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
        for _,key in ipairs(hazards) do check(not cfg[key],name.." hazard stays off: "..key) end
        check(cfg.wildfire=="off",name.." wildfire stays off")
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

-- Load the production service with explicit mock boundaries. The real cursor,
-- history, queue and updater functions remain in use; only native work is mocked.
package.loaded["lib/terrain-evolution-config"]=config
package.loaded["lib/lib"]={get_valid_entity=function(e) return e and e.valid and e end}
package.loaded["lib/terrain-policy"]={}
package.loaded["scripts/control/terrain-calendar"]={service=function() end}
package.loaded["lib/firefighting-config"]={}
package.loaded["lib/spawner-presets"]={}
storage={ei={}}
local terrain=dofile(pack.."scripts/control/terrain-evolution.lua")
local function upvalue(fn,name,replacement)
    for i=1,100 do
        local key,value=debug.getupvalue(fn,i)
        if not key then break end
        if key==name then if replacement then debug.setupvalue(fn,i,replacement) end;return value end
    end
    error("Missing production upvalue: "..name)
end
local updater=terrain.updater
upvalue(updater,"discover",function() end)
upvalue(updater,"commit",function() end)
upvalue(updater,"hazards",function() end)
local recovery=upvalue(updater,"recover_tiles")
local events=upvalue(updater,"service_events")
local trees=upvalue(updater,"recover_trees")
local tree_queries,soil_queries,tile_queries,recovery_queries,tree_recoveries={},{},{},{},0
local function query(root,budget,surface,x,y,cause,tick,target,recover)
    if budget.searches<=0 or budget.writes<=0 or budget.candidates<=0 then return nil end
    budget.searches=budget.searches-1;budget.used_searches=budget.used_searches+1
    budget.writes=budget.writes-1;budget.used_writes=budget.used_writes+1
    budget.candidates=budget.candidates-1;budget.used_candidates=budget.used_candidates+1
    local list=recover and recovery_queries or cause=="pollution" and soil_queries or tile_queries
    local id=recover and x or math.floor(x/32)
    list[id]=(list[id] or 0)+1
    return true
end
-- These functions share the production propose upvalue; installing once suffices.
upvalue(recovery,"propose",query)
check(upvalue(events,"propose")==query,"Shared guarded proposal seam")
upvalue(trees,"admit",function() tree_recoveries=tree_recoveries+1;return true end)
upvalue(updater,"tree_service",function(root,budget,record)
    if root.test_trees and budget.searches>0 then
        budget.searches=budget.searches-1;budget.used_searches=budget.used_searches+1
        tree_queries[record.x]=(tree_queries[record.x] or 0)+1
    end
end)
local function set() return {items={},index={},cursor=1} end
local function push(s,record,id)
    record.id=id;s.items[#s.items+1]=record;s.index[id]=#s.items
end
local function fresh(name,overrides)
    local cfg=config.resolve({performance=name},{})
    for k,v in pairs(overrides or {}) do cfg[k]=v end
    cfg.degradation=false;cfg.tree_stress=false;cfg.tree_regrowth=false
    cfg.recovery=true;cfg.clean_seconds=1;cfg.recovery_seconds=1;cfg.soil_seconds=1
    cfg.dirty_seconds=1;cfg.hazard_radius=1;cfg.protection_buffer=0
    local surface={valid=true,index=1,pollutant_type={name="pollution"},
        is_chunk_generated=function() return true end,get_pollution=function() return 0 end,
        get_tile=function() return {name="grass-3"} end}
    local entry={surface=surface,config=cfg,chunk_tokens={},generation=0}
    local root={config=cfg,surfaces={[1]=entry},enabled_surfaces=1,next_tick=cfg.interval,
        next_search=cfg.search_interval,pass=0,counters={},active=set(),history=set(),trees=set(),pending=set(),fires=set()}
    storage.ei.terrain_evolution=root
    tree_queries={};soil_queries={};tile_queries={};recovery_queries={};tree_recoveries=0
    return root,entry,surface
end
local function active(root,entry,surface,x)
    local token={references=1};entry.chunk_tokens[x..":0"]=token
    local record={surface=surface,owner=entry,x=x,y=0,chunk_cell=x..":0",chunk_token=token,
        sample_tick=0,dirty_since=-100000,clean_since=-100000,pollution=200,
        next_soil=0,next_tree=0,next_hazard=0,resident_since=0}
    push(root.active,record,"1:"..x..":0");return record
end
local function run(root,ticks)
    local previous,grant,lanes=nil,nil,{}
    for tick=1,ticks do
        -- Keep mock samples fresh to isolate scheduling from native sampling.
        for _,record in ipairs(root.active.items) do record.sample_tick=tick end
        updater{tick=tick}
        local last=root.last_service
        if last and last.tick==tick then
            if previous then check(tick-previous==root.config.interval,"Exact native-dispatch opportunity spacing") end
            previous=tick
            for key,maximum in pairs({candidates=root.config.candidates,writes=root.config.writes,
                searches=root.config.searches,histories=root.config.histories,events=root.config.events,
                active_samples=root.config.active_chunks}) do check(last[key]<=maximum,"Service cap "..key) end
            if last.search_allowance>0 then
                if grant then check(tick-grant>=root.config.search_interval,"No accumulated query grants") end
                grant=tick;lanes[last.query_lane]=true
            else check(last.searches==0,"No entity searches on intervening service") end
        end
    end
    check(lanes[0] and lanes[1] and lanes[2],"All query priorities remain reachable")
end
for name in pairs(expected) do
    local root,entry,surface=fresh(name);root.test_trees=true
    for x=0,2 do active(root,entry,surface,x) end
    run(root,root.config.search_interval*30)
    for x=0,2 do check(tree_queries[x]~=nil,name.." independent tree coverage "..x) end
end
do
    local root,entry,surface=fresh("custom",{interval=11,search_interval=32});root.test_trees=true
    for x=0,2 do active(root,entry,surface,x) end
    run(root,1100)
    for x=0,2 do check(tree_queries[x]~=nil,"Nondivisible Custom tree coverage "..x) end
end
for _,name in ipairs({"lean","ultra-low"}) do
    local root,entry,surface=fresh(name);root.config.degradation=true
    local count=name=="lean" and 2 or 8
    for x=0,count-1 do active(root,entry,surface,x) end
    run(root,root.config.search_interval*count*4)
    for x=0,count-1 do check(soil_queries[x]~=nil,name.." independent soil coverage "..x) end
end
do
    local root,entry,surface=fresh("ultra-low");root.config.tree_stress=true
    local chunk=active(root,entry,surface,0)
    for x=0,3 do
        push(root.history,{surface=surface,owner=entry,x=x,y=0,chunk_cell="0:0",chunk_token=chunk.chunk_token,
            expected="grass-3",origin="grass-1",path={"grass-1"},cause="thermal",next_tick=0},"1:"..x..":0")
    end
    local tree={valid=true,tree_gray_stage_index=1,position={x=0,y=0}}
    push(root.trees,{entity=tree,expected=1,surface=surface,next_tick=0,
        climate={surface=surface,x=0,y=0,sample_tick=0,clean_since=-100000}},"tree")
    run(root,4096)
    for x=0,3 do check(recovery_queries[x]~=nil,"Ultra Low mixed history recovery "..x) end
    check(tree_recoveries>0,"Ultra Low tree history progresses beside tile history")
    check(#root.history.items==4,"No committed histories discarded by inspection")
end
do
    local root,entry,surface=fresh("ultra-low")
    for x=0,7 do
        push(root.pending,{surface=surface,owner=entry,generation=0,x=x*32+8,y=8,cause="thermal",offset=0},"pending:"..x)
    end
    run(root,root.config.search_interval*128)
    for x=0,7 do check(tile_queries[x]~=nil,"Ultra Low queued tile coverage "..x) end
    check(#root.pending.items==0,"Finite scar descriptors finish")
end
print("PASS: "..checks.." standalone assertions; mocked boundaries, no Factorio engine or performance claim")
