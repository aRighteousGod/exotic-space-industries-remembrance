#!/usr/bin/env python3
"""Promote rendered nuclear train sheets and derive trim masks/icon sources."""

from __future__ import annotations

import argparse
import html
import json
import math
import shutil
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageEnhance, ImageFilter


FRAME_SIZE = 384


VARIANTS = [
    {
        "name": "goliath-rotated",
        "target_dir": "exotic-space-industries-remembrance/graphics/entities/nuclear-locomotive",
        "basename": "body",
        "grid": (16, 16),
        "frames": 256,
        "icon_frame": 32,
        "gamma": 0.78,
        "gain": 1.02,
        "lift": 6,
        "contrast": 1.04,
        "saturation": 0.86,
        "channel_gains": (1.02, 0.99, 1.08),
        "forward_shift_px": 10,
    },
    {
        "name": "goliath-sloped",
        "target_dir": "exotic-space-industries-remembrance/graphics/entities/nuclear-locomotive",
        "basename": "sloped",
        "grid": (16, 10),
        "frames": 160,
        "sloped_stripes": 8,
        "yaw_directions": 32,
        "slope_samples": 5,
        "reverse_slope_samples": False,
        # Vanilla/Juggernaut sloped files are four yaw columns by five slope rows per stripe.
        "reverse_slope_stripes": (),
        "target_slope_deltas_px": {},
        "gamma": 0.78,
        "gain": 1.02,
        "lift": 6,
        "contrast": 1.04,
        "saturation": 0.86,
        "channel_gains": (1.02, 0.99, 1.08),
        "forward_shift_px": 10,
    },
    {
        "name": "black-ark-rotated",
        "target_dir": "exotic-space-industries-remembrance/graphics/entities/advanced-cargo-wagon",
        "basename": "body",
        "grid": (16, 8),
        "frames": 128,
        "icon_frame": 16,
        "gamma": 0.82,
        "gain": 1.00,
        "lift": 4,
        "contrast": 1.04,
        "saturation": 0.80,
        "channel_gains": (1.02, 0.98, 1.08),
    },
    {
        "name": "black-ark-sloped",
        "target_dir": "exotic-space-industries-remembrance/graphics/entities/advanced-cargo-wagon",
        "basename": "sloped",
        "grid": (16, 5),
        "frames": 80,
        "sloped_stripes": 4,
        "yaw_directions": 16,
        "slope_samples": 5,
        "reverse_slope_samples": False,
        # Vanilla/Juggernaut sloped files are four yaw columns by five slope rows per stripe.
        "reverse_slope_stripes": (),
        "target_slope_deltas_px": {},
        "gamma": 0.82,
        "gain": 1.00,
        "lift": 4,
        "contrast": 1.04,
        "saturation": 0.80,
        "channel_gains": (1.02, 0.98, 1.08),
    },
]

ICON_TARGETS = {
    "goliath-rotated": {
        "source": "output/meshy/nuclear-trains/icons/ei-nuclear-locomotive-source.png",
        "tech": "exotic-space-industries-remembrance/graphics/techs/nuclear-locomotive.png",
    },
    "black-ark-rotated": {
        "source": "output/meshy/nuclear-trains/icons/ei-advanced-cargo-wagon-source.png",
        "tech": "exotic-space-industries-remembrance/graphics/techs/advanced-cargo-wagon.png",
    },
}


def sheet_path(repo: Path, variant: str, filename: str) -> Path:
    return repo / "output" / "meshy" / "nuclear-trains" / variant / "Render" / ".Sheets" / filename


def copy_sheet(source: Path, target: Path) -> None:
    if not source.exists():
        raise FileNotFoundError(source)
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source, target)


def enhance_entity_sheet(
    source: Path,
    target: Path,
    gamma: float,
    gain: float,
    lift: int,
    contrast: float,
    saturation: float,
    channel_gains: tuple[float, float, float] = (1.0, 1.0, 1.0),
) -> dict[str, float]:
    if not source.exists():
        raise FileNotFoundError(source)
    with Image.open(source).convert("RGBA") as img:
        pixels = img.load()
        before_luma = []
        for y in range(img.height):
            for x in range(img.width):
                r, g, b, a = pixels[x, y]
                if a < 8:
                    continue
                before_luma.append(0.2126 * r + 0.7152 * g + 0.0722 * b)
                nr = min(255, int(((r / 255) ** gamma) * 255 * gain + lift))
                ng = min(255, int(((g / 255) ** gamma) * 255 * gain + lift))
                nb = min(255, int(((b / 255) ** gamma) * 255 * gain + lift))
                pixels[x, y] = (nr, ng, nb, a)
        if contrast != 1.0 or saturation != 1.0:
            alpha = img.getchannel("A")
            rgb = img.convert("RGB")
            rgb = ImageEnhance.Contrast(rgb).enhance(contrast)
            rgb = ImageEnhance.Color(rgb).enhance(saturation)
            img = rgb.convert("RGBA")
            img.putalpha(alpha)
        if channel_gains != (1.0, 1.0, 1.0):
            alpha = img.getchannel("A")
            red, green, blue = img.convert("RGB").split()
            red_gain, green_gain, blue_gain = channel_gains
            red = red.point([min(255, int(value * red_gain)) for value in range(256)])
            green = green.point([min(255, int(value * green_gain)) for value in range(256)])
            blue = blue.point([min(255, int(value * blue_gain)) for value in range(256)])
            img = Image.merge("RGBA", (red, green, blue, alpha))
        after_luma = []
        for r, g, b, a in img.getdata():
            if a < 8:
                continue
            after_luma.append(0.2126 * r + 0.7152 * g + 0.0722 * b)
        target.parent.mkdir(parents=True, exist_ok=True)
        img.save(target)
    return {
        "before_mean_luma": round(sum(before_luma) / len(before_luma), 3) if before_luma else 0,
        "after_mean_luma": round(sum(after_luma) / len(after_luma), 3) if after_luma else 0,
        "contrast": contrast,
        "saturation": saturation,
        "channel_gains": tuple(round(value, 3) for value in channel_gains),
    }


def validate_dimensions(path: Path, grid: tuple[int, int]) -> list[int]:
    with Image.open(path) as img:
        size = img.size
    expected = (FRAME_SIZE * grid[0], FRAME_SIZE * grid[1])
    if size != expected:
        raise ValueError(f"{path} is {size}, expected {expected}")
    return [size[0], size[1]]


def trim_mask_from_base(base_path: Path, mask_path: Path) -> dict[str, float | int]:
    with Image.open(base_path).convert("RGBA") as img:
        pixels = img.load()
        width, height = img.size
        alpha = Image.new("L", img.size, 0)
        alpha_pixels = alpha.load()
        selected = 0
        opaque = 0

        for y in range(height):
            for x in range(width):
                r, g, b, a = pixels[x, y]
                if a < 8:
                    continue
                opaque += 1
                luma = 0.2126 * r + 0.7152 * g + 0.0722 * b
                green_accent = (
                    48 <= g <= 180
                    and luma < 140
                    and g > r * 1.18 + 8
                    and g > b * 1.02 + 3
                )
                if green_accent:
                    alpha_pixels[x, y] = min(96, int(a * 0.38))
                    selected += 1

        alpha = alpha.filter(ImageFilter.MaxFilter(3)).filter(ImageFilter.GaussianBlur(0.35))
        mask = Image.new("RGBA", img.size, (84, 84, 84, 0))
        mask.putalpha(alpha)
        mask_path.parent.mkdir(parents=True, exist_ok=True)
        mask.save(mask_path)

    coverage = selected / opaque if opaque else 0
    return {
        "opaque_pixels": opaque,
        "selected_pixels": selected,
        "selected_fraction": round(coverage, 6),
    }


def light_sheet_from_base(base_path: Path, light_path: Path) -> dict[str, float | int]:
    with Image.open(base_path).convert("RGBA") as img:
        pixels = img.load()
        width, height = img.size
        light = Image.new("RGBA", img.size, (0, 0, 0, 0))
        light_pixels = light.load()
        selected = 0
        opaque = 0

        for y in range(height):
            for x in range(width):
                r, g, b, a = pixels[x, y]
                if a < 8:
                    continue
                opaque += 1
                cyan_light = b > 76 and g > 64 and b > r * 1.28 and g > r * 1.12
                green_light = g > 84 and g > r * 1.24 and g > b * 1.04
                if cyan_light or green_light:
                    alpha = min(88, max(18, int(a * 0.42)))
                    light_pixels[x, y] = (min(120, max(r, 42)), min(160, max(g, 92)), min(190, max(b, 118)), alpha)
                    selected += 1

        alpha = light.getchannel("A").filter(ImageFilter.MaxFilter(3)).filter(ImageFilter.GaussianBlur(0.8))
        color = light.filter(ImageFilter.GaussianBlur(0.5))
        color.putalpha(alpha)
        light_path.parent.mkdir(parents=True, exist_ok=True)
        color.save(light_path)

    coverage = selected / opaque if opaque else 0
    return {
        "opaque_pixels": opaque,
        "selected_pixels": selected,
        "selected_fraction": round(coverage, 6),
    }


def crop_frame(sheet: Image.Image, grid: tuple[int, int], index: int) -> Image.Image:
    col = index % grid[0]
    row = index // grid[0]
    box = (col * FRAME_SIZE, row * FRAME_SIZE, (col + 1) * FRAME_SIZE, (row + 1) * FRAME_SIZE)
    return sheet.crop(box)


def forward_offset(yaw_index: int, pixels: int) -> tuple[int, int]:
    angle = 2 * math.pi * (yaw_index % 256) / 256
    return (int(round(math.sin(angle) * pixels)), int(round(-math.cos(angle) * pixels)))


def shifted_frame(frame: Image.Image, dx: int, dy: int) -> Image.Image:
    shifted = Image.new("RGBA", (FRAME_SIZE, FRAME_SIZE), (0, 0, 0, 0))
    src_left = max(0, -dx)
    src_top = max(0, -dy)
    dst_left = max(0, dx)
    dst_top = max(0, dy)
    width = FRAME_SIZE - src_left - dst_left
    height = FRAME_SIZE - src_top - dst_top
    if width <= 0 or height <= 0:
        return shifted
    region = frame.crop((src_left, src_top, src_left + width, src_top + height))
    shifted.alpha_composite(region, (dst_left, dst_top))
    return shifted


def alpha_centroid(frame: Image.Image) -> tuple[float, float] | None:
    alpha = frame.getchannel("A")
    bbox = alpha.getbbox()
    if bbox is None:
        return None
    pixels = alpha.load()
    total = 0
    sum_x = 0
    sum_y = 0
    for y in range(bbox[1], bbox[3], 4):
        for x in range(bbox[0], bbox[2], 4):
            weight = pixels[x, y]
            if weight <= 24:
                continue
            total += weight
            sum_x += x * weight
            sum_y += y * weight
    if total == 0:
        return None
    return (sum_x / total, sum_y / total)


def slope_output_source_index(
    stripe_index: int,
    yaw_column: int,
    slope_index: int,
    yaw_columns_per_stripe: int,
    slope_samples: int,
    reverse_slope_samples: bool,
    reverse_slope_stripes: set[int],
) -> int:
    reverse_this_stripe = reverse_slope_samples or (stripe_index + 1) in reverse_slope_stripes
    source_slope_index = slope_samples - 1 - slope_index if reverse_this_stripe else slope_index
    source_yaw_index = stripe_index * yaw_columns_per_stripe + yaw_column
    return source_yaw_index * slope_samples + source_slope_index


def compute_slope_drift_corrections(
    sheet_path: Path,
    yaw_directions: int,
    slope_samples: int,
    reverse_slope_samples: bool,
    reverse_slope_stripes: tuple[int, ...],
    target_deltas: dict[int, tuple[int, int]],
) -> dict[int, tuple[float, float]]:
    corrections: dict[int, tuple[float, float]] = {}
    if not target_deltas:
        return corrections
    reverse_stripes = set(reverse_slope_stripes)
    if yaw_directions % 4 != 0:
        raise ValueError(f"{sheet_path}: sloped yaw directions must pack into 4-column stripes")
    yaw_columns_per_stripe = 4
    stripe_count = yaw_directions // yaw_columns_per_stripe
    source_grid = (16, (yaw_directions * slope_samples + 15) // 16)
    with Image.open(sheet_path).convert("RGBA") as sheet:
        for stripe_number, target_delta in target_deltas.items():
            stripe_index = stripe_number - 1
            if stripe_index < 0 or stripe_index >= stripe_count:
                raise ValueError(f"{sheet_path}: slope drift stripe {stripe_number} exceeds {stripe_count} stripes")
            first_index = slope_output_source_index(
                stripe_index,
                0,
                0,
                yaw_columns_per_stripe,
                slope_samples,
                reverse_slope_samples,
                reverse_stripes,
            )
            last_index = slope_output_source_index(
                stripe_index,
                0,
                slope_samples - 1,
                yaw_columns_per_stripe,
                slope_samples,
                reverse_slope_samples,
                reverse_stripes,
            )
            first = alpha_centroid(crop_frame(sheet, source_grid, first_index))
            last = alpha_centroid(crop_frame(sheet, source_grid, last_index))
            if first is None or last is None:
                corrections[stripe_number] = (float(target_delta[0]), float(target_delta[1]))
                continue
            current_delta = (last[0] - first[0], last[1] - first[1])
            corrections[stripe_number] = (
                float(target_delta[0]) - current_delta[0],
                float(target_delta[1]) - current_delta[1],
            )
    return corrections


def apply_forward_shift_to_sheet(
    path: Path,
    grid: tuple[int, int],
    frames: int,
    pixels: int,
    yaw_indices: tuple[int, ...] | None = None,
    slope_samples: int = 1,
) -> dict[str, object]:
    offsets: dict[int, tuple[int, int]] = {}
    yaw_group_count = max(1, frames // max(1, slope_samples))
    with Image.open(path).convert("RGBA") as sheet:
        shifted_sheet = Image.new("RGBA", sheet.size, (0, 0, 0, 0))
        for frame_index in range(frames):
            if yaw_indices:
                yaw_index = yaw_indices[(frame_index // slope_samples) % len(yaw_indices)]
            elif slope_samples > 1:
                yaw_index = int(round(((frame_index // slope_samples) % yaw_group_count) * 256 / yaw_group_count))
            else:
                yaw_index = frame_index
            dx, dy = forward_offset(yaw_index, pixels)
            offsets[int(yaw_index)] = (dx, dy)
            frame = shifted_frame(crop_frame(sheet, grid, frame_index), dx, dy)
            col = frame_index % grid[0]
            row = frame_index // grid[0]
            shifted_sheet.alpha_composite(frame, (col * FRAME_SIZE, row * FRAME_SIZE))
        shifted_sheet.save(path)
    return {
        "pixels": pixels,
        "offsets": {str(key): [value[0], value[1]] for key, value in sorted(offsets.items())},
    }


def write_sloped_stripes(
    sheet_path: Path,
    target_dir: Path,
    basename: str,
    stripe_count: int,
    yaw_directions: int,
    slope_samples: int,
    reverse_slope_samples: bool = False,
    reverse_slope_stripes: tuple[int, ...] = (),
    slope_drift_corrections: dict[int, tuple[float, float]] | None = None,
) -> list[dict[str, int | str]]:
    records = []
    line_length = 4
    reverse_stripes = set(reverse_slope_stripes)
    slope_drift_corrections = slope_drift_corrections or {}
    if yaw_directions % stripe_count != 0:
        raise ValueError(f"{basename}: {yaw_directions} yaw directions must divide evenly into {stripe_count} stripes")
    yaw_columns_per_stripe = yaw_directions // stripe_count
    if yaw_columns_per_stripe != line_length:
        raise ValueError(f"{basename}: expected {line_length} yaw columns per stripe, got {yaw_columns_per_stripe}")

    with Image.open(sheet_path).convert("RGBA") as sheet:
        source_grid = (16, (yaw_directions * slope_samples + 15) // 16)
        for stripe_index in range(stripe_count):
            stripe = Image.new("RGBA", (FRAME_SIZE * line_length, FRAME_SIZE * slope_samples), (0, 0, 0, 0))
            reverse_this_stripe = reverse_slope_samples or (stripe_index + 1) in reverse_stripes
            drift = slope_drift_corrections.get(stripe_index + 1, (0.0, 0.0))
            for slope_index in range(slope_samples):
                for yaw_column in range(yaw_columns_per_stripe):
                    source_index = slope_output_source_index(
                        stripe_index,
                        yaw_column,
                        slope_index,
                        yaw_columns_per_stripe,
                        slope_samples,
                        reverse_slope_samples,
                        reverse_stripes,
                    )
                    frame = crop_frame(sheet, source_grid, source_index)
                    if drift != (0.0, 0.0):
                        t = slope_index / (slope_samples - 1) if slope_samples > 1 else 0
                        frame = shifted_frame(frame, int(round(drift[0] * t)), int(round(drift[1] * t)))
                    x = yaw_column * FRAME_SIZE
                    y = slope_index * FRAME_SIZE
                    stripe.alpha_composite(frame, (x, y))

            target = target_dir / f"{basename}-{stripe_index + 1}.png"
            target.parent.mkdir(parents=True, exist_ok=True)
            stripe.save(target)
            records.append({
                "target": str(target),
                "width": stripe.width,
                "height": stripe.height,
                "stripe_index": stripe_index + 1,
                "reversed": reverse_this_stripe,
                "yaw_columns": yaw_columns_per_stripe,
                "slope_rows": slope_samples,
                "slope_drift_correction": [round(drift[0], 3), round(drift[1], 3)],
            })
    return records


def alpha_bbox(image: Image.Image) -> tuple[int, int, int, int]:
    alpha = image.getchannel("A")
    bbox = alpha.getbbox()
    if bbox is None:
        return (0, 0, image.width, image.height)
    return bbox


def fit_subject(source: Image.Image, size: int, pad_ratio: float = 0.12) -> Image.Image:
    source = source.convert("RGBA")
    bbox = alpha_bbox(source)
    subject = source.crop(bbox)
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    max_subject = int(size * (1 - pad_ratio * 2))
    scale = min(max_subject / max(subject.width, 1), max_subject / max(subject.height, 1))
    new_size = (max(1, int(subject.width * scale)), max(1, int(subject.height * scale)))
    subject = subject.resize(new_size, Image.Resampling.LANCZOS)
    canvas.alpha_composite(subject, ((size - new_size[0]) // 2, (size - new_size[1]) // 2))
    return canvas


def enhance_icon_subject(source: Image.Image) -> Image.Image:
    source = source.convert("RGBA")
    alpha = source.getchannel("A")
    rgb = source.convert("RGB")
    rgb = ImageEnhance.Brightness(rgb).enhance(1.10)
    rgb = ImageEnhance.Contrast(rgb).enhance(1.10)
    enhanced = rgb.convert("RGBA")
    enhanced.putalpha(alpha)

    outline_alpha = ImageChops.subtract(alpha.filter(ImageFilter.MaxFilter(9)), alpha)
    outline = Image.new("RGBA", source.size, (82, 155, 96, 150))
    outline.putalpha(outline_alpha)
    out = Image.new("RGBA", source.size, (0, 0, 0, 0))
    out.alpha_composite(outline)
    out.alpha_composite(enhanced)
    return out


def tech_background(size: int) -> Image.Image:
    image = Image.new("RGBA", (size, size), (10, 12, 14, 255))
    draw = ImageDraw.Draw(image, "RGBA")
    for radius, alpha in [(238, 50), (184, 42), (128, 32)]:
        box = ((size - radius) // 2, (size - radius) // 2, (size + radius) // 2, (size + radius) // 2)
        draw.ellipse(box, outline=(77, 170, 96, alpha), width=max(2, size // 96))
    for offset in range(-size, size, 42):
        draw.line((offset, size, offset + size, 0), fill=(74, 88, 96, 45), width=4)
    return image


def write_icon_sources(repo: Path, variant: dict, records: dict, base_path: Path | None = None) -> None:
    target = ICON_TARGETS.get(variant["name"])
    if not target:
        return
    base_path = base_path or sheet_path(repo, variant["name"], "object_0.png")
    with Image.open(base_path).convert("RGBA") as sheet:
        frame = crop_frame(sheet, variant["grid"], variant["icon_frame"])

    icon_source = enhance_icon_subject(fit_subject(frame, 512, 0.08))
    source_path = repo / target["source"]
    source_path.parent.mkdir(parents=True, exist_ok=True)
    icon_source.save(source_path)

    tech = tech_background(512)
    shadow_alpha = icon_source.getchannel("A").filter(ImageFilter.GaussianBlur(9))
    shadow = Image.new("RGBA", (512, 512), (0, 0, 0, 120))
    shadow.putalpha(shadow_alpha)
    tech.alpha_composite(shadow, (10, 14))
    tech.alpha_composite(icon_source)
    tech_path = repo / target["tech"]
    tech_path.parent.mkdir(parents=True, exist_ok=True)
    tech.save(tech_path)

    records["icons"][variant["name"]] = {
        "source": str(source_path.relative_to(repo)),
        "tech": str(tech_path.relative_to(repo)),
    }


def write_gallery(repo: Path, records: dict) -> None:
    gallery = repo / "output" / "meshy" / "nuclear-trains" / "visual-gallery.html"
    rows = []
    for entry in records["promoted"]:
        if "target" in entry:
            target = html.escape(entry["target"])
            rows.append(f"<section><h2>{html.escape(entry['variant'])} / {html.escape(entry['role'])}</h2><img src='../../../{target}'></section>")
        elif entry.get("targets"):
            first_target = html.escape(entry["targets"][0]["target"])
            rows.append(f"<section><h2>{html.escape(entry['variant'])} / {html.escape(entry['role'])}</h2><img src='../../../{first_target}'></section>")
    gallery.write_text(
        "<!doctype html><meta charset='utf-8'><title>ESIR Nuclear Train Gallery</title>"
        "<style>body{background:#101316;color:#d7e1dc;font-family:Segoe UI,Arial,sans-serif;margin:24px}"
        "section{margin:0 0 28px}img{max-width:100%;background:#1b2024;image-rendering:auto}"
        "h2{font-size:16px;font-weight:600}</style>"
        + "\n".join(rows),
        encoding="utf-8",
    )
    records["gallery"] = str(gallery.relative_to(repo))


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo", default=".", help="Repository root.")
    parser.add_argument("--manifest", default="output/meshy/nuclear-trains/promoted-assets.json")
    args = parser.parse_args()

    repo = Path(args.repo).resolve()
    records: dict = {"promoted": [], "masks": {}, "icons": {}}

    for variant in VARIANTS:
        base_sheet = sheet_path(repo, variant["name"], "object_0.png")
        validate_dimensions(base_sheet, variant["grid"])
        target_dir = repo / variant["target_dir"]
        basename = variant["basename"]

        copies = {
            "shadow": (sheet_path(repo, variant["name"], "object_shadow_0.png"), target_dir / f"{basename}-shadow.png"),
        }
        base_target = target_dir / f"{basename}.png"
        forward_shift_px = int(variant.get("forward_shift_px", 0) or 0)
        enhancement = enhance_entity_sheet(
            base_sheet,
            base_target,
            float(variant["gamma"]),
            float(variant["gain"]),
            int(variant["lift"]),
            float(variant["contrast"]),
            float(variant["saturation"]),
            tuple(float(value) for value in variant.get("channel_gains", (1.0, 1.0, 1.0))),
        )
        if forward_shift_px:
            enhancement["forward_shift"] = apply_forward_shift_to_sheet(
                base_target,
                variant["grid"],
                int(variant["frames"]),
                forward_shift_px,
                tuple(int(value) for value in variant["yaw_indices"]) if variant.get("yaw_indices") else None,
                int(variant.get("slope_samples", 1)),
            )
        records["promoted"].append({
            "variant": variant["name"],
            "role": "base",
            "source": str(base_sheet.relative_to(repo)),
            "target": str(base_target.relative_to(repo)),
            "dimensions": validate_dimensions(base_target, variant["grid"]),
            "enhancement": enhancement,
        })

        for role, (source, target) in copies.items():
            copy_sheet(source, target)
            record = {
                "variant": variant["name"],
                "role": role,
                "source": str(source.relative_to(repo)),
                "target": str(target.relative_to(repo)),
                "dimensions": validate_dimensions(target, variant["grid"]),
            }
            if forward_shift_px:
                record["forward_shift"] = apply_forward_shift_to_sheet(
                    target,
                    variant["grid"],
                    int(variant["frames"]),
                    forward_shift_px,
                    tuple(int(value) for value in variant["yaw_indices"]) if variant.get("yaw_indices") else None,
                    int(variant.get("slope_samples", 1)),
                )
            records["promoted"].append({
                **record,
            })

        light_target = target_dir / f"{basename}-lights.png"
        records.setdefault("lights", {})[variant["name"]] = light_sheet_from_base(base_target, light_target)
        records["promoted"].append({
            "variant": variant["name"],
            "role": "accent-light",
            "source": str(base_target.relative_to(repo)),
            "target": str(light_target.relative_to(repo)),
            "dimensions": validate_dimensions(light_target, variant["grid"]),
        })

        mask_target = target_dir / f"{basename}-mask.png"
        records["masks"][variant["name"]] = trim_mask_from_base(base_target, mask_target)
        records["promoted"].append({
            "variant": variant["name"],
            "role": "trim-mask",
            "source": str(base_target.relative_to(repo)),
            "target": str(mask_target.relative_to(repo)),
            "dimensions": validate_dimensions(mask_target, variant["grid"]),
        })

        if variant.get("sloped_stripes"):
            reverse_slope_samples = bool(variant.get("reverse_slope_samples", False))
            reverse_slope_stripes = tuple(int(value) for value in variant.get("reverse_slope_stripes", ()))
            target_slope_deltas = {
                int(key): (int(value[0]), int(value[1]))
                for key, value in variant.get("target_slope_deltas_px", {}).items()
            }
            slope_drift_corrections = compute_slope_drift_corrections(
                base_target,
                int(variant["yaw_directions"]),
                int(variant["slope_samples"]),
                reverse_slope_samples,
                reverse_slope_stripes,
                target_slope_deltas,
            )
            stripe_specs = [
                ("base", base_target, basename),
                ("shadow", target_dir / f"{basename}-shadow.png", f"{basename}-shadow"),
                ("accent-light", light_target, f"{basename}-lights"),
                ("trim-mask", mask_target, f"{basename}-mask"),
            ]
            for role, source_sheet, stripe_basename in stripe_specs:
                stripe_records = write_sloped_stripes(
                    source_sheet,
                    target_dir,
                    stripe_basename,
                    int(variant["sloped_stripes"]),
                    int(variant["yaw_directions"]),
                    int(variant["slope_samples"]),
                    reverse_slope_samples,
                    reverse_slope_stripes,
                    slope_drift_corrections,
                )
                records["promoted"].append({
                    "variant": variant["name"],
                    "role": f"{role}-stripes",
                    "source": str(source_sheet.relative_to(repo)),
                    "targets": [
                        {
                            "target": str(Path(record["target"]).relative_to(repo)),
                            "dimensions": [int(record["width"]), int(record["height"])],
                            "stripe_index": int(record["stripe_index"]),
                            "reversed": bool(record["reversed"]),
                            "slope_drift_correction": record["slope_drift_correction"],
                        }
                        for record in stripe_records
                    ],
                    "stripe_layout": {
                        "line_length": 4,
                        "lines_per_file": int(variant["slope_samples"]),
                        "reverse_slope_samples": reverse_slope_samples,
                        "reverse_slope_stripes": [
                            int(value)
                            for value in reverse_slope_stripes
                        ],
                        "target_slope_deltas_px": {
                            str(key): [value[0], value[1]]
                            for key, value in sorted(target_slope_deltas.items())
                        },
                        "slope_drift_corrections": {
                            str(key): [round(value[0], 3), round(value[1], 3)]
                            for key, value in sorted(slope_drift_corrections.items())
                        },
                    },
                })

        write_icon_sources(repo, variant, records, base_target)

    write_gallery(repo, records)
    manifest = repo / args.manifest
    manifest.parent.mkdir(parents=True, exist_ok=True)
    manifest.write_text(json.dumps(records, indent=2), encoding="utf-8")
    print(f"promoted_assets_manifest={manifest}")
    print(f"gallery={repo / records['gallery']}")


if __name__ == "__main__":
    main()
