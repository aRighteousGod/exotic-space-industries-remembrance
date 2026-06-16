#!/usr/bin/env python3
"""Validate ESIR Spritter rolling-stock sheets after template rendering."""

from __future__ import annotations

import argparse
import hashlib
import re
from pathlib import Path

from PIL import Image


EXPECTED = {
    "body": {
        "file_count": 8,
        "line_length": 4,
        "lines_per_file": 8,
        "sprite_count": 256,
    },
    "sloped": {
        "file_count": 8,
        "line_length": 4,
        "lines_per_file": 5,
        "sprite_count": 160,
    },
}

TARGETS = {
    "nuclear-locomotive": "exotic-space-industries-remembrance-graphics-4/graphics/entities/nuclear-locomotive",
    "advanced-cargo-wagon": "exotic-space-industries-remembrance-graphics-4/graphics/entities/advanced-cargo-wagon",
    "advanced-fluid-wagon": "exotic-space-industries-remembrance-graphics-4/graphics/entities/advanced-fluid-wagon",
}

RAW_RENDER_TARGETS = {
    "nuclear-locomotive": "goliath",
    "advanced-cargo-wagon": "black-ark-cargo-wagon",
    "advanced-fluid-wagon": "black-grail-fluid-wagon",
}

DERIVED_EXPECTED = {
    "nuclear-locomotive": {
        "body-glow": {
            "base": "body",
            "role": "glow",
            "coverage": (0.0005, 0.03),
            "max_low_sat_fraction": 0.35,
        },
        "sloped-glow": {
            "base": "sloped",
            "role": "glow",
            "coverage": (0.0005, 0.03),
            "max_low_sat_fraction": 0.35,
        },
    },
    "advanced-cargo-wagon": {
        "body-mask": {
            "base": "body",
            "role": "mask",
            "coverage": (0.0005, 0.025),
            "max_low_sat_fraction": 0.18,
        },
        "sloped-mask": {
            "base": "sloped",
            "role": "mask",
            "coverage": (0.0005, 0.025),
            "max_low_sat_fraction": 0.18,
        },
        "body-glow": {
            "base": "body",
            "role": "glow",
            "coverage": (0.0001, 0.015),
            "max_low_sat_fraction": 0.35,
        },
        "sloped-glow": {
            "base": "sloped",
            "role": "glow",
            "coverage": (0.0001, 0.015),
            "max_low_sat_fraction": 0.35,
        },
    },
    "advanced-fluid-wagon": {
        "body-mask": {
            "base": "body",
            "role": "mask",
            "coverage": (0.0005, 0.04),
            "max_low_sat_fraction": 0.18,
        },
        "sloped-mask": {
            "base": "sloped",
            "role": "mask",
            "coverage": (0.0005, 0.04),
            "max_low_sat_fraction": 0.18,
        },
        "body-glow": {
            "base": "body",
            "role": "glow",
            "coverage": (0.0001, 0.025),
            "max_low_sat_fraction": 0.35,
        },
        "sloped-glow": {
            "base": "sloped",
            "role": "glow",
            "coverage": (0.0001, 0.025),
            "max_low_sat_fraction": 0.35,
        },
    },
}


def source_hash(target_dir: Path, layer: str, metadata: dict[str, int]) -> str:
    digest = hashlib.sha256()
    digest.update((target_dir / f"{layer}.lua").read_bytes())
    for index in range(metadata["file_count"]):
        digest.update((target_dir / f"{layer}-{index}.png").read_bytes())
    return digest.hexdigest()


def edge_alpha_extrema(alpha: Image.Image, left: int, top: int, right: int, bottom: int) -> tuple[int, int]:
    """Return min/max alpha on the outer edge of a rectangular alpha region."""
    if left >= right or top >= bottom:
        return (0, 0)

    edge_values = []
    edge_values.extend(alpha.crop((left, top, right, top + 1)).getdata())
    edge_values.extend(alpha.crop((left, bottom - 1, right, bottom)).getdata())
    if bottom - top > 2:
        edge_values.extend(alpha.crop((left, top + 1, left + 1, bottom - 1)).getdata())
        edge_values.extend(alpha.crop((right - 1, top + 1, right, bottom - 1)).getdata())
    return (min(edge_values), max(edge_values))


def validate_packed_cell_edges(
    target_dir: Path,
    layer: str,
    metadata: dict[str, int],
    alpha_threshold: int,
) -> tuple[int, int, list[str]]:
    failures: list[str] = []
    worst_alpha = 0
    bad_cells = 0
    cell_width = metadata["width"]
    cell_height = metadata["height"]

    for file_index in range(metadata["file_count"]):
        png = target_dir / f"{layer}-{file_index}.png"
        with Image.open(png).convert("RGBA") as img:
            alpha = img.getchannel("A")
            for row in range(metadata["lines_per_file"]):
                for column in range(metadata["line_length"]):
                    sprite_index = (
                        file_index * metadata["line_length"] * metadata["lines_per_file"]
                        + row * metadata["line_length"]
                        + column
                    )
                    if sprite_index >= metadata["sprite_count"]:
                        continue
                    left = column * cell_width
                    top = row * cell_height
                    right = left + cell_width
                    bottom = top + cell_height
                    _min_alpha, max_alpha = edge_alpha_extrema(alpha, left, top, right, bottom)
                    worst_alpha = max(worst_alpha, max_alpha)
                    if max_alpha >= alpha_threshold:
                        bad_cells += 1
                        if len(failures) < 12:
                            failures.append(f"{png.name}[sprite={sprite_index} max_edge_alpha={max_alpha}]")

    return bad_cells, worst_alpha, failures


def parse_lua_metadata(path: Path) -> dict[str, int]:
    text = path.read_text(encoding="utf-8")
    metadata: dict[str, int] = {}
    for key in ("file_count", "height", "line_length", "lines_per_file", "sprite_count", "width"):
        match = re.search(rf'\["{key}"\]\s*=\s*(\d+)', text)
        if not match:
            raise ValueError(f"{path} is missing metadata key {key}")
        metadata[key] = int(match.group(1))
    return metadata


def metadata_value(path: Path, key: str) -> str:
    text = path.read_text(encoding="utf-8")
    match = re.search(rf'\["{key}"\]\s*=\s*(.+),\s*$', text, flags=re.MULTILINE)
    if not match:
        raise ValueError(f"{path} is missing metadata key {key}")
    return match.group(1).strip()


def metadata_string(path: Path, key: str) -> str:
    text = path.read_text(encoding="utf-8")
    match = re.search(rf'\["{key}"\]\s*=\s*"([^"]+)"', text)
    if not match:
        raise ValueError(f"{path} is missing metadata string {key}")
    return match.group(1)


def pixel_saturation(r: int, g: int, b: int) -> float:
    maximum = max(r, g, b)
    minimum = min(r, g, b)
    if maximum <= 0:
        return 0.0
    return (maximum - minimum) / maximum


def luma_stats(path: Path) -> dict[str, float]:
    with Image.open(path).convert("RGBA") as img:
        pixels = [(r, g, b, a) for r, g, b, a in img.getdata() if a >= 8]
    if not pixels:
        return {"mean_luma": 0.0, "gt220_percent": 0.0, "lt24_percent": 0.0}
    lumas = [0.2126 * r + 0.7152 * g + 0.0722 * b for r, g, b, _ in pixels]
    return {
        "mean_luma": round(sum(lumas) / len(lumas), 3),
        "gt220_percent": round(sum(1 for value in lumas if value > 220) / len(lumas) * 100, 4),
        "lt24_percent": round(sum(1 for value in lumas if value < 24) / len(lumas) * 100, 4),
    }


def validate_derived_pixels(
    target_dir: Path,
    base_layer: str,
    derived_layer: str,
    base_metadata: dict[str, int],
    derived_metadata: dict[str, int],
    low_sat_limit: float,
) -> dict[str, float | int]:
    base_opaque = 0
    derived_pixels = 0
    outside_base = 0
    low_sat_gray = 0
    cell_count = base_metadata["file_count"]

    for index in range(cell_count):
        base_path = target_dir / f"{base_layer}-{index}.png"
        derived_path = target_dir / f"{derived_layer}-{index}.png"
        with Image.open(base_path).convert("RGBA") as base_img, Image.open(derived_path).convert("RGBA") as derived_img:
            if base_img.size != derived_img.size:
                raise ValueError(f"{derived_path}: size={derived_img.size}, expected {base_img.size}")
            for (r, g, b, a), (_, _, _, da) in zip(base_img.getdata(), derived_img.getdata()):
                if a >= 8:
                    base_opaque += 1
                if da < 8:
                    continue
                derived_pixels += 1
                if a < 8:
                    outside_base += 1
                    continue
                if pixel_saturation(r, g, b) < 0.18 and (0.2126 * r + 0.7152 * g + 0.0722 * b) > 76:
                    low_sat_gray += 1

    coverage = derived_pixels / base_opaque if base_opaque else 0
    low_sat_fraction = low_sat_gray / derived_pixels if derived_pixels else 0
    if outside_base:
        raise ValueError(f"{target_dir.name}/{derived_layer}: {outside_base} alpha pixels sit outside base alpha")
    if low_sat_fraction > low_sat_limit:
        raise ValueError(
            f"{target_dir.name}/{derived_layer}: low-saturation bright source fraction "
            f"{low_sat_fraction:.4f} exceeds {low_sat_limit:.4f}"
        )
    return {
        "base_opaque": base_opaque,
        "derived_pixels": derived_pixels,
        "coverage": round(coverage, 6),
        "low_sat_fraction": round(low_sat_fraction, 6),
    }


def validate_raw_frames(render_dir: Path, layer: str, alpha_threshold: int) -> str:
    if layer == "body":
        start, end = 0, 255
    else:
        start, end = 256, 415

    layer_dir = render_dir / layer
    if not layer_dir.exists():
        raise FileNotFoundError(layer_dir)

    failures: list[str] = []
    worst_alpha = 0
    expected_size: tuple[int, int] | None = None
    for frame in range(start, end + 1):
        png = layer_dir / f"{frame:04d}.png"
        if not png.exists():
            raise FileNotFoundError(png)
        with Image.open(png).convert("RGBA") as img:
            if expected_size is None:
                expected_size = img.size
            elif img.size != expected_size:
                raise ValueError(f"{png}: size={img.size}, expected={expected_size}")
            alpha = img.getchannel("A")
            _min_alpha, max_alpha = edge_alpha_extrema(alpha, 0, 0, img.width, img.height)
            worst_alpha = max(worst_alpha, max_alpha)
            if max_alpha >= alpha_threshold:
                if len(failures) < 12:
                    failures.append(f"{png.name} max_edge_alpha={max_alpha}")

    if failures:
        raise ValueError(
            f"{render_dir.name}/{layer}: raw render frames touch an image edge with alpha >= {alpha_threshold}; "
            f"examples: {', '.join(failures)}"
        )
    return f"{render_dir.name}/{layer}: raw frames {start}..{end}, size={expected_size}, max edge alpha={worst_alpha}"


def validate_layer(
    target_dir: Path,
    layer: str,
    alpha_threshold: int,
    check_packed_cell_edges: bool,
) -> list[str]:
    messages: list[str] = []
    metadata_path = target_dir / f"{layer}.lua"
    if not metadata_path.exists():
        raise FileNotFoundError(metadata_path)

    metadata = parse_lua_metadata(metadata_path)
    expected = EXPECTED[layer]
    for key, value in expected.items():
        if metadata[key] != value:
            raise ValueError(f"{metadata_path}: {key}={metadata[key]}, expected {value}")

    expected_size = (
        metadata["width"] * metadata["line_length"],
        metadata["height"] * metadata["lines_per_file"],
    )
    for index in range(metadata["file_count"]):
        png = target_dir / f"{layer}-{index}.png"
        if not png.exists():
            raise FileNotFoundError(png)
        with Image.open(png) as img:
            size = img.size
        if size != expected_size:
            raise ValueError(f"{png}: size={size}, expected={expected_size}")

    edge_summary = "packed cell edge check skipped"
    if check_packed_cell_edges:
        bad_cells, worst_alpha, failures = validate_packed_cell_edges(target_dir, layer, metadata, alpha_threshold)
        edge_summary = f"max packed cell edge alpha={worst_alpha}"
        if bad_cells:
            raise ValueError(
                f"{target_dir.name}/{layer}: {bad_cells} packed sprite cells touch an image edge "
                f"with alpha >= {alpha_threshold}; examples: {', '.join(failures)}"
            )

    stats = luma_stats(target_dir / f"{layer}-0.png")
    messages.append(
        f"{target_dir.name}/{layer}: {metadata['file_count']} files, "
        f"{metadata['width']}x{metadata['height']} frames, "
        f"{metadata['sprite_count']} sprites, sheet {expected_size[0]}x{expected_size[1]}, "
        f"{edge_summary}, "
        f"luma mean={stats['mean_luma']} >220={stats['gt220_percent']}% <24={stats['lt24_percent']}%"
    )
    return messages


def validate_derived_layer(
    target_dir: Path,
    derived_layer: str,
    options: dict,
    alpha_threshold: int,
    check_packed_cell_edges: bool,
) -> list[str]:
    messages: list[str] = []
    base_layer = options["base"]
    role = options["role"]
    metadata_path = target_dir / f"{derived_layer}.lua"
    base_metadata_path = target_dir / f"{base_layer}.lua"
    if not metadata_path.exists():
        raise FileNotFoundError(metadata_path)

    base_metadata = parse_lua_metadata(base_metadata_path)
    metadata = parse_lua_metadata(metadata_path)
    for key in ("file_count", "height", "line_length", "lines_per_file", "sprite_count", "width"):
        if metadata[key] != base_metadata[key]:
            raise ValueError(
                f"{metadata_path}: {key}={metadata[key]}, expected {base_metadata[key]} from {base_metadata_path.name}"
            )
    for key in ("spritter", "scale", "shift"):
        if metadata_value(metadata_path, key) != metadata_value(base_metadata_path, key):
            raise ValueError(f"{metadata_path}: {key} does not match {base_metadata_path.name}")

    if metadata_string(metadata_path, "derived_role") != role:
        raise ValueError(f"{metadata_path}: derived_role is not {role}")
    if metadata_string(metadata_path, "source_layer") != base_layer:
        raise ValueError(f"{metadata_path}: source_layer is not {base_layer}")
    expected_hash = source_hash(target_dir, base_layer, base_metadata)
    actual_hash = metadata_string(metadata_path, "source_sha256")
    if actual_hash != expected_hash:
        raise ValueError(f"{metadata_path}: source_sha256 is stale")

    expected_size = (
        metadata["width"] * metadata["line_length"],
        metadata["height"] * metadata["lines_per_file"],
    )
    for index in range(metadata["file_count"]):
        png = target_dir / f"{derived_layer}-{index}.png"
        if not png.exists():
            raise FileNotFoundError(png)
        with Image.open(png) as img:
            size = img.size
        if size != expected_size:
            raise ValueError(f"{png}: size={size}, expected={expected_size}")

    edge_summary = "packed cell edge check skipped"
    if check_packed_cell_edges:
        bad_cells, worst_alpha, failures = validate_packed_cell_edges(target_dir, derived_layer, metadata, alpha_threshold)
        edge_summary = f"max packed cell edge alpha={worst_alpha}"
        if bad_cells:
            raise ValueError(
                f"{target_dir.name}/{derived_layer}: {bad_cells} packed sprite cells touch an image edge "
                f"with alpha >= {alpha_threshold}; examples: {', '.join(failures)}"
            )

    stats = validate_derived_pixels(
        target_dir,
        base_layer,
        derived_layer,
        base_metadata,
        metadata,
        float(options["max_low_sat_fraction"]),
    )
    min_coverage, max_coverage = options["coverage"]
    if not (min_coverage <= stats["coverage"] <= max_coverage):
        raise ValueError(
            f"{target_dir.name}/{derived_layer}: coverage={stats['coverage']} outside "
            f"{min_coverage}..{max_coverage}"
        )

    messages.append(
        f"{target_dir.name}/{derived_layer}: role={role}, source={base_layer}, "
        f"coverage={stats['coverage']}, low_sat={stats['low_sat_fraction']}, {edge_summary}"
    )
    return messages


def validate_prototype_flags(repo: Path) -> str:
    prototype = repo / "exotic-space-industries-remembrance/prototypes/computer-age/nuclear-trains.lua"
    text = prototype.read_text(encoding="utf-8")
    required = (
        'nuclear_train_glow_layers',
        'advanced_cargo_wagon_layers',
        'advanced_fluid_wagon_layers',
        'goliath_hid_front_light',
        'hid-light-cone.png',
        'width = 400',
        'height = 1013',
        'source_orientation_offset',
        'front_light_pictures = nil',
        'suffix = "glow"',
        'suffix = "mask"',
        'path .. "-" .. layer_spec.suffix',
        'draw_as_glow = true',
        'draw_as_light = true',
        'apply_runtime_tint = true',
        'flags = {"mask"}',
    )
    missing = [fragment for fragment in required if fragment not in text]
    if missing:
        raise ValueError(f"{prototype}: missing expected layered train graphics fragments: {', '.join(missing)}")
    return "prototype layer flags: ok"


def validate_hid_cone(target_dir: Path) -> str:
    path = target_dir / "hid-light-cone.png"
    if not path.exists():
        raise FileNotFoundError(path)
    with Image.open(path).convert("RGBA") as img:
        if img.size != (400, 1013):
            raise ValueError(f"{path}: size={img.size}, expected (400, 1013)")
        alpha = img.getchannel("A")
        bbox = alpha.getbbox()
        if bbox is None:
            raise ValueError(f"{path}: no visible alpha")
        left, top, right, bottom = bbox
        if not (24 <= left <= 34 and 366 <= right <= 376 and 58 <= top <= 72 and 810 <= bottom <= 832):
            raise ValueError(f"{path}: alpha bbox={bbox}, expected roughly (28,65,372,822)")
        alpha_pixels = [value for value in alpha.getdata() if value >= 8]
        if not alpha_pixels:
            raise ValueError(f"{path}: no visible alpha")
        meaningful_bbox = alpha.point(lambda value: 255 if value >= 8 else 0).getbbox()
        if meaningful_bbox is None:
            raise ValueError(f"{path}: no meaningful alpha")
        meaningful_left, meaningful_top, meaningful_right, meaningful_bottom = meaningful_bbox
        if not (
            48 <= meaningful_left <= 58
            and 342 <= meaningful_right <= 352
            and 72 <= meaningful_top <= 82
            and 748 <= meaningful_bottom <= 772
        ):
            raise ValueError(
                f"{path}: meaningful alpha bbox={meaningful_bbox}, expected roughly (53,76,347,760)"
            )
        max_alpha = max(alpha_pixels)
        mean_alpha = sum(alpha_pixels) / len(alpha_pixels)
        if not (120 <= max_alpha <= 140) or not (36 <= mean_alpha <= 60):
            raise ValueError(f"{path}: weak cone alpha max={max_alpha} mean={mean_alpha:.2f}")
        edge_alpha = []
        for x in range(img.width):
            edge_alpha.append(alpha.getpixel((x, 0)))
            edge_alpha.append(alpha.getpixel((x, img.height - 1)))
        for y in range(img.height):
            edge_alpha.append(alpha.getpixel((0, y)))
            edge_alpha.append(alpha.getpixel((img.width - 1, y)))
        if max(edge_alpha) >= 8:
            raise ValueError(f"{path}: cone alpha touches image edge max={max(edge_alpha)}")
    return (
        f"{target_dir.name}/hid-light-cone.png: 400x1013, bbox={bbox}, "
        f"meaningful bbox={meaningful_bbox}, max alpha={max_alpha}, mean alpha={mean_alpha:.2f}, edge alpha ok"
    )


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", type=Path, default=Path("."), help="Repository root.")
    parser.add_argument("--alpha-threshold", type=int, default=8, help="Fail raw edge checks at or above this alpha.")
    parser.add_argument(
        "--render-root",
        type=Path,
        default=Path("output/meshy/nuclear-trains/rolling-stock-template"),
        help="Raw rolling-stock render root to scan for source clipping.",
    )
    parser.add_argument(
        "--skip-raw-edge-check",
        action="store_true",
        help="Validate only promoted Spritter metadata and sheet dimensions.",
    )
    parser.add_argument(
        "--check-packed-cell-edges",
        action="store_true",
        help="Also fail if Spritter-packed cell edges contain alpha. This is stricter than source clipping and may fail tightly cropped sheets.",
    )
    parser.add_argument(
        "--target",
        choices=sorted(TARGETS),
        action="append",
        help="Limit validation to one or more targets. Defaults to every target.",
    )
    args = parser.parse_args()
    selected_targets = set(args.target or TARGETS.keys())

    for name, relative_dir in TARGETS.items():
        if name not in selected_targets:
            continue
        target_dir = args.repo / relative_dir
        print(f"validating {name}: {target_dir}")
        if name == "nuclear-locomotive":
            print("  " + validate_hid_cone(target_dir))
        raw_dir = args.repo / args.render_root / RAW_RENDER_TARGETS[name]
        for layer in ("body", "sloped"):
            if not args.skip_raw_edge_check:
                print("  " + validate_raw_frames(raw_dir, layer, args.alpha_threshold))
            for message in validate_layer(
                target_dir,
                layer,
                args.alpha_threshold,
                args.check_packed_cell_edges,
            ):
                print("  " + message)
        for derived_layer, options in DERIVED_EXPECTED[name].items():
            for message in validate_derived_layer(
                target_dir,
                derived_layer,
                options,
                args.alpha_threshold,
                args.check_packed_cell_edges,
            ):
                print("  " + message)
    print(validate_prototype_flags(args.repo))


if __name__ == "__main__":
    main()
