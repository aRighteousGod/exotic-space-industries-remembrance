import argparse
import json
import math
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Vector


BODY_OBJECT_NAME = "emerald-apocalypse-hover-tank-crystal-glow"
GLOW_MATERIAL_NAME = "ESIR emerald apocalypse crystal glow overlay"


def parse_args():
    parser = argparse.ArgumentParser(description="Isolate Emerald Apocalypse crystal geometry for a glow overlay GLB.")
    parser.add_argument("--source", required=True, help="Approved cleaned tank GLB.")
    parser.add_argument("--out", required=True, help="Crystal-only overlay GLB path.")
    parser.add_argument("--manifest", required=True, help="Selection manifest JSON path.")
    parser.add_argument("--min-component-score", type=float, default=0.28)
    parser.add_argument("--min-component-p90", type=float, default=0.38)
    parser.add_argument("--min-bright-fraction", type=float, default=0.18)
    parser.add_argument("--min-face-score", type=float, default=0.16)
    parser.add_argument("--neighbor-face-score", type=float, default=0.105)
    parser.add_argument("--min-component-area", type=float, default=0.00022)
    parser.add_argument("--min-component-faces", type=int, default=4)
    parser.add_argument("--min-component-thickness", type=float, default=0.006)
    parser.add_argument("--min-normal-spread", type=float, default=0.045)
    parser.add_argument("--crystal-only-geometry", dest="crystal_only_geometry", action="store_true", default=False, help="Apply stricter 3D compact/faceted geometry gates to avoid panels, rings, and hull glow strips.")
    parser.add_argument("--min-center-z", type=float, default=0.0, help="Reject selected islands below this source-space Z center when crystal-only geometry is enabled.")
    parser.add_argument("--max-major-minor-ratio", type=float, default=8.5, help="Reject very long/flat strips when crystal-only geometry is enabled.")
    parser.add_argument("--min-mid-major-ratio", type=float, default=0.12, help="Reject very flat panels when crystal-only geometry is enabled.")
    parser.add_argument("--max-sample-faces", type=int, default=512)
    parser.add_argument("--emission-strength", type=float, default=3.5)
    parser.add_argument("--base-alpha", type=float, default=1.0)
    parser.add_argument("--keep-whole-components", dest="keep_whole_components", action="store_true", default=True, help="Keep every face of a selected crystal/material island to avoid chipped overlay chunks.")
    parser.add_argument("--no-keep-whole-components", dest="keep_whole_components", action="store_false", help="Keep only bright scored faces plus immediate neighbors.")
    parser.add_argument("--trim-boxy-components", dest="trim_boxy_components", action="store_true", default=False, help="For selected broad boxy islands, keep only high-emerald faces instead of whole mechanical housings.")
    parser.add_argument("--boxy-major-threshold", type=float, default=0.33)
    parser.add_argument("--boxy-minor-threshold", type=float, default=0.11)
    parser.add_argument("--boxy-keep-face-score", type=float, default=0.34)
    parser.add_argument("--boxy-keep-neighbor-score", type=float, default=0.20)
    parser.add_argument("--boxy-max-p90-score", type=float, default=0.98)
    return parser.parse_args(sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else [])


def clear_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete()


def vjson(vector):
    return [round(float(vector.x), 6), round(float(vector.y), 6), round(float(vector.z), 6)]


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


def percentile(values, q):
    if not values:
        return 0.0
    index = min(len(values) - 1, max(0, int(round((len(values) - 1) * q))))
    return sorted(values)[index]


def material_base_image(material):
    if not material or not material.use_nodes or not material.node_tree:
        return None
    nodes = material.node_tree.nodes
    principled = nodes.get("Principled BSDF")
    if principled and principled.inputs.get("Base Color"):
        stack = [link.from_node for link in principled.inputs["Base Color"].links]
        seen = set()
        while stack:
            node = stack.pop()
            if node.name in seen:
                continue
            seen.add(node.name)
            if node.bl_idname == "ShaderNodeTexImage" and node.image:
                return node.image
            for input_socket in node.inputs:
                stack.extend(link.from_node for link in input_socket.links)
    for node in nodes:
        if node.bl_idname == "ShaderNodeTexImage" and node.image:
            return node.image
    return None


def image_pixels(image, cache):
    key = image.name
    if key not in cache:
        # Blender's pixel array is row-major, bottom-left origin, RGBA float channels.
        cache[key] = {
            "size": tuple(int(v) for v in image.size),
            "pixels": list(image.pixels[:]),
        }
    return cache[key]


def sample_image(image, uv, cache):
    data = image_pixels(image, cache)
    width, height = data["size"]
    if width <= 0 or height <= 0:
        return (0.0, 0.0, 0.0, 1.0)
    u = uv.x % 1.0
    v = uv.y % 1.0
    x = min(width - 1, max(0, int(round(u * (width - 1)))))
    y = min(height - 1, max(0, int(round(v * (height - 1)))))
    index = (y * width + x) * 4
    pixels = data["pixels"]
    return (
        float(pixels[index]),
        float(pixels[index + 1]),
        float(pixels[index + 2]),
        float(pixels[index + 3]),
    )


def emerald_score(color):
    r, g, b, a = color
    if a <= 0.05:
        return 0.0
    brightness = (r + g + b) / 3.0
    cool_green = max(0.0, g - r * 1.12)
    cyan_core = max(0.0, min(g, b * 1.22) - r * 0.72)
    metal_penalty = max(0.0, r - b * 0.55) * 0.45
    darkness_penalty = max(0.0, 0.20 - brightness) * 1.2
    return max(0.0, cool_green * 0.55 + cyan_core * 0.55 + brightness * 0.22 - metal_penalty - darkness_penalty)


def face_score(obj, face, uv_layer, material_images, pixel_cache):
    material_image = material_images.get(face.material_index)
    if not material_image or not uv_layer:
        return 0.0
    samples = []
    u = sum((loop[uv_layer].uv for loop in face.loops), Vector((0.0, 0.0))) / max(1, len(face.loops))
    samples.append(sample_image(material_image, u, pixel_cache))
    for loop in face.loops:
        samples.append(sample_image(material_image, loop[uv_layer].uv, pixel_cache))
    return max(emerald_score(color) for color in samples)


def component_faces(bm):
    seen = set()
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
        yield faces


def sample_component_faces(faces, max_sample_faces):
    if len(faces) <= max_sample_faces:
        return faces
    stride = max(1, len(faces) // max_sample_faces)
    sampled = faces[::stride]
    return sampled[:max_sample_faces]


def component_metrics(obj, faces, face_scores, max_sample_faces):
    sample_faces = sample_component_faces(faces, max_sample_faces)
    scores = [face_scores[face.index] for face in sample_faces]
    points = [obj.matrix_world @ vert.co for face in faces for vert in face.verts]
    low, high = bounds(points)
    dims = [high.x - low.x, high.y - low.y, high.z - low.z]
    sorted_dims = sorted(dims, reverse=True)
    center = Vector(((low.x + high.x) * 0.5, (low.y + high.y) * 0.5, (low.z + high.z) * 0.5))
    area = sum(face.calc_area() for face in faces)
    normal_sum = Vector((0.0, 0.0, 0.0))
    for face in sample_faces:
        normal_sum += face.normal.normalized()
    average_normal_length = normal_sum.length / max(1, len(sample_faces))
    normal_spread = 1.0 - min(1.0, max(0.0, average_normal_length))
    bright_fraction = sum(1 for score in scores if score >= 0.28) / max(1, len(scores))
    return {
        "face_count": len(faces),
        "area": float(area),
        "bounds_low": low,
        "bounds_high": high,
        "dims": dims,
        "major_dim": sorted_dims[0] if sorted_dims else 0.0,
        "mid_dim": sorted_dims[1] if len(sorted_dims) >= 2 else 0.0,
        "minor_dim": sorted_dims[2] if len(sorted_dims) >= 3 else 0.0,
        "center": center,
        "mean_score": sum(scores) / max(1, len(scores)),
        "p75_score": percentile(scores, 0.75),
        "p90_score": percentile(scores, 0.90),
        "max_score": max(scores) if scores else 0.0,
        "bright_fraction": bright_fraction,
        "normal_spread": normal_spread,
    }


def is_boxy_component(metrics, args):
    return (
        args.trim_boxy_components
        and metrics["major_dim"] >= args.boxy_major_threshold
        and metrics["minor_dim"] >= args.boxy_minor_threshold
        and metrics["p90_score"] <= args.boxy_max_p90_score
    )


def should_keep_component(metrics, args):
    color_pass = (
        metrics["mean_score"] >= args.min_component_score
        or metrics["p90_score"] >= args.min_component_p90
        or metrics["bright_fraction"] >= args.min_bright_fraction
    )
    geometry_pass = (
        metrics["face_count"] >= args.min_component_faces
        and metrics["area"] >= args.min_component_area
        and (
            metrics["minor_dim"] >= args.min_component_thickness
            or metrics["normal_spread"] >= args.min_normal_spread
        )
    )
    tiny_facet_pass = (
        metrics["p90_score"] >= args.min_component_p90 + 0.10
        and metrics["area"] >= args.min_component_area * 0.30
        and metrics["face_count"] >= 2
    )
    if args.crystal_only_geometry:
        major = max(metrics["major_dim"], 0.0001)
        minor = max(metrics["minor_dim"], 0.0001)
        crystal_shape_pass = (
            metrics["center"].z >= args.min_center_z
            and metrics["normal_spread"] >= args.min_normal_spread
            and (major / minor) <= args.max_major_minor_ratio
            and (metrics["mid_dim"] / major) >= args.min_mid_major_ratio
        )
        return color_pass and crystal_shape_pass and (geometry_pass or tiny_facet_pass)
    return color_pass and (geometry_pass or tiny_facet_pass)


def grow_face_selection(keep_faces, faces, face_scores, neighbor_score):
    keep = set(keep_faces)
    face_set = set(faces)
    for face in list(keep_faces):
        for edge in face.edges:
            for linked in edge.link_faces:
                if linked in face_set and linked not in keep and face_scores[linked.index] >= neighbor_score:
                    keep.add(linked)
    return keep


def make_glow_material(emission_strength, alpha):
    material = bpy.data.materials.new(GLOW_MATERIAL_NAME)
    material.use_nodes = True
    material.diffuse_color = (0.04, 1.0, 0.62, alpha)
    material.blend_method = "BLEND"
    material.use_screen_refraction = False
    node = material.node_tree.nodes.get("Principled BSDF")
    if node:
        node.inputs["Base Color"].default_value = (0.04, 1.0, 0.62, alpha)
        node.inputs["Alpha"].default_value = alpha
        node.inputs["Roughness"].default_value = 0.23
        if node.inputs.get("Emission Color"):
            node.inputs["Emission Color"].default_value = (0.04, 1.0, 0.62, 1.0)
        if node.inputs.get("Emission Strength"):
            node.inputs["Emission Strength"].default_value = emission_strength
    return material


def isolate_object(obj, args):
    mesh = obj.data
    uv_layer_name = mesh.uv_layers.active.name if mesh.uv_layers.active else None
    material_images = {
        index: material_base_image(slot.material)
        for index, slot in enumerate(obj.material_slots)
    }

    bm = bmesh.new()
    bm.from_mesh(mesh)
    bm.faces.ensure_lookup_table()
    bm.verts.ensure_lookup_table()
    bm.edges.ensure_lookup_table()
    uv_layer = bm.loops.layers.uv.get(uv_layer_name) if uv_layer_name else None
    pixel_cache = {}
    face_scores = {}
    for face in bm.faces:
        face_scores[face.index] = face_score(obj, face, uv_layer, material_images, pixel_cache)

    kept_faces = set()
    component_reports = []
    for component_index, faces in enumerate(component_faces(bm)):
        metrics = component_metrics(obj, faces, face_scores, args.max_sample_faces)
        component_keep = should_keep_component(metrics, args)
        high_faces = {face for face in faces if face_scores[face.index] >= args.min_face_score}
        if component_keep:
            if is_boxy_component(metrics, args):
                boxy_high_faces = {face for face in faces if face_scores[face.index] >= args.boxy_keep_face_score}
                kept_faces.update(grow_face_selection(boxy_high_faces, faces, face_scores, args.boxy_keep_neighbor_score))
            elif args.keep_whole_components:
                kept_faces.update(faces)
            elif high_faces:
                kept_faces.update(grow_face_selection(high_faces, faces, face_scores, args.neighbor_face_score))
        if component_keep or metrics["p90_score"] >= args.min_component_p90:
            component_reports.append(
                {
                    "component_index": component_index,
                    "kept": bool(component_keep),
                    "boxy_trimmed": bool(component_keep and is_boxy_component(metrics, args)),
                    "face_count": metrics["face_count"],
                    "kept_face_count": sum(1 for face in faces if face in kept_faces),
                    "area": round(metrics["area"], 8),
                    "bounds_low": vjson(metrics["bounds_low"]),
                    "bounds_high": vjson(metrics["bounds_high"]),
                    "center": vjson(metrics["center"]),
                    "dims": [round(float(value), 6) for value in metrics["dims"]],
                    "major_dim": round(float(metrics["major_dim"]), 6),
                    "mid_dim": round(float(metrics["mid_dim"]), 6),
                    "minor_dim": round(float(metrics["minor_dim"]), 6),
                    "mean_score": round(float(metrics["mean_score"]), 6),
                    "p75_score": round(float(metrics["p75_score"]), 6),
                    "p90_score": round(float(metrics["p90_score"]), 6),
                    "max_score": round(float(metrics["max_score"]), 6),
                    "bright_fraction": round(float(metrics["bright_fraction"]), 6),
                    "normal_spread": round(float(metrics["normal_spread"]), 6),
                }
            )

    deleted_faces = [face for face in bm.faces if face not in kept_faces]
    bmesh.ops.delete(bm, geom=deleted_faces, context="FACES")
    bm.to_mesh(mesh)
    bm.free()
    mesh.update()

    obj.name = BODY_OBJECT_NAME
    obj.data.name = BODY_OBJECT_NAME
    obj.data.materials.clear()
    obj.data.materials.append(make_glow_material(args.emission_strength, args.base_alpha))
    for poly in obj.data.polygons:
        poly.material_index = 0

    component_reports.sort(key=lambda row: (not row["kept"], -row["p90_score"], -row["face_count"]))
    return {
        "uv_layer": uv_layer_name,
        "material_images": {
            str(index): image.name if image else None for index, image in material_images.items()
        },
        "face_count_after": len(obj.data.polygons),
        "face_count_deleted": len(deleted_faces),
        "component_report": component_reports[:240],
    }


def export_glb(path):
    path.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    for obj in bpy.context.scene.objects:
        if obj.type == "MESH":
            obj.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(path), export_format="GLB", use_selection=True)


def main():
    args = parse_args()
    clear_scene()
    bpy.ops.import_scene.gltf(filepath=str(Path(args.source).resolve()))
    mesh_objects = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    if not mesh_objects:
        raise RuntimeError("No mesh objects imported.")
    if len(mesh_objects) > 1:
        bpy.ops.object.select_all(action="DESELECT")
        for obj in mesh_objects:
            obj.select_set(True)
        bpy.context.view_layer.objects.active = mesh_objects[0]
        bpy.ops.object.join()
    obj = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"][0]
    report = isolate_object(obj, args)
    out = Path(args.out)
    export_glb(out)
    manifest = {
        "kind": "emerald_apocalypse_crystal_overlay_isolation",
        "source": str(Path(args.source).resolve()),
        "out": str(out.resolve()),
        "selection": {
            "min_component_score": args.min_component_score,
            "min_component_p90": args.min_component_p90,
            "min_bright_fraction": args.min_bright_fraction,
            "min_face_score": args.min_face_score,
            "neighbor_face_score": args.neighbor_face_score,
            "min_component_area": args.min_component_area,
            "min_component_faces": args.min_component_faces,
            "min_component_thickness": args.min_component_thickness,
            "min_normal_spread": args.min_normal_spread,
            "crystal_only_geometry": args.crystal_only_geometry,
            "min_center_z": args.min_center_z,
            "max_major_minor_ratio": args.max_major_minor_ratio,
            "min_mid_major_ratio": args.min_mid_major_ratio,
            "max_sample_faces": args.max_sample_faces,
            "keep_whole_components": args.keep_whole_components,
            "trim_boxy_components": args.trim_boxy_components,
            "boxy_major_threshold": args.boxy_major_threshold,
            "boxy_minor_threshold": args.boxy_minor_threshold,
            "boxy_keep_face_score": args.boxy_keep_face_score,
            "boxy_keep_neighbor_score": args.boxy_keep_neighbor_score,
            "boxy_max_p90_score": args.boxy_max_p90_score,
        },
        "rendering_note": "Render this GLB through the Factorio preset as an object/additive overlay. It intentionally excludes the removed forward barrel cylinder by using the approved v7 cleaned source.",
        **report,
    }
    manifest_path = Path(args.manifest)
    manifest_path.parent.mkdir(parents=True, exist_ok=True)
    manifest_path.write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    print(f"crystal_overlay_glb={out.resolve()}")
    print(f"manifest={manifest_path.resolve()}")
    print(f"faces_after={report['face_count_after']}")


if __name__ == "__main__":
    main()
