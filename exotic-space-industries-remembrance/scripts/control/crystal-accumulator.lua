--==============================================================================
-- ESIR FILE MAP
-- owns: crystal accumulator resonance runtime, shell swaps, mining override, and UI
-- loaded_by: exotic-space-industries-remembrance\control.lua
-- cadence: scheduled surface service plus dirty UI refresh
-- forwarded_events: check_global, get_pending_work_count, on_built_entity, on_destroyed_entity, on_gui_click, on_gui_closed, on_gui_opened, on_player_alt_selected_area, on_player_left_game, on_player_mined_entity, on_repaired_entity, on_robot_mined_entity, on_selected_entity_changed, on_space_platform_changed_state, rebuild_runtime_state, service_ui, update
-- storage_roots: storage.ei.crystal_accumulator
-- gui_ids: ei-crystal-accumulator-console, ei-crystal-accumulator-console-screen, ei-crystal-accumulator-strip
-- remote_interfaces: none
-- rebuild_on: crystal shell prototype changes, resonance profile schema changes
--==============================================================================

local mod_gui = require("mod-gui")
local ei_lib = require("lib/lib")
local scheduler = require("lib/runtime-scheduler")
local ei_surface_anchor = require("lib/surface-anchor")

local model = {}

-- Runtime shape, in one breath:
--   live crystal shells are tracked by visible entity unit number;
--   surfaces, not individual machines, are scheduled for periodic service;
--   each surface service pass builds one shared context and applies it to every
--   accumulator on that surface; and player UI refreshes are separately delayed
--   so GUI churn never becomes coupled to the machine cadence.
--
-- The module deliberately owns both the "physics" and the UI. Crystal
-- accumulator behavior is not just a power interface: shell swaps, husk breaks,
-- mining replacement, custom status, inspection output, and detached readouts
-- all need to agree on the same instability snapshot.
--
-- Reader's guide:
--   1. Constants and profile tables define the public behavior.
--   2. Storage and scheduler helpers keep the runtime cheap and save-safe.
--   3. Shell lifecycle helpers own entity replacement, mining, and repair.
--   4. Telemetry helpers translate EEI/network state into a load proxy.
--   5. process_record() is the single simulation step for one live crystal.
--   6. Snapshot and GUI helpers render state without mutating simulation.
--   7. model.* functions are the only surface control.lua should call.
--
-- The most important invariant: the visible entity's unit_number is the live
-- record key. Shell swaps necessarily change unit_number because Factorio cannot
-- mutate an entity prototype in place; every swap must therefore unregister the
-- old unit, register the new one, then repair all player/watch/UI references.
local MODULE_NAME = "crystal_accumulator"
local BASE_NAME = "ei-crystal-accumulator"
local LOW_NAME = "ei-crystal-accumulator-low"
local SURGED_NAME = "ei-crystal-accumulator-surged"
local GAIA_NAME = "ei-crystal-accumulator-gaia"
local REPAIR_TOOL_NAME = "ei-crystal-accumulator-repair"
local SERVICE_INTERVAL_TICKS = 300
local UI_REFRESH_INTERVAL_TICKS = 30
local STATUS_UPDATE_INTERVAL_TICKS = 60
local INSPECT_PRINT_LIMIT = 8
local DEFAULT_BUFFER_CAPACITY = 1000000000
local FRONTIER_COMPACT_THRESHOLD = 32
local SURFACE_AGGREGATE_SCHEMA = 4
local STRIP_NAME = "ei-crystal-accumulator-strip"
local RELATIVE_GUI_NAME = "ei-crystal-accumulator-console"
local SCREEN_GUI_NAME = "ei-crystal-accumulator-console-screen"
local INFORMATRON_PAGE = "crystal_accumulator_resonance"

-- These cadence constants are deliberately conservative. Simulation runs in
-- coarse 5-second surface passes because instability is strategic flavor, not a
-- per-tick power controller. UI refreshes may run faster, but only for players
-- who are actively selecting/opening/viewing a crystal readout.

-- "Live" means the entity is still an operating accumulator shell and must be
-- sampled, scheduled, and allowed to swap into a different shell variant.
-- "Husk" means the shell has already failed; it remains relevant for mining,
-- repair, inspection, and UI, but no longer contributes to resonance load.
local LIVE_NAMES = {
    [BASE_NAME] = true,
    [LOW_NAME] = true,
    [SURGED_NAME] = true,
    [GAIA_NAME] = true,
}

local LIVE_NAME_LIST = {
    BASE_NAME,
    LOW_NAME,
    SURGED_NAME,
    GAIA_NAME,
}

local HUSK_NAME_LIST = {
    "ei-crystal-accumulator_off-1",
    "ei-crystal-accumulator_off-2",
    "ei-crystal-accumulator_off-3",
    "ei-crystal-accumulator_off-4",
}

local HUSK_NAMES = {}
for _, husk_name in ipairs(HUSK_NAME_LIST) do
    HUSK_NAMES[husk_name] = true
end

local ALL_RELEVANT_NAMES = {}
for name in pairs(LIVE_NAMES) do
    ALL_RELEVANT_NAMES[name] = true
end
for name in pairs(HUSK_NAMES) do
    ALL_RELEVANT_NAMES[name] = true
end

local SHELL_OUTPUT_WATTS = {
    [BASE_NAME] = 7500000,
    [LOW_NAME] = 4000000,
    [SURGED_NAME] = 10000000,
    [GAIA_NAME] = 15000000,
}

local SHELL_KEYS = {
    [BASE_NAME] = "base",
    [LOW_NAME] = "low",
    [SURGED_NAME] = "surged",
    [GAIA_NAME] = "gaia",
}

-- Load bands are intentionally coarse. The actual load signal can come from
-- electric statistics or from local buffer strain, but downstream behavior only
-- needs a stable band: recovery, normal work, stress, and catastrophic pressure.
local LOAD_BANDS = {
    {key = "idle", min = 0, max = 0.15, delta = -8},
    {key = "light", min = 0.15, max = 0.50, delta = -3},
    {key = "working", min = 0.50, max = 0.90, delta = 2},
    {key = "strained", min = 0.90, max = 1.05, delta = 8},
    {key = "overdrive", min = 1.05, max = math.huge, delta = 14},
}

local STATUS_GREEN = defines.entity_status_diode and defines.entity_status_diode.green or 1
local STATUS_YELLOW = defines.entity_status_diode and defines.entity_status_diode.yellow or 2
local STATUS_RED = defines.entity_status_diode and defines.entity_status_diode.red or 3

local CROWDING_STATES = {
    free = {delta = 0},
    crowded = {delta = 2},
    strained = {delta = 5},
    chaotic = {delta = 9},
}

-- Surface profiles are the module's planet grammar. They define how many
-- resonant shells a surface tolerates, how strongly work becomes instability,
-- how quickly idle machines recover, which shell the surface prefers, and what
-- kind of backlash happens when an unstable crystal crosses the threshold.
--
-- These values are deliberately read as policy rather than simulation state:
-- runtime code should consult this table instead of scattering planet-specific
-- constants through the processing path.
local PROFILE_DEFS = {
    nauvis = {
        thresholds = {2, 4, 6},
        load_multiplier = 0.85,
        recovery_multiplier = 1.15,
        shell_bias = "base",
        backlash = "nauvis",
    },
    gaia = {
        thresholds = {math.huge, math.huge, math.huge},
        load_multiplier = 0,
        recovery_multiplier = 1,
        shell_bias = "gaia",
        backlash = "none",
    },
    fulgora = {
        thresholds = {2, 3, 4},
        load_multiplier = 1.15,
        recovery_multiplier = 1.00,
        shell_bias = "cycle",
        backlash = "fulgora",
    },
    vulcanus = {
        thresholds = {2, 3, 4},
        load_multiplier = 1.25,
        recovery_multiplier = 1.00,
        shell_bias = "surged",
        backlash = "vulcanus",
    },
    gleba = {
        thresholds = {2, 3, 4},
        load_multiplier = 1.00,
        recovery_multiplier = 1.35,
        shell_bias = "base",
        backlash = "gleba",
    },
    aquilo = {
        thresholds = {2, 4, 5},
        load_multiplier = 0.75,
        recovery_multiplier = 1.10,
        shell_bias = "low",
        backlash = "aquilo",
    },
    orbit = {
        thresholds = {2, 4, 5},
        load_multiplier = 1.00,
        recovery_multiplier = 1.00,
        shell_bias = "base",
        backlash = "generic",
    },
    generic = {
        thresholds = {2, 4, 5},
        load_multiplier = 1.00,
        recovery_multiplier = 1.00,
        shell_bias = "base",
        backlash = "generic",
    },
}

local function now_tick(event_or_tick)
    return ei_lib.get_event_tick(event_or_tick)
end

local function entity_check(entity)
    return ei_lib.entity_check(entity)
end

local function get_unit_number(entity)
    return ei_lib.get_entity_unit_number(entity)
end

local function is_live_entity(entity)
    return entity_check(entity) and LIVE_NAMES[entity.name] == true
end

local function is_relevant_entity(entity)
    return entity_check(entity) and ALL_RELEVANT_NAMES[entity.name] == true
end

local function get_quality_name(item_like)
    return ei_lib.get_quality_name(item_like, nil)
end

local function make_item_stack(name, quality_name, count)
    local stack = {name = name, count = count or 1}
    if quality_name then
        stack.quality = quality_name
    end
    return stack
end

local function is_gaia_surface(surface)
    if not (surface and surface.valid) then
        return false
    end

    if storage and storage.gaia_surfaces and storage.gaia_surfaces[surface.name] == true then
        return true
    end

    return surface.name == "gaia" or surface.name == "Gaia"
end

local function shallow_count(tbl)
    return scheduler.table_count(tbl or {})
end

local function get_nominal_output_per_tick(entity_name)
    return (SHELL_OUTPUT_WATTS[entity_name] or SHELL_OUTPUT_WATTS[BASE_NAME]) / 60
end

local function get_shell_key(entity_name)
    return SHELL_KEYS[entity_name] or "offline"
end

local function get_output_mw_text(entity_name)
    local output_mw = (SHELL_OUTPUT_WATTS[entity_name] or 0) / 1000000
    if math.abs(output_mw - math.floor(output_mw)) < 0.001 then
        return tostring(math.floor(output_mw))
    end

    return string.format("%.1f", output_mw)
end

local function get_surface_cohort_key(entity_name, quality_name)
    -- Cohorts are intentionally shell + quality, not individual entities. The
    -- electric statistics API reports aggregate flow by prototype/quality, so
    -- every crystal in that cohort shares the same network output term; local
    -- buffer strain is layered later to distinguish one depleted shell from a
    -- sibling on the same grid.
    return table.concat({
        tostring(entity_name or ""),
        tostring(quality_name or "normal"),
    }, "|")
end

local function get_network_cohort_key(network_id, entity_name, quality_name)
    -- Local electric networks can coexist on one surface. Prefixing the cohort
    -- with electric_network_id keeps isolated grids from averaging into each
    -- other, while still allowing same-shell same-quality crystals on the same
    -- grid to share the statistics-backed load estimate.
    return table.concat({
        tostring(network_id or "none"),
        tostring(entity_name or ""),
        tostring(quality_name or "normal"),
    }, "|")
end

local function get_electric_network_id(entity)
    if not entity_check(entity) then
        return nil
    end

    -- Some entities do not expose electric_network_id even when they participate
    -- in energy logic. Treat that as "no network telemetry" instead of letting a
    -- stale or unsupported LuaEntity crash the whole tick.
    local ok, network_id = pcall(function()
        return entity.electric_network_id
    end)
    if not ok then
        return nil
    end

    return network_id
end

local function make_stats_flow_id(entity_name, quality_name)
    -- FlowStatistics accepts either a bare prototype name or the quality-aware
    -- `{name=..., quality=...}` form. Normal quality uses the bare string because
    -- it is the most compatible representation across old saves and vanilla
    -- statistics windows.
    if quality_name and quality_name ~= "normal" then
        return {
            name = entity_name,
            quality = quality_name,
        }
    end

    return entity_name
end

-- Space-platform surfaces do not have a fixed planetary context while the
-- platform is flying. Transit adds instability later, but only when the platform
-- is actually between endpoints; docked orbit surfaces use the regular orbit
-- profile without that moving-threshold pressure.
local function is_surface_in_transit(surface)
    if not (surface and surface.valid and surface.platform and surface.platform.valid) then
        return false
    end

    local platform = surface.platform
    local connection = platform.space_connection
    local route_length = connection and connection.valid and tonumber(connection.length) or 0
    local route_distance = tonumber(platform.distance) or 0
    return route_length > 0 and route_distance > 0 and route_distance < route_length
end

local function calculate_crowding_percent(total_weight, thresholds)
    local limit = thresholds and thresholds[3] or 0
    if not limit or limit <= 0 or limit == math.huge then
        return 0
    end

    return math.floor(ei_lib.clamp(total_weight / limit, 0, 1) * 100 + 0.5)
end

local function get_resonance_weight(quality_factor)
    return 1 - (0.35 * ei_lib.clamp(tonumber(quality_factor) or 0, 0, 1))
end

-- Instability is the single stored health meter for the resonance system. UI,
-- shell choice, mining result, backlash, and final breakage all derive from it,
-- with "frozen" acting as an Aquilo-specific overlay state.
local function get_state_key(instability, frozen)
    if frozen then
        return "frozen"
    end

    if instability >= 75 then
        return "fracturing"
    end
    if instability >= 50 then
        return "volatile"
    end
    if instability >= 25 then
        return "strained"
    end

    return "calm"
end

local function get_status_diode(state_key, repair_mode)
    if repair_mode then
        return STATUS_RED
    end

    if state_key == "calm" then
        return STATUS_GREEN
    end
    if state_key == "strained" or state_key == "frozen" then
        return STATUS_YELLOW
    end

    return STATUS_RED
end

-- Factorio's custom_status is the tiny status line shown on the entity itself.
-- Keep this function snapshot-driven: it should not recompute module state, only
-- translate the already-built snapshot into the diode and localised caption.
local function set_entity_custom_status(entity, snapshot)
    if not (entity_check(entity) and snapshot) then
        return
    end

    -- This line is what appears in the vanilla tooltip/status area, separate
    -- from the custom relative/screen readout. Keep it short: the detailed panel
    -- owns explanation, while custom_status should answer "what state is this in
    -- right now?" without widening the entity tooltip into a second GUI.
    local diode = get_status_diode(snapshot.state_key, snapshot.result_mode == "repair")
    if snapshot.result_mode == "repair" then
        entity.custom_status = {
            diode = diode,
            label = {
                "",
                {"exotic-industries.crystal-accumulator-shell-offline"},
                " | ",
                {"exotic-industries.crystal-accumulator-profile-" .. snapshot.profile_key},
                " | ",
                {"exotic-industries.crystal-accumulator-repair-" .. snapshot.result_key},
            },
        }
        return
    end

    entity.custom_status = {
        diode = diode,
        label = {
            "exotic-industries.crystal-accumulator-strip",
            {"exotic-industries.crystal-accumulator-state-" .. snapshot.state_key},
            {"exotic-industries.crystal-accumulator-profile-" .. snapshot.profile_key},
            snapshot.coherence,
            {"exotic-industries.crystal-accumulator-load-" .. snapshot.load_band},
        },
    }
end

local function get_husk_name(instability, broken)
    if broken or instability >= 100 then
        return HUSK_NAME_LIST[4]
    end
    if instability >= 75 then
        return HUSK_NAME_LIST[3]
    end
    if instability >= 50 then
        return HUSK_NAME_LIST[2]
    end
    return HUSK_NAME_LIST[1]
end

-- Shell swaps destroy and recreate the visible entity. Circuit wires are not
-- preserved by that operation automatically, so we capture real wire connector
-- edges before destroy and rebuild them on the new shell afterward.
local function get_real_circuit_connections(entity)
    if not entity_check(entity) then
        return {}
    end

    -- Factorio stores circuit connections on wire connectors, not on the entity
    -- prototype. Shell swaps are destroy/create operations, so without this
    -- capture/restore pair a stressed crystal would silently sever player wiring
    -- whenever it changed output rung.
    local saved_connections = {}
    local ok, connectors = pcall(entity.get_wire_connectors, entity, false)
    if not ok or type(connectors) ~= "table" then
        return saved_connections
    end

    for connector_id, connector in pairs(connectors) do
        if connector and connector.valid then
            for _, connection in ipairs(connector.real_connections or {}) do
                if connection.target and connection.target.valid then
                    saved_connections[#saved_connections + 1] = {
                        source_id = connector_id,
                        target = connection.target,
                        origin = connection.origin,
                    }
                end
            end
        end
    end

    return saved_connections
end

local function restore_circuit_connections(entity, saved_connections)
    if not entity_check(entity) then
        return
    end

    -- Restore best-effort only. The opposite endpoint may have been mined,
    -- invalidated, or belong to a connector no longer available on the swapped
    -- shell; failed reconnects are ignored so shell replacement stays atomic.
    for _, connection in ipairs(saved_connections or {}) do
        local source = entity.get_wire_connector(connection.source_id, true)
        if source and source.valid and connection.target and connection.target.valid then
            source.connect_to(connection.target, false, connection.origin)
        end
    end
end

-- Storage layout:
--   by_unit:
--     Canonical entity records keyed by the currently live shell unit number.
--   units_by_surface:
--     Surface membership index. Periodic work is scheduled per surface and then
--     expands into these unit numbers only when that surface becomes due.
--   surface_aggregate_by_surface:
--     Cheap aggregate counts/weights used to compute crowding and telemetry
--     without scanning every entity for every single machine.
--   surface_due_buckets + frontier:
--     Delayed-bucket scheduler from runtime-scheduler plus a sorted frontier so
--     update() can early-return until the next due tick.
--   ui_due_buckets + frontier:
--     Separate GUI scheduler. UI cadence can be fast and player-local while
--     machine simulation stays slow and surface-scoped.
--   watch/open/screen maps:
--     Cross indexes for the three player-facing surfaces: selected/opened entity,
--     relative entity panel, and detachable screen readout.
--   pending_mining_*:
--     Pre-mine snapshots. Factorio gives the replacement buffer after the entity
--     is already being removed, so live-vs-husk mining result must be captured
--     during the pre-mined event and consumed during the mined event.
--   scratch_*:
--     Reused arrays for hot paths. They keep periodic surface service from
--     allocating fresh transient tables every cycle.
local function build_runtime()
    return {
        -- Canonical simulation records. Values can carry stale LuaEntity handles
        -- after mining/swap/load; every later dereference must revalidate.
        by_unit = {},

        -- Summary counters are convenience/status values only. If they disagree
        -- with the indexes, rebuild_runtime_state() and schema repair rebuild
        -- them from live records rather than trusting serialized numbers.
        live_crystal_count = 0,
        units_by_surface = {},
        active_surface_count = 0,
        surface_aggregate_by_surface = {},
        surface_aggregate_schema = SURFACE_AGGREGATE_SCHEMA,

        -- Simulation cadence: delayed buckets remember when a surface should wake;
        -- the ready queue holds surfaces that control.lua may process this tick.
        surface_queue = scheduler.ensure_queue(),
        surface_queue_count = 0,
        surface_due_buckets = scheduler.ensure_delayed_buckets(),
        due_surface_count = 0,
        last_due_activation_tick = 0,
        next_surface_due_tick = 0,
        surface_due_frontier_ticks = {},
        surface_due_frontier_head = 1,
        surface_due_frontier_present = {},
        surface_due_tick_by_surface = {},
        surface_state_by_surface = {},

        -- GUI cadence: same delayed-bucket/frontier idea, but player-indexed and
        -- faster. UI wakeups must not force simulation work.
        ui_due_buckets = scheduler.ensure_delayed_buckets(),
        next_ui_due_tick = 0,
        ui_due_frontier_ticks = {},
        ui_due_frontier_head = 1,
        ui_due_frontier_present = {},
        ui_pending_by_player = {},
        ui_next_allowed_tick = {},
        ui_render_signature_by_player = {},

        -- Detached screen preferences are per player and per watched unit. This
        -- prevents the module from reopening a panel a player just dismissed.
        screen_dismissed_by_player = {},
        screen_requested_by_player = {},
        screen_entity_by_player = {},

        -- Watch maps are reverse indexes only. They are used to wake viewers; the
        -- entity record and selected/opened GUI state remain the source of truth.
        watch_by_player = {},
        watched_player_count = 0,
        watchers_by_surface = {},
        watchers_by_unit = {},
        open_by_player = {},

        -- Mining buffers are only mutable after the mined event. These snapshots
        -- carry the pre-mine decision across Factorio's two-stage mining flow.
        pending_mining_by_unit = {},
        pending_mining_by_player = {},
        pending_mining_by_robot = {},

        -- Anchor and scratch storage are performance helpers. They are always
        -- derivable and should never encode player-facing irreversible state.
        anchor_cache = nil,
        last_status_tick = 0,
        scratch_unit_numbers = {},
        scratch_stale_units = {},
        scratch_player_indexes = {},
        scratch_due_ticks = {},
        scratch_dirty_unit_numbers = {},
    }
end

-- Surface aggregates are a lossy but intentional view of the live population:
-- total resonance weight for crowding, per-shell cohorts for global electric
-- statistics, and per-network cohorts for local electric statistics. The
-- individual record remains canonical for instability and shell state.
local function make_surface_aggregate()
    return {
        -- total_weight is quality-adjusted and drives resonance crowding.
        total_weight = 0,

        -- active_count is literal live shell count. It is shown in UI and used as
        -- a sanity signal, but crowding logic uses total_weight.
        active_count = 0,

        -- Surface cohorts support global electric-network statistics. They are
        -- shell+quality buckets because FlowStatistics cannot report per entity.
        cohort_counts = {},

        -- Network cohorts are the more precise form for normal planet grids:
        -- network_id -> shell+quality buckets plus a representative entity/pole.
        network_cohort_counts = {},

        -- Incremental add/remove paths cannot cheaply maintain network cohorts
        -- because electric_network_id can change when poles are built or removed.
        -- Mark false and rebuild from units_by_surface before telemetry reads.
        network_index_ready = false,
    }
end

local function add_record_to_aggregate(aggregate, record, entity)
    -- Re-index from the entity every time. Records survive shell swaps and save
    -- migrations, while entity.name, quality, and surface membership may have
    -- changed underneath them.
    local quality_factor = record.quality_factor
    if quality_factor == nil then
        quality_factor = ei_lib.get_normalized_quality_factor(entity)
        record.quality_factor = quality_factor
    end

    record.entity_name = entity.name
    record.quality_name = get_quality_name(entity)
    record.resonance_weight = get_resonance_weight(quality_factor)
    record.surface_index = entity.surface.index

    aggregate.total_weight = aggregate.total_weight + record.resonance_weight
    aggregate.active_count = aggregate.active_count + 1

    -- First build the surface-wide cohort. This is the fallback for global grids
    -- and for old cases where network_id cannot be recovered.
    local cohort_key = get_surface_cohort_key(record.entity_name, record.quality_name)
    local cohort_entry = aggregate.cohort_counts[cohort_key]
    if not cohort_entry then
        cohort_entry = {
            count = 0,
            entity_name = record.entity_name,
            quality_name = record.quality_name,
        }
        aggregate.cohort_counts[cohort_key] = cohort_entry
    end
    cohort_entry.count = cohort_entry.count + 1

    -- Then build the per-electric-network cohort when Factorio exposes a network
    -- id. The representative entity is only a lookup anchor for statistics; it is
    -- not a unique owner of the cohort's flow.
    local network_id = get_electric_network_id(entity)
    if network_id then
        local network_key = tostring(network_id)
        local network_entry = aggregate.network_cohort_counts[network_key]
        if not network_entry then
            network_entry = {
                network_id = network_id,
                representative_entity = entity,
                cohort_counts = {},
            }
            aggregate.network_cohort_counts[network_key] = network_entry
        end
        network_entry.representative_entity = network_entry.representative_entity or entity

        local network_cohort = network_entry.cohort_counts[cohort_key]
        if not network_cohort then
            network_cohort = {
                count = 0,
                entity_name = record.entity_name,
                quality_name = record.quality_name,
            }
            network_entry.cohort_counts[cohort_key] = network_cohort
        end
        network_cohort.count = network_cohort.count + 1
    end
end

-- Rebuild only one surface's aggregate. This is used as a repair path when a
-- cached context becomes suspect or a surface service pass notices stale unit
-- membership. It cleans dead records as it goes, but it does not scan the whole
-- game world.
local function rebuild_surface_aggregate(runtime, surface_index)
    if not (runtime and surface_index) then
        return nil
    end

    runtime.surface_aggregate_by_surface = runtime.surface_aggregate_by_surface or {}
    runtime.surface_state_by_surface = runtime.surface_state_by_surface or {}
    local surface_units = runtime.units_by_surface and runtime.units_by_surface[surface_index] or nil
    if not surface_units then
        runtime.surface_aggregate_by_surface[surface_index] = nil
        runtime.surface_state_by_surface[surface_index] = nil
        return nil
    end

    local aggregate = make_surface_aggregate()
    local stale_units = runtime.scratch_stale_units or {}
    runtime.scratch_stale_units = stale_units
    for i = #stale_units, 1, -1 do
        stale_units[i] = nil
    end

    for unit_number in pairs(surface_units) do
        local record = runtime.by_unit and runtime.by_unit[unit_number] or nil
        local entity = record and ei_lib.get_valid_entity(record.entity) or nil
        if entity and is_live_entity(entity) and entity.surface.index == surface_index then
            add_record_to_aggregate(aggregate, record, entity)
        else
            -- Do not mutate the table while iterating it. Collect stale entries
            -- first, then remove them in a second pass.
            stale_units[#stale_units + 1] = unit_number
        end
    end

    for _, unit_number in ipairs(stale_units) do
        surface_units[unit_number] = nil
        if runtime.by_unit and runtime.by_unit[unit_number] then
            -- If the record still existed, this repair path is effectively an
            -- unregister. Keep counters from drifting upward forever.
            runtime.by_unit[unit_number] = nil
            runtime.live_crystal_count = math.max(0, (tonumber(runtime.live_crystal_count) or 0) - 1)
        end
    end

    if aggregate.active_count <= 0 then
        -- A surface with no live shells should be invisible to the scheduler.
        -- Stale delayed-bucket entries may still exist, but activation checks the
        -- authoritative maps before pushing ready work.
        runtime.units_by_surface[surface_index] = nil
        runtime.active_surface_count = math.max(0, (tonumber(runtime.active_surface_count) or 0) - 1)
        runtime.surface_aggregate_by_surface[surface_index] = nil
        runtime.surface_state_by_surface[surface_index] = nil
        return nil
    end

    aggregate.network_index_ready = true
    runtime.surface_aggregate_by_surface[surface_index] = aggregate
    -- Any cached context based on the old aggregate is now suspect. Rebuild it on
    -- demand so telemetry/crowding/UI all see the same repaired surface view.
    runtime.surface_state_by_surface[surface_index] = nil
    return aggregate
end

-- Full aggregate rebuild is reserved for storage/schema repair. Normal runtime
-- adds and removes membership incrementally through add_surface_unit() and
-- remove_surface_unit(); this function is the "trust but re-index" pass for
-- configuration change and old saves.
local function rebuild_surface_aggregates(runtime)
    local previous_by_unit = runtime.by_unit or {}
    local new_by_unit = {}
    local units_by_surface = {}
    local aggregates = {}
    local live_count = 0
    local active_surface_count = 0

    for unit_number, record in pairs(previous_by_unit) do
        local entity = record and ei_lib.get_valid_entity(record.entity) or nil
        if entity and is_live_entity(entity) then
            -- Preserve the record table itself. This keeps instability, frozen
            -- state, last-load band, and carried quality data intact while all
            -- indexes around it are rebuilt.
            local surface_index = entity.surface.index
            local surface_units = units_by_surface[surface_index]
            if not surface_units then
                surface_units = {}
                units_by_surface[surface_index] = surface_units
                active_surface_count = active_surface_count + 1
            end
            surface_units[unit_number] = true

            local aggregate = aggregates[surface_index]
            if not aggregate then
                aggregate = make_surface_aggregate()
                aggregates[surface_index] = aggregate
            end
            add_record_to_aggregate(aggregate, record, entity)
            new_by_unit[unit_number] = record
            live_count = live_count + 1
        end
    end

    runtime.by_unit = new_by_unit
    runtime.units_by_surface = units_by_surface
    runtime.live_crystal_count = live_count
    runtime.active_surface_count = active_surface_count
    for _, aggregate in pairs(aggregates) do
        aggregate.network_index_ready = true
    end
    runtime.surface_aggregate_by_surface = aggregates
    runtime.surface_state_by_surface = {}
    -- Bumping this schema is the escape hatch for index bugs found after release.
    -- Old saves automatically re-enter this full re-index path the first time
    -- get_runtime() is called.
    runtime.surface_aggregate_schema = SURFACE_AGGREGATE_SCHEMA
end

-- get_runtime() is intentionally defensive. Saves may contain older versions of
-- this storage table, half-populated scheduler structures, or counters that were
-- introduced after the save was made. Normalize all of that here so the rest of
-- the file can treat runtime as shaped.
local function get_runtime()
    storage.ei = storage.ei or {}
    storage.ei.crystal_accumulator = storage.ei.crystal_accumulator or build_runtime()

    local runtime = storage.ei.crystal_accumulator
    -- Every field below is normalized because Factorio saves can cross multiple
    -- development versions. Treat missing fields as "old save shape", not as an
    -- error. This keeps migrations local to the module instead of requiring a
    -- dedicated migration file for every scheduler/UI scratch addition.
    runtime.by_unit = runtime.by_unit or {}
    runtime.live_crystal_count = math.max(0, tonumber(runtime.live_crystal_count) or shallow_count(runtime.by_unit))
    runtime.units_by_surface = runtime.units_by_surface or {}
    runtime.active_surface_count = math.max(0, tonumber(runtime.active_surface_count) or shallow_count(runtime.units_by_surface))
    runtime.surface_aggregate_by_surface = runtime.surface_aggregate_by_surface or {}
    runtime.surface_aggregate_schema = tonumber(runtime.surface_aggregate_schema) or 0
    if runtime.surface_aggregate_schema < SURFACE_AGGREGATE_SCHEMA then
        -- A schema bump means "derived indexes are no longer trustworthy". The
        -- records are still kept, but surface membership, cohorts, counters, and
        -- cached contexts are rebuilt from live entities.
        rebuild_surface_aggregates(runtime)
    end
    runtime.surface_queue = scheduler.ensure_queue(runtime.surface_queue)
    runtime.surface_queue_count = math.max(0, tonumber(runtime.surface_queue_count) or scheduler.queue_item_count(runtime.surface_queue))
    runtime.surface_due_buckets = scheduler.ensure_delayed_buckets(runtime.surface_due_buckets)
    runtime.last_due_activation_tick = tonumber(runtime.last_due_activation_tick) or 0
    runtime.next_surface_due_tick = tonumber(runtime.next_surface_due_tick) or 0
    runtime.surface_due_frontier_ticks = runtime.surface_due_frontier_ticks or {}
    runtime.surface_due_frontier_head = math.max(1, tonumber(runtime.surface_due_frontier_head) or 1)
    runtime.surface_due_frontier_present = runtime.surface_due_frontier_present or {}
    runtime.surface_due_tick_by_surface = runtime.surface_due_tick_by_surface or {}
    runtime.due_surface_count = math.max(0, tonumber(runtime.due_surface_count) or shallow_count(runtime.surface_due_tick_by_surface))
    runtime.surface_state_by_surface = runtime.surface_state_by_surface or {}
    runtime.ui_due_buckets = scheduler.ensure_delayed_buckets(runtime.ui_due_buckets)
    runtime.next_ui_due_tick = tonumber(runtime.next_ui_due_tick) or 0
    runtime.ui_due_frontier_ticks = runtime.ui_due_frontier_ticks or {}
    runtime.ui_due_frontier_head = math.max(1, tonumber(runtime.ui_due_frontier_head) or 1)
    runtime.ui_due_frontier_present = runtime.ui_due_frontier_present or {}
    runtime.ui_pending_by_player = runtime.ui_pending_by_player or {}
    runtime.ui_next_allowed_tick = runtime.ui_next_allowed_tick or {}
    runtime.ui_render_signature_by_player = runtime.ui_render_signature_by_player or {}
    runtime.screen_dismissed_by_player = runtime.screen_dismissed_by_player or {}
    runtime.screen_requested_by_player = runtime.screen_requested_by_player or {}
    runtime.screen_entity_by_player = runtime.screen_entity_by_player or {}
    runtime.watch_by_player = runtime.watch_by_player or {}
    runtime.watched_player_count = math.max(0, tonumber(runtime.watched_player_count) or shallow_count(runtime.watch_by_player))
    runtime.watchers_by_surface = runtime.watchers_by_surface or {}
    runtime.watchers_by_unit = runtime.watchers_by_unit or {}
    runtime.open_by_player = runtime.open_by_player or {}
    runtime.pending_mining_by_unit = runtime.pending_mining_by_unit or {}
    runtime.pending_mining_by_player = runtime.pending_mining_by_player or {}
    runtime.pending_mining_by_robot = runtime.pending_mining_by_robot or {}
    runtime.last_status_tick = tonumber(runtime.last_status_tick) or 0
    runtime.scratch_unit_numbers = runtime.scratch_unit_numbers or {}
    runtime.scratch_stale_units = runtime.scratch_stale_units or {}
    runtime.scratch_player_indexes = runtime.scratch_player_indexes or {}
    runtime.scratch_due_ticks = runtime.scratch_due_ticks or {}
    runtime.scratch_dirty_unit_numbers = runtime.scratch_dirty_unit_numbers or {}

    return runtime
end

local function get_next_ui_due_tick()
    local raw_runtime = storage and storage.ei and storage.ei.crystal_accumulator or nil
    return math.max(0, tonumber(raw_runtime and raw_runtime.next_ui_due_tick) or 0)
end

local function clear_scratch_array(array)
    for index = #array, 1, -1 do
        array[index] = nil
    end
    return array
end

local function get_surface_queue_count(runtime)
    if not runtime then
        return 0
    end

    runtime.surface_queue_count = math.max(
        0,
        tonumber(runtime.surface_queue_count) or scheduler.queue_item_count(runtime.surface_queue)
    )
    return runtime.surface_queue_count
end

local function ensure_anchor_cache(runtime)
    runtime.anchor_cache = ei_surface_anchor.ensure_distance_cache(
        runtime.anchor_cache,
        prototypes and prototypes.space_location
    )
    return runtime.anchor_cache
end

-- Profiles are chosen from the concrete surface first, with Gaia as an overlay
-- from the ESIR Gaia runtime. Platforms are handled before name matching because
-- a platform surface can be orbiting any destination but still needs orbit
-- behavior while it is a mobile vessel.
local function get_surface_profile(surface)
    if not (surface and surface.valid) then
        return "generic", PROFILE_DEFS.generic
    end

    if is_gaia_surface(surface) then
        return "gaia", PROFILE_DEFS.gaia
    end

    if surface.platform and surface.platform.valid then
        return "orbit", PROFILE_DEFS.orbit
    end

    local reference_name = nil
    if surface.planet and surface.planet.valid then
        reference_name = string.lower(surface.planet.name)
    else
        reference_name = string.lower(surface.name)
    end

    if string.find(reference_name, "nauvis", 1, true) then
        return "nauvis", PROFILE_DEFS.nauvis
    end
    if string.find(reference_name, "fulgora", 1, true) then
        return "fulgora", PROFILE_DEFS.fulgora
    end
    if string.find(reference_name, "vulcanus", 1, true) then
        return "vulcanus", PROFILE_DEFS.vulcanus
    end
    if string.find(reference_name, "gleba", 1, true) then
        return "gleba", PROFILE_DEFS.gleba
    end
    if string.find(reference_name, "aquilo", 1, true) then
        return "aquilo", PROFILE_DEFS.aquilo
    end

    return "generic", PROFILE_DEFS.generic
end

-- The surface anchor is a cheap "cosmic field" coordinate. It provides orbit and
-- platform instability flavor without needing per-tick worldgen or map scans:
-- resolve once through the shared anchor cache, then derive field pressure from
-- the anchor's position in the known space-location layout.
local function resolve_anchor_snapshot(runtime, surface)
    local cache = ensure_anchor_cache(runtime)
    local anchor = ei_surface_anchor.get_surface_anchor(surface, cache, prototypes and prototypes.space_location)
    if not anchor then
        return {
            field = 0,
            extra_instability = 0,
            label = surface and (surface.localised_name or surface.name) or {"exotic-industries.crystal-accumulator-profile-generic"},
        }
    end

    local x = tonumber(anchor.x) or 0
    local y = tonumber(anchor.y) or 0
    local radial_distance = math.sqrt((x * x) + (y * y))
    local max_pair_distance = math.max(1, tonumber(cache.max_pair_distance) or 1)
    local radial = ei_lib.clamp(radial_distance / max_pair_distance, 0, 1)
    local harmonic = ei_lib.clamp(0.5 + 0.25 * math.sin(x * 0.35) + 0.25 * math.cos(y * 0.27), 0, 1)
    local field = ei_lib.clamp((0.6 * radial) + (0.4 * harmonic), 0, 1)
    local field_scale = surface and surface.platform and surface.platform.valid and 8 or 4

    return {
        field = field,
        extra_instability = math.floor((field_scale * field) + 0.5),
        label = anchor.label or anchor.location_name or surface.name,
    }
end

local rebuild_ui_due_frontier
local compact_ui_due_frontier
local advance_ui_due_frontier
local insert_ui_due_frontier_tick

-- UI work is queued by player, not by entity. A single player can bounce between
-- selected entities, opened windows, a detached screen, and the mod-gui strip.
-- The pending tick map collapses repeated refresh requests so one noisy surface
-- event cannot enqueue the same player dozens of times.
local function queue_ui_refresh(runtime, player_index, current_tick)
    if not player_index then
        return
    end

    -- Debounce per player, not per triggering event. Selection, open, close,
    -- shell swaps, and surface transitions may all queue the same player in one
    -- short window; the earliest pending tick wins.
    local next_allowed = runtime.ui_next_allowed_tick[player_index] or current_tick
    local due_tick = math.max(current_tick + 1, next_allowed)
    local pending_tick = runtime.ui_pending_by_player[player_index]
    if pending_tick and pending_tick <= due_tick then
        return
    end

    runtime.ui_pending_by_player[player_index] = due_tick
    local bucket_exists = runtime.ui_due_buckets[due_tick] ~= nil
    scheduler.delayed_schedule(runtime.ui_due_buckets, due_tick, player_index)
    -- The delayed bucket owns the actual due list. The frontier only exists so
    -- service_ui() can ask "what is the next due tick?" cheaply.
    if not bucket_exists then
        insert_ui_due_frontier_tick(runtime, due_tick)
    elseif runtime.next_ui_due_tick == 0 then
        advance_ui_due_frontier(runtime)
    end
end

local function recalculate_next_ui_due_tick(runtime)
    return advance_ui_due_frontier(runtime)
end

-- The frontier tables are a small sorted index over runtime-scheduler delayed
-- buckets. Delayed buckets hold the real work, while the frontier gives
-- service_ui()/update() a single next tick to test before doing any heavier
-- table walk. Stale frontier ticks are tolerated and discarded as they surface.
rebuild_ui_due_frontier = function(runtime)
    local frontier = {}
    local present = runtime.ui_due_frontier_present or {}
    runtime.ui_due_frontier_ticks = frontier
    runtime.ui_due_frontier_present = present
    runtime.ui_due_frontier_head = 1
    for tick in pairs(present) do
        present[tick] = nil
    end

    local due_ticks = clear_scratch_array(runtime.scratch_due_ticks)
    for bucket_tick in pairs(runtime.ui_due_buckets) do
        local numeric_tick = tonumber(bucket_tick) or 0
        if numeric_tick > 0 then
            due_ticks[#due_ticks + 1] = numeric_tick
        end
    end

    table.sort(due_ticks)
    for _, due_tick in ipairs(due_ticks) do
        frontier[#frontier + 1] = due_tick
        present[due_tick] = true
    end

    runtime.next_ui_due_tick = frontier[1] or 0
    return runtime.next_ui_due_tick
end

compact_ui_due_frontier = function(runtime)
    local frontier = runtime.ui_due_frontier_ticks or {}
    local head = math.max(1, tonumber(runtime.ui_due_frontier_head) or 1)
    if head <= 1 then
        return frontier
    end

    local compacted = {}
    for i = head, #frontier do
        compacted[#compacted + 1] = frontier[i]
    end

    runtime.ui_due_frontier_ticks = compacted
    runtime.ui_due_frontier_head = 1
    return compacted
end

-- Advance, do not scan. This function peels stale head entries until it finds
-- a delayed bucket that still exists. If the frontier and buckets disagree too
-- much, it rebuilds from the authoritative delayed-bucket table.
advance_ui_due_frontier = function(runtime)
    local frontier = runtime.ui_due_frontier_ticks or {}
    local head = math.max(1, tonumber(runtime.ui_due_frontier_head) or 1)
    local present = runtime.ui_due_frontier_present or {}
    runtime.ui_due_frontier_ticks = frontier
    runtime.ui_due_frontier_head = head
    runtime.ui_due_frontier_present = present

    if head > #frontier then
        if next(runtime.ui_due_buckets) ~= nil then
            return rebuild_ui_due_frontier(runtime)
        end
        runtime.ui_due_frontier_ticks = {}
        runtime.ui_due_frontier_head = 1
        runtime.next_ui_due_tick = 0
        return 0
    end

    while head <= #frontier do
        local due_tick = tonumber(frontier[head]) or 0
        if due_tick > 0 and runtime.ui_due_buckets[due_tick] ~= nil then
            break
        end
        if due_tick > 0 then
            present[due_tick] = nil
        end
        head = head + 1
    end

    runtime.ui_due_frontier_head = head
    if head > #frontier then
        if next(runtime.ui_due_buckets) ~= nil then
            return rebuild_ui_due_frontier(runtime)
        end
        runtime.ui_due_frontier_ticks = {}
        runtime.ui_due_frontier_head = 1
        runtime.next_ui_due_tick = 0
        return 0
    end

    if head > FRONTIER_COMPACT_THRESHOLD and head > math.floor(#frontier / 2) then
        frontier = compact_ui_due_frontier(runtime)
        head = runtime.ui_due_frontier_head
    end

    runtime.next_ui_due_tick = tonumber(frontier[head]) or 0
    return runtime.next_ui_due_tick
end

-- Insertion keeps only the unconsumed suffix sorted. The head can point past old
-- entries, which is why callers never iterate frontier from index 1 directly.
insert_ui_due_frontier_tick = function(runtime, due_tick)
    due_tick = math.floor(tonumber(due_tick) or 0)
    if due_tick <= 0 then
        return
    end

    local frontier = runtime.ui_due_frontier_ticks or {}
    local head = math.max(1, tonumber(runtime.ui_due_frontier_head) or 1)
    local present = runtime.ui_due_frontier_present or {}
    runtime.ui_due_frontier_ticks = frontier
    runtime.ui_due_frontier_head = head
    runtime.ui_due_frontier_present = present

    if present[due_tick] then
        if runtime.next_ui_due_tick == 0 then
            advance_ui_due_frontier(runtime)
        end
        return
    end

    for i = head, #frontier do
        if due_tick < frontier[i] then
            table.insert(frontier, i, due_tick)
            present[due_tick] = true
            runtime.next_ui_due_tick = frontier[head] or due_tick
            return
        end
    end

    frontier[#frontier + 1] = due_tick
    present[due_tick] = true
    if runtime.next_ui_due_tick == 0 or due_tick < runtime.next_ui_due_tick then
        runtime.next_ui_due_tick = due_tick
    end
end

-- Watchers are the bridge between the simulation cadence and the player-facing
-- UI cadence. Periodic surface wakeups only refresh players who are actively
-- watching that surface or unit, and even then the UI queue performs its own
-- per-player debounce.
local function should_queue_surface_viewer(runtime, surface_index, player_index, wake_reason)
    if not (runtime and surface_index and player_index and runtime.watch_by_player[player_index]) then
        return false
    end

    if wake_reason ~= "periodic" then
        return true
    end

    local watch = runtime.watch_by_player[player_index]
    local watched_unit_number = watch and watch.unit_number or nil
    if watched_unit_number and runtime.by_unit[watched_unit_number] ~= nil then
        return true
    end

    local surface = game and game.get_surface(surface_index) or nil
    return surface and surface.valid and surface.platform and surface.platform.valid
end

local function queue_surface_viewers(runtime, surface_index, current_tick, wake_reason)
    local watchers = runtime.watchers_by_surface[surface_index]
    if not watchers then
        return
    end

    for player_index in pairs(watchers) do
        if should_queue_surface_viewer(runtime, surface_index, player_index, wake_reason) then
            queue_ui_refresh(runtime, player_index, current_tick)
        end
    end
end

local function queue_unit_viewers(runtime, unit_numbers, current_tick)
    if not (runtime and unit_numbers) then
        return
    end

    for _, unit_number in ipairs(unit_numbers) do
        local watchers = runtime.watchers_by_unit[unit_number]
        if watchers then
            for player_index in pairs(watchers) do
                if runtime.watch_by_player[player_index] then
                    queue_ui_refresh(runtime, player_index, current_tick)
                end
            end
        end
    end
end

-- Surface due frontier mirrors the UI frontier, but it schedules simulation
-- surfaces instead of players. The authoritative "one due tick per surface" map
-- is surface_due_tick_by_surface; delayed buckets may contain stale entries from
-- earlier due ticks and must be checked before activation.
local function rebuild_surface_due_frontier(runtime)
    local frontier = {}
    local present = runtime.surface_due_frontier_present or {}
    runtime.surface_due_frontier_ticks = frontier
    runtime.surface_due_frontier_present = present
    runtime.surface_due_frontier_head = 1
    for tick in pairs(present) do
        present[tick] = nil
    end

    local due_ticks = clear_scratch_array(runtime.scratch_due_ticks)
    for bucket_tick in pairs(runtime.surface_due_buckets) do
        local numeric_tick = tonumber(bucket_tick) or 0
        if numeric_tick > 0 then
            due_ticks[#due_ticks + 1] = numeric_tick
        end
    end

    table.sort(due_ticks)
    for _, due_tick in ipairs(due_ticks) do
        frontier[#frontier + 1] = due_tick
        present[due_tick] = true
    end

    runtime.next_surface_due_tick = frontier[1] or 0
    return runtime.next_surface_due_tick
end

local function compact_surface_due_frontier(runtime)
    local frontier = runtime.surface_due_frontier_ticks or {}
    local head = math.max(1, tonumber(runtime.surface_due_frontier_head) or 1)
    if head <= 1 then
        return frontier
    end

    local compacted = {}
    for i = head, #frontier do
        compacted[#compacted + 1] = frontier[i]
    end

    runtime.surface_due_frontier_ticks = compacted
    runtime.surface_due_frontier_head = 1
    return compacted
end

local function advance_surface_due_frontier(runtime)
    local frontier = runtime.surface_due_frontier_ticks or {}
    local head = math.max(1, tonumber(runtime.surface_due_frontier_head) or 1)
    local present = runtime.surface_due_frontier_present or {}
    runtime.surface_due_frontier_ticks = frontier
    runtime.surface_due_frontier_head = head
    runtime.surface_due_frontier_present = present

    if head > #frontier then
        if next(runtime.surface_due_buckets) ~= nil then
            return rebuild_surface_due_frontier(runtime)
        end
        runtime.next_surface_due_tick = 0
        return 0
    end

    while head <= #frontier and not runtime.surface_due_buckets[frontier[head]] do
        present[frontier[head]] = nil
        head = head + 1
    end
    runtime.surface_due_frontier_head = head

    if head > #frontier and next(runtime.surface_due_buckets) ~= nil then
        return rebuild_surface_due_frontier(runtime)
    end
    if head > #frontier then
        runtime.surface_due_frontier_ticks = {}
        runtime.surface_due_frontier_head = 1
        runtime.next_surface_due_tick = 0
        return 0
    end

    if head > FRONTIER_COMPACT_THRESHOLD and head > math.floor(#frontier / 2) then
        frontier = compact_surface_due_frontier(runtime)
        head = 1
    end

    runtime.next_surface_due_tick = frontier[head] or 0
    return runtime.next_surface_due_tick
end

local function insert_surface_due_frontier_tick(runtime, due_tick)
    if not due_tick or due_tick < 1 then
        return
    end

    local frontier = runtime.surface_due_frontier_ticks or {}
    local head = math.max(1, tonumber(runtime.surface_due_frontier_head) or 1)
    local present = runtime.surface_due_frontier_present or {}
    runtime.surface_due_frontier_ticks = frontier
    runtime.surface_due_frontier_head = head
    runtime.surface_due_frontier_present = present

    if present[due_tick] then
        runtime.next_surface_due_tick = frontier[head] or due_tick
        return
    end

    local insert_at = #frontier + 1
    for i = head, #frontier do
        if due_tick < frontier[i] then
            insert_at = i
            break
        end
    end

    table.insert(frontier, insert_at, due_tick)
    present[due_tick] = true
    runtime.next_surface_due_tick = frontier[head] or due_tick
end

-- Move due surfaces into the ready queue for bounded processing. This is the
-- module's main UPS valve: activation can release many surfaces at once, but
-- model.update(limit, event) decides how many surfaces actually get processed.
local function activate_due_surfaces(runtime, current_tick)
    if runtime.last_due_activation_tick == current_tick then
        return 0
    end

    local next_due_tick = advance_surface_due_frontier(runtime)
    if next_due_tick == 0 or current_tick < next_due_tick then
        return 0
    end

    runtime.last_due_activation_tick = current_tick

    local activated = 0
    while next_due_tick > 0 and next_due_tick <= current_tick do
        local due_tick = next_due_tick
        runtime.surface_due_frontier_present[due_tick] = nil
        runtime.surface_due_frontier_head = math.max(1, tonumber(runtime.surface_due_frontier_head) or 1) + 1
        for _, surface_index in ipairs(scheduler.delayed_take_due(runtime.surface_due_buckets, due_tick)) do
            if runtime.surface_due_tick_by_surface[surface_index] == due_tick then
                runtime.surface_due_tick_by_surface[surface_index] = nil
                runtime.due_surface_count = math.max(0, runtime.due_surface_count - 1)
                if scheduler.queue_push_unique(runtime.surface_queue, surface_index, surface_index) then
                    runtime.surface_queue_count = runtime.surface_queue_count + 1
                    activated = activated + 1
                end
            end
        end
        next_due_tick = advance_surface_due_frontier(runtime)
    end

    runtime.next_surface_due_tick = next_due_tick
    return activated
end

local function clear_player_watch(runtime, player_index)
    local previous_watch = runtime.watch_by_player[player_index]
    if previous_watch and previous_watch.surface_index and runtime.watchers_by_surface[previous_watch.surface_index] then
        runtime.watchers_by_surface[previous_watch.surface_index][player_index] = nil
        if next(runtime.watchers_by_surface[previous_watch.surface_index]) == nil then
            runtime.watchers_by_surface[previous_watch.surface_index] = nil
        end
    end
    if previous_watch and previous_watch.unit_number and runtime.watchers_by_unit[previous_watch.unit_number] then
        runtime.watchers_by_unit[previous_watch.unit_number][player_index] = nil
        if next(runtime.watchers_by_unit[previous_watch.unit_number]) == nil then
            runtime.watchers_by_unit[previous_watch.unit_number] = nil
        end
    end

    if previous_watch then
        runtime.watch_by_player[player_index] = nil
        runtime.watched_player_count = math.max(0, runtime.watched_player_count - 1)
    end
end

local function set_player_watch(runtime, player_index, surface_index, unit_number)
    local current_watch = runtime.watch_by_player[player_index]
    if current_watch and current_watch.surface_index == surface_index and current_watch.unit_number == unit_number then
        return
    end

    clear_player_watch(runtime, player_index)
    runtime.watch_by_player[player_index] = {
        surface_index = surface_index,
        unit_number = unit_number,
    }
    runtime.watched_player_count = runtime.watched_player_count + 1
    runtime.watchers_by_surface[surface_index] = runtime.watchers_by_surface[surface_index] or {}
    runtime.watchers_by_surface[surface_index][player_index] = true
    if unit_number then
        runtime.watchers_by_unit[unit_number] = runtime.watchers_by_unit[unit_number] or {}
        runtime.watchers_by_unit[unit_number][player_index] = true
    end
end

-- Scheduling a surface replaces later work with earlier work, but not the other
-- way around. The delayed bucket may keep old entries; surface_due_tick_by_surface
-- is the authoritative "this surface is really due at this tick" guard.
local function schedule_surface(runtime, surface_index, due_tick)
    if not surface_index then
        return
    end

    due_tick = math.max(1, math.floor(tonumber(due_tick) or 0))
    local existing_due_tick = runtime.surface_due_tick_by_surface[surface_index]
    -- Never replace an earlier wakeup with a later one. A surface can be pulled
    -- forward by build/repair/swap/viewer events, but periodic cadence should not
    -- push urgent work farther away.
    if existing_due_tick and existing_due_tick <= due_tick then
        return
    end

    if not existing_due_tick then
        runtime.due_surface_count = runtime.due_surface_count + 1
    end
    runtime.surface_due_tick_by_surface[surface_index] = due_tick
    local bucket_exists = runtime.surface_due_buckets[due_tick] ~= nil
    scheduler.delayed_schedule(runtime.surface_due_buckets, due_tick, surface_index)
    if not bucket_exists then
        insert_surface_due_frontier_tick(runtime, due_tick)
    elseif runtime.next_surface_due_tick == 0 then
        advance_surface_due_frontier(runtime)
    end
end

-- Aggregate adjustment is intentionally incremental. Register/unregister and
-- shell swaps should update the surface's count and weight immediately so the
-- next periodic pass can build context without a full surface rebuild.
local function adjust_surface_aggregate(runtime, surface_index, active_delta, weight_delta, cohort_key, cohort_delta, entity_name, quality_name)
    if not (runtime and surface_index) then
        return nil
    end

    local aggregates = runtime.surface_aggregate_by_surface or {}
    runtime.surface_aggregate_by_surface = aggregates
    local aggregate = aggregates[surface_index]
    if not aggregate then
        aggregate = {
            total_weight = 0,
            active_count = 0,
            cohort_counts = {},
            network_cohort_counts = {},
        }
        aggregates[surface_index] = aggregate
    end

    aggregate.active_count = math.max(0, (tonumber(aggregate.active_count) or 0) + (tonumber(active_delta) or 0))
    aggregate.total_weight = math.max(0, (tonumber(aggregate.total_weight) or 0) + (tonumber(weight_delta) or 0))
    aggregate.cohort_counts = aggregate.cohort_counts or {}
    -- Electric network membership is not stable enough to maintain incrementally:
    -- nearby poles can join/split networks without touching this entity. Mark the
    -- network index dirty and let build_surface_context() rebuild before reading
    -- telemetry.
    aggregate.network_index_ready = false
    if cohort_key then
        local cohort_entry = aggregate.cohort_counts[cohort_key]
        local cohort_count_delta = tonumber(cohort_delta) or 0
        if not cohort_entry and cohort_count_delta > 0 then
            cohort_entry = {
                count = 0,
                entity_name = entity_name,
                quality_name = quality_name,
            }
            aggregate.cohort_counts[cohort_key] = cohort_entry
        end
        if cohort_entry then
            cohort_entry.count = math.max(0, (tonumber(cohort_entry.count) or 0) + cohort_count_delta)
            cohort_entry.entity_name = cohort_entry.entity_name or entity_name
            if quality_name ~= nil then
                cohort_entry.quality_name = quality_name
            end
            if cohort_entry.count <= 0 then
                aggregate.cohort_counts[cohort_key] = nil
            end
        end
    end
    runtime.surface_state_by_surface[surface_index] = nil

    if aggregate.active_count <= 0 then
        aggregates[surface_index] = nil
        return nil
    end

    return aggregate
end

-- Membership is kept in both directions: by_unit has the record, units_by_surface
-- is the scheduling index, and the aggregate is the fast surface summary. All
-- three are updated together so service passes do not need to rediscover the map.
local function add_surface_unit(runtime, surface_index, unit_number, resonance_weight, entity_name, quality_name)
    if not (runtime and surface_index and unit_number) then
        return false
    end

    local surface_units = runtime.units_by_surface[surface_index]
    if not surface_units then
        surface_units = {}
        runtime.units_by_surface[surface_index] = surface_units
        runtime.active_surface_count = runtime.active_surface_count + 1
    end

    if surface_units[unit_number] then
        runtime.surface_state_by_surface[surface_index] = nil
        return false
    end

    surface_units[unit_number] = true
    adjust_surface_aggregate(
        runtime,
        surface_index,
        1,
        resonance_weight or 0,
        get_surface_cohort_key(entity_name, quality_name),
        1,
        entity_name,
        quality_name
    )
    return true
end

-- Removing the last unit on a surface also tears down that surface's queued work.
-- Any stale delayed-bucket entries are harmless because activation checks the
-- authoritative due map before pushing a surface into the ready queue.
local function remove_surface_unit(runtime, surface_index, unit_number, resonance_weight, entity_name, quality_name)
    local surface_units = runtime.units_by_surface[surface_index]
    local removed = false
    if surface_units and surface_units[unit_number] then
        surface_units[unit_number] = nil
        removed = true
    end

    if removed or (surface_units == nil and runtime.surface_aggregate_by_surface[surface_index] ~= nil) then
        adjust_surface_aggregate(
            runtime,
            surface_index,
            -1,
            -(tonumber(resonance_weight) or 0),
            get_surface_cohort_key(entity_name, quality_name),
            -1,
            entity_name,
            quality_name
        )
    else
        runtime.surface_state_by_surface[surface_index] = nil
    end

    if not surface_units then
        return
    end

    if next(surface_units) == nil then
        local removed_due_tick = runtime.surface_due_tick_by_surface[surface_index]
        runtime.units_by_surface[surface_index] = nil
        runtime.active_surface_count = math.max(0, runtime.active_surface_count - 1)
        runtime.surface_due_tick_by_surface[surface_index] = nil
        runtime.surface_state_by_surface[surface_index] = nil
        runtime.surface_aggregate_by_surface[surface_index] = nil
        if scheduler.queue_remove_value(runtime.surface_queue, surface_index) then
            runtime.surface_queue_count = math.max(0, runtime.surface_queue_count - 1)
        end
        if removed_due_tick then
            runtime.due_surface_count = math.max(0, runtime.due_surface_count - 1)
        end
        if removed_due_tick and runtime.next_surface_due_tick == removed_due_tick and not runtime.surface_due_buckets[removed_due_tick] then
            advance_surface_due_frontier(runtime)
        end
    end
end

local function unregister_record(runtime, unit_number)
    local record = runtime.by_unit[unit_number]
    if not record then
        return nil
    end

    remove_surface_unit(
        runtime,
        record.surface_index,
        unit_number,
        record.resonance_weight or get_resonance_weight(record.quality_factor),
        record.entity_name,
        record.quality_name
    )
    runtime.by_unit[unit_number] = nil
    runtime.live_crystal_count = math.max(0, runtime.live_crystal_count - 1)

    for player_index, open_unit in pairs(runtime.open_by_player) do
        if open_unit == unit_number then
            runtime.open_by_player[player_index] = nil
        end
    end

    return record
end

local function apply_quality_buffer(entity, quality_factor)
    if not entity_check(entity) then
        return DEFAULT_BUFFER_CAPACITY
    end

    local current_energy = tonumber(entity.energy) or 0
    local target_buffer = math.max(1, math.floor(DEFAULT_BUFFER_CAPACITY * (1 + (0.20 * quality_factor))))
    if math.abs((tonumber(entity.electric_buffer_size) or 0) - target_buffer) > 0.5 then
        entity.electric_buffer_size = target_buffer
    end
    if current_energy > target_buffer then
        entity.energy = target_buffer
    end

    return target_buffer
end

local function show_flying_text(surface, position, key)
    if not (surface and surface.valid and position) then
        return
    end

    rendering.draw_text{
        text = {"exotic-industries." .. key},
        surface = surface,
        target = {x = position.x, y = position.y},
        color = {r = 0.75, g = 0.95, b = 1},
        scale = 1,
        alignment = "center",
        scale_with_zoom = false,
        time_to_live = 180,
    }
end

-- Mining is a two-event operation. The pre-mine event still has the live entity
-- and its instability state; the mined event has the result buffer. These
-- snapshots carry the answer across that gap so mining a stabilized Gaia shell
-- and mining a damaged shell can produce different results deterministically.
local function capture_pending_mining(record)
    if not record then
        return nil
    end

    -- The result item is decided from the current runtime state, not from the
    -- prototype's mineable result. This enforces the design rule: only calm
    -- Gaia-stable shells mined on Gaia return a live crystal item; everything
    -- else collapses into a quality-preserving husk.
    local entity = ei_lib.get_valid_entity(record.entity)
    local unit_number = record.unit_number
    local quality_name = entity and get_quality_name(entity) or record.quality_name
    local can_return_live_item = entity_check(entity)
        and entity.name == GAIA_NAME
        and is_gaia_surface(entity.surface)
        and (record.instability or 0) < 25

    local husk_name = get_husk_name(record.instability or 0, false)
    local snapshot = {
        unit_number = unit_number,
        quality_name = quality_name,
        live_item_name = can_return_live_item and GAIA_NAME or nil,
        husk_name = husk_name,
    }

    return snapshot
end

-- Each snapshot can be reachable through three indexes at once: unit number,
-- player index, and robot unit number. Cleanup always removes every alias so a
-- later mined event cannot accidentally consume an old replacement decision.
local function clear_pending_mining_snapshot(runtime, pending_snapshot)
    if not pending_snapshot then
        return
    end

    local pending_unit_number = pending_snapshot.unit_number
    if pending_unit_number then
        runtime.pending_mining_by_unit[pending_unit_number] = nil
    end
    for player_index, player_snapshot in pairs(runtime.pending_mining_by_player) do
        if player_snapshot == pending_snapshot then
            runtime.pending_mining_by_player[player_index] = nil
        end
    end
    for robot_unit_number, robot_snapshot in pairs(runtime.pending_mining_by_robot) do
        if robot_snapshot == pending_snapshot then
            runtime.pending_mining_by_robot[robot_unit_number] = nil
        end
    end
end

local function store_pending_mining(runtime, event, snapshot)
    if not snapshot then
        return
    end

    -- The later mined event may arrive with different identifying information
    -- depending on player/robot mining and engine timing. Store every alias we
    -- can see now, then clear all aliases together when consumed.
    local unit_number = snapshot.unit_number
    clear_pending_mining_snapshot(runtime, runtime.pending_mining_by_unit[unit_number])
    if event and event.player_index then
        clear_pending_mining_snapshot(runtime, runtime.pending_mining_by_player[event.player_index])
    end
    if event and event.robot and event.robot.valid then
        clear_pending_mining_snapshot(runtime, runtime.pending_mining_by_robot[event.robot.unit_number])
    end
    runtime.pending_mining_by_unit[unit_number] = snapshot
    if event and event.player_index then
        runtime.pending_mining_by_player[event.player_index] = snapshot
    end
    if event and event.robot and event.robot.valid then
        runtime.pending_mining_by_robot[event.robot.unit_number] = snapshot
    end
end

local function take_pending_mining(runtime, event)
    local snapshot = nil
    local entity = event and event.entity or nil
    local unit_number = entity and get_unit_number(entity) or nil
    -- Prefer unit number when Factorio still provides it; player and robot
    -- indexes are fallbacks for the same pre-mine snapshot.
    if unit_number then
        snapshot = runtime.pending_mining_by_unit[unit_number]
    end

    if not snapshot and event and event.player_index then
        snapshot = runtime.pending_mining_by_player[event.player_index]
    end

    if not snapshot and event and event.robot and event.robot.valid then
        snapshot = runtime.pending_mining_by_robot[event.robot.unit_number]
    end

    if not snapshot then
        return nil
    end

    clear_pending_mining_snapshot(runtime, snapshot)

    return snapshot
end

-- Registration is the single entrance for a live shell. It refreshes quality,
-- restores carried instability after shell swaps, updates surface membership,
-- schedules simulation, and wakes interested UI. Callers can skip scheduling or
-- viewer refresh only while they are orchestrating a larger atomic operation.
local function register_record(runtime, entity, current_tick, carried_state, options)
    if not is_live_entity(entity) then
        return nil
    end

    local unit_number = get_unit_number(entity)
    if not unit_number then
        return nil
    end

    local surface_index = entity.surface.index

    local record = runtime.by_unit[unit_number]
    local is_new_record = record == nil
    -- Existing records are possible after save repair, UI discovery, or scripted
    -- re-registration. Preserve previous index metadata long enough to remove or
    -- adjust the old aggregate contribution without double-counting.
    local previous_surface_index = record and record.surface_index or nil
    local previous_weight = record and (record.resonance_weight or get_resonance_weight(record.quality_factor)) or nil
    local previous_entity_name = record and record.entity_name or nil
    local previous_quality_name = record and record.quality_name or nil
    record = record or {
        unit_number = unit_number,
        instability = 0,
        last_load_band = "idle",
        backlash_cooldown_until = 0,
        frozen = false,
    }

    record.entity = entity
    record.entity_name = entity.name
    record.surface_index = surface_index
    record.quality_factor = ei_lib.get_normalized_quality_factor(entity)
    record.quality_name = get_quality_name(entity)
    record.resonance_weight = get_resonance_weight(record.quality_factor)
    -- carried_state comes from swaps and repair flows. Keep resonance memory and
    -- UI history, but always refresh entity/quality/surface from the actual shell.
    record.instability = carried_state and carried_state.instability or record.instability or 0
    record.last_load_band = carried_state and carried_state.last_load_band or record.last_load_band or "idle"
    record.last_telemetry_key = carried_state and carried_state.last_telemetry_key or record.last_telemetry_key or "strain-fallback"
    record.backlash_cooldown_until = carried_state and carried_state.backlash_cooldown_until or record.backlash_cooldown_until or 0
    record.frozen = carried_state and carried_state.frozen or record.frozen or false
    record.last_energy = carried_state and carried_state.last_energy or record.last_energy or (tonumber(entity.energy) or 0)

    apply_quality_buffer(entity, record.quality_factor)

    if previous_surface_index and previous_surface_index ~= surface_index then
        -- Rare, but possible if another script moved the entity or an old save had
        -- bad membership. Remove the old surface entry before adding the new one.
        remove_surface_unit(runtime, previous_surface_index, unit_number, previous_weight, previous_entity_name, previous_quality_name)
    end
    local was_new_surface_unit = add_surface_unit(runtime, surface_index, unit_number, record.resonance_weight, record.entity_name, record.quality_name)

    runtime.by_unit[unit_number] = record
    if is_new_record then
        runtime.live_crystal_count = runtime.live_crystal_count + 1
    elseif previous_surface_index == surface_index and not was_new_surface_unit then
        -- Re-registration of the same unit can still change weight or cohort if
        -- quality/prototype metadata was repaired. Adjust only the deltas.
        local weight_delta = record.resonance_weight - (previous_weight or 0)
        if math.abs(weight_delta) > 0.0001 then
            adjust_surface_aggregate(runtime, surface_index, 0, weight_delta)
        end
        local previous_cohort_key = get_surface_cohort_key(previous_entity_name, previous_quality_name)
        local current_cohort_key = get_surface_cohort_key(record.entity_name, record.quality_name)
        if previous_cohort_key ~= current_cohort_key then
            adjust_surface_aggregate(runtime, surface_index, 0, 0, previous_cohort_key, -1, previous_entity_name, previous_quality_name)
            adjust_surface_aggregate(runtime, surface_index, 0, 0, current_cohort_key, 1, record.entity_name, record.quality_name)
        end
    end
    options = options or {}
    if not options.skip_schedule then
        schedule_surface(runtime, surface_index, current_tick)
    end
    if not options.skip_viewers then
        queue_surface_viewers(runtime, surface_index, current_tick)
    end

    return record
end

-- Shell swaps are entity replacement, not a prototype mutation. Carry only the
-- state that belongs to the resonance runtime, register the new shell, then move
-- player-opened and player-watched references across to the new unit number.
local function finalize_swap(runtime, old_record, new_entity, current_tick, reason)
    -- Only resonance state crosses the destroy/create boundary. Everything owned
    -- by the new entity itself is rediscovered by register_record().
    local carried_state = {
        instability = old_record and old_record.instability or 0,
        last_load_band = old_record and old_record.last_load_band or "idle",
        last_telemetry_key = old_record and old_record.last_telemetry_key or "strain-fallback",
        backlash_cooldown_until = old_record and old_record.backlash_cooldown_until or 0,
        frozen = old_record and old_record.frozen or false,
        last_energy = old_record and old_record.last_energy or 0,
    }
    if old_record then
        -- Unregister first so aggregates never briefly count both the old and new
        -- shell. That matters because swaps can be triggered mid surface pass.
        unregister_record(runtime, old_record.unit_number)
    end

    local new_record = register_record(runtime, new_entity, current_tick, carried_state, {
        skip_schedule = true,
        skip_viewers = true,
    })
    if new_record then
        schedule_surface(runtime, new_record.surface_index, current_tick + SERVICE_INTERVAL_TICKS)
        queue_surface_viewers(runtime, new_record.surface_index, current_tick)
    end

    if old_record and new_record then
        -- Any UI that was following the old unit should now follow the replacement
        -- unit. Without this, shell swaps feel like the GUI randomly closed.
        for player_index, open_unit in pairs(runtime.open_by_player) do
            if open_unit == old_record.unit_number then
                local player = game and game.get_player(player_index) or nil
                if player and player.valid then
                    player.opened = new_entity
                end
                runtime.open_by_player[player_index] = new_record.unit_number
                queue_ui_refresh(runtime, player_index, current_tick)
            end
        end

        for player_index, watch in pairs(runtime.watch_by_player) do
            if watch and watch.unit_number == old_record.unit_number then
                set_player_watch(runtime, player_index, new_record.surface_index, new_record.unit_number)
                queue_ui_refresh(runtime, player_index, current_tick)
            end
        end
    end

    if reason == "stabilized" then
        show_flying_text(new_entity.surface, new_entity.position, "crystal-accumulator-floating-stabilized")
    elseif reason == "downgraded" then
        show_flying_text(new_entity.surface, new_entity.position, "crystal-accumulator-floating-downgraded")
    end

    return new_record
end

-- swap_live_shell() preserves the player's visible machine as much as Factorio
-- allows: quality, force, direction, health, energy, buffer size, and circuit
-- wires are captured before destroying the old shell and restored afterward.
local function swap_live_shell(runtime, record, target_name, current_tick, reason)
    local entity = ei_lib.get_valid_entity(record and record.entity)
    if not (record and entity and target_name and entity.name ~= target_name) then
        return record
    end

    -- Capture visible shell state before destroy. This is the only point where
    -- the old entity is guaranteed valid, so every value needed for continuity is
    -- copied up front.
    local surface = entity.surface
    local quality = entity.quality
    local energy = tonumber(entity.energy) or 0
    local buffer = tonumber(entity.electric_buffer_size) or DEFAULT_BUFFER_CAPACITY
    local health = entity.health
    local force = entity.force
    local position = entity.position
    local direction = entity.direction
    local saved_connections = get_real_circuit_connections(entity)

    -- Do not raise destroy/build events for internal shell swaps. The module is
    -- already moving runtime membership explicitly, and raised events would cause
    -- other handlers to see a transient removal/rebuild that players did not ask
    -- for.
    entity.destroy({raise_destroy = false})

    local new_entity = surface.create_entity{
        name = target_name,
        position = position,
        force = force,
        direction = direction,
        quality = quality,
        create_build_effect_smoke = false,
        raise_built = false,
    }

    if not entity_check(new_entity) then
        return nil
    end

    -- Preserve the old buffer and stored energy for flavor continuity. Prototype
    -- flow limits define the actual shell output; buffer size is a forgiveness
    -- and strain-shaping knob, not the source of magical extra power.
    new_entity.health = math.min(new_entity.max_health or health, health or new_entity.health)
    new_entity.electric_buffer_size = buffer
    new_entity.energy = math.min(buffer, energy)
    restore_circuit_connections(new_entity, saved_connections)

    return finalize_swap(runtime, record, new_entity, current_tick, reason)
end

-- A husk is the terminal failed shell. It stays in-world as repair/mining/UI
-- content, but unregisters from the live scheduler before the replacement entity
-- is created so it cannot be processed as an operating accumulator again.
local function break_to_husk(runtime, record, current_tick, husk_name, reason)
    local entity = ei_lib.get_valid_entity(record and record.entity)
    if not entity then
        if record then
            unregister_record(runtime, record.unit_number)
        end
        return nil
    end

    local quality = entity.quality
    local force = entity.force
    local position = entity.position
    local direction = entity.direction
    local health = entity.health
    local surface = entity.surface
    local old_surface_index = record.surface_index

    -- Unregister before creating the husk so the failed shell stops contributing
    -- to load/crowding immediately. The husk remains relevant to UI and repair
    -- through ALL_RELEVANT_NAMES, but it is not scheduled as a live unit.
    unregister_record(runtime, record.unit_number)
    entity.destroy({raise_destroy = false})

    local husk = surface.create_entity{
        name = husk_name,
        position = position,
        force = force,
        direction = direction,
        quality = quality,
        create_build_effect_smoke = false,
        raise_built = false,
    }

    if entity_check(husk) and health then
        husk.health = math.min(husk.max_health or health, health)
    end

    queue_surface_viewers(runtime, old_surface_index, current_tick)
    if reason == "broken" then
        show_flying_text(surface, position, "crystal-accumulator-floating-broken")
    end

    return husk
end

local function choose_crowding_state(total_weight, thresholds)
    if total_weight > thresholds[3] then
        return "chaotic"
    end
    if total_weight > thresholds[2] then
        return "strained"
    end
    if total_weight > thresholds[1] then
        return "crowded"
    end
    return "free"
end

-- Electric statistics are the preferred load signal, because they reflect what
-- the network actually asked the accumulator cohort to do. Factorio exposes
-- statistics by item/entity flow id; quality-aware shells therefore need the
-- quality-bearing form returned by make_stats_flow_id().
local function read_statistics_flow_per_tick(statistics, entity_name, quality_name, category)
    if not (statistics and statistics.valid and entity_name) then
        return 0
    end

    local ok, flow_count = pcall(function()
        return statistics.get_flow_count{
            name = make_stats_flow_id(entity_name, quality_name),
            category = category,
            precision_index = defines.flow_precision_index.five_seconds,
        }
    end)
    if not ok then
        return 0
    end

    return math.max(0, tonumber(flow_count) or 0)
end

local function read_statistics_power_per_tick(statistics, entity_name, quality_name)
    -- EEIs can appear on either side of the electric-flow ledger depending on how
    -- Factorio classifies the interface at that moment. Use the stronger of input
    -- and output so the resonance system follows "network work observed" rather
    -- than a brittle category assumption.
    return math.max(
        read_statistics_flow_per_tick(statistics, entity_name, quality_name, "output"),
        read_statistics_flow_per_tick(statistics, entity_name, quality_name, "input")
    )
end

local function read_entity_network_statistics(entity)
    if not entity_check(entity) then
        return nil
    end

    local ok, statistics = pcall(function()
        return entity.electric_network_statistics
    end)
    if ok and statistics and statistics.valid then
        return statistics
    end

    return nil
end

-- Network statistics can be global for a surface or local to an electric
-- network. When the entity does not expose a valid statistics object directly,
-- probe nearby poles from the same electric network. This keeps isolated grids
-- readable without scanning the whole surface.
local function find_local_network_statistics(entity, network_id)
    if not (entity_check(entity) and network_id) then
        return nil
    end

    local direct_statistics = read_entity_network_statistics(entity)
    if direct_statistics then
        return direct_statistics
    end

    for _, pole in ipairs(entity.surface.find_entities_filtered{
        position = entity.position,
        radius = 64,
        type = "electric-pole",
    }) do
        if get_electric_network_id(pole) == network_id then
            local pole_statistics = read_entity_network_statistics(pole)
            if pole_statistics then
                return pole_statistics
            end
        end
    end

    return nil
end

-- Build a surface-level telemetry map once per surface service pass. Ratios are
-- stored by cohort so individual accumulators can later pick the most specific
-- reading available: network cohort first, then surface cohort, then local
-- buffer-strain fallback.
local function build_surface_telemetry(surface, aggregate)
    local telemetry = {
        available = false,
        key = "strain-fallback",
        ratio_by_cohort = {},
        ratio_by_network_cohort = {},
    }
    if not (surface and surface.valid) then
        return telemetry
    end

    local cohort_counts = aggregate and aggregate.cohort_counts or nil
    if surface.has_global_electric_network and cohort_counts and next(cohort_counts) ~= nil then
        local surface_statistics = surface.global_electric_network_statistics
        if surface_statistics and surface_statistics.valid then
            telemetry.available = true
            telemetry.key = "surface-strain"
            for cohort_key, cohort_entry in pairs(cohort_counts) do
                local cohort_count = cohort_entry and tonumber(cohort_entry.count) or 0
                if cohort_count > 0 and cohort_entry.entity_name then
                    local nominal_output = math.max(1, get_nominal_output_per_tick(cohort_entry.entity_name))
                    local output_per_tick = read_statistics_power_per_tick(surface_statistics, cohort_entry.entity_name, cohort_entry.quality_name)
                    local output_per_crystal = output_per_tick / cohort_count
                    telemetry.ratio_by_cohort[cohort_key] = ei_lib.clamp(output_per_crystal / nominal_output, 0, 1.25)
                end
            end
        end
    end

    local network_counts = aggregate and aggregate.network_cohort_counts or nil
    for _, network_entry in pairs(network_counts or {}) do
        local network_id = network_entry and network_entry.network_id or nil
        local statistics = find_local_network_statistics(network_entry and network_entry.representative_entity, network_id)
        if statistics then
            telemetry.available = true
            telemetry.key = "surface-strain"
            for cohort_key, cohort_entry in pairs(network_entry.cohort_counts or {}) do
                local cohort_count = cohort_entry and tonumber(cohort_entry.count) or 0
                if cohort_count > 0 and cohort_entry.entity_name then
                    -- Same shell+quality crystals on one network share the stats
                    -- term. Per-entity buffer strain is still applied later, so a
                    -- depleted sibling can read hotter than a full one.
                    local nominal_output = math.max(1, get_nominal_output_per_tick(cohort_entry.entity_name))
                    local output_per_tick = read_statistics_power_per_tick(statistics, cohort_entry.entity_name, cohort_entry.quality_name)
                    local output_per_crystal = output_per_tick / cohort_count
                    telemetry.ratio_by_network_cohort[get_network_cohort_key(network_id, cohort_entry.entity_name, cohort_entry.quality_name)] =
                        ei_lib.clamp(output_per_crystal / nominal_output, 0, 1.25)
                end
            end
        end
    end

    return telemetry
end

-- Buffer strain is the fallback load signal. It compares this cycle's energy
-- against the previous cycle and the shell's nominal output window. A falling
-- buffer means demand pressure; a recovering buffer relieves pressure.
local function resolve_strain_ratio(record, entity)
    local nominal_output = math.max(1, get_nominal_output_per_tick(entity.name))
    local buffer = math.max(1, tonumber(entity.electric_buffer_size) or DEFAULT_BUFFER_CAPACITY)
    local nominal_output_window = math.max(1, nominal_output * SERVICE_INTERVAL_TICKS)
    local current_energy = tonumber(entity.energy) or 0
    local previous_energy = tonumber(record.last_energy) or current_energy
    -- This is an EEI-safe proxy, not true per-entity generation telemetry. An
    -- empty/falling buffer implies local pressure; a recovering buffer tempers it.
    local buffer_ratio = ei_lib.clamp(current_energy / buffer, 0, 1)
    local deficit_ratio = math.max(previous_energy - current_energy, 0) / nominal_output_window
    local recovery_ratio = math.max(current_energy - previous_energy, 0) / nominal_output_window
    local proxy_load = ei_lib.clamp(((1 - buffer_ratio) * 0.75) + (deficit_ratio * 0.50) - (recovery_ratio * 0.25), 0, 1.25)

    return proxy_load
end

-- The final load ratio is conservative: use the strongest signal we can see.
-- Electric-stat telemetry catches real network work; buffer strain catches cases
-- where statistics are unavailable, local, delayed, or too noisy to trust alone.
local function resolve_load_ratio(record, entity, context)
    local cohort_key = get_surface_cohort_key(entity.name, record and record.quality_name or nil)
    local network_id = get_electric_network_id(entity)
    local network_cohort_key = get_network_cohort_key(network_id, entity.name, record and record.quality_name or nil)
    local telemetry_ratio = context
        and context.telemetry_ratio_by_network_cohort
        and context.telemetry_ratio_by_network_cohort[network_cohort_key]
        or nil
    telemetry_ratio = telemetry_ratio
        or (context and context.telemetry_ratio_by_cohort and context.telemetry_ratio_by_cohort[cohort_key])
        or 0
    local strain_ratio = resolve_strain_ratio(record, entity)
    local telemetry_key = context and context.telemetry_key or "strain-fallback"

    -- Taking max() intentionally errs on the side of stress. If either the grid
    -- statistics or the local buffer says the crystal is working hard, the shell
    -- should feel that pressure.
    return math.max(telemetry_ratio or 0, strain_ratio), telemetry_key
end

local function resolve_load_band(load_ratio)
    for _, band in ipairs(LOAD_BANDS) do
        if load_ratio >= band.min and load_ratio < band.max then
            return band.key, band.delta
        end
    end

    return "overdrive", 14
end

-- Lore keys intentionally follow state rather than exact numeric cause. This
-- keeps localisation compact while still letting Gaia, orbit, freezing, crowding,
-- and breakage read with distinct flavor.
local function choose_lore_key(profile_key, state_key, crowding_state, frozen)
    if profile_key == "gaia" then
        return "gaia"
    end
    if frozen then
        return "frozen"
    end
    if state_key == "fracturing" then
        return "fracturing"
    end
    if state_key == "volatile" then
        return "howling"
    end
    if crowding_state == "chaotic" then
        return "overcrowded"
    end
    if state_key == "strained" then
        return "singing"
    end
    if profile_key == "orbit" then
        return "astral"
    end
    return "quiet"
end

-- Backlash is the pressure relief valve. It fires only after high instability
-- and cooldown checks, then expresses the current surface's profile as pollution,
-- local damage, nearby instability, freezing, or no-op Gaia stability.
local function add_nearby_instability(runtime, source_entity, radius, delta, current_tick)
    for _, nearby in ipairs(source_entity.surface.find_entities_filtered{position = source_entity.position, radius = radius, name = LIVE_NAME_LIST}) do
        local nearby_unit = get_unit_number(nearby)
        local nearby_record = nearby_unit and runtime.by_unit[nearby_unit] or nil
        if nearby_record and nearby_unit ~= get_unit_number(source_entity) then
            nearby_record.instability = math.min(100, (nearby_record.instability or 0) + delta)
            schedule_surface(runtime, nearby_record.surface_index, current_tick + SERVICE_INTERVAL_TICKS)
        end
    end
end

local function apply_backlash(runtime, record, profile_key, intensity, current_tick)
    local entity = ei_lib.get_valid_entity(record and record.entity)
    if not entity or (record.backlash_cooldown_until or 0) > current_tick then
        return
    end

    intensity = math.max(1, math.floor(intensity * (1 - (0.30 * (record.quality_factor or 0))) + 0.5))
    record.backlash_cooldown_until = current_tick + (SERVICE_INTERVAL_TICKS * 2)
    show_flying_text(entity.surface, entity.position, "crystal-accumulator-floating-backlash")

    if profile_key == "nauvis" then
        entity.surface.pollute(entity.position, 8 * intensity)
        return
    end

    if profile_key == "fulgora" then
        for _, nearby in ipairs(entity.surface.find_entities_filtered{position = entity.position, radius = 6, force = entity.force}) do
            if nearby.valid and nearby ~= entity and nearby.health and not LIVE_NAMES[nearby.name] and not HUSK_NAMES[nearby.name] then
                nearby.damage(5 * intensity, entity.force, "electric")
            end
        end
        add_nearby_instability(runtime, entity, 6, 8 * intensity, current_tick)
        return
    end

    if profile_key == "vulcanus" then
        entity.surface.pollute(entity.position, 12 * intensity)
        for _, nearby in ipairs(entity.surface.find_entities_filtered{position = entity.position, radius = 4, force = entity.force}) do
            if nearby.valid and nearby ~= entity and nearby.health and not LIVE_NAMES[nearby.name] and not HUSK_NAMES[nearby.name] then
                nearby.damage(6 * intensity, entity.force, "fire")
            end
        end
        return
    end

    if profile_key == "gleba" then
        entity.surface.pollute(entity.position, 10 * intensity)
        add_nearby_instability(runtime, entity, 6, 10 * intensity, current_tick)
        return
    end

    if profile_key == "aquilo" then
        record.frozen = true
        record.instability = math.min(100, (record.instability or 0) + (4 * intensity))
        return
    end

    entity.surface.pollute(entity.position, 6 * intensity)
    add_nearby_instability(runtime, entity, 4, 4 * intensity, current_tick)
end

-- Shell target is a visual and mechanical summary of the current risk. Gaia
-- locks to the Gaia shell, Aquilo/frozen and overcrowded states bias low, high
-- useful load can surge, and strained/chaotic resonance suppresses surge before
-- it becomes a free power upgrade.
local function resolve_shell_target(context, load_ratio, record)
    local profile_key = context.profile_key
    local profile = context.profile
    local crowding_state = context.crowding_state
    if profile_key == "gaia" then
        return GAIA_NAME
    end

    if record.frozen or profile.shell_bias == "low" then
        return LOW_NAME
    end

    if crowding_state == "chaotic" or (record.instability or 0) >= 50 then
        return LOW_NAME
    end

    if profile_key == "fulgora" then
        local surge_window = (context.darkness or 0) < 0.45
        return surge_window and SURGED_NAME or LOW_NAME
    end

    if profile_key == "vulcanus" and load_ratio >= 0.95 and crowding_state ~= "strained" then
        return SURGED_NAME
    end

    if load_ratio > 1.05 and crowding_state == "free" and (record.instability or 0) < 50 then
        return SURGED_NAME
    end

    if crowding_state == "strained" then
        return LOW_NAME
    end

    return BASE_NAME
end

-- Surface context is the expensive shared read for a service pass. Build it once,
-- cache it, and hand it to every record on the same surface. It combines profile,
-- aggregate crowding, anchor field, darkness/transit state, and telemetry ratios.
-- Any record operation that changes membership or shell cohort invalidates this
-- cache by setting runtime.surface_state_by_surface[surface_index] = nil.
local function build_surface_context(runtime, surface, force_refresh)
    if not (surface and surface.valid) then
        return {
            profile_key = "generic",
            profile = PROFILE_DEFS.generic,
            anchor = {
                field = 0,
                extra_instability = 0,
                label = {"exotic-industries.crystal-accumulator-profile-generic"},
            },
            total_weight = 0,
            active_count = 0,
            crowding_state = "free",
            crowding_percent = 0,
            darkness = 0,
            in_transit = false,
            telemetry_key = "strain-fallback",
            telemetry_ratio_by_cohort = {},
            telemetry_ratio_by_network_cohort = {},
        }
    end

    local cached = runtime.surface_state_by_surface[surface.index]
    if cached and not force_refresh then
        cached.darkness = tonumber(surface.darkness) or 0
        if surface.platform and surface.platform.valid then
            cached.anchor = resolve_anchor_snapshot(runtime, surface)
            cached.in_transit = is_surface_in_transit(surface)
        elseif not cached.anchor then
            cached.anchor = resolve_anchor_snapshot(runtime, surface)
            cached.in_transit = false
        else
            cached.in_transit = false
        end
        return cached
    end

    local profile_key, profile = get_surface_profile(surface)
    local aggregate = runtime.surface_aggregate_by_surface[surface.index]
    local surface_units = runtime.units_by_surface[surface.index]
    if force_refresh
        or (surface_units and aggregate and aggregate.active_count ~= scheduler.table_count(surface_units))
        or (surface_units and aggregate and aggregate.network_index_ready ~= true)
        or (surface_units and not aggregate)
    then
        aggregate = rebuild_surface_aggregate(runtime, surface.index)
    end
    local total_weight = aggregate and aggregate.total_weight or 0
    local active_count = aggregate and aggregate.active_count or 0

    local crowding_state = choose_crowding_state(total_weight, profile.thresholds)
    local telemetry = build_surface_telemetry(surface, aggregate)
    local context = {
        profile_key = profile_key,
        profile = profile,
        anchor = resolve_anchor_snapshot(runtime, surface),
        total_weight = total_weight,
        active_count = active_count,
        crowding_state = crowding_state,
        crowding_percent = calculate_crowding_percent(total_weight, profile.thresholds),
        darkness = tonumber(surface.darkness) or 0,
        in_transit = is_surface_in_transit(surface),
        telemetry_key = telemetry.key,
        telemetry_ratio_by_cohort = telemetry.ratio_by_cohort,
        telemetry_ratio_by_network_cohort = telemetry.ratio_by_network_cohort,
    }

    runtime.surface_state_by_surface[surface.index] = context
    return context
end

-- Profile bias gives each world its own recovery/stress behavior on top of the
-- generic load band. It is intentionally applied after load and crowding so
-- planet flavor bends the system instead of replacing the shared rules.
local function apply_profile_instability_bias(context, record, charge_ratio, load_band_key, positive_multiplier, recovery_multiplier)
    local delta = 0

    if context.profile_key == "nauvis" then
        if charge_ratio < 0.20 and (load_band_key == "idle" or load_band_key == "light") then
            delta = delta - (2 * recovery_multiplier)
        end
    elseif context.profile_key == "fulgora" then
        if (context.darkness or 0) < 0.45 then
            if load_band_key == "working" or load_band_key == "strained" or load_band_key == "overdrive" then
                delta = delta + (2 * positive_multiplier)
            end
        elseif (context.darkness or 0) > 0.75 and (load_band_key == "idle" or load_band_key == "light") then
            delta = delta - (2 * recovery_multiplier)
        end
    elseif context.profile_key == "vulcanus" then
        if charge_ratio > 0.80 then
            delta = delta + (6 * positive_multiplier)
        end
    elseif context.profile_key == "gleba" then
        if charge_ratio < 0.25 then
            delta = delta - (8 * recovery_multiplier)
        elseif charge_ratio > 0.80 then
            delta = delta + (6 * positive_multiplier)
        end
    elseif context.profile_key == "aquilo" then
        if record.frozen then
            delta = delta - (3 * recovery_multiplier)
        elseif charge_ratio < 0.25 then
            delta = delta - (2 * recovery_multiplier)
        end
    elseif context.profile_key == "orbit" then
        if context.in_transit then
            delta = delta + (3 * positive_multiplier)
        end
    end

    return delta
end

-- The digest is the cheap "did the visible UI meaning change?" fingerprint used
-- by periodic processing. It avoids forcing all watching players to redraw when
-- a service pass only confirmed the same visible state.
local function build_periodic_ui_digest(record, entity)
    if not (record and entity_check(entity)) then
        return nil
    end

    local instability = math.floor(tonumber(record.instability) or 0)
    local intact_mining = entity.name == GAIA_NAME
        and is_gaia_surface(entity.surface)
        and instability < 25

    return table.concat({
        tostring(entity.name or ""),
        tostring(instability),
        tostring(record.last_load_band or ""),
        tostring(record.last_telemetry_key or ""),
        tostring(record.frozen == true),
        tostring(intact_mining),
    }, "|")
end

-- One record processing pass:
--   normalize Gaia special cases;
--   read charge/load/crowding/orbital/profile pressure;
--   update instability and remembered telemetry;
--   swap shells when the state wants a different visual body;
--   apply backlash once high instability is dangerous enough;
--   break to husk at terminal instability.
local function process_record(runtime, record, context, current_tick)
    local entity = ei_lib.get_valid_entity(record.entity)
    if not entity then
        unregister_record(runtime, record.unit_number)
        return nil, true
    end

    local before_ui_digest = build_periodic_ui_digest(record, entity)

    if context.profile_key == "gaia" then
        -- Gaia is the only true stable profile. It zeroes instability and forces
        -- the Gaia shell before any normal load/crowding/orbit pressure can apply.
        record.instability = 0
        record.frozen = false
        record.last_load_band = "idle"
        record.last_telemetry_key = context.telemetry_key or "strain-fallback"
        record.last_energy = tonumber(entity.energy) or 0
        if entity.name ~= GAIA_NAME then
            record = swap_live_shell(runtime, record, GAIA_NAME, current_tick, "stabilized")
            entity = record and ei_lib.get_valid_entity(record.entity) or nil
        end
        return record, before_ui_digest ~= build_periodic_ui_digest(record, entity)
    end

    if entity.name == GAIA_NAME then
        -- Gaia shells are not portable. The moment a stable shell exists outside
        -- Gaia, downgrade it before processing normal surface effects.
        record = swap_live_shell(runtime, record, BASE_NAME, current_tick, "downgraded")
        entity = record and ei_lib.get_valid_entity(record.entity) or nil
        if not entity then
            return nil, true
        end
    end

    record.quality_factor = record.quality_factor or ei_lib.get_normalized_quality_factor(entity)
    record.quality_name = record.quality_name or get_quality_name(entity)

    local charge_ratio = ei_lib.clamp((tonumber(entity.energy) or 0) / math.max(1, tonumber(entity.electric_buffer_size) or DEFAULT_BUFFER_CAPACITY), 0, 1)
    if context.profile_key == "aquilo" then
        -- Freeze-lock is an Aquilo overlay on top of normal instability. It cares
        -- about buffer starvation, not just load band, so a cold empty shell stays
        -- low-output until the buffer has meaningfully recovered.
        if charge_ratio < 0.15 then
            record.frozen = true
        elseif charge_ratio > 0.40 then
            record.frozen = false
        end
    else
        record.frozen = false
    end

    local load_ratio, telemetry_key = resolve_load_ratio(record, entity, context)
    local load_band_key, load_delta = resolve_load_band(load_ratio)
    -- Quality does not make a crystal magically stable. It softens positive
    -- stress, improves recovery, and lowers resonance weight; Gaia still owns the
    -- only absolute stability exemption.
    local positive_multiplier = 1 - (0.35 * record.quality_factor)
    local recovery_multiplier = (1 + (0.25 * record.quality_factor)) * (context.profile.recovery_multiplier or 1)
    local total_delta = 0

    if load_delta > 0 then
        total_delta = total_delta + (load_delta * (context.profile.load_multiplier or 1) * positive_multiplier)
    else
        total_delta = total_delta + (load_delta * recovery_multiplier)
    end

    local crowd_delta = CROWDING_STATES[context.crowding_state].delta or 0
    if crowd_delta > 0 then
        total_delta = total_delta + (crowd_delta * positive_multiplier)
    end

    local orbital_delta = context.anchor.extra_instability or 0
    if orbital_delta > 0 then
        total_delta = total_delta + (orbital_delta * positive_multiplier)
    end

    total_delta = total_delta + apply_profile_instability_bias(
        context,
        record,
        charge_ratio,
        load_band_key,
        positive_multiplier,
        recovery_multiplier
    )

    if context.profile_key == "aquilo" and total_delta > 0 then
        total_delta = total_delta * 0.5
    end

    -- Store integer-ish instability so UI, shell thresholds, and mining outcomes
    -- do not jitter on fractional profile math.
    record.instability = ei_lib.clamp((record.instability or 0) + math.floor(total_delta + 0.5), 0, 100)
    record.last_load_band = load_band_key
    record.last_telemetry_key = telemetry_key
    record.last_energy = tonumber(entity.energy) or 0

    local target_shell = resolve_shell_target(context, load_ratio, record)
    if target_shell and entity.name ~= target_shell then
        -- The chosen shell can change because of load, crowding, Gaia, Fulgora
        -- phase, or Aquilo freeze. swap_live_shell() returns the replacement
        -- record, so everything below must re-read entity from the new record.
        record = swap_live_shell(runtime, record, target_shell, current_tick, nil)
        entity = record and ei_lib.get_valid_entity(record.entity) or nil
        if not entity then
            return nil, true
        end
    end

    if record.instability >= 75 and (record.backlash_cooldown_until or 0) <= current_tick then
        local backlash_trigger = (context.crowding_state == "chaotic") or load_band_key == "overdrive" or load_band_key == "strained"
        if backlash_trigger then
            -- Backlash is intentionally delayed until both high instability and a
            -- triggering stress condition are present. A merely old damaged shell
            -- does not pulse forever while sitting idle.
            apply_backlash(runtime, record, context.profile_key, 1 + ((record.instability - 75) / 25), current_tick)
        end
    end

    if record.instability >= 100 then
        break_to_husk(runtime, record, current_tick, get_husk_name(record.instability or 100, true), "broken")
        return nil, true
    end

    return record, before_ui_digest ~= build_periodic_ui_digest(record, entity)
end

-- Snapshots are the read model for every user-facing surface: custom entity
-- status, relative GUI, detached screen, mod-gui strip, and repair-tool inspect
-- output. Keeping them centralized prevents UI paths from accidentally
-- recomputing state differently than the scheduler.
local function build_snapshot(runtime, entity, current_tick)
    if not is_relevant_entity(entity) then
        return nil
    end

    -- Snapshots may be requested from UI events before the next scheduled service
    -- pass has seen a newly placed shell. Register lazily so selection/opening a
    -- crystal produces a coherent readout immediately.
    local record = nil
    local unit_number = get_unit_number(entity)
    if unit_number then
        record = runtime.by_unit[unit_number]
    end
    if not record and is_live_entity(entity) then
        record = register_record(runtime, entity, current_tick, nil)
    end

    local context = build_surface_context(runtime, entity.surface, false)
    local profile_key = context.profile_key

    -- Husk snapshots intentionally reuse the same fields as live shell snapshots.
    -- That lets the GUI and inspect output stay simple: repair mode is just a
    -- different result_mode/state_key, not a separate rendering pipeline.
    local quality_factor = record and record.quality_factor or ei_lib.get_normalized_quality_factor(entity)
    local instability = record and record.instability or (HUSK_NAMES[entity.name] and 100 or 0)
    local frozen = record and record.frozen or false
    local state_key = HUSK_NAMES[entity.name] and "broken" or get_state_key(instability, frozen)
    local coherence = HUSK_NAMES[entity.name] and 0 or math.max(0, 100 - math.floor(instability + 0.5))
    local crowding_state = context.crowding_state
    local load_band = HUSK_NAMES[entity.name] and "offline" or (record and record.last_load_band or "idle")

    local lore_key = HUSK_NAMES[entity.name] and "shattered" or choose_lore_key(profile_key, state_key, crowding_state, frozen)
    local result_mode = HUSK_NAMES[entity.name] and "repair" or "mining"
    local result_key = HUSK_NAMES[entity.name]
        and (profile_key == "gaia" and "stable" or "restored")
        or ((entity.name == GAIA_NAME and is_gaia_surface(entity.surface) and instability < 25) and "intact" or "husk")

    return {
        entity = entity,
        unit_number = unit_number,
        state_key = state_key,
        profile_key = profile_key,
        coherence = coherence,
        load_band = load_band,
        telemetry_key = (record and record.last_telemetry_key) or context.telemetry_key or "strain-fallback",
        lore_key = lore_key,
        result_mode = result_mode,
        result_key = result_key,
        quality_percent = math.floor((quality_factor or 0) * 100 + 0.5),
        instability = instability,
        shell_key = get_shell_key(entity.name),
        output_text = get_output_mw_text(entity.name),
        anchor_label = context.anchor.label,
        show_anchor = entity.surface and entity.surface.platform and entity.surface.platform.valid,
        field_percent = math.floor((context.anchor.field or 0) * 100 + 0.5),
        active_count = context.active_count or 0,
        crowding_state = crowding_state,
        crowding_percent = context.crowding_percent or 0,
        is_live = LIVE_NAMES[entity.name] == true,
    }
end

local function get_entity_display_name(entity)
    if not entity_check(entity) then
        return ""
    end

    local prototype = entity.prototype
    return entity.localised_name
        or (prototype and prototype.localised_name)
        or {"entity-name." .. entity.name}
end

-- The status strip is intentionally separate from the entity-relative console.
-- It lets a player keep a compact readout while selecting or inspecting a
-- relevant entity, but it hides itself when the proper entity GUI is already
-- open and showing the richer relative panel.
local function destroy_status_strip(player)
    if not (player and player.valid) then
        return
    end

    local flow = mod_gui.get_frame_flow(player)
    local root = flow and flow[STRIP_NAME] or nil
    if root and root.valid then
        root.destroy()
    end
end

local function build_status_strip(player)
    local flow = mod_gui.get_frame_flow(player)
    local root = flow[STRIP_NAME]
    if root then
        return root
    end

    root = flow.add{
        type = "frame",
        name = STRIP_NAME,
        direction = "horizontal",
        style = "inside_shallow_frame",
    }

    local content = root.add{
        type = "flow",
        name = "content-flow",
        direction = "horizontal",
    }
    content.style.vertical_align = "center"

    content.add{
        type = "label",
        name = "summary-label",
        caption = "",
    }
    local coherence_bar = content.add{
        type = "progressbar",
        name = "coherence-bar",
        style = "ei_status_progressbar_cyan",
    }
    coherence_bar.style.minimal_width = 144
    coherence_bar.style.maximal_width = 144
    content.add{
        type = "button",
        name = "detail-button",
        caption = {"exotic-industries.crystal-accumulator-gui-detach-readout-short"},
        tooltip = {"exotic-industries.crystal-accumulator-gui-detach-readout"},
        tags = {
            parent_gui = STRIP_NAME,
            action = "open-detail",
        },
    }

    return root
end

local function add_wrapped_label(parent, name)
    local label = parent.add{type = "label", name = name, caption = ""}
    label.style.single_line = false
    label.style.maximal_width = 280
    label.style.horizontally_stretchable = true
    return label
end

-- Relative and screen consoles share the same content body. Build once into a
-- provided root and update it from snapshots; the container decides whether it is
-- anchored beside an entity GUI or detached as a movable screen frame.
local function build_console_contents(root)
    local main = root.add{type = "frame", name = "main-container", direction = "vertical", style = "inside_shallow_frame"}
    main.add{type = "frame", name = "subheader-frame", style = "ei_subheader_frame"}.add{
        type = "label",
        name = "subheader-label",
        caption = {"exotic-industries.crystal-accumulator-gui-status-title"},
        style = "subheader_caption_label",
    }

    local flow = main.add{type = "flow", name = "status-flow", direction = "vertical", style = "ei_inner_content_flow"}
    add_wrapped_label(flow, "shell-line")
    add_wrapped_label(flow, "profile-line")
    add_wrapped_label(flow, "anchor-line")
    add_wrapped_label(flow, "load-line")
    add_wrapped_label(flow, "telemetry-line")
    add_wrapped_label(flow, "resonance-line")
    add_wrapped_label(flow, "quality-line")
    add_wrapped_label(flow, "result-line")
    add_wrapped_label(flow, "lore-line")
    local coherence_bar = flow.add{type = "progressbar", name = "coherence-bar", style = "ei_status_progressbar_cyan"}
    coherence_bar.style.horizontally_stretchable = true
    coherence_bar.style.minimal_width = 260
    local field_bar = flow.add{type = "progressbar", name = "field-bar"}
    field_bar.style.horizontally_stretchable = true
    field_bar.style.minimal_width = 260

    return flow
end

-- All caption writes happen here. That keeps localisation keys and visibility
-- toggles paired with the snapshot fields they represent, and keeps the build
-- functions mostly structural.
local function update_console_contents(flow, snapshot)
    if not flow then
        return
    end

    -- The same body is used by both the relative panel and detached screen. Every
    -- line must therefore be safe for both "opened live EEI" and "selected husk"
    -- contexts, with visibility controlled by snapshot.result_mode.
    local main = flow.parent
    local subheader = main and main["subheader-frame"] and main["subheader-frame"]["subheader-label"] or nil
    local is_repair_mode = snapshot.result_mode == "repair"
    if subheader then
        if is_repair_mode then
            subheader.caption = {"exotic-industries.crystal-accumulator-shell-offline"}
        else
            subheader.caption = {"exotic-industries.crystal-accumulator-gui-status-title"}
        end
    end

    local lore_line = flow["lore-line"]
    local load_line = flow["load-line"]
    local coherence_bar = flow["coherence-bar"]
    local field_bar = flow["field-bar"]
    if not (lore_line and load_line and coherence_bar and field_bar) then
        return
    end

    lore_line.caption = {"exotic-industries.crystal-accumulator-gui-lore", {"exotic-industries.crystal-accumulator-lore-" .. snapshot.lore_key}}
    load_line.visible = not is_repair_mode
    coherence_bar.visible = not is_repair_mode
    field_bar.visible = true
    if is_repair_mode then
        flow["shell-line"].caption = {
            "",
            {"exotic-industries.crystal-accumulator-shell-offline"},
            " | ",
            {"exotic-industries.crystal-accumulator-state-" .. snapshot.state_key}
        }
    else
        -- Keep mining outcome out of the shell line. Shell is current operating
        -- form; result-line below explains what the player gets if they remove it.
        flow["shell-line"].caption = {"exotic-industries.crystal-accumulator-gui-shell", {"exotic-industries.crystal-accumulator-shell-" .. snapshot.shell_key}, snapshot.output_text}
    end
    flow["profile-line"].caption = {"exotic-industries.crystal-accumulator-gui-profile", {"exotic-industries.crystal-accumulator-profile-" .. snapshot.profile_key}}
    flow["anchor-line"].visible = snapshot.show_anchor == true
    if snapshot.show_anchor then
        flow["anchor-line"].caption = {"exotic-industries.crystal-accumulator-gui-anchor", snapshot.anchor_label}
    end
    load_line.caption = {"exotic-industries.crystal-accumulator-gui-load", {"exotic-industries.crystal-accumulator-load-" .. snapshot.load_band}}
    flow["telemetry-line"].caption = {"exotic-industries.crystal-accumulator-gui-telemetry", {"exotic-industries.crystal-accumulator-telemetry-" .. snapshot.telemetry_key}}
    flow["resonance-line"].caption = {
        "exotic-industries.crystal-accumulator-gui-resonance",
        {"exotic-industries.crystal-accumulator-crowding-" .. snapshot.crowding_state},
        snapshot.active_count
    }
    flow["quality-line"].caption = {"exotic-industries.crystal-accumulator-gui-quality", snapshot.quality_percent}
    flow["result-line"].caption = {
        "exotic-industries.crystal-accumulator-gui-result-" .. snapshot.result_mode,
        {"exotic-industries.crystal-accumulator-" .. snapshot.result_mode .. "-" .. snapshot.result_key}
    }
    coherence_bar.value = ei_lib.clamp(snapshot.coherence / 100, 0, 1)
    coherence_bar.caption = {"exotic-industries.crystal-accumulator-gui-coherence", snapshot.coherence, snapshot.instability}
    coherence_bar.tooltip = {"exotic-industries.crystal-accumulator-gui-coherence", snapshot.coherence, snapshot.instability}
    field_bar.value = ei_lib.clamp(snapshot.field_percent / 100, 0, 1)
    field_bar.caption = {"", "Field ", snapshot.field_percent, "%"}
    field_bar.tooltip = {"exotic-industries.crystal-accumulator-gui-field", snapshot.field_percent, snapshot.crowding_percent}
end

local function get_relative_root(player)
    if not (player and player.valid) then
        return nil
    end

    return player.gui.relative[RELATIVE_GUI_NAME]
end

local function get_screen_root(player)
    if not (player and player.valid) then
        return nil
    end

    return player.gui.screen[SCREEN_GUI_NAME]
end

local function destroy_relative_gui(player)
    local root = get_relative_root(player)
    if root and root.valid then
        root.destroy()
    end
end

local function destroy_screen_gui(player)
    local root = get_screen_root(player)
    if root and root.valid then
        root.destroy()
    end
end

local function clear_screen_target(runtime, player_index)
    if runtime and player_index then
        runtime.screen_entity_by_player[player_index] = nil
    end
end

local get_detached_screen_entity

-- The relative console is the "attached" view: it appears beside Factorio's
-- native entity GUI while the player has a live accumulator shell open. It
-- should feel like part of the machine rather than a separate management panel,
-- so it only owns chrome and delegates all volatile values to the shared console
-- body builder below.
local function build_relative_gui(player, entity)
    local root = get_relative_root(player)
    if root then
        root.destroy()
    end

    root = player.gui.relative.add{
        type = "frame",
        name = RELATIVE_GUI_NAME,
        anchor = {
            gui = defines.relative_gui_type.electric_energy_interface_gui,
            name = entity.name,
            position = defines.relative_gui_position.right,
        },
        tags = {
            anchor_name = entity.name,
            unit_number = get_unit_number(entity),
        },
        direction = "vertical",
    }

    local titlebar = root.add{type = "flow", name = "titlebar-flow", direction = "horizontal"}
    titlebar.add{type = "label", caption = {"exotic-industries.crystal-accumulator-gui-title"}, style = "frame_title"}
    titlebar.add{type = "empty-widget", style = "ei_titlebar_nondraggable_spacer", ignored_by_interaction = true}
    titlebar.add{
        type = "button",
        name = "detail-button",
        caption = {"exotic-industries.crystal-accumulator-gui-detach-readout-short"},
        tooltip = {"exotic-industries.crystal-accumulator-gui-detach-readout"},
        tags = {
            parent_gui = RELATIVE_GUI_NAME,
            action = "open-detail",
        },
    }
    titlebar.add{
        type = "sprite-button",
        sprite = "virtual-signal/informatron",
        tooltip = {"exotic-industries.gui-open-informatron"},
        style = "frame_action_button",
        tags = {
            parent_gui = RELATIVE_GUI_NAME,
            action = "goto-informatron",
            page = INFORMATRON_PAGE,
        },
    }

    build_console_contents(root)
    return root
end

-- The detach button doubles as a close button whenever the floating screen is
-- already showing this same unit. Keeping that state in one helper prevents the
-- relative GUI, status strip, and click handler from each inventing their own
-- interpretation of "is the detail window open?"
local function update_relative_readout_button(runtime, player, root, unit_number)
    if not (runtime and player and player.valid and root and root.valid and unit_number) then
        return
    end

    local titlebar = root["titlebar-flow"]
    local detail_button = titlebar and titlebar["detail-button"] or nil
    if not (detail_button and detail_button.valid) then
        return
    end

    local screen_entity = get_detached_screen_entity(runtime, player)
    local screen_matches = screen_entity and get_unit_number(screen_entity) == unit_number

    if screen_matches then
        detail_button.enabled = true
        detail_button.caption = {"gui.close"}
        detail_button.tooltip = {"gui.close"}
        detail_button.tags = {
            parent_gui = RELATIVE_GUI_NAME,
            action = "close-screen",
        }
    else
        detail_button.enabled = true
        detail_button.caption = {"exotic-industries.crystal-accumulator-gui-detach-readout-short"}
        detail_button.tooltip = {"exotic-industries.crystal-accumulator-gui-detach-readout"}
        detail_button.tags = {
            parent_gui = RELATIVE_GUI_NAME,
            action = "open-detail",
        }
    end
end

-- The screen console is the persistent form of the readout. It keeps its last
-- location when rebuilt so normal refresh churn does not nudge the player's UI,
-- but it still reuses the exact same content builder as the relative view.
local function build_screen_gui(player, entity)
    local root = get_screen_root(player)
    local previous_location = nil
    if root then
        local location = root.location
        if location and location.x and location.y then
            previous_location = {x = location.x, y = location.y}
        end
        root.destroy()
    end

    root = player.gui.screen.add{
        type = "frame",
        name = SCREEN_GUI_NAME,
        direction = "vertical",
        tags = {
            anchor_name = entity.name,
            unit_number = get_unit_number(entity),
        },
    }
    if previous_location then
        root.location = previous_location
    else
        root.auto_center = true
    end

    local titlebar = root.add{type = "flow", name = "titlebar-flow", direction = "horizontal"}
    titlebar.drag_target = root
    titlebar.add{
        type = "label",
        name = "title-label",
        caption = {
            "",
            {"exotic-industries.crystal-accumulator-gui-title"},
            " | ",
            get_entity_display_name(entity),
        },
        style = "frame_title",
        ignored_by_interaction = true,
    }
    local spacer = titlebar.add{type = "empty-widget", style = "ei_titlebar_draggable_spacer", ignored_by_interaction = true}
    spacer.style.horizontally_stretchable = true
    titlebar.add{
        type = "sprite-button",
        sprite = "virtual-signal/informatron",
        tooltip = {"exotic-industries.gui-open-informatron"},
        style = "frame_action_button",
        tags = {
            parent_gui = RELATIVE_GUI_NAME,
            action = "goto-informatron",
            page = INFORMATRON_PAGE,
        },
    }
    titlebar.add{
        type = "sprite-button",
        sprite = "utility/close",
        tooltip = {"gui.close"},
        style = "close_button",
        tags = {
            parent_gui = RELATIVE_GUI_NAME,
            action = "close-screen",
        },
    }

    build_console_contents(root)
    return root
end

local function update_screen_title(root, entity)
    if not (root and root.valid and entity_check(entity)) then
        return
    end

    local titlebar = root["titlebar-flow"]
    local title_label = titlebar and titlebar["title-label"] or nil
    if not (title_label and title_label.valid) then
        return
    end

    title_label.caption = {
        "",
        {"exotic-industries.crystal-accumulator-gui-title"},
        " | ",
        get_entity_display_name(entity),
    }
end

-- The status strip is intentionally treated as a fallback glance surface. When
-- a richer relative GUI is already anchored to the live machine, the strip gets
-- out of the way; when the player is looking at a husk or detached readout, it
-- can summarize the same snapshot without opening another full panel.
local function update_status_strip(runtime, player, snapshot)
    if not snapshot then
        destroy_status_strip(player)
        return
    end

    local opened_entity = ei_lib.get_valid_entity(player and player.opened)
    local live_window_matches = snapshot.is_live
        and opened_entity
        and is_live_entity(opened_entity)
        and get_unit_number(opened_entity) == snapshot.unit_number
    if live_window_matches then
        local relative_root = get_relative_root(player)
        local relative_matches = relative_root
            and relative_root.valid
            and relative_root.tags
            and relative_root.tags.unit_number == snapshot.unit_number
        if relative_matches then
            destroy_status_strip(player)
            return
        end
    end

    local root = build_status_strip(player)
    local content = root["content-flow"]
    local label = content and content["summary-label"] or nil
    local coherence_bar = content and content["coherence-bar"] or nil
    local detail_button = content and content["detail-button"] or nil
    if not (label and coherence_bar) then
        return
    end

    if detail_button then
        local screen_entity = get_detached_screen_entity(runtime, player)
        local screen_matches = screen_entity and get_unit_number(screen_entity) == snapshot.unit_number
        if live_window_matches then
            detail_button.visible = false
        elseif screen_matches then
            detail_button.visible = true
            detail_button.enabled = true
            detail_button.caption = {"gui.close"}
            detail_button.tooltip = {"gui.close"}
            detail_button.tags = {
                parent_gui = STRIP_NAME,
                action = "close-screen",
            }
        else
            detail_button.visible = true
            detail_button.enabled = true
            detail_button.caption = {"exotic-industries.crystal-accumulator-gui-detach-readout-short"}
            detail_button.tooltip = {"exotic-industries.crystal-accumulator-gui-detach-readout"}
            detail_button.tags = {
                parent_gui = STRIP_NAME,
                action = "open-detail",
            }
        end
    end

    coherence_bar.visible = snapshot.result_mode ~= "repair"
    if snapshot.result_mode == "repair" then
        label.caption = {
            "",
            {"exotic-industries.crystal-accumulator-shell-offline"},
            " | ",
            {"exotic-industries.crystal-accumulator-profile-" .. snapshot.profile_key},
            " | ",
            {"exotic-industries.crystal-accumulator-repair-" .. snapshot.result_key}
        }
    else
        label.caption = {
            "",
            {"exotic-industries.crystal-accumulator-strip-summary",
                {"exotic-industries.crystal-accumulator-shell-" .. snapshot.shell_key},
                snapshot.output_text,
                {"exotic-industries.crystal-accumulator-load-" .. snapshot.load_band}
            },
            " | ",
            {"exotic-industries.crystal-accumulator-mining-" .. snapshot.result_key}
        }
    end
    if coherence_bar.visible then
        coherence_bar.value = ei_lib.clamp(snapshot.coherence / 100, 0, 1)
        coherence_bar.caption = {"exotic-industries.crystal-accumulator-gui-coherence", snapshot.coherence, snapshot.instability}
    end
    if snapshot.result_mode == "repair" then
        root.tooltip = {
            "",
            {"exotic-industries.crystal-accumulator-shell-offline"},
            " | ",
            {"exotic-industries.crystal-accumulator-state-" .. snapshot.state_key},
            "\n",
            {"exotic-industries.crystal-accumulator-gui-profile", {"exotic-industries.crystal-accumulator-profile-" .. snapshot.profile_key}},
            snapshot.show_anchor and "\n" or "",
            snapshot.show_anchor and {"exotic-industries.crystal-accumulator-gui-anchor", snapshot.anchor_label} or "",
            snapshot.show_anchor and "\n" or "",
            {"exotic-industries.crystal-accumulator-gui-telemetry", {"exotic-industries.crystal-accumulator-telemetry-" .. snapshot.telemetry_key}},
            "\n",
            {"exotic-industries.crystal-accumulator-gui-resonance", {"exotic-industries.crystal-accumulator-crowding-" .. snapshot.crowding_state}, snapshot.active_count},
            "\n",
            {"exotic-industries.crystal-accumulator-gui-field", snapshot.field_percent, snapshot.crowding_percent},
            "\n",
            {"exotic-industries.crystal-accumulator-gui-quality", snapshot.quality_percent},
            "\n",
            {"exotic-industries.crystal-accumulator-gui-result-repair", {"exotic-industries.crystal-accumulator-repair-" .. snapshot.result_key}},
            "\n",
            {"exotic-industries.crystal-accumulator-gui-lore", {"exotic-industries.crystal-accumulator-lore-" .. snapshot.lore_key}},
            "\n",
            {"exotic-industries.crystal-accumulator-gui-inspect-hint"},
        }
    else
        root.tooltip = {
            "",
            {"exotic-industries.crystal-accumulator-gui-shell", {"exotic-industries.crystal-accumulator-shell-" .. snapshot.shell_key}, snapshot.output_text},
            "\n",
            {"exotic-industries.crystal-accumulator-gui-profile", {"exotic-industries.crystal-accumulator-profile-" .. snapshot.profile_key}},
            snapshot.show_anchor and "\n" or "",
            snapshot.show_anchor and {"exotic-industries.crystal-accumulator-gui-anchor", snapshot.anchor_label} or "",
            snapshot.show_anchor and "\n" or "",
            {"exotic-industries.crystal-accumulator-gui-load", {"exotic-industries.crystal-accumulator-load-" .. snapshot.load_band}},
            "\n",
            {"exotic-industries.crystal-accumulator-gui-telemetry", {"exotic-industries.crystal-accumulator-telemetry-" .. snapshot.telemetry_key}},
            "\n",
            {"exotic-industries.crystal-accumulator-gui-field", snapshot.field_percent, snapshot.crowding_percent},
            "\n",
            {"exotic-industries.crystal-accumulator-gui-quality", snapshot.quality_percent},
            "\n",
            {"exotic-industries.crystal-accumulator-gui-result-mining", {"exotic-industries.crystal-accumulator-mining-" .. snapshot.result_key}},
            "\n",
            {"exotic-industries.crystal-accumulator-gui-lore", {"exotic-industries.crystal-accumulator-lore-" .. snapshot.lore_key}},
            "\n",
            {"exotic-industries.crystal-accumulator-gui-inspect-hint"},
        }
    end
end

-- This function reconciles the actual GUI topology for a single player against
-- the snapshot chosen by refresh_player_ui(). It decides whether the readout
-- belongs beside an open live shell, in a detached screen window, or nowhere at
-- all; the surrounding render-signature logic handles skipping this work when
-- the same topology is already present.
local function update_detail_gui(runtime, player, snapshot, allow_screen)
    if not snapshot then
        clear_screen_target(runtime, player and player.valid and player.index or nil)
        destroy_relative_gui(player)
        destroy_screen_gui(player)
        return
    end

    local opened_entity = ei_lib.get_valid_entity(player and player.opened)
    if snapshot.is_live and opened_entity and is_live_entity(opened_entity) then
        local root = get_relative_root(player)
        if not root or not (
            root.tags
            and root.tags.anchor_name == snapshot.entity.name
            and root.tags.unit_number == snapshot.unit_number
        ) then
            root = build_relative_gui(player, snapshot.entity)
        end

        local flow = root and root["main-container"] and root["main-container"]["status-flow"] or nil
        update_console_contents(flow, snapshot)
        if allow_screen == false then
            clear_screen_target(runtime, player.index)
            destroy_screen_gui(player)
            update_relative_readout_button(runtime, player, root, snapshot.unit_number)
            return
        end

        local screen_root = get_screen_root(player)
        if not screen_root or not (
            screen_root.tags
            and screen_root.tags.anchor_name == snapshot.entity.name
            and screen_root.tags.unit_number == snapshot.unit_number
        ) then
            screen_root = build_screen_gui(player, snapshot.entity)
        end

        update_screen_title(screen_root, snapshot.entity)
        local screen_flow = screen_root and screen_root["main-container"] and screen_root["main-container"]["status-flow"] or nil
        update_console_contents(screen_flow, snapshot)
        if runtime and player and player.valid then
            runtime.screen_requested_by_player[player.index] = nil
            runtime.screen_entity_by_player[player.index] = snapshot.entity
        end
        update_relative_readout_button(runtime, player, root, snapshot.unit_number)
        return
    end

    destroy_relative_gui(player)
    if allow_screen == false then
        clear_screen_target(runtime, player.index)
        destroy_screen_gui(player)
        return
    end
    local root = get_screen_root(player)
    if not root or not (
        root.tags
        and root.tags.anchor_name == snapshot.entity.name
        and root.tags.unit_number == snapshot.unit_number
    ) then
        root = build_screen_gui(player, snapshot.entity)
    end

    update_screen_title(root, snapshot.entity)
    local flow = root and root["main-container"] and root["main-container"]["status-flow"] or nil
    update_console_contents(flow, snapshot)
    if runtime and player and player.valid then
        runtime.screen_requested_by_player[player.index] = nil
        runtime.screen_entity_by_player[player.index] = snapshot.entity
    end
end

-- Closing the detached screen is remembered per player and unit so the normal
-- refresh pass does not immediately reopen it just because the entity is still
-- selected or recently opened.
local function dismiss_screen_for_player(runtime, player, entity)
    if not (runtime and player and player.valid) then
        return
    end

    local detached_entity = get_detached_screen_entity(runtime, player)
    local target_entity = detached_entity or entity
    runtime.screen_dismissed_by_player[player.index] = target_entity and get_unit_number(target_entity) or false
    runtime.screen_requested_by_player[player.index] = nil
    clear_screen_target(runtime, player.index)
    destroy_screen_gui(player)
end

-- This is the cheap "should we keep caring about this player?" predicate. It
-- counts both explicit watches and physical GUI roots, which lets cleanup recover
-- from edge cases such as mod reloads, stale selections, or screen windows that
-- survived longer than their watch registration.
local function player_has_active_crystal_ui(runtime, player)
    if not (player and player.valid) then
        return false
    end

    local player_index = player.index
    return runtime.watch_by_player[player_index] ~= nil
        or runtime.open_by_player[player_index] ~= nil
        or runtime.ui_pending_by_player[player_index] ~= nil
        or get_relative_root(player) ~= nil
        or get_screen_root(player) ~= nil
        or (mod_gui.get_frame_flow(player) and mod_gui.get_frame_flow(player)[STRIP_NAME] ~= nil)
end

-- Detached detail screens are opt-in unless the machine is a husk. Live shells
-- already get the anchored relative readout, so reopening a screen after the
-- player dismissed it would feel like the machine arguing with them.
local function should_allow_screen_detail(runtime, player, snapshot)
    if not (runtime and player and player.valid and snapshot and snapshot.unit_number) then
        return false
    end

    local unit_number = snapshot.unit_number
    if runtime.screen_dismissed_by_player[player.index] == unit_number then
        return false
    end

    local screen_entity = get_detached_screen_entity(runtime, player)
    if screen_entity and get_unit_number(screen_entity) == unit_number then
        return true
    end

    if runtime.screen_requested_by_player[player.index] == unit_number then
        return true
    end

    local has_other_detached_screen = screen_entity and get_unit_number(screen_entity) ~= unit_number

    local opened = ei_lib.get_valid_entity(player.opened)
    if opened and get_unit_number(opened) == unit_number and not is_live_entity(opened) then
        return not has_other_detached_screen
    end

    local selected = ei_lib.get_valid_entity(player.selected)
    if selected and get_unit_number(selected) == unit_number and not snapshot.is_live then
        return not has_other_detached_screen
    end

    return false
end

-- Event handlers call this instead of forcing immediate GUI work. The delayed UI
-- queue absorbs rapid selection/open/close churn and allows control.lua to drain
-- refreshes through the module's normal service_ui() gate.
local function queue_player_ui_if_relevant(runtime, player_index, current_tick)
    if not player_index then
        return
    end

    local player = game and game.get_player(player_index) or nil
    if not (player and player.valid) then
        return
    end

    local opened = ei_lib.get_valid_entity(player.opened)
    local selected = ei_lib.get_valid_entity(player.selected)
    local entity = is_relevant_entity(opened) and opened or (is_relevant_entity(selected) and selected or nil)
    if entity then
        set_entity_custom_status(entity, build_snapshot(runtime, entity, current_tick))
    end
    if entity or player_has_active_crystal_ui(runtime, player) then
        queue_ui_refresh(runtime, player_index, current_tick)
    end
end

-- Prefer the entity GUI target over selection. Selection changes are frequent
-- and fuzzy; an opened entity is a much stronger statement that the player wants
-- the detailed readout for that specific accumulator.
local function get_relevant_entity_for_player(player)
    if not (player and player.valid) then
        return nil
    end

    local opened = ei_lib.get_valid_entity(player.opened)
    if is_relevant_entity(opened) then
        return opened
    end

    local selected = ei_lib.get_valid_entity(player.selected)
    if is_relevant_entity(selected) then
        return selected
    end

    return nil
end

-- A detached screen stores a unit number in GUI tags, but the canonical entity
-- reference still lives in runtime state. This resolver repairs either side when
-- possible and clears both when the unit disappeared.
get_detached_screen_entity = function(runtime, player)
    if not (runtime and player and player.valid) then
        return nil
    end

    local root = get_screen_root(player)
    if not root then
        clear_screen_target(runtime, player.index)
        return nil
    end

    local unit_number = root.tags and root.tags.unit_number or nil
    local stored_entity = ei_lib.get_valid_entity(runtime.screen_entity_by_player[player.index])
    if stored_entity and is_relevant_entity(stored_entity) then
        local stored_unit_number = get_unit_number(stored_entity)
        if not unit_number or stored_unit_number == unit_number then
            return stored_entity
        end
    end

    local record = unit_number and runtime.by_unit[unit_number] or nil
    local record_entity = record and ei_lib.get_valid_entity(record.entity) or nil
    if record_entity and is_relevant_entity(record_entity) then
        runtime.screen_entity_by_player[player.index] = record_entity
        return record_entity
    end

    clear_screen_target(runtime, player.index)
    return nil
end

local function get_gui_root_unit_number(root)
    if not (root and root.valid and root.tags) then
        return nil
    end

    return tonumber(root.tags.unit_number) or root.tags.unit_number
end

local function get_strip_render_mode(runtime, player, snapshot)
    -- The old mod_gui strip is intentionally suppressed. The entity custom_status
    -- now carries the compact tooltip/status line, while relative and detached
    -- panels carry the detailed readout. Keep this as a single policy switch in
    -- case the strip comes back later.
    return "hidden"
end

local function get_detail_render_mode(player, snapshot, detached_only, allow_screen)
    if not (player and player.valid and snapshot and snapshot.unit_number) then
        return "none"
    end

    if detached_only then
        return "screen-only"
    end

    local opened_entity = ei_lib.get_valid_entity(player.opened)
    local live_window_matches = snapshot.is_live
        and opened_entity
        and is_live_entity(opened_entity)
        and get_unit_number(opened_entity) == snapshot.unit_number
    if live_window_matches then
        -- Live shells prefer relative UI anchored beside Factorio's native EEI
        -- window. A detached screen is additive only when explicitly requested.
        return allow_screen and "relative+screen" or "relative-only"
    end

    -- Husk/selection-only views have no useful native window anchor, so the
    -- detached screen is the least surprising detailed UI.
    return allow_screen and "screen-only" or "none"
end

-- The render signature is a compact fingerprint of every value that can change
-- visible UI text, bars, or topology. If it matches and the expected roots still
-- exist, refresh_player_ui() can skip rebuilding the console entirely.
local function build_ui_render_signature(runtime, player, snapshot, detached_only, allow_screen)
    if not snapshot then
        return nil
    end

    local detail_mode = get_detail_render_mode(player, snapshot, detached_only, allow_screen)
    local strip_mode = detached_only and "hidden" or get_strip_render_mode(runtime, player, snapshot)
    local surface = snapshot.entity and snapshot.entity.surface or nil
    local surface_name = surface and surface.name or ""

    return table.concat({
        tostring(snapshot.unit_number or 0),
        tostring(snapshot.state_key or ""),
        tostring(snapshot.profile_key or ""),
        tostring(snapshot.coherence or 0),
        tostring(snapshot.load_band or ""),
        tostring(snapshot.telemetry_key or ""),
        tostring(snapshot.lore_key or ""),
        tostring(snapshot.result_mode or ""),
        tostring(snapshot.result_key or ""),
        tostring(snapshot.quality_percent or 0),
        tostring(snapshot.instability or 0),
        tostring(snapshot.shell_key or ""),
        tostring(snapshot.output_text or ""),
        tostring(snapshot.show_anchor == true),
        tostring(snapshot.field_percent or 0),
        tostring(snapshot.active_count or 0),
        tostring(snapshot.crowding_state or ""),
        tostring(snapshot.crowding_percent or 0),
        tostring(detached_only == true),
        tostring(allow_screen == true),
        strip_mode,
        detail_mode,
        surface_name,
    }, "|")
end

-- Signatures only prove that the content would be identical; they do not prove
-- that the player's GUI tree still has the right roots. This topology check is
-- the structural half of the no-op refresh test.
local function ui_topology_matches(runtime, player, snapshot, detached_only, allow_screen)
    if not (runtime and player and player.valid and snapshot and snapshot.unit_number) then
        return false
    end

    local unit_number = snapshot.unit_number
    local strip_root = mod_gui.get_frame_flow(player)[STRIP_NAME]
    local relative_unit_number = get_gui_root_unit_number(get_relative_root(player))
    local screen_unit_number = get_gui_root_unit_number(get_screen_root(player))
    local strip_mode = detached_only and "hidden" or get_strip_render_mode(runtime, player, snapshot)
    local detail_mode = get_detail_render_mode(player, snapshot, detached_only, allow_screen)

    -- Match actual roots, not just desired mode. Factorio may close a native GUI
    -- root underneath us, and another mod can change the relative/screen tree.
    if strip_mode == "hidden" then
        if strip_root then
            return false
        end
    elseif not strip_root then
        return false
    end

    if detail_mode == "screen-only" then
        return relative_unit_number == nil and screen_unit_number == unit_number
    end
    if detail_mode == "relative-only" then
        return relative_unit_number == unit_number and screen_unit_number == nil
    end
    if detail_mode == "relative+screen" then
        return relative_unit_number == unit_number and screen_unit_number == unit_number
    end

    return relative_unit_number == nil and screen_unit_number == nil
end

-- Open live shells are tracked separately from selected/watched entities so
-- anchored GUI behavior can follow Factorio's native open/close events rather
-- than guessing from selection alone.
local function sync_opened_live_shell(runtime, player_index, player)
    local opened = ei_lib.get_valid_entity(player and player.opened)
    if opened and is_live_entity(opened) then
        runtime.open_by_player[player_index] = get_unit_number(opened)
        return opened
    end

    runtime.open_by_player[player_index] = nil
    return nil
end

-- Player UI refresh is intentionally snapshot-first. It selects one relevant
-- entity, builds one read model, updates the entity's custom status, and then
-- lets render signatures decide whether actual GUI mutation is necessary.
local function refresh_player_ui(runtime, player_index, current_tick)
    local player = game and game.get_player(player_index) or nil
    if not (player and player.valid) then
        clear_player_watch(runtime, player_index)
        runtime.open_by_player[player_index] = nil
        runtime.ui_next_allowed_tick[player_index] = nil
        runtime.ui_render_signature_by_player[player_index] = nil
        runtime.screen_dismissed_by_player[player_index] = nil
        runtime.screen_requested_by_player[player_index] = nil
        clear_screen_target(runtime, player_index)
        return
    end

    local entity = get_relevant_entity_for_player(player)
    local detached_only = false
    if not entity then
        -- If the player is no longer looking at a relevant entity, a detached
        -- screen may still be valid. In that mode the screen becomes the sole UI
        -- owner and the relative/strip roots are forced closed.
        entity = get_detached_screen_entity(runtime, player)
        if entity then
            detached_only = true
            destroy_status_strip(player)
            destroy_relative_gui(player)
        else
            clear_player_watch(runtime, player_index)
            runtime.open_by_player[player_index] = nil
            runtime.ui_next_allowed_tick[player_index] = nil
            runtime.ui_render_signature_by_player[player_index] = nil
            runtime.screen_dismissed_by_player[player_index] = nil
            runtime.screen_requested_by_player[player_index] = nil
            clear_screen_target(runtime, player_index)
            destroy_status_strip(player)
            destroy_relative_gui(player)
            destroy_screen_gui(player)
            return
        end
    end

    if is_live_entity(entity) then
        -- A live entity can reach the UI path before the normal build hook after
        -- unusual cloning/scripted placement flows. Registering defensively here
        -- keeps the readout useful instead of showing an inert shell.
        local unit_number = get_unit_number(entity)
        if unit_number and not runtime.by_unit[unit_number] then
            register_record(runtime, entity, current_tick, nil)
        end
    end

    local current_unit_number = get_unit_number(entity)
    if not detached_only and runtime.screen_requested_by_player[player_index] ~= current_unit_number then
        runtime.screen_requested_by_player[player_index] = nil
    end
    if runtime.screen_dismissed_by_player[player_index] ~= current_unit_number then
        runtime.screen_dismissed_by_player[player_index] = nil
    end

    local snapshot = build_snapshot(runtime, entity, current_tick)
    -- Factorio's custom status is updated from the same snapshot as the GUI so
    -- entity hover text, detached screens, and inspection output cannot disagree.
    set_entity_custom_status(entity, snapshot)
    set_player_watch(runtime, player_index, entity.surface.index, get_unit_number(entity))
    runtime.ui_next_allowed_tick[player_index] = current_tick + UI_REFRESH_INTERVAL_TICKS

    if sync_opened_live_shell(runtime, player_index, player) then
        runtime.screen_dismissed_by_player[player_index] = nil
        runtime.screen_requested_by_player[player_index] = nil
    end

    local allow_screen = detached_only or should_allow_screen_detail(runtime, player, snapshot)
    local render_signature = build_ui_render_signature(runtime, player, snapshot, detached_only, allow_screen)
    -- Most queued UI refreshes should end here. The signature/topology pair makes
    -- repeated selection events cheap while still repairing roots that were
    -- destroyed externally.
    if render_signature
        and runtime.ui_render_signature_by_player[player_index] == render_signature
        and ui_topology_matches(runtime, player, snapshot, detached_only, allow_screen)
    then
        return
    end

    if detached_only then
        destroy_status_strip(player)
        update_detail_gui(runtime, player, snapshot, true)
        runtime.ui_render_signature_by_player[player_index] = render_signature
        return
    end

    destroy_status_strip(player)
    update_detail_gui(runtime, player, snapshot, allow_screen)
    runtime.ui_render_signature_by_player[player_index] = render_signature
end

-- Entity GUI open events are promoted into the detached screen flow. This keeps
-- the accumulator readout visible even though the live shell is implemented as
-- electric-energy-interface variants rather than a bespoke GUI-capable machine.
local function open_primary_screen_gui(runtime, player, entity, current_tick)
    if not (runtime and player and player.valid and is_relevant_entity(entity)) then
        return
    end

    local snapshot = build_snapshot(runtime, entity, current_tick)
    if not snapshot then
        return
    end

    destroy_status_strip(player)
    destroy_relative_gui(player)

    local root = build_screen_gui(player, snapshot.entity)
    update_screen_title(root, snapshot.entity)
    local flow = root and root["main-container"] and root["main-container"]["status-flow"] or nil
    update_console_contents(flow, snapshot)

    runtime.open_by_player[player.index] = snapshot.unit_number
    runtime.screen_requested_by_player[player.index] = nil
    runtime.screen_dismissed_by_player[player.index] = nil
    runtime.screen_entity_by_player[player.index] = snapshot.entity
    runtime.ui_render_signature_by_player[player.index] = nil
    player.opened = root
end

-- Full UI rebuild is only used after runtime reconstruction. It destroys stale
-- roots first, then queues normal per-player refreshes so the same throttled
-- path restores whatever the player is legitimately watching.
local function rebuild_player_ui(runtime, current_tick)
    for _, player in pairs(game and game.players or {}) do
        if player and player.valid then
            destroy_status_strip(player)
            destroy_relative_gui(player)
            destroy_screen_gui(player)
            clear_player_watch(runtime, player.index)
            runtime.open_by_player[player.index] = nil
            runtime.ui_pending_by_player[player.index] = nil
            runtime.ui_next_allowed_tick[player.index] = nil
            runtime.ui_render_signature_by_player[player.index] = nil
            runtime.screen_dismissed_by_player[player.index] = nil
            runtime.screen_requested_by_player[player.index] = nil
            queue_ui_refresh(runtime, player.index, current_tick)
        end
    end
end

-- Debug/status export is deliberately low cadence. The scheduler status panel
-- should expose enough counters to prove the module is asleep when idle without
-- turning status reporting into another source of periodic work.
local function update_runtime_status(runtime, current_tick)
    current_tick = tonumber(current_tick) or 0
    if current_tick > 0 and runtime.last_status_tick > 0 and current_tick < (runtime.last_status_tick + STATUS_UPDATE_INTERVAL_TICKS) then
        return
    end

    runtime.last_status_tick = current_tick
    scheduler.set_module_status(MODULE_NAME, {
        tick = current_tick,
        live_crystals = runtime.live_crystal_count or 0,
        active_surfaces = runtime.active_surface_count or 0,
        queued_surfaces = get_surface_queue_count(runtime),
        due_surfaces = runtime.due_surface_count or 0,
        next_surface_due_tick = runtime.next_surface_due_tick or 0,
        watched_players = runtime.watched_player_count or 0,
    })
end

function model.check_global()
    return get_runtime()
end

-- Runtime rebuild is the expensive repair path for init/config changes and save
-- migrations. It recreates scheduler-owned queues from live world state instead
-- of trusting serialized helper tables that may have changed shape between mod
-- versions.
function model.rebuild_runtime_state(reason, current_tick)
    local runtime = build_runtime()
    storage.ei = storage.ei or {}
    storage.ei.crystal_accumulator = runtime

    for _, surface in pairs(game and game.surfaces or {}) do
        for _, entity in ipairs(surface.find_entities_filtered{name = LIVE_NAME_LIST}) do
            register_record(runtime, entity, current_tick or 0, nil)
        end
    end

    rebuild_player_ui(runtime, current_tick or 0)
    runtime.last_status_tick = 0
    update_runtime_status(runtime, current_tick or 0)
    local status = scheduler.get_module_status(MODULE_NAME)
    status.rebuild_reason = reason
    scheduler.set_module_status(MODULE_NAME, status)
    return runtime
end

-- control.lua asks for pending work before spending a tick budget here. Activating
-- due surfaces first keeps delayed buckets as the sleep structure while the queue
-- remains the small, immediate work list.
function model.get_pending_work_count(event)
    local runtime = get_runtime()
    local current_tick = now_tick(event)
    activate_due_surfaces(runtime, current_tick)
    return get_surface_queue_count(runtime)
end

-- Main simulation service loop. It processes whole surfaces rather than isolated
-- entities so each pass can build one shared telemetry context, update every
-- accumulator on that surface against the same readings, then schedule the next
-- wakeup only if any units remain.
function model.update(limit, event)
    if type(limit) == "table" and event == nil then
        event = limit
        limit = 1
    end

    local runtime = get_runtime()
    local current_tick = now_tick(event)
    limit = math.max(1, tonumber(limit) or 1)

    activate_due_surfaces(runtime, current_tick)

    local processed = 0
    while processed < limit do
        local surface_index = scheduler.queue_pop_queued(runtime.surface_queue)
        if not surface_index then
            break
        end
        runtime.surface_queue_count = math.max(0, runtime.surface_queue_count - 1)

        local surface_units = runtime.units_by_surface[surface_index]
        if surface_units and next(surface_units) ~= nil then
            local surface = game and game.get_surface(surface_index) or nil
            if surface and surface.valid then
                -- Copy keys into scratch arrays before processing. Records may be
                -- swapped, removed, or re-registered during this pass, so iterating
                -- the live membership table directly would make the loop sensitive
                -- to mutation order.
                local unit_numbers = clear_scratch_array(runtime.scratch_unit_numbers)
                local dirty_unit_numbers = clear_scratch_array(runtime.scratch_dirty_unit_numbers)
                for unit_number in pairs(surface_units) do
                    unit_numbers[#unit_numbers + 1] = unit_number
                end

                -- One context read feeds every accumulator on the surface. If a
                -- record mutation invalidates the aggregate, the pass rebuilds the
                -- context lazily instead of preemptively doing extra work.
                local context = build_surface_context(runtime, surface, true)
                local surface_ui_dirty = false
                local surface_context_dirty = false
                for _, unit_number in ipairs(unit_numbers) do
                    if runtime.surface_state_by_surface[surface_index] == nil then
                        -- A previous unit in this same pass may have swapped shell,
                        -- broken, or been unregistered. Rebuild before the next unit
                        -- so later records do not use stale crowding/telemetry data.
                        context = build_surface_context(runtime, surface, true)
                    end
                    local record = runtime.by_unit[unit_number]
                    if record then
                        local updated_record, ui_changed = process_record(runtime, record, context, current_tick)
                        surface_ui_dirty = surface_ui_dirty or ui_changed == true
                        if ui_changed == true then
                            dirty_unit_numbers[#dirty_unit_numbers + 1] = updated_record and updated_record.unit_number or unit_number
                        end
                        if runtime.surface_state_by_surface[surface_index] == nil then
                            surface_context_dirty = true
                        end
                    else
                        surface_units[unit_number] = nil
                        surface_context_dirty = true
                    end
                end

                if runtime.units_by_surface[surface_index] and next(runtime.units_by_surface[surface_index]) ~= nil then
                    if runtime.surface_state_by_surface[surface_index] == nil then
                        build_surface_context(runtime, surface, true)
                    end
                    -- Reschedule only while live shells remain. Empty surfaces drop
                    -- out of all periodic work until a build/repair event wakes them.
                    schedule_surface(runtime, surface_index, current_tick + SERVICE_INTERVAL_TICKS)
                else
                    runtime.surface_state_by_surface[surface_index] = nil
                end
                -- Viewers on moving platforms need periodic field text even when a
                -- single unit did not visibly change. Static surfaces can take the
                -- cheaper path and refresh only players watching dirty units.
                if surface.platform and surface.platform.valid then
                    queue_surface_viewers(runtime, surface_index, current_tick, "periodic")
                elseif surface_context_dirty then
                    queue_surface_viewers(runtime, surface_index, current_tick, "periodic")
                elseif surface_ui_dirty then
                    queue_unit_viewers(runtime, dirty_unit_numbers, current_tick)
                end
                processed = processed + 1
            else
                -- Surface deletion is rare but nasty if left half-cleaned. Remove
                -- every unit/watch/proxy of UI state tied to the dead surface, then
                -- let stale delayed bucket entries fall out through their
                -- authoritative due maps.
                local stale_units = clear_scratch_array(runtime.scratch_stale_units)
                for unit_number in pairs(surface_units) do
                    stale_units[#stale_units + 1] = unit_number
                end
                for _, unit_number in ipairs(stale_units) do
                    if runtime.by_unit[unit_number] then
                        unregister_record(runtime, unit_number)
                    end
                end

                local watchers = runtime.watchers_by_surface[surface_index]
                if watchers then
                    local player_indexes = clear_scratch_array(runtime.scratch_player_indexes)
                    for player_index in pairs(watchers) do
                        player_indexes[#player_indexes + 1] = player_index
                    end
                    for _, player_index in ipairs(player_indexes) do
                        clear_player_watch(runtime, player_index)
                        runtime.ui_pending_by_player[player_index] = nil
                        runtime.ui_next_allowed_tick[player_index] = nil
                        runtime.ui_render_signature_by_player[player_index] = nil
                        runtime.screen_dismissed_by_player[player_index] = nil
                        runtime.screen_requested_by_player[player_index] = nil
                        clear_screen_target(runtime, player_index)
                        local player = game and game.get_player(player_index) or nil
                        if player and player.valid then
                            destroy_status_strip(player)
                            destroy_relative_gui(player)
                            destroy_screen_gui(player)
                        end
                    end
                end

                local removed_due_tick = runtime.surface_due_tick_by_surface[surface_index]
                local surface_still_registered = runtime.units_by_surface[surface_index] ~= nil
                runtime.units_by_surface[surface_index] = nil
                if surface_still_registered then
                    runtime.active_surface_count = math.max(0, runtime.active_surface_count - 1)
                end
                runtime.surface_due_tick_by_surface[surface_index] = nil
                runtime.surface_state_by_surface[surface_index] = nil
                runtime.surface_aggregate_by_surface[surface_index] = nil
                if removed_due_tick then
                    runtime.due_surface_count = math.max(0, runtime.due_surface_count - 1)
                end
                if removed_due_tick and runtime.next_surface_due_tick == removed_due_tick and not runtime.surface_due_buckets[removed_due_tick] then
                    advance_surface_due_frontier(runtime)
                end
            end
        end
    end

    update_runtime_status(runtime, current_tick)
    return processed, get_surface_queue_count(runtime)
end

-- UI service is intentionally separate from simulation service. Player-facing
-- refreshes wake on their own delayed buckets, which keeps opening/selection churn
-- from forcing accumulator physics work and keeps idle worlds at zero UI cadence.
function model.service_ui(event)
    local current_tick = now_tick(event)
    local next_ui_due_tick = get_next_ui_due_tick()
    if next_ui_due_tick == 0 or current_tick < next_ui_due_tick then
        return
    end

    local runtime = get_runtime()
    for _, player_index in ipairs(scheduler.delayed_take_due(runtime.ui_due_buckets, current_tick)) do
        local pending_tick = runtime.ui_pending_by_player[player_index]
        if pending_tick and pending_tick <= current_tick then
            runtime.ui_pending_by_player[player_index] = nil
            refresh_player_ui(runtime, player_index, current_tick)
        end
    end
    recalculate_next_ui_due_tick(runtime)
end

function model.get_next_ui_due_tick()
    return get_next_ui_due_tick()
end

-- Build handling is the narrow entrance for new live shells. Registration creates
-- the durable runtime record first, then immediately reconciles Gaia/base variants
-- so the placed entity matches the surface's profile rules from the first tick.
function model.on_built_entity(event_or_entity)
    local entity = event_or_entity and event_or_entity.entity or event_or_entity
    if not is_live_entity(entity) then
        return
    end

    local runtime = get_runtime()
    local current_tick = now_tick(event_or_entity)
    local record = register_record(runtime, entity, current_tick, nil)
    if record then
        local surface_profile_key = get_surface_profile(entity.surface)
        if surface_profile_key == "gaia" and entity.name ~= GAIA_NAME then
            swap_live_shell(runtime, record, GAIA_NAME, current_tick, "stabilized")
        elseif surface_profile_key ~= "gaia" and entity.name == GAIA_NAME then
            swap_live_shell(runtime, record, BASE_NAME, current_tick, "downgraded")
        end
    end
end

-- Repairing a husk is equivalent to reintroducing a live shell, but with a clean
-- instability state. The profile reconciliation is repeated because the surface
-- may now demand a different shell than the item that came out of the repair.
function model.on_repaired_entity(entity, event)
    if not is_live_entity(entity) then
        return
    end

    local current_tick = now_tick(event)
    local runtime = get_runtime()
    local record = register_record(runtime, entity, current_tick, {
        instability = 0,
        last_load_band = "idle",
        backlash_cooldown_until = 0,
        frozen = false,
        last_energy = tonumber(entity.energy) or 0,
    })

    if record then
        show_flying_text(entity.surface, entity.position, "crystal-accumulator-floating-repaired")
        local profile_key = get_surface_profile(entity.surface)
        if profile_key == "gaia" and entity.name ~= GAIA_NAME then
            swap_live_shell(runtime, record, GAIA_NAME, current_tick, "stabilized")
        elseif profile_key ~= "gaia" and entity.name == GAIA_NAME then
            swap_live_shell(runtime, record, BASE_NAME, current_tick, "downgraded")
        end
    end
end

-- Destroy handling covers both final removal and the pre-mining half of the
-- Factorio mining lifecycle. Pre-mine events snapshot item/quality/buffer intent;
-- actual item replacement waits for the mined event where the buffer exists.
function model.on_destroyed_entity(event)
    local entity = event and event.entity or event
    if not is_relevant_entity(entity) then
        return
    end

    local runtime = get_runtime()
    local current_tick = now_tick(event)
    queue_surface_viewers(runtime, entity.surface.index, current_tick)

    if is_live_entity(entity) then
        local unit_number = get_unit_number(entity)
        local record = unit_number and runtime.by_unit[unit_number] or nil
        if not record then
            return
        end

        if event and (event.name == defines.events.on_pre_player_mined_item or event.name == defines.events.on_robot_pre_mined) then
            store_pending_mining(runtime, event, capture_pending_mining(record))
            return
        end

        unregister_record(runtime, unit_number)
    end
end

-- The mined buffer is adjusted only after Factorio creates it. This lets unstable
-- shells return their correct live or husk item without fighting the engine's
-- normal mining result pipeline.
local function finalize_mined_buffer(event)
    local runtime = get_runtime()
    local snapshot = take_pending_mining(runtime, event)
    if not snapshot then
        return
    end

    local unit_number = snapshot.unit_number
    if unit_number and runtime.by_unit[unit_number] then
        unregister_record(runtime, unit_number)
    end

    if event.buffer and event.buffer.valid then
        local replacement_name = snapshot.live_item_name or snapshot.husk_name
        local replacement_stack = replacement_name and make_item_stack(replacement_name, snapshot.quality_name, 1) or nil
        if replacement_stack and event.buffer.can_insert(replacement_stack) then
            event.buffer.clear()
            event.buffer.insert(replacement_stack)
        end
    end

    local surface = event and event.entity and event.entity.valid and event.entity.surface or nil
    if surface and surface.valid then
        queue_surface_viewers(runtime, surface.index, now_tick(event))
    end
end

function model.on_player_mined_entity(event)
    finalize_mined_buffer(event)
end

function model.on_robot_mined_entity(event)
    finalize_mined_buffer(event)
end

-- Selection changes are high frequency, so this handler only invalidates the
-- player's next allowed UI tick when the watched unit actually changed. The real
-- rebuild still happens through the delayed UI queue.
function model.on_selected_entity_changed(event)
    local runtime = get_runtime()
    local player = event.player_index and game and game.get_player(event.player_index) or nil
    if player and player.valid then
        local entity = get_relevant_entity_for_player(player)
        local next_unit_number = entity and get_unit_number(entity) or nil
        local current_watch = runtime.watch_by_player[event.player_index]
        if current_watch and current_watch.unit_number ~= next_unit_number then
            runtime.ui_next_allowed_tick[event.player_index] = nil
        end
    end
    queue_player_ui_if_relevant(runtime, event.player_index, now_tick(event))
end

-- Opening a relevant entity promotes the custom readout immediately, then queues
-- a normal refresh to settle button state, watches, and any topology changes
-- caused by Factorio's native GUI behavior.
function model.on_gui_opened(event)
    local runtime = get_runtime()
    local player = event.player_index and game and game.get_player(event.player_index) or nil
    local previous_open_unit = runtime.open_by_player[event.player_index]
    local event_entity = event and event.entity or nil
    if not is_relevant_entity(event_entity)
        and player
        and player.valid
        and player.opened_gui_type == defines.gui_type.entity
    then
        event_entity = ei_lib.get_valid_entity(player.opened)
    end
    if player and player.valid and is_relevant_entity(event_entity) then
        open_primary_screen_gui(runtime, player, event_entity, now_tick(event))
    end
    sync_opened_live_shell(runtime, event.player_index, player)
    if is_relevant_entity(event_entity) or previous_open_unit ~= runtime.open_by_player[event.player_index] then
        runtime.ui_next_allowed_tick[event.player_index] = nil
    end
    queue_player_ui_if_relevant(runtime, event.player_index, now_tick(event))
end

-- Close events can mean "the native entity GUI closed", "the detached screen
-- closed", or "Factorio promoted a different root". The bookkeeping below keeps
-- those cases distinct so a player dismissing a screen is respected.
function model.on_gui_closed(event)
    local runtime = get_runtime()
    local player = event.player_index and game and game.get_player(event.player_index) or nil
    local previous_open_unit = runtime.open_by_player[event.player_index]
    local closed_entity = event and event.entity or nil
    local closed_screen = event.element and event.element.valid and event.element.name == SCREEN_GUI_NAME
    local promoted_screen_matches = false
    if player and player.valid and is_relevant_entity(closed_entity) then
        local screen_entity = get_detached_screen_entity(runtime, player)
        promoted_screen_matches = screen_entity
            and get_unit_number(screen_entity) == get_unit_number(closed_entity)
    end
    if player and player.valid and get_screen_root(player) then
        if closed_screen or (is_relevant_entity(closed_entity) and not promoted_screen_matches) then
            dismiss_screen_for_player(runtime, player, get_relevant_entity_for_player(player))
        end
    end
    sync_opened_live_shell(runtime, event.player_index, player)
    if closed_screen
        or is_relevant_entity(closed_entity)
        or previous_open_unit ~= runtime.open_by_player[event.player_index]
    then
        runtime.ui_next_allowed_tick[event.player_index] = nil
    end
    queue_player_ui_if_relevant(runtime, event.player_index, now_tick(event))
end

-- Platform movement changes the local cosmic context without any accumulator
-- entity changing. Waking only the platform surface and its viewers gives transit
-- the right feel without scanning every surface.
function model.on_space_platform_changed_state(event)
    local runtime = get_runtime()
    local platform = event and event.platform or nil
    if not (platform and platform.valid) then
        return
    end

    local hub = platform.hub
    local surface = hub and hub.valid and hub.surface or nil
    if not (surface and surface.valid) then
        return
    end

    if not ((runtime.units_by_surface[surface.index] and next(runtime.units_by_surface[surface.index]) ~= nil)
        or runtime.watchers_by_surface[surface.index]) then
        return
    end

    schedule_surface(runtime, surface.index, now_tick(event))
    queue_surface_viewers(runtime, surface.index, now_tick(event))
end

-- GUI clicks are routed entirely through element tags. That keeps chrome elements
-- free of global name assumptions and lets the relative, strip, and screen roots
-- share the same action vocabulary.
function model.on_gui_click(event)
    local element = event and event.element or nil
    if not (element and element.valid and element.tags) then
        return
    end

    local element_tags = element.tags

    if element_tags.parent_gui ~= RELATIVE_GUI_NAME and element_tags.parent_gui ~= STRIP_NAME then
        return
    end

    if element_tags.action == "goto-informatron" then
        local runtime = get_runtime()
        local player = event.player_index and game and game.get_player(event.player_index) or nil
        local page_name = element_tags.page or INFORMATRON_PAGE
        if player and player.valid and get_screen_root(player) then
            dismiss_screen_for_player(runtime, player, get_relevant_entity_for_player(player))
        end
        remote.call("informatron", "informatron_open_to_page", {
            player_index = event.player_index,
            interface = "exotic-industries-informatron",
            page_name = page_name,
        })
    elseif element_tags.action == "close-screen" then
        local runtime = get_runtime()
        local player = event.player_index and game and game.get_player(event.player_index) or nil
        if player and player.valid then
            dismiss_screen_for_player(runtime, player, get_relevant_entity_for_player(player))
        end
    elseif element_tags.action == "open-detail" then
        local runtime = get_runtime()
        local player = event.player_index and game and game.get_player(event.player_index) or nil
        local entity = player and player.valid and get_relevant_entity_for_player(player) or nil
        local unit_number = entity and get_unit_number(entity) or nil
        if runtime and player and player.valid and unit_number then
            runtime.screen_requested_by_player[player.index] = unit_number
            runtime.screen_dismissed_by_player[player.index] = nil
            runtime.ui_next_allowed_tick[player.index] = nil
            queue_ui_refresh(runtime, player.index, now_tick(event))
        end
    end
end

-- Player cleanup drops both the scheduler-facing watch state and any physical GUI
-- roots that might remain. The player can reconnect into a clean refresh path.
function model.on_player_left_game(player_index)
    local runtime = get_runtime()
    clear_player_watch(runtime, player_index)
    runtime.open_by_player[player_index] = nil
    runtime.ui_pending_by_player[player_index] = nil
    runtime.ui_next_allowed_tick[player_index] = nil
    runtime.ui_render_signature_by_player[player_index] = nil
    runtime.screen_dismissed_by_player[player_index] = nil
    runtime.screen_requested_by_player[player_index] = nil
    clear_screen_target(runtime, player_index)

    local player = game and game.get_player(player_index) or nil
    if player then
        destroy_status_strip(player)
        destroy_relative_gui(player)
        destroy_screen_gui(player)
    end
end

-- Alt-select with the repair tool is the field inspection mode. It prints the
-- same snapshot model used by the GUI, sorted spatially and capped so dragging
-- across a factory does not flood chat or build unbounded temporary output.
function model.on_player_alt_selected_area(event)
    if event.item ~= REPAIR_TOOL_NAME then
        return
    end

    local player = game and game.get_player(event.player_index) or nil
    if not (player and player.valid) then
        return
    end

    local runtime = get_runtime()
    local relevant_entities = {}
    for _, entity in ipairs(event.entities or {}) do
        if is_relevant_entity(entity) then
            relevant_entities[#relevant_entities + 1] = entity
        end
    end

    table.sort(relevant_entities, function(left, right)
        local left_x = (left.position and left.position.x) or 0
        local right_x = (right.position and right.position.x) or 0
        if left_x == right_x then
            local left_y = (left.position and left.position.y) or 0
            local right_y = (right.position and right.position.y) or 0
            if left_y == right_y then
                return (left.name or "") < (right.name or "")
            end
            return left_y < right_y
        end
        return left_x < right_x
    end)

    local printed = 0
    for index, entity in ipairs(relevant_entities) do
        if index > INSPECT_PRINT_LIMIT then
            break
        end

        local snapshot = build_snapshot(runtime, entity, now_tick(event))
        if snapshot then
            local x = math.floor((entity.position.x or 0) + 0.5)
            local y = math.floor((entity.position.y or 0) + 0.5)
            if snapshot.result_mode == "repair" then
                player.print({
                    "exotic-industries.crystal-accumulator-inspect-line-husk",
                    get_entity_display_name(entity),
                    x,
                    y,
                    {"exotic-industries.crystal-accumulator-state-" .. snapshot.state_key},
                    snapshot.field_percent,
                    {"exotic-industries.crystal-accumulator-telemetry-" .. snapshot.telemetry_key},
                    snapshot.quality_percent,
                    {"exotic-industries.crystal-accumulator-repair-" .. snapshot.result_key},
                })
            else
                player.print({
                    "exotic-industries.crystal-accumulator-inspect-line-live",
                    get_entity_display_name(entity),
                    x,
                    y,
                    {"exotic-industries.crystal-accumulator-shell-" .. snapshot.shell_key},
                    snapshot.output_text,
                    {"exotic-industries.crystal-accumulator-state-" .. snapshot.state_key},
                    {"exotic-industries.crystal-accumulator-load-" .. snapshot.load_band},
                    snapshot.coherence,
                    snapshot.field_percent,
                    {"exotic-industries.crystal-accumulator-telemetry-" .. snapshot.telemetry_key},
                    snapshot.quality_percent,
                    {"exotic-industries.crystal-accumulator-mining-" .. snapshot.result_key},
                })
            end
            printed = printed + 1
        end
    end

    if printed == 0 then
        player.print({"exotic-industries.crystal-accumulator-inspect-none"})
    elseif #relevant_entities > printed then
        player.print({"exotic-industries.crystal-accumulator-inspect-overflow", printed, (#relevant_entities - printed)})
    end
end

return model
