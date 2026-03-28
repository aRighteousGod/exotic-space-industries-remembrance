local model = {}

local function merge_tile_groups(...)
    local merged = {}

    for i = 1, select("#", ...) do
        local tile_group = select(i, ...)
        for _, tile_name in ipairs(tile_group) do
            merged[#merged + 1] = tile_name
        end
    end

    return merged
end

model.tile_groups = {
    meadow = {
        "ei-gaia-grass-1",
        "ei-gaia-grass-1-var",
    },
    wet = {
        "ei-gaia-grass-2",
        "ei-gaia-grass-2-var",
        "ei-gaia-grass-2-var-2",
    },
    rock_fringe = {
        "ei-gaia-rock-1",
    },
    rock_core = {
        "ei-gaia-rock-2",
        "ei-gaia-rock-3",
    },
    water = {
        "ei-gaia-water",
    },
}

model.tile_groups.grass = merge_tile_groups(model.tile_groups.meadow, model.tile_groups.wet)
model.tile_groups.rock = merge_tile_groups(model.tile_groups.rock_fringe, model.tile_groups.rock_core)
model.tile_groups.lush = merge_tile_groups(model.tile_groups.meadow, model.tile_groups.wet)
model.tile_groups.land = merge_tile_groups(model.tile_groups.lush, model.tile_groups.rock)

model.primary_tile_groups = {
    meadow = model.tile_groups.meadow,
    wet = model.tile_groups.wet,
    rock_fringe = model.tile_groups.rock_fringe,
    rock_core = model.tile_groups.rock_core,
    water = model.tile_groups.water,
}

return model
