--====================================================================================================
-- Doeworks bridge for ESIR modular rocket ordnance
--====================================================================================================

if not mods["doeworks-deer"] then
    return
end

local ei_lib = require("lib/lib")
local artillery_shell_icon = "__base__/graphics/icons/artillery-shell.png"
local nitric_acid_icon = ei_graphics_fluid_path .. "nitric-acid.png"
local cryodust_icon = ei_graphics_item_2_path .. "cryodust.png"
local uranium_235_icon = "__base__/graphics/icons/uranium-235.png"
local plutonium_icon = ei_graphics_item_path .. "plutonium-239.png"
local deer_ammo_icon = "__doeworks-deer__/graphics-smol/icons/deer-ammo-basic-icon.png"
local deer_crate_icon = "__doeworks-deer__/graphics-smol/icons/deer-crate-basic-icon.png"
local rocket_items_path = ei_temporary_rocket_item_path
local rocket_techs_path = ei_temporary_rocket_tech_path
local deer_ammo_basic_direct_icon = rocket_items_path .. "dw-deer-ammo-basic.png"
local deer_ammo_corrosive_direct_icon = rocket_items_path .. "dw-deer-ammo-corrosive.png"
local deer_ammo_cryo_direct_icon = rocket_items_path .. "dw-deer-ammo-cryo.png"
local deer_ammo_atomic_u235_direct_icon = rocket_items_path .. "dw-deer-ammo-atomic-u235.png"
local deer_ammo_atomic_plutonium_direct_icon = rocket_items_path .. "dw-deer-ammo-atomic-plutonium.png"
local deer_tech_icon = rocket_techs_path .. "dw-deer-tech.png"
local atomic_rocket_action = data.raw.projectile["atomic-rocket"] and data.raw.projectile["atomic-rocket"].action
local atomic_rocket_u235_action

local function mirror_gun_speed_bonus(tech_name, source_ammo_category, target_ammo_category)
    local technology = data.raw.technology[tech_name]
    if not technology or type(technology.effects) ~= "table" then
        return
    end

    local existing_modifier
    for _, effect in ipairs(technology.effects) do
        if effect.type == "gun-speed" and effect.ammo_category == target_ammo_category then
            return
        end

        if effect.type == "gun-speed" and effect.ammo_category == source_ammo_category then
            existing_modifier = effect.modifier
        end
    end

    if existing_modifier then
        technology.effects[#technology.effects + 1] = {
            type = "gun-speed",
            ammo_category = target_ammo_category,
            modifier = existing_modifier,
        }
    end
end

local function visit_tables(root, callback)
    if type(root) ~= "table" then
        return
    end

    callback(root)

    for _, value in pairs(root) do
        if type(value) == "table" then
            visit_tables(value, callback)
        end
    end
end

local function clone_atomic_action_with_center(action, center_name)
    if type(action) ~= "table" then
        return nil
    end

    local cloned = table.deepcopy(action)
    visit_tables(cloned, function(node)
        if node.type == "create-entity" and node.entity_name == "nuke-explosion" then
            node.entity_name = center_name
        end
    end)

    return cloned
end

atomic_rocket_u235_action = clone_atomic_action_with_center(atomic_rocket_action, "ei-atomic-u235-center-explosion")

local function patch_stream_damage(stream_name, damage_updates)
    local stream = data.raw.stream and data.raw.stream[stream_name]
    if not stream then
        return
    end

    visit_tables(stream, function(node)
        local damage = node.damage
        if type(damage) ~= "table" then
            return
        end

        if damage_updates[damage.type] then
            damage.amount = damage_updates[damage.type]
        end
    end)
end

local function retag_stream_damage(stream_name, from_type, to_type)
    local stream = data.raw.stream and data.raw.stream[stream_name]
    if not stream then
        return
    end

    visit_tables(stream, function(node)
        local damage = node.damage
        if type(damage) ~= "table" then
            return
        end

        if damage.type == from_type then
            damage.type = to_type
        end
    end)
end

local function rewrite_streams(root, stream_map)
    if type(stream_map) ~= "table" then
        return
    end

    visit_tables(root, function(node)
        if node.type == "stream" and node.stream and stream_map[node.stream] then
            node.stream = stream_map[node.stream]
        end
    end)
end

local function clone_recipe(source_name, new_name, order, icons, ingredients, results)
    local source = data.raw.recipe[source_name]
    if not source then
        return nil
    end

    local recipe = table.deepcopy(source)
    recipe.name = new_name
    recipe.order = order
    recipe.icon = nil
    recipe.icon_size = nil
    recipe.icon_mipmaps = nil
    recipe.icons = icons
    recipe.normal = nil
    recipe.expensive = nil
    recipe.ingredients = ingredients
    recipe.results = results
    recipe.main_product = results[1].name
    recipe.enabled = false
    return recipe
end

local function clone_ammo(source_name, new_name, order, icons, stream_map)
    local source = data.raw.ammo[source_name]
    if not source then
        return nil
    end

    local ammo = table.deepcopy(source)
    ammo.name = new_name
    ammo.order = order
    ammo.icon = nil
    ammo.icon_size = nil
    ammo.icon_mipmaps = nil
    ammo.icons = icons
    rewrite_streams(ammo.ammo_type.action, stream_map)
    return ammo
end

local function set_direct_icon(prototype, icon_path, icon_size, icon_mipmaps)
    if not prototype then
        return
    end

    prototype.icon = icon_path
    prototype.icon_size = icon_size or 512
    prototype.icon_mipmaps = icon_mipmaps or 5
    prototype.icons = nil
end

local function set_composite_icons(prototype, icons)
    if not prototype then
        return
    end

    prototype.icon = nil
    prototype.icon_size = nil
    prototype.icon_mipmaps = nil
    prototype.icons = icons
end

local function make_imported_recipe_icons(base_icon, overlay_icon, overlay_scale, overlay_shift)
    return ei_lib.make_icons(
        base_icon,
        512,
        overlay_icon,
        64,
        overlay_scale or 0.45,
        overlay_shift or {8, 8},
        nil,
        {base_mipmaps = 5, base_scale = 1.2}
    )
end

local function make_imported_tech_icons(base_icon, overlay_icon, overlay_scale, overlay_shift)
    return ei_lib.make_icons(
        base_icon,
        256,
        overlay_icon,
        64,
        overlay_scale or 0.4,
        overlay_shift or {8, 8},
        nil,
        {base_mipmaps = 4}
    )
end

local function clone_stream(source_name, new_name)
    local source = data.raw.stream and data.raw.stream[source_name]
    if not source then
        return nil
    end

    local stream = table.deepcopy(source)
    stream.name = new_name
    return stream
end

local function overwrite_stream(target_name, source_name)
    local source = data.raw.stream and data.raw.stream[source_name]
    local target = data.raw.stream and data.raw.stream[target_name]
    if not source or not target then
        return nil
    end

    local replacement = table.deepcopy(source)
    replacement.name = target_name

    for key in pairs(target) do
        target[key] = nil
    end

    for key, value in pairs(replacement) do
        target[key] = value
    end

    return target
end

local function set_stream_speed(stream_name, horizontal_speed)
    local stream = data.raw.stream and data.raw.stream[stream_name]
    if not stream then
        return
    end

    stream.particle_horizontal_speed = horizontal_speed
end

local function append_stream_visual_effects(stream_name, effects)
    local stream = data.raw.stream and data.raw.stream[stream_name]
    if not stream or not stream.action or not stream.action[1] then
        return
    end

    local delivery = stream.action[1].action_delivery
    if not delivery then
        return
    end

    local target_effects = delivery.target_effects
    if not target_effects then
        return
    end

    if target_effects.type then
        target_effects = {target_effects}
        delivery.target_effects = target_effects
    end

    for _, effect in ipairs(effects) do
        target_effects[#target_effects + 1] = table.deepcopy(effect)
    end
end

local function add_stream_payload_action(stream_name, action)
    local stream = data.raw.stream and data.raw.stream[stream_name]
    if not stream or not stream.action then
        return
    end

    stream.action[#stream.action + 1] = table.deepcopy(action)
end

-- Keep the turret awkwardness intact; only the payoff shifts.
ei_lib.set_prerequisites("dw-deer-tech", {
    "explosive-rocketry",
    "engine",
    "steel-processing",
    "ei-advanced-motor",
    "processing-unit",
    "ei-advanced-rocket-fuel",
})
ei_lib.set_age_packs("dw-deer-tech", "computer-age")
if data.raw.technology["dw-deer-tech"] then
    data.raw.technology["dw-deer-tech"].age = "computer-age"
end

ei_lib.recipe_new("dw-deer-turret", {
    {type = "item", name = "steel-plate", amount = 20},
    {type = "item", name = "engine-unit", amount = 20},
    {type = "item", name = "ei-steel-mechanical-parts", amount = 20},
    {type = "item", name = "ei-advanced-motor", amount = 6},
    {type = "item", name = "processing-unit", amount = 6},
}, {
    clear_difficulty_variants = true,
    enabled = false,
})

ei_lib.recipe_new("dw-deer-ammo-basic", {
    {type = "item", name = "ei-rocket-airframe", amount = 1},
    {type = "item", name = "ei-rocket-motor-high-energy", amount = 1},
    {type = "item", name = "ei-rocket-warhead-siege", amount = 1},
}, {
    clear_difficulty_variants = true,
    enabled = false,
})

set_direct_icon(data.raw.ammo["dw-deer-ammo-basic"], deer_ammo_basic_direct_icon)
set_composite_icons(
    data.raw.recipe["dw-deer-ammo-basic"],
    make_imported_recipe_icons(deer_ammo_basic_direct_icon, artillery_shell_icon, 0.4, {8, 8})
)
set_composite_icons(
    data.raw.recipe["dw-deer-crating-basic"],
    ei_lib.make_icons(deer_crate_icon, 64, artillery_shell_icon, 64, 0.4, {8, 8})
)
set_composite_icons(
    data.raw.recipe["dw-deer-uncrating-basic"],
    make_imported_recipe_icons(deer_ammo_basic_direct_icon, artillery_shell_icon, 0.4, {8, 8})
)
set_composite_icons(
    data.raw.technology["dw-deer-tech"],
    make_imported_tech_icons(deer_tech_icon, artillery_shell_icon, 0.4, {8, 8})
)

local deer_turret = data.raw["ammo-turret"] and data.raw["ammo-turret"]["dw-deer-turret"]
if deer_turret and deer_turret.attack_parameters then
    deer_turret.attack_parameters.range = 115
    deer_turret.attack_parameters.prepare_range = 116
    deer_turret.attack_parameters.min_range = 35
    deer_turret.attack_parameters.lead_target_for_projectile_speed = 0.5
end

local doeworks_prototypes = {}

overwrite_stream("ei-dw-deer-corrosive-stream", "dw-deer-basic-stream")
overwrite_stream("ei-dw-deer-cryo-stream", "dw-deer-basic-stream")

local stream_clones = {
    clone_stream("dw-deer-basic-cratestream", "ei-dw-deer-corrosive-cratestream"),
    clone_stream("dw-deer-basic-cratestreambad", "ei-dw-deer-corrosive-cratestreambad"),
    clone_stream("dw-deer-basic-cratestreamworse", "ei-dw-deer-corrosive-cratestreamworse"),
    clone_stream("dw-deer-basic-cratestream", "ei-dw-deer-cryo-cratestream"),
    clone_stream("dw-deer-basic-cratestreambad", "ei-dw-deer-cryo-cratestreambad"),
    clone_stream("dw-deer-basic-cratestreamworse", "ei-dw-deer-cryo-cratestreamworse"),
    clone_stream("dw-deer-basic-stream", "ei-dw-deer-atomic-u235-stream"),
    clone_stream("dw-deer-basic-cratestream", "ei-dw-deer-atomic-u235-cratestream"),
    clone_stream("dw-deer-basic-cratestreambad", "ei-dw-deer-atomic-u235-cratestreambad"),
    clone_stream("dw-deer-basic-cratestreamworse", "ei-dw-deer-atomic-u235-cratestreamworse"),
    clone_stream("dw-deer-basic-stream", "ei-dw-deer-atomic-plutonium-stream"),
    clone_stream("dw-deer-basic-cratestream", "ei-dw-deer-atomic-plutonium-cratestream"),
    clone_stream("dw-deer-basic-cratestreambad", "ei-dw-deer-atomic-plutonium-cratestreambad"),
    clone_stream("dw-deer-basic-cratestreamworse", "ei-dw-deer-atomic-plutonium-cratestreamworse"),
}

for _, stream in ipairs(stream_clones) do
    if stream then
        doeworks_prototypes[#doeworks_prototypes + 1] = stream
    end
end

local corrosive_ammo = clone_ammo(
    "dw-deer-ammo-basic",
    "dw-deer-ammo-corrosive",
    "d[cannon-shell]-d551[doeworks]-a[deer]-b[corrosive]",
    ei_lib.make_icons(deer_ammo_icon, 64, nitric_acid_icon, 64, 0.45, {8, 8}),
    {
        ["dw-deer-basic-stream"] = "ei-dw-deer-corrosive-stream",
    }
)
if corrosive_ammo then
    set_direct_icon(corrosive_ammo, deer_ammo_corrosive_direct_icon)
    doeworks_prototypes[#doeworks_prototypes + 1] = corrosive_ammo
end

local corrosive_crate = clone_ammo(
    "dw-deer-ammo-basic-crate",
    "dw-deer-ammo-corrosive-crate",
    "d[cannon-shell]-d551[doeworks]-a[deer]-b[corrosive]-a[crate]",
    ei_lib.make_icons(deer_crate_icon, 64, nitric_acid_icon, 64, 0.45, {8, 8}),
    {
        ["dw-deer-basic-cratestream"] = "ei-dw-deer-corrosive-cratestream",
        ["dw-deer-basic-cratestreambad"] = "ei-dw-deer-corrosive-cratestreambad",
        ["dw-deer-basic-cratestreamworse"] = "ei-dw-deer-corrosive-cratestreamworse",
    }
)
if corrosive_crate then
    doeworks_prototypes[#doeworks_prototypes + 1] = corrosive_crate
end

local cryo_ammo = clone_ammo(
    "dw-deer-ammo-basic",
    "dw-deer-ammo-cryo",
    "d[cannon-shell]-d551[doeworks]-a[deer]-c[cryo]",
    ei_lib.make_icons(deer_ammo_icon, 64, cryodust_icon, 64, 0.45, {8, 8}),
    {
        ["dw-deer-basic-stream"] = "ei-dw-deer-cryo-stream",
    }
)
if cryo_ammo then
    set_direct_icon(cryo_ammo, deer_ammo_cryo_direct_icon)
    doeworks_prototypes[#doeworks_prototypes + 1] = cryo_ammo
end

local atomic_u235_ammo = clone_ammo(
    "dw-deer-ammo-basic",
    "dw-deer-ammo-atomic-u235",
    "d[cannon-shell]-d551[doeworks]-a[deer]-d[atomic-u235]",
    ei_lib.make_icons(deer_ammo_icon, 64, uranium_235_icon, 64, 0.45, {8, 8}),
    {
        ["dw-deer-basic-stream"] = "ei-dw-deer-atomic-u235-stream",
    }
)
if atomic_u235_ammo then
    atomic_u235_ammo.stack_size = 5
    set_direct_icon(atomic_u235_ammo, deer_ammo_atomic_u235_direct_icon)
    doeworks_prototypes[#doeworks_prototypes + 1] = atomic_u235_ammo
end

local atomic_plutonium_ammo = clone_ammo(
    "dw-deer-ammo-basic",
    "dw-deer-ammo-atomic-plutonium",
    "d[cannon-shell]-d551[doeworks]-a[deer]-e[atomic-plutonium]",
    ei_lib.make_icons(deer_ammo_icon, 64, plutonium_icon, 64, 0.45, {8, 8}),
    {
        ["dw-deer-basic-stream"] = "ei-dw-deer-atomic-plutonium-stream",
    }
)
if atomic_plutonium_ammo then
    atomic_plutonium_ammo.stack_size = 5
    set_direct_icon(atomic_plutonium_ammo, deer_ammo_atomic_plutonium_direct_icon)
    doeworks_prototypes[#doeworks_prototypes + 1] = atomic_plutonium_ammo
end

local atomic_u235_crate = clone_ammo(
    "dw-deer-ammo-basic-crate",
    "dw-deer-ammo-atomic-u235-crate",
    "d[cannon-shell]-d551[doeworks]-a[deer]-d[atomic-u235]-a[crate]",
    ei_lib.make_icons(deer_crate_icon, 64, uranium_235_icon, 64, 0.45, {8, 8}),
    {
        ["dw-deer-basic-cratestream"] = "ei-dw-deer-atomic-u235-cratestream",
        ["dw-deer-basic-cratestreambad"] = "ei-dw-deer-atomic-u235-cratestreambad",
        ["dw-deer-basic-cratestreamworse"] = "ei-dw-deer-atomic-u235-cratestreamworse",
    }
)
if atomic_u235_crate then
    atomic_u235_crate.stack_size = 1
    doeworks_prototypes[#doeworks_prototypes + 1] = atomic_u235_crate
end

local atomic_plutonium_crate = clone_ammo(
    "dw-deer-ammo-basic-crate",
    "dw-deer-ammo-atomic-plutonium-crate",
    "d[cannon-shell]-d551[doeworks]-a[deer]-e[atomic-plutonium]-a[crate]",
    ei_lib.make_icons(deer_crate_icon, 64, plutonium_icon, 64, 0.45, {8, 8}),
    {
        ["dw-deer-basic-cratestream"] = "ei-dw-deer-atomic-plutonium-cratestream",
        ["dw-deer-basic-cratestreambad"] = "ei-dw-deer-atomic-plutonium-cratestreambad",
        ["dw-deer-basic-cratestreamworse"] = "ei-dw-deer-atomic-plutonium-cratestreamworse",
    }
)
if atomic_plutonium_crate then
    atomic_plutonium_crate.stack_size = 1
    doeworks_prototypes[#doeworks_prototypes + 1] = atomic_plutonium_crate
end

local cryo_crate = clone_ammo(
    "dw-deer-ammo-basic-crate",
    "dw-deer-ammo-cryo-crate",
    "d[cannon-shell]-d551[doeworks]-a[deer]-c[cryo]-a[crate]",
    ei_lib.make_icons(deer_crate_icon, 64, cryodust_icon, 64, 0.45, {8, 8}),
    {
        ["dw-deer-basic-cratestream"] = "ei-dw-deer-cryo-cratestream",
        ["dw-deer-basic-cratestreambad"] = "ei-dw-deer-cryo-cratestreambad",
        ["dw-deer-basic-cratestreamworse"] = "ei-dw-deer-cryo-cratestreamworse",
    }
)
if cryo_crate then
    doeworks_prototypes[#doeworks_prototypes + 1] = cryo_crate
end

local corrosive_recipe = clone_recipe(
    "dw-deer-ammo-basic",
    "dw-deer-ammo-corrosive",
    "d[cannon-shell]-d551[doeworks]-a[deer]-b[corrosive]",
    ei_lib.make_icons(deer_ammo_icon, 64, nitric_acid_icon, 64, 0.45, {8, 8}),
    {
        {type = "item", name = "ei-rocket-airframe", amount = 1},
        {type = "item", name = "ei-rocket-motor-high-energy", amount = 1},
        {type = "item", name = "ei-rocket-warhead-corrosive", amount = 1},
    },
    {
        {type = "item", name = "dw-deer-ammo-corrosive", amount = 1},
    }
)
if corrosive_recipe then
    set_composite_icons(corrosive_recipe, make_imported_recipe_icons(deer_ammo_corrosive_direct_icon, nitric_acid_icon))
    doeworks_prototypes[#doeworks_prototypes + 1] = corrosive_recipe
end

local corrosive_crating = clone_recipe(
    "dw-deer-crating-basic",
    "dw-deer-crating-corrosive",
    "d[cannon-shell]-d551[doeworks]-a[deer]-b[corrosive]-a[crate]",
    ei_lib.make_icons(deer_crate_icon, 64, nitric_acid_icon, 64, 0.45, {8, 8}),
    {
        {type = "item", name = "dw-deer-ammo-corrosive", amount = 12},
        {type = "item", name = "steel-plate", amount = 1},
    },
    {
        {type = "item", name = "dw-deer-ammo-corrosive-crate", amount = 1},
    }
)
if corrosive_crating then
    doeworks_prototypes[#doeworks_prototypes + 1] = corrosive_crating
end

local corrosive_uncrating = clone_recipe(
    "dw-deer-uncrating-basic",
    "dw-deer-uncrating-corrosive",
    "d[cannon-shell]-d551[doeworks]-a[deer]-b[corrosive]-b[uncrate]",
    ei_lib.make_icons(deer_ammo_icon, 64, nitric_acid_icon, 64, 0.45, {8, 8}),
    {
        {type = "item", name = "dw-deer-ammo-corrosive-crate", amount = 1},
    },
    {
        {type = "item", name = "dw-deer-ammo-corrosive", amount = 12},
    }
)
if corrosive_uncrating then
    set_composite_icons(corrosive_uncrating, make_imported_recipe_icons(deer_ammo_corrosive_direct_icon, nitric_acid_icon))
    doeworks_prototypes[#doeworks_prototypes + 1] = corrosive_uncrating
end

local cryo_recipe = clone_recipe(
    "dw-deer-ammo-basic",
    "dw-deer-ammo-cryo",
    "d[cannon-shell]-d551[doeworks]-a[deer]-c[cryo]",
    ei_lib.make_icons(deer_ammo_icon, 64, cryodust_icon, 64, 0.45, {8, 8}),
    {
        {type = "item", name = "ei-rocket-airframe", amount = 1},
        {type = "item", name = "ei-rocket-motor-high-energy", amount = 1},
        {type = "item", name = "ei-rocket-warhead-cryo", amount = 1},
    },
    {
        {type = "item", name = "dw-deer-ammo-cryo", amount = 1},
    }
)
if cryo_recipe then
    set_composite_icons(cryo_recipe, make_imported_recipe_icons(deer_ammo_cryo_direct_icon, cryodust_icon))
    doeworks_prototypes[#doeworks_prototypes + 1] = cryo_recipe
end

local atomic_u235_recipe = clone_recipe(
    "dw-deer-ammo-basic",
    "dw-deer-ammo-atomic-u235",
    "d[cannon-shell]-d551[doeworks]-a[deer]-d[atomic-u235]",
    ei_lib.make_icons(deer_ammo_icon, 64, uranium_235_icon, 64, 0.45, {8, 8}),
    {
        {type = "item", name = "ei-rocket-airframe", amount = 1},
        {type = "item", name = "ei-rocket-motor-high-energy", amount = 1},
        {type = "item", name = "ei-rocket-warhead-atomic-u235", amount = 1},
    },
    {
        {type = "item", name = "dw-deer-ammo-atomic-u235", amount = 1},
    }
)
if atomic_u235_recipe then
    atomic_u235_recipe.allow_productivity = false
    set_composite_icons(atomic_u235_recipe, make_imported_recipe_icons(deer_ammo_atomic_u235_direct_icon, uranium_235_icon))
    doeworks_prototypes[#doeworks_prototypes + 1] = atomic_u235_recipe
end

local atomic_plutonium_recipe = clone_recipe(
    "dw-deer-ammo-basic",
    "dw-deer-ammo-atomic-plutonium",
    "d[cannon-shell]-d551[doeworks]-a[deer]-e[atomic-plutonium]",
    ei_lib.make_icons(deer_ammo_icon, 64, plutonium_icon, 64, 0.45, {8, 8}),
    {
        {type = "item", name = "ei-rocket-airframe", amount = 1},
        {type = "item", name = "ei-rocket-motor-high-energy", amount = 1},
        {type = "item", name = "ei-rocket-warhead-atomic-plutonium", amount = 1},
    },
    {
        {type = "item", name = "dw-deer-ammo-atomic-plutonium", amount = 1},
    }
)
if atomic_plutonium_recipe then
    atomic_plutonium_recipe.allow_productivity = false
    set_composite_icons(atomic_plutonium_recipe, make_imported_recipe_icons(deer_ammo_atomic_plutonium_direct_icon, plutonium_icon))
    doeworks_prototypes[#doeworks_prototypes + 1] = atomic_plutonium_recipe
end

local atomic_u235_crating = clone_recipe(
    "dw-deer-crating-basic",
    "dw-deer-crating-atomic-u235",
    "d[cannon-shell]-d551[doeworks]-a[deer]-d[atomic-u235]-a[crate]",
    ei_lib.make_icons(deer_crate_icon, 64, uranium_235_icon, 64, 0.45, {8, 8}),
    {
        {type = "item", name = "dw-deer-ammo-atomic-u235", amount = 12},
        {type = "item", name = "steel-plate", amount = 1},
    },
    {
        {type = "item", name = "dw-deer-ammo-atomic-u235-crate", amount = 1},
    }
)
if atomic_u235_crating then
    atomic_u235_crating.allow_productivity = false
    doeworks_prototypes[#doeworks_prototypes + 1] = atomic_u235_crating
end

local atomic_u235_uncrating = clone_recipe(
    "dw-deer-uncrating-basic",
    "dw-deer-uncrating-atomic-u235",
    "d[cannon-shell]-d551[doeworks]-a[deer]-d[atomic-u235]-b[uncrate]",
    ei_lib.make_icons(deer_ammo_icon, 64, uranium_235_icon, 64, 0.45, {8, 8}),
    {
        {type = "item", name = "dw-deer-ammo-atomic-u235-crate", amount = 1},
    },
    {
        {type = "item", name = "dw-deer-ammo-atomic-u235", amount = 12},
    }
)
if atomic_u235_uncrating then
    atomic_u235_uncrating.allow_productivity = false
    set_composite_icons(atomic_u235_uncrating, make_imported_recipe_icons(deer_ammo_atomic_u235_direct_icon, uranium_235_icon))
    doeworks_prototypes[#doeworks_prototypes + 1] = atomic_u235_uncrating
end

local atomic_plutonium_crating = clone_recipe(
    "dw-deer-crating-basic",
    "dw-deer-crating-atomic-plutonium",
    "d[cannon-shell]-d551[doeworks]-a[deer]-e[atomic-plutonium]-a[crate]",
    ei_lib.make_icons(deer_crate_icon, 64, plutonium_icon, 64, 0.45, {8, 8}),
    {
        {type = "item", name = "dw-deer-ammo-atomic-plutonium", amount = 12},
        {type = "item", name = "steel-plate", amount = 1},
    },
    {
        {type = "item", name = "dw-deer-ammo-atomic-plutonium-crate", amount = 1},
    }
)
if atomic_plutonium_crating then
    atomic_plutonium_crating.allow_productivity = false
    doeworks_prototypes[#doeworks_prototypes + 1] = atomic_plutonium_crating
end

local atomic_plutonium_uncrating = clone_recipe(
    "dw-deer-uncrating-basic",
    "dw-deer-uncrating-atomic-plutonium",
    "d[cannon-shell]-d551[doeworks]-a[deer]-e[atomic-plutonium]-b[uncrate]",
    ei_lib.make_icons(deer_ammo_icon, 64, plutonium_icon, 64, 0.45, {8, 8}),
    {
        {type = "item", name = "dw-deer-ammo-atomic-plutonium-crate", amount = 1},
    },
    {
        {type = "item", name = "dw-deer-ammo-atomic-plutonium", amount = 12},
    }
)
if atomic_plutonium_uncrating then
    atomic_plutonium_uncrating.allow_productivity = false
    set_composite_icons(atomic_plutonium_uncrating, make_imported_recipe_icons(deer_ammo_atomic_plutonium_direct_icon, plutonium_icon))
    doeworks_prototypes[#doeworks_prototypes + 1] = atomic_plutonium_uncrating
end

local cryo_crating = clone_recipe(
    "dw-deer-crating-basic",
    "dw-deer-crating-cryo",
    "d[cannon-shell]-d551[doeworks]-a[deer]-c[cryo]-a[crate]",
    ei_lib.make_icons(deer_crate_icon, 64, cryodust_icon, 64, 0.45, {8, 8}),
    {
        {type = "item", name = "dw-deer-ammo-cryo", amount = 12},
        {type = "item", name = "steel-plate", amount = 1},
    },
    {
        {type = "item", name = "dw-deer-ammo-cryo-crate", amount = 1},
    }
)
if cryo_crating then
    doeworks_prototypes[#doeworks_prototypes + 1] = cryo_crating
end

local cryo_uncrating = clone_recipe(
    "dw-deer-uncrating-basic",
    "dw-deer-uncrating-cryo",
    "d[cannon-shell]-d551[doeworks]-a[deer]-c[cryo]-b[uncrate]",
    ei_lib.make_icons(deer_ammo_icon, 64, cryodust_icon, 64, 0.45, {8, 8}),
    {
        {type = "item", name = "dw-deer-ammo-cryo-crate", amount = 1},
    },
    {
        {type = "item", name = "dw-deer-ammo-cryo", amount = 12},
    }
)
if cryo_uncrating then
    set_composite_icons(cryo_uncrating, make_imported_recipe_icons(deer_ammo_cryo_direct_icon, cryodust_icon))
    doeworks_prototypes[#doeworks_prototypes + 1] = cryo_uncrating
end

if #doeworks_prototypes > 0 then
    data:extend(doeworks_prototypes)
end

local siege_visual_effects = {
    {
        type = "create-entity",
        entity_name = "ei-siege-rocket-explosion",
    },
}

local corrosive_visual_effects = {
    {
        type = "create-entity",
        entity_name = "ei-corrosive-rocket-explosion",
    },
    {
        type = "create-entity",
        entity_name = "ei-corrosive-rocket-cloud",
        trigger_created_entity = true,
    },
}

local corrosive_sticker_effects = {
    {
        type = "create-sticker",
        sticker = "ei-corrosive-rocket-sticker",
        show_in_tooltip = true,
    },
}

if data.raw.sticker["ei-corrosive-rocket-toxic-sticker"] then
    corrosive_sticker_effects[#corrosive_sticker_effects + 1] = {
        type = "create-sticker",
        sticker = "ei-corrosive-rocket-toxic-sticker",
        show_in_tooltip = false,
    }
end

corrosive_sticker_effects[#corrosive_sticker_effects + 1] = {
    type = "damage",
    damage = {amount = 48, type = "acid"},
    apply_damage_to_trees = false,
}

local cryo_visual_effects = {
    {
        type = "create-entity",
        entity_name = "ei-cryo-rocket-explosion",
    },
}

local corrosive_payload_action = {
    type = "area",
    radius = 3.75,
    show_in_tooltip = false,
    action_delivery = {
        type = "instant",
        target_effects = corrosive_sticker_effects,
    },
}

local cryo_payload_action = {
    type = "area",
    radius = 3.75,
    show_in_tooltip = false,
    action_delivery = {
        type = "instant",
        target_effects = {
            {
                type = "create-sticker",
                sticker = "ei-cryo-rocket-sticker",
                show_in_tooltip = true,
            },
            {
                type = "damage",
                damage = {amount = 24, type = "cold"},
                apply_damage_to_trees = false,
            },
        },
    },
}

local siege_streams = {
    "dw-deer-basic-stream",
    "dw-deer-basic-cratestream",
    "dw-deer-basic-cratestreambad",
    "dw-deer-basic-cratestreamworse",
}

for _, stream_name in ipairs(siege_streams) do
    append_stream_visual_effects(stream_name, siege_visual_effects)
end

local corrosive_streams = {
    "ei-dw-deer-corrosive-stream",
    "ei-dw-deer-corrosive-cratestream",
    "ei-dw-deer-corrosive-cratestreambad",
    "ei-dw-deer-corrosive-cratestreamworse",
}

for _, stream_name in ipairs(corrosive_streams) do
    append_stream_visual_effects(stream_name, corrosive_visual_effects)
    add_stream_payload_action(stream_name, corrosive_payload_action)
end

local cryo_streams = {
    "ei-dw-deer-cryo-stream",
    "ei-dw-deer-cryo-cratestream",
    "ei-dw-deer-cryo-cratestreambad",
    "ei-dw-deer-cryo-cratestreamworse",
}

for _, stream_name in ipairs(cryo_streams) do
    append_stream_visual_effects(stream_name, cryo_visual_effects)
    add_stream_payload_action(stream_name, cryo_payload_action)
end

local atomic_u235_streams = {
    "ei-dw-deer-atomic-u235-stream",
    "ei-dw-deer-atomic-u235-cratestream",
    "ei-dw-deer-atomic-u235-cratestreambad",
    "ei-dw-deer-atomic-u235-cratestreamworse",
}

local atomic_plutonium_streams = {
    "ei-dw-deer-atomic-plutonium-stream",
    "ei-dw-deer-atomic-plutonium-cratestream",
    "ei-dw-deer-atomic-plutonium-cratestreambad",
    "ei-dw-deer-atomic-plutonium-cratestreamworse",
}

if atomic_rocket_u235_action then
    for _, stream_name in ipairs(atomic_u235_streams) do
        add_stream_payload_action(stream_name, atomic_rocket_u235_action)
    end
end

if atomic_rocket_action then
    for _, stream_name in ipairs(atomic_plutonium_streams) do
        add_stream_payload_action(stream_name, atomic_rocket_action)
    end
end

ei_lib.add_unlock_recipe("dw-deer-tech", "dw-deer-ammo-basic")
ei_lib.add_unlock_recipe("dw-deer-tech", "dw-deer-crating-basic")
ei_lib.add_unlock_recipe("dw-deer-tech", "dw-deer-uncrating-basic")
ei_lib.add_unlock_recipe("dw-deer-tech", "ei-rocket-warhead-siege")

ei_lib.add_unlock_recipe("ei-corrosive-rocketry", "ei-rocket-warhead-corrosive")
ei_lib.add_unlock_recipe("ei-corrosive-rocketry", "dw-deer-ammo-corrosive")
ei_lib.add_unlock_recipe("ei-corrosive-rocketry", "dw-deer-crating-corrosive")
ei_lib.add_unlock_recipe("ei-corrosive-rocketry", "dw-deer-uncrating-corrosive")

ei_lib.add_unlock_recipe("ei-cryo-rocketry", "ei-rocket-warhead-cryo")
ei_lib.add_unlock_recipe("ei-cryo-rocketry", "dw-deer-ammo-cryo")
ei_lib.add_unlock_recipe("ei-cryo-rocketry", "dw-deer-crating-cryo")
ei_lib.add_unlock_recipe("ei-cryo-rocketry", "dw-deer-uncrating-cryo")

ei_lib.add_unlock_recipe("atomic-bomb", "dw-deer-ammo-atomic-u235")
ei_lib.add_unlock_recipe("atomic-bomb", "dw-deer-crating-atomic-u235")
ei_lib.add_unlock_recipe("atomic-bomb", "dw-deer-uncrating-atomic-u235")
ei_lib.add_unlock_recipe("ei-plutonium-warheads", "dw-deer-ammo-atomic-plutonium")
ei_lib.add_unlock_recipe("ei-plutonium-warheads", "dw-deer-crating-atomic-plutonium")
ei_lib.add_unlock_recipe("ei-plutonium-warheads", "dw-deer-uncrating-atomic-plutonium")

for _, tech_name in ipairs({
    "weapon-shooting-speed-3",
    "weapon-shooting-speed-4",
    "weapon-shooting-speed-5",
    "weapon-shooting-speed-6",
    "weapon-shooting-speed-7",
}) do
    mirror_gun_speed_bonus(tech_name, "rocket", "dw-deer-ammo")
end

for _, stream_name in ipairs({
    "dw-deer-basic-stream",
    "dw-deer-basic-cratestream",
    "ei-dw-deer-corrosive-stream",
    "ei-dw-deer-corrosive-cratestream",
    "ei-dw-deer-cryo-stream",
    "ei-dw-deer-cryo-cratestream",
    "ei-dw-deer-atomic-u235-stream",
    "ei-dw-deer-atomic-u235-cratestream",
    "ei-dw-deer-atomic-plutonium-stream",
    "ei-dw-deer-atomic-plutonium-cratestream",
}) do
    set_stream_speed(stream_name, 0.9)
end

for _, stream_name in ipairs({
    "dw-deer-basic-cratestreambad",
    "ei-dw-deer-corrosive-cratestreambad",
    "ei-dw-deer-cryo-cratestreambad",
    "ei-dw-deer-atomic-u235-cratestreambad",
    "ei-dw-deer-atomic-plutonium-cratestreambad",
}) do
    set_stream_speed(stream_name, 0.45)
end

for _, stream_name in ipairs({
    "dw-deer-basic-cratestreamworse",
    "ei-dw-deer-corrosive-cratestreamworse",
    "ei-dw-deer-cryo-cratestreamworse",
    "ei-dw-deer-atomic-u235-cratestreamworse",
    "ei-dw-deer-atomic-plutonium-cratestreamworse",
}) do
    set_stream_speed(stream_name, 0.6)
end

patch_stream_damage("dw-deer-basic-stream", {physical = 210, explosion = 640})
patch_stream_damage("dw-deer-basic-cratestream", {physical = 1000})
patch_stream_damage("dw-deer-basic-cratestreambad", {physical = 210, explosion = 640})
patch_stream_damage("dw-deer-basic-cratestreamworse", {physical = 210, explosion = 640})
patch_stream_damage("ei-dw-deer-corrosive-stream", {physical = 150, explosion = 450})
patch_stream_damage("ei-dw-deer-corrosive-cratestream", {physical = 700})
patch_stream_damage("ei-dw-deer-corrosive-cratestreambad", {physical = 150, explosion = 450})
patch_stream_damage("ei-dw-deer-corrosive-cratestreamworse", {physical = 150, explosion = 450})
retag_stream_damage("ei-dw-deer-corrosive-stream", "explosion", "acid")
retag_stream_damage("ei-dw-deer-corrosive-cratestream", "explosion", "acid")
retag_stream_damage("ei-dw-deer-corrosive-cratestreambad", "explosion", "acid")
retag_stream_damage("ei-dw-deer-corrosive-cratestreamworse", "explosion", "acid")
patch_stream_damage("ei-dw-deer-cryo-stream", {physical = 150, explosion = 450})
patch_stream_damage("ei-dw-deer-cryo-cratestream", {physical = 700})
patch_stream_damage("ei-dw-deer-cryo-cratestreambad", {physical = 150, explosion = 450})
patch_stream_damage("ei-dw-deer-cryo-cratestreamworse", {physical = 150, explosion = 450})
retag_stream_damage("ei-dw-deer-cryo-stream", "explosion", "cold")
retag_stream_damage("ei-dw-deer-cryo-cratestream", "explosion", "cold")
retag_stream_damage("ei-dw-deer-cryo-cratestreambad", "explosion", "cold")
retag_stream_damage("ei-dw-deer-cryo-cratestreamworse", "explosion", "cold")
patch_stream_damage("ei-dw-deer-atomic-u235-stream", {physical = 90, explosion = 300})
patch_stream_damage("ei-dw-deer-atomic-u235-cratestream", {physical = 450})
patch_stream_damage("ei-dw-deer-atomic-u235-cratestreambad", {physical = 90, explosion = 300})
patch_stream_damage("ei-dw-deer-atomic-u235-cratestreamworse", {physical = 90, explosion = 300})
patch_stream_damage("ei-dw-deer-atomic-plutonium-stream", {physical = 90, explosion = 300})
patch_stream_damage("ei-dw-deer-atomic-plutonium-cratestream", {physical = 450})
patch_stream_damage("ei-dw-deer-atomic-plutonium-cratestreambad", {physical = 90, explosion = 300})
patch_stream_damage("ei-dw-deer-atomic-plutonium-cratestreamworse", {physical = 90, explosion = 300})
