local ei_data = require("lib/data")
local ei_lib = require("lib/lib")
local util = require("util")

local function icon_data(prototype, fallback_icon, fallback_size)
    if prototype and prototype.icons then
        local first = prototype.icons[1]
        if first and first.icon then
            return {
                icon = first.icon,
                icon_size = first.icon_size or prototype.icon_size or fallback_size or 64,
                icon_mipmaps = first.icon_mipmaps or prototype.icon_mipmaps,
            }
        end
    elseif prototype and prototype.icon then
        return {
            icon = prototype.icon,
            icon_size = prototype.icon_size or fallback_size or 64,
            icon_mipmaps = prototype.icon_mipmaps,
        }
    end

    return {icon = fallback_icon, icon_size = fallback_size or 64}
end

local function layered_icons(base, overlay, opts)
    opts = opts or {}
    return {
        icons = {
            {
                icon = base.icon,
                icon_size = base.icon_size,
                icon_mipmaps = base.icon_mipmaps,
            },
            {
                icon = overlay.icon,
                icon_size = overlay.icon_size,
                icon_mipmaps = overlay.icon_mipmaps,
                scale = opts.scale or 0.35,
                shift = opts.shift or {8, 8},
            },
        },
        icon_size = base.icon_size,
    }
end

local steam_icon = icon_data(data.raw.fluid["steam"], "__base__/graphics/icons/fluid/steam.png", 64)
local sulfuric_acid_icon = icon_data(data.raw.fluid["sulfuric-acid"], "__base__/graphics/icons/fluid/sulfuric-acid.png", 64)
local crushed_slag_item_icon = ei_path.."graphics/items/crushed-slag.png"
local auric_slag_icon_1 = ei_path.."graphics/items/auric-slag-1.png"
local auric_slag_icon_2 = ei_path.."graphics/items/auric-slag-2.png"
local auric_slag_icon_3 = ei_path.."graphics/items/auric-slag-3.png"
local carbide_core_item_icon = ei_path.."graphics/items/carbide-precipitation-core.png"

local auric_slag_recipe_icon_2 = {icon = auric_slag_icon_2, icon_size = 64, icon_mipmaps = 4}
local auric_slag_recipe_icon_3 = {icon = auric_slag_icon_3, icon_size = 64, icon_mipmaps = 4}
local auric_vapor_icons = layered_icons(steam_icon, auric_slag_recipe_icon_2)
local auric_vapor_condensation_recipe_icons = layered_icons(auric_slag_recipe_icon_2, steam_icon, {scale = 0.3, shift = {9, 9}})
local auric_slag_washing_recipe_icons = layered_icons(auric_slag_recipe_icon_3, sulfuric_acid_icon, {scale = 0.3, shift = {9, 9}})

local function extraction_result(name, probability, amount_min, amount_max)
    return {type = "item", name = name, amount_min = amount_min, amount_max = amount_max, probability = math.min(1, probability * 1.25)}
end

local function fluid_result(name, amount_min, amount_max, ignored_by_stats)
    return {
        type = "fluid",
        name = name,
        amount_min = math.ceil(amount_min * 1.25),
        amount_max = math.ceil(amount_max * 1.25),
        ignored_by_stats = ignored_by_stats and math.ceil(ignored_by_stats * 1.25) or nil,
    }
end

local auric_fumarole = table.deepcopy(data.raw.resource["sulfuric-acid-geyser"])
auric_fumarole.name = "ei-auric-fumarole"
auric_fumarole.category = "ei-pumping"
auric_fumarole.autoplace = nil
auric_fumarole.infinite = false
auric_fumarole.minimum = 4000
auric_fumarole.normal = 8000
auric_fumarole.map_color = {r = 0.92, g = 0.72, b = 0.18}
auric_fumarole.minable = {
    mining_time = 1,
    fluid_amount = 1,
    required_fluid = "steam",
    results = {
        {type = "fluid", name = "ei-auric-vapor", amount = 20},
    },
}
auric_fumarole.icon = auric_vapor_icons.icons[1].icon
auric_fumarole.icon_size = auric_vapor_icons.icon_size
auric_fumarole.icon_mipmaps = auric_vapor_icons.icons[1].icon_mipmaps
auric_fumarole.icons = auric_vapor_icons.icons

-- Sulfuric geyser ambience already works directly on the resource prototype, so the auric clone
-- follows the same path instead of depending on a hidden helper entity with its own live state.
auric_fumarole.working_sound = {
    sound = {
        category = "world-ambient",
        variations = {
            {
                filename = ei_path.."sounds/auric-fumarole.ogg",
                volume = 0.3,
            },
        },
        advanced_volume_control = {
            fades = {
                fade_in = {
                    curve_type = "S-curve",
                    from = {control = 0.3, volume_percentage = 0.0},
                    to = {2.0, 100.0},
                },
            },
        },
        audible_distance_modifier = 0.3,
    },
    max_sounds_per_prototype = 3,
}

-- The art stays sulfuric-derived on purpose, but the copied vapor and rock are warmed toward
-- auric steam and gold-bearing condensate so players can read the chemistry at a glance.
if auric_fumarole.stages and auric_fumarole.stages.layers and auric_fumarole.stages.layers[1] then
    auric_fumarole.stages.layers[1].tint = {r = 1.0, g = 0.88, b = 0.70, a = 0.22}
end
if auric_fumarole.stateless_visualisation then
    if auric_fumarole.stateless_visualisation[1] and auric_fumarole.stateless_visualisation[1].animation then
        auric_fumarole.stateless_visualisation[1].animation.tint = util.multiply_color({r = 0.96, g = 0.86, b = 0.55}, 0.28)
    end
    if auric_fumarole.stateless_visualisation[2] and auric_fumarole.stateless_visualisation[2].animation then
        auric_fumarole.stateless_visualisation[2].animation.tint = util.multiply_color({r = 1.0, g = 0.92, b = 0.68}, 0.55)
    end
end

local auric_afterglow = {
    type = "animation",
    name = "ei-auric-fumarole-afterglow",
    filename = ei_graphics_other_path.."overload-animation.png",
    draw_as_glow = true,
    line_length = 16,
    width = 592 / 16,
    height = 35,
    frame_count = 16,
    animation_speed = 0.4,
    scale = 1.6,
    tint = {r = 1, g = 0.72, b = 0.14, a = 0.9},
}

data:extend({
    auric_fumarole,
    {
        type = "fluid",
        name = "ei-auric-vapor",
        icons = auric_vapor_icons.icons,
        icon_size = auric_vapor_icons.icon_size,
        default_temperature = 500,
        max_temperature = 1000,
        gas_temperature = 500,
        heat_capacity = "1kJ",
        base_color = {r = 0.97, g = 0.76, b = 0.21},
        flow_color = {r = 1, g = 0.88, b = 0.42},
        subgroup = "ei-refining-molten",
        order = "z[auric-vapor]",
        auto_barrel = false,
    },
    {
        type = "item",
        name = "ei-auric-slag",
        icon = auric_slag_icon_1,
        icon_size = 256,
        icon_mipmaps = 5,
        pictures = {
            {
                filename = auric_slag_icon_1,
                size = 256,
                icon_mipmaps = 5,
                scale = 0.125,
            },
            {
                filename = auric_slag_icon_2,
                size = 64,
                icon_mipmaps = 4,
                scale = 0.5,
            },
            {
                filename = auric_slag_icon_3,
                size = 64,
                icon_mipmaps = 4,
                scale = 0.5,
            },
        },
        stack_size = 100,
        subgroup = "ei-refining-byproduct",
        order = "z[auric-slag]",
    },
    {
        type = "item",
        name = "ei-crushed-slag",
        icon = crushed_slag_item_icon,
        icon_size = 64,
        icon_mipmaps = 4,
        stack_size = 100,
        subgroup = "ei-refining-crushed",
        order = "z[crushed-slag]",
    },
    {
        type = "item",
        name = "ei-carbide-precipitation-core",
        icon = carbide_core_item_icon,
        icon_size = 256,
        icon_mipmaps = 5,
        stack_size = 50,
        subgroup = "intermediate-product",
        order = "z[carbide-precipitation-core]",
    },
    auric_afterglow,
    {
        type = "recipe",
        name = "ei-slag-crushing",
        category = "ei-crushing",
        energy_required = 2,
        ingredients = {
            {type = "item", name = "ei-slag", amount = 5},
        },
        results = {
            {type = "item", name = "ei-crushed-slag", amount = 10},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-crushed-slag",
    },
    {
        type = "recipe",
        name = "ei-carbide-precipitation-core",
        category = "crafting",
        energy_required = 6,
        ingredients = {
            {type = "item", name = "tungsten-carbide", amount = 2},
            {type = "item", name = "ei-crushed-slag", amount = 8},
            {type = "item", name = "calcite", amount = 1},
        },
        results = {
            {type = "item", name = "ei-carbide-precipitation-core", amount = 1},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-carbide-precipitation-core",
        icon = carbide_core_item_icon,
        icon_size = 256,
        icon_mipmaps = 5,
    },
    {
        type = "recipe",
        name = "ei-auric-vapor-condensation",
        category = "ei-purifier",
        energy_required = 10,
        ingredients = {
            {type = "fluid", name = "ei-auric-vapor", amount = 200},
            {type = "item", name = "ei-carbide-precipitation-core", amount = 1},
        },
        results = {
            {type = "fluid", name = "steam", amount_min = 90, amount_max = 110, temperature = 500},
            {type = "fluid", name = "ei-dirty-water", amount_min = 25, amount_max = 55, ignored_by_stats = 55},
            {type = "item", name = "ei-auric-slag", amount_min = 40, amount_max = 50},
        },
        always_show_made_in = true,
        allow_productivity = false,
        enabled = false,
        main_product = "ei-auric-slag",
        icons = auric_vapor_condensation_recipe_icons.icons,
        icon_size = auric_vapor_condensation_recipe_icons.icon_size,
        subgroup = "ei-refining-purified",
        order = "z[auric-vapor-condensation]",
    },
    {
        type = "recipe",
        name = "ei-auric-slag-washing",
        category = "ei-purifier",
        energy_required = 8,
        ingredients = {
            {type = "item", name = "ei-auric-slag", amount = 100},
            {type = "fluid", name = "sulfuric-acid", amount = 50},
            {type = "fluid", name = "water", amount = 25},
        },
        results = {
            {type = "item", name = "ei-gold-chunk", amount_min = 4, amount_max = 6},
            {type = "item", name = "ei-slag", amount_min = 8, amount_max = 12, ignored_by_stats = 12},
            {type = "fluid", name = "ei-dirty-water", amount_min = 30, amount_max = 50, ignored_by_stats = 50},
        },
        always_show_made_in = true,
        allow_productivity = false,
        enabled = false,
        main_product = "ei-gold-chunk",
        icons = auric_slag_washing_recipe_icons.icons,
        icon_size = auric_slag_washing_recipe_icons.icon_size,
        subgroup = "ei-refining-extraction",
        order = "z[auric-slag-washing]",
    },
    {
        type = "recipe",
        name = "ei-slag-extraction-sulfuric-crushed",
        category = "ei-purifier",
        energy_required = 10,
        ingredients = {
            {type = "fluid", name = "sulfuric-acid", amount = 100},
            {type = "item", name = "ei-crushed-slag", amount = 200},
        },
        results = {
            fluid_result("ei-acidic-water", 15, 45, 45),
            extraction_result("ei-coal-chunk", 0.075, 0, 1),
            extraction_result("ei-iron-chunk", 0.05, 0, 1),
            extraction_result("ei-copper-chunk", 0.04, 0, 1),
            extraction_result("ei-gold-chunk", 0.02, 0, 1),
            extraction_result("ei-lead-chunk", 0.03, 0, 1),
            extraction_result("ei-sulfur-chunk", 0.035, 0, 1),
            extraction_result("ei-uranium-chunk", 0.0045, 0, 1),
            extraction_result("ei-neodym-chunk", 0.002, 0, 1),
        },
        always_show_made_in = true,
        enabled = false,
        subgroup = "ei-refining-purified",
        order = "z[slag-extraction-sulfuric-crushed]",
        main_product = "ei-acidic-water",
    },
    {
        type = "recipe",
        name = "ei-slag-extraction-nitric-crushed",
        category = "ei-purifier",
        energy_required = 8,
        ingredients = {
            {type = "fluid", name = "ei-nitric-acid", amount = 33},
            {type = "item", name = "ei-crushed-slag", amount = 200},
        },
        results = {
            fluid_result("ei-acidic-water", 5, 15, 15),
            extraction_result("ei-coal-chunk", 0.15, 0, 2),
            extraction_result("ei-iron-chunk", 0.1, 0, 2),
            extraction_result("ei-copper-chunk", 0.08, 0, 2),
            extraction_result("ei-gold-chunk", 0.04, 0, 2),
            extraction_result("ei-lead-chunk", 0.06, 0, 2),
            extraction_result("ei-sulfur-chunk", 0.07, 0, 2),
            extraction_result("ei-uranium-chunk", 0.009, 0, 2),
            extraction_result("ei-neodym-chunk", 0.004, 0, 2),
        },
        always_show_made_in = true,
        enabled = false,
        subgroup = "ei-refining-purified",
        order = "z[slag-extraction-nitric-crushed]",
        main_product = "ei-acidic-water",
    },
    {
        type = "recipe",
        name = "ei-slag-extraction-morphium-crushed",
        category = "ei-purifier",
        energy_required = 6,
        ingredients = {
            {type = "fluid", name = "ei-morphium", amount = 10},
            {type = "item", name = "ei-high-energy-crystal", amount = 1},
            {type = "item", name = "ei-crushed-slag", amount = 200},
        },
        results = {
            fluid_result("ei-bio-sludge", 1, 2, 2),
            {type = "item", name = "ei-high-energy-crystal", amount = 1, probability = 0.98, ignored_by_stats = 1},
            {type = "item", name = "ei-energy-crystal", amount = 1, probability = 0.02, ignored_by_stats = 1},
            extraction_result("ei-coal-chunk", 0.3, 1, 3),
            extraction_result("ei-iron-chunk", 0.2, 1, 3),
            extraction_result("ei-copper-chunk", 0.16, 1, 3),
            extraction_result("ei-gold-chunk", 0.08, 1, 3),
            extraction_result("ei-lead-chunk", 0.12, 1, 3),
            extraction_result("ei-sulfur-chunk", 0.14, 1, 3),
            extraction_result("ei-uranium-chunk", 0.018, 1, 3),
            extraction_result("ei-neodym-chunk", 0.008, 1, 3),
        },
        always_show_made_in = true,
        enabled = false,
        subgroup = "ei-refining-purified",
        order = "z[slag-extraction-morphium-crushed]",
        main_product = "ei-bio-sludge",
    },
    {
        type = "technology",
        name = "ei-auric-precipitation",
        icon = auric_slag_icon_1,
        icon_size = 256,
        icon_mipmaps = 5,
        prerequisites = {"planet-discovery-vulcanus", "ei-purifier", "tungsten-carbide"},
        effects = {
            {type = "unlock-recipe", recipe = "ei-carbide-precipitation-core"},
            {type = "unlock-recipe", recipe = "ei-auric-vapor-condensation"},
            {type = "unlock-recipe", recipe = "ei-auric-slag-washing"},
        },
        unit = {
            count = 120,
            ingredients = ei_data.science["computer-age-space-vulcanus"] or ei_data.science["computer-age-space"],
            time = 20,
        },
        age = "computer-age",
    },
})

ei_lib.add_unlock_recipe("ei-purifier", "ei-slag-crushing")
ei_lib.add_unlock_recipe("ei-purifier", "ei-slag-extraction-sulfuric-crushed")
ei_lib.add_unlock_recipe("ei-nitric-acid", "ei-slag-extraction-nitric-crushed")
ei_lib.add_unlock_recipe("ei-morphium-usage", "ei-slag-extraction-morphium-crushed")
