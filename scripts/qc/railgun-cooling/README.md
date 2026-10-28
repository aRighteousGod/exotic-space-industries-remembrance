# Railgun inserter and coolant regression

Current upgrade acceptance uses `scripts/qc/factorio-2.1/stage_railgun.py` with
a new short run path. Select `--version 2.0 --mode donor` for the preserved donor,
default 2.1 fresh mode for current native checks, or `--mode migration` to adopt
the donor. `save_checkpoint.py` waits for `railgun-baseline.zip` or
`railgun-accepted.zip`; reload mode verifies another 600 ticks and saves
`railgun-reloaded.zip`. The fixture uses insulated fluoroketone lines, separates
native connected segments from private helper buffers, and compares all 296
helper identities plus populated coolant and pending heat-debt state on adoption.
Cold/hot native capacities must remain 30/60 and cooled shots convert 10/10.
The 2.1 API needs no gameplay bridge or private remote interface in the shipped mod.

The commands and historical results below target the original 2.0 fixture.

Run `scripts/invoke-esir-dev.ps1 -Task qc-fast` first to refresh the dependency seed,
then run these commands from the repository root:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/invoke-railgun-cooling-qc.ps1 -Baseline
powershell -ExecutionPolicy Bypass -File scripts/invoke-railgun-cooling-qc.ps1
powershell -ExecutionPolicy Bypass -File scripts/invoke-railgun-cooling-qc.ps1 -Baseline -SaveBaseline
powershell -ExecutionPolicy Bypass -File scripts/invoke-railgun-cooling-qc.ps1 -SaveInput .factorio-qc/railgun-cooling/baseline/saves/railgun-baseline.zip
```

The runner stages a disposable gameplay copy and a private QC interface under
`.factorio-qc/railgun-cooling/`. Baseline mode removes only the two item-handling
flags and the corresponding migration from that copy. Installed mods and user
saves are untouched. `-SaveBaseline` briefly runs a local headless server to save
the broken layout before any repair, then stops that server.

Coverage:

- Discover legal native inserter placements against a helper-free railgun in all
  eight orientations, including the indented edges of diagonal collision shapes.
- Test both inserter-first and railgun-first placement, native drop targets, and
  actual chest-to-turret ammo delivery. No inserter targets are scripted by the fixture.
- Repeat target and ammo checks after helper rebuild and object-destruction recovery.
- Feed cold fluoroketone through real pipes, invoke the production shot callback,
  and verify consumption of 10 cold fluid and export of 10 hot fluid in every orientation.
- Load the pre-fix save with the new migration and verify repaired inserter targets,
  ammo delivery, preserved helper identities, fluid contents, and pipe connections.

Factorio 2.0.77 verification on 2026-09-24: the baseline saved layout had 120
helper-targeting failures among 288 valid placement cases. The fixed fresh layout
and migrated layout pass all 288 cases; all eight coolant rigs pass. Reports are
written to each profile's `script-output/railgun-qc.json`.

This is a headless logistics and coolant-handler test. It does not test rendering,
manual GUI interaction, or target acquisition and projectile damage in live combat.
