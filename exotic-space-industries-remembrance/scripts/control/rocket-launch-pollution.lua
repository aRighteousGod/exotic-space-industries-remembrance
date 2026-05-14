--==============================================================================
-- ESIR FILE MAP
-- owns: rocket launch pollution queues and effects
-- loaded_by: exotic-space-industries-remembrance\control.lua
-- cadence: launch ordered, launch completed, and every-tick updates
-- forwarded_events: on_rocket_launch_ordered, on_rocket_launched, updater
-- storage_roots: storage.ei
-- gui_ids: none
-- remote_interfaces: none
-- rebuild_on: startup setting changes, configuration changes
--==============================================================================
--[[
Rocket launch pollution scaling (config-driven, multiple curve options)

Why this exists:
- A flat pollution amount on rocket launch can feel wrong across progression.
- Early launches may be too punishing (or too trivial).
- Late launches may stop mattering once the player outscales the threat.
- This lets you choose a scaling curve that matches your desired pacing.

Supported modes:
  "linear"      -> predictable, steady increase with evolution
  "quadratic"   -> softer early game, stronger late game ramp
  "exponential" -> very gentle early, sharp late spike (tunable with exp_k)
  "threshold"   -> staged jumps at evo breakpoints (good for "phase shifts")
  "hybrid"      -> linear baseline + extra late-game bonus (usually best feel)

Evolution factor is typically in [0, 1], but we clamp anyway for safety.
]]
local ei_lib = require("lib/lib")
local ei_runtime_scheduler = require("lib/runtime-scheduler")
local model = {}
local ROCKET_LAUNCH_CONFIRM_GRACE_TICKS = 120
local try_form_retaliation

--====================================================================================================
--GAIA
--====================================================================================================
local rocket_pollution_config = {
  -- Select which scaling curve to use.
  -- Swap this string to change behavior without touching the logic below.
  mode = "linear", -- "linear", "quadratic", "exponential", "threshold", "hybrid"

  -- Base pollution emitted before scaling is applied.
  -- Final pollution = base * (mode-specific scale)
  base = 10000,

  -- Minimum scaling floor used by several modes.
  -- Prevents evo=0 launches from being effectively "free."
  -- Example: 0.1 means minimum 10% of base pollution.
  min_scale = 0.1,

  -- Exponential mode steepness.
  -- Higher values push more of the difficulty into late evolution.
  -- k=3 is a moderate curve; k=5 is much sharper.
  exp_k = 3,

  -- Threshold mode:
  -- These are checked in order, and the first matching evo ceiling is used.
  -- Think of each entry as: "if evo < this, use this multiplier".
  --
  -- Example with defaults:
  -- evo 0.00..0.19 -> 0.15x base
  -- evo 0.20..0.49 -> 0.35x base
  -- evo 0.50..0.79 -> 0.65x base
  -- evo 0.80..1.00 -> 1.20x base
  thresholds = {
    { evo = 0.2, scale = 0.15 },
    { evo = 0.4, scale = 0.25 },
    { evo = 0.55, scale = 0.4 },
    { evo = 0.8, scale = 0.65 },
    { evo = 0.9, scale = 0.9 },
    { evo = 0.95, scale = 1 },
    { evo = 1.1, scale = 1.20 }, -- catch-all (1.1 ensures evo=1.0 matches)
  },

  -- Hybrid mode:
  -- Starts as mostly linear scaling, then adds a bonus after late_start.
  -- Great when you want launches to feel fair early but dangerous later.
  hybrid = {
    -- Evolution point where the late bonus begins.
    -- Before this point, only the linear baseline matters.
    late_start = 0.6,

    -- Maximum additional multiplier added by the bonus at evo=1.
    -- Example: 0.5 means up to +50% on top of the linear component.
    late_bonus_max = 0.5,

    -- Shapes the bonus ramp:
    -- 1 = linear bonus
    -- 2 = quadratic bonus (smoother start, stronger finish)
    -- 3+ = even more backloaded
    late_power = 2,
  }
}

local function ensure_launch_state(current_tick)
  current_tick = current_tick or 0
  storage.ei = storage.ei or {}
  storage.ei.rocket_launch_pollution = storage.ei.rocket_launch_pollution or {}

  local state = storage.ei.rocket_launch_pollution
  state.launch_smoke = state.launch_smoke or {}
  state.pending_launches_by_silo = state.pending_launches_by_silo or {}
  state.pending_launch_cleanup_buckets = ei_runtime_scheduler.ensure_delayed_buckets(state.pending_launch_cleanup_buckets)

  -- Older saves may still carry predicted liftoff queues from the pre-confirmation path.
  -- Migrate them into pending launches so the actual `on_rocket_launched` event becomes
  -- the sole authority for whether the pollution consequence fires.
  if state.liftoff_queue and #state.liftoff_queue > 0 then
    for _, job in ipairs(state.liftoff_queue) do
      local expected_tick = job.tick or current_tick
      if expected_tick < current_tick then
        expected_tick = current_tick
      end
      if job.silo_unit_number then
        job.tick = expected_tick
        job.expected_tick = expected_tick
        state.pending_launches_by_silo[job.silo_unit_number] = job
        ei_runtime_scheduler.delayed_schedule(
          state.pending_launch_cleanup_buckets,
          expected_tick + ROCKET_LAUNCH_CONFIRM_GRACE_TICKS,
          {silo_unit_number = job.silo_unit_number, expected_tick = expected_tick}
        )
      end
    end
    state.liftoff_queue = {}
  end

  if state.liftoff_buckets then
    for due_tick, bucket in pairs(state.liftoff_buckets) do
      for _, job in pairs(bucket) do
        if type(job) == "table" and job.silo_unit_number then
          local expected_tick = job.tick or due_tick or current_tick
          if expected_tick < current_tick then
            expected_tick = current_tick
          end
          job.tick = expected_tick
          job.expected_tick = expected_tick
          state.pending_launches_by_silo[job.silo_unit_number] = job
          ei_runtime_scheduler.delayed_schedule(
            state.pending_launch_cleanup_buckets,
            expected_tick + ROCKET_LAUNCH_CONFIRM_GRACE_TICKS,
            {silo_unit_number = job.silo_unit_number, expected_tick = expected_tick}
          )
        end
      end
    end
    state.liftoff_buckets = {}
  end

  return state
end

local function queue_pending_launch(job, current_tick)
  if not (job and job.silo_unit_number) then
    return
  end

  local state = ensure_launch_state(current_tick)
  local expected_tick = job.tick or current_tick
  if expected_tick < current_tick then
    expected_tick = current_tick
  end

  job.tick = expected_tick
  job.expected_tick = expected_tick
  state.pending_launches_by_silo[job.silo_unit_number] = job
  ei_runtime_scheduler.delayed_schedule(
    state.pending_launch_cleanup_buckets,
    expected_tick + ROCKET_LAUNCH_CONFIRM_GRACE_TICKS,
    {silo_unit_number = job.silo_unit_number, expected_tick = expected_tick}
  )
  ei_runtime_scheduler.bump_counter("rocket-launch-pollution", "launch_ordered", 1)
end

-- Computes how much pollution a rocket launch should emit based on:
-- - force evolution factor on the current surface
-- - the configured scaling mode
local function get_rocket_launch_pollution(force, surface)
  local cfg = rocket_pollution_config

  -- Evolution factor is usually 0..1, but we guard against nil/out-of-range values.
  local evo = force.get_evolution_factor(surface) or 0
  evo = ei_lib.clamp(evo, 0, 1)

  local base = storage.ei.rocket_launch_pollution.cap
  local min_scale = cfg.min_scale
  local mode = storage.ei.rocket_launch_pollution.mode
  
  if not (base or min_scale or mode) then
    -- Fallback to safe defaults if config is missing for some reason.
    base = base or cfg.base
    min_scale = min_scale or 0.1
    mode = mode or cfg.mode
  end
  -- =========================
  -- MODE: LINEAR
  -- =========================
  if mode == "linear" then
    -- Scale directly with evolution:
    -- evo=0.0 -> min_scale (floor)
    -- evo=1.0 -> 1.0x base
    --
    -- Pros:
    -- - easy to reason about
    -- - predictable player experience
    -- - easiest to balance
    local scale = math.max(min_scale, evo)
    return base * scale

  -- =========================
  -- MODE: QUADRATIC
  -- =========================
  elseif mode == "quadratic" then
    -- Uses evo^2 to backload difficulty.
    -- This means early evo grows slowly, later evo grows much faster.
    --
    -- We normalize into [min_scale, 1.0]:
    -- scale = min_scale + (1 - min_scale) * (evo^2)
    --
    -- Examples with min_scale=0.1:
    -- evo=0.0 -> 0.1
    -- evo=0.5 -> 0.1 + 0.9*0.25 = 0.325
    -- evo=1.0 -> 1.0
    local scale = min_scale + (1 - min_scale) * (evo ^ 2)
    return base * scale

  -- =========================
  -- MODE: EXPONENTIAL
  -- =========================
  elseif mode == "exponential" then
    -- Stronger backloading than quadratic, but tunable.
    --
    -- We first compute a normalized exponential curve from 0..1:
    -- normalized = (e^(k*evo) - 1) / (e^k - 1)
    --
    -- Why normalize?
    -- - Guarantees normalized=0 at evo=0
    -- - Guarantees normalized=1 at evo=1
    --
    -- Then remap that into [min_scale, 1.0].
    local k = (cfg.exp_k and cfg.exp_k > 0) and cfg.exp_k or 3
    local normalized = (math.exp(k * evo) - 1) / (math.exp(k) - 1)
    local scale = min_scale + (1 - min_scale) * normalized
    return base * scale

  -- =========================
  -- MODE: THRESHOLD
  -- =========================
  elseif mode == "threshold" then
    -- Uses discrete "phase" jumps instead of a smooth curve.
    -- Great when you want progression to feel like crossing boundaries.
    --
    -- It checks the thresholds in order and returns the first match.
    -- Make sure the thresholds table is sorted ascending by `evo`.
    local thresholds = cfg.thresholds or {}
    for i = 1, #thresholds do
      local t = thresholds[i]
      if evo < t.evo then
        return base * t.scale
      end
    end

    -- Fallback in case thresholds is empty/malformed:
    return base * math.max(min_scale, evo)

  -- =========================
  -- MODE: HYBRID
  -- =========================
  elseif mode == "hybrid" then
    -- This mode combines:
    --   1) a linear baseline (so progression feels intuitive)
    --   2) a late-game bonus (so late launches regain danger)
    --
    -- This usually feels "best" in practice because:
    -- - early game isn't randomly spiky
    -- - mid game tracks expected evolution pressure
    -- - late game gets teeth again
    local h = cfg.hybrid or {}

    -- Clamp late_start so bad config values don't break the remap.
    local late_start = ei_lib.clamp(h.late_start or 0.6, 0, 1)

    local late_bonus_max = h.late_bonus_max or 0.5
    local late_power = h.late_power or 2

    -- Linear baseline keeps the curve intuitive.
    local linear = math.max(min_scale, evo)

    -- Bonus starts at 0 and ramps only after late_start.
    local late_bonus = 0

    if evo > late_start then
      -- Remap evo from [late_start, 1] -> [0, 1]
      -- We guard the denominator in case late_start=1.0.
      local denom = math.max(0.0001, 1 - late_start)
      local t = (evo - late_start) / denom

      -- Apply power shaping to control how fast the bonus ramps.
      -- t^2 = smoother entry, stronger finish.
      late_bonus = late_bonus_max * (t ^ late_power)
    end

    -- Final hybrid scale is baseline + bonus.
    -- Note: this can exceed 1.0 intentionally, which is the point.
    return base * (linear + late_bonus)

  else
    -- Safe fallback if mode string is invalid (typo, bad migration, etc.)
    return base * math.max(min_scale, evo)
  end
end
-- Spawn a visible, lingering smoke effect at the rocket silo launch site.
-- Spiral-lingering smoke: expands outward over time.
local function spawn_launch_smoke_spiral(surface, pos, pollution)
  local burst_count   = ei_lib.clamp(math.floor(pollution / 1500), 60, 240)
  local spiral_ticks  = ei_lib.clamp(math.floor(pollution / 180), 720, 4280)
  local emit_stride   = 8
  local per_emit      = ei_lib.clamp(math.floor(pollution / 6000), 20, 80)

  local start_radius  = 0.8
  local max_radius    = ei_lib.clamp(2.5 + pollution / 10000, 3.0, 15.0)
  local radius_step   = (max_radius - start_radius) / math.max(1, math.floor(spiral_ticks / emit_stride))
  local angle_step    = 0.55

  local SMOKE_NAME = "smoke"

  -- burst now (at liftoff)
  for i = 1, burst_count do
    surface.create_trivial_smoke{
      name = SMOKE_NAME,
      position = {
        x = pos.x + (math.random() - 0.5) * 3.0,
        y = pos.y + (math.random() - 0.5) * 3.0
      },
      starting_frame_deviation = math.random(0, 60),
    }
  end

  -- spiral job
  storage.ei.rocket_launch_pollution.launch_smoke = storage.ei.rocket_launch_pollution.launch_smoke or {}
  table.insert(storage.ei.rocket_launch_pollution.launch_smoke, {
    surface_index = surface.index,
    origin = { x = pos.x, y = pos.y },
    name = SMOKE_NAME,

    remaining = spiral_ticks,
    stride = emit_stride,
    per_emit = per_emit,

    angle = math.random() * math.pi * 2,
    angle_step = angle_step,

    radius = start_radius,
    radius_step = radius_step,

    jitter = 0.35,
  })
end

local function update_launch_smoke_spiral()
  local q = storage.ei.rocket_launch_pollution.launch_smoke
  if not (q and #q > 0) then return end

  for i = #q, 1, -1 do
    local job = q[i]
    job.remaining = job.remaining - 1

    if (job.remaining % job.stride) == 0 then
      local surface = game.surfaces[job.surface_index]
      if surface then
        job.angle = job.angle + job.angle_step
        job.radius = job.radius + job.radius_step

        local cx = job.origin.x + math.cos(job.angle) * job.radius
        local cy = job.origin.y + math.sin(job.angle) * job.radius

        for n = 1, job.per_emit do
          surface.create_trivial_smoke{
            name = job.name,
            position = {
              x = cx + (math.random() - 0.5) * job.jitter,
              y = cy + (math.random() - 0.5) * job.jitter
            },
            starting_frame_deviation = math.random(0, 60),
          }
        end
      end
    end

    if job.remaining <= 0 then
      table.remove(q, i)
    end
  end
end

local function apply_confirmed_launch(job)
  local surface = job and job.surface_index and game.surfaces[job.surface_index] or nil
  if not surface then
    return false
  end

  surface.pollute(job.position, job.pollution)
  spawn_launch_smoke_spiral(surface, job.position, job.pollution)
  try_form_retaliation(surface, job.position, job.pollution)
  ei_runtime_scheduler.bump_counter("rocket-launch-pollution", "liftoff_processed", 1)
  return true
end

local function is_impossible_difficulty()
  return storage
    and storage.ei
    and storage.ei.enemy_difficulty == "Impossible"
end

local function find_enemy_force()
  if not (game and game.forces) then
    return nil
  end

  local enemy_force = game.forces.enemy
  if enemy_force and enemy_force.valid then
    return enemy_force
  end

  return nil
end

local function sort_entities_by_distance(entities, origin)
  table.sort(entities, function(a, b)
    local ax = a.position.x - origin.x
    local ay = a.position.y - origin.y
    local bx = b.position.x - origin.x
    local by = b.position.y - origin.y
    return (ax * ax + ay * ay) < (bx * bx + by * by)
  end)
end

local function has_apex_launch_pressure(evo, pollution)
  local cap = rocket_pollution_config.base
  if storage and storage.ei and storage.ei.rocket_launch_pollution and storage.ei.rocket_launch_pollution.cap then
    cap = storage.ei.rocket_launch_pollution.cap
  end

  return evo >= 0.9 and pollution >= cap * 0.9
end

try_form_retaliation = function(surface, position, pollution)
  if not is_impossible_difficulty() then
    return false
  end

  local enemy_force = find_enemy_force()
  if not enemy_force then
    return false
  end

  local evo = enemy_force.get_evolution_factor(surface) or 0
  if evo <= 0 then
    return false
  end

  local radius = ei_lib.clamp(72 + pollution / 90 + evo * 48, 96, 256)
  local max_units = ei_lib.clamp(math.floor(6 + pollution / 900 + evo * 10), 8, 28)

  if has_apex_launch_pressure(evo, pollution) then
    radius = radius * 1.15
    max_units = ei_lib.clamp(math.floor(max_units * 1.25 + 0.5), 8, 36)
  end

  local nearby_units = surface.find_entities_filtered{
    position = position,
    radius = radius,
    force = enemy_force,
    type = "unit",
  }

  local nearby_spawners = surface.find_entities_filtered{
    position = position,
    radius = radius,
    force = enemy_force,
    type = "unit-spawner",
  }

  if (#nearby_units == 0 and #nearby_spawners == 0) or #nearby_units == 0 then
    return false
  end

  local valid_units = {}
  for _, unit in ipairs(nearby_units) do
    if unit and unit.valid then
      valid_units[#valid_units + 1] = unit
    end
  end

  if #valid_units == 0 then
    return false
  end

  sort_entities_by_distance(valid_units, position)

  local selected_units = {}
  for index = 1, math.min(max_units, #valid_units) do
    selected_units[#selected_units + 1] = valid_units[index]
  end

  if #selected_units == 0 then
    return false
  end

  local anchor_unit = selected_units[1]
  local unit_group = surface.create_unit_group{
    position = {x = anchor_unit.position.x, y = anchor_unit.position.y},
    force = enemy_force,
  }

  if not (unit_group and unit_group.valid) then
    return false
  end

  local added_units = 0
  for _, unit in ipairs(selected_units) do
    if unit and unit.valid then
      local ok = pcall(function()
        unit_group.add_member(unit)
      end)
      if ok then
        added_units = added_units + 1
      end
    end
  end

  if added_units == 0 then
    unit_group.destroy()
    return false
  end

  unit_group.set_command{
    type = defines.command.attack_area,
    destination = position,
    radius = 18,
    distraction = defines.distraction.by_enemy,
  }

  rendering.draw_text{
    text = "Enemy retaliation!",
    surface = surface,
    target = {x = position.x, y = position.y},
    color = {r = 1, g = 0.25, b = 0.25},
    scale = 1,
    alignment = "center",
    scale_with_zoom = false,
    time_to_live = 180,
  }

  return true
end

local function cleanup_stale_pending_launches(current_tick)
  local state = ensure_launch_state(current_tick)
  local due_entries = ei_runtime_scheduler.delayed_take_due_through(state.pending_launch_cleanup_buckets, current_tick)
  if #due_entries == 0 then return end

  for _, entry in ipairs(due_entries) do
    local pending = entry and entry.silo_unit_number and state.pending_launches_by_silo[entry.silo_unit_number] or nil
    if pending and pending.expected_tick == entry.expected_tick then
      state.pending_launches_by_silo[entry.silo_unit_number] = nil
      ei_runtime_scheduler.bump_counter("rocket-launch-pollution", "launch_canceled", 1)
    end
  end
end

function model.updater(event)
  if not (storage.ei and storage.ei.rocket_launch_pollution) then return end
  cleanup_stale_pending_launches(event.tick)
  update_launch_smoke_spiral()
end

local function queue_rocket_liftoff_wrath(silo, pollution, event)
  if not silo or not silo.valid then return end
  local surface = silo.surface
  local pos = silo.position

  -- Sync point: how long from “ordered” until the rocket actually launches.
  local delay = silo.prototype.launch_wait_time or 0

  storage.ei = storage.ei or {}
  storage.ei.rocket_launch_pollution = storage.ei.rocket_launch_pollution or {}

  queue_pending_launch({
    tick = event.tick + delay,
    surface_index = surface.index,
    position = { x = pos.x, y = pos.y },
    silo_unit_number = silo.unit_number,
    pollution = pollution,
  }, event.tick)
end

-- Event handler for rocket launches.
function model.on_rocket_launch_ordered(event)
  local silo = event.rocket_silo
  if not (silo and silo.valid) then return end

  local surface = silo.surface
  local force = silo.force
  if not (surface and surface.valid and force and force.valid) then return end

  -- Calculate pollution based on the configured scaling mode and current evolution.
  local pollution = get_rocket_launch_pollution(force, surface)
  queue_rocket_liftoff_wrath(silo, pollution, event)
end

function model.on_rocket_launched(event)
  local silo = event.rocket_silo
  if not (silo and silo.valid) then
    return
  end

  local surface = silo.surface
  local force = silo.force
  if not (surface and surface.valid and force and force.valid) then
    return
  end

  local state = ensure_launch_state(event.tick)
  local pending = silo.unit_number and state.pending_launches_by_silo[silo.unit_number] or nil
  if pending then
    state.pending_launches_by_silo[silo.unit_number] = nil
    pending.surface_index = surface.index
    pending.position = { x = silo.position.x, y = silo.position.y }
    pending.tick = event.tick
    apply_confirmed_launch(pending)
    return
  end

  -- Fallback for migration edge cases or external runtime interference that loses the
  -- ordered-launch record. Confirmed launches still get their pollution consequences.
  local pollution = get_rocket_launch_pollution(force, surface)
  apply_confirmed_launch({
    tick = event.tick,
    surface_index = surface.index,
    position = { x = silo.position.x, y = silo.position.y },
    silo_unit_number = silo.unit_number,
    pollution = pollution,
  })
  ei_runtime_scheduler.bump_counter("rocket-launch-pollution", "launch_untracked", 1)
end

function model.get_runtime_status()
  storage.ei = storage.ei or {}
  storage.ei.rocket_launch_pollution = storage.ei.rocket_launch_pollution or {}
  local state = ensure_launch_state(game and game.tick or 0)
  local status = {
    pending_launch_count = ei_runtime_scheduler.table_count(state.pending_launches_by_silo),
    pending_cleanup_bucket_count = ei_runtime_scheduler.delayed_bucket_count(state.pending_launch_cleanup_buckets),
    pending_cleanup_item_count = ei_runtime_scheduler.delayed_item_count(state.pending_launch_cleanup_buckets),
    legacy_liftoff_queue_count = #(storage.ei.rocket_launch_pollution.liftoff_queue or {}),
    active_smoke_jobs = #(state.launch_smoke or {}),
    pending_launches = ei_runtime_scheduler.table_count(state.pending_launches_by_silo),
    pending_cleanup_buckets = ei_runtime_scheduler.delayed_bucket_count(state.pending_launch_cleanup_buckets),
    pending_cleanup_items = ei_runtime_scheduler.delayed_item_count(state.pending_launch_cleanup_buckets),
    launch_smoke = #(state.launch_smoke or {}),
  }

  ei_runtime_scheduler.set_module_status("rocket-launch-pollution", status)
  return status
end

return model
