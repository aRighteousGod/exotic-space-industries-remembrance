# Core Lualib Map

Surveyed from verified Factorio 2.1.23 build 87750 under:

```text
.factorio-qc/f21/data/core/lualib
```

This map tracks installed game files. A hosted Lua API cache refresh alone is not enough to update the surveyed Factorio version.

Re-check with:

```powershell
& .\.factorio-qc\f21\bin\x64\factorio.exe --version
Get-ChildItem '.factorio-qc/f21/data/core/lualib' -File
rg -n "require.*(meld|util|resource-autoplace|mod-gui|math2d|math3d)" '.factorio-qc/f21/data'
```

## Data And Prototype Helpers

- `util`: copying, table comparison, colors, positions, icon composition, sprite loading, recipe product normalization, tint helpers, and assorted prototype utilities.
- `prototype-hierarchy` and `prototype-info`: new in 2.1; engine prototype hierarchy/metadata used by the loader and native helpers.
- `meld`: in-place recursive table patching with delete, overwrite, invoke, and append controls.
- `resource-autoplace`: resource autoplace setting construction; ESIR uses it for custom resource placement.
- `autoplace_utils`: lower-level autoplace peak helpers.
- `collision-mask-defaults`: default prototype collision masks by type.
- `collision-mask-util`: data-stage collision mask reading, comparison, collection, replacement, and old-mask migration.
- `circuit-connector-sprites`: circuit connector sprites, points, and definitions from generated templates.
- `circuit-connector-generated-definitions`: generated circuit connector definition data used by connector helpers.
- `sound-util`: sound variation and volume modifier helpers used by vanilla prototype sound definitions.
- `bonus-gui-ordering`: global bonus GUI ordering table used by ammo/category prototype setup.
- `surface-render-parameter-effects`: surface render parameter effect definitions.
- `data-duplicate-checker`: loader duplicate and overwrite diagnostics; treat as Factorio internals unless working on data loader behavior.
- `dataloader`: Factorio data loader support; mods normally use the provided `data` object, not this module directly.

## Geometry And Graphics Math

- `math2d`: orientation/vector helpers, position operations, distance, normalization, and bounding-box tests.
- `math3d`: 2D/3D/4D vector helpers and matrix helpers for projection, transforms, and animation/frame calculations.

## Runtime And Scenario Helpers

- `mod-gui`: standard top-button and left-flow GUI roots for persistent mod controls.
- `event_handler`: library-style event aggregator used by vanilla scenarios; avoid replacing ESIR's `control.lua` dispatcher with it.
- `story`: tutorial/scenario story flow helpers.
- `silo-script`: rocket silo victory script hooks for scenarios/freeplay-like control.
- `space-finish-script`: space platform victory-location hooks.
- `crash-site`: crash-site entity and cutscene helpers.
- `production-score`: production score calculations for PvP/scenario victory conditions.
- `kill-score`: kill score calculations layered on production score.

## Known ESIR Touchpoints

- `prototypes/planet-gaia/relic-debris.lua`: `resource-autoplace`.
- `prototypes/steam-age/drill-deposits.lua`: `resource-autoplace`.
- `prototypes/steam-age/acid-turret/acid.lua`: `util`, `circuit-connector-sprites`, and `math3d`.
- `scripts/control/crystal-accumulator.lua`: `mod-gui`.
- `scripts/control/em-trains/gui.lua`: `mod-gui`.
- `scripts/data-final-updates/camp-fire.lua`: core `util`.
- `prototypes/planet-gaia/procession-catalogue.lua`: core `util`.

## Practical Defaults

- The 2.0.77 to 2.1.23 survey has 23 to 25 Lua modules: two additions, no removals, 13 byte-identical and 10 changed modules. File presence does not prove semantic parity.
- In 2.1 `util.product_amount` understands `independent_probability`, `shared_probability` and `extra_count_fraction`; do not calculate yields from the removed product `probability` field. `util.contains_value` is available, and position shifting accepts keyed coordinates.
- Circuit connector definitions such as `chest` are vectors in 2.1. Use `chest-single` when a scalar definition is required. Connector sprites now own `render_layer` and `secondary_draw_order`; old mining-drill graphics-set fields are removed.

- For new ESIR prototype patches, check `meld`, `util`, and `ei_lib` before writing custom recursive table code.
- For resource patches, prefer `resource-autoplace` when matching vanilla map generation behavior.
- For runtime GUI, use `mod-gui` only for persistent global controls; use `esir-runtime-gui` for entity-bound panels.
- For runtime events, keep ESIR's dispatcher and scheduler rules instead of importing `event_handler` by default.
