#!/usr/bin/env python3
"""Generate ESIR nuclear train item and technology icons from Spritter sheets."""

from __future__ import annotations

import argparse
import json
import math
import re
import shutil
import subprocess
import sys
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageEnhance, ImageFilter, ImageStat


FRAME_INDEX = 32
ITEM_CANVAS_SIZE = 512
TECH_CANVAS_SIZE = 512

WARM_GOLD = (255, 208, 82)


TRAINS = [
    {
        "key": "nuclear-locomotive",
        "label": "Goliath",
        "entity_dir": "exotic-space-industries-remembrance-graphics-4/graphics/entities/nuclear-locomotive",
        "item_icon": "exotic-space-industries-remembrance-graphics-4/graphics/items/nuclear-locomotive.png",
        "tech_icon": "exotic-space-industries-remembrance-graphics-4/graphics/techs/nuclear-locomotive.png",
        "source_name": "nuclear-locomotive",
        "icon_frame": 160,
        "theme": "nuclear",
        "brightness": 1.08,
        "contrast": 1.08,
        "saturation": 1.03,
        "glow_alpha": 1.35,
        "tech_fit": 452,
        "item_fit": 448,
    },
    {
        "key": "advanced-cargo-wagon",
        "label": "Black Ark",
        "entity_dir": "exotic-space-industries-remembrance-graphics-4/graphics/entities/advanced-cargo-wagon",
        "item_icon": "exotic-space-industries-remembrance-graphics-4/graphics/items/advanced-cargo-wagon.png",
        "tech_icon": "exotic-space-industries-remembrance-graphics-4/graphics/techs/advanced-cargo-wagon.png",
        "source_name": "advanced-cargo-wagon",
        "icon_frame": 32,
        "theme": "carbon-fiber",
        "brightness": 1.07,
        "contrast": 1.08,
        "saturation": 1.04,
        "mask_alpha": 0.78,
        "glow_alpha": 1.15,
        "tech_fit": 452,
        "item_fit": 448,
    },
    {
        "key": "advanced-fluid-wagon",
        "label": "Black Grail",
        "entity_dir": "exotic-space-industries-remembrance-graphics-4/graphics/entities/advanced-fluid-wagon",
        "item_icon": "exotic-space-industries-remembrance-graphics-4/graphics/items/advanced-fluid-wagon.png",
        "tech_icon": "exotic-space-industries-remembrance-graphics-4/graphics/techs/advanced-fluid-wagon.png",
        "source_name": "advanced-fluid-wagon",
        "icon_frame": 32,
        "theme": "carbon-fiber",
        "brightness": 1.07,
        "contrast": 1.08,
        "saturation": 1.04,
        "mask_alpha": 0.78,
        "glow_alpha": 1.15,
        "tech_fit": 452,
        "item_fit": 448,
    },
]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Build Goliath, Black Ark, and Black Grail item/tech icons from current Spritter body sheets."
    )
    parser.add_argument("--repo", default=".", help="Repository root. Defaults to current directory.")
    parser.add_argument(
        "--frame",
        type=int,
        default=None,
        help="Optional body frame index override for every train. Defaults to each train's icon_frame.",
    )
    parser.add_argument(
        "--output-dir",
        default="output/meshy/nuclear-trains/icons",
        help="Scratch output directory for source images and previews.",
    )
    parser.add_argument(
        "--skip-item-helper",
        action="store_true",
        help="Write sources and tech icons only; do not rebuild item mip strips.",
    )
    parser.add_argument(
        "--train",
        choices=sorted(str(train["key"]) for train in TRAINS),
        action="append",
        help="Limit icon generation to one or more trains. Defaults to every train.",
    )
    return parser.parse_args()


def parse_lua_number(raw: str) -> float:
    raw = raw.strip().rstrip(",")
    if "/" in raw:
        left, right = raw.split("/", 1)
        return float(left.strip()) / float(right.strip())
    return float(raw)


def parse_spritter_metadata(path: Path) -> dict[str, int | float]:
    text = path.read_text(encoding="utf-8")
    metadata: dict[str, int | float] = {}
    for key in ("file_count", "height", "line_length", "lines_per_file", "scale", "sprite_count", "width"):
        match = re.search(rf'\["{re.escape(key)}"\]\s*=\s*([^,\n]+)', text)
        if not match:
            raise ValueError(f"{path}: missing Spritter metadata field {key}")
        value = parse_lua_number(match.group(1))
        metadata[key] = int(value) if value.is_integer() else value
    return metadata


def frame_location(metadata: dict[str, int | float], frame_index: int) -> tuple[int, int, int]:
    line_length = int(metadata["line_length"])
    lines_per_file = int(metadata["lines_per_file"])
    frames_per_file = line_length * lines_per_file
    sprite_count = int(metadata["sprite_count"])
    if frame_index < 0 or frame_index >= sprite_count:
        raise ValueError(f"Frame {frame_index} is outside sprite count {sprite_count}")
    file_index = frame_index // frames_per_file
    local_index = frame_index % frames_per_file
    col = local_index % line_length
    row = local_index // line_length
    return file_index, col, row


def crop_layer(sheet_path: Path, metadata: dict[str, int | float], frame_index: int) -> Image.Image:
    file_index, col, row = frame_location(metadata, frame_index)
    expected_name = sheet_path.with_name(f"{sheet_path.stem}-{file_index}{sheet_path.suffix}")
    if not expected_name.exists():
        raise FileNotFoundError(expected_name)
    width = int(metadata["width"])
    height = int(metadata["height"])
    with Image.open(expected_name).convert("RGBA") as sheet:
        box = (col * width, row * height, (col + 1) * width, (row + 1) * height)
        return sheet.crop(box)


def transparent_like(image: Image.Image) -> Image.Image:
    return Image.new("RGBA", image.size, (0, 0, 0, 0))


def alpha_bbox(image: Image.Image) -> tuple[int, int, int, int]:
    bbox = image.getchannel("A").getbbox()
    if bbox is None:
        raise ValueError("Icon source frame is fully transparent.")
    return bbox


def bbox_union(images: list[Image.Image], pad: int = 8) -> tuple[int, int, int, int]:
    combined = Image.new("L", images[0].size, 0)
    for image in images:
        combined = ImageChops.lighter(combined, image.getchannel("A"))
    bbox = combined.getbbox()
    if bbox is None:
        raise ValueError("Icon source layers are fully transparent.")
    left, top, right, bottom = bbox
    return (
        max(0, left - pad),
        max(0, top - pad),
        min(images[0].width, right + pad),
        min(images[0].height, bottom + pad),
    )


def crop_to_bbox(image: Image.Image, bbox: tuple[int, int, int, int]) -> Image.Image:
    return image.crop(bbox).convert("RGBA")


def enhance_base(image: Image.Image, brightness: float, contrast: float, saturation: float) -> Image.Image:
    alpha = image.getchannel("A")
    rgb = image.convert("RGB")
    rgb = ImageEnhance.Brightness(rgb).enhance(brightness)
    rgb = ImageEnhance.Contrast(rgb).enhance(contrast)
    rgb = ImageEnhance.Color(rgb).enhance(saturation)
    out = rgb.convert("RGBA")
    out.putalpha(alpha)
    return out


def scale_alpha(image: Image.Image, factor: float, cap: int = 255) -> Image.Image:
    if factor == 1.0 and cap == 255:
        return image
    alpha = image.getchannel("A").point(lambda value: min(cap, int(value * factor)))
    out = image.copy()
    out.putalpha(alpha)
    return out


def colorize_mask(mask: Image.Image, color: tuple[int, int, int], alpha_factor: float) -> Image.Image:
    alpha = mask.getchannel("A").point(lambda value: min(180, int(value * alpha_factor)))
    colored = Image.new("RGBA", mask.size, (*color, 0))
    colored.putalpha(alpha)
    return colored


def fit_layers(
    layers: dict[str, Image.Image],
    canvas_size: int,
    fit_size: int,
    vertical_shift: int = 0,
) -> dict[str, Image.Image]:
    base = layers["base"]
    scale = min(fit_size / max(1, base.width), fit_size / max(1, base.height))
    size = (max(1, round(base.width * scale)), max(1, round(base.height * scale)))
    origin = ((canvas_size - size[0]) // 2, (canvas_size - size[1]) // 2 + vertical_shift)

    fitted: dict[str, Image.Image] = {}
    for name, image in layers.items():
        resized = image.resize(size, Image.Resampling.LANCZOS)
        canvas = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
        canvas.alpha_composite(resized, origin)
        fitted[name] = canvas
    return fitted


def compose_train_icon(
    fitted: dict[str, Image.Image],
    *,
    shadow_alpha: int,
    shadow_radius: float,
    shadow_offset: tuple[int, int],
    include_mask: bool,
) -> Image.Image:
    base = fitted["base"]
    shadow_mask = base.getchannel("A").filter(ImageFilter.GaussianBlur(shadow_radius))
    shadow = Image.new("RGBA", base.size, (0, 0, 0, shadow_alpha))
    shadow.putalpha(shadow_mask.point(lambda value: min(shadow_alpha, int(value * 0.62))))

    canvas = Image.new("RGBA", base.size, (0, 0, 0, 0))
    canvas.alpha_composite(shadow, shadow_offset)
    canvas.alpha_composite(base)

    if include_mask and "mask" in fitted:
        canvas.alpha_composite(fitted["mask"])
    if "glow_halo" in fitted:
        canvas.alpha_composite(fitted["glow_halo"])
    if "glow" in fitted:
        canvas.alpha_composite(fitted["glow"])
    return canvas


def principal_axis(image: Image.Image) -> tuple[float, float]:
    alpha = image.getchannel("A")
    bbox = alpha.getbbox()
    if bbox is None:
        return (1.0, -0.35)
    pixels = alpha.load()
    total = 0.0
    sum_x = 0.0
    sum_y = 0.0
    for y in range(bbox[1], bbox[3], 3):
        for x in range(bbox[0], bbox[2], 3):
            weight = pixels[x, y]
            if weight < 16:
                continue
            total += weight
            sum_x += x * weight
            sum_y += y * weight
    if total <= 0:
        return (1.0, -0.35)
    mean_x = sum_x / total
    mean_y = sum_y / total

    cov_xx = 0.0
    cov_xy = 0.0
    cov_yy = 0.0
    for y in range(bbox[1], bbox[3], 3):
        for x in range(bbox[0], bbox[2], 3):
            weight = pixels[x, y]
            if weight < 16:
                continue
            dx = x - mean_x
            dy = y - mean_y
            cov_xx += weight * dx * dx
            cov_xy += weight * dx * dy
            cov_yy += weight * dy * dy

    angle = 0.5 * math.atan2(2.0 * cov_xy, cov_xx - cov_yy)
    ux = math.cos(angle)
    uy = math.sin(angle)
    if ux < 0:
        ux = -ux
        uy = -uy
    length = math.hypot(ux, uy) or 1.0
    return (ux / length, uy / length)


def draw_rail_scene(size: int, axis: tuple[float, float], subject_alpha: Image.Image) -> Image.Image:
    rail = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(rail, "RGBA")
    ux, uy = axis
    nx, ny = -uy, ux

    bbox = subject_alpha.getbbox() or (72, 112, size - 72, size - 96)
    center_x = (bbox[0] + bbox[2]) / 2 + nx * 8
    center_y = (bbox[1] + bbox[3]) / 2 + ny * 26
    rail_spacing = 42
    rail_length = 620

    for tick in range(-10, 11):
        t = tick * 34
        cx = center_x + ux * t
        cy = center_y + uy * t
        half = 34
        draw.line(
            (cx - nx * half, cy - ny * half, cx + nx * half, cy + ny * half),
            fill=(116, 93, 54, 72),
            width=7,
        )
        draw.line(
            (cx - nx * half, cy - ny * half, cx + nx * half, cy + ny * half),
            fill=(202, 172, 92, 48),
            width=3,
        )

    for side in (-0.5, 0.5):
        ox = nx * rail_spacing * side
        oy = ny * rail_spacing * side
        x1 = center_x - ux * rail_length / 2 + ox
        y1 = center_y - uy * rail_length / 2 + oy
        x2 = center_x + ux * rail_length / 2 + ox
        y2 = center_y + uy * rail_length / 2 + oy
        draw.line((x1, y1, x2, y2), fill=(36, 39, 42, 132), width=9)
        draw.line((x1, y1, x2, y2), fill=(188, 198, 192, 118), width=4)
        draw.line((x1 - nx * 2, y1 - ny * 2, x2 - nx * 2, y2 - ny * 2), fill=(250, 244, 216, 48), width=1)

    return rail.filter(ImageFilter.GaussianBlur(0.25))


def draw_nuclear_theme(size: int, subject_alpha: Image.Image) -> Image.Image:
    theme = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(theme, "RGBA")
    bbox = subject_alpha.getbbox() or (88, 110, size - 88, size - 110)
    cx = int((bbox[0] + bbox[2]) / 2 - 104)
    cy = int((bbox[1] + bbox[3]) / 2 + 46)

    for radius, alpha in [(214, 10), (150, 18), (84, 30), (38, 42)]:
        box = (cx - radius // 2, cy - radius // 2, cx + radius // 2, cy + radius // 2)
        draw.ellipse(box, fill=(52, 220, 180, alpha))

    band = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    bdraw = ImageDraw.Draw(band, "RGBA")
    bdraw.line((bbox[0] - 70, bbox[3] - 38, bbox[2] + 42, bbox[1] + 72), fill=(96, 244, 196, 22), width=16)
    bdraw.line((bbox[0] - 52, bbox[3] - 10, bbox[2] + 66, bbox[1] + 104), fill=(36, 186, 150, 14), width=10)
    theme.alpha_composite(band.filter(ImageFilter.GaussianBlur(5.0)))
    return theme.filter(ImageFilter.GaussianBlur(2.4))


def draw_carbon_fiber_theme(size: int, subject_alpha: Image.Image) -> Image.Image:
    weave = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(weave, "RGBA")

    for offset in range(-size, size * 2, 22):
        color = (92, 96, 92, 20) if (offset // 22) % 2 == 0 else (16, 18, 19, 24)
        draw.line((offset, size, offset + size, 0), fill=color, width=9)
    for offset in range(-size, size * 2, 22):
        color = (145, 150, 142, 13) if (offset // 22) % 2 == 0 else (10, 12, 13, 18)
        draw.line((offset, 0, offset + size, size), fill=color, width=6)

    local_mask = subject_alpha.filter(ImageFilter.MaxFilter(45)).filter(ImageFilter.GaussianBlur(24))
    local_mask = local_mask.point(lambda value: min(118, int(value * 0.42)))
    weave.putalpha(ImageChops.multiply(weave.getchannel("A"), local_mask))

    sheen = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    sheen_draw = ImageDraw.Draw(sheen, "RGBA")
    bbox = subject_alpha.getbbox() or (70, 105, size - 70, size - 105)
    left = max(0, bbox[0] - 24)
    top = max(0, bbox[1] - 18)
    right = min(size, bbox[2] + 24)
    bottom = min(size, bbox[3] + 28)
    sheen_draw.line((left - 18, top + 38, right + 18, bottom - 76), fill=(220, 230, 218, 18), width=10)
    sheen_draw.line((left + 20, top + 78, right + 36, bottom - 34), fill=(116, 152, 142, 14), width=6)
    sheen.putalpha(ImageChops.multiply(sheen.getchannel("A"), local_mask))
    weave.alpha_composite(sheen.filter(ImageFilter.GaussianBlur(2.0)))
    return weave


def draw_theme_scene(theme_name: str, size: int, subject_alpha: Image.Image) -> Image.Image:
    if theme_name == "nuclear":
        return draw_nuclear_theme(size, subject_alpha)
    if theme_name == "carbon-fiber":
        return draw_carbon_fiber_theme(size, subject_alpha)
    return Image.new("RGBA", (size, size), (0, 0, 0, 0))


def build_layer_set(
    repo: Path,
    train: dict[str, object],
    frame_index: int,
) -> tuple[dict[str, Image.Image], dict[str, object]]:
    entity_dir = repo / str(train["entity_dir"])
    metadata = parse_spritter_metadata(entity_dir / "body.lua")
    base = crop_layer(entity_dir / "body.png", metadata, frame_index)

    optional_layers: dict[str, Image.Image] = {}
    for role in ("mask", "glow"):
        layer_metadata_path = entity_dir / f"body-{role}.lua"
        if not layer_metadata_path.exists():
            continue
        layer_metadata = parse_spritter_metadata(layer_metadata_path)
        optional_layers[role] = crop_layer(entity_dir / f"body-{role}.png", layer_metadata, frame_index)

    bbox_layers = [base] + list(optional_layers.values())
    bbox = bbox_union(bbox_layers, pad=10)

    layers = {
        "base": enhance_base(
            crop_to_bbox(base, bbox),
            float(train["brightness"]),
            float(train["contrast"]),
            float(train["saturation"]),
        )
    }
    if "mask" in optional_layers:
        mask = crop_to_bbox(optional_layers["mask"], bbox)
        layers["mask"] = colorize_mask(mask, WARM_GOLD, float(train.get("mask_alpha", 0.75)))
    if "glow" in optional_layers:
        glow = scale_alpha(crop_to_bbox(optional_layers["glow"], bbox), float(train.get("glow_alpha", 1.0)), 190)
        halo_alpha = glow.getchannel("A").filter(ImageFilter.GaussianBlur(5)).point(lambda value: min(92, int(value * 0.55)))
        halo_rgb = glow.convert("RGB").filter(ImageFilter.GaussianBlur(3)).convert("RGBA")
        halo_rgb.putalpha(halo_alpha)
        layers["glow_halo"] = halo_rgb
        layers["glow"] = glow

    info = {
        "metadata": metadata,
        "frame": frame_index,
        "bbox": list(bbox),
        "source_file": frame_location(metadata, frame_index)[0],
        "source_cell": list(frame_location(metadata, frame_index)[1:]),
    }
    return layers, info


def ensure_parent(path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)


def backup_existing(path: Path, backup_dir: Path) -> Path | None:
    if not path.exists():
        return None
    backup_dir.mkdir(parents=True, exist_ok=True)
    backup = backup_dir / f"{path.parent.name}-{path.stem}-previous{path.suffix}"
    shutil.copy2(path, backup)
    return backup


def run_item_helper(repo: Path, source: Path, output: Path, preview: Path) -> None:
    helper = repo / ".codex/skills/esir-item-icon-prep/scripts/build_factorio_item_icon.py"
    if not helper.exists():
        raise FileNotFoundError(helper)
    subprocess.run(
        [
            sys.executable,
            str(helper),
            "--source",
            str(source),
            "--output",
            str(output),
            "--preview",
            str(preview),
            "--fit-size",
            "122",
        ],
        cwd=repo,
        check=True,
    )


def validate_png(path: Path, expected_size: tuple[int, int]) -> dict[str, object]:
    with Image.open(path).convert("RGBA") as image:
        if image.size != expected_size:
            raise ValueError(f"{path} is {image.size}, expected {expected_size}")
        bbox = image.getchannel("A").getbbox()
        if bbox is None:
            raise ValueError(f"{path} has no visible alpha")
        alpha_stat = ImageStat.Stat(image.getchannel("A"))
        return {
            "size": list(image.size),
            "alpha_bbox": list(bbox),
            "alpha_mean": round(alpha_stat.mean[0], 3),
        }


def write_contact_sheet(records: list[dict[str, object]], target: Path) -> None:
    cell_w = 260
    cell_h = 300
    sheet = Image.new("RGBA", (cell_w * 4, cell_h * len(records)), (22, 24, 26, 255))
    draw = ImageDraw.Draw(sheet)
    labels = ["source", "item preview", "item strip", "tech"]
    for row, record in enumerate(records):
        y = row * cell_h
        draw.text((12, y + 10), str(record["label"]), fill=(226, 233, 226, 255))
        paths = [
            Path(str(record["source"])),
            Path(str(record["item_preview"])),
            Path(str(record["item_icon"])),
            Path(str(record["tech_icon"])),
        ]
        for col, path in enumerate(paths):
            draw.text((col * cell_w + 12, y + 34), labels[col], fill=(172, 184, 178, 255))
            if not path.exists():
                continue
            with Image.open(path).convert("RGBA") as image:
                image.thumbnail((220, 220), Image.Resampling.LANCZOS)
                px = col * cell_w + (cell_w - image.width) // 2
                py = y + 62 + (220 - image.height) // 2
                checker = Image.new("RGBA", image.size, (42, 45, 46, 255))
                sheet.alpha_composite(checker, (px, py))
                sheet.alpha_composite(image, (px, py))
    ensure_parent(target)
    sheet.save(target)


def build_icons(
    repo: Path,
    output_dir: Path,
    frame_override: int | None,
    skip_item_helper: bool,
    train_filter: set[str] | None = None,
) -> dict[str, object]:
    records: list[dict[str, object]] = []
    backup_dir = repo / "tmp/nuclear-train-icon-backups"

    for train in TRAINS:
        if train_filter and str(train["key"]) not in train_filter:
            continue
        frame_index = int(frame_override if frame_override is not None else train.get("icon_frame", FRAME_INDEX))
        layers, info = build_layer_set(repo, train, frame_index)

        item_layers = fit_layers(
            layers,
            ITEM_CANVAS_SIZE,
            int(train["item_fit"]),
            vertical_shift=2,
        )
        item_source = compose_train_icon(
            item_layers,
            shadow_alpha=92,
            shadow_radius=6.0,
            shadow_offset=(7, 10),
            include_mask=True,
        )
        source_path = output_dir / f"{train['source_name']}-source.png"
        ensure_parent(source_path)
        item_source.save(source_path)

        tech_layers = fit_layers(
            layers,
            TECH_CANVAS_SIZE,
            int(train["tech_fit"]),
            vertical_shift=-8,
        )
        tech_subject = compose_train_icon(
            tech_layers,
            shadow_alpha=118,
            shadow_radius=9.0,
            shadow_offset=(9, 14),
            include_mask=True,
        )
        tech_icon = Image.new("RGBA", (TECH_CANVAS_SIZE, TECH_CANVAS_SIZE), (0, 0, 0, 0))
        tech_icon.alpha_composite(tech_subject)

        item_icon = repo / str(train["item_icon"])
        tech_path = repo / str(train["tech_icon"])
        ensure_parent(item_icon)
        ensure_parent(tech_path)
        item_backup = backup_existing(item_icon, backup_dir)
        tech_backup = backup_existing(tech_path, backup_dir)
        tech_icon.save(tech_path)

        item_preview = output_dir / f"{train['source_name']}-item-preview-128.png"
        if not skip_item_helper:
            run_item_helper(repo, source_path, item_icon, item_preview)
        else:
            item_source.resize((128, 128), Image.Resampling.LANCZOS).save(item_preview)

        record = {
            "key": train["key"],
            "label": train["label"],
            "source": str(source_path),
            "item_preview": str(item_preview),
            "item_icon": str(item_icon),
            "tech_icon": str(tech_path),
            "frame_info": info,
            "backups": {
                "item": str(item_backup) if item_backup else None,
                "tech": str(tech_backup) if tech_backup else None,
            },
            "validation": {
                "item": validate_png(item_icon, (224, 128)),
                "tech": validate_png(tech_path, (512, 512)),
            },
        }
        records.append(record)

    contact_sheet = output_dir / "nuclear-train-icon-contact-sheet.png"
    write_contact_sheet(records, contact_sheet)
    return {
        "frame_override": frame_override,
        "records": records,
        "contact_sheet": str(contact_sheet),
    }


def main() -> None:
    args = parse_args()
    repo = Path(args.repo).resolve()
    output_dir = (repo / args.output_dir).resolve()
    manifest = build_icons(repo, output_dir, args.frame, args.skip_item_helper, set(args.train) if args.train else None)
    manifest_path = output_dir / "nuclear-train-icon-manifest.json"
    ensure_parent(manifest_path)
    manifest_path.write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    print(json.dumps(manifest, indent=2))
    print(f"manifest={manifest_path}")


if __name__ == "__main__":
    main()
