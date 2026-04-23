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
local ei_fluid_safety = require("scripts/control/fluid-safety")
local ei_flammable_rupture_scheduler = require("scripts/control/flammable-rupture-scheduler")
local ORBITAL_SCANNER_NAME = "ei-orbital-combinator"
local ORBITAL_SCANNER_PROBE_FILE = "ei-orbital-scanner-probe.jsonl"
local ORBITAL_SCANNER_PROBE_DEFAULT_TICKS = 600

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

    if type(fallback_status) == "function" then
        fallback_status = fallback_status()
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
    local matter_runtime = ei_state.matter_runtime or {}
    local matter_gui = ei_state.matter_stabilizer_gui or {}
    local matrix = ei_state.induction_matrix or {}
    local gate = ei_state.gate or {}
    local rocket_pollution = ei_state.rocket_launch_pollution or {}
    local fluid_runtime = ei_state.fluid_runtime or {}
    local flammable_ruptures = ei_state.flammable_ruptures or {}
    local emt = storage and storage.ei_emt or {}
    local vulcanus = ei_state.vulcanus_fumaroles or {}
    local matter_tier_counts = {
        stable = 0,
        strained = 0,
        critical = 0,
    }

    if matter_runtime.machines then
        for _, machine_data in pairs(matter_runtime.machines) do
            local warning_state = machine_data and machine_data.warning_state or "stable"
            if matter_tier_counts[warning_state] ~= nil then
                matter_tier_counts[warning_state] = matter_tier_counts[warning_state] + 1
            end
        end
    end

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
        fluid_safety = capture_runtime_module_status("fluid-safety", ei_fluid_safety, function()
            return {
                tracked_entities = fluid_runtime.tracked_count or 0,
                segments = ei_runtime_scheduler.table_count(fluid_runtime.segments),
                urgent_queue = fluid_runtime.urgent_count or 0,
                dirty_queue = fluid_runtime.dirty_count or 0,
                scan_units = ei_lib.count_sequence(fluid_runtime.scan_units),
                service_mode_cursor = fluid_runtime.service_mode_cursor or 1,
                service_mode_name = fluid_runtime.service_mode_name or "idle",
                heavy_aftermath_queued = fluid_runtime.aftermath_stats and fluid_runtime.aftermath_stats.heavy_aftermath_queued or 0,
                light_vent_queued = fluid_runtime.aftermath_stats and fluid_runtime.aftermath_stats.light_vent_queued or 0,
                heavy_cooldown_suppressed = fluid_runtime.aftermath_stats and fluid_runtime.aftermath_stats.heavy_cooldown_suppressed or 0,
                light_cooldown_suppressed = fluid_runtime.aftermath_stats and fluid_runtime.aftermath_stats.light_cooldown_suppressed or 0,
            }
        end),
        matter_stabilizer = capture_runtime_module_status("matter-stabilizer", ei_matter_stabilizer, {
            machines = matter_runtime.machine_count or ei_lib.getn(ei_state.matter_machines),
            stabilizers = matter_runtime.stabilizer_count or ei_lib.getn(ei_state.matter_stabilizers),
            open_gui_count = ei_runtime_scheduler.table_count(matter_gui.open_by_player),
            pending_refresh_buckets = ei_runtime_scheduler.delayed_bucket_count(matter_gui.refresh_buckets),
            pending_refresh_items = ei_runtime_scheduler.delayed_item_count(matter_gui.refresh_buckets),
            stable = matter_tier_counts.stable,
            strained = matter_tier_counts.strained,
            critical = matter_tier_counts.critical,
        }),
        flammable_ruptures = capture_runtime_module_status("flammable-ruptures", ei_flammable_rupture_scheduler, function()
            return {
                fidelity_mode = flammable_ruptures.fidelity_mode,
                active_jobs = flammable_ruptures.active_job_count or ei_lib.getn(flammable_ruptures.jobs),
                pending_rings = flammable_ruptures.pending_ring_count or 0,
                ring_buckets = flammable_ruptures.scheduled_bucket_count or ei_runtime_scheduler.delayed_bucket_count(flammable_ruptures.ring_buckets),
                ring_bucket_items = flammable_ruptures.scheduled_ring_count or ei_runtime_scheduler.delayed_item_count(flammable_ruptures.ring_buckets),
                overdue_bucket_count = flammable_ruptures.overdue_bucket_count or 0,
                overdue_item_count = flammable_ruptures.overdue_item_count or 0,
            }
        end),
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
        orbital_scanner = capture_runtime_module_status("orbital-combinator", orbital_combinator, {
            banks = ei_state.orbital_combinator_bank_count or 0,
            dirty_banks = ei_runtime_scheduler.queue_length(ei_state.orbital_combinator_dirty_bank_queue),
            hot_surfaces = ei_runtime_scheduler.queue_length(ei_state.orbital_combinator_hot_surface_queue),
            cold_surfaces = ei_runtime_scheduler.queue_length(ei_state.orbital_combinator_cold_surface_queue),
            bank_audits = ei_runtime_scheduler.queue_length(ei_state.orbital_combinator_bank_audit_queue),
        }),
        orbital_logistics = capture_runtime_module_status("orbital-logistics", package.loaded["scripts/control/orbital-logistics"] or rawget(_G, "orbital_logistics"), {
            cohorts = ei_lib.getn(ei_state.orbital_logistics and ei_state.orbital_logistics.cohorts),
            transponders = ei_lib.getn(ei_state.orbital_logistics and ei_state.orbital_logistics.transponders_by_unit),
            selectors = ei_lib.getn(ei_state.orbital_logistics and ei_state.orbital_logistics.selectors_by_unit),
            coordinators = ei_lib.getn(ei_state.orbital_logistics and ei_state.orbital_logistics.coordinators_by_unit),
            uplinks = ei_lib.getn(ei_state.orbital_logistics and ei_state.orbital_logistics.uplinks_by_unit),
            leases = ei_lib.getn(ei_state.orbital_logistics and ei_state.orbital_logistics.lease_by_job_id),
            open_gui_count = ei_lib.getn(ei_state.orbital_logistics and ei_state.orbital_logistics.open_gui_by_player),
            dirty = ei_runtime_scheduler.queue_length(ei_state.orbital_logistics and ei_state.orbital_logistics.dirty_cohort_queue),
        }),
        railgun_cooling = capture_runtime_module_status("railgun-cooling", package.loaded["scripts/control/railgun-cooling"], {
            tracked_railguns = ei_lib.getn(ei_state.railgun_cooling and ei_state.railgun_cooling.turrets_by_unit),
            open_gui_count = ei_lib.getn(ei_state.railgun_cooling and ei_state.railgun_cooling.open_by_player),
            recovery_queue = ei_runtime_scheduler.queue_length(ei_state.railgun_cooling and ei_state.railgun_cooling.recovery_queue),
            recovery_buckets = ei_runtime_scheduler.delayed_bucket_count(ei_state.railgun_cooling and ei_state.railgun_cooling.recovery_buckets),
            recovery_bucket_items = ei_runtime_scheduler.delayed_item_count(ei_state.railgun_cooling and ei_state.railgun_cooling.recovery_buckets),
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
    local fluid = extra.fluid_safety or {}
    local ruptures = extra.flammable_ruptures or {}
    local emt = extra.em_trains or {}
    local black_hole = extra.black_hole or {}
    local orbital = extra.orbital_scanner or {}
    local orbital_logistics = extra.orbital_logistics or {}
    local railgun = extra.railgun_cooling or {}
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
        "fluid(t/u/d/s/cursor/mode)=" .. tostring(fluid.tracked_entities or 0) .. "/" .. tostring(fluid.urgent_queue or 0) .. "/" .. tostring(fluid.dirty_queue or 0) .. "/" .. tostring(fluid.scan_units or 0) .. "/" .. tostring(fluid.service_mode_cursor or 1) .. "/" .. tostring(fluid.service_mode_name or "idle"),
        "fluidfx(qh/ql|sh/sl)=" .. tostring(fluid.heavy_aftermath_queued or 0) .. "/" .. tostring(fluid.light_vent_queued or 0) .. "|" .. tostring(fluid.heavy_cooldown_suppressed or 0) .. "/" .. tostring(fluid.light_cooldown_suppressed or 0),
        "rupture(mode/a/p/d|ob/oi)=" .. tostring(ruptures.fidelity_mode or "?") .. "/" .. tostring(ruptures.active_jobs or 0) .. "/" .. tostring(ruptures.pending_rings or 0) .. "/" .. tostring(ruptures.ring_buckets or 0) .. "|" .. tostring(ruptures.overdue_bucket_count or 0) .. "/" .. tostring(ruptures.overdue_item_count or 0),
        "em(chargers/trains)=" .. tostring(emt.chargers or 0) .. "/" .. tostring(emt.trains or 0),
        "blackhole=" .. tostring(black_hole.entries or 0),
        "orbital(banks/dirty/probe)=" .. tostring(orbital.banks or orbital.bank_count or 0) .. "/" .. tostring(orbital.dirty_banks or 0) .. "/" .. tostring(orbital.probe_enabled == true or (orbital.probe and orbital.probe.enabled == true)),
        "cohort(c/l/u/gui)=" .. tostring(orbital_logistics.cohorts or orbital_logistics.cohort_count or 0) .. "/" .. tostring(orbital_logistics.leases or orbital_logistics.lease_count or 0) .. "/" .. tostring(orbital_logistics.uplinks or orbital_logistics.uplink_count or 0) .. "/" .. tostring(orbital_logistics.open_gui_count or 0),
        "railgun(track/block/recover)=" .. tostring(railgun.tracked_railguns or 0) .. "/" .. tostring(railgun.blocked_count or 0) .. "/" .. tostring(railgun.recovering_count or 0),
        "vulcanus(active/dormant)=" .. tostring(vulcanus.active or 0) .. "/" .. tostring(vulcanus.dormant or 0),
    }, " ")
end

local function is_orbital_scanner_entity(entity)
    return entity and entity.valid and entity.name == ORBITAL_SCANNER_NAME
end

local function get_orbital_probe_runtime()
    if orbital_combinator then
        return orbital_combinator
    end

    return nil
end

local function get_probe_target_scanner(player)
    if not (player and player.valid) then
        return nil
    end

    if is_orbital_scanner_entity(player.opened) then
        return player.opened
    end

    if is_orbital_scanner_entity(player.selected) then
        return player.selected
    end

    return nil
end

local function encode_probe_record(record)
    if helpers and helpers.table_to_json then
        local ok, encoded = pcall(helpers.table_to_json, record)
        if ok and encoded then
            return encoded
        end
    end

    if game and game.table_to_json then
        local ok, encoded = pcall(game.table_to_json, record)
        if ok and encoded then
            return encoded
        end
    end

    if serpent and serpent.line then
        return serpent.line(record, {sortkeys = true})
    end

    return nil
end

local function write_probe_file(path, content, append)
    if helpers and helpers.write_file then
        local ok = pcall(helpers.write_file, path, content, append)
        return ok
    end

    return false
end

local function write_orbital_probe_dump(records)
    if type(records) ~= "table" or #records == 0 then
        return 0, nil
    end

    if write_probe_file(ORBITAL_SCANNER_PROBE_FILE, "", false) then
        local written = 0
        for _, record in ipairs(records) do
            local encoded = encode_probe_record(record)
            if encoded and write_probe_file(ORBITAL_SCANNER_PROBE_FILE, encoded .. "\n", true) then
                written = written + 1
            end
        end

        return written, ORBITAL_SCANNER_PROBE_FILE
    end

    local written = 0
    for _, record in ipairs(records) do
        if ei_runtime_scheduler.write_telemetry("orbital-scanner-probe-dump", record, true) then
            written = written + 1
        end
    end

    if written > 0 then
        local runtime_state = ei_runtime_scheduler.ensure_root()
        local telemetry_file = runtime_state and runtime_state.telemetry and runtime_state.telemetry.file or "ei-runtime-scheduler.jsonl"
        return written, telemetry_file
    end

    return 0, nil
end

local function format_orbital_probe_counters(counters)
    counters = counters or {}
    return table.concat({
        "empty-req=" .. tostring(counters.request_overwrite_empty or 0),
        "empty-way=" .. tostring(counters.on_the_way_overwrite_empty or 0),
        "need=" .. tostring(counters.need_inventory_changed or 0),
        "prune=" .. tostring(counters.platform_pruned_from_surface_index or 0),
        "lost-members=" .. tostring(counters.bank_lost_active_members or 0),
        "blank-layout=" .. tostring(counters.layout_became_zero_or_blank or 0),
    }, " ")
end

local function get_orbital_probe_counters(snapshot)
    if not snapshot then
        return {}
    end

    return snapshot.counters or snapshot.cause_counts or {}
end

local function print_orbital_probe_usage(player)
    player.print("Usage: /ei_orbital_scanner_probe arm [ticks]|status|dump|clear")
end

local function handle_orbital_scanner_probe_command(cmd)
    local player = require_admin(cmd)
    if not player then
        return
    end

    local runtime = get_orbital_probe_runtime()
    if not runtime then
        player.print("Orbital scanner runtime unavailable.")
        return
    end

    local parameter = (cmd.parameter or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if parameter == "" then
        print_orbital_probe_usage(player)
        return
    end

    local action, remainder = parameter:match("^(%S+)%s*(.-)$")
    action = string.lower(action or "")

    if action == "arm" then
        if not runtime.arm_probe then
            player.print("Orbital scanner probe helpers unavailable.")
            return
        end

        local scanner = get_probe_target_scanner(player)
        if not scanner then
            player.print("Open or select an orbital scanner before arming the probe.")
            return
        end

        local ticks = tonumber(remainder)
        ticks = math.floor(ticks or ORBITAL_SCANNER_PROBE_DEFAULT_TICKS)
        if ticks < 1 then
            ticks = ORBITAL_SCANNER_PROBE_DEFAULT_TICKS
        end

        local status = runtime.arm_probe(scanner, game.tick + ticks, game.tick)
        if status then
            player.print("Orbital scanner probe armed for " .. tostring(ticks) .. " ticks on scanner " .. tostring(scanner.unit_number) .. ".")
            player.print("Probe status: " .. format_orbital_probe_counters(get_orbital_probe_counters(status)))
        else
            player.print("Failed to arm orbital scanner probe.")
        end
        return
    end

    if action == "status" then
        if not runtime.get_probe_status then
            player.print("Orbital scanner probe helpers unavailable.")
            return
        end

        local status = runtime.get_probe_status(game.tick)
        player.print(table.concat({
            "Orbital scanner probe",
            "enabled=" .. tostring(status and status.enabled == true),
            "target=" .. tostring(status and status.target_unit_number or "nil"),
            "reason=" .. tostring(status and status.arm_reason or "nil"),
            "expires=" .. tostring(status and status.expire_tick or 0),
            "records=" .. tostring(status and status.record_count or 0),
            format_orbital_probe_counters(get_orbital_probe_counters(status)),
        }, " "))
        return
    end

    if action == "dump" then
        local dump_helper = runtime.dump_probe or runtime.get_probe_dump or runtime.probe_dump
        if not dump_helper then
            player.print("Orbital scanner probe helpers unavailable.")
            return
        end

        local dump = dump_helper(game.tick)
        local records = dump and dump.records or {}
        local written, output_file = write_orbital_probe_dump(records)
        player.print(table.concat({
            "Orbital scanner probe dump",
            "records=" .. tostring(#records),
            "written=" .. tostring(written),
            "file=" .. tostring(output_file or "unavailable"),
            "reason=" .. tostring(dump and dump.status and dump.status.arm_reason or "nil"),
            format_orbital_probe_counters(get_orbital_probe_counters(dump and dump.status or dump)),
        }, " "))
        return
    end

    if action == "clear" then
        if not runtime.clear_probe then
            player.print("Orbital scanner probe helpers unavailable.")
            return
        end

        runtime.clear_probe()
        player.print("Orbital scanner probe cleared.")
        return
    end

    print_orbital_probe_usage(player)
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
        print_runtime_status(player, { "exotic-industries.ei-runtime-status-enabled" })
        return
    elseif parameter == "telemetry-off" then
        runtime_state.telemetry.enabled = false
        print_runtime_status(player, { "exotic-industries.ei-runtime-status-disabled" })
        return
    elseif parameter ~= "" and parameter ~= "snapshot" then
        print_runtime_status(player, { "exotic-industries.ei-runtime-status-usage" })
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
commands.add_command("ei_runtime_status", { "exotic-industries.ei-runtime-status-command-help" }, function(cmd)
    handle_runtime_status_command(cmd)
end)
commands.add_command("ei_orbital_scanner_probe", "Arms, inspects, dumps, or clears the orbital scanner diagnostic probe.", function(cmd)
    handle_orbital_scanner_probe_command(cmd)
end)
commands.add_command("rescan_orbital_logistics", "Queues an orbital logistics cohort runtime rescan from the live world.", function(cmd)
    local player = game.get_player(cmd.player_index)
    if not player or not player.admin then return end
    local runtime = package.loaded["scripts/control/orbital-logistics"] or rawget(_G, "orbital_logistics")
    if not runtime then
        player.print("Orbital logistics runtime unavailable.")
        return
    end
    if runtime.request_runtime_rescan then
        runtime.request_runtime_rescan("admin-command", game and game.tick or 0)
        player.print("Orbital logistics runtime rescan queued.")
        return
    end
    if runtime.rebuild_runtime_state then
        runtime.rebuild_runtime_state("admin-command", game and game.tick or 0)
        player.print("Orbital logistics runtime rebuilt.")
        return
    end
    player.print("Orbital logistics runtime unavailable.")
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
