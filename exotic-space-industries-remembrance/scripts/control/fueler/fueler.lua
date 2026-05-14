--==============================================================================
-- ESIR FILE MAP
-- owns: fueler towers, targets, player servicing, and console GUI
-- loaded_by: exotic-space-industries-remembrance\control.lua
-- cadence: init/config rebuild, build/destroy, scheduled tick step 6, and GUI open/close/click
-- forwarded_events: add_active_surface, audit_runtime_state, build_target_entry, build_tower_entry, cast_beam, check_global, clear_legacy_runtime_fields, close_gui, consume_tower_slice_budget, dequeue_ready_player, dequeue_surface_target, enqueue_ready_player, enqueue_ready_target, ensure_runtime_ready, entity_check, get_equipment, get_normalized_quality_factor, get_pending_work_count, get_quality_sort_level, get_ready_target_count, get_retry_delay, get_runtime_status, get_service_budget, get_surface_queue, get_target_type, get_tower_chunk_bucket, get_tower_slice_remaining, get_transfer_inv, has_tick_work, index_tower, is_better_tower, is_supported_runtime_target, mark_players_dirty, on_built_entity, on_destroyed_entity, on_gui_click, on_player_left_game, on_player_ready, open_gui, process_player_state, process_ready_player, process_ready_target, process_target_entry, rebuild_runtime_state, refuel_equipments, refuel_target, register_fueler, register_target, release_due_players, release_due_targets, remove_active_surface, remove_ready_player, remove_ready_target, remove_target_entry, remove_tower_entry, reset_runtime_storage, schedule_player, schedule_target, select_service_towers, set_equipment, set_target_type, sync_connected_players, sync_player_state, tower_matches_target, transfer_ammo, transfer_fuel, transfer_valid, unindex_tower, unregister_fueler, unregister_player_by_index, unregister_target, unschedule_player, unschedule_target, update_gui, updater
-- storage_roots: storage.ei
-- gui_ids: ei-fueler-console
-- remote_interfaces: none
-- rebuild_on: init, configuration change, entity topology changes
--==============================================================================
local model = {}
local ei_runtime_scheduler = require("lib/runtime-scheduler")
local get_entity_unit_number = ei_lib.get_entity_unit_number

local FUELER_RUNTIME_VERSION = 1
local FUELER_CHUNK_SIZE = 32
local PLAYER_SYNC_INTERVAL_TICKS = 600
local INTEGRITY_AUDIT_INTERVAL_TICKS = 1800

local SUCCESS_COOLDOWN_TICKS = 60
local FAILED_ACTION_COOLDOWN_TICKS = 120
local MOVING_RETRY_COOLDOWN_TICKS = 30
local STATIC_RETRY_COOLDOWN_TICKS = 300

local runtime_target_types = {
    ["locomotive"] = true,
    ["car"] = true,
    ["spider-vehicle"] = true,
    ["ammo-turret"] = true,
    ["artillery-turret"] = true,
    ["artillery-wagon"] = true
}

local runtime_target_type_names = {
    "locomotive",
    "car",
    "spider-vehicle",
    "ammo-turret",
    "artillery-turret",
    "artillery-wagon"
}

local static_target_types = {
    ["ammo-turret"] = true,
    ["artillery-turret"] = true,
    ["artillery-wagon"] = true
}

model.target_types = {
    "locomotive",
    "car",
    "spidertron",
    "character",
}

local function ensure_queue(queue)
    return ei_runtime_scheduler.ensure_queue(queue)
end

local function compact_queue(queue)
    queue = ensure_queue(queue)

    if queue.head > queue.tail then
        queue.items = {}
        queue.head = 1
        queue.tail = 0
        return queue
    end

    if queue.head > 64 and queue.head > math.floor((queue.tail - queue.head + 1) / 2) then
        local new_items = {}
        local new_tail = 0

        for index = queue.head, queue.tail do
            local item = queue.items[index]
            if item ~= nil then
                new_tail = new_tail + 1
                new_items[new_tail] = item
            end
        end

        queue.items = new_items
        queue.head = 1
        queue.tail = new_tail
    end

    return queue
end

local function raw_table_has_entries(tbl)
    return type(tbl) == "table" and next(tbl) ~= nil
end

local function raw_queue_item_count(queue)
    if type(queue) ~= "table" or type(queue.items) ~= "table" then
        return 0
    end

    local count = 0
    local head = queue.head or 1
    local tail = queue.tail or #queue.items
    for index = head, tail do
        if queue.items[index] ~= nil then
            count = count + 1
        end
    end

    return count
end

local function raw_surface_queue_item_count(surface_queues)
    if type(surface_queues) ~= "table" then
        return 0
    end

    local count = 0
    for _, queue in pairs(surface_queues) do
        count = count + raw_queue_item_count(queue)
    end

    return count
end

local function raw_due_bucket_ticks(buckets, current_tick)
    local due_ticks = {}
    if type(buckets) ~= "table" then
        return due_ticks
    end

    for due_tick, bucket in pairs(buckets) do
        if type(bucket) == "table" and next(bucket) ~= nil then
            if due_tick <= current_tick then
                due_ticks[#due_ticks + 1] = due_tick
            end
        end
    end

    return due_ticks
end

local function raw_due_bucket_item_count(buckets, current_tick)
    local count = 0
    for _, due_tick in ipairs(raw_due_bucket_ticks(buckets, current_tick)) do
        for _ in pairs(buckets[due_tick]) do
            count = count + 1
        end
    end

    return count
end

local function get_force_index(force)
    return force and force.index or nil
end

local function get_entity_target_type(entity)
    if not entity or not entity.type then
        return nil
    end

    if entity.type == "spider-vehicle" then
        return "spidertron"
    end

    return entity.type
end

local function is_vehicle_target_type(target_type)
    return target_type == "locomotive"
        or target_type == "car"
        or target_type == "spider-vehicle"
end

function model.entity_check(entity)
    return ei_lib.entity_check(entity)
end

function model.get_normalized_quality_factor(entity)
    if not entity or not entity.quality or not ei_lib.is_valid_number(entity.quality.level) then
        return 0
    end

    local min_level, max_level = ei_lib.get_quality_level_bounds()
    if not ei_lib.is_valid_number(min_level) or not ei_lib.is_valid_number(max_level) or max_level <= min_level then
        return 0
    end

    return ei_lib.clamp((entity.quality.level - min_level) / (max_level - min_level), 0, 1)
end

function model.get_quality_sort_level(entity)
    if entity and entity.quality and ei_lib.is_valid_number(entity.quality.level) then
        return entity.quality.level
    end

    return 0
end

function model.get_service_budget(entity)
    return 1 + math.floor(model.get_normalized_quality_factor(entity) * 2 + 0.000001)
end

function model.clear_legacy_runtime_fields()
    if not storage.ei then
        return
    end

    storage.ei.fueler_queue = nil
    storage.ei.fueler_break_point = nil
    storage.ei.cooldown = nil
end

local function refresh_runtime_range_cache(runtime)
    if not runtime then
        return
    end

    local range = ei_lib.config("fueler_range")
    runtime.cached_range = range
    runtime.cached_range_sqr = range * range
end

function model.check_global()
    if not storage.ei then
        storage.ei = {}
    end

    if not storage.ei.fueler then
        storage.ei.fueler = {}
    end

    local runtime = storage.ei.fueler_rt
    local runtime_was_missing = false
    local runtime_components_missing = false

    if not runtime then
        runtime = {}
        storage.ei.fueler_rt = runtime
        runtime_was_missing = true
    end

    local function ensure_component(name, default)
        if runtime[name] == nil then
            runtime[name] = default
            runtime_components_missing = true
        end
    end

    ensure_component("towers", {})
    ensure_component("tower_chunks", {})
    ensure_component("targets", {})
    ensure_component("target_surface_queues", {})
    ensure_component("target_surface_counts", {})
    ensure_component("active_surfaces", {})
    ensure_component("active_surface_positions", {})
    ensure_component("active_surface_cursor", 1)
    ensure_component("delayed_target_buckets", {})
    ensure_component("ready_target_count", 0)
    ensure_component("target_count", 0)
    ensure_component("player_queue", ensure_queue(nil))
    ensure_component("player_states", {})
    ensure_component("delayed_player_buckets", {})
    ensure_component("last_due_target_release_tick", -1)
    ensure_component("last_due_player_release_tick", -1)
    ensure_component("last_housekeeping_tick", -1)
    ensure_component("last_player_sync_tick", -PLAYER_SYNC_INTERVAL_TICKS)
    ensure_component("last_integrity_audit_tick", -INTEGRITY_AUDIT_INTERVAL_TICKS)
    ensure_component("player_sync_dirty", true)
    ensure_component("runtime_rebuild_in_progress", false)

    runtime.player_queue = ensure_queue(runtime.player_queue)
    if runtime.cached_range == nil or runtime.cached_range_sqr == nil then
        refresh_runtime_range_cache(runtime)
    end

    if runtime.runtime_version ~= FUELER_RUNTIME_VERSION then
        runtime.needs_rebuild = true
    elseif runtime_components_missing then
        runtime.needs_rebuild = true
    elseif runtime.needs_rebuild == nil then
        runtime.needs_rebuild = false
    end

    if runtime_was_missing and next(storage.ei.fueler) == nil then
        runtime.runtime_version = FUELER_RUNTIME_VERSION
        runtime.needs_rebuild = false
    end

    return runtime
end

function model.reset_runtime_storage(runtime)
    runtime.towers = {}
    runtime.tower_chunks = {}
    runtime.targets = {}
    runtime.target_surface_queues = {}
    runtime.target_surface_counts = {}
    runtime.active_surfaces = {}
    runtime.active_surface_positions = {}
    runtime.active_surface_cursor = 1
    runtime.delayed_target_buckets = {}
    runtime.ready_target_count = 0
    runtime.target_count = 0
    runtime.player_queue = ensure_queue(nil)
    runtime.player_states = {}
    runtime.delayed_player_buckets = {}
    runtime.last_due_target_release_tick = -1
    runtime.last_due_player_release_tick = -1
    runtime.last_housekeeping_tick = -1
    runtime.last_player_sync_tick = -PLAYER_SYNC_INTERVAL_TICKS
    runtime.last_integrity_audit_tick = -INTEGRITY_AUDIT_INTERVAL_TICKS
    runtime.player_sync_dirty = true
    runtime.runtime_version = FUELER_RUNTIME_VERSION
    runtime.needs_rebuild = false
    refresh_runtime_range_cache(runtime)

    model.clear_legacy_runtime_fields()
end

function model.get_surface_queue(runtime, surface_index, create)
    local queue = runtime.target_surface_queues[surface_index]
    if not queue and create then
        queue = ensure_queue(nil)
        runtime.target_surface_queues[surface_index] = queue
    end

    if not queue then
        return nil
    end

    return ensure_queue(queue)
end

function model.add_active_surface(runtime, surface_index)
    if runtime.active_surface_positions[surface_index] then
        return
    end

    runtime.active_surfaces[#runtime.active_surfaces + 1] = surface_index
    runtime.active_surface_positions[surface_index] = #runtime.active_surfaces
end

function model.remove_active_surface(runtime, surface_index)
    local remove_index = runtime.active_surface_positions[surface_index]
    if not remove_index then
        return
    end

    local active_surfaces = runtime.active_surfaces
    table.remove(active_surfaces, remove_index)
    runtime.active_surface_positions[surface_index] = nil

    for index = remove_index, #active_surfaces do
        runtime.active_surface_positions[active_surfaces[index]] = index
    end

    if #active_surfaces == 0 then
        runtime.active_surface_cursor = 1
        return
    end

    if runtime.active_surface_cursor > #active_surfaces then
        runtime.active_surface_cursor = 1
    end
end

function model.get_tower_chunk_bucket(runtime, surface_index, chunk_x, chunk_y, create)
    local surface_chunks = runtime.tower_chunks[surface_index]
    if not surface_chunks and create then
        surface_chunks = {}
        runtime.tower_chunks[surface_index] = surface_chunks
    end

    if not surface_chunks then
        return nil
    end

    local x_bucket = surface_chunks[chunk_x]
    if not x_bucket and create then
        x_bucket = {}
        surface_chunks[chunk_x] = x_bucket
    end

    if not x_bucket then
        return nil
    end

    local chunk_bucket = x_bucket[chunk_y]
    if not chunk_bucket and create then
        chunk_bucket = {}
        x_bucket[chunk_y] = chunk_bucket
    end

    return chunk_bucket
end

function model.build_tower_entry(runtime, entity)
    local unit_number = get_entity_unit_number(entity)
    local range = runtime and runtime.cached_range or ei_lib.config("fueler_range")
    local min_chunk_x, max_chunk_x, min_chunk_y, max_chunk_y = ei_lib.get_chunk_coverage(entity.position, range, FUELER_CHUNK_SIZE)

    return {
        unit_number = unit_number,
        entity = entity,
        surface_index = ei_lib.get_surface_index(entity.surface),
        min_chunk_x = min_chunk_x,
        max_chunk_x = max_chunk_x,
        min_chunk_y = min_chunk_y,
        max_chunk_y = max_chunk_y,
        quality_sort_level = model.get_quality_sort_level(entity),
        service_budget = model.get_service_budget(entity),
        target_type = model.get_target_type(unit_number),
        equipment_mode = model.get_equipment(unit_number),
        slice_tick = -1,
        slice_remaining = 0
    }
end

function model.index_tower(runtime, tower_id, tower_entry)
    if not tower_entry or not tower_entry.surface_index then
        return
    end

    for chunk_x = tower_entry.min_chunk_x, tower_entry.max_chunk_x do
        for chunk_y = tower_entry.min_chunk_y, tower_entry.max_chunk_y do
            local bucket = model.get_tower_chunk_bucket(runtime, tower_entry.surface_index, chunk_x, chunk_y, true)
            bucket[tower_id] = true
        end
    end
end

function model.unindex_tower(runtime, tower_id, tower_entry)
    if not tower_entry or not tower_entry.surface_index then
        return
    end

    local surface_chunks = runtime.tower_chunks[tower_entry.surface_index]
    if not surface_chunks then
        return
    end

    for chunk_x = tower_entry.min_chunk_x, tower_entry.max_chunk_x do
        local x_bucket = surface_chunks[chunk_x]
        if x_bucket then
            for chunk_y = tower_entry.min_chunk_y, tower_entry.max_chunk_y do
                local bucket = x_bucket[chunk_y]
                if bucket then
                    bucket[tower_id] = nil
                    if next(bucket) == nil then
                        x_bucket[chunk_y] = nil
                    end
                end
            end

            if next(x_bucket) == nil then
                surface_chunks[chunk_x] = nil
            end
        end
    end

    if next(surface_chunks) == nil then
        runtime.tower_chunks[tower_entry.surface_index] = nil
    end
end

function model.get_tower_slice_remaining(tower_entry, tick)
    if not tower_entry or not model.entity_check(tower_entry.entity) then
        return 0
    end

    if tower_entry.slice_tick ~= tick then
        tower_entry.slice_tick = tick
        tower_entry.slice_remaining = tower_entry.service_budget or model.get_service_budget(tower_entry.entity)
    end

    return tower_entry.slice_remaining or 0
end

function model.consume_tower_slice_budget(tower_entry, tick)
    local remaining = model.get_tower_slice_remaining(tower_entry, tick)
    if remaining <= 0 then
        return 0
    end

    tower_entry.slice_remaining = remaining - 1
    return tower_entry.slice_remaining
end

function model.get_transfer_inv(transfer)
    if not transfer then
        return nil
    end

    if type(transfer) == "number" then
        local player = game.get_player(transfer)
        return player and player.valid and player.get_main_inventory() or nil
    end

    if transfer and transfer.valid then
        return transfer.get_inventory(defines.inventory.robot_cargo)
    end

    return nil
end

function model.transfer_valid(source, transfer)
    local target_inv = model.get_transfer_inv(transfer)

    if not target_inv then
        return true
    end

    local source_inv = source.get_inventory(defines.inventory.chest)
    local return_value = true

    local source_stack = {name = source.name, count = 1}
    local quality = source.quality
    if quality and quality.name then
        source_stack.quality = quality.name
    elseif quality then
        source_stack.quality = quality
    end

    if not target_inv.can_insert(source_stack) then
        return_value = false
    end

    if return_value == true and type(transfer) ~= "number" then
        if source_inv and not source_inv.is_empty() then
            return_value = false
        end
    end

    return return_value
end

local function clone_stack(itemstack, target_inv)
    if not itemstack.valid_for_read then
        return 0
    end

    local original_count = itemstack.count
    local stack_definition = ei_lib.make_item_stack_definition(itemstack, original_count)
    if not stack_definition then
        return 0
    end

    local inserted = target_inv.insert(stack_definition)
    if not inserted or inserted <= 0 then
        return 0
    end

    itemstack.count = original_count - inserted
    return inserted
end

function model.transfer_fuel(source_inventory, target_inventory)
    local action = false

    for index = 1, #source_inventory do
        local itemstack = source_inventory[index]
        if clone_stack(itemstack, target_inventory) > 0 then
            action = true
        end
    end

    return action
end

function model.transfer_ammo(source_inventory, target_inventory)
    local action = false

    for index = 1, #source_inventory do
        local itemstack = source_inventory[index]
        if clone_stack(itemstack, target_inventory) > 0 then
            action = true
        end
    end

    return action
end

function model.cast_beam(fueler, target)
    fueler.surface.create_entity({
        name = "ei-fuel-beam",
        position = fueler.position,
        source_offset = {0, -1},
        source = fueler,
        target = target,
        duration = 30,
        force = fueler.force,
    })
end

function model.refuel_target(fueler, target, target_type)
    local fueler_inventory = fueler.get_inventory(defines.inventory.chest)
    local action = false

    local ammo_inventory = target.get_inventory(defines.inventory.turret_ammo)
    if ammo_inventory == nil then
        ammo_inventory = target.get_inventory(defines.inventory.artillery_turret_ammo)
    end
    if ammo_inventory == nil then
        ammo_inventory = target.get_inventory(defines.inventory.artillery_wagon_ammo)
    end

    if ammo_inventory then
        action = model.transfer_ammo(fueler_inventory, ammo_inventory) or action
    end

    if is_vehicle_target_type(target_type) then
        local fuel_inventory = target.get_fuel_inventory()
        if fuel_inventory then
            if not fueler_inventory.is_empty() then
                action = model.transfer_fuel(fueler_inventory, fuel_inventory) or action
            end

            local result_inventory = target.get_burnt_result_inventory()
            if result_inventory and not fueler_inventory.is_full() and not result_inventory.is_empty() then
                action = model.transfer_fuel(result_inventory, fueler_inventory) or action
            end
        end
    end

    if action then
        model.cast_beam(fueler, target)
    end

    return action
end

function model.refuel_equipments(fueler, target)
    local fueler_inventory = fueler.get_inventory(defines.inventory.chest)
    if not target.grid then
        return false
    end

    local equipments = target.grid.equipment
    if #equipments == 0 then
        return false
    end

    local action = false

    for _, equipment in ipairs(equipments) do
        if equipment.valid and equipment.burner then
            local burner_inventory = equipment.burner.inventory
            if not fueler_inventory.is_empty() then
                action = model.transfer_fuel(fueler_inventory, burner_inventory) or action
            end

            local result_inventory = equipment.burner.burnt_result_inventory
            if result_inventory and not fueler_inventory.is_full() and not result_inventory.is_empty() then
                action = model.transfer_fuel(result_inventory, fueler_inventory) or action
            end
        end
    end

    if action then
        model.cast_beam(fueler, target)
    end

    return action
end

function model.remove_ready_target(runtime, target_entry)
    if not target_entry or not target_entry.ready_queued or not target_entry.ready_surface_index then
        return
    end

    local queue = model.get_surface_queue(runtime, target_entry.ready_surface_index, false)
    if queue and queue.queued[target_entry.unit_number] then
        ei_runtime_scheduler.queue_remove_value(queue, target_entry.unit_number)
        compact_queue(queue)
        runtime.ready_target_count = math.max(0, (runtime.ready_target_count or 0) - 1)

        local surface_index = target_entry.ready_surface_index
        runtime.target_surface_counts[surface_index] = math.max(0, (runtime.target_surface_counts[surface_index] or 0) - 1)
        if runtime.target_surface_counts[surface_index] == 0 then
            runtime.target_surface_counts[surface_index] = nil
            model.remove_active_surface(runtime, surface_index)
        end
    end

    target_entry.ready_queued = false
    target_entry.ready_surface_index = nil
end

function model.enqueue_ready_target(runtime, target_id, surface_index)
    local target_entry = runtime.targets[target_id]
    if not target_entry or target_entry.ready_queued then
        return false
    end

    surface_index = surface_index or target_entry.surface_index
    if not surface_index then
        return false
    end

    local queue = model.get_surface_queue(runtime, surface_index, true)
    if queue.queued[target_id] then
        target_entry.ready_queued = true
        target_entry.ready_surface_index = surface_index
        return true
    end

    ei_runtime_scheduler.queue_push_unique(queue, target_id)

    target_entry.ready_queued = true
    target_entry.ready_surface_index = surface_index

    runtime.ready_target_count = (runtime.ready_target_count or 0) + 1
    runtime.target_surface_counts[surface_index] = (runtime.target_surface_counts[surface_index] or 0) + 1
    model.add_active_surface(runtime, surface_index)
    return true
end

function model.dequeue_surface_target(runtime, surface_index)
    local queue = model.get_surface_queue(runtime, surface_index, false)
    if not queue then
        return nil
    end

    local target_id = ei_runtime_scheduler.queue_pop_queued(queue)
    if target_id == nil then
        compact_queue(queue)
        return nil
    end

    runtime.ready_target_count = math.max(0, (runtime.ready_target_count or 0) - 1)
    runtime.target_surface_counts[surface_index] = math.max(0, (runtime.target_surface_counts[surface_index] or 0) - 1)
    if runtime.target_surface_counts[surface_index] == 0 then
        runtime.target_surface_counts[surface_index] = nil
        model.remove_active_surface(runtime, surface_index)
    end

    local target_entry = runtime.targets[target_id]
    if target_entry then
        target_entry.ready_queued = false
        target_entry.ready_surface_index = nil
    end

    compact_queue(queue)
    return target_id
end

function model.unschedule_target(runtime, target_entry)
    if not target_entry or not target_entry.next_ready_tick then
        return
    end

    local due_tick = target_entry.next_ready_tick
    local bucket = runtime.delayed_target_buckets[due_tick]
    if bucket then
        bucket[target_entry.unit_number] = nil
        if next(bucket) == nil then
            runtime.delayed_target_buckets[due_tick] = nil
        end
    end

    target_entry.next_ready_tick = nil
end

function model.schedule_target(runtime, target_entry, current_tick, delay)
    if not target_entry then
        return
    end

    model.remove_ready_target(runtime, target_entry)
    model.unschedule_target(runtime, target_entry)

    local due_tick = current_tick + delay
    local bucket = runtime.delayed_target_buckets[due_tick]
    if not bucket then
        bucket = {}
        runtime.delayed_target_buckets[due_tick] = bucket
    end

    bucket[target_entry.unit_number] = true
    target_entry.next_ready_tick = due_tick
end

function model.remove_ready_player(runtime, player_state)
    local queue = runtime.player_queue
    if not player_state or not player_state.ready_queued or not queue.queued[player_state.player_index] then
        if player_state then
            player_state.ready_queued = false
        end
        return
    end

    ei_runtime_scheduler.queue_remove_value(queue, player_state.player_index)
    compact_queue(queue)
    player_state.ready_queued = false
end

function model.enqueue_ready_player(runtime, player_index)
    local player_state = runtime.player_states[player_index]
    if not player_state or player_state.ready_queued then
        return false
    end

    local queue = runtime.player_queue
    if queue.queued[player_index] then
        player_state.ready_queued = true
        return true
    end

    ei_runtime_scheduler.queue_push_unique(queue, player_index)
    player_state.ready_queued = true
    return true
end

function model.dequeue_ready_player(runtime)
    local queue = runtime.player_queue
    local player_index = ei_runtime_scheduler.queue_pop_queued(queue)
    if player_index == nil then
        compact_queue(queue)
        return nil
    end

    local player_state = runtime.player_states[player_index]
    if player_state then
        player_state.ready_queued = false
    end

    compact_queue(queue)
    return player_index
end

function model.unschedule_player(runtime, player_state)
    if not player_state or not player_state.next_ready_tick then
        return
    end

    local due_tick = player_state.next_ready_tick
    local bucket = runtime.delayed_player_buckets[due_tick]
    if bucket then
        bucket[player_state.player_index] = nil
        if next(bucket) == nil then
            runtime.delayed_player_buckets[due_tick] = nil
        end
    end

    player_state.next_ready_tick = nil
end

function model.schedule_player(runtime, player_state, current_tick, delay)
    if not player_state then
        return
    end

    model.remove_ready_player(runtime, player_state)
    model.unschedule_player(runtime, player_state)

    local due_tick = current_tick + delay
    local bucket = runtime.delayed_player_buckets[due_tick]
    if not bucket then
        bucket = {}
        runtime.delayed_player_buckets[due_tick] = bucket
    end

    bucket[player_state.player_index] = true
    player_state.next_ready_tick = due_tick
end

function model.build_target_entry(entity)
    local unit_number = get_entity_unit_number(entity)
    if not unit_number then
        return nil
    end

    return {
        unit_number = unit_number,
        entity = entity,
        entity_type = entity.type,
        surface_index = ei_lib.get_surface_index(entity.surface),
        ready_queued = false,
        ready_surface_index = nil,
        next_ready_tick = nil
    }
end

function model.remove_tower_entry(runtime, tower_id, tower_entry)
    tower_entry = tower_entry or runtime.towers[tower_id]
    if not tower_entry then
        return false
    end

    model.unindex_tower(runtime, tower_id, tower_entry)
    runtime.towers[tower_id] = nil
    return true
end

function model.remove_target_entry(runtime, target_id, target_entry)
    target_entry = target_entry or runtime.targets[target_id]
    if not target_entry then
        return false
    end

    model.remove_ready_target(runtime, target_entry)
    model.unschedule_target(runtime, target_entry)
    runtime.targets[target_id] = nil
    runtime.target_count = math.max(0, (runtime.target_count or 0) - 1)
    return true
end

function model.unregister_player_by_index(runtime, player_index)
    local player_state = runtime.player_states[player_index]
    if not player_state then
        return false
    end

    model.remove_ready_player(runtime, player_state)
    model.unschedule_player(runtime, player_state)
    runtime.player_states[player_index] = nil
    return true
end

function model.register_fueler(entity)
    local runtime = model.check_global()
    local unit_number = get_entity_unit_number(entity)
    if not unit_number then
        return
    end

    local fueler_data = storage.ei.fueler[unit_number] or {}
    storage.ei.fueler[unit_number] = fueler_data
    fueler_data.entity = entity
    fueler_data.queue_pos = nil

    local existing = runtime.towers[unit_number]
    if existing then
        model.unindex_tower(runtime, unit_number, existing)
    end

    local tower_entry = model.build_tower_entry(runtime, entity)
    runtime.towers[unit_number] = tower_entry
    model.index_tower(runtime, unit_number, tower_entry)
end

function model.unregister_fueler(entity, transfer)
    if not model.transfer_valid(entity, transfer) then
        return
    end

    local runtime = model.check_global()
    local unit_number = get_entity_unit_number(entity)
    if not unit_number then
        return
    end

    model.remove_tower_entry(runtime, unit_number)
    storage.ei.fueler[unit_number] = nil
end

function model.is_supported_runtime_target(entity)
    return model.entity_check(entity)
        and get_entity_unit_number(entity) ~= nil
        and entity.type ~= nil
        and runtime_target_types[entity.type] == true
end

function model.register_target(entity)
    if not model.is_supported_runtime_target(entity) then
        return
    end

    local runtime = model.check_global()
    local target_id = get_entity_unit_number(entity)
    if not target_id then
        return
    end

    local target_entry = runtime.targets[target_id]

    if target_entry then
        target_entry.entity = entity
        target_entry.entity_type = entity.type
        target_entry.surface_index = ei_lib.get_surface_index(entity.surface)
        model.unschedule_target(runtime, target_entry)
        if not target_entry.ready_queued then
            model.enqueue_ready_target(runtime, target_id, target_entry.surface_index)
        end
        return
    end

    target_entry = model.build_target_entry(entity)
    runtime.targets[target_id] = target_entry
    runtime.target_count = (runtime.target_count or 0) + 1
    model.enqueue_ready_target(runtime, target_id, target_entry.surface_index)
end

function model.unregister_target(entity)
    local unit_number = get_entity_unit_number(entity)
    if not unit_number then
        return
    end

    local runtime = model.check_global()
    model.remove_target_entry(runtime, unit_number)
end

function model.sync_player_state(runtime, player_index)
    local player = game.get_player(player_index)
    if not player or not player.connected or not player.character or not model.entity_check(player.character) then
        model.unregister_player_by_index(runtime, player_index)
        return false
    end

    local player_state = runtime.player_states[player_index]
    if not player_state then
        player_state = {
            player_index = player_index,
            character = player.character,
            ready_queued = false,
            next_ready_tick = nil
        }
        runtime.player_states[player_index] = player_state
    else
        player_state.character = player.character
    end

    if not player_state.ready_queued and not player_state.next_ready_tick then
        model.enqueue_ready_player(runtime, player_index)
    end

    return true
end

function model.sync_connected_players(runtime)
    local seen_players = {}

    for _, player in pairs(game.connected_players) do
        seen_players[player.index] = true
        model.sync_player_state(runtime, player.index)
    end

    local stale_players = {}
    for player_index in pairs(runtime.player_states) do
        if not seen_players[player_index] then
            stale_players[#stale_players + 1] = player_index
        end
    end

    for _, player_index in ipairs(stale_players) do
        model.unregister_player_by_index(runtime, player_index)
    end

    runtime.player_sync_dirty = false
end

function model.audit_runtime_state(runtime)
    local stale_targets = {}

    for target_id, target_entry in pairs(runtime.targets) do
        if not model.entity_check(target_entry.entity) then
            stale_targets[#stale_targets + 1] = target_id
        elseif target_entry.ready_queued then
            local queue = target_entry.ready_surface_index and model.get_surface_queue(runtime, target_entry.ready_surface_index, false)
            if not queue or queue.queued[target_id] ~= true then
                target_entry.ready_queued = false
                target_entry.ready_surface_index = nil

                if not target_entry.next_ready_tick then
                    target_entry.surface_index = ei_lib.get_surface_index(target_entry.entity.surface)
                    model.enqueue_ready_target(runtime, target_id, target_entry.surface_index)
                end
            end
        elseif target_entry.ready_surface_index ~= nil then
            target_entry.ready_surface_index = nil
        end
    end

    for _, target_id in ipairs(stale_targets) do
        local target_entry = runtime.targets[target_id]
        if target_entry then
            model.remove_target_entry(runtime, target_id, target_entry)
        end
    end

    for surface_index, queue in pairs(runtime.target_surface_queues) do
        local stale_queue_targets = {}
        queue = ensure_queue(queue)
        runtime.target_surface_queues[surface_index] = queue

        for target_id in pairs(queue.queued) do
            local target_entry = runtime.targets[target_id]
            if not target_entry
                or not target_entry.ready_queued
                or target_entry.ready_surface_index ~= surface_index then
                stale_queue_targets[#stale_queue_targets + 1] = target_id
            end
        end

        for _, target_id in ipairs(stale_queue_targets) do
            ei_runtime_scheduler.queue_remove_value(queue, target_id)
        end

        compact_queue(queue)
    end

    local stale_player_queue_entries = {}
    local player_queue = ensure_queue(runtime.player_queue)
    runtime.player_queue = player_queue

    for player_index in pairs(player_queue.queued) do
        local player_state = runtime.player_states[player_index]
        if not player_state or not player_state.ready_queued then
            stale_player_queue_entries[#stale_player_queue_entries + 1] = player_index
        end
    end

    for _, player_index in ipairs(stale_player_queue_entries) do
        ei_runtime_scheduler.queue_remove_value(player_queue, player_index)
    end

    for player_index, player_state in pairs(runtime.player_states) do
        if player_state.ready_queued and player_queue.queued[player_index] ~= true then
            player_state.ready_queued = false
            if not player_state.next_ready_tick then
                model.enqueue_ready_player(runtime, player_index)
            end
        end
    end

    compact_queue(player_queue)

    local rebuilt_target_surface_counts = {}
    local rebuilt_active_surfaces = {}
    local rebuilt_active_surface_positions = {}
    local rebuilt_ready_target_count = 0
    local empty_surface_queues = {}

    for surface_index, queue in pairs(runtime.target_surface_queues) do
        local ready_count = ei_runtime_scheduler.table_count(queue.queued)
        if ready_count > 0 then
            rebuilt_target_surface_counts[surface_index] = ready_count
            rebuilt_ready_target_count = rebuilt_ready_target_count + ready_count
            rebuilt_active_surfaces[#rebuilt_active_surfaces + 1] = surface_index
            rebuilt_active_surface_positions[surface_index] = #rebuilt_active_surfaces
        elseif ei_runtime_scheduler.queue_item_count(queue) == 0 then
            empty_surface_queues[#empty_surface_queues + 1] = surface_index
        end
    end

    for _, surface_index in ipairs(empty_surface_queues) do
        runtime.target_surface_queues[surface_index] = nil
    end

    runtime.ready_target_count = rebuilt_ready_target_count
    runtime.target_surface_counts = rebuilt_target_surface_counts
    runtime.active_surfaces = rebuilt_active_surfaces
    runtime.active_surface_positions = rebuilt_active_surface_positions

    if #rebuilt_active_surfaces == 0 or runtime.active_surface_cursor > #rebuilt_active_surfaces then
        runtime.active_surface_cursor = 1
    end
end

function model.release_due_targets(runtime, tick)
    if runtime.last_due_target_release_tick == tick then
        return
    end

    runtime.last_due_target_release_tick = tick

    local due_ticks = raw_due_bucket_ticks(runtime.delayed_target_buckets, tick)
    if #due_ticks == 0 then
        return
    end

    for _, due_tick in ipairs(due_ticks) do
        local bucket = runtime.delayed_target_buckets[due_tick]
        runtime.delayed_target_buckets[due_tick] = nil

        if type(bucket) == "table" then
            for target_id in pairs(bucket) do
                local target_entry = runtime.targets[target_id]
                if target_entry then
                    target_entry.next_ready_tick = nil
                    if model.entity_check(target_entry.entity) then
                        target_entry.surface_index = ei_lib.get_surface_index(target_entry.entity.surface)
                        model.enqueue_ready_target(runtime, target_id, target_entry.surface_index)
                    else
                        model.remove_target_entry(runtime, target_id, target_entry)
                    end
                end
            end
        end
    end
end

function model.release_due_players(runtime, tick)
    if runtime.last_due_player_release_tick == tick then
        return
    end

    runtime.last_due_player_release_tick = tick

    local due_ticks = raw_due_bucket_ticks(runtime.delayed_player_buckets, tick)
    if #due_ticks == 0 then
        return
    end

    for _, due_tick in ipairs(due_ticks) do
        local bucket = runtime.delayed_player_buckets[due_tick]
        runtime.delayed_player_buckets[due_tick] = nil

        if type(bucket) == "table" then
            for player_index in pairs(bucket) do
                local player_state = runtime.player_states[player_index]
                if player_state then
                    player_state.next_ready_tick = nil
                    model.sync_player_state(runtime, player_index)
                end
            end
        end
    end
end

function model.is_better_tower(candidate, current)
    if not candidate then
        return false
    end

    if not current then
        return true
    end

    local candidate_quality = candidate.quality_sort_level or 0
    local current_quality = current.quality_sort_level or 0
    if candidate_quality ~= current_quality then
        return candidate_quality > current_quality
    end

    return (candidate.unit_number or 0) < (current.unit_number or 0)
end

function model.tower_matches_target(tower_entry, desired_target_type, equipment_mode, allow_any_vehicle_mode)
    if not tower_entry or not model.entity_check(tower_entry.entity) then
        return false
    end

    local tower_equipment_mode = tower_entry.equipment_mode == true
    if tower_equipment_mode ~= equipment_mode then
        return false
    end

    if not equipment_mode and allow_any_vehicle_mode then
        return true
    end

    local tower_target_type = tower_entry.target_type or model.target_types[1]
    return tower_target_type == desired_target_type
end

function model.select_service_towers(runtime, target, desired_target_type, allow_vehicle_mode, allow_equipment_mode, allow_any_vehicle_mode, tick)
    if not model.entity_check(target) or not target.surface or not target.position then
        return nil, nil
    end

    local surface_index = ei_lib.get_surface_index(target.surface)
    local chunk_x, chunk_y = ei_lib.get_chunk_coordinates(target.position, FUELER_CHUNK_SIZE)
    local bucket = model.get_tower_chunk_bucket(runtime, surface_index, chunk_x, chunk_y, false)
    if not bucket then
        return nil, nil
    end

    local best_vehicle = nil
    local best_equipment = nil
    local range_sqr = runtime.cached_range_sqr or 0
    local target_force_index = get_force_index(target.force)

    -- Select the best matching tower(s) in one pass instead of sorting the whole candidate list.
    for tower_id in pairs(bucket) do
        local tower_entry = runtime.towers[tower_id]
        local tower = tower_entry and tower_entry.entity or nil

        if model.entity_check(tower)
            and tower_entry.surface_index == surface_index
            and target_force_index == get_force_index(tower.force)
            and ei_lib.is_within_range_squared(target.position, tower.position, range_sqr) then
            if model.get_tower_slice_remaining(tower_entry, tick) > 0 then
                if allow_vehicle_mode
                    and model.tower_matches_target(tower_entry, desired_target_type, false, allow_any_vehicle_mode)
                    and model.is_better_tower(tower_entry, best_vehicle) then
                    best_vehicle = tower_entry
                end

                if allow_equipment_mode
                    and model.tower_matches_target(tower_entry, desired_target_type, true, false)
                    and model.is_better_tower(tower_entry, best_equipment) then
                    best_equipment = tower_entry
                end
            end
        elseif tower_entry and not model.entity_check(tower) then
            model.remove_tower_entry(runtime, tower_id, tower_entry)
            storage.ei.fueler[tower_id] = nil
        end
    end

    return best_vehicle, best_equipment
end

function model.get_retry_delay(entity_type)
    if static_target_types[entity_type] then
        return STATIC_RETRY_COOLDOWN_TICKS
    end

    return MOVING_RETRY_COOLDOWN_TICKS
end

function model.process_target_entry(runtime, target_entry, event)
    local target = target_entry and target_entry.entity or nil
    if not model.entity_check(target) then
        if target_entry then
            model.remove_target_entry(runtime, target_entry.unit_number, target_entry)
        end
        return false
    end

    target_entry.surface_index = ei_lib.get_surface_index(target.surface)

    local desired_target_type = get_entity_target_type(target)
    local allow_vehicle_mode = target.type ~= "character"
    local allow_equipment_mode = target.type == "character" or is_vehicle_target_type(target.type)
    local allow_any_vehicle_mode = static_target_types[target.type] == true

    local vehicle_tower, equipment_tower = model.select_service_towers(
        runtime,
        target,
        desired_target_type,
        allow_vehicle_mode,
        allow_equipment_mode,
        allow_any_vehicle_mode,
        event.tick
    )

    local attempted = false
    local success = false

    if vehicle_tower then
        attempted = true
        model.consume_tower_slice_budget(vehicle_tower, event.tick)
        success = model.refuel_target(vehicle_tower.entity, target, target.type) or success
    end

    if equipment_tower then
        attempted = true
        model.consume_tower_slice_budget(equipment_tower, event.tick)
        success = model.refuel_equipments(equipment_tower.entity, target) or success
    end

    if success then
        model.schedule_target(runtime, target_entry, event.tick, SUCCESS_COOLDOWN_TICKS)
    elseif attempted then
        model.schedule_target(runtime, target_entry, event.tick, FAILED_ACTION_COOLDOWN_TICKS)
    else
        model.schedule_target(runtime, target_entry, event.tick, model.get_retry_delay(target.type))
    end

    return true
end

function model.process_player_state(runtime, player_state, event)
    local player = player_state and game.get_player(player_state.player_index) or nil
    local character = player_state and player_state.character or nil

    if not player or not player.connected or not model.entity_check(character) then
        model.unregister_player_by_index(runtime, player_state and player_state.player_index)
        return false
    end

    local _, equipment_tower = model.select_service_towers(
        runtime,
        character,
        "character",
        false,
        true,
        false,
        event.tick
    )

    local attempted = false
    local success = false

    if equipment_tower then
        attempted = true
        model.consume_tower_slice_budget(equipment_tower, event.tick)
        success = model.refuel_equipments(equipment_tower.entity, character) or success
    end

    if success then
        model.schedule_player(runtime, player_state, event.tick, SUCCESS_COOLDOWN_TICKS)
    elseif attempted then
        model.schedule_player(runtime, player_state, event.tick, FAILED_ACTION_COOLDOWN_TICKS)
    else
        model.schedule_player(runtime, player_state, event.tick, MOVING_RETRY_COOLDOWN_TICKS)
    end

    return true
end

function model.process_ready_target(runtime, event)
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

        while true do
            local target_id = model.dequeue_surface_target(runtime, surface_index)
            if not target_id then
                break
            end

            local target_entry = runtime.targets[target_id]
            if target_entry and model.entity_check(target_entry.entity) then
                return model.process_target_entry(runtime, target_entry, event)
            end

            if target_entry then
                model.remove_target_entry(runtime, target_id, target_entry)
            end
        end

        surface_attempts = surface_attempts - 1
    end

    return false
end

function model.process_ready_player(runtime, event)
    while true do
        local player_index = model.dequeue_ready_player(runtime)
        if not player_index then
            return false
        end

        local player_state = runtime.player_states[player_index]
        if player_state then
            return model.process_player_state(runtime, player_state, event)
        end
    end
end

function model.get_target_type(unit)
    local fueler_data = storage
        and storage.ei
        and storage.ei.fueler
        and unit
        and storage.ei.fueler[unit]

    local target_type = fueler_data and fueler_data.target_type
    if not target_type then
        target_type = model.target_types[1]
    end

    return target_type
end

local function sync_tower_runtime_preferences(unit)
    local runtime = storage
        and storage.ei
        and storage.ei.fueler_rt
    local tower_entry = runtime
        and runtime.towers
        and runtime.towers[unit]

    if not tower_entry then
        return
    end

    tower_entry.target_type = model.get_target_type(unit)
    tower_entry.equipment_mode = model.get_equipment(unit)
end

function model.set_target_type(unit, target_type)
    if not target_type then
        target_type = model.target_types[1]
    end

    local fueler_data = storage
        and storage.ei
        and storage.ei.fueler
        and unit
        and storage.ei.fueler[unit]

    if fueler_data then
        fueler_data.target_type = target_type
        sync_tower_runtime_preferences(unit)
    end
end

function model.get_equipment(unit)
    local fueler_data = storage
        and storage.ei
        and storage.ei.fueler
        and unit
        and storage.ei.fueler[unit]

    local equipment = fueler_data and fueler_data.equipment
    if equipment == nil then
        equipment = false
    end

    return equipment
end

function model.set_equipment(unit, equipment)
    if not equipment then
        equipment = false
    end

    if storage.ei and storage.ei.fueler and storage.ei.fueler[unit] then
        storage.ei.fueler[unit].equipment = equipment
        sync_tower_runtime_preferences(unit)
    end
end

function model.rebuild_runtime_state(reason)
    local runtime = model.check_global()
    if runtime.runtime_rebuild_in_progress then
        return
    end

    runtime.runtime_rebuild_in_progress = true
    model.reset_runtime_storage(runtime)

    local seen_fuelers = {}

    for _, surface in pairs(game.surfaces) do
        local fuelers = surface.find_entities_filtered({
            name = "ei-fueler"
        })

        for _, fueler in pairs(fuelers) do
            if model.entity_check(fueler) then
                model.register_fueler(fueler)
                local unit_number = get_entity_unit_number(fueler)
                if unit_number then
                    seen_fuelers[unit_number] = true
                end
            end
        end
    end

    for unit_number in pairs(storage.ei.fueler) do
        if not seen_fuelers[unit_number] then
            storage.ei.fueler[unit_number] = nil
        end
    end

    for _, surface in pairs(game.surfaces) do
        local targets = surface.find_entities_filtered({
            type = runtime_target_type_names
        })

        for _, entity in pairs(targets) do
            if model.entity_check(entity) then
                model.register_target(entity)
            end
        end
    end

    model.sync_connected_players(runtime)

    runtime.runtime_version = FUELER_RUNTIME_VERSION
    runtime.needs_rebuild = false
    runtime.runtime_rebuild_in_progress = false
    runtime.player_sync_dirty = false
    runtime.last_player_sync_tick = game and game.tick or 0
    runtime.last_integrity_audit_tick = game and game.tick or 0

    if reason == "manual" then
        model.clear_legacy_runtime_fields()
    end
end

function model.ensure_runtime_ready()
    local runtime = model.check_global()
    if runtime.runtime_rebuild_in_progress then
        return runtime
    end

    if runtime.needs_rebuild then
        model.rebuild_runtime_state("auto")
        runtime = storage.ei and storage.ei.fueler_rt or runtime
    end

    return runtime
end

function model.get_ready_target_count()
    local runtime = model.check_global()
    return runtime.ready_target_count or 0
end

function model.get_pending_work_count(event)
    local runtime = storage and storage.ei and storage.ei.fueler_rt or nil
    if type(runtime) ~= "table" or runtime.runtime_rebuild_in_progress then
        return 0
    end

    local tick = event and event.tick or game and game.tick or 0

    local pending = math.max(
        tonumber(runtime.ready_target_count) or 0,
        raw_surface_queue_item_count(runtime.target_surface_queues)
    )

    pending = pending + raw_queue_item_count(runtime.player_queue)
    pending = pending + raw_due_bucket_item_count(runtime.delayed_target_buckets, tick)
    pending = pending + raw_due_bucket_item_count(runtime.delayed_player_buckets, tick)

    if runtime.needs_rebuild == true then
        pending = pending + 1
    end

    if runtime.player_sync_dirty == true then
        pending = pending + 1
    end

    local has_tracked_runtime = raw_table_has_entries(runtime.towers)
        or raw_table_has_entries(runtime.targets)
        or raw_table_has_entries(runtime.player_states)

    if has_tracked_runtime
        and (tick - (runtime.last_player_sync_tick or -PLAYER_SYNC_INTERVAL_TICKS)) >= PLAYER_SYNC_INTERVAL_TICKS
    then
        pending = pending + 1
    end

    if has_tracked_runtime
        and (tick - (runtime.last_integrity_audit_tick or -INTEGRITY_AUDIT_INTERVAL_TICKS)) >= INTEGRITY_AUDIT_INTERVAL_TICKS
    then
        pending = pending + 1
    end

    return pending
end

function model.has_tick_work(event)
    return model.get_pending_work_count(event) > 0
end

--HANDLERS
------------------------------------------------------------------------------------------------------

function model.on_built_entity(entity)
    if not model.entity_check(entity) then
        return
    end

    local is_fueler = entity.name == "ei-fueler"
    if not is_fueler and not model.is_supported_runtime_target(entity) then
        return
    end

    local runtime = model.ensure_runtime_ready()
    if not runtime or runtime.runtime_rebuild_in_progress then
        return
    end

    if is_fueler then
        model.register_fueler(entity)
    else
        model.register_target(entity)
    end
end

function model.on_destroyed_entity(entity, transfer)
    if not model.entity_check(entity) then
        return
    end

    local is_fueler = entity.name == "ei-fueler"
    if not is_fueler and not runtime_target_types[entity.type] then
        return
    end

    local runtime = model.ensure_runtime_ready()
    if not runtime or runtime.runtime_rebuild_in_progress then
        return
    end

    if is_fueler then
        if model.entity_check(entity) then
            model.unregister_fueler(entity, transfer)
        end
        return
    end

    if runtime_target_types[entity.type] then
        model.unregister_target(entity)
    end
end

function model.mark_players_dirty()
    local runtime = model.check_global()
    runtime.player_sync_dirty = true
end

function model.on_player_ready(player_index)
    local runtime = model.ensure_runtime_ready()
    if not runtime or runtime.runtime_rebuild_in_progress then
        return
    end

    runtime.player_sync_dirty = false
    model.sync_player_state(runtime, player_index)
end

function model.on_player_left_game(player_index)
    local runtime = model.check_global()
    runtime.player_sync_dirty = false
    model.unregister_player_by_index(runtime, player_index)
end

function model.updater(event)
    local runtime = model.ensure_runtime_ready()
    if not runtime or runtime.runtime_rebuild_in_progress then
        return false
    end

    if runtime.last_housekeeping_tick ~= event.tick then
        runtime.last_housekeeping_tick = event.tick
        if runtime.player_sync_dirty or (event.tick - (runtime.last_player_sync_tick or -PLAYER_SYNC_INTERVAL_TICKS)) >= PLAYER_SYNC_INTERVAL_TICKS then
            runtime.last_player_sync_tick = event.tick
            model.sync_connected_players(runtime)
        end

        if (event.tick - (runtime.last_integrity_audit_tick or -INTEGRITY_AUDIT_INTERVAL_TICKS)) >= INTEGRITY_AUDIT_INTERVAL_TICKS then
            runtime.last_integrity_audit_tick = event.tick
            model.audit_runtime_state(runtime)
        end

        model.release_due_targets(runtime, event.tick)
        model.release_due_players(runtime, event.tick)
    end

    if model.process_ready_target(runtime, event) then
        return true
    end

    return model.process_ready_player(runtime, event)
end

function model.get_runtime_status()
    local runtime = model.check_global()
    local ready_surface_queue_items = 0

    for _, queue in pairs(runtime.target_surface_queues or {}) do
        ready_surface_queue_items = ready_surface_queue_items + ei_runtime_scheduler.queue_item_count(queue)
    end

    local status = {
        tower_count = ei_runtime_scheduler.table_count(runtime.towers),
        target_count = runtime.target_count or 0,
        ready_target_count = runtime.ready_target_count or 0,
        ready_surface_queue_items = ready_surface_queue_items,
        active_surface_count = #(runtime.active_surfaces or {}),
        player_state_count = ei_runtime_scheduler.table_count(runtime.player_states),
        ready_player_queue = ei_runtime_scheduler.audit_queue(runtime.player_queue),
        delayed_target_bucket_count = ei_runtime_scheduler.delayed_bucket_count(runtime.delayed_target_buckets),
        delayed_target_item_count = ei_runtime_scheduler.delayed_item_count(runtime.delayed_target_buckets),
        delayed_player_bucket_count = ei_runtime_scheduler.delayed_bucket_count(runtime.delayed_player_buckets),
        delayed_player_item_count = ei_runtime_scheduler.delayed_item_count(runtime.delayed_player_buckets),
        last_housekeeping_tick = runtime.last_housekeeping_tick or -1,
        last_player_sync_tick = runtime.last_player_sync_tick or -PLAYER_SYNC_INTERVAL_TICKS,
        last_integrity_audit_tick = runtime.last_integrity_audit_tick or -INTEGRITY_AUDIT_INTERVAL_TICKS,
        player_sync_dirty = runtime.player_sync_dirty == true,
        needs_rebuild = runtime.needs_rebuild == true,
        targets = runtime.target_count or 0,
        ready_targets = runtime.ready_target_count or 0,
        active_surfaces = #(runtime.active_surfaces or {}),
        delayed_target_buckets = ei_runtime_scheduler.delayed_bucket_count(runtime.delayed_target_buckets),
        delayed_player_buckets = ei_runtime_scheduler.delayed_bucket_count(runtime.delayed_player_buckets),
        player_queue = ei_runtime_scheduler.queue_item_count(runtime.player_queue),
    }

    ei_runtime_scheduler.set_module_status("fueler", status)
    return status
end

commands.add_command("rescan_fuelers", "Rebuilds Fueler tower runtime queues, target indices, and player tracking state.", function(command)
    local player = command.player_index and game.get_player(command.player_index) or nil
    if player and not player.admin then
        return
    end

    ei_lib.crystal_echo("Fueler runtime rescan initiated.")
    model.rebuild_runtime_state("manual")
    ei_lib.crystal_echo("Fueler runtime rescan complete.")
end)

--GUI
------------------------------------------------------------------------------------------------------

function model.open_gui(player)
    if player.gui.relative["ei-fueler-console"] then
        model.close_gui(player)
    end

    local root = player.gui.relative.add{
        type = "frame",
        name = "ei-fueler-console",
        anchor = {
            gui = defines.relative_gui_type.container_gui,
            name = "ei-fueler",
            position = defines.relative_gui_position.right,
        },
        direction = "vertical",
    }

    do
        local titlebar = root.add{type = "flow", direction = "horizontal"}
        titlebar.add{
            type = "label",
            caption = {"exotic-industries-fueler.fueler-gui-title"},
            style = "frame_title",
        }

        titlebar.add{
            type = "empty-widget",
            style = "ei_titlebar_draggable_spacer",
            ignored_by_interaction = true
        }

        titlebar.add{
            type = "sprite-button",
            sprite = "virtual-signal/informatron",
            style = "frame_action_button",
            tags = {
                parent_gui = "ei-fueler-console",
                action = "goto-informatron",
                page = "exotic-industries-fueler-informatron"
            }
        }
    end

    local main_container = root.add{
        type = "frame",
        name = "main-container",
        direction = "vertical",
        style = "inside_shallow_frame",
    }

    do
        main_container.add{
            type = "frame",
            style = "ei_subheader_frame",
        }.add{
            type = "label",
            caption = {"exotic-industries-fueler.fueler-gui-control-title"},
            style = "subheader_caption_label",
        }

        local control_flow = main_container.add{
            type = "flow",
            name = "control-flow",
            direction = "vertical",
            style = "ei_inner_content_flow",
        }

        control_flow.add{
            type = "label",
            caption = {"exotic-industries-fueler.fueler-gui-control-description"},
            tooltip = {"exotic-industries-fueler.fueler-gui-control-description-tooltip"},
        }

        local button_frame = control_flow.add{
            type = "frame",
            name = "target-frame",
            style = "slot_button_deep_frame"
        }

        for _, target_name in ipairs(model.target_types) do
            button_frame.add{
                type = "sprite-button",
                sprite = "entity/" .. target_name,
                tooltip = {"entity-name." .. target_name},
                tags = {
                    action = "set-target-type",
                    parent_gui = "ei-fueler-console",
                    target_type = target_name
                },
                style = "ei_slot_button_radio"
            }
        end

        control_flow.add{type = "empty-widget", style = "ei_vertical_pusher"}

        control_flow.add{
            type = "label",
            caption = {"exotic-industries-fueler.fueler-gui-equipment-description"},
            tooltip = {"exotic-industries-fueler.fueler-gui-equipment-description-tooltip"},
        }

        local equipment_frame = control_flow.add{
            type = "frame",
            name = "equipment-frame",
            style = "slot_button_deep_frame"
        }

        equipment_frame.add{
            type = "sprite-button",
            sprite = "ei-vehicle",
            tooltip = {"exotic-industries-fueler.vehicle"},
            tags = {
                action = "set-equipment-type",
                parent_gui = "ei-fueler-console",
                equipment_type = false
            },
            style = "ei_slot_button_radio"
        }

        equipment_frame.add{
            type = "sprite-button",
            sprite = "ei-equipment",
            tooltip = {"exotic-industries-fueler.equipment"},
            tags = {
                action = "set-equipment-type",
                parent_gui = "ei-fueler-console",
                equipment_type = true
            },
            style = "ei_slot_button_radio"
        }

        control_flow.add{type = "empty-widget", style = "ei_vertical_pusher"}
    end

    model.update_gui(player)
end

local function get_opened_fueler_unit(player)
    local opened = player and player.opened or nil
    if not model.entity_check(opened) or opened.name ~= "ei-fueler" then
        return nil
    end

    return get_entity_unit_number(opened)
end

function model.update_gui(player)
    local root = player.gui.relative["ei-fueler-console"]
    if not root then
        return
    end

    local control = root["main-container"]["control-flow"]
    local target_frame = control["target-frame"]

    local fueler_unit = get_opened_fueler_unit(player)
    if not fueler_unit then
        model.close_gui(player)
        return
    end

    local target = model.get_target_type(fueler_unit)
    local equipment = model.get_equipment(fueler_unit)

    for _, elem in pairs(target_frame.children) do
        elem.enabled = elem.tags.target_type ~= target
    end

    local equipment_frame = control["equipment-frame"]
    for _, elem in pairs(equipment_frame.children) do
        elem.enabled = elem.tags.equipment_type ~= equipment
    end
end

function model.close_gui(player)
    if player.gui.relative["ei-fueler-console"] then
        player.gui.relative["ei-fueler-console"].destroy()
    end

    if player.gui.relative["ei_fueler-console"] then
        player.gui.relative["ei_fueler-console"].destroy()
    end
end

function model.on_gui_click(event)
    if event.element.tags.action == "set-target-type" then
        local player = game.players[event.player_index]
        local root = player.gui.relative["ei-fueler-console"]
        if not root then
            return
        end

        local fueler_unit = get_opened_fueler_unit(player)
        if not fueler_unit then
            model.close_gui(player)
            return
        end

        local target = event.element.tags.target_type

        model.set_target_type(fueler_unit, target)

        if target == "character" then
            model.set_equipment(fueler_unit, true)
        end

        model.update_gui(player)
    end

    if event.element.tags.action == "set-equipment-type" then
        local player = game.players[event.player_index]
        local root = player.gui.relative["ei-fueler-console"]
        if not root then
            return
        end

        local fueler_unit = get_opened_fueler_unit(player)
        if not fueler_unit then
            model.close_gui(player)
            return
        end

        local equipment_type = event.element.tags.equipment_type

        if equipment_type == false and model.get_target_type(fueler_unit) == "character" then
            return
        end

        model.set_equipment(fueler_unit, equipment_type)
        model.update_gui(player)
    end

    if event.element.tags.action == "goto-informatron" then
        remote.call("informatron", "informatron_open_to_page", {
            player_index = event.player_index,
            interface = "exotic-industries-fueler-informatron",
            page_name = event.element.tags.page
        })
    end
end

return model
