local model = {}
ei_lib = require("lib/lib")

--====================================================================================================
--MATTER STABILIZER
--====================================================================================================

local MATTER_RUNTIME_VERSION = 2
local MATTER_CHUNK_SIZE = 32
local MATTER_RANGE = ei_data.matter_stabilizer.matter_range
local MATTER_RANGE_SQR = MATTER_RANGE * MATTER_RANGE

local RISK_STRAINED_THRESHOLD = 0.02
local RISK_CRITICAL_THRESHOLD = 0.06

local WARNING_COOLDOWN_TICKS = 1800
local IMMINENT_WARNING_DELAY_TICKS = 600
local STRAINED_CRACKLE_COOLDOWN_TICKS = 180
local CRITICAL_CRACKLE_COOLDOWN_TICKS = 90
local CRITICAL_ARC_COOLDOWN_TICKS = 300

local GLOW_SPRITE = "emt_charger_glow"
local ARC_BEAM_NAME = "ei_charger-beam"
local CRACKLE_ANIMATION = "ei-overload-animation"

model.stabilizers = {
    ["ei-alien-stabilizer"] = ei_data.matter_stabilizer.alien_range,
    ["ei-matter-stabilizer"] = ei_data.matter_stabilizer.matter_range
}

model.matter_machines = {
    ["ei-exotic-assembler"] = true
}

model.stabilizer_names = {
    "ei-alien-stabilizer",
    "ei-matter-stabilizer"
}

model.matter_machine_names = {
    "ei-exotic-assembler"
}


--UTIL AND OTHER
------------------------------------------------------------------------------------------------------

local function new_runtime()
    return {
        version = MATTER_RUNTIME_VERSION,
        needs_rebuild = false,
        runtime_rebuild_in_progress = false,
        stabilizers = {},
        machines = {},
        stabilizer_chunks = {},
        machine_chunks = {},
        machine_surface_queues = {},
        machine_surface_counts = {},
        active_surfaces = {},
        active_surface_positions = {},
        active_surface_cursor = 1,
        machine_count = 0,
        stabilizer_count = 0,
        machine_fx = {},
        selected_render = {}
    }
end


local function new_surface_queue()
    return {
        items = {},
        positions = {},
        cursor = 1
    }
end


local function destroy_render_object(render_object)
    if render_object and render_object.valid then
        render_object.destroy()
    end
end


local function get_surface_index(surface)
    return surface and surface.index or nil
end


local function get_chunk_coordinate(tile_coordinate)
    return math.floor(tile_coordinate / MATTER_CHUNK_SIZE)
end


local function get_chunk_key(chunk_x, chunk_y)
    return chunk_x .. "," .. chunk_y
end


local function get_chunk_coordinates(position)
    return get_chunk_coordinate(position.x), get_chunk_coordinate(position.y)
end


local function get_chunk_coverage(position, radius)
    return get_chunk_coordinate(position.x - radius),
        get_chunk_coordinate(position.x + radius),
        get_chunk_coordinate(position.y - radius),
        get_chunk_coordinate(position.y + radius)
end


local function is_within_range_squared(source_position, target_position, max_range_sqr)
    local delta_x = source_position.x - target_position.x
    local delta_y = source_position.y - target_position.y
    return (delta_x * delta_x + delta_y * delta_y) <= max_range_sqr
end


local function get_surface_chunk_store(chunk_store, surface_index, create)
    local surface_store = chunk_store[surface_index]
    if not surface_store and create then
        surface_store = {}
        chunk_store[surface_index] = surface_store
    end

    return surface_store
end


local function get_chunk_bucket(chunk_store, surface_index, chunk_x, chunk_y, create)
    local surface_store = get_surface_chunk_store(chunk_store, surface_index, create)
    if not surface_store then
        return nil
    end

    local key = get_chunk_key(chunk_x, chunk_y)
    local bucket = surface_store[key]
    if not bucket and create then
        bucket = {}
        surface_store[key] = bucket
    end

    return bucket, key, surface_store
end


function model.check_entity(entity)

    if entity == nil then
        return false
    end

    if not entity.valid then
        return false
    end

    return true

end


function model.get_stabilizer_weight(entity)
    if entity and entity.quality and entity.quality.level and entity.quality.level > 1 then
        return (entity.quality.level - 1) * 3
    end

    return 1
end


function model.get_machine_base_chance(entity)
    local base_chance = 0.12

    if entity and entity.quality and entity.quality.level and entity.quality.level > 1 then
        base_chance = math.max(0.06, base_chance - (0.01 * (entity.quality.level - 1)))
    end

    return base_chance
end


function model.get_updates_per_entity(machine_count)
    local total_machines = math.max(1, machine_count or 0)
    local updates_per_entity = math.min(
        ei_update_functions_length,
        (ei_updater_per_entity_calls_per_second / total_machines)
    )

    if updates_per_entity < 0.01 then
        updates_per_entity = 0.01
    end

    return updates_per_entity
end


function model.destroy_machine_fx(runtime, unit_number)
    if not runtime or not runtime.machine_fx then
        return
    end

    local fx_state = runtime.machine_fx[unit_number]
    if not fx_state then
        return
    end

    destroy_render_object(fx_state.light)
    destroy_render_object(fx_state.halo)
    destroy_render_object(fx_state.outer_aura)
    runtime.machine_fx[unit_number] = nil
end


function model.destroy_player_render_list(render_list)
    if not render_list then
        return
    end

    for _, render_entry in pairs(render_list) do
        destroy_render_object(render_entry.render)
    end
end


function model.destroy_runtime_state(runtime)
    if not runtime then
        return
    end

    if runtime.machine_fx then
        for unit_number, _ in pairs(runtime.machine_fx) do
            model.destroy_machine_fx(runtime, unit_number)
        end
    end

    if runtime.selected_render then
        for _, render_list in pairs(runtime.selected_render) do
            model.destroy_player_render_list(render_list)
        end
    end
end


function model.reset_runtime_storage(runtime)
    runtime.version = MATTER_RUNTIME_VERSION
    runtime.needs_rebuild = false
    runtime.runtime_rebuild_in_progress = false
    runtime.stabilizers = {}
    runtime.machines = {}
    runtime.stabilizer_chunks = {}
    runtime.machine_chunks = {}
    runtime.machine_surface_queues = {}
    runtime.machine_surface_counts = {}
    runtime.active_surfaces = {}
    runtime.active_surface_positions = {}
    runtime.active_surface_cursor = 1
    runtime.machine_count = 0
    runtime.stabilizer_count = 0
    runtime.machine_fx = {}
    runtime.selected_render = {}

    storage.ei.matter_stabilizers = {}
    storage.ei.matter_stabilizers_count = 0
    storage.ei.matter_machines = {}
    storage.ei.matter_machines_count = 0
    storage.ei.stabilizer_break_point = nil
end


function model.check_global()
    if not storage.ei then
        storage.ei = {}
    end

    local runtime = storage.ei.matter_runtime
    local needs_rebuild = false

    if not runtime then
        runtime = new_runtime()
        storage.ei.matter_runtime = runtime
        needs_rebuild = true
    end

    if runtime.version ~= MATTER_RUNTIME_VERSION then
        needs_rebuild = true
    end

    if not runtime.stabilizers then
        runtime.stabilizers = {}
        needs_rebuild = true
    end
    if not runtime.machines then
        runtime.machines = {}
        needs_rebuild = true
    end
    if not runtime.stabilizer_chunks then
        runtime.stabilizer_chunks = {}
        needs_rebuild = true
    end
    if not runtime.machine_chunks then
        runtime.machine_chunks = {}
        needs_rebuild = true
    end
    if not runtime.machine_surface_queues then
        runtime.machine_surface_queues = {}
        needs_rebuild = true
    end
    if not runtime.machine_surface_counts then
        runtime.machine_surface_counts = {}
        needs_rebuild = true
    end
    if not runtime.active_surfaces then
        runtime.active_surfaces = {}
        needs_rebuild = true
    end
    if not runtime.active_surface_positions then
        runtime.active_surface_positions = {}
        needs_rebuild = true
    end
    if runtime.active_surface_cursor == nil then
        runtime.active_surface_cursor = 1
        needs_rebuild = true
    end
    if runtime.machine_count == nil then
        runtime.machine_count = 0
        needs_rebuild = true
    end
    if runtime.stabilizer_count == nil then
        runtime.stabilizer_count = 0
        needs_rebuild = true
    end
    if not runtime.machine_fx then
        runtime.machine_fx = {}
        needs_rebuild = true
    end
    if not runtime.selected_render then
        runtime.selected_render = {}
    end
    if runtime.needs_rebuild == nil then
        runtime.needs_rebuild = needs_rebuild
    end
    if runtime.runtime_rebuild_in_progress == nil then
        runtime.runtime_rebuild_in_progress = false
    end

    if storage.ei.selected_render then
        for _, render_entry in pairs(storage.ei.selected_render) do
            destroy_render_object(render_entry.render or render_entry)
        end
        storage.ei.selected_render = nil
    end

    if not storage.ei.matter_stabilizers then
        storage.ei.matter_stabilizers = {}
    end
    if storage.ei.matter_stabilizers_count == nil then
        storage.ei.matter_stabilizers_count = 0
    end
    if not storage.ei.matter_machines then
        storage.ei.matter_machines = {}
    end
    if storage.ei.matter_machines_count == nil then
        storage.ei.matter_machines_count = 0
    end

    if needs_rebuild then
        runtime.needs_rebuild = true
    end

    runtime.version = MATTER_RUNTIME_VERSION
    return runtime
end


function model.ensure_runtime_ready()
    local runtime = model.check_global()

    if runtime.needs_rebuild and not runtime.runtime_rebuild_in_progress then
        model.rebuild_runtime_state("auto")
    end

    return storage.ei.matter_runtime
end


function model.get_player_render_list(player_index, create)
    local runtime = model.check_global()
    local render_list = runtime.selected_render[player_index]

    if not render_list and create then
        render_list = {}
        runtime.selected_render[player_index] = render_list
    end

    return render_list
end


function model.remove_rendering_by_unit(unit_number)
    local runtime = model.check_global()
    if not runtime.selected_render then
        return
    end

    for _, render_list in pairs(runtime.selected_render) do
        local index = #render_list
        while index >= 1 do
            local render_entry = render_list[index]
            if render_entry.source_unit == unit_number or render_entry.target_unit == unit_number then
                destroy_render_object(render_entry.render)
                table.remove(render_list, index)
            end
            index = index - 1
        end
    end
end


function model.ensure_surface_queue(runtime, surface_index)
    local queue = runtime.machine_surface_queues[surface_index]
    if not queue then
        queue = new_surface_queue()
        runtime.machine_surface_queues[surface_index] = queue
    end

    return queue
end


function model.sync_active_surface(runtime, surface_index)
    local count = runtime.machine_surface_counts[surface_index] or 0
    local position = runtime.active_surface_positions[surface_index]

    if count > 0 and not position then
        table.insert(runtime.active_surfaces, surface_index)
        runtime.active_surface_positions[surface_index] = #runtime.active_surfaces
        return
    end

    if count <= 0 and position then
        local last_index = #runtime.active_surfaces
        local last_surface = runtime.active_surfaces[last_index]

        runtime.active_surfaces[position] = last_surface
        runtime.active_surfaces[last_index] = nil
        runtime.active_surface_positions[surface_index] = nil

        if last_surface and last_surface ~= surface_index then
            runtime.active_surface_positions[last_surface] = position
        end

        if runtime.active_surface_cursor > #runtime.active_surfaces then
            runtime.active_surface_cursor = 1
        end
    end
end


function model.add_machine_to_surface_queue(runtime, machine_data)
    local surface_index = machine_data.surface_index
    local queue = model.ensure_surface_queue(runtime, surface_index)

    if queue.positions[machine_data.unit_number] then
        return
    end

    table.insert(queue.items, machine_data.unit_number)
    queue.positions[machine_data.unit_number] = #queue.items

    runtime.machine_surface_counts[surface_index] = (runtime.machine_surface_counts[surface_index] or 0) + 1
    model.sync_active_surface(runtime, surface_index)
end


function model.remove_machine_from_surface_queue(runtime, machine_data)
    local surface_index = machine_data.surface_index
    local queue = runtime.machine_surface_queues[surface_index]
    if not queue then
        return
    end

    local index = queue.positions[machine_data.unit_number]
    if not index then
        return
    end

    local last_index = #queue.items
    local last_unit_number = queue.items[last_index]

    queue.items[index] = last_unit_number
    queue.items[last_index] = nil
    queue.positions[machine_data.unit_number] = nil

    if last_unit_number and last_unit_number ~= machine_data.unit_number then
        queue.positions[last_unit_number] = index
    end

    if queue.cursor > #queue.items then
        queue.cursor = 1
    end

    runtime.machine_surface_counts[surface_index] = math.max(
        0,
        (runtime.machine_surface_counts[surface_index] or 0) - 1
    )
    model.sync_active_surface(runtime, surface_index)
end


function model.add_to_chunk_store(chunk_store, surface_index, chunk_x, chunk_y, unit_number)
    local bucket = get_chunk_bucket(chunk_store, surface_index, chunk_x, chunk_y, true)
    bucket[unit_number] = true
end


function model.remove_from_chunk_store(chunk_store, surface_index, chunk_x, chunk_y, unit_number)
    local bucket, key, surface_store = get_chunk_bucket(chunk_store, surface_index, chunk_x, chunk_y, false)
    if not bucket then
        return
    end

    bucket[unit_number] = nil

    if next(bucket) == nil then
        surface_store[key] = nil
    end

    if surface_store and next(surface_store) == nil then
        chunk_store[surface_index] = nil
    end
end


function model.link_stabilizer_and_machine(stabilizer_data, machine_data)
    stabilizer_data.linked_machines[machine_data.unit_number] = true
    machine_data.nearby_stabilizers[stabilizer_data.unit_number] = true
end


function model.query_runtime_registry_in_range(runtime, registry, chunk_store, surface, position, range)
    local results = {}
    local surface_index = get_surface_index(surface)
    if not surface_index then
        return results
    end

    local surface_store = chunk_store[surface_index]
    if not surface_store then
        return results
    end

    local min_chunk_x, max_chunk_x, min_chunk_y, max_chunk_y = get_chunk_coverage(position, range)
    local max_range_sqr = range * range

    for chunk_x = min_chunk_x, max_chunk_x do
        for chunk_y = min_chunk_y, max_chunk_y do
            local bucket = surface_store[get_chunk_key(chunk_x, chunk_y)]
            if bucket then
                for unit_number, _ in pairs(bucket) do
                    local data = registry[unit_number]
                    local entity = data and data.entity
                    if model.check_entity(entity)
                        and is_within_range_squared(entity.position, position, max_range_sqr) then
                        table.insert(results, data)
                    end
                end
            end
        end
    end

    return results
end


function model.query_nearby_stabilizers(runtime, surface, position, range)
    return model.query_runtime_registry_in_range(runtime, runtime.stabilizers, runtime.stabilizer_chunks, surface, position, range)
end


function model.query_nearby_machines(runtime, surface, position, range)
    return model.query_runtime_registry_in_range(runtime, runtime.machines, runtime.machine_chunks, surface, position, range)
end


function model.remove_stabilizer_by_unit(runtime, unit_number)
    local stabilizer_data = runtime.stabilizers[unit_number]
    if not stabilizer_data then
        storage.ei.matter_stabilizers[unit_number] = nil
        return
    end

    for machine_unit_number, _ in pairs(stabilizer_data.linked_machines) do
        local machine_data = runtime.machines[machine_unit_number]
        if machine_data then
            machine_data.nearby_stabilizers[unit_number] = nil
        end
    end

    model.remove_from_chunk_store(
        runtime.stabilizer_chunks,
        stabilizer_data.surface_index,
        stabilizer_data.chunk_x,
        stabilizer_data.chunk_y,
        unit_number
    )

    runtime.stabilizers[unit_number] = nil
    runtime.stabilizer_count = math.max(0, runtime.stabilizer_count - 1)
    storage.ei.matter_stabilizers[unit_number] = nil
    storage.ei.matter_stabilizers_count = runtime.stabilizer_count

    model.remove_rendering_by_unit(unit_number)
end


function model.remove_matter_machine_by_unit(runtime, unit_number)
    local machine_data = runtime.machines[unit_number]
    if not machine_data then
        storage.ei.matter_machines[unit_number] = nil
        return
    end

    for stabilizer_unit_number, _ in pairs(machine_data.nearby_stabilizers) do
        local stabilizer_data = runtime.stabilizers[stabilizer_unit_number]
        if stabilizer_data then
            stabilizer_data.linked_machines[unit_number] = nil
        end
    end

    model.remove_from_chunk_store(
        runtime.machine_chunks,
        machine_data.surface_index,
        machine_data.chunk_x,
        machine_data.chunk_y,
        unit_number
    )
    model.remove_machine_from_surface_queue(runtime, machine_data)
    model.destroy_machine_fx(runtime, unit_number)

    runtime.machines[unit_number] = nil
    runtime.machine_count = math.max(0, runtime.machine_count - 1)
    storage.ei.matter_machines[unit_number] = nil
    storage.ei.matter_machines_count = runtime.machine_count

    model.remove_rendering_by_unit(unit_number)
end


function model.register_stabilizer(entity)
    local runtime = model.check_global()
    if not model.check_entity(entity) or not entity.unit_number then
        return
    end

    if runtime.stabilizers[entity.unit_number] then
        model.remove_stabilizer_by_unit(runtime, entity.unit_number)
    end

    local chunk_x, chunk_y = get_chunk_coordinates(entity.position)
    local stabilizer_data = {
        unit_number = entity.unit_number,
        entity = entity,
        surface_index = entity.surface.index,
        chunk_x = chunk_x,
        chunk_y = chunk_y,
        weight = model.get_stabilizer_weight(entity),
        linked_machines = {}
    }

    runtime.stabilizers[entity.unit_number] = stabilizer_data
    runtime.stabilizer_count = runtime.stabilizer_count + 1
    storage.ei.matter_stabilizers[entity.unit_number] = entity
    storage.ei.matter_stabilizers_count = runtime.stabilizer_count

    model.add_to_chunk_store(
        runtime.stabilizer_chunks,
        stabilizer_data.surface_index,
        chunk_x,
        chunk_y,
        entity.unit_number
    )

    local nearby_machines = model.query_nearby_machines(runtime, entity.surface, entity.position, MATTER_RANGE)
    for _, machine_data in pairs(nearby_machines) do
        model.link_stabilizer_and_machine(stabilizer_data, machine_data)
    end
end


function model.register_matter_machine(entity)
    local runtime = model.check_global()
    if not model.check_entity(entity) or not entity.unit_number then
        return
    end

    if runtime.machines[entity.unit_number] then
        model.remove_matter_machine_by_unit(runtime, entity.unit_number)
    end

    local chunk_x, chunk_y = get_chunk_coordinates(entity.position)
    local machine_data = {
        unit_number = entity.unit_number,
        entity = entity,
        surface_index = entity.surface.index,
        chunk_x = chunk_x,
        chunk_y = chunk_y,
        nearby_stabilizers = {},
        warning_state = "stable",
        critical_since_tick = nil,
        last_warning_tick = 0,
        last_imminent_warning_tick = 0,
        last_crackle_tick = 0,
        last_arc_tick = 0,
        pulse_seed = entity.unit_number % 360
    }

    runtime.machines[entity.unit_number] = machine_data
    runtime.machine_count = runtime.machine_count + 1
    storage.ei.matter_machines[entity.unit_number] = entity
    storage.ei.matter_machines_count = runtime.machine_count

    model.add_to_chunk_store(
        runtime.machine_chunks,
        machine_data.surface_index,
        chunk_x,
        chunk_y,
        entity.unit_number
    )
    model.add_machine_to_surface_queue(runtime, machine_data)

    local nearby_stabilizers = model.query_nearby_stabilizers(runtime, entity.surface, entity.position, MATTER_RANGE)
    for _, stabilizer_data in pairs(nearby_stabilizers) do
        model.link_stabilizer_and_machine(stabilizer_data, machine_data)
    end
end


function model.unregister_stabilizer(entity)
    local runtime = model.check_global()
    if not entity or not entity.unit_number then
        return
    end

    model.remove_stabilizer_by_unit(runtime, entity.unit_number)
end


function model.unregister_matter_machine(entity)
    local runtime = model.check_global()
    if not entity or not entity.unit_number then
        return
    end

    model.remove_matter_machine_by_unit(runtime, entity.unit_number)
end


function model.get_risk_tier(risk_per_second_estimate)
    if risk_per_second_estimate >= RISK_CRITICAL_THRESHOLD then
        return "critical"
    end

    if risk_per_second_estimate >= RISK_STRAINED_THRESHOLD then
        return "strained"
    end

    return "stable"
end


function model.draw_warning_text(entity, localised_text, color, ttl, scale)
    if not model.check_entity(entity) then
        return
    end

    rendering.draw_text{
        text = localised_text,
        surface = entity.surface,
        target = {
            entity = entity,
            offset = {0, -2.15}
        },
        color = color,
        alignment = "center",
        vertical_alignment = "middle",
        scale = scale,
        time_to_live = ttl,
        forces = {entity.force}
    }
end


function model.ensure_machine_light(runtime, machine_data)
    local fx_state = runtime.machine_fx[machine_data.unit_number]
    if fx_state
        and fx_state.light and fx_state.light.valid
        and fx_state.halo and fx_state.halo.valid
        and fx_state.outer_aura and fx_state.outer_aura.valid then
        return fx_state
    end

    if fx_state then
        destroy_render_object(fx_state.light)
        destroy_render_object(fx_state.halo)
        destroy_render_object(fx_state.outer_aura)
    end

    local light = rendering.draw_light{
        sprite = GLOW_SPRITE,
        scale = 1.45,
        intensity = 1.08,
        color = {r = 0.72, g = 0.24, b = 0.96},
        target = machine_data.entity,
        surface = machine_data.entity.surface,
        blend_mode = "multiplicative",
        apply_runtime_tint = true,
        draw_as_glow = true,
        time_to_live = 0,
        forces = {machine_data.entity.force}
    }

    local halo = rendering.draw_light{
        sprite = GLOW_SPRITE,
        scale = 3.35,
        intensity = 0.48,
        color = {r = 0.42, g = 0.08, b = 0.72},
        target = machine_data.entity,
        surface = machine_data.entity.surface,
        blend_mode = "multiplicative",
        apply_runtime_tint = true,
        draw_as_glow = true,
        time_to_live = 0,
        forces = {machine_data.entity.force}
    }

    local outer_aura = rendering.draw_light{
        sprite = GLOW_SPRITE,
        scale = 4.9,
        intensity = 0.0,
        color = {r = 0.2, g = 0.03, b = 0.38},
        target = machine_data.entity,
        surface = machine_data.entity.surface,
        blend_mode = "multiplicative-with-alpha",
        apply_runtime_tint = true,
        draw_as_glow = true,
        time_to_live = 0,
        forces = {machine_data.entity.force}
    }

    runtime.machine_fx[machine_data.unit_number] = {
        light = light,
        halo = halo,
        outer_aura = outer_aura
    }

    return runtime.machine_fx[machine_data.unit_number]
end


function model.spawn_machine_crackle(machine_data, tier)
    local entity = machine_data.entity
    if not model.check_entity(entity) then
        return
    end

    local pos = entity.position
    local offsets = {
        {x = -1.05, y = -1.05},
        {x =  1.05, y = -1.05},
        {x = -1.05, y =  1.05},
        {x =  1.05, y =  1.05}
    }
    local crackle_count = tier == "critical" and 2 or 1

    for _ = 1, crackle_count do
        local offset = offsets[math.random(1, #offsets)]
        local crackle_position = {
            x = pos.x + offset.x,
            y = pos.y + offset.y
        }

        rendering.draw_animation{
            animation = CRACKLE_ANIMATION,
            target = crackle_position,
            surface = entity.surface,
            render_layer = "object",
            x_scale = tier == "critical" and 0.75 or 0.6,
            y_scale = tier == "critical" and 0.75 or 0.6,
            time_to_live = tier == "critical" and 36 or 24
        }

        entity.surface.create_trivial_smoke{
            name = "electric-smoke",
            position = crackle_position
        }
    end
end


function model.spawn_machine_arc(machine_data, active_stabilizers)
    local entity = machine_data.entity
    if not model.check_entity(entity) or #active_stabilizers == 0 then
        return
    end

    local stabilizer_data = active_stabilizers[math.random(1, #active_stabilizers)]
    local stabilizer = stabilizer_data and stabilizer_data.entity
    if not model.check_entity(stabilizer) then
        return
    end

    entity.surface.create_entity{
        name = ARC_BEAM_NAME,
        position = stabilizer.position,
        source = stabilizer,
        target = entity,
        force = entity.force,
        duration = 18
    }

    entity.surface.create_trivial_smoke{
        name = "electric-smoke",
        position = stabilizer.position
    }
    entity.surface.create_trivial_smoke{
        name = "electric-smoke",
        position = entity.position
    }
end


function model.update_machine_presentation(runtime, machine_data, risk_tier, risk_per_second_estimate, active_stabilizers)
    local entity = machine_data.entity
    if not model.check_entity(entity) then
        return
    end

    local fx_state = model.ensure_machine_light(runtime, machine_data)
    local light = fx_state.light
    local halo = fx_state.halo
    local outer_aura = fx_state.outer_aura
    local tick = game.tick
    local pulse_period = 16
    local scale_base = 1.38
    local scale_delta = 0.22
    local intensity_base = 1.06
    local intensity_delta = 0.2
    local halo_scale_base = 3.1
    local halo_scale_delta = 0.45
    local halo_intensity_base = 0.46
    local halo_intensity_delta = 0.13
    local outer_scale_base = 4.9
    local outer_scale_delta = 0.25
    local outer_intensity_base = 0.0
    local outer_intensity_delta = 0.0
    local color = {r = 0.7, g = 0.22, b = 0.92}
    local halo_color = {r = 0.42, g = 0.08, b = 0.72}
    local outer_color = {r = 0.2, g = 0.03, b = 0.38}
    local crackle_cooldown = STRAINED_CRACKLE_COOLDOWN_TICKS

    if risk_tier == "strained" then
        pulse_period = 12
        scale_base = 1.58
        scale_delta = 0.3
        intensity_base = 1.28
        intensity_delta = 0.28
        halo_scale_base = 3.7
        halo_scale_delta = 0.6
        halo_intensity_base = 0.6
        halo_intensity_delta = 0.18
        outer_scale_base = 5.1
        outer_scale_delta = 0.3
        color = {r = 0.88, g = 0.3, b = 1.0}
        halo_color = {r = 0.58, g = 0.12, b = 0.84}
        outer_color = {r = 0.24, g = 0.04, b = 0.46}
        crackle_cooldown = STRAINED_CRACKLE_COOLDOWN_TICKS
    elseif risk_tier == "critical" then
        pulse_period = 8
        scale_base = 1.82
        scale_delta = 0.42
        intensity_base = 1.56
        intensity_delta = 0.4
        halo_scale_base = 4.4
        halo_scale_delta = 0.9
        halo_intensity_base = 0.78
        halo_intensity_delta = 0.24
        outer_scale_base = 5.6
        outer_scale_delta = 1.15
        outer_intensity_base = 0.22
        outer_intensity_delta = 0.14
        color = {r = 1.0, g = 0.62, b = 1.0}
        halo_color = {r = 0.85, g = 0.24, b = 1.0}
        outer_color = {r = 0.98, g = 0.32, b = 1.0}
        crackle_cooldown = CRITICAL_CRACKLE_COOLDOWN_TICKS
    end

    local pulse = 0.5 + 0.5 * math.sin((tick + machine_data.pulse_seed) / pulse_period)
    local glow_pressure = math.min(0.28, risk_per_second_estimate * 0.12)
    local halo_pressure = math.min(0.18, risk_per_second_estimate * 0.07)
    local outer_pressure = 0
    if risk_tier == "critical" then
        outer_pressure = math.min(0.12, risk_per_second_estimate * 0.05)
    end
    light.color = color
    light.scale = scale_base + scale_delta * pulse
    light.intensity = intensity_base + intensity_delta * pulse + glow_pressure
    halo.color = halo_color
    halo.scale = halo_scale_base + halo_scale_delta * pulse
    halo.intensity = halo_intensity_base + halo_intensity_delta * pulse + halo_pressure
    outer_aura.color = outer_color
    outer_aura.scale = outer_scale_base + outer_scale_delta * pulse
    outer_aura.intensity = outer_intensity_base + outer_intensity_delta * pulse + outer_pressure

    local previous_state = machine_data.warning_state or "stable"
    machine_data.warning_state = risk_tier

    if risk_tier == "critical" then
        if previous_state ~= "critical" then
            machine_data.critical_since_tick = tick

            if tick - (machine_data.last_warning_tick or 0) >= WARNING_COOLDOWN_TICKS then
                model.draw_warning_text(
                    entity,
                    {"exotic-industries.matter-lattice-failing"},
                    {r = 1.0, g = 0.4, b = 0.9},
                    240,
                    1.8
                )
                machine_data.last_warning_tick = tick
            end
        end

        if tick - (machine_data.last_crackle_tick or 0) >= crackle_cooldown then
            model.spawn_machine_crackle(machine_data, risk_tier)
            machine_data.last_crackle_tick = tick
        end

        if tick - (machine_data.last_arc_tick or 0) >= CRITICAL_ARC_COOLDOWN_TICKS then
            model.spawn_machine_arc(machine_data, active_stabilizers)
            machine_data.last_arc_tick = tick
        end

        if machine_data.critical_since_tick
            and tick - machine_data.critical_since_tick >= IMMINENT_WARNING_DELAY_TICKS
            and tick - (machine_data.last_imminent_warning_tick or 0) >= WARNING_COOLDOWN_TICKS then
            model.draw_warning_text(
                entity,
                {"exotic-industries.entropic-cascade-imminent"},
                {r = 1.0, g = 0.25, b = 0.55},
                300,
                2.0
            )
            machine_data.last_imminent_warning_tick = tick
        end
    else
        machine_data.critical_since_tick = nil

        if risk_tier == "strained"
            and tick - (machine_data.last_crackle_tick or 0) >= crackle_cooldown then
            model.spawn_machine_crackle(machine_data, risk_tier)
            machine_data.last_crackle_tick = tick
        end
    end
end


function model.collect_machine_stabilizers(runtime, machine_data)
    local active_stabilizers = {}
    local stabilizer_weight = 0
    local stale_stabilizers = {}

    for stabilizer_unit_number, _ in pairs(machine_data.nearby_stabilizers) do
        local stabilizer_data = runtime.stabilizers[stabilizer_unit_number]
        local stabilizer = stabilizer_data and stabilizer_data.entity

        if not model.check_entity(stabilizer) then
            table.insert(stale_stabilizers, stabilizer_unit_number)
        elseif is_within_range_squared(stabilizer.position, machine_data.entity.position, MATTER_RANGE_SQR) then
            if not stabilizer.disabled_by_control_behavior then
                stabilizer_weight = stabilizer_weight + (stabilizer_data.weight or 1)
                table.insert(active_stabilizers, stabilizer_data)
            end
        else
            table.insert(stale_stabilizers, stabilizer_unit_number)
        end
    end

    for _, stale_unit_number in pairs(stale_stabilizers) do
        model.remove_stabilizer_by_unit(runtime, stale_unit_number)
    end

    return stabilizer_weight, active_stabilizers
end


function model.reset_machine_state(machine_data)
    machine_data.warning_state = "stable"
    machine_data.critical_since_tick = nil
end


function model.update_matter_machine(machine_data)
    local runtime = model.check_global()
    if not machine_data then
        return false
    end

    local entity = machine_data.entity
    if not model.check_entity(entity) then
        model.remove_matter_machine_by_unit(runtime, machine_data.unit_number)
        return false
    end

    if not entity.is_crafting() then
        model.reset_machine_state(machine_data)
        model.destroy_machine_fx(runtime, machine_data.unit_number)
        return true
    end

    local stabilizer_weight, active_stabilizers = model.collect_machine_stabilizers(runtime, machine_data)
    local progress = entity.crafting_progress or 0
    local base_chance = model.get_machine_base_chance(entity)
    local decay = 2.43
    local updates_per_entity = model.get_updates_per_entity(runtime.machine_count)
    local risk_per_second_estimate = base_chance / ((stabilizer_weight + 1) ^ decay)
    risk_per_second_estimate = risk_per_second_estimate * (1 + progress) ^ 3

    local chance = risk_per_second_estimate / updates_per_entity
    local risk_tier = model.get_risk_tier(risk_per_second_estimate)

    model.update_machine_presentation(runtime, machine_data, risk_tier, risk_per_second_estimate, active_stabilizers)

    if math.random() < chance then
        game.print({"exotic-industries.exotic-assembler-explode", entity.name, entity.gps_tag})
        ei_lib.crystal_echo_floating("Containment Breach: Rationality Compromised.", entity, 6000, nil)
        entity.surface.create_entity{
            name = "ei-matter-explosion",
            position = entity.position,
            target = entity.position,
            speed = 0.3,
            force = entity.force
        }
    end

    return true
end


function model.rebuild_runtime_state(reason)
    local runtime = model.check_global()
    if runtime.runtime_rebuild_in_progress then
        return
    end

    runtime.runtime_rebuild_in_progress = true

    model.destroy_runtime_state(runtime)
    model.reset_runtime_storage(runtime)

    for _, surface in pairs(game.surfaces) do
        local stabilizers = surface.find_entities_filtered({
            name = model.stabilizer_names
        })

        for _, entity in pairs(stabilizers) do
            if model.check_entity(entity) then
                model.register_stabilizer(entity)
            end
        end
    end

    for _, surface in pairs(game.surfaces) do
        local matter_machines = surface.find_entities_filtered({
            name = model.matter_machine_names
        })

        for _, entity in pairs(matter_machines) do
            if model.check_entity(entity) then
                model.register_matter_machine(entity)
            end
        end
    end

    runtime = storage.ei.matter_runtime
    runtime.needs_rebuild = false
    runtime.runtime_rebuild_in_progress = false

    if reason == "manual" then
        storage.ei.stabilizer_break_point = nil
    end
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

    local render_list = model.get_player_render_list(player.index, true)
    for _, render_entry in pairs(render_list) do
        if render_entry.type == "connection"
            and render_entry.source_unit == source.unit_number
            and render_entry.target_unit == target.unit_number then
            return
        end
    end

    local render_object = rendering.draw_line{
        color = {r = 0, g = 1, b = 0},
        width = 0.2,
        from = source.position,
        to = target.position,
        surface = source.surface,
        players = {player},
        forces = {source.force},
        draw_on_ground = true,
    }

    table.insert(render_list, {
        render = render_object,
        source_unit = source.unit_number,
        target_unit = target.unit_number,
        type = "connection"
    })
end


function model.draw_stabilizer_range(entity, player)

    if not model.check_entity(entity) then
        return
    end

    local render_list = model.get_player_render_list(player.index, true)
    for _, render_entry in pairs(render_list) do
        if render_entry.type == "range" and render_entry.source_unit == entity.unit_number then
            return
        end
    end

    local range = model.stabilizers[entity.name]
    local scale = range / 4

    local render_object = rendering.draw_sprite{
        sprite = "ei-stabilizer-radius",
        target = entity,
        surface = entity.surface,
        players = {player},
        forces = {entity.force},
        render_layer = "radius-visualization",
        x_scale = scale,
        y_scale = scale,
    }

    table.insert(render_list, {
        render = render_object,
        source_unit = entity.unit_number,
        type = "range"
    })
end


function model.remove_rendering(entity)
    if not entity or not entity.unit_number then
        return
    end

    model.remove_rendering_by_unit(entity.unit_number)
end


function model.clear_rendering(player)

    if not player or not player.valid then
        return
    end

    local cursor_stack = player.cursor_stack
    if cursor_stack and cursor_stack.valid_for_read then
        if model.stabilizers[cursor_stack.name] or model.matter_machines[cursor_stack.name] then
            return
        end
    end

    local runtime = model.check_global()
    local render_list = runtime.selected_render[player.index]
    if not render_list then
        return
    end

    model.destroy_player_render_list(render_list)
    runtime.selected_render[player.index] = {}
end


function model.stabilizer_selected(player, entity)

    if not model.check_entity(entity) then
        return
    end

    local runtime = model.check_global()
    local matter_machines = model.query_nearby_machines(runtime, entity.surface, entity.position, model.stabilizers[entity.name])

    for _, machine_data in pairs(matter_machines) do
        if model.check_entity(machine_data.entity) then
            model.draw_connection(entity, machine_data.entity, player)
        end
    end

end


function model.stabilizer_on_cursor(player)

    local position = player.position
    if not position then
        return
    end

    local runtime = model.check_global()
    local stabilizers = model.query_nearby_stabilizers(runtime, player.surface, position, 100)

    for _, stabilizer_data in pairs(stabilizers) do
        if model.check_entity(stabilizer_data.entity) then
            model.draw_stabilizer_range(stabilizer_data.entity, player)
            model.stabilizer_selected(player, stabilizer_data.entity)
        end
    end

end


function model.on_player_left_game(player_index)
    local runtime = model.check_global()
    local render_list = runtime.selected_render[player_index]
    if not render_list then
        return
    end

    model.destroy_player_render_list(render_list)
    runtime.selected_render[player_index] = nil
end


--HANDLERS
------------------------------------------------------------------------------------------------------

function model.on_built_entity(entity)
    local runtime = model.check_global()
    if runtime.needs_rebuild and not runtime.runtime_rebuild_in_progress then
        model.rebuild_runtime_state("auto")
    end

    if model.stabilizers[entity.name] then
        model.register_stabilizer(entity)
    elseif model.matter_machines[entity.name] then
        model.register_matter_machine(entity)
    end
end


function model.on_destroyed_entity(entity)
    local runtime = model.check_global()
    if runtime.needs_rebuild and not runtime.runtime_rebuild_in_progress then
        model.rebuild_runtime_state("auto")
    end

    if model.stabilizers[entity.name] then
        model.unregister_stabilizer(entity)
    elseif model.matter_machines[entity.name] then
        model.unregister_matter_machine(entity)
    end
end


function model.on_selected_entity_changed(event)

    local player = game.get_player(event.player_index)
    if player == nil then
        return
    end

    local new_entity = player.selected
    model.clear_rendering(player)

    if new_entity == nil then
        return
    end

    if model.stabilizers[new_entity.name] then
        model.stabilizer_selected(player, new_entity)
    end

end


function model.on_player_cursor_stack_changed(event)

    local player = game.get_player(event.player_index)
    if player == nil then
        return
    end

    model.clear_rendering(player)

    if player.cursor_stack and player.cursor_stack.valid_for_read then
        local item = player.cursor_stack.name

        if model.stabilizers[item] or model.matter_machines[item] then
            model.stabilizer_on_cursor(player)
        end
    end

end


function model.update()
    local runtime = model.ensure_runtime_ready()
    if not runtime or runtime.runtime_rebuild_in_progress then
        return false
    end

    local active_surface_count = #runtime.active_surfaces
    if active_surface_count == 0 then
        return false
    end

    if runtime.active_surface_cursor > active_surface_count then
        runtime.active_surface_cursor = 1
    end

    local surface_attempts = active_surface_count
    while surface_attempts > 0 do
        local surface_index = runtime.active_surfaces[runtime.active_surface_cursor]
        runtime.active_surface_cursor = runtime.active_surface_cursor + 1
        if runtime.active_surface_cursor > active_surface_count then
            runtime.active_surface_cursor = 1
        end

        local queue = surface_index and runtime.machine_surface_queues[surface_index]
        if queue and #queue.items > 0 then
            if queue.cursor > #queue.items then
                queue.cursor = 1
            end

            local queue_attempts = #queue.items
            while queue_attempts > 0 do
                local unit_number = queue.items[queue.cursor]
                queue.cursor = queue.cursor + 1
                if queue.cursor > #queue.items then
                    queue.cursor = 1
                end

                local machine_data = unit_number and runtime.machines[unit_number]
                if machine_data then
                    model.update_matter_machine(machine_data)
                    return true
                end

                queue_attempts = queue_attempts - 1
            end
        end

        surface_attempts = surface_attempts - 1
    end

    return false
end


commands.add_command("rescan_matter_stabilizers", "Rebuilds matter stabilizer links, queues, and containment FX state.", function(command)
    local player = command.player_index and game.get_player(command.player_index) or nil
    if command.player_index and (not player or not player.admin) then
        return
    end

    ei_lib.crystal_echo("Matter stabilizer runtime rescan initiated.")
    model.rebuild_runtime_state("manual")
    ei_lib.crystal_echo("Matter stabilizer runtime rescan complete.")
end)


return model
