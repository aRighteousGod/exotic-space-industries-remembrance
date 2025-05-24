if script.active_mods["gvv"] then require("__gvv__.gvv")() end
require("util")
--====================================================================================================
--REQUIREMENTS
--====================================================================================================

ei_lib = require("lib/lib")
ei_data = require("lib/data")
ei_rng = require("lib/ei_rng")
ei_echo_codex = require("lib/echo_codex")

-- Used if gaia spawned in malformed, called in reforge_gaia
local ei_full_gaia_map_gen_settings = require("prototypes/alien_structures/reforge-gaia-table")



local ei_tech_scaling = require("scripts/control/tech_scaling")
local ei_global = require("scripts/control/global")
local ei_register = require("scripts/control/register_util")
local ei_powered_beacon = require("scripts/control/powered_beacon")
local ei_beacon_overload = require("scripts/control/beacon_overload")
local ei_spidertron_limiter = require("scripts/control/spidertron_limiter")


ei_victory = require("scripts/control/victory_disabler")
ei_alien_spawner = require("scripts/control/alien_spawner")
ei_informatron = require("scripts/control/informatron")
ei_milestone_preset = require("scripts/control/milestone_preset")
ei_matter_stabilizer = require("scripts/control/matter_stabilizer")
ei_neutron_collector = require("scripts/control/neutron_collector")
ei_fusion_reactor = require("scripts/control/fusion_reactor")
ei_induction_matrix = require("scripts/control/induction_matrix")
ei_black_hole = require("scripts/control/black_hole")
ei_informatron_messager = require("scripts/control/informatron_messager")
ei_gaia = require("scripts/control/gaia")
ei_gate = require("scripts/control/gate")
ei_alien_system = require("scripts/control/alien_system")
ei_debug = require("scripts/control/debug")
ei_compat = require("scripts/control/compat")
ei_loaders_lib = require("lib/ei_loaders_lib")

ei_fueler = require("scripts/control/fueler/fueler")
ei_fueler_informatron = require("scripts/control/fueler/informatron")

em_trains = require("scripts/control/em-trains/charger")
em_trains_gui = require("scripts/control/em-trains/gui")
em_trains_informatron = require("scripts/control/em-trains/informatron")

orbital_combinator = require("scripts/control/orbital_combinator")

--====================================================================================================
--K2_CONTROL
--====================================================================================================

local handler = require("__core__.lualib.event_handler")

handler.add_libraries({
  require("__flib__.gui"),

  require("K2_CONTROL.migrations"),
  require("K2_CONTROL.intergalactic-transceiver"),
  require("K2_CONTROL.planetary-teleporter-gui"), -- Must be before planetary-teleporter
  require("K2_CONTROL.planetary-teleporter"),
})

--====================================================================================================
--EVENTS
--====================================================================================================



--INIT
------------------------------------------------------------------------------------------------------
script.on_init(function()
    remote.call("freeplay", "set_disable_crashsite", true)

    -- setup storage table
    ei_global.init()
    ei_global.check_init()

    -- init other
    ei_tech_scaling.init()
    ei_register.init({"copper_beacon"}, true)
    ei_register.init({"fluid_entity"}, false)

    -- disable vanilla victory condition by rocket launch
    ei_victory.init()
    em_trains.check_global()
    em_trains_gui.mark_dirty()
    ei_compat.check_init()
    orbital_combinator.check_init()
    ei_lib.crystal_echo("☄ [Somnolent Awakening] — Gaia stirs from her dream-slumber; her shell begins to coalesce…")
    game.planets["gaia"]:create_surface(ei_full_gaia_map_gen_settings) --works
    ei_lib.crystal_echo("✧ [Awakened Triumph] — Gaias shell stands firm, yet the dreams murmur endures…")
    ei_lib.crystal_echo("✧ [Gaias Heart] — The crystalline veins of Gaia pulse with life, awaiting the touch of her children…") 
    storage.ei.gaia_reforged = 1 --0=pre reforge, 1 = post reforge/valid surface, additional #s for future planetary evolution
end)

--ENTITY RELATED
------------------------------------------------------------------------------------------------------

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
    on_destroyed_entity(e)
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

script.on_event(defines.events.on_tick, function() 
    updater()
end)
--[[
script.on_nth_tick(settings.startup["ei-ticks_per_spaced_update"].value, function(e)
    spaced_updater()
end)
]]

script.on_nth_tick(6000, function(e)
    ei_compat.nth_tick(e)
  end)
  

script.on_event(defines.events.on_console_command, function(e)
    ei_alien_spawner.give_tool(e)
    ei_gaia.spawn_command(e)
    ei_debug.teleport_to(e)
end)

script.on_event(defines.events.on_player_selected_area, function(e)
    ei_alien_spawner.on_player_selected_area(e)
    ei_alien_system.on_player_selected_area(e)
end)

script.on_event(defines.events.on_selected_entity_changed, function(e)
    ei_matter_stabilizer.on_selected_entity_changed(e)
end)

script.on_event(defines.events.on_player_cursor_stack_changed, function(e)
    ei_matter_stabilizer.on_player_cursor_stack_changed(e)
end)

script.on_event(defines.events.on_entity_logistic_slot_changed, function(e)
    ei_spidertron_limiter.on_entity_logistic_slot_changed(e)
end)

--RESEARCH RELATED
------------------------------------------------------------------------------------------------------
script.on_event(defines.events.on_research_finished, function(e)

    -- set new tech costs
    ei_tech_scaling.on_research_finished()

    -- notify player for informatron changes
    ei_informatron_messager.on_research_finished(e)

    em_trains.on_research_finished(e)

end)

--WORLD RELATED
------------------------------------------------------------------------------------------------------
script.on_event(defines.events.on_chunk_generated, function(e)
    ei_alien_spawner.on_chunk_generated(e)
end)

script.on_event(defines.events.on_player_respawned, function(event)
  local player = game.players[event.player_index]
  if player.character then
    player.character.clear_items_inside()
  end
end)

--GUI RELATED
-----------------------------------------------------------------------------------------------------

function rocket_silo_gui_open(event)
	if event.gui_type ~= defines.gui_type.entity then return end
	if event.entity.type ~= "rocket-silo" then return end
  game.get_player(event.player_index).cheat_mode = true
end

function rocket_silo_gui_close(event)
	if event.gui_type ~= defines.gui_type.entity then return end
	if event.entity.type ~= "rocket-silo" then return end
  game.get_player(event.player_index).cheat_mode = false
end

script.on_event(defines.events.on_gui_opened, function(event)
    local name = event.entity and event.entity.name

    if not name then
      return
    elseif name == "ei-fusion-reactor" then
        ei_fusion_reactor.open_gui(game.get_player(event.player_index) --[[@as LuaPlayer]])
    elseif ei_induction_matrix.core[name] then
        ei_induction_matrix.open_gui(game.get_player(event.player_index) --[[@as LuaPlayer]])
    elseif name == "ei-black-hole" then
        ei_black_hole.open_gui(game.get_player(event.player_index) --[[@as LuaPlayer]])
    elseif name == "ei-gate-container" then
        ei_gate.open_gui(game.get_player(event.player_index) --[[@as LuaPlayer]])
    elseif name == "ei_fueler" then
        ei_fueler.open_gui(game.get_player(event.player_index))
    end

    rocket_silo_gui_open(event)
end)

script.on_event(defines.events.on_gui_closed, function(event)
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
    elseif name == "ei_fueler" then
        ei_fueler.close_gui(game.get_player(event.player_index))
    end

    rocket_silo_gui_close(event)
end)

script.on_event(defines.events.on_gui_click, function(event)
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
    elseif parent_gui == "ei_fueler-console" then
        ei_fueler.on_gui_click(event)
    elseif parent_gui == "mod_gui" then
      em_trains_gui.on_gui_click(event)
    elseif parent_gui == "em_trains_mod-gui" then
      em_trains_gui.on_gui_click(event)

    end


end)

script.on_event(defines.events.on_gui_value_changed, function(event)
    local parent_gui = event.element.tags.parent_gui
    if not parent_gui then return end

    if parent_gui == "ei-fusion-reactor-console" then
        ei_fusion_reactor.on_gui_value_changed(event)
    end
end)

script.on_event(defines.events.on_gui_selection_state_changed, function(event)
    local parent_gui = event.element.tags.parent_gui
    if not parent_gui then return end

    if parent_gui == "ei-gate-console" then
        ei_gate.on_gui_selection_state_changed(event)
    end
end)

script.on_event(defines.events.on_script_trigger_effect, function(event)
    if event.effect_id == "ei-gate-remote" then
        ei_gate.used_remote(event)
    end
end)

--OTHER
------------------------------------------------------------------------------------------------------

local patch_resources = {
  "ei-phytogas-patch",
  "ei-cryoflux-patch",
  "ei-ammonia-patch",
  "ei-morphium-patch",
  "ei-coal-gas-patch"
}

function surface_contains_any_resources(surface)
  if not surface or not surface.count_entities_filtered then
    log("surface_contains_any_resources: invalid surface object passed")
    return false
  end
  for _, resource_name in pairs(patch_resources) do
    local found = surface.count_entities_filtered{
      name = resource_name,
      type = "resource"
    }
    if found > 0 then
      return true, resource_name, found
    end
  end
  return false
end

--Uncomment me to teleport to Gaia to test reforge_gaia_surface produced valid result :)

commands.add_command("goto-gaia", "Teleport to Gaia's surface", function(cmd)
    local player = game.get_player(cmd.player_index)
    if not player then return end
    local planet = game.planets["gaia"]
    local surface = planet and planet.surface
    if not surface then
        player.print("[Exotic Space Industries] Gaia surface not found.")
        return
    end
    local position = {0, 0}  -- center of the world
    player.teleport(position, surface)
    ei_lib.crystal_echo("✈ [Astral Transit] — " .. player.name .. " arrives upon Gaia’s crust.")
end)

function reforge_gaia_surface()
    --1.5.7 -> 1.5.8 migration
    local legacy = game.surfaces["Gaia"]
    local canonical = game.planets["gaia"]
    if legacy and canonical and not canonical.surface then
      log("[Gaia Migration] Rebinding 1.5.7 'Gaia' surface to prototype 'gaia'")
      legacy.name = "gaia"
      canonical.associate_surface(legacy)
      ei_lib.crystal_echo("☲ [Ghost Reclaimed] — The lost echo of 'Gaia' has been bound to its true self. Memory and flesh rejoin.")
    end
    if storage.ei.gaia_reforged == 1 then return end
    local planet_name = "gaia"
    local planet = game.planets[planet_name]
    if not planet then
        ei_lib.crystal_echo("☠ [Void’s Echo] — Gaia’s name lies unwritten; the rite dissolves into silent void.")
        return
    end

    local gaia_settings = ei_full_gaia_map_gen_settings
    local function checksum(tbl)
        local s = serpent.block(tbl, {sortkeys=true, numformat="%0.8f"})
        local sum = 0 for i = 1, #s do sum = (sum + s:byte(i)) % 2147483647 end
        return sum
    end

    -- 1) Grab old Gaia surface, if any
    local old_surface = planet.surface

    -- 2) If old exists and matches desired settings with resources, do nothing
    if old_surface and old_surface.valid then
        if checksum(old_surface.map_gen_settings) == checksum(gaia_settings) then
            local has, res, cnt = surface_contains_any_resources(old_surface)
            if has then
                ei_lib.crystal_echo("✔ [Echo Intact] — " .. res .. " crystals detected (" .. cnt .. "). Gaia stands.")
                storage.ei.gaia_reforged = 1
                return
            end
        end
    end

    -- 3a) Evacuate any players still on old Gaia
    if old_surface and old_surface.valid then
        for _, player in pairs(game.connected_players) do
            if player.surface == old_surface then
                ei_lib.crystal_echo("⚠ [Displacement] — Shunting " .. player.name .. " off world.")
                local x = ei_rng.int(player.name .. "-x", 0, 20) or 0
                local y = ei_rng.int(player.name .. "-y", 0, 20) or 0
                if not x then x = 0 end
                if not y then y = 0 end
                player.teleport({x, y}, "nauvis")
                ei_echo_codex.youHaveArrived(player)
            end
        end
        -- 3b) Preemptively cleanse all entities on Gaia before destroying it
        for _, entity in pairs(old_surface.find_entities()) do
            if entity.valid then
            pcall(function()
                entity.destroy({raise_destroy = true})
            end)
            end
        end
        ei_lib.crystal_echo("✖ [Silence] — No crystal veins resonate. Calling Gaia into the void…")
    end

    -- 4) Stage a new surface via low-level API
    local map_gen = util.table.deepcopy(gaia_settings)
    --map_gen.name = nil
    local new_surface = game.create_surface("Gaia", map_gen) --Capital because the other is gaia
    if not new_surface or not new_surface.valid then
        ei_lib.crystal_echo("☠ [Invocation Fracture] — Failed to birth Gaia’s new form; dusk endures.")
        return
    end
    -- 5) Delete old surface after associating
    if old_surface and old_surface.valid then
        game.delete_surface(old_surface.name)
    end
    -- 6) Schedule deferred recreation
    script.on_nth_tick(1, function()
        -- Abort if already reforged externally
        if storage.ei.gaia_reforged == 1 then
            script.on_nth_tick(1, nil)
            return
        end
        -- If old surface still exists, wait
        if game.surfaces[planet_name] then return end
        new_surface.name = "gaia" --Now we can uncapitalize it
        -- 7) Associate new surface with the planet
        planet.associate_surface(new_surface)
        -- 8) Update player, save settings, save reforge status, remove scheduler
        ei_lib.crystal_echo("✧ [Resurrection] — Gaia’s heart ignites once more upon a cleansed crust.")
        storage.ei.original_gaia_settings = gaia_settings --In case a mod modifies it, we'll know
        storage.ei.gaia_reforged = 1
        script.on_nth_tick(1, nil)
    end)
end


script.on_configuration_changed(function(e)
    ei_global.check_init() --Crystal_echo will fail without global color table
    -- Only trigger when *this* mod changes version
    if e.mod_changes and e.mod_changes["exotic-space-industries-remembrance"] then
--[[
        local val = ei_lib.config("em_updater_que") or "Beam"
        if val == "Beam" then
            storage.ei.em_train_que = 1
        elseif val == "Ring" then
            storage.ei.em_train_que = 2 --faster to compare a number
        else
            storage.ei.em_train_que = 0
        end
    
        val = ei_lib.config("em_updater_que_width")
        storage.ei.que_width = (val ~= nil) and val or 6
    
        val = ei_lib.config("em_updater_que_transparency")
        storage.ei.que_transparency = ((val ~= nil) and val or 80) / 100
    
        val = ei_lib.config("em_updater_que_timetolive")
        storage.ei.que_timetolive = (val ~= nil) and val or 60
    
        val = ei_lib.config("em_train_glow_toggle")
        storage.ei.em_train_glow_toggle = (val ~= nil) and val or true
    
        val = ei_lib.config("em_train_glow_timetolive")
        storage.ei.em_train_glow_timeToLive = (val ~= nil) and val or 60
    
        val = ei_lib.config("em_charger_glow_toggle")
        storage.ei.em_charger_glow = (val ~= nil) and val or true
    
        val = ei_lib.config("em_charger_glow_timetolive")
        storage.ei.em_charger_glow_timeToLive = (val ~= nil) and val or 60
        local modes = {
            [0] = "✦ NULL-STATE :: INERTIA LOCKED",
            [1] = "✴ AXIS-FIRE :: DIRECTED CONVERGENCE BEAM",
            [2] = "⟁ OMNI-RESONANCE :: PHASE RING ARRAY"
        }
        ei_lib.crystal_echo("『EM CHARGER QUE MODE HAS SHIFTED』 → "..modes[storage.ei.em_train_que].." ("..storage.ei.em_train_que..")","default-bold")
    ]]
        echo_codex.handle_global_settings()
        em_trains.check_global() --no nil tables
        em_trains.check_buffs() --updates global buff vals
        em_trains.printBuffStatus()
        em_trains.reinitialize_chargers() --applies updated buffs
        em_trains.reinitialize_trains()
        em_trains.update_rail_counts()
        em_trains_gui.mark_dirty()
    
        ei_lib.crystal_echo("⟦✦ TRANSCENSION RECOGNIZED ✦⟧","default-bold")
        ei_lib.crystal_echo("⫷ Sub-layer Recalibration Initiated ⫸")
        ei_lib.crystal_echo("⫷ Core Heuristics Have Shifted ⫸")
        ei_lib.crystal_echo("『CONFIGURATION CHANGED – BY WHOM, WE DARE NOT NAME","default-bold")

        reforge_gaia_surface() --Must be called AFTER check_global

    end
    ei_tech_scaling.init()
    ei_victory.init()  -- Required for Better Victory Screen
    orbital_combinator.check_init()
end)

local function youHaveArrived(player)
    if not player then
        log("youHaveArrived received null player")
        return
    end
    local surface = player.surface
    local pos = player.position
    local force = player.force or 1
    if not surface or not pos or not force then
        log("youHaveArrived received null surface or pos or force for player ")
        return
    else
        -- Draw multiple electric beams in a ring around the player
        for i = 1, 12 do
            local angle = (math.pi * 2 / 12) * i
            local offset = {
                x = pos.x + math.cos(angle) * 5,
                y = pos.y + math.sin(angle) * 5
            }
            surface.create_entity{
                name = "electric-beam",
                source = offset,
                position = pos,
                target = player,
                duration = 120,
                force = force
            }
        end

        -- Summon a "portal"—use smoke or other suitable entity
        for i = 1, 5 do
            surface.create_entity{
                name = "big-artillery-explosion", -- visually dramatic
                position = {
                    x = pos.x + ei_rng.float("portalboom") * 2 - 1,
                    y = pos.y + ei_rng.float("portalboom") * 2 - 1
                },
                position = pos,
                force = force
            }
        end

        surface.create_trivial_smoke{
            name = "electric-smoke",
            position = pos
        }
        local player_indices = {}
        for _, player in pairs(game.connected_players) do
          table.insert(player_indices, player.index)
        end
        if not ei_lib.getn(player_indices) then return end
        rendering.draw_light{
            sprite = "utility/light_medium",
            target = pos,
            surface = surface,
            color = {r = 0.6, g = 0.1, b = 1.0},
            intensity = 1.5,
            scale = 4.0,
            time_to_live = 180,
            players = player_indices
        }

    end
ei_lib.crystal_echo("Fragments of GAIA's lament ripple across space-time...")
ei_lib.crystal_echo("⟬ THE SYSTEM STIRS ⟭","default-bold")
ei_lib.crystal_echo("⚠️ YOU HAVE BEEN SEEN ⚠️","default-bold")
end
script.on_event(
  {
    defines.events.on_player_joined_game,
    defines.events.on_cutscene_cancelled,
    defines.events.on_cutscene_finished
  },
  function(event)
    local player = game.get_player(event.player_index)
    if player and player.valid and player.character then
        ei_echo_codex.youHaveArrived(player.character)
        if player.name then
            log(">> Arrival event triggered for player: " .. player.name)
        end
    end
  end
)

--====================================================================================================
--HANDLERS
--====================================================================================================
ei_update_step = 0  -- Tracks which entity type is updated next, skips first tick
ei_update_functions = {
    function() ei_powered_beacon.update() end, --1
    function() ei_powered_beacon.update_fluid_storages() end, --2
    function() ei_neutron_collector.update() end, --3
    function() ei_matter_stabilizer.update() end, --4
    function() orbital_combinator.update() end, --5
    function() ei_fueler.updater() end, --6
    function() ei_gate.update() end, --7
    function() em_trains.train_updater() end,--8
    function() em_trains.charger_updater() end,--9
}
--60/9=x6.66 (rounded up to 7) executions/handler/second, ie 7 rounds of 10 updates per 60ticks (default, customizable update length 9-6000 ticks)
ei_ticksPerFullUpdate = settings.startup["ei_ticks_per_full_update"].value -- How many ticks to spread updates over
local divisor = ei_ticksPerFullUpdate /  ei_lib.getn(ei_update_functions) -- How many times each entity updater is called per cycle
ei_maxEntityUpdates = settings.startup["ei-max_updates_per_tick"].value -- Ceiling on entity updates per tick
ei_update_functions_length = ei_lib.getn(ei_update_functions)
local divisor = ei_ticksPerFullUpdate /  ei_update_functions_length -- How many times each entity updater is called per cycle
function updater()
  local updates_needed = 1
   -- Hardcoded checks against ei_update_step are quick
   -- Whichever is less: max_updates_per_tick OR total of entities divided by the number of execution cycles
   if ei_update_step < 5 then -- Reduces the average number of `if` checks
--        if ei_update_step == 0 then
--            ei_global.check_init()
--            ei_update_step = 1
--            end
       if ei_update_step == 1 then
           if storage.ei and storage.ei.spaced_updates and storage.ei.spaced_updates > 0 then
               updates_needed = math.max(1,math.min(math.ceil(storage.ei.spaced_updates / divisor), ei_maxEntityUpdates))
               end
           for i = 1, updates_needed do
               --Abort loop if the queue changes to avoid null reference
               if storage.ei and storage.ei.spaced_updates and
               math.max(1,math.min(math.ceil(storage.ei.spaced_updates / divisor), ei_maxEntityUpdates)) ~= updates_needed then
                   goto skip
                   end
               ei_powered_beacon.update()
           end

       elseif ei_update_step == 2 then
           if storage.ei and storage.ei.spaced_updates and storage.ei.spaced_updates > 0 then
               updates_needed = math.max(1,math.min(math.ceil(storage.ei.spaced_updates / divisor), ei_maxEntityUpdates))
               end
           updates_needed = math.min(math.ceil(storage.ei.spaced_updates / divisor), ei_maxEntityUpdates)
           for i = 1, updates_needed do
               if storage.ei and storage.ei.spaced_updates and
               math.max(1,math.min(math.ceil(storage.ei.spaced_updates / divisor), ei_maxEntityUpdates)) ~= updates_needed then
                   goto skip
                   end
               ei_powered_beacon.update_fluid_storages()
           end

       elseif ei_update_step == 3 then
           if storage.ei and storage.ei["neutron_sources"] and  ei_lib.getn(storage.ei["neutron_sources"]) then
               updates_needed = math.max(1,math.min(math.ceil( ei_lib.getn(storage.ei["neutron_sources"]) / divisor), ei_maxEntityUpdates))
               end
           for i = 1, updates_needed do
               if storage.ei and storage.ei["neutron_sources"] and
               math.max(1,math.min(math.ceil( ei_lib.getn(storage.ei["neutron_sources"]) / divisor), ei_maxEntityUpdates)) ~= updates_needed then
                   goto skip
                   end
               ei_neutron_collector.update()
           end

       elseif ei_update_step == 4 then
           if storage.ei and storage.ei.matter_machines and #storage.ei.matter_machines then
               updates_needed = math.max(1,math.min(math.ceil( ei_lib.getn(storage.ei.matter_machines) / divisor), ei_maxEntityUpdates))
               end
           for i = 1, updates_needed do
               if storage.ei and storage.ei.matter_machines and
               math.max(1,math.min(math.ceil( ei_lib.getn(storage.ei.matter_machines) / divisor), ei_maxEntityUpdates)) ~= updates_needed then
                   goto skip
                   end
               ei_matter_stabilizer.update()
           end
       end

   else -- Otherwise, ei_update_step is >= 5

       if ei_update_step == 5 then
           if storage.ei and storage.ei.orbital_combinators and  ei_lib.getn(storage.ei.orbital_combinators) then
                updates_needed = math.max(1,math.min(math.ceil( ei_lib.getn(storage.ei.orbital_combinators) / divisor), ei_maxEntityUpdates))
                end
           for i = 1, updates_needed do
               if storage.ei and storage.ei.orbital_combinators and
               math.max(1,math.min(math.ceil(ei_lib.getn(storage.ei.orbital_combinators) / divisor), ei_maxEntityUpdates)) ~= updates_needed then
                   goto skip
                   end
               orbital_combinator.update()
           end

       elseif ei_update_step == 6 then
           if storage.ei and storage.ei.fueler_queue and #storage.ei.fueler_queue then
               updates_needed = math.max(1,math.min(math.ceil( ei_lib.getn(storage.ei.fueler_queue) / divisor), ei_maxEntityUpdates))
               end
           for i = 1, updates_needed do
               if storage.ei and storage.ei.fueler_queue and
               math.max(1,math.min(math.ceil( ei_lib.getn(storage.ei.fueler_queue) / divisor), ei_maxEntityUpdates)) ~= updates_needed then
                   goto skip
                   end
               ei_fueler.updater()
           end

       elseif ei_update_step == 7 then
           if storage.ei and storage.ei.gate and storage.ei.gate.gate and  ei_lib.getn(storage.ei.gate.gate) then
                updates_needed = math.max(1,math.min(math.ceil( ei_lib.getn(storage.ei.gate.gate) / divisor), ei_maxEntityUpdates))
                end
           for i = 1, updates_needed do
               if storage.ei and storage.ei.gate and storage.ei.gate.gate and
               math.max(1,math.min(math.ceil( ei_lib.getn(storage.ei.gate.gate) / divisor), ei_maxEntityUpdates)) ~= updates_needed then
                   goto skip
                   end
               ei_gate.update()
           end

       elseif ei_update_step == 8 then
           em_trains.check_global()

           if storage.ei_emt and storage.ei_emt.trains and ei_lib.getn(storage.ei_emt.trains) then
                updates_needed = math.max(1,math.min(math.ceil(ei_lib.getn(storage.ei_emt.trains) / divisor), ei_maxEntityUpdates))
                end
           for i = 1, updates_needed do
               if storage.ei_emt and storage.ei_emt.trains and
               math.max(1,math.min(math.ceil( ei_lib.getn(storage.ei_emt.trains) / divisor), ei_maxEntityUpdates)) ~= updates_needed then
                   goto skip
                   end
               if not em_trains.train_updater() then -- only try once if nil
                   goto skip
                   end
           end
       elseif ei_update_step == 9 then
           em_trains.check_global()
           if storage.ei_emt and storage.ei_emt.chargers and  ei_lib.getn(storage.ei_emt.chargers) then
                updates_needed = math.max(1,math.min(math.ceil( ei_lib.getn(storage.ei_emt.chargers) / divisor), ei_maxEntityUpdates))
                end
           for i = 1, updates_needed do
               if storage.ei_emt and storage.ei_emt.chargers and
               math.max(1,math.min(math.ceil(ei_lib.getn(storage.ei_emt.chargers) / divisor), ei_maxEntityUpdates)) ~= updates_needed then
                   goto skip
                   end
               if not em_trains.charger_updater() then -- only try once if nil
                   goto skip
                   end
           end
       end
   end
    ::skip::
    em_trains_gui.updater()
   -- Increment ei_update_step and loop back to 1 if needed
   ei_update_step = ei_update_step + 1
   if ei_update_step > ei_update_functions_length then --lol faster
       ei_update_step = 1
   end

   -- Essential updates that run every tick (e.g., timers, global effects)
   ei_alien_spawner.update()
   ei_gaia.update()
   ei_induction_matrix.update()
   ei_black_hole.update()
end

--Check global once per entity updater cycle
local globalCheckTicks = ei_ticksPerFullUpdate
script.on_nth_tick(globalCheckTicks, function(event)
    ei_global.check_init()
end)

--[[
function spaced_updater()
    ei_global.check_init()
    ei_gate.update()
end

-- Run fueler updates every 10 ticks
script.on_nth_tick(10, function()
  ei_fueler.updater()
end)

-- Run trains updates every 60 ticks
script.on_nth_tick(60, function()
  em_trains_charger.updater()
  em_trains_gui.updater()
  ei_gaia.update()
  ei_alien_spawner.update()
end)
]]
function on_built_entity(e)
    if not e["entity"] then
      return
    end

    if not e["entity"].valid then
      return
    end

    if ei_powered_beacon.counts_for_fluid_handling(e["entity"]) then
        ei_register.register_fluid_entity(e["entity"])
    end

    if e["entity"].name == "ei-copper-beacon" then
        local master_unit = ei_register.register_master_entity("copper_beacon", e["entity"])
        local slave_entity = ei_register.make_slave("copper_beacon", master_unit, "ei-copper-beacon_slave", {x = 0,y = 0})
        ei_register.link_slave("copper_beacon", master_unit, slave_entity, "slave_assembler")
        ei_register.init_beacon("copper_beacon", master_unit)
        ei_register.add_spaced_update()
        ei_beacon_overload.on_built_entity(e["entity"])
    end

    if e["entity"].name == "ei-iron-beacon" then
        local master_unit = ei_register.register_master_entity("copper_beacon", e["entity"])
        local slave_entity = ei_register.make_slave("copper_beacon", master_unit, "ei-iron-beacon_slave", {x = 0,y = 0})
        ei_register.link_slave("copper_beacon", master_unit, slave_entity, "slave_assembler")
        ei_register.init_beacon("copper_beacon", master_unit)
        ei_register.add_spaced_update()
        ei_beacon_overload.on_built_entity(e["entity"])
    end

--    ei_beacon_overload.on_built_entity(e["entity"])
    ei_neutron_collector.on_built_entity(e["entity"])
    ei_fusion_reactor.on_built_entity(e["entity"])
    ei_matter_stabilizer.on_built_entity(e["entity"])
    ei_induction_matrix.on_built_entity(e["entity"])
    ei_black_hole.on_built_entity(e["entity"])
    ei_gate.on_built_entity(e["entity"])
    ei_alien_system.on_built_entity(e["entity"])
    ei_gaia.on_built_entity(e["entity"])
    ei_loaders_lib.on_built_entity(e["entity"])
    ei_fueler.on_built_entity(e["entity"])
    em_trains.on_built_entity(e["entity"])
    orbital_combinator.add(e["entity"])
end


function on_built_tile(e)
    ei_induction_matrix.on_built_tile(e)
end


function on_destroyed_entity(e)
    if not e["entity"] then
        return
    end

    if not e["entity"].valid then
      return
    end

    if e["robot"] or e["player_index"] then
        e["destroy_type"] = "pre"
    else
        e["destroy_type"] = "past"
    end

    local transfer = nil or e["robot"] or e["player_index"]

    if ei_powered_beacon.counts_for_fluid_handling(e["entity"]) then
        ei_register.deregister_fluid_entity(e["entity"])
    end

    if e["entity"].name == "ei-copper-beacon" then
        local master_unit = e["entity"].unit_number
        if not storage.ei.copper_beacon.master[master_unit] then
            goto continue
        end
        local slave_entity = storage.ei.copper_beacon.master[master_unit].slaves.slave_assembler
        ei_register.unregister_slave_entity("copper_beacon", slave_entity ,e["entity"], true)
        ei_register.unregister_master_entity("copper_beacon", master_unit)
        ei_register.subtract_spaced_update()
        ::continue::
    end

    if e["entity"].name == "ei-iron-beacon" then
        local master_unit = e["entity"].unit_number
        if not storage.ei.copper_beacon.master[master_unit] then
            goto continue
        end
        local slave_entity = storage.ei.copper_beacon.master[master_unit].slaves.slave_assembler
        ei_register.unregister_slave_entity("copper_beacon", slave_entity ,e["entity"], true)
        ei_register.unregister_master_entity("copper_beacon", master_unit)
        ei_register.subtract_spaced_update()
        ::continue::
    end

    ei_beacon_overload.on_destroyed_entity(e["entity"], e["destroy_type"])
    ei_neutron_collector.on_destroyed_entity(e["entity"], e["destroy_type"])
    ei_alien_spawner.on_destroyed_entity(e["entity"])
    ei_matter_stabilizer.on_destroyed_entity(e["entity"])
    ei_induction_matrix.on_destroyed_entity(e["entity"])
    ei_black_hole.on_destroyed_entity(e["entity"], transfer)
    ei_gate.on_destroyed_entity(e["entity"], transfer)
    ei_fueler.on_destroyed_entity(e["entity"], transfer)
    em_trains.on_destroyed_entity(e["entity"])
    orbital_combinator.rem(e["entity"])
end


function on_destroyed_tile(e)
    ei_induction_matrix.on_destroyed_tile(e)
end