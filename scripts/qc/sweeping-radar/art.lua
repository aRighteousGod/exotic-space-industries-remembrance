-- Finite engine-backed art/lifecycle assertions; no performance benchmark.
local config=require("__exotic-space-industries-remembrance__/lib/sweeping-radar-config")
local fixture=require("test-config").fixture
local loaded=false
local current_tick
local function call(name,...) return remote.call("esir_radar_qc",name,current_tick,...) end
local function check(name,pass)
    storage.tests[#storage.tests+1]={name=name,pass=not not pass}
end
local function report()
    local pass=true
    for _,test in ipairs(storage.tests) do if not test.pass then pass=false end end
    helpers.write_file("radar-qc.json",helpers.table_to_json({all_pass=pass,tests=storage.tests}),false)
end
local function settings(radar,mode,run)
    local s=config.defaults();s.policy=1;s.mode=mode or 1;s.run=run or 1
    for _,g in pairs(s.modes) do g.radius=1;g.near=0 end
    call("settings",radar,s)
end
local function shot(name,night)
    if fixture~="art-visual" then return end
    local player=storage.player
    storage.surface.daytime=night and 0.5 or 0
    game.take_screenshot{player=player,path="radar-art/"..name..".png",show_gui=false,
        position={2,-1},surface=storage.surface,resolution={1200,800},zoom=2}
end
script.on_init(function() storage.pending=true end)
script.on_load(function() loaded=true end)
script.on_event(defines.events.on_tick,function(event)
    current_tick=event.tick
    if storage.pending then
        storage.pending=nil;storage.started=event.tick;storage.tests={}
        local surface=game.create_surface("radar-art",{autoplace_settings={entity={treat_missing_as_default=false}}})
        surface.request_to_generate_chunks({0,0},3);surface.force_generate_chunk_requests()
        storage.surface=surface;surface.daytime=0;surface.freeze_daytime=true
        game.forces.player.chart(surface,{{-96,-96},{96,96}})
        local a=surface.create_entity{name=config.names[1],position={-2,0},force="player",raise_built=true}
        local b=surface.create_entity{name=config.names[2],position={4,0},force="player",raise_built=true}
        storage.a=a;storage.b=b;settings(a);settings(b)
        surface.create_entity{name="substation",position={1,6},force="player"}
        storage.source=surface.create_entity{name="ei-radar-qc-source",position={5,6},force="player"}
        storage.ghost=surface.create_entity{name="entity-ghost",inner_name=config.names[2],position={10,0},force="player",raise_built=true}
        if fixture=="art-visual" then
            storage.player=assert(game.connected_players[1]);storage.player.set_controller{type=defines.controllers.god}
            storage.player.teleport({1,2},surface)
            for i,label in ipairs{"N","E","S","W"} do
                local a=(i-1)*math.pi/2
                rendering.draw_text{text=label,target={-2+3*math.sin(a),-3*math.cos(a)},surface=surface,color={1,1,1},scale=1}
            end
        end
        return
    end
    if loaded and storage.saved then
        loaded=false
        local v=call("visual",storage.b)
        check("reload-preserves-render-object",v.body and v.body.valid and v.body.id==storage.saved.id)
        check("reload-preserves-pose",v.frame==storage.saved.frame)
        check("reload-keeps-frozen-animation",v.body.animation_speed==0)
        report();storage.done=true;return
    end
    if storage.done then return end
    local t=event.tick-storage.started
    local a,b=storage.a,storage.b
    local limits=call("snapshot").last
    assert((limits.visual or 0)<=4 and limits.control<=4,"art exceeded existing control allowance")
    if t==30 then
        local va,vb=call("visual",a),call("visual",b)
        check("body-created-both",va.body and va.body.valid and vb.body and vb.body.valid)
        check("glow-only-advanced",not va.glow and vb.glow and vb.glow.valid and vb.glow.visible)
        local ghost=call("ghost_visual",storage.ghost)
        check("ghost-preview",ghost and ghost.object.valid)
        storage.ghost_object=ghost and ghost.object
        settings(a,1,0);settings(b,1,0)
    elseif t>=50 and t<306 then
        local heading=(t-50)*360/256
        for _,entity in ipairs{a,b} do
            call("visual_probe",entity,heading,false)
            local v=call("visual",entity)
            local expected=((t-50)+config.art[entity.name].north)%256
            check(entity.name.."-frame-"..(t-50),v.frame==expected and v.offset==expected%128
                and v.animation==entity.name.."-body-"..(math.floor(expected/128)+1)
                and v.body.animation_speed==0 and (not v.glow or v.glow.animation_offset==v.offset))
        end
        if (t-50)%64==0 then shot("cardinal-"..(t-50)/64) end
    elseif t==310 then
        call("visual_probe",b,90,false)
        call("visual_probe",b,180,false,20,10)
        local v=call("visual",b)
        check("clockwise-halfway",math.abs(v.heading-135)<0.001)
        call("visual_probe",b,90,true,20,10)
        check("counterclockwise-halfway",math.abs(call("visual",b).heading-112.5)<0.001)
        call("visual_probe",b,350,true)
        call("visual_probe",b,10,false,20,10)
        check("cross-north-clockwise",math.abs(call("visual",b).heading)<0.001)
        call("visual_probe",b,350,true,20,10)
        check("cross-north-counterclockwise",math.abs(call("visual",b).heading-355)<0.001)
        call("visual_probe",b,180,false,20,10000)
        check("no-animation-overshoot",call("visual",b).heading==180)
        settings(a,1,0);settings(b,1,0)
    elseif t==330 then
        storage.paused_frame=call("visual",b).frame
        check("paused-powered-glow",call("visual",b).glow.visible)
        shot("powered-night",true)
    elseif t==345 then
        check("pause-holds-pose",call("visual",b).frame==storage.paused_frame)
        storage.source.destroy()
        for _,r in ipairs{a,b} do call("snapshot",r).power.energy=0 end
    elseif t==365 then
        check("outage-holds-pose",call("visual",b).frame==storage.paused_frame)
        check("outage-glow-off",not call("visual",b).glow.visible)
        shot("unpowered-night",true)
        storage.source=storage.surface.create_entity{name="ei-radar-qc-source",position={5,6},force="player"}
    elseif t==385 then
        check("recovery-glow",call("visual",b).glow.visible)
        check("recovery-no-catchup",call("visual",b).frame==storage.paused_frame)
        local v=call("visual",b);storage.old_body=v.body;storage.old_glow=v.glow
        v.body.destroy();v.glow.destroy()
    elseif t==400 then
        check("bounded-render-repair",call("visual",b).body.valid and call("visual",b).glow.valid)
        local surface=game.planets.aquilo.create_surface()
        surface.request_to_generate_chunks({16,16},1);surface.force_generate_chunk_requests()
        storage.cold=surface.create_entity{name=config.names[2],position={16,16},force="player",raise_built=true}
    elseif t==415 then
        storage.ghost.destroy()
        storage.old_body=call("visual",b).body
        storage.b=call("robot_upgrade",b,config.names[2],"legendary")
        settings(storage.b,1,0)
    elseif t==440 then
        check("upgrade-teardown",not storage.old_body.valid)
        check("upgrade-recreates-art",call("visual",b).body.valid and b.quality.name=="legendary")
        check("ghost-teardown",not storage.ghost_object.valid)
        storage.clone=b.clone{position={16,0},surface=storage.surface,force=b.force}
        local other=game.create_surface("radar-art-move",{})
        storage.old_body=call("visual",b).body
        storage.cross=b.clone{position={0,0},surface=other,force=b.force}
        b.teleport({4,2},nil,true)
    elseif t==465 then
        local v=call("visual",b)
        local moved=call("visual",storage.cross)
        check("cross-surface-clone-art",moved.body and moved.body.valid and moved.body.surface==storage.cross.surface)
        check("same-surface-teleport-follows-entity",v.body==storage.old_body and v.body.target.entity==b)
        storage.removed=moved.body
        game.delete_surface(storage.cross.surface)
        local copy=call("visual",storage.clone)
        check("clone-has-independent-art",copy.body and copy.body.valid and copy.body~=v.body)
        storage.clone.destroy{raise_destroy=true}
        check("clone-art-teardown",not copy.body.valid)
        b.teleport({4,0},nil,true)
        settings(a);settings(b)
        storage.before=call("snapshot",b).observations
    elseif t==480 then
        check("surface-deletion-clears-art",not storage.removed.valid)
    elseif t==690 then
        call("fill",storage.cold)
    elseif t==700 then
        check("native-frozen-glow-off",storage.cold.frozen and call("snapshot",storage.cold).energy>0
            and not call("visual",storage.cold).glow.visible)
        storage.cold.destroy{raise_destroy=true}
        local v=call("visual",b)
        local r=call("snapshot",b)
        log("ART QC scanning "..helpers.table_to_json({status=r.status,observations=r.observations,energy=r.energy,ready=r.ready,
            geometry=r.geometry and r.geometry.phase,visual_heading=v.heading,completed=v.completed_tick,rate=r.rate,settings=r.settings,effective=r.effective}))
        check("real-observations-drive-animation",v.completed_tick and call("snapshot",b).observations>storage.before)
        check("native-scanning-still-disabled",a.disabled_by_script and b.disabled_by_script)
        settings(b,5)
        local s=config.defaults();s.policy=1;s.mode=5;s.modes[5].radius=1;s.modes[5].bearing=90
        call("settings",b,s)
    elseif t==850 then
        local v=call("visual",b)
        local r=call("snapshot",b)
        log("ART QC fixed "..helpers.table_to_json({status=r.status,observations=r.observations,energy=r.energy,ready=r.ready,
            geometry=r.geometry and r.geometry.phase,visual_heading=v.heading,completed=v.completed_tick,heading=r.heading,settings=r.settings,effective=r.effective}))
        check("fixed-bearing-settles",math.abs(v.heading-90)<0.001)
        settings(b,1,0)
    elseif t==880 then
        shot("complete")
        if fixture=="art-visual" then
            local frame=storage.player.gui.screen.add{type="frame",caption="Radar icons",direction="horizontal"}
            frame.location={20,20}
            for _,name in ipairs(config.names) do
                frame.add{type="sprite-button",sprite="item/"..name,tooltip={"entity-name."..name}}
            end
            game.take_screenshot{player=storage.player,path="radar-art/icons.png",show_gui=true,
                position={2,-1},surface=storage.surface,resolution=storage.player.display_resolution,zoom=2}
        end
        if fixture=="art-save" then
            local v=call("visual",b)
            storage.saved={id=v.body.id,frame=v.frame}
            report();game.server_save("radar-transition")
        else
            local old=call("visual",a).body
            a.destroy{raise_destroy=true}
            check("mining-destruction-teardown",not old.valid)
            report();storage.done=true
        end
    end
end)
