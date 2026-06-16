local REPORT_PATH = "beacon-overload-geometry-qc.jsonl"
local LOG_PREFIX = "BEACON_OVERLOAD_GEOMETRY_QC"
local COMPAT_REMOTE_NAME = "exotic-industries"
local SURFACE_NAME = "nauvis"
local ORIGIN = {x = 6200, y = 6200}
local BUILD_AREA = {
  left_top = {x = ORIGIN.x - 64, y = ORIGIN.y - 48},
  right_bottom = {x = ORIGIN.x + 292, y = ORIGIN.y + 48},
}
local MACHINE_OFFSET = {0.5, 0.5}
local SPEED_MODULE_NAME = "speed-module"
local ENERGY_BUFFER = 1000000000

local EDGE_BEACONS = {
  {name = "beacon", offset = {-4, 0}},
  {name = "beacon", offset = {0, -4}},
  {name = "beacon", offset = {0, 4}},
  {name = "beacon", offset = {-4, -4}},
  {name = "beacon", offset = {5, 0}},
}

local SCENARIOS = {
  {
    id = "edge-overlap",
    origin = {x = ORIGIN.x, y = ORIGIN.y},
    machine_name = "assembling-machine-3",
    machine_first = false,
    beacons = EDGE_BEACONS,
    expected_active = false,
    notes = "5 engine-affecting vanilla beacons, with the east beacon outside the old point-sample test",
  },
  {
    id = "edge-churn",
    origin = {x = ORIGIN.x + 50, y = ORIGIN.y},
    machine_name = "assembling-machine-3",
    machine_first = false,
    beacons = EDGE_BEACONS,
    churn_beacon_index = 5,
    expected_active = false,
    notes = "Remove and re-add the east edge beacon to prove queued full recounts clear stale overload",
  },
  {
    id = "weighted",
    origin = {x = ORIGIN.x + 100, y = ORIGIN.y},
    machine_name = "assembling-machine-3",
    machine_first = false,
    beacons = {
      {name = "zzz-bo-weighted-beacon", offset = {-4, 0}},
      {name = "zzz-bo-weighted-beacon", offset = {0, -4}},
      {name = "zzz-bo-weighted-beacon", offset = {0, 4}},
    },
    expected_active = false,
    notes = "3 helper beacons count as 6 ESIR overload weight",
  },
  {
    id = "excluded",
    origin = {x = ORIGIN.x + 150, y = ORIGIN.y},
    machine_name = "assembling-machine-3",
    machine_first = false,
    beacons = {
      {name = "beacon", offset = {-4, 0}},
      {name = "beacon", offset = {0, -4}},
      {name = "beacon", offset = {0, 4}},
      {name = "beacon", offset = {-4, -4}},
      {name = "zzz-bo-excluded-beacon", offset = {5, 0}},
    },
    expected_active = true,
    notes = "4 normal beacons plus 1 ESIR-excluded helper beacon should not overload",
  },
  {
    id = "long-range",
    origin = {x = ORIGIN.x + 200, y = ORIGIN.y},
    machine_name = "assembling-machine-3",
    machine_first = true,
    beacons = {
      {name = "zzz-bo-long-beacon", offset = {-10, 0}},
      {name = "zzz-bo-long-beacon", offset = {0, -10}},
      {name = "zzz-bo-long-beacon", offset = {0, 10}},
      {name = "zzz-bo-long-beacon", offset = {-10, -10}},
      {name = "zzz-bo-long-beacon", offset = {10, 0}},
    },
    expected_active = false,
    notes = "Machine is placed before 5 range-12 beacons outside the old default range",
  },
  {
    id = "heat-furnace",
    origin = {x = ORIGIN.x + 250, y = ORIGIN.y},
    machine_name = "ei-heat-steel-furnace",
    machine_first = true,
    force_active_before_beacons = true,
    beacons = EDGE_BEACONS,
    expected_active = true,
    notes = "ESIR heat steel furnace has uses_beacon_effects=false and should not be overload-disabled",
  },
}

local SCENARIO_BY_ID = {}
for _, scenario in ipairs(SCENARIOS) do
  SCENARIO_BY_ID[scenario.id] = scenario
end

local ACTIONS = {
  {tick = 30, name = "remove-edge-churn-beacon"},
  {tick = 60, name = "readd-edge-churn-beacon"},
}

local CHECKPOINTS = {
  {tick = 5, label = "initial"},
  {tick = 35, label = "after-edge-remove"},
  {tick = 70, label = "after-edge-readd"},
  {tick = 120, label = "steady-state"},
  {tick = 720, label = "final"},
}

local function ensure_state()
  storage.beacon_overload_geometry_qc = storage.beacon_overload_geometry_qc or {}
  local state = storage.beacon_overload_geometry_qc
  state.built = state.built or false
  state.base_tick = state.base_tick or 0
  state.action_index = state.action_index or 1
  state.checkpoint_index = state.checkpoint_index or 1
  state.scenarios = state.scenarios or {}
  return state
end

local function encode_record(record)
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

  return serpent and serpent.line and serpent.line(record, {comment = false}) or ""
end

local function write_file(path, contents, append)
  if helpers and helpers.write_file then
    helpers.write_file(path, contents, append and true or false, 0)
  elseif game and game.write_file then
    game.write_file(path, contents, append and true or false, 0)
  end
end

local function write_record(record)
  record.tick = record.tick or (game and game.tick or 0)
  local encoded = encode_record(record)
  if encoded == "" then
    return
  end

  log(LOG_PREFIX .. " " .. encoded)
  write_file(REPORT_PATH, encoded .. "\n", true)
end

local function call_compat(member_name, ...)
  if not remote.interfaces[COMPAT_REMOTE_NAME] or not remote.interfaces[COMPAT_REMOTE_NAME][member_name] then
    return false, "missing-remote"
  end

  return pcall(remote.call, COMPAT_REMOTE_NAME, member_name, ...)
end

local function configure_beacon_rules()
  local calls = {
    {
      name = "set-weighted",
      member = "set_beacon_overload_beacon_weight",
      args = {"zzz-bo-weighted-beacon", 2},
    },
    {
      name = "exclude-helper",
      member = "add_beacon_overload_beacon_exclusion",
      args = {"zzz-bo-excluded-beacon"},
    },
  }

  for _, call in ipairs(calls) do
    local ok, result = call_compat(call.member, call.args[1], call.args[2])
    write_record({
      event = "compat-rule",
      name = call.name,
      ok = ok == true,
      result = result,
    })
  end
end

local function get_force()
  return game.forces.player or game.forces[1]
end

local function get_surface()
  local surface = game.surfaces[SURFACE_NAME]
  if surface and surface.valid then
    return surface
  end

  return game.surfaces[1]
end

local function relative_position(origin, offset)
  return {
    x = origin.x + MACHINE_OFFSET[1] + offset[1],
    y = origin.y + MACHINE_OFFSET[2] + offset[2],
  }
end

local function machine_position(origin)
  return relative_position(origin, {0, 0})
end

local function energize(entity)
  if not (entity and entity.valid) then
    return
  end

  local ok, energy = pcall(function()
    return entity.energy
  end)
  if ok and energy ~= nil then
    pcall(function()
      entity.energy = ENERGY_BUFFER
    end)
  end
end

local function insert_speed_modules(entity)
  if not (entity and entity.valid) then
    return 0
  end

  local ok, inventory = pcall(function()
    return entity.get_module_inventory()
  end)
  if not ok or not inventory then
    return 0
  end

  return inventory.insert({name = SPEED_MODULE_NAME, count = 8}) or 0
end

local function place_entity(surface, force, name, position, raise_built)
  local entity = surface.create_entity({
    name = name,
    position = position,
    force = force,
    raise_built = raise_built ~= false,
    create_build_effect_smoke = false,
  })

  energize(entity)
  return entity
end

local function place_power(surface, force, origin)
  local offsets = {
    {-16, -16},
    {16, -16},
    {-16, 16},
    {16, 16},
    {0, 18},
  }

  local interface = surface.create_entity({
    name = "electric-energy-interface",
    position = {x = origin.x - 22, y = origin.y},
    force = force,
    create_build_effect_smoke = false,
  })
  energize(interface)

  for _, offset in ipairs(offsets) do
    local pole = surface.create_entity({
      name = "substation",
      position = {x = origin.x + offset[1], y = origin.y + offset[2]},
      force = force,
      create_build_effect_smoke = false,
    })
    energize(pole)
  end
end

local function clear_build_area(surface)
  surface.request_to_generate_chunks(ORIGIN, 12)
  surface.force_generate_chunk_requests()

  local tiles = {}
  for x = BUILD_AREA.left_top.x, BUILD_AREA.right_bottom.x do
    for y = BUILD_AREA.left_top.y, BUILD_AREA.right_bottom.y do
      tiles[#tiles + 1] = {name = "stone-path", position = {x = x, y = y}}
    end
  end
  surface.set_tiles(tiles, true)
  surface.destroy_decoratives({area = BUILD_AREA})

  for _, entity in pairs(surface.find_entities_filtered({area = BUILD_AREA})) do
    if entity.valid and entity.type ~= "character" then
      entity.destroy({raise_destroy = false})
    end
  end
end

local function place_machine(surface, force, scenario)
  local machine = place_entity(surface, force, scenario.machine_name, machine_position(scenario.origin), true)
  if machine and machine.valid and scenario.force_active_before_beacons then
    pcall(function()
      machine.active = true
    end)
  end
  return machine
end

local function place_beacon(surface, force, scenario, beacon_definition)
  local beacon = place_entity(
    surface,
    force,
    beacon_definition.name,
    relative_position(scenario.origin, beacon_definition.offset),
    true
  )
  insert_speed_modules(beacon)
  energize(beacon)
  return beacon
end

local function build_scenario(surface, force, scenario)
  place_power(surface, force, scenario.origin)

  local record = {
    id = scenario.id,
    machine = nil,
    beacons = {},
  }

  if scenario.machine_first then
    record.machine = place_machine(surface, force, scenario)
  end

  for index, beacon_definition in ipairs(scenario.beacons) do
    record.beacons[index] = place_beacon(surface, force, scenario, beacon_definition)
  end

  if not scenario.machine_first then
    record.machine = place_machine(surface, force, scenario)
  end

  return record
end

local function build_scene(reason)
  local state = ensure_state()
  local surface = get_surface()
  local force = get_force()

  write_file(REPORT_PATH, "", false)
  clear_build_area(surface)
  configure_beacon_rules()

  state.scenarios = {}
  for _, scenario in ipairs(SCENARIOS) do
    state.scenarios[scenario.id] = build_scenario(surface, force, scenario)
  end

  state.built = true
  state.base_tick = game.tick
  state.action_index = 1
  state.checkpoint_index = 1

  write_record({
    event = "built",
    reason = reason or "unknown",
    scenario_count = #SCENARIOS,
  })
end

local function read_active(entity)
  if not (entity and entity.valid) then
    return nil
  end

  local ok, active = pcall(function()
    return entity.active
  end)
  if ok then
    return active == true
  end

  return nil
end

local function get_engine_beacon_summary(entity)
  if not (entity and entity.valid) then
    return nil, {}, "missing-machine"
  end

  local ok, beacons = pcall(function()
    return entity.get_beacons()
  end)
  if not ok or type(beacons) ~= "table" then
    return nil, {}, "get-beacons-unavailable"
  end

  local names = {}
  for _, beacon in ipairs(beacons) do
    if beacon and beacon.valid then
      names[#names + 1] = beacon.name
    end
  end
  table.sort(names)

  return #names, names, nil
end

local function expected_active_for(scenario, checkpoint_label)
  if scenario.id == "edge-churn" then
    if checkpoint_label == "after-edge-remove" then
      return true
    end
    return false
  end

  return scenario.expected_active
end

local function collect_result(state, scenario, checkpoint_label)
  local record = state.scenarios[scenario.id] or {}
  local machine = record.machine
  local active = read_active(machine)
  local engine_count, engine_beacons, engine_error = get_engine_beacon_summary(machine)
  local expected_active = expected_active_for(scenario, checkpoint_label)
  local exists = machine and machine.valid or false
  local pass = exists and (expected_active == nil or active == expected_active)

  return {
    id = scenario.id,
    machine_name = scenario.machine_name,
    exists = exists,
    active = active,
    expected_active = expected_active,
    pass = pass == true,
    engine_beacon_count = engine_count,
    engine_beacons = engine_beacons,
    engine_error = engine_error,
    notes = scenario.notes,
  }
end

local function write_checkpoint(state, checkpoint)
  local results = {}
  local all_pass = true

  for _, scenario in ipairs(SCENARIOS) do
    local result = collect_result(state, scenario, checkpoint.label)
    results[#results + 1] = result
    all_pass = all_pass and result.pass
  end

  write_record({
    event = "checkpoint",
    label = checkpoint.label,
    relative_tick = checkpoint.tick,
    all_pass = all_pass,
    results = results,
  })
end

local function remove_edge_churn_beacon(state)
  local scenario = SCENARIO_BY_ID["edge-churn"]
  local record = state.scenarios["edge-churn"]
  if not (scenario and record) then
    return false, "missing-scenario"
  end

  local index = scenario.churn_beacon_index
  local beacon = record.beacons[index]
  if not (beacon and beacon.valid) then
    return false, "missing-beacon"
  end

  record.beacons[index] = nil
  return beacon.destroy({raise_destroy = true}), nil
end

local function readd_edge_churn_beacon(state)
  local scenario = SCENARIO_BY_ID["edge-churn"]
  local record = state.scenarios["edge-churn"]
  if not (scenario and record) then
    return false, "missing-scenario"
  end

  local index = scenario.churn_beacon_index
  local beacon_definition = scenario.beacons[index]
  local beacon = place_beacon(get_surface(), get_force(), scenario, beacon_definition)
  record.beacons[index] = beacon
  return beacon and beacon.valid or false, beacon and nil or "create-failed"
end

local function run_action(state, action)
  local ok = false
  local error_message = nil

  if action.name == "remove-edge-churn-beacon" then
    ok, error_message = remove_edge_churn_beacon(state)
  elseif action.name == "readd-edge-churn-beacon" then
    ok, error_message = readd_edge_churn_beacon(state)
  else
    error_message = "unknown-action"
  end

  write_record({
    event = "action",
    name = action.name,
    relative_tick = action.tick,
    ok = ok == true,
    error = error_message,
  })
end

local function energize_scene(state)
  for _, record in pairs(state.scenarios or {}) do
    energize(record.machine)
    for _, beacon in pairs(record.beacons or {}) do
      energize(beacon)
    end
  end
end

script.on_init(function()
  build_scene("on-init")
end)

script.on_configuration_changed(function()
  build_scene("configuration-changed")
end)

script.on_event(defines.events.on_tick, function(event)
  local state = ensure_state()
  if not state.built then
    build_scene("late-build")
  end

  energize_scene(state)

  local relative_tick = event.tick - (state.base_tick or 0)

  while ACTIONS[state.action_index] and relative_tick >= ACTIONS[state.action_index].tick do
    run_action(state, ACTIONS[state.action_index])
    state.action_index = state.action_index + 1
  end

  while CHECKPOINTS[state.checkpoint_index] and relative_tick >= CHECKPOINTS[state.checkpoint_index].tick do
    write_checkpoint(state, CHECKPOINTS[state.checkpoint_index])
    state.checkpoint_index = state.checkpoint_index + 1
  end
end)
