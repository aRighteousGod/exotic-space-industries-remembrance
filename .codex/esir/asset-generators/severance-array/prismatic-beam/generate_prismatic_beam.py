from __future__ import annotations

import json
import math
import random
from dataclasses import dataclass
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter


ASSET_NAME = "ei-severance-array-prismatic-beam"


def find_repo_root(start: Path) -> Path:
    for path in [start, *start.parents]:
        if (path / ".gitignore").exists() and (path / "exotic-space-industries-remembrance").exists():
            return path
    raise RuntimeError(f"Could not find repository root from {start}")


REPO_ROOT = find_repo_root(Path(__file__).resolve())
ROOT = REPO_ROOT / "output" / "meshy" / ASSET_NAME
EXPORT_DIR = ROOT / "factorio-export"
PREVIEW_DIR = ROOT / "previews"

BODY_SIZE = (256, 96)
CAP_SIZE = (192, 160)
IMPACT_SIZE = (256, 256)
BEAM_FRAMES = 16
IMPACT_FRAMES = 24
BEAM_LINE_LENGTH = 4
IMPACT_LINE_LENGTH = 6
SEED = 272031


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


def tile_noise(x: int, frame: int, salt: int, period: int = BODY_SIZE[0]) -> float:
    # Periodic harmonics keep the body tileable at the left/right edge.
    phase = frame * 0.67 + salt * 1.37
    tile_t = x / max(1, period - 1)
    a = math.sin(tile_t * math.tau * 3.0 + phase)
    b = math.sin(tile_t * math.tau * 7.0 - phase * 0.71)
    c = math.sin(tile_t * math.tau * 11.0 + phase * 1.9)
    return (a * 0.50 + b * 0.33 + c * 0.17 + 1.0) * 0.5


def draw_body_frame(frame: int, glow: bool = False) -> Image.Image:
    width, height = BODY_SIZE
    img = Image.new("RGBA", BODY_SIZE, (0, 0, 0, 0))
    pixels = img.load()
    phase = frame / BEAM_FRAMES * math.tau
    center = (height - 1) / 2.0

    for x in range(width):
        tile_t = x / max(1, width - 1)
        tile_phase = tile_t * math.tau
        shimmer = tile_noise(x, frame, 3)
        wave = math.sin(tile_phase * 2.0 + phase * 1.25) * 1.5
        local_center = center + wave
        core_radius = 4.8 + shimmer * 1.8
        band_radius = 17.0 + tile_noise(x, frame, 11) * 5.5
        haze_radius = 28.0 + tile_noise(x, frame, 19) * 8.0

        for y in range(height):
            dy = y - local_center
            ady = abs(dy)
            offset = dy / max(1.0, band_radius)
            alpha_core = math.exp(-((ady / core_radius) ** 2)) * 245.0
            alpha_band = math.exp(-((ady / band_radius) ** 2)) * 145.0
            alpha_haze = math.exp(-((ady / haze_radius) ** 2)) * 45.0
            strand = 0.76 + 0.24 * math.sin(tile_phase * 9.0 + y * 0.19 + phase)
            color_phase = phase + 0.9 * math.sin(tile_phase * 2.0)

            if glow:
                alpha = (alpha_band * 0.75 + alpha_haze * 1.15) * strand
                color = spectral_color(offset * 1.25, color_phase, 0.45)
            else:
                alpha = (alpha_core + alpha_band * 0.75 + alpha_haze * 0.28) * strand
                color = spectral_color(offset, color_phase, 1.0)

            if alpha > 1:
                add_pixel(pixels, x, y, (*color, clamp(alpha)))

    rng = random.Random(SEED + frame * 101 + (5000 if glow else 0))
    ember_count = 34 if not glow else 18
    for _ in range(ember_count):
        x = rng.randrange(24, width - 24)
        side = -1 if rng.random() < 0.5 else 1
        y = int(center + side * rng.uniform(16, 34) + rng.uniform(-5, 5))
        radius = rng.uniform(0.6, 1.9 if not glow else 3.2)
        alpha = rng.randrange(45, 105 if not glow else 80)
        color = rng.choice([(255, 109, 20), (255, 194, 36), (50, 232, 255), (238, 42, 209)])
        draw_disc(img, x, y, radius, (*color, alpha), additive=glow)

    if glow:
        img = horizontal_wrap_blur(img, 1.35)
    return apply_edge_fade(img, 0, 12, tile_x=True)


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


def edge_factor(position: int, length: int, margin: int, soft: int = 8) -> float:
    if margin <= 0:
        return 1.0

    distance = min(position, length - 1 - position)
    if distance < margin:
        return 0.0
    if distance < margin + soft:
        return ((distance - margin) / max(1, soft)) ** 0.72
    return 1.0


def apply_edge_fade(img: Image.Image, margin_x: int, margin_y: int, tile_x: bool = False, threshold: int = 3) -> Image.Image:
    pixels = img.load()
    width, height = img.size

    for y in range(height):
        fy = edge_factor(y, height, margin_y)

        for x in range(width):
            fx = 1.0 if tile_x else edge_factor(x, width, margin_x)

            r, g, b, a = pixels[x, y]
            a = clamp(a * min(fx, fy))
            if a <= threshold:
                pixels[x, y] = (0, 0, 0, 0)
            else:
                pixels[x, y] = (r, g, b, a)

    return img


def horizontal_wrap_blur(img: Image.Image, radius: float, pad: int = 16) -> Image.Image:
    width, height = img.size
    extended = Image.new("RGBA", (width + pad * 2, height), (0, 0, 0, 0))
    extended.alpha_composite(img.crop((width - pad, 0, width, height)), (0, 0))
    extended.alpha_composite(img, (pad, 0))
    extended.alpha_composite(img.crop((0, 0, pad, height)), (pad + width, 0))
    blurred = extended.filter(ImageFilter.GaussianBlur(radius))
    return blurred.crop((pad, 0, pad + width, height))


def cap_envelope(x: int, width: int, kind: str) -> float:
    t = x / max(1, width - 1)
    if kind == "head":
        return math.sin(t * math.pi * 0.5) ** 0.42
    return math.cos(t * math.pi * 0.5) ** 0.50


def draw_cap_frame(frame: int, kind: str, glow: bool = False) -> Image.Image:
    width, height = CAP_SIZE
    img = Image.new("RGBA", CAP_SIZE, (0, 0, 0, 0))
    pixels = img.load()
    phase = frame / BEAM_FRAMES * math.tau
    center = (height - 1) / 2.0

    for x in range(width):
        envelope = cap_envelope(x, width, kind)
        if envelope <= 0:
            continue
        tip_bias = x / max(1, width - 1) if kind == "head" else 1.0 - x / max(1, width - 1)
        wave = math.sin(x / width * math.tau * 1.6 + phase) * 2.4
        local_center = center + wave
        band_radius = 18.0 + 24.0 * envelope
        core_radius = 4.5 + 5.0 * envelope
        haze_radius = 34.0 + 38.0 * envelope

        for y in range(height):
            dy = y - local_center
            ady = abs(dy)
            offset = dy / max(1.0, band_radius)
            cut = envelope * (0.75 + 0.25 * math.sin(phase + x * 0.08))
            alpha_core = math.exp(-((ady / core_radius) ** 2)) * 255.0 * cut
            alpha_band = math.exp(-((ady / band_radius) ** 2)) * 172.0 * cut
            alpha_haze = math.exp(-((ady / haze_radius) ** 2)) * 58.0 * cut
            if glow:
                alpha = alpha_band * 0.9 + alpha_haze * 1.25
                color = spectral_color(offset * 1.15, phase + x * 0.04, 0.4)
            else:
                alpha = alpha_core + alpha_band * 0.80 + alpha_haze * 0.30
                color = spectral_color(offset, phase + x * 0.05, 1.0)
            alpha *= 0.70 + 0.30 * tip_bias
            if alpha > 1:
                add_pixel(pixels, x, y, (*color, clamp(alpha)))

    rng = random.Random(SEED + frame * 131 + (37 if kind == "head" else 73) + (9000 if glow else 0))
    for _ in range(45 if kind == "head" else 30):
        t = rng.random()
        x = width * (t ** (0.45 if kind == "head" else 1.75))
        if kind == "tail":
            x = width - x
        y = center + rng.choice([-1, 1]) * rng.uniform(22, 58) + rng.uniform(-5, 5)
        radius = rng.uniform(0.8, 3.3 if glow else 2.1)
        color = rng.choice([(255, 90, 12), (255, 210, 45), (0, 226, 255), (244, 42, 214), (132, 72, 255)])
        alpha = rng.randrange(42, 126 if not glow else 96)
        draw_disc(img, x, y, radius, (*color, alpha), additive=glow)

    if glow:
        img = img.filter(ImageFilter.GaussianBlur(1.6))
    return apply_edge_fade(img, 14, 14)


def draw_impact_frame(frame: int, glow: bool = False) -> Image.Image:
    width, height = IMPACT_SIZE
    img = Image.new("RGBA", IMPACT_SIZE, (0, 0, 0, 0))
    pixels = img.load()
    phase = frame / IMPACT_FRAMES * math.tau
    cx = (width - 1) / 2.0
    cy = (height - 1) / 2.0
    pulse = 0.78 + 0.22 * math.sin(phase)

    for y in range(height):
        for x in range(width):
            dx = x - cx
            dy = y - cy
            dist = math.hypot(dx, dy)
            angle = math.atan2(dy, dx)
            diagonal = abs(dx * 0.78 - dy * 0.62)
            slash = math.exp(-((diagonal / (10.0 + 5.0 * pulse)) ** 2)) * math.exp(-((dist / 92.0) ** 2))
            ring = math.exp(-(((dist - 42.0 - 6.0 * math.sin(phase + angle * 3.0)) / 10.0) ** 2))
            rays = (0.5 + 0.5 * math.sin(angle * 7.0 + phase * 2.2)) ** 3
            alpha = slash * 240.0 + ring * rays * 105.0
            if glow:
                alpha = slash * 135.0 + ring * rays * 155.0
            if alpha <= 1:
                continue
            color = spectral_color(math.sin(angle + phase) * 0.55, phase + angle * 2.0, 1.0)
            if slash > 0.55:
                color = mix(color, (255, 226, 42), 0.45)
            add_pixel(pixels, x, y, (*color, clamp(alpha)))

    rng = random.Random(SEED + frame * 199 + (12000 if glow else 0))
    for _ in range(90 if not glow else 55):
        angle = rng.uniform(-0.85, 2.25)
        dist = rng.uniform(18, 108)
        x = cx + math.cos(angle) * dist
        y = cy + math.sin(angle) * dist
        color = rng.choice([(255, 83, 9), (255, 193, 40), (0, 226, 255), (242, 45, 206)])
        draw_disc(img, x, y, rng.uniform(0.8, 3.8 if glow else 2.4), (*color, rng.randrange(35, 118)), additive=glow)

    if glow:
        img = img.filter(ImageFilter.GaussianBlur(2.0))
    return apply_edge_fade(img, 16, 16)


def pack_sheet(frames: list[Image.Image], frame_size: tuple[int, int], line_length: int) -> Image.Image:
    rows = math.ceil(len(frames) / line_length)
    sheet = Image.new("RGBA", (frame_size[0] * line_length, frame_size[1] * rows), (0, 0, 0, 0))
    for index, frame in enumerate(frames):
        x = (index % line_length) * frame_size[0]
        y = (index // line_length) * frame_size[1]
        sheet.alpha_composite(frame, (x, y))
    return sheet


def alpha_bounds(img: Image.Image) -> dict[str, int] | None:
    alpha = img.getchannel("A")
    bbox = alpha.getbbox()
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
    frame_w, frame_h = spec.frame_size
    bounds = []
    warnings = []
    for index in range(spec.frame_count):
        x = (index % spec.line_length) * frame_w
        y = (index // spec.line_length) * frame_h
        frame = img.crop((x, y, x + frame_w, y + frame_h))
        frame_bounds = alpha_bounds(frame)
        bounds.append(frame_bounds)
        if frame_bounds is None:
            warnings.append(f"frame {index} has no alpha")
            continue
        margins = [
            frame_bounds["margin_left"],
            frame_bounds["margin_top"],
            frame_bounds["margin_right"],
            frame_bounds["margin_bottom"],
        ]
        min_margin = min(margins)
        # Body is intentionally tileable left/right; cap/impact frames need full padding.
        if "body" in spec.path.name:
            vertical_margin = min(frame_bounds["margin_top"], frame_bounds["margin_bottom"])
            if vertical_margin < 6:
                warnings.append(f"frame {index} vertical alpha margin {vertical_margin}px")
        elif min_margin < 8:
            warnings.append(f"frame {index} alpha margin {min_margin}px")

    return {
        "file": spec.path.name,
        "path": str(spec.path.relative_to(ROOT)).replace("\\", "/"),
        "dimensions": list(img.size),
        "frame_size": list(spec.frame_size),
        "frame_count": spec.frame_count,
        "line_length": spec.line_length,
        "alpha_bounds": bounds,
        "warnings": warnings,
    }

def write_snippet() -> None:
    snippet = f"""-- Draft only: generated staged snippet for {ASSET_NAME}.
-- Copy PNGs into graphics/entities/severance-array/beam/ before using this.
-- Leave ei-severance-array-trigger-beam unchanged; it is the hidden script trigger carrier.

local PRISMATIC_BEAM_GRAPHICS_PATH = ARRAY_GRAPHICS_PATH.."beam/"

local function make_prismatic_beam_animation(filename, glow_filename, width, height, frame_count, line_length, scale)
    scale = scale or 1

    return {{
        layers = {{
            {{
                filename = PRISMATIC_BEAM_GRAPHICS_PATH..filename,
                width = width,
                height = height,
                frame_count = frame_count,
                line_length = line_length,
                animation_speed = 0.55,
                scale = scale,
            }},
            {{
                filename = PRISMATIC_BEAM_GRAPHICS_PATH..glow_filename,
                width = width,
                height = height,
                frame_count = frame_count,
                line_length = line_length,
                animation_speed = 0.55,
                scale = scale,
                draw_as_glow = true,
                blend_mode = "additive-soft",
            }},
        }},
    }}
end

local function make_prismatic_beam_graphics_set(scale)
    scale = scale or 1

    local body = make_prismatic_beam_animation(
        "ei-severance-array-beam-body.png",
        "ei-severance-array-beam-body-glow.png",
        {BODY_SIZE[0]},
        {BODY_SIZE[1]},
        {BEAM_FRAMES},
        {BEAM_LINE_LENGTH},
        scale
    )

    local head = make_prismatic_beam_animation(
        "ei-severance-array-beam-head.png",
        "ei-severance-array-beam-head-glow.png",
        {CAP_SIZE[0]},
        {CAP_SIZE[1]},
        {BEAM_FRAMES},
        {BEAM_LINE_LENGTH},
        scale
    )

    local tail = make_prismatic_beam_animation(
        "ei-severance-array-beam-tail.png",
        "ei-severance-array-beam-tail-glow.png",
        {CAP_SIZE[0]},
        {CAP_SIZE[1]},
        {BEAM_FRAMES},
        {BEAM_LINE_LENGTH},
        scale
    )

    return {{
        beam = {{
            start = tail,
            ending = head,
            head = head,
            tail = tail,
            body = {{body}},
            render_layer = "projectile",
        }},
        ground = {{
            head = util.empty_sprite(),
            tail = util.empty_sprite(),
            body = util.empty_sprite(),
        }},
        desired_segment_length = 1,
        transparent_start_end_animations = true,
        random_end_animation_rotation = false,
        randomize_animation_per_segment = false,
    }}
end

-- Promotion sketch, after preview approval and asset copy:
-- severance_beam.graphics_set = make_prismatic_beam_graphics_set(0.34)
-- severance_impact_beam.graphics_set = make_prismatic_beam_graphics_set(0.42)
-- Do not apply VISUAL_BEAM_TINT/IMPACT_BEAM_TINT to these custom rainbow fields.
"""
    (EXPORT_DIR / f"{ASSET_NAME}.prototype-snippet.lua").write_text(snippet, encoding="utf-8")


def write_integration_note() -> None:
    note = f"""# {ASSET_NAME}

Staged procedural Prismatic Core beam draft for the Severance Array.

This folder is a dry-run asset stage only. It does not modify shipped graphics or prototypes.

## Contents

- `ei-severance-array-beam-body.png`: tileable 16-frame body sheet, `256x96` frames, `4x4`.
- `ei-severance-array-beam-head.png`: 16-frame leading cap sheet, `192x160` frames, `4x4`.
- `ei-severance-array-beam-tail.png`: 16-frame dissipating cap sheet, `192x160` frames, `4x4`.
- `*-glow.png`: additive companion sheets for the same frames.
- `ei-severance-array-impact-prism.png`: optional 24-frame impact bloom, `256x256` frames, `6x4`.
- `{ASSET_NAME}.prototype-snippet.lua`: draft helper/snippet for later prototype promotion.
- `{ASSET_NAME}.factorio-asset-manifest.json`: dimensions, warnings, preview references, and promotion notes.

## Promotion Notes

If approved, copy the PNG files into:

`exotic-space-industries-remembrance/graphics/entities/severance-array/beam/`

Then adapt `prototypes/quantum-age/severance-array.lua` so the visible `ei-severance-array-beam` and
`ei-severance-array-impact-beam` use the custom `graphics_set.beam`. Leave
`ei-severance-array-trigger-beam` unchanged because it carries the hidden script effect.

The existing purple tint helpers should not be applied to these custom prismatic sprites; the color is baked
into the transparent sheets.
"""
    (EXPORT_DIR / "README.md").write_text(note, encoding="utf-8")


def composite_on_background(bg: tuple[int, int, int], label: str, beam: Image.Image, impact: Image.Image) -> Image.Image:
    canvas = Image.new("RGBA", (1280, 230), (*bg, 255))
    draw = ImageDraw.Draw(canvas)
    draw.text((18, 14), label, fill=(245, 245, 245, 255) if sum(bg) < 380 else (25, 25, 25, 255))

    y = 82
    x = 95
    canvas.alpha_composite(beam, (x, y - beam.height // 2))
    canvas.alpha_composite(impact, (1010, 18))
    return canvas


def make_beam_preview(body: Image.Image, head: Image.Image, tail: Image.Image, impact: Image.Image) -> Image.Image:
    repeated = Image.new("RGBA", (900, CAP_SIZE[1]), (0, 0, 0, 0))
    repeated.alpha_composite(tail, (0, 0))
    for index in range(4):
        repeated.alpha_composite(body, (CAP_SIZE[0] - 18 + index * BODY_SIZE[0], (CAP_SIZE[1] - BODY_SIZE[1]) // 2))
    repeated.alpha_composite(head, (CAP_SIZE[0] - 18 + 4 * BODY_SIZE[0] - 30, 0))
    repeated = repeated.crop((0, 0, 900, CAP_SIZE[1]))

    rows = [
        composite_on_background((4, 9, 13), "dark void", repeated, impact),
        composite_on_background((105, 70, 32), "desert orefield", repeated, impact),
        composite_on_background((95, 101, 101), "gray factory floor", repeated, impact),
    ]
    preview = Image.new("RGBA", (1280, len(rows) * 230), (0, 0, 0, 255))
    for i, row in enumerate(rows):
        preview.alpha_composite(row, (0, i * 230))
    return preview


def make_tile_preview(body_frames: list[Image.Image]) -> Image.Image:
    width = BODY_SIZE[0] * 5
    height = BODY_SIZE[1] * 4
    preview = Image.new("RGBA", (width, height), (20, 21, 22, 255))
    draw = ImageDraw.Draw(preview)
    for row in range(4):
        frame = body_frames[row * 4]
        for col in range(5):
            preview.alpha_composite(frame, (col * BODY_SIZE[0], row * BODY_SIZE[1]))
        for col in range(1, 5):
            x = col * BODY_SIZE[0]
            draw.line((x, row * BODY_SIZE[1], x, (row + 1) * BODY_SIZE[1]), fill=(255, 255, 255, 52), width=1)
    return preview


def make_frame_strip(frames: list[Image.Image], title: str) -> Image.Image:
    thumb_scale = 0.5
    thumb_w = int(frames[0].width * thumb_scale)
    thumb_h = int(frames[0].height * thumb_scale)
    cols = 8
    rows = math.ceil(len(frames) / cols)
    canvas = Image.new("RGBA", (cols * thumb_w, rows * thumb_h + 28), (12, 13, 16, 255))
    ImageDraw.Draw(canvas).text((8, 7), title, fill=(230, 230, 230, 255))
    for index, frame in enumerate(frames):
        thumb = frame.resize((thumb_w, thumb_h), Image.Resampling.LANCZOS)
        canvas.alpha_composite(thumb, ((index % cols) * thumb_w, 28 + (index // cols) * thumb_h))
    return canvas


def write_manifest(specs: list[SheetSpec], previews: list[Path]) -> dict[str, object]:
    sheets = [sheet_bounds(spec) for spec in specs]
    warnings = []
    for sheet in sheets:
        warnings.extend(f"{sheet['file']}: {warning}" for warning in sheet["warnings"])

    manifest = {
        "asset_name": ASSET_NAME,
        "mode": "custom-beam-draft",
        "variant": "prismatic-core",
        "generator": str(Path(__file__).resolve().relative_to(REPO_ROOT)).replace("\\", "/"),
        "seed": SEED,
        "prototype_template": "beam",
        "target_prototype_type": "beam",
        "target_prototype_names": ["ei-severance-array-beam", "ei-severance-array-impact-beam"],
        "do_not_modify": ["ei-severance-array-trigger-beam"],
        "staged_assets": sheets,
        "previews": [str(path.relative_to(ROOT)).replace("\\", "/") for path in previews],
        "snippet": f"factorio-export/{ASSET_NAME}.prototype-snippet.lua",
        "promotion": {
            "copy_assets_to": "exotic-space-industries-remembrance/graphics/entities/severance-array/beam/",
            "prototype_file": "exotic-space-industries-remembrance/prototypes/quantum-age/severance-array.lua",
            "field": "graphics_set.beam",
            "requires_visual_approval": True,
            "notes": [
                "Leave the hidden trigger beam unchanged.",
                "Bypass the existing purple tint helpers for custom prismatic sprites.",
                "Run preflight and Severance Array QC only after promotion is requested.",
            ],
        },
        "warnings": warnings,
    }
    manifest_path = EXPORT_DIR / f"{ASSET_NAME}.factorio-asset-manifest.json"
    manifest_path.write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    return manifest


def main() -> None:
    EXPORT_DIR.mkdir(parents=True, exist_ok=True)
    PREVIEW_DIR.mkdir(parents=True, exist_ok=True)
    (ROOT / "source").mkdir(parents=True, exist_ok=True)

    body_frames = [draw_body_frame(index, False) for index in range(BEAM_FRAMES)]
    body_glow_frames = [draw_body_frame(index, True) for index in range(BEAM_FRAMES)]
    head_frames = [draw_cap_frame(index, "head", False) for index in range(BEAM_FRAMES)]
    head_glow_frames = [draw_cap_frame(index, "head", True) for index in range(BEAM_FRAMES)]
    tail_frames = [draw_cap_frame(index, "tail", False) for index in range(BEAM_FRAMES)]
    tail_glow_frames = [draw_cap_frame(index, "tail", True) for index in range(BEAM_FRAMES)]
    impact_frames = [draw_impact_frame(index, False) for index in range(IMPACT_FRAMES)]
    impact_glow_frames = [draw_impact_frame(index, True) for index in range(IMPACT_FRAMES)]

    sheet_specs = [
        SheetSpec(EXPORT_DIR / "ei-severance-array-beam-body.png", BODY_SIZE, BEAM_FRAMES, BEAM_LINE_LENGTH),
        SheetSpec(EXPORT_DIR / "ei-severance-array-beam-body-glow.png", BODY_SIZE, BEAM_FRAMES, BEAM_LINE_LENGTH),
        SheetSpec(EXPORT_DIR / "ei-severance-array-beam-head.png", CAP_SIZE, BEAM_FRAMES, BEAM_LINE_LENGTH),
        SheetSpec(EXPORT_DIR / "ei-severance-array-beam-head-glow.png", CAP_SIZE, BEAM_FRAMES, BEAM_LINE_LENGTH),
        SheetSpec(EXPORT_DIR / "ei-severance-array-beam-tail.png", CAP_SIZE, BEAM_FRAMES, BEAM_LINE_LENGTH),
        SheetSpec(EXPORT_DIR / "ei-severance-array-beam-tail-glow.png", CAP_SIZE, BEAM_FRAMES, BEAM_LINE_LENGTH),
        SheetSpec(EXPORT_DIR / "ei-severance-array-impact-prism.png", IMPACT_SIZE, IMPACT_FRAMES, IMPACT_LINE_LENGTH),
        SheetSpec(EXPORT_DIR / "ei-severance-array-impact-prism-glow.png", IMPACT_SIZE, IMPACT_FRAMES, IMPACT_LINE_LENGTH),
    ]

    frame_sets = [
        body_frames,
        body_glow_frames,
        head_frames,
        head_glow_frames,
        tail_frames,
        tail_glow_frames,
        impact_frames,
        impact_glow_frames,
    ]
    for spec, frames in zip(sheet_specs, frame_sets):
        pack_sheet(frames, spec.frame_size, spec.line_length).save(spec.path)

    preview_paths = [
        PREVIEW_DIR / f"{ASSET_NAME}-readability-preview.png",
        PREVIEW_DIR / f"{ASSET_NAME}-tile-check.png",
        PREVIEW_DIR / f"{ASSET_NAME}-body-frame-strip.png",
        PREVIEW_DIR / f"{ASSET_NAME}-impact-frame-strip.png",
    ]
    make_beam_preview(body_frames[0], head_frames[3], tail_frames[9], impact_frames[4]).save(preview_paths[0])
    make_tile_preview(body_frames).save(preview_paths[1])
    make_frame_strip(body_frames, "Prismatic Core body frames").save(preview_paths[2])
    make_frame_strip(impact_frames, "Prismatic Core impact frames").save(preview_paths[3])

    write_snippet()
    write_integration_note()
    manifest = write_manifest(sheet_specs, preview_paths)

    report = {
        "asset_name": ASSET_NAME,
        "export_dir": str(EXPORT_DIR.relative_to(ROOT)).replace("\\", "/"),
        "preview_dir": str(PREVIEW_DIR.relative_to(ROOT)).replace("\\", "/"),
        "files_written": [str(spec.path.relative_to(ROOT)).replace("\\", "/") for spec in sheet_specs],
        "previews_written": [str(path.relative_to(ROOT)).replace("\\", "/") for path in preview_paths],
        "warnings": manifest["warnings"],
    }
    (ROOT / "source" / "generation-report.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
