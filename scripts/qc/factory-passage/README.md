# Factory passage acceptance

Observer narrowing uses `observers.lua` for offline admission/session/migration
checks and `observer-run.py --context <managed-context>` for native circuit and
machine-joint movement. Add `--visual` for a connected graphical player. The
separate `--benchmark --baseline <frozen-owner.lua>` matrix measures 1,000/10,000
crafters, 0/10% native circuit selection, main budgets 256/1024, additional circuit
budgets 1/1024 and five processes per revision: 160 trials. Both revisions run identical fixture sources and settings;
only the owner bytes differ. Prepare with the existing managed `-BaseOnly` runner.
The common checkpoint is tick 4,096. The circuit population starts explicitly
recipe-less in both revisions: unwired native circuit selection can retain an
existing recipe. Before latency probes, helpers must match that expected initial
population. Empty dirty queues alone are insufficient at one scan/tick.
The fixture records signal-to-recipe, recipe-to-joint, explicit-refresh latency,
native whole-tick cost and a separate accumulated passage profiler. Reject any
measurement overlapping another Factorio process. `circuit-scanner.lua` exercises
the indexed heap, both budget matrices, exact cooldown, parking and migration.
`locales.py` checks all eight key/parameter sets; `guide.py` opens the real native
Informatron page in each locale, translates labels and captures scroll positions.
`guide-acceptance.py` checks all eight locales and two inactive cases against the
delivered owner/configuration/page hashes and the retained frame hashes.
`render-observers.py` assembles hash-verified movement frames into a compact demo.
It records exact source/checkpoint hashes, observer attempts, whole-process memory
and paired steady-state regression limits. Preserve the frozen uncommitted baseline.
After the matrix, `legacy.py --context <managed-context>` loads the frozen owner's
actual populated checkpoint under the delivered owner. It checks budgeted revision
3 adoption without resetting queues, reports or helper identities.
`observer-report.py` summarizes an accepted 160-trial matrix, keeping native tick
cost, passage profiling, process memory, attempts and latency in separate fields.

An actual recipe-picker interaction still needs native UI input; programmatically
assigning `player.opened` and dispatching a handler is not that evidence. Two Lua
players are not proof of two connected clients. Silent external recipe/circuit
changes require `ei_factory_passage.refresh_entity`; no fallback sweep exists.

This fixture uses the exact engine and dependency selection from the ESIR development
profile. The production modules are copied into a private managed view; the installed
mod directory and live sources are not fixture output. Factorio 2.1.24 is required.

```powershell
# Full current development profile. Retain the printed CONTEXT path.
./scripts/invoke-factory-passage-qc.ps1 -Phase Prepare
./scripts/qc/factory-passage/matrix.ps1 -ContextPath <context.json> -Group modes -Render
./scripts/qc/factory-passage/matrix.ps1 -ContextPath <context.json> -Group transitions -Render
./scripts/qc/factory-passage/matrix.ps1 -ContextPath <context.json> -Group switches -Render
./scripts/qc/factory-passage/matrix.ps1 -ContextPath <context.json> -Group actors

# Isolated native cost comparison with the exact candidate modules.
./scripts/invoke-factory-passage-qc.ps1 -Phase Prepare -BaseOnly
./scripts/qc/factory-passage/performance.ps1 -ContextPath <performance-context.json>

# Repeat the same forty matched trials at the selectable upper limit.
./scripts/invoke-factory-passage-qc.ps1 -Phase Prepare -BaseOnly -Budget 1024
./scripts/qc/factory-passage/performance.ps1 -ContextPath <budget1024-context.json> -Budget 1024

# Actual ESIR administration owner, native GUI, repair and occupied-joint waits.
./scripts/invoke-factory-passage-qc.ps1 -Phase Prepare -Administration -Render
./scripts/invoke-factory-passage-qc.ps1 -Phase Create -ContextPath <admin-context.json> -Label administration
./scripts/invoke-factory-passage-qc.ps1 -Phase Visual -ContextPath <admin-context.json> -Label administration -ExpectedReceipt administration
# The graphical runner retains administration-checkpoint.json with the verified save path/hash.
./scripts/invoke-factory-passage-qc.ps1 -Phase Run -ContextPath <admin-context.json> -Label administration-reload -Save <checkpoint.zip> -Ticks 12 -ExpectedReceipt administration-reload

# Offline failure injection and boundary budgets, separate from native evidence.
./.tools/lua-5.4.8/lua54.exe scripts/qc/factory-passage/fairness.lua
./.tools/lua-5.4.8/lua54.exe scripts/qc/factory-passage/map-setting.lua
./.tools/lua-5.4.8/lua54.exe scripts/qc/factory-passage/lifecycle.lua

# Actual installed Squeak Through 2 package, copied and hash-checked for staging.
./scripts/invoke-factory-passage-qc.ps1 -Phase Prepare -BaseOnly -Companion
./scripts/invoke-factory-passage-qc.ps1 -Phase Create -ContextPath <companion-context.json> -Label companion
./scripts/invoke-factory-passage-qc.ps1 -Phase Run -ContextPath <companion-context.json> -Label companion -ExpectedReceipt companion
```

`modes` saves settled populated checkpoints. `transitions` tests all six directed
changes, then reloads ESIR without a configuration change. Its `-Render` selection
must match the original `modes` invocation: changing fixture code itself triggers
configuration change and is not an ordinary reload. Master/category cases and actor
cases are separate. `actors` uses a hidden native graphical client for real player,
robot and platform actions, including grounded and flying mech-armor characters.

The movement renderer consumes hash-verified native screenshot inventories. It
assembles frames without synthesizing character motion. Full graphical loads use
the same managed view through its Windows short path to avoid legacy MAX_PATH
asset-read failures. The fixture skips the freeplay intro so a modal cannot suspend
native movement. A native error or missing fresh semantic receipt fails the run.

The separate pipe-network benchmark uses seed 137013 and identical 1,000-column
connected grids. Five
independent processes per case alternate Vanilla/ESIR order. Each idle measurement
runs 6,000 updates from a settled checkpoint at tick 512; construction/removal bursts
remove and restore the same 1,000-pipe interior row and are measured separately.
Queue-drain latency is recorded before waiting for the common checkpoint tick.
The readiness probe starts at tick 11, so a reported 11 means ready by that first
observation, not an exact eleven-tick drain. Larger observed values are the tick
where the dirty and pending queues first become empty.
The native `Performed ... updates in ... ms` result supplies tick cost.
Every paired idle delta must be within the larger of 5% or 0.1 ms/tick. Expected helper
counts are asserted explicitly. Process memory and queue-drain ticks are separate
measurements; private memory is sampled every 200 ms, and process elapsed time
includes loading. Checkpoint hashes and exact candidate-module hashes are verified
for every trial. Observed overlapping Factorio
processes invalidate timing, and the runner waits and retries without stopping them.

Keep live source inputs unchanged while a managed run is open. `Configure` changes
only its private fixture. `Sync` deliberately replaces private source with current
repository source; never use it to promote private fixes. Preserve reviewed private
fixes before closing the run, because closeout retires the private view.

`Finish` requires an explicit passing acceptance JSON with every required receipt
label. Select final movement media with `Set-EsirQcSelectedEvidence` before closeout.
Compact evidence retains source hashes, settings, receipts and relevant logs. Full
two-client multiplayer synchronization is a separate test; a hosted fixture save
does not establish that coverage.

`acceptance.py --context <context.json>` checks all 17 full-profile native case
groups against the exact four production-module hashes before closeout. The
separate `performance.py` checks all 40 cost trials, checkpoint identity, exact
helper counts, idle invariants and the measured threshold. JSON receipts are stored
inside `evidence.zip` after compaction; selected final PNG/WebP media stays beside it.

`administration-acceptance.py --context <admin-context.json>` validates the final
`administration-final-render` / `administration-final-reload` pair (or explicit
`--label` / `--reload-label`), checks their exact production and private-fixture
hashes, validates the checkpoint handoff and three native GUI captures, and reruns
the offline fairness, transaction and report-lifecycle fixtures. It reports repeated
assertions as records, not independent scenarios. Rollback fault injection and
surface report transitions use mocked native boundaries; native movement and
separate-process persistence are reported separately.

`mode-acceptance.py --context <context.json>` validates the sixteen current
full-profile mode, transition, reload and switch groups without requiring a new
actor render batch. `--isolated` accepts the three `isolated-<mode>` Base cases;
add `--with-reload` to require `isolated-reload` from the ESIR settled checkpoint.
`--companion` accepts the actual companion override case. Each checks current
production hashes, effective mode/reason, budget, empty rebuild queues and inactive
ownership. Turret-port movement scenes use separate turret copies for their two
walkers, with both native ports connected in each copy, so character collisions
cannot divert the tested approach. These isolated Base scenes supplement the full
development profile and are not a substitute for its ESIR machine coverage.
