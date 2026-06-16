#!/usr/bin/env python3
"""Stage Meshy/Blender art as Factorio/ESIR asset drafts."""

from __future__ import annotations

import argparse
import datetime as dt
import glob
import html
import json
import math
import os
import re
import shutil
import subprocess
import sys
from io import BytesIO
from pathlib import Path, PurePosixPath
from typing import Any
from zipfile import ZipFile, is_zipfile

from PIL import Image


SAFE_NAME = re.compile(r"^[A-Za-z0-9][A-Za-z0-9_-]*$")
SAFE_FIELD = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*(\.[A-Za-z_][A-Za-z0-9_]*)*$")
SCRIPT_PATH = Path(__file__).resolve()
REPO_ROOT = SCRIPT_PATH.parents[4]
ICON_PREP_SCRIPT = (
    REPO_ROOT
    / ".codex"
    / "skills"
    / "esir-item-icon-prep"
    / "scripts"
    / "build_factorio_item_icon.py"
)

BUNDLE_SHEETS = [
    ("base", "object_0.png", ""),
    ("shadow", "object_shadow_0.png", "_shadow"),
    ("light_reduced", "object_lightAR_0.png", "_light_reduced"),
    ("light_additive", "object_lightA_0.png", "_light_additive"),
    ("light_glared_additive", "object_lightGlaredA_0.png", "_light_glared_additive"),
    ("light", "object_light_0.png", "_light"),
    ("light_glared", "object_lightGlared_0.png", "_light_glared"),
    ("mask", "object_mask_0.png", "_mask"),
    ("water_reflection", "WaterReflection.png", "_water_reflection"),
]
BUNDLE_RAW_FOLDERS = {
    "base": "Object",
    "shadow": "Shadow",
    "light_reduced": "Light A Reduced",
    "light_additive": "Light A",
    "light_glared_additive": "Light Glared A",
    "light": "Light",
    "light_glared": "Light Glared",
    "mask": "ColorMask",
    "water_reflection": "WaterReflection",
}
BUNDLE_SHEET_BY_LAYER = {layer: sheet for layer, sheet, _suffix in BUNDLE_SHEETS}
PREFERRED_ALPHA_LIGHTS = ["light_reduced", "light_additive", "light_glared_additive"]
OPAQUE_LIGHTS = ["light", "light_glared"]
PROMOTION_MARKER_TEMPLATE = "-- ESIR_ASSET_PROMOTE_{which} {prototype_name} {field}"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Stage Factorio/ESIR asset drafts from sheets or icon source art."
    )
    subparsers = parser.add_subparsers(dest="mode", required=True)

    entity = subparsers.add_parser("entity", help="Stage a static or directional entity sheet.")
    add_common(entity, factorio_var="ei_graphics_entity_path", prototype_kind="entity")
    add_sheet_args(entity)
    add_layer_args(entity)
    entity.add_argument("--direction-count", type=int, help="Directional sprite count.")

    machine = subparsers.add_parser("machine", help="Stage an assembling-machine-style graphics_set draft.")
    add_common(machine, factorio_var="ei_graphics_entity_path", prototype_kind="assembling-machine")
    add_sheet_args(machine)
    add_layer_args(machine)
    machine.add_argument("--working-sheet", help="Optional working_visualisations animation sheet.")
    machine.add_argument("--working-manifest", help="Optional manifest for --working-sheet.")
    machine.add_argument("--working-frame-width", type=int, help="Working animation frame width.")
    machine.add_argument("--working-frame-height", type=int, help="Working animation frame height.")
    machine.add_argument("--working-frame-count", type=int, help="Working animation frame count.")
    machine.add_argument("--working-line-length", type=int, help="Working animation line length.")
    machine.add_argument("--working-scale", type=float, help="Working animation scale. Defaults to --scale.")
    machine.add_argument("--working-shift", help="Working animation shift as x,y. Defaults to --shift.")
    machine.add_argument("--working-shadow-sheet", help="Optional working animation shadow sheet.")
    machine.add_argument("--working-shadow-scale", type=float, help="Working shadow scale. Defaults to --working-scale or --scale.")
    machine.add_argument("--working-shadow-shift", help="Working shadow shift as x,y. Defaults to --working-shift or --shift.")
    machine.add_argument("--animation-speed", type=float, default=0.6, help="Working animation speed.")
    machine.add_argument("--run-mode", choices=["forward", "backward"], help="Optional Factorio animation run_mode.")

    icon = subparsers.add_parser("icon", help="Stage a Factorio item icon mip strip.")
    add_common(icon, factorio_var="ei_graphics_item_path", prototype_kind="item")
    icon.add_argument("--source", required=True, help="Source icon artwork.")
    icon.add_argument("--canvas-size", type=int, default=128, help="Base icon canvas size.")
    icon.add_argument("--fit-size", type=int, default=118, help="Maximum fitted subject size.")
    icon.add_argument("--mip-sizes", default="64,32", help="Comma-separated mip sizes.")
    icon.add_argument(
        "--allow-existing-strip",
        action="store_true",
        help="Allow source art that already looks like a mip strip.",
    )

    bundle = subparsers.add_parser(
        "render-bundle",
        aliases=["bundle"],
        help="Stage a Factorio rendering preset Render.zip, extracted .Sheets, or raw Render frame bundle.",
    )
    add_common(bundle, factorio_var="ei_graphics_entity_path", prototype_kind="assembling-machine")
    add_layer_args(bundle, include_shadow_sheet=False)
    bundle.add_argument("--bundle", required=True, help="Render.zip or extracted Render directory.")
    bundle.add_argument(
        "--preset-manifest",
        help="Optional render_factorio_preset.py manifest used to infer frame/direction layout.",
    )
    bundle.add_argument(
        "--prototype-mode",
        choices=["machine", "entity"],
        default="machine",
        help="Snippet shape to emit for the staged bundle.",
    )
    bundle.add_argument("--frame-width", type=int, help="Frame width in pixels. Defaults from sheet layout.")
    bundle.add_argument("--frame-height", type=int, help="Frame height in pixels. Defaults from sheet layout.")
    bundle.add_argument("--line-length", type=int, help="Frames per row in the bundled sheets. Defaults to 8 or preset manifest grid.")
    bundle.add_argument("--frame-count", type=int, help="Animation frame count per direction. Defaults from preset manifest or 64.")
    bundle.add_argument("--direction-count", type=int, help="Direction count for directional bundles. Defaults from preset manifest or 1.")
    bundle.add_argument("--animation-speed", type=float, default=0.6, help="Animation speed for machine snippets.")
    bundle.add_argument("--run-mode", choices=["forward", "backward"], help="Optional Factorio animation run_mode.")
    bundle.add_argument(
        "--light-layer",
        choices=["none", "glow", "light"],
        default="glow",
        help="Include the best alpha-safe light sheet as draw_as_glow/draw_as_light, or stage only.",
    )
    bundle.add_argument(
        "--light-source",
        choices=["auto", "light_reduced", "light_additive", "light_glared_additive", "light", "light_glared"],
        default="auto",
        help="Specific staged light sheet to use in the snippet.",
    )
    bundle.add_argument(
        "--allow-opaque-light-layer",
        action="store_true",
        help="Allow object_light_0/object_lightGlared_0 in snippets even though they may be full-alpha sheets.",
    )
    bundle.add_argument(
        "--pack-raw-frames",
        action="store_true",
        help="Pack raw Render/Object/... frame folders instead of relying on Render/.Sheets.",
    )
    bundle.add_argument("--grid", default="8x8", help="Raw frame sheet grid, for example 2x2, 4x4, or 8x8.")
    bundle.add_argument(
        "--sheet-output-dir",
        help="Where packed raw sheets are written. Defaults to <output-dir>/.packed-sheets.",
    )
    bundle.add_argument(
        "--black-to-transparent",
        choices=["none", "rgb-zero"],
        default="none",
        help="Optional conversion for legacy black-background helper outputs.",
    )
    bundle.add_argument(
        "--emit-water-reflection",
        action="store_true",
        help="Include staged WaterReflection.png in the generated Lua snippet.",
    )
    bundle.add_argument(
        "--water-reflection-placement",
        choices=["auto", "top-level", "graphics-set"],
        default="auto",
        help="Where to place the water_reflection snippet.",
    )
    bundle.add_argument("--water-reflection-scale", type=float, default=5.0, help="water_reflection picture scale.")
    bundle.add_argument("--water-reflection-shift", default="0,45", help="water_reflection shift in pixels as x,y.")
    bundle.add_argument(
        "--water-reflection-priority",
        default="extra-high",
        help="Factorio render priority for water_reflection pictures.",
    )

    promote = subparsers.add_parser("promote", help="Dry-run or apply a narrow promotion from staged output.")
    promote.add_argument("--manifest", required=True, help="Staged factorio asset manifest.")
    promote.add_argument("--copy-assets", action="store_true", help="Copy staged PNGs into --graphics-destination.")
    promote.add_argument("--graphics-destination", help="Explicit graphics directory for --copy-assets.")
    promote.add_argument("--apply-prototype", action="store_true", help="Patch a marker-delimited prototype field.")
    promote.add_argument("--prototype-file", help="Prototype Lua file to patch.")
    promote.add_argument("--prototype-type", help="Prototype type for the dry-run plan.")
    promote.add_argument("--prototype-name", help="Prototype name and marker key.")
    promote.add_argument("--field", help="Prototype field and marker key, such as graphics_set.")
    promote.add_argument(
        "--expected-asset-count",
        type=int,
        help="Optional guard: fail if the manifest exposes a different number of promotable PNGs.",
    )
    promote.add_argument(
        "--require-prototype-identity",
        action="store_true",
        help="Require the prototype file to mention the requested prototype type and name before patching.",
    )
    promote.add_argument(
        "--prototype-integration",
        choices=["marker", "data-raw-assignment"],
        default="marker",
        help="Marker replacement style. data-raw-assignment emits a guarded data.raw assignment block.",
    )
    promote.add_argument(
        "--execute",
        action="store_true",
        help="Actually perform requested copy/prototype operations. Without this, promotion is a dry-run.",
    )
    promote.add_argument("--plan-output", help="Optional JSON plan output path.")

    gallery = subparsers.add_parser("gallery", help="Build a static visual approval gallery from staged manifests.")
    gallery.add_argument("--manifest", action="append", default=[], help="Manifest path. May be repeated.")
    gallery.add_argument("--manifest-glob", action="append", default=[], help="Python-expanded manifest glob. May be repeated.")
    gallery.add_argument("--output", required=True, help="HTML gallery output path.")
    gallery.add_argument("--approval-json", help="Optional JSON sidecar with collected gallery entries.")
    gallery.add_argument("--title", default="ESIR Visual Approval Gallery")
    gallery.add_argument("--include-snippet", action="store_true", help="Include prototype snippets in the HTML.")

    return parser.parse_args()


def add_common(parser: argparse.ArgumentParser, factorio_var: str, prototype_kind: str) -> None:
    parser.add_argument(
        "--asset-name",
        required=True,
        help="Asset/staging name. For main-pack graphics, prefer no leading ei- and pass --target-prototype-name for ei-* prototypes.",
    )
    parser.add_argument(
        "--output-dir",
        help="Staging directory. Defaults to output/meshy/<asset-name>/factorio-export.",
    )
    parser.add_argument("--filename-root", help="Output filename root. Defaults to --asset-name with a leading ei- removed.")
    parser.add_argument("--factorio-var", default=factorio_var, help="Lua graphics path variable for snippets.")
    parser.add_argument("--prototype-kind", default=prototype_kind, help="Prototype kind noted in metadata.")
    parser.add_argument(
        "--snippet-template",
        choices=[
            "auto",
            "entity",
            "machine",
            "assembling-machine",
            "furnace",
            "lab",
            "beacon",
            "turret",
            "car",
            "unit",
            "simple-entity",
            "container",
            "corpse",
            "item",
            "recipe",
            "technology",
        ],
        default="auto",
        help="Prototype-aware snippet hint. Keeps output staged; promotion is still separate.",
    )
    parser.add_argument("--target-prototype-type", help="Prototype type for snippet comments/manifest. Defaults from --prototype-kind.")
    parser.add_argument("--target-prototype-name", help="Prototype name for snippet comments/manifest. Defaults from --asset-name.")
    parser.add_argument("--target-field", default="auto", help="Prototype field hint, or auto.")


def add_sheet_args(parser: argparse.ArgumentParser) -> None:
    parser.add_argument("--sheet", required=True, help="Input PNG sheet.")
    parser.add_argument("--render-manifest", help="Optional render manifest JSON.")
    parser.add_argument("--frame-width", type=int, help="Frame width in pixels.")
    parser.add_argument("--frame-height", type=int, help="Frame height in pixels.")
    parser.add_argument("--line-length", type=int, help="Frames per row.")
    parser.add_argument("--frame-count", type=int, help="Frame count per direction.")


def add_layer_args(parser: argparse.ArgumentParser, *, include_shadow_sheet: bool = True) -> None:
    parser.add_argument("--scale", type=float, default=1.0, help="Lua sprite scale.")
    parser.add_argument("--shift", default="0,0", help="Lua sprite shift as x,y.")
    if include_shadow_sheet:
        parser.add_argument("--shadow-sheet", help="Optional shadow PNG sheet.")
    parser.add_argument("--shadow-scale", type=float, help="Shadow scale. Defaults to --scale.")
    parser.add_argument("--shadow-shift", help="Shadow shift as x,y. Defaults to --shift.")


def require_safe_name(value: str, label: str) -> str:
    if not SAFE_NAME.match(value):
        raise SystemExit(f"{label} must contain only letters, numbers, underscores, or dashes: {value}")
    return value


def resolve_path(value: str | None) -> Path | None:
    if value is None:
        return None
    return Path(value).expanduser().resolve()


def display_path(path: Path) -> str:
    try:
        return str(path.resolve().relative_to(Path.cwd().resolve())).replace("\\", "/")
    except ValueError:
        return str(path)


def output_dir_for(args: argparse.Namespace) -> Path:
    if args.output_dir:
        return resolve_path(args.output_dir)  # type: ignore[return-value]
    return (Path.cwd() / "output" / "meshy" / args.asset_name / "factorio-export").resolve()


def graphics_filename_root(value: str) -> str:
    if value.startswith("ei-") and len(value) > 3:
        return value[3:]
    return value


def filename_root_for(args: argparse.Namespace) -> str:
    root = args.filename_root if args.filename_root else graphics_filename_root(args.asset_name)
    return require_safe_name(root, "filename root")


def read_manifest(path: Path | None) -> dict[str, Any]:
    if path is None:
        return {}
    if not path.exists():
        raise FileNotFoundError(f"Manifest not found: {path}")
    return json.loads(path.read_text(encoding="utf-8-sig"))


def optional_manifest(path: Path | None) -> dict[str, Any]:
    if path is None or not path.exists():
        return {}
    return json.loads(path.read_text(encoding="utf-8-sig"))


def parse_shift(raw: str) -> tuple[float, float]:
    value = raw.strip().strip("{}[]()")
    parts = [part.strip() for part in value.split(",")]
    if len(parts) != 2:
        raise argparse.ArgumentTypeError(f"Shift must be x,y: {raw}")
    return (float(parts[0]), float(parts[1]))


def parse_mip_sizes(raw: str) -> list[int]:
    values = [int(part.strip()) for part in raw.split(",") if part.strip()]
    if not values:
        raise ValueError("--mip-sizes must include at least one size.")
    return values


def natural_key(value: str) -> list[Any]:
    return [int(part) if part.isdigit() else part.lower() for part in re.split(r"(\d+)", value)]


def parse_grid(raw: str) -> tuple[int, int]:
    value = raw.lower().replace(",", "x")
    parts = [part.strip() for part in value.split("x") if part.strip()]
    if len(parts) != 2:
        raise argparse.ArgumentTypeError(f"Grid must be columns x rows, got {raw}")
    columns, rows = int(parts[0]), int(parts[1])
    if columns < 1 or rows < 1:
        raise argparse.ArgumentTypeError("--grid values must be positive.")
    return columns, rows


def int_from_manifest(manifest: dict[str, Any], *keys: str) -> int | None:
    for key in keys:
        value = manifest.get(key)
        if value is not None:
            return int(value)
    return None


def image_info(path: Path) -> tuple[int, int, str]:
    if not path.exists():
        raise FileNotFoundError(f"Image not found: {path}")
    with Image.open(path) as image:
        return image.width, image.height, image.mode


def derive_spec(
    path: Path,
    manifest: dict[str, Any],
    *,
    frame_width: int | None,
    frame_height: int | None,
    line_length: int | None,
    frame_count: int | None,
    direction_count: int | None,
    default_frame_count: int,
    default_direction_count: int,
    manifest_directions_as: str,
) -> dict[str, Any]:
    image_width, image_height, mode = image_info(path)
    warnings: list[str] = []
    padding = int_from_manifest(manifest, "padding") or 0
    manifest_frame_size = int_from_manifest(manifest, "frame_size")

    if mode not in {"RGBA", "LA"} and "transparency" not in mode.lower():
        warnings.append(f"{display_path(path)} is {mode}; Factorio assets usually need transparent RGBA PNGs.")

    if padding:
        warnings.append("Input manifest has padding; generated snippets do not encode frame spacing.")

    inferred_directions = int_from_manifest(manifest, "directions")
    inferred_frame_count = int_from_manifest(manifest, "frame_count")
    if manifest_directions_as == "direction" and direction_count is None:
        direction_count = inferred_directions
    if manifest_directions_as == "frame" and frame_count is None:
        frame_count = inferred_frame_count or inferred_directions

    frame_count = frame_count or default_frame_count
    direction_count = direction_count or default_direction_count
    total_frames = frame_count * direction_count
    if total_frames < 1:
        raise ValueError("Total frame count must be positive.")

    frame_width = frame_width or manifest_frame_size
    frame_height = frame_height or manifest_frame_size
    line_length = line_length or int_from_manifest(manifest, "columns")

    if frame_width is None and line_length is None:
        line_length = total_frames
    if frame_width is None:
        assert line_length is not None
        frame_width = (image_width - padding * max(line_length - 1, 0)) // line_length

    line_length = line_length or max(1, image_width // frame_width)
    rows = math.ceil(total_frames / line_length)
    if frame_height is None:
        frame_height = (image_height - padding * max(rows - 1, 0)) // rows

    expected_width = line_length * frame_width + padding * max(line_length - 1, 0)
    expected_height = rows * frame_height + padding * max(rows - 1, 0)
    if expected_width > image_width or expected_height > image_height:
        raise ValueError(
            f"Frame layout exceeds image bounds for {path}: expected at least "
            f"{expected_width}x{expected_height}, got {image_width}x{image_height}."
        )
    if expected_width != image_width or expected_height != image_height:
        warnings.append(
            f"Frame layout covers {expected_width}x{expected_height} of "
            f"{image_width}x{image_height}; check for unused sheet area."
        )

    return {
        "path": display_path(path),
        "image_width": image_width,
        "image_height": image_height,
        "frame_width": frame_width,
        "frame_height": frame_height,
        "line_length": line_length,
        "frame_count": frame_count,
        "direction_count": direction_count,
        "rows": rows,
        "padding": padding,
        "warnings": warnings,
    }


def derive_multisheet_spec(
    paths: list[Path],
    *,
    frame_width: int | None,
    frame_height: int | None,
    line_length: int,
    frame_count: int,
    direction_count: int,
) -> dict[str, Any]:
    if not paths:
        raise ValueError("Multi-sheet spec requires at least one sheet.")
    image_width, image_height, mode = image_info(paths[0])
    warnings: list[str] = []
    if mode not in {"RGBA", "LA"} and "transparency" not in mode.lower():
        warnings.append(f"{display_path(paths[0])} is {mode}; Factorio assets usually need transparent RGBA PNGs.")
    frame_width = frame_width or max(1, image_width // line_length)
    frame_height = frame_height or frame_width
    total_frames = frame_count * direction_count
    if total_frames < 1:
        raise ValueError("Total frame count must be positive.")

    stripes: list[dict[str, Any]] = []
    capacity = 0
    for path in paths:
        width, height, _mode = image_info(path)
        if width % frame_width or height % frame_height:
            raise ValueError(
                f"Multi-sheet stripe dimensions must divide by frame size for {path}: "
                f"{width}x{height} with frame {frame_width}x{frame_height}."
            )
        width_in_frames = max(1, width // frame_width)
        height_in_frames = max(1, height // frame_height)
        capacity += width_in_frames * height_in_frames
        stripes.append(
            {
                "filename": path.name,
                "path": display_path(path),
                "width_in_frames": width_in_frames,
                "height_in_frames": height_in_frames,
                "image_width": width,
                "image_height": height,
            }
        )
    if capacity < total_frames:
        raise ValueError(f"Multi-sheet stripes hold {capacity} frames, but layout needs {total_frames}.")
    if capacity > total_frames:
        warnings.append(f"Multi-sheet stripes hold {capacity} frames for {total_frames} declared frames; check unused cells.")

    return {
        "path": display_path(paths[0]),
        "image_width": image_width,
        "image_height": image_height,
        "frame_width": frame_width,
        "frame_height": frame_height,
        "line_length": line_length,
        "frame_count": frame_count,
        "direction_count": direction_count,
        "capacity": capacity,
        "rows": math.ceil(total_frames / line_length),
        "padding": 0,
        "stripes": stripes,
        "warnings": warnings,
    }


def ensure_parent(path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)


def copy_png(source: Path, destination: Path) -> None:
    if source.suffix.lower() != ".png":
        raise ValueError(f"Expected a PNG file: {source}")
    ensure_parent(destination)
    shutil.copy2(source, destination)


def save_png_bytes_as_rgba(data: bytes, destination: Path) -> None:
    ensure_parent(destination)
    with Image.open(BytesIO(data)).convert("RGBA") as image:
        image.save(destination)


def rgba_bytes(image: Image.Image) -> bytes:
    buffer = BytesIO()
    image.convert("RGBA").save(buffer, format="PNG")
    return buffer.getvalue()


def maybe_black_to_transparent(image: Image.Image, mode: str) -> Image.Image:
    image = image.convert("RGBA")
    if mode != "rgb-zero":
        return image
    pixels = image.load()
    for y in range(image.height):
        for x in range(image.width):
            r, g, b, a = pixels[x, y]
            if r == 0 and g == 0 and b == 0:
                pixels[x, y] = (r, g, b, 0)
            else:
                pixels[x, y] = (r, g, b, a)
    return image


def read_frame_image(data: bytes, *, black_to_transparent: str) -> Image.Image:
    with Image.open(BytesIO(data)) as image:
        return maybe_black_to_transparent(image, black_to_transparent)


def checkerboard(size: tuple[int, int], square: int = 16) -> Image.Image:
    width, height = size
    image = Image.new("RGBA", size, (0, 0, 0, 0))
    px = image.load()
    colors = ((44, 48, 56, 255), (90, 96, 108, 255))
    for y in range(height):
        for x in range(width):
            px[x, y] = colors[((x // square) + (y // square)) % 2]
    return image


def write_sheet_preview(source: Path, destination: Path, max_size: int = 1024) -> None:
    with Image.open(source).convert("RGBA") as image:
        scale = min(max_size / image.width, max_size / image.height, 1.0)
        if scale < 1.0:
            image = image.resize(
                (max(1, round(image.width * scale)), max(1, round(image.height * scale))),
                Image.Resampling.LANCZOS,
            )
        background = checkerboard(image.size)
        background.alpha_composite(image)
        ensure_parent(destination)
        background.save(destination)


def fmt_num(value: float | int) -> str:
    number = float(value)
    if abs(number - round(number)) < 0.000001:
        return str(int(round(number)))
    return f"{number:.6f}".rstrip("0").rstrip(".")


def fmt_shift(shift: tuple[float, float]) -> str:
    return "{" + f"{fmt_num(shift[0])}, {fmt_num(shift[1])}" + "}"


def fmt_by_pixel(shift: tuple[float, float]) -> str:
    return f"util.by_pixel({fmt_num(shift[0])}, {fmt_num(shift[1])})"


def water_reflection_table(
    *,
    filename: str,
    factorio_var: str,
    spec: dict[str, Any],
    shift: tuple[float, float],
    scale: float,
    priority: str,
    indent: int = 4,
) -> str:
    pad = " " * indent
    return "\n".join(
        [
            pad + "{",
            pad + "    pictures = {",
            pad + f'        filename = {factorio_var}.."{filename}",',
            pad + f'        priority = "{priority}",',
            pad + f"        width = {spec['frame_width']},",
            pad + f"        height = {spec['frame_height']},",
            pad + f"        shift = {fmt_by_pixel(shift)},",
            pad + "        variation_count = 1,",
            pad + f"        scale = {fmt_num(scale)},",
            pad + "    },",
            pad + "    rotate = false,",
            pad + "    orientation_to_variation = false,",
            pad + "}",
        ]
    )


def sprite_table(
    *,
    filename: str | None = None,
    factorio_var: str,
    spec: dict[str, Any],
    shift: tuple[float, float],
    scale: float,
    draw_as_shadow: bool = False,
    draw_as_glow: bool = False,
    draw_as_light: bool = False,
    animation_speed: float | None = None,
    run_mode: str | None = None,
    indent: int = 8,
) -> str:
    pad = " " * indent
    lines = [
        pad + "{",
        pad + f"    size = {{{spec['frame_width']}, {spec['frame_height']}}},",
        pad + f"    width = {spec['frame_width']},",
        pad + f"    height = {spec['frame_height']},",
        pad + f"    shift = {fmt_shift(shift)},",
        pad + f"    scale = {fmt_num(scale)},",
        pad + f"    line_length = {spec['line_length']},",
        pad + f"    frame_count = {spec['frame_count']},",
    ]
    if filename:
        lines.insert(1, pad + f'    filename = {factorio_var}.."{filename}",')
    elif not spec.get("stripes"):
        raise ValueError("sprite_table requires filename or spec.stripes.")
    if spec["direction_count"] > 1:
        lines.append(pad + f"    direction_count = {spec['direction_count']},")
    if draw_as_shadow:
        lines.append(pad + "    draw_as_shadow = true,")
    if draw_as_glow:
        lines.append(pad + "    draw_as_glow = true,")
    if draw_as_light:
        lines.append(pad + "    draw_as_light = true,")
    if animation_speed is not None:
        lines.append(pad + f"    animation_speed = {fmt_num(animation_speed)},")
    if run_mode:
        lines.append(pad + f'    run_mode = "{run_mode}",')
    if spec.get("stripes"):
        lines.append(pad + "    stripes = {")
        for stripe in spec["stripes"]:
            lines.extend(
                [
                    pad + "        {",
                    pad + f'            filename = {factorio_var}.."{stripe["filename"]}",',
                    pad + f"            width_in_frames = {stripe['width_in_frames']},",
                    pad + f"            height_in_frames = {stripe['height_in_frames']},",
                    pad + "        },",
                ]
            )
        lines.append(pad + "    },")
    lines.append(pad + "}")
    return "\n".join(lines)


def animation_block(
    *,
    main_filename: str,
    factorio_var: str,
    main_spec: dict[str, Any],
    main_shift: tuple[float, float],
    main_scale: float,
    shadow_filename: str | None = None,
    shadow_spec: dict[str, Any] | None = None,
    shadow_shift: tuple[float, float] | None = None,
    shadow_scale: float | None = None,
    animation_speed: float | None = None,
    run_mode: str | None = None,
    indent: int = 4,
) -> str:
    pad = " " * indent
    if not shadow_filename or not shadow_spec:
        return sprite_table(
            filename=main_filename,
            factorio_var=factorio_var,
            spec=main_spec,
            shift=main_shift,
            scale=main_scale,
            animation_speed=animation_speed,
            run_mode=run_mode,
            indent=indent,
        )

    return "\n".join(
        [
            pad + "{",
            pad + "    layers = {",
            sprite_table(
                filename=main_filename,
                factorio_var=factorio_var,
                spec=main_spec,
                shift=main_shift,
                scale=main_scale,
                animation_speed=animation_speed,
                run_mode=run_mode,
                indent=indent + 8,
            )
            + ",",
            sprite_table(
                filename=shadow_filename,
                factorio_var=factorio_var,
                spec=shadow_spec,
                shift=shadow_shift or main_shift,
                scale=shadow_scale or main_scale,
                draw_as_shadow=True,
                indent=indent + 8,
            ),
            pad + "    }",
            pad + "}",
        ]
    )


def layered_animation_block(layer_tables: list[str], *, indent: int = 4) -> str:
    pad = " " * indent
    if len(layer_tables) == 1:
        return layer_tables[0]
    lines = [pad + "{", pad + "    layers = {"]
    for index, table in enumerate(layer_tables):
        text = table + ("," if index < len(layer_tables) - 1 else "")
        lines.append(text)
    lines.extend([pad + "    }", pad + "}"])
    return "\n".join(lines)


def assign_table(name: str, table: str, *, indent: int = 0, trailing_comma: bool = False) -> str:
    lines = table.splitlines()
    base_indent = len(lines[0]) - len(lines[0].lstrip(" "))
    normalized = []
    for line in lines:
        if line.startswith(" " * base_indent):
            line = line[base_indent:]
        normalized.append((" " * indent) + line)
    lines = normalized
    lines[0] = (" " * indent) + f"{name} = " + lines[0].strip()
    if trailing_comma:
        lines[-1] = lines[-1] + ","
    return "\n".join(lines)


def prototype_template_metadata(args: argparse.Namespace, *, default_field: str, mode: str) -> dict[str, Any]:
    explicit_template = getattr(args, "snippet_template", "auto") != "auto"
    explicit_target_type = bool(args.target_prototype_type)
    explicit_target_name = bool(args.target_prototype_name)
    explicit_target_field = getattr(args, "target_field", "auto") != "auto"
    template = args.snippet_template if explicit_template else args.prototype_kind
    target_type = args.target_prototype_type or args.prototype_kind
    target_name = args.target_prototype_name or args.asset_name
    field = args.target_field if explicit_target_field else default_field
    warnings: list[str] = []
    machine_types = {"machine", "assembling-machine", "furnace", "lab", "beacon"}
    icon_types = {"item", "recipe", "technology"}
    if mode == "machine" and template not in machine_types:
        warnings.append(f"Template {template} is staged with a graphics_set-shaped snippet; inspect target prototype fields.")
    if mode == "entity" and field not in {"animation", "picture"}:
        warnings.append(f"Entity snippet target field {field} is a hint only; generated table is animation-shaped.")
    if mode == "icon" and template not in icon_types:
        warnings.append(f"Icon snippet uses icon fields even though template is {template}.")
    return {
        "template": template,
        "target_prototype_type": target_type,
        "target_prototype_name": target_name,
        "target_field": field,
        "mode": mode,
        "explicit": {
            "snippet_template": explicit_template,
            "target_prototype_type": explicit_target_type,
            "target_prototype_name": explicit_target_name,
            "target_field": explicit_target_field,
        },
        "warnings": warnings,
    }


def snippet_notes(args: argparse.Namespace, metadata: dict[str, Any]) -> list[str]:
    return [
        f"-- Prototype template: {metadata['template']} -> {metadata['target_prototype_type']}/{metadata['target_prototype_name']} field {metadata['target_field']}.",
        f"-- Promotion hint: --prototype-type {metadata['target_prototype_type']} --prototype-name {metadata['target_prototype_name']} --field {metadata['target_field']}.",
        *[f"-- Warning: {warning}" for warning in metadata.get("warnings", [])],
    ]


def write_entity_snippet(
    path: Path,
    args: argparse.Namespace,
    *,
    main_filename: str,
    main_spec: dict[str, Any],
    shadow_filename: str | None,
    shadow_spec: dict[str, Any] | None,
) -> None:
    metadata = prototype_template_metadata(args, default_field="animation", mode="entity")
    shift = parse_shift(args.shift)
    shadow_shift = parse_shift(args.shadow_shift) if args.shadow_shift else shift
    animation = animation_block(
        main_filename=main_filename,
        factorio_var=args.factorio_var,
        main_spec=main_spec,
        main_shift=shift,
        main_scale=args.scale,
        shadow_filename=shadow_filename,
        shadow_spec=shadow_spec,
        shadow_shift=shadow_shift,
        shadow_scale=args.shadow_scale or args.scale,
        indent=4,
    )
    text = "\n".join(
        [
            f"-- Draft snippet for {args.asset_name}.",
            "-- Copy staged PNGs into the graphics folder behind the selected path variable before wiring.",
            *snippet_notes(args, metadata),
            assign_table("animation", animation),
            "",
        ]
    )
    path.write_text(text, encoding="utf-8")


def write_machine_snippet(
    path: Path,
    args: argparse.Namespace,
    *,
    main_filename: str,
    main_spec: dict[str, Any],
    shadow_filename: str | None,
    shadow_spec: dict[str, Any] | None,
    working_filename: str | None,
    working_spec: dict[str, Any] | None,
    working_shadow_filename: str | None,
    working_shadow_spec: dict[str, Any] | None,
) -> None:
    metadata = prototype_template_metadata(args, default_field="graphics_set", mode="machine")
    shift = parse_shift(args.shift)
    shadow_shift = parse_shift(args.shadow_shift) if args.shadow_shift else shift
    animation = animation_block(
        main_filename=main_filename,
        factorio_var=args.factorio_var,
        main_spec=main_spec,
        main_shift=shift,
        main_scale=args.scale,
        shadow_filename=shadow_filename,
        shadow_spec=shadow_spec,
        shadow_shift=shadow_shift,
        shadow_scale=args.shadow_scale or args.scale,
        indent=8,
    )
    lines = [
        f"-- Draft graphics_set for {args.asset_name}.",
        "-- Copy staged PNGs into the graphics folder behind the selected path variable before wiring.",
        *snippet_notes(args, metadata),
        "graphics_set = {",
        assign_table("animation", animation, indent=4, trailing_comma=True),
    ]
    if working_filename and working_spec:
        working_shift = parse_shift(args.working_shift) if args.working_shift else shift
        working_scale = args.working_scale if args.working_scale is not None else args.scale
        working_shadow_shift = (
            parse_shift(args.working_shadow_shift)
            if args.working_shadow_shift
            else working_shift
        )
        working_shadow_scale = (
            args.working_shadow_scale
            if args.working_shadow_scale is not None
            else working_scale
        )
        working = animation_block(
            main_filename=working_filename,
            factorio_var=args.factorio_var,
            main_spec=working_spec,
            main_shift=working_shift,
            main_scale=working_scale,
            shadow_filename=working_shadow_filename,
            shadow_spec=working_shadow_spec,
            shadow_shift=working_shadow_shift,
            shadow_scale=working_shadow_scale,
            animation_speed=args.animation_speed,
            run_mode=args.run_mode,
            indent=12,
        )
        if not working_shadow_filename:
            working = sprite_table(
                filename=working_filename,
                factorio_var=args.factorio_var,
                spec=working_spec,
                shift=working_shift,
                scale=working_scale,
                animation_speed=args.animation_speed,
                run_mode=args.run_mode,
                indent=12,
            )
        lines.extend(
            [
                "    working_visualisations = {",
                "        {",
                assign_table("animation", working, indent=12, trailing_comma=True),
                "        },",
                "    },",
            ]
        )
    lines.extend(["}", ""])
    path.write_text("\n".join(lines), encoding="utf-8")


def write_icon_snippet(path: Path, args: argparse.Namespace, *, icon_filename: str, icon_mipmaps: int) -> None:
    metadata = prototype_template_metadata(args, default_field="icon", mode="icon")
    text = "\n".join(
        [
            f"-- Draft item prototype fields for {args.asset_name}.",
            "-- Field fragment, not standalone Lua; trailing commas are intentional.",
            "-- Copy staged PNG into the graphics folder behind the selected path variable before wiring.",
            *snippet_notes(args, metadata),
            f'icon = {args.factorio_var}.."{icon_filename}",',
            f"icon_size = {args.canvas_size},",
            f"icon_mipmaps = {icon_mipmaps},",
            "",
        ]
    )
    path.write_text(text, encoding="utf-8")


def write_render_bundle_snippet(
    path: Path,
    args: argparse.Namespace,
    *,
    staged_layers: dict[str, dict[str, Any]],
    base_spec: dict[str, Any],
    selected_light_key: str | None,
) -> None:
    metadata = prototype_template_metadata(
        args,
        default_field="graphics_set" if args.prototype_mode == "machine" else "animation",
        mode=args.prototype_mode,
    )
    shift = parse_shift(args.shift)
    shadow_shift = parse_shift(args.shadow_shift) if args.shadow_shift else shift
    block_indent = 8 if args.prototype_mode == "machine" else 4
    layer_indent = block_indent + 8
    layer_tables = [
        sprite_table(
            filename=None if staged_layers["base"]["spec"].get("stripes") else staged_layers["base"]["filename"],
            factorio_var=args.factorio_var,
            spec=base_spec,
            shift=shift,
            scale=args.scale,
            animation_speed=args.animation_speed if args.prototype_mode == "machine" else None,
            run_mode=args.run_mode if args.prototype_mode == "machine" else None,
            indent=layer_indent,
        )
    ]

    if "shadow" in staged_layers:
        layer_tables.append(
            sprite_table(
                filename=None if staged_layers["shadow"]["spec"].get("stripes") else staged_layers["shadow"]["filename"],
                factorio_var=args.factorio_var,
                spec=staged_layers["shadow"]["spec"],
                shift=shadow_shift,
                scale=args.shadow_scale or args.scale,
                draw_as_shadow=True,
                indent=layer_indent,
            )
        )

    if selected_light_key:
        layer_tables.append(
            sprite_table(
                filename=None if staged_layers[selected_light_key]["spec"].get("stripes") else staged_layers[selected_light_key]["filename"],
                factorio_var=args.factorio_var,
                spec=staged_layers[selected_light_key]["spec"],
                shift=shift,
                scale=args.scale,
                draw_as_glow=args.light_layer == "glow",
                draw_as_light=args.light_layer == "light",
                indent=layer_indent,
            )
        )

    animation = layered_animation_block(layer_tables, indent=block_indent)
    notes = [
        f"-- Draft snippet from Factorio rendering preset bundle for {args.asset_name}.",
        "-- Copy staged PNGs into the graphics folder behind the selected path variable before wiring.",
        *snippet_notes(args, metadata),
    ]
    staged_keys = ", ".join(sorted(staged_layers))
    notes.append(f"-- Staged bundle layers: {staged_keys}.")
    if selected_light_key is None and args.light_layer != "none":
        notes.append("-- No alpha-safe light layer was selected for the snippet; light sheets remain staged for manual use.")
    water_reflection = None
    if args.emit_water_reflection:
        if "water_reflection" in staged_layers:
            water_reflection = water_reflection_table(
                filename=staged_layers["water_reflection"]["filename"],
                factorio_var=args.factorio_var,
                spec=staged_layers["water_reflection"]["spec"],
                shift=parse_shift(args.water_reflection_shift),
                scale=args.water_reflection_scale,
                priority=args.water_reflection_priority,
                indent=4,
            )
        else:
            notes.append("-- --emit-water-reflection was requested, but no WaterReflection.png layer was staged.")

    if args.prototype_mode == "machine":
        use_graphics_set_water = (
            water_reflection is not None
            and args.water_reflection_placement in {"auto", "graphics-set"}
        )
        lines = notes + [
            "graphics_set = {",
            assign_table("animation", animation, indent=4, trailing_comma=True),
        ]
        if use_graphics_set_water:
            lines.append(assign_table("water_reflection", water_reflection, indent=4, trailing_comma=True))
        lines.append("}")
        if water_reflection is not None and not use_graphics_set_water:
            lines.append(assign_table("water_reflection", water_reflection, trailing_comma=False))
        lines.append("")
        text = "\n".join(lines)
    else:
        lines = notes + [assign_table("animation", animation)]
        if water_reflection is not None:
            lines.append(assign_table("water_reflection", water_reflection))
        lines.append("")
        text = "\n".join(lines)
    path.write_text(text, encoding="utf-8")


def write_manifest(path: Path, payload: dict[str, Any]) -> None:
    payload["created_at_utc"] = dt.datetime.now(dt.UTC).isoformat()
    path.write_text(json.dumps(payload, indent=2), encoding="utf-8")


def run_entity(args: argparse.Namespace) -> None:
    require_safe_name(args.asset_name, "asset name")
    root = filename_root_for(args)
    output_dir = output_dir_for(args)
    output_dir.mkdir(parents=True, exist_ok=True)

    source_sheet = resolve_path(args.sheet)
    assert source_sheet is not None
    render_manifest = read_manifest(resolve_path(args.render_manifest))
    main_filename = f"{root}.png"
    staged_sheet = output_dir / main_filename
    copy_png(source_sheet, staged_sheet)

    main_spec = derive_spec(
        staged_sheet,
        render_manifest,
        frame_width=args.frame_width,
        frame_height=args.frame_height,
        line_length=args.line_length,
        frame_count=args.frame_count,
        direction_count=args.direction_count,
        default_frame_count=1,
        default_direction_count=1,
        manifest_directions_as="direction",
    )

    shadow_filename = None
    shadow_spec = None
    if args.shadow_sheet:
        shadow_source = resolve_path(args.shadow_sheet)
        assert shadow_source is not None
        shadow_filename = f"{root}_shadow.png"
        staged_shadow = output_dir / shadow_filename
        copy_png(shadow_source, staged_shadow)
        shadow_spec = derive_spec(
            staged_shadow,
            render_manifest,
            frame_width=args.frame_width,
            frame_height=args.frame_height,
            line_length=args.line_length,
            frame_count=args.frame_count,
            direction_count=args.direction_count,
            default_frame_count=main_spec["frame_count"],
            default_direction_count=main_spec["direction_count"],
            manifest_directions_as="direction",
        )

    preview = output_dir / f"{root}.preview.png"
    snippet = output_dir / f"{root}.prototype-snippet.lua"
    manifest_path = output_dir / f"{root}.factorio-asset-manifest.json"
    write_sheet_preview(staged_sheet, preview)
    write_entity_snippet(
        snippet,
        args,
        main_filename=main_filename,
        main_spec=main_spec,
        shadow_filename=shadow_filename,
        shadow_spec=shadow_spec,
    )
    write_manifest(
        manifest_path,
        {
            "mode": "entity",
            "asset_name": args.asset_name,
            "prototype_kind": args.prototype_kind,
            "prototype_template": prototype_template_metadata(args, default_field="animation", mode="entity"),
            "output_dir": display_path(output_dir),
            "files": {
                "sheet": display_path(staged_sheet),
                "preview": display_path(preview),
                "snippet": display_path(snippet),
                "shadow_sheet": display_path(output_dir / shadow_filename) if shadow_filename else None,
            },
            "factorio": {
                "path_variable": args.factorio_var,
                "scale": args.scale,
                "shift": parse_shift(args.shift),
            },
            "main_spec": main_spec,
            "shadow_spec": shadow_spec,
            "warnings": main_spec["warnings"] + (shadow_spec["warnings"] if shadow_spec else []),
        },
    )
    print_outputs(output_dir, manifest_path, preview, snippet)


def run_machine(args: argparse.Namespace) -> None:
    require_safe_name(args.asset_name, "asset name")
    root = filename_root_for(args)
    output_dir = output_dir_for(args)
    output_dir.mkdir(parents=True, exist_ok=True)

    source_sheet = resolve_path(args.sheet)
    assert source_sheet is not None
    render_manifest = read_manifest(resolve_path(args.render_manifest))
    main_filename = f"{root}.png"
    staged_sheet = output_dir / main_filename
    copy_png(source_sheet, staged_sheet)
    main_spec = derive_spec(
        staged_sheet,
        render_manifest,
        frame_width=args.frame_width,
        frame_height=args.frame_height,
        line_length=args.line_length,
        frame_count=args.frame_count,
        direction_count=1,
        default_frame_count=1,
        default_direction_count=1,
        manifest_directions_as="ignore",
    )

    shadow_filename = None
    shadow_spec = None
    staged_shadow = None
    if args.shadow_sheet:
        shadow_source = resolve_path(args.shadow_sheet)
        assert shadow_source is not None
        shadow_filename = f"{root}_shadow.png"
        staged_shadow = output_dir / shadow_filename
        copy_png(shadow_source, staged_shadow)
        shadow_spec = derive_spec(
            staged_shadow,
            render_manifest,
            frame_width=args.frame_width,
            frame_height=args.frame_height,
            line_length=args.line_length,
            frame_count=args.frame_count,
            direction_count=1,
            default_frame_count=main_spec["frame_count"],
            default_direction_count=1,
            manifest_directions_as="ignore",
        )

    working_filename = None
    working_spec = None
    staged_working = None
    working_shadow_filename = None
    working_shadow_spec = None
    staged_working_shadow = None
    if args.working_sheet:
        working_source = resolve_path(args.working_sheet)
        assert working_source is not None
        working_manifest = read_manifest(resolve_path(args.working_manifest))
        working_filename = f"{root}_animation.png"
        staged_working = output_dir / working_filename
        copy_png(working_source, staged_working)
        working_spec = derive_spec(
            staged_working,
            working_manifest,
            frame_width=args.working_frame_width,
            frame_height=args.working_frame_height,
            line_length=args.working_line_length,
            frame_count=args.working_frame_count,
            direction_count=1,
            default_frame_count=1,
            default_direction_count=1,
            manifest_directions_as="frame",
        )
        if args.working_shadow_sheet:
            working_shadow_source = resolve_path(args.working_shadow_sheet)
            assert working_shadow_source is not None
            working_shadow_filename = f"{root}_animation_shadow.png"
            staged_working_shadow = output_dir / working_shadow_filename
            copy_png(working_shadow_source, staged_working_shadow)
            working_shadow_spec = derive_spec(
                staged_working_shadow,
                working_manifest,
                frame_width=args.working_frame_width,
                frame_height=args.working_frame_height,
                line_length=args.working_line_length,
                frame_count=args.working_frame_count,
                direction_count=1,
                default_frame_count=working_spec["frame_count"],
                default_direction_count=1,
                manifest_directions_as="frame",
            )

    preview = output_dir / f"{root}.preview.png"
    shadow_preview = output_dir / f"{root}_shadow.preview.png" if staged_shadow else None
    working_preview = output_dir / f"{root}_animation.preview.png" if staged_working else None
    working_shadow_preview = output_dir / f"{root}_animation_shadow.preview.png" if staged_working_shadow else None
    snippet = output_dir / f"{root}.prototype-snippet.lua"
    manifest_path = output_dir / f"{root}.factorio-asset-manifest.json"
    write_sheet_preview(staged_sheet, preview)
    if staged_shadow and shadow_preview:
        write_sheet_preview(staged_shadow, shadow_preview)
    if staged_working and working_preview:
        write_sheet_preview(staged_working, working_preview)
    if staged_working_shadow and working_shadow_preview:
        write_sheet_preview(staged_working_shadow, working_shadow_preview)
    write_machine_snippet(
        snippet,
        args,
        main_filename=main_filename,
        main_spec=main_spec,
        shadow_filename=shadow_filename,
        shadow_spec=shadow_spec,
        working_filename=working_filename,
        working_spec=working_spec,
        working_shadow_filename=working_shadow_filename,
        working_shadow_spec=working_shadow_spec,
    )
    write_manifest(
        manifest_path,
        {
            "mode": "machine",
            "asset_name": args.asset_name,
            "prototype_kind": args.prototype_kind,
            "prototype_template": prototype_template_metadata(args, default_field="graphics_set", mode="machine"),
            "output_dir": display_path(output_dir),
            "files": {
                "sheet": display_path(staged_sheet),
                "preview": display_path(preview),
                "snippet": display_path(snippet),
                "shadow_sheet": display_path(output_dir / shadow_filename) if shadow_filename else None,
                "shadow_preview": display_path(shadow_preview) if shadow_preview else None,
                "working_sheet": display_path(output_dir / working_filename) if working_filename else None,
                "working_preview": display_path(working_preview) if working_preview else None,
                "working_shadow_sheet": display_path(output_dir / working_shadow_filename) if working_shadow_filename else None,
                "working_shadow_preview": display_path(working_shadow_preview) if working_shadow_preview else None,
            },
            "factorio": {
                "path_variable": args.factorio_var,
                "scale": args.scale,
                "shift": parse_shift(args.shift),
                "animation_speed": args.animation_speed if working_filename else None,
            },
            "main_spec": main_spec,
            "shadow_spec": shadow_spec,
            "working_spec": working_spec,
            "working_shadow_spec": working_shadow_spec,
            "warnings": (
                main_spec["warnings"]
                + (shadow_spec["warnings"] if shadow_spec else [])
                + (working_spec["warnings"] if working_spec else [])
                + (working_shadow_spec["warnings"] if working_shadow_spec else [])
            ),
        },
    )
    print_outputs(output_dir, manifest_path, preview, snippet)


def run_icon(args: argparse.Namespace) -> None:
    require_safe_name(args.asset_name, "asset name")
    root = filename_root_for(args)
    output_dir = output_dir_for(args)
    output_dir.mkdir(parents=True, exist_ok=True)

    source = resolve_path(args.source)
    assert source is not None
    icon_filename = f"{root}.png"
    staged_icon = output_dir / icon_filename
    preview = output_dir / f"{root}.preview.png"
    snippet = output_dir / f"{root}.prototype-snippet.lua"
    manifest_path = output_dir / f"{root}.factorio-asset-manifest.json"
    mip_sizes = parse_mip_sizes(args.mip_sizes)

    if not ICON_PREP_SCRIPT.exists():
        raise FileNotFoundError(f"ESIR icon prep helper not found: {ICON_PREP_SCRIPT}")

    command = [
        sys.executable,
        str(ICON_PREP_SCRIPT),
        "--source",
        str(source),
        "--output",
        str(staged_icon),
        "--preview",
        str(preview),
        "--canvas-size",
        str(args.canvas_size),
        "--fit-size",
        str(args.fit_size),
        "--mip-sizes",
        args.mip_sizes,
    ]
    if args.allow_existing_strip:
        command.append("--allow-existing-strip")
    subprocess.run(command, check=True)

    icon_width, icon_height, icon_mode = image_info(staged_icon)
    preview_width, preview_height, _ = image_info(preview)
    icon_mipmaps = 1 + len(mip_sizes)
    write_icon_snippet(snippet, args, icon_filename=icon_filename, icon_mipmaps=icon_mipmaps)
    write_manifest(
        manifest_path,
        {
            "mode": "icon",
            "asset_name": args.asset_name,
            "prototype_kind": args.prototype_kind,
            "prototype_template": prototype_template_metadata(args, default_field="icon", mode="icon"),
            "output_dir": display_path(output_dir),
            "files": {
                "icon": display_path(staged_icon),
                "preview": display_path(preview),
                "snippet": display_path(snippet),
            },
            "source": display_path(source),
            "factorio": {
                "path_variable": args.factorio_var,
                "icon_size": args.canvas_size,
                "icon_mipmaps": icon_mipmaps,
            },
            "icon": {
                "width": icon_width,
                "height": icon_height,
                "mode": icon_mode,
                "preview_width": preview_width,
                "preview_height": preview_height,
                "mip_sizes": mip_sizes,
            },
            "warnings": [],
        },
    )
    print_outputs(output_dir, manifest_path, preview, snippet)


def raw_bundle_roots(bundle_path: Path) -> list[Path]:
    candidates = [bundle_path]
    if bundle_path.name.lower() != "render":
        candidates.append(bundle_path / "Render")
    if bundle_path.name.lower() == ".sheets":
        candidates.append(bundle_path.parent)
    seen: set[Path] = set()
    roots = []
    for path in candidates:
        resolved = path.resolve()
        if resolved not in seen:
            roots.append(path)
            seen.add(resolved)
    return roots


def read_raw_bundle_frames(bundle_path: Path) -> dict[str, list[dict[str, Any]]]:
    if not bundle_path.exists():
        raise FileNotFoundError(f"Render bundle not found: {bundle_path}")

    frames: dict[str, list[dict[str, Any]]] = {layer: [] for layer in BUNDLE_RAW_FOLDERS}
    if bundle_path.is_file() and is_zipfile(bundle_path):
        with ZipFile(bundle_path) as archive:
            for name in archive.namelist():
                normalized = name.replace("\\", "/")
                if not normalized.lower().endswith(".png"):
                    continue
                posix = PurePosixPath(normalized)
                folder = posix.parent.name
                for layer, expected in BUNDLE_RAW_FOLDERS.items():
                    if folder.lower() == expected.lower():
                        frames[layer].append(
                            {
                                "name": posix.name,
                                "source": f"{display_path(bundle_path)}::{normalized}",
                                "data": archive.read(name),
                            }
                        )
                        break
    else:
        for root in raw_bundle_roots(bundle_path):
            if not root.exists() or not root.is_dir():
                continue
            for layer, folder in BUNDLE_RAW_FOLDERS.items():
                folder_path = root / folder
                if not folder_path.exists() or not folder_path.is_dir():
                    continue
                for path in folder_path.glob("*.png"):
                    frames[layer].append(
                        {
                            "name": path.name,
                            "source": display_path(path),
                            "data": path.read_bytes(),
                        }
                    )
    return {
        layer: sorted(items, key=lambda item: natural_key(str(item["name"])))
        for layer, items in frames.items()
        if items
    }


def pack_frame_records(
    frames: list[dict[str, Any]],
    *,
    target_name: str,
    columns: int,
    rows: int,
    black_to_transparent: str,
    single_frame: bool = False,
) -> dict[str, Any]:
    if not frames:
        raise FileNotFoundError(f"No raw frames found for {target_name}")

    selected = frames[:1] if single_frame else frames
    capacity = columns * rows
    if not single_frame and len(selected) > capacity:
        raise ValueError(
            f"{target_name} has {len(selected)} frames but grid {columns}x{rows} holds {capacity}; "
            "increase --grid or render fewer frames."
        )

    first = read_frame_image(selected[0]["data"], black_to_transparent=black_to_transparent)
    tile_w, tile_h = first.size
    if single_frame:
        return {
            "basename": target_name,
            "data": rgba_bytes(first),
            "source": selected[0]["source"],
            "packed_from": [frame["source"] for frame in selected],
            "tile_width": tile_w,
            "tile_height": tile_h,
            "columns": 1,
            "rows": 1,
            "frame_count": 1,
        }

    sheet = Image.new("RGBA", (columns * tile_w, rows * tile_h), (0, 0, 0, 0))
    for index, frame in enumerate(selected):
        image = first if index == 0 else read_frame_image(frame["data"], black_to_transparent=black_to_transparent)
        if image.size != (tile_w, tile_h):
            raise ValueError(
                f"Raw frame size mismatch for {target_name}: {frame['source']} is {image.size}, "
                f"expected {(tile_w, tile_h)}."
            )
        col = index % columns
        row = index // columns
        sheet.alpha_composite(image, (col * tile_w, row * tile_h))

    return {
        "basename": target_name,
        "data": rgba_bytes(sheet),
        "source": f"packed raw frames: {len(selected)}",
        "packed_from": [frame["source"] for frame in selected],
        "tile_width": tile_w,
        "tile_height": tile_h,
        "columns": columns,
        "rows": math.ceil(len(selected) / columns),
        "frame_count": len(selected),
    }


def indexed_sheet_name(target_name: str, index: int) -> str:
    if index == 0:
        return target_name
    path = Path(target_name)
    return f"{path.stem}_{index}{path.suffix}"


def pack_frame_record_chunks(
    frames: list[dict[str, Any]],
    *,
    target_name: str,
    columns: int,
    rows: int,
    black_to_transparent: str,
    single_frame: bool = False,
) -> list[dict[str, Any]]:
    if single_frame:
        return [
            pack_frame_records(
                frames,
                target_name=target_name,
                columns=columns,
                rows=rows,
                black_to_transparent=black_to_transparent,
                single_frame=True,
            )
        ]
    capacity = columns * rows
    if capacity < 1:
        raise ValueError("Raw frame packing grid must hold at least one frame.")
    packed = []
    for sheet_index, start in enumerate(range(0, len(frames), capacity)):
        chunk = frames[start : start + capacity]
        record = pack_frame_records(
            chunk,
            target_name=indexed_sheet_name(target_name, sheet_index),
            columns=columns,
            rows=rows,
            black_to_transparent=black_to_transparent,
            single_frame=False,
        )
        record["sheet_index"] = sheet_index
        record["frame_start"] = start + 1
        record["frame_end"] = start + len(chunk)
        packed.append(record)
    return packed


def pack_raw_bundle_sheets(
    bundle_path: Path,
    sheet_output_dir: Path,
    *,
    grid: tuple[int, int],
    black_to_transparent: str,
) -> dict[str, dict[str, Any]]:
    raw_frames = read_raw_bundle_frames(bundle_path)
    if "base" not in raw_frames:
        raise FileNotFoundError(f"No raw Render/Object PNG frames found in {bundle_path}")

    sheet_output_dir.mkdir(parents=True, exist_ok=True)
    sheets: dict[str, dict[str, Any]] = {}
    for layer, frames in raw_frames.items():
        target_name = BUNDLE_SHEET_BY_LAYER[layer]
        packed_chunks = pack_frame_record_chunks(
            frames,
            target_name=target_name,
            columns=grid[0],
            rows=grid[1],
            black_to_transparent=black_to_transparent,
            single_frame=layer == "water_reflection",
        )
        for packed in packed_chunks:
            destination = sheet_output_dir / packed["basename"]
            save_png_bytes_as_rgba(packed["data"], destination)
            packed.update(
                {
                    "source": display_path(destination),
                    "path": destination,
                    "data": destination.read_bytes(),
                    "packed_sheet": display_path(destination),
                }
            )
            sheets[destination.name.lower()] = packed
    return sheets


def read_bundle_sheets(bundle_path: Path) -> dict[str, dict[str, Any]]:
    if not bundle_path.exists():
        raise FileNotFoundError(f"Render bundle not found: {bundle_path}")

    sheets: dict[str, dict[str, Any]] = {}
    if bundle_path.is_file() and is_zipfile(bundle_path):
        with ZipFile(bundle_path) as archive:
            for name in archive.namelist():
                normalized = name.replace("\\", "/")
                if "/.Sheets/" not in normalized or not normalized.lower().endswith(".png"):
                    continue
                basename = Path(normalized).name
                sheets[basename.lower()] = {
                    "basename": basename,
                    "source": f"{display_path(bundle_path)}::{normalized}",
                    "data": archive.read(name),
                }
        return sheets

    roots = [bundle_path]
    if bundle_path.name.lower() != ".sheets":
        roots.extend([bundle_path / ".Sheets", bundle_path / "Render" / ".Sheets"])
    for root in roots:
        if not root.exists() or not root.is_dir():
            continue
        for path in root.glob("*.png"):
            sheets[path.name.lower()] = {
                "basename": path.name,
                "source": display_path(path),
                "data": path.read_bytes(),
            }
        if sheets:
            return sheets
    raise FileNotFoundError(f"No Render/.Sheets PNG files found in {bundle_path}")


def layer_bundle_entries(available: dict[str, dict[str, Any]], sheet_name: str) -> list[dict[str, Any]]:
    exact = available.get(sheet_name.lower())
    path = Path(sheet_name)
    stem = path.stem
    suffix = path.suffix.lower()
    extras: list[tuple[int, dict[str, Any]]] = []
    for name, entry in available.items():
        candidate = Path(name)
        if candidate.suffix.lower() != suffix:
            continue
        remainder = candidate.stem.removeprefix(stem)
        if remainder.startswith("_") and remainder[1:].isdigit():
            extras.append((int(remainder[1:]), entry))
    entries = []
    if exact:
        entries.append(exact)
    if extras and not exact:
        raise SystemExit(f"Multi-sheet bundle is missing required first sheet {sheet_name}.")
    expected = 1
    for index, _entry in sorted(extras, key=lambda item: item[0]):
        if index != expected:
            raise SystemExit(f"Multi-sheet bundle has a numbering gap after {sheet_name}: expected suffix _{expected}, got _{index}.")
        expected += 1
    entries.extend(entry for _index, entry in sorted(extras, key=lambda item: item[0]))
    return entries


def multisheet_bundle_warnings(available: dict[str, dict[str, Any]]) -> list[str]:
    names = set(available)
    extras: list[str] = []
    for _layer, sheet_name, _suffix in BUNDLE_SHEETS:
        path = Path(sheet_name)
        stem = path.stem
        suffix = path.suffix.lower()
        for name in names:
            candidate = Path(name)
            if candidate.suffix.lower() != suffix:
                continue
            remainder = candidate.stem.removeprefix(stem)
            if remainder.startswith("_") and remainder[1:].isdigit():
                extras.append(candidate.name)
    if not extras:
        return []
    return [
        "Multi-sheet preset bundle detected; generated snippets use Factorio stripes. "
        f"Extra sheet(s): {', '.join(sorted(extras))}."
    ]


def bundle_layout_defaults(args: argparse.Namespace, bundle_path: Path) -> dict[str, Any]:
    manifest_path = resolve_path(args.preset_manifest) if args.preset_manifest else bundle_path / "factorio-preset-render-manifest.json"
    preset_manifest = optional_manifest(manifest_path)
    grid = preset_manifest.get("grid") if isinstance(preset_manifest.get("grid"), list) else None
    line_length = args.line_length or (int(grid[0]) if grid else 8)
    directions = args.direction_count or int(preset_manifest.get("directions") or 1)
    animation_frames = preset_manifest.get("animation_frames")
    total_frames = preset_manifest.get("frames")
    if args.frame_count:
        frame_count = args.frame_count
    elif animation_frames and directions > 1:
        frame_count = int(animation_frames)
    elif total_frames and directions > 1:
        frame_count = max(1, int(total_frames) // directions)
    else:
        frame_count = int(total_frames or 64)
    return {
        "line_length": line_length,
        "frame_count": frame_count,
        "direction_count": directions,
        "manifest_path": display_path(manifest_path) if manifest_path and manifest_path.exists() else None,
    }


def select_bundle_light(args: argparse.Namespace, staged_layers: dict[str, dict[str, Any]], warnings: list[str]) -> str | None:
    if args.light_layer == "none":
        return None
    if args.light_source != "auto":
        if args.light_source in OPAQUE_LIGHTS and not args.allow_opaque_light_layer:
            warnings.append(f"{args.light_source} may be full-alpha; not using it without --allow-opaque-light-layer.")
            return None
        if args.light_source in staged_layers:
            return args.light_source
        warnings.append(f"Requested light source was not present in bundle: {args.light_source}")
        return None
    for key in PREFERRED_ALPHA_LIGHTS:
        if key in staged_layers:
            return key
    if args.allow_opaque_light_layer:
        for key in OPAQUE_LIGHTS:
            if key in staged_layers:
                return key
    return None


def run_render_bundle(args: argparse.Namespace) -> None:
    require_safe_name(args.asset_name, "asset name")
    root = filename_root_for(args)
    output_dir = output_dir_for(args)
    output_dir.mkdir(parents=True, exist_ok=True)

    bundle_path = resolve_path(args.bundle)
    assert bundle_path is not None
    if args.pack_raw_frames:
        sheet_output_dir = (
            resolve_path(args.sheet_output_dir)
            if args.sheet_output_dir
            else output_dir / ".packed-sheets"
        )
        assert sheet_output_dir is not None
        available = pack_raw_bundle_sheets(
            bundle_path,
            sheet_output_dir,
            grid=parse_grid(args.grid),
            black_to_transparent=args.black_to_transparent,
        )
        try:
            bundled_sheets = read_bundle_sheets(bundle_path)
        except FileNotFoundError:
            bundled_sheets = {}
        for basename, entry in bundled_sheets.items():
            available.setdefault(basename, entry)
    else:
        available = read_bundle_sheets(bundle_path)
    layout = bundle_layout_defaults(args, bundle_path)
    staged_layers: dict[str, dict[str, Any]] = {}
    warnings: list[str] = multisheet_bundle_warnings(available)

    for layer_key, bundle_name, suffix in BUNDLE_SHEETS:
        entries = layer_bundle_entries(available, bundle_name)
        if not entries:
            continue
        staged_paths: list[Path] = []
        staged_filenames: list[str] = []
        sources: list[str] = []
        for index, entry in enumerate(entries):
            index_suffix = "" if index == 0 else f"_{index}"
            filename = f"{root}{suffix}{index_suffix}.png"
            staged_path = output_dir / filename
            save_png_bytes_as_rgba(entry["data"], staged_path)
            staged_paths.append(staged_path)
            staged_filenames.append(filename)
            sources.append(entry["source"])
        if layer_key == "water_reflection":
            spec_frame_width = None
            spec_frame_height = None
            spec_line_length = 1
            spec_frame_count = 1
            spec_direction_count = 1
        else:
            spec_frame_width = args.frame_width
            spec_frame_height = args.frame_height
            spec_line_length = int(layout["line_length"])
            spec_frame_count = int(layout["frame_count"])
            spec_direction_count = int(layout["direction_count"])
        if len(staged_paths) > 1 and layer_key != "water_reflection":
            spec = derive_multisheet_spec(
                staged_paths,
                frame_width=spec_frame_width,
                frame_height=spec_frame_height,
                line_length=spec_line_length,
                frame_count=spec_frame_count,
                direction_count=spec_direction_count,
            )
        else:
            spec = derive_spec(
                staged_paths[0],
                {},
                frame_width=spec_frame_width,
                frame_height=spec_frame_height,
                line_length=spec_line_length,
                frame_count=spec_frame_count,
                direction_count=spec_direction_count,
                default_frame_count=spec_frame_count,
                default_direction_count=spec_direction_count,
                manifest_directions_as="ignore",
            )
        preview = output_dir / f"{root}{suffix}.preview.png"
        write_sheet_preview(staged_paths[0], preview)
        staged_layers[layer_key] = {
            "source": sources[0] if len(sources) == 1 else sources,
            "filename": staged_filenames[0],
            "filenames": staged_filenames,
            "path": display_path(staged_paths[0]),
            "paths": [display_path(path) for path in staged_paths],
            "preview": display_path(preview),
            "sheet_mode": "stripes" if spec.get("stripes") else "single",
            "sheets": spec.get("stripes")
            or [
                {
                    "filename": staged_filenames[0],
                    "path": display_path(staged_paths[0]),
                    "width_in_frames": spec.get("line_length"),
                    "height_in_frames": spec.get("rows"),
                    "image_width": spec.get("image_width"),
                    "image_height": spec.get("image_height"),
                }
            ],
            "spec": spec,
        }
        warnings.extend(spec["warnings"])

    if "base" not in staged_layers:
        raise FileNotFoundError("Render bundle did not contain Render/.Sheets/object_0.png.")

    selected_light_key = select_bundle_light(args, staged_layers, warnings)
    snippet = output_dir / f"{root}.prototype-snippet.lua"
    manifest_path = output_dir / f"{root}.factorio-asset-manifest.json"
    write_render_bundle_snippet(
        snippet,
        args,
        staged_layers=staged_layers,
        base_spec=staged_layers["base"]["spec"],
        selected_light_key=selected_light_key,
    )
    write_manifest(
        manifest_path,
        {
            "mode": "render-bundle",
            "asset_name": args.asset_name,
            "prototype_kind": args.prototype_kind,
            "prototype_mode": args.prototype_mode,
            "prototype_template": prototype_template_metadata(
                args,
                default_field="graphics_set" if args.prototype_mode == "machine" else "animation",
                mode=args.prototype_mode,
            ),
            "output_dir": display_path(output_dir),
            "bundle": display_path(bundle_path),
            "factorio_render_preset": {
                "known_blend": "factorioRenderingPreset_v4.blend",
                "source_bundle_shape": "Render/.Sheets/object_0.png plus shadow/light/mask passes",
                "default_assumption": "8x8 sheet, 64 frames, 384px cells unless overridden",
                "raw_frames_packed": args.pack_raw_frames,
                "raw_frame_grid": args.grid if args.pack_raw_frames else None,
                "preset_manifest": layout.get("manifest_path"),
                "effective_layout": {
                    "line_length": layout["line_length"],
                    "frame_count": layout["frame_count"],
                    "direction_count": layout["direction_count"],
                },
            },
            "selected_light_layer": selected_light_key,
            "water_reflection": {
                "emitted": bool(args.emit_water_reflection and "water_reflection" in staged_layers),
                "placement": args.water_reflection_placement,
                "scale": args.water_reflection_scale,
                "shift": parse_shift(args.water_reflection_shift),
            },
            "files": {
                "snippet": display_path(snippet),
                "manifest": display_path(manifest_path),
                "base_preview": staged_layers["base"]["preview"],
                "layers": {
                    key: {
                        item_key: item[item_key]
                        for item_key in [
                            "source",
                            "path",
                            "paths",
                            "preview",
                            "filename",
                            "filenames",
                            "sheet_mode",
                            "sheets",
                        ]
                    }
                    for key, item in staged_layers.items()
                },
            },
            "factorio": {
                "path_variable": args.factorio_var,
                "scale": args.scale,
                "shift": parse_shift(args.shift),
                "animation_speed": args.animation_speed if args.prototype_mode == "machine" else None,
            },
            "main_spec": staged_layers["base"]["spec"],
            "layer_specs": {key: item["spec"] for key, item in staged_layers.items()},
            "warnings": warnings,
        },
    )
    print_outputs(output_dir, manifest_path, Path(staged_layers["base"]["preview"]), snippet)


def manifest_path_value(value: Any) -> Path | None:
    if not value or not isinstance(value, str):
        return None
    if "::" in value:
        return None
    path = Path(value)
    if not path.is_absolute():
        path = Path.cwd() / path
    return path.resolve()


def collect_promotable_pngs(manifest: dict[str, Any]) -> list[Path]:
    files = manifest.get("files", {})
    found: list[Path] = []

    def visit(value: Any, key_hint: str = "") -> None:
        if isinstance(value, dict):
            for key, item in value.items():
                visit(item, key)
            return
        if isinstance(value, list):
            for item in value:
                visit(item, key_hint)
            return
        path = manifest_path_value(value)
        if path is None or path.suffix.lower() != ".png":
            return
        lowered = f"{key_hint} {path.name}".lower()
        allowed_keys = {"path", "paths", "sheet", "shadow_sheet", "working_sheet", "working_shadow_sheet", "icon"}
        if key_hint and key_hint not in allowed_keys:
            return
        if "preview" in lowered or ".packed-sheets" in lowered.replace("\\", "/"):
            return
        found.append(path)

    visit(files)
    deduped: list[Path] = []
    seen: set[Path] = set()
    for path in found:
        if path not in seen:
            deduped.append(path)
            seen.add(path)
    return deduped


def prototype_markers(prototype_name: str, field: str) -> tuple[str, str]:
    return (
        PROMOTION_MARKER_TEMPLATE.format(which="START", prototype_name=prototype_name, field=field),
        PROMOTION_MARKER_TEMPLATE.format(which="END", prototype_name=prototype_name, field=field),
    )


def data_raw_assignment(snippet_text: str, *, prototype_type: str, prototype_name: str, field: str) -> str:
    root = field.split(".", 1)[0]
    pattern = re.compile(rf"(^|\n)(?P<indent>\s*){re.escape(root)}\s*=\s*", re.MULTILINE)
    match = pattern.search(snippet_text)
    if not match:
        raise SystemExit(f"Snippet does not contain a top-level assignment for {root}.")
    rhs = snippet_text[match.end() :].strip()
    if not rhs:
        raise SystemExit(f"Snippet assignment for {root} is empty.")
    return "\n".join(
        [
            f'local prototype = data.raw["{prototype_type}"]["{prototype_name}"]',
            f'if not prototype then error("Missing promoted prototype: {prototype_type}/{prototype_name}") end',
            f"prototype.{field} = {rhs}",
        ]
    )


def manifest_prototype_metadata_check(manifest: dict[str, Any], args: argparse.Namespace) -> dict[str, Any]:
    metadata = manifest.get("prototype_template")
    result: dict[str, Any] = {"available": isinstance(metadata, dict), "checked": {}, "mismatches": []}
    if not isinstance(metadata, dict):
        return result

    explicit = metadata.get("explicit") if isinstance(metadata.get("explicit"), dict) else None
    checks = [
        ("target_prototype_type", "prototype_type", manifest.get("prototype_kind")),
        ("target_prototype_name", "prototype_name", manifest.get("asset_name")),
        ("target_field", "field", None),
    ]
    for metadata_key, args_key, legacy_default in checks:
        manifest_value = metadata.get(metadata_key)
        if not manifest_value:
            continue
        if explicit is not None:
            should_check = bool(explicit.get(metadata_key))
        else:
            should_check = legacy_default is not None and str(manifest_value) != str(legacy_default)
        if not should_check:
            continue
        requested_value = getattr(args, args_key)
        result["checked"][metadata_key] = {
            "manifest": manifest_value,
            "requested": requested_value,
        }
        if str(manifest_value) != str(requested_value):
            result["mismatches"].append(
                f"{metadata_key}={manifest_value!r} does not match --{args_key.replace('_', '-')} {requested_value!r}"
            )
    return result


def prototype_patch_plan(args: argparse.Namespace, manifest: dict[str, Any], *, execute: bool) -> dict[str, Any]:
    missing = [
        name
        for name in ["prototype_file", "prototype_type", "prototype_name", "field"]
        if not getattr(args, name)
    ]
    if missing:
        raise SystemExit("--apply-prototype requires " + ", ".join(f"--{name.replace('_', '-')}" for name in missing))
    if not SAFE_FIELD.match(args.field):
        raise SystemExit(f"--field must be a simple Lua field path, got: {args.field}")
    metadata_check = manifest_prototype_metadata_check(manifest, args)
    if metadata_check["mismatches"]:
        raise SystemExit(
            "Manifest prototype metadata does not match promotion request: "
            + "; ".join(str(item) for item in metadata_check["mismatches"])
        )

    prototype_file = resolve_path(args.prototype_file)
    assert prototype_file is not None
    snippet = manifest_path_value(manifest.get("files", {}).get("snippet"))
    if snippet is None or not snippet.exists():
        raise FileNotFoundError("Manifest does not point to an existing prototype snippet.")

    snippet_text = snippet.read_text(encoding="utf-8")
    snippet_root = args.field.split(".", 1)[0]
    if not re.search(rf"(^|\n)\s*{re.escape(snippet_root)}\s*=", snippet_text):
        raise SystemExit(f"Snippet does not contain an assignment matching --field root: {snippet_root}")

    start_marker, end_marker = prototype_markers(args.prototype_name, args.field)
    plan = {
        "prototype_file": display_path(prototype_file),
        "prototype_type": args.prototype_type,
        "prototype_name": args.prototype_name,
        "field": args.field,
        "snippet": display_path(snippet),
        "marker_start": start_marker,
        "marker_end": end_marker,
        "integration": args.prototype_integration,
        "manifest_prototype_metadata_check": metadata_check,
        "status": "planned",
    }

    if not prototype_file.exists():
        if execute:
            raise FileNotFoundError(f"Prototype file not found: {prototype_file}")
        plan["status"] = "dry-run-missing-prototype-file"
        return plan

    text = prototype_file.read_text(encoding="utf-8")
    if args.require_prototype_identity:
        identity_hits = {
            "prototype_type": args.prototype_type in text,
            "prototype_name": args.prototype_name in text,
        }
        plan["identity_check"] = identity_hits
        if not all(identity_hits.values()):
            message = "prototype identity strings were not both found in target file"
            if execute:
                raise SystemExit(f"{prototype_file}: {message}")
            plan["status"] = "dry-run-identity-required"
            plan["message"] = message
            return plan
    if text.count(start_marker) != 1 or text.count(end_marker) != 1:
        message = "marker pair not found; add explicit ESIR_ASSET_PROMOTE markers before applying"
        if start_marker in text or end_marker in text:
            message = "expected exactly one matching ESIR_ASSET_PROMOTE marker pair"
        if execute:
            raise SystemExit(f"{prototype_file}: {message}")
        plan["status"] = "dry-run-marker-required"
        plan["message"] = message
        return plan

    before, rest = text.split(start_marker, 1)
    _old, after = rest.split(end_marker, 1)
    if text.index(start_marker) > text.index(end_marker):
        raise SystemExit(f"{prototype_file}: promotion start marker appears after end marker.")
    promoted_text = (
        data_raw_assignment(
            snippet_text,
            prototype_type=args.prototype_type,
            prototype_name=args.prototype_name,
            field=args.field,
        )
        if args.prototype_integration == "data-raw-assignment"
        else snippet_text.rstrip()
    )
    replacement = "\n".join(
        [
            start_marker,
            promoted_text,
            end_marker,
        ]
    )
    plan["status"] = "would-patch" if not execute else "patched"
    if execute:
        prototype_file.write_text(before + replacement + after, encoding="utf-8")
    return plan


def run_promote(args: argparse.Namespace) -> None:
    manifest_path = resolve_path(args.manifest)
    assert manifest_path is not None
    if not manifest_path.exists():
        raise FileNotFoundError(f"Manifest not found: {manifest_path}")
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    execute = bool(args.execute)
    dry_run = not execute

    asset_paths = collect_promotable_pngs(manifest)
    if args.expected_asset_count is not None and len(asset_paths) != args.expected_asset_count:
        raise SystemExit(
            f"Expected {args.expected_asset_count} promotable PNGs, found {len(asset_paths)} in {manifest_path}."
        )
    copy_plan: list[dict[str, Any]] = []
    if args.copy_assets:
        if not args.graphics_destination:
            raise SystemExit("--copy-assets requires --graphics-destination")
        destination_root = resolve_path(args.graphics_destination)
        assert destination_root is not None
        for source in asset_paths:
            target = destination_root / source.name
            copy_plan.append({"source": display_path(source), "target": display_path(target), "exists": source.exists()})
            if execute:
                if not source.exists():
                    raise FileNotFoundError(f"Staged asset not found: {source}")
                ensure_parent(target)
                shutil.copy2(source, target)

    prototype_plan = None
    if args.apply_prototype:
        prototype_plan = prototype_patch_plan(args, manifest, execute=execute)

    plan = {
        "mode": "promote",
        "dry_run": dry_run,
        "manifest": display_path(manifest_path),
        "asset_name": manifest.get("asset_name"),
        "copy_assets": bool(args.copy_assets),
        "apply_prototype": bool(args.apply_prototype),
        "assets": [display_path(path) for path in asset_paths],
        "copies": copy_plan,
        "prototype": prototype_plan,
        "warnings": [
            "Promotion is intentionally narrow: no copy or prototype edit occurs unless --execute is passed.",
            "Prototype patching only replaces explicit ESIR_ASSET_PROMOTE marker blocks.",
        ],
    }
    if args.plan_output:
        plan_output = resolve_path(args.plan_output)
        assert plan_output is not None
        write_manifest(plan_output, plan)
    print(json.dumps(plan, indent=2))


def gallery_manifest_paths(args: argparse.Namespace) -> list[Path]:
    paths = [Path(item) for item in args.manifest]
    for pattern in args.manifest_glob:
        paths.extend(Path(item) for item in glob.glob(pattern, recursive=True))
    return sorted({path for path in paths if path.exists()})


def gallery_entries_from_manifest(path: Path, *, include_snippet: bool) -> dict[str, Any]:
    data = json.loads(path.read_text(encoding="utf-8-sig"))
    images: list[dict[str, Any]] = []

    def visit(value: Any, key: str = "") -> None:
        if isinstance(value, dict):
            for k, item in value.items():
                visit(item, k)
        elif isinstance(value, list):
            for item in value:
                visit(item, key)
        elif isinstance(value, str) and value.lower().endswith(".png") and "::" not in value:
            candidate = Path(value)
            if candidate.exists():
                images.append(
                    {
                        "path": display_path(candidate),
                        "role": key or "png",
                        "preview": "preview" in f"{key} {value}".lower(),
                    }
                )

    visit(data.get("files", {}))
    snippet_text = ""
    snippet = manifest_path_value(data.get("files", {}).get("snippet"))
    if include_snippet and snippet and snippet.exists():
        snippet_text = snippet.read_text(encoding="utf-8")[:16000]
    return {
        "manifest": display_path(path),
        "asset_name": data.get("asset_name"),
        "mode": data.get("mode"),
        "prototype_kind": data.get("prototype_kind"),
        "prototype_template": data.get("prototype_template"),
        "warnings": data.get("warnings", []),
        "images": images,
        "snippet": snippet_text,
    }


def href_for(path_text: str, base: Path) -> str:
    path = Path(path_text)
    return os.path.relpath(path.resolve(), base.resolve()).replace("\\", "/")


def run_gallery(args: argparse.Namespace) -> None:
    manifests = gallery_manifest_paths(args)
    if not manifests:
        raise FileNotFoundError("No manifests matched --manifest/--manifest-glob.")
    output = Path(args.output)
    entries = [gallery_entries_from_manifest(path, include_snippet=args.include_snippet) for path in manifests]
    output.parent.mkdir(parents=True, exist_ok=True)
    cards: list[str] = []
    for entry in entries:
        image_cards = []
        for image in entry["images"]:
            src = href_for(image["path"], output.parent)
            label = f"{image['role']} - {Path(image['path']).name}"
            image_cards.append(
                f'<figure><a href="{html.escape(src)}"><img src="{html.escape(src)}" alt="{html.escape(label)}"></a><figcaption>{html.escape(label)}</figcaption></figure>'
            )
        warnings = "".join(f"<li>{html.escape(str(warning))}</li>" for warning in entry.get("warnings", [])) or "<li>None</li>"
        snippet = f"<pre>{html.escape(entry.get('snippet', ''))}</pre>" if args.include_snippet and entry.get("snippet") else ""
        cards.append(
            "\n".join(
                [
                    '<section class="asset">',
                    f"<h2>{html.escape(str(entry.get('asset_name')))}</h2>",
                    f"<p>{html.escape(str(entry.get('mode')))} | {html.escape(str(entry.get('prototype_kind')))} | <code>{html.escape(str(entry.get('manifest')))}</code></p>",
                    f"<ul>{warnings}</ul>",
                    '<div class="grid">' + "".join(image_cards) + "</div>",
                    snippet,
                    "</section>",
                ]
            )
        )
    output.write_text(
        f"""<!doctype html>
<html lang=\"en\"><head><meta charset=\"utf-8\"><title>{html.escape(args.title)}</title>
<style>body{{font-family:Segoe UI,sans-serif;margin:24px;background:#151515;color:#ece8df}}.asset{{border-top:1px solid #444;padding:18px 0}}.grid{{display:grid;grid-template-columns:repeat(auto-fill,minmax(220px,1fr));gap:14px}}figure{{margin:0;background:#20201d;border:1px solid #45423b;padding:10px}}img{{max-width:100%;background:#2c2c2c}}pre{{overflow:auto;background:#0f0f0f;padding:12px}}</style>
</head><body><h1>{html.escape(args.title)}</h1>{''.join(cards)}</body></html>""",
        encoding="utf-8",
    )
    if args.approval_json:
        write_manifest(Path(args.approval_json), {"title": args.title, "manifests": [display_path(path) for path in manifests], "entries": entries})
    print(f"gallery={display_path(output)}")
    if args.approval_json:
        print(f"approval_json={display_path(Path(args.approval_json))}")


def print_outputs(output_dir: Path, manifest: Path, preview: Path, snippet: Path) -> None:
    print(f"output_dir={display_path(output_dir)}")
    print(f"manifest={display_path(manifest)}")
    print(f"preview={display_path(preview)}")
    print(f"snippet={display_path(snippet)}")


def main() -> None:
    args = parse_args()
    if args.mode == "entity":
        run_entity(args)
    elif args.mode == "machine":
        run_machine(args)
    elif args.mode == "icon":
        run_icon(args)
    elif args.mode in {"render-bundle", "bundle"}:
        run_render_bundle(args)
    elif args.mode == "promote":
        run_promote(args)
    elif args.mode == "gallery":
        run_gallery(args)
    else:
        raise SystemExit(f"Unknown mode: {args.mode}")


if __name__ == "__main__":
    main()
