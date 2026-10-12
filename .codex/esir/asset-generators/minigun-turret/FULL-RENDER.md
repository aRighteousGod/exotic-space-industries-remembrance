# Full render continuation

Installed beside the canonical renderer after the reviewed 2026-10-11 pilot gate.
Consult the registered run manifest for current execution status.
It reuses the exact approved prototype-2 source, scene, renderer and 256-sample,
seed-zero configuration. It does not rerun passed pilot color/layout tests,
regenerate icons, compile sprites, promote PNGs or change gameplay.

## Verified starting point

- `separated-v2-pilot`: 466 distinct hash-verified 540×540 RGBA8 PNG passes,
  55,101,785 bytes, configuration `cf3ce7c1…`.
- Directions 0, 32, 64, 96, 128, 160, 192 and 224: two fixed-base passes,
  16 upper passes and 448 complete-object/shadow passes across 28 poses.
- The 32 accepted sharp/running motion-blur endpoints are already present in
  those 466 files. They do not add further completed directions.
- The existing 1024px icon master and four SD/HD item/technology PNG payloads
  are verified and reused. Native icon readability remains a later review.
- No additional compatible full or partial direction chunk was found in the
  workspace render journals. Older smoke/assembled/teaser images have different
  settings. Two protected unit-test temporary directories were unreadable;
  neither is a render destination in the known tooling or artifact registry.

The full family has 14,850 Object/Shadow passes. Exactly 14,384 remain, covering
248 directions. Pilot timings suggest roughly 12.5 hours on this GPU. This is
an estimate, not a deadline or a completed-render claim.

## Approval before an expensive run

`Stage` and `Run` require an explicit `-ApprovalReport`, its `-ApprovalSha256`,
an actual native `-ImageReview`, and its `-ImageReviewSha256`. No script creates
approval or converts pending evidence to a pass.

The approved summary uses firing-fixture schema 1 and must set
`pilot_calibration_gate_passed: true`, `automated_checks_passed: true`, an empty
`failures` array, and status `pilot_calibration_passed` or `passed`. It must sit
beside the retained `native-report.json` and `minigun-firing/` native captures.
The validator binds the report/review to the actual model, candidate graphics
data, optional mechanical metadata, source image bytes, height-compensation
review and all eight requested/decoded piercing headings. Applicable flash and
projectile origins must meet the report's tolerance, no looser than two normal
native pixels. Instant-delivery projectiles may be explicitly not applicable.
The original native report, visual review and heading measurement report are
hash-bound. All 120 heading diagnostic image hashes and the seven baseline,
first-flash and decay captures per heading are rechecked through extended
Windows paths, including capture filenames longer than 260 characters.

The actual tested profile/doctrine is retained. A passed SD/on eight-view pilot
is enough for this full-render gate. `alignment_gate_passed: false` and
`production_approved: false` remain valid for calibration-only evidence. Final
moving/all-ammo/all-256 checks and all four final profile/doctrine configurations
remain promotion requirements, not prerequisites invented for generating art.

## Commands

Run from the repository root. PowerShell 5.1, Python and the existing Blender
5.1.1 installation are expected. DryRun does not register, copy or launch.

```powershell
$launcher = '.codex/esir/asset-generators/minigun-turret/invoke-full-render.ps1'
powershell -ExecutionPolicy Bypass -File $launcher -Task DryRun
```

Without approved evidence, DryRun verifies source hashes, all 466 pilot PNGs
and the existing icons, and reports `ready_to_render: false`. This is expected
while the pilot calibration report is pending. Supplying invalid or partial
approval arguments fails rather than silently bypassing the gate.

After the reviewed calibration exists, use its actual paths and SHA256 values:

```powershell
powershell -ExecutionPolicy Bypass -File $launcher -Task Stage `
  -ApprovalReport '<retained passed pilot summary>' -ApprovalSha256 '<SHA256>' `
  -ImageReview '<actual image review JSON>' -ImageReviewSha256 '<SHA256>'
```

Stage registers a fresh `separated-v2-full-*` sibling under `handoff-256` as
protected evidence and reports its exact `FullRoot`. It copies all pilot PNGs,
the configuration and the original journal byte-for-byte. It also preserves
the existing icon files under `reuse-icons/` with their original relative paths.
These are ordinary independent copies, never mutable hard links. The protected
classification prevents this expensive source output from automatic retirement.

Only the main operator starts engines:

```powershell
powershell -ExecutionPolicy Bypass -File $launcher -Task Run -FullRoot '<exact staged root>'
# Optional bounded execution: finish one verified chunk, then stop between chunks.
powershell -ExecutionPolicy Bypass -File $launcher -Task Run -FullRoot '<exact staged root>' -MaxChunks 1
powershell -ExecutionPolicy Bypass -File $launcher -Task Verify -FullRoot '<exact staged root>'
```

The default chunk contains eight unfinished directions (464 passes, about
24 minutes at pilot speed). Direction lists exclude completed pilot directions.
Each process runs the unchanged canonical renderer with `upper,full`, all 28
poses, 256 samples and eight CPU threads. Its renderer still selects the same
GPU and checks the exact stored configuration. There is no sample reduction,
seed change, material change, symmetry assumption or new exposure behavior.

## Resume and failure behavior

The manifest binds the approval and review, launcher/validator hashes, Blender
binary, configuration and registered output root. Resume with the same command
and exact `FullRoot`; approval paths need not be repeated. Stage can resume its
own interrupted seed copy when existing copies are byte-identical. It never
adopts an arbitrary preexisting directory or overwrites a differing seed file.

Run hashes all completed files before resuming, then sends each partially
complete direction to the renderer, which skips its verified completed passes.
Every successful chunk is checked for all 464 expected records; the existing
journal prefix must be unchanged. At final completion all 14,850 passes are
hashed again. Repeated Run after successful completion verifies and returns.

Malformed/truncated journal lines, a missing final newline, conflicting duplicate
records, changed PNGs, unjournaled PNGs or abandoned `.seed-partial` files stop
with the evidence intact. No journal is truncated, normalized or regenerated.
Inspect the exact interruption before an explicit repair; restarting does not
authorize dropping evidence. Logs and orchestration events use new attempt IDs.

The launcher holds an exclusive output lock and checks for Factorio or another
background Blender process before each chunk. Process inspection failure is a
failure, not an assumption that the engines are idle. The native process handle
is retained until `WaitForExit`/`ExitCode` is read; no `Refresh()` call discards it.
External tools still must honor serial engine ownership. Interrupting the shell
can leave its child Blender process running; inspect that process before resume.

Free space must exceed an eight-GiB floor plus 1.5× the pilot-based estimate for
remaining PNG bytes before work starts and before every chunk. Blender also
retains its own five-GiB per-frame guard. The output root and its ancestors must
stay inside this checkout, with no reparse/junction traversal.

Registry success means the rendered family is complete and hash-verified. The
manifest still says `production_approved: false`; native QA and final promotion
are deliberately outside this launcher.

## Lossless runtime savings already used

Reusing the pilot skips 466 passes; reusing icons avoids their Blender work.
The renderer already keeps persistent scene data and imports once per process.
Increasing `-ChunkSize` at initial Stage to 16 or 32 only reduces process/GPU
startup overhead; it does not reduce per-image render time and increases the
time between clean pause points. Eight is the conservative default.

No additional symmetry or pose reuse is proven. The four-strip atlas strategy,
PNG compression and post-render packing reduce delivered size, not the number
of required source render poses. Shadow/color pass elision would change the
approved source contract and is not performed here.
