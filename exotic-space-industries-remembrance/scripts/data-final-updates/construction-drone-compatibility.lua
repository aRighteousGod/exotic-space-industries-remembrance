--==============================================================================
-- ESIR FILE MAP
-- owns: Construction Drones collision policy for ESIR electric drill upgrades
-- loaded_by: data-final-fixes.lua after final collision-layer passes
-- cadence: data-final-fixes only
-- forwarded_events: none
-- storage_roots: none
-- gui_ids: none
-- remote_interfaces: none
-- rebuild_on: data stage reload
--==============================================================================
-- blueprint: .codex/esir/blueprints/startup-and-integration.md#contract

if not mods["Construction_Drones_Forked"] then return end

-- blueprint-ref: .codex/esir/blueprints/startup-and-integration.md#construction-drones
-- The fork excludes the vanilla drill from its drone-blocking layer, but adds
-- it to these same-footprint upgrade targets. Copy the canonical policy after
-- hover-layer propagation too: merely removing construction_drone leaves an
-- extra hover layer on the now-explicit ESIR masks and still breaks upgrading.
local drills = data.raw["mining-drill"]
local base = drills and drills["electric-mining-drill"]
if base then
    for _, name in ipairs({"ei-advanced-electric-mining-drill", "ei-superior-electric-mining-drill"}) do
        local drill = drills[name]
        if drill then
            -- Preserve nil so the engine inherits the same native default.
            drill.collision_mask = table.deepcopy(base.collision_mask)
        end
    end
end
