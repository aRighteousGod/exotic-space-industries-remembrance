-- Production event/index/queue acceptance. No direct registry insertion.
local config=require("test-config")
local reload_checked=false
local loaded=false
script.on_load(function() loaded=true end)
local function call(name,...) return remote.call("ei-water-qc",name,...) end
local function sample(entity) return call("sample",entity) end
local function delta(a,b) return (a-b+0.5)%1-0.5 end
local function check(name,pass,detail) storage.index_qc.results[name]={pass=pass==true,detail=detail} end
local function flame(surface,x,y,name)
    return surface.create_entity{name=name or "ei-oil-fire-flame",position={x,y},force="neutral"}
end
local function turret(s,x,y,water,weapon)
    local e=s.surface.create_entity{name="ei-water-turret",position={x,y},force="player",raise_built=true}
    call("preferences",e,3,weapon or false)
    if water>0 then e.insert_fluid{name="water",amount=water} end
    s.turrets[#s.turrets+1]=e
    return e
end
local function setup(tick)
    local s={started=tick,results={},turrets={},aimers={},shots=0,skips=0,violations=0,held={}}
    storage.index_qc=s
    local surface=game.create_surface("water-index-qc",{width=2048,height=1536,autoplace_settings={entity={treat_missing_as_default=false}}})
    surface.request_to_generate_chunks({0,0},17);surface.force_generate_chunk_requests();s.surface=surface
    local tiles={}
    for x=-550,650 do for y=-300,650 do tiles[#tiles+1]={name="lab-dark-1",position={x,y}} end end
    surface.set_tiles(tiles)
    s.select=turret(s,-480,0,0)
    s.event=turret(s,-400,0,0)
    s.pause=turret(s,-320,0,0)
    s.compact=turret(s,-240,0,0)
    s.chunk=turret(s,-32.5,0,0)
    s.bootstrap_fire=flame(surface,-160,-10)
    s.bootstrap=turret(s,-160,0,0)
    for i=1,192 do
        local x,y=64+((i-1)%15)*40,64+math.floor((i-1)/15)*40
        local entity=turret(s,x,y,0)
        s.aimers[#s.aimers+1]={entity=entity,x=x,y=y}
    end
    check("startup-targeting",settings.startup["ei-water-turret-fire-targeting"].value==config.targeting,config.targeting)
end
local function report(s)
    local pass=true
    for _,r in pairs(s.results) do if not r.pass then pass=false end end
    helpers.write_file("water-qc.json",helpers.table_to_json{all_pass=pass,cases=s.results},false)
end
script.on_event(defines.events.on_tick,function(event)
    local tick=event.tick
    if not storage.index_qc then setup(tick);loaded=false end
    local s=storage.index_qc
    local t=tick-s.started
    if loaded and s.save_probes and not reload_checked then
        reload_checked=true
        local valid=0
        for _,probe in ipairs(s.save_probes or {}) do
            local r=sample(probe.entity)
            if r.generation==probe.generation and r.fire==probe.fire and r.next_pulse==probe.next_pulse
                and r.aim_checkpoint and r.aim_checkpoint>=probe.checkpoint then valid=valid+1 end
        end
        check("load-retains-queued-aim",valid>0 and valid==#(s.save_probes or {}),valid)
    end
    for _,e in ipairs(s.turrets) do
        if e.valid then sample(e).power.energy=s.held[e.unit_number] and 0 or 50000 end
    end
    if t==1200 then
        local state=call("state")
        s.queries=state.counters.searches;s.cold=state.counters.acquisitions
        check("bootstrap-discovered-preexisting",state.index.fires[script.register_on_object_destroyed(s.bootstrap_fire)]~=nil)
        local outside=flame(s.surface,-540,-200)
        check("outside-coverage-not-retained",call("state").index.fires[script.register_on_object_destroyed(outside)]==nil)
        local p=s.select.position
        local edge=flame(s.surface,p.x+24.125,p.y)
        check("outside-radius-inside-chunk-rejected",call("state").index.fires[script.register_on_object_destroyed(edge)]==nil)
        local weapon=flame(s.surface,p.x+10,p.y,"fire-flame")
        check("weapon-without-opt-in-not-retained",call("state").index.fires[script.register_on_object_destroyed(weapon)]==nil)
        s.far=flame(s.surface,-470,2);s.near=flame(s.surface,-478,2)
        s.select.insert_fluid{name="water",amount=15}
        s.select.orientation=0.75
        s.event_fire=flame(s.surface,-388,0);s.event.insert_fluid{name="water",amount=15}
        s.pause_fire=flame(s.surface,-308,0);s.pause.insert_fluid{name="water",amount=15};s.pause.orientation=0.75
        for _,a in ipairs(s.aimers) do
            a.fire=flame(s.surface,a.x+12,a.y)
            local p,f=a.entity.position,a.fire.position
            a.goal=(math.atan2(f.y-p.y+1.3620957621,f.x-p.x)/(2*math.pi)+0.25)%1
            a.entity.orientation=(a.goal+0.5)%1;a.previous=a.entity.orientation
            a.entity.insert_fluid{name="water",amount=15}
        end
    end
    if t>=1200 and t<1700 then
        local counters=call("counters")
        if s.last_counters then
            local previous=s.last_counters
            if counters.hot_services-previous.hot_services>32 or counters.cold_slices-previous.cold_slices>8
                or counters.wake_visits-previous.wake_visits>32 or counters.searches-previous.searches>1
                or counters.candidate_visits+counters.maintenance_visits-previous.candidate_visits-previous.maintenance_visits>512 then
                s.budget_failure=true
            end
        end
        s.last_counters=counters
    end
    if t>=1200 and t<1500 then
        local selected=sample(s.select)
        if selected.fire and not s.selected then
            s.selected=true
            check("selection-policy",selected.fire==(config.targeting=="nearest" and s.near or s.far))
        end
        local r=sample(s.pause)
        if r.phase=="hot" and r.aim_checkpoint and not s.paused then
            s.paused=tick;s.held[s.pause.unit_number]=true;r.power.energy=0;s.pause_orientation=s.pause.orientation
        elseif s.paused and not s.resumed and tick-s.paused>=90 then
            s.resumed=tick;s.held[s.pause.unit_number]=nil
        end
        if s.paused and not s.resumed then
            check("paused-no-turn",math.abs(delta(s.pause.orientation,s.pause_orientation))<0.0001)
            check("paused-no-water",s.pause.get_fluid_count("water")==15)
        elseif s.resumed and not s.resume_checked and math.abs(delta(s.pause.orientation,s.pause_orientation))>0.0001 then
            check("resume-no-old-credit",math.abs(delta(s.pause.orientation,s.pause_orientation))<=0.02*(tick-s.resumed)+0.0001)
            s.resume_checked=true
        end
        for _,a in ipairs(s.aimers) do
            local r=sample(a.entity)
            if r.phase=="hot" and not a.acquired then a.acquired=r.aim_checkpoint end
            local step=math.abs(delta(a.entity.orientation,a.previous))
            if step>0.0201 then s.skips=s.skips+1 end
            if step>0 and a.checkpoint then s.max_gap=math.max(s.max_gap or 0,tick-a.checkpoint) end
            if a.checkpoint and step>0.02*math.max(0,tick-a.checkpoint)+0.0001 then s.violations=s.violations+1 end
            a.checkpoint=r.aim_checkpoint;a.previous=a.entity.orientation
            if a.entity.get_fluid_count("water")<1 and not a.shot then
                a.shot=tick;s.shots=s.shots+1
                check("aligned-"..s.shots,math.abs(delta(a.entity.orientation,a.goal))<0.0001,{actual=a.entity.orientation,goal=a.goal})
                check("catchup-duration-"..s.shots,a.acquired~=nil and tick-a.acquired<=32,{start=a.acquired,shot=tick})
                check("fresh-cooldown-"..s.shots,r.next_pulse==tick+60)
            end
        end
    end
    if t==1210 and config.save then
        s.save_probes={}
        for _,a in ipairs(s.aimers) do
            local r=sample(a.entity)
            if r.phase=="hot" and r.aim_checkpoint then
                s.save_probes[#s.save_probes+1]={entity=a.entity,fire=r.fire,checkpoint=r.aim_checkpoint,
                    generation=r.generation,next_pulse=r.next_pulse}
            end
        end
        check("save-has-queued-aimers",#s.save_probes>0,#s.save_probes)
        report(s);game.server_save("water-transition")
    end
    if t==1500 then
        check("event-suppressed",not s.event_fire.valid)
        check("all-aimers-served",s.shots==192,s.shots)
        check("backlog-skips-frames",s.skips>0,s.skips)
        check("five-tick-or-longer-gap",(s.max_gap or 0)>=5,s.max_gap)
        check("elapsed-step-budget",s.violations==0,s.violations)
        check("fixed-service-budgets",not s.budget_failure)
        check("resumed-and-fired",s.resume_checked==true and s.pause.get_fluid_count("water")<1)
        check("no-event-discovery-query",call("state").counters.searches==s.queries)
        s.compact_fires={}
        for i=1,600 do s.compact_fires[i]=flame(s.surface,-235+(i%10)*0.1,2+math.floor(i/10)*0.1) end
        s.compact.insert_fluid{name="water",amount=15}
    end
    if t==1502 then
        for i=1,450 do if s.compact_fires[i].valid then s.compact_fires[i].destroy() end end
        s.compact_new=flame(s.surface,-238,0)
    end
    if t==1504 then
        s.compact_during=flame(s.surface,-240,12)
        s.compact_transient=flame(s.surface,-240,14)
    end
    if t==1505 then s.compact_transient.destroy() end
    if t==1650 then
        local state=call("state")
        check("compaction-progress",state.counters.compactions>0,state.counters.compactions)
        local valid=true
        for id,r in pairs(state.index.fires) do
            local list=r.bucket[r.category]
            if not r.entity.valid or not list.slots[id] or list.items[list.slots[id]]~=id then valid=false end
        end
        check("compaction-membership",valid)
        check("compaction-mirrors-birth",state.index.fires[script.register_on_object_destroyed(s.compact_during)]~=nil)
        check("compaction-mirrors-removal",not s.compact_transient.valid)
        check("fixed-cold-work-budgets",not s.budget_failure)
        s.surface.delete_chunk{x=-1,y=0}
        s.surface.request_to_generate_chunks({-16,1},1);s.surface.force_generate_chunk_requests()
        s.chunk_fire=flame(s.surface,-20,2);s.chunk.insert_fluid{name="water",amount=15}
    end
    if t==1850 then
        check("chunk-neighbor-still-discovers",not s.chunk_fire.valid)
        local r=sample(s.event);local energy=r.power.energy;local helper=r.power
        call("repair")
        local after=sample(s.event)
        check("repair-retains-helper",after.power==helper and helper.energy==energy)
        check("repair-clears-aim-credit",after.aim_checkpoint==nil)
        s.repair_queries=call("state").counters.searches
    end
    if t==2100 then
        s.cooldown_fire=flame(s.surface,-388,0)
        s.event.insert_fluid{name="water",amount=30}
    end
    if t>=2100 and t<2400 then
        local r=sample(s.event)
        if not s.cooldown_deadline and s.event.get_fluid_count("water")<30 then
            s.cooldown_deadline=r.next_pulse;s.cooldown_orientation=s.event.orientation
            for _,stream in pairs(s.surface.find_entities_filtered{type="stream",position=s.event.position,radius=30}) do stream.destroy() end
            s.cooldown_fire.teleport({-410,10},nil,true)
        elseif s.cooldown_deadline then
            local step=math.abs(delta(s.event.orientation,s.cooldown_orientation))
            if tick<s.cooldown_deadline and step>0.0001 then s.cooldown_moved=true end
            if tick==s.cooldown_deadline then
                check("no-cooldown-turn-credit",step<0.0001)
                check("no-cooldown-water",s.event.get_fluid_count("water")==15)
            end
        end
    end
    if t==2400 then
        check("cooldown-remains-still",not s.cooldown_moved)
        check("second-pulse-after-cooldown",s.cooldown_fire and not s.cooldown_fire.valid and s.event.get_fluid_count("water")<1)
    end
    if t==3200 then
        s.settled_queries=call("state").counters.searches
        s.settled_acquisitions=call("state").counters.acquisitions
        s.settled_power=call("state").counters.power_checks
    end
    if t==4000 then
        local state=call("state")
        check("no-periodic-queries",state.counters.searches==s.settled_queries)
        check("cold-turrets-sleep",state.counters.acquisitions==s.settled_acquisitions)
        check("power-interlock-continues",state.counters.power_checks>s.settled_power)
    end
    if t==4100 then
        local surface=game.create_surface("water-import-qc",{width=128,height=128})
        surface.request_to_generate_chunks({0,0},1);surface.force_generate_chunk_requests()
        local e=surface.create_entity{name="ei-water-turret",position={0.5,0.5},force="player"}
        local old=surface.create_entity{name="ei-water-turret-power",position=e.position,force="player"}
        call("imported",surface)
        check("import-helper-reconciled",not old.valid and surface.count_entities_filtered{name="ei-water-turret-power"}==1)
        s.imported=surface;s.imported_turret=e
        s.turrets[#s.turrets+1]=e;call("preferences",e,3,false)
        s.uncovered=flame(surface,30,0.5)
        check("uncovered-fire-unindexed",call("state").index.fires[script.register_on_object_destroyed(s.uncovered)]==nil)
    end
    if t==4200 then
        s.imported_turret.teleport({12.5,0.5},nil,true)
        s.imported_turret.insert_fluid{name="water",amount=15}
    end
    if t==4450 then
        check("new-coverage-seeds-existing-fire",not s.uncovered.valid)
        s.moving_fire=flame(s.imported,60,0.5)
        s.moving_fire.teleport({20,0.5},nil,true)
        s.imported_turret.insert_fluid{name="water",amount=15}
    end
    if t==4650 then
        check("notified-fire-movement",not s.moving_fire.valid)
        s.deleted_surface=s.imported.index
        game.delete_surface(s.imported)
    end
    if t==4660 then check("surface-coverage-released",call("state").index.surfaces[s.deleted_surface]==nil) end
    if t==6000 then report(s) end
end)
