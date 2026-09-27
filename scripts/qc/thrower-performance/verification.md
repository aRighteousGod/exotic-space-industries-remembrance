# Flame and acid turret performance verification

Engine: installed Factorio **2.0.77**. Gameplay pack: **ESIR 1.3.40**.
Date: September 25, 2026. All saves, settings, dependency links, and gameplay
copies are isolated under `.factorio-qc/thrower-performance/`.

## Implementation boundary

The startup catalog and final data pass implement Original/2x/4x/8x/16x.
Original is the default. The allowlist contains the ordinary flame turret,
ten fuel-specific flame turrets, and the acid turret. This setting introduces
no production runtime handler, polling, scripted damage, or entity replacement.
The existing fuel-adaptation system continues to own turret replacement.

Original leaves pre-existing attack/effect prototypes unchanged. Stable private
copies of shared effects remain declared in every profile for save loading.
Optimized profiles scale finalized cooldowns, stream intervals, direct damage,
and fluid draws; sticker application intervals are capped at 30 ticks. General
damage modifiers, ground-fire damage/growth/lifetimes, targeting geometry,
quality behavior, and particle buffer capacity remain unchanged.

The independently added flame-overlap notification pass runs afterward. QC
compares prototype ownership immediately around this feature's pass and checks
balance/reference contracts again on final prototypes, so later notification
flags do not create false ownership failures.

## Sustained damage and consumption

Ten profile/adaptation combinations loaded in the engine. Each has 208 cases:
all ten flame fuels and four acid fluids, normal/legendary quality, research
bonus states disabled/enabled, and native isolated direct/sticker/ground/combined
effects. The fixture sets native force ammo/turret bonuses to 0/0 or +50%/+70%;
it tests their damage interaction, not the research-event lifecycle.
Acid has no ground-fire case. Each case warms up for 60 seconds and measures
120 seconds. Native damage events measure DPS, avoiding health rounding on
high-health targets.

All **1,664 optimized-versus-Original comparisons passed**. The following ranges
cover every optimized profile and both adaptation states:

| Measurement | Lowest ratio to Original | Highest ratio | Required tolerance |
|---|---:|---:|---:|
| Direct DPS | 0.995556 | 1.000278 | 1% |
| Sticker DPS | 0.995833 | 1.001391 | 1% |
| Ground-fire DPS | 0.989248 | 1.001391 | 5% |
| Combined stationary-target DPS | 0.995375 | 1.000519 | 5% |
| Fluid use per second | 0.995556 | 1.004444 | 1% |

Artifacts: `20260925-214312-025` (adaptation enabled) and
`20260925-215003-812` (disabled). Both use the supported timing run's frozen
gameplay pack, including the independent overlap-cleanup addition.

Warm-up damage is recorded separately in one-second bins. For example, the
normal-quality crude-oil ground-fire case reaches 95% of its eventual sustained
DPS in the third second under Original and the sixth second under 16x.
Its first six bins are 0/12.89/77.78/78/78/78 damage under Original and
0/6.50/30.88/52.98/72.04/77.35 under 16x. This is a measured buildup difference,
not a change to ground-fire damage, growth or lifetime prototype fields.

## Combat differences

All 90 behavior checks passed: nine scenarios, flame/acid, and five profiles.
They cover short bursts, retargeting, moving crowds, overlapping turrets, mixed
fuels, both range edges, flat/percentage resistance, and starvation/recovery.
Passing means attacks and recovery function; it does not assert combat parity.

For 16x in this fixture:

- Moving-crowd damage was about **86.4%** of Original for flame and **60.7%** for
  acid. The smaller number of impacts changes coverage and corrosion uptime.
- Against the fixture's resistance (flat 3, then 25%), total damage was about
  **151.3%** of Original for flame and **508.6%** for acid. Larger hits incur the
  flat deduction less often. These figures are scenario-specific.
- Short-burst total damage was about **95.3%** for flame and **119.6%** for acid.
- After firing stopped at tick 150, the last direct hit arrived at tick 244
  for flame and 301 for acid, versus 211 and 220 in Original. Those tails include
  airborne particles and stream timeout; ongoing burn/corrosion is separate.
- The same short-burst cases first hit at ticks 83/76 for flame/acid under 16x,
  versus 90/83 under Original. First-hit order depends on stream phase and travel;
  it is not a guaranteed latency improvement. Damage after stopping was
  3,978.68/2,076.80 under 16x and 4,195.08/1,732.13 under Original.

The setting descriptions warn about these tradeoffs, especially at 8x/16x.
Universal post-resistance parity is incompatible with fewer, larger hits under
[Factorio's damage rules](https://wiki.factorio.com/Damage).
Artifact: `20260925-215633-865`.

## Save transitions

Actual private-server saves exercised Original -> 16x -> 2x -> Original with
all fourteen fluids, legendary turrets, partial health, and active effects.
Both adaptation states passed all **84 turret-state checks**. Unit identity,
prototype identity, quality, and health survived. Every-tick samples observed
at most one attached sticker per target throughout both sequences, including
the first ticks after loading. No temporary duplicate attached damage effect
was observed.

Saved native effects retain their existing identities while active; the acid
targets still reported their original `ei-acid-sticker` through the sequence.
This verifies survival without forced replacement, not instantaneous conversion
of every saved effect to a new private prototype. The final expiry replay stops
all turrets without deleting effects: each save begins with 14 stickers and 10
fires and ends with zero of both after 130 seconds. Last damage occurred at
tick 3,661 with adaptation enabled and 1,862 with it disabled (relative to stop).
No further damage continued after natural expiry.

Artifacts: `20260925-215934-203` (enabled) and `20260925-220319-150` (disabled).

## Native performance

**All four optimized profiles passed the performance gate in all three
1,000-turret workloads on the supported stack.** For each workload, the slowest
optimized repetition had a lower mean than the fastest Original repetition.

Hardware: AMD Ryzen 7 5700X3D, 32 GB RAM. Each profile has three sequential
native replays and nine workloads per replay: 100/500/1,000 turrets, each
flame/acid/mixed. Every turret was confirmed to be firing. Each phase warms up
for 600 ticks and measures 1,800 ticks; setup/reporting boundaries are excluded,
leaving 1,799 timing samples per phase per repetition. Timed runs add no fixture
damage-event listener. Flame-only cycles the ten fuels; acid uses sulfuric acid;
mixed alternates flame and acid. Stable targets and fluid supply are maintained.

Values are **mean / p95 milliseconds per tick**, from native wholeUpdate samples
(5,397 samples per cell).

| Profile | Turrets | Flame | Acid | Mixed |
|---|---:|---:|---:|---:|
| Original | 100 | 1.078 / 1.750 | 4.271 / 5.205 | 2.771 / 3.685 |
| Original | 500 | 3.730 / 6.331 | 21.097 / 26.020 | 11.690 / 14.745 |
| Original | 1,000 | 6.828 / 11.523 | 42.706 / 52.734 | 25.532 / 35.194 |
| 2x | 100 | 0.844 / 1.367 | 2.490 / 3.278 | 1.622 / 2.050 |
| 2x | 500 | 2.419 / 4.133 | 11.130 / 15.057 | 6.442 / 7.854 |
| 2x | 1,000 | 4.346 / 7.706 | 23.194 / 30.748 | 12.931 / 16.284 |
| 4x | 100 | 0.702 / 1.079 | 1.476 / 1.952 | 1.081 / 1.482 |
| 4x | 500 | 1.800 / 2.941 | 5.708 / 7.668 | 4.151 / 6.809 |
| 4x | 1,000 | 3.382 / 6.581 | 12.422 / 18.649 | 6.967 / 9.446 |
| 8x | 100 | 0.630 / 0.955 | 0.965 / 1.330 | 0.847 / 1.198 |
| 8x | 500 | 1.486 / 2.365 | 3.527 / 5.201 | 2.425 / 3.425 |
| 8x | 1,000 | 2.700 / 4.617 | 6.240 / 8.836 | 4.182 / 5.316 |
| 16x | 100 | 0.625 / 0.915 | 0.793 / 1.153 | 0.711 / 1.043 |
| 16x | 500 | 1.523 / 2.827 | 2.133 / 3.083 | 2.009 / 3.286 |
| 16x | 1,000 | 2.835 / 5.122 | 4.727 / 6.795 | 3.689 / 5.802 |

Ranges of the three repetition means at 1,000 turrets:

| Profile | Flame ms | Acid ms | Mixed ms |
|---|---:|---:|---:|
| Original | 6.756-6.870 | 42.100-43.189 | 24.583-26.908 |
| 2x | 4.126-4.586 | 21.432-24.087 | 12.236-13.797 |
| 4x | 2.913-3.949 | 10.910-15.151 | 6.717-7.148 |
| 8x | 2.438-2.901 | 5.755-6.714 | 4.009-4.303 |
| 16x | 2.186-3.183 | 3.966-5.181 | 3.583-3.866 |

These are measurements of this desktop and loaded mod stack, not portable UPS
multipliers. Desktop background work was not fully controlled. No additional
thrower fixture ran alongside the timing process; diagnostic and functional
jobs started afterward. The comparison retains every repetition and requires
the slowest optimized repetition to beat the fastest baseline repetition.
The flame mean at 8x was slightly lower than at 16x: processing-count factors
do not guarantee proportionate or strictly increasing timing gains.

The authoritative run is **20260925-210600-611**, with Extinguisher disabled
according to the current incompatible dependency in info.json. Raw engine
timing logs, scenario reports, and performance-summary.json remain in that
ignored staging folder. The earlier 20260925-201510-301 run included Extinguisher
before that declaration changed; its timings are excluded from this table and
the final acceptance decision. Subsequent functional checks use the supported
run's frozen gameplay copy.

Separate diagnostic replays of that exact fixture recorded the following native
damage-event counts during each 1,800-tick measurement window at 1,000 turrets:

| Profile | Flame events | Acid events | Mixed events |
|---|---:|---:|---:|
| Original | 1,258,812 | 2,698,000 | 1,978,375 |
| 2x | 719,313 | 1,349,500 | 1,034,375 |
| 4x | 464,933 | 674,500 | 569,467 |
| 8x | 352,433 | 337,250 | 344,967 |
| 16x | 296,184 | 168,625 | 232,342 |

At the final sample, each continuously firing turret still had one stream and
one attached sticker. Flame-only had 1,000 ground fires, acid had zero, and
mixed had 500. This is expected: the setting reduces particles and applications
inside native stream/sticker entities, rather than removing persistent entities.
Unchanged ground-fire applications and the 30-tick burn cap limit flame's event
reduction. Reports also contain the corresponding 100/500-turret counts.
Diagnostic timings are excluded from every performance claim.

## Native visual review

All five profiles produced ten native 1440x1280 captures each: daylight and
darkness at ticks 600/1,200, then paired shutdown views at 1,230/1,300/1,380.
Firing stops at tick 1,201. Camera position and zoom (0.6) are identical, with
ten flame fuels above four acid fluids. Background map decoration varies between
fresh maps; this is a readability comparison, not a pixel-difference test.

Paired firing views and final tails were reviewed for every profile. Flame fuel
colors, luminous impacts, green acid streams and persistent ground-fire indicators
remain visible in daylight and darkness. Smoke is visibly lighter as the factor
increases. 8x/16x have pronounced gaps and thin trails, especially for acid; their
appearance matches the advertised loss of smoothness. At 16x, airborne flame
particles remain in the tick-1,300 image (about 1.7 seconds after shutdown) but
are gone by tick 1,380 (about 3 seconds). All profiles have cleared their airborne
streams in that final view while persistent fire remains. No stuck stream tail
or missing attack indicator was observed in these captures. This was a native
snapshot review, not an interactive playtest or an FPS benchmark.

Artifacts: `20260925-221016-559` (Original) and `20260925-221432-549`
(2x/4x/8x/16x), under each `script-output` directory. Native PNGs are retained;
RGB JPEG viewing copies were used because the image viewer rejected the engine's
RGBA PNGs. The graphical fixture skips Freeplay's pausing intro dialog and uses
a short temporary mod-path junction to avoid Windows path-length failures.
Thirty missing graphics files from concurrent, unrelated content work were
supplied to the disposable frozen gameplay copy; existing images and all Lua
remained unchanged. The initial Original capture completed successfully but
exposed a PowerShell process-exit-code bookkeeping error in the runner; retaining
the process handle fixed that issue before the four optimized capture runs.

## Static and engine loading checks

The repository `qc-fast` engine load passed. The profile matrix uses the same
native data-stage loading through isolated `--create` runs, with assertions,
instead of writing ten multi-gigabyte prototype dumps.

Preflight syntax, encoding, locale, require/reference, asset, and pack-version
checks passed. The remaining header warnings are in unrelated
`auric-inoculation-vat.lua` and `emerald-apocalypse-hover-tank.lua` modules.
Python's bytecode cache was redirected to a short temporary path to avoid the
protected `.codex` directory and Windows path-length failures.

All seven locale files have matching keys and numerical tooltip placeholders,
valid UTF-8 without a BOM, and no replacement characters or mojibake markers.
Reproduction commands and fixture contracts are in [README.md](README.md).

While the frozen runs were executing, the separate overlap handler changed to
allow same-prototype ground patches to coexist. The performance catalog/pass,
fuel catalog, fuel finalization and overlap prototype pass remained identical.
A fresh working-tree integration run (`20260925-220042-272`) passed all 36
Original/16x behavior cases, and `20260925-220244-874` passed 16x final-prototype
checks with adaptation disabled. The full timing table remains explicitly tied
to its frozen stack; it is not a benchmark of every concurrent working-tree edit.

A small Factorio 2.0 compatibility fix was also required in the existing
`singularity-lance-config.lua`: numerical tooltip substitution parameters are
converted to strings before becoming prototype LocalisedStrings. This resolves
the engine's startup rejection without changing the Lance's damage calculations.
