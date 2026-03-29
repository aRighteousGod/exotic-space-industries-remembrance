--====================================================================================================
--BOULDERS FOR GAIA
--====================================================================================================

local gaia_biomes = require("__exotic-space-industries-remembrance__/prototypes/planet-gaia/biomes")

local function make_ambient_sound(filename, variation_count, volume, tuning)
    return {
        sound =
        {
            variations = sound_variations(filename, variation_count, volume),
            advanced_volume_control = default_tile_sounds_advanced_volume_control(),
        },
        radius = tuning.radius,
        min_entity_count = tuning.min_entity_count,
        max_entity_count = tuning.max_entity_count,
        entity_to_sound_ratio = tuning.entity_to_sound_ratio,
        average_pause_seconds = tuning.average_pause_seconds,
    }
end

local function merge_tile_groups(...)
    local merged = {}

    for i = 1, select("#", ...) do
        for _, tile_name in ipairs(select(i, ...)) do
            merged[#merged + 1] = tile_name
        end
    end

    return merged
end

local dry_boulder_tiles = gaia_biomes.tile_groups.rock_core
local crystal_boulder_tiles = merge_tile_groups(gaia_biomes.tile_groups.rock_fringe, gaia_biomes.tile_groups.wet)

local dry_boulder_indices = {1, 2, 3, 4, 5, 6, 7, 8, 9, 12, 13, 14, 15}
local crystal_boulder_indices = {10, 11}

local function gaia_boulder_control_multiplier()
    return "(slider_rescale(control:gaia_boulders:size, 2) * slider_rescale(control:gaia_boulders:frequency, 2))"
end

local base_shifts = {
    {0.304688, -0.4},
    {0.0, 0.0390625},
    {0.151562, 0.0},
    {0.390625, 0.0},
    {0.328125, 0.0703125},
    {0.16875, -0.1},
    {0.3, -0.2},
    {0.0, 0.0},
    {0.1, 0.0},
    {0.325, -0.1},
    {0.453125, 0.0},
    {0.539062, -0.015625},
    {0.0703125, 0.179688},
    {0.160938, 0.0},
    {0.242188, -0.195312},
}

local dimensions = {
    [1] = {188, 127},
    [2] = {195, 135},
    [3] = {205, 132},
    [4] = {144, 142},
    [5] = {130, 107},
    [6] = {165, 109},
    [7] = {150, 133},
    [8] = {156, 111},
    [9] = {187, 120},
    [10] = {225, 128},
    [11] = {183, 144},
    [12] = {186, 160},
    [13] = {181, 174},
    [14] = {212, 150},
    [15] = {155, 117},
}

local function gaia_boulder_picture(index)
    local width, height = table.unpack(dimensions[index])
    return {
        filename = ei_graphics_2_path .. "graphics/terrain/gaia-boulder-" .. index .. ".png",
        width = width,
        height = height,
        scale = 0.5,
        shift = base_shifts[index],
    }
end

local function build_picture_set(indices)
    local pictures = {}

    for _, index in ipairs(indices) do
        pictures[#pictures + 1] = gaia_boulder_picture(index)
    end

    return pictures
end

local function make_boulder(name, tile_restriction, probability_expression, pictures)
    local boulder = table.deepcopy(data.raw["simple-entity"]["big-sand-rock"])
    boulder.name = name
    boulder.localised_name = {"entity-name." .. name}
    boulder.autoplace = {
        control = "gaia_boulders",
        order = "a[landscape]-c[rock]-a[" .. name .. "]",
        probability_expression = probability_expression,
        tile_restriction = tile_restriction,
    }
    boulder.pictures = pictures
    return boulder
end

local gaia_boulder = make_boulder(
    "ei-gaia-boulder-big",
    dry_boulder_tiles,
    "clamp((0.00045 + 0.0022 * gaia_rock_core_mask * max(0, gaia_accent_noise - 0.22)) * " .. gaia_boulder_control_multiplier() .. ", 0, 0.0032)",
    build_picture_set(dry_boulder_indices)
)
gaia_boulder.ambient_sounds = make_ambient_sound(
    "__space-age__/sound/world/semi-persistent/wind-gust",
    6,
    0.08,
    {
        radius = 12,
        min_entity_count = 2,
        max_entity_count = 6,
        entity_to_sound_ratio = 0.12,
        average_pause_seconds = 0,
    }
)

local gaia_crystal_boulder = make_boulder(
    "ei-gaia-crystal-boulder",
    crystal_boulder_tiles,
    "clamp((0.00008 + 0.00065 * gaia_wet_mask * gaia_rock_fringe_mask * max(0, gaia_accent_noise - 0.55)) * " .. gaia_boulder_control_multiplier() .. ", 0, 0.00085)",
    build_picture_set(crystal_boulder_indices)
)
gaia_crystal_boulder.ambient_sounds = make_ambient_sound(
    "__space-age__/sound/world/semi-persistent/ice-cracks",
    5,
    0.06,
    {
        radius = 14,
        min_entity_count = 1,
        max_entity_count = 5,
        entity_to_sound_ratio = 0.18,
        average_pause_seconds = 0,
    }
)
gaia_crystal_boulder.minable.results = {
    {type = "item", name = "ice", amount_min = 3, amount_max = 7},
}
gaia_crystal_boulder.mined_sound = sound_variations("__space-age__/sound/mining/mined-iceberg", 4, 0.7)
gaia_crystal_boulder.mining_sound = sound_variations("__space-age__/sound/mining/axe-mining-iceberg", 7, 0.5)

data:extend({gaia_boulder, gaia_crystal_boulder})
