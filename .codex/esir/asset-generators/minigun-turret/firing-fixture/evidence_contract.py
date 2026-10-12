"""Offline provenance and exact coverage checks; never creates native approval."""
from __future__ import annotations

import hashlib
import json
import math
import os
import re
from pathlib import Path, PurePosixPath

AMMO = ["firearm-magazine", "piercing-rounds-magazine", "uranium-rounds-magazine"] + [
    "ei-" + family + "-ammo" for family in
    ("compound", "corrosive", "cryo", "oxyfluoride", "morphium", "hexafluoride", "arc", "neutron")]
PILOT = list(range(0, 256, 32))
VARIANTS = {"native", "flash", "projectile", "blank"}
SOURCE = "453a8f5b75fd16630803d698293222cf9e07a3e1cecb1f7c3b40434d75008f59"
BOUND_FILES = {"native_report": "native-report.json", "fixture_plan": "fixture-plan.json",
               "anchors": "muzzle-anchors.json", "candidate_data": "candidate-graphics-data.lua",
               "mechanical_data": "candidate-mechanical-data.lua", "review": "visual-review.json",
               "candidate_assets": "candidate-assets-manifest.json",
               "capture_manifest": "capture-manifest.json"}


def bound_files(config):
    files = dict(BOUND_FILES)
    if config.get("heading_templates"):
        files["heading_measurement"] = "heading-measurements.json"
    return files


def projectile_requirements(audit, case, row):
    """Resolve each observed shot's declared ammo branch, never infer instant from silence.

    The fixture audits the effective source ammo graph before instrumenting it.
    Projectile births corroborate the route; rendered pixels still decide attachment.
    """
    declaration = audit["ammo"][case["spec"]["ammo"]]
    variant = declaration["variants"][row["variant"]]
    ammo_type = declaration["ammo_type"]
    branches = [ammo_type] if isinstance(ammo_type, dict) and "action" in ammo_type else ammo_type
    if not isinstance(branches, list) or not branches:
        raise ValueError("Missing effective ammo branches")

    def entries(value):
        if value is None:
            return []
        if isinstance(value, dict) and "type" in value:
            return [value]
        if isinstance(value, list):
            return value
        raise ValueError("Unsupported effective ammo action shape")

    counts = []
    for branch in branches:
        deliveries = [delivery for action in entries(branch.get("action"))
                      for delivery in entries(action.get("action_delivery"))]
        if any(delivery.get("type") not in ("instant", "projectile") for delivery in deliveries):
            raise ValueError("Unsupported effective ammo delivery route")
        counts.append(sum(delivery["type"] == "projectile" for delivery in deliveries))
    if (variant.get("observer_branches") != len(branches)
            or variant.get("projectile_deliveries") != sum(counts)
            or row.get("ammo") != variant.get("name")):
        raise ValueError("Effective ammo graph and instrumented route audit differ")
    prefix = "mgf-shot|" + variant["name"] + "|"
    requirements = []
    for shot in row.get("shots", []):
        effect = shot.get("effect", "")
        suffix = effect[len(prefix):] if effect.startswith(prefix) else ""
        if not suffix.isdecimal() or not 1 <= int(suffix) <= len(counts):
            raise ValueError("Shot does not identify an audited ammo branch")
        requirements.append(counts[int(suffix)-1] > 0)
    if not requirements:
        raise ValueError("No observed shots for the declared ammo route")
    birth_ticks = set()
    birth_prefix = "mgf-projectile|" + variant["name"] + "-projectile-"
    for birth in row.get("projectiles", []):
        if not birth.get("effect", "").startswith(birth_prefix):
            raise ValueError("Projectile birth does not identify this instrumented ammo route")
        birth_ticks.add(birth["tick"])
    required_ticks = {shot["tick"] for shot, required in zip(row["shots"], requirements) if required}
    if required_ticks - birth_ticks:
        raise ValueError("Declared projectile route lacks an actual projectile birth observation")
    if birth_ticks - required_ticks:
        raise ValueError("Unexpected projectile birth outside a declared projectile shot")
    return requirements


def ammunition_accounting(audit, case, row):
    """Validate native consumption; retain the old requested-as-inserted counters.

    Shot callback capture zero precedes its own ammo decrement. For the legacy
    moving fixture only, that recorded native readback recovers a clamped stack's
    actual budget. Every subsequent pre-tick ammo capture must corroborate it.
    This never rewrites the native report or excuses a source/consumption gap.
    """
    projectile_requirements(audit, case, row)
    inserted, consumed, unspent = (row.get(key) for key in ("inserted", "consumed", "unspent"))
    planned = case["spec"]["rounds"]
    if (any(type(value) is not int or value < 0 for value in (inserted, consumed, unspent, planned))
            or inserted != consumed + unspent or consumed <= 0):
        raise ValueError("Reported ammunition counters do not reconcile")
    shots = row["shots"]
    zeros = [cap for cap in row["captures"] if cap.get("shot_offset") == 0]
    if (len(zeros) != 1 or not shots or zeros[0].get("tick") != row.get("first_shot")
            or row.get("first_shot") != shots[0].get("tick")
            or type(zeros[0].get("remaining")) is not int or zeros[0]["remaining"] <= 0):
        raise ValueError("First pre-decrement native ammo capture is missing or inconsistent")
    initial = zeros[0]["remaining"]
    recovered = initial != inserted
    if recovered:
        magazine = audit["ammo"][case["spec"]["ammo"]]["magazine_size"]
        if (case["id"] != "moving-aim-piercing" or case["spec"]["kind"] != "moving"
                or planned != 1024 or inserted != planned or "requested" in row
                or type(magazine) is not int or magazine <= 0 or not 0 < initial < inserted
                or (inserted-initial) % magazine != 0):
            raise ValueError("Unrecognized historical ammunition insertion discrepancy")
        before = [cap for cap in row["captures"] if cap.get("shot_offset") == -1]
        if len(before) != 1 or before[0].get("remaining") != 0 or before[0]["tick"] >= row["first_shot"]:
            raise ValueError("Historical recovery lacks the empty prefire inventory")
        # On-tick capture precedes that update's firing; offset zero is taken in
        # its first source callback. Both therefore exclude current-tick shots.
        for cap in row["captures"]:
            if cap["shot_offset"] < 0:
                continue
            expected = initial - sum(shot["tick"] < cap["tick"] for shot in shots)
            if cap["tick"] != row["first_shot"] + cap["shot_offset"] or cap.get("remaining") != expected:
                raise ValueError("Historical ammo recovery disagrees with native capture readbacks")
    elif row.get("requested", planned) != planned or not 0 < inserted <= planned:
        raise ValueError("Actual/requested ammunition budget differs from the planned case")
    actual_consumed = initial - unspent
    if actual_consumed <= 0 or len(shots) != actual_consumed:
        raise ValueError("Native source shot count and actual ammunition consumption differ")
    if case["spec"]["kind"] == "static" and (inserted != planned or actual_consumed != planned):
        raise ValueError("Static ammunition consumption differs from its exact planned rounds")
    return {"reported_inserted":inserted,"reported_consumed":consumed,"requested_rounds":planned,
            "initial_rounds":initial,"consumed_rounds":actual_consumed,"unspent_rounds":unspent,
            "source_shots":len(shots),"legacy_insertion_accounting_recovered":recovered,
            "initial_capture":{"path":zeros[0]["path"],"tick":zeros[0]["tick"],"remaining":initial}}


def fs_path(path):
    value = os.path.abspath(path)
    if os.name == "nt" and not value.startswith("\\\\?\\"):
        value = "\\\\?\\UNC\\" + value[2:] if value.startswith("\\\\") else "\\\\?\\" + value
    return Path(value)


def sha(path):
    digest = hashlib.sha256()
    with fs_path(path).open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def canonical_sha(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True, separators=(",", ":"),
                                    allow_nan=False).encode("utf-8")).hexdigest()


def candidate_asset_path(root, name):
    path = PurePosixPath(name)
    if ("\\" in name or path.is_absolute() or ".." in path.parts or len(path.parts) < 3
            or path.parts[0] not in ("sd", "hd") or path.parts[1] != "graphics" or path.suffix != ".png"):
        raise ValueError("Unsafe candidate PNG identity: " + name)
    target = fs_path(Path(root).joinpath(*path.parts))
    cursor, boundary = target, fs_path(root)
    if boundary.is_symlink() or (boundary.exists() and getattr(boundary.stat(), "st_file_attributes", 0) & 1024):
        raise ValueError("Candidate root is a reparse point")
    while cursor != boundary:
        if cursor.is_symlink() or (cursor.exists() and getattr(cursor.stat(), "st_file_attributes", 0) & 1024):
            raise ValueError("Candidate PNG traverses a reparse point: " + name)
        cursor = cursor.parent
    return target


def build_candidate_asset_manifest(candidate_data_path, candidate_root):
    """Read/hash exact referenced SD+HD PNG union; return data without writing."""
    from PIL import Image
    prefix = "__zzz-esir-minigun-firing__/candidate/"
    text = fs_path(candidate_data_path).read_text(encoding="utf-8-sig")
    references = set(re.findall(r'"([^"\n]+\.png)"', text))
    if not references or any(not name.startswith(prefix) for name in references):
        raise ValueError("Final firing requires every PNG under its explicit candidate helper root")
    files = {}
    for reference in sorted(references):
        name = reference[len(prefix):]
        path = candidate_asset_path(candidate_root, name)
        digest = sha(path)
        with Image.open(path) as image:
            if image.format != "PNG" or max(image.size) > 4096 or min(image.size) <= 0:
                raise ValueError("Invalid candidate PNG/atlas size: " + name)
            size = list(image.size)
        files[name] = {"sha256": digest, "bytes": path.stat().st_size, "size": size}
    if {name.split("/", 1)[0] for name in files} != {"sd", "hd"}:
        raise ValueError("Candidate evidence must include the complete referenced SD/HD union")
    return {"schema": "esir.minigun.candidate-assets.v1", "candidate_data_sha256": sha(candidate_data_path),
            "files": files}


def verify_candidate_asset_manifest(manifest, candidate_data_path, candidate_root):
    if manifest != build_candidate_asset_manifest(candidate_data_path, candidate_root):
        raise ValueError("Referenced candidate PNG bytes/paths/dimensions or metadata changed")
    return True


def retain_candidate_assets(manifest, source_root, destination_root, mode):
    import shutil
    for name, record in manifest["files"].items():
        source = candidate_asset_path(source_root, name)
        destination = candidate_asset_path(destination_root, name)
        destination.parent.mkdir(parents=True, exist_ok=True)
        if not destination.exists():
            if mode == "hardlink": os.link(source, destination)
            elif mode == "copy": shutil.copy2(source, destination)
            else: raise ValueError("Unknown candidate retention mode")
        if sha(destination) != record["sha256"]:
            raise ValueError("Refusing different retained candidate PNG: " + name)


def capture_path(root, name):
    path = PurePosixPath(name)
    if (not isinstance(name, str) or "\\" in name or path.is_absolute() or ".." in path.parts
            or not path.parts or path.parts[0] != "minigun-firing" or path.suffix != ".png"):
        raise ValueError("Unsafe native capture identity: " + str(name))
    return fs_path(Path(root).joinpath(*path.parts))


def capture_names(value):
    """Deduplicate every recorded native screenshot, including moving/templates."""
    result = set()
    if isinstance(value, dict):
        name = value.get("path")
        if isinstance(name, str) and name.endswith(".png"):
            capture_path(Path.cwd(), name)
            result.add(name)
        for child in value.values():
            result.update(capture_names(child))
    elif isinstance(value, list):
        for child in value:
            result.update(capture_names(child))
    return result


def expected_identities(config):
    coverage = config.get("coverage")
    if coverage not in ("pilot", "full") or type(config.get("calibration_only")) is not bool:
        raise ValueError("Unknown firing coverage/calibration declaration")
    calibration = config["calibration_only"]
    if calibration and (coverage != "pilot" or config.get("include_moving") is not False):
        raise ValueError("Pilot calibration must be exactly eight static cases")
    if not calibration and config.get("include_moving") is not True:
        raise ValueError("Acceptance requires the moving-aim case")
    ammo = ["piercing-rounds-magazine"] if calibration else AMMO
    if config.get("ammo_names") != ammo:
        raise ValueError("Declared ammunition routes differ from the fixed acceptance inventory")
    directions = list(range(256)) if coverage == "full" else PILOT
    if config.get("direction_count") != len(directions):
        raise ValueError("Declared atlas direction count differs from coverage")
    result = {}
    for item in ammo:
        for direction in directions if item == "piercing-rounds-magazine" else PILOT:
            result[f"d{direction:03d}-{item}"] = ("static", item, direction, 1, 220)
    if not calibration:
        result["moving-aim-piercing"] = ("moving", "piercing-rounds-magazine", 0, 1024, 420)
    if config.get("case_count") != len(result):
        raise ValueError("Declared case count differs from exact required coverage")
    return result


def _authored_number_equal(observed, planned):
    """Account only for adjacent binary64 values in authored coordinate roundtrips."""
    if (type(observed) not in (int, float) or type(planned) not in (int, float)
            or not math.isfinite(observed) or not math.isfinite(planned)):
        return False
    # Native JSON writes integral numbers such as the authored orientation 0.0 as 0.
    if observed == planned:
        return True
    return (type(observed) is float and type(planned) is float
            and observed == math.nextafter(planned, observed))


def authored_case_equal(observed, planned):
    """Keep identity/structure exact; one ULP applies only to the two authored fields."""
    if type(observed) is not dict or type(planned) is not dict or observed.keys() != planned.keys():
        return False
    for key, value in planned.items():
        actual = observed[key]
        if key == "target_orientation":
            if not _authored_number_equal(actual, value):
                return False
        elif key == "visual_offset_tiles":
            if (type(actual) is not list or type(value) is not list
                    or len(actual) != 2 or len(value) != 2
                    or not all(_authored_number_equal(a, b) for a, b in zip(actual, value))):
                return False
        elif type(actual) is not type(value) or actual != value:
            return False
    return True


def authored_cases_equal(observed, planned):
    return (type(observed) is list and type(planned) is list and len(observed) == len(planned)
            and all(authored_case_equal(a, b) for a, b in zip(observed, planned)))


def coverage_failures(native, plan, anchors):
    errors = []
    config = native.get("config", {})
    try:
        expected = expected_identities(config)
    except (ValueError, TypeError) as error:
        return [str(error)]
    if config != plan.get("config") or not authored_cases_equal(
            [case.get("spec") for case in native["cases"]], plan.get("cases")):
        errors.append("Observed configuration/cases differ from the retained plan")
    if (config.get("source_sha256") != SOURCE or anchors.get("source_sha256") != SOURCE
            or config.get("profile") not in ("sd", "hd") or type(config.get("ballistic")) is not bool):
        errors.append("Model source/profile/doctrine identity is invalid")
    if (native.get("engine") != "2.0.77" or native.get("done") is not True
            or not isinstance(native.get("errors"), (list, dict)) or native["errors"]):
        errors.append("Native run is incomplete, wrong-version or contains observer errors")
    audit = native.get("prototype_audit", {})
    if audit.get("profile") != config.get("profile") or audit.get("ballistic") != config.get("ballistic"):
        errors.append("Prototype audit profile/doctrine differs from native configuration")
    if bool(audit.get("profile_enabled")) != (config.get("profile") == "hd"):
        errors.append("Enabled HD pack differs from the requested profile")
    geometry = {row["direction"]: row for row in anchors.get("visual_anchors", [])}
    if len(anchors.get("visual_anchors", [])) != 256 or set(geometry) != set(range(256)):
        errors.append("Geometry proposal does not contain exactly 256 directions")
    seen = []
    planned_cases = plan.get("cases", [])
    for case_index, case in enumerate(native["cases"]):
        name, spec = case.get("id"), case.get("spec", {})
        identity = tuple(spec.get(field) for field in
                         ("kind", "ammo", "requested_rendered_direction", "rounds", "case_ticks"))
        if name != spec.get("id") or expected.get(name) != identity:
            errors.append("Unexpected case identity: " + str(name))
        seen.append(name)
        variants = [row.get("variant") for row in case.get("rows", [])]
        if len(variants) != 4 or set(variants) != VARIANTS:
            errors.append(str(name) + ": contrast rows must occur exactly once")
        direction = spec.get("requested_rendered_direction")
        planned_spec = planned_cases[case_index] if case_index < len(planned_cases) else {}
        if direction in geometry and planned_spec.get("visual_offset_tiles") != geometry[direction]["visual_offset_tiles"]:
            errors.append(str(name) + ": planned visual anchor differs from bound geometry")
        if spec.get("kind") == "moving" and spec.get("slew_ticks") != 240:
            errors.append(str(name) + ": moving sweep duration differs")
    if len(seen) != len(expected) or set(seen) != set(expected):
        errors.append("Native cases do not cover the exact required identities once")
    expected_ticks = sum(value[4] for value in expected.values()) + 90
    if plan.get("benchmark_ticks") != expected_ticks:
        errors.append("Planned benchmark duration differs from exact case inventory")
    return errors


def summary_failures(summary, native, plan, anchors, actual_hashes):
    errors = coverage_failures(native, plan, anchors)
    config = native["config"]
    evidence = summary.get("evidence", {})
    if evidence.get("schema") != "esir.minigun.firing-evidence.v1":
        errors.append("Missing strengthened firing evidence contract")
    for key, filename in bound_files(config).items():
        if evidence.get("files", {}).get(filename) != actual_hashes.get(filename) or not actual_hashes.get(filename):
            errors.append("Changed/missing bound " + filename)
    if evidence.get("configuration_sha256") != canonical_sha(config):
        errors.append("Native configuration hash differs")
    for key in ("profile", "ballistic", "coverage", "calibration_only", "source_sha256", "candidate_data_sha256", "mechanical_data_sha256", "assets_manifest_sha256"):
        if summary.get(key) != config.get(key):
            errors.append("Summary/native " + key + " differs")
    for key, filename in (("native_report_sha256", "native-report.json"), ("review_sha256", "visual-review.json"),
                          ("candidate_data_sha256", "candidate-graphics-data.lua"),
                          ("mechanical_data_sha256", "candidate-mechanical-data.lua"),
                          ("assets_manifest_sha256", "candidate-assets-manifest.json")):
        if summary.get(key) != actual_hashes.get(filename):
            errors.append("Summary/file " + key + " differs")
    expected = expected_identities(config)
    actual = [row.get("id") for row in summary.get("cases", [])]
    static = {name for name, identity in expected.items() if identity[0] == "static"}
    if len(actual) != len(static) or set(actual) != static:
        errors.append("Summary static rows do not cover the required cases exactly once")
    for row in summary.get("cases", []):
        expected_case = expected.get(row.get("id"))
        if (expected_case is None or row.get("ammo") != expected_case[1]
                or row.get("requested_direction") != row.get("observed_direction")
                or row.get("observed_direction") != expected_case[2]
                or row.get("failures") != [] or row.get("pending_review") != []):
            errors.append("Unpassed/misattributed static summary row: " + str(row.get("id")))
    moving = summary.get("moving", [])
    if not config["calibration_only"] and (len(moving) != 1 or moving[0].get("id") != "moving-aim-piercing"
            or moving[0].get("sustained_sectors") != list(range(8))):
        errors.append("Summary moving sweep is incomplete")
    return errors


def launches(report, static_only=False):
    result = {}
    for case in report["cases"]:
        if static_only and case["spec"]["kind"] != "static":
            continue
        native_rows = [row for row in case["rows"] if row["variant"] == "native"]
        if len(native_rows) != 1 or not native_rows[0].get("shots"):
            raise ValueError("Missing/duplicate native launch observations: " + case["id"])
        positions = []
        for shot in native_rows[0]["shots"]:
            values = [shot.get(field, {}).get(axis) for field in ("source", "center") for axis in ("x", "y")]
            if any(type(value) not in (int, float) or not math.isfinite(value) for value in values):
                raise ValueError("Invalid native launch coordinates: " + case["id"])
            positions.append((values[0] - values[2], values[1] - values[3]))
        result[case["id"]] = positions
    return result


def compare_launches(left, right, static_only=False):
    a, b = launches(left, static_only), launches(right, static_only)
    return (set(a) == set(b) and all(len(a[key]) == len(b[key]) and
            all(math.dist(x, y) <= 1e-8 for x, y in zip(a[key], b[key])) for key in a))


def retain_captures(raw, output, native, mode="copy"):
    """Retain immutable screenshot bytes once; hardlinks require the same volume."""
    import shutil
    records = {}
    for name in sorted(capture_names(native)):
        source, destination = capture_path(raw, name), capture_path(output, name)
        digest = sha(source)
        if source != destination:
            destination.parent.mkdir(parents=True, exist_ok=True)
            if destination.exists():
                if sha(destination) != digest:
                    raise ValueError("Refusing to overwrite different retained capture: " + name)
            elif mode == "hardlink":
                os.link(source, destination)
            elif mode == "copy":
                shutil.copy2(source, destination)
            else:
                raise ValueError("Unknown capture retention mode")
            if sha(destination) != digest:
                raise ValueError("Retained capture bytes differ: " + name)
        records[name] = {"sha256": digest, "bytes": source.stat().st_size}
    return {"schema": "esir.minigun.firing-captures.v1", "native_report_capture_count": len(records),
            "logical_png_bytes": sum(row["bytes"] for row in records.values()),
            "retention_mode": mode, "files": records}
