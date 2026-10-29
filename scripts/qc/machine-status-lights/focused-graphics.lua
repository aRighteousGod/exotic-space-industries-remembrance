-- Private graphical acceptance only. Snapshot complete prototypes before this
-- atlas reduction; preserve every sprite referenced by the machines/actors.
local config = require("test-config")
if not config.visual then return end
local keep = {["__core__/graphics/empty.png"] = true}
local function retain(value)
    if type(value) == "string" and value:sub(-4) == ".png" then keep[value] = true
    elseif type(value) == "table" then for _, child in pairs(value) do retain(child) end end
end
for _, prototype_type in ipairs{"assembling-machine", "furnace", "character"} do
    for name, prototype in pairs(data.raw[prototype_type]) do
        if prototype_type == "character" or name:find("machine%-light") or
            name:find("assembling%-machine") then retain(prototype) end
    end
end
for _, case in ipairs(require("cases")) do
    retain(data.raw["assembling-machine"][case.name] or data.raw.furnace[case.name])
end
for _, name in ipairs{"lab-dark-1", "lab-dark-2", "water"} do retain(data.raw.tile[name]) end
local removed = 0
local function strip(value)
    if type(value) ~= "table" then return end
    local file = value.filename or (value.filenames and value.filenames[1])
    if type(file) == "string" and file:sub(-4) == ".png" and not keep[file] then
        value.filename, value.filenames, value.stripes = "__core__/graphics/empty.png", nil, nil
        value.width, value.height, value.size, value.x, value.y = 1, 1, nil, 0, 0
        if value.frame_count then value.frame_count = 1 end
        if value.direction_count then value.direction_count = 1 end
        value.line_length, value.lines_per_file, value.slice, value.frame_sequence = nil, nil, nil, nil
        value.mipmap_count, value.repeat_count = nil, nil
        removed = removed + 1
    end
    for _, child in pairs(value) do strip(child) end
end
-- Never rewrite mod-data snapshots: they are the unadapted preservation evidence.
for kind, prototypes_of_type in pairs(data.raw) do
    if kind ~= "mod-data" and kind ~= "utility-sprites" and kind ~= "utility-constants"
        and kind ~= "gui-style" and kind ~= "font" then strip(prototypes_of_type) end
end
log("Machine-light QC: reduced unrelated sprite entries " .. removed)
