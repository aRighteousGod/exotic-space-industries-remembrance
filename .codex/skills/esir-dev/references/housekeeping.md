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
  fixtures, dependency seeds, shared caches, final assets, provenance and review
  records remain protected. Do not enroll whole asset dossiers as disposable output.
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
even without `-Apply`; the default invocation without these switches is read-only.
Do not close another task's runs or retire evidence before finishing its comparison.
Routine closeout applies the established policy without requesting permission again.

Keep the latest two successful payloads per workflow/scenario and exact Factorio
version. Active tasks, incomplete/interrupted runs, unresolved failures and pins remain
protected regardless of age. Compact summaries and reproduction metadata survive
bulk retirement. Pin configuration comparisons that must outlive two newer successes.

Shared QC, runtime benchmarks and Gaia checks register automatically and return
`housekeeping.run_id`. Engine output and run-mod copies have a unique directory;
the established `fmqc/mods-live` dependency seed stays outside retention. Managed
runs use the existing dependency seed selection without writing legacy staging.
Housekeeping errors are separate from the QC verdict;
do not describe an unmanaged run as automatically retained or cleaned.

## Focused runners and ad hoc output

Dot-source `scripts/esir-housekeeping.ps1`. Register before creating disposable output.
Registration requires a new, absent directory and never adopts historical output.

```powershell
$run = Register-EsirArtifactRun -RepoRoot $PWD.Path -Workflow 'focused-example' `
    -Scenario 'native-default' -EngineVersion '2.0.77' `
    -Reproduction 'Exact command and settings used to reproduce this fixture'
$payload = Join-Path $PWD.Path $run.payload_path
# Direct the actual runner into $payload; inputs/durable deliverables stay elsewhere.
$summary = @{
    run_id = $run.id; workflow = $run.workflow; engine_version = $run.engine_version
    repo_root = $run.repo_root; payload_path = $run.payload_path
    timestamp = [DateTime]::UtcNow.ToString('o')
    overall_status = $actualResult.overall_status; result = $actualResult
}
Complete-EsirArtifactRun -RepoRoot $PWD.Path -RunId $run.id `
    -ExitCode $actualExitCode -Summary $summary
```

Use the actual resolved engine version and result, not the example constants.
Completion requires matching identity, fresh evidence and exit zero; failed/skipped
results remain protected. Pass `-DumpPath` for final data. Dumps must be fresh,
nonempty, owned, valid JSON objects; the validator streams them and conservatively
rejects individual tokens larger than 16 MiB.

Other `-Classification` values are `scratch` and `render-intermediates`. For renders,
provide `-RetainedPaths` for retained source/specification, final sheets and QA evidence
outside the disposable directory, plus reproduction instructions. Complete only after
QA. The registry records claims; establish classification and retained evidence before
enrollment. `models/` remains outside this workflow.

For a unique uncommitted original, use `-Classification protected-evidence` and pin
the new run before copying the original into its payload. This classification never
expires, even after close/unpin. Use a unique registered path, not a reused backup
filename. Once the original is safely preserved elsewhere or the edit is abandoned,
resolve that exact backup through the normal scoped edit workflow; never reclassify
source material as disposable merely to make retention remove it.

```powershell
Set-EsirArtifactRunState -RepoRoot $PWD.Path -RunId $runId -Action pin -Reason 'startup-off comparison'
Set-EsirArtifactRunState -RepoRoot $PWD.Path -RunId $runId -Action unpin -Reason 'startup-off comparison'
# After investigating failed/interrupted work and resolving its evidence needs:
Set-EsirArtifactRunState -RepoRoot $PWD.Path -RunId $runId -Action release -Reason 'Failure resolved; evidence summarized'
$dump = Get-EsirRetainedFinalData -RepoRoot $PWD.Path -EngineVersion '2.0.77'
```

Release cannot override a live running owner or pins. Successful runs use close/unpin
and normal retention. Unknown-engine QC stays protected. If no matching verified dump
exists, run matching QC or explicitly inspect historical evidence without adopting it.

## Deletion and reporting contract

Only new registered subdirectories of `.factorio-qc`, `output`, `temp`, `tmp`,
`.tmp_inspect` or `Render` qualify. They must be ignored and contain no tracked files.
Catalog saves, dependency/cache roles and registry storage are protected. Overlapping
ownership is rejected. Registry changes are serialized and replaced atomically.

Recheck identity, size/time, ownership, pins and containment before deletion; refuse
reparse traversal, locked files and changed payloads. Delete verified leaves and then
empty directories, never recursively delete a payload. Unlinking staged hard links
must not rewrite shared content or attributes. Preserve uncertainty and report why.
Retained file references protect their owning payload across runs, including after
the consumer's bulk output expires; removing durable evidence needs separate review.

Report removed file counts, logical bytes, protected reasons and observed free-space
change separately. Hard-linked path totals are not reclaimable-space estimates;
volume free-space changes may include unrelated activity. Keep inventory errors/skips
visible. Validate with `scripts/qc/housekeeping/check-housekeeping.ps1`; its isolated
fixtures never apply cleanup to the real historical backlog.

For separately reviewed, completed and inactive large text evidence, consider
lossless file-level NTFS compression instead of deleting required dumps or reports.
Check exact-path containment and identity, verify before/after content hashes and
logical lengths, and report storage bytes separately. Preserve existing paths and
ordinary tool readability; do not enable compression for whole artifact directories.
Do not hardlink mutable reports or dumps: a rerun can truncate every linked copy.
