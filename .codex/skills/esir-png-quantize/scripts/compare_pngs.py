"""Compare registered original/indexed cells; preview compositing is ordinary alpha-over."""
from __future__ import annotations

import argparse
import json
from functools import lru_cache
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

from png_common import (canonical, check_output, digest, load_spec, overlaps, read_json,
                        require, sha, write_json)

BACKGROUNDS = [(42, 45, 43), (207, 210, 204)]


def run(spec, conversion, output):
    job = load_spec(spec)
    conversion = Path(conversion).resolve()
    output = check_output(job, output)
    require(not overlaps(conversion, output), "Comparison output overlaps conversion")
    require(not output.exists() or output.is_dir() and not any(output.iterdir()), "Use an empty comparison directory")
    contract = read_json(conversion / "source-contract.json")
    report = read_json(conversion / "conversion-report.json")
    require(report.get("complete") and report["source_contract_sha256"] == sha(canonical(contract)), "Incomplete/inconsistent conversion")
    require(job["spec_sha256"] == contract["spec_sha256"] and str(job["source"]) == contract["source_root"], "Comparison spec/source differs from conversion")
    records = {r["path"]: r for r in report["artifacts"]}
    require(set(records) == set(job["files"]), "Conversion coverage differs")
    for rel, row in job["files"].items():
        require(row["sha256"] == records[rel]["source_sha256"] and digest(conversion / "assets" / rel) == records[rel]["sha256"], "Comparison input changed: " + rel)
    output.mkdir(parents=True, exist_ok=True)
    font = ImageFont.load_default(size=15)

    @lru_cache(maxsize=8)
    def atlas(root, rel):
        with Image.open(root / rel) as im:
            return im.convert("RGBA")

    def cell(root, rel, index):
        row = job["files"][rel]
        w, h = row["cell"]
        columns = row["size"][0] // w
        x, y = (index % columns) * w, (index // columns) * h
        return atlas(root, rel).crop((x, y, x + w, y + h))

    roots = [job["source"], conversion / "assets"]
    def paired(images, background, scale=1):
        w, h = images[0].size
        size = (max(1, round(w * scale)), max(1, round(h * scale)))
        panel_w = max(size[0] + 16, 180)
        panel = Image.new("RGB", (2 * panel_w, size[1] + 42), background)
        draw = ImageDraw.Draw(panel)
        text_color = "white" if background == BACKGROUNDS[0] else "black"
        for col, (label, im) in enumerate(zip(("Original", "Indexed / copied"), images)):
            base = Image.new("RGBA", im.size, (*background, 255))
            base.alpha_composite(im)
            if size != im.size:
                # Nearest preserves pixel inspection at integer magnification.
                filt = Image.Resampling.NEAREST if scale == int(scale) else Image.Resampling.BILINEAR
                base = base.resize(size, filt)
            panel.paste(base.convert("RGB"), (col * panel_w + 8, 32))
            draw.text((col * panel_w + 8, 8), label, fill=text_color, font=font)
        return panel

    artifacts = []
    for number, (rel, row) in enumerate(job["files"].items()):
        count = (row["size"][0] // row["cell"][0]) * (row["size"][1] // row["cell"][1])
        indices = sorted({0, count // 2, count - 1})
        scale = min(2, 640 / max(row["cell"]))
        panels = [paired([cell(root, rel, index) for root in roots], bg, scale)
                  for index in indices for bg in BACKGROUNDS]
        sheet = Image.new("RGB", (panels[0].width, sum(p.height + 24 for p in panels)), (24, 26, 25))
        draw = ImageDraw.Draw(sheet)
        y = 0
        for i, panel in enumerate(panels):
            draw.text((8, y + 2), f"{rel} | cell {indices[i // 2]} | {scale:g}x", fill="white", font=font)
            sheet.paste(panel, (0, y + 24))
            y += panel.height + 24
        filename = f"cells-{number:03}.png"
        sheet.save(output / filename)
        artifacts.append({"path": filename, "source": rel, "cells": indices})

    for preview in job["spec"].get("previews", []):
        frames = []
        for frame in preview["frames"]:
            composites = []
            for root in roots:
                image = Image.new("RGBA", tuple(preview["canvas"]), (0, 0, 0, 0))
                for layer in frame["layers"]:
                    part = cell(root, layer["path"], layer.get("cell", 0))
                    opacity = layer.get("opacity", 1)
                    if opacity != 1:
                        part.putalpha(part.getchannel("A").point(lambda v: round(v * opacity)))
                    image.alpha_composite(part, tuple(layer.get("at", [0, 0])))
                composites.append(image)
            panels = [paired(composites, bg, preview.get("scale", 1)) for bg in BACKGROUNDS]
            frame_image = Image.new("RGB", (panels[0].width, sum(p.height for p in panels)))
            frame_image.paste(panels[0], (0, 0))
            frame_image.paste(panels[1], (0, panels[0].height))
            frames.append(frame_image)
        selected = sorted({0, len(frames) // 2, len(frames) - 1})
        contact = Image.new("RGB", (frames[0].width, sum(frames[i].height for i in selected)))
        y = 0
        for index in selected:
            contact.paste(frames[index], (0, y))
            y += frames[index].height
        png = "preview-" + preview["name"] + ".png"
        contact.save(output / png)
        artifacts.append({"path": png, "frames": selected})
        if len(frames) > 1:
            webp = "preview-" + preview["name"] + ".webp"
            durations = [f.get("duration_ms", 100) for f in preview["frames"]]
            frames[0].save(output / webp, save_all=True, append_images=frames[1:],
                           duration=durations, loop=0, lossless=True, method=6)
            with Image.open(output / webp) as decoded:
                require(decoded.size == frames[0].size, "WebP dimensions changed")
                decoded.seek(decoded.n_frames - 1)
                decoded.load()
                encoded_frames = decoded.n_frames
            artifacts.append({"path": webp, "input_frames": len(frames), "encoded_frames": encoded_frames,
                              "duration_ms": sum(durations), "lossless": True})
    for item in artifacts:
        item.update(bytes=(output / item["path"]).stat().st_size, sha256=digest(output / item["path"]))
    result = {"schema": "esir.png-quantize.comparison.v1", "spec_sha256": job["spec_sha256"],
              "conversion_report_sha256": digest(conversion / "conversion-report.json"),
              "compositing": "ordinary source-over; not native Factorio shadow certification",
              "artifacts": artifacts}
    write_json(output / "comparison-report.json", result)
    return {"output": str(output), "artifacts": len(artifacts)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--spec", type=Path, required=True)
    parser.add_argument("--conversion", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    try:
        result = run(args.spec, args.conversion, args.output)
    except (ValueError, OSError, ImportError) as error:
        parser.exit(2, f"error: {error}\n")
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
