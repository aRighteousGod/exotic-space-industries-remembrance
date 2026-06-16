from __future__ import annotations

import argparse
import json
import shutil
import subprocess
import sys
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter


ASSET_NAME = "ei-singularity-lance-base-render"
BODY_FILENAME = "singularity-lance.png"
BASE_SHADOW_FILENAME = "singularity-lance_base-shadow.png"
FRAME_SIZE = 768
PYRAMID_CONTACT_POINT = (384, 428)

SOURCE_GLB = Path(r"C:\Users\Theorun\Documents\Development\Meshy_AI_Prism_of_the_Ancients_0503175722_texture.glb")
FACECLIP_CUTOFF = -0.09
TIP_PLUG_HALF_EXTENT = 0.032
TIP_PLUG_HEIGHT = 0.026
TIP_PLUG_BASE_DROP = 0.020
TIP_PLUG_CENTER = (0.004, -0.004)
SHADOW_GROUND_Z = 0.02

ORTHO_SCALE = "3.171489715576172"
TILE_SIZE = "64"
RENDER_INITIAL_ANGLE = "90"


def find_repo_root(start: Path) -> Path:
    for path in [start, *start.parents]:
        if (path / ".gitignore").exists() and (path / "exotic-space-industries-remembrance").exists():
            return path
    raise RuntimeError(f"Could not find repository root from {start}")


REPO_ROOT = find_repo_root(Path(__file__).resolve())
ROOT = REPO_ROOT / "output" / "meshy" / ASSET_NAME
EXPORT_DIR = ROOT / "factorio-export"
PREVIEW_DIR = ROOT / "previews"
SOURCE_DIR = ROOT / "source"
PREPARED_DIR = ROOT / "prepared"
RENDER_DIR = ROOT / "render"
GRAPHICS_DIR = REPO_ROOT / "exotic-space-industries-remembrance" / "graphics" / "entities" / "singularity-lance"
BODY_OUTPUT = EXPORT_DIR / BODY_FILENAME
SHADOW_OUTPUT = EXPORT_DIR / BASE_SHADOW_FILENAME
TIP_OUTPUT = EXPORT_DIR / "singularity-lance-tip-plug-overlay.png"
PROMOTED_BODY = GRAPHICS_DIR / BODY_FILENAME
PROMOTED_SHADOW = GRAPHICS_DIR / BASE_SHADOW_FILENAME
BODY_GLB = PREPARED_DIR / "ei-singularity-lance-base-faceclip-body.glb"
TIP_GLB = PREPARED_DIR / "ei-singularity-lance-base-faceclip-tip-plug-only.glb"
SHADOW_GLB = PREPARED_DIR / "ei-singularity-lance-base-faceclip-plug-only-grounded.glb"


def find_blender() -> Path:
    candidates = [
        Path(r"C:\Program Files\Blender Foundation\Blender 5.1\blender.exe"),
        Path(r"C:\Program Files\Blender Foundation\Blender 4.4\blender.exe"),
    ]
    for candidate in candidates:
        if candidate.exists():
            return candidate
    raise RuntimeError("Could not find Blender 5.1 or 4.4 under C:\\Program Files\\Blender Foundation")


PREP_SCRIPT = r'''
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import bmesh
import bpy


def parse_args():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--source-glb", required=True)
    parser.add_argument("--body-glb", required=True)
    parser.add_argument("--tip-glb", required=True)
    parser.add_argument("--shadow-glb", required=True)
    parser.add_argument("--report", required=True)
    parser.add_argument("--cutoff", type=float, required=True)
    parser.add_argument("--tip-half-extent", type=float, required=True)
    parser.add_argument("--tip-height", type=float, required=True)
    parser.add_argument("--tip-base-drop", type=float, required=True)
    parser.add_argument("--tip-center-x", type=float, required=True)
    parser.add_argument("--tip-center-y", type=float, required=True)
    parser.add_argument("--shadow-ground-z", type=float, required=True)
    return parser.parse_args(argv)


def clear_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete()


def make_mat(name, color, emission=0.0):
    material = bpy.data.materials.new(name)
    material.diffuse_color = color
    material.use_nodes = True
    if material.node_tree:
        bsdf = material.node_tree.nodes.get("Principled BSDF")
        if bsdf:
            bsdf.inputs["Base Color"].default_value = color
            bsdf.inputs["Roughness"].default_value = 0.84
            bsdf.inputs["Alpha"].default_value = color[3]
            bsdf.inputs["Emission Color"].default_value = (color[0], color[1], color[2], 1.0)
            bsdf.inputs["Emission Strength"].default_value = emission
    return material


def import_joined_mesh(source_glb):
    clear_scene()
    bpy.ops.import_scene.gltf(filepath=str(source_glb))
    meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    if not meshes:
        raise RuntimeError("No mesh objects imported")

    bpy.ops.object.select_all(action="DESELECT")
    for obj in meshes:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    if len(meshes) > 1:
        bpy.ops.object.join()
    obj = bpy.context.view_layer.objects.active
    obj.name = "singularity_lance_base_clipped_source"
    bpy.context.view_layer.update()
    return obj


def clip_above_world_z(obj, cutoff):
    matrix = obj.matrix_world.copy()
    mesh = obj.data
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bm.faces.ensure_lookup_table()
    remove_faces = [
        face
        for face in bm.faces
        if max((matrix @ vert.co).z for vert in face.verts) > cutoff
    ]
    before_faces = len(bm.faces)
    bmesh.ops.delete(bm, geom=remove_faces, context="FACES")
    bm.to_mesh(mesh)
    bm.free()
    mesh.update()

    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="DESELECT")
    bpy.ops.mesh.delete_loose()
    bpy.ops.object.mode_set(mode="OBJECT")

    return {
        "faces_before": before_faces,
        "faces_removed": len(remove_faces),
        "faces_after": len(mesh.polygons),
    }


def make_materials_opaque():
    for material in bpy.data.materials:
        material.blend_method = "OPAQUE"
        material.use_nodes = True
        if material.node_tree:
            bsdf = material.node_tree.nodes.get("Principled BSDF")
            if bsdf:
                bsdf.inputs["Alpha"].default_value = 1.0


def add_faceted_tip(cutoff, half_extent, height, base_drop, center_x, center_y):
    lit_mat = make_mat("upper_pyramid_tip_lit", (0.082, 0.395, 0.318, 1.0), 0.08)
    mid_mat = make_mat("upper_pyramid_tip_mid", (0.058, 0.318, 0.258, 1.0), 0.09)
    dark_mat = make_mat("upper_pyramid_tip_dark", (0.042, 0.245, 0.208, 1.0), 0.09)
    base_mat = make_mat("upper_pyramid_tip_base_fill", (0.052, 0.300, 0.248, 1.0), 0.16)

    z_base = cutoff - base_drop
    z_apex = cutoff + height
    cx = center_x
    cy = center_y
    h = half_extent
    verts = [
        (cx, cy, z_apex),
        (cx - h, cy - h, z_base),
        (cx + h, cy - h, z_base),
        (cx + h, cy + h, z_base),
        (cx - h, cy + h, z_base),
    ]
    faces = [
        (0, 3, 4),
        (0, 2, 3),
        (0, 1, 2),
        (0, 4, 1),
        (1, 4, 3, 2),
    ]
    mesh = bpy.data.meshes.new("upper_pyramid_tip_plug_mesh")
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new("upper_pyramid_tip_plug", mesh)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(lit_mat)
    obj.data.materials.append(mid_mat)
    obj.data.materials.append(dark_mat)
    obj.data.materials.append(base_mat)
    obj.data.polygons[0].material_index = 0
    obj.data.polygons[1].material_index = 1
    obj.data.polygons[2].material_index = 2
    obj.data.polygons[3].material_index = 1
    obj.data.polygons[4].material_index = 3
    return obj


def mesh_world_bounds():
    min_corner = [float("inf"), float("inf"), float("inf")]
    max_corner = [float("-inf"), float("-inf"), float("-inf")]
    for obj in bpy.context.scene.objects:
        if obj.type != "MESH":
            continue
        for corner in obj.bound_box:
            world = obj.matrix_world @ __import__("mathutils").Vector(corner)
            min_corner[0] = min(min_corner[0], world.x)
            min_corner[1] = min(min_corner[1], world.y)
            min_corner[2] = min(min_corner[2], world.z)
            max_corner[0] = max(max_corner[0], world.x)
            max_corner[1] = max(max_corner[1], world.y)
            max_corner[2] = max(max_corner[2], world.z)
    return min_corner, max_corner


def translate_meshes_z(delta):
    for obj in bpy.context.scene.objects:
        if obj.type == "MESH":
            obj.location.z += delta
    bpy.context.view_layer.update()


def remove_shadowless_tip_plug():
    removed = []
    for obj in list(bpy.context.scene.objects):
        if obj.name.startswith("upper_pyramid_tip_plug"):
            removed.append(obj.name)
            bpy.data.objects.remove(obj, do_unlink=True)
    bpy.context.view_layer.update()
    return removed


def export_glb(path):
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=str(path), export_format="GLB", use_selection=False)


def export_selected_glb(path, objects):
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0] if objects else None
    bpy.ops.export_scene.gltf(filepath=str(path), export_format="GLB", use_selection=True)
    bpy.ops.object.select_all(action="DESELECT")


def main():
    args = parse_args()
    source_glb = Path(args.source_glb).resolve()
    body_glb = Path(args.body_glb).resolve()
    tip_glb = Path(args.tip_glb).resolve()
    shadow_glb = Path(args.shadow_glb).resolve()
    report_path = Path(args.report).resolve()

    obj = import_joined_mesh(source_glb)
    clip_report = clip_above_world_z(obj, args.cutoff)
    make_materials_opaque()
    export_glb(body_glb)

    tip_plug = add_faceted_tip(
        args.cutoff,
        args.tip_half_extent,
        args.tip_height,
        args.tip_base_drop,
        args.tip_center_x,
        args.tip_center_y,
    )
    export_selected_glb(tip_glb, [tip_plug])

    min_corner, max_corner = mesh_world_bounds()
    shadow_excluded_objects = remove_shadowless_tip_plug()
    translate_meshes_z(args.shadow_ground_z - min_corner[2])
    grounded_min, grounded_max = mesh_world_bounds()
    export_glb(shadow_glb)

    report = {
        "source_glb": str(source_glb),
        "body_glb": str(body_glb),
        "tip_glb": str(tip_glb),
        "shadow_glb": str(shadow_glb),
        "faceclip_cutoff": args.cutoff,
        "tip_plug_half_extent": args.tip_half_extent,
        "tip_plug_height": args.tip_height,
        "tip_plug_base_drop": args.tip_base_drop,
        "tip_plug_center": [args.tip_center_x, args.tip_center_y],
        "shadow_ground_z": args.shadow_ground_z,
        "shadow_excluded_objects": shadow_excluded_objects,
        "clip": clip_report,
        "body_bounds": {"min": min_corner, "max": max_corner},
        "grounded_shadow_bounds": {"min": grounded_min, "max": grounded_max},
    }
    report_path.parent.mkdir(parents=True, exist_ok=True)
    report_path.write_text(json.dumps(report, indent=2), encoding="utf-8")
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
'''


def clean_png(path: Path) -> None:
    image = Image.open(path).convert("RGBA")
    pixels = image.load()
    for y in range(image.height):
        for x in range(image.width):
            r, g, b, a = pixels[x, y]
            if a <= 1:
                pixels[x, y] = (0, 0, 0, 0)
    image.save(path)


def alpha_bbox(path: Path) -> tuple[int, int, int, int] | tuple[()]:
    image = Image.open(path).convert("RGBA")
    return image.getchannel("A").getbbox() or ()


def copy_sheet(source: Path, destination: Path) -> None:
    if not source.exists():
        raise FileNotFoundError(source)
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source, destination)
    clean_png(destination)


def composite_body_with_tip(body_path: Path, tip_path: Path) -> None:
    body = Image.open(body_path).convert("RGBA")
    tip = Image.open(tip_path).convert("RGBA")
    if body.size != tip.size:
        raise ValueError(f"Tip overlay size {tip.size} does not match body size {body.size}")
    Image.alpha_composite(body, tip).save(body_path)
    clean_png(body_path)


def make_preview(body_path: Path, shadow_path: Path) -> None:
    PREVIEW_DIR.mkdir(parents=True, exist_ok=True)
    body = Image.open(body_path).convert("RGBA")
    shadow = Image.open(shadow_path).convert("RGBA")
    shadow = shadow.filter(ImageFilter.GaussianBlur(0.9))
    shadow.save(shadow_path)

    composite = Image.alpha_composite(shadow, body)
    composite.save(PREVIEW_DIR / "singularity-lance-base-composite.png")

    tip_box = (315, 360, 455, 455)
    composite.crop(tip_box).resize(
        ((tip_box[2] - tip_box[0]) * 4, (tip_box[3] - tip_box[1]) * 4),
        Image.Resampling.NEAREST,
    ).save(PREVIEW_DIR / "singularity-lance-base-tip-check.png")

    marker = Image.new("RGBA", body.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(marker)
    x, y = PYRAMID_CONTACT_POINT
    draw.line((x - 8, y, x + 8, y), fill=(255, 60, 60, 255), width=1)
    draw.line((x, y - 8, x, y + 8), fill=(255, 60, 60, 255), width=1)
    marked = Image.alpha_composite(body, marker)
    marked.crop(tip_box).resize(
        ((tip_box[2] - tip_box[0]) * 4, (tip_box[3] - tip_box[1]) * 4),
        Image.Resampling.NEAREST,
    ).save(PREVIEW_DIR / "singularity-lance-base-tip-contact-marker.png")

    body_crop = body.crop((250, 330, 520, 450)).resize((540, 240), Image.Resampling.NEAREST)
    body_crop.save(PREVIEW_DIR / "singularity-lance-base-upper-pyramid-2x.png")


def render_factorio(input_glb: Path, output_dir: Path, passes: str, save_blend: Path) -> None:
    renderer = REPO_ROOT / ".codex" / "skills" / "meshy-blender-spritesheet" / "scripts" / "render_factorio_preset.py"
    command = [
        str(find_blender()),
        "--factory-startup",
        "--background",
        "--python",
        str(renderer),
        "--",
        "--preset-blend",
        str(REPO_ROOT / "factorioRenderingPreset_v4.blend"),
        "--input",
        str(input_glb),
        "--asset-name",
        ASSET_NAME,
        "--output-dir",
        str(output_dir),
        "--passes",
        passes,
        "--quality",
        "final",
        "--cycles-compute-device",
        "cuda",
        "--cycles-include-cpu",
        "--persistent-data",
        "--no-denoise",
        "--frames",
        "1",
        "--directions",
        "1",
        "--animation-frames",
        "1",
        "--initial-angle",
        RENDER_INITIAL_ANGLE,
        "--ortho-scale",
        ORTHO_SCALE,
        "--tile-size",
        TILE_SIZE,
        "--resolution",
        str(FRAME_SIZE),
        "--pack-sheets",
        "--grid",
        "1x1",
        "--no-auto-ortho-scale",
        "--no-normalize",
        "--material-report",
        "--save-blend",
        str(save_blend),
    ]
    subprocess.run(command, cwd=REPO_ROOT, check=True)


def prepare_glbs() -> dict:
    if not SOURCE_GLB.exists():
        raise FileNotFoundError(f"Source GLB not found: {SOURCE_GLB}")

    SOURCE_DIR.mkdir(parents=True, exist_ok=True)
    PREPARED_DIR.mkdir(parents=True, exist_ok=True)
    prep_script = SOURCE_DIR / "prepare_singularity_lance_base.blender.py"
    prep_report = PREPARED_DIR / "prepare-report.json"
    prep_script.write_text(PREP_SCRIPT, encoding="utf-8")

    command = [
        str(find_blender()),
        "--factory-startup",
        "--background",
        "--python",
        str(prep_script),
        "--",
        "--source-glb",
        str(SOURCE_GLB),
        "--body-glb",
        str(BODY_GLB),
        "--tip-glb",
        str(TIP_GLB),
        "--shadow-glb",
        str(SHADOW_GLB),
        "--report",
        str(prep_report),
        "--cutoff",
        str(FACECLIP_CUTOFF),
        "--tip-half-extent",
        str(TIP_PLUG_HALF_EXTENT),
        "--tip-height",
        str(TIP_PLUG_HEIGHT),
        "--tip-base-drop",
        str(TIP_PLUG_BASE_DROP),
        "--tip-center-x",
        str(TIP_PLUG_CENTER[0]),
        "--tip-center-y",
        str(TIP_PLUG_CENTER[1]),
        "--shadow-ground-z",
        str(SHADOW_GROUND_Z),
    ]
    subprocess.run(command, cwd=REPO_ROOT, check=True)
    return json.loads(prep_report.read_text(encoding="utf-8"))


def run_pipeline() -> dict:
    EXPORT_DIR.mkdir(parents=True, exist_ok=True)
    RENDER_DIR.mkdir(parents=True, exist_ok=True)

    prep_report = prepare_glbs()
    body_render_dir = RENDER_DIR / "body" / "Render"
    tip_render_dir = RENDER_DIR / "tip-plug" / "Render"
    shadow_render_dir = RENDER_DIR / "shadow" / "Render"
    render_factorio(BODY_GLB, body_render_dir, "object", RENDER_DIR / "ei-singularity-lance-base-body.blend")
    render_factorio(TIP_GLB, tip_render_dir, "object", RENDER_DIR / "ei-singularity-lance-tip-plug.blend")
    render_factorio(SHADOW_GLB, shadow_render_dir, "shadow", RENDER_DIR / "ei-singularity-lance-base-shadow.blend")

    copy_sheet(body_render_dir / ".Sheets" / "object_0.png", BODY_OUTPUT)
    copy_sheet(tip_render_dir / ".Sheets" / "object_0.png", TIP_OUTPUT)
    composite_body_with_tip(BODY_OUTPUT, TIP_OUTPUT)
    copy_sheet(shadow_render_dir / ".Sheets" / "object_shadow_0.png", SHADOW_OUTPUT)
    make_preview(BODY_OUTPUT, SHADOW_OUTPUT)
    return prep_report


def image_info(path: Path) -> dict:
    image = Image.open(path).convert("RGBA")
    return {
        "path": str(path.relative_to(REPO_ROOT)).replace("\\", "/"),
        "dimensions": [image.width, image.height],
        "alpha_bbox": list(image.getchannel("A").getbbox() or ()),
        "bytes": path.stat().st_size,
    }


def image_difference_score(a_path: Path, b_path: Path) -> float:
    a = Image.open(a_path).convert("RGBA")
    b = Image.open(b_path).convert("RGBA")
    diff = ImageChops.difference(a, b)
    return sum(diff.convert("L").getdata()) / (diff.width * diff.height * 255.0)


def write_manifest(promote: bool, prep_report: dict) -> dict:
    manifest = {
        "asset_name": ASSET_NAME,
        "mode": "glb-faceclip-plug-only-single-frame-pyramid-base",
        "source_glb": str(SOURCE_GLB),
        "frame_size": FRAME_SIZE,
        "pyramid_contact_point": list(PYRAMID_CONTACT_POINT),
        "faceclip_cutoff": FACECLIP_CUTOFF,
        "tip_plug": {
            "half_extent": TIP_PLUG_HALF_EXTENT,
            "height": TIP_PLUG_HEIGHT,
            "base_drop": TIP_PLUG_BASE_DROP,
            "center": list(TIP_PLUG_CENTER),
            "purpose": "replaces the removed thin crystal support cylinder with an axis-aligned faceted cap",
        },
        "prep_report": prep_report,
        "outputs": {
            "body": image_info(BODY_OUTPUT),
            "tip_overlay": image_info(TIP_OUTPUT),
            "base_shadow": image_info(SHADOW_OUTPUT),
            "promoted": promote,
        },
        "prototype": {
            "file": "exotic-space-industries-remembrance/prototypes/alien-system/singularity-lance.lua",
            "body_frame_count": 1,
            "base_shadow_frame_count": 1,
        },
    }
    if PROMOTED_BODY.exists():
        manifest["difference_from_promoted_body_before_current_run"] = image_difference_score(BODY_OUTPUT, PROMOTED_BODY)
    ROOT.mkdir(parents=True, exist_ok=True)
    with (ROOT / "generation-report.json").open("w", encoding="utf-8") as handle:
        json.dump(manifest, handle, indent=2)
        handle.write("\n")
    with (EXPORT_DIR / f"{ASSET_NAME}.factorio-asset-manifest.json").open("w", encoding="utf-8") as handle:
        json.dump(manifest, handle, indent=2)
        handle.write("\n")
    return manifest


def promote_outputs() -> None:
    GRAPHICS_DIR.mkdir(parents=True, exist_ok=True)
    shutil.copy2(BODY_OUTPUT, PROMOTED_BODY)
    shutil.copy2(SHADOW_OUTPUT, PROMOTED_SHADOW)


def main() -> None:
    parser = argparse.ArgumentParser(description="Render the Singularity Lance pyramid base and base shadow from the source Prism GLB.")
    parser.add_argument("--promote", action="store_true", help="Copy rendered sheets into the live Singularity Lance graphics folder.")
    args = parser.parse_args()

    prep_report = run_pipeline()
    manifest = write_manifest(promote=False, prep_report=prep_report)
    if args.promote:
        promote_outputs()
        manifest = write_manifest(promote=True, prep_report=prep_report)
    print(json.dumps(manifest, indent=2))


if __name__ == "__main__":
    sys.exit(main())
