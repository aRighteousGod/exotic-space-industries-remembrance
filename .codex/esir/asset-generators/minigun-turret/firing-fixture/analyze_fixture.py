"""Analyze actual native firing images. Coordinates alone never pass this gate."""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import os
from pathlib import Path
import shutil

import numpy as np
from PIL import Image, ImageDraw

from evidence_contract import (canonical_sha, coverage_failures, authored_cases_equal, retain_captures,
                               retain_candidate_assets, verify_candidate_asset_manifest,
                               projectile_requirements, ammunition_accounting)
from compact_flash_evidence import compact_control_problem

OFFSETS = list(range(13)) + [16, 24, 32, 48, 64, 96]
VARIANTS = ("native", "flash", "projectile", "blank")


def fs_path(path):
    """Use the Win32 extended namespace only at filesystem access boundaries."""
    path=Path(path)
    if os.name!="nt":return path
    absolute=os.path.abspath(path)
    if absolute.startswith("\\\\?\\"):return Path(absolute)
    if absolute.startswith("\\\\"):return Path("\\\\?\\UNC\\"+absolute[2:])
    return Path("\\\\?\\"+absolute)


def sha(path):
    return hashlib.sha256(fs_path(path).read_bytes()).hexdigest()


def rgb(path):
    with Image.open(fs_path(path)) as image:
        return np.asarray(image.convert("RGB"), dtype=np.float32)


def decode_direction(path, capture):
    image = rgb(path)
    zoom = capture["zoom"]
    cx, cy = capture["entity_center"]
    cy += capture["marker_shift_tiles"][1] * 32 * zoom
    values, interiors = [], []
    for cell in range(18):
        x = round(cx + (cell * 4 + 2 - 36) * zoom)
        y = round(cy)
        # Interior of the 4x12-source-pixel cell: 6x16 native capture pixels at
        # zoom2. A small crossing shell particle cannot dominate the old4x4 crop.
        rx, ry = max(1, round(1.5*zoom)), max(1, round(4*zoom))
        if y-ry < 0 or x-rx < 0 or y+ry > image.shape[0] or x+rx > image.shape[1]:
            raise ValueError("Direction marker interior is outside the native capture")
        interior = image[y-ry:y+ry, x-rx:x+rx]
        interiors.append(interior)
        values.append(np.median(interior, axis=(0, 1)))
    # A physical tracer can cross a sentinel. Require actual sentinel-colored
    # pixels in at least one quarter of its interior, never infer a missing color.
    for interior, color in ((interiors[0], [255, 0, 255]), (interiors[-1], [0, 255, 255])):
        if np.count_nonzero(np.max(abs(interior-color), axis=2) <= 30) < math.ceil(interior.shape[0]*interior.shape[1]/4):
            raise ValueError("Direction marker sentinels are not visible")
    bits = [int(float(np.mean(value)) > 125) for value in values[1:-1]]
    if any(bits[i] + bits[i+8] != 1 for i in range(8)):
        raise ValueError("Direction marker complement check failed")
    return sum(bits[i] << i for i in range(8))


def contrast(variant, blank, variant_before, blank_before):
    difference = (variant - blank) - (variant_before - blank_before)
    mask = np.max(abs(difference), axis=2) >= 24
    y, x = np.nonzero(mask)
    return {"pixels": len(x), "bbox": [int(x.min()), int(y.min()), int(x.max()+1), int(y.max()+1)] if len(x) else None,
            "energy": float(np.maximum(difference, 0).sum()),
            "nearest_anchor_pixels": float(np.hypot(x-160, y-160).min()) if len(x) else None}, mask


def image_review(entry, capture, root, expected, tolerance):
    if not isinstance(entry, dict):
        return "image-backed origin review missing"
    path = root / capture["path"]
    if entry.get("capture") != capture["path"] or entry.get("sha256") != sha(path):
        return "review does not bind to the current native image bytes"
    if entry.get("native_visibility_confirmed") is not True:
        return "native visual identity was not confirmed"
    point = entry.get("origin_pixels")
    if not isinstance(point, list) or len(point) != 2 or not all(isinstance(x, (int, float)) and math.isfinite(x) for x in point):
        return "visual origin point missing"
    error = math.dist(point, expected) / capture["zoom"]
    if error > tolerance:
        return f"native visual origin misses the proposed muzzle by {error:.3f} native pixels"
    return None


def heading_review(entry, report_path, report, raw, measurement_path=None):
    """Bind reviewed native template shapes to their independent pixel controls."""
    if not isinstance(entry, dict) or entry.get("native_shapes_and_origins_confirmed") is not True:
        return "Heading-specific template origin/shape calibration requires native image review"
    path = fs_path(measurement_path if measurement_path is not None else entry.get("measurement_report", ""))
    if not path.is_file() or entry.get("measurement_sha256") != sha(path):
        return "Heading-template measurement report is missing or changed"
    measured = json.loads(path.read_text(encoding="utf-8-sig"))
    if (measured.get("native_report_sha256") != sha(report_path)
            or measured.get("candidate_data_sha256") != report["config"]["candidate_data_sha256"]
            or measured.get("held_out_controls_passed") is not True):
        return "Heading-template controls do not bind to this native run"
    cases = {case["id"] for case in report["cases"] if case["spec"]["kind"] == "static"}
    expected = {(case, variant, offset) for case in cases for variant in ("native", "flash") for offset in (0, 1)}
    actual = [(row["case"], row["variant"], row["shot_offset"]) for row in measured.get("results", [])]
    if len(actual) != len(expected) or set(actual) != expected:
        return "Heading-template image measurements are incomplete"
    expected_captures = set()
    cardinal_cases = set()
    for case in report["cases"]:
        if case["spec"]["kind"] != "static":
            continue
        if case["spec"]["requested_rendered_direction"] % 64 == 0:
            cardinal_cases.add(case["id"])
        for row in case["rows"]:
            if row["variant"] in ("native", "flash", "blank"):
                expected_captures.update(cap["path"] for cap in row["captures"] if cap["shot_offset"] in (-1, 0, 1))
        for variant in ("native", "flash"):
            expected_captures.update(cap["path"] for cap in report["heading_flash_templates"][case["id"] + "-" + variant]["captures"]
                                     if cap["shot_offset"] in (-1, 0, 1))
    controls = measured.get("held_out_controls", [])
    expected_controls = {(case, variant, offset) for case in cardinal_cases for variant in ("native", "flash") for offset in (0, 1)}
    if report["config"].get("compact_heading_templates"):
        problem = compact_control_problem(measured, report)
        if problem:
            return problem
    elif (len(controls) != len(expected_controls)
            or {(row["case"], row["variant"], row["shot_offset"]) for row in controls} != expected_controls
            or any(row.get("origin_pixels") != [128, 128] or row.get("known_origin") != [128, 128]
                   or row.get("control_registration_passed") is not True
                   or not 0 <= row.get("relative_sse", float("inf")) < .001 for row in controls)):
        return "Independent heading-template control registrations are incomplete or failed"
    if set(measured.get("source_capture_sha256", {})) != expected_captures or any(
            not (raw / name).is_file() or sha(raw / name) != value
            for name, value in measured["source_capture_sha256"].items()):
        return "Heading-template source pixels changed"
    if sorted(entry.get("reviewed_cases", [])) != sorted(cases):
        return "Heading-template visual review does not cover these cases"
    return None


def moving_evidence(case, geometry, raw, review, tolerance, audit):
    """Re-read native headings and bind first/sustained origin reviews at every gate."""
    failures, pending, decoded = [], [], []
    ammunition = {row["variant"]:ammunition_accounting(audit, case, row) for row in case["rows"]}
    row = next(row for row in case["rows"] if row["variant"] == "native")
    requirements = projectile_requirements(audit, case, row)
    decoded_captures = {}
    for shot_index, shot in enumerate(row["shots"], 1):
        capture = shot.get("capture")
        if not capture:
            failures.append(f"moving shot {shot_index} lacks an actual native screenshot")
            continue
        if shot.get("phase") != ("first_after_preparation" if shot_index == 1 else "sustained"):
            failures.append(f"moving shot {shot_index} has an invalid first/sustained phase")
        try:
            name = capture["path"]
            if name in decoded_captures:
                previous, direction = decoded_captures[name]
                if capture != previous:
                    raise ValueError("Shared native capture has conflicting projection metadata")
            else:
                direction = decode_direction(raw / name, capture)
                decoded_captures[name] = (capture, direction)
            expected = [capture["entity_center"][axis] + geometry[direction]["visual_offset_tiles"][axis]
                        * 32 * capture["zoom"] for axis in range(2)]
            decoded.append({"shot": shot_index, "direction": direction,
                            "sector": ((direction+16) % 256)//32, "phase": shot["phase"],
                            "source": shot.get("source"), "tick": shot["tick"],
                            "capture": capture, "expected_anchor_pixels": expected})
        except (ValueError, OSError, KeyError, TypeError) as error:
            failures.append(f"moving shot {shot_index}: {error}")
    sectors = sorted({shot["sector"] for shot in decoded if shot["phase"] == "sustained"})
    if sectors != list(range(8)):
        failures.append("Moving-aim burst did not visibly fire through all eight cardinal/diagonal sectors")
    selected = [shot for shot in decoded if shot["shot"] == 1]
    for sector in range(8):
        hits = [shot for shot in decoded if shot["sector"] == sector and shot["phase"] == "sustained"]
        if hits:
            selected.append(hits[len(hits)//2])
    for shot in selected:
        annotation = review.get("moving", {}).get(str(shot["shot"]), {})
        for visual in ("flash", "projectile"):
            if visual == "projectile" and not requirements[shot["shot"]-1]:
                continue
            problem = image_review(annotation.get(visual), shot["capture"], raw,
                                   shot["expected_anchor_pixels"], tolerance)
            if problem:
                pending.append(f"moving shot {shot['shot']} {visual}: {problem}")
    return ({"id": case["id"], "ammunition_accounting":ammunition,
             "decoded_shots": decoded, "sustained_sectors": sectors,
             "selected_review_shots": [shot["shot"] for shot in selected]}, failures, pending)


def late_residual_review(entry, late, before, raw):
    """Keep persistent particles separate from a visually reviewed expired flash."""
    if not isinstance(entry, dict) or entry.get("residual_is_not_muzzle_flash") is not True:
        return False
    if (entry.get("capture") != late["path"] or entry.get("sha256") != sha(raw / late["path"])
            or entry.get("baseline_capture") != before["path"]
            or entry.get("baseline_sha256") != sha(raw / before["path"])
            or not isinstance(entry.get("explanation"), str) or len(entry["explanation"]) < 20):
        return False
    box = entry.get("unchanged_muzzle_region")
    if (not isinstance(box, list) or len(box) != 4 or not all(isinstance(x, int) for x in box)
            or not (0 <= box[0] <= 128 and 0 <= box[1] <= 128
                    and 192 <= box[2] <= 320 and 192 <= box[3] <= 320)):
        return False
    x0, y0, x1, y1 = box
    return bool(np.array_equal(rgb(raw / late["path"])[y0:y1, x0:x1],
                               rgb(raw / before["path"])[y0:y1, x0:x1]))


def decay_review(entry, captures, raw):
    """Require reviewed native appearance and decay images, not contrast alone."""
    required = {-1, 0, 1, 2, 3, 12, 96}
    if entry.get("first_appearance_and_decay_reviewed") is not True:
        return "Flash first appearance and complete decay sequence need image review"
    reviewed = entry.get("reviewed_captures", [])
    offsets = [row.get("shot_offset") for row in reviewed]
    if len(offsets) != len(set(offsets)) or not required.issubset(offsets):
        return "Flash appearance/decay review is missing native frames"
    for row in reviewed:
        capture = captures.get(row["shot_offset"])
        if (not capture or row.get("capture") != capture["path"]
                or row.get("sha256") != sha(raw / capture["path"])):
            return "Flash appearance/decay review refers to changed native image bytes"
    return None


def analyze(run, output, review_path=None, tolerance=2.0, capture_storage="copy"):
    if not 0 < tolerance <= 2:
        raise ValueError("Native alignment hard gate is at most two normal-scale pixels for both SD and HD")
    run,output=fs_path(run),fs_path(output)
    review_path=fs_path(review_path) if review_path else None
    output.mkdir(parents=True, exist_ok=True)
    retained_input = (run / "native-report.json").is_file()
    raw = run if retained_input else run / "script-output"
    report_path = raw / ("native-report.json" if retained_input else "minigun-firing-report.json")
    if not report_path.exists():
        result = {"schema": 1, "status": "failed", "failures": ["Native report is missing"],
                  "alignment_gate_passed": False, "production_approved": False}
        (output / "summary.json").write_text(json.dumps(result, indent=2) + "\n")
        return result
    report = json.loads(report_path.read_text(encoding="utf-8-sig"))
    config, audit = report["config"], report["prototype_audit"]
    helper = run if retained_input else run / "mods/zzz-esir-minigun-firing"
    plan = json.loads((helper / "fixture-plan.json").read_text(encoding="utf-8-sig"))
    anchors = json.loads((helper / "muzzle-anchors.json").read_text(encoding="utf-8-sig"))
    geometry = {row["direction"]: row for row in anchors["visual_anchors"]}
    review = json.loads(review_path.read_text(encoding="utf-8-sig")) if review_path else {}
    failures, pending, results, calibration, moving, scope_pending = [], [], [], [], [], []
    failures.extend(coverage_failures(report, plan, anchors))
    bound_sources = {"native-report.json": report_path, "fixture-plan.json": helper / "fixture-plan.json",
                     "muzzle-anchors.json": helper / "muzzle-anchors.json",
                     "candidate-graphics-data.lua": helper / "candidate-graphics-data.lua",
                     "candidate-assets-manifest.json": helper / "candidate-assets-manifest.json",
                     "candidate-mechanical-data.lua": helper / "candidate-mechanical-data.lua"}
    if review_path:
        bound_sources["visual-review.json"] = review_path
    measurement_path = None
    if config.get("heading_templates"):
        measurement_path = (helper / "heading-measurements.json" if retained_input else
                            fs_path(review.get("heading_template_calibration", {}).get("measurement_report", "")))
        bound_sources["heading-measurements.json"] = measurement_path
    input_hashes = {name: sha(path) for name, path in bound_sources.items() if path.is_file()}
    for key, filename in (("candidate_data_sha256", "candidate-graphics-data.lua"),
                          ("assets_manifest_sha256", "candidate-assets-manifest.json"),
                          ("mechanical_data_sha256", "candidate-mechanical-data.lua")):
        if filename not in input_hashes or config.get(key) != input_hashes[filename]:
            failures.append("Native configuration does not bind actual retained input bytes: " + filename)
    candidate_manifest = None
    try:
        candidate_manifest = json.loads((helper / "candidate-assets-manifest.json").read_text(encoding="utf-8-sig"))
        verify_candidate_asset_manifest(candidate_manifest, helper / "candidate-graphics-data.lua", helper / "candidate")
    except (OSError, ValueError, KeyError, TypeError) as error:
        failures.append("Actual staged candidate atlas binding failed: " + str(error))
    if config != plan["config"] or not authored_cases_equal(
            [case["spec"] for case in report["cases"]], plan["cases"]):
        failures.append("Observed run differs from the retained planned case matrix")
    wanted_directions = set(range(256)) if config["coverage"] == "full" else set(range(0,256,32))
    wanted_pairs = {(d, ammo) for ammo in config["ammo_names"]
                    for d in (wanted_directions if ammo == "piercing-rounds-magazine" else range(0,256,32))}
    static_pairs = [(case["spec"]["requested_rendered_direction"], case["spec"]["ammo"])
                    for case in report["cases"] if case["spec"]["kind"] == "static"]
    if len(static_pairs) != len(wanted_pairs) or set(static_pairs) != wanted_pairs:
        failures.append("Static native cases do not cover every planned direction and ammunition route exactly once")
    if sum(case["spec"]["kind"] == "moving" for case in report["cases"]) != int(config.get("include_moving", True)):
        failures.append("Moving-aim case coverage differs from the retained plan")
    if not report.get("done") or len(report["cases"]) != config["case_count"]:
        failures.append("Fixture did not finish every planned case")
    if report.get("errors"):
        failures.append({"native_observer_errors": report["errors"]})
    if audit.get("limitations"):
        pending.extend(audit["limitations"])
    if bool(audit["profile_enabled"]) != (config["profile"] == "hd"):
        failures.append("Effective enabled HD pack differs from the explicit profile")
    if len(audit["effective_attack"].get("projectile_creation_parameters", [])) != 256:
        failures.append("Effective prototype did not retain the full launch map")
    if config.get("calibration_only"):
        scope_pending.append("Calibration-only subset cannot satisfy all-ammo/full acceptance")
    heading_templates = report.get("heading_flash_templates", {})
    if config.get("heading_templates"):
        expected_groups = {case["id"] + "-" + variant for case in report["cases"]
                           if case["spec"]["kind"] == "static" for variant in ("native", "flash")}
        if set(heading_templates) != expected_groups:
            failures.append("Heading-specific flash template groups are incomplete")
        for key, group in heading_templates.items():
            if group.get("status") not in ("orientation_readback_pending_images", "native_target_ray_pending_images"):
                pending.append(key + ": actual FX orientation was unavailable or template readback failed")
            expected_offsets = {-1, 0, 1} if config.get("compact_heading_templates") else set(range(-1, 13))
            if ({cap["shot_offset"] for cap in group["captures"]} != expected_offsets
                    or len(group["captures"]) != len(expected_offsets)):
                failures.append(key + ": missing heading-template frame capture")
        problem = heading_review(review.get("heading_template_calibration"), report_path, report, raw, measurement_path)
        if problem:
            pending.append(problem)
    if review.get("candidate_data_sha256") != config["candidate_data_sha256"]:
        pending.append("Review is missing or refers to different candidate metadata")
    if review.get("mechanical_data_sha256") != config.get("mechanical_data_sha256"):
        pending.append("Review is missing or refers to different optional fixture mechanical metadata")
    if review.get("source_sha256") != config["source_sha256"]:
        pending.append("Review does not bind to this model source")
    if review.get("native_report_sha256") != sha(report_path):
        pending.append("Review does not bind to this native report")
    if review.get("profile") != config["profile"] or review.get("ballistic") != config["ballistic"]:
        pending.append("Review does not name this SD/HD and doctrine configuration")
    if review.get("height_compensation_verified") is not True:
        pending.append("Native flash/projectile height compensation remains unverified")
    for case in report["cases"]:
        spec, case_id = case["spec"], case["id"]
        rows = {row["variant"]: row for row in case["rows"]}
        case_fail, case_pending = [], []
        if len(case["rows"]) != 4 or set(rows) != set(VARIANTS):
            failures.append(case_id + ": missing contrast variant")
            continue
        requirements = {}
        for variant, row in rows.items():
            try:
                requirements[variant] = projectile_requirements(audit, case, row)
            except (ValueError, KeyError, TypeError) as error:
                case_fail.append(variant + ": " + str(error))
            try:
                ammunition_accounting(audit, case, row)
            except (ValueError, KeyError, TypeError) as error:
                case_fail.append(variant + ": " + str(error))
        if len({row.get("first_shot") for row in rows.values()}) != 1:
            case_fail.append("Contrast variants have different first-shot ticks")
        if spec["kind"] == "moving":
            try:
                measured, moving_fail, moving_pending = moving_evidence(case, geometry, raw, review, tolerance, audit)
                moving.append(measured)
                case_fail.extend(moving_fail)
                case_pending.extend(moving_pending)
            except (ValueError, KeyError, TypeError) as error:
                case_fail.append("Moving native evidence is invalid: " + str(error))
            failures.extend(case_id + ": " + item for item in case_fail)
            pending.extend(case_id + ": " + item for item in case_pending)
            continue
        observed = {}
        for variant, row in rows.items():
            capture = row.get("direction_capture")
            try:
                observed[variant] = decode_direction(raw / capture["path"], capture)
            except (ValueError, FileNotFoundError, TypeError) as error:
                case_fail.append(variant + ": native direction decode failed: " + str(error))
        direction = observed.get("native")
        if set(observed.values()) != {spec["requested_rendered_direction"]} or len(observed) != 4:
            case_fail.append("Actual rendered direction differs from requested inverse-projection view")
        if direction is not None:
            calibration.append({"case": case_id, "requested": spec["requested_rendered_direction"],
                                "observed": direction, "orientation": rows["native"]["direction_capture"]["orientation"]})
        captures = {variant: {cap["shot_offset"]: cap for cap in row["captures"]} for variant, row in rows.items()}
        series = {"flash": [], "projectile": []}
        contrast_masks = {}
        try:
            before = {variant: rgb(raw / captures[variant][-1]["path"]) for variant in VARIANTS}
            for offset in OFFSETS:
                blank = rgb(raw / captures["blank"][offset]["path"])
                for visual in series:
                    details, mask = contrast(rgb(raw / captures[visual][offset]["path"]), blank,
                                             before[visual], before["blank"])
                    details["shot_offset"] = offset
                    series[visual].append(details)
                    contrast_masks[visual, offset] = mask
        except (KeyError, FileNotFoundError) as error:
            case_fail.append("Missing first-appearance/decay image: " + str(error))
        summary = {"id": case_id, "requested_direction": spec["requested_rendered_direction"],
                   "observed_direction": direction, "ammo": spec["ammo"], "contrast": series,
                   "source_effects": rows["native"]["shots"], "native_flashes": rows["native"]["flashes"],
                   "native_projectiles": rows["native"]["projectiles"]}
        panels = []
        for visual in series:
            expected_delivery = visual == "flash" or any(requirements.get("native", [True]))
            if not expected_delivery:
                summary[visual] = {"status": "not_applicable_native_instant_delivery"}
                continue
            visible = [point for point in series[visual] if point["pixels"] >= 8 and point["energy"] >= 250]
            if not visible:
                case_fail.append(visual + ": no contrasted native pixels observed")
                continue
            first = visible[0]["shot_offset"]
            summary[visual] = {"first_visible_offset": first,
                               "last_visible_offset": visible[-1]["shot_offset"],
                               "note": "Contrast includes native randomness; identity and origin require actual-image review"}
            if first > 3:
                case_fail.append(visual + ": first visible evidence is too late to measure the launch origin")
            annotation = review.get("cases", {}).get(case_id, {}).get(visual, {})
            cap = captures["native"].get(first)
            if cap:
                problem = image_review(annotation, cap, raw, [160, 160], tolerance)
                if problem:
                    case_pending.append(visual + ": " + problem)
                else:
                    summary[visual].update({"reviewed_capture": annotation["capture"],
                        "reviewed_capture_sha256": annotation["sha256"],
                        "observed_origin_pixels": annotation["origin_pixels"],
                        "registered_muzzle_pixels": [160, 160],
                        "attachment_error_native_pixels": math.dist(annotation["origin_pixels"], [160, 160]) / cap["zoom"]})
                for variant in ("native", visual, "blank"):
                    image = Image.open(fs_path(raw / captures[variant][first]["path"])).convert("RGB")
                    draw = ImageDraw.Draw(image)
                    draw.line((150,160,170,160), fill=(255,0,255), width=1)
                    draw.line((160,150,160,170), fill=(255,0,255), width=1)
                    draw.text((6,6), f"{visual}: {variant} t+{first}", fill=(255,255,255))
                    panels.append(image.resize((160,160)))
            if visual == "flash" and series[visual]:
                peak = max(x["energy"] for x in series[visual])
                late = series[visual][-1]
                summary[visual]["late_energy_fraction"] = late["energy"] / max(peak,1)
                if late["energy"] > max(250, peak*0.1):
                    if not late_residual_review(annotation.get("late_residual_review"),
                                                captures["native"][96], captures["native"][-1], raw):
                        case_pending.append("Flash contrast has not decayed by t+96; review native residuals or extend the window")
                problem = decay_review(annotation, captures["native"], raw)
                if problem:
                    case_pending.append(problem)
        if panels:
            gallery = Image.new("RGB", (160*len(panels),160), (20,20,20))
            for index, panel in enumerate(panels):
                gallery.paste(panel,(160*index,0))
            (output / "contacts").mkdir(exist_ok=True)
            gallery.save(output / "contacts" / (case_id+".png"))
        summary["failures"], summary["pending_review"] = case_fail, case_pending
        results.append(summary)
        failures.extend(case_id + ": " + item for item in case_fail)
        pending.extend(case_id + ": " + item for item in case_pending)
    expected = set(range(256)) if config["coverage"] == "full" else set(range(0,256,32))
    seen = {row["observed"] for row in calibration}
    projection_verified = bool(calibration) and seen == expected and all(row["observed"] == row["requested"] for row in calibration)
    projection = {"schema": 1, "source_sha256": config["source_sha256"],
                  "status": config["coverage"] + "_projection_verified" if projection_verified else "projection_unverified",
                  "formula": "atan2(sqrt(2)*sin(render_angle),cos(render_angle))/(2*pi) mod 1",
                  "direction_count": config["direction_count"], "measurements": calibration}
    (output / "projection-calibration.json").write_text(json.dumps(projection,indent=2)+"\n")
    if not projection_verified:
        failures.append("Native rendered-direction projection calibration is incomplete or mismatched")
    # Screenshots are immutable evidence. Explicit same-volume hardlink retention
    # avoids a second physical copy; mismatching existing destinations are refused.
    try:
        if candidate_manifest:
            retain_candidate_assets(candidate_manifest, helper / "candidate", output / "candidate", capture_storage)
        captures = retain_captures(raw, output, report, capture_storage)
        capture_manifest_path = output / "capture-manifest.json"
        capture_manifest_path.write_text(json.dumps(captures, indent=2) + "\n", encoding="utf-8")
        input_hashes["capture-manifest.json"] = sha(capture_manifest_path)
    except (OSError, ValueError) as error:
        captures = {"retention_failed": str(error)}
        failures.append("Native capture retention/hash binding failed: " + str(error))
    for name, source in bound_sources.items():
        destination = output / name
        if source.is_file() and source.resolve() != destination.resolve():
            if destination.exists() and sha(destination) != input_hashes[name]:
                raise ValueError("Different retained input exists; select a new analysis output: " + name)
            if not destination.exists():
                shutil.copy2(source, destination)
            if sha(destination) != input_hashes[name]:
                raise ValueError("Retained input hash differs: " + name)
    pilot_passed = bool(config.get("calibration_only") and projection_verified and not failures and not pending)
    result = {"schema": 1, "status": "failed" if failures else "pending_visual_review" if pending else "pilot_calibration_passed" if pilot_passed else "passed",
              "profile": config["profile"], "ballistic": config["ballistic"], "coverage": config["coverage"],
              "calibration_only": config.get("calibration_only",False),
              "heading_template_status": {key: group.get("status") for key, group in heading_templates.items()},
              "connector_status": "deferred_by_user", "shell_ejection_status": "audit_only_not_an_added_acceptance_gate",
              "automated_checks_passed": not failures, "alignment_gate_passed": not failures and not pending and not scope_pending,
              "pilot_calibration_gate_passed": pilot_passed,
              "failures": failures, "pending_review": pending + scope_pending,
              "pending_visual_review": pending, "remaining_acceptance_scope": scope_pending,
              "cases": results, "moving": moving,
              "source_sha256": config["source_sha256"], "native_report_sha256": sha(report_path),
              "review_sha256": sha(review_path) if review_path else None,
              "candidate_data_sha256": config["candidate_data_sha256"],
              "mechanical_data_sha256": config.get("mechanical_data_sha256"),
              "assets_manifest_sha256": config.get("assets_manifest_sha256"),
              "evidence": {"schema": "esir.minigun.firing-evidence.v1", "files": input_hashes,
                           "configuration_sha256": canonical_sha(config),
                           "capture_count": captures.get("native_report_capture_count"),
                           "logical_png_bytes": captures.get("logical_png_bytes"),
                           "capture_storage": capture_storage},
              "tolerance_native_pixels": tolerance,
              "attachment_goal_native_pixels": 1,
              "source_coordinates_alone_are_sufficient": False, "production_approved": False,
              "limitations": ["Native sub-tick instants cannot be reconstructed from one rendered frame per tick",
                              "Random rotation, scattered projectiles, particles and lighting can affect contrast masks",
                              "Flash centroid and projectile creation coordinates are not measured visual origins",
                              "Moving-aim screenshots include overlapping effects; selected first/sustained origins require review",
                              "This report covers one profile/doctrine combination; all four are required"]}
    (output / "summary.json").write_text(json.dumps(result,indent=2)+"\n",encoding="utf-8")
    return result


if __name__ == "__main__":
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--run",type=Path,required=True)
    parser.add_argument("--output",type=Path,required=True)
    parser.add_argument("--review",type=Path)
    parser.add_argument("--tolerance-native-pixels",type=float,default=2.0)
    parser.add_argument("--capture-storage", choices=("copy", "hardlink"), default="copy",
                        help="hardlink preserves one immutable physical copy on the same volume; never removes raw files")
    args=parser.parse_args()
    result=analyze(args.run,args.output,args.review,args.tolerance_native_pixels,args.capture_storage)
    print(json.dumps({key:result.get(key) for key in ("status","automated_checks_passed","alignment_gate_passed","production_approved")}))
    raise SystemExit(2 if result["status"]=="failed" else 3 if result["status"]=="pending_visual_review" else 0)
