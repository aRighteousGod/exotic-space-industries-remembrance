#!/usr/bin/env python3
"""Render one rolling-stock GLB through rolling_stock_template.blend.

The template owns the difficult part: the RollingStockStretchedRotator empty has
the 0..255 normal rotation animation and 256..415 elevated-rail slope animation.
This script only swaps in an ESIR GLB, fits it, and renders a requested frame
range without saving changes back to the template.
"""

from __future__ import annotations

import argparse
import json
import math
import os
import sys
from pathlib import Path

import bpy
from mathutils import Matrix, Vector


PLACEHOLDER_NAMES = {"Body", "SuzanneBack", "SuzanneFront"}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", required=True, help="GLB/GLTF path to import.")
    parser.add_argument("--asset-name", required=True, help="Name written into the render manifest.")
    parser.add_argument("--output-dir", required=True, help="Directory for rendered PNG frames.")
    parser.add_argument("--start", type=int, required=True, help="First template frame to render.")
    parser.add_argument("--end", type=int, required=True, help="Last template frame to render.")
    parser.add_argument("--frames", default=None, help="Optional comma-separated explicit frame list to render instead of every frame in start..end.")
    parser.add_argument("--resolution", type=int, default=800, help="Square input-frame resolution.")
    parser.add_argument("--samples", type=int, default=64, help="Cycles sample count.")
    parser.add_argument("--device", choices=("CPU", "GPU"), default="CPU", help="Cycles compute device.")
    parser.add_argument("--fit-length", type=float, default=None, help="Uniform scale so imported X length equals this many template units.")
    parser.add_argument("--fit-width", type=float, default=None, help="Uniform scale so imported Y width equals this many template units.")
    parser.add_argument("--scale", type=float, default=None, help="Explicit uniform import scale.")
    parser.add_argument("--rotation-z-degrees", type=float, default=0.0, help="Local Z rotation applied to the imported asset root.")
    parser.add_argument("--x-offset", type=float, default=0.0, help="Local X offset after centering and scaling.")
    parser.add_argument("--y-offset", type=float, default=0.0, help="Local Y offset after centering and scaling.")
    parser.add_argument("--bottom-z", type=float, default=0.75, help="Local Z for imported mesh bottom before animation.")
    parser.add_argument("--ortho-scale", type=float, default=12.5, help="Camera orthographic scale for the rolling-stock render envelope.")
    parser.add_argument("--view-transform", default=None, help="Optional color-management view transform override.")
    parser.add_argument("--exposure", type=float, default=None, help="Optional color-management exposure override.")
    parser.add_argument("--world-strength-scale", type=float, default=1.0, help="Multiply HDRI/world strength nodes by this value.")
    parser.add_argument("--area-fill-energy", type=float, default=0.0, help="Optional broad soft area-fill light energy.")
    parser.add_argument("--area-fill-size", type=float, default=8.0, help="Optional broad soft area-fill light size.")
    parser.add_argument("--metallic", type=float, default=0.0, help="Override unlinked Principled metallic inputs.")
    parser.add_argument("--roughness", type=float, default=0.78, help="Override unlinked Principled roughness inputs.")
    parser.add_argument("--force-opaque", action="store_true", help="Force imported materials to opaque alpha/blending.")
    parser.add_argument("--keep-placeholders", action="store_true", help="Do not remove the template Suzanne meshes.")
    parser.add_argument("--dry-run", action="store_true", help="Import, place, and write manifest without rendering.")
    script_args = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    return parser.parse_args(script_args)


def vector_list(value: Vector) -> list[float]:
    return [round(float(v), 6) for v in value]


def mesh_bounds(objects: list[bpy.types.Object]) -> dict[str, Vector | int]:
    mins = Vector((float("inf"), float("inf"), float("inf")))
    maxs = Vector((float("-inf"), float("-inf"), float("-inf")))
    mesh_count = 0

    for obj in objects:
        if obj.type != "MESH":
            continue
        mesh_count += 1
        for corner in obj.bound_box:
            point = obj.matrix_world @ Vector(corner)
            mins.x = min(mins.x, point.x)
            mins.y = min(mins.y, point.y)
            mins.z = min(mins.z, point.z)
            maxs.x = max(maxs.x, point.x)
            maxs.y = max(maxs.y, point.y)
            maxs.z = max(maxs.z, point.z)

    if mesh_count == 0:
        raise RuntimeError("Imported asset did not create any mesh objects.")

    center = (mins + maxs) * 0.5
    dimensions = maxs - mins
    return {
        "min": mins,
        "max": maxs,
        "center": center,
        "dimensions": dimensions,
        "mesh_count": mesh_count,
    }


def serializable_bounds(bounds: dict[str, Vector | int]) -> dict[str, list[float] | int]:
    return {
        "min": vector_list(bounds["min"]),
        "max": vector_list(bounds["max"]),
        "center": vector_list(bounds["center"]),
        "dimensions": vector_list(bounds["dimensions"]),
        "mesh_count": int(bounds["mesh_count"]),
    }


def parse_frame_list(raw: str | None, start: int, end: int) -> list[int] | None:
    if not raw:
        return None
    frames: list[int] = []
    for token in raw.split(","):
        token = token.strip()
        if not token:
            continue
        frame = int(token)
        if frame < start or frame > end:
            raise ValueError(f"Frame {frame} falls outside requested range {start}..{end}.")
        frames.append(frame)
    if not frames:
        raise ValueError("--frames did not contain any frame numbers.")
    return frames


def remove_placeholders() -> None:
    for name in PLACEHOLDER_NAMES:
        obj = bpy.data.objects.get(name)
        if obj:
            bpy.data.objects.remove(obj, do_unlink=True)


def import_asset(path: Path) -> tuple[list[bpy.types.Object], list[bpy.types.Object]]:
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(path.resolve()))
    imported = sorted(set(bpy.data.objects) - before, key=lambda obj: obj.name)
    imported_names = {obj.name for obj in imported}
    roots = [obj for obj in imported if obj.parent is None or obj.parent.name not in imported_names]
    return imported, roots


def set_material_defaults(imported: list[bpy.types.Object], metallic: float, roughness: float, force_opaque: bool) -> dict[str, int]:
    changed = {"materials": 0, "principled_nodes": 0}
    materials = sorted(
        {slot.material for obj in imported if obj.type == "MESH" for slot in obj.material_slots if slot.material},
        key=lambda material: material.name,
    )

    for material in materials:
        changed["materials"] += 1
        if force_opaque:
            material.blend_method = "OPAQUE"
            material.diffuse_color[3] = 1.0

        if not material.use_nodes:
            continue

        for node in material.node_tree.nodes:
            if node.type != "BSDF_PRINCIPLED":
                continue
            changed["principled_nodes"] += 1
            metallic_input = node.inputs.get("Metallic")
            roughness_input = node.inputs.get("Roughness")
            alpha_input = node.inputs.get("Alpha")
            if metallic_input and not metallic_input.is_linked:
                metallic_input.default_value = metallic
            if roughness_input and not roughness_input.is_linked:
                roughness_input.default_value = roughness
            if force_opaque and alpha_input and not alpha_input.is_linked:
                alpha_input.default_value = 1.0

    return changed


def configure_render(args: argparse.Namespace) -> None:
    scene = bpy.context.scene
    scene.frame_start = args.start
    scene.frame_end = args.end
    scene.frame_step = 1
    scene.render.resolution_x = args.resolution
    scene.render.resolution_y = args.resolution
    scene.render.resolution_percentage = 100
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.image_settings.compression = 30

    if hasattr(scene, "cycles"):
        scene.cycles.samples = args.samples
        scene.cycles.preview_samples = min(args.samples, 64)
        scene.cycles.use_denoising = True
        scene.cycles.device = args.device

    if args.ortho_scale is not None:
        camera = scene.camera
        if not camera or camera.type != "CAMERA":
            raise RuntimeError("Template scene camera is missing.")
        camera.data.ortho_scale = args.ortho_scale

    if args.view_transform:
        scene.view_settings.view_transform = args.view_transform
    if args.exposure is not None:
        scene.view_settings.exposure = args.exposure

    world = scene.world
    if world and world.use_nodes and args.world_strength_scale != 1.0:
        for node in world.node_tree.nodes:
            if node.type != "BACKGROUND":
                continue
            strength = node.inputs.get("Strength")
            if strength and not strength.is_linked:
                strength.default_value *= args.world_strength_scale

    if args.area_fill_energy > 0:
        light_data = bpy.data.lights.new("ESIRRollingStockSoftFill", "AREA")
        light_data.energy = args.area_fill_energy
        light_data.size = args.area_fill_size
        light = bpy.data.objects.new("ESIRRollingStockSoftFill", light_data)
        scene.collection.objects.link(light)
        light.location = (-3.5, -5.0, 7.5)
        light.rotation_euler = (0.95, 0.0, -0.55)

    output_dir = Path(args.output_dir).resolve()
    output_dir.mkdir(parents=True, exist_ok=True)
    scene.render.filepath = str(output_dir) + os.sep


def main() -> None:
    args = parse_args()
    scene = bpy.context.scene
    scene.frame_set(0)

    rotator = bpy.data.objects.get("RollingStockStretchedRotator")
    if not rotator:
        raise RuntimeError("RollingStockStretchedRotator was not found in the template.")

    if not args.keep_placeholders:
        remove_placeholders()

    imported, roots = import_asset(Path(args.input))
    material_changes = set_material_defaults(imported, args.metallic, args.roughness, args.force_opaque)

    collection = rotator.users_collection[0] if rotator.users_collection else scene.collection
    asset_root = bpy.data.objects.new(f"{args.asset_name}_ImportedRoot", None)
    collection.objects.link(asset_root)
    for root in roots:
        root.parent = asset_root

    raw_bounds = mesh_bounds(imported)
    raw_dimensions = raw_bounds["dimensions"]
    if args.scale is not None:
        scale = args.scale
        scale_reason = "explicit"
    elif args.fit_length is not None:
        scale = args.fit_length / raw_dimensions.x
        scale_reason = "fit_length"
    elif args.fit_width is not None:
        scale = args.fit_width / raw_dimensions.y
        scale_reason = "fit_width"
    else:
        scale = 1.0
        scale_reason = "native"

    raw_center = raw_bounds["center"]
    raw_min = raw_bounds["min"]
    rotation_z = math.radians(args.rotation_z_degrees)
    rotation = Matrix.Rotation(rotation_z, 4, "Z")
    rotated_center = rotation @ Vector((raw_center.x * scale, raw_center.y * scale, 0.0))

    asset_root.scale = (scale, scale, scale)
    asset_root.rotation_euler[2] = rotation_z
    asset_root.location = (
        -rotated_center.x + args.x_offset,
        -rotated_center.y + args.y_offset,
        args.bottom_z - raw_min.z * scale,
    )
    asset_root.parent = rotator
    bpy.context.view_layer.update()

    configure_render(args)
    explicit_frames = parse_frame_list(args.frames, args.start, args.end)

    placed_bounds = mesh_bounds(imported)
    manifest = {
        "asset_name": args.asset_name,
        "input": args.input,
        "output_dir": scene.render.filepath,
        "frame_range": [args.start, args.end],
        "frames": explicit_frames,
        "resolution": args.resolution,
        "samples": args.samples,
        "device": args.device,
        "scale": round(float(scale), 8),
        "scale_reason": scale_reason,
        "rotation_z_degrees": args.rotation_z_degrees,
        "x_offset": args.x_offset,
        "y_offset": args.y_offset,
        "bottom_z": args.bottom_z,
        "camera_ortho_scale": scene.camera.data.ortho_scale if scene.camera else None,
        "raw_bounds": serializable_bounds(raw_bounds),
        "placed_bounds": serializable_bounds(placed_bounds),
        "imported_roots": [obj.name for obj in roots],
        "imported_objects": [obj.name for obj in imported],
        "material_changes": material_changes,
        "template": "rolling_stock_template.blend",
        "template_rotator": "RollingStockStretchedRotator",
    }

    manifest_path = Path(scene.render.filepath) / f"{args.asset_name}.render-manifest.json"
    manifest_path.write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    print(f"WROTE_RENDER_MANIFEST={manifest_path}")

    if args.dry_run:
        print("DRY_RUN=1")
        return

    if explicit_frames:
        output_dir = Path(scene.render.filepath)
        for frame in explicit_frames:
            scene.frame_set(frame)
            scene.render.filepath = str(output_dir / f"{frame:04d}.png")
            bpy.ops.render.render(write_still=True)
        scene.render.filepath = str(output_dir) + os.sep
    else:
        bpy.ops.render.render(animation=True)


if __name__ == "__main__":
    main()
