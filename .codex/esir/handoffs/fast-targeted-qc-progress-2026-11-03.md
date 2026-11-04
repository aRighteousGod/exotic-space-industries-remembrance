# Fast and targeted QC implementation progress — 2026-11-03

Completed: see the [dated acceptance record](fast-targeted-qc-acceptance-2026-11-03.md)
for final receipts, timing observations, closeout and evidence boundaries.

Implementation is authorized by the user's “Implement the proposed plan.” This
work replaces routine full-QC repetition with explicit-scope iteration and
targeted acceptance. It does not change the explicit full gate, engine 2.1.24,
dependency selection or main version 1.4.03. Concurrent turbine work is preserved.

## Implemented

- `qc-quick`, `qc-targeted`, exact `ChangedPath`, and read-only `PlanOnly`.
- Explicit scope required: paths, ref, or suites. Quick presets declared for every
  active catalogue suite; targeted retains required cases and profile matrices.
- Narrow helper routing, core for dispatcher/ei_lib, representative lifecycle rows
  and conformance for runner changes, static catalogue-only routing, honest gaps.
- Active non-core engine-smoke and lazy seed creation before save-backed phases.
- Strict first-launch normalization: exact enabled mod set; a newly created settings
  file must match fresh native prototype-default attestation. Existing settings
  files remain byte guarded. No cached receipts or silently shortened assertions.
- Requested preview scope avoids Gaia work. Bare preview/full and targeted Gaia
  retain fixed preview + native acceptance, once each.
- Scoped syntax/encoding/locale/link/skill checks, managed child checks and compact
  native/broad closeout. Explicit omissions, gaps, process counts and timings.
- Repo/global guidance now leads with scoped planning, quick iteration, targeted
  acceptance, and explicit-request/authorized-release-only full QC.

## Verified so far

- 42 Python host tests pass, including scope isolation, matrix completeness,
  dirty rename/deletion handling, failure propagation and strict settings parsing.
- PowerShell 5.1: encoding 15, helper staging 12, preview acceptance 20 checks pass.
  PowerShell 7: encoding 15 and preview acceptance 20 checks pass.
- Thirteen initial skill validators pass; changed guidance also passed scoped
  strict static validation (`9dfb737732b64926a9bc463eb6f6e6fe`).
- Quick engine smoke is **ok**: parent `a1d497ef00f948bf9673c68d35e4f8ae`, native
  child `971ddd2ebc444477a8b5f85af3f2373a`, 47 assertions, one scenario session,
  no seed or checkpoint, about 25 seconds game process / 171 seconds workflow
  before parent closeout. Both runs are closed; child evidence is compacted.
- Earlier smoke `08366f46d3464faf894fb235c1ee9308` correctly failed input integrity
  on engine normalization; its parent `818566ae34b346a59cc67aca10a3c3cd` is retained
  as failed provenance. Both are closed. No historical receipt was rewritten.

## Final qualification

- Full adverse conformance is **ok**: targeted parent
  `53e9f6d5b35f47f7ba59d63556e07405`, native child
  `c8bee27c0c9746b9bcca71f0b2dbd463`; all seven cases, about 126 seconds workflow.
- Eight-row targeted lifecycle/matrix qualification is **ok** under parent
  `ade6b9c7390741a7b1921006cf2c311c`: build dispatch, induction lifecycle,
  both mirroring profiles and all four bootstrap settings rows; 16,250 native
  assertions. Its final-data child `0a20e7819ce942538cc3d927a3bf99c3` passed all
  39 checks before compacting the 2.076 GB dump. The workflow took 2,288 seconds
  before parent closeout, with 24 native game sessions plus the data dump.
- Exact changed-path rename/deletion/new-file validation passed in an isolated
  Git fixture. Forward plans for GUI, research, scheduler helpers, recipes, locale
  and shipping assets selected only their expected checks and explicit gaps.
- Focused Gaia is **ok**: parent `6890545c27fc4d8b9484e8d267460d2c`, one native
  child `79952638177f4bc8abdb3943a4c39db0`, 56 assertions, fixed seed-1000 preview
  and all six resources. Native surface identity and Gaia tiles are asserted.
- Requested-only Nauvis seed-42 preview is **ok**:
  `f80a04afb4bf4f9cb0604f7f3ec73e92`, no Gaia preview/native child. The explicit
  planet/seed request automatically chose requested scope without an override.
- All 25 task-owned runs are closed; 16 evidence archives and 412 indexed entries
  passed integrity verification. No Factorio process remained at final check.
  The source fingerprint still matches the completed gameplay qualification.
- Final selector repair is complete: explicit smoke and extended inventory
  preserve smoke; fallback deduplication compares actual selected candidates and
  equivalent profile inputs after quick projection. Added focused regressions.
  The eight-row selection/check plan is byte-for-value unchanged by the repair.
- Final adverse conformance is **ok** after that selector repair: parent
  `f250e1a4636b457d9ce427be4e927b02`, child
  `0dd268331361497f94d383bbaf58df4a`, all seven cases, 126.6 seconds before parent
  closeout. Both are closed; the child is compacted. Gameplay matrix repeats are
  unnecessary for this selector-only change.
Do not launch `qc-full` just to qualify this implementation.

The shared native guide documents the interface and evidence boundaries. Native
and broad children retain whole-source input validation even for narrow scope.
Keep runner/catalogue/helper files stable during qualification. Another chat has
also run a private loader investigation; its runs are not owned by this task.
