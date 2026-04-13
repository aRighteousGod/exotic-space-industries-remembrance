--====================================================================================================
-- Doeworks bridge for ESIR modular rocket ordnance
--====================================================================================================

if not mods["doeworks-deer"] then
    return
end

local ei_lib = require("lib/lib")
local nitric_acid_icon = ei_graphics_fluid_path .. "nitric-acid.png"
local cryodust_icon = ei_graphics_item_2_path .. "cryodust.png"
local uranium_235_icon = "__base__/graphics/icons/uranium-235.png"
local plutonium_icon = ei_graphics_item_path .. "plutonium-239.png"
local deer_ammo_icon = "__doeworks-deer__/graphics-smol/icons/deer-ammo-basic-icon.png"
local deer_crate_icon = "__doeworks-deer__/graphics-smol/icons/deer-crate-basic-icon.png"
local atomic_rocket_action = data.raw.projectile["atomic-rocket"] and data.raw.projectile["atomic-rocket"].action

local function add_unlock_if_present(tech_name, recipe_name)
    if data.raw.technology[tech_name] and data.raw.recipe[recipe_name] then
        ei_lib.add_unlock_recipe(tech_name, recipe_name)
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

local function set_recipe_ingredients(recipe_name, ingredients)
    local recipe = data.raw.recipe[recipe_name]
    if not recipe then
        return
    end

    recipe.normal = nil
    recipe.expensive = nil
    recipe.ingredients = ingredients
    recipe.enabled = false
end

local function make_icons(base_icon, overlay_icon)
    return {
        {
            icon = base_icon,
            icon_size = 64,
        },
        {
            icon = overlay_icon,
            icon_size = 64,
            scale = 0.45,
            shift = {8, 8},
        },
    }
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
    ammo.icons = icons
    rewrite_streams(ammo.ammo_type.action, stream_map)
    return ammo
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

set_recipe_ingredients("dw-deer-turret", {
    {type = "item", name = "steel-plate", amount = 20},
    {type = "item", name = "engine-unit", amount = 20},
    {type = "item", name = "ei-steel-mechanical-parts", amount = 20},
    {type = "item", name = "ei-advanced-motor", amount = 6},
    {type = "item", name = "processing-unit", amount = 6},
})

set_recipe_ingredients("dw-deer-ammo-basic", {
    {type = "item", name = "ei-rocket-airframe", amount = 1},
    {type = "item", name = "ei-rocket-motor-high-energy", amount = 1},
    {type = "item", name = "ei-rocket-warhead-siege", amount = 1},
})

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
    make_icons(deer_ammo_icon, nitric_acid_icon),
    {
        ["dw-deer-basic-stream"] = "ei-dw-deer-corrosive-stream",
    }
)
if corrosive_ammo then
    doeworks_prototypes[#doeworks_prototypes + 1] = corrosive_ammo
end

local corrosive_crate = clone_ammo(
    "dw-deer-ammo-basic-crate",
    "dw-deer-ammo-corrosive-crate",
    "d[cannon-shell]-d551[doeworks]-a[deer]-b[corrosive]-a[crate]",
    make_icons(deer_crate_icon, nitric_acid_icon),
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
    make_icons(deer_ammo_icon, cryodust_icon),
    {
        ["dw-deer-basic-stream"] = "ei-dw-deer-cryo-stream",
    }
)
if cryo_ammo then
    doeworks_prototypes[#doeworks_prototypes + 1] = cryo_ammo
end

local atomic_u235_ammo = clone_ammo(
    "dw-deer-ammo-basic",
    "dw-deer-ammo-atomic-u235",
    "d[cannon-shell]-d551[doeworks]-a[deer]-d[atomic-u235]",
    make_icons(deer_ammo_icon, uranium_235_icon),
    {
        ["dw-deer-basic-stream"] = "ei-dw-deer-atomic-u235-stream",
    }
)
if atomic_u235_ammo then
    atomic_u235_ammo.stack_size = 5
    doeworks_prototypes[#doeworks_prototypes + 1] = atomic_u235_ammo
end

local atomic_plutonium_ammo = clone_ammo(
    "dw-deer-ammo-basic",
    "dw-deer-ammo-atomic-plutonium",
    "d[cannon-shell]-d551[doeworks]-a[deer]-e[atomic-plutonium]",
    make_icons(deer_ammo_icon, plutonium_icon),
    {
        ["dw-deer-basic-stream"] = "ei-dw-deer-atomic-plutonium-stream",
    }
)
if atomic_plutonium_ammo then
    atomic_plutonium_ammo.stack_size = 5
    doeworks_prototypes[#doeworks_prototypes + 1] = atomic_plutonium_ammo
end

local atomic_u235_crate = clone_ammo(
    "dw-deer-ammo-basic-crate",
    "dw-deer-ammo-atomic-u235-crate",
    "d[cannon-shell]-d551[doeworks]-a[deer]-d[atomic-u235]-a[crate]",
    make_icons(deer_crate_icon, uranium_235_icon),
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
    make_icons(deer_crate_icon, plutonium_icon),
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
    make_icons(deer_crate_icon, cryodust_icon),
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
    make_icons(deer_ammo_icon, nitric_acid_icon),
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
    doeworks_prototypes[#doeworks_prototypes + 1] = corrosive_recipe
end

local corrosive_crating = clone_recipe(
    "dw-deer-crating-basic",
    "dw-deer-crating-corrosive",
    "d[cannon-shell]-d551[doeworks]-a[deer]-b[corrosive]-a[crate]",
    make_icons(deer_crate_icon, nitric_acid_icon),
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
    make_icons(deer_ammo_icon, nitric_acid_icon),
    {
        {type = "item", name = "dw-deer-ammo-corrosive-crate", amount = 1},
    },
    {
        {type = "item", name = "dw-deer-ammo-corrosive", amount = 12},
    }
)
if corrosive_uncrating then
    doeworks_prototypes[#doeworks_prototypes + 1] = corrosive_uncrating
end

local cryo_recipe = clone_recipe(
    "dw-deer-ammo-basic",
    "dw-deer-ammo-cryo",
    "d[cannon-shell]-d551[doeworks]-a[deer]-c[cryo]",
    make_icons(deer_ammo_icon, cryodust_icon),
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
    doeworks_prototypes[#doeworks_prototypes + 1] = cryo_recipe
end

local atomic_u235_recipe = clone_recipe(
    "dw-deer-ammo-basic",
    "dw-deer-ammo-atomic-u235",
    "d[cannon-shell]-d551[doeworks]-a[deer]-d[atomic-u235]",
    make_icons(deer_ammo_icon, uranium_235_icon),
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
    doeworks_prototypes[#doeworks_prototypes + 1] = atomic_u235_recipe
end

local atomic_plutonium_recipe = clone_recipe(
    "dw-deer-ammo-basic",
    "dw-deer-ammo-atomic-plutonium",
    "d[cannon-shell]-d551[doeworks]-a[deer]-e[atomic-plutonium]",
    make_icons(deer_ammo_icon, plutonium_icon),
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
    doeworks_prototypes[#doeworks_prototypes + 1] = atomic_plutonium_recipe
end

local atomic_u235_crating = clone_recipe(
    "dw-deer-crating-basic",
    "dw-deer-crating-atomic-u235",
    "d[cannon-shell]-d551[doeworks]-a[deer]-d[atomic-u235]-a[crate]",
    make_icons(deer_crate_icon, uranium_235_icon),
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
    make_icons(deer_ammo_icon, uranium_235_icon),
    {
        {type = "item", name = "dw-deer-ammo-atomic-u235-crate", amount = 1},
    },
    {
        {type = "item", name = "dw-deer-ammo-atomic-u235", amount = 12},
    }
)
if atomic_u235_uncrating then
    atomic_u235_uncrating.allow_productivity = false
    doeworks_prototypes[#doeworks_prototypes + 1] = atomic_u235_uncrating
end

local atomic_plutonium_crating = clone_recipe(
    "dw-deer-crating-basic",
    "dw-deer-crating-atomic-plutonium",
    "d[cannon-shell]-d551[doeworks]-a[deer]-e[atomic-plutonium]-a[crate]",
    make_icons(deer_crate_icon, plutonium_icon),
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
    make_icons(deer_ammo_icon, plutonium_icon),
    {
        {type = "item", name = "dw-deer-ammo-atomic-plutonium-crate", amount = 1},
    },
    {
        {type = "item", name = "dw-deer-ammo-atomic-plutonium", amount = 12},
    }
)
if atomic_plutonium_uncrating then
    atomic_plutonium_uncrating.allow_productivity = false
    doeworks_prototypes[#doeworks_prototypes + 1] = atomic_plutonium_uncrating
end

local cryo_crating = clone_recipe(
    "dw-deer-crating-basic",
    "dw-deer-crating-cryo",
    "d[cannon-shell]-d551[doeworks]-a[deer]-c[cryo]-a[crate]",
    make_icons(deer_crate_icon, cryodust_icon),
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
    make_icons(deer_ammo_icon, cryodust_icon),
    {
        {type = "item", name = "dw-deer-ammo-cryo-crate", amount = 1},
    },
    {
        {type = "item", name = "dw-deer-ammo-cryo", amount = 12},
    }
)
if cryo_uncrating then
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
        target_effects = {
            {
                type = "create-sticker",
                sticker = "ei-corrosive-rocket-sticker",
                show_in_tooltip = true,
            },
            {
                type = "damage",
                damage = {amount = 18, type = "acid"},
                apply_damage_to_trees = false,
            },
        },
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
                damage = {amount = 11, type = "cold"},
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

local atomic_streams = {
    "ei-dw-deer-atomic-u235-stream",
    "ei-dw-deer-atomic-u235-cratestream",
    "ei-dw-deer-atomic-u235-cratestreambad",
    "ei-dw-deer-atomic-u235-cratestreamworse",
    "ei-dw-deer-atomic-plutonium-stream",
    "ei-dw-deer-atomic-plutonium-cratestream",
    "ei-dw-deer-atomic-plutonium-cratestreambad",
    "ei-dw-deer-atomic-plutonium-cratestreamworse",
}

if atomic_rocket_action then
    for _, stream_name in ipairs(atomic_streams) do
        add_stream_payload_action(stream_name, atomic_rocket_action)
    end
end

add_unlock_if_present("dw-deer-tech", "dw-deer-ammo-basic")
add_unlock_if_present("dw-deer-tech", "dw-deer-crating-basic")
add_unlock_if_present("dw-deer-tech", "dw-deer-uncrating-basic")
add_unlock_if_present("dw-deer-tech", "ei-rocket-warhead-siege")

add_unlock_if_present("ei-corrosive-rocketry", "ei-rocket-warhead-corrosive")
add_unlock_if_present("ei-corrosive-rocketry", "dw-deer-ammo-corrosive")
add_unlock_if_present("ei-corrosive-rocketry", "dw-deer-crating-corrosive")
add_unlock_if_present("ei-corrosive-rocketry", "dw-deer-uncrating-corrosive")

add_unlock_if_present("ei-cryo-rocketry", "ei-rocket-warhead-cryo")
add_unlock_if_present("ei-cryo-rocketry", "dw-deer-ammo-cryo")
add_unlock_if_present("ei-cryo-rocketry", "dw-deer-crating-cryo")
add_unlock_if_present("ei-cryo-rocketry", "dw-deer-uncrating-cryo")

add_unlock_if_present("atomic-bomb", "dw-deer-ammo-atomic-u235")
add_unlock_if_present("atomic-bomb", "dw-deer-crating-atomic-u235")
add_unlock_if_present("atomic-bomb", "dw-deer-uncrating-atomic-u235")
add_unlock_if_present("ei-plutonium-warheads", "dw-deer-ammo-atomic-plutonium")
add_unlock_if_present("ei-plutonium-warheads", "dw-deer-crating-atomic-plutonium")
add_unlock_if_present("ei-plutonium-warheads", "dw-deer-uncrating-atomic-plutonium")

patch_stream_damage("dw-deer-basic-stream", {physical = 90, explosion = 300})
patch_stream_damage("dw-deer-basic-cratestream", {physical = 450})
patch_stream_damage("dw-deer-basic-cratestreambad", {physical = 90, explosion = 300})
patch_stream_damage("dw-deer-basic-cratestreamworse", {physical = 90, explosion = 300})
patch_stream_damage("ei-dw-deer-atomic-u235-stream", {physical = 90, explosion = 300})
patch_stream_damage("ei-dw-deer-atomic-u235-cratestream", {physical = 450})
patch_stream_damage("ei-dw-deer-atomic-u235-cratestreambad", {physical = 90, explosion = 300})
patch_stream_damage("ei-dw-deer-atomic-u235-cratestreamworse", {physical = 90, explosion = 300})
patch_stream_damage("ei-dw-deer-atomic-plutonium-stream", {physical = 90, explosion = 300})
patch_stream_damage("ei-dw-deer-atomic-plutonium-cratestream", {physical = 450})
patch_stream_damage("ei-dw-deer-atomic-plutonium-cratestreambad", {physical = 90, explosion = 300})
patch_stream_damage("ei-dw-deer-atomic-plutonium-cratestreamworse", {physical = 90, explosion = 300})
