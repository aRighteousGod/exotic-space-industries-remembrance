# Cryo container acceptance fixture

Run from the repository root with Factorio 2.0.77 and the ESIR dependency seed
already populated by `scripts/invoke-esir-dev.ps1 -Task qc-fast`.

```powershell
powershell -File scripts/invoke-cryo-container-qc.ps1 -Capacity 50
powershell -File scripts/invoke-cryo-container-qc.ps1 -Capacity 1000
powershell -File scripts/invoke-cryo-container-qc.ps1 -Capacity 2000
```

Each run registers an isolated payload under `.factorio-qc/managed`, copies the
main pack, links asset packs, and uses a private startup capacity. No shipping
setting defaults or player saves are changed. `script-output/cryo-final-data.json`
records the resolved recipes, items, technologies, machine categories and assertions;
`cryo-runtime.json` records native assembler round trips and research checks.

The final-data fixture checks the closed nine-fluid registry, conservation flags,
fixed temperatures, exact unlock ownership, final science sets, prerequisite cycles,
and both ordinary-barrel unlocks for acidic water and the fluoroketones. Runtime
checks exercise filling and emptying in assembling-machine-3, exact container/fluid
return, and rejection of an incorrect temperature when the engine can represent it.
Each family is tested with both prerequisites and with each prerequisite missing.

For upgrade coverage, provide a **pre-feature main-mod directory**. Baseline mode
rejects sources that already include the propellant family. It completes the old
cryo researches and all four production milestones before saving.

```powershell
powershell -File scripts/invoke-cryo-container-qc.ps1 -Phase Baseline -SourceRoot <pre-feature-main-mod>
powershell -File scripts/invoke-cryo-container-qc.ps1 -Capacity 1000 -SaveInput <baseline-payload>/fixture.zip
```

The upgraded save must retain nitrogen/oxygen research, leave all four new families
unresearched, and accept their research with the completed prerequisites.

`-Visual` runs the native graphics benchmark and captures the item/fill/empty grid,
assembler selection, two Factoriopedia entries and Aquilan research. Deep Windows
workspace paths may require a short junction to the payload for the game's
`--mod-directory` argument. Retain screenshots and review them; successful data
checks do not establish visual readability or native-language translation quality.

The full repository preflight and `qc-fast` remain separate checks. If their traversal,
storage or unrelated source checks fail, report those separately from this fixture.
Close this task's artifact run IDs after reviewing the evidence.
