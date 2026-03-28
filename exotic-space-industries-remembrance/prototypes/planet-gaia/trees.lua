--====================================================================================================
--TREES FOR GAIA
--====================================================================================================

local gaia_biomes = require("__exotic-space-industries-remembrance__/prototypes/planet-gaia/biomes")

local function merge_tile_groups(...)
    local merged = {}

    for i = 1, select("#", ...) do
        for _, tile_name in ipairs(select(i, ...)) do
            merged[#merged + 1] = tile_name
        end
    end

    return merged
end

local gaia_meadow_tiles = gaia_biomes.tile_groups.meadow
local gaia_wet_tiles = gaia_biomes.tile_groups.wet
local gaia_shore_tiles = merge_tile_groups(gaia_biomes.tile_groups.meadow, gaia_biomes.tile_groups.wet)
local gaia_fringe_tiles = gaia_biomes.tile_groups.rock_fringe
local gaia_shoulder_tiles = merge_tile_groups(gaia_biomes.tile_groups.meadow, gaia_biomes.tile_groups.rock_fringe)

data:extend({
    {
        type = "noise-expression",
        name = "gaia_tree_slider",
        expression = "slider_rescale(control:gaia_trees:size, 2) * slider_rescale(control:gaia_trees:frequency, 2)",
    },
    {
        type = "noise-expression",
        name = "gaia_tree_01",
        expression = "clamp(gaia_select(temperature, 9, 15.5, 2.5, 0, 1) * gaia_select(moisture, 0.52, 0.88, 0.12, 0, 1), 0, 1)",
    },
    {
        type = "noise-expression",
        name = "gaia_tree_02",
        expression = "clamp(gaia_select(temperature, 9, 15.5, 2.5, 0, 1) * gaia_select(moisture, 0.68, 1.0, 0.1, 0, 1), 0, 1)",
    },
    {
        type = "noise-expression",
        name = "gaia_tree_03",
        expression = "clamp(gaia_select(temperature, 10.5, 18, 2.8, 0, 1) * gaia_select(moisture, 0.38, 0.76, 0.12, 0, 1), 0, 1)",
    },
    {
        type = "noise-expression",
        name = "gaia_tree_04",
        expression = "clamp(gaia_select(temperature, 8.5, 15, 2.4, 0, 1) * gaia_select(moisture, 0.78, 1.0, 0.1, 0, 1) * gaia_select(gaia_water_mask, -1, 0.62, 0.16, 0.45, 1), 0, 1)",
    },
    {
        type = "noise-expression",
        name = "gaia_tree_05",
        expression = "clamp(gaia_select(temperature, 15.5, 24.5, 3.2, 0, 1) * gaia_select(moisture, 0.46, 0.78, 0.12, 0, 1), 0, 1)",
    },
    {
        type = "noise-expression",
        name = "gaia_tree_06",
        expression = "clamp(gaia_select(temperature, 13.5, 22.5, 3.0, 0, 1) * gaia_select(moisture, 0.34, 0.68, 0.12, 0, 1), 0, 1)",
    },
    {
        type = "noise-expression",
        name = "gaia_tree_meadow_habitat",
        expression = "clamp(gaia_meadow_mask * gaia_select(gaia_grove_presence, 0.46, 1.0, 0.14, 0, 1) * gaia_select(gaia_grove_density, -1, 0.88, 0.16, 0.55, 1), 0, 1)",
    },
    {
        type = "noise-expression",
        name = "gaia_tree_parkland_habitat",
        expression = "clamp(max(gaia_dry_shoulder_mask, 0.35 * gaia_meadow_mask * gaia_select(gaia_accent_noise, 0.4, 1.0, 0.16, 0, 1)) * gaia_select(gaia_grove_presence, 0.42, 0.96, 0.14, 0, 1), 0, 1)",
    },
    {
        type = "noise-expression",
        name = "gaia_tree_wet_habitat",
        expression = "clamp(gaia_wet_mask * gaia_select(gaia_grove_presence, 0.38, 1.0, 0.16, 0, 1) * gaia_select(gaia_grove_density, -1, 0.92, 0.16, 0.5, 1), 0, 1)",
    },
    {
        type = "noise-expression",
        name = "gaia_tree_shore_habitat",
        expression = "clamp(max(gaia_wet_transition_mask, 0.25 * gaia_wet_mask) * gaia_select(gaia_accent_noise, 0.32, 1.0, 0.14, 0, 1) * gaia_select(gaia_grove_presence, 0.36, 0.94, 0.14, 0, 1), 0, 1)",
    },
    {
        type = "noise-expression",
        name = "gaia_tree_fringe_habitat",
        expression = "clamp(gaia_rock_fringe_mask * gaia_select(gaia_grove_presence, 0.52, 1.0, 0.14, 0, 1) * gaia_select(gaia_grove_density, -1, 0.84, 0.16, 0.45, 1), 0, 1)",
    },
    {
        type = "noise-expression",
        name = "gaia_tree_shoulder_habitat",
        expression = "clamp(max(gaia_dry_shoulder_mask, 0.4 * gaia_rock_fringe_mask) * gaia_select(gaia_accent_noise, 0.36, 1.0, 0.14, 0, 1) * gaia_select(gaia_grove_presence, 0.46, 0.98, 0.14, 0, 1), 0, 1)",
    },
    {
        type = "noise-expression",
        name = "gaia_tree_budget",
        expression = "clamp((0.0025 + 0.036 * gaia_select(gaia_grove_presence, 0.5, 1.02, 0.16, 0, 1) * (0.24 + 0.76 * gaia_grove_density)) * gaia_land_mask * gaia_tree_slider, 0, 0.042)",
    },
    {
        type = "noise-expression",
        name = "gaia_tree_raw_share_01",
        expression = "0.65 * gaia_tree_meadow_habitat",
    },
    {
        type = "noise-expression",
        name = "gaia_tree_raw_share_02",
        expression = "0.6 * gaia_tree_wet_habitat",
    },
    {
        type = "noise-expression",
        name = "gaia_tree_raw_share_03",
        expression = "0.35 * gaia_tree_parkland_habitat",
    },
    {
        type = "noise-expression",
        name = "gaia_tree_raw_share_04",
        expression = "0.4 * gaia_tree_shore_habitat",
    },
    {
        type = "noise-expression",
        name = "gaia_tree_raw_share_05",
        expression = "0.7 * gaia_tree_fringe_habitat",
    },
    {
        type = "noise-expression",
        name = "gaia_tree_raw_share_06",
        expression = "0.3 * gaia_tree_shoulder_habitat",
    },
    {
        type = "noise-expression",
        name = "gaia_tree_share_total",
        expression = "max(0.001, gaia_tree_raw_share_01 + gaia_tree_raw_share_02 + gaia_tree_raw_share_03 + gaia_tree_raw_share_04 + gaia_tree_raw_share_05 + gaia_tree_raw_share_06)",
    },
    {
        type = "noise-expression",
        name = "gaia_tree_probability_01",
        expression = "clamp(gaia_tree_budget * gaia_tree_01 * gaia_select(gaia_aux, 0.18, 0.82, 0.18, 0, 1) * (gaia_tree_raw_share_01 / gaia_tree_share_total), 0, 0.02)",
    },
    {
        type = "noise-expression",
        name = "gaia_tree_probability_02",
        expression = "clamp(gaia_tree_budget * gaia_tree_02 * gaia_select(gaia_aux, 0.16, 0.84, 0.18, 0, 1) * (gaia_tree_raw_share_02 / gaia_tree_share_total), 0, 0.015)",
    },
    {
        type = "noise-expression",
        name = "gaia_tree_probability_03",
        expression = "clamp(gaia_tree_budget * gaia_tree_03 * gaia_select(gaia_aux, 0.22, 0.88, 0.18, 0, 1) * (gaia_tree_raw_share_03 / gaia_tree_share_total), 0, 0.011)",
    },
    {
        type = "noise-expression",
        name = "gaia_tree_probability_04",
        expression = "clamp(gaia_tree_budget * gaia_tree_04 * gaia_select(gaia_aux, 0.16, 0.9, 0.18, 0, 1) * (gaia_tree_raw_share_04 / gaia_tree_share_total), 0, 0.01)",
    },
    {
        type = "noise-expression",
        name = "gaia_tree_probability_05",
        expression = "clamp(gaia_tree_budget * gaia_tree_05 * gaia_select(gaia_aux, 0.22, 0.86, 0.18, 0, 1) * (gaia_tree_raw_share_05 / gaia_tree_share_total), 0, 0.0075)",
    },
    {
        type = "noise-expression",
        name = "gaia_tree_probability_06",
        expression = "clamp(gaia_tree_budget * gaia_tree_06 * gaia_select(gaia_aux, 0.18, 0.9, 0.18, 0, 1) * (gaia_tree_raw_share_06 / gaia_tree_share_total), 0, 0.0065)",
    },
})

-- Gaia leaf sheets are custom-colored, so these tints stay bright and only nudge
-- each species within its biome family instead of darkening the canopy.
local tree_colors = {
    ["01"] = {
        {r = 214, g = 255, b = 224}, {r = 198, g = 246, b = 232}, {r = 184, g = 236, b = 246}, {r = 206, g = 255, b = 236},
        {r = 192, g = 240, b = 214}, {r = 176, g = 228, b = 206}, {r = 162, g = 220, b = 226}, {r = 226, g = 255, b = 242},
        {r = 206, g = 248, b = 220}, {r = 190, g = 238, b = 228}, {r = 174, g = 232, b = 238}, {r = 216, g = 252, b = 232},
        {r = 184, g = 234, b = 214}, {r = 170, g = 226, b = 212}, {r = 156, g = 214, b = 220}, {r = 220, g = 250, b = 236},
    },
    ["02"] = {
        {r = 212, g = 244, b = 255}, {r = 224, g = 234, b = 255}, {r = 198, g = 255, b = 246}, {r = 232, g = 220, b = 255},
        {r = 188, g = 230, b = 255}, {r = 210, g = 255, b = 255}, {r = 242, g = 228, b = 255}, {r = 180, g = 220, b = 248},
        {r = 206, g = 238, b = 255}, {r = 218, g = 230, b = 255}, {r = 192, g = 246, b = 240}, {r = 226, g = 214, b = 255},
        {r = 182, g = 224, b = 248}, {r = 202, g = 248, b = 252}, {r = 236, g = 222, b = 255}, {r = 174, g = 214, b = 242},
    },
    ["03"] = {
        {r = 244, g = 250, b = 210}, {r = 230, g = 242, b = 194}, {r = 216, g = 232, b = 178}, {r = 248, g = 255, b = 222},
        {r = 220, g = 236, b = 184}, {r = 208, g = 226, b = 170}, {r = 198, g = 218, b = 164}, {r = 236, g = 248, b = 206},
        {r = 224, g = 240, b = 188}, {r = 212, g = 230, b = 180}, {r = 202, g = 222, b = 170}, {r = 242, g = 252, b = 214},
        {r = 228, g = 238, b = 192}, {r = 214, g = 228, b = 176}, {r = 206, g = 220, b = 168}, {r = 234, g = 244, b = 202},
    },
    ["04"] = {
        {r = 214, g = 248, b = 236}, {r = 202, g = 240, b = 228}, {r = 190, g = 232, b = 220}, {r = 224, g = 255, b = 242},
        {r = 204, g = 236, b = 232}, {r = 194, g = 230, b = 224}, {r = 182, g = 220, b = 214}, {r = 232, g = 250, b = 244},
        {r = 210, g = 244, b = 236}, {r = 198, g = 236, b = 226}, {r = 188, g = 228, b = 216}, {r = 220, g = 248, b = 240},
        {r = 206, g = 240, b = 230}, {r = 194, g = 232, b = 220}, {r = 186, g = 224, b = 210}, {r = 226, g = 252, b = 244},
    },
    ["05"] = {
        {r = 255, g = 226, b = 200}, {r = 255, g = 236, b = 214}, {r = 255, g = 220, b = 194}, {r = 246, g = 214, b = 188},
        {r = 255, g = 244, b = 220}, {r = 255, g = 230, b = 212}, {r = 242, g = 220, b = 194}, {r = 255, g = 242, b = 232},
        {r = 250, g = 220, b = 192}, {r = 255, g = 232, b = 206}, {r = 248, g = 216, b = 188}, {r = 240, g = 208, b = 182},
        {r = 255, g = 238, b = 214}, {r = 250, g = 226, b = 206}, {r = 236, g = 214, b = 188}, {r = 255, g = 236, b = 226},
    },
    ["06"] = {
        {r = 246, g = 210, b = 200}, {r = 236, g = 202, b = 190}, {r = 226, g = 194, b = 182}, {r = 255, g = 220, b = 212},
        {r = 240, g = 206, b = 194}, {r = 230, g = 198, b = 186}, {r = 220, g = 188, b = 176}, {r = 250, g = 214, b = 206},
        {r = 238, g = 204, b = 194}, {r = 228, g = 196, b = 184}, {r = 218, g = 186, b = 172}, {r = 244, g = 210, b = 202},
        {r = 234, g = 200, b = 188}, {r = 224, g = 190, b = 178}, {r = 214, g = 182, b = 170}, {r = 248, g = 216, b = 208},
    },
}

local gaia_tree_definitions = {
    ["01"] = {source = "01", tiles = gaia_meadow_tiles},
    ["02"] = {source = "02", tiles = gaia_wet_tiles},
    ["03"] = {source = "01", tiles = gaia_meadow_tiles},
    ["04"] = {source = "02", tiles = gaia_shore_tiles},
    ["05"] = {source = "05", tiles = gaia_fringe_tiles},
    ["06"] = {source = "05", tiles = gaia_shoulder_tiles},
}

local function gaia_leaf_filename(number, variation_letter)
    if number == "01" or number == "02" or number == "05" then
        return ei_graphics_tree_path .. number .. "/hr-tree-" .. number .. "-" .. variation_letter .. "-leaves.png"
    end

    return ei_graphics_gaia_tree_path .. number .. "/tree-" .. number .. "-" .. variation_letter .. "-leaves.png"
end

local function remap_gaia_tree_component(filename, number, component_name)
    local variation_letter = filename:match("tree%-%d%d%-(%a)%-" .. component_name .. "%.png$")
    if not variation_letter then
        return filename
    end

    if component_name == "leaves" then
        return gaia_leaf_filename(number, variation_letter)
    end

    return filename
end

local function remap_gaia_tree_variation(variation, number)
    if variation.leaves and variation.leaves.filename then
        variation.leaves.filename = remap_gaia_tree_component(variation.leaves.filename, number, "leaves")
    end
end

local function make_tree(number)
    local definition = gaia_tree_definitions[number]
    local tree = table.deepcopy(data.raw.tree["tree-" .. definition.source])

    tree.name = "ei-gaia-tree-" .. number
    tree.localised_name = {"entity-name." .. tree.name}
    tree.autoplace = {
        control = "gaia_trees",
        order = "a[tree]-b[forest]-gaia-" .. number,
        probability_expression = "gaia_tree_probability_" .. number,
        richness_expression = "clamp(random_penalty_at(6, 1), 0, 1)",
        tile_restriction = definition.tiles,
    }
    tree.colors = tree_colors[number]

    for i, variation in ipairs(tree.variations) do
        remap_gaia_tree_variation(tree.variations[i], number)
    end

    data:extend({tree})
end

for _, number in ipairs({"01", "03", "02", "04", "05", "06"}) do
    make_tree(number)
end
