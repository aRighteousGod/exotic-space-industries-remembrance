--==============================================================================
-- ESIR FILE MAP
-- owns: Emerald Apocalypse hover tank orbital shard visuals and autonomous
--       close-range beam-lance support
-- loaded_by: exotic-space-industries-remembrance\control.lua and
--            scripts/control/emerald-apocalypse-hover-tank.lua
-- cadence: hot visual motion is serviced every tick through control.lua;
--          cold target scans stay on the hover tank module's budgeted update fan-out
-- forwarded_events: new_state, ensure_state, ensure_counters, register_tank,
--                   remove_tank, sync_force_cache, sync_all_force_caches,
--                   get_force_cache, get_effective_damage, has_tick_work,
--                   get_pending_work_count, update, hot_update, updater, status
-- storage_roots: storage.ei.emerald_apocalypse_hover_tank.orbital_shards
-- gui_ids: none
-- remote_interfaces: none
-- rebuild_on: hover tank runtime schema changes, prototype changes, QC reset
--==============================================================================

local shards = {}

local ei_lib = require("lib/lib")
local scheduler = require("lib/runtime-scheduler")

local MODULE_NAME = "emerald-apocalypse-hover-tank"
local TANK_NAME = "ei-emerald-apocalypse-hover-tank"
local BEAM_NAME = TANK_NAME.."-orbital-shard-beam"
local SHARD_ANIMATION = TANK_NAME.."-orbital-shard"

local TAU = math.pi * 2
local atan2 = math.atan2 or function(y, x) return math.atan(y, x) end
local ORBITAL_COUNT = 3
local ORBIT_RADIUS = 5.4
local ORBIT_PERIOD_TICKS = 240
local VISUAL_UPDATE_INTERVAL = 1
-- Shard animations are kept as one LuaRenderObject per shard and retargeted on
-- the hot path. The short TTL is only a safety fuse if an update path stalls.
local VISUAL_TTL = 2
local REUSE_VISUAL_HANDLES = true
local MANUAL_VISUAL_CLEAR = VISUAL_TTL > VISUAL_UPDATE_INTERVAL and not REUSE_VISUAL_HANDLES
local ATTACK_RANGE = 36
local ATTACK_SCAN_INTERVAL = 12
local TARGET_SELECTION_LIMIT = 12
local SHARD_COOLDOWN_TICKS = 70
local DAMAGE_AMOUNT = 240
local DAMAGE_TYPE = "ei-plasma"
local TICKS_PER_SECOND = 60
local LATE_LASER_DAMAGE_TECH = "laser-weapons-damage-7"
local LATE_LASER_DAMAGE_PER_LEVEL = 0.70
local QUALITY_DAMAGE_MAX_BONUS = 1.00
local TARGETING_MODE_INDIVIDUAL = "individual"
local TARGETING_MODE_FOCUS_FIRE = "focus-fire"
local SERVICE_CAP = 24
local HOT_SERVICE_CAP = 64
local BEAM_DURATION = 12
local SHARD_RENDER_LAYER = "air-object"
local TANK_TRAVEL_FACE_SPEED = 0.015
local LINGER_TICKS = 90
local CLOSE_HALO_MIN_RADIUS = 4.6
local CLOSE_HALO_MAX_RADIUS = 7.2
local SKIRMISH_RADIUS = 6.25
local MIN_SHARD_ANGLE_SEPARATION = 0.42
local REANCHOR_DISTANCE = 18
local BEAM_MAX_LENGTH = ATTACK_RANGE + CLOSE_HALO_MAX_RADIUS + 5
local FORCE_CACHE_SCHEMA_VERSION = 3
local DEFAULT_APERTURE_TIER = 0
local SHARD_MANIFOLD_TECHS = {
    ["ei-emerald-shard-manifold-1"] = 4,
    ["ei-emerald-shard-manifold-2"] = 5,
    ["ei-emerald-shard-manifold-3"] = 6,
}
local RELOAD_LITANY_TECHS = {
    ["ei-emerald-reload-litany-1"] = 55,
    ["ei-emerald-reload-litany-2"] = 45,
    ["ei-emerald-reload-litany-3"] = 35,
}
local TARGET_VERDICT_TECH = "ei-emerald-target-verdict"
local VERDICT_APERTURE_TECHS = {
    ["ei-emerald-verdict-aperture-1"] = 1,
    ["ei-emerald-verdict-aperture-2"] = 2,
    ["ei-emerald-verdict-aperture-3"] = 3,
}
local APERTURE_PROFILES = {
    [0] = {
        tier = 0,
        beam_name = BEAM_NAME,
        beam_width = 0.42,
        corridor_radius = 0,
        impact_radius = 0,
        secondary_factor = 0,
        secondary_cap = 0,
    },
    [1] = {
        tier = 1,
        beam_name = BEAM_NAME.."-aperture-1",
        beam_width = 0.70,
        corridor_radius = 0.65,
        impact_radius = 1.10,
        secondary_factor = 0.50,
        secondary_cap = 4,
    },
    [2] = {
        tier = 2,
        beam_name = BEAM_NAME.."-aperture-2",
        beam_width = 0.95,
        corridor_radius = 0.90,
        impact_radius = 1.55,
        secondary_factor = 0.65,
        secondary_cap = 6,
    },
    [3] = {
        tier = 3,
        beam_name = BEAM_NAME.."-aperture-3",
        beam_width = 1.25,
        corridor_radius = 1.15,
        impact_radius = 2.05,
        secondary_factor = 0.80,
        secondary_cap = 8,
    },
}

local MODE_IDLE = "idle_orbit"
local MODE_SKIRMISH = "skirmish"
local MODE_LINGER = "linger"

local COUNTER_DEFAULTS = {
    shard_records_registered = 0,
    shard_records_removed = 0,
    shard_visual_cycles = 0,
    shard_visual_draws = 0,
    shard_visual_failures = 0,
    shard_scans = 0,
    shard_targets_selected = 0,
    shard_shots = 0,
    shard_beams_created = 0,
    shard_beam_failures = 0,
    shard_damage_hits = 0,
    shard_damage_failed = 0,
    shard_damage_rejected = 0,
    shard_secondary_damage_hits = 0,
    shard_invalid_purges = 0,
    shard_target_assignments = 0,
    shard_target_splits = 0,
    shard_focus_fire_assignments = 0,
    shard_spacing_adjustments = 0,
    shard_visual_clears = 0,
    shard_motion_reanchors = 0,
    shard_motion_idle_orbit = 0,
    shard_motion_skirmish = 0,
    shard_motion_linger = 0,
    shard_force_cache_refreshes = 0,
}

local HOT_COUNTERS = {
    shard_visual_cycles = true,
    shard_visual_draws = true,
    shard_visual_clears = true,
    shard_motion_reanchors = true,
    shard_motion_idle_orbit = true,
    shard_motion_skirmish = true,
    shard_motion_linger = true,
}

---@alias EmeraldApocalypseOrbitalShardMode "idle_orbit"|"skirmish"|"linger"

---@class EmeraldApocalypseOrbitalShardForceCache
---@field schema_version uint
---@field force_index uint?
---@field force_name string?
---@field tech_name string
---@field laser_7_levels uint
---@field per_level_bonus double
---@field multiplier double
---@field base_damage double
---@field shard_damage double
---@field per_shard_dps double
---@field swarm_dps double
---@field shard_count uint
---@field active_shard_count uint
---@field max_shard_count uint
---@field shard_count_override uint?
---@field targeting_mode "individual"|"focus-fire"
---@field cooldown_ticks uint
---@field target_priority boolean
---@field aperture_tier uint
---@field aperture_profile EmeraldApocalypseOrbitalShardApertureProfile
---@field representative_effective_dps double
---@field damage_type string
---@field last_refresh_tick uint

---@class EmeraldApocalypseOrbitalShardApertureProfile
---@field tier uint
---@field beam_name string
---@field beam_width double?
---@field corridor_radius double
---@field impact_radius double
---@field secondary_factor double
---@field secondary_cap uint

---@class EmeraldApocalypseOrbitalShardEffectiveDamage
---@field force_cache EmeraldApocalypseOrbitalShardForceCache
---@field force_index uint?
---@field force_name string?
---@field laser_7_levels uint
---@field laser_multiplier double
---@field quality_factor double
---@field quality_max_bonus double
---@field quality_multiplier double
---@field multiplier double
---@field base_damage double
---@field force_scaled_damage double
---@field shard_damage double
---@field per_shard_dps double
---@field swarm_dps double
---@field shard_count uint
---@field cooldown_ticks uint
---@field target_priority boolean
---@field aperture_tier uint
---@field aperture_profile EmeraldApocalypseOrbitalShardApertureProfile
---@field representative_effective_dps double
---@field damage_type string
---@field last_refresh_tick uint

---@class EmeraldApocalypseOrbitalShardMotion
---@field shard_index uint
---@field x double
---@field y double
---@field mode EmeraldApocalypseOrbitalShardMode
---@field assigned_target_unit uint?
---@field assigned_target_name string?
---@field last_target_x double?
---@field last_target_y double?
---@field linger_until_tick uint
---@field seed double
---@field last_motion_tick uint
---@field desired_angle double
---@field desired_radius double
---@field last_assignment_tick uint
---@field last_visual_orientation double?

---@class EmeraldApocalypseOrbitalShardRecord
---@field unit_number uint
---@field last_visual_tick uint
---@field next_scan_tick uint
---@field target_cursor uint
---@field active_shard_count uint
---@field shard_cooldowns table<uint, uint>
---@field shard_motion table<uint, EmeraldApocalypseOrbitalShardMotion>
---@field visual_handles table<uint, LuaRenderObject>?
---@field visual_surface_index uint?
---@field visual_force_index uint?

---@class EmeraldApocalypseOrbitalShardState
---@field records_by_unit table<uint, EmeraldApocalypseOrbitalShardRecord>
---@field update_queue table
---@field visual_queue table
---@field force_cache table<uint, EmeraldApocalypseOrbitalShardForceCache>
---@field record_count uint
---@field active_visual_count uint
---@field next_service_tick uint

local function ensure_counters(counters)
    counters = type(counters) == "table" and counters or {}
    for key, value in pairs(COUNTER_DEFAULTS) do
        if counters[key] == nil then
            counters[key] = value
        end
    end
    return counters
end

local function bump(runtime, counter_name, delta)
    delta = delta or 1
    local is_hot_counter = HOT_COUNTERS[counter_name] == true
    local qc_enabled = type(runtime) == "table" and type(runtime.qc) == "table" and runtime.qc.enabled == true
    if is_hot_counter and not qc_enabled then
        return
    end

    runtime.qc = type(runtime.qc) == "table" and runtime.qc or {}
    runtime.qc.counters = ensure_counters(runtime.qc.counters)
    runtime.qc.counters[counter_name] = (tonumber(runtime.qc.counters[counter_name]) or 0) + delta
    if qc_enabled or not is_hot_counter then
        scheduler.bump_counter(MODULE_NAME, counter_name, delta)
    end
end

function shards.new_state()
    return {
        records_by_unit = {},
        update_queue = scheduler.ensure_queue(nil),
        visual_queue = scheduler.ensure_queue(nil),
        force_cache = {},
        record_count = 0,
        active_visual_count = 0,
        next_service_tick = 0,
    }
end

function shards.ensure_state(state)
    state = type(state) == "table" and state or shards.new_state()
    state.records_by_unit = type(state.records_by_unit) == "table" and state.records_by_unit or {}
    state.update_queue = scheduler.ensure_queue(state.update_queue)
    state.visual_queue = scheduler.ensure_queue(state.visual_queue)
    state.force_cache = type(state.force_cache) == "table" and state.force_cache or {}
    local record_count = tonumber(state.record_count)
    if record_count == nil or (record_count <= 0 and next(state.records_by_unit) ~= nil) then
        record_count = scheduler.table_count(state.records_by_unit)
    end
    state.record_count = math.max(0, math.floor(record_count or 0))

    local active_visual_count = tonumber(state.active_visual_count)
    if active_visual_count == nil then
        active_visual_count = 0
        for _, record in pairs(state.records_by_unit) do
            if type(record) == "table" then
                local active_count = tonumber(record.active_shard_count)
                if active_count == nil or active_count > 0 then
                    active_visual_count = active_visual_count + 1
                end
            end
        end
    end
    state.active_visual_count = math.max(0, math.floor(active_visual_count or 0))
    state.next_service_tick = math.max(0, math.floor(tonumber(state.next_service_tick) or 0))
    return state
end

shards.ensure_counters = ensure_counters

local function queue_unit(state, unit_number)
    unit_number = tonumber(unit_number) or nil
    if not unit_number then
        return false
    end

    state.update_queue = scheduler.ensure_queue(state.update_queue)
    local pushed = scheduler.queue_push_unique(state.update_queue, unit_number, unit_number)
    return pushed == true
end

local function queue_visual_unit(state, unit_number)
    unit_number = tonumber(unit_number) or nil
    if not unit_number then
        return false
    end

    state.visual_queue = scheduler.ensure_queue(state.visual_queue)
    local pushed = scheduler.queue_push_unique(state.visual_queue, unit_number, unit_number)
    return pushed == true
end

local function queue_all_units(state)
    local queued = 0
    for unit_number in pairs(state.records_by_unit) do
        if queue_unit(state, unit_number) then
            queued = queued + 1
        end
    end
    return queued
end

local function queue_all_visual_units(state)
    local queued = 0
    for unit_number, record in pairs(state.records_by_unit) do
        local active_count = type(record) == "table" and tonumber(record.active_shard_count) or nil
        if (active_count == nil or active_count > 0 or type(record.visual_handles) == "table")
            and queue_visual_unit(state, unit_number) then
            queued = queued + 1
        end
    end
    return queued
end

local function shallow_position(position)
    if not position then
        return nil
    end

    return {
        x = position.x or position[1] or 0,
        y = position.y or position[2] or 0,
    }
end

local function get_laser_7_level_count(force)
    if not force or not force.valid then
        return 0
    end

    local ok, level_count = pcall(function()
        local technology = force.technologies and force.technologies[LATE_LASER_DAMAGE_TECH] or nil
        if not technology then
            return 0
        end

        -- For repeatable technologies, `level` is the next visible level after
        -- completed research. `researched` can be false once the next repeat is
        -- available, so the level itself is the stable completed-count source.
        return math.max(0, math.floor((tonumber(technology.level) or 7) - 7))
    end)

    if ok and ei_lib.is_valid_number(level_count) then
        return math.max(0, math.floor(level_count))
    end

    return 0
end

local function force_technology_researched(force, technology_name)
    if not force or not force.valid then
        return false
    end

    local ok, researched = pcall(function()
        local technology = force.technologies and force.technologies[technology_name] or nil
        return technology and technology.researched == true
    end)
    return ok and researched == true
end

local function resolve_shard_count(force)
    local shard_count = ORBITAL_COUNT
    for technology_name, count in pairs(SHARD_MANIFOLD_TECHS) do
        if force_technology_researched(force, technology_name) then
            shard_count = math.max(shard_count, count)
        end
    end
    return shard_count
end

local function resolve_cooldown_ticks(force)
    local cooldown_ticks = SHARD_COOLDOWN_TICKS
    for technology_name, ticks in pairs(RELOAD_LITANY_TECHS) do
        if force_technology_researched(force, technology_name) then
            cooldown_ticks = math.min(cooldown_ticks, ticks)
        end
    end
    return cooldown_ticks
end

local function resolve_aperture_tier(force)
    local aperture_tier = DEFAULT_APERTURE_TIER
    for technology_name, tier in pairs(VERDICT_APERTURE_TECHS) do
        if force_technology_researched(force, technology_name) then
            aperture_tier = math.max(aperture_tier, tier)
        end
    end
    return aperture_tier
end

local function copy_aperture_profile(aperture_tier)
    aperture_tier = ei_lib.clamp_integer(aperture_tier, 0, 3, DEFAULT_APERTURE_TIER)
    local source = APERTURE_PROFILES[aperture_tier] or APERTURE_PROFILES[DEFAULT_APERTURE_TIER]
    return {
        tier = source.tier,
        beam_name = source.beam_name,
        beam_width = source.beam_width,
        corridor_radius = source.corridor_radius,
        impact_radius = source.impact_radius,
        secondary_factor = source.secondary_factor,
        secondary_cap = source.secondary_cap,
    }
end

local function build_force_cache(force, current_tick)
    local laser_7_levels = get_laser_7_level_count(force)
    local multiplier = math.max(0, 1 + (laser_7_levels * LATE_LASER_DAMAGE_PER_LEVEL))
    local shard_damage = DAMAGE_AMOUNT * multiplier
    local shard_count = resolve_shard_count(force)
    local cooldown_ticks = resolve_cooldown_ticks(force)
    local aperture_tier = resolve_aperture_tier(force)
    local aperture_profile = copy_aperture_profile(aperture_tier)
    return {
        schema_version = FORCE_CACHE_SCHEMA_VERSION,
        force_index = force and force.valid and force.index or nil,
        force_name = force and force.valid and force.name or nil,
        tech_name = LATE_LASER_DAMAGE_TECH,
        laser_7_levels = laser_7_levels,
        per_level_bonus = LATE_LASER_DAMAGE_PER_LEVEL,
        multiplier = multiplier,
        base_damage = DAMAGE_AMOUNT,
        shard_damage = shard_damage,
        per_shard_dps = shard_damage * TICKS_PER_SECOND / cooldown_ticks,
        swarm_dps = shard_count * shard_damage * TICKS_PER_SECOND / cooldown_ticks,
        shard_count = shard_count,
        cooldown_ticks = cooldown_ticks,
        target_priority = force_technology_researched(force, TARGET_VERDICT_TECH),
        aperture_tier = aperture_tier,
        aperture_profile = aperture_profile,
        representative_effective_dps = shard_count * shard_damage * TICKS_PER_SECOND / cooldown_ticks,
        damage_type = DAMAGE_TYPE,
        last_refresh_tick = math.max(0, math.floor(tonumber(current_tick) or 0)),
    }
end

local function force_cache_is_current(cache)
    if type(cache) ~= "table" then
        return false
    end

    return tonumber(cache.schema_version) == FORCE_CACHE_SCHEMA_VERSION
        and cache.tech_name == LATE_LASER_DAMAGE_TECH
        and tonumber(cache.base_damage) == DAMAGE_AMOUNT
        and tonumber(cache.per_level_bonus) == LATE_LASER_DAMAGE_PER_LEVEL
        and type(cache.aperture_profile) == "table"
        and cache.aperture_profile.beam_name ~= nil
        and cache.target_priority ~= nil
        and cache.shard_count ~= nil
        and cache.cooldown_ticks ~= nil
end

function shards.sync_force_cache(runtime, force, current_tick)
    runtime.orbital_shards = shards.ensure_state(runtime.orbital_shards)
    local state = runtime.orbital_shards
    if not force or not force.valid then
        return build_force_cache(nil, current_tick)
    end

    local cache = build_force_cache(force, current_tick)
    state.force_cache[force.index] = cache
    bump(runtime, "shard_force_cache_refreshes", 1)
    return cache
end

function shards.sync_all_force_caches(runtime, current_tick)
    runtime.orbital_shards = shards.ensure_state(runtime.orbital_shards)
    if not game or not game.forces then
        return 0
    end

    local refreshed = 0
    for _, force in pairs(game.forces) do
        if force and force.valid then
            shards.sync_force_cache(runtime, force, current_tick)
            refreshed = refreshed + 1
        end
    end
    return refreshed
end

function shards.get_force_cache(runtime, force, current_tick)
    runtime.orbital_shards = shards.ensure_state(runtime.orbital_shards)
    if not force or not force.valid then
        return build_force_cache(nil, current_tick)
    end

    local cache = runtime.orbital_shards.force_cache[force.index]
    if force_cache_is_current(cache) then
        return cache
    end

    return shards.sync_force_cache(runtime, force, current_tick)
end

function shards.base_force_cache(current_tick)
    return build_force_cache(nil, current_tick)
end

local function clear_render_object(render_object)
    if render_object and render_object.valid then
        render_object.destroy()
        return true
    end

    return false
end

local function clear_visual_handles(runtime, record)
    if type(record) ~= "table" or type(record.visual_handles) ~= "table" then
        return 0
    end

    local cleared = 0
    for _, render_object in pairs(record.visual_handles) do
        if clear_render_object(render_object) then
            cleared = cleared + 1
        end
    end
    record.visual_handles = nil

    if cleared > 0 and runtime then
        bump(runtime, "shard_visual_clears", cleared)
    end

    record.visual_surface_index = nil
    record.visual_force_index = nil
    return cleared
end

local function clear_visual_handles_above(runtime, record, shard_count)
    if type(record) ~= "table" or type(record.visual_handles) ~= "table" then
        return 0
    end

    shard_count = math.max(0, math.floor(tonumber(shard_count) or 0))
    local cleared = 0
    for shard_index, render_object in pairs(record.visual_handles) do
        if tonumber(shard_index) and tonumber(shard_index) > shard_count then
            if clear_render_object(render_object) then
                cleared = cleared + 1
            end
            record.visual_handles[shard_index] = nil
        end
    end

    if cleared > 0 and runtime then
        bump(runtime, "shard_visual_clears", cleared)
    end

    return cleared
end

local function refresh_visual_handle(render_object, position, orientation)
    if not (render_object and render_object.valid) then
        return false
    end

    local ok = pcall(function()
        render_object.target = position
        render_object.orientation = orientation
        render_object.time_to_live = VISUAL_TTL
    end)
    return ok == true
end

local function set_record_active_count(state, record, active_count)
    active_count = math.max(0, math.floor(tonumber(active_count) or 0))
    if type(record) ~= "table" then
        return active_count
    end

    local old_count = tonumber(record.active_shard_count)
    local was_active = old_count == nil or old_count > 0
    local is_active = active_count > 0
    record.active_shard_count = active_count

    if type(state) == "table" and was_active ~= is_active then
        local current = tonumber(state.active_visual_count) or 0
        state.active_visual_count = math.max(0, math.floor(current + (is_active and 1 or -1)))
    end

    return active_count
end

local function remove_shard_record(runtime, state, unit_number, reason)
    unit_number = tonumber(unit_number) or nil
    if not unit_number or not state.records_by_unit[unit_number] then
        return false
    end

    local record = state.records_by_unit[unit_number]
    local active_count = tonumber(record.active_shard_count)
    if active_count == nil or active_count > 0 then
        state.active_visual_count = math.max(0, math.floor((tonumber(state.active_visual_count) or 0) - 1))
    end
    clear_visual_handles(runtime, record)
    state.records_by_unit[unit_number] = nil
    state.record_count = math.max(0, (tonumber(state.record_count) or 0) - 1)
    scheduler.queue_remove_value(state.update_queue, unit_number)
    scheduler.queue_remove_value(state.visual_queue, unit_number)
    bump(runtime, reason == "invalid" and "shard_invalid_purges" or "shard_records_removed", 1)
    return true
end

local function clamp(value, min_value, max_value)
    value = tonumber(value) or min_value
    if value < min_value then
        return min_value
    elseif value > max_value then
        return max_value
    end
    return value
end

local function get_tank_quality_factor(entity)
    if not ei_lib.entity_check(entity) then
        return 0
    end

    local ok, quality_factor = pcall(ei_lib.get_normalized_quality_factor, entity)
    if ok and ei_lib.is_valid_number(quality_factor) then
        return clamp(quality_factor, 0, 1)
    end

    return 0
end

local function profile_shard_count(profile)
    return math.max(1, math.floor(tonumber(profile and profile.shard_count) or ORBITAL_COUNT))
end

local function normalize_targeting_mode(mode)
    if mode == TARGETING_MODE_FOCUS_FIRE then
        return TARGETING_MODE_FOCUS_FIRE
    end
    return TARGETING_MODE_INDIVIDUAL
end

local function get_tank_settings(runtime, unit_number)
    unit_number = tonumber(unit_number) or nil
    local settings_by_unit = runtime and runtime.tank_settings_by_unit
    local settings = unit_number and type(settings_by_unit) == "table" and settings_by_unit[unit_number] or nil
    if type(settings) ~= "table" then
        return nil
    end
    return settings
end

local function resolve_tank_targeting_mode(runtime, unit_number)
    local settings = get_tank_settings(runtime, unit_number)
    return normalize_targeting_mode(settings and settings.targeting_mode)
end

local function resolve_active_shard_count(runtime, unit_number, profile)
    local max_count = profile_shard_count(profile)
    local settings = get_tank_settings(runtime, unit_number)
    local override = settings and tonumber(settings.shard_count_override) or nil
    if override == nil then
        return max_count, max_count, nil
    end

    local active_count = ei_lib.clamp_integer(override, 0, max_count, max_count)
    return active_count, max_count, active_count
end

local function resolve_entity_shard_state(runtime, entity, profile)
    return resolve_active_shard_count(runtime, ei_lib.get_entity_unit_number(entity), profile)
end

---@param runtime EmeraldApocalypseRuntime
---@param force LuaForce?
---@param entity LuaEntity?
---@param current_tick uint?
---@param force_cache EmeraldApocalypseOrbitalShardForceCache?
---@return EmeraldApocalypseOrbitalShardEffectiveDamage
function shards.get_effective_damage(runtime, force, entity, current_tick, force_cache)
    force_cache = type(force_cache) == "table"
        and force_cache
        or shards.get_force_cache(runtime, force, current_tick)

    local laser_multiplier = math.max(0, tonumber(force_cache.multiplier) or 1)
    local quality_factor = get_tank_quality_factor(entity)
    local quality_multiplier = 1 + (QUALITY_DAMAGE_MAX_BONUS * quality_factor)
    local force_scaled_damage = tonumber(force_cache.shard_damage) or DAMAGE_AMOUNT
    local shard_damage = force_scaled_damage * quality_multiplier
    local active_shard_count, max_shard_count, shard_count_override = resolve_entity_shard_state(runtime, entity, force_cache)
    local cooldown_ticks = math.max(1, math.floor(tonumber(force_cache.cooldown_ticks) or SHARD_COOLDOWN_TICKS))
    local unit_number = ei_lib.get_entity_unit_number(entity)
    local targeting_mode = resolve_tank_targeting_mode(runtime, unit_number)

    return {
        force_cache = force_cache,
        force_index = force_cache.force_index,
        force_name = force_cache.force_name,
        laser_7_levels = math.max(0, math.floor(tonumber(force_cache.laser_7_levels) or 0)),
        laser_multiplier = laser_multiplier,
        quality_factor = quality_factor,
        quality_max_bonus = QUALITY_DAMAGE_MAX_BONUS,
        quality_multiplier = quality_multiplier,
        multiplier = laser_multiplier * quality_multiplier,
        base_damage = tonumber(force_cache.base_damage) or DAMAGE_AMOUNT,
        force_scaled_damage = force_scaled_damage,
        shard_damage = shard_damage,
        per_shard_dps = shard_damage * TICKS_PER_SECOND / cooldown_ticks,
        swarm_dps = active_shard_count * shard_damage * TICKS_PER_SECOND / cooldown_ticks,
        shard_count = active_shard_count,
        active_shard_count = active_shard_count,
        max_shard_count = max_shard_count,
        shard_count_override = shard_count_override,
        targeting_mode = targeting_mode,
        cooldown_ticks = cooldown_ticks,
        target_priority = force_cache.target_priority == true,
        aperture_tier = math.max(0, math.floor(tonumber(force_cache.aperture_tier) or 0)),
        aperture_profile = type(force_cache.aperture_profile) == "table"
            and force_cache.aperture_profile
            or APERTURE_PROFILES[DEFAULT_APERTURE_TIER],
        representative_effective_dps = active_shard_count * shard_damage * TICKS_PER_SECOND / cooldown_ticks,
        damage_type = force_cache.damage_type or DAMAGE_TYPE,
        last_refresh_tick = math.max(0, math.floor(tonumber(current_tick) or tonumber(force_cache.last_refresh_tick) or 0)),
    }
end

local function normalize_angle(angle)
    angle = tonumber(angle) or 0
    return angle - (math.floor(angle / TAU) * TAU)
end

local function normalize_orientation(orientation)
    orientation = tonumber(orientation) or 0
    return orientation - math.floor(orientation)
end

local function angle_to_orientation(angle)
    -- LuaRendering orientation uses Factorio's vehicle convention: 0 north,
    -- 0.25 east. Our orbital angle math is 0 east, pi/2 south.
    return normalize_orientation((normalize_angle(angle) / TAU) + 0.25)
end

local function signed_angle_delta(from_angle, to_angle)
    local delta = normalize_angle(to_angle - from_angle + math.pi) - math.pi
    return delta
end

local function polar_position(origin, angle, radius)
    return {
        x = origin.x + math.cos(angle) * radius,
        y = origin.y + math.sin(angle) * radius,
    }
end

local function cached_force_profile(runtime, entity, current_tick)
    local state = runtime and runtime.orbital_shards or nil
    local force_index = entity and entity.force and entity.force.index or nil
    local cache = force_index and state and type(state.force_cache) == "table" and state.force_cache[force_index] or nil
    if force_cache_is_current(cache) then
        return cache
    end
    return build_force_cache(nil, current_tick)
end

local function profile_cooldown_ticks(profile)
    return math.max(1, math.floor(tonumber(profile and profile.cooldown_ticks) or SHARD_COOLDOWN_TICKS))
end

local function perfect_orbit_position(entity, current_tick, shard_index, shard_count)
    local position = entity.position
    shard_count = math.max(1, math.floor(tonumber(shard_count) or ORBITAL_COUNT))
    local phase = ((current_tick % ORBIT_PERIOD_TICKS) / ORBIT_PERIOD_TICKS)
        + ((shard_index - 1) / shard_count)
    local angle = phase * TAU
    return polar_position(position, angle, ORBIT_RADIUS), angle
end

local function angle_to_position(origin, position)
    return atan2(position.y - origin.y, position.x - origin.x)
end

local function position_to_orientation(origin, position, fallback_orientation)
    if not origin or not position then
        return normalize_orientation(fallback_orientation)
    end

    local dx = (position.x or 0) - (origin.x or 0)
    local dy = (position.y or 0) - (origin.y or 0)
    if (dx * dx) + (dy * dy) < 0.000001 then
        return normalize_orientation(fallback_orientation)
    end

    return angle_to_orientation(atan2(dy, dx))
end

local function tank_travel_orientation(entity)
    local speed = tonumber(entity.speed) or 0
    if math.abs(speed) < TANK_TRAVEL_FACE_SPEED then
        return nil
    end

    local orientation = tonumber(entity.orientation) or 0
    if speed < 0 then
        orientation = orientation + 0.5
    end
    return normalize_orientation(orientation)
end

local function deterministic_seed(unit_number, shard_index)
    local base = (tonumber(unit_number) or 1) * 0.61803398875
    return base + (shard_index * 2.39996322973)
end

local function ensure_motion_record(record, entity, current_tick, shard_index, shard_count)
    record.shard_motion = type(record.shard_motion) == "table" and record.shard_motion or {}
    local motion = record.shard_motion[shard_index]
    local fallback_position = nil
    local fallback_angle = nil
    local function get_fallback()
        if not fallback_position then
            fallback_position, fallback_angle = perfect_orbit_position(entity, current_tick, shard_index, shard_count)
        end
        return fallback_position, fallback_angle
    end

    if type(motion) ~= "table" then
        local position, angle = get_fallback()
        motion = {
            shard_index = shard_index,
            x = position.x,
            y = position.y,
            mode = MODE_IDLE,
            linger_until_tick = 0,
            seed = deterministic_seed(record.unit_number, shard_index),
            last_motion_tick = current_tick,
            desired_angle = angle,
            desired_radius = ORBIT_RADIUS,
            last_assignment_tick = 0,
        }
        record.shard_motion[shard_index] = motion
    end

    motion.shard_index = shard_index
    local motion_x = tonumber(motion.x)
    local motion_y = tonumber(motion.y)
    if motion_x == nil or motion_y == nil then
        local position = get_fallback()
        motion_x = motion_x or position.x
        motion_y = motion_y or position.y
    end
    motion.x = motion_x
    motion.y = motion_y
    if motion.mode ~= MODE_SKIRMISH and motion.mode ~= MODE_LINGER then
        motion.mode = MODE_IDLE
    end
    motion.linger_until_tick = math.max(0, math.floor(tonumber(motion.linger_until_tick) or 0))
    motion.seed = tonumber(motion.seed) or deterministic_seed(record.unit_number, shard_index)
    motion.last_motion_tick = math.max(0, math.floor(tonumber(motion.last_motion_tick) or current_tick))
    local desired_angle = tonumber(motion.desired_angle)
    if desired_angle == nil then
        local _, angle = get_fallback()
        desired_angle = angle
    end
    motion.desired_angle = normalize_angle(desired_angle)
    motion.desired_radius = clamp(motion.desired_radius or ORBIT_RADIUS, CLOSE_HALO_MIN_RADIUS, CLOSE_HALO_MAX_RADIUS)
    motion.last_assignment_tick = math.max(0, math.floor(tonumber(motion.last_assignment_tick) or 0))
    return motion
end

local function reconcile_record_shards(runtime, record, entity, current_tick, profile, shard_count)
    profile = profile or cached_force_profile(runtime, entity, current_tick)
    shard_count = shard_count ~= nil
        and math.max(0, math.floor(tonumber(shard_count) or 0))
        or resolve_active_shard_count(runtime, record and record.unit_number, profile)
    set_record_active_count(runtime and runtime.orbital_shards, record, shard_count)
    record.shard_cooldowns = type(record.shard_cooldowns) == "table" and record.shard_cooldowns or {}
    record.shard_motion = type(record.shard_motion) == "table" and record.shard_motion or {}

    if shard_count <= 0 then
        for shard_index in pairs(record.shard_cooldowns) do
            record.shard_cooldowns[shard_index] = nil
        end
        for shard_index in pairs(record.shard_motion) do
            record.shard_motion[shard_index] = nil
        end
        record.target_cursor = 0
        clear_visual_handles(runtime, record)
        return record.shard_motion
    end

    for shard_index = 1, shard_count do
        if record.shard_cooldowns[shard_index] == nil then
            record.shard_cooldowns[shard_index] = current_tick or 0
        end
        ensure_motion_record(record, entity, current_tick, shard_index, shard_count)
    end

    for shard_index in pairs(record.shard_cooldowns) do
        if tonumber(shard_index) and tonumber(shard_index) > shard_count then
            record.shard_cooldowns[shard_index] = nil
        end
    end
    for shard_index in pairs(record.shard_motion) do
        if tonumber(shard_index) and tonumber(shard_index) > shard_count then
            record.shard_motion[shard_index] = nil
        end
    end
    return record.shard_motion
end

local function relation_is_enemy(source_force, target_force)
    if not source_force or not target_force or source_force == target_force then
        return false
    end

    if target_force.name == "neutral" then
        return false
    end

    local ok_friend, friendly = pcall(function()
        return source_force.get_friend(target_force)
    end)
    if ok_friend and friendly == true then
        return false
    end

    local ok_cease_fire, cease_fire = pcall(function()
        return source_force.get_cease_fire(target_force)
    end)
    if ok_cease_fire and cease_fire == true then
        return false
    end

    return true
end

local function is_attack_target(source, target)
    if target == source then
        return false
    end
    if not ei_lib.entity_check(target) then
        return false
    end
    if not target.health or target.health <= 0 then
        return false
    end
    if target.destructible == false then
        return false
    end

    return relation_is_enemy(source.force, target.force)
end

local function is_scan_attack_target(source, target, relation_cache)
    if target == source then
        return false
    end
    if not ei_lib.entity_check(target) then
        return false
    end
    if not target.health or target.health <= 0 then
        return false
    end
    if target.destructible == false then
        return false
    end

    local target_force = target.force
    local key = target_force and (target_force.index or target_force.name) or "none"
    local relation = relation_cache[key]
    if relation == nil then
        relation = relation_is_enemy(source.force, target_force)
        relation_cache[key] = relation
    end

    return relation == true
end

local function distance_sq(a, b)
    local dx = a.x - b.x
    local dy = a.y - b.y
    return dx * dx + dy * dy
end

local function insert_nearest_target(targets, distances, target, distance)
    local count = #targets
    if count < TARGET_SELECTION_LIMIT then
        count = count + 1
        targets[count] = target
        distances[count] = distance
    elseif distance < (distances[count] or math.huge) then
        targets[count] = target
        distances[count] = distance
    else
        return false
    end

    while count > 1 and (distances[count] or math.huge) < (distances[count - 1] or math.huge) do
        targets[count], targets[count - 1] = targets[count - 1], targets[count]
        distances[count], distances[count - 1] = distances[count - 1], distances[count]
        count = count - 1
    end

    return true
end

local function target_max_health(target)
    if not target then
        return 0
    end

    local health = tonumber(target.health) or 0
    local ok, max_health = pcall(function()
        return target.prototype and target.prototype.max_health or nil
    end)
    if ok and ei_lib.is_valid_number(max_health) then
        return math.max(health, tonumber(max_health) or 0)
    end
    return health
end

local function target_threat_score(target, distance)
    local score = 0
    local target_type = target and target.type or ""
    if target_type == "unit-spawner" then
        score = score + 900
    elseif target_type == "turret" or target_type == "artillery-turret" then
        score = score + 700
    elseif target_type == "unit" then
        score = score + 500
    elseif target_type == "spider-vehicle" or target_type == "car" then
        score = score + 450
    else
        score = score + 250
    end
    local health = tonumber(target and target.health) or 0
    local max_health = target_max_health(target)
    score = score + math.min(300, max_health)
    if max_health > 0 then
        score = score + (1 - clamp(health / max_health, 0, 1)) * 180
    end

    score = score + math.max(0, 240 - (math.sqrt(tonumber(distance) or 0) * 8))
    return score
end

local function insert_threat_target(targets, distances, scores, target, distance, score)
    local count = #targets
    if count < TARGET_SELECTION_LIMIT then
        count = count + 1
        targets[count] = target
        distances[count] = distance
        scores[count] = score
    elseif score > (scores[count] or -math.huge)
        or (score == scores[count] and distance < (distances[count] or math.huge)) then
        targets[count] = target
        distances[count] = distance
        scores[count] = score
    else
        return false
    end

    while count > 1 do
        local left_score = scores[count - 1] or -math.huge
        local right_score = scores[count] or -math.huge
        local left_distance = distances[count - 1] or math.huge
        local right_distance = distances[count] or math.huge
        if right_score < left_score or (right_score == left_score and right_distance >= left_distance) then
            break
        end
        targets[count], targets[count - 1] = targets[count - 1], targets[count]
        distances[count], distances[count - 1] = distances[count - 1], distances[count]
        scores[count], scores[count - 1] = scores[count - 1], scores[count]
        count = count - 1
    end

    return true
end

local function find_targets(runtime, entity, profile)
    local position = entity.position
    local targets = {}
    local distances = {}
    local scores = {}
    local relation_cache = {}
    local rejected = 0
    local target_priority = profile and profile.target_priority == true
    local candidates = entity.surface.find_entities_filtered{
        position = position,
        radius = ATTACK_RANGE,
        is_military_target = true,
    }

    for index = 1, #candidates do
        local target = candidates[index]
        if is_scan_attack_target(entity, target, relation_cache) then
            local distance = distance_sq(target.position, position)
            if target_priority then
                insert_threat_target(targets, distances, scores, target, distance, target_threat_score(target, distance))
            else
                insert_nearest_target(targets, distances, target, distance)
            end
        else
            rejected = rejected + 1
        end
    end

    if rejected > 0 then
        bump(runtime, "shard_damage_rejected", rejected)
    end
    bump(runtime, "shard_scans", 1)
    bump(runtime, "shard_targets_selected", #targets)
    return targets
end

local function target_key(target, fallback_index)
    target = ei_lib.get_valid_entity(target)
    local unit_number = ei_lib.get_entity_unit_number(target)
    if unit_number then
        return "u:"..unit_number
    end
    return "n:"..(target and target.name or "unknown")..":"..(fallback_index or 0)
end

local function clear_target_assignments(record, current_tick)
    if type(record.shard_motion) ~= "table" then
        return
    end

    for _, motion in pairs(record.shard_motion) do
        if type(motion) == "table" then
            motion.assigned_target_unit = nil
            motion.assigned_target_name = nil
            if motion.last_target_x and motion.last_target_y and current_tick <= (motion.linger_until_tick or 0) then
                motion.mode = MODE_LINGER
            else
                motion.mode = MODE_IDLE
            end
        end
    end
end

local function enforce_shard_spacing(runtime, record, shard_count)
    local adjusted = 0
    if type(record.shard_motion) ~= "table" then
        return 0
    end

    shard_count = math.max(1, math.floor(tonumber(shard_count) or ORBITAL_COUNT))
    for _ = 1, 2 do
        for left_index = 1, shard_count - 1 do
            local left = record.shard_motion[left_index]
            for right_index = left_index + 1, shard_count do
                local right = record.shard_motion[right_index]
                if type(left) == "table" and type(right) == "table"
                    and left.mode ~= MODE_IDLE and right.mode ~= MODE_IDLE then
                    local delta = signed_angle_delta(left.desired_angle or 0, right.desired_angle or 0)
                    local distance = math.abs(delta)
                    if distance < MIN_SHARD_ANGLE_SEPARATION then
                        local direction = delta >= 0 and 1 or -1
                        local correction = (MIN_SHARD_ANGLE_SEPARATION - distance) * 0.5
                        left.desired_angle = normalize_angle((left.desired_angle or 0) - (direction * correction))
                        right.desired_angle = normalize_angle((right.desired_angle or 0) + (direction * correction))
                        adjusted = adjusted + 1
                    end
                end
            end
        end
    end

    if adjusted > 0 then
        bump(runtime, "shard_spacing_adjustments", adjusted)
    end
    return adjusted
end

local function assign_shard_targets(runtime, record, entity, targets, current_tick, profile)
    local shard_count = resolve_active_shard_count(runtime, record and record.unit_number, profile)
    local motions = reconcile_record_shards(runtime, record, entity, current_tick, profile, shard_count)
    if shard_count <= 0 then
        clear_target_assignments(record, current_tick)
        return nil
    end
    if #targets <= 0 then
        clear_target_assignments(record, current_tick)
        return nil
    end

    local assignments = {}
    local keys_by_shard = {}
    local totals_by_key = {}
    local unique_keys = {}
    local unique_count = 0
    local start_cursor = tonumber(record.target_cursor) or 0
    local targeting_mode = resolve_tank_targeting_mode(runtime, record and record.unit_number)
    local function add_assignment_key(key)
        totals_by_key[key] = (totals_by_key[key] or 0) + 1
        if not unique_keys[key] then
            unique_keys[key] = true
            unique_count = unique_count + 1
        end
    end

    if targeting_mode == TARGETING_MODE_FOCUS_FIRE then
        local target = targets[1]
        local key = target_key(target, 1)
        for shard_index = 1, shard_count do
            assignments[shard_index] = target
            keys_by_shard[shard_index] = key
            add_assignment_key(key)
        end
        bump(runtime, "shard_focus_fire_assignments", 1)
    else
        for shard_index = 1, shard_count do
            local target_index = ((start_cursor + shard_index - 1) % #targets) + 1
            local target = targets[target_index]
            local key = target_key(target, target_index)
            assignments[shard_index] = target
            keys_by_shard[shard_index] = key
            add_assignment_key(key)
        end

        record.target_cursor = (start_cursor + shard_count) % #targets
    end

    if unique_count > 1 then
        bump(runtime, "shard_target_splits", 1)
    end

    local seen_by_key = {}
    local origin = entity.position
    local assignment_count = 0
    for shard_index = 1, shard_count do
        local target = ei_lib.get_valid_entity(assignments[shard_index])
        local target_position = shallow_position(target and target.position)
        local motion = motions[shard_index]
        if target_position and type(motion) == "table" then
            local key = keys_by_shard[shard_index]
            seen_by_key[key] = (seen_by_key[key] or 0) + 1
            local group_index = seen_by_key[key]
            local group_total = totals_by_key[key] or 1
            local shared_offset = (group_index - ((group_total + 1) * 0.5)) * MIN_SHARD_ANGLE_SEPARATION
            local target_angle = angle_to_position(origin, target_position)

            motion.mode = MODE_SKIRMISH
            motion.assigned_target_unit = ei_lib.get_entity_unit_number(target)
            motion.assigned_target_name = target and target.name or nil
            motion.last_target_x = target_position.x
            motion.last_target_y = target_position.y
            motion.linger_until_tick = current_tick + LINGER_TICKS
            motion.desired_angle = normalize_angle(target_angle + shared_offset)
            motion.desired_radius = SKIRMISH_RADIUS
            motion.last_assignment_tick = current_tick
            assignment_count = assignment_count + 1
        end
    end

    if assignment_count > 0 then
        bump(runtime, "shard_target_assignments", assignment_count)
    end
    enforce_shard_spacing(runtime, record, shard_count)
    return assignments
end

local function clamp_coordinates_to_halo(origin, x, y, fallback_angle)
    local dx = x - origin.x
    local dy = y - origin.y
    local distance = math.sqrt((dx * dx) + (dy * dy))
    if distance < 0.001 then
        local anchored = polar_position(origin, fallback_angle or 0, ORBIT_RADIUS)
        return anchored.x, anchored.y
    end

    local radius = clamp(distance, CLOSE_HALO_MIN_RADIUS, CLOSE_HALO_MAX_RADIUS)
    return origin.x + (dx / distance) * radius,
        origin.y + (dy / distance) * radius
end

local function desired_motion_position(entity, motion, current_tick, shard_index, shard_count)
    local origin = entity.position
    if motion.mode == MODE_SKIRMISH and motion.last_target_x and motion.last_target_y then
        local angle_drift = math.sin((current_tick + motion.seed * 17) / 41) * 0.16
            + math.sin((current_tick + motion.seed * 31) / 89) * 0.08
        local radius_drift = math.sin((current_tick + motion.seed * 23) / 53) * 0.55
        local radius = clamp(SKIRMISH_RADIUS + radius_drift, CLOSE_HALO_MIN_RADIUS, CLOSE_HALO_MAX_RADIUS)
        motion.desired_radius = radius
        return polar_position(origin, normalize_angle((motion.desired_angle or 0) + angle_drift), radius)
    end

    if motion.mode == MODE_LINGER and motion.last_target_x and motion.last_target_y then
        local remaining = clamp(((motion.linger_until_tick or 0) - current_tick) / LINGER_TICKS, 0, 1)
        if remaining > 0 then
            local linger_angle = angle_to_position(origin, {x = motion.last_target_x, y = motion.last_target_y})
            motion.desired_angle = normalize_angle(linger_angle)
            local angle_drift = math.sin((current_tick + motion.seed * 19) / 47) * 0.24 * remaining
            local radius = clamp(ORBIT_RADIUS + math.sin((current_tick + motion.seed * 29) / 61) * 0.8 * remaining,
                CLOSE_HALO_MIN_RADIUS,
                CLOSE_HALO_MAX_RADIUS)
            motion.desired_radius = radius
            return polar_position(origin, normalize_angle(motion.desired_angle + angle_drift), radius)
        end
    end

    motion.mode = MODE_IDLE
    local position, angle = perfect_orbit_position(entity, current_tick, shard_index, shard_count)
    motion.desired_angle = normalize_angle(angle)
    motion.desired_radius = ORBIT_RADIUS
    return position
end

local function advance_shard_motion(runtime, record, entity, current_tick, profile, shard_count, motions)
    profile = profile or cached_force_profile(runtime, entity, current_tick)
    shard_count = shard_count ~= nil
        and math.max(0, math.floor(tonumber(shard_count) or 0))
        or resolve_active_shard_count(runtime, record and record.unit_number, profile)
    motions = motions or reconcile_record_shards(runtime, record, entity, current_tick, profile, shard_count)
    if shard_count <= 0 then
        return
    end

    local origin = entity.position
    local idle_count = 0
    local skirmish_count = 0
    local linger_count = 0
    local reanchor_count = 0

    for shard_index = 1, shard_count do
        local motion = motions[shard_index]
        local desired = desired_motion_position(entity, motion, current_tick, shard_index, shard_count)
        local dx = motion.x - origin.x
        local dy = motion.y - origin.y
        local distance_from_tank_sq = (dx * dx) + (dy * dy)

        if distance_from_tank_sq > (REANCHOR_DISTANCE * REANCHOR_DISTANCE) then
            motion.x = desired.x
            motion.y = desired.y
            reanchor_count = reanchor_count + 1
        elseif motion.mode == MODE_IDLE then
            motion.x = desired.x
            motion.y = desired.y
        else
            local dt = math.max(1, current_tick - (tonumber(motion.last_motion_tick) or current_tick))
            local blend = clamp(dt / 18, 0.16, 0.50)
            motion.x, motion.y = clamp_coordinates_to_halo(
                origin,
                motion.x + (desired.x - motion.x) * blend,
                motion.y + (desired.y - motion.y) * blend,
                motion.desired_angle)
        end

        motion.last_motion_tick = current_tick
        if motion.mode == MODE_SKIRMISH then
            skirmish_count = skirmish_count + 1
        elseif motion.mode == MODE_LINGER then
            linger_count = linger_count + 1
        else
            idle_count = idle_count + 1
        end
    end

    if reanchor_count > 0 then
        bump(runtime, "shard_motion_reanchors", reanchor_count)
    end
    if idle_count > 0 then
        bump(runtime, "shard_motion_idle_orbit", idle_count)
    end
    if skirmish_count > 0 then
        bump(runtime, "shard_motion_skirmish", skirmish_count)
    end
    if linger_count > 0 then
        bump(runtime, "shard_motion_linger", linger_count)
    end
end

local function shard_current_position(record, entity, current_tick, shard_index, shard_count)
    local motion = ensure_motion_record(record, entity, current_tick, shard_index, shard_count)
    return {x = motion.x, y = motion.y}, motion.desired_angle or 0
end

local function shard_visual_orientation(entity, motion, position, orbit_angle)
    local origin = entity.position
    if type(motion) == "table"
        and (motion.mode == MODE_SKIRMISH or motion.mode == MODE_LINGER)
        and motion.last_target_x
        and motion.last_target_y then
        local target_position = {x = motion.last_target_x, y = motion.last_target_y}
        local orientation = position_to_orientation(position, target_position, motion.last_visual_orientation)
        motion.last_visual_orientation = orientation
        return orientation
    end

    local travel_orientation = tank_travel_orientation(entity)
    if travel_orientation then
        if type(motion) == "table" then
            motion.last_visual_orientation = travel_orientation
        end
        return travel_orientation
    end

    local guard_orientation = position_to_orientation(origin, position, angle_to_orientation(orbit_angle or 0))
    if type(motion) == "table" then
        motion.last_visual_orientation = guard_orientation
    end
    return guard_orientation
end

local function draw_shard_visuals(runtime, record, entity, current_tick, profile, shard_count, motions)
    local drawn = 0
    local visual_handles = REUSE_VISUAL_HANDLES
        and (type(record.visual_handles) == "table" and record.visual_handles or {})
        or (MANUAL_VISUAL_CLEAR and {} or nil)
    profile = profile or cached_force_profile(runtime, entity, current_tick)
    shard_count = shard_count ~= nil
        and math.max(0, math.floor(tonumber(shard_count) or 0))
        or resolve_active_shard_count(runtime, record and record.unit_number, profile)
    motions = motions or reconcile_record_shards(runtime, record, entity, current_tick, profile, shard_count)

    local surface_index = entity.surface and entity.surface.index or nil
    local force_index = entity.force and entity.force.index or nil
    if REUSE_VISUAL_HANDLES
        and (record.visual_surface_index ~= surface_index or record.visual_force_index ~= force_index) then
        clear_visual_handles(runtime, record)
        visual_handles = {}
        record.visual_surface_index = surface_index
        record.visual_force_index = force_index
    end

    if MANUAL_VISUAL_CLEAR or record.visual_handles then
        if MANUAL_VISUAL_CLEAR then
            clear_visual_handles(runtime, record)
        elseif REUSE_VISUAL_HANDLES then
            clear_visual_handles_above(runtime, record, shard_count)
        end
    end

    if shard_count <= 0 then
        record.visual_handles = nil
        return
    end

    for shard_index = 1, shard_count do
        local motion = motions[shard_index]
        if type(motion) ~= "table" then
            motion = ensure_motion_record(record, entity, current_tick, shard_index, shard_count)
        end
        local position = {x = motion.x, y = motion.y}
        local orientation = shard_visual_orientation(entity, motion, position, motion.desired_angle or 0)

        local handle = visual_handles and visual_handles[shard_index] or nil
        if REUSE_VISUAL_HANDLES and refresh_visual_handle(handle, position, orientation) then
            drawn = drawn + 1
        else
            if handle then
                clear_render_object(handle)
                visual_handles[shard_index] = nil
            end

            local ok_animation, animation = pcall(function()
                return rendering.draw_animation{
                    animation = SHARD_ANIMATION,
                    target = position,
                    surface = entity.surface,
                    render_layer = SHARD_RENDER_LAYER,
                    orientation = orientation,
                    animation_speed = 1,
                    time_to_live = VISUAL_TTL,
                    forces = {entity.force},
                }
            end)
            if ok_animation and animation then
                if visual_handles then
                    visual_handles[shard_index] = animation
                end
                drawn = drawn + 1
            end
        end
    end

    if drawn > 0 then
        record.visual_handles = visual_handles
        record.visual_surface_index = surface_index
        record.visual_force_index = force_index
        bump(runtime, "shard_visual_draws", drawn)
    else
        record.visual_handles = nil
        bump(runtime, "shard_visual_failures", 1)
    end
end

local function create_beam(runtime, entity, from_position, target_position, aperture_profile)
    aperture_profile = type(aperture_profile) == "table" and aperture_profile or APERTURE_PROFILES[DEFAULT_APERTURE_TIER]
    local ok, beam = pcall(function()
        return entity.surface.create_entity{
            name = aperture_profile.beam_name or BEAM_NAME,
            position = from_position,
            source_position = from_position,
            target_position = target_position,
            duration = BEAM_DURATION,
            max_length = BEAM_MAX_LENGTH,
            force = entity.force,
        }
    end)

    if ok and beam then
        bump(runtime, "shard_beams_created", 1)
        return true
    end

    bump(runtime, "shard_beam_failures", 1)
    return false
end

local function apply_damage(runtime, entity, target, effective_damage, damage_amount)
    if not is_attack_target(entity, target) then
        bump(runtime, "shard_damage_rejected", 1)
        return false
    end

    effective_damage = type(effective_damage) == "table"
        and effective_damage
        or shards.get_effective_damage(runtime, entity.force, entity)
    damage_amount = tonumber(damage_amount) or tonumber(effective_damage.shard_damage) or DAMAGE_AMOUNT
    local ok, applied = pcall(function()
        return target.damage(damage_amount, entity.force, effective_damage.damage_type or DAMAGE_TYPE, entity)
    end)

    if ok and (applied == nil or applied == true or (type(applied) == "number" and applied > 0)) then
        bump(runtime, "shard_damage_hits", 1)
        return true
    end

    bump(runtime, "shard_damage_failed", 1)
    return false
end

local function point_segment_distance_sq(point, start_position, end_position)
    local px = point.x or 0
    local py = point.y or 0
    local ax = start_position.x or 0
    local ay = start_position.y or 0
    local bx = end_position.x or 0
    local by = end_position.y or 0
    local abx = bx - ax
    local aby = by - ay
    local length_sq = (abx * abx) + (aby * aby)
    if length_sq <= 0.000001 then
        return distance_sq(point, start_position)
    end

    local t = ((px - ax) * abx + (py - ay) * aby) / length_sq
    t = clamp(t, 0, 1)
    local cx = ax + abx * t
    local cy = ay + aby * t
    local dx = px - cx
    local dy = py - cy
    return (dx * dx) + (dy * dy)
end

local function secondary_key(target, fallback_index)
    target = ei_lib.get_valid_entity(target)
    if not target then
        return "invalid:"..tostring(fallback_index or 0)
    end

    local unit_number = ei_lib.get_entity_unit_number(target)
    if unit_number then
        return "u:"..unit_number
    end

    local ok_details, name, position = pcall(function()
        return target.name, target.position
    end)
    if not ok_details then
        return "invalid:"..tostring(fallback_index or 0)
    end

    return "p:"..(name or "unknown")..":"..
        tostring(position and position.x or 0)..":"..tostring(position and position.y or 0)..":"..tostring(fallback_index or 0)
end

local function collect_secondary_targets(entity, primary_target, from_position, target_position, aperture_profile)
    entity = ei_lib.get_valid_entity(entity)
    if not entity then
        return {}
    end

    if type(aperture_profile) ~= "table" or (tonumber(aperture_profile.tier) or 0) <= 0 then
        return {}
    end

    local cap = math.max(0, math.floor(tonumber(aperture_profile.secondary_cap) or 0))
    if cap <= 0 then
        return {}
    end

    local relation_cache = {}
    local seen = {}
    local secondaries = {}
    local primary_key = secondary_key(primary_target, "primary")
    seen[primary_key] = true
    local function try_add(target, fallback_index, corridor_radius)
        if #secondaries >= cap or not is_scan_attack_target(entity, target, relation_cache) then
            return
        end
        local key = secondary_key(target, fallback_index)
        if seen[key] then
            return
        end
        local position = shallow_position(target.position)
        if not position then
            return
        end
        if corridor_radius
            and point_segment_distance_sq(position, from_position, target_position) > corridor_radius * corridor_radius then
            return
        end
        seen[key] = true
        secondaries[#secondaries + 1] = target
    end

    local impact_radius = tonumber(aperture_profile.impact_radius) or 0
    if impact_radius > 0 then
        local candidates = entity.surface.find_entities_filtered{
            position = target_position,
            radius = impact_radius,
            is_military_target = true,
        }
        for index = 1, #candidates do
            local target = candidates[index]
            try_add(target, index, nil)
            if #secondaries >= cap then
                return secondaries
            end
        end
    end

    local corridor_radius = tonumber(aperture_profile.corridor_radius) or 0
    if corridor_radius > 0 then
        local left = math.min(from_position.x, target_position.x) - corridor_radius
        local right = math.max(from_position.x, target_position.x) + corridor_radius
        local top = math.min(from_position.y, target_position.y) - corridor_radius
        local bottom = math.max(from_position.y, target_position.y) + corridor_radius
        local candidates = entity.surface.find_entities_filtered{
            area = {{left, top}, {right, bottom}},
            is_military_target = true,
        }
        for index = 1, #candidates do
            local target = candidates[index]
            try_add(target, index, corridor_radius)
            if #secondaries >= cap then
                break
            end
        end
    end

    return secondaries
end

local function apply_secondary_damage(runtime, entity, primary_target, from_position, target_position, effective_damage)
    local aperture_profile = effective_damage and effective_damage.aperture_profile or nil
    if type(aperture_profile) ~= "table" or (tonumber(aperture_profile.tier) or 0) <= 0 then
        return 0
    end

    local secondaries = collect_secondary_targets(entity, primary_target, from_position, target_position, aperture_profile)
    local secondary_damage = (tonumber(effective_damage.shard_damage) or DAMAGE_AMOUNT)
        * (tonumber(aperture_profile.secondary_factor) or 0)
    local hits = 0
    for index = 1, #secondaries do
        local target = secondaries[index]
        if apply_damage(runtime, entity, target, effective_damage, secondary_damage) then
            bump(runtime, "shard_secondary_damage_hits", 1)
            hits = hits + 1
        end
    end
    return hits
end

local function fire_ready_shards(runtime, record, entity, assigned_targets, current_tick, force_cache)
    if type(assigned_targets) ~= "table" then
        return 0
    end

    local fired = 0
    record.shard_cooldowns = type(record.shard_cooldowns) == "table" and record.shard_cooldowns or {}
    local effective_damage = shards.get_effective_damage(runtime, entity.force, entity, current_tick, force_cache)
    local shard_count = math.max(0, math.floor(tonumber(effective_damage.active_shard_count or effective_damage.shard_count) or 0))
    if shard_count <= 0 then
        return 0
    end
    local cooldown_ticks = profile_cooldown_ticks(effective_damage)
    local aperture_profile = effective_damage.aperture_profile

    for shard_index = 1, shard_count do
        local cooldown_until = tonumber(record.shard_cooldowns[shard_index]) or 0
        if current_tick >= cooldown_until then
            -- A previous shard can destroy a shared target during this same firing loop.
            local target = ei_lib.get_valid_entity(assigned_targets[shard_index])
            local target_position = shallow_position(target and target.position)
            if target_position then
                local shard_position = shard_current_position(record, entity, current_tick, shard_index, shard_count)
                create_beam(runtime, entity, shard_position, target_position, aperture_profile)
                apply_damage(runtime, entity, target, effective_damage)
                apply_secondary_damage(runtime, entity, target, shard_position, target_position, effective_damage)
                record.shard_cooldowns[shard_index] = current_tick + cooldown_ticks
                bump(runtime, "shard_shots", 1)
                fired = fired + 1
            else
                bump(runtime, "shard_damage_rejected", 1)
            end
        end
    end

    return fired
end

function shards.register_tank(runtime, tank_record, entity, current_tick)
    runtime.orbital_shards = shards.ensure_state(runtime.orbital_shards)
    local state = runtime.orbital_shards
    local unit_number = tank_record and tank_record.unit_number or ei_lib.get_entity_unit_number(entity)
    if not unit_number then
        return nil
    end

    local record = state.records_by_unit[unit_number]
    if not record then
        record = {
            unit_number = unit_number,
            last_visual_tick = 0,
            next_scan_tick = current_tick or 0,
            target_cursor = 0,
            active_shard_count = 0,
            shard_cooldowns = {},
            shard_motion = {},
        }
        state.records_by_unit[unit_number] = record
        state.record_count = (tonumber(state.record_count) or 0) + 1
        bump(runtime, "shard_records_registered", 1)
    end

    if ei_lib.entity_check(entity) then
        reconcile_record_shards(runtime, record, entity, current_tick or 0, cached_force_profile(runtime, entity, current_tick or 0))
    end
    queue_unit(state, unit_number)
    queue_visual_unit(state, unit_number)
    return record
end

function shards.remove_tank(runtime, unit_number)
    runtime.orbital_shards = shards.ensure_state(runtime.orbital_shards)
    local state = runtime.orbital_shards
    return remove_shard_record(runtime, state, unit_number, "removed")
end

function shards.get_pending_work_count(runtime, current_tick)
    runtime.orbital_shards = shards.ensure_state(runtime.orbital_shards)
    local state = runtime.orbital_shards
    local tracked = state.record_count or 0
    if tracked <= 0 then
        return 0
    end

    local queued = scheduler.queue_item_count(state.update_queue)
    if queued > 0 then
        return queued
    end

    if current_tick >= (state.next_service_tick or 0) then
        return tracked
    end

    return 0
end

local function service_targeting_unit(runtime, state, unit_number, current_tick)
    local shard_record = state.records_by_unit[unit_number]
    local tank_record = runtime.tanks_by_unit and runtime.tanks_by_unit[unit_number] or nil
    local entity = ei_lib.get_valid_entity(tank_record and tank_record.entity)

    if not shard_record or not entity or entity.name ~= TANK_NAME then
        remove_shard_record(runtime, state, unit_number, "invalid")
        return true
    end

    local force_cache = shards.get_force_cache(runtime, entity.force, current_tick)
    local active_shard_count = resolve_active_shard_count(runtime, unit_number, force_cache)
    reconcile_record_shards(runtime, shard_record, entity, current_tick, force_cache, active_shard_count)
    if active_shard_count <= 0 then
        clear_target_assignments(shard_record, current_tick)
        shard_record.next_scan_tick = current_tick + ATTACK_SCAN_INTERVAL
        return true
    end
    if current_tick < (tonumber(shard_record.next_scan_tick) or 0) then
        return true
    end

    local targets = find_targets(runtime, entity, force_cache)
    local assigned_targets = assign_shard_targets(runtime, shard_record, entity, targets, current_tick, force_cache)
    shard_record.next_scan_tick = current_tick + ATTACK_SCAN_INTERVAL
    if assigned_targets then
        fire_ready_shards(runtime, shard_record, entity, assigned_targets, current_tick, force_cache)
    end
    return true
end

function shards.update(runtime, current_tick, limit)
    runtime.orbital_shards = shards.ensure_state(runtime.orbital_shards)
    local state = runtime.orbital_shards
    local tracked = state.record_count or 0
    if tracked <= 0 then
        state.update_queue = scheduler.clear_queue(state.update_queue)
        state.next_service_tick = current_tick + ATTACK_SCAN_INTERVAL
        return 0
    end

    if next(state.update_queue.queued) == nil then
        if current_tick < (state.next_service_tick or 0) then
            return 0
        end
        queue_all_units(state)
    end

    limit = math.max(1, math.floor(tonumber(limit) or SERVICE_CAP))
    local serviced = 0
    for _ = 1, math.min(limit, tracked) do
        local unit_number = scheduler.queue_pop_queued(state.update_queue)
        if not unit_number then
            break
        end
        if service_targeting_unit(runtime, state, unit_number, current_tick) then
            serviced = serviced + 1
        end
    end

    if next(state.update_queue.queued) == nil then
        state.next_service_tick = current_tick + ATTACK_SCAN_INTERVAL
    end

    return serviced
end

local function service_visual_unit(runtime, state, unit_number, current_tick)
    local shard_record = state.records_by_unit[unit_number]
    local tank_record = runtime.tanks_by_unit and runtime.tanks_by_unit[unit_number] or nil
    local entity = ei_lib.get_valid_entity(tank_record and tank_record.entity)

    if not shard_record or not entity or entity.name ~= TANK_NAME then
        remove_shard_record(runtime, state, unit_number, "invalid")
        return true, 0
    end

    local profile = cached_force_profile(runtime, entity, current_tick)
    local active_count = resolve_active_shard_count(runtime, unit_number, profile)
    local motions = reconcile_record_shards(runtime, shard_record, entity, current_tick, profile, active_count)
    if active_count <= 0 then
        return true, 0
    end

    advance_shard_motion(runtime, shard_record, entity, current_tick, profile, active_count, motions)

    if current_tick - (tonumber(shard_record.last_visual_tick) or 0) >= VISUAL_UPDATE_INTERVAL then
        draw_shard_visuals(runtime, shard_record, entity, current_tick, profile, active_count, motions)
        shard_record.last_visual_tick = current_tick
        bump(runtime, "shard_visual_cycles", 1)
    end

    return true, active_count
end

local resolve_tick

function shards.hot_update(runtime, event_or_tick, limit)
    local current_tick = resolve_tick(event_or_tick)
    runtime.orbital_shards = shards.ensure_state(runtime.orbital_shards)
    local state = runtime.orbital_shards
    local tracked = state.record_count or 0
    if tracked <= 0 then
        state.visual_queue = scheduler.clear_queue(state.visual_queue)
        return 0
    end

    if next(state.visual_queue.queued) == nil then
        if (tonumber(state.active_visual_count) or 0) <= 0 then
            return 0
        end
        queue_all_visual_units(state)
    end

    limit = math.max(1, math.floor(tonumber(limit) or HOT_SERVICE_CAP))
    local serviced = 0
    for _ = 1, math.min(limit, tracked) do
        local unit_number = scheduler.queue_pop_queued(state.visual_queue)
        if not unit_number then
            break
        end
        local ok, active_count = service_visual_unit(runtime, state, unit_number, current_tick)
        if ok then
            serviced = serviced + 1
        end
        local record = state.records_by_unit[unit_number]
        if record then
            active_count = tonumber(active_count) or tonumber(record.active_shard_count) or 0
            if active_count > 0 or record.visual_handles then
                queue_visual_unit(state, unit_number)
            end
        end
    end

    return serviced
end

function resolve_tick(event_or_tick)
    if type(event_or_tick) == "table" then
        return math.max(0, math.floor(tonumber(event_or_tick.tick) or 0))
    end
    return math.max(0, math.floor(tonumber(event_or_tick) or 0))
end

local function get_hover_tank_runtime()
    if not storage or type(storage.ei) ~= "table" then
        return nil
    end

    local runtime = storage.ei.emerald_apocalypse_hover_tank
    if type(runtime) ~= "table" then
        return nil
    end

    return runtime
end

function shards.has_tick_work(_event)
    local runtime = get_hover_tank_runtime()
    local state = runtime and runtime.orbital_shards or nil
    if type(state) ~= "table" then
        return false
    end
    if state.active_visual_count == nil
        or type(state.visual_queue) ~= "table"
        or type(state.visual_queue.queued) ~= "table" then
        runtime.orbital_shards = shards.ensure_state(state)
        state = runtime.orbital_shards
    end

    local visual_queue = state.visual_queue
    if type(visual_queue) == "table"
        and type(visual_queue.queued) == "table"
        and next(visual_queue.queued) ~= nil then
        return true
    end

    return (tonumber(state.active_visual_count) or 0) > 0
end

function shards.updater(event)
    local runtime = get_hover_tank_runtime()
    if not runtime then
        return false
    end

    local state = runtime.orbital_shards
    if type(state) ~= "table" then
        return false
    end
    local records_by_unit = state.records_by_unit
    if (state.record_count or 0) == 0
        and (type(records_by_unit) ~= "table" or next(records_by_unit) == nil) then
        return false
    end

    return shards.hot_update(runtime, event) > 0
end

local function count_motion_modes(runtime, state, status_cache)
    local counts = {
        idle_orbit = 0,
        skirmish = 0,
        linger = 0,
    }

    for unit_number, record in pairs(state.records_by_unit) do
        local shard_count = resolve_active_shard_count(runtime, unit_number, status_cache)
        if type(record) == "table" and type(record.shard_motion) == "table" then
            for shard_index = 1, shard_count do
                local motion = record.shard_motion[shard_index]
                local mode = type(motion) == "table" and motion.mode or MODE_IDLE
                if mode == MODE_SKIRMISH then
                    counts.skirmish = counts.skirmish + 1
                elseif mode == MODE_LINGER then
                    counts.linger = counts.linger + 1
                else
                    counts.idle_orbit = counts.idle_orbit + 1
                end
            end
        else
            counts.idle_orbit = counts.idle_orbit + shard_count
        end
    end

    return counts
end

local function summarize_tank_settings(runtime, status_cache)
    local settings_by_unit = runtime and runtime.tank_settings_by_unit
    local tank_records = runtime and runtime.tanks_by_unit
    local settings_count = 0
    local override_count = 0
    local disabled_count = 0
    local focus_fire_count = 0

    if type(tank_records) ~= "table" then
        return settings_count, override_count, disabled_count, focus_fire_count
    end

    for unit_number in pairs(tank_records) do
        local settings = type(settings_by_unit) == "table" and settings_by_unit[unit_number] or nil
        if type(settings) == "table" then
            settings_count = settings_count + 1
            if settings.shard_count_override ~= nil then
                override_count = override_count + 1
            end
            local active_count = resolve_active_shard_count(runtime, unit_number, status_cache)
            if active_count <= 0 then
                disabled_count = disabled_count + 1
            end
            if normalize_targeting_mode(settings.targeting_mode) == TARGETING_MODE_FOCUS_FIRE then
                focus_fire_count = focus_fire_count + 1
            end
        end
    end

    return settings_count, override_count, disabled_count, focus_fire_count
end

local function pick_status_force_cache(state)
    local player_force = game and game.forces and game.forces.player or nil
    if player_force and player_force.valid then
        local cache = state.force_cache[player_force.index]
        if type(cache) == "table" then
            return cache
        end
    end

    for _, cache in pairs(state.force_cache) do
        if type(cache) == "table" then
            return cache
        end
    end

    return build_force_cache(nil, 0)
end

function shards.status(runtime, representative_entity)
    runtime.orbital_shards = shards.ensure_state(runtime.orbital_shards)
    local state = runtime.orbital_shards
    local base_cache = build_force_cache(nil, 0)
    local status_cache = pick_status_force_cache(state)
    local representative_effective = nil
    if ei_lib.entity_check(representative_entity) then
        representative_effective = shards.get_effective_damage(
            runtime,
            representative_entity.force,
            representative_entity)
    end
    local settings_count, override_count, disabled_count, focus_fire_count =
        summarize_tank_settings(runtime, status_cache)

    return {
        shard_records = scheduler.table_count(state.records_by_unit),
        shard_active_visual_records = state.active_visual_count or 0,
        shard_update_queue_items = scheduler.queue_item_count(state.update_queue),
        shard_update_queue_unique = scheduler.table_count(state.update_queue.queued),
        shard_visual_queue_items = scheduler.queue_item_count(state.visual_queue),
        shard_visual_queue_unique = scheduler.table_count(state.visual_queue.queued),
        shard_next_service_tick = state.next_service_tick,
        shard_orbital_count = status_cache.shard_count,
        shard_base_orbital_count = ORBITAL_COUNT,
        shard_attack_range = ATTACK_RANGE,
        shard_scan_interval = ATTACK_SCAN_INTERVAL,
        shard_visual_update_interval = VISUAL_UPDATE_INTERVAL,
        shard_visual_ttl = VISUAL_TTL,
        shard_cooldown_ticks = status_cache.cooldown_ticks,
        shard_base_cooldown_ticks = SHARD_COOLDOWN_TICKS,
        shard_hot_service_cap = HOT_SERVICE_CAP,
        shard_damage = DAMAGE_AMOUNT,
        shard_base_damage = DAMAGE_AMOUNT,
        shard_damage_type = DAMAGE_TYPE,
        shard_laser_7_tech = LATE_LASER_DAMAGE_TECH,
        shard_laser_7_per_level_bonus = LATE_LASER_DAMAGE_PER_LEVEL,
        shard_quality_max_bonus = QUALITY_DAMAGE_MAX_BONUS,
        shard_base_per_shard_dps = base_cache.per_shard_dps,
        shard_base_swarm_dps = base_cache.swarm_dps,
        shard_current_laser_7_levels = status_cache.laser_7_levels,
        shard_current_multiplier = status_cache.multiplier,
        shard_current_damage = status_cache.shard_damage,
        shard_current_per_shard_dps = status_cache.per_shard_dps,
        shard_current_swarm_dps = status_cache.swarm_dps,
        shard_current_shard_count = status_cache.shard_count,
        shard_current_cooldown_ticks = status_cache.cooldown_ticks,
        shard_target_priority = status_cache.target_priority == true,
        shard_aperture_tier = status_cache.aperture_tier,
        shard_aperture_profile = status_cache.aperture_profile,
        shard_current_quality_factor = representative_effective and representative_effective.quality_factor or 0,
        shard_current_quality_multiplier = representative_effective and representative_effective.quality_multiplier or 1,
        shard_current_effective_multiplier = representative_effective and representative_effective.multiplier or status_cache.multiplier,
        shard_current_effective_damage = representative_effective and representative_effective.shard_damage or status_cache.shard_damage,
        shard_current_effective_per_shard_dps = representative_effective and representative_effective.per_shard_dps or status_cache.per_shard_dps,
        shard_current_effective_swarm_dps = representative_effective and representative_effective.swarm_dps or status_cache.swarm_dps,
        shard_current_active_count = representative_effective and representative_effective.active_shard_count or status_cache.shard_count,
        shard_current_max_count = representative_effective and representative_effective.max_shard_count or status_cache.shard_count,
        shard_current_targeting_mode = representative_effective and representative_effective.targeting_mode or TARGETING_MODE_INDIVIDUAL,
        shard_settings_count = settings_count,
        shard_count_overrides = override_count,
        shard_disabled_tanks = disabled_count,
        shard_focus_fire_tanks = focus_fire_count,
        shard_representative_effective_dps = representative_effective and representative_effective.representative_effective_dps or status_cache.representative_effective_dps,
        shard_force_cache_count = scheduler.table_count(state.force_cache),
        shard_force_cache = state.force_cache,
        shard_linger_ticks = LINGER_TICKS,
        shard_leash_min_radius = CLOSE_HALO_MIN_RADIUS,
        shard_leash_max_radius = CLOSE_HALO_MAX_RADIUS,
        shard_mode_counts = count_motion_modes(runtime, state, status_cache),
        shard_beam = status_cache.aperture_profile and status_cache.aperture_profile.beam_name or BEAM_NAME,
        shard_base_beam = BEAM_NAME,
        shard_animation = SHARD_ANIMATION,
        shard_render_layer = SHARD_RENDER_LAYER,
    }
end

shards.beam_name = BEAM_NAME
shards.animation_name = SHARD_ANIMATION
shards.targeting_mode_individual = TARGETING_MODE_INDIVIDUAL
shards.targeting_mode_focus_fire = TARGETING_MODE_FOCUS_FIRE

return shards
