# Orbital native upgrade - accepted implementation

The approved native-first orbital logistics/scanner/radar plan is implemented. The durable [acceptance report](../../../scripts/qc/orbital-logistics/README.md) owns current results, reproduction commands, exact workload limits and evidence links. Older progress notes are superseded. Main version remains **1.4.03**; no commit or deployment was requested.

## Delivered behavior

- Explicit native/cohort uplink ownership, safe adoption, native target authority, source-aware request eligibility, guarded mixed cargo, exact per-platform Need and confirmed-once launch accounting.
- Bulk inventory acquisition and operation-local request/incoming/stock batching, preserving the existing scheduler budgets and freshness. Native-only lanes do not request scanner Need work.
- Native hub/silo relative panels; named selector targets; coordinator Platforms/Rocket Lanes tabs, search, location filters and working cross-surface native-window links. Detail work is limited to visible panels; advanced state is tucked away.
- Player configuration survives rebuild, reload, configuration, settings paste, clone and actual blueprint/revival/overwrite. All eight locale sidecars, Informatron radar wiring examples, both subsystem models and current-version changelog are updated.
- Named native output groups were accidentally sharing filters across devices. Independent output sections and scanner schema 6/cohort schema 9 repair that while preserving configuration. Bridge reads now notify the existing dirty-bank queue when they observe changed values, preventing missed circuit publication.

## Acceptance

Exact engine: **Factorio 2.1.24 build 87808**, dependency lock `8f509c61cfebdcca625577ad4ed14f2b491e1c4cf1a63260d8ca78f09130161a`.

- Quality enabled `d18f92011be449eca5394693b5a49503`: candidate 127, rendered checkpoint 152, reload 57, configuration 57 assertions passed.
- Quality disabled `7726bb4ea32044199366a7b73edfa5a3`: candidate 126, rendered checkpoint 151, reload 57, configuration 57 assertions passed.
- Static preflight passed. Shared runner: 22 host tests, 12 helper checks and seven-phase base-only native conformance `a57859cb3c87431c81a5dc0cd9196633` passed. All seven core intentional-defect suite controls passed with zero source errors; final-validation.json records every run ID.
- Performance `63afab879fe849bf9b07dbe1a15ce8a4`: **72 serial trials, 60 retained samples**, five retained alternating pairs for each of 1/10/50 platforms and each measurement family. Semantic parity and identical response latency passed. Median paired active-script reductions: **44.45%, 41.29%, 48.90%**. Whole-engine reductions: **10.20%, 14.16%, 28.27%**; all 15 retained engine pairs improved. Keep the optimization.
- Artifact verification passed: 325 indexed archive members plus archive-covered manifests, 12 PNGs, exact 72-trial inventory, workload/source/seed hashes and archived sample equality. Six final English 1280x720 panels were visually reviewed.

Performance is a matched sparse inventory workload with four banks, one actual viewer and explicit bridge calls in open phases. Both variants contain the independent-output and publication correctness repairs. Source hashes in benchmark metadata normalize UTF-8/LF; raw retained-byte hashes are separately recorded. The engine's verbose CSV export crashes, so engine claims use standard total-update results, not per-phase engine figures.

Physical mouse/keyboard interaction, two-client multiplayer, all-locale rendering and full thruster-driven journeys remain unverified. Direct location changes are narrower than full flight. Radar wiring has native functional coverage, but no radar-versus-scanner whole-engine benchmark is claimed.

## Preservation and evidence ownership

Protected task run **80e261cd4fba45549860cd609e44a555**, payload `.factorio-qc/orbital-native-20261102`, retains original source snapshots, private benchmark scripts/seed, measurements, analysis and verification. Managed native archives live under `.factorio-qc/managed/<run>/evidence.zip`; rendered PNGs remain in each run's `rendered/` directory.

The comparison baseline is `baseline/` in the protected task root, not git HEAD. Concurrent movement/power/Factory Passage/Administration work remains intact. A scoped final check compares 41 movement/power functions: 40 are identical and the remaining movement callback only gains GUI event-tick forwarding. Recipes, research, entity roster, graphics, dependencies and power costs were not changed by this task.

Keep historical failed/interrupted runs as evidence. In particular `bbc40664c82040b3a63367a97f8fb764` remains protected-error because source changed during that run; it is not a current acceptance receipt. Ten exact empty directories from the initial sandboxed host-test attempt were safely retired, with a retained cleanup manifest. Do not apply global housekeeping to concurrent work.
