# Standardized tick dispatch verification

Fresh worktree validation on October 7, 2026, using Factorio 2.0.77 build 84539.
No commit, push or deployment. The baseline was frozen from the active worktree
before this dispatch patch, including the preceding ANISETRON UPS changes.
Older verification reports are not counted as new evidence below.

## Implemented contract

Both public controllers expose `updater(event)`. ANISETRON is the final guarded
mandatory service inside the central updater, beyond `skip`; its effective order
is unchanged. Child clock predicates admit paid owners/cleanup, due mobility,
movement attachments/sampling/repair, Wound marks and due committed packets.
They use existing state without initialization, allocation, queue counting or
entity queries. Permanent upgrade memories alone stay idle.

The Lance retains step 13, the every-tick fallback and its once-per-tick flag.
Its old limit was already ignored; removal of the pending-count/budget calculation
does not remove a functioning cap. `service_for_qc(legacy_limit,event)` preserves
the legacy call shape and actual processed-packet count. Diagnostic pending-count
exports and optional decoration budgets remain. Paid state, deadlines, movement,
fidelity, prototypes and artwork are unchanged.

## Fresh engine results

All named reports completed and passed:

| Fixture | Current result | Retained run |
|---|---:|---|
| Dispatch, pure predicates, legacy adapter | 176 checks | `dispatch-contract-after` |
| Ordinary idle reload, no configuration rebuild | 4 checks | `dispatch-cold-save2` / `cold-reload.txt` |
| Six ANISETRON fidelity suites | 898 checks; accounting and locks match | `dispatch-off` through `dispatch-unbounded` |
| Tracking and continuous presentation | 47 checks | `dispatch-tracking` |
| Native movement and stacked slows | 28 checks | `dispatch-mobility` |
| Lance inheritance and committed effects | 84 checks | `dispatch-inheritance` |
| v3 replay with Off configuration change | 84 checks | `dispatch-v3-replay` |
| Historical v2 paid replay | 10 checks | `dispatch-v2-replay` |
| Historical active/queued v1 replay | 7 checks | `dispatch-v1-queue-replay` |
| Original reference-16 charge replay | 6 checks | `dispatch-historical-replay` |
| Singularity Lance focused mechanics | 798 checks | `lance-updater-mechanics` |
| Lance schema-13 and schema-14 replays | 8 + 8 checks | `lance-updater-reload13-turn`, `lance-updater-reload14-wide` |

ANISETRON runs are under `.factorio-qc/anisetron/`; Lance runs are under
`.factorio-qc/cu/l/`. The [fixture README](README.md) records replay commands.

The frozen/current dispatcher trace matches over 64 ticks, covering all sixteen
phases, an exhausted railgun lane taking `goto skip`, exactly one eligible call
per weapon, and the ANISETRON tail position. The mixed-target native trace matches
86 ordered damage packets and 36 paid-state/endpoint samples, including target
death and subsequent targeting. Eighteen additional adapter packets also match.

Nineteen synthetic predicate cases each compare serialized state across eight
calls. Separate native fixtures exercise real movement without fire, stopping,
finite effects, source removal, Wound expiry and configuration cleanup. The idle
reload proves that a cold local preset remains eligible across repeated queries,
then initializes once through service and immediately becomes idle.

Adapter limits 0, 1 and 100000 each resolve three contacts at +8 and three
collapses at +38, returning three for each due batch and zero before/repeated
service. Each delivers exactly 4500 damage. These synchronous adapter probes use
production admission but simulate the paid notification; native payment is
separately covered by the ordinary mechanics and mixed-target fixtures.

Two fixture corrections were needed, without production changes: use one million
health for exact deltas (native float health at one hundred million rounded
500-damage changes to 496), and reload the idle save with unchanged staged files.
The normal wrapper's rewritten test configuration triggers configuration repair
and therefore cannot isolate cold local initialization.

## Parity and timing

The 32-vehicle fleet comparison matched all 180 sampled ticks and 14816 ordered
damage packets through idle, movement, firing and moving fire. Samples include
position/speed/heading, slowdown modifiers, ammunition, paid deadlines, locks,
beam endpoints, and each strand's geometry, visibility, offsets and finite TTL.

The updated profiler understands old `update` and current `updater` entry names.
Each phase uses the same 900 simulated ticks, including skipped calls. Idle
ANISETRON invocation count falls from 900 to 450; all active phases retain 900.
Measured inclusive ANISETRON milliseconds per simulated tick:

| Phase | Frozen | Current |
|---|---:|---:|
| Parked | 0.086803 | 0.084514 |
| Moving | 0.410535 | 0.419274 |
| Firing | 2.353324 | 2.514742 |
| Moving and firing | 2.675712 | 2.684893 |

This single pair establishes behavior parity and correct timing denominators;
it does not establish a speedup. Nested timers are not additive. Headless results
do not measure GPU cost, fresh pixel alignment, audible mixing or whole-factory UPS.

The native-power Lance comparison also passes accounting parity over the fixed
[120,600) window: 480 simulated ticks, 165 serviced ticks and 46 shot-bearing
ticks on each side. Inclusive shot plus service measures 3.610573 versus 3.673589
ms per simulated tick. Its internal `update-total` label is retained across the
entry-point rename. Runs are `lance-dispatch-profile-before` and
`lance-dispatch-profile-after`; `lance-profile.json` retains all nested phases.
These single-pair timing differences are reported without a speedup claim.

An empty visual registry may retain its previous diagnostic `last_pass` instead
of refreshing an empty pass on every cadence tick. Populated fleet visitation and
all gameplay accounting remain matched; the model documents this idle behavior.

## Repository and evidence

Doctor passed. Conceptual-link audit passed with zero findings across 47 models
and 131 owned sources. Preflight passed Lua/PowerShell syntax, require resolution,
locale checks, asset references and version consistency. Full preflight remains
red from 109 protected Python bytecode-cache writes and two existing encoding
issues (`scripts/qc/singularity-lance/angular-results.json` and
`temp/anisetron-tracking-fix/blueprint-final.json`). Existing Auric/Apocalypse
header warnings remain. In-memory compilation of all 155 Python files separately
passes without writing caches. Scoped `git diff --check` passes. These unrelated
files were not changed for this task.

The frozen manifest checks 133 shipping graphics/sound files with no changed
hashes. Concurrent Terrain Evolution work was left untouched. Reports, source
hashes and the scoped production diff are retained under
`.factorio-qc/anisetron/dispatch-work/`: `before-hashes.json`,
`source-manifest.json`, `implementation.diff`, `order-parity.json`,
`fleet-parity.json`, `fidelity.json`, `runtime-summary.json`,
`lance-regression.json`, `lance-profile.json`, `static-summary.json`, `blueprints-final.json`, and
`preflight.txt`. The baseline and transition saves remain available.
