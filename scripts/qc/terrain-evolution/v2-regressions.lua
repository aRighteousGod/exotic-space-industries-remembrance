-- Actual production regression suite; native API boundaries are mocked.
-- Run from repo root with scripts/qc/terrain-evolution/v2-regressions.lua.
-- Reuses the shipping standalone fixture's mock prelude; tests below retain
-- actual work/scheduler/updater/consumer/commit implementations.
local file=assert(io.open("scripts/qc/terrain-evolution/v2-static.lua","r"))
local source=file:read("*a");file:close()
local boundary=assert(source:find("local saved={}",1,true),"fixture prelude boundary")
local prelude=source:sub(1,boundary-1)
assert(load(prelude..[===[
local failures=0
check=function(ok,label)
    checks=checks+1
    if not ok then failures=failures+1;print("FAIL "..label) end
end
local original_discover=up(update,"discover")
local create_active=up(original_discover,"active")
local put=up(entity_event,"put")
up(update,"discover",function() end)
terrain.configure{
    gaia={resolve_gaia_tree_name=function() return "ei-gaia-tree-01" end},
    vat={is_terrain_claimed=function() return false end},
}
package.loaded["scripts/control/terrain-calendar"].remove_surface=function() end
local function run(root,first,last,step)
    for tick=first,last,step or root.config.interval do update{tick=tick} end
end
local function add_surface(root,index,enabled)
    local surface={valid=true,index=index,is_chunk_generated=function() return true end,
        get_pollution=function() return 0 end,pollutant_type={name="pollution"},
        find_entities_filtered=function() return {} end}
    local entry={surface=surface,config=config.resolve_surface(root.config,"nauvis"),
        planet="nauvis",chunk_tokens={},protected={},classified={},hazard_epoch=1}
    entry.config.enabled=enabled
    root.surfaces[index]=entry;root.surface_order[#root.surface_order+1]=index
    return entry
end
local function native_tiles(surface,initial)
    local mask={layers={}}
    local prototype={is_foundation=false,collision_mask=mask}
    prototypes={entity={["ei-gaia-tree-01"]={}},tile={}}
    for _,name in ipairs{"grass-1","grass-2","grass-3","grass-4"} do prototypes.tile[name]=prototype end
    local names,writes={},0
    local function position(x,y)
        if type(x)=="table" then return x.x or x[1],x.y or x[2] end
        return x,y
    end
    surface.get_tile=function(x,y)
        x,y=position(x,y)
        return {valid=true,name=names[x..":"..y] or initial(x,y),prototype=prototype,
            collides_with=function() return false end}
    end
    surface.set_tiles=function(tiles)
        for _,tile in ipairs(tiles) do local x,y=position(tile.position)
            names[x..":"..y]=tile.name;writes=writes+1
        end
    end
    surface.destroy_decoratives=function() end
    return function() return writes end
end
local function history(root,entry,i,expected,deadline,legacy)
    local x=i*32;local cell=i..":0";local token={references=1}
    entry.chunk_tokens[cell]=token
    local record={id="1:"..x..":0",surface=entry.surface,owner=entry,x=x,y=0,
        origin="grass-2",expected=expected,path={"grass-2"},cause="pollution",
        next_tick=deadline,chunk_cell=cell,chunk_token=token}
    if legacy then add(root.history,record) else put(root.history,record.id,record) end
    return record
end

-- Legacy E/T membership must survive conversion and enable the real action.
local root,entry=fresh({performance="custom",interval=1,search_interval=1,
    searches=4,candidates=27,events=1,histories=1},"gaia")
local planted=0
entry.surface.create_entity=function() planted=planted+1;return {valid=true,surface=entry.surface} end
prototypes={entity={["ei-gaia-tree-01"]={}}}
local old={id="legacy-regrowth",surface=entry.surface,owner=entry,x=0,y=0,cause="regrowth",
    tick=100,extra={name="ei-gaia-tree-01"},density_checked=100,chunks={},generation=0}
add(root.pending,old)
root.work=nil;work.initialize(root,100)
run(root,100,219,1)
check(root.work.jobs.migration==nil,"legacy pending generation completes")
check(old.pending_class=="E" and (root.pending.E or 0)==0,"legacy E classified and retired once")
check(planted==1 and #root.pending.items==0,"legacy Custom27 request actually grows")

-- Default Lean phase must leave conversion an actual bounded opportunity.
for _,disabled in ipairs{false,true} do
    root,entry=fresh();root.next_tick=16;root.next_search=32
    for i=0,63 do history(root,entry,i,"grass-1",1000000,true) end
    root.work=nil;work.initialize(root,0)
    if disabled then root.config.enabled=false;entry.config.enabled=false;root.enabled_surfaces=0 end
    local bounded=true
    for tick=16,32000,16 do update{tick=tick}
        if root.last_service and root.last_service.histories>root.config.histories then bounded=false end
    end
    check(root.work.jobs.migration==nil,"Lean legacy migration completes; disabled="..tostring(disabled))
    check(bounded,"migration shares configured history ceiling; disabled="..tostring(disabled))
    if disabled then check(not terrain.has_tick_work(32001),"disabled ecology sleeps after finite migration") end
end

-- Bootstrap waiting state changes when the last runnable member completes.
root,entry=fresh()
local disabled_entry=add_surface(root,2,false)
root.work=nil;work.initialize(root,0);work.refresh_reports(root,0)
local id=root.work.jobs.bootstrap.id
work.discovery_visit(root,entry,nil,1);work.cleanup(root,budget(),2)
local registry=scheduler.peek_rebuild_state()
check(registry.active[id].state=="waiting" and registry.public_count==0,
    "last runnable bootstrap member leaves a hidden waiting report")

-- Last-surface removal must finish its report without another tick.
root,entry=fresh();root.surface_registered={[1]=1};root.hazard_surfaces=1
id=root.work.jobs.bootstrap.id
terrain.on_surface_deleted{surface_index=1,tick=100}
registry=scheduler.peek_rebuild_state()
check(root.work.jobs.bootstrap==nil and not registry.active[id],"last-surface bootstrap completes synchronously")
check(not terrain.has_tick_work(100) and registry.public_count==0,"last-surface idle state has no stranded report")

-- Already-complete finite work never enters the public rebuild episode.
root,entry=fresh()
registry=scheduler.peek_rebuild_state()
local episode=registry.episode
work.initialize(root,1,"configuration")
local synchronous
for _,report in pairs(registry.history) do
    if report.operation=="revalidation" then synchronous=report.synchronous end
end
check(synchronous==true and not root.work.jobs.revalidation,"zero-drill revalidation is synchronous")
check(registry.episode==episode,"zero-drill revalidation does not open a public episode")
local source=work.maintenance_begin(root,"already-completed",10,2)
work.maintenance_update(root,source,10,true,2);work.cleanup(root,budget(),3)
local completed
for _,report in pairs(registry.history) do
    if report.operation=="maintenance" then completed=report end
end
check(completed and completed.synchronous and completed.completed==10,
    "completed-before-admission maintenance retains accurate synchronous result")

-- A non-recovery grant owns one of the existing writes, even under blocked R demand.
root,entry=fresh({performance="ultra-low"})
local native_writes=native_tiles(entry.surface,function(x) return x<10000 and "grass-3" or "grass-1" end)
entry.surface.find_entities_filtered=function(filter)
    if filter.area[1][1]<10000 then return {{valid=true,type="assembling-machine",name="assembling-machine-1"}} end
    return {}
end
for i=0,63 do
    local record=history(root,entry,i,"grass-3",0,false)
    record.origin="grass-1";record.path={"grass-1"}
    local observation=work.request_recovery(root,entry,record,40000)
    observation.sample_tick=40000;observation.clean_since=0;observation.pollution=0
    observation.expires=1000000;observation.ready_until=1000000
end
put(root.pending,"scar",{surface=entry.surface,owner=entry,x=100000,y=0,cause="mining",
    tick=40000,offset=0,radius=0,roll=true,extra={trigger="depletion"},chunks={}})
run(root,40000,72000,16)
check(native_writes()==1 and entry.surface.get_tile(100000,0).name=="grass-3",
    "Ultra Low mining performs its exact tile write despite blocked recovery")
check((entry.effects and entry.effects["depletion-scars"] or 0)==1 and #root.pending.items==0,
    "Ultra Low mining completes the descriptor and records the applied effect")

-- Paused queues must not ping-pong borrowed inspection grants forever.
root,entry=fresh({performance="ultra-low"});entry.config.enabled=false
local enabled_entry=add_surface(root,2,true)
enabled_entry.surface.get_pollution=function() return 1000 end
native_writes=native_tiles(enabled_entry.surface,function() return "grass-1" end)
put(root.pending,"paused-E",{surface=entry.surface,owner=entry,x=0,y=0,
    cause="rot",tick=40000,extra={},chunks={}})
put(root.pending,"paused-T",{surface=entry.surface,owner=entry,x=0,y=0,
    cause="mining",tick=40000,offset=0,radius=0,extra={},chunks={}})
create_active(root,enabled_entry.surface,0,0,0)
local observation=work.observe(root,enabled_entry,0,0,"ecology",0)
observation.pollution=1000;observation.dirty_since=0;observation.sample_tick=40000
observation.expires=1000000;observation.ready_until=1000000
run(root,40000,56000,16)
check(native_writes()>0 and (enabled_entry.effects.pollution or 0)>0,
    "paused E/T queues cannot prevent actual soil changes on another surface")
check(#root.pending.items==2,"paused requests remain preserved")

-- Draining is maintained after pressure/cap changes, and retires finite no-action cases.
local function drain_case(label,configure,pollution,cap,completed)
    root,entry=fresh();root.config.active_cap=cap or 1
    for _,key in ipairs{"degradation","tree_stress","tree_regrowth","aging","rot","cliffs","flood","drought"} do entry.config[key]=false end
    entry.config.wildfire="off";configure(entry.config)
    if not entry.config.enabled then add_surface(root,2,true) end
    entry.surface.get_pollution=function() return pollution or 0 end
    local active=create_active(root,entry.surface,0,0,0)
    work.observe(root,entry,0,0,"ecology",0)
    if completed then active.schedule.draining={} end
    run(root,40000,160000,16)
    check(#root.active.items==0,label)
end
drain_case("zero-probability hazard drains",function(c)c.wildfire="contained";c.wildfire_probability=0 end)
drain_case("stable neutral pollution drains soil",function(c)c.degradation=true end,50)
drain_case("disabled surface releases active admission capacity",function(c)c.degradation=true;c.enabled=false end)
drain_case("completed drain retires below increased cap",function()end,0,2,true)

-- Four grants per service must not repeatedly spend the only write in its first R slot.
root,entry=fresh({performance="custom",interval=1,search_interval=1,searches=4,
    candidates=32,histories=128,events=32,writes=1,recovery_reserved=1})
native_writes=native_tiles(entry.surface,function(x) return x<10000 and "grass-3" or "grass-1" end)
for i=0,63 do
    local record=history(root,entry,i,"grass-3",0,false)
    record.origin="grass-1";record.path={"grass-1"}
    local observation=work.request_recovery(root,entry,record,40000)
    observation.sample_tick=40000;observation.clean_since=0;observation.pollution=0
    observation.expires=1000000;observation.ready_until=1000000
end
put(root.pending,"custom-scar",{surface=entry.surface,owner=entry,x=100000,y=0,cause="mining",
    tick=40000,offset=0,radius=0,roll=true,extra={trigger="depletion"},chunks={}})
run(root,40000,40031,1)
check((entry.effects and entry.effects["depletion-scars"] or 0)==1,
    "Custom4 grants preserve a writable mining opportunity under successful recovery demand")
check((root.counters.recovered or 0)>0 and native_writes()<=32,
    "Custom4 mining fairness preserves recovery progress and one write per service")

print(("RESULT %d regression checks; %d failures"):format(checks,failures))
if failures>0 then os.exit(1) end
]===],"ev2-regressions","t",_ENV))()
