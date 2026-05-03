local REPORT_PATH = "severance-array-qc.jsonl"
local HELPER_REMOTE = "zzz-severance-array-qc"
local MAIN_QC_REMOTE = "exotic-industries-qc"
local FORCE_NAME = "severance-array-qc"
local SURFACE_NAME = "severance-array-qc"
local TURRET_NAME = "ei-severance-array"
local ORIGIN = {x = 0, y = 0}
local TARGET_P95_MS = 1
local AIM_P95_MS = 0.5

local TURRET_ROWS = 8
local TURRET_COLUMNS = 12
local TURRET_SPACING = 8
local ENEMIES_PER_TURRET = 10
local LASER_DAMAGE_MODIFIER = 999
local ENEMY_REFRESH_INTERVAL = 180
local ENEMY_REFRESH_FLOOR_RATIO = 0.65
local SERVICE_LIMIT = 4096
local FINAL_CHECKPOINT_TICK = 3600
local BUILD_RADIUS_CHUNKS = 16

local ENEMY_NAMES = {
  "behemoth-biter",
  "behemoth-spitter",
  "big-biter",
  "big-spitter",
}

local STATIC_ENEMY_NAMES = {
  "behemoth-worm-turret",
  "big-worm-turret",
  "biter-spawner",
  "spitter-spawner",
}

local AMMO_CANDIDATES = {
  "uranium-rounds-magazine",
  "piercing-rounds-magazine",
  "firearm-magazine",
  "explosive-rocket",
  "rocket",
  "explosive-cannon-shell",
  "cannon-shell",
}

local CHECKPOINTS = {
  1,
  30,
  60,
  120,
  300,
  600,
  1200,
  1800,
  2400,
  FINAL_CHECKPOINT_TICK,
}

local BUILD_AREA = {
  left_top = {x = -96, y = -64},
  right_bottom = {x = 160, y = 96},
}

local function ensure_state()
  storage.severance_array_qc = storage.severance_array_qc or {}
  local state = storage.severance_array_qc
  state.built = state.built or false
  state.base_tick = state.base_tick or 0
  state.checkpoint_index = state.checkpoint_index or 1
  state.turret_units = state.turret_units or {}
  state.enemy_units = state.enemy_units or {}
  state.static_enemy_units = state.static_enemy_units or {}
  state.expected_enemy_count = state.expected_enemy_count or 0
  return state
end

local function deep_copy(value)
  if type(value) ~= "table" then
    return value
  end

  local copy = {}
  for key, inner_value in pairs(value) do
    copy[deep_copy(key)] = deep_copy(inner_value)
  end
  return copy
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
    local ok = pcall(helpers.write_file, path, contents, append and true or false, 0)
    if ok then
      return
    end
  end

  if game and game.write_file then
    pcall(function()
      game.write_file(path, contents, append and true or false, 0)
    end)
  end
end

local function write_record(record)
  local encoded = encode_record(record)
  if encoded == "" then
    return
  end

  log("SEVERANCE_ARRAY_QC " .. encoded)
  write_file(REPORT_PATH, encoded .. "\n", true)
end

local function count_keys(tbl)
  local count = 0
  for _ in pairs(tbl or {}) do
    count = count + 1
  end
  return count
end

local function count_array(tbl)
  return type(tbl) == "table" and #tbl or 0
end

local function get_remote_status()
  local interface = remote.interfaces and remote.interfaces[MAIN_QC_REMOTE] or nil
  return {
    present = interface ~= nil,
    member_count = count_keys(interface),
    has_reset = interface and interface.reset_severance_array_runtime ~= nil or false,
    has_configure = interface and interface.configure_severance_array_qc ~= nil or false,
    has_service = interface and interface.service_severance_array_qc ~= nil or false,
    has_snapshot = interface and interface.get_severance_array_qc_snapshot ~= nil or false,
  }
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

local function number_value(value)
  local parsed = tonumber(value)
  if parsed then
    return parsed
  end

  return nil
end

local function first_number(...)
  for index = 1, select("#", ...) do
    local value = number_value(select(index, ...))
    if value then
      return value
    end
  end

  return nil
end

local function table_child(tbl, key)
  if type(tbl) == "table" then
    return tbl[key]
  end

  return nil
end

local function extract_scythe_timing(snapshot)
  if type(snapshot) ~= "table" then
    return {
      present = false,
    }
  end

  local scythe = table_child(snapshot, "scythe_update")
    or table_child(snapshot, "scythe")
    or table_child(table_child(snapshot, "timings"), "scythe_update")
    or table_child(table_child(snapshot, "timing"), "scythe_update")
    or table_child(table_child(snapshot, "severance_array"), "scythe_update")

  return {
    present = true,
    p95_ms = first_number(
      table_child(snapshot, "scythe_update_p95_ms"),
      table_child(snapshot, "p95_ms"),
      table_child(snapshot, "p95_update_ms"),
      table_child(scythe, "p95_ms"),
      table_child(scythe, "p95"),
      table_child(scythe, "p95_update_ms")
    ),
    max_ms = first_number(
      table_child(snapshot, "scythe_update_max_ms"),
      table_child(snapshot, "max_ms"),
      table_child(snapshot, "max_update_ms"),
      table_child(scythe, "max_ms"),
      table_child(scythe, "max"),
      table_child(scythe, "max_update_ms")
    ),
    average_ms = first_number(
      table_child(snapshot, "average_ms"),
      table_child(snapshot, "average_update_ms"),
      table_child(scythe, "average_ms"),
      table_child(scythe, "average_update_ms")
    ),
    last_ms = first_number(
      table_child(snapshot, "last_ms"),
      table_child(snapshot, "last_update_ms"),
      table_child(scythe, "last_ms"),
      table_child(scythe, "last_update_ms")
    ),
    sample_count = first_number(
      table_child(snapshot, "scythe_update_sample_count"),
      table_child(snapshot, "sample_count"),
      table_child(scythe, "sample_count"),
      table_child(scythe, "samples"),
      table_child(scythe, "count")
    ),
  }
end

local function get_base_map_gen_settings()
  local base_surface = game.surfaces["nauvis"] or game.surfaces[1]
  if base_surface and base_surface.valid and base_surface.map_gen_settings then
    return deep_copy(base_surface.map_gen_settings)
  end

  return deep_copy(game.default_map_gen_settings)
end

local function disable_autoplace(settings)
  settings = settings or {}
  settings.autoplace_controls = {}
  settings.autoplace_settings = settings.autoplace_settings or {}

  for _, category in ipairs({"entity", "tile", "decorative"}) do
    local target = settings.autoplace_settings[category]
    if type(target) == "table" then
      target.settings = {}
      target.treat_missing_as_default = false
    end
  end

  return settings
end

local function ensure_surface()
  local existing = game.surfaces[SURFACE_NAME]
  if existing and existing.valid then
    return existing
  end

  local settings = disable_autoplace(get_base_map_gen_settings())
  settings.width = 384
  settings.height = 256

  return game.create_surface(SURFACE_NAME, settings)
end

local function get_force()
  local force = game.forces[FORCE_NAME]
  if force and force.valid then
    return force
  end

  force = game.create_force(FORCE_NAME)
  return force
end

local function configure_forces(force)
  local enemy = game.forces.enemy
  if not (force and force.valid and enemy and enemy.valid) then
    return
  end

  force.set_friend(enemy, false)
  force.set_cease_fire(enemy, false)
  enemy.set_friend(force, false)
  enemy.set_cease_fire(force, false)

  pcall(function()
    force.set_ammo_damage_modifier("laser", LASER_DAMAGE_MODIFIER)
  end)
end

local function absolute_position(relative_position)
  return {
    x = ORIGIN.x + relative_position.x,
    y = ORIGIN.y + relative_position.y,
  }
end

local function clear_build_area(surface)
  surface.request_to_generate_chunks(ORIGIN, BUILD_RADIUS_CHUNKS)
  surface.force_generate_chunk_requests()

  local tiles = {}
  for x = BUILD_AREA.left_top.x, BUILD_AREA.right_bottom.x do
    for y = BUILD_AREA.left_top.y, BUILD_AREA.right_bottom.y do
      tiles[#tiles + 1] = {name = "refined-concrete", position = {x = x, y = y}}
    end
  end

  local ok = pcall(function()
    surface.set_tiles(tiles, true)
  end)
  if not ok then
    for _, tile in ipairs(tiles) do
      tile.name = "stone-path"
    end
    pcall(function()
      surface.set_tiles(tiles, true)
    end)
  end

  surface.destroy_decoratives({area = BUILD_AREA})
  for _, entity in pairs(surface.find_entities_filtered({area = BUILD_AREA})) do
    if entity.valid and entity.type ~= "character" then
      entity.destroy({raise_destroy = false})
    end
  end
end

local function place_entity(surface, definition)
  definition.create_build_effect_smoke = false
  local ok, entity = pcall(function()
    return surface.create_entity(definition)
  end)
  if not ok or not (entity and entity.valid) then
    return nil, ok and "invalid-entity" or tostring(entity)
  end

  if entity.energy then
    pcall(function()
      entity.energy = math.max(entity.energy, 10000000000)
    end)
  end

  return entity, nil
end

local function place_power(surface, force)
  local placed = 0
  for x = BUILD_AREA.left_top.x + 16, BUILD_AREA.right_bottom.x - 16, 32 do
    for y = BUILD_AREA.left_top.y + 16, BUILD_AREA.right_bottom.y - 16, 32 do
      local substation = place_entity(surface, {
        name = "substation",
        position = {x = x, y = y},
        force = force,
      })
      if substation then
        placed = placed + 1
      end
    end
  end

  local interface = place_entity(surface, {
    name = "electric-energy-interface",
    position = {x = BUILD_AREA.left_top.x + 8, y = BUILD_AREA.left_top.y + 8},
    force = force,
  })

  return {
    substations = placed,
    energy_interface = interface ~= nil,
  }
end

local function fill_turret_ammo(turret)
  if not (turret and turret.valid) then
    return 0
  end

  local inventory = nil
  local ok, result = pcall(function()
    return turret.get_inventory(defines.inventory.turret_ammo)
  end)
  if ok and result and result.valid then
    inventory = result
  end

  if not inventory then
    return 0
  end

  local inserted_total = 0
  for _, ammo_name in ipairs(AMMO_CANDIDATES) do
    local inserted = 0
    local insert_ok, insert_result = pcall(function()
      return inventory.insert({name = ammo_name, count = 200})
    end)
    if insert_ok then
      inserted = tonumber(insert_result) or 0
    end
    inserted_total = inserted_total + inserted
  end

  return inserted_total
end

local function turret_position(row, column)
  local width = (TURRET_COLUMNS - 1) * TURRET_SPACING
  local height = (TURRET_ROWS - 1) * TURRET_SPACING
  return {
    x = -width / 2 + (column - 1) * TURRET_SPACING,
    y = -height / 2 + (row - 1) * TURRET_SPACING,
  }
end

local function enemy_position_for_turret(row, column, slot)
  local turret_pos = turret_position(row, column)
  local lane = slot - 1
  local side = lane % 2 == 0 and 1 or -1
  local forward = 40 + math.floor(lane / 2) * 3
  local offset_y = side * (1.5 + (lane % 5) * 1.25)

  return {
    x = turret_pos.x + forward,
    y = turret_pos.y + offset_y,
  }
end

local function place_turrets(surface, force, state)
  local created = 0
  local failed = 0
  local inserted_ammo = 0
  state.turret_units = {}

  for row = 1, TURRET_ROWS do
    for column = 1, TURRET_COLUMNS do
      local position = absolute_position(turret_position(row, column))
      local turret, error_message = place_entity(surface, {
        name = TURRET_NAME,
        position = position,
        force = force,
        raise_built = true,
      })

      if turret then
        created = created + 1
        inserted_ammo = inserted_ammo + fill_turret_ammo(turret)
        state.turret_units[#state.turret_units + 1] = turret.unit_number
      else
        failed = failed + 1
        if failed <= 4 then
          write_record({
            kind = "placement-error",
            tick = game.tick,
            entity = TURRET_NAME,
            position = position,
            error = error_message,
          })
        end
      end
    end
  end

  return {
    created = created,
    failed = failed,
    inserted_ammo = inserted_ammo,
  }
end

local function freeze_enemy(entity)
  if not (entity and entity.valid) then
    return
  end

  pcall(function()
    entity.active = false
  end)
  pcall(function()
    entity.destructible = true
  end)
end

local function spawn_enemy(surface, position, slot, static)
  local names = static and STATIC_ENEMY_NAMES or ENEMY_NAMES
  local name = names[(slot % #names) + 1]
  local entity = place_entity(surface, {
    name = name,
    position = position,
    force = game.forces.enemy,
  })

  if entity then
    freeze_enemy(entity)
  end

  return entity
end

local function spawn_enemy_field(surface, state, static_only)
  local created_units = 0
  local created_static = 0
  state.enemy_units = state.enemy_units or {}
  state.static_enemy_units = state.static_enemy_units or {}

  for row = 1, TURRET_ROWS do
    for column = 1, TURRET_COLUMNS do
      for slot = 1, ENEMIES_PER_TURRET do
        local position = absolute_position(enemy_position_for_turret(row, column, slot))
        local static = static_only or slot % 4 == 0
        local enemy = spawn_enemy(surface, position, slot + row + column, static)
        if enemy then
          if static then
            created_static = created_static + 1
            state.static_enemy_units[#state.static_enemy_units + 1] = enemy.unit_number
          else
            created_units = created_units + 1
            state.enemy_units[#state.enemy_units + 1] = enemy.unit_number
          end
        end
      end
    end
  end

  state.expected_enemy_count = math.max(state.expected_enemy_count or 0, created_units + created_static)
  return {
    created_units = created_units,
    created_static = created_static,
    expected_enemy_count = state.expected_enemy_count,
  }
end

local function find_entities_by_unit_numbers(surface, unit_numbers)
  local by_unit = {}
  for _, entity in pairs(surface.find_entities_filtered({area = BUILD_AREA})) do
    if entity.valid and entity.unit_number then
      by_unit[entity.unit_number] = entity
    end
  end

  local found = {}
  for _, unit_number in ipairs(unit_numbers or {}) do
    local entity = by_unit[unit_number]
    if entity and entity.valid then
      found[#found + 1] = entity
    end
  end

  return found
end

local function count_live_tracked(surface, unit_numbers)
  return count_array(find_entities_by_unit_numbers(surface, unit_numbers))
end

local function entity_has_health(entity)
  if not (entity and entity.valid) then
    return false
  end

  local ok, health = pcall(function()
    return entity.health
  end)

  return ok and health ~= nil
end

local function count_enemy_targets(surface)
  local count = 0
  for _, entity in pairs(surface.find_entities_filtered({area = BUILD_AREA, force = "enemy"})) do
    if entity_has_health(entity) then
      count = count + 1
    end
  end

  return count
end

local function refresh_enemies_if_needed(surface, state, current_tick)
  if current_tick < (state.next_enemy_refresh_tick or 0) then
    return nil
  end

  state.next_enemy_refresh_tick = current_tick + ENEMY_REFRESH_INTERVAL
  local live_count = count_enemy_targets(surface)
  local floor = math.floor((state.expected_enemy_count or 0) * ENEMY_REFRESH_FLOOR_RATIO)
  if live_count >= floor then
    return {
      refreshed = false,
      live_enemy_count = live_count,
      refresh_floor = floor,
    }
  end

  local spawned = spawn_enemy_field(surface, state, false)
  spawned.refreshed = true
  spawned.live_enemy_count_before = live_count
  spawned.refresh_floor = floor
  return spawned
end

local function sync_main_runtime(reason, current_tick)
  local reset_ok, reset_result = call_main_qc("reset_severance_array_runtime", reason or "severance-array-qc", current_tick or game.tick)
  local configure_ok, configure_result = call_main_qc("configure_severance_array_qc", {
    reset = true,
    qc_enabled = true,
    profiling_enabled = true,
  })
  local service_ok, service_result = call_main_qc("service_severance_array_qc", SERVICE_LIMIT)

  return {
    reset_ok = reset_ok,
    reset_result = reset_result,
    configure_ok = configure_ok,
    configure_result = configure_result,
    service_ok = service_ok,
    service_result = service_result,
  }
end

local function collect_main_snapshot()
  local ok, snapshot = call_main_qc("get_severance_array_qc_snapshot")
  if ok and type(snapshot) == "table" then
    return {
      ok = true,
      snapshot = snapshot,
      timing = extract_scythe_timing(snapshot),
    }
  end

  return {
    ok = false,
    error = snapshot,
    timing = extract_scythe_timing(nil),
  }
end

local function summarize_validation(main_snapshot)
  local timing = main_snapshot and main_snapshot.timing or {}
  local p95_ms = tonumber(timing.p95_ms)
  local max_ms = tonumber(timing.max_ms)

  return {
    target_p95_ms = TARGET_P95_MS,
    aim_p95_ms = AIM_P95_MS,
    p95_under_target = p95_ms ~= nil and p95_ms < TARGET_P95_MS or false,
    p95_at_aim = p95_ms ~= nil and p95_ms <= AIM_P95_MS or false,
    max_under_target = max_ms ~= nil and max_ms < TARGET_P95_MS or false,
    max_ms = max_ms,
    average_ms = tonumber(timing.average_ms),
    last_ms = tonumber(timing.last_ms),
    timing_available = p95_ms ~= nil or max_ms ~= nil,
  }
end

local function collect_status(label, current_tick)
  local state = ensure_state()
  local surface = ensure_surface()
  local main_snapshot = collect_main_snapshot()

  return {
    kind = "snapshot",
    label = label,
    tick = current_tick or game.tick,
    relative_tick = (current_tick or game.tick) - (state.base_tick or 0),
    surface = surface.name,
    built = state.built == true,
    expected_turrets = TURRET_ROWS * TURRET_COLUMNS,
    expected_enemy_count = state.expected_enemy_count or 0,
    live_turrets = count_live_tracked(surface, state.turret_units),
    live_enemy_units = count_live_tracked(surface, state.enemy_units),
    live_static_enemies = count_live_tracked(surface, state.static_enemy_units),
    live_enemy_targets = count_enemy_targets(surface),
    remote_status = get_remote_status(),
    main_snapshot = main_snapshot,
    validation = summarize_validation(main_snapshot),
  }
end

local function build_scenario(current_tick, options)
  local state = ensure_state()
  local surface = ensure_surface()
  local force = get_force()
  current_tick = current_tick or game.tick

  configure_forces(force)
  clear_build_area(surface)
  write_file(REPORT_PATH, "", false)

  state.built = true
  state.base_tick = current_tick
  state.checkpoint_index = 1
  state.turret_units = {}
  state.enemy_units = {}
  state.static_enemy_units = {}
  state.expected_enemy_count = 0
  state.next_enemy_refresh_tick = current_tick + ENEMY_REFRESH_INTERVAL

  local power = place_power(surface, force)
  local turrets = place_turrets(surface, force, state)
  local enemies = spawn_enemy_field(surface, state, options and options.static_only == true)
  local sync = sync_main_runtime("build", current_tick)

  write_record({
    kind = "build",
    tick = current_tick,
    surface = surface.name,
    force = force.name,
    turret_name = TURRET_NAME,
    target_p95_ms = TARGET_P95_MS,
      aim_p95_ms = AIM_P95_MS,
      laser_damage_modifier = LASER_DAMAGE_MODIFIER,
      grid = {
      rows = TURRET_ROWS,
      columns = TURRET_COLUMNS,
      spacing = TURRET_SPACING,
      enemies_per_turret = ENEMIES_PER_TURRET,
    },
    power = power,
    turrets = turrets,
    enemies = enemies,
    remote_status = get_remote_status(),
    main_runtime_sync = sync,
  })
  write_record(collect_status("post-build", current_tick))

  return {
    built = state.built,
    turrets = turrets,
    enemies = enemies,
    sync = sync,
  }
end

local function run_due_checkpoints(current_tick)
  local state = ensure_state()
  if not state.built then
    return
  end

  local surface = ensure_surface()
  local refresh = refresh_enemies_if_needed(surface, state, current_tick)
  if refresh and refresh.refreshed then
    write_record({
      kind = "enemy-refresh",
      tick = current_tick,
      result = refresh,
    })
  end

  local next_index = state.checkpoint_index
  local checkpoint = CHECKPOINTS[next_index]
  while checkpoint and current_tick >= state.base_tick + checkpoint do
    call_main_qc("service_severance_array_qc", SERVICE_LIMIT)
    write_record(collect_status("t+" .. tostring(checkpoint), current_tick))
    state.checkpoint_index = next_index + 1
    next_index = state.checkpoint_index
    checkpoint = CHECKPOINTS[next_index]
  end
end

local function ensure_built(reason, current_tick)
  local state = ensure_state()
  if state.built then
    return
  end

  build_scenario(current_tick or game.tick, {reason = reason})
end

remote.add_interface(HELPER_REMOTE, {
  rebuild = function(options)
    return build_scenario(game.tick, options)
  end,
  get_status = function(label)
    return collect_status(label or "remote", game.tick)
  end,
  write_report = function(label)
    local snapshot = collect_status(label or "remote-report", game.tick)
    write_record(snapshot)
    return snapshot
  end,
  spawn_wave = function(static_only)
    local state = ensure_state()
    local result = spawn_enemy_field(ensure_surface(), state, static_only == true)
    write_record({
      kind = "manual-wave",
      tick = game.tick,
      result = result,
    })
    return result
  end,
})

script.on_init(function()
  build_scenario(game.tick)
end)

script.on_configuration_changed(function(event)
  build_scenario(event and event.tick or game.tick)
end)

script.on_event(defines.events.on_tick, function(event)
  ensure_built("tick", event.tick)
  run_due_checkpoints(event.tick)
end)
