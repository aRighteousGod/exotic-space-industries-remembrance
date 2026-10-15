-- Elapsed native fixture: autonomous ignition uses the public shipping updater.
-- Direct descriptors separately isolate flame mechanics from admission/scheduling.
local model={}
local function count(root) return root.counters.ignitions or 0 end
local function check(state,name,pass,detail)
    state.cases[name]={pass=pass==true,detail=detail}
end
-- Fixture-only reset: V2 admission counters and observation schedules belong
-- to the discarded records and must not leak between autonomous phases.
local function clear_ecology(root)
    for _,kind in ipairs{"active","pending","history","trees"} do
        root[kind]={items={},index={},cursor=1,kind=kind}
    end
    local work=root.work
    work.observations={};work.observation_keys={};work.observation_cursor=0
    work.observation_count=0;work.recovery_observations=0;work.ready_cursors={}
    work.deferred_entity=nil;work.deferred_lane=nil;work.query_cursor=0
    for _,entry in pairs(root.surfaces) do entry.chunk_tokens={};entry.counts={} end
    root.last_service=nil
end
local function reset(terrain,state,mode,dense,degradation,tick)
    local s=game.surfaces.nauvis
    local x=4096+state.phase*256
    s.request_to_generate_chunks({x+32,16},2);s.force_generate_chunk_requests()
    s.destroy_decoratives{area={{x-32,-32},{x+96,64}}}
    for _,entity in ipairs(s.find_entities_filtered{area={{x-32,-32},{x+96,64}}}) do entity.destroy() end
    local tiles={}
    for tx=x-32,x+95 do for ty=-32,63 do tiles[#tiles+1]={name="grass-1",position={tx,ty}} end end
    s.set_tiles(tiles,false,false,false,false)
    local root=storage.ei.terrain_evolution
    for _,r in ipairs(root.fires.items) do if r.entity.valid then r.entity.destroy() end end
    root.fires={items={},index={},cursor=1}
    clear_ecology(root)
    root.surface_order={} -- Isolate fixture chunks from incremental world discovery.
    root.next_fire=0;root.next_search=tick;root.next_tick=tick
    for _,pair in ipairs{
        {"wildfire",mode},{"wildfire_probability",1},{"hazard_seconds",30},
        {"degradation",degradation},{"dirty_seconds",1},{"soil_seconds",1},{"recovery",false},
        {"tree_stress",false},{"tree_regrowth",false},{"aging",false},{"rot",false},
        {"cliffs",false},{"flood",false},{"drought",false},{"seasonal_daylight",false},
        {"seasonal_ecology",false},{"intensity","custom"},{"custom_rate_multiplier",4},
        {"protection_buffer",0},
    } do assert(terrain.set_override(s,pair[1],pair[2],tick)) end
    state.trees={}
    local stride=dense and 2 or 6
    for tx=x+1,x+63,stride do for ty=1,31,stride do
        local tree=s.create_entity{name="tree-01",position={tx+.5,ty+.5},force="neutral"}
        if tree then state.trees[#state.trees+1]={entity=tree,health=tree.health,stage=tree.tree_stage_index,gray=tree.tree_gray_stage_index} end
    end end
    for cx=x/32,x/32+1 do terrain._qc.active(root,s,cx,0,tick);s.pollute({cx*32+16,16},10000) end
    state.surface=s;state.x=x;state.start=tick;state.before=count(root);state.mode=mode
    state.degradation=degradation;state.dense=dense;state.observed_fire=false;state.observed_damage=false
    local effects=root.surfaces[s.index].effects
    state.before_soil=effects and effects.pollution or 0
    state.first_fire=nil;state.native_children=false;state.owned={};state.max_searches=0
    state.next_pollution=tick;state.pollution_low=nil;state.pollution_high=nil
    state.before_counters={}
    for _,name in ipairs{"wildfire_attempts","wildfire_candidates","wildfire_no_fuel",
        "wildfire_protected","wildfire_creation_failed","samples"} do
        state.before_counters[name]=root.counters[name] or 0
    end
    return root
end
-- Fixture exposure is sustained; diffusion/tree absorption must not silently
-- turn the autonomous wildfire test into a clean-chunk negative test.
local function maintain_pollution(state,tick)
    if tick<state.next_pollution then return end
    state.next_pollution=tick+60
    for cx=state.x/32,state.x/32+1 do
        local p={cx*32+16,16};local amount=state.surface.get_pollution(p)
        state.pollution_low=math.min(state.pollution_low or amount,amount)
        state.pollution_high=math.max(state.pollution_high or amount,amount)
        if amount<10000 then state.surface.pollute(p,10000-amount) end
    end
end
local function diagnostics(state,root,tick)
    local result={elapsed=tick-state.start,minimum_pollution_before_refill=state.pollution_low,
        maximum_pollution_before_refill=state.pollution_high,observations=root.work.observation_count,
        first_fire_elapsed=state.first_fire and state.first_fire.born-state.start,
        post_ignition_ticks=state.first_fire and tick-state.first_fire.born,
        pending=#root.pending.items,active=#root.active.items}
    local first=state.first_fire
    if first then
        result.pollution_at_first_fire=first.pollution
        result.first_target_health=first.target_health
        result.first_target_fixture_health=first.fixture_health
        result.first_target_stage=first.target_stage
        result.first_target_gray=first.target_gray
        if first.target then
            result.first_target_valid=first.target.valid
            if first.target.valid then
                result.last_target_health=first.target.health
                result.last_target_stage=first.target.tree_stage_index
                result.last_target_gray=first.target.tree_gray_stage_index
            end
        end
    end
    for name,before in pairs(state.before_counters) do result[name]=(root.counters[name] or 0)-before end
    return result
end
local function observe(state,root,tick)
    local fires=state.surface.find_entities_filtered{type="fire",area={{state.x-32,-32},{state.x+96,64}}}
    if #fires>0 then state.observed_fire=true end
    for _,r in ipairs(root.fires.items) do
        if r.entity.valid then
            local known=false
            for _,entity in ipairs(state.owned) do if entity==r.entity then known=true;break end end
            if not known then state.owned[#state.owned+1]=r.entity end
            if not state.first_fire then
                local position=r.entity.position
                local first={entity=r.entity,born=r.started or r.expires-660,
                    pollution=state.surface.get_pollution(position)}
                for _,seeded in ipairs(state.trees) do
                    local tree=seeded.entity
                    if tree.valid and math.abs(tree.position.x-position.x)<0.1 and math.abs(tree.position.y-position.y)<0.1 then
                        first.target=tree;first.target_health=tree.health;first.fixture_health=seeded.health
                        first.target_stage=tree.tree_stage_index;first.target_gray=tree.tree_gray_stage_index
                        break
                    end
                end
                state.first_fire=first
            end
        end
    end
    for _,fire in ipairs(fires) do
        local known=false
        for _,entity in ipairs(state.owned) do if entity==fire then known=true;break end end
        if not known then state.native_children=true end
    end
    if state.first_fire and not state.first_fire.entity.valid and not state.first_fire.duration then
        state.first_fire.duration=tick-state.first_fire.born
    end
    if root.last_service then state.max_searches=math.max(state.max_searches,root.last_service.searches) end
    for _,r in ipairs(state.trees) do
        if not r.entity.valid or r.entity.health<r.health then state.observed_damage=true end
    end
end
local function direct_start(terrain,state,tick)
    reset(terrain,state,"off",false,false,tick)
    local s=state.surface;state.direct={}
    s.clear_pollution() -- Native pollution greying is not evidence of burning.
    for i,spec in ipairs{
        {"ei-ecology-fire","neutral"},{"ei-ecology-fire","enemy"},
        {"fire-flame-on-tree","neutral"},{"fire-flame-on-tree","enemy"},
    } do
        local x=state.x+i*128
        s.request_to_generate_chunks({x,16},1);s.force_generate_chunk_requests()
        for _,e in ipairs(s.find_entities_filtered{area={{x-16,0},{x+16,32}}}) do e.destroy() end
        local tiles={}
        for tx=x-16,x+16 do for ty=0,32 do tiles[#tiles+1]={name="grass-1",position={tx,ty}} end end
        s.set_tiles(tiles,false,false,false,false)
        local tree=s.create_entity{name="tree-01",position={x+.5,16.5},force="neutral"}
        local fire=s.create_entity{name=spec[1],position=tree.position,target=tree,force=spec[2],initial_ground_flame_count=1}
        state.direct[#state.direct+1]={name=spec[1].."-"..spec[2],tree=tree,health=tree.health,stage=tree.tree_stage_index,gray=tree.tree_gray_stage_index,fire=fire}
    end
    clear_ecology(storage.ei.terrain_evolution)
end
local function guard_cases(terrain,state,tick)
    local root=storage.ei.terrain_evolution;local s=state.surface
    local entry=root.surfaces[s.index];local cfg=entry.config
    local p={x=state.x+16.5,y=16.5}
    local tree=s.create_entity{name="tree-01",position=p,force="neutral"}
    local record={surface=s,x=math.floor(p.x),y=math.floor(p.y),cause="ignite",extra={tree=tree}}
    local function budget()
        return {candidates=32,searches=1,writes=4,batches={},positions={},
            used_candidates=0,used_searches=0,used_writes=0,used_events=0}
    end
    local before=count(root)
    cfg.wildfire="off"
    check(state,"off-blocks-new-ignition",terrain._qc.entity_event(root,budget(),record,tick)==false and count(root)==before)
    cfg.wildfire="contained"
    local chest=s.create_entity{name="wooden-chest",position={p.x+3,p.y},force="player"}
    check(state,"infrastructure-blocks-new-ignition",terrain._qc.entity_event(root,budget(),record,tick)==false and count(root)==before)
    chest.destroy()
    local probe={surface=s,x=math.floor(p.x/32),y=0,schedule={hazard_due={}},pollution=10000}
    local pending=#root.pending.items
    cfg.wildfire_probability=0
    terrain._qc.hazards(root,budget(),probe,tick)
    check(state,"zero-probability-blocks-admission",#root.pending.items==pending)
    cfg.wildfire_probability=1;probe.schedule.hazard_due[1]=0;probe.pollution=0
    terrain._qc.hazards(root,budget(),probe,tick)
    check(state,"clean-chunk-blocks-admission",#root.pending.items==pending)
    root.hazard_surfaces=nil;root.natural_exclusions=nil
    terrain.on_load()
    local adoption_due=terrain.has_tick_work(tick)
    local deferred_adoption=adoption_due and root.hazard_surfaces==nil and root.natural_exclusions==nil
    terrain.updater{tick=tick}
    check(state,"legacy-cache-repair-on-first-tick",deferred_adoption and root.hazard_surfaces~=nil and root.natural_exclusions~=nil)
    cfg=root.surfaces[s.index].config
    assert(terrain.set_override(s,"wildfire","contained",tick))
    probe.schedule.hazard_due={[1]=tick+100000};probe.schedule.hazard_epoch=-1;probe.pollution=10000
    terrain._qc.hazards(root,budget(),probe,tick)
    local rearmed=probe.schedule.hazard_due[1]
    check(state,"changed-mode-rearms-without-catchup",rearmed and rearmed>tick and rearmed<tick+100000)
    cfg=root.surfaces[s.index].config;cfg.cliffs=true;cfg.cliff_probability=1;cfg.flood=true;cfg.flood_probability=1
    local kinds={}
    for i=1,3 do
        probe.schedule.hazard_due={}
        terrain._qc.hazards(root,budget(),probe,tick+i)
        kinds[probe.schedule.hazard_kind]=true
    end
    check(state,"enabled-hazards-get-independent-turns",kinds[1] and kinds[2] and kinds[3])
    local function flame(name,offset)
        return s.create_entity{name=name,position={p.x+offset,p.y},force="neutral",initial_ground_flame_count=1}
    end
    local a,b,c=flame("ei-ecology-fire",1),flame("ei-ecology-fire",2),flame("ei-ecology-fire",3)
    root.fires={items={
        {id="live",entity=a,surface=s,started=tick,expires=tick+500},
        {id="expired-b",entity=b,surface=s,started=tick-600,expires=tick-1},
        {id="expired-c",entity=c,surface=s,started=tick-600,expires=tick-1},
    },index={live=1,["expired-b"]=2,["expired-c"]=3},cursor=1}
    root.next_tick=tick;root.next_search=tick+100000;root.next_fire_cleanup=tick
    terrain.updater{tick=tick}
    check(state,"cleanup-visits-every-expired-record",a.valid and not b.valid and not c.valid)
    local combat=flame("fire-flame",16)
    root.config.interval=1
    terrain.initialize(tick)
    check(state,"cadence-change-retires-contained-only",not a.valid and combat.valid)
    local owned=flame("ei-ecology-fire",4)
    local index=#root.fires.items+1
    root.fires.items[index]={id="surface-disable",entity=owned,surface=s,started=tick,expires=tick+500}
    root.fires.index["surface-disable"]=index
    root.next_tick=tick+8
    terrain.initialize(tick)
    check(state,"same-cadence-settings-preserve-cleanup-deadline",owned.valid and root.next_tick<=tick+8)
    assert(terrain.set_override(s,"active",false,tick))
    check(state,"last-surface-disable-retires-contained",not owned.valid and combat.valid)
    combat.destroy()
    if tree.valid then tree.destroy() end
end
function model.step(terrain,tick)
    local state=storage.terrain_wildfire_fixture
    if not state then
        state={phase=1,cases={}};storage.terrain_wildfire_fixture=state
        reset(terrain,state,"contained",true,true,tick)
    end
    local root=storage.ei.terrain_evolution
    if state.phase==5 then
        for _,r in ipairs(state.direct) do
            if not r.tree.valid or r.tree.health<r.health or r.tree.tree_stage_index~=r.stage or r.tree.tree_gray_stage_index~=r.gray then r.damaged=true end
            if tick-state.start>=150 and r.fire and r.fire.valid then r.after_fade=true end
        end
        if tick-state.start<1200 then return end
        for _,r in ipairs(state.direct) do
            check(state,"direct-"..r.name.."-after-fade",r.after_fade==true)
        end
        guard_cases(terrain,state,tick)
        local result={all_pass=true,count=0,cases=state.cases}
        for _,c in pairs(result.cases) do result.count=result.count+1;if not c.pass then result.all_pass=false end end
        return result
    end
    maintain_pollution(state,tick)
    observe(state,root,tick)
    -- Admission now has a scheduled first opportunity. Preserve the original
    -- 1800-tick minimum and allow 1200 native ticks after ignition, with a
    -- hard 3600-tick phase ceiling; a missing ignition still fails.
    local finish=state.first_fire and math.max(1800,state.first_fire.born-state.start+1200) or 3600
    if tick-state.start<math.min(3600,finish) then return end
    local detail=diagnostics(state,root,tick);detail.before=state.before;detail.after=count(root)
    local prefix=state.mode..(state.degradation and "-soil-on" or "-soil-off")..(state.dense and "-dense" or "-sparse")
    check(state,prefix.."-autonomous-ignition",count(root)>state.before,detail)
    check(state,prefix.."-native-fire-exists",state.observed_fire)
    if state.degradation then
        local effects=root.surfaces[state.surface.index].effects
        check(state,prefix.."-soil-actually-progresses",(effects and effects.pollution or 0)>state.before_soil)
    end
    -- Contained retains finite ground flames; native forest burning belongs to
    -- Spreading. Sparse forests need not have a reachable propagation neighbor.
    if state.mode=="spreading" and state.dense then check(state,prefix.."-native-tree-damage",state.observed_damage,detail) end
    check(state,prefix.."-query-budget",state.max_searches<=root.config.searches)
    if state.mode=="spreading" and state.dense then check(state,prefix.."-native-spread",state.native_children)
    elseif state.mode=="contained" then
        check(state,prefix.."-no-native-spread",not state.native_children)
        check(state,prefix.."-finite-lifetime",state.first_fire and state.first_fire.duration~=nil and state.first_fire.duration<=600,
            state.first_fire and state.first_fire.duration)
    end
    state.phase=state.phase+1
    if state.phase==2 then reset(terrain,state,"spreading",true,true,tick)
    elseif state.phase==3 then reset(terrain,state,"contained",false,false,tick)
    elseif state.phase==4 then reset(terrain,state,"spreading",false,false,tick)
    else direct_start(terrain,state,tick) end
end
return model
