"""Read-only render/gate validation; the explicit seed command copies verified inputs.

This staging helper never launches Blender or Factorio, changes a render config,
repairs a journal, or creates approval evidence. Paths stay in this checkout.
"""
import argparse
import hashlib
import json
import math
import os
from pathlib import Path
import shutil
import struct
import sys

PILOT = "output/meshy/minigun-prototypes/prototype-2/handoff-256/separated-v2-pilot"
ROOT = "output/meshy/minigun-prototypes/prototype-2/handoff-256"
GEN = ".codex/esir/asset-generators/minigun-turret"
CONFIG = "cf3ce7c1dd28cfac34287644f62c2ca620194255e9121b140d85303616fc4b4e"
SOURCE = "453a8f5b75fd16630803d698293222cf9e07a3e1cecb1f7c3b40434d75008f59"
PINS = {
    PILOT + "/render-configuration.json": "90dbebd099abfbd9f6ed68fdddb73578681f5babcda84a6a234dcda305ed6253",
    PILOT + "/render-records.jsonl": "5961994f38a1296fa5f35550abdd101ec1e5a6010ffb5662043ceb75c7ab127e",
    "output/meshy/minigun-prototypes/prototype-2/source/model.glb": SOURCE,
    ROOT + "/prepared/minigun-render-scene.blend": "54119b0892f2b610a60a62b7b9abcbf61eb15e3b379e79498b9fc46c30a8bdf7",
    GEN + "/render_separated.py": "cffc70bd6519360f145659814c80b4779b65499ca59e17a2defae28ba2fcca40",
    GEN + "/separated_contract.py": "142b399aefdabc6d90c1b4106b9f1a2ff3dda7cb624bb027117165606c0f81a6",
    ".codex/skills/meshy-blender-spritesheet/scripts/render_factorio_preset.py": "179d18cbe0a99aef0f08555e3e79f0d41e71da721e68462cbb94674c7f4c57ba",
}
DIRECTIONS = list(range(0, 256, 32))
REQUIRED = {("base", 0, 0, p) for p in ("Object", "Shadow")}
REQUIRED |= {("upper", d, 0, p) for d in range(256) for p in ("Object", "Shadow")}
REQUIRED |= {("full", d, n, p) for d in range(256) for n in range(28) for p in ("Object", "Shadow")}
PILOT_KEYS = {k for k in REQUIRED if k[0] == "base" or k[1] in DIRECTIONS}


def require(test, message):
    if not test:
        raise ValueError(message)


def fs(path):
    """Use extended Win32 I/O paths without changing portable evidence identities."""
    text = os.path.abspath(path)
    if os.name == "nt" and not text.startswith("\\\\?\\"):
        text = "\\\\?\\UNC\\" + text[2:] if text.startswith("\\\\") else "\\\\?\\" + text
    return Path(text)


def confined(repo, value, exists=True):
    candidate = Path(value)
    require(".." not in candidate.parts, "Parent traversal is refused: " + str(value))
    candidate = candidate if candidate.is_absolute() else repo / candidate
    # Reject reparse points before resolve(), including existing output ancestors.
    cursor = candidate.absolute()
    while cursor != repo.parent and cursor != cursor.parent:
        if fs(cursor).exists():
            require(not fs(cursor).is_symlink() and not (getattr(fs(cursor).stat(), "st_file_attributes", 0) & 1024),
                    "Reparse path is refused: " + str(cursor))
        cursor = cursor.parent
    target = Path(os.path.abspath(candidate))
    require(target.is_relative_to(repo) and target != repo, "Path leaves checkout: " + str(value))
    if exists:
        require(fs(target).exists(), "Missing input: " + str(target))
    return target


def sha(path):
    digest = hashlib.sha256()
    with fs(path).open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def read(path):
    return json.loads(fs(path).read_text(encoding="utf-8-sig"))


def file_record(repo, path):
    return {"path": path.relative_to(repo).as_posix(), "sha256": sha(path), "bytes": fs(path).stat().st_size}


def journal(repo, root, subset=None):
    config_path = confined(repo, root / "render-configuration.json")
    require(sha(config_path) == PINS[PILOT + "/render-configuration.json"], "Render configuration bytes changed")
    data = fs(confined(repo, root / "render-records.jsonl")).read_bytes()
    require(data.endswith(b"\n"), "Journal lacks its final newline; preserve it for explicit investigation")
    seen, paths, total, selected_count = {}, set(), 0, 0
    for line_number, line in enumerate(data.splitlines(), 1):
        require(bool(line.strip()), "Empty journal line: " + str(line_number))
        try:
            row = json.loads(line)
        except ValueError as error:
            raise ValueError(f"Malformed journal line {line_number}; no automatic truncation") from error
        key = (row["family"], row["direction"], row["pose"], row["pass"])
        require(key in REQUIRED and row["configuration_hash"] == CONFIG, "Unexpected journal identity/configuration")
        expected_path = f"references/{key[0]}/{key[3]}/d{key[1]:03}-p{key[2]:02}.png"
        require(row["path"] == expected_path, "Journal path does not match its pose identity")
        require(row["margin"] >= 8 and math.isfinite(row["pose_proof_error"]) and row["pose_proof_error"] < 2e-6,
                "Failed bounds or rotor proof in journal")
        if key in seen:
            require(seen[key]["sha256"] == row["sha256"], "Conflicting duplicate journal record; no silent repair")
        seen[key] = row
        paths.add(expected_path)
    for key, row in seen.items():
        path = confined(repo, root / row["path"])
        total += fs(path).stat().st_size
        if subset is not None and key not in subset:
            continue
        require(sha(path) == row["sha256"], "Recorded frame hash differs: " + str(path))
        with fs(path).open("rb") as stream:
            header = stream.read(26)
        require(header[:8] == b"\x89PNG\r\n\x1a\n" and struct.unpack(">II", header[16:24]) == (540, 540)
                and header[24:26] == bytes((8, 6)), "Expected 540px RGBA8 PNG: " + str(path))
        selected_count += 1
    for path in fs(root / "references").rglob("*.png"):
        require(path.relative_to(fs(root)).as_posix() in paths, "Unjournaled PNG needs explicit review: " + str(path))
    if subset is not None:
        require(subset.issubset(seen), "Requested chunk has missing journal records")
    return seen, {"journal_lines": len(data.splitlines()), "unique_passes": len(seen),
                  "verified_pngs": selected_count, "bytes": total, "journal_sha256": hashlib.sha256(data).hexdigest()}


def baseline(repo):
    for relative, expected in PINS.items():
        require(sha(confined(repo, relative)) == expected, "Approved input changed: " + relative)
    root = confined(repo, PILOT)
    config = read(root / "render-configuration.json")
    canonical = {k: v for k, v in config.items() if k != "hash"}
    require(hashlib.sha256(json.dumps(canonical, sort_keys=True).encode()).hexdigest() == CONFIG, "Invalid configuration digest")
    require(config["samples"] == 256 and config["seed"] == 0 and config["physical_poses"] == 28
            and config["resolution"] == [540, 540] and config["blender"] == "5.1.1", "Unexpected render settings")
    records, stats = journal(repo, root)
    require(set(records) == PILOT_KEYS and len(records) == 466, "Pilot is not exactly the retained 466-pass family")
    # Keep the existing icon sources; native icon readability remains a promotion gate.
    icons = []
    icon_root = confined(repo, ROOT + "/separated-v2-icons")
    icon_report = read(icon_root / "icon-report.json")
    require(icon_report["source_sha256"] == SOURCE and sha(icon_root / "icon-master.png") == icon_report["sha256"],
            "Icon master provenance differs")
    icons += [file_record(repo, icon_root / name) for name in ("icon-master.png", "icon-report.json")]
    compiled = root / "compiled"
    metadata = read(compiled / "metadata.json")
    for profile, value in metadata["profiles"].items():
        for icon in value["icons"].values():
            path = confined(repo, compiled / profile / icon["path"])
            require(sha(path) == icon["sha256"], "Compiled icon hash differs")
            icons.append(file_record(repo, path))
    return records, stats, icons


def approval(repo, summary_name, summary_sha, review_name, review_sha):
    require(all((summary_name, summary_sha, review_name, review_sha)),
            "Explicit approved pilot report/review paths and SHA256 values are required; approval is not inferred")
    summary_path, review_path = confined(repo, summary_name), confined(repo, review_name)
    require(sha(summary_path) == summary_sha.lower() and sha(review_path) == review_sha.lower(), "Approval/review hash mismatch")
    summary, review = read(summary_path), read(review_path)
    native_path = confined(repo, summary_path.parent / "native-report.json")
    native = read(native_path)
    config = native["config"]
    native_sha = sha(native_path)
    require(summary.get("native_report_sha256") == native_sha == review.get("native_report_sha256")
            and summary.get("review_sha256") == sha(review_path), "Native report/review provenance hash binding differs")
    require(summary.get("schema") == 1 and summary.get("pilot_calibration_gate_passed") is True
            and summary.get("status") in ("pilot_calibration_passed", "passed")
            and summary.get("automated_checks_passed") is True and summary.get("failures") == [],
            "Native image-backed pilot calibration is not explicitly passed")
    require(native.get("done") is True and isinstance(native.get("errors"), (list, dict))
            and not native["errors"] and native.get("engine") == "2.0.77",
            "Incomplete or wrong-version native firing evidence")
    require(config.get("source_sha256") == SOURCE and review.get("source_sha256") == SOURCE
            and review.get("height_compensation_verified") is True, "Source or native height review is unverified")
    candidate = config["candidate_data_sha256"]
    require(summary.get("candidate_data_sha256") == candidate == review.get("candidate_data_sha256"),
            "Approval, actual native prototype and image review refer to different candidate data")
    require(review.get("mechanical_data_sha256") == config.get("mechanical_data_sha256"), "Mechanical review binding differs")
    require(config["profile"] in ("sd", "hd") and isinstance(config["ballistic"], bool)
            and all(item.get("profile") == config["profile"] and item.get("ballistic") == config["ballistic"]
                    for item in (summary, review)), "Profile/doctrine attribution differs")
    tolerance = summary.get("tolerance_native_pixels", 0)
    require(0 < tolerance <= 2, "Calibration must retain the two-native-pixel ceiling")
    by_id = {case["id"]: case for case in summary["cases"]}
    actual_cases = [case for case in native["cases"] if case["spec"]["kind"] == "static"
                    and case["spec"]["ammo"] == "piercing-rounds-magazine"]
    require(len(actual_cases) == 8 and {case["spec"]["requested_rendered_direction"] for case in actual_cases} == set(DIRECTIONS),
            "Pilot does not cover all eight cardinal/diagonal piercing cases")
    heading = review.get("heading_template_calibration", {})
    case_ids = {case["id"] for case in actual_cases}
    require(heading.get("native_shapes_and_origins_confirmed") is True
            and set(heading.get("reviewed_cases", [])) == case_ids,
            "The reviewed native heading calibration is incomplete")
    measurement_path = confined(repo, heading.get("measurement_report", ""))
    require(sha(measurement_path) == heading.get("measurement_sha256"), "Heading measurement bytes changed")
    measurement = read(measurement_path)
    require(measurement.get("native_report_sha256") == native_sha
            and measurement.get("candidate_data_sha256") == candidate
            and measurement.get("held_out_controls_passed") is True,
            "Heading measurement provenance or held-out control verdict differs")
    controls = measurement.get("held_out_controls", [])
    require(len(controls) == 16 and all(item.get("control_registration_passed") is True for item in controls),
            "Heading control rows are incomplete")
    diagnostic_captures = measurement.get("source_capture_sha256", {})
    require(len(diagnostic_captures) == 120, "Heading diagnostic image bindings are incomplete")
    diagnostic_records = []
    for relative, expected in diagnostic_captures.items():
        require(relative.startswith("minigun-firing/"), "Unexpected heading diagnostic image identity")
        image_path = confined(repo, summary_path.parent / relative)
        require(sha(image_path) == expected, "Heading diagnostic image bytes changed")
        diagnostic_records.append(file_record(repo, image_path))
    image_records = []
    for case in actual_cases:
        measured = by_id.get(case["id"], {})
        require(measured.get("requested_direction") == measured.get("observed_direction") == case["spec"]["requested_rendered_direction"]
                and measured.get("failures") == [] and measured.get("pending_review") == [],
                "A pilot direction or per-case native image review is incomplete")
        row = next(item for item in case["rows"] if item["variant"] == "native")
        captures = {capture["shot_offset"]: capture for capture in row["captures"]}
        for visual in ("flash", "projectile"):
            if visual == "projectile" and not row["projectiles"]:
                require(measured.get(visual, {}).get("status") == "not_applicable_native_instant_delivery",
                        "Missing native projectile was not explicitly classified")
                continue
            effect = measured.get(visual, {})
            first = effect.get("first_visible_offset")
            require(first in captures and first <= 3, "First native visual is missing or too late")
            capture = captures[first]
            annotation = review.get("cases", {}).get(case["id"], {}).get(visual, {})
            require(annotation.get("capture") == capture["path"] and annotation.get("native_visibility_confirmed") is True,
                    "Visual review is not bound to the actual first native image")
            image_path = confined(repo, summary_path.parent / capture["path"])
            require(sha(image_path) == annotation.get("sha256"), "Reviewed native image bytes changed")
            point = annotation.get("origin_pixels")
            require(isinstance(point, list) and len(point) == 2 and all(isinstance(v, (int, float)) and math.isfinite(v) for v in point)
                    and math.dist(point, [160, 160]) / capture["zoom"] <= tolerance, "Reviewed native origin exceeds tolerance")
            if visual == "flash":
                require(annotation.get("first_appearance_and_decay_reviewed") is True, "Flash decay review is incomplete")
                offsets = [-1, 0, 1, 2, 3, 12, 96]
                reviewed = annotation.get("reviewed_captures", [])
                require(sorted(annotation.get("reviewed_offsets", [])) == offsets and len(reviewed) == 7
                        and sorted(item.get("shot_offset") for item in reviewed) == offsets,
                        "The seven baseline/first-flash/decay review images are incomplete")
                for item in reviewed:
                    expected_capture = captures.get(item["shot_offset"], {})
                    require(item.get("capture") == expected_capture.get("path"), "Decay review does not bind to the native capture")
                    reviewed_path = confined(repo, summary_path.parent / item["capture"])
                    require(sha(reviewed_path) == item.get("sha256"), "Reviewed decay image bytes changed")
                    image_records.append(file_record(repo, reviewed_path))
            image_records.append(file_record(repo, image_path))
    return {"passed": True, "profile": config["profile"], "ballistic": config["ballistic"],
            "source_sha256": SOURCE, "candidate_data_sha256": candidate, "directions": DIRECTIONS,
            "tolerance_native_pixels": tolerance, "summary": file_record(repo, summary_path),
            "review": file_record(repo, review_path), "native_report": file_record(repo, native_path),
            "heading_measurement": file_record(repo, measurement_path), "diagnostic_images": diagnostic_records,
            "reviewed_images": image_records, "scope": "pilot-calibration-only; final four-config promotion gates remain"}


def copy_once(source, target):
    if fs(target).exists():
        require(sha(source) == sha(target), "Existing seed destination differs; refusing overwrite: " + str(target))
        return False
    fs(target.parent).mkdir(parents=True, exist_ok=True)
    temporary = target.with_name(target.name + ".seed-partial")
    require(not fs(temporary).exists(), "Interrupted seed copy needs explicit review: " + str(temporary))
    shutil.copyfile(fs(source), fs(temporary))
    require(sha(source) == sha(temporary), "Seed copy hash mismatch")
    fs(temporary).rename(fs(target))
    return True


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("task", choices=("validate", "seed", "chunk"))
    parser.add_argument("--repo", type=Path, required=True)
    parser.add_argument("--full-root", type=Path)
    parser.add_argument("--approval"); parser.add_argument("--approval-sha256")
    parser.add_argument("--review"); parser.add_argument("--review-sha256")
    parser.add_argument("--allow-missing-approval", action="store_true")
    parser.add_argument("--directions")
    args = parser.parse_args()
    repo = args.repo.resolve()
    require((repo / "scripts/esir-housekeeping.ps1").is_file() and (repo / GEN / "render_separated.py").is_file(), "Wrong workspace")
    records, pilot_stats, icons = baseline(repo)
    gate = {"passed": False, "reason": "Approved report/review not supplied"}
    if args.approval or args.review or not args.allow_missing_approval:
        gate = approval(repo, args.approval, args.approval_sha256, args.review, args.review_sha256)
    require(args.task == "validate" or gate["passed"], "Mutation/chunk verification requires the approved pilot gate")
    full_stats, full_records = None, {}
    target = None
    if args.full_root:
        target = confined(repo, args.full_root, exists=False)
        permitted_parent = confined(repo, ROOT)
        require(target.parent == permitted_parent and target.name.startswith("separated-v2-full-"),
                "Full root must be a dedicated separated-v2-full-* sibling beneath handoff-256")
        require(target != confined(repo, PILOT), "Pilot cannot be an output")
    if args.task == "seed":
        require(target is not None and fs(target).is_dir(), "Register the fresh destination before copying")
        # The launcher establishes ownership first. Copies never use hard links.
        require(fs(target / "full-render-stage.json").is_file(), "Missing registered launcher ownership manifest")
        copied = 0
        for record in records.values():
            copied += copy_once(confined(repo, Path(PILOT) / record["path"]), confined(repo, target / record["path"], exists=False))
        for name in ("render-configuration.json", "render-records.jsonl"):
            copy_once(confined(repo, Path(PILOT) / name), target / name)
        for icon in icons:
            source = confined(repo, icon["path"])
            # Keep the complete relative identity under reuse-icons; do not regenerate it.
            copy_once(source, target / "reuse-icons" / icon["path"])
    if target and fs(target / "render-records.jsonl").exists():
        subset = None
        if args.task == "chunk":
            require(args.directions, "Chunk directions are required")
            directions = [int(value) for value in args.directions.split(",")]
            require(len(directions) == len(set(directions)) and all(0 <= value < 256 for value in directions), "Bad chunk directions")
            subset = {key for key in REQUIRED if key[0] in ("upper", "full") and key[1] in directions}
        full_records, full_stats = journal(repo, target, subset)
    elif args.task == "chunk":
        raise ValueError("Chunk journal is missing")
    available = set(full_records) if full_stats else set(records)
    missing = REQUIRED - available
    remaining_directions = sorted({key[1] for key in missing if key[0] != "base"})
    require(not any(key[0] == "base" for key in missing), "The retained fixed base is missing")
    result = {"schema": "esir.minigun.full-render-validation.v1", "approved_configuration_hash": CONFIG,
              "approval": gate, "pilot": pilot_stats, "full": full_stats, "reusable_icons": icons,
              "required_passes": len(REQUIRED), "remaining_passes": len(missing),
              "remaining_directions": remaining_directions, "complete": not missing,
              "ready_to_render": gate["passed"], "source_pins": PINS,
              "estimated_remaining_seconds": len(missing) * 3.13,
              "estimated_remaining_bytes_with_margin": math.ceil(len(missing) * pilot_stats["bytes"] / 466 * 1.5)}
    print(json.dumps(result, separators=(",", ":")))


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        print(json.dumps({"validation_failed": True, "error": str(error)}), file=sys.stderr)
        raise SystemExit(2)
