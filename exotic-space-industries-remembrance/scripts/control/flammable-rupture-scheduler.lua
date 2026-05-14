--==============================================================================
-- ESIR FILE MAP
-- owns: queued flammable rupture ring execution and runtime status
-- loaded_by: exotic-space-industries-remembrance\control.lua, scripts/control/flammable-fluids.lua
-- cadence: every tick and on-demand job creation
-- forwarded_events: begin_rupture, check_global, get_fidelity_profile, get_runtime_status, queue_rupture, updater
-- storage_roots: storage.ei.flammable_ruptures
-- gui_ids: none
-- remote_interfaces: none
-- rebuild_on: startup setting changes, configuration changes
--==============================================================================

local ei_lib = require("lib/lib")
local ei_runtime_scheduler = require("lib/runtime-scheduler")

local model = {}

local MODULE_NAME = "flammable-ruptures"
local DEFAULT_MODE = "standard"
local GOLDEN_ANGLE = math.pi * (3 - math.sqrt(5))

local MODE_PROFILES = {
    lean = {
        ring_count = 4,
        fire_cap = 96,
        smoke_cap = 48,
        explosion_cap = 24,
        scorch_cap = 18,
        massive_cap = 0,
        secondary_threshold = 1,
        secondary_limit = 0,
        aggressive_drain = false,
    },
    standard = {
        ring_count = 6,
        fire_cap = 180,
        smoke_cap = 96,
        explosion_cap = 40,
        scorch_cap = 24,
        massive_cap = 2,
        secondary_threshold = 0.25,
        secondary_limit = 1,
        aggressive_drain = false,
    },
    cinematic = {
        ring_count = 8,
        fire_cap = 320,
        smoke_cap = 160,
        explosion_cap = 72,
        scorch_cap = 32,
        massive_cap = 6,
        secondary_threshold = 0.18,
        secondary_limit = nil,
        aggressive_drain = false,
    },
    unbounded = {
        ring_count = 8,
        dynamic_ring_count = true,
        fire_cap = nil,
        smoke_cap = nil,
        explosion_cap = nil,
        scorch_cap = nil,
        massive_cap = nil,
        secondary_threshold = 0.18,
        secondary_limit = nil,
        aggressive_drain = true,
    },
}

local function now_tick()
    return game and game.tick or 0
end

local function shallow_copy(source)
    local copy = {}
    for key, value in pairs(source or {}) do
        copy[key] = value
    end
    return copy
end

local function get_mode()
    local mode = ei_lib.config("flammable-rupture-fidelity") or DEFAULT_MODE
    if not MODE_PROFILES[mode] then
        mode = DEFAULT_MODE
    end
    return mode
end

function model.get_fidelity_profile(visual_radius)
    local mode = get_mode()
    local profile = shallow_copy(MODE_PROFILES[mode])
    if profile.dynamic_ring_count then
        profile.ring_count = math.max(profile.ring_count or 8, math.ceil((visual_radius or 0) / 8))
    end
    profile.mode = mode
    return profile
end

local function new_state()
    return {
        next_job_id = 1,
        jobs = {},
        ring_buckets = {},
        active_job_count = 0,
        pending_ring_count = 0,
        scheduled_ring_count = 0,
        scheduled_bucket_count = 0,
    }
end

local function count_pending_rings(state)
    local total = 0
    for _, job in pairs(state.jobs or {}) do
        total = total + math.max(0, (job.ring_count or 0) - ((job.next_ring or 1) - 1))
    end
    return total
end

local function refresh_cached_counts(state)
    state.active_job_count = ei_runtime_scheduler.table_count(state.jobs)
    state.pending_ring_count = count_pending_rings(state)
    state.scheduled_ring_count = ei_runtime_scheduler.delayed_item_count(state.ring_buckets)
    state.scheduled_bucket_count = ei_runtime_scheduler.delayed_bucket_count(state.ring_buckets)
end

function model.check_global()
    storage.ei = storage.ei or {}
    storage.ei.flammable_ruptures = storage.ei.flammable_ruptures or new_state()

    local state = storage.ei.flammable_ruptures
    state.next_job_id = state.next_job_id or 1
    state.jobs = state.jobs or {}
    state.ring_buckets = ei_runtime_scheduler.ensure_delayed_buckets(state.ring_buckets)
    if state.active_job_count == nil
        or state.pending_ring_count == nil
        or state.scheduled_ring_count == nil
        or state.scheduled_bucket_count == nil then
        refresh_cached_counts(state)
    end
    return state
end

local function get_state()
    return model.check_global()
end

local function register_job(state, job)
    local job_id = state.next_job_id
    state.next_job_id = job_id + 1

    job.id = job_id
    job.mode = job.mode or get_mode()
    job.next_ring = job.next_ring or 1
    job.ring_count = job.ring_count or #(job.rings or {})
    state.jobs[job_id] = job
    state.active_job_count = math.max(0, tonumber(state.active_job_count) or 0) + 1
    state.pending_ring_count = math.max(0, tonumber(state.pending_ring_count) or 0) + math.max(0, job.ring_count or 0)
    return job_id
end

local function finish_job(state, job_id)
    local job = state.jobs[job_id]
    if job then
        state.pending_ring_count = math.max(
            0,
            (tonumber(state.pending_ring_count) or 0) - math.max(0, (job.ring_count or 0) - ((job.next_ring or 1) - 1))
        )
        state.active_job_count = math.max(0, (tonumber(state.active_job_count) or 0) - 1)
        state.jobs[job_id] = nil
        ei_runtime_scheduler.bump_counter(MODULE_NAME, "jobs_completed", 1)
    end
end

local function schedule_job_ring(state, job_id, due_tick)
    local created_bucket = state.ring_buckets[due_tick] == nil
    ei_runtime_scheduler.delayed_schedule(state.ring_buckets, due_tick, job_id)
    state.scheduled_ring_count = math.max(0, tonumber(state.scheduled_ring_count) or 0) + 1
    if created_bucket then
        state.scheduled_bucket_count = math.max(0, tonumber(state.scheduled_bucket_count) or 0) + 1
    end
    ei_runtime_scheduler.bump_counter(MODULE_NAME, "rings_queued", 1)
end

local function emit_center_samples(center, count, callback)
    for _ = 1, count do
        callback({x = center.x, y = center.y})
    end
end

local function emit_vogel_samples(center, inner_radius, outer_radius, count, callback)
    if count <= 0 or outer_radius <= 0 then
        return
    end

    local clamped_inner = math.max(0, inner_radius or 0)
    local span = math.max(0, outer_radius - clamped_inner)
    local base_angle = math.random() * math.pi * 2
    local jitter_band = math.max(0.2, outer_radius / math.max(count, 1))

    for i = 1, count do
        local sample = (i - 0.5) / count
        local angle = base_angle + (i * GOLDEN_ANGLE) + ((math.random() - 0.5) * 0.35)
        local sample_radius = clamped_inner + (math.sqrt(sample) * span)
        sample_radius = math.max(clamped_inner, sample_radius + ((math.random() - 0.5) * jitter_band))
        sample_radius = math.min(outer_radius, sample_radius)

        callback({
            x = center.x + (math.cos(angle) * sample_radius),
            y = center.y + (math.sin(angle) * sample_radius),
        })
    end
end

local function emit_rim_samples(center, inner_radius, outer_radius, count, callback)
    if count <= 0 or outer_radius <= 0 then
        return
    end

    local clamped_inner = math.max(0, inner_radius or 0)
    local span = math.max(0, outer_radius - clamped_inner)
    local base_angle = math.random() * math.pi * 2
    local rim_width = math.max(0.25, span * 0.18, outer_radius * 0.12)

    for i = 1, count do
        local angle = base_angle + (i * GOLDEN_ANGLE) + ((math.random() - 0.5) * 0.6)
        local sample_radius = math.max(clamped_inner, outer_radius - (math.random() * rim_width))
        sample_radius = math.min(outer_radius, sample_radius)

        callback({
            x = center.x + (math.cos(angle) * sample_radius),
            y = center.y + (math.sin(angle) * sample_radius),
        })
    end
end

local function emit_samples(center, layer, callback)
    local emitter = layer.emitter or "center"
    if emitter == "vogel" then
        emit_vogel_samples(center, layer.inner_radius or 0, layer.outer_radius or 0, layer.count or 0, callback)
        return
    end

    if emitter == "rim" then
        emit_rim_samples(center, layer.inner_radius or 0, layer.outer_radius or 0, layer.count or 0, callback)
        return
    end

    emit_center_samples(center, layer.count or 0, callback)
end

local function spawn_entity_layers(surface, center, layers)
    for _, layer in ipairs(layers or {}) do
        if layer.name and (layer.count or 0) > 0 then
            local force = nil
            if layer.force_name and game and game.forces then
                force = game.forces[layer.force_name]
            end

            local layer_center = layer.position or center
            emit_samples(layer_center, layer, function(position)
                surface.create_entity{
                    name = layer.name,
                    position = position,
                    force = force,
                }
            end)
        end
    end
end

local function spawn_smoke_layers(surface, center, layers)
    for _, layer in ipairs(layers or {}) do
        if layer.name and (layer.count or 0) > 0 then
            local layer_center = layer.position or center
            emit_samples(layer_center, layer, function(position)
                surface.create_trivial_smoke{
                    name = layer.name,
                    position = position,
                }
            end)
        end
    end
end

local function apply_ring_damage(job, ring)
    if not ring or not ring.damage_victims or not game then
        return
    end

    local source_force = game.forces[job.source_force_name or "neutral"] or game.forces.neutral
    for _, victim_data in ipairs(ring.damage_victims) do
        local victim = victim_data.entity
        if victim and victim.valid and victim_data.damage and victim_data.damage > 0 then
            victim.damage(victim_data.damage, source_force, job.damage_type)
        end
    end
end

local function apply_platform_tile_damage(job, surface, ring)
    if not (job and job.surface_kind == "platform" and surface and surface.valid and ring and ring.platform_tile_damage) then
        return
    end

    local platform = surface.platform
    if not (platform and platform.valid) then
        return
    end

    local damaged = 0
    for _, tile_damage in ipairs(ring.platform_tile_damage) do
        if tile_damage.position and tile_damage.damage and tile_damage.damage > 0 then
            local ok = pcall(function()
                platform.damage_tile{
                    position = tile_damage.position,
                    damage = tile_damage.damage,
                }
            end)

            if not ok then
                ok = pcall(function()
                    platform.damage_tile{
                        position = tile_damage.position,
                        amount = tile_damage.damage,
                    }
                end)
            end

            if ok then
                damaged = damaged + 1
            end
        end
    end

    if damaged > 0 then
        ei_runtime_scheduler.bump_counter(MODULE_NAME, "platform_tiles_damaged", damaged)
    end
end

local function execute_ring(state, job, ring_index)
    local ring = job.rings and job.rings[ring_index]
    if not ring then
        return false
    end

    local surface = game and game.get_surface(job.surface_index) or nil
    if not (surface and surface.valid) then
        return false
    end

    for _, entity_data in ipairs(ring.center_entities or {}) do
        if entity_data.name then
            local force = nil
            if entity_data.force_name and game and game.forces then
                force = game.forces[entity_data.force_name]
            end

            surface.create_entity{
                name = entity_data.name,
                position = entity_data.position or job.position,
                force = force,
            }
        end
    end

    spawn_entity_layers(surface, job.position, ring.entity_layers)
    spawn_smoke_layers(surface, job.position, ring.smoke_layers)
    spawn_entity_layers(surface, job.position, ring.fire_layers)
    spawn_entity_layers(surface, job.position, ring.scorch_layers)
    apply_platform_tile_damage(job, surface, ring)
    apply_ring_damage(job, ring)

    state.pending_ring_count = math.max(0, (tonumber(state.pending_ring_count) or 0) - 1)
    ei_runtime_scheduler.bump_counter(MODULE_NAME, "rings_processed", 1)
    return true
end

local function process_job(state, job, current_tick, allow_aggressive_drain)
    local processed = 0

    while job.next_ring <= job.ring_count do
        if not execute_ring(state, job, job.next_ring) then
            finish_job(state, job.id)
            return
        end

        processed = processed + 1
        job.next_ring = job.next_ring + 1

        if not allow_aggressive_drain or not MODE_PROFILES[job.mode] or not MODE_PROFILES[job.mode].aggressive_drain then
            break
        end
    end

    if processed > 1 then
        ei_runtime_scheduler.bump_counter(MODULE_NAME, "aggressive_extra_rings", processed - 1)
    end

    if job.next_ring > job.ring_count then
        finish_job(state, job.id)
        return
    end

    schedule_job_ring(state, job.id, current_tick + 1)
end

function model.queue_rupture(job, due_tick)
    if not job or not job.rings or #job.rings == 0 then
        return nil
    end

    local state = get_state()
    local job_id = register_job(state, job)
    ei_runtime_scheduler.bump_counter(MODULE_NAME, "jobs_started", 1)
    schedule_job_ring(state, job_id, math.max(now_tick(), due_tick or now_tick()))
    return job_id
end

function model.begin_rupture(job, current_tick)
    if not job or not job.rings or #job.rings == 0 then
        return nil
    end

    local tick = current_tick or now_tick()
    local state = get_state()
    local job_id = register_job(state, job)
    ei_runtime_scheduler.bump_counter(MODULE_NAME, "jobs_started", 1)
    process_job(state, job, tick, false)

    for _, child_job in ipairs(job.child_jobs or {}) do
        child_job.initial_delay = child_job.initial_delay or 1
        model.queue_rupture(child_job, tick + child_job.initial_delay)
    end
    job.child_jobs = nil

    return job_id
end

function model.updater(event)
    local state = storage and storage.ei and storage.ei.flammable_ruptures
    if not state then
        return
    end

    if state.active_job_count == nil
        or state.pending_ring_count == nil
        or state.scheduled_ring_count == nil
        or state.scheduled_bucket_count == nil then
        refresh_cached_counts(state)
    end

    local due_job_ids = {}
    local due_bucket_count = 0
    for due_tick, bucket in pairs(state.ring_buckets) do
        if due_tick <= event.tick then
            state.ring_buckets[due_tick] = nil
            due_bucket_count = due_bucket_count + 1
            for _, job_id in ipairs(bucket) do
                due_job_ids[#due_job_ids + 1] = job_id
            end
        end
    end

    if #due_job_ids <= 0 then
        return
    end

    state.scheduled_ring_count = math.max(0, (state.scheduled_ring_count or 0) - #due_job_ids)
    state.scheduled_bucket_count = math.max(0, (state.scheduled_bucket_count or 0) - due_bucket_count)

    for _, job_id in ipairs(due_job_ids) do
        local job = state.jobs[job_id]
        if job then
            process_job(state, job, event.tick, true)
        end
    end
end

local function count_overdue(state, current_tick)
    local bucket_count = 0
    local item_count = 0

    for due_tick, bucket in pairs(state.ring_buckets or {}) do
        if due_tick < current_tick then
            bucket_count = bucket_count + 1
            item_count = item_count + ei_lib.count_sequence(bucket, true)
        end
    end

    return bucket_count, item_count
end

function model.get_runtime_status()
    local state = get_state()
    local tick = now_tick()
    local overdue_buckets, overdue_items = count_overdue(state, tick)
    local active_job_count = math.max(0, tonumber(state.active_job_count) or 0)
    local pending_ring_count = math.max(0, tonumber(state.pending_ring_count) or 0)
    local scheduled_bucket_count = math.max(0, tonumber(state.scheduled_bucket_count) or 0)
    local scheduled_ring_count = math.max(0, tonumber(state.scheduled_ring_count) or 0)
    local status = {
        fidelity_mode = get_mode(),
        active_jobs = active_job_count,
        pending_rings = pending_ring_count,
        ring_bucket_count = scheduled_bucket_count,
        ring_bucket_items = scheduled_ring_count,
        ring_buckets = scheduled_bucket_count,
        overdue_bucket_count = overdue_buckets,
        overdue_item_count = overdue_items,
    }

    ei_runtime_scheduler.set_module_status(MODULE_NAME, status)
    return status
end

return model
