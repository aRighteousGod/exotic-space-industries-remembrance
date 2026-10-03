local test=require("test-config")
script.on_init(function()
    if remote.interfaces.freeplay then remote.call("freeplay","set_skip_intro",true);remote.call("freeplay","set_disable_crashsite",true) end
    local surface=game.create_surface("combat-performance",{autoplace_controls={},autoplace_settings={entity={treat_missing_as_default=false}}})
    surface.request_to_generate_chunks(test["miss-scene"] and {400,125} or {120,50},test["miss-scene"] and 30 or 6);surface.force_generate_chunk_requests()
    local tiles={};for x=-8,310 do for y=-8,170 do tiles[#tiles+1]={name="refined-concrete",position={x,y}} end end
    surface.set_tiles(tiles);surface.freeze_daytime=true;surface.daytime=.5
    game.forces.player.chart(surface,{{-20,-20},{330,190}})
    storage.surface=surface;storage.start=game.tick
    storage.receivers={};storage.turrets={};storage.initial_rounds=0
    for x=0,9 do for y=0,9 do
        local target=surface.create_entity{name="ei-combat-doctrines-qc-target",position={x*30+(test["miss-scene"] and 80 or 22),y*16},force="enemy"}
        local turret=surface.create_entity{name="ei-combat-doctrines-qc-bullet",position={x*30,y*16},force="player"}
        turret.orientation=.25;turret.get_inventory(defines.inventory.turret_ammo).insert{name="firearm-magazine",count=1000}
        turret.shooting_target=target
        storage.receivers[#storage.receivers+1]={entity=target,health=target.health}
        storage.turrets[#storage.turrets+1]=turret
        local stack=turret.get_inventory(defines.inventory.turret_ammo)[1]
        storage.initial_rounds=storage.initial_rounds+stack.count*stack.prototype.magazine_size
    end end
end)
script.on_event(defines.events.on_tick,function(event)
    if test.mode=="rendering" and not storage.viewer then
        local player=game.get_player(1)
        if player and player.connected then
            player.set_controller{type=defines.controllers.spectator}
            player.teleport({150,75},storage.surface);player.zoom=.14
            storage.viewer=true
        end
    end
    local report_tick=test.mode=="rendering" and 1800 or 3500
    if event.tick-storage.start==report_tick then
        local damage,remaining=0,0
        for _,receiver in ipairs(storage.receivers) do damage=damage+receiver.health-receiver.entity.health end
        for _,turret in ipairs(storage.turrets) do
            local stack=turret.get_inventory(defines.inventory.turret_ammo)[1]
            if stack.valid_for_read then remaining=remaining+(stack.count-1)*stack.prototype.magazine_size+stack.ammo end
        end
        helpers.write_file("combat-doctrines-performance.json",helpers.table_to_json({phase=test.phase,
            tick=event.tick,
            miss_scene=test["miss-scene"]==true,shots_fired=storage.initial_rounds-remaining,native_hits=damage/8,
            ballistic=settings.startup["ei-ballistic-divergence"].value,pyric=settings.startup["ei-pyric-radiance"].value,
            projectiles=#storage.surface.find_entities_filtered{type="projectile"},turrets=100,viewer=storage.viewer==true}),false)
    end
end)
