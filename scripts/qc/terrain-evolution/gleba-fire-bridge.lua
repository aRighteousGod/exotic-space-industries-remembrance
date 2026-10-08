-- Append to staged main control; also copy gleba-fire-tests.lua to staged helper.
local gleba_fire_tests=require("__zzz-esir-terrain-qc__.gleba-fire-tests")
local gleba_fire_terrain=require("scripts/control/terrain-evolution")
local gleba_fire_policy=require("lib/terrain-policy")
remote.add_interface("ei-terrain-gleba-fire-qc",{run=function()
    local result=gleba_fire_tests.run(gleba_fire_terrain,gleba_fire_policy)
    helpers.write_file("terrain-gleba-fire-qc.json",helpers.table_to_json(result),false)
    return result
end})
