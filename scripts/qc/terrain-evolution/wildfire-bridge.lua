-- Staged main-pack bridge only: the release mod exposes no QC interface.
local wildfire_tests=require("__zzz-esir-terrain-qc__.wildfire-tests")
local wildfire_terrain=require("scripts/control/terrain-evolution")
-- Chunk generation queues authored sites for later ticks. Suppress that unrelated
-- fixture-only producer before map setup, so protected alien flowers cannot be
-- inserted into the controlled forest after its entities have been cleared.
-- Production protection rules and native forest/fire behavior remain unchanged.
local wildfire_spawner=require("scripts/control/alien-spawner")
wildfire_spawner.allowed_surfaces.nauvis=nil
remote.add_interface("ei-terrain-wildfire-qc",{
    step=function(tick) return wildfire_tests.step(wildfire_terrain,tick) end,
})
