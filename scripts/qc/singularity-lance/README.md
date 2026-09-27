# Singularity Lance upgrade verification

The helper is a test mod, never part of the shipping mod list. Its bridge is appended
only to the staged ESIR control file. Use Factorio 2.0.77 for this checkout.

```powershell
powershell -ExecutionPolicy Bypass -File scripts/invoke-singularity-lance-qc.ps1 -Mode mechanics -Runs 1 -Ticks 240
powershell -ExecutionPolicy Bypass -File scripts/invoke-singularity-lance-qc.ps1 -Mode mechanics -Fidelity lean -Runs 1 -Ticks 240
powershell -ExecutionPolicy Bypass -File scripts/invoke-singularity-lance-qc.ps1 -Mode mechanics -NoScaling -Flatten -Runs 1 -Ticks 240
powershell -ExecutionPolicy Bypass -File scripts/invoke-singularity-lance-qc.ps1 -Mode save
powershell -ExecutionPolicy Bypass -File scripts/invoke-singularity-lance-qc.ps1 -Mode reload -SaveInput .factorio-qc/lance/c-s-dense-standard-00/saves/lance-seven.zip -Runs 1 -Ticks 60
```

Repeat mechanics for all five fidelity presets and the four scaling/flattening
combinations. Data-stage assertions validate finalized ingredients and the ordinary
no-scaling normalization. Runtime assertions cover damage, caps, geometry, Wound,
Testament, diplomacy, source/surface removal, migration, reset/merge, native energy,
quality bounds, and normal/scripted research. Completion markers are mandatory.

For matched measurements, the runner uses the pre-change dirty source captured in
`.factorio-qc/singularity-lance/baseline-source`, with lance-owned files overlaid for
the candidate. This preserves unrelated work while the extinguisher integration is
in progress. Raw artifacts are under `.factorio-qc/lance`; do not commit those caches.

```powershell
powershell -ExecutionPolicy Bypass -File scripts/invoke-singularity-lance-qc.ps1 -Mode benchmark -Scene dense -Baseline -Ticks 720 -Runs 5
powershell -ExecutionPolicy Bypass -File scripts/invoke-singularity-lance-qc.ps1 -Mode benchmark -Scene dense -Ticks 720 -Runs 5
powershell -ExecutionPolicy Bypass -File scripts/invoke-singularity-lance-qc.ps1 -Mode benchmark -Scene normal-power -Profile -Ticks 720 -Runs 1
```

Benchmark scenes: `no-lance`, `idle`, `direct`, `normal-power`, `dense`, `diagonal`,
and `research`. Discard the first full warmup run; compare the remaining five runs.
Detailed profiling has a separate output directory and is disabled for ordinary
timing runs. The direct/dense/diagonal scenes inject artificial paid-shot callbacks
at 60 shots/second per lance; they do not model available power. Normal-power uses
the native weapon, shipped energy consumption, and a sufficiently supplied grid.
Idle and research have 96 registered lances; dense has 96 lances and 960 targets.
Research injects a burst of 100 unrelated completion callbacks once per second.

## Manual graphical acceptance

The user elected to perform gameplay visual acceptance manually. Headless results
do not establish visibility, alignment, animation timing, or acceptable screen noise.
Review at normal gameplay zoom in daylight and darkness, with Lean and Standard.

- **Axial Rupture:** a continuous narrow white core with two cyan fracture edges;
  horizontal and diagonal shots align with the actual ray and its endpoint. Check
  the 12-tile extension, the quality range boundary, and large target bounds. No
  clipped or lingering stacks of beam images.
- **Wound Memory:** distinguish split fracture at stacks 1–2, branching fracture
  at 3–4, and broken ring at 5 without relying on color. The mark follows moving
  enemies and remains readable on worms and spawners. It refreshes on successful
  hits and disappears after two seconds without a hit, retargeting, loss of the
  capability, target/source destruction, or protective diplomacy. Direct scripted
  ownership assignment is reconciled on the next lance interaction; native TTL
  bounds any old mark left while idle.
- **Terminal Collapse:** the warning ring contracts at the original aim point for
  30 ticks, then flashes on the damage tick. Moving the target must leave the ring
  behind. It replaces the ordinary splash and is distinct from the axial endpoint.
- **Black-Hole Testament:** every eighth paid shot has a dark seam and broad
  white/violet rim. Its collapse has a dark disk, bright annulus, and terminal cross.
  Check combined full Wound stacks and the eighth shot; both signatures should read.
- **Load and fidelity:** core shapes remain visible in Lean and the dense 96-lance
  scene. Decoration may be reduced; no excessive bloom, flicker, persistent scars,
  or obscured enemy silhouettes. Compare each upgrade alone and the full chain.
- **UI:** four distinct technology emblems at normal icon size; readable technology,
  item/entity/Factoriopedia tooltips; no unknown locale keys or clipped text. Open
  Informatron before and after research to check force-current values, unlock states,
  science icons, prerequisites, and the artwork legend. Japanese terminology and
  translated wrapping need ordinary in-game review.

Staged art: `output/singularity-lance-upgrades/preview.png`. The reproducible source
and layer/strip contracts are in
`.codex/esir/asset-generators/singularity-lance/upgrades/`.
