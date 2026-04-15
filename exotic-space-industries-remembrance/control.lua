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
ei_update_functions_length = 9 --# of entity updaters updater() goes through
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

local function forward_orbital_combinator_event(handler_name, event)
    local handler = orbital_combinator and orbital_combinator[handler_name]
    if handler then
        handler(event)
    end
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
        em_trains,
        ei_black_hole,
        ei_vulcanus_fumaroles,
    }

    for _, module_ref in ipairs(modules) do
        if module_ref and module_ref.get_runtime_status then
            pcall(module_ref.get_runtime_status)
        end
    end

    ei_runtime_scheduler.write_telemetry("runtime-heartbeat", ei_runtime_scheduler.status_snapshot())
end

--====================================================================================================
--EVENTS
--====================================================================================================
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
    -- Steam train wheel helpers are runtime-only entities, so init always rebuilds that cache
    -- from the live world instead of trusting whatever happened to be serialized last save.
    ei_steam_train.check_global()
    ei_steam_train.rebuild_runtime_state("init")
    ei_fueler.check_global()
    ei_fueler.rebuild_runtime_state("init")
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
-- a script-raise, or an entity death.
script.on_event({
    defines.events.on_built_entity,
    defines.events.on_robot_built_entity,
    defines.events.script_raised_built,
    defines.events.script_raised_revive,
    --defines.events.on_entity_cloned
    }, function(e)
    on_built_entity(e)
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
        forward_orbital_combinator_event("on_destroyed_entity", e)
    end
    on_destroyed_entity(e)
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

script.on_event(defines.events.on_selected_entity_changed, function(e)
    -- Selection-change handlers are lightweight enough to dispatch directly every time.
    ei_matter_stabilizer.on_selected_entity_changed(e)
end)

script.on_event(defines.events.on_player_cursor_stack_changed, function(e)
    -- Cursor changes matter for systems that temporarily replace the player's held item
    -- with a tool/selector and need to clean up when the cursor changes.
    ei_matter_stabilizer.on_player_cursor_stack_changed(e)
    ei_gate.on_player_cursor_stack_changed(e)
end)

script.on_event(defines.events.on_entity_logistic_slot_changed, function(e)
    -- Slot edits can wake both per-entity logistics guards and scanner cache invalidation.
    ei_spidertron_limiter.on_entity_logistic_slot_changed(e)
    orbital_combinator.on_entity_logistic_slot_changed(e)
end)

script.on_event(defines.events.on_entity_settings_pasted, function(e)
    -- Scanner cache invalidation also needs to notice settings pastes onto platform hubs.
    orbital_combinator.on_entity_settings_pasted(e)
end)

script.on_event(defines.events.on_space_platform_changed_state, function(e)
    -- Platform travel/state changes can move a platform into or out of a scanner surface snapshot.
    orbital_combinator.on_space_platform_changed_state(e)
end)

script.on_event(defines.events.on_cargo_pod_finished_ascending, function(e)
    forward_orbital_combinator_event("on_cargo_pod_finished_ascending", e)
end)

script.on_event(defines.events.on_cargo_pod_started_ascending, function(e)
    forward_orbital_combinator_event("on_cargo_pod_started_ascending", e)
end)

script.on_event(defines.events.on_cargo_pod_delivered_cargo, function(e)
    forward_orbital_combinator_event("on_cargo_pod_delivered_cargo", e)
end)

script.on_event(defines.events.on_object_destroyed, function(e)
    forward_orbital_combinator_event("on_object_destroyed", e)
end)

script.on_event(defines.events.on_rocket_launch_ordered, function(e)
    forward_orbital_combinator_event("on_rocket_launch_ordered", e)
    ei_rocket_launch_pollution.on_rocket_launch_ordered(e)
end)

script.on_event(defines.events.on_rocket_launched, function(e)
    ei_rocket_launch_pollution.on_rocket_launched(e)
end)

--RESEARCH RELATED
------------------------------------------------------------------------------------------------------
script.on_event(defines.events.on_research_finished, function(e)
    -- Research completion has both immediate balance implications (tech scaling, train buffs)
    ei_tech_scaling.on_research_finished()
    ei_teslas_legacy.on_research_finished(e)
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

local function get_valid_gui_entity(event)
    return ei_lib.get_valid_entity(event and event.entity)
end

local function get_valid_gui_element(event)
    local element = event and event.element or nil
    if element and element.valid then
        return element
    end

    return nil
end

-- GUI dispatch is centralized here because several systems open custom screens from
-- entity interactions, while button callbacks are routed by tag instead of entity name.
script.on_event(defines.events.on_gui_opened, function(event)
    local entity = get_valid_gui_entity(event)
    local name = entity and entity.name or nil

    if not name then
      return
    elseif name == "ei-fusion-reactor" then
        ei_fusion_reactor.open_gui(game.get_player(event.player_index) --[[@as LuaPlayer]])
    elseif ei_induction_matrix.core[name] or ei_induction_matrix.proxy[name] then
        ei_induction_matrix.open_gui(game.get_player(event.player_index) --[[@as LuaPlayer]])
    elseif name == "ei-black-hole" then
        ei_black_hole.open_gui(game.get_player(event.player_index) --[[@as LuaPlayer]])
    elseif name == "ei-gate" or name == "ei-gate-container" then
        ei_gate.on_gui_opened(event)
    elseif name == "ei-orbital-combinator" then
        forward_orbital_combinator_event("on_gui_opened", event)
    elseif name == "ei-fueler" then
        ei_fueler.open_gui(game.get_player(event.player_index))
    end
end)

script.on_event(defines.events.on_gui_closed, function(event)
    -- Close routing mirrors open routing, but some UIs close by element name rather than
    -- entity because the custom screen may have replaced the player's opened target.
    local entity = get_valid_gui_entity(event)
    local element = get_valid_gui_element(event)
    local name = entity and entity.name or nil
    local element_name = element and element.name or nil

    if name == "ei-fusion-reactor" then
       ei_fusion_reactor.close_gui(game.get_player(event.player_index) --[[@as LuaPlayer]])
    elseif element_name == "ei-induction-matrix-console" then
        ei_induction_matrix.close_gui(game.get_player(event.player_index) --[[@as LuaPlayer]])
    elseif name == "ei-black-hole" then
        ei_black_hole.close_gui(game.get_player(event.player_index) --[[@as LuaPlayer]])
    elseif name == "ei-gate-container" then
        ei_gate.close_gui(game.get_player(event.player_index) --[[@as LuaPlayer]])
    elseif name == "ei-orbital-combinator" or element_name == "ei-orbital-combinator-console" then
        forward_orbital_combinator_event("on_gui_closed", event)
    elseif name == "ei-fueler" then
        ei_fueler.close_gui(game.get_player(event.player_index))
    end
end)

script.on_event(defines.events.on_gui_click, function(event)
    -- Button clicks are dispatched by the parent GUI tag, which keeps the actual button
    -- names free to stay local to each feature's UI code.
    local element = get_valid_gui_element(event)
    if not element then return end

    local parent_gui = element.tags and element.tags.parent_gui
    if not parent_gui then return end

    if parent_gui == "ei-fusion-reactor-console" then
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
        forward_orbital_combinator_event("on_gui_click", event)
    elseif parent_gui == "ei-fueler-console" then
        ei_fueler.on_gui_click(event)
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

script.on_event(defines.events.on_gui_selection_state_changed, function(event)
    -- Selection-state changes are currently only meaningful for the gate console dropdowns.
    local element = get_valid_gui_element(event)
    if not element then return end

    local parent_gui = element.tags and element.tags.parent_gui
    if not parent_gui then return end

    if parent_gui == "ei-gate-console" then
        ei_gate.on_gui_selection_state_changed(event)
    end
end)

script.on_event(defines.events.on_script_trigger_effect, function(event)
    -- Script trigger effects are used for capsule/remote actions that originate from data-stage
    -- prototypes but need runtime behavior.
    ei_teslas_legacy.on_script_trigger_effect(event)
    if event.effect_id == "ei-gate-remote" then
        ei_gate.used_remote(event)
    end
end)

script.on_event(defines.events.on_player_left_game, function(event)
    -- Gate remote state is player-bound, so disconnects need explicit cleanup.
    ei_gate.on_player_left_game(event.player_index)
    ei_matter_stabilizer.on_player_left_game(event.player_index)
end)

--OTHER
------------------------------------------------------------------------------------------------------

script.on_configuration_changed(function(e)
    local mod_changes_present = next(e.mod_changes or {}) ~= nil
    local startup_settings_changed = e.mod_startup_settings_changed

    if mod_changes_present or startup_settings_changed then
        ei_global.check_init(e) -- Crystal_echo and startup-setting mirrors expect these tables.
        ei_flammable_rupture_scheduler.check_global()
        ei_vulcanus_fumaroles.check_global()
        if mod_changes_present and ei_fluid_safety and ei_fluid_safety.rebuild_fluid_runtime then
            ei_fluid_safety.rebuild_fluid_runtime("configuration-changed")
        end
        ei_echo_codex.handle_global_settings(e)
        ei_nauvis_pressure_grace.on_configuration_changed(e)
        ei_teslas_legacy.on_configuration_changed(e)
    end

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
        em_trains.on_research_finished(e) --catch upgrades that didn't previously apply
        em_trains_gui.mark_dirty()
        ei_lib.crystal_echo("⟦✦ TRANSCENSION RECOGNIZED ✦⟧","default-bold")
        ei_lib.crystal_echo("⫷ Sub-layer Recalibration Initiated ⫸")
        ei_lib.crystal_echo("⫷ Core Heuristics Have Shifted ⫸")
        ei_lib.crystal_echo("『CONFIGURATION CHANGED – BY WHOM, WE DARE NOT NAME","default-bold")
        ei_victory.init()  -- Required for Better Victory Screen
        orbital_combinator.check_init()
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
    end
)

script.on_event(defines.events.on_singleplayer_init, function(_event)
    -- Singleplayer save loads do not raise `on_player_joined_game`.
    -- Use the dedicated SP-init hook to replay the queued arrival ritual without
    -- deriving gameplay work from `on_load`.
    ei_echo_codex.queue_players(game.connected_players)
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

  local updates_needed = 1
  -- Compute update step from event.tick to keep the timing source explicit.
  local ei_update_step = (event.tick % ei_update_functions_length) + 1
   -- Hardcoded checks against ei_update_step are quick
   -- Whichever is less: max_updates_per_tick OR total of entities divided by the number of execution cycles
   if ei_update_step < 5 then -- Reduces the average number of `if` checks
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
                    ei_fluid_safety.service_fluid_runtime(updates_needed)
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
               if not ei_matter_stabilizer.update() then
                goto skip
               end
           end
       end

   else -- Otherwise, ei_update_step is >= 5

       if ei_update_step == 5 then
           -- Step 5 mirrors logistic/platform state into orbital combinators.
           local pending_work_count = 0
           if orbital_combinator then
               if orbital_combinator.get_pending_work_count then
                   pending_work_count = orbital_combinator.get_pending_work_count() or 0
               elseif orbital_combinator.get_bank_count then
                   pending_work_count = orbital_combinator.get_bank_count() or 0
               end
           end
           if pending_work_count > 0 then
                updates_needed = math.max(1,math.min(math.ceil(pending_work_count / divisor), ei_maxEntityUpdates))
                for i = 1, updates_needed do
                    local current_pending_work_count = 0
                    if orbital_combinator then
                        if orbital_combinator.get_pending_work_count then
                            current_pending_work_count = orbital_combinator.get_pending_work_count() or 0
                        elseif orbital_combinator.get_bank_count then
                            current_pending_work_count = orbital_combinator.get_bank_count() or 0
                        end
                    end
                    if current_pending_work_count == 0
                    or math.max(1,math.min(math.ceil(current_pending_work_count / divisor), ei_maxEntityUpdates)) ~= updates_needed then
                        goto skip
                    end
                    if not orbital_combinator.update() then
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

       elseif ei_update_step == 7 then
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
       end
   end
    ::skip::

   -- Essential updates that run every tick regardless of the scheduled branch above.
   -- These are generally timer-driven or need quick reactions that would feel wrong if
   -- delayed to a once-per-cycle slot.
    em_trains_gui.updater()
    ei_alien_spawner.update(event)
    ei_gaia.update(event)
    ei_induction_matrix.update(event)
    ei_black_hole.update(event)
    ei_steam_train.updater(event)
    ei_echo_codex.arrival_waves(event)
    ei_beacon_overload.updater(event)
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

    ei_beacon_overload.on_built_entity(e["entity"])
    ei_neutron_collector.on_built_entity(e["entity"])
    ei_fusion_reactor.on_built_entity(e["entity"])
    ei_matter_stabilizer.on_built_entity(e["entity"])
    ei_induction_matrix.on_built_entity(e)
    ei_black_hole.on_built_entity(e)
    ei_gate.on_built_entity(e)
    ei_alien_system.on_built_entity(e["entity"])
    ei_gaia.on_built_entity(e)
    ei_loaders_lib.on_built_entity(e["entity"])
    ei_fueler.on_built_entity(e["entity"])
    em_trains.on_built_entity(e["entity"])
    orbital_combinator.add(e["entity"])
    ei_steam_train.on_built_entity(e)
    ei_camp_fire.on_built_entity(e)
    ei_teslas_legacy.on_built_entity(e)
end

function on_built_tile(e)
    -- Tile events only matter to the induction matrix right now, but they stay wrapped
    -- here for consistency with the entity dispatcher pattern.
    ei_induction_matrix.on_built_tile(e)
end

function on_destroyed_entity(e)
    -- Build/destroy symmetry matters because several modules need to undo registration,
    -- spill/transfer items correctly, or distinguish pre-mining from after-the-fact death.
    if not e or not e["entity"] or not e["entity"].valid then
      return
    end

    -- "pre" means a player/robot initiated the removal and a transfer target may exist.
    -- "past" means the entity is already being removed due to death or a script destroy.
    if e["robot"] or e["player_index"] then
        e["destroy_type"] = "pre"
    else
        e["destroy_type"] = "past"
    end

    -- Some subsystems accept either a robot reference or a player index here because
    -- they only need to know whether removed items should be handed back.
    local transfer = nil or e["robot"] or e["player_index"]

    if ei_fluid_safety.counts_for_fluid_handling(e["entity"]) then
        ei_register.deregister_fluid_entity(e["entity"])
    --[[
    elseif e["entity"].name == "ei-copper-beacon" or e["entity"].name == "ei-iron-beacon" then
        ei_register.teardown_master_slave("copper_beacon", e.entity, "slave_assembler")
        ]]
    end

    -- As with on_built_entity(), modules self-filter if the entity is irrelevant to them.
    ei_beacon_overload.on_destroyed_entity(e["entity"], e["destroy_type"])
    ei_neutron_collector.on_destroyed_entity(e["entity"], e["destroy_type"])
    ei_alien_spawner.on_destroyed_entity(e["entity"])
    ei_matter_stabilizer.on_destroyed_entity(e["entity"])
    ei_induction_matrix.on_destroyed_entity(e)
    ei_black_hole.on_destroyed_entity(e["entity"], transfer)
    ei_gate.on_destroyed_entity(e)
    ei_fueler.on_destroyed_entity(e["entity"], transfer)
    em_trains.on_destroyed_entity(e["entity"])
    orbital_combinator.rem(e["entity"])
    ei_camp_fire.on_destroyed_entity(e)
    -- Steam locomotives own extra helper entities that should disappear immediately on teardown.
    ei_steam_train.on_destroyed_entity(e["entity"])
end

function on_destroyed_tile(e)
    ei_induction_matrix.on_destroyed_tile(e)
end
