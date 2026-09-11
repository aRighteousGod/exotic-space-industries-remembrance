local REPORT_PATH = "beacon-overload-geometry-qc.jsonl"
local LOG_PREFIX = "BEACON_OVERLOAD_GEOMETRY_QC"
local COMPAT_REMOTE_NAME = "exotic-industries"
local QC_REMOTE_NAME = "exotic-industries-qc"
local SURFACE_NAME = "nauvis"
local TEMP_SURFACE_NAME = "zzz-beacon-overload-surface-qc"
local ORIGIN = {x = 6200, y = 6200}
local BUILD_AREA = {left_top = {x = ORIGIN.x - 48, y = ORIGIN.y - 48}, right_bottom = {x = ORIGIN.x + 500, y = ORIGIN.y + 132}}
local MACHINE_OFFSET = {0.5, 0.5}
local ENERGY_BUFFER = 1000000000

local EDGE_BEACONS = {
  {name = "beacon", offset = {-4, 0}}, {name = "beacon", offset = {0, -4}},
  {name = "beacon", offset = {0, 4}}, {name = "beacon", offset = {-4, -4}},
  {name = "beacon", offset = {5, 0}},
}

local function scenario_origin(column, row)
  return {x = ORIGIN.x + column * 50, y = ORIGIN.y + row * 80}
end

local SCENARIOS = {
  {id = "edge-overlap", origin = scenario_origin(0, 0), machine_name = "assembling-machine-3", beacons = EDGE_BEACONS,
    expected_active = false, expected_weight = 5, expected_links = 5, expected_engine = 5, notes = "Fifth beacon overlaps only at the receiver edge."},
  {id = "destroy-raised", origin = scenario_origin(1, 0), machine_name = "assembling-machine-3", beacons = EDGE_BEACONS,
    expected_active = false, expected_weight = 5, expected_links = 5, expected_engine = 5, notes = "Destroy with raise_destroy=true, then re-add."},
  {id = "weighted", origin = scenario_origin(2, 0), machine_name = "assembling-machine-3", beacons = {
      {name = "zzz-bo-weighted-beacon", offset = {-4, 0}}, {name = "zzz-bo-weighted-beacon", offset = {0, -4}},
      {name = "zzz-bo-weighted-beacon", offset = {0, 4}},
    }, expected_active = false, expected_weight = 6, expected_links = 3, expected_engine = 3, notes = "Three weight-two beacons."},
  {id = "excluded", origin = scenario_origin(3, 0), machine_name = "assembling-machine-3", beacons = {
      EDGE_BEACONS[1], EDGE_BEACONS[2], EDGE_BEACONS[3], EDGE_BEACONS[4], {name = "zzz-bo-excluded-beacon", offset = {5, 0}},
    }, expected_active = true, expected_weight = 4, expected_links = 4, expected_engine = 5, notes = "Engine sees excluded fifth beacon; ESIR does not count it."},
  {id = "long-range", origin = scenario_origin(4, 0), machine_name = "assembling-machine-3", machine_first = true, beacons = {
      {name = "zzz-bo-long-beacon", offset = {-10, 0}}, {name = "zzz-bo-long-beacon", offset = {0, -10}},
      {name = "zzz-bo-long-beacon", offset = {0, 10}}, {name = "zzz-bo-long-beacon", offset = {-10, -10}},
      {name = "zzz-bo-long-beacon", offset = {10, 0}},
    }, expected_active = false, expected_weight = 5, expected_links = 5, expected_engine = 5, notes = "Machine-first range-twelve construction."},
  {id = "heat-furnace", origin = scenario_origin(5, 0), machine_name = "ei-heat-steel-furnace", machine_first = true,
    force_active_before_beacons = true, beacons = EDGE_BEACONS, expected_active = true, expected_tracked = false,
    expected_engine = 0, notes = "uses_beacon_effects=false stays outside the graph."},
  {id = "build-fifth", origin = scenario_origin(6, 0), machine_name = "assembling-machine-3", machine_first = true,
    beacons = EDGE_BEACONS, initial_beacon_count = 4, expected_active = true, expected_weight = 4, expected_links = 4,
    expected_engine = 4, notes = "Machine first, then fifth ordinary beacon."},
  {id = "destroy-no-raise", origin = scenario_origin(7, 0), machine_name = "assembling-machine-3", beacons = EDGE_BEACONS,
    expected_active = false, expected_weight = 5, expected_links = 5, expected_engine = 5, notes = "Destroy without raised script event."},
  {id = "script-mine", origin = scenario_origin(8, 0), machine_name = "assembling-machine-3", beacons = EDGE_BEACONS,
    expected_active = false, expected_weight = 5, expected_links = 5, expected_engine = 5, notes = "Script-mine fifth beacon."},
  {id = "kill", origin = scenario_origin(9, 0), machine_name = "assembling-machine-3", beacons = EDGE_BEACONS,
    expected_active = false, expected_weight = 5, expected_links = 5, expected_engine = 5, notes = "Kill fifth beacon."},
  {id = "rapid-readd", origin = scenario_origin(0, 1), machine_name = "assembling-machine-3", beacons = EDGE_BEACONS,
    expected_active = false, expected_weight = 5, expected_links = 5, expected_engine = 5, notes = "Remove/re-add same tick."},
  {id = "fast-replace", origin = scenario_origin(1, 1), machine_name = "assembling-machine-3", beacons = EDGE_BEACONS,
    expected_active = false, expected_weight = 5, expected_links = 5, expected_engine = 5, notes = "Replace ordinary fifth beacon with excluded helper."},
  {id = "multi-remove", origin = scenario_origin(2, 1), machine_name = "assembling-machine-3", beacons = EDGE_BEACONS,
    expected_active = false, expected_weight = 5, expected_links = 5, expected_engine = 5, notes = "Two removals enqueue one recount."},
  {id = "machine-first-destroy", origin = scenario_origin(3, 1), machine_name = "assembling-machine-3", beacons = EDGE_BEACONS,
    expected_active = false, expected_weight = 5, expected_links = 5, expected_engine = 5, notes = "Destroy machine before linked beacon."},
  {id = "clone-beacon", origin = scenario_origin(4, 1), machine_name = "assembling-machine-3", machine_first = true,
    beacons = EDGE_BEACONS, initial_beacon_count = 4, expected_active = true, expected_weight = 4, expected_links = 4,
    expected_engine = 4, notes = "Clone fifth beacon."},
  {id = "clone-machine", origin = scenario_origin(5, 1), machine_name = "assembling-machine-3", machine_first = true,
    beacons = {}, destination_beacons = EDGE_BEACONS, destination_offset = {0, 20}, expected_active = true,
    expected_weight = 0, expected_links = 0, expected_engine = 0, notes = "Clone machine into a five-beacon destination."},
  {id = "beacon-teleport", origin = scenario_origin(6, 1), machine_name = "assembling-machine-3", beacons = EDGE_BEACONS,
    expected_active = false, expected_weight = 5, expected_links = 5, expected_engine = 5, notes = "Raised beacon teleport away/back."},
  {id = "machine-teleport", origin = scenario_origin(7, 1), machine_name = "assembling-machine-3", beacons = EDGE_BEACONS,
    expected_active = false, expected_weight = 5, expected_links = 5, expected_engine = 5, notes = "Raised overloaded-machine teleport away/back."},
  {id = "deconstruction-cancel", origin = scenario_origin(8, 1), machine_name = "assembling-machine-3", beacons = EDGE_BEACONS,
    expected_active = false, expected_weight = 5, expected_links = 5, expected_engine = 5, notes = "Mark/cancel deconstruction without removal."},
  {id = "raised-cross-surface", origin = scenario_origin(9, 1), machine_name = "assembling-machine-3", beacons = EDGE_BEACONS,
    expected_active = false, expected_weight = 5, expected_links = 5, expected_engine = 5,
    notes = "Cross-surface payload simulation; Factorio 2.0 cannot cross-surface teleport buildings."},
}

local SCENARIO_BY_ID = {}
for _, scenario in ipairs(SCENARIOS) do SCENARIO_BY_ID[scenario.id] = scenario end

local ACTIONS = {
  {20, "build-fifth"}, {30, "destroy-raised"}, {40, "readd-raised"}, {50, "destroy-no-raise"},
  {60, "script-mine"}, {70, "kill"}, {80, "rapid-readd"}, {90, "fast-replace"},
  {100, "multi-remove"}, {110, "machine-first-destroy"}, {120, "clone-beacon"}, {130, "clone-machine"},
  {140, "beacon-teleport-away"}, {150, "beacon-teleport-back"}, {160, "machine-teleport-away"},
  {170, "machine-teleport-back"}, {180, "deconstruction-cancel"}, {186, "raised-cross-surface"},
  {190, "build-temp-surface"}, {210, "delete-temp-surface"}, {230, "disable-overload"}, {250, "disabled-lifecycle"},
  {260, "enable-overload"}, {1500, "legacy-reseed"},
}

local CHECKPOINTS = {
  {5, "initial", "normal"}, {25, "after-build-fifth", "normal"}, {35, "after-destroy-raised", "normal"},
  {45, "after-readd-raised", "normal"}, {55, "after-destroy-no-raise", "normal"}, {65, "after-script-mine", "normal"},
  {75, "after-kill", "normal"}, {85, "after-rapid-readd", "normal"}, {95, "after-fast-replace", "normal"},
  {105, "after-multi-remove", "normal"}, {115, "after-machine-first-destroy", "normal"},
  {125, "after-clone-beacon", "normal"}, {135, "after-clone-machine", "normal"},
  {145, "after-beacon-teleport-away", "normal"}, {155, "after-beacon-teleport-back", "normal"},
  {165, "after-machine-teleport-away", "normal"}, {175, "after-machine-teleport-back", "normal"},
  {185, "after-deconstruction-cancel", "normal"}, {189, "after-raised-cross-surface", "normal"},
  {200, "temp-surface-built", "surface-built"}, {225, "temp-surface-deleted", "surface-deleted"},
  {245, "overload-disabled", "disabled"}, {255, "disabled-lifecycle-ignored", "disabled"}, {1400, "overload-reenabled", "normal"},
  {2800, "legacy-reseeded", "normal"}, {3500, "final", "normal", true},
}

local function ensure_state()
  storage.beacon_overload_geometry_qc = storage.beacon_overload_geometry_qc or {}
  local state = storage.beacon_overload_geometry_qc
  state.built = state.built or false; state.base_tick = state.base_tick or 0
  state.action_index = state.action_index or 1; state.checkpoint_index = state.checkpoint_index or 1
  state.scenarios = state.scenarios or {}; state.all_pass = state.all_pass ~= false
  state.failure_count = state.failure_count or 0
  return state
end

local function encode_record(record)
  if helpers and helpers.table_to_json then local ok, value = pcall(helpers.table_to_json, record); if ok and value then return value end end
  return serpent and serpent.line and serpent.line(record, {comment = false}) or ""
end

local function write_file(path, contents, append)
  if helpers and helpers.write_file then helpers.write_file(path, contents, append == true, 0) end
end

local function write_record(record)
  record.tick = record.tick or (game and game.tick or 0); local encoded = encode_record(record)
  if encoded == "" then return end; log(LOG_PREFIX .. " " .. encoded); write_file(REPORT_PATH, encoded .. "\n", true)
end

local function call_remote(interface_name, member_name, ...)
  local interface = remote.interfaces[interface_name]
  if not interface or not interface[member_name] then return false, "missing-remote" end
  return pcall(remote.call, interface_name, member_name, ...)
end

local function get_esir_snapshot(machine_unit)
  local ok, result = call_remote(QC_REMOTE_NAME, "get_beacon_overload_qc_snapshot", machine_unit)
  if not ok then return nil, tostring(result) end; return result, nil
end

local function configure_beacon_rules()
  for _, call in ipairs({
    {"set-weighted", "set_beacon_overload_beacon_weight", "zzz-bo-weighted-beacon", 2},
    {"exclude-helper", "add_beacon_overload_beacon_exclusion", "zzz-bo-excluded-beacon"},
  }) do
    local ok, result = call_remote(COMPAT_REMOTE_NAME, call[2], call[3], call[4])
    write_record({event = "compat-rule", name = call[1], ok = ok == true, result = result})
  end
end

local function get_force() return game.forces.player or game.forces[1] end
local function get_surface() return game.surfaces[SURFACE_NAME] or game.surfaces[1] end
local function ensure_temp_surface()
  local surface = game.surfaces[TEMP_SURFACE_NAME]
  if not surface then surface = game.create_surface(TEMP_SURFACE_NAME, {autoplace_controls = {}}) end
  surface.request_to_generate_chunks({0, 0}, 2); surface.force_generate_chunk_requests(); return surface
end
local function relative_position(origin, offset)
  return {x = origin.x + MACHINE_OFFSET[1] + offset[1], y = origin.y + MACHINE_OFFSET[2] + offset[2]}
end
local function machine_position(origin) return relative_position(origin, {0, 0}) end

local function energize(entity)
  if not (entity and entity.valid) then return end
  local ok, energy = pcall(function() return entity.energy end)
  if ok and energy ~= nil then pcall(function() entity.energy = ENERGY_BUFFER end) end
end
local function insert_speed_modules(entity)
  if not (entity and entity.valid) then return 0 end
  local ok, inventory = pcall(function() return entity.get_module_inventory() end)
  return ok and inventory and inventory.insert({name = "speed-module", count = 8}) or 0
end
local function place_entity(surface, force, name, position, raise_built)
  local entity = surface.create_entity({name = name, position = position, force = force,
    raise_built = raise_built ~= false, create_build_effect_smoke = false}); energize(entity); return entity
end
local function place_power(surface, force, origin)
  energize(surface.create_entity({name = "electric-energy-interface", position = {x = origin.x - 22, y = origin.y}, force = force}))
  for _, offset in ipairs({{-16, -16}, {16, -16}, {-16, 16}, {16, 16}, {0, 18}}) do
    surface.create_entity({name = "substation", position = {x = origin.x + offset[1], y = origin.y + offset[2]}, force = force})
  end
end
local function clear_build_area(surface)
  surface.request_to_generate_chunks({x = ORIGIN.x + 250, y = ORIGIN.y + 40}, 12); surface.force_generate_chunk_requests()
  local tiles = {}; for x = BUILD_AREA.left_top.x, BUILD_AREA.right_bottom.x do for y = BUILD_AREA.left_top.y, BUILD_AREA.right_bottom.y do
    tiles[#tiles + 1] = {name = "stone-path", position = {x = x, y = y}}
  end end
  surface.set_tiles(tiles, true); surface.destroy_decoratives({area = BUILD_AREA})
  for _, entity in pairs(surface.find_entities_filtered({area = BUILD_AREA})) do
    if entity.valid and entity.type ~= "character" then entity.destroy({raise_destroy = false}) end
  end
end
local function place_machine(surface, force, scenario, origin)
  local machine = place_entity(surface, force, scenario.machine_name, machine_position(origin or scenario.origin), true)
  if machine and machine.valid and scenario.force_active_before_beacons then machine.active = true end; return machine
end
local function place_beacon(surface, force, scenario, definition, origin)
  local beacon = place_entity(surface, force, definition.name, relative_position(origin or scenario.origin, definition.offset), true)
  insert_speed_modules(beacon); energize(beacon); return beacon
end

local function build_scenario(surface, force, scenario)
  place_power(surface, force, scenario.origin)
  local record = {machine = nil, machine_unit = nil, beacons = {}, extra_beacons = {}, expected_exists = true,
    expected_active = scenario.expected_active, expected_tracked = scenario.expected_tracked,
    expected_weight = scenario.expected_weight, expected_links = scenario.expected_links, expected_engine = scenario.expected_engine}
  if scenario.machine_first then record.machine = place_machine(surface, force, scenario) end
  for index = 1, (scenario.initial_beacon_count or #scenario.beacons) do
    record.beacons[index] = place_beacon(surface, force, scenario, scenario.beacons[index])
  end
  if not scenario.machine_first then record.machine = place_machine(surface, force, scenario) end
  if scenario.destination_beacons then
    record.destination_origin = {x = scenario.origin.x + scenario.destination_offset[1], y = scenario.origin.y + scenario.destination_offset[2]}
    for index, definition in ipairs(scenario.destination_beacons) do
      record.extra_beacons[index] = place_beacon(surface, force, scenario, definition, record.destination_origin)
    end
  end
  record.machine_unit = record.machine and record.machine.unit_number or nil; return record
end

local function build_scene(reason)
  local state, surface, force = ensure_state(), get_surface(), get_force()
  write_file(REPORT_PATH, "", false); clear_build_area(surface); ensure_temp_surface(); configure_beacon_rules()
  state.scenarios = {}; state.all_pass, state.failure_count = true, 0
  for _, scenario in ipairs(SCENARIOS) do state.scenarios[scenario.id] = build_scenario(surface, force, scenario) end
  state.built, state.base_tick, state.action_index, state.checkpoint_index = true, game.tick, 1, 1
  write_record({event = "built", reason = reason or "unknown", scenario_count = #SCENARIOS})
end

local function read_active(entity)
  if not (entity and entity.valid) then return nil end
  local ok, active = pcall(function() return entity.active end)
  if ok then return active == true end
  return nil
end
local function get_engine_beacon_summary(entity)
  if not (entity and entity.valid) then return nil, {}, "missing-machine" end
  local ok, beacons = pcall(function() return entity.get_beacons() end)
  if not ok or type(beacons) ~= "table" then return nil, {}, "get-beacons-unavailable" end
  local names = {}; for _, beacon in ipairs(beacons) do if beacon and beacon.valid then names[#names + 1] = beacon.name end end
  table.sort(names); return #names, names, nil
end
local function note_failure(state, passed)
  if not passed then state.all_pass = false; state.failure_count = state.failure_count + 1 end
end
local function collect_result(state, scenario)
  local record = state.scenarios[scenario.id]; local machine = record.machine
  local exists, active = machine and machine.valid or false, read_active(machine)
  local engine_count, engine_beacons, engine_error = get_engine_beacon_summary(machine)
  local snapshot, snapshot_error = get_esir_snapshot(record.machine_unit); local esir = snapshot and snapshot.machine or {}
  local expected_tracked = record.expected_tracked; if expected_tracked == nil then expected_tracked = true end
  local expected_overloaded = record.expected_weight and record.expected_weight > 4 or false; local pass
  if record.expected_exists == false then
    pass = not exists and esir.tracked ~= true and esir.overloaded ~= true and esir.icon_present ~= true
      and esir.linked_beacon_count == 0 and esir.queued ~= true and esir.registration_number == nil
  else
    pass = exists and active == record.expected_active and engine_count == record.expected_engine
      and esir.tracked == expected_tracked and esir.overloaded == expected_overloaded
      and esir.icon_present == expected_overloaded and esir.queued ~= true
    if expected_tracked then
      pass = pass and esir.weighted_count == record.expected_weight and esir.linked_beacon_count == record.expected_links
        and esir.registration_number ~= nil
    else
      pass = pass and esir.weighted_count == nil and esir.linked_beacon_count == 0 and esir.registration_number == nil
    end
  end
  return {id = scenario.id, exists = exists, active = active, expected_active = record.expected_active, pass = pass == true,
    engine_beacon_count = engine_count, expected_engine_beacon_count = record.expected_engine, engine_beacons = engine_beacons,
    engine_error = engine_error, expected_weighted_count = record.expected_weight,
    expected_linked_beacon_count = record.expected_links, esir = esir, esir_error = snapshot_error, notes = scenario.notes}
end

local function write_normal_checkpoint(state, checkpoint)
  local results, all_pass = {}, true
  for _, scenario in ipairs(SCENARIOS) do local result = collect_result(state, scenario); results[#results + 1] = result; all_pass = all_pass and result.pass end
  local topology, topology_error = get_esir_snapshot(nil)
  local topology_pass = topology and topology.machine_queue_length == 0 and topology.queued_unit_count == 0
    and topology.object_registration_count == topology.registered_beacon_count + topology.registered_machine_count
  all_pass = all_pass and topology_pass == true; note_failure(state, all_pass)
  write_record({event = "checkpoint", label = checkpoint[2], relative_tick = checkpoint[1], all_pass = all_pass == true,
    topology_pass = topology_pass == true, topology = topology, topology_error = topology_error, results = results})
end
local function set_expected(record, active, weight, links, engine)
  record.expected_active, record.expected_weight, record.expected_links, record.expected_engine = active, weight, links, engine
end
local function remove_beacon(record, index, mode)
  local beacon = record.beacons[index]; if not (beacon and beacon.valid) then return false, "missing-beacon" end
  record.beacons[index] = nil
  if mode == "mine" then return beacon.mine({force = true, raise_destroyed = true}), nil end
  if mode == "die" then return beacon.die(get_force()), nil end
  return beacon.destroy({raise_destroy = mode == "raised"}), nil
end
local function add_beacon(record, scenario, index, definition)
  local beacon = place_beacon(get_surface(), get_force(), scenario, definition or scenario.beacons[index]); record.beacons[index] = beacon
  local ok = beacon and beacon.valid or false; return ok, ok and nil or "create-failed"
end

local function run_named_action(state, action)
  local name = action[2]; local scenario, record, ok, err
  if name == "build-fifth" then
    scenario, record = SCENARIO_BY_ID[name], state.scenarios[name]; ok, err = add_beacon(record, scenario, 5); set_expected(record, false, 5, 5, 5)
  elseif name == "destroy-raised" then
    record = state.scenarios[name]; ok, err = remove_beacon(record, 5, "raised"); set_expected(record, true, 4, 4, 4)
  elseif name == "readd-raised" then
    scenario, record = SCENARIO_BY_ID["destroy-raised"], state.scenarios["destroy-raised"]; ok, err = add_beacon(record, scenario, 5); set_expected(record, false, 5, 5, 5)
  elseif name == "destroy-no-raise" then
    record = state.scenarios[name]; ok, err = remove_beacon(record, 5, "silent"); set_expected(record, true, 4, 4, 4)
  elseif name == "script-mine" then
    record = state.scenarios[name]; ok, err = remove_beacon(record, 5, "mine"); set_expected(record, true, 4, 4, 4)
  elseif name == "kill" then
    record = state.scenarios[name]; ok, err = remove_beacon(record, 5, "die"); set_expected(record, true, 4, 4, 4)
  elseif name == "rapid-readd" then
    scenario, record = SCENARIO_BY_ID[name], state.scenarios[name]; ok, err = remove_beacon(record, 5, "silent")
    local add_ok, add_err = add_beacon(record, scenario, 5); ok, err = ok and add_ok, err or add_err
  elseif name == "fast-replace" then
    scenario, record = SCENARIO_BY_ID[name], state.scenarios[name]; ok, err = remove_beacon(record, 5, "silent")
    local add_ok, add_err = add_beacon(record, scenario, 5, {name = "zzz-bo-excluded-beacon", offset = {5, 0}})
    ok, err = ok and add_ok, err or add_err; set_expected(record, true, 4, 4, 5)
  elseif name == "multi-remove" then
    record = state.scenarios[name]; local before = get_esir_snapshot(nil); record.enqueue_before = before and before.machine_queue_enqueues
    local ok4, err4 = remove_beacon(record, 4, "silent"); local ok5, err5 = remove_beacon(record, 5, "silent")
    ok, err = ok4 and ok5, err4 or err5; set_expected(record, true, 3, 3, 3)
  elseif name == "machine-first-destroy" then
    record = state.scenarios[name]; local machine = record.machine
    ok = machine and machine.valid and machine.destroy({raise_destroy = false}) or false
    local beacon_ok, beacon_err = remove_beacon(record, 5, "silent"); ok, err = ok and beacon_ok, beacon_err; record.expected_exists = false
  elseif name == "clone-beacon" then
    scenario, record = SCENARIO_BY_ID[name], state.scenarios[name]; local source = record.beacons[1]
    local clone = source and source.valid and source.clone({position = relative_position(scenario.origin, scenario.beacons[5].offset),
      surface = get_surface(), force = get_force(), create_build_effect_smoke = false}) or nil
    record.beacons[5] = clone; ok = clone and clone.valid or false; err = ok and nil or "clone-failed"; set_expected(record, false, 5, 5, 5)
  elseif name == "clone-machine" then
    record = state.scenarios[name]; local source = record.machine
    local clone = source and source.valid and source.clone({position = machine_position(record.destination_origin), surface = get_surface(),
      force = get_force(), create_build_effect_smoke = false}) or nil
    record.machine, record.machine_unit = clone, clone and clone.unit_number or record.machine_unit
    ok = clone and clone.valid or false; err = ok and nil or "clone-failed"; set_expected(record, false, 5, 5, 5)
  elseif name == "beacon-teleport-away" or name == "beacon-teleport-back" then
    scenario, record = SCENARIO_BY_ID["beacon-teleport"], state.scenarios["beacon-teleport"]; local beacon = record.beacons[5]
    local position = name == "beacon-teleport-away" and relative_position(scenario.origin, {25, 0}) or relative_position(scenario.origin, scenario.beacons[5].offset)
    ok = beacon and beacon.valid and beacon.teleport(position, nil, true) or false
    if name == "beacon-teleport-away" then set_expected(record, true, 4, 4, 4) else set_expected(record, false, 5, 5, 5) end
  elseif name == "machine-teleport-away" or name == "machine-teleport-back" then
    scenario, record = SCENARIO_BY_ID["machine-teleport"], state.scenarios["machine-teleport"]
    local position = name == "machine-teleport-away" and relative_position(scenario.origin, {0, 20}) or machine_position(scenario.origin)
    ok = record.machine and record.machine.valid and record.machine.teleport(position, nil, true) or false
    if name == "machine-teleport-away" then set_expected(record, true, 0, 0, 0) else set_expected(record, false, 5, 5, 5) end
  elseif name == "deconstruction-cancel" then
    record = state.scenarios[name]; local beacon = record.beacons[5]
    local marked = beacon and beacon.valid and beacon.order_deconstruction(get_force()) or false
    if marked then beacon.cancel_deconstruction(get_force()) end; ok, err = marked, marked and nil or "mark-failed"
  elseif name == "raised-cross-surface" then
    scenario, record = SCENARIO_BY_ID[name], state.scenarios[name]; local beacon = record.beacons[5]
    local old_position, old_surface_index = beacon and beacon.position, ensure_temp_surface().index
    ok = beacon and beacon.valid and beacon.teleport(relative_position(scenario.origin, {25, 0}), nil, false) or false
    if ok then script.raise_script_teleported({entity = beacon, old_surface_index = old_surface_index, old_position = old_position}) end
    set_expected(record, true, 4, 4, 4)
  elseif name == "build-temp-surface" then
    local surface, force = ensure_temp_surface(), get_force(); local baseline = get_esir_snapshot(nil)
    local temp_scenario = {machine_name = "assembling-machine-3", origin = {x = 0, y = 0}, beacons = EDGE_BEACONS}
    place_power(surface, force, temp_scenario.origin); local machine = place_machine(surface, force, temp_scenario)
    local beacons = {}; for i, definition in ipairs(EDGE_BEACONS) do beacons[i] = place_beacon(surface, force, temp_scenario, definition) end
    state.surface_test = {baseline = baseline, machine = machine, machine_unit = machine and machine.unit_number, beacons = beacons}; ok = machine and machine.valid or false
  elseif name == "delete-temp-surface" then
    local surface = game.surfaces[TEMP_SURFACE_NAME]; ok = surface and game.delete_surface(surface) or false
  elseif name == "disable-overload" then
    ok, err = call_remote(QC_REMOTE_NAME, "set_beacon_overload_enabled_for_qc", false)
  elseif name == "disabled-lifecycle" then
    local surface, force, origin = get_surface(), get_force(), scenario_origin(10, 1)
    local disabled_scenario = {machine_name = "assembling-machine-3", origin = origin, beacons = EDGE_BEACONS}
    place_power(surface, force, origin); local machine = place_machine(surface, force, disabled_scenario)
    local beacons = {}; for i, definition in ipairs(EDGE_BEACONS) do beacons[i] = place_beacon(surface, force, disabled_scenario, definition) end
    local teleported = machine and machine.valid and machine.teleport(relative_position(origin, {0, 20}), nil, true) or false
    state.disabled_test = {machine = machine, beacons = beacons}; ok = machine and machine.valid and teleported or false
  elseif name == "enable-overload" then
    ok, err = call_remote(QC_REMOTE_NAME, "set_beacon_overload_enabled_for_qc", true)
  elseif name == "legacy-reseed" then
    ok, err = call_remote(QC_REMOTE_NAME, "simulate_legacy_beacon_overload_state"); state.legacy_cleared_snapshot = ok and err or nil; err = ok and nil or err
  else ok, err = false, "unknown-action" end
  note_failure(state, ok == true); local topology = get_esir_snapshot(nil)
  write_record({event = "action", name = name, relative_tick = action[1], ok = ok == true, error = err, topology = topology})
end

local function write_special_checkpoint(state, checkpoint)
  local topology, topology_error = get_esir_snapshot(nil); local pass, details = false, {}
  if checkpoint[3] == "surface-built" then
    local test = state.surface_test or {}; local baseline = test.baseline or {}; local machine_snapshot = get_esir_snapshot(test.machine_unit)
    details.machine = machine_snapshot and machine_snapshot.machine
    pass = test.machine and test.machine.valid and read_active(test.machine) == false
      and topology.registered_beacon_count == baseline.registered_beacon_count + 5
      and topology.registered_machine_count == baseline.registered_machine_count + 1
      and topology.relationship_count == baseline.relationship_count + 5
  elseif checkpoint[3] == "surface-deleted" then
    local test = state.surface_test or {}; local baseline = test.baseline or {}; local machine_snapshot = get_esir_snapshot(test.machine_unit)
    details.machine = machine_snapshot and machine_snapshot.machine
    pass = not game.surfaces[TEMP_SURFACE_NAME] and topology.registered_beacon_count == baseline.registered_beacon_count
      and topology.registered_machine_count == baseline.registered_machine_count and topology.relationship_count == baseline.relationship_count
      and details.machine and details.machine.tracked == false and details.machine.icon_present == false
  elseif checkpoint[3] == "disabled" then
    pass = topology.enabled == false and topology.registered_beacon_count == 0 and topology.registered_machine_count == 0
      and topology.relationship_count == 0 and topology.object_registration_count == 0 and topology.overloaded_count == 0
      and topology.machine_queue_length == 0 and topology.queued_unit_count == 0
  end
  note_failure(state, pass); write_record({event = "checkpoint", label = checkpoint[2], relative_tick = checkpoint[1],
    all_pass = pass == true, topology = topology, topology_error = topology_error, details = details})
end

local function write_checkpoint(state, checkpoint)
  if checkpoint[3] == "normal" then write_normal_checkpoint(state, checkpoint) else write_special_checkpoint(state, checkpoint) end
  if checkpoint[2] == "after-multi-remove" then
    local record = state.scenarios["multi-remove"]; local topology = get_esir_snapshot(nil)
    local pass = record.enqueue_before and topology.machine_queue_enqueues == record.enqueue_before + 1
    note_failure(state, pass); write_record({event = "assertion", name = "multi-remove-single-enqueue", pass = pass == true,
      before = record.enqueue_before, after = topology.machine_queue_enqueues})
  elseif checkpoint[2] == "legacy-reseeded" then
    local cleared = state.legacy_cleared_snapshot or {}
    local pass = cleared.registered_beacon_count == 0 and cleared.registered_machine_count == 0
      and cleared.relationship_count == 0 and cleared.object_registration_count == 0
    note_failure(state, pass); write_record({event = "assertion", name = "legacy-state-cleared-before-rebuild", pass = pass == true, snapshot = cleared})
  end
  if checkpoint[4] then
    write_record({event = "aggregate", all_pass = state.all_pass == true, failure_count = state.failure_count,
      scenario_count = #SCENARIOS, checkpoint_count = #CHECKPOINTS})
    if not state.all_pass then error("Beacon overload geometry QC failed " .. tostring(state.failure_count) .. " authored checkpoints") end
  end
end

local function energize_scene(state)
  for _, record in pairs(state.scenarios) do
    energize(record.machine); for _, beacon in pairs(record.beacons) do energize(beacon) end
    for _, beacon in pairs(record.extra_beacons) do energize(beacon) end
  end
  local test = state.surface_test; if test then energize(test.machine); for _, beacon in pairs(test.beacons or {}) do energize(beacon) end end
end

script.on_init(function() build_scene("on-init") end)
script.on_configuration_changed(function() build_scene("configuration-changed") end)
script.on_event(defines.events.on_tick, function(event)
  local state = ensure_state(); if not state.built then build_scene("late-build") end; energize_scene(state)
  local relative_tick = event.tick - state.base_tick
  while ACTIONS[state.action_index] and relative_tick >= ACTIONS[state.action_index][1] do
    run_named_action(state, ACTIONS[state.action_index]); state.action_index = state.action_index + 1
  end
  while CHECKPOINTS[state.checkpoint_index] and relative_tick >= CHECKPOINTS[state.checkpoint_index][1] do
    write_checkpoint(state, CHECKPOINTS[state.checkpoint_index]); state.checkpoint_index = state.checkpoint_index + 1
  end
end)
