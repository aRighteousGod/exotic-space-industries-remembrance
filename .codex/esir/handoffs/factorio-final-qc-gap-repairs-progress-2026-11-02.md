# Final QC gap repairs progress

## Completed on 2026-11-03

The approved final-gap plan is complete. Fresh `qc-full -Strict` run
`a5137622f3d745228b7d144f70c38180` returned **ok**, including all seven core
families, eleven rows, twenty phases, 16,767 native check records and 228 host
postchecks. Required Gaia passed 56 native checks and nine host checks. All five
broad checks returned ok with zero warnings/errors. The common source fingerprint
remained `25cd80b96c0e43d7fcdcf85d086f152824d008ec21787a2e4347fed71d9d2feb`.

Fresh adverse conformance `6fc02a14f7a147fb9462614f7c5c2ac2` passed all seven
cases. All current evidence archives passed hash/integrity checks. The final broad
run and older completed task-owned broad/preview runs closed and compacted.
Prior input-integrity failures retain protected-error status with task ownership
closed. Dependency refresh completed at 108 declarations and 102 touchpoints, and
its read-only diff is clean. Version remains 1.4.03. This task did not commit,
push or deploy changes.

The [dated acceptance record](factorio-final-qc-gap-repairs-acceptance-2026-11-03.md)
contains final receipt links, warning disposition, evidence boundaries and closeout.
The sections below retain the earlier execution and pause history.

## Resumed on 2026-11-03

The user requested continuation. No Factorio or native-suite processes remained
from the paused execution. Strict preflight is running before a fresh complete
`qc-full -Strict` qualification. Main-mod version remains 1.4.03 and the exact
2.1.24 engine/dependency profile is unchanged.

The current common source fingerprint is
`25cd80b96c0e43d7fcdcf85d086f152824d008ec21787a2e4347fed71d9d2feb`.
Twenty-one gameplay/locale paths changed since the interrupted run, principally
orbital logistics, its UI, dispatcher integration and locale text. Preserve this
concurrent work. Earlier partial receipts do not establish acceptance of these
current inputs. The worktree inventory and initial fingerprint are recorded in
`temp/final-gap-worktree-20261103.txt` and `temp/final-gap-source-20261103.json`.

Strict preflight passed all twelve checks. The complete strict run is active as
`a5137622f3d745228b7d144f70c38180`, with its output redirected to
`temp/final-gap-full-20261103.json`. Its PowerShell owner is PID 15424, created
`2026-11-03T13:33:29.8449788Z`. Always recheck process identity before any stop.

Current host checks passed 26 Python tests, 15 encoding/UTF-8 checks in each of
Windows PowerShell 5.1 and PowerShell 7, twelve helper checks, eleven preview and
failure-propagation checks, and fifty controlled Lua assertions. Runner and
catalogue changes from the orbital work require fresh adverse conformance after
the full run. The current catalogue has seventy suites, eleven active, fifty-six
needs-port and three historical, plus thirty-six explicitly classified components.

The broad child of `a5137622f3d745228b7d144f70c38180` passed all five checks with
zero warnings/errors, including 39 final-data assertions and the fixed Gaia preview.
Gaia child `d3ad4b08d86449cda4ee8d37095e6e67` passed 56 native assertions and nine
host postchecks and compacted successfully. Its archive hash and every indexed
entry were verified. The runtime report records native 2.1 generation, surface
`esir-qc-gaia-runtime`, all 16,777,216 Gaia tiles and resource counts 4/6/4/5/8/10
in policy order. The core matrix is running, beginning with alert preferences.

Six affected skill validators passed. Current read-only change planning selected
seventeen rows and honestly reported ninety-nine uncovered paths and ten
supplementary requirements across the large shared worktree. Planning coverage
gaps are distinct from required core acceptance. The prior Gaia matrix and both
controlled-defect evidence archives were also hash/integrity verified.

## Latest pause on 2026-11-02

The user requested another save-and-pause during the replacement full run.
Execution is paused. Overall acceptance remains incomplete.

The verified task-owned process tree was stopped using process IDs plus creation
times. The stopped processes were full-wrapper PowerShell 33080, native-core Python
17532 and its Factorio child 29748. The guard initially rejected a timestamp
conversion mismatch without stopping anything. The corrected guard matched the
recorded identities. `temp/final-gap-pause-20261102.json` records the stop.

### Latest complete results

- Broad full run `8f6f0cabfec441d1b931c52bccc2b60a` passed fast/final-data,
  runtime smoke, preview, assets and packaging. Its final-data gate passed 39
  assertions. The broad run is still task-open with cleanup ready for later closeout.
- Its corrected Gaia child `9b524b308eea46b1bac4812b57ac15ea` passed and compacted.
  Current Gaia qualification requires 56 native checks and nine host postchecks,
  explicit native 2.1 revision, the named runtime surface and Gaia tile presence.
- Corrected strict custom preview `bc4cc959dabe471ba36fdd6fea1d201f` passed the
  fixed Gaia row and requested Nauvis seed-42 output. Task closeout remains pending.
- Controlled defects passed qualification in `1b95e61357324ff68c767ca16297b7a9`
  for missing relic resources and `c85a03f9309d415c9bc8a0afdc73d1a6` for selecting
  the legacy generation branch. Their failed child evidence is compacted.
- Final-version adverse conformance passed all seven cases in
  `a064e2220cbf4e29ac95dc88b17b1d9f`, with compact closeout.
- The Gaia preview matrix passed all eight seeds and six resource-disable probes
  in `3c424219ccf542508cc796a32aee5adb`, with compact closeout.
- Dependency catalogue refresh completed and its read-only diff is clean, with
  108 declared dependencies and 100 touchpoints. Five affected skill validators,
  blueprint audit, generic preview routing and focused Gaia selector checks passed.

### Completed core rows in the interrupted full run

These six rows and twelve phases passed and compacted, totaling 16,096 native
check records. They remain individual receipts. Full acceptance requires a fresh
complete aggregate.

| Suite/profile | Candidate | Reload | Configuration | Run ID |
| --- | ---: | ---: | ---: | --- |
| Alert preferences/default | 190 | 47 | — | `dd7b359135fc4f1cac1e4ef3421ae588` |
| Build dispatch/default | 930 | 56 | — | `73e5b893fcc04c8a98e0c79253d49024` |
| Induction/default | 137 | 48 | 48 | `a014f21757c547258aa6bb7d1e65ac51` |
| Mirroring/quality-enabled | 7239 | 79 | — | `f62b5821703944d69a92d4e78b1b0a2a` |
| Mirroring/quality-disabled | 7199 | 79 | — | `8a9cc1a2ed40485fb55b97cd5008119c` |
| Research bootstrap/triggers-0-flatten-0 | 44 | — | — | `566d38571d204e39a80e91f7aa529d88` |

Research bootstrap `triggers-0-flatten-1` was interrupted in run
`64d459b4033044c090c7fca311b08f6c`. Managed closeout completed with status `failed`,
task ownership closed and cleanup `compacted`, using the explicit user-pause reason
and no accepted phases. Its result is recorded in
`temp/final-gap-pause-closeout-20261102.json`.
The interrupted full run produced no final complete aggregate. Its redirected
`temp/final-gap-full-current-20261102.json` is incomplete and carries no acceptance.

The remaining core rows were the other three bootstrap settings rows, research
events and scheduler/event ticks. On resume, run a fresh complete `qc-full -Strict`
against stable sources. Then close task-owned broad runs, preserve protected failure
records, perform final static checks and publish the dated acceptance follow-up.
Main-mod version remains 1.4.03. All edits remain uncommitted.

## Resumed qualification and surface review

Work resumed on 2026-11-02. The user confirmed the concurrent task had finished.
The current implementation remains in qualification.

- All 26 Python tests, 11 preview/matrix PowerShell checks, 50 controlled Lua
  checks and two owned-process bridge checks passed. Preflight passed all 12 checks.
- The 39 corrected final-data assertions passed diagnostically and in the fresh
  broad full run `3acdc93a8ac846cfa7e0c7f9cea74de0`.
- The eight-seed and six-control Gaia preview matrix passed in run
  `3c424219ccf542508cc796a32aee5adb` with compact closeout.
- Full adverse runner conformance passed all seven cases in
  `c7318d0aae6945d2839736ffae55fd0c`.
- Initial Gaia native runs passed 53 checks. A private missing-relic defect was
  detected in `e03cee0ba5ca42c2b1c09174db448de5`.
- The user observed a window that looked unlike Gaia. Its recorded command belongs
  to the alert-preferences graphical reload checkpoint
  `dbe6ac3c9b81478a9279af71112ed295`, which passed both phases.
- Receipt inspection also exposed a real Gaia fixture issue. Passing `{seed=1000}`
  into the runtime factory's preserved-settings argument selected the legacy
  generation revision. The fixture now calls the fresh factory with no argument,
  then pins the seed. New assertions and host checks require the native 2.1
  generation revision, Gaia terrain expressions, Gaia tiles and surface identity.
  All 26 host tests passed after that correction. Corrected native run
  `f74e62422ebe4ba4b8fcc451fd928820` passed 56 checks and nine host postchecks,
  with all 16,777,216 measured tiles belonging to Gaia's tile catalogue.
- Strict custom preview `bc4cc959dabe471ba36fdd6fea1d201f` passed both the required
  Gaia coverage and the explicitly requested Nauvis seed-42 output. Its broad run
  still needs task closeout after all inspection is complete.
- Corrected private negative controls detected the missing relic resource in
  `1b95e61357324ff68c767ca16297b7a9` and the legacy generation branch in
  `c85a03f9309d415c9bc8a0afdc73d1a6`. Both are compact failed child receipts with
  successful qualification verdicts.
- Full aggregate `qc-full-3acdc93a8ac846cfa7e0c7f9cea74de0.json` was superseded by
  the fixture correction. All broad checks passed. Harness integrity rejected
  continuation of the core selection against the changed fixture code, so its
  final aggregate is failed. A replacement full run follows fresh conformance.

Additional protected receipts remain from source changes during execution. Run
`5e470c6df2f24e47b8a7cca21fe12d77` was invalidated by this task's changelog edit.
Preview run `5b990b5d7d2245468223ab2420edf2c1` had passing functional checks but
was invalidated by another changelog edit at closeout. Preserve their failure
provenance and use guarded managed closeout.

## Earlier pause checkpoint

Paused at the user's request on 2026-11-02. Implementation is partial. Final
qualification and the required strict full run are pending.

## Approved outcome and defaults

Implement the approved final-gap repair plan covering every warning family in the
earlier full run, the historical encoding gate, and the Gaia companion. Completion
requires a fresh `qc-full -Strict` result of `ok` on consistent inputs.

- Exact engine and adjacent base remain 2.1.24, build 87808.
- Preserve the current development dependency lock and main-mod version 1.4.03.
- Preserve concurrent work, historical receipts and the original seven-core suite
  qualification. This follow-up has no commit, push or deployment authorization.
- Keep the historical angular receipt intact. The user selected a narrowly pinned
  informational encoding record.
- Ordinary preview/full QC requires a fixed seed-1000 Gaia preview and native
  resource case. Qualification additionally requires the existing eight-seed and
  six-resource-disable matrix.
- Native, final-data, preview, rendered, performance, multiplayer and historical
  evidence retain separate labels.

The original native integration acceptance remains in
[the earlier acceptance record](factorio-native-testing-acceptance-2026-11-02.md).
Its final aggregate is `qc-full-4a1f2e541b424d48ae64a155fd68912a.json`, with native
core passing and overall QC failing on the historical encoding finding.

## Changes applied during this follow-up

### Encoding and global harness

- Added `.codex/esir/preserved-encoding.json` for
  `scripts/qc/singularity-lance/angular-results.json`.
- Pinned LF-normalized SHA-256
  `2f3c5ed418b0559f74220ca2963c4bde2d4faf1156ac075afacb3a5e9bc0bc12`, engine 2.0.77,
  `complete=false`, 32 punctuation-mojibake and 32 C1-control findings.
- `Invoke-EsirEncodingPass` checks the hash and finding counts, returns a matched
  record as informational with `status=ok`, and fails altered or missing records.
  Both matched and mismatched registered receipts are protected from `-FixEncoding`.
- Global `factorio-mod-qc/scripts/factorio-qc-lib.ps1` now decodes native output
  and log files as UTF-8 and restores caller encoding.
- The same global file has an optional `Context.preview_companion` hook. ESIR's
  delegate supplies its repository preview implementation. Other contexts retain
  the generic preview body.
- Global `factorio-mod-qc/SKILL.md` documents the hook, current ESIR delegation,
  historical template scope and UTF-8 capture.
- These global edits were applied with approved escalated patch commands because
  the files are outside the repository. The Windows batch patch wrapper rejected
  a multiline argument initially. Calling the actual patch executable succeeded.

### Production source fixes

- Logistic-chest iteration uses the five array values. Items are hidden and recipes
  are hidden and disabled. Removed the unsupported item `enabled` assignment.
- Accumulator settings use `link-multiplier-to-cost`.
- Conditional `accumulator-v2` technology lookup uses direct presence inspection,
  preserving the SolarMatrix/Paracelsin branches and icon fallback.
- Removed the absent mining-productivity tier 4 and shooting-speed tier 7 entries
  from the active age tables.
- Tesla category creation uses a quiet existence check before creating categories.
- Optional steel-gear recipe selection uses direct presence checks.
- Shared recipe swapping/normalization returns without mutation for nil optional
  ingredient/result arrays. Existing malformed and missing-target diagnostics remain.

### Gaia and required final-data checks

- Added an active, non-core `gaia-resources` catalogue entry with case `candidate`,
  profile `default`, seed 1000, 3600 ticks, 600 seconds and server checkpoint metadata.
- Added `scripts/qc/gaia-resources/runtime.lua`. The private fixture calls the
  production runtime settings factory, requests a 4096 square in 64-chunk batches,
  checks completion of 16,384 requested chunks and counts all six resources. It also
  checks effective accumulator settings.
- Added `native-tests/gaia_resources.py` for private staging and measured-report
  postchecks. Native envelopes now carry suite-owned `parameters`, and terminal
  reports optionally retain `metrics`.
- Added `native-tests/process.py`, a structured bridge to the existing owned-process
  supervisor. It returns run identity, request hash and process evidence.
- Added `native-tests/data_contracts.py`. It reuses the existing bounded final-data
  reader and checks chests, current technology ages/science/prerequisites,
  accumulator costs/icon, Tesla categories/weapons/effects and empty helper recipes.
- Added `scripts/esir-qc-acceptance.ps1` for owned preview processes, quantity
  parsing, required native Gaia child validation, fixed/custom previews and the
  dedicated matrix. It is dot-sourced by `esir-dev-lib.ps1`.
- The old Gaia matrix body now delegates to `Invoke-EsirGaiaResourceMatrix`, which
  preserves seed/size overrides and the six control probes. Its `-Strict` flag is
  propagated from the task dispatcher.
- The broad delegate runs required final-data checks after a successful fast check,
  before dump closeout, and registers the repository preview hook.
- Native harness fingerprint inputs include the new fixture, acceptance module,
  preservation manifest and Gaia policy.

These new Gaia/preview/final-data integration paths have not yet completed native
qualification. Review and test them before relying on their receipts.

## Verification performed

- `test_encoding.ps1` passed all 15 checks on Windows PowerShell 5.1.19041.7802
  and PowerShell 7.6.5. Windows PowerShell was rerun successfully after integration.
- Existing `test_helpers.ps1` passed 12 checks.
- Existing Python `test_runner.py` passed all 22 tests when rerun outside the
  sandbox. The first sandboxed attempt failed on access to Python-created temporary
  fixture directories. Those permission errors were unrelated to test assertions.
- New `test_data_helpers.lua` passed 50 controlled host checks with the repository's
  Lua 5.4 interpreter. This covers real shared helper code and focused source blocks,
  with explicit host-evidence labeling.
- `test-list --suite gaia-resources` passed catalogue/inventory/model-link validation.
- The Gaia Lua fixture passed `luac54 -p`.
- The acceptance PowerShell module parsed without errors.
- Scoped `git diff --check` passed. Git emitted ordinary LF/CRLF notices.

### First strict fast run

Run ID `aeb3eca8f8f44485a3532982911183d9`.

- The actual Factorio fast result was `ok`, with zero warnings and zero errors.
- Encoding returned `ok` with the preserved historical finding.
- Overall execution failed input integrity because another task changed
  `exotic-space-industries-remembrance/scripts/control/railgun-cooling.lua` during
  the run. The user was informed and integration work continued.
- The managed run is protected, failed and still task-open at this checkpoint.
  Resume through the managed closeout path after inspecting its state. Preserve
  the source-change failure and avoid manual registry edits or forced cleanup.
- Its diagnostic dump is approximately 2.08 GB at
  `.factorio-qc/scratch/aeb3eca8f8f44485a3532982911183d9/fast-20261102-171249-e699e4/script-output/data-raw-dump.json`.
  Use the bounded reader in `scripts/qc/factorio-2.1/final_data.py`. Avoid loading
  the entire dump with `json.load`.
- `data-contracts-diagnostic.json` in that run's managed evidence contains 38
  executed checks with one fixture error. The checker looked for the Tesla turret
  in `ammo-turret`, while production uses `electric-turret`. The checker has been
  corrected and a Tesla-ammo category assertion added. It has not been rerun.
  The old diagnostic file remains a failed diagnostic.

## Remaining work in execution order

1. Finish and run focused acceptance host tests. A new `test_acceptance.py` has
   been written but has not run. Add PowerShell coverage for preview-hook delegation,
   required Gaia child failure/missing phases, quantity parsing and incomplete or
   duplicate matrix rows. Exercise the structured owned-process bridge too.
2. Recheck all new functions for identity/freshness validation, strict failure
   propagation and exact executable/base agreement. Review optional-profile handling
   in final-data checks. The current checker targets the locked development profile.
3. Rerun the corrected final-data checker diagnostically, then qualify it through a
   fresh successful managed strict fast run with stable source inputs.
4. Run `qc-test -Suite gaia-resources -Case candidate -TestProfile default`. Diagnose
   any native API/generation/budget issues without weakening the required six-resource
   inventory, fixed area or explicit terminal completion.
5. Add and run a private controlled Gaia defect that removes a required resource.
   Verify the specific assertion fails and parent preview/full results propagate it.
6. Run focused `qc-preview -Strict`, including an explicit alternative seed/planet
   request. Preserve the required fixed Gaia row alongside requested output.
7. Run the default `qc-gaia-resources -Strict` matrix with all eight seeds and all
   six control probes. Validate exact row completeness and compact closeout.
8. Complete repository guidance and model updates. Pending areas include Gaia QC,
   native testing, lib-first, dependency touchpoints/catalogue, shared-helper and
   relevant progression/Tesla/Gaia verification sections, revisit notes and the
   current-version changelog. Global QC guidance already has its initial update.
9. Run affected skill validators, blueprint audit, routing checks and all host tests.
   Rerun the full adverse native runner conformance matrix because orchestration changed.
10. Run preflight and one complete `qc-full -Strict` against a consistent common
    source fingerprint. Require every seven-core row plus focused Gaia, final-data,
    assets, packaging and encoding checks. Finish managed closeout after consumers.
11. Publish the dated acceptance follow-up with fresh receipt links and warning
    dispositions. Preserve earlier failed aggregates and historical core receipts.

## Resume commands and cautions

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/qc/native-tests/test_encoding.ps1
pwsh -NoProfile -File scripts/qc/native-tests/test_encoding.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/qc/native-tests/test_helpers.ps1
python -B -m unittest discover -s scripts/qc/native-tests -p 'test_*.py'
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/invoke-esir-dev.ps1 -Task qc-test -Suite gaia-resources -Case candidate -TestProfile default -AsJson
```

Python tests that create temporary fixture directories required escalation in this
session. An approval prefix for the scoped unittest discovery command was granted.
Apply the same observed-permission handling to native managed requests if needed.

All recorded tool jobs have returned. A task-filtered process metadata check found
no active Factorio/native-test/QC wrapper job at pause. No goal object is active.
No files were committed or deployed. Source and guidance changes remain in the
shared dirty working tree.
