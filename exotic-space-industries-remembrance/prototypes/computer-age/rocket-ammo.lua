local ei_lib = require("lib/lib")
local ei_data = require("lib/data")

require("rocket-ammo-effects")

local rocket_icon = "__base__/graphics/icons/rocket.png"
local explosive_rocket_icon = "__base__/graphics/icons/explosive-rocket.png"
local atomic_bomb_icon = "__base__/graphics/icons/atomic-bomb.png"
local engine_icon = "__base__/graphics/icons/engine-unit.png"
local low_density_structure_icon = "__base__/graphics/icons/low-density-structure.png"
local explosives_icon = "__base__/graphics/icons/explosives.png"
local artillery_shell_icon = "__base__/graphics/icons/artillery-shell.png"
local uranium_235_icon = "__base__/graphics/icons/uranium-235.png"
local uranium_238_icon = "__base__/graphics/icons/uranium-238.png"
local processing_unit_icon = "__base__/graphics/icons/processing-unit.png"
local nitric_acid_icon = ei_graphics_fluid_path .. "nitric-acid.png"
local advanced_rocket_fuel_icon = ei_graphics_item_path .. "advanced-rocket-fuel.png"
local cryodust_icon = ei_graphics_item_2_path .. "cryodust.png"
local plutonium_icon = ei_graphics_item_path .. "plutonium-239.png"
local rocket_items_path = ei_temporary_rocket_item_path
local rocket_techs_path = ei_temporary_rocket_tech_path

local rocket_airframe_icon = rocket_items_path .. "ei-rocket-airframe.png"
local rocket_motor_basic_icon = rocket_items_path .. "ei-rocket-motor-basic.png"
local rocket_motor_high_energy_icon = rocket_items_path .. "ei-rocket-motor-high-energy.png"
local rocket_warhead_impact_icon = rocket_items_path .. "ei-rocket-warhead-impact.png"
local rocket_warhead_explosive_icon = rocket_items_path .. "ei-rocket-warhead-explosive.png"
local rocket_warhead_siege_icon = rocket_items_path .. "ei-rocket-warhead-siege.png"
local rocket_warhead_corrosive_icon = rocket_items_path .. "ei-rocket-warhead-corrosive.png"
local rocket_warhead_cryo_icon = rocket_items_path .. "ei-rocket-warhead-cryo.png"
local rocket_warhead_atomic_u235_icon = rocket_items_path .. "ei-rocket-warhead-atomic-u235.png"
local rocket_warhead_atomic_plutonium_icon = rocket_items_path .. "ei-rocket-warhead-atomic-plutonium.png"
local corrosive_rocket_icon = rocket_items_path .. "ei-corrosive-rocket.png"
local cryo_rocket_icon = rocket_items_path .. "ei-cryo-rocket.png"
local atomic_bomb_u235_icon = rocket_items_path .. "ei-atomic-bomb-u235.png"
local atomic_bomb_plutonium_icon = rocket_items_path .. "ei-atomic-bomb-plutonium.png"

local corrosive_rocketry_tech_icon = rocket_techs_path .. "ei-corrosive-rocketry.png"
local cryo_rocketry_tech_icon = rocket_techs_path .. "ei-cryo-rocketry.png"
local atomic_bomb_tech_icon = rocket_techs_path .. "atomic-bomb.png"
local plutonium_warheads_tech_icon = rocket_techs_path .. "ei-plutonium-warheads.png"

local function make_recipe(name, energy_required, ingredients, results, extra)
    local recipe = {
        type = "recipe",
        name = name,
        category = "crafting",
        energy_required = energy_required,
        ingredients = ingredients,
        results = results,
        enabled = false,
        always_show_made_in = true,
        main_product = results[1].name,
    }

    if extra then
        for key, value in pairs(extra) do
            recipe[key] = value
        end
    end

    return recipe
end

local function make_tech_icons(base_icon, overlay_icon)
    return ei_lib.make_icons(base_icon, 256, overlay_icon, 64, 0.4, {8, 8}, nil, {base_mipmaps = 4})
end

local function append_list(target, entries)
    if type(entries) ~= "table" then
        return
    end

    for _, entry in ipairs(entries) do
        target[#target + 1] = table.deepcopy(entry)
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

local function replace_damage_amount(root, damage_type, old_amount, new_amount, limit)
    local replaced = 0

    visit_tables(root, function(node)
        if replaced >= (limit or math.huge) then
            return
        end

        local damage = node.damage
        if type(damage) == "table" and damage.type == damage_type and damage.amount == old_amount then
            damage.amount = new_amount
            replaced = replaced + 1
        end
    end)

    return replaced
end

local function replace_atomic_center_explosion(root, replacement_name)
    visit_tables(root, function(node)
        if node.type == "create-entity" and node.entity_name == "nuke-explosion" then
            node.entity_name = replacement_name
        end
    end)
end

local function replace_created_entity_name(root, source_name, replacement_name, limit)
    local replaced = 0

    visit_tables(root, function(node)
        if replaced >= (limit or math.huge) then
            return
        end

        if node.type == "create-entity" and node.entity_name == source_name then
            node.entity_name = replacement_name
            replaced = replaced + 1
        end
    end)

    return replaced
end

local function replace_projectile_name(root, source_name, replacement_name, limit)
    local replaced = 0

    visit_tables(root, function(node)
        if replaced >= (limit or math.huge) then
            return
        end

        if node.projectile == source_name then
            node.projectile = replacement_name
            replaced = replaced + 1
        end
    end)

    return replaced
end

local function tune_nested_projectile_delivery(root, projectile_name, updates, limit)
    local tuned = 0

    visit_tables(root, function(node)
        if tuned >= (limit or math.huge) then
            return
        end

        local delivery = node.action_delivery
        if type(delivery) ~= "table" or delivery.projectile ~= projectile_name then
            return
        end

        for key, value in pairs(updates) do
            node[key] = value
        end
        tuned = tuned + 1
    end)

    return tuned
end

local function tune_nested_entity_delivery(root, entity_name, updates, limit)
    local tuned = 0

    visit_tables(root, function(node)
        if tuned >= (limit or math.huge) then
            return
        end

        local delivery = node.action_delivery
        if type(delivery) ~= "table" or delivery.type ~= "instant" then
            return
        end

        local target_effects = delivery.target_effects
        if type(target_effects) ~= "table" then
            return
        end

        local effects = target_effects.type and {target_effects} or target_effects
        for _, effect in ipairs(effects) do
            if effect.type == "create-entity" and effect.entity_name == entity_name then
                for key, value in pairs(updates) do
                    node[key] = value
                end
                tuned = tuned + 1
                break
            end
        end
    end)

    return tuned
end

local function ensure_target_effect_list(delivery)
    if type(delivery) ~= "table" then
        return nil
    end

    local target_effects = delivery.target_effects
    if type(target_effects) ~= "table" then
        delivery.target_effects = {}
        return delivery.target_effects
    end

    if target_effects.type then
        delivery.target_effects = {target_effects}
    end

    return delivery.target_effects
end

local function append_action_target_effects(action, effects)
    if type(action) ~= "table" or type(action.action_delivery) ~= "table" then
        return false
    end

    local target_effects = ensure_target_effect_list(action.action_delivery)
    if not target_effects then
        return false
    end

    append_list(target_effects, effects)
    return true
end

local function make_radiological_aftermath(sticker_name, cloud_name, inner_damage, inner_radius, outer_damage, outer_radius, sticker_radius)
    return {
        {
            type = "nested-result",
            action = {
                type = "area",
                radius = inner_radius,
                show_in_tooltip = false,
                trigger_from_target = true,
                action_delivery = {
                    type = "instant",
                    target_effects = {
                        {
                            type = "damage",
                            damage = {amount = inner_damage, type = "ei-radiological"},
                            apply_damage_to_trees = false,
                        },
                    },
                },
            },
        },
        {
            type = "nested-result",
            action = {
                type = "area",
                radius = outer_radius,
                show_in_tooltip = false,
                trigger_from_target = true,
                action_delivery = {
                    type = "instant",
                    target_effects = {
                        {
                            type = "damage",
                            damage = {amount = outer_damage, type = "ei-radiological"},
                            apply_damage_to_trees = false,
                        },
                    },
                },
            },
        },
        {
            type = "nested-result",
            action = {
                type = "area",
                radius = sticker_radius,
                show_in_tooltip = false,
                trigger_from_target = true,
                action_delivery = {
                    type = "instant",
                    target_effects = {
                        {
                            type = "create-sticker",
                            sticker = sticker_name,
                            show_in_tooltip = false,
                        },
                    },
                },
            },
        },
        {
            type = "create-entity",
            entity_name = cloud_name,
            trigger_created_entity = true,
            show_in_tooltip = false,
        },
    }
end

local function make_rocket_projectile(name, source_name, explosion_name, smoke_name, radius, damage_type, damage_amount, sticker_name, extra_actions)
    local projectile = table.deepcopy(data.raw.projectile[source_name])
    local area_effects = {
        {
            type = "damage",
            damage = {
                amount = damage_amount,
                type = damage_type,
            },
            apply_damage_to_trees = false,
        },
        {
            type = "create-trivial-smoke",
            smoke_name = smoke_name,
            repeat_count = 8,
            offset_deviation = {{-2.5, -2.5}, {2.5, 2.5}},
            speed_from_center = 0.045,
            speed_from_center_deviation = 0.02,
            initial_height = 0,
        },
    }

    if sticker_name then
        table.insert(area_effects, 2, {
            type = "create-sticker",
            sticker = sticker_name,
            show_in_tooltip = true,
        })
    end

    projectile.name = name
    local projectile_actions = {
        {
            type = "direct",
            action_delivery = {
                type = "instant",
                target_effects = {
                    {
                        type = "create-entity",
                        entity_name = explosion_name,
                        trigger_created_entity = true,
                    },
                    {
                        type = "create-trivial-smoke",
                        smoke_name = smoke_name,
                        repeat_count = 12,
                        offset_deviation = {{-0.75, -0.75}, {0.75, 0.75}},
                        speed_from_center = 0.03,
                        speed_from_center_deviation = 0.01,
                        initial_height = 0,
                    },
                },
            },
        },
        {
            type = "area",
            radius = radius,
            force = "enemy",
            action_delivery = {
                {
                    type = "instant",
                    target_effects = area_effects,
                },
            },
        },
    }

    append_list(projectile_actions, extra_actions)
    projectile.action = projectile_actions

    return projectile
end

replace_damage_amount(data.raw.projectile["rocket"] and data.raw.projectile["rocket"].action, "explosion", 200, 700, 1)
replace_damage_amount(data.raw.projectile["explosive-rocket"] and data.raw.projectile["explosive-rocket"].action, "explosion", 50, 280, 1)
replace_damage_amount(data.raw.projectile["explosive-rocket"] and data.raw.projectile["explosive-rocket"].action, "explosion", 100, 500, 1)
replace_created_entity_name(
    data.raw.projectile["explosive-rocket"] and data.raw.projectile["explosive-rocket"].action,
    "big-explosion",
    "ei-hand-explosive-rocket-explosion",
    1
)
if data.raw.projectile["rocket"] then
    data.raw.projectile["rocket"].acceleration = 0.0125
end
if data.raw.projectile["explosive-rocket"] then
    data.raw.projectile["explosive-rocket"].acceleration = 0.0125
end
if data.raw.projectile["atomic-rocket"] then
    data.raw.projectile["atomic-rocket"].acceleration = 0.00625
end

local corrosive_rocket = table.deepcopy(data.raw.ammo["rocket"])
corrosive_rocket.name = "ei-corrosive-rocket"
corrosive_rocket.icon = corrosive_rocket_icon
corrosive_rocket.icon_size = 512
corrosive_rocket.icon_mipmaps = 5
corrosive_rocket.icons = nil
corrosive_rocket.order = "d[rocket-launcher]-c[ei-corrosive-rocket]"
corrosive_rocket.ammo_type.action.action_delivery.projectile = "ei-corrosive-rocket-projectile"

local cryo_rocket = table.deepcopy(data.raw.ammo["rocket"])
cryo_rocket.name = "ei-cryo-rocket"
cryo_rocket.icon = cryo_rocket_icon
cryo_rocket.icon_size = 512
cryo_rocket.icon_mipmaps = 5
cryo_rocket.icons = nil
cryo_rocket.order = "d[rocket-launcher]-d[ei-cryo-rocket]"
cryo_rocket.ammo_type.action.action_delivery.projectile = "ei-cryo-rocket-projectile"

local corrosive_secondary_effects = {
    {
        type = "create-sticker",
        sticker = "ei-corrosive-rocket-sticker",
        show_in_tooltip = true,
    },
}

if data.raw.sticker["ei-corrosive-rocket-toxic-sticker"] then
    corrosive_secondary_effects[#corrosive_secondary_effects + 1] = {
        type = "create-sticker",
        sticker = "ei-corrosive-rocket-toxic-sticker",
        show_in_tooltip = false,
    }
end

corrosive_secondary_effects[#corrosive_secondary_effects + 1] = {
    type = "damage",
    damage = {
        amount = 48,
        type = "acid",
    },
    apply_damage_to_trees = false,
}

local corrosive_projectile = make_rocket_projectile(
    "ei-corrosive-rocket-projectile",
    "explosive-rocket",
    "ei-corrosive-rocket-explosion",
    "ei-corrosive-rocket-smoke",
    6.5,
    "acid",
    450,
    nil,
    {
        {
            type = "direct",
            action_delivery = {
                type = "instant",
                target_effects = {
                    {
                        type = "create-entity",
                        entity_name = "ei-corrosive-rocket-cloud",
                        trigger_created_entity = true,
                    },
                },
            },
        },
        {
            type = "area",
            radius = 3.75,
            force = "enemy",
            show_in_tooltip = false,
            action_delivery = {
                type = "instant",
                target_effects = corrosive_secondary_effects,
            },
        },
    }
)

local cryo_secondary_effects = {
    {
        type = "damage",
        damage = {
            amount = 24,
            type = "cold",
        },
        apply_damage_to_trees = false,
    },
}

local cryo_projectile = make_rocket_projectile(
    "ei-cryo-rocket-projectile",
    "rocket",
    "ei-cryo-rocket-explosion",
    "ei-cryo-rocket-smoke",
    5.5,
    "cold",
    450,
    "ei-cryo-rocket-sticker",
    {
        {
            type = "area",
            radius = 3.75,
            force = "enemy",
            show_in_tooltip = false,
            action_delivery = {
                type = "instant",
                target_effects = cryo_secondary_effects,
            },
        },
    }
)

local atomic_bomb_u235
local atomic_rocket_u235

if data.raw.ammo["atomic-bomb"] and data.raw.projectile["atomic-rocket"] then
    data.raw.ammo["atomic-bomb"].localised_name = {"item-name.ei-atomic-bomb-plutonium"}
    data.raw.ammo["atomic-bomb"].icon = atomic_bomb_plutonium_icon
    data.raw.ammo["atomic-bomb"].icon_size = 512
    data.raw.ammo["atomic-bomb"].icon_mipmaps = 5
    data.raw.ammo["atomic-bomb"].icons = nil
    data.raw.ammo["atomic-bomb"].pictures = nil

    atomic_bomb_u235 = table.deepcopy(data.raw.ammo["atomic-bomb"])
    atomic_bomb_u235.name = "ei-atomic-bomb-u235"
    atomic_bomb_u235.icon = atomic_bomb_u235_icon
    atomic_bomb_u235.icon_size = 512
    atomic_bomb_u235.icon_mipmaps = 5
    atomic_bomb_u235.icons = nil
    atomic_bomb_u235.pictures = nil
    atomic_bomb_u235.localised_name = {"item-name.ei-atomic-bomb-u235"}
    atomic_bomb_u235.order = "d[rocket-launcher]-e[ei-atomic-bomb-u235]"
    atomic_bomb_u235.ammo_type.action.action_delivery.projectile = "ei-atomic-rocket-u235"

    atomic_rocket_u235 = table.deepcopy(data.raw.projectile["atomic-rocket"])
    atomic_rocket_u235.name = "ei-atomic-rocket-u235"
    atomic_rocket_u235.acceleration = 0.00625
    replace_damage_amount(atomic_rocket_u235.action, "explosion", 400, 300, 1)
    replace_atomic_center_explosion(atomic_rocket_u235.action, "ei-atomic-u235-center-explosion")
    replace_projectile_name(
        atomic_rocket_u235.action,
        "atomic-bomb-ground-zero-projectile",
        "ei-atomic-u235-ground-zero-projectile",
        1
    )
    replace_projectile_name(atomic_rocket_u235.action, "atomic-bomb-wave", "ei-atomic-u235-wave", 1)
    tune_nested_projectile_delivery(atomic_rocket_u235.action, "ei-atomic-u235-ground-zero-projectile", {
        repeat_count = 800,
        radius = 6,
    }, 1)
    tune_nested_projectile_delivery(atomic_rocket_u235.action, "ei-atomic-u235-wave", {
        repeat_count = 800,
        radius = 30,
    }, 1)
    tune_nested_projectile_delivery(atomic_rocket_u235.action, "atomic-bomb-wave-spawns-cluster-nuke-explosion", {
        repeat_count = 700,
        radius = 20,
    }, 1)
    tune_nested_projectile_delivery(atomic_rocket_u235.action, "atomic-bomb-wave-spawns-fire-smoke-explosion", {
        repeat_count = 500,
        radius = 3,
    }, 1)
    tune_nested_projectile_delivery(atomic_rocket_u235.action, "atomic-bomb-wave-spawns-nuke-shockwave-explosion", {
        repeat_count = 700,
        radius = 6,
    }, 1)
    tune_nested_projectile_delivery(atomic_rocket_u235.action, "atomic-bomb-wave-spawns-nuclear-smoke", {
        repeat_count = 180,
        radius = 20,
    }, 1)
    tune_nested_entity_delivery(atomic_rocket_u235.action, "nuclear-smouldering-smoke-source", {
        repeat_count = 7,
        radius = 6,
    }, 1)
    append_action_target_effects(
        atomic_rocket_u235.action,
        make_radiological_aftermath(
            "ei-radiological-fallout-sticker-u235",
            "ei-radiological-fallout-cloud-u235",
            18,
            6,
            8,
            16,
            5
        )
    )
    append_action_target_effects(
        data.raw.projectile["atomic-rocket"].action,
        make_radiological_aftermath(
            "ei-radiological-fallout-sticker-plutonium",
            "ei-radiological-fallout-cloud-plutonium",
            24,
            8,
            10,
            20,
            7
        )
    )
end

if atomic_rocket_u235 and atomic_bomb_u235 then
    data:extend({
        atomic_rocket_u235,
        atomic_bomb_u235,
    })
end

data:extend({
    {
        type = "item",
        name = "ei-rocket-airframe",
        icon = rocket_airframe_icon,
        icon_size = 512,
        icon_mipmaps = 5,
        subgroup = "intermediate-product",
        order = "p[rocket-fuel]-c[ei-rocket-airframe]",
        stack_size = 100,
    },
    {
        type = "item",
        name = "ei-rocket-motor-basic",
        icon = rocket_motor_basic_icon,
        icon_size = 512,
        icon_mipmaps = 5,
        subgroup = "intermediate-product",
        order = "p[rocket-fuel]-d[ei-rocket-motor-basic]",
        stack_size = 100,
    },
    {
        type = "item",
        name = "ei-rocket-motor-high-energy",
        icon = rocket_motor_high_energy_icon,
        icon_size = 512,
        icon_mipmaps = 5,
        subgroup = "intermediate-product",
        order = "p[rocket-fuel]-e[ei-rocket-motor-high-energy]",
        stack_size = 100,
    },
    {
        type = "item",
        name = "ei-rocket-warhead-impact",
        icon = rocket_warhead_impact_icon,
        icon_size = 512,
        icon_mipmaps = 5,
        subgroup = "intermediate-product",
        order = "p[rocket-fuel]-f[ei-rocket-warhead-impact]",
        stack_size = 100,
    },
    {
        type = "item",
        name = "ei-rocket-warhead-explosive",
        icon = rocket_warhead_explosive_icon,
        icon_size = 512,
        icon_mipmaps = 5,
        subgroup = "intermediate-product",
        order = "p[rocket-fuel]-g[ei-rocket-warhead-explosive]",
        stack_size = 100,
    },
    {
        type = "item",
        name = "ei-rocket-warhead-siege",
        icon = rocket_warhead_siege_icon,
        icon_size = 512,
        icon_mipmaps = 5,
        subgroup = "intermediate-product",
        order = "p[rocket-fuel]-h[ei-rocket-warhead-siege]",
        stack_size = 100,
    },
    {
        type = "item",
        name = "ei-rocket-warhead-corrosive",
        icon = rocket_warhead_corrosive_icon,
        icon_size = 512,
        icon_mipmaps = 5,
        subgroup = "intermediate-product",
        order = "p[rocket-fuel]-i[ei-rocket-warhead-corrosive]",
        stack_size = 100,
    },
    {
        type = "item",
        name = "ei-rocket-warhead-cryo",
        icon = rocket_warhead_cryo_icon,
        icon_size = 512,
        icon_mipmaps = 5,
        subgroup = "intermediate-product",
        order = "p[rocket-fuel]-j[ei-rocket-warhead-cryo]",
        stack_size = 100,
    },
    {
        type = "item",
        name = "ei-rocket-warhead-atomic-u235",
        icon = rocket_warhead_atomic_u235_icon,
        icon_size = 512,
        icon_mipmaps = 5,
        subgroup = "intermediate-product",
        order = "p[rocket-fuel]-k[ei-rocket-warhead-atomic-u235]",
        stack_size = 20,
    },
    {
        type = "item",
        name = "ei-rocket-warhead-atomic-plutonium",
        icon = rocket_warhead_atomic_plutonium_icon,
        icon_size = 512,
        icon_mipmaps = 5,
        subgroup = "intermediate-product",
        order = "p[rocket-fuel]-l[ei-rocket-warhead-atomic-plutonium]",
        stack_size = 20,
    },

    make_recipe(
        "ei-rocket-airframe",
        4,
        {
            {type = "item", name = "low-density-structure", amount = 1},
            {type = "item", name = "iron-stick", amount = 4},
            {type = "item", name = "electronic-circuit", amount = 1},
        },
        {
            {type = "item", name = "ei-rocket-airframe", amount = 1},
        },
        {
            icons = ei_lib.make_icons(rocket_airframe_icon, 512, low_density_structure_icon, 64, 0.36, {8, 8}, nil, {base_mipmaps = 5}),
        }
    ),
    make_recipe(
        "ei-rocket-motor-basic",
        3,
        {
            {type = "item", name = "engine-unit", amount = 1},
            {type = "item", name = "solid-fuel", amount = 1},
            {type = "item", name = "electronic-circuit", amount = 1},
        },
        {
            {type = "item", name = "ei-rocket-motor-basic", amount = 1},
        },
        {
            icons = ei_lib.make_icons(rocket_motor_basic_icon, 512, engine_icon, 64, 0.4, {8, 8}, nil, {base_mipmaps = 5}),
        }
    ),
    make_recipe(
        "ei-rocket-motor-high-energy",
        6,
        {
            {type = "item", name = "ei-rocket-motor-basic", amount = 2},
            {type = "item", name = "ei-advanced-rocket-fuel", amount = 1},
            {type = "item", name = "processing-unit", amount = 2},
            {type = "item", name = "ei-ceramic", amount = 2},
        },
        {
            {type = "item", name = "ei-rocket-motor-high-energy", amount = 2},
        },
        {
            icons = ei_lib.make_icons(rocket_motor_high_energy_icon, 512, advanced_rocket_fuel_icon, 64, 0.45, {8, 8}, nil, {base_mipmaps = 5}),
        }
    ),
    make_recipe(
        "ei-rocket-warhead-impact",
        3,
        {
            {type = "item", name = "explosives", amount = 1},
            {type = "item", name = "steel-plate", amount = 1},
            {type = "item", name = "iron-stick", amount = 2},
        },
        {
            {type = "item", name = "ei-rocket-warhead-impact", amount = 1},
        },
        {
            icons = ei_lib.make_icons(rocket_warhead_impact_icon, 512, explosives_icon, 64, 0.4, {8, 8}, nil, {base_mipmaps = 5}),
        }
    ),
    make_recipe(
        "ei-rocket-warhead-explosive",
        5,
        {
            {type = "item", name = "ei-rocket-warhead-impact", amount = 1},
            {type = "item", name = "explosives", amount = 2},
            {type = "item", name = "plastic-bar", amount = 2},
        },
        {
            {type = "item", name = "ei-rocket-warhead-explosive", amount = 1},
        },
        {
            icons = ei_lib.make_icons(rocket_warhead_explosive_icon, 512, explosives_icon, 64, 0.4, {8, 8}, nil, {base_mipmaps = 5}),
        }
    ),
    make_recipe(
        "ei-rocket-warhead-siege",
        8,
        {
            {type = "item", name = "ei-rocket-warhead-explosive", amount = 1},
            {type = "item", name = "explosives", amount = 4},
            {type = "item", name = "steel-plate", amount = 2},
            {type = "item", name = "concrete", amount = 4},
        },
        {
            {type = "item", name = "ei-rocket-warhead-siege", amount = 1},
        },
        {
            icons = ei_lib.make_icons(rocket_warhead_siege_icon, 512, artillery_shell_icon, 64, 0.4, {8, 8}, nil, {base_mipmaps = 5}),
        }
    ),
    make_recipe(
        "ei-rocket-warhead-corrosive",
        8,
        {
            {type = "item", name = "ei-rocket-warhead-explosive", amount = 1},
            {type = "item", name = "sulfur", amount = 4},
            {type = "item", name = "ei-ceramic", amount = 2},
            {type = "fluid", name = "ei-nitric-acid", amount = 30},
            {type = "fluid", name = "ei-bio-oil", amount = 20},
        },
        {
            {type = "item", name = "ei-rocket-warhead-corrosive", amount = 1},
        },
        {
            category = "chemistry",
            crafting_machine_tint = {
                primary = {r = 0.22, g = 0.62, b = 0.18, a = 1},
                secondary = {r = 0.12, g = 0.35, b = 0.08, a = 1},
                tertiary = {r = 0.6, g = 0.9, b = 0.25, a = 1},
                quaternary = {r = 0.14, g = 0.3, b = 0.08, a = 1},
            },
            icons = ei_lib.make_icons(rocket_warhead_corrosive_icon, 512, nitric_acid_icon, 64, 0.45, {8, 8}, nil, {base_mipmaps = 5}),
        }
    ),
    make_recipe(
        "ei-rocket-warhead-cryo",
        8,
        {
            {type = "item", name = "ei-rocket-warhead-impact", amount = 1},
            {type = "item", name = "ei-cryodust", amount = 4},
            {type = "item", name = "ei-condensed-cryodust", amount = 1},
            {type = "item", name = "ei-ceramic", amount = 2},
        },
        {
            {type = "item", name = "ei-rocket-warhead-cryo", amount = 1},
        },
        {
            icons = ei_lib.make_icons(rocket_warhead_cryo_icon, 512, cryodust_icon, 64, 0.45, {8, 8}, nil, {base_mipmaps = 5}),
        }
    ),
    make_recipe(
        "ei-rocket-warhead-atomic-u235",
        12,
        {
            {type = "item", name = "uranium-235", amount = 10},
            {type = "item", name = "processing-unit", amount = 10},
            {type = "item", name = "explosives", amount = 10},
            {type = "item", name = "ei-lead-ingot", amount = 8},
            {type = "item", name = "ei-ceramic", amount = 12},
        },
        {
            {type = "item", name = "ei-rocket-warhead-atomic-u235", amount = 1},
        },
        {
            allow_productivity = false,
            icons = ei_lib.make_icons(rocket_warhead_atomic_u235_icon, 512, uranium_235_icon, 64, 0.45, {8, 8}, nil, {base_mipmaps = 5}),
        }
    ),
    make_recipe(
        "ei-rocket-warhead-atomic-plutonium",
        14,
        {
            {type = "item", name = "ei-plutonium-239", amount = 6},
            {type = "item", name = "uranium-238", amount = 20},
            {type = "item", name = "processing-unit", amount = 10},
            {type = "item", name = "explosives", amount = 10},
            {type = "item", name = "ei-lead-ingot", amount = 8},
            {type = "item", name = "ei-ceramic", amount = 12},
        },
        {
            {type = "item", name = "ei-rocket-warhead-atomic-plutonium", amount = 1},
        },
        {
            allow_productivity = false,
            icons = ei_lib.make_icons(rocket_warhead_atomic_plutonium_icon, 512, plutonium_icon, 64, 0.45, {8, 8}, nil, {base_mipmaps = 5}),
        }
    ),
    make_recipe(
        "ei-corrosive-rocket",
        5,
        {
            {type = "item", name = "ei-rocket-airframe", amount = 1},
            {type = "item", name = "ei-rocket-motor-high-energy", amount = 1},
            {type = "item", name = "ei-rocket-warhead-corrosive", amount = 1},
        },
        {
            {type = "item", name = "ei-corrosive-rocket", amount = 1},
        },
        {
            icons = ei_lib.make_icons(corrosive_rocket_icon, 512, nitric_acid_icon, 64, 0.45, {8, 8}, nil, {base_mipmaps = 5}),
        }
    ),
    make_recipe(
        "ei-cryo-rocket",
        5,
        {
            {type = "item", name = "ei-rocket-airframe", amount = 1},
            {type = "item", name = "ei-rocket-motor-high-energy", amount = 1},
            {type = "item", name = "ei-rocket-warhead-cryo", amount = 1},
        },
        {
            {type = "item", name = "ei-cryo-rocket", amount = 1},
        },
        {
            icons = ei_lib.make_icons(cryo_rocket_icon, 512, cryodust_icon, 64, 0.45, {8, 8}, nil, {base_mipmaps = 5}),
        }
    ),
    make_recipe(
        "atomic-bomb-u235",
        10,
        {
            {type = "item", name = "ei-rocket-airframe", amount = 1},
            {type = "item", name = "ei-rocket-motor-high-energy", amount = 1},
            {type = "item", name = "ei-rocket-warhead-atomic-u235", amount = 1},
        },
        {
            {type = "item", name = "ei-atomic-bomb-u235", amount = 1},
        },
        {
            allow_productivity = false,
            icons = ei_lib.make_icons(atomic_bomb_u235_icon, 512, uranium_235_icon, 64, 0.45, {8, 8}, nil, {base_mipmaps = 5}),
        }
    ),
    make_recipe(
        "atomic-bomb-plutonium",
        10,
        {
            {type = "item", name = "ei-rocket-airframe", amount = 1},
            {type = "item", name = "ei-rocket-motor-high-energy", amount = 1},
            {type = "item", name = "ei-rocket-warhead-atomic-plutonium", amount = 1},
        },
        {
            {type = "item", name = "atomic-bomb", amount = 1},
        },
        {
            allow_productivity = false,
            icons = ei_lib.make_icons(atomic_bomb_plutonium_icon, 512, plutonium_icon, 64, 0.45, {8, 8}, nil, {base_mipmaps = 5}),
        }
    ),

    corrosive_projectile,
    cryo_projectile,
    corrosive_rocket,
    cryo_rocket,

    {
        type = "technology",
        name = "ei-corrosive-rocketry",
        icons = make_tech_icons(corrosive_rocketry_tech_icon, nitric_acid_icon),
        prerequisites = {
            "explosive-rocketry",
            "ei-acidthrower-turret",
            "ei-purifier",
            "ei-nitric-acid",
            "ei-bio-oil",
            "ei-advanced-rocket-fuel",
        },
        effects = {
            {
                type = "unlock-recipe",
                recipe = "ei-rocket-warhead-corrosive",
            },
            {
                type = "unlock-recipe",
                recipe = "ei-corrosive-rocket",
            },
        },
        unit = {
            count = 150,
            ingredients = ei_data.science["advanced-computer-age"],
            time = 20,
        },
        age = "advanced-computer-age",
        order = "e-c-c",
    },
    {
        type = "technology",
        name = "ei-cryo-rocketry",
        icons = make_tech_icons(cryo_rocketry_tech_icon, cryodust_icon),
        prerequisites = {
            "explosive-rocketry",
            "ei-cryodust",
            "ei-advanced-motor-cryodust",
            "ei-advanced-rocket-fuel",
        },
        effects = {
            {
                type = "unlock-recipe",
                recipe = "ei-rocket-warhead-cryo",
            },
            {
                type = "unlock-recipe",
                recipe = "ei-cryo-rocket",
            },
        },
        unit = {
            count = 175,
            ingredients = ei_data.science["both-computer-age"],
            time = 20,
        },
        age = "both-computer-age",
        order = "e-c-d",
    },
    {
        type = "technology",
        name = "ei-plutonium-warheads",
        icons = make_tech_icons(plutonium_warheads_tech_icon, plutonium_icon),
        prerequisites = {
            "atomic-bomb",
            "ei-plutonium-239-recycling",
            "ei-high-temperature-reactor",
            "ei-advanced-computer-age-tech",
        },
        effects = {
            {
                type = "unlock-recipe",
                recipe = "ei-rocket-warhead-atomic-plutonium",
            },
            {
                type = "unlock-recipe",
                recipe = "atomic-bomb-plutonium",
            },
        },
        unit = {
            count = 250,
            ingredients = ei_data.science["advanced-computer-age"],
            time = 30,
        },
        age = "advanced-computer-age",
        order = "g-d-a",
    },
})

local atomic_rocket = data.raw.projectile["atomic-rocket"]
if atomic_rocket then
    local atomic_fx_inserted = false

    local function inject_atomic_fx(root)
        if atomic_fx_inserted or type(root) ~= "table" then
            return
        end

        if type(root.target_effects) == "table" then
            table.insert(root.target_effects, 1, {
                type = "create-entity",
                entity_name = "ei-atomic-rocket-explosion",
                trigger_created_entity = true,
            })
            table.insert(root.target_effects, 2, {
                type = "create-trivial-smoke",
                smoke_name = "ei-atomic-rocket-smoke",
                repeat_count = 20,
                offset_deviation = {{-1.5, -1.5}, {1.5, 1.5}},
                speed_from_center = 0.06,
                speed_from_center_deviation = 0.02,
                initial_height = 0,
            })
            atomic_fx_inserted = true
            return
        end

        for _, value in pairs(root) do
            inject_atomic_fx(value)
        end
    end

    inject_atomic_fx(atomic_rocket.action)
end

if data.raw.technology["atomic-bomb"] then
    data.raw.technology["atomic-bomb"].icon = nil
    data.raw.technology["atomic-bomb"].icon_size = nil
    data.raw.technology["atomic-bomb"].icon_mipmaps = nil
    data.raw.technology["atomic-bomb"].icons = make_tech_icons(atomic_bomb_tech_icon, uranium_235_icon)
end
