"""Compare native Standard/Off captures at identical unarmed reference poses.

This tests rendered pixels rather than live rendering handles. It deliberately
keeps naturally occluded individual keel tips diagnostic: the whole moving
craft must show a trail in each captured day/night view.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path

import numpy as np
from PIL import Image


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--enabled", type=Path, required=True, help="Enabled run script-output directory")
    parser.add_argument("--off", type=Path, required=True, help="Off run script-output directory")
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--min-pixels", type=int, default=12)
    args = parser.parse_args()
    enabled_manifest = json.loads((args.enabled / "anisetron-regression/captures.json").read_text(encoding="utf-8-sig"))
    off_manifest = json.loads((args.off / "anisetron-regression/captures.json").read_text(encoding="utf-8-sig"))
    off_frames = {frame["path"]: frame for frame in off_manifest["frames"]}
    rows = []
    passed = True
    for frame in enabled_manifest["frames"]:
        if frame["actor"] != "reference" or "/trail-" not in frame["path"]:
            continue
        baseline = off_frames.get(frame["path"])
        row = {"path": frame["path"], "tick": frame["tick"]}
        if not baseline:
            row.update(pass_=False, reason="missing Off comparison")
        else:
            pose_error = max(abs(frame["position"][axis] - baseline["position"][axis]) for axis in ("x", "y"))
            torso_error = abs((frame["torso"] - baseline["torso"] + .5) % 1 - .5)
            if pose_error > .00001 or torso_error > .00001 or frame["camera"] != baseline["camera"]:
                row.update(pass_=False, reason="native pose/camera mismatch", pose_error=pose_error, torso_error=torso_error)
            else:
                enabled = np.asarray(Image.open(args.enabled / frame["path"]).convert("RGB"), dtype=np.int16)
                off = np.asarray(Image.open(args.off / frame["path"]).convert("RGB"), dtype=np.int16)
                changed = np.max(np.abs(enabled - off), axis=2) >= 20
                red, green, blue = enabled[:, :, 0], enabled[:, :, 1], enabled[:, :, 2]
                chromatic = (green >= red + 12) & (green >= blue + 6) & (green >= 45)
                delta_green = (green - off[:, :, 1]) >= 10
                pixels = changed & chromatic & delta_green
                # Rendering decorations can vary by a few pixels with bob. Use
                # broad local corridors around the three projected tips and
                # report the individual counts without inventing visibility
                # when a tip is hidden behind the preserved original model.
                height, width = pixels.shape
                yy, xx = np.indices(pixels.shape)
                local = np.zeros(pixels.shape, dtype=bool)
                per_tip = []
                for offset in frame["projection"]["keel_tips"]:
                    # Direction table is already camera projected. Native
                    # source hover is 1.8; the measured bob may shift by <1 tile.
                    px = width / 2 + 32 * offset[0]
                    py = height / 2 + 32 * (5 + offset[1] - 1.8)
                    corridor = (np.abs(xx - px) <= 42) & (yy >= py - 42) & (yy <= py + 52)
                    per_tip.append(int(np.count_nonzero(pixels & corridor)))
                    local |= corridor
                count = int(np.count_nonzero(pixels & local))
                moving = bool(frame.get("visual", {}).get("moving"))
                real_night = "/trail-night/" not in frame["path"] or frame.get("darkness", 0) > .5
                row.update(pass_=real_night and (count >= args.min_pixels if moving else count <= 4),
                           moving=moving, darkness=frame.get("darkness"), visible_green_pixels=count,
                           per_tip_corridor_pixels=per_tip, all_changed_green_pixels=int(pixels.sum()),
                           minimum=args.min_pixels)
                overlay = enabled.astype(np.uint8).copy()
                overlay[pixels & local] = (255, 0, 255)
                diagnostics = args.output.parent / "trail-pixel-diagnostics"
                diagnostics.mkdir(parents=True, exist_ok=True)
                destination = diagnostics / (Path(frame["path"]).parent.name + "-" + Path(frame["path"]).name)
                Image.fromarray(overlay).save(destination)
                row["diagnostic"] = str(destination)
        row["pass"] = row.pop("pass_")
        passed &= row["pass"]
        rows.append(row)
    passed &= len(rows) == 10
    result = {"pass": bool(passed), "samples": len(rows), "results": rows,
              "scope": "Actual engine pixel difference at identical reference-vehicle poses, Standard versus Off. Per-tip corridor overlap and native rear occlusion prevent claiming three separately visible tips."}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"pass": bool(passed), "samples": len(rows), "output": str(args.output)}))
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
