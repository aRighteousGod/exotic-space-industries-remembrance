--==============================================================================
-- ESIR FILE MAP
-- owns: Gaian saucer chromatic wake runtime visuals
-- loaded_by: exotic-space-industries-remembrance\control.lua
-- cadence: control.lua updater fan-out, internally gated by startup preset
-- forwarded_events: check_global, get_pending_work_count, get_qc_snapshot, get_runtime_status, on_built_entity, on_configuration_changed, on_destroyed_entity, rebuild_runtime_state, reset_runtime_state, service_for_qc, updater
-- storage_roots: storage.ei.gaian_saucer_wake
-- gui_ids: none
-- remote_interfaces: none
-- rebuild_on: startup setting changes, prototype changes, runtime schema changes
--==============================================================================

local model = {}
local ei_lib = require("lib/lib")
local scheduler = require("lib/runtime-scheduler")
local wake_config = require("lib/gaian-saucer-wake-config")

local MODULE_NAME = "gaian-saucer-wake"
local RUNTIME_STATE_VERSION = 1
local SAUCER_NAME = "ei-gaian-saucer"
local WAKE_ANIMATION = "ei-gaian-saucer-wake"
local FRAME_COUNT = 64
local TAU = math.pi * 2
local STATUS_REFRESH_INTERVAL = 300
local WAKE_UNDERBODY_Y_OFFSET = -1.25
-- Factorio's runtime Lua is 5.2-style; use atan2 explicitly for movement directions.
local atan2 = math.atan2 or function(y, x) return math.atan(y, x) end
local cached_visual_config = nil
local runtime_active = nil

-- Startup settings are immutable during a session, so normalize the fidelity
-- preset once and reuse the resolved numeric budget until a rebuild clears it.
local function get_visual_config()
    if cached_visual_config then
        return cached_visual_config
    end

    local visual_config = wake_config.resolve()
    visual_config.update_interval = math.max(1, math.floor(tonumber(visual_config.update_interval) or 1))
    visual_config.service_cap_value = wake_config.get_service_cap(visual_config)
    visual_config.global_burst_cap_value = wake_config.get_global_burst_cap(visual_config)
    visual_config.burst_ttl = math.max(1, math.floor(tonumber(visual_config.burst_ttl) or 1))
    visual_config.animation_speed = tonumber(visual_config.animation_speed) or 0.45
    visual_config.scale = tonumber(visual_config.scale) or 0.23
    visual_config.wake_offset = tonumber(visual_config.wake_offset) or 1.4
    visual_config.wake_rear_bias = ei_lib.clamp_number(visual_config.wake_rear_bias, 0, 1, 1)
    visual_config.wake_turn_gain = ei_lib.clamp_number(visual_config.wake_turn_gain, 0, nil, 0)
    visual_config.wake_turn_max = ei_lib.clamp_number(visual_config.wake_turn_max, 0, nil, 0)
    visual_config.wake_turn_smoothing = ei_lib.clamp_number(visual_config.wake_turn_smoothing, 0, 1, 1)
    visual_config.movement_threshold = tonumber(visual_config.movement_threshold) or 0.03
    visual_config.movement_threshold_sq = visual_config.movement_threshold * visual_config.movement_threshold
    visual_config.min_unit_emit_interval = math.max(0, math.floor(tonumber(visual_config.min_unit_emit_interval) or 0))

    cached_visual_config = visual_config
    return visual_config
end

local function reset_visual_config_cache()
    cached_visual_config = nil
    runtime_active = nil
end

local function resolve_tick(event_or_tick)
    if type(event_or_tick) == "number" then
        return event_or_tick
    end

    if type(event_or_tick) == "table" and event_or_tick.tick then
        return event_or_tick.tick
    end

    return game and game.tick or 0
end

local function get_event_entity(event_or_entity)
    if ei_lib.entity_check(event_or_entity) then
        return event_or_entity
    end

    if type(event_or_entity) ~= "table" then
        return nil
    end

    return event_or_entity.entity
        or event_or_entity.created_entity
        or event_or_entity.destination
end

local function bump_counter(state, counter_name, delta)
    delta = delta or 1
    state.counters[counter_name] = (state.counters[counter_name] or 0) + delta
    state.counters_dirty = true
    return state.counters[counter_name]
end

-- Local counters stay cheap during movement service; the shared scheduler status
-- only receives deltas when the module actually reports status.
local function flush_scheduler_counters(state)
    if state.counters_dirty ~= true then
        return
    end

    state.scheduler_counters = type(state.scheduler_counters) == "table" and state.scheduler_counters or {}
    for counter_name, value in pairs(state.counters) do
        local normalized_value = tonumber(value) or 0
        local previous_value = tonumber(state.scheduler_counters[counter_name]) or 0
        local delta = normalized_value - previous_value
        if delta ~= 0 then
            scheduler.bump_counter(MODULE_NAME, counter_name, delta)
            state.scheduler_counters[counter_name] = normalized_value
        end
    end

    state.counters_dirty = false
end

-- Tracking is keyed by saucer unit number. The queue is a rotating work list, not
-- ownership state, so counts are cached and repaired for low steady-state cost.
local function ensure_state()
    storage.ei = storage.ei or {}

    local state = storage.ei.gaian_saucer_wake
    if type(state) ~= "table" then
        state = {}
        storage.ei.gaian_saucer_wake = state
    end

    state.version = RUNTIME_STATE_VERSION
    state.tracked = type(state.tracked) == "table" and state.tracked or {}
    state.active_queue = scheduler.ensure_queue(state.active_queue)
    state.counters = type(state.counters) == "table" and state.counters or {}
    state.last_update_tick = tonumber(state.last_update_tick) or 0
    state.last_rebuild_tick = tonumber(state.last_rebuild_tick) or 0
    state.last_status_tick = tonumber(state.last_status_tick) or 0
    state.last_fidelity = state.last_fidelity or nil
    if state.tracked_count == nil then
        state.tracked_count = scheduler.table_count(state.tracked)
    end
    if state.active_queue_count == nil then
        state.active_queue_count = scheduler.table_count(state.active_queue.queued)
    end
    return state
end

-- Turning the startup setting off should remove all live wake state immediately,
-- not merely stop future emissions while stale records linger.
local function clear_runtime_state(state)
    state.tracked = {}
    state.active_queue = scheduler.clear_queue(state.active_queue)
    state.active_queue_count = 0
    state.tracked_count = 0
    state.last_update_tick = 0
    runtime_active = false
    return state
end

local function get_active_queue_count(state)
    local active_queue_count = tonumber(state.active_queue_count)
    if active_queue_count ~= nil then
        return active_queue_count
    end

    state.active_queue = scheduler.ensure_queue(state.active_queue)
    active_queue_count = scheduler.table_count(state.active_queue.queued)
    state.active_queue_count = active_queue_count
    return active_queue_count
end

local function make_status(state, current_tick, visual_config)
    state = state or ensure_state()
    visual_config = visual_config or get_visual_config()
    current_tick = resolve_tick(current_tick)
    state.last_fidelity = visual_config.visual_fidelity
    flush_scheduler_counters(state)

    local queue_audit = scheduler.audit_queue(state.active_queue)
    local status = {
        enabled = visual_config.enabled == true,
        visual_fidelity = visual_config.visual_fidelity,
        tracked_saucers = tonumber(state.tracked_count) or scheduler.table_count(state.tracked),
        queue_items = queue_audit.length,
        queue_unique = queue_audit.unique,
        queue_span = queue_audit.span,
        emitted = tonumber(state.counters.emitted) or 0,
        capped = tonumber(state.counters.capped) or 0,
        invalid_purges = tonumber(state.counters.invalid_purges) or 0,
        registered = tonumber(state.counters.registered) or 0,
        deregistered = tonumber(state.counters.deregistered) or 0,
        last_update_tick = tonumber(state.last_update_tick) or 0,
        last_rebuild_tick = tonumber(state.last_rebuild_tick) or 0,
        update_interval = visual_config.update_interval,
        service_cap = visual_config.service_cap_value or "unbounded",
        global_burst_cap = visual_config.global_burst_cap_value or "unbounded",
        tick = current_tick,
    }

    scheduler.set_module_status(MODULE_NAME, status)
    state.last_status_tick = current_tick
    return status
end

local function maybe_make_status(state, current_tick, visual_config)
    if current_tick - (tonumber(state.last_status_tick) or 0) >= STATUS_REFRESH_INTERVAL then
        make_status(state, current_tick, visual_config)
    end
end

local function is_relevant_entity(entity)
    return ei_lib.entity_check(entity) and entity.name == SAUCER_NAME
end

local function deregister_unit(state, unit_number, current_tick, reason)
    unit_number = tonumber(unit_number) or nil
    if not unit_number then
        return false
    end

    if not state.tracked[unit_number] then
        return false
    end

    state.tracked[unit_number] = nil
    state.active_queue = scheduler.ensure_queue(state.active_queue)
    local active_queue_count = get_active_queue_count(state)
    if state.active_queue.queued[unit_number] then
        state.active_queue.queued[unit_number] = nil
        state.active_queue_count = math.max(0, active_queue_count - 1)
    end
    state.tracked_count = math.max(0, (tonumber(state.tracked_count) or scheduler.table_count(state.tracked)) - 1)
    if state.tracked_count <= 0 then
        runtime_active = false
    end
    bump_counter(state, reason == "invalid" and "invalid_purges" or "deregistered", 1)
    state.last_update_tick = resolve_tick(current_tick)
    return true
end

local function queue_unit(state, unit_number)
    if not unit_number then
        return false
    end

    state.active_queue = scheduler.ensure_queue(state.active_queue)
    local active_queue_count = get_active_queue_count(state)
    local pushed = scheduler.queue_push_unique(state.active_queue, unit_number, unit_number)
    if pushed then
        state.active_queue_count = active_queue_count + 1
    end
    return pushed == true
end

local function pop_queued_unit(state)
    local active_queue_count = get_active_queue_count(state)
    local unit_number = scheduler.queue_pop_queued(state.active_queue)
    if unit_number then
        state.active_queue_count = math.max(0, active_queue_count - 1)
    else
        state.active_queue_count = 0
    end
    return unit_number
end

-- Built/rebuilt saucers enter the scheduler only when visuals are enabled. The
-- stored position sample is used for movement vectors, independent of torso facing.
local function register_entity(entity, current_tick, visual_config)
    visual_config = visual_config or get_visual_config()
    if visual_config.enabled ~= true or not is_relevant_entity(entity) then
        return false
    end

    local unit_number = ei_lib.get_entity_unit_number(entity)
    if not unit_number then
        return false
    end

    current_tick = resolve_tick(current_tick)
    local state = ensure_state()
    local position = entity.position
    local record = state.tracked[unit_number]
    if not record then
        record = {
            unit_number = unit_number,
            last_emit_tick = 0,
            last_seen_tick = current_tick,
            wake_lateral_drift = 0,
        }
        state.tracked[unit_number] = record
        state.tracked_count = (tonumber(state.tracked_count) or 0) + 1
        bump_counter(state, "registered", 1)
    end

    record.entity = entity
    record.surface_index = entity.surface and entity.surface.index or nil
    record.force_index = entity.force and entity.force.index or nil
    record.last_x = tonumber(record.last_x) or (record.last_position and tonumber(record.last_position.x)) or position.x
    record.last_y = tonumber(record.last_y) or (record.last_position and tonumber(record.last_position.y)) or position.y
    record.last_position = nil
    record.wake_lateral_drift = tonumber(record.wake_lateral_drift) or 0
    record.last_seen_tick = current_tick
    queue_unit(state, unit_number)
    runtime_active = true
    return true
end

-- Turn slip is the signed 2D cross product between the last and current movement
-- normals. Presets scale and smooth it so curved flight curls without snapping.
local function update_turn_drift(record, nx, ny, visual_config)
    local previous_nx = tonumber(record.last_nx)
    local previous_ny = tonumber(record.last_ny)
    local previous_drift = tonumber(record.wake_lateral_drift) or 0
    local target_drift = 0

    if previous_nx and previous_ny then
        local turn = previous_nx * ny - previous_ny * nx
        local turn_max = visual_config.wake_turn_max
        target_drift = ei_lib.clamp_number(turn * visual_config.wake_turn_gain, -turn_max, turn_max, 0)
    end

    local smoothing = visual_config.wake_turn_smoothing
    record.wake_lateral_drift = previous_drift * smoothing + target_drift * (1 - smoothing)
    record.last_nx = nx
    record.last_ny = ny
    return record.wake_lateral_drift
end

local function draw_wake(record, entity, dx, dy, nx, ny, visual_config)
    local wake_offset = visual_config.wake_offset * visual_config.wake_rear_bias
    local lateral_drift = tonumber(record.wake_lateral_drift) or 0
    local side_x = -ny
    local side_y = nx
    local position = entity.position
    -- Anchor under/rear of the hull, then drift sideways on turns. The fixed Y
    -- lift compensates for the saucer rendering as an air-object above the ground
    -- plane where rendering.draw_animation places the wake.
    local wake_position = {
        x = position.x - nx * wake_offset + side_x * lateral_drift,
        y = position.y + WAKE_UNDERBODY_Y_OFFSET - ny * wake_offset + side_y * lateral_drift,
    }
    local orientation = (atan2(dx, -dy) / TAU) % 1
    -- The wake sheet is a 64-direction atlas stored as an AnimationPrototype.
    -- Freeze playback and select the pre-rotated frame from movement direction:
    -- N/NE/E/SE/S/SW/W/NW map to 0/8/16/24/32/40/48/56.
    local animation_offset = math.floor(orientation * FRAME_COUNT + 0.5) % FRAME_COUNT

    local ok = pcall(function()
        rendering.draw_animation{
            animation = WAKE_ANIMATION,
            target = wake_position,
            surface = entity.surface,
            orientation = 0,
            render_layer = "object",
            animation_speed = 0,
            animation_offset = animation_offset,
            x_scale = visual_config.scale,
            y_scale = visual_config.scale,
            time_to_live = visual_config.burst_ttl,
            forces = {entity.force},
        }
    end)

    return ok
end

-- A service pass samples one saucer, updates its movement memory, and emits at
-- most one short-lived rendering object if the fidelity budget allows it.
local function service_unit(state, unit_number, current_tick, visual_config, budget)
    local record = state.tracked[unit_number]
    if not record then
        return false
    end

    local entity = ei_lib.get_valid_entity(record.entity)
    if not entity or entity.name ~= SAUCER_NAME then
        deregister_unit(state, unit_number, current_tick, "invalid")
        return true
    end

    local position = entity.position
    local last_x = tonumber(record.last_x)
        or (record.last_position and tonumber(record.last_position.x))
        or position.x
    local last_y = tonumber(record.last_y)
        or (record.last_position and tonumber(record.last_position.y))
        or position.y
    local dx = position.x - last_x
    local dy = position.y - last_y
    local distance_sq = dx * dx + dy * dy

    record.last_x = position.x
    record.last_y = position.y
    record.last_position = nil
    record.surface_index = entity.surface and entity.surface.index or nil
    record.force_index = entity.force and entity.force.index or nil
    record.last_seen_tick = current_tick

    if distance_sq > 0 and distance_sq >= visual_config.movement_threshold_sq then
        local distance = math.sqrt(distance_sq)
        local nx = dx / distance
        local ny = dy / distance
        update_turn_drift(record, nx, ny, visual_config)

        if current_tick - (tonumber(record.last_emit_tick) or 0) >= visual_config.min_unit_emit_interval then
            local cap = budget.global_burst_cap
            if cap ~= nil and budget.emitted >= cap then
                bump_counter(state, "capped", 1)
            elseif draw_wake(record, entity, dx, dy, nx, ny, visual_config) then
                record.last_emit_tick = current_tick
                budget.emitted = budget.emitted + 1
                bump_counter(state, "emitted", 1)
            end
        end
    end

    queue_unit(state, unit_number)
    return true
end

-- The shared scheduler decides when this module gets called; this function owns
-- the per-call work cap, global burst cap, and round-robin queue refill.
local function service_runtime(limit, current_tick, visual_config)
    local state = ensure_state()
    visual_config = visual_config or get_visual_config()
    current_tick = resolve_tick(current_tick)

    if visual_config.enabled ~= true then
        clear_runtime_state(state)
        make_status(state, current_tick, visual_config)
        return 0
    end

    local tracked_count = tonumber(state.tracked_count) or scheduler.table_count(state.tracked)
    if tracked_count <= 0 then
        runtime_active = false
        if get_active_queue_count(state) > 0 then
            state.active_queue = scheduler.clear_queue(state.active_queue)
            state.active_queue_count = 0
        end
        maybe_make_status(state, current_tick, visual_config)
        return 0
    end
    runtime_active = true

    if get_active_queue_count(state) <= 0 then
        for unit_number in pairs(state.tracked) do
            queue_unit(state, unit_number)
        end
    end

    local service_cap = visual_config.service_cap_value
    if service_cap == nil then
        service_cap = tracked_count
    end
    service_cap = math.max(0, math.floor(tonumber(limit) or service_cap))

    local budget = {
        emitted = 0,
        global_burst_cap = visual_config.global_burst_cap_value,
    }
    local serviced = 0

    for _ = 1, service_cap do
        local unit_number = pop_queued_unit(state)
        if not unit_number then
            break
        end

        if service_unit(state, unit_number, current_tick, visual_config, budget) then
            serviced = serviced + 1
        end
    end

    state.last_update_tick = current_tick
    maybe_make_status(state, current_tick, visual_config)
    return serviced
end

function model.check_global()
    local state = ensure_state()
    local visual_config = get_visual_config()

    if visual_config.enabled ~= true then
        if (tonumber(state.tracked_count) or 0) > 0
        or runtime_active ~= false
        or (tonumber(state.last_status_tick) or 0) <= 0 then
            clear_runtime_state(state)
            make_status(state, game and game.tick or 0, visual_config)
        else
            runtime_active = false
        end
    elseif (tonumber(state.last_status_tick) or 0) <= 0 then
        runtime_active = (tonumber(state.tracked_count) or 0) > 0
        make_status(state, game and game.tick or 0, visual_config)
    end

    return state
end

-- Rebuild is intentionally scan-based: construction/destruction events handle the
-- normal path, while configuration changes need a clean authoritative inventory.
function model.rebuild_runtime_state(reason, current_tick)
    reset_visual_config_cache()
    current_tick = resolve_tick(current_tick)
    local visual_config = get_visual_config()
    local state = ensure_state()
    clear_runtime_state(state)
    state.last_rebuild_reason = reason or "rebuild"
    state.last_rebuild_tick = current_tick

    if visual_config.enabled == true and game and game.surfaces then
        for _, surface in pairs(game.surfaces) do
            if surface and surface.valid then
                for _, entity in pairs(surface.find_entities_filtered{name = SAUCER_NAME}) do
                    register_entity(entity, current_tick, visual_config)
                end
            end
        end
    end

    make_status(state, current_tick, visual_config)
    return state
end

function model.reset_runtime_state(reason, current_tick)
    return model.rebuild_runtime_state(reason or "reset", current_tick)
end

function model.on_configuration_changed(event)
    return model.rebuild_runtime_state("configuration-changed", event)
end

function model.on_built_entity(event_or_entity)
    local entity = get_event_entity(event_or_entity)
    return register_entity(entity, resolve_tick(event_or_entity))
end

function model.on_destroyed_entity(event_or_entity)
    local entity = get_event_entity(event_or_entity)
    if not is_relevant_entity(entity) then
        return false
    end

    local unit_number = ei_lib.get_entity_unit_number(entity)
    if not unit_number then
        return false
    end

    return deregister_unit(ensure_state(), unit_number, resolve_tick(event_or_entity), "destroyed")
end

function model.get_pending_work_count()
    local visual_config = get_visual_config()
    if visual_config.enabled ~= true then
        return 0
    end

    local state = ensure_state()
    local active_queue_count = get_active_queue_count(state)
    if active_queue_count > 0 then
        return active_queue_count
    end

    return tonumber(state.tracked_count) or 0
end

function model.updater(event)
    if runtime_active == false then
        return false
    end

    local current_tick = resolve_tick(event)
    local visual_config = get_visual_config()

    if visual_config.enabled ~= true then
        runtime_active = false
        return false
    end

    if current_tick % visual_config.update_interval ~= 0 then
        return false
    end

    return service_runtime(nil, current_tick, visual_config) > 0
end

function model.service_for_qc(limit, event_or_tick)
    return service_runtime(limit, resolve_tick(event_or_tick), get_visual_config())
end

function model.get_runtime_status(current_tick)
    return make_status(ensure_state(), resolve_tick(current_tick), get_visual_config())
end

function model.get_qc_snapshot(current_tick)
    return model.get_runtime_status(current_tick)
end

return model
