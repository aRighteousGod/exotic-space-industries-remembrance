-- Append only to the isolated staged ESIR control.lua after copying
-- lifecycle-tests.lua into the zzz-esir-terrain-qc helper directory.
local lifecycle_tests=require("__zzz-esir-terrain-qc__.lifecycle-tests")
local lifecycle_terrain=require("scripts/control/terrain-evolution")
local lifecycle_calendar=require("scripts/control/terrain-calendar")
remote.add_interface("ei-terrain-lifecycle-qc",{
    run=function()
        local result=lifecycle_tests.run(lifecycle_terrain,lifecycle_calendar)
        helpers.write_file("terrain-lifecycle-qc.json",helpers.table_to_json(result),false)
        return result
    end,
    finish_clear=function()
        local result=lifecycle_tests.finish_clear(lifecycle_terrain,lifecycle_calendar)
        helpers.write_file("terrain-lifecycle-qc.json",helpers.table_to_json(result),false)
        return result
    end,
})
