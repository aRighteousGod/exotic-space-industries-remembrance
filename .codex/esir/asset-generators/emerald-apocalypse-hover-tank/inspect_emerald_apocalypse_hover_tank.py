import argparse
import json
import math
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Vector


def parse_args():
    parser = argparse.ArgumentParser(description="Inspect Emerald Apocalypse Hover Tank GLB mesh components.")
    parser.add_argument("--source", required=True)
    parser.add_argument("--out", required=True)
    parser.add_argument("--limit", type=int, default=80)
    return parser.parse_args(sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else [])


def clear_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete()


def bounds(points):
    low = Vector((float("inf"), float("inf"), float("inf")))
    high = Vector((float("-inf"), float("-inf"), float("-inf")))
    for point in points:
        low.x = min(low.x, point.x)
        low.y = min(low.y, point.y)
        low.z = min(low.z, point.z)
        high.x = max(high.x, point.x)
        high.y = max(high.y, point.y)
        high.z = max(high.z, point.z)
    return low, high


def vjson(vector):
    return [round(float(vector.x), 6), round(float(vector.y), 6), round(float(vector.z), 6)]


def main():
    args = parse_args()
    clear_scene()
    bpy.ops.import_scene.gltf(filepath=str(Path(args.source).resolve()))
    objects = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    report = {"source": str(Path(args.source).resolve()), "objects": [], "components": []}
    for obj in objects:
        bm = bmesh.new()
        bm.from_mesh(obj.data)
        bm.faces.ensure_lookup_table()
        seen = set()
        object_components = []
        for face in bm.faces:
            if face in seen:
                continue
            stack = [face]
            seen.add(face)
            faces = []
            while stack:
                current = stack.pop()
                faces.append(current)
                for edge in current.edges:
                    for linked in edge.link_faces:
                        if linked not in seen:
                            seen.add(linked)
                            stack.append(linked)
            points = [obj.matrix_world @ vert.co for component_face in faces for vert in component_face.verts]
            low, high = bounds(points)
            dims = [high.x - low.x, high.y - low.y, high.z - low.z]
            sorted_dims = sorted(dims, reverse=True)
            ratio = sorted_dims[0] / max(0.0001, (sorted_dims[1] + sorted_dims[2]) * 0.5)
            center = Vector(((low.x + high.x) * 0.5, (low.y + high.y) * 0.5, (low.z + high.z) * 0.5))
            area = sum(face.calc_area() for face in faces)
            object_components.append(
                {
                    "object": obj.name,
                    "face_count": len(faces),
                    "area": round(float(area), 8),
                    "bounds_low": vjson(low),
                    "bounds_high": vjson(high),
                    "center": vjson(center),
                    "dims": [round(float(value), 6) for value in dims],
                    "length_ratio": round(float(ratio), 6),
                    "material_indices": sorted({face.material_index for face in faces}),
                }
            )
        bm.free()
        object_components.sort(key=lambda c: (c["length_ratio"], c["face_count"]), reverse=True)
        report["objects"].append(
            {
                "name": obj.name,
                "mesh": obj.data.name,
                "materials": [slot.material.name if slot.material else None for slot in obj.material_slots],
                "component_count": len(object_components),
            }
        )
        report["components"].extend(object_components[: args.limit])
    report["components"].sort(key=lambda c: (c["length_ratio"], c["face_count"]), reverse=True)
    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(report, indent=2), encoding="utf-8")


if __name__ == "__main__":
    main()

