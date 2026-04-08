local resource_autoplace = require("__core__/lualib/resource-autoplace")
local base_tile_sounds = require("__base__.prototypes.tile.tile-sounds")

local function gaia_relic_debris_autoplace()
    local autoplace = resource_autoplace.resource_autoplace_settings{
        name = "ei-gaia-relic-debris",
        order = "x1",
        base_density = 0.34,
        richness_multiplier = 1.18,
        richness_multiplier_distance_bonus = 1.25,
        base_spots_per_km2 = 0.075,
        has_starting_area_placement = true,
        random_spot_size_minimum = 0.18,
        random_spot_size_maximum = 0.7,
        random_probability = 1 / 72,
        regular_blob_amplitude_multiplier = 1,
        richness_post_multiplier = 1.0,
        additional_richness = 22000,
        regular_rq_factor_multiplier = 1,
        candidate_spot_count = 12
    }

    autoplace.probability_expression = "clamp((" .. autoplace.probability_expression .. ") * gaia_relic_debris_mask, 0, 1)"
    autoplace.richness_expression = "max(0, (" .. autoplace.richness_expression .. ") * max(0.45, gaia_relic_debris_richness))"

    return autoplace
end

data:extend({
    {
        type = "item",
        name = "ei-gaia-relic-debris",
        icon = "__exotic-space-industries-remembrance__/graphics/icons/gaia-relic-debris.png",
        icon_size = 64,
        icon_mipmaps = 4,
        subgroup = "raw-resource",
        order = "a[scrap]-b[gaia-relic-debris]",
        stack_size = 100
    },
    {
        type = "resource",
        name = "ei-gaia-relic-debris",
        icon = "__exotic-space-industries-remembrance__/graphics/icons/gaia-relic-debris.png",
        icon_size = 64,
        icon_mipmaps = 4,
        flags = {"placeable-neutral"},
        order = "a-b-g",
        tree_removal_probability = 0.45,
        tree_removal_max_distance = 32 * 32,
        minable = {
            mining_particle = "scrap-particle",
            mining_time = 0.6,
            result = "ei-gaia-relic-debris"
        },
        walking_sound = base_tile_sounds.walking.ore,
        collision_box = {{-0.1, -0.1}, {0.1, 0.1}},
        selection_box = {{-0.5, -0.5}, {0.5, 0.5}},
        resource_patch_search_radius = 12,
        autoplace = gaia_relic_debris_autoplace(),
        stage_counts = {15000, 9500, 5500, 2900, 1300, 400, 150, 80},
        stages = {
            sheet = {
                filename = "__exotic-space-industries-remembrance__/graphics/entities/gaia-relic-debris.png",
                priority = "extra-high",
                size = 128,
                frame_count = 8,
                variation_count = 8,
                scale = 0.5
            }
        },
        map_color = {r = 0.62, g = 0.84, b = 0.75},
        mining_visualisation_tint = {r = 0.72, g = 0.92, b = 0.82, a = 1}
    },
    {
        type = "autoplace-control",
        name = "ei-gaia-relic-debris",
        richness = true,
        order = "z4",
        category = "resource",
        localised_name = {"autoplace-control-names.ei-gaia-relic-debris"}
    },
    {
        type = "recipe",
        name = "ei-gaia-relic-debris-recycling",
        icons = {
            {
                icon = "__quality__/graphics/icons/recycling.png"
            },
            {
                icon = "__exotic-space-industries-remembrance__/graphics/icons/gaia-relic-debris.png",
                icon_size = 64,
                icon_mipmaps = 4,
                scale = 0.4
            },
            {
                icon = "__quality__/graphics/icons/recycling-top.png"
            }
        },
        category = "recycling-or-hand-crafting",
        subgroup = "ei-refining-raw",
        order = "z[gaia]-a[relic-debris-recycling]",
        enabled = false,
        auto_recycle = false,
        allow_productivity = true,
        allow_decomposition = false,
        energy_required = 0.35,
        ingredients = {
            {type = "item", name = "ei-gaia-relic-debris", amount = 1}
        },
        results = {
            {type = "item", name = "ei-iron-mechanical-parts", amount = 1, probability = 0.09, show_details_in_recipe_tooltip = false},
            {type = "item", name = "ei-copper-mechanical-parts", amount = 1, probability = 0.08, show_details_in_recipe_tooltip = false},
            {type = "item", name = "ei-steel-mechanical-parts", amount = 1, probability = 0.05, show_details_in_recipe_tooltip = false},
            {type = "item", name = "ei-iron-beam", amount = 1, probability = 0.05, show_details_in_recipe_tooltip = false},
            {type = "item", name = "battery", amount = 1, probability = 0.05, show_details_in_recipe_tooltip = false},
            {type = "item", name = "electronic-circuit", amount = 1, probability = 0.05, show_details_in_recipe_tooltip = false},
            {type = "item", name = "ei-electronic-parts", amount = 1, probability = 0.04, show_details_in_recipe_tooltip = false},
            {type = "item", name = "ei-insulated-wire", amount = 1, probability = 0.03, show_details_in_recipe_tooltip = false},
            {type = "item", name = "advanced-circuit", amount = 1, probability = 0.02, show_details_in_recipe_tooltip = false},
            {type = "item", name = "ei-module-part", amount = 1, probability = 0.02, show_details_in_recipe_tooltip = false},
            {type = "item", name = "stone", amount = 1, probability = 0.06, show_details_in_recipe_tooltip = false},
            {type = "item", name = "concrete", amount = 1, probability = 0.05, show_details_in_recipe_tooltip = false},
            {type = "item", name = "ice", amount = 1, probability = 0.04, show_details_in_recipe_tooltip = false},
            {type = "item", name = "ei-energy-crystal", amount = 1, probability = 0.025, show_details_in_recipe_tooltip = false},
            {type = "item", name = "ei-high-energy-crystal", amount = 1, probability = 0.004, show_details_in_recipe_tooltip = false}
        }
    }
})

ei_lib.add_unlock_recipe("recycling", "ei-gaia-relic-debris-recycling")
