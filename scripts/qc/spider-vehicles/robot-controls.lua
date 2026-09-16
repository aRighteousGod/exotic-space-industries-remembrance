-- Native construction-robot mining/build events, including the consumed LuaItem.
local catalog=require("__exotic-space-industries-remembrance__/lib/spider-vehicles")
local api="exotic-industries-spider-vehicles"
local model={}
function model.setup()
    local surface=game.surfaces["esir-weapon-controls"]
    local force=game.forces["esir-control-base"]
    force.worker_robots_speed_modifier=10
    surface.request_to_generate_chunks({0,5000},2);surface.force_generate_chunk_requests()
    local tiles={}
    for x=-12,25 do for y=4988,5012 do tiles[#tiles+1]={name="grass-1",position={x,y}} end end
    surface.set_tiles(tiles)
    local port=surface.create_entity{name="roboport",position={0,5000},force=force}
    port.energy=100000000
    port.get_inventory(defines.inventory.roboport_robot).insert{name="construction-robot",count=2}
    surface.create_entity{name="storage-chest",position={5,5000},force=force}
    local entity=surface.create_entity{name=catalog.configured_name("rocket",catalog.researched_state(force),{cycling=false,special=false},settings.startup["ei-spider-range-aware-cycling"].value),position={10,5000},force=force,raise_built=true}
    remote.call(api,"set_weapon_controls",entity,{cycling=false,special=false,selected_slot=2})
    storage.robot_controls={port=port,entity=entity,id=remote.call(api,"get_vehicle_id",entity)}
end
function model.replaced(event)
    local state=storage.robot_controls
    if not state then return end
    if state.id==event.vehicle_id then state.entity=event.entity end
    if state.rebuilt_id==event.vehicle_id then state.rebuilt=event.entity end
end
function model.mined(event)
    local state=storage.robot_controls
    if not state or event.entity~=state.entity then return end
    state.mined=true
    for index=1,#event.buffer do
        local stack=event.buffer[index]
        if stack.valid_for_read and stack.item_number then state.item_number=stack.item_number end
    end
end
function model.built(event)
    local state=storage.robot_controls
    if not state or not state.mined or catalog.family(event.entity.name)~="rocket" then return end
    state.rebuilt=event.entity;state.rebuilt_id=remote.call(api,"get_vehicle_id",event.entity)
end
function model.step(tick,check)
    local state=storage.robot_controls
    if not state then return end
    state.port.energy=100000000
    if tick==140 then state.entity.order_deconstruction(state.entity.force)
    elseif tick==300 then
        check("controls-native-robot-mine",state.mined==true and state.item_number~=nil)
        local port=state.port
        port.surface.create_entity{name="entity-ghost",inner_name="spidertron",position={15,5000},force=port.force,expires=false}
    elseif tick==480 and state.rebuilt and state.rebuilt.valid then
        local current=state.rebuilt and state.rebuilt.valid and remote.call(api,"get_weapon_controls",state.rebuilt)
        check("controls-native-robot-rebuild",current and not current.cycling and not current.special and current.selected_slot==2 and not current.pending)
        check("controls-native-robot-new-identity",current and current.vehicle_id~=state.id)
        local port=state.port
        local chest=port.surface.create_entity{name="passive-provider-chest",position={-8,5000},force=port.force}
        chest.insert{name="iron-plate",count=100}
        port.get_inventory(defines.inventory.roboport_robot).insert{name="logistic-robot",count=1}
        state.section=state.rebuilt.get_logistic_sections().add_section()
        state.section.set_slot(1,{value={name="iron-plate",quality="normal",comparator="="},min=100,max=100})
    elseif tick==600 then
        check("controls-active-delivery-pending",state.delivery_pending==true)
    end
    if tick>480 and tick<590 and state.rebuilt and state.rebuilt.valid then
        if state.delivery_requested then
            local controls=remote.call(api,"get_weapon_controls",state.rebuilt)
            if controls.pending_reason=="logistic-delivery" and controls.pending and not controls.effective_special then
                state.delivery_pending=true
                state.section.active=false
                remote.call(api,"set_weapon_controls",state.rebuilt,{special=false})
                state.delivery_requested=nil
            end
        elseif not state.delivery_pending then
            for _,point in pairs(state.rebuilt.get_logistic_point()) do
                if next(point.targeted_items_deliver) then
                    remote.call(api,"set_weapon_controls",state.rebuilt,{special=true})
                    state.delivery_requested=true
                    break
                end
            end
        end
    end
end
return model
