# Plasma smelting acceptance

Register a `plasma-smelting` / `conservative-six-recipes` housekeeping run for
Factorio 2.0.77. Before editing, copy the main mod into the run's
`baseline/exotic-space-industries-remembrance` directory using long-path-safe
file copies. Run these phases separately through the repo wrapper:

```powershell
powershell -File scripts/invoke-plasma-smelting-qc.ps1 -RunId <id> -Phase Prepare
powershell -File scripts/invoke-plasma-smelting-qc.ps1 -RunId <id> -Phase Baseline
powershell -File scripts/invoke-plasma-smelting-qc.ps1 -RunId <id> -Phase Candidate
powershell -File scripts/invoke-plasma-smelting-qc.ps1 -RunId <id> -Phase Save
powershell -File scripts/invoke-plasma-smelting-qc.ps1 -RunId <id> -Phase Reload
```

Baseline runs all six feedstocks in both native furnaces, then saves at a craft
boundary with input items, molten fluid and slag buffered. Candidate loads the
save with the live mod and checks identity, inventory/fluid preservation, old
research and new unlocks. Thirty-six native machines process 100 batches each
at zero, inherited and above-cap research. Only their electrical buffers are
replenished by the fixture; machine speed, categories, outputs and productivity
are unmodified. Fluid and item outputs are collected each tick.

Final-data assertions cover six recipes, thirty research effects, unlocks,
categories, icons and inherited entity presentation. Baseline comparison covers
all existing arc/gas recipes, protected machine fields and research definitions.
Save writes a real candidate checkpoint; Reload checks its machines and research.
Servers are unlisted, bound to 127.0.0.1:34420, and terminated after save completion.
Immutable assets are hard-linked through the shared auric fixture staging helper;
main-mod files are copied. The wrapper removes its temporary short-path junction.

Reports remain in the registered run. Headless checks do not establish graphical
UI appearance, native-language acceptance, electricity consumption measurements,
or optional Krastorio gameplay. Power estimates come from unchanged prototypes.
