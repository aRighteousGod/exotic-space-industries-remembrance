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
local model = {}

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

local function update_rocket_liftoff_queue(event)
  local q = storage.ei
    and storage.ei.rocket_launch_pollution
    and storage.ei.rocket_launch_pollution.liftoff_queue

  if not (q and #q > 0) then return end

  local now = event.tick
  for i = #q, 1, -1 do
    local job = q[i]
    if job.tick <= now then
      local surface = game.surfaces[job.surface_index]
      if surface then
        -- Apply pollution at liftoff
        surface.pollute(job.position, job.pollution)

        --local msg = {"exotic-industries.rocket-launch-pollution", string.format("%.0f", job.pollution)}

        -- Spiral smoke at liftoff
        spawn_launch_smoke_spiral(surface, job.position, job.pollution)
      end

      table.remove(q, i)
    end
  end
end

function model.updater(event)
  if not (storage.ei and storage.ei.rocket_launch_pollution) then return end
  update_rocket_liftoff_queue(event)
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
  storage.ei.rocket_launch_pollution.liftoff_queue = storage.ei.rocket_launch_pollution.liftoff_queue or {}

  table.insert(storage.ei.rocket_launch_pollution.liftoff_queue, {
    tick = event.tick + delay,
    surface_index = surface.index,
    position = { x = pos.x, y = pos.y },
    silo_unit_number = silo.unit_number,
    pollution = pollution,
  })
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

-- Triggered whenever a rocket is launched from a silo.
function model.on_rocket_launched(event)
  local silo = event.rocket_silo

  -- Defensive guard:
  -- The event *should* provide a valid silo, but mods / edge cases / migration weirdness
  -- can happen, so fail safely.
  if not (silo and silo.valid) then return end

  local surface = silo.surface
  local force = silo.force
  if not (surface and surface.valid and force and force.valid) then return end

  -- Calculate pollution based on the configured scaling mode and current evolution.
  local pollution = get_rocket_launch_pollution(force, surface)

  -- Emit pollution at the silo's position on the same surface.
  surface.pollute(silo.position, pollution)

  local msg = pollution.." pollution emitted"
  ei_lib.crystal_echo_floating(
    msg,
    silo,
    1800,
    "wrath"
  )
  --local msg = {"exotic-industries.rocket-launch-pollution", pollution}

  -- Optional debug
  -- game.print(string.format(
  --   "[rocket pollution] mode=%s evo=%.3f pollution=%.1f surface=%s force=%s",
  --   rocket_pollution_config.mode,
  --   force.get_evolution_factor(surface) or -1,
  --   pollution,
  --   surface.name,
  --   force.name
  -- ))
end

return model