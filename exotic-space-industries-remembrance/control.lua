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
ei_powered_beacon = require("scripts/control/powered-beacon")
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
local ei_nauvis_pressure_grace = require("scripts/control/nauvis-pressure-grace")

ei_fueler = require("scripts/control/fueler/fueler")
ei_fueler_informatron = require("scripts/control/fueler/informatron")

em_trains = require("scripts/control/em-trains/charger")
em_trains_gui = require("scripts/control/em-trains/gui")
em_trains_informatron = require("scripts/control/em-trains/informatron")

ei_steam_train = require("scripts/control/steam-train")
ei_camp_fire = require("scripts/control/camp-fire")
orbital_combinator = require("scripts/control/orbital-combinator")

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
    ei_lib.crystal_echo("☄ [Somnolent Awakening] — Gaia stirs from her dream-slumber; her shell begins to coalesce…")
    ei_lib.crystal_echo("✧ [Awakened Triumph] — Gaias shell stands firm, yet the dreams murmur endures…")
    ei_lib.crystal_echo("✧ [Gaias Heart] — The crystalline veins of Gaia pulse with life, awaiting the touch of her children…") 
    ei_echo_codex.youHaveArrived(event)
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
    ei_tech_scaling.on_tick()
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
    -- Spidertron limiter reacts to slot edits instead of polling logistics every tick.
    ei_spidertron_limiter.on_entity_logistic_slot_changed(e)
end)

script.on_event(defines.events.on_rocket_launched, function(e)
    -- Rocket pollution uses both "ordered" and "launched" so it can model the full launch flow.
    ei_rocket_launch_pollution.on_rocket_launched(e)
end)

script.on_event(defines.events.on_rocket_launch_ordered, function(e)
    ei_rocket_launch_pollution.on_rocket_launch_ordered(e)
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
end)

script.on_event(defines.events.on_resource_depleted, function(e)
    ei_mining_scars.on_resource_depleted(e)
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

-- GUI dispatch is centralized here because several systems open custom screens from
-- entity interactions, while button callbacks are routed by tag instead of entity name.
script.on_event(defines.events.on_gui_opened, function(event)
    local name = event.entity and event.entity.name

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
    elseif name == "ei-fueler" then
        ei_fueler.open_gui(game.get_player(event.player_index))
    end
end)

script.on_event(defines.events.on_gui_closed, function(event)
    -- Close routing mirrors open routing, but some UIs close by element name rather than
    -- entity because the custom screen may have replaced the player's opened target.
    local name = event.entity and event.entity.name
    local element_name = event.element and event.element.name

    if name == "ei-fusion-reactor" then
       ei_fusion_reactor.close_gui(game.get_player(event.player_index) --[[@as LuaPlayer]])
    elseif element_name == "ei-induction-matrix-console" then
        ei_induction_matrix.close_gui(game.get_player(event.player_index) --[[@as LuaPlayer]])
    elseif name == "ei-black-hole" then
        ei_black_hole.close_gui(game.get_player(event.player_index) --[[@as LuaPlayer]])
    elseif name == "ei-gate-container" then
        ei_gate.close_gui(game.get_player(event.player_index) --[[@as LuaPlayer]])
    elseif name == "ei-fueler" then
        ei_fueler.close_gui(game.get_player(event.player_index))
    end
end)

script.on_event(defines.events.on_gui_click, function(event)
    -- Button clicks are dispatched by the parent GUI tag, which keeps the actual button
    -- names free to stay local to each feature's UI code.
    local parent_gui = event.element.tags.parent_gui
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
    local parent_gui = event.element.tags.parent_gui
    if not parent_gui then return end

    if parent_gui == "ei-fusion-reactor-console" then
        ei_fusion_reactor.on_gui_value_changed(event)
    end
end)

script.on_event(defines.events.on_gui_selection_state_changed, function(event)
    -- Selection-state changes are currently only meaningful for the gate console dropdowns.
    local parent_gui = event.element.tags.parent_gui
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
    if next(e.mod_changes) ~= nil then
        -- This is the mod's broad migration/repair pass. It re-validates globals,
        -- clears stale cursor/gui state, reapplies runtime buffs, and reruns subsystem
        -- init that depends on changed prototypes or settings.
        ei_global.check_init(e) --Crystal_echo will fail without global color table
        ei_compat.check_init(e)
        ei_teslas_legacy.on_configuration_changed(e)
        ei_gate.on_configuration_changed(e)
        ei_echo_codex.handle_global_settings(e)
        ei_nauvis_pressure_grace.on_configuration_changed(e)
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
        ei_beacon_overload.refresh_all_overloads()
        ei_lib.crystal_echo("⟦✦ TRANSCENSION RECOGNIZED ✦⟧","default-bold")
        ei_lib.crystal_echo("⫷ Sub-layer Recalibration Initiated ⫸")
        ei_lib.crystal_echo("⫷ Core Heuristics Have Shifted ⫸")
        ei_lib.crystal_echo("『CONFIGURATION CHANGED – BY WHOM, WE DARE NOT NAME","default-bold")
        ei_victory.init()  -- Required for Better Victory Screen
        orbital_combinator.check_init()
    end

    -- Startup settings can change without giving the tech-scaling system any useful
    -- serialized state update, so always refresh the curve from live settings here.
    ei_tech_scaling.init()
end)

script.on_load(function()
    ei_tech_scaling.on_load()
    ei_teslas_legacy.on_load()
    ei_echo_codex.youHaveArrived(event)
end)

script.on_event(
  {
    defines.events.on_player_joined_game,
    defines.events.on_cutscene_cancelled,
    defines.events.on_cutscene_finished,
    defines.events.on_player_respawned
  },
    function(event)
        -- These events all represent moments where the player may need the codex arrival
        -- experience reapplied: joining, skipping cutscenes, or respawning.
        -- Refresh tech scaling here as well so opening an existing save repairs the
        -- multiplier even before the first simulation tick advances.
        ei_tech_scaling.on_player_joined_game()
        ei_echo_codex.youHaveArrived(event)
    end
)

--====================================================================================================
--HANDLERS
--====================================================================================================

--60/9=x6.66 (rounded up to 7) executions/handler/second, ie 7 rounds of 10 updates per entity per 60ticks (default, customizable update length 9-6000 ticks)
-- ei_update_step is now computed from game.tick to ensure multiplayer determinism
-- The list is kept here mostly as documentation of the scheduled subsystems; the actual
-- updater uses an explicit branch per step because the branch-specific queue sizing and
-- guard conditions differ between systems.
ei_update_functions = {
    function() ei_powered_beacon.update() end, -- deprecated legacy beacon updater
    function() ei_powered_beacon.update_fluid_storages() end, -- custom fluid entity queue
    function() ei_neutron_collector.update() end, -- neutron source/collector queue
    function() ei_matter_stabilizer.update() end, -- matter machine stabilization queue
    function() orbital_combinator.update() end, -- orbital logistics mirroring
    function() ei_fueler.updater() end, -- fueler task queue
    function() ei_gate.update() end, -- gate queue / breakpoint walker
    function() em_trains.train_updater() end, -- rolling stock logic
    function() em_trains.charger_updater() end, -- charger logic
}
local divisor = ei_ticksPerFullUpdate /  ei_update_functions_length -- How many times each entity updater is called per cycle

function updater(event)
  -- updater() has two tiers:
  -- 1. a scheduled tier that spreads heavy per-entity work across a fixed cycle
  -- 2. a mandatory tier that still runs every tick for systems that depend on timers
  --    or fast global reactions
  --
  -- game.tick decides which scheduled branch runs this tick. Because all peers compute
  -- the same step from the same tick, this stays deterministic in multiplayer.
  local updates_needed = 1
  -- Compute update step from game tick to ensure multiplayer determinism
  local ei_update_step = (event.tick % ei_update_functions_length) + 1
   -- Hardcoded checks against ei_update_step are quick
   -- Whichever is less: max_updates_per_tick OR total of entities divided by the number of execution cycles
   if ei_update_step < 5 then -- Reduces the average number of `if` checks
       if ei_update_step == 1 then
           -- Step 1 is the lightest branch and acts as a once-per-cycle sanity pass.
           -- It ensures storage still has the expected tables before later steps run.
           ei_global.check_init(event)
           ei_nauvis_pressure_grace.updater(event)
           ei_camp_fire.updater(event)
           ei_gaia.reforge_on_tick(event)
           --[[
           --now handled by Nonstandard beacons
           if storage.ei and storage.ei.spaced_updates and storage.ei.spaced_updates > 0 then
               updates_needed = math.max(1,math.min(math.ceil(storage.ei.spaced_updates / divisor), ei_maxEntityUpdates))
               end
           for i = 1, updates_needed do
               --Abort loop if the queue changes to avoid null reference
               if storage.ei and storage.ei.spaced_updates and
               math.max(1,math.min(math.ceil(storage.ei.spaced_updates / divisor), ei_maxEntityUpdates)) ~= updates_needed then
                   goto skip
                   end
               if not ei_powered_beacon.update() then
                goto skip
               end
            ]]

       elseif ei_update_step == 2 then
           -- Step 2 services the invalid fluid pipe logic
           if storage.ei and storage.ei.fluid_entity and storage.ei.fluid_entity_count and storage.ei.fluid_entity_count > 0 then
               updates_needed = math.max(1,math.min(math.ceil(storage.ei.fluid_entity_count / divisor), ei_maxEntityUpdates))
               for i = 1, updates_needed do
                    if storage.ei and storage.ei.fluid_entity and storage.ei.fluid_entity_count and
                    math.max(1,math.min(math.ceil(storage.ei.fluid_entity_count / divisor), ei_maxEntityUpdates)) ~= updates_needed then
                        goto skip
                        end
                    if not ei_powered_beacon.update_fluid_storages() then
                        goto skip
                    end
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
           if storage.ei and storage.ei.orbital_combinator_bank_count and storage.ei.orbital_combinator_bank_count > 0 then
                updates_needed = math.max(1,math.min(math.ceil(storage.ei.orbital_combinator_bank_count / divisor), ei_maxEntityUpdates))
                 end
            for i = 1, updates_needed do
               if storage.ei and storage.ei.orbital_combinator_bank_count and
               math.max(1,math.min(math.ceil(storage.ei.orbital_combinator_bank_count / divisor), ei_maxEntityUpdates)) ~= updates_needed then
                    goto skip
                    end
                if not orbital_combinator.update() then
                goto skip
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
               if not em_trains.train_updater(updates_needed) then
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
               if not em_trains.charger_updater(updates_needed) then
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
    ei_rocket_launch_pollution.updater(event)
    ei_fulgora_day_length_variation.updater(event)
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
    if ei_powered_beacon.counts_for_fluid_handling(e["entity"]) then
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
    --powered beacons
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

    if ei_powered_beacon.counts_for_fluid_handling(e["entity"]) then
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
