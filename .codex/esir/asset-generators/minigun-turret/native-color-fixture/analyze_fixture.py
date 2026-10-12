"""Compare registered native separated/reference screenshots without a fit."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil

import numpy as np
from PIL import Image
from capture_geometry import METHOD, UNITS, inspect as inspect_geometry, finish as finish_geometry


def analyze(run, output):
    report = json.loads((run / "script-output/minigun-native-color-report.json").read_text(encoding="utf-8-sig"))
    inputs = json.loads((run / "mods/zzz-esir-minigun-color/color-input-manifest.json").read_text(encoding="utf-8-sig"))
    graphics_log = (run / "graphics.log").read_text(encoding="utf-8-sig", errors="replace")
    compression = re.search(r"\[DXT: ([^\]]+)\]", graphics_log)
    actual_compression = compression.group(1) if compression else None
    requested_compression = inputs["texture_compression"]
    texture_policy = inputs.get("color_texture_policy", "native-default")
    output.mkdir(parents=True, exist_ok=True)
    failures = list(report["errors"])
    selected_profiles = inputs.get("selected_profiles", ["sd", "hd"])
    reference_selection = inputs.get("reference_selection", "full")
    reference_rows = inputs.get("reference_cells", [])
    reference_rows_hash = hashlib.sha256(json.dumps(reference_rows, sort_keys=True).encode()).hexdigest()
    expected_reference_cells = {(case["profile"], case["direction"], case["pose"])
                                for case in inputs["cases"]}
    actual_reference_cells = [(row["profile"], row["direction"], row["pose"]) for row in reference_rows]
    reference_selection_verified = (reference_selection == "full" or
        (reference_selection == "cells" and len(actual_reference_cells) == len(expected_reference_cells)
         and set(actual_reference_cells) == expected_reference_cells
         and inputs.get("reference_cells_sha256") == reference_rows_hash))
    helper_root = run / "mods/zzz-esir-minigun-color"
    staged_files_verified = True
    for source in inputs["files"]:
        staged = (helper_root / source["path"]).resolve()
        if (not staged.is_relative_to(helper_root.resolve()) or not staged.is_file()
                or hashlib.sha256(staged.read_bytes()).hexdigest() != source["sha256"]):
            staged_files_verified = False
            failures.append("Staged source image changed or is missing: " + source["path"])
    reference_selection_verified = reference_selection_verified and staged_files_verified
    if not reference_selection_verified:
        failures.append("Reference source-cell selection is incomplete or its manifest hash changed")
    if report.get("capture_geometry") != METHOD or inputs.get("capture_geometry") != METHOD:
        failures.append("Capture geometry predates the actual-position camera contract")
    if report.get("offset_units") != UNITS or inputs.get("offset_units") != UNITS:
        failures.append("Capture geometry does not declare engine-native pixel units")
    if actual_compression != requested_compression:
        failures.append(f"Requested texture compression {requested_compression!r}, engine reported {actual_compression!r}")
    atlas_flags = [sorted({flag.strip() for flag in match.split(",") if flag.strip()})
                   for match in re.findall(r"Created an atlas bitmap[^\r\n]*\[([^\]]+)\]", graphics_log)]
    required_flags = {"not-compressed"}
    color_atlas_flags = [flags for flags in atlas_flags
                        if required_flags.issubset(flags) and set(flags) <= required_flags | {"object"}]
    color_leaves = report.get("color_leaf_flags", [])
    leaf_flags_verified = (bool(color_leaves) and len(color_leaves) == inputs.get("expected_color_leaf_count")
        and all(set(leaf.get("flags", [])) == required_flags for leaf in color_leaves)
        and all(leaf.get("owner", "").startswith(("mg-color-sd-", "mg-color-hd-")) for leaf in color_leaves))
    native_color_flags_verified = (texture_policy == "not-compressed"
        and set(inputs.get("color_texture_flags") or []) == required_flags
        and bool(color_atlas_flags) and leaf_flags_verified)
    if texture_policy == "not-compressed" and not native_color_flags_verified:
        failures.append("Color sprites lack the tested lossless texture flags with native default sampling")
    rows = {case["id"]: case for case in report["cases"]}
    captures = {}
    for capture in report["captures"]:
        key = capture["case_id"], capture["variant"]
        if key in captures:
            failures.append("Duplicate screenshot record: " + str(key))
        captures[key] = capture
    results, geometry_groups = [], {}
    for case_id, case in rows.items():
        pair = [captures.get((case_id, variant)) for variant in ("separated", "reference")]
        if any(item is None for item in pair):
            failures.append("Incomplete comparison pair: " + case_id)
            continue
        if pair[0].get("orientation") != pair[1].get("orientation"):
            failures.append("Pair orientations differ: " + case_id)
        if reference_selection == "cells" and not case.get("background_only"):
            expected_names = [f"mg-color-{case['profile']}-separated-{case['pose']}",
                              f"mg-color-{case['profile']}-reference-{case['pose']}-d{case['direction']}"]
            if [item.get("prototype_name") for item in pair] != expected_names:
                failures.append("Native reference did not use the declared exact source cell: " + case_id)
                reference_selection_verified = False
        arrays, hashes = [], {}
        for variant, item in zip(("separated", "reference"), pair):
            path = run / "script-output" / item["path"]
            payload = path.read_bytes()
            hashes[variant] = hashlib.sha256(payload).hexdigest()
            with Image.open(path) as image:
                arrays.append(np.asarray(image.convert("RGB"), dtype=np.int16))
        if arrays[0].shape != arrays[1].shape or list(reversed(arrays[0].shape[:2])) != case["resolution"]:
            failures.append("Different screenshot bounds: " + case_id)
            continue
        failures.extend(inspect_geometry(case, pair, arrays[1], geometry_groups, report["matrix"]))
        # Both pictures use the identical native camera/world position. No
        # automatic registration, resampling or least-squares fit is allowed.
        difference = np.abs(arrays[0]-arrays[1])
        pixel_error = np.max(difference, axis=2)
        maximum = int(difference.max())
        rms = float(np.sqrt(np.mean(difference.astype(np.float64)**2)))
        changed = pixel_error > 0
        outside_allowance = pixel_error > report["rgb_max_allowance"]
        counts = {str(level): int(np.count_nonzero(pixel_error > level)) for level in (0, 1, 2, 8, 32, 64)}
        border = np.concatenate((pixel_error[:2].reshape(-1), pixel_error[-2:].reshape(-1),
                                 pixel_error[:, :2].reshape(-1), pixel_error[:, -2:].reshape(-1)))
        reference_border = np.concatenate((arrays[1][:2].reshape(-1, 3), arrays[1][-2:].reshape(-1, 3),
                                           arrays[1][:, :2].reshape(-1, 3), arrays[1][:, -2:].reshape(-1, 3)))
        background_rgb = np.median(reference_border, axis=0)
        reference_border_deviation = int(np.max(np.abs(reference_border-background_rgb)))
        foreground_pixels = int(np.count_nonzero(np.max(np.abs(arrays[1]-background_rgb), axis=2) > 4))
        passed = maximum <= report["rgb_max_allowance"] and rms <= report["rgb_rms_allowance"] and int(border.max()) == 0 and reference_border_deviation <= 1
        if case.get("background_only"):
            passed = maximum == 0
        elif foreground_pixels < max(16, 8 * case["zoom"]**2):
            passed = False
            failures.append("Reference sprite is absent or too small to validate: " + case_id)
        if not passed:
            failures.append("Native color comparison exceeds allowance: " + case_id)
        error_path = None
        if changed.any():
            target = output / "differences" / (case_id + ".png")
            target.parent.mkdir(exist_ok=True)
            heat = np.zeros((*pixel_error.shape, 3), dtype=np.uint8)
            heat[:, :, 0] = np.minimum(pixel_error * 8, 255)
            heat[:, :, 1] = np.where(outside_allowance, 0, np.minimum(pixel_error * 32, 255))
            Image.fromarray(heat).save(target, optimize=True)
            error_path = target.relative_to(output).as_posix()
        results.append({**case, "passed": passed, "maximum_rgb_error": maximum,
                        "rms_rgb_error": rms, "pixels_above_error": counts,
                        "registration_border_error": int(border.max()), "heatmap": error_path,
                        "reference_foreground_pixels": foreground_pixels,
                        "reference_border_deviation": reference_border_deviation,
                        "screenshots_sha256": hashes,
                        "orientations": [item.get("orientation") for item in pair]})
    expected = inputs["comparison_cases"] + len(inputs["controls"])
    if len(results) != expected or len(captures) != expected * 2:
        failures.append("Native screenshot matrix is incomplete")
    geometry, geometry_failures = finish_geometry(geometry_groups, report["matrix"])
    failures.extend(geometry_failures)
    geometry["passed"] = geometry["passed"] and not any("geometry" in failure or "registration" in failure for failure in failures)
    summary = {"schema": 1, "matrix": report["matrix"], "run": str(run),
               "source_direction_count": inputs.get("source_direction_count", 8),
               "selected_profiles": selected_profiles, "reference_selection": reference_selection,
               "reference_selection_verified": reference_selection_verified,
               "staged_files_verified": staged_files_verified,
               "reference_cells_sha256": reference_rows_hash,
               "input_manifest_sha256": hashlib.sha256((run / "mods/zzz-esir-minigun-color/color-input-manifest.json").read_bytes()).hexdigest(),
               "tested_direction_indices": inputs.get("tested_direction_indices", sorted(set(case["direction"] for case in inputs["cases"]))),
               "compiled_metadata_sha256": inputs["metadata_sha256"],
               "capture_geometry": geometry,
               "offset_units": UNITS,
               "automated_checks_passed": not failures, "failures": failures,
               "texture_compression_requested": requested_compression,
               "texture_compression_observed": actual_compression,
               "mathematical_composition_gate": actual_compression == "none" or native_color_flags_verified,
               "color_texture_policy": texture_policy,
               "color_texture_flags": inputs.get("color_texture_flags"),
               "native_color_flags_verified": native_color_flags_verified,
               "observed_atlas_flags": atlas_flags,
               "matched_color_atlas_flags": color_atlas_flags,
               "color_leaf_flag_count": len(color_leaves),
               "color_leaf_flags_verified": leaf_flags_verified,
               "compression_policy": "Selected per-sprite flags preserve color composition under the engine texture mode; automatic cropping remains enabled",
               "comparison_pairs": len(results), "expected_comparison_pairs": expected,
               "maximum_rgb_error": max((row["maximum_rgb_error"] for row in results), default=None),
               "maximum_case_rms_rgb_error": max((row["rms_rgb_error"] for row in results), default=None),
               "rgb_max_allowance": report["rgb_max_allowance"], "rgb_rms_allowance": report["rgb_rms_allowance"],
               "allowance_reason": "At most one 8-bit code value for composition rounding; no alpha-hole allowance",
               "cases": results, "shadows_included": False,
               "review_required": ["Inspect failed and worst-case native pairs/heatmaps for ownership seams or halos",
                   "Run high-quality compression separately after the none-compression mathematical gate",
                   "Validate the combined full-union shadow family separately; this fixture compares Object color only"],
               "production_approved": False,
               "analyzer_sha256": hashlib.sha256(Path(__file__).read_bytes()).hexdigest()}
    (output / "summary.json").write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")
    for name, value in (("native-report.json", report), ("color-input-manifest.json", inputs)):
        (output / name).write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8")
    shutil.copyfile(__file__, output / "analyzer-source.py")
    shutil.copyfile(Path(__file__).with_name("capture_geometry.py"), output / "capture_geometry.py")
    shutil.copytree(run / "script-output/minigun-native-color", output / "screenshots", dirs_exist_ok=True)
    return summary


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--run", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    result = analyze(args.run, args.output)
    print(json.dumps({key: result[key] for key in ("automated_checks_passed", "failures", "maximum_rgb_error",
                                                 "texture_compression_observed", "production_approved")}))
    raise SystemExit(0 if result["automated_checks_passed"] else 2)
