# Slag recovery acceptance fixture

The helper mod is disposable and never ships with ESIR. It captures the merged
recipes and technology through `mod-data`; its only prototype addition is a
purifier clone with void power and speed 60. Recipe times, products, probabilities,
module rules and native research effects are unchanged by the fixture.

Register a `slag-recovery` / `research-only` managed run with engine 2.0.77 through
`scripts/esir-housekeeping.ps1`. Before editing, copy the current purifier.lua and
vulcanus-fumaroles.lua source files into that run's `baseline/` directory. Keep
those independent copies as the pre-change recipe baseline.

```powershell
$runId = '<registered run id>'
powershell -ExecutionPolicy Bypass -File scripts/invoke-slag-recovery-qc.ps1 -RunId $runId -Phase Prepare
powershell -ExecutionPolicy Bypass -File scripts/invoke-slag-recovery-qc.ps1 -RunId $runId -Phase Baseline
powershell -ExecutionPolicy Bypass -File scripts/invoke-slag-recovery-qc.ps1 -RunId $runId -Phase Candidate
python -B scripts/qc/slag-recovery/check.py ".factorio-qc/managed/$runId"
powershell -ExecutionPolicy Bypass -File scripts/invoke-slag-recovery-qc.ps1 -RunId $runId -Phase Save
powershell -ExecutionPolicy Bypass -File scripts/invoke-slag-recovery-qc.ps1 -RunId $runId -Phase Reload
```

Prepare stages current gameplay source and hardlinks immutable graphics/dependency
assets. Each phase selects the old or current two recipe files and increments
only the helper mod version. The main mod version is never modified.

Baseline creates a pre-change save with all six recipes selected at extraction
research levels 0, 1 and 5. Candidate upgrades that save and completes 2,000 base
crafts for each of the 18 cases. It checks common-output floors on each collected
craft, native bonus-craft counts, module rejection, and product totals within six
standard deviations (plus two units for rounding). Fluid waste and both independent
crystal rolls are measured against base crafts, excluding productivity crafts.
Recipe research bonus is read from the force's LuaRecipe. The observed entity
productivity_bonus field stays zero in these research-only cases; native bonus
craft counts verify the recipe research effect independently of that field.

The Python check compares fresh baseline and candidate final data, verifies the
approved values and unchanged presentation/adjacent recipes/research, and derives
the lead/gold feedback return from final upstream prototypes. Save repeats the
native acceptance run in a private loopback server and writes a checkpoint;
Reload verifies recipe selections and research persistence from that checkpoint.
This server fixture is not multiplayer gameplay or visual acceptance.

Retain the compact JSON reports and logs in the registered run. Complete and close
only the task-owned run through housekeeping after inspecting all results. General
QC/preflight failures are separate from the focused verdict.
