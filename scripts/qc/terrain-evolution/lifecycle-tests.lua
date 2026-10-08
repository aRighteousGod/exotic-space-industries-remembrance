-- Native fixture only. Import at file load from the private staged ESIR bridge.
-- run() deliberately clears Nauvis in the isolated QC save; never use in a player save.
local tests={}
local fields={"dusk","evening","morning","dawn"}
local function same(a,b)
    for _,k in ipairs(fields) do if math.abs(a[k]-b[k])>1e-8 then return false end end
    return true
end
local function count(t) local n=0;for _ in pairs(t) do n=n+1 end;return n end
local function empty_set() return {items={},index={},cursor=1} end

function tests.run(terrain,calendar)
    assert(script.active_mods["zzz-esir-terrain-qc"],"Isolated terrain QC mod required")
    local results={}
    local deferred_clear=false
    local function check(name,value,detail) results[name]={pass=value==true,detail=detail} end
    local surface=game.surfaces.nauvis
    local fulgora=game.planets.fulgora.create_surface()
    local original_root=storage.ei.terrain_evolution
    local saved={}
    for _,s in pairs(game.surfaces) do
        saved[#saved+1]={surface=s,parameters=s.daytime_parameters,freeze=s.freeze_daytime,
            always=s.always_day,rotation=s.ticks_per_day,solar=s.solar_power_multiplier}
    end
    calendar.release(original_root)
    local tick=game.tick+1000
    local function fresh()
        storage.ei.terrain_evolution=nil
        terrain.initialize(tick)
        local root=storage.ei.terrain_evolution
        root.surface_order={surface.index};root.enabled_surfaces=1
        root.config.enabled=true;root.compatibility=nil;root.config.cold_chunks=0
        for index,entry in pairs(root.surfaces) do
            local c=entry.config
            c.enabled=index==surface.index;c.seasonal_daylight=false;c.seasonal_ecology=false
            c.degradation=false;c.tree_stress=false;c.tree_regrowth=false
            c.aging=false;c.rot=false;c.flood=false;c.drought=false;c.cliffs=false
            c.blood=false;c.wildfire="off";c.recovery=false;c.protection_buffer=0
            c.hazard_radius=1;c.intensity_multiplier=1
        end
        root.calendar.order={surface.index};root.calendar.cursor=1
        surface.always_day=false;surface.freeze_daytime=false
        return root,root.surfaces[surface.index]
    end
    local function step(root,advance)
        tick=tick+(advance or 32);root.next_tick=tick
        terrain.updater{tick=tick}
    end
    local function patch(x,y,name)
        local tiles={}
        for dx=-3,3 do for dy=-3,3 do tiles[#tiles+1]={name=name,position={x+dx,y+dy}} end end
        surface.set_tiles(tiles,false,false,false,true)
    end
    local ok,message=pcall(function()
        -- Actual native tuples, with analytic service ticks supplied explicitly.
        local root,entry=fresh()
        local baseline={dusk=.25,evening=.45,morning=.55,dawn=.75}
        surface.daytime_parameters=baseline
        local cfg={enabled=true,seasonal_daylight=true,year_days=360,tilt=23.5,latitude=45}
        local function visit()
            root.calendar.order={surface.index};root.calendar.cursor=1
            root.calendar.records[surface.index].next_tick=0
            calendar.service(root,tick,function() return cfg end)
        end
        local rotation,solar,daytime=surface.ticks_per_day,surface.solar_power_multiplier,surface.daytime
        calendar.set_phase(root,surface,.25,tick);visit()
        check("calendar-acquires-native-boundaries",not same(surface.daytime_parameters,baseline)
            and calendar.snapshot(root,surface,tick).owns_daylight)
        check("calendar-preserves-clock-and-solar",surface.ticks_per_day==rotation
            and surface.solar_power_multiplier==solar and surface.daytime==daytime)
        tick=tick+123
        local phase=calendar.snapshot(root,surface,tick).phase
        cfg.year_days=720;visit()
        check("period-change-preserves-phase",math.abs(calendar.snapshot(root,surface,tick).phase-phase)<1e-12)
        calendar.release(root)
        check("calendar-restores-owned-baseline",same(surface.daytime_parameters,baseline))
        calendar.set_phase(root,surface,0,tick);visit()
        local equinox_external=surface.daytime_parameters
        equinox_external.evening=equinox_external.evening+.001
        surface.daytime_parameters=equinox_external;visit()
        check("equinox-no-write-detects-external-control",calendar.snapshot(root,surface,tick).status=="external-control")
        calendar.release(root)
        check("equinox-release-preserves-external-tuple",same(surface.daytime_parameters,equinox_external))
        surface.daytime_parameters=baseline
        surface.freeze_daytime=true;calendar.set_phase(root,surface,.25,tick);visit()
        check("calendar-respects-freeze",same(surface.daytime_parameters,baseline)
            and surface.freeze_daytime and not calendar.snapshot(root,surface,tick).owns_daylight)
        surface.freeze_daytime=false;surface.always_day=true;visit()
        check("calendar-respects-always-day",same(surface.daytime_parameters,baseline)
            and surface.always_day and not calendar.snapshot(root,surface,tick).owns_daylight)
        surface.always_day=false;visit()
        local external=surface.daytime_parameters;external.evening=external.evening+.001
        surface.daytime_parameters=external;visit()
        check("external-change-suspends",calendar.snapshot(root,surface,tick).status=="external-control")
        calendar.release(root)
        check("release-preserves-external-tuple",same(surface.daytime_parameters,external))

        local f_parameters=fulgora.daytime_parameters
        local f_rotation=fulgora.ticks_per_day
        check("fulgora-phase-rejected",calendar.set_phase(root,fulgora,.25,tick)==false)
        -- A stale legacy record must not defeat the hard exclusion on release.
        root.calendar.records[fulgora.index]={surface=fulgora,baseline=baseline,last=f_parameters,
            phase=.25,epoch=tick,distance=25}
        root.calendar.order={fulgora.index};root.calendar.cursor=1
        calendar.service(root,tick,function() return cfg end)
        calendar.release_surface(root,fulgora.index);calendar.release(root)
        check("fulgora-hard-excluded-even-stale-record",same(fulgora.daytime_parameters,f_parameters)
            and fulgora.ticks_per_day==f_rotation)

        -- Last enabled override reset must release before the updater becomes idle.
        root,entry=fresh();surface.daytime_parameters=baseline
        root.config.active=false
        for _,e in pairs(root.surfaces) do e.config.enabled=false end
        root.enabled_surfaces=0
        terrain.set_override(surface,"active",true,tick)
        terrain.set_override(surface,"seasonal_daylight",true,tick)
        calendar.set_phase(root,surface,.25,tick)
        root.calendar.order={surface.index};root.calendar.cursor=1
        root.calendar.records[surface.index].next_tick=0
        calendar.service(root,tick,terrain.resolve_config)
        check("reset-fixture-owned-first",calendar.snapshot(root,surface,tick).owns_daylight)
        terrain.reset_overrides(surface,tick)
        check("reset-last-enabled-releases",same(surface.daytime_parameters,baseline)
            and not terrain.has_tick_work(tick+100000))

        -- Full active cache, smallest sample allowance, and a separate scar chunk.
        surface.request_to_generate_chunks({800,768},3);surface.force_generate_chunk_requests()
        for _,e in pairs(surface.find_entities_filtered{area={{748,748},{864,796}}}) do
            if e.valid and e.type~="character" then e.destroy() end
        end
        root,entry=fresh();surface.clear_pollution()
        root.config.active_cap=1;root.config.active_chunks=1
        root.config.tile_history_cap=1;root.config.histories=1
        patch(768,768,"grass-1");patch(800,768,"grass-1");patch(848,768,"grass-1")
        terrain.enqueue_scar(surface,{x=848,y=768},"wake",tick);step(root)
        check("saturated-cache-fixture",#root.active.items==1)
        terrain.enqueue_scar(surface,{x=768,y=768},"thermal",tick)
        for _=1,12 do step(root) end
        local history=root.history.items[1]
        assert(history,"First cap fixture scar was not created")
        local history_id=history.id
        terrain.enqueue_scar(surface,{x=800,y=768},"thermal",tick)
        for _=1,12 do step(root) end
        check("history-cap-never-evicts",#root.history.items==1 and root.history.index[history_id]~=nil)
        entry.config.recovery=true;entry.config.clean_seconds=1;entry.config.recovery_seconds=1
        history.next_tick=0
        for _=1,4 do step(root,700) end
        check("recovery-with-full-active-minimum-sample-budget",#root.history.items==0
            and surface.get_tile(history.x,history.y).name==history.origin)

        -- Untracked deletions must not create append-only token/tombstone state.
        local before=count(entry.chunk_tokens)
        for i=1,200 do terrain.on_chunk_deleted{surface_index=surface.index,positions={{x=10000+i,y=10000}},tick=tick} end
        check("untracked-deletion-metadata-bounded",count(entry.chunk_tokens)==before)

        -- A real delete/regenerate must invalidate old history, including same-name tile.
        entry.config.recovery=false
        terrain.enqueue_scar(surface,{x=768,y=768},"thermal",tick)
        for _=1,12 do step(root) end
        history=root.history.items[1];assert(history,"Deletion fixture scar missing")
        local x,y,expected=history.x,history.y,history.expected
        surface.delete_chunk{x=math.floor(x/32),y=math.floor(y/32)}
        surface.request_to_generate_chunks({x=x,y=y},0);surface.force_generate_chunk_requests()
        patch(x,y,expected)
        for _=1,3 do step(root) end
        check("regenerated-chunk-does-not-inherit-history",#root.history.items==0
            and surface.get_tile(x,y).name==expected)
        for _,e in pairs(surface.find_entities_filtered{area={{x-4,y-4},{x+5,y+5}}}) do
            if e.valid and e.type~="character" then e.destroy() end
        end
        patch(x,y,"grass-1")
        terrain.enqueue_scar(surface,{x=x,y=y},"thermal",tick)
        for _=1,12 do step(root) end
        history=root.history.items[1];assert(history,"Post-regeneration scar missing")
        entry.config.recovery=true;history.next_tick=0
        for _=1,4 do step(root,700) end
        check("new-history-after-regeneration-can-recover",#root.history.items==0
            and surface.get_tile(history.x,history.y).name==history.origin)

        -- Configure disable must detach active token references, preserving only history.
        root,entry=fresh()
        terrain.enqueue_scar(surface,{x=848,y=768},"wake",tick);step(root)
        check("token-disable-fixture-has-active",#root.active.items>0)
        for _,e in pairs(root.surfaces) do e.overrides.active=false end
        terrain.initialize(tick)
        entry=root.surfaces[surface.index]
        check("disable-detaches-active-tokens",#root.active.items==0 and count(entry.chunk_tokens)==0)

        -- Clearing terrain preserves the surviving surface's orbital identity.
        root,entry=fresh();surface.daytime_parameters=baseline
        entry.config.seasonal_daylight=true
        calendar.set_phase(root,surface,.25,tick)
        root.calendar.records[surface.index].next_tick=0
        calendar.service(root,tick,terrain.resolve_config)
        check("clear-fixture-owned-first",calendar.snapshot(root,surface,tick).owns_daylight)
        storage.__terrain_lifecycle_pending={results=results,surface=surface,baseline=baseline,
            owned=surface.daytime_parameters,orbit=root.calendar.records[surface.index],
            old_entry=entry,old_root=original_root,saved=saved}
        deferred_clear=true
        surface.clear() -- The API explicitly raises both clear events on a future tick.
    end)
    if not ok then check("fixture-execution",false,tostring(message)) end
    if deferred_clear and ok then return {pending=true,cases=results} end
    local current=storage.ei.terrain_evolution
    if current then calendar.release(current) end
    storage.ei.terrain_evolution=original_root
    for _,s in ipairs(saved) do
        if s.surface.valid then
            s.surface.daytime_parameters=s.parameters;s.surface.freeze_daytime=s.freeze
            s.surface.always_day=s.always;s.surface.ticks_per_day=s.rotation
            s.surface.solar_power_multiplier=s.solar
        end
    end
    local all,n=true,0
    for _,r in pairs(results) do n=n+1;all=all and r.pass end
    return {all_pass=all,count=n,cases=results}
end

function tests.finish_clear(terrain,calendar)
    local pending=storage.__terrain_lifecycle_pending
    assert(pending,"No deferred native clear fixture")
    local results=pending.results
    local surface=pending.surface
    local function check(name,value,detail) results[name]={pass=value==true,detail=detail} end
    local root=storage.ei.terrain_evolution
    check("native-clear-preserves-daylight",same(surface.daytime_parameters,pending.owned),surface.daytime_parameters)
    check("native-clear-preserves-orbit",root.calendar.records[surface.index]==pending.orbit)
    check("native-clear-reregisters-calendar",root.surfaces[surface.index]~=nil
        and root.surfaces[surface.index]~=pending.old_entry
        and root.calendar.records[surface.index]~=nil and root.enabled_surfaces>0)
    surface.request_to_generate_chunks({0,0},0);surface.force_generate_chunk_requests()
    check("native-clear-resumes-service",terrain.has_tick_work(game.tick+100000)==true)
    calendar.release(root)
    storage.ei.terrain_evolution=pending.old_root
    for _,s in ipairs(pending.saved) do
        if s.surface.valid then
            s.surface.daytime_parameters=s.parameters;s.surface.freeze_daytime=s.freeze
            s.surface.always_day=s.always;s.surface.ticks_per_day=s.rotation
            s.surface.solar_power_multiplier=s.solar
        end
    end
    storage.__terrain_lifecycle_pending=nil
    local all,n=true,0
    for _,r in pairs(results) do n=n+1;all=all and r.pass end
    return {all_pass=all,count=n,cases=results}
end

return tests
