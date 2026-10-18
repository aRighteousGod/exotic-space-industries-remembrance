-- Appended only to the isolated current-source main pack by the terrain runner.
-- Setter/inspection proxies never survive the wrapped call. This fixture is not
-- a performance measurement: proxy overhead is intentional test instrumentation.
local field_fixture=require("__zzz-esir-field-report-qc__/fixture")
local field_context={gui=require("scripts/control/terrain-gui"),
    terrain=require("scripts/control/terrain-evolution"),
    field=require("scripts/control/terrain-field-report"),
    fulgora=require("scripts/control/fulgora-day-length-variation")}
field_fixture.instrument(field_context)
remote.add_interface("ei-field-report-qc",{
    step=function(index,tick) return field_fixture.step(field_context,game.get_player(index),tick) end,
    result=function() return field_fixture.result() end,
})
