from __future__ import annotations

import argparse
import json
import math
import random
import shutil
from dataclasses import dataclass
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageStat


ASSET_NAME = "ei-singularity-lance-rune-glow"
OUTPUT_FILENAME = "singularity-lance-rune-glow.png"

FRAME_SIZE = 768
FRAME_COUNT = 64
LINE_LENGTH = 8
SEED = 612119
TAU = math.tau

MASK_DESCRIPTION = "a > 20 and g > 80 and b > 60 and r < 90 and g > r * 1.4"


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
BODY_SHEET = GRAPHICS_DIR / "singularity-lance.png"
PROMOTED_SHEET = GRAPHICS_DIR / OUTPUT_FILENAME


@dataclass(frozen=True)
class RunePixel:
    x: int
    y: int
    alpha: int
    phase: float


@dataclass(frozen=True)
class Spark:
    x: int
    y: int
    phase: float
    radius: float
    strength: float


def clamp(value: float, low: int = 0, high: int = 255) -> int:
    return int(max(low, min(high, round(value))))


def first_frame(sheet_path: Path) -> Image.Image:
    image = Image.open(sheet_path).convert("RGBA")
    return image.crop((0, 0, FRAME_SIZE, FRAME_SIZE))


def mask_predicate(r: int, g: int, b: int, a: int) -> bool:
    return a > 20 and g > 80 and b > 60 and r < 90 and g > r * 1.4


def make_rune_mask(body_frame: Image.Image) -> tuple[Image.Image, list[RunePixel]]:
    rng = random.Random(SEED)
    source = body_frame.load()
    mask = Image.new("L", (FRAME_SIZE, FRAME_SIZE), 0)
    mask_pixels = mask.load()
    cell_phases: dict[tuple[int, int], float] = {}
    rune_pixels: list[RunePixel] = []

    for y in range(FRAME_SIZE):
        for x in range(FRAME_SIZE):
            r, g, b, a = source[x, y]
            if not mask_predicate(r, g, b, a):
                continue

            color_strength = max(0.0, min(1.0, (g - r * 1.4) / 155.0))
            brightness = max(g, b) / 255.0
            alpha = clamp((36.0 + 164.0 * brightness * color_strength) * (a / 255.0), 0, 205)
            if alpha <= 0:
                continue

            cell = (x // 22, y // 22)
            if cell not in cell_phases:
                cell_phases[cell] = rng.random() * TAU

            local_phase = cell_phases[cell] + x * 0.019 + y * 0.013
            mask_pixels[x, y] = alpha
            rune_pixels.append(RunePixel(x=x, y=y, alpha=alpha, phase=local_phase))

    return mask, rune_pixels


def choose_sparks(rune_pixels: list[RunePixel]) -> list[Spark]:
    rng = random.Random(SEED + 41)
    candidates = [pixel for pixel in rune_pixels if pixel.alpha >= 72]
    if len(candidates) < 24:
        candidates = list(rune_pixels)

    sparks: list[Spark] = []
    used: list[tuple[int, int]] = []
    attempts = 0
    while candidates and len(sparks) < 28 and attempts < 800:
        attempts += 1
        pixel = rng.choice(candidates)
        if any((pixel.x - x) ** 2 + (pixel.y - y) ** 2 < 20**2 for x, y in used):
            continue
        used.append((pixel.x, pixel.y))
        sparks.append(
            Spark(
                x=pixel.x,
                y=pixel.y,
                phase=rng.random() * TAU,
                radius=rng.uniform(1.2, 2.4),
                strength=rng.uniform(0.65, 1.0),
            )
        )

    return sparks


def tint_for_pixel(phase: float, pixel_phase: float) -> tuple[int, int, int]:
    color_slide = 0.5 + 0.5 * math.sin(phase + pixel_phase * 0.31)
    return (
        clamp(14 + 30 * color_slide),
        clamp(205 + 45 * color_slide),
        clamp(226 + 28 * (1.0 - color_slide)),
    )


def draw_sparks(frame: Image.Image, sparks: list[Spark], phase: float) -> Image.Image:
    spark_alpha = Image.new("L", (FRAME_SIZE, FRAME_SIZE), 0)
    draw = ImageDraw.Draw(spark_alpha)

    for spark in sparks:
        pulse = max(0.0, math.sin(phase + spark.phase))
        pulse = pulse**10
        if pulse < 0.025:
            continue

        radius = spark.radius * (1.0 + pulse * 1.25)
        alpha = clamp(190 * pulse * spark.strength)
        draw.ellipse(
            (
                spark.x - radius,
                spark.y - radius,
                spark.x + radius,
                spark.y + radius,
            ),
            fill=alpha,
        )

    spark_alpha = spark_alpha.filter(ImageFilter.GaussianBlur(0.85))
    spark_layer = Image.new("RGBA", (FRAME_SIZE, FRAME_SIZE), (168, 255, 255, 0))
    spark_layer.putalpha(spark_alpha)
    return Image.alpha_composite(frame, spark_layer)


def draw_frame(index: int, rune_pixels: list[RunePixel], sparks: list[Spark]) -> Image.Image:
    phase = TAU * index / FRAME_COUNT
    frame = Image.new("RGBA", (FRAME_SIZE, FRAME_SIZE), (0, 0, 0, 0))
    pixels = frame.load()

    for pixel in rune_pixels:
        slow = 0.56 + 0.24 * math.sin(phase + pixel.phase)
        ripple = 0.13 * math.sin(phase * 2.0 + pixel.phase * 0.47 + pixel.x * 0.021 - pixel.y * 0.014)
        pulse = max(0.0, min(1.0, slow + ripple))
        alpha = clamp(pixel.alpha * pulse * 0.70)
        if alpha <= 0:
            continue

        r, g, b = tint_for_pixel(phase, pixel.phase)
        pixels[pixel.x, pixel.y] = (r, g, b, alpha)

    core_alpha = frame.getchannel("A")
    halo_alpha = core_alpha.filter(ImageFilter.GaussianBlur(1.45)).point(lambda value: clamp(value * 0.32))
    halo = Image.new("RGBA", (FRAME_SIZE, FRAME_SIZE), (28, 235, 255, 0))
    halo.putalpha(halo_alpha)
    frame = Image.alpha_composite(halo, frame)

    return draw_sparks(frame, sparks, phase)


def pack_sheet(frames: list[Image.Image]) -> Image.Image:
    sheet = Image.new("RGBA", (FRAME_SIZE * LINE_LENGTH, FRAME_SIZE * math.ceil(FRAME_COUNT / LINE_LENGTH)), (0, 0, 0, 0))
    for index, frame in enumerate(frames):
        x = (index % LINE_LENGTH) * FRAME_SIZE
        y = (index // LINE_LENGTH) * FRAME_SIZE
        sheet.paste(frame, (x, y))
    return sheet


def checkerboard(size: tuple[int, int], cell: int = 16) -> Image.Image:
    image = Image.new("RGBA", size, (48, 48, 48, 255))
    draw = ImageDraw.Draw(image)
    for y in range(0, size[1], cell):
        for x in range(0, size[0], cell):
            if (x // cell + y // cell) % 2 == 0:
                draw.rectangle((x, y, x + cell - 1, y + cell - 1), fill=(70, 70, 70, 255))
    return image


def make_previews(body_frame: Image.Image, frames: list[Image.Image]) -> None:
    PREVIEW_DIR.mkdir(parents=True, exist_ok=True)
    selected = list(range(0, FRAME_COUNT, 8))
    thumb_size = (256, 256)

    overlay_strip = Image.new("RGBA", (thumb_size[0] * len(selected), thumb_size[1]), (0, 0, 0, 0))
    composite_strip = Image.new("RGBA", (thumb_size[0] * len(selected), thumb_size[1]), (0, 0, 0, 0))
    body_thumb = body_frame.resize(thumb_size, Image.Resampling.LANCZOS)

    for column, index in enumerate(selected):
        overlay = frames[index].resize(thumb_size, Image.Resampling.LANCZOS)
        checker = checkerboard(thumb_size, 16)
        overlay_strip.alpha_composite(Image.alpha_composite(checker, overlay), (column * thumb_size[0], 0))
        composite_strip.alpha_composite(Image.alpha_composite(body_thumb, overlay), (column * thumb_size[0], 0))

    overlay_strip.save(PREVIEW_DIR / "singularity-lance-rune-glow-overlay-strip.png")
    composite_strip.save(PREVIEW_DIR / "singularity-lance-rune-glow-composite-strip.png")

    gif_frames = [
        Image.alpha_composite(body_frame, frame).resize(thumb_size, Image.Resampling.LANCZOS).convert("P", palette=Image.Palette.ADAPTIVE)
        for frame in frames
    ]
    gif_frames[0].save(
        PREVIEW_DIR / "singularity-lance-rune-glow-loop.gif",
        save_all=True,
        append_images=gif_frames[1:],
        duration=80,
        loop=0,
        optimize=False,
    )


def alpha_pixel_count(alpha: Image.Image) -> int:
    histogram = alpha.histogram()
    return sum(histogram[1:])


def make_manifest(mask: Image.Image, frames: list[Image.Image], promoted: bool) -> dict:
    frame_alpha_sums = [int(ImageStat.Stat(frame.getchannel("A")).sum[0]) for frame in frames]
    loop_delta = ImageChops.difference(frames[0].getchannel("A"), frames[-1].getchannel("A"))

    return {
        "asset_name": ASSET_NAME,
        "mode": "source-derived-rune-glow-overlay",
        "seed": SEED,
        "source": str(BODY_SHEET.relative_to(REPO_ROOT)).replace("\\", "/"),
        "output": {
            "sheet": str((EXPORT_DIR / OUTPUT_FILENAME).relative_to(REPO_ROOT)).replace("\\", "/"),
            "promoted_sheet": str(PROMOTED_SHEET.relative_to(REPO_ROOT)).replace("\\", "/"),
            "promoted": promoted,
        },
        "sheet": {
            "frame_size": [FRAME_SIZE, FRAME_SIZE],
            "frame_count": FRAME_COUNT,
            "line_length": LINE_LENGTH,
            "dimensions": [FRAME_SIZE * LINE_LENGTH, FRAME_SIZE * math.ceil(FRAME_COUNT / LINE_LENGTH)],
        },
        "mask": {
            "predicate": MASK_DESCRIPTION,
            "bbox": list(mask.getbbox() or ()),
            "nonzero_pixels": alpha_pixel_count(mask),
        },
        "frames": {
            "nonblank_count": sum(1 for frame in frames if frame.getchannel("A").getbbox() is not None),
            "alpha_sum_min": min(frame_alpha_sums),
            "alpha_sum_max": max(frame_alpha_sums),
            "loop_delta_alpha_mean": ImageStat.Stat(loop_delta).mean[0],
        },
        "prototype": {
            "file": "exotic-space-industries-remembrance/prototypes/alien-system/singularity-lance.lua",
            "layer": {
                "draw_as_glow": True,
                "blend_mode": "additive-soft",
                "animation_speed": 0.16,
                "scale": "LANCE_BODY_SCALE",
                "shift": "LANCE_BODY_SHIFT",
            },
        },
    }


def write_outputs(promote: bool) -> dict:
    EXPORT_DIR.mkdir(parents=True, exist_ok=True)
    PREVIEW_DIR.mkdir(parents=True, exist_ok=True)

    body_frame = first_frame(BODY_SHEET)
    mask, rune_pixels = make_rune_mask(body_frame)
    if not rune_pixels:
        raise RuntimeError(f"No rune pixels matched mask predicate: {MASK_DESCRIPTION}")

    sparks = choose_sparks(rune_pixels)
    frames = [draw_frame(index, rune_pixels, sparks) for index in range(FRAME_COUNT)]
    sheet = pack_sheet(frames)
    sheet_path = EXPORT_DIR / OUTPUT_FILENAME
    sheet.save(sheet_path)

    mask.save(PREVIEW_DIR / "singularity-lance-rune-mask.png")
    make_previews(body_frame, frames)

    if promote:
        GRAPHICS_DIR.mkdir(parents=True, exist_ok=True)
        shutil.copy2(sheet_path, PROMOTED_SHEET)

    manifest = make_manifest(mask, frames, promote)
    with (ROOT / "generation-report.json").open("w", encoding="utf-8") as handle:
        json.dump(manifest, handle, indent=2)
        handle.write("\n")
    with (EXPORT_DIR / f"{ASSET_NAME}.factorio-asset-manifest.json").open("w", encoding="utf-8") as handle:
        json.dump(manifest, handle, indent=2)
        handle.write("\n")

    return manifest


def main() -> None:
    parser = argparse.ArgumentParser(description="Generate the Singularity Lance rune twinkle glow overlay.")
    parser.add_argument("--promote", action="store_true", help="Copy the generated sheet into the live Singularity Lance graphics folder.")
    args = parser.parse_args()

    manifest = write_outputs(promote=args.promote)
    print(json.dumps(manifest, indent=2))


if __name__ == "__main__":
    main()
