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
local rocket_parts_icon = ei_graphics_3_path .. "graphics/items/rocket-parts.png"

local function make_icons(base_icon, base_size, overlay_icon, overlay_size, overlay_scale, overlay_shift, overlay_tint)
    local icons = {
        {
            icon = base_icon,
            icon_size = base_size,
        },
    }

    if overlay_icon then
        icons[#icons + 1] = {
            icon = overlay_icon,
            icon_size = overlay_size or 64,
            scale = overlay_scale or 0.45,
            shift = overlay_shift or {8, 8},
            tint = overlay_tint,
        }
    end

    return icons
end

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

local function make_rocket_projectile(name, source_name, explosion_name, smoke_name, radius, damage_type, damage_amount, sticker_name)
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
    projectile.action = {
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

    return projectile
end

local corrosive_rocket = table.deepcopy(data.raw.ammo["rocket"])
corrosive_rocket.name = "ei-corrosive-rocket"
corrosive_rocket.icon = nil
corrosive_rocket.icon_size = nil
corrosive_rocket.icons = make_icons(rocket_icon, 64, nitric_acid_icon, 64, 0.45, {8, 8})
corrosive_rocket.order = "d[rocket-launcher]-c[ei-corrosive-rocket]"
corrosive_rocket.ammo_type.action.action_delivery.projectile = "ei-corrosive-rocket-projectile"

local cryo_rocket = table.deepcopy(data.raw.ammo["rocket"])
cryo_rocket.name = "ei-cryo-rocket"
cryo_rocket.icon = nil
cryo_rocket.icon_size = nil
cryo_rocket.icons = make_icons(rocket_icon, 64, cryodust_icon, 64, 0.45, {8, 8})
cryo_rocket.order = "d[rocket-launcher]-d[ei-cryo-rocket]"
cryo_rocket.ammo_type.action.action_delivery.projectile = "ei-cryo-rocket-projectile"

local corrosive_projectile = make_rocket_projectile(
    "ei-corrosive-rocket-projectile",
    "explosive-rocket",
    "ei-corrosive-rocket-explosion",
    "ei-corrosive-rocket-smoke",
    6.5,
    "acid",
    180,
    "ei-corrosive-rocket-sticker"
)

local cryo_projectile = make_rocket_projectile(
    "ei-cryo-rocket-projectile",
    "rocket",
    "ei-cryo-rocket-explosion",
    "ei-cryo-rocket-smoke",
    5.5,
    "cold",
    55,
    "ei-cryo-rocket-sticker"
)

data:extend({
    {
        type = "item",
        name = "ei-rocket-airframe",
        icon = rocket_parts_icon,
        icon_size = 512,
        icon_mipmaps = 5,
        subgroup = "intermediate-product",
        order = "p[rocket-fuel]-c[ei-rocket-airframe]",
        stack_size = 100,
    },
    {
        type = "item",
        name = "ei-rocket-motor-basic",
        icons = make_icons(engine_icon, 64, rocket_icon, 64, 0.4, {8, 8}),
        subgroup = "intermediate-product",
        order = "p[rocket-fuel]-d[ei-rocket-motor-basic]",
        stack_size = 100,
    },
    {
        type = "item",
        name = "ei-rocket-motor-high-energy",
        icons = make_icons(engine_icon, 64, advanced_rocket_fuel_icon, 64, 0.45, {8, 8}),
        subgroup = "intermediate-product",
        order = "p[rocket-fuel]-e[ei-rocket-motor-high-energy]",
        stack_size = 100,
    },
    {
        type = "item",
        name = "ei-rocket-warhead-impact",
        icons = make_icons(rocket_icon, 64, explosives_icon, 64, 0.4, {8, 8}),
        subgroup = "intermediate-product",
        order = "p[rocket-fuel]-f[ei-rocket-warhead-impact]",
        stack_size = 100,
    },
    {
        type = "item",
        name = "ei-rocket-warhead-explosive",
        icon = explosive_rocket_icon,
        icon_size = 64,
        subgroup = "intermediate-product",
        order = "p[rocket-fuel]-g[ei-rocket-warhead-explosive]",
        stack_size = 100,
    },
    {
        type = "item",
        name = "ei-rocket-warhead-siege",
        icons = make_icons(explosive_rocket_icon, 64, artillery_shell_icon, 64, 0.4, {8, 8}),
        subgroup = "intermediate-product",
        order = "p[rocket-fuel]-h[ei-rocket-warhead-siege]",
        stack_size = 100,
    },
    {
        type = "item",
        name = "ei-rocket-warhead-corrosive",
        icons = make_icons(rocket_icon, 64, nitric_acid_icon, 64, 0.45, {8, 8}),
        subgroup = "intermediate-product",
        order = "p[rocket-fuel]-i[ei-rocket-warhead-corrosive]",
        stack_size = 100,
    },
    {
        type = "item",
        name = "ei-rocket-warhead-cryo",
        icons = make_icons(rocket_icon, 64, cryodust_icon, 64, 0.45, {8, 8}),
        subgroup = "intermediate-product",
        order = "p[rocket-fuel]-j[ei-rocket-warhead-cryo]",
        stack_size = 100,
    },
    {
        type = "item",
        name = "ei-rocket-warhead-atomic-u235",
        icons = make_icons(atomic_bomb_icon, 64, uranium_235_icon, 64, 0.45, {8, 8}),
        subgroup = "intermediate-product",
        order = "p[rocket-fuel]-k[ei-rocket-warhead-atomic-u235]",
        stack_size = 20,
    },
    {
        type = "item",
        name = "ei-rocket-warhead-atomic-plutonium",
        icons = make_icons(atomic_bomb_icon, 64, plutonium_icon, 64, 0.45, {8, 8}),
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
            icons = make_icons(rocket_parts_icon, 512, low_density_structure_icon, 64, 0.36, {8, 8}),
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
        }
    ),
    make_recipe(
        "ei-rocket-motor-high-energy",
        6,
        {
            {type = "item", name = "ei-rocket-motor-basic", amount = 1},
            {type = "item", name = "ei-advanced-rocket-fuel", amount = 1},
            {type = "item", name = "processing-unit", amount = 1},
            {type = "item", name = "ei-ceramic", amount = 1},
        },
        {
            {type = "item", name = "ei-rocket-motor-high-energy", amount = 1},
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
            icons = make_icons(atomic_bomb_icon, 64, uranium_235_icon, 64, 0.45, {8, 8}),
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
            icons = make_icons(atomic_bomb_icon, 64, plutonium_icon, 64, 0.45, {8, 8}),
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
            icons = make_icons(rocket_icon, 64, nitric_acid_icon, 64, 0.45, {8, 8}),
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
            icons = make_icons(rocket_icon, 64, cryodust_icon, 64, 0.45, {8, 8}),
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
            {type = "item", name = "atomic-bomb", amount = 1},
        },
        {
            allow_productivity = false,
            icons = make_icons(atomic_bomb_icon, 64, uranium_235_icon, 64, 0.45, {8, 8}),
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
            icons = make_icons(atomic_bomb_icon, 64, plutonium_icon, 64, 0.45, {8, 8}),
        }
    ),

    corrosive_projectile,
    cryo_projectile,
    corrosive_rocket,
    cryo_rocket,

    {
        type = "technology",
        name = "ei-corrosive-rocketry",
        icons = make_icons(rocket_icon, 64, nitric_acid_icon, 64, 0.45, {8, 8}),
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
        icons = make_icons(rocket_icon, 64, cryodust_icon, 64, 0.45, {8, 8}),
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
        icons = make_icons(atomic_bomb_icon, 64, plutonium_icon, 64, 0.45, {8, 8}),
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
