from __future__ import annotations

import argparse
import json
import math
import random
import shutil
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageStat


ASSET_NAME = "ei-singularity-lance-death-implosion"
FRAME_SIZE = 512
FRAME_COUNT = 48
LINE_LENGTH = 8
ROWS = 6
SEED = 506050707

NORMAL_FILENAME = "singularity-lance-death-implosion.png"
GLOW_FILENAME = "singularity-lance-death-implosion-glow.png"


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
FRAMES_DIR = ROOT / "frames"
GRAPHICS_DIR = REPO_ROOT / "exotic-space-industries-remembrance" / "graphics" / "entities" / "singularity-lance" / "death"


def clamp(value: float, low: float = 0.0, high: float = 255.0) -> int:
    return int(max(low, min(high, value)))


def clamp01(value: float) -> float:
    return max(0.0, min(1.0, value))


def mix(a: tuple[int, int, int], b: tuple[int, int, int], t: float) -> tuple[int, int, int]:
    t = clamp01(t)
    return (
        clamp(a[0] + (b[0] - a[0]) * t),
        clamp(a[1] + (b[1] - a[1]) * t),
        clamp(a[2] + (b[2] - a[2]) * t),
    )


def smoothstep(t: float) -> float:
    t = clamp01(t)
    return t * t * (3.0 - 2.0 * t)


def ease_out(t: float) -> float:
    t = clamp01(t)
    return 1.0 - (1.0 - t) ** 3


def ease_in(t: float) -> float:
    t = clamp01(t)
    return t * t * t


def polar(center: tuple[float, float], angle: float, radius: float, y_scale: float = 0.78) -> tuple[float, float]:
    return (
        center[0] + math.cos(angle) * radius,
        center[1] + math.sin(angle) * radius * y_scale,
    )


def color_band(angle: float, phase: float, hot: float = 0.0) -> tuple[int, int, int]:
    wave = 0.5 + 0.5 * math.sin(angle * 2.2 + phase)
    violet = mix((55, 8, 112), (160, 38, 255), wave)
    cyan = mix((16, 224, 255), (132, 255, 248), 0.35 + 0.35 * wave)
    magenta = mix((118, 18, 210), (250, 42, 238), wave)
    band = (angle / math.tau + phase * 0.12) % 1.0
    if band < 0.18:
        color = cyan
    elif band < 0.58:
        color = violet
    else:
        color = magenta
    return mix(color, (236, 252, 255), hot * 0.36)


def make_specs(count: int, seed_offset: int) -> list[dict[str, float]]:
    rng = random.Random(SEED + seed_offset)
    specs: list[dict[str, float]] = []
    for _ in range(count):
        specs.append(
            {
                "angle": rng.random() * math.tau,
                "radius": rng.uniform(0.42, 1.12),
                "speed": rng.uniform(0.72, 1.28),
                "size": rng.uniform(0.45, 1.45),
                "spin": rng.uniform(-1.6, 1.6),
                "start": rng.uniform(0.00, 0.24),
                "cyan": rng.random(),
                "jitter": rng.random(),
            }
        )
    return specs


SMOKE_SPECS = make_specs(58, 11)
SPLINTER_SPECS = make_specs(46, 31)
MOTE_SPECS = make_specs(72, 47)
CRACK_SPECS = make_specs(18, 71)


def frame_visibility(progress: float) -> float:
    ignition = 0.12 + 0.88 * smoothstep(progress / 0.10)
    return ignition * (1.0 - smoothstep((progress - 0.80) / 0.20))


def fade_to_frame_margin(position: int, size: int, margin: int, soft: int) -> float:
    distance = min(position, size - 1 - position)
    if distance < margin:
        return 0.0
    if distance < margin + soft:
        return ((distance - margin) / max(1, soft)) ** 0.75
    return 1.0


def apply_frame_fade(img: Image.Image, margin: int = 20, soft: int = 16) -> Image.Image:
    pixels = img.load()
    x_fade = [fade_to_frame_margin(x, img.width, margin, soft) for x in range(img.width)]
    y_fade = [fade_to_frame_margin(y, img.height, margin, soft) for y in range(img.height)]
    for y in range(img.height):
        fy = y_fade[y]
        for x in range(img.width):
            r, g, b, a = pixels[x, y]
            alpha = clamp(a * min(x_fade[x], fy))
            pixels[x, y] = (r, g, b, alpha) if alpha > 2 else (0, 0, 0, 0)
    return img


def draw_disc(draw: ImageDraw.ImageDraw, center: tuple[float, float], radius: float, color: tuple[int, int, int, int]) -> None:
    x, y = center
    draw.ellipse((x - radius, y - radius, x + radius, y + radius), fill=color)


def draw_arc(
    draw: ImageDraw.ImageDraw,
    center: tuple[float, float],
    radius: float,
    start: float,
    end: float,
    color: tuple[int, int, int, int],
    width: int,
    y_scale: float = 0.78,
) -> None:
    x, y = center
    box = (x - radius, y - radius * y_scale, x + radius, y + radius * y_scale)
    draw.arc(box, math.degrees(start), math.degrees(end), fill=color, width=max(1, width))


def draw_splinter(
    draw: ImageDraw.ImageDraw,
    center: tuple[float, float],
    angle: float,
    length: float,
    width: float,
    color: tuple[int, int, int, int],
    edge: tuple[int, int, int, int] | None = None,
) -> None:
    forward = (math.cos(angle), math.sin(angle))
    side = (math.cos(angle + math.pi / 2.0), math.sin(angle + math.pi / 2.0))
    bend = 0.22 * math.sin(angle * 2.7 + length * 0.013)
    points = [
        (
            center[0] - forward[0] * length * 0.52 - side[0] * width * 0.18,
            center[1] - forward[1] * length * 0.38 - side[1] * width * 0.18,
        ),
        (
            center[0] - forward[0] * length * 0.12 + side[0] * width * bend,
            center[1] - forward[1] * length * 0.08 + side[1] * width * bend,
        ),
        (
            center[0] + forward[0] * length * 0.50 + side[0] * width * 0.10,
            center[1] + forward[1] * length * 0.36 + side[1] * width * 0.10,
        ),
    ]
    draw.line(points, fill=color, width=max(1, int(width)), joint="curve")
    if edge:
        draw.line(points, fill=edge, width=max(1, int(width * 0.34)), joint="curve")
    for point in points[1:]:
        draw.ellipse(
            (
                point[0] - width * 0.28,
                point[1] - width * 0.28,
                point[0] + width * 0.28,
                point[1] + width * 0.28,
            ),
            fill=color,
        )


def draw_polyline(draw: ImageDraw.ImageDraw, points: list[tuple[float, float]], color: tuple[int, int, int, int], width: int) -> None:
    if len(points) > 1:
        draw.line(points, fill=color, width=max(1, width), joint="curve")


def draw_implosion_frame(index: int, glow: bool = False) -> Image.Image:
    scale = 2
    size = FRAME_SIZE * scale
    center = (size / 2.0, size / 2.0 + 16 * scale)
    progress = index / max(1, FRAME_COUNT - 1)
    phase = progress * math.tau
    visibility = frame_visibility(progress)
    ignition = smoothstep(progress / 0.16)
    expansion = ease_out(progress / 0.56)
    collapse = smoothstep((progress - 0.52) / 0.34)
    final_fade = 1.0 - smoothstep((progress - 0.82) / 0.18)
    pulse = math.sin(clamp01(progress / 0.31) * math.pi)
    breathing = 0.5 + 0.5 * math.sin(phase * 3.0)
    ring_radius = (38 + 184 * expansion) * (1.0 - 0.78 * collapse) + 18 * collapse
    inner_radius = (18 + 74 * pulse) * (1.0 - 0.70 * collapse) + 9 * collapse
    smoke_radius = 56 + 166 * expansion
    alpha_gate = visibility * final_fade

    soft = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    hard = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    sparks = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    soft_draw = ImageDraw.Draw(soft, "RGBA")
    hard_draw = ImageDraw.Draw(hard, "RGBA")
    spark_draw = ImageDraw.Draw(sparks, "RGBA")

    if glow:
        draw_disc(soft_draw, center, (92 + 142 * expansion) * scale, (34, 0, 96, clamp(34 * alpha_gate)))
        draw_disc(soft_draw, center, (44 + 96 * pulse) * scale, (0, 224, 255, clamp(60 * alpha_gate)))
        draw_disc(soft_draw, center, max(8, inner_radius * 0.82) * scale, (255, 30, 238, clamp(78 * alpha_gate)))

        for arc_index in range(18):
            angle = arc_index / 18.0 * math.tau - phase * 0.34
            span = 0.16 + 0.16 * math.sin(phase * 1.6 + arc_index)
            radius = ring_radius * scale * (0.84 + 0.13 * math.sin(phase * 2.1 + arc_index))
            color = color_band(angle, phase, 0.7)
            alpha = clamp((92 + 54 * breathing) * alpha_gate)
            draw_arc(soft_draw, center, radius, angle - span, angle + span, (*color, alpha), int((9 + arc_index % 5) * scale))

        for crack_index, spec in enumerate(CRACK_SPECS):
            active = smoothstep((progress - spec["start"]) / 0.20)
            if active <= 0.01 or progress > 0.86:
                continue
            angle = spec["angle"] - phase * (0.20 + spec["speed"] * 0.08)
            end_radius = ring_radius * scale * (0.66 + 0.38 * spec["radius"])
            points = []
            for step in range(5):
                t = step / 4.0
                radius = (inner_radius * 0.25 * scale) + end_radius * t
                local = angle + math.sin(t * math.pi + spec["jitter"] * 6.0) * 0.18
                points.append(polar(center, local, radius))
            color = color_band(angle, phase, 1.0)
            draw_polyline(soft_draw, points, (*color, clamp(120 * alpha_gate * active)), int(7 * scale))

        for spec in MOTE_SPECS:
            active = smoothstep((progress - spec["start"]) / 0.22)
            if active <= 0.01:
                continue
            radius = (30 + 180 * expansion * spec["radius"]) * (1.0 - collapse * 0.82) + collapse * 14
            angle = spec["angle"] + phase * (0.18 - spec["spin"] * 0.04)
            x, y = polar(center, angle, radius * scale)
            mote_size = (2.0 + 5.5 * spec["size"]) * scale * (1.0 - 0.35 * collapse)
            color = (120, 255, 252) if spec["cyan"] > 0.46 else (214, 64, 255)
            draw_disc(spark_draw, (x, y), mote_size, (*color, clamp(86 * active * alpha_gate)))

        soft = soft.filter(ImageFilter.GaussianBlur(6.5 * scale))
        sparks = sparks.filter(ImageFilter.GaussianBlur(1.4 * scale))
    else:
        for spec in SMOKE_SPECS:
            active = smoothstep((progress - spec["start"]) / 0.28)
            if active <= 0.01:
                continue
            angle = spec["angle"] + math.sin(phase + spec["jitter"] * 10.0) * 0.08
            radius = smoke_radius * spec["radius"] * (1.0 - collapse * 0.78) + collapse * 18
            x, y = polar(center, angle, radius * scale)
            puff = (15 + 31 * spec["size"]) * scale * (1.0 - 0.38 * collapse)
            violet = mix((8, 0, 24), (88, 20, 145), spec["cyan"] * 0.55)
            alpha = clamp((34 + 66 * spec["size"]) * active * alpha_gate)
            soft_draw.ellipse((x - puff * 1.35, y - puff, x + puff * 1.35, y + puff), fill=(*violet, alpha))

        for arc_index in range(14):
            angle = arc_index / 14.0 * math.tau + phase * 0.22
            span = 0.18 + 0.18 * math.sin(phase * 1.8 + arc_index)
            radius = ring_radius * scale * (0.88 + 0.15 * math.sin(phase * 2.0 + arc_index * 1.4))
            color = color_band(angle, phase, 0.15)
            draw_arc(hard_draw, center, radius, angle - span, angle + span, (*color, clamp(132 * alpha_gate)), int((3 + arc_index % 4) * scale))

        for crack_index, spec in enumerate(CRACK_SPECS):
            active = smoothstep((progress - spec["start"]) / 0.24)
            if active <= 0.01 or progress > 0.88:
                continue
            angle = spec["angle"] + phase * (0.12 + spec["spin"] * 0.03)
            start_radius = inner_radius * scale * (0.22 + spec["jitter"] * 0.32)
            end_radius = ring_radius * scale * (0.60 + 0.40 * spec["radius"])
            points = []
            for step in range(5):
                t = step / 4.0
                radius = start_radius + (end_radius - start_radius) * t
                local = angle + math.sin(t * math.pi * 1.3 + spec["jitter"] * 5.0) * 0.16
                points.append(polar(center, local, radius))
            color = color_band(angle, phase, 0.65)
            draw_polyline(hard_draw, points, (*color, clamp(160 * alpha_gate * active)), int((1.2 + spec["size"]) * scale))

        for splinter_index, spec in enumerate(SPLINTER_SPECS):
            active = smoothstep((progress - spec["start"]) / 0.26)
            if active <= 0.01:
                continue
            angle = spec["angle"] + phase * (0.12 + spec["spin"] * 0.05) + collapse * 0.9
            radius = (28 + 170 * expansion * spec["radius"] * spec["speed"]) * (1.0 - collapse * 0.78) + collapse * 16
            x, y = polar(center, angle, radius * scale)
            length = (16 + 42 * spec["size"]) * scale * (1.0 - 0.42 * collapse)
            width = (1.2 + 2.4 * spec["size"]) * scale
            color = (32, 214, 232) if spec["cyan"] > 0.73 else (128, 34, 214)
            edge = (132, 255, 250, clamp(110 * alpha_gate * active)) if spec["cyan"] > 0.73 else (214, 74, 255, clamp(96 * alpha_gate * active))
            draw_splinter(
                hard_draw,
                (x, y),
                angle + math.pi * 0.5 + phase * spec["spin"],
                length,
                width,
                (*color, clamp(170 * alpha_gate * active)),
                edge,
            )
            if spec["jitter"] > 0.46:
                dust_radius = (1.4 + 2.4 * spec["size"]) * scale
                dust_x = x + math.cos(angle + spec["spin"]) * length * 0.24
                dust_y = y + math.sin(angle + spec["spin"]) * length * 0.18
                draw_disc(spark_draw, (dust_x, dust_y), dust_radius, (*color, clamp(92 * alpha_gate * active)))

        draw_disc(hard_draw, center, max(8, inner_radius * 0.86) * scale, (0, 0, 6, clamp(230 * alpha_gate)))
        draw_disc(hard_draw, center, max(12, inner_radius * 1.18) * scale, (22, 0, 52, clamp(68 * alpha_gate)))
        draw_arc(hard_draw, center, max(16, inner_radius * 1.28) * scale, 0, math.tau, (98, 20, 178, clamp(150 * alpha_gate)), int(4 * scale))

        for spec in MOTE_SPECS:
            active = smoothstep((progress - spec["start"]) / 0.24)
            if active <= 0.02:
                continue
            radius = (24 + 180 * expansion * spec["radius"]) * (1.0 - collapse * 0.82) + collapse * 10
            angle = spec["angle"] - phase * (0.16 + spec["spin"] * 0.03)
            x, y = polar(center, angle, radius * scale)
            dot = (1.2 + 3.2 * spec["size"]) * scale
            color = color_band(angle, phase, 0.6)
            draw_disc(spark_draw, (x, y), dot, (*color, clamp(150 * active * alpha_gate)))

        soft = soft.filter(ImageFilter.GaussianBlur(4.0 * scale))
        hard = hard.filter(ImageFilter.GaussianBlur(0.30 * scale))
        sparks = sparks.filter(ImageFilter.GaussianBlur(0.35 * scale))

    frame = Image.alpha_composite(soft, hard)
    frame = Image.alpha_composite(frame, sparks)
    frame = add_edge_shudder(frame, progress, scale)
    frame = frame.resize((FRAME_SIZE, FRAME_SIZE), Image.Resampling.LANCZOS)
    frame = apply_frame_fade(frame)
    return frame


def add_edge_shudder(img: Image.Image, progress: float, scale: int) -> Image.Image:
    if progress < 0.12 or progress > 0.86:
        return img
    rng = random.Random(SEED + int(progress * 1000))
    scratch = Image.new("RGBA", img.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(scratch, "RGBA")
    center = (img.width / 2, img.height / 2 + 16 * scale)
    for _ in range(22):
        angle = rng.random() * math.tau
        radius = rng.uniform(50, 214) * scale * (1.0 - smoothstep((progress - 0.66) / 0.24) * 0.72)
        x, y = polar(center, angle, radius)
        length = rng.uniform(8, 26) * scale
        color = (34, 245, 255) if rng.random() > 0.55 else (174, 32, 248)
        draw.line(
            [
                (x, y),
                (x + math.cos(angle + rng.uniform(-0.8, 0.8)) * length, y + math.sin(angle + rng.uniform(-0.8, 0.8)) * length * 0.70),
            ],
            fill=(*color, rng.randrange(24, 86)),
            width=rng.randrange(1, 3) * scale,
        )
    return Image.alpha_composite(img, scratch.filter(ImageFilter.GaussianBlur(0.45 * scale)))


def pack_sheet(frames: list[Image.Image]) -> Image.Image:
    sheet = Image.new("RGBA", (FRAME_SIZE * LINE_LENGTH, FRAME_SIZE * ROWS), (0, 0, 0, 0))
    for index, frame in enumerate(frames):
        x = (index % LINE_LENGTH) * FRAME_SIZE
        y = (index // LINE_LENGTH) * FRAME_SIZE
        sheet.alpha_composite(frame, (x, y))
    return sheet


def alpha_metrics(frame: Image.Image) -> dict[str, object]:
    alpha = frame.getchannel("A")
    bounds = alpha.getbbox()
    stat = ImageStat.Stat(alpha)
    histogram = alpha.histogram()
    nonzero = sum(histogram[3:])
    alpha_sum = stat.sum[0]
    alpha_max = alpha.getextrema()[1]
    if not bounds:
        return {
            "blank": True,
            "alpha_sum": alpha_sum,
            "alpha_max": alpha_max,
            "nonzero_alpha_pixels": nonzero,
            "bounds": None,
            "margin": None,
        }
    left, top, right, bottom = bounds
    margin = min(left, top, FRAME_SIZE - right, FRAME_SIZE - bottom)
    return {
        "blank": False,
        "alpha_sum": alpha_sum,
        "alpha_max": alpha_max,
        "nonzero_alpha_pixels": nonzero,
        "bounds": [left, top, right, bottom],
        "margin": margin,
    }


def write_manifest(base_frames: list[Image.Image], glow_frames: list[Image.Image], promoted: bool) -> dict[str, object]:
    base_metrics = [alpha_metrics(frame) for frame in base_frames]
    glow_metrics = [alpha_metrics(frame) for frame in glow_frames]
    warnings: list[str] = []

    for label, metrics in (("base", base_metrics), ("glow", glow_metrics)):
        if metrics[0]["blank"]:
            warnings.append(f"{label} first frame is blank")
        if metrics[FRAME_COUNT // 2]["blank"]:
            warnings.append(f"{label} middle frame is blank")
        if float(metrics[-1]["alpha_sum"]) > float(metrics[FRAME_COUNT // 2]["alpha_sum"]) * 0.10:
            warnings.append(f"{label} final frame did not fade below 10 percent of middle frame")
        margins = [metric["margin"] for metric in metrics if metric["margin"] is not None]
        if margins and min(int(margin) for margin in margins) < 12:
            warnings.append(f"{label} alpha margin below 12 px")

    manifest = {
        "asset_name": ASSET_NAME,
        "mode": "singularity-lance-2d-procedural-black-violet-death-implosion",
        "generator": str(Path(__file__).resolve().relative_to(REPO_ROOT)).replace("\\", "/"),
        "frame_size": FRAME_SIZE,
        "frame_count": FRAME_COUNT,
        "line_length": LINE_LENGTH,
        "rows": ROWS,
        "sheet_size": [FRAME_SIZE * LINE_LENGTH, FRAME_SIZE * ROWS],
        "normal_sheet": str((EXPORT_DIR / NORMAL_FILENAME).relative_to(REPO_ROOT)).replace("\\", "/"),
        "glow_sheet": str((EXPORT_DIR / GLOW_FILENAME).relative_to(REPO_ROOT)).replace("\\", "/"),
        "target_graphics_dir": str(GRAPHICS_DIR.relative_to(REPO_ROOT)).replace("\\", "/"),
        "promoted": promoted,
        "prototype": {
            "name": "ei-singularity-lance-death-explosion",
            "frame_count": 48,
            "line_length": 8,
            "animation_speed": 0.58,
            "scale": 0.56,
            "shift": [0, -1.05],
            "light": {"r": 0.46, "g": 0.16, "b": 1.0},
        },
        "alpha_checks": {
            "base": {
                "first": base_metrics[0],
                "middle": base_metrics[FRAME_COUNT // 2],
                "last": base_metrics[-1],
            },
            "glow": {
                "first": glow_metrics[0],
                "middle": glow_metrics[FRAME_COUNT // 2],
                "last": glow_metrics[-1],
            },
        },
        "warnings": warnings,
    }
    manifest_path = EXPORT_DIR / f"{ASSET_NAME}.factorio-asset-manifest.json"
    manifest_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    return manifest


def generate(promote: bool) -> dict[str, object]:
    for directory in (EXPORT_DIR, PREVIEW_DIR, SOURCE_DIR, FRAMES_DIR):
        directory.mkdir(parents=True, exist_ok=True)
    if FRAMES_DIR.exists():
        shutil.rmtree(FRAMES_DIR)
        FRAMES_DIR.mkdir(parents=True, exist_ok=True)

    base_dir = FRAMES_DIR / "base"
    glow_dir = FRAMES_DIR / "glow"
    base_dir.mkdir(parents=True, exist_ok=True)
    glow_dir.mkdir(parents=True, exist_ok=True)

    base_frames: list[Image.Image] = []
    glow_frames: list[Image.Image] = []
    for index in range(FRAME_COUNT):
        base = draw_implosion_frame(index, glow=False)
        glow = draw_implosion_frame(index, glow=True)
        base_frames.append(base)
        glow_frames.append(glow)
        base.save(base_dir / f"base-{index:03d}.png")
        glow.save(glow_dir / f"glow-{index:03d}.png")

    base_sheet = pack_sheet(base_frames)
    glow_sheet = pack_sheet(glow_frames)
    base_path = EXPORT_DIR / NORMAL_FILENAME
    glow_path = EXPORT_DIR / GLOW_FILENAME
    base_sheet.save(base_path)
    glow_sheet.save(glow_path)
    shutil.copy2(base_path, PREVIEW_DIR / NORMAL_FILENAME)
    shutil.copy2(glow_path, PREVIEW_DIR / GLOW_FILENAME)
    shutil.copy2(Path(__file__).resolve(), SOURCE_DIR / Path(__file__).name)

    if promote:
        GRAPHICS_DIR.mkdir(parents=True, exist_ok=True)
        shutil.copy2(base_path, GRAPHICS_DIR / NORMAL_FILENAME)
        shutil.copy2(glow_path, GRAPHICS_DIR / GLOW_FILENAME)

    return write_manifest(base_frames, glow_frames, promote)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Generate 2D procedural Singularity Lance death implosion sheets.")
    parser.add_argument("--promote", action="store_true", help="Copy approved sheets into the live lance death graphics folder.")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    manifest = generate(args.promote)
    print(json.dumps({
        "normal_sheet": manifest["normal_sheet"],
        "glow_sheet": manifest["glow_sheet"],
        "sheet_size": manifest["sheet_size"],
        "warnings": manifest["warnings"],
        "promoted": manifest["promoted"],
    }, indent=2))


if __name__ == "__main__":
    main()
