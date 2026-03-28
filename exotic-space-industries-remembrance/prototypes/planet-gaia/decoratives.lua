--====================================================================================================
--DECORATIVES FOR GAIA
--====================================================================================================

local gaia_biomes = require("__exotic-space-industries-remembrance__/prototypes/planet-gaia/biomes")
local tile_groups = gaia_biomes.tile_groups

local gaia_decorative_settings = {
    ["ei-gaia-meadow-carpet-grass"] = {frequency = 1.8, richness = 1, size = 1.45},
    ["ei-gaia-wet-carpet-grass"] = {frequency = 1.25, richness = 1, size = 1.1},
    ["ei-gaia-meadow-hairy-grass"] = {frequency = 1.15, richness = 1, size = 0.9},
    ["ei-gaia-wet-hairy-grass"] = {frequency = 1.55, richness = 1, size = 1.2},
    ["ei-gaia-meadow-bush-mini"] = {frequency = 0.48, richness = 1, size = 0.75},
    ["ei-gaia-fringe-bush-mini"] = {frequency = 0.24, richness = 1, size = 0.5},
    ["ei-gaia-wet-asterisk-mini"] = {frequency = 0.36, richness = 1, size = 0.5},
    ["ei-gaia-shore-asterisk-mini"] = {frequency = 0.28, richness = 1, size = 0.45},
    ["ei-gaia-fringe-lichen-decal"] = {frequency = 0.34, richness = 1, size = 0.55},
    ["ei-gaia-core-lichen-decal"] = {frequency = 0.22, richness = 1, size = 0.45},
    ["ei-gaia-meadow-pink-lichen-decal"] = {frequency = 0.16, richness = 1, size = 0.42},
    ["ei-gaia-wet-pink-lichen-decal"] = {frequency = 0.08, richness = 1, size = 0.28},
    ["ei-gaia-wet-shroom-decal"] = {frequency = 0.18, richness = 1, size = 0.34},
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

local function tint_pictures(decorative, tint)
    if not tint then
        return
    end

    for _, picture in ipairs(decorative.pictures or {}) do
        picture.tint = tint
    end
end

local function make_decorative(base_name, new_name, order, probability_expression, tile_restriction, tint)
    local decorative = data.raw["optimized-decorative"][base_name]
    if not decorative then
        error("Missing base decorative prototype: " .. base_name)
    end

    decorative = table.deepcopy(decorative)
    decorative.name = new_name
    decorative.autoplace = decorative_autoplace(decorative.autoplace, order, probability_expression, tile_restriction)
    tint_pictures(decorative, tint)

    data:extend({decorative})
end

make_decorative(
    "green-carpet-grass",
    "ei-gaia-meadow-carpet-grass",
    "a[landscape]-b[gaia]-a[meadow-carpet]",
    "clamp((0.018 + 0.11 * gaia_meadow_mask * (0.45 + gaia_lushness) * gaia_select(gaia_wetness, -1, 0.72, 0.2, 0.32, 1)) * " .. gaia_decorative_control_multiplier() .. ", 0, 0.16)",
    tile_groups.meadow,
    {r = 0.46, g = 0.63, b = 0.32}
)

make_decorative(
    "green-carpet-grass",
    "ei-gaia-wet-carpet-grass",
    "a[landscape]-b[gaia]-b[wet-carpet]",
    "clamp((0.006 + 0.065 * gaia_wet_mask * (0.4 + gaia_wetness) * gaia_select(gaia_accent_noise, 0.24, 1.04, 0.18, 0.3, 1)) * " .. gaia_decorative_control_multiplier() .. ", 0, 0.11)",
    tile_groups.wet,
    {r = 0.56, g = 0.82, b = 0.72}
)

make_decorative(
    "green-hairy-grass",
    "ei-gaia-meadow-hairy-grass",
    "a[landscape]-b[gaia]-c[meadow-hair]",
    "clamp((0.006 + 0.06 * gaia_meadow_mask * gaia_select(gaia_accent_noise, 0.34, 1.0, 0.16, 0.28, 1)) * " .. gaia_decorative_control_multiplier() .. ", 0, 0.09)",
    tile_groups.meadow,
    {r = 0.77, g = 0.88, b = 0.58}
)

make_decorative(
    "green-hairy-grass",
    "ei-gaia-wet-hairy-grass",
    "a[landscape]-b[gaia]-d[wet-hair]",
    "clamp((0.008 + 0.1 * gaia_wet_mask * (0.45 + gaia_wetness) + 0.018 * gaia_wet_transition_mask) * " .. gaia_decorative_control_multiplier() .. ", 0, 0.15)",
    tile_groups.wet,
    {r = 0.75, g = 0.94, b = 0.88}
)

make_decorative(
    "green-bush-mini",
    "ei-gaia-meadow-bush-mini",
    "a[landscape]-b[gaia]-e[meadow-bush]",
    "clamp((0.002 + 0.017 * gaia_meadow_mask * gaia_lushness * max(0, gaia_accent_noise - 0.3)) * " .. gaia_decorative_control_multiplier() .. ", 0, 0.028)",
    tile_groups.meadow,
    {r = 0.9, g = 0.86, b = 0.58}
)

make_decorative(
    "green-bush-mini",
    "ei-gaia-fringe-bush-mini",
    "a[landscape]-b[gaia]-f[fringe-bush]",
    "clamp((0.001 + 0.013 * gaia_dry_shoulder_mask * gaia_select(gaia_accent_noise, 0.4, 1.04, 0.14, 0, 1)) * " .. gaia_decorative_control_multiplier() .. ", 0, 0.018)",
    tile_groups.rock,
    {r = 0.9, g = 0.55, b = 0.34}
)

make_decorative(
    "green-asterisk-mini",
    "ei-gaia-wet-asterisk-mini",
    "a[landscape]-b[gaia]-g[wet-asterisk]",
    "clamp((0.002 + 0.025 * gaia_wet_mask * max(0, gaia_accent_noise - 0.42)) * " .. gaia_decorative_control_multiplier() .. ", 0, 0.036)",
    tile_groups.wet,
    {r = 0.83, g = 0.97, b = 0.92}
)

make_decorative(
    "green-asterisk-mini",
    "ei-gaia-shore-asterisk-mini",
    "a[landscape]-b[gaia]-h[shore-asterisk]",
    "clamp((0.0014 + 0.022 * gaia_wet_transition_mask * gaia_select(gaia_water_edge_mask, 0.04, 1.0, 0.12, 0.36, 1)) * " .. gaia_decorative_control_multiplier() .. ", 0, 0.028)",
    tile_groups.wet,
    {r = 0.84, g = 0.78, b = 0.93}
)

make_decorative(
    "lichen-decal",
    "ei-gaia-fringe-lichen-decal",
    "a[landscape]-b[gaia]-i[fringe-lichen]",
    "clamp((0.0015 + 0.018 * gaia_rock_fringe_mask * max(0, gaia_accent_noise - 0.3)) * " .. gaia_decorative_control_multiplier() .. ", 0, 0.028)",
    tile_groups.rock_fringe,
    {r = 0.89, g = 0.83, b = 0.65}
)

make_decorative(
    "lichen-decal",
    "ei-gaia-core-lichen-decal",
    "a[landscape]-b[gaia]-j[core-lichen]",
    "clamp((0.001 + 0.014 * gaia_rock_core_mask * gaia_select(gaia_accent_noise, 0.26, 1.06, 0.16, 0.22, 1)) * " .. gaia_decorative_control_multiplier() .. ", 0, 0.02)",
    tile_groups.rock_core,
    {r = 0.76, g = 0.72, b = 0.86}
)

make_decorative(
    "pink-lichen-decal",
    "ei-gaia-meadow-pink-lichen-decal",
    "a[landscape]-b[gaia]-k[meadow-pink]",
    "clamp((0.0004 + 0.008 * gaia_meadow_mask * max(0, gaia_accent_noise - 0.7)) * " .. gaia_decorative_control_multiplier() .. ", 0, 0.012)",
    tile_groups.meadow,
    {r = 0.9, g = 0.57, b = 0.63}
)

make_decorative(
    "pink-lichen-decal",
    "ei-gaia-wet-pink-lichen-decal",
    "a[landscape]-b[gaia]-l[wet-pink]",
    "clamp((0.00015 + 0.0045 * gaia_wet_mask * gaia_select(gaia_accent_noise, 0.66, 1.08, 0.14, 0, 1)) * " .. gaia_decorative_control_multiplier() .. ", 0, 0.007)",
    tile_groups.wet,
    {r = 0.8, g = 0.63, b = 0.85}
)

make_decorative(
    "shroom-decal",
    "ei-gaia-wet-shroom-decal",
    "a[landscape]-b[gaia]-m[wet-shroom]",
    "clamp((0.00045 + 0.0085 * gaia_wet_mask * gaia_select(gaia_accent_noise, 0.64, 1.08, 0.14, 0, 1)) * " .. gaia_decorative_control_multiplier() .. ", 0, 0.012)",
    tile_groups.wet,
    {r = 0.9, g = 0.8, b = 0.96}
)

make_decorative(
    "shroom-decal",
    "ei-gaia-fringe-shroom-decal",
    "a[landscape]-b[gaia]-n[fringe-shroom]",
    "clamp((0.0002 + 0.005 * gaia_dry_shoulder_mask * gaia_select(gaia_accent_noise, 0.68, 1.08, 0.14, 0, 1)) * " .. gaia_decorative_control_multiplier() .. ", 0, 0.0075)",
    tile_groups.rock,
    {r = 0.95, g = 0.74, b = 0.48}
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
