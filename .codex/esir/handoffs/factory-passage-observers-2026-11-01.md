# Factory passage observers, circuit scanner and guide

Implemented under ESIR **1.4.03**, verified with exact Factorio **2.1.24**.
All 160 isolated timing trials and native legacy classification passed. Physical
recipe-picker interaction and actual two-client synchronization remain unverified;
the separate evidence boundaries below are part of this delivery.

## Delivered behavior

- Closed manual machines have no recurring recipe checks. Native GUI observation
  and native assembler circuit selection are independent reasons, counted once per
  machine. Rocket silos are GUI-only. Cached proximity avoids idle topology scans.
- The existing main budget defaults to 256, range 1–1,024, retaining the persistent
  6:1:1 dirty/retry/GUI-or-legacy rotation. Circuit-only candidates use a separate
  additional budget, default **1**, range 1–1,024, and an enabled-by-default toggle.
- Circuit deadlines use the shared indexed min-heap, ordered by due tick and unit
  number. Every attempted item is charged. Successful checks, including unchanged
  ones, and actual reconciliation establish a 60-tick background cooldown. GUI and
  explicit event updates bypass it; deferred work does not refresh the clock.
- GUI open/close transfers service immediately from cached eligibility, even when
  reconciliation is backlogged. The next maintenance pass still owns topology work.
- Scanner Off parks candidates. Re-enabling and budget changes do not discover the
  world, rebuild helpers, reset queues or reset an active rebuild report.
- Revision 3 classifies old observer entries through bounded service, preserving
  helpers, queues, service cursor, GUI sessions and reports. Ordinary load is pure.
- Native Map settings and Administration Global rules share the same authority.
  False checkbox values now survive snapshots and untouched editor refreshes.
- Administration exposes reasons, sessions, candidates, deadline and independent
  attempt/completed-scan counters. Inspect includes deadline entries.
- The ungated Informatron page under New mechanics uses a helpful engineer voice,
  explains all controls and the 600-machine timing example, and takes a pure settings
  snapshot only when opened. All eight locales contain the page and new controls.

Existing geometry, pipe modes, master/companion precedence, occupancy handling,
five scripted recipe-write notifications and the refresh remote interface remain.
Silent external changes require the refresh hook; no fallback sweep was added.

## Static and native evidence

- Offline: 373,824 deadline/scanner assertions, 306 fairness/status checks,
  41 observer/session checks, 41 rebuild lifecycle checks, and 18 Map transaction
  checks. The 944 locale assertions cover 116 English keys in all eight locales.
- Native scheduler: managed run `0c8eade6ff54421e97ab63475a6671a3`, 118 candidate
  and 125 reload assertions, including indexed deadlines and serialized indices.
- Native full development profile: managed run
  `b174b9c982134c44895b388fad36bc6c` accepted 30 receipt groups: the sixteen mode,
  transition, reload and switch groups; Administration plus reload; seven scripted
  owner cases; actors; and ten guide cases. Administration produced 1,950 assertion
  records and reload 2,937, including repeated guards rather than independent cases.
  The writer fixture covers all five write sites in seven cases (24 assertions).
- Actual Squeak Through 2 package precedence passed in managed run
  `1566a89a4ae2401c861d0ed77070f182`.
- Native focused observer/movement: managed run `07e48b32e8d848508064dd33e0be7b58`,
  fourteen checks plus sixteen on reload. Native checks cover tick 59/60, next-tick
  reconciliation, refreshed deadlines, scanner parking, GUI recipe changes and real
  character walking against a connected and then removed machine-port barrier.
  The ordinary reload preserves helper/observer populations without topology work.
  The same run also proves the corrected old/new circuit settlement probes.
- Native revision 1 → 3 classification in the final benchmark run loads the actual
  frozen owner's populated save. With budgets 1 + 1, 1,000 permanent observers
  become 100 circuit observers; all 901 helper identities, owner/queue identities
  and rebuild state remain intact. Across 1,201 ticks, 4,510 assertion records
  confirm both attempt caps and no topology work or helper churn during adoption.
- Broad preflight: eleven checks pass. The sole failure is the pre-existing
  suspected mojibake in `scripts/qc/singularity-lance/angular-results.json`.

## Rendered evidence

The full-profile archive retains thirty guide captures across all eight locales,
Vanilla mode and master disablement. Each guide case passes 65 native assertions
and resolves 22 translated captions. Current-setting values derive from the owner,
scroll positions differ, and opening the page leaves serialized passage state
unchanged. The retained Administration captures show the three runtime controls,
observer diagnostics, active reconciliation and character-clearance waiting.

The focused observer archive retains the complete native machine GUI and a WebP
assembled from nine pairs of hash-verified walking frames; no motion is synthesized.
Native screenshots establish rendering, not independent native-speaker review.
Informatron's existing Traditional Chinese clock header exposes untranslated plural
formatting tokens; the new page content and navigation render correctly. That host
header is outside this patch.

## Performance method

The 160-trial matrix uses 1,000/10,000 crafters, 0%/10% circuit selection,
main budgets 256/1,024, circuit budgets 1/1,024 and five old/new trials per case.
An unwired native circuit selector can retain its previous recipe. Both measured
revisions therefore start the selected circuit population explicitly recipe-less.
Settling verifies expected helper counts before explicit-refresh and native circuit
latency probes, then takes a common 4,096-tick checkpoint. Whole-tick cost, passage
profiler time, memory, attempts, helpers and latency are separate measurements.
An overlapping unrelated Factorio process invalidated one attempt; it is excluded.
The user approved an exclusive validation window for the remaining runs.

The final matrix is managed run `2c84b9df7c344eaf922f5064609e269a`. It uses isolated
Base fixtures containing the actual passage owner; full-profile correctness is
verified separately. Do not extrapolate its tick-cost differences to an entire
modded factory's UPS. The earlier 80-trial pipe-network/burst evidence belongs to
the administration extension's recorded source revision, not this crafter matrix.
The frozen baseline is the original permanent-observer owner, not the intermediate
revision 2 implementation. Both measured owners use identical supporting fixtures
and libraries.

## Measured results

**All 160 runs and all 80 paired comparisons passed.** Every new-owner measurement
was faster than its matched baseline. The smallest reduction was **0.162910 ms/tick**;
the smallest margin inside the required larger-of-5%-or-0.1-ms/tick allowance was
**0.262910 ms/tick**. Each measured process was isolated from other Factorio processes.

At the default main/circuit budgets **256 / 1**, means across five runs were:

| Crafters | Circuit selection | Native old → new (ms/tick) | Passage script old → new (ms/tick) | Peak private old → new (MiB) |
|---:|---:|---:|---:|---:|
| 1,000 | 0% | 0.391759 → 0.192006 | 0.194249 → 0.004924 | 421.2 → 409.2 |
| 1,000 | 10% | 0.421829 → 0.252589 | 0.193924 → 0.034309 | 414.4 → 409.6 |
| 10,000 | 0% | 1.714209 → 0.964761 | 0.733484 → 0.005456 | 586.2 → 515.1 |
| 10,000 | 10% | 1.654990 → 0.970171 | 0.723135 → 0.042425 | 574.0 → 513.9 |

Memory is sampled whole-process private memory, not a Lua-only allocation measure.
All manual populations produced **zero GUI and circuit attempts** after settling.
At circuit budget 1, each circuit population made 5,990 attempts over the 5,990-tick
observation interval. There were no idle topology queries or helper creations or
destructions in either measured revision. Matched helper totals were 1,000/10,000
for manual populations and 901/9,001 for 10% circuit populations; one selected
machine receives the probe signal, restoring its fluid recipe and one joint.

The low scan budget trades response time for work limits. At 10,000 crafters with
1,000 circuit candidates and main budget 256, the native signal-to-joint probe took
**960 ticks** with circuit budget 1 and **58 ticks** with circuit budget 1,024.
Passage script time rose from **0.042425** to **0.281713 ms/tick** in those cases.
Explicit refresh completed in **one tick** in every settled layout. These are
controlled probe results, not worst-case or guaranteed response times. The JSON
retains initial queue-settlement ticks, native signal-to-recipe and recipe-to-joint
latency separately; the common measurement checkpoint remained tick 4,096.

The [compact benchmark archive](../../../.factorio-qc/managed/2c84b9df7c344eaf922f5064609e269a/evidence.zip)
contains `reports/observer-performance-summary.md` (the complete sixteen-case
table), `reports/observer-performance-summary.json` (structured metrics), all
trials, process monitors, checkpoints' hashes, legacy receipts and final source
verification. Baseline owner SHA-256 is
`87270e9052353f54df6b3f281f8ff66c5886c50092bf5ed8e16af5080c775ece`;
delivered owner SHA-256 is
`6aa7afdbf450b1a62b55724088d6bc1f8bbae34ab19d60fdef6fedfa5d167648`.
Fifteen current production-file hashes match the accepted native evidence.

## Verification boundaries

Physical recipe-picker interaction and actual two-client synchronization remain
separate gates. Earlier programmatic GUI events are not physical picker evidence.
The earlier two-client attempt loaded the same Steam cloud identity for both peers;
it does not establish two-client acceptance. Do not alter user account/cloud data.
The native legacy fixture isolates budgeted schema adoption from the existing
deliberate configuration-rebuild dispatcher. Configuration changes still rebuild
the topology catalog and helpers according to the established lifecycle contract;
ordinary load and observer schema classification do not.
Native setting definitions/API writes and the Administration editor were tested;
the built-in Mod settings screen was not manually operated. Surface clear/delete
has native actor coverage; import-report transitions use source review and mocked
native boundaries. Existing death/presentation definitions are unchanged; this
extension does not claim a new exhaustive death-effect render review.

Two early full-profile views were invalidated by concurrent `control.lua` edits.
Run `90042550dc214e9bb353e131264b9285` then exposed delayed GUI admission behind
dirty work; the owner and focused regression test were corrected. Source guards
must remain enforced when closing these superseded views.

Successful full-profile, companion, focused-observer and benchmark runs are closed and
compacted. The superseded source-invalidated runs remain protected; their guards
were not bypassed. An incomplete forty-trial batch in `07e48b32e8d848508064dd33e0be7b58`
preceded correction of the recipe-less starting condition and is excluded from the
final 160-trial acceptance.

The unique uncommitted baseline and intermediate sources remain pinned in
`925129974b1e465da385ef527ed29cd6`. No live source or installed mod directory was
used as disposable staging.

No deployment, issue posting, commit or version change is authorized.
