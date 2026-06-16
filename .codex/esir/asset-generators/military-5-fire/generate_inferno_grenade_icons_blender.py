import argparse
import json
import math
import sys
from pathlib import Path

import bpy
from mathutils import Vector
from PIL import Image, ImageEnhance, ImageFilter


ITEM_MIPS = (128, 64, 32)
TECH_MIPS = (256, 128, 64, 32)


def ensure_dir(path):
    Path(path).mkdir(parents=True, exist_ok=True)


def clear_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete()


def setup_render(size, samples):
    scene = bpy.context.scene
    scene.render.resolution_x = size
    scene.render.resolution_y = size
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


def add_camera(elevation=60, yaw=45, distance=8, ortho_scale=3.2):
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
    key_data.energy = 640
    key_data.size = 5

    fill_data = bpy.data.lights.new("soft_fill", "POINT")
    fill = bpy.data.objects.new("soft_fill", fill_data)
    bpy.context.collection.objects.link(fill)
    fill.location = (4.0, 5.0, 4.0)
    fill_data.energy = 85

    rim_data = bpy.data.lights.new("ember_rim", "POINT")
    rim = bpy.data.objects.new("ember_rim", rim_data)
    bpy.context.collection.objects.link(rim)
    rim.location = (0, -3.5, 2.2)
    rim_data.energy = 80
    rim_data.color = (1.0, 0.42, 0.12)


def normalize_model(path):
    bpy.ops.import_scene.gltf(filepath=str(path))
    meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    if not meshes:
        raise RuntimeError(f"No mesh objects imported from {path}")

    bpy.ops.object.select_all(action="DESELECT")
    for obj in meshes:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    if len(meshes) > 1:
        bpy.ops.object.join()
    obj = bpy.context.view_layer.objects.active

    bpy.context.view_layer.update()
    corners = [obj.matrix_world @ Vector(corner) for corner in obj.bound_box]
    min_v = Vector((min(v.x for v in corners), min(v.y for v in corners), min(v.z for v in corners)))
    max_v = Vector((max(v.x for v in corners), max(v.y for v in corners), max(v.z for v in corners)))
    center = (min_v + max_v) * 0.5
    obj.location -= center
    bpy.context.view_layer.update()
    min_z = min((obj.matrix_world @ Vector(corner)).z for corner in obj.bound_box)
    obj.location.z -= min_z
    bpy.context.view_layer.update()

    root = bpy.data.objects.new("inferno_grenade_icon_root", None)
    bpy.context.collection.objects.link(root)
    obj.parent = root
    return root, obj


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


def enhance(image):
    image = image.convert("RGBA")
    red, green, blue, alpha = image.split()
    rgb = Image.merge("RGB", (red, green, blue))
    rgb = ImageEnhance.Brightness(rgb).enhance(1.18)
    rgb = ImageEnhance.Contrast(rgb).enhance(1.08)
    rgb = ImageEnhance.Color(rgb).enhance(1.08)
    return Image.merge("RGBA", (*rgb.split(), alpha))


def trim(image):
    bbox = image.getbbox()
    return image.crop(bbox) if bbox else image


def fit(image, max_size):
    image = trim(image).copy()
    image.thumbnail(max_size, Image.Resampling.LANCZOS)
    return image


def build_item_strip(source, output):
    source = enhance(source)
    subject = fit(source, (102, 102))
    base = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    base.alpha_composite(subject, ((128 - subject.width) // 2, (128 - subject.height) // 2))

    strip = Image.new("RGBA", (224, 128), (0, 0, 0, 0))
    x = 0
    for size in ITEM_MIPS:
        mip = base if size == 128 else base.resize((size, size), Image.Resampling.LANCZOS)
        strip.alpha_composite(mip, (x, 0))
        x += size
    ensure_dir(output.parent)
    strip.save(output)


def make_shadow(source, max_size):
    subject = fit(source.getchannel("A"), max_size)
    shadow = Image.new("RGBA", subject.size, (0, 0, 0, 0))
    alpha = subject.filter(ImageFilter.GaussianBlur(max(2, subject.width // 30)))
    shadow.putalpha(alpha.point(lambda value: int(value * 0.42)))
    return shadow


def build_tech_strip(source, output):
    source = enhance(source)
    base = Image.new("RGBA", (256, 256), (0, 0, 0, 0))

    shadow = make_shadow(source, (182, 72))
    base.alpha_composite(shadow, ((256 - shadow.width) // 2 + 14, 160))

    ember = Image.new("RGBA", (128, 42), (255, 92, 12, 0))
    ember_alpha = Image.new("L", ember.size, 0)
    for x in range(ember.width):
        for y in range(ember.height):
            dx = (x - ember.width / 2) / (ember.width / 2)
            dy = (y - ember.height / 2) / (ember.height / 2)
            value = max(0, 1 - dx * dx - dy * dy)
            ember_alpha.putpixel((x, y), int(78 * value))
    ember.putalpha(ember_alpha.filter(ImageFilter.GaussianBlur(7)))
    base.alpha_composite(ember, (64, 151))

    subject = fit(source, (194, 168))
    base.alpha_composite(subject, ((256 - subject.width) // 2, 20))

    strip = Image.new("RGBA", (sum(TECH_MIPS), 256), (0, 0, 0, 0))
    x = 0
    for size in TECH_MIPS:
        mip = base if size == 256 else base.resize((size, size), Image.Resampling.LANCZOS)
        strip.alpha_composite(mip, (x, 0))
        x += size
    ensure_dir(output.parent)
    strip.save(output)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo-root", default=".")
    parser.add_argument("--output-root", default="output/meshy/military-5-fire/inferno-grenade-icons")
    parser.add_argument("--source-size", type=int, default=512)
    argv = sys.argv
    if "--" in argv:
        argv = argv[argv.index("--") + 1:]
    else:
        argv = []
    args = parser.parse_args(argv)

    repo_root = Path(args.repo_root).resolve()
    output_root = (repo_root / args.output_root).resolve()
    source_path = output_root / "inferno-grenade-icon-source.png"
    preview_path = output_root / "inferno-grenade-icons-preview.png"

    clear_scene()
    setup_render(args.source_size, 48)
    add_camera(ortho_scale=3.1)
    add_lights()
    root, obj = normalize_model(repo_root / "models" / "inferno-grenade.glb")
    decimate = decimate_for_render(obj, 240000)
    root.rotation_euler.z = math.radians(-30)
    root.rotation_euler.x = math.radians(8)
    root.rotation_euler.y = math.radians(-18)
    render_png(source_path)

    source = Image.open(source_path).convert("RGBA")
    item_output = repo_root / "exotic-space-industries-remembrance-graphics-4" / "graphics" / "items" / "inferno-grenade.png"
    tech_output = repo_root / "exotic-space-industries-remembrance-graphics-4" / "graphics" / "techs" / "inferno-grenade.png"
    build_item_strip(source, item_output)
    build_tech_strip(source, tech_output)

    preview = Image.new("RGBA", (736, 300), (18, 18, 18, 255))
    preview.alpha_composite(Image.open(item_output).convert("RGBA"), (16, 16))
    preview.alpha_composite(Image.open(tech_output).convert("RGBA"), (16, 156))
    preview.save(preview_path)

    manifest = {
        "source": str(source_path),
        "source_bbox": source.getbbox(),
        "item_icon": str(item_output),
        "tech_icon": str(tech_output),
        "preview": str(preview_path),
        "decimate": decimate,
    }
    manifest_path = output_root / "inferno-grenade-icons-manifest.json"
    manifest_path.write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    print(json.dumps(manifest, indent=2))


if __name__ == "__main__":
    main()
