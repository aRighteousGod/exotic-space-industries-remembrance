# Radar spritesheet integration

**Placement/depth correction, awaiting user checks:** native placement pictures
and a depth-sorted visual helper replace the overlay implementation below.
Existing reports/fixtures describe the previous LuaRenderObject implementation
and are historical evidence only. No checks were run for this correction, at
the user's request.

Factorio 2.0.77, ESIR 1.3.40. Both approved models are now shipping art:
the Split-Trough Watcher and Fourfold Interrogator, each with 256 facings.

- Ten unchanged approved PNG pages in the main mod: 35,167,676 bytes.
- Two matching 128/64/32 inventory icon strips in the main pack: 57,483 bytes.
- Body/shadow use two 128-frame animation segments; the Phased-array's white
  panels and red indicator use a separate additive glow animation.
- The existing four control visits per tick select frozen frames and interpolate
  behind completed observations. Larger fleets share visual refresh capacity.
  No new scheduler, scan allowance, or power cost is introduced.
- Raw master renders, lower-facing exports and `/models` remain untouched.

`art-assets.json` records shipping paths, sizes and hashes. The existing
`spritesheets.py check` verified all 1,280 pass frames against the retained
RGBA8 master decode, including alpha, page order and unchanged master hashes.
Both icon previews were visually inspected before promotion.

The focused engine fixture passed 540 assertions in `.factorio-qc/radar/art5`:
all 256 frame selections for both chassis, page transitions, clockwise/reverse
interpolation, crossing north, clamping at the completed target, pause,
powered/off glow, render repair, native freezing, upgrades, clones, surface
deletion, ordinary movement, actual observation-driven rotation and fixed bearing.
It asserts at most four visual services per tick throughout. The first
headless Watch fixture had no connected player to complete queued charting;
the focused headless run uses Survey over generated terrain. The connected
visual fixture also exercised Watch successfully.

Day/night screenshots and native inventory-icon review use the connected-player
fixture. The first review exposed weak light-only emission; production uses
`draw_as_glow` on `light-effect` for visible self-emission. The final graphical
run, `.factorio-qc/radar/av2`, passed all 540 assertions. Its four cardinal
views, powered/unpowered night views and native inventory-icon screenshot were
inspected. The panels and red indicator emit while powered and extinguish on
outage. Both reports are retained in [art-results.json](art-results.json).

```powershell
powershell -ExecutionPolicy Bypass -File scripts/invoke-sweeping-radar-qc.ps1 -RunName art -Fixture art -Ticks 1000
powershell -ExecutionPolicy Bypass -File scripts/invoke-sweeping-radar-qc.ps1 -RunName art-view -Fixture art-visual -Visual -Ticks 1000 -SaveInput .factorio-qc/wtr/player/fixture.zip -GraphicsArchiveDirectory .factorio-qc/radar/art-archives
```

Radar pages now ship in the main mod. Companion graphics archives remain useful for graphical
QC on Windows; long loose-file paths in unrelated existing graphics can exceed
the engine's path limit. These are finite functional runs, not performance
measurements. Benchmarks and broader regression runs were skipped at the user's
request. Save/reload is supported by persisted render objects but was not rerun
for this art integration.

Lua syntax, requires, locale keys and asset references passed preflight. The
updated conceptual-model audit and seven-locale radar audit pass. Overall
repository preflight remains blocked by the pre-existing encoding finding in
`scripts/qc/singularity-lance/angular-results.json`; the generic asset wrapper
also encountered protected Python-cache writes. No unrelated files were repaired.
