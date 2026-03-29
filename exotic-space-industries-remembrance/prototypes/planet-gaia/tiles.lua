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

local function gaia_world_ambient_sound(filename_stem, variation_count, volume, tuning, advanced_volume_control)
    return {
        sound = {
            variations = sound_variations(filename_stem, variation_count, volume),
            advanced_volume_control = advanced_volume_control or default_tile_sounds_advanced_volume_control(),
        },
        radius = tuning.radius,
        min_entity_count = tuning.min_entity_count,
        max_entity_count = tuning.max_entity_count,
        entity_to_sound_ratio = tuning.entity_to_sound_ratio,
        average_pause_seconds = tuning.average_pause_seconds,
    }
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
        ambient_sounds = definition.ambient_sounds,
        ambient_sounds_group = definition.ambient_sounds_group,
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
        map_color = {r = 38, g = 74, b = 69},
        ambient_sounds = gaia_world_ambient_sound(
            "__base__/sound/world/trees/tree-ambient-leaves",
            5,
            0.16,
            {
                radius = 7.5,
                min_entity_count = 6,
                max_entity_count = 18,
                entity_to_sound_ratio = 0.10,
                average_pause_seconds = 0,
            }
        ),
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
        probability_expression = "clamp(2.25 * max(gaia_wet_mask, 0.35 * gaia_wet_transition_mask) * gaia_select(gaia_variant_noise, -1, 0.62, 0.18, 0.32, 1) * " .. gaia_control_multiplier("gaia_wetlands") .. ", 0, 2.35)",
        map_color = {r = 56, g = 69, b = 48},
        ambient_sounds = gaia_world_ambient_sound(
            "__space-age__/sound/world/tiles/insects-deep-mud",
            8,
            0.15,
            {
                radius = 7.5,
                min_entity_count = 5,
                max_entity_count = 15,
                entity_to_sound_ratio = 0.12,
                average_pause_seconds = 0,
            }
        ),
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
        map_color = {r = 89, g = 80, b = 100},
        ambient_sounds_group = "ei-gaia-grass-1",
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
        probability_expression = "clamp(0.95 * gaia_wet_transition_mask * gaia_select(gaia_accent_noise, 0.54, 1.08, 0.16, 0, 1) * " .. gaia_control_multiplier("gaia_wetlands") .. ", 0, 1.0)",
        map_color = {r = 61, g = 77, b = 56},
        ambient_sounds_group = "ei-gaia-grass-2",
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
        probability_expression = "clamp(1.9 * max(gaia_wet_transition_mask, 0.8 * gaia_wet_mask) * gaia_select(gaia_variant_noise, 0.42, 1.08, 0.18, 0, 1) * gaia_select(gaia_accent_noise, 0.22, 1.08, 0.18, 0, 1) * " .. gaia_control_multiplier("gaia_wetlands") .. ", 0, 2.0)",
        map_color = {r = 82, g = 72, b = 95},
        ambient_sounds_group = "ei-gaia-grass-2",
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
        map_color = {r = 117, g = 104, b = 89},
        ambient_sounds = gaia_world_ambient_sound(
            "__space-age__/sound/world/semi-persistent/wind-gust",
            6,
            0.12,
            {
                radius = 7.5,
                min_entity_count = 6,
                max_entity_count = 16,
                entity_to_sound_ratio = 0.08,
                average_pause_seconds = 0,
            }
        ),
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
        probability_expression = "clamp(1.55 * gaia_rock_core_mask * gaia_select(gaia_variant_noise, -1, 0.42, 0.14, 0, 1) * " .. gaia_control_multiplier("gaia_rocks") .. ", 0, 1.55)",
        map_color = {r = 142, g = 98, b = 79},
        ambient_sounds_group = "ei-gaia-rock-1",
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
        probability_expression = "clamp(1.55 * gaia_rock_core_mask * gaia_select(gaia_variant_noise, 0.5, 1.08, 0.14, 0, 1) * " .. gaia_control_multiplier("gaia_rocks") .. ", 0, 1.55)",
        map_color = {r = 151, g = 131, b = 103},
        ambient_sounds_group = "ei-gaia-rock-1",
    }),
})
