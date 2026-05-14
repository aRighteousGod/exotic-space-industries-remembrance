from __future__ import annotations

import argparse
import json
import math
import random
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter


ASSET = "emerald-apocalypse-hover-tank"
SEED = 509011313
EFFECTS = {
    "chargeup": {"size": (256, 256), "frames": 32, "line": 8},
    "muzzle": {"size": (256, 256), "frames": 16, "line": 4},
    "beam": {"size": (384, 96), "frames": 16, "line": 4},
    "impact": {"size": (256, 256), "frames": 24, "line": 6},
    "shield": {"size": (384, 384), "frames": 32, "line": 8},
    "scorchmark": {"size": (256, 256), "frames": 1, "line": 1},
    "hover-emitter": {"size": (256, 256), "frames": 32, "line": 8},
}


def clamp(value: float, low: int = 0, high: int = 255) -> int:
    return int(max(low, min(high, value)))


def new_sheet(spec):
    width, height = spec["size"]
    rows = math.ceil(spec["frames"] / spec["line"])
    return Image.new("RGBA", (width * spec["line"], height * rows), (0, 0, 0, 0))


def paste_frame(sheet, frame, spec, index):
    width, height = spec["size"]
    col = index % spec["line"]
    row = index // spec["line"]
    sheet.alpha_composite(frame, (col * width, row * height))


def draw_radial_spikes(draw, center, radius, count, phase, color):
    cx, cy = center
    points = []
    for i in range(count * 2):
        angle = phase + i * math.pi / count
        r = radius * (1.0 if i % 2 == 0 else 0.45)
        points.append((cx + math.cos(angle) * r, cy + math.sin(angle) * r))
    draw.polygon(points, fill=color)


def blur_glow(frame, radius=8, alpha=190):
    glow = frame.filter(ImageFilter.GaussianBlur(radius))
    r, g, b, a = glow.split()
    a = a.point(lambda p: clamp(p * alpha / 255))
    glow = Image.merge("RGBA", (r, g, b, a))
    glow.alpha_composite(frame)
    return glow


def frame_chargeup(index, spec, glow=False):
    rng = random.Random(SEED + index)
    w, h = spec["size"]
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img, "RGBA")
    t = index / max(1, spec["frames"] - 1)
    cx, cy = w / 2, h / 2
    for ring in range(5):
        radius = 18 + ring * 18 + math.sin(t * math.tau + ring) * 5
        alpha = clamp(55 + 165 * t - ring * 12)
        color = (18, clamp(160 + ring * 17), 92, alpha)
        draw.ellipse((cx - radius, cy - radius, cx + radius, cy + radius), outline=color, width=3)
    for spoke in range(12):
        a = spoke * math.tau / 12 + t * 1.7
        length = 36 + 74 * t + rng.random() * 8
        draw.line((cx, cy, cx + math.cos(a) * length, cy + math.sin(a) * length), fill=(2, 255, 121, 130), width=2)
    draw_radial_spikes(draw, (cx, cy), 24 + 10 * t, 8, t * math.tau, (0, 20, 13, 190))
    return blur_glow(img, 10, 220) if glow else img


def frame_muzzle(index, spec, glow=False):
    w, h = spec["size"]
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img, "RGBA")
    t = index / max(1, spec["frames"] - 1)
    cx, cy = w * 0.38, h / 2
    length = 70 * (1.0 - t * 0.55)
    draw.polygon([(cx, cy - 18), (cx + length, cy - 38), (cx + length * 1.2, cy), (cx + length, cy + 38), (cx, cy + 18)], fill=(0, 245, 115, clamp(220 * (1 - t))))
    draw.polygon([(cx - 10, cy - 9), (cx + length * 0.68, cy - 15), (cx + length * 0.9, cy), (cx + length * 0.68, cy + 15), (cx - 10, cy + 9)], fill=(245, 255, 222, clamp(185 * (1 - t))))
    for offset in (-28, 28):
        draw.line((cx - 14, cy + offset, cx + length * 0.9, cy + offset * 0.4), fill=(0, 16, 10, clamp(190 * (1 - t))), width=5)
    return blur_glow(img, 7, 230) if glow else img


def frame_beam(index, spec, glow=False):
    w, h = spec["size"]
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img, "RGBA")
    phase = index / spec["frames"]
    cy = h / 2
    for x in range(-20, w + 20, 18):
        jitter = math.sin((x * 0.05) + phase * math.tau) * 8
        draw.line((x, cy - 20 + jitter, x + 34, cy + 19 - jitter), fill=(0, 22, 14, 210), width=8)
    draw.rectangle((0, cy - 16, w, cy + 16), fill=(0, 215, 101, 195))
    draw.rectangle((0, cy - 5, w, cy + 5), fill=(238, 255, 219, 210))
    for y in (cy - 28, cy + 28):
        draw.line((0, y, w, y + math.sin(phase * math.tau) * 3), fill=(0, 95, 54, 170), width=3)
    return blur_glow(img, 5, 220) if glow else img


def frame_impact(index, spec, glow=False):
    w, h = spec["size"]
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img, "RGBA")
    t = index / max(1, spec["frames"] - 1)
    cx, cy = w / 2, h / 2
    draw_radial_spikes(draw, (cx, cy), 24 + 86 * t, 14, t * 2.2, (0, 230, 105, clamp(220 * (1 - t * 0.75))))
    draw.ellipse((cx - 28 - 30 * t, cy - 15 - 18 * t, cx + 28 + 30 * t, cy + 15 + 18 * t), fill=(0, 16, 11, clamp(210 * (1 - t * 0.5))))
    draw.ellipse((cx - 14, cy - 8, cx + 14, cy + 8), fill=(230, 255, 214, clamp(170 * (1 - t))))
    return blur_glow(img, 9, 225) if glow else img


def frame_shield(index, spec, glow=False):
    w, h = spec["size"]
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img, "RGBA")
    t = index / max(1, spec["frames"] - 1)
    cx, cy = w / 2, h / 2
    for ring in range(3):
        rx = 118 + ring * 22 + math.sin(t * math.tau + ring) * 5
        ry = 72 + ring * 15
        draw.ellipse((cx - rx, cy - ry, cx + rx, cy + ry), outline=(0, 220, 112, 120 - ring * 22), width=4)
    for i in range(10):
        a = i * math.tau / 10 + t * 0.4
        p1 = (cx + math.cos(a) * 72, cy + math.sin(a) * 42)
        p2 = (cx + math.cos(a + 0.22) * 150, cy + math.sin(a + 0.22) * 88)
        draw.line((p1, p2), fill=(0, 28, 16, 150), width=5)
        draw.line((p1, p2), fill=(0, 245, 122, 80), width=2)
    return blur_glow(img, 10, 220) if glow else img


def frame_scorchmark(index, spec, glow=False):
    w, h = spec["size"]
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img, "RGBA")
    cx, cy = w / 2, h / 2
    draw.ellipse((cx - 88, cy - 48, cx + 88, cy + 48), fill=(6, 8, 7, 156))
    for i in range(18):
        a = i * math.tau / 18
        draw.line((cx, cy, cx + math.cos(a) * (46 + i % 5 * 8), cy + math.sin(a) * (23 + i % 4 * 6)), fill=(0, 135, 72, 80), width=2)
    draw.ellipse((cx - 30, cy - 14, cx + 30, cy + 14), fill=(0, 18, 11, 160))
    return blur_glow(img, 5, 110) if glow else img


def frame_hover_emitter(index, spec, glow=False):
    w, h = spec["size"]
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img, "RGBA")
    t = index / max(1, spec["frames"])
    cx, cy = w / 2, h / 2

    outer = (81, 38)
    inner = (46, 21)
    pulse = math.sin(t * math.tau) * 3.0

    for ring in range(4):
        rx = outer[0] + pulse + ring * 6
        ry = outer[1] + pulse * 0.45 + ring * 3
        alpha = clamp(92 - ring * 14)
        draw.ellipse(
            (cx - rx, cy - ry, cx + rx, cy + ry),
            outline=(0, clamp(190 + ring * 14), clamp(105 + ring * 24), alpha),
            width=2,
        )

    draw.ellipse(
        (cx - inner[0], cy - inner[1], cx + inner[0], cy + inner[1]),
        outline=(220, 255, 210, 98),
        width=2,
    )

    shard_colors = [
        (0, 255, 130, 180),
        (70, 255, 210, 150),
        (178, 255, 86, 135),
        (235, 255, 218, 120),
    ]
    for shard in range(12):
        angle = t * math.tau * 1.35 + shard * math.tau / 12
        color = shard_colors[shard % len(shard_colors)]
        radius_a = 30 + (shard % 3) * 6
        radius_b = 64 + (shard % 4) * 5
        x1 = cx + math.cos(angle) * radius_a
        y1 = cy + math.sin(angle) * radius_a * 0.54
        x2 = cx + math.cos(angle + 0.16) * radius_b
        y2 = cy + math.sin(angle + 0.16) * radius_b * 0.54
        draw.line((x1, y1, x2, y2), fill=color, width=2)

    for arc in range(5):
        rx = 54 + arc * 7
        ry = 25 + arc * 4
        start = int((t * 360 * (1.0 + arc * 0.17) + arc * 61) % 360)
        span = 34 + arc * 6
        color = shard_colors[(arc + index) % len(shard_colors)]
        draw.arc(
            (cx - rx, cy - ry, cx + rx, cy + ry),
            start=start,
            end=start + span,
            fill=color,
            width=3 if arc % 2 == 0 else 2,
        )

    for sigil in range(8):
        angle = sigil * math.tau / 8 + t * 0.35
        x = cx + math.cos(angle) * 53
        y = cy + math.sin(angle) * 28
        draw.line(
            (x - math.cos(angle) * 5, y - math.sin(angle) * 3, x + math.cos(angle) * 5, y + math.sin(angle) * 3),
            fill=(0, 20, 11, 145),
            width=2,
        )

    return blur_glow(img, 9, 225) if glow else img


FRAME_BUILDERS = {
    "chargeup": frame_chargeup,
    "muzzle": frame_muzzle,
    "beam": frame_beam,
    "impact": frame_impact,
    "shield": frame_shield,
    "scorchmark": frame_scorchmark,
    "hover-emitter": frame_hover_emitter,
}


def write_effect(name, out_dir):
    spec = EFFECTS[name]
    normal = new_sheet(spec)
    glow = new_sheet(spec)
    builder = FRAME_BUILDERS[name]
    for index in range(spec["frames"]):
        paste_frame(normal, builder(index, spec, glow=False), spec, index)
        paste_frame(glow, builder(index, spec, glow=True), spec, index)
    normal_path = out_dir / f"{ASSET}-{name}.png"
    glow_path = out_dir / f"{ASSET}-{name}-glow.png"
    normal.save(normal_path)
    glow.save(glow_path)
    return {
        "effect": name,
        "normal": str(normal_path),
        "glow": str(glow_path),
        "frame_size": spec["size"],
        "frames": spec["frames"],
        "line_length": spec["line"],
        "roles": ["base", "glow", "runtime-animation"] if name == "hover-emitter"
            else ["base", "glow"] if name != "scorchmark"
            else ["base", "decal"],
    }


def main():
    parser = argparse.ArgumentParser(description="Generate procedural Emerald Apocalypse hover tank effect draft sheets.")
    parser.add_argument("--out-dir", default="output/meshy/emerald-apocalypse-hover-tank/effects")
    args = parser.parse_args()
    out_dir = Path(args.out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    outputs = [write_effect(name, out_dir) for name in EFFECTS]
    manifest = {
        "asset": ASSET,
        "seed": SEED,
        "source": "procedural generator; no Singularity Lance or Gaian saucer source art reused",
        "outputs": outputs,
    }
    (out_dir / f"{ASSET}-effects.manifest.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")


if __name__ == "__main__":
    main()
