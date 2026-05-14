#!/usr/bin/env python3
"""Create brightened base-pass variants for the Emerald Apocalypse hover tank.

The final Blender object pass preserved the approved geometry/framing but landed
too dark in-game. This script post-processes the already-rendered Object frames,
keeps alpha intact, protects saturated emerald crystal pixels from blowing out,
packs Factorio stripe sheets, and emits a comparison preview using the existing
shadow and crystal glow passes.
"""

from __future__ import annotations

import argparse
import json
import math
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable

from PIL import Image, ImageDraw


@dataclass(frozen=True)
class Variant:
    name: str
    gamma: float
    multiplier: float
    lift: float
    green_preserve: float


VARIANTS = (
    Variant("v1-moderate", gamma=0.78, multiplier=1.06, lift=3.0, green_preserve=0.28),
    Variant("v2-strong", gamma=0.68, multiplier=1.08, lift=5.0, green_preserve=0.36),
    Variant("v3-apex", gamma=0.61, multiplier=1.11, lift=7.0, green_preserve=0.44),
)

SELECTED_PREVIEW_FRAMES = (1, 9, 21, 37, 53)
SHEET_COLUMNS = 4
SHEET_ROWS = 4


def clamp(value: float, low: float = 0.0, high: float = 255.0) -> int:
    return int(max(low, min(high, round(value))))


def clamp01(value: float) -> float:
    return max(0.0, min(1.0, value))


def make_lut(variant: Variant) -> list[int]:
    lut: list[int] = []
    for value in range(256):
        normalized = value / 255.0
        corrected = (255.0 * (normalized ** variant.gamma) * variant.multiplier) + variant.lift
        lut.append(clamp(corrected))
    return lut


def emerald_preserve_score(r: int, g: int, b: int) -> float:
    # Protect high-saturation emerald/cyan crystal faces. The bronze body and
    # dark green panels still receive the brightness lift.
    saturation_push = clamp01((g - max(r, b) - 12) / 72.0)
    green_floor = clamp01((g - 58) / 112.0)
    cyan_floor = clamp01((b - 45) / 125.0)
    return max(saturation_push * green_floor, cyan_floor * green_floor * 0.45)


def brighten_frame(source_path: Path, out_path: Path, variant: Variant, lut: list[int]) -> dict:
    source = Image.open(source_path).convert("RGBA")
    result = Image.new("RGBA", source.size, (0, 0, 0, 0))
    source_pixels = source.load()
    result_pixels = result.load()
    alpha_bbox = source.getchannel("A").getbbox()

    if not alpha_bbox:
        result.save(out_path)
        return {
            "frame": source_path.name,
            "alpha_pixels": 0,
            "mean_luma": 0,
        }

    luma_sum = 0.0
    alpha_pixels = 0
    min_x, min_y, max_x, max_y = alpha_bbox
    for y in range(min_y, max_y):
        for x in range(min_x, max_x):
            r, g, b, a = source_pixels[x, y]
            if a == 0:
                continue

            ar = lut[r]
            ag = lut[g]
            ab = lut[b]
            preserve = emerald_preserve_score(r, g, b) * variant.green_preserve
            if preserve > 0:
                inv = 1.0 - preserve
                ar = clamp((ar * inv) + (r * preserve))
                ag = clamp((ag * inv) + (g * preserve))
                ab = clamp((ab * inv) + (b * preserve))

            result_pixels[x, y] = (ar, ag, ab, a)
            luma_sum += (0.2126 * ar) + (0.7152 * ag) + (0.0722 * ab)
            alpha_pixels += 1

    result.save(out_path)
    return {
        "frame": source_path.name,
        "alpha_pixels": alpha_pixels,
        "mean_luma": round(luma_sum / max(1, alpha_pixels), 2),
        "alpha_bbox": alpha_bbox,
    }


def frame_paths(directory: Path) -> list[Path]:
    return sorted(directory.glob("*.png"))


def pack_sheets(frame_dir: Path, sheet_dir: Path, prefix: str) -> list[str]:
    frames = frame_paths(frame_dir)
    if not frames:
        return []

    first = Image.open(frames[0]).convert("RGBA")
    frame_width, frame_height = first.size
    first.close()
    per_sheet = SHEET_COLUMNS * SHEET_ROWS
    sheet_paths: list[str] = []

    for sheet_index, start in enumerate(range(0, len(frames), per_sheet)):
        chunk = frames[start:start + per_sheet]
        sheet = Image.new("RGBA", (frame_width * SHEET_COLUMNS, frame_height * SHEET_ROWS), (0, 0, 0, 0))
        for local_index, frame_path in enumerate(chunk):
            frame = Image.open(frame_path).convert("RGBA")
            x = (local_index % SHEET_COLUMNS) * frame_width
            y = (local_index // SHEET_COLUMNS) * frame_height
            sheet.alpha_composite(frame, (x, y))
            frame.close()

        suffix = "_0" if sheet_index == 0 else f"_0_{sheet_index}"
        out_path = sheet_dir / f"{prefix}{suffix}.png"
        sheet.save(out_path)
        sheet_paths.append(str(out_path))

    return sheet_paths


def additive_glow(base: Image.Image, glow: Image.Image) -> Image.Image:
    base = base.convert("RGBA")
    glow = glow.convert("RGBA")
    result = base.copy()
    bp = result.load()
    gp = glow.load()
    width, height = result.size

    glow_bbox = glow.getchannel("A").getbbox()
    if not glow_bbox:
        return result

    min_x, min_y, max_x, max_y = glow_bbox
    for y in range(min_y, max_y):
        for x in range(min_x, max_x):
            gr, gg, gb, ga = gp[x, y]
            if ga == 0:
                continue
            br, bg, bb, ba = bp[x, y]
            alpha = ga / 255.0
            bp[x, y] = (
                clamp(br + gr * alpha),
                clamp(bg + gg * alpha),
                clamp(bb + gb * alpha),
                max(ba, ga),
            )

    return result


def composite_preview(base_path: Path, shadow_path: Path, glow_path: Path, background: tuple[int, int, int]) -> Image.Image:
    base = Image.open(base_path).convert("RGBA")
    canvas = Image.new("RGBA", base.size, (*background, 255))
    if shadow_path.exists():
        shadow = Image.open(shadow_path).convert("RGBA")
        canvas.alpha_composite(shadow)
        shadow.close()
    canvas.alpha_composite(base)
    base.close()
    if glow_path.exists():
        glow = Image.open(glow_path).convert("RGBA")
        canvas = additive_glow(canvas, glow)
        glow.close()
    return canvas


def make_preview_strip(render_dir: Path, out_root: Path, variant_dirs: dict[str, Path]) -> Path:
    object_dir = render_dir / "Object"
    shadow_dir = render_dir / "Shadow"
    glow_dir = render_dir / "Emerald Glow"
    columns = [("original", object_dir)] + [(variant.name, variant_dirs[variant.name]) for variant in VARIANTS]
    scale = 0.25
    cell_w = int(1536 * scale)
    cell_h = int(1536 * scale)
    label_h = 36
    pad = 10
    width = (cell_w * len(columns)) + (pad * (len(columns) + 1))
    height = ((cell_h + label_h) * len(SELECTED_PREVIEW_FRAMES)) + (pad * (len(SELECTED_PREVIEW_FRAMES) + 1))
    strip = Image.new("RGBA", (width, height), (18, 18, 18, 255))
    draw = ImageDraw.Draw(strip)

    for row, frame_number in enumerate(SELECTED_PREVIEW_FRAMES):
        frame_name = f"{frame_number:04d}.png"
        y = pad + row * (cell_h + label_h + pad)
        for col, (label, directory) in enumerate(columns):
            x = pad + col * (cell_w + pad)
            preview = composite_preview(
                directory / frame_name,
                shadow_dir / frame_name,
                glow_dir / frame_name,
                background=(112, 102, 62),
            )
            preview.thumbnail((cell_w, cell_h), Image.Resampling.LANCZOS)
            strip.alpha_composite(preview, (x, y + label_h))
            draw.text((x + 4, y + 5), f"{label} / {frame_name}", fill=(230, 235, 220, 255))
            preview.close()

    out_path = out_root / "emerald-apocalypse-brightness-correction-comparison-strip.png"
    strip.save(out_path)
    return out_path


def summarize_variant(frames: Iterable[dict], variant: Variant, sheets: list[str]) -> dict:
    frame_list = list(frames)
    lumas = [frame["mean_luma"] for frame in frame_list if frame.get("alpha_pixels", 0) > 0]
    return {
        "name": variant.name,
        "settings": {
            "gamma": variant.gamma,
            "multiplier": variant.multiplier,
            "lift": variant.lift,
            "green_preserve": variant.green_preserve,
        },
        "frame_count": len(frame_list),
        "mean_luma": round(sum(lumas) / max(1, len(lumas)), 2),
        "min_frame_luma": round(min(lumas), 2) if lumas else 0,
        "max_frame_luma": round(max(lumas), 2) if lumas else 0,
        "sheets": sheets,
    }


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--render-dir",
        type=Path,
        default=Path("output/meshy/emerald-apocalypse-hover-tank/Render-final-64-v7-ultra"),
    )
    parser.add_argument(
        "--out-root",
        type=Path,
        default=Path("output/meshy/emerald-apocalypse-hover-tank/brightness-correction"),
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    render_dir = args.render_dir
    object_dir = render_dir / "Object"
    if not object_dir.exists():
        raise SystemExit(f"Object frame directory not found: {object_dir}")

    out_root = args.out_root
    out_root.mkdir(parents=True, exist_ok=True)
    sheet_dir = out_root / ".Sheets"
    sheet_dir.mkdir(parents=True, exist_ok=True)

    object_frames = frame_paths(object_dir)
    manifest = {
        "kind": "emerald_apocalypse_brightness_correction",
        "source_object_dir": str(object_dir),
        "out_root": str(out_root),
        "variants": [],
    }
    variant_dirs: dict[str, Path] = {}

    for variant in VARIANTS:
        lut = make_lut(variant)
        variant_dir = out_root / variant.name / "Object"
        variant_dir.mkdir(parents=True, exist_ok=True)
        variant_dirs[variant.name] = variant_dir
        frame_metrics = []
        for frame_path in object_frames:
            frame_metrics.append(brighten_frame(frame_path, variant_dir / frame_path.name, variant, lut))
        sheets = pack_sheets(variant_dir, sheet_dir, f"object_bright_{variant.name}")
        manifest["variants"].append(summarize_variant(frame_metrics, variant, sheets))

    preview_path = make_preview_strip(render_dir, out_root, variant_dirs)
    manifest["preview"] = str(preview_path)
    manifest_path = out_root / "emerald-apocalypse-brightness-correction.manifest.json"
    manifest_path.write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    print(json.dumps({"manifest": str(manifest_path), "preview": str(preview_path)}, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
