-- Private graphics fixture, after the unmodified final-data snapshot.
local keep = {["__core__/graphics/empty.png"] = true}
local function retain(value)
    if type(value) == "string" and value:sub(-4) == ".png" then keep[value] = true
    elseif type(value) == "table" then for _, child in pairs(value) do retain(child) end end
end
for _, name in ipairs(require("cases")) do retain(data.raw["assembling-machine"][name]) end
retain(data.raw["mining-drill"]["ei-steam-oil-pumpjack"])
-- Elevated rolling-stock slope sets require their native eight-direction layout.
for _, kind in ipairs{"locomotive", "cargo-wagon", "fluid-wagon", "artillery-wagon", "car", "character"} do retain(data.raw[kind]) end
for kind, prototypes_of_type in pairs(data.raw) do
    if kind:find("rail", 1, true) or kind:find("belt", 1, true) or kind:find("splitter", 1, true)
        or kind:find("loader", 1, true) or kind == "inserter" or kind == "electric-pole"
        or kind == "tree" or kind == "plant" then retain(prototypes_of_type) end
end
for _, pair in ipairs{{"tile", "lab-dark-1"}, {"pipe", "pipe"}, {"constant-combinator", "constant-combinator"}} do
    retain(data.raw[pair[1]][pair[2]])
end
-- Keep the structural sprite contracts of ordinary construction types. The large
-- unrelated combat/spider atlases account for the memory this fixture must avoid.
local reduced = {unit = true, corpse = true, ["spider-vehicle"] = true, ["spider-leg"] = true,
    ["mining-drill"] = true,
    ["ammo-turret"] = true, ["fluid-turret"] = true, ["electric-turret"] = true,
    projectile = true, explosion = true, stream = true, sticker = true}
for kind, prototypes_of_type in pairs(data.raw) do
    if kind ~= "mod-data" and not reduced[kind] then retain(prototypes_of_type) end
end
local function strip(value)
    if type(value) ~= "table" then return end
    local file = value.filename or (value.filenames and value.filenames[1])
        or (value.stripes and value.stripes[1] and value.stripes[1].filename)
    if type(file) == "string" and file:sub(-4) == ".png" and not keep[file] then
        value.filename, value.filenames, value.stripes = "__core__/graphics/empty.png", nil, nil
        -- Wet-fluid masks reserve border pixels; a one-pixel placeholder underflows.
        value.width, value.height, value.size, value.x, value.y = 16, 16, nil, 0, 0
        if value.frame_count then value.frame_count = 1 end
        if value.direction_count then value.direction_count = 1 end
        if value.variation_count then value.variation_count = 1 end
        value.line_length, value.lines_per_file, value.slice, value.frame_sequence = nil, nil, nil, nil
        value.mipmap_count, value.repeat_count = nil, nil
    end
    for _, child in pairs(value) do strip(child) end
end
for kind, prototypes_of_type in pairs(data.raw) do
    if kind ~= "mod-data" and kind ~= "utility-sprites" and kind ~= "utility-constants"
        and kind ~= "gui-style" and kind ~= "font" then strip(prototypes_of_type) end
end
-- Direction shuffles cannot address removed directions in reduced corpse atlases.
for _, corpse in pairs(data.raw.corpse) do corpse.direction_shuffle = nil end
for _, unit in pairs(data.raw.unit) do unit.alternative_attacking_frame_sequence = nil end
local pole = table.deepcopy(data.raw["electric-pole"].substation)
pole.name = "mirroring-qc-pole"
pole.minable, pole.radius_visualisation_picture, pole.light = nil, nil, nil
pole.collision_box, pole.collision_mask = {{0, 0}, {0, 0}}, {layers = {}}
pole.supply_area_distance, pole.maximum_wire_distance = 9, 0
pole.pictures = {filename = "__core__/graphics/empty.png", width = 1, height = 1, direction_count = 1}
pole.connection_points = {{wire = {}, shadow = {}}}
data:extend{pole, {
    type = "electric-energy-interface", name = "mirroring-qc-supply",
    icon = "__base__/graphics/icons/accumulator.png", icon_size = 64,
    flags = {"not-on-map"}, collision_box = {{0, 0}, {0, 0}}, collision_mask = {layers = {}},
    energy_source = {type = "electric", buffer_capacity = "100MJ", usage_priority = "primary-output",
        input_flow_limit = "0W", output_flow_limit = "1TW"},
    energy_production = "0W", energy_usage = "0W",
    picture = {filename = "__core__/graphics/empty.png", width = 1, height = 1},
}}
