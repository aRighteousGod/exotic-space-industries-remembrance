-- Disposable fixture's sole event owner. Native inventory/crafting/research
-- windows are opened directly; no imitation of the game UI is used.
local config=require('test-config')
local function capture(label,tick,position,gui)
    local player=game.get_player(1)
    local path='minigun-consumer/'..label..'.png'
    game.take_screenshot{player=player,surface=storage.surface,position=position or {0,0},
        resolution={1280,960},zoom=1,daytime=0,anti_alias=false,
        show_gui=gui or false,show_entity_info=false,hide_clouds=true,hide_fog=true,force_render=true,path=path}
    storage.captures[#storage.captures+1]={label=label,path=path,tick=tick,gui=gui or false,
        opened_gui_type=player and player.opened_gui_type or nil,
        inventory_window_open=player and player.opened_gui_type==defines.gui_type.controller or false,
        opened_entity=player and player.opened_gui_type==defines.gui_type.entity and player.opened and player.opened.name or nil}
end
script.on_init(function()
    if remote.interfaces.freeplay then
        remote.call('freeplay','set_skip_intro',true);remote.call('freeplay','set_disable_crashsite',true)
    end
    storage.started=game.tick;storage.captures={};storage.rows={};storage.observations={}
    local surface=game.create_surface('mg-consumer',{autoplace_controls={},autoplace_settings={entity={treat_missing_as_default=false}}})
    storage.surface=surface
    surface.request_to_generate_chunks({0,0},3);surface.force_generate_chunk_requests()
    local tiles={}
    for x=-32,32 do for y=-24,24 do tiles[#tiles+1]={name='refined-concrete',position={x,y}} end end
    surface.set_tiles(tiles,true);surface.freeze_daytime=true;surface.daytime=0
    game.forces.player.chart(surface,{{-48,-48},{48,48}})
    for i,direction in ipairs(config.directions) do
        local x=((i-1)%4)*8-12;local y=math.floor((i-1)/4)*10-5
        local turret=assert(surface.create_entity{name=config.entity_name,force='player',position={x+0.5,y+0.5}})
        turret.orientation=direction/256;turret.disabled_by_script=true
        turret.insert{name='piercing-rounds-magazine',count=100}
        turret.energy=666000
        storage.rows[#storage.rows+1]={entity=turret,direction=direction}
    end
end)
script.on_event(defines.events.on_tick,function(e)
    if storage.done then return end
    local age=e.tick-storage.started
    local player=game.get_player(1)
    if age==2 then
        assert(player,'Native consumer capture requires the graphics benchmark player')
        player.set_controller{type=defines.controllers.god};player.teleport({0,18},storage.surface)
        local inventory=assert(player.get_main_inventory())
        inventory.clear();inventory.insert{name=config.entity_name,count=1}
        assert(game.forces.player.recipes[config.entity_name]);game.forces.player.recipes[config.entity_name].enabled=true
    end
    for _,row in ipairs(storage.rows) do
        row.entity.energy=666000 -- Observation rig supplies power, not a shortage test.
        if row.target and row.target.valid then row.target.health=1000000000 end
    end
    if age==10 then capture('parked-eight-directions',e.tick) end
    if age==40 then
        for _,row in ipairs(storage.rows) do
            local angle=row.direction*2*math.pi/256
            row.target=assert(storage.surface.create_entity{name='mg-consumer-target',force='enemy',
                position={row.entity.position.x+math.sin(angle)*14,row.entity.position.y-math.cos(angle)*14}})
            row.entity.disabled_by_script=false;row.entity.shooting_target=row.target
        end
    end
    if age>=39 and age<=100 then capture('prepare-'..age,e.tick) end
    if age==130 then capture('running-eight-directions',e.tick) end
    if age==160 then
        for _,row in ipairs(storage.rows) do if row.target and row.target.valid then row.target.destroy() end end
    end
    if age>=159 and age<=360 then capture('fold-'..age,e.tick) end
    if age==390 then
        player.opened=nil;capture('combined-shadow-eight-directions',e.tick)
    end
    if age==410 then player.opened=defines.gui_type.controller end
    if age==412 then capture('native-inventory-crafting',e.tick,player.position,true) end
    if age==430 then player.opened=storage.rows[1].entity end
    if age==432 then capture('native-entity-window',e.tick,storage.rows[1].entity.position,true) end
    if age==450 then player.opened=nil;player.open_technology_gui(config.technology_name) end
    if age==452 then capture('native-research-window',e.tick,player.position,true) end
    if age%10==0 then
        local rows={}
        for _,row in ipairs(storage.rows) do rows[#rows+1]={direction=row.direction,orientation=row.entity.orientation,
            active=row.entity.active,energy=row.entity.energy,ammo=row.entity.get_item_count('piercing-rounds-magazine')} end
        storage.observations[#storage.observations+1]={tick=e.tick,age=age,rows=rows}
    end
    if age==500 then
        local report={schema='esir.minigun.consumer-native.v1',engine_version=script.active_mods.base,
            config=config,lineage=config.lineage,done=true,captures=storage.captures,observations=storage.observations,
            audit=prototypes.mod_data['mg-consumer-audit'].data,active_mods=script.active_mods}
        helpers.write_file('minigun-consumer-report.json',helpers.table_to_json(report),false)
        storage.done=true;game.set_wait_for_screenshots_to_finish()
    end
end)
