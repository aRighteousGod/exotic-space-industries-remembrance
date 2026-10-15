-- Proposed native V2 stress helper. Disposable profile only; not shipping code.
-- Setup and fixture maintenance run outside the timed production updater.
-- World membership is finite: 4096 idle drills + 8 working drills; cache <=4096.
local model={}
local burst_progress=require("__zzz-esir-terrain-qc__/burst-progress")
local trace_options=require("__zzz-esir-terrain-qc__/options")
local ctx
local profile
local planets={
    {name="nauvis",source="grass-1",target="grass-3"},
    {name="gaia",source="ei-gaia-grass-2",target="ei-gaia-grass-1"},
    {name="vulcanus",source="volcanic-smooth-stone",target="volcanic-smooth-stone-warm"},
    {name="gleba",source="midland-cracked-lichen",target="midland-cracked-lichen-dark"},
    {name="fulgora",source="fulgoran-rock",target="fulgoran-sand"},
    {name="aquilo",source="snow-crests",target="snow-flat"},
}
local accelerated={clean_seconds=1,dirty_seconds=1,recovery_seconds=1,
    periodic_mining_seconds=30,periodic_mining_probability=1,
    tree_stress_seconds=30,hazard_seconds=30,wildfire_probability=1}
local function root() return assert(storage.ei.terrain_evolution) end
local function state() return assert(storage.ei.terrain_stress_v2) end
local function numbers(source)
    local result={};for key,value in pairs(source or {}) do if type(value)=="number" then result[key]=value end end
    return result
end
local function add_record(set,record)
    assert(not set.index[record.id],"Duplicate fixture ownership: "..record.id)
    record.ecology_version=2
    set.items[#set.items+1]=record;set.index[record.id]=#set.items
    ctx.work.count_record(root(),record,set.kind)
end
local function attach(entry,record)
    local cell=math.floor(record.x/32)..":"..math.floor(record.y/32)
    local token=entry.chunk_tokens[cell]
    if not token then token={references=0};entry.chunk_tokens[cell]=token end
    token.references=token.references+1;record.chunk_cell=cell;record.chunk_token=token
end
local function override(surface,key,value)
    local ok,message=ctx.terrain.set_override(surface,key,value,game.tick)
    assert(ok,"Fixture override rejected: "..key.." "..serpent.line(message))
end
local function make_patch(surface,x,y,width,height,tile)
    local center={x=x+width/2,y=y+height/2}
    surface.request_to_generate_chunks(center,math.ceil(math.max(width,height)/64)+1)
    surface.force_generate_chunk_requests()
    -- Destructive setup is confined to this disposable fixture's named rectangles.
    for _,entity in ipairs(surface.find_entities_filtered{area={{x-4,y-4},{x+width+4,y+height+4}}}) do
        if entity.valid and entity.type~="character" then entity.destroy() end
    end
    local tiles={}
    for tx=x,x+width-1 do for ty=y,y+height-1 do tiles[#tiles+1]={name=tile,position={tx,ty}} end end
    surface.set_tiles(tiles,false,false,false,true)
end
local function gaia_history_origin(surface,entry)
    local extent=root().anchor_extent+40
    for attempt=0,31 do
        local x,y=10240+attempt*1024,10240
        surface.request_to_generate_chunks({x+64,y+24},3);surface.force_generate_chunk_requests()
        local blocked=entry.protection_saturated==true
        for cx=math.floor((x-16)/32),math.floor((x+144)/32) do
            for cy=math.floor((y-16)/32),math.floor((y+64)/32) do
                if entry.protected[cx..":"..cy] then blocked=true end
                for _,rect in ipairs(entry.overflow_bounds or {}) do
                    if cx>=rect[1] and cy>=rect[2] and cx<=rect[3] and cy<=rect[4] then blocked=true end
                end
            end
        end
        if not blocked and surface.count_entities_filtered{name="ei-artifact-flag",
            area={{x-extent,y-extent},{x+128+extent,y+48+extent}},limit=1}==0 then return x,y end
    end
    error("No unclaimed Gaia history rectangle in 32 finite candidates")
end
local function native_resource_name(drill_name)
    local categories=prototypes.entity[drill_name].resource_categories
    local candidates={}
    for name,p in pairs(prototypes.entity) do
        if p.type=="resource" and not p.infinite_resource and categories[p.resource_category]
            and not p.mineable_properties.required_fluid then candidates[#candidates+1]=name end
    end
    table.sort(candidates)
    for _,preferred in ipairs{"coal","iron-ore","stone"} do
        for _,name in ipairs(candidates) do if name==preferred then return name end end
    end
    return assert(candidates[1],"No finite, fluid-free native quarry resource")
end
local function live_working_count()
    local count=0
    for _,value in ipairs(state().working) do
        local e=value.drill
        if e.valid and e.active and e.status==defines.entity_status.working and e.mining_target
            and e.mining_target.valid and not e.mining_target.prototype.infinite_resource then count=count+1 end
    end
    return count
end
local function registry_check()
    local r=root();local count,seen=0,{}
    for _,entry in pairs(r.surfaces) do
        for slot,id in ipairs(entry.drills or {}) do
            local member=assert(r.work.drills[id],"Missing drill map member")
            assert(not seen[id] and member.owner==entry and member.slot==slot,"Invalid drill owner slot")
            assert(member.entity.valid and r.work.registrations[member.registration]==id,"Invalid native registration mapping")
            seen[id]=true;count=count+1
        end
    end
    local mapped=0;for id in pairs(r.work.drills) do mapped=mapped+1;assert(seen[id],"Unlisted drill map member") end
    return count==mapped and count==r.work.drill_count and count==4096
end
function model.configure(context)
    assert(not ctx,"V2 stress helper configured twice")
    ctx=context
    local original=ctx.terrain.updater
    ctx.terrain.updater=function(event)
        if not profile then return original(event) end
        root().__qc_trace_tick=event.tick
        local timer=helpers.create_profiler();original(event);timer.stop()
        local r=root();local v=r.last_service
        if not v or v.tick~=event.tick then profile.unexpected_dispatch=profile.unexpected_dispatch+1;return end
        log({"","TERRAIN_ECOLOGY_PROFILE lane="..profile.name.." tick="..event.tick.." elapsed=",timer})
        profile.services=profile.services+1
        local cfg=r.config
        profile.caps=profile.caps and v.candidates<=cfg.candidates and v.writes<=cfg.writes
            and v.searches<=cfg.searches and v.events<=cfg.events and v.active_samples<=cfg.active_chunks
            and v.histories<=cfg.histories and r.work.drill_count<=4096
            and r.work.observation_count<=math.min(64,math.max(1,math.floor(1024/cfg.interval)))
            and #r.pending.items<=cfg.pending_cap and #r.history.items<=cfg.tile_history_cap
            and #r.trees.items<=cfg.tree_history_cap
            and (r.mine_tick~=event.tick or (r.mine_queries or 0)<=cfg.mining_queries)
        if v.search_allowance>0 then
            profile.caps=profile.caps and (not profile.last_search or event.tick-profile.last_search>=cfg.search_interval)
            profile.last_search=event.tick
        end
        for _,key in ipairs{"candidates","writes","searches","events","histories","active_samples"} do
            profile.maxima[key]=math.max(profile.maxima[key] or 0,v[key] or 0)
        end
        profile.maxima.observations=math.max(profile.maxima.observations or 0,r.work.observation_count)
        profile.maxima.pending=math.max(profile.maxima.pending or 0,#r.pending.items)
        profile.min_history=math.min(profile.min_history,#r.history.items)
        profile.min_tree_history=math.min(profile.min_tree_history,#r.trees.items)
        profile.min_drills=math.min(profile.min_drills,r.work.drill_count)
    end
    -- Fixed-cost instrumentation is included in updater timing; no roster walks.
    local original_drills=ctx.work.service_drills
    ctx.work.service_drills=function(r,b,tick,rate,scar)
        local before=b.used_candidates
        local function counted_scar(...)
            if profile then profile.working_attempts=profile.working_attempts+1 end
            local accepted=scar(...)
            if profile and accepted then profile.working_accepted=profile.working_accepted+1 end
            return accepted
        end
        original_drills(r,b,tick,rate,profile and counted_scar or scar)
        if profile then
            local used=b.used_candidates-before
            profile.caps=profile.caps and used<=math.min(4,r.config.histories)
            profile.maxima.drill_inspections=math.max(profile.maxima.drill_inspections or 0,used)
        end
    end
end
function model.begin()
    assert(script.active_mods["zzz-esir-terrain-qc"],"Disposable terrain helper required")
    assert(not storage.ei.terrain_stress_v2,"Use a fresh native fixture save")
    for _,spec in ipairs(planets) do if not game.planets[spec.name].surface then game.planets[spec.name].create_surface() end end
    ctx.terrain.initialize(game.tick)
    local r=root();assert(r.config.performance=="lean" and r.config.interval==16 and r.config.search_interval==32,"Default Lean required")
    for _,row in ipairs(ctx.config.schema) do
        assert(settings.global[row.setting_name].value==row.default,"Fresh default settings required: "..row.setting_name)
    end
    assert(#r.history.items==0 and #r.trees.items==0,"Start before ecology creates ownership")
    assert(r.work.drill_count==0,"Fresh fixture must not contain pre-registered eligible drills")
    local f={planets={},working={},cohort={},owned_tiles={},tree_serial=0,idle_created=0,metadata_chunks=0,
        begun=game.tick,results={},native_query_fixture="real entity queries; synthetic chunk metadata is labelled separately"}
    storage.ei.terrain_stress_v2=f
    for i,spec in ipairs(planets) do
        local s=game.planets[spec.name].surface
        f.planets[i]={surface=s,spec=spec,prior_active=ctx.terrain.get_overrides(s).active}
        assert(ctx.terrain.resolve_config(s).enabled,"All six planets must be enabled")
        override(s,"active",false)
    end
    for _,kind in ipairs{"history","trees","active","pending"} do r[kind].kind=kind end
    return {setup_frozen=true,performance="lean",seasonal_daylight="kept at loaded default; Fulgora independent"}
end
function model.prepare_planet(index)
    local f=state();local p=f.planets[index];local s=p.surface;local spec=p.spec;local entry=root().surfaces[s.index]
    local x,y=10240,10240
    if spec.name=="gaia" then x,y=gaia_history_origin(s,entry) end
    p.x=x;p.y=y;p.field_x=x;p.field_y=y+256
    assert(root().transitions[spec.source]==spec.target,"Unexpected native transition for "..spec.name)
    make_patch(s,x-16,y-16,160,80,spec.target)
    make_patch(s,p.field_x-8,p.field_y-8,272,192,spec.source)
    local quota=math.floor(32768/6)+(index<=32768%6 and 1 or 0)
    p.history_seeded=quota
    for n=0,quota-1 do
        local tx,ty=x+n%128,y+math.floor(n/128)
        local record={id=s.index..":"..tx..":"..ty,surface=s,owner=entry,x=tx,y=ty,
            origin=spec.source,expected=spec.target,path={spec.source},cause="pollution",next_tick=game.tick+10000000}
        attach(entry,record);add_record(root().history,record)
        f.owned_tiles[#f.owned_tiles+1]=record
        -- Eight records in each of eight chunks; the production observation limit is eight references/chunk.
        if index==1 and ((ty-y)==0 or (ty-y)==32) and (tx-x)%32<8 then
            record.fixture_due_cohort=true;f.cohort[#f.cohort+1]=record
        end
    end
    if index==1 then
        f.forest={surface=s,x=x+512,y=y,width=128,height=256}
        make_patch(s,f.forest.x-16,f.forest.y-16,160,288,"grass-1")
        f.working_origin={x=x+1024,y=y}
        make_patch(s,x+1000,y-32,320,80,"grass-1")
    end
    return {planet=spec.name,histories=quota,source=spec.source,target=spec.target}
end
function model.seed_trees(count)
    local f=state();local r=root();local forest=f.forest;local entry=r.surfaces[forest.surface.index]
    local created=0
    while created<count and #r.trees.items<4096 do
        local n=f.tree_serial;assert(n<8192,"Finite forest replacement reserve exhausted")
        f.tree_serial=n+1
        local p={x=forest.x+(n%64)*2+.5,y=forest.y+math.floor(n/64)*2+.5}
        local tree=assert(forest.surface.create_entity{name="tree-01",position=p,force="neutral"},"Native forest tree creation failed")
        local gray=tree.tree_gray_stage_index
        assert(gray<tree.tree_gray_stage_index_max,"Tree has no native stress stage")
        tree.tree_gray_stage_index=gray+1
        add_record(r.trees,{id=forest.surface.index..":"..tree.position.x..":"..tree.position.y,
            surface=forest.surface,owner=entry,entity=tree,gray=gray,stage=tree.tree_stage_index,
            expected=tree.tree_gray_stage_index,next_tick=game.tick+10000000})
        created=created+1
    end
    return #r.trees.items==4096
end
function model.seed_working()
    local f=state();local s=f.planets[1].surface;local resource_name=native_resource_name("ei-burner-quarry")
    for i=0,7 do
        local p={x=f.working_origin.x+i*32,y=f.working_origin.y}
        local ore=assert(s.create_entity{name=resource_name,position={p.x+10.5,p.y+.5},amount=100000})
        local drill=assert(s.create_entity{name="ei-burner-quarry",position=p,force="player",raise_built=true})
        local chest=assert(s.create_entity{name="iron-chest",position=drill.drop_position,force="player"})
        drill.destructible=false;chest.destructible=false
        assert(drill.burner.inventory.insert{name="coal",count=50}>0)
        assert(root().work.drills[drill.unit_number],"Working member must be cached before idle capacity is filled")
        f.working[#f.working+1]={drill=drill,chest=chest,resource=ore}
    end
    f.resource_name=resource_name
    return {working_native_drills=8,resource=resource_name}
end
function model.seed_idle(count)
    local f=state();local cap_before=root().work.coverage_limited
    local last=math.min(4096,f.idle_created+count)
    for n=f.idle_created,last-1 do
        local index=n%6+1;local p=f.planets[index];local q=math.floor(n/6)
        local drill=assert(p.surface.create_entity{name=ctx.policy.drills[n%4+1],
            position={p.field_x+(q%32)*8+4,p.field_y+math.floor(q/32)*8+4},force="player",raise_built=true})
        drill.active=false;drill.destructible=false
    end
    f.idle_created=last
    if last==4096 then
        assert(root().work.drill_count==4096 and root().work.coverage_limited>cap_before,"Native cache capacity was not exercised")
        assert(registry_check(),"Native registry identity mismatch")
    end
    return last==4096
end
function model.chunks(first,count)
    local f=state()
    for n=first,first+count-1 do
        local p=f.planets[n%6+1];local q=math.floor(n/6)
        p.surface.set_chunk_generated_status({x=5000+q%200,y=5000+math.floor(q/200)},defines.chunk_generated_status.entities)
    end
    f.metadata_chunks=f.metadata_chunks+count
    return f.metadata_chunks
end
function model.seed_active()
    local f=state();local r=root();assert(#r.active.items==0,"Seed active population while setup is frozen")
    for n=0,2047 do
        local p=f.planets[n%6+1];local q=math.floor(n/6);local x,y=5000+q%200,5000+math.floor(q/200)
        if n<6 then x=math.floor(p.x/32);y=math.floor(p.y/32)
        elseif n<15 then
            p=f.planets[1];local forest=f.forest;local cell=n-6
            x=math.floor(forest.x/32)+cell%3;y=math.floor(forest.y/32)+math.floor(cell/3)
        end
        local entry=r.surfaces[p.surface.index]
        local record={id=p.surface.index..":"..x..":"..y,surface=p.surface,owner=entry,x=x,y=y,
            resident_since=game.tick,next_soil=game.tick,next_tree=game.tick,next_hazard=game.tick}
        local cell=x..":"..y;local token=entry.chunk_tokens[cell]
        if not token then token={references=0};entry.chunk_tokens[cell]=token end
        token.references=token.references+1;record.chunk_cell=cell;record.chunk_token=token
        add_record(r.active,record)
    end
    -- Real forest cohort is admitted explicitly; giant metadata populations cannot hide this load.
    local forest=f.forest;local entry=r.surfaces[forest.surface.index]
    for dx=0,2 do for dy=0,2 do
        ctx.work.observe(r,entry,math.floor(forest.x/32)+dx,math.floor(forest.y/32)+dy,"ecology",game.tick)
    end end
    assert(#r.history.items==32768 and #r.trees.items==4096 and #r.active.items==2048 and #f.cohort==64,"Incomplete native population")
    return {tile_histories=32768,tree_histories=4096,active=2048,cohort=64,world_drills=4104,cached_drills=4096}
end
function model.maintenance()
    local f=state()
    for _,value in ipairs(f.working) do
        assert(value.drill.valid and value.chest.valid and value.resource.valid,"Fixed working asset was lost")
        value.drill.burner.inventory.insert{name="coal",count=20}
        local ash=value.drill.burner.burnt_result_inventory
        if ash and ash.valid then ash.clear() end
        value.chest.get_inventory(defines.inventory.chest).clear()
    end
    if f.forest then
        for dx=0,2 do for dy=0,2 do
            f.forest.surface.pollute({f.forest.x+dx*32+16,f.forest.y+dy*32+16},10000)
        end end
    end
    if f.exercise then
        -- Eight local native pollution cells are held clean; no whole-surface sweep.
        for dx=0,3 do for dy=0,1 do
            local p={f.planets[1].x+dx*32+16,f.planets[1].y+dy*32+16}
            local amount=f.planets[1].surface.get_pollution(p)
            if amount>0 then f.planets[1].surface.pollute(p,-amount) end
        end end
    end
    return live_working_count()
end
function model.working_status()
    local details={}
    for _,value in ipairs(state().working) do
        local e=value.drill
        details[#details+1]={status=e.valid and e.status or "invalid",active=e.valid and e.active,
            target=e.valid and e.mining_target and e.mining_target.valid and e.mining_target.name,
            fuel=e.valid and e.burner.inventory.get_item_count(),
            ash=e.valid and e.burner.burnt_result_inventory and e.burner.burnt_result_inventory.get_item_count(),
            remaining=e.valid and e.burner.remaining_burning_fuel,
            resource=value.resource.valid and value.resource.amount,
            output=value.chest.valid and value.chest.get_inventory(defines.inventory.chest).get_item_count()}
    end
    return {count=live_working_count(),details=details}
end
function model.resume_setup()
    for _,p in ipairs(state().planets) do override(p.surface,"active",p.prior_active) end
    root().next_tick=game.tick+root().config.interval
end
function model.freeze()
    assert(not profile,"End profiling before fixture setup")
    root().next_tick=game.tick+4096
end
function model.start(name)
    local r=root();assert(not profile and registry_check(),"Invalid stress start")
    assert(r.config.performance=="lean" and r.config.interval==16 and r.config.search_interval==32)
    assert(#r.history.items==32768 and #r.trees.items==4096,"Full histories required at each profile start")
    local f=state();local settings={}
    for _,p in ipairs(f.planets) do
        local c=ctx.terrain.resolve_config(p.surface)
        assert(c.enabled and (p.spec.name=="fulgora" or c.seasonal_daylight),"Ecology/daylight unexpectedly disabled")
        local snapshot={intensity_multiplier=c.intensity_multiplier}
        for _,row in ipairs(ctx.config.schema) do snapshot[row.key]=c[row.key] end
        settings[p.spec.name]=snapshot
    end
    local count=live_working_count();assert(count==8,"All eight native quarries must be working at profile start")
    profile={name=name,start=game.tick,services=0,caps=true,maxima={},unexpected_dispatch=0,working_attempts=0,working_accepted=0,
        min_history=#r.history.items,min_tree_history=#r.trees.items,min_drills=r.work.drill_count,
        before=numbers(r.counters),metadata_chunks=f.metadata_chunks,settings=settings,
        initial={history=#r.history.items,trees=#r.trees.items,active=#r.active.items,pending=#r.pending.items,occupancy_names=#r.natural_exclusions,
            cached_drills=r.work.drill_count,world_idle_drills=f.idle_created,world_working_drills=#f.working}}
    root().next_tick=game.tick+root().config.interval
    if name=="v2_full_history_due_burst" then
        root().__qc_trace_from=game.tick+(trace_options.trace_offset or 0)
        root().__qc_trace_until=root().__qc_trace_from+5000
    end
    return {name=name,at=game.tick,metadata_chunks=f.metadata_chunks,working=count}
end
function model.exercise_setup()
    assert(not profile);model.freeze();local f=state();f.exercise=true
    for key,value in pairs(accelerated) do override(f.planets[1].surface,key,value) end
    local r=root();local entry=r.surfaces[f.planets[1].surface.index]
    for _,record in ipairs(f.cohort) do
        assert(r.history.items[r.history.index[record.id]]==record,"Cohort ownership changed before exercise")
        record.next_tick=game.tick
        assert(ctx.work.request_recovery(r,entry,record,game.tick),"No observation space for finite due cohort")
    end
    f.burst_cursor=0;f.burst_rejected=0;f.burst_records=burst_progress.new()
    model.maintenance()
    return {accelerations=accelerated,seasonal_daylight="unchanged",due_histories=#f.cohort}
end
function model.burst_step()
    local r=root();local f=state();assert(not profile,"Burst seeding is excluded from timing")
    if #r.pending.items<r.config.pending_cap then
        for _=1,r.config.admissions do
            local n=f.burst_cursor;assert(n<4096,"Finite native burst locations exhausted")
            f.burst_cursor=n+1
            local p=f.planets[n%6+1];local q=math.floor(n/6)
            local position={x=p.field_x+(q%32)*8+4,y=p.field_y+math.floor(q/32)*8+4}
            if ctx.terrain.enqueue_scar(p.surface,position,"thermal",game.tick) then
                local record=r.pending.items[#r.pending.items]
                assert(record.surface==p.surface and record.x==math.floor(position.x)
                    and record.y==math.floor(position.y),"Unexpected appended burst descriptor")
                burst_progress.capture(f.burst_records,record)
            else f.burst_rejected=f.burst_rejected+1 end
            if #r.pending.items==r.config.pending_cap then break end
        end
    end
    if #r.pending.items==r.config.pending_cap then
        local count=#r.pending.items;local saturated=r.counters.saturated or 0;local p=f.planets[1]
        assert(not ctx.terrain.enqueue_scar(p.surface,{x=p.x+2048,y=p.y+2048},"thermal",game.tick),"Full pending queue admitted new work")
        assert(#r.pending.items==count and (r.counters.saturated or 0)>saturated,"Pending cap was not visible")
        f.burst_initial=count;return true
    end
    return false
end
function model.stop()
    local p=assert(profile);profile=nil;local r=root();local f=state()
    local deltas={};for key,value in pairs(r.counters) do if type(value)=="number" then deltas[key]=value-(p.before[key] or 0) end end
    local cohort_restored=0
    for _,record in ipairs(f.cohort) do
        if not r.history.index[record.id] and record.surface.get_tile(record.x,record.y).name==record.origin then cohort_restored=cohort_restored+1 end
    end
    local retained,missing=0,0
    for _,record in ipairs(f.owned_tiles) do
        if not f.exercise or not record.fixture_due_cohort then
            if r.history.items[r.history.index[record.id] or 0]==record then retained=retained+1 else missing=missing+1 end
        end
    end
    local result={caps=p.caps,services=p.services,ticks=game.tick-p.start,maxima=p.maxima,
        unexpected_dispatch=p.unexpected_dispatch,initial=p.initial,settings=p.settings,
        metadata_only_chunk_records=p.metadata_chunks,real_surface_count=#f.planets,
        min_history=p.min_history,min_tree_history=p.min_tree_history,min_cached_drills=p.min_drills,
        final={history=#r.history.items,trees=#r.trees.items,pending=#r.pending.items,observations=r.work.observation_count,
            cached_drills=r.work.drill_count,working_drills=live_working_count()},
        deltas=deltas,cohort_restored=cohort_restored,retained_owned_tiles=retained,unexpected_missing_ownership=missing,
        working_attempts=p.working_attempts,working_accepted=p.working_accepted,registry_consistent=registry_check(),
        bootstrap=ctx.work.jobs(r),accelerations=f.exercise and accelerated or false,
        workload_notes={"32,768 tile histories are seeded V2 ownership on real six-planet tiles",
            "4096 initial stressed tree histories use a native Nauvis forest; later native deaths may retire them",
            "10k/100k are metadata-only native chunk records, not generated inhabited terrain",
            "fuel/output maintenance and 9 forest pollution injections of 10000 every 600 ticks occur outside profiling",
            "working drills and output chests are indestructible fixture assets; ecology settings are unchanged in default lanes"}}
    result.pass=result.caps and result.services>0 and result.unexpected_dispatch==0 and result.registry_consistent
        and result.min_cached_drills==4096 and result.final.working_drills==8 and missing==0
    if f.exercise then
        result.burst_progress=burst_progress.summarize(f.burst_records,r.pending)
        result.pass=result.pass and cohort_restored==64 and (deltas.recovered or 0)>=64
            and result.working_attempts>0 and result.burst_progress.pass
            and (deltas.wildfire_attempts or 0)>0
        local effects=root().surfaces[f.planets[1].surface.index].effects or {}
        result.working_scar_tiles=effects["working-scars"] or 0
        -- At a full history cap an accepted working request may be unable to write.
        -- Native working eligibility itself is separately proven by the focused fixture.
    end
    f.results[p.name]=result
    return result
end
function model.summary()
    local f=state();local count,pass=0,true
    for _,result in pairs(f.results) do count=count+1;pass=pass and result.pass end
    return {all_pass=pass and count==3,count=count,cases=f.results,setup={world_idle_drills=f.idle_created,
        world_working_drills=#f.working,working_resource=f.resource_name,tree_entities_created=f.tree_serial,
        metadata_only_chunks=f.metadata_chunks,native_surfaces=#f.planets,elapsed_ticks=game.tick-f.begun}}
end
return model
