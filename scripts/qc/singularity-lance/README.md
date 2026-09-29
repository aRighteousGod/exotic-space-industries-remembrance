# Singularity Lance upgrade verification

The current Full Hybrid contract is schema 12, with an explicit in-place schema-11
migration. See `hybrid-verification.md` and `hybrid-results.json` for this enhancement's
evidence. Older reports below retain their historical values and measurements.

The helper is a test mod, never part of the shipping mod list. Its bridge is appended
only to the staged ESIR control file. Use Factorio 2.0.77 for this checkout.

```powershell
powershell -ExecutionPolicy Bypass -File scripts/invoke-singularity-lance-qc.ps1 -Mode mechanics -Runs 1 -Ticks 240
powershell -ExecutionPolicy Bypass -File scripts/invoke-singularity-lance-qc.ps1 -Mode mechanics -Fidelity lean -Runs 1 -Ticks 240
powershell -ExecutionPolicy Bypass -File scripts/invoke-singularity-lance-qc.ps1 -Mode mechanics -NoScaling -Flatten -Runs 1 -Ticks 240
powershell -ExecutionPolicy Bypass -File scripts/invoke-singularity-lance-qc.ps1 -Mode save
powershell -ExecutionPolicy Bypass -File scripts/invoke-singularity-lance-qc.ps1 -Mode reload -SaveInput .factorio-qc/lance/c-s-dense-standard-00/saves/lance-seven.zip -Runs 1 -Ticks 60
```

Use `-CurrentSource -RunName <fresh-name>` for current development. `-BaselineSource`
selects a frozen main-pack snapshot, `-FixtureSource` selects an identical helper
for matched old/new benchmarks, and `-MapSeed` defaults to 410728. A current-source
baseline with its four old upgrades enabled must **not** use `-Baseline`, which
selects the older pre-upgrade comparison mode. Benchmark targets have one billion
health and an end-of-run population assertion so stronger damage does not remove
query candidates. The first complete engine run is discarded as warmup.

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

- **Axial Rupture:** the main beam leaves the raised crystal and reaches the actual
  aim point. Its dedicated cyan source aperture transitions into the upgraded
  prismatic body; Testament instead opens around a dark throat with a bright rim.
  The regular beam keeps its original opening. Inspect the scaled flares at the
  fork for excessive brightness.
  The forward incision continues up to 24 tiles, and two narrower rays
  fork there at ±15° for up to 18 tiles. Inspect cardinal/diagonal shots, quality
  range and native-approved large-target bounds. All four segments must connect;
  retain saturated moving material, tails, original impact bloom and terrain light.
  Rapid firing and retargeting must not leave stacks of old segments.
- **Wound Memory:** distinguish split fracture at stacks 1–2, branching fracture
  at 3–4, and broken ring at 5 without relying on color. The mark follows moving
  enemies and remains readable on worms and spawners. It refreshes on successful
  hits and disappears after two seconds without a hit, retargeting, loss of the
  capability, target/source destruction, or protective diplomacy. Direct scripted
  ownership assignment is reconciled on the next lance interaction; native TTL
  bounds any old mark left while idle.
- **Terminal Collapse:** the outer warning contracts at the fixed aim point for
  30 ticks while the 1.5-tile core boundary remains legible within the 4-tile blast.
  A stronger central flash marks damage. Moving the target leaves the warning
  behind. It replaces ordinary splash and is distinct from the incision endpoint.
- **Black-Hole Testament:** every eighth paid shot has a dark seam and broad
  prismatic banks. Its first warning has a 3-tile core within a 6-tile blast. At
  tick 30 the first contact remains visible above the second warning; at tick 60
  the radius-5 echo ends in its terminal cross. Check full Wound (+100%) together
  with the eighth-shot signature and rapid-fire visual hold.
- **Load and fidelity:** core shapes remain visible in Lean and the dense 96-lance
  scene. Decoration may be reduced; no excessive bloom, flicker, persistent scars,
  or obscured enemy silhouettes. Compare each upgrade alone and the full chain.
- **Player information:** inspect long technology descriptions, effect rows,
  item/entity/Factoriopedia tooltips, force-current status and Informatron wrapping.
  Wound should read +20% on the first hit through +100% on the fifth; the page must
  explain branch caps, center-based core/outer selection, reserved primary slots,
  and both impact times. Check all maintained locales where available.
- **UI:** four distinct technology emblems at normal icon size; readable technology,
  item/entity/Factoriopedia tooltips; no unknown locale keys or clipped text. Open
  Informatron before and after research to check force-current values, unlock states,
  science icons, prerequisites, and the artwork legend. Japanese terminology and
  translated wrapping need ordinary in-game review.

Current staged art: `output/meshy/lance-prismatic-liturgy/hybrid/hybrid-board.png`
and `hybrid-timeline.webp` (four-times slower playback). The reproducible source,
manifest and layer/strip contracts are in
`.codex/esir/asset-generators/singularity-lance/prismatic-redesign/HYBRID.md`.
The earlier upgrade-art preview remains historical evidence only.
