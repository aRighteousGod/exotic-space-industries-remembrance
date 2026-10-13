local directions={0,32,64,96,128,160,192,224}
local function orientation(d)
    local angle=d*2*math.pi/256
    return (math.atan2(math.sqrt(2)*math.sin(angle),math.cos(angle))/(2*math.pi))%1
end
script.on_init(function()
    if remote.interfaces.freeplay then
        remote.call('freeplay','set_skip_intro',true)
        remote.call('freeplay','set_disable_crashsite',true)
    end
    storage.started=game.tick;storage.rows={};storage.captures={};storage.shots={}
    local surface=game.create_surface('casing-probe',{autoplace_controls={},
        autoplace_settings={entity={treat_missing_as_default=false}}})
    storage.surface=surface
    surface.request_to_generate_chunks({0,0},3)
    surface.request_to_generate_chunks({0,100},3)
    surface.force_generate_chunk_requests()
    surface.freeze_daytime=true;surface.daytime=0
    local tiles={}
    for x=-28,28 do for y=-16,155 do tiles[#tiles+1]={name='refined-concrete',position={x,y}} end end
    surface.set_tiles(tiles,true)
    for index,spec in ipairs(prototypes.mod_data['mg-casing-probe-data'].data.specs) do
        for n,d in ipairs(directions) do
            local x=((n-1)%4)*8-12+0.5
            local y=(index-1)*16+math.floor((n-1)/4)*8+0.5
            local turret=assert(surface.create_entity{name=spec.name,force='player',position={x,y}})
            turret.orientation=orientation(d);turret.disabled_by_script=true
            turret.insert{name='firearm-magazine',count=100};turret.energy=666000
            storage.rows[#storage.rows+1]={entity=turret,direction=d,profile=index,label=spec.label,
                position={turret.position.x,turret.position.y}}
        end
    end
end)
script.on_event(defines.events.on_entity_damaged,function(e)
    local cause=e.cause
    if cause and cause.valid and cause.name:match('^mg%-casing%-probe%-') then
        local key=tostring(cause.unit_number)
        storage.shots[key]=(storage.shots[key] or 0)+1
        storage.shot_orientations=storage.shot_orientations or {}
        storage.shot_orientations[key]=cause.orientation
    end
end)
script.on_event(defines.events.on_tick,function(e)
    if storage.done then return end
    if not storage.clock_started then storage.started=e.tick-1;storage.clock_started=true end
    local age=e.tick-storage.started
    local player=game.get_player(1)
    if age==2 and player then player.set_controller{type=defines.controllers.god};player.teleport({0,4},storage.surface) end
    for _,row in ipairs(storage.rows) do row.entity.energy=666000 end
    if age==15 then
        for _,row in ipairs(storage.rows) do
            local angle=orientation(row.direction)*2*math.pi
            row.target=assert(storage.surface.create_entity{name='mg-casing-target',force='enemy',
                position={row.entity.position.x+math.sin(angle)*14,row.entity.position.y-math.cos(angle)*14}})
            row.entity.disabled_by_script=false;row.entity.shooting_target=row.target
        end
    end
    if age==65 then
        for _,row in ipairs(storage.rows) do
            row.entity.disabled_by_script=true
            if row.target and row.target.valid then row.target.destroy() end
        end
    end
    if age==75 then
        for index,spec in ipairs(prototypes.mod_data['mg-casing-probe-data'].data.specs) do
            local path='casing-probe/'..spec.label..'.png'
            game.take_screenshot{player=player,surface=storage.surface,position={0.5,(index-1)*16+3.5},
                resolution={1280,640},zoom=1.25,daytime=0,anti_alias=false,show_gui=false,
                show_entity_info=false,hide_clouds=true,hide_fog=true,force_render=true,path=path}
            storage.captures[#storage.captures+1]={profile=index,label=spec.label,path=path,
                position={0.5,(index-1)*16+3.5},resolution={1280,640},zoom=1.25}
        end
    end
    if age==90 then
        local rows={}
        for _,row in ipairs(storage.rows) do rows[#rows+1]={direction=row.direction,label=row.label,
            profile=row.profile,position=row.position,orientation=row.entity.orientation,
            shots=storage.shots[tostring(row.entity.unit_number)] or 0} end
        helpers.write_file('casing-probe-report.json',helpers.table_to_json{
            engine=script.active_mods.base,rows=rows,captures=storage.captures,
            specs=prototypes.mod_data['mg-casing-probe-data'].data.specs},false)
        storage.done=true;game.set_wait_for_screenshots_to_finish()
    end
end)
