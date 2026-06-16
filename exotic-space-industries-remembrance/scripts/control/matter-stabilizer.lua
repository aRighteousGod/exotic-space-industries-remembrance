--==============================================================================
-- ESIR FILE MAP
-- owns: matter runtime, queues, player rendering cleanup, and exotic assembler GUI
-- loaded_by: exotic-space-industries-remembrance\control.lua
-- cadence: build/destroy, selection/cursor/player-left, scheduled tick step 4, and configuration rebuild
-- forwarded_events: add_machine_to_surface_queue, add_to_chunk_store, check_entity, check_global, clear_rendering, close_gui, collect_machine_stabilizers, destroy_machine_fx, destroy_player_render_list, destroy_runtime_state, draw_connection, draw_stabilizer_range, draw_warning_text, ensure_machine_light, ensure_runtime_ready, ensure_surface_queue, get_due_gui_refresh_count, get_machine_base_chance, get_pending_work_count, get_player_render_list, get_risk_tier, get_runtime_status, get_stabilizer_weight, get_updates_per_entity, has_tick_work, link_stabilizer_and_machine, on_built_entity, on_destroyed_entity, on_gui_click, on_player_cursor_stack_changed, on_player_left_game, on_selected_entity_changed, open_gui, query_nearby_machines, query_nearby_stabilizers, query_runtime_registry_in_range, rebuild_runtime_state, register_matter_machine, register_stabilizer, remove_from_chunk_store, remove_machine_from_surface_queue, remove_matter_machine_by_unit, remove_rendering, remove_rendering_by_unit, remove_stabilizer_by_unit, reset_machine_state, reset_runtime_storage, spawn_machine_arc, spawn_machine_crackle, stabilizer_on_cursor, stabilizer_selected, sync_active_surface, unregister_matter_machine, unregister_stabilizer, update, update_machine_presentation, update_matter_machine, update_gui
-- storage_roots: storage.ei
-- gui_ids: ei-exotic-assembler-console
-- remote_interfaces: none
-- rebuild_on: init, configuration change, entity topology changes
--==============================================================================
local model = {}
ei_lib = require("lib/lib")
local ei_runtime_scheduler = require("lib/runtime-scheduler")

--====================================================================================================
--MATTER STABILIZER
--====================================================================================================

local MATTER_RUNTIME_VERSION = 3
local MATTER_CHUNK_SIZE = 32
local MATTER_RANGE = ei_data.matter_stabilizer.matter_range
local MATTER_RANGE_SQR = MATTER_RANGE * MATTER_RANGE
local MATTER_RISK_DECAY = 2.43
local MODULE_NAME = "matter-stabilizer"
local GUI_NAME = "ei-exotic-assembler-console"
local GUI_SUPPORT_MAX_WEIGHT = 5

local RISK_STRAINED_THRESHOLD = 0.02
local RISK_CRITICAL_THRESHOLD = 0.06

local WARNING_COOLDOWN_TICKS = 1800
local IMMINENT_WARNING_DELAY_TICKS = 600
local STRAINED_CRACKLE_COOLDOWN_TICKS = 180
local CRITICAL_CRACKLE_COOLDOWN_TICKS = 90
local CRITICAL_ARC_COOLDOWN_TICKS = 300

local GLOW_SPRITE = "emt_charger_glow"
local ARC_BEAM_NAME = "ei_charger-beam"
local CRACKLE_ANIMATION = "ei-overload-animation"

model.stabilizers = {
    ["ei-alien-stabilizer"] = ei_data.matter_stabilizer.alien_range,
    ["ei-matter-stabilizer"] = ei_data.matter_stabilizer.matter_range
}

model.matter_machines = {
    ["ei-exotic-assembler"] = true
}

model.stabilizer_names = {
    "ei-alien-stabilizer",
    "ei-matter-stabilizer"
}

model.matter_machine_names = {
    "ei-exotic-assembler"
}


--UTIL AND OTHER
------------------------------------------------------------------------------------------------------

local function new_runtime()
    return {
        version = MATTER_RUNTIME_VERSION,
        needs_rebuild = false,
        runtime_rebuild_in_progress = false,
        stabilizers = {},
        machines = {},
        stabilizer_chunks = {},
        machine_chunks = {},
        machine_surface_queues = {},
        machine_surface_counts = {},
        active_surfaces = {},
        active_surface_positions = {},
        active_surface_cursor = 1,
        machine_count = 0,
        stabilizer_count = 0,
        machine_fx = {},
        selected_render = {}
    }
end


local function new_surface_queue()
    return {
        items = {},
        positions = {},
        cursor = 1
    }
end


local function destroy_render_object(render_object)
    if render_object and render_object.valid then
        render_object.destroy()
    end
end


local function get_chunk_key(chunk_x, chunk_y)
    return chunk_x .. "," .. chunk_y
end

local function get_surface_chunk_store(chunk_store, surface_index, create)
    local surface_store = chunk_store[surface_index]
    if not surface_store and create then
        surface_store = {}
        chunk_store[surface_index] = surface_store
    end

    return surface_store
end


local function get_chunk_bucket(chunk_store, surface_index, chunk_x, chunk_y, create)
    local surface_store = get_surface_chunk_store(chunk_store, surface_index, create)
    if not surface_store then
        return nil
    end

    local key = get_chunk_key(chunk_x, chunk_y)
    local bucket = surface_store[key]
    if not bucket and create then
        bucket = {}
        surface_store[key] = bucket
    end

    return bucket, key, surface_store
end


local function now_tick(event_tick)
    return event_tick or (game and game.tick) or 0
end


local function count_due_bucket_items(buckets, tick)
    if type(buckets) ~= "table" then
        return 0
    end

    local count = 0
    for due_tick, bucket in pairs(buckets) do
        local numeric_due_tick = tonumber(due_tick)
        if numeric_due_tick and numeric_due_tick <= tick and type(bucket) == "table" then
            if #bucket > 0 then
                count = count + #bucket
            else
                for _ in pairs(bucket) do
                    count = count + 1
                end
            end
        end
    end

    return count
end


local function recalculate_gui_next_refresh_tick(gui_state)
    if type(gui_state) ~= "table" or type(gui_state.refresh_buckets) ~= "table" then
        return 0
    end

    local next_refresh_tick = 0
    for due_tick, bucket in pairs(gui_state.refresh_buckets) do
        local numeric_due_tick = tonumber(due_tick)
        if numeric_due_tick and type(bucket) == "table" and next(bucket) ~= nil then
            if next_refresh_tick == 0 or numeric_due_tick < next_refresh_tick then
                next_refresh_tick = numeric_due_tick
            end
        end
    end

    gui_state.next_refresh_tick = next_refresh_tick
    return next_refresh_tick
end


local function clamp_01(value)
    return math.max(0, math.min(1, tonumber(value) or 0))
end


local function format_percent(value)
    return string.format("%.2f", (tonumber(value) or 0) * 100)
end


local function format_multiplier(value)
    return string.format("%.2f", tonumber(value) or 0)
end


local function format_snapshot_seconds(snapshot_tick)
    local seconds = math.max(0, (tonumber(snapshot_tick) or 0) / 60)
    if seconds >= 100 then
        return string.format("%.0f", seconds)
    end

    return string.format("%.1f", seconds)
end


local function required_weight_for_target_risk(base_chance, progress_multiplier, target_risk_per_second)
    if target_risk_per_second <= 0 then
        return 0
    end

    local weighted_base = math.max(0, (tonumber(base_chance) or 0) * (tonumber(progress_multiplier) or 0))
    if weighted_base <= target_risk_per_second then
        return 0
    end

    return math.max(0, (weighted_base / target_risk_per_second) ^ (1 / MATTER_RISK_DECAY) - 1)
end


local function get_gui_root(player)
    if not (player and player.valid and player.gui and player.gui.relative) then
        return nil
    end

    local root = player.gui.relative[GUI_NAME]
    if root and root.valid then
        return root
    end

    return nil
end


local function set_progressbar_style(element, style_name)
    if element and element.valid and element.style.name ~= style_name then
        element.style = style_name
    end
end


local function add_status_row(parent, row_name, title_locale_key, bar_style)
    local row = parent.add{
        type = "flow",
        name = row_name .. "-row",
        direction = "vertical",
    }
    row.style.horizontally_stretchable = true
    row.style.vertical_spacing = 4

    local title = row.add{
        type = "label",
        name = "title",
        caption = {"exotic-industries." .. title_locale_key},
    }
    title.style.horizontally_stretchable = true

    local bar = row.add{
        type = "progressbar",
        name = "bar",
        style = bar_style,
    }
    bar.style.horizontally_stretchable = true

    return row
end


function model.check_entity(entity)
    return ei_lib.entity_check(entity)
end


function model.get_stabilizer_weight(entity)
    if entity and entity.quality and entity.quality.level and entity.quality.level > 1 then
        return (entity.quality.level - 1) * 3
    end

    return 1
end


function model.get_machine_base_chance(entity)
    local base_chance = 0.12

    if entity and entity.quality and entity.quality.level and entity.quality.level > 1 then
        base_chance = math.max(0.06, base_chance - (0.01 * (entity.quality.level - 1)))
    end

    return base_chance
end


function model.get_updates_per_entity(machine_count)
    local total_machines = math.max(1, machine_count or 0)
    local updates_per_entity = math.min(
        ei_update_functions_length,
        (ei_updater_per_entity_calls_per_second / total_machines)
    )

    if updates_per_entity < 0.01 then
        updates_per_entity = 0.01
    end

    return updates_per_entity
end


function model.destroy_machine_fx(runtime, unit_number)
    if not runtime or not runtime.machine_fx then
        return
    end

    local fx_state = runtime.machine_fx[unit_number]
    if not fx_state then
        return
    end

    destroy_render_object(fx_state.light)
    destroy_render_object(fx_state.halo)
    destroy_render_object(fx_state.outer_aura)
    runtime.machine_fx[unit_number] = nil
end


function model.destroy_player_render_list(render_list)
    if not render_list then
        return
    end

    for _, render_entry in pairs(render_list) do
        destroy_render_object(render_entry.render)
    end
end


function model.destroy_runtime_state(runtime)
    if not runtime then
        return
    end

    if runtime.machine_fx then
        for unit_number, _ in pairs(runtime.machine_fx) do
            model.destroy_machine_fx(runtime, unit_number)
        end
    end

    if runtime.selected_render then
        for _, render_list in pairs(runtime.selected_render) do
            model.destroy_player_render_list(render_list)
        end
    end
end


function model.reset_runtime_storage(runtime)
    runtime.version = MATTER_RUNTIME_VERSION
    runtime.needs_rebuild = false
    runtime.runtime_rebuild_in_progress = false
    runtime.stabilizers = {}
    runtime.machines = {}
    runtime.stabilizer_chunks = {}
    runtime.machine_chunks = {}
    runtime.machine_surface_queues = {}
    runtime.machine_surface_counts = {}
    runtime.active_surfaces = {}
    runtime.active_surface_positions = {}
    runtime.active_surface_cursor = 1
    runtime.machine_count = 0
    runtime.stabilizer_count = 0
    runtime.machine_fx = {}
    runtime.selected_render = {}

    storage.ei.matter_stabilizers = {}
    storage.ei.matter_stabilizers_count = 0
    storage.ei.matter_machines = {}
    storage.ei.matter_machines_count = 0
    storage.ei.stabilizer_break_point = nil
    storage.ei.matter_stabilizer_gui = {
        open_by_player = {},
        watchers_by_unit = {},
        refresh_buckets = ei_runtime_scheduler.ensure_delayed_buckets(nil),
        next_refresh_tick = 0,
        last_gui_service_tick = 0,
    }
end


function model.check_global()
    if not storage.ei then
        storage.ei = {}
    end

    local runtime = storage.ei.matter_runtime
    local needs_rebuild = false

    if not runtime then
        runtime = new_runtime()
        storage.ei.matter_runtime = runtime
        needs_rebuild = true
    end

    if runtime.version ~= MATTER_RUNTIME_VERSION then
        needs_rebuild = true
    end

    if not runtime.stabilizers then
        runtime.stabilizers = {}
        needs_rebuild = true
    end
    if not runtime.machines then
        runtime.machines = {}
        needs_rebuild = true
    end
    if not runtime.stabilizer_chunks then
        runtime.stabilizer_chunks = {}
        needs_rebuild = true
    end
    if not runtime.machine_chunks then
        runtime.machine_chunks = {}
        needs_rebuild = true
    end
    if not runtime.machine_surface_queues then
        runtime.machine_surface_queues = {}
        needs_rebuild = true
    end
    if not runtime.machine_surface_counts then
        runtime.machine_surface_counts = {}
        needs_rebuild = true
    end
    if not runtime.active_surfaces then
        runtime.active_surfaces = {}
        needs_rebuild = true
    end
    if not runtime.active_surface_positions then
        runtime.active_surface_positions = {}
        needs_rebuild = true
    end
    if runtime.active_surface_cursor == nil then
        runtime.active_surface_cursor = 1
        needs_rebuild = true
    end
    if runtime.machine_count == nil then
        runtime.machine_count = 0
        needs_rebuild = true
    end
    if runtime.stabilizer_count == nil then
        runtime.stabilizer_count = 0
        needs_rebuild = true
    end
    if not runtime.machine_fx then
        runtime.machine_fx = {}
        needs_rebuild = true
    end
    if not runtime.selected_render then
        runtime.selected_render = {}
    end
    if runtime.needs_rebuild == nil then
        runtime.needs_rebuild = needs_rebuild
    end
    if runtime.runtime_rebuild_in_progress == nil then
        runtime.runtime_rebuild_in_progress = false
    end

    if storage.ei.selected_render then
        for _, render_entry in pairs(storage.ei.selected_render) do
            destroy_render_object(render_entry.render or render_entry)
        end
        storage.ei.selected_render = nil
    end

    if not storage.ei.matter_stabilizers then
        storage.ei.matter_stabilizers = {}
    end
    if storage.ei.matter_stabilizers_count == nil then
        storage.ei.matter_stabilizers_count = 0
    end
    if not storage.ei.matter_machines then
        storage.ei.matter_machines = {}
    end
    if storage.ei.matter_machines_count == nil then
        storage.ei.matter_machines_count = 0
    end
    local gui_state = storage.ei.matter_stabilizer_gui
    if type(gui_state) ~= "table" then
        storage.ei.matter_stabilizer_gui = {
            open_by_player = {},
            watchers_by_unit = {},
            refresh_buckets = ei_runtime_scheduler.ensure_delayed_buckets(nil),
            next_refresh_tick = 0,
            last_gui_service_tick = 0,
        }
    else
        gui_state.open_by_player = type(gui_state.open_by_player) == "table" and gui_state.open_by_player or {}
        gui_state.watchers_by_unit = type(gui_state.watchers_by_unit) == "table" and gui_state.watchers_by_unit or {}
        gui_state.refresh_buckets = ei_runtime_scheduler.ensure_delayed_buckets(gui_state.refresh_buckets)
        gui_state.next_refresh_tick = tonumber(gui_state.next_refresh_tick) or recalculate_gui_next_refresh_tick(gui_state)
        gui_state.last_gui_service_tick = tonumber(gui_state.last_gui_service_tick) or 0
    end

    if needs_rebuild then
        runtime.needs_rebuild = true
    end

    runtime.version = MATTER_RUNTIME_VERSION
    return runtime
end


function model.get_gui_state()
    model.check_global()
    return storage.ei.matter_stabilizer_gui
end


function model.ensure_runtime_ready()
    local runtime = model.check_global()

    if runtime.needs_rebuild and not runtime.runtime_rebuild_in_progress then
        model.rebuild_runtime_state("auto")
    end

    return storage.ei.matter_runtime
end


function model.get_open_matter_machine(player)
    local entity = ei_lib.get_valid_entity(player and player.opened)
    if entity and entity.name == "ei-exotic-assembler" then
        return entity
    end

    return nil
end


function model.machine_has_watchers(unit_number)
    local gui_state = model.get_gui_state()
    local watchers = gui_state.watchers_by_unit[unit_number]
    return watchers ~= nil and next(watchers) ~= nil
end


function model.destroy_gui_root(player)
    local root = get_gui_root(player)
    if root then
        root.destroy()
    end
end


function model.clear_gui_session(player_index, destroy_gui, counter_name)
    local gui_state = model.get_gui_state()
    local session = gui_state.open_by_player[player_index]
    local had_session = session ~= nil
    if session then
        local watchers = gui_state.watchers_by_unit[session.unit_number]
        if watchers then
            watchers[player_index] = nil
            if next(watchers) == nil then
                gui_state.watchers_by_unit[session.unit_number] = nil
            end
        end

        gui_state.open_by_player[player_index] = nil
    end

    if destroy_gui and game then
        local player = game.get_player(player_index)
        if player then
            model.destroy_gui_root(player)
        end
    end

    if counter_name and had_session then
        ei_runtime_scheduler.bump_counter(MODULE_NAME, counter_name, 1)
    end
end


function model.clear_all_gui_sessions()
    local gui_state = model.get_gui_state()
    local player_indices = {}
    for player_index, _ in pairs(gui_state.open_by_player) do
        player_indices[#player_indices + 1] = player_index
    end

    for _, player_index in pairs(player_indices) do
        model.clear_gui_session(player_index, true, nil)
    end

    gui_state.refresh_buckets = ei_runtime_scheduler.ensure_delayed_buckets(nil)
    gui_state.next_refresh_tick = 0
    gui_state.last_gui_service_tick = 0
end


function model.close_sessions_for_unit(unit_number, destroy_gui, counter_name)
    local gui_state = model.get_gui_state()
    local watchers = gui_state.watchers_by_unit[unit_number]
    if not watchers then
        return
    end

    local player_indices = {}
    for player_index, _ in pairs(watchers) do
        player_indices[#player_indices + 1] = player_index
    end

    for _, player_index in pairs(player_indices) do
        model.clear_gui_session(player_index, destroy_gui, counter_name)
    end
end


function model.ensure_gui_session(player_index, unit_number)
    local gui_state = model.get_gui_state()
    local existing = gui_state.open_by_player[player_index]
    if existing and existing.unit_number ~= unit_number then
        model.clear_gui_session(player_index, false, "gui_closed")
        existing = nil
    end

    if not existing then
        existing = {
            unit_number = unit_number,
            last_signature = nil,
            pending_tick = nil,
        }
        gui_state.open_by_player[player_index] = existing
        ei_runtime_scheduler.bump_counter(MODULE_NAME, "gui_opened", 1)
    else
        existing.unit_number = unit_number
        existing.last_signature = nil
        existing.pending_tick = nil
    end

    local watchers = gui_state.watchers_by_unit[unit_number]
    if not watchers then
        watchers = {}
        gui_state.watchers_by_unit[unit_number] = watchers
    end
    watchers[player_index] = true

    return existing
end


function model.queue_gui_refresh_for_player(player_index, refresh_tick)
    local gui_state = model.get_gui_state()
    local session = gui_state.open_by_player[player_index]
    if not session then
        return
    end

    refresh_tick = now_tick(refresh_tick)
    if session.pending_tick and session.pending_tick <= refresh_tick then
        return
    end

    session.pending_tick = refresh_tick
    ei_runtime_scheduler.delayed_schedule(gui_state.refresh_buckets, refresh_tick, player_index)
    local next_refresh_tick = tonumber(gui_state.next_refresh_tick) or 0
    if next_refresh_tick <= 0 or refresh_tick < next_refresh_tick then
        gui_state.next_refresh_tick = refresh_tick
    end
    ei_runtime_scheduler.bump_counter(MODULE_NAME, "gui_refresh_queued", 1)
end


function model.queue_gui_refresh_for_unit(unit_number, refresh_tick)
    local gui_state = model.get_gui_state()
    local watchers = gui_state.watchers_by_unit[unit_number]
    if not watchers then
        return
    end

    for player_index, _ in pairs(watchers) do
        model.queue_gui_refresh_for_player(player_index, refresh_tick)
    end
end


function model.make_machine_snapshot(runtime, machine_data, stabilizer_weight, active_stabilizers, snapshot_tick, is_crafting, progress)
    local entity = machine_data.entity
    local base_chance = model.get_machine_base_chance(entity)
    local updates_per_entity = model.get_updates_per_entity(runtime.machine_count)
    local base_risk_per_second = base_chance / ((stabilizer_weight + 1) ^ MATTER_RISK_DECAY)
    local current_progress_multiplier = is_crafting and ((1 + progress) ^ 3) or 0
    local current_risk_per_second = is_crafting and (base_risk_per_second * current_progress_multiplier) or 0
    local current_per_update_chance = current_risk_per_second / updates_per_entity
    local current_tier = is_crafting and model.get_risk_tier(current_risk_per_second) or "dormant"
    local forecast_progress = 1
    local forecast_progress_multiplier = (1 + forecast_progress) ^ 3
    local forecast_risk_per_second = base_risk_per_second * forecast_progress_multiplier
    local forecast_tier = model.get_risk_tier(forecast_risk_per_second)
    local active_stabilizer_count = active_stabilizers and #active_stabilizers or 0
    local current_hold_weight_required = is_crafting
        and required_weight_for_target_risk(base_chance, current_progress_multiplier, RISK_STRAINED_THRESHOLD)
        or 0
    local forecast_hold_weight_required = required_weight_for_target_risk(
        base_chance,
        forecast_progress_multiplier,
        RISK_STRAINED_THRESHOLD
    )
    local forecast_buffer_weight_required = required_weight_for_target_risk(
        base_chance,
        forecast_progress_multiplier,
        RISK_CRITICAL_THRESHOLD
    )
    local projection_signature = string.format(
        "%s|%.3f|%.4f|%.4f|%d|%d",
        current_tier,
        progress,
        current_risk_per_second,
        forecast_risk_per_second,
        stabilizer_weight,
        active_stabilizer_count
    )

    return {
        active_stabilizer_count = active_stabilizer_count,
        stabilizer_weight = stabilizer_weight,
        base_chance = base_chance,
        current_progress = progress,
        current_progress_multiplier = current_progress_multiplier,
        current_risk_per_second = current_risk_per_second,
        current_per_update_chance = current_per_update_chance,
        current_tier = current_tier,
        current_hold_weight_required = current_hold_weight_required,
        forecast_progress = forecast_progress,
        forecast_progress_multiplier = forecast_progress_multiplier,
        forecast_risk_per_second = forecast_risk_per_second,
        forecast_tier = forecast_tier,
        forecast_hold_weight_required = forecast_hold_weight_required,
        forecast_buffer_weight_required = forecast_buffer_weight_required,
        projection_signature = projection_signature,
        snapshot_tick = snapshot_tick,
    }
end


function model.refresh_machine_snapshot(runtime, machine_data, snapshot_tick)
    local entity = machine_data.entity
    if not model.check_entity(entity) then
        machine_data.volatility_snapshot = nil
        return nil, {}
    end

    local stabilizer_weight, active_stabilizers = model.collect_machine_stabilizers(runtime, machine_data)
    local is_crafting = entity.is_crafting()
    local progress = is_crafting and (entity.crafting_progress or 0) or 0
    local snapshot = model.make_machine_snapshot(
        runtime,
        machine_data,
        stabilizer_weight,
        active_stabilizers,
        snapshot_tick,
        is_crafting,
        progress
    )

    machine_data.volatility_snapshot = snapshot
    return snapshot, active_stabilizers
end


function model.get_containment_display(snapshot)
    if snapshot.current_tier == "dormant" then
        return {
            style = "ei_status_progressbar_grey",
            value = 0,
            band = {"exotic-industries.exotic-assembler-gui-band-dormant"},
        }
    end

    if snapshot.current_tier == "critical" then
        return {
            style = "ei_status_progressbar_red",
            value = clamp_01(snapshot.current_risk_per_second / RISK_CRITICAL_THRESHOLD),
            band = {"exotic-industries.exotic-assembler-gui-band-cascade-imminent"},
        }
    end

    if snapshot.current_tier == "strained" then
        return {
            style = "ei_status_progressbar_purple",
            value = clamp_01(snapshot.current_risk_per_second / RISK_CRITICAL_THRESHOLD),
            band = {"exotic-industries.exotic-assembler-gui-band-strained"},
        }
    end

    return {
        style = "ei_status_progressbar_cyan",
        value = clamp_01(snapshot.current_risk_per_second / RISK_STRAINED_THRESHOLD),
        band = {"exotic-industries.exotic-assembler-gui-band-holding"},
    }
end


function model.get_cycle_pressure_display(snapshot)
    local progress = snapshot.current_progress or 0
    if progress <= 0 then
        return {
            style = "ei_status_progressbar_grey",
            value = 0,
            band = {"exotic-industries.exotic-assembler-gui-cycle-band-dormant"},
        }
    end

    if progress < 0.34 then
        return {
            style = "ei_status_progressbar_grey",
            value = clamp_01(progress),
            band = {"exotic-industries.exotic-assembler-gui-cycle-band-initial"},
        }
    end

    if progress < 0.75 then
        return {
            style = "ei_status_progressbar_purple",
            value = clamp_01(progress),
            band = {"exotic-industries.exotic-assembler-gui-cycle-band-rising"},
        }
    end

    return {
        style = "ei_status_progressbar_red",
        value = clamp_01(progress),
        band = {"exotic-industries.exotic-assembler-gui-cycle-band-terminal"},
    }
end


function model.get_support_display(snapshot)
    local weight = snapshot.stabilizer_weight or 0
    local hold_required = snapshot.forecast_hold_weight_required or 0
    local buffer_required = snapshot.forecast_buffer_weight_required or 0
    if weight <= 0 then
        return {
            style = "ei_status_progressbar_grey",
            value = 0,
            band = {"exotic-industries.exotic-assembler-gui-support-band-absent"},
        }
    end

    if hold_required <= 0 or weight >= hold_required then
        return {
            style = "ei_status_progressbar_cyan",
            value = clamp_01(weight / math.max(1, hold_required)),
            band = {"exotic-industries.exotic-assembler-gui-support-band-anchored"},
        }
    end

    if buffer_required > 0 and weight >= buffer_required then
        return {
            style = "ei_status_progressbar_grey",
            value = clamp_01(weight / math.max(1, hold_required)),
            band = {"exotic-industries.exotic-assembler-gui-support-band-buffered"},
        }
    end

    return {
        style = "ei_status_progressbar_purple",
        value = clamp_01(weight / math.max(1, math.max(buffer_required, GUI_SUPPORT_MAX_WEIGHT))),
        band = {"exotic-industries.exotic-assembler-gui-support-band-thin"},
    }
end


function model.get_forecast_display(snapshot)
    if snapshot.forecast_tier == "critical" then
        return {
            style = "ei_status_progressbar_red",
            value = clamp_01(snapshot.forecast_risk_per_second / RISK_CRITICAL_THRESHOLD),
            band = {"exotic-industries.exotic-assembler-gui-forecast-band-cascade"},
        }
    end

    if snapshot.forecast_tier == "strained" then
        return {
            style = "ei_status_progressbar_purple",
            value = clamp_01(snapshot.forecast_risk_per_second / RISK_CRITICAL_THRESHOLD),
            band = {"exotic-industries.exotic-assembler-gui-forecast-band-strain"},
        }
    end

    return {
        style = "ei_status_progressbar_cyan",
        value = clamp_01(snapshot.forecast_risk_per_second / RISK_STRAINED_THRESHOLD),
        band = {"exotic-industries.exotic-assembler-gui-forecast-band-hold"},
    }
end


function model.build_gui(player)
    if not (player and player.valid and player.gui and player.gui.relative) then
        return nil
    end

    local root = player.gui.relative.add{
        type = "frame",
        name = GUI_NAME,
        anchor = {
            gui = defines.relative_gui_type.assembling_machine_gui,
            name = "ei-exotic-assembler",
            position = defines.relative_gui_position.right,
        },
        direction = "vertical",
    }
    root.style.minimal_width = 320

    local titlebar = root.add{type = "flow", direction = "horizontal"}
    titlebar.add{
        type = "label",
        caption = {"exotic-industries.exotic-assembler-gui-title"},
        style = "frame_title",
    }
    titlebar.add{
        type = "empty-widget",
        style = "ei_titlebar_nondraggable_spacer",
        ignored_by_interaction = true,
    }
    titlebar.add{
        type = "sprite-button",
        sprite = "virtual-signal/informatron",
        tooltip = {"exotic-industries.gui-open-informatron"},
        style = "frame_action_button",
        tags = {
            parent_gui = GUI_NAME,
            action = "goto-informatron",
            page = "exotic_stabilizer",
        },
    }

    local main_container = root.add{
        type = "frame",
        name = "main-container",
        direction = "vertical",
        style = "inside_shallow_frame",
    }
    main_container.style.minimal_width = 320
    main_container.style.horizontally_stretchable = true

    main_container.add{
        type = "frame",
        style = "ei_subheader_frame",
    }.add{
        type = "label",
        caption = {"exotic-industries.exotic-assembler-gui-status-title"},
        style = "subheader_caption_label",
    }

    local status_flow = main_container.add{
        type = "flow",
        name = "status-flow",
        direction = "vertical",
        style = "ei_inner_content_flow",
    }
    status_flow.style.horizontally_stretchable = true
    status_flow.style.vertical_spacing = 8

    add_status_row(status_flow, "containment-state", "exotic-assembler-gui-containment-state-title", "ei_status_progressbar_grey")
    add_status_row(status_flow, "cycle-pressure", "exotic-assembler-gui-cycle-pressure-title", "ei_status_progressbar_purple")
    add_status_row(status_flow, "lattice-support", "exotic-assembler-gui-lattice-support-title", "ei_status_progressbar_cyan")
    add_status_row(status_flow, "peak-forecast", "exotic-assembler-gui-peak-forecast-title", "ei_status_progressbar_grey")

    return root
end


function model.update_gui(player, snapshot)
    if not (player and player.valid and snapshot) then
        return
    end

    local root = get_gui_root(player)
    if not root then
        root = model.build_gui(player)
    end
    if not root then
        return
    end

    local status_flow = root["main-container"] and root["main-container"]["status-flow"]
    if not (status_flow and status_flow.valid) then
        return
    end

    local containment_row = status_flow["containment-state-row"]
    local cycle_row = status_flow["cycle-pressure-row"]
    local support_row = status_flow["lattice-support-row"]
    local forecast_row = status_flow["peak-forecast-row"]
    if not (containment_row and cycle_row and support_row and forecast_row) then
        return
    end

    local containment_title = containment_row["title"]
    local containment_bar = containment_row["bar"]
    local cycle_title = cycle_row["title"]
    local cycle_bar = cycle_row["bar"]
    local support_title = support_row["title"]
    local support_bar = support_row["bar"]
    local forecast_title = forecast_row["title"]
    local forecast_bar = forecast_row["bar"]
    if not (
        containment_title and containment_bar
        and cycle_title and cycle_bar
        and support_title and support_bar
        and forecast_title and forecast_bar
    ) then
        return
    end

    local containment = model.get_containment_display(snapshot)
    local cycle_pressure = model.get_cycle_pressure_display(snapshot)
    local support = model.get_support_display(snapshot)
    local forecast = model.get_forecast_display(snapshot)
    local snapshot_tick = snapshot.snapshot_tick or 0
    local snapshot_seconds = format_snapshot_seconds(snapshot_tick)
    local containment_tooltip = {
        "exotic-industries.exotic-assembler-gui-containment-state-tooltip",
        snapshot_seconds,
        format_percent(snapshot.base_chance),
        format_percent(snapshot.current_risk_per_second),
        format_percent(snapshot.current_per_update_chance),
        format_multiplier(snapshot.current_progress_multiplier),
    }
    local cycle_tooltip = {
        "exotic-industries.exotic-assembler-gui-cycle-pressure-tooltip",
        snapshot_seconds,
        format_percent(snapshot.current_progress),
        format_multiplier(snapshot.current_progress_multiplier),
    }
    local support_tooltip = {
        "exotic-industries.exotic-assembler-gui-lattice-support-tooltip",
        snapshot_seconds,
        snapshot.active_stabilizer_count or 0,
        snapshot.stabilizer_weight or 0,
    }
    local forecast_tooltip = {
        "exotic-industries.exotic-assembler-gui-peak-forecast-tooltip",
        snapshot_seconds,
        format_percent(snapshot.forecast_risk_per_second),
        forecast.band,
    }

    set_progressbar_style(containment_bar, containment.style)
    containment_bar.value = containment.value
    containment_bar.caption = containment.band
    containment_bar.tooltip = containment_tooltip
    containment_title.tooltip = containment_tooltip

    set_progressbar_style(cycle_bar, cycle_pressure.style)
    cycle_bar.value = cycle_pressure.value
    cycle_bar.caption = cycle_pressure.band
    cycle_bar.tooltip = cycle_tooltip
    cycle_title.tooltip = cycle_tooltip

    set_progressbar_style(support_bar, support.style)
    support_bar.value = support.value
    support_bar.caption = support.band
    support_bar.tooltip = support_tooltip
    support_title.tooltip = support_tooltip

    set_progressbar_style(forecast_bar, forecast.style)
    forecast_bar.value = forecast.value
    forecast_bar.caption = forecast.band
    forecast_bar.tooltip = forecast_tooltip
    forecast_title.tooltip = forecast_tooltip

    local gui_state = model.get_gui_state()
    local session = gui_state.open_by_player[player.index]
    if session then
        session.last_signature = snapshot.projection_signature
    end
end


function model.open_gui(player, event)
    if not (player and player.valid) then
        return
    end

    local entity = model.get_open_matter_machine(player)
    if not model.check_entity(entity) then
        model.close_gui(player)
        return
    end

    local runtime = model.ensure_runtime_ready()
    if not runtime or runtime.runtime_rebuild_in_progress then
        return
    end

    local unit_number = ei_lib.get_entity_unit_number(entity)
    if not unit_number then
        model.close_gui(player)
        return
    end

    local machine_data = runtime.machines[unit_number]
    if not machine_data then
        model.register_matter_machine(entity)
        runtime = storage.ei.matter_runtime
        machine_data = runtime and runtime.machines[unit_number]
    end
    if not machine_data then
        model.close_gui(player)
        return
    end

    model.ensure_gui_session(player.index, unit_number)

    local tick = now_tick(event and event.tick)
    local snapshot = model.refresh_machine_snapshot(runtime, machine_data, tick)
    if snapshot then
        model.update_gui(player, snapshot)
    else
        model.close_gui(player)
    end
end


function model.close_gui(player)
    if not player then
        return
    end

    model.clear_gui_session(player.index, true, "gui_closed")
end


function model.on_gui_click(event)
    local element = event and event.element
    if not (element and element.valid and element.tags) then
        return
    end

    if element.tags.action == "goto-informatron" then
        remote.call("informatron", "informatron_open_to_page", {
            player_index = event.player_index,
            interface = "exotic-industries-informatron",
            page_name = element.tags.page or "exotic_stabilizer",
        })
    end
end


function model.service_due_gui_refreshes(event_tick)
    local gui_state = model.get_gui_state()
    local tick = now_tick(event_tick)
    if gui_state.last_gui_service_tick == tick then
        local next_refresh_tick = tonumber(gui_state.next_refresh_tick) or recalculate_gui_next_refresh_tick(gui_state)
        if next_refresh_tick <= 0 or next_refresh_tick > tick then
            return
        end
    end

    gui_state.last_gui_service_tick = tick

    if next(gui_state.open_by_player) == nil then
        gui_state.refresh_buckets = ei_runtime_scheduler.ensure_delayed_buckets(nil)
        gui_state.next_refresh_tick = 0
        return
    end

    local next_refresh_tick = tonumber(gui_state.next_refresh_tick) or recalculate_gui_next_refresh_tick(gui_state)
    if next_refresh_tick <= 0 or next_refresh_tick > tick then
        return
    end

    local runtime = model.ensure_runtime_ready()
    if not runtime or runtime.runtime_rebuild_in_progress then
        return
    end

    local due_ticks = {}
    for bucket_tick, _ in pairs(gui_state.refresh_buckets) do
        if bucket_tick <= tick then
            due_ticks[#due_ticks + 1] = bucket_tick
        end
    end

    if #due_ticks == 0 then
        recalculate_gui_next_refresh_tick(gui_state)
        return
    end

    table.sort(due_ticks)

    local due_players = {}
    for _, due_tick in pairs(due_ticks) do
        local bucket = ei_runtime_scheduler.delayed_take_due(gui_state.refresh_buckets, due_tick)
        for _, player_index in pairs(bucket) do
            due_players[player_index] = true
        end
    end
    recalculate_gui_next_refresh_tick(gui_state)

    local player_groups = {}
    for player_index, _ in pairs(due_players) do
        local session = gui_state.open_by_player[player_index]
        if session and session.pending_tick and session.pending_tick <= tick then
            local player = game and game.get_player(player_index)
            local opened_entity = model.get_open_matter_machine(player)
            local opened_unit_number = ei_lib.get_entity_unit_number(opened_entity)

            if not (player and player.valid)
                or opened_unit_number ~= session.unit_number
            then
                model.clear_gui_session(player_index, true, "gui_stale_cleaned")
            else
                local group = player_groups[session.unit_number]
                if not group then
                    group = {}
                    player_groups[session.unit_number] = group
                end

                group[#group + 1] = {
                    player = player,
                    player_index = player_index,
                    session = session,
                }
            end
        end
    end

    for unit_number, group in pairs(player_groups) do
        local machine_data = runtime.machines[unit_number]
        if not machine_data or not model.check_entity(machine_data.entity) then
            for _, entry in pairs(group) do
                model.clear_gui_session(entry.player_index, true, "gui_stale_cleaned")
            end
        else
            local snapshot = model.refresh_machine_snapshot(runtime, machine_data, tick)
            if not snapshot then
                for _, entry in pairs(group) do
                    model.clear_gui_session(entry.player_index, true, "gui_stale_cleaned")
                end
            else
                for _, entry in pairs(group) do
                    entry.session.pending_tick = nil
                    if entry.session.last_signature ~= snapshot.projection_signature or not get_gui_root(entry.player) then
                        model.update_gui(entry.player, snapshot)
                    end
                end
            end
        end
    end
end


function model.get_runtime_status()
    local runtime = model.ensure_runtime_ready()
    local gui_state = model.get_gui_state()
    local tier_counts = {
        dormant = 0,
        stable = 0,
        strained = 0,
        critical = 0,
        unsampled = 0,
    }

    for _, machine_data in pairs(runtime and runtime.machines or {}) do
        local entity = machine_data and machine_data.entity
        if model.check_entity(entity) then
            local snapshot = machine_data.volatility_snapshot
            local tier = entity.is_crafting()
                and ((snapshot and snapshot.current_tier) or machine_data.warning_state or "unsampled")
                or "dormant"
            tier_counts[tier] = (tier_counts[tier] or 0) + 1
        else
            tier_counts.unsampled = tier_counts.unsampled + 1
        end
    end

    local status = {
        machine_count = runtime and runtime.machine_count or 0,
        stabilizer_count = runtime and runtime.stabilizer_count or 0,
        active_surface_count = runtime and #(runtime.active_surfaces or {}) or 0,
        open_gui_count = ei_runtime_scheduler.table_count(gui_state.open_by_player),
        watched_machine_count = ei_runtime_scheduler.table_count(gui_state.watchers_by_unit),
        pending_refresh_bucket_count = ei_runtime_scheduler.delayed_bucket_count(gui_state.refresh_buckets),
        pending_refresh_item_count = ei_runtime_scheduler.delayed_item_count(gui_state.refresh_buckets),
        last_gui_service_tick = gui_state.last_gui_service_tick or 0,
        dormant_count = tier_counts.dormant,
        stable_count = tier_counts.stable,
        strained_count = tier_counts.strained,
        critical_count = tier_counts.critical,
        unsampled_count = tier_counts.unsampled,
        tier_counts = tier_counts,
        entries = runtime and runtime.machine_count or 0,
    }

    ei_runtime_scheduler.set_module_status(MODULE_NAME, status)
    return status
end


function model.get_due_gui_refresh_count(event)
    local gui_state = storage and storage.ei and storage.ei.matter_stabilizer_gui or nil
    local open_by_player = type(gui_state) == "table" and gui_state.open_by_player or nil
    if type(open_by_player) ~= "table" or next(open_by_player) == nil then
        return 0
    end

    local tick = now_tick(event and event.tick)
    local next_refresh_tick = tonumber(gui_state.next_refresh_tick) or recalculate_gui_next_refresh_tick(gui_state)
    if next_refresh_tick <= 0 or next_refresh_tick > tick then
        return 0
    end

    return count_due_bucket_items(gui_state.refresh_buckets, tick)
end


function model.get_pending_work_count(event)
    local runtime = storage and storage.ei and storage.ei.matter_runtime or nil
    if type(runtime) ~= "table" then
        return 1
    end

    if runtime.runtime_rebuild_in_progress then
        return 0
    end

    if runtime.version ~= MATTER_RUNTIME_VERSION
        or runtime.needs_rebuild == true
        or not runtime.machine_surface_queues
        or not runtime.active_surfaces
    then
        return 1
    end

    local machine_count = tonumber(runtime.machine_count) or 0
    if machine_count > 0 then
        return machine_count
    end

    local due_gui_refresh_count = model.get_due_gui_refresh_count(event)
    return due_gui_refresh_count > 0 and 1 or 0
end


function model.has_tick_work(event)
    return model.get_pending_work_count(event) > 0
end


function model.get_player_render_list(player_index, create)
    local runtime = model.check_global()
    local render_list = runtime.selected_render[player_index]

    if not render_list and create then
        render_list = {}
        runtime.selected_render[player_index] = render_list
    end

    return render_list
end


function model.remove_rendering_by_unit(unit_number)
    local runtime = model.check_global()
    if not runtime.selected_render then
        return
    end

    for _, render_list in pairs(runtime.selected_render) do
        local index = #render_list
        while index >= 1 do
            local render_entry = render_list[index]
            if render_entry.source_unit == unit_number or render_entry.target_unit == unit_number then
                destroy_render_object(render_entry.render)
                table.remove(render_list, index)
            end
            index = index - 1
        end
    end
end


function model.ensure_surface_queue(runtime, surface_index)
    local queue = runtime.machine_surface_queues[surface_index]
    if not queue then
        queue = new_surface_queue()
        runtime.machine_surface_queues[surface_index] = queue
    end

    return queue
end


function model.sync_active_surface(runtime, surface_index)
    local count = runtime.machine_surface_counts[surface_index] or 0
    local position = runtime.active_surface_positions[surface_index]

    if count > 0 and not position then
        table.insert(runtime.active_surfaces, surface_index)
        runtime.active_surface_positions[surface_index] = #runtime.active_surfaces
        return
    end

    if count <= 0 and position then
        local last_index = #runtime.active_surfaces
        local last_surface = runtime.active_surfaces[last_index]

        runtime.active_surfaces[position] = last_surface
        runtime.active_surfaces[last_index] = nil
        runtime.active_surface_positions[surface_index] = nil

        if last_surface and last_surface ~= surface_index then
            runtime.active_surface_positions[last_surface] = position
        end

        if runtime.active_surface_cursor > #runtime.active_surfaces then
            runtime.active_surface_cursor = 1
        end
    end
end


function model.add_machine_to_surface_queue(runtime, machine_data)
    local surface_index = machine_data.surface_index
    local queue = model.ensure_surface_queue(runtime, surface_index)

    if queue.positions[machine_data.unit_number] then
        return
    end

    table.insert(queue.items, machine_data.unit_number)
    queue.positions[machine_data.unit_number] = #queue.items

    runtime.machine_surface_counts[surface_index] = (runtime.machine_surface_counts[surface_index] or 0) + 1
    model.sync_active_surface(runtime, surface_index)
end


function model.remove_machine_from_surface_queue(runtime, machine_data)
    local surface_index = machine_data.surface_index
    local queue = runtime.machine_surface_queues[surface_index]
    if not queue then
        return
    end

    local index = queue.positions[machine_data.unit_number]
    if not index then
        return
    end

    local last_index = #queue.items
    local last_unit_number = queue.items[last_index]

    queue.items[index] = last_unit_number
    queue.items[last_index] = nil
    queue.positions[machine_data.unit_number] = nil

    if last_unit_number and last_unit_number ~= machine_data.unit_number then
        queue.positions[last_unit_number] = index
    end

    if queue.cursor > #queue.items then
        queue.cursor = 1
    end

    runtime.machine_surface_counts[surface_index] = math.max(
        0,
        (runtime.machine_surface_counts[surface_index] or 0) - 1
    )
    model.sync_active_surface(runtime, surface_index)
end


function model.add_to_chunk_store(chunk_store, surface_index, chunk_x, chunk_y, unit_number)
    local bucket = get_chunk_bucket(chunk_store, surface_index, chunk_x, chunk_y, true)
    bucket[unit_number] = true
end


function model.remove_from_chunk_store(chunk_store, surface_index, chunk_x, chunk_y, unit_number)
    local bucket, key, surface_store = get_chunk_bucket(chunk_store, surface_index, chunk_x, chunk_y, false)
    if not bucket then
        return
    end

    bucket[unit_number] = nil

    if next(bucket) == nil then
        surface_store[key] = nil
    end

    if surface_store and next(surface_store) == nil then
        chunk_store[surface_index] = nil
    end
end


function model.link_stabilizer_and_machine(stabilizer_data, machine_data)
    stabilizer_data.linked_machines[machine_data.unit_number] = true
    machine_data.nearby_stabilizers[stabilizer_data.unit_number] = true
end


function model.query_runtime_registry_in_range(runtime, registry, chunk_store, surface, position, range)
    local results = {}
    local surface_index = ei_lib.get_surface_index(surface)
    if not surface_index then
        return results
    end

    local surface_store = chunk_store[surface_index]
    if not surface_store then
        return results
    end

    local min_chunk_x, max_chunk_x, min_chunk_y, max_chunk_y = ei_lib.get_chunk_coverage(position, range, MATTER_CHUNK_SIZE)
    local max_range_sqr = range * range

    for chunk_x = min_chunk_x, max_chunk_x do
        for chunk_y = min_chunk_y, max_chunk_y do
            local bucket = surface_store[get_chunk_key(chunk_x, chunk_y)]
            if bucket then
                for unit_number, _ in pairs(bucket) do
                    local data = registry[unit_number]
                    local entity = data and data.entity
                    if model.check_entity(entity)
                        and ei_lib.is_within_range_squared(entity.position, position, max_range_sqr) then
                        table.insert(results, data)
                    end
                end
            end
        end
    end

    return results
end


function model.query_nearby_stabilizers(runtime, surface, position, range)
    return model.query_runtime_registry_in_range(runtime, runtime.stabilizers, runtime.stabilizer_chunks, surface, position, range)
end


function model.query_nearby_machines(runtime, surface, position, range)
    return model.query_runtime_registry_in_range(runtime, runtime.machines, runtime.machine_chunks, surface, position, range)
end


function model.remove_stabilizer_by_unit(runtime, unit_number)
    local stabilizer_data = runtime.stabilizers[unit_number]
    if not stabilizer_data then
        storage.ei.matter_stabilizers[unit_number] = nil
        return
    end

    for machine_unit_number, _ in pairs(stabilizer_data.linked_machines) do
        local machine_data = runtime.machines[machine_unit_number]
        if machine_data then
            machine_data.nearby_stabilizers[unit_number] = nil
        end
        model.queue_gui_refresh_for_unit(machine_unit_number, now_tick())
    end

    model.remove_from_chunk_store(
        runtime.stabilizer_chunks,
        stabilizer_data.surface_index,
        stabilizer_data.chunk_x,
        stabilizer_data.chunk_y,
        unit_number
    )

    runtime.stabilizers[unit_number] = nil
    runtime.stabilizer_count = math.max(0, runtime.stabilizer_count - 1)
    storage.ei.matter_stabilizers[unit_number] = nil
    storage.ei.matter_stabilizers_count = runtime.stabilizer_count

    model.remove_rendering_by_unit(unit_number)
end


function model.remove_matter_machine_by_unit(runtime, unit_number)
    local machine_data = runtime.machines[unit_number]
    if not machine_data then
        model.close_sessions_for_unit(unit_number, true, "gui_stale_cleaned")
        storage.ei.matter_machines[unit_number] = nil
        return
    end

    model.close_sessions_for_unit(unit_number, true, "gui_stale_cleaned")

    for stabilizer_unit_number, _ in pairs(machine_data.nearby_stabilizers) do
        local stabilizer_data = runtime.stabilizers[stabilizer_unit_number]
        if stabilizer_data then
            stabilizer_data.linked_machines[unit_number] = nil
        end
    end

    model.remove_from_chunk_store(
        runtime.machine_chunks,
        machine_data.surface_index,
        machine_data.chunk_x,
        machine_data.chunk_y,
        unit_number
    )
    model.remove_machine_from_surface_queue(runtime, machine_data)
    model.destroy_machine_fx(runtime, unit_number)

    runtime.machines[unit_number] = nil
    runtime.machine_count = math.max(0, runtime.machine_count - 1)
    storage.ei.matter_machines[unit_number] = nil
    storage.ei.matter_machines_count = runtime.machine_count

    model.remove_rendering_by_unit(unit_number)
end


function model.register_stabilizer(entity)
    local runtime = model.check_global()
    local unit_number = ei_lib.get_entity_unit_number(entity)
    if not model.check_entity(entity) or not unit_number then
        return
    end

    if runtime.stabilizers[unit_number] then
        model.remove_stabilizer_by_unit(runtime, unit_number)
    end

    local chunk_x, chunk_y = ei_lib.get_chunk_coordinates(entity.position, MATTER_CHUNK_SIZE)
    local stabilizer_data = {
        unit_number = unit_number,
        entity = entity,
        surface_index = entity.surface.index,
        chunk_x = chunk_x,
        chunk_y = chunk_y,
        weight = model.get_stabilizer_weight(entity),
        linked_machines = {}
    }

    runtime.stabilizers[unit_number] = stabilizer_data
    runtime.stabilizer_count = runtime.stabilizer_count + 1
    storage.ei.matter_stabilizers[unit_number] = entity
    storage.ei.matter_stabilizers_count = runtime.stabilizer_count

    model.add_to_chunk_store(
        runtime.stabilizer_chunks,
        stabilizer_data.surface_index,
        chunk_x,
        chunk_y,
        unit_number
    )

    local nearby_machines = model.query_nearby_machines(runtime, entity.surface, entity.position, MATTER_RANGE)
    for _, machine_data in pairs(nearby_machines) do
        model.link_stabilizer_and_machine(stabilizer_data, machine_data)
        model.queue_gui_refresh_for_unit(machine_data.unit_number, now_tick())
    end
end


function model.register_matter_machine(entity)
    local runtime = model.check_global()
    local unit_number = ei_lib.get_entity_unit_number(entity)
    if not model.check_entity(entity) or not unit_number then
        return
    end

    if runtime.machines[unit_number] then
        model.remove_matter_machine_by_unit(runtime, unit_number)
    end

    local chunk_x, chunk_y = ei_lib.get_chunk_coordinates(entity.position, MATTER_CHUNK_SIZE)
    local machine_data = {
        unit_number = unit_number,
        entity = entity,
        surface_index = entity.surface.index,
        chunk_x = chunk_x,
        chunk_y = chunk_y,
        nearby_stabilizers = {},
        warning_state = "stable",
        critical_since_tick = nil,
        last_warning_tick = 0,
        last_imminent_warning_tick = 0,
        last_crackle_tick = 0,
        last_arc_tick = 0,
        pulse_seed = unit_number % 360,
        volatility_snapshot = nil,
    }

    runtime.machines[unit_number] = machine_data
    runtime.machine_count = runtime.machine_count + 1
    storage.ei.matter_machines[unit_number] = entity
    storage.ei.matter_machines_count = runtime.machine_count

    model.add_to_chunk_store(
        runtime.machine_chunks,
        machine_data.surface_index,
        chunk_x,
        chunk_y,
        unit_number
    )
    model.add_machine_to_surface_queue(runtime, machine_data)

    local nearby_stabilizers = model.query_nearby_stabilizers(runtime, entity.surface, entity.position, MATTER_RANGE)
    for _, stabilizer_data in pairs(nearby_stabilizers) do
        model.link_stabilizer_and_machine(stabilizer_data, machine_data)
    end
end


function model.unregister_stabilizer(entity)
    local runtime = model.check_global()
    local unit_number = ei_lib.get_entity_unit_number(entity)
    if not unit_number then
        return
    end

    model.remove_stabilizer_by_unit(runtime, unit_number)
end


function model.unregister_matter_machine(entity)
    local runtime = model.check_global()
    local unit_number = ei_lib.get_entity_unit_number(entity)
    if not unit_number then
        return
    end

    model.remove_matter_machine_by_unit(runtime, unit_number)
end


function model.get_risk_tier(risk_per_second_estimate)
    if risk_per_second_estimate >= RISK_CRITICAL_THRESHOLD then
        return "critical"
    end

    if risk_per_second_estimate >= RISK_STRAINED_THRESHOLD then
        return "strained"
    end

    return "stable"
end


function model.draw_warning_text(entity, localised_text, color, ttl, scale)
    if not model.check_entity(entity) then
        return
    end

    rendering.draw_text{
        text = localised_text,
        surface = entity.surface,
        target = {
            entity = entity,
            offset = {0, -2.15}
        },
        color = color,
        alignment = "center",
        vertical_alignment = "middle",
        scale = scale,
        time_to_live = ttl,
        forces = {entity.force}
    }
end


function model.ensure_machine_light(runtime, machine_data)
    local fx_state = runtime.machine_fx[machine_data.unit_number]
    if fx_state
        and fx_state.light and fx_state.light.valid
        and fx_state.halo and fx_state.halo.valid
        and fx_state.outer_aura and fx_state.outer_aura.valid then
        return fx_state
    end

    if fx_state then
        destroy_render_object(fx_state.light)
        destroy_render_object(fx_state.halo)
        destroy_render_object(fx_state.outer_aura)
    end

    local light = rendering.draw_light{
        sprite = GLOW_SPRITE,
        scale = 1.45,
        intensity = 1.08,
        color = {r = 0.72, g = 0.24, b = 0.96},
        target = machine_data.entity,
        surface = machine_data.entity.surface,
        blend_mode = "multiplicative",
        apply_runtime_tint = true,
        draw_as_glow = true,
        time_to_live = 0,
        forces = {machine_data.entity.force}
    }

    local halo = rendering.draw_light{
        sprite = GLOW_SPRITE,
        scale = 3.35,
        intensity = 0.48,
        color = {r = 0.42, g = 0.08, b = 0.72},
        target = machine_data.entity,
        surface = machine_data.entity.surface,
        blend_mode = "multiplicative",
        apply_runtime_tint = true,
        draw_as_glow = true,
        time_to_live = 0,
        forces = {machine_data.entity.force}
    }

    local outer_aura = rendering.draw_light{
        sprite = GLOW_SPRITE,
        scale = 4.9,
        intensity = 0.0,
        color = {r = 0.2, g = 0.03, b = 0.38},
        target = machine_data.entity,
        surface = machine_data.entity.surface,
        blend_mode = "multiplicative-with-alpha",
        apply_runtime_tint = true,
        draw_as_glow = true,
        time_to_live = 0,
        forces = {machine_data.entity.force}
    }

    runtime.machine_fx[machine_data.unit_number] = {
        light = light,
        halo = halo,
        outer_aura = outer_aura
    }

    return runtime.machine_fx[machine_data.unit_number]
end


function model.spawn_machine_crackle(machine_data, tier)
    local entity = machine_data.entity
    if not model.check_entity(entity) then
        return
    end

    local pos = entity.position
    local offsets = {
        {x = -1.05, y = -1.05},
        {x =  1.05, y = -1.05},
        {x = -1.05, y =  1.05},
        {x =  1.05, y =  1.05}
    }
    local crackle_count = tier == "critical" and 2 or 1

    for _ = 1, crackle_count do
        local offset = offsets[math.random(1, #offsets)]
        local crackle_position = {
            x = pos.x + offset.x,
            y = pos.y + offset.y
        }

        rendering.draw_animation{
            animation = CRACKLE_ANIMATION,
            target = crackle_position,
            surface = entity.surface,
            render_layer = "object",
            x_scale = tier == "critical" and 0.75 or 0.6,
            y_scale = tier == "critical" and 0.75 or 0.6,
            time_to_live = tier == "critical" and 36 or 24
        }

        entity.surface.create_trivial_smoke{
            name = "electric-smoke",
            position = crackle_position
        }
    end
end


function model.spawn_machine_arc(machine_data, active_stabilizers)
    local entity = machine_data.entity
    if not model.check_entity(entity) or #active_stabilizers == 0 then
        return
    end

    local stabilizer_data = active_stabilizers[math.random(1, #active_stabilizers)]
    local stabilizer = stabilizer_data and stabilizer_data.entity
    if not model.check_entity(stabilizer) then
        return
    end

    entity.surface.create_entity{
        name = ARC_BEAM_NAME,
        position = stabilizer.position,
        source = stabilizer,
        target = entity,
        force = entity.force,
        duration = 18
    }

    entity.surface.create_trivial_smoke{
        name = "electric-smoke",
        position = stabilizer.position
    }
    entity.surface.create_trivial_smoke{
        name = "electric-smoke",
        position = entity.position
    }
end


function model.update_machine_presentation(runtime, machine_data, risk_tier, risk_per_second_estimate, active_stabilizers, current_tick)
    local entity = machine_data.entity
    if not model.check_entity(entity) then
        return
    end

    local fx_state = model.ensure_machine_light(runtime, machine_data)
    local light = fx_state.light
    local halo = fx_state.halo
    local outer_aura = fx_state.outer_aura
    local tick = now_tick(current_tick)
    local pulse_period = 16
    local scale_base = 1.38
    local scale_delta = 0.22
    local intensity_base = 1.06
    local intensity_delta = 0.2
    local halo_scale_base = 3.1
    local halo_scale_delta = 0.45
    local halo_intensity_base = 0.46
    local halo_intensity_delta = 0.13
    local outer_scale_base = 4.9
    local outer_scale_delta = 0.25
    local outer_intensity_base = 0.0
    local outer_intensity_delta = 0.0
    local color = {r = 0.7, g = 0.22, b = 0.92}
    local halo_color = {r = 0.42, g = 0.08, b = 0.72}
    local outer_color = {r = 0.2, g = 0.03, b = 0.38}
    local crackle_cooldown = STRAINED_CRACKLE_COOLDOWN_TICKS

    if risk_tier == "strained" then
        pulse_period = 12
        scale_base = 1.58
        scale_delta = 0.3
        intensity_base = 1.28
        intensity_delta = 0.28
        halo_scale_base = 3.7
        halo_scale_delta = 0.6
        halo_intensity_base = 0.6
        halo_intensity_delta = 0.18
        outer_scale_base = 5.1
        outer_scale_delta = 0.3
        color = {r = 0.88, g = 0.3, b = 1.0}
        halo_color = {r = 0.58, g = 0.12, b = 0.84}
        outer_color = {r = 0.24, g = 0.04, b = 0.46}
        crackle_cooldown = STRAINED_CRACKLE_COOLDOWN_TICKS
    elseif risk_tier == "critical" then
        pulse_period = 8
        scale_base = 1.82
        scale_delta = 0.42
        intensity_base = 1.56
        intensity_delta = 0.4
        halo_scale_base = 4.4
        halo_scale_delta = 0.9
        halo_intensity_base = 0.78
        halo_intensity_delta = 0.24
        outer_scale_base = 5.6
        outer_scale_delta = 1.15
        outer_intensity_base = 0.22
        outer_intensity_delta = 0.14
        color = {r = 1.0, g = 0.62, b = 1.0}
        halo_color = {r = 0.85, g = 0.24, b = 1.0}
        outer_color = {r = 0.98, g = 0.32, b = 1.0}
        crackle_cooldown = CRITICAL_CRACKLE_COOLDOWN_TICKS
    end

    local pulse = 0.5 + 0.5 * math.sin((tick + machine_data.pulse_seed) / pulse_period)
    local glow_pressure = math.min(0.28, risk_per_second_estimate * 0.12)
    local halo_pressure = math.min(0.18, risk_per_second_estimate * 0.07)
    local outer_pressure = 0
    if risk_tier == "critical" then
        outer_pressure = math.min(0.12, risk_per_second_estimate * 0.05)
    end
    light.color = color
    light.scale = scale_base + scale_delta * pulse
    light.intensity = intensity_base + intensity_delta * pulse + glow_pressure
    halo.color = halo_color
    halo.scale = halo_scale_base + halo_scale_delta * pulse
    halo.intensity = halo_intensity_base + halo_intensity_delta * pulse + halo_pressure
    outer_aura.color = outer_color
    outer_aura.scale = outer_scale_base + outer_scale_delta * pulse
    outer_aura.intensity = outer_intensity_base + outer_intensity_delta * pulse + outer_pressure

    local previous_state = machine_data.warning_state or "stable"
    machine_data.warning_state = risk_tier

    if risk_tier == "critical" then
        if previous_state ~= "critical" then
            machine_data.critical_since_tick = tick

            if tick - (machine_data.last_warning_tick or 0) >= WARNING_COOLDOWN_TICKS then
                model.draw_warning_text(
                    entity,
                    {"exotic-industries.matter-lattice-failing"},
                    {r = 1.0, g = 0.4, b = 0.9},
                    240,
                    1.8
                )
                machine_data.last_warning_tick = tick
            end
        end

        if tick - (machine_data.last_crackle_tick or 0) >= crackle_cooldown then
            model.spawn_machine_crackle(machine_data, risk_tier)
            machine_data.last_crackle_tick = tick
        end

        if tick - (machine_data.last_arc_tick or 0) >= CRITICAL_ARC_COOLDOWN_TICKS then
            model.spawn_machine_arc(machine_data, active_stabilizers)
            machine_data.last_arc_tick = tick
        end

        if machine_data.critical_since_tick
            and tick - machine_data.critical_since_tick >= IMMINENT_WARNING_DELAY_TICKS
            and tick - (machine_data.last_imminent_warning_tick or 0) >= WARNING_COOLDOWN_TICKS then
            model.draw_warning_text(
                entity,
                {"exotic-industries.entropic-cascade-imminent"},
                {r = 1.0, g = 0.25, b = 0.55},
                300,
                2.0
            )
            machine_data.last_imminent_warning_tick = tick
        end
    else
        machine_data.critical_since_tick = nil

        if risk_tier == "strained"
            and tick - (machine_data.last_crackle_tick or 0) >= crackle_cooldown then
            model.spawn_machine_crackle(machine_data, risk_tier)
            machine_data.last_crackle_tick = tick
        end
    end
end


function model.collect_machine_stabilizers(runtime, machine_data)
    local active_stabilizers = {}
    local stabilizer_weight = 0
    local stale_stabilizers = {}

    for stabilizer_unit_number, _ in pairs(machine_data.nearby_stabilizers) do
        local stabilizer_data = runtime.stabilizers[stabilizer_unit_number]
        local stabilizer = stabilizer_data and stabilizer_data.entity

        if not model.check_entity(stabilizer) then
            table.insert(stale_stabilizers, stabilizer_unit_number)
        elseif ei_lib.is_within_range_squared(stabilizer.position, machine_data.entity.position, MATTER_RANGE_SQR) then
            if not stabilizer.disabled_by_control_behavior then
                stabilizer_weight = stabilizer_weight + (stabilizer_data.weight or 1)
                table.insert(active_stabilizers, stabilizer_data)
            end
        else
            table.insert(stale_stabilizers, stabilizer_unit_number)
        end
    end

    for _, stale_unit_number in pairs(stale_stabilizers) do
        model.remove_stabilizer_by_unit(runtime, stale_unit_number)
    end

    return stabilizer_weight, active_stabilizers
end


function model.reset_machine_state(machine_data)
    machine_data.warning_state = "stable"
    machine_data.critical_since_tick = nil
end


function model.update_matter_machine(machine_data, event_tick)
    local runtime = model.check_global()
    if not machine_data then
        return false
    end

    local tick = now_tick(event_tick)

    local entity = machine_data.entity
    if not model.check_entity(entity) then
        model.remove_matter_machine_by_unit(runtime, machine_data.unit_number)
        return false
    end

    if not entity.is_crafting() then
        local previous_signature = machine_data.volatility_snapshot and machine_data.volatility_snapshot.projection_signature or nil
        model.reset_machine_state(machine_data)
        model.destroy_machine_fx(runtime, machine_data.unit_number)

        if model.machine_has_watchers(machine_data.unit_number) then
            local snapshot = model.refresh_machine_snapshot(runtime, machine_data, tick)
            if snapshot and snapshot.projection_signature ~= previous_signature then
                model.queue_gui_refresh_for_unit(machine_data.unit_number, tick)
            end
        else
            machine_data.volatility_snapshot = nil
        end

        return true
    end

    local previous_signature = machine_data.volatility_snapshot and machine_data.volatility_snapshot.projection_signature or nil
    local snapshot, active_stabilizers = model.refresh_machine_snapshot(runtime, machine_data, tick)
    if not snapshot then
        return false
    end

    local chance = snapshot.current_per_update_chance
    local risk_tier = snapshot.current_tier

    model.update_machine_presentation(
        runtime,
        machine_data,
        risk_tier,
        snapshot.current_risk_per_second,
        active_stabilizers,
        tick
    )

    if snapshot.projection_signature ~= previous_signature then
        model.queue_gui_refresh_for_unit(machine_data.unit_number, tick)
    end

    if math.random() < chance then
        ei_lib.notify_connected_players(
            "matter_machine",
            {"exotic-industries.exotic-assembler-explode", entity.name, entity.gps_tag}
        )
        ei_lib.crystal_echo_floating("Containment Breach: Rationality Compromised.", entity, 6000, nil)
        entity.surface.create_entity{
            name = "ei-matter-explosion",
            position = entity.position,
            target = entity.position,
            speed = 0.3,
            force = entity.force
        }
    end

    return true
end


function model.rebuild_runtime_state(reason)
    local runtime = model.check_global()
    if runtime.runtime_rebuild_in_progress then
        return
    end

    runtime.runtime_rebuild_in_progress = true

    model.clear_all_gui_sessions()
    model.destroy_runtime_state(runtime)
    model.reset_runtime_storage(runtime)

    for _, surface in pairs(game.surfaces) do
        local stabilizers = surface.find_entities_filtered({
            name = model.stabilizer_names
        })

        for _, entity in pairs(stabilizers) do
            if model.check_entity(entity) then
                model.register_stabilizer(entity)
            end
        end
    end

    for _, surface in pairs(game.surfaces) do
        local matter_machines = surface.find_entities_filtered({
            name = model.matter_machine_names
        })

        for _, entity in pairs(matter_machines) do
            if model.check_entity(entity) then
                model.register_matter_machine(entity)
            end
        end
    end

    runtime = storage.ei.matter_runtime
    runtime.needs_rebuild = false
    runtime.runtime_rebuild_in_progress = false

    if reason == "manual" then
        storage.ei.stabilizer_break_point = nil
    end
end


--RENDERING RELATED
------------------------------------------------------------------------------------------------------

function model.draw_connection(source, target, player)

    if not model.check_entity(source) then
        return
    end

    if not model.check_entity(target) then
        return
    end

    local source_unit = ei_lib.get_entity_unit_number(source)
    local target_unit = ei_lib.get_entity_unit_number(target)
    if not source_unit or not target_unit then
        return
    end

    local render_list = model.get_player_render_list(player.index, true)
    for _, render_entry in pairs(render_list) do
        if render_entry.type == "connection"
            and render_entry.source_unit == source_unit
            and render_entry.target_unit == target_unit then
            return
        end
    end

    local render_object = rendering.draw_line{
        color = {r = 0, g = 1, b = 0},
        width = 0.2,
        from = source.position,
        to = target.position,
        surface = source.surface,
        players = {player},
        forces = {source.force},
        draw_on_ground = true,
    }

    table.insert(render_list, {
        render = render_object,
        source_unit = source_unit,
        target_unit = target_unit,
        type = "connection"
    })
end


function model.draw_stabilizer_range(entity, player)

    if not model.check_entity(entity) then
        return
    end

    local entity_unit = ei_lib.get_entity_unit_number(entity)
    if not entity_unit then
        return
    end

    local render_list = model.get_player_render_list(player.index, true)
    for _, render_entry in pairs(render_list) do
        if render_entry.type == "range" and render_entry.source_unit == entity_unit then
            return
        end
    end

    local range = model.stabilizers[entity.name]
    local scale = range / 4

    local render_object = rendering.draw_sprite{
        sprite = "ei-stabilizer-radius",
        target = entity,
        surface = entity.surface,
        players = {player},
        forces = {entity.force},
        render_layer = "radius-visualization",
        x_scale = scale,
        y_scale = scale,
    }

    table.insert(render_list, {
        render = render_object,
        source_unit = entity_unit,
        type = "range"
    })
end


function model.remove_rendering(entity)
    local unit_number = ei_lib.get_entity_unit_number(entity)
    if not unit_number then
        return
    end

    model.remove_rendering_by_unit(unit_number)
end


function model.clear_rendering(player)

    if not player or not player.valid then
        return
    end

    local cursor_stack = player.cursor_stack
    if cursor_stack and cursor_stack.valid_for_read then
        if model.stabilizers[cursor_stack.name] or model.matter_machines[cursor_stack.name] then
            return
        end
    end

    local runtime = model.check_global()
    local render_list = runtime.selected_render[player.index]
    if not render_list then
        return
    end

    model.destroy_player_render_list(render_list)
    runtime.selected_render[player.index] = {}
end


function model.stabilizer_selected(player, entity)

    if not model.check_entity(entity) then
        return
    end

    local runtime = model.check_global()
    local matter_machines = model.query_nearby_machines(runtime, entity.surface, entity.position, model.stabilizers[entity.name])

    for _, machine_data in pairs(matter_machines) do
        if model.check_entity(machine_data.entity) then
            model.draw_connection(entity, machine_data.entity, player)
        end
    end

end


function model.stabilizer_on_cursor(player)

    local position = player.position
    if not position then
        return
    end

    local runtime = model.check_global()
    local stabilizers = model.query_nearby_stabilizers(runtime, player.surface, position, 100)

    for _, stabilizer_data in pairs(stabilizers) do
        if model.check_entity(stabilizer_data.entity) then
            model.draw_stabilizer_range(stabilizer_data.entity, player)
            model.stabilizer_selected(player, stabilizer_data.entity)
        end
    end

end


function model.on_player_left_game(player_index)
    local runtime = model.check_global()
    local render_list = runtime.selected_render[player_index]
    if render_list then
        model.destroy_player_render_list(render_list)
        runtime.selected_render[player_index] = nil
    end

    model.clear_gui_session(player_index, false, "gui_closed")
end


--HANDLERS
------------------------------------------------------------------------------------------------------

function model.on_built_entity(entity)
    local runtime = model.check_global()
    if runtime.needs_rebuild and not runtime.runtime_rebuild_in_progress then
        model.rebuild_runtime_state("auto")
    end

    if model.stabilizers[entity.name] then
        model.register_stabilizer(entity)
    elseif model.matter_machines[entity.name] then
        model.register_matter_machine(entity)
    end
end


function model.on_destroyed_entity(entity)
    local runtime = model.check_global()
    if runtime.needs_rebuild and not runtime.runtime_rebuild_in_progress then
        model.rebuild_runtime_state("auto")
    end

    if model.stabilizers[entity.name] then
        model.unregister_stabilizer(entity)
    elseif model.matter_machines[entity.name] then
        model.unregister_matter_machine(entity)
    end
end


function model.on_selected_entity_changed(event)

    local player = game.get_player(event.player_index)
    if player == nil then
        return
    end

    local new_entity = player.selected
    model.clear_rendering(player)

    if new_entity == nil then
        return
    end

    if model.stabilizers[new_entity.name] then
        model.stabilizer_selected(player, new_entity)
    end

end


function model.on_player_cursor_stack_changed(event)

    local player = game.get_player(event.player_index)
    if player == nil then
        return
    end

    model.clear_rendering(player)

    if player.cursor_stack and player.cursor_stack.valid_for_read then
        local item = player.cursor_stack.name

        if model.stabilizers[item] or model.matter_machines[item] then
            model.stabilizer_on_cursor(player)
        end
    end

end


function model.update(event)
    local tick = now_tick(event and event.tick)
    local runtime = model.ensure_runtime_ready()
    if not runtime or runtime.runtime_rebuild_in_progress then
        return false
    end

    local active_surface_count = #runtime.active_surfaces
    if active_surface_count == 0 then
        model.service_due_gui_refreshes(tick)
        return false
    end

    if runtime.active_surface_cursor > active_surface_count then
        runtime.active_surface_cursor = 1
    end

    local surface_attempts = active_surface_count
    while surface_attempts > 0 do
        local surface_index = runtime.active_surfaces[runtime.active_surface_cursor]
        runtime.active_surface_cursor = runtime.active_surface_cursor + 1
        if runtime.active_surface_cursor > active_surface_count then
            runtime.active_surface_cursor = 1
        end

        local queue = surface_index and runtime.machine_surface_queues[surface_index]
        if queue and #queue.items > 0 then
            if queue.cursor > #queue.items then
                queue.cursor = 1
            end

            local queue_attempts = #queue.items
            while queue_attempts > 0 do
                local unit_number = queue.items[queue.cursor]
                queue.cursor = queue.cursor + 1
                if queue.cursor > #queue.items then
                    queue.cursor = 1
                end

                local machine_data = unit_number and runtime.machines[unit_number]
                if machine_data then
                    model.update_matter_machine(machine_data, tick)
                    model.service_due_gui_refreshes(tick)
                    return true
                end

                queue_attempts = queue_attempts - 1
            end
        end

        surface_attempts = surface_attempts - 1
    end

    model.service_due_gui_refreshes(tick)
    return false
end


commands.add_command("rescan_matter_stabilizers", "Rebuilds matter stabilizer links, queues, and containment FX state.", function(command)
    local player = command.player_index and game.get_player(command.player_index) or nil
    if command.player_index and (not player or not player.admin) then
        return
    end

    ei_lib.crystal_echo("Matter stabilizer runtime rescan initiated.")
    model.rebuild_runtime_state("manual")
    ei_lib.crystal_echo("Matter stabilizer runtime rescan complete.")
end)


return model
