local SOURCE = "ei-rocket-launch-pollution"
local API = "esir-rocket-pollution-qc"
local function call(method, ...) return remote.call(API, method, ...) end
local function check(condition, message)
  assert(condition, "ROCKET_QC " .. message)
  storage.checks = (storage.checks or 0) + 1
end
local function close(a, b) return math.abs(a - b) < .002 end
local function prepare(silo)
  silo.rocket_parts = silo.prototype.rocket_parts_required
  silo.get_inventory(defines.inventory.rocket_silo_rocket).insert{name = "iron-plate", count = 1}
end
script.on_init(function()
  if remote.interfaces.freeplay then
    remote.call("freeplay", "set_skip_intro", true)
    remote.call("freeplay", "set_disable_crashsite", true)
  end
  game.map_settings.enemy_evolution.time_factor = 0
  game.map_settings.enemy_evolution.pollution_factor = 0
  game.speed = 16
  storage.cases, storage.by_id, storage.start, storage.checks = {}, {}, game.tick, 0
  local specs = {
    {"hybrid"}, {"plume"}, {"cinematic"}, {"spiral"},
    {"rocket-before", action = "rocket-before"}, {"silo-before", action = "silo-before"},
    {"silo-burning", action = "silo-burning"}, {"rocket-flying", action = "rocket-flying"},
    {"silo-detached", action = "silo-detached"},
    {"silo-tail", style = "spiral", cap = 200000, action = "silo-tail"},
    {"slow", prototype = "ei-rocket-qc-silo-slow"},
    {"fast", prototype = "ei-rocket-qc-silo-fast"},
    {"overlap", overlap = true},
    {"repeat", repeat_launch = true}, {"repair", repair = true},
    {"shared-surface", pair = true},
    {"legacy", legacy = "pending"}, {"legacy-queue", legacy = "queue"},
    {"legacy-buckets", legacy = "buckets"}, {"fallback", fallback = true},
    {"no-silo"}, {"legacy-confirm", fallback = true},
    {"legacy-late", fallback = true}, {"lost-index", lose_index = true},
    {"zero", cap = 0}, {"quadratic", mode = "quadratic"},
    {"exponential", mode = "exponential"}, {"threshold", mode = "threshold", expected = 12000},
    {"curve-hybrid", mode = "hybrid", expected = 15000},
  }
  for _, spec in ipairs(specs) do
    local surface = game.create_surface("rocket-qc-" .. spec[1], {width = 96, height = 96,
      autoplace_controls = {}, autoplace_settings = {entity = {treat_missing_as_default = false}}})
    surface.request_to_generate_chunks({0, 0}, 1); surface.force_generate_chunk_requests()
    local tiles = {}
    for x = -12, 32 do for y = -12, 12 do tiles[#tiles + 1] = {name = "refined-concrete", position = {x, y}} end end
    surface.set_tiles(tiles)
    surface.freeze_daytime = true; surface.daytime = .5
    game.forces.player.set_evolution_factor(1, surface)
    local silo = surface.create_entity{name = spec.prototype or "rocket-silo", position = {0, 0}, force = "player"}
    prepare(silo)
    spec.name, spec.silo, spec.id, spec.surface = spec[1], silo, silo.unit_number, surface
    spec.style = spec.style or ((spec[1] == "plume" or spec[1] == "cinematic" or spec[1] == "spiral") and spec[1] or "hybrid")
    spec.cap = spec.cap == nil and 10000 or spec.cap
    spec.expected = spec.expected or spec.cap
    if spec.pair then
      spec.second = surface.create_entity{name = "rocket-silo", position = {20, 0}, force = "player"}
      prepare(spec.second)
      storage.by_id[spec.second.unit_number] = spec
      spec.expected = spec.cap * 2
    end
    spec.events, spec.phases, spec.completed, spec.orders = {}, {}, 0, 0
    storage.cases[#storage.cases + 1] = spec; storage.by_id[spec.id] = spec
  end
end)
script.on_event(defines.events.on_rocket_launch_ordered, function(event)
  local row = storage.by_id[event.rocket_silo.unit_number]
  if not row then return end
  row.orders = row.orders + 1; row.order_tick = event.tick; row.rocket = event.rocket
  row.ignition_tick = nil
  row.graph_baseline = row.surface.pollution_statistics.get_input_count(SOURCE)
  row.particle_baseline = call("snapshot", row.id, row.surface.index).activity.particles
  row.events[#row.events + 1] = {name = "ordered", tick = event.tick}
end)
script.on_event(defines.events.on_rocket_launched, function(event)
  local row = event.rocket_silo and storage.by_id[event.rocket_silo.unit_number]
  if not row then for _, candidate in ipairs(storage.cases) do if candidate.rocket == event.rocket then row = candidate; break end end end
  if not row then return end
  row.completed = row.completed + 1; row.confirm_tick = event.tick
  row.events[#row.events + 1] = {name = "confirmed", tick = event.tick}
  local snap = call("snapshot", row.id, row.surface.index)
  if row.canceled then
    check(close(snap.activity.emitted, row.cancel_emitted), row.name .. " canceled confirmation cannot top up")
    return
  end
  if not row.pair or row.completed == 2 then
    check(close(snap.activity.emitted, row.expected * (row.pair and 1 or row.completed)), row.name .. " settled physical total " .. helpers.table_to_json(snap))
  end
end)
local function cancel(row, tick)
  local snap = call("snapshot", row.id, row.surface.index)
  row.canceled = tick; row.cancel_particles = snap.activity.particles; row.cancel_emitted = snap.activity.emitted
  if row.action:find("silo", 1, true) then row.silo.destroy() else row.rocket.destroy() end
end
script.on_event(defines.events.on_tick, function(event)
  if not storage.cases or storage.done then return end
  for _, row in ipairs(storage.cases) do
    local snap = call("snapshot", row.id, row.surface.index)
    local graph = row.surface.pollution_statistics.get_input_count(SOURCE)
    check(close(graph, snap.activity.emitted), row.name .. " graph equals physical emissions")
    if row.canceled then
      check(close(snap.activity.emitted, row.cancel_emitted), row.name .. " no emissions after cancel")
      check(snap.activity.particles == row.cancel_particles and snap.smoke == 0 and not snap.pending, row.name .. " no particles/jobs after cancel")
    elseif row.silo.valid then
      row.silo.energy = 1000000000
      if row.second then row.second.energy = 1000000000 end
      local phase = row.silo.rocket_silo_status
      if phase ~= row.phase then
        row.phase = phase
        row.phases[#row.phases + 1] = {tick = event.tick, status = phase,
          attached = row.silo.rocket ~= nil, rocket_valid = row.rocket and row.rocket.valid or false}
      end
      if phase == defines.rocket_silo_status.rocket_ready and row.orders < (row.repeat_launch and 2 or 1) then
        call("configure", row.id, row.style, row.cap, row.mode, row.name)
        check(row.silo.launch_rocket{type = defines.cargo_destination.orbit}, row.name .. " launch accepted")
        if row.second then
          call("configure", row.second.unit_number, row.style, row.cap, row.mode, row.name)
          check(row.second.launch_rocket{type = defines.cargo_destination.orbit}, "shared surface second launch accepted")
        end
      end
      if row.order_tick and row.completed < row.orders then
        local age = event.tick - row.order_tick
        if phase == defines.rocket_silo_status.engine_starting and not row.ignition_tick then
          row.ignition_tick = event.tick
          if not row.fallback and row.cap > 0 then
            check(snap.pending and snap.pending.ignition_tick == event.tick, row.name .. " ignition aligned tick=" .. event.tick .. " snapshot=" .. helpers.table_to_json(snap))
            check(close(snap.activity.emitted - row.graph_baseline, row.expected / 812), row.name .. " one ignition tick share")
          end
        end
        if not row.ignition_tick then
          check(close(graph, row.graph_baseline), row.name .. " no pre-ignition pollution")
          check(snap.activity.particles == row.particle_baseline, row.name .. " no pre-ignition particles")
        elseif not row.fallback and not row.index_lost then
          local sampled_age = math.floor((event.tick - row.ignition_tick) / 10) * 10
          local target = row.expected * math.min((sampled_age + 1) / 812, 1)
          check(close(graph - row.graph_baseline, target), row.name .. " cumulative ten-tick burn target")
        end
        if row.legacy and age == 30 then call("legacy", row.id, row.legacy) end
        if row.fallback and age == 30 then call("forget", row.id) end
        if row.name == "legacy-late" and phase == defines.rocket_silo_status.lights_blinking_close and not row.late_adopted then
          call("legacy_late", row.silo); row.late_adopted = true
        end
        if row.repair and row.ignition_tick and event.tick == row.ignition_tick + 40 then
          call("repair", event.tick)
          local repaired = call("snapshot", row.id, row.surface.index)
          check(repaired.pending.emitted == snap.pending.emitted and repaired.pending.ignition_tick == snap.pending.ignition_tick, "repair preserves accounting")
        end
        if row.lose_index and row.ignition_tick and event.tick == row.ignition_tick + 40 then
          call("forget", row.id, true); row.index_lost = true
        end
        if row.overlap and phase == defines.rocket_silo_status.rocket_flying and not row.overlap_seen then
          check(call("overlap", row.silo, event.tick), "overlap retains old ledger and rejects replacement identity")
          row.overlap_seen = true
        end
        if row.name == "slow" and age == 1400 then check(snap.pending ~= nil and graph > 0, "slow launch survives former deadline") end
        if row.action == "rocket-before" or row.action == "silo-before" then
          if age == 30 then cancel(row, event.tick) end
        elseif row.action == "silo-burning" and row.ignition_tick and event.tick == row.ignition_tick + 40 then
          check(graph > 0 and graph < row.expected, "partial burn before silo destruction"); cancel(row, event.tick)
        elseif row.action == "rocket-flying" and phase == defines.rocket_silo_status.rocket_flying then
          check(graph > 0 and graph < row.expected, "partial burn before rocket destruction"); cancel(row, event.tick)
        elseif row.action == "silo-detached" and phase == defines.rocket_silo_status.lights_blinking_close then
          check(row.rocket.valid, "detached rocket survives silo closure"); cancel(row, event.tick)
        end
      end
      if row.action == "silo-tail" and row.confirm_tick and event.tick == row.confirm_tick + 1 then
        check(snap.smoke > 0, "confirmed pad tail exists"); cancel(row, event.tick)
      end
      if row.repeat_launch and row.completed == 1 and phase == defines.rocket_silo_status.building_rocket and not row.reprepared then
        prepare(row.silo); row.reprepared = true
      end
    end
    if row.name == "hybrid" and game.is_multiplayer() then
      storage.checkpoints = storage.checkpoints or {}
      local checkpoint
      if row.order_tick and not row.ignition_tick and event.tick == row.order_tick + 30 then checkpoint = "before"
      elseif row.ignition_tick and event.tick == row.ignition_tick + 100 then checkpoint = "during"
      elseif row.confirm_tick and event.tick == row.confirm_tick + 1 then checkpoint = "after" end
      if checkpoint and not storage.checkpoints[checkpoint] then
        storage.checkpoints[checkpoint] = {tick = event.tick, emitted = snap.activity.emitted}
        game.server_save("rocket-" .. checkpoint)
      end
    end
  end
  if event.tick - storage.start >= 6000 then
    local report = {checks = storage.checks, cases = {}, all_pass = true, checkpoints = storage.checkpoints}
    for _, row in ipairs(storage.cases) do
      if row.overlap then check(row.overlap_seen, "injected overlap exercised") end
      if row.action then check(row.canceled ~= nil, row.name .. " cancel scenario ran")
      else check(row.completed == ((row.repeat_launch or row.pair) and 2 or 1), row.name .. " confirmations") end
      local snap = call("snapshot", row.id, row.surface.index, true)
      report.cases[#report.cases + 1] = {name = row.name, orders = row.orders, completed = row.completed,
        events = row.events, phases = row.phases, ignition_tick = row.ignition_tick,
        emitted = snap.activity.emitted, particles = snap.activity.particles, emissions = snap.activity.emissions}
    end
    check(call("idle", event.tick), "idle gate after all launches")
    check(call("policy_checks", storage.cases[1].surface.index), "native retaliation policies")
    report.checks = storage.checks
    helpers.write_file("rocket-pollution.json", helpers.table_to_json(report), false)
    log("ROCKET_POLLUTION_QC COMPLETE " .. report.checks)
    storage.done = true
  end
end)
