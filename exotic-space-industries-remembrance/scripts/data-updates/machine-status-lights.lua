--==============================================================================
-- ESIR FILE MAP
-- owns: early Bottleneck Lite exclusion for native ESIR status indicators
-- loaded_by: exotic-space-industries-remembrance/data-updates.lua
-- cadence: data updates before Bottleneck Lite data final fixes
-- forwarded_events: none
-- storage_roots: none
-- gui_ids: none
-- remote_interfaces: none
-- rebuild_on: production light mode or Bottleneck Lite enable setting changes
--==============================================================================
-- blueprint: .codex/esir/blueprints/machine-status-lights.md#contract

local preset = require("lib/machine-status-light-config").resolve()
local enabled = settings.startup["bnl-enable"]
if not preset.status_lights or not mods["BottleneckLite"] or not enabled or not enabled.value then return end

local definitions = require("lib/machine-status-light-definitions")
for _, registry in ipairs{definitions.replacements, definitions.additions} do
    for name, pixels in pairs(registry) do
        if #pixels > 0 then
            local prototype = data.raw["assembling-machine"][name] or data.raw.furnace[name]
            if prototype then
                -- Bottleneck Lite consumes this flag before adding its indicator
                -- and assigning the shared graphics_set.status_colors table.
                prototype.bottleneck_ignore = true ---@diagnostic disable-line: inject-field
            end
        end
    end
end
