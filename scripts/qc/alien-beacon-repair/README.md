# Alien beacon repair regression

The focused runner uses Factorio 2.0.77 and the actual Nonstandard Beacons 1.4.2
archive. It copies gameplay sources into registered staging and appends a QC-only
remote bridge to the staged dispatcher. Source mods and the input save are not
modified. Use a disposable fixture save that contains a native player with a
cursor stack; a bare `--create` save has no player.

Register an `alien-beacon-repair` run through `scripts/esir-housekeeping.ps1` and
preserve the pre-fix `scripts/control/alien-system.lua` at
`<payload>/baseline/alien-system.lua` when testing the baseline. Then run:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/invoke-alien-beacon-repair-qc.ps1 -RunId <id> -Phase Prepare -SavePath <fixture.zip>
powershell -ExecutionPolicy Bypass -File scripts/invoke-alien-beacon-repair-qc.ps1 -RunId <id> -Phase Baseline -SavePath <fixture.zip>
powershell -ExecutionPolicy Bypass -File scripts/invoke-alien-beacon-repair-qc.ps1 -RunId <id> -Phase Candidate -SavePath <fixture.zip>
```

The baseline must reproduce the exact `control.lua:556` nil-metadata error after
native hover selection. Candidate coverage repairs all three damaged variants at
normal and legendary quality. It checks cursor consumption, preserved force,
position and quality, exactly one build notification and fuel source, dependency
metadata, fuel consumption, beacon activation, native hover-status execution,
and cleanup through the standard destruction event.

The fixture calls ESIR's existing selection receiver through its staging bridge;
it does not simulate mouse dragging or review rendered UI. No multiplayer or
existing-player-save acceptance is implied. The runner writes logs and a JSON
result under the registered payload. Complete and close that run after reviewing
the evidence; the expected baseline crash is a successful reproduction.
