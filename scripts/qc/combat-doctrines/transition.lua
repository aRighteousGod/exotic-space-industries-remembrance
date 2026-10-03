local test=require("test-config")
local function stacks()
    local rows={}
    local inventory=storage.stash.get_inventory(defines.inventory.chest)
    for i=1,3 do
        local stack=inventory[i]
        rows[i]={name=stack.name,count=stack.count,ammo=stack.ammo,quality=stack.quality.name,capacity=stack.prototype.magazine_size}
    end
    return rows
end
local function record()
    storage.transition_report={phase=test.phase,stacks=stacks(),tick=game.tick,
        ballistic=settings.startup["ei-ballistic-divergence"].value,
        doctrine=settings.startup["ei-ballistic-divergence-preset"].value,
        pyric_doctrine=settings.startup["ei-pyric-radiance-preset"].value,
        inflight=storage.inflight and storage.inflight.valid or false,all_pass=true}
    for index,row in ipairs(storage.transition_report.stacks) do
        assert(row.name==(index==3 and "shotgun-shell" or "firearm-magazine"),"Transition item identity")
        assert(row.count==1 and row.quality==(index==2 and "legendary" or "normal"),"Transition count/quality")
        assert(row.ammo>0,"Transition remaining ammunition")
        if test.phase=="transition-reload" then
            assert(row.ammo==storage.previous_stacks[index].ammo,"Reload changed remaining ammunition")
        end
    end
    if test.phase~="transition-reload" then assert(storage.transition_report.inflight,"Saved private projectile did not survive") end
    if test.phase=="transition-off" or test.phase=="transition-reload" then
        assert(storage.transition_report.doctrine=="terminal-barrage" and storage.transition_report.pyric_doctrine=="apotheosis","Disabled toggles lost their selected doctrines")
    end
    storage.previous_stacks=storage.transition_report.stacks
    if test.phase=="transition-source" or test.phase=="transition-reload" then storage.save_pending=true
    else
        storage.consume_cases={}
        local inventory=storage.stash.get_inventory(defines.inventory.chest)
        for index,row in ipairs(storage.transition_report.stacks) do
            local y=20+index*12
            local turret=storage.stash.surface.create_entity{name=index==3 and "ei-shotgun-turret" or "gun-turret",position={0,y},force="player"}
            local target=storage.stash.surface.create_entity{name="ei-combat-doctrines-qc-target",position={8,y},force="enemy"}
            local stack=turret.get_inventory(defines.inventory.turret_ammo)[1]
            stack.set_stack(inventory[index])
            assert(stack.ammo==row.ammo,"Copy changed saved ammunition")
            turret.shooting_target=target
            storage.consume_cases[index]={turret=turret,target=target,initial_health=target.health,remaining=row.ammo,consumed=0}
        end
        storage.consume_started=game.tick
    end
end
script.on_init(function()
    local surface=game.create_surface("combat-transition",{autoplace_controls={},autoplace_settings={entity={treat_missing_as_default=false}}})
    surface.request_to_generate_chunks({60,20},3);surface.force_generate_chunk_requests()
    local tiles={};for x=-20,140 do for y=-10,65 do tiles[#tiles+1]={name="refined-concrete",position={x,y}} end end
    surface.set_tiles(tiles)
    storage.stash=surface.create_entity{name="steel-chest",position={0,-6},force="player"}
    local inv=storage.stash.get_inventory(defines.inventory.chest)
    inv[1].set_stack{name="firearm-magazine",count=1,ammo=7}
    inv[2].set_stack{name="firearm-magazine",count=1,ammo=27,quality="legendary"}
    inv[3].set_stack{name="shotgun-shell",count=1,ammo=7}
    game.forces.player.set_ammo_damage_modifier("bullet",.5)
    game.forces.player.set_turret_attack_modifier("ei-combat-doctrines-qc-bullet",.5)
    storage.flight_target=surface.create_entity{name="ei-combat-doctrines-qc-range-target",position={120,0},force="enemy"}
    storage.flight_health=storage.flight_target.health
    storage.flight_impacts=0
    storage.launcher=surface.create_entity{name="ei-combat-doctrines-qc-bullet",position={0,0},force="player",quality="legendary"}
    storage.launcher.orientation=.25
    local ammo=storage.launcher.get_inventory(defines.inventory.turret_ammo)[1]
    ammo.set_stack{name="firearm-magazine",count=1,quality="legendary"};ammo.ammo=1
    storage.launcher.shooting_target=storage.flight_target
    storage.awaiting_launch=true
    storage.flight_expected_damage=8*2.5*1.5*1.5
    storage.needs_record=true
end)
script.on_configuration_changed(function() storage.needs_record=true end)
script.on_load(function() end)
script.on_event(defines.events.on_entity_damaged,function(event)
    if event.entity==storage.flight_target then storage.flight_impacts=storage.flight_impacts+1 end
end)
script.on_event(defines.events.on_tick,function(event)
    if storage.awaiting_launch then
        local projectiles=storage.stash.surface.find_entities_filtered{type="projectile",name="ei-ballistic-divergence-firearm-magazine-1-1-1"}
        if #projectiles==0 then assert(event.tick<60,"Native transition shot did not launch");return end
        storage.inflight=projectiles[1];storage.awaiting_launch=nil
    end
    if storage.needs_record or storage.recorded_phase~=test.phase then
        storage.needs_record=nil;storage.recorded_phase=test.phase;record()
    end
    if storage.consume_cases then
        local complete=true
        for _,c in ipairs(storage.consume_cases) do
            local stack=c.turret.get_inventory(defines.inventory.turret_ammo)[1]
            local remaining=stack.valid_for_read and (stack.count-1)*stack.prototype.magazine_size+stack.ammo or 0
            c.consumed=c.consumed+c.remaining-remaining;c.remaining=remaining
            if remaining>0 then complete=false end
        end
        if complete and game.tick-storage.consume_started>150 then
            local rows={}
            for index,c in ipairs(storage.consume_cases) do
                assert(c.consumed==storage.transition_report.stacks[index].ammo and c.target.health<c.initial_health,"Saved rounds were lost or refilled")
                rows[index]={rounds=c.consumed,damage=c.initial_health-c.target.health}
            end
            assert(storage.flight_impacts==1 and not storage.inflight.valid,"Saved projectile did not complete one impact")
            local flight_damage=storage.flight_health-storage.flight_target.health
            assert(math.abs(flight_damage-storage.flight_expected_damage)<.01,"Saved native projectile lost its research or quality scaling")
            storage.transition_report.consumption=rows
            storage.transition_report.saved_projectile_impacts=storage.flight_impacts
            storage.transition_report.saved_projectile_damage=flight_damage
            storage.consume_cases=nil;storage.save_pending=true
        end
    end
    if storage.save_pending then
        storage.save_pending=nil
        helpers.write_file(test.phase..".json",helpers.table_to_json(storage.transition_report),false)
        game.server_save("combat-doctrines-"..test.phase)
    end
end)
