# Production building status lights

<a id="contract"></a>
## Contract

The startup setting `ei-production-machine-lights` selects `status` (default),
`original`, or `off` for the curated 28 production buildings. Settings and data
stages share the config module; no runtime state, events, or migrations exist.

- `original` returns before touching prototypes, retaining the original white lights.
- `off` removes only the exact standalone basic white light with intensity 1 and size 15.
- `status` replaces 25 plain lights, adding 20 lights at the existing indicators
  of 17 of those bodies. The eight bodies without indicators receive no replacement.
- Arc furnace, plasma heater and molten-metal caster each receive one additional
  indicator, for 23 status lights across 20 bodies. None of these three machines'
  existing visuals are removed, including in Off and Original modes. Original
  and Off simply omit their additional indicators.
- The arc furnace flicker preset continues to own only its four tagged process
  lights. All five presets remain independent of the production status setting;
  arc Off can coexist with a steady status lamp and the original idle capacitor glow.
- Additional indicator entries are inserted before authored visuals, preserving
  their relative order and every existing `secondary_draw_order`. Factorio's
  secondary draw order controls sprite stacking; emitted lights have no documented
  depth ordering, so the emitted light cannot guarantee an underneath blend.
  The added lens sprite intentionally draws above the original colored pixels.
- Native status tint is red for idle, missing input, and disabled; green for
  working; yellow for full output; orange for low power; transparent for no power.
  This matches Bottleneck Lite 1.3.4's defaults except that no power stays dark.
  Each visual pairs one neutral lens overlay with one light, using only native
  status tint. Lights use radius 0.35 (advanced refinery 0.50), intensity 1, and
  minimum darkness 0.1. The refinery covers its whole inset screen, centered at
  source pixel `(470, 555)`, entity offset `(-0.669375, 0.3353125)`; all other
  measured centers remain unchanged.
- Neutral 64-pixel lens masks cover the colored source face, disconnected rim,
  and antialiased fringe, plus one source pixel of opaque filtering coverage.
  Source red-to-green changes distinguish lens edges from unchanged metal.
  The overlays use normal
  blending and `draw_as_glow`, on `light-effect` at secondary draw order 4.
  The source sprites remain unchanged; the overlay and emitter both disappear
  without energy. All new PNGs ship in the main mod's `graphics/status-lights/`
  by explicit user request. Original and Off load no added lens overlays.
- During data-updates, only Status plus installed/enabled Bottleneck Lite sets
  `bottleneck_ignore = true` on the 20 indicator-bearing bodies. BNL consumes it
  in data-final-fixes before inserting its own indicator or overriding colors.
  The eight bodies without lamps remain eligible. Other modes and absent/disabled
  BNL do not mutate flags, including flags owned by other mods. A shared coordinate
  registry defines both this early scope and the late lighting pass.
- ESIR uses its own fixed colors even when BNL's colors are customized. No runtime
  handlers, polling, state, migration, or additional light emitters are introduced.
- Intensity was calibrated against the reskinned assemblers' additive status
  sprites in native day/night captures. A point light illuminates existing pixels,
  so it cannot exactly match their additive brightness on every body. Neutral
  lenses keep the status color readable beside preserved process effects,
  including the HTR's recipe-colored glow.
- Indicator centers are calibrated to current ESIR artwork and transformed using
  the body frame dimensions, scale, and shift. These bodies share art across
  orientations. An external reskin requires new calibration.
- The finalizer runs after fuel-glow and arc-furnace-light. It preserves all other
  graphics, authored process effects, gameplay, death effects, and presentation.
  In particular, Off does not remove the HTR's separate recipe-colored process glow.
- Alien utilities and other unlisted authored-light bodies remain outside this
  registry. Both molten-metal caster and nuclear-waste castor are covered separately.

## Implementation sources

- [Startup mode config](../../../exotic-space-industries-remembrance/lib/machine-status-light-config.lua)
- [Shared indicator definitions](../../../exotic-space-industries-remembrance/lib/machine-status-light-definitions.lua)
- [Early Bottleneck Lite exclusion](../../../exotic-space-industries-remembrance/scripts/data-updates/machine-status-lights.lua)
- [Curated indicator positions and finalizer](../../../exotic-space-industries-remembrance/scripts/data-final-updates/machine-status-lights.lua)

## Verification

Compare final prototypes with the pass disabled and with each startup mode.
Require 25 original generic lights, 23 status emitters on 20 bodies, and zero
replacement emitters in Off. Preserve complete prototypes after subtracting only
the expected lighting differences, including excluded bodies and HTR process effects.
Check native statuses and day/night rendering, supported orientations, normal and
enlarged views, and transitions. Prototype checks cannot establish visible alignment.
Check all five arc presets and verify that removing just the added status entries
recovers each machine's original process visuals, death and presentation fields.
Check all three startup modes with Bottleneck Lite absent, disabled, enabled, and
custom-colored. Capture early flags before BNL consumes them; final flag presence
alone cannot prove exclusion. Verify an independently supplied ignore flag too.
Exercise full-output and low-power recovery, and review yellow/orange lenses in
day/night captures. The QC baseline disables both early and final ESIR hooks.
