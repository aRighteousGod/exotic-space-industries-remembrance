# ANISETRON stability correction - October 7, 2026

Engine: installed Factorio **2.0.77**, build 84539. These are current worktree
results. No Git commit, push, package deployment, model generation, material
edit, or sprite rerender is part of this correction.

## Production changes

- Native beam start/ending artwork is retained for all 42 ANISETRON variants.
  The separate ground ray is empty; the core and its additive glow share the
  original aligned layers. The redundant script source halo is removed.
- Native bob speed changes from .08 to 1, retaining height 1.8 and four legs.
  The old empirical speed-dependent decorative lift becomes zero.
- Trail direction uses clockwise screen coordinates consistently for rendering
  and hull clearance. A downward component keeps N/NE trails out of the hull.
  Zero prototype shift plus an explicit half-length center offset preserves
  the crystal root when stretching the animation. All eight physical tips,
  visibility rules, thinness, finite lifetimes and fidelity budgets remain.
- The positive native slowing floor changes from .20 to .50. Enemy stickers,
  their lifetimes and damage, zero-modifier stuns and hard speed caps remain.
  Normal travel and the existing four-leg gait are unchanged.

## Movement evidence

All run paths below are under `.factorio-qc/anisetron/`.

| Probe | Result |
|---|---|
| `stability-public2`, old floor | 40 actors; 16 slowed actors fail, 64 pauses, maximum 224 consecutive motionless ticks |
| `stability-manual`, old floor | Manual armed/slowed reversals reproduce the stop; maximum 234 motionless ticks |
| `stability-friction` | Friction falls from 15.89 to 1.09, but every saved position/speed/heading remains exactly equal to the baseline; rejected |
| `stability-manual-ten` | Ten native legs still reproduce the slowed reversal stop; not promoted |
| `stability-overlap*`, `stability-minstep*` | Overlap .5/1 and minimum step .1/.5 still reproduce the stop; not promoted |
| `stability-fast-half` | Fast legs plus a native half-speed sticker still reproduce the stop; not promoted |
| `stability-floor2` | .20 and .35 segments stall; .50/.75/1 segments have no >=60-tick pauses |
| `stability-floor50` | **40/40 pass**, 20,000 ticks per actor, zero >=60-tick pauses; worst transient zero-progress run 24 ticks |

The 50% matrix's unmodified equipped-cruise mean is exactly equal to the old
matrix, .172360584 tiles/tick. Its protected slowed-cruise mean is about .1051
versus the former .0472. The safeguard is a native modifier floor, not an exact
velocity clamp; ordinary brief gait/turn transients remain.

The actual `ASS` save contains a legendary ANISETRON at 471.437 health with no
equipment or active slowing stickers. Initial N/S driving, old-bob comparison,
the installed mod set, and `stability-ass-sustained` (12,000 uninterrupted input
ticks) did **not** reproduce the user's intermittent release/repress symptom.
This remains an explicit open reproduction boundary. Repeated scripted
`walking_state` writes can mask real-input or event-order interactions. The
optional observer is default-off, administrator-only and writes no player or
vehicle state. No unverified compatibility workaround is shipped.

## Visual and endpoint evidence

- `stability-bob*` and `stability-work/bob-*.json`: actual body registration
  measures 41 pixels of cruise excursion at .08, versus 3-4 pixels at 1.
- `stability-roots`: 624 native screenshots. All eight day/night headings were
  inspected, including low/high sampled hover positions and stopping. N shows
  three rear strands, NE five exposed strands; other views retain the appropriate
  three to five visible roots. Actual root placement is coherent at normal zoom.
  Registration of 288 day movement frames gives approximately -1.787 to +2.315
  pixels of remaining vertical difference. This is not a universal <=2px claim.
- `stability-effects`: 48 static beam captures across eight day/night headings.
  Native endpoint versus requested endpoint differs by at most .177 screen px.
  Visible source and impact caps cover their anchors. No separate offset glow
  ray is visible. Very short projected rays can crowd their cap artwork.
- `stability-tracking`: **47/47** runtime checks pass. Read-only actual-pixel
  review of 435 captures finds zero empty regions in 751 expected source bands
  and 288 on-screen endpoint neighborhoods. Broad presence regions establish
  delivery, not precision. Eleven registered turning frames contain 17 measured
  origins: crown .025-1.686px and facade .014-.373px from the expected source axis.
  Several night correlations miss the old evaluator's strict threshold, so
  these are diagnostic measurements rather than a blanket alignment certificate.
- `stability-moving-ends`: 192 wider native captures keep nearby front/rear
  targets in frame during travel, quarter-turns, wraparound and deceleration.
  All 384 channel/frame endpoints have visible caps. Native target versus paid
  endpoint differs by at most .177px. Local cap-axis fits have medians about
  .40px and maxima 2.46px crown/1.78px facade; asymmetric flare art prevents a
  strict <=2px cap certificate. The last screenshot still coasts, while trace
  tick 600 shows all 16 beam vehicles fully stopped. Targets follow the hull
  after production updates, so the newly drawn target can lead the native beam
  point by up to 11.41/15.76px in this artificial rapid-turn fixture. Real native
  enemy tracking is covered separately above; no target offset is inferred
  from that fixture ordering.

## Mechanical and repository checks

- `stability-native`: **151/151** native vehicle, payment, logistics, lifecycle
  and visual-service checks pass.
- `stability-data`: fresh focused final-data and asset inspectors pass: 128
  directions, eight sheets, all referenced assets, restored endpoint art,
  aligned glow layers, progression, range, ammo, readouts and native voices.
- `stability-observer`: native bounded-recorder smoke passes; the 60-frame
  trace completes without moving the vehicle or modifying walking input.
- `stability-mobility3`: **28/28**, including real enemy attacks, native controls,
  equivalent damage, helper cleanup, slow expiry and no ordinary-speed boost.
  The fixture now checks affected vehicles and actual compensated factors,
  instead of requiring five helpers simultaneously: faster protected craft
  outrun some slow effects before the sampling instant.
- `stability-replay`: **84/84** active v3 save replay with fidelity changed to Off;
  exact payment, packets, queued work and deadlines survive the reload.
- Fresh conceptual-link audit: **0 findings**, 46 models and 125 owned sources.
  Preflight passes Lua, PowerShell, requires, locale, asset references, pack
  versions and conceptual links. The full preflight remains red for protected
  Python cache writes and two pre-existing encoding findings in unrelated QC
  files. Independent in-memory compilation passes all **149** discovered Python
  sources. Existing unrelated header warnings remain.
- `stability-work/preservation.json`: **4,905** baseline files checked, no
  missing files and no changed PNG, OGG, GLB or Blender assets. Sixteen existing
  source/doc/QC paths changed, all within the ANISETRON correction; new fixture
  and observer sources are separate. No unrelated source changes were detected.

Historical inheritance/ten-leg reports retain their original parameters and
limits. The approved model, materials, 128-direction sheets, icons and attachment
coordinates are preserved; this work changes runtime placement and prototypes.

## Review delivery and staging cleanup

`stability-work/review` contains normal-size native day/night north/NE loops,
lossless eight-heading boards and a compressed turning-beam preview. Every
preview is under 10 MiB. Raw engine captures remain the measurement authority.
The optional observer ZIP is `stability-work/zzz-esir-anisetron-observer_0.0.1.zip`;
it is not installed automatically or included in the shipping mod.

The scoped cleanup removed 53 disposable staging directories from this pass,
including duplicate temporary graphics runs. The inventory counted approximately
2.12 GiB of singly linked files, separately from 53.45 GiB of apparent paths
dominated by hard-linked assets. All reports, saves, reviewed repository captures,
the asset/dependency caches, source art, and current/baseline/friction source
snapshots remain. `cleanup-plan.json` and `cleanup-result.json` record the checked
absolute paths, junction handling and zero remaining cleanup targets.
