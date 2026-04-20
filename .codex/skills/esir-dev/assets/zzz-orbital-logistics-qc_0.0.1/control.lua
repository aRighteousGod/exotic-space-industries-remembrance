local REPORT_PATH = "orbital-logistics-qc.jsonl"
local FORCE_NAME = "orbital-logistics-qc"
local SURFACE_NAME = "nauvis"
local ORIGIN = {x = 4800, y = 4800}
local BUILD_AREA = {
  left_top = {x = ORIGIN.x - 128, y = ORIGIN.y - 128},
  right_bottom = {x = ORIGIN.x + 128, y = ORIGIN.y + 128},
}

local PLATFORM_SPECS = {
  {
    name = "QC Alpha",
    planet = "nauvis",
    request_filters = {
      {value = {type = "item", name = "iron-plate", quality = "normal"}, min = 200},
      {value = {type = "item", name = "copper-plate", quality = "normal"}, min = 150},
    },
  },
  {
    name = "QC Beta",
    planet = "nauvis",
    request_filters = {
      {value = {type = "item", name = "steel-plate", quality = "normal"}, min = 80},
      {value = {type = "item", name = "processing-unit", quality = "normal"}, min = 25},
    },
  },
  {
    name = "QC Gamma",
    planet = "nauvis",
    request_filters = {
      {value = {type = "item", name = "stone-brick", quality = "normal"}, min = 60},
      {value = {type = "item", name = "low-density-structure", quality = "normal"}, min = 12},
    },
  },
}

local GROUND_ENTITIES = {
  scanner = {
    name = "ei-orbital-combinator",
    position = {-24, -8},
  },
  coordinator = {
    name = "ei-orbital-coordinator",
    position = {-2, 0},
  },
  coordinator_b = {
    name = "ei-orbital-coordinator",
    position = {6, 0},
  },
  selector_a = {
    name = "ei-orbital-selector",
    position = {-14, 10},
  },
  selector_b = {
    name = "ei-orbital-selector",
    position = {-14, -14},
  },
  selector_c = {
    name = "ei-orbital-selector",
    position = {-14, 34},
  },
  silo_a = {
    name = "rocket-silo",
    position = {24, -12},
  },
  uplink_a = {
    name = "ei-orbital-dispatch-uplink",
    position = {16, -12},
  },
  silo_b = {
    name = "rocket-silo",
    position = {24, 12},
  },
  uplink_b = {
    name = "ei-orbital-dispatch-uplink",
    position = {16, 12},
  },
}

local GROUND_ENTITY_ORDER = {
  "scanner",
  "coordinator",
  "coordinator_b",
  "selector_a",
  "selector_b",
  "selector_c",
  "silo_a",
  "uplink_a",
  "silo_b",
  "uplink_b",
}

local CHECKPOINTS = {
  1,
  30,
  60,
  120,
  180,
  240,
  270,
  300,
  330,
  420,
  450,
  480,
}

-- The helper should do more than assemble a pretty still life. These timed
-- mutations deliberately force coordinator failover, lease release, retargeting,
-- real silo loss, and a contested-lane rotation so the checkpoint snapshots
-- prove the cohort can recover from live drift instead of just idle prettily.
local ACTIONS = {
  {tick = 45, name = "duplicate-manual-target"},
  {tick = 90, name = "restore-policy-selector"},
  {tick = 120, name = "destroy-active-coordinator"},
  {tick = 150, name = "invalid-manual-selector"},
  {tick = 195, name = "restore-manual-selector"},
  {tick = 225, name = "retarget-manual-selector"},
  {tick = 255, name = "destroy-silo-b"},
  {tick = 285, name = "rebuild-silo-b"},
  {tick = 300, name = "rebind-uplink-b"},
  {tick = 330, name = "prepare-fairness-rotation"},
  {tick = 345, name = "clear-fairness-lane"},
  {tick = 360, name = "rebind-fairness-lane-first"},
  {tick = 375, name = "clear-fairness-lane-again"},
  {tick = 390, name = "rebind-fairness-lane-second"},
  {tick = 405, name = "create-transponder-conflict"},
  {tick = 435, name = "restore-transponder-ids"},
}

local CONFIGURE_RETRY_INTERVAL = 30

local function ensure_state()
  storage.orbital_logistics_qc = storage.orbital_logistics_qc or {}
  local state = storage.orbital_logistics_qc
  state.platforms = state.platforms or {}
  state.entity_units = state.entity_units or {}
  state.platform_ids = state.platform_ids or {}
  state.checkpoint_index = state.checkpoint_index or 1
  state.action_index = state.action_index or 1
  state.built = state.built or false
  state.platforms_ready = state.platforms_ready or false
  state.configured = state.configured or false
  state.needs_runtime_rearm = state.needs_runtime_rearm == nil and true or state.needs_runtime_rearm
  state.platform_prime_attempts = state.platform_prime_attempts or 0
  state.configure_attempts = state.configure_attempts or 0
  state.next_configure_tick = state.next_configure_tick or 0
  state.base_tick = state.base_tick or 0
  return state
end

local function count_keys(tbl)
  local count = 0
  for _ in pairs(tbl or {}) do
    count = count + 1
  end
  return count
end

local function collect_remote_status()
  local interface = remote.interfaces and remote.interfaces["exotic-industries-qc"] or nil
  local interface_names = {}

  if remote.interfaces then
    for name in pairs(remote.interfaces) do
      interface_names[#interface_names + 1] = name
    end
  end

  table.sort(interface_names)

  local truncated = false
  while #interface_names > 12 do
    interface_names[#interface_names] = nil
    truncated = true
  end

  return {
    present = interface ~= nil,
    member_count = count_keys(interface),
    interface_names = interface_names,
    interface_names_truncated = truncated,
  }
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

  log("ORBITAL_LOGISTICS_QC " .. encoded)

  if helpers and helpers.write_file then
    helpers.write_file(REPORT_PATH, encoded .. "\n", true, 0)
  elseif game and game.write_file then
    game.write_file(REPORT_PATH, encoded .. "\n", true, 0)
  end
end

local function get_force()
  local force = game.forces[FORCE_NAME]
  if force and force.valid then
    return force
  end

  return game.create_force(FORCE_NAME)
end

local function ensure_surface(name)
  local surface = game.surfaces[name]
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
  surface.request_to_generate_chunks(ORIGIN, 8)
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

local function place_entity(surface, definition)
  definition.create_build_effect_smoke = false
  local entity = surface.create_entity(definition)
  if entity and entity.valid and entity.energy then
    entity.energy = math.max(entity.energy, 1000000000)
  end
  return entity
end

local function place_power_backbone(surface, force)
  local positions = {
    {-24, -8},
    {-4, -8},
    {16, -8},
    {36, -8},
  }

  for _, offset in ipairs(positions) do
    place_entity(surface, {
      name = "substation",
      position = absolute_position(offset),
      force = force,
      raise_built = true,
    })
  end

  place_entity(surface, {
    name = "electric-energy-interface",
    position = absolute_position({-28, -8}),
    force = force,
  })
end

local function place_ground_layout(surface, force, state)
  place_power_backbone(surface, force)

  for _, key in ipairs(GROUND_ENTITY_ORDER) do
    local definition = GROUND_ENTITIES[key]
    local entity = place_entity(surface, {
      name = definition.name,
      position = absolute_position(definition.position),
      force = force,
      raise_built = true,
    })
    state.entity_units[key] = entity and entity.valid and entity.unit_number or nil
  end
end

local function find_ground_entity(surface, force, key, expected_unit_number)
  local definition = GROUND_ENTITIES[key]
  if not definition then
    return nil, "unknown-ground-entity"
  end

  local position = absolute_position(definition.position)
  local candidates = surface.find_entities_filtered({
    area = {
      {x = position.x - 4, y = position.y - 4},
      {x = position.x + 4, y = position.y + 4},
    },
    name = definition.name,
    force = force,
  })

  local fallback = nil
  for _, entity in ipairs(candidates) do
    if entity.valid then
      if expected_unit_number and entity.unit_number == expected_unit_number then
        return entity, nil
      end
      fallback = fallback or entity
    end
  end

  if fallback then
    return fallback, nil
  end

  return nil, "missing-ground-entity"
end

local function destroy_ground_entity(surface, force, state, key)
  local entity, find_error = find_ground_entity(surface, force, key, state.entity_units[key])
  if not entity then
    return false, find_error, {
      action = "destroy-entity",
      entity_key = key,
      expected_unit_number = state.entity_units[key],
    }
  end

  local old_unit_number = entity.unit_number
  local ok, destroyed = pcall(function()
    return entity.destroy({raise_destroy = true})
  end)
  if ok and destroyed then
    state.entity_units[key] = nil
  end

  return ok and destroyed or false,
    ok and "destroyed" or tostring(destroyed),
    {
      action = "destroy-entity",
      entity_key = key,
      old_unit_number = old_unit_number,
    }
end

local function rebuild_ground_entity(surface, force, state, key)
  local definition = GROUND_ENTITIES[key]
  if not definition then
    return false, "unknown-ground-entity", {
      action = "rebuild-entity",
      entity_key = key,
    }
  end

  local existing = find_ground_entity(surface, force, key, state.entity_units[key])
  if existing then
    return false, "entity-still-present", {
      action = "rebuild-entity",
      entity_key = key,
      existing_unit_number = existing.unit_number,
    }
  end

  local entity = place_entity(surface, {
    name = definition.name,
    position = absolute_position(definition.position),
    force = force,
    raise_built = true,
  })

  state.entity_units[key] = entity and entity.valid and entity.unit_number or nil

  return entity and entity.valid or false,
    entity and entity.unit_number or "invalid-entity",
    {
      action = "rebuild-entity",
      entity_key = key,
      new_unit_number = state.entity_units[key],
    }
end

local function get_platform_requester_point(platform)
  if not (platform and platform.valid and platform.hub and platform.hub.valid) then
    return nil, "missing-hub", nil
  end

  local point_getters = {
    {
      label = "entity-requester-point",
      getter = function()
        return platform.hub.get_requester_point and platform.hub.get_requester_point() or nil
      end,
    },
    {
      label = "space-platform-hub-requester",
      getter = function()
        return platform.hub.get_logistic_point(defines.logistic_member_index.space_platform_hub_requester)
      end,
    },
    {
      label = "cargo-landing-pad-requester",
      getter = function()
        return platform.hub.get_logistic_point(defines.logistic_member_index.cargo_landing_pad_requester)
      end,
    },
  }

  local last_error = "missing-requester-point"
  for _, candidate in ipairs(point_getters) do
    local ok, point = pcall(candidate.getter)
    if ok and point and point.valid then
      return point, nil, candidate.label
    end
    if not ok then
      last_error = tostring(point)
    end
  end

  return nil, last_error, nil
end

local function get_manual_request_section(point)
  local manual_sections = {}

  for _, section in ipairs(point.sections or {}) do
    if section and section.valid and section.is_manual then
      manual_sections[#manual_sections + 1] = section
    end
  end

  table.sort(manual_sections, function(left, right)
    return (left.index or 0) < (right.index or 0)
  end)

  for index = #manual_sections, 2, -1 do
    point.remove_section(manual_sections[index].index)
  end

  if manual_sections[1] and manual_sections[1].valid then
    return manual_sections[1]
  end

  local ok, section = pcall(point.add_section, point, "qc")
  if ok and section and section.valid then
    return section
  end

  return nil
end

local function set_platform_requests(platform, filters)
  local point, point_error, point_source = get_platform_requester_point(platform)
  if not point then
    return false, point_error, point_source
  end

  local section = get_manual_request_section(point)
  if not (section and section.valid) then
    return false, "missing-requester-section", point_source
  end

  local assigned, assign_error = pcall(function()
    if section.group ~= "qc" then
      section.group = "qc"
    end
    if section.active ~= true then
      section.active = true
    end

    for slot_index = section.filters_count, 1, -1 do
      section.clear_slot(slot_index)
    end

    for slot_index, filter in ipairs(filters or {}) do
      section.set_slot(slot_index, {
        value = {
          type = filter.value.type,
          name = filter.value.name,
          quality = filter.value.quality or "normal",
        },
        min = math.max(0, tonumber(filter.min) or 0),
        max = filter.max,
      })
    end
  end)
  if assigned then
    return true, nil, point_source
  end

  return false, tostring(assign_error), point_source
end

local function get_existing_platform(force, name)
  for _, platform in pairs(force.platforms or {}) do
    if platform and platform.valid and platform.name == name then
      return platform
    end
  end

  return nil
end

local function ensure_platform(force, spec)
  local platform = get_existing_platform(force, spec.name)
  if platform and platform.valid then
    return platform, "reused"
  end

  local ok, created = pcall(function()
    return force.create_space_platform{
      name = spec.name,
      planet = spec.planet,
      starter_pack = "space-platform-starter-pack",
    }
  end)

  if ok and created and created.valid then
    return created, "created"
  end

  return nil, ok and "invalid-platform" or tostring(created)
end

local function ensure_platform_hub(platform)
  if not (platform and platform.valid) then
    return nil, "missing-platform"
  end

  if platform.hub and platform.hub.valid then
    return platform.hub, "ready"
  end

  local ok, hub = pcall(platform.apply_starter_pack, platform)
  if ok and hub and hub.valid then
    return hub, "applied"
  end

  return nil, ok and "hub-not-ready" or tostring(hub)
end

local function place_transponder_for_platform(platform, force, state)
  if not (platform and platform.valid and platform.surface and platform.surface.valid and platform.hub and platform.hub.valid) then
    return nil
  end

  for _, existing in pairs(platform.surface.find_entities_filtered({name = "ei-platform-transponder"})) do
    if existing.valid then
      existing.destroy({raise_destroy = false})
    end
  end

  local position = {
    x = platform.hub.position.x + 2,
    y = platform.hub.position.y + 2,
  }

  local entity = place_entity(platform.surface, {
    name = "ei-platform-transponder",
    position = position,
    force = force,
    raise_built = true,
  })

  local platform_state = {
    index = platform.index,
    name = platform.name,
    surface_name = platform.surface.name,
    hub_unit_number = platform.hub.unit_number,
    transponder_unit_number = entity and entity.valid and entity.unit_number or nil,
  }
  state.platforms[platform.index] = platform_state
  state.platforms[platform.name] = platform_state

  return entity
end

local function create_platforms(force)
  local created = {}

  for _, spec in ipairs(PLATFORM_SPECS) do
    local platform, status = ensure_platform(force, spec)
    if platform and platform.valid then
      created[#created + 1] = {
        index = platform.index,
        name = platform.name,
        status = status,
        surface_name = platform.surface and platform.surface.valid and platform.surface.name or nil,
        dispatch_surface_name = platform.space_location and platform.space_location.name or nil,
      }
    else
      created[#created + 1] = {
        index = nil,
        name = spec.name,
        error = status,
      }
    end
  end

  return created
end

local function prime_platforms(force, state)
  local results = {}
  local all_ready = true
  state.platform_prime_attempts = (state.platform_prime_attempts or 0) + 1
  state.platforms = {}

  for _, spec in ipairs(PLATFORM_SPECS) do
    local platform = get_existing_platform(force, spec.name)
    local result = {
      name = spec.name,
      platform_index = platform and platform.valid and platform.index or nil,
      hub_ready = false,
    }

    local hub, hub_status = ensure_platform_hub(platform)
    result.hub_status = hub_status
    result.hub_ready = hub and hub.valid or false

    if platform and platform.valid and hub and hub.valid and platform.surface and platform.surface.valid then
      local assigned_requests, request_error, request_source = set_platform_requests(platform, spec.request_filters)
      local transponder = place_transponder_for_platform(platform, force, state)
      result.requester_assigned = assigned_requests
      result.requester_error = request_error
      result.requester_source = request_source
      result.transponder_unit_number = transponder and transponder.valid and transponder.unit_number or nil
      local platform_state = {
        index = platform.index,
        name = platform.name,
        surface_name = platform.surface.name,
        hub_unit_number = platform.hub.unit_number,
        transponder_unit_number = result.transponder_unit_number,
      }
      state.platforms[platform.index] = platform_state
      state.platforms[platform.name] = platform_state

      if not assigned_requests or not result.transponder_unit_number then
        all_ready = false
      end
    else
      all_ready = false
      result.requester_assigned = false
      result.requester_error = platform and platform.valid and "hub-not-ready" or "missing-platform"
      result.transponder_unit_number = nil
    end

    results[#results + 1] = result
  end

  return all_ready, results
end

local function service_runtime(limit)
  if not remote.interfaces["exotic-industries-qc"] then
    return false, "missing-remote"
  end

  local ok, result = pcall(remote.call, "exotic-industries-qc", "service_orbital_logistics_qc", limit)
  return ok, ok and result or tostring(result)
end

local function rebuild_runtime()
  if not remote.interfaces["exotic-industries-qc"] then
    return false, "missing-remote"
  end

  local ok, result = pcall(remote.call, "exotic-industries-qc", "rebuild_orbital_logistics_runtime")
  return ok, ok and result or tostring(result)
end

local function get_orbital_runtime_module()
  return package.loaded["scripts/control/orbital-logistics"] or rawget(_G, "orbital_logistics")
end

local function get_qc_player()
  for _, player in pairs(game.players or {}) do
    if player and player.valid then
      return player
    end
  end

  return nil
end

local function get_qc_gui_root(player)
  if not (player and player.valid and player.gui) then
    return nil
  end

  return (player.gui.relative and player.gui.relative["ei-orbital-logistics-console"])
    or (player.gui.screen and player.gui.screen["ei-orbital-logistics-console"])
    or nil
end

local function close_qc_gui(player, runtime, tick)
  local root = get_qc_gui_root(player)
  if root and root.valid and script and script.raise_event then
    pcall(script.raise_event, defines.events.on_gui_closed, {
      tick = tick,
      player_index = player.index,
      gui_type = defines.gui_type.custom,
      element = root,
    })
  end

  if runtime and runtime.close_gui then
    pcall(runtime.close_gui, player)
  end

  if player and player.valid then
    pcall(function()
      player.opened = nil
    end)
  end
end

local function find_entity_by_unit_number(force, entity_name, unit_number)
  if not (force and force.valid and entity_name and unit_number) then
    return nil
  end

  for _, surface in pairs(game.surfaces or {}) do
    for _, entity in ipairs(surface.find_entities_filtered({name = entity_name, force = force})) do
      if entity.valid and entity.unit_number == unit_number then
        return entity
      end
    end
  end

  return nil
end

local function get_gui_probe_target(state, force, key)
  if key == "transponder_alpha" then
    local platform = state.platforms and state.platforms["QC Alpha"] or nil
    local unit_number = platform and platform.transponder_unit_number or nil
    local entity = find_entity_by_unit_number(force, "ei-platform-transponder", unit_number)
    return entity, unit_number
  end

  local unit_number = state.entity_units and state.entity_units[key] or nil
  local definition = GROUND_ENTITIES[key]
  local entity = definition and find_ground_entity(ensure_surface(SURFACE_NAME), force, key, unit_number) or nil
  return entity, unit_number
end

local function collect_gui_smoke(state, tick)
  local runtime = get_orbital_runtime_module()
  local player = get_qc_player()
  local force = get_force()
  local results = {
    available = runtime ~= nil and player ~= nil,
    runtime_present = runtime ~= nil,
    player_present = player ~= nil,
    probes = {},
  }

  if not (runtime and player and force) then
    return results
  end

  for _, key in ipairs({"transponder_alpha", "selector_a", "coordinator", "uplink_a"}) do
    local entity, expected_unit_number = get_gui_probe_target(state, force, key)
    local probe = {
      key = key,
      expected_unit_number = expected_unit_number,
      entity_name = entity and entity.valid and entity.name or nil,
      unit_number = entity and entity.valid and entity.unit_number or nil,
      found = entity ~= nil,
    }

    if entity and entity.valid then
      pcall(function()
        player.teleport(entity.position, entity.surface)
      end)

      close_qc_gui(player, runtime, tick)
      pcall(function()
        player.opened = entity
      end)

      local route_ok, route_result = false, "missing-script-raise-event"
      if script and script.raise_event then
        route_ok, route_result = pcall(script.raise_event, defines.events.on_gui_opened, {
          tick = tick,
          player_index = player.index,
          gui_type = defines.gui_type.entity,
          entity = entity,
        })
      end

      local root = get_qc_gui_root(player)
      probe.route_event_ok = route_ok
      probe.route_event_result = route_ok and "raised" or tostring(route_result)
      probe.opened = root ~= nil and root.valid or false
      probe.gui_mode = root and root.valid and root.tags and root.tags.gui_mode or nil
      probe.summary_present = root and root.valid and root.body and root.body.summary and root.body.summary.valid or false
      probe.details_present = root and root.valid and root.body and root.body.details and root.body.details.valid or false
      probe.hint_present = root and root.valid and root.body and root.body.hint and root.body.hint.valid or false

      if root and root.valid and root.body then
        if entity.name == "ei-platform-transponder" then
          probe.controls_ok = root.body["override-flow"] and root.body["override-flow"].valid or false
        elseif entity.name == "ei-orbital-selector" then
          probe.controls_ok = (root.body["mode-flow"] and root.body["mode-flow"].valid or false)
            and (root.body["focus-flow"] and root.body["focus-flow"].valid or false)
            and (root.body["release-selector-lease"] and root.body["release-selector-lease"].valid or false)
        elseif entity.name == "ei-orbital-coordinator" then
          probe.controls_ok = (root.body["coordinator-flow"] and root.body["coordinator-flow"].valid or false)
            and (root.body["coordinator-flow"]["refresh-cohort"] and root.body["coordinator-flow"]["refresh-cohort"].valid or false)
        elseif entity.name == "ei-orbital-dispatch-uplink" then
          probe.controls_ok = (root.body["silo-dropdown"] and root.body["silo-dropdown"].valid or false)
            and (root.body["binding-flow"] and root.body["binding-flow"].valid or false)
            and (root.body["oversize-flow"] and root.body["oversize-flow"].valid or false)
            and (root.body["threshold-flow"] and root.body["threshold-flow"].valid or false)
        else
          probe.controls_ok = false
        end
      else
        probe.controls_ok = false
      end

      close_qc_gui(player, runtime, tick)
    else
      probe.route_event_ok = false
      probe.route_event_result = "missing-entity"
      probe.opened = false
      probe.controls_ok = false
      probe.summary_present = false
      probe.details_present = false
      probe.hint_present = false
    end

    results.probes[#results.probes + 1] = probe
  end

  return results
end

local function validate_gui_smoke(gui_smoke)
  local validation = {
    ok = true,
    skipped = false,
    errors = {},
    summary = {
      available = gui_smoke and gui_smoke.available or false,
      runtime_present = gui_smoke and gui_smoke.runtime_present or false,
      player_present = gui_smoke and gui_smoke.player_present or false,
      probe_count = gui_smoke and gui_smoke.probes and #gui_smoke.probes or 0,
    },
  }

  if not validation.summary.runtime_present then
    validation.ok = false
    validation.errors[#validation.errors + 1] = "runtime-missing"
    return validation
  end

  if not validation.summary.player_present then
    validation.skipped = true
    validation.summary.skip_reason = "missing-player"
    return validation
  end

  for _, probe in ipairs(gui_smoke and gui_smoke.probes or {}) do
    if not probe.found then
      validation.errors[#validation.errors + 1] = "probe-missing:" .. tostring(probe.key)
    end
    if not probe.opened then
      validation.errors[#validation.errors + 1] = "gui-not-opened:" .. tostring(probe.key)
    end
    if not probe.summary_present then
      validation.errors[#validation.errors + 1] = "summary-missing:" .. tostring(probe.key)
    end
    if not probe.details_present then
      validation.errors[#validation.errors + 1] = "details-missing:" .. tostring(probe.key)
    end
    if not probe.hint_present then
      validation.errors[#validation.errors + 1] = "hint-missing:" .. tostring(probe.key)
    end
    if not probe.controls_ok then
      validation.errors[#validation.errors + 1] = "controls-missing:" .. tostring(probe.key)
    end
  end

  validation.ok = #validation.errors == 0
  return validation
end

local function collect_runtime_snapshot(checkpoint_name, tick, state)
  local service_ok, service_result = service_runtime(256)
  local snapshot_ok, snapshot = false, nil
  local remote_status = collect_remote_status()
  local gui_smoke = collect_gui_smoke(state or ensure_state(), tick)

  if remote.interfaces["exotic-industries-qc"] then
    snapshot_ok, snapshot = pcall(remote.call, "exotic-industries-qc", "get_orbital_logistics_qc_snapshot")
  end

  return {
    kind = "checkpoint",
    checkpoint = checkpoint_name,
    tick = tick,
    remote = remote_status,
    service_ok = service_ok,
    service_result = service_result,
    gui_smoke = gui_smoke,
    gui_validation = validate_gui_smoke(gui_smoke),
    baseline_validation = snapshot_ok and validate_snapshot_baseline(snapshot, state or ensure_state()) or {
      ok = false,
      errors = {"snapshot-unavailable"},
      summary = {},
    },
    snapshot_ok = snapshot_ok,
    snapshot = snapshot_ok and snapshot or tostring(snapshot),
  }
end

local function build_platform_id_map(snapshot, force_index)
  local platform_ids = {}
  for _, transponder in ipairs(snapshot and snapshot.transponders or {}) do
    if transponder.force_index == force_index
      and transponder.dispatch_surface_name == SURFACE_NAME
      and transponder.platform_name
      and transponder.platform_id
    then
      platform_ids[transponder.platform_name] = transponder.platform_id
    end
  end
  return platform_ids
end

local function configure_partial(config)
  if not remote.interfaces["exotic-industries-qc"] then
    return false, "missing-remote"
  end

  local ok, result = pcall(remote.call, "exotic-industries-qc", "configure_orbital_logistics_qc", config)
  return ok, ok and result or tostring(result)
end

local function get_snapshot_cohort(snapshot, force_index, surface_name)
  for _, cohort in ipairs(snapshot and snapshot.cohorts or {}) do
    if cohort.force_index == force_index and cohort.surface_name == surface_name then
      return cohort
    end
  end

  return nil
end

local function get_snapshot_job(snapshot, force_index, surface_name, selector_unit_number)
  local cohort = get_snapshot_cohort(snapshot, force_index, surface_name)
  for _, job in ipairs(cohort and cohort.jobs or {}) do
    if job.selector_unit_number == selector_unit_number then
      return job
    end
  end

  return nil
end

local function get_snapshot_uplink(snapshot, unit_number)
  for _, uplink in ipairs(snapshot and snapshot.uplinks or {}) do
    if uplink.unit_number == unit_number then
      return uplink
    end
  end

  return nil
end

local function get_snapshot_transponder(snapshot, force_index, platform_name)
  for _, transponder in ipairs(snapshot and snapshot.transponders or {}) do
    if transponder.force_index == force_index and transponder.platform_name == platform_name then
      return transponder
    end
  end

  return nil
end

local function get_snapshot_active_coordinator_unit_number(snapshot, force_index, surface_name)
  local cohort = get_snapshot_cohort(snapshot, force_index, surface_name)
  return cohort and cohort.active_coordinator_unit_number or nil
end

local function get_uplink_lease_target_platform_id(snapshot, uplink_unit_number)
  for _, lease in ipairs(snapshot and snapshot.leases or {}) do
    if lease.uplink_unit_number == uplink_unit_number then
      return lease.target_platform_id
    end
  end

  return nil
end

local function get_blocked_lane_reason(snapshot, force_index, surface_name, uplink_unit_number)
  local cohort = get_snapshot_cohort(snapshot, force_index, surface_name)
  for _, lane in ipairs(cohort and cohort.blocked_lanes or {}) do
    if lane.uplink_unit_number == uplink_unit_number then
      return lane.reason
    end
  end

  return nil
end

local function get_platform_spec_by_name(name)
  for _, spec in ipairs(PLATFORM_SPECS) do
    if spec.name == name then
      return spec
    end
  end

  return nil
end

local function push_validation_error(validation, message)
  validation.errors[#validation.errors + 1] = message
end

local function validate_snapshot_baseline(snapshot, state)
  local force = get_force()
  local force_index = force and force.index or nil
  local validation = {
    ok = false,
    errors = {},
    summary = {
      cohort_present = false,
      dispatch_transponder_count = 0,
      selector_count = 0,
      coordinator_count = 0,
      uplink_count = 0,
      dirty_queue_length = snapshot and snapshot.runtime and snapshot.runtime.queues and snapshot.runtime.queues.dirty and snapshot.runtime.queues.dirty.length or nil,
      rescan_queue_length = snapshot and snapshot.runtime and snapshot.runtime.queues and snapshot.runtime.queues.rescan and snapshot.runtime.queues.rescan.length or nil,
      transponder_force_bucket_count = snapshot and snapshot.runtime and snapshot.runtime.indexes and snapshot.runtime.indexes.transponder_force_bucket_count or nil,
      transponder_force_member_count = snapshot and snapshot.runtime and snapshot.runtime.indexes and snapshot.runtime.indexes.transponder_force_member_count or nil,
      transponder_platform_bucket_count = snapshot and snapshot.runtime and snapshot.runtime.indexes and snapshot.runtime.indexes.transponder_platform_bucket_count or nil,
      transponder_platform_member_count = snapshot and snapshot.runtime and snapshot.runtime.indexes and snapshot.runtime.indexes.transponder_platform_member_count or nil,
      transponder_dispatch_bucket_count = snapshot and snapshot.runtime and snapshot.runtime.indexes and snapshot.runtime.indexes.transponder_dispatch_surface_bucket_count or nil,
      transponder_dispatch_member_count = snapshot and snapshot.runtime and snapshot.runtime.indexes and snapshot.runtime.indexes.transponder_dispatch_surface_member_count or nil,
    },
  }

  local cohort = get_snapshot_cohort(snapshot, force_index, SURFACE_NAME)
  validation.summary.cohort_present = cohort ~= nil
  if not cohort then
    push_validation_error(validation, "missing-cohort")
  end

  local expected_platform_count = #PLATFORM_SPECS
  local seen_platform_ids = {}
  for _, transponder in ipairs(snapshot and snapshot.transponders or {}) do
    if transponder.force_index == force_index and transponder.dispatch_surface_name == SURFACE_NAME then
      validation.summary.dispatch_transponder_count = validation.summary.dispatch_transponder_count + 1

      if not transponder.platform_id then
        push_validation_error(validation, "missing-platform-id:" .. tostring(transponder.platform_name or transponder.unit_number))
      elseif seen_platform_ids[transponder.platform_id] then
        push_validation_error(validation, "duplicate-platform-id:" .. tostring(transponder.platform_id))
      else
        seen_platform_ids[transponder.platform_id] = true
      end

      local spec = get_platform_spec_by_name(transponder.platform_name)
      if not spec then
        push_validation_error(validation, "unexpected-platform:" .. tostring(transponder.platform_name))
      else
        local expected_filter_count = #(spec.request_filters or {})
        if not (transponder.scanner_requests and transponder.scanner_requests.ok) then
          push_validation_error(validation, "requests-bridge-failed:" .. tostring(transponder.platform_name))
        elseif transponder.scanner_requests.filter_count ~= expected_filter_count then
          push_validation_error(validation, "requests-filter-count:" .. tostring(transponder.platform_name) .. ":" .. tostring(transponder.scanner_requests.filter_count) .. "/" .. tostring(expected_filter_count))
        end

        if not (transponder.scanner_need and transponder.scanner_need.ok) then
          push_validation_error(validation, "need-bridge-failed:" .. tostring(transponder.platform_name))
        elseif transponder.scanner_need.filter_count ~= expected_filter_count then
          push_validation_error(validation, "need-filter-count:" .. tostring(transponder.platform_name) .. ":" .. tostring(transponder.scanner_need.filter_count) .. "/" .. tostring(expected_filter_count))
        end
      end
    end
  end

  if validation.summary.dispatch_transponder_count ~= expected_platform_count then
    push_validation_error(validation, "dispatch-transponder-count:" .. tostring(validation.summary.dispatch_transponder_count) .. "/" .. tostring(expected_platform_count))
  end

  for _, selector in ipairs(snapshot and snapshot.selectors or {}) do
    if selector.force_index == force_index and selector.surface_name == SURFACE_NAME then
      validation.summary.selector_count = validation.summary.selector_count + 1
    end
  end
  if validation.summary.selector_count ~= 3 then
    push_validation_error(validation, "selector-count:" .. tostring(validation.summary.selector_count) .. "/3")
  end

  for _, coordinator in ipairs(snapshot and snapshot.coordinators or {}) do
    if coordinator.force_index == force_index and coordinator.surface_name == SURFACE_NAME then
      validation.summary.coordinator_count = validation.summary.coordinator_count + 1
    end
  end
  if validation.summary.coordinator_count ~= 2 then
    push_validation_error(validation, "coordinator-count:" .. tostring(validation.summary.coordinator_count) .. "/2")
  end

  for _, uplink in ipairs(snapshot and snapshot.uplinks or {}) do
    if uplink.force_index == force_index and uplink.surface_name == SURFACE_NAME then
      validation.summary.uplink_count = validation.summary.uplink_count + 1
    end
  end
  if validation.summary.uplink_count ~= 2 then
    push_validation_error(validation, "uplink-count:" .. tostring(validation.summary.uplink_count) .. "/2")
  end

  if validation.summary.transponder_force_bucket_count ~= 1 then
    push_validation_error(validation, "transponder-force-buckets:" .. tostring(validation.summary.transponder_force_bucket_count) .. "/1")
  end
  if validation.summary.transponder_force_member_count ~= expected_platform_count then
    push_validation_error(validation, "transponder-force-members:" .. tostring(validation.summary.transponder_force_member_count) .. "/" .. tostring(expected_platform_count))
  end
  if validation.summary.transponder_platform_bucket_count ~= expected_platform_count then
    push_validation_error(validation, "transponder-platform-buckets:" .. tostring(validation.summary.transponder_platform_bucket_count) .. "/" .. tostring(expected_platform_count))
  end
  if validation.summary.transponder_platform_member_count ~= expected_platform_count then
    push_validation_error(validation, "transponder-platform-members:" .. tostring(validation.summary.transponder_platform_member_count) .. "/" .. tostring(expected_platform_count))
  end
  if validation.summary.transponder_dispatch_bucket_count ~= 1 then
    push_validation_error(validation, "transponder-dispatch-buckets:" .. tostring(validation.summary.transponder_dispatch_bucket_count) .. "/1")
  end
  if validation.summary.transponder_dispatch_member_count ~= expected_platform_count then
    push_validation_error(validation, "transponder-dispatch-members:" .. tostring(validation.summary.transponder_dispatch_member_count) .. "/" .. tostring(expected_platform_count))
  end

  if validation.summary.dirty_queue_length ~= 0 then
    push_validation_error(validation, "dirty-queue:" .. tostring(validation.summary.dirty_queue_length))
  end
  if validation.summary.rescan_queue_length ~= 0 then
    push_validation_error(validation, "rescan-queue:" .. tostring(validation.summary.rescan_queue_length))
  end
  if snapshot and snapshot.runtime and snapshot.runtime.pending_rescan then
    push_validation_error(validation, "pending-rescan")
  end

  validation.ok = #validation.errors == 0
  return validation
end

local function summarize_action_expectation(action_name, snapshot, state)
  local force = get_force()
  local force_index = force and force.index or nil
  local summary = {
    ok = false,
    lease_count = #(snapshot and snapshot.leases or {}),
  }

  if action_name == "duplicate-manual-target" then
    local selector_job = get_snapshot_job(snapshot, force_index, SURFACE_NAME, state.entity_units.selector_b)
    summary.selector_state = selector_job and selector_job.state or nil
    summary.blocked_reason = selector_job and selector_job.blocked_reason or nil
    summary.ok = summary.selector_state == "blocked"
      and summary.blocked_reason == "platform-busy"
      and summary.lease_count == 1
  elseif action_name == "restore-policy-selector" then
    local selector_job = get_snapshot_job(snapshot, force_index, SURFACE_NAME, state.entity_units.selector_b)
    summary.selector_state = selector_job and selector_job.state or nil
    summary.target_platform_id = selector_job and selector_job.target_platform_id or nil
    summary.ok = summary.selector_state == "ready" and summary.lease_count == 2
  elseif action_name == "destroy-active-coordinator" then
    summary.active_coordinator_unit_number = get_snapshot_active_coordinator_unit_number(snapshot, force_index, SURFACE_NAME)
    summary.ok = summary.active_coordinator_unit_number == state.entity_units.coordinator_b
      and summary.lease_count == 2
  elseif action_name == "invalid-manual-selector" then
    local selector_job = get_snapshot_job(snapshot, force_index, SURFACE_NAME, state.entity_units.selector_a)
    summary.selector_state = selector_job and selector_job.state or nil
    summary.invalid_reason = selector_job and selector_job.invalid_reason or nil
    summary.ok = summary.selector_state == "invalid" and summary.invalid_reason == "unknown-platform-id"
  elseif action_name == "restore-manual-selector" then
    local selector_a_job = get_snapshot_job(snapshot, force_index, SURFACE_NAME, state.entity_units.selector_a)
    local selector_b_job = get_snapshot_job(snapshot, force_index, SURFACE_NAME, state.entity_units.selector_b)
    summary.selector_a_state = selector_a_job and selector_a_job.state or nil
    summary.selector_a_target = selector_a_job and selector_a_job.target_platform_id or nil
    summary.selector_b_state = selector_b_job and selector_b_job.state or nil
    summary.selector_b_target = selector_b_job and selector_b_job.target_platform_id or nil
    summary.ok = summary.lease_count == 2
      and summary.selector_a_state == "ready"
      and summary.selector_a_target == state.platform_ids["QC Alpha"]
      and summary.selector_b_state == "ready"
      and summary.selector_b_target ~= nil
      and summary.selector_b_target ~= state.platform_ids["QC Alpha"]
  elseif action_name == "retarget-manual-selector" then
    local selector_a_job = get_snapshot_job(snapshot, force_index, SURFACE_NAME, state.entity_units.selector_a)
    local selector_b_job = get_snapshot_job(snapshot, force_index, SURFACE_NAME, state.entity_units.selector_b)
    summary.selector_a_state = selector_a_job and selector_a_job.state or nil
    summary.selector_a_target = selector_a_job and selector_a_job.target_platform_id or nil
    summary.selector_b_state = selector_b_job and selector_b_job.state or nil
    summary.selector_b_target = selector_b_job and selector_b_job.target_platform_id or nil
    summary.ok = summary.lease_count == 2
      and summary.selector_a_state == "ready"
      and summary.selector_a_target == state.platform_ids["QC Beta"]
      and summary.selector_b_state == "ready"
      and summary.selector_b_target == state.platform_ids["QC Alpha"]
  elseif action_name == "destroy-silo-b" or action_name == "rebuild-silo-b" then
    local uplink = get_snapshot_uplink(snapshot, state.entity_units.uplink_b)
    summary.binding_silo_unit_number = uplink and uplink.binding_silo_unit_number or nil
    summary.bound_silo_found = uplink and uplink.bound_silo_found or false
    summary.leased_job_id = uplink and uplink.leased_job_id or nil
    summary.blocked_reason = get_blocked_lane_reason(snapshot, force_index, SURFACE_NAME, state.entity_units.uplink_b)
    summary.ok = summary.binding_silo_unit_number == nil
      and summary.bound_silo_found == false
      and summary.leased_job_id == nil
      and summary.blocked_reason == "missing-silo-binding"
  elseif action_name == "rebind-uplink-b" then
    local uplink = get_snapshot_uplink(snapshot, state.entity_units.uplink_b)
    summary.binding_silo_unit_number = uplink and uplink.binding_silo_unit_number or nil
    summary.bound_silo_found = uplink and uplink.bound_silo_found or false
    summary.leased_job_id = uplink and uplink.leased_job_id or nil
    summary.ok = summary.binding_silo_unit_number == state.entity_units.silo_b
      and summary.bound_silo_found == true
      and summary.leased_job_id ~= nil
  elseif action_name == "prepare-fairness-rotation" then
    local selector_a_job = get_snapshot_job(snapshot, force_index, SURFACE_NAME, state.entity_units.selector_a)
    local selector_b_job = get_snapshot_job(snapshot, force_index, SURFACE_NAME, state.entity_units.selector_b)
    local selector_c_job = get_snapshot_job(snapshot, force_index, SURFACE_NAME, state.entity_units.selector_c)
    summary.selector_a_target = selector_a_job and selector_a_job.target_platform_id or nil
    summary.selector_b_target = selector_b_job and selector_b_job.target_platform_id or nil
    summary.selector_c_target = selector_c_job and selector_c_job.target_platform_id or nil
    summary.selector_c_state = selector_c_job and selector_c_job.state or nil
    summary.uplink_b_target = get_uplink_lease_target_platform_id(snapshot, state.entity_units.uplink_b)
    summary.ok = summary.lease_count == 2
      and summary.selector_a_target == state.platform_ids["QC Alpha"]
      and summary.selector_b_target == state.platform_ids["QC Beta"]
      and summary.selector_c_state == "ready"
      and summary.selector_c_target == state.platform_ids["QC Gamma"]
      and summary.uplink_b_target == state.platform_ids["QC Beta"]
  elseif action_name == "clear-fairness-lane" or action_name == "clear-fairness-lane-again" then
    local uplink = get_snapshot_uplink(snapshot, state.entity_units.uplink_b)
    summary.binding_silo_unit_number = uplink and uplink.binding_silo_unit_number or nil
    summary.bound_silo_found = uplink and uplink.bound_silo_found or false
    summary.leased_job_id = uplink and uplink.leased_job_id or nil
    summary.blocked_reason = get_blocked_lane_reason(snapshot, force_index, SURFACE_NAME, state.entity_units.uplink_b)
    summary.ok = summary.binding_silo_unit_number == nil
      and summary.bound_silo_found == false
      and summary.leased_job_id == nil
      and summary.blocked_reason == "missing-silo-binding"
  elseif action_name == "rebind-fairness-lane-first" then
    local uplink = get_snapshot_uplink(snapshot, state.entity_units.uplink_b)
    summary.binding_silo_unit_number = uplink and uplink.binding_silo_unit_number or nil
    summary.bound_silo_found = uplink and uplink.bound_silo_found or false
    summary.uplink_b_target = get_uplink_lease_target_platform_id(snapshot, state.entity_units.uplink_b)
    summary.ok = summary.binding_silo_unit_number == state.entity_units.silo_b
      and summary.bound_silo_found == true
      and summary.uplink_b_target == state.platform_ids["QC Gamma"]
  elseif action_name == "rebind-fairness-lane-second" then
    local uplink = get_snapshot_uplink(snapshot, state.entity_units.uplink_b)
    summary.binding_silo_unit_number = uplink and uplink.binding_silo_unit_number or nil
    summary.bound_silo_found = uplink and uplink.bound_silo_found or false
    summary.uplink_b_target = get_uplink_lease_target_platform_id(snapshot, state.entity_units.uplink_b)
    summary.ok = summary.binding_silo_unit_number == state.entity_units.silo_b
      and summary.bound_silo_found == true
      and summary.uplink_b_target == state.platform_ids["QC Beta"]
  elseif action_name == "create-transponder-conflict" then
    local alpha = get_snapshot_transponder(snapshot, force_index, "QC Alpha")
    local beta = get_snapshot_transponder(snapshot, force_index, "QC Beta")
    summary.alpha_platform_id = alpha and alpha.platform_id or nil
    summary.beta_platform_id = beta and beta.platform_id or nil
    summary.alpha_conflict = alpha and alpha.conflict or false
    summary.beta_conflict = beta and beta.conflict or false
    summary.ok = summary.alpha_platform_id ~= nil
      and summary.alpha_platform_id == summary.beta_platform_id
      and summary.alpha_conflict == true
      and summary.beta_conflict == true
  elseif action_name == "restore-transponder-ids" then
    local alpha = get_snapshot_transponder(snapshot, force_index, "QC Alpha")
    local beta = get_snapshot_transponder(snapshot, force_index, "QC Beta")
    summary.alpha_platform_id = alpha and alpha.platform_id or nil
    summary.beta_platform_id = beta and beta.platform_id or nil
    summary.alpha_conflict = alpha and alpha.conflict or false
    summary.beta_conflict = beta and beta.conflict or false
    summary.ok = summary.alpha_platform_id == state.platform_ids["QC Alpha"]
      and summary.beta_platform_id == state.platform_ids["QC Beta"]
      and summary.alpha_conflict == false
      and summary.beta_conflict == false
  end

  return summary
end

local function build_action_configuration(action_name, state)
  local platform_ids = state.platform_ids or {}

  if action_name == "duplicate-manual-target" then
    if not platform_ids["QC Alpha"] then
      return nil, "missing-platform-id:QC Alpha"
    end
    return {
      selectors = {
        {
          unit_number = state.entity_units.selector_b,
          mode = "manual",
          manual_platform_id = platform_ids["QC Alpha"],
        },
      },
    }
  end

  if action_name == "restore-policy-selector" then
    return {
      selectors = {
        {
          unit_number = state.entity_units.selector_b,
          mode = "policy",
          manual_platform_id = false,
        },
      },
    }
  end

  if action_name == "prepare-fairness-rotation" then
    if not platform_ids["QC Alpha"] or not platform_ids["QC Beta"] then
      return nil, "missing-platform-id:fairness-bootstrap"
    end

    return {
      selectors = {
        {
          unit_number = state.entity_units.selector_a,
          mode = "manual",
          manual_platform_id = platform_ids["QC Alpha"],
        },
        {
          unit_number = state.entity_units.selector_b,
          mode = "manual",
          manual_platform_id = platform_ids["QC Beta"],
        },
        {
          unit_number = state.entity_units.selector_c,
          mode = "policy",
          manual_platform_id = false,
        },
      },
      uplinks = {
        {
          unit_number = state.entity_units.uplink_b,
          binding_silo_unit_number = state.entity_units.silo_b,
          binding_source = "qc",
        },
      },
    }
  end

  if action_name == "invalid-manual-selector" then
    return {
      selectors = {
        {
          unit_number = state.entity_units.selector_a,
          mode = "manual",
          manual_platform_id = 999999,
        },
      },
    }
  end

  if action_name == "restore-manual-selector" then
    if not platform_ids["QC Alpha"] then
      return nil, "missing-platform-id:QC Alpha"
    end
    return {
      selectors = {
        {
          unit_number = state.entity_units.selector_a,
          mode = "manual",
          manual_platform_id = platform_ids["QC Alpha"],
        },
      },
    }
  end

  if action_name == "retarget-manual-selector" then
    if not platform_ids["QC Beta"] then
      return nil, "missing-platform-id:QC Beta"
    end
    return {
      selectors = {
        {
          unit_number = state.entity_units.selector_a,
          mode = "manual",
          manual_platform_id = platform_ids["QC Beta"],
        },
      },
    }
  end

  if action_name == "rebind-uplink-b" then
    return {
      uplinks = {
        {
          unit_number = state.entity_units.uplink_b,
          binding_silo_unit_number = state.entity_units.silo_b,
          binding_source = "qc",
        },
      },
    }
  end

  if action_name == "clear-fairness-lane" or action_name == "clear-fairness-lane-again" then
    return {
      uplinks = {
        {
          unit_number = state.entity_units.uplink_b,
          binding_silo_unit_number = false,
          binding_source = "qc",
        },
      },
    }
  end

  if action_name == "rebind-fairness-lane-first" then
    return {
      selectors = {
        {
          unit_number = state.entity_units.selector_b,
          mode = "policy",
          manual_platform_id = false,
        },
        {
          unit_number = state.entity_units.selector_c,
          mode = "policy",
          manual_platform_id = false,
        },
      },
      uplinks = {
        {
          unit_number = state.entity_units.uplink_b,
          binding_silo_unit_number = state.entity_units.silo_b,
          binding_source = "qc",
        },
      },
    }
  end

  if action_name == "rebind-fairness-lane-second" then
    return {
      uplinks = {
        {
          unit_number = state.entity_units.uplink_b,
          binding_silo_unit_number = state.entity_units.silo_b,
          binding_source = "qc",
        },
      },
    }
  end

  if action_name == "create-transponder-conflict" then
    local alpha_platform = state.platforms and state.platforms["QC Alpha"] or nil
    local beta_platform = state.platforms and state.platforms["QC Beta"] or nil
    if not alpha_platform or not beta_platform or not platform_ids["QC Alpha"] then
      return nil, "missing-platform-state:transponder-conflict"
    end
    return {
      transponders = {
        {
          unit_number = alpha_platform.transponder_unit_number,
          platform_id = platform_ids["QC Alpha"],
        },
        {
          unit_number = beta_platform.transponder_unit_number,
          platform_id = platform_ids["QC Alpha"],
        },
      },
    }
  end

  if action_name == "restore-transponder-ids" then
    local alpha_platform = state.platforms and state.platforms["QC Alpha"] or nil
    local beta_platform = state.platforms and state.platforms["QC Beta"] or nil
    if not alpha_platform or not beta_platform or not platform_ids["QC Alpha"] or not platform_ids["QC Beta"] then
      return nil, "missing-platform-state:transponder-restore"
    end
    return {
      transponders = {
        {
          unit_number = alpha_platform.transponder_unit_number,
          platform_id = platform_ids["QC Alpha"],
        },
        {
          unit_number = beta_platform.transponder_unit_number,
          platform_id = platform_ids["QC Beta"],
        },
      },
    }
  end

  return nil, "unknown-action"
end

local function perform_action(action_name, state)
  local force = get_force()
  local surface = ensure_surface(SURFACE_NAME)

  if action_name == "destroy-active-coordinator" then
    local ok, result, details = destroy_ground_entity(surface, force, state, "coordinator")
    return ok, result, details
  end

  if action_name == "destroy-silo-b" then
    local ok, result, details = destroy_ground_entity(surface, force, state, "silo_b")
    return ok, result, details
  end

  if action_name == "rebuild-silo-b" then
    local ok, result, details = rebuild_ground_entity(surface, force, state, "silo_b")
    return ok, result, details
  end

  local config, build_error = build_action_configuration(action_name, state)
  if not config then
    return false, build_error or "missing-config", nil
  end

  local ok, result = configure_partial(config)
  return ok, ok and result or tostring(result), config
end

local function configure_runtime(force, state, current_tick)
  current_tick = current_tick or game.tick
  state.configure_attempts = (state.configure_attempts or 0) + 1

  local remote_status = collect_remote_status()
  if not remote_status.present then
    state.next_configure_tick = current_tick + CONFIGURE_RETRY_INTERVAL
    write_record({
      kind = "configured",
      tick = current_tick,
      attempt = state.configure_attempts,
      remote = remote_status,
      rebuild_ok = false,
      rebuild_result = "missing-remote",
      warm_service_ok = false,
      warm_service_result = "missing-remote",
      initial_snapshot_ok = false,
      initial_snapshot = "nil",
      platform_ids = state.platform_ids or {},
      config_ok = false,
      config_result = "missing-remote",
      post_service_ok = false,
      post_service_result = "missing-remote",
      post_snapshot_ok = false,
      post_snapshot = "nil",
    })
    return false
  end

  local rebuild_ok, rebuild_result = rebuild_runtime()
  local warm_service_ok, warm_service_result = service_runtime(256)
  local snapshot_ok, snapshot = false, nil

  if remote.interfaces["exotic-industries-qc"] then
    snapshot_ok, snapshot = pcall(remote.call, "exotic-industries-qc", "get_orbital_logistics_qc_snapshot")
  end

  local platform_ids = snapshot_ok and build_platform_id_map(snapshot, force.index) or {}
  local initial_validation = snapshot_ok and validate_snapshot_baseline(snapshot, state) or nil
  state.platform_ids = platform_ids

  local config_ok, config_result = false, "missing-remote"
  if remote.interfaces["exotic-industries-qc"] then
    config_ok, config_result = pcall(remote.call, "exotic-industries-qc", "configure_orbital_logistics_qc", {
      selectors = {
        {
          unit_number = state.entity_units.selector_a,
          mode = "manual",
          manual_platform_id = platform_ids["QC Alpha"],
        },
        {
          unit_number = state.entity_units.selector_b,
          mode = "policy",
          manual_platform_id = false,
        },
        {
          unit_number = state.entity_units.selector_c,
          mode = "manual",
          manual_platform_id = false,
        },
      },
      uplinks = {
        {
          unit_number = state.entity_units.uplink_a,
          binding_silo_unit_number = state.entity_units.silo_a,
          binding_source = "qc",
          oversize_mode = "sticky",
        },
        {
          unit_number = state.entity_units.uplink_b,
          binding_silo_unit_number = state.entity_units.silo_b,
          binding_source = "qc",
          oversize_mode = "threshold",
          threshold_floor = 40,
        },
      },
    })
  end

  local post_service_ok, post_service_result = service_runtime(256)
  local post_snapshot_ok, post_snapshot = false, nil
  if remote.interfaces["exotic-industries-qc"] then
    post_snapshot_ok, post_snapshot = pcall(remote.call, "exotic-industries-qc", "get_orbital_logistics_qc_snapshot")
  end
  local post_validation = post_snapshot_ok and validate_snapshot_baseline(post_snapshot, state) or nil

  state.configured = config_ok and post_snapshot_ok
  if state.configured then
    -- The initial build path already performs the first full configure. Keep
    -- the delayed rearm only as a fallback for late remote registration.
    state.needs_runtime_rearm = false
  end
  state.next_configure_tick = state.configured and current_tick or (current_tick + CONFIGURE_RETRY_INTERVAL)

  write_record({
    kind = "configured",
    tick = current_tick,
    attempt = state.configure_attempts,
    remote = remote_status,
    rebuild_ok = rebuild_ok,
    rebuild_result = rebuild_result,
    warm_service_ok = warm_service_ok,
    warm_service_result = warm_service_result,
    initial_snapshot_ok = snapshot_ok,
    initial_snapshot = snapshot_ok and snapshot or tostring(snapshot),
    initial_validation = initial_validation,
    platform_ids = platform_ids,
    config_ok = config_ok,
    config_result = config_ok and config_result or tostring(config_result),
    post_service_ok = post_service_ok,
    post_service_result = post_service_result,
    post_snapshot_ok = post_snapshot_ok,
    post_snapshot = post_snapshot_ok and post_snapshot or tostring(post_snapshot),
    post_validation = post_validation,
  })

  return state.configured
end

local function build_scenario(current_tick)
  local state = ensure_state()
  local force = get_force()
  local surface = ensure_surface(SURFACE_NAME)
  current_tick = current_tick or game.tick

  clear_build_area(surface)
  state.entity_units = {}
  state.platforms = {}
  state.platform_ids = {}

  place_ground_layout(surface, force, state)
  state.platform_creation = create_platforms(force)
  state.built = true
  state.platforms_ready = false
  state.configured = false
  state.needs_runtime_rearm = true
  state.platform_prime_attempts = 0
  state.configure_attempts = 0
  state.base_tick = current_tick
  state.next_configure_tick = current_tick + 2
  state.checkpoint_index = 1
  state.action_index = 1

  write_record({
    kind = "build",
    tick = current_tick,
    surface = surface.name,
    origin = ORIGIN,
    force = force.name,
    entity_units = state.entity_units,
    platforms = state.platform_creation,
  })

  local ready, results = prime_platforms(force, state)
  state.platforms_ready = ready
  write_record({
    kind = "platform-prime",
    tick = current_tick,
    attempt = state.platform_prime_attempts,
    ready = ready,
    results = results,
  })

  if state.platforms_ready then
    configure_runtime(force, state, current_tick)
  end
end

local function run_due_actions(current_tick)
  local state = ensure_state()
  if not state.built or not state.platforms_ready or not state.configured then
    return
  end

  local next_index = state.action_index
  local action = ACTIONS[next_index]
  while action and current_tick >= state.base_tick + action.tick do
    local action_ok, action_result, action_payload = perform_action(action.name, state)
    local post = collect_runtime_snapshot("after-" .. action.name, current_tick, state)
    local expectation = nil

    if post.snapshot_ok and type(post.snapshot) == "table" then
      expectation = summarize_action_expectation(action.name, post.snapshot, state)
    end

    write_record({
      kind = "action",
      action = action.name,
      tick = current_tick,
      config = action_payload,
      config_ok = action_ok,
      config_result = action_result,
      post = post,
      expectation = expectation,
    })

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
  current_tick = current_tick or game.tick

  if not state.platforms_ready and current_tick >= state.base_tick + 1 then
    local ready, results = prime_platforms(get_force(), state)
    state.platforms_ready = ready
    if ready or state.platform_prime_attempts <= 3 or (state.platform_prime_attempts % 60) == 0 then
      write_record({
        kind = "platform-prime",
        tick = current_tick,
        attempt = state.platform_prime_attempts,
        ready = ready,
        results = results,
      })
    end
  end

  if state.platforms_ready
    and not state.configured
    and current_tick >= (state.next_configure_tick or (state.base_tick + 2))
  then
    configure_runtime(get_force(), state, current_tick)
  end

  if state.needs_runtime_rearm and current_tick >= state.base_tick + 1 then
    state.needs_runtime_rearm = false
    if not state.platforms_ready then
      local ready, results = prime_platforms(get_force(), state)
      state.platforms_ready = ready
      write_record({
        kind = "platform-prime",
        tick = current_tick,
        attempt = state.platform_prime_attempts,
        ready = ready,
        results = results,
      })
    end

    if state.platforms_ready then
      configure_runtime(get_force(), state, current_tick)
    end
  end

  run_due_actions(current_tick)

  local next_index = state.checkpoint_index
  local checkpoint_tick = CHECKPOINTS[next_index]
  while checkpoint_tick and current_tick >= state.base_tick + checkpoint_tick do
    local checkpoint_name = "t+" .. tostring(checkpoint_tick)
    write_record(collect_runtime_snapshot(checkpoint_name, current_tick, state))
    state.checkpoint_index = next_index + 1
    next_index = state.checkpoint_index
    checkpoint_tick = CHECKPOINTS[next_index]
  end
end

script.on_init(function()
  build_scenario(game.tick)
end)

script.on_configuration_changed(function(event)
  build_scenario(event and event.tick or game.tick)
end)

script.on_event(defines.events.on_tick, function(event)
  run_due_checkpoints(event.tick)
end)
