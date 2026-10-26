# Arc furnace, plasma heater and caster status lights

Historical red/green-only extension. See [multicolor status and complete lens
coverage](MULTICOLOR-VERIFICATION.md) for the current palette and rendered
acceptance with the guarded lens overlays.

Factorio **2.0.77**, ESIR **1.3.41**. This extends the earlier 25-body lighting
pass to 28 bodies, with **23 status emitters across 20 indicator-bearing bodies**.
The previous eight bodies without indicators still receive no replacement light.

## Implementation and setting interaction

Each new body gets one independent status light, radius **0.35**, intensity **1**,
minimum darkness **0.1**, without flicker. Source sprite measurements are:

| Body | Pixel center | Entity-relative offset |
|---|---|---|
| Arc furnace | (385, 82) | (1.4109375, -1.903125) |
| Plasma heater | (385, 82) | (1.4109375, -1.903125) |
| Molten-metal caster | (361, 93) | (0.721875, -1.320625) |

The main finalizer has a separate additive registry for these bodies. It does not
apply the generic-light removal rule to their visuals. Original and Off production
modes leave all their authored effects unchanged and omit the new status light.

The arc preset runs first and still owns exactly its four tagged process lights.
Original, Reduced, Soft and Static retain four; Off removes those four and retains
the original idle capacitor glow. The status setting independently adds or omits
its steady lamp, including when arc process glow is Off.

Status entries come first in the visualisation array. Existing visuals retain their
relative ordering, render layers and secondary draw orders. The pinned official
`WorkingVisualisation.secondary_draw_order` documentation specifies sprite order;
`LightDefinition` exposes no independent light depth. This therefore preserves
sprite stacking without claiming a separate underneath blend for emitted light.

## Native validation

Seven real startup profiles cover all three production modes with the original arc
preset, plus Status with arc Off, Static, Soft and Reduced. This is not the full
15-combination Cartesian product. **1,402 focused assertions pass.**

- Complete final-prototype comparisons cover all 28 targets and all present
  exclusions, subtracting only the expected status changes and independently
  specified arc-preset changes. Every other field remains identical, including
  animation, process lighting, energy, death effects, sounds and Factoriopedia.
- Exactly 23 emitters exist in Status, with each of the three added lights first
  in its body's array. The native colors, exact light fields and four direction
  offsets are checked independently of the source transform.
- **588 native state/orientation cases** and **84 circuit/energy transition
  checks** pass. Empty furnaces natively report `no_ingredients`; this is distinct
  from the assembler/caster's `no_recipe` and `item_ingredient_shortage` states.
- Low-power cases use isolated undersupplied networks. Transition captures hold
  the verified state through a render boundary before advancing the scenario.

The fixture snapshots final prototypes before adapting recipes to a short item
recipe. Furnace and assembler types, native energy, speed, graphics and directions
are retained. Other copied runtime controls are isolated. This establishes focused
native lighting behavior, not full-mod runtime or multiplayer acceptance.

## Rendered review

The retained run contains 51 native captures: day/night and normal/double zoom for
Status with original arc and arc Off, Off-mode comparison views, and 24 transition
snapshots. Review sheets show the whole bodies and all four requested orientations.
The machine's existing idle/process illumination is intentionally allowed to remain
without energy; only the newly added status emission must disappear.

The day/night sheets and all 24 transition snapshots were visually reviewed. Red
and green emission stays centered on the visible indicators, including every
native orientation, and the original process effects remain visible. All **12
unpowered indicator regions exactly match Off-mode pixels** with the same original
arc preset. Circuit disable/resume and energy loss/restoration show red, green,
dark and green respectively, with no settled-state disagreement in the sprite art.

One arc-Off graphical pass rendered its captures but crashed in the graphics-driver
teardown after automatic quit. Its log is retained as
`off-status-dx-shutdown-crash.txt`. The retry and the final Off comparison pass both
exited cleanly; final checks use those regenerated images.

## Repository checks and provenance

Preflight passes Lua syntax, PowerShell syntax, blueprint contracts, headers,
requires, locale keys, asset references and version consistency. Full preflight
still fails on unrelated long Python bytecode-cache paths and the same three
existing encoding findings documented in the earlier verification report. Focused
Python files additionally pass AST parsing without generating bytecode caches.

Live body/animation sprite hashes match the private staged copies for all six
images. Only immutable asset files share storage with the previous private seed;
mutable source/control files have private copies. No shipping art was edited.

- Managed run: `aef487e54e3541eea7c15ed3f101fbba`
- Payload: `.factorio-qc/ml-2012a9f2`
- Native reports and captures: `script-output/machine-lights/`
- Acceptance: `smelter-acceptance.json` in that directory
- Native visual review and no-energy comparison: `review/`
- Reproduction: [README smelter extension](README.md#smelter-extension)
- Earlier 25-body acceptance: [verification report](VERIFICATION.md)

Death and player-facing presentation are **inherited and verified by complete
prototype comparison**. Death-animation playback and the Factoriopedia UI were not
rerendered for this lighting-only extension.
