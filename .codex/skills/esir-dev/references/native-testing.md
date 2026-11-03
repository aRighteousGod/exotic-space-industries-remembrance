# Native functional testing

Use `scripts/invoke-esir-dev.ps1` and `.codex/esir/test-suites.json`. The development profile pins the executable, adjacent base data and dependency lock to exact **2.1.24**. Historical receipts retain their original versions.

## Discovery and selection

```powershell
powershell -ExecutionPolicy Bypass -File scripts/invoke-esir-dev.ps1 -Task test-list
powershell -ExecutionPolicy Bypass -File scripts/invoke-esir-dev.ps1 -Task test-plan
powershell -ExecutionPolicy Bypass -File scripts/invoke-esir-dev.ps1 -Task qc-test
powershell -ExecutionPolicy Bypass -File scripts/invoke-esir-dev.ps1 -Task qc-test -Suite induction-circuit -Case configuration
powershell -ExecutionPolicy Bypass -File scripts/invoke-esir-dev.ps1 -Task qc-test -Suite mirroring -TestProfile quality-disabled
powershell -ExecutionPolicy Bypass -File scripts/invoke-esir-dev.ps1 -Task qc-test -ChangedSince HEAD
```

Listing and planning are read-only. `test-plan` without a ref examines differences against HEAD, including staged, unstaged, deleted, renamed and relevant untracked paths. Both rename paths participate. Plans report cases, profiles, selection reasons, uncovered paths and supplementary evidence requirements.

`qc-test` defaults to the seven core families. `-TestTier extended` includes all active migrated cases and extended variants, including adverse runner controls. Exact `-Suite`, `-Case` and `-TestProfile` selectors reject unknown or empty selections before staging. Cases require one explicit suite. Use explicit suites or `-ChangedSince`, not both. Comma-separated values work through PowerShell `-File`.

Fixture changes select their owner. Shared dispatcher and helper changes select core. Runner or catalogue changes select full adverse conformance plus core, even at the default tier. Normal `qc-full` requires core and focused Gaia acceptance. Unmapped gameplay selects core and retains an explicit coverage gap. Documentation-only plans may be empty. Execution requires a nonempty selection. Installed mods never expand curated matrices. The `factorio-2.1` entry also inventories nested and loose components with explicit status, existing executor references and matrix requirements.

## Core contract

`qc-full` also requires the focused Gaia preview and the non-core
`gaia-resources/candidate` case through its broad preview child. The dedicated
`qc-gaia-resources` command owns the extended eight-seed and six-control preview
matrix. See [Gaia resource QC](gaia-resource-qc.md) for these execution boundaries.

The encoding gate preserves explicitly registered historical captures using
`.codex/esir/preserved-encoding.json`. A matching normalized hash and exact finding
counts produce an informational record. Changed or missing evidence fails, and
`-FixEncoding` protects registered captures from rewriting.

| Suite | Required cases | Profiles |
| --- | --- | --- |
| `build-dispatch` | `candidate`, `reload` | `default` |
| `scheduler-event-tick` | `candidate`, `reload` | `default` |
| `research-events` | `candidate`, `reload` | `default` |
| `research-bootstrap` | `candidate`; lab/progress/inventory `reload` in `triggers-1-flatten-0` | all four `triggers-0/1-flatten-0/1` combinations |
| `induction-circuit` | `candidate`, `reload`, `configuration` | `default` |
| `alert-preferences` | `candidate`, `reload` | `default` |
| `mirroring` | `candidate`, `reload` | `quality-enabled`, `quality-disabled` |

The first bootstrap profile digit is the effective `no_triggers` value. The catalogue owns the complete profile/case requirements. `active` means runnable; only a matching fresh passing receipt establishes acceptance. `needs-port` and `historical` entries remain discoverable and cannot pass through native execution.

## Execution and verdict

Fresh candidates use `--test-scenario`; saved-state assertions use `--test-save`. A runner-generated identity and selected phase arrive through `--test-arg` / `script.test_arg`. Runtime arguments cannot configure startup/data stages; profile inputs are staged first.

Every fixture writes its terminal report before calling `script.finish_test(boolean)`. Success requires successful process exit, clean fatal-log classification, unchanged validated inputs and a fresh report matching run, suite, profile, phase, exact engine and selected cases. Reports must be complete, nonempty and entirely passing. Missing, stale, malformed, empty, incomplete or mismatched reports fail. A zero exit from `--test-ticks` alone is insufficient.

The default per-phase limits are 3,600 simulation ticks and 600 wall-clock seconds. Lua deadlines and independent host timeouts both apply. Only owned children may be terminated. Functional tests run sequentially in private managed staging; stdout/stderr, fingerprints, reports and reproduction commands are retained by compact closeout.

Reload checkpoints retain the existing server or graphical producer. Player-dependent checkpoint producers are explicit in receipts. Require fresh successful assertions, save-completion logs, ZIP integrity and a checkpoint hash. Ordinary reload selects its phase through test arguments without changing helper bytes and asserts no configuration repair occurred. Deliberate configuration cases are separate.

An adapter may return `rendered_output` naming its folder below the private write-data `script-output` directory. After a graphical checkpoint, the runner copies that folder to the managed evidence `rendered` directory before scratch cleanup. Review the retained images separately from programmatic GUI assertions; screenshots do not establish physical input or multiplayer behavior. The fatal-log classifier includes native `Exception at tick` messages so an error dialog cannot hold an owned graphical child until the full timeout.

The full bootstrap lab row compares the independent candidate state with both the checkpoint and reload state, including exact progress and inventory. Explicit `-Case reload` selection verifies its checkpoint and saved state without that separate candidate comparison. Checkpoint producer receipts distinguish deliberate termination after a verified save from the actual native test process exit.

Required helpers stage automatically through the shared resolver. Never copy into shared `fmqc/mods-live`, patch source junctions, or mutate package-store hardlinks. `qc-full` aggregates native core children after its existing final-data consumers finish; every required incomplete/failed child fails the aggregate. Deliberate hangs belong in runner qualification, not normal `qc-full`.

A common source fingerprint spans the whole selection and the broad/native parts of `qc-full`: gameplay Lua, JSON, locale CFG, explicit sibling source overrides and baseline dependency/settings selection must remain identical between rows. Each managed row also retains its full staged-input validation. A source edit between otherwise passing rows invalidates the aggregate. Compacted qualification reports are read from their hash-verified evidence archive, never from loose leftovers.

## Evidence and models

The [2026-11-03 follow-up acceptance](../../../esir/handoffs/factorio-final-qc-gap-repairs-acceptance-2026-11-03.md)
records a complete strict full result of **ok**, the current core/Gaia matrix,
fresh conformance and warning disposition. The
[2026-11-02 acceptance record](../../../esir/handoffs/factorio-native-testing-acceptance-2026-11-02.md)
preserves the original native qualification and earlier broad-QC findings.
New acceptance still requires matching fresh input fingerprints and reports.

Keep native events, injected dispatcher probes, controlled clock checks, final-data assertions, ordinary persistence, historical migration, rendered checks, multiplayer and performance distinct. Native GUI elements/programmatic edits do not establish mouse interaction or rendered layout. Functional results do not establish UPS improvement. Presentation scenes, combat families, cryo and the 64-row Quality matrix retain their explicit migration status and dedicated workflows.

Model verification sections may include `test-suite: <id>` and `test-case: <suite>/<case>`. Link validation rejects unknown IDs; it does not prove scenario coverage. Preserve existing historical assertion counts as provenance instead of making obsolete exports or counts the current contract.

Runner changes require host conformance tests and the full base-only adverse matrix:

```powershell
python -B scripts/qc/native-tests/test_runner.py
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/qc/native-tests/test_helpers.ps1
powershell -ExecutionPolicy Bypass -File scripts/invoke-esir-dev.ps1 -Task qc-test -Suite runner-conformance -TestTier extended
python -B scripts/qc/native-tests/qualify_suites.py
```

The last command injects one named defect per core family into separate private copies before freezing inputs. Every child must return `failed` for the expected assertion; staging failures, changed inputs and unrelated failures cannot qualify a detector. These failed child receipts are qualification evidence, not failed acceptance of shipping sources. Use `--suite <id>` to qualify a focused detector. Keep all runner and fixture files stable during execution: receipts include their hashes as well as staged gameplay/settings inputs.

## Official sources

- [Exact 2.1.24 LuaBootstrap](https://lua-api.factorio.com/2.1.24/classes/LuaBootstrap.html)
- [Command-line parameters](https://wiki.factorio.com/Command_line_parameters)

Verify both exact-version documentation and executable `--help` before changing capabilities.
