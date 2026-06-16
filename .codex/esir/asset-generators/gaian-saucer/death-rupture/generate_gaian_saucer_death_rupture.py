from __future__ import annotations

import argparse
import json
import math
import random
import shutil
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter


ASSET_NAME = "ei-gaian-saucer-death-rupture"
FRAME_SIZE = 512
FRAME_COUNT = 48
LINE_LENGTH = 8
ROWS = 6
SEED = 505030805

NORMAL_FILENAME = "gaian-saucer-death-rupture.png"
GLOW_FILENAME = "gaian-saucer-death-rupture-glow.png"


def find_repo_root(start: Path) -> Path:
    for path in [start, *start.parents]:
        if (path / ".gitignore").exists() and (path / "exotic-space-industries-remembrance").exists():
            return path
    raise RuntimeError(f"Could not find repository root from {start}")


REPO_ROOT = find_repo_root(Path(__file__).resolve())
ROOT = REPO_ROOT / "output" / "meshy" / ASSET_NAME
EXPORT_DIR = ROOT / "factorio-export"
PREVIEW_DIR = ROOT / "previews"
SOURCE_DIR = ROOT / "source"
SAUCER_DIR = REPO_ROOT / "exotic-space-industries-remembrance" / "graphics" / "entities" / "gaian-saucer"
DEATH_DIR = SAUCER_DIR / "death"


def clamp(value: float, low: float = 0.0, high: float = 255.0) -> int:
    return int(max(low, min(high, value)))


def mix(a: tuple[int, int, int], b: tuple[int, int, int], t: float) -> tuple[int, int, int]:
    t = max(0.0, min(1.0, t))
    return (
        clamp(a[0] + (b[0] - a[0]) * t),
        clamp(a[1] + (b[1] - a[1]) * t),
        clamp(a[2] + (b[2] - a[2]) * t),
    )


def spectral_color(angle: float, phase: float, heat: float = 1.0) -> tuple[int, int, int]:
    wave = 0.5 + 0.5 * math.sin(angle * 2.0 + phase)
    band = (angle / math.tau + phase / math.tau) % 1.0
    if band < 0.28:
        color = mix((0, 238, 255), (60, 112, 255), wave)
    elif band < 0.58:
        color = mix((64, 255, 128), (250, 255, 72), wave)
    else:
        color = mix((255, 36, 206), (126, 62, 255), wave)
    return mix(color, (255, 246, 210), max(0.0, min(1.0, heat - 1.0)) * 0.32)


def ease_out(t: float) -> float:
    t = max(0.0, min(1.0, t))
    return 1.0 - (1.0 - t) ** 3


def ease_in_out(t: float) -> float:
    t = max(0.0, min(1.0, t))
    return t * t * (3.0 - 2.0 * t)


def fade_to_frame_margin(position: int, size: int, margin: int = 20, soft: int = 16) -> float:
    distance = min(position, size - 1 - position)
    if distance < margin:
        return 0.0
    if distance < margin + soft:
        return ((distance - margin) / max(1, soft)) ** 0.75
    return 1.0


def apply_frame_fade(img: Image.Image, margin: int = 20, soft: int = 16) -> Image.Image:
    pixels = img.load()
    for y in range(img.height):
        fy = fade_to_frame_margin(y, img.height, margin, soft)
        for x in range(img.width):
            fx = fade_to_frame_margin(x, img.width, margin, soft)
            r, g, b, a = pixels[x, y]
            a = clamp(a * min(fx, fy))
            pixels[x, y] = (r, g, b, a) if a > 2 else (0, 0, 0, 0)
    return img


def draw_arc(
    draw: ImageDraw.ImageDraw,
    center: tuple[float, float],
    radius: float,
    start: float,
    end: float,
    color: tuple[int, int, int, int],
    width: int,
) -> None:
    cx, cy = center
    box = (cx - radius, cy - radius, cx + radius, cy + radius)
    draw.arc(box, math.degrees(start), math.degrees(end), fill=color, width=max(1, width))


def draw_disc(
    draw: ImageDraw.ImageDraw,
    center: tuple[float, float],
    radius: float,
    color: tuple[int, int, int, int],
) -> None:
    cx, cy = center
    draw.ellipse((cx - radius, cy - radius, cx + radius, cy + radius), fill=color)


def draw_polyline(
    draw: ImageDraw.ImageDraw,
    points: list[tuple[float, float]],
    color: tuple[int, int, int, int],
    width: int,
) -> None:
    if len(points) >= 2:
        draw.line(points, fill=color, width=max(1, width), joint="curve")


def draw_shell_frame(index: int, glow: bool = False) -> Image.Image:
    rng = random.Random(SEED + index * 173 + (30000 if glow else 0))
    img = Image.new("RGBA", (FRAME_SIZE, FRAME_SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img, "RGBA")
    center = (FRAME_SIZE / 2, FRAME_SIZE / 2 + 3)
    progress = index / max(1, FRAME_COUNT - 1)
    phase = progress * math.tau

    ignition = min(1.0, progress / 0.18)
    expansion = ease_out(max(0.0, (progress - 0.10) / 0.72))
    fade = max(0.10, min(1.0, max(0.0, (1.0 - progress) / 0.36)))
    pulse = math.sin(min(1.0, progress / 0.28) * math.pi)

    inner_radius = 18 + 72 * pulse + 22 * math.sin(phase * 1.4)
    shell_radius = 52 + 150 * expansion
    outer_radius = 74 + 128 * ease_in_out(max(0.0, (progress - 0.16) / 0.62))
    collapse_radius = max(12, 88 * (1.0 - ignition) + 14)

    if glow:
        draw_disc(draw, center, 58 + 160 * expansion, (0, 210, 255, clamp(42 * fade)))
        draw_disc(draw, center, 40 + 118 * expansion, (255, 38, 218, clamp(44 * fade)))
        draw_disc(draw, center, 24 + 92 * pulse, (88, 255, 128, clamp(78 * max(fade, pulse * 0.7))))
    else:
        draw_disc(draw, center, 12 + 30 * pulse, (245, 255, 210, clamp(96 * max(pulse, fade * 0.25))))
        draw_disc(draw, center, max(8, collapse_radius), (12, 64, 48, clamp(34 * (1.0 - ignition))))

    arc_count = 9 if glow else 13
    for arc_index in range(arc_count):
        angle = arc_index / arc_count * math.tau + phase * (0.30 if glow else -0.22)
        span = 0.24 + 0.18 * math.sin(phase * 2.1 + arc_index)
        radius = shell_radius + math.sin(phase * 3.0 + arc_index * 1.9) * (10 if glow else 7)
        color = spectral_color(angle, phase * 2.2, 1.25 if not glow else 1.0)
        alpha = clamp((94 if glow else 156) * fade * (0.72 + 0.28 * rng.random()))
        width = rng.randrange(8, 16) if glow else rng.randrange(3, 8)
        draw_arc(draw, center, radius, angle - span, angle + span, (*color, alpha), width)

    crack_count = 12
    for crack_index in range(crack_count):
        angle = crack_index / crack_count * math.tau + math.sin(phase + crack_index) * 0.20
        if rng.random() < progress * 0.08:
            angle += rng.uniform(-0.30, 0.30)
        start_radius = inner_radius * rng.uniform(0.52, 0.84)
        end_radius = outer_radius * rng.uniform(0.72, 1.02)
        if progress < 0.09:
            end_radius = start_radius + 20 * ignition
        color = spectral_color(angle, phase + crack_index * 0.31, 1.45)
        alpha = clamp((52 if glow else 142) * fade * min(1.0, progress / 0.22 + 0.2))
        width = rng.randrange(4, 8) if glow else rng.randrange(1, 4)
        bend = rng.uniform(-0.24, 0.24)
        points = []
        for step in range(4):
            t = step / 3.0
            radius = start_radius + (end_radius - start_radius) * t
            local_angle = angle + bend * math.sin(t * math.pi) + rng.uniform(-0.035, 0.035)
            points.append((
                center[0] + math.cos(local_angle) * radius,
                center[1] + math.sin(local_angle) * radius * 0.84,
            ))
        draw_polyline(draw, points, (*color, alpha), width)

    shard_count = 22 if not glow else 12
    for shard_index in range(shard_count):
        t = rng.random()
        angle = rng.random() * math.tau
        radius = (44 + 156 * expansion) * rng.uniform(0.65, 1.05)
        color = spectral_color(angle, phase + shard_index, 1.20)
        alpha = clamp((104 if glow else 188) * fade * (0.35 + 0.65 * t))
        size = rng.uniform(1.6, 4.5 if not glow else 8.0)
        x = center[0] + math.cos(angle) * radius
        y = center[1] + math.sin(angle) * radius * 0.84
        draw_disc(draw, (x, y), size, (*color, alpha))

    if glow:
        img = img.filter(ImageFilter.GaussianBlur(3.2))
    else:
        img = img.filter(ImageFilter.GaussianBlur(0.25))

    return apply_frame_fade(img)


def pack_sheet(frames: list[Image.Image]) -> Image.Image:
    sheet = Image.new("RGBA", (FRAME_SIZE * LINE_LENGTH, FRAME_SIZE * ROWS), (0, 0, 0, 0))
    for index, frame in enumerate(frames):
        x = (index % LINE_LENGTH) * FRAME_SIZE
        y = (index // LINE_LENGTH) * FRAME_SIZE
        sheet.alpha_composite(frame, (x, y))
    return sheet


def frame_bounds(frame: Image.Image) -> tuple[int, int, int, int] | None:
    alpha = frame.getchannel("A")
    return alpha.getbbox()


def validate_frames(frames: list[Image.Image]) -> dict:
    empty = []
    min_margin = FRAME_SIZE
    bounds = []
    for index, frame in enumerate(frames):
        bbox = frame_bounds(frame)
        if not bbox:
            empty.append(index)
            bounds.append(None)
            min_margin = 0
            continue
        left, top, right, bottom = bbox
        margin = min(left, top, FRAME_SIZE - right, FRAME_SIZE - bottom)
        min_margin = min(min_margin, margin)
        bounds.append([left, top, right, bottom])
    return {
        "frame_count": len(frames),
        "empty_frames": empty,
        "min_alpha_margin": min_margin,
        "bounds": bounds,
    }


def first_frame(sheet_path: Path, frame_size: int = 768) -> Image.Image | None:
    if not sheet_path.exists():
        return None
    sheet = Image.open(sheet_path).convert("RGBA")
    return sheet.crop((0, 0, frame_size, frame_size))


def paste_scaled(canvas: Image.Image, layer: Image.Image, scale: float, center: tuple[int, int], opacity: float = 1.0) -> None:
    w = max(1, int(layer.width * scale))
    h = max(1, int(layer.height * scale))
    resized = layer.resize((w, h), Image.Resampling.LANCZOS)
    if opacity < 1.0:
        alpha = resized.getchannel("A").point(lambda value: clamp(value * opacity))
        resized.putalpha(alpha)
    canvas.alpha_composite(resized, (center[0] - w // 2, center[1] - h // 2))


def make_preview(normal_frames: list[Image.Image], glow_frames: list[Image.Image]) -> Path:
    PREVIEW_DIR.mkdir(parents=True, exist_ok=True)
    canvas = Image.new("RGBA", (780, 360), (26, 24, 28, 255))
    draw = ImageDraw.Draw(canvas, "RGBA")
    for x in range(0, canvas.width, 26):
        shade = 38 + (x // 26) % 2 * 8
        draw.rectangle((x, 0, x + 25, canvas.height), fill=(shade, 34, 35, 255))

    saucer = first_frame(SAUCER_DIR / "gaian-saucer_dark_compact.png")
    saucer_glow = first_frame(SAUCER_DIR / "gaian-saucer_dark_compact_glow.png")
    saucer_shadow = first_frame(SAUCER_DIR / "gaian-saucer_dark_compact_shadow.png")
    center = (390, 176)
    frame_index = 18
    paste_scaled(canvas, glow_frames[frame_index], 0.52, center, 0.95)
    paste_scaled(canvas, normal_frames[frame_index], 0.52, center, 1.0)
    if saucer_shadow:
        paste_scaled(canvas, saucer_shadow, 0.69, (center[0] + 18, center[1] + 26), 0.35)
    if saucer:
        paste_scaled(canvas, saucer, 0.69, center, 0.42)
    if saucer_glow:
        paste_scaled(canvas, saucer_glow, 0.69, center, 0.70)

    preview_path = PREVIEW_DIR / f"{ASSET_NAME}-factorio-scale-preview.png"
    canvas.convert("RGBA").save(preview_path)
    return preview_path


def make_frame_strip(frames: list[Image.Image]) -> Path:
    PREVIEW_DIR.mkdir(parents=True, exist_ok=True)
    sample_indices = list(range(0, FRAME_COUNT, 4))
    thumb = 128
    strip = Image.new("RGBA", (thumb * len(sample_indices), thumb), (24, 22, 25, 255))
    for column, index in enumerate(sample_indices):
        frame = frames[index].resize((thumb, thumb), Image.Resampling.LANCZOS)
        strip.alpha_composite(frame, (column * thumb, 0))
    path = PREVIEW_DIR / f"{ASSET_NAME}-frame-strip.png"
    strip.save(path)
    return path


def promote_assets(normal_path: Path, glow_path: Path) -> list[str]:
    DEATH_DIR.mkdir(parents=True, exist_ok=True)
    promoted = []
    for source in (normal_path, glow_path):
        target = DEATH_DIR / source.name
        shutil.copy2(source, target)
        promoted.append(str(target.relative_to(REPO_ROOT)).replace("\\", "/"))
    return promoted


def write_report(paths: dict, normal_validation: dict, glow_validation: dict, promoted: list[str]) -> Path:
    SOURCE_DIR.mkdir(parents=True, exist_ok=True)
    report = {
        "asset_name": ASSET_NAME,
        "mode": "gaian-saucer-shell-rupture-death-explosion",
        "frame_size": FRAME_SIZE,
        "frame_count": FRAME_COUNT,
        "line_length": LINE_LENGTH,
        "sheet_dimensions": [FRAME_SIZE * LINE_LENGTH, FRAME_SIZE * ROWS],
        "normal": normal_validation,
        "glow": glow_validation,
        "outputs": {key: str(value.relative_to(REPO_ROOT)).replace("\\", "/") for key, value in paths.items()},
        "promoted": promoted,
    }
    report_path = SOURCE_DIR / "generation-report.json"
    report_path.write_text(json.dumps(report, indent=2), encoding="utf-8")
    return report_path


def main() -> None:
    parser = argparse.ArgumentParser(description="Generate the Slipwake Saucer shell-rupture death explosion sheets.")
    parser.add_argument("--promote", action="store_true", help="Copy approved sheets into the live saucer death graphics folder.")
    args = parser.parse_args()

    EXPORT_DIR.mkdir(parents=True, exist_ok=True)
    normal_frames = [draw_shell_frame(index, False) for index in range(FRAME_COUNT)]
    glow_frames = [draw_shell_frame(index, True) for index in range(FRAME_COUNT)]

    normal_path = EXPORT_DIR / NORMAL_FILENAME
    glow_path = EXPORT_DIR / GLOW_FILENAME
    pack_sheet(normal_frames).save(normal_path)
    pack_sheet(glow_frames).save(glow_path)

    preview_path = make_preview(normal_frames, glow_frames)
    strip_path = make_frame_strip(normal_frames)
    normal_validation = validate_frames(normal_frames)
    glow_validation = validate_frames(glow_frames)

    promoted = promote_assets(normal_path, glow_path) if args.promote else []
    report_path = write_report(
        {
            "normal_sheet": normal_path,
            "glow_sheet": glow_path,
            "factorio_scale_preview": preview_path,
            "frame_strip": strip_path,
            "report": SOURCE_DIR / "generation-report.json",
        },
        normal_validation,
        glow_validation,
        promoted,
    )

    print(f"Wrote {normal_path.relative_to(REPO_ROOT)}")
    print(f"Wrote {glow_path.relative_to(REPO_ROOT)}")
    print(f"Wrote {preview_path.relative_to(REPO_ROOT)}")
    print(f"Wrote {strip_path.relative_to(REPO_ROOT)}")
    print(f"Wrote {report_path.relative_to(REPO_ROOT)}")
    if promoted:
        print("Promoted:")
        for path in promoted:
            print(f"  {path}")

    failures = []
    for label, validation in (("normal", normal_validation), ("glow", glow_validation)):
        if validation["empty_frames"]:
            failures.append(f"{label} empty frames: {validation['empty_frames']}")
        if validation["min_alpha_margin"] < 18:
            failures.append(f"{label} min alpha margin {validation['min_alpha_margin']} < 18")
    if failures:
        raise SystemExit("; ".join(failures))


if __name__ == "__main__":
    main()
