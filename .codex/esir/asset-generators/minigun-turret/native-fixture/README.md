# Minigun native graphics fixture

This standalone, disposable Factorio **2.0.77** mod tests graphics contracts. It
is not loaded by the shipping ESIR mod. Generating its PNGs or staging its mod
directory does not establish native correctness. The launcher defaults to
`-Task Stage`; only the explicit `-Task Run` starts Factorio.

<a id="contract"></a>
## Ownership and lifecycle

`contract.lua` owns physical source indices and state identifiers.
`data-final-fixes.lua` creates fixture turret clones from the final ESIR turret.
Its one temporary ammunition source observer exists only in this isolated mod
set and counts consumption independently of damage/spider action branches.
Candidate and legacy diagnostic clones explicitly clear
`attack_parameters.shell_particle` so ejected casings cannot cover their
barcodes. This is recorded in the diagnostic PNG manifest and native report.
Production turret shells and the actual firing-appearance fixture remain
untouched; attack speed, cooldown, ammunition damage/delivery and the source
observer remain intact. The barcode classifier is unchanged.
`control.lua` is this fixture mod's sole event dispatcher. It owns bounded test
rows in `storage`, uses supplied event ticks, and stops at elapsed tick 1550.
It neither imports nor changes ESIR's runtime dispatcher or scheduler.

`build_fixture.py` creates lossless diagnostic PNGs. `analyze_fixture.py` reads
actual engine captures, preserves them outside disposable staging and reports
failures separately from engine startup. The fixture makes no production
approval decision: `production_approved` is always false.

The fixture's small, purpose-specific callbacks and source-index functions do
not initialize ESIR's shared runtime globals. They are test instrumentation,
not replacement production entity guards, queues or scheduling APIs.

## Layout and native states

- Physical rotor source: **28 frames x 256 directions**, 64 x 32 pixels per cell.
- Seven columns, four rows per direction, eight directions per file: 32 files
  of **448 x 1024** pixels. `filenames`, `slice=7`, `line_length=7`,
  `lines_per_file=32`, physical `frame_count=28` on every rotor leaf.
- Park `{1}`, run `{2}`, prepare `{1,3..12,2}`, fold `{2,13..28,1}`.
- Upper: one physical frame per direction, `repeat_count=12/18` in transitions.
- Fixed base: plain one-frame `Animation` in `base_visualisation`, no direction
  count and `turret_base_has_direction=false`.
- Eight independent `enabled_states` markers identify folded, preparing,
  prepared, starting-attack, attacking, ending-attack, rotate-for-folding and
  folding. A separate state probe adds four-tick starting/ending states solely
  to make those normally instantaneous states observable; it is excluded from
  sustained-DPS comparisons. Unobserved states remain explicitly reported.

Frozen layout clones select each physical pose independently. Their heading is
stepped through all 256 projected sprite directions. This tests **7168 native
source cells**, including temporal row wrapping, every file boundary, and the
last direction. It also compares static upper direction and fixed-base pixels.
Actual 12/18 playback and repeat counts are tested separately in active turrets.
Frozen probes cannot establish animation timing by themselves.

The fixed-base comparison holds each world position constant across all 256
headings; different positions can have different environmental lighting. The
cross-position hash count is retained as context, not treated as rotation.
Barcode extraction samples only the known opaque 5 x 6 source-pixel patches.
It requires a strict black/white majority and rejects conflicting polarity or
an ambiguous patch. Intermediate colors from casings/tracers do not vote.
Every decoded capture retains its confidence and original single-pixel result;
revised analyses belong in a fresh directory so earlier verdicts stay intact.

The baseline's `attacking_speed=20` and cooldown 0.25 are asserted and preserved.
Both legacy and candidate must emit and consume **660 shots in [90,750)**.
Candidate primary/secondary preparation speeds are 1/12 and folding speeds 1/18.
First-shot delay, native state spans, pose ordering, retargeting and return to
folded are retained; no strict legacy first-shot parity is demanded. The
accepted 45-tick activation ceiling is a hard upper bound, not the target.
The source sequences contain 12 and 18 indices; these counts are not evidence
of an equal number of screenshots with the native state marker. The analyzer
reports state entry/exit, visible state span and endpoint-to-endpoint elapsed
ticks separately, including endpoint poses shown in adjacent native states.
Review these measured values before claiming a precise elapsed duration.

Spin-up target loss is requested at 3/6/9 ticks after acquisition. Spin-down
reacquisition is requested 5/9/14 ticks after the estimated native fold start.
The runtime API does not expose native animation phase: **do not claim these
requests hit the intended phase without examining the decoded frames**. The
first run measures fold start after target loss; stage a fresh run with
`-FoldDelayTicks <measured delay>` if needed. The report includes two frames on
either side of each interruption. Reversal, reset, orientation movement and
the rotate-for-folding state require explicit review, not a runtime workaround.

## Shadow calibration

Nineteen cases compare alpha 64/128/192 via the actual base visualisation and
two state animation leaves. Base-only reference controls supply candidate
minimum/maximum/alpha-over/clamped-add results. Reversed leaf order and
base-versus-upper ownership comparisons are included. Measurements use the
same engine-rendered neutral background and central pixels, not assumed gamma
or shadow tint. Four RGB levels of residual tolerance allow scalar PNG/engine
quantization; ambiguous or ownership-dependent results fail the automated gate.

This determines only scalar accumulation. It does **not** approve recomposed
real-geometry shadows, antialiased edges, penumbrae or mixed SD/HD family seams.
Those require comparison against an all-caster rendered union reference.

## Commands

From the repository root, without launching Factorio:

```powershell
python -B .codex/esir/asset-generators/minigun-turret/native-fixture/build_fixture.py
powershell -File .codex/esir/asset-generators/minigun-turret/invoke-native-fixture.ps1 -Task Stage -Mode on
```

After the main task authorizes the serial native run, use the printed payload:

```powershell
powershell -File .codex/esir/asset-generators/minigun-turret/invoke-native-fixture.ps1 -Task Run -RunPath "<managed payload>"
```

Stage and run a separate `-Mode off` fixture. `-Task Analyze -RunPath ...`
re-decodes existing native evidence without launching the engine. A failed
engine run remains protected for investigation. An executed run retains its
summary, raw report, logs and all screenshots under the minigun dossier's
`native-fixture/` output directory; source and temporary junctions are verified
and unlinked nonrecursively. Reusing a completed payload to overwrite native
evidence is refused. Changes to the production turret after staging require
fresh staging.

The launcher pins the existing repository QC dependency seed, uses isolated
startup settings, asserts engine version at execution, and refuses concurrent
Factorio or background Blender processes. It does not alter live mod selection.
