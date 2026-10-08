--==============================================================================
-- ESIR FILE MAP
-- owns: finite resource depletion admission adapter
-- loaded_by: control.lua
-- cadence: bounded resource depletion events
-- forwarded_events: owner-routed callbacks only
-- storage_roots: none; terrain owner holds admitted work
-- gui_ids: none
-- remote_interfaces: none
-- rebuild_on: owner lifecycle and configuration changes
--==============================================================================
-- blueprint: .codex/esir/blueprints/mining-scars.md#contract
-- Depletion admission remains event-owned; terrain evolution supplies the common
-- finite work budget and protected tile writer. The event names a resource, not
-- its drill, so eligibility means coverage by a supported quarry/drill.
local terrain=require("scripts/control/terrain-evolution")
local model={}
function model.on_resource_depleted(event)
    terrain.on_resource_depleted(event)
end
return model
