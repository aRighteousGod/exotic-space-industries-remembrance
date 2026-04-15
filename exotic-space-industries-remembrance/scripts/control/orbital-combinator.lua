--==============================================================================
-- ESIR FILE MAP
-- owns: orbital combinator and platform bank mirroring
-- loaded_by: exotic-space-industries-remembrance\control.lua
-- cadence: init/config, build/destroy, logistic slot change, settings paste, platform state change, cargo pod lifecycle, object destroyed, gui, and scheduled tick step 5
-- forwarded_events: add, check_init, entity_check, get_bank_count, on_cargo_pod_delivered_cargo, on_cargo_pod_finished_ascending, on_cargo_pod_started_ascending, on_destroyed_entity, on_entity_logistic_slot_changed, on_entity_settings_pasted, on_gui_click, on_gui_closed, on_gui_opened, on_object_destroyed, on_rocket_launch_ordered, on_space_platform_changed_state, rebuild_banks, rem, update, update_orbital_bank
-- storage_roots: storage.ei
-- gui_ids: ei-orbital-combinator-console
-- remote_interfaces: none
-- rebuild_on: init, configuration change, platform topology changes, combinator topology changes
--==============================================================================
local ei_runtime_scheduler = require("lib/runtime-scheduler")

local model = {}

local ORBITAL_COMBINATOR_NAME = "ei-orbital-combinator"
local SPACE_PLATFORM_HUB_ENTITY_TYPE = "space-platform-hub"
local OVERFLOW_SECTION_GROUP = "Scanner overflow"
local DEFAULT_MEMBER_SLOT_CAPACITY = 10000
local PLATFORM_RECONCILE_INTERVAL = 300
local BANK_CONNECTION_AUDIT_INTERVAL = 60
local COLD_BANK_AUDIT_INTERVAL = 1800
local BANK_HOT_TICKS = 1800
local HOT_BANK_PLATFORM_POLL_INTERVAL = 12
local HOT_SURFACE_AUDIT_SLICE = 4
local COLD_SURFACE_AUDIT_SLICE = 2
local RECONCILE_PLATFORM_SLICE = 8
local ORBITAL_RUNTIME_STATE_VERSION = 3
local GUI_NAME = "ei-orbital-combinator-console"
local MODE_REQUESTS = "requests"
local MODE_ON_THE_WAY = "on_the_way"
local MODE_NEED = "need"
local VALID_MODES = {
  [MODE_REQUESTS] = true,
  [MODE_ON_THE_WAY] = true,
  [MODE_NEED] = true,
}
local EMPTY_FILTERS_SIGNATURE = nil
local ADJACENT_OFFSETS = {
  {x = 2, y = 0},
  {x = -2, y = 0},
  {x = 0, y = 2},
  {x = 0, y = -2},
}
local OVERFLOW_SIGNAL = {
  type = "virtual",
  name = "ei-orbital-overflow",
  quality = "normal",
}
local HOT_DIRTY_BANK_DEADLINE = 1
local COLD_DIRTY_BANK_DEADLINE = COLD_BANK_AUDIT_INTERVAL
local WORK_CLASS_DEFINITIONS = {
  {
    name = "hot_dirty_bank",
    deadline_ticks = HOT_DIRTY_BANK_DEADLINE,
  },
  {
    name = "hot_surface_audit",
    deadline_ticks = HOT_BANK_PLATFORM_POLL_INTERVAL,
  },
  {
    name = "bank_connection_audit",
    deadline_ticks = BANK_CONNECTION_AUDIT_INTERVAL,
  },
  {
    name = "cold_dirty_bank",
    deadline_ticks = COLD_DIRTY_BANK_DEADLINE,
  },
  {
    name = "incremental_reconcile",
    deadline_ticks = PLATFORM_RECONCILE_INTERVAL,
  },
  {
    name = "cold_surface_audit",
    deadline_ticks = COLD_BANK_AUDIT_INTERVAL,
  },
}
local WORK_CLASS_DEFINITION_BY_NAME = {}
local EMPTY_FILTERS = {}
local is_bank_hot
local rebuild_platform_cache_from_world
local get_platform_surface_name
local register_object_for_destroy
local get_bank_members
local audit_bank_wired_state

for order, definition in ipairs(WORK_CLASS_DEFINITIONS) do
  definition.order = order
  WORK_CLASS_DEFINITION_BY_NAME[definition.name] = definition
end


local function get_snapshot_cache_root()
  storage.ei.orbital_combinator_snapshot_cache = storage.ei.orbital_combinator_snapshot_cache or {}
  return storage.ei.orbital_combinator_snapshot_cache
end


local function get_force_by_index(force_index)
  if not game or not force_index then
    return nil
  end

  for _, force in pairs(game.forces or {}) do
    if force and force.valid and force.index == force_index then
      return force
    end
  end

  return nil
end


local function next_collection_entry(collection, previous_key)
  if not collection then
    return nil, nil
  end

  local first_key = nil
  local first_value = nil
  local found_previous = previous_key == nil
  local return_next = previous_key == nil

  for key, value in pairs(collection) do
    if first_key == nil then
      first_key = key
      first_value = value
    end

    if return_next then
      return key, value
    end

    if key == previous_key then
      found_previous = true
      return_next = true
    end
  end

  if previous_key ~= nil and not found_previous then
    return first_key, first_value
  end

  return nil, nil
end


local function clear_snapshot_cache(force_index, surface_name)
  local snapshot_cache = get_snapshot_cache_root()
  if not force_index or not surface_name then
    storage.ei.orbital_combinator_snapshot_cache = {}
    return
  end

  local prefix = tostring(force_index) .. ":" .. tostring(surface_name) .. ":"
  for cache_key in pairs(snapshot_cache) do
    if string.sub(cache_key, 1, #prefix) == prefix then
      snapshot_cache[cache_key] = nil
    end
  end
end


local function is_valid_mode(mode)
  return mode ~= nil and VALID_MODES[mode] == true
end


local function normalize_mode(mode)
  if is_valid_mode(mode) then
    return mode
  end

  return MODE_REQUESTS
end


local function get_surface_generation_key(force_index, surface_name)
  return tostring(force_index or 0) .. ":" .. tostring(surface_name or "")
end


local function get_force_surface_key(force_index, surface_name)
  return get_surface_generation_key(force_index, surface_name)
end


local function get_surface_platform_index_root()
  storage.ei.orbital_combinator_surface_platform_index = storage.ei.orbital_combinator_surface_platform_index or {}
  return storage.ei.orbital_combinator_surface_platform_index
end


local function get_surface_bank_index_root()
  storage.ei.orbital_combinator_surface_bank_index = storage.ei.orbital_combinator_surface_bank_index or {}
  return storage.ei.orbital_combinator_surface_bank_index
end


local function get_surface_state_root()
  storage.ei.orbital_combinator_surface_state = storage.ei.orbital_combinator_surface_state or {}
  return storage.ei.orbital_combinator_surface_state
end


local function get_dirty_bank_queue()
  storage.ei.orbital_combinator_dirty_bank_queue = ei_runtime_scheduler.ensure_queue(storage.ei.orbital_combinator_dirty_bank_queue)
  return storage.ei.orbital_combinator_dirty_bank_queue
end


local function get_bank_audit_queue()
  storage.ei.orbital_combinator_bank_audit_queue = ei_runtime_scheduler.ensure_queue(storage.ei.orbital_combinator_bank_audit_queue)
  return storage.ei.orbital_combinator_bank_audit_queue
end


local function get_hot_surface_queue()
  storage.ei.orbital_combinator_hot_surface_queue = ei_runtime_scheduler.ensure_queue(storage.ei.orbital_combinator_hot_surface_queue)
  return storage.ei.orbital_combinator_hot_surface_queue
end


local function get_cold_surface_queue()
  storage.ei.orbital_combinator_cold_surface_queue = ei_runtime_scheduler.ensure_queue(storage.ei.orbital_combinator_cold_surface_queue)
  return storage.ei.orbital_combinator_cold_surface_queue
end


local function get_reconcile_state()
  storage.ei.orbital_combinator_reconcile_state = storage.ei.orbital_combinator_reconcile_state or {}
  local state = storage.ei.orbital_combinator_reconcile_state
  if state.next_due_tick == nil then
    state.next_due_tick = 0
  end
  if state.cycle == nil then
    state.cycle = 0
  end
  if state.force_cursor == nil then
    state.force_cursor = nil
  end
  if state.platform_cursor == nil then
    state.platform_cursor = nil
  end
  if state.cache_cursor == nil then
    state.cache_cursor = nil
  end
  if state.cleanup_phase == nil then
    state.cleanup_phase = false
  end
  if state.in_progress == nil then
    state.in_progress = false
  end
  return state
end


local function get_work_service_root()
  storage.ei.orbital_combinator_work_service = storage.ei.orbital_combinator_work_service or {}
  local root = storage.ei.orbital_combinator_work_service

  for _, definition in ipairs(WORK_CLASS_DEFINITIONS) do
    local state = root[definition.name]
    if not state then
      state = {}
      root[definition.name] = state
    end

    state.last_served_tick = state.last_served_tick or 0
    state.served_count = state.served_count or 0
    state.deadline_ticks = definition.deadline_ticks
  end

  return root
end


local function get_work_service_state(work_class_name)
  return get_work_service_root()[work_class_name]
end


local function mark_work_class_served(work_class_name, current_tick)
  local state = get_work_service_state(work_class_name)
  state.last_served_tick = current_tick
  state.served_count = (state.served_count or 0) + 1
  state.deadline_ticks = (WORK_CLASS_DEFINITION_BY_NAME[work_class_name] or {}).deadline_ticks or state.deadline_ticks or 0
end


local function ensure_surface_state(force_index, surface_name)
  local surface_key = get_force_surface_key(force_index, surface_name)
  local state_root = get_surface_state_root()
  local state = state_root[surface_key]
  if not state then
    state = {
      force_index = force_index,
      surface_name = surface_name,
      hot_cursor = 1,
      cold_cursor = 1,
      last_hot_audit_tick = 0,
      last_cold_audit_tick = 0,
    }
    state_root[surface_key] = state
  else
    state.force_index = force_index
    state.surface_name = surface_name
    state.hot_cursor = state.hot_cursor or 1
    state.cold_cursor = state.cold_cursor or 1
    state.last_hot_audit_tick = state.last_hot_audit_tick or 0
    state.last_cold_audit_tick = state.last_cold_audit_tick or 0
  end

  return state, surface_key
end


local function ensure_surface_platform_entry(force_index, surface_name)
  local surface_root = get_surface_platform_index_root()
  local surface_key = get_force_surface_key(force_index, surface_name)
  local entry = surface_root[surface_key]
  if not entry then
    entry = {
      force_index = force_index,
      surface_name = surface_name,
      platform_indices = {},
      platform_set = {},
    }
    surface_root[surface_key] = entry
  else
    entry.force_index = force_index
    entry.surface_name = surface_name
    entry.platform_indices = entry.platform_indices or {}
    entry.platform_set = entry.platform_set or {}
  end

  ensure_surface_state(force_index, surface_name)
  return entry, surface_key
end


local function remove_surface_if_empty(surface_key)
  if not surface_key then
    return
  end

  local surface_root = get_surface_platform_index_root()
  local entry = surface_root[surface_key]
  if entry and ei_lib.getn(entry.platform_indices or {}) == 0 then
    surface_root[surface_key] = nil
    get_surface_state_root()[surface_key] = nil
  end
end


local function add_platform_to_surface_index(platform_index, force_index, surface_name)
  if not platform_index or not force_index or not surface_name then
    return nil
  end

  local entry, surface_key = ensure_surface_platform_entry(force_index, surface_name)
  if not entry.platform_set[platform_index] then
    entry.platform_set[platform_index] = true
    entry.platform_indices[#entry.platform_indices + 1] = platform_index
  end

  return surface_key
end


local function remove_platform_from_surface_index(platform_index, surface_key)
  if not platform_index or not surface_key then
    return
  end

  local surface_root = get_surface_platform_index_root()
  local entry = surface_root[surface_key]
  if not entry or not entry.platform_set[platform_index] then
    return
  end

  entry.platform_set[platform_index] = nil
  for index = #entry.platform_indices, 1, -1 do
    if entry.platform_indices[index] == platform_index then
      table.remove(entry.platform_indices, index)
      break
    end
  end

  remove_surface_if_empty(surface_key)
end


local function enqueue_dirty_bank(bank_id)
  if not bank_id then
    return false
  end

  local added
  added, storage.ei.orbital_combinator_dirty_bank_queue = ei_runtime_scheduler.queue_push_unique(get_dirty_bank_queue(), bank_id, bank_id)
  return added == true
end


local function enqueue_bank_audit(bank_id)
  if not bank_id then
    return false
  end

  local added
  added, storage.ei.orbital_combinator_bank_audit_queue = ei_runtime_scheduler.queue_push_unique(get_bank_audit_queue(), bank_id, bank_id)
  return added == true
end


local function enqueue_hot_surface(force_index, surface_name)
  if not force_index or not surface_name then
    return false
  end

  ensure_surface_state(force_index, surface_name)

  local surface_key = get_force_surface_key(force_index, surface_name)
  local added
  added, storage.ei.orbital_combinator_hot_surface_queue = ei_runtime_scheduler.queue_push_unique(get_hot_surface_queue(), surface_key, surface_key)
  return added == true
end


local function enqueue_cold_surface(force_index, surface_name)
  if not force_index or not surface_name then
    return false
  end

  ensure_surface_state(force_index, surface_name)

  local surface_key = get_force_surface_key(force_index, surface_name)
  local added
  added, storage.ei.orbital_combinator_cold_surface_queue = ei_runtime_scheduler.queue_push_unique(get_cold_surface_queue(), surface_key, surface_key)
  return added == true
end


local function get_surface_generations_root()
  storage.ei.orbital_combinator_surface_generations = storage.ei.orbital_combinator_surface_generations or {}
  storage.ei.orbital_combinator_surface_generations[MODE_REQUESTS] = storage.ei.orbital_combinator_surface_generations[MODE_REQUESTS] or {}
  storage.ei.orbital_combinator_surface_generations[MODE_ON_THE_WAY] = storage.ei.orbital_combinator_surface_generations[MODE_ON_THE_WAY] or {}
  storage.ei.orbital_combinator_surface_generations[MODE_NEED] = storage.ei.orbital_combinator_surface_generations[MODE_NEED] or {}
  return storage.ei.orbital_combinator_surface_generations
end


local function get_surface_generation(force_index, surface_name, mode)
  local key = get_surface_generation_key(force_index, surface_name)
  local generations = get_surface_generations_root()[normalize_mode(mode)]
  return generations[key] or 0
end


local function get_generation_token(force_index, surface_name, mode)
  local epoch = storage.ei.orbital_combinator_generation_epoch or 0
  local normalized_mode = normalize_mode(mode)
  return tostring(epoch) .. ":" .. normalized_mode .. ":" .. tostring(get_surface_generation(force_index, surface_name, normalized_mode))
end


local function bump_surface_generations(force_index, surface_name, modes)
  if not force_index or not surface_name then
    return
  end

  local key = get_surface_generation_key(force_index, surface_name)
  local generations_root = get_surface_generations_root()

  for _, mode in ipairs(modes) do
    local normalized_mode = normalize_mode(mode)
    generations_root[normalized_mode][key] = (generations_root[normalized_mode][key] or 0) + 1
  end

  clear_snapshot_cache(force_index, surface_name)
end


local function bump_all_generations()
  storage.ei.orbital_combinator_generation_epoch = (storage.ei.orbital_combinator_generation_epoch or 0) + 1
  clear_snapshot_cache()
end


local function has_registered_banks()
  return storage
    and storage.ei
    and (storage.ei.orbital_combinator_bank_count or 0) > 0
end


function model.entity_check(entity)
  return ei_lib.entity_check(entity)
end


local function is_registered_scanner(entity)
  return model.entity_check(entity) and entity.name == ORBITAL_COMBINATOR_NAME and entity.unit_number ~= nil
end


local function get_signal_name(signal_name)
  if signal_name == nil then
    return nil
  end

  if type(signal_name) == "string" then
    return signal_name
  end

  if signal_name.name then
    return signal_name.name
  end

  return tostring(signal_name)
end


local function get_quality_name(quality)
  if quality == nil then
    return "normal"
  end

  if type(quality) == "string" then
    return quality
  end

  if quality.name then
    return quality.name
  end

  return tostring(quality)
end


local function normalize_signal_id(value)
  if not value then
    return nil
  end

  local signal_name = get_signal_name(value.name)
  if not signal_name then
    return nil
  end

  return {
    type = value.type or "item",
    name = signal_name,
    quality = get_quality_name(value.quality),
  }
end


local function copy_signal_id(value)
  local normalized = normalize_signal_id(value)
  if not normalized then
    return nil
  end

  return {
    type = normalized.type,
    name = normalized.name,
    quality = normalized.quality,
  }
end


local function make_filter(value, min, max)
  local signal = copy_signal_id(value)
  if not signal then
    return nil
  end

  return {
    value = signal,
    min = min,
    max = max,
  }
end


local function signal_key(value)
  return table.concat({
    value.type or "item",
    value.name or "",
    value.quality or "normal",
  }, "|")
end


local function compare_signal_values(a, b)
  if a.type ~= b.type then
    return a.type < b.type
  end
  if a.name ~= b.name then
    return a.name < b.name
  end
  return (a.quality or "normal") < (b.quality or "normal")
end


local function compare_filters(a, b)
  return compare_signal_values(a.value, b.value)
end


local function compare_entities(a, b)
  local pos_a = a.position
  local pos_b = b.position

  if pos_a.y ~= pos_b.y then
    return pos_a.y < pos_b.y
  end
  if pos_a.x ~= pos_b.x then
    return pos_a.x < pos_b.x
  end

  return (a.unit_number or 0) < (b.unit_number or 0)
end


local function compare_platforms(a, b)
  if a.name ~= b.name then
    return a.name < b.name
  end

  return (a.sort_id or 0) < (b.sort_id or 0)
end


local function hash_update(hash, value)
  local text = tostring(value)

  for i = 1, #text do
    hash = ((hash * 33) + string.byte(text, i)) % 4294967296
  end

  return hash
end


local function build_filters_signature(filters)
  local hash = 5381
  hash = hash_update(hash, #filters)

  for _, filter in ipairs(filters) do
    hash = hash_update(hash, filter.value.type or "item")
    hash = hash_update(hash, filter.value.name or "")
    hash = hash_update(hash, filter.value.quality or "normal")
    hash = hash_update(hash, filter.min or 0)
    hash = hash_update(hash, filter.max == nil and "nil" or filter.max)
  end

  return string.format("%08x", hash)
end


EMPTY_FILTERS_SIGNATURE = build_filters_signature(EMPTY_FILTERS)


local function get_grid_coordinate(value)
  return math.floor((value * 2) + 0.5)
end


local function get_position_key_from_xy(grid_x, grid_y)
  return tostring(grid_x) .. ":" .. tostring(grid_y)
end


local function get_position_key(entity)
  local pos = entity.position
  return get_position_key_from_xy(get_grid_coordinate(pos.x), get_grid_coordinate(pos.y))
end


local function sanitize_registered_entities()
  local removed_any = false

  for unit_number, entity in pairs(storage.ei.orbital_combinators) do
    if not is_registered_scanner(entity) or entity.unit_number ~= unit_number then
      storage.ei.orbital_combinators[unit_number] = nil
      removed_any = true
    end
  end

  if removed_any then
    clear_snapshot_cache()
  end

  return removed_any
end


local function rebuild_registry_from_world()
  if not game or not game.surfaces then
    return
  end

  for _, surface in pairs(game.surfaces) do
    for _, entity in pairs(surface.find_entities_filtered{name = ORBITAL_COMBINATOR_NAME}) do
      if is_registered_scanner(entity) then
        storage.ei.orbital_combinators[entity.unit_number] = entity
      end
    end
  end
end


local function get_unit_mode(unit_number)
  if not unit_number then
    return MODE_REQUESTS
  end

  return normalize_mode(storage.ei.orbital_combinator_mode_by_unit[unit_number])
end


local function set_unit_mode(unit_number, mode)
  if unit_number then
    storage.ei.orbital_combinator_mode_by_unit[unit_number] = normalize_mode(mode)
  end
end


local function get_bank_mode(bank)
  return normalize_mode(bank and bank.mode)
end


local function mark_bank_hot(bank, current_tick)
  if not bank then
    return
  end

  bank.hot_until_tick = math.max(bank.hot_until_tick or 0, (current_tick or (game and game.tick) or 0) + BANK_HOT_TICKS)
end


local function clear_bank_gui_tracking(bank)
  if bank then
    bank.open_gui_count = 0
  end
end


local function get_bank_surface(bank)
  if not game or not bank or not bank.surface_index then
    return nil
  end

  return game.surfaces[bank.surface_index]
end


local function invalidate_bank(bank)
  if not bank then
    return
  end

  bank.signature = nil
  bank.input_signature = nil
  bank.last_applied_generation_token = nil
  bank.member_layout_state_signature = nil
  bank.member_layout_signatures = nil
end


local function wake_bank(bank, current_tick)
  if not bank then
    return
  end

  invalidate_bank(bank)
  mark_bank_hot(bank, current_tick)
  enqueue_dirty_bank(bank.id)
  enqueue_bank_audit(bank.id)
  enqueue_hot_surface(bank.force_index, bank.surface_name)
  enqueue_cold_surface(bank.force_index, bank.surface_name)
end


local function wake_surface_banks(force_index, surface_name, current_tick)
  if not force_index or not surface_name then
    return
  end

  local surface_key = get_force_surface_key(force_index, surface_name)
  local bank_ids = get_surface_bank_index_root()[surface_key] or EMPTY_FILTERS
  for _, bank_id in ipairs(bank_ids) do
    local bank = storage.ei.orbital_combinator_banks and storage.ei.orbital_combinator_banks[bank_id] or nil
    if bank then
      wake_bank(bank, current_tick)
    end
  end
end


local function connector_has_external_peer(connector, ignored_owner)
  if not connector or not connector.valid then
    return false
  end

  for _, connection in ipairs(connector.real_connections or {}) do
    local peer = connection.target
    if peer and peer.valid and peer.owner ~= ignored_owner then
      return true
    end
  end

  return false
end


local function entity_has_external_circuit_connection(entity)
  if not model.entity_check(entity) then
    return false
  end

  local ok, connectors = pcall(entity.get_wire_connectors, false)
  if not ok or type(connectors) ~= "table" then
    return false
  end

  for _, connector in pairs(connectors) do
    if connector_has_external_peer(connector, nil) then
      return true
    end
  end

  return false
end


function model.check_init(rebuild_banks)
  if not storage.ei then
    storage.ei = {}
  end

  local needs_platform_rebuild = false
  local force_bank_rebuild = false

  if not storage.ei.orbital_combinators then
    storage.ei.orbital_combinators = {}
  end
  if storage.ei.orbital_combinators_break_point == nil then
    storage.ei.orbital_combinators_break_point = nil
  end

  if not storage.ei.orbital_combinator_banks then
    storage.ei.orbital_combinator_banks = {}
  end
  if not storage.ei.orbital_combinator_bank_by_unit then
    storage.ei.orbital_combinator_bank_by_unit = {}
  end
  if storage.ei.orbital_combinator_bank_count == nil then
    storage.ei.orbital_combinator_bank_count = 0
  end
  if not storage.ei.orbital_combinator_mode_by_unit then
    storage.ei.orbital_combinator_mode_by_unit = {}
  end
  if not storage.ei.orbital_combinator_open_gui_by_player then
    storage.ei.orbital_combinator_open_gui_by_player = {}
  end
  if not storage.ei.orbital_combinator_platform_cache then
    storage.ei.orbital_combinator_platform_cache = {}
  end
  if not storage.ei.orbital_combinator_platform_by_hub then
    storage.ei.orbital_combinator_platform_by_hub = {}
  end
  if not storage.ei.orbital_combinator_object_registration then
    storage.ei.orbital_combinator_object_registration = {}
    needs_platform_rebuild = true
  end
  if not storage.ei.orbital_combinator_snapshot_cache then
    storage.ei.orbital_combinator_snapshot_cache = {}
  end
  if not storage.ei.orbital_combinator_surface_platform_index then
    storage.ei.orbital_combinator_surface_platform_index = {}
    needs_platform_rebuild = true
  end
  if not storage.ei.orbital_combinator_surface_bank_index then
    storage.ei.orbital_combinator_surface_bank_index = {}
  end
  if not storage.ei.orbital_combinator_surface_state then
    storage.ei.orbital_combinator_surface_state = {}
    needs_platform_rebuild = true
  end
  if storage.ei.orbital_combinator_hot_surface_break_point == nil then
    storage.ei.orbital_combinator_hot_surface_break_point = nil
  end
  if storage.ei.orbital_combinator_cold_surface_break_point == nil then
    storage.ei.orbital_combinator_cold_surface_break_point = nil
  end
  if storage.ei.orbital_combinator_connection_audit_break_point == nil then
    storage.ei.orbital_combinator_connection_audit_break_point = nil
  end
  if not storage.ei.orbital_combinator_dirty_bank_queue then
    storage.ei.orbital_combinator_dirty_bank_queue = ei_runtime_scheduler.ensure_queue(nil)
  else
    storage.ei.orbital_combinator_dirty_bank_queue = ei_runtime_scheduler.ensure_queue(storage.ei.orbital_combinator_dirty_bank_queue)
  end
  if not storage.ei.orbital_combinator_bank_audit_queue then
    storage.ei.orbital_combinator_bank_audit_queue = ei_runtime_scheduler.ensure_queue(nil)
  else
    storage.ei.orbital_combinator_bank_audit_queue = ei_runtime_scheduler.ensure_queue(storage.ei.orbital_combinator_bank_audit_queue)
  end
  if not storage.ei.orbital_combinator_hot_surface_queue then
    storage.ei.orbital_combinator_hot_surface_queue = ei_runtime_scheduler.ensure_queue(nil)
  else
    storage.ei.orbital_combinator_hot_surface_queue = ei_runtime_scheduler.ensure_queue(storage.ei.orbital_combinator_hot_surface_queue)
  end
  if not storage.ei.orbital_combinator_cold_surface_queue then
    storage.ei.orbital_combinator_cold_surface_queue = ei_runtime_scheduler.ensure_queue(nil)
  else
    storage.ei.orbital_combinator_cold_surface_queue = ei_runtime_scheduler.ensure_queue(storage.ei.orbital_combinator_cold_surface_queue)
  end
  if not storage.ei.orbital_combinator_reconcile_state then
    storage.ei.orbital_combinator_reconcile_state = {}
    needs_platform_rebuild = true
  end
  if not storage.ei.orbital_combinator_surface_generations then
    storage.ei.orbital_combinator_surface_generations = {}
  end
  if not storage.ei.orbital_combinator_surface_generations[MODE_REQUESTS] then
    storage.ei.orbital_combinator_surface_generations[MODE_REQUESTS] = {}
  end
  if not storage.ei.orbital_combinator_surface_generations[MODE_ON_THE_WAY] then
    storage.ei.orbital_combinator_surface_generations[MODE_ON_THE_WAY] = {}
  end
  if not storage.ei.orbital_combinator_surface_generations[MODE_NEED] then
    storage.ei.orbital_combinator_surface_generations[MODE_NEED] = {}
  end
  if storage.ei.orbital_combinator_generation_epoch == nil then
    storage.ei.orbital_combinator_generation_epoch = 0
  end
  if storage.ei.orbital_combinator_runtime_state_version ~= ORBITAL_RUNTIME_STATE_VERSION then
    storage.ei.orbital_combinator_runtime_state_version = ORBITAL_RUNTIME_STATE_VERSION
    needs_platform_rebuild = true
    force_bank_rebuild = true
  end

  get_reconcile_state()
  get_work_service_root()

  if rebuild_banks == nil then
    rebuild_banks = true
  end
  if force_bank_rebuild then
    rebuild_banks = true
  end

  if needs_platform_rebuild and game then
    rebuild_platform_cache_from_world(game and game.tick or 0)
  end

  if rebuild_banks then
    if ei_lib.getn(storage.ei.orbital_combinators) == 0 then
      rebuild_registry_from_world()
    end
    model.rebuild_banks()
  end
end


function model.rebuild_banks()
  model.check_init(false)
  sanitize_registered_entities()

  local grouped_entities = {}
  local old_banks = storage.ei.orbital_combinator_banks or {}
  local old_bank_by_unit = storage.ei.orbital_combinator_bank_by_unit or {}
  local open_gui_by_player = storage.ei.orbital_combinator_open_gui_by_player or {}
  local banks = {}
  local bank_by_unit = {}

  for _, entity in pairs(storage.ei.orbital_combinators) do
    if is_registered_scanner(entity) then
      local group_key = tostring(entity.force.index) .. ":" .. tostring(entity.surface.index)
      local group = grouped_entities[group_key]

      if not group then
        group = {
          entities = {},
          by_position = {},
          force_index = entity.force.index,
          surface_index = entity.surface.index,
          surface_name = entity.surface.name,
        }
        grouped_entities[group_key] = group
      end

      table.insert(group.entities, entity)
      group.by_position[get_position_key(entity)] = entity
    end
  end

  for _, group in pairs(grouped_entities) do
    table.sort(group.entities, compare_entities)

    local visited = {}

    for _, root in ipairs(group.entities) do
      local root_unit = root.unit_number

      if not visited[root_unit] then
        local queue = {root}
        local component = {}
        local head = 1
        visited[root_unit] = true

        while head <= #queue do
          local current = queue[head]
          head = head + 1
          component[#component + 1] = current

          local current_x = get_grid_coordinate(current.position.x)
          local current_y = get_grid_coordinate(current.position.y)

          for _, offset in ipairs(ADJACENT_OFFSETS) do
            local neighbor = group.by_position[get_position_key_from_xy(current_x + offset.x, current_y + offset.y)]
            if neighbor and not visited[neighbor.unit_number] then
              visited[neighbor.unit_number] = true
              queue[#queue + 1] = neighbor
            end
          end
        end

        table.sort(component, compare_entities)

        local members = {}
        for _, member in ipairs(component) do
          members[#members + 1] = member.unit_number
        end

        local bank_id = members[1]
        local bank_mode = MODE_REQUESTS
        local carried_hot_until_tick = 0
        local carried_connection_audit_tick = 0
        local carried_wired = false

        for _, unit_number in ipairs(members) do
          local candidate_mode = get_unit_mode(unit_number)
          if candidate_mode ~= MODE_REQUESTS then
            bank_mode = candidate_mode
            break
          end
        end

        for _, unit_number in ipairs(members) do
          set_unit_mode(unit_number, bank_mode)

          local previous_bank = old_banks[old_bank_by_unit[unit_number]]
          if previous_bank then
            carried_hot_until_tick = math.max(carried_hot_until_tick, previous_bank.hot_until_tick or 0)
            carried_connection_audit_tick = math.max(carried_connection_audit_tick, previous_bank.last_connection_audit_tick or 0)
            carried_wired = carried_wired or previous_bank.wired == true
          end
        end

        banks[bank_id] = {
          id = bank_id,
          anchor_unit_number = bank_id,
          force_index = group.force_index,
          surface_index = group.surface_index,
          surface_name = group.surface_name,
          members = members,
          mode = bank_mode,
          signature = nil,
          input_signature = nil,
          open_gui_count = 0,
          wired = carried_wired,
          hot_until_tick = carried_hot_until_tick,
          last_connection_audit_tick = carried_connection_audit_tick,
          last_applied_generation_token = nil,
          member_layout_state_signature = nil,
          member_layout_signatures = nil,
        }

        for _, unit_number in ipairs(members) do
          bank_by_unit[unit_number] = bank_id
        end
      end
    end
  end

  storage.ei.orbital_combinator_banks = banks
  storage.ei.orbital_combinator_bank_by_unit = bank_by_unit
  storage.ei.orbital_combinator_bank_count = ei_lib.getn(banks)
  storage.ei.orbital_combinator_surface_bank_index = {}
  storage.ei.orbital_combinator_dirty_bank_queue = ei_runtime_scheduler.ensure_queue(nil)
  storage.ei.orbital_combinator_bank_audit_queue = ei_runtime_scheduler.ensure_queue(nil)
  storage.ei.orbital_combinator_hot_surface_break_point = nil
  storage.ei.orbital_combinator_cold_surface_break_point = nil
  storage.ei.orbital_combinator_connection_audit_break_point = nil

  for _, unit_number in pairs(open_gui_by_player) do
    local bank_id = bank_by_unit[unit_number]
    if bank_id and banks[bank_id] then
      banks[bank_id].open_gui_count = (banks[bank_id].open_gui_count or 0) + 1
    end
  end

  for bank_id, bank in pairs(banks) do
    local surface_key = get_force_surface_key(bank.force_index, bank.surface_name)
    local bank_index = get_surface_bank_index_root()
    bank_index[surface_key] = bank_index[surface_key] or {}
    bank_index[surface_key][#bank_index[surface_key] + 1] = bank_id
    ensure_surface_state(bank.force_index, bank.surface_name)
    enqueue_dirty_bank(bank_id)
    enqueue_bank_audit(bank_id)
    enqueue_cold_surface(bank.force_index, bank.surface_name)
    if is_bank_hot(bank, game and game.tick or 0) then
      enqueue_hot_surface(bank.force_index, bank.surface_name)
    end
  end

  clear_snapshot_cache()
end


function model.add(entity)
  if not is_registered_scanner(entity) then
    return
  end

  model.check_init(false)
  storage.ei.orbital_combinators[entity.unit_number] = entity
  model.rebuild_banks()
end


function model.rem(entity)
  if not entity or not entity.valid or entity.name ~= ORBITAL_COMBINATOR_NAME or not entity.unit_number then
    return
  end

  model.check_init(false)
  storage.ei.orbital_combinators[entity.unit_number] = nil
  model.rebuild_banks()
end


local function merge_filter_entry(target, source)
  target.min = (target.min or 0) + (source.min or 0)

  if target.max ~= nil and source.max ~= nil then
    target.max = target.max + source.max
  else
    target.max = nil
  end
end


local function add_filter_to_map(target, value, min, max)
  local filter = make_filter(value, min, max)
  if not filter then
    return
  end

  local key = signal_key(filter.value)
  if target[key] then
    merge_filter_entry(target[key], filter)
  else
    target[key] = filter
  end
end


local function finalize_filter_map(merged)
  local filters = {}

  for _, filter in pairs(merged) do
    filters[#filters + 1] = filter
  end

  table.sort(filters, compare_filters)
  return filters
end


local function build_inventory_filter_map(inventory)
  local merged = {}
  if not inventory or not inventory.valid then
    return merged
  end

  for slot_index = 1, #inventory do
    local stack = inventory[slot_index]
    if stack and stack.valid_for_read and stack.count and stack.count > 0 then
      add_filter_to_map(merged, {
        type = "item",
        name = stack.name,
        quality = stack.quality,
      }, stack.count, nil)
    end
  end

  return merged
end


local function get_inventory_content(inventory)
  return finalize_filter_map(build_inventory_filter_map(inventory))
end


local function get_inventory_filter_content(inventory)
  local merged = build_inventory_filter_map(inventory)
  local filters = finalize_filter_map(merged)
  return filters, build_filters_signature(filters), merged
end


local function get_platform_requester_logistic_point(platform)
  local hub = platform and platform.valid and platform.hub or nil
  if not model.entity_check(hub) then
    return nil
  end

  return hub.get_logistic_point(defines.logistic_member_index.cargo_landing_pad_requester)
end


local function build_logistic_point_filter_map(entries)
  local merged = {}
  for _, entry in ipairs(entries or EMPTY_FILTERS) do
    if entry and entry.name and entry.count and entry.count > 0 then
      add_filter_to_map(merged, {
        type = "item",
        name = entry.name,
        quality = entry.quality,
      }, entry.count, nil)
    end
  end

  return merged
end


local function get_logistic_point_content(logistic_point, field_name)
  if not logistic_point or not logistic_point.valid then
    return EMPTY_FILTERS, EMPTY_FILTERS_SIGNATURE, {}
  end

  local merged = build_logistic_point_filter_map(logistic_point[field_name])
  local filters = finalize_filter_map(merged)
  return filters, build_filters_signature(filters), merged
end


local function subtract_filter_maps(base_filters, subtract_maps)
  local merged = {}

  for _, filter in ipairs(base_filters or EMPTY_FILTERS) do
    local copy = make_filter(filter.value, filter.min or 0, nil)
    if copy then
      merged[signal_key(copy.value)] = copy
    end
  end

  for _, subtract_map in ipairs(subtract_maps or EMPTY_FILTERS) do
    if subtract_map then
      for key, filter in pairs(subtract_map) do
        local existing = merged[key]
        if existing then
          existing.min = math.max(0, (existing.min or 0) - (filter.min or 0))
        end
      end
    end
  end

  local filters = {}
  for _, filter in pairs(merged) do
    if (filter.min or 0) > 0 then
      filters[#filters + 1] = filter
    end
  end

  table.sort(filters, compare_filters)
  return filters
end


local function ensure_platform_entry_defaults(entry)
  entry = entry or {}
  entry.request_filters = entry.request_filters or entry.filters or EMPTY_FILTERS
  entry.request_filter_signature = entry.request_filter_signature or entry.filter_signature or EMPTY_FILTERS_SIGNATURE
  entry.requester_filter_signature = entry.requester_filter_signature or entry.request_filter_signature or EMPTY_FILTERS_SIGNATURE
  entry.request_filter_map = entry.request_filter_map or {}
  entry.on_the_way_filters = entry.on_the_way_filters or EMPTY_FILTERS
  entry.on_the_way_filter_signature = entry.on_the_way_filter_signature or EMPTY_FILTERS_SIGNATURE
  entry.targeted_deliver_signature = entry.targeted_deliver_signature or entry.on_the_way_filter_signature or EMPTY_FILTERS_SIGNATURE
  entry.targeted_deliver_map = entry.targeted_deliver_map or {}
  entry.need_inventory_filters = entry.need_inventory_filters or EMPTY_FILTERS
  entry.need_inventory_signature = entry.need_inventory_signature or EMPTY_FILTERS_SIGNATURE
  entry.need_inventory_map = entry.need_inventory_map or {}
  entry.need_filters = entry.need_filters or EMPTY_FILTERS
  entry.need_filter_signature = entry.need_filter_signature or EMPTY_FILTERS_SIGNATURE
  entry.last_need_audit_tick = entry.last_need_audit_tick or 0
  entry.platform_name = entry.platform_name or nil
  entry.sort_id = entry.sort_id or 0
  entry.last_seen_tick = entry.last_seen_tick or 0
  return entry
end


local function get_platform_from_entry(platform_index, entry)
  local force = get_force_by_index(entry and entry.force_index or nil)
  local platform = force and force.platforms and force.platforms[platform_index] or nil
  if platform and platform.valid then
    return platform
  end

  return nil
end


local function rebuild_platform_need_filters(entry)
  local previous_signature = entry.need_filter_signature or EMPTY_FILTERS_SIGNATURE
  local need_filters = subtract_filter_maps(entry.request_filters or EMPTY_FILTERS, {
    entry.targeted_deliver_map or {},
    entry.need_inventory_map or {},
  })
  local next_signature = build_filters_signature(need_filters)
  entry.need_filters = need_filters
  entry.need_filter_signature = next_signature
  return next_signature ~= previous_signature
end


local function sync_platform_entry(platform, current_tick)
  local platform_cache = storage.ei.orbital_combinator_platform_cache
  local platform_by_hub = storage.ei.orbital_combinator_platform_by_hub
  local platform_index = platform.index
  local entry = ensure_platform_entry_defaults(platform_cache[platform_index])
  local hub = platform.hub
  local hub_unit_number = model.entity_check(hub) and hub.unit_number or nil
  local force_index = platform.force.index
  local surface_name = get_platform_surface_name(platform)

  if entry.hub_unit_number and entry.hub_unit_number ~= hub_unit_number then
    platform_by_hub[entry.hub_unit_number] = nil
  end

  if entry.surface_key and (entry.force_index ~= force_index or entry.surface_name ~= surface_name) then
    remove_platform_from_surface_index(platform_index, entry.surface_key)
    entry.surface_key = nil
  end

  entry.force_index = force_index
  entry.surface_name = surface_name
  entry.surface_key = add_platform_to_surface_index(platform_index, force_index, surface_name)
  entry.hub_unit_number = hub_unit_number
  entry.platform_name = platform.name or ("platform-" .. tostring(hub_unit_number or platform_index))
  entry.sort_id = hub_unit_number or 0
  entry.last_seen_tick = current_tick

  if not entry.object_registration_number then
    entry.object_registration_number = register_object_for_destroy("platform", platform, {
      platform_index = platform_index,
    })
  end

  if hub_unit_number then
    platform_by_hub[hub_unit_number] = platform_index
  end

  platform_cache[platform_index] = entry
  return entry
end


local function apply_platform_component_changes(entry, changed_modes, current_tick, wake_banks)
  if #changed_modes == 0 or not entry.force_index or not entry.surface_name then
    return false
  end

  bump_surface_generations(entry.force_index, entry.surface_name, changed_modes)
  enqueue_cold_surface(entry.force_index, entry.surface_name)
  if wake_banks ~= false then
    wake_surface_banks(entry.force_index, entry.surface_name, current_tick)
  end
  return true
end


local function refresh_platform_request_component(platform, current_tick, wake_banks)
  local entry = sync_platform_entry(platform, current_tick)
  local previous_request_signature = entry.request_filter_signature or EMPTY_FILTERS_SIGNATURE
  local previous_need_signature = entry.need_filter_signature or EMPTY_FILTERS_SIGNATURE
  local filters, filter_signature, filter_map = get_logistic_point_content(get_platform_requester_logistic_point(platform), "filters")
  entry.request_filters = filters
  entry.request_filter_signature = filter_signature
  entry.requester_filter_signature = filter_signature
  entry.request_filter_map = filter_map

  local changed_modes = {}
  if filter_signature ~= previous_request_signature then
    changed_modes[#changed_modes + 1] = MODE_REQUESTS
  end
  if rebuild_platform_need_filters(entry) and entry.need_filter_signature ~= previous_need_signature then
    changed_modes[#changed_modes + 1] = MODE_NEED
  end

  apply_platform_component_changes(entry, changed_modes, current_tick, wake_banks)
  return entry, #changed_modes > 0
end


local function refresh_platform_on_the_way_component(platform, current_tick, wake_banks)
  local entry = sync_platform_entry(platform, current_tick)
  local previous_on_the_way_signature = entry.on_the_way_filter_signature or EMPTY_FILTERS_SIGNATURE
  local previous_need_signature = entry.need_filter_signature or EMPTY_FILTERS_SIGNATURE
  local filters, filter_signature, filter_map = get_logistic_point_content(get_platform_requester_logistic_point(platform), "targeted_items_deliver")
  entry.on_the_way_filters = filters
  entry.on_the_way_filter_signature = filter_signature
  entry.targeted_deliver_signature = filter_signature
  entry.targeted_deliver_map = filter_map

  local changed_modes = {}
  if filter_signature ~= previous_on_the_way_signature then
    changed_modes[#changed_modes + 1] = MODE_ON_THE_WAY
  end
  if rebuild_platform_need_filters(entry) and entry.need_filter_signature ~= previous_need_signature then
    changed_modes[#changed_modes + 1] = MODE_NEED
  end

  apply_platform_component_changes(entry, changed_modes, current_tick, wake_banks)
  return entry, #changed_modes > 0
end


local function refresh_platform_need_inventory_component(platform, current_tick, wake_banks)
  local entry = sync_platform_entry(platform, current_tick)
  local previous_need_signature = entry.need_filter_signature or EMPTY_FILTERS_SIGNATURE
  local hub = platform.hub
  local hub_inventory = nil
  if model.entity_check(hub) then
    hub_inventory = hub.get_inventory(defines.inventory.hub_main)
  end

  local inventory_filters, inventory_signature, inventory_map = get_inventory_filter_content(hub_inventory)
  entry.need_inventory_filters = inventory_filters
  entry.need_inventory_signature = inventory_signature
  entry.need_inventory_map = inventory_map
  entry.last_need_audit_tick = current_tick

  local changed_modes = {}
  if rebuild_platform_need_filters(entry) and entry.need_filter_signature ~= previous_need_signature then
    changed_modes[#changed_modes + 1] = MODE_NEED
  end

  apply_platform_component_changes(entry, changed_modes, current_tick, wake_banks)
  return entry, #changed_modes > 0
end


local function hydrate_platform_entry(platform, current_tick)
  local entry = sync_platform_entry(platform, current_tick)
  local hub = platform.hub
  local hub_inventory = nil
  if model.entity_check(hub) then
    hub_inventory = hub.get_inventory(defines.inventory.hub_main)
  end

  local request_filters, request_signature, request_map = get_logistic_point_content(get_platform_requester_logistic_point(platform), "filters")
  local on_the_way_filters, on_the_way_signature, on_the_way_map = get_logistic_point_content(get_platform_requester_logistic_point(platform), "targeted_items_deliver")
  local inventory_filters, inventory_signature, inventory_map = get_inventory_filter_content(hub_inventory)

  entry.request_filters = request_filters
  entry.request_filter_signature = request_signature
  entry.requester_filter_signature = request_signature
  entry.request_filter_map = request_map
  entry.on_the_way_filters = on_the_way_filters
  entry.on_the_way_filter_signature = on_the_way_signature
  entry.targeted_deliver_signature = on_the_way_signature
  entry.targeted_deliver_map = on_the_way_map
  entry.need_inventory_filters = inventory_filters
  entry.need_inventory_signature = inventory_signature
  entry.need_inventory_map = inventory_map
  entry.last_need_audit_tick = current_tick
  rebuild_platform_need_filters(entry)
  storage.ei.orbital_combinator_platform_cache[platform.index] = entry
  return entry
end


rebuild_platform_cache_from_world = function(current_tick)
  if not game then
    return
  end

  storage.ei.orbital_combinator_platform_cache = {}
  storage.ei.orbital_combinator_platform_by_hub = {}
  storage.ei.orbital_combinator_object_registration = {}
  storage.ei.orbital_combinator_surface_platform_index = {}
  storage.ei.orbital_combinator_surface_state = {}
  storage.ei.orbital_combinator_snapshot_cache = {}
  storage.ei.orbital_combinator_hot_surface_queue = ei_runtime_scheduler.ensure_queue(nil)
  storage.ei.orbital_combinator_cold_surface_queue = ei_runtime_scheduler.ensure_queue(nil)

  local reconcile_state = get_reconcile_state()
  reconcile_state.force_cursor = nil
  reconcile_state.platform_cursor = nil
  reconcile_state.cache_cursor = nil
  reconcile_state.cleanup_phase = false
  reconcile_state.in_progress = false
  reconcile_state.next_due_tick = (current_tick or 0) + PLATFORM_RECONCILE_INTERVAL

  for _, force in pairs(game.forces or {}) do
    if force and force.valid then
      for _, platform in pairs(force.platforms or {}) do
        if platform and platform.valid then
          hydrate_platform_entry(platform, current_tick or 0)
        end
      end
    end
  end
end


local function remove_platform_cache_entry(platform_index)
  local entry = storage.ei.orbital_combinator_platform_cache[platform_index]
  if not entry then
    return
  end

  if entry.hub_unit_number then
    storage.ei.orbital_combinator_platform_by_hub[entry.hub_unit_number] = nil
  end

  if entry.surface_key then
    remove_platform_from_surface_index(platform_index, entry.surface_key)
  end

  if entry.object_registration_number then
    storage.ei.orbital_combinator_object_registration[entry.object_registration_number] = nil
  end

  storage.ei.orbital_combinator_platform_cache[platform_index] = nil
end


get_platform_surface_name = function(platform)
  local location = platform and platform.valid and platform.space_location or nil
  return location and location.name or nil
end


local function get_platform_surface_context(platform_index)
  local entry = storage.ei.orbital_combinator_platform_cache[platform_index]
  if entry and entry.force_index and entry.surface_name then
    return entry.force_index, entry.surface_name
  end

  if not game then
    return nil, nil
  end

  for _, force in pairs(game.forces) do
    local platform = force.platforms and force.platforms[platform_index]
    if platform and platform.valid then
      return force.index, get_platform_surface_name(platform)
    end
  end

  return nil, nil
end


register_object_for_destroy = function(kind, object, payload)
  if not script or not object or not object.valid then
    return nil
  end

  local registration_number = script.register_on_object_destroyed(object)
  if registration_number then
    storage.ei.orbital_combinator_object_registration[registration_number] = payload
    payload.kind = kind
  end

  return registration_number
end


local function store_platform_cache_entry(platform, hub, filters, filter_signature, dirty)
  local entry = sync_platform_entry(platform, game and game.tick or 0)
  entry.hub_unit_number = hub and hub.valid and hub.unit_number or nil
  entry.request_filters = filters or EMPTY_FILTERS
  entry.request_filter_signature = filter_signature or EMPTY_FILTERS_SIGNATURE
  entry.requester_filter_signature = entry.request_filter_signature
  entry.request_filter_map = entry.request_filter_map or {}
  entry.on_the_way_filters = entry.on_the_way_filters or EMPTY_FILTERS
  entry.on_the_way_filter_signature = entry.on_the_way_filter_signature or EMPTY_FILTERS_SIGNATURE
  entry.targeted_deliver_signature = entry.targeted_deliver_signature or entry.on_the_way_filter_signature
  entry.targeted_deliver_map = entry.targeted_deliver_map or {}
  entry.need_inventory_filters = entry.need_inventory_filters or EMPTY_FILTERS
  entry.need_inventory_signature = entry.need_inventory_signature or EMPTY_FILTERS_SIGNATURE
  entry.need_inventory_map = entry.need_inventory_map or {}
  entry.need_filters = entry.need_filters or EMPTY_FILTERS
  entry.need_filter_signature = entry.need_filter_signature or EMPTY_FILTERS_SIGNATURE
  entry.request_dirty = dirty == true
  entry.filters = entry.request_filters
  entry.filter_signature = entry.request_filter_signature
  entry.dirty = entry.request_dirty
  entry.last_seen_tick = game and game.tick or 0
  storage.ei.orbital_combinator_platform_cache[platform.index] = entry
  return entry
end


local function mark_platform_dirty(platform_index)
  if not platform_index then
    return false
  end

  model.check_init(false)

  local entry = storage.ei.orbital_combinator_platform_cache[platform_index]
  local platform = entry and get_platform_from_entry(platform_index, entry) or nil
  if platform then
    refresh_platform_request_component(platform, game and game.tick or 0, true)
    enqueue_hot_surface(platform.force.index, get_platform_surface_name(platform))
    enqueue_cold_surface(platform.force.index, get_platform_surface_name(platform))
    return true
  end

  local force_index, surface_name = get_platform_surface_context(platform_index)
  if force_index and surface_name then
    enqueue_hot_surface(force_index, surface_name)
    enqueue_cold_surface(force_index, surface_name)
  else
    clear_snapshot_cache()
  end

  return false
end


local function get_cached_platform_index_by_hub_entity(entity)
  if not model.entity_check(entity) or not entity.unit_number or not entity.force or not entity.force.valid then
    return nil
  end

  model.check_init(false)

  local platform_cache = storage.ei.orbital_combinator_platform_cache
  local platform_by_hub = storage.ei.orbital_combinator_platform_by_hub
  local platform_index = platform_by_hub[entity.unit_number]

  if not platform_index then
    return nil
  end

  local entry = platform_cache[platform_index]
  if entry and entry.hub_unit_number == entity.unit_number and entry.force_index == entity.force.index then
    return platform_index
  end

  platform_by_hub[entity.unit_number] = nil
  return nil
end


local function get_platform_index_by_hub_entity(entity)
  local platform_index = get_cached_platform_index_by_hub_entity(entity)
  if platform_index then
    return platform_index
  end

  if not model.entity_check(entity) or not entity.unit_number or not entity.force or not entity.force.valid then
    return nil
  end

  model.check_init(false)

  for candidate_index, platform in pairs(entity.force.platforms or {}) do
    if platform and platform.valid then
      local hub = platform.hub
      if hub and hub.valid and hub.unit_number == entity.unit_number then
        sync_platform_entry(platform, game and game.tick or 0)
        return candidate_index
      end
    end
  end

  return nil
end


local function mark_platform_hub_dirty(entity, allow_scan)
  if not has_registered_banks() then
    return
  end

  local platform_index = nil
  if allow_scan then
    platform_index = get_platform_index_by_hub_entity(entity)
  else
    platform_index = get_cached_platform_index_by_hub_entity(entity)
  end

  if platform_index then
    local entry = storage.ei.orbital_combinator_platform_cache[platform_index]
    local platform = entry and get_platform_from_entry(platform_index, entry) or nil
    if platform then
      refresh_platform_request_component(platform, game and game.tick or 0, true)
      enqueue_hot_surface(platform.force.index, get_platform_surface_name(platform))
      enqueue_cold_surface(platform.force.index, get_platform_surface_name(platform))
    else
      mark_platform_dirty(platform_index)
    end
  end
end


local function reconcile_platform_cache(current_tick)
  if not has_registered_banks() then
    return false
  end

  local state = get_reconcile_state()
  if not state.in_progress and current_tick < (state.next_due_tick or 0) then
    return false
  end

  if not state.in_progress then
    state.in_progress = true
    state.cleanup_phase = false
    state.force_cursor = nil
    state.platform_cursor = nil
    state.cache_cursor = nil
    state.cycle = (state.cycle or 0) + 1
  end

  if not state.cleanup_phase then
    local scanned = 0

    while scanned < RECONCILE_PLATFORM_SLICE do
      local force_key, force = next_collection_entry(game.forces, state.force_cursor)
      if force_key == nil then
        state.cleanup_phase = true
        state.force_cursor = nil
        state.platform_cursor = nil
        return true
      end

      local platform_index, platform = next_collection_entry(force.platforms or {}, state.platform_cursor)
      if platform_index == nil then
        state.force_cursor = force_key
        state.platform_cursor = nil
      else
        state.force_cursor = force_key
        state.platform_cursor = platform_index
        if platform and platform.valid then
          local previous_entry = storage.ei.orbital_combinator_platform_cache[platform_index]
          local previous_force_index = previous_entry and previous_entry.force_index or nil
          local previous_surface_name = previous_entry and previous_entry.surface_name or nil
          local previous_platform_name = previous_entry and previous_entry.platform_name or nil

          refresh_platform_request_component(platform, current_tick, true)
          refresh_platform_on_the_way_component(platform, current_tick, true)
          refresh_platform_need_inventory_component(platform, current_tick, true)

          local entry = sync_platform_entry(platform, current_tick)
          entry.reconcile_cycle = state.cycle

          if previous_force_index and previous_surface_name
            and (previous_force_index ~= entry.force_index or previous_surface_name ~= entry.surface_name) then
            bump_surface_generations(previous_force_index, previous_surface_name, {MODE_REQUESTS, MODE_ON_THE_WAY, MODE_NEED})
            wake_surface_banks(previous_force_index, previous_surface_name, current_tick)
          end

          if previous_platform_name ~= entry.platform_name then
            bump_surface_generations(entry.force_index, entry.surface_name, {MODE_REQUESTS, MODE_ON_THE_WAY, MODE_NEED})
            wake_surface_banks(entry.force_index, entry.surface_name, current_tick)
          end
        end
        scanned = scanned + 1
      end
    end

    return true
  end

  local scanned = 0
  local platform_cache = storage.ei.orbital_combinator_platform_cache
  if state.cache_cursor ~= nil and platform_cache[state.cache_cursor] == nil then
    state.cache_cursor = nil
  end
  while scanned < RECONCILE_PLATFORM_SLICE do
    local platform_index, entry = next_collection_entry(platform_cache, state.cache_cursor)
    if platform_index == nil then
      state.in_progress = false
      state.cleanup_phase = false
      state.cache_cursor = nil
      state.next_due_tick = current_tick + PLATFORM_RECONCILE_INTERVAL
      return true
    end

    local next_platform_index = next_collection_entry(platform_cache, platform_index)
    state.cache_cursor = next_platform_index
    if entry and entry.reconcile_cycle ~= state.cycle then
      local force_index = entry.force_index
      local surface_name = entry.surface_name
      remove_platform_cache_entry(platform_index)
      if force_index and surface_name then
        bump_surface_generations(force_index, surface_name, {MODE_REQUESTS, MODE_ON_THE_WAY, MODE_NEED})
        wake_surface_banks(force_index, surface_name, current_tick)
      end
    end
    scanned = scanned + 1
  end

  return true
end


local function get_on_the_way_platform_filters(platform)
  local logistic_point = get_platform_requester_logistic_point(platform)
  return get_logistic_point_content(logistic_point, "targeted_items_deliver")
end


local function mark_platform_surface_modes_dirty(platform, modes, current_tick)
  if not platform or not platform.valid or not platform.force or not platform.force.valid then
    return false
  end

  local requested_modes = {}
  for _, mode in ipairs(modes or EMPTY_FILTERS) do
    requested_modes[normalize_mode(mode)] = true
  end

  sync_platform_entry(platform, current_tick or (game and game.tick) or 0)
  if requested_modes[MODE_REQUESTS] then
    refresh_platform_request_component(platform, current_tick or (game and game.tick) or 0, true)
  end
  if requested_modes[MODE_ON_THE_WAY] then
    refresh_platform_on_the_way_component(platform, current_tick or (game and game.tick) or 0, true)
  end
  if requested_modes[MODE_NEED] then
    if not requested_modes[MODE_REQUESTS] then
      refresh_platform_request_component(platform, current_tick or (game and game.tick) or 0, true)
    end
    if not requested_modes[MODE_ON_THE_WAY] then
      refresh_platform_on_the_way_component(platform, current_tick or (game and game.tick) or 0, true)
    end
    refresh_platform_need_inventory_component(platform, current_tick or (game and game.tick) or 0, true)
  end

  enqueue_hot_surface(platform.force.index, get_platform_surface_name(platform))
  enqueue_cold_surface(platform.force.index, get_platform_surface_name(platform))
  return true
end


local function get_destination_platform_from_station(station)
  if not model.entity_check(station) or station.type ~= SPACE_PLATFORM_HUB_ENTITY_TYPE then
    return nil
  end

  local platform_index = get_platform_index_by_hub_entity(station)
  if not platform_index then
    return nil
  end

  local platform = station.force.platforms and station.force.platforms[platform_index]
  if not platform or not platform.valid then
    return nil
  end

  return platform
end


local function get_destination_platform_from_pod(pod)
  if not model.entity_check(pod) then
    return nil
  end

  local destination = pod.cargo_pod_destination
  if not destination or destination.type ~= defines.cargo_destination.station then
    return nil
  end

  return get_destination_platform_from_station(destination.station)
end


local function get_destination_platform_from_rocket(event)
  local rocket = event and event.rocket or nil
  local pod = rocket and rocket.attached_cargo_pod or nil
  return get_destination_platform_from_pod(pod)
end


local function get_surface_platform_indices(force_index, surface_name)
  local entry = get_surface_platform_index_root()[get_force_surface_key(force_index, surface_name)]
  return entry and entry.platform_indices or EMPTY_FILTERS
end


local function get_surface_bank_ids(force_index, surface_name)
  return get_surface_bank_index_root()[get_force_surface_key(force_index, surface_name)] or EMPTY_FILTERS
end


local function get_platform_cached_mode_filters(entry, mode)
  local normalized_mode = normalize_mode(mode)
  if normalized_mode == MODE_REQUESTS then
    return entry.request_filters or EMPTY_FILTERS, entry.request_filter_signature or EMPTY_FILTERS_SIGNATURE
  end
  if normalized_mode == MODE_ON_THE_WAY then
    return entry.on_the_way_filters or EMPTY_FILTERS, entry.on_the_way_filter_signature or EMPTY_FILTERS_SIGNATURE
  end
  return entry.need_filters or EMPTY_FILTERS, entry.need_filter_signature or EMPTY_FILTERS_SIGNATURE
end


local function build_surface_snapshot(force, surface, mode)
  local platforms = {}
  local platform_cache = storage.ei.orbital_combinator_platform_cache
  local normalized_mode = normalize_mode(mode)

  for _, platform_index in ipairs(get_surface_platform_indices(force.index, surface.name)) do
    local entry = platform_cache[platform_index]
    if entry and entry.force_index == force.index and entry.surface_name == surface.name then
      local filters, filter_signature = get_platform_cached_mode_filters(entry, normalized_mode)
      platforms[#platforms + 1] = {
        index = platform_index,
        name = entry.platform_name or ("platform-" .. tostring(entry.sort_id or platform_index)),
        sort_id = entry.sort_id or 0,
        filters = filters,
        filter_signature = filter_signature,
      }
    end
  end

  table.sort(platforms, compare_platforms)

  local hash = 5381
  hash = hash_update(hash, #platforms)

  for _, platform in ipairs(platforms) do
    hash = hash_update(hash, platform.index or 0)
    hash = hash_update(hash, platform.name or "")
    hash = hash_update(hash, platform.sort_id or 0)
    hash = hash_update(hash, platform.filter_signature or EMPTY_FILTERS_SIGNATURE)
  end

  return {
    platforms = platforms,
    signature = string.format("%08x", hash),
    pages_by_capacity = {},
  }
end


local function get_surface_snapshot(force, surface, mode)
  local normalized_mode = normalize_mode(mode)
  local generation_token = get_generation_token(force.index, surface.name, normalized_mode)
  local cache_key = table.concat({
    tostring(force.index),
    tostring(surface.name),
    normalized_mode,
    generation_token,
  }, ":")
  local snapshot_cache = get_snapshot_cache_root()
  if not snapshot_cache[cache_key] then
    snapshot_cache[cache_key] = build_surface_snapshot(force, surface, normalized_mode)
  end
  return snapshot_cache[cache_key]
end


local function surface_has_hot_interest(force_index, surface_name, current_tick)
  for _, bank_id in ipairs(get_surface_bank_ids(force_index, surface_name)) do
    local bank = storage.ei.orbital_combinator_banks and storage.ei.orbital_combinator_banks[bank_id] or nil
    if bank and ((bank.open_gui_count or 0) > 0
      or bank.wired == true
      or (bank.hot_until_tick or 0) >= current_tick) then
      return true
    end
  end

  return false
end


local function collect_surface_bank_activity(force_index, surface_name, current_tick, only_hot)
  local activity = {
    has_banks = false,
    hot = false,
    requests = false,
    on_the_way = false,
    need = false,
  }

  for _, bank_id in ipairs(get_surface_bank_ids(force_index, surface_name)) do
    local bank = storage.ei.orbital_combinator_banks and storage.ei.orbital_combinator_banks[bank_id] or nil
    if bank then
      activity.has_banks = true

      if current_tick >= ((bank.last_connection_audit_tick or 0) + BANK_CONNECTION_AUDIT_INTERVAL) then
        local members = get_bank_members(bank)
        if members and #members > 0 then
          audit_bank_wired_state(bank, members, current_tick)
        end
      end

      local bank_is_hot = is_bank_hot(bank, current_tick)
      activity.hot = activity.hot or bank_is_hot
      if not only_hot or bank_is_hot then
        local mode = get_bank_mode(bank)
        if mode == MODE_REQUESTS then
          activity.requests = true
        elseif mode == MODE_ON_THE_WAY then
          activity.on_the_way = true
        elseif mode == MODE_NEED then
          activity.need = true
        end
      end
    end
  end

  return activity
end


local function normalize_surface_cursor(cursor, platform_count)
  if platform_count <= 0 then
    return 1
  end
  if cursor == nil or cursor < 1 or cursor > platform_count then
    return 1
  end
  return cursor
end


local function audit_surface_platform_slice(force_index, surface_name, current_tick, slice_size, cursor_field, audit_requests, audit_on_the_way, audit_need_inventory)
  local state = ensure_surface_state(force_index, surface_name)
  local platform_indices = get_surface_platform_indices(force_index, surface_name)
  local platform_count = #platform_indices

  if cursor_field == "hot_cursor" then
    state.last_hot_audit_tick = current_tick
  else
    state.last_cold_audit_tick = current_tick
  end

  if platform_count == 0 then
    state[cursor_field] = 1
    return false
  end

  local cursor = normalize_surface_cursor(state[cursor_field], platform_count)
  local inspected = 0

  while inspected < slice_size and platform_count > 0 do
    if cursor > platform_count then
      cursor = 1
    end

    local platform_index = platform_indices[cursor]
    cursor = cursor + 1
    inspected = inspected + 1

    local entry = storage.ei.orbital_combinator_platform_cache[platform_index]
    local platform = entry and get_platform_from_entry(platform_index, entry) or nil
    if platform and platform.valid then
      if audit_requests then
        refresh_platform_request_component(platform, current_tick, true)
      end
      if audit_on_the_way then
        refresh_platform_on_the_way_component(platform, current_tick, true)
      end
      if audit_need_inventory then
        refresh_platform_need_inventory_component(platform, current_tick, true)
      end
    else
      local stale_entry = storage.ei.orbital_combinator_platform_cache[platform_index]
      local stale_force_index = stale_entry and stale_entry.force_index or force_index
      local stale_surface_name = stale_entry and stale_entry.surface_name or surface_name
      remove_platform_cache_entry(platform_index)
      if stale_force_index and stale_surface_name then
        bump_surface_generations(stale_force_index, stale_surface_name, {MODE_REQUESTS, MODE_ON_THE_WAY, MODE_NEED})
        wake_surface_banks(stale_force_index, stale_surface_name, current_tick)
      end
      platform_indices = get_surface_platform_indices(force_index, surface_name)
      platform_count = #platform_indices
      cursor = normalize_surface_cursor(cursor, platform_count)
    end
  end

  state[cursor_field] = normalize_surface_cursor(cursor, platform_count)
  return inspected > 0
end


local function find_due_surface(current_tick, kind, advance_cursor)
  local state_root = get_surface_state_root()
  local total = ei_runtime_scheduler.table_count(state_root)
  if total == 0 then
    return nil, nil
  end

  local cursor_name = kind == "hot"
    and "orbital_combinator_hot_surface_break_point"
    or "orbital_combinator_cold_surface_break_point"
  local cursor = storage.ei[cursor_name]
  if cursor ~= nil and state_root[cursor] == nil then
    cursor = nil
    if advance_cursor then
      storage.ei[cursor_name] = nil
    end
  end
  local next_cursor = cursor
  local scanned = 0

  while scanned < total do
    local surface_key, state = next_collection_entry(state_root, next_cursor)
    if surface_key == nil then
      surface_key, state = next_collection_entry(state_root, nil)
    end
    if surface_key == nil then
      if advance_cursor then
        storage.ei[cursor_name] = nil
      end
      return nil, nil
    end

    local resume_surface_key = next_collection_entry(state_root, surface_key)
    if advance_cursor then
      storage.ei[cursor_name] = resume_surface_key
    end
    next_cursor = resume_surface_key
    scanned = scanned + 1

    local bank_ids = get_surface_bank_ids(state.force_index, state.surface_name)
    local platform_indices = get_surface_platform_indices(state.force_index, state.surface_name)
    if #bank_ids == 0 and #platform_indices == 0 then
      state_root[surface_key] = nil
    elseif kind == "hot" then
      if surface_has_hot_interest(state.force_index, state.surface_name, current_tick)
        and current_tick >= ((state.last_hot_audit_tick or 0) + HOT_BANK_PLATFORM_POLL_INTERVAL) then
        return surface_key, state
      end
    elseif current_tick >= ((state.last_cold_audit_tick or 0) + COLD_BANK_AUDIT_INTERVAL) then
      return surface_key, state
    end
  end

  return nil, nil
end


local function service_hot_surface(state, current_tick)
  state = state or {}
  state.last_hot_audit_tick = current_tick

  local activity = collect_surface_bank_activity(state.force_index, state.surface_name, current_tick, true)
  if not activity.has_banks or not activity.hot then
    return false
  end

  local audit_requests = activity.requests or activity.need
  local audit_on_the_way = activity.on_the_way or activity.need
  local audit_need_inventory = activity.need
  if not audit_requests and not audit_on_the_way and not audit_need_inventory then
    return false
  end

  return audit_surface_platform_slice(
    state.force_index,
    state.surface_name,
    current_tick,
    HOT_SURFACE_AUDIT_SLICE,
    "hot_cursor",
    audit_requests,
    audit_on_the_way,
    audit_need_inventory
  )
end


local function service_cold_surface(state, current_tick)
  state = state or {}
  state.last_cold_audit_tick = current_tick

  local activity = collect_surface_bank_activity(state.force_index, state.surface_name, current_tick, false)
  if not activity.has_banks then
    return false
  end

  return audit_surface_platform_slice(
    state.force_index,
    state.surface_name,
    current_tick,
    COLD_SURFACE_AUDIT_SLICE,
    "cold_cursor",
    activity.requests or activity.need,
    activity.on_the_way or activity.need,
    activity.need
  )
end


local function find_hot_dirty_bank_candidate(current_tick)
  local queue = get_dirty_bank_queue()

  for index = queue.head, queue.tail do
    local bank_id = queue.items[index]
    if bank_id ~= nil then
      local bank = storage.ei.orbital_combinator_banks and storage.ei.orbital_combinator_banks[bank_id] or nil
      if bank and is_bank_hot(bank, current_tick) then
        return bank_id, bank
      end
    end
  end

  return nil, nil
end


local function find_cold_dirty_bank_candidate(current_tick)
  local queue = get_dirty_bank_queue()

  for index = queue.head, queue.tail do
    local bank_id = queue.items[index]
    if bank_id ~= nil then
      local bank = storage.ei.orbital_combinator_banks and storage.ei.orbital_combinator_banks[bank_id] or nil
      if not bank or not is_bank_hot(bank, current_tick) then
        return bank_id, bank
      end
    end
  end

  return nil, nil
end


local function service_dirty_bank_candidate(bank_id, bank, current_tick)
  if not bank_id then
    return false
  end

  if not bank then
    ei_runtime_scheduler.queue_remove_value(get_dirty_bank_queue(), bank_id)
    return true
  end

  if not model.update_orbital_bank(bank, current_tick) then
    return false
  end

  ei_runtime_scheduler.queue_remove_value(get_dirty_bank_queue(), bank_id)
  return true
end


local function service_hot_dirty_bank(current_tick)
  local bank_id, bank = find_hot_dirty_bank_candidate(current_tick)
  return service_dirty_bank_candidate(bank_id, bank, current_tick)
end


local function service_cold_dirty_bank(current_tick)
  local bank_id, bank = find_cold_dirty_bank_candidate(current_tick)
  return service_dirty_bank_candidate(bank_id, bank, current_tick)
end


local function find_due_connection_audit_bank(current_tick, advance_cursor)
  local banks = storage.ei.orbital_combinator_banks or {}
  local total = storage.ei.orbital_combinator_bank_count or ei_lib.getn(banks)
  if total <= 0 then
    if advance_cursor then
      storage.ei.orbital_combinator_connection_audit_break_point = nil
    end
    return nil
  end

  local cursor = storage.ei.orbital_combinator_connection_audit_break_point
  if cursor ~= nil and banks[cursor] == nil then
    cursor = nil
    if advance_cursor then
      storage.ei.orbital_combinator_connection_audit_break_point = nil
    end
  end
  local next_cursor = cursor
  local scanned = 0

  while scanned < total do
    local bank_id, bank = next_collection_entry(banks, next_cursor)
    if bank_id == nil then
      bank_id, bank = next_collection_entry(banks, nil)
    end
    if bank_id == nil then
      if advance_cursor then
        storage.ei.orbital_combinator_connection_audit_break_point = nil
      end
      return nil
    end

    if advance_cursor then
      storage.ei.orbital_combinator_connection_audit_break_point = bank_id
    end
    next_cursor = bank_id
    scanned = scanned + 1

    if bank and current_tick >= ((bank.last_connection_audit_tick or 0) + BANK_CONNECTION_AUDIT_INTERVAL) then
      return bank
    end
  end

  return nil
end


local function service_bank_connection_audit(current_tick)
  local queued_bank_id = ei_runtime_scheduler.queue_peek(get_bank_audit_queue())
  if queued_bank_id ~= nil then
    ei_runtime_scheduler.queue_pop(get_bank_audit_queue(), queued_bank_id)

    local queued_bank = storage.ei.orbital_combinator_banks and storage.ei.orbital_combinator_banks[queued_bank_id] or nil
    if not queued_bank then
      return true
    end

    local queued_members = get_bank_members(queued_bank)
    if not queued_members or #queued_members == 0 then
      model.rebuild_banks()
      return false
    end

    audit_bank_wired_state(queued_bank, queued_members, current_tick)
    return true
  end

  local bank = find_due_connection_audit_bank(current_tick, true)
  if not bank then
    return false
  end

  local members = get_bank_members(bank)
  if not members or #members == 0 then
    model.rebuild_banks()
    return false
  end

  audit_bank_wired_state(bank, members, current_tick)
  return true
end


local function service_surface_queue(queue_getter, current_tick, surface_service)
  local surface_key = ei_runtime_scheduler.queue_peek(queue_getter())
  if surface_key == nil then
    return false
  end

  ei_runtime_scheduler.queue_pop(queue_getter(), surface_key)

  local state = get_surface_state_root()[surface_key]
  if not state then
    return true
  end

  surface_service(state, current_tick)
  return true
end


local function service_hot_surface_work(current_tick)
  if service_surface_queue(get_hot_surface_queue, current_tick, service_hot_surface) then
    return true
  end

  local _, state = find_due_surface(current_tick, "hot", true)
  if not state then
    return false
  end

  return service_hot_surface(state, current_tick)
end


local function service_cold_surface_work(current_tick)
  if service_surface_queue(get_cold_surface_queue, current_tick, service_cold_surface) then
    return true
  end

  local _, state = find_due_surface(current_tick, "cold", true)
  if not state then
    return false
  end

  return service_cold_surface(state, current_tick)
end


local function service_incremental_reconcile(current_tick)
  return reconcile_platform_cache(current_tick)
end


local function has_hot_dirty_bank_work(current_tick)
  return find_hot_dirty_bank_candidate(current_tick) ~= nil
end


local function has_hot_surface_work(current_tick)
  return ei_runtime_scheduler.queue_peek(get_hot_surface_queue()) ~= nil
    or find_due_surface(current_tick, "hot", false) ~= nil
end


local function has_bank_connection_audit_work(current_tick)
  return ei_runtime_scheduler.queue_peek(get_bank_audit_queue()) ~= nil
    or find_due_connection_audit_bank(current_tick, false) ~= nil
end


local function has_cold_dirty_bank_work(current_tick)
  return find_cold_dirty_bank_candidate(current_tick) ~= nil
end


local function has_incremental_reconcile_work(current_tick)
  local state = get_reconcile_state()
  return state.in_progress == true
    or (has_registered_banks() and current_tick >= (state.next_due_tick or 0))
end


local function has_cold_surface_work(current_tick)
  return ei_runtime_scheduler.queue_peek(get_cold_surface_queue()) ~= nil
    or find_due_surface(current_tick, "cold", false) ~= nil
end


local function has_work_for_class(work_class_name, current_tick)
  if work_class_name == "hot_dirty_bank" then
    return has_hot_dirty_bank_work(current_tick)
  end
  if work_class_name == "hot_surface_audit" then
    return has_hot_surface_work(current_tick)
  end
  if work_class_name == "bank_connection_audit" then
    return has_bank_connection_audit_work(current_tick)
  end
  if work_class_name == "cold_dirty_bank" then
    return has_cold_dirty_bank_work(current_tick)
  end
  if work_class_name == "incremental_reconcile" then
    return has_incremental_reconcile_work(current_tick)
  end
  if work_class_name == "cold_surface_audit" then
    return has_cold_surface_work(current_tick)
  end

  return false
end


local function service_work_class(work_class_name, current_tick)
  if work_class_name == "hot_dirty_bank" then
    return service_hot_dirty_bank(current_tick)
  end
  if work_class_name == "hot_surface_audit" then
    return service_hot_surface_work(current_tick)
  end
  if work_class_name == "bank_connection_audit" then
    return service_bank_connection_audit(current_tick)
  end
  if work_class_name == "cold_dirty_bank" then
    return service_cold_dirty_bank(current_tick)
  end
  if work_class_name == "incremental_reconcile" then
    return service_incremental_reconcile(current_tick)
  end
  if work_class_name == "cold_surface_audit" then
    return service_cold_surface_work(current_tick)
  end

  return false
end


local function select_work_class(current_tick)
  local pending = {}
  local overdue_candidate = nil

  for _, definition in ipairs(WORK_CLASS_DEFINITIONS) do
    if has_work_for_class(definition.name, current_tick) then
      local service_state = get_work_service_state(definition.name)
      local overdue_by = current_tick - ((service_state.last_served_tick or 0) + (service_state.deadline_ticks or definition.deadline_ticks or 0))
      local candidate = {
        definition = definition,
        overdue_by = overdue_by,
      }

      pending[#pending + 1] = candidate
      if overdue_by >= 0 and (
        not overdue_candidate
        or overdue_by > overdue_candidate.overdue_by
        or (overdue_by == overdue_candidate.overdue_by and definition.order < overdue_candidate.definition.order)
      ) then
        overdue_candidate = candidate
      end
    end
  end

  if overdue_candidate then
    return overdue_candidate.definition
  end

  return pending[1] and pending[1].definition or nil
end


local function get_member_slot_capacity(entity)
  -- Runtime prototypes do not expose the data-stage item_slot_count, and
  -- LuaLogisticSection.filters_count is only the number of populated filters,
  -- not the section's writable capacity. The orbital scanner prototype is fixed,
  -- so we use its declared slot count directly.
  return DEFAULT_MEMBER_SLOT_CAPACITY
end


get_bank_members = function(bank)
  local members = {}
  local min_capacity = nil

  for _, unit_number in ipairs(bank.members or {}) do
    local entity = storage.ei.orbital_combinators[unit_number]
    if not is_registered_scanner(entity) then
      return nil
    end

    local capacity = math.max(1, get_member_slot_capacity(entity))
    members[#members + 1] = {
      unit_number = unit_number,
      entity = entity,
      capacity = capacity,
    }

    if not min_capacity or capacity < min_capacity then
      min_capacity = capacity
    end
  end

  return members, min_capacity or DEFAULT_MEMBER_SLOT_CAPACITY
end


local function make_page_label(platform_name, page_index, page_count)
  if page_index == 1 then
    return platform_name
  end

  return string.format("%s [%d/%d]", platform_name, page_index, page_count)
end


local function make_page(label, filters, start_index, stop_index)
  local filter_count = 0
  if filters and start_index and stop_index and stop_index >= start_index then
    filter_count = stop_index - start_index + 1
  end

  return {
    label = label,
    filters = filters,
    start_index = start_index or 1,
    stop_index = stop_index or 0,
    filter_count = filter_count,
    cost = math.max(1, filter_count),
  }
end


local function make_inline_page(label, filters)
  return make_page(label, filters, 1, #filters)
end


local function get_page_filter_count(page)
  return page.filter_count or 0
end


local function iter_page_filters(page, callback)
  local filters = page.filters
  if not filters then
    return
  end

  local start_index = page.start_index or 1
  local stop_index = page.stop_index or 0
  if stop_index < start_index then
    return
  end

  local page_slot_index = 1
  for filter_index = start_index, stop_index do
    callback(filters[filter_index], page_slot_index, filter_index)
    page_slot_index = page_slot_index + 1
  end
end


local function split_platform_into_pages(platform, page_capacity)
  local pages = {}
  local filters = platform.filters
  local filter_count = #filters
  local page_count = math.max(1, math.ceil(filter_count / page_capacity))

  for page_index = 1, page_count do
    local start_index = ((page_index - 1) * page_capacity) + 1
    local stop_index = math.min(start_index + page_capacity - 1, filter_count)

    if filter_count == 0 then
      start_index = 1
      stop_index = 0
    end

    pages[#pages + 1] = make_page(
      make_page_label(platform.name, page_index, page_count),
      filters,
      start_index,
      stop_index
    )
  end

  return pages
end


local function build_bank_pages(snapshot, page_capacity)
  local pages = {}

  for _, platform in ipairs(snapshot.platforms) do
    local platform_pages = split_platform_into_pages(platform, page_capacity)
    for _, page in ipairs(platform_pages) do
      pages[#pages + 1] = page
    end
  end

  return pages
end


local function get_cached_pages(snapshot, page_capacity)
  local cache_key = tostring(page_capacity)
  if not snapshot.pages_by_capacity[cache_key] then
    snapshot.pages_by_capacity[cache_key] = build_bank_pages(snapshot, page_capacity)
  end

  return snapshot.pages_by_capacity[cache_key]
end


local function assign_pages_to_members(members, pages, reserved_anchor_cost)
  local layouts = {}
  local used_cost = {}
  local member_index = 1
  local omitted_filter_count = 0

  for index, member in ipairs(members) do
    layouts[member.unit_number] = {}
    used_cost[index] = 0
  end

  local function remaining_capacity(index)
    local reserve = 0
    if index == 1 then
      reserve = reserved_anchor_cost
    end

    return members[index].capacity - reserve - used_cost[index]
  end

  for _, page in ipairs(pages) do
    while member_index <= #members and remaining_capacity(member_index) < page.cost do
      member_index = member_index + 1
    end

    if member_index > #members then
      omitted_filter_count = omitted_filter_count + get_page_filter_count(page)
    else
      local member_layout = layouts[members[member_index].unit_number]
      member_layout[#member_layout + 1] = page
      used_cost[member_index] = used_cost[member_index] + page.cost
    end
  end

  return layouts, omitted_filter_count
end


local function append_overflow_page(layouts, anchor_unit_number, omitted_filter_count)
  if omitted_filter_count <= 0 then
    return
  end

  local overflow_filter = make_filter(OVERFLOW_SIGNAL, omitted_filter_count, nil)
  if not overflow_filter then
    return
  end

  layouts[anchor_unit_number] = layouts[anchor_unit_number] or {}
  layouts[anchor_unit_number][#layouts[anchor_unit_number] + 1] = make_inline_page(
    OVERFLOW_SECTION_GROUP,
    {overflow_filter}
  )
end


local function build_layout_signature(bank, layouts)
  local hash = 5381

  for _, unit_number in ipairs(bank.members or {}) do
    local member_pages = layouts[unit_number] or {}
    hash = hash_update(hash, unit_number)
    hash = hash_update(hash, #member_pages)

    for _, page in ipairs(member_pages) do
      hash = hash_update(hash, page.label)
      hash = hash_update(hash, get_page_filter_count(page))

      iter_page_filters(page, function(filter)
        hash = hash_update(hash, filter.value.type or "item")
        hash = hash_update(hash, filter.value.name or "")
        hash = hash_update(hash, filter.value.quality or "normal")
        hash = hash_update(hash, filter.min or 0)
        hash = hash_update(hash, filter.max == nil and "nil" or filter.max)
      end)
    end
  end

  return string.format("%08x", hash)
end


local function filters_match(slot, expected_filter)
  if not slot or not slot.value then
    return false
  end

  local signal = normalize_signal_id(slot.value)
  if not signal then
    return false
  end

  if signal.type ~= expected_filter.value.type then
    return false
  end
  if signal.name ~= expected_filter.value.name then
    return false
  end
  if signal.quality ~= expected_filter.value.quality then
    return false
  end
  if slot.min ~= expected_filter.min then
    return false
  end
  if slot.max ~= expected_filter.max then
    return false
  end

  return true
end


local function reconcile_section(section, page)
  if section.active ~= true then
    section.active = true
  end

  if section.group ~= page.label then
    section.group = page.label
  end

  local current_count = section.filters_count
  local desired_count = get_page_filter_count(page)

  if current_count > desired_count then
    for index = current_count, desired_count + 1, -1 do
      section.clear_slot(index)
    end
  end

  iter_page_filters(page, function(filter, page_slot_index)
    if not filters_match(section.get_slot(page_slot_index), filter) then
      section.set_slot(page_slot_index, {
        value = copy_signal_id(filter.value),
        min = filter.min,
        max = filter.max,
      })
    end
  end)
end


local function reconcile_entity(entity, desired_pages)
  local control = entity.get_control_behavior()
  if not control or not control.valid then
    return false
  end

  while control.sections_count > #desired_pages do
    if not control.remove_section(control.sections_count) then
      return false
    end
  end

  while control.sections_count < #desired_pages do
    if not control.add_section("") then
      return false
    end
  end

  for index, page in ipairs(desired_pages) do
    local section = control.get_section(index)
    if not section then
      return false
    end

    reconcile_section(section, page)
  end

  return true
end


local function build_bank_input_signature(bank, members, snapshot)
  local hash = 5381
  hash = hash_update(hash, bank.force_index or 0)
  hash = hash_update(hash, bank.surface_index or 0)
  hash = hash_update(hash, get_bank_mode(bank))
  hash = hash_update(hash, snapshot.signature or "")
  hash = hash_update(hash, #members)

  for _, member in ipairs(members) do
    hash = hash_update(hash, member.unit_number)
    hash = hash_update(hash, member.capacity)
  end

  return string.format("%08x", hash)
end


local function build_bank_layout(bank, members, page_capacity, snapshot)
  local pages = get_cached_pages(snapshot, page_capacity)
  local layouts, omitted_filter_count = assign_pages_to_members(members, pages, 0)

  if omitted_filter_count > 0 then
    local overflow_page_capacity = math.max(1, page_capacity - 1)
    pages = get_cached_pages(snapshot, overflow_page_capacity)
    layouts, omitted_filter_count = assign_pages_to_members(members, pages, 1)
    append_overflow_page(layouts, bank.anchor_unit_number, omitted_filter_count)
  end

  return layouts
end


local function build_member_layout_state_signature(bank, members)
  local hash = 5381
  hash = hash_update(hash, get_bank_mode(bank))
  hash = hash_update(hash, bank.anchor_unit_number or 0)
  hash = hash_update(hash, #members)

  for _, member in ipairs(members) do
    hash = hash_update(hash, member.unit_number)
    hash = hash_update(hash, member.capacity)
  end

  return string.format("%08x", hash)
end


local function build_member_layout_signature(desired_pages)
  local hash = 5381
  hash = hash_update(hash, #desired_pages)

  for _, page in ipairs(desired_pages) do
    hash = hash_update(hash, page.label or "")
    hash = hash_update(hash, get_page_filter_count(page))

    iter_page_filters(page, function(filter)
      hash = hash_update(hash, filter.value.type or "item")
      hash = hash_update(hash, filter.value.name or "")
      hash = hash_update(hash, filter.value.quality or "normal")
      hash = hash_update(hash, filter.min or 0)
      hash = hash_update(hash, filter.max == nil and "nil" or filter.max)
    end)
  end

  return string.format("%08x", hash)
end


audit_bank_wired_state = function(bank, members, current_tick)
  if current_tick < ((bank.last_connection_audit_tick or 0) + BANK_CONNECTION_AUDIT_INTERVAL) then
    return
  end

  bank.last_connection_audit_tick = current_tick
  bank.wired = false

  for _, member in ipairs(members) do
    if entity_has_external_circuit_connection(member.entity) then
      bank.wired = true
      return
    end
  end
end


is_bank_hot = function(bank, current_tick)
  return (bank.open_gui_count or 0) > 0
    or bank.wired == true
    or (bank.hot_until_tick or 0) >= current_tick
end


local function get_bank_generation_token(bank, anchor)
  return get_generation_token(anchor.force.index, anchor.surface.name, get_bank_mode(bank))
end


function model.update_orbital_bank(bank, current_tick)
  if not bank then
    return false
  end

  current_tick = current_tick or (game and game.tick) or 0
  local members, page_capacity = get_bank_members(bank)
  if not members or #members == 0 then
    model.rebuild_banks()
    return false
  end

  local anchor = members[1].entity
  local member_layout_state_signature = build_member_layout_state_signature(bank, members)
  if bank.member_layout_state_signature ~= member_layout_state_signature then
    bank.member_layout_state_signature = member_layout_state_signature
    bank.member_layout_signatures = nil
  end
  audit_bank_wired_state(bank, members, current_tick)
  local generation_token = get_bank_generation_token(bank, anchor)
  local snapshot = get_surface_snapshot(anchor.force, anchor.surface, get_bank_mode(bank))
  local input_signature = build_bank_input_signature(bank, members, snapshot)

  if bank.input_signature == input_signature then
    bank.last_applied_generation_token = generation_token
    return true
  end

  local layouts = build_bank_layout(bank, members, page_capacity, snapshot)
  local signature = build_layout_signature(bank, layouts)
  if bank.signature == signature then
    bank.input_signature = input_signature
    bank.last_applied_generation_token = generation_token
    return true
  end

  local current_member_layout_signatures = bank.member_layout_signatures or {}
  local next_member_layout_signatures = {}
  for _, member in ipairs(members) do
    local desired_pages = layouts[member.unit_number] or {}
    local desired_signature = build_member_layout_signature(desired_pages)
    next_member_layout_signatures[member.unit_number] = desired_signature

    if current_member_layout_signatures[member.unit_number] ~= desired_signature
      and not reconcile_entity(member.entity, desired_pages) then
      invalidate_bank(bank)
      return false
    end
  end

  bank.signature = signature
  bank.input_signature = input_signature
  bank.last_applied_generation_token = generation_token
  bank.member_layout_signatures = next_member_layout_signatures
  return true
end


local function get_bank_for_unit_number(unit_number)
  if not unit_number then
    return nil
  end

  local bank_id = storage.ei.orbital_combinator_bank_by_unit[unit_number]
  return bank_id and storage.ei.orbital_combinator_banks[bank_id] or nil
end


local function get_player_open_bank(player_index)
  local unit_number = storage.ei.orbital_combinator_open_gui_by_player[player_index]
  return unit_number and get_bank_for_unit_number(unit_number) or nil
end


local function set_player_open_gui(player_index, unit_number)
  local open_gui_by_player = storage.ei.orbital_combinator_open_gui_by_player
  local previous_unit_number = open_gui_by_player[player_index]
  if previous_unit_number == unit_number then
    return
  end

  local previous_bank = get_bank_for_unit_number(previous_unit_number)
  if previous_bank and (previous_bank.open_gui_count or 0) > 0 then
    previous_bank.open_gui_count = previous_bank.open_gui_count - 1
  end

  if unit_number then
    open_gui_by_player[player_index] = unit_number
    local next_bank = get_bank_for_unit_number(unit_number)
    if next_bank then
      next_bank.open_gui_count = (next_bank.open_gui_count or 0) + 1
      wake_bank(next_bank, game and game.tick or 0)
    end
  else
    open_gui_by_player[player_index] = nil
  end
end


local function close_gui(player)
  if player and player.gui and player.gui.relative and player.gui.relative[GUI_NAME] then
    player.gui.relative[GUI_NAME].destroy()
  end
end


local function build_gui(player)
  close_gui(player)

  local root = player.gui.relative.add{
    type = "frame",
    name = GUI_NAME,
    anchor = {
      gui = defines.relative_gui_type.constant_combinator_gui,
      name = ORBITAL_COMBINATOR_NAME,
      position = defines.relative_gui_position.right,
    },
    direction = "vertical",
  }

  local titlebar = root.add{type = "flow", direction = "horizontal"}
  titlebar.add{
    type = "label",
    caption = {"exotic-industries.orbital-scanner-gui-title"},
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
      page = "orbital_scanner",
    },
  }

  local main = root.add{
    type = "frame",
    name = "main-container",
    direction = "vertical",
    style = "inside_shallow_frame",
  }

  main.add{
    type = "frame",
    style = "ei_subheader_frame",
  }.add{
    type = "label",
    caption = {"exotic-industries.orbital-scanner-gui-mode-title"},
    style = "subheader_caption_label",
  }

  local button_flow = main.add{
    type = "flow",
    name = "mode-flow",
    direction = "vertical",
    style = "ei_inner_content_flow",
  }

  local modes = {
    {mode = MODE_REQUESTS, caption = {"exotic-industries.orbital-scanner-gui-mode-requests"}, tooltip = {"exotic-industries.orbital-scanner-gui-mode-requests-tooltip"}},
    {mode = MODE_ON_THE_WAY, caption = {"exotic-industries.orbital-scanner-gui-mode-on-the-way"}, tooltip = {"exotic-industries.orbital-scanner-gui-mode-on-the-way-tooltip"}},
    {mode = MODE_NEED, caption = {"exotic-industries.orbital-scanner-gui-mode-need"}, tooltip = {"exotic-industries.orbital-scanner-gui-mode-need-tooltip"}},
  }

  for _, mode_data in ipairs(modes) do
    button_flow.add{
      type = "button",
      name = "mode-" .. mode_data.mode,
      caption = mode_data.caption,
      tooltip = mode_data.tooltip,
      tags = {
        parent_gui = GUI_NAME,
        action = "set-mode",
        mode = mode_data.mode,
      },
    }
  end

  main.add{
    type = "label",
    name = "shared-note",
    caption = {"exotic-industries.orbital-scanner-gui-mode-shared-note"},
    style = "caption_label",
  }

  return root
end


local function refresh_player_gui(player)
  if not player or not player.valid then
    return
  end

  local root = player.gui.relative[GUI_NAME] or build_gui(player)
  local bank = get_player_open_bank(player.index)
  local mode = get_bank_mode(bank)
  local mode_flow = root["main-container"] and root["main-container"]["mode-flow"]
  if not mode_flow then
    return
  end

  for _, mode_name in ipairs({MODE_REQUESTS, MODE_ON_THE_WAY, MODE_NEED}) do
    local button = mode_flow["mode-" .. mode_name]
    if button then
      button.style = mode_name == mode and "ei_green_button" or "button"
      button.enabled = mode_name ~= mode
    end
  end
end


local function refresh_open_player_guis()
  for player_index, _ in pairs(storage.ei.orbital_combinator_open_gui_by_player or {}) do
    local player = game.get_player(player_index)
    if player then
      refresh_player_gui(player)
    end
  end
end


function model.get_bank_count()
  model.check_init(false)
  return storage.ei.orbital_combinator_bank_count or 0
end


function model.on_entity_logistic_slot_changed(event)
  if not has_registered_banks() then
    return
  end
  if not event or not event.entity or not event.entity.valid then
    return
  end
  if event.entity.type ~= SPACE_PLATFORM_HUB_ENTITY_TYPE then
    return
  end

  mark_platform_hub_dirty(event.entity, false)
end


function model.on_entity_settings_pasted(event)
  if not has_registered_banks() then
    return
  end
  if not event or not event.destination or not event.destination.valid then
    return
  end
  if event.destination.type ~= SPACE_PLATFORM_HUB_ENTITY_TYPE then
    return
  end

  mark_platform_hub_dirty(event.destination, true)
end


function model.on_rocket_launch_ordered(event)
  if not has_registered_banks() then
    return
  end

  local platform = get_destination_platform_from_rocket(event)
  if platform then
    mark_platform_surface_modes_dirty(platform, {MODE_ON_THE_WAY, MODE_NEED}, event and event.tick or game.tick)
  end
end


function model.on_cargo_pod_started_ascending(event)
  if not has_registered_banks() then
    return
  end

  local platform = get_destination_platform_from_pod(event and event.cargo_pod or nil)
  if platform then
    mark_platform_surface_modes_dirty(platform, {MODE_ON_THE_WAY, MODE_NEED}, event and event.tick or game.tick)
  end
end


function model.on_cargo_pod_finished_ascending(event)
  if not has_registered_banks() then
    return
  end

  local platform = get_destination_platform_from_pod(event and event.cargo_pod or nil)
  if platform then
    mark_platform_surface_modes_dirty(platform, {MODE_ON_THE_WAY, MODE_NEED}, event and event.tick or game.tick)
  end
end


function model.on_cargo_pod_delivered_cargo(event)
  if not has_registered_banks() then
    return
  end

  local pod = event and event.cargo_pod or nil
  local surface = pod and pod.surface or nil
  local platform = surface and surface.valid and surface.platform or nil
  if platform and platform.valid then
    mark_platform_surface_modes_dirty(platform, {MODE_ON_THE_WAY, MODE_NEED}, event and event.tick or game.tick)
  end
end


function model.on_space_platform_changed_state(event)
  if not has_registered_banks() then
    return
  end
  if not event or not event.platform or not event.platform.valid then
    clear_snapshot_cache()
    return
  end

  local current_tick = event.tick or game.tick
  local force_index = event.platform.force.index
  local current_surface_name = get_platform_surface_name(event.platform)
  local entry = storage.ei.orbital_combinator_platform_cache[event.platform.index]
  local previous_surface_name = entry and entry.surface_name or nil

  if entry then
    entry.force_index = force_index
    entry.surface_name = current_surface_name
  end

  mark_platform_dirty(event.platform.index)

  if current_surface_name then
    bump_surface_generations(force_index, current_surface_name, {MODE_ON_THE_WAY})
    wake_surface_banks(force_index, current_surface_name, current_tick)
  end

  if previous_surface_name and previous_surface_name ~= current_surface_name then
    bump_surface_generations(force_index, previous_surface_name, {MODE_REQUESTS, MODE_ON_THE_WAY, MODE_NEED})
    wake_surface_banks(force_index, previous_surface_name, current_tick)
  end
end


function model.on_destroyed_entity(event)
  if not has_registered_banks() then
    return
  end

  local entity = event and event.entity or nil
  local unit_number = ei_lib.get_entity_unit_number(entity)
  if not unit_number then
    return
  end

  if entity and entity.type == SPACE_PLATFORM_HUB_ENTITY_TYPE then
    local platform_index = storage.ei.orbital_combinator_platform_by_hub[unit_number]
    if platform_index then
      local entry = storage.ei.orbital_combinator_platform_cache[platform_index]
      if entry then
        entry.hub_unit_number = nil
        entry.request_dirty = true
        entry.dirty = true
      end
      storage.ei.orbital_combinator_platform_by_hub[unit_number] = nil
      mark_platform_dirty(platform_index)
    end
  end
end


function model.on_object_destroyed(event)
  if not event or not event.registration_number then
    return
  end

  model.check_init(false)

  local payload = storage.ei.orbital_combinator_object_registration[event.registration_number]
  if not payload then
    return
  end

  storage.ei.orbital_combinator_object_registration[event.registration_number] = nil

  if payload.kind == "platform" and payload.platform_index then
    local force_index, surface_name = get_platform_surface_context(payload.platform_index)
    remove_platform_cache_entry(payload.platform_index)
    if force_index and surface_name then
      bump_surface_generations(force_index, surface_name, {MODE_REQUESTS, MODE_ON_THE_WAY, MODE_NEED})
      wake_surface_banks(force_index, surface_name, event.tick or game.tick)
    else
      clear_snapshot_cache()
    end
    return
  end

  if payload.kind == "pod" and payload.pod_unit_number and storage.ei.orbital_combinator_incoming_pods then
    storage.ei.orbital_combinator_incoming_pods[payload.pod_unit_number] = nil
  end
end


function model.on_gui_opened(event)
  model.check_init(false)

  local player = game.get_player(event.player_index)
  if not player then
    return
  end

  local entity = player.opened
  if not is_registered_scanner(entity) then
    close_gui(player)
    set_player_open_gui(player.index, nil)
    return
  end

  set_player_open_gui(player.index, entity.unit_number)
  refresh_player_gui(player)
end


function model.on_gui_closed(event)
  model.check_init(false)

  local player = game.get_player(event.player_index)
  if not player then
    return
  end

  close_gui(player)
  set_player_open_gui(player.index, nil)
end


function model.on_gui_click(event)
  if not event or not event.element or not event.element.valid then
    return
  end

  local tags = event.element.tags or {}
  local action = tags.action
  if action == "goto-informatron" then
    remote.call("informatron", "informatron_open_to_page", {
      player_index = event.player_index,
      interface = "exotic-industries-informatron",
      page_name = tags.page,
    })
    return
  end

  if action ~= "set-mode" then
    return
  end

  model.check_init(false)

  local player = game.get_player(event.player_index)
  local unit_number = player and storage.ei.orbital_combinator_open_gui_by_player[event.player_index] or nil
  local bank = get_bank_for_unit_number(unit_number)
  if not bank then
    return
  end

  local next_mode = normalize_mode(tags.mode)
  if next_mode == get_bank_mode(bank) then
    return
  end

  bank.mode = next_mode
  for _, member_unit_number in ipairs(bank.members or {}) do
    set_unit_mode(member_unit_number, next_mode)
  end

  clear_snapshot_cache()
  wake_bank(bank, event.tick or game.tick)
  refresh_open_player_guis()
end


function model.get_pending_work_count()
  model.check_init(false)

  if not storage.ei or not storage.ei.orbital_combinator_banks then
    return 0
  end

  local current_tick = game and game.tick or 0
  local pending_work_count = 0

  pending_work_count = pending_work_count + ei_runtime_scheduler.queue_item_count(get_dirty_bank_queue())
  pending_work_count = pending_work_count + ei_runtime_scheduler.queue_item_count(get_bank_audit_queue())
  pending_work_count = pending_work_count + ei_runtime_scheduler.queue_item_count(get_hot_surface_queue())
  pending_work_count = pending_work_count + ei_runtime_scheduler.queue_item_count(get_cold_surface_queue())

  if has_hot_surface_work(current_tick) then
    pending_work_count = pending_work_count + 1
  end
  if has_bank_connection_audit_work(current_tick) then
    pending_work_count = pending_work_count + 1
  end
  if has_incremental_reconcile_work(current_tick) then
    pending_work_count = pending_work_count + 1
  end
  if has_cold_surface_work(current_tick) then
    pending_work_count = pending_work_count + 1
  end

  return pending_work_count
end


function model.update()
  model.check_init(false)

  if not storage.ei or not storage.ei.orbital_combinator_banks then
    return false
  end

  if storage.ei.orbital_combinator_bank_count == nil then
    storage.ei.orbital_combinator_bank_count = ei_lib.getn(storage.ei.orbital_combinator_banks)
  end

  local current_tick = game and game.tick or 0
  local selected_work_class = select_work_class(current_tick)
  if not selected_work_class then
    return false
  end

  if not service_work_class(selected_work_class.name, current_tick) then
    return false
  end

  mark_work_class_served(selected_work_class.name, current_tick)
  return model.get_pending_work_count() > 0
end


return model
