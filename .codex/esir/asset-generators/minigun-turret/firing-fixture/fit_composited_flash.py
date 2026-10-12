"""Recover native flash foreground from paired backgrounds; never approve alignment.

The translation search uses actual native pixels, without an expected muzzle
position or a CPU-rotated sprite. The existing raw-correlation report is retained.
"""
import argparse
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

from analyze_fixture import fs_path, rgb, sha


def recover(s0, b0, s1, b1):
    d0, d1 = s0 - b0, s1 - b1
    difference = b1 - b0
    denominator = (difference * difference).sum(axis=2)
    alpha = np.clip(((d0 - d1) * difference).sum(axis=2)
                    / np.maximum(denominator, 1), 0, 1)
    foreground = (d0 + alpha[:, :, None] * b0
                  + d1 + alpha[:, :, None] * b1) / 2
    support = (np.max(np.maximum(d0, d1), axis=2) > 12).astype(np.uint8) * 255
    weights = (np.asarray(Image.fromarray(support).filter(ImageFilter.MaxFilter(7)),
                          dtype=np.float32) / 255 * (denominator > 25))
    if weights.sum() < 20:
        raise ValueError("Insufficient independent-background support")
    return foreground, alpha, weights


def fit(delta, background, foreground, alpha, weights):
    h, w = alpha.shape
    rows, cols = delta.shape[:2]
    # Current native extents447/383 pad to448/384; preserve the full valid crop.
    fft_shape = tuple(((extent + 63) // 64) * 64 for extent in (rows + h - 1, cols + w - 1))

    def correlate(a, b):
        return np.fft.irfft2(np.fft.rfft2(a, s=fft_shape)
                            * np.conj(np.fft.rfft2(b, s=fft_shape)),
                            s=fft_shape)[:rows-h+1, :cols-w+1]

    dot = np.zeros((rows-h+1, cols-w+1))
    energy = dot.copy()
    for channel in range(3):
        d, b, f = delta[:, :, channel], background[:, :, channel], foreground[:, :, channel]
        dot += correlate(d, f * weights) + correlate(b, alpha * f * weights)
        energy += (correlate(d*d, weights) + 2 * correlate(d*b, alpha * weights)
                   + correlate(b*b, alpha*alpha * weights))
    template_energy = float((foreground*foreground * weights[:, :, None]).sum())
    loss = np.maximum(0, energy + template_energy - 2*dot) / max(template_energy, 1)
    y, x = np.unravel_index(np.argmin(loss), loss.shape)
    distant = loss.copy()
    distant[max(0, y-8):y+9, max(0, x-8):x+9] = np.inf
    return {
        "origin_pixels": [int(x+64), int(y+64)],
        "relative_sse": float(loss[y, x]),
        "next_distant_sse": float(distant.min()),
        "cosine_at_best": float(dot[y, x] / np.sqrt(max(energy[y, x], 1)
                                                   * max(template_energy, 1))),
        "weighted_support_pixels": int(np.count_nonzero(weights)),
        "approved": False,
    }


def run(root, raw_report, output):
    root, raw_report, output = fs_path(root), fs_path(raw_report), fs_path(output)
    report = json.loads((root / "native-report.json").read_text(encoding="utf-8-sig"))
    raw = json.loads(raw_report.read_text(encoding="utf-8-sig"))
    if raw["native_report_sha256"] != sha(root / "native-report.json"):
        raise ValueError("Paired-height evidence belongs to a different native run")
    output.mkdir(parents=True, exist_ok=True)
    results, held_out = [], []
    evidence_hashes = {}

    def capture(path):
        evidence_hashes[path] = sha(root / path)
        return rgb(root / path)

    for case in report["cases"]:
        if case["spec"]["kind"] != "static":
            continue
        variants = {row["variant"]: row for row in case["rows"]}
        caps = {name: {cap["shot_offset"]: cap for cap in row["captures"]}
                for name, row in variants.items()}
        blank_before = capture(caps["blank"][-1]["path"])
        for variant in ("native", "flash"):
            group = report["heading_flash_templates"][case["id"] + "-" + variant]
            controls = {cap["shot_offset"]: cap for cap in group["captures"]}
            baseline = capture(controls[-1]["path"])
            before = capture(caps[variant][-1]["path"])
            definitions = group["definitions"]
            count = len(definitions) // 2
            variation = group["source_effect"]["graphics_variation"]
            if count != 25 or len(definitions) != 50:
                raise ValueError("Expected five native rays and five variations at two heights")
            for offset in (0, 1):
                control = controls[offset]
                origins = control["runtime_attachment_origins"]
                if (control["cell_size"] != 256 or control["zoom"] != 2
                        or len(origins) != len(definitions)
                        or any(abs(x-(128+i*256)) > 1e-5 or abs(y-128) > 1e-5
                               for i, (x, y) in enumerate(origins))):
                    raise ValueError("Native template cell registration changed")
                atlas = capture(controls[offset]["path"])
                actual = capture(caps[variant][offset]["path"])
                background = before + capture(caps["blank"][offset]["path"]) - blank_before
                alternatives = []
                for index, definition in enumerate(definitions[:count]):
                    if definition["variation"] != variation:
                        continue
                    other = index + count
                    elevated = definitions[other]
                    if (definition["height"] != 0 or elevated["height"] != 1
                            or definition["ray_mode"] != elevated["ray_mode"]
                            or definition["variation"] != elevated["variation"]):
                        raise ValueError("Mismatched height-control pair")
                    pairs = [row for row in raw["paired_height_controls"]
                             if row["case"] == case["id"] and row["variant"] == variant
                             and row["shot_offset"] == offset and row["variation"] == variation
                             and row["ray_mode"] == definition["ray_mode"]]
                    if len(pairs) != 1 or pairs[0]["observed_height_translation"] != [0, -64]:
                        raise ValueError("Native height translation is not independently established")
                    if pairs[0]["sha256"] != evidence_hashes[controls[offset]["path"]]:
                        raise ValueError("Paired-height capture changed")
                    x0, x1 = index*256+64, other*256+64
                    recovered = recover(atlas[64:192, x0:x0+128], baseline[64:192, x0:x0+128],
                                        atlas[0:128, x1:x1+128], baseline[0:128, x1:x1+128])
                    measurement = fit(actual-background, background, *recovered)
                    measurement["ray_mode"] = definition["ray_mode"]
                    alternatives.append(measurement)
                    # A different native control cell has the same heading at the
                    # four cardinals, but a new background unused in recovery.
                    if (definition["ray_mode"] == "center"
                            and case["spec"]["requested_rendered_direction"] % 64 == 0):
                        target = index + 5
                        if (definitions[target]["ray_mode"] != "center_projected_once"
                                or definitions[target]["variation"] != variation
                                or definitions[target]["height"] != 0):
                            raise ValueError("Held-out cell is not the matching independent native ray")
                        left = target * 256
                        independent = atlas[:, left:left+256]
                        independent_background = baseline[:, left:left+256]
                        test = fit(independent-independent_background, independent_background, *recovered)
                        test.update(case=case["id"], variant=variant, shot_offset=offset,
                                    known_origin=[128, 128], recovery_ray="center",
                                    held_out_ray="center_projected_once")
                        test["control_registration_passed"] = (test["origin_pixels"] == [128, 128]
                                                               and test["relative_sse"] < .001)
                        held_out.append(test)
                alternatives.sort(key=lambda row: row["relative_sse"])
                best = dict(alternatives[0])
                best.update(case=case["id"], variant=variant, shot_offset=offset,
                            variation=variation, alternatives=alternatives,
                            capture=caps[variant][offset]["path"], zoom=caps[variant][offset]["zoom"],
                            status="unreviewed_compositing_measurement")
                best["proposed_anchor_error_native_pixels"] = float(
                    np.linalg.norm(np.asarray(best["origin_pixels"]) - [160, 160]) / best["zoom"])
                results.append(best)
                picture = Image.fromarray(np.clip(actual, 0, 255).astype(np.uint8))
                draw = ImageDraw.Draw(picture)
                x, y = best["origin_pixels"]
                draw.line((x-8, y, x+8, y), fill=(0, 255, 255))
                draw.line((x, y-8, x, y+8), fill=(0, 255, 255))
                picture.resize((960, 960), Image.Resampling.NEAREST).save(
                    output / f'{case["id"]}-{variant}-t{offset}.png')
    result = {
        "schema": 1, "status": "unreviewed_paired_background_compositing_measurements", "approved": False,
        "native_report_sha256": sha(root / "native-report.json"), "raw_report_sha256": sha(raw_report),
        "candidate_data_sha256": report["config"]["candidate_data_sha256"],
        "source_capture_sha256": evidence_hashes, "results": results, "held_out_controls": held_out,
        "held_out_controls_passed": bool(held_out) and all(r["control_registration_passed"] for r in held_out),
        "method": "native paired-background opacity recovery; full translation search; absolute compositing residual",
        "limitations": ["Pilot diagnostics do not approve final firing alignment",
                        "No proposed muzzle point, bright centroid or CPU rotation enters the search",
                        "Only visible flash frames 0 and 1 are fitted; decay remains a separate visual check",
                        "Nearby ray alternatives can share the attachment without identifying a unique constructor",
                        "Each next_distant_sse applies to that ray only, not a global ambiguity margin across rays",
                        "The two-pixel attachment limit still requires physical barrel and full native effect review"],
    }
    (output / "composited-flash-measurements.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    return result


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--evidence", type=Path, required=True)
    parser.add_argument("--raw-measurements", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    result = run(args.evidence, args.raw_measurements, args.output)
    print(json.dumps({"status": result["status"], "measurements": len(result["results"]),
                      "held_out_controls": len(result["held_out_controls"]),
                      "held_out_controls_passed": result["held_out_controls_passed"], "approved": False}))
