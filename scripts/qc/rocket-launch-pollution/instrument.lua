-- Appended only to the staged main control. Instrument actual native API calls.
local function qc_state()
  storage.rocket_pollution_qc = storage.rocket_pollution_qc or {surfaces = {}, configurations = {}}
  return storage.rocket_pollution_qc
end
local function surface_row(surface)
  local rows = qc_state().surfaces
  rows[surface.index] = rows[surface.index] or {particles = 0, emitted = 0, emissions = {}}
  return rows[surface.index]
end
function rocket_qc_smoke(surface)
  return function(spec)
    local row = surface_row(surface)
    row.particles = row.particles + 1
    surface.create_trivial_smoke(spec)
  end
end
function rocket_qc_pollute(surface, position, amount, source, tick)
  local before = surface.get_pollution(position)
  surface.pollute(position, amount, source)
  local row = surface_row(surface)
  assert(math.abs(surface.get_pollution(position) - before - amount) < .001, "Physical emission delta")
  row.emitted = row.emitted + amount
  row.emissions[#row.emissions + 1] = {tick = tick, amount = amount, total = row.emitted}
end
function rocket_qc_cancellation(launch, tick)
  log("ROCKET_QC CANCEL " .. helpers.table_to_json{tick = tick, surface = launch.surface_index,
    silo_valid = launch.silo and launch.silo.valid, rocket_valid = launch.rocket and launch.rocket.valid,
    phase = launch.silo and launch.silo.valid and launch.silo.rocket_silo_status,
    emitted = launch.emitted_pollution})
end
remote.add_interface("esir-rocket-pollution-qc", {
  configure = function(silo_id, style, cap, mode, scenario)
    qc_state().configurations[silo_id] = {style = style, cap = cap, mode = mode or "linear", scenario = scenario}
  end,
  snapshot = function(silo_id, surface_index, full)
    local state = storage.ei.rocket_launch_pollution
    local launch = state.pending_launches_by_silo[silo_id]
    local pending
    if launch then
      pending = {ordered_tick = launch.ordered_tick, ignition_tick = launch.ignition_tick,
        emitted = launch.emitted_pollution, total = launch.pollution, expected_tick = launch.expected_tick}
    end
    local smoke = 0
    for _, job in ipairs(state.launch_smoke) do
      if job.silo_unit_number == silo_id then smoke = smoke + 1 end
    end
    local activity = surface_row(game.surfaces[surface_index])
    local detached = 0
    for _, old in pairs(state.detached_launches) do
      if old.silo_unit_number == silo_id and not old.canceled then detached = detached + 1 end
    end
    return {pending = pending, smoke = smoke, detached = detached, activity = full and activity
      or {emitted = activity.emitted, particles = activity.particles}}
  end,
  repair = function(tick) ei_rocket_launch_pollution.repair_runtime_state("rocket-qc", tick) end,
  legacy = function(silo_id, kind)
    local state = storage.ei.rocket_launch_pollution
    local launch = state.pending_launches_by_silo[silo_id]
    assert(launch and launch.emitted_pollution == 0)
    launch.silo, launch.rocket, launch.ordered_tick, launch.emitted_pollution = nil, nil, nil, nil
    for _, job in ipairs(state.launch_smoke) do
      if job.silo_unit_number == silo_id then job.launch = nil end
    end
    if kind == "queue" then
      state.pending_launches_by_silo[silo_id] = nil
      state.liftoff_queue = {launch}
    elseif kind == "buckets" then
      state.pending_launches_by_silo[silo_id] = nil
      state.liftoff_buckets = {[launch.tick] = {launch}}
    end
    state.launch_state_version = nil
  end,
  forget = function(silo_id, preserve_smoke)
    local state = storage.ei.rocket_launch_pollution
    state.pending_launches_by_silo[silo_id] = nil
    if not preserve_smoke then
      for i = #state.launch_smoke, 1, -1 do
        if state.launch_smoke[i].silo_unit_number == silo_id then table.remove(state.launch_smoke, i) end
      end
      ei_rocket_launch_pollution.repair_runtime_state("rocket-qc-forget", game.tick)
    end
  end,
  overlap = function(silo, tick)
    local state = storage.ei.rocket_launch_pollution
    local original = state.pending_launches_by_silo[silo.unit_number]
    local paid = original.emitted_pollution
    assert(original.flight_started and original.rocket.valid)
    -- Inject external interference without forcing the native silo to rebuild
    -- while it still owns a rocket (which violates an engine assertion).
    local replacement = {valid = true, surface = silo.surface}
    ei_rocket_launch_pollution.on_rocket_launch_ordered{rocket_silo = silo, rocket = replacement, tick = tick}
    local newest = state.pending_launches_by_silo[silo.unit_number]
    assert(newest ~= original and state.detached_launches[silo.unit_number .. ":" .. original.ordered_tick] == original)
    ei_rocket_launch_pollution.updater{tick = tick}
    assert(newest.canceled and newest.emitted_pollution == 0 and original.emitted_pollution == paid)
    replacement.valid = false
    return true
  end,
  legacy_late = function(silo)
    local state = storage.ei.rocket_launch_pollution
    state.pending_launches_by_silo[silo.unit_number] = {silo_unit_number = silo.unit_number,
      surface_index = silo.surface.index, position = silo.position, pollution = 10000,
      tick = game.tick - 600, expected_tick = game.tick - 600}
    state.launch_state_version = nil
  end,
  idle = function(tick) return not ei_rocket_launch_pollution.has_tick_work{tick = tick} end,
  policy_checks = function(surface_index)
    local state = storage.ei.rocket_launch_pollution
    state.launch_smoke[#state.launch_smoke + 1] = {silo_unit_number = -1, kind = "spiral", next_tick = game.tick + 1}
    state.launch_state_version = nil
    ei_rocket_launch_pollution.repair_runtime_state("rocket-qc-orphan", game.tick)
    assert(#state.launch_smoke == 0, "legacy orphan smoke retired")
    local surface = game.surfaces[surface_index]
    local previous = storage.ei.enemy_difficulty
    storage.ei.enemy_difficulty = "Impossible"
    game.forces.enemy.set_evolution_factor(1, surface)
    local unit = surface.create_entity{name = "small-biter", position = {20, 10}, force = "enemy"}
    surface.peaceful_mode = true
    assert(not ei_rocket_launch_pollution._qc_retaliation(surface, {x = 0, y = 0}, 10000), "peaceful retaliation guard")
    surface.peaceful_mode = false; surface.no_enemies_mode = true
    assert(not ei_rocket_launch_pollution._qc_retaliation(surface, {x = 0, y = 0}, 10000), "no-enemies retaliation guard")
    surface.no_enemies_mode = false
    if not unit.valid then unit = surface.create_entity{name = "small-biter", position = {20, 10}, force = "enemy"} end
    assert(ei_rocket_launch_pollution._qc_retaliation(surface, {x = 0, y = 0}, 10000), "ordinary Impossible retaliation")
    unit.destroy(); storage.ei.enemy_difficulty = previous
    return true
  end,
})
local ordered = script.get_event_handler(defines.events.on_rocket_launch_ordered)
script.on_event(defines.events.on_rocket_launch_ordered, function(event)
  local config = qc_state().configurations[event.rocket_silo.unit_number]
  if config then
    local state = storage.ei.rocket_launch_pollution
    state.visual_style, state.cap, state.mode = config.style, config.cap, config.mode
  end
  ordered(event)
end)
local confirmed = script.get_event_handler(defines.events.on_rocket_launched)
script.on_event(defines.events.on_rocket_launched, function(event)
  local config = event.rocket_silo and qc_state().configurations[event.rocket_silo.unit_number]
  if config then
    local state = storage.ei.rocket_launch_pollution
    state.visual_style, state.cap, state.mode = config.style, config.cap, config.mode
    if config.scenario == "legacy-confirm" then
      local silo = event.rocket_silo
      state.pending_launches_by_silo[silo.unit_number] = {silo_unit_number = silo.unit_number,
        surface_index = silo.surface.index, position = silo.position, pollution = config.cap,
        tick = event.tick, expected_tick = event.tick}
      state.launch_state_version = nil
    end
  end
  local pending = event.rocket_silo and storage.ei.rocket_launch_pollution.pending_launches_by_silo[event.rocket_silo.unit_number]
  log("ROCKET_QC CONFIRM " .. helpers.table_to_json{tick = event.tick, surface = event.rocket.surface.index,
    position = event.rocket.position, silo_present = event.rocket_silo ~= nil,
    pending = pending ~= nil, same_rocket = pending and pending.rocket == event.rocket,
    emitted = pending and pending.emitted_pollution})
  if config and config.scenario == "no-silo" then
    confirmed{tick = event.tick, name = event.name, rocket = event.rocket}
  else
    confirmed(event)
  end
end)
