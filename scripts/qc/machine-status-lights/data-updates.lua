-- Capture the early flag before BNL consumes it, and seed another mod's flag.
local config = require("test-config")
local flags = {}
for _, case in ipairs(require("cases")) do
    local prototype = data.raw["assembling-machine"][case.name] or data.raw.furnace[case.name]
    flags[case.name] = prototype.bottleneck_ignore == true
end
data.raw["assembling-machine"]["assembling-machine-1"].bottleneck_ignore = true
data:extend{{type = "mod-data", name = "machine-light-early-qc", data_type = "machine-light-early-qc",
    data = {flags = flags, bottleneck = config.bottleneck or "absent"}}}
