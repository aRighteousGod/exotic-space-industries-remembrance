import argparse
import json
import math
import sys
from pathlib import Path

import bpy
import bmesh
from mathutils import Vector


ASSET_NAME = "ei-sawblade-turret"
BODY_OBJECT_NAME = "ei-sawblade-turret-body"
BLADE_OBJECT_NAME = "ei-sawblade-turret-blade"


def parse_args():
    parser = argparse.ArgumentParser(description="Prepare Oathbreaker Saw GLB for the Factorio preset renderer.")
    parser.add_argument("--source", required=True, help="Path to the source GLB.")
    parser.add_argument("--out", required=True, help="Prepared GLB path.")
    parser.add_argument("--target-width", type=float, default=2.9, help="Prepared model width in preset world units.")
    parser.add_argument("--manifest", help="Optional JSON manifest path.")
    parser.add_argument(
        "--legacy-material-overrides",
        action="store_true",
        help="Replace source textures with the first-pass dark body and silver blade materials.",
    )
    return parser.parse_args(sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else [])


def clear_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete()


def import_source(path):
    bpy.ops.import_scene.gltf(filepath=str(path))
    meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    if not meshes:
        raise RuntimeError(f"No mesh objects imported from {path}")
    if len(meshes) > 1:
        bpy.ops.object.select_all(action="DESELECT")
        for obj in meshes:
            obj.select_set(True)
        bpy.context.view_layer.objects.active = meshes[0]
        bpy.ops.object.join()
        meshes = [bpy.context.view_layer.objects.active]
    return meshes[0]


def world_bounds(objects):
    low = Vector((float("inf"), float("inf"), float("inf")))
    high = Vector((float("-inf"), float("-inf"), float("-inf")))
    for obj in objects:
        for corner in obj.bound_box:
            world = obj.matrix_world @ Vector(corner)
            low.x = min(low.x, world.x)
            low.y = min(low.y, world.y)
            low.z = min(low.z, world.z)
            high.x = max(high.x, world.x)
            high.y = max(high.y, world.y)
            high.z = max(high.z, world.z)
    return low, high


def normalize_mesh_object(obj, low, high, target_width):
    center = Vector(((low.x + high.x) * 0.5, (low.y + high.y) * 0.5, low.z))
    width = max(high.x - low.x, high.y - low.y)
    scale = target_width / width if width > 0 else 1.0
    world = obj.matrix_world.copy()
    mesh = obj.data
    for vertex in mesh.vertices:
        vertex.co = (world @ vertex.co - center) * scale
    mesh.update()
    obj.matrix_world.identity()
    return scale


def face_coords(world_center, low, high):
    width = max(high.x - low.x, high.y - low.y)
    radius = math.hypot(
        world_center.x - (low.x + high.x) * 0.5,
        world_center.y - (low.y + high.y) * 0.5,
    )
    radius_norm = radius / (width * 0.5) if width > 0 else 0
    z_norm = (world_center.z - low.z) / (high.z - low.z) if high.z > low.z else 0
    return radius_norm, z_norm


def face_is_blade_overlay(world_center, world_normal, low, high):
    radius_norm, z_norm = face_coords(world_center, low, high)
    high_outer_top = z_norm >= 0.76 and radius_norm >= 0.72
    tooth_side = z_norm >= 0.47 and radius_norm >= 0.82
    not_bottom_edge = world_normal.z > -0.50
    return (high_outer_top or tooth_side) and not_bottom_edge


def face_is_body_blade_cut(world_center, world_normal, low, high):
    radius_norm, z_norm = face_coords(world_center, low, high)
    outer_top_blade = z_norm >= 0.74 and radius_norm >= 0.70
    tooth_side = z_norm >= 0.47 and radius_norm >= 0.80
    return outer_top_blade or tooth_side


def component_is_blade(stats):
    high_outer_ring = (
        stats["faces"] >= 50
        and stats["z_avg"] >= 0.78
        and stats["r_avg"] >= 0.72
        and stats["r_max"] >= 0.90
    )
    high_outer_teeth = (
        stats["faces"] >= 4
        and stats["z_avg"] >= 0.82
        and stats["r_avg"] >= 0.84
        and stats["r_max"] >= 0.89
    )
    return high_outer_ring or high_outer_teeth


def component_is_body_blade_cut(stats):
    upper_blade_zone = (
        stats["z_avg"] >= 0.74
        and stats["r_avg"] >= 0.56
        and stats["r_max"] >= 0.63
    )
    return component_is_blade(stats) or upper_blade_zone


def split_mesh_by_blade(source_obj, low, high):
    body = source_obj.copy()
    body.data = source_obj.data.copy()
    body.name = BODY_OBJECT_NAME
    body.data.name = BODY_OBJECT_NAME
    bpy.context.collection.objects.link(body)

    blade = source_obj.copy()
    blade.data = source_obj.data.copy()
    blade.name = BLADE_OBJECT_NAME
    blade.data.name = BLADE_OBJECT_NAME
    bpy.context.collection.objects.link(blade)

    def delete_faces(obj, should_delete_component):
        mesh = obj.data
        bm = bmesh.new()
        bm.from_mesh(mesh)
        bm.faces.ensure_lookup_table()
        width = max(high.x - low.x, high.y - low.y)
        height = high.z - low.z
        center_x = (low.x + high.x) * 0.5
        center_y = (low.y + high.y) * 0.5

        def rz_for_face(face):
            world_center = obj.matrix_world @ face.calc_center_median()
            radius = math.hypot(world_center.x - center_x, world_center.y - center_y)
            radius_norm = radius / (width * 0.5) if width > 0 else 0
            z_norm = (world_center.z - low.z) / height if height > 0 else 0
            return radius_norm, z_norm

        seen = set()
        doomed = []
        for face in bm.faces:
            if face in seen:
                continue

            stack = [face]
            seen.add(face)
            component_faces = []
            while stack:
                current = stack.pop()
                component_faces.append(current)
                for edge in current.edges:
                    for linked_face in edge.link_faces:
                        if linked_face not in seen:
                            seen.add(linked_face)
                            stack.append(linked_face)

            radii = []
            zs = []
            for component_face in component_faces:
                radius_norm, z_norm = rz_for_face(component_face)
                radii.append(radius_norm)
                zs.append(z_norm)

            stats = {
                "faces": len(component_faces),
                "r_min": min(radii),
                "r_max": max(radii),
                "r_avg": sum(radii) / len(radii),
                "z_min": min(zs),
                "z_max": max(zs),
                "z_avg": sum(zs) / len(zs),
            }
            if should_delete_component(stats):
                doomed.extend(component_faces)
        bmesh.ops.delete(bm, geom=doomed, context="FACES")
        bm.to_mesh(mesh)
        bm.free()
        mesh.update()
        return len(doomed)

    body_deleted = delete_faces(body, component_is_body_blade_cut)
    blade_deleted = delete_faces(blade, lambda stats: not component_is_blade(stats))
    bpy.data.objects.remove(source_obj, do_unlink=True)
    return body, blade, body_deleted, blade_deleted


def make_material(name, color, metallic=0.0, roughness=0.45, alpha=1.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    mat.blend_method = "BLEND" if alpha < 1.0 else "OPAQUE"
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        if "Base Color" in bsdf.inputs:
            bsdf.inputs["Base Color"].default_value = color
        if "Alpha" in bsdf.inputs:
            bsdf.inputs["Alpha"].default_value = alpha
        if "Metallic" in bsdf.inputs:
            bsdf.inputs["Metallic"].default_value = metallic
        if "Roughness" in bsdf.inputs:
            bsdf.inputs["Roughness"].default_value = roughness
    mat.diffuse_color = (color[0], color[1], color[2], alpha)
    return mat


def override_blade_material(blade):
    blade_mat = make_material("brushed-silver-blade", (0.82, 0.80, 0.73, 1.0), 0.85, 0.28)
    blade.data.materials.clear()
    blade.data.materials.append(blade_mat)


def rework_body_materials(body):
    cap = make_material("matte-black-crown", (0.025, 0.024, 0.023, 1.0), 0.20, 0.78)
    upper = make_material("dark-upper-housing", (0.12, 0.125, 0.12, 1.0), 0.38, 0.76)
    lower = make_material("muted-gunmetal-body", (0.34, 0.35, 0.34, 1.0), 0.42, 0.82)
    recess = make_material("black-recessed-panels", (0.035, 0.034, 0.032, 1.0), 0.18, 0.84)

    body.data.materials.clear()
    for material in (cap, upper, lower, recess):
        body.data.materials.append(material)

    low, high = world_bounds([body])
    width = max(high.x - low.x, high.y - low.y)
    center_x = (low.x + high.x) * 0.5
    center_y = (low.y + high.y) * 0.5
    height = high.z - low.z
    for polygon in body.data.polygons:
        center = body.matrix_world @ polygon.center
        radius = math.hypot(center.x - center_x, center.y - center_y)
        radius_norm = radius / (width * 0.5) if width > 0 else 0
        z_norm = (center.z - low.z) / height if height > 0 else 0
        if z_norm >= 0.73 and radius_norm <= 0.55:
            polygon.material_index = 0
        elif z_norm >= 0.50:
            polygon.material_index = 1
        elif radius_norm >= 0.72 or z_norm <= 0.18:
            polygon.material_index = 3
        else:
            polygon.material_index = 2
    body.data.update()


def set_origin_to_world_zero(obj):
    cursor_location = bpy.context.scene.cursor.location.copy()
    bpy.context.scene.cursor.location = (0, 0, 0)
    bpy.ops.object.select_all(action="DESELECT")
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.origin_set(type="ORIGIN_CURSOR", center="MEDIAN")
    obj.select_set(False)
    bpy.context.scene.cursor.location = cursor_location


def export_prepared_glb(path, objects):
    path.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.export_scene.gltf(
        filepath=str(path),
        export_format="GLB",
        use_selection=True,
        export_apply=True,
    )


def main():
    args = parse_args()
    source = Path(args.source).expanduser().resolve()
    out = Path(args.out).expanduser().resolve()
    manifest_path = Path(args.manifest).expanduser().resolve() if args.manifest else out.with_suffix(".manifest.json")

    clear_scene()
    source_obj = import_source(source)
    low, high = world_bounds([source_obj])
    body, blade, body_deleted, blade_deleted = split_mesh_by_blade(source_obj, low, high)
    normalize_mesh_object(body, low, high, args.target_width)
    normalize_mesh_object(blade, low, high, args.target_width)
    set_origin_to_world_zero(body)
    set_origin_to_world_zero(blade)
    if args.legacy_material_overrides:
        rework_body_materials(body)
        override_blade_material(blade)
    set_origin_to_world_zero(blade)

    export_prepared_glb(out, [body, blade])
    manifest = {
        "asset": ASSET_NAME,
        "source": str(source),
        "prepared_glb": str(out),
        "body_object": BODY_OBJECT_NAME,
        "blade_object": BLADE_OBJECT_NAME,
        "target_width": args.target_width,
        "blade_split": {
            "body_deleted_faces": body_deleted,
            "blade_deleted_faces": blade_deleted,
            "component_heuristic": "connected overlay islands: large high outer ring faces plus small high-radius tooth islands; static body uses a broader upper-blade cut to prevent ghosting under the runtime blade layer",
        },
        "material_adjustments": (
            {
                "mode": "legacy-overrides",
                "body": "rough dark steel, matte black cap, and black recess materials to reduce Meshy reflectiveness",
                "blade": "brushed silver blade; rotation is handled by the 64-frame preset render",
            }
            if args.legacy_material_overrides
            else {
                "mode": "preserve-source",
                "body": "source materials and textures preserved after body/blade mesh split",
                "blade": "source materials and textures preserved; rotation is handled by the 64-frame preset render",
            }
        ),
        "rendering": "Use factorioRenderingPreset_v4.blend via render_factorio_preset.py for camera, lighting, shadows, and pass compositing.",
    }
    manifest_path.parent.mkdir(parents=True, exist_ok=True)
    manifest_path.write_text(json.dumps(manifest, indent=2), encoding="utf-8")


if __name__ == "__main__":
    main()
