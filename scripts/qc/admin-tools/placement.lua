-- Native placement/grant acceptance in a disposable full-ESIR save only.
local model={}
local function action(player,operation,args,tick)
    return remote.call("esir-admin-qc","execute",player.index,operation,args,tick)
end
local function place(player,surface,force,item,position,quality,tick,check)
    local ok,message=action(player,"place_entities",{surface_index=surface.index,force_index=force.index,
        position=position,place_item={name=item,quality=quality or "normal"},quantity=1,direction=defines.direction.north},tick)
    check("placement admitted "..item.." at "..position.x..","..position.y,ok,message)
end

function model.start(player,force,tick,check)
    local surface=game.create_surface("ei-admin-qc-placement",{width=128,height=128,
        autoplace_settings={entity={treat_missing_as_default=false},decorative={treat_missing_as_default=false}}})
    surface.request_to_generate_chunks({0,0},2);surface.force_generate_chunk_requests()
    local tiles={}
    for x=-40,40 do for y=-40,40 do tiles[#tiles+1]={name="refined-concrete",position={x,y}} end end
    surface.set_tiles(tiles,true)
    local rails={}
    for y=-16,24,2 do
        rails[#rails+1]=assert(surface.create_entity{name="straight-rail",position={0,y},direction=defines.direction.north,force=force})
    end
    place(player,surface,force,"ei-steam-basic-locomotive",{x=0,y=0},"rare",tick,check)
    local original=assert(surface.create_entity{name="wooden-chest",position={16,0},force=player.force})
    original.insert{name="coal",count=7}

    -- The isolated fixture deliberately fills its disposable player's inventory.
    -- Service insertion must keep these existing stacks intact and report limits.
    local inventory=assert(player.get_main_inventory())
    for slot=1,#inventory do inventory[slot].set_stack{name="coal",count=prototypes.item.coal.stack_size} end
    local coal_before=inventory.get_item_count("coal")
    local ok,message=action(player,"give_items",{player_index=player.index,item={name="copper-plate",quality="rare"},quantity=1},tick)
    check("full inventory grant inserts nothing",not ok and inventory.get_item_count{name="copper-plate",quality="rare"}==0,message)
    check("full inventory grant preserves existing stacks",inventory.get_item_count("coal")==coal_before)
    inventory[1].clear()
    local fit=prototypes.item["copper-plate"].stack_size
    ok,message=action(player,"give_items",{player_index=player.index,item={name="copper-plate",quality="rare"},quantity=10000},tick)
    check("partial quality grant fills available slot",ok and inventory.get_item_count{name="copper-plate",quality="rare"}==fit,message)
    check("partial grant preserves other stacks",inventory.get_item_count("coal")==coal_before-prototypes.item.coal.stack_size)
    return {surface=surface,force=force,original=original,rails=rails,start=tick,phase=1,player_index=player.index}
end

function model.finish(state,tick,check)
    if tick-state.start<5 then return false end
    local trains=state.surface.find_entities_filtered{name="ei-steam-basic-locomotive"}
    local player=game.get_player(state.player_index)
    if state.phase==1 then
        check("steam wrapper creates one native locomotive",#trains==1,#trains)
        local train=trains[1]
        check("scripted steam wrapper preserves selected force",train and train.force==state.force)
        check("scripted steam wrapper preserves quality",train and train.quality.name=="rare")
        local on_selected_track=false
        local occupied=train and train.train.get_rails() or {}
        for _,rail in ipairs(occupied) do
            for _,expected in ipairs(state.rails) do if rail==expected then on_selected_track=true end end
        end
        check("steam placement remains on selected native track",on_selected_track,train and train.position)
        check("steam placement has native empty fuel inventory",train and train.get_fuel_inventory().is_empty())
        check("steam placement wrapper is removed by owner",state.surface.count_entities_filtered{name="ei-steam-basic-locomotive-placement-entity"}==0)
        -- A valid unoccupied rail lies six tiles away. Native placement must not
        -- search for and silently relocate this request onto it.
        place(player,state.surface,state.force,"ei-steam-basic-locomotive",{x=6,y=16},"normal",tick,check)
        state.phase=2;state.start=tick;return false
    elseif state.phase==2 then
        check("off-track placement does not move stock to nearby rail",#trains==1,#trains)
        place(player,state.surface,state.force,"wooden-chest",{x=16,y=0},"rare",tick,check)
        state.phase=3;state.start=tick;return false
    end
    check("placement preserves obstructing entity and inventory",state.original.valid and state.original.get_item_count("coal")==7)
    check("ordinary placement creates a collision-safe quality building",state.surface.count_entities_filtered{name="wooden-chest",force=state.force,quality="rare"}==1)
    return true
end
return model
