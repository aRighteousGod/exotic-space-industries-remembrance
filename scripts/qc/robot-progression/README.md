# Advanced robot acceptance fixture

This opt-in companion uses live ESIR data and runtime controls. It never ships
inside the gameplay mod. Register a `robot-progression` artifact run using
`scripts/esir-housekeeping.ps1`, then invoke:

```powershell
powershell -File scripts/invoke-robot-progression-qc.ps1 -RunId <id> -Phase Prepare
powershell -File scripts/invoke-robot-progression-qc.ps1 -RunId <id> -Phase Baseline
powershell -File scripts/invoke-robot-progression-qc.ps1 -RunId <id> -Phase Candidate
powershell -File scripts/invoke-robot-progression-qc.ps1 -RunId <id> -Phase Save
powershell -File scripts/invoke-robot-progression-qc.ps1 -RunId <id> -Phase Reload
powershell -File scripts/invoke-robot-progression-qc.ps1 -RunId <id> -Phase Visual -ShowVisualWindow
```

`Prepare` stages immutable assets with hard links and gameplay source with ordinary
copies. The historical robot source comes from the pinned pre-feature revision
`747d349e3ab693e2acb436fe9a51cf9fbb9eda1d`; `-BaselineRevision` can select another
explicit pre-feature baseline when needed.
Other staged gameplay stays fixed across the comparison; the robot owner and its
late decomposition guard refresh from live source for each candidate phase.

`Baseline` creates a pre-feature save with Advanced bots already researched and a
placed Wraithline. `Candidate` loads it with the new prototypes at the same mod
version. Assertions cover native recipe refresh, a fresh research unlock, placed
entity identity, normal/rare assembler conversions and rejection of productivity.
Final-data comparisons protect earlier tiers, direct/recycling recipes, tech costs
and prerequisites, deaths, hit effects, sounds and native scenes.

The timing matrix runs 20 normal-quality robots per fleet on separate surfaces,
using identical advanced roboports and unlimited fixture power supplied only to
ports. Source/target origins are 32 or 128 tiles apart. Construction sites extend
9 tiles horizontally and 19 vertically from the target origin. Each case moves
2,000 iron plates, builds/deconstructs 200 walls, or repairs 40 damaged walls.
Profiles use speed/storage bonuses of 0/0 and +100%/+3. Results are sampled every
30 ticks; they are controlled workload comparisons, not universal throughput or
UPS claims. Twenty depleted bots of each family also exercise native recharging.

`Save` repeats only crafting/unlock checks and creates a real server checkpoint;
`Reload` verifies saved recipe availability and crafted qualities. It does not
repeat the fleet matrix. `Visual -ShowVisualWindow` opens a private graphical client and captures
conversion icons, an assembler window, both native Factoriopedia entity scenes
and both conversion recipe pages. Inspect screenshots before claiming visual
acceptance. Hidden normal-play and graphics-benchmark clients loaded but did not
advance capture ticks on this workstation, so visible-window permission is needed
for this phase. The runner terminates only the client/server it launched.

Keep runtime reports, final snapshots, captures and this reproduction information.
Complete and close the registered run after inspecting its evidence. No migration,
production control handler, new shipping graphics or locale key is needed.
