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

  -- Pull config values with defaults so this function stays resilient
  -- even if someone deletes a config field during refactor/testing.
  local base = storage.ei.rocket_launch_pollution_cap or cfg.base
  local min_scale = cfg.min_scale or 0.1
  local mode = storage.ei.rocket_launch_pollution_mode or "linear"

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

-- Event handler for rocket launches.
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
  --local msg = {"exotic-industries.rocket-launch-pollution", pollution}
  local msg = pollution.." pollution emitted"
  ei_lib.crystal_echo_floating(
    msg,
    silo,
    1800,
    "wrath"
  )
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