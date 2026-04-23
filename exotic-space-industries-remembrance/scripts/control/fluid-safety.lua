--==============================================================================
-- ESIR FILE MAP
-- owns: queued invalid-fluid auditing and fluid safety enforcement
-- loaded_by: exotic-space-industries-remembrance\control.lua
-- cadence: scheduled tick step 2 plus build/destroy checks
-- forwarded_events: classify_entity, counts_for_fluid_handling, ensure_fluid_runtime, enqueue_dirty_segment, enqueue_urgent_entity, get_fluid_work_count, get_runtime_status, on_configuration_changed, on_fluid_entity_deregistered, on_fluid_entity_registered, rebuild_fluid_runtime, service_fluid_runtime, touch_entity
-- storage_roots: storage.ei
-- gui_ids: none
-- remote_interfaces: none
-- rebuild_on: entity registration changes
--==============================================================================

local model = {}
local ei_data = require("lib/data")
local ei_lib = require("lib/lib")
local ei_runtime_scheduler = require("lib/runtime-scheduler")
local get_entity_unit_number = ei_lib.get_entity_unit_number
local count_present_keys = ei_runtime_scheduler.table_count
local MODULE_NAME = "fluid-safety"

local FLUID_CLASS_NORMAL = "normal"
local FLUID_CLASS_DATA = "data"
local FLUID_CLASS_INSULATED = "insulated"

local FLUID_CARRIER_LINE = "line"
local FLUID_CARRIER_ELEVATED_LINE = "elevated-line"
local FLUID_CARRIER_SIGNAL_LINE = "signal-line"
local FLUID_CARRIER_VESSEL = "vessel"

local FLUID_STATUS_EMPTY = "empty"
local FLUID_STATUS_STABLE = "stable"
local FLUID_STATUS_SAFE = "safe"
local FLUID_STATUS_DATA = "data"
local FLUID_STATUS_CRYO_NITROGEN = "cryo_nitrogen"
local FLUID_STATUS_CRYO_OXYGEN = "cryo_oxygen"
local FLUID_STATUS_NEEDS_INSULATED = "needs_insulated"

local FLUID_EFFECT_FAMILY_DATA = "data"
local FLUID_EFFECT_FAMILY_CRYO = "cryo"
local FLUID_EFFECT_FAMILY_THERMAL = "thermal"
local FLUID_EFFECT_FAMILY_CHEMICAL = "chemical"

local AFTERMATH_QUEUE_EFFECT = "effect"
local AFTERMATH_QUEUE_VENT = "vent"
local AFTERMATH_SEVERITY_HEAVY = "heavy"
local AFTERMATH_SEVERITY_LIGHT = "light"

local SEGMENT_MEMBER_ACTION_BUDGET = 32
local FLUID_QUEUE_STORAGE_VERSION = 2
local FLUID_SERVICE_ROTATION = {"urgent", "urgent", "dirty", "urgent", "scan"}
local FLUID_RUNTIME_REBUILD_TYPES = {"pipe", "storage-tank", "pipe-to-ground"}
local FLUID_RUNTIME_REBUILD_NAMES = {"elevated-pipe"}
local HEAVY_LINE_AFTERMATH_COOLDOWN_TICKS = 90
local HEAVY_VESSEL_AFTERMATH_COOLDOWN_TICKS = 150
local LIGHT_CRYO_VENT_COOLDOWN_TICKS = 30
local LIGHT_CRYO_FEEDBACK_COOLDOWN_TICKS = 15
local BREACH_FALLBACK_FLOATING_TTL = 150
local BREACH_NOTIFICATION_COOLDOWN_TICKS = 300

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

local thermal_effect_lookup = {
    ["lava"] = true,
}

local fluidbox_capacity_by_name = {}

-- Flip this on when chasing a fluid-runtime hang again.
local FLUID_DIAGNOSTICS_ENABLED = false

local function fluid_log(message)
    if not FLUID_DIAGNOSTICS_ENABLED then
        return
    end

    log("[ESIR fluid] " .. message)
end

local function new_aftermath_stats()
    return {
        heavy_aftermath_queued = 0,
        light_vent_queued = 0,
        heavy_cooldown_suppressed = 0,
        light_cooldown_suppressed = 0,
    }
end

local function ensure_aftermath_stats(runtime)
    runtime.aftermath_stats = runtime.aftermath_stats or new_aftermath_stats()
    local stats = runtime.aftermath_stats
    stats.heavy_aftermath_queued = math.max(0, tonumber(stats.heavy_aftermath_queued) or 0)
    stats.light_vent_queued = math.max(0, tonumber(stats.light_vent_queued) or 0)
    stats.heavy_cooldown_suppressed = math.max(0, tonumber(stats.heavy_cooldown_suppressed) or 0)
    stats.light_cooldown_suppressed = math.max(0, tonumber(stats.light_cooldown_suppressed) or 0)
    return stats
end

local function bump_aftermath_stat(runtime, key, delta)
    local stats = ensure_aftermath_stats(runtime)
    delta = delta or 1
    stats[key] = math.max(0, (tonumber(stats[key]) or 0) + delta)
    ei_runtime_scheduler.bump_counter(MODULE_NAME, key, delta)
    return stats[key]
end

-- Load the shared rupture helper eagerly so fluid-safety cannot silently fall back
-- to plain dying explosions if a one-time lazy require ever misses.
local fluid_rupture_effects = require("scripts/control/fluid-rupture-effects")
local current_entity_segment_id
local get_next_service_mode_name
local maybe_echo_phase_shift_feedback
local maybe_notify_breach

local function get_fluid_rupture_effects()
    return fluid_rupture_effects
end

local function new_fluid_runtime()
    local urgent_queue = ei_runtime_scheduler.ensure_queue(nil)
    local dirty_queue = ei_runtime_scheduler.ensure_queue(nil)
    return {
        initialized = false,
        entries_by_unit = {},
        tracked_count = 0,
        scan_units = {},
        scan_index = 1,
        urgent_units = urgent_queue,
        urgent_head = 1,
        urgent_tail = 1,
        urgent_pending = urgent_queue.queued,
        urgent_count = 0,
        segments = {},
        dirty_segments = dirty_queue,
        dirty_head = 1,
        dirty_tail = 1,
        dirty_pending = dirty_queue.queued,
        dirty_count = 0,
        queue_storage_version = FLUID_QUEUE_STORAGE_VERSION,
        service_mode_cursor = 1,
        aftermath_stats = new_aftermath_stats(),
    }
end

local function sync_legacy_fluid_storage(runtime)
    storage.ei.fluid_entity = storage.ei.fluid_entity or {}
    storage.ei.fluid_entity_count = runtime.tracked_count or 0
end

local function get_segment_member_count(segment)
    if not segment then
        return 0
    end

    local member_count = tonumber(segment.member_count)
    if member_count ~= nil then
        return math.max(0, member_count)
    end

    member_count = count_present_keys(segment.members)
    segment.member_count = member_count
    return member_count
end

local function add_segment_member(segment, unit_number)
    if not (segment and unit_number) then
        return false
    end

    if segment.members[unit_number] ~= nil then
        return false
    end

    segment.members[unit_number] = true
    segment.member_count = get_segment_member_count(segment) + 1
    return true
end

local function remove_segment_member(segment, unit_number)
    if not (segment and unit_number) then
        return false
    end

    if segment.members[unit_number] == nil then
        return false
    end

    segment.members[unit_number] = nil
    segment.member_count = math.max(0, get_segment_member_count(segment) - 1)
    return true
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

local function sync_runtime_queue_compat_fields(state, queue, head_key, tail_key, pending_key)
    queue = ei_runtime_scheduler.ensure_queue(queue)
    state[head_key] = queue.head or 1
    state[tail_key] = (queue.tail or 0) + 1
    state[pending_key] = queue.queued
    return queue
end

local function rebuild_unique_runtime_queue(queue)
    queue = ei_runtime_scheduler.ensure_queue(queue)

    local items = {}
    local queued = {}
    local new_tail = 0

    for index = queue.head, queue.tail do
        local value = queue.items[index]
        if value ~= nil and queued[value] ~= true then
            new_tail = new_tail + 1
            items[new_tail] = value
            queued[value] = true
        end
    end

    queue.items = items
    queue.head = 1
    queue.tail = new_tail
    queue.queued = queued
    return queue, new_tail
end

local function migrate_runtime_queue(state, queue_key, head_key, tail_key, pending_key, count_key)
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

    local migrated_count
    queue, migrated_count = rebuild_unique_runtime_queue(queue)
    state[queue_key] = queue
    state[count_key] = migrated_count
    sync_runtime_queue_compat_fields(state, queue, head_key, tail_key, pending_key)
    return queue
end

local function get_runtime_queue_count(state, queue_key, count_key)
    local count = tonumber(state[count_key])
    if count ~= nil then
        return math.max(0, count)
    end

    local queue = ei_runtime_scheduler.ensure_queue(state[queue_key])
    state[queue_key] = queue
    count = ei_runtime_scheduler.queue_item_count(queue)
    state[count_key] = count
    return count
end

local function enqueue_runtime_queue_value(state, queue_key, head_key, tail_key, pending_key, count_key, value)
    if value == nil then
        return false
    end

    local queue = ei_runtime_scheduler.ensure_queue(state[queue_key])
    local added
    added, queue = ei_runtime_scheduler.queue_push_unique(queue, value)
    state[queue_key] = queue
    if added then
        state[count_key] = math.max(0, tonumber(state[count_key]) or 0) + 1
    end
    sync_runtime_queue_compat_fields(state, queue, head_key, tail_key, pending_key)
    return added == true
end

local function dequeue_runtime_queue_value(state, queue_key, head_key, tail_key, pending_key, count_key)
    local queue = ei_runtime_scheduler.ensure_queue(state[queue_key])
    local value = ei_runtime_scheduler.queue_pop_queued(queue)
    state[queue_key] = queue
    if value ~= nil then
        state[count_key] = math.max(0, (tonumber(state[count_key]) or 0) - 1)
    end
    sync_runtime_queue_compat_fields(state, queue, head_key, tail_key, pending_key)
    return value
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

local function resolve_effect_family(fluid_name, status)
    if status == FLUID_STATUS_DATA or (fluid_name and computing_fluid_lookup[fluid_name]) then
        return FLUID_EFFECT_FAMILY_DATA
    end

    if status == FLUID_STATUS_CRYO_NITROGEN or status == FLUID_STATUS_CRYO_OXYGEN or (fluid_name and cryo_conversion_lookup[fluid_name]) then
        return FLUID_EFFECT_FAMILY_CRYO
    end

    if fluid_name and (thermal_effect_lookup[fluid_name] or fluid_name:find("ei%-heated%-", 1) == 1) then
        return FLUID_EFFECT_FAMILY_THERMAL
    end

    return FLUID_EFFECT_FAMILY_CHEMICAL
end

local function resolve_carrier_class(subject)
    local entity = subject
    local entry_class = nil
    if type(subject) == "table" and subject.entity then
        entity = subject.entity
        entry_class = subject.class
    end

    if not entity then
        if entry_class == FLUID_CLASS_DATA then
            return FLUID_CARRIER_SIGNAL_LINE
        end

        return FLUID_CARRIER_LINE
    end

    if entity.type == "storage-tank" then
        return FLUID_CARRIER_VESSEL
    end

    if entity.name == "elevated-pipe" then
        return FLUID_CARRIER_ELEVATED_LINE
    end

    if entry_class == FLUID_CLASS_DATA or (entity.name or ""):find("ei%-data", 1) == 1 then
        return FLUID_CARRIER_SIGNAL_LINE
    end

    return FLUID_CARRIER_LINE
end

local function should_destroy_for_status(status, entry_class)
    if status == FLUID_STATUS_DATA then
        return entry_class == FLUID_CLASS_NORMAL
    end

    if status == FLUID_STATUS_SAFE then
        return entry_class == FLUID_CLASS_DATA
    end

    if status == FLUID_STATUS_NEEDS_INSULATED then
        return entry_class ~= FLUID_CLASS_INSULATED
    end

    if status == FLUID_STATUS_CRYO_NITROGEN or status == FLUID_STATUS_CRYO_OXYGEN then
        return entry_class == FLUID_CLASS_DATA
    end

    return false
end

local function get_first_fluid_name_and_amount(fluid_contents)
    if not fluid_contents then
        return nil, 0
    end

    local best_fluid_name = nil
    local best_amount = 0
    local best_priority = -1

    for fluid_name, amount in pairs(fluid_contents) do
        amount = tonumber(amount) or 0
        if amount > 0 then
            local status = classify_fluid_status(fluid_name)
            local priority = 0
            if status == FLUID_STATUS_NEEDS_INSULATED then
                priority = 4
            elseif status == FLUID_STATUS_DATA then
                priority = 3
            elseif status == FLUID_STATUS_CRYO_NITROGEN or status == FLUID_STATUS_CRYO_OXYGEN then
                priority = 2
            elseif status == FLUID_STATUS_SAFE then
                priority = 1
            end

            -- Choose a stable dominant fluid so mixed segments do not depend on `pairs()`.
            if not best_fluid_name
                or amount > best_amount
                or (amount == best_amount and priority > best_priority)
                or (amount == best_amount and priority == best_priority and fluid_name < best_fluid_name)
            then
                best_fluid_name = fluid_name
                best_amount = amount
                best_priority = priority
            end
        end
    end

    return best_fluid_name, best_amount
end

local function get_named_fluid_amount(fluid_contents, fluid_name)
    if not (fluid_contents and fluid_name) then
        return 0
    end

    return math.max(0, tonumber(fluid_contents[fluid_name]) or 0)
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

local function read_entity_segment_contents(entity)
    if not (entity and entity.valid) then
        return nil
    end

    if not entity_has_fluidbox(entity) then
        if entity.get_fluid_count and entity.get_fluid_count() <= 0 then
            return nil
        end

        if entity.get_fluid_contents then
            return entity.get_fluid_contents()
        end

        return nil
    end

    local ok, contents = pcall(function()
        return entity.fluidbox.get_fluid_segment_contents(1)
    end)

    if ok and contents then
        return contents
    end

    if entity.get_fluid_contents then
        return entity.get_fluid_contents()
    end

    return nil
end

local function get_runtime_entry(runtime, unit_or_entity)
    if not unit_or_entity then
        return nil
    end

    if type(unit_or_entity) == "number" then
        return runtime.entries_by_unit[unit_or_entity]
    end

    local unit_number = get_entity_unit_number(unit_or_entity)
    if unit_number then
        return runtime.entries_by_unit[unit_number]
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
            member_count = 0,
            cursor_unit = nil,
            status = FLUID_STATUS_EMPTY,
            representative_unit = nil,
            last_notified_tick = nil,
            last_notified_signature = nil,
            last_scan_enqueued_tick = nil,
            last_heavy_aftermath_tick = nil,
            last_light_vent_tick = nil,
            last_phase_shift_feedback_tick = nil,
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
    if segment and get_segment_member_count(segment) <= 0 then
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

    remove_segment_member(segment, entry.unit_number)
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
    add_segment_member(segment, entry.unit_number)
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

    local member_count = get_segment_member_count(segment)
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

        remove_segment_member(segment, unit_number)
        if segment.representative_unit == unit_number then
            segment.representative_unit = next(segment.members)
        end
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

local function read_entity_segment_fluid(entity)
    if not (entity and entity.valid) then
        return nil, 0
    end

    local contents = read_entity_segment_contents(entity)
    if contents then
        return get_first_fluid_name_and_amount(contents)
    end

    return read_entity_fluid(entity)
end

local function get_entity_target_fluid_amount(entity, fluid_name)
    if not (entity and entity.valid and fluid_name and entity.get_fluid_contents) then
        return 0
    end

    local contents = entity.get_fluid_contents()
    local amount = get_named_fluid_amount(contents, fluid_name)
    if amount > 0 then
        return amount
    end

    local converted_name = cryo_conversion_lookup[fluid_name]
    if converted_name then
        return get_named_fluid_amount(contents, converted_name)
    end

    return 0
end

local function get_segment_member_profile(runtime, segment_id)
    local profile = {
        total_count = 0,
        normal_count = 0,
        data_count = 0,
        insulated_count = 0,
        non_insulated_count = 0,
    }

    local segment = runtime.segments[segment_id]
    if not segment then
        return profile
    end

    local member_count = get_segment_member_count(segment)
    local loop_limit = member_count + 1
    local iterations = 0
    local unit_number = next_member_after(segment.members, nil)

    while unit_number do
        iterations = iterations + 1
        if iterations > loop_limit then
            log_segment_loop_guard("get_segment_member_profile", segment_id, member_count, segment.status, nil)
            return profile
        end

        local next_unit = next_member_after(segment.members, unit_number)
        local entry = runtime.entries_by_unit[unit_number]

        if not entry or not entry.entity or not entry.entity.valid then
            prune_runtime_entry(runtime, unit_number)
        else
            local live_segment_id = current_entity_segment_id(entry)
            if live_segment_id ~= segment_id then
                set_entry_segment(runtime, entry, live_segment_id, true)
            else
                entry.last_segment_id = segment_id
                profile.total_count = profile.total_count + 1

                if entry.class == FLUID_CLASS_NORMAL then
                    profile.normal_count = profile.normal_count + 1
                    profile.non_insulated_count = profile.non_insulated_count + 1
                elseif entry.class == FLUID_CLASS_DATA then
                    profile.data_count = profile.data_count + 1
                    profile.non_insulated_count = profile.non_insulated_count + 1
                elseif entry.class == FLUID_CLASS_INSULATED then
                    profile.insulated_count = profile.insulated_count + 1
                end
            end
        end

        unit_number = next_unit
    end

    return profile
end

local function get_segment_status_impact(status, profile)
    profile = profile or {}

    if status == FLUID_STATUS_DATA then
        return math.max(0, tonumber(profile.normal_count) or 0), 3
    end

    if status == FLUID_STATUS_SAFE then
        return math.max(0, tonumber(profile.data_count) or 0), 1
    end

    if status == FLUID_STATUS_NEEDS_INSULATED then
        return math.max(0, tonumber(profile.non_insulated_count) or 0), 4
    end

    if status == FLUID_STATUS_CRYO_NITROGEN or status == FLUID_STATUS_CRYO_OXYGEN then
        return math.max(0, tonumber(profile.normal_count) or 0) + math.max(0, tonumber(profile.data_count) or 0), 2
    end

    return 0, 0
end

local function select_effective_segment_fluid(fluid_contents, member_profile)
    member_profile = member_profile or {}
    if not fluid_contents then
        return nil, 0, FLUID_STATUS_EMPTY
    end

    local best_fluid_name = nil
    local best_amount = 0
    local best_status = FLUID_STATUS_EMPTY
    local best_priority = -1
    local best_affected_count = -1
    local has_positive_fluid = false

    for fluid_name, amount in pairs(fluid_contents) do
        amount = tonumber(amount) or 0
        if amount > 0 then
            has_positive_fluid = true
            local status = classify_fluid_status(fluid_name)
            local affected_count, priority = get_segment_status_impact(status, member_profile)
            if affected_count > 0 then
                if not best_fluid_name
                    or priority > best_priority
                    or (priority == best_priority and affected_count > best_affected_count)
                    or (priority == best_priority and affected_count == best_affected_count and amount > best_amount)
                    or (priority == best_priority and affected_count == best_affected_count and amount == best_amount and fluid_name < best_fluid_name)
                then
                    best_fluid_name = fluid_name
                    best_amount = amount
                    best_status = status
                    best_priority = priority
                    best_affected_count = affected_count
                end
            end
        end
    end

    if best_fluid_name then
        return best_fluid_name, best_amount, best_status
    end

    if has_positive_fluid then
        return nil, 0, FLUID_STATUS_STABLE
    end

    return nil, 0, FLUID_STATUS_EMPTY
end

local function read_segment_fluid(runtime, segment_id)
    local representative_entry = get_segment_representative(runtime, segment_id)
    if not representative_entry then
        return nil, 0, FLUID_STATUS_EMPTY
    end

    local entity = representative_entry.entity
    local fluid_contents = read_entity_segment_contents(entity)
    local member_profile = get_segment_member_profile(runtime, segment_id)
    return select_effective_segment_fluid(fluid_contents, member_profile)
end

local function get_entity_fluidbox_capacity(entity)
    if not entity_has_fluidbox(entity) then
        return 0
    end

    local entity_name = entity.name
    if entity_name then
        local cached_capacity = fluidbox_capacity_by_name[entity_name]
        if cached_capacity ~= nil then
            return cached_capacity
        end
    end

    local ok, capacity = pcall(function()
        return entity.fluidbox.get_capacity(1)
    end)

    if ok and capacity then
        capacity = math.max(0, tonumber(capacity) or 0)
        if entity_name then
            fluidbox_capacity_by_name[entity_name] = capacity
        end
        return capacity
    end

    if entity_name then
        fluidbox_capacity_by_name[entity_name] = 0
    end
    return 0
end

local function get_destroy_drain_cap(carrier, fluidbox_volume)
    fluidbox_volume = math.max(0, tonumber(fluidbox_volume) or 0)
    if carrier == FLUID_CARRIER_VESSEL then
        return math.floor(fluidbox_volume * 1.5)
    end

    return fluidbox_volume
end

local function get_effect_severity(carrier, stored_amount)
    if carrier == FLUID_CARRIER_VESSEL and (tonumber(stored_amount) or 0) >= 200 then
        return "medium"
    end

    return "small"
end

local function get_carrier_priority(subject)
    local carrier = resolve_carrier_class(subject)
    if carrier == FLUID_CARRIER_VESSEL then
        return 4
    end

    if carrier == FLUID_CARRIER_SIGNAL_LINE then
        return 3
    end

    if carrier == FLUID_CARRIER_ELEVATED_LINE then
        return 2
    end

    return 1
end

local function prefer_capacity_candidate(candidate_entry, candidate_capacity, best_entry, best_capacity)
    if not candidate_entry then
        return false
    end

    if not best_entry then
        return true
    end

    if candidate_capacity ~= best_capacity then
        return candidate_capacity > best_capacity
    end

    return (candidate_entry.unit_number or math.huge) < (best_entry.unit_number or math.huge)
end

local function prefer_destroy_candidate(candidate_entry, candidate_priority, candidate_capacity, best_entry, best_priority, best_capacity)
    if not candidate_entry then
        return false
    end

    if not best_entry then
        return true
    end

    if candidate_priority ~= best_priority then
        return candidate_priority > best_priority
    end

    if candidate_capacity ~= best_capacity then
        return candidate_capacity > best_capacity
    end

    return (candidate_entry.unit_number or math.huge) < (best_entry.unit_number or math.huge)
end

local function find_segment_replacement_entry(runtime, segment_id, excluded_unit_number, preferred_unit_number)
    local segment = runtime.segments[segment_id]
    if not segment then
        return nil
    end

    if preferred_unit_number and preferred_unit_number ~= excluded_unit_number then
        local preferred_entry = runtime.entries_by_unit[preferred_unit_number]
        if preferred_entry
            and preferred_entry.entity
            and preferred_entry.entity.valid
            and get_fluidbox_segment_id(preferred_entry.entity) == segment_id
        then
            preferred_entry.last_segment_id = segment_id
            return preferred_entry
        end
    end

    local member_count = get_segment_member_count(segment)
    local loop_limit = member_count + 1
    local iterations = 0
    local unit_number = next_member_after(segment.members, nil)
    local best_entry = nil
    local best_capacity = -1
    while unit_number do
        iterations = iterations + 1
        if iterations > loop_limit then
            log_segment_loop_guard("find_segment_replacement_entry", segment_id, member_count, segment.status, nil)
            return nil
        end

        if unit_number ~= excluded_unit_number then
            local entry = runtime.entries_by_unit[unit_number]
            if entry and entry.entity and entry.entity.valid and get_fluidbox_segment_id(entry.entity) == segment_id then
                entry.last_segment_id = segment_id
                local capacity = get_entity_fluidbox_capacity(entry.entity)
                if prefer_capacity_candidate(entry, capacity, best_entry, best_capacity) then
                    best_entry = entry
                    best_capacity = capacity
                end
            end
        end

        unit_number = next_member_after(segment.members, unit_number)
    end

    return best_entry
end

local function build_segment_breach_plan(runtime, segment_id, status)
    local segment = runtime.segments[segment_id]
    if not segment then
        return nil
    end

    local member_count = get_segment_member_count(segment)
    local loop_limit = member_count + 1
    local iterations = 0
    local unit_number = next_member_after(segment.members, nil)
    local best_normal_capacity = -1
    local best_replacement_capacity = -1
    local best_destroy_priority = -1
    local best_destroy_capacity = -1
    local plan = {
        normal_entry = nil,
        replacement_entry = nil,
        primary_entry = nil,
    }

    while unit_number do
        iterations = iterations + 1
        if iterations > loop_limit then
            log_segment_loop_guard("build_segment_breach_plan", segment_id, member_count, status, nil)
            return plan
        end

        local next_unit = next_member_after(segment.members, unit_number)
        local entry = runtime.entries_by_unit[unit_number]

        if not entry or not entry.entity or not entry.entity.valid then
            prune_runtime_entry(runtime, unit_number)
        else
            local live_segment_id = current_entity_segment_id(entry)
            if live_segment_id ~= segment_id then
                set_entry_segment(runtime, entry, live_segment_id, true)
            else
                entry.last_segment_id = segment_id

                if entry.class == FLUID_CLASS_NORMAL then
                    local normal_capacity = get_entity_fluidbox_capacity(entry.entity)
                    if prefer_capacity_candidate(entry, normal_capacity, plan.normal_entry, best_normal_capacity) then
                        plan.normal_entry = entry
                        best_normal_capacity = normal_capacity
                    end
                end

                if should_destroy_for_status(status, entry.class) then
                    local destroy_priority = get_carrier_priority(entry)
                    local destroy_capacity = get_entity_fluidbox_capacity(entry.entity)
                    if prefer_destroy_candidate(entry, destroy_priority, destroy_capacity, plan.primary_entry, best_destroy_priority, best_destroy_capacity) then
                        plan.primary_entry = entry
                        best_destroy_priority = destroy_priority
                        best_destroy_capacity = destroy_capacity
                    end
                else
                    local replacement_capacity = get_entity_fluidbox_capacity(entry.entity)
                    if prefer_capacity_candidate(entry, replacement_capacity, plan.replacement_entry, best_replacement_capacity) then
                        plan.replacement_entry = entry
                        best_replacement_capacity = replacement_capacity
                    end
                end
            end
        end

        unit_number = next_unit
    end

    return plan
end

local function drain_entity_fluid(entity)
    if not (entity and entity.valid) then
        return nil, 0
    end

    local fluid_name, amount = read_entity_fluid(entity)
    clear_entity_fluids(entity)
    return fluid_name, amount
end

local function drain_segment_fluid(runtime, segment_id, fluid_name)
    local representative_entry = get_segment_representative(runtime, segment_id)
    if not representative_entry then
        return fluid_name, 0, nil
    end

    local entity = representative_entry.entity
    if not (entity and entity.valid) then
        return fluid_name, 0, representative_entry
    end

    if not entity_has_fluidbox(entity) then
        local removed_name, removed_amount = drain_entity_fluid(entity)
        return removed_name or fluid_name, removed_amount, representative_entry
    end

    local live_contents = read_entity_segment_contents(entity)
    local live_name, live_amount = get_first_fluid_name_and_amount(live_contents)
    local target_name = fluid_name
    local target_amount = get_named_fluid_amount(live_contents, target_name)
    local converted_name = cryo_conversion_lookup[fluid_name]
    if converted_name then
        local converted_amount = get_named_fluid_amount(live_contents, converted_name)
        if converted_amount > 0 then
            target_name = converted_name
            target_amount = converted_amount
        end
    end

    if target_name and target_amount > 0 then
        local ok, removed = pcall(function()
            return entity.fluidbox.flush(1, target_name)
        end)

        if ok and removed then
            if target_name then
                local removed_amount = removed[target_name] or 0
                if removed_amount > 0 then
                    return target_name, removed_amount, representative_entry
                end
            end

            local removed_name, removed_amount = get_first_fluid_name_and_amount(removed)
            if removed_name and removed_amount > 0 then
                return removed_name, removed_amount, representative_entry
            end
        end

        clear_entity_fluids(entity)
        return target_name, target_amount, representative_entry
    end

    return target_name or live_name or fluid_name, 0, representative_entry
end

local function insert_replacement_fluid(entry, fluid_name, amount)
    local entity = entry and entry.entity
    if not (entity and entity.valid and fluid_name and amount and amount > 0) then
        return false
    end

    entity.insert_fluid({ name = fluid_name, amount = amount })
    return true
end

local function resolve_breach_context(segment_id, segment, entry, status, fluid_name, options)
    options = options or {}

    local should_destroy = options.should_destroy == true
    local entity = entry and entry.entity or nil
    local carrier = options.carrier or resolve_carrier_class(entry)
    local severity = options.severity or (should_destroy and AFTERMATH_SEVERITY_HEAVY or AFTERMATH_SEVERITY_LIGHT)
    local segment_amount = math.max(0, tonumber(options.amount) or 0)
    local effect_amount = math.max(0, tonumber(options.effect_amount) or segment_amount)
    local fluidbox_volume = math.max(1, tonumber(options.fluidbox_volume) or get_entity_fluidbox_capacity(entity) or 1)
    local drain_cap = options.drain_cap
    if drain_cap == nil and should_destroy then
        drain_cap = get_destroy_drain_cap(carrier, fluidbox_volume)
    end

    local aftermath_cap = options.aftermath_cap
    if aftermath_cap == nil and should_destroy then
        aftermath_cap = drain_cap
    end

    local queue_kind = options.queue_kind
    if not queue_kind then
        if severity == AFTERMATH_SEVERITY_LIGHT then
            queue_kind = AFTERMATH_QUEUE_VENT
        else
            queue_kind = AFTERMATH_QUEUE_EFFECT
        end
    end

    local drain_mode = options.drain_mode
    if not drain_mode then
        if segment_id and (should_destroy or options.replacement_fluid) and carrier ~= FLUID_CARRIER_VESSEL then
            drain_mode = "segment"
        elseif should_destroy or options.replacement_fluid then
            drain_mode = "entity"
        end
    end

    local family = options.family or resolve_effect_family(fluid_name, status)
    if status == FLUID_STATUS_SAFE and carrier == FLUID_CARRIER_SIGNAL_LINE then
        family = FLUID_EFFECT_FAMILY_DATA
    end

    local context = {
        segment_id = segment_id,
        segment = segment,
        entry = entry,
        entity = entity,
        status = status,
        fluid_name = fluid_name,
        incompatible_name = options.incompatible_name or fluid_name,
        family = family,
        carrier = carrier,
        variant = options.variant or fluid_name or carrier,
        severity = severity,
        effect_severity = options.effect_severity or get_effect_severity(carrier, effect_amount),
        queue_kind = queue_kind,
        breach_kind = options.breach_kind or (should_destroy and "destroy" or "phase-shift"),
        should_destroy = should_destroy,
        drain_mode = drain_mode,
        drain_cap = drain_cap,
        aftermath_cap = aftermath_cap,
        segment_amount = segment_amount,
        effect_amount = effect_amount,
        aftermath_amount = segment_amount,
        fluidbox_volume = fluidbox_volume,
        replacement_entry = options.replacement_entry,
        replacement_fluid = options.replacement_fluid,
        segment_preserve_excess = options.segment_preserve_excess,
        skip_aftermath = options.skip_aftermath == true,
        drained_amount = 0,
        pollution_amount = 0,
        source_force_name = options.source_force_name or (entity and entity.force and entity.force.name) or "neutral",
        damage_scale = math.max(0.2, tonumber(options.damage_scale) or 1),
    }

    if context.segment_preserve_excess == nil then
        context.segment_preserve_excess = context.drain_mode == "segment" and should_destroy and context.replacement_fluid == nil
    end

    if severity == AFTERMATH_SEVERITY_HEAVY then
        context.cooldown_field = "last_heavy_aftermath_tick"
        if carrier == FLUID_CARRIER_VESSEL then
            context.cooldown_ticks = HEAVY_VESSEL_AFTERMATH_COOLDOWN_TICKS
        else
            context.cooldown_ticks = HEAVY_LINE_AFTERMATH_COOLDOWN_TICKS
        end
    elseif severity == AFTERMATH_SEVERITY_LIGHT then
        context.cooldown_field = "last_light_vent_tick"
        context.cooldown_ticks = LIGHT_CRYO_VENT_COOLDOWN_TICKS
    end

    if context.family == FLUID_EFFECT_FAMILY_THERMAL then
        context.allow_fire = true
        context.allow_scorch = true
        context.allow_secondary = false
        context.allow_pipeline_fire = true
        context.allow_platform_tile_damage = true
        context.pollution_amount = math.max(0, context.aftermath_amount * (context.variant == "lava" and 0.05 or 0.03))
        context.damage_scale = context.variant == "lava" and 1.05 or 0.95
    elseif context.family == FLUID_EFFECT_FAMILY_CHEMICAL then
        context.allow_fire = false
        context.allow_scorch = false
        context.allow_secondary = false
        context.allow_pipeline_fire = false
        context.allow_platform_tile_damage = false
        context.pollution_amount = 0
        context.damage_scale = context.effect_severity == "medium" and 0.70 or 0.58
    elseif context.family == FLUID_EFFECT_FAMILY_CRYO then
        context.allow_fire = false
        context.allow_scorch = false
        context.allow_secondary = false
        context.allow_pipeline_fire = false
        context.allow_platform_tile_damage = false
        context.pollution_amount = 0
        context.damage_scale = 0.50
    else
        context.allow_fire = false
        context.allow_scorch = false
        context.allow_secondary = false
        context.allow_pipeline_fire = false
        context.allow_platform_tile_damage = false
        context.pollution_amount = 0
        context.damage_scale = 0.62
    end

    if carrier == FLUID_CARRIER_ELEVATED_LINE then
        context.allow_pipeline_fire = false
        context.allow_platform_tile_damage = false
    end

    if carrier == FLUID_CARRIER_SIGNAL_LINE then
        context.allow_fire = false
        context.allow_scorch = false
        context.allow_pipeline_fire = false
        context.allow_platform_tile_damage = false
        context.pollution_amount = 0
    end

    return context
end

local function build_aftermath_spec(context)
    return {
        effect_family = context.family,
        effect_variant = context.variant or context.fluid_name or context.family,
        carrier_class = context.carrier,
        severity = context.effect_severity,
        stored_amount = math.max(0, tonumber(context.aftermath_amount) or tonumber(context.drained_amount) or 0),
        fluidbox_volume = math.max(1, tonumber(context.fluidbox_volume) or 1),
        pollution_amount = math.max(0, tonumber(context.pollution_amount) or 0),
        allow_fire = context.allow_fire,
        allow_scorch = context.allow_scorch,
        allow_secondary = context.allow_secondary,
        allow_pipeline_fire = context.allow_pipeline_fire,
        allow_platform_tile_damage = context.allow_platform_tile_damage,
        source_force_name = context.source_force_name,
        damage_scale = context.damage_scale,
        drained_amount = context.drained_amount or 0,
    }
end

local function maybe_queue_contextual_aftermath(runtime, segment, context, tick)
    local entity = context and context.entity
    if not (context and entity and entity.valid) then
        return "failed"
    end

    if segment and context.cooldown_field and context.cooldown_ticks then
        local last_tick = segment[context.cooldown_field]
        if last_tick and (tick - last_tick) < context.cooldown_ticks then
            if context.queue_kind == AFTERMATH_QUEUE_VENT then
                bump_aftermath_stat(runtime, "light_cooldown_suppressed")
            else
                bump_aftermath_stat(runtime, "heavy_cooldown_suppressed")
            end
            return "cooldown_suppressed"
        end
    end

    local effects = get_fluid_rupture_effects()
    local spec = build_aftermath_spec(context)
    if context.queue_kind == AFTERMATH_QUEUE_VENT then
        local queued = effects and effects.queue_vent and effects.queue_vent(entity, spec, tick) or false
        if queued then
            if segment and context.cooldown_field and context.cooldown_ticks then
                segment[context.cooldown_field] = tick
            end
            bump_aftermath_stat(runtime, "light_vent_queued")
            return "queued"
        end
        return "failed"
    end

    local queued = effects and effects.queue_effect and effects.queue_effect(entity, spec, tick) or false
    if queued then
        if segment and context.cooldown_field and context.cooldown_ticks then
            segment[context.cooldown_field] = tick
        end
        bump_aftermath_stat(runtime, "heavy_aftermath_queued")
        return "queued"
    end
    return "failed"
end

local function apply_breach_context(runtime, segment_id, segment, context, tick)
    if not context then
        return false
    end

    local replacement_entry = context.replacement_entry or context.entry
    local replacement_amount = nil
    if context.drain_mode == "segment" then
        local drained_name, drained_amount, representative_entry = drain_segment_fluid(runtime, segment_id, context.fluid_name)
        if drained_name then
            context.fluid_name = drained_name
            context.incompatible_name = context.incompatible_name or drained_name
        end
        replacement_entry = replacement_entry or representative_entry
        context.replacement_entry = replacement_entry
        replacement_amount = drained_amount or 0
        context.drained_amount = replacement_amount
        if context.segment_preserve_excess and context.drain_cap then
            local preserved_amount = math.max(0, replacement_amount - context.drain_cap)
            context.drained_amount = math.min(replacement_amount, context.drain_cap)
            if preserved_amount > 0 and replacement_entry then
                insert_replacement_fluid(replacement_entry, context.fluid_name, preserved_amount)
            end
        end
    elseif context.drain_mode == "entity" then
        local drained_name, drained_amount = drain_entity_fluid(context.entity)
        if drained_name then
            context.fluid_name = drained_name
            context.incompatible_name = context.incompatible_name or drained_name
        end
        context.replacement_entry = replacement_entry
        replacement_amount = drained_amount or 0
        context.drained_amount = replacement_amount
    end

    local aftermath_result = "skipped"
    local aftermath_queued = false
    if not context.skip_aftermath then
        context.aftermath_amount = math.max(0, math.min(context.drained_amount or 0, context.aftermath_cap or context.drained_amount or 0))
        if context.aftermath_amount <= 0 and (context.segment_amount or 0) > 0 then
            context.aftermath_amount = math.max(0, math.min(context.segment_amount, context.aftermath_cap or context.segment_amount))
        end
        if context.family == FLUID_EFFECT_FAMILY_THERMAL then
            context.pollution_amount = math.max(0, context.aftermath_amount * (context.variant == "lava" and 0.05 or 0.03))
        end
        aftermath_result = maybe_queue_contextual_aftermath(runtime, segment, context, tick)
        aftermath_queued = aftermath_result == "queued"
    end

    if context.replacement_fluid and replacement_entry then
        insert_replacement_fluid(replacement_entry, context.replacement_fluid, replacement_amount or 0)
    end

    if context.should_destroy then
        local entity = context.entity
        if not (entity and entity.valid) then
            return false
        end

        maybe_notify_breach(segment, context, tick)
        local destroyed_ok, destroyed = pcall(function()
            return entity.destroy({raise_destroy = true})
        end)
        if not (destroyed_ok and destroyed) and entity.valid then
            entity.die(entity.force)
        end
    elseif aftermath_queued then
        maybe_notify_breach(segment, context, tick)
    elseif context.breach_kind == "phase-shift"
        and aftermath_result == "cooldown_suppressed"
        and (tonumber(context.drained_amount) or 0) > 0
    then
        maybe_echo_phase_shift_feedback(segment, context, tick)
    end

    return true
end

local function get_notification_floating_key(context)
    if not context then
        return "pipe-breach-generic"
    end

    if context.breach_kind == "phase-shift" then
        return "pipe-breach-phase-shift"
    end

    if context.family == FLUID_EFFECT_FAMILY_DATA then
        return "pipe-breach-data"
    end

    if context.family == FLUID_EFFECT_FAMILY_CRYO then
        return "pipe-breach-cryo"
    end

    if context.family == FLUID_EFFECT_FAMILY_THERMAL then
        return "pipe-breach-thermal"
    end

    if context.family == FLUID_EFFECT_FAMILY_CHEMICAL then
        return "pipe-breach-chemical"
    end

    return "pipe-breach-generic"
end

local function get_notification_print_key(context, include_fluid)
    local suffix = include_fluid and "-1" or "-2"
    if not context then
        return "incompatible-pipe-chemical" .. suffix
    end

    if context.breach_kind == "phase-shift" then
        return include_fluid and "phase-shift-pipe-1" or "phase-shift-pipe-2"
    end

    if context.family == FLUID_EFFECT_FAMILY_DATA then
        return "incompatible-pipe-data" .. suffix
    end

    if context.family == FLUID_EFFECT_FAMILY_CRYO then
        return "incompatible-pipe-cryo" .. suffix
    end

    if context.family == FLUID_EFFECT_FAMILY_THERMAL then
        return "incompatible-pipe-thermal" .. suffix
    end

    if context.family == FLUID_EFFECT_FAMILY_CHEMICAL then
        return "incompatible-pipe-chemical" .. suffix
    end

    return "incompatible-pipe-chemical" .. suffix
end

local function get_breach_entity_message_name(entity)
    if entity and entity.localised_name then
        return entity.localised_name
    end

    if entity and entity.name then
        return {"entity-name." .. entity.name}
    end

    return {"exotic-industries.pipe-breach-generic"}
end

local function build_breach_notification_message(context, entity)
    local incompatible_name = context and (context.incompatible_name or context.fluid_name) or nil
    local entity_name = get_breach_entity_message_name(entity)
    local location = entity and entity.gps_tag or nil
    if location then
        local key = get_notification_print_key(context, type(incompatible_name) == "string" and incompatible_name ~= "")
        if type(incompatible_name) == "string" and incompatible_name ~= "" then
            return {
                "exotic-industries." .. key,
                incompatible_name,
                entity_name,
                location,
            }
        end

        return {
            "exotic-industries." .. key,
            entity_name,
            location,
        }
    end

    local message = {
        "",
        "[img=utility/warning_icon] ",
        { "exotic-industries." .. get_notification_floating_key(context) },
    }

    if type(incompatible_name) == "string" and incompatible_name ~= "" then
        message[#message + 1] = " "
        message[#message + 1] = { "fluid-name." .. incompatible_name }
    end

    message[#message + 1] = " "
    message[#message + 1] = entity_name

    return message
end

local function get_breach_notification_signature(context)
    if not context then
        return "generic"
    end

    return table.concat({
        tostring(context.breach_kind or "destroy"),
        tostring(context.family or "generic"),
        tostring(context.incompatible_name or context.fluid_name or ""),
    }, "::")
end

local function get_breach_floating_target(entity, context)
    if not (entity and entity.valid) then
        return nil
    end

    local carrier = context and context.carrier or nil
    local y_offset = -1.1
    if carrier == FLUID_CARRIER_VESSEL then
        y_offset = -2.0
    elseif carrier == FLUID_CARRIER_ELEVATED_LINE then
        y_offset = -1.45
    elseif carrier == FLUID_CARRIER_SIGNAL_LINE then
        y_offset = -1.2
    end

    return {
        surface = entity.surface,
        position = {
            x = entity.position.x,
            y = entity.position.y + y_offset,
        }
    }
end

local function get_breach_floating_color(context)
    if not context then
        return {r = 1, g = 1, b = 1}
    end

    if context.breach_kind == "phase-shift" or context.family == FLUID_EFFECT_FAMILY_CRYO then
        return {r = 0.68, g = 0.9, b = 1}
    end

    if context.family == FLUID_EFFECT_FAMILY_DATA then
        return {r = 0.52, g = 1, b = 0.96}
    end

    if context.family == FLUID_EFFECT_FAMILY_THERMAL then
        if context.variant == "lava" then
            return {r = 1, g = 0.32, b = 0.14}
        end

        return {r = 1, g = 0.56, b = 0.18}
    end

    if context.family == FLUID_EFFECT_FAMILY_CHEMICAL then
        return {r = 0.7, g = 1, b = 0.42}
    end

    return {r = 1, g = 1, b = 1}
end

local function spawn_breach_floating_text(entity, context, intent)
    local target = get_breach_floating_target(entity, context)
    if not (target and target.surface and target.surface.valid and target.position) then
        return false
    end

    local message = { "exotic-industries." .. get_notification_floating_key(context) }
    local ok, created = pcall(function()
        return target.surface.create_entity{
            name = "flying-text",
            position = target.position,
            text = message,
            color = get_breach_floating_color(context),
        }
    end)

    if ok and created and created.valid then
        return true
    end

    ei_lib.crystal_echo_floating(message, target, BREACH_FALLBACK_FLOATING_TTL, intent)
    return false
end

maybe_echo_phase_shift_feedback = function(segment, context, tick)
    local entity = context and context.entity
    if not (entity and entity.valid) then
        return false
    end

    tick = tonumber(tick) or (game and game.tick) or 0

    if segment then
        local last_tick = segment.last_phase_shift_feedback_tick
        if last_tick and (tick - last_tick) < LIGHT_CRYO_FEEDBACK_COOLDOWN_TICKS then
            return false
        end
        segment.last_phase_shift_feedback_tick = tick
    end

    spawn_breach_floating_text(entity, context, "serenity")

    return true
end

maybe_notify_breach = function(segment, context, tick)
    local entity = context and context.entity
    if not (entity and entity.valid) then
        return
    end

    tick = tonumber(tick) or (game and game.tick) or 0

    if segment then
        local signature = get_breach_notification_signature(context)
        local last_tick = tonumber(segment.last_notified_tick) or 0
        if segment.last_notified_signature == signature
            and last_tick > 0
            and (tick - last_tick) < BREACH_NOTIFICATION_COOLDOWN_TICKS
        then
            return
        end

        segment.last_notified_tick = tick
        segment.last_notified_signature = signature
    end

    ei_lib.notify_connected_players("insulated_pipe", build_breach_notification_message(context, entity))

    spawn_breach_floating_text(entity, context, context.breach_kind == "phase-shift" and "serenity" or "wrath")
end

local function destroy_offending_entity(runtime, segment_id, segment, entry, status, incompatible_name, amount, preferred_replacement_unit, shared_breach, tick)
    local entity = entry and entry.entity
    if not (entity and entity.valid) then
        return false
    end

    local carrier = resolve_carrier_class(entry)
    local effect_amount = amount
    if carrier == FLUID_CARRIER_VESSEL then
        effect_amount = get_entity_target_fluid_amount(entity, incompatible_name)
    end

    local replacement_unit = preferred_replacement_unit
    local replacement_entry = nil
    local drain_mode = nil
    local segment_preserve_excess = nil
    local skip_aftermath = false

    if shared_breach then
        replacement_unit = shared_breach.replacement_unit or replacement_unit
        replacement_entry = shared_breach.replacement_entry or replacement_entry
        if shared_breach.applied then
            drain_mode = "none"
            skip_aftermath = true
            segment_preserve_excess = false
        else
            segment_preserve_excess = replacement_unit ~= nil
        end
    end

    if segment_id and not skip_aftermath and not replacement_entry then
        replacement_entry = find_segment_replacement_entry(runtime, segment_id, entry.unit_number, replacement_unit)
    end

    local context = resolve_breach_context(segment_id, segment, entry, status, incompatible_name, {
        should_destroy = true,
        carrier = carrier,
        amount = amount,
        effect_amount = effect_amount,
        fluidbox_volume = get_entity_fluidbox_capacity(entity),
        replacement_entry = replacement_entry,
        drain_mode = drain_mode,
        segment_preserve_excess = segment_preserve_excess,
        skip_aftermath = skip_aftermath,
    })

    if shared_breach and shared_breach.applied then
        context.fluid_name = shared_breach.fluid_name or context.fluid_name
        context.incompatible_name = shared_breach.incompatible_name or context.incompatible_name
    end

    local applied = apply_breach_context(runtime, segment_id, segment, context, tick or (game and game.tick) or 0)
    if shared_breach and applied and not shared_breach.applied then
        shared_breach.applied = true
        shared_breach.fluid_name = context.fluid_name or shared_breach.fluid_name
        shared_breach.incompatible_name = context.incompatible_name or shared_breach.incompatible_name
        if context.replacement_entry then
            shared_breach.replacement_entry = context.replacement_entry
        end
        if context.replacement_entry and context.replacement_entry.unit_number then
            shared_breach.replacement_unit = context.replacement_entry.unit_number
        end
    end

    return applied
end

local function audit_unsegmented_entry(runtime, entry, tick)
    if not (entry and entry.entity and entry.entity.valid) then
        return false
    end

    tick = math.max(0, tonumber(tick) or (game and game.tick) or 0)

    if entry.class == FLUID_CLASS_INSULATED then
        return true
    end

    local fluid_name, amount = read_entity_fluid(entry.entity)
    local status = classify_fluid_status(fluid_name)
    if status == FLUID_STATUS_EMPTY then
        return true
    end

    if should_destroy_for_status(status, entry.class) then
        destroy_offending_entity(runtime, nil, nil, entry, status, fluid_name, amount, nil, nil, tick)
        return true
    end

    if status == FLUID_STATUS_CRYO_NITROGEN or status == FLUID_STATUS_CRYO_OXYGEN then
        if entry.class == FLUID_CLASS_NORMAL and amount > 0 then
            local context = resolve_breach_context(nil, nil, entry, status, fluid_name, {
                amount = amount,
                severity = AFTERMATH_SEVERITY_LIGHT,
                queue_kind = AFTERMATH_QUEUE_VENT,
                breach_kind = "phase-shift",
                drain_mode = "entity",
                replacement_fluid = cryo_conversion_lookup[fluid_name],
                fluidbox_volume = get_entity_fluidbox_capacity(entry.entity),
            })
            apply_breach_context(runtime, nil, nil, context, tick)
        end
        return true
    end

    return true
end

current_entity_segment_id = function(entry)
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

local function process_segment_violations(runtime, segment_id, status, incompatible_name, segment_amount, breach_plan, tick)
    local segment = runtime.segments[segment_id]
    if not segment then
        return false
    end

    tick = tick or (game and game.tick) or 0
    breach_plan = breach_plan or build_segment_breach_plan(runtime, segment_id, status)
    local shared_breach = nil
    local anchor_unit = nil

    local member_count = get_segment_member_count(segment)
    local loop_limit = member_count + 1
    local iterations = 0
    local processed = 0
    local current_unit = advance_segment_cursor(segment)
    local last_processed = segment.cursor_unit

    if breach_plan and breach_plan.primary_entry then
        anchor_unit = breach_plan.primary_entry.unit_number
        shared_breach = {
            anchor_unit = anchor_unit,
            replacement_entry = breach_plan.replacement_entry,
            replacement_unit = breach_plan.replacement_entry and breach_plan.replacement_entry.unit_number or nil,
            applied = false,
            fluid_name = incompatible_name,
            incompatible_name = incompatible_name,
        }

        if destroy_offending_entity(
            runtime,
            segment_id,
            segment,
            breach_plan.primary_entry,
            status,
            incompatible_name,
            segment_amount,
            shared_breach.replacement_unit,
            shared_breach,
            tick
        ) then
            processed = processed + 1
        end
    end

    while current_unit and processed < SEGMENT_MEMBER_ACTION_BUDGET do
        iterations = iterations + 1
        if iterations > loop_limit then
            log_segment_loop_guard("process_segment_violations", segment_id, member_count, status, incompatible_name)
            current_unit = nil
            break
        end

        local next_unit = next_member_after(segment.members, current_unit)
        local entry = runtime.entries_by_unit[current_unit]

        if anchor_unit and current_unit == anchor_unit and shared_breach and shared_breach.applied then
            last_processed = current_unit
            current_unit = next_unit
            goto continue_segment_violation_loop
        end

        if not entry or not entry.entity or not entry.entity.valid then
            prune_runtime_entry(runtime, current_unit)
        else
            local live_segment_id = current_entity_segment_id(entry)
            if live_segment_id ~= segment_id then
                set_entry_segment(runtime, entry, live_segment_id, true)
            else
                entry.last_segment_id = segment_id

                if should_destroy_for_status(status, entry.class) then
                    destroy_offending_entity(
                        runtime,
                        segment_id,
                        segment,
                        entry,
                        status,
                        incompatible_name,
                        segment_amount,
                        shared_breach and shared_breach.replacement_unit or next_unit,
                        shared_breach,
                        tick
                    )
                end
            end
        end

        processed = processed + 1
        last_processed = current_unit
        current_unit = next_unit
        ::continue_segment_violation_loop::
    end

    if current_unit then
        segment.cursor_unit = last_processed
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
                    tostring(get_segment_member_count(segment)),
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

local function audit_segment(runtime, segment_id, tick)
    local fluid_name, amount, status = read_segment_fluid(runtime, segment_id)
    local segment = runtime.segments[segment_id]
    if not segment then
        return false
    end

    tick = math.max(0, tonumber(tick) or (game and game.tick) or 0)
    segment.status = status

    if status == FLUID_STATUS_EMPTY or status == FLUID_STATUS_STABLE then
        segment.requeue_window_tick = nil
        segment.requeue_window_count = nil
        return true
    end

    if status == FLUID_STATUS_CRYO_NITROGEN or status == FLUID_STATUS_CRYO_OXYGEN then
        local breach_plan = build_segment_breach_plan(runtime, segment_id, status)
        local normal_entry = breach_plan and breach_plan.normal_entry or nil
        if normal_entry then
            local context = resolve_breach_context(segment_id, segment, normal_entry, status, fluid_name, {
                amount = amount,
                severity = AFTERMATH_SEVERITY_LIGHT,
                queue_kind = AFTERMATH_QUEUE_VENT,
                breach_kind = "phase-shift",
                drain_mode = "segment",
                replacement_fluid = cryo_conversion_lookup[fluid_name],
                replacement_entry = normal_entry,
                fluidbox_volume = get_entity_fluidbox_capacity(normal_entry.entity),
                segment_preserve_excess = false,
            })
            apply_breach_context(runtime, segment_id, segment, context, tick)
        elseif get_segment_member_count(segment) > 0 then
            maybe_log_segment_warning(
                segment,
                "last_cryo_no_normal_log_tick",
                60,
                string.format(
                    "cryo segment has no normal member segment=%s status=%s fluid=%s members=%s tick=%s",
                    tostring(segment_id),
                    tostring(status),
                    tostring(fluid_name),
                    tostring(get_segment_member_count(segment)),
                    tostring(tick)
                )
            )
        end
        process_segment_violations(runtime, segment_id, status, fluid_name, amount, breach_plan, tick)
        return true
    end

    if status == FLUID_STATUS_DATA or status == FLUID_STATUS_NEEDS_INSULATED or status == FLUID_STATUS_SAFE then
        process_segment_violations(runtime, segment_id, status, fluid_name, amount, nil, tick)
        return true
    end

    return true
end

local function enqueue_connected_neighbors(runtime, entity)
    if not entity_has_fluidbox(entity) then
        return
    end

    local seen = {}
    for index = 1, #entity.fluidbox do
        local ok, connections = pcall(function()
            return entity.fluidbox.get_connections(index)
        end)

        if ok and connections then
            for _, connection in pairs(connections) do
                local owner = connection and connection.owner
                local unit_number = get_entity_unit_number(owner)
                if unit_number and not seen[unit_number] and runtime.entries_by_unit[unit_number] then
                    seen[unit_number] = true
                    model.enqueue_urgent_entity(unit_number)
                end
            end
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
    runtime.segments = runtime.segments or {}

    if runtime.queue_storage_version ~= FLUID_QUEUE_STORAGE_VERSION then
        runtime.urgent_units = migrate_runtime_queue(runtime, "urgent_units", "urgent_head", "urgent_tail", "urgent_pending", "urgent_count")
        runtime.dirty_segments = migrate_runtime_queue(runtime, "dirty_segments", "dirty_head", "dirty_tail", "dirty_pending", "dirty_count")
        runtime.queue_storage_version = FLUID_QUEUE_STORAGE_VERSION
    else
        runtime.urgent_units = ei_runtime_scheduler.ensure_queue(runtime.urgent_units)
        sync_runtime_queue_compat_fields(runtime, runtime.urgent_units, "urgent_head", "urgent_tail", "urgent_pending")
        runtime.urgent_count = get_runtime_queue_count(runtime, "urgent_units", "urgent_count")
        runtime.dirty_segments = ei_runtime_scheduler.ensure_queue(runtime.dirty_segments)
        sync_runtime_queue_compat_fields(runtime, runtime.dirty_segments, "dirty_head", "dirty_tail", "dirty_pending")
        runtime.dirty_count = get_runtime_queue_count(runtime, "dirty_segments", "dirty_count")
    end

    runtime.service_mode_cursor = math.max(1, runtime.service_mode_cursor or 1)
    runtime.initialized = runtime.initialized == true
    ensure_aftermath_stats(runtime)

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

local function rebuild_runtime_entry(runtime, entity)
    if not (entity and entity.valid and entity.force and model.counts_for_fluid_handling(entity)) then
        return false
    end

    local entry = add_runtime_entry(runtime, entity)
    if not entry then
        return false
    end

    entry.class = model.classify_entity(entity)
    local segment_id = current_entity_segment_id(entry)
    set_entry_segment(runtime, entry, segment_id, false)
    return true
end

function model.enqueue_urgent_entity(unit_number)
    local runtime = model.ensure_fluid_runtime()
    return enqueue_runtime_queue_value(runtime, "urgent_units", "urgent_head", "urgent_tail", "urgent_pending", "urgent_count", unit_number)
end

function model.enqueue_dirty_segment(segment_id)
    local runtime = model.ensure_fluid_runtime()
    return enqueue_runtime_queue_value(runtime, "dirty_segments", "dirty_head", "dirty_tail", "dirty_pending", "dirty_count", segment_id)
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

    enqueue_connected_neighbors(runtime, entity)
    model.touch_entity(entry.unit_number)
    if not entry.last_segment_id then
        model.enqueue_urgent_entity(entry.unit_number)
    end

    return true
end

function model.on_fluid_entity_deregistered(entity)
    local runtime = model.ensure_fluid_runtime()
    local unit_number = get_entity_unit_number(entity)
    if not unit_number then
        return false
    end

    local entry = runtime.entries_by_unit[unit_number]
    if not entry then
        return false
    end

    enqueue_connected_neighbors(runtime, entity)
    if entry.last_segment_id then
        model.enqueue_dirty_segment(entry.last_segment_id)
    end

    return prune_runtime_entry(runtime, unit_number)
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
        for _, entity in pairs(surface.find_entities_filtered{type = FLUID_RUNTIME_REBUILD_TYPES}) do
            rebuild_runtime_entry(runtime, entity)
        end

        for _, entity in pairs(surface.find_entities_filtered{name = FLUID_RUNTIME_REBUILD_NAMES}) do
            rebuild_runtime_entry(runtime, entity)
        end
    end

    runtime.scan_index = 1
    runtime.urgent_units = ei_runtime_scheduler.clear_queue(runtime.urgent_units)
    sync_runtime_queue_compat_fields(runtime, runtime.urgent_units, "urgent_head", "urgent_tail", "urgent_pending")
    runtime.urgent_count = 0
    runtime.dirty_segments = ei_runtime_scheduler.clear_queue(runtime.dirty_segments)
    sync_runtime_queue_compat_fields(runtime, runtime.dirty_segments, "dirty_head", "dirty_tail", "dirty_pending")
    runtime.dirty_count = 0
    runtime.queue_storage_version = FLUID_QUEUE_STORAGE_VERSION
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

function model.on_configuration_changed(event)
    local mod_changes_present = event and next(event.mod_changes or {}) ~= nil or false
    if not mod_changes_present then
        return false
    end

    model.rebuild_fluid_runtime("configuration-changed")
    return true
end

function model.get_fluid_work_count()
    local runtime = model.ensure_fluid_runtime()
    return runtime.tracked_count or 0
end

function model.get_runtime_status()
    local runtime = model.ensure_fluid_runtime()
    local aftermath_stats = ensure_aftermath_stats(runtime)
    local next_service_mode = get_runtime_queue_count(runtime, "urgent_units", "urgent_count") <= 0
        and get_runtime_queue_count(runtime, "dirty_segments", "dirty_count") <= 0
        and #runtime.scan_units <= 0 and "idle" or nil
    local status = {
        initialized = runtime.initialized == true,
        tracked_entities = runtime.tracked_count or 0,
        segments = count_present_keys(runtime.segments),
        urgent_queue = get_runtime_queue_count(runtime, "urgent_units", "urgent_count"),
        dirty_queue = get_runtime_queue_count(runtime, "dirty_segments", "dirty_count"),
        scan_units = #runtime.scan_units,
        service_mode_cursor = runtime.service_mode_cursor or 1,
        service_mode_name = next_service_mode or nil,
        heavy_aftermath_queued = aftermath_stats.heavy_aftermath_queued or 0,
        light_vent_queued = aftermath_stats.light_vent_queued or 0,
        heavy_cooldown_suppressed = aftermath_stats.heavy_cooldown_suppressed or 0,
        light_cooldown_suppressed = aftermath_stats.light_cooldown_suppressed or 0,
    }

    status.service_mode_name = status.service_mode_name or get_next_service_mode_name(runtime, {
        urgent = status.urgent_queue,
        dirty = status.dirty_queue,
        scan = status.scan_units,
    })
    runtime.service_mode_name = status.service_mode_name
    ei_runtime_scheduler.set_module_status(MODULE_NAME, status)
    return status
end

local function get_fluid_queue_snapshot(runtime, snapshot)
    snapshot = snapshot or {}
    snapshot.urgent = get_runtime_queue_count(runtime, "urgent_units", "urgent_count")
    snapshot.dirty = get_runtime_queue_count(runtime, "dirty_segments", "dirty_count")
    snapshot.scan = #runtime.scan_units
    return snapshot
end

local function process_one_urgent(runtime, tick)
    local unit_number = dequeue_runtime_queue_value(runtime, "urgent_units", "urgent_head", "urgent_tail", "urgent_pending", "urgent_count")
    while unit_number do
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
                    audit_unsegmented_entry(runtime, live_entry, tick)
                end
                return true
            end
        end

        unit_number = dequeue_runtime_queue_value(runtime, "urgent_units", "urgent_head", "urgent_tail", "urgent_pending", "urgent_count")
    end

    return false
end

local function process_one_dirty(runtime, tick)
    local segment_id = dequeue_runtime_queue_value(runtime, "dirty_segments", "dirty_head", "dirty_tail", "dirty_pending", "dirty_count")
    while segment_id do
        if runtime.segments[segment_id] then
            audit_segment(runtime, segment_id, tick)
            return true
        end
        segment_id = dequeue_runtime_queue_value(runtime, "dirty_segments", "dirty_head", "dirty_tail", "dirty_pending", "dirty_count")
    end

    return false
end

local function process_one_scan(runtime, full_update_ticks, tick)
    local tracked_count = #runtime.scan_units
    if tracked_count == 0 then
        runtime.scan_index = 1
        return false
    end

    tick = math.max(0, tonumber(tick) or (game and game.tick) or 0)

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
        full_update_ticks = math.max(1, tonumber(full_update_ticks) or math.max(1, tonumber(ei_ticksPerFullUpdate) or 60))
        if segment and (previous_segment_id ~= entry.last_segment_id
            or not segment.last_scan_enqueued_tick
            or (tick - segment.last_scan_enqueued_tick) >= full_update_ticks) then
            segment.last_scan_enqueued_tick = tick
            model.enqueue_dirty_segment(entry.last_segment_id)
        end
        return true
    end

    audit_unsegmented_entry(runtime, entry, tick)
    return true
end

local function process_one_mode(runtime, mode, full_update_ticks, tick)
    if mode == "urgent" then
        return process_one_urgent(runtime, tick)
    end

    if mode == "dirty" then
        return process_one_dirty(runtime, tick)
    end

    if mode == "scan" then
        return process_one_scan(runtime, full_update_ticks, tick)
    end

    return false
end

local function resolve_weighted_service_mode(runtime, snapshot, advance_cursor)
    snapshot = get_fluid_queue_snapshot(runtime, snapshot)
    if snapshot.urgent <= 0 and snapshot.dirty <= 0 and snapshot.scan <= 0 then
        if advance_cursor then
            runtime.service_mode_cursor = 1
        end
        return nil
    end

    local cursor = math.max(1, runtime.service_mode_cursor or 1)
    local rotation_length = #FLUID_SERVICE_ROTATION
    for offset = 0, rotation_length - 1 do
        local index = ((cursor + offset - 1) % rotation_length) + 1
        local mode = FLUID_SERVICE_ROTATION[index]
        if snapshot[mode] and snapshot[mode] > 0 then
            if advance_cursor then
                runtime.service_mode_cursor = (index % rotation_length) + 1
            end
            return mode
        end
    end

    if advance_cursor then
        runtime.service_mode_cursor = 1
    end
    return nil
end

get_next_service_mode_name = function(runtime, snapshot)
    return resolve_weighted_service_mode(runtime, snapshot, false) or "idle"
end

local function pick_weighted_service_mode(runtime, snapshot)
    return resolve_weighted_service_mode(runtime, snapshot, true)
end

function model.service_fluid_runtime(budget, event_or_tick)
    local runtime = model.ensure_fluid_runtime()
    if (runtime.tracked_count or 0) <= 0 then
        return 0
    end

    budget = math.max(1, math.floor(tonumber(budget) or 1))
    local tick = ei_lib.get_event_tick(event_or_tick)
    if tick <= 0 then
        tick = (game and game.tick) or 0
    end
    local performed = 0
    local full_update_ticks = math.max(1, tonumber(ei_ticksPerFullUpdate) or 60)
    local snapshot = get_fluid_queue_snapshot(runtime)

    -- Single-slot budgets follow the weighted rotation directly so sustained urgent churn
    -- cannot pin the runtime forever when step 2 only has one unit of work to spend.
    if budget == 1 then
        local mode = pick_weighted_service_mode(runtime, snapshot)
        if mode and process_one_mode(runtime, mode, full_update_ticks, tick) then
            return 1
        end

        return 0
    end

    -- Reserve one immediate urgent slot so freshly touched entities still react quickly.
    if snapshot.urgent > 0 and process_one_urgent(runtime, tick) then
        performed = performed + 1
        get_fluid_queue_snapshot(runtime, snapshot)
    end

    -- Reserve a little room for repair and background validation so a constant stream of
    -- urgent wakeups cannot indefinitely starve segment audits or round-robin scans.
    if performed < budget and snapshot.dirty > 0 and budget >= 2 then
        if process_one_dirty(runtime, tick) then
            performed = performed + 1
            get_fluid_queue_snapshot(runtime, snapshot)
        end
    end

    if performed < budget and snapshot.scan > 0 and budget >= 3 then
        if process_one_scan(runtime, full_update_ticks, tick) then
            performed = performed + 1
            get_fluid_queue_snapshot(runtime, snapshot)
        end
    end

    while performed < budget do
        local mode = pick_weighted_service_mode(runtime, snapshot)
        if not mode or not process_one_mode(runtime, mode, full_update_ticks, tick) then
            break
        end

        performed = performed + 1
        get_fluid_queue_snapshot(runtime, snapshot)
    end

    return performed
end

return model
