# Sweeping radar validation

This page records the original implementation before the Heavy infrastructure
power costs and Balanced quality bonuses. See [quality-validation.md](quality-validation.md)
for the current rebalance's functional verification. Historical timing results
below were not rerun for that change and are not evidence of its performance.

Validated on Factorio 2.0.77 build 84539, ESIR 1.3.40. The complete reproducible
evidence is in [results.json](results.json); fixture commands and operating limits
are in [README.md](README.md). Generated saves, verbose timing CSVs, engine logs
and screenshots remain in ignored `.factorio-qc/radar/` staging.

## Correctness

- The disabled-shell feasibility fixture passed 14 checks: isolated red input
  and green output, electrical refill and exact debit, zero-valued input, and no
  native chart requests at every installed quality. A positive native-radar
  control produced 1,199 scan events while the disabled shells produced none.
- The functional fixture passed 62 checks. It covers all five modes, geometry
  completeness, north-crossing sectors, selected-policy state, atomic current-beam
  publication, completed-pass publication, recent expiry, capped contacts and
  indexed deadlines, Watch behavior, pulse acknowledgement and held-trigger edge
  history, zero-speed pause, and resumption without catch-up.
- Lifecycle checks cover blueprint tags/revival, cloning, player replacement,
  robot upgrade transactions, empty copies, capped transferred energy, helper
  repair/teardown, force merging, modded hostile forces, asymmetric friendship,
  cease-fire, raised and unraised teleports, surface deletion, stale GUI teardown,
  and native Aquilo freezing/thawing.
- Save/reload captured a paid 128-candidate query after exactly 64 aggregation
  records. Ordinary reload, forced configuration change and migration from the
  earlier dense-ready-list development save preserved ordered progress, settings
  and the one-million-joule payment without a second debit.
- The final generation-admission queue also passed a separate unpaid-state
  save/reload fixture. Four separated radars retained their cursor and waiting
  order with zero admission debit. The oldest waiter received the next grant and
  paid exactly once. A paid aggregation save from the preceding development
  schema also migrated to the final schema without losing progress or payment.
- The final `data.raw` audit confirmed both chassis, helper limits, exact recipe
  ingredients, finite research branches, final prerequisites/science and recycling.
  Source technology count 100 becomes 10 under this fixture's existing ESIR cost
  scaling. The feature leaves the ordinary radar unchanged.
- Locale auditing passed for seven locales with 94 keys each, matching
  placeholders, no duplicate keys, no BOM and no replacement characters. Existing
  Japanese wording outside the new sidecar was preserved.
- Repository preflight passed its syntax, encoding, reference, version and asset
  checks; its overall warning status is from existing unrelated module-header
  warnings. Asset QC completed with overall OK.

## Fairness regression

Fleet totals alone concealed a serious defect in an earlier candidate: its dense
swap-removal ready list delivered 108.35 observations/s with 100 radars while 35
radars completed no observations. Those timing runs are failed-candidate evidence,
not release results.

The final service uses circular ready lists. Re-entry joins behind every current
waiter, including work retained across ticks. A focused 100-radar regression
completed 38–62 observations per radar during the 40-second measurement window,
at 109.85 observations/s fleet-wide. The complete matrix now asserts a positive
measurement-window observation delta for every radar in each active scanning
case. Continuous geometry churn is deliberately excluded from that progress
assertion: replacing geometry before preparation completes can prevent scanning.

A second regression used 100 radars separated by 1,024 tiles. This exposed
generation admission starvation hidden by the overlapping fleet: fair visits
could align repeatedly with the 30-tick global gate, leaving some radars without
an observation even after 150 seconds. Generation now has a separate circular
admission lane whose cursor advances only when a grant is available. Every new
request queues behind existing waiters; admission uses the first of the same two
observation attempts, not an additional scan allowance. The focused fixed run
delivered 2–4 observations to every radar and 1.95 observations/s fleet-wide.
Earlier matrices from before this fix are not the final timing evidence.
Fair admission has a throughput cost in the overlapping exploration fixture:
50 radars fell from 49.30 to 35.375 observations/s and 100 from 77.625 to 53.325.
The fix prevents starvation; it is not described as a throughput improvement.

## Measurement method and limits

The measured main pack is frozen as `source-final4`; its SHA-256 manifest, helper
hashes, save hash and mod-list hashes are recorded in `results.json`. All cases
use the same connected-player fixture and installed dependencies. Each case
discards 600 warm-up ticks and measures 2,400 ticks. Timing statistics exclude the
fixture-transition tick, yielding 2,399 engine samples per case.
The ten-second warm-up does not guarantee that a 100-radar fleet has finished
preparing its coverage; remaining startup delay is visible in unavailable-report
samples and ready gaps. These short windows are not labeled settled-state results.

Baseline runs retain the same visible radar, electrical buffer and output helper
entities, with the radar script service disabled. Absolute whole-engine time
includes native entity overhead, other mods and QC sampling. Baseline/candidate
deltas therefore do not measure installation cost relative to an empty world.
Separate stage-profiler runs do not control simulation and are not used for
unprofiled whole-engine timing. This workstation also hosted other Factorio
activity during some runs; the process observations are included with the data.

Coverage radius is four chunks except for the radius-one simultaneous-completion
case. Fleets alternate both chassis with all radar research on a six-tile grid,
so exploration can reuse terrain generated by nearby radars. Dense scenes overlap
129 hostile turrets per chunk to exercise truncation and aggregation pressure.
The additional dispersed exploration case has 1,024 tiles between radars and
exposes the shared generation allowance without that terrain reuse.
These synthetic cases establish bounded operations and delivered service under
their stated conditions; they are not a universal save-performance guarantee.

The JSON records average, p95 and worst timings, all stage maxima, queue occupancy,
pending-job waits, sampled ready gaps, publication and sampling ages, throttling,
per-radar observation deltas and completed-pass duration samples. A pass statistic
with `samples: 0` means no pass completed within the available run, not a zero-time
pass. Sampled ready gaps are diagnostics, not a proved maximum-latency guarantee.
Unpaid generation intents have at most one queue entry per radar; they are
reported separately from the 32 admitted-job cap. The long follow-ups measure
150 seconds on generated terrain, 400 seconds with dense contacts and 150 seconds
of dispersed exploration. Their pass durations are simulation time; their engine
timings are diagnostic and are not substituted for the alternating matrix runs.

Recent-report validity is deliberately withheld during partial aggregation.
In the short final matrix, valid reports accounted for 30.25% of sampled radar
states in dense50 and 57.16% in dense100. Their valid-only sample-age p95 values
were three and five seconds. Reporting only those ages would hide the unavailable
states. The dispersed regression reached 46 seconds p95 sample age and 49 seconds
maximum, consistent with sharing about two new-terrain observations per second
among 100 radars. Ages are floored whole seconds, exclude invalid reports, and do
not bound the age of every individual contact retained by a policy.

## Final timing matrix

All values below are milliseconds except the final throughput column. The two
candidate means are independent unprofiled runs. The p95 and worst columns take
the larger value across those runs; stage attribution comes from a separate run.
Detailed individual stages and both sets of statistics remain in the JSON.

| Fleet | Workload | Baseline mean ms (runs 1 / 2) | Candidate mean ms (runs 1 / 2) | Candidate p95 / worst ms (max across runs) | Radar stages mean / p95 ms | Observations/s |
|---:|---|---|---|---|---|---:|
| 1 | idle | 0.468 / 0.490 | 0.523 / 0.521 | 0.728 / 1.933 | 0.083 / 0.151 | 0.00 |
| 1 | warm | 0.422 / 0.465 | 0.529 / 0.514 | 0.751 / 2.008 | 0.105 / 0.204 | 16.00 |
| 1 | exploration | 0.471 / 0.474 | 0.647 / 0.657 | 0.928 / 19.680 | 0.106 / 0.170 | 6.28 |
| 1 | dense | 0.455 / 0.448 | 0.802 / 0.848 | 1.940 / 6.690 | 0.468 / 1.886 | 11.72 |
| 1 | churn | 0.508 / 0.461 | 1.017 / 0.894 | 1.672 / 5.818 | 0.540 / 1.084 | 0.00 |
| 1 | completion | 0.456 / 0.454 | 0.519 / 0.567 | 0.840 / 3.344 | 0.108 / 0.201 | 16.00 |
| 10 | idle | 0.472 / 0.490 | 0.582 / 0.573 | 0.824 / 2.376 | 0.127 / 0.260 | 0.00 |
| 10 | warm | 0.471 / 0.509 | 0.684 / 0.710 | 1.050 / 4.659 | 0.220 / 0.362 | 97.42 |
| 10 | exploration | 0.483 / 0.542 | 0.730 / 0.752 | 1.119 / 18.461 | 0.160 / 0.298 | 10.60 |
| 10 | dense | 0.519 / 0.494 | 1.641 / 1.577 | 2.587 / 11.260 | 1.236 / 2.486 | 41.90 |
| 10 | churn | 0.483 / 0.501 | 1.030 / 0.987 | 1.512 / 3.741 | 0.566 / 0.884 | 0.00 |
| 10 | completion | 0.489 / 0.533 | 0.671 / 0.653 | 0.950 / 2.308 | 0.247 / 0.381 | 93.78 |
| 50 | idle | 0.641 / 0.678 | 0.844 / 0.827 | 1.264 / 3.008 | 0.252 / 0.408 | 0.00 |
| 50 | warm | 0.682 / 0.714 | 1.001 / 0.957 | 1.559 / 5.741 | 0.355 / 0.522 | 118.75 |
| 50 | exploration | 0.643 / 0.761 | 1.013 / 0.986 | 1.665 / 16.695 | 0.295 / 0.460 | 35.38 |
| 50 | dense | 0.744 / 0.736 | 2.838 / 2.637 | 4.555 / 27.708 | 2.159 / 3.758 | 33.38 |
| 50 | churn | 0.753 / 0.703 | 1.430 / 1.340 | 2.200 / 36.133 | 0.693 / 1.079 | 0.00 |
| 50 | completion | 0.667 / 0.670 | 1.013 / 0.952 | 1.609 / 3.673 | 0.366 / 0.551 | 106.80 |
| 100 | idle | 0.899 / 0.980 | 1.085 / 1.069 | 1.686 / 7.087 | 0.269 / 0.408 | 0.00 |
| 100 | warm | 0.896 / 0.869 | 1.264 / 1.213 | 1.863 / 4.899 | 0.393 / 0.629 | 109.78 |
| 100 | exploration | 0.792 / 0.949 | 1.479 / 1.272 | 2.592 / 149.477 | 0.367 / 0.610 | 53.33 |
| 100 | dense | 0.847 / 0.913 | 2.945 / 2.609 | 4.802 / 28.147 | 1.838 / 3.511 | 35.02 |
| 100 | churn | 0.904 / 0.979 | 1.619 / 1.506 | 2.404 / 19.188 | 0.732 / 1.190 | 0.00 |
| 100 | completion | 0.931 / 0.964 | 1.272 / 1.180 | 1.961 / 5.231 | 0.393 / 0.610 | 107.92 |

The largest exploration spike repeated at the same simulation tick: whole-engine
149.48/142.44 ms, of which the native map generator accounted for 147.85/141.21 ms;
script update was 1.06/0.84 ms. One bounded asynchronous generation submission can
still produce a large native generation cost. Watch avoids new terrain requests;
the Survey submission interval limits frequency, not the cost of one engine job.

In the final 100-radar long runs, every radar completed a full pass. Generated
terrain delivered 115.94 observations/s with last-pass duration mean/p95/worst
57.48/64.67/65.72 seconds. Dense contacts delivered 37.89 observations/s with
173.24/199.32/228.50-second passes. The dispersed run delivered 1.9533 observations/s
and 2–4 observations per radar over 150 seconds; no full pass completed in that
window. Its unpaid admission queue peaked at 99 while admitted jobs peaked at two.

## Presentation and remaining scope

The visual fixture exercises the normal linked open-entity input path for all
five modes and captures the screen panel, world coverage and remote-view overlay.
Screenshots were inspected. It drives GUI/input handlers programmatically;
physical mouse/keyboard interaction is not claimed. The final GUI hides a previous
geometry's heading until the new geometry completes work. The inspected GUI source
is identical to the frozen benchmark GUI; benchmark scenes have no open viewers.

Robot upgrades are validated as an upgrade transaction and event sequence, not
an end-to-end flying-robot test. Multiplayer desynchronization testing and
native-speaker review of the new translations remain outside this evidence.
The shipping art remains tinted native radar art; generated concepts are separate
design proposals, not production sprites.

There is no fixed "50 radars under X ms" release claim. Lower cost accompanied by
lower delivered scan rate is not presented as a free UPS improvement.
