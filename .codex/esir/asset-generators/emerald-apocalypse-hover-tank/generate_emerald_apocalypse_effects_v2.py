from __future__ import annotations

import argparse
import json
import math
import random
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageStat


ASSET = "emerald-apocalypse-hover-tank"
SEED = 509011313

SPECS = {
    "chargeup": {"size": (512, 512), "frames": 60, "line": 10},
    "muzzle-flash": {"size": (384, 384), "frames": 24, "line": 6},
    "beam-body": {"size": (384, 128), "frames": 24, "line": 6},
    "beam-head": {"size": (384, 128), "frames": 24, "line": 6},
    "beam-tail": {"size": (384, 128), "frames": 24, "line": 6},
    "impact": {"size": (768, 768), "frames": 64, "line": 8},
    "hit-flash": {"size": (384, 384), "frames": 24, "line": 6},
    "scorchmark": {"size": (768, 768), "frames": 1, "line": 1},
    "shield-pulse": {"size": (512, 512), "frames": 48, "line": 8},
    "shield-pulse-v3": {"size": (768, 768), "frames": 48, "line": 8},
}

EMERALD = (0, 255, 126)
MINT = (185, 255, 218)
ACID = (114, 255, 52)
BLACK = (0, 9, 6)
NULL = (0, 0, 0)


def clamp(value: float, lo: int = 0, hi: int = 255) -> int:
    return int(max(lo, min(hi, value)))


def rgba(color, alpha):
    return (color[0], color[1], color[2], clamp(alpha))


def unit(t: float) -> float:
    return max(0.0, min(1.0, t))


def ease_out(t: float) -> float:
    t = unit(t)
    return 1 - (1 - t) * (1 - t)


def ease_in(t: float) -> float:
    t = unit(t)
    return t * t


def new_sheet(spec):
    w, h = spec["size"]
    rows = math.ceil(spec["frames"] / spec["line"])
    return Image.new("RGBA", (w * spec["line"], h * rows), (0, 0, 0, 0))


def paste_frame(sheet: Image.Image, frame: Image.Image, spec, index: int):
    w, h = spec["size"]
    col = index % spec["line"]
    row = index // spec["line"]
    sheet.alpha_composite(frame, (col * w, row * h))


def alpha_bbox(img: Image.Image):
    return img.getchannel("A").getbbox()


def glow_from(base: Image.Image, radius: float, alpha_scale: float = 1.0) -> Image.Image:
    glow = Image.new("RGBA", base.size, (0, 0, 0, 0))
    bloom = base.filter(ImageFilter.GaussianBlur(radius))
    r, g, b, a = bloom.split()
    a = a.point(lambda p: clamp(p * alpha_scale))
    glow.alpha_composite(Image.merge("RGBA", (r, g, b, a)))
    return glow


def combine_base_and_glow(base: Image.Image, glow_radius=12, glow_alpha=1.0):
    glow = glow_from(base, glow_radius, glow_alpha)
    soft = glow.copy()
    soft.alpha_composite(base)
    return base, soft


def polygon_star(draw, center, radius, inner, points, phase, color):
    cx, cy = center
    pts = []
    for idx in range(points * 2):
        angle = phase + idx * math.pi / points
        r = radius if idx % 2 == 0 else inner
        pts.append((cx + math.cos(angle) * r, cy + math.sin(angle) * r))
    draw.polygon(pts, fill=color)


def draw_ring(draw, cx, cy, rx, ry, color, width=3, start=0, end=360):
    box = (cx - rx, cy - ry, cx + rx, cy + ry)
    if start == 0 and end == 360:
        draw.ellipse(box, outline=color, width=width)
    else:
        draw.arc(box, start=start, end=end, fill=color, width=width)


def draw_rotated_rect(draw, cx, cy, length, width, angle, color):
    ca = math.cos(angle)
    sa = math.sin(angle)
    hx = length / 2
    hy = width / 2
    pts = []
    for x, y in ((-hx, -hy), (hx, -hy), (hx, hy), (-hx, hy)):
        pts.append((cx + ca * x - sa * y, cy + sa * x + ca * y))
    draw.polygon(pts, fill=color)


def frame_chargeup(index, spec):
    w, h = spec["size"]
    t = index / max(1, spec["frames"] - 1)
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img, "RGBA")
    rng = random.Random(SEED + index * 13)
    cx, cy = w * 0.50, h * 0.50
    contraction = 1 - ease_out(t) * 0.72

    for ring in range(9):
        phase = (t * 420 + ring * 31) % 360
        rx = (205 - ring * 16) * contraction + 14 + math.sin(t * math.tau * 2 + ring) * 4
        ry = rx * (0.68 + ring * 0.012)
        alpha = 46 + 160 * t - ring * 7
        color = rgba(EMERALD if ring % 3 else ACID, alpha)
        draw_ring(draw, cx, cy, rx, ry, color, width=3 + (ring % 2), start=phase, end=phase + 230)
        draw_ring(draw, cx, cy, rx * 0.92, ry * 0.92, rgba(BLACK, 70 + 50 * t), width=2, start=phase + 238, end=phase + 304)

    for spoke in range(28):
        angle = spoke * math.tau / 28 + t * 1.9
        outer = 220 - 128 * ease_out(t) + rng.random() * 14
        inner = 42 - 18 * t
        x1 = cx + math.cos(angle) * outer
        y1 = cy + math.sin(angle) * outer * 0.74
        x2 = cx + math.cos(angle + 0.08) * inner
        y2 = cy + math.sin(angle + 0.08) * inner * 0.74
        draw.line((x1, y1, x2, y2), fill=rgba(EMERALD, 90 + 115 * t), width=2)

    for blade in range(8):
        angle = blade * math.tau / 8 - t * 2.8
        draw_rotated_rect(draw, cx, cy, 120 - 46 * t, 12, angle, rgba(BLACK, 150))

    polygon_star(draw, (cx, cy), 52 - 16 * t, 19 - 8 * t, 8, t * -math.tau * 1.5, rgba(BLACK, 215))
    draw.ellipse((cx - 12, cy - 12, cx + 12, cy + 12), fill=rgba(MINT, 120 + 100 * t))
    return combine_base_and_glow(img, 18, 1.45)


def frame_muzzle(index, spec):
    w, h = spec["size"]
    t = index / max(1, spec["frames"] - 1)
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img, "RGBA")
    cx, cy = w * 0.35, h * 0.50
    fade = max(0.05, 1 - ease_in(t))
    throat = 48 + 55 * (1 - t)
    reach = 190 - 70 * t

    draw.polygon(
        [(cx - 30, cy - 34), (cx + reach, cy - 74), (cx + reach * 1.07, cy),
         (cx + reach, cy + 74), (cx - 30, cy + 34)],
        fill=rgba(EMERALD, 195 * fade),
    )
    draw.polygon(
        [(cx - 14, cy - 13), (cx + reach * 0.72, cy - 30), (cx + reach * 0.94, cy),
         (cx + reach * 0.72, cy + 30), (cx - 14, cy + 13)],
        fill=rgba(MINT, 220 * fade),
    )
    for blade in range(10):
        angle = (blade - 5) * 0.19
        y = cy + math.sin(angle) * 92
        x = cx + 45 + abs(blade - 5) * 6
        draw.polygon(
            [(x, y), (x + 76 * fade, y - 16), (x + 36 * fade, cy), (x + 76 * fade, y + 16)],
            fill=rgba(BLACK, 160 * fade),
        )
    for tooth in range(14):
        angle = tooth * math.tau / 14 + t * 1.2
        draw_rotated_rect(draw, cx + 12, cy, throat, 7, angle, rgba(BLACK, 170 * fade))
    return combine_base_and_glow(img, 12, 1.35)


def beam_frame(index, spec, role):
    w, h = spec["size"]
    phase = index / max(1, spec["frames"])
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img, "RGBA")
    cy = h / 2
    rng = random.Random(SEED + 5000 + index + len(role) * 101)

    if role == "tail":
        start_alpha = 0
        left_width = 18
    else:
        start_alpha = 190
        left_width = 0

    if role == "head":
        points = [(0, cy - 30), (w - 42, cy - 42), (w - 2, cy), (w - 42, cy + 42), (0, cy + 30)]
        draw.polygon(points, fill=rgba(EMERALD, 210))
        draw.polygon([(w - 92, cy - 22), (w - 10, cy), (w - 92, cy + 22)], fill=rgba(MINT, 230))
        draw.polygon([(w - 124, cy - 48), (w - 56, cy - 34), (w - 88, cy)], fill=rgba(BLACK, 185))
        draw.polygon([(w - 124, cy + 48), (w - 56, cy + 34), (w - 88, cy)], fill=rgba(BLACK, 185))
    elif role == "tail":
        draw.polygon([(22, cy), (92, cy - 46), (w, cy - 27), (w, cy + 27), (92, cy + 46)], fill=rgba(EMERALD, 198))
        draw.polygon([(54, cy), (112, cy - 17), (w, cy - 10), (w, cy + 10), (112, cy + 17)], fill=rgba(MINT, 208))
        polygon_star(draw, (70, cy), 46, 16, 8, phase * math.tau, rgba(BLACK, 170))
    else:
        draw.rectangle((left_width, cy - 27, w, cy + 27), fill=rgba(EMERALD, 195))
        draw.rectangle((left_width, cy - 9, w, cy + 9), fill=rgba(MINT, 218))

    for x in range(-60, w + 80, 42):
        y_shift = math.sin((x * 0.04) + phase * math.tau * 2.0) * 13
        draw.polygon(
            [(x, cy - 42 + y_shift), (x + 52, cy - 31 - y_shift), (x + 24, cy), (x + 52, cy + 31 - y_shift), (x, cy + 42 + y_shift)],
            fill=rgba(BLACK, 104 + rng.random() * 50),
        )
    for lane in (-45, -34, 34, 45):
        draw.line((0, cy + lane, w, cy + lane + math.sin(phase * math.tau) * 5), fill=rgba(EMERALD, 88), width=2)
    for block in range(16):
        x = rng.randrange(0, w)
        y = int(cy + rng.choice((-1, 1)) * rng.randrange(17, 42))
        draw.rectangle((x, y, x + rng.randrange(8, 26), y + rng.randrange(3, 8)), fill=rgba(ACID, 70 + rng.randrange(65)))
    if start_alpha:
        draw.rectangle((0, cy - 22, 16, cy + 22), fill=(0, 255, 126, start_alpha))
    return combine_base_and_glow(img, 7, 1.3)


def frame_impact(index, spec):
    w, h = spec["size"]
    t = index / max(1, spec["frames"] - 1)
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img, "RGBA")
    cx, cy = w / 2, h / 2
    rng = random.Random(SEED + 9000 + index)

    collapse = 1 - abs(t - 0.32) / 0.32 if t < 0.64 else 0
    rupture = ease_out(max(0, t - 0.25) / 0.75)
    inversion = max(0, 1 - abs(t - 0.34) / 0.075)
    aftershock = max(0, 1 - abs(t - 0.58) / 0.24)

    for ring in range(14):
        rr = 342 - ring * 18 - 188 * ease_out(min(t / 0.40, 1))
        rr = max(28, rr)
        alpha = (132 + ring * 7) * max(0, 1 - t * 0.78)
        start = (ring * 31 - t * 760) % 360
        color = MINT if inversion > 0.45 and ring % 3 == 0 else (EMERALD if ring % 2 else ACID)
        draw_ring(draw, cx, cy, rr, rr * 0.70, rgba(color, alpha), width=6 + (ring % 2), start=start, end=start + 224)
        draw_ring(draw, cx, cy, rr * 0.90, rr * 0.63, rgba(BLACK, 118 * (1 - t)), width=4, start=start + 230, end=start + 326)

    for shutter in range(18):
        angle = shutter * math.tau / 18 - t * 3.2
        inner = 66 + 74 * collapse
        outer = 340 - 44 * rupture
        p1 = (cx + math.cos(angle - 0.055) * inner, cy + math.sin(angle - 0.055) * inner * 0.68)
        p2 = (cx + math.cos(angle) * outer, cy + math.sin(angle) * outer * 0.68)
        p3 = (cx + math.cos(angle + 0.055) * inner, cy + math.sin(angle + 0.055) * inner * 0.68)
        draw.polygon((p1, p2, p3), fill=rgba(BLACK, 138 * max(0, 1 - t * 0.52)))

    for shard in range(72):
        angle = shard * math.tau / 72 + rng.random() * 0.06 - t * 2.05
        outer = 102 + 218 * rupture + rng.random() * 16
        inner = 18 + 58 * collapse
        x1 = cx + math.cos(angle) * outer
        y1 = cy + math.sin(angle) * outer * 0.68
        x2 = cx + math.cos(angle + 0.035) * inner
        y2 = cy + math.sin(angle + 0.035) * inner * 0.68
        draw.line((x1, y1, x2, y2), fill=rgba(EMERALD if shard % 4 else MINT, 132 * max(0, 1 - t * 0.62)), width=3 + (shard % 3 == 0))

    for chevron in range(22):
        angle = chevron * math.tau / 22 + t * 1.1
        radius = 130 + 170 * rupture + (chevron % 4) * 7
        draw_rotated_rect(
            draw,
            cx + math.cos(angle) * radius,
            cy + math.sin(angle) * radius * 0.67,
            58 + 32 * aftershock,
            11,
            angle + math.pi / 2,
            rgba(BLACK, 104 * max(aftershock, 1 - t)),
        )

    polygon_star(draw, (cx, cy), 118 + 214 * rupture, 42 + 78 * rupture, 18, -t * 5.7, rgba(BLACK, 224 * max(0, 1 - t * 0.58)))
    draw.ellipse((cx - 74 - 64 * inversion, cy - 46 - 44 * inversion, cx + 74 + 64 * inversion, cy + 46 + 44 * inversion), fill=rgba(MINT, 244 * inversion))
    draw.ellipse((cx - 38 - 118 * rupture, cy - 24 - 76 * rupture, cx + 38 + 118 * rupture, cy + 24 + 76 * rupture), fill=rgba(BLACK, 195 * max(0, 1 - t * 0.32)))
    return combine_base_and_glow(img, 16, 1.55)


def frame_hit_flash(index, spec):
    w, h = spec["size"]
    t = index / max(1, spec["frames"] - 1)
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img, "RGBA")
    cx, cy = w / 2, h / 2
    fade = max(0.05, 1 - ease_in(t))
    polygon_star(draw, (cx, cy), 42 + 118 * t, 15 + 20 * t, 11, t * 2.7, rgba(EMERALD, 205 * fade))
    polygon_star(draw, (cx, cy), 26 + 54 * t, 11 + 9 * t, 7, -t * 4.1, rgba(BLACK, 175 * fade))
    draw.ellipse((cx - 18, cy - 12, cx + 18, cy + 12), fill=rgba(MINT, 210 * fade))
    return combine_base_and_glow(img, 12, 1.35)


def frame_scorchmark(index, spec):
    w, h = spec["size"]
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img, "RGBA")
    cx, cy = w / 2, h / 2
    draw.ellipse((cx - 350, cy - 216, cx + 350, cy + 216), fill=(1, 3, 3, 164))
    draw.ellipse((cx - 282, cy - 168, cx + 282, cy + 168), fill=(0, 11, 7, 142))
    draw.ellipse((cx - 162, cy - 92, cx + 162, cy + 92), fill=(0, 0, 0, 188))
    for i in range(72):
        angle = i * math.tau / 72
        length = 150 + (i % 9) * 22
        draw.line(
            (cx, cy, cx + math.cos(angle) * length, cy + math.sin(angle) * length * 0.58),
            fill=rgba(EMERALD if i % 3 else ACID, 64),
            width=3 if i % 4 else 5,
        )
    for ring in range(5):
        start = 22 + ring * 41
        draw_ring(draw, cx, cy, 316 - ring * 38, (196 - ring * 24), rgba(BLACK, 104 - ring * 10), width=7, start=start, end=start + 156)
        draw_ring(draw, cx, cy, 300 - ring * 36, (184 - ring * 23), rgba(EMERALD, 38 - ring * 4), width=3, start=start + 162, end=start + 286)
    for i in range(26):
        angle = i * math.tau / 26 + 0.1
        draw_rotated_rect(draw, cx + math.cos(angle) * 162, cy + math.sin(angle) * 86, 86 + (i % 5) * 9, 11, angle, (0, 0, 0, 126))
    return combine_base_and_glow(img, 12, 0.92)


def frame_shield(index, spec):
    w, h = spec["size"]
    t = index / max(1, spec["frames"] - 1)
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img, "RGBA")
    cx, cy = w / 2, h / 2
    fade = max(0.05, 1 - ease_in(t))
    pulse = ease_out(t)
    for ring in range(5):
        rx = 104 + ring * 16 + pulse * 42
        ry = 64 + ring * 12 + pulse * 28
        draw_ring(draw, cx, cy, rx, ry, rgba(EMERALD, (145 - ring * 17) * fade), width=4)
    for i in range(18):
        angle = i * math.tau / 18 + t * 0.7
        p1 = (cx + math.cos(angle) * (72 + pulse * 18), cy + math.sin(angle) * (41 + pulse * 12))
        p2 = (cx + math.cos(angle + 0.18) * (174 + pulse * 24), cy + math.sin(angle + 0.18) * (102 + pulse * 14))
        draw.line((p1, p2), fill=rgba(BLACK, 155 * fade), width=5)
        draw.line((p1, p2), fill=rgba(ACID if i % 3 == 0 else EMERALD, 95 * fade), width=2)
    return combine_base_and_glow(img, 14, 1.25)


def frame_shield_v3(index, spec):
    w, h = spec["size"]
    t = index / max(1, spec["frames"] - 1)
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img, "RGBA")
    cx, cy = w / 2, h / 2
    fade = max(0.04, 1 - ease_in(t))
    pulse = ease_out(t)
    phase = t * 90

    for ring in range(5):
        rx = 210 + ring * 22 + pulse * 32
        ry = 132 + ring * 16 + pulse * 28
        alpha = (150 - ring * 15) * fade
        for segment in range(3):
            start = phase + ring * 23 + segment * 122
            end = start + 82 + math.sin(t * math.tau + ring + segment) * 10
            draw_ring(draw, cx, cy, rx, ry, rgba(EMERALD if ring % 2 else ACID, alpha), width=5, start=start, end=end)
            draw_ring(draw, cx, cy, rx * 0.94, ry * 0.94, rgba(BLACK, (118 - ring * 9) * fade), width=3, start=end + 8, end=end + 34)

    for i in range(36):
        angle = i * math.tau / 36 - t * 0.95
        outer = 324 - pulse * 22 + math.sin(i * 1.7 + t * math.tau) * 6
        inner = 96 + pulse * 20
        p1 = (cx + math.cos(angle) * outer, cy + math.sin(angle) * outer * 0.69)
        p2 = (cx + math.cos(angle + 0.12) * inner, cy + math.sin(angle + 0.12) * inner * 0.69)
        draw.line((p1, p2), fill=rgba(BLACK, 128 * fade), width=7)
        draw.line((p1, p2), fill=rgba(ACID if i % 4 == 0 else EMERALD, 80 * fade), width=3)

    for blade in range(12):
        angle = blade * math.tau / 12 + t * 1.4
        draw_rotated_rect(
            draw,
            cx + math.cos(angle) * (166 + pulse * 16),
            cy + math.sin(angle) * (102 + pulse * 10),
            72,
            12,
            angle + math.pi / 2,
            rgba(BLACK, 92 * fade),
        )

    return combine_base_and_glow(img, 18, 1.18)


BUILDERS = {
    "chargeup": frame_chargeup,
    "muzzle-flash": frame_muzzle,
    "beam-body": lambda index, spec: beam_frame(index, spec, "body"),
    "beam-head": lambda index, spec: beam_frame(index, spec, "head"),
    "beam-tail": lambda index, spec: beam_frame(index, spec, "tail"),
    "impact": frame_impact,
    "hit-flash": frame_hit_flash,
    "scorchmark": frame_scorchmark,
    "shield-pulse": frame_shield,
    "shield-pulse-v3": frame_shield_v3,
}


def sheet_stats(sheet: Image.Image, spec):
    w, h = spec["size"]
    boxes = []
    edge_touches = 0
    for index in range(spec["frames"]):
        col = index % spec["line"]
        row = index // spec["line"]
        frame = sheet.crop((col * w, row * h, col * w + w, row * h + h))
        bbox = alpha_bbox(frame)
        boxes.append(bbox)
        if bbox and (bbox[0] <= 1 or bbox[1] <= 1 or bbox[2] >= w - 1 or bbox[3] >= h - 1):
            edge_touches += 1
    alpha = sheet.getchannel("A")
    stat = ImageStat.Stat(alpha)
    return {
        "frame_size": [w, h],
        "frames": spec["frames"],
        "line_length": spec["line"],
        "nonempty_frames": sum(1 for box in boxes if box),
        "edge_touches": edge_touches,
        "alpha_mean": stat.mean[0],
        "alpha_max": stat.extrema[0][1],
    }


def write_effect(name: str, out_dir: Path):
    spec = SPECS[name]
    base_sheet = new_sheet(spec)
    glow_sheet = new_sheet(spec)
    builder = BUILDERS[name]
    for index in range(spec["frames"]):
        base, glow = builder(index, spec)
        paste_frame(base_sheet, base, spec, index)
        paste_frame(glow_sheet, glow, spec, index)

    base_path = out_dir / f"{ASSET}-{name}.png"
    glow_path = out_dir / f"{ASSET}-{name}-glow.png"
    base_sheet.save(base_path)
    glow_sheet.save(glow_path)
    return {
        "effect": name,
        "base": str(base_path),
        "glow": str(glow_path),
        **sheet_stats(base_sheet, spec),
    }


def write_preview(out_dir: Path, manifest, version: str):
    samples = []
    for entry in manifest["outputs"]:
        name = entry["effect"]
        sheet = Image.open(entry["base"]).convert("RGBA")
        w, h = entry["frame_size"]
        frames = entry["frames"]
        picks = sorted(set([0, frames // 3, (frames * 2) // 3, frames - 1]))
        for pick in picks:
            col = pick % entry["line_length"]
            row = pick // entry["line_length"]
            frame = sheet.crop((col * w, row * h, col * w + w, row * h + h))
            frame.thumbnail((192, 192), Image.Resampling.LANCZOS)
            tile = Image.new("RGBA", (210, 224), (0, 0, 0, 255))
            d = ImageDraw.Draw(tile)
            tile.alpha_composite(frame, ((210 - frame.width) // 2, 22 + (190 - frame.height) // 2))
            d.text((8, 6), f"{name}:{pick:02d}", fill=(190, 255, 218, 255))
            samples.append(tile)

    cols = 4
    rows = math.ceil(len(samples) / cols)
    preview = Image.new("RGBA", (cols * 210, rows * 224), (0, 0, 0, 255))
    for index, tile in enumerate(samples):
        preview.alpha_composite(tile, ((index % cols) * 210, (index // cols) * 224))
    preview_path = out_dir / f"{ASSET}-effects-{version}-preview-strip.png"
    preview.save(preview_path)
    manifest["preview"] = str(preview_path)


def main():
    parser = argparse.ArgumentParser(description="Generate high-fidelity Emerald Apocalypse cannon effect v2 sheets.")
    parser.add_argument("--out-dir", default="output/meshy/emerald-apocalypse-hover-tank/effects-v2")
    parser.add_argument("--version", default="v2")
    parser.add_argument("--effects", nargs="+", choices=sorted(SPECS))
    args = parser.parse_args()

    out_dir = Path(args.out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    effect_names = args.effects or list(SPECS)
    outputs = [write_effect(name, out_dir) for name in effect_names]
    manifest = {
        "asset": ASSET,
        "version": args.version,
        "seed": SEED,
        "source": "deterministic procedural render; original Emerald Apocalypse effect language; no Singularity Lance or Gaian wake source art reused",
        "outputs": outputs,
    }
    write_preview(out_dir, manifest, args.version)
    manifest_path = out_dir / f"{ASSET}-effects-{args.version}.manifest.json"
    manifest_path.write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    print(manifest_path)


if __name__ == "__main__":
    main()
