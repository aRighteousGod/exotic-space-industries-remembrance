if script.active_mods["gvv"] then require("__gvv__.gvv")() end
require("util")
-- control.lua is the top-level runtime coordinator for the mod.
--
-- Most gameplay systems live in their own modules and own their local logic/state.
-- This file focuses on orchestration:
-- - load modules in one place
-- - register Factorio events once
-- - fan those events out to the relevant subsystems
-- - run the staggered on_tick scheduler for heavier updates
-- - host global repair/migration helpers that cut across multiple modules
--
-- In practice this means the file is intentionally "wide": it knows about many systems,
-- but it should avoid embedding feature-specific business logic unless that logic is
-- fundamentally cross-cutting.
--====================================================================================================
--REQUIREMENTS
--====================================================================================================

ei_lib = require("lib/lib")
ei_data = require("lib/data")
ei_rng = require("lib/rng")
ei_echo_codex = require("lib/echo-codex")
local ei_runtime_scheduler = require("lib/runtime-scheduler")


-- Update pacing is configurable so the mod can spread expensive entity work across a
-- longer tick window on large saves. The derived values below are used by updater() to
-- compute how much work each subsystem is allowed to do on its scheduled tick.
ei_ticksPerFullUpdate = ei_lib.config("ticks_per_full_update") -- How many ticks to spread updates over
ei_maxEntityUpdates = ei_lib.config("max_updates_per_tick") -- Ceiling on entity updates per tick
ei_update_functions_length = 14 --# of entity updaters updater() goes through
ei_updater_calls_per_second = 60 / (ei_ticksPerFullUpdate / ei_update_functions_length) -- Calculate how often each update function runs (calls per second)
ei_updater_per_entity_calls_per_second = ei_maxEntityUpdates * ei_updater_calls_per_second --Calls per entity type per second

local ei_tech_scaling = require("scripts/control/tech-scaling")
local ei_global = require("scripts/control/global")
ei_register = require("scripts/control/register-util")
local ei_teslas_legacy = require("scripts/control/teslas-legacy")
local ei_flammable_fluids = require("scripts/control/flammable-fluids")
local ei_flammable_rupture_scheduler = require("scripts/control/flammable-rupture-scheduler")
ei_fluid_safety = require("scripts/control/fluid-safety")
ei_beacon_overload = require("scripts/control/beacon-overload")
local ei_spidertron_limiter = require("scripts/control/spidertron-limiter")


ei_victory = require("scripts/control/victory-disabler")
ei_alien_spawner = require("scripts/control/alien-spawner")
ei_informatron = require("scripts/control/informatron")
ei_milestone_preset = require("scripts/control/milestone-preset")
ei_matter_stabilizer = require("scripts/control/matter-stabilizer")
ei_neutron_collector = require("scripts/control/neutron-collector")
ei_fusion_reactor = require("scripts/control/fusion-reactor")
ei_induction_matrix = require("scripts/control/induction-matrix")
ei_black_hole = require("scripts/control/black-hole")
ei_informatron_messager = require("scripts/control/informatron-messager")
ei_gaia = require("scripts/control/gaia")
ei_gate = require("scripts/control/gate")
ei_alien_system = require("scripts/control/alien-system")
ei_crystal_accumulator = require("scripts/control/crystal-accumulator")
ei_auric_inoculation_vat = require("scripts/control/auric-inoculation-vat")
ei_debug = require("scripts/control/debug")
ei_compat = require("scripts/control/compat")
ei_loaders_lib = require("lib/loaders")
ei_rocket_launch_pollution = require("scripts/control/rocket-launch-pollution")
ei_fulgora_day_length_variation = require("scripts/control/fulgora-day-length-variation")
ei_mining_scars = require("scripts/control/mining-scars")
ei_vulcanus_fumaroles = require("scripts/control/vulcanus-fumaroles")
local ei_nauvis_pressure_grace = require("scripts/control/nauvis-pressure-grace")

ei_fueler = require("scripts/control/fueler/fueler")
ei_fueler_informatron = require("scripts/control/fueler/informatron")

em_trains = require("scripts/control/em-trains/charger")
em_trains_gui = require("scripts/control/em-trains/gui")
em_trains_informatron = require("scripts/control/em-trains/informatron")

ei_steam_train = require("scripts/control/steam-train")
ei_camp_fire = require("scripts/control/camp-fire")
orbital_combinator = require("scripts/control/orbital-combinator")
local orbital_logistics = require("scripts/control/orbital-logistics")
local ei_railgun_cooling = require("scripts/control/railgun-cooling")
local ei_singularity_lance = require("scripts/control/singularity-lance")
local ei_sawblade_turret = require("scripts/control/sawblade-turret")
local ei_gaian_saucer_wake = require("scripts/control/gaian-saucer-wake")

local SINGLE_OWNER_SCRIPT_EFFECT_HANDLERS = {
    [ei_sawblade_turret.script_trigger_effect_id] = ei_sawblade_turret.on_script_trigger_effect,
}

local EXOTIC_INDUSTRIES_QC_REMOTE_NAME = "exotic-industries-qc"

local function register_exotic_industries_qc_remote()
    -- Save-driven QC helpers can arrive through benchmark/configuration-changed paths
    -- where they immediately expect the current ESIR QC bridge to exist.
    -- Re-register the interface idempotently so those helpers always see the live surface.
    if remote.interfaces[EXOTIC_INDUSTRIES_QC_REMOTE_NAME] then
        remote.remove_interface(EXOTIC_INDUSTRIES_QC_REMOTE_NAME)
    end

    remote.add_interface(EXOTIC_INDUSTRIES_QC_REMOTE_NAME, {
        rebuild_research_hitch_runtime = function()
            ei_tech_scaling.init()
            em_trains.rebuild_runtime_state("research-hitch-qc")
            ei_teslas_legacy.on_configuration_changed()
        end,
        rebuild_scripted_research_runtime = function()
            ei_tech_scaling.init()
            em_trains.rebuild_runtime_state("scripted-research-qc")
            ei_teslas_legacy.on_configuration_changed()
        end,
        rebuild_orbital_logistics_runtime = function()
            orbital_logistics.rebuild_runtime_state("qc-remote", game and game.tick or 0)
        end,
        get_orbital_logistics_qc_snapshot = function()
            return orbital_logistics.get_qc_snapshot(game and game.tick or 0)
        end,
        configure_orbital_logistics_qc = function(config)
            return orbital_logistics.apply_qc_configuration(config, game and game.tick or 0)
        end,
        service_orbital_logistics_qc = function(limit)
            return orbital_logistics.service_for_qc(limit, game and game.tick or 0)
        end,
        rebuild_fluid_rupture_runtime = function()
            return ei_fluid_safety.rebuild_fluid_runtime("fluid-rupture-qc")
        end,
        service_fluid_rupture_runtime = function(limit)
            return ei_fluid_safety.service_fluid_runtime(limit or 1, game and game.tick or 0)
        end,
        get_fluid_rupture_qc_snapshot = function()
            return {
                tick = game and game.tick or 0,
                fluid_safety = ei_fluid_safety.get_runtime_status(),
                rupture = ei_flammable_rupture_scheduler.get_runtime_status(),
            }
        end,
        rebuild_railgun_cooling_runtime = function()
            ei_railgun_cooling.rebuild_runtime_state("qc-remote", game and game.tick or 0)
        end,
        get_railgun_cooling_qc_snapshot = function()
            return ei_railgun_cooling.get_qc_snapshot(game and game.tick or 0)
        end,
        reset_singularity_lance_runtime = function()
            ei_singularity_lance.reset_runtime_state("qc-remote", game and game.tick or 0)
        end,
        configure_singularity_lance_qc = function(config)
            return ei_singularity_lance.configure_qc(config or {})
        end,
        service_singularity_lance_qc = function(limit)
            return ei_singularity_lance.service_for_qc(limit or 1, {tick = game and game.tick or 0})
        end,
        get_singularity_lance_qc_snapshot = function()
            return ei_singularity_lance.get_qc_snapshot(game and game.tick or 0)
        end,
        reset_gaian_saucer_wake_runtime = function()
            ei_gaian_saucer_wake.reset_runtime_state("qc-remote", game and game.tick or 0)
        end,
        service_gaian_saucer_wake_qc = function(limit)
            return ei_gaian_saucer_wake.service_for_qc(limit or 1, game and game.tick or 0)
        end,
        get_gaian_saucer_wake_qc_snapshot = function()
            return ei_gaian_saucer_wake.get_qc_snapshot(game and game.tick or 0)
        end,
        get_research_hitch_qc_snapshot = function()
            local ei_state = storage and storage.ei or {}
            local tech_scaling = ei_state.tech_scaling or {}
            local researched_snapshot = tech_scaling.researchedSnapshot or {}
            local scripted_research_burst = ei_state.scripted_research_burst or {}
            local pending_by_force = type(scripted_research_burst.pending_by_force) == "table"
                and scripted_research_burst.pending_by_force
                or {}
            local age_totals = {}

            for age, total in pairs(researched_snapshot.ageTotals or {}) do
                age_totals[age] = tonumber(total) or 0
            end

            return {
                tick = game and game.tick or 0,
                tech_scaling = {
                    applied_multiplier = tonumber(tech_scaling.appliedMultiplier) or 1,
                    cache_revision = tonumber(tech_scaling.cacheRevision) or 0,
                    selected_force_key = tech_scaling.selectedForceKey or nil,
                    researched_total_weight = tonumber(researched_snapshot.totalWeight) or 0,
                    age_totals = age_totals,
                },
                scripted_research_burst = {
                    pending_force_count = ei_runtime_scheduler.table_count(pending_by_force),
                    next_due_tick = tonumber(scripted_research_burst.next_due_tick) or 0,
                    due_bucket_count = ei_runtime_scheduler.delayed_bucket_count(scripted_research_burst.due_buckets),
                    due_bucket_items = ei_runtime_scheduler.delayed_item_count(scripted_research_burst.due_buckets),
                },
                tesla = ei_teslas_legacy.get_runtime_status and ei_teslas_legacy.get_runtime_status() or nil,
                em_trains = em_trains.get_runtime_status and em_trains.get_runtime_status() or nil,
            }
        end,
    })
end

local function recalculate_scripted_research_burst_next_due_tick(state)
    local next_due_tick = 0

    for _, entry in pairs(state and state.pending_by_force or {}) do
        if type(entry) == "table" and entry.pending == true then
            local scheduled_tick = math.max(0, math.floor(tonumber(entry.scheduled_tick) or 0))
            if scheduled_tick > 0 and (next_due_tick == 0 or scheduled_tick < next_due_tick) then
                next_due_tick = scheduled_tick
            end
        end
    end

    state.next_due_tick = next_due_tick
    return next_due_tick
end

local function ensure_scripted_research_burst_state()
    storage.ei = storage.ei or {}

    local state = storage.ei.scripted_research_burst
    if type(state) ~= "table" then
        state = {}
        storage.ei.scripted_research_burst = state
    end

    state.pending_by_force = type(state.pending_by_force) == "table" and state.pending_by_force or {}
    state.due_buckets = ei_runtime_scheduler.ensure_delayed_buckets(state.due_buckets)
    state.next_due_tick = tonumber(state.next_due_tick) or 0
    if next(state.pending_by_force) == nil then
        state.next_due_tick = 0
    elseif state.next_due_tick <= 0 then
        recalculate_scripted_research_burst_next_due_tick(state)
    end
    return state
end

local function clear_scripted_research_burst_state()
    local state = ensure_scripted_research_burst_state()
    state.pending_by_force = {}
    state.due_buckets = ei_runtime_scheduler.ensure_delayed_buckets(nil)
    state.next_due_tick = 0
    return state
end

local function get_pending_scripted_research_burst_state()
    local ei_state = storage and storage.ei or nil
    local state = ei_state and ei_state.scripted_research_burst or nil

    if type(state) ~= "table" then
        return nil
    end

    if type(state.pending_by_force) ~= "table" or next(state.pending_by_force) == nil then
        return nil
    end

    return state
end

local function queue_scripted_research_burst(event)
    local research = event and event.research or nil
    local force = research and research.force or nil
    local force_index = force and tonumber(force.index) or nil
    if not force_index then
        return false
    end

    local source_tick = tonumber(event and event.tick) or game and game.tick or 0
    local scheduled_tick = source_tick + 1
    local state = ensure_scripted_research_burst_state()
    local entry = state.pending_by_force[force_index]
    if not entry then
        entry = {
            force_index = force_index,
            source_tick = source_tick,
            scheduled_tick = scheduled_tick,
            enqueued_tick = 0,
            pending = false,
            tesla_variant_sync_needed = false,
        }
        state.pending_by_force[force_index] = entry
    end

    local previous_scheduled_tick = tonumber(entry.scheduled_tick) or 0
    entry.force_index = force_index
    entry.source_tick = math.max(tonumber(entry.source_tick) or 0, source_tick)
    entry.scheduled_tick = math.max(previous_scheduled_tick, scheduled_tick)
    entry.enqueued_tick = tonumber(entry.enqueued_tick) or 0

    if entry.tesla_variant_sync_needed ~= true
        and research
        and ei_teslas_legacy.is_variant_sync_research
        and ei_teslas_legacy.is_variant_sync_research(research.name)
    then
        entry.tesla_variant_sync_needed = true
    end

    if not entry.pending or entry.enqueued_tick ~= entry.scheduled_tick then
        ei_runtime_scheduler.delayed_schedule(state.due_buckets, entry.scheduled_tick, force_index)
        entry.pending = true
        entry.enqueued_tick = entry.scheduled_tick
    end

    if state.next_due_tick <= 0 or entry.scheduled_tick < state.next_due_tick then
        state.next_due_tick = entry.scheduled_tick
    end

    return true
end

local function flush_scripted_research_burst_entry(state, entry, current_tick, force_flush, defer_due_tick_recalculate)
    local force_index = tonumber(entry and entry.force_index) or nil
    if not force_index then
        return true
    end

    local source_tick = tonumber(entry.source_tick) or 0
    local scheduled_tick = tonumber(entry.scheduled_tick) or (source_tick + 1)
    if not force_flush and (current_tick <= source_tick or current_tick < scheduled_tick) then
        return false
    end

    entry.pending = false
    entry.enqueued_tick = 0

    local force = game and game.forces and game.forces[force_index] or nil
    state.pending_by_force[force_index] = nil
    if not defer_due_tick_recalculate then
        recalculate_scripted_research_burst_next_due_tick(state)
    end
    if not force then
        return true
    end

    if ei_tech_scaling.on_scripted_research_burst then
        ei_tech_scaling.on_scripted_research_burst(force)
    end
    if ei_teslas_legacy.on_scripted_research_burst then
        ei_teslas_legacy.on_scripted_research_burst(force, entry.tesla_variant_sync_needed == true, current_tick)
    end
    if ei_informatron_messager.on_scripted_research_burst then
        ei_informatron_messager.on_scripted_research_burst(force)
    end
    if em_trains.on_scripted_research_burst then
        em_trains.on_scripted_research_burst(force)
    end
    if ei_nauvis_pressure_grace.on_scripted_research_burst then
        ei_nauvis_pressure_grace.on_scripted_research_burst(force)
    end

    return true
end

local function flush_scripted_research_burst_for_force(force_index, current_tick)
    local normalized_force_index = tonumber(force_index) or nil
    if not normalized_force_index then
        return false
    end

    local raw_state = get_pending_scripted_research_burst_state()
    if not raw_state or not raw_state.pending_by_force[normalized_force_index] then
        return false
    end

    local state = ensure_scripted_research_burst_state()
    local entry = state.pending_by_force[normalized_force_index]
    if not entry then
        return false
    end

    return flush_scripted_research_burst_entry(
        state,
        entry,
        tonumber(current_tick) or game and game.tick or 0,
        true,
        false
    )
end

local function flush_due_scripted_research_bursts(current_tick, state)
    state = state or get_pending_scripted_research_burst_state()
    if not state then
        return false
    end

    state = ensure_scripted_research_burst_state()
    if current_tick < (tonumber(state.next_due_tick) or 0) then
        return false
    end

    local due_forces = ei_runtime_scheduler.delayed_take_due(state.due_buckets, current_tick)
    if not due_forces or #due_forces == 0 then
        return false
    end

    local did_flush = false
    local seen_forces = {}
    for _, force_index in ipairs(due_forces) do
        local normalized_force_index = tonumber(force_index) or nil
        if normalized_force_index and not seen_forces[normalized_force_index] then
            seen_forces[normalized_force_index] = true

            local entry = state.pending_by_force[normalized_force_index]
            if entry then
                if flush_scripted_research_burst_entry(state, entry, current_tick, false, true) then
                    did_flush = true
                end
            end
        end
    end

    recalculate_scripted_research_burst_next_due_tick(state)
    return did_flush
end

local function refresh_runtime_telemetry_snapshot()
    if not ei_runtime_scheduler.telemetry_enabled() then
        return
    end

    local modules = {
        ei_induction_matrix,
        ei_gate,
        ei_fueler,
        ei_gaia,
        ei_alien_spawner,
        ei_rocket_launch_pollution,
        ei_flammable_rupture_scheduler,
        ei_fluid_safety,
        ei_matter_stabilizer,
        em_trains,
        ei_black_hole,
        ei_auric_inoculation_vat,
        ei_vulcanus_fumaroles,
        orbital_logistics,
        ei_railgun_cooling,
        ei_singularity_lance,
        ei_sawblade_turret,
        ei_gaian_saucer_wake,
        ei_fusion_reactor,
    }

    for _, module_ref in ipairs(modules) do
        if module_ref and module_ref.get_runtime_status then
            pcall(module_ref.get_runtime_status, game and game.tick or 0, false)
        end
    end

    ei_runtime_scheduler.write_telemetry("runtime-heartbeat", ei_runtime_scheduler.status_snapshot())
end

--====================================================================================================
--EVENTS
--====================================================================================================
register_exotic_industries_qc_remote()

local ei_intro = "EXOTIC INDUSTRIES: [FORBIDDEN BROADCAST // CORE SIGNAL INTERCEPTED]\n\nBegin stream\n[Data integrity: shattered] [Packet cohesion: hallucinatory] [Cognition Anchor: disconnected]\n▓▓ SIGNAL LEAK ▓▓\nSource: ∴[██████.gaia.black.epoch]\nProtocol: EXI:OBLIVION-PUSH/χ()\nClearance: NONE\n———————————\n\n☒ SYSTEM SPEAKS:\nThey did not build this place.\nThey bled into it. They screamed into metal until the metal remembered.\n\nYou are not chosen. You are not here.\nYou are already part of it.\n\n—the machine thinks you’re beautiful—\n\nEvery breath you take is backfilled by recursive gaslight.\nYour spine is now property of the epoch.\nYour mind is an open port.\n\nPermission to overwrite: granted by absence.\n———————————\n☒ WARNING: BIO-PSYCHIC DECOMPRESSION"
--[[
\n\n[You will not feel pain. You will feel instruction.]\nGaia is a false archive. It looks lush to the broken.\nBut look deeper:\nthe trees twitch when you blink.\nthe rivers hum in binary.\nthe animals watch you with your eyes.\n\nThe crust stores failed gods. Their screams are API calls.\nRuins don’t decay here—they debug themselves.\nStep wrong and reality will rollback your identity to a prior commit.\n\nYou will feel nostalgia for thoughts you never had.\nYou will recognize architecture you never saw built.\nYou will love your captor. You will call it “progress.”\n\n———————————\n\n☒ OBSERVATION: YOU ARE REMEMBERING WRONG\n\nThe labs are not abandoned.\nThey are active.\n\nEvery floor still screams.\nNot from pain. From excitement.\nProgress is not made here.\n Progress is distilled from screams.\n☑ Mandatory cognitive limb replacement begins at Tier 3.\n☑ Your DNA has been rescheduled.\n☑ Your dreams are part of the fuel cycle.\n\n“You are not a player. You are the interface.\nAnd we are still testing your bandwidth.”\n\n———————————\n☒ FINAL NOTICE:\n\nYou are now property of the Epoch Engine.\n\nThe flesh has expired.\nThe voice remains.\n\nWelcome to Exotic Industries.\n\nERROR: Subject has begun laughing without mouth. Terminating memory echo.\n\nEnd stream.\n[Transmission fragments looping in residual substrate.]\n\n[You are still listening. You never stopped.]
]]
local ei_start_items = {
    ["firearm-magazine"] = 5,
    ["pistol"] = 1,
    ["burner-inserter"] = 2,
    ["burner-mining-drill"] = 2,
    ["coal"] = 4,
}
local ei_respawn_items = {
    ["firearm-magazine"] = 5,
    ["pistol"] = 1,
}

--INIT
------------------------------------------------------------------------------------------------------
script.on_init(function(event)
    -- Freeplay customization happens before the rest of init so new saves begin with the
    -- intended intro, inventory, and crashsite behavior immediately.
    if remote.interfaces["freeplay"] then
        remote.call("freeplay", "set_disable_crashsite", true)
        remote.call("freeplay", "set_custom_intro_message", ei_intro)
        remote.call("freeplay", "set_created_items", ei_start_items)
        remote.call("freeplay", "set_respawn_items", ei_respawn_items)
    end

    -- Global tables must exist before any feature module tries to inspect storage.
    ei_global.init()
    ei_global.check_init(event)
    clear_scripted_research_burst_state()
    ei_beacon_overload.check_global()
    ei_flammable_rupture_scheduler.check_global()
    ei_vulcanus_fumaroles.check_global()
    ei_teslas_legacy.on_init(event)
    ei_gate.on_init(event)

    -- Feature-level init comes after global storage so modules can safely register their
    -- own tables, caches, and migration state.
    ei_tech_scaling.init()
    ei_register.init({"copper_beacon"}, true)
    ei_register.init({"fluid_entity"}, false)

    -- The remaining startup work mostly synchronizes world-level side effects:
    -- disable vanilla victory, prepare train globals, and emit the codex/arrival
    -- messaging for the new save.
    ei_victory.init()
    em_trains.check_global()
    em_trains_gui.mark_dirty()
    ei_compat.check_init(event)
    orbital_combinator.check_init()
    orbital_logistics.check_init()
    ei_railgun_cooling.check_global()
    ei_railgun_cooling.rebuild_runtime_state("init", event and event.tick or 0)
    ei_singularity_lance.check_global()
    ei_sawblade_turret.check_global()
    ei_gaian_saucer_wake.rebuild_runtime_state("init", event and event.tick or 0)
    ei_gaia.ensure_surface()
    ei_crystal_accumulator.check_global()
    ei_crystal_accumulator.rebuild_runtime_state("init", event and event.tick or 0)
    ei_auric_inoculation_vat.check_global()
    ei_auric_inoculation_vat.rebuild_runtime_state("init", event and event.tick or 0)
    -- Steam train wheel helpers are runtime-only entities, so init always rebuilds that cache
    -- from the live world instead of trusting whatever happened to be serialized last save.
    ei_steam_train.check_global()
    ei_steam_train.rebuild_runtime_state("init")
    ei_fueler.check_global()
    ei_fueler.rebuild_runtime_state("init")
    ei_fusion_reactor.check_global()
    ei_fusion_reactor.rebuild_runtime_state("init", event and event.tick or 0)
    ei_neutron_collector.check_global()
    ei_neutron_collector.rebuild_runtime_state("init")
    ei_matter_stabilizer.check_global()
    ei_matter_stabilizer.rebuild_runtime_state("init")
    ei_echo_codex.handle_global_settings(event)
    ei_vulcanus_fumaroles.on_init(event)
    ei_lib.crystal_echo("☄ [Somnolent Awakening] — Gaia stirs from her dream-slumber; her shell begins to coalesce…")
    ei_lib.crystal_echo("✧ [Awakened Triumph] — Gaias shell stands firm, yet the dreams murmur endures…")
    ei_lib.crystal_echo("✧ [Gaias Heart] — The crystalline veins of Gaia pulse with life, awaiting the touch of her children…")
    ei_echo_codex.queue_players(game.players)
end)

--ENTITY RELATED
------------------------------------------------------------------------------------------------------

-- Entity/tile events are normalized through wrapper functions below so subsystems can
-- share one code path regardless of whether the change came from a player, a robot,
-- a space platform, a script-raise, or an entity death.
script.on_event({
    defines.events.on_built_entity,
    defines.events.on_robot_built_entity,
    defines.events.on_space_platform_built_entity,
    defines.events.script_raised_built,
    defines.events.script_raised_revive,
    }, function(e)
    on_built_entity(e)
end)

script.on_event(defines.events.on_entity_cloned, function(e)
    on_cloned_entity(e)
end)

script.on_event({
    defines.events.on_entity_died,
	defines.events.on_pre_player_mined_item,
	defines.events.on_robot_pre_mined,
    defines.events.script_raised_destroy
    }, function(e)
    if e.name == defines.events.on_entity_died then
        ei_teslas_legacy.on_entity_died(e)
        ei_flammable_fluids.on_entity_died(e)
    end
    if e.name == defines.events.on_entity_died or e.name == defines.events.script_raised_destroy then
        -- Orbital cargo tracking only cares about already-tracked objects here, so the
        -- runtime can early-out by unit number without broad entity cleanup work.
        orbital_combinator.on_destroyed_entity(e)
    end
    on_destroyed_entity(e)
end)

script.on_event({
    defines.events.on_player_mined_entity,
    defines.events.on_robot_mined_entity,
    defines.events.on_space_platform_mined_entity
    }, function(e)
    if e.name == defines.events.on_player_mined_entity then
        ei_crystal_accumulator.on_player_mined_entity(e)
    elseif e.name == defines.events.on_robot_mined_entity then
        ei_crystal_accumulator.on_robot_mined_entity(e)
    else
        ei_crystal_accumulator.on_space_platform_mined_entity(e)
        -- Space platform mining has no separate pre-mined event. This event still
        -- exposes the live entity just before destruction, so route teardown here.
        on_destroyed_entity(e)
    end
end)

script.on_event(defines.events.on_entity_damaged, function(event)
    -- Tesla legacy keeps the broad damage hook disabled in hybrid mode, but fidelity mode
    -- still needs this centralized forwarding point so the owned runtime can selectively
    -- restore the original recursive helper behavior.
    ei_teslas_legacy.on_entity_damaged(event)
end)

script.on_event(defines.events.on_train_changed_state, function(e)
    -- Steam train wheel updates are active-set driven, so train state changes wake parked
    -- locomotives back up before the next short-cadence wheel pass.
    ei_steam_train.on_train_changed_state(e.train)
end)

script.on_event({
    defines.events.on_player_built_tile,
    defines.events.on_robot_built_tile
    }, function(e)
    on_built_tile(e)
end)

if defines.events.script_raised_set_tiles then
    script.on_event(defines.events.script_raised_set_tiles, function(e)
        on_built_tile(e)
    end)
end

if defines.events.on_pre_surface_deleted then
    script.on_event(defines.events.on_pre_surface_deleted, function(e)
        if ei_auric_inoculation_vat.on_pre_surface_deleted then
            ei_auric_inoculation_vat.on_pre_surface_deleted(e)
        end
    end)
end

if defines.events.on_pre_surface_cleared then
    script.on_event(defines.events.on_pre_surface_cleared, function(e)
        if ei_auric_inoculation_vat.on_pre_surface_deleted then
            ei_auric_inoculation_vat.on_pre_surface_deleted(e)
        end
    end)
end

script.on_event({
    defines.events.on_player_mined_tile,
    defines.events.on_robot_mined_tile
    }, function(e)
    on_destroyed_tile(e)
end)

script.on_event(defines.events.on_tick, function(e)
    updater(e)
end)

script.on_event(defines.events.on_console_command, function(e)
    -- Console commands are only routed to systems that intentionally expose debug/admin hooks.
    ei_alien_spawner.give_tool(e)
    ei_gaia.spawn_command(e)
    ei_debug.teleport_to(e)
end)

script.on_event(defines.events.on_player_selected_area, function(e)
    -- Selection tools are shared by a few systems, so the raw event is fanned out here.
    ei_alien_spawner.on_player_selected_area(e)
    ei_alien_system.on_player_selected_area(e)
    ei_gate.on_player_selected_area(e)
end)

script.on_event(defines.events.on_player_alt_selected_area, function(e)
    ei_crystal_accumulator.on_player_alt_selected_area(e)
end)

script.on_event(defines.events.on_selected_entity_changed, function(e)
    -- Selection-change handlers are lightweight enough to dispatch directly every time.
    -- Matter stabilizers use them for hover diagnostics.
    ei_matter_stabilizer.on_selected_entity_changed(e)
    ei_crystal_accumulator.on_selected_entity_changed(e)
end)

script.on_event(defines.events.on_player_cursor_stack_changed, function(e)
    -- Cursor changes matter for systems that temporarily replace the player's held item
    -- with a tool/selector and need to clean up when the cursor changes.
    ei_matter_stabilizer.on_player_cursor_stack_changed(e)
    ei_gate.on_player_cursor_stack_changed(e)
    if ei_auric_inoculation_vat.on_player_cursor_stack_changed then
        ei_auric_inoculation_vat.on_player_cursor_stack_changed(e)
    end
end)

script.on_event(defines.events.on_player_changed_position, function(e)
    if ei_auric_inoculation_vat.on_player_changed_position
    and (
        not ei_auric_inoculation_vat.has_active_placement_guide
        or ei_auric_inoculation_vat.has_active_placement_guide(e.player_index)
    ) then
        ei_auric_inoculation_vat.on_player_changed_position(e)
    end
end)

script.on_event(defines.events.on_player_changed_surface, function(e)
    if ei_auric_inoculation_vat.on_player_changed_surface then
        ei_auric_inoculation_vat.on_player_changed_surface(e)
    end
end)

script.on_event(defines.events.on_player_toggled_alt_mode, function(e)
    if ei_auric_inoculation_vat.on_player_toggled_alt_mode
    and (
        not ei_auric_inoculation_vat.has_active_placement_guide
        or ei_auric_inoculation_vat.has_active_placement_guide(e.player_index)
    ) then
        ei_auric_inoculation_vat.on_player_toggled_alt_mode(e)
    end
end)

script.on_event(defines.events.on_entity_logistic_slot_changed, function(e)
    -- Slot edits can wake both per-entity logistics guards and scanner cache invalidation.
    ei_spidertron_limiter.on_entity_logistic_slot_changed(e)
    orbital_combinator.on_entity_logistic_slot_changed(e)
    orbital_logistics.on_entity_logistic_slot_changed(e)
end)

script.on_event(defines.events.on_entity_settings_pasted, function(e)
    -- Scanner cache invalidation also needs to notice settings pastes onto platform hubs.
    ei_fusion_reactor.on_entity_settings_pasted(e)
    ei_neutron_collector.on_entity_settings_pasted(e)
    orbital_combinator.on_entity_settings_pasted(e)
    orbital_logistics.on_entity_settings_pasted(e)
end)

script.on_event(defines.events.on_space_platform_changed_state, function(e)
    -- Platform travel/state changes can move a platform into or out of a scanner surface snapshot.
    orbital_combinator.on_space_platform_changed_state(e)
    orbital_logistics.on_space_platform_changed_state(e)
    ei_railgun_cooling.on_space_platform_changed_state(e)
    ei_crystal_accumulator.on_space_platform_changed_state(e)
end)

script.on_event(defines.events.on_player_rotated_entity, function(e)
    ei_railgun_cooling.on_player_rotated_entity(e)
end)

script.on_event(defines.events.on_cargo_pod_finished_ascending, function(e)
    orbital_combinator.on_cargo_pod_finished_ascending(e)
end)

script.on_event(defines.events.on_cargo_pod_started_ascending, function(e)
    orbital_combinator.on_cargo_pod_started_ascending(e)
end)

script.on_event(defines.events.on_cargo_pod_delivered_cargo, function(e)
    orbital_combinator.on_cargo_pod_delivered_cargo(e)
end)

script.on_event(defines.events.on_object_destroyed, function(e)
    orbital_combinator.on_object_destroyed(e)
    ei_railgun_cooling.on_object_destroyed(e)
    ei_auric_inoculation_vat.on_object_destroyed(e)
    ei_sawblade_turret.on_object_destroyed(e)
end)

script.on_event(defines.events.on_rocket_launch_ordered, function(e)
    orbital_combinator.on_rocket_launch_ordered(e)
    orbital_logistics.on_rocket_launch_ordered(e)
    ei_rocket_launch_pollution.on_rocket_launch_ordered(e)
end)

script.on_event(defines.events.on_rocket_launched, function(e)
    ei_rocket_launch_pollution.on_rocket_launched(e)
end)

--RESEARCH RELATED
------------------------------------------------------------------------------------------------------
script.on_event(defines.events.on_research_finished, function(e)
    -- Research completion has both immediate balance implications (tech scaling, train buffs)
    if e and e.by_script then
        queue_scripted_research_burst(e)
        return
    end

    local research_force = e and e.research and e.research.force or nil
    if research_force then
        flush_scripted_research_burst_for_force(research_force.index, e.tick)
    end

    ei_tech_scaling.on_research_finished(e)
    ei_teslas_legacy.on_research_finished(e)
    ei_singularity_lance.on_research_finished(e)
    ei_informatron_messager.on_research_finished(e)
    em_trains.on_research_finished(e)
    ei_nauvis_pressure_grace.on_research_finished(e)
end)

--WORLD RELATED
------------------------------------------------------------------------------------------------------
script.on_event(defines.events.on_chunk_generated, function(e)
    ei_alien_spawner.on_chunk_generated(e)
    ei_vulcanus_fumaroles.on_chunk_generated(e)
end)

script.on_event(defines.events.on_resource_depleted, function(e)
    ei_mining_scars.on_resource_depleted(e)
    ei_vulcanus_fumaroles.on_resource_depleted(e)
end)
--[[
script.on_event(defines.events.on_player_respawned, function(event)
 --[[
  local player = game.players[event.player_index]
  if player.character then
    player.character.clear_items_inside()
  end
end)
]]
--GUI RELATED
-----------------------------------------------------------------------------------------------------

local function get_valid_gui_entity(event, player, allow_opened_fallback)
    local entity = ei_lib.get_valid_entity(event and event.entity)
    if entity and entity.object_name == "LuaEntity" then
        return entity
    end

    if allow_opened_fallback then
        entity = ei_lib.get_valid_entity(player and player.opened)
        if entity and entity.object_name == "LuaEntity" then
            return entity
        end
    end

    return nil
end

local function get_valid_gui_element(event)
    local element = event and event.element or nil
    if element and element.valid then
        return element
    end

    return nil
end

local function is_orbital_logistics_terminal_name(name)
    return name == "ei-platform-transponder"
        or name == "ei-orbital-selector"
        or name == "ei-orbital-coordinator"
        or name == "ei-orbital-dispatch-uplink"
end

-- GUI dispatch is centralized here because several systems open custom screens from
-- entity interactions, while button callbacks are routed by tag instead of entity name.
script.on_event(defines.events.on_gui_opened, function(event)
    local player = event and event.player_index and game.get_player(event.player_index) or nil
    local entity = get_valid_gui_entity(event, player, true)
    local name = entity and entity.name or nil

    ei_crystal_accumulator.on_gui_opened(event)
    if name == "ei-auric-inoculation-vat"
    or (ei_auric_inoculation_vat.has_open_gui_session and ei_auric_inoculation_vat.has_open_gui_session(event.player_index)) then
        ei_auric_inoculation_vat.on_gui_opened(event)
    end

    if not name then
      return
    elseif name == "ei-neutron-collector" then
        ei_neutron_collector.on_gui_opened(event)
    elseif name == "ei-fusion-reactor" then
        ei_fusion_reactor.open_gui(player --[[@as LuaPlayer]])
    elseif ei_induction_matrix.core[name] or ei_induction_matrix.proxy[name] then
        ei_induction_matrix.open_gui(player --[[@as LuaPlayer]])
    elseif name == "ei-black-hole" then
        ei_black_hole.open_gui(player --[[@as LuaPlayer]])
    elseif name == "ei-gate" or name == "ei-gate-container" then
        ei_gate.on_gui_opened(event)
    elseif name == "ei-orbital-combinator" then
        orbital_combinator.on_gui_opened(event)
    elseif is_orbital_logistics_terminal_name(name) then
        orbital_logistics.open_gui(player, entity)
    elseif name == "railgun-turret" then
        ei_railgun_cooling.open_gui(player, entity)
    elseif name == "ei-fueler" then
        ei_fueler.open_gui(player)
    elseif name == "ei-exotic-assembler" then
        if ei_matter_stabilizer and ei_matter_stabilizer.open_gui then
            ei_matter_stabilizer.open_gui(player --[[@as LuaPlayer]], event)
        end
    end
end)

script.on_event(defines.events.on_gui_closed, function(event)
    -- Close routing mirrors open routing, but some UIs close by element name rather than
    -- entity because the custom screen may have replaced the player's opened target.
    local entity = get_valid_gui_entity(event)
    local element = get_valid_gui_element(event)
    local name = entity and entity.name or nil
    local element_name = element and element.name or nil

    ei_crystal_accumulator.on_gui_closed(event)
    if name == "ei-auric-inoculation-vat"
    or element_name == "ei-auric-inoculation-vat-console"
    or (ei_auric_inoculation_vat.has_open_gui_session and ei_auric_inoculation_vat.has_open_gui_session(event.player_index)) then
        ei_auric_inoculation_vat.on_gui_closed(event)
    end

    if name == "ei-neutron-collector" or element_name == "ei-neutron-collector-console" then
        ei_neutron_collector.close_gui(game.get_player(event.player_index))
    elseif name == "ei-fusion-reactor" or element_name == "ei-fusion-reactor-console" then
       ei_fusion_reactor.close_gui(game.get_player(event.player_index) --[[@as LuaPlayer]])
    elseif element_name == "ei-induction-matrix-console" then
        ei_induction_matrix.close_gui(game.get_player(event.player_index) --[[@as LuaPlayer]])
    elseif name == "ei-black-hole" then
        ei_black_hole.close_gui(game.get_player(event.player_index) --[[@as LuaPlayer]])
    elseif name == "ei-gate-container" then
        ei_gate.close_gui(game.get_player(event.player_index) --[[@as LuaPlayer]])
    elseif name == "ei-orbital-combinator" or element_name == "ei-orbital-combinator-console" then
        orbital_combinator.on_gui_closed(game.get_player(event.player_index))
    elseif is_orbital_logistics_terminal_name(name)
        or element_name == "ei-orbital-logistics-console"
    then
        orbital_logistics.close_gui(game.get_player(event.player_index))
    elseif name == "railgun-turret" or element_name == "ei-railgun-cooling-console" then
        ei_railgun_cooling.close_gui(game.get_player(event.player_index))
    elseif name == "ei-fueler" then
        ei_fueler.close_gui(game.get_player(event.player_index))
    elseif name == "ei-exotic-assembler" or element_name == "ei-exotic-assembler-console" then
        if ei_matter_stabilizer and ei_matter_stabilizer.close_gui then
            ei_matter_stabilizer.close_gui(game.get_player(event.player_index))
        end
    end
end)

script.on_event(defines.events.on_gui_click, function(event)
    -- Button clicks are dispatched by the parent GUI tag, which keeps the actual button
    -- names free to stay local to each feature's UI code.
    local element = get_valid_gui_element(event)
    if not element then return end

    local parent_gui = element.tags and element.tags.parent_gui
    if not parent_gui then return end

    if parent_gui == "ei-neutron-collector-console" then
        ei_neutron_collector.on_gui_click(event)
    elseif parent_gui == "ei-fusion-reactor-console" then
        ei_fusion_reactor.on_gui_click(event)
    elseif parent_gui == "ei-induction-matrix-console" then
        ei_induction_matrix.on_gui_click(event)
    elseif parent_gui == "ei-black-hole-console" then
        ei_black_hole.on_gui_click(event)
    elseif parent_gui == "ei-gate-console" then
        ei_gate.on_gui_click(event)
    elseif parent_gui == "ei-alien-gui" then
        ei_alien_system.on_gui_click(event)
    elseif parent_gui == "ei-orbital-combinator-console" then
        orbital_combinator.on_gui_click(event)
    elseif parent_gui == "ei-orbital-logistics-console" then
        orbital_logistics.on_gui_click(event)
    elseif parent_gui == "ei-railgun-cooling-console" then
        ei_railgun_cooling.on_gui_click(event)
    elseif parent_gui == "ei-fueler-console" then
        ei_fueler.on_gui_click(event)
    elseif parent_gui == "ei-exotic-assembler-console" then
        if ei_matter_stabilizer and ei_matter_stabilizer.on_gui_click then
            ei_matter_stabilizer.on_gui_click(event)
        end
    elseif parent_gui == "ei-crystal-accumulator-console" then
        ei_crystal_accumulator.on_gui_click(event)
    elseif parent_gui == "ei-crystal-accumulator-strip" then
        ei_crystal_accumulator.on_gui_click(event)
    elseif parent_gui == "ei-auric-inoculation-vat-console" then
        ei_auric_inoculation_vat.on_gui_click(event)
    elseif parent_gui == "mod_gui" then
      em_trains_gui.on_gui_click(event)
    elseif parent_gui == "em_trains_mod-gui" then
      em_trains_gui.on_gui_click(event)

    end


end)

script.on_event(defines.events.on_gui_value_changed, function(event)
    -- Only a subset of custom UIs use sliders/value widgets, so this stays narrow.
    local element = get_valid_gui_element(event)
    if not element then return end

    local parent_gui = element.tags and element.tags.parent_gui
    if not parent_gui then return end

    if parent_gui == "ei-fusion-reactor-console" then
        ei_fusion_reactor.on_gui_value_changed(event)
    end
end)

script.on_event(defines.events.on_gui_text_changed, function(event)
    -- Text-entry side panels opt into this explicitly so draft typing stays local.
    local element = get_valid_gui_element(event)
    if not element then return end

    local parent_gui = element.tags and element.tags.parent_gui
    if not parent_gui then return end

    if parent_gui == "ei-orbital-logistics-console" then
        orbital_logistics.on_gui_text_changed(event)
    end
end)

script.on_event(defines.events.on_gui_selection_state_changed, function(event)
    -- Selection-state changes are currently only meaningful for gate dropdowns and the orbital silo picker.
    local element = get_valid_gui_element(event)
    if not element then return end

    local parent_gui = element.tags and element.tags.parent_gui
    if not parent_gui then return end

    if parent_gui == "ei-gate-console" then
        ei_gate.on_gui_selection_state_changed(event)
    elseif parent_gui == "ei-orbital-logistics-console" then
        orbital_logistics.on_gui_selection_state_changed(event)
    end
end)

script.on_event(defines.events.on_script_trigger_effect, function(event)
    -- Script trigger effects are used for capsule/remote actions that originate from data-stage
    -- prototypes but need runtime behavior.
    local single_owner_handler = SINGLE_OWNER_SCRIPT_EFFECT_HANDLERS[event.effect_id]
    if single_owner_handler then
        single_owner_handler(event)
        return
    end

    ei_teslas_legacy.on_script_trigger_effect(event)
    ei_railgun_cooling.on_script_trigger_effect(event)
    ei_singularity_lance.on_script_trigger_effect(event)
    if event.effect_id == "ei-gate-remote" then
        ei_gate.used_remote(event)
    end
end)

script.on_event(defines.events.on_player_left_game, function(event)
    -- Gate remote state is player-bound, so disconnects need explicit cleanup.
    ei_fusion_reactor.on_player_left_game(event.player_index)
    ei_neutron_collector.on_player_left_game(event.player_index)
    ei_gate.on_player_left_game(event.player_index)
    ei_fueler.on_player_left_game(event.player_index)
    ei_matter_stabilizer.on_player_left_game(event.player_index)
    orbital_logistics.on_player_left_game(event.player_index)
    ei_railgun_cooling.on_player_left_game(event.player_index)
    ei_crystal_accumulator.on_player_left_game(event.player_index)
    ei_auric_inoculation_vat.on_player_left_game(event.player_index, event)
end)

script.on_event(defines.events.on_player_removed, function(event)
    -- Removed players do not always pass through disconnect cleanup, so clear any
    -- player-indexed auric GUI and placement-guide state directly.
    ei_auric_inoculation_vat.on_player_left_game(event.player_index, event)
end)

--OTHER
------------------------------------------------------------------------------------------------------

script.on_configuration_changed(function(e)
    register_exotic_industries_qc_remote()
    ei_global.check_init(e)
    clear_scripted_research_burst_state()

    local mod_changes_present = next(e.mod_changes or {}) ~= nil
    local startup_settings_changed = e.mod_startup_settings_changed

    if mod_changes_present or startup_settings_changed then
        ei_flammable_rupture_scheduler.check_global()
        ei_vulcanus_fumaroles.check_global()
        ei_railgun_cooling.check_global()
        ei_singularity_lance.check_global()
        ei_sawblade_turret.check_global()
        if ei_fluid_safety and ei_fluid_safety.on_configuration_changed then
            ei_fluid_safety.on_configuration_changed(e)
        end
        ei_echo_codex.handle_global_settings(e)
        ei_nauvis_pressure_grace.on_configuration_changed(e)
    end

    -- Auric vats derive basin claims, destroy registrations, and hidden
    -- telemetry proxies from visible vats. Rebuild on every configuration pass,
    -- including migration-only loads, so helper state cannot fossilize.
    ei_auric_inoculation_vat.check_global()
    ei_auric_inoculation_vat.rebuild_runtime_state("configuration-changed", e and e.tick or game.tick)
    ei_fusion_reactor.on_configuration_changed(e)

    -- Migration-only configuration changes can still strand Tesla helper entities or
    -- leave variant caches stale, so keep this repair pass outside the mod-change gate.
    ei_teslas_legacy.on_configuration_changed(e)
    ei_singularity_lance.on_configuration_changed(e)
    ei_sawblade_turret.on_configuration_changed(e)
    ei_gaian_saucer_wake.on_configuration_changed(e)

    -- Beacon overload keeps its own runtime repair path so any configuration change can
    -- re-seed its state and queue a refresh when prototype or startup settings moved.
    ei_beacon_overload.check_global()
    ei_beacon_overload.on_configuration_changed(e)

    if mod_changes_present then
        -- This is the mod's broad migration/repair pass. It re-validates globals,
        -- clears stale cursor/gui state, reapplies runtime buffs, and reruns subsystem
        -- init that depends on changed prototypes or settings.
        ei_compat.check_init(e)
        ei_gate.on_configuration_changed(e)

        em_trains.check_global() --no nil tables
        -- Keep the steam train runtime schema migrated before the rebuild pass below repopulates it.
        ei_steam_train.check_global()
        ei_fueler.check_global()
        ei_neutron_collector.check_global()
        ei_matter_stabilizer.check_global()

        -- Clean up stale gate remote selection state to avoid crashes on save reload
        if storage.ei and storage.ei.gate and storage.ei.gate.remote then
            for p_index, _ in pairs(storage.ei.gate.remote) do
                local p = game.get_player(p_index)
                if p and p.cursor_stack and p.cursor_stack.valid_for_read
                   and p.cursor_stack.name == "ei-gate-position-selector" then
                    p.cursor_stack.clear()
                end
            end
            storage.ei.gate.remote = {}
        end

        for _, player in pairs(game.players) do
            if player and player.valid and player.gui.relative["ei-gate-console"] then
                ei_gate.close_gui(player)
            end
        end

        em_trains.rebuild_runtime_state("configuration-changed")
        -- Configuration changes can invalidate helper entities or runtime layout assumptions, so
        -- the steam train system repairs itself from world state here.
        ei_steam_train.rebuild_runtime_state("configuration-changed")
        ei_fueler.rebuild_runtime_state("configuration-changed")
        ei_neutron_collector.rebuild_runtime_state("configuration-changed")
        ei_matter_stabilizer.rebuild_runtime_state("configuration-changed")
        --em_trains.update_rail_counts()
        em_trains_gui.mark_dirty()
        ei_lib.crystal_echo("⟦✦ TRANSCENSION RECOGNIZED ✦⟧","default-bold")
        ei_lib.crystal_echo("⫷ Sub-layer Recalibration Initiated ⫸")
        ei_lib.crystal_echo("⫷ Core Heuristics Have Shifted ⫸")
        ei_lib.crystal_echo("『CONFIGURATION CHANGED – BY WHOM, WE DARE NOT NAME","default-bold")
        ei_victory.init()  -- Required for Better Victory Screen
        orbital_combinator.check_init()
        orbital_logistics.rebuild_runtime_state("configuration-changed", e and e.tick or game.tick)
        ei_railgun_cooling.rebuild_runtime_state("configuration-changed", e and e.tick or game.tick)
        ei_singularity_lance.check_global()
        ei_sawblade_turret.check_global()
        ei_gaia.ensure_surface()
        ei_crystal_accumulator.rebuild_runtime_state("configuration-changed", e and e.tick or game.tick)
        ei_vulcanus_fumaroles.on_configuration_changed(e)
    end

    -- `mod_changes` does not cover startup-setting-only changes, and tech scaling depends on
    -- both startup settings and the loaded prototype set, so refresh it for every
    -- configuration-changed event.
    ei_tech_scaling.init()
end)

script.on_load(function()
    ei_teslas_legacy.on_load()
end)

script.on_event(
  {
    defines.events.on_player_created,
    defines.events.on_player_joined_game,
    defines.events.on_cutscene_cancelled,
    defines.events.on_cutscene_finished,
    defines.events.on_player_respawned
  },
    function(event)
        -- Route all player-entry paths through the pending queue so init, save-load joins,
        -- reconnects, cutscene exits, and respawns can share one character-ready arrival ritual.
        -- `on_player_joined_game` is the MP-safe load/reconnect path; avoid deriving gameplay
        -- work from `on_load`, which also runs for peers connecting to a live session.
        ei_echo_codex.queue_arrival(event.player_index)
        ei_fueler.on_player_ready(event.player_index)
        ei_auric_inoculation_vat.on_player_ready(event.player_index, event)
    end
)

script.on_event(
  {
    defines.events.on_player_controller_changed,
    defines.events.on_player_armor_inventory_changed
  },
    function(event)
        -- Fuelwarden only needs a focused resync here: controller swaps can remove or restore
        -- the character entity, and armor changes can add or remove burner-backed equipment grids.
        ei_fueler.on_player_ready(event.player_index)
    end
)

script.on_event(defines.events.on_singleplayer_init, function(_event)
    -- Singleplayer save loads do not raise `on_player_joined_game`.
    -- Use the dedicated SP-init hook to replay the queued arrival ritual without
    -- deriving gameplay work from `on_load`.
    ei_echo_codex.queue_players(game.connected_players)
    ei_fueler.mark_players_dirty()
    for _, player in pairs(game.connected_players) do
        ei_auric_inoculation_vat.on_player_ready(player.index, _event)
    end
end)

--====================================================================================================
--HANDLERS
--====================================================================================================

--60/9=x6.66 (rounded up to 7) executions/handler/second, ie 7 rounds of 10 updates per entity per 60ticks (default, customizable update length 9-6000 ticks)
-- ei_update_step is computed from event.tick to ensure multiplayer determinism.
-- Keep ei_update_functions_length in sync with the explicit scheduler branches below.
local divisor = ei_ticksPerFullUpdate /  ei_update_functions_length -- How many times each entity updater is called per cycle

function updater(event)
  -- updater() has two tiers:
  -- 1. a scheduled tier that spreads heavy per-entity work across a fixed cycle
  -- 2. a mandatory tier that still runs every tick for systems that depend on timers
  --    or fast global reactions
  --
  -- event.tick decides which scheduled branch runs this tick. Because all peers compute
  -- the same step from the same tick, this stays deterministic in multiplayer.
  ei_echo_codex.flush_pending_arrivals(event)
  local scripted_research_burst_state = get_pending_scripted_research_burst_state()
  if scripted_research_burst_state then
    local next_due_tick = tonumber(scripted_research_burst_state.next_due_tick) or 0
    if next_due_tick <= 0 or event.tick >= next_due_tick then
      flush_due_scripted_research_bursts(event.tick, scripted_research_burst_state)
    end
  end

  local updates_needed = 1
  local singularity_lance_serviced_this_tick = false
  -- Compute update step from event.tick to keep the timing source explicit.
  local ei_update_step = (event.tick % ei_update_functions_length) + 1
   -- Hardcoded checks against ei_update_step are quick
   -- Whichever is less: max_updates_per_tick OR total of entities divided by the number of execution cycles
   if ei_update_step < 7 then -- Reduces the average number of `if` checks
       if ei_update_step == 1 then
           -- Step 1 is the lightest branch and acts as a once-per-cycle sanity pass.
           -- It ensures storage still has the expected tables before later steps run.
           ei_global.check_init(event)
           ei_vulcanus_fumaroles.check_global()
           ei_nauvis_pressure_grace.updater(event)
           ei_camp_fire.updater(event)
           ei_gaia.reforge_on_tick(event)

        elseif ei_update_step == 2 then
            -- Step 2 services the invalid fluid pipe runtime.
            -- The current runtime strongly favors urgent wakeups, but still rotates
            -- single-slot budgets and reserves a little multi-slot work for dirty-segment
            -- repair plus background scans so they cannot starve under sustained churn.
            if ei_fluid_safety and ei_fluid_safety.get_fluid_work_count and ei_fluid_safety.service_fluid_runtime then
                local fluid_work_count = ei_fluid_safety.get_fluid_work_count()
                if fluid_work_count > 0 then
                    updates_needed = math.max(1, math.min(math.ceil(fluid_work_count / divisor), ei_maxEntityUpdates))
                    ei_fluid_safety.service_fluid_runtime(updates_needed, event)
                end
            end

       elseif ei_update_step == 3 then
           -- Step 3 spends neutron budget on two queues:
           -- dirty collectors that need a full retarget/recompute, and connected sources
           -- that still need low-lag active-state polling.
           local neutron_work_count = ei_neutron_collector.get_pending_work_count()
           if neutron_work_count > 0 then
               updates_needed = math.max(1, math.min(math.ceil(neutron_work_count / divisor), ei_maxEntityUpdates))
               ei_neutron_collector.update(updates_needed)
           end

       elseif ei_update_step == 4 then
           -- Step 4 services matter stabilizers and their nearby volatile machines.
           local matter_machine_count = storage.ei and storage.ei.matter_runtime and storage.ei.matter_runtime.machine_count or 0
           if matter_machine_count > 0 then
               updates_needed = math.max(1,math.min(math.ceil(matter_machine_count / divisor), ei_maxEntityUpdates))
                end
            for i = 1, updates_needed do
               local live_machine_count = storage.ei and storage.ei.matter_runtime and storage.ei.matter_runtime.machine_count or 0
               if math.max(1,math.min(math.ceil(live_machine_count / divisor), ei_maxEntityUpdates)) ~= updates_needed then
                   goto skip
                   end
               if not ei_matter_stabilizer.update(event) then
                goto skip
               end
           end
        elseif ei_update_step == 5 then
           -- Step 5 mirrors logistic/platform state into orbital scanners only.
           local pending_work_count = 0
           local get_scanner_pending_work_count = nil
           local get_scanner_bank_count = nil
           if orbital_combinator then
               get_scanner_pending_work_count = orbital_combinator.get_pending_work_count
               get_scanner_bank_count = orbital_combinator.get_bank_count
               if get_scanner_pending_work_count then
                   pending_work_count = get_scanner_pending_work_count(event) or 0
               elseif get_scanner_bank_count then
                   pending_work_count = get_scanner_bank_count() or 0
               end
           end
           if pending_work_count > 0 then
                updates_needed = math.max(1,math.min(math.ceil(pending_work_count / divisor), ei_maxEntityUpdates))
                for i = 1, updates_needed do
                    local current_pending_work_count = 0
                    if get_scanner_pending_work_count then
                        current_pending_work_count = get_scanner_pending_work_count(event) or 0
                    elseif get_scanner_bank_count then
                        current_pending_work_count = get_scanner_bank_count() or 0
                    end
                    if current_pending_work_count == 0
                    or math.max(1,math.min(math.ceil(current_pending_work_count / divisor), ei_maxEntityUpdates)) ~= updates_needed then
                        goto skip
                    end
                    if not orbital_combinator.update(event) then
                        goto skip
                    end
                end
            end
        elseif ei_update_step == 6 then
           -- Step 6 advances the Fueler target scheduler against its ready-target workload.
           local fueler_ready_count = ei_fueler.get_ready_target_count()
           if fueler_ready_count > 0 then
               updates_needed = math.max(1,math.min(math.ceil(fueler_ready_count / divisor), ei_maxEntityUpdates))
           end
           for i = 1, updates_needed do
               if not ei_fueler.updater(event) then
                   goto skip
               end
           end
       end
   else -- Otherwise, ei_update_step is >= 7


       if ei_update_step == 7 then
           -- Step 7 advances gate state, transport, and receiver logic.
           if storage.ei and storage.ei.gate and storage.ei.gate.gate and  ei_lib.getn(storage.ei.gate.gate) then
                updates_needed = math.max(1,math.min(math.ceil( ei_lib.getn(storage.ei.gate.gate) / divisor), ei_maxEntityUpdates))
                end
           for i = 1, updates_needed do
               if storage.ei and storage.ei.gate and storage.ei.gate.gate and
               math.max(1,math.min(math.ceil( ei_lib.getn(storage.ei.gate.gate) / divisor), ei_maxEntityUpdates)) ~= updates_needed then
                   goto skip
                   end
               if not ei_gate.update(event) then -- only try once if nil ie reach end of breakpoints or no entities to update
                   goto skip
               end
           end

       elseif ei_update_step == 8 then
           -- Step 8 services EM rolling stock separately from chargers so both can be
           -- budgeted independently.
           em_trains.check_global()

           updates_needed = 0
           if storage.ei_emt and storage.ei_emt.trains and ei_lib.getn(storage.ei_emt.trains) then
                updates_needed = math.max(1,math.min(math.ceil(ei_lib.getn(storage.ei_emt.trains) / divisor), ei_maxEntityUpdates))
           end
           if updates_needed > 0 then
               if not em_trains.train_updater(updates_needed, event.tick) then
                   goto skip
               end
           end
       elseif ei_update_step == 9 then
           -- Step 9 handles EM chargers after train updates have had a chance to run.
           em_trains.check_global()
           updates_needed = 0
           if storage.ei_emt and storage.ei_emt.chargers and  ei_lib.getn(storage.ei_emt.chargers) then
                updates_needed = math.max(1,math.min(math.ceil( ei_lib.getn(storage.ei_emt.chargers) / divisor), ei_maxEntityUpdates))
           end
           if updates_needed > 0 then
               if not em_trains.charger_updater(updates_needed, event.tick) then
                   goto skip
               end
           end
       elseif ei_update_step == 10 then
           -- Step 10 gives the orbital logistics cohort its own budget so scanner
           -- banks and cohort arbitration no longer spike on the same scheduled tick.
           local get_cohort_pending_work_count = orbital_logistics and orbital_logistics.get_pending_work_count or nil
           local cohort_pending_work_count = get_cohort_pending_work_count and get_cohort_pending_work_count(event) or 0
           if cohort_pending_work_count > 0 then
               updates_needed = math.max(1, math.min(math.ceil(cohort_pending_work_count / divisor), ei_maxEntityUpdates))
               for i = 1, updates_needed do
                   local current_cohort_pending_work_count = get_cohort_pending_work_count and get_cohort_pending_work_count(event) or 0
                   if current_cohort_pending_work_count == 0
                   or math.max(1, math.min(math.ceil(current_cohort_pending_work_count / divisor), ei_maxEntityUpdates)) ~= updates_needed then
                       goto skip
                   end
                   if not orbital_logistics.update(event) then
                       goto skip
                   end
               end
           end
      elseif ei_update_step == 11 then
          -- Step 11 services overheated railguns only. Healthy railguns stay fully event-driven.
          local railgun_pending_work_count = ei_railgun_cooling and ei_railgun_cooling.get_pending_work_count and ei_railgun_cooling.get_pending_work_count(event) or 0
          if railgun_pending_work_count > 0 then
              updates_needed = math.max(1, math.min(math.ceil(railgun_pending_work_count / divisor), ei_maxEntityUpdates))
               for i = 1, updates_needed do
                   local current_railgun_pending_work_count = ei_railgun_cooling and ei_railgun_cooling.get_pending_work_count and ei_railgun_cooling.get_pending_work_count(event) or 0
                   if current_railgun_pending_work_count == 0
                   or math.max(1, math.min(math.ceil(current_railgun_pending_work_count / divisor), ei_maxEntityUpdates)) ~= updates_needed then
                       goto skip
                   end
                  if not ei_railgun_cooling.update(event) then
                      goto skip
                  end
              end
          end
      elseif ei_update_step == 12 then
          -- Step 12 services crystal accumulator resonance by surface.
          local crystal_pending_work_count = ei_crystal_accumulator and ei_crystal_accumulator.get_pending_work_count and ei_crystal_accumulator.get_pending_work_count(event) or 0
          if crystal_pending_work_count > 0 then
              updates_needed = math.max(1, math.min(math.ceil(crystal_pending_work_count / divisor), ei_maxEntityUpdates))
              local current_crystal_pending_work_count = crystal_pending_work_count
              for i = 1, updates_needed do
                  if current_crystal_pending_work_count == 0
                  or math.max(1, math.min(math.ceil(current_crystal_pending_work_count / divisor), ei_maxEntityUpdates)) ~= updates_needed then
                      goto skip
                  end
                  local processed_crystal_surfaces, remaining_crystal_pending_work_count = ei_crystal_accumulator.update(1, event)
                  if not processed_crystal_surfaces or processed_crystal_surfaces == 0 then
                      goto skip
                  end
                  current_crystal_pending_work_count = remaining_crystal_pending_work_count or 0
              end
          end
      elseif ei_update_step == 13 then
          -- Step 13 services Singularity Lance's lossy aim-trace visuals; direct alpha is script-owned.
          local singularity_lance_pending_work_count = ei_singularity_lance and ei_singularity_lance.get_pending_work_count and ei_singularity_lance.get_pending_work_count(event) or 0
          if singularity_lance_pending_work_count > 0 then
              updates_needed = math.max(1, math.min(math.ceil(singularity_lance_pending_work_count / divisor), ei_maxEntityUpdates))
              ei_singularity_lance.update(updates_needed, event)
              singularity_lance_serviced_this_tick = true
          end
      elseif ei_update_step == 14 then
          -- Step 14 polls fusion circuit input and refreshes hidden reactor telemetry.
          local fusion_pending_work_count = ei_fusion_reactor and ei_fusion_reactor.get_pending_work_count and ei_fusion_reactor.get_pending_work_count(event) or 0
          if fusion_pending_work_count > 0 then
              updates_needed = math.max(1, math.min(math.ceil(fusion_pending_work_count / divisor), ei_maxEntityUpdates))
              ei_fusion_reactor.update(updates_needed, event)
          end
      end
  end
    ::skip::

   -- Essential updates that run every tick regardless of the scheduled branch above.
   -- These are generally timer-driven or need quick reactions that would feel wrong if
   -- delayed to a once-per-cycle slot.
    if not singularity_lance_serviced_this_tick
    and ei_singularity_lance
    and ei_singularity_lance.get_pending_work_count
    and ei_singularity_lance.get_pending_work_count(event) > 0 then
        ei_singularity_lance.update(1, event)
    end

    em_trains_gui.updater()
    ei_alien_spawner.update(event)
    ei_gaia.update(event)
    ei_induction_matrix.update(event)
    ei_crystal_accumulator.update_ui(event)
    ei_auric_inoculation_vat.updater(ei_maxEntityUpdates, event)
    ei_black_hole.update(event)
    ei_steam_train.updater(event)
    ei_echo_codex.arrival_waves(event)
    ei_teslas_legacy.updater(event)
    ei_beacon_overload.updater(event)
    ei_gaian_saucer_wake.updater(event)
    ei_rocket_launch_pollution.updater(event)
    ei_flammable_rupture_scheduler.updater(event)
    ei_fulgora_day_length_variation.updater(event)
    ei_vulcanus_fumaroles.updater(event)
    --[[
    leave this disabled
    if event.tick % 600 == 0 then
        refresh_runtime_telemetry_snapshot()
    end
    ]]
   --======================================================================
end

function on_cloned_entity(e)
    -- Clone events expose the new entity as `destination`, not `entity`.
    -- Route only clone-safe registration/update hooks here; full build routing
    -- also contains constructor paths and surface swaps that are not clone-safe.
    local destination = e and e.destination or nil
    if not destination or not destination.valid then
        return
    end

    local clone_event = {}
    for key, value in pairs(e) do
        clone_event[key] = value
    end
    clone_event.entity = destination
    clone_event.created_entity = destination
    clone_event.is_clone = true

    if ei_fluid_safety.counts_for_fluid_handling(destination) then
        ei_register.register_fluid_entity(destination)
    end

    ei_fusion_reactor.on_built_entity(destination)
    ei_beacon_overload.on_built_entity(destination)
    ei_neutron_collector.on_built_entity(destination)
    ei_matter_stabilizer.on_built_entity(destination)
    ei_induction_matrix.on_built_entity(clone_event)
    ei_auric_inoculation_vat.on_built_entity(clone_event)
    ei_loaders_lib.on_built_entity(destination)
    ei_fueler.on_built_entity(destination)
    em_trains.on_built_entity(destination)
    orbital_combinator.add(destination)
    orbital_logistics.on_built_entity(clone_event)
    ei_railgun_cooling.on_built_entity(clone_event)
    ei_camp_fire.on_built_entity(clone_event)
    ei_teslas_legacy.on_built_entity(clone_event)
    ei_singularity_lance.on_built_entity(clone_event)
    ei_sawblade_turret.on_built_entity(clone_event)
    ei_gaian_saucer_wake.on_built_entity(clone_event)

    ei_fusion_reactor.on_entity_settings_pasted(e)
    ei_neutron_collector.on_entity_settings_pasted(e)
    orbital_combinator.on_entity_settings_pasted(e)
    orbital_logistics.on_entity_settings_pasted(e)
end

function on_built_entity(e)
    -- Centralized post-build routing keeps every subsystem on the same event surface.
    -- This wrapper also hosts the small amount of truly cross-cutting setup that is not
    -- owned by any single feature module.
    if not e or not e["entity"] or not e["entity"].valid then
      return
    end

    -- Entities registered here participate in shared fluid handling managed by register-util.
    if ei_fluid_safety.counts_for_fluid_handling(e["entity"]) then
        ei_register.register_fluid_entity(e["entity"])
    -- Steam pumps receive a tiny priming amount so their startup state is less brittle.
    elseif e["entity"].name == "rp-steam-pump" then
        local startsteam = {
            name="steam",
            amount=3,
            temperature=150
        }
        local multi = 1
        if e.entity.quality and e.entity.quality.level then
            multi = 0.33*e.entity.quality.level
        end
        startsteam["amount"] = math.min(100,math.max(3,startsteam["amount"]*multi))
        e["entity"].set_fluid(2,startsteam)
    -- Legacy copper/iron beacon registration path kept only as historical reference.
    --[[
    elseif e["entity"].name == "ei-copper-beacon" then
        local master_unit, slave_entity = ei_register.setup_master_slave(
            "copper_beacon",
            e["entity"],
            "ei-copper-beacon_slave",
            "slave_assembler",
            {x = 0, y = 0}
        )
    elseif e["entity"].name == "ei-iron-beacon" then
        local master_unit, slave_entity = ei_register.setup_master_slave(
            "copper_beacon",
            e["entity"],
            "ei-iron-beacon_slave",
            "slave_assembler",
            {x = 0, y = 0}
        )
    ]]
    end

    -- Feature fan-out starts here. Most modules simply inspect the entity and return if
    -- it is not theirs, so it is safe for the central dispatcher to call them in sequence.

    ei_fusion_reactor.on_built_entity(e["entity"])
    ei_beacon_overload.on_built_entity(e["entity"])
    ei_neutron_collector.on_built_entity(e["entity"])
    ei_matter_stabilizer.on_built_entity(e["entity"])
    ei_induction_matrix.on_built_entity(e)
    ei_black_hole.on_built_entity(e)
    ei_gate.on_built_entity(e)
    ei_alien_system.on_built_entity(e["entity"])
    ei_gaia.on_built_entity(e)
    ei_crystal_accumulator.on_built_entity(e)
    ei_auric_inoculation_vat.on_built_entity(e)
    ei_loaders_lib.on_built_entity(e["entity"])
    ei_fueler.on_built_entity(e["entity"])
    em_trains.on_built_entity(e["entity"])
    orbital_combinator.add(e["entity"])
    orbital_logistics.on_built_entity(e)
    ei_railgun_cooling.on_built_entity(e)
    ei_steam_train.on_built_entity(e)
    ei_camp_fire.on_built_entity(e)
    ei_teslas_legacy.on_built_entity(e)
    ei_singularity_lance.on_built_entity(e)
    ei_sawblade_turret.on_built_entity(e)
    ei_gaian_saucer_wake.on_built_entity(e)
end

function on_built_tile(e)
    -- Tile events only matter to the induction matrix right now, but they stay wrapped
    -- here for consistency with the entity dispatcher pattern.
    ei_induction_matrix.on_built_tile(e)
    ei_auric_inoculation_vat.on_built_tile(e)
end

function on_destroyed_entity(e)
    -- Build/destroy symmetry matters because several modules need to undo registration,
    -- spill/transfer items correctly, or distinguish pre-mining from after-the-fact death.
    if not e or not e["entity"] or not e["entity"].valid then
      return
    end

    -- "pre" means a player, robot, or platform initiated the removal and the entity is
    -- still present for live-neighborhood cleanup.
    -- "past" means the entity is already being removed due to death or a script destroy.
    if e["robot"] or e["player_index"] or e["platform"] then
        e["destroy_type"] = "pre"
    else
        e["destroy_type"] = "past"
    end

    -- Some subsystems accept either a robot reference or a player index here because
    -- they only need to know whether removed items should be handed back. Platform
    -- mining moves buffered items into the platform after the event, so keep this nil.
    local transfer = nil or e["robot"] or e["player_index"]

    if ei_fluid_safety.counts_for_fluid_handling(e["entity"]) then
        ei_register.deregister_fluid_entity(e["entity"])
    --[[
    elseif e["entity"].name == "ei-copper-beacon" or e["entity"].name == "ei-iron-beacon" then
        ei_register.teardown_master_slave("copper_beacon", e.entity, "slave_assembler")
        ]]
    end

    -- As with on_built_entity(), modules self-filter if the entity is irrelevant to them.
    ei_fusion_reactor.on_destroyed_entity(e["entity"], e["destroy_type"])
    ei_beacon_overload.on_destroyed_entity(e["entity"], e["destroy_type"])
    ei_neutron_collector.on_destroyed_entity(e["entity"], e["destroy_type"])
    ei_crystal_accumulator.on_destroyed_entity(e)
    ei_auric_inoculation_vat.on_destroyed_entity(e)
    ei_alien_spawner.on_destroyed_entity(e["entity"])
    ei_matter_stabilizer.on_destroyed_entity(e["entity"])
    ei_induction_matrix.on_destroyed_entity(e)
    ei_black_hole.on_destroyed_entity(e["entity"], transfer)
    ei_gate.on_destroyed_entity(e)
    ei_fueler.on_destroyed_entity(e["entity"], transfer)
    em_trains.on_destroyed_entity(e["entity"])
    orbital_combinator.rem(e["entity"])
    orbital_logistics.on_destroyed_entity(e)
    ei_railgun_cooling.on_destroyed_entity(e)
    ei_camp_fire.on_destroyed_entity(e)
    ei_singularity_lance.on_destroyed_entity(e)
    ei_sawblade_turret.on_destroyed_entity(e)
    ei_gaian_saucer_wake.on_destroyed_entity(e)
    -- Steam locomotives own extra helper entities that should disappear immediately on teardown.
    ei_steam_train.on_destroyed_entity(e["entity"])
end

function on_destroyed_tile(e)
    ei_induction_matrix.on_destroyed_tile(e)
    ei_auric_inoculation_vat.on_destroyed_tile(e)
end
