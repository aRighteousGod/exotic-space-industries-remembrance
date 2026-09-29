# Singularity Lance — Full Hybrid verification

Implemented against ESIR 1.3.40 / Factorio 2.0.77. This is a working-tree change,
without release deployment, commit, or push. Eighteen unrelated dirty files match
their pre-change SHA-256 snapshots.

## Delivered behavior

All balance values live in `lib/singularity-lance-config.lua`. Native targeting,
energy payment, quality range, the existing ammunition multiplier, research
identities, science sets, prerequisite links, and automatic pricing remain intact.

- Wound applies +20% on the first hit, reaching +100% on the fifth successful hit.
  Only positive primary damage advances or refreshes it; retargeting and a gap of
  at least 120 ticks reset it.
- One combined spatial query selects the 2-tile central incision (24-tile
  overpenetration, 500 damage, cap 5) and two ±15° branches (width 1, reach 18,
  250 damage, shared cap 3). Central eligibility takes precedence before caps;
  an enemy receives at most one incision packet. Secondary rays stop at the
  effective-range circle; native-approved direct attacks retain their reach.
- The 30-tick Collapse replaces splash: 1,000 damage in radius 1.5, otherwise
  600 in radius 4, with 10 secondary slots and a reserved eligible primary.
- Every eighth paid shot uses ×4 primary damage, central/branch caps 10/6,
  a first Collapse of 2,000 in radius 3 or 1,200 in radius 6 with 16 secondary
  slots, then one radius-5 / 1,000-damage echo at tick 60 with 12 secondary slots.
  The stationary fully wounded primary receives 7,000 × M across three packets.
- Each blast queries current positions and rechecks bilateral diplomacy before
  damage. Core and outer damage are exclusive; each paid packet remains separate.
  Both Testament packets are committed at firing. Source removal and research
  changes do not revoke them; force merging transfers attribution and surface
  deletion removes both.

## Runtime and presentation

Schema 12 explicitly upgrades schema 11 in place, preserving registrations,
meters, timestamps, delayed buckets and due ticks. Existing packets retain their
old scalar damage, radius, cap, primary exclusion, and single-impact behavior.
The older pre-upgrade migration remains separate.

Upgraded presentation is bounded to four native segments per lance, meeting at
the actual aim point. The crystal offset, original impact bloom, native terrain
lighting, prismatic material, tails and three Wound bands are retained. New
concentrated warnings expose a fixed inner boundary in Lean too. Echo warnings
start after the first impact, under its flash; late service joins the existing
warning phase and overdue paired service never recreates an expired warning.

Axial and Testament have dedicated `start` animations matching their material:
a swept cyan aperture around the hot Axial axis, and a white/violet throat around
Testament's dark seam. Both use animated spectral banks, caustics, gold knots and
streamers. The regular beam retains its original opening. Upgraded `head`, `tail`
and `body` artwork remains. Narrow branches inherit a scaled opening; all four
segment origins use native animation, with no additional entity or rendering object.

Eight collapse PNGs / 84 frames add 42 MiB raw RGBA atlas storage (21 MiB semantic-only).
Four dedicated-origin PNGs / 32 frames add a further 7.5 MiB (3.75 MiB semantic-only).
All 36 existing production images are byte-identical. This is an atlas byte count,
not measured GPU allocation. The generator, manifest and source notes are under
`.codex/esir/asset-generators/singularity-lance/prismatic-redesign/`.

Seven maintained locales, technology effects, static tooltips, force-current
status and Informatron share configuration-derived values. Locale auditing checks
490 entries, exact key and parameter multiplicity parity, UTF-8, and duplicates.
The longest description uses 13 parameters, below the pinned API's limit of 20.

## Engine and static evidence

- Five fidelity presets: 533 assertions for Lean/Standard; 531 for
  Cinematic/Maximal/Unbounded (the two short-TTL expiry checks apply to Lean/Standard).
- Dedicated source openings: a further Lean and Standard run each passes
  533 runtime assertions plus all six beam prototype contracts. Material-specific
  source sheets, frame layout, animation speed, glow layers, scaled branch starts,
  source segmentation, original impact bloom and terrain-light masks are asserted.
- All four scaler/flattening combinations pass; the other three Standard runs
  each have 533 assertions. Final data-stage checks assert full science sets,
  required direct prerequisites and the existing no-scaling normalization.
- An actual schema-11 save retains counter seven, five Wound stacks, the original
  timestamp and seven paid old collapses. Those old packets deliver 1,750 area
  damage and exclude the primary; the next new eighth shot deals 4,000 direct and
  schedules the two new pulses. Actual schema-12 counter-seven reload also passes.
- Coverage includes eight firing directions, exact corridor filtering, rotated
  and large targets, caps/ties, quality/native bounding-box boundaries, exact core
  and shell boundaries, reserved primaries, movement, bilateral protection changes,
  research/source/surface changes, real force-merge delivery, and separate resistance
  applications. Reentrant destruction guards remain covered.
- A 96-lance rapid-fire fixture retains all 864 delayed packets and exactly 384
  native beam segments. Every preset gives identical aggregate damage. Native
  health arithmetic accumulates 18.5/30 damage of rounding over the first/all
  pulses respectively; exact packet counts are also asserted, with tolerance far
  below one missing packet.
- `preflight`: syntax, encoding, requires, locale, asset references and pack-version
  checks pass; two pre-existing unrelated module-header warnings remain.
- `qc-fast`: zero errors, 69 existing unrelated compatibility/prototype warnings.
- `qc-assets`: clean. Legacy art replay/hash checks and new frame/edge/core-marker
  QA pass. The final `data.raw` technology records are retained in the JSON report.

## Performance method and results

Median of five measured whole-engine mean update times, in milliseconds:

| Scene | Before | Full Hybrid | Change |
|---|---:|---:|---:|
| No lance | 0.367 | 0.364 | -0.82% |
| 96 idle lances | 0.386 | 0.382 | -1.04% |
| Direct-only, one lance | 0.453 | 0.453 | 0.00% |
| Normal-power, 96 lances | 2.170 | 4.346 | +100.28% |
| Dense artificial stress, 96 lances | 53.612 | 88.773 | +65.58% |
| Diagonal artificial stress, 96 lances | 14.320 | 29.222 | +104.06% |
| Unrelated research flood, 96 idle lances | 0.389 | 0.407 | +4.63% |

The direct-only result has no regression above the 5% investigation threshold.
Its five-run ranges overlap (before 0.447–0.463 ms, after 0.449–0.474 ms).
The enhanced combat costs are substantial and consistent across repeated runs;
this is not an overall UPS improvement. Small differences in the near-idle scenes
should not be interpreted as optimization wins. Full individual samples and
separate phase attribution are retained in `hybrid-results.json`.

Candidate attribution after 120 warmup ticks (milliseconds per tick, including
zero-work ticks; profiling enabled only for these separate runs):

| Lance phase | Normal-power mean | Dense mean | Dense p95 |
|---|---:|---:|---:|
| Combined three-ray selection | 1.895 | 27.886 | 48.501 |
| Incision damage calls | 0.612 | 14.562 | 24.687 |
| First Collapse damage work | 0.797 | 31.121 | 48.163 |
| Echo damage work | 0.138 | 3.864 | 29.333 |
| Shot core presentation | 0.175 | 3.275 | 6.838 |
| Impact / echo-warning presentation | 0.023 | 0.787 | 2.826 |
| Optional decoration | 0.008 | 0.187 | 0.290 |
| Total lance script (`shot + update-total`) | 3.875 | 89.155 | 126.237 |

**The existing 1 ms p95 dense-fixture objective remains unmet.** The measured
candidate is 126.237 ms p95 under artificial dense firing, with profiling overhead
included. Normal-power total lance p95 is 22.304 ms; native synchronized salvos
produce spikes that the 3.875 ms mean does not describe. These are measured costs,
not a claim that the new mechanics meet the earlier UPS objective.

Over the 480 measured ticks, dense stress processes 46,080 paid shots through
46,080 combined incision queries, 46,080 first impacts, and 5,760 echoes. Normal
power records 1,352 shots, 1,352 incision queries, 7,552 central and 3,870 branch
packets, and 170 echoes. The aligned dense and diagonal arrangements produce no
branch victims because their eligible victims belong to the central ray; the
normal-power target selection exercises branches. First-impact counts may differ
slightly from current-window shot counts because paid work crosses the warmup
boundary. No packet is dropped to meet a performance budget. Idle/no-lance and
unrelated-research profiles have zero lance queries, Wound cues, status refreshes,
force-cache refreshes or measured shot/update work. Unrelated effects remain
excluded by the exact-ID dispatcher and the dedicated fixture assertions.

The baseline is the pre-enhancement dirty source, including the preceding crystal,
impact-bloom and lighting fixes. Matched before/after pairs use the same frozen
helper, seed 410728, 600 ticks, one discarded full warmup run and five measured
runs. Pair order alternates by scene; measurements are serial. Targets have one
billion health, and populated runs assert that query populations survive. The
no-lance pair predates that final-tick assertion and creates no targets on either
side. Detailed telemetry is disabled for timing runs and enabled separately.

The direct/dense/diagonal cases inject 60 paid-shot callbacks per second per lance
and are artificial firing stress. Normal-power uses native weapon firing and the
shipped power contract. Whole-engine means include fixture and other-mod costs;
the separate phase profiler measures lance work after tick 120. GPU/render cost
is outside these headless results. Nested phase measurements must not be summed:
only `shot + update-total` form total lance script work.

Dedicated source openings followed the benchmark snapshot. Runtime is identical;
one 16-frame, 192-by-160 animation replaces another at the same scale and speed.
Segment and layer counts remain unchanged, with 7.5 MiB additional raw atlas data.
Lean and Standard receive separate final-source engine checks. Timing results
belong to the frozen snapshot, rather than a new measurement of the final artwork.

## Manual graphical acceptance

The user elected to perform gameplay visual review. Staged sheets and day/night
Lean/Standard composites were inspected; no isolated graphical fixture is claimed.
Review at ordinary gameplay zoom:

1. Crystal alignment and the dedicated Axial/Testament openings that transition
   into their own beam materials in all directions; the regular opening stays
   unchanged. The main beam ends at the true aim point,
   with all three extensions connected there. Inspect long/diagonal shots, quality
   range limits and large native-approved targets beyond center range.
2. Saturated moving prismatic ribbons, tails, original impact blooms and terrain
   lighting on the main beam, forward incision and both narrower branches. Inspect
   the three scaled source flares at the fork for excessive brightness or hidden targets.
3. Wound split/branch/broken-halo bands at hits 1–2 / 3–4 / 5. The final halo means
   +100%; check moving enemies, worms and spawners, retargeting and two-second expiry.
4. The normal warning's fixed 1.5-tile core boundary within its radius-4 blast,
   readable while the outer warning contracts; strong center contact at tick 30.
5. Testament's dark seam and broad banks, radius-3 core/radius-6 first warning,
   first contact visible over the second warning at tick 30, and radius-5 echo
   with terminal cross at tick 60. Check rapid fire and full Wound together.
6. Day/night and Lean/Standard, every upgrade separately and combined, then the
   96-lance scene: no clipped sprites, disconnected forks, piled-up beams, excessive
   glare, hidden core boundaries or unreadable enemy silhouettes.
7. Wrapping and readability of technology descriptions, effect rows, item/entity/
   Factoriopedia tooltips, custom status and Informatron, including translated text.

Staged review files: `output/meshy/lance-prismatic-liturgy/hybrid/hybrid-board.png`,
`hybrid-timeline.webp`, and the timeline stills. The durable generator recreates
these artifacts; the timeline is deliberately played four times slower.
Dedicated-origin previews: `output/meshy/lance-prismatic-liturgy/origins/origin-board.png`
and `origin-motion.webp`. These show source/body material comparisons; native
cap placement remains a gameplay check. Reproduce with the durable `origin.py`;
`ORIGINS.md` records source roles and the manual review scope.
