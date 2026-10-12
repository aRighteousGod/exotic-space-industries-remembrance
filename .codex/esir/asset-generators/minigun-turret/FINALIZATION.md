# Finalization and shipping verification boundary

The finalizer, consumer fixtures and shipping auditor are installed. Native acceptance remains pending until the full evidence exists. The finalizer itself starts no engine, installs no assets, builds no archives and edits no shipping Lua.

`finalize_graphics_data.py` converts an **unchanged, fully tested** candidate lookup into calibrated metadata. It does not calculate a new muzzle point, fit a new offset, or accept an eight-view pilot. It leaves `production_promoted=false` and writes only into a new directory below repository `output`.

The finalizer reopens the canonical emitter and calls its production-shaped, read-only profile validation. This rechecks full 256-direction/28-pose compiler metadata, every PNG hash and geometry record, icons, exact rotor reconstruction, and the native lossless color aggregate. It never invokes `Emitter.emit()`. It compares the result with the frozen artifact map and reproduces the candidate Lua from its JSON before trusting the tested Lua hash.

The schema-2 firing matrix is recomputed from all four retained SD/HD × Ballistic Divergence off/on runs. Its exact candidate, mechanics, anchors, and **actual loaded PNG manifest** must match the current atlas. The validator rehashes screenshots, reviews and retained candidate PNGs, verifies each audited projectile route against actual shot observations, and recomputes moving-shot image approval. Both compact and diagnostic heading-template analysis retain and bind `heading-measurements.json`; the matrix repeats its coverage, control and capture checks. A passing summary alone cannot establish fresh native evidence.

The final table retains the exact 256 muzzle tuples. `native_launch_contract` records each actual effective `projectile_center`, `projectile_creation_distance`, and `apply_projection_to_projectile_creation_position` with `{present=true,value=...}` or `{present=false}`. This preserves native absence and avoids assuming that the lookup makes another launch field irrelevant. Both the main consumer and the unloaded example must apply this measured contract.

## Inputs and command

Create a request JSON with the following shape. Each reference is `{ "path": "an exact existing file", "sha256": "its lowercase SHA256" }`. Relative paths resolve from the request's directory. Do not edit historical evidence to satisfy this schema.

```json
{
  "schema": "esir.minigun.finalization-request.v1",
  "artifact_map": {"path": "full-emission/artifact-map.json", "sha256": "REQUIRED"},
  "compiled_metadata": {"path": "full-compiler/metadata.json", "sha256": "REQUIRED"},
  "anchors": {"path": "muzzle-anchors.json", "sha256": "REQUIRED"},
  "mechanical_data": {"path": "candidate-mechanical-data.lua", "sha256": "REQUIRED"},
  "candidate_assets_manifest": {"path": "full-run/candidate-assets-manifest.json", "sha256": "REQUIRED"},
  "firing_matrix": {"path": "full-firing-matrix.json", "sha256": "REQUIRED"},
  "lifecycle": {"path": "lifecycle-acceptance.json", "sha256": "REQUIRED"},
  "visual": {"path": "visual-acceptance.json", "sha256": "REQUIRED"}
}
```

The full emission must contain its original `graphics-data.json`, candidate Lua, `emit-input.json`, artifact map, and generated draft HD example. Color evidence is taken from the candidate's bound provenance; it cannot be silently substituted. Residual shadow input, if used in a later approved route, additionally needs a bound `shadow_metadata` reference. The current accepted design uses combined shadows; report the native review under `combined_shadow`.

```powershell
python -B .codex/esir/asset-generators/minigun-turret/finalize_graphics_data.py `
  --repo . `
  --acceptance output/minigun-implementation/finalization-request.json `
  --output output/minigun-implementation/finalized-minigun
```

The default matrix validator is the installed `firing-fixture/summarize_matrix.py`. The receipt records its source hash plus `evidence_contract.py`, `analyze_fixture.py` (`matrix_image_review`) and `compact_flash_evidence.py` (`matrix_compact_controls`). The output directory must not already exist. A rejected check produces no finalized files. Offline tests do **not** claim native or end-to-end finalization approval.

## Review evidence interface

The lifecycle and visual review files use `esir.minigun.lifecycle-acceptance.v1` and `esir.minigun.visual-acceptance.v1`. Both require:

- `lineage` exactly containing `source_sha256`, `compiled_metadata_sha256`, `candidate_data_sha256`, `mechanical_data_sha256`, `anchors_sha256`, and `atlas_inventory_sha256`. The last value hashes canonical sorted compact JSON of the full manifest's `files` mapping, including PNG hash, bytes, and dimensions.
- `passed=true`, empty `failures` and `pending_review`, and a nonempty `reviewer` identity.
- `raw_reports`: named file/SHA references. Each raw report has `engine_version="2.0.77"`, the same lineage, `automated_checks_passed=true`, empty `failures`, and `cases`. Any `source_native_reports` references are also rehashed.
- Exactly the case inventory below. Each reviewed case has `id`, `raw_report` (a named reference), `passed=true`, explanatory `notes`, and at least one bound capture. Captures use the same file/SHA reference shape and must occur in that raw case's `captures` list. Their paths resolve from the review directory; absolute retained paths avoid ambiguity.
- Each raw case has the same `id`, `automated_checks_passed=true`, empty `failures`, and nonempty `observations`. Save/load cases also list `checkpoint_saves` file/SHA references to actual mid-state saves.

The finalizer verifies coverage and immutable evidence. Human interpretation of those native observations remains explicit in the signed-off review; the finalizer cannot infer freeze behavior or image quality from a Boolean. The installed [lifecycle](lifecycle-fixture/README.md) and [consumer](consumer-fixture/README.md) fixtures produce the reports for [LIFECYCLE-AND-INTEGRATION.md](LIFECYCLE-AND-INTEGRATION.md); their final native runs and reviews remain pending.

Lifecycle inventory: each of `save_load`, `ammo_shortage`, `energy_shortage`, `script_disable`, `circuit_disable`, and `freeze_thaw` at each of `preparing`, `running`, and `folding` — 18 cases, IDs such as `save_load/preparing`. The case itself must include recovery/reacquisition, not only the interruption event.

Visual inventory: for each of `sd` and `hd`, review `native_load`, `state_transitions`, `combined_shadow`, `item_recipe_icon`, and `technology_icon`; additionally `hd_selection/enabled`, `hd_selection/disabled`, and `mechanics/unchanged` — 13 cases. Connector relocation is user-owned and is not an acceptance case. Preserve the existing connector.

`mechanics/unchanged` must bind the complete eight-configuration pre-final main consumer aggregate: absent/disabled/enabled/incompatible HD, each with Ballistic Divergence off and on. Its six successful native reports provide separate approved combat baselines for the two doctrines; the two incompatible cases must reject as expected. The finalizer checks equal mechanics across SD/HD scenarios within each doctrine, retains both snapshots and all source references as `consumer_combat_baselines`, and binds them into its receipt and generated provenance. Final consumer checks compare untouched shipping mechanics to these baselines. Artwork, measured launch fields and state timing have separate checks; user-owned `circuit_connector` is excluded.

## Outputs and remaining gates

A successful invocation writes `graphics-data.lua`, `graphics-data.json`, `hd-example-graphics-data.lua`, a new `artifact-map.json`, and `finalization-receipt.json`. The artifact map retains all original PNG byte hashes and updates the unloaded HD example support artifact to the calibrated bytes. The receipt binds all final output hashes, native evidence, validators, and the effective mechanical fields. The HD example has only `profiles.hd`; explicitly selected G6 shadow references remain intact.

These outputs permit the next scoped integration checks; they are not release approval. Follow this order:

1. Install the reviewed main consumer changes, exact finalized main metadata, mapped G6/HD PNGs and calibrated unloaded HD example together. Run `audit_shipping.py` without `--archives` to verify actual installed destinations, not just source overlays.
2. Run the finalized main consumer matrix and independent base + HD example checks. Keep the original draft `-ArtifactMap` bound to the firing manifest and pass finalizer output separately as `-Finalized`; do not substitute the final map for that draft input.
3. Build fresh complete archives using the **finalizer's** artifact map, then audit those ZIPs against every actual installed pack file, including license, README, metadata and unloaded example support files.

```powershell
python -B .codex/esir/asset-generators/minigun-turret/audit_shipping.py `
  --repo . --finalized output/minigun-implementation/finalized-minigun

# After the finalized consumer checks above:
python -B .codex/esir/asset-generators/minigun-turret/measure_packages.py `
  --repo . --artifact-map output/minigun-implementation/finalized-minigun/artifact-map.json `
  --output output/minigun-implementation/final-exact-packages-001

python -B .codex/esir/asset-generators/minigun-turret/audit_shipping.py `
  --repo . --finalized output/minigun-implementation/finalized-minigun `
  --archives output/minigun-implementation/final-exact-packages-001
```

The auditor is read-only. It binds the finalizer receipt, main metadata, exact PNG/support destinations and complete pack inventory; with `--archives` it also checks ZIP integrity, complete membership and entry hashes against installed files. An overlay-based package measurement alone cannot prove that shipping destinations were installed. Each complete archive must be strictly below **256,000,000 bytes**; a 240,000,000-byte warning is informational. Pre-native budget archives and metadata allowances cannot replace these final exact archives. Re-run measurement and audit after archive content changes. None of these tools publishes, deploys or grants release approval.
