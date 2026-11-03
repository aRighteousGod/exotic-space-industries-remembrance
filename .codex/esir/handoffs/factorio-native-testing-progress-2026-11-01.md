# Factorio 2.1.24 native testing implementation checkpoint

Recorded: 2026-11-01 20:28 UTC (14:28 America/Chicago).

**Status: implementation and core qualification completed on 2026-11-02.**

The [final acceptance record](factorio-native-testing-acceptance-2026-11-02.md)
supersedes the pending-work statements in this chronological checkpoint. All seven
core families passed eleven rows and twenty phases in final aggregate
`4a1f2e541b424d48ae64a155fd68912a`. It retains overall `failed` for the historical
encoding finding, with native status `ok`. Broad evidence is closed and compacted.
Final adverse conformance `bd6894f2f42c4701842a58a1300d126e` passed all seven cases.

The original checkpoint below records the first requested pause. The user then
resumed with "continue with plan", and has now requested "save progress on plan
and pause for now". The subsequent "Continue with plan" on 2026-11-02 resumed
implementation and qualification.

## 2026-11-02 continuation

- The completed concurrent runtime-options work adds an active extended suite to the existing catalogue. Discovery and model-link checks pass on the current checkout. Core remains seven families and eleven profile rows.
- Current preflight passes eleven checks. Its sole failure is the existing historical encoding finding recorded below.
- This session uses PowerShell 7. Python-launched Windows PowerShell inherited its module paths and could not resolve `Get-FileHash`. Seven attempted qualification rows failed during staging and closed with retained failed evidence. The runner now clears that inherited variable only in the child environment, allowing Windows PowerShell to rebuild its native module paths.
- All 22 host tests pass, including a real child-shell hash-command probe. The twelve shared-helper/aggregation checks and all seventeen skill validators pass.
- All seven prescribed suite defects were detected on gameplay fingerprint `76cabbfba0da8313ec6938b9fbf7dd3d05fc5d3fc4ddce5d6c42542966335716`. The bootstrap detector was corrected to recognize its exact native ingredient assertion, which runs before the host semantic check. A focused native rerun verified the corrected detector. Legacy helper routing now retains the explicit needs-port gap alongside core selection.
- Final adverse runner conformance `12d444465ce846c89950eceb3459ebd6` passed all seven cases with compact closeout after these changes.
- Complete `qc-full` run `964bcab6f3584ae082a14ab6cac25062` finished and correctly returned failed. Ten core rows passed. Research candidate passed, but its reload fixture incorrectly required an empty physical bucket table after controlled immediate-flush probes. The production model explicitly permits cancelled entries when live pending forces and next-due tick are zero. The corrected fixture records those counts at acceptance and compares them on ordinary reload, while requiring no live backlog and no configuration repair. Focused native requalification is running before a final complete `qc-full` rerun.
- That first full run's broad asset/package checks passed. Broad data/runtime/preview completed with warnings, including the supplementary global Gaia companion's incompatible 2.0 metadata. The concrete Gaia gap is recorded in REVISIT_NOTES. Run `964bcab6f3584ae082a14ab6cac25062` was closed and compacted after its final-data consumers finished. Its failed aggregate remains `.factorio-qc/fmqc/qc-full-964bcab6f3584ae082a14ab6cac25062.json`.
- Corrected research persistence passed focused candidate/reload verification in `2e2427c3141648fa92b71a023f9d4e76`, with 176 and 53 terminal report checks. Final aggregate `4a1f2e541b424d48ae64a155fd68912a` then passed all eleven native rows and twenty phases on the same gameplay fingerprint. Its 16,767 terminal report checks and 228 host postchecks passed. The broad run and all native children are closed and compacted. The acceptance record above contains the final receipts and broad-QC findings.

| Qualified defect family | Evidence run |
| --- | --- |
| Build dispatch | `4357dc31bb684a9e88790d0e82dae0a8` |
| Scheduler and event ticks | `14f46682485c4abebed09f9bfa12e3d2` |
| Research events | `87a75f8a98244ef9aaf98d86ee6a7c10` |
| Research bootstrap, corrected detector rerun | `12606e71f7e34f29bdb350e6e4991461` |
| Induction circuits | `934a413ef2f848f0b9f6b91fe9caca4b` |
| Alert preferences | `8672233bbeea463a9020001c3a3878c9` |
| Mirroring | `865893acfde54476b9066b3709a29ff3` |

## Resume update

- The other task repaired the RP steam-pump geometry blocker. Its current-hash full-profile factory-passage acceptance is documented in `factory-passage-acceptance-2026-11-01.md`; no pump repair was needed here.
- Alerts now pass candidate (190 assertions) and ordinary reload (47), with successful compact closeout: `36a6c5ee58a34c10a8d72b061b387ce1`.
- Induction candidate `3349f7f25e96484489d6777800e967a2` exposed a real gameplay interaction: old tile-corner probes miss one-tile coils/solenoids after passage trims collision boxes. The production lookup now scans the whole logical tile; the existing legal coil placement and 25 MJ assertion remain unchanged. Blueprint/changelog updated, version unchanged. Requalification `ec185037f56e4b0391bf0b738e2d6529` passed candidate (137), reload (48), and configuration repair (48), with compact closeout.
- Fixed qualification detectors to read hash-verified compact evidence ZIPs. Refreshed factory-passage catalogue workflows/ownership and preserved explicit owner gaps during shared-file routing.
- Added a selection-wide code/locale/configuration fingerprint including all three explicit sibling source overrides; `qc-full` requires broad/native fingerprint agreement. Existing full managed staging checks remain. Malformed broad receipts now follow failed closeout instead of escaping it.
- Current focused host checks: 21 Python tests and 12 PowerShell checks passed, including malformed compact reports and source disappearance after completed rows. Blueprint audit, touched Lua syntax and scoped whitespace checks passed. Preflight again passed 11 checks with only the unchanged historical encoding failure below.
- Final adverse conformance `3a2c07383274404ca9dc43d4d22a5eba` passed all seven cases after all runner hardening, with compact closeout. The earlier `af88f4dd89e24495929d91374d657071` also passed before the last failure-path hardenings.
- Initial private defect qualification proved build (`d6ea737f17fd4df78e46ee1aaa877949`, 23 intended tick failures) and scheduler (`ab3770a3cd3148e3bb549f70187a903b`, controlled tick-zero failure). At 17:25 America/Chicago, concurrent edits changed control/startup/map-settings/factory-passage configuration during research (`d96bcaa5fbd64159b59b9c5d751ee101`). The new selection guard stopped and reported all five paths; the research receipt remains protected and does not qualify. The entire seven-defect selection was restarted after the files became quiet. No concurrent changes were reverted.
- The restarted selection completed its build-defect child `5d4fecb675d7470d8b257451806ce1c4` before this second pause. The selection coordinator was then stopped by verified PID/command-line ownership so it cannot launch additional cases. A scheduler staging child had already started (`ed4fc8519f7a433989e0befae68721f4`); closeout is recorded below. This is an interrupted qualification selection, not a completed seven-family qualification.
- Pause closeout completed: `ed4fc8519f7a433989e0befae68721f4` has zero executed phases, `interrupted=true`, reason `User requested pause before native execution`, and `status=failed` / `cleanup_status=compacted`. Its final receipt is retained. The restarted build defect was independently read from its authenticated archive and returned `defect_detected=true`. No task-owned test or staging process remains running.

### State at the second pause

- Implemented runner, catalogue, staging adapters, seven core adapters, guidance/skill integrations and `qc-full` aggregation are present in the worktree.
- The real induction collision-box regression is repaired and passed all candidate/reload/configuration phases on 2.1.24. The existing native assertion was retained; no fixture-only capacity workaround was introduced.
- Latest tooling qualification: 21 Python host tests, 12 PowerShell helper/aggregate checks, 17 validated skills, clean catalogue/model/link audits, 11 passing preflight checks with only the existing historical encoding failure, and complete adverse native conformance `3a2c07383274404ca9dc43d4d22a5eba`.
- **Still incomplete:** all seven native suite-defect qualifications on a stable final source selection; a fresh complete 11-row/20-phase core selection; final end-to-end `qc-full` and broad-run closeout.
- Gameplay changed concurrently after the successful induction run. Recheck current source identity before final qualification; do not combine old and new passing rows into current acceptance. The shared snapshot now catches edits between rows as well as during them.
- The invalidated research run `d96bcaa5fbd64159b59b9c5d751ee101` is confirmed `task_open=false`, `status=failed`, `cleanup_status=protected-error`. Its protected payload was not deleted.
- No commits, pushes, deployment or version bump were performed. Concurrent gameplay/asset/dependency work remains untouched except the explicitly documented small induction discovery repair and its model/changelog additions.

The remaining acceptance sequence below still applies. Earlier partial receipts
remain provenance and do not replace final current-source core qualification.

## Contract and workspace boundaries

- Implement the approved repository-owned suite system, all individual skill integrations and concrete repairs, seven core families, runner/suite qualification, and final `qc-full` acceptance.
- Exact executable, base data and dependency profile remain **2.1.24**. Profile: `.codex/esir/factorio-development.json`; executable: `.factorio-qc/engine-2.1.24/bin/x64/factorio.exe`; seed: `.factorio-qc/dependency-seeds/2.1-core`; dependency lock SHA-256: `8f509c61cfebdcca625577ad4ed14f2b491e1c4cf1a63260d8ca78f09130161a`.
- No hosted CI, deployment, commit, push, or main-mod version bump was performed by this task.
- Preserve concurrent work and historical receipts. The worktree contains substantial unrelated Minigun extraction, Continued mod, build-dispatch, factory-passage, source, metadata, locale, asset and blueprint changes. A dirty path is not proof that this task owns all its changes. Do not use broad staging/reverts or cleanup.
- Native functional runs are sequential and use managed private staging. Rendered, performance, multiplayer and historical evidence remain separate.
- No task-owned Factorio/native-runner process was active at pause (checked via process command lines). All three read-only sidecars had completed. Unrelated Blender MCP processes were left untouched.

## Implementation delivered in the worktree

### Catalogue, selection and validation

- New `.codex/esir/test-suites.json`: last audited inventory **67 top-level suites and 36 nested components**. Eight active entries comprise seven core families plus runner conformance. Remaining entries have explicit `needs-port` or `historical` status, evidence boundaries and workflow references; duplicate entrypoints are consolidated.
- Explicit curated profiles, matrix rows, source/fixture ownership, helpers, launch/save references, expected reports, finite budgets and checkpoint executors. Required core currently comprises **11 profile rows and 20 phases**. Research bootstrap requires all four setting combinations; mirroring requires Quality enabled and disabled.
- New `scripts/qc/native-tests/catalogue.py`: strict catalogue validation, required matrix/phase completeness, exact selectors, one-suite case selection, dirty-worktree routing, both rename paths, deletions, relevant untracked files, documentation-only empty plans, and empty-execution rejection.
- Infrastructure changes select conformance plus core; shared runtime/dispatcher changes select mapped core; unmapped gameplay selects core with explicit coverage gaps. Supplementary render/multiplayer/benchmark requirements are reported separately.
- Wrapper `scripts/invoke-esir-dev.ps1` exposes `test-list`, `test-plan`, `qc-test`, `-Suite`, `-Case`, `-TestProfile`, `-TestTier`, and `-ChangedSince` with early validation.
- Fresh report validation requires exact run/suite/profile/phase/engine/input identity, exact selected cases, explicit completion, nonempty assertions, all required checks passed and successful process exit. Missing, malformed, stale, mismatched, empty or incomplete reports fail. Tick-limit exit zero alone fails.

### Supervised execution and managed staging

- New `runner.py`, `managed.ps1`, helper Lua/scenario, `adapters.py` and `runtime_adapters.py` under `scripts/qc/native-tests/`.
- Fresh candidate fixtures use `--test-scenario`; saved-state phases use `--test-save`; identity and phase selection use `--test-arg`. Terminal reports precede explicit `script.finish_test`.
- Lua deadlines plus independent host timeouts; owned child processes only; captured stdout/stderr; fatal log classification; explicit command/result provenance.
- Exact executable/base/profile agreement is checked before generic staging fallback and again against actual engine logs. Managed configuration explicitly selects adjacent engine data, rather than inheriting another installation's read-data path.
- Automatic required-helper resolution/staging is shared by applicable `qc-runtime`, `qc-preview`, `qc-full` and native paths. Missing/incompatible helpers fail before execution. Explicit save paths retain catalogue identity. Generic non-ESIR QC behavior remains delegated.
- Private helper ordering derives only from the explicit enabled mod list. Installed mods never silently expand a test matrix.
- Runner/harness inputs are fingerprinted at process import and checked before/after staging and phases. Private mod content, helper content, settings, mod list and effective path contract are validated. Concurrent source drift invalidates receipts rather than being ignored.
- Windows graphical asset loading exceeded MAX_PATH through long staging junction paths. Engine-facing config/mod-directory arguments now use verified short-path aliases; canonical ownership and fingerprint paths remain unchanged.
- Managed errors retain failed evidence. Closeout closes task ownership even when payload protection prevents compaction. No protected payloads were forcibly deleted.

### Checkpoint/reload and concrete adapter repairs

- Retain established server or graphical checkpoint producers. Native save-completion ordering was investigated but was not proven sufficient to replace them.
- Checkpoint acceptance requires a fresh matching report, save-completion log, ZIP integrity, hash and unchanged inputs. The actual owned termination exit is retained separately from verified checkpoint success.
- Ordinary reload changes phase through arguments/saved state without changing helper content. It requires no configuration-change callback. Deliberate configuration repair is a separate phase.
- Fresh graphical player seeds initially paused on ESIR's custom freeplay intro. The private common helper now preserves the original fixture initialization callback and sets freeplay `skip_intro` after it. Research, bootstrap and mirroring init/load/configuration handlers were reviewed for preservation. Shipping gameplay code was not changed for this fix.
- `scripts/qc/factorio-2.1/save_checkpoint.py`, `native_client.py`, new `managed_paths.py` and `validate-context.ps1` use configured engine/managed paths and retain report/save/hash/timeout/ownership checks.
- Quality matrix adapters consume managed `context.json`, fix worker precreation/reuse, freeze private fixture sources and validate reuse fingerprints. The **64-row historical matrix remains outside current native acceptance** and was not requalified.
- Scripted-research helper metadata/API moved to the current private 2.1 convention. Missing diagnostic snapshots are required assertion failures. Manual `fmqc/mods-live` staging guidance was removed after shared staging verification.

### Seven core adapters implemented; full qualification still outstanding

| Suite ID | Implemented coverage and qualification boundary |
| --- | --- |
| `build-dispatch` | Current candidate assertions, ownership/consumption, invalidation, metadata preservation, supplied ticks and ordinary reload. Native events and injected probes remain distinguishable. Existing historical counts are provenance, not a new contract. |
| `scheduler-event-tick` | Current exports, tick zero, supplied ticks, queue/delay, cleanup and persistence; controlled clock checks remain labeled. |
| `research-events` | Ordinary completion, scripted flood coalescing, current fanout, required diagnostic state, force isolation, pending-flush ordering, delayed/derived state and persistence. |
| `research-bootstrap` | Four no-triggers/flatten profiles, effective settings, shared-template invariants; ordinary laboratory completion and independent saved progress/inventory/queue comparison in the applicable profile. |
| `induction-circuit` | Native GUI elements/tags/programmatic events, defaults/filters/immediate updates, stale sessions/replacement, ordinary reload and deliberate configuration repair. Graphical checkpoint must still be requalified with the latest private intro fix. |
| `alert-preferences` | Personal Off authority, state isolation, defaults/toggles/master, native delivery cleanup, invalid sources and persistence. Synthetic player-state isolation is labeled; multiplayer and rendered evidence remain separate. Graphical checkpoint must still be requalified with the latest private intro fix. |
| `mirroring` | Current final-data/native invariants, transport/heat/furnace/blueprint/fluid/save assertions under both Quality profiles, separate from historical 19-field differential comparison. |

### Qualification tooling and `qc-full`

- `test_runner.py`: host tests for selectors, dirty routing, matrices, report failures, input tampering, exact engine rejection, missing helpers, owned timeout/fatal handling, short paths, managed Quality adapter behavior, and uncontaminated negative-control detection.
- `test_helpers.ps1`: shared helper resolver/stager and parent aggregate validation, including missing profile/phase and failed child propagation.
- `qualify_suites.py`: seven explicit private defect injections and strict detectors implemented. **Complete native suite-negative qualification remains unfinished.** Partial results from the resumed work are recorded above. It must not accept an unrelated load/fatal/input/cleanup failure as proof of defect detection.
- `scripts/esir-dev-lib.ps1`: `qc-full` aggregates native core after existing broad QC consumers finish; validates all required rows/phases; propagates child failures and broad housekeeping failures. Unique and latest machine-readable aggregate output is written. **End-to-end final `qc-full` has not yet been run.**

### Skills, guidance and models

- Shared mechanics live in `.codex/skills/esir-dev/references/native-testing.md`.
- Updated specialist integrations for dev, GUI, research, Lua docs/assumptions/types, dependency intelligence, presentation, recipe icons, library/core/vanilla helpers, conceptual blueprints/template, asset pipeline and Factorio export.
- Updated runtime standards, scheduler and alerts references, migrated fixture READMEs, applicable blueprint verification sections, managed helper instructions and concrete REVISIT gaps.
- Global `C:/Users/Theorun/.codex/skills/factorio-mod-qc/SKILL.md` and `references/factorio-cli.md` now document the six native symbols, explicit completion/capability checks, current profile-derived version selection and ESIR delegation. Global `esir-dev` remains a thin delegate.
- Corrected stale global 2.0.76 workstation/benchmark-only advice and recipe-icon 2.0.77 copyable example. Historical receipts/counts remain historical.

## Verification completed

### Runner qualification at the first pause

Receipt: `.factorio-qc/managed/465bd286e626400fa0cf16dca1ee646f/final-result.json`.

- Engine **2.1.24**, suite `runner-conformance`, profile `base-only`, overall **ok**.
- All seven phases passed: candidate (9 assertions), reload (11 assertions), explicit failure, Lua error, missing terminal report, tick-limit exit zero, host timeout.
- Negative phases passed by observing their prescribed rejection, not by treating the injected defect as successful functionality.
- Graphical checkpoint verified; actual owned termination recorded. Housekeeping status `success`, cleanup `compacted`.
- This was the last conformance run after the private initialization/intro fix. Earlier passing receipts include `d0b321a7c49e4f6ba5816077cb3d3ee2` and `62a609c4ed2a427bab8e8754ffc2edba`; prefer the latest receipt above.
- Base qualification proved player presence/connected state, relevant lifecycle behavior and native GUI elements. It is not full-profile rendered acceptance.

### Host, static and guidance verification

- **19 Python host tests passed** after the initialization fix.
- **12 PowerShell helper/aggregate checks passed**.
- Independent read-only validation: **17/17 skills valid** (15 repo-local plus two global), catalogue/component/model/workflow audits clean, nine realistic forward-routing scenarios passed; 10 Python files compiled in memory and eight PowerShell files parsed without errors at that review checkpoint.
- Scoped `git diff --check` passed (line-ending warnings only).
- Latest useful preflight: **11 checks ok, one failed**. Only failure: pre-existing historical `scripts/qc/singularity-lance/angular-results.json`, `mojibake-suspected [utf8]`. Preserve this historical receipt and report the boundary; do not silently rewrite it to make preflight green.
- New concurrent factory-passage fixture/runner files appeared after the earlier complete catalogue audit. Re-run discovery on resume and give those new files explicit catalogue status if still present; the 67/36 inventory is an audited checkpoint, not a permanent claim of completeness.

### Partial core evidence, not final acceptance

| Receipt ID | Observed result |
| --- | --- |
| `ea21ed3dd1ce4295a21ec0dd9787f7a0` | Mirroring Quality-disabled passed on an earlier harness revision; rerun final current harness. |
| `1588f495e2924750a3656b984fe8d83c` | Research bootstrap false/false passed. |
| `19c98bed3b2c458d9f8dd835f9e56f8a` | Research bootstrap false/true passed. |
| `8ea0bfc9236044caa40031f9c814fcc7` | Research bootstrap true/false candidate and reload passed. |
| `6f586a28fa58493a96d902ffacc2b59d` | Research bootstrap true/true raw assertions completed, but concurrent locale edits invalidated inputs. Not accepted. |
| `3a2bce476144412db47d55e2969759c5` | Scheduler candidate/reload passed. |
| `bcc95b56d3064560bf1e4aa8cdf92686` | Research events invalidated by concurrent source edits. Not accepted. |
| `3aa25414e302477db82d7ddb55ad6969` | Alerts candidate passed 190 assertions; graphical checkpoint paused at intro, then owned process was stopped. Concurrent changes also invalidated inputs. Overall failed, evidence preserved. |
| `a23d0baca2f045dfbf7ee091034b5864` | Alerts seed creation failed on current factory-passage/RP pump data error; compacted/closed. |
| `888f71e29c9849d3a0df763d5a41834b` | Induction seed creation failed on the same data error; compacted/closed. |

Earlier induction candidate passed 137 assertions, but the graphical checkpoint encountered the subsequently fixed Windows path problem. Build and Quality-enabled rows also encountered concurrent-input drift. These are useful diagnosis/provenance, not a complete current acceptance run.

Managed receipts are under `.factorio-qc/managed/<run-id>/`; compact runs retain `evidence.zip` containing `reports/...` and `scratch/...`. Read ZIP entries directly rather than assuming retained loose logs. Failed/protected runs remain protected; task ownership was closed through normal housekeeping.

## Original blocker (repaired by the other task during the pause)

The concurrent factory-passage task activated its data-final collision pass around 20:14 UTC. Standard-profile seed creation then failed:

```text
Error while loading entity prototype "rp-steam-pump" (pump):
PipeConnectionDefinition: position must be inside of entity bounding box.
position={0.250, 0.500}, leftTop={-0.199, -0.699}, rightBottom={0.199, 0.699}
Modifications: RP Steam Roboports -> ESIR
```

Read-only comparison of successful earlier alert seed `3aa...` and failed seed `a23...` found identical private helper metadata, mod load order, selected dependency profile and RP package SHA-256 (`4c8ac6273007c16023131f88792ce9aa5416fb6de893893d0da5f925def77ce2`). The four factory-passage modules were already present but dormant in the earlier seed; new top-level settings/data/data-final registrations activated them.

The pump's authored box is approximately +/-0.29 by +/-0.9. Its energy-source fluid box has connections at x=+/-0.25, y=+/-0.5. `lib/factory-passage-config.lua` proposes a trimmed box +/-0.2 by +/-0.7, which excludes those ports. `scripts/data-final-updates/factory-passage.lua` inspects the energy-source box but permits an extra tile in the east/west geometry check, admitting invalid native bounds.

Proposed bounded repair, **not implemented by this task**: preserve the original collision box whenever the proposed trim excludes an authored fluid connection that must remain inside it, including energy-source fluid connections, in both `esir` and `squeak-through` modes. Preserve authored port positions; record why trimming was excluded. Check native quantization and connection rules before coding. The user paused instead of resolving which task owns this gameplay repair. Re-check current source on resume because the other task may have repaired it meanwhile.

## Original resumption sequence

1. Re-read this checkpoint and the current user instruction. Inspect current dirty worktree/profile/catalogue and concurrent changes; do not overwrite another task's work. The original RP pump blocker was repaired; verify current source identity and any newer changes before qualification.
2. Refresh catalogue discovery/link validation for newly introduced fixtures/runners. Keep all families' eligibility and evidence requirements explicit. Do not silently promote unported coverage.
3. Retain the passing alert and induction standalone evidence above as provenance. The final core selection must revalidate them with the final common source fingerprint after concurrent changes. No helper-content changes between ordinary reload phases.
4. Run all seven private suite-negative qualifications with `qualify_suites.py`; require each prescribed defect to produce the expected clean failure and preserve its evidence. Repair actual fixture/runner defects without weakening unrelated-failure detection.
5. Run every core profile row on stable inputs (all four bootstrap settings, both mirroring Quality profiles, all required reload/configuration phases). No partially executed suite or missing matrix row can pass.
6. If runner behavior changes, rerun full adverse conformance. Deliberate hangs remain outside normal `qc-full`.
7. Run relevant focused host/static/skill checks after new edits, then a complete `qc-full`. Preserve final-data dump consumer lifetime and propagate every required core failure. Report the known historical encoding failure independently if it persists.
8. Close task-owned managed runs after consumers finish. Preserve protected, historical and concurrent artifacts. Produce final acceptance reporting with native assertions, static checks, rendered, benchmark, multiplayer and historical evidence clearly separated.

Useful commands after an explicit resume:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/invoke-esir-dev.ps1 -Task test-list
powershell -ExecutionPolicy Bypass -File scripts/invoke-esir-dev.ps1 -Task test-plan
python -B scripts/qc/native-tests/test_runner.py
powershell -ExecutionPolicy Bypass -File scripts/qc/native-tests/test_helpers.ps1
powershell -ExecutionPolicy Bypass -File scripts/invoke-esir-dev.ps1 -Task qc-test -Suite runner-conformance -TestTier extended
python -B scripts/qc/native-tests/qualify_suites.py
powershell -ExecutionPolicy Bypass -File scripts/invoke-esir-dev.ps1 -Task qc-test -TestTier core
powershell -ExecutionPolicy Bypass -File scripts/invoke-esir-dev.ps1 -Task qc-full
```

The required core pass, seven-defect qualification, complete `qc-full` execution,
catalogue reconciliation and final closeout are complete. The acceptance record
separates native results from the retained broad-QC findings and the dedicated
rendered, performance, multiplayer and historical workflows.
