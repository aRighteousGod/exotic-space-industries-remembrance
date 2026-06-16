--==============================================================================
-- ESIR FILE MAP
-- owns: neutron collector runtime, source linking, and relative GUI diagnostics
-- loaded_by: exotic-space-industries-remembrance\control.lua
-- cadence: build/destroy, scheduled tick step 3, GUI open/close/click, and configuration rebuild
-- forwarded_events: add_connected_source, apply_collector_animation, attach_wire_proxy_to_collector, calc_distance, calc_efficiency, calc_fusion_flux, check_global, clear_gui_session, clear_legacy_runtime_fields, clear_queued_collector, close_gui, close_sessions_for_unit, connect_collector, dequeue_dirty_collector, destroy_all_wire_proxies, destroy_wire_proxy, disconnect_collector, ensure_gui_session, ensure_runtime_ready, ensure_wire_proxy, entity_check, find_neutron_source, get_collector_state_key, get_connected_source_count, get_dirty_collector_count, get_dirty_queue, get_due_gui_refresh_count, get_entity_recipe_name, get_gui_snapshot, get_open_neutron_collector, get_pending_work_count, get_source_entry, get_source_fusion_multiplier, get_state, is_output_empty, make_direction_animation, on_built_entity, on_destroyed_entity, on_entity_settings_pasted, on_gui_click, on_gui_opened, on_player_left_game, open_gui, poll_connected_sources, poll_source, process_dirty_collectors, queue_collectors_in_range, queue_dirty_collector, queue_gui_refresh_for_player, queue_gui_refresh_for_unit, rebuild_runtime_state, refresh_collector, register_collector, remove_collector_from_source, remove_connected_source, remove_direction_animation, remove_direction_animation_by_unit, remove_source_entry, reset_runtime_storage, service_gui_refreshes, service_wire_proxy_outputs, show_resolution_text, unregister_collector, update, update_gui, update_neutron_collector, update_neutron_collectors_in_range, update_wire_proxy_signals
-- storage_roots: storage.ei.neutron_runtime, storage.ei.neutron_collector_animation
-- gui_ids: ei-neutron-collector-console
-- remote_interfaces: none
-- rebuild_on: init, configuration change, entity topology changes
--==============================================================================
local model = {}
local ei_runtime_scheduler = require("lib/runtime-scheduler")
local get_entity_unit_number = ei_lib.get_entity_unit_number

local NEUTRON_RUNTIME_VERSION = 7
local NEUTRON_COLLECTOR_NAME = "ei-neutron-collector"
local NEUTRON_IDLE_RECIPE_NAME = "ei-neutron-collector-idle"
local NEUTRON_WIRE_PROXY_NAME = "ei-neutron-collector-circuit-interface"
local NEUTRON_WIRE_PROXY_ENABLED = true
local FUSION_REACTOR_NAME = "ei-fusion-reactor"
local SPACE_AGE_FUSION_REACTOR_NAME = "fusion-reactor"
local DEFAULT_FUSION_RECIPE = "ei-fusion-F1__ei-heated-deuterium-F2__ei-heated-tritium-TM__medium-FM__medium"
local GUI_NAME = "ei-neutron-collector-console"
local GUI_REFRESH_DELAY = 1
local MAX_GUI_CANDIDATES = 3
local NEUTRON_WIRE_UPDATE_INTERVAL = 60

local function make_wire_signal(name)
    return {
        type = "virtual",
        name = name,
        quality = "normal",
        comparator = "=",
    }
end

local SIGNAL_NEUTRON_EFFICIENCY = make_wire_signal("ei-neutron-efficiency")
local SIGNAL_NEUTRON_DISTANCE = make_wire_signal("ei-neutron-distance")
local SIGNAL_NEUTRON_COLLECTOR_AGENT = make_wire_signal("ei-neutron-collector-agent")
local SIGNAL_NEUTRON_SOURCE_AGENT = make_wire_signal("ei-neutron-source-agent")
local SIGNAL_NEUTRON_SCAN_AGENT = make_wire_signal("ei-neutron-scan-agent")

--====================================================================================================
--NEUTRON COLLECTOR
--====================================================================================================

model.range = 10 + 1.5 -- range of neutron collector in tiles + 1.5 collector size
model.neutron_sources = {
    ["ei-high-temperature-reactor"] = -20,
    ["nuclear-reactor"] = -30,
    ["ei-fission-facility"] = -40,
    ["ei-castor"] = -50,
    [FUSION_REACTOR_NAME] = 10,
    [SPACE_AGE_FUSION_REACTOR_NAME] = -50,
}
model.neutron_source_names = {
    "ei-high-temperature-reactor",
    "nuclear-reactor",
    "ei-fission-facility",
    "ei-castor",
    FUSION_REACTOR_NAME,
    SPACE_AGE_FUSION_REACTOR_NAME,
}
model.dist_buffs = {
    [FUSION_REACTOR_NAME] = 3,
}

local COLLECTOR_AGENT_SIGNAL_VALUES = {
    ["neutron-collector-gui-state-active"] = 1,
    ["neutron-collector-gui-state-idle"] = 2,
    ["neutron-collector-gui-state-blocked"] = 3,
}

local SOURCE_AGENT_SIGNAL_VALUES = {
    ["neutron-collector-gui-source-live"] = 1,
    ["neutron-collector-gui-source-dormant"] = 2,
    ["neutron-collector-gui-source-absent"] = 3,
}

local SCAN_AGENT_SIGNAL_VALUES = {
    ["neutron-collector-gui-scan-stable"] = 1,
    ["neutron-collector-gui-scan-dirty"] = 2,
    ["neutron-collector-gui-scan-rebind-pending"] = 3,
}

local function make_dirty_queue()
    return ei_runtime_scheduler.ensure_queue(nil)
end

local function make_wire_output_buckets()
    local buckets = {}
    for i = 0, NEUTRON_WIRE_UPDATE_INTERVAL - 1 do
        buckets[i] = {}
    end
    return buckets
end

local function add_wire_output_bucket(runtime, unit_number)
    if not runtime or type(unit_number) ~= "number" then
        return
    end

    local buckets = runtime.wire_output_buckets
    local index_by_unit = runtime.wire_output_index_by_unit
    if type(buckets) ~= "table" or type(index_by_unit) ~= "table" then
        return
    end

    if index_by_unit[unit_number] then
        return
    end

    local bucket_index = unit_number % NEUTRON_WIRE_UPDATE_INTERVAL
    local bucket = buckets[bucket_index]
    if type(bucket) ~= "table" then
        bucket = {}
        buckets[bucket_index] = bucket
    end

    bucket[#bucket + 1] = unit_number
    index_by_unit[unit_number] = {
        bucket_index = bucket_index,
        slot_index = #bucket,
    }
end

local function remove_wire_output_bucket(runtime, unit_number)
    if not runtime or type(unit_number) ~= "number" then
        return
    end

    local index_by_unit = runtime.wire_output_index_by_unit
    local buckets = runtime.wire_output_buckets
    if type(index_by_unit) ~= "table" or type(buckets) ~= "table" then
        return
    end

    local location = index_by_unit[unit_number]
    if not location then
        return
    end

    local bucket = buckets[location.bucket_index]
    if type(bucket) == "table" then
        local last_index = #bucket
        local slot_index = location.slot_index
        local last_unit = bucket[last_index]

        bucket[slot_index] = last_unit
        bucket[last_index] = nil

        if last_unit ~= nil and last_index ~= slot_index then
            local last_location = index_by_unit[last_unit]
            if last_location then
                last_location.slot_index = slot_index
            end
        end
    end

    index_by_unit[unit_number] = nil
end

local function reset_dirty_queue(queue)
    return ei_runtime_scheduler.clear_queue(queue)
end

local function now_tick(event_or_tick)
    return ei_lib.get_event_tick(event_or_tick) or (game and game.tick) or 0
end

local function make_gui_refresh_buckets()
    return ei_runtime_scheduler.ensure_delayed_buckets(nil)
end

local function get_relative_gui_root(player)
    if not (player and player.valid and player.gui and player.gui.relative) then
        return nil
    end

    return player.gui.relative[GUI_NAME]
end

local function get_screen_gui_root(player)
    if not (player and player.valid and player.gui and player.gui.screen) then
        return nil
    end

    return player.gui.screen[GUI_NAME]
end

local function get_gui_root(player)
    return get_relative_gui_root(player) or get_screen_gui_root(player)
end

local function destroy_gui_root(player)
    local relative_root = get_relative_gui_root(player)
    if relative_root then
        relative_root.destroy()
    end

    local screen_root = get_screen_gui_root(player)
    if screen_root then
        screen_root.destroy()
    end
end

local function format_distance(distance)
    if distance == nil then
        return nil
    end

    return string.format("%.1f", math.max(0, distance))
end

local function format_seconds(seconds)
    if seconds == nil then
        return nil
    end

    return string.format("%.1f", seconds)
end

local function clone_candidate(candidate)
    if type(candidate) ~= "table" then
        return nil
    end

    return {
        unit_number = candidate.unit_number,
        source_name = candidate.source_name,
        distance = candidate.distance,
        efficiency = candidate.efficiency,
        active = candidate.active,
    }
end

local function source_sort_key(left, right)
    if (left.efficiency or 0) ~= (right.efficiency or 0) then
        return (left.efficiency or 0) > (right.efficiency or 0)
    end

    if (left.distance or math.huge) ~= (right.distance or math.huge) then
        return (left.distance or math.huge) < (right.distance or math.huge)
    end

    return tostring(left.source_name or "") < tostring(right.source_name or "")
end

local function make_signature(snapshot)
    local parts = {
        tostring(snapshot.collector_state_key or ""),
        tostring(snapshot.block_reason_key or ""),
        tostring(snapshot.efficiency or 0),
        tostring(snapshot.source_name or ""),
        tostring(snapshot.source_agent_key or ""),
        tostring(snapshot.scan_agent_key or ""),
        tostring(snapshot.charge_time_seconds or ""),
        tostring(snapshot.source_distance or ""),
    }

    for _, candidate in ipairs(snapshot.candidates or {}) do
        parts[#parts + 1] = table.concat({
            tostring(candidate.source_name or ""),
            tostring(candidate.active and 1 or 0),
            tostring(candidate.efficiency or 0),
            format_distance(candidate.distance) or "",
        }, ":")
    end

    return table.concat(parts, "|")
end

local function get_runtime_source_state(source_entry)
    if not source_entry then
        return false
    end

    local entity = ei_lib.get_valid_entity(source_entry.entity)
    if not entity then
        return false
    end

    if source_entry.last_active_state == nil then
        source_entry.last_active_state = model.get_state(entity)
    end

    return source_entry.last_active_state == true
end

local function connector_targets_match(source, target)
    if not source or not source.valid or not target or not target.valid then
        return false
    end

    for _, connection in ipairs(source.real_connections) do
        local target_connection = connection.target
        if target_connection
        and target_connection.valid
        and target_connection.owner == target.owner
        and target_connection.wire_connector_id == target.wire_connector_id then
            return true
        end
    end

    return false
end

local function ensure_internal_wire(source_entity, source_id, target_entity, target_id)
    local source = source_entity.get_wire_connector(source_id, true)
    local target = target_entity.get_wire_connector(target_id, true)

    if not source or not source.valid or not target or not target.valid then
        return false
    end

    if connector_targets_match(source, target) then
        return true
    end

    local ok, connected = pcall(
        source.connect_to,
        target,
        false,
        defines.wire_origin.script
    )

    if not ok then
        return false
    end

    if connected then
        return true
    end

    return connector_targets_match(source, target)
end

local function resolve_wire_connector_id(entity, preferred_ids)
    if not model.entity_check(entity) then
        return nil
    end

    local ok, connectors = pcall(entity.get_wire_connectors, true)
    if not ok or type(connectors) ~= "table" then
        return nil
    end

    for _, connector_id in ipairs(preferred_ids) do
        local connector = connectors[connector_id]
        if connector and connector.valid then
            return connector_id
        end
    end

    return nil
end

local function get_neutron_wire_proxy_position(collector)
    return {
        x = collector.position.x,
        y = collector.position.y,
    }
end

--UTIL
------------------------------------------------------------------------------------------------------

function model.calc_distance(entity, source)
    local dist = math.sqrt((entity.position.x - source.position.x) ^ 2 + (entity.position.y - source.position.y) ^ 2)
    local buff = model.dist_buffs[source.name] or 0
    return dist - buff
end


function model.calc_fusion_flux(fuel1, fuel2, temp_mode, fuel_mode)
    if fuel1 == nil or fuel2 == nil then
        return 0
    end

    local fuel1_multiplier = ei_data.fusion.fuel_neutron_flux[fuel1]
    local fuel2_multiplier = ei_data.fusion.fuel_neutron_flux[fuel2]

    if fuel1_multiplier == nil or fuel2_multiplier == nil then
        return 0
    end

    local temp_multiplier = ei_data.fusion.temp_neutron_flux[temp_mode]
    local fuel_multiplier = ei_data.fusion.injection_neutron_flux[fuel_mode]

    if temp_multiplier == nil or fuel_multiplier == nil then
        return 0
    end

    return fuel1_multiplier * fuel2_multiplier * temp_multiplier * fuel_multiplier
end


function model.entity_check(entity)
    return ei_lib.entity_check(entity)
end


function model.get_entity_recipe_name(entity)
    if not model.entity_check(entity) or not entity.get_recipe then
        return nil
    end

    local recipe = entity.get_recipe()
    return recipe and recipe.name or nil
end


function model.clear_legacy_runtime_fields()
    if not storage or not storage.ei then
        return
    end

    -- Legacy source bookkeeping was hash-walked every pass. The new runtime rebuilds
    -- its dense queues lazily and clears the old tables once migration is complete.
    storage.ei["neutron_sources"] = nil
    storage.ei["neutron_script_break_point"] = nil
end


function model.check_global()
    storage.ei = storage.ei or {}
    storage.ei["neutron_collector_animation"] = storage.ei["neutron_collector_animation"] or {}

    local runtime = storage.ei.neutron_runtime
    local needs_rebuild = false

    if type(runtime) ~= "table" then
        runtime = {}
        storage.ei.neutron_runtime = runtime
        needs_rebuild = true
    end

    -- The neutron runtime keeps two hot paths dense:
    -- 1. dirty collectors waiting for a full nearest-source recompute
    -- 2. connected sources that still need low-lag active/inactive polling
    local function ensure_component(name, default, mark_rebuild)
        if runtime[name] == nil then
            runtime[name] = default
            if mark_rebuild ~= false then
                needs_rebuild = true
            end
        end
    end

    ensure_component("sources_by_unit", {})
    ensure_component("collectors_by_unit", {})
    ensure_component("connected_source_units", {})
    ensure_component("connected_source_index_by_unit", {})
    ensure_component("connected_source_count", 0)
    ensure_component("dirty_collector_queue", make_dirty_queue())
    ensure_component("dirty_collector_count", 0)
    ensure_component("poll_cursor", 1)
    ensure_component("prefer_poll_next", false)
    ensure_component("runtime_version", NEUTRON_RUNTIME_VERSION)
    ensure_component("needs_rebuild", false)
    ensure_component("runtime_rebuild_in_progress", false)
    ensure_component("open_by_player", {}, false)
    ensure_component("watchers_by_unit", {}, false)
    ensure_component("gui_refresh_buckets", make_gui_refresh_buckets(), false)
    ensure_component("last_gui_service_tick", 0, false)
    ensure_component("wire_output_buckets", make_wire_output_buckets(), false)
    ensure_component("wire_output_index_by_unit", {}, false)

    runtime.open_by_player = type(runtime.open_by_player) == "table" and runtime.open_by_player or {}
    runtime.watchers_by_unit = type(runtime.watchers_by_unit) == "table" and runtime.watchers_by_unit or {}
    runtime.gui_refresh_buckets = ei_runtime_scheduler.ensure_delayed_buckets(runtime.gui_refresh_buckets)
    runtime.last_gui_service_tick = tonumber(runtime.last_gui_service_tick) or 0
    runtime.wire_output_buckets = type(runtime.wire_output_buckets) == "table" and runtime.wire_output_buckets or make_wire_output_buckets()
    runtime.wire_output_index_by_unit = type(runtime.wire_output_index_by_unit) == "table" and runtime.wire_output_index_by_unit or {}

    if runtime.runtime_version ~= NEUTRON_RUNTIME_VERSION then
        needs_rebuild = true
    end

    if needs_rebuild then
        runtime.needs_rebuild = true
    end

    return runtime
end


function model.reset_runtime_storage(runtime)
    local preserved_sessions = type(runtime.open_by_player) == "table" and runtime.open_by_player or {}

    runtime.sources_by_unit = {}
    runtime.collectors_by_unit = {}
    runtime.connected_source_units = {}
    runtime.connected_source_index_by_unit = {}
    runtime.connected_source_count = 0
    runtime.dirty_collector_queue = make_dirty_queue()
    runtime.dirty_collector_count = 0
    runtime.poll_cursor = 1
    runtime.prefer_poll_next = false
    runtime.runtime_version = NEUTRON_RUNTIME_VERSION
    runtime.needs_rebuild = false
    runtime.open_by_player = {}
    runtime.watchers_by_unit = {}
    runtime.gui_refresh_buckets = make_gui_refresh_buckets()
    runtime.last_gui_service_tick = 0
    runtime.wire_output_buckets = make_wire_output_buckets()
    runtime.wire_output_index_by_unit = {}

    for player_index, session in pairs(preserved_sessions) do
        if type(session) == "table" and session.unit_number ~= nil then
            session.last_signature = nil
            session.pending_tick = nil
            runtime.open_by_player[player_index] = session
            runtime.watchers_by_unit[session.unit_number] = runtime.watchers_by_unit[session.unit_number] or {}
            runtime.watchers_by_unit[session.unit_number][player_index] = true
        end
    end

    model.clear_legacy_runtime_fields()
end


function model.ensure_runtime_ready()
    local runtime = model.check_global()
    if runtime.runtime_rebuild_in_progress then
        return runtime
    end

    if runtime.needs_rebuild then
        model.rebuild_runtime_state("auto")
        runtime = storage.ei and storage.ei.neutron_runtime or runtime
    end

    return runtime
end


function model.get_dirty_queue(runtime)
    local queue = runtime.dirty_collector_queue
    if not queue then
        queue = make_dirty_queue()
        runtime.dirty_collector_queue = queue
    end

    queue = ei_runtime_scheduler.ensure_queue(queue)
    runtime.dirty_collector_queue = queue
    return queue
end


function model.get_open_neutron_collector(player)
    local entity = ei_lib.get_valid_entity(player and player.opened)
    if entity and entity.name == NEUTRON_COLLECTOR_NAME then
        return entity
    end

    local runtime = storage and storage.ei and storage.ei.neutron_runtime or nil
    local session = runtime and runtime.open_by_player and player and runtime.open_by_player[player.index] or nil
    local collector_entry = session and session.unit_number and runtime.collectors_by_unit[session.unit_number] or nil
    local session_entity = collector_entry and ei_lib.get_valid_entity(collector_entry.entity) or nil
    if session_entity and session_entity.name == NEUTRON_COLLECTOR_NAME then
        return session_entity
    end

    return nil
end


function model.clear_gui_session(runtime, player_index, destroy_gui)
    local session = runtime.open_by_player[player_index]
    if session then
        local watchers = runtime.watchers_by_unit[session.unit_number]
        if watchers then
            watchers[player_index] = nil
            if next(watchers) == nil then
                runtime.watchers_by_unit[session.unit_number] = nil
            end
        end

        runtime.open_by_player[player_index] = nil
    end

    if destroy_gui and game then
        local player = game.get_player(player_index)
        if player then
            destroy_gui_root(player)
        end
    end
end


function model.close_sessions_for_unit(runtime, unit_number, destroy_gui)
    local watchers = runtime.watchers_by_unit[unit_number]
    if not watchers then
        return
    end

    local player_indices = {}
    for player_index, _ in pairs(watchers) do
        player_indices[#player_indices + 1] = player_index
    end

    for _, player_index in ipairs(player_indices) do
        model.clear_gui_session(runtime, player_index, destroy_gui)
    end
end


function model.ensure_gui_session(runtime, player_index, unit_number)
    local session = runtime.open_by_player[player_index]
    if session and session.unit_number ~= unit_number then
        model.clear_gui_session(runtime, player_index, false)
        session = nil
    end

    if not session then
        session = {
            unit_number = unit_number,
            last_signature = nil,
            pending_tick = nil,
        }
        runtime.open_by_player[player_index] = session
    else
        session.unit_number = unit_number
        session.last_signature = nil
        session.pending_tick = nil
    end

    local watchers = runtime.watchers_by_unit[unit_number]
    if not watchers then
        watchers = {}
        runtime.watchers_by_unit[unit_number] = watchers
    end
    watchers[player_index] = true

    return session
end


function model.queue_gui_refresh_for_player(runtime, player_index, refresh_tick)
    local session = runtime.open_by_player[player_index]
    if not session then
        return
    end

    refresh_tick = now_tick(refresh_tick)
    if session.pending_tick and session.pending_tick <= refresh_tick then
        return
    end

    session.pending_tick = refresh_tick
    ei_runtime_scheduler.delayed_schedule(runtime.gui_refresh_buckets, refresh_tick, player_index)
end


function model.queue_gui_refresh_for_unit(unit_number, refresh_tick)
    local runtime = model.check_global()
    local watchers = runtime.watchers_by_unit[unit_number]
    if not watchers then
        return
    end

    for player_index, _ in pairs(watchers) do
        model.queue_gui_refresh_for_player(runtime, player_index, refresh_tick)
    end
end


function model.get_due_gui_refresh_count(runtime, event_or_tick)
    if next(runtime.open_by_player) == nil then
        return 0
    end

    local tick = now_tick(event_or_tick)
    local due_players = {}
    for bucket_tick, bucket in pairs(runtime.gui_refresh_buckets) do
        if bucket_tick <= tick then
            for _, player_index in pairs(bucket) do
                due_players[player_index] = true
            end
        end
    end

    return ei_runtime_scheduler.table_count(due_players)
end


local function get_due_wire_output_count(runtime, event_or_tick)
    local buckets = runtime and runtime.wire_output_buckets or nil
    if type(buckets) ~= "table" then
        return 0
    end

    local tick = now_tick(event_or_tick)
    local bucket = buckets[tick % NEUTRON_WIRE_UPDATE_INTERVAL]
    if type(bucket) ~= "table" then
        return 0
    end

    return #bucket
end


function model.add_connected_source(runtime, source_unit)
    if runtime.connected_source_index_by_unit[source_unit] then
        return
    end

    local new_index = (runtime.connected_source_count or 0) + 1
    runtime.connected_source_units[new_index] = source_unit
    runtime.connected_source_index_by_unit[source_unit] = new_index
    runtime.connected_source_count = new_index
end


function model.remove_connected_source(runtime, source_unit)
    local remove_index = runtime.connected_source_index_by_unit[source_unit]
    if not remove_index then
        return
    end

    local last_index = runtime.connected_source_count or 0
    local last_unit = runtime.connected_source_units[last_index]

    runtime.connected_source_units[remove_index] = last_unit
    runtime.connected_source_units[last_index] = nil
    runtime.connected_source_index_by_unit[source_unit] = nil

    if last_unit ~= nil and last_unit ~= source_unit then
        runtime.connected_source_index_by_unit[last_unit] = remove_index
    end

    runtime.connected_source_count = math.max(0, last_index - 1)

    if runtime.connected_source_count == 0 then
        runtime.poll_cursor = 1
    elseif runtime.poll_cursor > runtime.connected_source_count then
        runtime.poll_cursor = 1
    end
end


function model.get_source_entry(runtime, source)
    local unit_number = get_entity_unit_number(source)
    if not unit_number then
        return nil
    end

    local entry = runtime.sources_by_unit[unit_number]
    if entry and model.entity_check(source) then
        entry.entity = source
    end

    return entry
end


function model.get_or_create_source_entry(runtime, source)
    if not model.entity_check(source) then
        return nil
    end

    local unit_number = get_entity_unit_number(source)
    if model.neutron_sources[source.name] == nil or not unit_number then
        return nil
    end

    local entry = runtime.sources_by_unit[unit_number]
    if not entry then
        entry = {
            unit_number = unit_number,
            entity = source,
            collectors = {},
            collector_count = 0,
            last_active_state = nil,
            last_recipe_name = nil,
            fusion_multiplier = nil,
        }
        runtime.sources_by_unit[unit_number] = entry
    else
        entry.entity = source
    end

    return entry
end


function model.destroy_wire_proxy(collector_entry)
    if not collector_entry then
        return
    end

    local proxy = collector_entry.wire_proxy
    if model.entity_check(proxy) then
        proxy.destroy({raise_destroy = false})
    end

    collector_entry.wire_proxy = nil
    collector_entry.wire_proxy_connected = nil
    collector_entry.signal_cache = nil
end


function model.attach_wire_proxy_to_collector(collector_entry)
    if not collector_entry then
        return false
    end

    if not NEUTRON_WIRE_PROXY_ENABLED then
        model.destroy_wire_proxy(collector_entry)
        return false
    end

    local proxy = collector_entry.wire_proxy
    local collector = collector_entry.entity
    if model.entity_check(proxy) == false or model.entity_check(collector) == false then
        return false
    end

    local collector_red_id = resolve_wire_connector_id(collector, {
        defines.wire_connector_id.circuit_red,
        defines.wire_connector_id.combinator_output_red,
        defines.wire_connector_id.combinator_input_red,
    })
    local collector_green_id = resolve_wire_connector_id(collector, {
        defines.wire_connector_id.circuit_green,
        defines.wire_connector_id.combinator_output_green,
        defines.wire_connector_id.combinator_input_green,
    })
    local proxy_red_id = resolve_wire_connector_id(proxy, {
        defines.wire_connector_id.combinator_output_red,
        defines.wire_connector_id.circuit_red,
        defines.wire_connector_id.combinator_input_red,
    })
    local proxy_green_id = resolve_wire_connector_id(proxy, {
        defines.wire_connector_id.combinator_output_green,
        defines.wire_connector_id.circuit_green,
        defines.wire_connector_id.combinator_input_green,
    })

    if (not collector_red_id and not collector_green_id) or (not proxy_red_id and not proxy_green_id) then
        collector_entry.wire_proxy_connected = false
        return false
    end

    local connected = false
    if collector_red_id and proxy_red_id then
        connected = ensure_internal_wire(
            collector,
            collector_red_id,
            proxy,
            proxy_red_id
        ) or connected
    end

    if collector_green_id and proxy_green_id then
        connected = ensure_internal_wire(
            collector,
            collector_green_id,
            proxy,
            proxy_green_id
        ) or connected
    end

    collector_entry.wire_proxy_connected = connected
    if connected == false then
        collector_entry.signal_cache = nil
    end
    return connected
end


function model.ensure_wire_proxy(collector_entry)
    if not collector_entry then
        return nil
    end

    if not NEUTRON_WIRE_PROXY_ENABLED then
        model.destroy_wire_proxy(collector_entry)
        return nil
    end

    local collector = collector_entry.entity
    if not model.entity_check(collector) then
        return nil
    end

    local expected_position = get_neutron_wire_proxy_position(collector)
    local proxy = collector_entry.wire_proxy
    if model.entity_check(proxy) then
        if math.abs(proxy.position.x - expected_position.x) > 0.01
        or math.abs(proxy.position.y - expected_position.y) > 0.01 then
            pcall(proxy.teleport, expected_position)
        end
        if collector_entry.wire_proxy_connected ~= true then
            model.attach_wire_proxy_to_collector(collector_entry)
        end
        return proxy
    end

    local ok, created_proxy = pcall(
        collector.surface.create_entity,
        {
            name = NEUTRON_WIRE_PROXY_NAME,
            position = expected_position,
            force = collector.force,
            create_build_effect_smoke = false,
            raise_built = false,
        }
    )
    proxy = ok and created_proxy or nil

    if model.entity_check(proxy) == false then
        return nil
    end

    collector_entry.wire_proxy = proxy
    collector_entry.wire_proxy_connected = nil
    collector_entry.signal_cache = nil
    model.attach_wire_proxy_to_collector(collector_entry)
    return proxy
end


function model.register_collector(runtime, entity)
    local unit_number = get_entity_unit_number(entity)
    if not model.entity_check(entity) or entity.name ~= NEUTRON_COLLECTOR_NAME or not unit_number then
        return nil
    end

    local entry = runtime.collectors_by_unit[unit_number]
    if not entry then
        entry = {
            unit_number = unit_number,
            entity = entity,
            source_unit = nil,
            queued = false,
            exclude_source_unit = nil,
            last_recipe_name = nil,
            last_direction = nil,
            last_efficiency = 0,
            last_candidates = {},
            last_source_distance = nil,
            last_had_source = nil,
            wire_proxy = nil,
            wire_proxy_connected = nil,
            signal_cache = nil,
        }
        runtime.collectors_by_unit[unit_number] = entry
    else
        entry.entity = entity
        entry.last_candidates = type(entry.last_candidates) == "table" and entry.last_candidates or {}
        entry.signal_cache = type(entry.signal_cache) == "table" and entry.signal_cache or nil
    end

    model.ensure_wire_proxy(entry)
    add_wire_output_bucket(runtime, unit_number)
    model.update_wire_proxy_signals(runtime, entry)

    return entry
end


function model.queue_dirty_collector(runtime, collector_entry, exclude_source_unit)
    if not collector_entry or not collector_entry.unit_number then
        return false
    end

    if exclude_source_unit ~= nil then
        collector_entry.exclude_source_unit = exclude_source_unit
    end

    if collector_entry.queued then
        return false
    end

    local queue = model.get_dirty_queue(runtime)
    ei_runtime_scheduler.queue_push(queue, collector_entry.unit_number)
    collector_entry.queued = true
    runtime.dirty_collector_count = (runtime.dirty_collector_count or 0) + 1
    model.update_wire_proxy_signals(runtime, collector_entry)
    model.queue_gui_refresh_for_unit(collector_entry.unit_number, now_tick() + GUI_REFRESH_DELAY)

    return true
end


function model.clear_queued_collector(runtime, collector_entry)
    if not (collector_entry and collector_entry.queued) then
        return
    end

    collector_entry.queued = false
    runtime.dirty_collector_count = math.max(0, (runtime.dirty_collector_count or 0) - 1)
    ei_runtime_scheduler.queue_remove_value(model.get_dirty_queue(runtime), collector_entry.unit_number)
end


function model.dequeue_dirty_collector(runtime)
    local queue = model.get_dirty_queue(runtime)

    local unit_number = ei_runtime_scheduler.queue_pop_matching(queue, function(candidate_unit_number)
        local collector_entry = runtime.collectors_by_unit[candidate_unit_number]
        return collector_entry and collector_entry.queued == true
    end)

    if unit_number then
        local collector_entry = runtime.collectors_by_unit[unit_number]
        collector_entry.queued = false
        runtime.dirty_collector_count = math.max(0, (runtime.dirty_collector_count or 0) - 1)
        return collector_entry
    end

    reset_dirty_queue(queue)
    return nil
end


function model.remove_direction_animation_by_unit(unit_number)
    if not storage.ei["neutron_collector_animation"] then
        storage.ei["neutron_collector_animation"] = {}
    end

    local animation = storage.ei["neutron_collector_animation"][unit_number]
    if animation then
        animation.destroy()
        storage.ei["neutron_collector_animation"][unit_number] = nil
    end
end


function model.remove_collector_from_source(runtime, source_entry, collector_unit, clear_source_unit)
    if not source_entry or not source_entry.collectors[collector_unit] then
        return
    end

    source_entry.collectors[collector_unit] = nil
    source_entry.collector_count = math.max(0, (source_entry.collector_count or 0) - 1)

    local collector_entry = runtime.collectors_by_unit[collector_unit]
    if clear_source_unit and collector_entry and collector_entry.source_unit == source_entry.unit_number then
        collector_entry.source_unit = nil
    end

    if source_entry.collector_count <= 0 then
        model.remove_connected_source(runtime, source_entry.unit_number)
        runtime.sources_by_unit[source_entry.unit_number] = nil
    end
end


function model.disconnect_collector(runtime, collector_entry)
    if not collector_entry or not collector_entry.source_unit then
        return
    end

    local source_unit = collector_entry.source_unit
    collector_entry.source_unit = nil

    local source_entry = runtime.sources_by_unit[source_unit]
    if not source_entry then
        return
    end

    model.remove_collector_from_source(runtime, source_entry, collector_entry.unit_number, false)
end


function model.connect_collector(runtime, collector_entry, source)
    local source_entry = model.get_or_create_source_entry(runtime, source)
    if not source_entry then
        model.disconnect_collector(runtime, collector_entry)
        return nil
    end

    if collector_entry.source_unit ~= source_entry.unit_number then
        model.disconnect_collector(runtime, collector_entry)
        collector_entry.source_unit = source_entry.unit_number
    end

    if not source_entry.collectors[collector_entry.unit_number] then
        source_entry.collectors[collector_entry.unit_number] = true
        source_entry.collector_count = (source_entry.collector_count or 0) + 1
    end

    model.add_connected_source(runtime, source_entry.unit_number)

    return source_entry
end


function model.unregister_collector(runtime, collector)
    local unit_number = get_entity_unit_number(collector)
    local collector_entry = unit_number and runtime.collectors_by_unit[unit_number] or nil

    if not collector_entry and type(collector) == "table" and collector.entity ~= nil then
        collector_entry = collector
        unit_number = collector.unit_number
    end

    if not unit_number then
        return
    end

    model.close_sessions_for_unit(runtime, unit_number, true)

    if collector_entry then
        model.clear_queued_collector(runtime, collector_entry)
        model.disconnect_collector(runtime, collector_entry)
        model.destroy_wire_proxy(collector_entry)
        remove_wire_output_bucket(runtime, unit_number)
        runtime.collectors_by_unit[unit_number] = nil
    end

    model.remove_direction_animation_by_unit(unit_number)
end


function model.remove_source_entry(runtime, source_unit, queue_collectors)
    local source_entry = runtime.sources_by_unit[source_unit]
    if not source_entry then
        return
    end

    for collector_unit in pairs(source_entry.collectors) do
        local collector_entry = runtime.collectors_by_unit[collector_unit]
        if collector_entry and collector_entry.source_unit == source_unit then
            collector_entry.source_unit = nil
            if queue_collectors and model.entity_check(collector_entry.entity) then
                model.queue_dirty_collector(runtime, collector_entry)
            end
        end
    end

    model.remove_connected_source(runtime, source_unit)
    runtime.sources_by_unit[source_unit] = nil
end


function model.parse_fusion_multiplier(recipe_name)
    recipe_name = recipe_name or DEFAULT_FUSION_RECIPE

    local fuel1 = recipe_name:match("F1__(.+)%-F2__")
    local fuel2 = recipe_name:match("F2__(.+)%-TM__")
    local temp_mode = recipe_name:match("TM__(.+)%-FM__")
    local fuel_mode = recipe_name:match("FM__(.+)")

    return 2 * model.calc_fusion_flux(fuel1, fuel2, temp_mode, fuel_mode)
end


function model.get_source_fusion_multiplier(source_entry)
    local recipe_name = model.get_entity_recipe_name(source_entry.entity) or DEFAULT_FUSION_RECIPE
    if source_entry.last_recipe_name ~= recipe_name then
        source_entry.last_recipe_name = recipe_name
        source_entry.fusion_multiplier = model.parse_fusion_multiplier(recipe_name)
    end

    return source_entry.fusion_multiplier or 0
end


function model.find_neutron_source(runtime, entity, exclude)
    local exclude_unit = type(exclude) == "number" and exclude or get_entity_unit_number(exclude)
    local entities = entity.surface.find_entities_filtered{
        name = model.neutron_source_names,
        position = entity.position,
        radius = model.range,
    }

    if #entities == 0 then
        return {
            source = nil,
            eff = 0,
            had_source = false,
            distance = nil,
            candidates = {},
        }
    end

    local had_source = false
    local evaluated_candidates = {}

    for _, source in ipairs(entities) do
        if model.entity_check(source) and model.neutron_sources[source.name] ~= nil then
            local source_unit = get_entity_unit_number(source)
            if exclude_unit ~= nil and source_unit == exclude_unit then
                goto continue
            end

            had_source = true

            local source_entry = source_unit and runtime.sources_by_unit[source_unit] or nil
            local distance = model.calc_distance(entity, source)
            local efficiency = model.calc_efficiency(entity, source, source_entry)
            local active = source_entry and get_runtime_source_state(source_entry) or model.get_state(source)

            evaluated_candidates[#evaluated_candidates + 1] = {
                entity = source,
                unit_number = source_unit,
                source_name = source.name,
                distance = distance,
                efficiency = efficiency,
                active = active,
            }
        end

        ::continue::
    end

    table.sort(evaluated_candidates, source_sort_key)

    local best_candidate = evaluated_candidates[1]
    local candidates = {}
    for index = 1, math.min(MAX_GUI_CANDIDATES, #evaluated_candidates) do
        candidates[index] = clone_candidate(evaluated_candidates[index])
    end

    return {
        source = best_candidate and best_candidate.entity or nil,
        eff = best_candidate and (best_candidate.efficiency or 0) or 0,
        had_source = had_source,
        distance = best_candidate and best_candidate.distance or nil,
        candidates = candidates,
    }
end


function model.show_resolution_text(entity, result)
    if not result.had_source then
        rendering.draw_text{
            target = entity,
            text = "No nearby neutron source",
            color = {r = 1, g = 0.77, b = 0},
            surface = entity.surface,
            scale = 1,
            time_to_live = 15,
        }
        return
    end

    if result.eff > 0 then
        rendering.draw_text{
            text = "Efficiency: " .. result.eff .. "%",
            surface = entity.surface,
            target = entity,
            color = {r = 0.48, g = 0.77, b = 0.37},
            scale = 0.75,
            time_to_live = 120,
            alignment = "center",
            scale_with_zoom = false,
        }
        return
    end

    rendering.draw_text{
        target = entity,
        text = "Insufficient neutron flux",
        color = {r = 1, g = 0.77, b = 0},
        surface = entity.surface,
        scale = 1,
        time_to_live = 15,
    }
end


function model.apply_collector_animation(collector_entry, direction_count)
    if direction_count == nil then
        if collector_entry.last_direction ~= nil
            or (storage.ei["neutron_collector_animation"] and storage.ei["neutron_collector_animation"][collector_entry.unit_number]) then
            model.remove_direction_animation_by_unit(collector_entry.unit_number)
        end

        collector_entry.last_direction = nil
        return
    end

    if collector_entry.last_direction ~= direction_count then
        model.make_direction_animation(collector_entry.entity, direction_count)
        collector_entry.last_direction = direction_count
    end
end


function model.refresh_collector(runtime, collector_entry, show_feedback, exclude)
    local entity = collector_entry and collector_entry.entity or nil
    if not model.entity_check(entity) then
        model.unregister_collector(runtime, collector_entry)
        return false
    end

    -- Dirty refresh is the expensive path: resolve the best source, migrate the binding,
    -- and only touch recipe/animation state when the resolved output actually changed.
    local effective_exclude = collector_entry.exclude_source_unit or exclude
    collector_entry.exclude_source_unit = nil

    local result = model.find_neutron_source(runtime, entity, effective_exclude)
    local source_entry = nil
    local source_state = false

    if result.source and result.eff > 0 then
        source_entry = model.connect_collector(runtime, collector_entry, result.source)
        if source_entry and model.entity_check(source_entry.entity) then
            source_state = model.get_state(source_entry.entity)
            source_entry.last_active_state = source_state
        end
    else
        model.disconnect_collector(runtime, collector_entry)
    end

    local desired_recipe_name = nil
    local applied_recipe_name = NEUTRON_IDLE_RECIPE_NAME
    local desired_direction = nil
    local desired_active = false

    if result.source and result.eff > 0 and not entity.disabled_by_control_behavior then
        desired_recipe_name = "ei-charged-neutron-container-" .. result.eff
        applied_recipe_name = desired_recipe_name
        desired_direction = model.get_looking_direction(entity, result.source)
        desired_active = source_state
    end

    local current_recipe_name = model.get_entity_recipe_name(entity)
    if current_recipe_name ~= applied_recipe_name then
        entity.set_recipe(applied_recipe_name)
    end
    entity.recipe_locked = true

    model.apply_collector_animation(collector_entry, desired_direction)
    entity.active = desired_active

    collector_entry.last_recipe_name = desired_recipe_name
    collector_entry.last_efficiency = result.eff or 0
    collector_entry.last_candidates = result.candidates or {}
    collector_entry.last_source_distance = source_entry and result.distance or nil
    collector_entry.last_had_source = result.had_source == true

    if desired_recipe_name then
        ei_victory.count_value("neutron_collector_efficiency", result.eff)
    end

    model.update_wire_proxy_signals(runtime, collector_entry)

    if show_feedback then
        model.show_resolution_text(entity, result)
    end

    model.queue_gui_refresh_for_unit(collector_entry.unit_number, now_tick() + GUI_REFRESH_DELAY)
    return true
end


function model.process_dirty_collectors(runtime, budget)
    local processed = 0

    while processed < budget do
        local collector_entry = model.dequeue_dirty_collector(runtime)
        if not collector_entry then
            break
        end

        model.refresh_collector(runtime, collector_entry, false)
        processed = processed + 1
    end

    return processed
end


function model.service_wire_proxy_outputs(runtime, event_or_tick)
    runtime = runtime or model.ensure_runtime_ready()
    if not runtime or runtime.runtime_rebuild_in_progress then
        return 0
    end

    local tick = now_tick(event_or_tick)
    local bucket_index = tick % NEUTRON_WIRE_UPDATE_INTERVAL
    local bucket = runtime.wire_output_buckets and runtime.wire_output_buckets[bucket_index] or nil
    if type(bucket) ~= "table" or #bucket == 0 then
        return 0
    end

    local scheduled = {}
    for i = 1, #bucket do
        scheduled[i] = bucket[i]
    end

    local processed = 0
    for _, unit_number in ipairs(scheduled) do
        local collector_entry = runtime.collectors_by_unit[unit_number]
        if collector_entry and model.entity_check(collector_entry.entity) then
            model.update_wire_proxy_signals(runtime, collector_entry)
            processed = processed + 1
        else
            remove_wire_output_bucket(runtime, unit_number)
        end
    end

    return processed
end


function model.poll_source(runtime, source_unit)
    local source_entry = runtime.sources_by_unit[source_unit]
    if not source_entry then
        model.remove_connected_source(runtime, source_unit)
        return false
    end

    local source = source_entry.entity
    if not model.entity_check(source) then
        model.remove_source_entry(runtime, source_unit, true)
        return true
    end

    -- Steady-state polling is intentionally narrow: prune stale collector links and only
    -- fan out active-state writes when the source actually changed state.
    local source_state = model.get_state(source)
    local state_changed = source_entry.last_active_state == nil or source_entry.last_active_state ~= source_state
    source_entry.last_active_state = source_state

    for collector_unit in pairs(source_entry.collectors) do
        local collector_entry = runtime.collectors_by_unit[collector_unit]

        if not collector_entry then
            model.remove_collector_from_source(runtime, source_entry, collector_unit, false)
        elseif collector_entry.source_unit ~= source_unit then
            model.remove_collector_from_source(runtime, source_entry, collector_unit, false)
        elseif not model.entity_check(collector_entry.entity) then
            model.clear_queued_collector(runtime, collector_entry)
            model.destroy_wire_proxy(collector_entry)
            runtime.collectors_by_unit[collector_unit] = nil
            model.remove_direction_animation_by_unit(collector_unit)
            model.remove_collector_from_source(runtime, source_entry, collector_unit, false)
            model.close_sessions_for_unit(runtime, collector_unit, true)
        elseif state_changed then
            collector_entry.entity.active = source_state
                and not collector_entry.entity.disabled_by_control_behavior
                and collector_entry.last_recipe_name ~= nil

            for _, candidate in ipairs(collector_entry.last_candidates or {}) do
                if candidate.unit_number == source_unit then
                    candidate.active = source_state
                end
            end

            model.update_wire_proxy_signals(runtime, collector_entry)
            model.queue_gui_refresh_for_unit(collector_unit, now_tick() + GUI_REFRESH_DELAY)
        end
    end

    if runtime.sources_by_unit[source_unit] == nil then
        return true
    end

    return true
end


function model.poll_connected_sources(runtime, budget)
    local processed = 0

    while processed < budget and (runtime.connected_source_count or 0) > 0 do
        if runtime.poll_cursor > runtime.connected_source_count then
            runtime.poll_cursor = 1
        end

        local source_unit = runtime.connected_source_units[runtime.poll_cursor]
        runtime.poll_cursor = runtime.poll_cursor + 1
        if runtime.poll_cursor > runtime.connected_source_count then
            runtime.poll_cursor = 1
        end

        if source_unit ~= nil then
            model.poll_source(runtime, source_unit)
            processed = processed + 1
        else
            break
        end
    end

    return processed
end


function model.queue_collectors_in_range(runtime, neutron_source, exclude)
    if model.entity_check(neutron_source) == false then
        return
    end

    local exclude_source_unit = type(exclude) == "number" and exclude or get_entity_unit_number(exclude)
    local entities = neutron_source.surface.find_entities_filtered{
        name = NEUTRON_COLLECTOR_NAME,
        position = neutron_source.position,
        radius = model.range,
    }

    for _, entity in ipairs(entities) do
        local collector_entry = model.register_collector(runtime, entity)
        if collector_entry then
            model.queue_dirty_collector(runtime, collector_entry, exclude_source_unit)
        end
    end
end


function model.destroy_all_wire_proxies()
    if not game then
        return
    end

    for _, surface in pairs(game.surfaces) do
        local proxies = surface.find_entities_filtered{name = NEUTRON_WIRE_PROXY_NAME}
        for _, proxy in ipairs(proxies) do
            if model.entity_check(proxy) then
                proxy.destroy({raise_destroy = false})
            end
        end
    end
end


function model.rebuild_runtime_state(reason)
    local runtime = model.check_global()
    if runtime.runtime_rebuild_in_progress then
        return
    end

    runtime.runtime_rebuild_in_progress = true
    model.destroy_all_wire_proxies()
    model.reset_runtime_storage(runtime)

    for _, surface in pairs(game.surfaces) do
        local collectors = surface.find_entities_filtered{
            name = NEUTRON_COLLECTOR_NAME,
        }

        for _, collector in ipairs(collectors) do
            if model.entity_check(collector) then
                local collector_entry = model.register_collector(runtime, collector)
                if collector_entry then
                    model.queue_dirty_collector(runtime, collector_entry)
                end
            end
        end
    end

    model.process_dirty_collectors(runtime, runtime.dirty_collector_count or 0)

    runtime.runtime_version = NEUTRON_RUNTIME_VERSION
    runtime.needs_rebuild = false
    runtime.runtime_rebuild_in_progress = false

    if reason == "init" then
        runtime.prefer_poll_next = false
    end

    for player_index, _ in pairs(runtime.open_by_player) do
        model.queue_gui_refresh_for_player(runtime, player_index, now_tick())
    end
end


function model.get_dirty_collector_count()
    local runtime = model.ensure_runtime_ready()
    return runtime and runtime.dirty_collector_count or 0
end


function model.get_connected_source_count()
    local runtime = model.ensure_runtime_ready()
    return runtime and runtime.connected_source_count or 0
end


function model.get_pending_work_count()
    local runtime = model.ensure_runtime_ready()
    if not runtime then
        return 0
    end

    return (runtime.dirty_collector_count or 0)
        + (runtime.connected_source_count or 0)
        + get_due_wire_output_count(runtime)
        + model.get_due_gui_refresh_count(runtime)
end


function model.update_neutron_collector(entity, exclude, show_feedback)
    local runtime = model.ensure_runtime_ready()
    if not runtime or runtime.runtime_rebuild_in_progress then
        return false
    end

    local collector_entry = model.register_collector(runtime, entity)
    if not collector_entry then
        return false
    end

    model.clear_queued_collector(runtime, collector_entry)
    return model.refresh_collector(runtime, collector_entry, show_feedback == true, exclude)
end


function model.update_neutron_collectors_in_range(neutron_source, exclude)
    local runtime = model.ensure_runtime_ready()
    if not runtime or runtime.runtime_rebuild_in_progress then
        return
    end

    model.queue_collectors_in_range(runtime, neutron_source, exclude)
end


function model.is_output_empty(entity)
    if entity.crafting_progress == 1 then
        local output_inventory = entity.get_output_inventory and entity.get_output_inventory() or nil
        if output_inventory and not output_inventory.is_empty() and output_inventory.is_full() then
            return false
        end

        -- same for potential fluidboxes
        -- TODO
    end

    return true
end


function model.get_state(entity)
    if model.entity_check(entity) == false then
        return false
    end

    if entity.type == "assembling-machine" then
        if model.is_output_empty(entity) == false then
            return false
        end

        return entity.is_crafting() and not entity.disabled_by_control_behavior
    end

    if entity.type == "furnace" then
        if model.is_output_empty(entity) == false then
            return false
        end

        return entity.is_crafting() and not entity.disabled_by_control_behavior
    end

    if entity.type == "reactor" and entity.burner and entity.burner.currently_burning then
        return true
    end

    if entity.type == "fusion-reactor" then
        return entity.status == defines.entity_status.working
    end

    return false
end

--MATH RELATED
------------------------------------------------------------------------------------------------------

function model.get_looking_direction(entity, target)
    -- get the direction from entity to target, snap to 64 directions
    -- 0 = north = 0dec, 16 = east = 45dec, 32 = south = 90dec, 48 = west = 270dec, 64 = north = 360dec

    if model.entity_check(entity) == false then
        return 0
    end

    if model.entity_check(target) == false then
        return 0
    end

    local dx = target.position.x - entity.position.x
    local dy = target.position.y - entity.position.y

    local phi = math.atan(dx / dy)

    if dx == 0 then
        if dy < 0 then
            return 0
        else
            return 32
        end
    end

    if dx < 0 and dy < 0 then
        phi = phi + math.pi
    elseif dx > 0 and dy < 0 then
        phi = phi + math.pi
    end

    phi = phi + math.pi

    local theta = 2 * math.pi - phi
    local angle = theta * 180 / math.pi
    local direction = math.floor(angle / 360 * 64)

    return direction % 64
end


function model.calc_efficiency(entity, source, source_entry)
    if not model.entity_check(entity) or not model.entity_check(source) then
        return 0
    end

    local dist = model.calc_distance(entity, source)
    if dist > model.range then
        return 0
    end

    local efficiency
    if dist < 1 then
        efficiency = 100
    else
        efficiency = 100 - (dist / model.range) * 90 + model.neutron_sources[source.name]
    end

    if efficiency < 0 then
        efficiency = 0
    elseif efficiency > 100 then
        efficiency = 100
    end

    if source.name == FUSION_REACTOR_NAME then
        local fusion_multiplier

        if source_entry then
            fusion_multiplier = model.get_source_fusion_multiplier(source_entry)
        else
            fusion_multiplier = model.parse_fusion_multiplier(model.get_entity_recipe_name(source) or DEFAULT_FUSION_RECIPE)
        end

        efficiency = efficiency * fusion_multiplier
    end

    efficiency = math.floor(efficiency / 10) * 10

    if efficiency < 0 then
        efficiency = 0
    elseif efficiency > 300 then
        efficiency = 300
    end

    return efficiency
end


function model.get_charge_time_seconds(efficiency)
    if not efficiency or efficiency < 10 then
        return nil
    end

    return 1000 / math.max(10, (efficiency + efficiency - 10))
end


function model.get_scan_agent_key(collector_entry)
    if collector_entry and collector_entry.queued then
        if collector_entry.source_unit ~= nil or collector_entry.last_recipe_name ~= nil then
            return "neutron-collector-gui-scan-rebind-pending"
        end

        return "neutron-collector-gui-scan-dirty"
    end

    return "neutron-collector-gui-scan-stable"
end


function model.get_collector_state_key(runtime, collector_entry, source_active, block_reason_key)
    block_reason_key = block_reason_key or model.get_block_reason_key(runtime, collector_entry)

    if block_reason_key == "neutron-collector-gui-block-disabled-by-circuit"
        or block_reason_key == "neutron-collector-gui-block-output-blocked" then
        return "neutron-collector-gui-state-blocked"
    end

    if collector_entry and collector_entry.last_recipe_name ~= nil and source_active then
        return "neutron-collector-gui-state-active"
    end

    return "neutron-collector-gui-state-idle"
end


function model.get_block_reason_key(runtime, collector_entry)
    local entity = collector_entry and ei_lib.get_valid_entity(collector_entry.entity) or nil
    if not entity then
        return "neutron-collector-gui-block-no-source"
    end

    if entity.disabled_by_control_behavior then
        return "neutron-collector-gui-block-disabled-by-circuit"
    end

    if collector_entry.last_recipe_name == nil then
        if collector_entry.last_had_source then
            return "neutron-collector-gui-block-insufficient-flux"
        end

        return "neutron-collector-gui-block-no-source"
    end

    if not model.is_output_empty(entity) then
        return "neutron-collector-gui-block-output-blocked"
    end

    local source_entry = collector_entry.source_unit and runtime.sources_by_unit[collector_entry.source_unit] or nil
    if not source_entry or not ei_lib.get_valid_entity(source_entry.entity) then
        return "neutron-collector-gui-block-no-source"
    end

    if not get_runtime_source_state(source_entry) then
        return "neutron-collector-gui-block-source-idle"
    end

    return nil
end


function model.get_gui_snapshot(runtime, collector_entry)
    local entity = collector_entry and ei_lib.get_valid_entity(collector_entry.entity) or nil
    if not entity then
        return nil
    end

    local source_entry = collector_entry.source_unit and runtime.sources_by_unit[collector_entry.source_unit] or nil
    local source_entity = source_entry and ei_lib.get_valid_entity(source_entry.entity) or nil
    local source_active = source_entity and get_runtime_source_state(source_entry) or false
    local block_reason_key = model.get_block_reason_key(runtime, collector_entry)
    local collector_state_key = model.get_collector_state_key(runtime, collector_entry, source_active, block_reason_key)

    local source_agent_key
    if source_entity then
        source_agent_key = source_active and "neutron-collector-gui-source-live" or "neutron-collector-gui-source-dormant"
    else
        source_agent_key = "neutron-collector-gui-source-absent"
    end

    local candidates = {}
    for _, candidate in ipairs(collector_entry.last_candidates or {}) do
        candidates[#candidates + 1] = clone_candidate(candidate)
    end

    local snapshot = {
        collector_state_key = collector_state_key,
        block_reason_key = block_reason_key,
        efficiency = collector_entry.last_efficiency or 0,
        source_name = source_entity and source_entity.name or nil,
        source_distance = collector_entry.last_source_distance,
        source_agent_key = source_agent_key,
        charge_time_seconds = model.get_charge_time_seconds(collector_entry.last_efficiency),
        collector_agent_key = collector_state_key,
        scan_agent_key = model.get_scan_agent_key(collector_entry),
        candidates = candidates,
    }

    snapshot.signature = make_signature(snapshot)
    return snapshot
end


local function build_wire_signal_cache(runtime, collector_entry)
    local source_entry = collector_entry.source_unit and runtime.sources_by_unit[collector_entry.source_unit] or nil
    local source_entity = source_entry and ei_lib.get_valid_entity(source_entry.entity) or nil
    local source_active = source_entity and get_runtime_source_state(source_entry) or false
    local block_reason_key = model.get_block_reason_key(runtime, collector_entry)
    local collector_state_key = model.get_collector_state_key(runtime, collector_entry, source_active, block_reason_key)
    local source_agent_key

    if source_entity then
        source_agent_key = source_active and "neutron-collector-gui-source-live" or "neutron-collector-gui-source-dormant"
    else
        source_agent_key = "neutron-collector-gui-source-absent"
    end

    local scan_agent_key = model.get_scan_agent_key(collector_entry)

    return {
        efficiency = math.max(0, math.floor((collector_entry.last_efficiency or 0) + 0.5)),
        distance = collector_entry.last_source_distance and math.max(0, math.floor((collector_entry.last_source_distance * 10) + 0.5)) or 0,
        collector_agent = COLLECTOR_AGENT_SIGNAL_VALUES[collector_state_key] or 0,
        source_agent = SOURCE_AGENT_SIGNAL_VALUES[source_agent_key] or 0,
        scan_agent = SCAN_AGENT_SIGNAL_VALUES[scan_agent_key] or 0,
    }
end

local function set_wire_signal_slot(section, slot_index, signal, value)
    local ok = pcall(section.set_slot, slot_index, {value = signal, min = value})
    if ok then
        return true
    end

    pcall(section.clear_slot, slot_index)
    return false
end

local function clear_wire_proxy_output(proxy)
    if model.entity_check(proxy) == false then
        return
    end

    local control = proxy.get_control_behavior()
    if not control or not control.valid then
        return
    end

    control.enabled = false

    local section = control.get_section(1)
    if not section then
        return
    end

    for i = 1, section.filters_count do
        section.clear_slot(i)
    end
end


function model.update_wire_proxy_signals(runtime, collector_entry)
    if not (runtime and collector_entry and collector_entry.unit_number) then
        return false
    end

    if not NEUTRON_WIRE_PROXY_ENABLED then
        model.destroy_wire_proxy(collector_entry)
        return false
    end

    if not model.entity_check(collector_entry.entity) then
        model.destroy_wire_proxy(collector_entry)
        return false
    end

    local proxy = model.ensure_wire_proxy(collector_entry)
    if model.entity_check(proxy) == false then
        return false
    end

    if collector_entry.wire_proxy_connected ~= true then
        clear_wire_proxy_output(proxy)
        collector_entry.signal_cache = nil
        return false
    end

    local values = build_wire_signal_cache(runtime, collector_entry)
    local cache = collector_entry.signal_cache
    if cache
    and cache.efficiency == values.efficiency
    and cache.distance == values.distance
    and cache.collector_agent == values.collector_agent
    and cache.source_agent == values.source_agent
    and cache.scan_agent == values.scan_agent then
        return false
    end

    local control = proxy.get_control_behavior()
    if not control or not control.valid then
        return false
    end

    control.enabled = true

    local section = control.get_section(1)
    if not section then
        section = control.add_section("neutron")
    end

    if not section then
        return false
    end

    section.active = true

    for i = 1, section.filters_count do
        section.clear_slot(i)
    end

    local wrote_all_slots = true
    wrote_all_slots = set_wire_signal_slot(section, 1, SIGNAL_NEUTRON_EFFICIENCY, values.efficiency) and wrote_all_slots
    wrote_all_slots = set_wire_signal_slot(section, 2, SIGNAL_NEUTRON_DISTANCE, values.distance) and wrote_all_slots
    wrote_all_slots = set_wire_signal_slot(section, 3, SIGNAL_NEUTRON_COLLECTOR_AGENT, values.collector_agent) and wrote_all_slots
    wrote_all_slots = set_wire_signal_slot(section, 4, SIGNAL_NEUTRON_SOURCE_AGENT, values.source_agent) and wrote_all_slots
    wrote_all_slots = set_wire_signal_slot(section, 5, SIGNAL_NEUTRON_SCAN_AGENT, values.scan_agent) and wrote_all_slots

    if not wrote_all_slots then
        collector_entry.signal_cache = nil
        return false
    end

    collector_entry.signal_cache = values
    return true
end

--GUI
------------------------------------------------------------------------------------------------------

function model.build_gui(player)
    destroy_gui_root(player)

    if not (player and player.valid and player.gui) then
        return nil
    end

    local root
    local detached = false

    if player.gui.relative then
        local ok, relative_root = pcall(function()
            return player.gui.relative.add{
                type = "frame",
                name = GUI_NAME,
                anchor = {
                    gui = defines.relative_gui_type.assembling_machine_gui,
                    name = NEUTRON_COLLECTOR_NAME,
                    position = defines.relative_gui_position.right,
                },
                direction = "vertical",
                tags = {
                    parent_gui = GUI_NAME,
                    gui_mode = "relative",
                },
            }
        end)

        if ok and relative_root and relative_root.valid then
            root = relative_root
        end
    end

    if not root and player.gui.screen then
        detached = true
        root = player.gui.screen.add{
            type = "frame",
            name = GUI_NAME,
            direction = "vertical",
            tags = {
                parent_gui = GUI_NAME,
                gui_mode = "screen",
            },
        }
        root.force_auto_center()
    end

    if not root then
        return nil
    end

    root.style.minimal_width = 440

    local function add_wrapped_label(parent, name)
        local label = parent.add{
            type = "label",
            name = name,
            style = "caption_label",
        }
        label.style.single_line = false
        label.style.horizontally_stretchable = true
        return label
    end

    local titlebar = root.add{type = "flow", direction = "horizontal"}
    if detached then
        titlebar.drag_target = root
    end
    titlebar.add{
        type = "label",
        caption = {"exotic-industries.neutron-collector-gui-title"},
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
            page = "neutron_collector",
        },
    }
    if detached then
        titlebar.add{
            type = "sprite-button",
            style = "close_button",
            sprite = "utility/close",
            hovered_sprite = "utility/close_black",
            clicked_sprite = "utility/close_black",
            tags = {
                parent_gui = GUI_NAME,
                action = "close-gui",
            },
        }
    end

    local main_container = root.add{
        type = "frame",
        name = "main-container",
        direction = "vertical",
        style = "inside_shallow_frame",
    }
    main_container.style.minimal_width = 440

    main_container.add{type = "frame", style = "ei_subheader_frame"}.add{
        type = "label",
        caption = {"exotic-industries.neutron-collector-gui-status-title"},
        style = "subheader_caption_label",
    }

    local status_flow = main_container.add{
        type = "flow",
        name = "status-flow",
        direction = "vertical",
        style = "ei_inner_content_flow",
    }
    status_flow.style.vertical_spacing = 4
    add_wrapped_label(status_flow, "state-label")
    add_wrapped_label(status_flow, "efficiency-label")
    local efficiency_bar = status_flow.add{
        type = "progressbar",
        name = "efficiency-bar",
        style = "ei_status_progressbar_cyan",
    }
    efficiency_bar.style.horizontally_stretchable = true
    add_wrapped_label(status_flow, "source-label")
    add_wrapped_label(status_flow, "distance-label")
    add_wrapped_label(status_flow, "source-activity-label")
    add_wrapped_label(status_flow, "charge-time-label")
    add_wrapped_label(status_flow, "block-reason-label")

    main_container.add{type = "frame", style = "ei_subheader_frame_with_top_border"}.add{
        type = "label",
        caption = {"exotic-industries.neutron-collector-gui-agents-title"},
        style = "subheader_caption_label",
    }

    local agents_flow = main_container.add{
        type = "flow",
        name = "agents-flow",
        direction = "vertical",
        style = "ei_inner_content_flow",
    }
    agents_flow.style.vertical_spacing = 4
    add_wrapped_label(agents_flow, "collector-agent-label")
    add_wrapped_label(agents_flow, "source-agent-label")
    add_wrapped_label(agents_flow, "scan-agent-label")

    main_container.add{type = "frame", style = "ei_subheader_frame_with_top_border"}.add{
        type = "label",
        caption = {"exotic-industries.neutron-collector-gui-candidates-title"},
        style = "subheader_caption_label",
    }

    local candidates_flow = main_container.add{
        type = "flow",
        name = "candidates-flow",
        direction = "vertical",
        style = "ei_inner_content_flow",
    }
    candidates_flow.style.vertical_spacing = 4
    for index = 1, MAX_GUI_CANDIDATES do
        add_wrapped_label(candidates_flow, "candidate-" .. index)
    end

    main_container.add{type = "frame", style = "ei_subheader_frame_with_top_border"}.add{
        type = "label",
        caption = {"exotic-industries.neutron-collector-gui-options-title"},
        style = "subheader_caption_label",
    }

    local options_flow = main_container.add{
        type = "flow",
        name = "options-flow",
        direction = "horizontal",
        style = "ei_inner_content_flow_horizontal",
    }
    options_flow.style.horizontal_spacing = 8
    options_flow.add{
        type = "button",
        name = "refresh-scan",
        caption = {"exotic-industries.neutron-collector-gui-refresh"},
        tags = {
            parent_gui = GUI_NAME,
            action = "refresh-scan",
        },
    }

    return root
end


function model.update_gui(player, snapshot)
    if not (player and player.valid) then
        return
    end

    local root = get_gui_root(player) or model.build_gui(player)
    if not root then
        return
    end
    local main = root["main-container"]
    if not main then
        return
    end

    local status_flow = main["status-flow"]
    local agents_flow = main["agents-flow"]
    local candidates_flow = main["candidates-flow"]
    if not (status_flow and agents_flow and candidates_flow) then
        return
    end

    status_flow["state-label"].caption = {"exotic-industries.neutron-collector-gui-state", {"exotic-industries." .. snapshot.collector_state_key}}
    status_flow["efficiency-label"].caption = {"exotic-industries.neutron-collector-gui-efficiency", snapshot.efficiency or 0}
    status_flow["efficiency-bar"].value = ei_lib.clamp((snapshot.efficiency or 0) / 300, 0, 1)
    status_flow["efficiency-bar"].caption = ""
    status_flow["efficiency-bar"].tooltip = {"exotic-industries.neutron-collector-gui-efficiency", snapshot.efficiency or 0}
    status_flow["source-label"].caption = {"exotic-industries.neutron-collector-gui-source", snapshot.source_name and {"entity-name." .. snapshot.source_name} or {"exotic-industries.neutron-collector-gui-source-none"}}

    if snapshot.source_distance ~= nil then
        status_flow["distance-label"].caption = {"exotic-industries.neutron-collector-gui-distance", format_distance(snapshot.source_distance) or "0.0"}
    else
        status_flow["distance-label"].caption = {"exotic-industries.neutron-collector-gui-distance-none"}
    end

    status_flow["source-activity-label"].caption = {"exotic-industries.neutron-collector-gui-source-activity", {"exotic-industries." .. snapshot.source_agent_key}}

    if snapshot.charge_time_seconds ~= nil then
        status_flow["charge-time-label"].caption = {"exotic-industries.neutron-collector-gui-charge-time", format_seconds(snapshot.charge_time_seconds) or "0.0"}
    else
        status_flow["charge-time-label"].caption = {"exotic-industries.neutron-collector-gui-charge-time-none"}
    end

    local block_reason_label = status_flow["block-reason-label"]
    if snapshot.block_reason_key then
        block_reason_label.visible = true
        block_reason_label.caption = {"exotic-industries.neutron-collector-gui-block-reason", {"exotic-industries." .. snapshot.block_reason_key}}
    else
        block_reason_label.visible = false
        block_reason_label.caption = ""
    end

    agents_flow["collector-agent-label"].caption = {"exotic-industries.neutron-collector-gui-agent-collector", {"exotic-industries." .. snapshot.collector_agent_key}}
    agents_flow["source-agent-label"].caption = {"exotic-industries.neutron-collector-gui-agent-source", {"exotic-industries." .. snapshot.source_agent_key}}
    agents_flow["scan-agent-label"].caption = {"exotic-industries.neutron-collector-gui-agent-scan", {"exotic-industries." .. snapshot.scan_agent_key}}

    for index = 1, MAX_GUI_CANDIDATES do
        local candidate_label = candidates_flow["candidate-" .. index]
        local candidate = snapshot.candidates[index]
        if candidate then
            candidate_label.caption = {
                "exotic-industries.neutron-collector-gui-candidate-line",
                {"entity-name." .. candidate.source_name},
                {"exotic-industries." .. (candidate.active and "neutron-collector-gui-source-live" or "neutron-collector-gui-source-dormant")},
                format_distance(candidate.distance) or "0.0",
                candidate.efficiency or 0,
            }
        elseif index == 1 then
            candidate_label.caption = {"exotic-industries.neutron-collector-gui-candidate-none"}
        else
            candidate_label.caption = ""
        end
    end

    local runtime = model.check_global()
    local session = runtime.open_by_player[player.index]
    if session then
        session.last_signature = snapshot.signature
        session.pending_tick = nil
    end
end


function model.open_gui(player)
    if not (player and player.valid) then
        return
    end

    local runtime = model.ensure_runtime_ready()
    if not runtime or runtime.runtime_rebuild_in_progress then
        return
    end

    local entity = model.get_open_neutron_collector(player)
    if not entity then
        model.close_gui(player)
        return
    end

    local collector_entry = model.register_collector(runtime, entity)
    if not collector_entry then
        model.close_gui(player)
        return
    end

    model.update_neutron_collector(entity, nil, false)
    collector_entry = runtime.collectors_by_unit[collector_entry.unit_number]
    if not collector_entry then
        model.close_gui(player)
        return
    end

    destroy_gui_root(player)
    model.ensure_gui_session(runtime, player.index, collector_entry.unit_number)

    local snapshot = model.get_gui_snapshot(runtime, collector_entry)
    if not snapshot then
        model.close_gui(player)
        return
    end

    model.update_gui(player, snapshot)
end


function model.close_gui(player)
    if not (player and player.valid) then
        return
    end

    local runtime = model.check_global()
    model.clear_gui_session(runtime, player.index, false)
    destroy_gui_root(player)
end


function model.on_gui_opened(event)
    model.open_gui(game.get_player(event.player_index))
end


function model.on_gui_click(event)
    local element = event and event.element
    if not (element and element.valid and element.tags) then
        return
    end

    if element.tags.action == "close-gui" then
        model.close_gui(game.get_player(event.player_index))
        return
    end

    if element.tags.action == "goto-informatron" then
        remote.call("informatron", "informatron_open_to_page", {
            player_index = event.player_index,
            interface = "exotic-industries-informatron",
            page_name = element.tags.page or "neutron_collector",
        })
        return
    end

    if element.tags.action ~= "refresh-scan" then
        return
    end

    local player = game.get_player(event.player_index)
    local entity = model.get_open_neutron_collector(player)
    if not entity then
        model.close_gui(player)
        return
    end

    if not model.update_neutron_collector(entity, nil, false) then
        model.close_gui(player)
        return
    end

    local runtime = model.ensure_runtime_ready()
    local unit_number = get_entity_unit_number(entity)
    local collector_entry = unit_number and runtime.collectors_by_unit[unit_number] or nil
    local snapshot = collector_entry and model.get_gui_snapshot(runtime, collector_entry) or nil
    if not snapshot then
        model.close_gui(player)
        return
    end

    model.update_gui(player, snapshot)
end


function model.on_entity_settings_pasted(event)
    local entity = ei_lib.get_valid_entity(event and event.destination)
    if not (entity and entity.name == NEUTRON_COLLECTOR_NAME) then
        return
    end

    model.update_neutron_collector(entity, nil, false)
end


function model.on_player_left_game(player_index)
    local player = game and game.get_player(player_index) or nil
    if player then
        model.close_gui(player)
        return
    end

    local runtime = model.check_global()
    model.clear_gui_session(runtime, player_index, false)
end


function model.service_gui_refreshes(event_or_tick, runtime)
    runtime = runtime or model.ensure_runtime_ready()
    if not runtime or runtime.runtime_rebuild_in_progress then
        return false
    end

    local tick = now_tick(event_or_tick)
    if runtime.last_gui_service_tick == tick then
        return false
    end

    runtime.last_gui_service_tick = tick

    if next(runtime.open_by_player) == nil then
        runtime.gui_refresh_buckets = make_gui_refresh_buckets()
        return false
    end

    local due_ticks = {}
    for bucket_tick, _ in pairs(runtime.gui_refresh_buckets) do
        if bucket_tick <= tick then
            due_ticks[#due_ticks + 1] = bucket_tick
        end
    end

    if #due_ticks == 0 then
        return false
    end

    table.sort(due_ticks)

    local due_players = {}
    for _, due_tick in ipairs(due_ticks) do
        local bucket = ei_runtime_scheduler.delayed_take_due(runtime.gui_refresh_buckets, due_tick)
        for _, player_index in ipairs(bucket) do
            due_players[player_index] = true
        end
    end

    local refreshed = false
    for player_index, _ in pairs(due_players) do
        local session = runtime.open_by_player[player_index]
        if session and session.pending_tick and session.pending_tick <= tick then
            local player = game and game.get_player(player_index) or nil
            local opened_entity = model.get_open_neutron_collector(player)
            local opened_unit_number = get_entity_unit_number(opened_entity)

            if not (player and player.valid) or opened_unit_number ~= session.unit_number then
                model.clear_gui_session(runtime, player_index, true)
            else
                local collector_entry = runtime.collectors_by_unit[session.unit_number]
                if not collector_entry or not model.entity_check(collector_entry.entity) then
                    model.clear_gui_session(runtime, player_index, true)
                else
                    local snapshot = model.get_gui_snapshot(runtime, collector_entry)
                    if not snapshot then
                        model.clear_gui_session(runtime, player_index, true)
                    else
                        if session.last_signature ~= snapshot.signature or not get_gui_root(player) then
                            model.update_gui(player, snapshot)
                        else
                            session.pending_tick = nil
                        end
                        refreshed = true
                    end
                end
            end
        end
    end

    return refreshed
end


function model.update(budget)
    local runtime = model.ensure_runtime_ready()
    if not runtime or runtime.runtime_rebuild_in_progress then
        return false
    end

    local gui_refreshed = model.service_gui_refreshes(nil, runtime)

    budget = math.max(0, math.floor(budget or 1))
    if budget <= 0 then
        return gui_refreshed
    end

    local dirty_count = runtime.dirty_collector_count or 0
    local connected_count = runtime.connected_source_count or 0
    local wire_due_count = get_due_wire_output_count(runtime)
    if dirty_count <= 0 and connected_count <= 0 and wire_due_count <= 0 then
        return gui_refreshed
    end

    -- Dirty collector work gets priority, but we still reserve poll budget for connected
    -- sources so reactors and furnaces pause/resume nearby collectors with low visible lag.
    local reserved_poll_budget = 0

    if connected_count > 0 then
        if dirty_count <= 0 then
            reserved_poll_budget = budget
        elseif budget > 1 then
            reserved_poll_budget = 1
        elseif runtime.prefer_poll_next then
            reserved_poll_budget = 1
        end
    end

    local dirty_budget = budget - reserved_poll_budget
    local dirty_processed = 0
    if dirty_budget > 0 then
        dirty_processed = model.process_dirty_collectors(runtime, dirty_budget)
    end

    local remaining_budget = budget - dirty_processed
    local poll_processed = 0
    if remaining_budget > 0 and connected_count > 0 then
        poll_processed = model.poll_connected_sources(runtime, remaining_budget)
    end

    remaining_budget = budget - dirty_processed - poll_processed
    if remaining_budget > 0 then
        dirty_processed = dirty_processed + model.process_dirty_collectors(runtime, remaining_budget)
    end

    local wire_processed = 0
    if budget > 0 then
        wire_processed = model.service_wire_proxy_outputs(runtime, game and game.tick or nil)
    end

    if connected_count > 0 and dirty_count > 0 and budget == 1 then
        runtime.prefer_poll_next = not runtime.prefer_poll_next
    end

    return gui_refreshed or (dirty_processed + poll_processed + wire_processed) > 0
end

--SPRITE RELATED
------------------------------------------------------------------------------------------------------

function model.make_direction_animation(entity, direction_count)
    model.remove_direction_animation(entity)

    local animation = rendering.draw_animation({
        animation = "ei-neutron-collector_top",
        target = entity,
        surface = entity.surface,
        render_layer = 132,
        animation_speed = 0,
        animation_offset = direction_count - 1,
        x_scale = 1,
        y_scale = 1,
    })

    local unit_number = get_entity_unit_number(entity)
    if unit_number then
        storage.ei["neutron_collector_animation"][unit_number] = animation
    end
end


function model.remove_direction_animation(entity)
    local unit_number = get_entity_unit_number(entity)
    if not unit_number then
        return
    end

    model.remove_direction_animation_by_unit(unit_number)
end

--HANDLERS
------------------------------------------------------------------------------------------------------

function model.on_built_entity(entity)
    local runtime = model.ensure_runtime_ready()
    if not runtime or runtime.runtime_rebuild_in_progress or model.entity_check(entity) == false then
        return
    end

    if entity.name == NEUTRON_COLLECTOR_NAME then
        model.update_neutron_collector(entity, nil, true)
        return
    end

    if model.neutron_sources[entity.name] then
        model.update_neutron_collectors_in_range(entity)
    end
end


function model.on_destroyed_entity(entity, destroy_type)
    local runtime = model.ensure_runtime_ready()
    if not runtime or runtime.runtime_rebuild_in_progress or model.entity_check(entity) == false then
        return
    end

    if entity.name == NEUTRON_COLLECTOR_NAME then
        model.unregister_collector(runtime, entity)
        return
    end

    if model.neutron_sources[entity.name] then
        model.update_neutron_collectors_in_range(entity, entity)
        local unit_number = get_entity_unit_number(entity)
        if unit_number then
            model.remove_source_entry(runtime, unit_number, false)
        end
    end
end

return model
