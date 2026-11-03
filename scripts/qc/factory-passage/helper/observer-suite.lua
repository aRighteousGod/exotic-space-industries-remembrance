-- Private native fixture. Both benchmark revisions run this identical driver.
local fixture=require("fixture-config")
local passage=require("scripts/control/factory-passage")
local loaded=false
local profiler
local profiled_ticks=0
local function check(value,name,detail)
    storage.checks[#storage.checks+1]={name=name,passed=not not value,detail=detail}
    assert(value,"Observer QC: "..name.." "..serpent.line(detail or {}))
end
local function receipt(name,extra)
    local result=extra or {};result.passed=true;result.checks=storage.checks;result.status=passage.status()
    result.mode=fixture.mode;result.enabled=true;result.engine=script.active_mods.base;result.tick=game.tick;result.loaded=loaded
    result.count=fixture.performance;result.circuit_percent=fixture.circuit_percent;result.revision=fixture.revision;result.circuit_budget=fixture.circuit_budget or 1
    helpers.write_file("factory-passage/"..name..".json",helpers.table_to_json(result),false)
end
local function build(s,name,x,y)
    return assert(s.create_entity{name=name,position={x,y},force="player",snap_to_grid=false})
end
local function refresh(entity) passage.refresh_entity(entity,game.tick,true) end
local function capture(label)
    if not fixture.visual then return end
    local frame={path="factory-passage/observer-"..label..".png",scene=label}
    if label=="open-recipe" then
        game.take_screenshot{resolution={1280,720},path=frame.path,show_gui=true,force_render=true,player=game.get_player(1)}
    else
        game.take_screenshot{surface=game.surfaces[storage.surface],position={0,-0.5},resolution={800,600},zoom=2,
            path=frame.path,show_gui=true,player=game.get_player(1)}
    end
    storage.frames[#storage.frames+1]=frame
end
local function expected_watchers()
    return fixture.revision=="baseline" and fixture.performance or math.floor(fixture.performance*fixture.circuit_percent/100)
end
local function topology_same(before,now)
    return before.topology==now.topology and before.created==now.created and before.destroyed==now.destroyed
end
script.on_init(function()
    settings.global["ei-factory-passage-update-budget"]={value=fixture.budget}
    settings.global["ei-factory-passage-circuit-scanner-enabled"]={value=true}
    settings.global["ei-factory-passage-circuit-scan-budget"]={value=fixture.circuit_budget or 1}
    if fixture.performance>0 then game.speed=100 end
    if remote.interfaces.freeplay then remote.call("freeplay","set_skip_intro",true);remote.call("freeplay","set_disable_crashsite",true) end
    storage.started=game.tick;storage.checks={};storage.frames={};storage.gui_events={}
    local s=game.create_surface("observer-qc",{width=2048,height=2048,seed=137013,water="none",
        autoplace_settings={entity={treat_missing_as_default=false},decorative={treat_missing_as_default=false}}})
    s.request_to_generate_chunks({400,400},15);s.force_generate_chunk_requests()
    for _,e in pairs(s.find_entities()) do e.destroy() end
    s.freeze_daytime=true;s.daytime=0.5;storage.surface=s.index
    storage.machines={};storage.pipes={}
    local n=math.max(1,fixture.performance)
    for i=1,n do
        local x,y=((i-1)%100)*8+0.5,math.floor((i-1)/100)*8+0.5
        local e=build(s,"ei-passage-qc-crafter",x,y)
        e.set_recipe("ei-passage-qc-fluid-recipe")
        if i<=math.floor(n*(fixture.circuit_percent or 0)/100) then
            -- An unwired native circuit selector can retain its current recipe.
            -- Start both measured revisions in the same explicit empty state.
            e.set_recipe(nil);e.get_or_create_control_behavior().circuit_set_recipe=true
        end
        storage.machines[i]=e;storage.pipes[i]=build(s,"pipe",x-1,y-2)
    end
    passage.rebuild_runtime_state("fixture",game.tick)
end)
script.on_load(function() loaded=true end)
script.on_event(defines.events.on_object_destroyed,passage.on_object_destroyed)
script.on_event(defines.events.script_raised_destroy,function(e) passage.on_removed(e.entity,e) end)
script.on_event(defines.events.script_raised_teleported,passage.on_teleported)
script.on_event(defines.events.on_gui_opened,function(e)
    storage.gui_events[#storage.gui_events+1]={kind="open",tick=e.tick,gui_type=e.gui_type,entity=e.entity and e.entity.name}
    if passage.on_gui_opened then passage.on_gui_opened(e) end
end)
script.on_event(defines.events.on_gui_closed,function(e)
    storage.gui_events[#storage.gui_events+1]={kind="close",tick=e.tick,gui_type=e.gui_type,entity=e.entity and e.entity.name}
    if passage.on_gui_closed then passage.on_gui_closed(e) end
end)
if passage.on_player_left then
    script.on_event({defines.events.on_player_left_game,defines.events.on_player_died,defines.events.on_player_removed},passage.on_player_left)
end
remote.add_interface("ei_observer_qc",{
    status=function() return passage.status() end,
    gui_events=function() return storage.gui_events end,
    export=function() receipt("observer-interactive",{events=storage.gui_events,frames=storage.frames}) end,
})
script.on_event(defines.events.on_tick,function(event)
    if fixture.performance>0 and storage.saved then
        profiler=profiler or helpers.create_profiler(true)
        profiler.restart();profiled_ticks=profiled_ticks+1
    end
    if passage.has_work(event.tick) then passage.updater(passage.update_budget(),event) end
    if profiler then profiler.stop() end
    local age=event.tick-storage.started;local now=passage.status()
    if fixture.performance>0 then
        if storage.saved then
            if not storage.idle_start then storage.idle_start={tick=event.tick,status=now} end
            if event.tick-storage.idle_start.tick==5990 then
                check(topology_same(storage.idle_start.status.counters,now.counters),"no idle topology or helper churn")
                check(now.watchers==expected_watchers(),"exact observer population",now.watchers)
                local attempts=(now.counters.watchers_attempts or 0)-(storage.idle_start.status.counters.watchers_attempts or 0)
                check(expected_watchers()>0 or attempts==0,"manual candidate generates zero observer attempts",attempts)
                local circuit_attempts=(now.counters.circuit_attempts or 0)-(storage.idle_start.status.counters.circuit_attempts or 0)
                if fixture.revision=="baseline" then
                    check(attempts==5990*math.min(expected_watchers(),math.ceil(fixture.budget/8)),"exact baseline observer attempts",attempts)
                else
                    check(attempts==0,"no recurring GUI checks without viewers",attempts)
                    check(circuit_attempts<=5990*(fixture.circuit_budget or 1),"independent circuit attempt cap",circuit_attempts)
                    check(expected_watchers()>0 or circuit_attempts==0,"manual population has zero circuit attempts")
                    check(now.counters.circuit_max_attempts<=(fixture.circuit_budget or 1),"peak circuit cap")
                end
                profiler.divide(profiled_ticks);log({"","passage-profiler-ms-per-tick=",profiler})
                receipt("performance-idle",{watcher_attempts=attempts,circuit_attempts=circuit_attempts,observation_ticks=5990,ready_tick=storage.ready_tick,latency=storage.latency})
            end
            return
        end
        -- Circuit-selected machines start recipe-less. Verify actual helper
        -- counts as well as queues before driving a native circuit recipe change.
        local initial_helpers=fixture.performance-math.floor(fixture.performance*fixture.circuit_percent/100)
        if now.dirty==0 and now.pending==0 and now.helpers==initial_helpers then storage.ready_tick=storage.ready_tick or age end
        if storage.ready_tick and not storage.latency then
            storage.latency={manual_request=event.tick,helpers=now.helpers}
            local manual=storage.machines[#storage.machines]
            manual.set_recipe(nil);refresh(manual)
        elseif storage.latency and not storage.latency.manual_ticks and now.helpers==storage.latency.helpers-1 then
            storage.latency.manual_ticks=event.tick-storage.latency.manual_request
            local manual=storage.machines[#storage.machines]
            manual.set_recipe("ei-passage-qc-fluid-recipe");refresh(manual)
        elseif storage.latency and storage.latency.manual_ticks and now.helpers==storage.latency.helpers and now.dirty==0 and now.pending==0 and not storage.latency.signal_request and fixture.circuit_percent>0 then
            local machine=storage.machines[1]
            local combinator=build(machine.surface,"constant-combinator",4,0)
            combinator.get_or_create_control_behavior().add_section().set_slot(1,{value={type="recipe",name="ei-passage-qc-fluid-recipe",quality="normal"},min=1})
            combinator.get_wire_connector(defines.wire_connector_id.circuit_red,true).connect_to(machine.get_wire_connector(defines.wire_connector_id.circuit_red,true))
            storage.latency.signal_request=event.tick
        end
        if storage.latency and storage.latency.signal_request and not storage.latency.joint_ticks then
            if storage.machines[1].get_recipe() then storage.latency.recipe_tick=storage.latency.recipe_tick or event.tick end
            if now.helpers==storage.latency.helpers+1 then
                storage.latency.joint_ticks=event.tick-storage.latency.signal_request
                storage.latency.observer_ticks=event.tick-storage.latency.recipe_tick
            end
        end
        if age==4096 then
            check(now.update_budget==fixture.budget and now.counters.max_processed<=fixture.budget,"native configured budget and attempt cap")
            check(storage.latency and storage.latency.manual_ticks and (fixture.circuit_percent==0 or storage.latency.joint_ticks),"manual and circuit latency probes completed",{latency=storage.latency,ready_tick=storage.ready_tick,status=now,recipe=storage.machines[1].get_recipe() and storage.machines[1].get_recipe().name})
            check(now.dirty==0 and now.pending==0,"checkpoint settled",now)
            check(now.watchers==expected_watchers(),"checkpoint observer population",now.watchers)
            game.speed=1;storage.saved=true;receipt("performance-ready",{ready_tick=storage.ready_tick,latency=storage.latency})
            game.server_save("factory-passage-performance")
        end
        return
    end
    -- Native boundary checks use absolute fixture age, before the GUI sequence's
    -- deliberate sixty-tick pause. Admission at tick 37 establishes deadline 97.
    if age==96 then
        check((now.counters.circuit_attempts or 0)==0 and now.helpers==0,"native cooldown excludes tick 59")
    elseif age==97 then
        check(now.counters.circuit_scans==1 and now.helpers==0 and now.dirty>0,"native tick 60 scans and defers reconciliation")
    elseif age==98 then
        check(now.helpers==1 and now.next_circuit_tick==event.tick+60,"native completed reconciliation refreshes deadline")
    elseif age==99 then
        storage.parked_attempts=now.counters.circuit_attempts
        settings.global["ei-factory-passage-circuit-scanner-enabled"]={value=false}
    elseif age==110 then
        check(now.counters.circuit_attempts==storage.parked_attempts and now.circuit_candidates==1,"native scanner Off parks its candidate")
        settings.global["ei-factory-passage-circuit-scanner-enabled"]={value=true}
    end
    -- Allow the first native circuit deadline to mature before GUI/movement checks.
    if age>=120 then age=age-60 elseif age>=60 then return end
    local machine=storage.machines[1];local pipe=storage.pipes[1]
    if storage.finished then
        if loaded and not storage.reload_checked then
            check(now.watchers==storage.saved_status.watchers and now.helpers==storage.saved_status.helpers,"ordinary reload preserves observer/helper population")
            check(now.counters.topology==storage.saved_status.counters.topology,"ordinary reload avoids topology rebuild")
            storage.reload_checked=true;receipt("observer-reload")
        end
        return
    end
    if age==12 then
        check(now.watchers==0 and now.helpers==1,"native manual coupling without observer",now)
        storage.before=now.counters;machine.set_recipe(nil)
    elseif age==24 then
        check(topology_same(storage.before,now.counters) and now.helpers==1,"silent script recipe change requires refresh hook")
        refresh(machine)
    elseif age==36 then
        check(now.helpers==0 and now.watchers==0,"notified empty recipe opens joint")
        machine.get_or_create_control_behavior().circuit_set_recipe=true;refresh(machine)
    elseif age==48 then
        check(now.watchers==1 and now.circuit_watchers==1 and machine.get_recipe()==nil,"native no-signal circuit observer")
        local s=game.surfaces[storage.surface]
        local combinator=build(s,"constant-combinator",4,0)
        combinator.get_or_create_control_behavior().add_section().set_slot(1,{value={type="recipe",name="ei-passage-qc-fluid-recipe",quality="normal"},min=1})
        combinator.get_wire_connector(defines.wire_connector_id.circuit_red,true).connect_to(machine.get_wire_connector(defines.wire_connector_id.circuit_red,true))
        storage.combinator=combinator;storage.signal_tick=event.tick
    elseif age==60 then
        check(machine.get_recipe() and machine.get_recipe().name=="ei-passage-qc-fluid-recipe" and now.helpers==1,"native circuit recipe builds joint")
        machine.get_control_behavior().circuit_set_recipe=false;refresh(machine)
        storage.player=game.get_player(1)
        if storage.player and storage.player.connected then
            storage.player.teleport({3,3},machine.surface);storage.player.opened=machine
            passage.on_gui_opened{player_index=1,tick=event.tick}
        end
        machine.set_recipe(nil)
    elseif age==72 then
        if storage.player and storage.player.connected then
            check(now.gui_watchers==1 and now.circuit_watchers==0 and now.helpers==0,"native open GUI observes recipe clearing")
            machine.set_recipe("ei-passage-qc-fluid-recipe")
        else
            check(now.watchers==0,"circuit observer retires after disabled")
            machine.set_recipe("ei-passage-qc-fluid-recipe");refresh(machine)
        end
    elseif age==74 then
        if storage.player and storage.player.connected then
            check(storage.player.opened==machine,"native machine GUI remains open after recipe change")
            capture("open-recipe")
        end
    elseif age==84 then
        check(now.helpers==1,"fluid recipe restores coupling")
        if storage.player and storage.player.connected then
            storage.player.opened=nil;passage.on_gui_closed{player_index=1,entity=machine,tick=event.tick}
        end
        storage.actor=build(machine.surface,"character",-2,-1)
        storage.actor.walking_state={walking=true,direction=defines.direction.east}
    elseif age==114 then
        check(storage.actor.position.x<-.8,"native movement cannot cross connected machine joint",storage.actor.position)
        storage.actor.walking_state={walking=false};storage.actor.teleport({-2,-1})
        machine.set_recipe(nil);refresh(machine)
    elseif age==126 then
        storage.actor.walking_state={walking=true,direction=defines.direction.east}
    elseif age==156 then
        check(storage.actor.position.x>0,"native movement crosses removed machine joint",storage.actor.position)
        storage.actor.destroy();storage.combinator.destroy()
        capture("open-joint");storage.saved_status=now;storage.finished=true
        receipt("observer-functional",{frames=storage.frames,events=storage.gui_events})
        if game.is_multiplayer() then game.server_save("factory-passage-performance")
        elseif fixture.visual then game.auto_save("factory-passage-observers") end
    end
    if (age>=85 and age<=114 or age>=127 and age<=156) and age%3==0 then capture("movement-"..age) end
end)
