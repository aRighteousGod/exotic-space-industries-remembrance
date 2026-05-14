from __future__ import annotations

import argparse
import json
import math
import shutil
from dataclasses import dataclass
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont


FRAME_SIZE = 256
FRAME_COUNT = 64
LINE_LENGTH = 8
DISPLAY_SCALE = 0.69

BASE_FILENAME = "ei-gaian-saucer_dark_compact.png"
GLOW_FILENAME = "ei-gaian-saucer_dark_compact_glow.png"


@dataclass(frozen=True)
class GlowStats:
    frame_count: int
    nonempty_frames: int
    edge_touches: int
    black_alpha_pixels: int
    nonzero_alpha_pixels: int
    coverage_pct: float
    min_alpha_margin_px: int | None
    max_frame_coverage_pct: float


def find_repo_root(start: Path) -> Path:
    for path in [start, *start.parents]:
        if (path / ".gitignore").exists() and (path / "exotic-space-industries-remembrance").exists():
            return path
    raise RuntimeError(f"Could not find repository root from {start}")


REPO_ROOT = find_repo_root(Path(__file__).resolve())
GRAPHICS_DIR = REPO_ROOT / "exotic-space-industries-remembrance" / "graphics" / "entities" / "gaian-saucer"
DEFAULT_SOURCE = GRAPHICS_DIR / BASE_FILENAME
DEFAULT_TARGET = GRAPHICS_DIR / GLOW_FILENAME
DEFAULT_OUTPUT_DIR = REPO_ROOT / "output" / "meshy" / "ei-gaian-saucer" / "derived-dark-compact-glow"


def clamp(value: float, low: float = 0.0, high: float = 255.0) -> int:
    return int(max(low, min(high, round(value))))


def smoothstep(edge0: float, edge1: float, value: float) -> float:
    if edge0 == edge1:
        return 1.0 if value >= edge1 else 0.0
    t = max(0.0, min(1.0, (value - edge0) / (edge1 - edge0)))
    return t * t * (3.0 - 2.0 * t)


def mix(a: tuple[int, int, int], b: tuple[int, int, int], t: float) -> tuple[int, int, int]:
    return (
        clamp(a[0] + (b[0] - a[0]) * t),
        clamp(a[1] + (b[1] - a[1]) * t),
        clamp(a[2] + (b[2] - a[2]) * t),
    )


def glow_pixel(r: int, g: int, b: int, a: int) -> tuple[int, int, int, int, str | None]:
    if a <= 8:
        return (0, 0, 0, 0, None)

    maxc = max(r, g, b)
    minc = min(r, g, b)
    if maxc < 48:
        return (0, 0, 0, 0, None)

    sat = (maxc - minc) / max(1, maxc)
    luma = 0.2126 * r + 0.7152 * g + 0.0722 * b
    alpha_weight = min(1.0, a / 220.0)

    cyan = 0.0
    if b >= 80 and g >= 66 and b >= r + 18 and g >= r * 0.62:
        color_gap = min(b, g) - r
        cyan = smoothstep(16, 120, color_gap) * smoothstep(50, 160, luma) * smoothstep(0.18, 0.62, sat)

    gold = 0.0
    if r >= 105 and g >= 55 and b <= 96 and r >= g * 1.03 and luma >= 58:
        warmth = r + 0.72 * g - 1.65 * b
        gold = smoothstep(82, 250, warmth) * smoothstep(0.18, 0.72, sat) * smoothstep(58, 135, luma)

    magenta = 0.0
    if r >= 90 and b >= 64 and r >= g + 24 and b >= g + 6:
        magenta = smoothstep(22, 118, min(r - g, b - g + 18)) * smoothstep(44, 145, luma) * smoothstep(0.22, 0.76, sat)

    hot = 0.0
    if maxc >= 178 and sat >= 0.14 and luma >= 105:
        hot = smoothstep(172, 245, maxc) * smoothstep(102, 208, luma)

    scores = {
        "cyan": cyan,
        "gold": gold * 0.62,
        "magenta": magenta * 0.78,
        "hot": hot,
    }
    kind, strength = max(scores.items(), key=lambda item: item[1])
    if strength < 0.11:
        return (0, 0, 0, 0, None)

    original = (r, g, b)
    if kind == "hot":
        color = mix(original, (220, 255, 255), 0.58)
        alpha = 185 * strength
    elif kind == "cyan":
        color = mix(original, (64, 242, 255), 0.54)
        alpha = 155 * strength
    elif kind == "gold":
        color = mix(original, (255, 180, 44), 0.46)
        alpha = 64 * strength
    else:
        color = mix(original, (255, 68, 214), 0.48)
        alpha = 92 * strength

    alpha = clamp(alpha * alpha_weight, 0, 210)
    if alpha < 5:
        return (0, 0, 0, 0, None)
    return (*color, alpha, kind)


def reduce_alpha(image: Image.Image, factor: float, floor: int = 3) -> Image.Image:
    layer = image.copy().convert("RGBA")
    pixels = []
    for r, g, b, a in layer.getdata():
        new_alpha = clamp(a * factor)
        if new_alpha < floor:
            pixels.append((0, 0, 0, 0))
        else:
            pixels.append((r, g, b, new_alpha))
    layer.putdata(pixels)
    return layer


def scrub_black_alpha(image: Image.Image, alpha_floor: int = 3) -> Image.Image:
    cleaned = image.copy().convert("RGBA")
    pixels = []
    for r, g, b, a in cleaned.getdata():
        if a <= alpha_floor or (r + g + b <= 8):
            pixels.append((0, 0, 0, 0))
        else:
            pixels.append((r, g, b, a))
    cleaned.putdata(pixels)
    return cleaned


def derive_glow(base: Image.Image) -> tuple[Image.Image, dict[str, int]]:
    base = base.convert("RGBA")
    core = Image.new("RGBA", base.size, (0, 0, 0, 0))
    counts = {"cyan": 0, "gold": 0, "magenta": 0, "hot": 0}

    output_pixels = []
    for r, g, b, a in base.getdata():
        gr, gg, gb, ga, kind = glow_pixel(r, g, b, a)
        output_pixels.append((gr, gg, gb, ga))
        if kind:
            counts[kind] += 1
    core.putdata(output_pixels)

    aura = reduce_alpha(core.filter(ImageFilter.GaussianBlur(2.2)), 0.18)
    halo = reduce_alpha(core.filter(ImageFilter.GaussianBlur(1.05)), 0.42)
    glow = Image.alpha_composite(aura, halo)
    glow = Image.alpha_composite(glow, core)
    return scrub_black_alpha(glow), counts


def frame_bbox(sheet: Image.Image, index: int) -> tuple[int, int, int, int] | None:
    x = (index % LINE_LENGTH) * FRAME_SIZE
    y = (index // LINE_LENGTH) * FRAME_SIZE
    return sheet.crop((x, y, x + FRAME_SIZE, y + FRAME_SIZE)).getchannel("A").getbbox()


def collect_stats(glow: Image.Image) -> tuple[GlowStats, list[dict[str, object]]]:
    alpha = glow.getchannel("A")
    nonzero_total = 0
    black_alpha = 0
    frame_rows: list[dict[str, object]] = []
    nonempty = 0
    edge_touches = 0
    margins: list[int] = []
    max_frame_coverage = 0.0

    for r, g, b, a in glow.getdata():
        if a > 0:
            nonzero_total += 1
            if r + g + b <= 8:
                black_alpha += 1

    for index in range(FRAME_COUNT):
        x = (index % LINE_LENGTH) * FRAME_SIZE
        y = (index // LINE_LENGTH) * FRAME_SIZE
        frame = glow.crop((x, y, x + FRAME_SIZE, y + FRAME_SIZE))
        frame_alpha = frame.getchannel("A")
        bbox = frame_alpha.getbbox()
        frame_nonzero = sum(1 for value in frame_alpha.getdata() if value > 0)
        coverage = frame_nonzero / (FRAME_SIZE * FRAME_SIZE) * 100.0
        max_frame_coverage = max(max_frame_coverage, coverage)
        row: dict[str, object] = {
            "frame": index + 1,
            "nonzero_alpha_pixels": frame_nonzero,
            "coverage_pct": round(coverage, 4),
            "bbox": None,
            "edge_touch": False,
            "margin_px": None,
        }
        if bbox:
            nonempty += 1
            margin = min(bbox[0], bbox[1], FRAME_SIZE - bbox[2], FRAME_SIZE - bbox[3])
            edge_touch = bbox[0] <= 0 or bbox[1] <= 0 or bbox[2] >= FRAME_SIZE or bbox[3] >= FRAME_SIZE
            if edge_touch:
                edge_touches += 1
            margins.append(margin)
            row.update({
                "bbox": list(bbox),
                "edge_touch": edge_touch,
                "margin_px": margin,
            })
        frame_rows.append(row)

    stats = GlowStats(
        frame_count=FRAME_COUNT,
        nonempty_frames=nonempty,
        edge_touches=edge_touches,
        black_alpha_pixels=black_alpha,
        nonzero_alpha_pixels=nonzero_total,
        coverage_pct=round(nonzero_total / (glow.width * glow.height) * 100.0, 4),
        min_alpha_margin_px=min(margins) if margins else None,
        max_frame_coverage_pct=round(max_frame_coverage, 4),
    )
    return stats, frame_rows


def cut_frame(sheet: Image.Image, index: int) -> Image.Image:
    x = (index % LINE_LENGTH) * FRAME_SIZE
    y = (index // LINE_LENGTH) * FRAME_SIZE
    return sheet.crop((x, y, x + FRAME_SIZE, y + FRAME_SIZE))


def trim(image: Image.Image) -> Image.Image:
    bbox = image.getchannel("A").getbbox()
    return image.crop(bbox) if bbox else image


def additive_over(base: Image.Image, glow: Image.Image, amount: float = 1.0) -> Image.Image:
    base = base.convert("RGBA")
    glow = glow.convert("RGBA")
    pixels = []
    for (br, bg, bb, ba), (gr, gg, gb, ga) in zip(base.getdata(), glow.getdata()):
        factor = ga / 255.0 * amount
        pixels.append((
            clamp(br + gr * factor),
            clamp(bg + gg * factor),
            clamp(bb + gb * factor),
            ba,
        ))
    out = Image.new("RGBA", base.size, (0, 0, 0, 0))
    out.putdata(pixels)
    return out


def paste_additive(canvas: Image.Image, overlay: Image.Image, xy: tuple[int, int], amount: float = 1.0) -> None:
    x, y = xy
    region = canvas.crop((x, y, x + overlay.width, y + overlay.height))
    canvas.paste(additive_over(region, overlay, amount), (x, y))


def make_strip(base: Image.Image, glow: Image.Image, output_dir: Path) -> None:
    directions = [0, 8, 16, 24, 32, 40, 48, 56]
    font = ImageFont.load_default()
    cell = 220
    label_h = 20

    glow_strip = Image.new("RGBA", (len(directions) * cell, cell + label_h), (18, 18, 20, 255))
    composite_strip = Image.new("RGBA", (len(directions) * cell, cell + label_h), (34, 33, 30, 255))
    draw_glow = ImageDraw.Draw(glow_strip)
    draw_comp = ImageDraw.Draw(composite_strip)

    for column, index in enumerate(directions):
        gx = column * cell
        glow_frame = trim(cut_frame(glow, index))
        glow_frame.thumbnail((180, 180), Image.Resampling.LANCZOS)
        glow_strip.alpha_composite(glow_frame, (gx + (cell - glow_frame.width) // 2, label_h + (cell - label_h - glow_frame.height) // 2))
        draw_glow.text((gx + 6, 4), f"glow {index}", fill=(220, 230, 236, 255), font=font)

        base_frame = cut_frame(base, index)
        comp_frame = additive_over(base_frame, cut_frame(glow, index), 1.18)
        comp_frame = trim(comp_frame)
        comp_frame.thumbnail((180, 180), Image.Resampling.LANCZOS)
        composite_strip.alpha_composite(comp_frame, (gx + (cell - comp_frame.width) // 2, label_h + (cell - label_h - comp_frame.height) // 2))
        draw_comp.text((gx + 6, 4), f"base+glow {index}", fill=(220, 230, 236, 255), font=font)

    glow_strip.save(output_dir / "glow-only-8-direction-strip.png")
    composite_strip.save(output_dir / "base-plus-glow-8-direction-strip.png")


def make_factorio_preview(base: Image.Image, glow: Image.Image, output_dir: Path) -> None:
    backgrounds = [
        ((17, 20, 23), "dark factory"),
        ((70, 89, 57), "gaian green"),
        ((111, 82, 45), "dry ground"),
    ]
    frame_index = 18
    body = cut_frame(base, frame_index)
    light = cut_frame(glow, frame_index)
    display_size = max(1, round(FRAME_SIZE * DISPLAY_SCALE))
    body = body.resize((display_size, display_size), Image.Resampling.LANCZOS)
    light = light.resize((display_size, display_size), Image.Resampling.LANCZOS)
    font = ImageFont.load_default()
    rows = []
    for bg, label in backgrounds:
        canvas = Image.new("RGBA", (760, 360), (*bg, 255))
        draw = ImageDraw.Draw(canvas, "RGBA")
        for y in range(0, canvas.height, 32):
            draw.line((0, y, canvas.width, y), fill=(255, 255, 255, 18))
        for x in range(0, canvas.width, 32):
            draw.line((x, 0, x, canvas.height), fill=(255, 255, 255, 14))
        text_color = (236, 238, 240, 255) if sum(bg) < 300 else (21, 22, 23, 255)
        draw.text((14, 12), label, fill=text_color, font=font)
        x = (canvas.width - display_size) // 2
        y = (canvas.height - display_size) // 2 + 8
        canvas.alpha_composite(body, (x, y))
        paste_additive(canvas, light, (x, y), 1.25)
        rows.append(canvas)

    preview = Image.new("RGBA", (760, 360 * len(rows)), (0, 0, 0, 255))
    for index, row in enumerate(rows):
        preview.alpha_composite(row, (0, index * 360))
    preview.save(output_dir / "factorio-scale-composite.png")


def make_glow_atlas_preview(glow: Image.Image, output_dir: Path) -> None:
    background = Image.new("RGBA", glow.size, (0, 0, 0, 255))
    paste_additive(background, glow, (0, 0), 1.4)
    background.save(output_dir / "glow-only-atlas-preview.png")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Derive a Slipwake Saucer glow overlay from the approved compact dark body sheet.")
    parser.add_argument("--source", type=Path, default=DEFAULT_SOURCE, help="Base saucer body sheet.")
    parser.add_argument("--output-dir", type=Path, default=DEFAULT_OUTPUT_DIR, help="Staging output directory.")
    parser.add_argument("--target", type=Path, default=DEFAULT_TARGET, help="Promotion target glow sheet.")
    parser.add_argument("--promote", action="store_true", help="Copy the generated glow sheet to the mod graphics target.")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    source = args.source.resolve()
    output_dir = args.output_dir.resolve()
    target = args.target.resolve()
    output_dir.mkdir(parents=True, exist_ok=True)

    base = Image.open(source).convert("RGBA")
    expected_size = (FRAME_SIZE * LINE_LENGTH, FRAME_SIZE * math.ceil(FRAME_COUNT / LINE_LENGTH))
    if base.size != expected_size:
        raise ValueError(f"Expected {expected_size} source sheet, got {base.size}: {source}")

    glow, class_counts = derive_glow(base)
    glow_path = output_dir / GLOW_FILENAME
    glow.save(glow_path)

    stats, frame_rows = collect_stats(glow)
    make_strip(base, glow, output_dir)
    make_factorio_preview(base, glow, output_dir)
    make_glow_atlas_preview(glow, output_dir)

    metrics = {
        "source": str(source),
        "generated": str(glow_path),
        "promoted_to": str(target) if args.promote else None,
        "layout": {
            "sheet_size": list(glow.size),
            "frame_size": [FRAME_SIZE, FRAME_SIZE],
            "frame_count": FRAME_COUNT,
            "line_length": LINE_LENGTH,
        },
        "style": "Veins+Rim",
        "class_counts": class_counts,
        "summary": stats.__dict__,
        "frames": frame_rows,
        "previews": [
            "glow-only-atlas-preview.png",
            "glow-only-8-direction-strip.png",
            "base-plus-glow-8-direction-strip.png",
            "factorio-scale-composite.png",
        ],
    }
    metrics_path = output_dir / "ei-gaian-saucer_dark_compact_glow.metrics.json"
    metrics_path.write_text(json.dumps(metrics, indent=2), encoding="utf-8")

    if args.promote:
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(glow_path, target)

    print(json.dumps(metrics["summary"], indent=2))
    print(f"generated={glow_path}")
    if args.promote:
        print(f"promoted={target}")


if __name__ == "__main__":
    main()
