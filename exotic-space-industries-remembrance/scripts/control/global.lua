--==============================================================================
-- ESIR FILE MAP
-- owns: root storage schema and scheduled runtime sanity
-- loaded_by: exotic-space-industries-remembrance\control.lua
-- cadence: init, configuration-changed, and scheduled tick step 1
-- forwarded_events: check_init, init
-- storage_roots: storage.ei
-- gui_ids: none
-- remote_interfaces: none
-- rebuild_on: init, configuration change
--==============================================================================
-- Init storage variables for Exotic Industries
ei_lib = require("lib/lib")
ei_echo_codex = require("lib/echo-codex")
local ei_runtime_scheduler = require("lib/runtime-scheduler")
local ei_global = {}
local BEACON_OVERLOAD_DEBUG_AUTO_ARM_DEFAULT = false

local function new_steam_train_runtime()
    -- Steam trains maintain a full tracked set plus a smaller active queue for frequent wheel updates.
    return {
        locomotives_by_unit = {},
        tracked_units = {},
        tracked_index_by_unit = {},
        active_units = {},
        active_index_by_unit = {},
        audit_cursor = 1
    }
end

local function new_beacon_overload_runtime()
    local function new_queue()
        return ei_runtime_scheduler.ensure_queue(nil)
    end

    return {
        enabled = ei_lib.config("beacon-overload") == true,
        tracked_machines = {},
        machine_counts = {},
        overloaded_units = {},
        tracked_count = 0,
        overloaded_count = 0,
        mode = nil,
        surface_queue = new_queue(),
        chunk_queue = new_queue(),
        machine_queue = new_queue(),
        queued_units = {},
        queued_chunk_keys = {},
        processed_chunk_keys = {},
        tracked_refresh_cursor = nil,
        tracked_audit_cursor = nil,
        icon_audit_cursor = nil,
        release_cursor = nil,
        last_reason = nil,
        debug = {
            enabled = false,
            auto_arm = BEACON_OVERLOAD_DEBUG_AUTO_ARM_DEFAULT,
            last_heartbeat_tick = 0,
            last_reason = nil,
            last_status = {},
        },
        compat = {
            machine_exclusions = {},
            beacon_exclusions = {},
            beacon_weights = {},
        }
    }
end

local function new_fluid_runtime()
    return {
        initialized = false,
        entries_by_unit = {},
        tracked_count = 0,
        scan_units = {},
        scan_index = 1,
        urgent_units = {},
        urgent_head = 1,
        urgent_tail = 1,
        urgent_pending = {},
        segments = {},
        dirty_segments = {},
        dirty_head = 1,
        dirty_tail = 1,
        dirty_pending = {},
        service_mode_cursor = 1,
    }
end

local function new_orbital_combinator_reconcile_state()
    return {
        next_due_tick = 0,
        cycle = 0,
        force_cursor = nil,
        platform_cursor = nil,
        cache_cursor = nil,
        cleanup_phase = false,
        in_progress = false,
    }
end

local function new_orbital_combinator_surface_generations()
    return {
        requests = {},
        on_the_way = {},
        need = {},
    }
end

local function new_orbital_combinator_runtime_state()
    return {
        banks = {},
        bank_by_unit = {},
        bank_count = 0,
        mode_by_unit = {},
        open_gui_by_player = {},
        platform_cache = {},
        platform_by_hub = {},
        object_registration = {},
        snapshot_cache = {},
        incoming_pods = {},
        surface_platform_index = {},
        surface_bank_index = {},
        surface_state = {},
        work_service = {},
        dirty_bank_queue = ei_runtime_scheduler.ensure_queue(nil),
        bank_audit_queue = ei_runtime_scheduler.ensure_queue(nil),
        hot_surface_queue = ei_runtime_scheduler.ensure_queue(nil),
        cold_surface_queue = ei_runtime_scheduler.ensure_queue(nil),
        hot_surface_break_point = nil,
        cold_surface_break_point = nil,
        connection_audit_break_point = nil,
        reconcile_state = new_orbital_combinator_reconcile_state(),
        surface_generations = new_orbital_combinator_surface_generations(),
        generation_epoch = 0,
        platform_reconcile_tick = 0,
        runtime_state_version = 0,
    }
end

local TECH_SCALING_AGES = {
    "dark-age",
    "steam-age",
    "electricity-age",
    "computer-age",
    "quantum-age",
    "exotic-age",
}

local function new_tech_scaling_age_totals()
    local totals = {}

    for _, age in ipairs(TECH_SCALING_AGES) do
        totals[age] = 0
    end

    return totals
end

local function new_tech_scaling_researched_snapshot(force_key)
    return {
        forceKey = force_key,
        totalWeight = 0,
        ageTotals = new_tech_scaling_age_totals(),
        researchedByName = {},
    }
end

local function new_tech_scaling_runtime()
    return {
        maxCost = 0,
        startPrice = 0,
        baseStartPrice = 0,
        techCount = 0,
        appliedMultiplier = 1,
        disabled = false,
        ageTotals = new_tech_scaling_age_totals(),
        techMetaByName = {},
        researchedSnapshot = new_tech_scaling_researched_snapshot(nil),
        selectedForceKey = nil,
        cacheRevision = 0,
        unknownAgeLogged = false,
    }
end

local function new_scripted_research_burst_runtime()
    return {
        pending_by_force = {},
        due_buckets = ei_runtime_scheduler.ensure_delayed_buckets(nil),
        next_due_tick = 0,
    }
end

local function get_scripted_research_burst_next_due_tick(pending_by_force)
    local next_due_tick = 0

    for _, entry in pairs(pending_by_force or {}) do
        if type(entry) == "table" and entry.pending == true then
            local scheduled_tick = math.max(0, math.floor(tonumber(entry.scheduled_tick) or 0))
            if scheduled_tick > 0 and (next_due_tick == 0 or scheduled_tick < next_due_tick) then
                next_due_tick = scheduled_tick
            end
        end
    end

    return next_due_tick
end

local function ensure_scripted_research_burst_runtime()
    if type(storage.ei.scripted_research_burst) ~= "table" then
        storage.ei.scripted_research_burst = new_scripted_research_burst_runtime()
        return
    end

    local runtime = storage.ei.scripted_research_burst
    runtime.pending_by_force = type(runtime.pending_by_force) == "table" and runtime.pending_by_force or {}
    runtime.due_buckets = ei_runtime_scheduler.ensure_delayed_buckets(runtime.due_buckets)

    local normalized_pending_by_force = {}
    for force_key, entry in pairs(runtime.pending_by_force) do
        if type(entry) == "table" then
            local normalized_force_index = tonumber(entry.force_index or force_key)
            if normalized_force_index then
                local normalized_entry = normalized_pending_by_force[normalized_force_index]
                if not normalized_entry then
                    normalized_entry = {
                        force_index = normalized_force_index,
                        source_tick = 0,
                        scheduled_tick = 0,
                        enqueued_tick = 0,
                        pending = false,
                        tesla_variant_sync_needed = false,
                    }
                    normalized_pending_by_force[normalized_force_index] = normalized_entry
                end

                normalized_entry.source_tick = math.max(
                    tonumber(normalized_entry.source_tick) or 0,
                    tonumber(entry.source_tick) or 0
                )
                normalized_entry.scheduled_tick = math.max(
                    tonumber(normalized_entry.scheduled_tick) or 0,
                    tonumber(entry.scheduled_tick) or 0
                )
                normalized_entry.enqueued_tick = math.max(
                    tonumber(normalized_entry.enqueued_tick) or 0,
                    tonumber(entry.enqueued_tick) or 0
                )
                normalized_entry.pending = normalized_entry.pending or entry.pending == true
                normalized_entry.tesla_variant_sync_needed = normalized_entry.tesla_variant_sync_needed
                    or entry.tesla_variant_sync_needed == true
            end
        end
    end

    runtime.pending_by_force = normalized_pending_by_force
    runtime.next_due_tick = get_scripted_research_burst_next_due_tick(runtime.pending_by_force)
end

local function ensure_tech_scaling_runtime()
    if type(storage.ei["tech_scaling"]) ~= "table" then
        storage.ei["tech_scaling"] = new_tech_scaling_runtime()
        return
    end

    local tech_scaling = storage.ei["tech_scaling"]

    if not tech_scaling.ageTotals then
        tech_scaling.ageTotals = new_tech_scaling_age_totals()
    else
        for _, age in ipairs(TECH_SCALING_AGES) do
            if tech_scaling.ageTotals[age] == nil then
                tech_scaling.ageTotals[age] = 0
            end
        end
    end

    if tech_scaling.maxCost == nil then
        tech_scaling.maxCost = 0
    end

    if tech_scaling.startPrice == nil then
        tech_scaling.startPrice = 0
    end

    if tech_scaling.baseStartPrice == nil then
        tech_scaling.baseStartPrice = 0
    end

    if tech_scaling.techCount == nil then
        tech_scaling.techCount = 0
    end

    if tech_scaling.appliedMultiplier == nil then
        tech_scaling.appliedMultiplier = 1
    else
        tech_scaling.appliedMultiplier = tonumber(tech_scaling.appliedMultiplier) or 1
    end

    tech_scaling.disabled = tech_scaling.disabled == true

    if type(tech_scaling.techMetaByName) ~= "table" then
        tech_scaling.techMetaByName = {}
    end

    if type(tech_scaling.researchedSnapshot) ~= "table" then
        tech_scaling.researchedSnapshot = new_tech_scaling_researched_snapshot(nil)
    else
        local snapshot = tech_scaling.researchedSnapshot
        snapshot.forceKey = snapshot.forceKey or nil
        snapshot.totalWeight = tonumber(snapshot.totalWeight) or 0
        if type(snapshot.ageTotals) ~= "table" then
            snapshot.ageTotals = new_tech_scaling_age_totals()
        else
            for _, age in ipairs(TECH_SCALING_AGES) do
                if snapshot.ageTotals[age] == nil then
                    snapshot.ageTotals[age] = 0
                end
            end
        end
        if type(snapshot.researchedByName) ~= "table" then
            snapshot.researchedByName = {}
        end
    end

    if tech_scaling.selectedForceKey ~= nil and type(tech_scaling.selectedForceKey) ~= "string" then
        tech_scaling.selectedForceKey = tostring(tech_scaling.selectedForceKey)
    end

    if tech_scaling.cacheRevision == nil then
        tech_scaling.cacheRevision = 0
    else
        tech_scaling.cacheRevision = tonumber(tech_scaling.cacheRevision) or 0
    end

    if tech_scaling.unknownAgeLogged == nil then
        tech_scaling.unknownAgeLogged = false
    end
end


--====================================================================================================
--GLOBAL VARIABLES
--====================================================================================================

function ei_global.init()
    storage.ei = {}

    storage.ei["tech_scaling"] = new_tech_scaling_runtime()
    storage.ei.scripted_research_burst = new_scripted_research_burst_runtime()

    storage.ei["overload_icons"] = {}
    storage.ei.beacon_overload = new_beacon_overload_runtime()
    storage.ei["neutron_collector_animation"] = {}
    storage.ei.neutron_runtime = {}
    storage.ei["spawner_queue"] = {}
    storage.ei["orbital_combinators"] = {}
    storage.ei.orbital_combinators_break_point = nil
    local orbital_runtime = new_orbital_combinator_runtime_state()
    storage.ei.orbital_combinator_banks = orbital_runtime.banks
    storage.ei.orbital_combinator_bank_by_unit = orbital_runtime.bank_by_unit
    storage.ei.orbital_combinator_banks_break_point = nil
    storage.ei.orbital_combinator_bank_count = orbital_runtime.bank_count
    storage.ei.orbital_combinator_mode_by_unit = orbital_runtime.mode_by_unit
    storage.ei.orbital_combinator_open_gui_by_player = orbital_runtime.open_gui_by_player
    storage.ei.orbital_combinator_platform_cache = orbital_runtime.platform_cache
    storage.ei.orbital_combinator_platform_by_hub = orbital_runtime.platform_by_hub
    storage.ei.orbital_combinator_incoming_pods = orbital_runtime.incoming_pods
    storage.ei.orbital_combinator_object_registration = orbital_runtime.object_registration
    storage.ei.orbital_combinator_snapshot_cache = orbital_runtime.snapshot_cache
    storage.ei.orbital_combinator_surface_platform_index = orbital_runtime.surface_platform_index
    storage.ei.orbital_combinator_surface_bank_index = orbital_runtime.surface_bank_index
    storage.ei.orbital_combinator_surface_state = orbital_runtime.surface_state
    storage.ei.orbital_combinator_work_service = orbital_runtime.work_service
    storage.ei.orbital_combinator_dirty_bank_queue = orbital_runtime.dirty_bank_queue
    storage.ei.orbital_combinator_bank_audit_queue = orbital_runtime.bank_audit_queue
    storage.ei.orbital_combinator_hot_surface_queue = orbital_runtime.hot_surface_queue
    storage.ei.orbital_combinator_cold_surface_queue = orbital_runtime.cold_surface_queue
    storage.ei.orbital_combinator_hot_surface_break_point = orbital_runtime.hot_surface_break_point
    storage.ei.orbital_combinator_cold_surface_break_point = orbital_runtime.cold_surface_break_point
    storage.ei.orbital_combinator_connection_audit_break_point = orbital_runtime.connection_audit_break_point
    storage.ei.orbital_combinator_reconcile_state = orbital_runtime.reconcile_state
    storage.ei.orbital_combinator_surface_generations = orbital_runtime.surface_generations
    storage.ei.orbital_combinator_generation_epoch = orbital_runtime.generation_epoch
    storage.ei.orbital_combinator_platform_reconcile_tick = orbital_runtime.platform_reconcile_tick
    storage.ei.orbital_combinator_runtime_state_version = orbital_runtime.runtime_state_version
    storage.ei["rocket_launch_pollution"] = {}
    storage.ei["rocket_launch_pollution"].mode = "linear"
    storage.ei["rocket_launch_pollution"].cap = 10000
    storage.ei["rocket_launch_pollution"].launch_smoke = {}
    storage.ei["rocket_launch_pollution"].pending_launches_by_silo = {}
    storage.ei["rocket_launch_pollution"].pending_launch_cleanup_buckets = {}
    storage.ei.fulgora_day_length_variation = {}
    storage.ei.enemy_difficulty = "Tempered"
    storage.ei.nauvis_pressure = {}
    storage.ei.nauvis_pressure.milestone = 0
    storage.ei.nauvis_pressure.last_run_tick = 0
    --depreciated by NSB
    --storage.ei.spaced_updates = 0
    storage.ei.fluid_runtime = new_fluid_runtime()
    storage.ei.fluid_entity = {}
    storage.ei.fluid_entity_count = 0
    storage.ei.arrival_waves = {}
    storage.ei.pending_arrivals = {}
    storage.ei.alien = {}
    -- Initialize the indexed steam train runtime shape up front so new saves and migrated saves agree.
    storage.ei.locomotives = new_steam_train_runtime()
    storage.ei.campfire = {}
    storage.ei.campfire_last_run_tick = 0
    storage.ei.beacon_overload.debug.auto_arm = BEACON_OVERLOAD_DEBUG_AUTO_ARM_DEFAULT
    storage.ei.vulcanus_fumaroles = {
        backfill_bootstrapped = false,
        processed_chunks = {},
        history_chunks = {},
        cooldown_chunks = {},
        backfill_queue = ei_runtime_scheduler.ensure_queue(nil),
        active = {},
        active_chunk_buckets = {},
        dormant_chunks = {},
        dormant_delayed_buckets = {},
        dormant_surface_queues = {},
        dormant_surface_counts = {},
        dormant_active_surfaces = {},
        dormant_active_surface_positions = {},
        dormant_active_surface_cursor = 0,
        zero_active_since_tick = nil,
    }
    ei_lib.crystal_echo("»» INITIALIZING SYSTEM CORE: ＥＸＯＴＩＣ ＳＰΛＣΣ ＩＮＤＵＳＴＲＩＥＳ ««","default-bold")
    ei_lib.crystal_echo(">> Integrating chronometric lattices... Binding entropy to mass... Stand by.","default-semibold")
end

function ei_global.check_init(event)
    -- TODO: dont hardcode this
    if not storage.ei then
	    storage.ei = {}
    end
    if not storage.ei.arrival_waves then
        storage.ei.arrival_waves = {}
    end
    if not storage.ei.pending_arrivals then
        storage.ei.pending_arrivals = {}
    end
    if not storage.ei.campfire then
        storage.ei.campfire = {}
    end
    if not storage.ei.campfire_last_run_tick then
        storage.ei.campfire_last_run_tick = 0
    end
    -- Older saves may still carry the legacy locomotive array, so rebuild the container if the
    -- indexed fields are missing.
    if not storage.ei.locomotives or not storage.ei.locomotives.locomotives_by_unit then
        storage.ei.locomotives = new_steam_train_runtime()
    end
    if not storage.ei.rocket_launch_pollution then
        storage.ei.rocket_launch_pollution = {}
        storage.ei["rocket_launch_pollution"].mode = "linear"
        storage.ei["rocket_launch_pollution"].cap = 10000
    end
    if not storage.ei.rocket_launch_pollution.launch_smoke then
        storage.ei.rocket_launch_pollution.launch_smoke = {}
    end
    if not storage.ei.rocket_launch_pollution.pending_launches_by_silo then
        storage.ei.rocket_launch_pollution.pending_launches_by_silo = {}
    end
    if not storage.ei.rocket_launch_pollution.pending_launch_cleanup_buckets then
        storage.ei.rocket_launch_pollution.pending_launch_cleanup_buckets = {}
    end
    if not storage.ei.fulgora_day_length_variation then
        storage.ei.fulgora_day_length_variation = {}
    end
    if not storage.ei.enemy_difficulty then
        storage.ei.enemy_difficulty = "Tempered"
    end
    if not storage.ei.nauvis_pressure then
        storage.ei.nauvis_pressure = {}
        storage.ei.nauvis_pressure.milestone = 0
    end
    if not storage.ei.nauvis_pressure.last_run_tick then
        storage.ei.nauvis_pressure.last_run_tick = 0
    end
    ensure_tech_scaling_runtime()
    ensure_scripted_research_burst_runtime()

    if not storage.ei["overload_icons"] then
        storage.ei["overload_icons"] = {}
    end
    if not storage.ei.beacon_overload then
        storage.ei.beacon_overload = new_beacon_overload_runtime()
    end
    if storage.ei.beacon_overload.enabled == nil then
        storage.ei.beacon_overload.enabled = ei_lib.config("beacon-overload") == true
    else
        storage.ei.beacon_overload.enabled = storage.ei.beacon_overload.enabled == true
    end
    if not storage.ei.beacon_overload.tracked_machines then
        storage.ei.beacon_overload.tracked_machines = {}
    end
    if not storage.ei.beacon_overload.machine_counts then
        storage.ei.beacon_overload.machine_counts = {}
    end
    if not storage.ei.beacon_overload.overloaded_units then
        storage.ei.beacon_overload.overloaded_units = {}
    end
    if storage.ei.beacon_overload.tracked_count == nil then
        storage.ei.beacon_overload.tracked_count = 0
    end
    if storage.ei.beacon_overload.overloaded_count == nil then
        storage.ei.beacon_overload.overloaded_count = 0
    end
    if storage.ei.beacon_overload.tracked_refresh_cursor == nil then
        storage.ei.beacon_overload.tracked_refresh_cursor = nil
    end
    if storage.ei.beacon_overload.tracked_audit_cursor == nil then
        storage.ei.beacon_overload.tracked_audit_cursor = nil
    end
    if storage.ei.beacon_overload.icon_audit_cursor == nil then
        storage.ei.beacon_overload.icon_audit_cursor = nil
    end
    if storage.ei.beacon_overload.release_cursor == nil then
        storage.ei.beacon_overload.release_cursor = nil
    end
    if storage.ei.beacon_overload.last_reason == nil then
        storage.ei.beacon_overload.last_reason = nil
    end
    storage.ei.beacon_overload.surface_queue = ei_runtime_scheduler.ensure_queue(
        type(storage.ei.beacon_overload.surface_queue) == "table" and storage.ei.beacon_overload.surface_queue or nil
    )
    storage.ei.beacon_overload.chunk_queue = ei_runtime_scheduler.ensure_queue(
        type(storage.ei.beacon_overload.chunk_queue) == "table" and storage.ei.beacon_overload.chunk_queue or nil
    )
    storage.ei.beacon_overload.machine_queue = ei_runtime_scheduler.ensure_queue(
        type(storage.ei.beacon_overload.machine_queue) == "table" and storage.ei.beacon_overload.machine_queue or nil
    )
    if not storage.ei.beacon_overload.queued_units then
        storage.ei.beacon_overload.queued_units = {}
    end
    if not storage.ei.beacon_overload.queued_chunk_keys then
        storage.ei.beacon_overload.queued_chunk_keys = {}
    end
    if not storage.ei.beacon_overload.processed_chunk_keys then
        storage.ei.beacon_overload.processed_chunk_keys = {}
    end
    if not storage.ei.beacon_overload.debug or type(storage.ei.beacon_overload.debug) ~= "table" then
        storage.ei.beacon_overload.debug = {
            enabled = false,
            auto_arm = BEACON_OVERLOAD_DEBUG_AUTO_ARM_DEFAULT,
            last_heartbeat_tick = 0,
            last_reason = nil,
            last_status = {},
        }
    end
    if storage.ei.beacon_overload.debug.enabled == nil then
        storage.ei.beacon_overload.debug.enabled = false
    end
    if storage.ei.beacon_overload.debug.auto_arm == nil then
        storage.ei.beacon_overload.debug.auto_arm = BEACON_OVERLOAD_DEBUG_AUTO_ARM_DEFAULT
    end
    if storage.ei.beacon_overload.debug.last_heartbeat_tick == nil then
        storage.ei.beacon_overload.debug.last_heartbeat_tick = 0
    end
    if storage.ei.beacon_overload.debug.last_reason == nil then
        storage.ei.beacon_overload.debug.last_reason = nil
    end
    if storage.ei.beacon_overload.debug.last_status == nil then
        storage.ei.beacon_overload.debug.last_status = {}
    end

    -- Migrate the legacy refresh queue into the new chunked schema if an older save is loaded.
    if storage.ei.beacon_overload.refresh and type(storage.ei.beacon_overload.refresh) == "table" then
        local legacy = storage.ei.beacon_overload.refresh
        if legacy.mode ~= nil and storage.ei.beacon_overload.mode == nil then
            storage.ei.beacon_overload.mode = legacy.mode
        end
        if legacy.surfaces and (not storage.ei.beacon_overload.surface_queue.items or #storage.ei.beacon_overload.surface_queue.items == 0) then
            storage.ei.beacon_overload.surface_queue = {
                head = legacy.surface_head or 1,
                items = legacy.surfaces,
            }
            storage.ei.beacon_overload.surface_queue = ei_runtime_scheduler.ensure_queue(storage.ei.beacon_overload.surface_queue)
        end
        if legacy.chunks and (not storage.ei.beacon_overload.chunk_queue.items or #storage.ei.beacon_overload.chunk_queue.items == 0) then
            storage.ei.beacon_overload.chunk_queue = {
                head = legacy.chunk_head or 1,
                items = legacy.chunks,
            }
            storage.ei.beacon_overload.chunk_queue = ei_runtime_scheduler.ensure_queue(storage.ei.beacon_overload.chunk_queue)
        end
        if legacy.machines and (not storage.ei.beacon_overload.machine_queue.items or #storage.ei.beacon_overload.machine_queue.items == 0) then
            storage.ei.beacon_overload.machine_queue = {
                head = legacy.machine_head or 1,
                items = legacy.machines,
            }
            storage.ei.beacon_overload.machine_queue = ei_runtime_scheduler.ensure_queue(storage.ei.beacon_overload.machine_queue)
        end
        if legacy.queued_units and next(storage.ei.beacon_overload.queued_units) == nil then
            storage.ei.beacon_overload.queued_units = legacy.queued_units
        end
        storage.ei.beacon_overload.refresh = nil
    end
    if storage.ei.beacon_overload.debug.auto_arm == nil then
        storage.ei.beacon_overload.debug.auto_arm = BEACON_OVERLOAD_DEBUG_AUTO_ARM_DEFAULT
    end
    if not storage.ei.beacon_overload.compat then
        storage.ei.beacon_overload.compat = {}
    end
    if not storage.ei.beacon_overload.compat.machine_exclusions then
        storage.ei.beacon_overload.compat.machine_exclusions = {}
    end
    if not storage.ei.beacon_overload.compat.beacon_exclusions then
        storage.ei.beacon_overload.compat.beacon_exclusions = {}
    end
    if not storage.ei.beacon_overload.compat.beacon_weights then
        storage.ei.beacon_overload.compat.beacon_weights = {}
    end

    if not storage.ei["neutron_collector_animation"] then
        storage.ei["neutron_collector_animation"] = {}
    end

    if not storage.ei.neutron_runtime then
        storage.ei.neutron_runtime = {}
    end

    if not storage.ei["spawner_queue"] then
        storage.ei["spawner_queue"] = {}
    end

    if not storage.ei["orbital_combinators"] then
        storage.ei["orbital_combinators"] = {}
    end
    if storage.ei.orbital_combinators_break_point == nil then
        storage.ei.orbital_combinators_break_point = nil
    end
    if not storage.ei.orbital_combinator_banks then
        storage.ei.orbital_combinator_banks = {}
    end
    if not storage.ei.orbital_combinator_bank_by_unit then
        storage.ei.orbital_combinator_bank_by_unit = {}
    end
    if storage.ei.orbital_combinator_banks_break_point == nil then
        storage.ei.orbital_combinator_banks_break_point = nil
    end
    if storage.ei.orbital_combinator_bank_count == nil then
        storage.ei.orbital_combinator_bank_count = 0
    end
    if not storage.ei.orbital_combinator_mode_by_unit then
        storage.ei.orbital_combinator_mode_by_unit = {}
    end
    if not storage.ei.orbital_combinator_open_gui_by_player then
        storage.ei.orbital_combinator_open_gui_by_player = {}
    end
    if not storage.ei.orbital_combinator_platform_cache then
        storage.ei.orbital_combinator_platform_cache = {}
    end
    if not storage.ei.orbital_combinator_platform_by_hub then
        storage.ei.orbital_combinator_platform_by_hub = {}
    end
    if not storage.ei.orbital_combinator_snapshot_cache then
        storage.ei.orbital_combinator_snapshot_cache = {}
    end
    if not storage.ei.orbital_combinator_surface_platform_index then
        storage.ei.orbital_combinator_surface_platform_index = {}
    end
    if not storage.ei.orbital_combinator_surface_bank_index then
        storage.ei.orbital_combinator_surface_bank_index = {}
    end
    if not storage.ei.orbital_combinator_surface_state then
        storage.ei.orbital_combinator_surface_state = {}
    end
    if not storage.ei.orbital_combinator_work_service then
        storage.ei.orbital_combinator_work_service = {}
    end
    if storage.ei.orbital_combinator_hot_surface_break_point == nil then
        storage.ei.orbital_combinator_hot_surface_break_point = nil
    end
    if storage.ei.orbital_combinator_cold_surface_break_point == nil then
        storage.ei.orbital_combinator_cold_surface_break_point = nil
    end
    if storage.ei.orbital_combinator_connection_audit_break_point == nil then
        storage.ei.orbital_combinator_connection_audit_break_point = nil
    end
    storage.ei.orbital_combinator_dirty_bank_queue = ei_runtime_scheduler.ensure_queue(
        type(storage.ei.orbital_combinator_dirty_bank_queue) == "table" and storage.ei.orbital_combinator_dirty_bank_queue or nil
    )
    storage.ei.orbital_combinator_bank_audit_queue = ei_runtime_scheduler.ensure_queue(
        type(storage.ei.orbital_combinator_bank_audit_queue) == "table" and storage.ei.orbital_combinator_bank_audit_queue or nil
    )
    storage.ei.orbital_combinator_hot_surface_queue = ei_runtime_scheduler.ensure_queue(
        type(storage.ei.orbital_combinator_hot_surface_queue) == "table" and storage.ei.orbital_combinator_hot_surface_queue or nil
    )
    storage.ei.orbital_combinator_cold_surface_queue = ei_runtime_scheduler.ensure_queue(
        type(storage.ei.orbital_combinator_cold_surface_queue) == "table" and storage.ei.orbital_combinator_cold_surface_queue or nil
    )
    if not storage.ei.orbital_combinator_reconcile_state then
        storage.ei.orbital_combinator_reconcile_state = new_orbital_combinator_reconcile_state()
    end
    if storage.ei.orbital_combinator_reconcile_state.next_due_tick == nil then
        storage.ei.orbital_combinator_reconcile_state.next_due_tick = 0
    end
    if storage.ei.orbital_combinator_reconcile_state.cycle == nil then
        storage.ei.orbital_combinator_reconcile_state.cycle = 0
    end
    if storage.ei.orbital_combinator_reconcile_state.force_cursor == nil then
        storage.ei.orbital_combinator_reconcile_state.force_cursor = nil
    end
    if storage.ei.orbital_combinator_reconcile_state.platform_cursor == nil then
        storage.ei.orbital_combinator_reconcile_state.platform_cursor = nil
    end
    if storage.ei.orbital_combinator_reconcile_state.cache_cursor == nil then
        storage.ei.orbital_combinator_reconcile_state.cache_cursor = nil
    end
    if storage.ei.orbital_combinator_reconcile_state.cleanup_phase == nil then
        storage.ei.orbital_combinator_reconcile_state.cleanup_phase = false
    end
    if storage.ei.orbital_combinator_reconcile_state.in_progress == nil then
        storage.ei.orbital_combinator_reconcile_state.in_progress = false
    end
    if not storage.ei.orbital_combinator_incoming_pods then
        storage.ei.orbital_combinator_incoming_pods = {}
    end
    if not storage.ei.orbital_combinator_object_registration then
        storage.ei.orbital_combinator_object_registration = {}
    end
    if not storage.ei.orbital_combinator_surface_generations then
        storage.ei.orbital_combinator_surface_generations = new_orbital_combinator_surface_generations()
    end
    if not storage.ei.orbital_combinator_surface_generations.requests then
        storage.ei.orbital_combinator_surface_generations.requests = {}
    end
    if not storage.ei.orbital_combinator_surface_generations.on_the_way then
        storage.ei.orbital_combinator_surface_generations.on_the_way = {}
    end
    if not storage.ei.orbital_combinator_surface_generations.need then
        storage.ei.orbital_combinator_surface_generations.need = {}
    end
    if storage.ei.orbital_combinator_generation_epoch == nil then
        storage.ei.orbital_combinator_generation_epoch = 0
    end
    if storage.ei.orbital_combinator_platform_reconcile_tick == nil then
        storage.ei.orbital_combinator_platform_reconcile_tick = 0
    end
    if storage.ei.orbital_combinator_runtime_state_version == nil then
        storage.ei.orbital_combinator_runtime_state_version = 0
    end
    if storage.ei.gaia_reforged ~= nil then
        storage.ei.gaia_reforged = nil
    end
    if storage.ei.original_gaia_settings ~= nil then
        storage.ei.original_gaia_settings = nil
    end
    -- Legacy copper-beacon runtime fields, deprecated by the nonstandard-beacon path.
    --[[
    if not storage.ei.spaced_updates then
        storage.ei.spaced_updates = 0
    end
    ]]
    -- Shared fluid-safety runtime state.
    local needs_fluid_rebuild = false
    if not storage.ei.fluid_runtime or not storage.ei.fluid_runtime.entries_by_unit then
        storage.ei.fluid_runtime = new_fluid_runtime()
        needs_fluid_rebuild = true
    end
    if not storage.ei.fluid_entity then
        storage.ei.fluid_entity = {}
    end
    --int count of fluid handling entities
    if storage.ei.fluid_entity_count == nil then
        storage.ei.fluid_entity_count = 0
    end
    if ei_fluid_safety and ei_fluid_safety.ensure_fluid_runtime then
        ei_fluid_safety.ensure_fluid_runtime()
    end
    if ei_fluid_safety
    and ei_fluid_safety.rebuild_fluid_runtime
    and (needs_fluid_rebuild or storage.ei.fluid_runtime.initialized == false) then
        ei_fluid_safety.rebuild_fluid_runtime("global-check-init")
    end

    if not storage.ei.alien then
        storage.ei.alien = {}
        storage.ei.alien.state = {}
    end

    if not storage.ei.vulcanus_fumaroles then
        storage.ei.vulcanus_fumaroles = {
            -- Seed the runtime sentinel low so the fumarole module can force its current queue rebuild.
            runtime_version = 0,
            -- Seed the pre-refresh sentinel so the runtime module can force its current eligibility rebuild.
            eligibility_version = 2,
            pending_eligibility_refresh = false,
            backfill_bootstrapped = false,
            processed_chunks = {},
            history_chunks = {},
            cooldown_chunks = {},
            backfill_queue = ei_runtime_scheduler.ensure_queue(nil),
            active = {},
            active_chunk_buckets = {},
            dormant_chunks = {},
            dormant_delayed_buckets = {},
            dormant_surface_queues = {},
            dormant_surface_counts = {},
            dormant_active_surfaces = {},
            dormant_active_surface_positions = {},
            dormant_active_surface_cursor = 0,
            zero_active_since_tick = nil,
        }
    end
    if storage.ei.vulcanus_fumaroles.runtime_version == nil then
        storage.ei.vulcanus_fumaroles.runtime_version = 0
    end
    if storage.ei.vulcanus_fumaroles.eligibility_version == nil then
        storage.ei.vulcanus_fumaroles.eligibility_version = 2
    end
    if storage.ei.vulcanus_fumaroles.pending_eligibility_refresh == nil then
        storage.ei.vulcanus_fumaroles.pending_eligibility_refresh = false
    end
    storage.ei.vulcanus_fumaroles.backfill_queue = ei_runtime_scheduler.ensure_queue(
        storage.ei.vulcanus_fumaroles.backfill_queue or ei_runtime_scheduler.ensure_queue(nil)
    )

end

return ei_global
