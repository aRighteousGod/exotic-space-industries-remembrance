# Singularity Lance delivery evidence — 2026-09-25

## Implementation and ownership

The main pack implements Axial Rupture → Wound Memory → Terminal Collapse →
Black-Hole Testament. Shared values live in `lib/singularity-lance-config.lua`;
the technology effect rows, static tooltips, and force-current Informatron page
consume the same values. All seven maintained locale sidecars are synchronized.

Technologies are declared with the lance prototypes. Final ingredients are reconciled
after generic inheritance and before the ordinary cost scaler. The late lance pass
restores required prerequisite links without replacing compatibility prerequisites or
running another pricing pass. The existing laser-damage 6/7 bridge remains the only
research damage multiplier.

Runtime schema 11 owns registered lances, per-force capabilities, per-lance meters,
paid collapse buckets, and presentation references. The central dispatcher routes
the exact lance effect ID. There is no lance damage/death listener, target polling,
idle wound sweep, or second event loop. Damage packets always recheck bilateral
friendship/cease-fire protection, neutral ownership, validity, and destructibility.
Selection may reuse diplomacy only within one query, before any damage callback.

The 24 new PNGs ship in the main pack. No companion graphics dependency/version
changes are required. The checked-in procedural generator retains transparent core
and glow layers; the staging preview and animation strips were inspected. Gameplay
visual acceptance is delegated to the user, as requested; no gameplay capture pass
is claimed. See [the manual checklist](README.md#manual-graphical-acceptance).

## Validation scope

Engine: Factorio 2.0.77, with the enabled 40-mod compatibility profile captured for
this task. Unrelated work, including the concurrent extinguisher integration, is
frozen at the pre-change dirty snapshot for matched lance tests. The runner overlays
only lance-owned files and the narrow control integration. This is not a claim that
every optional compatibility mod or the evolving full worktree was tested.

- Repository preflight: Lua/Python syntax, references, locale and encoding checks
  pass. Its remaining warnings concern pre-existing file-map headers in the auric
  inoculation vat and Emerald Apocalypse modules.
- `qc-assets`: passes against the shipping asset tree.
- The final general `qc-fast` and `qc-runtime` wrapper attempts stop before loading
  prototypes: their cached mod list still enables standalone `extinguisher`, which
  the concurrent ESIR integration now declares incompatible. The lance-specific
  engine fixture uses its frozen dependency profile and completes independently.
  The unrelated integration and its shared cache have not been changed for this task.
- Final prerequisite and science assertions: scaling on/off × flattening on/off
  pass, including exact finalized Axial inheritance, canonical later catalogs,
  omitted Space science at the two deepest steps, and retained required links.
- Native energy payment, native quality/bounding-box targeting, separate-shot flat
  resistance, nearest corridor entry, rotated/large targets, primary exclusion,
  splash/penetration/collapse caps, fixed delayed positions, source removal,
  diplomacy changes, research loss, surface deletion, resets, merges, normal and
  scripted research, clone/ownership resets, and legacy settlement are covered.
- Wound tests include the full ramp, retargeting, exact expiry, zero damage, and
  primary-only scaling. Zero damage neither builds nor refreshes a wound.
- A synchronous secondary-damage reaction destroys the primary target or the lance
  before presentation. Both cases avoid invalid entity access, create no stale Wound
  mark, and preserve the already-paid collapse. This reproduces the reported
  `wound_cue` crash boundary; presentation now revalidates both entities.
- Actual server save/reload at counter seven passes: the next paid shot deals
  1500 baseline laser damage with full Wound stacks and consumes the eighth shot once.

The final fidelity sweep passes all 119 assertions in each of Lean, Standard,
Cinematic, Maximal and Unbounded, including the reported invalid-entity crash
regression, zero-damage Wound and secondary range-boundary corrections.
Raw logs, staged mods and saves remain in ignored
`.factorio-qc/lance/`; the reusable fixture and analyzer are checked in here.

## Performance method

Each matched scene uses one discarded full warmup run followed by five runs of 720
updates. Compare medians and the spread of those five run means, not a single run.
Whole-game update timings include the engine and the enabled mod profile. Other
development activity on this machine can contribute to run variation.

The direct, dense and diagonal scenes inject 60 paid-shot callbacks per second per
lance. They are artificial stress, not sustainable power behavior. Dense uses 96
lances and 960 durable military targets. Normal-power uses native targeting and the
shipped 125 MJ shot / 400 MW input / 20 MW drain. Research injects 100 unrelated
completion callbacks once per second into a scene with 96 registered lances.

Detailed phase profiling is disabled for ordinary measurements and normal gameplay.
Separate diagnostic runs aggregate timers by phase and tick, then log outside the
measured callbacks. Timings include profiler bookkeeping and engine calls made by
the module. `shot-core` is contained in `shot`; `mechanics`, `impact-core`, and
`decoration` are contained in `update-total`. Total lance work is `shot + update-total`,
not the sum of every row. Phase distributions discard the first 120 ticks and include
zero-work ticks. Headless profiling measures script/render-object workload, not GPU
rendering cost or visual legibility.

The baseline has the old coupled presentation/damage behavior. The candidate's
guaranteed splash and separately paid upgrade packets intentionally perform more
mechanical work. The one-lance direct scene provides the simpler-path regression
check; the upgraded scenes report added workload separately.

## Performance acceptance

Whole-game update medians below use five measured runs; parentheses show the minimum
and maximum of those five run means. They are not per-tick extrema. Raw run means,
source hashes, phase distributions, counters, and validation markers are retained in
[results.json](results.json).

| Matched scene | Baseline median (range), ms | Candidate median (range), ms | Median change |
| --- | ---: | ---: | ---: |
| No lance | 0.429 (0.423–0.447) | 0.442 (0.439–0.458) | +3.0% |
| 96 idle lances | 0.417 (0.410–0.466) | 0.432 (0.430–0.454) | +3.6% |
| One lance, direct-only stress | 0.525 (0.523–0.535) | 0.532 (0.530–0.558) | +1.3% |
| 96 lances, native normal power | 0.795 (0.772–1.000) | 2.168 (2.036–2.302) | +172.7% |
| 96 lances, artificial dense stress | 6.858 (6.378–7.361) | 57.713 (54.992–112.742) | +741.5% |
| 96 lances, diagonal stress | 5.292 (5.143–5.858) | 17.122 (16.045–18.484) | +223.5% |
| Unrelated research bursts | 2.997 (2.976–3.038) | 0.408 (0.400–0.457) | −86.4% |

Direct-only is below the 5% investigation threshold and its run ranges overlap.
Normal-power and dense were repeated after the other lance validation jobs finished.
Background development activity remained uncontrolled; the large dense spread is
reported rather than removed as an outlier. These figures are not a hardware-neutral
UPS guarantee. The no-lance/idle/direct paths were measured before the final Wound
validity guard, which those scenes never enter; upgraded timings include that guard.

**The 1 ms p95 dense-fixture objective is not met.** The final diagnostic run measured
83.088 ms p95 for all lance work in artificial dense firing, and 17.107 ms p95 in
the native normal-power scene. The corresponding means are 53.320 and 1.503 ms/tick.
Normal-power fire is bursty; its p95 should not be replaced by its much lower mean.
These figures include synchronous engine/mod work invoked by the lance's damage
calls and diagnostic profiler overhead, and are specific to this machine/profile.

| Script phase | Dense mean / p95 (ms) | Normal-power mean / p95 (ms) |
| --- | ---: | ---: |
| Whole shot callback, including core cues | 25.848 / 46.217 | 0.856 / 1.854 |
| Shot core cues, contained in the row above | 2.128 / 3.304 | 0.067 / 0.154 |
| Delayed mechanics | 26.414 / 43.516 | 0.625 / 1.487 |
| Delayed impact core cues | 0.525 / 1.013 | 0.010 / 0.032 |
| Decoration | 0.246 / 0.457 | 0.006 / 0.012 |
| Whole delayed update | 27.472 / 45.299 | 0.647 / 1.562 |
| All lance work, shot plus delayed update | 53.320 / 83.088 | 1.503 / 17.107 |

The dense counter window contains 46,080 paid shots and 529,440 secondary damage
packets over 480 ticks. The baseline receives the same 46,080 callbacks but reports
only 531 scripted area-victim applications through 59 coupled damage jobs. The new
guaranteed area packets and penetration therefore represent substantial added work,
not just a new presentation of the old workload. Immediate shot work excluding core cues averages 23.720 ms,
and delayed mechanics average 26.414 ms. Thus reducing decoration alone cannot meet
the target. No paid packets were merged, delayed beyond their due tick for a budget,
or discarded to make the benchmark pass. The performance objective remains open.

The UPS pass removes idle searches, wound sweeps, unrelated-research scans and broad
effect dispatch; caches immutable range values; reuses unchanged beams/marks;
checks diplomacy cheaply during each query while rechecking every actual packet;
and bounds decoration independently. Idle and unrelated-research snapshots have
empty lance work counters. Exact-ID dispatch excludes unrelated script effects by
construction; this dispatch property was also checked in the central source.

## Reproduction

Use [the fixture instructions](README.md) and `analyze.py`. The baseline source was
captured before lance edits, preserving the existing dirty worktree. It is local
evidence, not a clean historical release. On another checkout, supply that source
snapshot with `-BaselineSource`; ordinary candidate checks fall back to the current
main pack if no captured snapshot exists.
