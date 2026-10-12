-- Disposable fixture's sole event owner. Native inventory/crafting/research
-- windows are opened directly; no imitation of the game UI is used.
local config=require('test-config')
local function capture(label,tick,position,gui)
    if config.disable_gui then return end
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
    game.tick_paused=false
    game.speed=1
    if remote.interfaces.freeplay then
        remote.call('freeplay','set_skip_intro',true);remote.call('freeplay','set_disable_crashsite',true)
    end
    storage.started=game.tick;storage.captures={};storage.rows={};storage.observations={}
    storage.shots={};storage.damage={}
    local surface=game.create_surface('mg-consumer',{autoplace_controls={},autoplace_settings={entity={treat_missing_as_default=false}}})
    storage.surface=surface
    surface.request_to_generate_chunks({0,0},3);surface.force_generate_chunk_requests()
    surface.request_to_generate_chunks({80,70},2);surface.request_to_generate_chunks({-80,70},2)
    surface.request_to_generate_chunks({80,150},2);surface.request_to_generate_chunks({-80,150},2);surface.force_generate_chunk_requests()
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
    for index,name in ipairs({'minigun-turret-hd','mg-rate-reference','mg-rate-cooldown-probe','mg-rate-animation-probe'}) do
        local turret=assert(surface.create_entity{name=name,force='player',position={index%2==1 and -80.5 or 80.5,index<=2 and 70.5 or 150.5}})
        turret.orientation=0;turret.disabled_by_script=true
        turret.insert{name='piercing-rounds-magazine',count=100};turret.energy=666000
        storage.rows[#storage.rows+1]={entity=turret,direction=0,rate_test=true}
    end
end)
script.on_event(defines.events.on_player_created,function(e)
    game.tick_paused=false
    game.speed=1
end)
script.on_event(defines.events.on_entity_damaged,function(e)
    local cause=e.cause
    if cause and cause.valid and (cause.name=='minigun-turret-hd' or cause.name:match('^mg%-rate%-')) then
        local age=e.tick-storage.started
        if age>=80 and age<140 then
            local key=tostring(cause.unit_number)
            storage.shots[key]=(storage.shots[key] or 0)+1
            storage.damage[key]=e.final_damage_amount
        end
    end
end)
script.on_event(defines.events.on_tick,function(e)
    if storage.done then return end
    if not storage.clock_started then
        storage.started=e.tick-1
        storage.clock_started=true
        helpers.write_file('minigun-first-tick.json',helpers.table_to_json({tick=e.tick,game_tick=game.tick,paused=game.tick_paused,speed=game.speed,players=#game.players}),false)
    end
    storage.invocations=(storage.invocations or 0)+1
    if storage.invocations<=10 then helpers.write_file('minigun-tick-debug.json',helpers.table_to_json({tick=e.tick,game_tick=game.tick,paused=game.tick_paused,speed=game.speed,players=#game.players,invocations=storage.invocations}),true) end
    local age=e.tick-storage.started
    local player=game.get_player(1)
    if age==2 and not config.disable_gui then
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
    if age>=39 and age<=58 then capture('prepare-'..age,e.tick) end
    if age>=80 and age<=100 then capture('firing-'..age,e.tick) end
    if age==130 then capture('running-eight-directions',e.tick) end
    if age==160 then
        for _,row in ipairs(storage.rows) do if row.target and row.target.valid then row.target.destroy() end end
    end
    if age>=209 and age<=245 then capture('fold-'..age,e.tick) end
    if age==390 and not config.disable_gui then
        player.opened=nil;capture('combined-shadow-eight-directions',e.tick)
    end
    if not config.disable_gui then
        if age==410 then player.opened=defines.gui_type.controller end
        if age==412 then capture('native-inventory-crafting',e.tick,player.position,true) end
        if age==430 then player.opened=storage.rows[1].entity end
        if age==432 then capture('native-entity-window',e.tick,storage.rows[1].entity.position,true) end
        if age==450 then
            player.opened=nil;player.open_technology_gui(config.technology_name)
            capture('native-research-window',e.tick,player.position,true)
        end
    end
    if age%10==0 then
        local rows={}
        for _,row in ipairs(storage.rows) do rows[#rows+1]={direction=row.direction,orientation=row.entity.orientation,
            active=row.entity.active,energy=row.entity.energy,ammo=row.entity.get_item_count('piercing-rounds-magazine')} end
        storage.observations[#storage.observations+1]={tick=e.tick,age=age,rows=rows}
    end
    if age==450 then
        local report={schema='esir.minigun.consumer-native.v1',engine_version=script.active_mods.base,
            config=config,lineage=config.lineage,done=true,captures=storage.captures,observations=storage.observations,
            audit=prototypes.mod_data['mg-consumer-audit'].data,active_mods=script.active_mods}
        report.rate={}
        for _,row in ipairs(storage.rows) do if row.rate_test then
            local key=tostring(row.entity.unit_number)
            report.rate[row.entity.name]={shots=storage.shots[key] or 0,damage=storage.damage[key]}
        end end
        helpers.write_file('minigun-consumer-report.json',helpers.table_to_json(report),false)
        storage.done=true
        if not config.disable_gui then game.set_wait_for_screenshots_to_finish() end
    end
end)
