-- Engine acceptance fixture. Expensive exhaustive checks exist only in this mod.
local config=require("__exotic-space-industries-remembrance__/lib/sweeping-radar-config")
local geometry=require("__exotic-space-industries-remembrance__/lib/sweeping-radar-geometry")
local contacts=require("__exotic-space-industries-remembrance__/lib/sweeping-radar-contacts")
local timers=require("__exotic-space-industries-remembrance__/lib/sweeping-radar-timers")
local current_tick
local function call(name,...) return remote.call("esir_radar_qc",name,current_tick,...) end
local function check(name,condition,detail)
    storage.tests[#storage.tests+1]={name=name,pass=condition==true,detail=detail}
end
local function preferences(mode,policy)
    local settings=config.defaults()
    settings.mode=mode;settings.contacts=policy or 1;settings.expiry=2
    for _,v in pairs(settings.modes) do v.radius=2;v.near=0;v.start=315;v.stop=45 end
    settings.modes[3].near=1
    return settings
end
local function pure_tests()
    local shape_count={}
    for mode=1,5 do
        local manual=preferences(mode)
        local s=manual.modes[mode];s.mode=mode
        local g=geometry.new(s,{x=16,y=16})
        local steps=0
        while g.phase~="ready" do geometry.step(g);steps=steps+1;assert(steps<10000) end
        local cells={}
        for _,cell in ipairs(g.cells) do
            local key=cell.x..":"..cell.y
            assert(not cells[key]);cells[key]=true
        end
        local missing=0
        for x=-80,80,2 do for y=-80,80,2 do
            if geometry.contains(g,x,y) and not cells[math.floor((x+16)/32)..":"..math.floor((y+16)/32)] then missing=missing+1 end
        end end
        check("geometry-complete-"..mode,missing==0,{cells=g.count,steps=steps,missing=missing})
        shape_count[mode]=g.count
    end
    check("fixed-and-sector-smaller",shape_count[5]<shape_count[1] and shape_count[2]<shape_count[1])
    local set=contacts.new()
    for i=1,2049 do contacts.observe(set,{id=tostring(i),x=i,y=0,distance2=i*i,bearing=90,tick=i},i+3000) end
    check("contact-cap",set.count==2048 and #set.expiry==2048 and #set.nearest==2048 and set.incomplete)
    for i=1,2048 do contacts.observe(set,{id=tostring(i),x=4096-i,y=0,distance2=(4096-i)^2,bearing=90,tick=4000},5000) end
    check("indexed-repeat-no-growth",#set.expiry==2048 and #set.nearest==2048 and set.nearest[1].id=="2048")
    local retired=0
    while contacts.expire_one(set,5000) do retired=retired+1 end
    check("bounded-expiry-drains",retired==2048 and set.count==0 and #set.nearest==0)
    local deadlines=timers.new()
    for i=1,10000 do timers.set(deadlines,i,"scan",10001-i) end
    for i=1,10000 do timers.set(deadlines,i,"scan",i) end
    for i=1,10000,2 do timers.cancel(deadlines,i..":scan") end
    check("one-deadline-per-owner",#deadlines.heap==5000)
    local ordered,last=true,0
    for i=1,5000 do
        local entry=timers.take_due(deadlines,10000)
        ordered=ordered and entry.tick>=last;last=entry.tick
    end
    check("deadlines-ordered-and-drained",ordered and #deadlines.heap==0 and next(deadlines.entries)==nil)
end
local function setup(tick)
    if storage.started then return end
    storage.started=tick;storage.tests={};storage.radars={};storage.targets={};storage.maximum={}
    local surface=game.create_surface("radar-acceptance",{width=2048,height=1024,autoplace_controls={}})
    surface.request_to_generate_chunks({0,0},12);surface.force_generate_chunk_requests()
    for _,entity in pairs(surface.find_entities_filtered{force="enemy"}) do entity.destroy() end
    local tiles={}
    for x=-20,90 do for y=180,215 do tiles[#tiles+1]={name="grass-1",position={x,y}} end end
    surface.set_tiles(tiles)
    local force=game.create_force("radar-acceptance")
    force.research_all_technologies()
    -- A real LuaPlayer membership is needed for native chart execution.
    for _,player in pairs(game.players) do player.force=force end
    storage.force=force;storage.surface=surface
    pure_tests()
    for mode=1,5 do
        local x=(mode-3)*160+16
        local entity=surface.create_entity{name="ei-phased-array-radar",position={x,16},force=force,raise_built=true}
        local settings=preferences(mode,mode==2 and 2 or mode==3 and 3 or 1)
        call("settings",entity,settings)
        storage.radars[mode]=entity
        surface.create_entity{name="substation",position={x+4,16},force=force}
        surface.create_entity{name="ei-radar-qc-source",position={x+4,20},force=force}
        local target=surface.create_entity{name="gun-turret",position={x,mode==3 and -32 or -8},force="enemy"}
        storage.targets[mode]=target
    end
    local dry=surface.create_entity{name="ei-sweeping-radar",position={400,16},force=force,quality="legendary",raise_built=true}
    storage.dry=dry
    call("settings",dry,preferences(1))
    local watch=surface.create_entity{name="ei-sweeping-radar",position={1000,16},force=force,raise_built=true}
    local settings=preferences(1);settings.policy=0
    call("settings",watch,settings);storage.watch=watch
    storage.watch_generated=call("snapshot").counters.generated
    local beam=surface.create_entity{name="ei-phased-array-radar",position={16,272},force=force,raise_built=true}
    local beam_settings=preferences(5,3);beam_settings.modes[5].radius=1
    call("settings",beam,beam_settings);storage.beam=beam;storage.beam_atomic=true;storage.beam_batches=0
    surface.create_entity{name="substation",position={20,272},force=force}
    surface.create_entity{name="ei-radar-qc-source",position={20,276},force=force}
    for _,y in ipairs{240,272} do for i=1,128 do
        local target=surface.create_entity{name="gun-turret",position={16,y},force="enemy"};target.active=false
    end end
end
script.on_init(function() storage.pending_setup=true end)
script.on_configuration_changed(function() if not storage.started then storage.pending_setup=true end end)
script.on_event(defines.events.on_tick,function(event)
    current_tick=event.tick
    if storage.pending_setup then storage.pending_setup=nil;setup(event.tick);return end
    local t=event.tick-storage.started
    local fleet=call("snapshot")
    local last=fleet.last
    for key,limit in pairs{control=4,visual=4,geometry=64,chart=2,query=2,snapshot=258,aggregate=64,maintenance=64,publish=2,generation=1} do
        local value=last[key] or 0
        storage.maximum[key]=math.max(storage.maximum[key] or 0,value)
        assert(value<=limit,"stage exceeded: "..key)
    end
    assert(fleet.jobs<=32,"job cap")
    if t>=60 and t<600 then call("short_pulse_probe",storage.radars[4]) end
    if t>600 and t<630 then
        local pulse=call("snapshot",storage.radars[4])
        storage.pulse_ack=storage.pulse_ack or (pulse.output and pulse.output[2]==1)
    end
    if t<600 then
        local beam=call("snapshot",storage.beam)
        if beam.batch and beam.observations>0 then
            storage.beam_batches=storage.beam_batches+1
            storage.beam_atomic=storage.beam_atomic and beam.report_valid and beam.report_count<=128
            local previous=storage.previous_beam
            if previous and previous.observations==beam.observations then
                storage.beam_atomic=storage.beam_atomic and previous.report_count==beam.report_count
                    and previous.report_published==beam.report_published
            end
        end
        storage.previous_beam=beam
    end
    -- Watch is deliberately away from the powered network but given energy.
    if t%10==0 then call("fill",storage.watch) end
    if storage.cold and storage.cold.valid and t%10==0 then call("fill",storage.cold) end
    if t==60 then
        check("empty-new-buffer",call("snapshot",storage.dry).energy==0)
        local quality=call("snapshot",storage.dry)
        check("quality-balanced-bonuses",quality.maximum==28 and quality.rate==6 and math.abs(quality.cost-4480000)<0.001)
        check("pulse-armed-no-work",call("snapshot",storage.radars[4]).observations==0)
        call("trigger",storage.radars[4])
        local player=game.get_player(1)
        if player then
            player.teleport({16,100},storage.surface)
            call("open",player.index,storage.radars[3])
            check("gui-opens",player.gui.screen.ei_sweeping_radar_gui~=nil)
            local function action(element,name)
                if element.tags.action==name then return element end
                for _,child in ipairs(element.children) do local found=action(child,name);if found then return found end end
            end
            local controls=call("gui_controls",player.index)
            controls.fields.speed.value.text="17"
            controls.center.text="0";controls.width.text="90"
            call("gui_event",{player_index=player.index,element=action(player.gui.screen.ei_sweeping_radar_gui,"arc"),name=defines.events.on_gui_click})
            call("gui_event",{player_index=player.index,element=action(player.gui.screen.ei_sweeping_radar_gui,"apply"),name=defines.events.on_gui_click})
            local saved=call("snapshot",storage.radars[3]).settings
            check("gui-apply-arc",saved.speed==17 and saved.modes[3].start==315 and saved.modes[3].stop==45)
            controls=call("gui_controls",player.index);controls.fields.mode.value.selected_index=2
            call("gui_event",{player_index=player.index,element=controls.fields.mode.value,name=defines.events.on_gui_selection_state_changed})
            saved=call("snapshot",storage.radars[3]).settings
            check("gui-mode-preserves-geometry",saved.mode==2 and saved.modes[3].start==315 and saved.modes[3].stop==45)
            call("close",player.index)
            call("settings",storage.radars[3],preferences(3,3))
        end
    elseif t==600 then
        check("current-beam-atomic",storage.beam_atomic and storage.beam_batches>0,storage.beam_batches)
        for mode=1,5 do
            local s=call("snapshot",storage.radars[mode])
            check("mode-progress-"..mode,s.observations>0 and s.passes>0,{observations=s.observations,passes=s.passes,status=s.status})
            if mode==2 then check("completed-pass-report",s.report_valid and s.report_count==1,s.report_count) end
        end
        check("pulse-exactly-one-pass",call("snapshot",storage.radars[4]).passes==1)
        check("watch-no-generation",fleet.counters.generated==storage.watch_generated,fleet.counters.generated)
        local radar=storage.radars[1]
        storage.pause_observations=call("snapshot",radar).observations
        local settings=preferences(1);settings.speed=0;call("settings",radar,settings)
        for _,target in pairs(storage.targets) do if target.valid then target.destroy() end end
    elseif t==630 then
        check("short-pulse-publication-ack",storage.pulse_ack==true)
    elseif t==635 then
        local settings=preferences(4);settings.trigger=1
        call("settings",storage.radars[4],settings)
    elseif t==650 then
        storage.passes_before_churn=call("snapshot",storage.radars[4]).passes
        local settings=preferences(4);settings.trigger=1;settings.modes[4].stop=60
        call("settings",storage.radars[4],settings)
    elseif t==720 then
        local pulse=call("snapshot",storage.radars[4])
        check("held-trigger-no-rearm",pulse.passes==storage.passes_before_churn and pulse.status=="armed")
        local s=call("snapshot",storage.radars[1])
        check("zero-speed-pauses",s.observations<=storage.pause_observations+1 and s.output[3]==0)
        call("settings",storage.radars[1],preferences(1))
        storage.resume_observations=s.observations
    elseif t==1000 then
        local s=call("snapshot",storage.radars[1])
        check("resume-progress",s.observations>storage.resume_observations)
        check("recent-expiry",s.report_count==0 and s.report_valid,s.report_count)
        check("native-chart-executed",storage.force.is_chunk_charted(storage.surface,{0,-1}),{players=#storage.force.players})
        local original=storage.radars[2]
        storage.clone=original.clone{position={-144,160},surface=storage.surface,force=storage.force}
        local c=call("snapshot",storage.clone)
        check("clone-settings",c.settings.mode==2 and c.settings.contacts==2)
        check("clone-no-free-energy",c.energy==0,c.energy)
        local p=call("snapshot",original).power
        p.destroy();storage.helper_original=p
    elseif t==1030 then
        local s=call("snapshot",storage.radars[2])
        check("helper-repair",s.power.valid and s.power~=storage.helper_original)
        local entity=storage.clone
        local s2=call("snapshot",entity)
        storage.deleted_power=s2.power;storage.deleted_output=s2.output_entity
        entity.destroy{raise_destroy=true}
    elseif t==1100 then
        check("helper-teardown",not storage.deleted_power.valid and not storage.deleted_output.valid)
        local radar=storage.radars[1]
        local settings=preferences(5,3);call("settings",radar,settings)
        storage.dense={};storage.dense_peak=0;storage.dense_overflow=false
        for i=1,129 do
            local target=storage.surface.create_entity{name="gun-turret",position={radar.position.x,radar.position.y-24},force="enemy"}
            target.active=false;storage.dense[i]=target
        end
        local player=game.get_player(1)
        if player then
            player.clear_cursor();player.cursor_stack.set_stack{name="blueprint"}
            player.cursor_stack.set_blueprint_entities{{entity_number=1,name="ei-phased-array-radar",position={0,0}}}
            call("blueprint",1,storage.radars[2])
            local tags=player.cursor_stack.get_blueprint_entity_tag(1,config.tag)
            check("blueprint-tags",tags and tags.mode==2 and tags.contacts==2)
            local ghosts=player.cursor_stack.build_blueprint{surface=storage.surface,force=storage.force,position={16,200},force_build=true}
            for _,ghost in pairs(ghosts) do ghost.revive{raise_revive=true} end
            local built=storage.surface.find_entities_filtered{name="ei-phased-array-radar",position={16,200},radius=3}[1]
            check("blueprint-revive",built and call("snapshot",built).settings.mode==2)
            check("blueprint-no-energy",built and call("snapshot",built).energy==0)
            local base=storage.surface.create_entity{name="ei-sweeping-radar",position={40,200},force=storage.force,raise_built=true}
            call("settings",base,preferences(3));call("fill",base)
            player.teleport({40,196},storage.surface)
            player.clear_cursor();player.cursor_stack.set_stack{name="ei-phased-array-radar",count=1}
            local can_build=player.can_build_from_cursor{position=base.position}
            player.build_from_cursor{position=base.position}
            local upgraded=storage.surface.find_entities_filtered{name="ei-phased-array-radar",position={40,200},radius=1}[1]
            check("player-upgrade-settings",upgraded and call("snapshot",upgraded).settings.mode==3,{can_build=can_build,built=upgraded~=nil,settings=upgraded and call("snapshot",upgraded).settings})
            check("player-upgrade-energy-cap",upgraded and call("snapshot",upgraded).energy==10000000)
            local robot_base=storage.surface.create_entity{name="ei-sweeping-radar",position={64,200},force=storage.force,raise_built=true}
            call("settings",robot_base,preferences(2));call("fill",robot_base)
            local robot_upgraded=call("robot_upgrade",robot_base)
            check("robot-upgrade-transaction",call("snapshot",robot_upgraded).settings.mode==2 and call("snapshot",robot_upgraded).energy==10000000)
        end
    elseif t==1350 then
        check("query-overflow-sentinel",storage.dense_peak==128 and storage.dense_overflow,{peak=storage.dense_peak,overflow=storage.dense_overflow})
        for _,entity in pairs(storage.dense) do entity.destroy() end
        storage.dense=nil
        local radar=storage.radars[1]
        local settings=preferences(1)
        settings.overrides.speed={enabled=true,signal={type="virtual",name="signal-S"}}
        settings.overrides.run={enabled=true,signal={type="virtual",name="signal-G"}}
        call("settings",radar,settings)
        storage.input=storage.surface.create_entity{name="constant-combinator",position={radar.position.x+3,radar.position.y},force=storage.force}
        storage.input.get_wire_connector(defines.wire_connector_id.circuit_red,true).connect_to(radar.get_wire_connector(defines.wire_connector_id.circuit_red,true),false,defines.wire_origin.script)
        local section=storage.input.get_or_create_control_behavior().get_section(1)
        section.set_slot(1,{value={type="virtual",name="signal-G",quality="normal"},min=2})
        storage.circuit_before=call("snapshot",radar).observations
    elseif t==1400 then
        local s=call("snapshot",storage.radars[1])
        check("zero-circuit-value",s.effective.speed==0 and s.effective.run==2 and s.output[3]==0)
        storage.input.get_control_behavior().get_section(1).set_slot(2,{value={type="virtual",name="signal-S",quality="normal"},min=100})
    elseif t==1500 then
        check("positive-run-not-boolean",call("snapshot",storage.radars[1]).observations>storage.circuit_before)
        local settings=preferences(1);settings.overrides.radius={enabled=true,signal={type="virtual",name="radar-qc-missing-signal"}}
        call("settings",storage.radars[1],settings)
    elseif t==1540 then
        check("removed-signal-safe",call("snapshot",storage.radars[1]).status=="invalid")
        call("settings",storage.radars[1],preferences(1))
        for i=1,32 do
            local entity=storage.surface.create_entity{name="ei-sweeping-radar",position={-300+i*5,300},force=storage.force,raise_built=true}
            call("settings",entity,preferences(1))
        end
        storage.starvation_before=call("snapshot",storage.radars[1]).observations
    elseif t==1800 then
        check("unpowered-fleet-no-starvation",call("snapshot",storage.radars[1]).observations>storage.starvation_before and fleet.jobs<32,fleet.jobs)
        storage.epoch_before=call("pending",storage.radars[1]).epoch
        storage.force.technologies["automation"].researched=false
        storage.force.technologies["automation"].researched=true
    elseif t==1860 then
        check("unrelated-research-preserves-progress",call("pending",storage.radars[1]).epoch==storage.epoch_before)
        storage.hostile=game.create_force("radar-qc-hostile")
        local radar=storage.radars[1]
        storage.diplomacy_target=storage.surface.create_entity{name="gun-turret",position={radar.position.x,radar.position.y-8},force=storage.hostile}
        storage.diplomacy_target.active=false
    elseif t==2100 then
        check("modded-hostile-detected",call("snapshot",storage.radars[1]).report_count==1)
        storage.hostile.set_friend(storage.force,true)
    elseif t==2240 then
        check("asymmetric-friend-excluded",call("snapshot",storage.radars[1]).report_count==0)
        storage.hostile.set_friend(storage.force,false)
    elseif t==2400 then
        check("hostility-restored",call("snapshot",storage.radars[1]).report_count==1)
        storage.force.set_cease_fire(storage.hostile,true)
    elseif t==2540 then
        check("cease-fire-excluded",call("snapshot",storage.radars[1]).report_count==0)
        storage.force.set_cease_fire(storage.hostile,false)
        game.merge_forces(storage.force,game.forces.player)
    elseif t==2720 then
        local radar=storage.radars[1]
        local s=call("snapshot",radar)
        check("force-merge-helper-ownership",radar.force==game.forces.player and s.power.force==radar.force and s.output_entity.force==radar.force)
        local p={x=radar.position.x+200,y=radar.position.y+200}
        check("same-surface-teleport",radar.teleport(p,nil,true))
        storage.surface.create_entity{name="substation",position={p.x+4,p.y},force=radar.force}
        storage.surface.create_entity{name="ei-radar-qc-source",position={p.x+4,p.y+4},force=radar.force}
    elseif t==2780 then
        local radar=storage.radars[1]
        local s=call("snapshot",radar)
        check("teleport-helpers-and-report",s.power.position.x==radar.position.x and s.power.position.y==radar.position.y and s.report_count==0)
        s.output_entity.destroy();storage.old_output=s.output_entity
    elseif t==2830 then
        local radar=storage.radars[1]
        local s=call("snapshot",radar)
        check("output-helper-repaired",s.output_entity.valid and s.output_entity~=storage.old_output and radar.get_signal({type="virtual",name="ei-radar-ready"},defines.wire_connector_id.circuit_green)==1)
        local player=game.get_player(1)
        if player then
            player.teleport(radar.position,radar.surface);call("open",1,radar)
            local function button(element)
                if element.tags.action=="apply" then return element end
                for _,child in ipairs(element.children) do local found=button(child);if found then return found end end
            end
            local apply=button(player.gui.screen.ei_sweeping_radar_gui)
            player.force=storage.hostile
            call("gui_event",{player_index=1,element=apply,name=defines.events.on_gui_click})
            check("stale-gui-closes",not player.gui.screen.ei_sweeping_radar_gui)
            player.force=game.forces.player
        end
        storage.temporary=game.create_surface("radar-delete")
        local entity=storage.temporary.create_entity{name="ei-sweeping-radar",position={0,0},force="player",raise_built=true}
        storage.orphan=call("snapshot",entity).power
        game.delete_surface(storage.temporary)
    elseif t==2840 then
        local radar=storage.radars[1]
        storage.teleport_epoch=call("snapshot",radar).epoch
        assert(radar.teleport({radar.position.x+32,radar.position.y+32}))
    elseif t==2900 then
        local radar=storage.radars[1]
        local moved=call("snapshot",radar)
        check("unraised-teleport-recovers",moved.epoch>storage.teleport_epoch
            and moved.geometry.position.x==radar.position.x and moved.power.position.x==radar.position.x)
        check("surface-delete-teardown",not storage.orphan.valid)
        local surface=assert(game.planets.aquilo).create_surface()
        surface.request_to_generate_chunks({16,16},1);surface.force_generate_chunk_requests()
        storage.cold=surface.create_entity{name="ei-sweeping-radar",position={16,16},force="player",raise_built=true}
        check("native-freezable",storage.cold.is_freezable)
    elseif t==3200 then
        local s=call("snapshot",storage.cold)
        check("frozen-pauses",storage.cold.frozen and s.observations==0
            and storage.cold.get_signal({type="virtual",name="ei-radar-valid"},defines.wire_connector_id.circuit_green)==0,s.status)
        local heater=storage.cold.surface.create_entity{name="heat-interface",position=storage.cold.position,force="player"}
        heater.set_heat_setting{mode="exactly",temperature=200}
    elseif t==3500 then
        local s=call("snapshot",storage.cold)
        check("thaw-resumes",not storage.cold.frozen and s.observations>0,s.status)
        local pass=true
        for _,test in ipairs(storage.tests) do if not test.pass then pass=false end end
        helpers.write_file("radar-qc.json",helpers.table_to_json({all_pass=pass,tests=storage.tests,stage_maximum=storage.maximum}),false)
    end
    if storage.dense then
        local s=call("snapshot",storage.radars[1])
        storage.dense_peak=math.max(storage.dense_peak,s.report_count)
        storage.dense_overflow=storage.dense_overflow or s.report_incomplete
    end
end)
