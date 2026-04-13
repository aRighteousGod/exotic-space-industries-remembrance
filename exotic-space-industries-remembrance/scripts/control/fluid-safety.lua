--==============================================================================
-- ESIR FILE MAP
-- owns: queued invalid-fluid auditing and fluid safety enforcement
-- loaded_by: exotic-space-industries-remembrance\control.lua
-- cadence: scheduled tick step 2 plus build/destroy checks
-- forwarded_events: classify_entity, counts_for_fluid_handling, ensure_fluid_runtime, enqueue_dirty_segment, enqueue_urgent_entity, get_fluid_work_count, on_fluid_entity_deregistered, on_fluid_entity_registered, rebuild_fluid_runtime, service_fluid_runtime, touch_entity
-- storage_roots: storage.ei
-- gui_ids: none
-- remote_interfaces: none
-- rebuild_on: entity registration changes
--==============================================================================

local model = {}
local ei_data = require("lib/data")
local ei_lib = require("lib/lib")
local ei_runtime_scheduler = require("lib/runtime-scheduler")

local FLUID_CLASS_NORMAL = "normal"
local FLUID_CLASS_DATA = "data"
local FLUID_CLASS_INSULATED = "insulated"

local FLUID_STATUS_EMPTY = "empty"
local FLUID_STATUS_SAFE = "safe"
local FLUID_STATUS_DATA = "data"
local FLUID_STATUS_CRYO_NITROGEN = "cryo_nitrogen"
local FLUID_STATUS_CRYO_OXYGEN = "cryo_oxygen"
local FLUID_STATUS_NEEDS_INSULATED = "needs_insulated"

local SEGMENT_MEMBER_ACTION_BUDGET = 32
local FLUID_SERVICE_ROTATION = {"urgent", "urgent", "dirty", "urgent", "scan"}

local computing_fluid_lookup = {}
for _, fluid_name in ipairs(ei_data.computing_types or {}) do
    computing_fluid_lookup[fluid_name] = true
end

local insulated_required_lookup = {
    ["lava"] = true,
    ["fluoroketone-cold"] = true,
    ["fluoroketone-hot"] = true,
    ["electrolyte"] = true,
}

local cryo_conversion_lookup = {
    ["ei-liquid-nitrogen"] = "ei-nitrogen-gas",
    ["ei-liquid-oxygen"] = "ei-oxygen-gas",
}

-- Flip this on when chasing a fluid-runtime hang again.
local FLUID_DIAGNOSTICS_ENABLED = false

local function fluid_log(message)
    if not FLUID_DIAGNOSTICS_ENABLED then
        return
    end

    log("[ESIR fluid] " .. message)
end

local function new_fluid_runtime()
    return {
        initialized = false,
        entries_by_unit = {},
        tracked_count = 0,
        scan_units = {},
        scan_index = 1,
        urgent_units = ei_runtime_scheduler.ensure_queue(nil),
        urgent_head = 1,
        urgent_tail = 1,
        urgent_pending = {},
        segments = {},
        dirty_segments = ei_runtime_scheduler.ensure_queue(nil),
        dirty_head = 1,
        dirty_tail = 1,
        dirty_pending = {},
        service_mode_cursor = 1,
    }
end

local function sync_legacy_fluid_storage(runtime)
    storage.ei.fluid_entity = storage.ei.fluid_entity or {}
    storage.ei.fluid_entity_count = runtime.tracked_count or 0
end

local function count_present_keys(tbl)
    local count = 0
    for _ in pairs(tbl or {}) do
        count = count + 1
    end

    return count
end

local function next_member_after(tbl, key)
    if not tbl or not next(tbl) then
        return nil
    end

    if not key or tbl[key] == nil then
        local first_key = next(tbl)
        while first_key and tbl[first_key] == nil do
            first_key = next(tbl, first_key)
        end
        return first_key
    end

    local next_key = next(tbl, key)
    while next_key and tbl[next_key] == nil do
        next_key = next(tbl, next_key)
    end

    return next_key
end

local function next_member_wrapped(tbl, key)
    if not tbl or not next(tbl) then
        return nil
    end

    return next_member_after(tbl, key) or next_member_after(tbl, nil)
end

local function maybe_log_segment_warning(segment, tick_field, window_ticks, message)
    local tick = (game and game.tick) or 0
    if segment and segment[tick_field] and (tick - segment[tick_field]) < window_ticks then
        return
    end

    if segment then
        segment[tick_field] = tick
    end

    fluid_log(message)
end

local function log_segment_loop_guard(function_name, segment_id, member_count, status, fluid_name)
    fluid_log(
        string.format(
            "loop guard tripped function=%s segment=%s members=%s status=%s fluid=%s tick=%s",
            tostring(function_name),
            tostring(segment_id),
            tostring(member_count),
            tostring(status),
            tostring(fluid_name),
            tostring((game and game.tick) or 0)
        )
    )
end

local function sync_queue_cursor_fields(state, queue, head_key, tail_key)
    queue = ei_runtime_scheduler.ensure_queue(queue)
    state[head_key] = queue.head or 1
    state[tail_key] = (queue.tail or 0) + 1
    return queue
end

local function ensure_runtime_queue(state, queue_key, head_key, tail_key)
    local queue = state[queue_key]
    if type(queue) ~= "table" then
        queue = {}
    end

    if queue.items then
        queue = ei_runtime_scheduler.ensure_queue(queue)
    else
        local items = {}
        local new_tail = 0
        local head = math.max(1, state[head_key] or 1)
        local tail = math.max(head, state[tail_key] or 1)

        for index = head, tail - 1 do
            local value = queue[index]
            if value ~= nil then
                new_tail = new_tail + 1
                items[new_tail] = value
            end
        end

        queue = ei_runtime_scheduler.ensure_queue({
            items = items,
            head = 1,
            tail = new_tail,
        })
    end

    state[queue_key] = queue
    return sync_queue_cursor_fields(state, queue, head_key, tail_key)
end

local function queue_push(state, queue, head_key, tail_key, value)
    ei_runtime_scheduler.queue_push(queue, value)
    sync_queue_cursor_fields(state, queue, head_key, tail_key)
end

local function queue_pop(state, queue, head_key, tail_key)
    local value = ei_runtime_scheduler.queue_pop(queue)
    sync_queue_cursor_fields(state, queue, head_key, tail_key)
    return value
end

local function queue_depth(state, queue_key, head_key, tail_key)
    local queue = ensure_runtime_queue(state, queue_key, head_key, tail_key)
    return ei_runtime_scheduler.queue_item_count(queue)
end

local function entity_has_fluidbox(entity)
    if not (entity and entity.valid and entity.fluidbox) then
        return false
    end

    return #entity.fluidbox >= 1
end

local function get_fluidbox_segment_id(entity)
    if not entity_has_fluidbox(entity) then
        return nil
    end

    local ok, segment_id = pcall(function()
        return entity.fluidbox.get_fluid_segment_id(1)
    end)

    if ok then
        return segment_id
    end

    return nil
end

local function clear_entity_fluids(entity)
    if entity and entity.valid then
        entity.clear_fluid_inside()
    end
end

local function classify_fluid_status(fluid_name)
    if not fluid_name then
        return FLUID_STATUS_EMPTY
    end

    if computing_fluid_lookup[fluid_name] then
        return FLUID_STATUS_DATA
    end

    if fluid_name == "ei-liquid-nitrogen" then
        return FLUID_STATUS_CRYO_NITROGEN
    end

    if fluid_name == "ei-liquid-oxygen" then
        return FLUID_STATUS_CRYO_OXYGEN
    end

    if fluid_name:find("ei%-heated%-", 1) == 1 or insulated_required_lookup[fluid_name] then
        return FLUID_STATUS_NEEDS_INSULATED
    end

    return FLUID_STATUS_SAFE
end

local function get_first_fluid_name_and_amount(fluid_contents)
    if not fluid_contents then
        return nil, 0
    end

    for fluid_name, amount in pairs(fluid_contents) do
        if amount and amount > 0 then
            return fluid_name, amount
        end
    end

    return nil, 0
end

local function read_entity_fluid(entity)
    if not (entity and entity.valid) then
        return nil, 0
    end

    if entity.get_fluid_count and entity.get_fluid_count() <= 0 then
        return nil, 0
    end

    return get_first_fluid_name_and_amount(entity.get_fluid_contents())
end

local function get_runtime_entry(runtime, unit_or_entity)
    if not unit_or_entity then
        return nil
    end

    if type(unit_or_entity) == "number" then
        return runtime.entries_by_unit[unit_or_entity]
    end

    if unit_or_entity.unit_number then
        return runtime.entries_by_unit[unit_or_entity.unit_number]
    end

    return nil
end

local function get_segment(runtime, segment_id)
    if not segment_id then
        return nil
    end

    local segment = runtime.segments[segment_id]
    if not segment then
        segment = {
            members = {},
            cursor_unit = nil,
            status = FLUID_STATUS_EMPTY,
            representative_unit = nil,
            last_notified_tick = nil,
            last_scan_enqueued_tick = nil,
        }
        runtime.segments[segment_id] = segment
    end

    return segment
end

local function cleanup_segment_if_empty(runtime, segment_id)
    if not segment_id then
        return
    end

    local segment = runtime.segments[segment_id]
    if segment and not next(segment.members) then
        runtime.segments[segment_id] = nil
    end
end

local function remove_entry_from_segment(runtime, entry, segment_id)
    if not (entry and segment_id) then
        return
    end

    local segment = runtime.segments[segment_id]
    if not segment then
        return
    end

    segment.members[entry.unit_number] = nil
    if segment.cursor_unit == entry.unit_number then
        segment.cursor_unit = nil
    end
    if segment.representative_unit == entry.unit_number then
        segment.representative_unit = next(segment.members)
    end

    cleanup_segment_if_empty(runtime, segment_id)
end

local function add_entry_to_segment(runtime, entry, segment_id)
    if not (entry and segment_id) then
        return
    end

    local segment = get_segment(runtime, segment_id)
    segment.members[entry.unit_number] = true
    if not segment.representative_unit then
        segment.representative_unit = entry.unit_number
    end
end

local function remove_scan_unit(runtime, unit_number)
    local entry = runtime.entries_by_unit[unit_number]
    if not entry or not entry.dense_index then
        return
    end

    local remove_index = entry.dense_index
    local last_index = #runtime.scan_units
    local last_unit = runtime.scan_units[last_index]

    runtime.scan_units[remove_index] = last_unit
    runtime.scan_units[last_index] = nil

    if last_unit and last_unit ~= unit_number then
        local last_entry = runtime.entries_by_unit[last_unit]
        if last_entry then
            last_entry.dense_index = remove_index
        end
    end

    if runtime.scan_index > #runtime.scan_units then
        runtime.scan_index = 1
    end
end

local function prune_runtime_entry(runtime, unit_number)
    local entry = runtime.entries_by_unit[unit_number]
    if not entry then
        return false
    end

    remove_entry_from_segment(runtime, entry, entry.last_segment_id)
    runtime.urgent_pending[unit_number] = nil
    remove_scan_unit(runtime, unit_number)
    runtime.entries_by_unit[unit_number] = nil
    runtime.tracked_count = math.max(0, runtime.tracked_count - 1)

    storage.ei.fluid_entity[unit_number] = nil
    sync_legacy_fluid_storage(runtime)

    return true
end

local function set_entry_segment(runtime, entry, segment_id, enqueue_dirty)
    local old_segment_id = entry.last_segment_id
    if old_segment_id == segment_id then
        return false
    end

    remove_entry_from_segment(runtime, entry, old_segment_id)
    entry.last_segment_id = segment_id
    add_entry_to_segment(runtime, entry, segment_id)

    if enqueue_dirty then
        if old_segment_id then
            model.enqueue_dirty_segment(old_segment_id)
        end
        if segment_id then
            model.enqueue_dirty_segment(segment_id)
        end
    end

    return true
end

local function add_runtime_entry(runtime, entity)
    if not (entity and entity.valid and entity.unit_number) then
        return nil
    end

    local unit_number = entity.unit_number
    local entry = runtime.entries_by_unit[unit_number]
    if entry then
        entry.entity = entity
        entry.class = model.classify_entity(entity)
        storage.ei.fluid_entity[unit_number] = entity
        sync_legacy_fluid_storage(runtime)
        return entry
    end

    entry = {
        unit_number = unit_number,
        entity = entity,
        class = model.classify_entity(entity),
        dense_index = #runtime.scan_units + 1,
        last_segment_id = nil,
    }

    runtime.entries_by_unit[unit_number] = entry
    runtime.scan_units[entry.dense_index] = unit_number
    runtime.tracked_count = runtime.tracked_count + 1

    storage.ei.fluid_entity[unit_number] = entity
    sync_legacy_fluid_storage(runtime)

    return entry
end

local function get_segment_representative(runtime, segment_id)
    local segment = runtime.segments[segment_id]
    if not segment then
        return nil, nil
    end

    local unit_number = segment.representative_unit
    local entry = unit_number and runtime.entries_by_unit[unit_number] or nil
    if entry and entry.entity and entry.entity.valid and entry.last_segment_id == segment_id then
        return entry, segment
    end

    local member_count = count_present_keys(segment.members)
    local loop_limit = member_count + 1
    local iterations = 0
    unit_number = next_member_after(segment.members, nil)
    while unit_number do
        iterations = iterations + 1
        if iterations > loop_limit then
            log_segment_loop_guard("get_segment_representative", segment_id, member_count, segment.status, nil)
            runtime.segments[segment_id] = nil
            return nil, nil
        end

        local next_unit = next_member_after(segment.members, unit_number)
        entry = runtime.entries_by_unit[unit_number]
        if entry and entry.entity and entry.entity.valid then
            local current_segment_id = get_fluidbox_segment_id(entry.entity)
            if current_segment_id == segment_id then
                entry.last_segment_id = segment_id
                segment.representative_unit = unit_number
                return entry, segment
            end
        end

        segment.members[unit_number] = nil
        unit_number = next_unit
    end

    if member_count > 0 then
        maybe_log_segment_warning(
            segment,
            "last_missing_representative_log_tick",
            60,
            string.format(
                "segment representative missing segment=%s members=%s status=%s tick=%s",
                tostring(segment_id),
                tostring(member_count),
                tostring(segment.status),
                tostring((game and game.tick) or 0)
            )
        )
    end

    runtime.segments[segment_id] = nil
    return nil, nil
end

local function read_segment_fluid(runtime, segment_id)
    local representative_entry = get_segment_representative(runtime, segment_id)
    if not representative_entry then
        return nil, 0, FLUID_STATUS_EMPTY
    end

    local entity = representative_entry.entity
    if not entity_has_fluidbox(entity) then
        local fluid_name, amount = read_entity_fluid(entity)
        return fluid_name, amount, classify_fluid_status(fluid_name)
    end

    local fluid_name = nil
    local amount = 0
    local ok, contents = pcall(function()
        return entity.fluidbox.get_fluid_segment_contents(1)
    end)

    if ok and contents then
        fluid_name, amount = get_first_fluid_name_and_amount(contents)
    else
        fluid_name, amount = read_entity_fluid(entity)
    end

    return fluid_name, amount, classify_fluid_status(fluid_name)
end

local function maybe_notify_segment_violation(segment, entity, incompatible_name)
    if not (segment and entity and entity.valid) then
        return
    end

    if segment.last_notified_tick == game.tick then
        return
    end

    segment.last_notified_tick = game.tick

    if incompatible_name and entity.localised_name then
        ei_lib.notify_connected_players(
            "insulated_pipe",
            { "exotic-industries.incompatible-pipe-1", incompatible_name, entity.localised_name, entity.gps_tag }
        )
    else
        ei_lib.notify_connected_players(
            "insulated_pipe",
            { "exotic-industries.incompatible-pipe-2", entity.name, entity.gps_tag }
        )
    end

    ei_lib.crystal_echo_floating("Incompatible pipe", entity, 6000, "wrath")
end

local function destroy_offending_entity(segment, entry, incompatible_name)
    local entity = entry and entry.entity
    if not (entity and entity.valid) then
        return false
    end

    maybe_notify_segment_violation(segment, entity, incompatible_name)
    clear_entity_fluids(entity)
    entity.die(entity.force)
    return true
end

local function audit_unsegmented_entry(entry)
    if not (entry and entry.entity and entry.entity.valid) then
        return false
    end

    if entry.class == FLUID_CLASS_INSULATED then
        return true
    end

    local fluid_name, amount = read_entity_fluid(entry.entity)
    local status = classify_fluid_status(fluid_name)
    if status == FLUID_STATUS_EMPTY then
        return true
    end

    if status == FLUID_STATUS_DATA then
        if entry.class == FLUID_CLASS_NORMAL then
            destroy_offending_entity(nil, entry, fluid_name)
        end
        return true
    end

    if status == FLUID_STATUS_SAFE then
        if entry.class == FLUID_CLASS_DATA then
            destroy_offending_entity(nil, entry, fluid_name)
        end
        return true
    end

    if status == FLUID_STATUS_NEEDS_INSULATED then
        if entry.class ~= FLUID_CLASS_INSULATED then
            destroy_offending_entity(nil, entry, fluid_name)
        end
        return true
    end

    if status == FLUID_STATUS_CRYO_NITROGEN or status == FLUID_STATUS_CRYO_OXYGEN then
        if entry.class == FLUID_CLASS_DATA then
            destroy_offending_entity(nil, entry, fluid_name)
        elseif entry.class == FLUID_CLASS_NORMAL and amount > 0 then
            clear_entity_fluids(entry.entity)
            entry.entity.insert_fluid({ name = cryo_conversion_lookup[fluid_name], amount = amount })
        end
        return true
    end

    return true
end

local function current_entity_segment_id(entry)
    if not (entry and entry.entity and entry.entity.valid) then
        return nil
    end

    return get_fluidbox_segment_id(entry.entity)
end

local function advance_segment_cursor(segment)
    if not segment then
        return nil
    end

    if not segment.cursor_unit or segment.members[segment.cursor_unit] == nil then
        return next_member_wrapped(segment.members, nil)
    end

    return next_member_after(segment.members, segment.cursor_unit)
end

local function process_segment_violations(runtime, segment_id, status, incompatible_name)
    local segment = runtime.segments[segment_id]
    if not segment then
        return false
    end

    local member_count = count_present_keys(segment.members)
    local loop_limit = member_count + 1
    local iterations = 0
    local processed = 0
    local current_unit = advance_segment_cursor(segment)
    local last_processed = segment.cursor_unit

    while current_unit and processed < SEGMENT_MEMBER_ACTION_BUDGET do
        iterations = iterations + 1
        if iterations > loop_limit then
            log_segment_loop_guard("process_segment_violations", segment_id, member_count, status, incompatible_name)
            current_unit = nil
            break
        end

        local next_unit = next_member_after(segment.members, current_unit)
        local entry = runtime.entries_by_unit[current_unit]

        if not entry or not entry.entity or not entry.entity.valid then
            prune_runtime_entry(runtime, current_unit)
        else
            local live_segment_id = current_entity_segment_id(entry)
            if live_segment_id ~= segment_id then
                set_entry_segment(runtime, entry, live_segment_id, true)
            else
                entry.last_segment_id = segment_id

                local should_destroy = false
                if status == FLUID_STATUS_DATA then
                    should_destroy = entry.class == FLUID_CLASS_NORMAL
                elseif status == FLUID_STATUS_SAFE then
                    should_destroy = entry.class == FLUID_CLASS_DATA
                elseif status == FLUID_STATUS_NEEDS_INSULATED then
                    should_destroy = entry.class ~= FLUID_CLASS_INSULATED
                elseif status == FLUID_STATUS_CRYO_NITROGEN or status == FLUID_STATUS_CRYO_OXYGEN then
                    should_destroy = entry.class == FLUID_CLASS_DATA
                end

                if should_destroy then
                    destroy_offending_entity(segment, entry, incompatible_name)
                end
            end
        end

        processed = processed + 1
        last_processed = current_unit
        current_unit = next_unit
    end

    if current_unit then
        segment.cursor_unit = last_processed
        local tick = (game and game.tick) or 0
        if not segment.requeue_window_tick or (tick - segment.requeue_window_tick) >= 60 then
            segment.requeue_window_tick = tick
            segment.requeue_window_count = 0
        end
        segment.requeue_window_count = (segment.requeue_window_count or 0) + 1
        if segment.requeue_window_count >= 5 then
            maybe_log_segment_warning(
                segment,
                "last_requeue_storm_log_tick",
                60,
                string.format(
                    "dirty segment requeue storm segment=%s status=%s members=%s requeues=%s tick=%s",
                    tostring(segment_id),
                    tostring(status),
                    tostring(count_present_keys(segment.members)),
                    tostring(segment.requeue_window_count),
                    tostring(tick)
                )
            )
        end
        model.enqueue_dirty_segment(segment_id)
    else
        segment.cursor_unit = nil
        segment.requeue_window_tick = nil
        segment.requeue_window_count = nil
    end

    return processed > 0
end

local function segment_has_normal_member(runtime, segment_id)
    local segment = runtime.segments[segment_id]
    if not segment then
        return false
    end

    local member_count = count_present_keys(segment.members)
    local loop_limit = member_count + 1
    local iterations = 0
    local unit_number = next_member_after(segment.members, nil)
    while unit_number do
        iterations = iterations + 1
        if iterations > loop_limit then
            log_segment_loop_guard("segment_has_normal_member", segment_id, member_count, segment.status, nil)
            return false
        end

        local entry = runtime.entries_by_unit[unit_number]
        if entry and entry.entity and entry.entity.valid then
            local current_segment_id = get_fluidbox_segment_id(entry.entity)
            if current_segment_id == segment_id and entry.class == FLUID_CLASS_NORMAL then
                entry.last_segment_id = segment_id
                return true
            end
        end

        unit_number = next_member_after(segment.members, unit_number)
    end

    return false
end

local function convert_segment_fluid(runtime, segment_id, fluid_name)
    local representative_entry = get_segment_representative(runtime, segment_id)
    if not representative_entry then
        return false
    end

    local entity = representative_entry.entity
    local gas_name = cryo_conversion_lookup[fluid_name]
    if not gas_name or not entity_has_fluidbox(entity) then
        return false
    end

    local removed_amount = 0
    local ok, removed = pcall(function()
        return entity.fluidbox.flush(1, fluid_name)
    end)

    if ok and removed then
        removed_amount = removed[fluid_name] or 0
    else
        local _, amount = read_entity_fluid(entity)
        removed_amount = amount
        clear_entity_fluids(entity)
    end

    if removed_amount > 0 then
        entity.insert_fluid({ name = gas_name, amount = removed_amount })
    end

    return true
end

local function audit_segment(runtime, segment_id)
    local fluid_name, _, status = read_segment_fluid(runtime, segment_id)
    local segment = runtime.segments[segment_id]
    if not segment then
        return false
    end

    segment.status = status

    if status == FLUID_STATUS_EMPTY then
        segment.requeue_window_tick = nil
        segment.requeue_window_count = nil
        return true
    end

    if status == FLUID_STATUS_CRYO_NITROGEN or status == FLUID_STATUS_CRYO_OXYGEN then
        if segment_has_normal_member(runtime, segment_id) then
            convert_segment_fluid(runtime, segment_id, fluid_name)
        elseif next(segment.members) then
            maybe_log_segment_warning(
                segment,
                "last_cryo_no_normal_log_tick",
                60,
                string.format(
                    "cryo segment has no normal member segment=%s status=%s fluid=%s members=%s tick=%s",
                    tostring(segment_id),
                    tostring(status),
                    tostring(fluid_name),
                    tostring(count_present_keys(segment.members)),
                    tostring((game and game.tick) or 0)
                )
            )
        end
        process_segment_violations(runtime, segment_id, status, fluid_name)
        return true
    end

    if status == FLUID_STATUS_DATA or status == FLUID_STATUS_NEEDS_INSULATED or status == FLUID_STATUS_SAFE then
        process_segment_violations(runtime, segment_id, status, fluid_name)
        return true
    end

    return true
end

local function enqueue_connected_neighbors(runtime, entity)
    if not entity_has_fluidbox(entity) then
        return
    end

    local ok, connections = pcall(function()
        return entity.fluidbox.get_connections(1)
    end)

    if not ok or not connections then
        return
    end

    for _, connection in pairs(connections) do
        local owner = connection and connection.owner
        if owner and owner.valid and owner.unit_number and runtime.entries_by_unit[owner.unit_number] then
            model.enqueue_urgent_entity(owner.unit_number)
        end
    end
end

function model.ensure_fluid_runtime()
    storage.ei = storage.ei or {}
    storage.ei.fluid_entity = storage.ei.fluid_entity or {}

    local runtime = storage.ei.fluid_runtime
    if not runtime then
        runtime = new_fluid_runtime()
        storage.ei.fluid_runtime = runtime
    end

    runtime.entries_by_unit = runtime.entries_by_unit or {}
    runtime.tracked_count = runtime.tracked_count or 0
    runtime.scan_units = runtime.scan_units or {}
    runtime.scan_index = math.max(1, runtime.scan_index or 1)
    runtime.urgent_units = ensure_runtime_queue(runtime, "urgent_units", "urgent_head", "urgent_tail")
    runtime.urgent_pending = runtime.urgent_pending or {}
    runtime.segments = runtime.segments or {}
    runtime.dirty_segments = ensure_runtime_queue(runtime, "dirty_segments", "dirty_head", "dirty_tail")
    runtime.dirty_pending = runtime.dirty_pending or {}
    runtime.service_mode_cursor = math.max(1, runtime.service_mode_cursor or 1)
    runtime.initialized = runtime.initialized == true

    sync_legacy_fluid_storage(runtime)
    return runtime
end

function model.classify_entity(entity)
    if not entity then
        return FLUID_CLASS_NORMAL
    end

    local name = entity.name or ""
    if name:find("ei%-data", 1) == 1 then
        return FLUID_CLASS_DATA
    end

    if name:find("ei%-insulated", 1) == 1 then
        return FLUID_CLASS_INSULATED
    end

    return FLUID_CLASS_NORMAL
end

function model.counts_for_fluid_handling(entity)
    if entity.type == "pipe" or entity.type == "storage-tank" or entity.type == "pipe-to-ground" then
        return true
    end

    if entity.type == "furnace" and entity.name == "elevated-pipe" then
        return true
    end

    return false
end

function model.enqueue_urgent_entity(unit_number)
    local runtime = model.ensure_fluid_runtime()
    if not unit_number or runtime.urgent_pending[unit_number] then
        return false
    end

    queue_push(runtime, runtime.urgent_units, "urgent_head", "urgent_tail", unit_number)
    runtime.urgent_pending[unit_number] = true
    return true
end

function model.enqueue_dirty_segment(segment_id)
    local runtime = model.ensure_fluid_runtime()
    if not segment_id or runtime.dirty_pending[segment_id] then
        return false
    end

    queue_push(runtime, runtime.dirty_segments, "dirty_head", "dirty_tail", segment_id)
    runtime.dirty_pending[segment_id] = true
    return true
end

function model.touch_entity(unit_or_entity)
    local runtime = model.ensure_fluid_runtime()
    local entry = get_runtime_entry(runtime, unit_or_entity)
    if not entry and type(unit_or_entity) ~= "number" then
        entry = add_runtime_entry(runtime, unit_or_entity)
    end

    if not entry then
        return false
    end

    if not (entry.entity and entry.entity.valid) then
        prune_runtime_entry(runtime, entry.unit_number)
        return false
    end

    entry.class = model.classify_entity(entry.entity)
    local current_segment_id = current_entity_segment_id(entry)
    set_entry_segment(runtime, entry, current_segment_id, true)

    return true
end

function model.on_fluid_entity_registered(entity)
    local runtime = model.ensure_fluid_runtime()
    local entry = add_runtime_entry(runtime, entity)
    if not entry then
        return false
    end

    model.enqueue_urgent_entity(entry.unit_number)
    enqueue_connected_neighbors(runtime, entity)
    model.touch_entity(entry.unit_number)

    return true
end

function model.on_fluid_entity_deregistered(entity)
    local runtime = model.ensure_fluid_runtime()
    if not (entity and entity.unit_number) then
        return false
    end

    local entry = runtime.entries_by_unit[entity.unit_number]
    if not entry then
        return false
    end

    enqueue_connected_neighbors(runtime, entity)
    if entry.last_segment_id then
        model.enqueue_dirty_segment(entry.last_segment_id)
    end

    return prune_runtime_entry(runtime, entity.unit_number)
end

function model.rebuild_fluid_runtime(reason)
    local runtime = new_fluid_runtime()
    local rebuild_reason = reason or "unspecified"

    storage.ei = storage.ei or {}
    storage.ei.fluid_runtime = runtime
    storage.ei.fluid_entity = {}
    sync_legacy_fluid_storage(runtime)

    fluid_log(
        string.format(
            "rebuild begin reason=%s tick=%s surfaces=%s",
            tostring(rebuild_reason),
            tostring((game and game.tick) or 0),
            tostring(count_present_keys(game and game.surfaces or {}))
        )
    )

    for _, surface in pairs(game.surfaces) do
        for _, entity in pairs(surface.find_entities()) do
            if entity and entity.valid and entity.force and model.counts_for_fluid_handling(entity) then
                local entry = add_runtime_entry(runtime, entity)
                if entry then
                    entry.class = model.classify_entity(entity)
                    local segment_id = current_entity_segment_id(entry)
                    set_entry_segment(runtime, entry, segment_id, false)
                end
            end
        end
    end

    runtime.scan_index = 1
    runtime.urgent_units = ei_runtime_scheduler.clear_queue(runtime.urgent_units)
    sync_queue_cursor_fields(runtime, runtime.urgent_units, "urgent_head", "urgent_tail")
    runtime.dirty_segments = ei_runtime_scheduler.clear_queue(runtime.dirty_segments)
    sync_queue_cursor_fields(runtime, runtime.dirty_segments, "dirty_head", "dirty_tail")
    runtime.service_mode_cursor = 1
    runtime.initialized = true

    for segment_id, _ in pairs(runtime.segments) do
        model.enqueue_dirty_segment(segment_id)
    end

    sync_legacy_fluid_storage(runtime)
    fluid_log(
        string.format(
            "rebuild end reason=%s tick=%s tracked=%s segments=%s",
            tostring(rebuild_reason),
            tostring((game and game.tick) or 0),
            tostring(runtime.tracked_count or 0),
            tostring(count_present_keys(runtime.segments))
        )
    )
    return runtime
end

function model.get_fluid_work_count()
    local runtime = model.ensure_fluid_runtime()
    return runtime.tracked_count or 0
end

local function get_fluid_queue_snapshot(runtime)
    return {
        urgent = queue_depth(runtime, "urgent_units", "urgent_head", "urgent_tail"),
        dirty = queue_depth(runtime, "dirty_segments", "dirty_head", "dirty_tail"),
        scan = #runtime.scan_units,
    }
end

local function process_one_urgent(runtime)
    local unit_number = queue_pop(runtime, runtime.urgent_units, "urgent_head", "urgent_tail")
    while unit_number do
        runtime.urgent_pending[unit_number] = nil
        local entry = runtime.entries_by_unit[unit_number]
        if entry then
            if not (entry.entity and entry.entity.valid) then
                prune_runtime_entry(runtime, unit_number)
                return true
            end

            model.touch_entity(unit_number)
            local live_entry = runtime.entries_by_unit[unit_number]
            if live_entry then
                if live_entry.last_segment_id then
                    model.enqueue_dirty_segment(live_entry.last_segment_id)
                else
                    audit_unsegmented_entry(live_entry)
                end
                return true
            end
        end

        unit_number = queue_pop(runtime, runtime.urgent_units, "urgent_head", "urgent_tail")
    end

    return false
end

local function process_one_dirty(runtime)
    local segment_id = queue_pop(runtime, runtime.dirty_segments, "dirty_head", "dirty_tail")
    while segment_id do
        runtime.dirty_pending[segment_id] = nil
        if runtime.segments[segment_id] then
            audit_segment(runtime, segment_id)
            return true
        end
        segment_id = queue_pop(runtime, runtime.dirty_segments, "dirty_head", "dirty_tail")
    end

    return false
end

local function process_one_scan(runtime)
    local tracked_count = #runtime.scan_units
    if tracked_count == 0 then
        runtime.scan_index = 1
        return false
    end

    if runtime.scan_index > tracked_count then
        runtime.scan_index = 1
    end

    local unit_number = runtime.scan_units[runtime.scan_index]
    runtime.scan_index = (runtime.scan_index % tracked_count) + 1
    local entry = runtime.entries_by_unit[unit_number]
    if not entry then
        return true
    end

    if not (entry.entity and entry.entity.valid) then
        prune_runtime_entry(runtime, unit_number)
        return true
    end

    local previous_segment_id = entry.last_segment_id
    model.touch_entity(unit_number)
    entry = runtime.entries_by_unit[unit_number]
    if not entry then
        return true
    end

    if entry.last_segment_id then
        local segment = runtime.segments[entry.last_segment_id]
        local full_update_ticks = math.max(1, tonumber(ei_ticksPerFullUpdate) or 60)
        if segment and (previous_segment_id ~= entry.last_segment_id
            or not segment.last_scan_enqueued_tick
            or (game.tick - segment.last_scan_enqueued_tick) >= full_update_ticks) then
            segment.last_scan_enqueued_tick = game.tick
            model.enqueue_dirty_segment(entry.last_segment_id)
        end
        return true
    end

    audit_unsegmented_entry(entry)
    return true
end

local function process_one_mode(runtime, mode)
    if mode == "urgent" then
        return process_one_urgent(runtime)
    end

    if mode == "dirty" then
        return process_one_dirty(runtime)
    end

    if mode == "scan" then
        return process_one_scan(runtime)
    end

    return false
end

local function pick_weighted_service_mode(runtime)
    local snapshot = get_fluid_queue_snapshot(runtime)
    if snapshot.urgent <= 0 and snapshot.dirty <= 0 and snapshot.scan <= 0 then
        runtime.service_mode_cursor = 1
        return nil
    end

    local cursor = math.max(1, runtime.service_mode_cursor or 1)
    local rotation_length = #FLUID_SERVICE_ROTATION
    for offset = 0, rotation_length - 1 do
        local index = ((cursor + offset - 1) % rotation_length) + 1
        local mode = FLUID_SERVICE_ROTATION[index]
        if snapshot[mode] and snapshot[mode] > 0 then
            runtime.service_mode_cursor = (index % rotation_length) + 1
            return mode
        end
    end

    runtime.service_mode_cursor = 1
    return nil
end

function model.service_fluid_runtime(budget)
    local runtime = model.ensure_fluid_runtime()
    if (runtime.tracked_count or 0) <= 0 then
        return 0
    end

    budget = math.max(1, math.floor(tonumber(budget) or 1))
    local performed = 0
    local snapshot = get_fluid_queue_snapshot(runtime)

    -- Single-slot budgets follow the weighted rotation directly so sustained urgent churn
    -- cannot pin the runtime forever when step 2 only has one unit of work to spend.
    if budget == 1 then
        local mode = pick_weighted_service_mode(runtime)
        if mode and process_one_mode(runtime, mode) then
            return 1
        end

        return 0
    end

    -- Reserve one immediate urgent slot so freshly touched entities still react quickly.
    if snapshot.urgent > 0 and process_one_urgent(runtime) then
        performed = performed + 1
    end

    -- Reserve a little room for repair and background validation so a constant stream of
    -- urgent wakeups cannot indefinitely starve segment audits or round-robin scans.
    if performed < budget and snapshot.dirty > 0 and budget >= 2 then
        if process_one_dirty(runtime) then
            performed = performed + 1
        end
    end

    if performed < budget and snapshot.scan > 0 and budget >= 3 then
        if process_one_scan(runtime) then
            performed = performed + 1
        end
    end

    while performed < budget do
        local mode = pick_weighted_service_mode(runtime)
        if not mode or not process_one_mode(runtime, mode) then
            break
        end

        performed = performed + 1
    end

    return performed
end

return model
