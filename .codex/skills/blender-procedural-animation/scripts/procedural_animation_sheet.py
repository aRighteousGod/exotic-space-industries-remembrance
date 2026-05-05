#!/usr/bin/env python3
"""Render procedural Blender animation frames into a transparent sheet.

Run with Blender:
  blender --background --python procedural_animation_sheet.py -- --test-asset machine --output-sheet tmp/machine.png
"""

from __future__ import annotations

import argparse
import json
import math
import os
import random
import sys
from pathlib import Path

import bpy
from mathutils import Vector


PRESETS = ["spin", "bob", "pulse", "orbit", "machine", "crystal", "gate", "all", "none"]
TEST_ASSETS = ["machine", "crystal", "gate", "orbiters"]


def parse_args() -> argparse.Namespace:
    argv = sys.argv
    if "--" in argv:
        argv = argv[argv.index("--") + 1 :]
    else:
        argv = []

    parser = argparse.ArgumentParser(
        description="Render a procedural Blender animation into transparent frames and a packed sheet."
    )
    parser.add_argument("--input", help="GLB, GLTF, OBJ, FBX, or BLEND source file.")
    parser.add_argument("--test-asset", choices=TEST_ASSETS, help="Generate a procedural test asset.")
    parser.add_argument("--base-dir", help="Resolve relative paths from this directory.")
    parser.add_argument("--output-sheet", required=True, help="Packed spritesheet PNG path.")
    parser.add_argument("--frames-dir", help="Directory for individual frame PNGs.")
    parser.add_argument("--manifest", help="Manifest JSON path. Defaults next to output sheet.")
    parser.add_argument("--save-blend", help="Optional .blend output for inspection.")
    parser.add_argument("--preset", choices=PRESETS, default="machine", help="Procedural motion preset.")
    parser.add_argument("--frames", type=int, default=16, help="Animation frames per direction.")
    parser.add_argument("--directions", type=int, default=1, help="Camera directions to render.")
    parser.add_argument(
        "--direction-mode",
        choices=["rotate-object", "camera-orbit"],
        default="rotate-object",
        help="Use rotate-object for Factorio-stable screen lighting; camera-orbit for inspection renders.",
    )
    parser.add_argument("--columns", type=int, help="Spritesheet columns. Defaults to frames.")
    parser.add_argument("--padding", type=int, default=0, help="Transparent pixels between frames.")
    parser.add_argument("--frame-size", type=int, default=256, help="Square frame size in pixels.")
    parser.add_argument("--elevation", type=float, default=60.0, help="Camera elevation in degrees.")
    parser.add_argument("--yaw-offset", type=float, default=45.0, help="First camera yaw in degrees.")
    parser.add_argument("--ortho-scale", type=float, help="Override orthographic camera scale.")
    parser.add_argument("--min-alpha-margin", type=int, default=16, help="Minimum transparent margin in pixels for every rendered frame.")
    parser.add_argument("--fail-alpha-margin", action="store_true", help="Exit non-zero when the fitted render cannot satisfy the alpha margin.")
    parser.add_argument("--auto-ortho-scale", dest="auto_ortho_scale", action="store_true", default=True, help="Increase orthographic scale and rerender until alpha margins pass. Enabled by default.")
    parser.add_argument("--no-auto-ortho-scale", dest="auto_ortho_scale", action="store_false", help="Disable automatic orthographic scale fitting.")
    parser.add_argument("--auto-ortho-step", type=float, default=1.12, help="Multiplier used after an alpha margin failure.")
    parser.add_argument("--auto-ortho-max", type=float, default=8.0, help="Maximum orthographic scale allowed by auto fitting.")
    parser.add_argument("--resolution-scale", type=int, default=100, help="Blender render resolution percentage.")
    parser.add_argument("--engine", choices=["eevee", "cycles"], default="eevee")
    parser.add_argument("--samples", type=int, default=64)
    parser.add_argument(
        "--factorio-preset-defaults",
        action="store_true",
        help="Use local factorioRenderingPreset_v4-inspired defaults: 384px, 8x8/64 frames, Cycles 256.",
    )
    parser.add_argument("--seed", type=int, default=19, help="Deterministic seed for generated helper geometry.")
    parser.add_argument("--amplitude", type=float, default=0.18, help="Generic bob/pulse/open amplitude.")
    parser.add_argument("--spin-turns", type=float, default=1.0, help="Whole-asset turns per loop for spin-like presets.")
    parser.add_argument("--orbit-radius", type=float, default=1.35, help="Generated orbiter radius.")
    parser.add_argument("--key-energy", type=float, default=520.0, help="Upper-left key light energy.")
    parser.add_argument("--fill-energy", type=float, default=70.0, help="Lower-right fill light energy.")
    parser.add_argument("--shadow-sheet", help="Optional generated draft shadow spritesheet path.")
    parser.add_argument("--shadow-offset", default="18,12", help="Draft shadow offset as right,down pixels.")
    parser.add_argument("--shadow-alpha", type=float, default=0.42, help="Draft shadow opacity multiplier.")
    parser.add_argument("--no-normalize", action="store_true", help="Do not center and scale imported meshes.")
    args = parser.parse_args(argv)

    if args.factorio_preset_defaults:
        seen = lambda flag: any(part == flag or part.startswith(flag + "=") for part in argv)
        if not seen("--frame-size"):
            args.frame_size = 384
        if not seen("--frames"):
            args.frames = 64
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

    if not args.input and not args.test_asset:
        parser.error("Provide --input or --test-asset.")
    if args.frames < 1:
        parser.error("--frames must be >= 1.")
    if args.directions < 1:
        parser.error("--directions must be >= 1.")
    if args.frame_size < 16:
        parser.error("--frame-size must be >= 16.")
    if args.min_alpha_margin < 0:
        parser.error("--min-alpha-margin must be >= 0.")
    if args.auto_ortho_step <= 1.0:
        parser.error("--auto-ortho-step must be greater than 1.")
    if args.auto_ortho_max <= 0:
        parser.error("--auto-ortho-max must be greater than 0.")
    return args


def parse_pixel_offset(raw: str) -> tuple[int, int]:
    parts = [part.strip() for part in raw.split(",")]
    if len(parts) != 2:
        raise argparse.ArgumentTypeError(f"Expected x,y pixel offset, got: {raw}")
    return (int(parts[0]), int(parts[1]))


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


def make_material(name: str, color: tuple[float, float, float, float], metallic: float = 0.0, emission: float = 0.0) -> bpy.types.Material:
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs["Base Color"].default_value = color
        bsdf.inputs["Metallic"].default_value = metallic
        bsdf.inputs["Roughness"].default_value = 0.42
        if "Emission Color" in bsdf.inputs:
            bsdf.inputs["Emission Color"].default_value = color
        if "Emission Strength" in bsdf.inputs:
            bsdf.inputs["Emission Strength"].default_value = emission
    return mat


def assign_mat(obj: bpy.types.Object, mat: bpy.types.Material) -> bpy.types.Object:
    obj.data.materials.append(mat)
    return obj


def add_cube(name: str, location: tuple[float, float, float], scale: tuple[float, float, float], mat: bpy.types.Material) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    assign_mat(obj, mat)
    return obj


def add_cylinder(name: str, location: tuple[float, float, float], radius: float, depth: float, mat: bpy.types.Material, vertices: int = 48) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=location)
    obj = bpy.context.object
    obj.name = name
    assign_mat(obj, mat)
    return obj


def add_torus(name: str, location: tuple[float, float, float], major: float, minor: float, mat: bpy.types.Material) -> bpy.types.Object:
    bpy.ops.mesh.primitive_torus_add(major_radius=major, minor_radius=minor, major_segments=64, minor_segments=12, location=location)
    obj = bpy.context.object
    obj.name = name
    assign_mat(obj, mat)
    return obj


def add_sphere(name: str, location: tuple[float, float, float], radius: float, mat: bpy.types.Material) -> bpy.types.Object:
    bpy.ops.mesh.primitive_uv_sphere_add(segments=32, ring_count=16, radius=radius, location=location)
    obj = bpy.context.object
    obj.name = name
    assign_mat(obj, mat)
    return obj


def add_cone(name: str, location: tuple[float, float, float], radius1: float, radius2: float, depth: float, mat: bpy.types.Material) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cone_add(vertices=5, radius1=radius1, radius2=radius2, depth=depth, location=location)
    obj = bpy.context.object
    obj.name = name
    assign_mat(obj, mat)
    return obj


def create_test_asset(kind: str, seed: int, orbit_radius: float) -> None:
    random.seed(seed)
    metal = make_material("dark_ritual_metal", (0.035, 0.045, 0.055, 1.0), metallic=0.75)
    graphite = make_material("blackened_graphite", (0.01, 0.012, 0.016, 1.0), metallic=0.35)
    glow = make_material("signal_glow_red", (1.0, 0.18, 0.07, 1.0), emission=1.4)
    crystal = make_material("corrupt_crystal", (0.18, 0.88, 0.95, 0.72), emission=0.8)

    if kind == "machine":
        add_cube("base_plate", (0, 0, -0.18), (1.15, 0.9, 0.18), metal)
        add_cylinder("machine_core_column", (0, 0, 0.18), 0.42, 0.72, graphite)
        add_sphere("pulse_core", (0, 0, 0.58), 0.28, glow)
        ring_a = add_torus("counter_ring_a", (0, 0, 0.58), 0.74, 0.035, metal)
        ring_b = add_torus("counter_ring_b", (0, 0, 0.82), 0.56, 0.03, metal)
        ring_a.rotation_euler.x = math.radians(90)
        ring_b.rotation_euler.x = math.radians(90)
        for idx in range(4):
            angle = math.tau * idx / 4.0
            add_cube(
                f"orbiter_{idx}",
                (math.cos(angle) * orbit_radius, math.sin(angle) * orbit_radius, 0.62),
                (0.12, 0.12, 0.18),
                glow if idx % 2 == 0 else metal,
            )
    elif kind == "crystal":
        add_cylinder("crystal_base", (0, 0, -0.2), 0.58, 0.22, metal)
        add_cone("pulse_crystal_lower", (0, 0, 0.26), 0.44, 0.15, 0.9, crystal)
        upper = add_cone("pulse_crystal_upper", (0, 0, 0.86), 0.16, 0.34, 0.7, crystal)
        upper.rotation_euler.z = math.radians(36)
        for idx in range(3):
            angle = math.tau * idx / 3.0
            add_sphere(f"mote_orbiter_{idx}", (math.cos(angle) * 0.9, math.sin(angle) * 0.9, 0.45), 0.08, glow)
    elif kind == "gate":
        add_cube("gate_left_mass", (-0.55, 0, 0.25), (0.22, 0.36, 0.85), metal)
        add_cube("gate_right_mass", (0.55, 0, 0.25), (0.22, 0.36, 0.85), metal)
        add_cube("gate_threshold_base", (0, 0, -0.28), (1.4, 0.42, 0.18), graphite)
        ring = add_torus("gate_rotating_halo", (0, 0, 0.46), 0.72, 0.035, glow)
        ring.rotation_euler.x = math.radians(90)
        add_sphere("gate_pulse_core", (0, 0, 0.46), 0.2, glow)
    elif kind == "orbiters":
        add_sphere("pulse_core", (0, 0, 0.35), 0.32, glow)
        add_torus("halo_ring", (0, 0, 0.35), 0.7, 0.03, metal)
        for idx in range(8):
            angle = math.tau * idx / 8.0
            z = 0.35 + 0.08 * math.sin(angle * 2.0)
            add_sphere(f"orbiter_mote_{idx}", (math.cos(angle) * orbit_radius, math.sin(angle) * orbit_radius, z), 0.06, crystal)
    else:
        raise SystemExit(f"Unknown test asset: {kind}")


def import_source(path: Path) -> None:
    suffix = path.suffix.lower()
    if suffix in {".glb", ".gltf"}:
        bpy.ops.import_scene.gltf(filepath=str(path))
    elif suffix == ".obj":
        bpy.ops.wm.obj_import(filepath=str(path))
    elif suffix == ".fbx":
        bpy.ops.import_scene.fbx(filepath=str(path))
    elif suffix == ".blend":
        with bpy.data.libraries.load(str(path), link=False) as (data_from, data_to):
            data_to.objects = list(data_from.objects)
        for obj in data_to.objects:
            if obj is not None:
                bpy.context.collection.objects.link(obj)
    else:
        raise SystemExit(f"Unsupported input extension: {suffix}")


def mesh_objects() -> list[bpy.types.Object]:
    return [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]


def bounds_for(objects: list[bpy.types.Object]) -> tuple[Vector, Vector]:
    points = []
    for obj in objects:
        points.extend(obj.matrix_world @ Vector(corner) for corner in obj.bound_box)
    if not points:
        raise SystemExit("No mesh objects found.")
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


def create_animation_root(center: Vector) -> bpy.types.Object:
    bpy.ops.object.empty_add(type="PLAIN_AXES", location=center)
    root = bpy.context.object
    root.name = "procedural_animation_root"
    for obj in mesh_objects():
        obj.parent = root
    return root


def setup_render(args: argparse.Namespace) -> None:
    scene = bpy.context.scene
    scene.frame_start = 0
    scene.frame_end = args.frames - 1
    scene.render.resolution_x = args.frame_size
    scene.render.resolution_y = args.frame_size
    scene.render.resolution_percentage = args.resolution_scale
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.view_settings.view_transform = "Standard"
    scene.view_settings.look = "Medium High Contrast"
    scene.view_settings.exposure = 0.0
    scene.view_settings.gamma = 1.0
    if args.engine == "cycles":
        scene.render.engine = "CYCLES"
        scene.cycles.samples = args.samples
        scene.cycles.use_denoising = True
    else:
        scene.render.engine = "BLENDER_EEVEE_NEXT"
        scene.eevee.taa_render_samples = args.samples


def setup_lighting(args: argparse.Namespace, center: Vector, radius: float, camera: bpy.types.Object) -> None:
    world = bpy.context.scene.world or bpy.data.worlds.new("World")
    bpy.context.scene.world = world
    world.color = (0.015, 0.018, 0.024)

    view_dir = (center - camera.location).normalized()
    quat = camera.matrix_world.to_quaternion()
    screen_right = quat @ Vector((1.0, 0.0, 0.0))
    screen_up = quat @ Vector((0.0, 1.0, 0.0))
    distance = max(radius * 4.5, 6.0)

    key_position = center - view_dir * distance * 0.35 - screen_right * distance * 0.75 + screen_up * distance * 0.9
    fill_position = center - view_dir * distance * 0.25 + screen_right * distance * 0.8 - screen_up * distance * 0.35

    bpy.ops.object.light_add(type="AREA", location=key_position)
    key = bpy.context.object
    key.name = "factorio_upper_left_key_light"
    key.data.energy = args.key_energy
    key.data.size = 4.5

    bpy.ops.object.light_add(type="POINT", location=fill_position)
    fill = bpy.context.object
    fill.name = "factorio_lower_right_fill_light"
    fill.data.energy = args.fill_energy


def setup_camera(center: Vector, radius: float, args: argparse.Namespace) -> bpy.types.Object:
    bpy.ops.object.empty_add(type="PLAIN_AXES", location=center)
    target = bpy.context.object
    target.name = "procedural_camera_target"

    bpy.ops.object.camera_add()
    camera = bpy.context.object
    bpy.context.scene.camera = camera
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = args.ortho_scale or max(radius * 2.55, 2.5)

    constraint = camera.constraints.new(type="TRACK_TO")
    constraint.track_axis = "TRACK_NEGATIVE_Z"
    constraint.up_axis = "UP_Y"
    constraint.target = target
    return camera


def set_camera_angle(camera: bpy.types.Object, center: Vector, radius: float, yaw_deg: float, elevation_deg: float) -> None:
    yaw = math.radians(yaw_deg)
    elevation = math.radians(elevation_deg)
    distance = max(radius * 4.2, 6.0)
    horizontal = math.cos(elevation) * distance
    camera.location = (
        center.x + math.cos(yaw) * horizontal,
        center.y + math.sin(yaw) * horizontal,
        center.z + math.sin(elevation) * distance,
    )


def capture_base(objects: list[bpy.types.Object]) -> dict[str, tuple[Vector, tuple[float, float, float], Vector]]:
    base = {}
    for obj in objects:
        base[obj.name] = (obj.location.copy(), tuple(obj.rotation_euler), obj.scale.copy())
    return base


def reset_objects(objects: list[bpy.types.Object], base: dict[str, tuple[Vector, tuple[float, float, float], Vector]]) -> None:
    for obj in objects:
        loc, rot, scale = base[obj.name]
        obj.location = loc.copy()
        obj.rotation_euler = rot
        obj.scale = scale.copy()


def matches(obj: bpy.types.Object, fragments: tuple[str, ...]) -> bool:
    name = obj.name.lower()
    return any(fragment in name for fragment in fragments)


def apply_pulse(objects: list[bpy.types.Object], cycle: float, amplitude: float) -> None:
    value = 1.0 + amplitude * (0.5 + 0.5 * math.sin(math.tau * cycle))
    targeted = [obj for obj in objects if matches(obj, ("core", "glow", "crystal", "pulse"))]
    for obj in targeted or objects:
        obj.scale *= value


def apply_orbit(objects: list[bpy.types.Object], cycle: float, radius: float, turns: float = 1.0) -> None:
    orbiters = [obj for obj in objects if matches(obj, ("orbiter", "satellite", "mote"))]
    for idx, obj in enumerate(orbiters):
        angle = math.tau * (cycle * turns + idx / max(len(orbiters), 1))
        base_radius = max(radius, math.hypot(obj.location.x, obj.location.y))
        obj.location.x = math.cos(angle) * base_radius
        obj.location.y = math.sin(angle) * base_radius
        obj.location.z += 0.08 * math.sin(angle * 2.0)
        obj.rotation_euler.z += angle


def apply_ring_rotation(objects: list[bpy.types.Object], cycle: float, turns: float = 1.0) -> None:
    rings = [obj for obj in objects if matches(obj, ("ring", "halo", "rotor", "blade"))]
    for idx, obj in enumerate(rings):
        direction = -1.0 if idx % 2 else 1.0
        obj.rotation_euler.z += direction * math.tau * cycle * turns


def apply_gate(objects: list[bpy.types.Object], cycle: float, amplitude: float) -> None:
    open_value = 0.5 - 0.5 * math.cos(math.tau * cycle)
    for obj in objects:
        lower = obj.name.lower()
        if "left" in lower:
            obj.location.x -= amplitude * 1.8 * open_value
        elif "right" in lower:
            obj.location.x += amplitude * 1.8 * open_value
        elif "gate" in lower and "halo" not in lower and "core" not in lower:
            obj.location.z += amplitude * 0.25 * math.sin(math.tau * cycle)


def apply_procedural_motion(root: bpy.types.Object, objects: list[bpy.types.Object], args: argparse.Namespace, frame_idx: int) -> None:
    cycle = frame_idx / args.frames
    preset = args.preset

    if preset == "none":
        return
    if preset in {"spin", "all"}:
        root.rotation_euler.z += math.tau * cycle * args.spin_turns
    if preset in {"bob", "crystal", "all"}:
        root.location.z += args.amplitude * math.sin(math.tau * cycle)
    if preset in {"pulse", "machine", "crystal", "gate", "all"}:
        apply_pulse(objects, cycle, args.amplitude)
    if preset in {"orbit", "machine", "crystal", "all"}:
        apply_orbit(objects, cycle, args.orbit_radius)
    if preset in {"machine", "gate", "all"}:
        apply_ring_rotation(objects, cycle, turns=1.0)
    if preset in {"gate", "all"}:
        apply_gate(objects, cycle, args.amplitude)
    if preset == "machine":
        root.rotation_euler.z += math.tau * cycle * 0.12
    if preset == "crystal":
        root.rotation_euler.z += math.tau * cycle * 0.35


def render_frames(args: argparse.Namespace, root: bpy.types.Object, camera: bpy.types.Object, center: Vector, radius: float, frames_dir: Path) -> list[Path]:
    frames_dir.mkdir(parents=True, exist_ok=True)
    objects = mesh_objects()
    base = capture_base([root] + objects)
    paths = []

    for direction_idx in range(args.directions):
        if args.direction_mode == "camera-orbit":
            yaw = args.yaw_offset + (360.0 * direction_idx / args.directions)
        else:
            yaw = args.yaw_offset
        set_camera_angle(camera, center, radius, yaw, args.elevation)
        for frame_idx in range(args.frames):
            reset_objects([root] + objects, base)
            if args.direction_mode == "rotate-object":
                root.rotation_euler.z += math.tau * direction_idx / args.directions
            bpy.context.scene.frame_set(frame_idx)
            apply_procedural_motion(root, objects, args, frame_idx)
            bpy.context.view_layer.update()
            frame_path = frames_dir / f"direction_{direction_idx:02d}_frame_{frame_idx:03d}.png"
            bpy.context.scene.render.filepath = str(frame_path)
            bpy.ops.render.render(write_still=True)
            paths.append(frame_path)
    return paths


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


def effective_min_alpha_margin(args: argparse.Namespace, shadow_sheet: Path | None) -> int:
    margin = max(0, int(args.min_alpha_margin))
    if shadow_sheet:
        offset_x, offset_down = parse_pixel_offset(args.shadow_offset)
        margin = max(margin, max(0, offset_x), max(0, offset_down))
    return margin


def analyze_alpha_margins(frame_paths: list[Path], min_margin: int) -> tuple[list[dict[str, object]], list[str]]:
    records = [alpha_bounds_for_frame(path) for path in frame_paths]
    warnings = []
    if min_margin > 0:
        for index, record in enumerate(records):
            margin = record.get("minimum_margin")
            if isinstance(margin, int) and margin < min_margin:
                warnings.append(f"frame_{index:03d} alpha margin {margin}px is below required margin {min_margin}px.")
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


def render_with_optional_auto_ortho(
    args: argparse.Namespace,
    root: bpy.types.Object,
    camera: bpy.types.Object,
    center: Vector,
    radius: float,
    frames_dir: Path,
    min_margin: int,
) -> tuple[list[Path], list[dict[str, object]], list[str], list[dict[str, object]], float]:
    attempts = []
    scale = float(camera.data.ortho_scale)
    while True:
        camera.data.ortho_scale = scale
        frame_paths = render_frames(args, root, camera, center, radius, frames_dir)
        alpha_bounds, warnings = analyze_alpha_margins(frame_paths, min_margin)
        margins = [
            int(record["minimum_margin"])
            for record in alpha_bounds
            if isinstance(record.get("minimum_margin"), int)
        ]
        attempts.append({"ortho_scale": scale, "minimum_margin": min(margins) if margins else None, "warnings": warnings})
        if not args.auto_ortho_scale or not warnings:
            return frame_paths, alpha_bounds, warnings, attempts, scale
        next_scale = next_ortho_scale_from_alpha(
            alpha_bounds,
            scale,
            min_margin,
            args.auto_ortho_step,
            args.auto_ortho_max,
        )
        if next_scale is None:
            return frame_paths, alpha_bounds, warnings, attempts, scale
        scale = next_scale


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

    sheet = bpy.data.images.new("procedural_animation_sheet", width=sheet_w, height=sheet_h, alpha=True)
    sheet.pixels = pixels
    output_sheet.parent.mkdir(parents=True, exist_ok=True)
    sheet.save_render(str(output_sheet))
    bpy.data.images.remove(sheet)
    return sheet_w, sheet_h


def make_shadow_sheet(source_sheet: Path, output_shadow: Path, offset: tuple[int, int], alpha: float) -> None:
    image = bpy.data.images.load(str(source_sheet), check_existing=False)
    width, height = image.size
    src = list(image.pixels)
    dst = [0.0] * (width * height * 4)
    offset_x, offset_down = offset

    for y in range(height):
        for x in range(width):
            src_index = (y * width + x) * 4
            source_alpha = src[src_index + 3]
            if source_alpha <= 0.0:
                continue
            dst_x = x + offset_x
            dst_y = y - offset_down
            if not (0 <= dst_x < width and 0 <= dst_y < height):
                continue
            dst_index = (dst_y * width + dst_x) * 4
            dst_alpha = min(1.0, source_alpha * alpha)
            if dst_alpha > dst[dst_index + 3]:
                dst[dst_index : dst_index + 4] = [0.0, 0.0, 0.0, dst_alpha]

    shadow = bpy.data.images.new("factorio_draft_shadow_sheet", width=width, height=height, alpha=True)
    shadow.pixels = dst
    output_shadow.parent.mkdir(parents=True, exist_ok=True)
    shadow.save_render(str(output_shadow))
    bpy.data.images.remove(shadow)
    bpy.data.images.remove(image)


def write_manifest(
    path: Path,
    args: argparse.Namespace,
    frame_paths: list[Path],
    sheet_size: tuple[int, int],
    source: str | None,
    shadow_sheet: Path | None,
    alpha_bounds: list[dict[str, object]],
    warnings: list[str],
    final_ortho_scale: float,
    auto_ortho_attempts: list[dict[str, object]],
    effective_margin: int,
) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    manifest = {
        "kind": "blender_procedural_animation",
        "source": source,
        "base_dir": str(Path(args.base_dir).resolve()) if args.base_dir else os.getcwd(),
        "output_sheet": str(Path(args.output_sheet)),
        "frames": [str(path) for path in frame_paths],
        "preset": args.preset,
        "frame_count": args.frames,
        "directions": args.directions,
        "direction_mode": args.direction_mode,
        "frame_size": args.frame_size,
        "columns": args.columns or args.frames,
        "line_length": args.columns or args.frames,
        "padding": args.padding,
        "sheet_width": sheet_size[0],
        "sheet_height": sheet_size[1],
        "elevation": args.elevation,
        "yaw_offset": args.yaw_offset,
        "ortho_scale": final_ortho_scale,
        "min_alpha_margin": args.min_alpha_margin,
        "effective_min_alpha_margin": effective_margin,
        "auto_ortho_scale": args.auto_ortho_scale,
        "auto_ortho_attempts": auto_ortho_attempts,
        "alpha_bounds": alpha_bounds,
        "warnings": warnings,
        "engine": args.engine,
        "samples": args.samples,
        "factorio_preset_defaults": args.factorio_preset_defaults,
        "factorio_preset_reference": "factorioRenderingPreset_v4.blend" if args.factorio_preset_defaults else None,
        "amplitude": args.amplitude,
        "spin_turns": args.spin_turns,
        "orbit_radius": args.orbit_radius,
        "factorio_lighting": {
            "key_direction": "screen upper-left",
            "shadow_direction": "screen lower-right",
            "key_energy": args.key_energy,
            "fill_energy": args.fill_energy,
            "shadow_sheet": str(shadow_sheet) if shadow_sheet else None,
            "shadow_offset": args.shadow_offset,
            "shadow_alpha": args.shadow_alpha,
        },
        "direction_order": "direction-major, frame-minor",
    }
    path.write_text(json.dumps(manifest, indent=2), encoding="utf-8")


def main() -> None:
    args = parse_args()
    base_dir = resolve_path(args.base_dir, Path.cwd()) if args.base_dir else Path.cwd().resolve()
    output_sheet = resolve_path(args.output_sheet, base_dir)
    assert output_sheet is not None
    frames_dir = resolve_path(args.frames_dir, base_dir) if args.frames_dir else output_sheet.with_suffix("").parent / (output_sheet.stem + "_frames")
    manifest = resolve_path(args.manifest, base_dir) if args.manifest else output_sheet.with_suffix(".manifest.json")
    assert frames_dir is not None
    assert manifest is not None
    columns = args.columns or args.frames

    clear_scene()
    source = args.input or f"test-asset:{args.test_asset}"
    if args.test_asset:
        create_test_asset(args.test_asset, args.seed, args.orbit_radius)
    else:
        input_path = resolve_path(args.input, base_dir)
        assert input_path is not None
        import_source(input_path)

    center, radius = ((Vector((0, 0, 0)), 1.0) if args.no_normalize else normalize_scene())
    root = create_animation_root(center)
    setup_render(args)
    camera = setup_camera(center, radius, args)
    set_camera_angle(camera, center, radius, args.yaw_offset, args.elevation)
    bpy.context.view_layer.update()
    setup_lighting(args, center, radius, camera)
    shadow_sheet = resolve_path(args.shadow_sheet, base_dir) if args.shadow_sheet else None
    effective_margin = effective_min_alpha_margin(args, shadow_sheet)
    frame_paths, alpha_bounds, warnings, auto_ortho_attempts, final_ortho_scale = render_with_optional_auto_ortho(
        args,
        root,
        camera,
        center,
        radius,
        frames_dir,
        effective_margin,
    )
    sheet_size = pack_sheet(frame_paths, output_sheet, columns, args.padding)
    if shadow_sheet:
        make_shadow_sheet(output_sheet, shadow_sheet, parse_pixel_offset(args.shadow_offset), args.shadow_alpha)
    write_manifest(
        manifest,
        args,
        frame_paths,
        sheet_size,
        source,
        shadow_sheet,
        alpha_bounds,
        warnings,
        final_ortho_scale,
        auto_ortho_attempts,
        effective_margin,
    )
    if warnings and args.fail_alpha_margin:
        raise SystemExit("Alpha margin check failed; see manifest warnings.")

    if args.save_blend:
        blend_path = resolve_path(args.save_blend, base_dir)
        assert blend_path is not None
        blend_path.parent.mkdir(parents=True, exist_ok=True)
        bpy.ops.wm.save_as_mainfile(filepath=str(blend_path))

    print(f"Procedural animation sheet: {output_sheet}")
    if shadow_sheet:
        print(f"Draft shadow sheet: {shadow_sheet}")
    print(f"Manifest: {manifest}")


if __name__ == "__main__":
    main()
