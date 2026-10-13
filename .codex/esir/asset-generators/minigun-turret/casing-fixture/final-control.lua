local config=require('test-config')
local directions={0,32,64,96,128,160,192,224}
---@param d integer
---@return number
local function orientation(d)
    local a=d*2*math.pi/256
    return (math.atan2(math.sqrt(2)*math.sin(a),math.cos(a))/(2*math.pi))%1
end
---@param entity LuaEntity
---@return number
local function ammo_left(entity)
    local slot=entity.get_inventory(defines.inventory.turret_ammo)[1]
    if not slot.valid_for_read then return 0 end
    return (slot.count-1)*slot.prototype.magazine_size+slot.ammo
end
---@param label string
---@param position? MapPosition
---@param resolution? DisplayResolution
---@param zoom? number
local function capture(label,position,resolution,zoom)
    local path='casing-final/'..label..'.png'
    game.take_screenshot{player=game.get_player(1),surface=storage.surface,position=position or {0.5,4.5},
        resolution=resolution or {1280,640},zoom=zoom or 1.25,daytime=0,anti_alias=false,
        show_gui=false,show_entity_info=false,hide_clouds=true,hide_fog=true,force_render=true,path=path}
    storage.captures[#storage.captures+1]={label=label,path=path,age=game.tick-storage.started,
        position=position or {0.5,4.5},resolution=resolution or {1280,640},zoom=zoom or 1.25}
end
script.on_init(function()
    if remote.interfaces.freeplay then
        remote.call('freeplay','set_skip_intro',true);remote.call('freeplay','set_disable_crashsite',true)
    end
    storage.started=game.tick;storage.rows={};storage.captures={};storage.shots={};storage.trace={}
    local surface=game.create_surface('casing-final',{autoplace_controls={},
        autoplace_settings={entity={treat_missing_as_default=false}}})
    storage.surface=surface
    for _,p in ipairs({{0,0},{80,0}}) do surface.request_to_generate_chunks(p,3) end
    surface.force_generate_chunk_requests();surface.freeze_daytime=true;surface.daytime=0
    local tiles={}
    for x=-32,105 do for y=-24,24 do tiles[#tiles+1]={name='refined-concrete',position={x,y}} end end
    surface.set_tiles(tiles,true)
    for i,d in ipairs(directions) do
        local turret=assert(surface.create_entity{name=config.entity,force='player',
            position={((i-1)%4)*8-12+.5,math.floor((i-1)/4)*8+.5}})
        turret.orientation=orientation(d);turret.disabled_by_script=true
        local ammo=({'firearm-magazine','piercing-rounds-magazine','uranium-rounds-magazine'})[(i-1)%3+1]
        turret.insert{name=ammo,count=100};turret.energy=666000
        storage.rows[#storage.rows+1]={entity=turret,direction=d,ammo=ammo}
    end
    local single=assert(surface.create_entity{name='mg-casing-single',force='player',position={80.5,.5}})
    single.orientation=0;single.disabled_by_script=true
    single.insert{name='piercing-rounds-magazine',count=100};single.energy=666000
    storage.single=single
end)
script.on_event(defines.events.on_entity_damaged,function(e)
    local cause=e.cause
    if cause and cause.valid and (cause.name==config.entity or cause.name=='mg-casing-single') then
        local key=tostring(cause.unit_number)
        storage.shots[key]=(storage.shots[key] or 0)+1
        if cause.name=='mg-casing-single' and not storage.single_shot then storage.single_shot=e.tick-storage.started end
    end
end)
script.on_event(defines.events.on_tick,function(e)
    if storage.done then return end
    if not storage.clock_started then storage.started=e.tick-1;storage.clock_started=true end
    local age=e.tick-storage.started;local player=game.get_player(1)
    if age==2 and player then player.set_controller{type=defines.controllers.god};player.teleport({0,4},storage.surface) end
    if age==10 then capture('parked-baseline') end
    for _,row in ipairs(storage.rows) do row.entity.energy=666000 end
    storage.single.energy=666000
    if age==15 then
        for _,row in ipairs(storage.rows) do
            local a=orientation(row.direction)*2*math.pi
            row.target=assert(storage.surface.create_entity{name='mg-casing-target',force='enemy',
                position={row.entity.position.x+math.sin(a)*14,row.entity.position.y-math.cos(a)*14}})
            row.entity.disabled_by_script=false;row.entity.shooting_target=row.target
        end
        storage.single_target=assert(storage.surface.create_entity{name='mg-casing-target',force='enemy',position={80.5,-13.5}})
        storage.single.disabled_by_script=false;storage.single.shooting_target=storage.single_target
    end
    local elapsed=storage.single_shot and age-storage.single_shot
    if elapsed and elapsed>=1 and elapsed<=35 then
        capture('single-'..elapsed,{80.5,.5},{384,384},3)
        storage.trace[#storage.trace+1]={age=age,elapsed=elapsed,orientation=storage.single.orientation,
            position={storage.single.position.x,storage.single.position.y}}
        storage.single.disabled_by_script=true
    end
    if age>=24 and age<=34 then capture('first-shot-'..age) end
    if age==80 then for _,row in ipairs(storage.rows) do row.ammo_start=ammo_left(row.entity) end end
    if age==80 or age==81 or age==90 or age==130 then capture('firing-'..age) end
    if age==140 then
        for _,row in ipairs(storage.rows) do row.steady_shots=row.ammo_start-ammo_left(row.entity) end
    end
    if age>=141 and age<180 then
        local row=storage.rows[4]
        row.target.teleport({row.entity.position.x+14*math.sin(orientation(96)*2*math.pi+(age-141)*.012),
            row.entity.position.y-14*math.cos(orientation(96)*2*math.pi+(age-141)*.012)})
    end
    if age==160 then capture('turning-burst') end
    if age==180 then
        for _,row in ipairs(storage.rows) do if row.target.valid then row.target.destroy() end end
        if storage.single_target.valid then storage.single_target.destroy() end
        capture('last-burst')
    end
    if age==200 or age==220 or age==240 or age==360 or age==400 or age==430 then capture('stand-down-'..age) end
    if age==435 then
        local rows={}
        for _,row in ipairs(storage.rows) do rows[#rows+1]={direction=row.direction,ammo=row.ammo,
            orientation=row.entity.orientation,steady_shots=row.steady_shots,
            damage_events=storage.shots[tostring(row.entity.unit_number)] or 0,
            position={row.entity.position.x,row.entity.position.y}} end
        helpers.write_file('casing-final-report.json',helpers.table_to_json{engine=script.active_mods.base,
            config=config,rows=rows,captures=storage.captures,trace=storage.trace,
            single_shot=storage.single_shot,audit=prototypes.mod_data['mg-casing-final-audit'].data},false)
        storage.done=true;game.set_wait_for_screenshots_to_finish()
    end
end)
