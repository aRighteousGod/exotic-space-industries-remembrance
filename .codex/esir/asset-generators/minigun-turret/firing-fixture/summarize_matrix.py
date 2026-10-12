"""Hash-bound four-configuration firing acceptance; never starts an engine."""
import argparse
import json
import math
from pathlib import Path

from evidence_contract import (bound_files, SOURCE, canonical_sha, capture_names,
                               capture_path, compare_launches, fs_path, sha, summary_failures,
                               verify_candidate_asset_manifest, projectile_requirements, ammunition_accounting)
from analyze_fixture import heading_review, moving_evidence


def read(path):
    return json.loads(fs_path(path).read_text(encoding="utf-8-sig"))


def load_bundle(directory):
    root = fs_path(directory)
    summary, native = read(root / "summary.json"), read(root / "native-report.json")
    plan, anchors = read(root / "fixture-plan.json"), read(root / "muzzle-anchors.json")
    hashes = {filename: sha(root / filename) for filename in bound_files(native["config"]).values()}
    errors = summary_failures(summary, native, plan, anchors, hashes)
    verify_candidate_asset_manifest(read(root / "candidate-assets-manifest.json"),
                                    root / "candidate-graphics-data.lua", root / "candidate")
    if (summary.get("coverage") != "full" or summary.get("calibration_only") is not False
            or summary.get("status") != "passed" or summary.get("automated_checks_passed") is not True
            or summary.get("alignment_gate_passed") is not True
            or summary.get("failures") != [] or summary.get("pending_review") != []):
        errors.append("Full image-backed alignment gate is not passed")
    tolerance = summary.get("tolerance_native_pixels")
    if type(tolerance) not in (int, float) or not math.isfinite(tolerance) or not 0 < tolerance <= 2:
        errors.append("The current two-native-pixel maximum is not enforced")
    review = read(root / "visual-review.json")
    for field in ("profile", "ballistic", "source_sha256", "candidate_data_sha256", "mechanical_data_sha256"):
        if review.get(field) != native["config"].get(field):
            errors.append("Visual review/native " + field + " differs")
    if review.get("native_report_sha256") != hashes["native-report.json"] or review.get("height_compensation_verified") is not True:
        errors.append("Native report/height review binding differs")
    if native["config"].get("heading_templates"):
        problem = heading_review(review.get("heading_template_calibration"), root / "native-report.json",
                                 native, root, root / "heading-measurements.json")
        if problem:
            errors.append(problem)
    manifest = read(root / "capture-manifest.json")
    expected = capture_names(native)
    files = manifest.get("files", {})
    if (manifest.get("schema") != "esir.minigun.firing-captures.v1"
            or set(files) != expected or manifest.get("native_report_capture_count") != len(expected)):
        errors.append("Native capture manifest is not the exact recorded screenshot set")
    if summary.get("evidence", {}).get("capture_count") != len(expected):
        errors.append("Summary/native capture count differs")
    for name, record in files.items():
        path = capture_path(root, name)
        if sha(path) != record.get("sha256") or path.stat().st_size != record.get("bytes"):
            errors.append("Changed native screenshot: " + name)
    if manifest.get("logical_png_bytes") != sum(row["bytes"] for row in files.values()):
        errors.append("Capture byte inventory differs")
    native_cases = {case["id"]: case for case in native["cases"]}
    requirements = {}
    for case in native["cases"]:
        for row in case["rows"]:
            try:
                requirements[case["id"], row["variant"]] = projectile_requirements(native["prototype_audit"], case, row)
                ammunition_accounting(native["prototype_audit"], case, row)
            except (ValueError, KeyError, TypeError) as error:
                errors.append(case["id"] + ": " + row["variant"] + ": " + str(error))
    for case in summary.get("cases", []):
        actual = native_cases.get(case["id"])
        if not actual:
            continue
        row = next(row for row in actual["rows"] if row["variant"] == "native")
        captures = {cap["shot_offset"]: cap for cap in row["captures"]}
        for visual in ("flash", "projectile"):
            observed = case.get(visual, {})
            if visual == "projectile" and not any(requirements.get((case["id"], "native"), [True])):
                if observed.get("status") != "not_applicable_native_instant_delivery":
                    errors.append(case["id"] + ": instant delivery is not explicitly classified")
                continue
            annotation = review.get("cases", {}).get(case["id"], {}).get(visual, {})
            capture = captures.get(observed.get("first_visible_offset"), {})
            name = capture.get("path")
            point = annotation.get("origin_pixels")
            if (not capture or observed.get("first_visible_offset") not in (0, 1, 2, 3)
                    or annotation.get("capture") != name or annotation.get("native_visibility_confirmed") is not True
                    or annotation.get("sha256") != files.get(name, {}).get("sha256")
                    or observed.get("reviewed_capture_sha256") != annotation.get("sha256")
                    or observed.get("observed_origin_pixels") != point
                    or not isinstance(point, list) or len(point) != 2
                    or any(type(value) not in (int, float) or not math.isfinite(value) for value in point)
                    or type(capture.get("zoom")) not in (int, float) or not math.isfinite(capture["zoom"]) or capture["zoom"] <= 0
                    or math.dist(point, [160, 160]) / capture["zoom"] > tolerance):
                errors.append(case["id"] + ": unbound/unpassed real native " + visual + " origin")
            if visual == "flash":
                reviewed = annotation.get("reviewed_captures", [])
                offsets = [item.get("shot_offset") for item in reviewed]
                if (annotation.get("first_appearance_and_decay_reviewed") is not True
                        or len(offsets) != len(set(offsets)) or not {-1, 0, 1, 2, 3, 12, 96}.issubset(offsets)):
                    errors.append(case["id"] + ": incomplete visual flash sequence review")
                for item in reviewed:
                    wanted = captures.get(item.get("shot_offset"), {}).get("path")
                    if item.get("capture") != wanted or item.get("sha256") != files.get(wanted, {}).get("sha256"):
                        errors.append(case["id"] + ": changed visual flash sequence capture")
    geometry = {row["direction"]: row for row in anchors["visual_anchors"]}
    moving = []
    for case in native["cases"]:
        if case["spec"]["kind"] != "moving":
            continue
        try:
            measured, failures, pending = moving_evidence(case, geometry, root, review, tolerance, native["prototype_audit"])
            moving.append(measured)
            errors.extend(case["id"] + ": " + problem for problem in failures + pending)
        except (ValueError, KeyError, TypeError, OSError) as error:
            errors.append(case["id"] + ": invalid moving native evidence: " + str(error))
    if moving != summary.get("moving"):
        errors.append("Saved moving summary differs from actual decoded native captures")
    return summary, native, hashes, errors


def summarize(directories, *, expected_candidate_sha256, expected_mechanical_sha256,
              expected_anchors_sha256, expected_assets_manifest_sha256):
    failures, configurations = [], {}
    expected_lineage = {"candidate-graphics-data.lua": expected_candidate_sha256,
                        "candidate-mechanical-data.lua": expected_mechanical_sha256,
                        "candidate-assets-manifest.json": expected_assets_manifest_sha256,
                        "muzzle-anchors.json": expected_anchors_sha256}
    if any(not isinstance(value, str) or len(value) != 64 or any(c not in "0123456789abcdef" for c in value)
           for value in expected_lineage.values()):
        failures.append("Explicit lowercase SHA256 pins for current candidate, asset manifest, mechanical data and anchors are required")
    if len(directories) != 4:
        failures.append("Exactly four retained evidence directories are required")
    for directory in directories:
        try:
            summary, native, hashes, errors = load_bundle(directory)
            key = (native["config"]["profile"], native["config"]["ballistic"])
            if key in configurations:
                failures.append("Duplicate configuration " + repr(key))
            configurations[key] = (summary, native, str(directory), hashes)
            failures.extend(repr(key) + ": " + error for error in errors)
            for name, expected in expected_lineage.items():
                if hashes.get(name) != expected:
                    failures.append(repr(key) + ": evidence is not the explicitly pinned current " + name)
        except (OSError, ValueError, TypeError, KeyError, StopIteration) as error:
            failures.append(str(directory) + ": missing/invalid evidence: " + str(error))
    if set(configurations) != {(profile, mode) for profile in ("sd", "hd") for mode in (False, True)}:
        failures.append("Exactly SD/HD by doctrine off/on is required")
    for mode in (False, True):
        if ("sd", mode) not in configurations or ("hd", mode) not in configurations:
            continue
        sd, hd = configurations["sd", mode][1], configurations["hd", mode][1]
        for field in ("effective_attack", "collision_box", "selection_box"):
            if sd["prototype_audit"].get(field) != hd["prototype_audit"].get(field):
                failures.append(f"SD/HD native prototype {field} differs for doctrine={mode}")
        try:
            if not compare_launches(sd, hd):
                failures.append(f"SD/HD native launch coordinates differ for doctrine={mode}")
        except (ValueError, KeyError, TypeError) as error:
            failures.append(str(error))
    for profile in ("sd", "hd"):
        if (profile, False) not in configurations or (profile, True) not in configurations:
            continue
        off, on = configurations[profile, False][1], configurations[profile, True][1]
        # Delivery graphs legitimately differ by doctrine. Compare the fixed
        # physical muzzle map and actual static origins, not all ammo/effect data.
        for field in ("projectile_creation_parameters", "projectile_center", "apply_projection_to_projectile_creation_position"):
            if off["prototype_audit"]["effective_attack"].get(field) != on["prototype_audit"]["effective_attack"].get(field):
                failures.append(f"Doctrine changes native launch field {field} for profile={profile}")
        try:
            if not compare_launches(off, on, static_only=True):
                failures.append(f"Doctrine off/on static native origins differ for profile={profile}")
        except (ValueError, KeyError, TypeError) as error:
            failures.append(str(error))
    return {"schema": 2, "all_four_firing_configurations_passed": not failures,
            "source_sha256": SOURCE, "expected_lineage": expected_lineage, "failures": failures,
            "configurations": [{"profile": key[0], "ballistic": key[1], "directory": value[2],
                                "summary_sha256": sha(Path(value[2]) / "summary.json"),
                                "native_report_sha256": value[3]["native-report.json"],
                                "configuration_sha256": canonical_sha(value[1]["config"]),
                                "bound_files": value[3]} for key, value in configurations.items()],
            "production_approved": False,
            "note": "Firing acceptance does not replace timing, assets, package or mechanical production gates"}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directories", nargs=4, type=Path)
    parser.add_argument("--expected-candidate-sha256", required=True)
    parser.add_argument("--expected-mechanical-sha256", required=True)
    parser.add_argument("--expected-anchors-sha256", required=True)
    parser.add_argument("--expected-assets-manifest-sha256", required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    result = summarize(args.directories, expected_candidate_sha256=args.expected_candidate_sha256,
                       expected_mechanical_sha256=args.expected_mechanical_sha256,
                       expected_assets_manifest_sha256=args.expected_assets_manifest_sha256,
                       expected_anchors_sha256=args.expected_anchors_sha256)
    fs_path(args.output).parent.mkdir(parents=True, exist_ok=True)
    fs_path(args.output).write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(result, indent=2))
    raise SystemExit(0 if result["all_four_firing_configurations_passed"] else 2)
