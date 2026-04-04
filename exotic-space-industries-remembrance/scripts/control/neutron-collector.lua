local model = {}

local NEUTRON_RUNTIME_VERSION = 1
local NEUTRON_COLLECTOR_NAME = "ei-neutron-collector"
local FUSION_REACTOR_NAME = "ei-fusion-reactor"
local DEFAULT_FUSION_RECIPE = "ei-fusion-F1__ei-heated-deuterium-F2__ei-heated-tritium-TM__medium-FM__medium"

--====================================================================================================
--NEUTRON COLLECTOR
--====================================================================================================

model.range = 10 + 1.5 -- range of neutron collector in tiles + 1.5 collector size
model.neutron_sources = {
    ["ei-high-temperature-reactor"] = -20,
    ["nuclear-reactor"] = -30,
    ["ei-fission-facility"] = -40,
    ["ei-castor"] = -50,
    [FUSION_REACTOR_NAME] = 10,
}
model.neutron_source_names = {
    "ei-high-temperature-reactor",
    "nuclear-reactor",
    "ei-fission-facility",
    "ei-castor",
    FUSION_REACTOR_NAME,
}
model.dist_buffs = {
    [FUSION_REACTOR_NAME] = 3,
}

local function make_dirty_queue()
    return {
        items = {},
        head = 1,
        tail = 0,
    }
end

local function reset_dirty_queue(queue)
    queue.items = {}
    queue.head = 1
    queue.tail = 0
    return queue
end

local function compact_dirty_queue(queue)
    if queue.head > queue.tail then
        return reset_dirty_queue(queue)
    end

    if queue.head > 64 and queue.head > math.floor((queue.tail - queue.head + 1) / 2) then
        local new_items = {}
        local new_tail = 0

        for index = queue.head, queue.tail do
            local unit_number = queue.items[index]
            if unit_number ~= nil then
                new_tail = new_tail + 1
                new_items[new_tail] = unit_number
            end
        end

        queue.items = new_items
        queue.head = 1
        queue.tail = new_tail
    end

    return queue
end

--UTIL
------------------------------------------------------------------------------------------------------

function model.calc_distance(entity, source)
    local dist = math.sqrt((entity.position.x - source.position.x) ^ 2 + (entity.position.y - source.position.y) ^ 2)
    local buff = model.dist_buffs[source.name] or 0
    return dist - buff
end


function model.calc_fusion_flux(fuel1, fuel2, temp_mode, fuel_mode)
    if fuel1 == nil or fuel2 == nil then
        return 0
    end

    local fuel1_multiplier = ei_data.fusion.fuel_neutron_flux[fuel1]
    local fuel2_multiplier = ei_data.fusion.fuel_neutron_flux[fuel2]

    if fuel1_multiplier == nil or fuel2_multiplier == nil then
        return 0
    end

    local temp_multiplier = ei_data.fusion.temp_neutron_flux[temp_mode]
    local fuel_multiplier = ei_data.fusion.injection_neutron_flux[fuel_mode]

    if temp_multiplier == nil or fuel_multiplier == nil then
        return 0
    end

    return fuel1_multiplier * fuel2_multiplier * temp_multiplier * fuel_multiplier
end


function model.entity_check(entity)
    return entity ~= nil and entity.valid == true
end


function model.get_entity_recipe_name(entity)
    if not model.entity_check(entity) or not entity.get_recipe then
        return nil
    end

    local recipe = entity.get_recipe()
    return recipe and recipe.name or nil
end


function model.clear_legacy_runtime_fields()
    if not storage or not storage.ei then
        return
    end

    -- Legacy source bookkeeping was hash-walked every pass. The new runtime rebuilds
    -- its dense queues lazily and clears the old tables once migration is complete.
    storage.ei["neutron_sources"] = nil
    storage.ei["neutron_script_break_point"] = nil
end


function model.check_global()
    if not storage.ei then
        storage.ei = {}
    end

    if not storage.ei["neutron_collector_animation"] then
        storage.ei["neutron_collector_animation"] = {}
    end

    local runtime = storage.ei.neutron_runtime
    local needs_rebuild = false

    if not runtime then
        runtime = {}
        storage.ei.neutron_runtime = runtime
        needs_rebuild = true
    end

    -- The neutron runtime keeps two hot paths dense:
    -- 1. dirty collectors waiting for a full nearest-source recompute
    -- 2. connected sources that still need low-lag active/inactive polling
    local function ensure_component(name, default)
        if runtime[name] == nil then
            runtime[name] = default
            needs_rebuild = true
        end
    end

    ensure_component("sources_by_unit", {})
    ensure_component("collectors_by_unit", {})
    ensure_component("connected_source_units", {})
    ensure_component("connected_source_index_by_unit", {})
    ensure_component("connected_source_count", 0)
    ensure_component("dirty_collector_queue", make_dirty_queue())
    ensure_component("dirty_collector_count", 0)
    ensure_component("poll_cursor", 1)
    ensure_component("prefer_poll_next", false)
    ensure_component("runtime_version", NEUTRON_RUNTIME_VERSION)
    ensure_component("needs_rebuild", false)
    ensure_component("runtime_rebuild_in_progress", false)

    if runtime.runtime_version ~= NEUTRON_RUNTIME_VERSION then
        needs_rebuild = true
    end

    if needs_rebuild then
        runtime.needs_rebuild = true
    end

    return runtime
end


function model.reset_runtime_storage(runtime)
    runtime.sources_by_unit = {}
    runtime.collectors_by_unit = {}
    runtime.connected_source_units = {}
    runtime.connected_source_index_by_unit = {}
    runtime.connected_source_count = 0
    runtime.dirty_collector_queue = make_dirty_queue()
    runtime.dirty_collector_count = 0
    runtime.poll_cursor = 1
    runtime.prefer_poll_next = false
    runtime.runtime_version = NEUTRON_RUNTIME_VERSION
    runtime.needs_rebuild = false

    model.clear_legacy_runtime_fields()
end


function model.ensure_runtime_ready()
    local runtime = model.check_global()
    if runtime.runtime_rebuild_in_progress then
        return runtime
    end

    if runtime.needs_rebuild then
        model.rebuild_runtime_state("auto")
        runtime = storage.ei and storage.ei.neutron_runtime or runtime
    end

    return runtime
end


function model.get_dirty_queue(runtime)
    local queue = runtime.dirty_collector_queue
    if not queue then
        queue = make_dirty_queue()
        runtime.dirty_collector_queue = queue
    end

    queue.items = queue.items or {}
    queue.head = queue.head or 1
    queue.tail = queue.tail or 0

    return queue
end


function model.add_connected_source(runtime, source_unit)
    if runtime.connected_source_index_by_unit[source_unit] then
        return
    end

    local new_index = (runtime.connected_source_count or 0) + 1
    runtime.connected_source_units[new_index] = source_unit
    runtime.connected_source_index_by_unit[source_unit] = new_index
    runtime.connected_source_count = new_index
end


function model.remove_connected_source(runtime, source_unit)
    local remove_index = runtime.connected_source_index_by_unit[source_unit]
    if not remove_index then
        return
    end

    local last_index = runtime.connected_source_count or 0
    local last_unit = runtime.connected_source_units[last_index]

    runtime.connected_source_units[remove_index] = last_unit
    runtime.connected_source_units[last_index] = nil
    runtime.connected_source_index_by_unit[source_unit] = nil

    if last_unit ~= nil and last_unit ~= source_unit then
        runtime.connected_source_index_by_unit[last_unit] = remove_index
    end

    runtime.connected_source_count = math.max(0, last_index - 1)

    if runtime.connected_source_count == 0 then
        runtime.poll_cursor = 1
    elseif runtime.poll_cursor > runtime.connected_source_count then
        runtime.poll_cursor = 1
    end
end


function model.get_source_entry(runtime, source)
    local unit_number = source and source.unit_number or nil
    if not unit_number then
        return nil
    end

    local entry = runtime.sources_by_unit[unit_number]
    if entry and model.entity_check(source) then
        entry.entity = source
    end

    return entry
end


function model.get_or_create_source_entry(runtime, source)
    if not model.entity_check(source) then
        return nil
    end

    if model.neutron_sources[source.name] == nil or not source.unit_number then
        return nil
    end

    local entry = runtime.sources_by_unit[source.unit_number]
    if not entry then
        entry = {
            unit_number = source.unit_number,
            entity = source,
            collectors = {},
            collector_count = 0,
            last_active_state = nil,
            last_recipe_name = nil,
            fusion_multiplier = nil,
        }
        runtime.sources_by_unit[source.unit_number] = entry
    else
        entry.entity = source
    end

    return entry
end


function model.register_collector(runtime, entity)
    if not model.entity_check(entity) or entity.name ~= NEUTRON_COLLECTOR_NAME or not entity.unit_number then
        return nil
    end

    local entry = runtime.collectors_by_unit[entity.unit_number]
    if not entry then
        entry = {
            unit_number = entity.unit_number,
            entity = entity,
            source_unit = nil,
            queued = false,
            exclude_source_unit = nil,
            last_recipe_name = nil,
            last_direction = nil,
            last_efficiency = 0,
        }
        runtime.collectors_by_unit[entity.unit_number] = entry
    else
        entry.entity = entity
    end

    return entry
end


function model.queue_dirty_collector(runtime, collector_entry, exclude_source_unit)
    if not collector_entry or not collector_entry.unit_number then
        return false
    end

    if exclude_source_unit ~= nil then
        collector_entry.exclude_source_unit = exclude_source_unit
    end

    if collector_entry.queued then
        return false
    end

    local queue = model.get_dirty_queue(runtime)
    queue.tail = queue.tail + 1
    queue.items[queue.tail] = collector_entry.unit_number
    collector_entry.queued = true
    runtime.dirty_collector_count = (runtime.dirty_collector_count or 0) + 1

    return true
end


function model.dequeue_dirty_collector(runtime)
    local queue = model.get_dirty_queue(runtime)

    while queue.head <= queue.tail do
        local unit_number = queue.items[queue.head]
        queue.items[queue.head] = nil
        queue.head = queue.head + 1

        local collector_entry = runtime.collectors_by_unit[unit_number]
        if collector_entry and collector_entry.queued then
            collector_entry.queued = false
            runtime.dirty_collector_count = math.max(0, (runtime.dirty_collector_count or 0) - 1)
            compact_dirty_queue(queue)
            return collector_entry
        end
    end

    reset_dirty_queue(queue)
    return nil
end


function model.remove_direction_animation_by_unit(unit_number)
    if not storage.ei["neutron_collector_animation"] then
        storage.ei["neutron_collector_animation"] = {}
    end

    local animation = storage.ei["neutron_collector_animation"][unit_number]
    if animation then
        animation.destroy()
        storage.ei["neutron_collector_animation"][unit_number] = nil
    end
end


function model.remove_collector_from_source(runtime, source_entry, collector_unit, clear_source_unit)
    if not source_entry or not source_entry.collectors[collector_unit] then
        return
    end

    source_entry.collectors[collector_unit] = nil
    source_entry.collector_count = math.max(0, (source_entry.collector_count or 0) - 1)

    local collector_entry = runtime.collectors_by_unit[collector_unit]
    if clear_source_unit and collector_entry and collector_entry.source_unit == source_entry.unit_number then
        collector_entry.source_unit = nil
    end

    if source_entry.collector_count <= 0 then
        model.remove_connected_source(runtime, source_entry.unit_number)
        runtime.sources_by_unit[source_entry.unit_number] = nil
    end
end


function model.disconnect_collector(runtime, collector_entry)
    if not collector_entry or not collector_entry.source_unit then
        return
    end

    local source_unit = collector_entry.source_unit
    collector_entry.source_unit = nil

    local source_entry = runtime.sources_by_unit[source_unit]
    if not source_entry then
        return
    end

    model.remove_collector_from_source(runtime, source_entry, collector_entry.unit_number, false)
end


function model.connect_collector(runtime, collector_entry, source)
    local source_entry = model.get_or_create_source_entry(runtime, source)
    if not source_entry then
        model.disconnect_collector(runtime, collector_entry)
        return nil
    end

    if collector_entry.source_unit ~= source_entry.unit_number then
        model.disconnect_collector(runtime, collector_entry)
        collector_entry.source_unit = source_entry.unit_number
    end

    if not source_entry.collectors[collector_entry.unit_number] then
        source_entry.collectors[collector_entry.unit_number] = true
        source_entry.collector_count = (source_entry.collector_count or 0) + 1
    end

    model.add_connected_source(runtime, source_entry.unit_number)

    return source_entry
end


function model.unregister_collector(runtime, collector)
    local unit_number = collector and collector.unit_number or nil
    local collector_entry = unit_number and runtime.collectors_by_unit[unit_number] or nil

    if not collector_entry and type(collector) == "table" and collector.entity ~= nil then
        collector_entry = collector
        unit_number = collector.unit_number
    end

    if not unit_number then
        return
    end

    if collector_entry then
        if collector_entry.queued then
            collector_entry.queued = false
            runtime.dirty_collector_count = math.max(0, (runtime.dirty_collector_count or 0) - 1)
        end

        model.disconnect_collector(runtime, collector_entry)
        runtime.collectors_by_unit[unit_number] = nil
    end

    model.remove_direction_animation_by_unit(unit_number)
end


function model.remove_source_entry(runtime, source_unit, queue_collectors)
    local source_entry = runtime.sources_by_unit[source_unit]
    if not source_entry then
        return
    end

    for collector_unit in pairs(source_entry.collectors) do
        local collector_entry = runtime.collectors_by_unit[collector_unit]
        if collector_entry and collector_entry.source_unit == source_unit then
            collector_entry.source_unit = nil
            if queue_collectors and model.entity_check(collector_entry.entity) then
                model.queue_dirty_collector(runtime, collector_entry)
            end
        end
    end

    model.remove_connected_source(runtime, source_unit)
    runtime.sources_by_unit[source_unit] = nil
end


function model.parse_fusion_multiplier(recipe_name)
    recipe_name = recipe_name or DEFAULT_FUSION_RECIPE

    local fuel1 = recipe_name:match("F1__(.+)%-F2__")
    local fuel2 = recipe_name:match("F2__(.+)%-TM__")
    local temp_mode = recipe_name:match("TM__(.+)%-FM__")
    local fuel_mode = recipe_name:match("FM__(.+)")

    return 2 * model.calc_fusion_flux(fuel1, fuel2, temp_mode, fuel_mode)
end


function model.get_source_fusion_multiplier(source_entry)
    local recipe_name = model.get_entity_recipe_name(source_entry.entity) or DEFAULT_FUSION_RECIPE
    if source_entry.last_recipe_name ~= recipe_name then
        source_entry.last_recipe_name = recipe_name
        source_entry.fusion_multiplier = model.parse_fusion_multiplier(recipe_name)
    end

    return source_entry.fusion_multiplier or 0
end


function model.find_neutron_source(runtime, entity, exclude)
    local exclude_unit = type(exclude) == "number" and exclude or (exclude and exclude.unit_number)
    local entities = entity.surface.find_entities_filtered{
        name = model.neutron_source_names,
        position = entity.position,
        radius = model.range,
    }

    if #entities == 0 then
        return {
            source = nil,
            eff = 0,
            had_source = false,
        }
    end

    local best_source = nil
    local best_efficiency = 0
    local had_source = false

    for _, source in ipairs(entities) do
        if model.entity_check(source) and model.neutron_sources[source.name] ~= nil then
            if exclude_unit ~= nil and source.unit_number == exclude_unit then
                goto continue
            end

            had_source = true

            local source_entry = runtime.sources_by_unit[source.unit_number]
            local efficiency = model.calc_efficiency(entity, source, source_entry)

            if best_source == nil or efficiency > best_efficiency then
                best_source = source
                best_efficiency = efficiency
            end
        end

        ::continue::
    end

    return {
        source = best_source,
        eff = best_efficiency,
        had_source = had_source,
    }
end


function model.show_resolution_text(entity, result)
    if not result.had_source then
        rendering.draw_text{
            target = entity,
            text = "No nearby neutron source",
            color = {r = 1, g = 0.77, b = 0},
            surface = entity.surface,
            scale = 1,
            time_to_live = 15,
        }
        return
    end

    if result.eff > 0 then
        rendering.draw_text{
            text = "Efficiency: " .. result.eff .. "%",
            surface = entity.surface,
            target = entity,
            color = {r = 0.48, g = 0.77, b = 0.37},
            scale = 0.75,
            time_to_live = 120,
            alignment = "center",
            scale_with_zoom = false,
        }
        return
    end

    rendering.draw_text{
        target = entity,
        text = "Insufficient neutron flux",
        color = {r = 1, g = 0.77, b = 0},
        surface = entity.surface,
        scale = 1,
        time_to_live = 15,
    }
end


function model.apply_collector_animation(collector_entry, direction_count)
    if direction_count == nil then
        if collector_entry.last_direction ~= nil
            or (storage.ei["neutron_collector_animation"] and storage.ei["neutron_collector_animation"][collector_entry.unit_number]) then
            model.remove_direction_animation_by_unit(collector_entry.unit_number)
        end

        collector_entry.last_direction = nil
        return
    end

    if collector_entry.last_direction ~= direction_count then
        model.make_direction_animation(collector_entry.entity, direction_count)
        collector_entry.last_direction = direction_count
    end
end


function model.refresh_collector(runtime, collector_entry, show_feedback, exclude)
    local entity = collector_entry and collector_entry.entity or nil
    if not model.entity_check(entity) then
        model.unregister_collector(runtime, collector_entry)
        return false
    end

    -- Dirty refresh is the expensive path: resolve the best source, migrate the binding,
    -- and only touch recipe/animation state when the resolved output actually changed.
    local effective_exclude = collector_entry.exclude_source_unit or exclude
    collector_entry.exclude_source_unit = nil

    local result = model.find_neutron_source(runtime, entity, effective_exclude)
    local source_entry = nil
    local source_state = false

    if result.source and result.eff > 0 then
        source_entry = model.connect_collector(runtime, collector_entry, result.source)
        if source_entry and model.entity_check(source_entry.entity) then
            source_state = model.get_state(source_entry.entity)
            source_entry.last_active_state = source_state
        end
    else
        model.disconnect_collector(runtime, collector_entry)
    end

    local desired_recipe_name = nil
    local desired_direction = nil
    local desired_active = false

    if result.source and result.eff > 0 and not entity.disabled_by_control_behavior then
        desired_recipe_name = "ei-charged-neutron-container-" .. result.eff
        desired_direction = model.get_looking_direction(entity, result.source)
        desired_active = source_state
    end

    local current_recipe_name = model.get_entity_recipe_name(entity)
    if current_recipe_name ~= desired_recipe_name then
        entity.set_recipe(desired_recipe_name)
    end
    entity.recipe_locked = true

    model.apply_collector_animation(collector_entry, desired_direction)
    entity.active = desired_active

    collector_entry.last_recipe_name = desired_recipe_name
    collector_entry.last_efficiency = result.eff or 0

    if desired_recipe_name then
        ei_victory.count_value("neutron_collector_efficiency", result.eff)
    end

    if show_feedback then
        model.show_resolution_text(entity, result)
    end

    return true
end


function model.process_dirty_collectors(runtime, budget)
    local processed = 0

    while processed < budget do
        local collector_entry = model.dequeue_dirty_collector(runtime)
        if not collector_entry then
            break
        end

        model.refresh_collector(runtime, collector_entry, false)
        processed = processed + 1
    end

    return processed
end


function model.poll_source(runtime, source_unit)
    local source_entry = runtime.sources_by_unit[source_unit]
    if not source_entry then
        model.remove_connected_source(runtime, source_unit)
        return false
    end

    local source = source_entry.entity
    if not model.entity_check(source) then
        model.remove_source_entry(runtime, source_unit, true)
        return true
    end

    -- Steady-state polling is intentionally narrow: prune stale collector links and only
    -- fan out active-state writes when the source actually changed state.
    local source_state = model.get_state(source)
    local state_changed = source_entry.last_active_state == nil or source_entry.last_active_state ~= source_state

    for collector_unit in pairs(source_entry.collectors) do
        local collector_entry = runtime.collectors_by_unit[collector_unit]

        if not collector_entry then
            model.remove_collector_from_source(runtime, source_entry, collector_unit, false)
        elseif collector_entry.source_unit ~= source_unit then
            model.remove_collector_from_source(runtime, source_entry, collector_unit, false)
        elseif not model.entity_check(collector_entry.entity) then
            if collector_entry.queued then
                collector_entry.queued = false
                runtime.dirty_collector_count = math.max(0, (runtime.dirty_collector_count or 0) - 1)
            end

            runtime.collectors_by_unit[collector_unit] = nil
            model.remove_direction_animation_by_unit(collector_unit)
            model.remove_collector_from_source(runtime, source_entry, collector_unit, false)
        elseif state_changed then
            collector_entry.entity.active = source_state
                and not collector_entry.entity.disabled_by_control_behavior
                and collector_entry.last_recipe_name ~= nil
        end
    end

    if runtime.sources_by_unit[source_unit] == nil then
        return true
    end

    source_entry.last_active_state = source_state
    return true
end


function model.poll_connected_sources(runtime, budget)
    local processed = 0

    while processed < budget and (runtime.connected_source_count or 0) > 0 do
        if runtime.poll_cursor > runtime.connected_source_count then
            runtime.poll_cursor = 1
        end

        local source_unit = runtime.connected_source_units[runtime.poll_cursor]
        runtime.poll_cursor = runtime.poll_cursor + 1
        if runtime.poll_cursor > runtime.connected_source_count then
            runtime.poll_cursor = 1
        end

        if source_unit ~= nil then
            model.poll_source(runtime, source_unit)
            processed = processed + 1
        else
            break
        end
    end

    return processed
end


function model.queue_collectors_in_range(runtime, neutron_source, exclude)
    if model.entity_check(neutron_source) == false then
        return
    end

    local exclude_source_unit = type(exclude) == "number" and exclude or (exclude and exclude.unit_number)
    local entities = neutron_source.surface.find_entities_filtered{
        name = NEUTRON_COLLECTOR_NAME,
        position = neutron_source.position,
        radius = model.range,
    }

    for _, entity in ipairs(entities) do
        local collector_entry = model.register_collector(runtime, entity)
        if collector_entry then
            model.queue_dirty_collector(runtime, collector_entry, exclude_source_unit)
        end
    end
end


function model.rebuild_runtime_state(reason)
    local runtime = model.check_global()
    if runtime.runtime_rebuild_in_progress then
        return
    end

    runtime.runtime_rebuild_in_progress = true
    model.reset_runtime_storage(runtime)

    for _, surface in pairs(game.surfaces) do
        local collectors = surface.find_entities_filtered{
            name = NEUTRON_COLLECTOR_NAME,
        }

        for _, collector in ipairs(collectors) do
            if model.entity_check(collector) then
                local collector_entry = model.register_collector(runtime, collector)
                if collector_entry then
                    model.queue_dirty_collector(runtime, collector_entry)
                end
            end
        end
    end

    model.process_dirty_collectors(runtime, runtime.dirty_collector_count or 0)

    runtime.runtime_version = NEUTRON_RUNTIME_VERSION
    runtime.needs_rebuild = false
    runtime.runtime_rebuild_in_progress = false

    if reason == "init" then
        runtime.prefer_poll_next = false
    end
end


function model.get_dirty_collector_count()
    local runtime = model.ensure_runtime_ready()
    return runtime and runtime.dirty_collector_count or 0
end


function model.get_connected_source_count()
    local runtime = model.ensure_runtime_ready()
    return runtime and runtime.connected_source_count or 0
end


function model.get_pending_work_count()
    local runtime = model.ensure_runtime_ready()
    if not runtime then
        return 0
    end

    return (runtime.dirty_collector_count or 0) + (runtime.connected_source_count or 0)
end


function model.update_neutron_collector(entity, exclude, show_feedback)
    local runtime = model.ensure_runtime_ready()
    if not runtime or runtime.runtime_rebuild_in_progress then
        return false
    end

    local collector_entry = model.register_collector(runtime, entity)
    if not collector_entry then
        return false
    end

    return model.refresh_collector(runtime, collector_entry, show_feedback == true, exclude)
end


function model.update_neutron_collectors_in_range(neutron_source, exclude)
    local runtime = model.ensure_runtime_ready()
    if not runtime or runtime.runtime_rebuild_in_progress then
        return
    end

    model.queue_collectors_in_range(runtime, neutron_source, exclude)
end


function model.is_output_empty(entity)
    if entity.crafting_progress == 1 then
        local output_inventory = entity.get_output_inventory and entity.get_output_inventory() or nil
        if output_inventory and not output_inventory.is_empty() and output_inventory.is_full() then
            return false
        end

        -- same for potential fluidboxes
        -- TODO
    end

    return true
end


function model.get_state(entity)
    if model.entity_check(entity) == false then
        return false
    end

    if entity.type == "assembling-machine" then
        if model.is_output_empty(entity) == false then
            return false
        end

        return entity.is_crafting() and not entity.disabled_by_control_behavior
    end

    if entity.type == "furnace" then
        if model.is_output_empty(entity) == false then
            return false
        end

        return entity.is_crafting() and not entity.disabled_by_control_behavior
    end

    if entity.type == "reactor" and entity.burner and entity.burner.currently_burning then
        return true
    end

    return false
end

--MATH RELATED
------------------------------------------------------------------------------------------------------

function model.get_looking_direction(entity, target)
    -- get the direction from entity to target, snap to 64 directions
    -- 0 = north = 0dec, 16 = east = 45dec, 32 = south = 90dec, 48 = west = 270dec, 64 = north = 360dec

    if model.entity_check(entity) == false then
        return 0
    end

    if model.entity_check(target) == false then
        return 0
    end

    local dx = target.position.x - entity.position.x
    local dy = target.position.y - entity.position.y

    local phi = math.atan(dx / dy)

    if dx == 0 then
        if dy < 0 then
            return 0
        else
            return 32
        end
    end

    if dx < 0 and dy < 0 then
        phi = phi + math.pi
    elseif dx > 0 and dy < 0 then
        phi = phi + math.pi
    end

    phi = phi + math.pi

    local theta = 2 * math.pi - phi
    local angle = theta * 180 / math.pi
    local direction = math.floor(angle / 360 * 64)

    return direction % 64
end


function model.calc_efficiency(entity, source, source_entry)
    if not model.entity_check(entity) or not model.entity_check(source) then
        return 0
    end

    local dist = model.calc_distance(entity, source)
    if dist > model.range then
        return 0
    end

    local efficiency
    if dist < 1 then
        efficiency = 100
    else
        efficiency = 100 - (dist / model.range) * 90 + model.neutron_sources[source.name]
    end

    if efficiency < 0 then
        efficiency = 0
    elseif efficiency > 100 then
        efficiency = 100
    end

    if source.name == FUSION_REACTOR_NAME then
        local fusion_multiplier

        if source_entry then
            fusion_multiplier = model.get_source_fusion_multiplier(source_entry)
        else
            fusion_multiplier = model.parse_fusion_multiplier(model.get_entity_recipe_name(source) or DEFAULT_FUSION_RECIPE)
        end

        efficiency = efficiency * fusion_multiplier
    end

    efficiency = math.floor(efficiency / 10) * 10

    if efficiency < 0 then
        efficiency = 0
    elseif efficiency > 300 then
        efficiency = 300
    end

    return efficiency
end


function model.update(budget)
    local runtime = model.ensure_runtime_ready()
    if not runtime or runtime.runtime_rebuild_in_progress then
        return false
    end

    budget = math.max(0, math.floor(budget or 1))
    if budget <= 0 then
        return false
    end

    local dirty_count = runtime.dirty_collector_count or 0
    local connected_count = runtime.connected_source_count or 0
    if dirty_count <= 0 and connected_count <= 0 then
        return false
    end

    -- Dirty collector work gets priority, but we still reserve poll budget for connected
    -- sources so reactors and furnaces pause/resume nearby collectors with low visible lag.
    local reserved_poll_budget = 0

    if connected_count > 0 then
        if dirty_count <= 0 then
            reserved_poll_budget = budget
        elseif budget > 1 then
            reserved_poll_budget = 1
        elseif runtime.prefer_poll_next then
            reserved_poll_budget = 1
        end
    end

    local dirty_budget = budget - reserved_poll_budget
    local dirty_processed = 0
    if dirty_budget > 0 then
        dirty_processed = model.process_dirty_collectors(runtime, dirty_budget)
    end

    local remaining_budget = budget - dirty_processed
    local poll_processed = 0
    if remaining_budget > 0 and connected_count > 0 then
        poll_processed = model.poll_connected_sources(runtime, remaining_budget)
    end

    remaining_budget = budget - dirty_processed - poll_processed
    if remaining_budget > 0 then
        dirty_processed = dirty_processed + model.process_dirty_collectors(runtime, remaining_budget)
    end

    if connected_count > 0 and dirty_count > 0 and budget == 1 then
        runtime.prefer_poll_next = not runtime.prefer_poll_next
    end

    return (dirty_processed + poll_processed) > 0
end

--SPRITE RELATED
------------------------------------------------------------------------------------------------------

function model.make_direction_animation(entity, direction_count)
    model.remove_direction_animation(entity)

    local animation = rendering.draw_animation({
        animation = "ei-neutron-collector_top",
        target = entity,
        surface = entity.surface,
        render_layer = 132,
        animation_speed = 0,
        animation_offset = direction_count - 1,
        x_scale = 1,
        y_scale = 1,
    })

    storage.ei["neutron_collector_animation"][entity.unit_number] = animation
end


function model.remove_direction_animation(entity)
    if not entity or not entity.unit_number then
        return
    end

    model.remove_direction_animation_by_unit(entity.unit_number)
end

--HANDLERS
------------------------------------------------------------------------------------------------------

function model.on_built_entity(entity)
    local runtime = model.ensure_runtime_ready()
    if not runtime or runtime.runtime_rebuild_in_progress or model.entity_check(entity) == false then
        return
    end

    if entity.name == NEUTRON_COLLECTOR_NAME then
        model.update_neutron_collector(entity, nil, true)
        return
    end

    if model.neutron_sources[entity.name] then
        model.update_neutron_collectors_in_range(entity)
    end
end


function model.on_destroyed_entity(entity, destroy_type)
    local runtime = model.ensure_runtime_ready()
    if not runtime or runtime.runtime_rebuild_in_progress or model.entity_check(entity) == false then
        return
    end

    if entity.name == NEUTRON_COLLECTOR_NAME then
        model.unregister_collector(runtime, entity)
        return
    end

    if model.neutron_sources[entity.name] then
        model.update_neutron_collectors_in_range(entity, entity)
        if entity.unit_number then
            model.remove_source_entry(runtime, entity.unit_number, false)
        end
    end
end

return model
