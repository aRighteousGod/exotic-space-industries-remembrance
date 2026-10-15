-- Append only to the staged ESIR control.lua, instead of the ordinary QC bridge.
-- No private native object methods or production event dispatchers are replaced.
local native_v2_stress=require("__zzz-esir-terrain-qc__/stress-v2")
native_v2_stress.configure{terrain=require("scripts/control/terrain-evolution"),
    work=require("scripts/control/terrain-ecology-work"),policy=require("lib/terrain-policy"),
    config=require("lib/terrain-evolution-config")}
remote.add_interface("ei-terrain-v2-stress-qc",{
    begin=native_v2_stress.begin,prepare_planet=native_v2_stress.prepare_planet,
    seed_trees=native_v2_stress.seed_trees,seed_working=native_v2_stress.seed_working,
    seed_idle=native_v2_stress.seed_idle,chunks=native_v2_stress.chunks,
    seed_active=native_v2_stress.seed_active,maintenance=native_v2_stress.maintenance,
    working_status=native_v2_stress.working_status,
    resume_setup=native_v2_stress.resume_setup,freeze=native_v2_stress.freeze,
    start=native_v2_stress.start,stop=native_v2_stress.stop,
    exercise_setup=native_v2_stress.exercise_setup,burst_step=native_v2_stress.burst_step,
    summary=native_v2_stress.summary,
})
