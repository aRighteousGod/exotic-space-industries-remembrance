local function capture(name)
    game.take_screenshot{player=game.get_player(1),surface=storage.surface,
        position={9.5,9.5},resolution={1728,1728},zoom=2,
        path='centering/'..name..'.png',show_gui=false,show_entity_info=false,daytime=0,anti_alias=false}
end
script.on_init(function()
    local surface = game.create_surface('centering',{width=128,height=128})
    surface.request_to_generate_chunks({9,9},3); surface.force_generate_chunk_requests()
    for _, entity in pairs(surface.find_entities()) do if entity.valid then entity.destroy() end end
    local tiles = {}
    for y=-40,50 do for x=-40,50 do tiles[#tiles+1]={name='lab-dark-1',position={x,y}} end end
    surface.set_tiles(tiles); surface.daytime=.5; surface.freeze_daytime=true
    storage.surface=surface; storage.rows={}; storage.age=0; storage.shots=0
    local directions={0,.25,.5,.75}
    local groups=prototypes.mod_data['mg-centering-audit'].data.groups
    for row, group in ipairs(groups) do
        for col, orientation in ipairs(directions) do
            local turret=assert(surface.create_entity{name=group.entity,force='player',position={(col-1)*6+.5,(row-1)*6+.5}})
            turret.orientation=orientation; turret.disabled_by_script=true
            turret.insert{name='piercing-rounds-magazine',count=100}; turret.energy=666000
            rendering.draw_rectangle{color={r=.3,g=1,b=.4,a=1},left_top=turret.selection_box.left_top,
                right_bottom=turret.selection_box.right_bottom,surface=surface,width=2,draw_on_ground=true}
            rendering.draw_text{text=group.density..' '..group.state,target={turret.position.x,turret.position.y+2},
                surface=surface,color={1,1,1},scale=1.5,alignment='center'}
            storage.rows[#storage.rows+1]={entity=turret,orientation=orientation}
        end
    end
end)
script.on_event(defines.events.on_entity_damaged,function(event)
    if event.cause and event.cause.valid and event.cause.name:find('mg-centering-',1,true)==1 then storage.shots=storage.shots+1 end
end)
script.on_event(defines.events.on_tick,function(event)
    if storage.done then return end
    storage.age=storage.age+1
    local age=storage.age
    if age==2 then local p=game.get_player(1); if p then p.set_controller{type=defines.controllers.god};p.teleport({9.5,9.5},storage.surface) end end
    for _, row in ipairs(storage.rows) do row.entity.energy=666000 end
    if age==10 then capture('parked') end
    if age==15 then
        for _, row in ipairs(storage.rows) do
            local a=row.orientation*2*math.pi
            row.target=assert(storage.surface.create_entity{name='mg-centering-target',force='enemy',
                position={row.entity.position.x+math.sin(a)*14,row.entity.position.y-math.cos(a)*14}})
            row.entity.disabled_by_script=false; row.entity.shooting_target=row.target
        end
    end
    if age==75 then capture('firing') end
    if age==100 then for _, row in ipairs(storage.rows) do if row.target.valid then row.target.destroy() end end end
    if age==225 then capture('standdown') end
    if age==230 then
        helpers.write_file('centering/report.json',helpers.table_to_json{engine=script.active_mods.base,
            shots=storage.shots,audit=prototypes.mod_data['mg-centering-audit'].data},false)
        storage.done=true
    end
end)
