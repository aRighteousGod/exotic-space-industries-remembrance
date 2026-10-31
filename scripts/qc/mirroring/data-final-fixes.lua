-- Last dependency in this private fixture: capture final prototypes without edits.
local snapshot = {entities = {}, quality = mods.quality ~= nil}
for _, kind in ipairs{"assembling-machine", "furnace", "inserter", "mining-drill", "rocket-silo"} do
    for name, prototype in pairs(data.raw[kind]) do
        snapshot.entities[name] = table.deepcopy(prototype)
    end
end
for _, name in ipairs(require("cases")) do
    assert(snapshot.entities[name], "Missing reviewed machine: " .. name)
end
data:extend{{type = "mod-data", name = "mirroring-qc", data_type = "mirroring-qc", data = snapshot}}
if require("test-config").visual then require("render-data") end
