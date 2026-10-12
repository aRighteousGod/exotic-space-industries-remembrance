"""Stage deterministic firing cases and direction markers; never starts Factorio."""
from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path
import re
import shutil

from PIL import Image, ImageDraw
from evidence_contract import build_candidate_asset_manifest

AMMO = ["firearm-magazine", "piercing-rounds-magazine", "uranium-rounds-magazine"] + [
    f"ei-{family}-ammo" for family in
    ("compound", "corrosive", "cryo", "oxyfluoride", "morphium", "hexafluoride", "arc", "neutron")]
PILOT_DIRECTIONS = list(range(0, 256, 32))


def lua(value):
    if value is None:
        return "nil"
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, (int, float)):
        if not math.isfinite(value):
            raise ValueError("Non-finite fixture number")
        return repr(value)
    if isinstance(value, str):
        return json.dumps(value, ensure_ascii=True)
    if isinstance(value, list):
        return "{" + ",".join(lua(x) for x in value) + "}"
    return "{" + ",".join("[" + lua(k) + "]=" + lua(v) for k, v in value.items()) + "}"


def inverse_projection(direction):
    """Hypothesis until the native direction marker verifies it for this atlas."""
    angle = direction * math.tau / 256
    return math.atan2(math.sqrt(2) * math.sin(angle), math.cos(angle)) / math.tau % 1


def marker(output, indices):
    image = Image.new("RGBA", (72 * 16, 12 * math.ceil(len(indices) / 16)))
    draw = ImageDraw.Draw(image)
    for frame, direction in enumerate(indices):
        x, y = frame % 16 * 72, frame // 16 * 12
        bits = [(direction >> bit) & 1 for bit in range(8)]
        colors = [(255, 0, 255)] + [(245, 245, 245) if b else (12, 12, 12)
                                  for b in bits + [1 - b for b in bits]] + [(0, 255, 255)]
        for cell, color in enumerate(colors):
            draw.rectangle((x + cell * 4, y, x + cell * 4 + 3, y + 11), fill=(*color, 255))
    output.parent.mkdir(parents=True, exist_ok=True)
    image.save(output)


def build(args):
    destination = args.output.resolve()
    destination.mkdir(parents=True, exist_ok=True)
    calibration_only = getattr(args, "calibration_only", False)
    if calibration_only and getattr(args, "include_moving", False):
        raise ValueError("Calibration-only is eight static cases; use ordinary pilot/full coverage for moving fire")
    include_moving = not calibration_only or getattr(args, "include_moving", False)
    include_wired = getattr(args, "include_wired_preview", False)
    compact_heading_templates = getattr(args, "compact_heading_templates", False)
    heading_templates = getattr(args, "heading_templates", False) or compact_heading_templates
    if compact_heading_templates and getattr(args, "heading_templates", False):
        raise ValueError("Choose compact or diagnostic heading controls, not both")
    if calibration_only and args.coverage != "pilot":
        raise ValueError("Calibration-only is an eight-heading pilot; full acceptance cannot use this subset")
    anchors = json.loads(args.anchors.read_text(encoding="utf-8-sig"))
    rows = {row["direction"]: row for row in anchors["visual_anchors"]}
    if set(rows) != set(range(256)):
        raise ValueError("Expected all 256 geometry proposals, even for an eight-view pilot")
    calibration = None
    if args.calibration:
        calibration = json.loads(args.calibration.read_text(encoding="utf-8-sig"))
        if calibration.get("status") not in ("pilot_projection_verified", "full_projection_verified"):
            raise ValueError("Calibration does not contain a verified native inverse-projection result")
        if calibration.get("source_sha256") != anchors["source_sha256"]:
            raise ValueError("Calibration belongs to a different model")
    elif args.coverage == "full":
        raise ValueError("Full coverage requires a native pilot projection-calibration.json")
    directions = PILOT_DIRECTIONS if args.coverage == "pilot" else list(range(256))
    cases = []
    ammo_names = ["piercing-rounds-magazine"] if calibration_only else AMMO
    for ammo in ammo_names:
        for direction in directions if ammo == "piercing-rounds-magazine" else PILOT_DIRECTIONS:
            row = rows[direction]
            cases.append({"id": f"d{direction:03d}-{ammo}", "ammo": ammo,
                          "kind": "static", "case_ticks": 220, "rounds": 1,
                          "requested_rendered_direction": direction,
                          "target_orientation": inverse_projection(direction),
                          "visual_offset_tiles": row["visual_offset_tiles"]})
    if include_moving:
        cases.append({"id": "moving-aim-piercing", "ammo": "piercing-rounds-magazine",
                      "kind": "moving", "case_ticks": 420, "rounds": 1024,
                      "slew_ticks": 240, "requested_rendered_direction": 0,
                      "target_orientation": 0.0, "visual_offset_tiles": rows[0]["visual_offset_tiles"]})
    copied = destination / "candidate-graphics-data.lua"
    if args.candidate_data.resolve() != copied.resolve():
        shutil.copy2(args.candidate_data, copied)
    if args.candidate_assets:
        shutil.copytree(args.candidate_assets, destination / "candidate", dirs_exist_ok=True)
    if args.mechanical_data:
        shutil.copy2(args.mechanical_data, destination / "candidate-mechanical-data.lua")
    else:
        (destination / "candidate-mechanical-data.lua").write_text(
            'return {status="connector_deferred_by_user",connector_anchor_calibrated=false}\n',encoding="utf-8")
    candidate_text = copied.read_text(encoding="utf-8-sig")
    fixture_prefix = "__zzz-esir-minigun-firing__/"
    missing = []
    for path in re.findall(r'"([^"\n]+\.png)"', candidate_text):
        if path.startswith(fixture_prefix) and not (destination / path[len(fixture_prefix):]).is_file():
            missing.append(path)
    if missing:
        raise FileNotFoundError("Candidate references missing fixture images: " + repr(missing[:8]))
    config = {"schema": 1, "ballistic": args.mode == "on", "profile": args.profile,
              "coverage": args.coverage, "direction_count": len(directions),
              "case_ticks": 220, "ammo_names": ammo_names, "case_count": len(cases),
              "calibration_only": calibration_only, "include_moving": include_moving,
              "include_wired_preview": include_wired,
              "heading_templates": heading_templates,
              "compact_heading_templates": compact_heading_templates,
              "maximum_native_pixel_error": 2, "attachment_goal_native_pixels": 1,
              "source_sha256": anchors["source_sha256"],
              "anchor_status": anchors.get("status"),
              "height_compensation_verified": anchors.get("height_compensation_verified", False),
              "projection_prior_status": calibration.get("status") if calibration else "uncalibrated_hypothesis",
              "candidate_data_sha256": hashlib.sha256(copied.read_bytes()).hexdigest()}
    config["mechanical_data_sha256"] = hashlib.sha256((destination / "candidate-mechanical-data.lua").read_bytes()).hexdigest()
    assets = build_candidate_asset_manifest(copied, destination / "candidate")
    assets_path = destination / "candidate-assets-manifest.json"
    assets_path.write_text(json.dumps(assets, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    config["assets_manifest_sha256"] = hashlib.sha256(assets_path.read_bytes()).hexdigest()
    (destination / "test-config.lua").write_text("return " + lua(config) + "\n", encoding="utf-8")
    (destination / "cases.lua").write_text("return " + lua(cases) + "\n", encoding="utf-8")
    marker(destination / "graphics/direction-code.png", directions)
    if compact_heading_templates:
        for role, color in (("a", (32, 48, 64, 255)), ("b", (192, 176, 160, 255)),
                            ("c", (96, 112, 80, 255))):
            Image.new("RGBA", (128, 128), color).save(destination / f"graphics/compact-background-{role}.png")
    shutil.copy2(args.anchors, destination / "muzzle-anchors.json")
    manifest = {"schema": 1, "config": config, "cases": cases,
                "benchmark_ticks": sum(case["case_ticks"] for case in cases) + 90,
                "planned_direction_captures": 8 * len(cases),
                "planned_muzzle_clips": 4 * 20 * len(cases),
                "maximum_moving_shot_captures": 4 * (240 + 21) if include_moving else 0,
                "moving_capture_policy": "one actual frame per variant and native tick; every shot retains its frame reference",
                "planned_wired_captures": 8 if include_wired else 0,
                "planned_flash_template_atlases": 14 * len(ammo_names),
                "planned_heading_template_atlases": (6 if compact_heading_templates else 28) * sum(case["kind"] == "static" for case in cases) if heading_templates else 0,
                "heading_template_cells": 9 if compact_heading_templates else None,
                "status": "staged_not_native_validated"}
    (destination / "fixture-plan.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({key: manifest[key] for key in ("benchmark_ticks", "planned_direction_captures", "planned_muzzle_clips", "status")}))
    return manifest


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--anchors", type=Path, required=True)
    parser.add_argument("--candidate-data", type=Path, required=True)
    parser.add_argument("--candidate-assets", type=Path)
    parser.add_argument("--mechanical-data", type=Path)
    parser.add_argument("--calibration", type=Path)
    parser.add_argument("--mode", choices=("on", "off"), required=True)
    parser.add_argument("--profile", choices=("sd", "hd"), required=True)
    parser.add_argument("--coverage", choices=("pilot", "full"), default="pilot")
    parser.add_argument("--calibration-only",action="store_true")
    parser.add_argument("--include-moving",action="store_true")
    parser.add_argument("--include-wired-preview",action="store_true")
    parser.add_argument("--heading-templates",action="store_true")
    parser.add_argument("--compact-heading-templates",action="store_true")
    build(parser.parse_args())
