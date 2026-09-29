# Event tick propagation

Use the existing isolated runtime runner. The private exports and event bridge
are inserted into its staged copy only; shipping modules expose no QC hooks.

```powershell
powershell -ExecutionPolicy Bypass -File scripts/invoke-control-ups-qc.ps1 `
  -RunName event-tick -BaselineSource output/event-tick-audit/before `
  -BridgePath scripts/qc/event-tick/bridge.lua `
  -ExportsPath scripts/qc/event-tick/exports.json -Ticks 600 -Runs 1
```

Choose a fresh run name for each run. Require `EVENT_TICK ALL_COMPLETE` in the
benchmark log as well as a successful engine exit. Do not use `-Probe`, which
selects the separate control UPS suite. Run after other Factorio QC processes
finish; the runner refuses concurrent engines.

The checks use supplied ticks deliberately different from `game.tick` and cover
tick zero, Tesla burst cooldown and hit expiry boundaries, fluid warning rate
limits, EM glow timestamps, and neutron GUI deadlines and budget dispatch.
The remaining 600-tick run checks ordinary engine initialization and updates.
Singularity Lance and Flex Radar have no targeted checks in this fixture.

## Verified 2026-09-28

Factorio 2.0.77 passed all 22 assertions and completed 600 updates in the
isolated `et0928b` profile. The 14 changed runtime files matched the source
hashes recorded before staging. Evidence is in
`.factorio-qc/cu/g/et0928b/benchmark.log` and
`output/event-tick-audit/result.json`.

Lua syntax, tick-variable scope, encoding, references, and whitespace checks
passed. The preflight wrapper's Python bytecode writes hit protected paths,
then the redirected cache exceeded Windows path limits; a read-only compile
of all 90 Python files passed. Two existing module-header warnings remain.
This fixture does not claim multiplayer or interactive GUI coverage.
