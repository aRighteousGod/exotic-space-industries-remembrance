-- Actual player cursor, transformed blueprints, construction robots and reload.
local loaded=false
local turret="ei-acidthrower-turret"
local red,green=defines.wire_connector_id.circuit_red,defines.wire_connector_id.circuit_green
local function surface(name)
    local s=game.create_surface(name,{width=256,height=256,autoplace_settings={entity={treat_missing_as_default=false},decorative={treat_missing_as_default=false}}})
    s.request_to_generate_chunks({0,0},3);s.force_generate_chunk_requests()
    for _,e in pairs(s.find_entities()) do e.destroy() end
    local tiles={};for x=-80,80 do for y=-80,80 do tiles[#tiles+1]={name="lab-dark-1",position={x,y}} end end
    s.set_tiles(tiles);s.freeze_daytime=true;s.daytime=0
    return s
end
local function verify(e)
    assert(e.valid and e.direction%2==0)
    local ports=e.get_fluid_box_pipe_connections(1);assert(#ports==2)
    for _,p in ipairs(ports) do assert(p.target and p.target.valid and p.target.name=="pipe") end
    for _,id in ipairs{red,green} do
        local c=e.get_wire_connector(id,false);assert(c and #c.real_connections==1,"Blueprint wire")
        assert(c.real_connections[1].target.owner.valid)
    end
    assert(e.get_control_behavior().read_ammo,"Blueprint circuit setting")
end
local function snapshot(e)
    local f={};for i=1,e.fluids_count do f[i]=e.get_fluid(i) or false end
    local wires={}
    for _,id in ipairs{red,green} do
        local edge=e.get_wire_connector(id,false).real_connections[1]
        wires[tostring(id)]={unit=edge.target.owner.unit_number,connector=edge.target.wire_connector_id}
    end
    return {direction=e.direction,position=e.position,quality=e.quality.name,health=e.health,fluid=f,wires=wires}
end
local function setup(player,tick)
    player.set_controller{type=defines.controllers.god};player.cheat_mode=true
    local root={start=tick,entities={},placements={},transforms={},robot_events={}};storage.acid_player=root
    local s=surface("acid-player-source");player.teleport({0,30},s)
    for i=0,7 do
        player.cursor_stack.set_stack{name=turret,count=1}
        player.build_from_cursor{position={(i-3.5)*10,30},direction=i*2}
        local built=s.find_entities_filtered{name=turret,area={{(i-3.5)*10-2,28},{(i-3.5)*10+2,32}}}
        assert(#built==1 and built[1].direction==i*2,"Actual player placement")
        root.placements[#root.placements+1]={requested=i*2,actual=built[1].direction,position=built[1].position}
        local e=assert(s.create_entity{name=turret,position={(i-3.5)*10,0},direction=i*2,force="player",quality=i==7 and "rare" or "normal"})
        e.health=e.health-17
        for _,port in ipairs(e.get_fluid_box_pipe_connections(1)) do assert(s.create_entity{name="pipe",position=port.target_position,force="player"}) end
        local pole=assert(s.create_entity{name="medium-electric-pole",position={e.position.x+3,e.position.y+3},force="player"})
        for _,id in ipairs{red,green} do assert(e.get_wire_connector(id,true).connect_to(pole.get_wire_connector(id,true))) end
        e.get_or_create_control_behavior().read_ammo=true
        verify(e);root.entities[#root.entities+1]=e
        e.insert_fluid{name="sulfuric-acid",amount=100,temperature=25}
    end
    player.cursor_stack.set_stack{name="blueprint",count=1}
    player.cursor_stack.create_blueprint{surface=s,force=player.force,area={{-41,-5},{41,6}},include_entities=true}
    for _,e in ipairs(player.cursor_stack.get_blueprint_entities()) do
        if e.name==turret then player.cursor_stack.set_blueprint_entity_tag(e.entity_number,"acid-qc-direction",e.direction or 0) end
    end
    root.blueprint=player.cursor_stack.export_stack()
    for rotation=0,3 do for flip=0,3 do
        local dest=surface("acid-blueprint-"..rotation.."-"..flip);player.teleport({0,0},dest)
        player.build_from_cursor{position={0,0},direction=rotation*4,flip_horizontal=flip%2==1,flip_vertical=flip>=2}
        local ghosts=dest.find_entities_filtered{type="entity-ghost",ghost_name=turret}
        assert(#ghosts==8,"Blueprint eight turret ghosts")
        local directions={};local mapping={}
        for _,g in ipairs(ghosts) do
            directions[g.direction]=true
            local original=assert(g.tags["acid-qc-direction"])
            -- Native blueprint mirrors act in source coordinates before rotation.
            local expected=original
            if flip%2==1 then expected=(-expected)%16 end
            if flip>=2 then expected=(8-expected)%16 end
            expected=(expected+rotation*4)%16
            assert(g.direction==expected,"Individual transformed blueprint direction")
            mapping[#mapping+1]={original=original,actual=g.direction,expected=expected}
        end
        for d=0,14,2 do assert(directions[d],"Transformed heading absent") end
        for _,g in ipairs(dest.find_entities_filtered{type="entity-ghost"}) do
            local _,revived=g.revive{raise_revive=true};assert(revived and revived.valid)
        end
        for _,e in ipairs(dest.find_entities_filtered{name=turret}) do verify(e);root.entities[#root.entities+1]=e end
        root.transforms[#root.transforms+1]={rotation=rotation*4,horizontal=flip%2==1,vertical=flip>=2,turrets=8,mapping=mapping}
    end end
    local robot=surface("acid-robot-construction");root.robot_surface=robot;player.teleport({0,0},robot)
    player.build_from_cursor{position={0,0},direction=0}
    local port=assert(robot.create_entity{name="roboport",position={0,20},force="player"});root.port=port
    robot.create_entity{name="substation",position={6,20},force="player"}
    robot.create_entity{name="hidden-electric-energy-interface",position={6,20},force="player"}
    port.energy=port.electric_buffer_size
    port.get_inventory(defines.inventory.roboport_robot).insert{name="construction-robot",count=24}
    local chest=robot.create_entity{name="storage-chest",position={6,23},force="player"}.get_inventory(defines.inventory.chest)
    for _,item in ipairs{{name=turret,count=8},{name=turret,quality="rare",count=1},{name="pipe",count=32},{name="medium-electric-pole",count=16}} do chest.insert(item) end
    player.clear_cursor();game.speed=4
end
script.on_init(function()
    if remote.interfaces.freeplay then remote.call("freeplay","set_skip_intro",true);remote.call("freeplay","set_disable_crashsite",true) end
end)
script.on_load(function() loaded=true end)
script.on_event(defines.events.on_robot_built_entity,function(event)
    local root=storage.acid_player
    if root and event.entity.surface==root.robot_surface and event.entity.name==turret then
        assert(event.robot and event.robot.valid)
        root.robot_events[#root.robot_events+1]={tick=event.tick,direction=event.entity.direction,quality=event.entity.quality.name}
    end
end)
script.on_event(defines.events.on_tick,function(event)
    local player=game.get_player(1);if not player then return end
    if not storage.acid_player then setup(player,event.tick) end
    local root=storage.acid_player
    if loaded and root.finished then
        for i,e in ipairs(root.entities) do
            verify(e);local now=snapshot(e);local old=root.saved[i]
            assert(now.direction==old.direction and now.health==old.health and now.quality==old.quality)
            assert(now.position.x==old.position.x and now.position.y==old.position.y)
            assert(helpers.table_to_json(now.wires)==helpers.table_to_json(old.wires),"Saved wire targets changed")
            for j,f in ipairs(old.fluid) do if f then assert(now.fluid[j] and now.fluid[j].name==f.name and math.abs(now.fluid[j].amount-f.amount)<.0001 and now.fluid[j].temperature==f.temperature) end end
        end
        helpers.write_file("acid-eight-player-reload.json",helpers.table_to_json{passed=true,entities=#root.entities,circuits=true,quality=true},false)
        loaded=false;return
    end
    if root.finished then return end
    root.port.energy=root.port.electric_buffer_size
    local built=root.robot_surface.find_entities_filtered{name=turret}
    if #built==8 and #root.robot_surface.find_entities_filtered{type="entity-ghost"}==0 then
        assert(#root.robot_events==8)
        for _,e in ipairs(built) do verify(e);root.entities[#root.entities+1]=e end
        root.saved={};for _,e in ipairs(root.entities) do root.saved[#root.saved+1]=snapshot(e) end
        for i=1,8 do
            local e=root.entities[i]
            game.take_screenshot{surface=e.surface,position={e.position.x+.4,e.position.y+.2},resolution={640,640},zoom=3,
                path="acid-eight/circuits-"..i..".png",daytime=0,show_gui=false,force_render=true}
        end
        root.finished=true
        game.take_screenshot{surface=root.robot_surface,position={0,0},resolution={1600,500},zoom=.6,path="acid-eight/robot-built.png",daytime=0,show_gui=false,force_render=true}
        game.set_wait_for_screenshots_to_finish()
        helpers.write_file("acid-eight-player.json",helpers.table_to_json{passed=true,placements=root.placements,transforms=root.transforms,robot_events=root.robot_events,entities=#root.entities},false)
        game.auto_save("acid-eight-player")
    end
    assert(event.tick-root.start<3600,"Robot construction timeout")
end)
