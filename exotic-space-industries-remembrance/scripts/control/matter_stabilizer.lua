local model = {}

--====================================================================================================
--MATTER STABILIZER
--====================================================================================================

model.stabilizers = {
    ["ei-alien-stabilizer"] = ei_data.matter_stabilizer.alien_range,
    ["ei-matter-stabilizer"] = ei_data.matter_stabilizer.matter_range
}

model.matter_machines = {
    ["ei-exotic-assembler"] = true
}


--UTIL AND OTHER
------------------------------------------------------------------------------------------------------

function model.check_entity(entity)

    if entity == nil then
        return false
    end

    if not entity.valid then
        return false
    end

    return true

end


function model.find_in_range(machine_type, surface, pos, range)

    local entities = surface.find_entities_filtered({
        position = pos,
        radius = range,
        type ="assembling-machine"
    })

    local matter_machines = {}

    for _, e in pairs(entities) do

        if machine_type == "stabilizer" then
            if model.stabilizers[e.name] and e.is_crafting() then
                table.insert(matter_machines, e)
            end

        elseif machine_type == "matter_machine" then
            if model.matter_machines[e.name] then
                table.insert(matter_machines, e)
            end
        end

    end

    return matter_machines

end


function model.update_matter_machine(entity)

    if not model.check_entity(entity) or not (entity.is_crafting() or entity.crafting_progress > 0) then
        return
    end
    local sur = entity.surface
    local pos = {["x"]=entity.position.x,["y"]=entity.position.y}
    local range = ei_data.matter_stabilizer.matter_range
    if not sur or not pos["x"] or not pos["y"] then
        log("ei update_matter_machine got nil sur or pos for exotic assembler")
        return
    end
    -- get stabilizers in range
    local stabilizers = model.find_in_range("stabilizer", sur, {pos["x"],pos["y"]}, range)
    local stabilizers_nearby_count = #stabilizers or 0

    local progress = entity.crafting_progress or 0
    local base_chance = 0.12 --0.12
    local decay = 2.43
    -- In-range / effective ones
    -- floor at 1 to avoid div-by-zero
    local total_matter_machines = storage.ei.matter_machines_count or 1

    -- Estimate how often a single matter machine gets updated per second
    -- Scale update pressure by total number of stabilizers (more stabilizers = more contention)
    local updates_per_entity = math.min(ei_update_functions_length,(ei_updater_per_entity_calls_per_second / total_matter_machines))

    -- Safety floor
    if updates_per_entity < 0.01 then updates_per_entity = 0.01 end --cheese it by going over 9000 stabilizers? doubt it

    -- Calculate explosion chance per update
    local chance = base_chance / ((stabilizers_nearby_count + 1) ^ decay)
    chance = chance * (1 + progress)^3
    chance = chance / updates_per_entity --modulate based off how often the updater makes it to a particular machine
    local rand = math.random()

    if rand < chance then
        --clickable with link
        game.print({"exotic-industries.exotic-assembler-explode", sur.name, pos["x"], pos["y"]})
        ei_lib.crystal_echo_floating("Containment Breach: Rationality Compromised.",entity,6000,nil,chance,stabilizers_nearby_count,total_matter_machines,updates_per_entity)
        --Sayonara
        entity.surface.create_entity{
        name = "ei-matter-explosion",
        position = entity.position,
        target = entity.position,
        speed = 0.3,
        force = entity.force
    }
    else
        rendering.draw_light {
        sprite = "emt_charger_glow",
        scale = 0.75,
        intensity = 0.55, --same as plasma turret, ideal given explosion is the plasma bullet explosion
        color = {r = 0.45, g = 0.1, b = 0.6},
        target = entity,
        surface = sur,
        time_to_live = math.ceil((60 / updates_per_entity)*1.25),
        players = game.connected_players,
        blend_mode = "multiplicative",
        apply_runtime_tint = true,
        draw_as_glow = true,
        }
    end
end


--REGISTRY
------------------------------------------------------------------------------------------------------

function model.register_stabilizer(entity)

    if storage.ei.matter_stabilizers == nil then
        storage.ei.matter_stabilizers = {}
    end
    if storage.ei.matter_stabilizers_count == nil then
        storage.ei.matter_stabilizers_count = 0
    end

    storage.ei.matter_stabilizers[entity.unit_number] = entity
    storage.ei.matter_stabilizers_count = storage.ei.matter_stabilizers_count+1

end


function model.unregister_stabilizer(entity)

    if storage.ei.matter_stabilizers == nil then
        return
    end
    if storage.ei.matter_stabilizers_count == nil then
       storage.ei.matter_stabilizers_count = 0
    end
    storage.ei.matter_stabilizers[entity.unit_number] = nil
    storage.ei.matter_stabilizers_count = math.max(0,storage.ei.matter_stabilizers_count-1)
end


function model.register_matter_machine(entity)

    if storage.ei.matter_machines == nil then
        storage.ei.matter_machines = {}
    end
    if storage.ei.matter_machines_count == nil then
        storage.ei.matter_machines_count = 0
    end
    storage.ei.matter_machines[entity.unit_number] = entity
    storage.ei.matter_machines_count = storage.ei.matter_machines_count+1

end


function model.unregister_matter_machine(entity)

    if storage.ei.matter_machines == nil then
        return
    end
    if storage.ei.matter_machines_count == nil then
       storage.ei.matter_machines_count = 0
    end
    storage.ei.matter_machines[entity.unit_number] = nil
    storage.ei.matter_machines_count = math.max(0,storage.ei.matter_machines_count-1)
end


--RENDERING RELATED
------------------------------------------------------------------------------------------------------

function model.draw_connection(source, target, player)

    if not model.check_entity(source) then
        return
    end

    if not model.check_entity(target) then
        return
    end

    if not storage.ei.selected_render then
        storage.ei.selected_render = {}
    end

    -- draw a line between the two entities
    render = rendering.draw_line{
        color = {r = 0, g = 1, b = 0},
        width = 0.2,
        from = source.position,
        to = target.position,
        surface = source.surface,
        players = {player},
        forces = {source.force},
        draw_on_ground = true,
    }

    table.insert(storage.ei.selected_render, {
        ["render"] = render,
        ["source"] = source,
        ["target"] = target,
        ["type"] = "connection"
    })

    -- game.print(source.unit_number)

end


function model.draw_stabilizer_range(entity, player)

    if not model.check_entity(entity) then
        return
    end

    if not storage.ei.selected_render then
        storage.ei.selected_render = {}
    end

    -- check if this entity already has a range circle

    for _, render in pairs(storage.ei.selected_render) do
        if render.type == "range" and render.source == entity then
            return
        end
    end

    local range = model.stabilizers[entity.name]
    local scale = range/4 -- 1 <-> 2.5 + 1.5 tiles = 4 tiles

    -- draw a circle around the entity

    render = rendering.draw_sprite{
        sprite = "ei-stabilizer-radius",
        target = entity,
        surface = entity.surface,
        players = {player},
        forces = {entity.force},
        render_layer = "radius-visualization",
        x_scale = scale,
        y_scale = scale,
    }

    table.insert(storage.ei.selected_render, {
        ["render"] = render,
        ["source"] = entity,
        ["type"] = "range"
    })

end


function model.remove_rendering(entity)

    if not model.check_entity(entity) then
        return
    end

    -- remove this entity from rendering
    -- assume it is a matter machine

    for _, render in pairs(storage.ei.selected_render) do
        if render.type == "connection" and render.target == entity then
            render.render.destroy()
            table.remove(storage.ei.selected_render, _)
        end
    end

    -- assume it is a stabilizer

    for _, render in pairs(storage.ei.selected_render) do
        if render.type == "range" and render.source == entity then
            render.render.destroy()
            table.remove(storage.ei.selected_render, _)
        end

        if render.type == "connection" and render.source == entity then
            render.render.destroy()
            table.remove(storage.ei.selected_render, _)
        end

    end

end


function model.clear_rendering(player)

    if not player.valid then
        return
    end

    if not player.cursor_stack then
        return
    end

    -- dont clear rendering if player has stabilizer or matter machine in cursor
    if player.cursor_stack.valid_for_read then
        if model.stabilizers[player.cursor_stack.name] then
            return
        end

        if model.matter_machines[player.cursor_stack.name] then
            return
        end
    end

    if storage.ei.selected_render then
        for _, render in pairs(storage.ei.selected_render) do
            render = render.render
            render.destroy()
        end
    end

    storage.ei.selected_render = {}

end


function model.stabilizer_selected(player, entity)

    if not model.check_entity(entity) then
        return
    end

    local range = model.stabilizers[entity.name]
    local matter_machines = model.find_in_range("matter_machine",entity.surface, entity.position, range)

    -- draw lines to all matter machines

    for _, e in pairs(matter_machines) do
        model.draw_connection(entity, e, player)
    end

end


--[[
function model.matter_machine_selected(player, entity)

end
]]


function model.stabilizer_on_cursor(player)

    -- get player position and find all stabilizers in screen range

    local position = player.position

    if not position then
        return
    end

    local stabilizers = model.find_in_range("stabilizer", player.surface, position, 100)

    -- draw circle for every stabilizer

    for _, e in pairs(stabilizers) do
        model.draw_stabilizer_range(e, player)

        -- draw lines to all matter machines
        model.stabilizer_selected(player, e)
    end

end


--HANDLERS
------------------------------------------------------------------------------------------------------

function model.on_built_entity(entity)

    if model.stabilizers[entity.name] then
        model.register_stabilizer(entity)
    elseif model.matter_machines[entity.name] then
        model.register_matter_machine(entity)
    end
    
end


function model.on_destroyed_entity(entity)

    if model.stabilizers[entity.name] then
        model.remove_rendering(entity)

        -- remove stabilizer from storage
        model.unregister_stabilizer(entity)
    elseif model.matter_machines[entity.name] then
        model.remove_rendering(entity)

        -- remove matter machine from storage
        model.unregister_matter_machine(entity)
    end
    
end


function model.on_selected_entity_changed(event)

    local player = game.get_player(event.player_index)
    local new_entity = player.selected

    if player == nil then
        return
    end

    model.clear_rendering(player)

    if new_entity == nil then
        return
    end

    if model.stabilizers[new_entity.name] then
        model.stabilizer_selected(player, new_entity)
    end

    --[[
    if model.matter_machines[new_entity.name] then
        model.matter_machine_selected(player, new_entity)
    end
    ]]

end


function model.on_player_cursor_stack_changed(event)

    local player = game.get_player(event.player_index)

    if player == nil then
        return
    end

    model.clear_rendering(player)

    if player.cursor_stack and player.cursor_stack.valid_for_read then
        
        local item = player.cursor_stack.name

        if model.stabilizers[item] then
            model.stabilizer_on_cursor(player)
        end

        if model.matter_machines[item] then
            model.stabilizer_on_cursor(player)
        end

    end

end


function model.update()

    if not storage.ei.matter_machines then
        return false
    end

    -- if no current break point then try to make a new one
    if not storage.ei.stabilizer_break_point and next(storage.ei.matter_machines) then
        storage.ei.stabilizer_break_point,_ = next(storage.ei.matter_machines)
    end

    -- if no current break point then return
    if not storage.ei.stabilizer_break_point then
        return false
    end

    -- get current break point
    local break_id = storage.ei.stabilizer_break_point

    model.update_matter_machine(storage.ei.matter_machines[break_id])

    -- get next break point
    if next(storage.ei.matter_machines, break_id) then
        storage.ei.stabilizer_break_point,_ = next(storage.ei.matter_machines, break_id)
        return true
    else
        storage.ei.stabilizer_break_point = nil
        return false
    end

end


return model