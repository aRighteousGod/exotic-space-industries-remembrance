-- Append only to staged ESIR control.lua; require executes at module loading.
local guard_tests=require("__zzz-esir-terrain-qc__.guard-tests")
local guard_terrain=require("scripts/control/terrain-evolution")
local guard_calendar=require("scripts/control/terrain-calendar")
local guard_vat=require("scripts/control/auric-inoculation-vat")
remote.add_interface("ei-terrain-guard-qc",{run=function()
    local result=guard_tests.run(guard_terrain,guard_calendar,guard_vat)
    helpers.write_file("terrain-guard-qc.json",helpers.table_to_json(result),false)
    return result
end,finish=function()
    local result=guard_tests.finish(guard_terrain,guard_calendar)
    helpers.write_file("terrain-guard-qc.json",helpers.table_to_json(result),false)
    return result
end})
