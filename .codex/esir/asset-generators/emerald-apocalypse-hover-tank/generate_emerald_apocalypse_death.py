from __future__ import annotations

import json
import math
import random
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter


LOGICAL_FRAME_SIZE = 96
FRAME_SIZE = 768
FRAME_COUNT = 64
LINE_LENGTH = 8
SHEET_SIZE = FRAME_SIZE * LINE_LENGTH
ROWS = FRAME_COUNT // LINE_LENGTH
SEED = 90377816
SCALE = FRAME_SIZE / LOGICAL_FRAME_SIZE

NORMAL_FILENAME = "emerald-apocalypse-hover-tank-death-collapse.png"
GLOW_FILENAME = "emerald-apocalypse-hover-tank-death-collapse-glow.png"


def find_repo_root(start: Path) -> Path:
    for path in [start, *start.parents]:
        if (path / ".git").exists() and (path / "exotic-space-industries-remembrance").exists():
            return path
    raise RuntimeError(f"Could not find repository root from {start}")


REPO_ROOT = find_repo_root(Path(__file__).resolve())
DEATH_DIR = (
    REPO_ROOT
    / "exotic-space-industries-remembrance"
    / "graphics"
    / "entities"
    / "emerald-apocalypse-hover-tank"
    / "death"
)


def clamp(value: float, low: float = 0.0, high: float = 255.0) -> int:
    return int(max(low, min(high, value)))


def ease_out(t: float) -> float:
    t = max(0.0, min(1.0, t))
    return 1.0 - (1.0 - t) ** 3


def ease_in(t: float) -> float:
    t = max(0.0, min(1.0, t))
    return t**3


def ease_in_out(t: float) -> float:
    t = max(0.0, min(1.0, t))
    return t * t * (3.0 - 2.0 * t)


def lerp(a: float, b: float, t: float) -> float:
    return a + (b - a) * t


def rgba(color: tuple[int, int, int], alpha: float) -> tuple[int, int, int, int]:
    return (color[0], color[1], color[2], clamp(alpha))


def scale_value(value: float) -> float:
    return value * SCALE


def scale_point(point: tuple[float, float]) -> tuple[float, float]:
    return (point[0] * SCALE, point[1] * SCALE)


def scale_points(points: list[tuple[float, float]]) -> list[tuple[float, float]]:
    return [scale_point(point) for point in points]


def scale_bbox(bbox: tuple[float, float, float, float]) -> tuple[float, float, float, float]:
    return tuple(scale_value(value) for value in bbox)  # type: ignore[return-value]


class ScaledDraw:
    def __init__(self, image: Image.Image) -> None:
        self.draw = ImageDraw.Draw(image, "RGBA")

    def polygon(self, points: list[tuple[float, float]], **kwargs) -> None:
        self.draw.polygon(scale_points(points), **kwargs)

    def line(self, points: list[tuple[float, float]], **kwargs) -> None:
        width = kwargs.get("width")
        if width is not None:
            kwargs["width"] = max(1, round(width * SCALE))
        self.draw.line(scale_points(points), **kwargs)

    def ellipse(self, bbox: tuple[float, float, float, float], **kwargs) -> None:
        width = kwargs.get("width")
        if width is not None:
            kwargs["width"] = max(1, round(width * SCALE))
        self.draw.ellipse(scale_bbox(bbox), **kwargs)


def rotated_point(cx: float, cy: float, x: float, y: float, angle: float) -> tuple[float, float]:
    ca = math.cos(angle)
    sa = math.sin(angle)
    return (cx + x * ca - y * sa, cy + x * sa + y * ca)


def polygon_ellipse(cx: float, cy: float, rx: float, ry: float, angle: float, steps: int = 64) -> list[tuple[float, float]]:
    return [
        rotated_point(cx, cy, math.cos(i / steps * math.tau) * rx, math.sin(i / steps * math.tau) * ry, angle)
        for i in range(steps)
    ]


def draw_soft_line(
    image: Image.Image,
    points: list[tuple[float, float]],
    color: tuple[int, int, int],
    alpha: float,
    width: int,
    blur: float,
) -> None:
    layer = Image.new("RGBA", image.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer, "RGBA")
    draw.line(scale_points(points), fill=rgba(color, alpha), width=max(1, round(width * SCALE)), joint="curve")
    if blur:
        layer = layer.filter(ImageFilter.GaussianBlur(scale_value(blur)))
    image.alpha_composite(layer)


def draw_shard(
    draw: ImageDraw.ImageDraw,
    cx: float,
    cy: float,
    length: float,
    width: float,
    angle: float,
    color: tuple[int, int, int],
    alpha: float,
) -> None:
    tip = rotated_point(cx, cy, length, 0.0, angle)
    base_a = rotated_point(cx, cy, -length * 0.22, width, angle)
    base_b = rotated_point(cx, cy, -length * 0.30, -width, angle)
    mid = rotated_point(cx, cy, length * 0.22, width * 0.18, angle)
    draw.polygon([base_a, mid, tip, base_b], fill=rgba(color, alpha))
    draw.line([base_a, tip, base_b], fill=rgba((158, 255, 178), alpha * 0.55), width=1)


def apply_margin_fade(image: Image.Image, hard_margin: int | None = None, soft_margin: int | None = None) -> Image.Image:
    hard_margin = max(1, round((hard_margin if hard_margin is not None else 2) * SCALE))
    soft_margin = max(1, round((soft_margin if soft_margin is not None else 10) * SCALE))
    mask = Image.new("L", image.size, 255)
    draw = ImageDraw.Draw(mask)
    width, height = image.size
    for distance in range(hard_margin + soft_margin):
        if distance <= hard_margin:
            value = 0
        else:
            t = (distance - hard_margin) / soft_margin
            value = clamp(ease_in_out(t) * 255)
        draw.rectangle((distance, distance, width - 1 - distance, height - 1 - distance), outline=value)
    result = image.copy()
    result.putalpha(ImageChops.multiply(result.getchannel("A"), mask))
    return result


def draw_frame(index: int, debris: list[dict[str, float]]) -> tuple[Image.Image, Image.Image]:
    t = index / (FRAME_COUNT - 1)
    collapse = ease_in_out(min(1.0, t / 0.70))
    flash = math.exp(-((t - 0.32) / 0.105) ** 2)
    after_flash = ease_out(max(0.0, (t - 0.34) / 0.66))
    fade = max(0.0, 1.0 - ease_in(max(0.0, (t - 0.72) / 0.28)) * 0.86)
    rng = random.Random(SEED + index * 31)

    base = Image.new("RGBA", (FRAME_SIZE, FRAME_SIZE), (0, 0, 0, 0))
    glow = Image.new("RGBA", (FRAME_SIZE, FRAME_SIZE), (0, 0, 0, 0))
    base_draw = ScaledDraw(base)
    glow_draw = ScaledDraw(glow)

    cx = LOGICAL_FRAME_SIZE / 2.0
    cy = LOGICAL_FRAME_SIZE / 2.0 + 4.0
    jitter_x = math.sin(index * 0.73) * flash * 1.2
    jitter_y = math.cos(index * 0.57) * flash * 0.9
    cx += jitter_x
    cy += jitter_y

    hull_rx = lerp(31.0, 18.0, collapse) * fade
    hull_ry = lerp(13.5, 8.5, collapse) * fade
    hull_angle = math.radians(-7.0 + math.sin(index * 0.18) * 2.0)

    shield_rx = lerp(43.0, 12.0, collapse)
    shield_ry = lerp(30.0, 7.0, collapse)
    shield_alpha = (120.0 * (1.0 - collapse) + 70.0 * flash) * fade
    for shell in range(3):
        pulse = math.sin(index * 0.40 + shell * 1.7) * 1.5
        pts = polygon_ellipse(cx, cy - 1, shield_rx - shell * 4 + pulse, shield_ry - shell * 3, hull_angle, 80)
        draw_soft_line(base, pts + [pts[0]], (14, 214, 113), shield_alpha * (0.62 - shell * 0.13), 1, 0.4)
        draw_soft_line(glow, pts + [pts[0]], (21, 255, 142), shield_alpha * (0.92 - shell * 0.16), 2, 1.2)

    under_progress = ease_out(max(0.0, (t - 0.12) / 0.58))
    for ring in range(4):
        side = -1 if ring % 2 == 0 else 1
        ring_cx = cx + side * (11 + ring * 2 + under_progress * (13 + ring * 2))
        ring_cy = cy + 8 + ring * 0.8 + under_progress * (ring - 1) * 1.5
        ring_rx = (10 - ring * 0.9) * fade
        ring_ry = (3.4 + ring * 0.2) * fade
        shear_angle = hull_angle + side * (0.34 + under_progress * 0.48)
        arc_pts = []
        for step in range(26):
            a = math.radians(192 + step * 4.8)
            arc_pts.append(rotated_point(ring_cx, ring_cy, math.cos(a) * ring_rx, math.sin(a) * ring_ry, shear_angle))
        alpha = (155 - ring * 18) * (1.0 - under_progress * 0.32) * fade
        draw_soft_line(base, arc_pts, (83, 236, 118), alpha, 2, 0.2)
        draw_soft_line(glow, arc_pts, (38, 255, 112), alpha * 1.4, 2, 1.0)

    if hull_rx > 1:
        hull = polygon_ellipse(cx, cy, hull_rx, hull_ry, hull_angle, 64)
        base_draw.polygon(hull, fill=rgba((10, 28, 22), 215 * fade))
        base_draw.line(hull + [hull[0]], fill=rgba((78, 191, 113), 150 * fade), width=1)

        deck = polygon_ellipse(cx, cy - 2, hull_rx * 0.72, hull_ry * 0.42, hull_angle, 42)
        base_draw.polygon(deck, fill=rgba((17, 65, 43), 168 * fade))
        base_draw.line(deck + [deck[0]], fill=rgba((127, 255, 145), 95 * fade), width=1)

    spine_break = ease_out(max(0.0, (t - 0.18) / 0.42))
    for i in range(7):
        spine_t = i / 6
        sx = cx + (spine_t - 0.5) * 36 * (1.0 - collapse * 0.25)
        sy = cy - 11 - math.sin(spine_t * math.pi) * 8 * (1.0 - collapse * 0.4)
        rupture = max(0.0, spine_break - spine_t * 0.09)
        length = (8 + i % 3 * 1.6) * (1.0 + rupture * 0.8) * fade
        width = (3.2 + i % 2) * fade
        angle = -math.pi / 2 + (spine_t - 0.5) * 1.1 + rupture * (spine_t - 0.5) * 2.1
        color = (52, 182, 103) if i % 2 else (130, 255, 150)
        alpha = (195 + flash * 45) * max(0.0, 1.0 - after_flash * 0.55) * fade
        draw_shard(base_draw, sx, sy, length, width, angle, color, alpha)
        draw_shard(glow_draw, sx, sy, length * 1.08, width * 0.85, angle, (58, 255, 127), alpha * 0.72)

    core_r = lerp(4.0, 20.0, flash) * max(0.25, 1.0 - after_flash * 0.45)
    core_alpha = (120 + flash * 135) * fade
    base_draw.ellipse(
        (cx - core_r, cy - core_r * 0.72, cx + core_r, cy + core_r * 0.72),
        fill=rgba((3, 9, 6), core_alpha * 0.86),
        outline=rgba((84, 255, 109), core_alpha),
        width=1,
    )
    glow_draw.ellipse(
        (cx - core_r * 1.55, cy - core_r * 1.08, cx + core_r * 1.55, cy + core_r * 1.08),
        fill=rgba((24, 255, 99), (70 + flash * 130) * fade),
    )

    burst = ease_out(max(0.0, (t - 0.25) / 0.46))
    for k in range(22):
        angle = k / 22 * math.tau + rng.uniform(-0.08, 0.08)
        radius = (8 + burst * rng.uniform(18, 42)) * fade
        length = rng.uniform(4, 12) * (1.0 - after_flash * 0.45)
        start = rotated_point(cx, cy, radius * 0.28, rng.uniform(-2, 2), angle)
        end = rotated_point(cx, cy, radius + length, rng.uniform(-1.5, 1.5), angle)
        alpha = (145 + flash * 80) * (1.0 - burst * 0.35) * fade
        color = (38, 255, 116) if k % 3 else (2, 104, 62)
        base_draw.line([start, end], fill=rgba(color, alpha), width=1)
        glow_draw.line([start, end], fill=rgba((18, 255, 107), alpha * 1.12), width=2)

    for shard in debris:
        start_t = shard["start"]
        if t < start_t:
            continue
        life_t = min(1.0, (t - start_t) / shard["life"])
        alpha = 185 * (1.0 - ease_in(life_t)) * fade
        if alpha <= 2:
            continue
        distance = shard["speed"] * ease_out(life_t)
        sx = cx + shard["origin_x"] + math.cos(shard["angle"]) * distance
        sy = cy + shard["origin_y"] + math.sin(shard["angle"]) * distance + life_t * life_t * 8
        spin = shard["spin"] * life_t
        draw_shard(
            base_draw,
            sx,
            sy,
            shard["length"] * (1.0 - life_t * 0.35),
            shard["width"],
            shard["angle"] + spin,
            (54, 190, 101) if shard["hot"] < 0.5 else (132, 255, 145),
            alpha,
        )
        draw_shard(
            glow_draw,
            sx,
            sy,
            shard["length"] * 0.8,
            shard["width"] * 0.65,
            shard["angle"] + spin,
            (37, 255, 124),
            alpha * 0.48,
        )

    smoke_alpha = 62 * after_flash * fade
    for puff in range(8):
        px = cx + math.cos(puff * 1.8) * (8 + after_flash * (9 + puff))
        py = cy + math.sin(puff * 1.3) * 4 - after_flash * (5 + puff * 0.7)
        pr = 4 + after_flash * (4 + puff % 3)
        base_draw.ellipse(
            (px - pr, py - pr * 0.7, px + pr, py + pr * 0.7),
            fill=rgba((4, 22, 14), smoke_alpha * (0.9 - puff * 0.055)),
        )

    glow = glow.filter(ImageFilter.GaussianBlur(scale_value(0.55)))
    return apply_margin_fade(base), apply_margin_fade(glow)


def build_debris() -> list[dict[str, float]]:
    rng = random.Random(SEED)
    debris = []
    for _ in range(38):
        angle = rng.uniform(-math.pi * 0.95, math.pi * 1.95)
        debris.append(
            {
                "angle": angle,
                "origin_x": rng.uniform(-18.0, 18.0),
                "origin_y": rng.uniform(-12.0, 10.0),
                "speed": rng.uniform(16.0, 44.0),
                "length": rng.uniform(2.8, 7.5),
                "width": rng.uniform(1.2, 3.2),
                "spin": rng.uniform(-5.0, 5.0),
                "start": rng.uniform(0.20, 0.47),
                "life": rng.uniform(0.36, 0.62),
                "hot": rng.random(),
            }
        )
    return debris


def paste_frame(sheet: Image.Image, frame: Image.Image, index: int) -> None:
    x = (index % LINE_LENGTH) * FRAME_SIZE
    y = (index // LINE_LENGTH) * FRAME_SIZE
    sheet.alpha_composite(frame, (x, y))


def alpha_bounds(image: Image.Image) -> tuple[int, int, int, int] | None:
    alpha = image.getchannel("A")
    bbox = alpha.getbbox()
    if bbox is None:
        return None
    return bbox


def main() -> None:
    DEATH_DIR.mkdir(parents=True, exist_ok=True)
    normal_sheet = Image.new("RGBA", (SHEET_SIZE, SHEET_SIZE), (0, 0, 0, 0))
    glow_sheet = Image.new("RGBA", (SHEET_SIZE, SHEET_SIZE), (0, 0, 0, 0))
    debris = build_debris()

    per_frame_bounds = []
    for index in range(FRAME_COUNT):
        normal, glow = draw_frame(index, debris)
        paste_frame(normal_sheet, normal, index)
        paste_frame(glow_sheet, glow, index)
        per_frame_bounds.append(
            {
                "frame": index,
                "normal_alpha_bounds": alpha_bounds(normal),
                "glow_alpha_bounds": alpha_bounds(glow),
            }
        )

    normal_path = DEATH_DIR / NORMAL_FILENAME
    glow_path = DEATH_DIR / GLOW_FILENAME
    normal_sheet.save(normal_path, optimize=True)
    glow_sheet.save(glow_path, optimize=True)

    manifest = {
        "asset": "emerald-apocalypse-hover-tank death collapse",
        "frame_size": FRAME_SIZE,
        "frame_count": FRAME_COUNT,
        "line_length": LINE_LENGTH,
        "sheet_size": [SHEET_SIZE, SHEET_SIZE],
        "normal": str(normal_path.relative_to(REPO_ROOT)),
        "glow": str(glow_path.relative_to(REPO_ROOT)),
        "seed": SEED,
        "style_notes": [
            "emerald shield membrane implodes",
            "underhull rings shear outward",
            "crystal spine rupture",
            "black-green core flash",
            "transparent background",
        ],
        "per_frame_bounds": per_frame_bounds,
    }
    (Path(__file__).with_suffix(".manifest.json")).write_text(json.dumps(manifest, indent=2), encoding="utf-8")


if __name__ == "__main__":
    main()
