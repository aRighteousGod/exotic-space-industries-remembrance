--====================================================================================================
--TILES FOR GAIA
--====================================================================================================

local grass_variant_weights = {
    max_size = 4,
    [1] = {weights = {0.085, 0.085, 0.085, 0.085, 0.087, 0.085, 0.065, 0.085, 0.045, 0.045, 0.045, 0.045, 0.005, 0.025, 0.045, 0.045}},
    [2] = {probability = 0.91, weights = {0.15, 0.15, 0.15, 0.15, 0.018, 0.02, 0.015, 0.025, 0.015, 0.02, 0.025, 0.015, 0.025, 0.025, 0.01, 0.025}},
    [4] = {probability = 0.82, weights = {0.1, 0.08, 0.08, 0.1, 0.01, 0.01, 0.01, 0.01, 0.01, 0.01, 0.01, 0.01, 0.01, 0.01, 0.01, 0.01}},
}

local rock_variant_weights = {
    max_size = 4,
    [1] = {weights = {0.085, 0.085, 0.085, 0.085, 0.087, 0.085, 0.065, 0.085, 0.045, 0.045, 0.045, 0.045, 0.005, 0.025, 0.045, 0.045}},
    [2] = {probability = 1, weights = {0.07, 0.07, 0.025, 0.07, 0.07, 0.07, 0.007, 0.025, 0.07, 0.05, 0.015, 0.026, 0.03, 0.005, 0.07, 0.027}},
    [4] = {probability = 1, weights = {0.07, 0.07, 0.07, 0.07, 0.07, 0.07, 0.015, 0.07, 0.07, 0.07, 0.015, 0.05, 0.07, 0.07, 0.065, 0.07}},
}

local function gaia_control_multiplier(control_name, size_scale, frequency_scale)
    size_scale = size_scale or 2
    frequency_scale = frequency_scale or 2
    return "(slider_rescale(control:" .. control_name .. ":size, " .. size_scale .. ") * slider_rescale(control:" .. control_name .. ":frequency, " .. frequency_scale .. "))"
end

local function make_gaia_tile(definition)
    local base_tile = data.raw.tile[definition.base_tile]
    local transition_tile = data.raw.tile[definition.transition_tile or definition.base_tile]

    return {
        name = definition.name,
        type = "tile",
        order = definition.order,
        collision_mask = {layers = {ground_tile = true}},
        layer = definition.layer,
        variants = tile_variations_template(
            ei_graphics_terrain_path .. definition.texture,
            definition.mask,
            definition.variant_weights
        ),
        transitions = transition_tile.transitions,
        transitions_between_transitions = transition_tile.transitions_between_transitions,
        autoplace = {
            control = definition.control,
            probability_expression = definition.probability_expression,
        },
        walking_sound = base_tile.walking_sound,
        map_color = definition.map_color,
        scorch_mark_color = base_tile.scorch_mark_color or {r = 0.318, g = 0.222, b = 0.152, a = 1},
        pollution_absorption_per_second = base_tile.pollution_absorption_per_second,
        vehicle_friction_modifier = base_tile.vehicle_friction_modifier,
        trigger_effect = base_tile.trigger_effect,
    }
end

data:extend({
    make_gaia_tile({
        name = "ei-gaia-grass-1",
        base_tile = "grass-1",
        transition_tile = "grass-1",
        texture = "gaia-grass-1_hr.png",
        mask = "__base__/graphics/terrain/masks/transition-3.png",
        variant_weights = grass_variant_weights,
        order = "a[gaia]-a[grass]",
        layer = 55,
        control = "gaia_meadow",
        probability_expression = "clamp(2.2 * gaia_meadow_mask * gaia_select(gaia_variant_noise, -1, 0.62, 0.18, 0.35, 1) * " .. gaia_control_multiplier("gaia_meadow") .. ", 0, 2.4)",
        map_color = {r = 0.12, g = 0.48, b = 0.43},
    }),
    make_gaia_tile({
        name = "ei-gaia-grass-2",
        base_tile = "grass-2",
        transition_tile = "grass-2",
        texture = "gaia-grass-2_hr.png",
        mask = "__base__/graphics/terrain/masks/transition-3.png",
        variant_weights = grass_variant_weights,
        order = "a[gaia]-a[grass]",
        layer = 56,
        control = "gaia_wetlands",
        probability_expression = "clamp(1.85 * gaia_wet_mask * gaia_select(gaia_variant_noise, -1, 0.56, 0.18, 0.28, 1) * " .. gaia_control_multiplier("gaia_wetlands") .. ", 0, 2.0)",
        map_color = {r = 0.18, g = 0.60, b = 0.58},
    }),
    make_gaia_tile({
        name = "ei-gaia-grass-1-var",
        base_tile = "grass-1",
        transition_tile = "grass-1",
        texture = "gaia-grass-1_var_hr.png",
        mask = "__base__/graphics/terrain/masks/transition-3.png",
        variant_weights = grass_variant_weights,
        order = "a[gaia]-a[grass]",
        layer = 57,
        control = "gaia_meadow",
        probability_expression = "clamp(1.45 * gaia_meadow_mask * gaia_select(gaia_variant_noise, 0.58, 1.1, 0.12, 0, 1) * " .. gaia_control_multiplier("gaia_meadow") .. ", 0, 1.45)",
        map_color = {r = 0.18, g = 0.54, b = 0.44},
    }),
    make_gaia_tile({
        name = "ei-gaia-grass-2-var",
        base_tile = "grass-2",
        transition_tile = "grass-2",
        texture = "gaia-grass-2_hr.png",
        mask = "__base__/graphics/terrain/masks/transition-3.png",
        variant_weights = grass_variant_weights,
        order = "a[gaia]-a[grass]",
        layer = 58,
        control = "gaia_wetlands",
        probability_expression = "clamp(0.95 * gaia_wet_mask * gaia_select(gaia_accent_noise, 0.52, 1.08, 0.16, 0, 1) * " .. gaia_control_multiplier("gaia_wetlands") .. ", 0, 1.05)",
        map_color = {r = 0.26, g = 0.66, b = 0.62},
    }),
    make_gaia_tile({
        name = "ei-gaia-grass-2-var-2",
        base_tile = "grass-2",
        transition_tile = "grass-2",
        texture = "gaia-grass-2_var_hr.png",
        mask = "__base__/graphics/terrain/masks/transition-3.png",
        variant_weights = grass_variant_weights,
        order = "a[gaia]-a[grass]",
        layer = 59,
        control = "gaia_wetlands",
        probability_expression = "clamp(1.3 * gaia_wet_mask * gaia_select(gaia_variant_noise, 0.48, 1.08, 0.18, 0, 1) * (0.72 + 0.28 * gaia_accent_noise) * " .. gaia_control_multiplier("gaia_wetlands") .. ", 0, 1.4)",
        map_color = {r = 0.49, g = 0.42, b = 0.58},
    }),
    make_gaia_tile({
        name = "ei-gaia-rock-1",
        base_tile = "dirt-4",
        transition_tile = "grass-3",
        texture = "gaia-rock-1_hr.png",
        mask = "__base__/graphics/terrain/masks/transition-1.png",
        variant_weights = rock_variant_weights,
        order = "a[gaia]-a[rock]",
        layer = 60,
        control = "gaia_rocks",
        probability_expression = "clamp(1.9 * gaia_rock_fringe_mask * gaia_select(gaia_variant_noise, -1, 0.76, 0.16, 0.22, 1) * " .. gaia_control_multiplier("gaia_rocks") .. ", 0, 2.0)",
        map_color = {r = 0.43, g = 0.38, b = 0.49},
    }),
    make_gaia_tile({
        name = "ei-gaia-rock-2",
        base_tile = "dry-dirt",
        transition_tile = "dry-dirt",
        texture = "gaia-rock-2_hr.png",
        mask = "__base__/graphics/terrain/masks/transition-1.png",
        variant_weights = rock_variant_weights,
        order = "a[gaia]-a[rock]",
        layer = 61,
        control = "gaia_rocks",
        probability_expression = "clamp(1.7 * gaia_rock_core_mask * gaia_select(gaia_variant_noise, -1, 0.5, 0.18, 0.2, 1) * " .. gaia_control_multiplier("gaia_rocks") .. ", 0, 1.8)",
        map_color = {r = 0.53, g = 0.43, b = 0.50},
    }),
    make_gaia_tile({
        name = "ei-gaia-rock-3",
        base_tile = "dirt-3",
        transition_tile = "dirt-3",
        texture = "gaia-rock-3_hr.png",
        mask = "__base__/graphics/terrain/masks/transition-1.png",
        variant_weights = rock_variant_weights,
        order = "a[gaia]-a[rock]",
        layer = 62,
        control = "gaia_rocks",
        probability_expression = "clamp(1.65 * gaia_rock_core_mask * gaia_select(gaia_variant_noise, 0.45, 1.1, 0.16, 0, 1) * " .. gaia_control_multiplier("gaia_rocks") .. ", 0, 1.75)",
        map_color = {r = 0.34, g = 0.29, b = 0.38},
    }),
})
