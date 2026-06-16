--==============================================================================
-- ESIR FILE MAP
-- owns: rocket launch pollution, launch retaliation, and visual smoke queues
-- loaded_by: exotic-space-industries-remembrance\control.lua
-- cadence: ordered-launch visual queueing, confirmed-launch consequences, and due-tick smoke/cleanup work
-- forwarded_events: has_tick_work, on_rocket_launch_ordered, on_rocket_launched, updater
-- storage_roots: storage.ei
-- gui_ids: none
-- remote_interfaces: none
-- rebuild_on: startup setting changes, configuration changes
--==============================================================================
--[[
Rocket launch pollution and visual exhaust lifecycle

This module deliberately splits launch order visuals from confirmed launch
gameplay consequences:

- on_rocket_launch_ordered computes the pollution amount, records the pending
  launch, and starts any selected smoke visuals.
- Pad exhaust ("spiral" and hybrid's reduced bloom) starts at
  silo.prototype.launch_wait_time. It is an annular ground effect around the
  launch well, with the center aperture and rocket column kept clear. When a
  plume is also enabled, pad exhaust tapers out and stops as that plume begins.
- The ascending plume starts later, after the plume ignition/lift-off delay, and
  is removed once the confirmed launch event arrives.
- on_rocket_launched is the only path that applies pollution and retaliation.
  Ordered-but-canceled launches keep their visual smoke bounded by stale cleanup
  and never emit gameplay pollution.
- has_tick_work gates runtime updates. Smoke jobs store next_tick summaries so
  idle periods do not run control work. Pad-exhaust jobs sleep between emission
  stride boundaries, but advance their remaining lifetime exactly as the old
  per-tick loop did before emitting.

Pollution scaling is config-driven and supports multiple curve options.

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
local ROCKET_LAUNCH_VISUAL_STYLE_DEFAULT = "hybrid"
local ROCKET_LAUNCH_VISUAL_STYLES = {
  hybrid = true,
  plume = true,
  cinematic = true,
  spiral = true,
}

local PLUME_SMOKE_NAME = "ei-rocket-launch-plume-smoke"
local PLUME_START_DELAY = 650
local PLUME_LIFT_OFF_DELAY = 40
local PLUME_ASCENT_START_DELAY = PLUME_START_DELAY + PLUME_LIFT_OFF_DELAY
local PLUME_INITIAL_SPEED = 0.000025
local PLUME_INITIAL_ACCELERATION = 0.000035
local PLUME_ACCELERATION_GROWTH = 0.00000065
local PLUME_ACCELERATION_EXPONENT = 1.55
local PLUME_MAX_SPEED = 1.8
local PLUME_MAX_TRAIL_TICKS = 1200
local PLUME_SMOKE_BUDGET_PER_TICK = 96
local PAD_EXHAUST_CENTER_OFFSET_Y = 0.55
local PAD_EXHAUST_APERTURE_RADIUS_X = 3.05
local PAD_EXHAUST_APERTURE_RADIUS_Y = 2.05
local PAD_EXHAUST_ROCKET_COLUMN_HALF_WIDTH = 2.3
local PAD_EXHAUST_ROCKET_COLUMN_NORTH = -4.0
local PAD_EXHAUST_ROCKET_COLUMN_SOUTH = 4.5
local PAD_EXHAUST_POSITION_ATTEMPTS = 10
local PAD_EXHAUST_ANGLE_NUDGE = math.pi / 10
local PAD_EXHAUST_TWO_PI = math.pi * 2
local PAD_EXHAUST_PLUME_HANDOFF_FADE_TICKS = 96
local LAUNCH_POLLUTION_TEXT_OFFSET_Y = -1.1
local LAUNCH_RETALIATION_TEXT_OFFSET_Y = 0.35
local try_form_retaliation

---@alias EiRocketLaunchVisualStyle "hybrid"|"plume"|"cinematic"|"spiral"

---@class EiRocketLaunchSmokeJob
---@field kind "plume"|"spiral"|nil
---@field silo_unit_number uint|nil
---@field surface_index uint
---@field origin MapPosition
---@field pollution number|nil
---@field ticks uint|nil
---@field visual_y number|nil
---@field current_speed number|nil
---@field density uint|nil
---@field emit_stride uint|nil
---@field next_tick uint|nil
---@field last_tick uint|nil
---@field expire_tick uint|nil
---@field burst_count uint|nil
---@field burst_pending boolean|nil
---@field name string|nil
---@field remaining uint|nil
---@field stride uint|nil
---@field per_emit uint|nil
---@field angle number|nil
---@field angle_step number|nil
---@field radius number|nil
---@field radius_step number|nil
---@field jitter number|nil
---@field stop_tick uint|nil
---@field fade_out_ticks uint|nil

---@class EiLaunchPadExhaustGeometry
---@field start_radius number
---@field burst_inner_radius number
---@field burst_outer_radius number
---@field radial_jitter number
---@field angle_jitter number

---@type EiLaunchPadExhaustGeometry
local PAD_EXHAUST_FULL_GEOMETRY = {
  start_radius = 3.2,
  burst_inner_radius = 3.2,
  burst_outer_radius = 4.75,
  radial_jitter = 0.45,
  angle_jitter = 0.14,
}

---@type EiLaunchPadExhaustGeometry
local PAD_EXHAUST_REDUCED_GEOMETRY = {
  start_radius = 3.05,
  burst_inner_radius = 3.05,
  burst_outer_radius = 3.9,
  radial_jitter = 0.28,
  angle_jitter = 0.10,
}

--====================================================================================================
-- POLLUTION CURVE CONFIG
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

local function count_bucket_items(bucket)
  local count = 0
  if type(bucket) ~= "table" then
    return count
  end

  for _ in pairs(bucket) do
    count = count + 1
  end

  return count
end

local function has_legacy_liftoff_work(state)
  return (type(state.liftoff_queue) == "table" and #state.liftoff_queue > 0)
      or (type(state.liftoff_buckets) == "table" and next(state.liftoff_buckets) ~= nil)
end

local function refresh_pending_cleanup_summary(state)
  local next_due_tick = 0
  local bucket_count = 0
  local item_count = 0

  for due_tick, bucket in pairs(state.pending_launch_cleanup_buckets or {}) do
    local numeric_due_tick = tonumber(due_tick)
    if numeric_due_tick and type(bucket) == "table" and next(bucket) ~= nil then
      bucket_count = bucket_count + 1
      item_count = item_count + count_bucket_items(bucket)
      if next_due_tick <= 0 or numeric_due_tick < next_due_tick then
        next_due_tick = numeric_due_tick
      end
    end
  end

  state.next_pending_cleanup_tick = next_due_tick
  state.pending_cleanup_bucket_count = bucket_count
  state.pending_cleanup_item_count = item_count
  return next_due_tick
end

local function remember_pending_cleanup_tick(state, due_tick)
  local numeric_due_tick = tonumber(due_tick)
  if not numeric_due_tick or numeric_due_tick <= 0 then
    return
  end

  local next_due_tick = tonumber(state.next_pending_cleanup_tick) or 0
  if next_due_tick <= 0 or numeric_due_tick < next_due_tick then
    state.next_pending_cleanup_tick = numeric_due_tick
  end
end

local function schedule_pending_cleanup(state, due_tick, entry)
  local created_bucket = state.pending_launch_cleanup_buckets[due_tick] == nil
  ei_runtime_scheduler.delayed_schedule(state.pending_launch_cleanup_buckets, due_tick, entry)
  remember_pending_cleanup_tick(state, due_tick)
  state.pending_cleanup_item_count = math.max(0, tonumber(state.pending_cleanup_item_count) or 0) + 1
  if created_bucket then
    state.pending_cleanup_bucket_count = math.max(0, tonumber(state.pending_cleanup_bucket_count) or 0) + 1
  end
end

---@param visual_style string|nil
---@return EiRocketLaunchVisualStyle
local function sanitize_visual_style(visual_style)
  if type(visual_style) == "string" and ROCKET_LAUNCH_VISUAL_STYLES[visual_style] then
    return visual_style
  end

  return ROCKET_LAUNCH_VISUAL_STYLE_DEFAULT
end

---@param state table|nil
---@return EiRocketLaunchVisualStyle
local function get_visual_style(state)
  return sanitize_visual_style(state and state.visual_style or nil)
end

---@param visual_style EiRocketLaunchVisualStyle
---@return boolean
local function visual_style_uses_plume(visual_style)
  return visual_style == "hybrid" or visual_style == "plume" or visual_style == "cinematic"
end

---@param visual_style EiRocketLaunchVisualStyle
---@return "full"|"reduced"|nil
local function get_pad_exhaust_profile(visual_style)
  if visual_style == "hybrid" then
    return "reduced"
  end

  if visual_style == "cinematic" or visual_style == "spiral" then
    return "full"
  end

  return nil
end

---@param tick number|nil
---@return uint|nil
local function normalize_smoke_tick(tick)
  local numeric_tick = tonumber(tick)
  if numeric_tick and numeric_tick > 0 then
    return math.floor(numeric_tick)
  end

  return nil
end

---@param next_tick uint|nil
---@param stop_tick uint|nil
---@return uint|nil
local function clamp_smoke_due_to_stop_tick(next_tick, stop_tick)
  if not stop_tick then
    return next_tick
  end

  if not next_tick or next_tick <= 0 or next_tick > stop_tick then
    return stop_tick
  end

  return next_tick
end

local function remember_launch_smoke_tick(state, due_tick)
  local numeric_due_tick = tonumber(due_tick)
  if not numeric_due_tick or numeric_due_tick <= 0 then
    return
  end

  numeric_due_tick = math.floor(numeric_due_tick)
  local next_tick = tonumber(state.next_launch_smoke_tick) or 0
  if next_tick <= 0 or numeric_due_tick < next_tick then
    state.next_launch_smoke_tick = numeric_due_tick
  end
end

local function get_launch_smoke_due_tick(job, current_tick)
  if type(job) ~= "table" then
    return nil
  end

  local stop_tick = normalize_smoke_tick(job.stop_tick)
  local next_tick = tonumber(job.next_tick)
  if next_tick and next_tick > 0 then
    return clamp_smoke_due_to_stop_tick(math.floor(next_tick), stop_tick)
  end

  if stop_tick then
    return stop_tick
  end

  -- Old saves may have smoke jobs that predate next_tick. Wake once so updater()
  -- can repair their cadence without losing the visual job.
  return current_tick
end

-- Spiral smoke emits from the old post-decrement `remaining % stride == 0`
-- cadence. Return the next tick where that old loop would have emitted or
-- ended so the scheduler can sleep through visually idle ticks.
---@param current_tick uint
---@param remaining number
---@param stride number
---@return uint|nil
local function get_next_spiral_due_tick(current_tick, remaining, stride)
  if remaining <= 0 then
    return nil
  end

  local ticks_until_emit = remaining % stride
  if ticks_until_emit <= 0 then
    ticks_until_emit = stride
  end

  return current_tick + math.max(1, math.min(remaining, ticks_until_emit))
end

local function refresh_launch_smoke_summary(state, current_tick)
  current_tick = current_tick or (game and game.tick) or 0
  local jobs = state.launch_smoke
  if type(jobs) ~= "table" then
    state.launch_smoke = {}
    state.launch_smoke_count = 0
    state.next_launch_smoke_tick = 0
    return 0, 0
  end

  local job_count = #jobs
  local next_tick = 0
  for index = 1, job_count do
    local due_tick = get_launch_smoke_due_tick(jobs[index], current_tick)
    if due_tick and (next_tick <= 0 or due_tick < next_tick) then
      next_tick = due_tick
    end
  end

  state.launch_smoke_count = job_count
  state.next_launch_smoke_tick = next_tick
  return job_count, next_tick
end

---@param state table
---@param silo_unit_number uint|nil
---@param kind "plume"|"spiral"|nil
---@return uint removed_count
local function remove_launch_smoke_jobs_for_silo(state, silo_unit_number, kind)
  if not silo_unit_number then
    return 0
  end

  local jobs = state.launch_smoke
  if type(jobs) ~= "table" then
    state.launch_smoke_count = 0
    return 0
  end

  local removed_count = 0
  local write_index = 1
  local job_count = #jobs
  for read_index = 1, job_count do
    local job = jobs[read_index]
    if type(job) == "table"
        and job.silo_unit_number == silo_unit_number
        and (kind == nil or job.kind == kind) then
      removed_count = removed_count + 1
    else
      if write_index ~= read_index then
        jobs[write_index] = job
      end
      write_index = write_index + 1
    end
  end

  for index = job_count, write_index, -1 do
    jobs[index] = nil
  end

  state.launch_smoke_count = #jobs
  if removed_count > 0 then
    refresh_launch_smoke_summary(state, game and game.tick or 0)
  end
  return removed_count
end

---@param state table
---@param silo_unit_number uint|nil
---@return uint removed_count
local function remove_plume_jobs_for_silo(state, silo_unit_number)
  return remove_launch_smoke_jobs_for_silo(state, silo_unit_number, "plume")
end

---@param state table
---@return uint plume_jobs
---@return uint spiral_jobs
local function count_launch_smoke_jobs(state)
  local plume_jobs = 0
  local spiral_jobs = 0
  for _, job in ipairs(state.launch_smoke or {}) do
    if type(job) == "table" and job.kind == "plume" then
      plume_jobs = plume_jobs + 1
    else
      spiral_jobs = spiral_jobs + 1
    end
  end

  return plume_jobs, spiral_jobs
end

local function ensure_launch_state(current_tick)
  current_tick = current_tick or 0
  storage.ei = storage.ei or {}
  storage.ei.rocket_launch_pollution = storage.ei.rocket_launch_pollution or {}

  local state = storage.ei.rocket_launch_pollution
  state.launch_smoke = state.launch_smoke or {}
  state.launch_smoke_count = state.launch_smoke_count or #state.launch_smoke
  if state.next_launch_smoke_tick == nil
      or ((tonumber(state.launch_smoke_count) or 0) > 0
          and (tonumber(state.next_launch_smoke_tick) or 0) <= 0) then
    refresh_launch_smoke_summary(state, current_tick)
  end
  state.visual_style = get_visual_style(state)
  state.pending_launches_by_silo = state.pending_launches_by_silo or {}
  state.pending_launch_cleanup_buckets = ei_runtime_scheduler.ensure_delayed_buckets(
    state.pending_launch_cleanup_buckets
  )
  if state.next_pending_cleanup_tick == nil
      or state.pending_cleanup_bucket_count == nil
      or state.pending_cleanup_item_count == nil
      or ((tonumber(state.pending_cleanup_item_count) or 0) > 0
          and (tonumber(state.next_pending_cleanup_tick) or 0) <= 0) then
    refresh_pending_cleanup_summary(state)
  end

  -- Older saves may still carry predicted liftoff queues from the pre-confirmation path.
  -- Migrate them into pending launches so the actual `on_rocket_launched` event becomes
  -- the sole authority for whether the pollution consequence fires.
  state.legacy_liftoff_work = has_legacy_liftoff_work(state)
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
        schedule_pending_cleanup(
          state,
          expected_tick + ROCKET_LAUNCH_CONFIRM_GRACE_TICKS,
          {silo_unit_number = job.silo_unit_number, expected_tick = expected_tick}
        )
      end
    end
    state.liftoff_queue = {}
    state.legacy_liftoff_work = has_legacy_liftoff_work(state)
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
          schedule_pending_cleanup(
            state,
            expected_tick + ROCKET_LAUNCH_CONFIRM_GRACE_TICKS,
            {silo_unit_number = job.silo_unit_number, expected_tick = expected_tick}
          )
        end
      end
    end
    state.liftoff_buckets = {}
    state.legacy_liftoff_work = false
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
  local cleanup_tick = math.max(
    expected_tick + ROCKET_LAUNCH_CONFIRM_GRACE_TICKS,
    tonumber(job.cleanup_tick) or 0
  )
  schedule_pending_cleanup(
    state,
    cleanup_tick,
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

---@param pollution number|nil
---@return uint
local function get_plume_smoke_density(pollution)
  local amount = math.max(0, tonumber(pollution) or 0)
  return ei_lib.clamp(math.ceil(amount / 4000), 2, 6)
end

---@param current_tick uint|number|nil
---@return uint
local function get_launch_plume_start_tick(current_tick)
  return math.max(0, math.floor(tonumber(current_tick) or 0)) + PLUME_ASCENT_START_DELAY
end

---@param state table
---@param surface LuaSurface
---@param pos MapPosition
---@param silo_unit_number uint
---@param pollution number
---@param current_tick uint
---@param skip_existing_clear boolean|nil
local function queue_launch_plume(state, surface, pos, silo_unit_number, pollution, current_tick, skip_existing_clear)
  if not skip_existing_clear then
    remove_plume_jobs_for_silo(state, silo_unit_number)
  end
  state.launch_smoke = state.launch_smoke or {}
  current_tick = math.max(0, math.floor(tonumber(current_tick) or 0))
  local start_tick = get_launch_plume_start_tick(current_tick)
  state.launch_smoke[#state.launch_smoke + 1] = {
    kind = "plume",
    silo_unit_number = silo_unit_number,
    surface_index = surface.index,
    origin = {x = pos.x, y = pos.y},
    pollution = pollution,
    ticks = 0,
    visual_y = pos.y,
    current_speed = PLUME_INITIAL_SPEED,
    density = get_plume_smoke_density(pollution),
    next_tick = start_tick,
    expire_tick = current_tick + PLUME_MAX_TRAIL_TICKS,
  }
  state.launch_smoke_count = #state.launch_smoke
  remember_launch_smoke_tick(state, start_tick)
end

---@param reduced boolean
---@return EiLaunchPadExhaustGeometry
local function get_pad_exhaust_geometry(reduced)
  return reduced and PAD_EXHAUST_REDUCED_GEOMETRY or PAD_EXHAUST_FULL_GEOMETRY
end

---@param stop_tick uint|nil
---@param fade_out_ticks uint|nil
---@param current_tick uint
---@return number
local function get_pad_exhaust_fade_scale(stop_tick, fade_out_ticks, current_tick)
  stop_tick = normalize_smoke_tick(stop_tick)
  if not stop_tick then
    return 1
  end

  if current_tick >= stop_tick then
    return 0
  end

  fade_out_ticks = math.max(0, math.floor(tonumber(fade_out_ticks) or 0))
  if fade_out_ticks <= 0 then
    return 1
  end

  local ticks_until_stop = stop_tick - current_tick
  if ticks_until_stop >= fade_out_ticks then
    return 1
  end

  return math.max(0, ticks_until_stop / fade_out_ticks)
end

---@param job EiRocketLaunchSmokeJob
---@param current_tick uint
---@return number
local function get_pad_exhaust_job_fade_scale(job, current_tick)
  return get_pad_exhaust_fade_scale(job.stop_tick, job.fade_out_ticks, current_tick)
end

---@param count number
---@param fade_scale number
---@param minimum_active_count uint
---@return uint
local function scale_pad_exhaust_emit_count(count, fade_scale, minimum_active_count)
  count = math.max(0, math.floor(tonumber(count) or 0))
  if count <= 0 or fade_scale <= 0 then
    return 0
  end

  if fade_scale >= 1 then
    return count
  end

  return math.min(count, math.max(minimum_active_count, math.ceil(count * fade_scale)))
end

---@param job EiRocketLaunchSmokeJob
---@return boolean
local function is_reduced_pad_exhaust_job(job)
  local stride = tonumber(job.stride) or 8
  if stride >= 12 then
    return true
  end

  local per_emit = tonumber(job.per_emit)
  return per_emit ~= nil and per_emit <= 16
end

---@param origin MapPosition
---@return number origin_x
---@return number origin_y
local function get_origin_xy(origin)
  return tonumber(origin.x or origin[1]) or 0, tonumber(origin.y or origin[2]) or 0
end

---@param angle number
---@return number
local function normalize_pad_exhaust_angle_delta(angle)
  return angle - PAD_EXHAUST_TWO_PI * math.floor((angle + math.pi) / PAD_EXHAUST_TWO_PI)
end

---@param origin MapPosition
---@param angle number
---@param radius number
---@return number x
---@return number y
local function get_pad_exhaust_position(origin, angle, radius)
  local origin_x, origin_y = get_origin_xy(origin)
  local center_x = origin_x
  local center_y = origin_y + PAD_EXHAUST_CENTER_OFFSET_Y
  return center_x + math.cos(angle) * radius, center_y + math.sin(angle) * radius
end

---@param origin MapPosition
---@param x number
---@param y number
---@return boolean
local function is_inside_pad_exhaust_aperture(origin, x, y)
  local origin_x, origin_y = get_origin_xy(origin)
  local dx = (x - origin_x) / PAD_EXHAUST_APERTURE_RADIUS_X
  local dy = (y - (origin_y + PAD_EXHAUST_CENTER_OFFSET_Y)) / PAD_EXHAUST_APERTURE_RADIUS_Y
  return (dx * dx + dy * dy) < 1
end

---@param origin MapPosition
---@param x number
---@param y number
---@return boolean
local function is_inside_rocket_column_exclusion(origin, x, y)
  local origin_x, origin_y = get_origin_xy(origin)
  local dx = x - origin_x
  local dy = y - origin_y
  return math.abs(dx) < PAD_EXHAUST_ROCKET_COLUMN_HALF_WIDTH
      and dy > PAD_EXHAUST_ROCKET_COLUMN_NORTH
      and dy < PAD_EXHAUST_ROCKET_COLUMN_SOUTH
end

---@param origin MapPosition
---@param x number
---@param y number
---@return boolean
local function is_pad_exhaust_position_blocked(origin, x, y)
  return is_inside_pad_exhaust_aperture(origin, x, y)
      or is_inside_rocket_column_exclusion(origin, x, y)
end

---@param angle number
---@param radius number
---@return number
local function snap_pad_exhaust_angle_to_side_arc(angle, radius)
  local side_center = math.cos(angle) >= 0 and 0 or math.pi
  local safe_radius = math.max(radius, PAD_EXHAUST_ROCKET_COLUMN_HALF_WIDTH + 0.001)
  local max_offset = math.acos(math.min(0.98, PAD_EXHAUST_ROCKET_COLUMN_HALF_WIDTH / safe_radius))
  local offset = normalize_pad_exhaust_angle_delta(angle - side_center)
  if offset > max_offset then
    offset = max_offset
  elseif offset < -max_offset then
    offset = -max_offset
  end

  return side_center + offset * 0.96
end

---@param origin MapPosition
---@param angle number
---@param radius number
---@return number x
---@return number y
local function resolve_pad_exhaust_position(origin, angle, radius)
  local x, y = get_pad_exhaust_position(origin, angle, radius)
  if not is_pad_exhaust_position_blocked(origin, x, y) then
    return x, y
  end

  for attempt = 1, PAD_EXHAUST_POSITION_ATTEMPTS do
    local step = math.ceil(attempt / 2) * PAD_EXHAUST_ANGLE_NUDGE
    local direction = (attempt % 2 == 1) and 1 or -1
    local nudged_angle = angle + direction * step
    x, y = get_pad_exhaust_position(origin, nudged_angle, radius)
    if not is_pad_exhaust_position_blocked(origin, x, y) then
      return x, y
    end
  end

  local side_angle = snap_pad_exhaust_angle_to_side_arc(angle, radius)
  x, y = get_pad_exhaust_position(origin, side_angle, radius)
  if not is_pad_exhaust_position_blocked(origin, x, y) then
    return x, y
  end

  side_angle = math.cos(angle) >= 0 and 0 or math.pi
  return get_pad_exhaust_position(origin, side_angle, radius)
end

---@param surface LuaSurface
---@param origin MapPosition
---@param smoke_name string
---@param angle number
---@param radius number
---@param geometry EiLaunchPadExhaustGeometry
---@param radial_jitter number|nil
local function emit_pad_exhaust_smoke(surface, origin, smoke_name, angle, radius, geometry, radial_jitter)
  local random = math.random
  local smoke_angle = angle + (random() - 0.5) * geometry.angle_jitter
  local smoke_radius = math.max(geometry.start_radius, radius)
      + random() * math.max(0, radial_jitter or geometry.radial_jitter)
  local x, y = resolve_pad_exhaust_position(origin, smoke_angle, smoke_radius)
  surface.create_trivial_smoke{
    name = smoke_name,
    position = {x = x, y = y},
    starting_frame_deviation = random(0, 60),
  }
end

---@param surface LuaSurface
---@param pos MapPosition
---@param burst_count uint
---@param smoke_name string
---@param geometry EiLaunchPadExhaustGeometry
local function emit_launch_spiral_burst(surface, pos, burst_count, smoke_name, geometry)
  local count = math.max(0, math.floor(tonumber(burst_count) or 0))
  if count <= 0 then
    return
  end

  local random = math.random
  local phase = random() * PAD_EXHAUST_TWO_PI
  local angle_step = PAD_EXHAUST_TWO_PI / count
  local radius_range = math.max(0, geometry.burst_outer_radius - geometry.burst_inner_radius)
  for index = 1, count do
    local angle = phase + (index - 1) * angle_step
    local radius = geometry.burst_inner_radius + random() * radius_range
    emit_pad_exhaust_smoke(surface, pos, smoke_name, angle, radius, geometry, 0)
  end
end

---@param surface LuaSurface
---@param job EiRocketLaunchSmokeJob
---@param geometry EiLaunchPadExhaustGeometry
---@param per_emit uint
local function emit_launch_spiral_pairs(surface, job, geometry, per_emit)
  local pair_count = math.max(1, math.ceil(per_emit / 2))
  local phase = tonumber(job.angle) or 0
  local radius = math.max(geometry.start_radius, tonumber(job.radius) or geometry.start_radius)
  local smoke_name = job.name or "smoke"
  local emitted = 0

  -- Paint opposing sectors every due tick so the pad reads as a venting ring,
  -- not a single smoke point orbiting through the rocket sprite.
  for pair_index = 0, pair_count - 1 do
    local angle = phase + pair_index * (math.pi / pair_count)
    emit_pad_exhaust_smoke(surface, job.origin, smoke_name, angle, radius, geometry, geometry.radial_jitter)
    emitted = emitted + 1
    if emitted >= per_emit then
      return
    end

    emit_pad_exhaust_smoke(surface, job.origin, smoke_name, angle + math.pi, radius, geometry, geometry.radial_jitter)
    emitted = emitted + 1
    if emitted >= per_emit then
      return
    end
  end
end

-- Queue a visible pad-exhaust effect at the rocket silo launch site. Full mode
-- keeps ESIR's original timing and density profile; reduced mode is hybrid's
-- milder annular pad bloom. When stop_tick is present, the pad exhaust fades
-- and then yields exactly as the ascending plume starts.
---@param surface LuaSurface
---@param pos MapPosition
---@param pollution number
---@param profile "full"|"reduced"|nil
---@param state table|nil
---@param current_tick uint|nil
---@param start_tick uint|nil
---@param silo_unit_number uint|nil
---@param stop_tick uint|nil
---@param fade_out_ticks uint|nil
local function spawn_launch_smoke_spiral(
    surface,
    pos,
    pollution,
    profile,
    state,
    current_tick,
    start_tick,
    silo_unit_number,
    stop_tick,
    fade_out_ticks)
  local reduced = profile == "reduced"
  local geometry = get_pad_exhaust_geometry(reduced)
  local burst_count = reduced
      and ei_lib.clamp(math.floor(pollution / 2500), 16, 64)
      or ei_lib.clamp(math.floor(pollution / 1500), 60, 240)
  local spiral_ticks = reduced
      and ei_lib.clamp(math.floor(pollution / 600), 120, 600)
      or ei_lib.clamp(math.floor(pollution / 180), 720, 4280)
  local emit_stride = reduced and 12 or 8
  local per_emit = reduced
      and ei_lib.clamp(math.floor(pollution / 12000), 6, 16)
      or ei_lib.clamp(math.floor(pollution / 6000), 20, 80)

  local start_radius = geometry.start_radius
  local max_radius = reduced
      and ei_lib.clamp(1.75 + pollution / 18000, 2.5, 8.0)
      or ei_lib.clamp(2.5 + pollution / 10000, 3.0, 15.0)
  max_radius = math.max(max_radius, start_radius)
  local radius_step   = (max_radius - start_radius) / math.max(1, math.floor(spiral_ticks / emit_stride))
  local angle_step    = 0.55

  local SMOKE_NAME = "smoke"
  local random = math.random

  state = state or ensure_launch_state(game and game.tick or 0)
  state.launch_smoke = state.launch_smoke or {}
  current_tick = math.max(0, math.floor(tonumber(current_tick) or (game and game.tick) or 0))
  start_tick = math.max(0, math.floor(tonumber(start_tick) or current_tick))
  stop_tick = normalize_smoke_tick(stop_tick)
  fade_out_ticks = stop_tick and math.max(0, math.floor(tonumber(fade_out_ticks) or 0)) or nil
  if stop_tick and (current_tick >= stop_tick or start_tick >= stop_tick) then
    return
  end

  local burst_pending = start_tick > current_tick

  if not burst_pending then
    local fade_scale = get_pad_exhaust_fade_scale(stop_tick, fade_out_ticks, current_tick)
    local scaled_burst_count = scale_pad_exhaust_emit_count(burst_count, fade_scale, 2)
    if scaled_burst_count > 0 then
      emit_launch_spiral_burst(surface, pos, scaled_burst_count, SMOKE_NAME, geometry)
    end
  end

  local next_tick = clamp_smoke_due_to_stop_tick(
    burst_pending and start_tick or (current_tick + 1),
    stop_tick
  )

  state.launch_smoke[#state.launch_smoke + 1] = {
    silo_unit_number = silo_unit_number,
    surface_index = surface.index,
    origin = { x = pos.x, y = pos.y },
    name = SMOKE_NAME,
    kind = "spiral",
    burst_count = burst_count,
    burst_pending = burst_pending,

    remaining = spiral_ticks,
    stride = emit_stride,
    per_emit = per_emit,

    angle = random() * math.pi * 2,
    angle_step = angle_step,

    radius = start_radius,
    radius_step = radius_step,

    jitter = geometry.radial_jitter,
    stop_tick = stop_tick,
    fade_out_ticks = fade_out_ticks,
    -- last_tick lets update_launch_smoke_spiral_job skip idle ticks while
    -- preserving the original per-tick remaining countdown.
    next_tick = next_tick,
    last_tick = burst_pending and (start_tick - 1) or current_tick,
  }
  state.launch_smoke_count = #state.launch_smoke
  remember_launch_smoke_tick(state, next_tick)
end

---@param state table
---@param surface LuaSurface
---@param pos MapPosition
---@param pollution number
---@param profile "full"|"reduced"
---@param silo_unit_number uint
---@param current_tick uint
---@param start_tick uint
---@param stop_tick uint|nil
---@param fade_out_ticks uint|nil
local function queue_launch_spiral(
    state,
    surface,
    pos,
    pollution,
    profile,
    silo_unit_number,
    current_tick,
    start_tick,
    stop_tick,
    fade_out_ticks)
  spawn_launch_smoke_spiral(
    surface,
    pos,
    pollution,
    profile,
    state,
    current_tick,
    start_tick,
    silo_unit_number,
    stop_tick,
    fade_out_ticks
  )
end

---@param job EiRocketLaunchSmokeJob
---@param current_tick uint
---@return boolean keep_job
---@return uint|nil next_tick
local function update_launch_smoke_spiral_job(job, current_tick)
  if type(job.origin) ~= "table" then
    return false, nil
  end

  local stop_tick = normalize_smoke_tick(job.stop_tick)
  if stop_tick and current_tick >= stop_tick then
    return false, nil
  end

  local next_tick = tonumber(job.next_tick)
  if next_tick and next_tick > current_tick then
    local due_tick = clamp_smoke_due_to_stop_tick(math.floor(next_tick), stop_tick)
    job.next_tick = due_tick
    return true, due_tick
  end

  local surface_index = job.surface_index
  if not surface_index then
    return false, nil
  end

  local surface = game.surfaces[surface_index]
  if not (surface and surface.valid) then
    return false, nil
  end

  local reduced = is_reduced_pad_exhaust_job(job)
  local geometry = get_pad_exhaust_geometry(reduced)

  if job.burst_pending == true then
    local fade_scale = get_pad_exhaust_job_fade_scale(job, current_tick)
    local scaled_burst_count = scale_pad_exhaust_emit_count(
      math.max(1, tonumber(job.burst_count) or 1),
      fade_scale,
      2
    )
    emit_launch_spiral_burst(
      surface,
      job.origin,
      scaled_burst_count,
      job.name or "smoke",
      geometry
    )
    job.burst_pending = false
  end

  -- Advance as though the old every-tick spiral updater had run for each
  -- elapsed tick; this keeps full/cinematic emission timing exact while cutting
  -- idle wakeups between stride boundaries.
  local previous_remaining = math.max(0, tonumber(job.remaining) or 0)
  local previous_tick = tonumber(job.last_tick) or (current_tick - 1)
  local elapsed_ticks = math.max(1, current_tick - previous_tick)
  elapsed_ticks = math.min(elapsed_ticks, math.max(1, previous_remaining))
  job.remaining = previous_remaining - elapsed_ticks
  job.last_tick = current_tick
  local remaining = job.remaining
  local stride = math.max(1, tonumber(job.stride) or 8)

  if (remaining % stride) == 0 then
    job.angle = (tonumber(job.angle) or 0) + (tonumber(job.angle_step) or 0.55)
    job.radius = math.max(
      geometry.start_radius,
      (tonumber(job.radius) or geometry.start_radius) + (tonumber(job.radius_step) or 0.1)
    )

    local fade_scale = get_pad_exhaust_job_fade_scale(job, current_tick)
    local per_emit = scale_pad_exhaust_emit_count(
      math.max(reduced and 6 or 1, tonumber(job.per_emit) or 1),
      fade_scale,
      2
    )
    if per_emit > 0 then
      emit_launch_spiral_pairs(surface, job, geometry, per_emit)
    end
  end

  if remaining > 0 then
    job.next_tick = clamp_smoke_due_to_stop_tick(
      get_next_spiral_due_tick(current_tick, remaining, stride),
      stop_tick
    )
    return true, job.next_tick
  end

  return false, nil
end

---@param job EiRocketLaunchSmokeJob
---@param plume_budget uint
---@param current_tick uint
---@return boolean keep_job
---@return uint plume_budget
---@return uint|nil next_tick
local function update_launch_smoke_plume_job(job, plume_budget, current_tick)
  if type(job.origin) ~= "table" then
    return false, plume_budget, nil
  end

  local next_tick = tonumber(job.next_tick)
  if next_tick and next_tick > current_tick then
    return true, plume_budget, next_tick
  end

  local expire_tick = tonumber(job.expire_tick)
  if expire_tick and expire_tick > 0 and current_tick > expire_tick then
    return false, plume_budget, nil
  end

  local previous_ticks = tonumber(job.ticks) or 0
  if not expire_tick and previous_ticks >= PLUME_START_DELAY then
    previous_ticks = math.max(0, previous_ticks - PLUME_ASCENT_START_DELAY)
  end
  job.ticks = previous_ticks + 1

  if job.ticks > PLUME_MAX_TRAIL_TICKS then
    return false, plume_budget, nil
  end

  job.visual_y = tonumber(job.visual_y) or job.origin.y
  job.current_speed = tonumber(job.current_speed) or PLUME_INITIAL_SPEED

  local active_flight_time = job.ticks
  local current_accel = PLUME_INITIAL_ACCELERATION
      + (PLUME_ACCELERATION_GROWTH * (active_flight_time ^ PLUME_ACCELERATION_EXPONENT))

  job.current_speed = math.min(job.current_speed + current_accel, PLUME_MAX_SPEED)
  job.visual_y = job.visual_y - job.current_speed

  if plume_budget <= 0 then
    job.next_tick = current_tick + 1
    return true, 0, job.next_tick
  end

  local surface_index = job.surface_index
  if not surface_index then
    return false, plume_budget, nil
  end

  local surface = game.surfaces[surface_index]
  if not (surface and surface.valid) then
    return false, plume_budget, nil
  end

  local density = math.min(plume_budget, math.max(1, tonumber(job.density) or get_plume_smoke_density(job.pollution)))
  local random = math.random
  for _ = 1, density do
    surface.create_trivial_smoke{
      name = PLUME_SMOKE_NAME,
      position = {
        x = job.origin.x + (random(-30, 30) / 10),
        y = job.visual_y + (random(8, 16) / 10)
      },
      starting_frame_deviation = random(0, 60),
    }
  end

  job.next_tick = current_tick + 1
  return true, plume_budget - density, job.next_tick
end

---@param jobs table
---@return table<uint, uint>|nil
local function get_plume_start_ticks_by_silo(jobs)
  local plume_start_ticks = nil
  for _, job in ipairs(jobs or {}) do
    if type(job) == "table" and job.kind == "plume" and job.silo_unit_number then
      local plume_start_tick = normalize_smoke_tick(job.next_tick)
      if plume_start_tick then
        plume_start_ticks = plume_start_ticks or {}
        local existing_tick = plume_start_ticks[job.silo_unit_number]
        if not existing_tick or plume_start_tick < existing_tick then
          plume_start_ticks[job.silo_unit_number] = plume_start_tick
        end
      end
    end
  end

  return plume_start_ticks
end

---@param job EiRocketLaunchSmokeJob
---@param plume_start_ticks table<uint, uint>|nil
local function infer_pad_exhaust_handoff_from_plume(job, plume_start_ticks)
  if not plume_start_ticks or job.kind == "plume" or normalize_smoke_tick(job.stop_tick) then
    return
  end

  local silo_unit_number = job.silo_unit_number
  local stop_tick = silo_unit_number and plume_start_ticks[silo_unit_number] or nil
  if stop_tick then
    job.stop_tick = stop_tick
    job.fade_out_ticks = tonumber(job.fade_out_ticks) or PAD_EXHAUST_PLUME_HANDOFF_FADE_TICKS
  end
end

local function update_launch_smoke(current_tick)
  local state = storage.ei.rocket_launch_pollution
  local q = state.launch_smoke
  if not (q and #q > 0) then
    state.launch_smoke_count = 0
    state.next_launch_smoke_tick = 0
    return
  end

  current_tick = current_tick or (game and game.tick) or 0
  local plume_budget = PLUME_SMOKE_BUDGET_PER_TICK
  local write_index = 1
  local job_count = #q
  local next_due_tick = 0
  local plume_start_ticks = get_plume_start_ticks_by_silo(q)
  for read_index = 1, job_count do
    local job = q[read_index]
    local keep_job = false
    local job_next_tick = nil
    if type(job) == "table" then
      infer_pad_exhaust_handoff_from_plume(job, plume_start_ticks)
      if job.kind == "plume" then
        keep_job, plume_budget, job_next_tick = update_launch_smoke_plume_job(job, plume_budget, current_tick)
      else
        keep_job, job_next_tick = update_launch_smoke_spiral_job(job, current_tick)
      end
    end

    if keep_job then
      if write_index ~= read_index then
        q[write_index] = job
      end
      if job_next_tick and (next_due_tick <= 0 or job_next_tick < next_due_tick) then
        next_due_tick = job_next_tick
      end
      write_index = write_index + 1
    end
  end

  for index = job_count, write_index, -1 do
    q[index] = nil
  end

  state.launch_smoke_count = #q
  state.next_launch_smoke_tick = next_due_tick
end

---@param state table
---@param current_tick uint
---@return boolean
local function is_launch_smoke_due(state, current_tick)
  if state.launch_smoke_count == nil or state.next_launch_smoke_tick == nil then
    return true
  end

  if (tonumber(state.launch_smoke_count) or 0) <= 0 then
    return false
  end

  local next_tick = tonumber(state.next_launch_smoke_tick)
  if next_tick == nil or next_tick <= 0 then
    return true
  end

  return current_tick >= next_tick
end

-- Pending cleanup is intentionally separate from smoke cadence. Plume/spiral
-- ticks should not pay cleanup cost unless a stale ordered launch is actually
-- due for cancellation, or legacy save state still needs migration.
---@param state table
---@param current_tick uint
---@return boolean
local function is_pending_cleanup_due(state, current_tick)
  if state.next_pending_cleanup_tick == nil
      or state.pending_cleanup_bucket_count == nil
      or state.pending_cleanup_item_count == nil
      or state.legacy_liftoff_work == nil then
    return true
  end

  if state.legacy_liftoff_work == true then
    return true
  end

  if (tonumber(state.pending_cleanup_item_count) or 0) <= 0
      and (tonumber(state.pending_cleanup_bucket_count) or 0) <= 0 then
    return false
  end

  local next_tick = tonumber(state.next_pending_cleanup_tick)
  if next_tick == nil or next_tick <= 0 then
    return true
  end

  return current_tick >= next_tick
end

local function draw_launch_hover_text(surface, position, text, color, y_offset)
  if not (surface and position and text) then
    return
  end

  rendering.draw_text{
    text = text,
    surface = surface,
    target = {x = position.x, y = position.y + (y_offset or 0)},
    color = color,
    scale = 1,
    alignment = "center",
    scale_with_zoom = false,
    time_to_live = 180,
  }
end

local function apply_confirmed_launch(job)
  local surface = job and job.surface_index and game.surfaces[job.surface_index] or nil
  if not surface then
    return false
  end

  local state = ensure_launch_state(job.tick or (game and game.tick) or 0)
  -- Ordered launch owns the visual smoke sequence. Confirmation only stops the
  -- ascending plume and applies gameplay consequences so aborted orders cannot pollute.
  remove_plume_jobs_for_silo(state, job.silo_unit_number)

  local pollution = tonumber(job.pollution) or 0
  surface.pollute(job.position, pollution)
  draw_launch_hover_text(
    surface,
    job.position,
    {"exotic-industries.rocket-launch-pollution", math.floor(pollution + 0.5)},
    {r = 0.95, g = 0.72, b = 0.28},
    LAUNCH_POLLUTION_TEXT_OFFSET_Y
  )
  try_form_retaliation(surface, job.position, pollution)
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

local function refresh_farthest_selected_unit(distances, selected_count)
  local farthest_index = 1
  local farthest_distance = distances[1] or 0

  for index = 2, selected_count do
    local distance = distances[index] or 0
    if distance > farthest_distance then
      farthest_distance = distance
      farthest_index = index
    end
  end

  return farthest_index, farthest_distance
end

local function select_nearest_units(entities, origin, limit)
  local selected_units = {}
  local selected_distances = {}
  local selected_count = 0
  local farthest_index = 1
  local farthest_distance = 0
  local nearest_unit = nil
  local nearest_distance = nil

  for _, unit in ipairs(entities) do
    if unit and unit.valid then
      local dx = unit.position.x - origin.x
      local dy = unit.position.y - origin.y
      local distance = dx * dx + dy * dy

      if nearest_distance == nil or distance < nearest_distance then
        nearest_distance = distance
        nearest_unit = unit
      end

      if selected_count < limit then
        selected_count = selected_count + 1
        selected_units[selected_count] = unit
        selected_distances[selected_count] = distance
        if selected_count == 1 or distance > farthest_distance then
          farthest_distance = distance
          farthest_index = selected_count
        end
      elseif distance < farthest_distance then
        selected_units[farthest_index] = unit
        selected_distances[farthest_index] = distance
        farthest_index, farthest_distance = refresh_farthest_selected_unit(selected_distances, selected_count)
      end
    end
  end

  return selected_units, selected_count, nearest_unit
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

  if #nearby_units == 0 then
    return false
  end

  local selected_units, selected_count, anchor_unit = select_nearest_units(nearby_units, position, max_units)
  if selected_count == 0 then
    return false
  end

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

  draw_launch_hover_text(
    surface,
    position,
    {"exotic-industries.rocket-launch-pollution-retaliation"},
    {r = 1, g = 0.25, b = 0.25},
    LAUNCH_RETALIATION_TEXT_OFFSET_Y
  )

  return true
end

local function cleanup_stale_pending_launches(current_tick)
  local state = ensure_launch_state(current_tick)
  local pending_item_count = tonumber(state.pending_cleanup_item_count) or 0
  local pending_bucket_count = tonumber(state.pending_cleanup_bucket_count) or 0
  if pending_item_count <= 0 and pending_bucket_count <= 0 then
    return
  end

  local next_cleanup_tick = tonumber(state.next_pending_cleanup_tick) or 0
  if next_cleanup_tick <= 0 then
    next_cleanup_tick = refresh_pending_cleanup_summary(state)
  end

  if next_cleanup_tick <= 0 or next_cleanup_tick > current_tick then
    return
  end

  local due_entries = {}
  local next_due_tick = 0
  local bucket_count = 0
  local item_count = 0

  for due_tick, bucket in pairs(state.pending_launch_cleanup_buckets) do
    local numeric_due_tick = tonumber(due_tick)
    if numeric_due_tick and numeric_due_tick <= current_tick then
      state.pending_launch_cleanup_buckets[due_tick] = nil
      if type(bucket) == "table" then
        for _, entry in ipairs(bucket) do
          due_entries[#due_entries + 1] = entry
        end
      end
    elseif numeric_due_tick and type(bucket) == "table" and next(bucket) ~= nil then
      bucket_count = bucket_count + 1
      item_count = item_count + count_bucket_items(bucket)
      if next_due_tick <= 0 or numeric_due_tick < next_due_tick then
        next_due_tick = numeric_due_tick
      end
    else
      state.pending_launch_cleanup_buckets[due_tick] = nil
    end
  end

  state.next_pending_cleanup_tick = next_due_tick
  state.pending_cleanup_bucket_count = bucket_count
  state.pending_cleanup_item_count = item_count

  if #due_entries == 0 then
    return
  end

  for _, entry in ipairs(due_entries) do
    local pending = entry and entry.silo_unit_number and state.pending_launches_by_silo[entry.silo_unit_number] or nil
    if pending and pending.expected_tick == entry.expected_tick then
      state.pending_launches_by_silo[entry.silo_unit_number] = nil
      remove_launch_smoke_jobs_for_silo(state, entry.silo_unit_number, nil)
      ei_runtime_scheduler.bump_counter("rocket-launch-pollution", "launch_canceled", 1)
    end
  end
end

function model.has_tick_work(event)
  local state = storage and storage.ei and storage.ei.rocket_launch_pollution or nil
  if type(state) ~= "table" then
    return false
  end

  local current_tick = ei_lib.get_event_tick(event)
  return is_launch_smoke_due(state, current_tick) or is_pending_cleanup_due(state, current_tick)
end

function model.updater(event)
  if not (storage.ei and storage.ei.rocket_launch_pollution) then return end
  local state = storage.ei.rocket_launch_pollution
  local current_tick = event.tick
  if is_pending_cleanup_due(state, current_tick) then
    cleanup_stale_pending_launches(current_tick)
  end
  if is_launch_smoke_due(state, current_tick) then
    update_launch_smoke(current_tick)
  end
end

-- Ordered launches own visual sequencing. Confirmed launches later decide
-- whether the stored pollution consequences actually fire.
local function queue_rocket_liftoff_wrath(silo, pollution, event)
  if not silo or not silo.valid then return end
  if not silo.unit_number then return end
  local surface = silo.surface
  local pos = silo.position

  -- Sync point: how long from "ordered" until the rocket actually launches.
  local delay = silo.prototype.launch_wait_time or 0

  local state = ensure_launch_state(event.tick)
  local visual_style = get_visual_style(state)
  local pad_exhaust_profile = get_pad_exhaust_profile(visual_style)
  local expected_tick = event.tick + delay
  local uses_plume = visual_style_uses_plume(visual_style)
  local plume_start_tick = uses_plume and get_launch_plume_start_tick(event.tick) or nil
  local cleanup_tick = nil

  if pad_exhaust_profile or uses_plume then
    remove_launch_smoke_jobs_for_silo(state, silo.unit_number, nil)
    cleanup_tick = event.tick + PLUME_MAX_TRAIL_TICKS + ROCKET_LAUNCH_CONFIRM_GRACE_TICKS
  end

  if pad_exhaust_profile then
    queue_launch_spiral(
      state,
      surface,
      pos,
      pollution,
      pad_exhaust_profile,
      silo.unit_number,
      event.tick,
      expected_tick,
      uses_plume and plume_start_tick or nil,
      uses_plume and PAD_EXHAUST_PLUME_HANDOFF_FADE_TICKS or nil
    )
  end

  if uses_plume then
    queue_launch_plume(state, surface, pos, silo.unit_number, pollution, event.tick, true)
  end

  queue_pending_launch({
    tick = expected_tick,
    surface_index = surface.index,
    position = { x = pos.x, y = pos.y },
    silo_unit_number = silo.unit_number,
    pollution = pollution,
    cleanup_tick = cleanup_tick,
  }, event.tick)
end

-- Ordered launch: queue visuals and remember the predicted confirmation tick.
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

-- Confirmed launch: apply pollution/retaliation once, then clear the pending
-- plume. Pad exhaust is already running from the ordered launch timing.
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
  local plume_jobs, spiral_jobs = count_launch_smoke_jobs(state)
  local status = {
    visual_style = get_visual_style(state),
    pending_launch_count = ei_runtime_scheduler.table_count(state.pending_launches_by_silo),
    pending_cleanup_bucket_count = tonumber(state.pending_cleanup_bucket_count) or 0,
    pending_cleanup_item_count = tonumber(state.pending_cleanup_item_count) or 0,
    next_pending_cleanup_tick = tonumber(state.next_pending_cleanup_tick) or 0,
    legacy_liftoff_queue_count = #(storage.ei.rocket_launch_pollution.liftoff_queue or {}),
    legacy_liftoff_work = state.legacy_liftoff_work == true,
    active_smoke_jobs = tonumber(state.launch_smoke_count) or 0,
    next_launch_smoke_tick = tonumber(state.next_launch_smoke_tick) or 0,
    plume_jobs = plume_jobs,
    spiral_jobs = spiral_jobs,
    pending_launches = ei_runtime_scheduler.table_count(state.pending_launches_by_silo),
    pending_cleanup_buckets = tonumber(state.pending_cleanup_bucket_count) or 0,
    pending_cleanup_items = tonumber(state.pending_cleanup_item_count) or 0,
    launch_smoke = tonumber(state.launch_smoke_count) or 0,
  }

  ei_runtime_scheduler.set_module_status("rocket-launch-pollution", status)
  return status
end

return model
