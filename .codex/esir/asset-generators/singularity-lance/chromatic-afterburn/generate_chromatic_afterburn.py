from __future__ import annotations

import json
import math
import random
from dataclasses import dataclass
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter


ASSET_NAME = "ei-singularity-lance-chromatic-afterburn"


def find_repo_root(start: Path) -> Path:
    for path in [start, *start.parents]:
        if (path / ".gitignore").exists() and (path / "exotic-space-industries-remembrance").exists():
            return path
    raise RuntimeError(f"Could not find repository root from {start}")


REPO_ROOT = find_repo_root(Path(__file__).resolve())
ROOT = REPO_ROOT / "output" / "meshy" / ASSET_NAME
EXPORT_DIR = ROOT / "factorio-export"
PREVIEW_DIR = ROOT / "previews"

FIRE_SIZE = (192, 192)
FIRE_FRAMES = 32
FIRE_LINE_LENGTH = 8
STICKER_SIZE = (96, 96)
STICKER_FRAMES = 32
STICKER_LINE_LENGTH = 8
SCORCH_SIZE = (256, 182)
SCORCH_VARIATIONS = 4
SEED = 713271


@dataclass(frozen=True)
class SheetSpec:
    path: Path
    frame_size: tuple[int, int]
    frame_count: int
    line_length: int


def clamp(value: float, low: float = 0.0, high: float = 255.0) -> int:
    return int(max(low, min(high, value)))


def mix(a: tuple[int, int, int], b: tuple[int, int, int], t: float) -> tuple[int, int, int]:
    t = max(0.0, min(1.0, t))
    return (
        clamp(a[0] + (b[0] - a[0]) * t),
        clamp(a[1] + (b[1] - a[1]) * t),
        clamp(a[2] + (b[2] - a[2]) * t),
    )


def add_pixel(
    pixels,
    x: int,
    y: int,
    rgba: tuple[int, int, int, int],
    mode: str = "over",
) -> None:
    if x < 0 or y < 0:
        return
    try:
        existing = pixels[x, y]
    except IndexError:
        return

    r, g, b, a = rgba
    if a <= 0:
        return

    if mode == "add":
        pixels[x, y] = (
            clamp(existing[0] + r * a / 255.0),
            clamp(existing[1] + g * a / 255.0),
            clamp(existing[2] + b * a / 255.0),
            clamp(existing[3] + a),
        )
        return

    alpha = a / 255.0
    out_a = alpha + existing[3] / 255.0 * (1.0 - alpha)
    if out_a <= 0:
        pixels[x, y] = (0, 0, 0, 0)
        return

    out_r = (r * alpha + existing[0] * existing[3] / 255.0 * (1.0 - alpha)) / out_a
    out_g = (g * alpha + existing[1] * existing[3] / 255.0 * (1.0 - alpha)) / out_a
    out_b = (b * alpha + existing[2] * existing[3] / 255.0 * (1.0 - alpha)) / out_a
    pixels[x, y] = (clamp(out_r), clamp(out_g), clamp(out_b), clamp(out_a * 255.0))


def spectral_color(offset: float, phase: float, heat: float = 1.0) -> tuple[int, int, int]:
    band = 0.5 + 0.5 * math.sin(offset * 3.4 + phase)
    if offset < -0.18:
        return mix((0, 225, 255), (88, 77, 255), band * 0.85)
    if offset > 0.18:
        return mix((255, 28, 192), (160, 63, 255), band * 0.85)
    hot = mix((255, 112, 20), (255, 232, 58), 0.45 + 0.45 * band)
    return mix(hot, (255, 255, 246), max(0.0, 1.0 - abs(offset) * 7.0) * 0.72 * heat)


def draw_disc(img: Image.Image, cx: float, cy: float, radius: float, rgba: tuple[int, int, int, int], additive: bool = False) -> None:
    pixels = img.load()
    min_x = math.floor(cx - radius * 2)
    max_x = math.ceil(cx + radius * 2)
    min_y = math.floor(cy - radius * 2)
    max_y = math.ceil(cy + radius * 2)
    for y in range(min_y, max_y + 1):
        for x in range(min_x, max_x + 1):
            distance = math.hypot(x - cx, y - cy)
            if distance > radius * 2:
                continue
            fade = math.exp(-((distance / max(0.1, radius)) ** 2))
            add_pixel(pixels, x, y, (rgba[0], rgba[1], rgba[2], clamp(rgba[3] * fade)), "add" if additive else "over")


def draw_soft_line(
    img: Image.Image,
    start: tuple[float, float],
    end: tuple[float, float],
    radius: float,
    rgba: tuple[int, int, int, int],
    additive: bool = False,
) -> None:
    length = max(1.0, math.hypot(end[0] - start[0], end[1] - start[1]))
    steps = max(2, int(length / max(1.0, radius * 0.65)))
    for i in range(steps + 1):
        t = i / steps
        x = start[0] + (end[0] - start[0]) * t
        y = start[1] + (end[1] - start[1]) * t
        draw_disc(img, x, y, radius, rgba, additive)


def edge_factor(position: int, length: int, margin: int, soft: int = 8) -> float:
    if margin <= 0:
        return 1.0

    distance = min(position, length - 1 - position)
    if distance < margin:
        return 0.0
    if distance < margin + soft:
        return ((distance - margin) / max(1, soft)) ** 0.72
    return 1.0


def apply_edge_fade(img: Image.Image, margin_x: int, margin_y: int, threshold: int = 3) -> Image.Image:
    pixels = img.load()
    width, height = img.size

    for y in range(height):
        fy = edge_factor(y, height, margin_y)
        for x in range(width):
            fx = edge_factor(x, width, margin_x)
            r, g, b, a = pixels[x, y]
            a = clamp(a * min(fx, fy))
            if a <= threshold:
                pixels[x, y] = (0, 0, 0, 0)
            else:
                pixels[x, y] = (r, g, b, a)

    return img


def draw_afterburn_flame(size: tuple[int, int], frame: int, frame_count: int, compact: bool, glow: bool = False) -> Image.Image:
    width, height = size
    img = Image.new("RGBA", size, (0, 0, 0, 0))
    pixels = img.load()
    phase = frame / frame_count * math.tau
    base_y = height * (0.70 if compact else 0.74)
    flame_h = height * (0.62 if compact else 0.66)
    core_w = width * (0.19 if compact else 0.21)
    haze_w = width * (0.35 if compact else 0.38)
    cx = width * 0.5 + math.sin(phase * 1.4) * width * (0.018 if compact else 0.025)

    for y in range(height):
        u = (base_y - y) / flame_h
        if u < -0.08 or u > 1.05:
            continue
        lift = max(0.0, min(1.0, u))
        taper = (1.0 - lift) ** 0.55
        tongue = 0.72 + 0.22 * math.sin(phase * 2.7 + lift * 13.0) + 0.12 * math.sin(phase * 4.3 - lift * 19.0)
        local_core = core_w * (0.18 + 0.92 * taper) * tongue
        local_haze = haze_w * (0.18 + 0.95 * taper)
        bend = math.sin(lift * math.pi * 1.35 + phase * 1.25) * width * (0.11 if compact else 0.13) * lift
        split = math.sin(lift * 21.0 + phase * 2.4) * width * (0.018 if compact else 0.024)
        local_cx = cx + bend + split

        for x in range(width):
            dx = x - local_cx
            adx = abs(dx)
            if adx > local_haze * 1.18:
                continue
            edge = adx / max(1.0, local_haze)
            core = math.exp(-((adx / max(1.0, local_core)) ** 2))
            haze = math.exp(-((adx / max(1.0, local_haze)) ** 2))
            crown = math.sin(max(0.0, min(1.0, lift)) * math.pi) ** 0.55
            strand = 0.76 + 0.24 * math.sin(x * 0.17 + y * 0.09 + phase * 2.2)
            notch = 0.86 + 0.14 * math.sin((x + y) * 0.07 + phase * 5.0)

            if glow:
                alpha = (haze * 108.0 + core * 54.0) * crown * strand
                heat = 0.45
            else:
                alpha = (core * 210.0 + haze * 72.0) * crown * strand * notch
                heat = 1.0

            if alpha <= 1:
                continue

            offset = dx / max(1.0, local_haze)
            color = spectral_color(offset * 1.35, phase + lift * 4.1 + math.sin(x * 0.05) * 0.7, heat)
            if not glow and edge > 0.72:
                color = mix((38, 6, 54), color, 0.68)
            add_pixel(pixels, x, y, (*color, clamp(alpha)), "add" if glow else "over")

    wound_y = height * (0.76 if compact else 0.79)
    wound_w = width * (0.34 if compact else 0.40)
    for i in range(6):
        t = (i - 2.5) / 2.5
        color = spectral_color(t * 0.44, phase + i * 0.7, 0.75 if glow else 1.0)
        alpha = 62 if glow else 120
        radius = (2.0 if compact else 3.2) + i % 2
        start = (cx - wound_w * 0.5 + i * wound_w / 5.0, wound_y + math.sin(phase + i) * 2.4)
        end = (cx - wound_w * 0.28 + i * wound_w / 5.0, wound_y - height * 0.07 + math.cos(phase * 1.4 + i) * 2.6)
        draw_soft_line(img, start, end, radius, (*color, alpha), glow)

    rng = random.Random(SEED + frame * 193 + (9000 if glow else 0) + (41 if compact else 0))
    ember_count = 11 if compact else 20
    for _ in range(ember_count):
        x = rng.uniform(width * 0.20, width * 0.80)
        y = rng.uniform(height * 0.24, height * 0.82)
        drift = math.sin(phase + y * 0.03) * width * 0.05
        side = -1 if x < width * 0.5 else 1
        color = rng.choice([(255, 124, 20), (255, 219, 45), (35, 226, 255), (238, 38, 210), (138, 74, 255)])
        draw_disc(
            img,
            x + drift + side * rng.uniform(0, width * 0.05),
            y,
            rng.uniform(0.7, 1.7 if not glow else 3.0),
            (*color, rng.randrange(30, 92 if not glow else 72)),
            glow,
        )

    margin = 7 if compact else 10
    img = apply_edge_fade(img, margin, margin)
    if glow:
        img = img.filter(ImageFilter.GaussianBlur(1.35 if compact else 1.75))
        img = apply_edge_fade(img, margin, margin)
    return img


def draw_scorch_variation(index: int, glow: bool = False) -> Image.Image:
    width, height = SCORCH_SIZE
    img = Image.new("RGBA", SCORCH_SIZE, (0, 0, 0, 0))
    pixels = img.load()
    rng = random.Random(SEED + index * 617 + (8000 if glow else 0))
    cx = width * (0.49 + rng.uniform(-0.025, 0.025))
    cy = height * (0.54 + rng.uniform(-0.03, 0.025))
    rx = width * rng.uniform(0.31, 0.37)
    ry = height * rng.uniform(0.20, 0.25)
    angle = rng.uniform(-0.18, 0.18)
    cos_a = math.cos(angle)
    sin_a = math.sin(angle)

    for y in range(height):
        for x in range(width):
            dx = x - cx
            dy = y - cy
            lx = (dx * cos_a + dy * sin_a) / rx
            ly = (-dx * sin_a + dy * cos_a) / ry
            r = math.sqrt(lx * lx + ly * ly)
            if r > 1.18:
                continue
            ragged = 0.92 + 0.08 * math.sin(x * 0.08 + y * 0.13 + index * 2.1) + 0.05 * math.sin(x * 0.19 - y * 0.05)
            edge = max(0.0, 1.0 - r / max(0.2, ragged))
            if edge <= 0:
                continue

            if glow:
                alpha = (1.0 - abs(r - 0.78) / 0.28) * 42.0
                if alpha <= 0:
                    continue
                color = spectral_color(lx * 0.75, index * 0.8 + ly * 2.0, 0.35)
                add_pixel(pixels, x, y, (*color, clamp(alpha)), "add")
            else:
                soot = (edge ** 0.45) * 190.0
                heat = math.exp(-((r / 0.34) ** 2)) * 60.0
                color = mix((11, 7, 13), (72, 18, 79), edge * 0.45)
                color = mix(color, (150, 58, 25), heat / 255.0)
                add_pixel(pixels, x, y, (*color, clamp(soot + heat)))

    crack_count = 8
    for crack in range(crack_count):
        theta = rng.uniform(0, math.tau)
        length = rng.uniform(0.35, 0.92)
        start = (cx + math.cos(theta) * rx * 0.05, cy + math.sin(theta) * ry * 0.05)
        end = (
            cx + math.cos(theta + rng.uniform(-0.28, 0.28)) * rx * length,
            cy + math.sin(theta + rng.uniform(-0.28, 0.28)) * ry * length,
        )
        mid = ((start[0] + end[0]) * 0.5 + rng.uniform(-9, 9), (start[1] + end[1]) * 0.5 + rng.uniform(-7, 7))
        color = spectral_color(math.sin(theta), index * 1.1 + crack * 0.9, 0.85)
        alpha = 112 if glow else 76
        radius = rng.uniform(1.2, 2.4 if glow else 1.8)
        draw_soft_line(img, start, mid, radius, (*color, alpha), glow)
        draw_soft_line(img, mid, end, max(0.8, radius * 0.72), (*color, alpha), glow)

    if glow:
        img = img.filter(ImageFilter.GaussianBlur(0.8))
    return apply_edge_fade(img, 8, 8)


def make_sheet(frame_func, frame_size: tuple[int, int], frame_count: int, line_length: int) -> Image.Image:
    rows = math.ceil(frame_count / line_length)
    sheet = Image.new("RGBA", (frame_size[0] * line_length, frame_size[1] * rows), (0, 0, 0, 0))
    for frame in range(frame_count):
        tile = frame_func(frame)
        x = (frame % line_length) * frame_size[0]
        y = (frame // line_length) * frame_size[1]
        sheet.alpha_composite(tile, (x, y))
    return sheet


def make_scorch_sheet(glow: bool = False) -> Image.Image:
    sheet = Image.new("RGBA", (SCORCH_SIZE[0] * SCORCH_VARIATIONS, SCORCH_SIZE[1]), (0, 0, 0, 0))
    for index in range(SCORCH_VARIATIONS):
        sheet.alpha_composite(draw_scorch_variation(index, glow), (index * SCORCH_SIZE[0], 0))
    return sheet


def alpha_bbox(frame: Image.Image, threshold: int = 8) -> tuple[int, int, int, int] | None:
    alpha = frame.getchannel("A")
    mask = alpha.point(lambda value: 255 if value > threshold else 0)
    return mask.getbbox()


def frame_bounds(sheet: Image.Image, spec: SheetSpec) -> list[dict[str, object]]:
    bounds = []
    for frame in range(spec.frame_count):
        x = (frame % spec.line_length) * spec.frame_size[0]
        y = (frame // spec.line_length) * spec.frame_size[1]
        crop = sheet.crop((x, y, x + spec.frame_size[0], y + spec.frame_size[1]))
        bbox = alpha_bbox(crop)
        if not bbox:
            bounds.append({"frame": frame, "bbox": None, "min_margin": None})
            continue
        left, top, right, bottom = bbox
        margins = [left, top, spec.frame_size[0] - right, spec.frame_size[1] - bottom]
        bounds.append({"frame": frame, "bbox": [left, top, right, bottom], "min_margin": min(margins)})
    return bounds


def make_readability_preview(fire: Image.Image, fire_glow: Image.Image, sticker: Image.Image, sticker_glow: Image.Image, scorch: Image.Image, scorch_glow: Image.Image) -> None:
    width, height = 1280, 720
    preview = Image.new("RGBA", (width, height), (0, 0, 0, 255))
    draw = ImageDraw.Draw(preview)
    backgrounds = [
        (0, 0, 426, height, (7, 12, 17, 255)),
        (426, 0, 853, height, (78, 50, 29, 255)),
        (853, 0, width, height, (56, 61, 64, 255)),
    ]
    for box in backgrounds:
        draw.rectangle(box[:4], fill=box[4])

    rng = random.Random(SEED)
    for _ in range(220):
        x = rng.randrange(width)
        y = rng.randrange(height)
        color = rng.choice([(22, 31, 35, 255), (96, 67, 39, 255), (73, 78, 80, 255)])
        draw.point((x, y), fill=color)

    fire_frame = fire.crop((FIRE_SIZE[0] * 5, 0, FIRE_SIZE[0] * 6, FIRE_SIZE[1]))
    fire_glow_frame = fire_glow.crop((FIRE_SIZE[0] * 5, 0, FIRE_SIZE[0] * 6, FIRE_SIZE[1]))
    sticker_frame = sticker.crop((STICKER_SIZE[0] * 9, STICKER_SIZE[1], STICKER_SIZE[0] * 10, STICKER_SIZE[1] * 2))
    sticker_glow_frame = sticker_glow.crop((STICKER_SIZE[0] * 9, STICKER_SIZE[1], STICKER_SIZE[0] * 10, STICKER_SIZE[1] * 2))
    scorch_frame = scorch.crop((SCORCH_SIZE[0], 0, SCORCH_SIZE[0] * 2, SCORCH_SIZE[1]))
    scorch_glow_frame = scorch_glow.crop((SCORCH_SIZE[0], 0, SCORCH_SIZE[0] * 2, SCORCH_SIZE[1]))

    for cx in (213, 640, 1066):
        ground_y = 515
        preview.alpha_composite(scorch_frame, (cx - SCORCH_SIZE[0] // 2, ground_y - 58))
        preview.alpha_composite(scorch_glow_frame, (cx - SCORCH_SIZE[0] // 2, ground_y - 58))
        preview.alpha_composite(fire_glow_frame, (cx - FIRE_SIZE[0] // 2, ground_y - 145))
        preview.alpha_composite(fire_frame, (cx - FIRE_SIZE[0] // 2, ground_y - 145))
        preview.alpha_composite(sticker_glow_frame, (cx + 54, ground_y - 182))
        preview.alpha_composite(sticker_frame, (cx + 54, ground_y - 182))

    preview.convert("RGB").save(PREVIEW_DIR / f"{ASSET_NAME}-readability-preview.png")


def make_alpha_preview(sheets: list[tuple[str, Image.Image, SheetSpec]]) -> None:
    cell_w = 260
    cell_h = 220
    preview = Image.new("RGBA", (cell_w * 4, cell_h * len(sheets)), (12, 14, 18, 255))
    draw = ImageDraw.Draw(preview)
    for row, (label, sheet, spec) in enumerate(sheets):
        for column in range(4):
            frame = min(spec.frame_count - 1, column * max(1, spec.frame_count // 4))
            x = (frame % spec.line_length) * spec.frame_size[0]
            y = (frame // spec.line_length) * spec.frame_size[1]
            crop = sheet.crop((x, y, x + spec.frame_size[0], y + spec.frame_size[1]))
            scale = min((cell_w - 34) / spec.frame_size[0], (cell_h - 44) / spec.frame_size[1])
            resized = crop.resize((int(spec.frame_size[0] * scale), int(spec.frame_size[1] * scale)), Image.Resampling.LANCZOS)
            ox = column * cell_w + (cell_w - resized.width) // 2
            oy = row * cell_h + (cell_h - resized.height) // 2 + 12
            preview.alpha_composite(resized, (ox, oy))
            bbox = alpha_bbox(crop)
            if bbox:
                left, top, right, bottom = bbox
                rect = (
                    ox + int(left * scale),
                    oy + int(top * scale),
                    ox + int(right * scale),
                    oy + int(bottom * scale),
                )
                draw.rectangle(rect, outline=(255, 72, 48, 255), width=2)
            draw.text((column * cell_w + 10, row * cell_h + 8), f"{label} f{frame:02d}", fill=(216, 225, 232, 255))
    preview.convert("RGB").save(PREVIEW_DIR / f"{ASSET_NAME}-alpha-bounds-preview.png")


def save_manifest(specs: list[SheetSpec], sheets: dict[str, Image.Image]) -> None:
    report = {
        "asset_name": ASSET_NAME,
        "seed": SEED,
        "generated_assets": [],
    }
    for spec in specs:
        sheet = sheets[spec.path.name]
        bounds = frame_bounds(sheet, spec)
        warnings = []
        for entry in bounds:
            margin = entry["min_margin"]
            if margin is None:
                warnings.append(f"frame {entry['frame']} is empty")
            elif margin < 6:
                warnings.append(f"frame {entry['frame']} margin below 6px: {margin}")
        report["generated_assets"].append(
            {
                "path": str(spec.path.relative_to(ROOT)).replace("\\", "/"),
                "frame_size": list(spec.frame_size),
                "frame_count": spec.frame_count,
                "line_length": spec.line_length,
                "sheet_size": list(sheet.size),
                "alpha_bounds": bounds,
                "warnings": warnings,
            }
        )

    (ROOT / "source" / "generation-report.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
    (EXPORT_DIR / f"{ASSET_NAME}.factorio-asset-manifest.json").write_text(json.dumps(report, indent=2), encoding="utf-8")


def write_snippet() -> None:
    snippet = """-- Staged non-impact afterburn graphics for ei-singularity-lance.
-- Promote these sheets to graphics/entities/singularity-lance/afterburn/ before using.
local afterburn_path = ei_path.."graphics/entities/singularity-lance/afterburn/"

local function make_afterburn_animation(filename, glow_filename, width, height, frame_count, line_length, scale, shift, speed)
    return {
        layers = {
            {
                filename = afterburn_path..filename,
                width = width,
                height = height,
                frame_count = frame_count,
                line_length = line_length,
                animation_speed = speed,
                scale = scale,
                shift = shift,
            },
            {
                filename = afterburn_path..glow_filename,
                width = width,
                height = height,
                frame_count = frame_count,
                line_length = line_length,
                animation_speed = speed,
                scale = scale,
                shift = shift,
                draw_as_glow = true,
                blend_mode = "additive-soft",
            },
        },
    }
end
"""
    (EXPORT_DIR / f"{ASSET_NAME}.prototype-snippet.lua").write_text(snippet, encoding="utf-8")


def main() -> None:
    EXPORT_DIR.mkdir(parents=True, exist_ok=True)
    PREVIEW_DIR.mkdir(parents=True, exist_ok=True)
    (ROOT / "source").mkdir(parents=True, exist_ok=True)

    fire = make_sheet(lambda frame: draw_afterburn_flame(FIRE_SIZE, frame, FIRE_FRAMES, False, False), FIRE_SIZE, FIRE_FRAMES, FIRE_LINE_LENGTH)
    fire_glow = make_sheet(lambda frame: draw_afterburn_flame(FIRE_SIZE, frame, FIRE_FRAMES, False, True), FIRE_SIZE, FIRE_FRAMES, FIRE_LINE_LENGTH)
    sticker = make_sheet(lambda frame: draw_afterburn_flame(STICKER_SIZE, frame, STICKER_FRAMES, True, False), STICKER_SIZE, STICKER_FRAMES, STICKER_LINE_LENGTH)
    sticker_glow = make_sheet(lambda frame: draw_afterburn_flame(STICKER_SIZE, frame, STICKER_FRAMES, True, True), STICKER_SIZE, STICKER_FRAMES, STICKER_LINE_LENGTH)
    scorch = make_scorch_sheet(False)
    scorch_glow = make_scorch_sheet(True)

    outputs = {
        "singularity-lance-afterburn-fire.png": fire,
        "singularity-lance-afterburn-fire-glow.png": fire_glow,
        "singularity-lance-afterburn-sticker.png": sticker,
        "singularity-lance-afterburn-sticker-glow.png": sticker_glow,
        "singularity-lance-afterburn-scorchmark.png": scorch,
        "singularity-lance-afterburn-scorchmark-glow.png": scorch_glow,
    }
    for filename, sheet in outputs.items():
        sheet.save(EXPORT_DIR / filename)

    specs = [
        SheetSpec(EXPORT_DIR / "singularity-lance-afterburn-fire.png", FIRE_SIZE, FIRE_FRAMES, FIRE_LINE_LENGTH),
        SheetSpec(EXPORT_DIR / "singularity-lance-afterburn-fire-glow.png", FIRE_SIZE, FIRE_FRAMES, FIRE_LINE_LENGTH),
        SheetSpec(EXPORT_DIR / "singularity-lance-afterburn-sticker.png", STICKER_SIZE, STICKER_FRAMES, STICKER_LINE_LENGTH),
        SheetSpec(EXPORT_DIR / "singularity-lance-afterburn-sticker-glow.png", STICKER_SIZE, STICKER_FRAMES, STICKER_LINE_LENGTH),
        SheetSpec(EXPORT_DIR / "singularity-lance-afterburn-scorchmark.png", SCORCH_SIZE, SCORCH_VARIATIONS, SCORCH_VARIATIONS),
        SheetSpec(EXPORT_DIR / "singularity-lance-afterburn-scorchmark-glow.png", SCORCH_SIZE, SCORCH_VARIATIONS, SCORCH_VARIATIONS),
    ]
    save_manifest(specs, outputs)
    write_snippet()
    make_readability_preview(fire, fire_glow, sticker, sticker_glow, scorch, scorch_glow)
    make_alpha_preview(
        [
            ("fire", fire, specs[0]),
            ("sticker", sticker, specs[2]),
            ("scorch", scorch, specs[4]),
        ]
    )

    fire.save(PREVIEW_DIR / f"{ASSET_NAME}-fire-frame-strip.png")
    sticker.save(PREVIEW_DIR / f"{ASSET_NAME}-sticker-frame-strip.png")
    scorch.save(PREVIEW_DIR / f"{ASSET_NAME}-scorchmark-variations.png")


if __name__ == "__main__":
    main()
