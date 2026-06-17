#!/usr/bin/env python3
"""Generate the Goliath procedural HID headlight cone."""

from __future__ import annotations

import argparse
import json
import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter


ENTITY_DIR = Path("exotic-space-industries-remembrance-graphics-5/graphics/entities/nuclear-locomotive")
PREVIEW_DIR = Path("output/meshy/nuclear-trains/hid-headlight-previews")
WIDTH = 400
HEIGHT = 1013


def smoothstep(edge0: float, edge1: float, value: float) -> float:
    if edge0 == edge1:
        return 1.0 if value >= edge1 else 0.0
    value = min(1.0, max(0.0, (value - edge0) / (edge1 - edge0)))
    return value * value * (3.0 - 2.0 * value)


def generate_hid_cone(width: int = WIDTH, height: int = HEIGHT) -> Image.Image:
    """Create a wide rounded cone with transparent padding and no hard edge cutoff."""
    y0 = int(height * 0.055)
    y1 = int(height * 0.86)
    edge_pad = int(width * 0.18)
    center_x = (width - 1) / 2
    rgba = np.zeros((height, width, 4), dtype=np.float32)

    for y in range(y0, y1 + 1):
        t = (y - y0) / (y1 - y0)
        start = smoothstep(0.0, 0.085, t)
        tail = 1.0 - smoothstep(0.62, 1.0, t)
        shoulder = math.exp(-((t - 0.18) / 0.18) ** 2) * 0.14 * start
        half_width = width * (0.060 + 0.370 * max(0.0, 1.0 - t) ** 0.72) * start
        half_width = min(half_width, width * 0.300)
        if half_width <= 0.2:
            continue

        strength = (0.12 + 0.78 * max(0.0, 1.0 - t) ** 1.20) * start * tail
        if strength <= 0.001:
            continue

        y_edge_fade = min(1.0, (y - y0) / edge_pad, (y1 - y) / edge_pad)
        for x in range(width):
            x_edge_fade = min(1.0, x / edge_pad, (width - 1 - x) / edge_pad)
            edge_fade = max(0.0, min(x_edge_fade, y_edge_fade))
            if edge_fade <= 0:
                continue

            dx = abs(x - center_x) / half_width
            if dx >= 1.55:
                continue

            soft = math.exp(-1.15 * (dx ** 3.2))
            core = math.exp(-(dx / 0.34) ** 2.0) * 0.24
            alpha = min(176.0, 148.0 * (strength + shoulder) * (soft * 0.72 + core) * edge_fade)
            if alpha <= 0.4:
                continue

            edge_fraction = min(1.0, dx / 1.55)
            teal_mix = smoothstep(0.36, 1.0, edge_fraction) * 0.70
            rgba[y, x, 0] = 255 * (1.0 - teal_mix) + 80 * teal_mix
            rgba[y, x, 1] = 255 * (1.0 - teal_mix) + 228 * teal_mix
            rgba[y, x, 2] = 255
            rgba[y, x, 3] = alpha

    image = Image.fromarray(np.clip(rgba, 0, 255).astype(np.uint8)).convert("RGBA")
    alpha = image.getchannel("A").filter(ImageFilter.GaussianBlur(2.4))
    color = image.filter(ImageFilter.GaussianBlur(0.45))
    color.putalpha(alpha)
    return color


def make_cone_preview(cone: Image.Image, preview_dir: Path) -> Path:
    preview_dir.mkdir(parents=True, exist_ok=True)
    checker = Image.new("RGBA", cone.size, (15, 17, 20, 255))
    draw = ImageDraw.Draw(checker)
    step = 32
    for y in range(0, cone.height, step):
        for x in range(0, cone.width, step):
            if (x // step + y // step) % 2 == 0:
                draw.rectangle((x, y, x + step - 1, y + step - 1), fill=(26, 30, 36, 255))
    checker.alpha_composite(cone)
    target = preview_dir / "goliath-hid-light-cone-preview.png"
    checker.save(target)
    return target


def alpha_summary(image: Image.Image) -> dict[str, float | int | list[int]]:
    alpha = image.getchannel("A")
    bbox = alpha.getbbox()
    values = [value for value in alpha.getdata() if value >= 8]
    if not values:
        raise ValueError("generated cone has no visible alpha")
    edge_values = []
    for x in range(image.width):
        edge_values.append(alpha.getpixel((x, 0)))
        edge_values.append(alpha.getpixel((x, image.height - 1)))
    for y in range(image.height):
        edge_values.append(alpha.getpixel((0, y)))
        edge_values.append(alpha.getpixel((image.width - 1, y)))
    return {
        "bbox": list(bbox or (0, 0, 0, 0)),
        "max_alpha": max(values),
        "mean_visible_alpha": round(sum(values) / len(values), 3),
        "max_edge_alpha": max(edge_values),
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", type=Path, default=Path("."), help="Repository root.")
    parser.add_argument("--preview-dir", type=Path, default=PREVIEW_DIR, help="Preview output directory.")
    args = parser.parse_args()

    repo = args.repo.resolve()
    target_dir = repo / ENTITY_DIR
    preview_dir = repo / args.preview_dir
    target_dir.mkdir(parents=True, exist_ok=True)

    cone = generate_hid_cone()
    cone_path = target_dir / "hid-light-cone.png"
    cone.save(cone_path)
    cone_preview = make_cone_preview(cone, preview_dir)

    results = {
        "cone": {
            "path": str(cone_path.relative_to(repo)),
            "size": [cone.width, cone.height],
            "preview": str(cone_preview.relative_to(repo)),
            "alpha": alpha_summary(cone),
        },
        "baked_headlight_layers": "removed",
    }
    manifest_path = preview_dir / "goliath-hid-headlights-manifest.json"
    manifest_path.write_text(json.dumps(results, indent=2), encoding="utf-8")
    print(f"hid-light-cone: {cone.width}x{cone.height}, alpha={results['cone']['alpha']}")
    print(f"wrote {manifest_path.relative_to(repo)}")


if __name__ == "__main__":
    main()
