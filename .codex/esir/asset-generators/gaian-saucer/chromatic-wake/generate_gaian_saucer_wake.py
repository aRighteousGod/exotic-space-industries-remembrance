from __future__ import annotations

import argparse
import json
import math
import random
import shutil
from dataclasses import dataclass
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter


ASSET_NAME = "ei-gaian-saucer-chromatic-wake"


def find_repo_root(start: Path) -> Path:
    for path in [start, *start.parents]:
        if (path / ".gitignore").exists() and (path / "exotic-space-industries-remembrance").exists():
            return path
    raise RuntimeError(f"Could not find repository root from {start}")


REPO_ROOT = find_repo_root(Path(__file__).resolve())
ROOT = REPO_ROOT / "output" / "meshy" / ASSET_NAME
EXPORT_DIR = ROOT / "factorio-export"
PREVIEW_DIR = ROOT / "previews"
GRAPHICS_DIR = REPO_ROOT / "exotic-space-industries-remembrance" / "graphics" / "entities"
SAUCER_DIR = GRAPHICS_DIR / "gaian-saucer"
WAKE_DIR = SAUCER_DIR / "wake"
BEAM_DIR = GRAPHICS_DIR / "singularity-lance" / "beam"

FRAME_SIZE = 768
FRAME_COUNT = 64
LINE_LENGTH = 8
BEAM_FRAME_SIZE = (256, 96)
BEAM_FRAME_COUNT = 16
BEAM_LINE_LENGTH = 4
SEED = 5905030805

NORMAL_FILENAME = "ei-gaian-saucer_wake.png"
GLOW_FILENAME = "ei-gaian-saucer_wake_glow.png"

SAUCER_SCALE = 0.23
WAKE_SCALE = 0.23


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


def spectral_color(offset: float, phase: float, heat: float = 1.0) -> tuple[int, int, int]:
    band = 0.5 + 0.5 * math.sin(offset * 3.7 + phase)
    if offset < -0.22:
        return mix((0, 232, 255), (72, 82, 255), band * 0.88)
    if offset > 0.22:
        return mix((255, 34, 193), (143, 60, 255), band * 0.88)
    hot = mix((255, 118, 22), (255, 235, 58), 0.45 + 0.45 * band)
    return mix(hot, (255, 255, 246), max(0.0, 1.0 - abs(offset) * 5.7) * 0.70 * heat)


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


def draw_disc(
    img: Image.Image,
    cx: float,
    cy: float,
    radius: float,
    rgba: tuple[int, int, int, int],
    additive: bool = False,
) -> None:
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


def crop_beam_frames(sheet: Image.Image) -> list[Image.Image]:
    frames: list[Image.Image] = []
    frame_w, frame_h = BEAM_FRAME_SIZE
    for index in range(BEAM_FRAME_COUNT):
        col = index % BEAM_LINE_LENGTH
        row = index // BEAM_LINE_LENGTH
        box = (col * frame_w, row * frame_h, (col + 1) * frame_w, (row + 1) * frame_h)
        frames.append(sheet.crop(box).convert("RGBA"))
    return frames


def sample_bilinear(img: Image.Image, x: float, y: float) -> tuple[int, int, int, int]:
    width, height = img.size
    x = x % width
    y = max(0.0, min(height - 1.001, y))

    x0 = int(math.floor(x))
    y0 = int(math.floor(y))
    x1 = (x0 + 1) % width
    y1 = min(height - 1, y0 + 1)
    tx = x - x0
    ty = y - y0
    pixels = img.load()
    p00 = pixels[x0, y0]
    p10 = pixels[x1, y0]
    p01 = pixels[x0, y1]
    p11 = pixels[x1, y1]

    out = []
    for channel in range(4):
        a = p00[channel] + (p10[channel] - p00[channel]) * tx
        b = p01[channel] + (p11[channel] - p01[channel]) * tx
        out.append(clamp(a + (b - a) * ty))
    return (out[0], out[1], out[2], out[3])


def fade_to_frame_margin(value: int, length: int, margin: int = 22, soft: int = 18) -> float:
    distance = min(value, length - 1 - value)
    if distance < margin:
        return 0.0
    if distance < margin + soft:
        return ((distance - margin) / max(1, soft)) ** 0.72
    return 1.0


def apply_frame_fade(img: Image.Image, margin: int = 22, soft: int = 18) -> Image.Image:
    pixels = img.load()
    for y in range(img.height):
        fy = fade_to_frame_margin(y, img.height, margin, soft)
        for x in range(img.width):
            fx = fade_to_frame_margin(x, img.width, margin, soft)
            r, g, b, a = pixels[x, y]
            a = clamp(a * min(fx, fy))
            pixels[x, y] = (r, g, b, a) if a > 2 else (0, 0, 0, 0)
    return img


def wake_center(t: float, phase: float) -> tuple[float, float]:
    # Default orientation is "moving north": the wake begins near the saucer
    # underside and trails down/back. Runtime selects a pre-rotated atlas frame.
    # Keep geometry phase-stable; frame phase should shimmer, not make the
    # Factorio animation visibly slide away from its render target.
    sway = math.sin(t * math.pi * 1.3) * (18.0 + 20.0 * t)
    counter = math.sin(t * math.tau * 2.15) * (5.0 + 14.0 * t)
    x = FRAME_SIZE / 2 + sway + counter
    y = 232.0 + t * 430.0 + math.sin(t * math.pi) * 6.0
    return x, y


def wake_radius(t: float, glow: bool) -> tuple[float, float, float]:
    taper = max(0.0, math.sin(t * math.pi)) ** 0.44
    tail_widen = 0.48 + 0.52 * t
    core = 8.0 + 19.0 * taper * tail_widen
    band = 28.0 + 55.0 * taper * tail_widen
    haze = 52.0 + 94.0 * taper * tail_widen
    if glow:
        return core * 1.1, band * 1.2, haze * 1.23
    return core, band, haze


def temporal_envelope(t: float, phase: float) -> float:
    entrance = min(1.0, max(0.0, t / 0.09))
    exit_fade = min(1.0, max(0.0, (1.0 - t) / 0.17))
    pulse = 0.86 + 0.14 * math.sin(phase * 1.8)
    return (min(entrance, exit_fade) ** 0.66) * pulse


def draw_wake_frame(index: int, source_frames: list[Image.Image], glow: bool = False) -> Image.Image:
    img = Image.new("RGBA", (FRAME_SIZE, FRAME_SIZE), (0, 0, 0, 0))
    pixels = img.load()
    phase = index / FRAME_COUNT * math.tau
    source = source_frames[index % len(source_frames)]
    rng = random.Random(SEED + index * 173 + (10000 if glow else 0))

    for row in range(198, 718):
        rough_t = (row - 232.0) / 430.0
        t_low = max(0.0, rough_t - 0.08)
        t_high = min(1.0, rough_t + 0.08)
        samples = (t_low, (t_low + t_high) * 0.5, t_high)
        scan_left = FRAME_SIZE
        scan_right = 0
        centers = []
        for t_sample in samples:
            cx, cy = wake_center(t_sample, phase)
            _, _, haze = wake_radius(t_sample, glow)
            centers.append((t_sample, cx, cy, haze))
            scan_left = min(scan_left, math.floor(cx - haze * 1.1))
            scan_right = max(scan_right, math.ceil(cx + haze * 1.1))

        scan_left = max(24, scan_left)
        scan_right = min(FRAME_SIZE - 25, scan_right)

        for col in range(scan_left, scan_right + 1):
            best_alpha = 0.0
            best_color = (0, 0, 0)
            best_mode = "add" if glow else "over"

            for t, cx, cy, _haze in centers:
                dx = col - cx
                dy = row - cy
                distance = math.hypot(dx * 0.82, dy * 1.22)
                core_radius, band_radius, haze_radius = wake_radius(t, glow)
                if distance > haze_radius * 1.08:
                    continue

                envelope = temporal_envelope(t, phase)
                lateral = dx / max(1.0, band_radius)
                sample_x = t * BEAM_FRAME_SIZE[0] + index * 3.7 + math.sin(row * 0.08 + phase) * 5.0
                sample_y = (BEAM_FRAME_SIZE[1] - 1) * 0.5 + lateral * 34.0
                sr, sg, sb, sa = sample_bilinear(source, sample_x, sample_y)
                sampled_alpha = sa / 255.0

                core = math.exp(-((distance / max(1.0, core_radius)) ** 2))
                band = math.exp(-((distance / max(1.0, band_radius)) ** 2))
                haze = math.exp(-((distance / max(1.0, haze_radius)) ** 2))
                strand = 0.73 + 0.27 * math.sin(col * 0.083 + row * 0.117 + phase * 2.5)
                fault = 0.82 + 0.18 * math.sin((col - row) * 0.045 + phase * 4.0)

                if glow:
                    alpha = (band * 92.0 + haze * 116.0 + core * 34.0) * envelope * strand
                    color = mix((sr, sg, sb), spectral_color(lateral * 1.3, phase + t * 4.8, 0.42), 0.40)
                else:
                    alpha = (core * 214.0 + band * 94.0 + haze * 24.0) * envelope * strand * fault
                    alpha *= 0.52 + sampled_alpha * 0.58
                    color = mix((sr, sg, sb), spectral_color(lateral, phase + t * 4.2, 1.0), 0.30)

                if alpha > best_alpha:
                    best_alpha = alpha
                    best_color = color

            if best_alpha > 1:
                add_pixel(pixels, col, row, (*best_color, clamp(best_alpha)), best_mode)

    mote_count = 28 if not glow else 20
    for mote_index in range(mote_count):
        t = rng.random() * 0.92
        cx, cy = wake_center(t, phase)
        _, band_radius, _ = wake_radius(t, glow)
        side = -1 if rng.random() < 0.5 else 1
        x = cx + side * rng.uniform(band_radius * 0.25, band_radius * 0.82) + rng.uniform(-7, 7)
        y = cy + rng.uniform(-14, 16)
        if x < 42 or x > FRAME_SIZE - 42 or y < 222 or y > 690:
            continue
        color = spectral_color(rng.uniform(-0.75, 0.75), phase + mote_index * 0.57, 0.72 if glow else 1.0)
        radius = rng.uniform(0.9, 2.2 if not glow else 4.8)
        alpha = rng.randrange(34, 94 if not glow else 82)
        draw_disc(img, x, y, radius, (*color, alpha), additive=glow)

    if glow:
        img = img.filter(ImageFilter.GaussianBlur(1.4))
    return apply_frame_fade(img)


def rotate_directional_frame(frame: Image.Image, direction_index: int) -> Image.Image:
    # PIL rotates counterclockwise in screen space. Factorio orientations advance
    # clockwise from north, so negate the angle to turn the northbound wake into
    # the requested movement direction.
    angle = -(direction_index / FRAME_COUNT) * 360.0
    return frame.rotate(
        angle,
        resample=Image.Resampling.BICUBIC,
        center=(FRAME_SIZE / 2, FRAME_SIZE / 2),
        fillcolor=(0, 0, 0, 0),
    )


def pack_sheet(frames: list[Image.Image]) -> Image.Image:
    rows = math.ceil(len(frames) / LINE_LENGTH)
    sheet = Image.new("RGBA", (FRAME_SIZE * LINE_LENGTH, FRAME_SIZE * rows), (0, 0, 0, 0))
    for index, frame in enumerate(frames):
        x = (index % LINE_LENGTH) * FRAME_SIZE
        y = (index // LINE_LENGTH) * FRAME_SIZE
        sheet.alpha_composite(frame, (x, y))
    return sheet


def alpha_bounds(img: Image.Image) -> dict[str, int] | None:
    bbox = img.getchannel("A").getbbox()
    if not bbox:
        return None
    left, top, right, bottom = bbox
    return {
        "left": left,
        "top": top,
        "right": right - 1,
        "bottom": bottom - 1,
        "margin_left": left,
        "margin_top": top,
        "margin_right": img.width - right,
        "margin_bottom": img.height - bottom,
    }


def sheet_bounds(spec: SheetSpec) -> dict[str, object]:
    img = Image.open(spec.path).convert("RGBA")
    bounds = []
    warnings = []
    for index in range(spec.frame_count):
        x = (index % spec.line_length) * spec.frame_size[0]
        y = (index // spec.line_length) * spec.frame_size[1]
        frame = img.crop((x, y, x + spec.frame_size[0], y + spec.frame_size[1]))
        frame_bounds = alpha_bounds(frame)
        bounds.append(frame_bounds)
        if frame_bounds is None:
            warnings.append(f"frame {index} is fully transparent")
            continue
        min_margin = min(
            frame_bounds["margin_left"],
            frame_bounds["margin_top"],
            frame_bounds["margin_right"],
            frame_bounds["margin_bottom"],
        )
        if min_margin < 18:
            warnings.append(f"frame {index} alpha margin {min_margin}px")

    return {
        "file": str(spec.path.relative_to(ROOT)).replace("\\", "/"),
        "dimensions": list(img.size),
        "frame_size": list(spec.frame_size),
        "frame_count": spec.frame_count,
        "line_length": spec.line_length,
        "alpha_bounds": bounds,
        "warnings": warnings,
    }


def first_frame(path: Path) -> Image.Image:
    return Image.open(path).convert("RGBA").crop((0, 0, FRAME_SIZE, FRAME_SIZE))


def paste_layer(
    canvas: Image.Image,
    frame: Image.Image,
    scale: float,
    shift_tiles: tuple[float, float],
    glow: bool = False,
) -> None:
    layer = frame
    size = (max(1, int(round(layer.width * scale))), max(1, int(round(layer.height * scale))))
    layer = layer.resize(size, Image.Resampling.LANCZOS)
    if glow:
        layer = layer.filter(ImageFilter.GaussianBlur(0.35))
    x = int(round(canvas.width / 2 + shift_tiles[0] * 32 - size[0] / 2))
    y = int(round(canvas.height / 2 + shift_tiles[1] * 32 - size[1] / 2))
    canvas.alpha_composite(layer, (x, y))


def make_factorio_preview(wake: Image.Image, wake_glow: Image.Image) -> Image.Image:
    saucer = first_frame(SAUCER_DIR / "ei-gaian-saucer.png")
    saucer_glow = first_frame(SAUCER_DIR / "ei-gaian-saucer_glow.png")
    saucer_shadow = first_frame(SAUCER_DIR / "ei-gaian-saucer_shadow.png")

    backgrounds = [
        ((17, 20, 23), "dark factory"),
        ((70, 89, 57), "gaian green"),
        ((111, 82, 45), "dry ground"),
    ]
    rows = []
    for bg, label in backgrounds:
        canvas = Image.new("RGBA", (760, 520), (*bg, 255))
        draw = ImageDraw.Draw(canvas)
        for y in range(0, canvas.height, 32):
            draw.line((0, y, canvas.width, y), fill=(255, 255, 255, 18))
        for x in range(0, canvas.width, 32):
            draw.line((x, 0, x, canvas.height), fill=(255, 255, 255, 14))
        draw.text((14, 12), label, fill=(236, 238, 240, 255) if sum(bg) < 300 else (21, 22, 23, 255))

        paste_layer(canvas, saucer_shadow, SAUCER_SCALE, (0.48, 0.58))
        paste_layer(canvas, wake, WAKE_SCALE, (0, 1.35))
        paste_layer(canvas, wake_glow, WAKE_SCALE, (0, 1.35), glow=True)
        paste_layer(canvas, saucer, SAUCER_SCALE, (0, 0))
        paste_layer(canvas, saucer_glow, SAUCER_SCALE, (0, 0), glow=True)
        rows.append(canvas)

    preview = Image.new("RGBA", (760, 520 * len(rows)), (0, 0, 0, 255))
    for index, row in enumerate(rows):
        preview.alpha_composite(row, (0, index * 520))
    return preview


def make_frame_strip(frames: list[Image.Image], title: str) -> Image.Image:
    thumb_scale = 0.25
    thumb_w = int(frames[0].width * thumb_scale)
    thumb_h = int(frames[0].height * thumb_scale)
    cols = 8
    rows = math.ceil(len(frames) / cols)
    canvas = Image.new("RGBA", (cols * thumb_w, rows * thumb_h + 30), (12, 13, 16, 255))
    ImageDraw.Draw(canvas).text((8, 8), title, fill=(230, 230, 230, 255))
    for index, frame in enumerate(frames):
        thumb = frame.resize((thumb_w, thumb_h), Image.Resampling.LANCZOS)
        canvas.alpha_composite(thumb, ((index % cols) * thumb_w, 30 + (index // cols) * thumb_h))
    return canvas


def write_manifest(specs: list[SheetSpec], previews: list[Path], promoted: bool) -> dict[str, object]:
    sheets = [sheet_bounds(spec) for spec in specs]
    warnings: list[str] = []
    for sheet in sheets:
        warnings.extend(f"{sheet['file']}: {warning}" for warning in sheet["warnings"])

    manifest = {
        "asset_name": ASSET_NAME,
        "mode": "gaian-saucer-directional-slipwake",
        "source_assets": [
            str((BEAM_DIR / "ei-singularity-lance-beam-body.png").relative_to(REPO_ROOT)).replace("\\", "/"),
            str((BEAM_DIR / "ei-singularity-lance-beam-body-glow.png").relative_to(REPO_ROOT)).replace("\\", "/"),
        ],
        "generator": str(Path(__file__).resolve().relative_to(REPO_ROOT)).replace("\\", "/"),
        "seed": SEED,
        "staged_assets": sheets,
        "previews": [str(path.relative_to(ROOT)).replace("\\", "/") for path in previews],
        "target_graphics_dir": str(WAKE_DIR.relative_to(REPO_ROOT)).replace("\\", "/"),
        "prototype_file": "exotic-space-industries-remembrance/prototypes/alien-system/gaian-saucer.lua",
        "runtime_file": "exotic-space-industries-remembrance/scripts/control/gaian-saucer-wake.lua",
        "frame": {
            "size": FRAME_SIZE,
            "frame_count": FRAME_COUNT,
            "line_length": LINE_LENGTH,
            "scale": WAKE_SCALE,
            "animation_speed": 0,
            "default_orientation": "frame 0 is moving north; runtime selects one of 64 pre-rotated movement directions",
        },
        "promoted_to_mod": promoted,
        "warnings": warnings,
    }
    manifest_path = EXPORT_DIR / f"{ASSET_NAME}.factorio-asset-manifest.json"
    manifest_path.write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    return manifest


def generate(promote: bool) -> dict[str, object]:
    EXPORT_DIR.mkdir(parents=True, exist_ok=True)
    PREVIEW_DIR.mkdir(parents=True, exist_ok=True)
    (ROOT / "source").mkdir(parents=True, exist_ok=True)

    body_path = BEAM_DIR / "ei-singularity-lance-beam-body.png"
    glow_path = BEAM_DIR / "ei-singularity-lance-beam-body-glow.png"
    if not body_path.exists() or not glow_path.exists():
        raise FileNotFoundError(f"Expected promoted Singularity Lance beam body sheets in {BEAM_DIR}")

    normal_sources = crop_beam_frames(Image.open(body_path).convert("RGBA"))
    glow_sources = crop_beam_frames(Image.open(glow_path).convert("RGBA"))

    normal_frames = [
        rotate_directional_frame(draw_wake_frame(index, normal_sources, False), index)
        for index in range(FRAME_COUNT)
    ]
    glow_frames = [
        rotate_directional_frame(draw_wake_frame(index, glow_sources, True), index)
        for index in range(FRAME_COUNT)
    ]

    specs = [
        SheetSpec(EXPORT_DIR / NORMAL_FILENAME, (FRAME_SIZE, FRAME_SIZE), FRAME_COUNT, LINE_LENGTH),
        SheetSpec(EXPORT_DIR / GLOW_FILENAME, (FRAME_SIZE, FRAME_SIZE), FRAME_COUNT, LINE_LENGTH),
    ]
    pack_sheet(normal_frames).save(specs[0].path)
    pack_sheet(glow_frames).save(specs[1].path)

    if promote:
        WAKE_DIR.mkdir(parents=True, exist_ok=True)
        shutil.copy2(specs[0].path, WAKE_DIR / NORMAL_FILENAME)
        shutil.copy2(specs[1].path, WAKE_DIR / GLOW_FILENAME)

    preview_paths = [
        PREVIEW_DIR / f"{ASSET_NAME}-factorio-scale-preview.png",
        PREVIEW_DIR / f"{ASSET_NAME}-frame-strip.png",
    ]
    make_factorio_preview(normal_frames[0], glow_frames[0]).save(preview_paths[0])
    make_frame_strip(normal_frames[::2], "Gaian saucer chromatic wake frames").save(preview_paths[1])

    manifest = write_manifest(specs, preview_paths, promote)
    report = {
        "asset_name": ASSET_NAME,
        "export_dir": str(EXPORT_DIR.relative_to(ROOT)).replace("\\", "/"),
        "preview_dir": str(PREVIEW_DIR.relative_to(ROOT)).replace("\\", "/"),
        "files_written": [str(spec.path.relative_to(ROOT)).replace("\\", "/") for spec in specs],
        "promoted_files": [
            str((WAKE_DIR / NORMAL_FILENAME).relative_to(REPO_ROOT)).replace("\\", "/"),
            str((WAKE_DIR / GLOW_FILENAME).relative_to(REPO_ROOT)).replace("\\", "/"),
        ] if promote else [],
        "previews_written": [str(path.relative_to(ROOT)).replace("\\", "/") for path in preview_paths],
        "warnings": manifest["warnings"],
    }
    (ROOT / "source" / "generation-report.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
    return report


def main() -> None:
    parser = argparse.ArgumentParser(description="Generate the Gaian Saucer chromatic wake animation sheets.")
    parser.add_argument("--promote", action="store_true", help="Copy generated PNGs into the live Gaian Saucer wake graphics folder.")
    args = parser.parse_args()
    print(json.dumps(generate(args.promote), indent=2))


if __name__ == "__main__":
    main()
