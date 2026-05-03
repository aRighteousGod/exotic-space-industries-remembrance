--====================================================================================================
--SEVERANCE ARRAY
--====================================================================================================

local ei_lib = require("lib/lib")
local scheduler = require("lib/runtime-scheduler")
local severance_array_config = require("lib/severance-array-config")

local severance_array = {}

--====================================================================================================
--CONSTANTS
--====================================================================================================

local MODULE_NAME = "severance-array"
local RUNTIME_VERSION = 9

local TURRET_NAME = "ei-severance-array"
local SHOT_EFFECT_ID = "ei-severance-array-shot"
local BEAM_NAME = "ei-severance-array-beam"
local IMPACT_BEAM_NAME = "ei-severance-array-impact-beam"
local FIRE_STICKER_NAME = "ei-severance-array-fire-sticker"
local HIT_FIRE_NAME = "ei-severance-array-hit-fire"
local SCORCHMARK_NAME = "ei-severance-array-scorchmark"

local BASE_DAMAGE = 540
local AOE_DAMAGE = 90
local AOE_RADIUS = 1.1
local RANGE = 85
local AMMO_DAMAGE_CATEGORY = "laser"
local VISUAL_SOURCE_OFFSET = {x = 0, y = -2.60}

local TARGET_UPDATE_MS = 0.5
local HARD_UPDATE_MS = 1.0
local TIMING_SAMPLE_LIMIT = 120

--====================================================================================================
--RUNTIME STORAGE
--====================================================================================================

local function new_counters()
    return {
        shots = 0,
        damage_jobs = 0,
        damage_jobs_processed = 0,
        damage_jobs_expired = 0,
        damage_victims = 0,
        direct_damage_applied = 0,
        direct_damage_failed = 0,
        direct_damage_rejected = 0,
        direct_damage_amount = 0,
        impact_effects_scheduled = 0,
        impact_effects_applied = 0,
        impact_effects_expired = 0,
        impact_transactions = 0,
        impact_transactions_delayed = 0,
        impact_transactions_merged = 0,
        impact_witnesses_rendered = 0,
        impact_witnesses_dropped = 0,
        impact_fallbacks = 0,
        force_cache_refreshes = 0,
        visual_jobs = 0,
        visual_jobs_dropped = 0,
        visual_jobs_expired = 0,
        visual_jobs_retargeted = 0,
        visual_slices = 0,
        visual_slices_rendered = 0,
        fires_created = 0,
        fires_rejected = 0,
        fires_skipped = 0,
        scorchmarks_created = 0,
        scorchmarks_rejected = 0,
        scorchmarks_skipped = 0,
        stickers_applied = 0,
        stickers_rejected = 0,
        stickers_skipped = 0,
        invalid_events = 0,
        refreshes = 0,
    }
end

local function new_runtime()
    return {
        version = RUNTIME_VERSION,
        damage_queue = scheduler.ensure_queue(nil),
        impact_buckets = scheduler.ensure_delayed_buckets(nil),
        visual_queue = scheduler.ensure_queue(nil),
        force_cache = {},
        impact_effect_count = 0,
        impact_next_due_tick = 0,
        impact_witness_tick = nil,
        impact_witness_count = 0,
        visual_fidelity = nil,
        visual_config = severance_array_config.resolve(),
        visual_slice_count = 0,
        active_visual_jobs = 0,
        active_visual_by_unit = {},
        last_visual_endpoint_by_unit = {},
        next_visual_job_id = 0,
        visual_runtime_normalized = true,
        last_shot_by_unit = {},
        last_fire_by_unit = {},
        last_fire_tick = nil,
        last_sticker_tick = nil,
        last_scorch_by_unit = {},
        last_scorch_tick = nil,
        profiling_enabled = false,
        qc_enabled = false,
        counters = new_counters(),
        timings = {
            last_ms = 0,
            max_ms = 0,
            average_ms = 0,
            samples = {},
            sample_index = 0,
            sample_count = 0,
            slow_updates = 0,
        },
    }
end

local function normalize_visual_runtime(runtime)
    local visual_queue = runtime.visual_queue
    runtime.active_visual_by_unit = {}

    if not visual_queue or not visual_queue.items then
        runtime.visual_slice_count = 0
        runtime.active_visual_jobs = 0
        return
    end

    local active_visual_jobs = 0
    local visual_slice_count = 0
    for _, job in pairs(visual_queue.items) do
        if type(job) == "table" then
            job.source = nil
            local remaining_slices = math.max(0, job.remaining_slices or 0)
            if remaining_slices > 0 then
                active_visual_jobs = active_visual_jobs + 1
                visual_slice_count = visual_slice_count + remaining_slices
                if job.source_unit_number then
                    runtime.active_visual_by_unit[job.source_unit_number] = job
                end
            end
        end
    end

    runtime.visual_slice_count = visual_slice_count
    runtime.active_visual_jobs = active_visual_jobs
    runtime.visual_runtime_normalized = true
end

local function ensure_runtime()
    storage.ei = storage.ei or {}

    if not storage.ei.severance_array or storage.ei.severance_array.version ~= RUNTIME_VERSION then
        storage.ei.severance_array = new_runtime()
    end

    local runtime = storage.ei.severance_array
    runtime.damage_queue = scheduler.ensure_queue(runtime.damage_queue)
    runtime.impact_buckets = scheduler.ensure_delayed_buckets(runtime.impact_buckets)
    runtime.visual_queue = scheduler.ensure_queue(runtime.visual_queue)
    runtime.force_cache = runtime.force_cache or {}
    if runtime.impact_effect_count == nil then
        runtime.impact_effect_count = scheduler.delayed_item_count(runtime.impact_buckets)
    end
    runtime.impact_next_due_tick = runtime.impact_next_due_tick or 0
    runtime.impact_witness_count = runtime.impact_witness_count or 0
    runtime.visual_config = runtime.visual_config or severance_array_config.resolve()
    runtime.visual_fidelity = runtime.visual_fidelity
        or runtime.visual_config.visual_fidelity
        or severance_array_config.default_fidelity
    runtime.counters = runtime.counters or new_counters()
    for key, value in pairs(new_counters()) do
        if runtime.counters[key] == nil then
            runtime.counters[key] = value
        end
    end
    runtime.timings = runtime.timings or new_runtime().timings
    runtime.last_shot_by_unit = runtime.last_shot_by_unit or {}
    runtime.last_fire_by_unit = runtime.last_fire_by_unit or {}
    runtime.last_sticker_by_unit = nil
    runtime.last_scorch_by_unit = runtime.last_scorch_by_unit or {}
    runtime.active_visual_by_unit = runtime.active_visual_by_unit or {}
    runtime.last_visual_endpoint_by_unit = runtime.last_visual_endpoint_by_unit or {}
    runtime.visual_slice_count = runtime.visual_slice_count or 0
    runtime.active_visual_jobs = runtime.active_visual_jobs or 0
    runtime.next_visual_job_id = runtime.next_visual_job_id or 0
    if not runtime.visual_runtime_normalized then
        normalize_visual_runtime(runtime)
    end

    return runtime
end

local function reset_runtime()
    storage.ei = storage.ei or {}
    storage.ei.severance_array = new_runtime()
    return storage.ei.severance_array
end

--====================================================================================================
--HELPERS
--====================================================================================================

local function get_tick(event)
    local tick = ei_lib.get_event_tick(event)
    if tick and tick > 0 then
        return tick
    end

    return game and game.tick or 0
end

local function get_perf_setting()
    return ei_lib.clamp(tonumber(ei_lib.config("max_updates_per_tick")) or 10, 1, 100)
end

local function sync_visual_config(runtime)
    if not runtime then return severance_array_config.resolve() end

    local visual_config = severance_array_config.resolve()
    runtime.visual_config = visual_config
    runtime.visual_fidelity = visual_config.visual_fidelity
    return visual_config
end

local function get_visual_config(runtime)
    if not runtime then
        return severance_array_config.resolve()
    end

    if not runtime.visual_config or not runtime.visual_fidelity then
        return sync_visual_config(runtime)
    end

    return runtime.visual_config
end

local function get_slice_count(runtime)
    return severance_array_config.get_slice_count(get_visual_config(runtime), get_perf_setting())
end

local function get_visual_job_cap(runtime)
    return severance_array_config.get_visual_job_cap(get_visual_config(runtime), get_perf_setting())
end

local function get_update_limit_cap(runtime)
    return severance_array_config.get_update_limit_cap(get_visual_config(runtime), get_perf_setting())
end

local function get_impact_witness_cap(runtime)
    return severance_array_config.get_impact_witness_cap(get_visual_config(runtime), get_perf_setting())
end

local function queue_count(queue)
    if scheduler.queue_item_count then
        return scheduler.queue_item_count(queue)
    end

    return math.max(0, (queue.last or 0) - (queue.first or 1) + 1)
end

local function shallow_position(position)
    if not position then return nil end
    return {x = position.x, y = position.y}
end

local function get_surface(surface_index)
    if not surface_index then return nil end
    return game.surfaces[surface_index]
end

local function get_force(force_index)
    if not force_index then return nil end
    return game.forces[force_index]
end

local function build_force_cache(force)
    local modifier = 0

    if force and force.valid then
        local ok, value = pcall(function()
            return force.get_ammo_damage_modifier(AMMO_DAMAGE_CATEGORY)
        end)

        if ok and ei_lib.is_valid_number(value) then
            modifier = value
        end
    end

    local multiplier = math.max(0, 1 + modifier)
    return {
        ammo_category = AMMO_DAMAGE_CATEGORY,
        laser_damage_multiplier = multiplier,
        direct_damage = BASE_DAMAGE * multiplier,
    }
end

local function sync_force_cache(runtime, force)
    if not runtime or not force or not force.valid then return nil end

    runtime.force_cache = runtime.force_cache or {}
    runtime.force_cache[force.index] = build_force_cache(force)
    runtime.counters.force_cache_refreshes = (runtime.counters.force_cache_refreshes or 0) + 1

    return runtime.force_cache[force.index]
end

local function sync_all_force_caches(runtime)
    if not game or not game.forces then return end

    runtime.force_cache = runtime.force_cache or {}
    for _, force in pairs(game.forces) do
        sync_force_cache(runtime, force)
    end
end

local function get_force_cache(runtime, force)
    if not force or not force.valid then
        return build_force_cache(nil)
    end

    runtime.force_cache = runtime.force_cache or {}
    local cache = runtime.force_cache[force.index]
    if not cache or cache.ammo_category ~= AMMO_DAMAGE_CATEGORY then
        cache = sync_force_cache(runtime, force)
    end

    return cache or build_force_cache(force)
end

local function get_shot_source(event)
    local source = ei_lib.get_valid_entity(event.source_entity)
    if source and source.name == TURRET_NAME then
        return source
    end

    local cause = ei_lib.get_valid_entity(event.cause_entity)
    if cause and cause.name == TURRET_NAME then
        return cause
    end

    return nil
end

local function vector_to(source, target)
    if not source or not target then return nil end

    local x = target.x - source.x
    local y = target.y - source.y
    local length = math.sqrt(x * x + y * y)

    if length <= 0.0001 then return nil end

    return {
        x = x / length,
        y = y / length,
    }, length
end

local function target_position_from_event(event, source)
    if event.target_position then
        return shallow_position(event.target_position)
    end

    if event.target_entity and event.target_entity.valid then
        return shallow_position(event.target_entity.position)
    end

    local direction = source.direction or defines.direction.north
    local orientation = direction / 8
    local angle = orientation * math.pi * 2 - math.pi / 2

    return {
        x = source.position.x + math.cos(angle) * RANGE,
        y = source.position.y + math.sin(angle) * RANGE,
    }
end

local function get_direct_target(event, source)
    local target = ei_lib.get_valid_entity(event.target_entity)
    if not target or target == source then return nil end
    if target.force and source.force and target.force == source.force then return nil end
    if not target.health or target.health <= 0 then return nil end
    return target
end

local function should_apply_fire_sticker(runtime, tick)
    local interval = get_visual_config(runtime).fire_sticker_global_interval or 0
    if interval > 0 and runtime.last_sticker_tick and tick - runtime.last_sticker_tick < interval then
        runtime.counters.stickers_skipped = runtime.counters.stickers_skipped + 1
        return false
    end

    runtime.last_sticker_tick = tick
    return true
end

local function apply_fire_sticker(runtime, source, target, tick)
    if not target or not source.force then return end
    if not should_apply_fire_sticker(runtime, tick) then return end

    if not target.prototype or not target.prototype.sticker_box then
        runtime.counters.stickers_rejected = runtime.counters.stickers_rejected + 1
        return
    end

    local ok, sticker = pcall(function()
        return target.surface.create_entity({
            name = FIRE_STICKER_NAME,
            position = target.position,
            force = source.force,
            source = source,
            target = target,
            cause = source,
        })
    end)

    if not ok then
        runtime.counters.stickers_rejected = runtime.counters.stickers_rejected + 1
        return
    end

    if sticker then
        runtime.counters.stickers_applied = runtime.counters.stickers_applied + 1
    else
        runtime.counters.stickers_rejected = runtime.counters.stickers_rejected + 1
    end
end

local function should_create_hit_fire(runtime, unit_number, tick)
    local visual_config = get_visual_config(runtime)
    local global_interval = visual_config.hit_fire_global_interval or 0
    if global_interval > 0 and runtime.last_fire_tick and tick - runtime.last_fire_tick < global_interval then
        runtime.counters.fires_skipped = runtime.counters.fires_skipped + 1
        return false
    end

    if unit_number then
        local unit_interval = visual_config.hit_fire_unit_interval or 0
        local last_unit_tick = runtime.last_fire_by_unit[unit_number]
        if unit_interval > 0 and last_unit_tick and tick - last_unit_tick < unit_interval then
            runtime.counters.fires_skipped = runtime.counters.fires_skipped + 1
            return false
        end

        runtime.last_fire_by_unit[unit_number] = tick
    end

    runtime.last_fire_tick = tick
    return true
end

local function create_hit_fire(runtime, source, position, unit_number, tick)
    if not source.surface or not source.force or not position then return end
    if not should_create_hit_fire(runtime, unit_number, tick) then return end

    local fire = source.surface.create_entity({
        name = HIT_FIRE_NAME,
        position = position,
        force = source.force,
    })

    if fire then
        runtime.counters.fires_created = runtime.counters.fires_created + 1
    else
        runtime.counters.fires_rejected = runtime.counters.fires_rejected + 1
    end
end

local function should_create_scorchmark(runtime, unit_number, tick)
    local visual_config = get_visual_config(runtime)
    local global_interval = visual_config.scorchmark_global_interval or 0
    if global_interval > 0 and runtime.last_scorch_tick and tick - runtime.last_scorch_tick < global_interval then
        runtime.counters.scorchmarks_skipped = runtime.counters.scorchmarks_skipped + 1
        return false
    end

    if unit_number then
        local unit_interval = visual_config.scorchmark_unit_interval or 0
        local last_unit_tick = runtime.last_scorch_by_unit[unit_number]
        if unit_interval > 0 and last_unit_tick and tick - last_unit_tick < unit_interval then
            runtime.counters.scorchmarks_skipped = runtime.counters.scorchmarks_skipped + 1
            return false
        end

        runtime.last_scorch_by_unit[unit_number] = tick
    end

    runtime.last_scorch_tick = tick
    return true
end

local function create_scorchmark(runtime, source, position, unit_number, tick)
    if not source.surface or not position then return end
    if not should_create_scorchmark(runtime, unit_number, tick) then return end

    local scorchmark = source.surface.create_entity({
        name = SCORCHMARK_NAME,
        position = position,
    })

    if scorchmark then
        runtime.counters.scorchmarks_created = runtime.counters.scorchmarks_created + 1
    else
        runtime.counters.scorchmarks_rejected = runtime.counters.scorchmarks_rejected + 1
    end
end

local function is_splash_target(source, entity, direct_target)
    if entity == direct_target or entity == source then return false end
    -- find_entities_filtered returns live LuaEntity handles; keep this hot path pcall-free.
    if not entity or entity.valid ~= true then return false end
    if not entity.health or entity.health <= 0 then return false end
    if entity.force and source.force and entity.force == source.force then return false end
    return true
end

local function apply_splash_damage(runtime, source, center_position, direct_target)
    if not source.surface or not source.force or not center_position then return end

    runtime.counters.damage_jobs = runtime.counters.damage_jobs + 1

    local force = source.force
    local victims = source.surface.find_entities_filtered({
        position = center_position,
        radius = AOE_RADIUS,
        is_military_target = true,
    })

    for index = 1, #victims do
        local entity = victims[index]
        if is_splash_target(source, entity, direct_target) then
            local applied = entity.damage(AOE_DAMAGE, force, "laser", source, source)

            if applied and applied > 0 then
                runtime.counters.damage_victims = runtime.counters.damage_victims + 1
            end
        end
    end

    runtime.counters.damage_jobs_processed = runtime.counters.damage_jobs_processed + 1
end

local function offset_position(position, offset)
    return {
        x = position.x + offset.x,
        y = position.y + offset.y,
    }
end

local function clamp_target_position(source_position, target_position)
    local axis, distance = vector_to(source_position, target_position)
    if not axis then return nil end

    local clamped_distance = math.min(distance, RANGE)
    return {
        x = source_position.x + axis.x * clamped_distance,
        y = source_position.y + axis.y * clamped_distance,
    }
end

local function lerp_position(from_position, to_position, fraction)
    return {
        x = from_position.x + (to_position.x - from_position.x) * fraction,
        y = from_position.y + (to_position.y - from_position.y) * fraction,
    }
end

local function consume_impact_witness_budget(runtime, tick)
    if runtime.impact_witness_tick ~= tick then
        runtime.impact_witness_tick = tick
        runtime.impact_witness_count = 0
    end

    local impact_witness_cap = get_impact_witness_cap(runtime)
    if impact_witness_cap and (runtime.impact_witness_count or 0) >= impact_witness_cap then
        return false
    end

    runtime.impact_witness_count = (runtime.impact_witness_count or 0) + 1
    return true
end

local function render_impact_witness(runtime, source, source_position, target_position, tick)
    if not source.surface or not source.force then return false end
    local axis = vector_to(source_position, target_position)
    if not axis then return false end
    local visual_config = get_visual_config(runtime)
    local impact_witness_length = visual_config.impact_witness_length or 1.25

    if not consume_impact_witness_budget(runtime, tick) then
        runtime.counters.impact_witnesses_dropped = runtime.counters.impact_witnesses_dropped + 1
        return false
    end

    local witness_start = {
        x = target_position.x - axis.x * impact_witness_length,
        y = target_position.y - axis.y * impact_witness_length,
    }

    local beam = source.surface.create_entity({
        name = IMPACT_BEAM_NAME,
        position = witness_start,
        source_position = witness_start,
        target_position = target_position,
        duration = visual_config.impact_witness_duration_ticks or 8,
        max_length = impact_witness_length + 1,
        force = source.force,
    })

    if beam then
        runtime.counters.impact_witnesses_rendered = runtime.counters.impact_witnesses_rendered + 1
        return true
    end

    runtime.counters.impact_witnesses_dropped = runtime.counters.impact_witnesses_dropped + 1
    return false
end

local function apply_direct_damage(runtime, source, target, force_cache, damage_count)
    damage_count = math.max(1, math.floor(tonumber(damage_count) or 1))

    if not source.force or not target then
        runtime.counters.direct_damage_rejected = runtime.counters.direct_damage_rejected + damage_count
        return false
    end

    if not ei_lib.entity_check(target)
        or not target.surface
        or target.surface ~= source.surface
        or not target.health
        or target.health <= 0
        or (target.force and target.force == source.force)
    then
        runtime.counters.direct_damage_rejected = runtime.counters.direct_damage_rejected + damage_count
        return false
    end

    local damage = (force_cache and force_cache.direct_damage or BASE_DAMAGE) * damage_count
    local applied = target.damage(damage, source.force, "laser", source, source)

    if applied and applied > 0 then
        runtime.counters.direct_damage_applied = runtime.counters.direct_damage_applied + damage_count
        runtime.counters.direct_damage_amount = runtime.counters.direct_damage_amount + (tonumber(applied) or 0)
        return true
    end

    runtime.counters.direct_damage_failed = runtime.counters.direct_damage_failed + damage_count
    return false
end

local function apply_fallback_damage(runtime, source, direct_target, damage_count)
    damage_count = math.max(1, math.floor(tonumber(damage_count) or 1))
    if not ei_lib.entity_check(source) or not source.force then
        runtime.counters.direct_damage_rejected = runtime.counters.direct_damage_rejected + damage_count
        return false
    end

    runtime.counters.impact_transactions = runtime.counters.impact_transactions + damage_count
    runtime.counters.impact_fallbacks = runtime.counters.impact_fallbacks + damage_count

    return apply_direct_damage(runtime, source, direct_target, get_force_cache(runtime, source.force), damage_count)
end

local function recalculate_impact_next_due_tick(runtime)
    local next_due_tick = 0
    local item_count = 0

    for due_tick, bucket in pairs(runtime.impact_buckets or {}) do
        if type(bucket) == "table" and next(bucket) ~= nil then
            item_count = item_count + #bucket

            local numeric_tick = tonumber(due_tick)
            if numeric_tick and (next_due_tick == 0 or numeric_tick < next_due_tick) then
                next_due_tick = numeric_tick
            end
        end
    end

    runtime.impact_effect_count = item_count
    runtime.impact_next_due_tick = next_due_tick
    return next_due_tick
end

local function get_due_impact_count(runtime, tick)
    if (runtime.impact_effect_count or 0) <= 0 then
        return 0
    end

    local due_tick = tonumber(runtime.impact_next_due_tick) or 0
    if due_tick <= 0 then
        due_tick = recalculate_impact_next_due_tick(runtime)
    end

    if due_tick > 0 and due_tick <= tick then
        return runtime.impact_effect_count or 0
    end

    return 0
end

local function apply_impact_effects(runtime, source, target_endpoint, direct_target, unit_number, tick, damage_count)
    damage_count = math.max(1, math.floor(tonumber(damage_count) or 1))

    local force_cache = get_force_cache(runtime, source.force)
    create_hit_fire(runtime, source, target_endpoint, unit_number, tick)
    create_scorchmark(runtime, source, target_endpoint, unit_number, tick)
    apply_fire_sticker(runtime, source, direct_target, tick)
    apply_direct_damage(runtime, source, direct_target, force_cache, damage_count)
    apply_splash_damage(runtime, source, target_endpoint, direct_target)
    runtime.counters.impact_effects_applied = runtime.counters.impact_effects_applied + damage_count
end

local function schedule_impact_effects(runtime, source, target_endpoint, direct_target, unit_number, tick, damage_count)
    damage_count = math.max(1, math.floor(tonumber(damage_count) or 1))

    local due_tick = tick + (get_visual_config(runtime).impact_effect_delay_ticks or 2)
    scheduler.delayed_schedule(runtime.impact_buckets, due_tick, {
        source_unit_number = ei_lib.get_entity_unit_number(source),
        target_position = shallow_position(target_endpoint),
        direct_target = direct_target,
        direct_target_unit_number = ei_lib.get_entity_unit_number(direct_target),
        unit_number = unit_number,
        created_tick = tick,
        due_tick = due_tick,
        damage_count = damage_count,
    })

    runtime.impact_effect_count = (runtime.impact_effect_count or 0) + 1

    if (runtime.impact_next_due_tick or 0) == 0 or due_tick < runtime.impact_next_due_tick then
        runtime.impact_next_due_tick = due_tick
    end

    runtime.counters.impact_effects_scheduled = runtime.counters.impact_effects_scheduled + damage_count
end

local function apply_impact_transaction(runtime, source, source_position, target_position, direct_target, unit_number, tick, damage_count)
    damage_count = math.max(1, math.floor(tonumber(damage_count) or 1))

    local target_endpoint = clamp_target_position(source_position, target_position)
    if not target_endpoint then
        runtime.counters.invalid_events = runtime.counters.invalid_events + 1
        return nil
    end

    runtime.counters.impact_transactions = runtime.counters.impact_transactions + damage_count

    local witnessed = render_impact_witness(runtime, source, source_position, target_endpoint, tick)

    if witnessed then
        schedule_impact_effects(runtime, source, target_endpoint, direct_target, unit_number, tick, damage_count)
    else
        runtime.counters.impact_fallbacks = runtime.counters.impact_fallbacks + damage_count
        apply_direct_damage(runtime, source, direct_target, get_force_cache(runtime, source.force), damage_count)
    end

    return target_endpoint
end

local function get_entity_by_unit_number(unit_number)
    unit_number = tonumber(unit_number)
    if not unit_number or not game or not game.get_entity_by_unit_number then
        return nil
    end

    local ok, entity = pcall(function()
        return game.get_entity_by_unit_number(unit_number)
    end)

    if ok then
        return ei_lib.get_valid_entity(entity)
    end

    return nil
end

local function resolve_pending_source(job)
    local source = get_entity_by_unit_number(job and job.source_unit_number)
    if source and source.name == TURRET_NAME and source.force and source.surface then
        return source
    end

    return nil
end

local function resolve_pending_target(impact)
    if not impact then return nil end

    local target = get_entity_by_unit_number(impact.direct_target_unit_number)
    if target then
        return target
    end

    return ei_lib.get_valid_entity(impact.direct_target)
end

local function apply_scheduled_impact_effects(runtime, impact, tick)
    if not impact then return false end

    local damage_count = math.max(1, math.floor(tonumber(impact.damage_count) or 1))
    local source = get_entity_by_unit_number(impact.source_unit_number)
    if not source or source.name ~= TURRET_NAME or not source.force or not source.surface then
        runtime.counters.impact_effects_expired = runtime.counters.impact_effects_expired + damage_count
        runtime.counters.direct_damage_rejected = runtime.counters.direct_damage_rejected + damage_count
        return false
    end

    local target_endpoint = clamp_target_position(shallow_position(source.position), impact.target_position)
        or impact.target_position
        or shallow_position(source.position)

    apply_impact_effects(
        runtime,
        source,
        target_endpoint,
        resolve_pending_target(impact),
        impact.unit_number,
        tick,
        damage_count
    )

    return true
end

local function refresh_final_visual_endpoint(job)
    local impact = job and job.pending_impact
    if not impact then return end

    local target = resolve_pending_target(impact)
    if not target or not target.position then return end

    local target_endpoint = clamp_target_position(job.source_position, shallow_position(target.position))
    if not target_endpoint then return end

    job.to_position = target_endpoint
    impact.target_position = shallow_position(target_endpoint)
end

local function build_pending_impact(source_position, target_position, direct_target, tick, damage_count)
    return {
        source_position = shallow_position(source_position),
        target_position = shallow_position(target_position),
        direct_target = direct_target,
        direct_target_unit_number = ei_lib.get_entity_unit_number(direct_target),
        created_tick = tick,
        damage_count = math.max(1, math.floor(tonumber(damage_count) or 1)),
    }
end

local function pending_target_matches(impact, direct_target)
    if not impact then return false end

    local target_unit_number = ei_lib.get_entity_unit_number(direct_target)
    if impact.direct_target_unit_number and target_unit_number then
        return impact.direct_target_unit_number == target_unit_number
    end

    return impact.direct_target and direct_target and impact.direct_target == direct_target
end

local function merge_pending_impact(runtime, job, direct_target, damage_count)
    local impact = job and job.pending_impact
    if not impact or not pending_target_matches(impact, direct_target) then
        return false
    end

    damage_count = math.max(1, math.floor(tonumber(damage_count) or 1))
    impact.damage_count = math.max(1, math.floor(tonumber(impact.damage_count) or 1)) + damage_count
    runtime.counters.impact_transactions_merged = runtime.counters.impact_transactions_merged + damage_count
    return true
end

local function fallback_pending_impact(runtime, job)
    local impact = job and job.pending_impact
    if not impact then return false end

    job.pending_impact = nil

    local source = resolve_pending_source(job)
    if not source then
        runtime.counters.direct_damage_rejected = runtime.counters.direct_damage_rejected + math.max(1, math.floor(tonumber(impact.damage_count) or 1))
        return false
    end

    return apply_fallback_damage(runtime, source, resolve_pending_target(impact), impact.damage_count)
end

local function apply_pending_impact(runtime, job, tick)
    local impact = job and job.pending_impact
    if not impact then return false end

    job.pending_impact = nil

    local source = resolve_pending_source(job)
    if not source then
        runtime.counters.direct_damage_rejected = runtime.counters.direct_damage_rejected + math.max(1, math.floor(tonumber(impact.damage_count) or 1))
        return false
    end

    runtime.counters.impact_transactions_delayed = runtime.counters.impact_transactions_delayed + math.max(1, math.floor(tonumber(impact.damage_count) or 1))

    return apply_impact_transaction(
        runtime,
        source,
        impact.source_position or job.source_position or shallow_position(source.position),
        impact.target_position or job.to_position,
        resolve_pending_target(impact),
        job.source_unit_number,
        tick,
        impact.damage_count
    )
end

local function profiler_to_ms(profiler)
    if not profiler then return nil end

    local text = type(profiler) == "string" and profiler or tostring(profiler)
    local value, unit = string.match(text, "([%d%.]+)%s*([mun]?s)")
    value = tonumber(value)

    if not value then return nil end
    if unit == "s" then return value * 1000 end
    if unit == "ms" then return value end
    if unit == "us" then return value / 1000 end
    if unit == "ns" then return value / 1000000 end

    return value
end

local function record_timing(runtime, ms)
    if not ms or ms < 0 then return end

    local timings = runtime.timings
    timings.last_ms = ms
    timings.max_ms = math.max(timings.max_ms or 0, ms)

    if ms > HARD_UPDATE_MS then
        timings.slow_updates = (timings.slow_updates or 0) + 1
    end

    timings.sample_index = ((timings.sample_index or 0) % TIMING_SAMPLE_LIMIT) + 1
    timings.samples[timings.sample_index] = ms
    timings.sample_count = math.min(TIMING_SAMPLE_LIMIT, (timings.sample_count or 0) + 1)

    local total = 0
    local sorted = {}
    for _, sample in pairs(timings.samples) do
        total = total + sample
        sorted[#sorted + 1] = sample
    end

    timings.average_ms = total / math.max(1, timings.sample_count)
    table.sort(sorted)
    timings.p95_ms = sorted[math.max(1, math.ceil(#sorted * 0.95))] or 0
end

local function profile_update(runtime, callback)
    if not runtime.profiling_enabled or not game.create_profiler then
        return callback()
    end

    local profiler = game.create_profiler()
    local result = callback()
    profiler:stop()
    runtime.timings.last_duration = tostring(profiler)
    if tonumber(result) and tonumber(result) > 0 then
        if runtime.qc_enabled then
            log({"", "SEVERANCE_ARRAY_PROFILE processed=", tostring(result), " pending=", tostring(severance_array.get_pending_work_count()), " elapsed=", profiler})
        end
        local elapsed_ms = profiler_to_ms(runtime.timings.last_duration)
        if elapsed_ms then
            record_timing(runtime, elapsed_ms)
        end
    end

    return result
end

--====================================================================================================
--VISUALS
--====================================================================================================

local function render_visual_slice(job)
    local surface = get_surface(job.surface_index)
    local force = get_force(job.force_index)
    if not surface or not force or not force.valid then return false end

    local fraction
    if job.slice_count <= 1 then
        fraction = 0.5
    else
        fraction = (job.next_slice - 1) / (job.slice_count - 1)
    end

    local target_position = lerp_position(job.from_position, job.to_position, fraction)
    job.current_position = target_position

    surface.create_entity({
        name = BEAM_NAME,
        position = job.eye_position,
        source_position = job.eye_position,
        target_position = target_position,
        duration = (job.visual_config and job.visual_config.beam_duration_ticks) or 14,
        max_length = RANGE + 8,
        force = force,
    })

    return true
end

local function finish_visual_job(runtime, job, expired)
    if expired then
        fallback_pending_impact(runtime, job)
    end

    runtime.visual_slice_count = math.max(0, runtime.visual_slice_count - math.max(0, job.remaining_slices or 0))
    runtime.active_visual_jobs = math.max(0, runtime.active_visual_jobs - 1)
    job.pending_impact = nil
    job.remaining_slices = 0

    local unit_number = job.source_unit_number
    if unit_number then
        if runtime.active_visual_by_unit and runtime.active_visual_by_unit[unit_number] == job then
            runtime.active_visual_by_unit[unit_number] = nil
        end

        runtime.last_visual_endpoint_by_unit = runtime.last_visual_endpoint_by_unit or {}
        runtime.last_visual_endpoint_by_unit[unit_number] = shallow_position(job.current_position or job.to_position)
    end

    if expired then
        runtime.counters.visual_jobs_expired = runtime.counters.visual_jobs_expired + 1
    end
end

local function apply_visual_slice(runtime, job, tick)
    if tick - job.created_tick > (get_visual_config(runtime).visual_job_ttl or 240) then
        finish_visual_job(runtime, job, true)
        return true
    end

    if job.remaining_slices <= 0 then
        finish_visual_job(runtime, job, false)
        return true
    end

    local final_slice = job.remaining_slices <= 1
    if final_slice then
        refresh_final_visual_endpoint(job)
    end

    local rendered = render_visual_slice(job)
    if rendered then
        runtime.counters.visual_slices_rendered = runtime.counters.visual_slices_rendered + 1
    end

    job.next_slice = job.next_slice + 1
    job.remaining_slices = job.remaining_slices - 1
    runtime.visual_slice_count = math.max(0, runtime.visual_slice_count - 1)

    if final_slice then
        apply_pending_impact(runtime, job, tick)
    end

    if job.remaining_slices > 0 then
        scheduler.queue_push(runtime.visual_queue, job)
    else
        finish_visual_job(runtime, job, false)
    end

    return true
end

local function clear_visual_jobs_for_unit(runtime, unit_number)
    if not unit_number then
        return
    end

    runtime.active_visual_by_unit[unit_number] = nil
    runtime.last_visual_endpoint_by_unit[unit_number] = nil

    if not runtime.visual_queue or not runtime.visual_queue.items then
        return
    end

    local cleared = 0
    for index, job in pairs(runtime.visual_queue.items) do
        if type(job) == "table" and job.source_unit_number == unit_number then
            runtime.visual_slice_count = math.max(0, runtime.visual_slice_count - (job.remaining_slices or 0))
            runtime.active_visual_jobs = math.max(0, runtime.active_visual_jobs - 1)
            runtime.visual_queue.items[index] = nil
            cleared = cleared + 1
        end
    end

    if cleared > 0 then
        scheduler.compact_queue(runtime.visual_queue, false)
    end
end

local function enqueue_visual_job(runtime, source, source_position, target_position, direct_target, tick)
    local unit_number = ei_lib.get_entity_unit_number(source)
    local target_endpoint = clamp_target_position(source_position, target_position)
    if not target_endpoint then
        runtime.counters.invalid_events = runtime.counters.invalid_events + 1
        return false
    end

    local visual_config = get_visual_config(runtime)
    local slice_count = get_slice_count(runtime)
    local eye_position = offset_position(source_position, VISUAL_SOURCE_OFFSET)
    local active_job = unit_number and runtime.active_visual_by_unit[unit_number] or nil

    if type(active_job) == "table" and (active_job.remaining_slices or 0) > 0 then
        local remaining_slices = math.max(1, math.floor(tonumber(active_job.remaining_slices) or 1))
        fallback_pending_impact(runtime, active_job)
        active_job.source_position = source_position
        active_job.eye_position = eye_position
        active_job.from_position = shallow_position(active_job.current_position or active_job.to_position or target_endpoint)
        active_job.to_position = target_endpoint
        active_job.force_index = source.force.index
        active_job.surface_index = source.surface.index
        active_job.visual_config = visual_config
        active_job.created_tick = tick
        active_job.slice_count = math.max(2, remaining_slices)
        active_job.next_slice = 1
        active_job.remaining_slices = remaining_slices
        active_job.pending_impact = build_pending_impact(source_position, target_endpoint, direct_target, tick, 1)
        runtime.counters.visual_jobs_retargeted = runtime.counters.visual_jobs_retargeted + 1
        return true
    elseif unit_number then
        runtime.active_visual_by_unit[unit_number] = nil
    end

    local visual_job_cap = get_visual_job_cap(runtime)
    if visual_job_cap and runtime.active_visual_jobs >= visual_job_cap then
        if unit_number then
            runtime.last_visual_endpoint_by_unit[unit_number] = shallow_position(target_endpoint)
        end
        runtime.counters.visual_jobs_dropped = runtime.counters.visual_jobs_dropped + 1
        return false
    end

    local from_position = target_endpoint
    if unit_number and runtime.last_visual_endpoint_by_unit[unit_number] then
        from_position = shallow_position(runtime.last_visual_endpoint_by_unit[unit_number])
    end

    runtime.next_visual_job_id = runtime.next_visual_job_id + 1
    runtime.active_visual_jobs = runtime.active_visual_jobs + 1
    runtime.visual_slice_count = runtime.visual_slice_count + slice_count
    runtime.counters.visual_jobs = runtime.counters.visual_jobs + 1
    runtime.counters.visual_slices = runtime.counters.visual_slices + slice_count

    scheduler.queue_push(runtime.visual_queue, {
        id = runtime.next_visual_job_id,
        source_unit_number = unit_number,
        source_position = source_position,
        eye_position = eye_position,
        from_position = from_position,
        to_position = target_endpoint,
        current_position = shallow_position(from_position),
        force_index = source.force.index,
        surface_index = source.surface.index,
        visual_config = visual_config,
        created_tick = tick,
        slice_count = slice_count,
        next_slice = 1,
        remaining_slices = slice_count,
        pending_impact = build_pending_impact(source_position, target_endpoint, direct_target, tick, 1),
    })

    if unit_number then
        runtime.active_visual_by_unit[unit_number] = runtime.visual_queue.items[runtime.visual_queue.tail]
    end

    return true
end

--====================================================================================================
--EVENTS
--====================================================================================================

function severance_array.check_global()
    local runtime = ensure_runtime()
    sync_visual_config(runtime)
    sync_all_force_caches(runtime)
end

function severance_array.reset_runtime_state()
    local runtime = reset_runtime()
    sync_visual_config(runtime)
    sync_all_force_caches(runtime)
    return severance_array.get_runtime_status()
end

function severance_array.configure_qc(config)
    local runtime = ensure_runtime()
    config = config or {}

    if config.reset then
        runtime = reset_runtime()
        sync_visual_config(runtime)
        sync_all_force_caches(runtime)
    end

    if config.profiling_enabled ~= nil then
        runtime.profiling_enabled = config.profiling_enabled and true or false
    end

    if config.qc_enabled ~= nil then
        runtime.qc_enabled = config.qc_enabled and true or false
        runtime.profiling_enabled = runtime.qc_enabled or runtime.profiling_enabled
    end

    return severance_array.get_qc_snapshot(get_tick())
end

function severance_array.on_configuration_changed()
    local runtime = ensure_runtime()
    sync_visual_config(runtime)
    sync_all_force_caches(runtime)
end

function severance_array.on_research_finished(event)
    if not event or not event.research or not event.research.force then
        return
    end

    local runtime = ensure_runtime()
    sync_force_cache(runtime, event.research.force)
end

function severance_array.on_script_trigger_effect(event)
    if event.effect_id ~= SHOT_EFFECT_ID then return end

    local runtime = ensure_runtime()
    local tick = get_tick(event)
    local source = get_shot_source(event)

    if not source or source.name ~= TURRET_NAME or not source.force or not source.surface then
        runtime.counters.invalid_events = runtime.counters.invalid_events + 1
        return
    end

    local unit_number = ei_lib.get_entity_unit_number(source)
    local trace_allowed = true
    if unit_number then
        local last_tick = runtime.last_shot_by_unit[unit_number]
        local min_shot_interval = get_visual_config(runtime).min_shot_interval or 0
        if min_shot_interval > 0 and last_tick and tick - last_tick < min_shot_interval then
            trace_allowed = false
        else
            runtime.last_shot_by_unit[unit_number] = tick
        end
    end

    local source_position = shallow_position(source.position)
    local target_position = target_position_from_event(event, source)

    if not vector_to(source_position, target_position) then
        runtime.counters.invalid_events = runtime.counters.invalid_events + 1
        return
    end

    runtime.counters.shots = runtime.counters.shots + 1

    local direct_target = get_direct_target(event, source)
    if trace_allowed then
        if enqueue_visual_job(runtime, source, source_position, target_position, direct_target, tick) then
            return
        end
    elseif unit_number then
        local active_job = runtime.active_visual_by_unit and runtime.active_visual_by_unit[unit_number] or nil
        if merge_pending_impact(runtime, active_job, direct_target, 1) then
            return
        end
    end

    apply_fallback_damage(runtime, source, direct_target, 1)
end

function severance_array.on_destroyed_entity(event)
    local entity = event and event.entity or event
    if not entity or not entity.valid or entity.name ~= TURRET_NAME then return end

    local runtime = ensure_runtime()
    local unit_number = ei_lib.get_entity_unit_number(entity)
    if unit_number then
        runtime.last_shot_by_unit[unit_number] = nil
        runtime.last_fire_by_unit[unit_number] = nil
        runtime.last_scorch_by_unit[unit_number] = nil
        clear_visual_jobs_for_unit(runtime, unit_number)
    end
end

--====================================================================================================
--UPDATER
--====================================================================================================

local function take_due_impact_bucket(runtime, tick)
    local due_tick = tonumber(runtime.impact_next_due_tick) or 0
    if due_tick <= 0 then
        due_tick = recalculate_impact_next_due_tick(runtime)
    end

    if due_tick <= 0 or due_tick > tick then
        return nil, nil
    end

    local bucket = runtime.impact_buckets[due_tick]
    runtime.impact_buckets[due_tick] = nil
    if not bucket or next(bucket) == nil then
        recalculate_impact_next_due_tick(runtime)
        return nil, nil
    end

    return due_tick, bucket
end

local function update_impact_queue(runtime, limit, tick)
    local processed = 0
    local needs_recalculate = false

    while processed < limit do
        local due_tick, bucket = take_due_impact_bucket(runtime, tick)
        if not due_tick or not bucket then break end

        local remaining = {}
        for _, impact in ipairs(bucket) do
            if processed < limit then
                apply_scheduled_impact_effects(runtime, impact, tick)
                runtime.impact_effect_count = math.max(0, (runtime.impact_effect_count or 0) - 1)
                processed = processed + 1
            else
                remaining[#remaining + 1] = impact
            end
        end

        if #remaining > 0 then
            runtime.impact_buckets[due_tick] = remaining
            runtime.impact_next_due_tick = due_tick
            break
        end

        needs_recalculate = true
    end

    if needs_recalculate then
        recalculate_impact_next_due_tick(runtime)
    end

    return processed
end

local function update_visual_queue(runtime, limit, tick)
    local processed = 0

    while processed < limit do
        local job = scheduler.queue_pop(runtime.visual_queue)
        if not job then break end

        apply_visual_slice(runtime, job, tick)
        processed = processed + 1
    end

    return processed
end

function severance_array.get_pending_work_count(event)
    local runtime = ensure_runtime()
    return (runtime.visual_slice_count or 0) + get_due_impact_count(runtime, get_tick(event))
end

function severance_array.update(limit, event)
    local runtime = ensure_runtime()
    local tick = get_tick(event)
    limit = math.max(1, tonumber(limit) or 1)
    local update_limit_cap = get_update_limit_cap(runtime)
    if update_limit_cap then
        limit = math.min(limit, update_limit_cap)
    elseif get_visual_config(runtime).drain_pending_work then
        limit = math.max(limit, severance_array.get_pending_work_count(event))
    end

    return profile_update(runtime, function()
        local pending_visual = runtime.active_visual_jobs or 0
        if pending_visual <= 0 then
            pending_visual = queue_count(runtime.visual_queue)
        end
        local pending_impacts = runtime.impact_effect_count or 0

        if pending_visual <= 0 and pending_impacts <= 0 then
            return 0
        end

        if pending_visual > 0 and pending_impacts > 0 and tick % 2 == 1 then
            local visual_budget = get_visual_config(runtime).drain_pending_work and limit or 1
            local visual_processed = update_visual_queue(runtime, visual_budget, tick)
            if visual_processed >= limit then
                return visual_processed
            end

            return visual_processed + update_impact_queue(runtime, limit - visual_processed, tick)
        end

        local processed = update_impact_queue(runtime, limit, tick)
        if processed >= limit then
            return processed
        end

        return processed + update_visual_queue(runtime, limit - processed, tick)
    end)
end

function severance_array.service_for_qc(limit, event)
    local runtime = ensure_runtime()
    runtime.profiling_enabled = true
    return severance_array.update(limit, event)
end

--====================================================================================================
--STATUS
--====================================================================================================

function severance_array.get_runtime_status()
    local runtime = ensure_runtime()
    local pending_damage = queue_count(runtime.damage_queue) + (runtime.impact_effect_count or 0)
    local pending_due = (runtime.visual_slice_count or 0) + get_due_impact_count(runtime, get_tick())
    local timings = runtime.timings
    local has_timing = (timings.sample_count or 0) > 0
    local visual_preset = severance_array_config.runtime_snapshot(get_visual_config(runtime), get_perf_setting())

    local status = {
        module = MODULE_NAME,
        visual_fidelity = visual_preset.visual_fidelity,
        visual_preset = visual_preset,
        pending = pending_damage + (runtime.visual_slice_count or 0),
        pending_due = pending_due,
        pending_damage = pending_damage,
        pending_visual_slices = runtime.visual_slice_count or 0,
        active_visual_jobs = runtime.active_visual_jobs or 0,
        last_update_ms = has_timing and timings.last_ms or nil,
        max_update_ms = has_timing and timings.max_ms or nil,
        average_update_ms = has_timing and timings.average_ms or nil,
        p95_update_ms = has_timing and timings.p95_ms or nil,
        p95_ms = has_timing and timings.p95_ms or nil,
        last_update_duration = timings.last_duration,
        sample_count = timings.sample_count or 0,
        slow_updates = timings.slow_updates or 0,
        target_update_ms = TARGET_UPDATE_MS,
        hard_update_ms = HARD_UPDATE_MS,
        update_limit_cap = visual_preset.update_limit_cap,
        impact_witness_cap = visual_preset.impact_witness_cap,
        impact_next_due_tick = runtime.impact_next_due_tick or 0,
        impact_witnesses_this_tick = runtime.impact_witness_count or 0,
    }

    scheduler.set_module_status(MODULE_NAME, status)
    return status
end

function severance_array.get_qc_snapshot()
    local runtime = ensure_runtime()
    local status = severance_array.get_runtime_status()

    status.counters = runtime.counters
    status.profiling_enabled = runtime.profiling_enabled and true or false
    status.qc_enabled = runtime.qc_enabled and true or false
    status.slice_count = status.visual_preset.visual_drag_slices
    status.damage_cap = status.visual_preset.impact_witness_cap
    status.visual_job_cap = status.visual_preset.visual_job_cap
    status.native_damage = 0
    status.scripted_base_damage = BASE_DAMAGE
    status.force_cache = runtime.force_cache
    status.ammo_damage_category = AMMO_DAMAGE_CATEGORY
    status.impact_fire = HIT_FIRE_NAME
    status.impact_scorchmark = SCORCHMARK_NAME
    status.impact_beam = IMPACT_BEAM_NAME
    status.spillover_damage = AOE_DAMAGE
    status.spillover_radius = AOE_RADIUS
    status.spillover_victim_cap = "uncapped"
    status.range = RANGE
    status.visual_beam_duration = status.visual_preset.beam_duration_ticks
    status.impact_witness_duration = status.visual_preset.impact_witness_duration_ticks
    status.impact_witness_length = status.visual_preset.impact_witness_length
    status.impact_effect_delay_ticks = status.visual_preset.impact_effect_delay_ticks
    status.impact_witness_cap = status.visual_preset.impact_witness_cap
    status.visual_drag_slices = status.visual_preset.visual_drag_slices

    return status
end

--====================================================================================================
--COMMANDS
--====================================================================================================

local function get_command_player(command)
    if not command or not command.player_index then return nil end

    local player = game.players[command.player_index]
    if player and player.valid then
        return player
    end

    return nil
end

local function command_print(command, message)
    local player = get_command_player(command)
    if player then
        player.print(message)
    else
        log("[severance-array] " .. message)
    end
end

local function count_live_turrets()
    local count = 0

    for _, surface in pairs(game.surfaces) do
        if surface and surface.valid then
            count = count + surface.count_entities_filtered({name = TURRET_NAME})
        end
    end

    return count
end

local function count_enemy_targets(entity)
    if not entity or not entity.valid or not entity.surface then return 0 end

    local ok, count = pcall(function()
        return entity.surface.count_entities_filtered({
            position = entity.position,
            radius = RANGE,
            force = "enemy",
        })
    end)

    if ok and count then
        return count
    end

    return 0
end

local function format_energy(value)
    value = tonumber(value) or 0

    if value >= 1000000000 then
        return string.format("%.2f GJ", value / 1000000000)
    end

    if value >= 1000000 then
        return string.format("%.2f MJ", value / 1000000)
    end

    if value >= 1000 then
        return string.format("%.2f kJ", value / 1000)
    end

    return tostring(math.floor(value)) .. " J"
end

local function get_entity_energy(entity)
    if not entity or not entity.valid then return 0 end

    local ok, energy = pcall(function()
        return entity.energy
    end)

    if ok and energy then
        return energy
    end

    return 0
end

function severance_array.refresh_runtime_state()
    local runtime = reset_runtime()
    sync_all_force_caches(runtime)
    runtime.counters.refreshes = runtime.counters.refreshes + 1

    return {
        turrets = count_live_turrets(),
        status = severance_array.get_runtime_status(),
    }
end

function severance_array.probe_selected_turret(command)
    local runtime = ensure_runtime()
    local player = get_command_player(command)
    local selected = player and ei_lib.get_valid_entity(player.selected) or nil

    if not selected or selected.name ~= TURRET_NAME then
        return {
            selected = false,
            turrets = count_live_turrets(),
            shots = runtime.counters.shots,
            invalid_events = runtime.counters.invalid_events,
        }
    end

    return {
        selected = true,
        unit_number = ei_lib.get_entity_unit_number(selected),
        force = selected.force and selected.force.name or "?",
        surface = selected.surface and selected.surface.name or "?",
        status = selected.status,
        energy = get_entity_energy(selected),
        enemies_in_range = count_enemy_targets(selected),
        shots = runtime.counters.shots,
        invalid_events = runtime.counters.invalid_events,
        pending_visual_slices = runtime.visual_slice_count or 0,
        active_visual_jobs = runtime.active_visual_jobs or 0,
    }
end

if commands and commands.add_command then
    commands.add_command("ei_severance_array_refresh", "Resets Severance Array runtime queues and reports live turret count.", function(command)
        local result = severance_array.refresh_runtime_state()
        command_print(command, "Severance Array runtime refreshed; live arrays: " .. tostring(result.turrets or 0) .. ".")
    end)

    commands.add_command("ei_severance_array_probe", "Reports the selected Severance Array state and nearby enemy count.", function(command)
        local result = severance_array.probe_selected_turret(command)
        if not result.selected then
            command_print(command, "No Severance Array selected. Live arrays: " .. tostring(result.turrets or 0) .. ", shots: " .. tostring(result.shots or 0) .. ", invalid events: " .. tostring(result.invalid_events or 0) .. ".")
            return
        end

        command_print(
            command,
            "Severance Array probe: unit="
                .. tostring(result.unit_number or "?")
                .. ", force=" .. tostring(result.force or "?")
                .. ", surface=" .. tostring(result.surface or "?")
                .. ", status=" .. tostring(result.status or "?")
                .. ", energy=" .. format_energy(result.energy)
                .. ", enemies_in_range=" .. tostring(result.enemies_in_range or 0)
                .. ", shots=" .. tostring(result.shots or 0)
                .. ", invalid_events=" .. tostring(result.invalid_events or 0)
                .. ", active_visual_jobs=" .. tostring(result.active_visual_jobs or 0)
                .. ", pending_visual_slices=" .. tostring(result.pending_visual_slices or 0)
                .. "."
        )
    end)
end

return severance_array
