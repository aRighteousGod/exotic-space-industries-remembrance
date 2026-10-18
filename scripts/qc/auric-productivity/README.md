# Auric productivity acceptance fixture

Uses Factorio 2.0.77 and the dependency ZIP seed in `.factorio-qc/fmqc/mods-live`.
Shipping source and player saves are never used as writable staging. Asset files
are hard-linked read-only by convention; the main pack and helper are copied.
The short-lived mod-path junction is outside the registered payload and is removed
after each engine phase. The payload itself contains ordinary directories only.

Register a run and retain the **pre-feature** fumarole prototype before applying the
feature, or supply that file from a known pre-feature revision. Baseline mode rejects
a prototype that already declares the new technology.

```powershell
. ./scripts/esir-housekeeping.ps1
$record = Register-EsirArtifactRun -RepoRoot $PWD.Path -Workflow auric-productivity `
    -Scenario baseline-and-native-crafting -EngineVersion 2.0.77 `
    -Reproduction 'scripts/invoke-auric-productivity-qc.ps1; phases documented in scripts/qc/auric-productivity/README.md'
$baseline = Join-Path $record.payload_path 'baseline/exotic-space-industries-remembrance/prototypes/planet-vulcanus'
New-Item -ItemType Directory -Path $baseline -Force | Out-Null
Copy-Item <pre-feature-vulcanus-fumaroles.lua> (Join-Path $baseline 'vulcanus-fumaroles.lua')
powershell -File scripts/invoke-auric-productivity-qc.ps1 -RunId $record.id -Phase Prepare
powershell -File scripts/invoke-auric-productivity-qc.ps1 -RunId $record.id -Phase Baseline
powershell -File scripts/invoke-auric-productivity-qc.ps1 -RunId $record.id -Phase Candidate
powershell -File scripts/invoke-auric-productivity-qc.ps1 -RunId $record.id -Phase NoScaling
powershell -File scripts/invoke-auric-productivity-qc.ps1 -RunId $record.id -Phase Dump
powershell -File scripts/invoke-auric-productivity-qc.ps1 -RunId $record.id -Phase Save
powershell -File scripts/invoke-auric-productivity-qc.ps1 -RunId $record.id -Phase Reload
powershell -File scripts/invoke-auric-productivity-qc.ps1 -RunId $record.id -Phase Visual
```

Run phases sequentially. Save binds only `127.0.0.1:34418`, uses an unlisted
disposable server, accelerates simulation, waits for the checkpoint to finish, then
stops that process. Reload reads that real checkpoint. Generated startup settings
are discarded between phases so the selected scaling default is actually applied.

Visual uses a normal isolated graphical load with medium sprite detail and low
video-memory usage. It closes the fixture's introductory panels and requests the
research window at player join, with a second request after 60 updates. It captures
the client resolution and stops its own process after the PNG is readable.
Inspect the image: creating a PNG alone is not a UI pass.

Final-data checks cover the single washing effect, both prerequisites, six science
packs, time/cost under both scaling modes, infinite levels, module eligibility,
productivity cap, ingredient/output ranges and gold-only bonus eligibility. Dump
retains the engine's complete `script-output/data-raw-dump.json` separately.

Runtime loads the pre-feature save and checks preserved milestone research, initial
availability, both missing-prerequisite cases, and a normal queued research
completion. Six accelerated native purifier clones consume 1,000 washing batches
each: zero, ten, thirty and forty research levels; four current tier-3 productivity
modules alone; and twenty-nine levels with those modules. Clones change only speed,
power supply, placement identity and upgrade/mining metadata, retaining the actual
washing recipe and purifier module/fluid behavior. Gold and waste means must stay
within 5% of their expected values; waste must also remain within its base range.
`products_finished` includes bonus crafts, so consumed batches establish base
craft counts. Module productivity is taken from final prototypes, not assumed.

`Candidate-auric-runtime.json` and `NoScaling-auric-runtime.json` retain the cases;
the corresponding `*-final-data.json` files retain resolved prototypes.
`Reload-auric-reload.json` verifies researched levels and machines survived the
checkpoint. Inspect `Visual-auric-research.png` for native research presentation;
headless assertions do not establish visual readability or native-language review.

After reviewing evidence, complete the registered run with its actual summary and
dump, then close its task ownership through the housekeeping helpers. Broad ESIR
preflight/QC failures remain separate from this focused fixture's result.

## Validation evidence (2026-10-18)

Both scaling profiles passed 26 final-data assertions and all six 1,000-batch
crafting cases. Normal research completion, pre-feature save admission, prerequisite
gates, and a real server checkpoint/reload passed. The complete engine dump's auric
technology and washing recipe matched the focused final-data snapshot exactly.

The graphical capture loaded successfully but showed the engine's consistency
loading overlay with `gui_type = 0`; it does **not** establish research-screen
acceptance. Native GUI and native-language review remain unverified. Broad wrappers
hit existing minigun scratch long paths; the session-only `rg` enumeration workaround
left unrelated minigun blueprint, protected Python cache, encoding and header findings.
