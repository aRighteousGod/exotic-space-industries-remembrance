#!/usr/bin/env python3
"""Drive the local Factorio rendering preset from background Blender.

Run with Blender:
  blender --background --python render_factorio_preset.py -- --preset-blend factorioRenderingPreset_v4.blend --test-cube --asset-name test --output-dir output/meshy/test/Render
"""

from __future__ import annotations

import argparse
import json
import math
import os
import re
import sys
from pathlib import Path
from typing import Any

try:
    import bpy
    from mathutils import Vector
except ImportError:  # Allows `python render_factorio_preset.py --help` outside Blender.
    bpy = None  # type: ignore[assignment]
    Vector = None  # type: ignore[assignment]


PASS_DEFS = {
    "object": {"node_labels": ["Object"], "folder": "Object", "sheet": "object_0.png"},
    "shadow": {"node_labels": ["Shadow"], "folder": "Shadow", "sheet": "object_shadow_0.png"},
    "light": {"node_labels": ["Light Black"], "folder": "Light", "sheet": "object_light_0.png"},
    "light-alpha": {"node_labels": ["Light"], "folder": "Light A", "sheet": "object_lightA_0.png"},
    "light-alpha-reduced": {"node_labels": ["Light with Alpha"], "folder": "Light A Reduced", "sheet": "object_lightAR_0.png"},
    "light-glared": {"node_labels": ["Light Glared"], "folder": "Light Glared", "sheet": "object_lightGlared_0.png"},
    "light-glared-alpha": {"node_labels": ["Light Glared with Alpha"], "folder": "Light Glared A", "sheet": "object_lightGlaredA_0.png"},
    "mask": {"node_labels": ["Color Mask"], "folder": "ColorMask", "sheet": "object_mask_0.png"},
    "water-reflection": {"node_labels": ["WaterReflection"], "folder": "WaterReflection", "sheet": "WaterReflection.png", "single": True},
}
DEFAULT_PASSES = "object,shadow,light-alpha-reduced,light-alpha,mask"
SAFE_NAME = re.compile(r"^[A-Za-z0-9][A-Za-z0-9_-]*$")


def parse_args() -> argparse.Namespace:
    argv = sys.argv
    if "--" in argv:
        argv = argv[argv.index("--") + 1 :]
    else:
        argv = argv[1:]

    parser = argparse.ArgumentParser(description="Render through factorioRenderingPreset_v4.blend.")
    parser.add_argument("--preset-blend", required=True, help="Path to factorioRenderingPreset_v4.blend.")
    parser.add_argument("--input", help="GLB, GLTF, OBJ, or FBX model path.")
    parser.add_argument("--test-cube", action="store_true", help="Create a simple cube instead of importing a model.")
    parser.add_argument("--base-dir", help="Resolve relative paths from this directory.")
    parser.add_argument("--asset-name", required=True, help="Asset/prototype-style name used in manifests.")
    parser.add_argument("--output-dir", required=True, help="Render output root, usually output/meshy/<asset>/Render.")
    parser.add_argument("--manifest", help="Manifest path. Defaults to <output-dir>/factorio-preset-render-manifest.json.")
    parser.add_argument("--passes", default=DEFAULT_PASSES, help="Comma-separated preset passes to render.")
    parser.add_argument("--quality", choices=["smoke", "final"], default="smoke", help="Smoke is low-sample; final uses preset-style samples.")
    parser.add_argument("--samples", type=int, help="Override Cycles samples.")
    parser.add_argument("--frames", type=int, default=64, help="Total Blender frame range end.")
    parser.add_argument("--directions", type=int, default=4, help="Preset direction count.")
    parser.add_argument("--animation-frames", type=int, default=16, help="Animation frames per direction.")
    parser.add_argument("--unit-directions", type=int, choices=[16, 32], help="Unit-style direction count; also sets total frames unless --frames is explicit.")
    parser.add_argument("--initial-angle", type=float, default=90.0, help="Initial angle in degrees for the unit-driver formula.")
    parser.add_argument("--ortho-scale", type=float, default=6.0, help="Preset camera orthographic scale.")
    parser.add_argument("--tile-size", type=int, default=64, help="Preset tile size in pixels.")
    parser.add_argument("--resolution", type=int, help="Override square render resolution.")
    parser.add_argument("--pack-sheets", action="store_true", help="Pack rendered pass folders into Render/.Sheets.")
    parser.add_argument("--grid", default="8x8", help="Packed sheet grid, e.g. 8x8.")
    parser.add_argument("--lights", choices=["auto", "none"], default="auto", help="Move non-sun lights to Lights on and assign Light Group Lights.")
    parser.add_argument("--keep-ground-dirt", action="store_true", help="Keep Ground Dirt when clearing preset object examples.")
    parser.add_argument("--keep-pipe", action="store_true", help="Keep Pipe when clearing preset object examples.")
    parser.add_argument("--no-parent-to-rotation", action="store_true", help="Do not parent imported meshes to Rotation by Frames & Directions.")
    parser.add_argument("--no-normalize", action="store_true", help="Do not center and scale imported meshes.")
    parser.add_argument("--auto-prep", action="store_true", help="Run conservative imported-model cleanup before preset placement.")
    parser.add_argument("--prep-origin-mode", choices=["center", "ground"], default="center", help="Origin normalization mode for imported meshes.")
    parser.add_argument("--prep-target-size", type=float, default=2.0, help="Largest normalized mesh dimension before preset render.")
    parser.add_argument("--prep-remove-imported-cameras", action="store_true", help="Remove cameras imported with the model.")
    parser.add_argument("--prep-delete-empty-meshes", action="store_true", help="Delete imported mesh objects with no polygons.")
    parser.add_argument("--prep-alpha-mode", choices=["report", "force-opaque"], default="report", help="Report alpha material risks or force imported materials opaque.")
    parser.add_argument("--prep-apply-scale", action="store_true", help="Apply imported mesh scale transforms before normalization.")
    parser.add_argument("--dry-run", action="store_true", help="Configure the preset and write a manifest without rendering.")
    parser.add_argument("--preflight-only", action="store_true", help="Configure and inspect the preset, write a manifest, and skip rendering.")
    parser.add_argument("--preflight-margin", type=float, default=0.12, help="Warn when projected asset margin is below this ratio.")
    parser.add_argument("--fail-framing-risk", action="store_true", help="Exit non-zero when preflight detects low framing margin.")
    parser.add_argument("--require-light-group", default="Lights", help="Required light group for export/glow lights.")
    parser.add_argument("--fail-missing-light-group", action="store_true", help="Exit non-zero when export lights are not in --require-light-group.")
    parser.add_argument("--footprint-tiles", help="Gameplay footprint estimate as WxH tiles, used for preflight reporting.")
    parser.add_argument("--material-report", action="store_true", help="Include material alpha/emission/texture risk details in the manifest.")
    parser.add_argument("--warn-alpha-materials", action="store_true", help="Warn about transparent/alpha-capable materials.")
    parser.add_argument("--fail-alpha-risk", action="store_true", help="Exit non-zero if material alpha risks are found.")
    parser.add_argument("--save-blend", help="Optional .blend output after configuration.")
    args = parser.parse_args(argv)

    if not SAFE_NAME.match(args.asset_name):
        parser.error("--asset-name must contain only letters, numbers, underscores, or dashes.")
    if not args.input and not args.test_cube:
        parser.error("Provide --input or --test-cube.")
    if args.unit_directions and not any(part == "--directions" or part.startswith("--directions=") for part in argv):
        args.directions = args.unit_directions
    if args.unit_directions and not any(part == "--frames" or part.startswith("--frames=") for part in argv):
        args.frames = args.animation_frames * args.unit_directions
    if args.frames < 1 or args.directions < 1 or args.animation_frames < 1:
        parser.error("--frames, --directions, and --animation-frames must be positive.")
    return args


def resolve_path(value: str | None, base_dir: Path) -> Path | None:
    if value is None:
        return None
    path = Path(value)
    if path.is_absolute():
        return path
    return (base_dir / path).resolve()


def parse_passes(raw: str) -> list[str]:
    passes = [part.strip().lower() for part in raw.split(",") if part.strip()]
    unknown = [item for item in passes if item not in PASS_DEFS]
    if unknown:
        raise SystemExit(f"Unknown pass(es): {', '.join(unknown)}")
    return passes


def parse_grid(raw: str) -> tuple[int, int]:
    value = raw.lower().replace(",", "x")
    parts = [part.strip() for part in value.split("x") if part.strip()]
    if len(parts) != 2:
        raise SystemExit(f"--grid must be columns x rows, got {raw}")
    columns, rows = int(parts[0]), int(parts[1])
    if columns < 1 or rows < 1:
        raise SystemExit("--grid values must be positive.")
    return columns, rows


def parse_tiles(raw: str | None) -> tuple[float, float] | None:
    if not raw:
        return None
    value = raw.lower().replace(",", "x")
    parts = [part.strip() for part in value.split("x") if part.strip()]
    if len(parts) != 2:
        raise SystemExit(f"--footprint-tiles must be WxH, got {raw}")
    width, height = float(parts[0]), float(parts[1])
    if width <= 0 or height <= 0:
        raise SystemExit("--footprint-tiles values must be positive.")
    return width, height


def scene() -> bpy.types.Scene:
    return bpy.data.scenes.get("Default Scene") or bpy.context.scene


def ensure_factorio_props() -> None:
    props = {
        "factorio_tilesize": bpy.props.IntProperty(default=64, min=1),
        "factorio_oScale": bpy.props.FloatProperty(default=6.0, min=1.0),
        "factorio_animationFrames": bpy.props.IntProperty(default=16, min=1),
        "factorio_directions": bpy.props.IntProperty(default=4, min=1),
        "factorio_mute_exports": bpy.props.BoolProperty(default=False),
    }
    for name, prop in props.items():
        if not hasattr(bpy.types.Scene, name):
            setattr(bpy.types.Scene, name, prop)


def collection(name: str) -> bpy.types.Collection | None:
    return bpy.data.collections.get(name)


def unlink_from_all(obj: bpy.types.Object) -> None:
    for coll in list(obj.users_collection):
        coll.objects.unlink(obj)


def link_to_collection(obj: bpy.types.Object, coll_name: str) -> None:
    coll = collection(coll_name)
    if coll is None:
        raise SystemExit(f"Required preset collection not found: {coll_name}")
    if obj.name not in coll.objects:
        coll.objects.link(obj)


def clear_preset_examples(args: argparse.Namespace) -> list[str]:
    cleared: list[str] = []
    keep = set()
    if args.keep_ground_dirt:
        keep.add("Ground Dirt")
    if args.keep_pipe:
        keep.add("Pipe")
    for coll_name in ["Normal", "Colored", "Uncolored", "Lights on", "Lights off"]:
        coll = collection(coll_name)
        if not coll:
            continue
        for obj in list(coll.objects):
            if obj.name in keep:
                continue
            if obj.type in {"MESH", "LIGHT"}:
                name = obj.name
                bpy.data.objects.remove(obj, do_unlink=True)
                cleared.append(name)
    return cleared


def import_model(path: Path) -> list[bpy.types.Object]:
    before = set(bpy.data.objects)
    suffix = path.suffix.lower()
    if suffix in {".glb", ".gltf"}:
        bpy.ops.import_scene.gltf(filepath=str(path))
    elif suffix == ".obj":
        bpy.ops.wm.obj_import(filepath=str(path))
    elif suffix == ".fbx":
        bpy.ops.import_scene.fbx(filepath=str(path))
    else:
        raise SystemExit(f"Unsupported input extension: {suffix}")
    return [obj for obj in bpy.data.objects if obj not in before]


def create_test_cube() -> list[bpy.types.Object]:
    bpy.ops.mesh.primitive_cube_add(size=2.0, location=(0, 0, 0.8))
    cube = bpy.context.object
    cube.name = "esir_preset_test_cube"
    mat = bpy.data.materials.new("esir_preset_test_cube_dark")
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs["Base Color"].default_value = (0.04, 0.05, 0.06, 1.0)
        bsdf.inputs["Metallic"].default_value = 0.55
        bsdf.inputs["Roughness"].default_value = 0.38
    cube.data.materials.append(mat)
    return [cube]


def mesh_objects(objects: list[bpy.types.Object]) -> list[bpy.types.Object]:
    return [obj for obj in objects if obj.type == "MESH"]


def bounds_for(objects: list[bpy.types.Object]) -> tuple[Vector, Vector]:
    points = []
    for obj in objects:
        points.extend(obj.matrix_world @ Vector(corner) for corner in obj.bound_box)
    if not points:
        raise SystemExit("No mesh objects found for preset render.")
    mins = Vector((min(p.x for p in points), min(p.y for p in points), min(p.z for p in points)))
    maxs = Vector((max(p.x for p in points), max(p.y for p in points), max(p.z for p in points)))
    return mins, maxs


def vector_list(value: Vector) -> list[float]:
    return [float(value.x), float(value.y), float(value.z)]


def normalize_objects(objects: list[bpy.types.Object], *, target_size: float = 2.0, origin_mode: str = "center") -> dict[str, Any]:
    meshes = mesh_objects(objects)
    if not meshes:
        return {"enabled": False, "reason": "no mesh objects"}
    mins, maxs = bounds_for(meshes)
    center = (mins + maxs) * 0.5
    size = max((maxs - mins).x, (maxs - mins).y, (maxs - mins).z)
    scale = target_size / size if size > 0 else 1.0
    if origin_mode == "ground":
        origin = Vector((center.x, center.y, mins.z))
    else:
        origin = center
    for obj in meshes:
        obj.location -= origin
        obj.scale *= scale
    bpy.context.view_layer.update()
    after_mins, after_maxs = bounds_for(meshes)
    return {
        "enabled": True,
        "origin_mode": origin_mode,
        "target_size": target_size,
        "scale_factor": scale,
        "bounds_before": {"min": vector_list(mins), "max": vector_list(maxs)},
        "bounds_after": {"min": vector_list(after_mins), "max": vector_list(after_maxs)},
    }


def apply_scale_to_meshes(objects: list[bpy.types.Object]) -> bool:
    meshes = mesh_objects(objects)
    if not meshes:
        return False
    bpy.ops.object.select_all(action="DESELECT")
    for obj in meshes:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    bpy.ops.object.select_all(action="DESELECT")
    return True


def force_opaque_alpha_materials(objects: list[bpy.types.Object]) -> list[dict[str, Any]]:
    changed: list[dict[str, Any]] = []
    for obj in mesh_objects(objects):
        for slot in obj.material_slots:
            mat = slot.material
            if not mat:
                continue
            before = {
                "blend_method": getattr(mat, "blend_method", None),
                "use_nodes": bool(getattr(mat, "use_nodes", False)),
            }
            touched = False
            if getattr(mat, "blend_method", "OPAQUE") != "OPAQUE":
                mat.blend_method = "OPAQUE"
                touched = True
            if mat.use_nodes and mat.node_tree:
                bsdf = mat.node_tree.nodes.get("Principled BSDF")
                if bsdf and "Alpha" in bsdf.inputs and bsdf.inputs["Alpha"].default_value < 1:
                    bsdf.inputs["Alpha"].default_value = 1
                    touched = True
            if touched:
                changed.append({"object": obj.name, "material": mat.name, "before": before})
    return changed


def auto_prep_imported_objects(objects: list[bpy.types.Object], args: argparse.Namespace) -> dict[str, Any]:
    enabled = any(
        [
            args.auto_prep,
            args.prep_remove_imported_cameras,
            args.prep_delete_empty_meshes,
            args.prep_apply_scale,
            args.prep_alpha_mode == "force-opaque",
        ]
    )
    report: dict[str, Any] = {
        "enabled": enabled,
        "origin_mode": args.prep_origin_mode,
        "target_size": args.prep_target_size,
        "alpha_mode": args.prep_alpha_mode,
        "removed_imported_cameras": [],
        "deleted_empty_meshes": [],
        "forced_opaque_materials": [],
        "applied_scale": False,
    }
    if not enabled:
        return report
    remove_cameras = args.auto_prep or args.prep_remove_imported_cameras
    delete_empty = args.auto_prep or args.prep_delete_empty_meshes
    for obj in list(objects):
        if remove_cameras and obj.type == "CAMERA":
            report["removed_imported_cameras"].append(obj.name)
            bpy.data.objects.remove(obj, do_unlink=True)
            objects.remove(obj)
        elif delete_empty and obj.type == "MESH" and len(obj.data.polygons) == 0:
            report["deleted_empty_meshes"].append(obj.name)
            bpy.data.objects.remove(obj, do_unlink=True)
            objects.remove(obj)
    if args.prep_apply_scale:
        report["applied_scale"] = apply_scale_to_meshes(objects)
    if args.prep_alpha_mode == "force-opaque":
        report["forced_opaque_materials"] = force_opaque_alpha_materials(objects)
    return report


def place_imported_objects(objects: list[bpy.types.Object], args: argparse.Namespace) -> None:
    rotator = bpy.data.objects.get("Rotation by Frames & Directions")
    for obj in objects:
        unlink_from_all(obj)
        if obj.type == "LIGHT" and args.lights == "auto":
            link_to_collection(obj, "Lights on")
            if hasattr(obj.data, "lightgroup"):
                obj.data.lightgroup = "Lights"
        elif obj.type == "LIGHT":
            link_to_collection(obj, "Object")
        else:
            link_to_collection(obj, "Normal")
            if rotator and not args.no_parent_to_rotation:
                obj.parent = rotator


def setup_scene(args: argparse.Namespace, selected_passes: list[str], output_dir: Path) -> dict[str, Any]:
    ensure_factorio_props()
    scn = scene()
    bpy.context.window.scene = scn
    scn["factorio_animationFrames"] = args.animation_frames
    scn["factorio_directions"] = args.directions
    scn["factorio_oScale"] = args.ortho_scale
    scn["factorio_tilesize"] = args.tile_size
    # The imported preset's original drivers may still reference these short
    # custom-property names even when Codex replaces unit drivers later.
    scn["frames"] = args.animation_frames
    scn["dir"] = args.directions
    scn.factorio_animationFrames = args.animation_frames
    scn.factorio_directions = args.directions
    scn.factorio_oScale = args.ortho_scale
    scn.factorio_tilesize = args.tile_size

    scn.frame_start = 1
    scn.frame_end = args.frames
    scn.render.engine = "CYCLES"
    scn.cycles.samples = args.samples if args.samples is not None else (256 if args.quality == "final" else 16)
    scn.cycles.use_denoising = True
    scn.render.film_transparent = True
    scn.render.use_compositing = True
    scn.render.image_settings.file_format = "PNG"
    scn.render.image_settings.color_mode = "RGBA"
    scn.render.filepath = str(output_dir / "Composite" / "")
    resolution = args.resolution or int(round(args.ortho_scale * args.tile_size))
    scn.render.resolution_x = resolution
    scn.render.resolution_y = resolution
    scn.render.resolution_percentage = 100
    if scn.camera and scn.camera.type == "CAMERA":
        scn.camera.data.type = "ORTHO"
        scn.camera.data.ortho_scale = args.ortho_scale

    selected_labels = {
        label
        for pass_name in selected_passes
        for label in PASS_DEFS[pass_name]["node_labels"]
    }
    node_records = []
    if scn.use_nodes and scn.node_tree:
        for node in scn.node_tree.nodes:
            if node.bl_idname != "CompositorNodeOutputFile":
                continue
            label = node.label or node.name
            matched_pass = None
            for pass_name in selected_passes:
                if label in PASS_DEFS[pass_name]["node_labels"]:
                    matched_pass = pass_name
                    break
            node.mute = matched_pass is None
            if matched_pass:
                folder = PASS_DEFS[matched_pass]["folder"]
                node.base_path = str(output_dir / folder)
            node_records.append(
                {
                    "name": node.name,
                    "label": label,
                    "mute": bool(node.mute),
                    "base_path": node.base_path,
                    "selected": label in selected_labels,
                    "slots": [slot.path for slot in node.file_slots],
                }
            )
    return {
        "scene": scn.name,
        "resolution": [resolution, resolution],
        "samples": scn.cycles.samples,
        "frame_start": scn.frame_start,
        "frame_end": scn.frame_end,
        "node_records": node_records,
    }


def add_unit_driver(args: argparse.Namespace) -> None:
    rotator = bpy.data.objects.get("Rotation by Frames & Directions")
    if not rotator:
        return
    if rotator.animation_data:
        for fcu in list(rotator.animation_data.drivers):
            rotator.driver_remove(fcu.data_path, fcu.array_index)
    fcu = rotator.driver_add("rotation_euler", 2)
    driver = fcu.driver
    driver.type = "SCRIPTED"
    driver.expression = f"radians(-{args.initial_angle} - ((frame - 1) // {args.animation_frames}) * 360 / {args.directions})"


def material_risks(objects: list[bpy.types.Object]) -> list[dict[str, Any]]:
    risks: list[dict[str, Any]] = []
    for obj in mesh_objects(objects):
        for slot in obj.material_slots:
            mat = slot.material
            if not mat:
                continue
            risk: dict[str, Any] = {
                "object": obj.name,
                "material": mat.name,
                "blend_method": getattr(mat, "blend_method", None),
                "alpha_inputs": [],
                "transparent_nodes": [],
                "image_alpha_textures": [],
                "emission_nodes": [],
            }
            if getattr(mat, "blend_method", "OPAQUE") != "OPAQUE":
                risk["alpha_inputs"].append(f"blend_method={mat.blend_method}")
            if mat.use_nodes and mat.node_tree:
                for node in mat.node_tree.nodes:
                    if node.bl_idname == "ShaderNodeBsdfPrincipled":
                        alpha = node.inputs.get("Alpha")
                        if alpha and getattr(alpha, "default_value", 1.0) < 1.0:
                            risk["alpha_inputs"].append(f"Principled Alpha={alpha.default_value}")
                    if "Transparent" in node.bl_idname:
                        risk["transparent_nodes"].append(node.name)
                    if "Emission" in node.bl_idname:
                        risk["emission_nodes"].append(node.name)
                    if node.bl_idname == "ShaderNodeTexImage" and getattr(node, "image", None):
                        if node.image.depth in {32, 64} or node.image.alpha_mode != "NONE":
                            risk["image_alpha_textures"].append(node.image.name)
            if any(risk[key] for key in ["alpha_inputs", "transparent_nodes", "image_alpha_textures", "emission_nodes"]):
                risks.append(risk)
    return risks


def preflight_report(
    args: argparse.Namespace,
    *,
    selected_passes: list[str],
    imported: list[bpy.types.Object],
    scene_record: dict[str, Any],
) -> dict[str, Any]:
    required_collections = ["Object", "Normal", "Colored", "Uncolored", "Lights on", "Lights off", "Scene"]
    collections = {name: bpy.data.collections.get(name) is not None for name in required_collections}
    rotator = bpy.data.objects.get("Rotation by Frames & Directions")
    missing_nodes = []
    duplicate_nodes = []
    labels = [record["label"] for record in scene_record.get("node_records", [])]
    for pass_name in selected_passes:
        expected = PASS_DEFS[pass_name]["node_labels"]
        matches = [label for label in labels if label in expected]
        if not matches:
            missing_nodes.append(pass_name)
        if len(matches) > 1 and pass_name != "water-reflection":
            duplicate_nodes.append({"pass": pass_name, "labels": matches})

    light_issues = []
    for obj in bpy.data.objects:
        if obj.type != "LIGHT" or obj.data.type == "SUN":
            continue
        in_lights_on = any(coll.name == "Lights on" for coll in obj.users_collection)
        lightgroup = getattr(obj.data, "lightgroup", "")
        if in_lights_on and args.require_light_group and lightgroup != args.require_light_group:
            light_issues.append({"name": obj.name, "lightgroup": lightgroup, "required": args.require_light_group})

    meshes = mesh_objects(imported)
    mins, maxs = bounds_for(meshes)
    size = maxs - mins
    width = max(size.x, size.y)
    height = size.z
    ortho = float(args.ortho_scale)
    margin_ratio = max(0.0, (ortho - width) / max(ortho, 0.000001) / 2.0)
    framing_risk = margin_ratio < args.preflight_margin
    footprint = parse_tiles(args.footprint_tiles)
    footprint_report = None
    if footprint:
        world_units_per_tile = ortho / max(footprint)
        footprint_report = {
            "tiles": list(footprint),
            "pixels_per_tile": args.tile_size,
            "cell_resolution": scene_record["resolution"],
            "world_units_per_tile": world_units_per_tile,
            "asset_dimensions_world": [size.x, size.y, size.z],
            "recommended_ortho_scale": max(footprint) * world_units_per_tile,
        }

    risks = material_risks(imported)
    warnings = []
    errors = []
    if not all(collections.values()):
        errors.append("Required preset collections are missing.")
    if missing_nodes:
        errors.append(f"Selected compositor passes have no output node: {', '.join(missing_nodes)}")
    if duplicate_nodes:
        warnings.append(f"Duplicate compositor output labels: {duplicate_nodes}")
    if not rotator and not args.no_parent_to_rotation:
        errors.append("Rotation by Frames & Directions empty is missing.")
    if light_issues:
        message = f"Lights in Lights on without required light group {args.require_light_group}."
        (errors if args.fail_missing_light_group else warnings).append(message)
    if framing_risk:
        message = f"Projected asset margin {margin_ratio:.3f} is below --preflight-margin {args.preflight_margin}."
        (errors if args.fail_framing_risk else warnings).append(message)
    alpha_risks = [
        risk for risk in risks
        if risk["alpha_inputs"] or risk["transparent_nodes"] or risk["image_alpha_textures"]
    ]
    if alpha_risks and args.warn_alpha_materials:
        message = f"Material alpha risk detected in {len(alpha_risks)} material(s)."
        (errors if args.fail_alpha_risk else warnings).append(message)

    return {
        "collections": collections,
        "compositor": {
            "selected_passes": selected_passes,
            "missing_pass_nodes": missing_nodes,
            "duplicate_nodes": duplicate_nodes,
        },
        "rotation": {
            "rotator_present": rotator is not None,
            "driver_replaced": rotator is not None,
            "unit_driver_mode": bool(args.unit_directions),
        },
        "lights": {
            "required_light_group": args.require_light_group,
            "issues": light_issues,
        },
        "framing": {
            "bounds_min": [mins.x, mins.y, mins.z],
            "bounds_max": [maxs.x, maxs.y, maxs.z],
            "dimensions": [size.x, size.y, size.z],
            "ortho_scale": ortho,
            "margin_ratio": margin_ratio,
            "framing_risk": framing_risk,
            "footprint": footprint_report,
        },
        "materials": risks if args.material_report else {"risk_count": len(risks), "alpha_risk_count": len(alpha_risks)},
        "warnings": warnings,
        "errors": errors,
        "passed": not errors,
    }


def render_animation(output_dir: Path) -> None:
    output_dir.mkdir(parents=True, exist_ok=True)
    bpy.ops.render.render(animation=True)


def natural_key(path: Path) -> list[Any]:
    return [int(part) if part.isdigit() else part.lower() for part in re.split(r"(\d+)", path.name)]


def frame_files(folder: Path) -> list[Path]:
    if not folder.exists():
        return []
    return sorted([path for path in folder.glob("*.png") if path.is_file()], key=natural_key)


def pack_frame_paths(frame_paths: list[Path], output_sheet: Path, columns: int, rows: int) -> dict[str, Any]:
    if not frame_paths:
        raise FileNotFoundError(f"No PNG frames to pack for {output_sheet}")
    first = bpy.data.images.load(str(frame_paths[0]), check_existing=False)
    tile_w, tile_h = first.size
    bpy.data.images.remove(first)
    frames_per_sheet = columns * rows
    sheet_records = []
    output_sheet.parent.mkdir(parents=True, exist_ok=True)

    for sheet_index in range(math.ceil(len(frame_paths) / frames_per_sheet)):
        current = frame_paths[sheet_index * frames_per_sheet : (sheet_index + 1) * frames_per_sheet]
        sheet_w = columns * tile_w
        sheet_h = rows * tile_h
        pixels = [0.0] * (sheet_w * sheet_h * 4)
        for idx, frame_path in enumerate(current):
            image = bpy.data.images.load(str(frame_path), check_existing=False)
            if tuple(image.size) != (tile_w, tile_h):
                raise ValueError(f"Frame size mismatch: {frame_path} is {image.size}, expected {(tile_w, tile_h)}")
            rgba = list(image.pixels)
            col = idx % columns
            row = rows - 1 - (idx // columns)
            x0 = col * tile_w
            y0 = row * tile_h
            for y in range(tile_h):
                for x in range(tile_w):
                    src = (y * tile_w + x) * 4
                    dst = ((y0 + y) * sheet_w + (x0 + x)) * 4
                    pixels[dst : dst + 4] = rgba[src : src + 4]
            bpy.data.images.remove(image)
        target = output_sheet if sheet_index == 0 else output_sheet.with_name(f"{output_sheet.stem}_{sheet_index}{output_sheet.suffix}")
        sheet = bpy.data.images.new(target.stem, width=sheet_w, height=sheet_h, alpha=True)
        sheet.pixels = pixels
        sheet.save_render(str(target))
        bpy.data.images.remove(sheet)
        sheet_records.append(str(target))
    return {"tile_size": [tile_w, tile_h], "sheets": sheet_records}


def copy_first_frame(frame_paths: list[Path], output_sheet: Path) -> dict[str, Any]:
    if not frame_paths:
        raise FileNotFoundError(f"No PNG frames to copy for {output_sheet}")
    image = bpy.data.images.load(str(frame_paths[0]), check_existing=False)
    output_sheet.parent.mkdir(parents=True, exist_ok=True)
    image.save_render(str(output_sheet))
    size = list(image.size)
    bpy.data.images.remove(image)
    return {"tile_size": size, "sheets": [str(output_sheet)]}


def pack_sheets(output_dir: Path, selected_passes: list[str], grid: tuple[int, int]) -> dict[str, Any]:
    sheets_dir = output_dir / ".Sheets"
    records = {}
    for pass_name in selected_passes:
        info = PASS_DEFS[pass_name]
        folder = output_dir / str(info["folder"])
        frames = frame_files(folder)
        if not frames:
            records[pass_name] = {"warning": f"No frames found in {folder}"}
            continue
        target = sheets_dir / str(info["sheet"])
        if info.get("single"):
            records[pass_name] = copy_first_frame(frames, target)
        else:
            records[pass_name] = pack_frame_paths(frames, target, grid[0], grid[1])
    return records


def write_manifest(path: Path, payload: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2), encoding="utf-8")


def main() -> None:
    args = parse_args()
    if bpy is None or Vector is None:
        raise SystemExit("render_factorio_preset.py must be run with Blender for rendering.")
    base_dir = resolve_path(args.base_dir, Path.cwd()) if args.base_dir else Path.cwd().resolve()
    preset = resolve_path(args.preset_blend, base_dir)
    output_dir = resolve_path(args.output_dir, base_dir)
    manifest = resolve_path(args.manifest, base_dir) if args.manifest else output_dir / "factorio-preset-render-manifest.json"
    assert preset is not None and output_dir is not None and manifest is not None
    selected_passes = parse_passes(args.passes)
    grid = parse_grid(args.grid)

    bpy.ops.wm.open_mainfile(filepath=str(preset))
    output_dir.mkdir(parents=True, exist_ok=True)
    cleared = clear_preset_examples(args)
    if args.test_cube:
        imported = create_test_cube()
        source = "test-cube"
    else:
        input_path = resolve_path(args.input, base_dir)
        assert input_path is not None
        imported = import_model(input_path)
        source = str(input_path)
    auto_prep = auto_prep_imported_objects(imported, args)
    normalize_report: dict[str, Any] = {"enabled": False}
    if not args.no_normalize:
        normalize_report = normalize_objects(
            imported,
            target_size=args.prep_target_size,
            origin_mode=args.prep_origin_mode,
        )
    place_imported_objects(imported, args)
    add_unit_driver(args)

    scene_record = setup_scene(args, selected_passes, output_dir)
    preflight = preflight_report(
        args,
        selected_passes=selected_passes,
        imported=imported,
        scene_record=scene_record,
    )
    if not args.dry_run and not args.preflight_only:
        render_animation(output_dir)
    packed = pack_sheets(output_dir, selected_passes, grid) if args.pack_sheets and not args.dry_run and not args.preflight_only else {}

    if args.save_blend:
        save_path = resolve_path(args.save_blend, base_dir)
        assert save_path is not None
        save_path.parent.mkdir(parents=True, exist_ok=True)
        bpy.ops.wm.save_as_mainfile(filepath=str(save_path))

    write_manifest(
        manifest,
        {
            "kind": "factorio_preset_render",
            "asset_name": args.asset_name,
            "preset_blend": str(preset),
            "source": source,
            "output_dir": str(output_dir),
            "passes": selected_passes,
            "quality": args.quality,
            "dry_run": args.dry_run,
            "preflight_only": args.preflight_only,
            "frames": args.frames,
            "directions": args.directions,
            "animation_frames": args.animation_frames,
            "unit_directions": args.unit_directions,
            "initial_angle": args.initial_angle,
            "ortho_scale": args.ortho_scale,
            "tile_size": args.tile_size,
            "grid": list(grid),
            "cleared_preset_objects": cleared,
            "imported_objects": [obj.name for obj in imported],
            "auto_prep": auto_prep,
            "normalization": normalize_report,
            "scene": scene_record,
            "preflight": preflight,
            "packed_sheets": packed,
            "warnings": [
                "factorioRenderingPreset_v4.blend may warn about a newer Blender version; this script configures required props directly.",
                "Light/glow exports depend on preset compositor nodes and the Lights light group.",
            ] + preflight.get("warnings", []),
        },
    )
    print(f"factorio_preset_output={output_dir}")
    print(f"manifest={manifest}")
    if not preflight.get("passed", True):
        raise SystemExit("Preset preflight failed; see manifest preflight.errors.")


if __name__ == "__main__":
    main()
