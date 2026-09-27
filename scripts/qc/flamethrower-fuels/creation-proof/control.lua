local function check(name,value)
    storage.report.checks[name]=value==true
    helpers.write_file("flamethrower-proof.json",helpers.table_to_json(storage.report),false)
    assert(value,name)
end
script.on_init(function()
    storage.report={checks={},events={},reused=0}
    local surface=game.surfaces[1]
    surface.request_to_generate_chunks({0,0},1);surface.force_generate_chunk_requests()
    for _,entity in pairs(surface.find_entities_filtered{area={{-10,-10},{10,10}}}) do entity.destroy() end
    local tiles={}
    for x=-10,10 do for y=-10,10 do tiles[#tiles+1]={name="refined-concrete",position={x,y}} end end
    surface.set_tiles(tiles)
    storage.target=surface.create_entity{name="behemoth-biter",position={5,0},force="enemy"}
    storage.target.active=false
end)
script.on_event(defines.events.on_trigger_created_entity,function(event)
    local entity=event.entity
    check("created-valid",entity.valid)
    storage.report.events[#storage.report.events+1]={tick=event.tick,name=entity.name}
    if entity.type=="sticker" then
        check("attached-at-event",entity.sticked_to==storage.target)
        for _,old in pairs(entity.sticked_to.stickers or {}) do
            if old~=entity then old.destroy() end
        end
        storage.sticker=entity
        check("sticker-destruction-safe",entity.valid and #entity.sticked_to.stickers==1)
    elseif entity.type=="fire" then
        if storage.fire==entity then storage.report.reused=storage.report.reused+1 end
        for _,old in pairs(entity.surface.find_entities_filtered{position=entity.position,radius=1,type="fire"}) do
            if old~=entity then old.destroy() end
        end
        storage.fire=entity
        check("fire-destruction-safe",entity.valid)
    end
end)
local function shot(kind,id)
    local target=kind=="sticker" and storage.target or {0,0}
    game.surfaces[1].create_entity{name="proof-"..kind.."-shot-"..id,position={0,0},target=target,speed=1,force="player"}
end
script.on_event(defines.events.on_tick,function(event)
    if event.tick==1 then shot("fire","a");shot("sticker","a") end
    if event.tick==15 then shot("fire","b");shot("sticker","b") end
    if event.tick>=30 and event.tick<=100 and event.tick%5==0 then shot("fire","b") end
    if event.tick==150 then
        check("refueling-emits-no-new-creation",#storage.report.events==4 and storage.report.reused==0)
        check("newest-sticker",storage.sticker.valid and storage.sticker.name=="proof-sticker-b")
        check("newest-fire",storage.fire.valid and storage.fire.name=="proof-fire-b")
        check("one-fire",game.surfaces[1].count_entities_filtered{position={0,0},radius=1,type="fire"}==1)
        storage.report.all_pass=true
        helpers.write_file("flamethrower-proof.json",helpers.table_to_json(storage.report),false)
    end
end)
