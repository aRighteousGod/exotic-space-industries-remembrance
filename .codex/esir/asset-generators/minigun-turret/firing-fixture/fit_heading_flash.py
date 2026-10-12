"""Measure flash pixels against actual heading-matched native template pixels.

Only template controls use their independent runtime attachment registration.
No proposed muzzle coordinate enters a correlation search. Results remain
unapproved until the native images and control calibration are inspected.
"""
import argparse
import json
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw
from analyze_fixture import fs_path, rgb, sha
from fit_flash_origin import correlate, signal


def best_match(source, templates):
    if float((source * source).sum()) < 500:
        return {"status": "no_visible_signal", "approved": False}
    rows = []
    for template in templates:
        if float((template["pixels"] ** 2).sum()) < 500:
            continue
        row = correlate(source, template["pixels"])
        row["template"] = template["identity"]
        rows.append(row)
    if not rows:
        return {"status": "no_template_signal", "approved": False}
    rows.sort(key=lambda row: row["score"], reverse=True)
    best = dict(rows[0])
    comparable = [row for row in rows if row["score"] >= best["score"] - .05]
    spread = max(float(np.linalg.norm(np.asarray(row["origin_pixels"]) - best["origin_pixels"]))
                 for row in comparable)
    best.update(competing_origin_spread_pixels=spread, alternatives=rows[:5],
                status="review_candidate" if best["score"] >= .65 and spread <= 3
                and best["translation_peak_margin"] >= .04 else "ambiguous", approved=False)
    return best


def run(root, output):
    root, output = fs_path(root), fs_path(output)
    report = json.loads((root / "native-report.json").read_text(encoding="utf-8-sig"))
    output.mkdir(parents=True, exist_ok=True)
    results, paired = [], []
    for case in report["cases"]:
        if case["spec"]["kind"] != "static":
            continue
        variants = {row["variant"]: row for row in case["rows"]}
        captures = {name: {cap["shot_offset"]: cap for cap in row["captures"]}
                    for name, row in variants.items()}
        for variant in ("native", "flash"):
            group = report["heading_flash_templates"][case["id"] + "-" + variant]
            t_caps = {cap["shot_offset"]: cap for cap in group["captures"]}
            baseline = rgb(root / t_caps[-1]["path"])
            definitions = group["definitions"]
            count = len(definitions) // 2
            native_variation = group.get("source_effect", {}).get("graphics_variation")
            if len(definitions) != count * 2 or any(d["height"] != 0 for d in definitions[:count]):
                raise ValueError("Expected complete zero/native-height paired variations")
            templates = []
            for offset, cap in sorted(t_caps.items()):
                if offset < 0:
                    continue
                atlas = rgb(root / cap["path"]) - baseline
                origins = cap["runtime_attachment_origins"]
                if len(origins) != len(definitions):
                    raise ValueError("Native template attachment coordinates are missing")
                for index in range(count):
                    cx, cy = origins[index]
                    local_x = cx - index * 256
                    if abs(local_x - 128) > 1e-5 or abs(cy - 128) > 1e-5:
                        raise ValueError("Template camera registration is not centered")
                    tile = signal(atlas[64:192, index * 256 + 64:index * 256 + 192])
                    identity = {"variation": definitions[index]["variation"], "shot_offset": offset,
                                "ray_mode": definitions[index].get("ray_mode", "orientation_setter"),
                                "capture": cap["path"], "sha256": sha(root / cap["path"]),
                                "template_height": 0, "attachment_in_crop": [64, 64],
                                "control_runtime_origin": origins[index]}
                    templates.append({"pixels": tile, "identity": identity})
                    if offset in (0, 1, 2):
                        other = index + count
                        elevated = signal(atlas[:, other * 256:(other + 1) * 256])
                        pair = correlate(elevated, tile)
                        pair.update(case=case["id"], variant=variant, variation=definitions[index]["variation"],
                                    ray_mode=definitions[index].get("ray_mode", "orientation_setter"),
                                    shot_offset=offset, source_height=definitions[other]["height"],
                                    zero_origin_local=[128, 128],
                                    observed_height_translation=[pair["origin_pixels"][0] - 128,
                                                                 pair["origin_pixels"][1] - 128],
                                    capture=cap["path"], sha256=sha(root / cap["path"]), approved=False)
                        paired.append(pair)
            before = rgb(root / captures[variant][-1]["path"])
            blank_before = rgb(root / captures["blank"][-1]["path"])
            for offset in range(13):
                cap = captures[variant][offset]
                native = rgb(root / cap["path"])
                delta = native - before - (rgb(root / captures["blank"][offset]["path"]) - blank_before)
                available = [template for template in templates
                             if abs(template["identity"]["shot_offset"] - offset) <= 2
                             and (not isinstance(native_variation, int) or
                                  template["identity"]["variation"] == native_variation)]
                fit = best_match(signal(delta), available)
                fit.update(case=case["id"], variant=variant, shot_offset=offset, capture=cap["path"],
                           sha256=sha(root / cap["path"]), template_orientation_status=group["status"],
                           effect_orientation=group.get("source_effect", {}).get("orientation"),
                           native_graphics_variation=native_variation,
                           method="heading_matched_native_pixels_no_CPU_rotation", zoom=cap["zoom"])
                if "origin_pixels" in fit:
                    # This comparison is diagnostic only; the anchor never entered the search.
                    fit["proposed_anchor_error_native_pixels"] = float(
                        np.linalg.norm(np.asarray(fit["origin_pixels"]) - [160, 160]) / cap["zoom"])
                    picture = Image.fromarray(native.astype(np.uint8))
                    draw = ImageDraw.Draw(picture)
                    x, y = fit["origin_pixels"]
                    draw.line((x - 8, y, x + 8, y), fill=(0, 255, 255), width=1)
                    draw.line((x, y - 8, x, y + 8), fill=(0, 255, 255), width=1)
                    draw.rectangle((158, 158, 162, 162), outline=(255, 0, 255))
                    picture.resize((960, 960), Image.Resampling.NEAREST).save(
                        output / f'{case["id"]}-{variant}-t{offset}.png')
                results.append(fit)
    result = {"schema": 1, "status": "unreviewed_heading_pixel_measurements", "approved": False,
              "native_report_sha256": sha(root / "native-report.json"),
              "candidate_data_sha256": report["config"]["candidate_data_sha256"],
              "results": results, "paired_height_controls": paired,
              "limitations": ["Runtime template attachment positions must agree with independent source-frame calibration",
                              "First appearance, decay, tracer overlap and ambiguous matches require native visual inspection",
                              "No expected muzzle coordinate or CPU angle rotation enters the search",
                              "This tool does not approve alignment or infer first-projectile origins"]}
    (output / "heading-flash-measurements.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    return result


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--evidence", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    result = run(args.evidence, args.output)
    print(json.dumps({"status": result["status"], "measurements": len(result["results"]), "approved": False}))
