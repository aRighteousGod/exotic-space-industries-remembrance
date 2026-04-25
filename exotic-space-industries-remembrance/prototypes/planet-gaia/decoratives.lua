--====================================================================================================
--DECORATIVES FOR GAIA
--====================================================================================================

local gaia_biomes = require("__exotic-space-industries-remembrance__/prototypes/planet-gaia/biomes")
local tile_groups = gaia_biomes.tile_groups

local gaia_decorative_settings = {
    ["ei-gaia-meadow-carpet-grass"] = {frequency = 1.8, richness = 1, size = 1.45},
    ["ei-gaia-purple-carpet-grass"] = {frequency = 1.45, richness = 1, size = 1.25},
    ["ei-gaia-wet-carpet-grass"] = {frequency = 1.25, richness = 1, size = 1.1},
    ["ei-gaia-bloom-carpet-grass"] = {frequency = 1.25, richness = 1, size = 1.1},
    ["ei-gaia-meadow-hairy-grass"] = {frequency = 1.15, richness = 1, size = 0.9},
    ["ei-gaia-purple-hairy-grass"] = {frequency = 0.95, richness = 1, size = 0.82},
    ["ei-gaia-wet-hairy-grass"] = {frequency = 1.55, richness = 1, size = 1.2},
    ["ei-gaia-bloom-hairy-grass"] = {frequency = 1.55, richness = 1, size = 1.2},
    ["ei-gaia-meadow-bush-mini"] = {frequency = 0.48, richness = 1, size = 0.75},
    ["ei-gaia-purple-bush-mini"] = {frequency = 0.36, richness = 1, size = 0.68},
    ["ei-gaia-fringe-bush-mini"] = {frequency = 0.24, richness = 1, size = 0.5},
    ["ei-gaia-wet-asterisk-mini"] = {frequency = 0.36, richness = 1, size = 0.5},
    ["ei-gaia-bloom-asterisk-mini"] = {frequency = 0.36, richness = 1, size = 0.5},
    ["ei-gaia-shore-asterisk-mini"] = {frequency = 0.28, richness = 1, size = 0.45},
    ["ei-gaia-bloom-shore-asterisk-mini"] = {frequency = 0.28, richness = 1, size = 0.45},
    ["ei-gaia-fringe-lichen-decal"] = {frequency = 0.34, richness = 1, size = 0.55},
    ["ei-gaia-core-lichen-decal"] = {frequency = 0.22, richness = 1, size = 0.45},
    ["ei-gaia-meadow-pink-lichen-decal"] = {frequency = 0.16, richness = 1, size = 0.42},
    ["ei-gaia-purple-pink-lichen-decal"] = {frequency = 0.12, richness = 1, size = 0.38},
    ["ei-gaia-wet-pink-lichen-decal"] = {frequency = 0.08, richness = 1, size = 0.28},
    ["ei-gaia-bloom-pink-lichen-decal"] = {frequency = 0.08, richness = 1, size = 0.28},
    ["ei-gaia-wet-shroom-decal"] = {frequency = 0.18, richness = 1, size = 0.34},
    ["ei-gaia-bloom-shroom-decal"] = {frequency = 0.18, richness = 1, size = 0.34},
    ["ei-gaia-fringe-shroom-decal"] = {frequency = 0.08, richness = 1, size = 0.24},
    ["ei-gaia-tiny-rock"] = {frequency = 0.95, richness = 1, size = 1},
    ["ei-gaia-small-rock"] = {frequency = 0.55, richness = 1, size = 0.85},
    ["ei-gaia-tiny-rock-cluster"] = {frequency = 0.7, richness = 1, size = 0.9},
}

local function gaia_decorative_control_multiplier()
    return "(slider_rescale(control:gaia_decoratives:size, 2) * slider_rescale(control:gaia_decoratives:frequency, 2))"
end

local function decorative_autoplace(base_autoplace, order, probability_expression, tile_restriction)
    local autoplace = base_autoplace and table.deepcopy(base_autoplace) or {}
    autoplace.order = order
    autoplace.control = "gaia_decoratives"
    autoplace.probability_expression = probability_expression
    autoplace.tile_restriction = tile_restriction or tile_groups.land
    return autoplace
end

local function retarget_pictures(decorative, art_folder, runtime_tint)
    local folder_path = art_folder and (ei_graphics_decorative_path .. "gaia/" .. art_folder .. "/") or nil
    for _, picture in ipairs(decorative.pictures or {}) do
        if folder_path then
            local basename = picture.filename and picture.filename:match("([^/]+)$")
            if basename then
                picture.filename = folder_path .. basename
            end
        end
        picture.tint = runtime_tint
        picture.tint_as_overlay = nil

        if picture.hr_version then
            if folder_path then
                local hr_basename = picture.hr_version.filename and picture.hr_version.filename:match("([^/]+)$")
                if hr_basename then
                    picture.hr_version.filename = folder_path .. hr_basename
                end
            end
            picture.hr_version.tint = runtime_tint
            picture.hr_version.tint_as_overlay = nil
        end
    end
end

local function make_decorative(base_name, new_name, order, probability_expression, tile_restriction, art_folder, runtime_tint)
    local decorative = data.raw["optimized-decorative"][base_name]
    if not decorative then
        error("Missing base decorative prototype: " .. base_name)
    end

    decorative = table.deepcopy(decorative)
    decorative.name = new_name
    decorative.autoplace = decorative_autoplace(decorative.autoplace, order, probability_expression, tile_restriction)
    retarget_pictures(decorative, art_folder, runtime_tint)

    data:extend({decorative})
end

make_decorative(
    "green-carpet-grass",
    "ei-gaia-meadow-carpet-grass",
    "a[landscape]-b[gaia]-a[meadow-carpet]",
    "clamp((0.018 + 0.11 * gaia_meadow_mask * (0.45 + gaia_lushness) * gaia_select(gaia_wetness, -1, 0.72, 0.2, 0.32, 1)) * " .. gaia_decorative_control_multiplier() .. ", 0, 0.16)",
    tile_groups.meadow_green,
    "meadow-carpet-grass"
)

make_decorative(
    "green-carpet-grass",
    "ei-gaia-purple-carpet-grass",
    "a[landscape]-b[gaia]-a1[purple-meadow-carpet]",
    "clamp((0.018 + 0.11 * gaia_meadow_mask * (0.45 + gaia_lushness) * gaia_select(gaia_wetness, -1, 0.72, 0.2, 0.32, 1)) * " .. gaia_decorative_control_multiplier() .. ", 0, 0.16)",
    tile_groups.meadow_purple,
    "purple-meadow-carpet-grass"
)

make_decorative(
    "green-carpet-grass",
    "ei-gaia-wet-carpet-grass",
    "a[landscape]-b[gaia]-b[wet-carpet]",
    "clamp((0.006 + 0.065 * gaia_wet_mask * (0.4 + gaia_wetness) * gaia_select(gaia_accent_noise, 0.24, 1.04, 0.18, 0.3, 1)) * " .. gaia_decorative_control_multiplier() .. ", 0, 0.11)",
    tile_groups.wet_green,
    "wet-carpet-grass"
)

make_decorative(
    "green-carpet-grass",
    "ei-gaia-bloom-carpet-grass",
    "a[landscape]-b[gaia]-b1[bloom-carpet]",
    "clamp((0.006 + 0.065 * gaia_wet_mask * (0.4 + gaia_wetness) * gaia_select(gaia_accent_noise, 0.24, 1.04, 0.18, 0.3, 1)) * " .. gaia_decorative_control_multiplier() .. ", 0, 0.11)",
    tile_groups.wet_bloom,
    "bloom-carpet-grass"
)

make_decorative(
    "green-hairy-grass",
    "ei-gaia-meadow-hairy-grass",
    "a[landscape]-b[gaia]-c[meadow-hair]",
    "clamp((0.006 + 0.06 * gaia_meadow_mask * gaia_select(gaia_accent_noise, 0.34, 1.0, 0.16, 0.28, 1)) * " .. gaia_decorative_control_multiplier() .. ", 0, 0.09)",
    tile_groups.meadow_green,
    "meadow-hairy-grass"
)

make_decorative(
    "green-hairy-grass",
    "ei-gaia-purple-hairy-grass",
    "a[landscape]-b[gaia]-c1[purple-meadow-hair]",
    "clamp((0.006 + 0.06 * gaia_meadow_mask * gaia_select(gaia_accent_noise, 0.34, 1.0, 0.16, 0.28, 1)) * " .. gaia_decorative_control_multiplier() .. ", 0, 0.09)",
    tile_groups.meadow_purple,
    "purple-meadow-hairy-grass"
)

make_decorative(
    "green-hairy-grass",
    "ei-gaia-wet-hairy-grass",
    "a[landscape]-b[gaia]-d[wet-hair]",
    "clamp((0.008 + 0.1 * gaia_wet_mask * (0.45 + gaia_wetness) + 0.018 * gaia_wet_transition_mask) * " .. gaia_decorative_control_multiplier() .. ", 0, 0.15)",
    tile_groups.wet_green,
    "wet-hairy-grass"
)

make_decorative(
    "green-hairy-grass",
    "ei-gaia-bloom-hairy-grass",
    "a[landscape]-b[gaia]-d1[bloom-hair]",
    "clamp((0.008 + 0.1 * gaia_wet_mask * (0.45 + gaia_wetness) + 0.018 * gaia_wet_transition_mask) * " .. gaia_decorative_control_multiplier() .. ", 0, 0.15)",
    tile_groups.wet_bloom,
    "bloom-hairy-grass"
)

make_decorative(
    "green-bush-mini",
    "ei-gaia-meadow-bush-mini",
    "a[landscape]-b[gaia]-e[meadow-bush]",
    "clamp((0.002 + 0.017 * gaia_meadow_mask * gaia_lushness * max(0, gaia_accent_noise - 0.3)) * " .. gaia_decorative_control_multiplier() .. ", 0, 0.028)",
    tile_groups.meadow_green,
    "meadow-bush-mini"
)

make_decorative(
    "green-bush-mini",
    "ei-gaia-purple-bush-mini",
    "a[landscape]-b[gaia]-e1[purple-meadow-bush]",
    "clamp((0.002 + 0.017 * gaia_meadow_mask * gaia_lushness * max(0, gaia_accent_noise - 0.3)) * " .. gaia_decorative_control_multiplier() .. ", 0, 0.028)",
    tile_groups.meadow_purple,
    "purple-meadow-bush-mini"
)

make_decorative(
    "green-bush-mini",
    "ei-gaia-fringe-bush-mini",
    "a[landscape]-b[gaia]-f[fringe-bush]",
    "clamp((0.001 + 0.013 * gaia_dry_shoulder_mask * gaia_select(gaia_accent_noise, 0.4, 1.04, 0.14, 0, 1)) * " .. gaia_decorative_control_multiplier() .. ", 0, 0.018)",
    tile_groups.rock,
    "fringe-bush-mini"
)

make_decorative(
    "green-asterisk-mini",
    "ei-gaia-wet-asterisk-mini",
    "a[landscape]-b[gaia]-g[wet-asterisk]",
    "clamp((0.002 + 0.025 * gaia_wet_mask * max(0, gaia_accent_noise - 0.42)) * " .. gaia_decorative_control_multiplier() .. ", 0, 0.036)",
    tile_groups.wet_green,
    "wet-asterisk-mini"
)

make_decorative(
    "green-asterisk-mini",
    "ei-gaia-bloom-asterisk-mini",
    "a[landscape]-b[gaia]-g1[bloom-asterisk]",
    "clamp((0.002 + 0.025 * gaia_wet_mask * max(0, gaia_accent_noise - 0.42)) * " .. gaia_decorative_control_multiplier() .. ", 0, 0.036)",
    tile_groups.wet_bloom,
    "bloom-asterisk-mini"
)

make_decorative(
    "green-asterisk-mini",
    "ei-gaia-shore-asterisk-mini",
    "a[landscape]-b[gaia]-h[shore-asterisk]",
    "clamp((0.0014 + 0.022 * gaia_wet_transition_mask * gaia_select(gaia_water_edge_mask, 0.04, 1.0, 0.12, 0.36, 1)) * " .. gaia_decorative_control_multiplier() .. ", 0, 0.028)",
    tile_groups.wet_green,
    "shore-asterisk-mini"
)

make_decorative(
    "green-asterisk-mini",
    "ei-gaia-bloom-shore-asterisk-mini",
    "a[landscape]-b[gaia]-h1[bloom-shore-asterisk]",
    "clamp((0.0014 + 0.022 * gaia_wet_transition_mask * gaia_select(gaia_water_edge_mask, 0.04, 1.0, 0.12, 0.36, 1)) * " .. gaia_decorative_control_multiplier() .. ", 0, 0.028)",
    tile_groups.wet_bloom,
    "bloom-shore-asterisk-mini"
)

make_decorative(
    "lichen-decal",
    "ei-gaia-fringe-lichen-decal",
    "a[landscape]-b[gaia]-i[fringe-lichen]",
    "clamp((0.0015 + 0.018 * gaia_rock_fringe_mask * max(0, gaia_accent_noise - 0.3)) * " .. gaia_decorative_control_multiplier() .. ", 0, 0.028)",
    tile_groups.rock_fringe,
    "fringe-lichen-decal",
    {r = 0.86, g = 0.78, b = 0.68}
)

make_decorative(
    "lichen-decal",
    "ei-gaia-core-lichen-decal",
    "a[landscape]-b[gaia]-j[core-lichen]",
    "clamp((0.001 + 0.014 * gaia_rock_core_mask * gaia_select(gaia_accent_noise, 0.26, 1.06, 0.16, 0.22, 1)) * " .. gaia_decorative_control_multiplier() .. ", 0, 0.02)",
    tile_groups.rock_core,
    "fringe-lichen-decal",
    {r = 0.86, g = 0.78, b = 0.68}
)

make_decorative(
    "pink-lichen-decal",
    "ei-gaia-meadow-pink-lichen-decal",
    "a[landscape]-b[gaia]-k[meadow-pink]",
    "clamp((0.0004 + 0.008 * gaia_meadow_mask * max(0, gaia_accent_noise - 0.7)) * " .. gaia_decorative_control_multiplier() .. ", 0, 0.012)",
    tile_groups.meadow_green,
    "meadow-pink-lichen-decal",
    {r = 0.88, g = 0.66, b = 0.74}
)

make_decorative(
    "pink-lichen-decal",
    "ei-gaia-purple-pink-lichen-decal",
    "a[landscape]-b[gaia]-k1[purple-meadow-pink]",
    "clamp((0.0004 + 0.008 * gaia_meadow_mask * max(0, gaia_accent_noise - 0.7)) * " .. gaia_decorative_control_multiplier() .. ", 0, 0.012)",
    tile_groups.meadow_purple,
    "purple-meadow-pink-lichen-decal",
    {r = 0.74, g = 0.68, b = 0.86}
)

make_decorative(
    "pink-lichen-decal",
    "ei-gaia-wet-pink-lichen-decal",
    "a[landscape]-b[gaia]-l[wet-pink]",
    "clamp((0.00015 + 0.0045 * gaia_wet_mask * gaia_select(gaia_accent_noise, 0.66, 1.08, 0.14, 0, 1)) * " .. gaia_decorative_control_multiplier() .. ", 0, 0.007)",
    tile_groups.wet_green,
    "wet-pink-lichen-decal",
    {r = 0.80, g = 0.68, b = 0.87}
)

make_decorative(
    "pink-lichen-decal",
    "ei-gaia-bloom-pink-lichen-decal",
    "a[landscape]-b[gaia]-l1[bloom-pink]",
    "clamp((0.00015 + 0.0045 * gaia_wet_mask * gaia_select(gaia_accent_noise, 0.66, 1.08, 0.14, 0, 1)) * " .. gaia_decorative_control_multiplier() .. ", 0, 0.007)",
    tile_groups.wet_bloom,
    "bloom-pink-lichen-decal",
    {r = 0.73, g = 0.64, b = 0.86}
)

make_decorative(
    "shroom-decal",
    "ei-gaia-wet-shroom-decal",
    "a[landscape]-b[gaia]-m[wet-shroom]",
    "clamp((0.00045 + 0.0085 * gaia_wet_mask * gaia_select(gaia_accent_noise, 0.64, 1.08, 0.14, 0, 1)) * " .. gaia_decorative_control_multiplier() .. ", 0, 0.012)",
    tile_groups.wet_green,
    "wet-shroom-decal"
)

make_decorative(
    "shroom-decal",
    "ei-gaia-bloom-shroom-decal",
    "a[landscape]-b[gaia]-m1[bloom-shroom]",
    "clamp((0.00045 + 0.0085 * gaia_wet_mask * gaia_select(gaia_accent_noise, 0.64, 1.08, 0.14, 0, 1)) * " .. gaia_decorative_control_multiplier() .. ", 0, 0.012)",
    tile_groups.wet_bloom,
    "bloom-shroom-decal"
)

make_decorative(
    "shroom-decal",
    "ei-gaia-fringe-shroom-decal",
    "a[landscape]-b[gaia]-n[fringe-shroom]",
    "clamp((0.0002 + 0.005 * gaia_dry_shoulder_mask * gaia_select(gaia_accent_noise, 0.68, 1.08, 0.14, 0, 1)) * " .. gaia_decorative_control_multiplier() .. ", 0, 0.0075)",
    tile_groups.rock,
    "fringe-shroom-decal"
)

make_decorative(
    "tiny-rock",
    "ei-gaia-tiny-rock",
    "a[landscape]-c[rock]-a[tiny]",
    "clamp((0.012 + 0.075 * gaia_rock_fringe_mask + 0.05 * gaia_rock_core_mask) * " .. gaia_decorative_control_multiplier() .. ", 0, 0.13)",
    tile_groups.rock
)

make_decorative(
    "small-rock",
    "ei-gaia-small-rock",
    "a[landscape]-c[rock]-b[small]",
    "clamp((0.004 + 0.022 * gaia_rock_fringe_mask + 0.032 * gaia_rock_core_mask) * " .. gaia_decorative_control_multiplier() .. ", 0, 0.05)",
    tile_groups.rock
)

make_decorative(
    "tiny-rock-cluster",
    "ei-gaia-tiny-rock-cluster",
    "a[landscape]-c[rock]-c[cluster]",
    "clamp((0.003 + 0.025 * gaia_rock_fringe_mask + 0.017 * gaia_rock_core_mask) * " .. gaia_decorative_control_multiplier() .. ", 0, 0.042)",
    tile_groups.rock
)

return gaia_decorative_settings
