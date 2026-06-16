--==============================================================================
-- ESIR FILE MAP
-- owns: rocket launch plume smoke prototype
-- loaded_by: exotic-space-industries-remembrance\data.lua
-- cadence: data-stage load
-- forwarded_events: none
-- storage_roots: none
-- gui_ids: none
-- remote_interfaces: none
-- rebuild_on: data stage reload, base trivial-smoke changes
--==============================================================================

local source_smoke = data.raw["trivial-smoke"] and data.raw["trivial-smoke"]["smoke"]

if source_smoke then
  local plume_smoke = table.deepcopy(source_smoke)
  plume_smoke.name = "ei-rocket-launch-plume-smoke"
  plume_smoke.flags = plume_smoke.flags or {"not-on-map"}
  plume_smoke.show_when_smoke_off = true
  plume_smoke.color = {r = 0.46, g = 0.43, b = 0.40, a = 0.38}
  plume_smoke.start_scale = 0.55
  plume_smoke.end_scale = 2.35
  plume_smoke.duration = 240
  plume_smoke.fade_in_duration = 20
  plume_smoke.fade_away_duration = 90
  plume_smoke.spread_duration = 180

  local function style_animation(animation)
    if not animation then
      return
    end

    if animation.layers then
      for _, layer in ipairs(animation.layers) do
        style_animation(layer)
      end
      return
    end

    animation.scale = (animation.scale or 1) * 2.7
    animation.tint = {r = 0.55, g = 0.51, b = 0.47, a = 0.42}
    animation.blend_mode = "normal"
  end

  style_animation(plume_smoke.animation)
  data:extend({plume_smoke})
end
