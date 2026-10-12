# Firefighting integration verification

Engine: installed Factorio 2.0.77. Pack: ESIR 1.3.40, primary checkout.
All profiles use disposable copied packs and saves; installed mods and original
player saves were not changed.

## Final implementation

- Integrated `ei-extinguisher`, `ei-extinguisher-ammo`, their recipes, research,
  assets and migration; the standalone extinguisher dependency is now a conflict.
- The turret consumes one integrated extinguisher and requires its research.
- Selected art: concept 9, light blue/teal. Final footprint is 3x3, with native
  fluidbox collars at centered opposite ports. Both sides of all four placed
  directions connect to ordinary pipe tiles.
- Only the lower plinth is fixed. The complete circular platform, head, backpack
  and internal supply pipe rotate together across 64 frames. Shadows and neutral
  owner trim remain separate layers; the selected teal paint is baked.
- Existing control dispatch and scheduler are used. Ordinary event paths pass
  `event.tick`; initialization/configuration snapshots use `game.tick` because
  those callbacks have no event tick.

## Evidence

| Profile | Result | Evidence under `.factorio-qc/wtr/` |
|---|---|---|
| Final runtime/player | 66 cases passed | `final-player/script-output/water-qc.json` |
| Final 3x3 connection layout | 59 cases passed, including 25 port/aim assertions | `ports-3x3/script-output/water-qc.json` |
| Native muzzle calibration | 41 cases passed; maximum final-direction error 0.008381 tile | `muzzle/script-output/water-qc.json` |
| In-game sprites and collars | Eight aiming views, each with four base placements | `visual/script-output/water-art/pose-0.png` through `pose-7.png` |
| Legacy extinguisher transition | Ten migration assertions passed, including partial ammo and quality | `new-load/` and `reload/` |
| Water state persistence | Normal and configuration reload passed | `water-reload/` and `water-config/` |

Native muzzle probes isolate barrel, pivot and delivery offsets. A stream impact
event's source position is the source entity center; launch effects supply the
projected muzzle. The native engine quantizes positions. The matching scripted
formula aims from the elevated pivot and retains the physical tip at close range.

Asset QA: 4 base frames and 64 head/body/shadow/mask frames; correct dimensions
and ordering; neutral mask; minimum head-body alpha margin 71px and head-shadow
margin 29px. Every exported visible pixel and alpha value matches its original
frame. Blender's convenience sheet packing changed colors, so shipping uses the
asset exporter's raw-frame packing. Icons are 224x128 (128/64/32 mips) and 256x256.

`invoke-esir-dev.ps1 -Task qc-assets` passed. Final preflight has no syntax,
encoding, locale, asset-reference or version errors; two unrelated existing
module-header warnings remain in auric-inoculation-vat and
emerald-apocalypse-hover-tank. Generic `qc-fast` previously seeded the removed
external extinguisher, so the isolated harness supplies the valid mod list.

The player profile exercises real GUI widgets through production handlers,
paste, blueprints, stale/foreign-force events and lifecycle cleanup. This is not
a joined multiplayer/desync test. Earlier performance samples were collected
alongside other engine work and are not an isolated performance comparison.

## Replay and review

The durable art generator is `.codex/esir/asset-generators/water-turret/`.
Shipping sprites, masks, shadows, icons and provenance belong to Graphics 6;
the main pack owns their prototypes and gameplay. Replay exports remain staged.
Run `invoke-art.ps1` there from the repository root. Original source model,
task responses and prepared blends remain in `output/meshy/water-turret/`.
Open `output/meshy/water-turret/index.html` for independent base/head controls,
force trim, tile/port markers, game-scale view and an engine screenshot.

Meshy was updated in the persistent global installation and launcher, not only
inside the project: `0.5.2-esir.20260925.1`. The update passed 50 offline MCP
compatibility checks, build/lint, fresh global-launcher discovery, and 13 REST
helper checks. One Meshy 7.1 generation consumed 40 credits; no paid regeneration
was needed. The 8K texture option returned an 8192 base-color map and 4096 PBR
auxiliary maps, all retained in the original source model.

## Smooth suppression aiming, 2026-10-12

The turret advances its weapon orientation along the shortest wrapped arc before
launching scripted suppression. The native prototype and script share a 0.02-turn
step. Misaligned shots reuse the bounded fire queue at the next tick, without
spending water or adding persistent aiming state. Queue backlog slows movement
rather than increasing a step; enemy-first acquisition and readiness still gate
every continuation. Ground direction and external pipe connections stay fixed.

The registered `smooth-turn-20261012` profile passed all 114 cases over 2,200
updates in Factorio 2.0.77. The original 66 player/runtime cases passed alongside
48 orientation cases: multi-tick travel, both wrap directions, a half-turn,
alignment before one 15-water pulse, target cancellation, power-loss/resume,
idle enemy-first aiming, and fixed bases/ports. The sampled long turn took 19
steps and the half-turn took 25. These are automated engine checks, not manual
visual review, multiplayer, or a saturated-fleet performance measurement.

Reproduce with the existing runner and a fresh run name:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/invoke-water-turret-qc.ps1 `
  -RunName smooth-turn-20261012 `
  -SaveInput .factorio-qc/wtr/final-player/fixture.zip -PlayerSave
```

Evidence is under `.factorio-qc/wtr/smooth-turn-20261012/`; the registered run ID
is `fda3f5976f9042b0ac826c394f5ced65`. The first fixture attempt exposed a nil
comparison in its blackout assertion, and the next used too short an observation
window for existing search/power deadlines. Both fixture issues were corrected;
the production turning code was unchanged across the successful rerun.

The run record is closed and pinned. Its retention snapshot was rejected because
the legacy runner stages graphics companion junctions; engine acceptance passed,
and the evidence remains protected rather than traversing those linked folders.

Touched Lua syntax and whitespace checks passed. The full blueprint audit reports
only an unrelated missing `acidthrower-pressure-jet.md#dispersion` anchor. The
preflight wrapper could not finish enumerating another task's long generated
minigun output path. Neither result is a water-turret engine failure.

## Graphics 6 relocation, 2026-10-12

Moved the five base/head/shadow/mask sheets, both icons and `PROVENANCE.md`
to `exotic-space-industries-remembrance-graphics-6/graphics/`, preserving every
file byte-for-byte. The original main-pack copies were retired. The prototype
uses `ei_graphics_6_path`; the existing required Graphics 6 dependency covers
the assets. QA icon paths, generated Lua snippet paths and both disabled
promotion destinations now point at Graphics 6. Research still uses the
256-square preview and the item retains its 128/64/32 mip strip.

The `graphics6-20261012` profile passed all 114 cases over 2,200 updates in
Factorio 2.0.77, including the new final-data assertions for all seven PNG paths.
SHA-256 checks matched all eight moved files; PNG validity/dimensions, Lua,
Python, PowerShell and JSON syntax, and scoped whitespace checks passed.
No image data or animation layout changed. Move manifest and engine evidence:
`.factorio-qc/wtr/graphics6-20261012/`, registered run
`dfaad68c164b44f6bb3f29b081315d73`. Its task-created companion junctions were
unlinked after validation without touching source packs, allowing a successful
retention snapshot and closeout. Rerunning the fixture recreates those links.
