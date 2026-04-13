--==============================================================================
-- ESIR FILE MAP
-- owns: debug console teleport command
-- loaded_by: exotic-space-industries-remembrance\control.lua
-- cadence: console command
-- forwarded_events: teleport_to
-- storage_roots: storage.ei
-- gui_ids: none
-- remote_interfaces: none
-- rebuild_on: runtime rebuild
--==============================================================================
local model = {}
local ei_lib = require("lib/lib")
local ei_runtime_scheduler = require("lib/runtime-scheduler")
local ei_flammable_rupture_scheduler = require("scripts/control/flammable-rupture-scheduler")

local function get_beacon_overload_helper(name)
    if not ei_beacon_overload then
        return nil
    end

    return ei_beacon_overload[name]
end

local function call_beacon_overload(name, ...)
    local helper = get_beacon_overload_helper(name)
    if not helper then
        return nil
    end

    return helper(...)
end

local function capture_runtime_module_status(module_name, module_ref, fallback_status)
    if module_ref and module_ref.get_runtime_status then
        local ok, status = pcall(module_ref.get_runtime_status)
        if ok and status then
            return status
        end
    end

    local status = fallback_status or {}
    ei_runtime_scheduler.set_module_status(module_name, status)
    return status
end

local function get_status_snapshot()
    local status = call_beacon_overload("get_debug_status")
    if status then
        return status
    end

    local state = storage.ei and storage.ei.beacon_overload or nil
    local debug_state = state and state.debug or {}
    return {
        enabled = debug_state.enabled or false,
        auto_arm = debug_state.auto_arm ~= false,
        mode = state and state.mode or nil,
        reason = (debug_state.last_reason or (state and state.last_reason)) or nil,
        tracked_count = state and state.tracked_count or 0,
        overloaded_count = state and state.overloaded_count or 0,
        surface_queue = state and state.surface_queue or nil,
        chunk_queue = state and state.chunk_queue or nil,
        machine_queue = state and state.machine_queue or nil,
        tracked_refresh_cursor = state and state.tracked_refresh_cursor or nil,
        tracked_audit_cursor = state and state.tracked_audit_cursor or nil,
        icon_audit_cursor = state and state.icon_audit_cursor or nil,
        release_cursor = state and state.release_cursor or nil,
        last_heartbeat_tick = debug_state.last_heartbeat_tick or 0,
        last_reason = debug_state.last_reason or nil,
        last_status = debug_state.last_status or {},
    }
end

local function format_status_summary(status)
    local surface_queue_length = status.surface_queue_length or ei_runtime_scheduler.queue_length(status.surface_queue)
    local chunk_queue_length = status.chunk_queue_length or ei_runtime_scheduler.queue_length(status.chunk_queue)
    local machine_queue_length = status.machine_queue_length or ei_runtime_scheduler.queue_length(status.machine_queue)
    local parts = {
        "Beacon overload debug",
        "enabled=" .. tostring(status.enabled and true or false),
        "auto_arm=" .. tostring(status.auto_arm and true or false),
        "mode=" .. tostring(status.mode or "idle"),
        "tracked=" .. tostring(status.tracked_count or 0),
        "overloaded=" .. tostring(status.overloaded_count or 0),
        "queues=" .. tostring(surface_queue_length) .. "/" .. tostring(chunk_queue_length) .. "/" .. tostring(machine_queue_length),
    }

    if status.reason then
        parts[#parts + 1] = "reason=" .. tostring(status.reason)
    end

    return table.concat(parts, " ")
end

local function require_admin(cmd)
    local player = cmd and cmd.player_index and game.get_player(cmd.player_index) or nil
    if not player or not player.valid or not player.admin then
        return nil
    end

    return player
end

local function handle_debug_toggle(cmd)
    local player = require_admin(cmd)
    if not player then
        return
    end

    local action = string.lower((cmd.parameter or ""):gsub("^%s+", ""):gsub("%s+$", ""))
    if action == "" then
        player.print("Usage: /beacon_overload_debug on|off|auto-on|auto-off")
        return
    end

    if action == "on" then
        if not get_beacon_overload_helper("set_debug_enabled") then
            player.print("Beacon overload debug helper unavailable.")
            return
        end
        call_beacon_overload("set_debug_enabled", true, "admin-command")
        player.print("Beacon overload debug enabled.")
        return
    end

    if action == "off" then
        if not get_beacon_overload_helper("set_debug_enabled") then
            player.print("Beacon overload debug helper unavailable.")
            return
        end
        call_beacon_overload("set_debug_enabled", false, "admin-command")
        player.print("Beacon overload debug disabled.")
        return
    end

    if action == "auto-on" then
        if not get_beacon_overload_helper("set_debug_auto_arm") then
            player.print("Beacon overload debug helper unavailable.")
            return
        end
        call_beacon_overload("set_debug_auto_arm", true)
        player.print("Beacon overload debug auto-arm enabled.")
        return
    end

    if action == "auto-off" then
        if not get_beacon_overload_helper("set_debug_auto_arm") then
            player.print("Beacon overload debug helper unavailable.")
            return
        end
        call_beacon_overload("set_debug_auto_arm", false)
        player.print("Beacon overload debug auto-arm disabled.")
        return
    end

    player.print("Usage: /beacon_overload_debug on|off|auto-on|auto-off")
end

local function handle_status_command(cmd)
    local player = require_admin(cmd)
    if not player then
        return
    end

    local status = get_status_snapshot()
    local summary = format_status_summary(status)
    player.print(summary)
    if serpent and serpent.block then
        log("[ESIR beacon-overload] status " .. serpent.block(status, {sortkeys = true}))
    else
        log("[ESIR beacon-overload] status snapshot unavailable: serpent missing")
    end
end

local function require_admin_or_server(cmd)
    if not cmd or not cmd.player_index then
        return true, nil
    end

    local player = game.get_player(cmd.player_index)
    if not player or not player.valid or not player.admin then
        return false, nil
    end

    return true, player
end

local function print_runtime_status(player, message)
    if player then
        player.print(message)
        return
    end

    game.print(message)
end

local function get_runtime_status_snapshot()
    local ei_state = storage and storage.ei or {}
    local fueler = storage and storage.ei and storage.ei.fueler_rt or {}
    local matrix = ei_state.induction_matrix or {}
    local gate = ei_state.gate or {}
    local rocket_pollution = ei_state.rocket_launch_pollution or {}
    local flammable_ruptures = ei_state.flammable_ruptures or {}
    local emt = storage and storage.ei_emt or {}
    local vulcanus = ei_state.vulcanus_fumaroles or {}

    local dirty_core_count = 0
    if matrix.core then
        for matrix_id, matrix_data in pairs(matrix.core) do
            if type(matrix_id) == "number" and matrix_data and matrix_data.dirty then
                dirty_core_count = dirty_core_count + 1
            end
        end
    end

    return ei_runtime_scheduler.status_snapshot({
        induction_matrix = capture_runtime_module_status("induction-matrix", ei_induction_matrix, {
            cores = ei_lib.getn(matrix.core) - (matrix.core and matrix.core.stats and 1 or 0),
            dirty_cores = dirty_core_count,
            dirty_queue = ei_runtime_scheduler.queue_length(matrix.dirty_core_queue),
            render_queue = ei_lib.count_sequence(matrix.render_queue),
            render_buckets = ei_runtime_scheduler.delayed_bucket_count(matrix.render_buckets),
            render_bucket_items = ei_runtime_scheduler.delayed_item_count(matrix.render_buckets),
            stat_texts = ei_lib.getn(matrix.stat_text_index),
        }),
        gate = capture_runtime_module_status("gate", ei_gate, {
            gates = ei_lib.getn(gate.gate),
            breakpoint = gate.gate_break_point,
            last_housekeeping_tick = gate.last_housekeeping_tick,
            receiver_registry_dirty = gate.receiver_registry_dirty == true,
        }),
        fueler = capture_runtime_module_status("fueler", ei_fueler, {
            targets = fueler.target_count or ei_lib.getn(fueler.targets),
            ready_targets = fueler.ready_target_count or 0,
            active_surfaces = ei_lib.count_sequence(fueler.active_surfaces),
            delayed_target_buckets = ei_runtime_scheduler.delayed_bucket_count(fueler.delayed_target_buckets),
            delayed_player_buckets = ei_runtime_scheduler.delayed_bucket_count(fueler.delayed_player_buckets),
            player_queue = ei_runtime_scheduler.queue_length(fueler.player_queue),
            last_housekeeping_tick = fueler.last_housekeeping_tick,
        }),
        gaia = capture_runtime_module_status("gaia", ei_gaia, {
            damage_ticks = ei_lib.count_sequence(ei_state.damage_ticks),
            damage_tick_buckets = ei_runtime_scheduler.delayed_bucket_count(ei_state.damage_tick_buckets),
            damage_tick_items = ei_runtime_scheduler.delayed_item_count(ei_state.damage_tick_buckets),
            reforge_active = ei_state.reforge_gaia ~= nil,
        }),
        alien_spawner = capture_runtime_module_status("alien-spawner", ei_alien_spawner, {
            legacy_queue = ei_lib.count_sequence(ei_state.spawner_queue),
            delayed_buckets = ei_runtime_scheduler.delayed_bucket_count(ei_state.spawner_buckets),
            delayed_items = ei_runtime_scheduler.delayed_item_count(ei_state.spawner_buckets),
        }),
        rocket_launch_pollution = capture_runtime_module_status("rocket-launch-pollution", ei_rocket_launch_pollution, {
            pending_launches = ei_lib.getn(rocket_pollution.pending_launches_by_silo),
            pending_cleanup_buckets = ei_runtime_scheduler.delayed_bucket_count(rocket_pollution.pending_launch_cleanup_buckets),
            pending_cleanup_items = ei_runtime_scheduler.delayed_item_count(rocket_pollution.pending_launch_cleanup_buckets),
            launch_smoke = ei_lib.count_sequence(rocket_pollution.launch_smoke),
        }),
        flammable_ruptures = capture_runtime_module_status("flammable-ruptures", ei_flammable_rupture_scheduler, {
            active_jobs = ei_lib.getn(flammable_ruptures.jobs),
            ring_buckets = ei_runtime_scheduler.delayed_bucket_count(flammable_ruptures.ring_buckets),
            ring_bucket_items = ei_runtime_scheduler.delayed_item_count(flammable_ruptures.ring_buckets),
        }),
        em_trains = capture_runtime_module_status("em-trains", em_trains, {
            chargers = ei_lib.getn(emt.chargers),
            trains = ei_lib.getn(emt.trains),
            charger_active_surfaces = ei_lib.count_sequence(emt.charger_active_surfaces),
            train_active_surfaces = ei_lib.count_sequence(emt.train_active_surfaces),
            rail_audit_cursor = emt.charger_rail_audit_cursor,
            rail_audit_requested = emt.charger_rail_audit_requested == true,
        }),
        black_hole = capture_runtime_module_status("black-hole", ei_black_hole, {
            entries = ei_lib.getn(ei_state.black_hole),
            active_queue = ei_runtime_scheduler.queue_length(ei_state.black_hole_active_queue),
            dormant_audit_queue = ei_runtime_scheduler.queue_length(ei_state.black_hole_dormant_audit_queue),
        }),
        vulcanus = capture_runtime_module_status("vulcanus-fumaroles", ei_vulcanus_fumaroles, {
            active = ei_lib.getn(vulcanus.active),
            dormant = ei_lib.getn(vulcanus.dormant_chunks),
            dormant_buckets = ei_runtime_scheduler.delayed_bucket_count(vulcanus.dormant_delayed_buckets),
            dormant_ready_surfaces = ei_lib.count_sequence(vulcanus.dormant_active_surfaces),
            backfill_queue = ei_runtime_scheduler.queue_length(vulcanus.backfill_queue),
        }),
    })
end

local function format_runtime_status_summary(snapshot)
    local extra = snapshot.extra or {}
    local matrix = extra.induction_matrix or {}
    local fueler = extra.fueler or {}
    local gate = extra.gate or {}
    local gaia = extra.gaia or {}
    local alien_spawner = extra.alien_spawner or {}
    local rocket = extra.rocket_launch_pollution or {}
    local ruptures = extra.flammable_ruptures or {}
    local emt = extra.em_trains or {}
    local black_hole = extra.black_hole or {}
    local vulcanus = extra.vulcanus or {}

    return table.concat({
        "ESIR runtime",
        "tick=" .. tostring(snapshot.tick or 0),
        "matrix(dirty/q/render)=" .. tostring(matrix.dirty_cores or 0) .. "/" .. tostring(matrix.dirty_queue or 0) .. "/" .. tostring(matrix.render_queue or 0),
        "gate=" .. tostring(gate.gates or 0),
        "fueler(ready/delay)=" .. tostring(fueler.ready_targets or 0) .. "/" .. tostring(fueler.delayed_target_buckets or 0),
        "gaia(delay)=" .. tostring(gaia.damage_tick_buckets or 0),
        "alien(delay)=" .. tostring(alien_spawner.delayed_buckets or 0),
        "rocket(pending/smoke)=" .. tostring(rocket.pending_launches or 0) .. "/" .. tostring(rocket.launch_smoke or 0),
        "rupture(active/delay)=" .. tostring(ruptures.active_jobs or 0) .. "/" .. tostring(ruptures.ring_buckets or 0),
        "em(chargers/trains)=" .. tostring(emt.chargers or 0) .. "/" .. tostring(emt.trains or 0),
        "blackhole=" .. tostring(black_hole.entries or 0),
        "vulcanus(active/dormant)=" .. tostring(vulcanus.active or 0) .. "/" .. tostring(vulcanus.dormant or 0),
    }, " ")
end

local function handle_runtime_status_command(cmd)
    local ok, player = require_admin_or_server(cmd)
    if not ok then
        return
    end

    local parameter = string.lower((cmd.parameter or ""):gsub("^%s+", ""):gsub("%s+$", ""))
    local runtime_state = ei_runtime_scheduler.ensure_root()

    if parameter == "telemetry-on" then
        runtime_state.telemetry.enabled = true
        print_runtime_status(player, "ESIR runtime telemetry enabled.")
        return
    elseif parameter == "telemetry-off" then
        runtime_state.telemetry.enabled = false
        print_runtime_status(player, "ESIR runtime telemetry disabled.")
        return
    elseif parameter ~= "" and parameter ~= "snapshot" then
        print_runtime_status(player, "Usage: /ei_runtime_status [snapshot|telemetry-on|telemetry-off]")
        return
    end

    local snapshot = get_runtime_status_snapshot()
    print_runtime_status(player, format_runtime_status_summary(snapshot))
    ei_runtime_scheduler.log_snapshot("debug-command", snapshot.extra)
end
-- command '/tp SURFACE_NAME_OR_INDEX'
function model.teleport_to(event)
  if event.command ~= 'tp' then
    return
  end

  if not event.parameters then
    return
  end

  if not event.player_index then
    return
  end

  local player = game.get_player(event.player_index)

  if not player.admin then
    return
  end

  local destination = game.get_surface(event.parameters)

  if destination == nil then
    return
  end

  ei_lib.crystal_echo("Teleporting")
  player.teleport({0,0}, destination)
end
-- Debugs proclaim
commands.add_command("victory_reset", "Resets victory status which allows victory screen to trigger.", function(cmd)
    local player = game.get_player(cmd.player_index)
    if not player or not player.admin then return end
    local force = player.force
    if force and force.name and storage.ei.victory and storage.ei.victory[force.name] == true then
        storage.ei.victory[force.name] = false
        ei_lib.crystal_echo("The hour is again late but not over")
    else
        ei_lib.crystal_echo("The hour is not late yet, or victory was not achieved before. No reset needed.")
    end
end)

commands.add_command("refresh_beacon_overload", "Queues a background rebuild of beacon overload status", function(cmd)
    local player = game.get_player(cmd.player_index)
    if not player or not player.admin then return end
    ei_lib.crystal_echo("Beacon overload rebuild queued; the cosmos will catch up in the background")
    ei_beacon_overload.refresh_all_overloads()
end)
commands.add_command("beacon_overload_debug", "Toggles beacon overload stall logging. Usage: on, off, auto-on, auto-off.", function(cmd)
    handle_debug_toggle(cmd)
end)
commands.add_command("beacon_overload_status", "Reports beacon overload debug state and logs a structured snapshot.", function(cmd)
    handle_status_command(cmd)
end)
commands.add_command("ei_runtime_status", "Reports shared runtime scheduler queues and controls default-off heartbeat telemetry.", function(cmd)
    handle_runtime_status_command(cmd)
end)
commands.add_command("reforge_gaia", "Destroy and recreate Gaia's surface from the current planet prototype.", function(cmd)
    local player = game.get_player(cmd.player_index)
    if not player or not player.admin then return end
    local surface = ei_gaia.reforge_gaia_surface(cmd)
    if not surface then return end
    player.teleport({0, 0}, surface)
end)
commands.add_command("goto-gaia", "Teleport to Gaia's surface", function(cmd)
    local player = game.get_player(cmd.player_index)
    if not player or not player.admin then return end
    local surface = ei_gaia.create_gaia()
    if not surface then return end
    local position = {0, 0}  -- center of the world
    player.teleport(position, surface)
    ei_lib.crystal_echo("✈ [Astral Transit] — " .. player.name .. " arrives upon Gaia’s crust.")
    log(player.name.." used goto-gaia")
end)

commands.add_command("goto-fulgora", "Teleport to Fulgoras's surface", function(cmd)
    local player = game.get_player(cmd.player_index)
    if not player or not player.admin then return end
    local planet = game.planets["fulgora"]
    local surface = planet and planet.surface
    if not surface then
        game.planets["fulgora"]:create_surface("fulgora")
        ei_lib.crystal_echo("✈ [Astral Transit] - Fulgora shakes off the dust of ages.")
        return
    end
    local position = {0, 0}  -- center of the world
    player.teleport(position, surface)
    ei_lib.crystal_echo("✈ [Astral Transit] — " .. player.name .. " arrives upon Fulgora's crust.")
    log(player.name.." used goto-fulgora")
end)

commands.add_command("goto-vulcanus", "Teleport to Vulcanus's surface", function(cmd)
    local player = game.get_player(cmd.player_index)
    if not player or not player.admin then return end
    local planet = game.planets["vulcanus"]
    local surface = planet and planet.surface
    if not surface then
        game.planets["vulcanus"]:create_surface("vulcanus")
        ei_lib.crystal_echo("✈ [Astral Transit] - Vulcanus erupts into existence.")
        return
    end
    local position = {0, 0}  -- center of the world
    player.teleport(position, surface)
    ei_lib.crystal_echo("✈ [Astral Transit] — " .. player.name .. " arrives upon Vulcanus' crust.")
    log(player.name.." used goto-vulcanus")
end)

commands.add_command("goto-gleba", "Teleport to Gleba's surface", function(cmd)
    local player = game.get_player(cmd.player_index)
    if not player or not player.admin then return end
    local planet = game.planets["gleba"]
    local surface = planet and planet.surface
    if not surface then
        game.planets["gleba"]:create_surface("gleba")
        ei_lib.crystal_echo("✈ [Astral Transit] - Gleba awakens from its slumber.")
        return
    end
    local position = {0, 0}  -- center of the world
    player.teleport(position, surface)
    ei_lib.crystal_echo("✈ [Astral Transit] — " .. player.name .. " arrives upon Gleba's crust.")
    log(player.name.." used goto-gleba")
end)
commands.add_command("goto-aquilo", "Teleport to Aquillo's surface", function(cmd)
    local player = game.get_player(cmd.player_index)
    if not player or not player.admin then return end
    local planet = game.planets["aquilo"]
    local surface = planet and planet.surface
    if not surface then
        game.planets["aquilo"]:create_surface("aquilo")
        ei_lib.crystal_echo("✈ [Astral Transit] - Aquilo shivers into being.")
        return
    end
    local position = {0, 0}  -- center of the world
    player.teleport(position, surface)
    ei_lib.crystal_echo("✈ [Astral Transit] — " .. player.name .. " arrives upon Aquilo's crust.")
    log(player.name.." used goto-aquilo")
end)
commands.add_command("goto-nauvis", "Teleport to Nauvis' surface", function(cmd)
    local player = game.get_player(cmd.player_index)
    if not player or not player.admin then return end
    local planet = game.planets["nauvis"]
    local surface = planet and planet.surface
    if not surface then
        game.planets["nauvis"]:create_surface("nauvis")
        ei_lib.crystal_echo("✈ [Astral Transit] - Nauvis radiates with life once more.")
        return
    end
    local position = {0, 0}  -- center of the world
    player.teleport(position, surface)
    ei_lib.crystal_echo("✈ [Astral Transit] — " .. player.name .. " arrives upon Nauvis' crust.")
    log(player.name.." used goto-nauvis")
end)


return model
