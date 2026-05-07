import argparse
import math
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Vector


def parse_args():
    parser = argparse.ArgumentParser(description="List connected component stats for the sawblade turret GLB.")
    parser.add_argument("--source", required=True, help="Source GLB to inspect.")
    parser.add_argument("--min-faces", type=int, default=40)
    parser.add_argument("--min-r-avg", type=float, default=0.0)
    parser.add_argument("--min-z-avg", type=float, default=0.0)
    parser.add_argument("--max-z-avg", type=float, default=1.0)
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


def component_stats(obj, low, high, min_faces):
    width = max(high.x - low.x, high.y - low.y)
    height = high.z - low.z
    center_x = (low.x + high.x) * 0.5
    center_y = (low.y + high.y) * 0.5
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bm.faces.ensure_lookup_table()

    seen = set()
    stats = []
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

        if len(component_faces) < min_faces:
            continue

        radii = []
        zs = []
        normals_z = []
        materials = {}
        for component_face in component_faces:
            world_center = obj.matrix_world @ component_face.calc_center_median()
            radius = math.hypot(world_center.x - center_x, world_center.y - center_y)
            radii.append(radius / (width * 0.5) if width > 0 else 0)
            zs.append((world_center.z - low.z) / height if height > 0 else 0)
            normals_z.append((obj.matrix_world.to_3x3() @ component_face.normal).z)
            materials[component_face.material_index] = materials.get(component_face.material_index, 0) + 1

        material_names = []
        for material_index, count in sorted(materials.items(), key=lambda item: -item[1])[:3]:
            material = obj.data.materials[material_index] if material_index < len(obj.data.materials) else None
            material_names.append(f"{material_index}:{material.name if material else '<missing>'}:{count}")

        stats.append(
            {
                "faces": len(component_faces),
                "r_min": min(radii),
                "r_avg": sum(radii) / len(radii),
                "r_max": max(radii),
                "z_min": min(zs),
                "z_avg": sum(zs) / len(zs),
                "z_max": max(zs),
                "nz_avg": sum(normals_z) / len(normals_z),
                "materials": ", ".join(material_names),
            }
        )

    bm.free()
    return stats


def main():
    args = parse_args()
    clear_scene()
    source = Path(args.source).expanduser().resolve()
    obj = import_source(source)
    low, high = world_bounds([obj])
    stats = [
        item
        for item in component_stats(obj, low, high, args.min_faces)
        if item["r_avg"] >= args.min_r_avg
        and item["z_avg"] >= args.min_z_avg
        and item["z_avg"] <= args.max_z_avg
    ]
    stats.sort(key=lambda item: (-item["z_avg"], -item["r_avg"]))

    print("faces rmin ravg rmax zmin zavg zmax nzavg materials")
    for item in stats:
        print(
            f"{item['faces']:5d} "
            f"{item['r_min']:.3f} {item['r_avg']:.3f} {item['r_max']:.3f} "
            f"{item['z_min']:.3f} {item['z_avg']:.3f} {item['z_max']:.3f} "
            f"{item['nz_avg']:.3f} {item['materials']}"
        )


if __name__ == "__main__":
    main()
