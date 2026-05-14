from __future__ import annotations

import argparse
import json
import math
import sys
from pathlib import Path

import bpy
from mathutils import Vector


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Render Emerald Apocalypse charge icon turntable frames.")
    parser.add_argument("--input", required=True, help="Source GLB path.")
    parser.add_argument("--output-dir", required=True, help="Directory for transparent PNG frames.")
    parser.add_argument("--frames", type=int, default=64, help="Number of turntable directions.")
    parser.add_argument("--resolution", type=int, default=512, help="Square render resolution.")
    parser.add_argument("--samples", type=int, default=96, help="Cycles samples per frame.")
    parser.add_argument("--selected-index", type=int, help="Render only this turntable index.")
    parser.add_argument("--initial-angle", type=float, default=0.0, help="Initial Z rotation angle in degrees.")
    parser.add_argument("--manifest", help="Optional manifest path.")
    argv = sys.argv
    if "--" in argv:
        argv = argv[argv.index("--") + 1:]
    else:
        argv = []
    return parser.parse_args(argv)


def clear_scene() -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete()


def import_model(path: Path) -> list[bpy.types.Object]:
    bpy.ops.import_scene.gltf(filepath=str(path))
    meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    if not meshes:
        raise RuntimeError(f"No mesh objects imported from {path}")
    return meshes


def combined_bounds(objects: list[bpy.types.Object]) -> tuple[Vector, Vector]:
    min_v = Vector((math.inf, math.inf, math.inf))
    max_v = Vector((-math.inf, -math.inf, -math.inf))
    for obj in objects:
        for corner in obj.bound_box:
            world = obj.matrix_world @ Vector(corner)
            min_v.x = min(min_v.x, world.x)
            min_v.y = min(min_v.y, world.y)
            min_v.z = min(min_v.z, world.z)
            max_v.x = max(max_v.x, world.x)
            max_v.y = max(max_v.y, world.y)
            max_v.z = max(max_v.z, world.z)
    return min_v, max_v


def normalize_model(objects: list[bpy.types.Object]) -> tuple[Vector, Vector, float]:
    min_v, max_v = combined_bounds(objects)
    center = (min_v + max_v) * 0.5
    extent = max_v - min_v
    largest = max(extent.x, extent.y, extent.z, 0.0001)
    scale = 2.35 / largest

    parent = bpy.data.objects.new("emerald_apocalypse_charge_turntable", None)
    bpy.context.collection.objects.link(parent)

    for obj in objects:
        obj.location -= center
        obj.scale = (obj.scale.x * scale, obj.scale.y * scale, obj.scale.z * scale)
        obj.parent = parent

    bpy.context.view_layer.update()
    min_n, max_n = combined_bounds(objects)
    return min_n, max_n, scale


def look_at(obj: bpy.types.Object, target: Vector) -> None:
    direction = target - obj.location
    obj.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()


def setup_camera_and_lights(ortho_scale: float) -> bpy.types.Object:
    camera_data = bpy.data.cameras.new("Icon Camera")
    camera = bpy.data.objects.new("Icon Camera", camera_data)
    bpy.context.collection.objects.link(camera)
    camera.location = (3.65, -5.05, 3.35)
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = ortho_scale
    look_at(camera, Vector((0, 0, 0.12)))
    bpy.context.scene.camera = camera

    key_data = bpy.data.lights.new("Factorio-ish key", "AREA")
    key = bpy.data.objects.new("Factorio-ish key", key_data)
    bpy.context.collection.objects.link(key)
    key.location = (-3.8, -4.5, 5.6)
    key.data.energy = 620
    key.data.size = 4.0

    rim_data = bpy.data.lights.new("Emerald containment rim", "POINT")
    rim = bpy.data.objects.new("Emerald containment rim", rim_data)
    bpy.context.collection.objects.link(rim)
    rim.location = (1.5, 2.1, 1.4)
    rim.data.energy = 78
    rim.data.color = (0.22, 1.0, 0.58)
    rim.data.shadow_soft_size = 4.0

    fill_data = bpy.data.lights.new("Soft fill", "AREA")
    fill = bpy.data.objects.new("Soft fill", fill_data)
    bpy.context.collection.objects.link(fill)
    fill.location = (3.4, 3.2, 4.2)
    fill.data.energy = 55
    fill.data.size = 5.5

    return camera


def configure_render(resolution: int, samples: int) -> None:
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.samples = samples
    scene.cycles.use_denoising = True
    scene.render.film_transparent = True
    scene.render.resolution_x = resolution
    scene.render.resolution_y = resolution
    scene.render.resolution_percentage = 100
    scene.view_settings.view_transform = "Standard"
    scene.view_settings.look = "Medium High Contrast"
    scene.view_settings.exposure = 0
    scene.view_settings.gamma = 1
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.world = bpy.data.worlds.new("transparent icon world")
    scene.world.color = (0, 0, 0)


def render_frames(args: argparse.Namespace, parent: bpy.types.Object, output_dir: Path) -> list[dict[str, float | int | str]]:
    output_dir.mkdir(parents=True, exist_ok=True)
    if args.selected_index is None:
        indices = range(args.frames)
    else:
        indices = [max(0, min(args.frames - 1, args.selected_index))]

    records = []
    for index in indices:
        angle = math.radians(args.initial_angle + (360.0 * index / args.frames))
        parent.rotation_euler = (0, 0, angle)
        bpy.context.view_layer.update()
        path = output_dir / f"frame_{index:03d}.png"
        bpy.context.scene.render.filepath = str(path)
        bpy.ops.render.render(write_still=True)
        records.append({"index": index, "angle_degrees": math.degrees(angle) % 360.0, "path": str(path)})
    return records


def main() -> None:
    args = parse_args()
    source = Path(args.input).resolve()
    output_dir = Path(args.output_dir).resolve()
    if not source.exists():
        raise FileNotFoundError(source)

    clear_scene()
    meshes = import_model(source)
    min_v, max_v, scale = normalize_model(meshes)
    parent = bpy.data.objects["emerald_apocalypse_charge_turntable"]
    extent = max_v - min_v
    setup_camera_and_lights(max(extent.x, extent.y, extent.z) * 1.32)
    configure_render(args.resolution, args.samples)
    records = render_frames(args, parent, output_dir)

    manifest_path = Path(args.manifest).resolve() if args.manifest else output_dir / "turntable-manifest.json"
    manifest = {
        "source": str(source),
        "output_dir": str(output_dir),
        "frames": args.frames,
        "resolution": args.resolution,
        "samples": args.samples,
        "selected_index": args.selected_index,
        "normalization_scale": scale,
        "normalized_bounds": {
            "min": [min_v.x, min_v.y, min_v.z],
            "max": [max_v.x, max_v.y, max_v.z],
        },
        "renders": records,
    }
    manifest_path.parent.mkdir(parents=True, exist_ok=True)
    manifest_path.write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    print(f"Wrote {manifest_path}")


if __name__ == "__main__":
    main()
