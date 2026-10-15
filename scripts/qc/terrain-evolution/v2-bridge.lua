-- Private native bridge appended only to the staged gameplay pack.
local v2_qc=require("__zzz-esir-terrain-qc__/v2-tests")
local v2_context={terrain=require("scripts/control/terrain-evolution"),work=require("scripts/control/terrain-ecology-work"),policy=require("lib/terrain-policy")}
remote.add_interface("ei-terrain-v2-qc",{step=function(phase,tick) return v2_qc.step(v2_context,phase,tick) end})
