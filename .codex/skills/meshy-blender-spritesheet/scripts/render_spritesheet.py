#!/usr/bin/env python3
"""Render a 3D model into transparent directional sprite frames and a sheet.

Run with Blender:
  blender --background --python render_spritesheet.py -- --input model.glb --output-sheet output/sheet.png
"""

from __future__ import annotations

import argparse
import json
import math
import os
import sys
from pathlib import Path

import bpy
from mathutils import Vector


def parse_args() -> argparse.Namespace:
    argv = sys.argv
    if "--" in argv:
        argv = argv[argv.index("--") + 1 :]
    else:
        argv = []

    parser = argparse.ArgumentParser(description="Render a model into directional sprite frames and a packed sheet.")
    parser.add_argument("--input", help="GLB, GLTF, OBJ, or FBX model path.")
    parser.add_argument("--test-cube", action="store_true", help="Render a generated cube instead of importing a model.")
    parser.add_argument("--base-dir", help="Resolve relative input/output paths from this directory. Defaults to current shell directory.")
    parser.add_argument("--output-sheet", required=True, help="Packed spritesheet PNG path.")
    parser.add_argument("--frames-dir", help="Directory for individual frame PNGs.")
    parser.add_argument("--manifest", help="JSON manifest path. Defaults next to output sheet.")
    parser.add_argument("--directions", type=int, default=8, help="Number of yaw directions to render.")
    parser.add_argument("--frame-size", type=int, default=256, help="Square frame size in pixels.")
    parser.add_argument("--columns", type=int, help="Spritesheet columns. Defaults to directions in one row.")
    parser.add_argument("--padding", type=int, default=0, help="Transparent pixels between packed frames.")
    parser.add_argument("--elevation", type=float, default=60.0, help="Camera elevation angle in degrees.")
    parser.add_argument("--yaw-offset", type=float, default=45.0, help="First camera yaw angle in degrees.")
    parser.add_argument("--ortho-scale", type=float, help="Override orthographic camera scale.")
    parser.add_argument("--resolution-scale", type=int, default=100, help="Blender render resolution percentage.")
    parser.add_argument("--engine", choices=["eevee", "cycles"], default="eevee")
    parser.add_argument("--samples", type=int, default=64)
    parser.add_argument("--exposure", type=float, default=0.0, help="Render exposure adjustment for dark imported materials.")
    parser.add_argument("--gamma", type=float, default=1.0, help="Render gamma adjustment.")
    parser.add_argument("--world-strength", type=float, default=0.025, help="Neutral world color strength used as ambient lift.")
    parser.add_argument("--key-energy", type=float, default=450.0, help="Key area light energy.")
    parser.add_argument("--fill-energy", type=float, default=80.0, help="Fill/rim point light energy.")
    parser.add_argument("--min-alpha-margin", type=int, default=16, help="Warn when non-transparent pixels are closer than this many pixels to a frame edge.")
    parser.add_argument("--fail-alpha-margin", action="store_true", help="Exit non-zero when --min-alpha-margin is violated.")
    parser.add_argument("--auto-ortho-scale", dest="auto_ortho_scale", action="store_true", default=True, help="Increase orthographic scale and rerender until --min-alpha-margin passes. Enabled by default.")
    parser.add_argument("--no-auto-ortho-scale", dest="auto_ortho_scale", action="store_false", help="Disable automatic orthographic scale fitting.")
    parser.add_argument("--auto-ortho-step", type=float, default=1.12, help="Multiplier used by --auto-ortho-scale after a margin failure.")
    parser.add_argument("--auto-ortho-max", type=float, default=8.0, help="Maximum orthographic scale allowed by --auto-ortho-scale.")
    parser.add_argument(
        "--factorio-preset-defaults",
        action="store_true",
        help="Use local factorioRenderingPreset_v4-inspired defaults: 384px, 8x8/64 directions, Cycles 256.",
    )
    parser.add_argument("--save-blend", help="Optional .blend output for inspection.")
    parser.add_argument("--no-normalize", action="store_true", help="Do not center and uniformly scale the imported model.")
    args = parser.parse_args(argv)

    if args.factorio_preset_defaults:
        seen = lambda flag: any(part == flag or part.startswith(flag + "=") for part in argv)
        if not seen("--frame-size"):
            args.frame_size = 384
        if not seen("--directions"):
            args.directions = 64
        if not seen("--columns"):
            args.columns = 8
        if not seen("--engine"):
            args.engine = "cycles"
        if not seen("--samples"):
            args.samples = 256
        if not seen("--elevation"):
            args.elevation = 45.0
        if not seen("--yaw-offset"):
            args.yaw_offset = -90.0

    if not args.input and not args.test_cube:
        parser.error("Provide --input or --test-cube.")
    if args.directions < 1:
        parser.error("--directions must be >= 1.")
    if args.frame_size < 16:
        parser.error("--frame-size must be >= 16.")
    if args.auto_ortho_step <= 1.0:
        parser.error("--auto-ortho-step must be greater than 1.")
    if args.auto_ortho_max <= 0:
        parser.error("--auto-ortho-max must be greater than 0.")
    return args


def resolve_path(value: str | None, base_dir: Path) -> Path | None:
    if value is None:
        return None
    path = Path(value)
    if path.is_absolute():
        return path
    return (base_dir / path).resolve()


def clear_scene() -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete()


def import_model(path: Path) -> None:
    suffix = path.suffix.lower()
    if suffix in {".glb", ".gltf"}:
        bpy.ops.import_scene.gltf(filepath=str(path))
    elif suffix == ".obj":
        bpy.ops.wm.obj_import(filepath=str(path))
    elif suffix == ".fbx":
        bpy.ops.import_scene.fbx(filepath=str(path))
    else:
        raise SystemExit(f"Unsupported input extension: {suffix}")


def create_test_cube() -> None:
    bpy.ops.mesh.primitive_cube_add(size=2.0, location=(0, 0, 0))
    cube = bpy.context.object
    cube.name = "test_cube"
    mat = bpy.data.materials.new("test_cube_dark_metal")
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs["Base Color"].default_value = (0.04, 0.06, 0.08, 1.0)
        bsdf.inputs["Metallic"].default_value = 0.6
        bsdf.inputs["Roughness"].default_value = 0.45
    cube.data.materials.append(mat)


def mesh_objects() -> list[bpy.types.Object]:
    return [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]


def bounds_for(objects: list[bpy.types.Object]) -> tuple[Vector, Vector]:
    points = []
    for obj in objects:
        points.extend(obj.matrix_world @ Vector(corner) for corner in obj.bound_box)
    if not points:
        raise SystemExit("No mesh objects found after import.")
    mins = Vector((min(p.x for p in points), min(p.y for p in points), min(p.z for p in points)))
    maxs = Vector((max(p.x for p in points), max(p.y for p in points), max(p.z for p in points)))
    return mins, maxs


def normalize_scene() -> tuple[Vector, float]:
    objects = mesh_objects()
    mins, maxs = bounds_for(objects)
    center = (mins + maxs) * 0.5
    size = max((maxs - mins).x, (maxs - mins).y, (maxs - mins).z)
    scale = 2.0 / size if size > 0 else 1.0

    for obj in objects:
        obj.location -= center
        obj.scale *= scale

    bpy.context.view_layer.update()
    mins, maxs = bounds_for(objects)
    radius = max((maxs - mins).length * 0.5, 1.0)
    return (mins + maxs) * 0.5, radius


def setup_render(args: argparse.Namespace) -> None:
    scene = bpy.context.scene
    scene.render.resolution_x = args.frame_size
    scene.render.resolution_y = args.frame_size
    scene.render.resolution_percentage = args.resolution_scale
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.view_settings.view_transform = "Standard"
    scene.view_settings.look = "Medium High Contrast"
    scene.view_settings.exposure = args.exposure
    scene.view_settings.gamma = args.gamma

    if args.engine == "cycles":
        scene.render.engine = "CYCLES"
        scene.cycles.samples = args.samples
        scene.cycles.use_denoising = True
    else:
        scene.render.engine = "BLENDER_EEVEE_NEXT"
        scene.eevee.taa_render_samples = args.samples


def setup_lighting(args: argparse.Namespace) -> None:
    world = bpy.context.scene.world or bpy.data.worlds.new("World")
    bpy.context.scene.world = world
    world.color = (args.world_strength * 0.8, args.world_strength, args.world_strength * 1.2)

    bpy.ops.object.light_add(type="AREA", location=(-3.0, -4.0, 5.5))
    key = bpy.context.object
    key.name = "sprite_key_light"
    key.data.energy = args.key_energy
    key.data.size = 4.0

    bpy.ops.object.light_add(type="POINT", location=(3.5, 2.5, 3.0))
    fill = bpy.context.object
    fill.name = "sprite_rim_fill"
    fill.data.energy = args.fill_energy


def setup_camera(center: Vector, radius: float, args: argparse.Namespace) -> bpy.types.Object:
    bpy.ops.object.empty_add(type="PLAIN_AXES", location=center)
    target = bpy.context.object
    target.name = "sprite_camera_target"

    bpy.ops.object.camera_add()
    camera = bpy.context.object
    bpy.context.scene.camera = camera
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = args.ortho_scale or max(radius * 2.35, 2.4)

    constraint = camera.constraints.new(type="TRACK_TO")
    constraint.track_axis = "TRACK_NEGATIVE_Z"
    constraint.up_axis = "UP_Y"
    constraint.target = target
    return camera


def set_camera_angle(camera: bpy.types.Object, center: Vector, radius: float, yaw_deg: float, elevation_deg: float) -> None:
    yaw = math.radians(yaw_deg)
    elevation = math.radians(elevation_deg)
    distance = max(radius * 4.0, 6.0)
    horizontal = math.cos(elevation) * distance
    camera.location = (
        center.x + math.cos(yaw) * horizontal,
        center.y + math.sin(yaw) * horizontal,
        center.z + math.sin(elevation) * distance,
    )


def render_frames(args: argparse.Namespace, camera: bpy.types.Object, center: Vector, radius: float, frames_dir: Path) -> list[Path]:
    frames_dir.mkdir(parents=True, exist_ok=True)
    paths = []
    for idx in range(args.directions):
        yaw = args.yaw_offset + (360.0 * idx / args.directions)
        set_camera_angle(camera, center, radius, yaw, args.elevation)
        bpy.context.view_layer.update()
        frame_path = frames_dir / f"frame_{idx:03d}.png"
        bpy.context.scene.render.filepath = str(frame_path)
        bpy.ops.render.render(write_still=True)
        paths.append(frame_path)
    return paths


def pack_sheet(frame_paths: list[Path], output_sheet: Path, columns: int, padding: int) -> tuple[int, int]:
    first = bpy.data.images.load(str(frame_paths[0]), check_existing=False)
    tile_w, tile_h = first.size
    bpy.data.images.remove(first)

    rows = math.ceil(len(frame_paths) / columns)
    sheet_w = columns * tile_w + max(columns - 1, 0) * padding
    sheet_h = rows * tile_h + max(rows - 1, 0) * padding
    pixels = [0.0] * (sheet_w * sheet_h * 4)

    for idx, frame_path in enumerate(frame_paths):
        image = bpy.data.images.load(str(frame_path), check_existing=False)
        rgba = list(image.pixels)
        col = idx % columns
        row = rows - 1 - (idx // columns)
        x0 = col * (tile_w + padding)
        y0 = row * (tile_h + padding)
        for y in range(tile_h):
            for x in range(tile_w):
                src = (y * tile_w + x) * 4
                dst = ((y0 + y) * sheet_w + (x0 + x)) * 4
                pixels[dst : dst + 4] = rgba[src : src + 4]
        bpy.data.images.remove(image)

    sheet = bpy.data.images.new("spritesheet", width=sheet_w, height=sheet_h, alpha=True)
    sheet.pixels = pixels
    output_sheet.parent.mkdir(parents=True, exist_ok=True)
    sheet.save_render(str(output_sheet))
    bpy.data.images.remove(sheet)
    return sheet_w, sheet_h


def alpha_bounds_for_frame(frame_path: Path, alpha_threshold: float = 0.03) -> dict[str, object]:
    image = bpy.data.images.load(str(frame_path), check_existing=False)
    width, height = image.size
    pixels = list(image.pixels)
    min_x = width
    min_y = height
    max_x = -1
    max_y = -1
    for y in range(height):
        row = y * width * 4
        for x in range(width):
            alpha = pixels[row + x * 4 + 3]
            if alpha > alpha_threshold:
                min_x = min(min_x, x)
                min_y = min(min_y, y)
                max_x = max(max_x, x)
                max_y = max(max_y, y)
    bpy.data.images.remove(image)
    if max_x < 0:
        return {"path": str(frame_path), "empty": True, "width": width, "height": height}
    margins = {
        "left": min_x,
        "right": width - 1 - max_x,
        "bottom": min_y,
        "top": height - 1 - max_y,
    }
    return {
        "path": str(frame_path),
        "empty": False,
        "width": width,
        "height": height,
        "bounds": {"min_x": min_x, "min_y": min_y, "max_x": max_x, "max_y": max_y},
        "margins": margins,
        "minimum_margin": min(margins.values()),
    }


def analyze_alpha_margins(frame_paths: list[Path], min_margin: int) -> tuple[list[dict[str, object]], list[str]]:
    records = [alpha_bounds_for_frame(path) for path in frame_paths]
    warnings = []
    if min_margin > 0:
        for index, record in enumerate(records):
            margin = record.get("minimum_margin")
            if isinstance(margin, int) and margin < min_margin:
                warnings.append(f"frame_{index:03d} alpha margin {margin}px is below --min-alpha-margin {min_margin}px.")
    return records, warnings


def next_ortho_scale_from_alpha(
    records: list[dict[str, object]],
    current_scale: float,
    min_margin: int,
    step: float,
    max_scale: float,
) -> float | None:
    if min_margin <= 0:
        return None
    needed = current_scale * step
    for record in records:
        bounds = record.get("bounds")
        width = record.get("width")
        height = record.get("height")
        if not isinstance(bounds, dict) or not isinstance(width, int) or not isinstance(height, int):
            continue
        target_w = max(width - 2 * min_margin, 1)
        target_h = max(height - 2 * min_margin, 1)
        content_w = int(bounds["max_x"]) - int(bounds["min_x"]) + 1
        content_h = int(bounds["max_y"]) - int(bounds["min_y"]) + 1
        needed = max(needed, current_scale * content_w / target_w * 1.02)
        needed = max(needed, current_scale * content_h / target_h * 1.02)
    if needed > max_scale:
        return max_scale if current_scale < max_scale else None
    return needed if needed > current_scale else None


def write_manifest(
    path: Path,
    args: argparse.Namespace,
    frame_paths: list[Path],
    sheet_size: tuple[int, int],
    alpha_bounds: list[dict[str, object]],
    warnings: list[str],
    ortho_scale: float,
    auto_ortho_attempts: list[dict[str, object]],
) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    manifest = {
        "input": args.input,
        "base_dir": str(Path(args.base_dir).resolve()) if args.base_dir else os.getcwd(),
        "output_sheet": str(Path(args.output_sheet)),
        "frames": [str(path) for path in frame_paths],
        "directions": args.directions,
        "frame_size": args.frame_size,
        "columns": args.columns or args.directions,
        "padding": args.padding,
        "sheet_width": sheet_size[0],
        "sheet_height": sheet_size[1],
        "elevation": args.elevation,
        "yaw_offset": args.yaw_offset,
        "ortho_scale": ortho_scale,
        "engine": args.engine,
        "samples": args.samples,
        "exposure": args.exposure,
        "gamma": args.gamma,
        "world_strength": args.world_strength,
        "key_energy": args.key_energy,
        "fill_energy": args.fill_energy,
        "min_alpha_margin": args.min_alpha_margin,
        "auto_ortho_scale": args.auto_ortho_scale,
        "auto_ortho_attempts": auto_ortho_attempts,
        "alpha_bounds": alpha_bounds,
        "warnings": warnings,
        "factorio_preset_defaults": args.factorio_preset_defaults,
        "factorio_preset_reference": "factorioRenderingPreset_v4.blend" if args.factorio_preset_defaults else None,
    }
    path.write_text(json.dumps(manifest, indent=2), encoding="utf-8")


def render_with_optional_auto_ortho(
    args: argparse.Namespace,
    camera: bpy.types.Object,
    center: Vector,
    radius: float,
    frames_dir: Path,
) -> tuple[list[Path], list[dict[str, object]], list[str], list[dict[str, object]], float]:
    attempts = []
    scale = float(camera.data.ortho_scale)
    while True:
        camera.data.ortho_scale = scale
        frame_paths = render_frames(args, camera, center, radius, frames_dir)
        alpha_bounds, warnings = analyze_alpha_margins(frame_paths, args.min_alpha_margin)
        min_margin = None
        for record in alpha_bounds:
            margin = record.get("minimum_margin")
            if isinstance(margin, int):
                min_margin = margin if min_margin is None else min(min_margin, margin)
        attempts.append({"ortho_scale": scale, "minimum_margin": min_margin, "warnings": warnings})
        if not args.auto_ortho_scale or not warnings:
            return frame_paths, alpha_bounds, warnings, attempts, scale
        next_scale = next_ortho_scale_from_alpha(
            alpha_bounds,
            scale,
            args.min_alpha_margin,
            args.auto_ortho_step,
            args.auto_ortho_max,
        )
        if next_scale is None:
            return frame_paths, alpha_bounds, warnings, attempts, scale
        scale = next_scale


def main() -> None:
    args = parse_args()
    base_dir = resolve_path(args.base_dir, Path.cwd()) if args.base_dir else Path.cwd().resolve()
    output_sheet = resolve_path(args.output_sheet, base_dir)
    assert output_sheet is not None
    frames_dir = resolve_path(args.frames_dir, base_dir) if args.frames_dir else output_sheet.with_suffix("").parent / (output_sheet.stem + "_frames")
    manifest = resolve_path(args.manifest, base_dir) if args.manifest else output_sheet.with_suffix(".manifest.json")
    assert frames_dir is not None
    assert manifest is not None
    columns = args.columns or args.directions

    clear_scene()
    if args.test_cube:
        create_test_cube()
    else:
        input_path = resolve_path(args.input, base_dir)
        assert input_path is not None
        import_model(input_path)

    center, radius = ((Vector((0, 0, 0)), 1.0) if args.no_normalize else normalize_scene())
    setup_render(args)
    setup_lighting(args)
    camera = setup_camera(center, radius, args)
    frame_paths, alpha_bounds, warnings, auto_ortho_attempts, final_ortho_scale = render_with_optional_auto_ortho(
        args,
        camera,
        center,
        radius,
        frames_dir,
    )
    sheet_size = pack_sheet(frame_paths, output_sheet, columns, args.padding)
    write_manifest(manifest, args, frame_paths, sheet_size, alpha_bounds, warnings, final_ortho_scale, auto_ortho_attempts)
    if warnings and args.fail_alpha_margin:
        raise SystemExit("Alpha margin check failed; see manifest warnings.")

    if args.save_blend:
        bpy.ops.wm.save_as_mainfile(filepath=str(Path(args.save_blend)))

    print(f"Spritesheet: {output_sheet}")
    print(f"Manifest: {manifest}")


if __name__ == "__main__":
    main()
