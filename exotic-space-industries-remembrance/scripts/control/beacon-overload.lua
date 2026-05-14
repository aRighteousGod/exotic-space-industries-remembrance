--==============================================================================
-- ESIR FILE MAP
-- owns: beacon overload effects, icons, and rebuild/runtime state
-- loaded_by: exotic-space-industries-remembrance\control.lua
-- cadence: build, destroy, configuration refresh, and queued refresh drain
-- forwarded_events: add_overload_effect, add_overload_icon, allows_effects, check_global, count_beacons, counts_for_overload, entity_check, get_debug_status, has_tick_work, on_built_entity, on_configuration_changed, on_destroyed_entity, refresh_all_overloads, refresh_tracked_overloads, remove_overload_icon, set_debug_auto_arm, set_debug_enabled, update_all_machines_in_range, update_overload, updater
-- storage_roots: storage.ei, storage.ei.beacon_overload
-- gui_ids: none
-- remote_interfaces: none
-- rebuild_on: configuration change, beacon-machine topology changes
--==============================================================================

local model = {}
local ei_runtime_scheduler = require("lib/runtime-scheduler")

local OVERLOAD_THRESHOLD = 4
local DEFAULT_MAX_BEACON_RANGE = ei_data.beacon_range or 6
local WORLD_BOOTSTRAP_CHUNK_DISCOVERY_PER_TICK = 1
local WORLD_BOOTSTRAP_CHUNKS_PER_TICK = 4
local TRACKED_REFRESH_BUDGET = 8
local RELEASE_BUDGET = 8
local AUDIT_TRACKED_BUDGET = 4
local AUDIT_ICON_BUDGET = 2
local IDLE_AUDIT_INTERVAL_TICKS = 60
local DEBUG_HEARTBEAT_TICKS = 300
local DEBUG_SLOW_PHASE_MS = 5
local DEBUG_PREFIX = "[ESIR beacon-overload]"
local DEBUG_AUTO_ARM_DEFAULT = false
local get_entity_unit_number = ei_lib.get_entity_unit_number

local ELIGIBLE_MACHINE_TYPES = {
    ["assembling-machine"] = true,
    ["furnace"] = true,
    ["lab"] = true,
    ["rocket-silo"] = true,
    ["mining-drill"] = true,
}

local DEFAULT_MACHINE_EXCLUSIONS = {
    ["ei-copper-beacon-source"] = true,
    ["ei-iron-beacon-source"] = true,
    ["nsb-internal-manager"] = true,
    ["nsb-internal-monitor"] = true,
    ["nsb-internal-mimic"] = true,
    ["mupgrade-beacon"] = true,
}

local DEFAULT_BEACON_EXCLUSIONS = {
    ["ei-alien-beacon"] = true,
    ["ei-warp-beacon"] = true,
}

local DEFAULT_BEACON_WEIGHTS = {
    ["ei-iron-beacon"] = 2,
    ["kr-singularity-beacon"] = 2,
}

local REBUILD_MACHINE_TYPES = {
    "assembling-machine",
    "furnace",
    "lab",
    "rocket-silo",
    "mining-drill",
}

local active_surface_scan = nil

local function new_queue_section()
    return ei_runtime_scheduler.ensure_queue(nil)
end

local function raw_queue_has_items(queue)
    if type(queue) ~= "table" or type(queue.items) ~= "table" then
        return false
    end

    local head = queue.head or 1
    local tail = queue.tail or #queue.items
    for index = head, tail do
        if queue.items[index] ~= nil then
            return true
        end
    end

    return false
end

local function read_overload_enabled_config()
    return ei_lib.config("beacon-overload") == true
end

local function set_overload_enabled_cache(state, enabled)
    state.enabled = enabled == true
    return state.enabled
end

local function sync_overload_enabled_cache(state)
    return set_overload_enabled_cache(state, read_overload_enabled_config())
end

local function ensure_state()
    storage.ei = storage.ei or {}
    storage.ei.overload_icons = storage.ei.overload_icons or {}
    storage.ei.beacon_overload = storage.ei.beacon_overload or {}

    local state = storage.ei.beacon_overload
    state.tracked_machines = state.tracked_machines or {}
    state.machine_counts = state.machine_counts or {}
    state.overloaded_units = state.overloaded_units or {}
    state.tracked_count = state.tracked_count or 0
    state.overloaded_count = state.overloaded_count or 0
    state.tracked_refresh_cursor = state.tracked_refresh_cursor or nil
    state.tracked_audit_cursor = state.tracked_audit_cursor or nil
    state.icon_audit_cursor = state.icon_audit_cursor or nil
    state.release_cursor = state.release_cursor or nil
    state.last_reason = state.last_reason or nil
    state.compat = state.compat or {}
    state.compat.machine_exclusions = state.compat.machine_exclusions or {}
    state.compat.beacon_exclusions = state.compat.beacon_exclusions or {}
    state.compat.beacon_weights = state.compat.beacon_weights or {}
    state.debug = state.debug or {}
    state.debug.enabled = state.debug.enabled == true
    if state.debug.auto_arm == nil then
        state.debug.auto_arm = DEBUG_AUTO_ARM_DEFAULT
    end
    state.debug.last_heartbeat_tick = state.debug.last_heartbeat_tick or 0
    state.debug.last_reason = state.debug.last_reason or nil
    state.debug.last_status = state.debug.last_status or {}
    state.debug.phase_timings = state.debug.phase_timings or {}

    if state.refresh and type(state.refresh) == "table" then
        local legacy = state.refresh
        state.mode = state.mode or legacy.mode
        state.surface_queue = state.surface_queue or ei_runtime_scheduler.ensure_queue({ head = legacy.surface_head or 1, items = legacy.surfaces or {} })
        state.chunk_queue = state.chunk_queue or ei_runtime_scheduler.ensure_queue({ head = legacy.chunk_head or 1, items = legacy.chunks or {} })
        state.machine_queue = state.machine_queue or ei_runtime_scheduler.ensure_queue({ head = legacy.machine_head or 1, items = legacy.machines or {} })
        state.queued_units = state.queued_units or legacy.queued_units or {}
        state.refresh = nil
    end

    state.mode = state.mode or nil
    state.surface_queue = ei_runtime_scheduler.ensure_queue(state.surface_queue or new_queue_section())
    state.chunk_queue = ei_runtime_scheduler.ensure_queue(state.chunk_queue or new_queue_section())
    state.machine_queue = ei_runtime_scheduler.ensure_queue(state.machine_queue or new_queue_section())
    state.queued_units = state.queued_units or {}
    state.queued_chunk_keys = state.queued_chunk_keys or {}
    state.processed_chunk_keys = state.processed_chunk_keys or {}

    local tracked_has_entries = next(state.tracked_machines) ~= nil
    if state.tracked_count == nil then
        state.tracked_count = 0
    elseif state.tracked_count > 0 and not tracked_has_entries then
        state.tracked_count = 0
    end

    local overloaded_has_entries = next(state.overloaded_units) ~= nil
    if state.overloaded_count == nil then
        state.overloaded_count = 0
    elseif state.overloaded_count > 0 and not overloaded_has_entries then
        state.overloaded_count = 0
    end

    if state.enabled == nil then
        sync_overload_enabled_cache(state)
    end

    return state
end

local function is_overload_enabled(state)
    state = state or ensure_state()
    return state.enabled == true
end

local function get_refresh_budget()
    local configured = tonumber(ei_maxEntityUpdates) or 10
    return math.max(1, math.floor(configured))
end

local function get_surface_discovery_budget()
    return WORLD_BOOTSTRAP_CHUNK_DISCOVERY_PER_TICK
end

local function get_chunk_scan_budget()
    return WORLD_BOOTSTRAP_CHUNKS_PER_TICK
end

local function get_tracked_refresh_budget()
    return math.max(1, math.min(TRACKED_REFRESH_BUDGET, get_refresh_budget()))
end

local function get_release_budget()
    return math.max(1, math.min(RELEASE_BUDGET, get_refresh_budget()))
end

local function get_tracked_audit_budget()
    return math.max(1, math.min(AUDIT_TRACKED_BUDGET, get_refresh_budget()))
end

local function get_icon_audit_budget()
    return math.max(1, AUDIT_ICON_BUDGET)
end

local function expand_area(area, range)
    return {
        left_top = { x = area.left_top.x - range, y = area.left_top.y - range },
        right_bottom = { x = area.right_bottom.x + range, y = area.right_bottom.y + range },
    }
end

local function point_in_area(position, area)
    return position.x >= area.left_top.x
        and position.x <= area.right_bottom.x
        and position.y >= area.left_top.y
        and position.y <= area.right_bottom.y
end

local function is_machine_name_excluded(state, name)
    return DEFAULT_MACHINE_EXCLUSIONS[name] or state.compat.machine_exclusions[name] or false
end

local function is_beacon_name_excluded(state, name)
    return DEFAULT_BEACON_EXCLUSIONS[name] or state.compat.beacon_exclusions[name] or false
end

local function get_beacon_weight(state, name)
    local compat_weight = state.compat.beacon_weights[name]
    if compat_weight then
        return compat_weight
    end

    return DEFAULT_BEACON_WEIGHTS[name] or 1
end

local function reset_queue_section(queue_section)
    return ei_runtime_scheduler.clear_queue(queue_section)
end

local function reset_refresh_queue(state)
    state.mode = nil
    reset_queue_section(state.surface_queue)
    reset_queue_section(state.chunk_queue)
    reset_queue_section(state.machine_queue)
    state.queued_units = {}
    state.queued_chunk_keys = {}
    state.processed_chunk_keys = {}
    state.tracked_refresh_cursor = nil
    state.release_cursor = nil
end

local function clear_active_surface_scan()
    active_surface_scan = nil
end

local function clear_refresh_mode(state)
    reset_refresh_queue(state)
    clear_active_surface_scan()
end

local function queue_length(queue_section)
    return ei_runtime_scheduler.queue_length(queue_section)
end

local function queue_push(queue_section, value)
    ei_runtime_scheduler.queue_push(queue_section, value)
end

local function queue_peek(queue_section)
    return ei_runtime_scheduler.queue_peek(queue_section)
end

local function queue_pop(queue_section)
    return ei_runtime_scheduler.queue_pop(queue_section)
end

local function make_chunk_key(surface_index, chunk_x, chunk_y)
    return tostring(surface_index) .. ":" .. tostring(chunk_x) .. ":" .. tostring(chunk_y)
end

local function chunk_area(chunk_x, chunk_y)
    local left = chunk_x * 32
    local top = chunk_y * 32
    return {
        left_top = { x = left, y = top },
        right_bottom = { x = left + 32, y = top + 32 },
    }
end

local function get_render_object(render_ref)
    if not render_ref then
        return nil
    end

    local render_ref_type = type(render_ref)
    if render_ref_type == "userdata" then
        if render_ref.valid then
            return render_ref
        end
        return nil
    end

    if render_ref_type ~= "number" then
        return nil
    end

    local ok, render_object = pcall(function()
        return rendering.get_object_by_id(render_ref)
    end)
    if not ok then
        return nil
    end
    if render_object and render_object.valid then
        return render_object
    end

    return nil
end

local function cleanup_icon_by_unit(unit_number)
    local icons = storage.ei and storage.ei.overload_icons
    if not icons then
        return
    end

    local render_id = icons[unit_number]
    if not render_id then
        return
    end

    local state = storage.ei and storage.ei.beacon_overload
    if state and state.icon_audit_cursor == unit_number then
        state.icon_audit_cursor = next(icons, unit_number)
    end

    local render_object = get_render_object(render_id)
    if render_object then
        render_object.destroy()
    end

    icons[unit_number] = nil
end

local function queue_machine_for_refresh(state, entity)
    if not model.entity_check(entity) then
        return
    end

    local unit_number = get_entity_unit_number(entity)
    if not unit_number or state.queued_units[unit_number] then
        return
    end

    state.queued_units[unit_number] = true
    queue_push(state.machine_queue, unit_number)
end

local function clear_overloaded_flag(state, unit_number)
    if state.overloaded_units[unit_number] == nil then
        return
    end

    if state.release_cursor == unit_number then
        state.release_cursor = next(state.overloaded_units, unit_number)
    end

    state.overloaded_units[unit_number] = nil
    state.overloaded_count = math.max(0, (state.overloaded_count or 0) - 1)
end

local function set_entity_active_safely(entity, active)
    if not model.entity_check(entity) then
        return false
    end

    local ok = pcall(function()
        entity.active = active
    end)

    return ok
end

local function track_machine(state, entity)
    if not model.entity_check(entity) then
        return false
    end

    local unit_number = get_entity_unit_number(entity)
    if not unit_number then
        return false
    end

    if state.tracked_machines[unit_number] == nil then
        state.tracked_count = math.max(0, (state.tracked_count or 0) + 1)
    end

    state.tracked_machines[unit_number] = entity
    return true
end

local function remove_machine_tracking_by_unit(state, unit_number, entity, reactivate)
    if not unit_number then
        return
    end

    local tracked_entity = model.entity_check(entity) and entity or state.tracked_machines[unit_number]
    if reactivate and state.overloaded_units[unit_number] and tracked_entity then
        set_entity_active_safely(tracked_entity, true)
    end

    if state.tracked_machines[unit_number] ~= nil then
        state.tracked_count = math.max(0, (state.tracked_count or 0) - 1)
    end

    if state.tracked_refresh_cursor == unit_number then
        state.tracked_refresh_cursor = next(state.tracked_machines, unit_number)
    end
    if state.tracked_audit_cursor == unit_number then
        state.tracked_audit_cursor = next(state.tracked_machines, unit_number)
    end

    state.tracked_machines[unit_number] = nil
    state.machine_counts[unit_number] = nil
    state.queued_units[unit_number] = nil
    clear_overloaded_flag(state, unit_number)
    cleanup_icon_by_unit(unit_number)
end

local function remove_machine_tracking(state, entity, reactivate)
    remove_machine_tracking_by_unit(state, get_entity_unit_number(entity), entity, reactivate)
end

local function value_to_string(value)
    if value == nil then
        return "nil"
    end
    return tostring(value)
end

local function get_cursor_entry(tbl, cursor)
    local key = cursor
    local value = key and tbl[key] or nil
    if value == nil then
        key, value = next(tbl, nil)
    end
    if key == nil then
        return nil, nil, nil
    end

    local next_key = next(tbl, key)
    return key, value, next_key
end

local function current_surface_index(state)
    if active_surface_scan and active_surface_scan.surface_index then
        return active_surface_scan.surface_index
    end

    if queue_length(state.surface_queue) > 0 then
        return queue_peek(state.surface_queue)
    end

    return nil
end

local function build_debug_status(state, phase, reason, elapsed_text)
    local snapshot = {
        phase = phase,
        reason = reason or state.last_reason,
        mode = state.mode,
        enabled = state.enabled == true,
        auto_arm = state.debug.auto_arm == true,
        tracked_count = state.tracked_count or 0,
        overloaded_count = state.overloaded_count or 0,
        surface_queue_length = queue_length(state.surface_queue),
        chunk_queue_length = queue_length(state.chunk_queue),
        machine_queue_length = queue_length(state.machine_queue),
        current_surface_index = current_surface_index(state),
        tracked_refresh_cursor = state.tracked_refresh_cursor,
        tracked_audit_cursor = state.tracked_audit_cursor,
        icon_audit_cursor = state.icon_audit_cursor,
        release_cursor = state.release_cursor,
        heartbeat_tick = state.debug.last_heartbeat_tick or 0,
        elapsed = elapsed_text,
        phase_timings = state.debug.phase_timings or {},
    }

    state.debug.last_status = snapshot
    state.debug.last_reason = snapshot.reason
    return snapshot
end

local function format_debug_status(snapshot)
    local fields = {
        "phase=" .. value_to_string(snapshot.phase),
        "reason=" .. value_to_string(snapshot.reason),
        "mode=" .. value_to_string(snapshot.mode),
        "enabled=" .. value_to_string(snapshot.enabled),
        "auto_arm=" .. value_to_string(snapshot.auto_arm),
        "tracked=" .. value_to_string(snapshot.tracked_count),
        "overloaded=" .. value_to_string(snapshot.overloaded_count),
        "queues(s=" .. value_to_string(snapshot.surface_queue_length) .. ",c=" .. value_to_string(snapshot.chunk_queue_length) .. ",m=" .. value_to_string(snapshot.machine_queue_length) .. ")",
        "surface=" .. value_to_string(snapshot.current_surface_index),
        "cursors(tr=" .. value_to_string(snapshot.tracked_refresh_cursor) .. ",ta=" .. value_to_string(snapshot.tracked_audit_cursor) .. ",ia=" .. value_to_string(snapshot.icon_audit_cursor) .. ",re=" .. value_to_string(snapshot.release_cursor) .. ")",
        "heartbeat=" .. value_to_string(snapshot.heartbeat_tick),
    }

    if snapshot.elapsed ~= nil then
        fields[#fields + 1] = "elapsed=" .. value_to_string(snapshot.elapsed)
    end

    return table.concat(fields, " ")
end

local function log_debug_status(state, phase, reason, elapsed_text)
    if not (state.debug and state.debug.enabled) then
        return nil
    end

    local snapshot = build_debug_status(state, phase, reason, elapsed_text)
    log(DEBUG_PREFIX .. " " .. format_debug_status(snapshot))
    return snapshot
end

local function maybe_auto_arm_debug(state, reason, allow_auto_arm)
    state.last_reason = reason or state.last_reason
    state.debug.last_reason = state.last_reason

    if allow_auto_arm and state.debug.auto_arm and not state.debug.enabled then
        state.debug.enabled = true
        state.debug.last_heartbeat_tick = 0
        log(DEBUG_PREFIX .. " auto-armed reason=" .. value_to_string(state.last_reason))
    end
end

local function set_work_mode(state, mode, reason)
    state.mode = mode
    state.last_reason = reason or state.last_reason
    state.debug.last_reason = state.last_reason
end

local function profiler_elapsed_text(profiler)
    if not profiler then
        return nil
    end

    local raw = tostring(profiler)
    if not raw then
        return nil
    end

    return raw
end

local function profiler_elapsed_ms(elapsed_text)
    if type(elapsed_text) ~= "string" then
        return nil
    end

    local value, unit = elapsed_text:match("([%d%.]+)%s*(ms)")
    if not value then
        value, unit = elapsed_text:match("([%d%.]+)%s*(us)")
    end
    if not value then
        value, unit = elapsed_text:match("([%d%.]+)%s*(ns)")
    end
    if not value then
        value, unit = elapsed_text:match("([%d%.]+)%s*(s)")
    end

    local numeric = tonumber(value)
    if not numeric then
        return nil
    end

    if unit == "s" then
        return numeric * 1000
    end
    if unit == "us" then
        return numeric / 1000
    end
    if unit == "ns" then
        return numeric / 1000000
    end
    if unit == "ms" then
        return numeric
    end

    return nil
end

local function with_profiled_phase(state, phase, reason, fn)
    local profiler = nil
    if state.debug and state.debug.enabled and game and game.create_profiler then
        profiler = game.create_profiler()
    end
    local ok, result1, result2, result3 = pcall(fn)

    if profiler and profiler.stop then
        pcall(function()
            profiler:stop()
        end)
    end

    local elapsed_text = profiler_elapsed_text(profiler)
    if state.debug and state.debug.enabled then
        state.debug.phase_timings[phase] = {
            duration = elapsed_text,
            ms = profiler_elapsed_ms(elapsed_text),
            work = result1,
            extra = { reason = reason },
            tick = game and game.tick or 0,
        }
        local snapshot = log_debug_status(state, phase, reason, elapsed_text)
        local elapsed_ms = profiler_elapsed_ms(elapsed_text)
        if snapshot and elapsed_ms and elapsed_ms >= DEBUG_SLOW_PHASE_MS then
            log(DEBUG_PREFIX .. " slow-phase phase=" .. value_to_string(phase) .. " " .. format_debug_status(snapshot))
        end
    end

    if not ok then
        error(result1, 0)
    end

    return result1, result2, result3
end

local function heartbeat_if_needed(state, event)
    if not (state.debug and state.debug.enabled) then
        return
    end

    local active = state.mode ~= nil
        or queue_length(state.surface_queue) > 0
        or queue_length(state.chunk_queue) > 0
        or queue_length(state.machine_queue) > 0
        or state.tracked_refresh_cursor ~= nil
        or state.release_cursor ~= nil
        or active_surface_scan ~= nil

    if not active then
        return
    end

    local tick = (event and event.tick) or game.tick
    if (tick - (state.debug.last_heartbeat_tick or 0)) < DEBUG_HEARTBEAT_TICKS then
        return
    end

    state.debug.last_heartbeat_tick = tick
    log_debug_status(state, "heartbeat", state.last_reason, nil)
end

local function queue_release_mode(state, reason)
    reset_refresh_queue(state)
    clear_active_surface_scan()
    state.release_cursor = nil
    set_work_mode(state, "release", reason)
    log_debug_status(state, "release-enqueue", reason, nil)
end

local function queue_world_mode(state, reason)
    reset_refresh_queue(state)
    clear_active_surface_scan()
    state.tracked_refresh_cursor = nil
    set_work_mode(state, "world", reason)
    log_debug_status(state, "world-enqueue", reason, nil)
end

local function queue_tracked_mode(state, reason)
    reset_refresh_queue(state)
    clear_active_surface_scan()
    state.tracked_refresh_cursor = nil
    set_work_mode(state, "tracked", reason)
    log_debug_status(state, "tracked-enqueue", reason, nil)
end

local function cleanup_invalid_icon_entries(state, budget)
    local icons = storage.ei and storage.ei.overload_icons
    if not icons then
        return 0
    end

    budget = math.max(0, budget or 0)
    local cursor = state.icon_audit_cursor
    local processed = 0

    while budget > 0 do
        local unit_number, render_id, next_key = get_cursor_entry(icons, cursor)
        if unit_number == nil then
            cursor = nil
            break
        end

        if not get_render_object(render_id) or state.overloaded_units[unit_number] ~= true then
            cleanup_icon_by_unit(unit_number)
        end

        cursor = next_key
        processed = processed + 1
        budget = budget - 1
    end

    state.icon_audit_cursor = cursor
    return processed
end

local function cleanup_invalid_tracked_machines(state, budget)
    budget = math.max(0, budget or 0)
    local cursor = state.tracked_audit_cursor
    local processed = 0

    while budget > 0 do
        local unit_number, entity, next_key = get_cursor_entry(state.tracked_machines, cursor)
        if unit_number == nil then
            cursor = nil
            break
        end

        if not model.entity_check(entity) then
            remove_machine_tracking_by_unit(state, unit_number, entity, false)
        elseif not model.counts_for_overload(entity, state) then
            remove_machine_tracking_by_unit(state, unit_number, entity, true)
        end

        cursor = next_key
        processed = processed + 1
        budget = budget - 1
    end

    state.tracked_audit_cursor = cursor
    return processed
end

local function process_tracked_refresh_queue(state)
    local budget = get_tracked_refresh_budget()
    local processed = 0
    while budget > 0 do
        local unit_number, entity, next_key = get_cursor_entry(state.tracked_machines, state.tracked_refresh_cursor)
        if unit_number == nil then
            state.tracked_refresh_cursor = nil
            break
        end

        if not model.entity_check(entity) then
            remove_machine_tracking_by_unit(state, unit_number, entity, false)
        elseif not model.counts_for_overload(entity, state) then
            remove_machine_tracking_by_unit(state, unit_number, entity, true)
        else
            queue_machine_for_refresh(state, entity)
        end

        state.tracked_refresh_cursor = next_key
        processed = processed + 1
        budget = budget - 1
    end

    return processed
end

local function process_release_queue(state)
    local budget = get_release_budget()
    local processed = 0
    while budget > 0 do
        local unit_number, _, next_key = get_cursor_entry(state.overloaded_units, state.release_cursor)
        if unit_number == nil then
            state.release_cursor = nil
            break
        end

        local entity = state.tracked_machines[unit_number]
        if model.entity_check(entity) then
            if not set_entity_active_safely(entity, true) then
                remove_machine_tracking_by_unit(state, unit_number, entity, false)
                entity = nil
            end
        end
        if entity then
            cleanup_icon_by_unit(unit_number)
            clear_overloaded_flag(state, unit_number)
        end

        state.release_cursor = next_key
        processed = processed + 1
        budget = budget - 1
    end

    return processed
end

local function queue_idle_audits(state)
    local tracked_processed = cleanup_invalid_tracked_machines(state, get_tracked_audit_budget())
    local icon_processed = cleanup_invalid_icon_entries(state, get_icon_audit_budget())
    return tracked_processed + icon_processed
end

local function get_beacon_range(entity)
    if not model.entity_check(entity) then
        return 0
    end

    local proto = entity.prototype
    if not proto then
        return 0
    end

    if proto.get_supply_area_distance then
        return proto.get_supply_area_distance(entity.quality) or 0
    end

    return proto.supply_area_distance or 0
end

local function beacon_counts_for_overload(state, entity)
    if not model.entity_check(entity) or entity.type ~= "beacon" then
        return nil, 0
    end

    if is_beacon_name_excluded(state, entity.name) then
        return nil, 0
    end

    local range = get_beacon_range(entity)
    if range <= 0 then
        return nil, 0
    end

    return get_beacon_weight(state, entity.name), range
end

local function chunk_generated(surface, chunk_x, chunk_y)
    if not (surface and surface.valid) then
        return false
    end

    if not surface.is_chunk_generated then
        return true
    end

    local ok, generated = pcall(function()
        return surface.is_chunk_generated({ x = chunk_x, y = chunk_y })
    end)
    if not ok then
        return true
    end

    return generated
end

local function begin_surface_scan(state)
    local surface_index = queue_peek(state.surface_queue)
    if surface_index == nil then
        return false
    end

    local surface = game.surfaces[surface_index]
    if not (surface and surface.valid) then
        queue_pop(state.surface_queue)
        clear_active_surface_scan()
        return true
    end

    local iterator_valid = true
    if active_surface_scan and active_surface_scan.iterator and type(active_surface_scan.iterator) == "userdata" then
        iterator_valid = active_surface_scan.iterator.valid
    end

    if not active_surface_scan
        or active_surface_scan.surface_index ~= surface_index
        or not active_surface_scan.iterator
        or not iterator_valid then
        active_surface_scan = {
            surface_index = surface_index,
            iterator = surface.get_chunks(),
        }
    end

    return true
end

local function discover_surface_chunks(state, budget)
    local processed = 0
    local surface_index = queue_peek(state.surface_queue)
    if surface_index == nil then
        return processed
    end

    local surface = game.surfaces[surface_index]
    if not (surface and surface.valid) then
        queue_pop(state.surface_queue)
        clear_active_surface_scan()
        return processed + 1
    end

    if not begin_surface_scan(state) then
        return processed
    end

    while budget > 0 do
        local chunk = active_surface_scan.iterator()
        if not chunk then
            queue_pop(state.surface_queue)
            clear_active_surface_scan()
            return processed
        end

        budget = budget - 1
        processed = processed + 1
        local key = make_chunk_key(surface_index, chunk.x, chunk.y)
        if not state.processed_chunk_keys[key] and not state.queued_chunk_keys[key] then
            if chunk_generated(surface, chunk.x, chunk.y) then
                state.queued_chunk_keys[key] = true
                queue_push(state.chunk_queue, {
                    surface_index = surface_index,
                    chunk_x = chunk.x,
                    chunk_y = chunk.y,
                })
            else
                state.processed_chunk_keys[key] = true
            end
        end
    end

    return processed
end

local function update_machine_state(state, entity, should_overload)
    if not model.entity_check(entity) then
        return
    end

    local unit_number = get_entity_unit_number(entity)
    if not unit_number then
        return
    end

    local was_overloaded = state.overloaded_units[unit_number] and true or false
    if should_overload then
        if not set_entity_active_safely(entity, false) then
            remove_machine_tracking_by_unit(state, unit_number, entity, false)
            return
        end
        if not was_overloaded then
            model.add_overload_effect(entity)
            if ei_victory and ei_victory.count_value then
                ei_victory.count_value("machines_overloaded", 1)
            end
            state.overloaded_count = math.max(0, (state.overloaded_count or 0) + 1)
        end
        model.add_overload_icon(entity)
        state.overloaded_units[unit_number] = true
        return
    end

    local icons = storage.ei and storage.ei.overload_icons or nil
    local has_icon = icons and icons[unit_number] ~= nil or false
    if was_overloaded then
        if not set_entity_active_safely(entity, true) then
            remove_machine_tracking_by_unit(state, unit_number, entity, false)
            return
        end
        clear_overloaded_flag(state, unit_number)
    end

    if was_overloaded or has_icon then
        model.remove_overload_icon(entity)
    end
end

local function recount_machine(state, entity)
    if not model.entity_check(entity) then
        return 0
    end

    local surface = entity.surface
    local bbox = entity.bounding_box
    if not (surface and bbox) then
        return 0
    end

    local search_area = expand_area(bbox, DEFAULT_MAX_BEACON_RANGE)
    local candidates = surface.find_entities_filtered { area = search_area, type = "beacon" }

    local total = 0
    for _, beacon in ipairs(candidates) do
        local weight, range = beacon_counts_for_overload(state, beacon)
        if weight and point_in_area(beacon.position, expand_area(bbox, range)) then
            total = total + weight
        end
    end

    return total
end

local function process_machine_refresh(state, entity)
    if not model.entity_check(entity) then
        return
    end

    if not model.counts_for_overload(entity, state) then
        remove_machine_tracking(state, entity, true)
        return
    end

    if not track_machine(state, entity) then
        return
    end

    local unit_number = get_entity_unit_number(entity)
    local count = recount_machine(state, entity)
    state.machine_counts[unit_number] = count
    update_machine_state(state, entity, count > OVERLOAD_THRESHOLD)
end

local function apply_beacon_delta_to_machine(state, entity, delta, destroy_type)
    if not model.entity_check(entity) then
        return
    end

    if not model.counts_for_overload(entity, state) then
        remove_machine_tracking(state, entity, true)
        return
    end

    if not track_machine(state, entity) then
        return
    end

    local unit_number = get_entity_unit_number(entity)
    local current_count = state.machine_counts[unit_number]
    if current_count == nil then
        current_count = recount_machine(state, entity)
        if delta < 0 and destroy_type == "pre" then
            current_count = current_count + delta
        end
    else
        current_count = current_count + delta
    end

    current_count = math.max(0, current_count)
    state.machine_counts[unit_number] = current_count
    update_machine_state(state, entity, current_count > OVERLOAD_THRESHOLD)
end

local function process_chunk_scan(state, chunk_entry)
    local surface = game.surfaces[chunk_entry.surface_index]
    local key = make_chunk_key(chunk_entry.surface_index, chunk_entry.chunk_x, chunk_entry.chunk_y)
    state.queued_chunk_keys[key] = nil
    state.processed_chunk_keys[key] = true

    if not (surface and surface.valid) then
        return
    end

    if not chunk_generated(surface, chunk_entry.chunk_x, chunk_entry.chunk_y) then
        return
    end

    local machines = surface.find_entities_filtered {
        area = chunk_area(chunk_entry.chunk_x, chunk_entry.chunk_y),
        type = REBUILD_MACHINE_TYPES,
    }

    for _, machine in ipairs(machines) do
        if model.counts_for_overload(machine, state) then
            track_machine(state, machine)
            queue_machine_for_refresh(state, machine)
        end
    end
end

local function process_chunk_queue(state)
    local budget = get_chunk_scan_budget()
    local processed = 0
    while budget > 0 do
        local chunk_entry = queue_pop(state.chunk_queue)
        if not chunk_entry then
            break
        end

        process_chunk_scan(state, chunk_entry)
        processed = processed + 1
        budget = budget - 1
    end

    return processed
end

local function process_machine_queue(state)
    local budget = get_refresh_budget()
    local processed = 0
    while budget > 0 do
        local entry = queue_pop(state.machine_queue)
        if not entry then
            break
        end

        local unit_number = nil
        local entity = nil

        if type(entry) == "number" then
            unit_number = entry
            entity = state.tracked_machines[unit_number]
        else
            entity = entry
            if model.entity_check(entity) then
                unit_number = get_entity_unit_number(entity)
            else
                unit_number = get_entity_unit_number(entity)
            end
        end

        if unit_number then
            state.queued_units[unit_number] = nil
        end

        if model.entity_check(entity) then
            process_machine_refresh(state, entity)
        elseif unit_number then
            remove_machine_tracking_by_unit(state, unit_number, entity, false)
        end

        processed = processed + 1
        budget = budget - 1
    end

    return processed
end

local function release_owned_overloads(state, reason)
    queue_release_mode(state, reason or "disable")
end

local function enqueue_tracked_refresh(state, reason)
    queue_tracked_mode(state, reason or "tracked-refresh")
end

local function enqueue_world_rebuild(state, reason)
    queue_world_mode(state, reason or "world-rebuild")
    for _, surface in pairs(game.surfaces) do
        if surface and surface.valid then
            queue_push(state.surface_queue, surface.index)
        end
    end
end

function model.entity_check(entity)
    return ei_lib.entity_check(entity)
end

function model.check_global()
    ensure_state()
end

function model.set_debug_enabled(enabled, reason)
    local state = ensure_state()
    state.debug.enabled = enabled == true
    state.last_reason = reason or state.last_reason
    state.debug.last_reason = state.last_reason
    if state.debug.enabled then
        state.debug.last_heartbeat_tick = 0
        log_debug_status(state, "debug-enabled", state.last_reason, nil)
    else
        log(DEBUG_PREFIX .. " debug-disabled reason=" .. value_to_string(state.last_reason))
    end
    return state.debug.enabled
end

function model.set_debug_auto_arm(enabled)
    local state = ensure_state()
    state.debug.auto_arm = enabled ~= false
    return state.debug.auto_arm
end

function model.get_debug_status()
    local state = ensure_state()
    return build_debug_status(state, state.mode or "idle", state.last_reason, nil)
end

function model.allows_effects(entity)
    if not model.entity_check(entity) then
        return false
    end

    local effects = entity.prototype and entity.prototype.allowed_effects
    if not effects then
        return false
    end

    for _, enabled in pairs(effects) do
        if enabled == true then
            return true
        end
    end

    return false
end

function model.counts_for_overload(entity, state)
    if not model.entity_check(entity) then
        return false
    end

    if not ELIGIBLE_MACHINE_TYPES[entity.type] then
        return false
    end

    state = state or ensure_state()
    if is_machine_name_excluded(state, entity.name) then
        return false
    end

    return model.allows_effects(entity)
end

function model.count_beacons(entity)
    local state = ensure_state()
    return recount_machine(state, entity)
end

function model.refresh_all_overloads(reason)
    local state = ensure_state()
    reason = reason or "manual-refresh"
    maybe_auto_arm_debug(state, reason, true)
    log_debug_status(state, "refresh-all-entry", state.last_reason, nil)

    if not is_overload_enabled(state) then
        if next(state.overloaded_units) ~= nil then
            release_owned_overloads(state, reason .. "-disabled")
        else
            clear_refresh_mode(state)
        end
        return
    end

    enqueue_world_rebuild(state, reason)
end

function model.refresh_tracked_overloads(reason)
    local state = ensure_state()
    reason = reason or "tracked-refresh"
    maybe_auto_arm_debug(state, reason, false)
    log_debug_status(state, "tracked-refresh-entry", state.last_reason, nil)

    if not is_overload_enabled(state) then
        if next(state.overloaded_units) ~= nil then
            release_owned_overloads(state, reason .. "-disabled")
        else
            clear_refresh_mode(state)
        end
        return
    end

    enqueue_tracked_refresh(state, reason)
end

function model.update_overload(entity, state)
    if not model.entity_check(entity) then
        return
    end

    state = state or ensure_state()
    if not is_overload_enabled(state) then
        local unit_number = get_entity_unit_number(entity)
        if unit_number and state.overloaded_units[unit_number] then
            update_machine_state(state, entity, false)
        end
        return
    end

    process_machine_refresh(state, entity)
end

function model.update_all_machines_in_range(entity, destroy_type, beacon_value, state)
    if not model.entity_check(entity) then
        return
    end

    state = state or ensure_state()
    local _, range = beacon_counts_for_overload(state, entity)
    if range <= 0 then
        return
    end

    local bbox = entity.bounding_box
    if not bbox then
        return
    end

    local machines = entity.surface.find_entities_filtered {
        area = expand_area(bbox, range),
        type = { "assembling-machine", "furnace", "lab", "rocket-silo", "mining-drill" },
    }

    local delta = beacon_value or get_beacon_weight(state, entity.name)
    for _, machine in ipairs(machines) do
        apply_beacon_delta_to_machine(state, machine, delta, destroy_type)
    end
end

function model.add_overload_icon(entity)
    local unit_number = get_entity_unit_number(entity)
    if not model.entity_check(entity) or not unit_number then
        return
    end

    ensure_state()
    local icons = storage.ei.overload_icons
    local existing = icons[unit_number]
    if get_render_object(existing) then
        return
    end

    if existing and not get_render_object(existing) then
        icons[unit_number] = nil
    end

    icons[unit_number] = rendering.draw_sprite {
        sprite = "ei-overload-icon",
        target = entity,
        x_scale = 0.75,
        y_scale = 0.75,
        surface = entity.surface,
        render_layer = 139,
    }
end

function model.remove_overload_icon(entity)
    local unit_number = get_entity_unit_number(entity)
    if not unit_number then
        return
    end

    ensure_state()
    cleanup_icon_by_unit(unit_number)
end

function model.add_overload_effect(entity)
    local unit_number = get_entity_unit_number(entity)
    if not model.entity_check(entity) or not unit_number then
        return
    end

    ensure_state()
    local current_icon = storage.ei.overload_icons[unit_number]
    if get_render_object(current_icon) then
        return
    end

    local size = entity.prototype.collision_box.right_bottom.x - entity.prototype.collision_box.left_top.x
    local pos = entity.position

    rendering.draw_animation {
        animation = "ei-overload-animation",
        target = { pos.x - size / 2, pos.y - size / 2 },
        surface = entity.surface,
        render_layer = 139,
        time_to_live = 30,
    }
    rendering.draw_animation {
        animation = "ei-overload-animation",
        target = { pos.x + size / 2, pos.y - size / 2 },
        surface = entity.surface,
        render_layer = 139,
        time_to_live = 30,
    }
    rendering.draw_animation {
        animation = "ei-overload-animation",
        target = { pos.x - size / 2, pos.y + size / 2 },
        surface = entity.surface,
        render_layer = 139,
        time_to_live = 30,
    }
    rendering.draw_animation {
        animation = "ei-overload-animation",
        target = { pos.x + size / 2, pos.y + size / 2 },
        surface = entity.surface,
        render_layer = 139,
        time_to_live = 30,
    }

    rendering.draw_text {
        target = { pos.x - 1, pos.y - size / 2 },
        text = "Beacon overload",
        color = { r = 1, g = 0.77, b = 0 },
        surface = entity.surface,
        scale = 1,
        time_to_live = 15,
    }
end

function model.on_configuration_changed(e)
    local state = ensure_state()
    local reason = "configuration-changed"
    maybe_auto_arm_debug(state, reason, true)
    log_debug_status(state, "config-change-entry", reason, nil)

    with_profiled_phase(state, "config-change", reason, function()
        local previous_enabled = state.enabled == true
        local enabled = sync_overload_enabled_cache(state)
        local mod_changes_present = e and next(e.mod_changes or {}) ~= nil or false
        local startup_settings_changed = e and e.mod_startup_settings_changed or false

        if not enabled then
            if next(state.overloaded_units) ~= nil then
                release_owned_overloads(state, reason .. "-disabled")
            else
                clear_refresh_mode(state)
            end
            return
        end

        if previous_enabled == false or mod_changes_present or startup_settings_changed then
            enqueue_world_rebuild(state, reason)
        end
    end)

    log_debug_status(state, "config-change-exit", reason, nil)
end

function model.has_tick_work(event)
    local state = storage and storage.ei and storage.ei.beacon_overload or nil
    if type(state) ~= "table" then
        return false
    end

    if state.mode ~= nil
        or active_surface_scan ~= nil
        or state.tracked_refresh_cursor ~= nil
        or state.release_cursor ~= nil
        or state.tracked_audit_cursor ~= nil
        or state.icon_audit_cursor ~= nil
    then
        return true
    end

    if raw_queue_has_items(state.surface_queue)
        or raw_queue_has_items(state.chunk_queue)
        or raw_queue_has_items(state.machine_queue)
    then
        return true
    end

    if (tonumber(state.overloaded_count) or 0) > 0
        or (type(state.overloaded_units) == "table" and next(state.overloaded_units) ~= nil)
    then
        return true
    end

    if state.debug and state.debug.enabled == true then
        return true
    end

    local tracked_count = tonumber(state.tracked_count) or 0
    if tracked_count <= 0 and type(state.tracked_machines) == "table" then
        tracked_count = next(state.tracked_machines) ~= nil and 1 or 0
    end

    local tick = event and event.tick or game and game.tick or 0
    return tracked_count > 0 and tick % IDLE_AUDIT_INTERVAL_TICKS == 0
end

function model.updater(event)
    local state = ensure_state()
    local tick = (event and event.tick) or game.tick
    local enabled = is_overload_enabled(state)

    if not enabled then
        if state.mode ~= "release" and next(state.overloaded_units) ~= nil then
            release_owned_overloads(state, "runtime-disabled")
        end
        if state.mode ~= "release" then
            clear_refresh_mode(state)
        end
    end

    if state.mode == "release" then
        with_profiled_phase(state, "release", state.last_reason, function()
            return process_release_queue(state)
        end)
    elseif enabled and state.mode == "tracked" then
        with_profiled_phase(state, "tracked-seeding", state.last_reason, function()
            return process_tracked_refresh_queue(state)
        end)
        with_profiled_phase(state, "machine-recount", state.last_reason, function()
            return process_machine_queue(state)
        end)
    elseif enabled and state.mode == "world" then
        if queue_length(state.surface_queue) > 0 then
            with_profiled_phase(state, "chunk-discovery", state.last_reason, function()
                return discover_surface_chunks(state, get_surface_discovery_budget())
            end)
        end

        with_profiled_phase(state, "chunk-scan", state.last_reason, function()
            return process_chunk_queue(state)
        end)
        with_profiled_phase(state, "machine-recount", state.last_reason, function()
            return process_machine_queue(state)
        end)
    end

    if state.mode == nil and tick % IDLE_AUDIT_INTERVAL_TICKS == 0 then
        with_profiled_phase(state, "idle-audit", state.last_reason, function()
            return queue_idle_audits(state)
        end)
    end
    heartbeat_if_needed(state, event)

    if state.mode == "release" then
        if next(state.overloaded_units) == nil and queue_length(state.machine_queue) == 0 then
            clear_refresh_mode(state)
        end
    elseif queue_length(state.surface_queue) == 0
        and queue_length(state.chunk_queue) == 0
        and queue_length(state.machine_queue) == 0
        and state.tracked_refresh_cursor == nil then
        clear_refresh_mode(state)
    end
end

function model.on_built_entity(entity)
    if not model.entity_check(entity) then
        return
    end

    local entity_type = entity.type
    local maybe_machine = ELIGIBLE_MACHINE_TYPES[entity_type] == true
    local is_beacon = entity_type == "beacon"
    if not maybe_machine and not is_beacon then
        return
    end

    local state = ensure_state()
    local enabled = is_overload_enabled(state)
    if maybe_machine and model.counts_for_overload(entity, state) then
        if enabled then
            process_machine_refresh(state, entity)
        else
            track_machine(state, entity)
        end
    end

    if not is_beacon or not enabled then
        return
    end

    local weight = beacon_counts_for_overload(state, entity)
    if weight then
        model.update_all_machines_in_range(entity, nil, weight, state)
    end
end

function model.on_destroyed_entity(entity, destroy_type)
    if not entity then
        return
    end

    local entity_type = entity.type
    local maybe_machine = ELIGIBLE_MACHINE_TYPES[entity_type] == true
    local is_beacon = entity_type == "beacon"
    if not maybe_machine and not is_beacon then
        return
    end

    local state = ensure_state()
    local unit_number = get_entity_unit_number(entity)
    if maybe_machine and unit_number and state.tracked_machines[unit_number] then
        remove_machine_tracking(state, entity, false)
    elseif maybe_machine and unit_number and state.overloaded_units[unit_number] then
        clear_overloaded_flag(state, unit_number)
        cleanup_icon_by_unit(unit_number)
    end

    if not is_beacon or not is_overload_enabled(state) then
        return
    end

    local weight = entity.valid and beacon_counts_for_overload(state, entity) or nil
    if weight then
        model.update_all_machines_in_range(entity, destroy_type, -weight, state)
    end
end

return model
