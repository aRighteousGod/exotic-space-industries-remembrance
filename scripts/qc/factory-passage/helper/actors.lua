-- Native player, robot and platform lifecycle proof; no synthetic build events.
local M={}
local function helpers_on(surface)
    local count=0
    for _,entity in pairs(surface.find_entities_filtered{type="simple-entity-with-owner"}) do
        if entity.name:find("ei-factory-passage-joint-",1,true)==1 then count=count+1 end
    end
    return count
end
function M.event(event)
    local root=storage.actors
    local entity=event.entity or event.destination
    if not root or not entity or not entity.valid then return end
    root.events[event.name]=(root.events[event.name] or 0)+1
    for _,case in ipairs(root.cases) do
        if entity.surface==case.surface and entity.name=="pipe" then
            if event.name==defines.events.on_robot_built_entity then assert(event.robot and event.robot.valid);case.built_events=case.built_events+1 end
            if event.name==defines.events.on_space_platform_built_entity then assert(event.platform==case.platform);case.built_events=case.built_events+1 end
            if event.name==defines.events.on_robot_mined_entity or event.name==defines.events.on_space_platform_mined_entity then case.mined_events=case.mined_events+1 end
        end
    end
end
local function start(player,tick,check)
    player.set_controller{type=defines.controllers.god};player.cheat_mode=true
    local root={start=tick,events={},cases={}};storage.actors=root
    local force=player.force;force.unlock_quality("rare")
    local source=game.surfaces[storage.surface];player.teleport({0,0},source)
    for x=0,1 do
        player.cursor_stack.set_stack{name="pipe",count=1}
        player.build_from_cursor{position={x+0.5,0.5}}
    end
    root.player_pipes=source.find_entities_filtered{name="pipe"}
    check(#root.player_pipes==2 and root.events[defines.events.on_built_entity]==2,"actual player cursor construction")
    source.create_entity{name="pipe",position={60.5,0.5},force=force,raise_built=true}
    root.grounded_actor=source.create_entity{name="character",position={61,0.5},force=force}
    root.grounded_actor.get_inventory(defines.inventory.character_armor).insert{name="mech-armor",count=1}
    root.grounded_box=root.grounded_actor.bounding_box
    source.create_entity{name="pipe",position={61.5,0.5},force=force,raise_built=true}
    local flight=game.create_surface("passage-flight",{width=64,height=64})
    flight.request_to_generate_chunks({0,0},1);flight.force_generate_chunk_requests()
    for _,entity in pairs(flight.find_entities()) do entity.destroy() end
    local water={};for x=-10,10 do for y=-16,12 do water[#water+1]={name="water",position={x,y}} end end
    flight.set_tiles(water,true,false,false,false)
    for x=-8,8 do flight.create_entity{name="pipe",position={x,0},force=force,snap_to_grid=false,raise_built=true} end
    root.flight_surface=flight
    root.flight_actor=flight.create_entity{name="character",position={0.5,-12},force=force}
    root.flight_actor.get_inventory(defines.inventory.character_armor).insert{name="mech-armor",count=1}
    root.flight_samples={}
    player.cursor_stack.set_stack{name="blueprint",count=1}
    player.cursor_stack.create_blueprint{surface=source,force=force,area={{-1,-1},{3,2}},include_entities=true}
    root.blueprint=player.cursor_stack.export_stack()
    for _,kind in ipairs{"robot","platform"} do
        local s,inventory,platform,port
        if kind=="robot" then
            s=game.create_surface("passage-robot",{width=64,height=64})
            s.request_to_generate_chunks({0,0},1);s.force_generate_chunk_requests()
            for _,e in pairs(s.find_entities()) do e.destroy() end
            local tiles={};for x=-25,25 do for y=-25,25 do tiles[#tiles+1]={name="stone-path",position={x,y}} end end;s.set_tiles(tiles)
            port=s.create_entity{name="roboport",position={0,0},force=force}
            s.create_entity{name="substation",position={6,0},force=force}
            s.create_entity{name="hidden-electric-energy-interface",position={6,0},force=force}
            port.get_inventory(defines.inventory.roboport_robot).insert{name="construction-robot",count=8}
            inventory=s.create_entity{name="storage-chest",position={6,3},force=force}.get_inventory(defines.inventory.chest)
        else
            platform=force.create_space_platform{name="Passage QC",planet="nauvis",starter_pack="space-platform-starter-pack"}
            local hub=platform.apply_starter_pack(true);platform.paused=true;hub.request_missing_construction_materials=false
            s=platform.surface
            local tiles={};for x=-15,15 do for y=-15,15 do tiles[#tiles+1]={name="space-platform-foundation",position={x,y}} end end;s.set_tiles(tiles)
            inventory=hub.get_inventory(defines.inventory.hub_main)
            local probe=assert(s.create_entity{name="thruster",position={0,-10},force=force})
            local port=assert(probe.get_fluid_box_pipe_connections(1)[1])
            root.thruster_position=probe.position;root.thruster_surface=s
            root.thruster_pipe=s.create_entity{name="pipe",position=port.target_position,force=force,snap_to_grid=false,raise_built=true}
            probe.destroy()
        end
        inventory.insert{name="pipe",count=2};inventory.insert{name="pipe",quality="rare",count=2}
        local case={kind=kind,surface=s,platform=platform,port=port,built_events=0,mined_events=0,phase="building"}
        root.cases[#root.cases+1]=case
        for x=10,11 do s.create_entity{name="entity-ghost",inner_name="pipe",position={x+0.5,0.5},force=force} end
    end
    player.clear_cursor();game.speed=4
end
function M.tick(event,check,receipt,status,refresh)
    local player=game.get_player(1);if not player then return end
    if not storage.actors then start(player,event.tick,check) end
    local root=storage.actors;if root.done then return end
    local age=event.tick-root.start
    if age==10 then
        local source=game.surfaces[storage.surface]
        check(helpers_on(source)==1,"player build activates one joint")
        check(status().pending>0,"grounded mech armor defers occupied helper")
        root.grounded_actor.walking_state={walking=true,direction=defines.direction.north}
        for _,helper in pairs(root.flight_surface.find_entities_filtered{area={{0.4,-0.1},{0.6,0.1}},type="simple-entity-with-owner"}) do
            if helper.name:find("ei-factory-passage-joint-",1,true)==1 then root.flight_helper=helper end
        end
        check(root.flight_helper and root.flight_helper.valid,"flight crossing has an active helper")
        player.cursor_stack.set_stack{name="blueprint",count=1}
        player.cursor_stack.create_blueprint{surface=source,force=player.force,area={{-1,-1},{3,2}},include_entities=true}
        local entries=player.cursor_stack.get_blueprint_entities()
        check(#entries==2,"active collision helpers excluded from blueprint")
        player.clear_cursor()
        root.clone=root.player_pipes[1].clone{position={30.5,0.5},surface=source,force="player"}
        source.create_entity{name="pipe",position={31.5,0.5},force="player",raise_built=true}
        check(player.mine_entity(root.player_pipes[1],true),"native player mining")
        root.player_pipes[2].die()
        root.machine=source.create_entity{name="chemical-plant",position={10.5,10.5},force="player",raise_built=true}
        root.machine.set_recipe("ei-passage-qc-fluid-recipe")
        local ports=root.machine.get_fluid_box_pipe_connections(1)
        root.machine_ports=#ports
        for _,port in ipairs(ports) do source.create_entity{name="pipe",position=port.target_position,force="player",raise_built=true} end
        refresh(root.machine)
    elseif age==20 then
        check(root.clone and root.clone.valid and root.events[defines.events.on_entity_cloned]==1,"native connected pipe cloning")
        local source=game.surfaces[storage.surface]
        check(root.grounded_actor.position.y< -0.5,"grounded mech armor leaves constructed joint",{position=root.grounded_actor.position,box=root.grounded_box})
        root.grounded_actor.walking_state={walking=false,direction=defines.direction.north}
        check(helpers_on(source)==2+root.machine_ports,"connected clone and machine ports each own one joint",{actual=helpers_on(source),expected=2+root.machine_ports})
        for _,helper in pairs(source.find_entities_filtered{type="simple-entity-with-owner"}) do
            if helper.name:find("ei-factory-passage-joint-",1,true)==1 then
                local cloned=helper.clone{position={40,0},surface=source,force="player"}
                check(not cloned or not cloned.valid,"native helper clone is discarded")
                break
            end
        end
        check(root.events[defines.events.on_player_mined_entity]==1 and root.events[defines.events.on_entity_died]==1,"native mining and death events")
        check(root.machine.rotate{by_player=player},"native player rotation")
        check(root.machine.flip{horizontal=true,by_player=player},"native player flipping")
        root.thruster=root.thruster_surface.create_entity{name="thruster",position=root.thruster_position,force="player",raise_built=true}
    elseif age==30 then
        local position=root.thruster_pipe.position
        local found=false
        for _,helper in pairs(root.thruster_surface.find_entities_filtered{area={{position.x-0.6,position.y-0.6},{position.x+0.6,position.y+0.6}},type="simple-entity-with-owner"}) do
            if helper.name:find("ei-factory-passage-joint-",1,true)==1 then found=true end
        end
        check(found,"new stationary fluid receiver reconciles existing pipe")
        root.thruster.destroy{raise_destroy=true};root.thruster_pipe.destroy{raise_destroy=true}
        root.grounded_actor.destroy()
        check(root.events[defines.events.on_player_rotated_entity]==1 and root.events[defines.events.on_player_flipped_entity]==1,"rotation and flip dispatcher events")
        root.machine.teleport({20.5,10.5},nil,true)
        root.machine.destroy{raise_destroy=true}
        for _,pipe in pairs(game.surfaces[storage.surface].find_entities_filtered{name="pipe"}) do pipe.destroy{raise_destroy=true} end
        root.temporary=game.create_surface("passage-clear",{width=32,height=32})
        for x=0,1 do root.temporary.create_entity{name="pipe",position={x,0},force="player",raise_built=true} end
    elseif age==40 then
        check(helpers_on(root.temporary)==1,"surface clear starts with owned joint")
        root.temporary.clear(true)
    elseif age==50 then
        check(helpers_on(root.temporary)==0,"native surface clear removes helpers")
        game.delete_surface(root.temporary)
    end
    if not root.flight_done then
        local actor=root.flight_actor
        actor.walking_state={walking=true,direction=defines.direction.south}
        if math.abs(actor.position.y)<1 then root.flight_samples[#root.flight_samples+1]={tick=event.tick,position=actor.position,flying=actor.is_flying,height=actor.flight_height} end
        if actor.position.y>1 then
            check(actor.is_flying and actor.flight_height>0 and root.flight_helper.valid,"native mech flight crosses active joint helper",root.flight_samples)
            root.flight_done=true;root.flight_finished=event.tick
            actor.destroy();game.delete_surface(root.flight_surface)
        end
    end
    local done=age>55 and root.flight_done and event.tick>root.flight_finished+3
    for _,case in ipairs(root.cases) do
        if case.port then case.port.energy=case.port.electric_buffer_size end
        local pipes=case.surface.find_entities_filtered{name="pipe"}
        if case.phase=="building" and #pipes==2 and case.built_events==2 then
            case.ready=case.ready or event.tick
            if event.tick>case.ready+3 then
                check(helpers_on(case.surface)==1,case.kind.." construction reconciles one joint")
                for _,pipe in ipairs(pipes) do check(pipe.order_upgrade{target={name="pipe",quality="rare"},force=player.force},case.kind.." order quality upgrade") end
                case.phase="upgrading"
            end
        elseif case.phase=="upgrading" and #pipes==2 and pipes[1].quality.name=="rare" and pipes[2].quality.name=="rare" and case.built_events==4 then
            case.upgraded=case.upgraded or event.tick
            if event.tick>case.upgraded+3 then
                check(helpers_on(case.surface)==1,case.kind.." upgrade has one joint without duplicate")
                for _,pipe in ipairs(pipes) do check(pipe.order_deconstruction(player.force),case.kind.." order deconstruction") end
                case.phase="mining"
            end
        elseif case.phase=="mining" and #pipes==0 and case.mined_events>=2 then
            case.removed=case.removed or event.tick
            if event.tick>case.removed+3 then check(helpers_on(case.surface)==0,case.kind.." removal cleans helpers");case.phase="done" end
        end
        done=done and case.phase=="done"
    end
    if done then
        local now=status();check(now.helpers==0 and now.dirty==0 and now.pending==0,"all actor lifecycle helpers and pending work cleaned")
        check(now.counters.unsupported==0,"actor geometry supported")
        root.done=true;receipt("actors",{events=root.events,elapsed_ticks=age,flight=root.flight_samples,grounded_armor_box=root.grounded_box})
    end
    assert(age<3600,"Native actor lifecycle timeout")
end
return M
