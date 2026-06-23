local REPORT_PATH = "fluid-rupture-qc.jsonl"
local FORCE_NAME = "fluid-rupture-qc"
local SURFACE_NAME = "nauvis"
local QC_REMOTE_NAME = "exotic-industries-qc"
local ORIGIN = {x = 5600, y = 5600}
local BUILD_AREA = {
  left_top = {x = ORIGIN.x - 80, y = ORIGIN.y - 40},
  right_bottom = {x = ORIGIN.x + 80, y = ORIGIN.y + 40},
}

local CASE_SPECS = {
  {
    id = "data-line",
    entity_name = "pipe",
    position = {-32, 0},
    fluid = {name = "ei-computing-power", amount = 100},
  },
  {
    id = "cryo-line",
    entity_name = "pipe",
    position = {-20, 0},
    fluid = {name = "ei-liquid-nitrogen", amount = 100},
  },
  {
    id = "thermal-line",
    entity_name = "pipe",
    position = {-8, 0},
    fluid = {name = "lava", amount = 100},
  },
  {
    id = "ignored-data-line",
    entity_name = "tnd-pipe-name",
    position = {4, 0},
    fluid = {name = "ei-computing-power", amount = 100},
  },
  {
    id = "chemical-vessel",
    entity_name = "storage-tank",
    position = {16, 0},
    fluid = {name = "electrolyte", amount = 2500},
  },
  {
    id = "flammable-vessel",
    entity_name = "storage-tank",
    position = {40, 0},
    fluid = {name = "crude-oil", amount = 2500},
  },
}

local ACTIONS = {
  {tick = 1, name = "rebuild-fluid-runtime"},
  {tick = 2, name = "service-fluid-runtime"},
  {tick = 3, name = "service-fluid-runtime"},
  {tick = 4, name = "service-fluid-runtime"},
  {tick = 5, name = "kill-flammable-vessel"},
}

local CHECKPOINTS = {
  {tick = 1, label = "after-rebuild", phase = "built"},
  {tick = 4, label = "after-fluid-service", phase = "fluid-serviced"},
  {tick = 5, label = "after-flammable-kill", phase = "flammable-killed"},
  {tick = 20, label = "after-scheduler-drain", phase = "flammable-killed"},
  {tick = 60, label = "steady-state", phase = "flammable-killed"},
}

local function ensure_state()
  storage.fluid_rupture_qc = storage.fluid_rupture_qc or {}
  local state = storage.fluid_rupture_qc
  state.built = state.built or false
  state.base_tick = state.base_tick or 0
  state.action_index = state.action_index or 1
  state.checkpoint_index = state.checkpoint_index or 1
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

local function write_record(record)
  local encoded = encode_record(record)
  if encoded == "" then
    return
  end

  log("FLUID_RUPTURE_QC " .. encoded)

  if helpers and helpers.write_file then
    helpers.write_file(REPORT_PATH, encoded .. "\n", true, 0)
  elseif game and game.write_file then
    game.write_file(REPORT_PATH, encoded .. "\n", true, 0)
  end
end

local function count_keys(tbl)
  local count = 0
  for _ in pairs(tbl or {}) do
    count = count + 1
  end
  return count
end

local function collect_remote_status()
  local interfaces = remote.interfaces or {}
  local interface = interfaces[QC_REMOTE_NAME] or nil
  return {
    present = interface ~= nil,
    member_count = count_keys(interface),
  }
end

local function call_qc_remote(member_name, ...)
  if not remote.interfaces[QC_REMOTE_NAME] or not remote.interfaces[QC_REMOTE_NAME][member_name] then
    return false, "missing-remote"
  end

  return pcall(remote.call, QC_REMOTE_NAME, member_name, ...)
end

local function get_force()
  local force = game.forces[FORCE_NAME]
  if force and force.valid then
    return force
  end

  return game.create_force(FORCE_NAME)
end

local function ensure_surface()
  local surface = game.surfaces[SURFACE_NAME]
  if surface and surface.valid then
    return surface
  end

  return game.surfaces[1]
end

local function absolute_position(relative_position)
  return {
    x = ORIGIN.x + relative_position[1],
    y = ORIGIN.y + relative_position[2],
  }
end

local function clear_build_area(surface)
  surface.request_to_generate_chunks(ORIGIN, 6)
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

local function place_case_entity(surface, force, case_spec)
  local entity = surface.create_entity({
    name = case_spec.entity_name,
    position = absolute_position(case_spec.position),
    force = force,
    raise_built = true,
    create_build_effect_smoke = false,
  })

  local inserted = 0
  if entity and entity.valid and case_spec.fluid then
    inserted = entity.insert_fluid(case_spec.fluid) or 0
  end

  return entity, inserted
end

local function collect_entity_fluids(entity)
  local fluids = {}
  local by_key = {}
  local fluidbox = entity and entity.valid and entity.fluidbox or nil
  if not fluidbox then
    return fluids
  end

  for index = 1, #fluidbox do
    local contents = fluidbox[index]
    if contents and contents.name and contents.amount and contents.amount > 0 then
      local key = contents.name .. "|" .. tostring(contents.temperature or "")
      local entry = by_key[key]
      if not entry then
        entry = {
          name = contents.name,
          amount = 0,
          temperature = contents.temperature,
        }
        by_key[key] = entry
        fluids[#fluids + 1] = entry
      end

      entry.amount = entry.amount + contents.amount
    end
  end

  table.sort(fluids, function(left, right)
    return (left.name or "") < (right.name or "")
  end)

  return fluids
end

local function find_case_entity(surface, force, case_spec)
  local position = absolute_position(case_spec.position)
  local matches = surface.find_entities_filtered({
    area = {
      {position.x - 0.51, position.y - 0.51},
      {position.x + 0.51, position.y + 0.51},
    },
    force = force.name,
    name = case_spec.entity_name,
  })

  for _, entity in ipairs(matches) do
    if entity and entity.valid then
      return entity
    end
  end

  return nil
end

local function collect_case_result(surface, force, case_spec)
  local entity = find_case_entity(surface, force, case_spec)
  return {
    id = case_spec.id,
    entity_name = case_spec.entity_name,
    exists = entity ~= nil,
    type = entity and entity.type or nil,
    unit_number = entity and entity.unit_number or nil,
    fluids = entity and collect_entity_fluids(entity) or {},
  }
end

local function collect_case_results(surface, force)
  local results = {}
  for _, case_spec in ipairs(CASE_SPECS) do
    results[#results + 1] = collect_case_result(surface, force, case_spec)
  end
  return results
end

local function index_case_results(results)
  local by_id = {}
  for _, result in ipairs(results or {}) do
    by_id[result.id] = result
  end
  return by_id
end

local function unit_table_has_key(tbl, unit_number)
  if not unit_number or type(tbl) ~= "table" then
    return false
  end

  return tbl[unit_number] ~= nil or tbl[tostring(unit_number)] ~= nil
end

local function unit_list_has_value(list, unit_number)
  if not unit_number or type(list) ~= "table" then
    return false
  end

  for _, value in pairs(list) do
    if value == unit_number or tostring(value) == tostring(unit_number) then
      return true
    end
  end

  return false
end

local function case_has_fluid(result, fluid_name)
  for _, fluid in ipairs(result and result.fluids or {}) do
    if fluid.name == fluid_name and (fluid.amount or 0) > 0 then
      return true
    end
  end

  return false
end

local function collect_validation(phase, results)
  local by_id = index_case_results(results)
  local checks = {}
  local passed = true

  local function add_check(label, ok, detail)
    if not ok then
      passed = false
    end
    checks[#checks + 1] = {
      label = label,
      passed = ok == true,
      detail = detail,
    }
  end

  if phase == "built" then
    for _, case_spec in ipairs(CASE_SPECS) do
      local result = by_id[case_spec.id]
      add_check(case_spec.id .. "-built", result and result.exists == true, result and "exists" or "missing")
    end
  end

  if phase == "fluid-serviced" or phase == "flammable-killed" then
    add_check("data-line-destroyed", by_id["data-line"] and by_id["data-line"].exists == false, tostring(by_id["data-line"] and by_id["data-line"].exists))
    add_check("cryo-line-preserved", by_id["cryo-line"] and by_id["cryo-line"].exists == true, tostring(by_id["cryo-line"] and by_id["cryo-line"].exists))
    add_check(
      "cryo-line-converted-to-gas",
      by_id["cryo-line"] and case_has_fluid(by_id["cryo-line"], "ei-nitrogen-gas") and not case_has_fluid(by_id["cryo-line"], "ei-liquid-nitrogen"),
      "liquid=" .. tostring(case_has_fluid(by_id["cryo-line"], "ei-liquid-nitrogen")) .. ", gas=" .. tostring(case_has_fluid(by_id["cryo-line"], "ei-nitrogen-gas"))
    )
    add_check("thermal-line-destroyed", by_id["thermal-line"] and by_id["thermal-line"].exists == false, tostring(by_id["thermal-line"] and by_id["thermal-line"].exists))
    add_check("ignored-data-line-preserved", by_id["ignored-data-line"] and by_id["ignored-data-line"].exists == true, tostring(by_id["ignored-data-line"] and by_id["ignored-data-line"].exists))
    add_check(
      "ignored-data-line-kept-data-fluid",
      by_id["ignored-data-line"] and case_has_fluid(by_id["ignored-data-line"], "ei-computing-power"),
      "data=" .. tostring(case_has_fluid(by_id["ignored-data-line"], "ei-computing-power"))
    )
    add_check("chemical-vessel-destroyed", by_id["chemical-vessel"] and by_id["chemical-vessel"].exists == false, tostring(by_id["chemical-vessel"] and by_id["chemical-vessel"].exists))
  end

  if phase == "fluid-serviced" then
    add_check("flammable-vessel-still-present", by_id["flammable-vessel"] and by_id["flammable-vessel"].exists == true, tostring(by_id["flammable-vessel"] and by_id["flammable-vessel"].exists))
  elseif phase == "flammable-killed" then
    add_check("flammable-vessel-destroyed", by_id["flammable-vessel"] and by_id["flammable-vessel"].exists == false, tostring(by_id["flammable-vessel"] and by_id["flammable-vessel"].exists))
  end

  return {
    phase = phase,
    passed = passed,
    checks = checks,
  }
end

local function collect_rebuild_validation(rebuild_result)
  local surface = ensure_surface()
  local force = get_force()
  local by_id = index_case_results(collect_case_results(surface, force))
  local entries_by_unit = rebuild_result and rebuild_result.entries_by_unit or {}
  local scan_units = rebuild_result and rebuild_result.scan_units or {}
  local checks = {}
  local passed = true

  local function add_check(label, ok, detail)
    if not ok then
      passed = false
    end
    checks[#checks + 1] = {
      label = label,
      passed = ok == true,
      detail = detail,
    }
  end

  local data_line = by_id["data-line"]
  local ignored_data_line = by_id["ignored-data-line"]
  local data_unit = data_line and data_line.unit_number or nil
  local ignored_unit = ignored_data_line and ignored_data_line.unit_number or nil

  add_check("data-line-tracked-after-rebuild", unit_table_has_key(entries_by_unit, data_unit), "unit=" .. tostring(data_unit))
  add_check("ignored-data-line-untracked-after-rebuild", not unit_table_has_key(entries_by_unit, ignored_unit), "unit=" .. tostring(ignored_unit))
  add_check("ignored-data-line-not-scanned-after-rebuild", not unit_list_has_value(scan_units, ignored_unit), "unit=" .. tostring(ignored_unit))

  return {
    phase = "after-rebuild-action",
    passed = passed,
    checks = checks,
  }
end

local function capture_qc_snapshot()
  local ok, snapshot = call_qc_remote("get_fluid_rupture_qc_snapshot")
  if not ok or type(snapshot) ~= "table" then
    return {
      ok = false,
      error = snapshot,
    }
  end

  snapshot.ok = true
  return snapshot
end

local function collect_snapshot(label, current_tick, phase)
  local surface = ensure_surface()
  local force = get_force()
  local results = collect_case_results(surface, force)
  return {
    kind = "snapshot",
    label = label,
    tick = current_tick,
    phase = phase,
    remote_status = collect_remote_status(),
    rupture_snapshot = capture_qc_snapshot(),
    validation = collect_validation(phase, results),
    cases = results,
  }
end

local function build_scenario(current_tick)
  local state = ensure_state()
  local surface = ensure_surface()
  local force = get_force()

  clear_build_area(surface)

  state.base_tick = current_tick or game.tick
  state.action_index = 1
  state.checkpoint_index = 1
  state.built = true

  local placements = {}
  for _, case_spec in ipairs(CASE_SPECS) do
    local entity, inserted = place_case_entity(surface, force, case_spec)
    placements[#placements + 1] = {
      id = case_spec.id,
      entity_name = case_spec.entity_name,
      created = entity and entity.valid or false,
      inserted = inserted,
    }
  end

  write_record({
    kind = "build",
    tick = state.base_tick,
    remote_status = collect_remote_status(),
    placements = placements,
  })
  write_record(collect_snapshot("built", state.base_tick, "built"))
end

local function run_action(action, current_tick)
  if action.name == "rebuild-fluid-runtime" then
    local ok, result = call_qc_remote("rebuild_fluid_rupture_runtime")
    write_record({
      kind = "action",
      action = action.name,
      tick = current_tick,
      ok = ok,
      result = result,
      validation = ok and type(result) == "table" and collect_rebuild_validation(result) or nil,
    })
    return
  end

  if action.name == "service-fluid-runtime" then
    local performed_total = 0
    local ok = true
    local err = nil
    for _ = 1, 4 do
      local service_ok, performed = call_qc_remote("service_fluid_rupture_runtime", 16)
      if not service_ok then
        ok = false
        err = performed
        break
      end
      performed_total = performed_total + (tonumber(performed) or 0)
      if (tonumber(performed) or 0) <= 0 then
        break
      end
    end

    write_record({
      kind = "action",
      action = action.name,
      tick = current_tick,
      ok = ok,
      performed = performed_total,
      error = err,
    })
    return
  end

  if action.name == "kill-flammable-vessel" then
    local surface = ensure_surface()
    local force = get_force()
    local entity = find_case_entity(surface, force, CASE_SPECS[#CASE_SPECS])
    local killed = false
    if entity and entity.valid then
      killed = entity.die(force)
    end

    write_record({
      kind = "action",
      action = action.name,
      tick = current_tick,
      found = entity ~= nil,
      killed = killed == true,
    })
  end
end

local function run_due_actions(current_tick)
  local state = ensure_state()
  if not state.built then
    return
  end

  local next_index = state.action_index
  local action = ACTIONS[next_index]
  while action and current_tick >= state.base_tick + action.tick do
    run_action(action, current_tick)
    state.action_index = next_index + 1
    next_index = state.action_index
    action = ACTIONS[next_index]
  end
end

local function run_due_checkpoints(current_tick)
  local state = ensure_state()
  if not state.built then
    return
  end

  local next_index = state.checkpoint_index
  local checkpoint = CHECKPOINTS[next_index]
  while checkpoint and current_tick >= state.base_tick + checkpoint.tick do
    write_record(collect_snapshot(checkpoint.label, current_tick, checkpoint.phase))
    state.checkpoint_index = next_index + 1
    next_index = state.checkpoint_index
    checkpoint = CHECKPOINTS[next_index]
  end
end

script.on_init(function()
  build_scenario(game.tick)
end)

script.on_configuration_changed(function(event)
  build_scenario(event and event.tick or game.tick)
end)

script.on_event(defines.events.on_tick, function(event)
  run_due_actions(event.tick)
  run_due_checkpoints(event.tick)
end)
