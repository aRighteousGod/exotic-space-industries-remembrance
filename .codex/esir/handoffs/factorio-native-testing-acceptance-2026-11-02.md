# Factorio 2.1.24 native testing acceptance

Implementation and qualification completed on 2026-11-02 under main-mod version
1.4.03. All seven required core families passed in one complete final `qc-full`
execution. The aggregate records eleven profile rows and twenty completed phases.

The native result is **ok**. The overall `qc-full` result is **failed** because
the existing historical encoding finding in
`scripts/qc/singularity-lance/angular-results.json` remains active. The broad
delegate records **warning**, including the supplementary Gaia companion's
incompatible Factorio 2.0 metadata. Asset and package checks are **ok**.

The machine-readable aggregate contains every child result, the broad checks,
encoding findings and common source fingerprint. The broad run was closed and
compacted after its final-data consumers finished.
[Final aggregate](../../../.factorio-qc/fmqc/qc-full-4a1f2e541b424d48ae64a155fd68912a.json)

## Delivered interface and ownership

- `test-list`, `test-plan` and `qc-test` are available through the repository
  wrapper. Exact suite/case/profile selectors, core/extended selection and
  committed/dirty-worktree routing are implemented.
- The catalogue contains 68 suites and 36 nested components. Its top-level
  statuses are 9 active, 56 needs-port and 3 historical. The mandatory core has
  seven families. Runner conformance and the separately integrated runtime-options
  suite account for the other active entries.
- Native execution uses private managed inputs, exact engine/base/profile checks,
  explicit terminal completion, report identity/freshness validation, independent
  Lua and host deadlines, owned-process supervision and compact evidence closeout.
- A common gameplay/configuration fingerprint spans all selected rows and the
  broad/native portions of `qc-full`. Per-run staged input and harness validation
  remains active throughout execution.
- Shared save-aware helper staging, checkpoint paths, Quality adapter context/reuse
  handling, individual skill integrations and profile-derived version guidance are
  implemented. The 64-row Quality matrix retains its separate migration status.

The operator guide and catalogue own the reproducible commands and selected rows.
[Native testing guide](../../skills/esir-dev/references/native-testing.md),
[suite catalogue](../test-suites.json)

## Final core evidence

Engine and adjacent base data are **2.1.24**, build **87808**. The selected
development dependency lock has SHA-256
`8f509c61cfebdcca625577ad4ed14f2b491e1c4cf1a63260d8ca78f09130161a`.
The final broad/native common source fingerprint is
`76cabbfba0da8313ec6938b9fbf7dd3d05fc5d3fc4ddce5d6c42542966335716`.
The aggregate reports no source-fingerprint or receipt-parsing errors.

The twenty terminal reports contain **16,767 passing check records**. These counts
include per-phase profile assertions and repetitions across matrix rows. An
additional **228 passing host checks** validate captured final-data and exact
saved research state. All eleven child evidence archives passed integrity checks.

| Suite and profile | Candidate | Ordinary reload | Configuration | Receipt |
| --- | ---: | ---: | ---: | --- |
| Alert preferences / default | 190 | 47 | — | [d26920f3](../../../.factorio-qc/managed/d26920f308274174b3629e7455476214/final-result.json) |
| Build dispatch / default | 930 | 56 | — | [9698df83](../../../.factorio-qc/managed/9698df8341034fe4a9f5353d7fd2e026/final-result.json) |
| Induction circuits / default | 137 | 48 | 48 | [0dd561ff](../../../.factorio-qc/managed/0dd561ff71f04a928701108eece78c1f/final-result.json) |
| Mirroring / Quality enabled | 7,239 | 79 | — | [113288d4](../../../.factorio-qc/managed/113288d4bf91413baf8a420a8feea072/final-result.json) |
| Mirroring / Quality disabled | 7,199 | 79 | — | [eade16e4](../../../.factorio-qc/managed/eade16e40ab04edc84e750dad4af476c/final-result.json) |
| Bootstrap / no_triggers=false, flatten=false | 44 | — | — | [0959bab5](../../../.factorio-qc/managed/0959bab50a3f4d94a0f8b1c3b3d89322/final-result.json) |
| Bootstrap / no_triggers=false, flatten=true | 44 | — | — | [fb7c64f1](../../../.factorio-qc/managed/fb7c64f1864b433cad5dbc5414b3af5e/final-result.json) |
| Bootstrap / no_triggers=true, flatten=false | 65 | 46 | — | [d383173b](../../../.factorio-qc/managed/d383173bda464b76a99603d903ac0667/final-result.json) |
| Bootstrap / no_triggers=true, flatten=true | 44 | — | — | [84130d57](../../../.factorio-qc/managed/84130d570dff4249ad80d0e88d9f67b4/final-result.json) |
| Research events / default | 176 | 53 | — | [be87e440](../../../.factorio-qc/managed/be87e4404bc24c87baba9be24ec2df79/final-result.json) |
| Scheduler and event ticks / default | 118 | 125 | — | [582ec7e0](../../../.factorio-qc/managed/582ec7e0e05146efb0f1bba7668df00b/final-result.json) |

The laboratory row verifies ordinary completion and exact progress, inventory and
queue persistence. The two mirroring rows use the current checker, with historical
differential evidence retaining its original provenance. Player-dependent
checkpoint producers use the declared graphical executor. All functional phases
use the native testing API and preserve ordinary-reload helper content.

## Qualification and tooling checks

Final runner conformance passed all seven cases, covering successful completion,
reload, explicit failure, Lua error, missing report, tick-limit exit zero and host
timeout. The final run is closed and compacted.
[Runner conformance receipt](../../../.factorio-qc/managed/bd6894f2f42c4701842a58a1300d126e/final-result.json)

All seven prescribed private defects were detected on the same gameplay
fingerprint as final core acceptance. Their child receipts record the intended
failed execution, while qualification verifies the specific failure and rejects
unrelated errors, altered inputs, stale reports and invalid evidence.

| Defect | Qualified receipt |
| --- | --- |
| Drop the build receiver's supplied tick | [4357dc31](../../../.factorio-qc/managed/4357dc31bb684a9e88790d0e82dae0a8/final-result.json) |
| Ignore the supplied scheduler clock | [14f46682](../../../.factorio-qc/managed/14f46682485c4abebed09f9bfa12e3d2/final-result.json) |
| Omit a scripted research receiver | [87a75f8a](../../../.factorio-qc/managed/87a75f8a98244ef9aaf98d86ee6a7c10/final-result.json) |
| Mutate the shared science template | [12606e71](../../../.factorio-qc/managed/12606e71f7e34f29bdb350e6e4991461/final-result.json) |
| Enable induction outputs by default | [934a413e](../../../.factorio-qc/managed/934a413ef2f848f0b9f6b91fe9caca4b/final-result.json) |
| Ignore personal alert Off | [8672233b](../../../.factorio-qc/managed/8672233bbeea463a9020001c3a3878c9/final-result.json) |
| Disable an approved mirroring opt-in | [865893ac](../../../.factorio-qc/managed/865893acfde54476b9066b3709a29ff3/final-result.json) |

- 22 Python host tests passed, including selectors, dirty rename/deletion routing,
  matrix completeness, malformed evidence, changed inputs, child timeout,
  engine-family rejection and Windows PowerShell module resolution.
- 12 PowerShell checks passed for shared helper staging and required child-result
  propagation.
- All 17 affected skill validators passed. Catalogue inventory/model-link checks,
  focused routing requests, blueprint audit and scoped whitespace checks passed.
- Preflight passed eleven checks. Its encoding-health check reports the historical
  `angular-results.json` finding identified above.
- A conformance registration attempted during broad closeout encountered the
  shared registry lock. Closeout completed and the sequential retry passed.

## Repairs found during qualification

The induction suite exposed a production interaction with Factory Passage.
Tile-corner probes missed coils and solenoids after their collision boxes were
reduced. Component discovery now scans the full logical tile. The original legal
coil placement and 25 MJ assertion passed along with reload and configuration
repair. The model and current-version changelog record the correction.
[Induction source](../../../exotic-space-industries-remembrance/scripts/control/induction-matrix.lua),
[induction model](../blueprints/induction-matrix.md)

The research reload fixture initially required physical delayed buckets to be
empty after controlled immediate flushes. The existing production contract permits
cancelled entries while live pending work is empty. The corrected fixture captures
and compares their saved counts, requires zero pending forces and zero next-due
tick, and separately checks that ordinary reload ran no configuration repair.
The first complete aggregate propagated that required failure. The final complete
aggregate contains the passing corrected case.
[Earlier failed aggregate](../../../.factorio-qc/fmqc/qc-full-964bcab6f3584ae082a14ab6cac25062.json)

Other qualification repairs include private intro suppression for graphical
checkpoint production, verified short paths for Windows sprite loading, explicit
engine data paths, authenticated reads of compact evidence, and isolation of
Windows PowerShell's module path when launched from Python under PowerShell 7.

## Evidence boundaries and retained gaps

Native GUI elements, programmatic callbacks, controlled clocks and injected
dispatcher probes carry their distinct fixture labels. Dedicated rendered layout,
mouse interaction, performance, multiplayer and historical migration acceptance
follow their separate catalogue requirements. Existing receipts preserve their
original engine/version and source provenance.

The supplementary global Gaia companion requires a metadata/API port from its
current 2.0 template before it can provide current native acceptance. The catalogue
continues to expose Gaia generation, the full Quality matrix, cryo, presentation,
combat/entity and other deferred families through explicit migration status.
The concrete Gaia finding and remaining migration work are recorded for follow-up.
[Revisit notes](../REVISIT_NOTES.md)

The implementation and evidence remain in the working tree and managed artifact
store. Local commands and JSON results provide the integration surface for later CI.
