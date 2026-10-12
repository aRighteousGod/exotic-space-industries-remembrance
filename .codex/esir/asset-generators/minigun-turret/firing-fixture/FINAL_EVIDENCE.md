# Final firing evidence handoff

Staging only. These files strengthen offline evidence checks and never start Factorio. No final native acceptance is asserted here. The parent owns installation, the compact heading-control review branch, and all serial native runs.

## Files and integration

- `evidence_contract.py`: fixed case inventory, evidence hashes, actual launch-coordinate comparison, referenced PNG inventory, immutable capture and candidate-asset retention.
- `analyze_fixture.py`: analyzer with the contract and retention hooks. The parent has integrated the compact-control validation branch; its independent controls and actual image identities are checked by `compact_flash_evidence.py`.
- `summarize_matrix.py`: schema 2 aggregate requiring the four distinct full SD/HD × doctrine off/on results, their actual files and explicit current candidate pins.
- `test_evidence_contract.py`: offline rejection and storage tests. Test artifacts are marked as unit tests and are not native evidence.

The fixed final inventory is 256 piercing directions, eight directions for each of the other ten ammunition routes, and one moving case: 336 static plus one moving, with 74,430 benchmark ticks. Pilot calibration is exactly eight static piercing cases, no moving case, and 1,850 ticks. The ordinary all-ammunition pilot is 88 static plus one moving and 19,870 ticks.

The builder must call `build_candidate_asset_manifest(candidate_data_path, candidate_root)` after copying the actual candidate files, write its returned object to `candidate-assets-manifest.json`, and set `config.assets_manifest_sha256` to the SHA256 of that exact JSON file. `candidate_root` is the helper's `candidate/` directory. The inventory includes the complete referenced SD/HD union even when only one profile is enabled. References must use `__zzz-esir-minigun-firing__/candidate/`; paths, encoded bytes, PNG dimensions, and the 4096-pixel maximum are checked. `verify_candidate_asset_manifest(manifest, candidate_data_path, candidate_root)` rebuilds and compares the exact inventory.

The analyzer retains eight bound inputs: native report, fixture plan, muzzle anchors, candidate graphics Lua, mechanical Lua, candidate asset manifest, visual review, and capture manifest. It also retains the actual referenced atlas PNGs under `candidate/`. A final matrix rehashes those inputs, atlas bytes, and every recorded screenshot; a filename-only candidate hash is insufficient.

## Retention and invocation

Use the analyzer's explicit `--capture-storage hardlink` when raw and retained roots share a volume. It verifies source and destination bytes, preserves both paths, refuses different existing bytes, and does not silently fall back to copying. Candidate PNGs use the same retention mode. Existing historical captures are untouched. Hardlinks are immutable evidence aliases: do not overwrite either alias in place after a run.

The matrix command requires four fresh complete retained directories and these explicit lowercase SHA256 arguments. Supply absolute directory paths so that the final metadata finalizer can reproduce the report independently of the working directory:

```text
python -B summarize_matrix.py SD_OFF SD_ON HD_OFF HD_ON
  --expected-candidate-sha256 SHA
  --expected-mechanical-sha256 SHA
  --expected-anchors-sha256 SHA
  --expected-assets-manifest-sha256 SHA
  --output NEW_MATRIX_REPORT.json
```

The matrix reports `all_four_firing_configurations_passed`, exact input hashes, and configuration hashes. It always leaves `production_approved=false`: firing acceptance does not replace final timing, lifecycle, color, shadow, package, or mechanical gates. SD/HD must have equal actual center-relative launch coordinates and matching attack definitions. Doctrine on/off must retain the same static origins and muzzle fields; their ammunition/effect payload graphs may legitimately differ.

## Verification and storage limits

Twelve offline tests pass, including stale/missing/switched evidence, incomplete coverage, duplicate variants, changed PNGs under unchanged Lua filenames, nonfinite/missing launch observations, and hardlink identity. Python AST parsing passes. The fixed inventory was also checked against the real previously accepted eight-case pilot without rewriting its evidence or verdict. No engine was started.

The parent has added moving screenshot deduplication at the native tick boundary: every shot event remains recorded, and same-tick shots explicitly share the same rendered capture. Its conservative maximum is 1,044 moving screenshots (four variants × 261 ticks). The parent also owns nine-cell compact heading controls, captured only at offsets -1, 0, and 1. Do not use the original 50-cell heading-control layout for all 336 final static cases.

Run configurations serially and measure the first actual full run before reserving later runs. Keep raw and retained screenshot paths as verified hardlinks, and likewise retain candidate atlas bytes without a second physical copy. Logical directory sizes are not allocated disk use. No existing evidence cleanup is performed by this handoff; a separate read-only duplicate inventory is reported to the parent. Actual remaining disk capacity must cover source rendering, compilation, the next native run, and a working reserve.
