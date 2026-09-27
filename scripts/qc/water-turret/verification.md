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
