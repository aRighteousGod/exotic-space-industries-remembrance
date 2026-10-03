local test=require("test-config")
local fuels=require("__exotic-space-industries-remembrance__/lib/flamethrower-fuels")
local configs={require("__exotic-space-industries-remembrance__/lib/pyric-radiance-config"),
    require("__exotic-space-industries-remembrance__/lib/ballistic-divergence-config")}
local titles={"pyric-radiance","ballistic-divergence"}
script.on_init(function()
    if remote.interfaces.freeplay then remote.call("freeplay","set_skip_intro",true);remote.call("freeplay","set_disable_crashsite",true) end
    local surface=game.create_surface("combat-night",{autoplace_controls={},autoplace_settings={entity={treat_missing_as_default=false}}})
    surface.request_to_generate_chunks({0,0},3);surface.force_generate_chunk_requests()
    local tiles={};for x=-50,50 do for y=-35,35 do tiles[#tiles+1]={name="refined-concrete",position={x,y}} end end
    surface.set_tiles(tiles);surface.freeze_daytime=true;surface.daytime=.5
    storage.surface=surface;storage.start=game.tick
    game.forces.player.chart(surface,{{-80,-80},{80,80}})
    rendering.draw_text{text="Pyric Radiance / "..test["pyric-radiance"],surface=surface,target={0,-27},color={1,1,1},alignment="center"}
    storage.targets={}
    for i=1,10 do
        local fuel=fuels.fuels[i]
        local x=(i-5.5)*8
        surface.create_entity{name="ei-flame-"..fuel.id.."-turret-fire",position={x,-9},force="player",initial_ground_flame_count=1}
        storage.targets[i]=surface.create_entity{name="ei-combat-doctrines-qc-target",position={x,-17},force="enemy"}
        rendering.draw_text{text=fuel.id,surface=surface,target={x,-5},color={1,1,1},scale=.6,alignment="center"}
    end
    storage.silo=surface.create_entity{name="rocket-silo",position={28,17},force="player"}
    storage.silo.rocket_parts=prototypes.entity["rocket-silo"].rocket_parts_required
    storage.silo.get_inventory(defines.inventory.rocket_silo_rocket).insert{name="iron-plate",count=1}
    storage.report={phase=test.phase,screenshots={},rocket_statuses={}}
    storage.report.translations={}
end)
script.on_event(defines.events.on_string_translated,function(event)
    storage.report.translations[#storage.report.translations+1]={translated=event.translated,result=event.result}
end)
local function capture(tag)
    local path="combat-doctrines/"..test.phase.."-"..tag..".png"
    game.take_screenshot{surface=storage.surface,position={0,0},resolution={1920,1080},zoom=.65,daytime=.5,
        show_gui=false,show_entity_info=false,hide_clouds=true,hide_fog=true,force_render=true,path=path}
    storage.report.screenshots[#storage.report.screenshots+1]=path
end
script.on_event(defines.events.on_tick,function(event)
    local tick=event.tick-storage.start
    local player=game.get_player(1)
    if player and not storage.viewer then
        player.set_controller{type=defines.controllers.spectator}
        player.teleport({0,0},storage.surface)
        for i,config in ipairs(configs) do
            for _,name in ipairs(config.allowed_values) do player.request_translation(config.describe(name)) end
            player.request_translation({"combat-doctrines.overlap-warning",{"exotic-industries-informatron."..titles[i]}})
        end
        storage.viewer=true
    end
    storage.silo.energy=1000000000
    local status=storage.silo.rocket_silo_status
    if status~=storage.status then
        storage.status=status
        storage.report.rocket_statuses[#storage.report.rocket_statuses+1]={tick=tick,status=status}
        if status==defines.rocket_silo_status.rocket_ready then
            storage.silo.launch_rocket({type=defines.cargo_destination.orbit})
        elseif status==defines.rocket_silo_status.engine_starting or status==defines.rocket_silo_status.rocket_flying then capture("launch-"..tick) end
    end
    if tick%90==1 and tick<700 then
        for i,fuel in ipairs(fuels.fuels) do
            local x=(i-5.5)*8
            storage.surface.create_entity{name="ei-flame-"..fuel.id.."-flamethrower-fire-stream",position={x,0},source_position={x,0},target_position={x,-17},force="player"}
            storage.surface.create_entity{name="ei-flame-"..fuel.id.."-turret-fire",position={x,-9},force="player",initial_ground_flame_count=1}
        end
    end
    if tick==180 or tick==450 then
        for i,name in ipairs{"explosion","big-explosion","explosion-gunshot","uranium-cannon-explosion"} do
            storage.surface.create_entity{name=name,position={-32+(i-1)*12,13},target={-30+(i-1)*12,13},force="player"}
        end
        for i,name in ipairs{"ei-ballistic-divergence-firearm-magazine-1-1-1","ei-ballistic-divergence-ei-cryo-ammo-1-1-1","rocket"} do
            storage.surface.create_entity{name=name,position={-35,14+i*3},source={-35,14+i*3},target={10,14+i*3},force="player",speed=1,max_range=45}
        end
    end
    if tick==180 or tick==181 or tick==190 or tick==451 or tick==480 or tick==1000 then capture(tostring(tick)) end
    if tick==2100 then
        assert(#storage.report.translations==22,"All shared doctrine descriptions and warnings must translate")
        for _,result in ipairs(storage.report.translations) do assert(result.translated,"Invalid combat doctrine localization") end
        helpers.write_file("combat-doctrines-visual.json",helpers.table_to_json(storage.report),false)
    end
end)
