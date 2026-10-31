# Housekeeping: generated artifacts and completed edits

Automatic retention never prunes actual source mod folders. Completing an authorized
edit includes removing the exact files that edit makes obsolete. Source retirement
uses the normal reviewed patch workflow, not the retention command.

## Boundaries

- Leave root `models/` entirely outside housekeeping. Never prune `.git/`.
- Exclude actual mod roots (main ESIR, graphics, soundtrack and other source packs)
  from automatic retention, including generated-looking files inside those roots.
  Normal development may inspect, edit and retire files in the touched subsystem.
- Ignored does not mean disposable. Historical QC, source backups, paid downloads,
  fixtures, unclassified dependency seeds/caches, final assets, provenance and review
  records remain protected. Do not enroll whole asset dossiers as disposable output.
  The managed package store below has its own explicit reference/collection policy.
- Codex-home sessions, databases, plugins, tools, images, memories and `.tmp` remain
  inventory-only. Never clean external application data through this workflow.

## Finish replacements without shipping leftovers

For an authorized replacement, account for added, updated, retained and retired files.
Prefer the canonical filename when its role stays the same. Put experiments, previews,
alternate renders and temporary backups in ignored staging outside mod folders.

When names or sheet counts change, inspect the touched family: numbered sheets/stripes,
shadows, masks and companion metadata. Remove proven-superseded shipping files in the
same patch, including obsolete higher-numbered sheets. Search filenames and directory
or basename prefixes across packs, helpers, generators, manifests and relevant startup
or compatibility branches. Trace constructed filenames and preserve shared assets.

A no-hit search does not prove non-use. Preflight finds supported missing references;
`qc-assets` checks structure. Final-data evidence is configuration-specific. Use the
relevant engine/profile and graphics-load or visual checks for changed geometry.

Git history preserves committed originals. Preserve a unique uncommitted original in
pinned staging when necessary; do not duplicate every replacement permanently.
Reconcile partial failed promotions too: PNG copies can precede a failed prototype
patch. Report unresolved ownership/consumers instead of deleting uncertain files.

At asset closeout, resolve task-created temporary scene saves such as Blender
`.blend1` backups after checking the retained canonical project, original sources,
reproduction steps, final outputs and QA. A different backup is not an identical
duplicate: preserve it if it contains unique work or an intentionally retained
comparison. Review exact files; never blanket-delete backup extensions or dossiers.

Retiring proven-obsolete files directly associated with an authorized edit requires no
separate housekeeping approval. Do not expand this into a whole-pack orphan sweep.
The asset exporter remains a narrow copy-and-prototype tool.

## Routine inventory and closeout

```powershell
# Lightweight registry plan and nonrecursive metadata for eligible artifact roots.
powershell -ExecutionPolicy Bypass -File scripts/invoke-esir-dev.ps1 -Task housekeeping -AsJson
# Explicit full inventory; Codex-home paths remain metadata-only.
powershell -ExecutionPolicy Bypass -File scripts/invoke-esir-dev.ps1 -Task housekeeping -FullInventory -IncludeCodexHome -AsJson
# At task closeout, close only run IDs whose evidence this task has finished using.
. ./scripts/esir-housekeeping.ps1
Set-EsirArtifactRunState -RepoRoot $PWD.Path -RunId $runId -Action close
powershell -ExecutionPolicy Bypass -File scripts/invoke-esir-dev.ps1 -Task housekeeping -Apply -AsJson
```

`-CloseRunId <ids>` combines closeout with the wrapper. Closing changes the registry
even without `-Apply`; for new compact runs it also bundles evidence and retires
owned scratch/views. The default invocation without these switches is read-only.
Do not close another task's runs or retire evidence before finishing its comparison.
Routine closeout applies the established policy without requesting permission again.

Shared QC, runtime benchmarks and Gaia checks register automatically and return
`housekeeping.run_id`. Their new compact runs keep evidence separate from mod views
and scratch. Housekeeping errors remain separate from the QC verdict. Older records
and raw registration-only runners retain their conservative legacy rules; they are
not retroactively adopted or described as using the new storage contract.

## One managed copy of each required package

`scripts/esir_qc_storage.py` owns the store and leases. PowerShell callers use
`scripts/esir-qc-storage.ps1` and `Invoke-EsirQcStorage`; Python callers use the same
implementation rather than another copy/link helper.

- Canonical ZIP identity includes mod name, version, Factorio family and SHA-256.
  Importing identical bytes reuses one physical file. Same-version/different-content
  packages stay distinct and need exact selection; never overwrite by version alone.
- Development dependency seeds contain lock/selection metadata, not another ZIP set.
  Preserve exact engine, lock hash, archive hash and source-precedence validation.
  Never infer the current selection from historical `mods-live` or preview folders.
- Each active run has a thin mod view on the store's physical volume: archive
  hardlinks, source views, and private selection/settings/helper files. A hardlink
  failure is an error, never permission to silently copy a package.
- Declare `read-only` or `private-mutable` source staging. Junction only sources
  the run will read. Fixtures that rewrite Lua/configuration need physically private
  mutable files; share only immutable media. Check write targets before patching and
  validate input fingerprints before accepting results. Never edit through shared
  links or modify their attributes.
- Current profile references, active task leases and explicit pins retain packages.
  Collect unused managed versions at task closeout and explicit housekeeping.
  Historical receipts record input hashes but do not retain packages forever.
  Reproducing an unpinned historical run may require fetching its exact input again.

Use C: by default. Mod views stay with the store; bulky scratch can independently
overflow to `D:/ESIR`. Keep a configurable 10 GiB free-space reserve. Estimate scratch
from the caller's estimate or the previous measured peak plus 25%, falling back to
20 GiB when neither exists. If the store itself needs overflow, relocate only that
managed store while no active leases exist: journal the transfer, verify hashes,
publish its new root, then retire the verified old copy. Interrupted transfers keep
the old authority recoverable. Do not automatically move back or relocate historical
directories because an overflow root exists.

Change the reserve or unknown-workflow estimate through the shared helper's
`configure` action with integer `reserve_bytes` and `default_estimate_bytes` fields;
do not edit the ownership registry by hand. Per-run `estimate_bytes` overrides only
that run's scratch estimate.

## Compact evidence and consumer lifetimes

At closeout retain a compressed evidence bundle and small readable index containing
the verdict, relevant logs, exact input identities, settings, reproduction commands
and extracted assertions. Select required saves and final QA captures explicitly.
Externally referenced final media stays in its canonical location without another
copy inside the bundle. Do not retain two complete successful payloads by default.

Raw prototype dumps, engine caches, staged setups, temporary packages and intermediate
frames are scratch. Validate a fresh dump and extract assertions before disposal;
do not replace full JSON validation with a file-exists check. Pin bulky evidence with
a reason when it remains necessary. `Get-EsirRetainedFinalData` returns only an active
or explicitly pinned verified dump for the exact engine; otherwise regenerate it
through matching QC. A receipt's historical path is not an available dump.

A process exit is not necessarily consumer completion. Portal capture keeps its frame
lease until render and validation finish; multi-phase fixtures keep their view until
the final phase. Close only after comparisons, extraction and downstream consumers
finish. Failed runs retain a compact failure reproducer rather than every generated
file; uncertain cleanup remains a protected error. Unresolved failures, active owners
and pins cannot be bypassed by claiming that output is disposable.

## Focused runners and ad hoc output

Register before creating output; registration requires a new absent directory. Use
`Start-EsirManagedQc` for shared harness work. A focused adapter that registers its
own run must call `Initialize-EsirManagedQcContext` with the matching run ID and
explicit source mode before staging. Read the current development profile rather
than copying an engine constant from an older fixture.
The current profile is Factorio 2.1.24. When its dependency seed is absent, restore
it with `scripts/qc/factorio-2.1/prepare_development_seed.py --dependencies <verified-input-directory> --smoke <accepted-save>`.
The input lock must match the profile's SHA-256; imports reuse same-volume archive
identities and the new seed contains only lock/selection metadata. Never relabel
historical 2.1.23 evidence as 2.1.24 acceptance.
Complete through `Complete-EsirArtifactRun` with a fresh summary matching the run's
`run_id`, `workflow`, `engine_version`, `repo_root`, `payload_path`, `timestamp` and
actual `overall_status`; a successful process alone does not complete ownership.

```powershell
. ./scripts/esir-housekeeping.ps1
# $context comes from Get-EsirQcContext; $run is a new registered task-owned run.
Initialize-EsirManagedQcContext -RepoRoot $PWD.Path -Context $context `
    -RunId $run.id -SourceMode private-mutable
# Run consumers using the context's separate view, scratch and evidence paths.
Set-EsirQcSelectedEvidence -RepoRoot $PWD.Path -RunId $run.id -Paths $selectedPaths
# Complete with the actual matching verdict, then close after all consumers finish.
Set-EsirArtifactRunState -RepoRoot $PWD.Path -RunId $run.id -Action close
```

Pin/unpin with `Set-EsirArtifactRunState -Action pin|unpin -Reason <reason>`; compact
runs synchronize these with their storage lease. Closing a pinned run defers bulk
retirement until its pin is removed. Preserve exact engine and reproduction metadata
when resolving a failed/interrupted run. Unknown-engine results remain protected.

Historical standalone runners require an explicit managed-storage adapter before
reuse can claim this policy. A previous `-ReuseRun` path does not establish current
ownership, safe mutability or matching input hashes. Do not retrofit historical
acceptance reports or adopt old output during ordinary execution.

For non-QC generated scratch and render intermediates, retain the registration
classifications and `-RetainedPaths` contract: identify source/specification, final
output and QA evidence before enrollment. Preserve unique uncommitted originals as
pinned `protected-evidence`; never reclassify source material as disposable to make
retention remove it. `models/` stays outside this workflow.

## Deletion and reporting contract

Registry ownership covers new ignored repository payloads and the helper's exact
managed overflow roots. Catalog saves, source packs, historical caches and unregistered
paths remain outside automatic collection. Reject overlapping ownership and serialize
registry updates atomically.

Recheck identity, size/time, ownership, consumers, pins and containment before deletion;
refuse locked files and unexplained changes. Remove only recorded owned view junctions
as links, never recurse through their targets. Tear down views and short aliases before
durable evidence snapshots. Unlinking hardlinks must not rewrite shared content or
attributes. Preserve uncertainty and report the specific protected reason.

Report removed file counts, logical bytes, unique allocated recovery when measured,
and observed volume free-space change separately. Hardlinked path totals are not
reclaimable-space estimates; concurrent volume activity can change free space. Keep
inventory errors visible. Validate with isolated storage and housekeeping fixtures;
never apply tests to the historical backlog.
`scripts/qc/storage/check-skill-workflow.ps1` exercises the documented register,
stage, complete and close lifecycle in a disposable repository outside editor-watched
output. It verifies physical package identity and scratch retirement without claiming
native engine coverage. Locks held by an editor or engine remain protected errors;
retry after the owner releases them rather than weakening cleanup checks.
