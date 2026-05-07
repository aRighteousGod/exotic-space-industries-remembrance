--==============================================================================
-- ESIR FILE MAP
-- owns: orbital logistics cohort runtime, including platform transponder IDs,
--       selector focus/policy, coordinator arbitration, dispatch uplinks,
--       leased mixed-manifest jobs, cohort GUIs, and QC/runtime snapshots
-- loaded_by: exotic-space-industries-remembrance\control.lua
-- cadence: event-driven invalidation plus dedicated control.lua step-10 cohort servicing
-- forwarded_events: check_init, rebuild_runtime_state, on_built_entity,
--                   on_destroyed_entity, on_entity_logistic_slot_changed,
--                   on_entity_settings_pasted, on_space_platform_changed_state,
--                   on_rocket_launch_ordered, request_runtime_rescan,
--                   open_gui, close_gui, on_player_left_game, on_gui_click,
--                   on_gui_selection_state_changed, on_gui_text_changed, update,
--                   get_pending_work_count, get_runtime_status, get_qc_snapshot
-- storage_roots: storage.ei.orbital_logistics
-- gui_ids: ei-orbital-logistics-console
-- rebuild_on: init, configuration change, admin rescan, and cohort entity churn
-- remote_interfaces: exposed indirectly through control.lua QC hooks
--==============================================================================

local ei_lib = require("lib/lib")
local ei_runtime_scheduler = require("lib/runtime-scheduler")

local model = {}

local ORBITAL_LOGISTICS_RUNTIME_STATE_VERSION = 5
local PLATFORM_TRANSPONDER_NAME = "ei-platform-transponder"
local ORBITAL_SELECTOR_NAME = "ei-orbital-selector"
local ORBITAL_COORDINATOR_NAME = "ei-orbital-coordinator"
local ORBITAL_DISPATCH_UPLINK_NAME = "ei-orbital-dispatch-uplink"
local FORCE_TRANSPONDER_BUCKET_KEY = true
local GUI_NAME = "ei-orbital-logistics-console"
local GUI_MODE_RELATIVE = "relative"
local GUI_MODE_SCREEN = "screen"
local RESCAN_QUEUE_KEY = "orbital-logistics-full-rescan"

local MODE_MANUAL = "manual"
local MODE_CIRCUIT = "circuit"
local MODE_POLICY = "policy"

local OVERSIZE_STICKY = "sticky"
local OVERSIZE_SINGLE_SHOT = "single_shot"
local OVERSIZE_THRESHOLD = "threshold"

local get_gui_record
local set_gui_record
local set_gui_draft_value
local get_opened_cohort_entity
local get_player_opened_cohort_entity
local resolve_requested_cohort_entity
local close_player_gui
local get_player_gui_root
local count_jobs_by_state
local gui_record_matches_cohort
local destroy_player_uplink_silo_overlays
local destroy_uplink_silo_overlays_for_unit
local sync_player_uplink_silo_overlays

local function normalize_gui_mode(gui_mode)
  if gui_mode == GUI_MODE_RELATIVE then
    return GUI_MODE_RELATIVE
  end

  return GUI_MODE_SCREEN
end

local NEED_MODE_NAME = "need"
local REQUESTS_MODE_NAME = "requests"

local VALID_SELECTOR_MODES = {
  [MODE_MANUAL] = true,
  [MODE_CIRCUIT] = true,
  [MODE_POLICY] = true,
}

local SELECTOR_MODE_ORDER = {MODE_MANUAL, MODE_CIRCUIT, MODE_POLICY}

local VALID_OVERSIZE_MODES = {
  [OVERSIZE_STICKY] = true,
  [OVERSIZE_SINGLE_SHOT] = true,
  [OVERSIZE_THRESHOLD] = true,
}

local OVERSIZE_MODE_ORDER = {OVERSIZE_STICKY, OVERSIZE_SINGLE_SHOT, OVERSIZE_THRESHOLD}

local ENTITY_SLOT_CAPACITY = {
  [PLATFORM_TRANSPONDER_NAME] = 32,
  [ORBITAL_SELECTOR_NAME] = 512,
  [ORBITAL_COORDINATOR_NAME] = 128,
  [ORBITAL_DISPATCH_UPLINK_NAME] = 512,
}

local PLATFORM_ID_SIGNAL = {type = "virtual", name = "ei-platform-id", quality = "normal"}
local READY_SIGNAL = {type = "virtual", name = "ei-orbital-ready", quality = "normal"}
local BLOCKED_SIGNAL = {type = "virtual", name = "ei-orbital-blocked", quality = "normal"}
local INVALID_SIGNAL = {type = "virtual", name = "ei-orbital-invalid", quality = "normal"}
local LEASE_SIGNAL = {type = "virtual", name = "ei-orbital-lease", quality = "normal"}

local STATUS_YELLOW = defines.entity_status_diode and defines.entity_status_diode.yellow or 2
local STATUS_RED = defines.entity_status_diode and defines.entity_status_diode.red or 3

local function is_cohort_entity(entity)
  return ei_lib.entity_check(entity)
    and (entity.name == PLATFORM_TRANSPONDER_NAME
      or entity.name == ORBITAL_SELECTOR_NAME
      or entity.name == ORBITAL_COORDINATOR_NAME
      or entity.name == ORBITAL_DISPATCH_UPLINK_NAME)
end

local function now_tick(current_tick)
  return current_tick or (game and game.tick) or 0
end

local function normalize_selector_mode(mode)
  if VALID_SELECTOR_MODES[mode] then
    return mode
  end

  return MODE_MANUAL
end

local function normalize_oversize_mode(mode)
  if VALID_OVERSIZE_MODES[mode] then
    return mode
  end

  return OVERSIZE_STICKY
end

local function normalize_platform_id_input(value)
  local numeric = tonumber(value)
  return numeric and math.max(1, math.floor(numeric)) or nil
end

local function normalize_threshold_floor_input(value)
  return math.max(0, tonumber(value) or 0)
end

local function signal_key(signal)
  if not signal then
    return ""
  end

  return table.concat({
    signal.type or "item",
    signal.name or "",
    signal.quality or "normal",
  }, "|")
end

local function copy_signal_id(signal)
  if not signal or not signal.type or not signal.name then
    return nil
  end

  return {
    type = signal.type,
    name = signal.name,
    quality = signal.quality or "normal",
  }
end

local function make_filter(signal, count, max)
  local copied = copy_signal_id(signal)
  if not copied then
    return nil
  end

  return {
    value = copied,
    min = math.max(0, math.floor(tonumber(count) or 0)),
    max = max,
  }
end

local function hash_update(hash, value)
  local text = tostring(value or "")
  for index = 1, #text do
    hash = ((hash * 33) + string.byte(text, index)) % 4294967296
  end
  return hash
end

local function build_filters_signature(filters)
  local hash = 5381
  hash = hash_update(hash, #filters)

  for _, filter in ipairs(filters or {}) do
    hash = hash_update(hash, filter.value and filter.value.type or "item")
    hash = hash_update(hash, filter.value and filter.value.name or "")
    hash = hash_update(hash, filter.value and filter.value.quality or "normal")
    hash = hash_update(hash, filter.min or 0)
    hash = hash_update(hash, filter.max == nil and "nil" or filter.max)
  end

  return string.format("%08x", hash)
end

local EMPTY_FILTERS = {}
local EMPTY_FILTERS_SIGNATURE = build_filters_signature(EMPTY_FILTERS)

local function count_map(tbl)
  local count = 0
  for _ in pairs(tbl or {}) do
    count = count + 1
  end
  return count
end

local function count_nested_bucket_count(index_root)
  local count = 0
  for _, force_bucket in pairs(index_root or EMPTY_FILTERS) do
    count = count + count_map(force_bucket)
  end
  return count
end

local function count_nested_member_count(index_root)
  local count = 0
  for _, force_bucket in pairs(index_root or EMPTY_FILTERS) do
    for _, scoped_bucket in pairs(force_bucket or EMPTY_FILTERS) do
      count = count + count_map(scoped_bucket)
    end
  end
  return count
end

local function count_cached_uplink_dropdowns(uplinks_by_unit)
  local count = 0
  for _, record in pairs(uplinks_by_unit or EMPTY_FILTERS) do
    if type(record.silo_dropdown_cache) == "table" then
      count = count + 1
    end
  end
  return count
end

local function get_scanner_module()
  return rawget(_G, "orbital_combinator") or package.loaded["scripts/control/orbital-combinator"]
end

local function get_entity_by_unit_number(unit_number)
  if not game or not unit_number then
    return nil
  end

  if game.get_entity_by_unit_number then
    local ok, entity = pcall(game.get_entity_by_unit_number, unit_number)
    if ok and ei_lib.entity_check(entity) then
      return entity
    end
  end

  return nil
end

local function get_platform_surface_name(platform)
  local scanner = get_scanner_module()
  if scanner and type(scanner.get_platform_surface_name) == "function" then
    local ok, surface_name = pcall(scanner.get_platform_surface_name, platform)
    if ok and surface_name then
      return surface_name
    end
  end

  return platform and platform.valid and platform.space_location and platform.space_location.name or nil
end

local function service_pass_cache_key(platform, mode, current_tick)
  if not platform or not platform.valid then
    return nil
  end

  return tostring(platform.index or 0) .. "|" .. tostring(mode or "") .. "|" .. tostring(current_tick or 0)
end

local function get_platform_mode_payload(platform, mode, current_tick, service_pass_cache)
  local cache_key = service_pass_cache_key(platform, mode, current_tick)
  if service_pass_cache and cache_key then
    local cached_payload = service_pass_cache.platform_mode_payloads[cache_key]
    if cached_payload ~= nil then
      return cached_payload or nil
    end
  end

  local scanner = get_scanner_module()
  if not scanner or type(scanner.get_platform_mode_filters) ~= "function" then
    return nil
  end

  local ok, payload = pcall(scanner.get_platform_mode_filters, platform, mode, current_tick)
  if service_pass_cache and cache_key then
    service_pass_cache.platform_mode_payloads[cache_key] = ok and payload or false
  end
  if ok and payload then
    return payload
  end

  return nil
end

local function get_platform_mode_payload_result(platform, mode, current_tick, service_pass_cache)
  local scanner = get_scanner_module()
  if not scanner or type(scanner.get_platform_mode_filters) ~= "function" then
    return nil, "scanner-bridge-missing"
  end

  local ok, payload = pcall(scanner.get_platform_mode_filters, platform, mode, current_tick)
  if ok then
    return payload, nil
  end

  return nil, tostring(payload)
end

local function summarize_scanner_bridge(platform, mode, current_tick)
  local payload, bridge_error = get_platform_mode_payload_result(platform, mode, current_tick)
  local filters = payload and payload.filters or EMPTY_FILTERS

  return {
    ok = payload ~= nil,
    error = payload and nil or bridge_error,
    platform_name = payload and payload.platform_name or nil,
    surface_name = payload and payload.surface_name or nil,
    signature = payload and payload.signature or EMPTY_FILTERS_SIGNATURE,
    filter_count = #filters,
  }
end

local function get_surface_summary(force_index, surface_name, current_tick)
  local scanner = get_scanner_module()
  if not scanner or type(scanner.get_surface_summary) ~= "function" then
    return nil
  end

  local ok, summary = pcall(scanner.get_surface_summary, force_index, surface_name, current_tick)
  if ok and summary then
    return summary
  end

  return nil
end

local function get_mode_name_need()
  local scanner = get_scanner_module()
  if scanner and type(scanner.get_mode_name_need) == "function" then
    return scanner.get_mode_name_need()
  end

  return NEED_MODE_NAME
end

local function get_mode_name_requests()
  local scanner = get_scanner_module()
  if scanner and type(scanner.get_mode_name_requests) == "function" then
    return scanner.get_mode_name_requests()
  end

  return REQUESTS_MODE_NAME
end

local function cohort_key(force_index, surface_name)
  return tostring(force_index or 0) .. ":" .. tostring(surface_name or "")
end

local function sort_records_by_unit(records)
  table.sort(records, function(left, right)
    return (left.unit_number or 0) < (right.unit_number or 0)
  end)
  return records
end

local function get_root()
  storage.ei = storage.ei or {}
  local root = storage.ei.orbital_logistics
  if type(root) ~= "table" then
    root = {}
    storage.ei.orbital_logistics = root
  end

  -- Preserve the serialized schema marker so check_init() can distinguish
  -- a legitimate empty runtime from stale or never-built state.
  root.runtime_state_version = tonumber(root.runtime_state_version) or 0
  root.runtime_initialized = root.runtime_initialized == true
  root.cohorts = type(root.cohorts) == "table" and root.cohorts or {}
  root.transponders_by_unit = type(root.transponders_by_unit) == "table" and root.transponders_by_unit or {}
  root.selectors_by_unit = type(root.selectors_by_unit) == "table" and root.selectors_by_unit or {}
  root.coordinators_by_unit = type(root.coordinators_by_unit) == "table" and root.coordinators_by_unit or {}
  root.uplinks_by_unit = type(root.uplinks_by_unit) == "table" and root.uplinks_by_unit or {}
  root.claims_by_force = type(root.claims_by_force) == "table" and root.claims_by_force or {}
  root.conflicts_by_force = type(root.conflicts_by_force) == "table" and root.conflicts_by_force or {}
  root.next_platform_id_by_force = type(root.next_platform_id_by_force) == "table" and root.next_platform_id_by_force or {}
  root.transponder_units_by_force = type(root.transponder_units_by_force) == "table" and root.transponder_units_by_force or {}
  root.transponder_units_by_platform = type(root.transponder_units_by_platform) == "table" and root.transponder_units_by_platform or {}
  root.transponder_units_by_dispatch_surface = type(root.transponder_units_by_dispatch_surface) == "table" and root.transponder_units_by_dispatch_surface or {}
  root.dispatch_surfaces_by_platform = type(root.dispatch_surfaces_by_platform) == "table" and root.dispatch_surfaces_by_platform or {}
  root.dispatch_surfaces_by_hub_unit = type(root.dispatch_surfaces_by_hub_unit) == "table" and root.dispatch_surfaces_by_hub_unit or {}
  root.uplink_dropdown_generation_by_surface = type(root.uplink_dropdown_generation_by_surface) == "table" and root.uplink_dropdown_generation_by_surface or {}
  root.power_sensor_by_unit = type(root.power_sensor_by_unit) == "table" and root.power_sensor_by_unit or {}
  root.power_state_by_unit = type(root.power_state_by_unit) == "table" and root.power_state_by_unit or {}
  root.power_seeded_tick_by_unit = type(root.power_seeded_tick_by_unit) == "table" and root.power_seeded_tick_by_unit or {}
  root.lease_by_job_id = type(root.lease_by_job_id) == "table" and root.lease_by_job_id or {}
  root.lease_by_uplink_unit = type(root.lease_by_uplink_unit) == "table" and root.lease_by_uplink_unit or {}
  root.uplink_by_silo_unit = type(root.uplink_by_silo_unit) == "table" and root.uplink_by_silo_unit or {}
  root.open_gui_by_player = type(root.open_gui_by_player) == "table" and root.open_gui_by_player or {}
  root.uplink_silo_overlay_by_player = type(root.uplink_silo_overlay_by_player) == "table" and root.uplink_silo_overlay_by_player or {}
  root.dirty_cohort_queue = ei_runtime_scheduler.ensure_queue(root.dirty_cohort_queue)
  root.rescan_queue = ei_runtime_scheduler.ensure_queue(root.rescan_queue)
  root.pending_rescan_reason = root.pending_rescan_reason or nil
  root.pending_rescan_request_count = root.pending_rescan_request_count or 0
  root.last_rescan_tick = root.last_rescan_tick or 0
  root.last_rescan_request_tick = root.last_rescan_request_tick or 0
  root.last_runtime_status_tick = root.last_runtime_status_tick or 0
  return root
end

local function destroy_render_object(render_object)
  if render_object and render_object.valid then
    render_object.destroy()
  end
end

local cohort_power = {}
cohort_power.proxy_search_radius = 1.25
cohort_power.state_powered = "powered"
cohort_power.state_low_power = "low_power"
cohort_power.state_unpowered = "unpowered"
cohort_power.sensor_name_by_entity = {
  [PLATFORM_TRANSPONDER_NAME] = "ei-platform-transponder-power-sensor",
  [ORBITAL_SELECTOR_NAME] = "ei-orbital-selector-power-sensor",
  [ORBITAL_COORDINATOR_NAME] = "ei-orbital-coordinator-power-sensor",
  [ORBITAL_DISPATCH_UPLINK_NAME] = "ei-orbital-dispatch-uplink-power-sensor",
}
cohort_power.sensor_names = {}
for _, sensor_name in pairs(cohort_power.sensor_name_by_entity) do
  cohort_power.sensor_names[sensor_name] = true
end

function cohort_power.get_sensor_name(entity_or_name)
  local entity_name = type(entity_or_name) == "table" and entity_or_name.name or entity_or_name
  return cohort_power.sensor_name_by_entity[entity_name]
end

function cohort_power.get_sensor_root()
  return get_root().power_sensor_by_unit
end

function cohort_power.get_state_root()
  return get_root().power_state_by_unit
end

function cohort_power.get_seed_root()
  return get_root().power_seeded_tick_by_unit
end

function cohort_power.is_sensor(entity)
  return ei_lib.entity_check(entity) and cohort_power.sensor_names[entity.name] == true
end

function cohort_power.normalize_state(state)
  if state == true or state == cohort_power.state_powered then
    return cohort_power.state_powered
  end
  if state == cohort_power.state_low_power then
    return cohort_power.state_low_power
  end

  return cohort_power.state_unpowered
end

function cohort_power.is_active_state(state)
  state = cohort_power.normalize_state(state)
  return state == cohort_power.state_powered or state == cohort_power.state_low_power
end

function cohort_power.get_cached_state(unit_number)
  return cohort_power.normalize_state(cohort_power.get_state_root()[unit_number])
end

function cohort_power.set_cached_state(unit_number, state)
  cohort_power.get_state_root()[unit_number] = cohort_power.normalize_state(state)
end

function cohort_power.same_position(left, right)
  if not left or not right then
    return false
  end

  return math.abs((left.position.x or 0) - (right.position.x or 0)) < 0.01
    and math.abs((left.position.y or 0) - (right.position.y or 0)) < 0.01
end

function cohort_power.find_existing_sensor(entity)
  if not is_cohort_entity(entity) then
    return nil
  end

  local sensor_name = cohort_power.get_sensor_name(entity)
  if not sensor_name then
    return nil
  end

  local fallback = nil
  local fallback_distance = nil
  local position = entity.position
  local helpers = entity.surface.find_entities_filtered{
    area = {
      {position.x - cohort_power.proxy_search_radius, position.y - cohort_power.proxy_search_radius},
      {position.x + cohort_power.proxy_search_radius, position.y + cohort_power.proxy_search_radius},
    },
    force = entity.force,
    name = sensor_name,
  }

  for _, helper in ipairs(helpers) do
    if cohort_power.is_sensor(helper) then
      local dx = (helper.position.x or 0) - (position.x or 0)
      local dy = (helper.position.y or 0) - (position.y or 0)
      local distance = dx * dx + dy * dy
      if not fallback or distance < fallback_distance then
        if fallback then
          fallback.destroy({raise_destroy = false})
        end
        fallback = helper
        fallback_distance = distance
      else
        helper.destroy({raise_destroy = false})
      end
    end
  end

  return fallback
end

function cohort_power.ensure(entity, current_tick)
  if not is_cohort_entity(entity) then
    return nil
  end

  local sensor_name = cohort_power.get_sensor_name(entity)
  if not sensor_name then
    return nil
  end

  local unit_number = entity.unit_number
  local sensor_root = cohort_power.get_sensor_root()
  local sensor = sensor_root[unit_number]
  local created = false

  if cohort_power.is_sensor(sensor) then
    if sensor.name == sensor_name
      and sensor.force == entity.force
      and sensor.surface == entity.surface
      and cohort_power.same_position(sensor, entity)
    then
      return sensor
    end

    sensor.destroy({raise_destroy = false})
  end

  sensor = cohort_power.find_existing_sensor(entity)
  if cohort_power.is_sensor(sensor) and not cohort_power.same_position(sensor, entity) then
    sensor.destroy({raise_destroy = false})
    sensor = nil
  end

  if not cohort_power.is_sensor(sensor) then
    sensor = entity.surface.create_entity{
      name = sensor_name,
      position = entity.position,
      force = entity.force,
      create_build_effect_smoke = false,
      raise_built = false,
    }
    created = cohort_power.is_sensor(sensor)
  end

  sensor_root[unit_number] = cohort_power.is_sensor(sensor) and sensor or nil
  if created then
    cohort_power.get_seed_root()[unit_number] = (current_tick or (game and game.tick) or 0) + 2
    cohort_power.set_cached_state(unit_number, cohort_power.state_unpowered)
  end

  return sensor_root[unit_number]
end

function cohort_power.get_live_state(entity, current_tick)
  if not is_cohort_entity(entity) then
    return cohort_power.state_unpowered
  end

  local unit_number = entity.unit_number
  local state_root = cohort_power.get_state_root()
  local seed_root = cohort_power.get_seed_root()
  current_tick = current_tick or (game and game.tick) or 0

  local seeded_until_tick = seed_root[unit_number]
  if seeded_until_tick
    and current_tick <= seeded_until_tick
    and cohort_power.normalize_state(state_root[unit_number]) == cohort_power.state_unpowered
  then
    return cohort_power.state_unpowered
  end

  local sensor = cohort_power.get_sensor_root()[unit_number]
  if not cohort_power.is_sensor(sensor) then
    return cohort_power.state_unpowered
  end

  local sensor_status = sensor.status
  if sensor_status == defines.entity_status.no_power
    or sensor_status == defines.entity_status.not_plugged_in_electric_network
  then
    return cohort_power.state_unpowered
  end
  if sensor_status == defines.entity_status.low_power then
    return cohort_power.state_low_power
  end
  if sensor_status ~= nil then
    if seeded_until_tick and current_tick > seeded_until_tick then
      seed_root[unit_number] = nil
    end
    return cohort_power.state_powered
  end
  if (sensor.energy or 0) > 0 then
    if seeded_until_tick and current_tick > seeded_until_tick then
      seed_root[unit_number] = nil
    end
    return cohort_power.state_powered
  end
  if seeded_until_tick and current_tick > seeded_until_tick then
    seed_root[unit_number] = nil
  end

  return cohort_power.state_unpowered
end

function cohort_power.apply_visible_status(entity, state)
  if not is_cohort_entity(entity) then
    return
  end

  state = cohort_power.normalize_state(state)

  if state == cohort_power.state_unpowered then
    entity.custom_status = {
      diode = STATUS_RED,
      label = {"exotic-industries.orbital-scanner-status-no-power"},
    }
    return
  end

  if state == cohort_power.state_low_power then
    entity.custom_status = {
      diode = STATUS_YELLOW,
      label = {"exotic-industries.orbital-scanner-status-low-power"},
    }
    return
  end

  entity.custom_status = nil
end

function cohort_power.destroy(unit_number, entity_name)
  unit_number = tonumber(unit_number) or nil
  if not unit_number then
    return
  end

  local sensor_root = cohort_power.get_sensor_root()
  local sensor = sensor_root[unit_number]
  local expected_sensor_name = cohort_power.get_sensor_name(entity_name)
  if cohort_power.is_sensor(sensor)
    and (expected_sensor_name == nil or sensor.name == expected_sensor_name)
  then
    sensor.destroy({raise_destroy = false})
  end

  sensor_root[unit_number] = nil
  cohort_power.get_seed_root()[unit_number] = nil
  cohort_power.get_state_root()[unit_number] = nil
end

function cohort_power.destroy_all_sensors()
  if not game or not game.surfaces then
    return
  end

  for _, surface in pairs(game.surfaces) do
    for sensor_name in pairs(cohort_power.sensor_names) do
      for _, sensor in ipairs(surface.find_entities_filtered{name = sensor_name}) do
        if cohort_power.is_sensor(sensor) then
          sensor.destroy({raise_destroy = false})
        end
      end
    end
  end
end

destroy_player_uplink_silo_overlays = function(player_index)
  player_index = tonumber(player_index) or nil
  if not player_index then
    return
  end

  local root = get_root()
  local render_state = root.uplink_silo_overlay_by_player[player_index]
  if type(render_state) == "table" and type(render_state.entries) == "table" then
    for _, render_entry in pairs(render_state.entries) do
      destroy_render_object(render_entry.render or render_entry)
    end
  end
  root.uplink_silo_overlay_by_player[player_index] = nil
end

destroy_uplink_silo_overlays_for_unit = function(unit_number)
  unit_number = tonumber(unit_number) or 0
  if unit_number == 0 then
    return
  end

  local root = get_root()
  for player_index, render_state in pairs(root.uplink_silo_overlay_by_player) do
    if type(render_state) == "table" and type(render_state.entries) == "table" then
      local keep_entries = {}
      local removed_any = false
      for _, render_entry in ipairs(render_state.entries) do
        if type(render_entry) == "table"
          and render_entry.uplink_unit ~= unit_number
          and render_entry.silo_unit ~= unit_number
        then
          keep_entries[#keep_entries + 1] = render_entry
        else
          destroy_render_object(render_entry and (render_entry.render or render_entry) or nil)
          removed_any = true
        end
      end

      if removed_any then
        if next(keep_entries) ~= nil then
          render_state.entries = keep_entries
        else
          root.uplink_silo_overlay_by_player[player_index] = nil
        end
      end
    else
      root.uplink_silo_overlay_by_player[player_index] = nil
    end
  end
end

local function ensure_cohort(force_index, surface_name)
  local root = get_root()
  local key = cohort_key(force_index, surface_name)
  local cohort = root.cohorts[key]
  if type(cohort) ~= "table" then
    cohort = {}
    root.cohorts[key] = cohort
  end

  cohort.key = key
  cohort.force_index = force_index
  cohort.surface_name = surface_name
  cohort.transponder_units = type(cohort.transponder_units) == "table" and cohort.transponder_units or {}
  cohort.selector_units = type(cohort.selector_units) == "table" and cohort.selector_units or {}
  cohort.coordinator_units = type(cohort.coordinator_units) == "table" and cohort.coordinator_units or {}
  cohort.uplink_units = type(cohort.uplink_units) == "table" and cohort.uplink_units or {}
  cohort.jobs_by_id = type(cohort.jobs_by_id) == "table" and cohort.jobs_by_id or {}
  cohort.blocked_lanes = type(cohort.blocked_lanes) == "table" and cohort.blocked_lanes or {}
  cohort.last_assignment_tick_by_platform_id = type(cohort.last_assignment_tick_by_platform_id) == "table" and cohort.last_assignment_tick_by_platform_id or {}
  cohort.active_coordinator_unit_number = cohort.active_coordinator_unit_number or nil
  cohort.last_service_tick = cohort.last_service_tick or 0
  cohort.last_snapshot = type(cohort.last_snapshot) == "table" and cohort.last_snapshot or {}
  cohort.last_snapshot_signature = cohort.last_snapshot_signature or nil
  cohort.last_signature = cohort.last_signature or nil
  -- Stable cohorts can be serviced repeatedly for queue fairness without paying
  -- the full signature-build/render cost every visit. Signature generation bumps
  -- only when signature-visible cohort state actually changes.
  cohort.signature_generation = tonumber(cohort.signature_generation) or 0
  cohort.last_signature_generation = tonumber(cohort.last_signature_generation) or -1
  return cohort
end

local function cohort_has_members(cohort)
  return next(cohort and cohort.transponder_units or EMPTY_FILTERS) ~= nil
    or next(cohort and cohort.selector_units or EMPTY_FILTERS) ~= nil
    or next(cohort and cohort.coordinator_units or EMPTY_FILTERS) ~= nil
    or next(cohort and cohort.uplink_units or EMPTY_FILTERS) ~= nil
end

local function adjust_dispatch_surface_ref(index_root, first_key, second_key, surface_name, delta)
  if not (first_key and second_key and surface_name) then
    return
  end

  local first_bucket = index_root[first_key]
  if type(first_bucket) ~= "table" then
    first_bucket = {}
    index_root[first_key] = first_bucket
  end

  local second_bucket = first_bucket[second_key]
  if type(second_bucket) ~= "table" then
    second_bucket = {}
    first_bucket[second_key] = second_bucket
  end

  local next_count = (second_bucket[surface_name] or 0) + delta
  if next_count > 0 then
    second_bucket[surface_name] = next_count
    return
  end

  second_bucket[surface_name] = nil
  if next(second_bucket) == nil then
    first_bucket[second_key] = nil
  end
  if next(first_bucket) == nil then
    index_root[first_key] = nil
  end
end

local function adjust_force_scoped_unit(index_root, force_index, bucket_key, unit_number, present)
  if not (force_index and bucket_key and unit_number) then
    return
  end

  local force_bucket = index_root[force_index]
  if type(force_bucket) ~= "table" then
    if not present then
      return
    end

    force_bucket = {}
    index_root[force_index] = force_bucket
  end

  local scoped_bucket = force_bucket[bucket_key]
  if type(scoped_bucket) ~= "table" then
    if not present then
      return
    end

    scoped_bucket = {}
    force_bucket[bucket_key] = scoped_bucket
  end

  if present then
    scoped_bucket[unit_number] = true
    return
  end

  scoped_bucket[unit_number] = nil
  if next(scoped_bucket) == nil then
    force_bucket[bucket_key] = nil
  end
  if next(force_bucket) == nil then
    index_root[force_index] = nil
  end
end

local function get_surface_uplink_dropdown_generation(force_index, surface_name)
  local by_force = get_root().uplink_dropdown_generation_by_surface[force_index]
  return by_force and (tonumber(by_force[surface_name]) or 0) or 0
end

local function bump_surface_uplink_dropdown_generation(force_index, surface_name)
  if not (force_index and surface_name) then
    return 0
  end

  local root = get_root()
  local by_force = root.uplink_dropdown_generation_by_surface[force_index]
  if type(by_force) ~= "table" then
    by_force = {}
    root.uplink_dropdown_generation_by_surface[force_index] = by_force
  end

  local next_generation = math.max(0, tonumber(by_force[surface_name]) or 0) + 1
  by_force[surface_name] = next_generation
  return next_generation
end

local function sync_transponder_dispatch_indexes(record, previous_force_index, previous_platform_index, previous_dispatch_surface_name, previous_hub_unit_number, previous_unit_number)
  local next_force_index = record and record.force_index or nil
  local next_platform_index = record and record.platform_index or nil
  local next_dispatch_surface_name = record and record.dispatch_surface_name or nil
  local next_hub_unit_number = record and record.hub_unit_number or nil
  local next_unit_number = record and record.unit_number or nil
  previous_unit_number = previous_unit_number or next_unit_number
  if previous_force_index == next_force_index
    and previous_platform_index == next_platform_index
    and previous_dispatch_surface_name == next_dispatch_surface_name
    and previous_hub_unit_number == next_hub_unit_number
    and previous_unit_number == next_unit_number
  then
    return
  end

  local root = get_root()
  adjust_force_scoped_unit(root.transponder_units_by_force, previous_force_index, FORCE_TRANSPONDER_BUCKET_KEY, previous_unit_number, false)
  adjust_force_scoped_unit(root.transponder_units_by_platform, previous_force_index, previous_platform_index, previous_unit_number, false)
  adjust_force_scoped_unit(root.transponder_units_by_dispatch_surface, previous_force_index, previous_dispatch_surface_name, previous_unit_number, false)
  adjust_dispatch_surface_ref(root.dispatch_surfaces_by_platform, previous_force_index, previous_platform_index, previous_dispatch_surface_name, -1)
  adjust_dispatch_surface_ref(root.dispatch_surfaces_by_hub_unit, previous_force_index, previous_hub_unit_number, previous_dispatch_surface_name, -1)
  adjust_force_scoped_unit(root.transponder_units_by_force, next_force_index, FORCE_TRANSPONDER_BUCKET_KEY, next_unit_number, true)
  adjust_force_scoped_unit(root.transponder_units_by_platform, next_force_index, next_platform_index, next_unit_number, true)
  adjust_force_scoped_unit(root.transponder_units_by_dispatch_surface, next_force_index, next_dispatch_surface_name, next_unit_number, true)
  adjust_dispatch_surface_ref(root.dispatch_surfaces_by_platform, next_force_index, next_platform_index, next_dispatch_surface_name, 1)
  adjust_dispatch_surface_ref(root.dispatch_surfaces_by_hub_unit, next_force_index, next_hub_unit_number, next_dispatch_surface_name, 1)
end

local function queue_cohort(force_index, surface_name)
  if not force_index or not surface_name then
    return false
  end

  local root = get_root()
  local key = cohort_key(force_index, surface_name)
  local cohort = root.cohorts[key]
  if not cohort then
    return false
  end

  if not cohort_has_members(cohort) then
    root.cohorts[key] = nil
    return false
  end

  ei_runtime_scheduler.queue_push_unique(root.dirty_cohort_queue, key, key)
  return true
end

-- GUI polish uses these cheap queue lookups so operators can see when a cohort
-- refresh or runtime rebuild is already pending instead of re-clicking blindly.
local function is_cohort_queue_pending(force_index, surface_name)
  if not (force_index and surface_name) then
    return false
  end

  local queue = ei_runtime_scheduler.ensure_queue(get_root().dirty_cohort_queue)
  return queue.queued[cohort_key(force_index, surface_name)] == true
end

local function is_runtime_rescan_pending()
  local queue = ei_runtime_scheduler.ensure_queue(get_root().rescan_queue)
  return queue.queued[RESCAN_QUEUE_KEY] == true
end

-- Keep "wake the cohort soon" separate from "the cohort's visible signature just
-- changed". Queue-only wakeups are still useful for manual refreshes, GUI-open
-- follow-up, and post-launch revisits that do not guarantee a new output shape.
local function touch_cohort_signature_generation(force_index, surface_name)
  if not (force_index and surface_name) then
    return false
  end

  local root = get_root()
  local cohort = root.cohorts[cohort_key(force_index, surface_name)]
  if type(cohort) ~= "table" then
    return false
  end

  cohort.signature_generation = math.max(0, tonumber(cohort.signature_generation) or 0) + 1
  return true
end

local function mark_cohort_dirty(force_index, surface_name)
  local touched = touch_cohort_signature_generation(force_index, surface_name)
  local queued = queue_cohort(force_index, surface_name)
  return touched or queued
end

local function mark_dispatch_surface_refs_dirty(force_index, refs)
  local marked = false
  for surface_name in pairs(refs or {}) do
    marked = mark_cohort_dirty(force_index, surface_name) or marked
  end
  return marked
end

local function queue_platform_dispatch_cohorts(force_index, platform_index)
  local root = get_root()
  local refs = root.dispatch_surfaces_by_platform[force_index]
  refs = refs and refs[platform_index] or nil
  return mark_dispatch_surface_refs_dirty(force_index, refs)
end

local function queue_hub_dispatch_cohorts(force_index, hub_unit_number)
  local root = get_root()
  local refs = root.dispatch_surfaces_by_hub_unit[force_index]
  refs = refs and refs[hub_unit_number] or nil
  return mark_dispatch_surface_refs_dirty(force_index, refs)
end

local function mark_transponder_record_cohorts_dirty(record)
  if type(record) ~= "table" then
    return false
  end

  local marked = mark_cohort_dirty(record.force_index, record.surface_name)
  if record.dispatch_surface_name and record.dispatch_surface_name ~= record.surface_name then
    marked = mark_cohort_dirty(record.force_index, record.dispatch_surface_name) or marked
  end
  return marked
end

local function get_record_entity(record)
  local entity = record and record.entity or nil
  if ei_lib.entity_check(entity) then
    return entity
  end

  entity = get_entity_by_unit_number(record and record.unit_number or nil)
  if ei_lib.entity_check(entity) then
    record.entity = entity
    return entity
  end

  return nil
end

local function get_cohort_record_by_unit_number(unit_number)
  if not unit_number then
    return nil
  end

  local root = get_root()
  return root.transponders_by_unit[unit_number]
    or root.selectors_by_unit[unit_number]
    or root.coordinators_by_unit[unit_number]
    or root.uplinks_by_unit[unit_number]
    or nil
end

local function allocate_platform_id(force_index)
  local root = get_root()
  local claims = root.claims_by_force[force_index] or {}
  local next_id = math.max(1, root.next_platform_id_by_force[force_index] or 1)

  while claims[next_id] do
    next_id = next_id + 1
  end

  root.next_platform_id_by_force[force_index] = next_id + 1
  return next_id
end

local function get_force_transponder_records(force_index)
  local root = get_root()
  local records = {}
  local indexed_units = root.transponder_units_by_force[force_index]
  indexed_units = indexed_units and indexed_units[FORCE_TRANSPONDER_BUCKET_KEY] or nil

  for unit_number in pairs(indexed_units or EMPTY_FILTERS) do
    local record = root.transponders_by_unit[unit_number]
    if record then
      records[#records + 1] = record
    end
  end

  return sort_records_by_unit(records)
end

local function collect_changed_flat_map_keys(changed_keys, previous_map, next_map)
  for key, previous_value in pairs(previous_map or EMPTY_FILTERS) do
    if next_map[key] ~= previous_value then
      changed_keys[key] = true
    end
  end
  for key, next_value in pairs(next_map or EMPTY_FILTERS) do
    if previous_map[key] ~= next_value then
      changed_keys[key] = true
    end
  end
end

local function rebuild_force_platform_claims(force_index)
  local root = get_root()
  local previous_claims = root.claims_by_force[force_index] or EMPTY_FILTERS
  local previous_conflicts = root.conflicts_by_force[force_index] or EMPTY_FILTERS
  local previous_conflict_by_unit = {}
  local claims = {}
  local conflicts = {}
  local grouped = {}
  local next_id = 1

  for _, record in ipairs(get_force_transponder_records(force_index)) do
    previous_conflict_by_unit[record.unit_number] = record.conflict == true
    record.conflict = false
    if cohort_power.record_has_active_power(record) then
      local platform_id = tonumber(record.platform_id) or nil
      if platform_id and platform_id > 0 then
        grouped[platform_id] = grouped[platform_id] or {}
        grouped[platform_id][#grouped[platform_id] + 1] = record
        if platform_id >= next_id then
          next_id = platform_id + 1
        end
      end
    end
  end

  for platform_id, records in pairs(grouped) do
    local platform_index = nil
    local conflicted = false
    for _, record in ipairs(records) do
      if platform_index == nil then
        platform_index = record.platform_index
      elseif record.platform_index ~= platform_index then
        conflicted = true
      end
    end

    if conflicted then
      conflicts[platform_id] = true
      for _, record in ipairs(records) do
        record.conflict = true
      end
    else
      claims[platform_id] = platform_index
    end
  end

  root.claims_by_force[force_index] = claims
  root.conflicts_by_force[force_index] = conflicts
  root.next_platform_id_by_force[force_index] = math.max(root.next_platform_id_by_force[force_index] or 1, next_id)
  local changed_platform_ids = {}
  collect_changed_flat_map_keys(changed_platform_ids, previous_claims, claims)
  collect_changed_flat_map_keys(changed_platform_ids, previous_conflicts, conflicts)

  -- The caller already dirties the directly edited transponder. Only wake the
  -- other cohorts whose claim/conflict view actually changed.
  for platform_id in pairs(changed_platform_ids) do
    for _, record in ipairs(grouped[platform_id] or EMPTY_FILTERS) do
      mark_transponder_record_cohorts_dirty(record)
    end
  end

  -- A transponder can also keep the same platform ID while its conflict flag
  -- flips because another claimant moved in or out. Catch that explicit panel-
  -- visible state change without falling back to a full force-wide dirty pass.
  for _, records in pairs(grouped) do
    for _, record in ipairs(records) do
      if previous_conflict_by_unit[record.unit_number] ~= (record.conflict == true) then
        mark_transponder_record_cohorts_dirty(record)
      end
    end
  end
end

function cohort_power.get_record_state(record)
  return cohort_power.get_cached_state(record and record.unit_number or nil)
end

function cohort_power.record_has_active_power(record)
  return cohort_power.is_active_state(cohort_power.get_record_state(record))
end

function cohort_power.mark_record_dirty(record)
  if type(record) ~= "table" then
    return false
  end

  if record.platform_index ~= nil then
    rebuild_force_platform_claims(record.force_index)
    return mark_transponder_record_cohorts_dirty(record)
  end

  return mark_cohort_dirty(record.force_index, record.surface_name)
end

function cohort_power.refresh_record_state(record, current_tick)
  if type(record) ~= "table" or not record.unit_number then
    return false
  end

  local entity = get_record_entity(record)
  local previous_state = cohort_power.get_cached_state(record.unit_number)
  local next_state = cohort_power.state_unpowered
  if entity then
    cohort_power.ensure(entity, current_tick)
    next_state = cohort_power.get_live_state(entity, current_tick)
  else
    cohort_power.destroy(record.unit_number)
  end

  -- Power status belongs to the visible terminal, not the hidden sensor. Keep
  -- degraded states fresh even when output pages do not need a full rewrite.
  if entity and (next_state ~= cohort_power.state_powered or previous_state ~= next_state) then
    cohort_power.apply_visible_status(entity, next_state)
  end

  if previous_state == next_state then
    return false
  end

  cohort_power.set_cached_state(record.unit_number, next_state)
  cohort_power.mark_record_dirty(record)
  return true
end

function cohort_power.refresh_cohort_state(cohort, current_tick)
  local root = get_root()
  local changed = false
  for unit_number in pairs(cohort.transponder_units or EMPTY_FILTERS) do
    changed = cohort_power.refresh_record_state(root.transponders_by_unit[unit_number], current_tick) or changed
  end
  for unit_number in pairs(cohort.selector_units or EMPTY_FILTERS) do
    changed = cohort_power.refresh_record_state(root.selectors_by_unit[unit_number], current_tick) or changed
  end
  for unit_number in pairs(cohort.coordinator_units or EMPTY_FILTERS) do
    changed = cohort_power.refresh_record_state(root.coordinators_by_unit[unit_number], current_tick) or changed
  end
  for unit_number in pairs(cohort.uplink_units or EMPTY_FILTERS) do
    changed = cohort_power.refresh_record_state(root.uplinks_by_unit[unit_number], current_tick) or changed
  end
  return changed
end

local function find_existing_platform_id(force_index, platform_index, except_unit_number)
  local root = get_root()
  local existing_platform_id = nil

  for unit_number, record in pairs(root.transponders_by_unit) do
    if unit_number ~= except_unit_number
      and record.force_index == force_index
      and record.platform_index == platform_index
      and tonumber(record.platform_id)
    then
      local candidate = math.floor(tonumber(record.platform_id))
      if candidate > 0 and (not existing_platform_id or candidate < existing_platform_id) then
        existing_platform_id = candidate
      end
    end
  end

  return existing_platform_id
end

local function ensure_transponder_platform_id(record)
  local root = get_root()
  local platform_id = tonumber(record.manual_platform_id) or tonumber(record.platform_id) or nil
  if platform_id and platform_id > 0 then
    record.platform_id = math.floor(platform_id)
    local claims = root.claims_by_force[record.force_index] or EMPTY_FILTERS
    local conflicts = root.conflicts_by_force[record.force_index] or EMPTY_FILTERS
    -- Most service passes revisit transponders whose platform claim is already
    -- settled. Skip the force-wide claim rebuild unless this ID actually needs
    -- to be revalidated or conflict state has gone stale.
    if record.platform_index ~= nil
      and claims[record.platform_id] == record.platform_index
      and conflicts[record.platform_id] ~= true
    then
      record.conflict = false
      return record.platform_id
    end
    rebuild_force_platform_claims(record.force_index)
    return record.platform_id
  end

  local reused = find_existing_platform_id(record.force_index, record.platform_index, record.unit_number)
  if reused then
    record.platform_id = reused
    local claims = root.claims_by_force[record.force_index] or EMPTY_FILTERS
    local conflicts = root.conflicts_by_force[record.force_index] or EMPTY_FILTERS
    if record.platform_index ~= nil
      and claims[record.platform_id] == record.platform_index
      and conflicts[record.platform_id] ~= true
    then
      record.conflict = false
      return record.platform_id
    end
    rebuild_force_platform_claims(record.force_index)
    return record.platform_id
  end

  record.platform_id = allocate_platform_id(record.force_index)
  rebuild_force_platform_claims(record.force_index)
  return record.platform_id
end

local function read_platform_from_transponder(entity)
  if not ei_lib.entity_check(entity) then
    return nil
  end

  local platform = entity.surface and entity.surface.valid and entity.surface.platform or nil
  if platform and platform.valid then
    return platform
  end

  return nil
end

local function register_transponder(entity, current_tick)
  if not ei_lib.entity_check(entity) then
    return nil
  end

  local root = get_root()
  local platform = read_platform_from_transponder(entity)
  local record = root.transponders_by_unit[entity.unit_number] or {}
  local previous_force_index = record.force_index
  local previous_platform_index = record.platform_index
  local previous_dispatch_surface_name = record.dispatch_surface_name
  local previous_hub_unit_number = record.hub_unit_number
  record.entity = entity
  record.unit_number = entity.unit_number
  record.force_index = entity.force.index
  record.surface_name = entity.surface.name
  record.platform_index = platform and platform.index or nil
  record.platform_name = platform and platform.name or nil
  record.dispatch_surface_name = platform and get_platform_surface_name(platform) or nil
  record.hub_unit_number = platform and platform.hub and platform.hub.valid and platform.hub.unit_number or nil
  record.last_seen_tick = now_tick(current_tick)
  root.transponders_by_unit[entity.unit_number] = record
  cohort_power.ensure(entity, current_tick)
  cohort_power.set_cached_state(entity.unit_number, cohort_power.get_live_state(entity, current_tick))
  cohort_power.apply_visible_status(entity, cohort_power.get_cached_state(entity.unit_number))
  sync_transponder_dispatch_indexes(record, previous_force_index, previous_platform_index, previous_dispatch_surface_name, previous_hub_unit_number)
  ensure_cohort(record.force_index, record.surface_name).transponder_units[entity.unit_number] = true
  ensure_transponder_platform_id(record)
  mark_cohort_dirty(record.force_index, record.surface_name)
  if previous_dispatch_surface_name and previous_dispatch_surface_name ~= record.surface_name then
    mark_cohort_dirty(record.force_index, previous_dispatch_surface_name)
  end
  if record.dispatch_surface_name and record.dispatch_surface_name ~= record.surface_name then
    mark_cohort_dirty(record.force_index, record.dispatch_surface_name)
  end
  return record
end

local function remove_transponder(unit_number)
  local root = get_root()
  local record = root.transponders_by_unit[unit_number]
  if not record then
    return false
  end

  local cohort = root.cohorts[cohort_key(record.force_index, record.surface_name)]
  if cohort then
    cohort.transponder_units[unit_number] = nil
  end
  sync_transponder_dispatch_indexes(nil, record.force_index, record.platform_index, record.dispatch_surface_name, record.hub_unit_number, record.unit_number)
  root.transponders_by_unit[unit_number] = nil
  cohort_power.destroy(unit_number, PLATFORM_TRANSPONDER_NAME)
  rebuild_force_platform_claims(record.force_index)
  mark_cohort_dirty(record.force_index, record.surface_name)
  if record.dispatch_surface_name and record.dispatch_surface_name ~= record.surface_name then
    mark_cohort_dirty(record.force_index, record.dispatch_surface_name)
  end
  return true
end

local function set_transponder_manual_platform_id(unit_number, platform_id, current_tick)
  local root = get_root()
  local record = root.transponders_by_unit[unit_number]
  if not record then
    return nil, false
  end

  local current_manual_platform_id = tonumber(record.manual_platform_id) or nil
  local next_manual_platform_id = normalize_platform_id_input(platform_id)
  if current_manual_platform_id == next_manual_platform_id
    and (next_manual_platform_id ~= nil or tonumber(record.platform_id) ~= nil)
  then
    -- Reapplying the same override, or clearing an already-auto-assigned ID,
    -- should not reshuffle platform identity or dirty the cohort.
    return record, false
  end

  record.manual_platform_id = next_manual_platform_id
  if record.manual_platform_id then
    record.platform_id = record.manual_platform_id
  else
    record.platform_id = nil
  end
  record.last_seen_tick = now_tick(current_tick)
  ensure_transponder_platform_id(record)
  mark_cohort_dirty(record.force_index, record.surface_name)
  if record.dispatch_surface_name and record.dispatch_surface_name ~= record.surface_name then
    mark_cohort_dirty(record.force_index, record.dispatch_surface_name)
  end
  return record, true
end

local function register_selector(entity, current_tick)
  if not ei_lib.entity_check(entity) then
    return nil
  end

  local root = get_root()
  local record = root.selectors_by_unit[entity.unit_number] or {}
  record.entity = entity
  record.unit_number = entity.unit_number
  record.force_index = entity.force.index
  record.surface_name = entity.surface.name
  record.mode = normalize_selector_mode(record.mode)
  record.manual_platform_id = tonumber(record.manual_platform_id) or nil
  record.last_seen_tick = now_tick(current_tick)
  root.selectors_by_unit[entity.unit_number] = record
  cohort_power.ensure(entity, current_tick)
  cohort_power.set_cached_state(entity.unit_number, cohort_power.get_live_state(entity, current_tick))
  cohort_power.apply_visible_status(entity, cohort_power.get_cached_state(entity.unit_number))
  ensure_cohort(record.force_index, record.surface_name).selector_units[entity.unit_number] = true
  mark_cohort_dirty(record.force_index, record.surface_name)
  return record
end

local function remove_selector(unit_number)
  local root = get_root()
  local record = root.selectors_by_unit[unit_number]
  if not record then
    return false
  end

  local cohort = root.cohorts[cohort_key(record.force_index, record.surface_name)]
  if cohort then
    cohort.selector_units[unit_number] = nil
  end
  root.selectors_by_unit[unit_number] = nil
  cohort_power.destroy(unit_number, ORBITAL_SELECTOR_NAME)
  local lease = root.lease_by_job_id[unit_number]
  if lease then
    local uplink_record = lease.uplink_unit_number and root.uplinks_by_unit[lease.uplink_unit_number] or nil
    if uplink_record then
      root.lease_by_uplink_unit[uplink_record.unit_number] = nil
      uplink_record.leased_job_id = nil
    end
    root.lease_by_job_id[unit_number] = nil
  end
  mark_cohort_dirty(record.force_index, record.surface_name)
  return true
end

local function register_coordinator(entity, current_tick)
  if not ei_lib.entity_check(entity) then
    return nil
  end

  local root = get_root()
  local record = root.coordinators_by_unit[entity.unit_number] or {}
  record.entity = entity
  record.unit_number = entity.unit_number
  record.force_index = entity.force.index
  record.surface_name = entity.surface.name
  record.last_seen_tick = now_tick(current_tick)
  root.coordinators_by_unit[entity.unit_number] = record
  cohort_power.ensure(entity, current_tick)
  cohort_power.set_cached_state(entity.unit_number, cohort_power.get_live_state(entity, current_tick))
  cohort_power.apply_visible_status(entity, cohort_power.get_cached_state(entity.unit_number))
  ensure_cohort(record.force_index, record.surface_name).coordinator_units[entity.unit_number] = true
  mark_cohort_dirty(record.force_index, record.surface_name)
  return record
end

local function remove_coordinator(unit_number)
  local root = get_root()
  local record = root.coordinators_by_unit[unit_number]
  if not record then
    return false
  end

  local cohort = root.cohorts[cohort_key(record.force_index, record.surface_name)]
  if cohort then
    cohort.coordinator_units[unit_number] = nil
  end
  root.coordinators_by_unit[unit_number] = nil
  cohort_power.destroy(unit_number, ORBITAL_COORDINATOR_NAME)
  mark_cohort_dirty(record.force_index, record.surface_name)
  return true
end

local function find_adjacent_silos(entity)
  if not ei_lib.entity_check(entity) then
    return {}
  end

  -- The uplink is intentionally compact relative to a rocket silo, so allow a
  -- little breathing room for real pad layouts instead of requiring near-zero
  -- gap center-to-center placement.
  local radius = 8
  local candidates = entity.surface.find_entities_filtered{
    area = {
      {entity.position.x - radius, entity.position.y - radius},
      {entity.position.x + radius, entity.position.y + radius},
    },
    force = entity.force,
    type = "rocket-silo",
  }

  table.sort(candidates, function(left, right)
    local left_distance = (left.position.x - entity.position.x) ^ 2 + (left.position.y - entity.position.y) ^ 2
    local right_distance = (right.position.x - entity.position.x) ^ 2 + (right.position.y - entity.position.y) ^ 2
    if left_distance == right_distance then
      return (left.unit_number or 0) < (right.unit_number or 0)
    end
    return left_distance < right_distance
  end)

  return candidates
end

local function invalidate_uplink_dropdown_cache(record)
  if type(record) ~= "table" then
    return false
  end

  local cache = record.silo_dropdown_cache
  if type(cache) ~= "table" then
    record.silo_dropdown_cache = nil
    return false
  end

  record.silo_dropdown_cache = nil
  return true
end

local function invalidate_surface_uplink_dropdown_caches(force_index, surface_name)
  if not (force_index and surface_name) then
    return false
  end

  -- Binding ownership or silo topology changes affect every uplink dropdown on
  -- the surface, but we can invalidate lazily with a generation token instead
  -- of scanning every uplink record just to clear caches eagerly.
  bump_surface_uplink_dropdown_generation(force_index, surface_name)
  return true
end

local function remember_bound_silo(record, silo)
  if not record then
    return nil
  end

  if ei_lib.entity_check(silo) and silo.type == "rocket-silo" then
    record.binding_silo_entity = silo
    record.binding_silo_unit_number = silo.unit_number or record.binding_silo_unit_number
    return silo
  end

  record.binding_silo_entity = nil
  return nil
end

local function get_bound_silo(record)
  local unit_number = record and record.binding_silo_unit_number or nil
  if not unit_number then
    return nil
  end

  local cached_silo = record and record.binding_silo_entity or nil
  if ei_lib.entity_check(cached_silo)
    and cached_silo.type == "rocket-silo"
    and (cached_silo.unit_number == nil or cached_silo.unit_number == unit_number)
  then
    return remember_bound_silo(record, cached_silo)
  end

  local silo = get_entity_by_unit_number(unit_number)
  if ei_lib.entity_check(silo) and silo.type == "rocket-silo" then
    return remember_bound_silo(record, silo)
  end

  local entity = get_record_entity(record)
  if entity then
    for _, candidate in ipairs(find_adjacent_silos(entity)) do
      if candidate.unit_number == unit_number then
        return remember_bound_silo(record, candidate)
      end
    end
  end

  return nil
end

-- Uplink binding reads are repeated during one cohort service pass, so keep a
-- tiny per-pass cache keyed by uplink unit number instead of rewalking the same
-- entity lookup path during reconcile and output render.
local function get_bound_silo_for_service_pass(record, bound_silo_by_unit_number)
  if not record then
    return nil
  end

  if type(bound_silo_by_unit_number) ~= "table" then
    return get_bound_silo(record)
  end

  local unit_number = record.unit_number
  if not unit_number then
    return get_bound_silo(record)
  end

  local cached = bound_silo_by_unit_number[unit_number]
  if cached ~= nil then
    return cached or nil
  end

  local bound_silo = get_bound_silo(record)
  bound_silo_by_unit_number[unit_number] = bound_silo or false
  return bound_silo
end

-- Cohort panel refreshes often already know the entity, root, and sometimes
-- a per-pass silo cache. Seed that once so open-panel work does not keep
-- re-deriving the same per-entity record handoff.
local function seed_panel_context(panel_context, entity, root_state, cohort, bound_silo_by_unit_number)
  if type(panel_context) ~= "table" then
    panel_context = {}
  end
  if not ei_lib.entity_check(entity) then
    return panel_context
  end

  root_state = root_state or panel_context.root_state or get_root()
  panel_context.entity = entity
  panel_context.root_state = panel_context.root_state or root_state
  if cohort ~= nil then
    panel_context.cohort = panel_context.cohort or cohort
  end

  if entity.name == PLATFORM_TRANSPONDER_NAME then
    if panel_context.transponder_record == nil then
      panel_context.transponder_record = root_state.transponders_by_unit[entity.unit_number]
    end
  elseif entity.name == ORBITAL_SELECTOR_NAME then
    if panel_context.selector_record == nil then
      panel_context.selector_record = root_state.selectors_by_unit[entity.unit_number]
    end
    if panel_context.selector_lease == nil then
      panel_context.selector_lease = root_state.lease_by_job_id[entity.unit_number]
    end
  elseif entity.name == ORBITAL_COORDINATOR_NAME then
    if panel_context.coordinator_refresh_pending == nil then
      panel_context.coordinator_refresh_pending = is_cohort_queue_pending(entity.force.index, entity.surface.name)
    end
    if panel_context.coordinator_rescan_pending == nil then
      panel_context.coordinator_rescan_pending = is_runtime_rescan_pending()
    end
  elseif entity.name == ORBITAL_DISPATCH_UPLINK_NAME then
    if panel_context.uplink_record == nil then
      panel_context.uplink_record = root_state.uplinks_by_unit[entity.unit_number]
    end
    if panel_context.bound_silo == nil then
      local bound_silo = type(bound_silo_by_unit_number) == "table"
        and get_bound_silo_for_service_pass(panel_context.uplink_record, bound_silo_by_unit_number)
        or get_bound_silo(panel_context.uplink_record)
      panel_context.bound_silo = bound_silo or false
    end
  end

  return panel_context
end

local function get_uplink_binding_owner_unit_number(binding_silo_unit_number)
  if not binding_silo_unit_number then
    return nil
  end

  return get_root().uplink_by_silo_unit[binding_silo_unit_number]
end

local function clear_uplink_runtime_binding(record, release_lease)
  if not record then
    return false
  end

  local changed = false
  local root = get_root()
  if release_lease and record.leased_job_id then
    root.lease_by_job_id[record.leased_job_id] = nil
    root.lease_by_uplink_unit[record.unit_number] = nil
    record.leased_job_id = nil
    changed = true
  end

  if record.binding_silo_unit_number and root.uplink_by_silo_unit[record.binding_silo_unit_number] == record.unit_number then
    root.uplink_by_silo_unit[record.binding_silo_unit_number] = nil
    changed = true
  end

  changed = record.binding_silo_unit_number ~= nil or record.binding_source ~= nil or changed
  record.binding_silo_unit_number = nil
  record.binding_silo_entity = nil
  record.binding_source = nil
  invalidate_uplink_dropdown_cache(record)
  if changed then
    invalidate_surface_uplink_dropdown_caches(record.force_index, record.surface_name)
    touch_cohort_signature_generation(record.force_index, record.surface_name)
  end
  return changed
end

local function sync_uplink_silo_index(record)
  local root = get_root()

  for silo_unit_number, uplink_unit_number in pairs(root.uplink_by_silo_unit) do
    if uplink_unit_number == record.unit_number and silo_unit_number ~= record.binding_silo_unit_number then
      root.uplink_by_silo_unit[silo_unit_number] = nil
    end
  end

  if record.binding_silo_unit_number then
    root.uplink_by_silo_unit[record.binding_silo_unit_number] = record.unit_number
  end
end

local function find_preferred_adjacent_silo(entity, current_unit_number)
  for _, silo in ipairs(find_adjacent_silos(entity)) do
    local owner_unit_number = get_uplink_binding_owner_unit_number(silo.unit_number)
    if owner_unit_number == nil or owner_unit_number == current_unit_number then
      return silo
    end
  end

  return nil
end

local function register_uplink(entity, current_tick)
  if not ei_lib.entity_check(entity) then
    return nil
  end

  local root = get_root()
  local record = root.uplinks_by_unit[entity.unit_number] or {}
  record.entity = entity
  record.unit_number = entity.unit_number
  record.force_index = entity.force.index
  record.surface_name = entity.surface.name
  record.oversize_mode = normalize_oversize_mode(record.oversize_mode)
  record.threshold_floor = math.max(0, tonumber(record.threshold_floor) or 0)
  record.leased_job_id = tonumber(record.leased_job_id) or nil
  record.last_seen_tick = now_tick(current_tick)
  invalidate_uplink_dropdown_cache(record)
  root.uplinks_by_unit[entity.unit_number] = record
  cohort_power.ensure(entity, current_tick)
  cohort_power.set_cached_state(entity.unit_number, cohort_power.get_live_state(entity, current_tick))
  cohort_power.apply_visible_status(entity, cohort_power.get_cached_state(entity.unit_number))

  if not record.binding_silo_unit_number then
    local nearest = find_preferred_adjacent_silo(entity, entity.unit_number)
    if nearest then
      record.binding_silo_unit_number = nearest.unit_number
      record.binding_silo_entity = nearest
      record.binding_source = "adjacent"
    end
  else
    local owner_unit_number = get_uplink_binding_owner_unit_number(record.binding_silo_unit_number)
    if owner_unit_number and owner_unit_number ~= record.unit_number then
      local owner_record = root.uplinks_by_unit[owner_unit_number]
      if owner_record and owner_record.unit_number and owner_record.unit_number < record.unit_number then
        clear_uplink_runtime_binding(record, true)
      else
        clear_uplink_runtime_binding(owner_record, true)
        if owner_record then
          mark_cohort_dirty(owner_record.force_index, owner_record.surface_name)
        end
      end
    end
  end

  sync_uplink_silo_index(record)
  ensure_cohort(record.force_index, record.surface_name).uplink_units[entity.unit_number] = true
  mark_cohort_dirty(record.force_index, record.surface_name)
  return record
end

local function remove_uplink(unit_number)
  local root = get_root()
  local record = root.uplinks_by_unit[unit_number]
  if not record then
    return false
  end

  clear_uplink_runtime_binding(record, true)
  root.lease_by_uplink_unit[unit_number] = nil
  local cohort = root.cohorts[cohort_key(record.force_index, record.surface_name)]
  if cohort then
    cohort.uplink_units[unit_number] = nil
  end
  root.uplinks_by_unit[unit_number] = nil
  cohort_power.destroy(unit_number, ORBITAL_DISPATCH_UPLINK_NAME)
  mark_cohort_dirty(record.force_index, record.surface_name)
  return true
end

local function set_uplink_binding(unit_number, silo_unit_number, source)
  local root = get_root()
  local record = root.uplinks_by_unit[unit_number]
  if not record then
    return nil, false
  end

  local next_silo_unit_number = tonumber(silo_unit_number) or nil
  local next_binding_source = next_silo_unit_number and (source or "manual") or nil
  local current_silo_unit_number = tonumber(record.binding_silo_unit_number) or nil
  if current_silo_unit_number == next_silo_unit_number
    and record.binding_source == next_binding_source
    and (next_silo_unit_number == nil or get_uplink_binding_owner_unit_number(next_silo_unit_number) == unit_number)
    and (next_silo_unit_number ~= nil or record.leased_job_id == nil)
  then
    -- Reconfirming the same silo binding should not churn caches or dirty the cohort.
    return record, false
  end

  local next_silo = next_silo_unit_number and get_entity_by_unit_number(next_silo_unit_number) or nil
  if next_silo_unit_number then
    local owner_unit_number = get_uplink_binding_owner_unit_number(next_silo_unit_number)
    if owner_unit_number and owner_unit_number ~= unit_number then
      local owner_record = root.uplinks_by_unit[owner_unit_number]
      clear_uplink_runtime_binding(owner_record, true)
      if owner_record then
        mark_cohort_dirty(owner_record.force_index, owner_record.surface_name)
      end
    end
  end

  clear_uplink_runtime_binding(record, next_silo_unit_number == nil)
  record.binding_silo_unit_number = next_silo_unit_number
  record.binding_silo_entity = nil
  if next_silo_unit_number then
    if next_silo and next_silo.type == "rocket-silo" then
      remember_bound_silo(record, next_silo)
    else
      local entity = get_record_entity(record)
      if entity then
        for _, candidate in ipairs(find_adjacent_silos(entity)) do
          if candidate.unit_number == next_silo_unit_number then
            remember_bound_silo(record, candidate)
            break
          end
        end
      end
    end
  end
  record.binding_source = next_binding_source
  invalidate_uplink_dropdown_cache(record)
  invalidate_surface_uplink_dropdown_caches(record.force_index, record.surface_name)
  sync_uplink_silo_index(record)
  mark_cohort_dirty(record.force_index, record.surface_name)
  return record, true
end

local function set_uplink_oversize_mode(unit_number, oversize_mode, threshold_floor, current_tick)
  local root = get_root()
  local record = root.uplinks_by_unit[unit_number]
  if not record then
    return nil, false
  end

  local next_oversize_mode = normalize_oversize_mode(oversize_mode)
  local next_threshold_floor = threshold_floor ~= nil
    and normalize_threshold_floor_input(threshold_floor)
    or normalize_threshold_floor_input(record.threshold_floor)
  if record.oversize_mode == next_oversize_mode
    and normalize_threshold_floor_input(record.threshold_floor) == next_threshold_floor
  then
    return record, false
  end

  record.oversize_mode = next_oversize_mode
  record.threshold_floor = next_threshold_floor
  record.last_seen_tick = now_tick(current_tick)
  mark_cohort_dirty(record.force_index, record.surface_name)
  return record, true
end

local function get_dispatch_surface_transponder_records(force_index, dispatch_surface_name)
  local root = get_root()
  local records = {}
  local indexed_units = root.transponder_units_by_dispatch_surface[force_index]
  indexed_units = indexed_units and indexed_units[dispatch_surface_name] or nil

  -- Registry construction is on the hot service path, so narrow the candidate
  -- set to transponders already known to target this dispatch surface instead
  -- of sweeping the entire force every time one cohort wakes up.
  for unit_number in pairs(indexed_units or EMPTY_FILTERS) do
    local record = root.transponders_by_unit[unit_number]
    if record then
      records[#records + 1] = record
    end
  end

  return sort_records_by_unit(records)
end

local function get_platform_transponder_records(force_index, platform_index)
  local root = get_root()
  local records = {}
  local indexed_units = root.transponder_units_by_platform[force_index]
  indexed_units = indexed_units and indexed_units[platform_index] or nil

  -- Platform-state refreshes only need transponders already bound to the
  -- touched platform, not the entire force-wide transponder map.
  for unit_number in pairs(indexed_units or EMPTY_FILTERS) do
    local record = root.transponders_by_unit[unit_number]
    if record then
      records[#records + 1] = record
    end
  end

  return sort_records_by_unit(records)
end

local function build_transponder_platform_registry(force_index, dispatch_surface_name)
  local registry = {
    by_id = {},
    ordered = {},
  }

  for _, record in ipairs(get_dispatch_surface_transponder_records(force_index, dispatch_surface_name)) do
    local entity = get_record_entity(record)
    local platform = entity and read_platform_from_transponder(entity) or nil
    if entity
      and cohort_power.record_has_active_power(record)
      and platform
      and platform.valid
      and record.force_index == force_index
    then
      local previous_platform_name = record.platform_name
      local previous_force_index = record.force_index
      local previous_platform_index = record.platform_index
      local previous_dispatch_surface_name = record.dispatch_surface_name
      local previous_hub_unit_number = record.hub_unit_number
      record.platform_index = platform.index
      record.platform_name = platform.name
      record.dispatch_surface_name = get_platform_surface_name(platform)
      record.hub_unit_number = platform.hub and platform.hub.valid and platform.hub.unit_number or nil
      sync_transponder_dispatch_indexes(record, previous_force_index, previous_platform_index, previous_dispatch_surface_name, previous_hub_unit_number)
      ensure_transponder_platform_id(record)
      if previous_dispatch_surface_name ~= record.dispatch_surface_name
        or previous_hub_unit_number ~= record.hub_unit_number
        or previous_platform_name ~= record.platform_name
      then
        mark_cohort_dirty(record.force_index, record.surface_name)
        if previous_dispatch_surface_name and previous_dispatch_surface_name ~= record.surface_name then
          mark_cohort_dirty(record.force_index, previous_dispatch_surface_name)
        end
        if record.dispatch_surface_name and record.dispatch_surface_name ~= record.surface_name then
          mark_cohort_dirty(record.force_index, record.dispatch_surface_name)
        end
      end

      if not record.conflict
        and record.platform_id
        and record.dispatch_surface_name == dispatch_surface_name
      then
        local entry = registry.by_id[record.platform_id]
        if not entry then
          entry = {
            platform_id = record.platform_id,
            platform = platform,
            platform_index = platform.index,
            platform_name = platform.name,
            transponder_units = {},
          }
          registry.by_id[record.platform_id] = entry
          registry.ordered[#registry.ordered + 1] = entry
        end
        entry.transponder_units[#entry.transponder_units + 1] = record.unit_number
      end
    end
  end

  table.sort(registry.ordered, function(left, right)
    return (left.platform_id or 0) < (right.platform_id or 0)
  end)

  return registry
end

local function get_service_pass_registry(cohort, current_tick, service_pass_cache)
  if service_pass_cache and service_pass_cache.transponder_registry then
    return service_pass_cache.transponder_registry
  end

  local registry = build_transponder_platform_registry(cohort.force_index, cohort.surface_name)
  -- Keep the registry cache scoped to one service pass only. The retry after
  -- lease cleanup can reuse the same refreshed transponder view, but nothing
  -- here should survive into a later tick or a different cohort.
  if service_pass_cache then
    service_pass_cache.transponder_registry = registry
  end

  return registry
end

local function manifest_from_payload(payload)
  local manifest = {}
  local total_count = 0
  local filters = payload and payload.filters or EMPTY_FILTERS

  for _, filter in ipairs(filters) do
    local amount = math.max(0, tonumber(filter.min) or 0)
    if amount > 0 then
      manifest[#manifest + 1] = {
        value = copy_signal_id(filter.value),
        min = amount,
        max = nil,
      }
      total_count = total_count + amount
    end
  end

  table.sort(manifest, function(left, right)
    return signal_key(left.value) < signal_key(right.value)
  end)

  return manifest, total_count
end

local function get_platform_need_entry(registry_entry, current_tick, service_pass_cache)
  if not registry_entry or not registry_entry.platform or not registry_entry.platform.valid then
    return nil
  end

  local cache_key = service_pass_cache_key(registry_entry.platform, get_mode_name_need(), current_tick)
  if service_pass_cache and cache_key then
    local cached_entry = service_pass_cache.platform_need_entries[cache_key]
    if cached_entry ~= nil then
      return cached_entry or nil
    end
  end

  local payload = get_platform_mode_payload(registry_entry.platform, get_mode_name_need(), current_tick, service_pass_cache)
  if not payload then
    if service_pass_cache and cache_key then
      service_pass_cache.platform_need_entries[cache_key] = false
    end
    return nil
  end

  local manifest, total_count = manifest_from_payload(payload)
  local entry = {
    platform_id = registry_entry.platform_id,
    platform = registry_entry.platform,
    platform_name = payload.platform_name or registry_entry.platform_name,
    manifest = manifest,
    manifest_signature = build_filters_signature(manifest),
    total_count = total_count,
    payload = payload,
  }

  if service_pass_cache and cache_key then
    service_pass_cache.platform_need_entries[cache_key] = entry
  end

  return entry
end

local function read_signal_value(entity, signal)
  if not ei_lib.entity_check(entity) then
    return 0
  end

  local total = 0
  local seen_networks = {}
  local ok, connectors = pcall(entity.get_wire_connectors, false)
  if not ok or type(connectors) ~= "table" then
    return 0
  end

  for connector_id, connector in pairs(connectors) do
    if connector and connector.valid then
      local network_ok, network = pcall(entity.get_circuit_network, connector_id)
      if network_ok and network and not seen_networks[network.network_id] then
        seen_networks[network.network_id] = true
        local value_ok, value = pcall(network.get_signal, signal)
        if value_ok and value then
          total = total + value
        end
      end
    end
  end

  return total
end

local function signal_ids_match(left, right)
  if not left or not right then
    return false
  end

  return (left.type or "item") == (right.type or "item")
    and (left.name or "") == (right.name or "")
    and (left.quality or "normal") == (right.quality or "normal")
end

local function read_entity_output_signal_value(entity, signal)
  if not ei_lib.entity_check(entity) or not signal then
    return 0
  end

  local control = entity.get_control_behavior()
  if not control or not control.valid then
    return 0
  end

  local total = 0
  for section_index = 1, control.sections_count do
    local section = control.get_section(section_index)
    if section and section.active ~= false then
      for slot_index = 1, section.filters_count do
        local slot = section.get_slot(slot_index)
        if slot and signal_ids_match(slot.value, signal) then
          total = total + math.max(0, math.floor(tonumber(slot.min) or 0))
        end
      end
    end
  end

  return total
end

local function read_external_signal_value(entity, signal)
  -- Selector circuit mode should react to upstream platform-ID signals, not the
  -- selector's own published status page echoing back through the same network.
  return math.max(0, read_signal_value(entity, signal) - read_entity_output_signal_value(entity, signal))
end

local function build_policy_candidate_order(cohort, need_by_id)
  local candidates = {}

  for platform_id, need_entry in pairs(need_by_id) do
    if need_entry.total_count > 0 then
      candidates[#candidates + 1] = {
        platform_id = platform_id,
        total_count = need_entry.total_count,
        last_assignment_tick = cohort.last_assignment_tick_by_platform_id[platform_id] or 0,
      }
    end
  end

  if #candidates > 1 then
    table.sort(candidates, function(left, right)
      if left.last_assignment_tick ~= right.last_assignment_tick then
        return left.last_assignment_tick < right.last_assignment_tick
      end
      if left.total_count ~= right.total_count then
        return left.total_count > right.total_count
      end
      return left.platform_id < right.platform_id
    end)
  end

  local ordered_platform_ids = {}
  for index = 1, #candidates do
    ordered_platform_ids[index] = candidates[index].platform_id
  end

  return ordered_platform_ids
end

local function choose_policy_platform_id(policy_candidate_order, need_by_id, reserved_platform_ids, current_target_platform_id)
  for _, platform_id in ipairs(policy_candidate_order or EMPTY_FILTERS) do
    local need_entry = need_by_id[platform_id]
    -- Policy selectors should be able to keep their own in-flight lease target
    -- while priority selectors reshuffle around them. The precomputed order is
    -- safe to reuse because only the live reservation check is selector-specific.
    if need_entry and need_entry.total_count > 0
      and (not reserved_platform_ids[platform_id] or platform_id == current_target_platform_id)
    then
      return platform_id
    end
  end

  return nil
end

local function build_selector_job(record, registry, need_by_id, reserved_platform_ids, policy_candidate_order, current_tick, service_pass_cache)
  local entity = get_record_entity(record)
  if not entity then
    return {
      job_id = record.unit_number,
      selector_unit_number = record.unit_number,
      state = "invalid",
      invalid_reason = "missing-selector",
    }
  end

  if not cohort_power.record_has_active_power(record) then
    return {
      job_id = record.unit_number,
      selector_unit_number = record.unit_number,
      force_index = record.force_index,
      surface_name = record.surface_name,
      mode = normalize_selector_mode(record.mode),
      target_platform_id = nil,
      manifest = EMPTY_FILTERS,
      manifest_signature = EMPTY_FILTERS_SIGNATURE,
      total_count = 0,
      state = "blocked",
      blocked_reason = "no-power",
      invalid_reason = nil,
      platform_name = nil,
    }
  end

  local mode = normalize_selector_mode(record.mode)
  local target_platform_id = nil
  local current_lease = get_root().lease_by_job_id[record.unit_number]

  if mode == MODE_MANUAL then
    target_platform_id = tonumber(record.manual_platform_id) or nil
  elseif mode == MODE_CIRCUIT then
    target_platform_id = math.floor(read_external_signal_value(entity, PLATFORM_ID_SIGNAL))
    if target_platform_id <= 0 then
      target_platform_id = nil
    end
  else
    target_platform_id = choose_policy_platform_id(
      policy_candidate_order,
      need_by_id,
      reserved_platform_ids,
      current_lease and current_lease.target_platform_id or nil
    )
  end

  local job = {
    job_id = record.unit_number,
    selector_unit_number = record.unit_number,
    force_index = record.force_index,
    surface_name = record.surface_name,
    mode = mode,
    target_platform_id = target_platform_id,
    manifest = EMPTY_FILTERS,
    manifest_signature = EMPTY_FILTERS_SIGNATURE,
    total_count = 0,
    state = "blocked",
    blocked_reason = "no-target",
    invalid_reason = nil,
    platform_name = nil,
  }

  if not target_platform_id then
    return job
  end

  local registry_entry = registry.by_id[target_platform_id]
  if not registry_entry then
    job.state = "invalid"
    job.blocked_reason = nil
    job.invalid_reason = "unknown-platform-id"
    return job
  end

  local need_entry = need_by_id[target_platform_id] or get_platform_need_entry(registry_entry, current_tick, service_pass_cache)
  if not need_entry then
    job.state = "invalid"
    job.blocked_reason = nil
    job.invalid_reason = "missing-platform"
    return job
  end

  job.platform_name = need_entry.platform_name
  job.manifest = need_entry.manifest
  job.manifest_signature = need_entry.manifest_signature
  job.total_count = need_entry.total_count
  local target_is_reserved = reserved_platform_ids and reserved_platform_ids[target_platform_id] == true or false
  local owns_current_target = current_lease and current_lease.target_platform_id == target_platform_id
  if need_entry.total_count > 0 and target_is_reserved and not owns_current_target then
    job.blocked_reason = "platform-busy"
  elseif need_entry.total_count > 0 then
    job.state = "ready"
    job.blocked_reason = nil
  else
    job.blocked_reason = "no-demand"
  end

  return job
end

local function choose_active_coordinator(cohort)
  local candidate = nil
  for unit_number in pairs(cohort.coordinator_units or {}) do
    local record = get_root().coordinators_by_unit[unit_number]
    if record and get_record_entity(record) and cohort_power.record_has_active_power(record) then
      if not candidate or unit_number < candidate then
        candidate = unit_number
      end
    end
  end
  return candidate
end

local function release_uplink_lease(uplink_record)
  local root = get_root()
  local job_id = uplink_record and uplink_record.leased_job_id or nil
  if not job_id then
    return false
  end

  root.lease_by_job_id[job_id] = nil
  root.lease_by_uplink_unit[uplink_record.unit_number] = nil
  uplink_record.leased_job_id = nil
  touch_cohort_signature_generation(uplink_record.force_index, uplink_record.surface_name)
  return true
end

local function assign_uplink_lease(cohort, uplink_record, job, current_tick)
  local root = get_root()
  local lease = {
    lease_id = tostring(job.job_id) .. ":" .. tostring(uplink_record.unit_number) .. ":" .. tostring(now_tick(current_tick)),
    job_id = job.job_id,
    uplink_unit_number = uplink_record.unit_number,
    coordinator_unit_number = cohort.active_coordinator_unit_number,
    target_platform_id = job.target_platform_id,
    created_tick = now_tick(current_tick),
    launch_count = 0,
  }

  root.lease_by_job_id[job.job_id] = lease
  root.lease_by_uplink_unit[uplink_record.unit_number] = lease
  uplink_record.leased_job_id = job.job_id
  cohort.last_assignment_tick_by_platform_id[job.target_platform_id] = now_tick(current_tick)
  touch_cohort_signature_generation(cohort.force_index, cohort.surface_name)
end

local function compare_ready_jobs_by_fairness(cohort, left, right)
  local left_mode_priority = left.mode == MODE_MANUAL and 0 or (left.mode == MODE_CIRCUIT and 1 or 2)
  local right_mode_priority = right.mode == MODE_MANUAL and 0 or (right.mode == MODE_CIRCUIT and 1 or 2)
  if left_mode_priority ~= right_mode_priority then
    return left_mode_priority < right_mode_priority
  end

  local left_last_assignment_tick = cohort.last_assignment_tick_by_platform_id[left.target_platform_id] or 0
  local right_last_assignment_tick = cohort.last_assignment_tick_by_platform_id[right.target_platform_id] or 0
  if left_last_assignment_tick ~= right_last_assignment_tick then
    return left_last_assignment_tick < right_last_assignment_tick
  end
  if left.total_count ~= right.total_count then
    return left.total_count > right.total_count
  end
  if left.target_platform_id ~= right.target_platform_id then
    return left.target_platform_id < right.target_platform_id
  end
  return left.job_id < right.job_id
end

local function build_registry_target_lease_counts(registry)
  local root = get_root()
  local target_lease_counts = {}

  -- One service pass only cares about lease pressure on platforms that are
  -- actually present in the current dispatch-surface registry.
  for _, lease in pairs(root.lease_by_job_id) do
    local target_platform_id = lease and lease.target_platform_id or nil
    if target_platform_id and registry.by_id[target_platform_id] then
      target_lease_counts[target_platform_id] = (target_lease_counts[target_platform_id] or 0) + 1
    end
  end

  return target_lease_counts
end

local function build_candidate_jobs(cohort, current_tick, service_pass_cache)
  local registry = get_service_pass_registry(cohort, current_tick, service_pass_cache)
  local root = get_root()
  local target_lease_counts = build_registry_target_lease_counts(registry)
  local selector_records = {}
  for unit_number in pairs(cohort.selector_units or {}) do
    local record = root.selectors_by_unit[unit_number]
    if record then
      selector_records[#selector_records + 1] = record
    end
  end
  sort_records_by_unit(selector_records)

  if #selector_records == 0 then
    return registry, {}, EMPTY_FILTERS, target_lease_counts, 0, 0, 0
  end

  local reserved_platform_ids = {}
  for target_platform_id in pairs(target_lease_counts) do
    reserved_platform_ids[target_platform_id] = true
  end

  local need_by_id = {}
  local needs_policy_scan = false
  local priority_selector_records = {}
  local policy_selector_records = {}
  for _, record in ipairs(selector_records) do
    if normalize_selector_mode(record.mode) == MODE_POLICY then
      needs_policy_scan = true
      policy_selector_records[#policy_selector_records + 1] = record
    else
      priority_selector_records[#priority_selector_records + 1] = record
    end
  end

  if needs_policy_scan then
    for platform_id, registry_entry in pairs(registry.by_id) do
      need_by_id[platform_id] = get_platform_need_entry(registry_entry, current_tick, service_pass_cache)
    end
  end

  -- This order only depends on cohort age and platform need, so every policy
  -- selector can reuse it while still applying its own live reservation filter.
  local policy_candidate_order = needs_policy_scan and build_policy_candidate_order(cohort, need_by_id) or EMPTY_FILTERS

  local jobs_by_id = {}
  local ready_jobs = {}
  local ready_job_count = 0
  local blocked_job_count = 0
  local invalid_job_count = 0
  local function stage_selector_job(job)
    jobs_by_id[job.job_id] = job
    if job.state == "ready" then
      ready_job_count = ready_job_count + 1
      if job.target_platform_id then
        reserved_platform_ids[job.target_platform_id] = true
        ready_jobs[#ready_jobs + 1] = job
      end
    elseif job.state == "invalid" then
      invalid_job_count = invalid_job_count + 1
    else
      blocked_job_count = blocked_job_count + 1
    end
  end
  -- Manual and circuit selectors stay ahead of policy selectors, but they still
  -- need to respect already leased or earlier reserved targets so the visible
  -- selector state matches the arbiter's actual lease rules.
  for _, record in ipairs(priority_selector_records) do
    local job = build_selector_job(record, registry, need_by_id, reserved_platform_ids, policy_candidate_order, current_tick, service_pass_cache)
    stage_selector_job(job)
  end

  for _, record in ipairs(policy_selector_records) do
    local job = build_selector_job(record, registry, need_by_id, reserved_platform_ids, policy_candidate_order, current_tick, service_pass_cache)
    stage_selector_job(job)
  end

  if #ready_jobs > 1 then
    table.sort(ready_jobs, function(left, right)
      return compare_ready_jobs_by_fairness(cohort, left, right)
    end)
  end

  return registry, jobs_by_id, ready_jobs, target_lease_counts, ready_job_count, blocked_job_count, invalid_job_count
end

local function try_launch_uplink_job(cohort, uplink_record, job, registry, current_tick, bound_silo)
  local entity = get_record_entity(uplink_record)
  if not entity or not job or job.state ~= "ready" then
    return false
  end

  -- Reuse the pass-local binding answer when reconcile already resolved it for
  -- this uplink so launch does not pay for the same lookup twice in one pass.
  local silo = bound_silo ~= nil and bound_silo or get_bound_silo(uplink_record)
  if not silo then
    return false
  end

  local registry_entry = registry.by_id[job.target_platform_id]
  local platform = registry_entry and registry_entry.platform or nil
  local destination_hub = platform and platform.valid and platform.hub or nil
  if not ei_lib.entity_check(destination_hub) then
    return false
  end

  local ok, launched = pcall(silo.launch_rocket, silo, {
    type = defines.cargo_destination.station,
    station = destination_hub,
  })

  if not ok or launched ~= true then
    return false
  end

  local lease = get_root().lease_by_job_id[job.job_id]
  if lease then
    lease.launch_count = (lease.launch_count or 0) + 1
    lease.last_launch_tick = now_tick(current_tick)
  end

  uplink_record.last_launch_tick = now_tick(current_tick)
  if uplink_record.oversize_mode == OVERSIZE_SINGLE_SHOT then
    release_uplink_lease(uplink_record)
  end

  queue_cohort(cohort.force_index, cohort.surface_name)
  return true
end

local function reconcile_leases_and_uplinks(cohort, registry, jobs_by_id, ready_jobs, target_lease_counts, current_tick, service_pass_cache)
  local root = get_root()
  local blocked_lanes = {}
  local uplink_records = {}
  local released_any = false
  target_lease_counts = target_lease_counts or {}
  local bound_silo_by_unit_number = service_pass_cache and service_pass_cache.bound_silo_by_unit_number or {}

  -- Reuse the binding lookup for the whole service pass so one uplink does not
  -- pay for the same answer multiple times while we are reconciling it.
  local function get_bound_silo_for_pass(uplink_record)
    return get_bound_silo_for_service_pass(uplink_record, bound_silo_by_unit_number)
  end

  for unit_number in pairs(cohort.uplink_units or {}) do
    local record = root.uplinks_by_unit[unit_number]
    if record and get_record_entity(record) then
      uplink_records[#uplink_records + 1] = record
    end
  end
  sort_records_by_unit(uplink_records)

  local function remove_target_lease_count(target_platform_id)
    if not target_platform_id then
      return
    end

    local remaining = (target_lease_counts[target_platform_id] or 0) - 1
    if remaining > 0 then
      target_lease_counts[target_platform_id] = remaining
    else
      target_lease_counts[target_platform_id] = nil
    end
  end

  for _, uplink_record in ipairs(uplink_records) do
    local leased_job_id = uplink_record.leased_job_id
    local lease = leased_job_id and root.lease_by_job_id[leased_job_id] or nil
    local bound_silo = get_bound_silo_for_pass(uplink_record)
    if not cohort_power.record_has_active_power(uplink_record) then
      local released_lease = release_uplink_lease(uplink_record)
      released_any = released_lease or released_any
      if released_lease and lease and lease.target_platform_id then
        remove_target_lease_count(lease.target_platform_id)
      end
      blocked_lanes[uplink_record.unit_number] = "no-power"
    elseif not bound_silo then
      local released_lease = release_uplink_lease(uplink_record)
      released_any = released_lease or released_any
      if released_lease and lease and lease.target_platform_id then
        remove_target_lease_count(lease.target_platform_id)
      end
      blocked_lanes[uplink_record.unit_number] = "missing-silo-binding"
    elseif not cohort.active_coordinator_unit_number then
      local released_lease = release_uplink_lease(uplink_record)
      released_any = released_lease or released_any
      if released_lease and lease and lease.target_platform_id then
        remove_target_lease_count(lease.target_platform_id)
      end
      blocked_lanes[uplink_record.unit_number] = "no-active-coordinator"
    else
      local leased_job = leased_job_id and jobs_by_id[leased_job_id] or nil
      local released_lease = false
      if not leased_job or leased_job.state ~= "ready" then
        released_lease = release_uplink_lease(uplink_record)
      elseif lease and lease.target_platform_id ~= leased_job.target_platform_id then
        -- Selector retargets, policy reassignments, or registry drift should
        -- converge in the same service pass instead of keeping a stale lease
        -- alive until some later wakeup happens to revisit the cohort.
        released_lease = release_uplink_lease(uplink_record)
      elseif uplink_record.oversize_mode == OVERSIZE_THRESHOLD
        and leased_job.total_count <= math.max(0, tonumber(uplink_record.threshold_floor) or 0)
      then
        released_lease = release_uplink_lease(uplink_record)
      end

      released_any = released_lease or released_any
      if released_lease and lease and lease.target_platform_id then
        remove_target_lease_count(lease.target_platform_id)
      end
    end
  end

  local candidate_jobs = {}
  local queued_platform_ids = {}
  for _, job in ipairs(ready_jobs or EMPTY_FILTERS) do
    if job.state == "ready"
      and not root.lease_by_job_id[job.job_id]
      and (target_lease_counts[job.target_platform_id] or 0) == 0
      and not queued_platform_ids[job.target_platform_id]
    then
      candidate_jobs[#candidate_jobs + 1] = job
      queued_platform_ids[job.target_platform_id] = true
    end
  end

  local candidate_index = 1
  for _, uplink_record in ipairs(uplink_records) do
    local bound_silo = get_bound_silo_for_pass(uplink_record)
    if not uplink_record.leased_job_id and bound_silo and cohort.active_coordinator_unit_number then
      local job = candidate_jobs[candidate_index]
      if job then
        candidate_index = candidate_index + 1
        assign_uplink_lease(cohort, uplink_record, job, current_tick)
      else
        blocked_lanes[uplink_record.unit_number] = blocked_lanes[uplink_record.unit_number] or "no-ready-job"
      end
    end
  end

  for _, uplink_record in ipairs(uplink_records) do
    local job = uplink_record.leased_job_id and jobs_by_id[uplink_record.leased_job_id] or nil
    local bound_silo = get_bound_silo_for_pass(uplink_record)
    if job and job.state == "ready" and bound_silo then
      try_launch_uplink_job(cohort, uplink_record, job, registry, current_tick, bound_silo)
    end
  end

  cohort.blocked_lanes = blocked_lanes
  return released_any
end

local function split_pages(label, filters, slot_capacity)
  local pages = {}
  local total = #filters
  local page_count = math.max(1, math.ceil(total / slot_capacity))

  for page_index = 1, page_count do
    local start_index = ((page_index - 1) * slot_capacity) + 1
    local stop_index = math.min(start_index + slot_capacity - 1, total)
    if total == 0 then
      start_index = 1
      stop_index = 0
    end

    local page_filters = {}
    for index = start_index, stop_index do
      page_filters[#page_filters + 1] = filters[index]
    end

    local page_label = label
    if page_index > 1 then
      page_label = string.format("%s [%d/%d]", label, page_index, page_count)
    end
    pages[#pages + 1] = {label = page_label, filters = page_filters}
  end

  return pages
end

local function build_output_pages(status_label, status_filters, manifest_label, manifest_filters, slot_capacity)
  local pages = split_pages(status_label, status_filters or EMPTY_FILTERS, slot_capacity)
  local manifest_pages = split_pages(manifest_label, manifest_filters or EMPTY_FILTERS, slot_capacity)
  for _, page in ipairs(manifest_pages) do
    pages[#pages + 1] = page
  end
  return pages
end

local function filters_match(slot, filter)
  if not slot or not slot.value then
    return false
  end

  local current_signal = copy_signal_id(slot.value)
  local expected_signal = filter and filter.value or nil
  if not current_signal or not expected_signal then
    return false
  end

  return current_signal.type == expected_signal.type
    and current_signal.name == expected_signal.name
    and (current_signal.quality or "normal") == (expected_signal.quality or "normal")
    and slot.min == filter.min
    and slot.max == filter.max
end

local function reconcile_section(section, page)
  if section.active ~= true then
    section.active = true
  end

  if section.group ~= page.label then
    section.group = page.label
  end

  local current_count = section.filters_count
  local desired_count = #page.filters

  if current_count > desired_count then
    for index = current_count, desired_count + 1, -1 do
      section.clear_slot(index)
    end
  end

  for index, filter in ipairs(page.filters) do
    if not filters_match(section.get_slot(index), filter) then
      section.set_slot(index, {
        value = copy_signal_id(filter.value),
        min = filter.min,
        max = filter.max,
      })
    end
  end
end

local function reconcile_entity_output(entity, pages)
  if not ei_lib.entity_check(entity) then
    return false
  end

  local control = entity.get_control_behavior()
  if not control or not control.valid then
    return false
  end

  while control.sections_count > #pages do
    if not control.remove_section(control.sections_count) then
      return false
    end
  end

  while control.sections_count < #pages do
    if not control.add_section("") then
      return false
    end
  end

  for index, page in ipairs(pages) do
    local section = control.get_section(index)
    if not section then
      return false
    end
    reconcile_section(section, page)
  end

  return true
end

local function set_custom_status(entity, diode, label, power_state)
  if not ei_lib.entity_check(entity) then
    return
  end

  power_state = cohort_power.normalize_state(power_state)
  if power_state == cohort_power.state_unpowered or power_state == cohort_power.state_low_power then
    cohort_power.apply_visible_status(entity, power_state)
    return
  end

  if diode and label then
    entity.custom_status = {
      diode = diode,
      label = label,
    }
  else
    entity.custom_status = nil
  end
end

local function build_transponder_pages(record)
  local status = {}
  local entity = get_record_entity(record)
  local platform = entity and read_platform_from_transponder(entity) or nil
  local power_state = cohort_power.get_record_state(record)

  if not cohort_power.is_active_state(power_state) then
    status[#status + 1] = make_filter(INVALID_SIGNAL, 1, nil)
    set_custom_status(entity, nil, nil, power_state)
  elseif record.platform_id and not record.conflict and platform and platform.valid then
    status[#status + 1] = make_filter(PLATFORM_ID_SIGNAL, record.platform_id, nil)
    status[#status + 1] = make_filter(READY_SIGNAL, 1, nil)
    set_custom_status(entity, nil, nil, power_state)
  else
    status[#status + 1] = make_filter(INVALID_SIGNAL, 1, nil)
    if record.conflict then
      set_custom_status(entity, STATUS_RED, {"exotic-industries.orbital-logistics-status-conflict"}, power_state)
    else
      set_custom_status(entity, STATUS_YELLOW, {"exotic-industries.orbital-logistics-status-invalid"}, power_state)
    end
  end

  return split_pages("Platform ID", status, ENTITY_SLOT_CAPACITY[PLATFORM_TRANSPONDER_NAME])
end

local function build_selector_pages(record, job)
  local entity = get_record_entity(record)
  local power_state = cohort_power.get_record_state(record)
  local state_signal = job.state == "ready" and READY_SIGNAL or (job.state == "invalid" and INVALID_SIGNAL or BLOCKED_SIGNAL)
  local status = {make_filter(state_signal, 1, nil)}

  if job.target_platform_id then
    status[#status + 1] = make_filter(PLATFORM_ID_SIGNAL, job.target_platform_id, nil)
  end
  if get_root().lease_by_job_id[job.job_id] then
    status[#status + 1] = make_filter(LEASE_SIGNAL, 1, nil)
  end

  if not cohort_power.is_active_state(power_state) then
    set_custom_status(entity, nil, nil, power_state)
  elseif job.state == "ready" then
    set_custom_status(entity, nil, nil, power_state)
  elseif job.state == "invalid" then
    set_custom_status(entity, STATUS_RED, {"exotic-industries.orbital-logistics-status-invalid"}, power_state)
  else
    set_custom_status(entity, STATUS_YELLOW, {"exotic-industries.orbital-logistics-status-blocked"}, power_state)
  end

  return build_output_pages("Selector status", status, "Need preview", job.manifest or EMPTY_FILTERS, ENTITY_SLOT_CAPACITY[ORBITAL_SELECTOR_NAME])
end

local function build_coordinator_pages(record, cohort, jobs_by_id)
  local entity = get_record_entity(record)
  local power_state = cohort_power.get_record_state(record)
  local root = get_root()
  local snapshot = cohort.last_snapshot or nil
  local ready_job_count = tonumber(snapshot and snapshot.ready_job_count)
  local blocked_job_count = tonumber(snapshot and snapshot.blocked_job_count)
  local invalid_job_count = tonumber(snapshot and snapshot.invalid_job_count)

  -- Service already stages these counts in cohort.last_snapshot before the
  -- coordinator outputs render, so prefer that same-pass summary and only fall
  -- back if a rebuild path has not seeded the snapshot yet.
  if ready_job_count == nil or blocked_job_count == nil or invalid_job_count == nil then
    ready_job_count, blocked_job_count, invalid_job_count = count_jobs_by_state(jobs_by_id)
  end

  local status = {
    make_filter(READY_SIGNAL, ready_job_count, nil),
    make_filter(BLOCKED_SIGNAL, blocked_job_count, nil),
    make_filter(INVALID_SIGNAL, invalid_job_count, nil),
    make_filter(LEASE_SIGNAL, count_map(root.lease_by_uplink_unit), nil),
    -- Coordinators summarize the dispatch registry that selectors and uplinks can actually use,
    -- not the raw count of transponder entities on the coordinator's own surface.
    make_filter(PLATFORM_ID_SIGNAL, (cohort.last_snapshot and cohort.last_snapshot.registry_count) or 0, nil),
  }

  if not cohort_power.is_active_state(power_state) then
    status = {make_filter(BLOCKED_SIGNAL, 1, nil)}
    set_custom_status(entity, nil, nil, power_state)
  elseif cohort.active_coordinator_unit_number == record.unit_number then
    set_custom_status(entity, nil, nil, power_state)
  else
    set_custom_status(entity, STATUS_YELLOW, {"exotic-industries.orbital-logistics-status-standby"}, power_state)
  end

  return split_pages("Coordinator status", status, ENTITY_SLOT_CAPACITY[ORBITAL_COORDINATOR_NAME])
end

local function build_uplink_pages(entity, record, job, bound_silo)
  local power_state = cohort_power.get_record_state(record)
  local state_signal = job and job.state == "ready" and READY_SIGNAL or (job and job.state == "invalid" and INVALID_SIGNAL or BLOCKED_SIGNAL)
  local status = {make_filter(state_signal, 1, nil)}

  if job and job.target_platform_id then
    status[#status + 1] = make_filter(PLATFORM_ID_SIGNAL, job.target_platform_id, nil)
  end
  if record.leased_job_id then
    status[#status + 1] = make_filter(LEASE_SIGNAL, 1, nil)
  end

  if not cohort_power.is_active_state(power_state) then
    set_custom_status(entity, nil, nil, power_state)
  elseif not bound_silo then
    set_custom_status(entity, STATUS_RED, {"exotic-industries.orbital-logistics-status-missing-silo"}, power_state)
  elseif job and job.state == "ready" then
    set_custom_status(entity, nil, nil, power_state)
  elseif job and job.state == "invalid" then
    set_custom_status(entity, STATUS_RED, {"exotic-industries.orbital-logistics-status-invalid"}, power_state)
  else
    set_custom_status(entity, STATUS_YELLOW, {"exotic-industries.orbital-logistics-status-blocked"}, power_state)
  end

  return build_output_pages("Dispatch status", status, "Dispatch manifest", job and job.manifest or EMPTY_FILTERS, ENTITY_SLOT_CAPACITY[ORBITAL_DISPATCH_UPLINK_NAME])
end

local function build_cohort_signature(cohort, jobs_by_id)
  local hash = 5381
  local root = get_root()
  hash = hash_update(hash, cohort.force_index)
  hash = hash_update(hash, cohort.surface_name)
  hash = hash_update(hash, cohort.active_coordinator_unit_number or 0)
  hash = hash_update(hash, cohort.last_snapshot and cohort.last_snapshot.registry_count or 0)

  local transponder_records = {}
  for unit_number in pairs(cohort.transponder_units or {}) do
    local record = root.transponders_by_unit[unit_number]
    if record then
      transponder_records[#transponder_records + 1] = record
    end
  end
  sort_records_by_unit(transponder_records)

  for _, record in ipairs(transponder_records) do
    hash = hash_update(hash, record.unit_number or 0)
    hash = hash_update(hash, cohort_power.get_record_state(record))
    hash = hash_update(hash, record.platform_index or 0)
    hash = hash_update(hash, record.platform_id or 0)
    hash = hash_update(hash, record.manual_platform_id or 0)
    hash = hash_update(hash, record.conflict and 1 or 0)
    hash = hash_update(hash, record.dispatch_surface_name or "")
  end

  local jobs = {}
  for _, job in pairs(jobs_by_id or {}) do
    jobs[#jobs + 1] = job
  end
  table.sort(jobs, function(left, right)
    return (left.job_id or 0) < (right.job_id or 0)
  end)

  for _, job in ipairs(jobs) do
    hash = hash_update(hash, job.job_id)
    hash = hash_update(hash, job.state)
    hash = hash_update(hash, job.target_platform_id or 0)
    hash = hash_update(hash, job.total_count or 0)
    hash = hash_update(hash, job.manifest_signature or EMPTY_FILTERS_SIGNATURE)
    hash = hash_update(hash, job.blocked_reason or "")
    hash = hash_update(hash, job.invalid_reason or "")
    hash = hash_update(hash, job.platform_name or "")
    local lease = root.lease_by_job_id[job.job_id]
    hash = hash_update(hash, lease and lease.uplink_unit_number or 0)
    hash = hash_update(hash, lease and lease.target_platform_id or 0)
  end

  local selector_records = {}
  for unit_number in pairs(cohort.selector_units or {}) do
    local record = root.selectors_by_unit[unit_number]
    if record then
      selector_records[#selector_records + 1] = record
    end
  end
  sort_records_by_unit(selector_records)

  for _, record in ipairs(selector_records) do
    hash = hash_update(hash, record.unit_number or 0)
    hash = hash_update(hash, cohort_power.get_record_state(record))
    hash = hash_update(hash, record.mode or "")
    hash = hash_update(hash, record.manual_platform_id or 0)
  end

  local coordinator_records = {}
  for unit_number in pairs(cohort.coordinator_units or {}) do
    local record = root.coordinators_by_unit[unit_number]
    if record then
      coordinator_records[#coordinator_records + 1] = record
    end
  end
  sort_records_by_unit(coordinator_records)

  for _, record in ipairs(coordinator_records) do
    hash = hash_update(hash, record.unit_number or 0)
    hash = hash_update(hash, cohort_power.get_record_state(record))
  end

  local uplink_records = {}
  for unit_number in pairs(cohort.uplink_units or {}) do
    local record = root.uplinks_by_unit[unit_number]
    if record then
      uplink_records[#uplink_records + 1] = record
    end
  end
  sort_records_by_unit(uplink_records)

  for _, record in ipairs(uplink_records) do
    hash = hash_update(hash, record.unit_number or 0)
    hash = hash_update(hash, cohort_power.get_record_state(record))
    hash = hash_update(hash, record.binding_silo_unit_number or 0)
    hash = hash_update(hash, record.binding_source or "")
    hash = hash_update(hash, record.leased_job_id or 0)
    hash = hash_update(hash, record.oversize_mode or "")
    hash = hash_update(hash, record.threshold_floor or 0)
    hash = hash_update(hash, cohort.blocked_lanes and cohort.blocked_lanes[record.unit_number] or "")
  end

  return string.format("%08x", hash)
end

local function build_cohort_snapshot_signature(snapshot)
  -- Cohort panels surface scheduler summaries that do not always change the
  -- combinator outputs, so track GUI-visible snapshot drift separately.
  local hash = 5381
  local scanner_summary = snapshot and snapshot.scanner_summary or nil
  hash = hash_update(hash, snapshot and snapshot.ready_job_count or 0)
  hash = hash_update(hash, snapshot and snapshot.blocked_job_count or 0)
  hash = hash_update(hash, snapshot and snapshot.invalid_job_count or 0)
  hash = hash_update(hash, snapshot and snapshot.blocked_lane_count or 0)
  hash = hash_update(hash, snapshot and snapshot.registry_count or 0)
  hash = hash_update(hash, snapshot and snapshot.selector_count or 0)
  hash = hash_update(hash, snapshot and snapshot.uplink_count or 0)
  hash = hash_update(hash, scanner_summary and scanner_summary.bank_count or 0)
  hash = hash_update(hash, scanner_summary and scanner_summary.platform_count or 0)
  hash = hash_update(hash, scanner_summary and scanner_summary.hot_interest and 1 or 0)
  return string.format("%08x", hash)
end

local function render_transponder_outputs(cohort)
  local root = get_root()
  for unit_number in pairs(cohort.transponder_units or {}) do
    local record = root.transponders_by_unit[unit_number]
    local entity = record and get_record_entity(record) or nil
    if entity then
      reconcile_entity_output(entity, build_transponder_pages(record))
    end
  end
end

local function render_selector_outputs(cohort, jobs_by_id)
  local root = get_root()
  for unit_number in pairs(cohort.selector_units or {}) do
    local record = root.selectors_by_unit[unit_number]
    local entity = record and get_record_entity(record) or nil
    if entity then
      reconcile_entity_output(entity, build_selector_pages(record, jobs_by_id[unit_number] or {
        job_id = unit_number,
        state = "blocked",
        manifest = EMPTY_FILTERS,
      }))
    end
  end
end

local function render_coordinator_outputs(cohort, jobs_by_id)
  local root = get_root()
  for unit_number in pairs(cohort.coordinator_units or {}) do
    local record = root.coordinators_by_unit[unit_number]
    local entity = record and get_record_entity(record) or nil
    if entity then
      reconcile_entity_output(entity, build_coordinator_pages(record, cohort, jobs_by_id))
    end
  end
end

local function render_uplink_outputs(cohort, jobs_by_id, service_pass_cache)
  local root = get_root()
  local bound_silo_by_unit_number = service_pass_cache and service_pass_cache.bound_silo_by_unit_number or nil
  for unit_number in pairs(cohort.uplink_units or {}) do
    local record = root.uplinks_by_unit[unit_number]
    local entity = record and get_record_entity(record) or nil
    local job = record and record.leased_job_id and jobs_by_id[record.leased_job_id] or nil
    local bound_silo = record and get_bound_silo_for_service_pass(record, bound_silo_by_unit_number) or nil
    if entity then
      reconcile_entity_output(entity, build_uplink_pages(entity, record, job, bound_silo))
    end
  end
end

local function cohort_needs_dispatch_service(cohort)
  return next(cohort.selector_units or {}) ~= nil
    or next(cohort.coordinator_units or {}) ~= nil
    or next(cohort.uplink_units or {}) ~= nil
end

local function cohort_has_coordinator(cohort)
  return next(cohort and cohort.coordinator_units or EMPTY_FILTERS) ~= nil
end

local function service_cohort(cohort, current_tick)
  current_tick = now_tick(current_tick)
  cohort_power.refresh_cohort_state(cohort, current_tick)
  local service_pass_cache = {
    transponder_registry = nil,
    platform_mode_payloads = {},
    platform_need_entries = {},
    bound_silo_by_unit_number = {},
  }
  local previous_snapshot_signature = cohort.last_snapshot_signature
  local registry = {by_id = {}, ordered = {}}
  local jobs_by_id = {}
  local ready_jobs = {}
  local target_lease_counts = {}
  local ready_job_count = 0
  local blocked_job_count = 0
  local invalid_job_count = 0

  if cohort_needs_dispatch_service(cohort) then
    cohort.active_coordinator_unit_number = choose_active_coordinator(cohort)
    -- This cache lives for one service pass only, so the follow-up rebuild after
    -- lease cleanup reuses the same scanner bridge results without changing any
    -- outward selector or queue behavior.
    registry, jobs_by_id, ready_jobs, target_lease_counts, ready_job_count, blocked_job_count, invalid_job_count = build_candidate_jobs(cohort, current_tick, service_pass_cache)
    cohort.jobs_by_id = jobs_by_id
    if reconcile_leases_and_uplinks(cohort, registry, jobs_by_id, ready_jobs, target_lease_counts, current_tick, service_pass_cache) then
      -- Lease teardown can change which targets are truly available. Rebuild the
      -- cohort once in the same service pass so retargets, broken bindings, and
      -- similar drift converge immediately instead of waiting for a later wakeup.
      registry, jobs_by_id, ready_jobs, target_lease_counts, ready_job_count, blocked_job_count, invalid_job_count = build_candidate_jobs(cohort, current_tick, service_pass_cache)
      cohort.jobs_by_id = jobs_by_id
      reconcile_leases_and_uplinks(cohort, registry, jobs_by_id, ready_jobs, target_lease_counts, current_tick, service_pass_cache)
    end

    cohort.last_snapshot = {
      ready_job_count = ready_job_count,
      blocked_job_count = blocked_job_count,
      invalid_job_count = invalid_job_count,
      blocked_lane_count = count_map(cohort.blocked_lanes),
      registry_count = count_map(registry.by_id),
      selector_count = count_map(cohort.selector_units),
      uplink_count = count_map(cohort.uplink_units),
      -- Scanner bridge summaries are only surfaced through coordinator panels
      -- and runtime snapshots, so selector/uplink-only cohorts can skip the
      -- extra cross-module read in steady state.
      scanner_summary = cohort_has_coordinator(cohort)
        and get_surface_summary(cohort.force_index, cohort.surface_name, current_tick)
        or nil,
    }
  else
    cohort.active_coordinator_unit_number = nil
    cohort.jobs_by_id = {}
    cohort.blocked_lanes = {}
    cohort.last_snapshot = {
      ready_job_count = 0,
      blocked_job_count = 0,
      invalid_job_count = 0,
      blocked_lane_count = 0,
      registry_count = 0,
      selector_count = 0,
      uplink_count = 0,
      scanner_summary = nil,
    }
  end
  local snapshot_signature = build_cohort_snapshot_signature(cohort.last_snapshot)
  local snapshot_changed = snapshot_signature ~= previous_snapshot_signature
  cohort.last_snapshot_signature = snapshot_signature

  local signature_generation = tonumber(cohort.signature_generation) or 0
  local last_signature_generation = tonumber(cohort.last_signature_generation) or -1
  local signature = cohort.last_signature
  if signature == nil or signature_generation ~= last_signature_generation then
    signature = build_cohort_signature(cohort, jobs_by_id)
  end
  local signature_changed = signature ~= cohort.last_signature
  if signature_changed then
    render_transponder_outputs(cohort)
    render_selector_outputs(cohort, jobs_by_id)
    render_coordinator_outputs(cohort, jobs_by_id)
    render_uplink_outputs(cohort, jobs_by_id, service_pass_cache)
    cohort.last_signature = signature
  end
  cohort.last_signature_generation = signature_generation
  cohort.last_service_tick = current_tick
  return signature_changed or snapshot_changed
end
-- Open cohort panels should follow the scheduler's cached updates instead of
-- forcing players to close and reopen after the next service pass.
local function refresh_open_cohort_guis(force_index, surface_name)
  if not game then
    return
  end

  local root = get_root()
  local cohort = root.cohorts[cohort_key(force_index, surface_name)]
  if type(cohort) ~= "table" then
    return
  end
  local open_gui_by_player = type(root.open_gui_by_player) == "table" and root.open_gui_by_player or nil
  if not open_gui_by_player or next(open_gui_by_player) == nil then
    return
  end

  -- Multiple players can watch the same cohort terminal at once, so reuse the
  -- resolved entity per unit number within this refresh pass instead of
  -- re-normalizing the same entity for each open panel.
  local entity_by_unit_number = {}
  local bound_silo_by_unit_number = {}
  -- Keep only same-surface scalars in the shared context. The per-player GUI
  -- refresh path writes entity-specific records back into panel_context, so
  -- each open panel still needs its own table.
  local shared_panel_context = {
    root_state = root,
    cohort = cohort,
    coordinator_refresh_pending = nil,
    coordinator_rescan_pending = nil,
  }
  for player_index in pairs(open_gui_by_player) do
    local gui_record = get_gui_record(player_index)
    if gui_record
      and gui_record.force_index
      and gui_record.surface_name
      and (gui_record.force_index ~= force_index or gui_record.surface_name ~= surface_name)
    then
      goto continue
    end

    local player = game.get_player(player_index)
    if not player then
      open_gui_by_player[player_index] = nil
      goto continue
    end
    local unit_number = gui_record and gui_record.unit_number or nil
    local entity = nil
    if unit_number then
      local cached_entity = entity_by_unit_number[unit_number]
      if cached_entity ~= nil then
        entity = cached_entity or nil
      else
        entity = get_cohort_entity_by_unit_number(unit_number)
        entity_by_unit_number[unit_number] = entity or false
      end
    end
    if not ei_lib.entity_check(entity) then
      -- Dead entities can leave a stale open-GUI record behind, which would
      -- otherwise be rechecked on every future cohort service pass.
      set_gui_record(player_index, nil)
      close_player_gui(player)
      goto continue
    end
    if entity.force.index == force_index
      and entity.surface.name == surface_name
      and not gui_record_matches_cohort(gui_record, entity.name, cohort)
    then
      if entity.name == ORBITAL_COORDINATOR_NAME
        and shared_panel_context.coordinator_refresh_pending == nil
      then
        shared_panel_context.coordinator_refresh_pending = is_cohort_queue_pending(force_index, surface_name)
        shared_panel_context.coordinator_rescan_pending = is_runtime_rescan_pending()
      end
      local panel_context = seed_panel_context({
        coordinator_refresh_pending = shared_panel_context.coordinator_refresh_pending,
        coordinator_rescan_pending = shared_panel_context.coordinator_rescan_pending,
      }, entity, shared_panel_context.root_state, shared_panel_context.cohort, bound_silo_by_unit_number)
      model.refresh_player_gui(player, entity, panel_context)
    end
    ::continue::
  end
end

local function build_world_entity_list(surface)
  local result = {}
  for _, name in ipairs({
    PLATFORM_TRANSPONDER_NAME,
    ORBITAL_SELECTOR_NAME,
    ORBITAL_COORDINATOR_NAME,
    ORBITAL_DISPATCH_UPLINK_NAME,
  }) do
    for _, entity in pairs(surface.find_entities_filtered{name = name}) do
      result[#result + 1] = entity
    end
  end
  return result
end

function model.rebuild_runtime_state(reason, current_tick)
  local root = get_root()
  current_tick = now_tick(current_tick)

  cohort_power.destroy_all_sensors()

  for player_index in pairs(root.uplink_silo_overlay_by_player or EMPTY_FILTERS) do
    destroy_player_uplink_silo_overlays(player_index)
  end

  root.runtime_state_version = ORBITAL_LOGISTICS_RUNTIME_STATE_VERSION
  root.runtime_initialized = true
  root.cohorts = {}
  root.transponders_by_unit = {}
  root.selectors_by_unit = {}
  root.coordinators_by_unit = {}
  root.uplinks_by_unit = {}
  root.claims_by_force = {}
  root.conflicts_by_force = {}
  root.transponder_units_by_force = {}
  root.transponder_units_by_platform = {}
  root.transponder_units_by_dispatch_surface = {}
  root.dispatch_surfaces_by_platform = {}
  root.dispatch_surfaces_by_hub_unit = {}
  root.uplink_dropdown_generation_by_surface = {}
  root.power_sensor_by_unit = {}
  root.power_state_by_unit = {}
  root.power_seeded_tick_by_unit = {}
  root.lease_by_job_id = {}
  root.lease_by_uplink_unit = {}
  root.uplink_by_silo_unit = {}
  root.uplink_silo_overlay_by_player = {}
  root.dirty_cohort_queue = ei_runtime_scheduler.ensure_queue(nil)
  root.rescan_queue = ei_runtime_scheduler.ensure_queue(nil)
  root.pending_rescan_reason = nil
  root.pending_rescan_request_count = 0

  if game and game.surfaces then
    for _, surface in pairs(game.surfaces) do
      for _, entity in ipairs(build_world_entity_list(surface)) do
        if entity.name == PLATFORM_TRANSPONDER_NAME then
          register_transponder(entity, current_tick)
        elseif entity.name == ORBITAL_SELECTOR_NAME then
          register_selector(entity, current_tick)
        elseif entity.name == ORBITAL_COORDINATOR_NAME then
          register_coordinator(entity, current_tick)
        elseif entity.name == ORBITAL_DISPATCH_UPLINK_NAME then
          register_uplink(entity, current_tick)
        end
      end
    end
  end

  root.last_rescan_tick = current_tick
  return {
    reason = reason or "manual",
    tick = current_tick,
    cohort_count = count_map(root.cohorts),
    transponder_count = count_map(root.transponders_by_unit),
    selector_count = count_map(root.selectors_by_unit),
    coordinator_count = count_map(root.coordinators_by_unit),
    uplink_count = count_map(root.uplinks_by_unit),
  }
end

function model.request_runtime_rescan(reason, current_tick)
  local root = get_root()
  current_tick = now_tick(current_tick)

  root.pending_rescan_reason = reason or root.pending_rescan_reason or "queued"
  root.pending_rescan_request_count = (root.pending_rescan_request_count or 0) + 1
  root.last_rescan_request_tick = current_tick
  ei_runtime_scheduler.queue_push_unique(root.rescan_queue, RESCAN_QUEUE_KEY, RESCAN_QUEUE_KEY)
  return true
end

local function consume_pending_runtime_rescan(root, current_tick)
  local rescan_key = ei_runtime_scheduler.queue_peek(root.rescan_queue)
  local pending_reason = root.pending_rescan_reason
  if not rescan_key and not pending_reason then
    return false
  end

  if rescan_key then
    ei_runtime_scheduler.queue_pop(root.rescan_queue, rescan_key)
  end

  root.pending_rescan_reason = nil
  root.pending_rescan_request_count = 0
  model.rebuild_runtime_state(
    pending_reason or ((rescan_key and rescan_key ~= RESCAN_QUEUE_KEY) and rescan_key or "queued"),
    current_tick
  )
  return true
end

function model.check_init(rebuild)
  local root = get_root()
  if rebuild ~= false then
    if root.runtime_state_version ~= ORBITAL_LOGISTICS_RUNTIME_STATE_VERSION or root.runtime_initialized ~= true then
      model.rebuild_runtime_state("init", game and game.tick or 0)
    end
  end
end

function model.get_pending_work_count()
  local root = get_root()
  local rescan_pending = root.pending_rescan_reason and 1 or 0
  local rescan_length = math.max(ei_runtime_scheduler.queue_length(root.rescan_queue), rescan_pending)
  return ei_runtime_scheduler.queue_length(root.dirty_cohort_queue) + rescan_length
end

function model.update(event)
  model.check_init(false)
  local root = get_root()
  local current_tick = event and event.tick or game and game.tick or 0

  if consume_pending_runtime_rescan(root, current_tick) then
    return model.get_pending_work_count() > 0
  end

  local key = ei_runtime_scheduler.queue_peek(root.dirty_cohort_queue)
  if not key then
    return false
  end

  ei_runtime_scheduler.queue_pop(root.dirty_cohort_queue, key)
  local cohort = root.cohorts[key]
  if cohort then
    if service_cohort(cohort, current_tick) then
      refresh_open_cohort_guis(cohort.force_index, cohort.surface_name)
    end
  end

  return model.get_pending_work_count() > 0
end

function model.get_runtime_status(current_tick)
  model.check_init(false)
  current_tick = now_tick(current_tick)
  local root = get_root()
  local cohort_count = count_map(root.cohorts)
  if cohort_count == 0 then
    return {
      tick = current_tick,
      runtime_state_version = root.runtime_state_version,
      cohort_count = 0,
      transponder_count = 0,
      selector_count = 0,
      coordinator_count = 0,
      uplink_count = 0,
      lease_count = 0,
      blocked_lane_count = 0,
      open_gui_count = count_map(root.open_gui_by_player),
      indexes = {
        transponder_force_bucket_count = 0,
        transponder_force_member_count = 0,
        transponder_platform_bucket_count = 0,
        transponder_platform_member_count = 0,
        transponder_dispatch_surface_bucket_count = 0,
        transponder_dispatch_surface_member_count = 0,
      },
      gui = {
        cached_uplink_dropdown_count = 0,
        uplink_dropdown_surface_generation_count = count_nested_bucket_count(root.uplink_dropdown_generation_by_surface),
      },
      queues = {
        dirty = {count = 0, length = 0},
        rescan = {
          count = math.max(ei_runtime_scheduler.queue_item_count(root.rescan_queue), root.pending_rescan_reason and 1 or 0),
          length = math.max(ei_runtime_scheduler.queue_length(root.rescan_queue), root.pending_rescan_reason and 1 or 0),
        },
      },
      cohorts = {},
      last_rescan_tick = root.last_rescan_tick,
      pending_rescan = root.pending_rescan_reason and {
        reason = root.pending_rescan_reason,
        requested_tick = root.last_rescan_request_tick,
        request_count = root.pending_rescan_request_count or 0,
      } or nil,
    }
  end

  local cohorts = {}
  local blocked_lane_count = 0

  for key, cohort in pairs(root.cohorts) do
    blocked_lane_count = blocked_lane_count + count_map(cohort.blocked_lanes)
    cohorts[#cohorts + 1] = {
      key = key,
      force_index = cohort.force_index,
      surface_name = cohort.surface_name,
      active_coordinator_unit_number = cohort.active_coordinator_unit_number,
      transponder_count = count_map(cohort.transponder_units),
      selector_count = count_map(cohort.selector_units),
      coordinator_count = count_map(cohort.coordinator_units),
      uplink_count = count_map(cohort.uplink_units),
      blocked_lane_count = count_map(cohort.blocked_lanes),
      last_service_tick = cohort.last_service_tick or 0,
      last_snapshot = cohort.last_snapshot,
    }
  end

  table.sort(cohorts, function(left, right)
    if left.force_index ~= right.force_index then
      return (left.force_index or 0) < (right.force_index or 0)
    end
    return tostring(left.surface_name or "") < tostring(right.surface_name or "")
  end)

  return {
    tick = current_tick,
    runtime_state_version = root.runtime_state_version,
    cohort_count = cohort_count,
    transponder_count = count_map(root.transponders_by_unit),
    selector_count = count_map(root.selectors_by_unit),
    coordinator_count = count_map(root.coordinators_by_unit),
    uplink_count = count_map(root.uplinks_by_unit),
    lease_count = count_map(root.lease_by_job_id),
    blocked_lane_count = blocked_lane_count,
    open_gui_count = count_map(root.open_gui_by_player),
    indexes = {
      transponder_force_bucket_count = count_nested_bucket_count(root.transponder_units_by_force),
      transponder_force_member_count = count_nested_member_count(root.transponder_units_by_force),
      transponder_platform_bucket_count = count_nested_bucket_count(root.transponder_units_by_platform),
      transponder_platform_member_count = count_nested_member_count(root.transponder_units_by_platform),
      transponder_dispatch_surface_bucket_count = count_nested_bucket_count(root.transponder_units_by_dispatch_surface),
      transponder_dispatch_surface_member_count = count_nested_member_count(root.transponder_units_by_dispatch_surface),
    },
    gui = {
      cached_uplink_dropdown_count = count_cached_uplink_dropdowns(root.uplinks_by_unit),
      uplink_dropdown_surface_generation_count = count_nested_bucket_count(root.uplink_dropdown_generation_by_surface),
    },
    queues = {
      dirty = {
        count = ei_runtime_scheduler.queue_item_count(root.dirty_cohort_queue),
        length = ei_runtime_scheduler.queue_length(root.dirty_cohort_queue),
      },
      rescan = {
        count = math.max(ei_runtime_scheduler.queue_item_count(root.rescan_queue), root.pending_rescan_reason and 1 or 0),
        length = math.max(ei_runtime_scheduler.queue_length(root.rescan_queue), root.pending_rescan_reason and 1 or 0),
      },
    },
    cohorts = cohorts,
    last_rescan_tick = root.last_rescan_tick,
    pending_rescan = root.pending_rescan_reason and {
      reason = root.pending_rescan_reason,
      requested_tick = root.last_rescan_request_tick,
      request_count = root.pending_rescan_request_count or 0,
    } or nil,
  }
end

function model.get_qc_snapshot(current_tick)
  model.check_init(false)
  current_tick = now_tick(current_tick)
  local root = get_root()
  local snapshot = {
    tick = current_tick,
    runtime = model.get_runtime_status(current_tick),
    transponders = {},
    selectors = {},
    coordinators = {},
    uplinks = {},
    leases = {},
    cohorts = {},
  }

  for unit_number, record in pairs(root.transponders_by_unit) do
    local entity = get_record_entity(record)
    local platform = entity and read_platform_from_transponder(entity) or nil
    snapshot.transponders[#snapshot.transponders + 1] = {
      unit_number = unit_number,
      force_index = record.force_index,
      surface_name = record.surface_name,
      platform_index = record.platform_index,
      platform_name = record.platform_name,
      platform_id = record.platform_id,
      manual_platform_id = record.manual_platform_id,
      dispatch_surface_name = record.dispatch_surface_name,
      conflict = record.conflict == true,
      scanner_requests = summarize_scanner_bridge(platform, get_mode_name_requests(), current_tick),
      scanner_need = summarize_scanner_bridge(platform, get_mode_name_need(), current_tick),
    }
  end

  for unit_number, record in pairs(root.selectors_by_unit) do
    snapshot.selectors[#snapshot.selectors + 1] = {
      unit_number = unit_number,
      force_index = record.force_index,
      surface_name = record.surface_name,
      mode = record.mode,
      manual_platform_id = record.manual_platform_id,
    }
  end

  for unit_number, record in pairs(root.coordinators_by_unit) do
    snapshot.coordinators[#snapshot.coordinators + 1] = {
      unit_number = unit_number,
      force_index = record.force_index,
      surface_name = record.surface_name,
    }
  end

  for unit_number, record in pairs(root.uplinks_by_unit) do
    local bound_silo = get_bound_silo(record)
    snapshot.uplinks[#snapshot.uplinks + 1] = {
      unit_number = unit_number,
      force_index = record.force_index,
      surface_name = record.surface_name,
      binding_silo_unit_number = record.binding_silo_unit_number,
      bound_silo_found = bound_silo ~= nil,
      bound_silo_name = bound_silo and bound_silo.name or nil,
      oversize_mode = record.oversize_mode,
      threshold_floor = record.threshold_floor,
      leased_job_id = record.leased_job_id,
    }
  end

  for job_id, lease in pairs(root.lease_by_job_id) do
    snapshot.leases[#snapshot.leases + 1] = {
      job_id = job_id,
      uplink_unit_number = lease.uplink_unit_number,
      coordinator_unit_number = lease.coordinator_unit_number,
      target_platform_id = lease.target_platform_id,
      launch_count = lease.launch_count or 0,
      created_tick = lease.created_tick or 0,
      last_launch_tick = lease.last_launch_tick or 0,
    }
  end

  for key, cohort in pairs(root.cohorts) do
    local jobs = {}
    for _, job in pairs(cohort.jobs_by_id or {}) do
      jobs[#jobs + 1] = {
        job_id = job.job_id,
        selector_unit_number = job.selector_unit_number,
        mode = job.mode,
        state = job.state,
        blocked_reason = job.blocked_reason,
        invalid_reason = job.invalid_reason,
        target_platform_id = job.target_platform_id,
        platform_name = job.platform_name,
        total_count = job.total_count or 0,
        manifest_signature = job.manifest_signature,
        leased = root.lease_by_job_id[job.job_id] ~= nil,
      }
    end
    table.sort(jobs, function(left, right)
      return (left.job_id or 0) < (right.job_id or 0)
    end)

    local blocked_lanes = {}
    for unit_number, reason in pairs(cohort.blocked_lanes or {}) do
      blocked_lanes[#blocked_lanes + 1] = {
        uplink_unit_number = unit_number,
        reason = reason,
      }
    end
    table.sort(blocked_lanes, function(left, right)
      return (left.uplink_unit_number or 0) < (right.uplink_unit_number or 0)
    end)

    snapshot.cohorts[#snapshot.cohorts + 1] = {
      key = key,
      force_index = cohort.force_index,
      surface_name = cohort.surface_name,
      active_coordinator_unit_number = cohort.active_coordinator_unit_number,
      last_service_tick = cohort.last_service_tick or 0,
      last_signature = cohort.last_signature,
      last_snapshot = cohort.last_snapshot,
      jobs = jobs,
      blocked_lanes = blocked_lanes,
    }
  end

  table.sort(snapshot.cohorts, function(left, right)
    if left.force_index ~= right.force_index then
      return (left.force_index or 0) < (right.force_index or 0)
    end
    return tostring(left.surface_name or "") < tostring(right.surface_name or "")
  end)

  return snapshot
end

local function set_selector_qc_target(unit_number, mode, manual_platform_id, current_tick)
  local root = get_root()
  local record = root.selectors_by_unit[unit_number]
  if not record then
    return nil, false
  end

  -- The live GUI and the QC helper share this setter so identical selector
  -- inputs can short-circuit before they dirty the cohort or force a repaint.
  local next_mode = mode ~= nil and normalize_selector_mode(mode) or normalize_selector_mode(record.mode)
  local next_manual_platform_id = record.manual_platform_id

  if manual_platform_id == false then
    next_manual_platform_id = nil
  elseif manual_platform_id ~= nil then
    next_manual_platform_id = normalize_platform_id_input(manual_platform_id)
  end

  if normalize_selector_mode(record.mode) == next_mode
    and tonumber(record.manual_platform_id) == tonumber(next_manual_platform_id)
  then
    return record, false
  end

  record.mode = next_mode
  record.manual_platform_id = next_manual_platform_id
  record.last_seen_tick = now_tick(current_tick)
  mark_cohort_dirty(record.force_index, record.surface_name)
  return record, true
end

function model.apply_qc_configuration(config, current_tick)
  model.check_init(false)
  current_tick = now_tick(current_tick)
  config = type(config) == "table" and config or {}

  local result = {
    tick = current_tick,
    transponders = {},
    selectors = {},
    uplinks = {},
  }

  for _, entry in ipairs(config.transponders or {}) do
    local record = set_transponder_manual_platform_id(entry.unit_number, entry.platform_id, current_tick)
    result.transponders[#result.transponders + 1] = {
      unit_number = entry.unit_number,
      ok = record ~= nil,
      platform_id = record and record.platform_id or nil,
      conflict = record and record.conflict == true or false,
    }
  end

  for _, entry in ipairs(config.selectors or {}) do
    local record = set_selector_qc_target(entry.unit_number, entry.mode, entry.manual_platform_id, current_tick)
    result.selectors[#result.selectors + 1] = {
      unit_number = entry.unit_number,
      ok = record ~= nil,
      mode = record and record.mode or nil,
      manual_platform_id = record and record.manual_platform_id or nil,
    }
  end

  for _, entry in ipairs(config.uplinks or {}) do
    local record = get_root().uplinks_by_unit[entry.unit_number]
    if record then
      if entry.binding_silo_unit_number ~= nil then
        set_uplink_binding(entry.unit_number, entry.binding_silo_unit_number, entry.binding_source or "manual")
      end
      if entry.oversize_mode ~= nil or entry.threshold_floor ~= nil then
        set_uplink_oversize_mode(entry.unit_number, entry.oversize_mode or record.oversize_mode, entry.threshold_floor, current_tick)
      end
      record = get_root().uplinks_by_unit[entry.unit_number]
    end
    result.uplinks[#result.uplinks + 1] = {
      unit_number = entry.unit_number,
      ok = record ~= nil,
      binding_silo_unit_number = record and record.binding_silo_unit_number or nil,
      oversize_mode = record and record.oversize_mode or nil,
      threshold_floor = record and record.threshold_floor or nil,
    }
  end

  return result
end

function model.service_for_qc(limit, current_tick)
  model.check_init(false)
  current_tick = now_tick(current_tick)
  local root = get_root()
  local max_steps = math.max(1, math.min(math.floor(tonumber(limit) or 64), 2048))
  local serviced = 0

  while serviced < max_steps do
    if consume_pending_runtime_rescan(root, current_tick) then
      serviced = serviced + 1
    else
      local key = ei_runtime_scheduler.queue_peek(root.dirty_cohort_queue)
      if not key then
        break
      end

      ei_runtime_scheduler.queue_pop(root.dirty_cohort_queue, key)
      local cohort = root.cohorts[key]
      if cohort then
        service_cohort(cohort, current_tick)
      end
      serviced = serviced + 1
    end
  end

  return {
    tick = current_tick,
    serviced = serviced,
    pending = model.get_pending_work_count(),
  }
end

get_gui_record = function(player_index)
  local root = get_root()
  local record = root.open_gui_by_player[player_index]
  if type(record) == "number" then
    record = {
      unit_number = record,
      gui_mode = GUI_MODE_RELATIVE,
    }
    root.open_gui_by_player[player_index] = record
  end

  if type(record) ~= "table" then
    if record ~= nil then
      root.open_gui_by_player[player_index] = nil
    end
    return nil
  end

  local unit_number = tonumber(record.unit_number) or nil
  if not unit_number then
    root.open_gui_by_player[player_index] = nil
    return nil
  end

  return {
    unit_number = unit_number,
    gui_mode = normalize_gui_mode(record.gui_mode),
    force_index = tonumber(record.force_index) or nil,
    surface_name = type(record.surface_name) == "string" and record.surface_name or nil,
    entity_name = type(record.entity_name) == "string" and record.entity_name or nil,
    draft_override_platform_id = type(record.draft_override_platform_id) == "string" and record.draft_override_platform_id or nil,
    draft_selector_platform_id = type(record.draft_selector_platform_id) == "string" and record.draft_selector_platform_id or nil,
    draft_threshold_floor = type(record.draft_threshold_floor) == "string" and record.draft_threshold_floor or nil,
    draft_binding_silo_unit_number = record.draft_binding_silo_unit_number ~= nil
      and (tonumber(record.draft_binding_silo_unit_number) or 0)
      or nil,
    last_seen_cohort_signature = type(record.last_seen_cohort_signature) == "string" and record.last_seen_cohort_signature or nil,
    last_seen_snapshot_signature = type(record.last_seen_snapshot_signature) == "string" and record.last_seen_snapshot_signature or nil,
  }
end

set_gui_record = function(player_index, unit_number, gui_mode, entity)
  local root = get_root()
  if unit_number then
    local previous = type(root.open_gui_by_player[player_index]) == "table" and root.open_gui_by_player[player_index] or nil
    local preserve_drafts = previous and tonumber(previous.unit_number) == tonumber(unit_number)
    local preserve_seen_signatures = previous and tonumber(previous.unit_number) == tonumber(unit_number)
    local entity_ref = ei_lib.get_valid_entity(entity)
    root.open_gui_by_player[player_index] = {
      unit_number = unit_number,
      gui_mode = normalize_gui_mode(gui_mode),
      force_index = entity_ref and entity_ref.force and entity_ref.force.index or nil,
      surface_name = entity_ref and entity_ref.surface and entity_ref.surface.name or nil,
      entity_name = entity_ref and entity_ref.name or nil,
      draft_override_platform_id = preserve_drafts and type(previous.draft_override_platform_id) == "string"
        and previous.draft_override_platform_id or nil,
      draft_selector_platform_id = preserve_drafts and type(previous.draft_selector_platform_id) == "string"
        and previous.draft_selector_platform_id or nil,
      draft_threshold_floor = preserve_drafts and type(previous.draft_threshold_floor) == "string"
        and previous.draft_threshold_floor or nil,
      draft_binding_silo_unit_number = preserve_drafts and previous.draft_binding_silo_unit_number ~= nil
        and tostring(previous.draft_binding_silo_unit_number) or nil,
      last_seen_cohort_signature = preserve_seen_signatures and type(previous.last_seen_cohort_signature) == "string"
        and previous.last_seen_cohort_signature or nil,
      last_seen_snapshot_signature = preserve_seen_signatures and type(previous.last_seen_snapshot_signature) == "string"
        and previous.last_seen_snapshot_signature or nil,
    }
  else
    root.open_gui_by_player[player_index] = nil
  end
end

local function set_gui_seen_signatures(player_index, cohort_signature, snapshot_signature)
  local record = get_root().open_gui_by_player[player_index]
  if type(record) ~= "table" then
    return
  end

  record.last_seen_cohort_signature = type(cohort_signature) == "string" and cohort_signature or nil
  record.last_seen_snapshot_signature = type(snapshot_signature) == "string" and snapshot_signature or nil
end

gui_record_matches_cohort = function(gui_record, entity_name, cohort)
  if type(gui_record) ~= "table" or type(cohort) ~= "table" then
    return false
  end

  if entity_name == ORBITAL_COORDINATOR_NAME then
    return gui_record.last_seen_cohort_signature == cohort.last_signature
      and gui_record.last_seen_snapshot_signature == cohort.last_snapshot_signature
  end

  return gui_record.last_seen_cohort_signature == cohort.last_signature
end

set_gui_draft_value = function(player_index, key, value)
  local record = get_root().open_gui_by_player[player_index]
  if type(record) ~= "table" or type(key) ~= "string" then
    return false
  end

  local next_value = value ~= nil and tostring(value) or nil
  if record[key] == next_value then
    return false
  end

  record[key] = next_value
  return true
end

get_cohort_entity_by_unit_number = function(unit_number)
  unit_number = tonumber(unit_number) or nil
  if not unit_number then
    return nil
  end

  local cohort_record = get_cohort_record_by_unit_number(unit_number)
  local entity = get_record_entity(cohort_record)
  if entity and is_cohort_entity(entity) then
    return entity
  end

  entity = get_entity_by_unit_number(unit_number)
  if entity and is_cohort_entity(entity) then
    return entity
  end

  return nil
end

get_opened_cohort_entity = function(player_index)
  local record = get_gui_record(player_index)
  local entity = get_cohort_entity_by_unit_number(record and record.unit_number or nil)
  if entity then
    return entity
  end

  set_gui_record(player_index, nil)
  return nil
end

get_player_opened_cohort_entity = function(player)
  local opened = ei_lib.get_valid_entity(player and player.opened)
  if is_cohort_entity(opened) then
    return opened
  end

  return nil
end

resolve_requested_cohort_entity = function(player, entity_hint)
  local hinted = ei_lib.get_valid_entity(entity_hint)
  if is_cohort_entity(hinted) then
    return hinted
  end

  return get_player_opened_cohort_entity(player)
end

close_player_gui = function(player)
  destroy_player_uplink_silo_overlays(player and player.index or nil)
  if player and player.gui and player.gui.relative and player.gui.relative[GUI_NAME] then
    player.gui.relative[GUI_NAME].destroy()
  end
  if player and player.gui and player.gui.screen and player.gui.screen[GUI_NAME] then
    player.gui.screen[GUI_NAME].destroy()
  end
end

get_player_gui_root = function(player)
  if not (player and player.gui) then
    return nil
  end

  return (player.gui.relative and player.gui.relative[GUI_NAME])
    or (player.gui.screen and player.gui.screen[GUI_NAME])
    or nil
end

function model.get_gui(player)
  return get_player_gui_root(player)
end

-- Keep GUI rendering tied to cached cohort state so the cohort terminals can
-- stay configurable without re-running selector/coordinator arbitration on
-- every refresh. The preferred path is now the same relative combinator panel
-- style the scanner uses, with a screen fallback only if the relative anchor
-- cannot be created for the currently opened terminal.
-- Player-facing orbital cohort wording is kept behind locale keys here so the
-- handbook, item descriptions, and GUI can stay in sync without hiding English
-- copy inside runtime logic.

local function gui_text(value)
  if value == nil or value == "" then
    return "-"
  end

  return tostring(value)
end

local function gui_locale(key, ...)
  return {"exotic-industries." .. key, ...}
end

local function gui_value(key, ...)
  return gui_locale("orbital-logistics-gui-value-" .. key, ...)
end

local function gui_line(key, ...)
  return gui_locale("orbital-logistics-gui-line-" .. key, ...)
end

local function gui_hint(key, ...)
  return gui_locale("orbital-logistics-gui-hint-" .. key, ...)
end

local function get_preferred_gui_mode(player, entity)
  if ei_lib.entity_check(entity) and get_player_opened_cohort_entity(player) == entity then
    return GUI_MODE_RELATIVE
  end

  return GUI_MODE_SCREEN
end

local function copy_gui_location(location)
  if type(location) ~= "table" then
    return nil
  end

  local x = tonumber(location.x or location[1]) or nil
  local y = tonumber(location.y or location[2]) or nil
  if not (x and y) then
    return nil
  end

  return {x = x, y = y}
end

local function add_gui_section(parent, caption, use_top_border, name)
  local header = parent.add{
    type = "frame",
    name = name and (name .. "-header") or nil,
    style = use_top_border and "ei_subheader_frame_with_top_border" or "ei_subheader_frame",
  }
  header.add{
    type = "label",
    caption = caption,
    style = "subheader_caption_label",
  }

  local section = parent.add{
    type = "flow",
    name = name,
    direction = "vertical",
    style = "ei_inner_content_flow",
  }
  section.style.horizontally_stretchable = true
  return section
end

local function add_gui_subheader(parent, caption, use_top_border, name)
  local header = parent.add{
    type = "frame",
    name = name,
    style = use_top_border and "ei_subheader_frame_with_top_border" or "ei_subheader_frame",
  }
  header.add{
    type = "label",
    caption = caption,
    style = "subheader_caption_label",
  }
  return header
end

local GUI_REASON_LABEL_KEYS = {
  ["no-target"] = "orbital-logistics-status-no-target",
  ["platform-busy"] = "orbital-logistics-status-platform-busy",
  ["unknown-platform-id"] = "orbital-logistics-status-unknown-platform-id",
  ["missing-platform"] = "orbital-logistics-status-missing-platform",
  ["no-demand"] = "orbital-logistics-status-no-demand",
  ["missing-selector"] = "orbital-logistics-status-missing-selector",
  ["missing-silo-binding"] = "orbital-logistics-status-missing-silo-binding",
  ["no-active-coordinator"] = "orbital-logistics-status-no-active-coordinator",
  ["no-ready-job"] = "orbital-logistics-status-no-ready-job",
  ["no-power"] = "orbital-scanner-status-no-power",
}

local GUI_STATE_LABEL_KEYS = {
  ["ready"] = "orbital-logistics-status-ready",
  ["invalid"] = "orbital-logistics-status-invalid",
  ["blocked"] = "orbital-logistics-status-blocked",
  ["standby"] = "orbital-logistics-status-standby",
  ["conflict"] = "orbital-logistics-status-conflict",
  ["missing-silo"] = "orbital-logistics-status-missing-silo",
}

local function gui_reason_text(value)
  local key = value and GUI_REASON_LABEL_KEYS[value] or nil
  if key then
    return gui_locale(key)
  end

  return gui_text(value)
end

local function gui_state_text(value, reason)
  if value == "invalid" then
    return reason
      and gui_locale("orbital-logistics-gui-state-invalid-with-reason", gui_reason_text(reason))
      or gui_locale(GUI_STATE_LABEL_KEYS.invalid)
  end
  if value == "blocked" then
    return reason
      and gui_locale("orbital-logistics-gui-state-blocked-with-reason", gui_reason_text(reason))
      or gui_locale(GUI_STATE_LABEL_KEYS.blocked)
  end
  if not value or value == "" then
    return gui_locale("orbital-logistics-status-idle")
  end

  local key = GUI_STATE_LABEL_KEYS[value]
  if key then
    return gui_locale(key)
  end

  return tostring(value)
end

local function set_gui_caption(container, name, caption)
  if container and container[name] then
    container[name].caption = caption
  end
end

local function make_gui_caption(lines)
  local text = {""}
  for _, line in ipairs(lines or {}) do
    if line ~= nil and line ~= "" then
      if #text > 0 then
        text[#text + 1] = "\n"
      end
      text[#text + 1] = line
    end
  end
  if #text <= 1 then
    return ""
  end
  return text
end

local function gui_detail_line(label_key, value)
  return {"", gui_locale(label_key), ": ", value}
end

local function get_selector_job_record(cohort, unit_number)
  if not cohort then
    return nil
  end

  local job = cohort.jobs_by_id[unit_number]
  if job then
    return job
  end

  local record = get_root().selectors_by_unit[unit_number]
  if not record then
    return nil
  end

  return {
    job_id = unit_number,
    selector_unit_number = unit_number,
    force_index = record.force_index,
    surface_name = record.surface_name,
    mode = normalize_selector_mode(record.mode),
    target_platform_id = tonumber(record.manual_platform_id) or nil,
    manifest = EMPTY_FILTERS,
    manifest_signature = EMPTY_FILTERS_SIGNATURE,
    total_count = 0,
    state = "blocked",
    blocked_reason = "no-target",
    invalid_reason = nil,
    platform_name = nil,
  }
end

local function get_uplink_job_record(cohort, record)
  if not (cohort and record and record.leased_job_id) then
    return nil
  end

  return cohort.jobs_by_id and cohort.jobs_by_id[record.leased_job_id] or nil
end

local function set_dropdown_value(dropdown, wanted_value)
  if not (dropdown and dropdown.valid) then
    return 1
  end

  local values = dropdown.tags and dropdown.tags.values or nil
  if type(values) ~= "table" then
    return 1
  end

  for index, value in ipairs(values) do
    if tonumber(value) == tonumber(wanted_value) then
      if dropdown.selected_index ~= index then
        dropdown.selected_index = index
      end
      return index
    end
  end

  if dropdown.selected_index ~= 1 then
    dropdown.selected_index = 1
  end
  return 1
end

count_jobs_by_state = function(jobs_by_id)
  local ready = 0
  local blocked = 0
  local invalid = 0

  for _, job in pairs(jobs_by_id or {}) do
    if job.state == "ready" then
      ready = ready + 1
    elseif job.state == "invalid" then
      invalid = invalid + 1
    else
      blocked = blocked + 1
    end
  end

  return ready, blocked, invalid
end

local function build_entity_silo_dropdown_items(entity, current_uplink_unit_number)
  local items = {{"exotic-industries.orbital-logistics-gui-silo-none"}}
  local values = {0}
  local index_by_unit_number = {[0] = 1}
  local preferred_adjacent_unit_number = 0
  local fallback_adjacent_unit_number = 0
  if ei_lib.entity_check(entity) then
    for _, silo in ipairs(find_adjacent_silos(entity)) do
      local silo_unit_number = tonumber(silo.unit_number) or 0
      local owner_unit_number = get_uplink_binding_owner_unit_number(silo_unit_number)
      local label = { "", tostring(silo.unit_number), " [", {"entity-name.rocket-silo"}, "]" }
      if owner_unit_number and owner_unit_number ~= current_uplink_unit_number then
        label[#label + 1] = " - "
        label[#label + 1] = gui_locale("orbital-logistics-gui-silo-linked", tostring(owner_unit_number))
      end
      if silo_unit_number ~= 0 then
        if fallback_adjacent_unit_number == 0 then
          fallback_adjacent_unit_number = silo_unit_number
        end
        if preferred_adjacent_unit_number == 0
          and (owner_unit_number == nil or owner_unit_number == current_uplink_unit_number)
        then
          preferred_adjacent_unit_number = silo_unit_number
        end
      end
      items[#items + 1] = label
      values[#values + 1] = silo_unit_number
      index_by_unit_number[silo_unit_number] = #values
    end
  end
  if preferred_adjacent_unit_number == 0 then
    preferred_adjacent_unit_number = fallback_adjacent_unit_number
  end
  return items, values, index_by_unit_number, preferred_adjacent_unit_number
end

-- Open uplink GUIs can repaint often while the cohort services the same surface.
-- Cache the nearby-silo dropdown plus its preferred adjacent choice on the
-- uplink record and only invalidate it on silo topology or ownership changes
-- instead of rescanning every refresh.
local function get_uplink_dropdown_items(record, entity, current_uplink_unit_number)
  local surface_generation = type(record) == "table"
    and get_surface_uplink_dropdown_generation(record.force_index, record.surface_name)
    or 0
  local cache = record and record.silo_dropdown_cache or nil
  if type(cache) == "table"
    and type(cache.items) == "table"
    and type(cache.values) == "table"
    and type(cache.index_by_unit_number) == "table"
    and (tonumber(cache.surface_generation) or 0) == surface_generation
  then
    return cache.items, cache.values, cache.index_by_unit_number, tonumber(cache.preferred_adjacent_unit_number) or 0
  end

  local items, values, index_by_unit_number, preferred_adjacent_unit_number = build_entity_silo_dropdown_items(entity, current_uplink_unit_number)
  if type(record) == "table" then
    record.silo_dropdown_cache = {
      items = items,
      values = values,
      index_by_unit_number = index_by_unit_number,
      preferred_adjacent_unit_number = preferred_adjacent_unit_number,
      surface_generation = surface_generation,
    }
  end
  return items, values, index_by_unit_number, preferred_adjacent_unit_number
end

local function refresh_uplink_dropdown(dropdown, entity, current_uplink_unit_number, bound_silo_unit_number, record)
  if not (dropdown and dropdown.valid) then
    return nil, 0, 0
  end

  local items, values, index_by_unit_number, preferred_adjacent_unit_number = get_uplink_dropdown_items(record, entity, current_uplink_unit_number)
  local tags = dropdown.tags or {}
  local wanted_index = type(index_by_unit_number) == "table"
    and index_by_unit_number[tonumber(bound_silo_unit_number or 0)]
    or nil
  if wanted_index == nil then
    wanted_index = 1
  end
  local selected_value = tonumber(values[wanted_index]) or 0

  if tags.values == values and dropdown.selected_index == wanted_index then
    return values, selected_value, preferred_adjacent_unit_number
  end

  if tags.values == values then
    set_dropdown_value(dropdown, bound_silo_unit_number or 0)
    return values, tonumber(values[dropdown.selected_index]) or 0, preferred_adjacent_unit_number
  end

  dropdown.items = items
  tags.parent_gui = GUI_NAME
  tags.values = values
  dropdown.tags = tags
  set_dropdown_value(dropdown, bound_silo_unit_number or 0)
  return values, tonumber(values[dropdown.selected_index]) or 0, preferred_adjacent_unit_number
end

local function build_uplink_silo_overlay_signature(uplink_unit_number, bound_silo_unit_number, selected_silo_unit_number, values)
  local signature_parts = {
    tostring(tonumber(uplink_unit_number) or 0),
    tostring(tonumber(bound_silo_unit_number) or 0),
    tostring(tonumber(selected_silo_unit_number) or 0),
  }

  for _, value in ipairs(values or EMPTY_FILTERS) do
    local silo_unit_number = tonumber(value) or 0
    if silo_unit_number ~= 0 then
      signature_parts[#signature_parts + 1] = table.concat({
        tostring(silo_unit_number),
        tostring(tonumber(get_uplink_binding_owner_unit_number(silo_unit_number)) or 0),
      }, ":")
    end
  end

  return table.concat(signature_parts, "|")
end

local function append_uplink_overlay_candidate(candidates, seen, silo_unit_number)
  silo_unit_number = tonumber(silo_unit_number) or 0
  if silo_unit_number == 0 or seen[silo_unit_number] then
    return
  end

  seen[silo_unit_number] = true
  candidates[#candidates + 1] = silo_unit_number
end

local function build_uplink_overlay_candidates(values, bound_silo_unit_number, selected_silo_unit_number)
  local candidates = {}
  local seen = {}

  for _, value in ipairs(values or EMPTY_FILTERS) do
    append_uplink_overlay_candidate(candidates, seen, value)
  end
  append_uplink_overlay_candidate(candidates, seen, bound_silo_unit_number)
  append_uplink_overlay_candidate(candidates, seen, selected_silo_unit_number)

  return candidates
end

local function uplink_overlay_entries_are_valid(entries)
  if type(entries) ~= "table" then
    return false
  end

  for _, render_entry in ipairs(entries) do
    local render_object = render_entry and render_entry.render or nil
    if not (render_object and render_object.valid) then
      return false
    end
  end

  return true
end

sync_player_uplink_silo_overlays = function(player, entity, panel_context)
  -- Dispatch uplinks use the same nearby-silo candidate list in the GUI and in
  -- the world overlay so players can bind by sight without maintaining a
  -- second discovery path or leaking labels to uninvolved players.
  local player_index = player and player.index or nil
  if not tonumber(player_index) then
    return
  end

  if not (player and player.valid and ei_lib.entity_check(entity) and entity.name == ORBITAL_DISPATCH_UPLINK_NAME) then
    destroy_player_uplink_silo_overlays(player_index)
    return
  end

  local root = get_root()
  local record = type(panel_context) == "table" and type(panel_context.uplink_record) == "table"
    and panel_context.uplink_record
    or root.uplinks_by_unit[entity.unit_number]
  if type(record) ~= "table" then
    destroy_player_uplink_silo_overlays(player_index)
    return
  end

  local values = type(panel_context) == "table" and panel_context.uplink_dropdown_values or nil
  if type(values) ~= "table" then
    local _, cached_values = get_uplink_dropdown_items(record, entity, entity.unit_number)
    values = cached_values
  end
  local gui_record = get_gui_record(player_index)
  local bound_silo_unit_number = tonumber(record.binding_silo_unit_number) or 0
  local selected_silo_unit_number = tonumber(type(panel_context) == "table" and panel_context.uplink_selected_silo_unit_number or nil)
    or tonumber(gui_record and gui_record.draft_binding_silo_unit_number)
    or bound_silo_unit_number
  local overlay_candidates = build_uplink_overlay_candidates(values, bound_silo_unit_number, selected_silo_unit_number)
  local signature = build_uplink_silo_overlay_signature(
    entity.unit_number,
    bound_silo_unit_number,
    selected_silo_unit_number,
    overlay_candidates
  )
  local existing = root.uplink_silo_overlay_by_player[player_index]
  if type(existing) == "table"
    and existing.signature == signature
    and existing.uplink_unit == entity.unit_number
    and uplink_overlay_entries_are_valid(existing.entries)
  then
    return
  end

  destroy_player_uplink_silo_overlays(player_index)

  local entries = {}
  for _, silo_unit_number in ipairs(overlay_candidates) do
    local silo = get_entity_by_unit_number(silo_unit_number)
    if ei_lib.entity_check(silo)
      and silo.type == "rocket-silo"
      and silo.force.index == entity.force.index
      and silo.surface.name == entity.surface.name
    then
      local owner_unit_number = tonumber(get_uplink_binding_owner_unit_number(silo_unit_number)) or 0
      local color = {r = 0.92, g = 0.95, b = 1}
      local scale = 1.15
      if owner_unit_number ~= 0 and owner_unit_number ~= entity.unit_number then
        color = {r = 1, g = 0.42, b = 0.42}
      elseif silo_unit_number == bound_silo_unit_number and bound_silo_unit_number ~= 0 then
        color = {r = 0.35, g = 1, b = 0.55}
        scale = 1.3
      elseif silo_unit_number == selected_silo_unit_number and selected_silo_unit_number ~= 0 then
        color = {r = 1, g = 0.84, b = 0.22}
        scale = 1.22
      end

      -- Rocket silos are large enough that entity-anchored text can end up
      -- feeling swallowed by the sprite stack, so place the label at an
      -- fixed offset above the pad and scope it the same way other ESIR
      -- player-only visual helpers do, so the label reliably follows the silo
      -- sprite and only the inspecting player sees it.
      local render_object = rendering.draw_text{
        text = "#" .. tostring(silo_unit_number),
        surface = silo.surface,
        target = {
          entity = silo,
          offset = {0, -4.75},
        },
        color = color,
        alignment = "center",
        vertical_alignment = "middle",
        font = "default-game",
        scale = scale,
        scale_with_zoom = false,
        players = {player},
        forces = {entity.force},
        render_mode = "game",
      }

      if render_object and render_object.valid then
        entries[#entries + 1] = {
          render = render_object,
          uplink_unit = entity.unit_number,
          silo_unit = silo_unit_number,
        }
      end
    end
  end

  if next(entries) ~= nil then
    root.uplink_silo_overlay_by_player[player_index] = {
      uplink_unit = entity.unit_number,
      signature = signature,
      entries = entries,
    }
  end
end

local function build_player_gui(player, entity, gui_mode)
  local previous_screen_root = player and player.gui and player.gui.screen and player.gui.screen[GUI_NAME] or nil
  local previous_screen_location = previous_screen_root and previous_screen_root.valid
    and copy_gui_location(previous_screen_root.location)
    or nil
  close_player_gui(player)
  if not (player and player.valid and ei_lib.entity_check(entity)) then
    return nil
  end

  gui_mode = normalize_gui_mode(gui_mode)

  local root = nil
  if gui_mode == GUI_MODE_RELATIVE then
    local ok, relative_root = pcall(function()
      return player.gui.relative.add{
        type = "frame",
        name = GUI_NAME,
        anchor = {
          gui = defines.relative_gui_type.constant_combinator_gui,
          name = entity.name,
          position = defines.relative_gui_position.right,
        },
        direction = "vertical",
        tags = {
          parent_gui = GUI_NAME,
          entity_unit_number = entity.unit_number,
          gui_mode = GUI_MODE_RELATIVE,
        },
      }
    end)
    if ok and relative_root and relative_root.valid then
      root = relative_root
    end
  end

  if not root then
    gui_mode = GUI_MODE_SCREEN
    root = player.gui.screen.add{
      type = "frame",
      name = GUI_NAME,
      direction = "vertical",
      tags = {
        parent_gui = GUI_NAME,
        entity_unit_number = entity.unit_number,
        gui_mode = GUI_MODE_SCREEN,
      },
    }
    -- Detached panels should stay where the player last dragged them when a
    -- rebuild is needed for the same console or another cohort terminal.
    if previous_screen_location then
      root.location = previous_screen_location
    else
      root.force_auto_center()
    end
  end

  local titlebar = root.add{type = "flow", direction = "horizontal"}
  if gui_mode == GUI_MODE_SCREEN then
    titlebar.drag_target = root
  end
  titlebar.add{type = "label", caption = {"entity-name." .. entity.name}, style = "frame_title"}
  titlebar.add{
    type = "label",
    caption = gui_mode == GUI_MODE_RELATIVE and gui_value("panel-linked") or gui_value("panel-detached"),
    style = "caption_label",
  }
  titlebar.add{
    type = "empty-widget",
    style = gui_mode == GUI_MODE_SCREEN and "ei_titlebar_draggable_spacer" or "ei_titlebar_nondraggable_spacer",
    ignored_by_interaction = true,
  }
  titlebar.add{
    type = "sprite-button",
    sprite = "virtual-signal/informatron",
    tooltip = {"exotic-industries.gui-open-informatron"},
    style = "frame_action_button",
    tags = {parent_gui = GUI_NAME, action = "goto-informatron"},
  }
  if gui_mode == GUI_MODE_SCREEN then
    titlebar.add{
      type = "sprite-button",
      style = "close_button",
      sprite = "utility/close",
      hovered_sprite = "utility/close_black",
      clicked_sprite = "utility/close_black",
      tags = {parent_gui = GUI_NAME, action = "close-gui"},
    }
  end

  local body = root.add{type = "frame", name = "body", direction = "vertical", style = "inside_shallow_frame"}
  -- Give the cohort panels a little more room so coordinator hints, uplink
  -- bindings, and the detached title state stop feeling squeezed.
  body.style.minimal_width = 456
  add_gui_subheader(body, gui_locale("orbital-logistics-gui-status-title"), false, "status-header")
  local summary = body.add{type = "label", name = "summary", style = "caption_label"}
  summary.style.single_line = false
  summary.style.maximal_width = 436
  local details = body.add{type = "label", name = "details", style = "caption_label"}
  details.style.single_line = false
  details.style.maximal_width = 436
  add_gui_subheader(body, gui_locale("orbital-logistics-gui-guidance-title"), true, "guidance-header")
  local hint = body.add{type = "label", name = "hint", style = "caption_label"}
  hint.style.single_line = false
  hint.style.maximal_width = 436

  if entity.name == PLATFORM_TRANSPONDER_NAME then
    local section = add_gui_section(body, gui_locale("orbital-logistics-gui-platform-id"), true, "override-section")
    local flow = section.add{type = "flow", direction = "horizontal", name = "override-flow"}
    flow.style.horizontally_stretchable = true
    local textfield = flow.add{type = "textfield", name = "platform-id", text = "", tooltip = gui_locale("orbital-logistics-gui-platform-id-tooltip")}
    textfield.style.width = 96
    textfield.style.horizontally_stretchable = true
    flow.add{type = "button", name = "apply-platform-id", caption = gui_locale("orbital-logistics-gui-apply-platform-id"), tooltip = gui_locale("orbital-logistics-gui-apply-platform-id-tooltip"), tags = {parent_gui = GUI_NAME, action = "apply-platform-id"}}
    flow.add{type = "button", name = "clear-platform-id", caption = gui_locale("orbital-logistics-gui-clear-platform-id"), tooltip = gui_locale("orbital-logistics-gui-clear-platform-id-tooltip"), tags = {parent_gui = GUI_NAME, action = "clear-platform-id"}}
  elseif entity.name == ORBITAL_SELECTOR_NAME then
    local mode_section = add_gui_section(body, gui_locale("orbital-logistics-gui-mode-label"), true, "mode-section")
    local mode_flow = mode_section.add{type = "flow", direction = "vertical", name = "mode-flow"}
    mode_flow.style.horizontally_stretchable = true
    for _, mode_name in ipairs(SELECTOR_MODE_ORDER) do
      local button = mode_flow.add{
        type = "button",
        name = "mode-" .. mode_name,
        caption = {"exotic-industries.orbital-logistics-gui-selector-mode-" .. mode_name},
        tooltip = mode_name == MODE_MANUAL
          and gui_locale("orbital-logistics-gui-selector-mode-manual-tooltip")
          or (mode_name == MODE_CIRCUIT
            and gui_locale("orbital-logistics-gui-selector-mode-circuit-tooltip")
            or gui_locale("orbital-logistics-gui-selector-mode-policy-tooltip")),
        tags = {parent_gui = GUI_NAME, action = "set-selector-mode", mode = mode_name},
      }
      button.style.horizontally_stretchable = true
    end
    local focus_section = add_gui_section(body, gui_locale("orbital-logistics-gui-manual-target-label"), true, "focus-section")
    local focus_flow = focus_section.add{type = "flow", direction = "horizontal", name = "focus-flow"}
    focus_flow.style.horizontally_stretchable = true
    local textfield = focus_flow.add{type = "textfield", name = "platform-id", text = "", tooltip = gui_locale("orbital-logistics-gui-selector-platform-tooltip")}
    textfield.style.width = 96
    textfield.style.horizontally_stretchable = true
    focus_flow.add{type = "button", name = "apply-selector-platform", caption = gui_locale("orbital-logistics-gui-apply-selector-platform"), tooltip = gui_locale("orbital-logistics-gui-apply-selector-platform-tooltip"), tags = {parent_gui = GUI_NAME, action = "apply-selector-platform"}}
    focus_flow.add{type = "button", name = "clear-selector-platform", caption = gui_locale("orbital-logistics-gui-clear-selector-platform"), tooltip = gui_locale("orbital-logistics-gui-clear-selector-platform-tooltip"), tags = {parent_gui = GUI_NAME, action = "clear-selector-platform"}}
    local release_button = focus_section.add{
      type = "button",
      name = "release-selector-lease",
      caption = gui_locale("orbital-logistics-gui-release-selector-lease"),
      tooltip = gui_locale("orbital-logistics-gui-release-selector-lease-tooltip"),
      style = "ei_small_red_button",
      tags = {parent_gui = GUI_NAME, action = "release-selector-lease"},
    }
    release_button.style.horizontally_stretchable = true
  elseif entity.name == ORBITAL_COORDINATOR_NAME then
    local control_section = add_gui_section(body, gui_locale("orbital-logistics-gui-coordinator-control-label"), true, "coordinator-section")
    local control_flow = control_section.add{type = "flow", direction = "horizontal", name = "coordinator-flow"}
    control_flow.style.horizontally_stretchable = true
    control_flow.style.horizontal_spacing = 8
    local refresh_button = control_flow.add{
      type = "button",
      name = "refresh-cohort",
      caption = gui_locale("orbital-logistics-gui-refresh-cohort"),
      tooltip = gui_locale("orbital-logistics-gui-refresh-cohort-tooltip"),
      tags = {parent_gui = GUI_NAME, action = "refresh-cohort"},
    }
    refresh_button.style.horizontally_stretchable = true
    if player.admin then
      local rescan_button = control_flow.add{
        type = "button",
        name = "rescan-runtime",
        caption = gui_locale("orbital-logistics-gui-rescan-runtime"),
        tooltip = gui_locale("orbital-logistics-gui-rescan-runtime-tooltip"),
        style = "ei_small_red_button",
        tags = {parent_gui = GUI_NAME, action = "rescan-runtime"},
      }
      rescan_button.style.horizontally_stretchable = true
    end
  elseif entity.name == ORBITAL_DISPATCH_UPLINK_NAME then
    local binding_section = add_gui_section(body, gui_locale("orbital-logistics-gui-binding-label"), true, "binding-section")
    local record = get_root().uplinks_by_unit[entity.unit_number]
    local items, values = get_uplink_dropdown_items(record, entity, entity.unit_number)
    local dropdown = binding_section.add{
      type = "drop-down",
      name = "silo-dropdown",
      items = items,
      selected_index = 1,
      tags = {parent_gui = GUI_NAME, values = values},
    }
    dropdown.style.horizontally_stretchable = true
    local binding_flow = binding_section.add{type = "flow", direction = "horizontal", name = "binding-flow"}
    binding_flow.style.horizontally_stretchable = true
    binding_flow.style.horizontal_spacing = 8
    local apply_binding_button = binding_flow.add{type = "button", name = "apply-silo-binding", caption = gui_locale("orbital-logistics-gui-apply-silo-binding"), tooltip = gui_locale("orbital-logistics-gui-confirm-silo-binding-tooltip"), tags = {parent_gui = GUI_NAME, action = "apply-silo-binding"}}
    local clear_binding_button = binding_flow.add{type = "button", name = "clear-silo-binding", caption = gui_locale("orbital-logistics-gui-clear-silo-binding"), tooltip = gui_locale("orbital-logistics-gui-clear-silo-binding-tooltip"), tags = {parent_gui = GUI_NAME, action = "clear-silo-binding"}}
    local adjacent_binding_button = binding_flow.add{type = "button", name = "adjacent-silo-binding", caption = {"exotic-industries.orbital-logistics-gui-use-adjacent"}, tooltip = gui_locale("orbital-logistics-gui-use-adjacent-tooltip"), tags = {parent_gui = GUI_NAME, action = "adjacent-silo-binding"}}
    apply_binding_button.style.horizontally_stretchable = true
    clear_binding_button.style.horizontally_stretchable = true
    adjacent_binding_button.style.horizontally_stretchable = true
    local release_uplink_button = binding_section.add{
      type = "button",
      name = "release-uplink-lease",
      caption = gui_locale("orbital-logistics-gui-release-uplink-lease"),
      tooltip = gui_locale("orbital-logistics-gui-release-uplink-lease-tooltip"),
      style = "ei_small_red_button",
      tags = {parent_gui = GUI_NAME, action = "release-uplink-lease"},
    }
    release_uplink_button.style.horizontally_stretchable = true

    local oversize_section = add_gui_section(body, gui_locale("orbital-logistics-gui-detail-threshold"), true, "oversize-section")
    local oversize_flow = oversize_section.add{type = "flow", direction = "vertical", name = "oversize-flow"}
    oversize_flow.style.horizontally_stretchable = true
    for _, mode_name in ipairs(OVERSIZE_MODE_ORDER) do
      local button = oversize_flow.add{
        type = "button",
        name = "oversize-" .. mode_name,
        caption = {"exotic-industries.orbital-logistics-gui-oversize-" .. mode_name},
        tooltip = mode_name == OVERSIZE_STICKY
          and gui_locale("orbital-logistics-gui-oversize-sticky-tooltip")
          or (mode_name == OVERSIZE_SINGLE_SHOT
            and gui_locale("orbital-logistics-gui-oversize-single-shot-tooltip")
            or gui_locale("orbital-logistics-gui-oversize-threshold-tooltip")),
        tags = {parent_gui = GUI_NAME, action = "set-oversize-mode", mode = mode_name},
      }
      button.style.horizontally_stretchable = true
    end
    oversize_section.add{
      type = "label",
      name = "threshold-floor-label",
      caption = gui_locale("orbital-logistics-gui-threshold-floor-label"),
      style = "caption_label",
    }
    local threshold_flow = oversize_section.add{type = "flow", direction = "horizontal", name = "threshold-flow"}
    threshold_flow.style.horizontally_stretchable = true
    threshold_flow.style.horizontal_spacing = 8
    local textfield = threshold_flow.add{type = "textfield", name = "threshold-floor", text = "0", tooltip = gui_locale("orbital-logistics-gui-threshold-floor-tooltip")}
    textfield.style.width = 96
    textfield.style.horizontally_stretchable = true
    local apply_threshold_button = threshold_flow.add{type = "button", name = "apply-threshold-floor", caption = gui_locale("orbital-logistics-gui-apply-threshold-floor"), tooltip = gui_locale("orbital-logistics-gui-apply-threshold-floor-tooltip"), tags = {parent_gui = GUI_NAME, action = "apply-threshold-floor"}}
    apply_threshold_button.style.horizontally_stretchable = true
  end
  if gui_mode == GUI_MODE_SCREEN then
    root.bring_to_front()
  end
  return root
end

-- Keep draft typing and silo browsing cheap: these interactions only need the
-- side panel's control state refreshed, not a full cohort summary rebuild. A
-- full panel refresh can optionally hand off already-read state so the open GUI
-- path does not immediately repeat the same record lookups.
local function refresh_player_gui_controls(player, entity_override, panel_context)
  if not (player and player.valid) then
    return
  end

  local seeded_panel_context = type(panel_context) == "table" and panel_context or nil
  local entity = seeded_panel_context and ei_lib.get_valid_entity(seeded_panel_context.entity) or nil
  if not is_cohort_entity(entity) then
    entity = ei_lib.get_valid_entity(entity_override)
  end
  if not is_cohort_entity(entity) then
    entity = get_opened_cohort_entity(player.index)
  end
  if not ei_lib.entity_check(entity) then
    destroy_player_uplink_silo_overlays(player.index)
    return
  end

  local root = get_player_gui_root(player)
  if not (root and root.valid and root.body) then
    destroy_player_uplink_silo_overlays(player.index)
    return
  end
  local root_state = (seeded_panel_context and seeded_panel_context.root_state) or get_root()
  -- Control refresh only needs root_state plus any cached record handoff, so
  -- normalize the context once and let the per-entity branches trust it.
  panel_context = seed_panel_context(seeded_panel_context or {}, entity, root_state)
  local override_section = root.body["override-section"]
  local mode_section = root.body["mode-section"]
  local focus_section = root.body["focus-section"]

  local gui_record = get_gui_record(player.index)
  local root_mode = normalize_gui_mode(root.tags and root.tags.gui_mode)
  if not gui_record
    or gui_record.unit_number ~= entity.unit_number
    or gui_record.gui_mode ~= root_mode
    or gui_record.force_index ~= entity.force.index
    or gui_record.surface_name ~= entity.surface.name
  then
    set_gui_record(player.index, entity.unit_number, root_mode, entity)
    gui_record = get_gui_record(player.index)
  end

  if entity.name == PLATFORM_TRANSPONDER_NAME then
    local record = panel_context.transponder_record
    if type(record) ~= "table" then
      record = root_state.transponders_by_unit[entity.unit_number]
      panel_context.transponder_record = record
    end
    local override_flow = override_section and override_section["override-flow"] or nil
    local override_field = override_flow and override_flow["platform-id"] or nil
    local override_text = (gui_record and gui_record.draft_override_platform_id)
      or (record and record.manual_platform_id and tostring(record.manual_platform_id))
      or ""
    if override_field and override_field.text ~= override_text then
      override_field.text = override_text
    end
    if override_flow then
      local current_manual_platform_id = tonumber(record and record.manual_platform_id) or nil
      local draft_manual_platform_id = normalize_platform_id_input(override_text)
      local apply_button = override_flow["apply-platform-id"]
      local clear_button = override_flow["clear-platform-id"]
      if apply_button then
        apply_button.enabled = current_manual_platform_id ~= draft_manual_platform_id
      end
      if clear_button then
        clear_button.enabled = current_manual_platform_id ~= nil or override_text ~= ""
      end
    end
  elseif entity.name == ORBITAL_SELECTOR_NAME then
    local record = panel_context.selector_record
    if type(record) ~= "table" then
      record = root_state.selectors_by_unit[entity.unit_number]
      panel_context.selector_record = record
    end
    local lease = panel_context.selector_lease
    if lease == nil then
      lease = root_state.lease_by_job_id[entity.unit_number]
      panel_context.selector_lease = lease
    end
    local normalized_mode = normalize_selector_mode(record and record.mode)
    local mode_flow = mode_section and mode_section["mode-flow"] or nil
    if mode_flow and record then
      for _, mode_name in ipairs(SELECTOR_MODE_ORDER) do
        local button = mode_flow["mode-" .. mode_name]
        if button then
          button.style = mode_name == normalized_mode and "ei_green_button" or "button"
          button.enabled = mode_name ~= normalized_mode
        end
      end
    end
    local focus_flow = focus_section and focus_section["focus-flow"] or nil
    local focus_field = focus_flow and focus_flow["platform-id"] or nil
    local focus_text = (gui_record and gui_record.draft_selector_platform_id)
      or (record and record.manual_platform_id and tostring(record.manual_platform_id))
      or ""
    if focus_field and focus_field.text ~= focus_text then
      focus_field.text = focus_text
    end
    if focus_flow then
      local manual_mode_active = normalized_mode == MODE_MANUAL
      local current_manual_platform_id = tonumber(record and record.manual_platform_id) or nil
      local draft_manual_platform_id = normalize_platform_id_input(focus_text)
      if focus_field then
        focus_field.enabled = manual_mode_active
      end
      local apply_button = focus_flow["apply-selector-platform"]
      local clear_button = focus_flow["clear-selector-platform"]
      if apply_button then
        apply_button.enabled = manual_mode_active and current_manual_platform_id ~= draft_manual_platform_id
      end
      if clear_button then
        clear_button.enabled = manual_mode_active and (current_manual_platform_id ~= nil or focus_text ~= "")
      end
    end
    local release_button = focus_section and focus_section["release-selector-lease"] or nil
    if release_button then
      release_button.enabled = lease ~= nil
    end
  elseif entity.name == ORBITAL_COORDINATOR_NAME then
    local coordinator_section = root.body["coordinator-section"]
    local control_flow = coordinator_section and coordinator_section["coordinator-flow"] or nil
    if control_flow then
      local refresh_pending = panel_context.coordinator_refresh_pending
      local rescan_pending = panel_context.coordinator_rescan_pending
      local refresh_button = control_flow["refresh-cohort"]
      local rescan_button = control_flow["rescan-runtime"]
      if refresh_button then
        refresh_button.enabled = not refresh_pending
        refresh_button.tooltip = refresh_pending
          and gui_locale("orbital-logistics-gui-refresh-cohort-pending-tooltip")
          or gui_locale("orbital-logistics-gui-refresh-cohort-tooltip")
      end
      if rescan_button then
        rescan_button.enabled = not rescan_pending
        rescan_button.tooltip = rescan_pending
          and gui_locale("orbital-logistics-gui-rescan-runtime-pending-tooltip")
          or gui_locale("orbital-logistics-gui-rescan-runtime-tooltip")
      end
    end
  elseif entity.name == ORBITAL_DISPATCH_UPLINK_NAME then
    local record = panel_context.uplink_record
    local skip_binding_controls = panel_context.skip_uplink_binding_controls == true
    if type(record) ~= "table" then
      record = root_state.uplinks_by_unit[entity.unit_number]
      panel_context.uplink_record = record
    end
    local binding_section = root.body["binding-section"]
    local oversize_section = root.body["oversize-section"]
    local silo_dropdown = binding_section and binding_section["silo-dropdown"] or nil
    local current_binding_silo_unit_number = tonumber(record and record.binding_silo_unit_number) or 0
    local current_binding_source = record and record.binding_source or nil
    local preferred_adjacent_unit_number = type(record) == "table"
      and type(record.silo_dropdown_cache) == "table"
      and (tonumber(record.silo_dropdown_cache.preferred_adjacent_unit_number) or 0)
      or 0
    local selected_silo_unit_number = (gui_record and gui_record.draft_binding_silo_unit_number)
      or current_binding_silo_unit_number
      or 0
    if silo_dropdown and not skip_binding_controls then
      local values, refreshed_selected_silo_unit_number, refreshed_preferred_adjacent_unit_number = refresh_uplink_dropdown(
        silo_dropdown,
        entity,
        entity.unit_number,
        selected_silo_unit_number,
        record
      )
      if type(values) == "table" then
        selected_silo_unit_number = tonumber(refreshed_selected_silo_unit_number) or 0
        preferred_adjacent_unit_number = tonumber(refreshed_preferred_adjacent_unit_number) or preferred_adjacent_unit_number
        panel_context.uplink_dropdown_values = values
        panel_context.uplink_selected_silo_unit_number = selected_silo_unit_number
        panel_context.uplink_preferred_adjacent_unit_number = preferred_adjacent_unit_number
      end
    end
    local binding_flow = binding_section and binding_section["binding-flow"] or nil
    if binding_flow and not skip_binding_controls then
      local apply_button = binding_flow["apply-silo-binding"]
      local clear_button = binding_flow["clear-silo-binding"]
      local adjacent_button = binding_flow["adjacent-silo-binding"]
      if apply_button then
        apply_button.enabled = current_binding_silo_unit_number ~= selected_silo_unit_number
          or (selected_silo_unit_number ~= 0 and current_binding_source ~= "manual")
      end
      if clear_button then
        clear_button.enabled = current_binding_silo_unit_number ~= 0 or selected_silo_unit_number ~= 0
      end
      if adjacent_button then
        adjacent_button.enabled = preferred_adjacent_unit_number ~= current_binding_silo_unit_number
          or (current_binding_source ~= "adjacent" and preferred_adjacent_unit_number ~= 0)
      end
    end
    local threshold_flow = oversize_section and oversize_section["threshold-flow"] or nil
    local threshold_field = threshold_flow and threshold_flow["threshold-floor"] or nil
    local threshold_text = (gui_record and gui_record.draft_threshold_floor)
      or tostring(record and record.threshold_floor or 0)
    if threshold_field and threshold_field.text ~= threshold_text then
      threshold_field.text = threshold_text
    end
    local oversize_flow = oversize_section and oversize_section["oversize-flow"] or nil
    local normalized_oversize_mode = normalize_oversize_mode(record and record.oversize_mode)
    local threshold_mode_active = normalized_oversize_mode == OVERSIZE_THRESHOLD
    if oversize_flow and record then
      for _, mode_name in ipairs(OVERSIZE_MODE_ORDER) do
        local button = oversize_flow["oversize-" .. mode_name]
        if button then
          button.style = mode_name == normalized_oversize_mode and "ei_green_button" or "button"
          button.enabled = mode_name ~= normalized_oversize_mode
        end
      end
    end
    if threshold_flow then
      if threshold_field then
        threshold_field.enabled = threshold_mode_active
      end
      local apply_button = threshold_flow["apply-threshold-floor"]
      if apply_button then
        local draft_threshold_floor = normalize_threshold_floor_input(threshold_text)
        local current_threshold_floor = normalize_threshold_floor_input(record and record.threshold_floor or 0)
        apply_button.enabled = threshold_mode_active
          and draft_threshold_floor ~= current_threshold_floor
      end
    end
    local release_button = binding_section and binding_section["release-uplink-lease"] or nil
    if release_button then
      release_button.enabled = record and record.leased_job_id ~= nil
    end
  end

  if panel_context.skip_uplink_binding_controls ~= true then
    sync_player_uplink_silo_overlays(player, entity, panel_context)
  end
end

function model.refresh_player_gui(player, entity_override, panel_context)
  if not (player and player.valid) then
    return
  end

  local seeded_panel_context = type(panel_context) == "table" and panel_context or nil
  local entity = seeded_panel_context and ei_lib.get_valid_entity(seeded_panel_context.entity) or nil
  if not is_cohort_entity(entity) then
    entity = ei_lib.get_valid_entity(entity_override)
  end
  if not is_cohort_entity(entity) then
    entity = get_opened_cohort_entity(player.index)
  end
  if not ei_lib.entity_check(entity) then
    entity = get_player_opened_cohort_entity(player)
    if ei_lib.entity_check(entity) then
      set_gui_record(player.index, entity.unit_number, get_preferred_gui_mode(player, entity), entity)
    end
  end
  if not ei_lib.entity_check(entity) then
    close_player_gui(player)
    set_gui_record(player.index, nil)
    return
  end

  local gui_record = get_gui_record(player.index)
  local root = get_player_gui_root(player) or build_player_gui(player, entity, gui_record and gui_record.gui_mode or get_preferred_gui_mode(player, entity))
  if not root or not root.body or not root.body.summary or not root.body.details or not root.body.hint then
    return
  end
  local root_state = (seeded_panel_context and seeded_panel_context.root_state) or get_root()
  local cohort = seeded_panel_context and seeded_panel_context.cohort or nil
  if type(cohort) ~= "table" then
    cohort = ensure_cohort(entity.force.index, entity.surface.name)
  end
  -- Full refresh and control refresh both only need root_state plus seeded
  -- records, so normalize the panel handoff once and keep the branches simple.
  panel_context = seed_panel_context(seeded_panel_context or {}, entity, root_state, cohort)

  local root_mode = normalize_gui_mode(root.tags and root.tags.gui_mode)
  if not gui_record
    or gui_record.unit_number ~= entity.unit_number
    or gui_record.gui_mode ~= root_mode
    or gui_record.force_index ~= entity.force.index
    or gui_record.surface_name ~= entity.surface.name
  then
    set_gui_record(player.index, entity.unit_number, root_mode, entity)
    gui_record = get_gui_record(player.index)
  end

  if entity.name == PLATFORM_TRANSPONDER_NAME then
    local record = panel_context.transponder_record
    if type(record) ~= "table" then
      record = root_state.transponders_by_unit[entity.unit_number]
      panel_context.transponder_record = record
    end
    local power_state = cohort_power.get_record_state(record)
    local power_active = cohort_power.is_active_state(power_state)
    local platform = read_platform_from_transponder(entity)
    local valid = power_active and record and record.platform_id and not record.conflict and record.dispatch_surface_name and platform and platform.valid
    local state = not power_active and "invalid" or (record and record.conflict and "conflict" or (valid and "ready" or "invalid"))
    local override_source = record and record.manual_platform_id and gui_value("manual-override") or gui_value("auto-assigned")
    local live_link = platform and platform.valid and gui_value("connected") or gui_value("missing")
    set_gui_caption(root.body, "summary", {"", {"exotic-industries.orbital-logistics-gui-platform-id"}, ": ", gui_text(record and record.platform_id or nil), " | ", gui_state_text(state, not power_active and "no-power" or nil)})
    set_gui_caption(root.body, "details", make_gui_caption({
      gui_detail_line("orbital-logistics-gui-detail-platform", gui_text(record and record.platform_name or nil)),
      gui_detail_line("orbital-logistics-gui-detail-dispatch-surface", gui_text(record and record.dispatch_surface_name or nil)),
      gui_detail_line("orbital-logistics-gui-detail-override-source", override_source),
      gui_detail_line("orbital-logistics-gui-detail-conflict", record and record.conflict and gui_value("yes") or gui_value("no")),
      gui_detail_line("orbital-logistics-gui-detail-live-link", live_link),
    }))
    set_gui_caption(root.body, "hint", not power_active
      and gui_hint("reason", gui_reason_text("no-power"))
      or (valid and gui_hint("transponder-ready") or (record and record.conflict and gui_hint("transponder-conflict") or gui_hint("transponder-place"))))
  elseif entity.name == ORBITAL_SELECTOR_NAME then
    local record = panel_context.selector_record
    if type(record) ~= "table" then
      record = root_state.selectors_by_unit[entity.unit_number]
      panel_context.selector_record = record
    end
    local job = get_selector_job_record(cohort, entity.unit_number)
    local power_state = cohort_power.get_record_state(record)
    local power_active = cohort_power.is_active_state(power_state)
    local mode = normalize_selector_mode(record and record.mode)
    local reason = not power_active and "no-power" or (job and (job.state == "invalid" and job.invalid_reason or job.blocked_reason) or nil)
    local lease = panel_context.selector_lease
    if lease == nil then
      lease = root_state.lease_by_job_id[entity.unit_number]
      panel_context.selector_lease = lease
    end
    local lease_text = lease and gui_value("uplink", tostring(lease.uplink_unit_number or 0)) or gui_value("open")
    set_gui_caption(root.body, "summary", {"", {"exotic-industries.orbital-logistics-gui-mode-label"}, ": ", {"exotic-industries.orbital-logistics-gui-selector-mode-" .. mode}, " | ", gui_state_text((not power_active and "blocked") or (job and job.state or nil), reason)})
    set_gui_caption(root.body, "details", make_gui_caption({
      gui_detail_line("orbital-logistics-gui-detail-target-id", gui_text(job and job.target_platform_id or record and record.manual_platform_id or nil)),
      gui_detail_line("orbital-logistics-gui-detail-target-platform", gui_text(job and job.platform_name or nil)),
      gui_detail_line("orbital-logistics-gui-detail-need-total", gui_text(job and job.total_count or 0)),
      gui_detail_line("orbital-logistics-gui-detail-state", gui_state_text((not power_active and "blocked") or (job and job.state or nil), reason)),
      gui_detail_line("orbital-logistics-gui-detail-lease", lease_text),
    }))
    set_gui_caption(root.body, "hint", not power_active
      and gui_hint("reason", gui_reason_text("no-power"))
      or (job and job.state == "ready"
      and (lease and gui_hint("selector-ready-leased") or gui_hint("selector-ready-open"))
      or (job and job.state == "invalid"
        and gui_hint("reason", gui_reason_text(job.invalid_reason))
        or ((mode == MODE_MANUAL and gui_hint("selector-manual"))
          or (mode == MODE_CIRCUIT and gui_hint("selector-circuit"))
          or gui_hint("selector-policy")))))
  elseif entity.name == ORBITAL_COORDINATOR_NAME then
    local snapshot = cohort.last_snapshot or {}
    local power_state = cohort_power.get_record_state(panel_context.coordinator_record or {unit_number = entity.unit_number})
    local power_active = cohort_power.is_active_state(power_state)
    local active = power_active and cohort.active_coordinator_unit_number == entity.unit_number
    local refresh_pending = panel_context.coordinator_refresh_pending
    local rescan_pending = panel_context.coordinator_rescan_pending
    local ready_count = tonumber(snapshot.ready_job_count) or 0
    local blocked_count = tonumber(snapshot.blocked_job_count)
    local invalid_count = tonumber(snapshot.invalid_job_count)
    if blocked_count == nil or invalid_count == nil then
      local _, fallback_blocked_count, fallback_invalid_count = count_jobs_by_state(cohort.jobs_by_id)
      blocked_count = blocked_count or fallback_blocked_count
      invalid_count = invalid_count or fallback_invalid_count
    end
    local selector_count = tonumber(snapshot.selector_count) or count_map(cohort.selector_units)
    local uplink_count = tonumber(snapshot.uplink_count) or count_map(cohort.uplink_units)
    local scanner_summary = snapshot.scanner_summary or nil
    set_gui_caption(root.body, "summary", {"", {"exotic-industries.orbital-logistics-gui-coordinator-label"}, ": ", gui_text(cohort.active_coordinator_unit_number or nil), " | ", power_active and (active and gui_value("active") or gui_state_text("standby")) or gui_reason_text("no-power")})
    set_gui_caption(root.body, "details", make_gui_caption({
      gui_detail_line("orbital-logistics-gui-detail-role", power_active and (active and gui_value("active") or gui_value("standby")) or gui_reason_text("no-power")),
      gui_line("jobs", gui_text(ready_count), gui_text(blocked_count), gui_text(invalid_count)),
      gui_detail_line("orbital-logistics-gui-detail-blocked-lanes", gui_text(snapshot.blocked_lane_count or 0)),
      gui_detail_line("orbital-logistics-gui-detail-registry-count", gui_text(snapshot.registry_count or 0)),
      gui_line("selectors-uplinks", gui_text(selector_count), gui_text(uplink_count)),
      scanner_summary and gui_line("scanner", gui_text(scanner_summary.bank_count or 0), gui_text(scanner_summary.platform_count or 0), scanner_summary.hot_interest and gui_value("yes") or gui_value("no")) or nil,
    }))
    if not power_active then
      set_gui_caption(root.body, "hint", gui_hint("reason", gui_reason_text("no-power")))
    elseif rescan_pending then
      set_gui_caption(root.body, "hint", gui_hint("coordinator-rescan-pending"))
    elseif refresh_pending then
      set_gui_caption(root.body, "hint", gui_hint("coordinator-refresh-pending"))
    else
      set_gui_caption(root.body, "hint", active and (ready_count > 0 and gui_hint("coordinator-active-ready") or gui_hint("coordinator-active-idle")) or gui_hint("coordinator-standby"))
    end
  else
    local record = panel_context.uplink_record
    local power_state = cohort_power.get_record_state(record)
    local power_active = cohort_power.is_active_state(power_state)
    local job = get_uplink_job_record(cohort, record)
    local bound_silo = panel_context.bound_silo ~= false and panel_context.bound_silo or nil
    local block_reason = not power_active and "no-power" or (cohort.blocked_lanes and cohort.blocked_lanes[entity.unit_number] or nil)
    local summary_state = "blocked"
    if not power_active then
      summary_state = "blocked"
    elseif not bound_silo then
      summary_state = "missing-silo"
    elseif not cohort.active_coordinator_unit_number then
      summary_state = "blocked"
      block_reason = block_reason or "no-active-coordinator"
    elseif job and job.state == "ready" then
      summary_state = "ready"
    elseif job and job.state == "invalid" then
      summary_state = "invalid"
      block_reason = job.invalid_reason
    else
      block_reason = block_reason or (job and job.blocked_reason) or "no-ready-job"
    end

    local binding_source = record and record.binding_source == "adjacent"
      and gui_value("adjacent")
      or (record and record.binding_source == "manual" and gui_value("manual") or gui_text(nil))
    local threshold_mode = {"exotic-industries.orbital-logistics-gui-oversize-" .. normalize_oversize_mode(record and record.oversize_mode)}

    local bound_silo_text = bound_silo and gui_text(bound_silo.unit_number) or gui_locale("orbital-logistics-gui-silo-none")
    set_gui_caption(root.body, "summary", {"", {"exotic-industries.orbital-logistics-gui-binding-label"}, ": ", bound_silo_text, " | ", gui_state_text(summary_state, block_reason)})
    set_gui_caption(root.body, "details", make_gui_caption({
      gui_detail_line("orbital-logistics-gui-detail-binding-source", binding_source),
      gui_detail_line("orbital-logistics-gui-detail-bound-silo", bound_silo_text),
      gui_detail_line("orbital-logistics-gui-detail-lease", gui_text(record and record.leased_job_id or nil)),
      gui_detail_line("orbital-logistics-gui-detail-target-id", gui_text(job and job.target_platform_id or nil)),
      gui_detail_line("orbital-logistics-gui-detail-target-platform", gui_text(job and job.platform_name or nil)),
      gui_detail_line("orbital-logistics-gui-detail-need-total", gui_text(job and job.total_count or 0)),
      gui_line("threshold", gui_text(record and record.threshold_floor or 0), threshold_mode),
    }))
    set_gui_caption(root.body, "hint", summary_state == "ready" and gui_hint("uplink-ready") or gui_hint("uplink-blocked", gui_reason_text(block_reason)))
  end

  refresh_player_gui_controls(player, entity, panel_context)

  set_gui_seen_signatures(
    player.index,
    cohort.last_signature,
    entity.name == ORBITAL_COORDINATOR_NAME and cohort.last_snapshot_signature or nil
  )
end

function model.open_gui(player, entity_hint)
  if not (player and player.valid) then
    return
  end

  model.check_init(false)

  local entity = resolve_requested_cohort_entity(player, entity_hint)
  if not entity then
    model.close_gui(player)
    return
  end

  local gui_mode = get_preferred_gui_mode(player, entity)
  local gui_record = get_gui_record(player.index)
  local root = get_player_gui_root(player)
  local root_mode = normalize_gui_mode(root and root.tags and root.tags.gui_mode)
  local rebuilt_root = not (root and root.valid and gui_record and gui_record.unit_number == entity.unit_number and root_mode == gui_mode)
  if rebuilt_root then
    -- Reopen the same cohort panel in place when nothing material changed.
    root = build_player_gui(player, entity, gui_mode)
    root_mode = normalize_gui_mode(root and root.tags and root.tags.gui_mode)
  end
  set_gui_record(player.index, entity.unit_number, root_mode or gui_mode, entity)
  -- The full refresh path can seed its own root/cohort handoff from the entity
  -- we already resolved here, so opening a panel does not need a throwaway
  -- one-field context table first.
  model.refresh_player_gui(player, entity)
  if rebuilt_root then
    queue_cohort(entity.force.index, entity.surface.name)
  end
end

function model.close_gui(player)
  if player and player.valid then
    set_gui_record(player.index, nil)
    close_player_gui(player)
  end
end

function model.on_player_left_game(player_index)
  destroy_player_uplink_silo_overlays(player_index)
  set_gui_record(player_index, nil)
end

function model.on_gui_click(event)
  local player = event and event.player_index and game.get_player(event.player_index) or nil
  local element = event and event.element or nil
  if not player or not (element and element.valid) then
    return
  end

  local action = element.tags and element.tags.action or nil
  if action == "goto-informatron" then
    remote.call("informatron", "informatron_open_to_page", player.index, "exotic-industries-informatron", "orbital_scanner")
    return
  elseif action == "close-gui" then
    model.close_gui(player)
    return
  elseif not action then
    return
  end

  local entity = get_opened_cohort_entity(player.index)
  if not ei_lib.entity_check(entity) then
    return
  end

  local current_tick = event and event.tick or game and game.tick or 0
  local root = get_player_gui_root(player)
  local root_state = get_root()
  local panel_context = seed_panel_context({}, entity, root_state)
  local uplink_record = entity.name == ORBITAL_DISPATCH_UPLINK_NAME
    and panel_context.uplink_record
    or nil
  local should_refresh = true
  if not root or not root.body then
    return
  end
  -- Click-driven actions often bounce between the same panel sections while the
  -- player is editing live drafts, so cache the section roots once here
  -- instead of tree-walking the same control paths per branch.
  local override_section = root.body["override-section"]
  local focus_section = root.body["focus-section"]
  local binding_section = root.body["binding-section"]
  local oversize_section = root.body["oversize-section"]

  if action == "apply-platform-id" then
    local override_flow = override_section and override_section["override-flow"] or nil
    local textfield = override_flow and override_flow["platform-id"] or nil
    local raw_text = textfield and textfield.text or nil
    set_gui_draft_value(player.index, "draft_override_platform_id", nil)
    set_transponder_manual_platform_id(entity.unit_number, raw_text, current_tick)
  elseif action == "clear-platform-id" then
    set_gui_draft_value(player.index, "draft_override_platform_id", nil)
    set_transponder_manual_platform_id(entity.unit_number, nil, current_tick)
  elseif action == "refresh-cohort" then
    queue_cohort(entity.force.index, entity.surface.name)
    panel_context.coordinator_refresh_pending = true
    refresh_player_gui_controls(player, entity, panel_context)
    should_refresh = false
  elseif action == "rescan-runtime" then
    if player.admin then
      model.request_runtime_rescan("gui-admin", current_tick)
      panel_context.coordinator_rescan_pending = true
    end
    refresh_player_gui_controls(player, entity, panel_context)
    should_refresh = false
  elseif action == "set-selector-mode" then
    local _, changed = set_selector_qc_target(entity.unit_number, element.tags.mode, nil, current_tick)
    should_refresh = changed
  elseif action == "apply-selector-platform" then
    local focus_flow = focus_section and focus_section["focus-flow"] or nil
    local textfield = focus_flow and focus_flow["platform-id"] or nil
    local raw_text = textfield and textfield.text or nil
    set_gui_draft_value(player.index, "draft_selector_platform_id", nil)
    set_selector_qc_target(entity.unit_number, nil, raw_text, current_tick)
  elseif action == "clear-selector-platform" then
    set_gui_draft_value(player.index, "draft_selector_platform_id", nil)
    set_selector_qc_target(entity.unit_number, nil, false, current_tick)
  elseif action == "release-selector-lease" then
    local lease = root_state.lease_by_job_id[entity.unit_number]
    local uplink_record = lease and root_state.uplinks_by_unit[lease.uplink_unit_number] or nil
    if uplink_record then
      release_uplink_lease(uplink_record)
      queue_cohort(uplink_record.force_index, uplink_record.surface_name)
    else
      queue_cohort(entity.force.index, entity.surface.name)
    end
  elseif action == "apply-silo-binding" then
    local dropdown = binding_section and binding_section["silo-dropdown"] or nil
    local values = dropdown and dropdown.tags and dropdown.tags.values or nil
    local selected_index = dropdown and dropdown.selected_index or 1
    local silo_unit_number = values and values[selected_index] or nil
    set_gui_draft_value(player.index, "draft_binding_silo_unit_number", nil)
    set_uplink_binding(entity.unit_number, silo_unit_number, "manual")
    local bound_silo = get_entity_by_unit_number(tonumber(silo_unit_number) or 0)
    if ei_lib.entity_check(bound_silo) and bound_silo.type == "rocket-silo" then
      panel_context.bound_silo = bound_silo
    else
      panel_context.bound_silo = nil
    end
  elseif action == "clear-silo-binding" then
    set_gui_draft_value(player.index, "draft_binding_silo_unit_number", nil)
    set_uplink_binding(entity.unit_number, nil, "manual")
    panel_context.bound_silo = false
  elseif action == "adjacent-silo-binding" then
    local nearest = nil
    if uplink_record and type(uplink_record.silo_dropdown_cache) == "table" then
      local preferred_adjacent_unit_number = tonumber(uplink_record.silo_dropdown_cache.preferred_adjacent_unit_number) or 0
      if preferred_adjacent_unit_number ~= 0 then
        local cached_nearest = get_entity_by_unit_number(preferred_adjacent_unit_number)
        if ei_lib.entity_check(cached_nearest)
          and cached_nearest.type == "rocket-silo"
          and cached_nearest.force.index == entity.force.index
          and cached_nearest.surface.name == entity.surface.name
        then
          nearest = cached_nearest
        end
      end
    end
    if not nearest then
      nearest = find_preferred_adjacent_silo(entity, entity.unit_number) or find_adjacent_silos(entity)[1]
    end
    set_gui_draft_value(player.index, "draft_binding_silo_unit_number", nil)
    set_uplink_binding(entity.unit_number, nearest and nearest.unit_number or nil, "adjacent")
    panel_context.bound_silo = nearest or false
  elseif action == "release-uplink-lease" then
    if uplink_record then
      release_uplink_lease(uplink_record)
      queue_cohort(uplink_record.force_index, uplink_record.surface_name)
    end
  elseif action == "set-oversize-mode" then
    if uplink_record then
      local _, changed = set_uplink_oversize_mode(entity.unit_number, element.tags.mode, uplink_record.threshold_floor, current_tick)
      should_refresh = changed
    end
  elseif action == "apply-threshold-floor" then
    local threshold_flow = oversize_section and oversize_section["threshold-flow"] or nil
    local textfield = threshold_flow and threshold_flow["threshold-floor"] or nil
    if uplink_record then
      set_gui_draft_value(player.index, "draft_threshold_floor", nil)
      set_uplink_oversize_mode(entity.unit_number, uplink_record.oversize_mode, textfield and textfield.text or 0, current_tick)
    end
  end

  if should_refresh then
    model.refresh_player_gui(player, entity, panel_context)
  end
end

function model.on_gui_selection_state_changed(event)
  local element = event and event.element or nil
  if not (element and element.valid) then
    return
  end
  if (element.tags and element.tags.parent_gui) ~= GUI_NAME then
    return
  end
  local player = event and event.player_index and game.get_player(event.player_index) or nil
  if not player then
    return
  end
  if element.name == "silo-dropdown" then
    local entity = get_opened_cohort_entity(player.index)
    if not (ei_lib.entity_check(entity) and entity.name == ORBITAL_DISPATCH_UPLINK_NAME) then
      return
    end
    local values = element.tags and element.tags.values or nil
    local selected_unit_number = type(values) == "table" and values[element.selected_index] or 0
    if set_gui_draft_value(player.index, "draft_binding_silo_unit_number", tonumber(selected_unit_number) or 0) then
      refresh_player_gui_controls(player, entity)
    end
    return
  end

  -- The cohort GUI currently has one intentional selection widget. Ignore any
  -- other selection-state noise instead of repainting the full console.
end

function model.on_gui_text_changed(event)
  local element = event and event.element or nil
  if not (element and element.valid) then
    return
  end
  if (element.tags and element.tags.parent_gui) ~= GUI_NAME then
    return
  end

  local player = event and event.player_index and game.get_player(event.player_index) or nil
  if not player then
    return
  end

  if element.name ~= "platform-id" and element.name ~= "threshold-floor" then
    return
  end

  local entity = get_opened_cohort_entity(player.index)
  if not ei_lib.entity_check(entity) then
    return
  end

  if entity.name == PLATFORM_TRANSPONDER_NAME and element.name == "platform-id" then
    if not set_gui_draft_value(player.index, "draft_override_platform_id", element.text or "") then
      return
    end
    refresh_player_gui_controls(player, entity)
    return
  elseif entity.name == ORBITAL_SELECTOR_NAME and element.name == "platform-id" then
    if not set_gui_draft_value(player.index, "draft_selector_platform_id", element.text or "") then
      return
    end
    refresh_player_gui_controls(player, entity)
    return
  elseif entity.name == ORBITAL_DISPATCH_UPLINK_NAME and element.name == "threshold-floor" then
    if not set_gui_draft_value(player.index, "draft_threshold_floor", element.text or "") then
      return
    end
    refresh_player_gui_controls(player, entity, {skip_uplink_binding_controls = true})
    return
  else
    return
  end
end

function model.on_built_entity(event)
  local entity = event and event.entity or nil
  if not ei_lib.entity_check(entity) then
    return
  end

  local current_tick = event and event.tick or game and game.tick or 0
  if entity.type == "rocket-silo" then
    invalidate_surface_uplink_dropdown_caches(entity.force.index, entity.surface.name)
    queue_cohort(entity.force.index, entity.surface.name)
  elseif entity.name == PLATFORM_TRANSPONDER_NAME then
    register_transponder(entity, current_tick)
  elseif entity.name == ORBITAL_SELECTOR_NAME then
    register_selector(entity, current_tick)
  elseif entity.name == ORBITAL_COORDINATOR_NAME then
    register_coordinator(entity, current_tick)
  elseif entity.name == ORBITAL_DISPATCH_UPLINK_NAME then
    register_uplink(entity, current_tick)
  end
end

function model.on_destroyed_entity(event)
  local entity = event and event.entity or nil
  if not entity or not entity.valid or not entity.unit_number then
    return
  end

  destroy_uplink_silo_overlays_for_unit(entity.unit_number)

  if entity.type == "rocket-silo" then
    local root = get_root()
    local uplink_unit_number = root.uplink_by_silo_unit[entity.unit_number]
    if uplink_unit_number then
      local record = root.uplinks_by_unit[uplink_unit_number]
      if record then
        clear_uplink_runtime_binding(record, true)
        queue_cohort(record.force_index, record.surface_name)
      else
        root.uplink_by_silo_unit[entity.unit_number] = nil
      end
    end
    invalidate_surface_uplink_dropdown_caches(entity.force.index, entity.surface.name)
    queue_cohort(entity.force.index, entity.surface.name)
  end

  if entity.name == PLATFORM_TRANSPONDER_NAME then
    remove_transponder(entity.unit_number)
  elseif entity.name == ORBITAL_SELECTOR_NAME then
    remove_selector(entity.unit_number)
  elseif entity.name == ORBITAL_COORDINATOR_NAME then
    remove_coordinator(entity.unit_number)
  elseif entity.name == ORBITAL_DISPATCH_UPLINK_NAME then
    remove_uplink(entity.unit_number)
  end
end

local function refresh_transponders_for_platform(platform, current_tick)
  if not (platform and platform.valid) then
    return false
  end

  local queued = false
  for _, record in ipairs(get_platform_transponder_records(platform.force.index, platform.index)) do
    local previous_platform_name = record.platform_name
    local previous_dispatch_surface_name = record.dispatch_surface_name
    local previous_hub_unit_number = record.hub_unit_number
    record.platform_name = platform.name
    record.dispatch_surface_name = get_platform_surface_name(platform)
    record.hub_unit_number = platform.hub and platform.hub.valid and platform.hub.unit_number or nil
    record.last_seen_tick = now_tick(current_tick)
    sync_transponder_dispatch_indexes(record, record.force_index, record.platform_index, previous_dispatch_surface_name, previous_hub_unit_number)
    if previous_platform_name ~= record.platform_name
      or previous_dispatch_surface_name ~= record.dispatch_surface_name
      or previous_hub_unit_number ~= record.hub_unit_number
    then
      queued = mark_cohort_dirty(record.force_index, record.surface_name) or queued
      if previous_dispatch_surface_name and previous_dispatch_surface_name ~= record.surface_name then
        queued = mark_cohort_dirty(record.force_index, previous_dispatch_surface_name) or queued
      end
      if record.dispatch_surface_name and record.dispatch_surface_name ~= record.surface_name then
        queued = mark_cohort_dirty(record.force_index, record.dispatch_surface_name) or queued
      end
    end
  end

  return queued
end

function model.on_entity_logistic_slot_changed(event)
  if not event or not ei_lib.entity_check(event.entity) or event.entity.type ~= "space-platform-hub" then
    return
  end

  queue_hub_dispatch_cohorts(event.entity.force.index, event.entity.unit_number)
end

function model.on_entity_settings_pasted(event)
  if not event or not ei_lib.entity_check(event.destination) then
    return
  end

  if event.destination.name == PLATFORM_TRANSPONDER_NAME then
    register_transponder(event.destination, event.tick)
  elseif event.destination.name == ORBITAL_SELECTOR_NAME then
    register_selector(event.destination, event.tick)
  elseif event.destination.name == ORBITAL_COORDINATOR_NAME then
    register_coordinator(event.destination, event.tick)
  elseif event.destination.name == ORBITAL_DISPATCH_UPLINK_NAME then
    register_uplink(event.destination, event.tick)
  elseif event.destination.type == "space-platform-hub" then
    queue_hub_dispatch_cohorts(event.destination.force.index, event.destination.unit_number)
  end
end

function model.on_space_platform_changed_state(event)
  local platform = event and event.platform or nil
  if platform and platform.valid then
    refresh_transponders_for_platform(platform, event and event.tick or (game and game.tick) or 0)
    queue_platform_dispatch_cohorts(platform.force.index, platform.index)
  end
end

function model.on_rocket_launch_ordered(event)
  if not event or not ei_lib.entity_check(event.rocket_silo) then
    return
  end

  local uplink_unit_number = get_root().uplink_by_silo_unit[event.rocket_silo.unit_number]
  if not uplink_unit_number then
    return
  end

  local uplink_record = get_root().uplinks_by_unit[uplink_unit_number]
  if not uplink_record then
    return
  end

  if uplink_record.oversize_mode == OVERSIZE_SINGLE_SHOT then
    release_uplink_lease(uplink_record)
  end

  mark_cohort_dirty(uplink_record.force_index, uplink_record.surface_name)
end

return model
