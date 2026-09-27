local model={}
local started
function model.setup(tick)
    log("water-art: setup at "..tick)
    local surface=game.create_surface("water-art-qc",{width=64,height=64,autoplace_controls={},autoplace_settings={entity={treat_missing_as_default=false}}})
    surface.request_to_generate_chunks({0,0},2);surface.force_generate_chunk_requests()
    for _,entity in pairs(surface.find_entities_filtered{type={"unit","unit-spawner","turret","tree"}}) do entity.destroy() end
    local tiles={}
    for x=-20,20 do for y=-20,20 do tiles[#tiles+1]={name="lab-dark-1",position={x,y}} end end
    surface.set_tiles(tiles);surface.always_day=true
    storage.visual={surface=surface,started=tick,turrets={}}
    for index,direction in ipairs{defines.direction.north,defines.direction.east,defines.direction.south,defines.direction.west} do
        local p={x=index%2==1 and -4.5 or 4.5,y=index<=2 and -4.5 or 4.5}
        local entity=surface.create_entity{name="ei-water-turret",position=p,direction=direction,force="player",raise_built=true}
        remote.call("ei-water-qc","preferences",entity,3,false)
        storage.visual.turrets[#storage.visual.turrets+1]=entity
        for _,connection in pairs(entity.fluidbox.get_pipe_connections(1)) do
            local target=connection.target_position
            surface.create_entity{name="pipe",position=target,force="player"}.insert_fluid{name="water",amount=100}
        end
        rendering.draw_text{text=({"N base","E base","S base","W base"})[index],surface=surface,target={p.x-1.5,p.y+2.5},color={1,1,1},scale=1}
    end
end
function model.update(tick)
    local state=storage.visual
    started=started or tick
    local offset=tick-started
    if offset>=60 and offset<300 then
        local pose=math.floor((offset-60)/30)
        for _,entity in ipairs(state.turrets) do entity.orientation=pose/8 end
        if (offset-60)%30==10 then
            log("water-art: capture pose "..pose)
            game.take_screenshot{surface=state.surface,position={0,0},resolution={1280,1280},zoom=2,
                path="water-art/pose-"..pose..".png",show_gui=false,show_entity_info=false,daytime=0,anti_alias=true,force_render=true}
        end
    end
end
script.on_event(defines.events.on_player_created,function(event)
    if not storage.visual then model.setup(event.tick);storage.pending_setup=nil end
    game.tick_paused=false
    log("water-art: graphics player ready")
end)
return model
