--==============================================================================
-- ESIR FILE MAP
-- owns: Emerald Apocalypse Hover Tank runtime charge, grid enforcement, hover drift,
--       underhull hover shimmer, endpoint nuclear-ground spiral scars, orbital shard support,
--       shield pulse cleanup, object-destroyed registration, and QC telemetry
-- loaded_by: exotic-space-industries-remembrance\control.lua
-- cadence: build/destroy/clone/drive/equipment/script-trigger/damage events plus
--          control.lua update fan-out for delayed charge/cold targeting, and
--          every-tick hot shard visual motion
-- forwarded_events: check_global, rebuild_runtime_state, on_built_entity,
--                   on_cloned_entity, on_destroyed_entity, on_object_destroyed,
--                   on_player_driving_changed_state, on_player_placed_equipment,
--                   on_player_removed_equipment,
--                   on_script_trigger_effect, on_entity_damaged,
--                   on_research_finished, on_scripted_research_burst,
--                   on_configuration_changed, open_gui, close_gui,
--                   on_gui_opened, on_gui_closed, on_gui_click,
--                   on_gui_value_changed, on_player_left_game,
--                   has_tick_work, has_hot_tick_work,
--                   update, hot_update,
--                   get_pending_work_count, get_runtime_status, get_qc_snapshot,
--                   configure_qc, service_for_qc, reset_runtime_state
-- storage_roots: storage.ei.emerald_apocalypse_hover_tank
-- gui_ids: ei-emerald-apocalypse-hover-tank-console
-- remote_interfaces: debug/QC methods are expected to be registered by control.lua
-- rebuild_on: runtime schema changes, prototype changes, QC reset, configuration change
--==============================================================================

local model = {}

local ei_lib = require("lib/lib")
local scheduler = require("lib/runtime-scheduler")
local hover_config = require("lib/emerald-apocalypse-hover-tank-config")
local hover_emitter_offsets_by_direction = require("lib/emerald-apocalypse-hover-tank-hover-offsets")
local orbital_shards = require("scripts/control/emerald-apocalypse-orbital-shards")

local MODULE_NAME = "emerald-apocalypse-hover-tank"
local RUNTIME_VERSION = 13

local TANK_NAME = "ei-emerald-apocalypse-hover-tank"
local GUI_NAME = "ei-emerald-apocalypse-hover-tank-console"
local TARGETING_MODE_INDIVIDUAL = orbital_shards.targeting_mode_individual or "individual"
local TARGETING_MODE_FOCUS_FIRE = orbital_shards.targeting_mode_focus_fire or "focus-fire"
local CORE_EQUIPMENT = "ei-emerald-fusion-core-equipment"
local SHIELD_EQUIPMENT = "ei-emerald-aegis-shield-equipment"
local CHARGE_ITEM = "ei-emerald-apocalypse-charge"
local CHARGE_EFFECT_ID = "ei-emerald-apocalypse-charge-shot"
local HOVER_EMITTER_ANIMATION = TANK_NAME.."-hover-emitter"
local CHARGEUP_ANIMATION = "ei-emerald-apocalypse-chargeup"
local MUZZLE_FLASH_ANIMATION = "ei-emerald-apocalypse-muzzle-flash"
local MAIN_BEAM_NAME = "ei-emerald-apocalypse-beam"
local IMPACT_EXPLOSION = "ei-emerald-collapse-impact"
local SHOCKWAVE_EXPLOSION = "ei-emerald-apocalypse-shockwave"
local HIT_FLASH_ANIMATION = "ei-emerald-collapse-hit-flash"
local SCORCHMARK_NAME = "ei-emerald-collapse-scorchmark"
local SHIELD_PULSE_ANIMATION = "ei-emerald-shield-pulse"
local CHARGE_START_SOUND = "ei-emerald-apocalypse-hover-tank-charge-start"
local CORE_EQUIPMENT_POSITION = {x = 0, y = 0}
local SHIELD_EQUIPMENT_POSITION = {x = 6, y = 0}

local CHARGE_TICKS = 569
local RANGE = 96
local DAMAGE_AMOUNT = 1000000
local DAMAGE_TYPE = "ei-plasma"
local POST_FIRE_COOLDOWN = 900
local LINE_HALF_WIDTH = 1.35
local IMPACT_RADIUS = 52
local IMPACT_CENTER_DAMAGE = 1000000
local IMPACT_EDGE_DAMAGE = 200000
local IMPACT_FLASH_LIMIT = 16
local TERRAIN_SPIRAL_TILE = "nuclear-ground"
local TERRAIN_SPIRAL_BATCH_SIZE = 32
local TERRAIN_SPIRAL_MAX_VISITS_PER_BATCH = 96
local TERRAIN_SPIRAL_INTERVAL = 2
local TERRAIN_SPIRAL_SERVICE_CAP = 2
local TERRAIN_SPIRAL_HASH_MOD = 104729
local MUZZLE_DISTANCE = 4.6
local MIN_BEAM_VISUAL_LENGTH = 0.5
local MIN_ENDPOINT_EFFECT_RANGE = MUZZLE_DISTANCE + 0.35
local BEAM_VISUAL_TICKS = 28
local MUZZLE_FLASH_TTL = 26
local HIT_FLASH_TTL = 28
local HIT_FLASH_LIMIT = 12
local CHARGEUP_SCALE = 0.52
local MUZZLE_FLASH_SCALE = 0.64
local HIT_FLASH_SCALE = 0.64
local SHIELD_PULSE_SCALE = 1.44
local MOTION_MAX_DRIFT_SPEED = 0.24
local MOTION_FORWARD_THRUST = 0.0042
local MOTION_REVERSE_THRUST = 0.0028
local MOTION_BRAKE_THRUST = 0.0075
local MOTION_DRIVER_DRAG = 0.988
local MOTION_COAST_DRAG = 0.94
local MOTION_MIN_ACTIVE_DRIFT = 0.00008
local MOTION_CHARGEUP_DRAG_MULTIPLIER = 0.72
local MOTION_RECOIL_IMPULSE = 0.105
local MOTION_APOCALYPSE_BRACE_DRAG_MULTIPLIER = 0.56
local MOTION_APOCALYPSE_RECOIL_THRUST = 0.0024
local MOTION_APOCALYPSE_MAX_DRIFT_SPEED = 0.075
local MOTION_EXTERNAL_RESET_DISTANCE = 2.5
local APOCALYPSE_BEAM_REFRESH_TICKS = 18
local APOCALYPSE_BEAM_SEGMENT_TICKS = 24
local SHIELD_PULSE_TTL = 48
local SHIELD_PULSE_COALESCE_TICKS = 12
local STATUS_REFRESH_INTERVAL = 300
local STATUS_GREEN = defines.entity_status_diode and defines.entity_status_diode.green or 1

local DOCTRINE = {
    schema = 2,
    apocalypse_recursion_tech = "ei-emerald-apocalypse-recursion",
    reclaim_target_threshold = 16,
    split_wake_half_width = 0.78,
    split_wake_lateral_offset = 2.15,
    split_wake_damage_factor = 0.28,
    split_wake_target_limit = 24,
    keel_wake_interval = 15,
    keel_wake_radius = 6.5,
    keel_wake_damage = 2500,
    keel_wake_target_limit = 10,
    keel_wake_min_speed = 0.045,
    branch_scar_target_limit = 4,
    branch_scar_step = 2,
    unsealed_impact_damage_multiplier = 1.15,
    unsealed_shockwave_extra_puffs = 4,
    toggle_options = {"reclaim_charges", "keel_wake", "branch_scars", "split_wake", "unseal_impact"},
    toggle_keys = {
        reclaim_charges = true,
        keel_wake = true,
        branch_scars = true,
        split_wake = true,
        unseal_impact = true,
    },
    toggle_locale = {
        reclaim_charges = "reclaim-charges",
        keel_wake = "keel-wake",
        branch_scars = "branch-scars",
        split_wake = "split-wake",
        unseal_impact = "unseal-impact",
    },
    charge_catechism_techs = {
        "ei-emerald-charge-catechism-1",
        "ei-emerald-charge-catechism-2",
        "ei-emerald-charge-catechism-3",
    },
    inertial_oath_techs = {
        "ei-emerald-inertial-oath-1",
        "ei-emerald-inertial-oath-2",
    },
    aegis_covenant_techs = {
        "ei-emerald-aegis-covenant-1",
        "ei-emerald-aegis-covenant-2",
    },
    vector_keel_techs = {
        "ei-emerald-vector-keel-1",
        "ei-emerald-vector-keel-2",
    },
    collapse_mandate_techs = {
        "ei-emerald-collapse-mandate-1",
        "ei-emerald-collapse-mandate-2",
        "ei-emerald-collapse-mandate-3",
    },
    charge_ticks_by_level = {
        [0] = CHARGE_TICKS,
        [1] = 510,
        [2] = 460,
        [3] = 382,
    },
    charge_sound_by_level = {
        [0] = CHARGE_START_SOUND,
        [1] = CHARGE_START_SOUND.."-upgrade-1",
        [2] = CHARGE_START_SOUND.."-upgrade-2",
        [3] = CHARGE_START_SOUND.."-upgrade-3",
    },
    cooldown_by_level = {
        [0] = POST_FIRE_COOLDOWN,
        [1] = 790,
        [2] = 680,
    },
    aegis_profiles = {
        [0] = {enabled = false, radius = 0, damage = 0, cap = 0, cooldown = 0},
        [1] = {enabled = true, radius = 8, damage = 15000, cap = 16, cooldown = 90},
        [2] = {enabled = true, radius = 12, damage = 30000, cap = 24, cooldown = 75},
    },
    keel_profiles = {
        [0] = {
            max_drift_speed = MOTION_MAX_DRIFT_SPEED,
            forward_thrust = MOTION_FORWARD_THRUST,
            reverse_thrust = MOTION_REVERSE_THRUST,
            brake_thrust = MOTION_BRAKE_THRUST,
            driver_drag = MOTION_DRIVER_DRAG,
            coast_drag = MOTION_COAST_DRAG,
            chargeup_drag_multiplier = MOTION_CHARGEUP_DRAG_MULTIPLIER,
        },
        [1] = {
            max_drift_speed = 0.25,
            forward_thrust = 0.00455,
            reverse_thrust = 0.0032,
            brake_thrust = 0.0086,
            driver_drag = 0.989,
            coast_drag = 0.935,
            chargeup_drag_multiplier = 0.68,
        },
        [2] = {
            max_drift_speed = 0.26,
            forward_thrust = 0.0049,
            reverse_thrust = 0.0035,
            brake_thrust = 0.0098,
            driver_drag = 0.990,
            coast_drag = 0.930,
            chargeup_drag_multiplier = 0.64,
        },
    },
    collapse_profiles = {
        [0] = {radius = IMPACT_RADIUS, center_damage = IMPACT_CENTER_DAMAGE, edge_damage = IMPACT_EDGE_DAMAGE},
        [1] = {radius = IMPACT_RADIUS, center_damage = 1150000, edge_damage = 260000},
        [2] = {radius = IMPACT_RADIUS, center_damage = 1300000, edge_damage = 340000},
        [3] = {radius = IMPACT_RADIUS, center_damage = 1500000, edge_damage = 450000},
    },
}

local TAU = math.pi * 2
local atan2 = math.atan2 or function(y, x) return math.atan(y, x) end
local HOVER_DIRECTION_COUNT = 64
local HOVER_EMITTER_COUNT = 4
local HOVER_EMITTER_FRAME_COUNT = 32
local HOVER_EMITTER_ANIMATION_SPEED = 0.42
local HOVER_EMITTER_RENDER_LAYER = "lower-object"
local HOVER_EMITTER_SPRITE_SCALE_PER_RADIUS = 0.36
local cached_hover_visual_config = nil
local gui = {}

-- Fallback anchors only. Normal runtime uses the generated 64-direction table
-- so all four emitter effects sit on the four rendered hover feet.
local HOVER_EMITTERS = {
    {forward = 0.05, side = -0.60, radius_scale = 1.00},
    {forward = 0.05, side = 0.60, radius_scale = 1.00},
    {forward = 1.35, side = -0.40, radius_scale = 0.92},
    {forward = 1.35, side = 0.40, radius_scale = 0.92},
}

local HOVER_COLORS = {
    {r = 0.02, g = 1.00, b = 0.46},
    {r = 0.30, g = 1.00, b = 0.72},
    {r = 0.08, g = 0.82, b = 1.00},
    {r = 0.78, g = 1.00, b = 0.28},
}

-- These counters can move every tick per driven tank. Keep them local in normal
-- play and mirror them into the shared scheduler only when QC is explicitly on.
local HOT_COUNTERS = {
    damage_hits = true,
    damage_failed = true,
    impact_area_hits = true,
    impact_area_failed = true,
    impact_area_flashes = true,
    impact_area_damage_total = true,
    impact_area_wave_skipped = true,
    impact_area_wave_failures = true,
    terrain_spiral_batches = true,
    terrain_spiral_tiles_changed = true,
    terrain_spiral_tiles_skipped = true,
    terrain_spiral_bursts = true,
    terrain_spiral_burst_failures = true,
    shockwave_puffs = true,
    shockwave_rings = true,
    shockwave_arcs = true,
    shockwave_visual_failures = true,
    motion_steps = true,
    motion_driver_ticks = true,
    motion_coast_ticks = true,
    motion_native_speed_resets = true,
    motion_equipment_bonus_ticks = true,
    hover_samples = true,
    hover_emitters = true,
    hover_idle_emitters = true,
    hover_inactive_samples = true,
    hover_capped = true,
    hover_draw_failures = true,
    apocalypse_brace_ticks = true,
    apocalypse_recoil_ticks = true,
    apocalypse_beam_refreshes = true,
    apocalypse_beam_failures = true,
}

---@class EmeraldApocalypseTankRecord
---@field unit_number uint
---@field entity LuaEntity
---@field registration_number uint?
---@field surface_index uint?
---@field force_index uint?
---@field last_seen_tick uint
---@field charge_started_tick uint?
---@field charge_due_tick uint?
---@field cooldown_until_tick uint?
---@field last_fire_tick uint?
---@field charge_profile table?
---@field aim_x number?
---@field aim_y number?
---@field aim_range number?
---@field aim_target_x number?
---@field aim_target_y number?
---@field drift_x number?
---@field drift_y number?
---@field last_motion_x number?
---@field last_motion_y number?
---@field last_safe_x number?
---@field last_safe_y number?
---@field last_safe_orientation RealOrientation?
---@field last_motion_speed number?
---@field last_motion_tick uint?
---@field motion_idle_ticks uint?
---@field movement_equipment_factor number?
---@field movement_equipment_factor_tick uint?
---@field last_hover_x number?
---@field last_hover_y number?
---@field last_hover_emit_tick uint?
---@field hover_active boolean?
---@field last_shield_pulse_tick uint?
---@field apocalypse_job_id uint?
---@field apocalypse_dx number?
---@field apocalypse_dy number?
---@field apocalypse_orientation RealOrientation?
---@field last_aegis_reprisal_tick uint?
---@field last_keel_wake_tick uint?

---@class EmeraldApocalypseTankShardSettings
---@field shard_count_override uint?
---@field targeting_mode "individual"|"focus-fire"
---@field doctrine_toggles table<string, boolean>

---@class EmeraldApocalypseTankDoctrineForceCache
---@field schema uint
---@field force_index uint?
---@field force_name string?
---@field tick uint
---@field charge_level uint
---@field inertial_level uint
---@field aegis_level uint
---@field vector_keel_level uint
---@field collapse_level uint
---@field recursion_unlocked boolean
---@field charge_ticks uint
---@field charge_sound string
---@field post_fire_cooldown uint
---@field aegis_reprisal table
---@field keel table
---@field collapse table

---@class EmeraldApocalypseRuntime
---@field version uint
---@field tanks_by_unit table<uint, EmeraldApocalypseTankRecord>
---@field tank_settings_by_unit table<uint, EmeraldApocalypseTankShardSettings>
---@field doctrine_force_cache table<uint, EmeraldApocalypseTankDoctrineForceCache>
---@field open_by_player table<uint, uint>
---@field registrations table<uint, {kind:string, unit_number:uint}>
---@field charge_queue table
---@field charge_buckets table<uint, uint[]>
---@field motion_queue table
---@field hover_queue table
---@field terrain_spiral_queue table
---@field terrain_spiral_jobs table<uint, EmeraldApocalypseTerrainSpiralJob>
---@field next_terrain_spiral_id uint
---@field hover_active_count uint
---@field shield_pulses table<uint, {render:any, expires_tick:uint, unit_number:uint?}>
---@field orbital_shards EmeraldApocalypseOrbitalShardState
---@field pending_by_unit table<uint, uint>
---@field qc table
---@field next_charge_due_tick uint
---@field next_pulse_cleanup_tick uint
---@field next_pulse_id uint
---@field last_status_tick uint
---@field pending_work_tick uint?
---@field pending_work_count uint?

---@class EmeraldApocalypseTerrainSpiralJob
---@field id uint
---@field surface_index uint
---@field center_x int
---@field center_y int
---@field impact_x number
---@field impact_y number
---@field muzzle_x number?
---@field muzzle_y number?
---@field beam_dx number?
---@field beam_dy number?
---@field beam_orientation RealOrientation?
---@field beam_last_tick uint?
---@field force_name string?
---@field source_unit_number uint?
---@field seed uint
---@field radius uint
---@field impact_center_damage number?
---@field impact_edge_damage number?
---@field impact_damage_multiplier number?
---@field unsealed boolean?
---@field offsets table<uint, {x:int, y:int}>
---@field impact_targets table<uint, {entity:LuaEntity, unit_number:uint?, name:string?, hit_position:MapPosition, distance:number}>
---@field impact_next_index uint
---@field impact_flash_count uint
---@field wave_radius number
---@field shockwave_step uint
---@field next_index uint
---@field next_tick uint
---@field batch_size uint
---@field interval uint

local function new_counters()
    local counters = {
        registered = 0,
        deregistered = 0,
        rebuilt = 0,
        grid_repairs = 0,
        charges_started = 0,
        charges_rejected = 0,
        charges_consumed = 0,
        charges_completed = 0,
        charge_refunds = 0,
        charge_refund_failures = 0,
        charges_reclaimed = 0,
        charge_reclaim_failures = 0,
        doctrine_force_cache_refreshes = 0,
        late_aim_samples = 0,
        late_aim_fallbacks = 0,
        line_attacks = 0,
        damage_hits = 0,
        damage_failed = 0,
        split_wake_hits = 0,
        split_wake_failures = 0,
        split_wake_visuals = 0,
        impact_area_hits = 0,
        impact_area_failed = 0,
        impact_area_flashes = 0,
        impact_area_damage_total = 0,
        impact_area_targets_queued = 0,
        impact_area_wave_skipped = 0,
        impact_area_wave_failures = 0,
        terrain_spiral_jobs_started = 0,
        terrain_spiral_jobs_completed = 0,
        terrain_spiral_batches = 0,
        terrain_spiral_tiles_changed = 0,
        terrain_spiral_tiles_skipped = 0,
        terrain_spiral_bursts = 0,
        terrain_spiral_burst_failures = 0,
        shockwave_puffs = 0,
        shockwave_rings = 0,
        shockwave_arcs = 0,
        shockwave_visual_failures = 0,
        branch_scar_offsets = 0,
        unsealed_impacts = 0,
        terrain_spiral_failures = 0,
        cooldown_rejections = 0,
        motion_steps = 0,
        motion_teleports_failed = 0,
        motion_rollbacks = 0,
        motion_driver_ticks = 0,
        motion_coast_ticks = 0,
        motion_recoil_impulses = 0,
        motion_native_speed_resets = 0,
        motion_equipment_bonus_ticks = 0,
        apocalypse_brace_ticks = 0,
        apocalypse_recoil_ticks = 0,
        apocalypse_beam_refreshes = 0,
        apocalypse_beam_failures = 0,
        hover_activations = 0,
        hover_deactivations = 0,
        hover_samples = 0,
        hover_emitters = 0,
        hover_idle_emitters = 0,
        hover_inactive_samples = 0,
        hover_capped = 0,
        hover_draw_failures = 0,
        shield_pulses = 0,
        shield_pulses_coalesced = 0,
        shield_pulses_cleaned = 0,
        aegis_reprisal_hits = 0,
        aegis_reprisal_failures = 0,
        keel_wake_hits = 0,
        keel_wake_failures = 0,
        chargeup_visuals = 0,
        muzzle_flashes = 0,
        beam_visuals = 0,
        impact_effects = 0,
        hit_flashes = 0,
        scorchmarks_created = 0,
        visual_failures = 0,
        invalid_purges = 0,
        fixed_equipment_removals_blocked = 0,
        fixed_equipment_items_purged = 0,
        fixed_equipment_repair_failures = 0,
        orbital_shard_status_updates = 0,
        orbital_shard_status_failures = 0,
    }
    return orbital_shards.ensure_counters(counters)
end

local function normalize_targeting_mode(mode)
    if mode == TARGETING_MODE_FOCUS_FIRE then
        return TARGETING_MODE_FOCUS_FIRE
    end
    return TARGETING_MODE_INDIVIDUAL
end

function model.copy_doctrine_toggles(source)
    local toggles = {}
    if type(source) ~= "table" then
        return toggles
    end

    for _, key in ipairs(DOCTRINE.toggle_options) do
        if source[key] ~= nil then
            toggles[key] = source[key] == true
        end
    end
    return toggles
end

local function copy_tank_settings(settings_by_unit)
    local copied = {}
    if type(settings_by_unit) ~= "table" then
        return copied
    end

    for unit_number, settings in pairs(settings_by_unit) do
        local numeric_unit = tonumber(unit_number)
        if numeric_unit and type(settings) == "table" then
            local override = settings.shard_count_override
            if override ~= nil then
                override = math.max(0, math.floor(tonumber(override) or 0))
            end
            copied[numeric_unit] = {
                shard_count_override = override,
                targeting_mode = normalize_targeting_mode(settings.targeting_mode),
                doctrine_toggles = model.copy_doctrine_toggles(settings.doctrine_toggles),
            }
        end
    end

    return copied
end

local function new_runtime()
    -- Durable state is keyed by tank unit number. Stored LuaEntity references
    -- are convenience handles only; hot paths revalidate them before use.
    return {
        version = RUNTIME_VERSION,
        tanks_by_unit = {},
        tank_settings_by_unit = {},
        doctrine_force_cache = {},
        open_by_player = {},
        registrations = {},
        charge_queue = scheduler.ensure_queue(nil),
        charge_buckets = scheduler.ensure_delayed_buckets(nil),
        motion_queue = scheduler.ensure_queue(nil),
        hover_queue = scheduler.ensure_queue(nil),
        terrain_spiral_queue = scheduler.ensure_queue(nil),
        terrain_spiral_jobs = {},
        next_terrain_spiral_id = 0,
        hover_active_count = 0,
        shield_pulses = {},
        orbital_shards = orbital_shards.new_state(),
        pending_by_unit = {},
        qc = {
            enabled = false,
            counters = new_counters(),
        },
        next_charge_due_tick = 0,
        next_pulse_cleanup_tick = 0,
        next_pulse_id = 0,
        last_status_tick = 0,
        pending_work_tick = nil,
        pending_work_count = nil,
    }
end

---@return EmeraldApocalypseRuntime
local function ensure_runtime()
    storage.ei = storage.ei or {}
    local runtime = storage.ei.emerald_apocalypse_hover_tank
    if type(runtime) ~= "table" or runtime.version ~= RUNTIME_VERSION then
        -- Schema changes rebuild derived queues and registrations from live
        -- entities instead of trusting stale storage-era handles.
        local preserved_settings = type(runtime) == "table"
            and copy_tank_settings(runtime.tank_settings_by_unit)
            or {}
        runtime = new_runtime()
        runtime.tank_settings_by_unit = preserved_settings
        storage.ei.emerald_apocalypse_hover_tank = runtime
    end

    runtime.tanks_by_unit = type(runtime.tanks_by_unit) == "table" and runtime.tanks_by_unit or {}
    runtime.tank_settings_by_unit = type(runtime.tank_settings_by_unit) == "table" and runtime.tank_settings_by_unit or {}
    runtime.doctrine_force_cache = type(runtime.doctrine_force_cache) == "table" and runtime.doctrine_force_cache or {}
    runtime.open_by_player = type(runtime.open_by_player) == "table" and runtime.open_by_player or {}
    runtime.registrations = type(runtime.registrations) == "table" and runtime.registrations or {}
    runtime.charge_queue = scheduler.ensure_queue(runtime.charge_queue)
    runtime.charge_buckets = scheduler.ensure_delayed_buckets(runtime.charge_buckets)
    runtime.motion_queue = scheduler.ensure_queue(runtime.motion_queue)
    runtime.hover_queue = scheduler.ensure_queue(runtime.hover_queue)
    runtime.terrain_spiral_queue = scheduler.ensure_queue(runtime.terrain_spiral_queue)
    runtime.terrain_spiral_jobs = type(runtime.terrain_spiral_jobs) == "table" and runtime.terrain_spiral_jobs or {}
    runtime.next_terrain_spiral_id = tonumber(runtime.next_terrain_spiral_id) or 0
    if runtime.hover_active_count == nil then
        local active_count = 0
        for _, record in pairs(runtime.tanks_by_unit) do
            if type(record) == "table" and record.hover_active == true then
                active_count = active_count + 1
            end
        end
        runtime.hover_active_count = active_count
    else
        runtime.hover_active_count = math.max(0, math.floor(tonumber(runtime.hover_active_count) or 0))
    end
    runtime.shield_pulses = type(runtime.shield_pulses) == "table" and runtime.shield_pulses or {}
    runtime.orbital_shards = orbital_shards.ensure_state(runtime.orbital_shards)
    runtime.pending_by_unit = type(runtime.pending_by_unit) == "table" and runtime.pending_by_unit or {}
    runtime.qc = type(runtime.qc) == "table" and runtime.qc or {}
    runtime.qc.counters = type(runtime.qc.counters) == "table" and runtime.qc.counters or new_counters()
    orbital_shards.ensure_counters(runtime.qc.counters)
    for key, value in pairs(new_counters()) do
        if runtime.qc.counters[key] == nil then
            runtime.qc.counters[key] = value
        end
    end
    runtime.next_charge_due_tick = tonumber(runtime.next_charge_due_tick) or 0
    runtime.next_pulse_cleanup_tick = tonumber(runtime.next_pulse_cleanup_tick) or 0
    runtime.next_pulse_id = tonumber(runtime.next_pulse_id) or 0
    runtime.last_status_tick = tonumber(runtime.last_status_tick) or 0
    runtime.pending_work_tick = tonumber(runtime.pending_work_tick) or nil
    runtime.pending_work_count = tonumber(runtime.pending_work_count) or nil
    return runtime
end

local function resolve_tick(event_or_tick)
    if type(event_or_tick) == "number" then
        return math.max(0, math.floor(event_or_tick))
    end

    if type(event_or_tick) == "table" then
        return math.max(0, math.floor(tonumber(event_or_tick.tick) or 0))
    end

    return 0
end

local function raw_queue_has_items(queue)
    if type(queue) ~= "table" then
        return false
    end

    local items = queue.items
    if type(items) == "table" then
        local head = queue.head or 1
        local tail = queue.tail or #items
        for index = head, tail do
            if items[index] ~= nil then
                return true
            end
        end
    end

    local queued = queue.queued
    return type(queued) == "table" and next(queued) ~= nil
end

local function raw_table_has_entries(tbl)
    return type(tbl) == "table" and next(tbl) ~= nil
end

local function raw_orbital_shards_has_records(state)
    if type(state) ~= "table" then
        return false
    end

    return (state.record_count or 0) > 0
        or raw_table_has_entries(state.records_by_unit)
end

local function raw_orbital_shards_has_tick_work(state, current_tick)
    if not raw_orbital_shards_has_records(state) then
        return false
    end

    return raw_queue_has_items(state.update_queue)
        or raw_queue_has_items(state.visual_queue)
        or current_tick >= (state.next_service_tick or 0)
end

local function raw_has_active_hover_record(runtime)
    if type(runtime) ~= "table" or type(runtime.tanks_by_unit) ~= "table" then
        return false
    end

    for _, record in pairs(runtime.tanks_by_unit) do
        if type(record) == "table" and record.hover_active == true then
            return true
        end
    end

    return false
end

local function record_has_active_apocalypse_job(runtime, record, current_tick)
    if type(runtime) ~= "table" or type(record) ~= "table" then
        return false
    end

    local job_id = record.apocalypse_job_id
    if not job_id or type(runtime.terrain_spiral_jobs) ~= "table" or not runtime.terrain_spiral_jobs[job_id] then
        return false
    end

    return true
end

local function clear_apocalypse_brace(record, job_id)
    if type(record) ~= "table" then
        return
    end
    if job_id and record.apocalypse_job_id ~= job_id then
        return
    end

    record.apocalypse_job_id = nil
    record.apocalypse_dx = nil
    record.apocalypse_dy = nil
    record.apocalypse_orientation = nil
end

local function raw_has_active_motion_record(runtime)
    if type(runtime) ~= "table" or type(runtime.tanks_by_unit) ~= "table" then
        return false
    end

    local pending_by_unit = type(runtime.pending_by_unit) == "table" and runtime.pending_by_unit or {}
    local min_speed_sqr = MOTION_MIN_ACTIVE_DRIFT * MOTION_MIN_ACTIVE_DRIFT
    for unit_number, record in pairs(runtime.tanks_by_unit) do
        if type(record) == "table" then
            if pending_by_unit[unit_number] ~= nil or record.hover_active == true then
                return true
            end

            if record_has_active_apocalypse_job(runtime, record) then
                return true
            end

            local last_motion_speed = math.abs(tonumber(record.last_motion_speed) or 0)
            if last_motion_speed >= MOTION_MIN_ACTIVE_DRIFT then
                return true
            end

            local drift_x = tonumber(record.drift_x) or 0
            local drift_y = tonumber(record.drift_y) or 0
            if (drift_x * drift_x) + (drift_y * drift_y) >= min_speed_sqr then
                return true
            end
        end
    end

    return false
end

local function reset_hover_visual_config_cache()
    cached_hover_visual_config = nil
end

local function get_hover_visual_config()
    if cached_hover_visual_config then
        return cached_hover_visual_config
    end

    -- The startup setting is stable during a run, but normalization allocates a
    -- defensive preset copy. Cache the runtime-safe values until config changes.
    local visual_config = hover_config.resolve()
    visual_config.update_interval = math.max(1, math.floor(tonumber(visual_config.update_interval) or 1))
    visual_config.service_cap_value = hover_config.get_service_cap(visual_config)
    visual_config.global_emitter_cap_value = hover_config.get_global_emitter_cap(visual_config)
    visual_config.movement_threshold = tonumber(visual_config.movement_threshold) or 0.035
    visual_config.movement_threshold_sq = visual_config.movement_threshold * visual_config.movement_threshold
    visual_config.ring_ttl = math.max(1, math.floor(tonumber(visual_config.ring_ttl) or 1))
    visual_config.moving_emit_interval = math.max(0, math.floor(tonumber(visual_config.moving_emit_interval) or 0))
    visual_config.idle_emit_interval = math.max(1, math.floor(tonumber(visual_config.idle_emit_interval) or 1))
    visual_config.radius = ei_lib.clamp_number(visual_config.radius, 0.05, nil, 0.42)
    visual_config.width = ei_lib.clamp_number(visual_config.width, 1, nil, 2)
    visual_config.echo_alpha = ei_lib.clamp_number(visual_config.echo_alpha, 0, 1, 0)
    visual_config.arc_alpha = ei_lib.clamp_number(visual_config.arc_alpha, 0, 1, 0.26)
    visual_config.arc_count = ei_lib.clamp_integer(visual_config.arc_count, 0, nil, 0)
    visual_config.arc_span = ei_lib.clamp_number(visual_config.arc_span, 0, TAU, 0.86)
    visual_config.arc_thickness = ei_lib.clamp_number(visual_config.arc_thickness, 0.01, nil, 0.05)
    visual_config.phase_speed = tonumber(visual_config.phase_speed) or 0.026

    cached_hover_visual_config = visual_config
    return visual_config
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
        or event_or_entity.source_entity
        or event_or_entity.vehicle
end

local function is_tank(entity)
    return ei_lib.entity_check(entity) and entity.name == TANK_NAME
end

local function tank_has_driver(entity)
    local ok, driver = pcall(function()
        return entity and entity.get_driver and entity.get_driver()
    end)
    return ok and driver ~= nil
end

local function tank_has_player_occupant(entity)
    if not is_tank(entity) then
        return false
    end

    if tank_has_driver(entity) then
        return true
    end

    local ok, passenger = pcall(function()
        return entity.get_passenger and entity.get_passenger()
    end)
    return ok and passenger ~= nil
end

local function is_fixed_equipment_name(name)
    return name == CORE_EQUIPMENT or name == SHIELD_EQUIPMENT
end

local function normalize_quality_name(value, default_quality)
    if type(value) == "string" and value ~= "" then
        return value
    end

    if value ~= nil then
        local ok, name = pcall(function()
            return value.name
        end)
        if ok and type(name) == "string" and name ~= "" then
            return name
        end
    end

    return default_quality or "normal"
end

local function get_object_quality_name(object, default_quality)
    if not object then
        return default_quality or "normal"
    end

    local ok, quality = pcall(function()
        return object.quality
    end)
    if not ok then
        return default_quality or "normal"
    end

    return normalize_quality_name(quality, default_quality)
end

local function bump(runtime, counter_name, delta)
    delta = delta or 1
    if HOT_COUNTERS[counter_name] and runtime.qc.enabled ~= true then
        local shadow = model.hot_counter_shadow or {}
        model.hot_counter_shadow = shadow
        shadow[counter_name] = (tonumber(shadow[counter_name]) or 0) + delta
        return (tonumber(runtime.qc.counters[counter_name]) or 0) + shadow[counter_name]
    end

    runtime.qc.counters[counter_name] = (tonumber(runtime.qc.counters[counter_name]) or 0) + delta
    -- Scheduler telemetry is useful for QC, but high-frequency visual/motion
    -- counters should not churn the shared status table during ordinary play.
    if runtime.qc.enabled == true or not HOT_COUNTERS[counter_name] then
        scheduler.bump_counter(MODULE_NAME, counter_name, delta)
    end
    return runtime.qc.counters[counter_name]
end

function model.counter_snapshot(runtime)
    local shadow = model.hot_counter_shadow
    if not raw_table_has_entries(shadow) then
        return runtime.qc.counters
    end

    local counters = {}
    for key, value in pairs(runtime.qc.counters or {}) do
        counters[key] = value
    end
    for key, value in pairs(shadow) do
        counters[key] = (tonumber(counters[key]) or 0) + value
    end
    return counters
end

function model.shallow_copy_table(source)
    local copied = {}
    if type(source) ~= "table" then
        return copied
    end

    for key, value in pairs(source) do
        if type(value) == "table" then
            copied[key] = model.shallow_copy_table(value)
        else
            copied[key] = value
        end
    end
    return copied
end

function model.force_cache_key(force)
    if not (force and force.valid) then
        return nil
    end

    return force.index
end

function model.force_technology_researched(force, technology_name)
    if not (force and force.valid and technology_name) then
        return false
    end

    local ok, technology = pcall(function()
        return force.technologies[technology_name]
    end)
    if not ok or not technology then
        return false
    end

    local researched_ok, researched = pcall(function()
        return technology.researched
    end)
    return researched_ok and researched == true
end

function model.resolved_research_level(force, technologies)
    local level = 0
    for index, technology_name in ipairs(technologies or {}) do
        if model.force_technology_researched(force, technology_name) then
            level = index
        end
    end
    return level
end

function model.make_doctrine_force_cache(force, current_tick)
    current_tick = resolve_tick(current_tick)
    local charge_level = model.resolved_research_level(force, DOCTRINE.charge_catechism_techs)
    local inertial_level = model.resolved_research_level(force, DOCTRINE.inertial_oath_techs)
    local aegis_level = model.resolved_research_level(force, DOCTRINE.aegis_covenant_techs)
    local vector_keel_level = model.resolved_research_level(force, DOCTRINE.vector_keel_techs)
    local collapse_level = model.resolved_research_level(force, DOCTRINE.collapse_mandate_techs)
    local recursion_unlocked = model.force_technology_researched(force, DOCTRINE.apocalypse_recursion_tech)

    return {
        schema = DOCTRINE.schema,
        force_index = model.force_cache_key(force),
        force_name = force and force.valid and force.name or nil,
        tick = current_tick,
        charge_level = charge_level,
        inertial_level = inertial_level,
        aegis_level = aegis_level,
        vector_keel_level = vector_keel_level,
        collapse_level = collapse_level,
        recursion_unlocked = recursion_unlocked,
        charge_ticks = DOCTRINE.charge_ticks_by_level[charge_level] or CHARGE_TICKS,
        charge_sound = DOCTRINE.charge_sound_by_level[charge_level] or CHARGE_START_SOUND,
        post_fire_cooldown = DOCTRINE.cooldown_by_level[inertial_level] or POST_FIRE_COOLDOWN,
        aegis_reprisal = model.shallow_copy_table(DOCTRINE.aegis_profiles[aegis_level] or DOCTRINE.aegis_profiles[0]),
        keel = model.shallow_copy_table(DOCTRINE.keel_profiles[vector_keel_level] or DOCTRINE.keel_profiles[0]),
        collapse = model.shallow_copy_table(DOCTRINE.collapse_profiles[collapse_level] or DOCTRINE.collapse_profiles[0]),
    }
end

function model.doctrine_force_cache_is_current(cache)
    return type(cache) == "table"
        and cache.schema == DOCTRINE.schema
        and type(cache.keel) == "table"
        and type(cache.collapse) == "table"
        and type(cache.aegis_reprisal) == "table"
        and type(cache.charge_sound) == "string"
end

function model.sync_doctrine_force_cache(runtime, force, current_tick)
    local key = model.force_cache_key(force)
    if not key then
        return nil
    end

    runtime.doctrine_force_cache = type(runtime.doctrine_force_cache) == "table"
        and runtime.doctrine_force_cache
        or {}
    local cache = model.make_doctrine_force_cache(force, current_tick)
    runtime.doctrine_force_cache[key] = cache
    bump(runtime, "doctrine_force_cache_refreshes", 1)
    return cache
end

function model.sync_all_doctrine_force_caches(runtime, current_tick)
    if not (game and game.forces) then
        return 0
    end

    local synced = 0
    for _, force in pairs(game.forces) do
        if force and force.valid then
            if model.sync_doctrine_force_cache(runtime, force, current_tick) then
                synced = synced + 1
            end
        end
    end
    return synced
end

function model.get_doctrine_force_cache(runtime, force, current_tick)
    runtime.doctrine_force_cache = type(runtime.doctrine_force_cache) == "table"
        and runtime.doctrine_force_cache
        or {}
    local key = model.force_cache_key(force)
    if not key then
        return model.make_doctrine_force_cache(force, current_tick)
    end

    local cache = runtime.doctrine_force_cache[key]
    if not model.doctrine_force_cache_is_current(cache) then
        cache = model.sync_doctrine_force_cache(runtime, force, current_tick)
    end
    return cache or model.make_doctrine_force_cache(force, current_tick)
end

function model.normalize_seed_part(value)
    value = math.floor(tonumber(value) or 0)
    if value < 0 then
        return ((-value * 2) + 1) % TERRAIN_SPIRAL_HASH_MOD
    end
    return (value * 2) % TERRAIN_SPIRAL_HASH_MOD
end

function model.hash_mix(seed, value)
    seed = math.floor(tonumber(seed) or 0) % TERRAIN_SPIRAL_HASH_MOD
    value = model.normalize_seed_part(value)
    return ((seed * 4099) + (value * 131) + 17) % TERRAIN_SPIRAL_HASH_MOD
end

function model.hash_fraction(seed, salt)
    local value = model.hash_mix(seed, salt)
    value = ((value * 8191) + 37) % TERRAIN_SPIRAL_HASH_MOD
    return value / TERRAIN_SPIRAL_HASH_MOD
end

function model.make_terrain_spiral_seed(surface_index, center_x, center_y, current_tick, unit_number)
    local seed = 97
    seed = model.hash_mix(seed, surface_index)
    seed = model.hash_mix(seed, center_x)
    seed = model.hash_mix(seed, center_y)
    seed = model.hash_mix(seed, current_tick)
    seed = model.hash_mix(seed, unit_number)
    return seed
end

function model.make_terrain_spiral_offsets(radius, seed)
    radius = math.max(1, math.floor(tonumber(radius) or 1))
    seed = math.floor(tonumber(seed) or 0) % TERRAIN_SPIRAL_HASH_MOD

    local radius_sq = radius * radius
    local clockwise = model.hash_fraction(seed, 1) >= 0.5 and 1 or -1
    local phase_radians = model.hash_fraction(seed, 2) * TAU
    local turns = 3.45 + (model.hash_fraction(seed, 3) * 1.25)
    local brush_growth = 1.35 + (model.hash_fraction(seed, 4) * 0.38)
    local wave_frequency = 2 + math.floor(model.hash_fraction(seed, 5) * 4)
    local offsets = {}
    local used = {}

    local function round(value)
        if value >= 0 then
            return math.floor(value + 0.5)
        end
        return math.ceil(value - 0.5)
    end

    local function add_offset(x, y)
        if (x * x) + (y * y) > radius_sq then
            return
        end

        local key = x..":"..y
        if used[key] then
            return
        end

        used[key] = true
        offsets[#offsets + 1] = {x = x, y = y}
    end

    add_offset(0, 0)

    -- Walk a real spiral path, brushing nearby tiles as the arm passes. There
    -- is deliberately no gap fill; the scar should remain a torn spiral.
    local path_steps = math.max(1, math.floor(radius * turns * 16))
    for step = 0, path_steps do
        local t = step / path_steps
        local distance = t * radius
        local angle = clockwise * (
            phase_radians
            + (t * turns * TAU)
            + (math.sin((t * TAU * wave_frequency) + phase_radians) * 0.18)
        )
        local cx = round(math.cos(angle) * distance)
        local cy = round(math.sin(angle) * distance)
        local brush = 0.92 + (t * brush_growth)
        local brush_radius = math.ceil(brush)
        local brush_sq = brush * brush
        for by = -brush_radius, brush_radius do
            for bx = -brush_radius, brush_radius do
                if (bx * bx) + (by * by) <= brush_sq then
                    add_offset(cx + bx, cy + by)
                end
            end
        end
    end

    return offsets
end

function model.add_branch_scar_offsets(offsets, radius, seed, impact_targets, center)
    if type(offsets) ~= "table" then
        return 0
    end

    radius = math.max(1, math.floor(tonumber(radius) or IMPACT_RADIUS))
    local used = {}
    for _, offset in ipairs(offsets) do
        if type(offset) == "table" then
            used[(offset.x or 0)..":"..(offset.y or 0)] = true
        end
    end

    local function add_offset(x, y)
        x = math.floor(tonumber(x) or 0)
        y = math.floor(tonumber(y) or 0)
        if (x * x) + (y * y) > radius * radius then
            return false
        end

        local key = x..":"..y
        if used[key] then
            return false
        end

        used[key] = true
        offsets[#offsets + 1] = {x = x, y = y}
        return true
    end

    local added = 0
    local branch_count = 0
    for _, entry in ipairs(type(impact_targets) == "table" and impact_targets or {}) do
        if branch_count >= DOCTRINE.branch_scar_target_limit then
            break
        end

        local position = entry.hit_position
        local distance = tonumber(entry.distance) or radius
        if position and distance > 2 and distance <= radius then
            branch_count = branch_count + 1
            center = center or {x = 0, y = 0}
            local angle = atan2((tonumber(position.y) or 0) - (tonumber(center.y) or 0), (tonumber(position.x) or 0) - (tonumber(center.x) or 0))
            angle = angle + ((model.hash_fraction(seed, branch_count * 211) - 0.5) * 0.7)
            local branch_length = math.max(6, math.floor(distance * (0.28 + model.hash_fraction(seed, branch_count * 257) * 0.18)))
            local branch_start = math.max(2, math.floor(distance - branch_length))
            for step = branch_start, math.floor(distance), DOCTRINE.branch_scar_step do
                local wobble = (model.hash_fraction(seed, step + branch_count * 317) - 0.5) * 1.8
                local x = math.floor(math.cos(angle) * step + wobble + 0.5)
                local y = math.floor(math.sin(angle) * step - wobble + 0.5)
                if add_offset(x, y) then
                    added = added + 1
                end
            end
        end
    end

    table.sort(offsets, function(a, b)
        local ad = ((a.x or 0) * (a.x or 0)) + ((a.y or 0) * (a.y or 0))
        local bd = ((b.x or 0) * (b.x or 0)) + ((b.y or 0) * (b.y or 0))
        if ad ~= bd then
            return ad < bd
        end
        if a.x ~= b.x then
            return (a.x or 0) < (b.x or 0)
        end
        return (a.y or 0) < (b.y or 0)
    end)

    return added
end

function model.get_surface_by_index(surface_index)
    if not game then
        return nil
    end

    if game.get_surface then
        return game.get_surface(surface_index)
    end

    return game.surfaces and game.surfaces[surface_index] or nil
end

function model.terrain_spiral_tile_is_eligible(surface, x, y)
    local ok, tile = pcall(function()
        return surface.get_tile({x = x, y = y})
    end)
    if not ok or not tile or not tile.name or tile.name == "out-of-map" or tile.name == TERRAIN_SPIRAL_TILE then
        return false
    end

    local water_ok, is_water = pcall(function()
        return tile.collides_with and tile.collides_with("water_tile")
    end)
    if not water_ok or is_water then
        return false
    end

    return true
end

local function format_damage_number(value)
    value = tonumber(value) or 0
    if value >= 100 or value % 1 == 0 then
        return tostring(math.floor(value + 0.5))
    end

    return string.format("%.1f", value)
end

function model.format_seconds_from_ticks(ticks)
    local seconds = (tonumber(ticks) or 0) / 60
    local rounded = math.floor(seconds * 100 + 0.5) / 100
    if rounded % 1 == 0 then
        return tostring(math.floor(rounded))
    end

    local text = string.format("%.2f", rounded)
    return (text:gsub("0+$", ""):gsub("%.$", ""))
end

local function set_orbital_shard_damage_status(runtime, entity, force_cache, current_tick)
    if not is_tank(entity) then
        return false
    end

    current_tick = resolve_tick(current_tick)
    force_cache = type(force_cache) == "table"
        and force_cache
        or orbital_shards.get_force_cache(runtime, entity.force, current_tick)
    local effective_damage = orbital_shards.get_effective_damage(
        runtime,
        entity.force,
        entity,
        current_tick,
        force_cache)

    local ok = pcall(function()
        entity.custom_status = {
            diode = STATUS_GREEN,
            label = {
                "entity-status.ei-emerald-apocalypse-orbital-shards-current-dps",
                format_damage_number(effective_damage.swarm_dps),
                {"damage-type-name."..(effective_damage.damage_type or DAMAGE_TYPE)},
                effective_damage.active_shard_count or effective_damage.shard_count or 0,
                effective_damage.max_shard_count or effective_damage.shard_count or 0,
            },
        }
    end)

    if ok then
        bump(runtime, "orbital_shard_status_updates", 1)
        return true
    end

    bump(runtime, "orbital_shard_status_failures", 1)
    return false
end

local function refresh_orbital_shard_damage_statuses(runtime, force, current_tick)
    if not game or not game.surfaces then
        return 0
    end

    local filter = {name = TANK_NAME}
    if force and force.valid then
        filter.force = force.name
    end

    local force_cache_by_index = {}
    local updated = 0
    for _, surface in pairs(game.surfaces) do
        if surface and surface.valid then
            for _, entity in pairs(surface.find_entities_filtered(filter)) do
                local force_index = entity.force and entity.force.index or nil
                local force_cache = force_index and force_cache_by_index[force_index] or nil
                if not force_cache then
                    force_cache = orbital_shards.get_force_cache(runtime, entity.force, current_tick)
                    if force_index then
                        force_cache_by_index[force_index] = force_cache
                    end
                end
                if set_orbital_shard_damage_status(
                    runtime,
                    entity,
                    force_cache,
                    current_tick
                ) then
                    updated = updated + 1
                end
            end
        end
    end

    return updated
end

function model.refresh_registered_orbital_shard_damage_statuses(runtime, force, current_tick)
    local tanks_by_unit = runtime and runtime.tanks_by_unit
    if type(tanks_by_unit) ~= "table" then
        return 0
    end

    local force_cache_by_index = {}
    local updated = 0
    for _, record in pairs(tanks_by_unit) do
        local entity = ei_lib.get_valid_entity(record and record.entity)
        if is_tank(entity) and (not force or entity.force == force) then
            local force_index = entity.force and entity.force.index or nil
            local force_cache = force_index and force_cache_by_index[force_index] or nil
            if not force_cache then
                force_cache = orbital_shards.get_force_cache(runtime, entity.force, current_tick)
                if force_index then
                    force_cache_by_index[force_index] = force_cache
                end
            end
            if set_orbital_shard_damage_status(runtime, entity, force_cache, current_tick) then
                updated = updated + 1
            end
        end
    end

    return updated
end

function model.release_legacy_max_shard_overrides(runtime, force, old_max_count, new_max_count)
    old_max_count = tonumber(old_max_count) or nil
    new_max_count = tonumber(new_max_count) or nil
    if not (force and force.valid and old_max_count and new_max_count and new_max_count > old_max_count) then
        return 0
    end

    local settings_by_unit = runtime and runtime.tank_settings_by_unit
    local tanks_by_unit = runtime and runtime.tanks_by_unit
    if type(settings_by_unit) ~= "table" or type(tanks_by_unit) ~= "table" then
        return 0
    end

    local released = 0
    for unit_number, settings in pairs(settings_by_unit) do
        if type(settings) == "table" and tonumber(settings.shard_count_override) == old_max_count then
            local record = tanks_by_unit[unit_number]
            local entity = ei_lib.get_valid_entity(record and record.entity)
            local same_force = entity and entity.force == force
                or (not entity and record and tonumber(record.force_index) == force.index)
            if same_force then
                settings.shard_count_override = nil
                released = released + 1
            end
        end
    end

    return released
end

local function get_grid(entity)
    if not ei_lib.entity_check(entity) then
        return nil
    end

    local ok, grid = pcall(function()
        return entity.grid
    end)
    return ok and grid or nil
end

local function get_grid_equipment(grid)
    -- EquipmentGrid objects can be stale after clone/mining/reset boundaries.
    -- Probe through pcall and let the fixed-equipment repair path decide what
    -- to restore.
    if not grid then
        return {}
    end

    local ok, equipment = pcall(function()
        return grid.equipment
    end)
    if ok and type(equipment) == "table" then
        return equipment
    end

    return {}
end

local function equipment_position_matches(equipment, position)
    if not equipment or not equipment.valid or not position then
        return false
    end

    local equipment_position = equipment.position
    return equipment_position
        and equipment_position.x == position.x
        and equipment_position.y == position.y
end

local function equipment_quality_matches(equipment, quality_name)
    if not equipment or not equipment.valid then
        return false
    end

    return get_object_quality_name(equipment, "normal") == normalize_quality_name(quality_name, "normal")
end

local function get_fixed_equipment(grid, name)
    local matches = {}
    for _, equipment in pairs(get_grid_equipment(grid)) do
        if equipment and equipment.valid and equipment.name == name then
            matches[#matches + 1] = equipment
        end
    end
    return matches
end

local function put_fixed_equipment(grid, name, position, quality_name)
    quality_name = normalize_quality_name(quality_name, "normal")
    local ok, equipment = pcall(function()
        return grid.put{name = name, quality = quality_name, position = position}
    end)
    if ok and equipment then
        return equipment
    end

    ok, equipment = pcall(function()
        return grid.put{name = name, quality = quality_name}
    end)
    if ok and equipment then
        return equipment
    end

    if quality_name ~= "normal" then
        return nil
    end

    ok, equipment = pcall(function()
        return grid.put{name = name, position = position}
    end)
    if ok and equipment then
        return equipment
    end

    ok, equipment = pcall(function()
        return grid.put{name = name}
    end)
    if ok and equipment then
        return equipment
    end

    return nil
end

local function move_fixed_equipment(grid, equipment, position)
    if not equipment or not equipment.valid or equipment_position_matches(equipment, position) then
        return false
    end

    local ok, moved = pcall(function()
        return grid.move{equipment = equipment, position = position}
    end)
    return ok and moved == true
end

local function take_fixed_equipment(grid, equipment)
    if not equipment or not equipment.valid then
        return false
    end

    local ok, removed = pcall(function()
        return grid.take{equipment = equipment}
    end)
    return ok and removed ~= nil
end

local function ensure_single_fixed_equipment(grid, name, position, quality_name)
    -- Built-in equipment is part of the vehicle contract. Keep one copy at the
    -- reserved location and matching the tank quality. Extras and stale
    -- normal-quality copies are removed so repeated repair events cannot fill
    -- the grid with fixed gear.
    quality_name = normalize_quality_name(quality_name, "normal")
    local repairs = 0
    local matches = get_fixed_equipment(grid, name)
    local keep = nil

    for _, equipment in ipairs(matches) do
        if equipment_position_matches(equipment, position)
            and equipment_quality_matches(equipment, quality_name) then
            keep = equipment
            break
        end
    end

    if not keep then
        for _, equipment in ipairs(matches) do
            if equipment_position_matches(equipment, position)
                and not equipment_quality_matches(equipment, quality_name)
                and take_fixed_equipment(grid, equipment) then
                repairs = repairs + 1
            end
        end

        for _, equipment in ipairs(matches) do
            if equipment_quality_matches(equipment, quality_name) then
                keep = equipment
                break
            end
        end
        if keep and not equipment_position_matches(keep, position) then
            if move_fixed_equipment(grid, keep, position) then
                repairs = repairs + 1
            else
                keep = nil
            end
        end
    end

    if not keep or not keep.valid then
        keep = put_fixed_equipment(grid, name, position, quality_name)
        if keep then
            repairs = repairs + 1
        end
    end

    -- `LuaEquipmentGrid::get_contents()` returns quality-count arrays in
    -- Factorio 2.0, not a name-keyed dictionary. Use concrete equipment handles
    -- here so the fixed gear repair stays idempotent and old over-inserted saves
    -- are cleaned back down to one core and one shield.
    matches = get_fixed_equipment(grid, name)
    if not keep then
        for _, equipment in ipairs(matches) do
            if equipment_position_matches(equipment, position)
                and equipment_quality_matches(equipment, quality_name) then
                keep = equipment
                break
            end
        end
    end
    if not keep then
        for _, equipment in ipairs(matches) do
            if equipment_quality_matches(equipment, quality_name) then
                keep = equipment
                break
            end
        end
    end
    if not keep then
        keep = matches[1]
    end

    for _, equipment in ipairs(matches) do
        if equipment ~= keep and take_fixed_equipment(grid, equipment) then
            repairs = repairs + 1
        end
    end

    return repairs
end

local function ensure_equipment(entity)
    local grid = get_grid(entity)
    if not grid then
        return 0
    end

    local quality_name = get_object_quality_name(entity, "normal")
    return ensure_single_fixed_equipment(grid, CORE_EQUIPMENT, CORE_EQUIPMENT_POSITION, quality_name)
        + ensure_single_fixed_equipment(grid, SHIELD_EQUIPMENT, SHIELD_EQUIPMENT_POSITION, quality_name)
end

local function has_fixed_equipment(entity)
    local grid = get_grid(entity)
    if not grid then
        return false
    end

    return #get_fixed_equipment(grid, CORE_EQUIPMENT) > 0
        and #get_fixed_equipment(grid, SHIELD_EQUIPMENT) > 0
end

local function get_grid_owner_entity(grid)
    if not grid or grid.valid == false then
        return nil
    end

    local ok, owner = pcall(function()
        return grid.entity_owner
    end)
    if ok then
        return ei_lib.get_valid_entity(owner)
    end

    return nil
end

local function quality_matches(item_stack, quality_name)
    return get_object_quality_name(item_stack, "normal") == normalize_quality_name(quality_name, "normal")
end

local function remove_from_cursor_stack(player, name, quality_name, count)
    if count <= 0 then
        return 0
    end

    local ok, cursor_stack = pcall(function()
        return player.cursor_stack
    end)
    if not ok or not cursor_stack or not cursor_stack.valid_for_read then
        return 0
    end
    if cursor_stack.name ~= name or not quality_matches(cursor_stack, quality_name) then
        return 0
    end

    local removed = math.min(count, tonumber(cursor_stack.count) or 0)
    if removed <= 0 then
        return 0
    end

    ok = pcall(function()
        if cursor_stack.count <= removed then
            cursor_stack.clear()
        else
            cursor_stack.count = cursor_stack.count - removed
        end
    end)

    return ok and removed or 0
end

local function remove_from_player_inventory(player, name, quality_name, count)
    if count <= 0 then
        return 0
    end

    local stack = {
        name = name,
        count = count,
        quality = quality_name or "normal",
    }
    local ok, removed = pcall(function()
        return player.remove_item(stack)
    end)

    return ok and (tonumber(removed) or 0) or 0
end

local function purge_removed_fixed_equipment_item(runtime, event)
    local name = event and event.equipment
    if not is_fixed_equipment_name(name) then
        return 0
    end

    local player = game and game.get_player(event.player_index) or nil
    if not player then
        return 0
    end

    local remaining = math.max(1, math.floor(tonumber(event.count) or 1))
    local quality_name = normalize_quality_name(event.quality, "normal")
    local purged = remove_from_cursor_stack(player, name, quality_name, remaining)
    remaining = remaining - purged

    if remaining > 0 then
        local inventory_removed = remove_from_player_inventory(player, name, quality_name, remaining)
        purged = purged + inventory_removed
    end

    if purged > 0 then
        bump(runtime, "fixed_equipment_items_purged", purged)
    end

    return purged
end

local function recalculate_next_charge_due(runtime)
    local next_due_tick = 0
    for bucket_tick in pairs(runtime.charge_buckets) do
        if bucket_tick > 0 and (next_due_tick == 0 or bucket_tick < next_due_tick) then
            next_due_tick = bucket_tick
        end
    end
    runtime.next_charge_due_tick = next_due_tick
    return next_due_tick
end

local function remove_unit_from_delayed_charge_bucket(runtime, unit_number, due_tick)
    local bucket = runtime.charge_buckets[due_tick]
    if type(bucket) ~= "table" then
        return 0
    end

    local write_index = 1
    local removed = 0
    for read_index = 1, #bucket do
        local value = bucket[read_index]
        if value == unit_number then
            removed = removed + 1
        else
            bucket[write_index] = value
            write_index = write_index + 1
        end
    end

    for index = write_index, #bucket do
        bucket[index] = nil
    end

    if write_index == 1 then
        runtime.charge_buckets[due_tick] = nil
    end

    return removed
end

local function clear_pending_charge(runtime, unit_number)
    -- A charged shot can be in the immediate queue or delayed bucket. Any tank
    -- removal path must clear both so stale unit numbers cannot discharge later.
    local removed = scheduler.queue_remove_value(runtime.charge_queue, unit_number) and 1 or 0
    local pending_tick = runtime.pending_by_unit[unit_number]
    runtime.pending_by_unit[unit_number] = nil

    if pending_tick ~= nil then
        removed = removed + remove_unit_from_delayed_charge_bucket(runtime, unit_number, pending_tick)
    else
        for bucket_tick in pairs(runtime.charge_buckets) do
            removed = removed + remove_unit_from_delayed_charge_bucket(runtime, unit_number, bucket_tick)
        end
    end

    if removed > 0 then
        recalculate_next_charge_due(runtime)
        runtime.pending_work_tick = nil
        runtime.pending_work_count = nil
    end

    return removed
end

local function clear_render(render_object)
    if render_object and render_object.valid then
        render_object.destroy()
    end
end

local function invalidate_pending_work_cache(runtime)
    -- control.lua can ask for pending work more than once in a tick. Mutating
    -- events clear the cached answer so charge timing remains exact.
    runtime.pending_work_tick = nil
    runtime.pending_work_count = nil
end

local function queue_hover_unit(runtime, unit_number)
    unit_number = tonumber(unit_number) or nil
    if not unit_number then
        return false
    end

    runtime.hover_queue = scheduler.ensure_queue(runtime.hover_queue)
    local pushed = scheduler.queue_push_unique(runtime.hover_queue, unit_number, unit_number)
    return pushed == true
end

local function queue_motion_unit(runtime, unit_number)
    unit_number = tonumber(unit_number) or nil
    if not unit_number then
        return false
    end

    runtime.motion_queue = scheduler.ensure_queue(runtime.motion_queue)
    local pushed = scheduler.queue_push_unique(runtime.motion_queue, unit_number, unit_number)
    if pushed then
        invalidate_pending_work_cache(runtime)
    end
    return pushed == true
end

local function set_hover_active(runtime, record, entity, current_tick, active)
    -- Occupancy events are the cheap front door for hover visuals. Once active,
    -- each tank self-requeues; the slow repair sweep is only a backstop.
    if not record then
        return false
    end

    local unit_number = tonumber(record.unit_number) or nil
    if not unit_number then
        return false
    end

    if active == true then
        if record.hover_active ~= true then
            record.hover_active = true
            runtime.hover_active_count = (tonumber(runtime.hover_active_count) or 0) + 1
            bump(runtime, "hover_activations", 1)
            local position = entity and entity.position
            if position then
                record.last_hover_x = position.x
                record.last_hover_y = position.y
                record.last_hover_emit_tick = math.max(0, (tonumber(current_tick) or 0) - 9999)
            end
        else
            record.hover_active = true
        end
        return queue_hover_unit(runtime, unit_number)
    end

    if record.hover_active == true then
        runtime.hover_active_count = math.max(0, (tonumber(runtime.hover_active_count) or 0) - 1)
        bump(runtime, "hover_deactivations", 1)
    end
    record.hover_active = false
    scheduler.queue_remove_value(runtime.hover_queue, unit_number)

    local position = entity and entity.position
    if position then
        record.last_hover_x = position.x
        record.last_hover_y = position.y
    end
    return false
end

local function sync_hover_activity(runtime, record, entity, current_tick)
    return set_hover_active(runtime, record, entity, current_tick, tank_has_player_occupant(entity))
end

local function remove_record(runtime, unit_number, reason)
    unit_number = tonumber(unit_number) or nil
    if not unit_number then
        return false
    end

    local record = runtime.tanks_by_unit[unit_number]
    if not record then
        return false
    end

    if record.registration_number then
        runtime.registrations[record.registration_number] = nil
    end
    if record.hover_active == true then
        runtime.hover_active_count = math.max(0, (tonumber(runtime.hover_active_count) or 0) - 1)
    end
    gui.close_open_guis_for_unit(runtime, unit_number)
    orbital_shards.remove_tank(runtime, unit_number)
    runtime.tanks_by_unit[unit_number] = nil
    runtime.tank_settings_by_unit[unit_number] = nil
    clear_pending_charge(runtime, unit_number)
    scheduler.queue_remove_value(runtime.motion_queue, unit_number)
    scheduler.queue_remove_value(runtime.hover_queue, unit_number)
    bump(runtime, reason == "invalid" and "invalid_purges" or "deregistered", 1)
    return true
end

local function register_tank(runtime, entity, current_tick)
    -- Idempotent registration is called from build, clone, damage, driving, and
    -- script-trigger paths. It refreshes identity, queues motion, repairs fixed
    -- equipment, and reattaches object-destroyed tracking.
    if not is_tank(entity) then
        return nil
    end

    local unit_number = ei_lib.get_entity_unit_number(entity)
    if not unit_number then
        return nil
    end

    local record = runtime.tanks_by_unit[unit_number]
    if not record then
        record = {
            unit_number = unit_number,
            last_seen_tick = current_tick,
            cooldown_until_tick = 0,
        }
        runtime.tanks_by_unit[unit_number] = record
        bump(runtime, "registered", 1)
    end

    record.entity = entity
    record.surface_index = entity.surface and entity.surface.index or nil
    record.force_index = entity.force and entity.force.index or nil
    record.last_seen_tick = current_tick
    record.drift_x = tonumber(record.drift_x) or 0
    record.drift_y = tonumber(record.drift_y) or 0
    record.last_motion_x = tonumber(record.last_motion_x) or entity.position.x
    record.last_motion_y = tonumber(record.last_motion_y) or entity.position.y
    record.last_safe_x = tonumber(record.last_safe_x) or entity.position.x
    record.last_safe_y = tonumber(record.last_safe_y) or entity.position.y
    record.last_safe_orientation = tonumber(record.last_safe_orientation) or entity.orientation
    record.last_motion_speed = tonumber(record.last_motion_speed) or 0
    record.last_motion_tick = tonumber(record.last_motion_tick) or current_tick
    record.motion_idle_ticks = math.max(0, math.floor(tonumber(record.motion_idle_ticks) or 0))
    record.movement_equipment_factor = tonumber(record.movement_equipment_factor) or 1
    record.movement_equipment_factor_tick = tonumber(record.movement_equipment_factor_tick) or -1
    record.last_hover_x = tonumber(record.last_hover_x) or entity.position.x
    record.last_hover_y = tonumber(record.last_hover_y) or entity.position.y
    record.last_hover_emit_tick = tonumber(record.last_hover_emit_tick) or 0
    queue_motion_unit(runtime, unit_number)
    sync_hover_activity(runtime, record, entity, current_tick)
    orbital_shards.register_tank(runtime, record, entity, current_tick)
    set_orbital_shard_damage_status(
        runtime,
        entity,
        orbital_shards.get_force_cache(runtime, entity.force, current_tick),
        current_tick
    )

    if not record.registration_number then
        local registration_number = script.register_on_object_destroyed(entity)
        record.registration_number = registration_number
        runtime.registrations[registration_number] = {kind = "tank", unit_number = unit_number}
    end

    local repairs = ensure_equipment(entity)
    if repairs > 0 then
        bump(runtime, "grid_repairs", repairs)
    end

    return record
end

function gui.get_root(player)
    if not (player and player.valid and player.gui and player.gui.relative) then
        return nil
    end

    return player.gui.relative[GUI_NAME]
end

function gui.destroy_root(player)
    local root = gui.get_root(player)
    if root and root.valid then
        root.destroy()
        return true
    end
    return false
end

function gui.get_tank_entity_by_unit(runtime, unit_number)
    unit_number = tonumber(unit_number) or nil
    local record = unit_number and runtime.tanks_by_unit[unit_number] or nil
    local entity = ei_lib.get_valid_entity(record and record.entity)
    if is_tank(entity) then
        return entity, record
    end
    return nil, record
end

function gui.ensure_tank_shard_settings(runtime, unit_number)
    unit_number = tonumber(unit_number) or nil
    if not unit_number then
        return nil
    end

    runtime.tank_settings_by_unit = type(runtime.tank_settings_by_unit) == "table"
        and runtime.tank_settings_by_unit
        or {}
    local settings = runtime.tank_settings_by_unit[unit_number]
    if type(settings) ~= "table" then
        settings = {
            shard_count_override = nil,
            targeting_mode = TARGETING_MODE_INDIVIDUAL,
            doctrine_toggles = {},
        }
        runtime.tank_settings_by_unit[unit_number] = settings
    end

    settings.targeting_mode = normalize_targeting_mode(settings.targeting_mode)
    if type(settings.doctrine_toggles) ~= "table" then
        settings.doctrine_toggles = {}
    else
        for key, value in pairs(settings.doctrine_toggles) do
            if DOCTRINE.toggle_keys[key] then
                settings.doctrine_toggles[key] = value == true
            else
                settings.doctrine_toggles[key] = nil
            end
        end
    end
    if settings.shard_count_override ~= nil then
        settings.shard_count_override = math.max(0, math.floor(tonumber(settings.shard_count_override) or 0))
    end
    return settings
end

function gui.get_tank_shard_readout(runtime, entity, current_tick)
    current_tick = resolve_tick(current_tick)
    local force_cache = orbital_shards.get_force_cache(runtime, entity.force, current_tick)
    return orbital_shards.get_effective_damage(runtime, entity.force, entity, current_tick, force_cache)
end

function model.doctrine_toggle_is_enabled(cache, settings, key)
    if not (cache and cache.recursion_unlocked == true and DOCTRINE.toggle_keys[key]) then
        return false
    end

    settings = type(settings) == "table" and settings or {}
    local toggles = type(settings.doctrine_toggles) == "table" and settings.doctrine_toggles or {}
    if toggles[key] == nil then
        return true
    end
    return toggles[key] == true
end

function model.get_tank_settings_for_entity(runtime, entity)
    local unit_number = ei_lib.get_entity_unit_number(entity)
    return unit_number and gui.ensure_tank_shard_settings(runtime, unit_number) or nil
end

function model.get_tank_doctrine(runtime, entity, current_tick)
    local cache = model.get_doctrine_force_cache(runtime, entity and entity.force or nil, current_tick)
    local settings = entity and model.get_tank_settings_for_entity(runtime, entity) or nil
    local toggles = {}
    for _, key in ipairs(DOCTRINE.toggle_options) do
        toggles[key] = model.doctrine_toggle_is_enabled(cache, settings, key)
    end

    return cache, settings, toggles
end

function model.doctrine_toggle_for_entity(runtime, entity, current_tick, key)
    if not DOCTRINE.toggle_keys[key] then
        return false, model.get_doctrine_force_cache(runtime, entity and entity.force or nil, current_tick)
    end

    local cache = model.get_doctrine_force_cache(runtime, entity and entity.force or nil, current_tick)
    local unit_number = entity and ei_lib.get_entity_unit_number(entity) or nil
    local settings = unit_number
        and type(runtime.tank_settings_by_unit) == "table"
        and runtime.tank_settings_by_unit[unit_number]
        or nil
    return model.doctrine_toggle_is_enabled(cache, settings, key), cache
end

function model.make_shot_profile(runtime, entity, current_tick)
    local cache, _, toggles = model.get_tank_doctrine(runtime, entity, current_tick)
    local collapse = cache.collapse or DOCTRINE.collapse_profiles[0]
    local damage_multiplier = toggles.unseal_impact and DOCTRINE.unsealed_impact_damage_multiplier or 1
    return {
        charge_level = cache.charge_level or 0,
        inertial_level = cache.inertial_level or 0,
        collapse_level = cache.collapse_level or 0,
        vector_keel_level = cache.vector_keel_level or 0,
        charge_ticks = cache.charge_ticks or CHARGE_TICKS,
        post_fire_cooldown = cache.post_fire_cooldown or POST_FIRE_COOLDOWN,
        charge_sound = cache.charge_sound or CHARGE_START_SOUND,
        line_damage = DAMAGE_AMOUNT,
        line_half_width = LINE_HALF_WIDTH,
        impact_radius = collapse.radius or IMPACT_RADIUS,
        impact_center_damage = collapse.center_damage or IMPACT_CENTER_DAMAGE,
        impact_edge_damage = collapse.edge_damage or IMPACT_EDGE_DAMAGE,
        impact_damage_multiplier = damage_multiplier,
        recoil_impulse = MOTION_RECOIL_IMPULSE,
        reclaim_charges = toggles.reclaim_charges == true,
        keel_wake = toggles.keel_wake == true,
        branch_scars = toggles.branch_scars == true,
        split_wake = toggles.split_wake == true,
        unseal_impact = toggles.unseal_impact == true,
    }
end

function model.snapshot_shot_profile(profile)
    return model.shallow_copy_table(profile or {})
end

function gui.get_tank_doctrine_readout(runtime, entity, current_tick)
    local cache, settings, toggles = model.get_tank_doctrine(runtime, entity, current_tick)
    return {
        cache = cache,
        settings = settings,
        toggles = toggles,
        charge_ticks = cache.charge_ticks or CHARGE_TICKS,
        post_fire_cooldown = cache.post_fire_cooldown or POST_FIRE_COOLDOWN,
        recursion_unlocked = cache.recursion_unlocked == true,
    }
end

function gui.prune_orphaned_tank_settings(runtime)
    local pruned = 0
    if type(runtime.tank_settings_by_unit) ~= "table" then
        runtime.tank_settings_by_unit = {}
        return pruned
    end

    for unit_number in pairs(runtime.tank_settings_by_unit) do
        if not runtime.tanks_by_unit[unit_number] then
            runtime.tank_settings_by_unit[unit_number] = nil
            pruned = pruned + 1
        end
    end
    return pruned
end

function gui.style_width(element, width)
    if element and element.valid then
        pcall(function()
            element.style.width = width
        end)
    end
end

function gui.add_status_row(parent, name, caption)
    local flow = parent.add{type = "flow", name = name, direction = "horizontal"}
    flow.add{type = "label", caption = caption}
    flow.add{type = "empty-widget", style = "ei_horizontal_pusher", ignored_by_interaction = true}
    flow.add{type = "label", name = "readout"}
    return flow
end

function gui.add_shard_button(parent, name, caption, tags, width)
    local button = parent.add{
        type = "button",
        name = name,
        caption = caption,
        tags = tags,
    }
    gui.style_width(button, width or 36)
    return button
end

function gui.build(player, entity, readout, current_tick)
    gui.destroy_root(player)

    local unit_number = ei_lib.get_entity_unit_number(entity)
    local root = player.gui.relative.add{
        type = "frame",
        name = GUI_NAME,
        anchor = {
            gui = defines.relative_gui_type.car_gui,
            name = TANK_NAME,
            position = defines.relative_gui_position.right,
        },
        direction = "vertical",
        tags = {parent_gui = GUI_NAME, unit_number = unit_number},
    }

    local titlebar = root.add{type = "flow", direction = "horizontal"}
    titlebar.add{
        type = "label",
        caption = {"exotic-industries.ei-emerald-apocalypse-shard-gui-title"},
        style = "frame_title",
    }
    titlebar.add{
        type = "empty-widget",
        style = "ei_titlebar_nondraggable_spacer",
        ignored_by_interaction = true,
    }

    local main = root.add{
        type = "frame",
        name = "main-container",
        direction = "vertical",
        style = "inside_shallow_frame",
    }

    main.add{type = "frame", style = "ei_subheader_frame"}.add{
        type = "label",
        caption = {"exotic-industries.ei-emerald-apocalypse-shard-gui-status-title"},
        style = "subheader_caption_label",
    }

    local status_flow = main.add{
        type = "flow",
        name = "status-flow",
        direction = "vertical",
        style = "ei_inner_content_flow",
    }
    gui.add_status_row(status_flow, "active-row", {"exotic-industries.ei-emerald-apocalypse-shard-gui-active"})
    gui.add_status_row(status_flow, "targeting-row", {"exotic-industries.ei-emerald-apocalypse-shard-gui-targeting"})
    gui.add_status_row(status_flow, "dps-row", {"exotic-industries.ei-emerald-apocalypse-shard-gui-dps"})

    main.add{type = "frame", style = "ei_subheader_frame_with_top_border"}.add{
        type = "label",
        caption = {"exotic-industries.ei-emerald-apocalypse-shard-gui-control-title"},
        style = "subheader_caption_label",
    }

    local control_flow = main.add{
        type = "flow",
        name = "control-flow",
        direction = "vertical",
        style = "ei_inner_content_flow",
    }
    local count_flow = control_flow.add{type = "flow", name = "count-flow", direction = "horizontal"}
    gui.add_shard_button(count_flow, "set-zero", "0", {
        parent_gui = GUI_NAME,
        action = "set-shard-count",
        unit_number = unit_number,
        value = 0,
    }, 32)
    gui.add_shard_button(count_flow, "decrease", "-", {
        parent_gui = GUI_NAME,
        action = "adjust-shard-count",
        unit_number = unit_number,
        value = -1,
    }, 32)
    count_flow.add{type = "label", name = "shard-count-value", caption = tostring(readout.active_shard_count or 0)}
    gui.add_shard_button(count_flow, "increase", "+", {
        parent_gui = GUI_NAME,
        action = "adjust-shard-count",
        unit_number = unit_number,
        value = 1,
    }, 32)
    gui.add_shard_button(count_flow, "set-max", {"exotic-industries.ei-emerald-apocalypse-shard-gui-max"}, {
        parent_gui = GUI_NAME,
        action = "set-shard-count",
        unit_number = unit_number,
        value = "max",
    }, 54)

    local targeting_flow = control_flow.add{type = "flow", name = "targeting-flow", direction = "horizontal"}
    targeting_flow.add{
        type = "button",
        name = "split-mode",
        caption = {"exotic-industries.ei-emerald-apocalypse-shard-gui-split"},
        tags = {
            parent_gui = GUI_NAME,
            action = "set-targeting-mode",
            unit_number = unit_number,
            value = TARGETING_MODE_INDIVIDUAL,
        },
    }
    targeting_flow.add{
        type = "button",
        name = "focus-mode",
        caption = {"exotic-industries.ei-emerald-apocalypse-shard-gui-focus"},
        tags = {
            parent_gui = GUI_NAME,
            action = "set-targeting-mode",
            unit_number = unit_number,
            value = TARGETING_MODE_FOCUS_FIRE,
        },
    }

    main.add{type = "frame", style = "ei_subheader_frame_with_top_border"}.add{
        type = "label",
        caption = {"exotic-industries.ei-emerald-apocalypse-doctrine-gui-title"},
        style = "subheader_caption_label",
    }

    local doctrine_status_flow = main.add{
        type = "flow",
        name = "doctrine-status-flow",
        direction = "vertical",
        style = "ei_inner_content_flow",
    }
    gui.add_status_row(doctrine_status_flow, "charge-row", {"exotic-industries.ei-emerald-apocalypse-doctrine-gui-charge"})
    gui.add_status_row(doctrine_status_flow, "cooldown-row", {"exotic-industries.ei-emerald-apocalypse-doctrine-gui-cooldown"})
    gui.add_status_row(doctrine_status_flow, "recursion-row", {"exotic-industries.ei-emerald-apocalypse-doctrine-gui-recursion"})

    local doctrine_toggle_flow = main.add{
        type = "flow",
        name = "doctrine-toggle-flow",
        direction = "vertical",
        style = "ei_inner_content_flow",
    }
    for _, option in ipairs(DOCTRINE.toggle_options) do
        doctrine_toggle_flow.add{
            type = "button",
            name = "toggle-"..option,
            caption = {"exotic-industries.ei-emerald-apocalypse-doctrine-toggle-"..(DOCTRINE.toggle_locale[option] or option)},
            tooltip = {"exotic-industries.ei-emerald-apocalypse-doctrine-toggle-"..(DOCTRINE.toggle_locale[option] or option).."-tooltip"},
            tags = {
                parent_gui = GUI_NAME,
                action = "toggle-doctrine-option",
                unit_number = unit_number,
                value = option,
            },
        }
    end

    model.update_gui(player, current_tick)
    return root
end

function model.update_gui(player, current_tick)
    if not (player and player.valid) then
        return false
    end

    local runtime = ensure_runtime()
    local unit_number = runtime.open_by_player[player.index]
    local entity = gui.get_tank_entity_by_unit(runtime, unit_number)
    local root = gui.get_root(player)
    if not (root and entity) then
        model.close_gui(player)
        return false
    end

    current_tick = resolve_tick(current_tick)
    local readout = gui.get_tank_shard_readout(runtime, entity, current_tick)
    local doctrine_readout = gui.get_tank_doctrine_readout(runtime, entity, current_tick)
    local max_count = readout.max_shard_count or readout.shard_count or 0
    local active_count = readout.active_shard_count or readout.shard_count or 0
    local targeting_mode = normalize_targeting_mode(readout.targeting_mode)
    local main = root["main-container"]
    if not main then
        gui.build(player, entity, readout, current_tick)
        return true
    end
    if not main["doctrine-status-flow"] or not main["doctrine-toggle-flow"] then
        gui.build(player, entity, readout, current_tick)
        return true
    end

    local status_flow = main["status-flow"]
    if status_flow then
        status_flow["active-row"]["readout"].caption = {
            "exotic-industries.ei-emerald-apocalypse-shard-gui-active-value",
            active_count,
            max_count,
        }
        status_flow["targeting-row"]["readout"].caption = targeting_mode == TARGETING_MODE_FOCUS_FIRE
            and {"exotic-industries.ei-emerald-apocalypse-shard-gui-focus"}
            or {"exotic-industries.ei-emerald-apocalypse-shard-gui-split"}
        status_flow["dps-row"]["readout"].caption = {
            "exotic-industries.ei-emerald-apocalypse-shard-gui-dps-value",
            format_damage_number(readout.swarm_dps),
            {"damage-type-name."..(readout.damage_type or DAMAGE_TYPE)},
        }
    end

    local control_flow = main["control-flow"]
    if control_flow then
        local count_flow = control_flow["count-flow"]
        if count_flow then
            count_flow["shard-count-value"].caption = tostring(active_count)
            for _, name in pairs({"set-zero", "decrease", "increase", "set-max"}) do
                if count_flow[name] then
                    local tags = count_flow[name].tags or {}
                    tags.unit_number = unit_number
                    count_flow[name].tags = tags
                end
            end
        end

        local targeting_flow = control_flow["targeting-flow"]
        if targeting_flow then
            targeting_flow["split-mode"].style = targeting_mode == TARGETING_MODE_INDIVIDUAL
                and "ei_small_green_button"
                or "ei_small_button"
            targeting_flow["focus-mode"].style = targeting_mode == TARGETING_MODE_FOCUS_FIRE
                and "ei_small_green_button"
                or "ei_small_button"
            targeting_flow["split-mode"].tags = {
                parent_gui = GUI_NAME,
                action = "set-targeting-mode",
                unit_number = unit_number,
                value = TARGETING_MODE_INDIVIDUAL,
            }
            targeting_flow["focus-mode"].tags = {
                parent_gui = GUI_NAME,
                action = "set-targeting-mode",
                unit_number = unit_number,
                value = TARGETING_MODE_FOCUS_FIRE,
            }
        end
    end

    local doctrine_status_flow = main["doctrine-status-flow"]
    if doctrine_status_flow then
        doctrine_status_flow["charge-row"]["readout"].caption = {
            "exotic-industries.ei-emerald-apocalypse-doctrine-gui-seconds",
            model.format_seconds_from_ticks(doctrine_readout.charge_ticks or CHARGE_TICKS),
        }
        doctrine_status_flow["cooldown-row"]["readout"].caption = {
            "exotic-industries.ei-emerald-apocalypse-doctrine-gui-seconds",
            model.format_seconds_from_ticks(doctrine_readout.post_fire_cooldown or POST_FIRE_COOLDOWN),
        }
        doctrine_status_flow["recursion-row"]["readout"].caption = doctrine_readout.recursion_unlocked
            and {"exotic-industries.ei-emerald-apocalypse-doctrine-gui-unsealed"}
            or {"exotic-industries.ei-emerald-apocalypse-doctrine-gui-sealed"}
    end

    local doctrine_toggle_flow = main["doctrine-toggle-flow"]
    if doctrine_toggle_flow then
        for _, option in ipairs(DOCTRINE.toggle_options) do
            local button = doctrine_toggle_flow["toggle-"..option]
            if button then
                local enabled = doctrine_readout.toggles and doctrine_readout.toggles[option] == true
                button.enabled = doctrine_readout.recursion_unlocked == true
                button.style = enabled and "ei_small_green_button" or "ei_small_button"
                button.tags = {
                    parent_gui = GUI_NAME,
                    action = "toggle-doctrine-option",
                    unit_number = unit_number,
                    value = option,
                }
            end
        end
    end

    return true
end

function model.open_gui(player, entity, event_or_tick)
    if not (player and player.valid) then
        return false
    end

    entity = ei_lib.get_valid_entity(entity or player.opened)
    if not is_tank(entity) then
        return false
    end

    local runtime = ensure_runtime()
    local current_tick = resolve_tick(event_or_tick)
    local record = register_tank(runtime, entity, current_tick)
    if not record then
        return false
    end

    runtime.open_by_player[player.index] = record.unit_number
    local readout = gui.get_tank_shard_readout(runtime, entity, current_tick)
    gui.build(player, entity, readout, current_tick)
    return true
end

function model.close_gui(player)
    if not (player and player.valid) then
        return false
    end

    local runtime = ensure_runtime()
    runtime.open_by_player[player.index] = nil
    return gui.destroy_root(player)
end

function gui.close_open_guis_for_unit(runtime, unit_number)
    unit_number = tonumber(unit_number) or nil
    if not unit_number or not game or not game.players then
        return 0
    end

    local closed = 0
    for _, player in pairs(game.players) do
        if player and player.valid and runtime.open_by_player[player.index] == unit_number then
            if gui.destroy_root(player) then
                closed = closed + 1
            end
            runtime.open_by_player[player.index] = nil
        end
    end
    return closed
end

function gui.close_all(runtime)
    if game and game.players then
        for _, player in pairs(game.players) do
            if player and player.valid then
                gui.destroy_root(player)
            end
        end
    end
    if type(runtime) == "table" then
        runtime.open_by_player = {}
    end
end

function gui.refresh_open_guis_for_force(runtime, force, current_tick)
    if not (game and game.players) then
        return 0
    end

    local refreshed = 0
    for player_index, unit_number in pairs(runtime.open_by_player) do
        local player = game.get_player(player_index)
        local entity = gui.get_tank_entity_by_unit(runtime, unit_number)
        if player and player.valid and entity and (not force or entity.force == force) then
            if model.update_gui(player, current_tick) then
                refreshed = refreshed + 1
            end
        elseif player and player.valid and gui.get_root(player) then
            model.close_gui(player)
        end
    end
    return refreshed
end

function model.on_gui_opened(event)
    local player = game and event and game.get_player(event.player_index) or nil
    local entity = ei_lib.get_valid_entity(event and event.entity) or (player and ei_lib.get_valid_entity(player.opened) or nil)
    if not is_tank(entity) then
        return false
    end

    return model.open_gui(player, entity, event)
end

function model.on_gui_closed(event)
    local player = game and event and game.get_player(event.player_index) or nil
    if not (player and player.valid) then
        return false
    end

    local entity = ei_lib.get_valid_entity(event and event.entity)
    local element = event and event.element
    local element_name = element and element.valid and element.name or nil
    if is_tank(entity) or element_name == GUI_NAME or gui.get_root(player) then
        return model.close_gui(player)
    end
    return false
end

function model.on_gui_click(event)
    local element = event and event.element
    if not (element and element.valid) then
        return false
    end

    local tags = element.tags or {}
    if tags.parent_gui ~= GUI_NAME then
        return false
    end

    local player = game and event and game.get_player(event.player_index) or nil
    if not (player and player.valid) then
        return false
    end

    local runtime = ensure_runtime()
    local unit_number = tonumber(tags.unit_number) or runtime.open_by_player[player.index]
    local entity = gui.get_tank_entity_by_unit(runtime, unit_number)
    if not entity then
        model.close_gui(player)
        return false
    end

    local current_tick = resolve_tick(event)
    local readout = gui.get_tank_shard_readout(runtime, entity, current_tick)
    local max_count = readout.max_shard_count or readout.shard_count or 0
    local active_count = readout.active_shard_count or readout.shard_count or 0
    local settings = gui.ensure_tank_shard_settings(runtime, unit_number)
    if not settings then
        return false
    end

    if tags.action == "set-shard-count" then
        if tags.value == "max" then
            -- nil means auto/max, so later shard-manifold research keeps this
            -- tank following the researched maximum instead of pinning old DPS.
            settings.shard_count_override = nil
        else
            settings.shard_count_override = ei_lib.clamp_integer(tonumber(tags.value), 0, max_count, max_count)
        end
    elseif tags.action == "adjust-shard-count" then
        settings.shard_count_override = ei_lib.clamp_integer(
            active_count + (tonumber(tags.value) or 0),
            0,
            max_count,
            active_count)
    elseif tags.action == "set-targeting-mode" then
        settings.targeting_mode = normalize_targeting_mode(tags.value)
    elseif tags.action == "toggle-doctrine-option" then
        local key = tostring(tags.value or "")
        if not DOCTRINE.toggle_keys[key] then
            return false
        end

        local cache = model.get_doctrine_force_cache(runtime, entity.force, current_tick)
        if cache.recursion_unlocked ~= true then
            return false
        end

        settings.doctrine_toggles[key] = not model.doctrine_toggle_is_enabled(cache, settings, key)
    else
        return false
    end

    register_tank(runtime, entity, current_tick)
    gui.refresh_open_guis_for_force(runtime, entity.force, current_tick)
    return true
end

function model.on_gui_value_changed(event)
    local element = event and event.element
    if element and element.valid and element.tags and element.tags.parent_gui == GUI_NAME then
        return model.on_gui_click(event)
    end
    return false
end

function model.on_player_left_game(event_or_player_index)
    local player_index = type(event_or_player_index) == "table"
        and event_or_player_index.player_index
        or event_or_player_index
    local player = game and game.get_player(player_index) or nil
    local runtime = ensure_runtime()
    local current_tick = resolve_tick(event_or_player_index)
    runtime.open_by_player[player_index] = nil
    if player and player.valid then
        gui.destroy_root(player)
    end
    model.maybe_status(runtime, current_tick)
    return true
end

local function consume_charge_item(entity)
    -- The vehicle gun has already consumed one stack-size-1 charge before the
    -- script-trigger effect reaches runtime. Runtime records that consumption
    -- but must not pull a second charge from the trunk or ammo inventory.
    return ei_lib.entity_check(entity)
end

function model.refund_charge_item(runtime, entity, success_counter_name, failure_counter_name)
    if not is_tank(entity) then
        bump(runtime, failure_counter_name or "charge_refund_failures", 1)
        return false
    end

    local ok, inserted = pcall(function()
        return entity.insert{name = CHARGE_ITEM, count = 1}
    end)
    if ok and (tonumber(inserted) or 0) >= 1 then
        bump(runtime, success_counter_name or "charge_refunds", 1)
        return true
    end

    bump(runtime, failure_counter_name or "charge_refund_failures", 1)
    return false
end

local function normalize_vector(dx, dy, fallback_orientation)
    local length = math.sqrt((dx * dx) + (dy * dy))
    if length > 0.0001 then
        return dx / length, dy / length
    end

    local angle = (fallback_orientation or 0) * TAU
    return math.sin(angle), -math.cos(angle)
end

local function orientation_vector(orientation)
    local angle = (tonumber(orientation) or 0) * TAU
    return math.sin(angle), -math.cos(angle)
end

local function vector_length(dx, dy)
    return math.sqrt((dx * dx) + (dy * dy))
end

local function clamp_vector(dx, dy, max_length)
    local length = vector_length(dx, dy)
    if length <= max_length or length <= 0 then
        return dx, dy, length
    end

    local scale = max_length / length
    return dx * scale, dy * scale, max_length
end

local function apply_counter_thrust(dx, dy, amount)
    local length = vector_length(dx, dy)
    if length <= amount then
        return 0, 0
    end

    local scale = (length - amount) / length
    return dx * scale, dy * scale
end

function model.read_entity_speed(entity)
    if not ei_lib.entity_check(entity) then
        return 0
    end

    local ok, speed = pcall(function()
        return entity.speed
    end)
    return ok and (tonumber(speed) or 0) or 0
end

function model.neutralize_native_vehicle_speed(runtime, entity, observed_speed)
    if not ei_lib.entity_check(entity) then
        return false
    end

    local speed = observed_speed
    if speed == nil then
        speed = model.read_entity_speed(entity)
    end

    local ok = pcall(function()
        entity.speed = 0
    end)
    if ok and math.abs(tonumber(speed) or 0) > 0.00001 then
        bump(runtime, "motion_native_speed_resets", 1)
    end
    return ok
end

function model.read_equipment_movement_bonus(equipment)
    if not equipment then
        return 0
    end

    local ok, direct_bonus = pcall(function()
        return equipment.movement_bonus
    end)
    if ok and tonumber(direct_bonus) then
        return math.max(0, tonumber(direct_bonus))
    end

    local prototype_ok, prototype = pcall(function()
        return equipment.prototype
    end)
    if not prototype_ok or not prototype then
        return 0
    end

    local bonus_ok, prototype_bonus = pcall(function()
        return prototype.movement_bonus
    end)
    if bonus_ok and tonumber(prototype_bonus) then
        return math.max(0, tonumber(prototype_bonus))
    end

    return 0
end

function model.equipment_has_power_for_movement(equipment)
    if not equipment then
        return false
    end

    local max_ok, max_energy = pcall(function()
        return equipment.max_energy
    end)
    max_energy = max_ok and (tonumber(max_energy) or 0) or 0
    if max_energy <= 0 then
        return true
    end

    local energy_ok, energy = pcall(function()
        return equipment.energy
    end)
    energy = energy_ok and (tonumber(energy) or 0) or 0
    return energy >= max_energy * 0.01
end

function model.tank_movement_equipment_factor(record, entity, current_tick)
    -- Movement-bonus equipment multiplies native vehicle acceleration. The
    -- Emerald tank's drift is script-owned, so translate that bonus into the
    -- scripted thrust profile instead of letting native car physics double dip.
    local cached_tick = tonumber(record and record.movement_equipment_factor_tick) or -1
    if record and current_tick and current_tick - cached_tick < 30 then
        return tonumber(record.movement_equipment_factor) or 1
    end

    local grid = get_grid(entity)
    if not grid then
        if record then
            record.movement_equipment_factor = 1
            record.movement_equipment_factor_tick = current_tick
        end
        return 1
    end

    local total_bonus = 0
    for _, equipment in pairs(get_grid_equipment(grid)) do
        local bonus = model.read_equipment_movement_bonus(equipment)
        if bonus > 0 and model.equipment_has_power_for_movement(equipment) then
            total_bonus = total_bonus + bonus
        end
        if total_bonus >= 0.75 then
            total_bonus = 0.75
            break
        end
    end

    local factor = 1 + ei_lib.clamp_number(total_bonus, 0, 0.75, 0)
    if record then
        record.movement_equipment_factor = factor
        record.movement_equipment_factor_tick = current_tick
    end
    return factor
end

local function tank_has_available_thrust(entity)
    -- Hover locomotion remains fuel-gated. Equipment movement bonuses are read
    -- separately by the scripted drift controller.
    if not ei_lib.entity_check(entity) then
        return false
    end

    local burner = entity.burner
    if burner then
        if burner.currently_burning then
            return true
        end
        if (tonumber(burner.remaining_burning_fuel) or 0) > 0 then
            return true
        end
    end

    local ok, inventory = pcall(function()
        return entity.get_fuel_inventory and entity.get_fuel_inventory()
    end)
    if ok and inventory and inventory.valid then
        local empty_ok, empty = pcall(function()
            return inventory.is_empty()
        end)
        return not empty_ok or empty ~= true
    end

    return burner == nil
end

local function get_riding_acceleration(entity)
    local state = entity.riding_state
    return state and state.acceleration or nil
end

local function set_neutral_riding_state(entity)
    if not ei_lib.entity_check(entity) then
        return false
    end

    local riding = defines and defines.riding
    local neutral_acceleration = riding and riding.acceleration and riding.acceleration.nothing or nil
    local straight_direction = riding and riding.direction and riding.direction.straight or nil
    if neutral_acceleration == nil or straight_direction == nil then
        return false
    end

    local ok = pcall(function()
        entity.riding_state = {
            acceleration = neutral_acceleration,
            direction = straight_direction,
        }
    end)
    return ok
end

local function is_acceleration(acceleration, name)
    return defines
        and defines.riding
        and defines.riding.acceleration
        and acceleration == defines.riding.acceleration[name]
end

local function drift_speed(record)
    return vector_length(tonumber(record.drift_x) or 0, tonumber(record.drift_y) or 0)
end

local function get_aim_vector(entity)
    -- The weapon is a hull-fixed cannon. Target selection only starts the charge;
    -- the final vector is always the tank's current facing at charge start.
    return normalize_vector(0, 0, entity.orientation)
end

local function relation_is_enemy(source_force, target_force)
    if not source_force or not target_force or source_force == target_force then
        return false
    end

    local ok, friendly = pcall(function()
        return source_force.get_friend(target_force)
    end)
    return not (ok and friendly == true)
end

local function clamp_beam_range(range)
    return ei_lib.clamp_number(range, 0, RANGE, RANGE)
end

local function point_line_distance_sq(position, sx, sy, dx, dy, line_range)
    local px = position.x - sx
    local py = position.y - sy
    local along = (px * dx) + (py * dy)
    if along < 0 or along > line_range then
        return nil
    end

    local side = (px * -dy) + (py * dx)
    return side * side
end

local function get_position_xy(position)
    if type(position) ~= "table" then
        return nil, nil
    end

    return tonumber(position.x or position[1]), tonumber(position.y or position[2])
end

local function get_event_target_position(event)
    if not event then
        return nil
    end

    if event.target_position then
        return event.target_position
    end

    local target_entity = ei_lib.get_valid_entity(event.target_entity)
    return target_entity and target_entity.position or nil
end

local function get_line_range_to_position(entity, dx, dy, position, fallback_range)
    local target_x, target_y = get_position_xy(position)
    if not target_x or not target_y then
        return clamp_beam_range(fallback_range)
    end

    local source = entity.position
    local projection = ((target_x - source.x) * dx) + ((target_y - source.y) * dy)
    if projection <= 0 then
        return 0
    end

    return clamp_beam_range(projection)
end

local function get_target_line_range(entity, dx, dy, event)
    return get_line_range_to_position(entity, dx, dy, get_event_target_position(event), RANGE)
end

local function get_control_shooting_position(control)
    -- There is no persistent cursor target for a delayed shot. Sample the live
    -- shooting state at discharge and fall back to charge-start range if needed.
    if not control then
        return nil
    end

    local ok, shooting_state = pcall(function()
        return control.shooting_state
    end)
    if not ok or type(shooting_state) ~= "table" then
        return nil
    end

    if defines
        and defines.shooting
        and shooting_state.state == defines.shooting.not_shooting then
        return nil
    end

    local target_x, target_y = get_position_xy(shooting_state.position)
    if not target_x or not target_y then
        return nil
    end

    return {x = target_x, y = target_y}
end

local function get_vehicle_driver(entity)
    local ok, driver = pcall(function()
        return entity and entity.get_driver and entity.get_driver()
    end)
    return ok and driver or nil
end

local function get_late_fire_target_position(entity, record)
    -- Factorio only gives us the script-trigger target at charge start, but
    -- LuaControl.shooting_state exposes the live shot position. Sample that
    -- at discharge so the wind-up judges where the cannon is actually aimed.
    local target_position = get_control_shooting_position(entity)
    if target_position then
        return target_position, "vehicle-shooting-state"
    end

    local driver = get_vehicle_driver(entity)
    target_position = get_control_shooting_position(driver)
    if target_position then
        return target_position, "driver-shooting-state"
    end

    local ok, driver_player = pcall(function()
        return driver and driver.player
    end)
    if ok then
        target_position = get_control_shooting_position(driver_player)
        if target_position then
            return target_position, "driver-player-shooting-state"
        end
    end

    local fallback_x = tonumber(record and record.aim_target_x)
    local fallback_y = tonumber(record and record.aim_target_y)
    if fallback_x and fallback_y then
        return {x = fallback_x, y = fallback_y}, "charge-start-target"
    end

    return nil, "stored-range"
end

local function copy_position(position)
    if not position then
        return nil
    end

    return {
        x = position.x,
        y = position.y,
    }
end

function model.copy_entity_position(entity)
    if not ei_lib.entity_check(entity) then
        return nil
    end

    local ok, position = pcall(function()
        return entity.position
    end)
    if not ok then
        return nil
    end

    return copy_position(position)
end

function model.get_entity_force(entity)
    if not ei_lib.entity_check(entity) then
        return nil
    end

    local ok, force = pcall(function()
        return entity.force
    end)
    return ok and force or nil
end

function model.entity_has_health(entity)
    if not ei_lib.entity_check(entity) then
        return false
    end

    local ok, health = pcall(function()
        return entity.health
    end)
    return ok and health ~= nil
end

function model.copy_entity_name(entity)
    if not ei_lib.entity_check(entity) then
        return nil
    end

    local ok, name = pcall(function()
        return entity.name
    end)
    return ok and name or nil
end

local function rotate_east_facing_sprite_to_orientation(orientation)
    return ((tonumber(orientation) or 0) + 0.75) % 1
end

local function compute_fire_geometry(entity, record)
    -- The cannon is hull-fixed: target selection starts the charge, but final
    -- discharge uses the tank's current orientation and live projected range.
    local dx, dy = get_aim_vector(entity)
    local sampled_target, aim_source = get_late_fire_target_position(entity, record)
    local line_range = get_line_range_to_position(entity, dx, dy, sampled_target, record.aim_range or RANGE)
    local source_position = copy_position(entity.position)
    local muzzle_position = {
        x = source_position.x + dx * MUZZLE_DISTANCE,
        y = source_position.y + dy * MUZZLE_DISTANCE,
    }
    local target_position = {
        x = source_position.x + dx * line_range,
        y = source_position.y + dy * line_range,
    }

    return {
        source_position = source_position,
        muzzle_position = muzzle_position,
        target_position = target_position,
        dx = dx,
        dy = dy,
        line_range = line_range,
        aim_source = aim_source,
        beam_visual_length = math.max(0, line_range - MUZZLE_DISTANCE),
    }
end

local function bump_visual_result(runtime, ok, counter_name)
    if ok then
        bump(runtime, counter_name, 1)
        return true
    end

    bump(runtime, "visual_failures", 1)
    return false
end

local function render_charge_visual(runtime, entity, profile)
    -- Pure presentation: the ammo transaction and delayed attack are already
    -- owned by start_charge()/activate_due_charges().
    if not ei_lib.entity_check(entity) then
        return
    end

    profile = type(profile) == "table" and profile or {}
    local charge_ticks = math.max(1, math.floor(tonumber(profile.charge_ticks) or CHARGE_TICKS))
    local ok, render = pcall(function()
        return rendering.draw_animation{
            animation = CHARGEUP_ANIMATION,
            target = entity,
            surface = entity.surface,
            oriented_offset = {0, -MUZZLE_DISTANCE},
            use_target_orientation = true,
            render_layer = "projectile",
            animation_speed = 60 / charge_ticks,
            x_scale = CHARGEUP_SCALE,
            y_scale = CHARGEUP_SCALE,
            time_to_live = charge_ticks,
            forces = {entity.force},
        }
    end)
    bump_visual_result(runtime, ok and render ~= nil, "chargeup_visuals")

    pcall(function()
        entity.surface.play_sound{
            path = profile.charge_sound or CHARGE_START_SOUND,
            position = entity.position,
        }
    end)
end

local function draw_animation_visual(runtime, surface, force, animation, position, ttl, scale, render_layer, counter_name, orientation)
    local ok, render = pcall(function()
        return rendering.draw_animation{
            animation = animation,
            target = position,
            surface = surface,
            render_layer = render_layer,
            orientation = orientation,
            animation_speed = 1,
            x_scale = scale,
            y_scale = scale,
            time_to_live = ttl,
            forces = {force},
        }
    end)
    return bump_visual_result(runtime, ok and render ~= nil, counter_name)
end

local function create_entity_visual(runtime, surface, force, name, position, counter_name, extra)
    local ok, created = pcall(function()
        local spec = {
            name = name,
            position = position,
            force = force,
        }
        if extra then
            for key, value in pairs(extra) do
                spec[key] = value
            end
        end
        return surface.create_entity(spec)
    end)
    return bump_visual_result(runtime, ok and created ~= nil, counter_name)
end

local function draw_hit_flash_positions(runtime, surface, force, positions, limit, counter_name)
    local flashes = 0
    if type(positions) ~= "table" then
        return 0
    end

    for _, position in ipairs(positions) do
        if flashes >= limit then
            break
        end
        if position then
            draw_animation_visual(
                runtime,
                surface,
                force,
                HIT_FLASH_ANIMATION,
                position,
                HIT_FLASH_TTL,
                HIT_FLASH_SCALE,
                "projectile",
                counter_name
            )
            flashes = flashes + 1
        end
    end

    return flashes
end

local function set_apocalypse_brace(runtime, record, job, geometry, entity)
    if type(record) ~= "table" or type(job) ~= "table" or type(geometry) ~= "table" then
        return false
    end

    record.apocalypse_job_id = job.id
    record.apocalypse_dx = geometry.dx
    record.apocalypse_dy = geometry.dy
    record.apocalypse_orientation = ei_lib.entity_check(entity) and entity.orientation or record.apocalypse_orientation
    queue_motion_unit(runtime, record.unit_number)
    return true
end

function model.endpoint_impact_damage(distance, job)
    job = type(job) == "table" and job or {}
    local radius = math.max(1, tonumber(job.radius) or IMPACT_RADIUS)
    local center_damage = tonumber(job.impact_center_damage) or IMPACT_CENTER_DAMAGE
    local edge_damage = tonumber(job.impact_edge_damage) or IMPACT_EDGE_DAMAGE
    local multiplier = tonumber(job.impact_damage_multiplier) or 1
    local fraction = ei_lib.clamp_number((tonumber(distance) or radius) / radius, 0, 1, 1)
    local damage = edge_damage + (center_damage - edge_damage) * (1 - fraction)
    return math.max(edge_damage, math.floor((damage * multiplier) + 0.5))
end

function model.draw_sustained_apocalypse_beam(runtime, job, current_tick)
    if type(job) ~= "table" then
        return false
    end

    local last_tick = tonumber(job.beam_last_tick) or 0
    if last_tick > 0 and current_tick - last_tick < APOCALYPSE_BEAM_REFRESH_TICKS then
        return false
    end

    local surface = model.get_surface_by_index(job.surface_index)
    local force = game and game.forces and (game.forces[job.force_name or "player"] or game.forces.player) or nil
    if not (surface and surface.valid and force) then
        bump(runtime, "apocalypse_beam_failures", 1)
        bump(runtime, "visual_failures", 1)
        return false
    end

    local dx = tonumber(job.beam_dx) or 0
    local dy = tonumber(job.beam_dy) or 0
    if vector_length(dx, dy) <= 0 then
        dx, dy = orientation_vector(tonumber(job.beam_orientation) or 0)
    end

    local muzzle_position = {
        x = tonumber(job.muzzle_x) or (tonumber(job.impact_x) or 0),
        y = tonumber(job.muzzle_y) or (tonumber(job.impact_y) or 0),
    }
    local record = runtime.tanks_by_unit and runtime.tanks_by_unit[job.source_unit_number] or nil
    local entity = record and ei_lib.get_valid_entity(record.entity) or nil
    if is_tank(entity) then
        local position = entity.position
        muzzle_position = {
            x = position.x + dx * MUZZLE_DISTANCE,
            y = position.y + dy * MUZZLE_DISTANCE,
        }
        job.muzzle_x = muzzle_position.x
        job.muzzle_y = muzzle_position.y
        if record.apocalypse_orientation then
            set_neutral_riding_state(entity)
            pcall(function()
                entity.orientation = record.apocalypse_orientation
            end)
        end
    end

    local target_position = {
        x = tonumber(job.impact_x) or muzzle_position.x,
        y = tonumber(job.impact_y) or muzzle_position.y,
    }
    local beam_length = vector_length(target_position.x - muzzle_position.x, target_position.y - muzzle_position.y)
    if beam_length < MIN_BEAM_VISUAL_LENGTH then
        bump(runtime, "apocalypse_beam_failures", 1)
        return false
    end

    local ok = create_entity_visual(runtime, surface, force, MAIN_BEAM_NAME, muzzle_position, "beam_visuals", {
        source = muzzle_position,
        target = target_position,
        duration = APOCALYPSE_BEAM_SEGMENT_TICKS,
        max_length = beam_length + 1,
    })
    job.beam_last_tick = current_tick
    if ok then
        bump(runtime, "apocalypse_beam_refreshes", 1)
    else
        bump(runtime, "apocalypse_beam_failures", 1)
    end
    return ok
end

function model.draw_endpoint_shockwave(runtime, surface, force, job, previous_radius, wave_radius)
    if not (surface and surface.valid and force) then
        bump(runtime, "shockwave_visual_failures", 1)
        return 0
    end

    previous_radius = math.max(0, tonumber(previous_radius) or 0)
    wave_radius = ei_lib.clamp_number(wave_radius, 0, tonumber(job and job.radius) or IMPACT_RADIUS, 0)
    if wave_radius <= 0 or wave_radius <= previous_radius + 0.05 then
        return 0
    end

    local center = {
        x = tonumber(job.impact_x) or ((tonumber(job.center_x) or 0) + 0.5),
        y = tonumber(job.impact_y) or ((tonumber(job.center_y) or 0) + 0.5),
    }
    local step = math.floor(tonumber(job.shockwave_step) or 0)
    local ttl = 10
    local drawn = 0

    local ring_ok = pcall(function()
        rendering.draw_circle{
            color = {r = 0.05, g = 1.0, b = 0.46, a = 0.34},
            radius = wave_radius,
            width = 3,
            filled = false,
            target = center,
            surface = surface,
            time_to_live = ttl,
            draw_on_ground = true,
            forces = {force},
        }
    end)
    if ring_ok then
        bump(runtime, "shockwave_rings", 1)
        drawn = drawn + 1
    else
        bump(runtime, "shockwave_visual_failures", 1)
        bump(runtime, "visual_failures", 1)
    end

    for arc_index = 1, 3 do
        local start_angle = (model.hash_fraction(job.seed or 0, step * 41 + arc_index * 13) * TAU)
            + (step * 0.17)
        local arc_ok = pcall(function()
            rendering.draw_arc{
                color = {r = 0.02, g = 1.0, b = 0.40, a = 0.42},
                max_radius = wave_radius + 0.75,
                min_radius = math.max(0.1, wave_radius - 0.75),
                start_angle = start_angle,
                angle = TAU * (0.10 + model.hash_fraction(job.seed or 0, step * 73 + arc_index * 29) * 0.12),
                target = center,
                surface = surface,
                time_to_live = ttl + 2,
                draw_on_ground = true,
                forces = {force},
            }
        end)
        if arc_ok then
            bump(runtime, "shockwave_arcs", 1)
            drawn = drawn + 1
        else
            bump(runtime, "shockwave_visual_failures", 1)
            bump(runtime, "visual_failures", 1)
        end
    end

    local puff_count = math.max(4, math.min(10, math.floor(wave_radius / 8) + 3))
    if job and job.unsealed == true then
        puff_count = puff_count + DOCTRINE.unsealed_shockwave_extra_puffs
    end
    for puff_index = 1, puff_count do
        local salt = step * 97 + puff_index * 31
        local angle = ((puff_index - 1) * TAU / puff_count)
            + (model.hash_fraction(job.seed or 0, salt) * 0.42)
            + (step * 0.11)
        local radius = ei_lib.clamp_number(
            wave_radius + ((model.hash_fraction(job.seed or 0, salt + 11) - 0.5) * 2.2),
            0,
            tonumber(job.radius) or IMPACT_RADIUS,
            wave_radius
        )
        local puff_ok = create_entity_visual(
            runtime,
            surface,
            force,
            SHOCKWAVE_EXPLOSION,
            {
                x = center.x + math.cos(angle) * radius,
                y = center.y + math.sin(angle) * radius,
            },
            "shockwave_puffs"
        )
        if puff_ok then
            drawn = drawn + 1
        else
            bump(runtime, "shockwave_visual_failures", 1)
        end
    end

    job.shockwave_step = step + 1
    return drawn
end

function model.apply_endpoint_wave_damage(runtime, job, surface, force, wave_radius)
    if not force then
        bump(runtime, "impact_area_wave_failures", 1)
        return 0
    end

    local targets = type(job.impact_targets) == "table" and job.impact_targets or {}
    local next_index = math.max(1, math.floor(tonumber(job.impact_next_index) or 1))
    local flash_count = math.max(0, math.floor(tonumber(job.impact_flash_count) or 0))
    local source_entity = nil
    local source_record = job.source_unit_number
        and runtime
        and type(runtime.tanks_by_unit) == "table"
        and runtime.tanks_by_unit[job.source_unit_number]
        or nil
    if type(source_record) == "table" then
        source_entity = ei_lib.get_valid_entity(source_record.entity)
    end

    local damaged = 0
    while next_index <= #targets do
        local entry = targets[next_index]
        local distance = tonumber(entry and entry.distance) or IMPACT_RADIUS
        if distance > wave_radius then
            break
        end

        next_index = next_index + 1
        local target = entry and ei_lib.get_valid_entity(entry.entity) or nil
        if target
            and model.entity_has_health(target)
            and relation_is_enemy(force, model.get_entity_force(target)) then
            local damage = model.endpoint_impact_damage(distance, job)
            local ok = pcall(function()
                local damage_source = source_entity
                if damage_source and damage_source.surface ~= target.surface then
                    damage_source = nil
                end
                if damage_source then
                    target.damage(damage, force, DAMAGE_TYPE, damage_source)
                else
                    target.damage(damage, force, DAMAGE_TYPE)
                end
            end)
            if ok then
                damaged = damaged + 1
                bump(runtime, "impact_area_hits", 1)
                bump(runtime, "impact_area_damage_total", damage)
                if flash_count < IMPACT_FLASH_LIMIT and entry.hit_position then
                    if draw_animation_visual(
                        runtime,
                        surface,
                        force,
                        HIT_FLASH_ANIMATION,
                        entry.hit_position,
                        HIT_FLASH_TTL,
                        HIT_FLASH_SCALE,
                        "projectile",
                        "impact_area_flashes"
                    ) then
                        flash_count = flash_count + 1
                    end
                end
            else
                bump(runtime, "impact_area_failed", 1)
                bump(runtime, "impact_area_wave_failures", 1)
            end
        else
            bump(runtime, "impact_area_wave_skipped", 1)
        end
    end

    job.impact_next_index = next_index
    job.impact_flash_count = flash_count
    return damaged
end

function model.queue_terrain_spiral_job(runtime, job_id)
    if not job_id then
        return false
    end

    runtime.terrain_spiral_queue = scheduler.ensure_queue(runtime.terrain_spiral_queue)
    local pushed = scheduler.queue_push_unique(runtime.terrain_spiral_queue, job_id, job_id)
    invalidate_pending_work_cache(runtime)
    return pushed == true
end

function model.start_terrain_spiral(runtime, entity, geometry, current_tick, unit_number, impact_targets, profile)
    if not geometry
        or not geometry.target_position
        or (tonumber(geometry.line_range) or 0) < MIN_ENDPOINT_EFFECT_RANGE
        or not is_tank(entity) then
        return false
    end

    local ok, tile_prototype = pcall(function()
        return prototypes and prototypes.tile and prototypes.tile[TERRAIN_SPIRAL_TILE]
    end)
    if not ok or not tile_prototype then
        bump(runtime, "terrain_spiral_failures", 1)
        return false
    end

    local surface = entity.surface
    if not (surface and surface.valid) then
        bump(runtime, "terrain_spiral_failures", 1)
        return false
    end

    local target = geometry.target_position
    profile = type(profile) == "table" and profile or {}
    local radius = math.max(1, math.floor(tonumber(profile.impact_radius) or IMPACT_RADIUS))
    local center_x = math.floor(tonumber(target.x) or 0)
    local center_y = math.floor(tonumber(target.y) or 0)
    local seed = model.make_terrain_spiral_seed(surface.index, center_x, center_y, current_tick, unit_number)
    local offsets = model.make_terrain_spiral_offsets(radius, seed)
    if profile.branch_scars == true then
        local added = model.add_branch_scar_offsets(offsets, radius, seed, impact_targets, target)
        if added > 0 then
            bump(runtime, "branch_scar_offsets", added)
        end
    end
    if #offsets <= 0 then
        bump(runtime, "terrain_spiral_failures", 1)
        return false
    end

    runtime.next_terrain_spiral_id = (tonumber(runtime.next_terrain_spiral_id) or 0) + 1
    local job_id = runtime.next_terrain_spiral_id
    runtime.terrain_spiral_jobs[job_id] = {
        id = job_id,
        surface_index = surface.index,
        center_x = center_x,
        center_y = center_y,
        impact_x = tonumber(target.x) or (center_x + 0.5),
        impact_y = tonumber(target.y) or (center_y + 0.5),
        muzzle_x = geometry.muzzle_position and geometry.muzzle_position.x or nil,
        muzzle_y = geometry.muzzle_position and geometry.muzzle_position.y or nil,
        beam_dx = geometry.dx,
        beam_dy = geometry.dy,
        beam_orientation = entity.orientation,
        beam_last_tick = current_tick,
        force_name = entity.force and entity.force.name or "player",
        source_unit_number = unit_number,
        seed = seed,
        radius = radius,
        impact_center_damage = profile.impact_center_damage or IMPACT_CENTER_DAMAGE,
        impact_edge_damage = profile.impact_edge_damage or IMPACT_EDGE_DAMAGE,
        impact_damage_multiplier = profile.impact_damage_multiplier or 1,
        unsealed = profile.unseal_impact == true,
        offsets = offsets,
        impact_targets = type(impact_targets) == "table" and impact_targets or {},
        impact_next_index = 1,
        impact_flash_count = 0,
        wave_radius = 0,
        shockwave_step = 0,
        next_index = 1,
        next_tick = current_tick,
        batch_size = TERRAIN_SPIRAL_BATCH_SIZE,
        interval = TERRAIN_SPIRAL_INTERVAL,
    }
    set_apocalypse_brace(runtime, runtime.tanks_by_unit and runtime.tanks_by_unit[unit_number] or nil, runtime.terrain_spiral_jobs[job_id], geometry, entity)
    model.queue_terrain_spiral_job(runtime, job_id)
    bump(runtime, "terrain_spiral_jobs_started", 1)
    bump(runtime, "impact_area_targets_queued", #(runtime.terrain_spiral_jobs[job_id].impact_targets or {}))
    if profile.unseal_impact == true then
        bump(runtime, "unsealed_impacts", 1)
    end
    return true
end

function model.service_terrain_spiral_job(runtime, job, current_tick)
    if type(job) ~= "table" then
        return true
    end

    local surface = model.get_surface_by_index(job.surface_index)
    if not (surface and surface.valid) then
        bump(runtime, "terrain_spiral_failures", 1)
        return true
    end

    local offsets = type(job.offsets) == "table" and job.offsets or {}
    local next_index = math.max(1, math.floor(tonumber(job.next_index) or 1))
    local batch_size = math.max(1, math.floor(tonumber(job.batch_size) or TERRAIN_SPIRAL_BATCH_SIZE))
    local max_visits = math.max(batch_size, TERRAIN_SPIRAL_MAX_VISITS_PER_BATCH)
    local center_x = math.floor(tonumber(job.center_x) or 0)
    local center_y = math.floor(tonumber(job.center_y) or 0)
    local impact_x = tonumber(job.impact_x) or (center_x + 0.5)
    local impact_y = tonumber(job.impact_y) or (center_y + 0.5)
    local force = game and game.forces and (game.forces[job.force_name or "player"] or game.forces.player) or nil
    local tiles = {}
    local skipped = 0
    local visited = 0
    local previous_wave_radius = math.max(0, tonumber(job.wave_radius) or 0)
    local wave_radius = previous_wave_radius

    while next_index <= #offsets and #tiles < batch_size and visited < max_visits do
        local offset = offsets[next_index]
        next_index = next_index + 1
        visited = visited + 1
        if type(offset) == "table" then
            local offset_x = tonumber(offset.x) or 0
            local offset_y = tonumber(offset.y) or 0
            local x = center_x + offset_x
            local y = center_y + offset_y
            local wave_dx = (x + 0.5) - impact_x
            local wave_dy = (y + 0.5) - impact_y
            wave_radius = math.max(wave_radius, math.sqrt((wave_dx * wave_dx) + (wave_dy * wave_dy)))
            if model.terrain_spiral_tile_is_eligible(surface, x, y) then
                tiles[#tiles + 1] = {
                    name = TERRAIN_SPIRAL_TILE,
                    position = {x = x, y = y},
                }
            else
                skipped = skipped + 1
            end
        else
            skipped = skipped + 1
        end
    end

    job.next_index = next_index
    if visited > 0 then
        bump(runtime, "terrain_spiral_batches", 1)
    end
    if skipped > 0 then
        bump(runtime, "terrain_spiral_tiles_skipped", skipped)
    end

    if next_index > #offsets then
        wave_radius = math.max(wave_radius, tonumber(job.radius) or IMPACT_RADIUS)
    end
    wave_radius = ei_lib.clamp_number(wave_radius, 0, tonumber(job.radius) or IMPACT_RADIUS, previous_wave_radius)
    job.wave_radius = wave_radius

    if #tiles > 0 then
        local ok = pcall(function()
            surface.set_tiles(tiles, true, false, true, false)
        end)
        if ok then
            bump(runtime, "terrain_spiral_tiles_changed", #tiles)
            for _, tile in ipairs(tiles) do
                if force and tile.position then
                    local burst_ok = draw_animation_visual(
                        runtime,
                        surface,
                        force,
                        HIT_FLASH_ANIMATION,
                        {x = tile.position.x + 0.5, y = tile.position.y + 0.5},
                        20,
                        0.48,
                        "explosion",
                        "terrain_spiral_bursts"
                    )
                    if not burst_ok then
                        bump(runtime, "terrain_spiral_burst_failures", 1)
                    end
                else
                    bump(runtime, "terrain_spiral_burst_failures", 1)
                end

                local decorative_ok = pcall(function()
                    surface.destroy_decoratives{
                        position = tile.position,
                        exclude_soft = false,
                    }
                end)
                if not decorative_ok then
                    bump(runtime, "terrain_spiral_failures", 1)
                end
            end
        else
            bump(runtime, "terrain_spiral_failures", 1)
        end
    end

    if visited > 0 then
        model.draw_sustained_apocalypse_beam(runtime, job, current_tick)
        model.draw_endpoint_shockwave(runtime, surface, force, job, previous_wave_radius, wave_radius)
        model.apply_endpoint_wave_damage(runtime, job, surface, force, wave_radius)
    end

    if next_index > #offsets then
        return true
    end

    job.next_tick = current_tick + math.max(1, math.floor(tonumber(job.interval) or TERRAIN_SPIRAL_INTERVAL))
    return false
end

function model.service_terrain_spiral_queue(runtime, current_tick)
    runtime.terrain_spiral_queue = scheduler.ensure_queue(runtime.terrain_spiral_queue)
    runtime.terrain_spiral_jobs = type(runtime.terrain_spiral_jobs) == "table" and runtime.terrain_spiral_jobs or {}

    local serviced = 0
    local scanned = 0
    local max_scans = math.max(TERRAIN_SPIRAL_SERVICE_CAP * 4, TERRAIN_SPIRAL_SERVICE_CAP)
    local deferred_job_ids = nil
    while serviced < TERRAIN_SPIRAL_SERVICE_CAP and scanned < max_scans do
        scanned = scanned + 1
        local job_id = scheduler.queue_pop_queued(runtime.terrain_spiral_queue)
        if not job_id then
            for candidate_id, job in pairs(runtime.terrain_spiral_jobs) do
                if current_tick >= (tonumber(job.next_tick) or 0) then
                    job_id = candidate_id
                    break
                end
            end
        end
        if not job_id then
            break
        end

        local job = runtime.terrain_spiral_jobs[job_id]
        if not job then
            serviced = serviced + 1
        elseif current_tick < (tonumber(job.next_tick) or 0) then
            deferred_job_ids = deferred_job_ids or {}
            deferred_job_ids[#deferred_job_ids + 1] = job_id
        else
            local done = model.service_terrain_spiral_job(runtime, job, current_tick)
            serviced = serviced + 1
            if done then
                local record = runtime.tanks_by_unit and runtime.tanks_by_unit[job.source_unit_number] or nil
                clear_apocalypse_brace(record, job_id)
                runtime.terrain_spiral_jobs[job_id] = nil
                bump(runtime, "terrain_spiral_jobs_completed", 1)
                invalidate_pending_work_cache(runtime)
            else
                model.queue_terrain_spiral_job(runtime, job_id)
            end
        end
    end

    if deferred_job_ids then
        for _, job_id in ipairs(deferred_job_ids) do
            model.queue_terrain_spiral_job(runtime, job_id)
        end
    end

    return serviced
end

local function render_discharge_visuals(runtime, entity, geometry, hit_positions, impact_hit_positions, profile)
    if not ei_lib.entity_check(entity) then
        return
    end

    profile = type(profile) == "table" and profile or {}
    local surface = entity.surface
    local force = entity.force
    local muzzle_position = geometry.muzzle_position
    local target_position = geometry.target_position
    local orientation = rotate_east_facing_sprite_to_orientation(entity.orientation)

    pcall(function()
        surface.play_sound{
            path = "ei-emerald-apocalypse-hover-tank-beam-fire",
            position = muzzle_position,
        }
    end)

    draw_animation_visual(
        runtime,
        surface,
        force,
        MUZZLE_FLASH_ANIMATION,
        muzzle_position,
        MUZZLE_FLASH_TTL,
        MUZZLE_FLASH_SCALE,
        "projectile",
        "muzzle_flashes",
        orientation
    )

    if geometry.beam_visual_length >= MIN_BEAM_VISUAL_LENGTH then
        create_entity_visual(runtime, surface, force, MAIN_BEAM_NAME, muzzle_position, "beam_visuals", {
            source = muzzle_position,
            target = target_position,
            duration = BEAM_VISUAL_TICKS,
            max_length = geometry.beam_visual_length + 1,
        })

        if profile.split_wake == true then
            for _, lateral_offset in ipairs({-DOCTRINE.split_wake_lateral_offset, DOCTRINE.split_wake_lateral_offset}) do
                local side_muzzle = {
                    x = muzzle_position.x + (-geometry.dy * lateral_offset),
                    y = muzzle_position.y + (geometry.dx * lateral_offset),
                }
                local side_target = {
                    x = target_position.x + (-geometry.dy * lateral_offset),
                    y = target_position.y + (geometry.dx * lateral_offset),
                }
                create_entity_visual(runtime, surface, force, MAIN_BEAM_NAME, side_muzzle, "split_wake_visuals", {
                    source = side_muzzle,
                    target = side_target,
                    duration = BEAM_VISUAL_TICKS,
                    max_length = geometry.beam_visual_length + 1,
                })
            end
        end

        if geometry.line_range >= MIN_ENDPOINT_EFFECT_RANGE then
            create_entity_visual(runtime, surface, force, IMPACT_EXPLOSION, target_position, "impact_effects")
        end
    end

    draw_hit_flash_positions(runtime, surface, force, hit_positions, HIT_FLASH_LIMIT, "hit_flashes")
    draw_hit_flash_positions(runtime, surface, force, impact_hit_positions, IMPACT_FLASH_LIMIT, "impact_area_flashes")
end

local function schedule_charge(runtime, record, due_tick)
    -- next_charge_due_tick is the cheap wake-up guard; the delayed bucket holds
    -- unit numbers only so stale entity references never cross the wind-up.
    runtime.pending_by_unit[record.unit_number] = due_tick
    record.charge_due_tick = due_tick
    scheduler.delayed_schedule(runtime.charge_buckets, due_tick, record.unit_number)
    if runtime.next_charge_due_tick == 0 or due_tick < runtime.next_charge_due_tick then
        runtime.next_charge_due_tick = due_tick
    end
    invalidate_pending_work_cache(runtime)
end

local function start_charge(runtime, record, event, current_tick)
    -- The prototype shot has already spent one stack-size-1 charge. Runtime
    -- commits to the wind-up here; rejected pending/cooldown triggers refund
    -- the already-spent charge, but aim/target changes after commit do not.
    local entity = ei_lib.get_valid_entity(record and record.entity)
    if not is_tank(entity) then
        return false
    end

    if runtime.pending_by_unit[record.unit_number] then
        bump(runtime, "charges_rejected", 1)
        model.refund_charge_item(runtime, entity)
        return false
    end

    if current_tick < (tonumber(record.cooldown_until_tick) or 0) then
        bump(runtime, "cooldown_rejections", 1)
        model.refund_charge_item(runtime, entity)
        return false
    end

    if not consume_charge_item(entity) then
        bump(runtime, "charges_rejected", 1)
        return false
    end

    local fallback_aim_x, fallback_aim_y = get_aim_vector(entity)
    record.aim_x = nil
    record.aim_y = nil
    record.aim_range = get_target_line_range(entity, fallback_aim_x, fallback_aim_y, event)
    record.aim_target_x, record.aim_target_y = get_position_xy(get_event_target_position(event))
    record.charge_started_tick = current_tick
    record.charge_profile = model.snapshot_shot_profile(model.make_shot_profile(runtime, entity, current_tick))
    bump(runtime, "charges_consumed", 1)
    bump(runtime, "charges_started", 1)
    schedule_charge(runtime, record, current_tick + (record.charge_profile.charge_ticks or CHARGE_TICKS))
    queue_motion_unit(runtime, record.unit_number)
    render_charge_visual(runtime, entity, record.charge_profile)
    return true
end

local function find_line_targets(entity, dx, dy, line_range, half_width, lateral_offset)
    -- Damage is runtime-owned so the beam prototype stays cosmetic. Keep the
    -- broad area query mod-friendly, then filter by force and line geometry.
    line_range = clamp_beam_range(line_range)
    half_width = math.max(0.1, tonumber(half_width) or LINE_HALF_WIDTH)
    lateral_offset = tonumber(lateral_offset) or 0
    local surface = entity.surface
    local base_position = entity.position
    local start = {
        x = base_position.x + (-dy * lateral_offset),
        y = base_position.y + (dx * lateral_offset),
    }
    local finish = {
        x = start.x + dx * line_range,
        y = start.y + dy * line_range,
    }
    local min_x = math.min(start.x, finish.x) - half_width
    local max_x = math.max(start.x, finish.x) + half_width
    local min_y = math.min(start.y, finish.y) - half_width
    local max_y = math.max(start.y, finish.y) + half_width
    local width_sq = half_width * half_width
    local targets = {}

    local entities = surface.find_entities_filtered{
        area = {{min_x, min_y}, {max_x, max_y}},
    }

    local source_force = model.get_entity_force(entity)
    for _, target in pairs(entities) do
        local target_position = model.copy_entity_position(target)
        local target_force = target_position and model.get_entity_force(target) or nil
        local distance_sq = target_position
            and point_line_distance_sq(target_position, start.x, start.y, dx, dy, line_range)
            or nil
        if target ~= entity
            and target_position
            and model.entity_has_health(target)
            and relation_is_enemy(source_force, target_force)
            and distance_sq
            and distance_sq <= width_sq then
            targets[#targets + 1] = {
                entity = target,
                unit_number = ei_lib.get_entity_unit_number(target),
                name = model.copy_entity_name(target),
                hit_position = target_position,
                projection = ((target_position.x - start.x) * dx) + ((target_position.y - start.y) * dy),
            }
        end
    end

    table.sort(targets, function(a, b)
        return (tonumber(a.projection) or 0) < (tonumber(b.projection) or 0)
    end)

    return targets
end

local function find_endpoint_impact_targets(entity, center, radius)
    if not center then
        return {}
    end

    radius = math.max(1, tonumber(radius) or IMPACT_RADIUS)
    local surface = entity.surface
    local min_x = center.x - radius
    local max_x = center.x + radius
    local min_y = center.y - radius
    local max_y = center.y + radius
    local radius_sq = radius * radius
    local targets = {}

    local entities = surface.find_entities_filtered{
        area = {{min_x, min_y}, {max_x, max_y}},
    }

    local source_force = model.get_entity_force(entity)
    for _, target in pairs(entities) do
        local target_position = model.copy_entity_position(target)
        if target ~= entity
            and target_position
            and model.entity_has_health(target)
            and relation_is_enemy(source_force, model.get_entity_force(target)) then
            local dx = target_position.x - center.x
            local dy = target_position.y - center.y
            local distance_sq = (dx * dx) + (dy * dy)
            if distance_sq <= radius_sq then
                targets[#targets + 1] = {
                    entity = target,
                    unit_number = ei_lib.get_entity_unit_number(target),
                    name = target.name,
                    hit_position = target_position,
                    distance = math.sqrt(distance_sq),
                }
            end
        end
    end

    table.sort(targets, function(a, b)
        if a.distance ~= b.distance then
            return a.distance < b.distance
        end
        local a_unit = tonumber(a.unit_number) or 0
        local b_unit = tonumber(b.unit_number) or 0
        if a_unit ~= b_unit then
            return a_unit < b_unit
        end
        if a.name ~= b.name then
            return tostring(a.name or "") < tostring(b.name or "")
        end
        local a_position = a.hit_position or {}
        local b_position = b.hit_position or {}
        if a_position.x ~= b_position.x then
            return (tonumber(a_position.x) or 0) < (tonumber(b_position.x) or 0)
        end
        return (tonumber(a_position.y) or 0) < (tonumber(b_position.y) or 0)
    end)

    return targets
end

local add_motion_impulse

function model.line_target_key(entry)
    local unit_number = entry and entry.unit_number or nil
    if not unit_number then
        unit_number = entry and ei_lib.get_entity_unit_number(entry.entity) or nil
    end
    if unit_number then
        return "u:"..unit_number
    end

    local position = entry and entry.hit_position or nil
    local name = entry and entry.name or model.copy_entity_name(entry and entry.entity)
    return "p:"..tostring(name or "?")
        ..":"..tostring(position and position.x or "?")
        ..":"..tostring(position and position.y or "?")
end

function model.apply_split_wake_damage(runtime, entity, geometry, profile, already_hit)
    if not (profile and profile.split_wake == true) then
        return {}, 0
    end

    local hit_positions = {}
    local hit_count = 0
    local damage = math.max(1, math.floor((tonumber(profile.line_damage) or DAMAGE_AMOUNT) * DOCTRINE.split_wake_damage_factor + 0.5))
    local offsets = {-DOCTRINE.split_wake_lateral_offset, DOCTRINE.split_wake_lateral_offset}
    for _, lateral_offset in ipairs(offsets) do
        local targets = find_line_targets(
            entity,
            geometry.dx,
            geometry.dy,
            geometry.line_range,
            DOCTRINE.split_wake_half_width,
            lateral_offset
        )
        for _, entry in ipairs(targets) do
            if hit_count >= DOCTRINE.split_wake_target_limit then
                return hit_positions, hit_count
            end

            local key = model.line_target_key(entry)
            if not (already_hit and already_hit[key]) then
                local target = entry.entity
                local hit_position = entry.hit_position or model.copy_entity_position(target)
                if model.entity_has_health(target) then
                    local ok = pcall(function()
                        target.damage(damage, entity.force, DAMAGE_TYPE, entity)
                    end)
                    if ok then
                        hit_count = hit_count + 1
                        if already_hit then
                            already_hit[key] = true
                        end
                        bump(runtime, "split_wake_hits", 1)
                        if hit_position and #hit_positions < HIT_FLASH_LIMIT then
                            hit_positions[#hit_positions + 1] = hit_position
                        end
                    else
                        bump(runtime, "split_wake_failures", 1)
                    end
                else
                    bump(runtime, "split_wake_failures", 1)
                end
            end
        end
    end

    return hit_positions, hit_count
end

local function apply_line_attack(runtime, record, current_tick)
    -- The real shot happens here, after the audio/visual charge has completed.
    -- Targets are collected immediately before damage so vanished enemies or
    -- changed aim do not leave stale LuaEntity references behind.
    local entity = ei_lib.get_valid_entity(record and record.entity)
    if not is_tank(entity) then
        remove_record(runtime, record and record.unit_number, "invalid")
        return false
    end

    local geometry = compute_fire_geometry(entity, record)
    local dx = geometry.dx
    local dy = geometry.dy
    if geometry.aim_source == "vehicle-shooting-state"
        or geometry.aim_source == "driver-shooting-state"
        or geometry.aim_source == "driver-player-shooting-state" then
        bump(runtime, "late_aim_samples", 1)
    else
        bump(runtime, "late_aim_fallbacks", 1)
    end
    local profile = type(record.charge_profile) == "table"
        and model.snapshot_shot_profile(record.charge_profile)
        or model.make_shot_profile(runtime, entity, current_tick)
    local targets = find_line_targets(entity, dx, dy, geometry.line_range, profile.line_half_width)
    local hit_positions = {}
    local already_hit = {}

    for _, entry in ipairs(targets) do
        local target = entry.entity
        local hit_position = entry.hit_position or model.copy_entity_position(target)
        local target_key = model.line_target_key(entry)
        if model.entity_has_health(target) then
            local ok = pcall(function()
                target.damage(profile.line_damage or DAMAGE_AMOUNT, entity.force, DAMAGE_TYPE, entity)
            end)
            if ok then
                already_hit[target_key] = true
                bump(runtime, "damage_hits", 1)
                if hit_position and #hit_positions < HIT_FLASH_LIMIT then
                    hit_positions[#hit_positions + 1] = hit_position
                end
            else
                bump(runtime, "damage_failed", 1)
            end
        else
            bump(runtime, "damage_failed", 1)
        end
    end
    local split_positions, split_hits = model.apply_split_wake_damage(runtime, entity, geometry, profile, already_hit)
    for _, position in ipairs(split_positions) do
        if #hit_positions >= HIT_FLASH_LIMIT then
            break
        end
        hit_positions[#hit_positions + 1] = position
    end

    local impact_targets = find_endpoint_impact_targets(entity, geometry.target_position, profile.impact_radius)
    model.start_terrain_spiral(runtime, entity, geometry, current_tick, record.unit_number, impact_targets, profile)

    record.last_fire_tick = current_tick
    record.cooldown_until_tick = current_tick + (profile.post_fire_cooldown or POST_FIRE_COOLDOWN)
    record.charge_started_tick = nil
    record.charge_due_tick = nil
    record.charge_profile = nil
    record.aim_x = nil
    record.aim_y = nil
    record.aim_range = nil
    record.aim_target_x = nil
    record.aim_target_y = nil
    add_motion_impulse(runtime, record, -dx * (profile.recoil_impulse or MOTION_RECOIL_IMPULSE), -dy * (profile.recoil_impulse or MOTION_RECOIL_IMPULSE), "motion_recoil_impulses")
    runtime.pending_by_unit[record.unit_number] = nil
    bump(runtime, "charges_completed", 1)
    bump(runtime, "line_attacks", 1)
    if profile.reclaim_charges == true and (#targets + split_hits + #impact_targets) >= DOCTRINE.reclaim_target_threshold then
        model.refund_charge_item(runtime, entity, "charges_reclaimed", "charge_reclaim_failures")
    end
    render_discharge_visuals(runtime, entity, geometry, hit_positions, {}, profile)
    return true
end

local function activate_due_charges(runtime, current_tick)
    -- Drain from the maintained earliest due tick instead of scanning every
    -- delayed bucket. Lagged saves still process overdue buckets in tick order.
    if runtime.next_charge_due_tick == 0 or current_tick < runtime.next_charge_due_tick then
        return 0
    end

    local activated = 0
    while runtime.next_charge_due_tick ~= 0 and runtime.next_charge_due_tick <= current_tick do
        local due_tick = runtime.next_charge_due_tick
        local bucket = scheduler.delayed_take_due(runtime.charge_buckets, due_tick)
        for _, unit_number in ipairs(bucket) do
            if runtime.pending_by_unit[unit_number] == due_tick then
                runtime.pending_by_unit[unit_number] = nil
                scheduler.queue_push_unique(runtime.charge_queue, unit_number, unit_number)
                activated = activated + 1
            end
        end
        -- Recalculate after each due bucket so lagged saves still drain buckets
        -- in tick order without scanning and sorting the whole bucket table first.
        recalculate_next_charge_due(runtime)
    end
    if activated > 0 then
        invalidate_pending_work_cache(runtime)
    end
    return activated
end

local function service_charge_queue(runtime, current_tick)
    local unit_number = scheduler.queue_pop_queued(runtime.charge_queue)
    if not unit_number then
        return false
    end

    local record = runtime.tanks_by_unit[unit_number]
    if record then
        apply_line_attack(runtime, record, current_tick)
    end
    return true
end

function add_motion_impulse(runtime, record, impulse_x, impulse_y, counter_name)
    -- Beam recoil and any future external shove feed the same drift vector as
    -- normal driving, preserving the heavy skid feel.
    if not record then
        return false
    end

    record.drift_x, record.drift_y = clamp_vector(
        (tonumber(record.drift_x) or 0) + impulse_x,
        (tonumber(record.drift_y) or 0) + impulse_y,
        MOTION_MAX_DRIFT_SPEED
    )
    record.motion_idle_ticks = 0
    if counter_name then
        bump(runtime, counter_name, 1)
    end
    return queue_motion_unit(runtime, record.unit_number)
end

function model.apply_keel_wake(runtime, entity, record, current_tick, speed)
    if not is_tank(entity) then
        return 0
    end

    if current_tick - (tonumber(record.last_keel_wake_tick) or 0) < DOCTRINE.keel_wake_interval then
        return 0
    end

    record.last_keel_wake_tick = current_tick
    local position = entity.position
    local radius = DOCTRINE.keel_wake_radius
    local entities = entity.surface.find_entities_filtered{
        area = {{position.x - radius, position.y - radius}, {position.x + radius, position.y + radius}},
    }
    local source_force = model.get_entity_force(entity)
    local hits = 0
    local damage = math.max(1, math.floor(DOCTRINE.keel_wake_damage * (1 + (tonumber(speed) or 0) * 4)))
    for _, target in pairs(entities) do
        if hits >= DOCTRINE.keel_wake_target_limit then
            break
        end

        local target_position = model.copy_entity_position(target)
        if target ~= entity
            and target_position
            and model.entity_has_health(target)
            and relation_is_enemy(source_force, model.get_entity_force(target)) then
            local dx = target_position.x - position.x
            local dy = target_position.y - position.y
            if (dx * dx) + (dy * dy) <= radius * radius then
                local ok = pcall(function()
                    target.damage(damage, entity.force, DAMAGE_TYPE, entity)
                end)
                if ok then
                    hits = hits + 1
                    bump(runtime, "keel_wake_hits", 1)
                    if hits <= 4 then
                        draw_animation_visual(
                            runtime,
                            entity.surface,
                            entity.force,
                            HIT_FLASH_ANIMATION,
                            target_position,
                            18,
                            0.42,
                            "projectile",
                            "hit_flashes"
                        )
                    end
                else
                    bump(runtime, "keel_wake_failures", 1)
                end
            end
        end
    end
    return hits
end

local function rollback_motion(runtime, record, entity)
    -- Teleport failure usually means collision or surface constraints. Snap
    -- back to the last known safe state and zero drift rather than tunneling.
    local rollback = {
        x = tonumber(record.last_safe_x) or entity.position.x,
        y = tonumber(record.last_safe_y) or entity.position.y,
    }

    pcall(function()
        entity.teleport(rollback)
    end)
    if record.last_safe_orientation then
        pcall(function()
            entity.orientation = record.last_safe_orientation
        end)
    end

    record.drift_x = 0
    record.drift_y = 0
    record.last_motion_x = rollback.x
    record.last_motion_y = rollback.y
    record.last_motion_speed = 0
    record.motion_idle_ticks = 0
    pcall(function()
        entity.speed = 0
    end)
    bump(runtime, "motion_rollbacks", 1)
end

local function service_motion_queue(runtime, current_tick)
    -- Motion is script-authoritative while occupied, drifting, or bracing. The
    -- vehicle supplies input/fuel state; this controller applies hover inertia.
    local unit_number = scheduler.queue_pop_queued(runtime.motion_queue)
    if not unit_number then
        return false
    end

    local record = runtime.tanks_by_unit[unit_number]
    local entity = record and ei_lib.get_valid_entity(record.entity) or nil
    if not is_tank(entity) then
        if record then
            remove_record(runtime, unit_number, "invalid")
        end
        return true
    end

    local position = entity.position
    local last_x = tonumber(record.last_motion_x) or position.x
    local last_y = tonumber(record.last_motion_y) or position.y
    local external_dx = position.x - last_x
    local external_dy = position.y - last_y
    local native_speed = model.read_entity_speed(entity)
    if vector_length(external_dx, external_dy) > MOTION_EXTERNAL_RESET_DISTANCE then
        record.last_motion_x = position.x
        record.last_motion_y = position.y
        record.last_safe_x = position.x
        record.last_safe_y = position.y
        record.last_safe_orientation = entity.orientation
        record.drift_x = 0
        record.drift_y = 0
        record.last_motion_speed = 0
        record.last_motion_tick = current_tick
        model.neutralize_native_vehicle_speed(runtime, entity, native_speed)
        if tank_has_driver(entity) then
            queue_motion_unit(runtime, unit_number)
        end
        return true
    end

    local drift_x = tonumber(record.drift_x) or 0
    local drift_y = tonumber(record.drift_y) or 0
    local has_driver = tank_has_driver(entity)
    local acceleration = get_riding_acceleration(entity)
    model.neutralize_native_vehicle_speed(runtime, entity, native_speed)
    local apocalypse_active = record_has_active_apocalypse_job(runtime, record, current_tick)
    local keel_wake_enabled, doctrine_cache = model.doctrine_toggle_for_entity(runtime, entity, current_tick, "keel_wake")
    local keel = doctrine_cache.keel or DOCTRINE.keel_profiles[0]
    local equipment_factor = model.tank_movement_equipment_factor(record, entity, current_tick)
    local max_drift_speed = (tonumber(keel.max_drift_speed) or MOTION_MAX_DRIFT_SPEED) * equipment_factor
    local forward_thrust = (tonumber(keel.forward_thrust) or MOTION_FORWARD_THRUST) * equipment_factor
    local reverse_thrust = (tonumber(keel.reverse_thrust) or MOTION_REVERSE_THRUST) * equipment_factor
    local brake_thrust = (tonumber(keel.brake_thrust) or MOTION_BRAKE_THRUST) * equipment_factor
    local can_thrust = has_driver and tank_has_available_thrust(entity) and not apocalypse_active
    if equipment_factor > 1 then
        bump(runtime, "motion_equipment_bonus_ticks", 1)
    end

    if apocalypse_active and record.apocalypse_orientation then
        -- During the endpoint apocalypse the cannon is still firing. Lock the
        -- hull orientation and neutralize riding input so steering cannot drag
        -- the beam sideways while the shockwave resolves.
        set_neutral_riding_state(entity)
        pcall(function()
            entity.orientation = record.apocalypse_orientation
        end)
    end

    if can_thrust then
        local forward_x, forward_y = orientation_vector(entity.orientation)
        if is_acceleration(acceleration, "accelerating") then
            drift_x = drift_x + forward_x * forward_thrust
            drift_y = drift_y + forward_y * forward_thrust
        elseif is_acceleration(acceleration, "reversing") then
            drift_x = drift_x - forward_x * reverse_thrust
            drift_y = drift_y - forward_y * reverse_thrust
        elseif is_acceleration(acceleration, "braking") then
            drift_x, drift_y = apply_counter_thrust(drift_x, drift_y, brake_thrust)
        end
    end

    if apocalypse_active then
        local recoil_x = -(tonumber(record.apocalypse_dx) or 0) * MOTION_APOCALYPSE_RECOIL_THRUST
        local recoil_y = -(tonumber(record.apocalypse_dy) or 0) * MOTION_APOCALYPSE_RECOIL_THRUST
        drift_x = drift_x + recoil_x
        drift_y = drift_y + recoil_y
        drift_x = drift_x * MOTION_APOCALYPSE_BRACE_DRAG_MULTIPLIER
        drift_y = drift_y * MOTION_APOCALYPSE_BRACE_DRAG_MULTIPLIER
        drift_x, drift_y = clamp_vector(drift_x, drift_y, MOTION_APOCALYPSE_MAX_DRIFT_SPEED)
        bump(runtime, "apocalypse_brace_ticks", 1)
        bump(runtime, "apocalypse_recoil_ticks", 1)
    end

    if runtime.pending_by_unit[unit_number] then
        local chargeup_drag = tonumber(keel.chargeup_drag_multiplier) or MOTION_CHARGEUP_DRAG_MULTIPLIER
        drift_x = drift_x * chargeup_drag
        drift_y = drift_y * chargeup_drag
    end

    local drag = has_driver
        and (tonumber(keel.driver_drag) or MOTION_DRIVER_DRAG)
        or (tonumber(keel.coast_drag) or MOTION_COAST_DRAG)
    drift_x = drift_x * drag
    drift_y = drift_y * drag
    drift_x, drift_y = clamp_vector(drift_x, drift_y, max_drift_speed)

    local speed = vector_length(drift_x, drift_y)
    if speed < MOTION_MIN_ACTIVE_DRIFT and not has_driver and not apocalypse_active then
        record.drift_x = 0
        record.drift_y = 0
        record.last_motion_speed = 0
        record.last_motion_tick = current_tick
        record.motion_idle_ticks = (tonumber(record.motion_idle_ticks) or 0) + 1
        model.neutralize_native_vehicle_speed(runtime, entity)
        return true
    end

    local new_position = {
        x = last_x + drift_x,
        y = last_y + drift_y,
    }
    local ok, teleported = pcall(function()
        return entity.teleport(new_position)
    end)
    if not ok or teleported == false then
        bump(runtime, "motion_teleports_failed", 1)
        rollback_motion(runtime, record, entity)
        return true
    end

    record.drift_x = drift_x
    record.drift_y = drift_y
    record.last_motion_x = new_position.x
    record.last_motion_y = new_position.y
    record.last_safe_x = new_position.x
    record.last_safe_y = new_position.y
    record.last_safe_orientation = entity.orientation
    record.last_motion_speed = speed
    record.last_motion_tick = current_tick
    record.motion_idle_ticks = 0
    model.neutralize_native_vehicle_speed(runtime, entity)

    if has_driver then
        bump(runtime, "motion_driver_ticks", 1)
    else
        bump(runtime, "motion_coast_ticks", 1)
    end
    bump(runtime, "motion_steps", 1)

    if keel_wake_enabled == true and speed >= DOCTRINE.keel_wake_min_speed then
        model.apply_keel_wake(runtime, entity, record, current_tick, speed)
    end

    if has_driver or speed >= MOTION_MIN_ACTIVE_DRIFT or runtime.pending_by_unit[unit_number] or apocalypse_active then
        queue_motion_unit(runtime, unit_number)
    end
    return true
end

local function queue_active_motion_units(runtime, current_tick)
    local active = 0
    local stale_units = nil

    for unit_number, record in pairs(runtime.tanks_by_unit) do
        local entity = ei_lib.get_valid_entity(record.entity)
        if is_tank(entity) then
            if runtime.pending_by_unit[unit_number]
                or drift_speed(record) >= MOTION_MIN_ACTIVE_DRIFT
                or tank_has_driver(entity)
                or record_has_active_apocalypse_job(runtime, record, current_tick)
            then
                queue_motion_unit(runtime, unit_number)
                active = active + 1
            end
        else
            stale_units = stale_units or {}
            stale_units[#stale_units + 1] = unit_number
        end
    end

    if stale_units then
        for _, unit_number in ipairs(stale_units) do
            remove_record(runtime, unit_number, "invalid")
        end
    end

    return active
end

local function hover_color(index, alpha)
    local color = HOVER_COLORS[((index - 1) % #HOVER_COLORS) + 1]
    return {
        r = color.r,
        g = color.g,
        b = color.b,
        a = alpha,
    }
end

local function get_hover_direction_index(entity)
    local orientation = tonumber(entity.orientation) or 0
    return (math.floor((orientation % 1) * HOVER_DIRECTION_COUNT + 0.5) % HOVER_DIRECTION_COUNT) + 1
end

local function make_hover_motion_context(record)
    -- Compute drift strength and direction once per tank service. All four
    -- emitter feet share this context for alpha, phase, and rear slip.
    local drift_x = tonumber(record and record.drift_x) or 0
    local drift_y = tonumber(record and record.drift_y) or 0
    local speed = vector_length(drift_x, drift_y)
    local factor = ei_lib.clamp_number(speed / MOTION_MAX_DRIFT_SPEED, 0, 1, 0)
    local unit_x = 0
    local unit_y = 0

    if speed > MOTION_MIN_ACTIVE_DRIFT then
        unit_x = drift_x / speed
        unit_y = drift_y / speed
    end

    return {
        factor = factor,
        unit_x = unit_x,
        unit_y = unit_y,
    }
end

local function apply_rear_slip_offset(target, emitter, motion_context)
    local motion_factor = motion_context and motion_context.factor or 0
    if motion_factor <= 0 or not target or not emitter or (emitter.forward or 0) > 0.2 then
        return target
    end

    if motion_context.unit_x == 0 and motion_context.unit_y == 0 then
        return target
    end

    local slip = 0.18 * motion_factor
    return {
        x = target.x - motion_context.unit_x * slip,
        y = target.y - motion_context.unit_y * slip,
    }
end

local function resolve_hover_position(entity, emitter, emitter_index, motion_context, direction_offsets)
    local position = entity.position
    local offset = type(direction_offsets) == "table" and direction_offsets[emitter_index] or nil
    if type(offset) == "table" and offset.x and offset.y then
        local target = {
            x = position.x + offset.x,
            y = position.y + offset.y,
        }
        return apply_rear_slip_offset(target, emitter, motion_context), offset.radius_scale or emitter.radius_scale or 1
    end

    local angle = (entity.orientation or 0) * TAU
    local forward_x = math.sin(angle)
    local forward_y = -math.cos(angle)
    local right_x = math.cos(angle)
    local right_y = math.sin(angle)

    local target = {
        x = position.x + forward_x * emitter.forward + right_x * emitter.side,
        y = position.y + forward_y * emitter.forward + right_y * emitter.side,
    }
    return apply_rear_slip_offset(target, emitter, motion_context), emitter.radius_scale or 1
end

local function draw_hover_emitter(entity, emitter, emitter_index, current_tick, visual_config, motion_context, direction_offsets)
    local motion_factor = motion_context and motion_context.factor or 0
    local target, radius_scale = resolve_hover_position(entity, emitter, emitter_index, motion_context, direction_offsets)
    local surface = entity.surface
    local force_filter = {entity.force}
    local radius = visual_config.radius * radius_scale * (1 + motion_factor * 0.12)
    local phase_speed = visual_config.phase_speed * (1 + motion_factor * 1.35)
    local phase = ((current_tick * phase_speed) + ((emitter_index * 0.173) % 1)) % 1
    local outer_alpha = ei_lib.clamp_number(0.24 + motion_factor * 0.12, 0, 1, 0.24)
    local echo_alpha = ei_lib.clamp_number(visual_config.echo_alpha * (1 + motion_factor * 0.65), 0, 1, visual_config.echo_alpha)
    local arc_alpha = ei_lib.clamp_number(visual_config.arc_alpha * (1 + motion_factor * 0.75), 0, 1, visual_config.arc_alpha)
    local drawn = 0

    local ok_sprite = pcall(function()
        rendering.draw_animation{
            animation = HOVER_EMITTER_ANIMATION,
            target = target,
            surface = surface,
            orientation = 0,
            render_layer = HOVER_EMITTER_RENDER_LAYER,
            animation_speed = HOVER_EMITTER_ANIMATION_SPEED,
            animation_offset = math.floor((phase * HOVER_EMITTER_FRAME_COUNT) + emitter_index * 5) % HOVER_EMITTER_FRAME_COUNT,
            x_scale = radius * HOVER_EMITTER_SPRITE_SCALE_PER_RADIUS,
            y_scale = radius * HOVER_EMITTER_SPRITE_SCALE_PER_RADIUS,
            time_to_live = visual_config.ring_ttl,
            forces = force_filter,
        }
    end)
    if ok_sprite then
        drawn = drawn + 1
    end

    local ok_outer = pcall(function()
        rendering.draw_circle{
            color = hover_color(emitter_index, outer_alpha),
            radius = radius,
            width = visual_config.width,
            filled = false,
            target = target,
            surface = surface,
            time_to_live = visual_config.ring_ttl,
            draw_on_ground = true,
            forces = force_filter,
        }
    end)
    if ok_outer then
        drawn = drawn + 1
    end

    if echo_alpha > 0 then
        local ok_echo = pcall(function()
            rendering.draw_circle{
                color = hover_color(emitter_index + 1, echo_alpha),
                radius = radius * 0.62,
                width = math.max(1, visual_config.width - 0.5),
                filled = false,
                target = target,
                surface = surface,
                time_to_live = visual_config.ring_ttl,
                draw_on_ground = true,
                forces = force_filter,
            }
        end)
        if ok_echo then
            drawn = drawn + 1
        end
    end

    for arc_index = 1, visual_config.arc_count do
        local start_angle = (phase * TAU) + ((arc_index - 1) * TAU / math.max(1, visual_config.arc_count))
            + (emitter_index * 0.31)
        local ok_arc = pcall(function()
            rendering.draw_arc{
                color = hover_color(emitter_index + arc_index + 1, arc_alpha),
                max_radius = radius + visual_config.arc_thickness,
                min_radius = math.max(0.02, radius - visual_config.arc_thickness),
                start_angle = start_angle,
                angle = visual_config.arc_span,
                target = target,
                surface = surface,
                time_to_live = visual_config.ring_ttl,
                draw_on_ground = true,
                forces = force_filter,
            }
        end)
        if ok_arc then
            drawn = drawn + 1
        end
    end

    return drawn
end

local function emit_hover_shimmer(runtime, record, entity, current_tick, visual_config, budget, idle)
    -- Emitters are capped globally per service pass. This lets cinematic modes
    -- look loud without one occupied fleet monopolizing render-object creation.
    local emitted = 0
    local motion_context = make_hover_motion_context(record)
    local direction_offsets = hover_emitter_offsets_by_direction[get_hover_direction_index(entity)]
    for emitter_index, emitter in ipairs(HOVER_EMITTERS) do
        if budget.global_emitter_cap ~= nil and budget.emitters >= budget.global_emitter_cap then
            bump(runtime, "hover_capped", 1)
            break
        end

        local drawn = draw_hover_emitter(entity, emitter, emitter_index, current_tick, visual_config, motion_context, direction_offsets)
        if drawn > 0 then
            emitted = emitted + 1
            budget.emitters = budget.emitters + 1
        else
            bump(runtime, "hover_draw_failures", 1)
        end
    end

    if emitted > 0 then
        record.last_hover_emit_tick = current_tick
        if idle then
            bump(runtime, "hover_idle_emitters", emitted)
        end
        bump(runtime, "hover_emitters", emitted)
    end

    return emitted
end

local function service_hover_unit(runtime, unit_number, current_tick, visual_config, budget)
    -- One queue item represents one active tank, not one emitter. The unit
    -- requeues itself while occupied so the hot path remains event-gated.
    local record = runtime.tanks_by_unit[unit_number]
    if not record then
        return false
    end

    local entity = ei_lib.get_valid_entity(record.entity)
    if not is_tank(entity) then
        remove_record(runtime, unit_number, "invalid")
        return true
    end

    if not tank_has_player_occupant(entity) then
        bump(runtime, "hover_inactive_samples", 1)
        set_hover_active(runtime, record, entity, current_tick, false)
        return true
    end

    record.hover_active = true
    local position = entity.position
    local last_x = tonumber(record.last_hover_x) or position.x
    local last_y = tonumber(record.last_hover_y) or position.y
    local dx = position.x - last_x
    local dy = position.y - last_y
    local distance_sq = dx * dx + dy * dy

    record.last_hover_x = position.x
    record.last_hover_y = position.y
    record.surface_index = entity.surface and entity.surface.index or nil
    record.force_index = entity.force and entity.force.index or nil
    record.last_seen_tick = current_tick
    bump(runtime, "hover_samples", 1)

    local moving = distance_sq >= visual_config.movement_threshold_sq
    local interval = moving and visual_config.moving_emit_interval or visual_config.idle_emit_interval
    local last_emit_tick = tonumber(record.last_hover_emit_tick) or 0

    if current_tick - last_emit_tick >= interval then
        emit_hover_shimmer(runtime, record, entity, current_tick, visual_config, budget, not moving)
    end

    if record.hover_active == true then
        queue_hover_unit(runtime, unit_number)
    end
    return true
end

local function queue_active_hover_units(runtime)
    -- Backstop repair only. Normal enter/exit events and per-unit requeues keep
    -- hover activity current without scanning every tracked tank each tick.
    local active = 0
    local stale_units = nil

    for unit_number, record in pairs(runtime.tanks_by_unit) do
        local entity = ei_lib.get_valid_entity(record.entity)
        if is_tank(entity) then
            if record.hover_active == true then
                active = active + 1
                queue_hover_unit(runtime, unit_number)
            end
        else
            stale_units = stale_units or {}
            stale_units[#stale_units + 1] = unit_number
        end
    end

    if stale_units then
        for _, unit_number in ipairs(stale_units) do
            remove_record(runtime, unit_number, "invalid")
        end
    end

    return active
end

function model.service_hover_queue(runtime, current_tick, visual_config)
    -- Presentation loop. It intentionally does not drive gameplay, equipment,
    -- or charge state; it can be skipped entirely when visuals are disabled.
    visual_config = visual_config or get_hover_visual_config()
    if visual_config.enabled ~= true then
        runtime.hover_queue = scheduler.clear_queue(runtime.hover_queue)
        return 0
    end

    if current_tick % visual_config.update_interval ~= 0 then
        return 0
    end

    local active = tonumber(runtime.hover_active_count) or 0
    if active <= 0 then
        runtime.hover_queue = scheduler.clear_queue(runtime.hover_queue)
        return 0
    end

    -- Normal occupancy events and per-unit self-requeue keep this queue hot.
    -- Fall back to a full tracked-tank scan only if the active count says work
    -- exists but the queue was somehow lost after migration or manual repair.
    if type(runtime.hover_queue.queued) ~= "table"
        or next(runtime.hover_queue.queued) == nil
        or current_tick % STATUS_REFRESH_INTERVAL == 0
    then
        active = queue_active_hover_units(runtime)
        if active <= 0 then
            runtime.hover_queue = scheduler.clear_queue(runtime.hover_queue)
            return 0
        end
    end

    local limit = visual_config.service_cap_value
    if limit == nil then
        limit = active
    end
    limit = math.max(0, math.floor(tonumber(limit) or 0))

    local budget = {
        emitters = 0,
        global_emitter_cap = visual_config.global_emitter_cap_value,
    }
    local serviced = 0

    for _ = 1, limit do
        local unit_number = scheduler.queue_pop_queued(runtime.hover_queue)
        if not unit_number then
            break
        end

        if service_hover_unit(runtime, unit_number, current_tick, visual_config, budget) then
            serviced = serviced + 1
        end
    end

    return serviced
end

function model.cleanup_shield_pulses(runtime, current_tick)
    -- Rendering TTL handles normal expiration, but keeping handles lets status
    -- and QC observe pulses and lets reset paths destroy anything still valid.
    if runtime.next_pulse_cleanup_tick == 0 or current_tick < runtime.next_pulse_cleanup_tick then
        return 0
    end

    local cleaned = 0
    local next_due_tick = 0
    for pulse_id, pulse in pairs(runtime.shield_pulses) do
        local expires_tick = tonumber(pulse.expires_tick) or 0
        if expires_tick <= current_tick then
            clear_render(pulse.render)
            runtime.shield_pulses[pulse_id] = nil
            cleaned = cleaned + 1
        elseif next_due_tick == 0 or expires_tick < next_due_tick then
            next_due_tick = expires_tick
        end
    end
    runtime.next_pulse_cleanup_tick = next_due_tick
    if cleaned > 0 then
        bump(runtime, "shield_pulses_cleaned", cleaned)
    end
    return cleaned
end

function model.make_shield_pulse(runtime, entity, current_tick, skip_equipment_check)
    -- Damage can arrive in bursts. Coalescing keeps the membrane legible and
    -- prevents overlapping 48-frame pulses from becoming a render-object tax.
    if not skip_equipment_check then
        local repairs = ensure_equipment(entity)
        if repairs > 0 then
            bump(runtime, "grid_repairs", repairs)
        end
    end

    local unit_number = ei_lib.get_entity_unit_number(entity)
    local record = unit_number and runtime.tanks_by_unit[unit_number] or nil
    if record then
        local last_pulse_tick = tonumber(record.last_shield_pulse_tick) or -999999
        if current_tick - last_pulse_tick < SHIELD_PULSE_COALESCE_TICKS then
            bump(runtime, "shield_pulses_coalesced", 1)
            return false
        end
        record.last_shield_pulse_tick = current_tick
    end

    local pulse = {
        render = nil,
        expires_tick = current_tick + SHIELD_PULSE_TTL,
        unit_number = unit_number,
    }

    local ok = pcall(function()
        pulse.render = rendering.draw_animation{
            animation = SHIELD_PULSE_ANIMATION,
            target = entity,
            surface = entity.surface,
            render_layer = "higher-object-above",
            animation_speed = 1,
            x_scale = SHIELD_PULSE_SCALE,
            y_scale = SHIELD_PULSE_SCALE,
            time_to_live = SHIELD_PULSE_TTL,
            forces = {entity.force},
        }
    end)
    if not ok or not pulse.render then
        bump(runtime, "visual_failures", 1)
    end

    runtime.next_pulse_id = (tonumber(runtime.next_pulse_id) or 0) + 1
    local pulse_id = runtime.next_pulse_id
    runtime.shield_pulses[pulse_id] = pulse
    if runtime.next_pulse_cleanup_tick == 0 or pulse.expires_tick < runtime.next_pulse_cleanup_tick then
        runtime.next_pulse_cleanup_tick = pulse.expires_tick
    end
    bump(runtime, "shield_pulses", 1)
    return true
end

function model.apply_aegis_reprisal(runtime, entity, record, current_tick)
    if not is_tank(entity) then
        return 0
    end

    local cache = model.get_doctrine_force_cache(runtime, entity.force, current_tick)
    local profile = cache.aegis_reprisal or DOCTRINE.aegis_profiles[0]
    if profile.enabled ~= true then
        return 0
    end

    local cooldown = math.max(1, tonumber(profile.cooldown) or 1)
    if current_tick - (tonumber(record and record.last_aegis_reprisal_tick) or 0) < cooldown then
        return 0
    end
    if record then
        record.last_aegis_reprisal_tick = current_tick
    end

    local position = entity.position
    local radius = math.max(1, tonumber(profile.radius) or 1)
    local cap = math.max(1, math.floor(tonumber(profile.cap) or 1))
    local damage = math.max(1, math.floor(tonumber(profile.damage) or 1))
    local source_force = model.get_entity_force(entity)
    local hits = 0
    local entities = entity.surface.find_entities_filtered{
        area = {{position.x - radius, position.y - radius}, {position.x + radius, position.y + radius}},
    }

    for _, target in pairs(entities) do
        if hits >= cap then
            break
        end

        local target_position = model.copy_entity_position(target)
        if target ~= entity
            and target_position
            and model.entity_has_health(target)
            and relation_is_enemy(source_force, model.get_entity_force(target)) then
            local dx = target_position.x - position.x
            local dy = target_position.y - position.y
            if (dx * dx) + (dy * dy) <= radius * radius then
                local ok = pcall(function()
                    target.damage(damage, entity.force, DAMAGE_TYPE, entity)
                end)
                if ok then
                    hits = hits + 1
                    bump(runtime, "aegis_reprisal_hits", 1)
                    if hits <= 6 then
                        draw_animation_visual(
                            runtime,
                            entity.surface,
                            entity.force,
                            HIT_FLASH_ANIMATION,
                            target_position,
                            20,
                            0.5,
                            "projectile",
                            "hit_flashes"
                        )
                    end
                else
                    bump(runtime, "aegis_reprisal_failures", 1)
                end
            end
        end
    end
    return hits
end

function model.enforce_all_tracked_equipment(runtime)
    local repaired = 0
    for unit_number, record in pairs(runtime.tanks_by_unit) do
        local entity = ei_lib.get_valid_entity(record.entity)
        if is_tank(entity) then
            repaired = repaired + ensure_equipment(entity)
        else
            remove_record(runtime, unit_number, "invalid")
        end
    end
    if repaired > 0 then
        bump(runtime, "grid_repairs", repaired)
    end
    return repaired
end

function model.make_status(runtime, current_tick)
    -- Status is the slow, truthful snapshot: scan tracked tanks, remove stale
    -- records, and mirror a compact module status for debug/QC tools.
    current_tick = resolve_tick(current_tick)
    local visual_config = get_hover_visual_config()
    local tracked = 0
    local charging = 0
    local cooling_down = 0
    local active_motion = 0
    local active_hover = 0
    local representative_tank = nil
    local stale_units = nil

    for unit_number, record in pairs(runtime.tanks_by_unit) do
        local entity = ei_lib.get_valid_entity(record.entity)
        if is_tank(entity) then
            representative_tank = representative_tank or entity
            tracked = tracked + 1
            if runtime.pending_by_unit[unit_number] then
                charging = charging + 1
            end
            if current_tick < (tonumber(record.cooldown_until_tick) or 0) then
                cooling_down = cooling_down + 1
            end
            if drift_speed(record) >= MOTION_MIN_ACTIVE_DRIFT
                or tank_has_driver(record.entity)
                or record_has_active_apocalypse_job(runtime, record, current_tick) then
                active_motion = active_motion + 1
            end
            if record.hover_active == true and tank_has_player_occupant(entity) then
                active_hover = active_hover + 1
            end
        else
            stale_units = stale_units or {}
            stale_units[#stale_units + 1] = unit_number
        end
    end

    if stale_units then
        for _, unit_number in ipairs(stale_units) do
            remove_record(runtime, unit_number, "invalid")
        end
    end

    local status = {
        tick = current_tick,
        tracked_tanks = tracked,
        charging = charging,
        cooling_down = cooling_down,
        active_motion = active_motion,
        active_hover = active_hover,
        hover_active_count = tonumber(runtime.hover_active_count) or 0,
        charge_queue_items = scheduler.queue_item_count(runtime.charge_queue),
        charge_bucket_count = scheduler.delayed_bucket_count(runtime.charge_buckets),
        charge_bucket_items = scheduler.delayed_item_count(runtime.charge_buckets),
        motion_queue_items = scheduler.queue_item_count(runtime.motion_queue),
        motion_queue_unique = scheduler.table_count(runtime.motion_queue.queued),
        hover_queue_items = scheduler.queue_item_count(runtime.hover_queue),
        hover_queue_unique = scheduler.table_count(runtime.hover_queue.queued),
        terrain_spiral_jobs = scheduler.table_count(runtime.terrain_spiral_jobs),
        terrain_spiral_queue_items = scheduler.queue_item_count(runtime.terrain_spiral_queue),
        terrain_spiral_queue_unique = scheduler.table_count(runtime.terrain_spiral_queue.queued),
        hover_visuals_enabled = visual_config.enabled == true,
        hover_visual_fidelity = visual_config.visual_fidelity,
        hover_update_interval = visual_config.update_interval,
        hover_service_cap = visual_config.service_cap_value or "unbounded",
        hover_global_emitter_cap = visual_config.global_emitter_cap_value or "unbounded",
        shield_pulses = scheduler.table_count(runtime.shield_pulses),
        orbital_shards = orbital_shards.status(runtime, representative_tank),
        shard_settings_count = scheduler.table_count(runtime.tank_settings_by_unit),
        doctrine_force_cache_count = scheduler.table_count(runtime.doctrine_force_cache),
        shard_open_guis = scheduler.table_count(runtime.open_by_player),
        next_charge_due_tick = runtime.next_charge_due_tick,
        next_pulse_cleanup_tick = runtime.next_pulse_cleanup_tick,
        qc_enabled = runtime.qc.enabled == true,
        counters = model.counter_snapshot(runtime),
    }
    runtime.last_status_tick = current_tick
    scheduler.set_module_status(MODULE_NAME, status)
    return status
end

function model.maybe_status(runtime, current_tick)
    if current_tick - (tonumber(runtime.last_status_tick) or 0) >= STATUS_REFRESH_INTERVAL then
        model.refresh_registered_orbital_shard_damage_statuses(runtime, nil, current_tick)
        model.make_status(runtime, current_tick)
    end
end

function model.check_global(event_or_tick)
    local runtime = ensure_runtime()
    local current_tick = resolve_tick(event_or_tick)
    orbital_shards.sync_all_force_caches(runtime, current_tick)
    model.sync_all_doctrine_force_caches(runtime, current_tick)
    refresh_orbital_shard_damage_statuses(runtime, nil, current_tick)
    return runtime
end

function model.rebuild_runtime_state(reason, current_tick)
    -- Configuration changes and QC resets rebuild from live tank entities. This
    -- intentionally discards derived queues, cached counts, and registrations.
    reset_hover_visual_config_cache()
    model.hot_counter_shadow = {}
    current_tick = resolve_tick(current_tick)
    storage.ei = storage.ei or {}
    local previous_runtime = storage.ei.emerald_apocalypse_hover_tank
    local preserved_settings = type(previous_runtime) == "table"
        and copy_tank_settings(previous_runtime.tank_settings_by_unit)
        or {}
    gui.close_all(previous_runtime)
    storage.ei.emerald_apocalypse_hover_tank = new_runtime()
    local runtime = ensure_runtime()
    runtime.tank_settings_by_unit = preserved_settings
    orbital_shards.sync_all_force_caches(runtime, current_tick)
    model.sync_all_doctrine_force_caches(runtime, current_tick)

    if game and game.surfaces then
        for _, surface in pairs(game.surfaces) do
            if surface and surface.valid then
                for _, entity in pairs(surface.find_entities_filtered{name = TANK_NAME}) do
                    register_tank(runtime, entity, current_tick)
                end
            end
        end
    end

    refresh_orbital_shard_damage_statuses(runtime, nil, current_tick)
    gui.prune_orphaned_tank_settings(runtime)
    bump(runtime, "rebuilt", 1)
    local status = model.make_status(runtime, current_tick)
    status.rebuild_reason = reason or "rebuild"
    scheduler.set_module_status(MODULE_NAME, status)
    return runtime
end

function model.reset_runtime_state(reason, current_tick)
    return model.rebuild_runtime_state(reason or "reset", current_tick)
end

function model.on_configuration_changed(event)
    return model.rebuild_runtime_state("configuration-changed", resolve_tick(event))
end

function model.on_research_finished(event)
    local force = event and event.research and event.research.force or nil
    if not force or not force.valid then
        return false
    end

    local runtime = ensure_runtime()
    local current_tick = resolve_tick(event)
    local old_cache = runtime.orbital_shards
        and runtime.orbital_shards.force_cache
        and runtime.orbital_shards.force_cache[force.index]
        or nil
    local old_max_count = old_cache and old_cache.shard_count or 3
    local force_cache = orbital_shards.sync_force_cache(runtime, force, current_tick)
    model.release_legacy_max_shard_overrides(runtime, force, old_max_count, force_cache and force_cache.shard_count)
    model.sync_doctrine_force_cache(runtime, force, current_tick)
    refresh_orbital_shard_damage_statuses(runtime, force, current_tick)
    gui.refresh_open_guis_for_force(runtime, force, current_tick)
    model.make_status(runtime, current_tick)
    return true
end

function model.on_scripted_research_burst(force, current_tick)
    if not force or not force.valid then
        return false
    end

    local runtime = ensure_runtime()
    current_tick = resolve_tick(current_tick)
    local old_cache = runtime.orbital_shards
        and runtime.orbital_shards.force_cache
        and runtime.orbital_shards.force_cache[force.index]
        or nil
    local old_max_count = old_cache and old_cache.shard_count or 3
    local force_cache = orbital_shards.sync_force_cache(runtime, force, current_tick)
    model.release_legacy_max_shard_overrides(runtime, force, old_max_count, force_cache and force_cache.shard_count)
    model.sync_doctrine_force_cache(runtime, force, current_tick)
    refresh_orbital_shard_damage_statuses(runtime, force, current_tick)
    gui.refresh_open_guis_for_force(runtime, force, current_tick)
    model.make_status(runtime, current_tick)
    return true
end

function model.on_built_entity(event_or_entity)
    local entity = get_event_entity(event_or_entity)
    if not is_tank(entity) then
        return false
    end

    return register_tank(ensure_runtime(), entity, resolve_tick(event_or_entity)) ~= nil
end

function model.on_cloned_entity(event)
    return model.on_built_entity(event)
end

function model.on_destroyed_entity(event_or_entity)
    local entity = get_event_entity(event_or_entity)
    if not is_tank(entity) then
        return false
    end

    local unit_number = ei_lib.get_entity_unit_number(entity)
    return remove_record(ensure_runtime(), unit_number, "destroyed")
end

function model.on_object_destroyed(event)
    local runtime = ensure_runtime()
    local registration_number = event and event.registration_number
    local payload = runtime.registrations[registration_number]
    if not payload then
        return false
    end

    runtime.registrations[registration_number] = nil
    if payload.kind == "tank" then
        return remove_record(runtime, payload.unit_number, "destroyed")
    end

    return false
end

function model.on_player_driving_changed_state(event)
    local player = game and game.get_player(event and event.player_index) or nil
    local vehicle = ei_lib.get_valid_entity(event and event.entity)
        or (player and ei_lib.get_valid_entity(player.vehicle) or nil)
    if not is_tank(vehicle) then
        return false
    end

    local runtime = ensure_runtime()
    local current_tick = resolve_tick(event)
    local record = register_tank(runtime, vehicle, current_tick)
    sync_hover_activity(runtime, record, vehicle, current_tick)
    return true
end

function model.on_player_placed_equipment(event)
    local owner = get_grid_owner_entity(event and event.grid)
    if not is_tank(owner) then
        return false
    end

    local runtime = ensure_runtime()
    local current_tick = resolve_tick(event)
    local record = register_tank(runtime, owner, current_tick)
    if record then
        record.movement_equipment_factor_tick = -1
    end
    return true
end

function model.on_player_removed_equipment(event)
    local name = event and event.equipment
    local owner = get_grid_owner_entity(event and event.grid)
    if not is_fixed_equipment_name(name) then
        if is_tank(owner) then
            local runtime = ensure_runtime()
            local unit_number = ei_lib.get_entity_unit_number(owner)
            local record = unit_number and runtime.tanks_by_unit[unit_number] or nil
            if record then
                record.movement_equipment_factor_tick = -1
            end
        end
        return false
    end

    local runtime = ensure_runtime()
    local current_tick = resolve_tick(event)
    local repaired = 0
    local blocked = false

    if is_tank(owner) then
        -- This event fires after the hidden fixed equipment has already been
        -- handed to the player. Put the built-in gear back immediately, then
        -- purge the returned hidden item so the grid behaves as non-removable.
        repaired = ensure_equipment(owner)
        if repaired > 0 then
            bump(runtime, "grid_repairs", repaired)
        end
        register_tank(runtime, owner, current_tick)
        blocked = has_fixed_equipment(owner)
    else
        repaired = model.enforce_all_tracked_equipment(runtime)
        blocked = repaired > 0
    end

    if blocked then
        bump(runtime, "fixed_equipment_removals_blocked", 1)
        purge_removed_fixed_equipment_item(runtime, event)
        return true
    end

    bump(runtime, "fixed_equipment_repair_failures", 1)
    return false
end

function model.on_script_trigger_effect(event)
    if not event or event.effect_id ~= CHARGE_EFFECT_ID then
        return false
    end

    local source = ei_lib.get_valid_entity(event.source_entity) or get_event_entity(event)
    if not is_tank(source) then
        return false
    end

    local runtime = ensure_runtime()
    local current_tick = resolve_tick(event)
    local record = register_tank(runtime, source, current_tick)
    if not record then
        return false
    end

    return start_charge(runtime, record, event, current_tick)
end

function model.on_entity_damaged(event)
    local entity = event and ei_lib.get_valid_entity(event.entity) or nil
    if not is_tank(entity) then
        return false
    end

    local runtime = ensure_runtime()
    local current_tick = resolve_tick(event)
    local record = register_tank(runtime, entity, current_tick)
    model.make_shield_pulse(runtime, entity, current_tick, true)
    model.apply_aegis_reprisal(runtime, entity, record, current_tick)
    return true
end

function model.has_tick_work(event)
    local runtime = storage and storage.ei and storage.ei.emerald_apocalypse_hover_tank or nil
    if type(runtime) ~= "table" then
        return false
    end

    if runtime.version ~= RUNTIME_VERSION then
        return true
    end

    local current_tick = resolve_tick(event)
    if raw_queue_has_items(runtime.charge_queue)
        or raw_queue_has_items(runtime.motion_queue)
        or raw_queue_has_items(runtime.terrain_spiral_queue)
        or (current_tick % STATUS_REFRESH_INTERVAL == 0 and raw_has_active_motion_record(runtime))
        or raw_table_has_entries(runtime.terrain_spiral_jobs)
    then
        return true
    end

    local next_charge_due_tick = runtime.next_charge_due_tick or 0
    if next_charge_due_tick > 0 and current_tick >= next_charge_due_tick then
        return true
    end

    local next_pulse_cleanup_tick = runtime.next_pulse_cleanup_tick or 0
    if next_pulse_cleanup_tick > 0 and current_tick >= next_pulse_cleanup_tick then
        return true
    end
    if next_pulse_cleanup_tick <= 0 and raw_table_has_entries(runtime.shield_pulses) then
        return true
    end

    return raw_orbital_shards_has_tick_work(runtime.orbital_shards, current_tick)
end

function model.has_hot_tick_work(event)
    local runtime = storage and storage.ei and storage.ei.emerald_apocalypse_hover_tank or nil
    if type(runtime) ~= "table" then
        return false
    end

    local current_tick = resolve_tick(event)
    return (tonumber(runtime.hover_active_count) or 0) > 0
        or raw_queue_has_items(runtime.hover_queue)
        or (current_tick % STATUS_REFRESH_INTERVAL == 0 and raw_has_active_hover_record(runtime))
end

function model.get_pending_work_count(event)
    -- Side-effect-free status helper for QC/debug callers. The dispatcher uses
    -- has_tick_work() and lets update() activate due buckets.
    local runtime = ensure_runtime()
    local current_tick = resolve_tick(event)
    if runtime.pending_work_tick == current_tick and runtime.pending_work_count ~= nil then
        return runtime.pending_work_count
    end

    local orbital_pending = orbital_shards.get_pending_work_count(runtime, current_tick)
    local pending = scheduler.queue_item_count(runtime.charge_queue)
        + scheduler.queue_item_count(runtime.motion_queue)
        + scheduler.queue_item_count(runtime.terrain_spiral_queue)
        + orbital_pending
    if (runtime.next_charge_due_tick or 0) > 0 and current_tick >= runtime.next_charge_due_tick then
        pending = pending + 1
    end
    local next_pulse_cleanup_tick = runtime.next_pulse_cleanup_tick or 0
    if next_pulse_cleanup_tick > 0 and current_tick >= next_pulse_cleanup_tick then
        pending = pending + 1
    elseif next_pulse_cleanup_tick <= 0 and raw_table_has_entries(runtime.shield_pulses) then
        pending = pending + 1
    end
    if pending <= 0 and raw_has_active_motion_record(runtime) then
        pending = 1
    end
    if pending <= 0 and raw_table_has_entries(runtime.terrain_spiral_jobs) then
        pending = 1
    end
    runtime.pending_work_tick = current_tick
    runtime.pending_work_count = pending
    return pending
end

function model.update(event)
    -- Cold gameplay service: charge completion, scripted motion, shield cleanup,
    -- and orbital shard logic. Visual-only hover shimmer lives in hot_update().
    local runtime = ensure_runtime()
    local current_tick = resolve_tick(event)
    invalidate_pending_work_cache(runtime)
    activate_due_charges(runtime, current_tick)
    model.cleanup_shield_pulses(runtime, current_tick)

    local did_work = false
    if service_charge_queue(runtime, current_tick) then
        did_work = true
    end
    if not raw_queue_has_items(runtime.motion_queue) and raw_has_active_motion_record(runtime) then
        queue_active_motion_units(runtime, current_tick)
    end
    if service_motion_queue(runtime, current_tick) then
        did_work = true
    end
    if model.service_terrain_spiral_queue(runtime, current_tick) > 0 then
        did_work = true
    end
    if orbital_shards.update(runtime, current_tick) > 0 then
        did_work = true
    end

    model.maybe_status(runtime, current_tick)
    return did_work
end

function model.hot_update(event)
    -- Hot presentation service. Exit before touching queues unless at least one
    -- player-occupied tank has active hover visuals.
    local runtime = ensure_runtime()
    if (tonumber(runtime.hover_active_count) or 0) <= 0 then
        queue_active_hover_units(runtime)
    end
    if (tonumber(runtime.hover_active_count) or 0) <= 0 then
        runtime.hover_queue = scheduler.clear_queue(runtime.hover_queue)
        return 0
    end

    local current_tick = resolve_tick(event)
    local serviced = model.service_hover_queue(runtime, current_tick, get_hover_visual_config())
    if serviced > 0 then
        model.maybe_status(runtime, current_tick)
    end
    return serviced
end

function model.service_for_qc(limit, event_or_tick)
    local runtime = ensure_runtime()
    local current_tick = resolve_tick(event_or_tick)
    limit = math.max(1, math.floor(tonumber(limit) or 1))
    local serviced = 0
    for _ = 1, limit do
        orbital_shards.hot_update(runtime, current_tick)
        local hover_serviced = model.hot_update(current_tick)
        if model.update(current_tick) or hover_serviced > 0 then
            serviced = serviced + 1
        else
            break
        end
    end
    return serviced
end

function model.configure_qc(config, event_or_tick)
    local runtime = ensure_runtime()
    runtime.qc.enabled = type(config) == "table" and config.enabled == true
    return model.get_qc_snapshot(resolve_tick(event_or_tick))
end

function model.get_runtime_status(current_tick)
    return model.make_status(ensure_runtime(), current_tick)
end

function model.get_qc_snapshot(current_tick)
    return model.get_runtime_status(current_tick)
end

-- Debug/QC exports. control.lua only needs charge_effect_id, but the other
-- stable names are useful for console probes and companion QC helpers.
model.tank_name = TANK_NAME
model.gui_name = GUI_NAME
model.charge_effect_id = CHARGE_EFFECT_ID
model.charge_item = CHARGE_ITEM
model.hover_setting_name = hover_config.setting_name
model.orbital_shard_beam = orbital_shards.beam_name
model.visual_prototypes = {
    chargeup = CHARGEUP_ANIMATION,
    muzzle_flash = MUZZLE_FLASH_ANIMATION,
    beam = MAIN_BEAM_NAME,
    impact = IMPACT_EXPLOSION,
    shockwave = SHOCKWAVE_EXPLOSION,
    hit_flash = HIT_FLASH_ANIMATION,
    scorchmark = SCORCHMARK_NAME,
    shield_pulse = SHIELD_PULSE_ANIMATION,
    terrain_spiral_tile = TERRAIN_SPIRAL_TILE,
}

return model
