# Gleba Auric vat acceptance fixture

Factorio 2.0.77 validates live source against the installed dependency seed. This
fixture and its staging helper are independent of the Vulcanus `auric-productivity`
fixture, so either change can be delivered on its own.

Register workflow `gleba-auric-vat`, scenario `fuller-fields-and-native-washing`, and
preserve these pre-change files under the run's `baseline/` directory before edits:

- `prototypes/planet-gleba/auric-cysts.lua`
- `prototypes/planet-gleba/auric-inoculation-vat.lua`
- `scripts/control/auric-inoculation-vat.lua`

Run the phases sequentially:

```powershell
powershell -File scripts/invoke-gleba-auric-vat-qc.ps1 -RunId <id> -Phase Prepare
powershell -File scripts/invoke-gleba-auric-vat-qc.ps1 -RunId <id> -Phase Baseline
powershell -File scripts/invoke-gleba-auric-vat-qc.ps1 -RunId <id> -Phase Candidate
powershell -File scripts/invoke-gleba-auric-vat-qc.ps1 -RunId <id> -Phase NoScaling
powershell -File scripts/invoke-gleba-auric-vat-qc.ps1 -RunId <id> -Phase Dump
powershell -File scripts/invoke-gleba-auric-vat-qc.ps1 -RunId <id> -Phase Save
powershell -File scripts/invoke-gleba-auric-vat-qc.ps1 -RunId <id> -Phase Reload
# Interactive acceptance: opens a visible Factorio window and captures both panels.
powershell -File scripts/invoke-gleba-auric-vat-qc.ps1 -RunId <id> -Phase Visual -ShowVisualWindow
```

Baseline creates seven native vats with valid, discovered basin claims, living cyst
nodes and fermentation at 37.5%. Candidate verifies that identity, claims, progress,
vigor, contamination and prior research survive configuration change.

The staged-only bridge exercises actual owner functions on native entities. It
checks all seven ordinary/enriched yields, capacity saturation, one-slot capacity,
an exhausted placement list, both biological failure thresholds, blocked/cleared
drainage and snapshots with deliberately stale cached yields. Completion pulses
isolate these branches. A separate fully supplied cycle uses native phase recipes,
the normal dispatcher and real durations from seed through rest.

Seven native purifier clones consume 1,000 washing batches each: research levels
0, 10, 30 and 40; four current tier-3 productivity modules; ten levels plus modules;
and twenty-nine levels plus modules. Only clone speed, power, identity and placement
metadata change. Final module values determine expected bonuses. Gold and water
means must be within 5% of expectation; probabilistic spoilage within five standard
deviations (per-batch variance 4/3 for the 50% chance of 1-3 items). Waste
also remains within base output ranges. Consumed inputs count base crafts because
`products_finished` includes productivity crafts.

Final-data checks cover prerequisites, science, cost with global scaling on/off,
native effect, module eligibility, cap, temperature, pressure, byproduct exclusions
and protected hidden phases. Save runs an unlisted disposable server bound to
127.0.0.1:34419, writes a real checkpoint, and stops only that process. Reload checks
field state, research and installed modules. Visual captures native technology and
vat panels; inspect both images before claiming UI acceptance. Hidden single-player
loading did not advance this fixture, and a graphics benchmark has no local player,
so Visual requires explicit interactive opt-in. Native-language and
two-client multiplayer review are separate from this fixture.

Main pack/helper files are copied; immutable asset files are hard-linked and never
edited in staging. A temporary short mod-path junction is removed after each phase
and is outside the registered payload. Complete and close only this task's managed
run after retaining its reports, dump and reproduction metadata.
