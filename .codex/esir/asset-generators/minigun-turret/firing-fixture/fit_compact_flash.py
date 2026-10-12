"""Measure actual native flash attachments from nine compact control cells.

This produces diagnostics, never a passed visual review. Every fit searches the
entire captured image. The expected muzzle is used only after that search.
"""
import argparse
import json
import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

from analyze_fixture import fs_path, rgb, sha
from fit_composited_flash import recover, fit

SCHEMA = "esir.minigun.compact-flash-measurements.v1"
RAYS = ["center_projected_twice", "source_projected_twice", "visual_projected_twice"]


def require(condition, message):
    if not condition:
        raise ValueError(message)


def inspect_controls(group, offset, atlas, baseline):
    """Recover A/B foreground, then independently locate the elevated C cell."""
    require(group.get("control_layout") == "paired-background-native-height-v1",
            "Unexpected compact control layout")
    definitions = group["definitions"]
    captures = {row["shot_offset"]: row for row in group["captures"]}
    require(set(captures) == {-1, 0, 1} and len(group["captures"]) == 3,
            "Compact control frame inventory differs")
    capture = captures[offset]
    origins = capture["runtime_attachment_origins"]
    require(len(definitions) == len(origins) == 9 and capture["cell_size"] == 256
            and capture["zoom"] == 2 and atlas.shape == baseline.shape == (256, 2304, 3),
            "Compact native control dimensions changed")
    require(all(abs(x-(128+index*256)) < 1e-5 and abs(y-128) < 1e-5
                for index, (x, y) in enumerate(origins)), "Control attachment coordinates changed")
    variation = group["source_effect"]["graphics_variation"]
    models, controls = [], []
    for ray_index, ray in enumerate(RAYS):
        start = ray_index * 3
        entries = definitions[start:start+3]
        require([row.get("role") for row in entries] == ["recovery-a", "recovery-b", "held-out-height"]
                and all(row["ray_mode"] == ray and row["variation"] == variation for row in entries)
                and entries[0]["height"] == entries[1]["height"] == 0
                and entries[2]["height"] == entries[2]["source_height"],
                "Control roles, actual source variation or height differ")
        require(math.isfinite(entries[2]["height"]) and 0 < entries[2]["height"] <= 1,
                "Compact window requires a positive authored height of at most one tile")
        xa, xb, xc = start*256, (start+1)*256, (start+2)*256
        recovered = recover(atlas[64:192, xa+64:xa+192], baseline[64:192, xa+64:xa+192],
                            atlas[64:192, xb+64:xb+192], baseline[64:192, xb+64:xb+192])
        independent = atlas[:, xc:xc+256]
        background = baseline[:, xc:xc+256]
        measured = fit(independent-background, background, *recovered)
        expected = [128, 128 - entries[2]["height"] * 64]
        measured.update(ray_mode=ray, known_origin=[128,128], native_height=entries[2]["height"],
                        expected_visual_origin=expected,
                        observed_height_translation=[measured["origin_pixels"][0]-128,
                                                     measured["origin_pixels"][1]-128],
                        control_registration_passed=(math.dist(measured["origin_pixels"], expected) <= .5
                                                     and measured["relative_sse"] < .001))
        controls.append(measured)
        models.append((ray, recovered))
    return models, controls


def run(root, output):
    root, output = fs_path(root), fs_path(output)
    report_path = root / "native-report.json"
    report = json.loads(report_path.read_text(encoding="utf-8-sig"))
    require(report["config"].get("compact_heading_templates") is True,
            "This run did not request the compact native controls")
    require(not (output / "compact-flash-measurements.json").exists(), "Refusing to overwrite diagnostics")
    output.mkdir(parents=True, exist_ok=True)
    hashes, results, held_out = {}, [], []

    def image(path):
        hashes[path] = sha(root / path)
        return rgb(root / path)

    for case in report["cases"]:
        if case["spec"]["kind"] != "static":
            continue
        rows = {row["variant"]: row for row in case["rows"]}
        captures = {key: {cap["shot_offset"]: cap for cap in row["captures"]}
                    for key, row in rows.items()}
        blank_before = image(captures["blank"][-1]["path"])
        for variant in ("native", "flash"):
            group = report["heading_flash_templates"][case["id"] + "-" + variant]
            controls = {row["shot_offset"]: row for row in group["captures"]}
            baseline = image(controls[-1]["path"])
            before = image(captures[variant][-1]["path"])
            for offset in (0, 1):
                atlas = image(controls[offset]["path"])
                models, checked = inspect_controls(group, offset, atlas, baseline)
                for control in checked:
                    control.update(case=case["id"], variant=variant, shot_offset=offset)
                held_out.extend(checked)
                cap = captures[variant][offset]
                actual = image(cap["path"])
                background = before + image(captures["blank"][offset]["path"]) - blank_before
                alternatives = []
                for ray, recovered in models:
                    match = fit(actual-background, background, *recovered)
                    match["ray_mode"] = ray
                    alternatives.append(match)
                alternatives.sort(key=lambda row: row["relative_sse"])
                best = dict(alternatives[0])
                close = [row for row in alternatives if row["relative_sse"] <= best["relative_sse"] + .02]
                best.update(case=case["id"], variant=variant, shot_offset=offset,
                            variation=group["source_effect"]["graphics_variation"], alternatives=alternatives,
                            capture=cap["path"], zoom=cap["zoom"],
                            approved=False,
                            status="unreviewed_compact_compositing_measurement",
                            competing_origin_spread_pixels=max(math.dist(row["origin_pixels"],best["origin_pixels"])
                                                               for row in close))
                best["proposed_anchor_error_native_pixels"] = math.dist(best["origin_pixels"], [160,160]) / cap["zoom"]
                results.append(best)
                panel = Image.fromarray(np.clip(actual,0,255).astype(np.uint8))
                draw = ImageDraw.Draw(panel)
                x,y = best["origin_pixels"]
                draw.line((x-8,y,x+8,y),fill=(0,255,255))
                draw.line((x,y-8,x,y+8),fill=(0,255,255))
                draw.rectangle((158,158,162,162),outline=(255,0,255))
                panel.save(output / f"{case['id']}-{variant}-t{offset}.png")
    result = {"schema":SCHEMA,"status":"unreviewed_compact_native_flash_measurements","approved":False,
              "native_report_sha256":sha(report_path),"candidate_data_sha256":report["config"]["candidate_data_sha256"],
              "source_capture_sha256":hashes,"results":results,"held_out_controls":held_out,
              "held_out_controls_passed":bool(held_out) and all(row["control_registration_passed"] for row in held_out),
              "method":"paired native backgrounds; full translation search; independent native-height heldout cells",
              "limitations":["Diagnostic fits require separate actual barrel, full native flash and decay image review",
                             "No expected muzzle point enters the fit; it is used only to report attachment error",
                             "Control height assumptions are tested against independently rendered pixels",
                             "Firing during changing aim remains a separate native capture review"]}
    (output / "compact-flash-measurements.json").write_text(json.dumps(result,indent=2)+"\n",encoding="utf-8")
    return result


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--evidence",type=Path,required=True)
    parser.add_argument("--output",type=Path,required=True)
    args = parser.parse_args()
    result = run(args.evidence,args.output)
    print(json.dumps({"measurements":len(result["results"]),"held_out_controls":len(result["held_out_controls"]),
                      "held_out_controls_passed":result["held_out_controls_passed"],"approved":False}))
