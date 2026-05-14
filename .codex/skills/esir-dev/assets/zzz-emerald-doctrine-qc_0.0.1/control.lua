local REPORT_PATH = "emerald-doctrine-qc.jsonl"
local HELPER_REMOTE = "zzz-emerald-doctrine-qc"
local MAIN_QC_REMOTE = "exotic-industries-qc"
local FORCE_NAME = "emerald-doctrine-qc"
local SURFACE_NAME = "emerald-doctrine-qc"
local TANK_NAME = "ei-emerald-apocalypse-hover-tank"
local CHARGE_NAME = "ei-emerald-apocalypse-charge"
local FUEL_NAME = "nuclear-fuel"
local ORIGIN = {x = 0, y = 0}

local CHECKPOINTS = {1, 30, 120, 360, 720, 1200}
local DOCTRINE_TECHS = {
  "ei-emerald-charge-catechism-1",
  "ei-emerald-charge-catechism-2",
  "ei-emerald-charge-catechism-3",
  "ei-emerald-inertial-oath-1",
  "ei-emerald-inertial-oath-2",
  "ei-emerald-aegis-covenant-1",
  "ei-emerald-aegis-covenant-2",
  "ei-emerald-vector-keel-1",
  "ei-emerald-vector-keel-2",
  "ei-emerald-collapse-mandate-1",
  "ei-emerald-collapse-mandate-2",
  "ei-emerald-collapse-mandate-3",
  "ei-emerald-apocalypse-recursion",
}

local function ensure_state()
  storage.emerald_doctrine_qc = storage.emerald_doctrine_qc or {}
  local state = storage.emerald_doctrine_qc
  state.built = state.built or false
  state.base_tick = state.base_tick or 0
  state.checkpoint_index = state.checkpoint_index or 1
  state.tank_unit_number = state.tank_unit_number or nil
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

  log("EMERALD_DOCTRINE_QC " .. encoded)
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

local function call_main_qc(member_name, ...)
  if not remote.interfaces[MAIN_QC_REMOTE] or not remote.interfaces[MAIN_QC_REMOTE][member_name] then
    return false, "missing-remote:" .. member_name
  end

  local ok, result = pcall(remote.call, MAIN_QC_REMOTE, member_name, ...)
  if ok then
    return true, result
  end
  return false, tostring(result)
end

local function get_force()
  local force = game.forces[FORCE_NAME]
  if not force then
    force = game.create_force(FORCE_NAME)
  end
  return force
end

local function get_surface()
  local surface = game.surfaces[SURFACE_NAME]
  if not surface then
    surface = game.create_surface(SURFACE_NAME, {
      width = 384,
      height = 384,
      default_enable_all_autoplace_controls = false,
    })
  end
  return surface
end

local function set_researched(force, names)
  for _, name in ipairs(names or {}) do
    local technology = force.technologies[name]
    if technology then
      technology.researched = true
    end
  end
end

local function build_world(state)
  if state.built then
    return
  end

  local surface = get_surface()
  local force = get_force()
  set_researched(force, DOCTRINE_TECHS)
  surface.request_to_generate_chunks(ORIGIN, 4)
  surface.force_generate_chunk_requests()

  for _, entity in pairs(surface.find_entities_filtered{area = {{-96, -96}, {96, 96}}}) do
    if entity.valid then
      entity.destroy()
    end
  end

  local tank = surface.create_entity{
    name = TANK_NAME,
    position = ORIGIN,
    force = force,
    raise_built = true,
  }
  if tank and tank.valid then
    pcall(function()
      tank.insert{name = CHARGE_NAME, count = 8}
      tank.insert{name = FUEL_NAME, count = 4}
    end)
    state.tank_unit_number = tank.unit_number
  end

  for i = 1, 18 do
    surface.create_entity{
      name = i % 3 == 0 and "behemoth-spitter" or "behemoth-biter",
      position = {x = 28 + (i % 6) * 3, y = -8 + math.floor(i / 6) * 4},
      force = "enemy",
    }
  end

  local ok_reset, reset_result = call_main_qc("reset_emerald_apocalypse_hover_tank_runtime", "emerald-doctrine-qc")
  local ok_configure, configure_result = call_main_qc("configure_emerald_apocalypse_hover_tank_qc", {enabled = true})
  state.built = true
  state.base_tick = game.tick
  write_record{
    event = "built",
    tick = game.tick,
    tank_unit_number = state.tank_unit_number,
    reset = {ok = ok_reset, result = reset_result},
    configure = {ok = ok_configure, result = configure_result},
  }
end

local function checkpoint(state)
  local relative_tick = game.tick - (state.base_tick or 0)
  local target_tick = CHECKPOINTS[state.checkpoint_index]
  if not target_tick or relative_tick < target_tick then
    return
  end

  local ok_service, service_result = call_main_qc("service_emerald_apocalypse_hover_tank_qc", 4096, game.tick)
  local ok_snapshot, snapshot = call_main_qc("get_emerald_apocalypse_hover_tank_qc_snapshot", game.tick)
  write_record{
    event = "checkpoint",
    tick = game.tick,
    relative_tick = relative_tick,
    service = {ok = ok_service, result = service_result},
    snapshot_ok = ok_snapshot,
    remote_members = remote.interfaces[MAIN_QC_REMOTE] and count_keys(remote.interfaces[MAIN_QC_REMOTE]) or 0,
    snapshot = snapshot,
  }
  state.checkpoint_index = state.checkpoint_index + 1
end

script.on_init(function()
  local state = ensure_state()
  state.built = false
  build_world(state)
end)

script.on_configuration_changed(function()
  local state = ensure_state()
  state.built = false
  build_world(state)
end)

script.on_event(defines.events.on_tick, function()
  local state = ensure_state()
  build_world(state)
  checkpoint(state)
end)

remote.add_interface(HELPER_REMOTE, {
  rebuild = function()
    local state = ensure_state()
    state.built = false
    state.checkpoint_index = 1
    build_world(state)
    return true
  end,
  snapshot = function()
    local ok, snapshot = call_main_qc("get_emerald_apocalypse_hover_tank_qc_snapshot", game.tick)
    return {ok = ok, snapshot = snapshot}
  end,
})
