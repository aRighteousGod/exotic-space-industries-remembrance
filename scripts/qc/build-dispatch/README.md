# Build-dispatch lifetime acceptance

## Current native suite

Use `scripts/invoke-esir-dev.ps1 -Task qc-test -Suite build-dispatch` from the repo root. Shared mechanics and evidence rules live in `.codex/skills/esir-dev/references/native-testing.md`; the catalogue owns exact profiles/cases. Current `candidate`/`reload` assertions run on exact 2.1.24. Native ownership/metadata checks and injected event/failure probes retain distinct labels. Historical comparisons below remain qualification provenance.

The [2026-11-01 verification receipt](verification.md) records native results,
call counts and the separate broad-preflight limitation.

Use the exact engine and dependency lock in the development profile (currently
Factorio 2.1.24). The fixture appends probes only to a managed private main-pack
copy. Source snapshots stay immutable during each engine run. It introduces no
shipping remote interface, scheduler, or diagnostic switch.

Before editing, run `freeze.ps1` and retain its returned `record` path:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/qc/build-dispatch/freeze.ps1
powershell -ExecutionPolicy Bypass -File scripts/qc/build-dispatch/run.ps1 -Record <record> -Phase baseline
# Apply the shipping change, then:
powershell -ExecutionPolicy Bypass -File scripts/qc/build-dispatch/run.ps1 -Record <record> -Phase candidate -ServerSave
powershell -ExecutionPolicy Bypass -File scripts/qc/build-dispatch/run.ps1 -Record <candidate-record> -Phase reload -Save <candidate-evidence>/reload.zip -Reuse
```

Each phase returns its own managed run, report and write-data directory. Preserve
the candidate save explicitly before closing its run. Complete runs with their
actual verdict and close them through the shared housekeeping API once comparisons
and reload consumers finish. The initial freeze run remains open until the baseline
consumer finishes. Reports and source/instrumentation hashes are compact evidence;
staged mod views and engine caches are scratch.

The baseline lane expects the old tagged-turbine failure and records chest/pipe
receiver and shared-guard counts. Candidate probes use real native entities and the
actual registered handlers. Event-shape probes deliberately invoke handlers with
controlled metadata/ticks; they are separate from native script-raised events.
The fixture also injects explicit consumption results to check every dispatcher
termination boundary. These are adversarial routing probes, not native placement
coverage. Matrix incoming-entity loss and invalidation at scrubber normalization
return are also injected; scrubber's actual script-built reentrancy is tested
separately. Creation-failure injection is confined to named constructors in private
copies and recorded in each phase's input manifest.

Acceptance covers survivor identity, no invalid downstream handles, single owner
calls, original event metadata, cloned aliases, rejection/refunds, registries and
save/reload. Compare ordinary receiver/guard counts separately from correctness.
This suite does not establish visual, multiplayer or whole-factory UPS acceptance.

The [overlap audit](overlap.md) maps required secondary consumers, irrelevant
fan-out, pre-admission initialization and implications for a later pruning pass.
Use `-ServerSave` for the candidate lane when producing a reload save; the returned
evidence directory retains `reload.zip`. Benchmark mode suppresses saves. `-Reuse`
reruns a still-open fixture from its immutable snapshot after validating its inputs.

The old runtime-contract GUI/research fixtures target historical engines and are
not substituted for this focused current-engine lane. Run the repository preflight,
blueprint/header audits, runtime-contract advisory and wrapper `qc-runtime` too.
