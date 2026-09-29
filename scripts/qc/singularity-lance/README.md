# Singularity Lance upgrade verification

The current angular-sweep contract is schema 14, preserving schemas 11, 12 and 13
in place. Read [the maintenance reference](../../../docs/singularity-lance.md) for
baseline/upgrade mechanics, transaction ordering, presentation and lifecycle rules.
See `angular-verification.md` and `angular-results.json` for current evidence. Older
reports retain their historical values and measurements.

The helper is a test mod, never part of the shipping mod list. Its bridge is appended
only to the staged ESIR control file. Use Factorio 2.0.77 for this checkout.

```powershell
powershell -ExecutionPolicy Bypass -File scripts/invoke-singularity-lance-qc.ps1 -Mode mechanics -CurrentSource -RunName lance-check-standard -Runs 1 -Ticks 340
powershell -ExecutionPolicy Bypass -File scripts/invoke-singularity-lance-qc.ps1 -Mode mechanics -CurrentSource -RunName lance-check-lean -Fidelity lean -Runs 1 -Ticks 340
powershell -ExecutionPolicy Bypass -File scripts/invoke-singularity-lance-qc.ps1 -Mode mechanics -CurrentSource -RunName lance-check-flatten -NoScaling -Flatten -Runs 1 -Ticks 340
powershell -ExecutionPolicy Bypass -File scripts/invoke-singularity-lance-qc.ps1 -Mode save -CurrentSource -RunName lance-check-save
powershell -ExecutionPolicy Bypass -File scripts/invoke-singularity-lance-qc.ps1 -Mode reload -CurrentSource -RunName lance-check-reload -SaveInput .factorio-qc/cu/l/lance-check-save/saves/lance-seven.zip -Runs 1 -Ticks 60
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

The historical first-upgrade comparison used the pre-change dirty source captured in
`.factorio-qc/singularity-lance/baseline-source`, with lance-owned files overlaid for
the candidate. This preserved unrelated work during the extinguisher integration.
Its raw artifacts remain under `.factorio-qc/lance`; do not commit those caches.

That default snapshot describes the historical first-upgrade comparison. For the
schema-13 restoration, use explicit `-CurrentSource -BaselineSource` snapshots
under `.factorio-qc/sweep/before` and `after`, without `-Baseline`; both sides have
the Full Hybrid upgrades enabled. Use `.factorio-qc/sweep/fixture-before` only for
the old side's unchanged benchmark driver. Run the new helper on the candidate.
These ignored snapshots are retained local evidence inputs, not files supplied
by a fresh clone. For a new comparison, capture separate before/after source and
fixture snapshots before editing; the generated report records measured source
hashes. The current-source mechanics commands above do not require those snapshots.
For schema 14 comparisons, freeze both sources under `.factorio-qc/angular/before`
and `after`, and pass the same updated `-FixtureSource` to both sides. Include
`wide-native` and `wide-burst`. The former has four separated, powered lances with
alternating hostile targets every 40 ticks; the latter injects one paid shot per
lance per tick toward alternating distinct targets. Both exercise near-half-turns.
Neither target teleportation nor same-identity movement can substitute for retargeting.

`-InFlight` with `save`/`reload` exercises an eighth shot saved before contact;
ordinary `save` preserves counter seven and seven outstanding first collapses.
Use `-WideFlight` with `save`/`reload` for an actual schema-14 save containing a
half-turn and queued successor. `read-angular-prototypes.py <data-raw-dump.json>`
streams final lance research/native-power records from the live wrapper's large
prototype dump without loading the entire file into memory.

```powershell
powershell -ExecutionPolicy Bypass -File scripts/invoke-singularity-lance-qc.ps1 -Mode benchmark -Scene dense -CurrentSource -BaselineSource .factorio-qc/angular/before -FixtureSource .factorio-qc/angular/fixture -RunName lance-check-before-dense -NoCounters -Ticks 600 -Runs 5
powershell -ExecutionPolicy Bypass -File scripts/invoke-singularity-lance-qc.ps1 -Mode benchmark -Scene dense -CurrentSource -BaselineSource .factorio-qc/angular/after -FixtureSource .factorio-qc/angular/fixture -RunName lance-check-after-dense -NoCounters -Ticks 600 -Runs 5
powershell -ExecutionPolicy Bypass -File scripts/invoke-singularity-lance-qc.ps1 -Mode benchmark -Scene normal-power -CurrentSource -BaselineSource .factorio-qc/angular/after -FixtureSource .factorio-qc/angular/fixture -RunName lance-check-profile-power -Profile -Ticks 600 -Runs 1
```

Benchmark scenes: `no-lance`, `idle`, `direct`, `normal-power`, `dense`, `diagonal`,
`research`, `wide-native`, and `wide-burst`. Discard the first full warmup run; compare the remaining five runs.
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

- **Acquisition:** the first beam grows from the crystal. Later attacks sweep from
  the last endpoint, while attacks on the same moving target remain visually locked.
  Wide turns follow a smooth arc around the crystal, with beam length interpolated
  separately: check 90 degrees (15 ticks) and 180 degrees (30 ticks), including
  moving enemies crossing the angle boundary. First acquisition and short turns
  take eight ticks. Crossing other enemies during the sweep does not damage them.
  Rapid bursts retain full turns until the 60-tick payment-to-contact bound forces
  catch-up. No beam trail stack, center-crossing, disappearance or abrupt reversal.
- **Axial Rupture:** the main beam leaves the raised crystal and reaches the actual
  contact point. Its dedicated cyan source aperture transitions into the upgraded
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
- **Terminal Collapse:** the outer warning contracts at the fixed contact point for
  30 ticks while the 1.5-tile core boundary remains legible within the 4-tile blast.
  A stronger central flash marks damage at 30 ticks after contact. Moving the target leaves the warning
  behind. It replaces ordinary splash and is distinct from the incision endpoint.
- **Black-Hole Testament:** every eighth paid shot has a dark seam and broad
  prismatic banks. Its first warning has a 3-tile core within a 6-tile blast. At
  30 ticks after contact, the first impact remains visible above
  the second warning; at 60 ticks after contact, the radius-5 echo
  ends in its terminal cross. Check full Wound (+100%) together
  with the eighth-shot signature and rapid-fire visual hold.
- **Lighting:** beam middle/end terrain light randomly varies among cyan, cobalt,
  magenta, violet, orange and gold at one quarter of the prior preset strength.
  The crystal-side tail stays violet. Contact adds a five-tick matching flash and finite matching
  afterglow. Inspect actual terrain illumination, including source opening and
  original impact bloom, in daylight and darkness.
- **Load and fidelity:** core shapes remain visible in Lean and the dense 96-lance
  scene. Decoration may be reduced; no excessive bloom, flicker, persistent scars,
  or obscured enemy silhouettes. Compare each upgrade alone and the full chain.
- **Player information:** inspect long technology descriptions, effect rows,
  item/entity/Factoriopedia tooltips, force-current status and Informatron wrapping.
  Wound should read no bonus on the first hit, +20% on the second, and +100% on the sixth; the page must
  explain branch caps, center-based core/outer selection, reserved primary slots,
  and both contact-relative impact times. Check all maintained locales where available.
  The native green-diode row must contain only compact baseline DPS, such as
  `Base direct DPS: 3.65k`, on one line. Inspect the lore's last word above the
  separator separately, at ordinary and enlarged UI scales; a shorter status alone
  does not establish that the screenshot's clipping has been repaired.
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
