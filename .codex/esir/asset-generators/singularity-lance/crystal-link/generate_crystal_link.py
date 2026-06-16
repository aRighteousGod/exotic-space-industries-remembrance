from __future__ import annotations

import argparse
import json
import math
import random
import shutil
from dataclasses import dataclass
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter


ASSET_NAME = "ei-singularity-lance-crystal-link"


def find_repo_root(start: Path) -> Path:
    for path in [start, *start.parents]:
        if (path / ".gitignore").exists() and (path / "exotic-space-industries-remembrance").exists():
            return path
    raise RuntimeError(f"Could not find repository root from {start}")


REPO_ROOT = find_repo_root(Path(__file__).resolve())
ROOT = REPO_ROOT / "output" / "meshy" / ASSET_NAME
EXPORT_DIR = ROOT / "factorio-export"
PREVIEW_DIR = ROOT / "previews"
GRAPHICS_DIR = REPO_ROOT / "exotic-space-industries-remembrance" / "graphics" / "entities" / "singularity-lance"
BEAM_DIR = GRAPHICS_DIR / "beam"
CRYSTAL_LINK_DIR = GRAPHICS_DIR / "crystal-link"

FRAME_SIZE = 768
FRAME_COUNT = 64
LINE_LENGTH = 8
BEAM_FRAME_SIZE = (256, 96)
BEAM_FRAME_COUNT = 16
BEAM_LINE_LENGTH = 4
SEED = 892117

NORMAL_FILENAME = "singularity-lance-crystal-link.png"
GLOW_FILENAME = "singularity-lance-crystal-link-glow.png"

ARRAY_BODY_SCALE = 0.65
ARRAY_BODY_SHIFT = (0.0, -2.66)
ARRAY_BODY_SHADOW_SHIFT = (0.0, 0.65)
ARRAY_CRYSTAL_SCALE = 0.5
ARRAY_CRYSTAL_LINK_SCALE = ARRAY_CRYSTAL_SCALE
ARRAY_CRYSTAL_SHIFT = (0.0, -1.90)
ARRAY_CRYSTAL_LINK_SHIFT = (0.0, -1.75)
TILE_PIXELS = 32.0

CRYSTAL_LOWER_TIP_Y = 339.0
PYRAMID_TIP_BASE_Y = 428.0


def projected_y(frame_y: float, scale: float, shift: tuple[float, float]) -> float:
    return (frame_y - FRAME_SIZE / 2) * scale + shift[1] * TILE_PIXELS


def link_frame_y_for_projected_y(y: float) -> float:
    return FRAME_SIZE / 2 + (y - ARRAY_CRYSTAL_LINK_SHIFT[1] * TILE_PIXELS) / ARRAY_CRYSTAL_LINK_SCALE


# The sheet is positioned in the same full-frame space as the crystal layer,
# but the link keeps its own shift so the lower end stays pinned to the upper
# pyramid tip instead of sinking into the top panel.
LINK_CENTER_X = 384.0
LINK_TOP_Y = link_frame_y_for_projected_y(projected_y(CRYSTAL_LOWER_TIP_Y, ARRAY_CRYSTAL_SCALE, ARRAY_CRYSTAL_SHIFT))
LINK_BOTTOM_Y = link_frame_y_for_projected_y(projected_y(PYRAMID_TIP_BASE_Y, ARRAY_BODY_SCALE, ARRAY_BODY_SHIFT))
LINK_CORE_RADIUS = 15.5
LINK_HAZE_RADIUS = 31.0


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
    band = 0.5 + 0.5 * math.sin(offset * 3.4 + phase)
    if offset < -0.18:
        return mix((0, 225, 255), (88, 77, 255), band * 0.85)
    if offset > 0.18:
        return mix((255, 28, 192), (160, 63, 255), band * 0.85)
    hot = mix((255, 112, 20), (255, 232, 58), 0.45 + 0.45 * band)
    return mix(hot, (255, 255, 246), max(0.0, 1.0 - abs(offset) * 7.0) * 0.72 * heat)


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


def vertical_envelope(t: float) -> float:
    entrance = min(1.0, max(0.0, t / 0.13))
    exit_fade = min(1.0, max(0.0, (1.0 - t) / 0.17))
    return min(entrance, exit_fade) ** 0.55


def link_center_x(body_t: float, phase: float) -> float:
    bend = math.sin(body_t * math.pi * 1.12 + phase * 2.0) * 3.4
    bend += math.sin(body_t * math.tau * 2.4 - phase) * 1.6
    return LINK_CENTER_X + bend


def looped_source_frame(source_frames: list[Image.Image], index: int) -> Image.Image:
    position = index / FRAME_COUNT * len(source_frames)
    left_index = int(math.floor(position)) % len(source_frames)
    right_index = (left_index + 1) % len(source_frames)
    blend = position - math.floor(position)

    if blend <= 0.001:
        return source_frames[left_index]

    return Image.blend(source_frames[left_index], source_frames[right_index], blend)


def spark_specs(count: int, glow: bool) -> list[dict[str, float]]:
    rng = random.Random(SEED + (5000 if glow else 0))
    specs: list[dict[str, float]] = []
    for spark_index in range(count):
        specs.append({
            "lane": (spark_index / max(1, count) + rng.uniform(-0.018, 0.018)) % 1.0,
            "cycles": float(1 + spark_index % 2),
            "phase": rng.uniform(0.0, math.tau),
            "wobble_cycles": float(1 + spark_index % 3),
            "x_jitter": rng.uniform(1.5, 5.5),
            "color_offset": rng.uniform(-0.65, 0.65),
            "radius": rng.uniform(1.1, 2.6 if not glow else 4.8),
            "alpha": float(rng.randrange(46, 94 if not glow else 82)),
            "pulse_phase": rng.uniform(0.0, math.tau),
        })
    return specs


def draw_link_frame(index: int, source_frames: list[Image.Image], glow: bool = False) -> Image.Image:
    img = Image.new("RGBA", (FRAME_SIZE, FRAME_SIZE), (0, 0, 0, 0))
    pixels = img.load()
    phase_unit = index / FRAME_COUNT
    phase = phase_unit * math.tau
    source = looped_source_frame(source_frames, index)
    link_height = LINK_BOTTOM_Y - LINK_TOP_Y

    for y in range(math.floor(LINK_TOP_Y - 18), math.ceil(LINK_BOTTOM_Y + 18)):
        t = (y - LINK_TOP_Y) / link_height
        if t < -0.12 or t > 1.10:
            continue

        body_t = max(0.0, min(1.0, t))
        envelope = vertical_envelope(body_t)
        if envelope <= 0.001:
            continue

        center_x = link_center_x(body_t, phase)
        taper = 0.78 + 0.22 * math.sin(body_t * math.pi)
        core_radius = LINK_CORE_RADIUS * taper
        haze_radius = LINK_HAZE_RADIUS * (0.82 + 0.18 * math.sin(body_t * math.pi))
        scan_radius = haze_radius * (1.35 if glow else 1.0)
        min_x = math.floor(center_x - scan_radius)
        max_x = math.ceil(center_x + scan_radius)

        for x in range(min_x, max_x + 1):
            dx = x - center_x
            adx = abs(dx)
            if adx > scan_radius:
                continue

            lateral = dx / max(1.0, haze_radius)
            sample_x = (body_t + phase_unit) * BEAM_FRAME_SIZE[0]
            sample_y = (BEAM_FRAME_SIZE[1] - 1) * 0.5 + lateral * 35.0
            sample_y += math.sin(body_t * 18.0 + phase * 2.0) * 2.1
            sr, sg, sb, sa = sample_bilinear(source, sample_x, sample_y)

            core = math.exp(-((adx / max(1.0, core_radius)) ** 2))
            haze = math.exp(-((adx / max(1.0, haze_radius)) ** 2))
            strand = 0.76 + 0.24 * math.sin(y * 0.135 + x * 0.075 + phase * 3.0)
            pulse = 0.70 + 0.30 * math.sin((1.0 - body_t) * math.tau * 3.0 + phase * 3.0)
            sampled_alpha = sa / 255.0

            if glow:
                alpha = (haze * 130.0 + core * 44.0) * envelope * strand * (0.75 + 0.25 * pulse)
                color = mix((sr, sg, sb), spectral_color(lateral * 1.2, phase + body_t * 5.0, 0.45), 0.35)
                mode = "add"
            else:
                alpha = (core * 205.0 + haze * 72.0) * envelope * strand * pulse
                alpha *= 0.55 + sampled_alpha * 0.62
                color = mix((sr, sg, sb), spectral_color(lateral, phase + body_t * 4.0, 1.0), 0.24)
                mode = "over"

            if alpha > 1:
                add_pixel(pixels, x, y, (*color, clamp(alpha)), mode)

    for spark_index, spark in enumerate(spark_specs(18 if not glow else 12, glow)):
        lane = (spark["lane"] + phase_unit * spark["cycles"]) % 1.0
        y = LINK_BOTTOM_Y - lane * link_height
        y += math.sin(phase * spark["wobble_cycles"] + spark["phase"]) * 2.5
        if y < LINK_TOP_Y or y > LINK_BOTTOM_Y:
            continue
        t = (y - LINK_TOP_Y) / link_height
        body_t = max(0.0, min(1.0, t))
        x = link_center_x(body_t, phase)
        x += math.sin(body_t * math.pi * 1.4 + phase + spark["phase"]) * 5.2
        x += math.sin(phase * spark["wobble_cycles"] + spark["pulse_phase"]) * spark["x_jitter"]
        color = spectral_color(spark["color_offset"], phase + spark_index * 0.7, 0.75 if glow else 1.0)
        pulse = 0.78 + 0.22 * math.sin(phase * 2.0 + spark["pulse_phase"])
        alpha = spark["alpha"] * vertical_envelope(body_t) * pulse
        if alpha <= 1:
            continue
        radius = spark["radius"] * (0.88 + 0.12 * pulse)
        draw_disc(img, x, y, radius, (*color, alpha), additive=glow)

    if glow:
        img = img.filter(ImageFilter.GaussianBlur(1.15))
    return img


def pack_sheet(frames: list[Image.Image]) -> Image.Image:
    sheet = Image.new("RGBA", (FRAME_SIZE * LINE_LENGTH, FRAME_SIZE * math.ceil(len(frames) / LINE_LENGTH)), (0, 0, 0, 0))
    for index, frame in enumerate(frames):
        x = (index % LINE_LENGTH) * FRAME_SIZE
        y = (index // LINE_LENGTH) * FRAME_SIZE
        sheet.alpha_composite(frame, (x, y))
    return sheet


def sheet_bounds(spec: SheetSpec) -> dict[str, object]:
    img = Image.open(spec.path).convert("RGBA")
    warnings: list[str] = []
    bounds = []
    for index in range(spec.frame_count):
        x = (index % spec.line_length) * spec.frame_size[0]
        y = (index // spec.line_length) * spec.frame_size[1]
        frame = img.crop((x, y, x + spec.frame_size[0], y + spec.frame_size[1]))
        bbox = frame.getchannel("A").getbbox()
        bounds.append(bbox)
        if bbox is None:
            warnings.append(f"frame {index} is fully transparent")
            continue
        left, top, right, bottom = bbox
        if min(left, top, spec.frame_size[0] - right, spec.frame_size[1] - bottom) < 18:
            warnings.append(f"frame {index} alpha is close to the frame edge: {bbox}")

    return {
        "file": str(spec.path.relative_to(ROOT)).replace("\\", "/"),
        "frame_size": list(spec.frame_size),
        "frame_count": spec.frame_count,
        "line_length": spec.line_length,
        "alpha_bounds": bounds,
        "warnings": warnings,
    }


def paste_layer(
    canvas: Image.Image,
    frame: Image.Image,
    scale: float,
    shift: tuple[float, float],
    glow: bool = False,
    tint: tuple[int, int, int, int] | None = None,
) -> None:
    layer = frame
    if tint is not None:
        r, g, b, a = tint
        pixels = layer.load()
        layer = layer.copy()
        pixels = layer.load()
        for y in range(layer.height):
            for x in range(layer.width):
                pr, pg, pb, pa = pixels[x, y]
                if pa:
                    pixels[x, y] = (
                        clamp(pr * r / 255.0),
                        clamp(pg * g / 255.0),
                        clamp(pb * b / 255.0),
                        clamp(pa * a / 255.0),
                    )

    size = (max(1, int(round(layer.width * scale))), max(1, int(round(layer.height * scale))))
    layer = layer.resize(size, Image.Resampling.LANCZOS)
    if glow:
        layer = layer.filter(ImageFilter.GaussianBlur(0.35))
    x = int(round(canvas.width / 2 + shift[0] * 32 - size[0] / 2))
    y = int(round(canvas.height / 2 + shift[1] * 32 - size[1] / 2))
    canvas.alpha_composite(layer, (x, y))


def first_frame(path: Path) -> Image.Image:
    return Image.open(path).convert("RGBA").crop((0, 0, FRAME_SIZE, FRAME_SIZE))


def make_factorio_preview(link: Image.Image, link_glow: Image.Image) -> Image.Image:
    base = first_frame(GRAPHICS_DIR / "singularity-lance.png")
    base_shadow = first_frame(GRAPHICS_DIR / "singularity-lance_base-shadow.png")
    crystal_shadow = first_frame(GRAPHICS_DIR / "singularity-lance_shadow.png")
    crystal = first_frame(GRAPHICS_DIR / "singularity-lance_crystal.png")

    backgrounds = [
        ((17, 20, 23), "dark"),
        ((104, 80, 47), "desert"),
        ((63, 83, 57), "grass"),
    ]
    rows = []
    for bg, label in backgrounds:
        canvas = Image.new("RGBA", (720, 520), (*bg, 255))
        draw = ImageDraw.Draw(canvas)
        for y in range(0, canvas.height, 32):
            draw.line((0, y, canvas.width, y), fill=(255, 255, 255, 18))
        for x in range(0, canvas.width, 32):
            draw.line((x, 0, x, canvas.height), fill=(255, 255, 255, 14))
        draw.text((14, 12), label, fill=(236, 238, 240, 255) if sum(bg) < 300 else (21, 22, 23, 255))

        paste_layer(canvas, base_shadow, ARRAY_BODY_SCALE, ARRAY_BODY_SHADOW_SHIFT)
        paste_layer(canvas, crystal_shadow, ARRAY_CRYSTAL_SCALE, ARRAY_CRYSTAL_SHIFT)
        paste_layer(canvas, base, ARRAY_BODY_SCALE, ARRAY_BODY_SHIFT)
        paste_layer(canvas, link, ARRAY_CRYSTAL_LINK_SCALE, ARRAY_CRYSTAL_LINK_SHIFT)
        paste_layer(canvas, link_glow, ARRAY_CRYSTAL_LINK_SCALE, ARRAY_CRYSTAL_LINK_SHIFT, glow=True)
        paste_layer(canvas, crystal, ARRAY_CRYSTAL_SCALE, ARRAY_CRYSTAL_SHIFT)
        paste_layer(canvas, crystal, ARRAY_CRYSTAL_SCALE, ARRAY_CRYSTAL_SHIFT, tint=(163, 250, 255, 133))
        rows.append(canvas)

    preview = Image.new("RGBA", (720, 520 * len(rows)), (0, 0, 0, 255))
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
        "mode": "singularity-lance-crystal-link",
        "source_assets": [
            str((BEAM_DIR / "singularity-lance-beam-body.png").relative_to(REPO_ROOT)).replace("\\", "/"),
            str((BEAM_DIR / "singularity-lance-beam-body-glow.png").relative_to(REPO_ROOT)).replace("\\", "/"),
        ],
        "generator": str(Path(__file__).resolve().relative_to(REPO_ROOT)).replace("\\", "/"),
        "seed": SEED,
        "staged_assets": sheets,
        "previews": [str(path.relative_to(ROOT)).replace("\\", "/") for path in previews],
        "target_graphics_dir": str(CRYSTAL_LINK_DIR.relative_to(REPO_ROOT)).replace("\\", "/"),
        "prototype_file": "exotic-space-industries-remembrance/prototypes/alien-system/singularity-lance.lua",
        "frame": {
            "size": FRAME_SIZE,
            "frame_count": FRAME_COUNT,
            "line_length": LINE_LENGTH,
            "scale": ARRAY_CRYSTAL_LINK_SCALE,
            "shift": list(ARRAY_CRYSTAL_LINK_SHIFT),
            "crystal_shift": list(ARRAY_CRYSTAL_SHIFT),
            "animation_speed": 0.55,
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

    body_path = BEAM_DIR / "singularity-lance-beam-body.png"
    glow_path = BEAM_DIR / "singularity-lance-beam-body-glow.png"
    if not body_path.exists() or not glow_path.exists():
        raise FileNotFoundError(f"Expected promoted beam body sheets in {BEAM_DIR}")

    normal_sources = crop_beam_frames(Image.open(body_path).convert("RGBA"))
    glow_sources = crop_beam_frames(Image.open(glow_path).convert("RGBA"))

    normal_frames = [draw_link_frame(index, normal_sources, False) for index in range(FRAME_COUNT)]
    glow_frames = [draw_link_frame(index, glow_sources, True) for index in range(FRAME_COUNT)]

    specs = [
        SheetSpec(EXPORT_DIR / NORMAL_FILENAME, (FRAME_SIZE, FRAME_SIZE), FRAME_COUNT, LINE_LENGTH),
        SheetSpec(EXPORT_DIR / GLOW_FILENAME, (FRAME_SIZE, FRAME_SIZE), FRAME_COUNT, LINE_LENGTH),
    ]
    pack_sheet(normal_frames).save(specs[0].path)
    pack_sheet(glow_frames).save(specs[1].path)

    if promote:
        CRYSTAL_LINK_DIR.mkdir(parents=True, exist_ok=True)
        shutil.copy2(specs[0].path, CRYSTAL_LINK_DIR / NORMAL_FILENAME)
        shutil.copy2(specs[1].path, CRYSTAL_LINK_DIR / GLOW_FILENAME)

    preview_paths = [
        PREVIEW_DIR / f"{ASSET_NAME}-factorio-scale-preview.png",
        PREVIEW_DIR / f"{ASSET_NAME}-frame-strip.png",
    ]
    make_factorio_preview(normal_frames[0], glow_frames[0]).save(preview_paths[0])
    make_frame_strip(normal_frames[::4], "Crystal link sampled frames").save(preview_paths[1])

    manifest = write_manifest(specs, preview_paths, promote)
    report = {
        "asset_name": ASSET_NAME,
        "export_dir": str(EXPORT_DIR.relative_to(ROOT)).replace("\\", "/"),
        "preview_dir": str(PREVIEW_DIR.relative_to(ROOT)).replace("\\", "/"),
        "files_written": [str(spec.path.relative_to(ROOT)).replace("\\", "/") for spec in specs],
        "promoted_files": [
            str((CRYSTAL_LINK_DIR / NORMAL_FILENAME).relative_to(REPO_ROOT)).replace("\\", "/"),
            str((CRYSTAL_LINK_DIR / GLOW_FILENAME).relative_to(REPO_ROOT)).replace("\\", "/"),
        ] if promote else [],
        "previews_written": [str(path.relative_to(ROOT)).replace("\\", "/") for path in preview_paths],
        "warnings": manifest["warnings"],
    }
    (ROOT / "source" / "generation-report.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
    return report


def main() -> None:
    parser = argparse.ArgumentParser(description="Generate the Singularity Lance chromatic crystal-link overlay sheets.")
    parser.add_argument("--promote", action="store_true", help="Copy generated PNGs into the live Singularity Lance crystal-link graphics folder.")
    args = parser.parse_args()
    print(json.dumps(generate(args.promote), indent=2))


if __name__ == "__main__":
    main()
