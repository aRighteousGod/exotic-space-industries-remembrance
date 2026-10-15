-- Actual production scheduler/state machines with mocked native boundaries.
-- Lua 5.4 screening is supplemental to Factorio 2.0.77 native fixtures.
local pack="exotic-space-industries-remembrance/"
storage={ei={}}
local function loadmod(name) local m=dofile(pack..name..".lua");package.loaded[name]=m;return m end
if not package.loaded["lib/terrain-index"] then loadmod("lib/terrain-index") end
local config=loadmod("lib/terrain-evolution-config")
local policy=loadmod("lib/terrain-policy")
local scheduler=loadmod("lib/runtime-scheduler")
package.loaded["lib/lib"]={get_valid_entity=function(e) return e and e.valid and e end,get_entity_unit_number=function(e) return e and e.valid and e.unit_number end}
package.loaded["scripts/control/terrain-calendar"]={service=function() end,snapshot=function() return {phase=0} end,phase=function() return 0 end}
package.loaded["lib/firefighting-config"]={};package.loaded["lib/spawner-presets"]={}
local work=loadmod("scripts/control/terrain-ecology-work")
local terrain=loadmod("scripts/control/terrain-evolution")
local checks=0
local function check(ok,label) checks=checks+1;assert(ok,label) end
local function up(fn,name,replacement)
    for i=1,100 do local key,value=debug.getupvalue(fn,i);if not key then break end
        if key==name then if replacement~=nil then debug.setupvalue(fn,i,replacement) end;return value end end
    error("Missing production upvalue: "..name)
end
local function set() return {items={},index={},cursor=1} end
local function add(s,r) s.items[#s.items+1]=r;s.index[r.id]=#s.items end
local function fresh(options,planet,legacy)
    storage={ei={}}
    local cfg=config.resolve(options or {performance="lean"},{});cfg.seasonal_ecology=false
    local root={config=cfg,surfaces={},surface_order={1},surface_cursor=1,active=set(),history=set(),trees=set(),pending=set(),fires=set(),counters={},pass=0,next_tick=0,enabled_surfaces=1,transitions=policy.transitions}
    local tile={valid=true,name=planet=="gaia" and "ei-gaia-grass-1" or "grass-1",prototype={is_foundation=false},collides_with=function() return false end}
    local surface={valid=true,index=1,is_chunk_generated=function() return true end,get_tile=function() return tile end,
        find_entities_filtered=function() return {} end,get_pollution=function() return 0 end,pollutant_type={name="pollution"},can_place_entity=function() return true end}
    surface.create_entity=function() return {valid=true,surface=surface} end
    local entry={surface=surface,config=config.resolve_surface(cfg,planet or "nauvis"),planet=planet or "nauvis",chunk_tokens={},protected={},classified={["0:0"]=true},hazard_epoch=1}
    root.surfaces[1]=entry;storage.ei.terrain_evolution=root
    if legacy then for _,name in ipairs{"history","trees","pending","active"} do add(root[name],{id=name,climate={sample_tick=0}}) end end
    work.initialize(root,0);return root,entry
end
local function budget() return {candidates=32,writes=4,searches=1,samples=2,histories=4,events=4,used_candidates=0,used_searches=0,used_writes=0,used_events=0,batches={},positions={}} end
local update=terrain.updater
local service=up(update,"service_class")
local entity_loop=up(service,"service_entity_events")
local entity_event=up(entity_loop,"entity_event")
local saved={}
for _,name in ipairs{"recover_tiles","recover_trees","service_events","discover","commit"} do saved[name]=up(update,name,function() end) end
local root=fresh();local order={}
up(update,"service_class",function(_,b,lane) order[#order+1]=lane;b.searches=0;b.used_searches=b.used_searches+1 end)
for tick=0,352,32 do update{tick=tick} end
check(table.concat(order,",")=="R,T,R,E,R,S,R,T,R,G,R,H","weighted twelve-grant order")
check(root.last_service.searches==1,"Lean search ceiling")
local entry;root,entry=fresh({performance="custom",interval=1,search_interval=1,searches=4,candidates=27},"gaia")
local planted=0;entry.surface.create_entity=function() planted=planted+1;return {valid=true,surface=entry.surface} end
terrain.configure{gaia={resolve_gaia_tree_name=function() return "ei-gaia-tree-01" end},vat={is_terrain_claimed=function() return false end}}
prototypes={entity={["ei-gaia-tree-01"]={}}}
local record={id="gaia-seed",surface=entry.surface,owner=entry,x=0,y=0,cause="regrowth",extra={name="ei-gaia-tree-01"},density_checked=100,chunks={},ecology_version=2}
add(root.pending,record)
up(update,"service_class",function(r,b,lane,tick)
    if lane=="E" then service(r,b,lane,tick)
    elseif b.candidates>0 then b.candidates=b.candidates-1;b.used_candidates=b.used_candidates+1;b.searches=0;b.used_searches=b.used_searches+1 end
end)
update{tick=100}
check(root.work.deferred_lane=="E" and root.work.deferred_entity==record and planted==0,"Custom27 preserves atomic request")
update{tick=101}
check(planted==1 and not root.pending.index[record.id],"Custom27 succeeds on first next grant")
check(root.last_service.candidates<=27,"Custom27 candidate ceiling")
root,entry=fresh({performance="custom",candidates=27},"gaia")
record={id="zero-seed",surface=entry.surface,owner=entry,x=0,y=0,cause="regrowth",extra={},density_checked=100,chunks={}}
local b=budget();b.candidates=0;entity_event(root,b,record,100)
check(b.deferred_entity==record,"zero candidates preserves Gaia grant")
up(update,"service_class",service);for name,fn in pairs(saved) do up(update,name,fn) end
local sample=up(update,"sample")
local create_active=up(up(update,"discover"),"active")
root,entry=fresh()
for x=0,63 do create_active(root,entry.surface,x,0,0);work.observe(root,entry,x,0,"ecology",0) end
local max_gap,last=0,{}
for tick=16,80000,16 do
    work.sample_observation(root,budget(),tick,sample)
    for slot,r in pairs(root.work.observations) do if r.sample_tick==tick then if last[slot] then max_gap=math.max(max_gap,tick-last[slot]) end;last[slot]=tick end end
end
check(max_gap<=1024,"Lean64 cohort sample gap")
check(work.ready(root,"G",80000)~=nil,"mature cohort remains executable")
root.config.interval=256;work.initialize(root,80001)
check(root.work.observation_count==4,"Custom256 cohort cap")
root,entry=fresh();local observation=work.observe(root,entry,0,0,"recovery",0)
work.sample_observation(root,budget(),1600,sample)
check(observation.expires==1600+entry.config.clean_seconds*60+1200,"lease starts on first sample")
work.sample_observation(root,budget(),3001,sample);check(observation.clean_since==3001,"stale gap breaks dwell")
entry.surface.get_pollution=function() return 1000 end
for tick=3017,42000,16 do work.sample_observation(root,budget(),tick,sample) end
check(work.ready(root,"R",42000)==nil,"dirty recovery never ready")
root,entry=fresh(nil,nil,true);local job=root.work.jobs.migration;local id=job.id
add(root.history,{id="new",ecology_version=2})
local attached=0
local function next_record(s,cursor) if #s.items==0 then return end;s[cursor]=(s[cursor] or 0)%#s.items+1;return s.items[s[cursor]] end
root.pending.items[1].surface=entry.surface;root.pending.items[1].owner=entry;root.pending.items[1].generation=0
for tick=1,8 do work.migrate(root,budget(),tick,next_record,function(r) r.chunks={};attached=attached+1 end) end
local state=scheduler.peek_rebuild_state()
check(not root.work.jobs.migration and not state.active[id],"migration completes")
local completed;for _,r in pairs(state.history) do if r.id==id then completed=r end end
check(completed and completed.completed==8 and completed.total==8 and attached==1,"migration excludes new admissions")
local bootstrap=root.work.jobs.bootstrap;id=bootstrap.id
entry.bootstrap.closed=true;entry.drill_discovery={bootstrap=true,x=0,y=0};bootstrap.remaining=0;bootstrap.pending=1;root.work.bootstrap_pending=1;entry.config.enabled=false
work.refresh_reports(root,10);work.cleanup(root,budget(),11)
check(state.active[id].state=="waiting" and state.public_count==0,"disabled closed bootstrap pending stays hidden")
check(state.active[id].total==nil,"bootstrap total unknown")
work.initialize(root,12,"load-adoption");check(root.work.jobs.bootstrap.id==id,"load preserves generation ID")
entry.config.enabled=true;work.refresh_reports(root,13);work.discovery_query(root,budget(),14,function() return {} end)
check(not root.work.jobs.bootstrap and not state.active[id],"bootstrap retires admitted descriptor")
local next_id=state.next_id;scheduler.report_rebuild("terrain-evolution","bootstrap","global",id,{state="running"},15)
check(state.next_id==next_id and not state.active[id],"stale publisher cannot reopen")
root,entry=fresh();local old=create_active(root,entry.surface,0,0,0)
observation=work.observe(root,entry,0,0,"ecology",0);work.sample_observation(root,budget(),16,sample)
observation.schedule.next_soil=1000000;local old_schedule=observation.schedule
up(update,"remove")(root.active,old.id);create_active(root,entry.surface,0,0,40000)
work.sample_observation(root,budget(),40000,sample)
local renewed=work.observe(root,entry,0,0,"ecology",40001)
check(renewed.schedule==old_schedule and renewed.schedule.next_soil==1000000,"cooldown survives active replacement and cohort renewal")
print("PASS "..checks.." V2 scheduler/state checks")

root,entry=fresh();local registry=scheduler.peek_rebuild_state();local generation=root.work.jobs.bootstrap
work.cleanup(root,budget(),1) -- queued -> running is always published.
local revision=registry.revision;local payload=generation.report_details
for tick=2,60 do work.cleanup(root,budget(),tick) end
check(registry.revision==revision and generation.report_details==payload,"identical report boundaries reuse payload without publishing")
work.cleanup(root,budget(),61)
check(registry.revision==revision+1,"unchanged reports retain sixty-tick ETA heartbeat")
generation.completed=generation.completed+1;work.cleanup(root,budget(),62)
check(registry.active[generation.id].completed==generation.completed,"progress publishes before heartbeat")
work.cleanup(root,budget(),121)
check(registry.active[generation.id].samples[#registry.active[generation.id].samples].tick==121,"progress publication does not postpone due ETA sample")
local old_id=generation.id;storage.ei.runtime_scheduler.rebuilds=nil
work.cleanup(root,budget(),122);registry=scheduler.peek_rebuild_state()
check(registry and registry.active[generation.id],"missing registry can adopt cached generation")
scheduler.finish_rebuild(generation.id,"superseded",123);revision=registry.next_id
work.cleanup(root,budget(),124)
check(registry.next_id==revision and not registry.active[generation.id],"cached retired publisher cannot reopen generation")
print("PASS 6 report publication/deduplication checks")
