data:extend({
    {
        type = "noise-function",
        name = "gaia_select",
        parameters = {"input", "from", "to", "slope", "min_value", "max_value"},
        expression = "clamp(min(input - (from - slope), to + slope - input) / slope, min_value, max_value)",
    },
    {
        type = "noise-expression",
        name = "gaia_water_frequency",
        expression = "slider_rescale(control:gaia_water:frequency, 2)",
    },
    {
        type = "noise-expression",
        name = "gaia_rock_frequency",
        expression = "slider_rescale(control:gaia_rocks:frequency, 2)",
    },
    {
        type = "noise-expression",
        name = "gaia_starting_land",
        expression = "clamp(1 - distance / 260, 0, 0.85)",
    },
    {
        type = "noise-expression",
        name = "gaia_wobble_x",
        expression = "multioctave_noise{x = x, y = y, persistence = 0.7, seed0 = map_seed, seed1 = 1100, octaves = 3, input_scale = 1/140}",
    },
    {
        type = "noise-expression",
        name = "gaia_wobble_y",
        expression = "multioctave_noise{x = x, y = y, persistence = 0.7, seed0 = map_seed, seed1 = 1200, octaves = 3, input_scale = 1/140}",
    },
    {
        type = "noise-expression",
        name = "gaia_wobble_small_x",
        expression = "multioctave_noise{x = x, y = y, persistence = 0.72, seed0 = map_seed, seed1 = 1300, octaves = 2, input_scale = 1/45}",
    },
    {
        type = "noise-expression",
        name = "gaia_wobble_small_y",
        expression = "multioctave_noise{x = x, y = y, persistence = 0.72, seed0 = map_seed, seed1 = 1400, octaves = 2, input_scale = 1/45}",
    },
    {
        type = "noise-expression",
        name = "gaia_variant_noise",
        expression = "clamp(0.5 + 0.5 * multioctave_noise{x = x + gaia_wobble_x * 12, y = y + gaia_wobble_y * 12, persistence = 0.72, seed0 = map_seed, seed1 = 2100, octaves = 4, input_scale = 1/70}, 0, 1)",
    },
    {
        type = "noise-expression",
        name = "gaia_forest_noise",
        expression = "clamp(0.5 + 0.32 * multioctave_noise{x = x + gaia_wobble_x * 18, y = y + gaia_wobble_y * 18, persistence = 0.7, seed0 = map_seed, seed1 = 2200, octaves = 4, input_scale = 1/210} + 0.18 * multioctave_noise{x = x + gaia_wobble_small_x * 8, y = y + gaia_wobble_small_y * 8, persistence = 0.72, seed0 = map_seed, seed1 = 2300, octaves = 2, input_scale = 1/85}, 0, 1)",
    },
    {
        type = "noise-expression",
        name = "gaia_grove_presence",
        expression = "clamp(0.44 + 0.34 * multioctave_noise{x = x + gaia_wobble_x * 26, y = y + gaia_wobble_y * 26, persistence = 0.72, seed0 = map_seed, seed1 = 2260, octaves = 4, input_scale = 1/360} + 0.18 * gaia_forest_noise + 0.08 * gaia_accent_noise + 0.08 * gaia_river_mask - 0.16 * gaia_rock_core_mask, 0, 1)",
    },
    {
        type = "noise-expression",
        name = "gaia_grove_density",
        expression = "clamp(0.38 + 0.3 * multioctave_noise{x = x + gaia_wobble_small_x * 18, y = y + gaia_wobble_small_y * 18, persistence = 0.72, seed0 = map_seed, seed1 = 2270, octaves = 4, input_scale = 1/150} + 0.22 * gaia_forest_noise + 0.1 * gaia_accent_noise - 0.08 * gaia_water_mask, 0, 1)",
    },
    {
        type = "noise-expression",
        name = "gaia_accent_noise",
        expression = "clamp(0.5 + 0.5 * multioctave_noise{x = x + gaia_wobble_x * 6, y = y + gaia_wobble_y * 6, persistence = 0.68, seed0 = map_seed, seed1 = 2400, octaves = 4, input_scale = 1/95}, 0, 1)",
    },
    {
        type = "noise-expression",
        name = "gaia_rock_feature_noise",
        expression = "clamp(0.5 + 0.5 * multioctave_noise{x = x + gaia_wobble_small_x * 12, y = y + gaia_wobble_small_y * 12, persistence = 0.72, seed0 = map_seed, seed1 = 2450, octaves = 4, input_scale = 1/120 * gaia_rock_frequency}, 0, 1)",
    },
    {
        type = "noise-expression",
        name = "gaia_landmass_large",
        expression = "0.65 + 0.35 * multioctave_noise{x = x, y = y, persistence = 0.7, seed0 = map_seed, seed1 = 3100, octaves = 4, input_scale = 1/950}",
    },
    {
        type = "noise-expression",
        name = "gaia_landmass_medium",
        expression = "0.5 + 0.5 * multioctave_noise{x = x + gaia_wobble_x * 40, y = y + gaia_wobble_y * 40, persistence = 0.68, seed0 = map_seed, seed1 = 3200, octaves = 4, input_scale = 1/260}",
    },
    {
        type = "noise-expression",
        name = "gaia_hilliness",
        expression = "clamp(0.5 + 0.5 * multioctave_noise{x = x + gaia_wobble_small_x * 18, y = y + gaia_wobble_small_y * 18, persistence = 0.7, seed0 = map_seed, seed1 = 3300, octaves = 4, input_scale = 1/120}, 0, 1)",
    },
    {
        type = "noise-expression",
        name = "gaia_river_mask",
        expression = "clamp(1.14 - 2.7 * abs(multioctave_noise{x = x + gaia_wobble_x * 95 + gaia_wobble_small_x * 24, y = y + gaia_wobble_y * 95 + gaia_wobble_small_y * 24, persistence = 0.68, seed0 = map_seed, seed1 = 4100, octaves = 5, input_scale = 1/420 * gaia_water_frequency}) + 0.14 * multioctave_noise{x = x + gaia_wobble_x * 40, y = y + gaia_wobble_y * 40, persistence = 0.7, seed0 = map_seed, seed1 = 4200, octaves = 2, input_scale = 1/140 * gaia_water_frequency}, 0, 1)",
    },
    {
        type = "noise-expression",
        name = "gaia_lake_mask",
        expression = "clamp(0.04 + 0.54 * lake_sites + 0.44 * basin_noise + 0.18 * gaia_river_mask - 0.38, 0, 1)",
        local_expressions = {
            lake_sites = "clamp(0.92 - 1.75 * abs(multioctave_noise{x = x + gaia_wobble_x * 80, y = y + gaia_wobble_y * 80, persistence = 0.7, seed0 = map_seed, seed1 = 4300, octaves = 3, input_scale = 1/720 * gaia_water_frequency}), 0, 1)",
            basin_noise = "clamp(0.84 - 1.8 * abs(multioctave_noise{x = x + gaia_wobble_small_x * 20, y = y + gaia_wobble_small_y * 20, persistence = 0.72, seed0 = map_seed, seed1 = 4400, octaves = 3, input_scale = 1/220 * gaia_water_frequency}), 0, 1)",
        },
    },
    {
        type = "noise-expression",
        name = "gaia_water_mask",
        expression = "clamp(max(gaia_river_mask * (0.84 + 0.46 * gaia_lake_mask), gaia_lake_mask * 1.18) - gaia_starting_land * 0.22, 0, 1)",
    },
    {
        type = "noise-expression",
        name = "gaia_water_edge_mask",
        -- Soft transition zone (1 tile wide) at water perimeter for edge decoratives
        expression = "clamp(max(gaia_river_mask, gaia_lake_mask) * max(0, min(1, (1 - gaia_water_mask) * 3)), 0, 1)",
    },
    {
        type = "noise-expression",
        name = "gaia_dry_macro",
        expression = "0.5 + 0.5 * multioctave_noise{x = x, y = y, persistence = 0.72, seed0 = map_seed, seed1 = 5100, octaves = 3, input_scale = 1/760}",
    },
    {
        type = "noise-expression",
        name = "gaia_rockiness",
        expression = "clamp(0.02 + 0.28 * gaia_dry_macro + 0.12 * multioctave_noise{x = x + gaia_wobble_x * 24, y = y + gaia_wobble_y * 24, persistence = 0.72, seed0 = map_seed, seed1 = 5200, octaves = 4, input_scale = 1/230} + 0.08 * gaia_hilliness - 0.22 * gaia_starting_land - 0.2 * gaia_river_mask - 0.18 * gaia_lake_mask, 0, 1)",
    },
    {
        type = "noise-expression",
        name = "gaia_lushness",
        expression = "clamp(0.44 + 0.28 * multioctave_noise{x = x + gaia_wobble_x * 20, y = y + gaia_wobble_y * 20, persistence = 0.7, seed0 = map_seed, seed1 = 5300, octaves = 4, input_scale = 1/190} + 0.52 * gaia_river_mask + 0.48 * gaia_lake_mask - 0.38 * gaia_rockiness, 0, 1)",
    },
    {
        type = "noise-expression",
        name = "gaia_elevation",
        -- CLIFF HEIGHT REFERENCE:
        -- Elevation range: [-32, 180] prevents runaway cliff generation
        -- Cliff 0: 24 units | Cliff 1: 104 units | Max 2 cliffs per terrain chunk
        expression = "clamp(4 + 13 * gaia_landmass_large + 5 * gaia_landmass_medium + 4 * gaia_hilliness - 60 * gaia_water_mask, -32, 180)",
    },
    {
        type = "noise-expression",
        name = "gaia_wetness",
        expression = "clamp(0.18 + 0.82 * gaia_river_mask + 1.0 * gaia_lake_mask + 0.16 * gaia_landmass_medium - 0.26 * gaia_rockiness - 0.12 * clamp(gaia_elevation / 34, 0, 1), 0, 1)",
    },
    {
        type = "noise-expression",
        name = "gaia_land_mask",
        expression = "clamp(gaia_elevation / 10, 0, 1)",
    },
    {
        type = "noise-expression",
        name = "gaia_meadow_mask",
        expression = "clamp(gaia_select(gaia_lushness, 0.46, 1.08, 0.16, 0, 1) * gaia_select(gaia_wetness, 0.14, 0.72, 0.16, 0, 1) * gaia_select(gaia_rockiness, -1, 0.5, 0.15, 0, 1) * gaia_land_mask, 0, 1)",
    },
    {
        type = "noise-expression",
        name = "gaia_wet_mask",
        expression = "clamp(gaia_select(gaia_wetness, 0.52, 1.08, 0.18, 0, 1) * gaia_select(gaia_lushness, 0.28, 1.08, 0.16, 0, 1) * gaia_select(gaia_rockiness, -1, 0.5, 0.16, 0, 1) * gaia_land_mask, 0, 1)",
    },
    {
        type = "noise-expression",
        name = "gaia_rock_fringe_mask",
        expression = "clamp(gaia_select(gaia_rockiness, 0.48, 0.94, 0.12, 0, 1) * gaia_select(gaia_wetness, -1, 0.52, 0.14, 0, 1) * gaia_select(gaia_lushness, -1, 0.78, 0.16, 0, 1) * gaia_land_mask, 0, 1)",
    },
    {
        type = "noise-expression",
        name = "gaia_rock_core_mask",
        expression = "clamp(gaia_select(gaia_rockiness, 0.72, 1.2, 0.12, 0, 1) * gaia_select(gaia_wetness, -1, 0.34, 0.18, 0, 1) * gaia_select(gaia_lushness, -1, 0.58, 0.18, 0, 1) * gaia_land_mask, 0, 1)",
    },
    {
        type = "noise-expression",
        name = "gaia_wet_transition_mask",
        expression = "clamp(max(gaia_meadow_mask * gaia_select(gaia_wetness, 0.32, 0.92, 0.16, 0, 1) * gaia_select(gaia_water_edge_mask, -1, 0.84, 0.18, 0.35, 1), gaia_wet_mask * gaia_select(gaia_water_edge_mask, -0.02, 1.0, 0.14, 0.35, 1) * gaia_select(gaia_lushness, 0.18, 1.1, 0.16, 0, 1)), 0, 1)",
    },
    {
        type = "noise-expression",
        name = "gaia_dry_shoulder_mask",
        expression = "clamp(max(gaia_meadow_mask * gaia_select(gaia_rockiness, 0.18, 0.74, 0.14, 0, 1) * gaia_select(gaia_wetness, -1, 0.54, 0.16, 0, 1), gaia_rock_fringe_mask * gaia_select(gaia_lushness, 0.18, 0.82, 0.16, 0, 1)), 0, 1)",
    },
    {
        type = "noise-expression",
        name = "gaia_aux",
        expression = "aux_basic",
    },
    {
        type = "noise-expression",
        name = "gaia_moisture",
        expression = "clamp(0.42 + 0.12 * gaia_wet_mask + 0.2 * gaia_meadow_mask + 0.34 * gaia_rock_fringe_mask - 0.16 * gaia_rock_core_mask + 0.12 * (moisture_basic - 0.5) + 0.08 * (gaia_wetness - 0.5), 0, 1)",
    },
    {
        type = "noise-expression",
        name = "gaia_temperature",
        expression = "clamp(18.5 - 5.2 * gaia_wet_mask - 6.0 * gaia_meadow_mask + 3.5 * gaia_rock_fringe_mask + 10.0 * gaia_rock_core_mask + 0.4 * (temperature_basic - 15) + 0.4 * (gaia_variant_noise - 0.5), 9, 30)",
    },
    {
        type = "noise-expression",
        name = "gaia_cliffiness",
        expression = "clamp((0.3 * cliffiness_basic + 0.9 * gaia_rock_core_mask + 0.55 * gaia_rock_fringe_mask) * gaia_select(gaia_elevation, 18, 96, 22, 0, 1) * gaia_select(gaia_wetness, -1, 0.68, 0.2, 0, 1), 0, 1)",
    },
})
