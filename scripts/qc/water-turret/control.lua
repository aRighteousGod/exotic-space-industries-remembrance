local config=require("test-config")
local muzzle=config.muzzle and require("muzzle")
local visual=config.visual and require("visual")
local run_started
local function check(name,pass,detail)
    storage.results[name]={pass=pass==true,detail=detail}
end
local function report()
    local pass=true
    for _,result in pairs(storage.results) do if not result.pass then pass=false end end
    helpers.write_file("water-qc.json",helpers.table_to_json{all_pass=pass,cases=storage.results},false)
end
local function call(name,...) return remote.call("ei-water-qc",name,...) end
local function rec(entity) return call("record",entity) end
local function fire(surface,position,name)
    return surface.create_entity{name=name or "ei-oil-fire-flame",position=position,force="neutral"}
end
local function setup()
    storage.results={};storage.started=game.tick
    local surface=game.create_surface("water-qc",{width=1024,height=512,autoplace_controls={},autoplace_settings={entity={treat_missing_as_default=false}}})
    surface.request_to_generate_chunks({0,0},10);surface.force_generate_chunk_requests()
    local tiles={}
    for x=-480,480 do for y=-150,150 do tiles[#tiles+1]={name="lab-dark-1",position={x,y}} end end
    surface.set_tiles(tiles)
    for _,entity in pairs(surface.find_entities_filtered{type={"unit","unit-spawner","turret","tree"}}) do entity.destroy() end
    storage.surface=surface
    if config.baseline then
        local force=game.forces.player
        force.technologies.extinguisher.researched=true
        local fresh=game.create_force("water-qc-unresearched")
        storage.legacy={}
        local s=storage.legacy
        s.character=surface.create_entity{name="character",position={0,0},force=force}
        s.character.get_inventory(defines.inventory.character_guns)[1].set_stack{name="extinguisher",quality="rare"}
        s.character.get_inventory(defines.inventory.character_ammo)[1].set_stack{name="extinguisher-ammo",count=1,ammo=37,quality="rare"}
        s.chest=surface.create_entity{name="steel-chest",position={4,0},force=force}
        local inv=s.chest.get_inventory(defines.inventory.chest)
        inv[1].set_stack{name="extinguisher",count=3,quality="uncommon"}
        inv[2].set_stack{name="extinguisher-ammo",count=4,quality="epic"};inv[2].ammo=37
        s.loose=surface.create_entity{name="item-on-ground",position={8,0},stack={name="extinguisher",count=1,quality="rare"}}
        s.assembler=surface.create_entity{name="assembling-machine-2",position={12,0},force=force}
        s.assembler.set_recipe("extinguisher")
        s.chem=surface.create_entity{name="chemical-plant",position={18,0},force=force}
        s.chem.set_recipe("extinguisher-ammo")
        s.marker=surface.create_entity{name="extinguisher-remnants",position={30,0},force=force}
        check("baseline-ready",s.character.valid and not fresh.technologies.extinguisher.researched)
        return
    end
    storage.cases={};storage.powered={}
    local function turret(name,x,y,mode,water,powered,quality)
        local entity=surface.create_entity{name="ei-water-turret",position={x+0.5,y+0.5},force="player",quality=quality or "normal",raise_built=true}
        if water~=0 then entity.insert_fluid{name="water",amount=water or 100} end
        call("preferences",entity,mode or 1,false)
        storage.cases[name]=entity
        if powered~=false then storage.powered[name]=true end
        return entity
    end
    local function enemy(x,y,force)
        local entity=surface.create_entity{name="esir-water-qc-target",position={x,y},force=force or "enemy"}
        entity.active=false
        return entity
    end
    local c=storage.cases
    if config.performance~=0 then
        local count=math.max(0,config.performance)
        for i=1,count do turret("idle-"..i,-250+((i-1)%50)*4,-40+math.floor((i-1)/50)*4,1,0,false) end
        if count>0 then
            for _,x in ipairs{-260,-200,-140,-80,-20} do surface.create_entity{name="esir-water-qc-pole",position={x,0},force="player"} end
            surface.create_entity{name="esir-water-qc-source",position={-260,0},force="player"}
        end
        return
    end
    c.combat=turret("combat",-350,0)
    c.enemy=enemy(-350,-12)
    c.enemy_first_fire=fire(surface,{-350,10})
    c.friend=enemy(-349.3,-12,"player")
    storage.enemy_health=c.enemy.health
    c.fireonly=turret("fireonly",-280,0,3,15)
    c.fo_enemy=enemy(-280,-12)
    c.fo_fire=fire(surface,{-280,-10})
    c.unpowered=turret("unpowered",-210,0,1,100,false)
    c.up_enemy=enemy(-210,-12)
    c.up_fire=fire(surface,{-210,-10})
    c.protected=turret("protected",-140,0,3,100)
    c.weapon_fire=fire(surface,{-140,-10},"fire-flame")
    c.acid=fire(surface,{-136,-10},"acid-splash-fire-spitter-small")
    c.first=turret("first",-70,0,2,100)
    c.first_enemy=enemy(-70,-12)
    c.first_fire=fire(surface,{-70,-10})
    c.legend=turret("legend",0,0,3,100,true,"legendary")
    c.legend_fire=fire(surface,{0,-30})
    c.dry=turret("dry",70,0,2,14)
    c.dry_enemy=enemy(70,-12)
    c.dry_fire=fire(surface,{70,-10})
    c.refill=turret("refill",70,60,3,0)
    c.infinite=surface.create_entity{name="infinity-pipe",position={72.5,60.5},force="player"}
    c.infinite.set_infinity_pipe_filter{name="water",percentage=1,mode="at-least"}
    c.refill_fire=fire(surface,{70,50})
    -- Each side is fed independently: a working opposite port cannot hide a bad one.
    storage.grid_ports={}
    local cardinals={defines.direction.north,defines.direction.east,defines.direction.south,defines.direction.west}
    local function rotate(x,y,turns)
        for _=1,turns do x,y=-y,x end
        return x,y
    end
    local function positions(entity)
        local result={}
        for _,connection in pairs(entity.fluidbox.get_pipe_connections(1)) do
            result[#result+1]={position=connection.position,target_position=connection.target_position}
        end
        return result
    end
    for cardinal=0,3 do
        for side=1,2 do
            local x,y=-299.5+cardinal*60,60.5+side*16
            local entity=surface.create_entity{name="ei-water-turret",position={x,y},direction=cardinals[cardinal+1],force="player",raise_built=true}
            call("preferences",entity,3,false)
            local expected={}
            for _,sign in ipairs{-1,1} do
                local px,py=rotate(sign,0,cardinal)
                local tx,ty=rotate(sign*2,0,cardinal)
                expected[#expected+1]={position={x=x+px,y=y+py},target_position={x=x+tx,y=y+ty}}
            end
            local key="grid-"..cardinal.."-"..side
            local before=positions(entity)
            local matched=0
            for _,actual in ipairs(before) do for _,want in ipairs(expected) do
                if actual.position.x==want.position.x and actual.position.y==want.position.y
                    and actual.target_position.x==want.target_position.x and actual.target_position.y==want.target_position.y then matched=matched+1 end
            end end
            check(key.."-coordinates",matched==2,{actual=before,expected=expected})
            local pipe=surface.create_entity{name="pipe",position=expected[side].target_position,force="player"}
            pipe.insert_fluid{name="water",amount=100}
            entity.orientation=0.375
            check(key.."-aim-fixed-ports",helpers.table_to_json(before)==helpers.table_to_json(positions(entity)))
            storage.grid_ports[key]={entity=entity,pipe=pipe}
        end
    end
    c.wrong_row=turret("wrong_row",-40,90,3,0,false)
    c.wrong_pipe=surface.create_entity{name="pipe",position={-37.5,89.5},force="player"}
    c.wrong_pipe.insert_fluid{name="water",amount=100}
    c.circuit=turret("circuit",140,0,3,100)
    local behavior=c.circuit.get_or_create_control_behavior()
    behavior.circuit_enable_disable=true
    behavior.circuit_condition={condition={first_signal={type="virtual",name="signal-A"},comparator=">",constant=0}}
    c.constant=surface.create_entity{name="constant-combinator",position={143,3},force="player"}
    c.circuit.get_wire_connector(defines.wire_connector_id.circuit_red,true).connect_to(
        c.constant.get_wire_connector(defines.wire_connector_id.circuit_red,true))
    c.circuit_fire=fire(surface,{140,-10})
    c.external=turret("external",210,0,3,100)
    -- Rebuild later proves a pre-existing script-disable remains owned externally.
    c.external.disabled_by_script=true
    c.flight=turret("flight",280,0,3,15)
    call("preferences",c.flight,3,true)
    c.flight_fire=fire(surface,{280,-20},"fire-flame")
    c.normal_mover=surface.create_entity{name="character",position={-100,100},force="player"}
    c.single_mover=surface.create_entity{name="character",position={-100,110},force="player"}
    c.repeat_mover=surface.create_entity{name="character",position={-100,120},force="player"}
    for _,name in ipairs{"normal_mover","single_mover","repeat_mover"} do
        c[name].walking_state={walking=true,direction=defines.direction.east}
    end
    storage.last_enemy_stickers=0
end
script.on_init(function() storage.pending_setup=true;if visual then game.tick_paused=false end end)
script.on_configuration_changed(function() storage.started=game.tick;storage.results={} end)
local function migration_checks()
    local s=storage.legacy
    if not s then return end
    local gun=s.character.get_inventory(defines.inventory.character_guns)[1]
    local ammo=s.character.get_inventory(defines.inventory.character_ammo)[1]
    check("equipped-gun",gun.name=="ei-extinguisher" and gun.quality.name=="rare")
    check("partial-ammo",ammo.name=="ei-extinguisher-ammo" and ammo.ammo==37 and ammo.quality.name=="rare",ammo.ammo)
    local inv=s.chest.get_inventory(defines.inventory.chest)
    check("chest-gun",inv[1].name=="ei-extinguisher" and inv[1].count==3 and inv[1].quality.name=="uncommon")
    check("chest-ammo",inv[2].name=="ei-extinguisher-ammo" and inv[2].count==4 and inv[2].ammo==37 and inv[2].quality.name=="epic")
    check("loose-item",s.loose.stack.name=="ei-extinguisher" and s.loose.stack.quality.name=="rare")
    check("research",game.forces.player.technologies["ei-extinguisher"].researched)
    check("unresearched",not game.forces["water-qc-unresearched"].technologies["ei-extinguisher"].researched)
    check("recipes",s.assembler.get_recipe().name=="ei-extinguisher" and s.chem.get_recipe().name=="ei-extinguisher-ammo")
    check("stale-marker-removed",not s.marker.valid)
    check("external-removed",not script.active_mods.extinguisher)
end
script.on_event(defines.events.on_tick,function(event)
    if visual then
        if storage.pending_setup then visual.setup(event.tick);storage.pending_setup=nil end
        visual.update(event.tick)
        return
    end
    if muzzle then
        if storage.pending_setup then muzzle.setup(event.tick);storage.pending_setup=nil end
        muzzle.update(event.tick)
        return
    end
    if storage.pending_setup then setup();storage.pending_setup=nil end
    run_started=run_started or event.tick
    local tick=event.tick-run_started
    if config.loaded then
        if storage.legacy then
            if tick==10 then migration_checks();report();if config.save then game.server_save("water-transition") end end
        else
            if tick==0 then storage.reload_power_start=call("state").counters.power_checks end
            if tick==80 then
                local state=call("state")
                check("registry-survives-load",state.count==#storage.surface.find_entities_filtered{name="ei-water-turret"})
                check("preferences-survive-load",rec(storage.cases.protected).mode==3 and rec(storage.cases.protected).weapon_fires)
                check("guards-resume-after-load",state.counters.power_checks>storage.reload_power_start,state.counters)
                report()
            end
        end
        return
    end
    if config.baseline then
        if tick==10 then report();if config.save then game.server_save("water-transition") end end
        return
    end
    if config.performance~=0 then
        if tick==1000 then call("start_profile") end
        if tick==7000 then
            local state=call("state")
            local expected=math.max(0,config.performance)
            local powered=0
            for _,record in pairs(state and state.records or {}) do if record.powered then powered=powered+1 end end
            check("idle-registry",(state and state.count or 0)==expected)
            check("idle-power",powered==expected,powered)
            check("idle-cadence",expected==0 or state.counters.searches<=expected*60,state and state.counters)
            check("profile-calls",call("profile")==6000)
            report()
        end
        return
    end
    local c=storage.cases
    for name in pairs(storage.powered) do
        local entity=c[name]
        if entity and entity.valid then local r=rec(entity);if r and r.power and r.power.valid then r.power.energy=50000 end end
    end
    if tick<300 then c.combat.insert_fluid{name="water",amount=100} end
    if c.flight.valid and c.flight.get_fluid_count("water")<1 then
        call("preferences",c.flight,3,false)
        c.flight.destroy{raise_destroy=true}
        storage.flight_removed=true
    end
    if tick<260 then
        for _,sticker in pairs(c.enemy.stickers or {}) do if sticker.name=="ei-water-slow" then storage.last_enemy_stickers=storage.last_enemy_stickers+1 end end
    end
    if tick==100 then
        storage.move_start={}
        for _,name in ipairs{"normal_mover","single_mover","repeat_mover"} do storage.move_start[name]=c[name].position.x end
        storage.surface.create_entity{name="ei-water-slow",position=c.single_mover.position,target=c.single_mover}
    end
    if tick>=100 and tick<=180 and tick%5==0 then storage.surface.create_entity{name="ei-water-slow",position=c.repeat_mover.position,target=c.repeat_mover} end
    if tick==180 then
        local distance=c.normal_mover.position.x-storage.move_start.normal_mover
        local single=(c.single_mover.position.x-storage.move_start.single_mover)/distance
        local repeated=(c.repeat_mover.position.x-storage.move_start.repeat_mover)/distance
        check("single-slow",math.abs(single-0.75)<0.03,single)
        check("nonstacking-slow",math.abs(repeated-0.75)<0.03,repeated)
    end
    if tick==280 then
        for key,pair in pairs(storage.grid_ports) do
            local connected=false
            for _,connection in pairs(pair.entity.fluidbox.get_pipe_connections(1)) do
                if connection.target and connection.target.owner==pair.pipe then connected=true end
            end
            check(key.."-refill",connected and pair.entity.get_fluid_count("water")>0,pair.entity.get_fluid_count("water"))
        end
        check("wrong-row-disconnected",c.wrong_row.get_fluid_count("water")==0,c.wrong_row.get_fluid_count("water"))
        check("native-acquisition",storage.last_enemy_stickers>0,storage.last_enemy_stickers)
        check("enemy-first-protects-combat",c.enemy_first_fire.valid)
        check("disabled-native-fluid-refill",not c.refill_fire.valid and c.refill.get_fluid_count("water")>0,c.refill.get_fluid_count("water"))
        check("zero-damage",c.enemy.health==storage.enemy_health,{before=storage.enemy_health,after=c.enemy.health})
        check("friendly-not-slowed",not c.friend.stickers or #c.friend.stickers==0)
        check("fire-only",not c.fo_fire.valid and (not c.fo_enemy.stickers or #c.fo_enemy.stickers==0))
        check("pulse-water",c.fireonly.get_fluid_count("water")==0,c.fireonly.get_fluid_count("water"))
        check("in-flight-policy-and-removal",storage.flight_removed and not c.flight_fire.valid)
        check("one-impact-per-pulse",call("impacts")["ei-water-suppression-protected:-280:-10"]==1,call("impacts"))
        check("power-required",c.up_fire.valid and c.unpowered.disabled_by_script and (not c.up_enemy.stickers or #c.up_enemy.stickers==0))
        check("weapon-protected",c.weapon_fire.valid)
        check("acid-protected",c.acid.valid)
        check("fire-first",not c.first_fire.valid)
        check("legendary-range",not c.legend_fire.valid)
        check("circuit-disable",c.circuit_fire.valid and c.circuit.disabled_by_control_behavior,
            {fire=c.circuit_fire.valid,disabled=c.circuit.disabled_by_control_behavior,behavior=c.circuit.get_control_behavior().disabled})
        check("dry-combat-fallback",not c.dry.disabled_by_script,{disabled=c.dry.disabled_by_script,water=c.dry.get_fluid_count("water")})
        call("preferences",c.protected,3,true)
        c.circuit.get_control_behavior().circuit_enable_disable=false
    end
    if tick==300 then storage.water_start=c.combat.get_fluid_count("water") end
    if tick==420 then
        local consumed=storage.water_start-c.combat.get_fluid_count("water")
        check("combat-water-per-second",math.abs(consumed-60)<2.1,consumed/2)
        check("weapon-opt-in",not c.weapon_fire.valid)
        check("acid-still-protected",c.acid.valid)
        check("circuit-reenable",not c.circuit_fire.valid)
        local p={280,-10}
        c.handheld_acid=fire(storage.surface,p,"acid-splash-fire-spitter-small")
        storage.surface.create_entity{name="ei-handheld-extinguisher-stream",position={280,0},source_position={280,0},target_position=p,force="player"}
        storage.powered.combat=nil
        rec(c.combat).power.energy=30000
        storage.blackout_started=event.tick
    end
    if tick>420 and tick<450 and c.combat.disabled_by_script and not storage.blackout_delay then
        storage.blackout_delay=event.tick-storage.blackout_started
        check("blackout-cutoff",storage.blackout_delay<=15 and rec(c.combat).power.energy>0,{ticks=storage.blackout_delay,energy=rec(c.combat).power.energy})
    end
    if tick==550 then
        check("handheld-impact",not c.handheld_acid.valid)
        check("slow-expires",not c.repeat_mover.stickers or #c.repeat_mover.stickers==0)
        local source=c.protected
        c.clone=source.clone{position={280,0},surface=storage.surface,force="player"}
        check("clone-preferences",rec(c.clone).mode==3 and rec(c.clone).weapon_fires)
        check("clone-empty-power",rec(c.clone).power.energy==0 and c.clone.disabled_by_script)
        local r=rec(c.clone);r.power.destroy()
    end
    if tick==590 then
        check("helper-repaired",rec(c.clone).power.valid and c.clone.disabled_by_script)
        local old=rec(c.clone).power
        c.clone.teleport({280,20},nil,true)
        local moved=rec(c.clone).power
        check("helper-teleport",not old.valid and moved.position.x==c.clone.position.x and moved.position.y==c.clone.position.y)
        storage.clone_helper=moved
        c.clone.destroy{raise_destroy=true}
    end
    if tick==620 then
        check("helper-teardown",not storage.clone_helper.valid)
        local pos=c.circuit.position
        local old=rec(c.circuit)
        call("rebuild")
        check("rebuild-preferences",rec(c.protected).mode==3 and rec(c.protected).weapon_fires)
        check("rebuild-empty-power",rec(c.circuit).power.energy==0)
        check("rebuild-old-helper-gone",not old.power.valid)
        report()
        if config.save then game.server_save("water-transition") end
    end
    if config.player and tick==900 then
        local player=game.get_player(1)
        assert(player,"Fixture requires a real player save")
        player.force=game.forces.player
        player.teleport({-140,4},storage.surface)
        player.opened=c.protected
        call("gui_open",{player_index=1,entity=c.protected})
        local root=player.gui.relative["ei-water-turret-console"]
        check("gui-relative",root and root.valid)
        local function child_of_type(parent,kind)
            for _,child in pairs(parent.children) do
                if child.type==kind then return child end
                local found=child_of_type(child,kind);if found then return found end
            end
        end
        local dropdown=child_of_type(root,"drop-down")
        dropdown.selected_index=2
        call("gui_change",{player_index=1,element=dropdown,tick=event.tick})
        check("gui-mode-change",rec(c.protected).mode==2)
        call("paste",c.protected,c.circuit)
        check("settings-paste",rec(c.circuit).mode==2 and rec(c.circuit).weapon_fires)
        player.clear_cursor()
        player.cursor_stack.set_stack{name="blueprint"}
        player.cursor_stack.set_blueprint_entities{{entity_number=1,name="ei-water-turret",position={0,0}}}
        call("blueprint",1,c.protected)
        local tags=player.cursor_stack.get_blueprint_entity_tag(1,"ei_water_turret")
        check("blueprint-tags",tags and tags.mode==2 and tags.weapon_fires)
        local ghosts=player.cursor_stack.build_blueprint{surface=storage.surface,force=player.force,position={300,60},force_build=true}
        for _,ghost in pairs(ghosts) do ghost.revive{raise_revive=true} end
        local built=storage.surface.find_entities_filtered{name="ei-water-turret",position={300,60},radius=3}[1]
        check("blueprint-revive",built and rec(built).mode==2 and rec(built).weapon_fires)
        player.opened=c.circuit
        call("gui_change",{player_index=1,element=dropdown,tick=event.tick})
        check("stale-gui-safe",rec(c.protected).mode==2)
        player.opened=nil
        player.force=game.forces.enemy
        call("gui_open",{player_index=1,entity=c.protected})
        check("foreign-force-gui",not player.gui.relative["ei-water-turret-console"])
        player.force=game.forces.player
        report()
    end
    if tick==700 then
        local temporary=game.create_surface("water-qc-delete",{width=32,height=32})
        local entity=temporary.create_entity{name="ei-water-turret",position={0,0},force="player",raise_built=true}
        storage.deleted_surface_helper=rec(entity).power
        game.delete_surface(temporary)
    end
    if tick==720 then check("surface-cleanup",not storage.deleted_surface_helper.valid);report() end
    if tick%100==0 then report() end
end)
