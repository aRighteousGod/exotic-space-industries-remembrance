"""Diagnose calibrated keel attachment placement without claiming exact bob access.

Registers displayed raw body frames in motion captures, estimates the one-tick
physics displacement from adjacent recorded poses, and compares native-body lift
with the configured entity-render attachment correction. Entity-render targets
inherit the base prototype height; their residual correction approximates bob.
Velocity/bob estimates are diagnostics, not a universal two-pixel certification.
"""
import argparse
import json
import math
from pathlib import Path

import numpy as np
from PIL import Image

from measure_twin_emitters import Evaluator, point


def wrapped_delta(value):
    return (value + .5) % 1 - .5


def geometry_anchor(evaluator, name, index, pivot, zoom):
    row = evaluator.anchors[name][index]
    return pivot + (point(row["anchor"]) - point(row["pivot"])) * evaluator.scale * zoom


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--bundle", required=True, type=Path)
    parser.add_argument("--art", required=True, type=Path)
    parser.add_argument("--lift", default=.625, type=float)
    parser.add_argument("--curve", nargs=3, type=float, metavar=("MINIMUM", "SPAN", "SPEED"),
                        help="Use the current stateless speed curve instead of a fixed lift")
    parser.add_argument("--draft", action="store_true")
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    evaluator = Evaluator(args.bundle, args.draft)
    metadata_file = args.art / "motion-poses.json"
    poses = json.loads(metadata_file.read_text())
    evaluator.hash(metadata_file)
    rows = []
    for number, pose in enumerate(poses):
        row = {"frame": number + 1, "tick": pose.get("tick"), "torso": pose["torso"],
               "speed": pose["speed"], "moving": pose["speed"] > .001}
        try:
            shot = args.art / "motion-day" / f"{number+1:03d}.png"
            evaluator.hash(shot)
            screen = np.asarray(Image.open(shot).convert("RGB"), dtype=np.float32) / 255
            zoom, centre, origin, ground, exact = evaluator.camera(pose, screen.shape)
            fit = evaluator.register(screen, pose, zoom, ground, {})
            prior = poses[max(0, number - 1)]
            following = poses[min(len(poses) - 1, number + 1)]
            velocity_direction = point(following["position"]) - point(prior["position"])
            length = np.linalg.norm(velocity_direction)
            if length > 1e-8:
                velocity_direction /= length
            else:
                velocity_direction = np.array([math.sin(pose["torso"] * math.tau),
                                               -math.cos(pose["torso"] * math.tau)])
            velocity = velocity_direction * pose["speed"]
            estimated_physics_ground = ground + velocity * 32 * zoom
            inferred_lift = (estimated_physics_ground[1] - fit["pivot"][1]) / (32 * zoom)
            inferred_lift -= pose["height"]
            elapsed = pose.get("tick", number * 12) - prior.get("tick", max(0, number - 1) * 12)
            turn_per_tick = wrapped_delta(pose["torso"] - prior["torso"]) / elapsed if elapsed else 0
            predicted = (pose["torso"] + turn_per_tick) % 1
            lookup_index = math.floor(predicted * 128 + .5) % 128
            # Keep quantized preview-body mismatch explicit. The full128 bundle
            # removes this draft limitation; the motion/bob inference stays approximate.
            attachments = []
            configured_lift = args.lift if not args.curve else (args.curve[0] + args.curve[1] *
                              np.clip(abs(pose["speed"]) / args.curve[2], 0, 1))
            attachment_pivot = estimated_physics_ground + [0, -(pose["height"] + configured_lift) * 32 * zoom]
            for name in ("keel_left", "keel_center", "keel_right"):
                body_anchor = geometry_anchor(evaluator, name, fit["body_index"], fit["pivot"], zoom)
                attachment = geometry_anchor(evaluator, name, lookup_index, attachment_pivot, zoom)
                attachments.append({"anchor": name, "displayed_tip_px": np.round(body_anchor, 6).tolist(),
                                    "estimated_attachment_px": np.round(attachment, 6).tolist(),
                                    "estimated_error_px": round(float(np.linalg.norm(attachment - body_anchor)), 6),
                                    "estimated_delta_px": np.round(attachment - body_anchor, 6).tolist()})
            row.update({"status": "diagnostic", "correlation": round(fit["correlation"], 6),
                        "body_index": fit["body_index"], "predicted_lookup_index": lookup_index,
                        "body_frame_exact": evaluator.source_count == 128,
                        "pivot_px": np.round(fit["pivot"], 6).tolist(),
                        "estimated_physics_displacement_px": np.round(velocity * 32 * zoom, 6).tolist(),
                        "inferred_residual_lift_tiles": round(float(inferred_lift), 6),
                        "configured_lift_tiles": float(configured_lift),
                        "estimated_vertical_residual_px": round(float((inferred_lift - configured_lift) * 32 * zoom), 6),
                        "attachments": attachments,
                        "confidence": "Raw-body registration is measured; displacement, turn and bob separation are inferred."})
        except (ValueError, FileNotFoundError) as error:
            row.update({"status": "unmeasurable", "reason": str(error)})
        rows.append(row)
    measured = [r for r in rows if r["status"] == "diagnostic"]
    moving = [r for r in measured if r["moving"]]
    report = {"kind": "reference17-keel-attachment-diagnostic", "certified": False,
              "draft": args.draft, "raw_source_directions": evaluator.source_count,
              "configured_lift_tiles": args.lift if not args.curve else None,
              "configured_curve": args.curve, "frames": len(rows), "measured": len(measured),
              "moving_estimated_vertical_residual_range_px":
                  [min(r["estimated_vertical_residual_px"] for r in moving),
                   max(r["estimated_vertical_residual_px"] for r in moving)] if moving else None,
              "results": rows, "sha256": evaluator.hashes,
              "scope": "Approximate entity-render attachment diagnostic. No current native bob API and no universal pixel guarantee. Draft eight-source body quantization is reported separately."}
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({key: value for key, value in report.items() if key not in ("results", "sha256")}))


if __name__ == "__main__":
    main()
