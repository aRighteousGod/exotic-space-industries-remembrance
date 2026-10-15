-- Standalone Lua screening only. Mocked native boundaries cannot validate Factorio
-- APIs, real tile writes, save/reload, or performance; run the native lanes later.
local pack="exotic-space-industries-remembrance/"
local config=dofile(pack.."lib/terrain-evolution-config.lua")
local checks=0
local function check(ok,label)
    checks=checks+1;assert(ok,label)
end
local expected={
    ["ultra-low"]={16,128,1,1},low={16,64,2,2},lean={16,32,4,4},
    balanced={8,16,4,4},detailed={4,8,8,4},
    ["high-fidelity"]={2,4,8,4},["ultra-high-fidelity"]={1,2,16,8},
}
local hazards={"aging","rot","flood","drought","cliffs","blood","paving","seasonal_ecology"}
for name,values in pairs(expected) do
    for _,intensity in ipairs({"restrained","standard","severe","custom"}) do
        local cfg,errors=config.resolve({performance=name,intensity=intensity},{})
        check(#errors==0,name.." config validation")
        check(cfg.interval==values[1] and cfg.search_interval==values[2] and cfg.histories==values[3] and cfg.writes==values[4],name.." cadence and batch contract")
        for key,value in pairs(config.performance_presets[name]) do
            local row=config.by_key[key]
            check(cfg[key]==value and value>=row.min and value<=row.max,name.." intensity-independent budget "..key)
        end
        for _,key in ipairs(hazards) do check(cfg[key],name.." ecology defaults on: "..key) end
        check(cfg.mining_recovery and cfg.wildfire=="contained",name.." mining recovery and contained wildfire default on")
        local disabled={performance=name,intensity=intensity,wildfire="off",mining_recovery=false}
        for _,key in ipairs(hazards) do disabled[key]=false end
        local explicit=config.resolve(disabled,{})
        for _,key in ipairs(hazards) do check(not explicit[key],name.." explicit ecology disable retained: "..key) end
        check(not explicit.mining_recovery and explicit.wildfire=="off",name.." explicit recovery/fire disable retained")
        check(not config.resolve_surface(cfg,"fulgora").seasonal_daylight,name.." Fulgora exclusion")
    end
end
local custom={performance="custom"}
for key in pairs(config.performance_presets.lean) do custom[key]=config.by_key[key].max end
local resolved,errors=config.resolve(custom,{})
check(#errors==0,"Custom maxima remain valid")
for key,value in pairs(custom) do check(resolved[key]==value,"Custom maximum "..key) end
local _,invalid=config.resolve({performance="custom",interval=0,search_interval=0,candidates=26,active_chunks=1},{})
check(#invalid==4,"Cadence and atomic work floors")
for key in pairs(config.performance_presets.lean) do
    local _,rejected=config.resolve_surface(config.resolve({},{}),"nauvis",{[key]=config.by_key[key].default})
    check(#rejected==1,"Global budget rejects surface override: "..key)
end

-- V2 supersedes the former three-class service harness.
dofile("scripts/qc/terrain-evolution/v2-static.lua")
print("PASS "..checks.." preset configuration checks")
