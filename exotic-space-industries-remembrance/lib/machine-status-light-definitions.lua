--==============================================================================
-- ESIR FILE MAP
-- owns: shared production indicator coordinates and per-body light geometry
-- loaded_by: scripts/data-updates/machine-status-lights.lua and scripts/data-final-updates/machine-status-lights.lua
-- cadence: data updates and data final stage load
-- forwarded_events: none
-- storage_roots: none
-- gui_ids: none
-- remote_interfaces: none
-- rebuild_on: machine sprite geometry or indicator artwork changes
--==============================================================================
-- blueprint: .codex/esir/blueprints/machine-status-lights.md#contract

-- Zero-based centers within the source frame. Empty rows remove only the old
-- plain light and remain eligible for Bottleneck Lite's own indicators.
---@type table<string, data.Vector[]>
local replacements = {
    ["ei-crusher"] = {{345, 79}},
    ["ei-advanced-crusher"] = {{345, 79}},
    ["ei-grower"] = {{385, 81}},
    ["ei-purifier"] = {{385, 81}},
    ["ei-waver-factory"] = {{361, 92}},
    ["ei-small-simulator"] = {{361, 92}},
    ["ei-lufter"] = {{360, 92}},
    ["ei-advanced-centrifuge"] = {{129, 337}},
    ["ei-advanced-chem-plant"] = {{384, 56}},
    -- Whole inset screen, including its former cyan quadrants.
    ["ei-advanced-refinery"] = {{470, 555}},
    ["ei-bio-reactor"] = {{401, 64}},
    ["ei-high-temperature-reactor"] = {{138, 291}},
    ["ei-nano-factory"] = {{355, 351}},
    ["ei-neutron-activator"] = {{366, 92}},
    ["ei-neutron-collector"] = {{110, 401}},
    ["ei-fission-facility"] = {{214, 189}, {256, 176}, {297, 189}},
    ["ei-castor"] = {{326, 274}, {364, 248}},
    ["ei-burner-assembler"] = {},
    ["ei-steam-assembler"] = {},
    ["ei-steam-crusher"] = {},
    ["ei-bio-chamber"] = {},
    ["ei-computer-core"] = {},
    ["ei-excavator"] = {},
    ["ei-fusion-reactor"] = {},
    ["ei-quantum-computer"] = {},
}

-- Authored process lighting is never passed through the replacement rule.
---@type table<string, data.Vector[]>
local additions = {
    ["ei-arc-furnace"] = {{385, 82}},
    ["ei-plasma-heater"] = {{385, 82}},
    ["ei-caster"] = {{361, 93}},
}

---@class EiMachineStatusLightDefinitions
---@field replacements table<string, data.Vector[]>
---@field additions table<string, data.Vector[]>
---@field radius table<string, number>
---@type EiMachineStatusLightDefinitions
local definitions = {
    replacements = replacements,
    additions = additions,
    radius = {["ei-advanced-refinery"] = 0.5},
}
return definitions
