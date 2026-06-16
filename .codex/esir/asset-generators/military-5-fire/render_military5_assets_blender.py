import argparse
import json
import math
import sys
from pathlib import Path

import bpy
from mathutils import Vector


INCINERATOR_DIRECTION_COUNT = 32
INCINERATOR_NORTH_OFFSET = 4


def clear_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete()


def ensure_dir(path):
    Path(path).mkdir(parents=True, exist_ok=True)


def setup_render(frame_size, samples):
    scene = bpy.context.scene
    scene.render.resolution_x = frame_size
    scene.render.resolution_y = frame_size
    scene.render.resolution_percentage = 100
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.view_settings.view_transform = "Standard"
    scene.view_settings.look = "Medium High Contrast"
    scene.view_settings.exposure = 0
    scene.view_settings.gamma = 1

    for engine in ("BLENDER_EEVEE_NEXT", "BLENDER_EEVEE"):
        try:
            scene.render.engine = engine
            break
        except TypeError:
            continue

    if hasattr(scene, "eevee"):
        if hasattr(scene.eevee, "taa_render_samples"):
            scene.eevee.taa_render_samples = samples
        if hasattr(scene.eevee, "use_gtao"):
            scene.eevee.use_gtao = True
        if hasattr(scene.eevee, "gtao_distance"):
            scene.eevee.gtao_distance = 3
        if hasattr(scene.eevee, "use_bloom"):
            scene.eevee.use_bloom = True
            scene.eevee.bloom_intensity = 0.08


def look_at(obj, target):
    direction = Vector(target) - obj.location
    obj.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()


def add_camera(elevation=60, yaw=45, distance=8, ortho_scale=2.8):
    yaw_rad = math.radians(yaw)
    elev_rad = math.radians(elevation)
    xy = math.cos(elev_rad) * distance
    camera_data = bpy.data.cameras.new("FactorioCamera")
    camera = bpy.data.objects.new("FactorioCamera", camera_data)
    bpy.context.collection.objects.link(camera)
    camera.location = (
        math.cos(yaw_rad) * xy,
        math.sin(yaw_rad) * xy,
        math.sin(elev_rad) * distance,
    )
    look_at(camera, (0, 0, 0.35))
    camera_data.type = "ORTHO"
    camera_data.ortho_scale = ortho_scale
    bpy.context.scene.camera = camera
    return camera


def add_lights():
    world = bpy.context.scene.world or bpy.data.worlds.new("World")
    bpy.context.scene.world = world
    world.color = (0, 0, 0)

    key_data = bpy.data.lights.new("upper_left_key", "AREA")
    key = bpy.data.objects.new("upper_left_key", key_data)
    bpy.context.collection.objects.link(key)
    key.location = (-4.5, -5.0, 6.0)
    key_data.energy = 550
    key_data.size = 5

    fill_data = bpy.data.lights.new("soft_fill", "POINT")
    fill = bpy.data.objects.new("soft_fill", fill_data)
    bpy.context.collection.objects.link(fill)
    fill.location = (4.0, 5.0, 4.0)
    fill_data.energy = 65

    rim_data = bpy.data.lights.new("ember_rim", "POINT")
    rim = bpy.data.objects.new("ember_rim", rim_data)
    bpy.context.collection.objects.link(rim)
    rim.location = (0, -3.5, 2.2)
    rim_data.energy = 55
    rim_data.color = (1.0, 0.42, 0.12)


def import_model(path):
    bpy.ops.import_scene.gltf(filepath=str(path))
    meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    if not meshes:
        raise RuntimeError(f"No mesh objects imported from {path}")
    return meshes


def mesh_stats(meshes):
    polygons = sum(len(obj.data.polygons) for obj in meshes)
    vertices = sum(len(obj.data.vertices) for obj in meshes)
    return {"mesh_count": len(meshes), "polygons": polygons, "vertices": vertices}


def normalize_meshes(meshes):
    bpy.ops.object.select_all(action="DESELECT")
    if len(meshes) > 1:
        for obj in meshes:
            obj.select_set(True)
        bpy.context.view_layer.objects.active = meshes[0]
        bpy.ops.object.join()
        obj = bpy.context.view_layer.objects.active
    else:
        obj = meshes[0]
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj

    bpy.context.view_layer.update()
    corners = [obj.matrix_world @ Vector(corner) for corner in obj.bound_box]
    min_v = Vector((min(v.x for v in corners), min(v.y for v in corners), min(v.z for v in corners)))
    max_v = Vector((max(v.x for v in corners), max(v.y for v in corners), max(v.z for v in corners)))
    center = (min_v + max_v) * 0.5
    obj.location -= center
    bpy.context.view_layer.update()
    corners = [obj.matrix_world @ Vector(corner) for corner in obj.bound_box]
    min_z = min(v.z for v in corners)
    obj.location.z -= min_z
    bpy.context.view_layer.update()
    return obj


def decimate_for_render(obj, target_polygons):
    current = len(obj.data.polygons)
    if current <= target_polygons:
        return {"applied": False, "polygons_before": current, "polygons_after": current}
    ratio = max(0.04, min(1.0, target_polygons / current))
    mod = obj.modifiers.new("render_only_decimate", "DECIMATE")
    mod.ratio = ratio
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.modifier_apply(modifier=mod.name)
    return {
        "applied": True,
        "ratio": ratio,
        "polygons_before": current,
        "polygons_after": len(obj.data.polygons),
    }


def render_png(path):
    ensure_dir(Path(path).parent)
    bpy.context.scene.render.filepath = str(path)
    bpy.ops.render.render(write_still=True)


def render_incinerator(repo_root, output_root, quality):
    clear_scene()
    frame_size = 128 if quality == "final" else 96
    directions = INCINERATOR_DIRECTION_COUNT if quality == "final" else 8
    frames = 8 if quality == "final" else 4
    samples = 32 if quality == "final" else 12
    setup_render(frame_size, samples)
    add_camera(ortho_scale=2.75)
    add_lights()

    meshes = import_model(repo_root / "models" / "incinerator-bot.glb")
    stats_before = mesh_stats(meshes)
    obj = normalize_meshes(meshes)
    decimate = decimate_for_render(obj, 260000 if quality == "final" else 120000)
    stats_after = mesh_stats([obj])

    root = bpy.data.objects.new("incinerator_root", None)
    bpy.context.collection.objects.link(root)
    obj.parent = root
    base_dir = output_root / "incinerator" / quality / "frames" / "base"
    for direction in range(directions):
        if directions == INCINERATOR_DIRECTION_COUNT:
            # Factorio rotated animations are north-first and advance clockwise.
            # The source model's neutral render points roughly northeast, so map
            # direction 0 to the old north-facing index and reverse the order.
            source_direction = (INCINERATOR_NORTH_OFFSET - direction) % directions
        else:
            source_direction = direction
        root.rotation_euler.z = (2 * math.pi * source_direction / directions)
        for frame in range(frames):
            root.location.z = 0.025 * math.sin(2 * math.pi * frame / frames)
            render_png(base_dir / f"d{direction:02d}_f{frame:02d}.png")

    icon_dir = output_root / "incinerator" / quality / "icon-source"
    setup_render(256, samples)
    add_camera(ortho_scale=2.35)
    root.rotation_euler.z = math.radians(-35)
    root.location.z = 0
    render_png(icon_dir / "ei-incinerator-capsule-source.png")

    return {
        "asset": "ei-incinerator",
        "quality": quality,
        "frame_size": frame_size,
        "directions": directions,
        "frames": frames,
        "columns": frames,
        "direction_order": "north-first-clockwise" if directions == INCINERATOR_DIRECTION_COUNT else "smoke-preview",
        "stats_before": stats_before,
        "stats_after": stats_after,
        "decimate": decimate,
        "base_frames": str(base_dir),
        "icon_source": str(icon_dir / "ei-incinerator-capsule-source.png"),
    }


def render_grenade(repo_root, output_root, quality):
    clear_scene()
    frame_size = 64 if quality == "final" else 64
    frames = 16 if quality == "final" else 8
    samples = 32 if quality == "final" else 12
    setup_render(frame_size, samples)
    add_camera(ortho_scale=2.45)
    add_lights()

    meshes = import_model(repo_root / "models" / "inferno-grenade.glb")
    stats_before = mesh_stats(meshes)
    obj = normalize_meshes(meshes)
    decimate = decimate_for_render(obj, 220000 if quality == "final" else 100000)
    stats_after = mesh_stats([obj])

    root = bpy.data.objects.new("inferno_grenade_root", None)
    bpy.context.collection.objects.link(root)
    obj.parent = root

    frames_dir = output_root / "inferno-grenade" / quality / "frames" / "projectile"
    for frame in range(frames):
        root.rotation_euler.z = 2 * math.pi * frame / frames
        root.rotation_euler.x = math.radians(12) * math.sin(2 * math.pi * frame / frames)
        root.rotation_euler.y = math.radians(18) * math.cos(2 * math.pi * frame / frames)
        render_png(frames_dir / f"f{frame:02d}.png")

    icon_dir = output_root / "inferno-grenade" / quality / "icon-source"
    setup_render(256, samples)
    add_camera(ortho_scale=2.25)
    root.rotation_euler.z = math.radians(-30)
    root.rotation_euler.x = math.radians(10)
    root.rotation_euler.y = math.radians(-18)
    render_png(icon_dir / "ei-inferno-grenade-source.png")

    return {
        "asset": "ei-inferno-grenade",
        "quality": quality,
        "frame_size": frame_size,
        "frames": frames,
        "columns": 8,
        "stats_before": stats_before,
        "stats_after": stats_after,
        "decimate": decimate,
        "projectile_frames": str(frames_dir),
        "icon_source": str(icon_dir / "ei-inferno-grenade-source.png"),
    }


def render_fragment(repo_root, output_root, quality):
    clear_scene()
    frame_size = 64
    frames = 16 if quality == "final" else 8
    samples = 32 if quality == "final" else 12
    setup_render(frame_size, samples)
    add_camera(ortho_scale=2.15)
    add_lights()

    meshes = import_model(repo_root / "models" / "inferno-grenade-fragment.glb")
    stats_before = mesh_stats(meshes)
    obj = normalize_meshes(meshes)
    decimate = decimate_for_render(obj, 180000 if quality == "final" else 80000)
    stats_after = mesh_stats([obj])

    root = bpy.data.objects.new("inferno_grenade_fragment_root", None)
    bpy.context.collection.objects.link(root)
    obj.parent = root

    frames_dir = output_root / "inferno-grenade-fragment" / quality / "frames" / "projectile"
    for frame in range(frames):
        root.rotation_euler.z = 2 * math.pi * frame / frames
        root.rotation_euler.x = math.radians(24) * math.sin(2 * math.pi * frame / frames)
        root.rotation_euler.y = math.radians(22) * math.cos(2 * math.pi * frame / frames)
        render_png(frames_dir / f"f{frame:02d}.png")

    return {
        "asset": "ei-inferno-grenade-fragment",
        "quality": quality,
        "frame_size": frame_size,
        "frames": frames,
        "columns": 8,
        "stats_before": stats_before,
        "stats_after": stats_after,
        "decimate": decimate,
        "projectile_frames": str(frames_dir),
    }


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo-root", default=".")
    parser.add_argument("--output-root", default="output/meshy/military-5-fire")
    parser.add_argument("--quality", choices=("smoke", "final"), default="final")
    parser.add_argument("--asset", choices=("all", "incinerator", "grenade", "fragment"), default="all")
    argv = sys.argv
    if "--" in argv:
        argv = argv[argv.index("--") + 1:]
    else:
        argv = []
    args = parser.parse_args(argv)

    repo_root = Path(args.repo_root).resolve()
    output_root = (repo_root / args.output_root).resolve()
    ensure_dir(output_root)

    results = []
    if args.asset in ("all", "incinerator"):
        results.append(render_incinerator(repo_root, output_root, args.quality))
    if args.asset in ("all", "grenade"):
        results.append(render_grenade(repo_root, output_root, args.quality))
    if args.asset in ("all", "fragment"):
        results.append(render_fragment(repo_root, output_root, args.quality))

    manifest = {
        "script": Path(__file__).as_posix(),
        "quality": args.quality,
        "output_root": str(output_root),
        "results": results,
    }
    manifest_path = output_root / f"military-5-fire-{args.quality}-render-manifest.json"
    manifest_path.write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    print(json.dumps(manifest, indent=2))


if __name__ == "__main__":
    main()
