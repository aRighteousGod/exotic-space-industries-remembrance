# Fluid safety alert regression

Run the actual fluid owner against mutable engine boundaries:

```powershell
.tools/lua-5.4.8/lua54.exe scripts/qc/fluid-safety/runtime.lua
```

An optional first argument selects an earlier `fluid-safety.lua` for a before/after
comparison. The fixture exposes local functions only in its in-memory test copy.
It checks stale segment representatives over empty, water, oil and ordinary gas
networks; subsequent membership repair; rejection of phase shifts with no liquid
removed; nitrogen/oxygen conversion in segmented and unsegmented paths; and
destructive data-pipe processing after conversion.

For Factorio 2.0.77, use the existing isolated runner with a fresh short output
path, a known dependency seed, and a compatible fixture save:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/invoke-control-ups-qc.ps1 `
  -RunName fluid-alerts -BaselineSource exotic-space-industries-remembrance `
  -SeedModDirectory .factorio-qc/egi1/mods -SaveInput .factorio-qc/egi1/fixture.zip `
  -ExportsPath scripts/qc/fluid-safety/exports.json `
  -BridgePath scripts/qc/fluid-safety/bridge.lua -Ticks 60 -Runs 1
```

Keep Windows staging paths short enough for the dependency assets. Register generated
output under the housekeeping workflow. The bridge and private exports are injected
only into the staged main mod; the shipping mod gains no remote API or test exports.

Require `FLUID_NATIVE ALL_COMPLETE` and a successful benchmark exit. This fixture
uses real native pipe contents and deliberately stale persisted segment membership,
modeling a split/merge before queued membership repair. It verifies that ordinary
networks are unchanged, false vents/incidents are rejected, genuine nitrogen/oxygen
boiloff is admitted once, and the subsequent data-pipe breach still drains converted
gas. It tests incident admission directly; visible native delivery and multiplayer
coverage belong to the shared alert fixtures.

2026-10-25: 51 mocked-boundary assertions and 52 native assertions passed on 2.0.77.
The original source fails the stale-network/zero-drain regression. Evidence is retained
in `.factorio-qc/fb1/`; no visual or multiplayer acceptance is claimed by this fixture.
