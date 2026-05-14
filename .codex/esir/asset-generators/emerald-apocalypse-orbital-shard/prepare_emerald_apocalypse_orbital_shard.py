import argparse
import json
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Vector


ASSET_NAME = "emerald-apocalypse-orbital-shard"
PREPARED_OBJECT_NAME = "emerald-apocalypse-orbital-shard-prepared"
CRYSTAL_FACES_OBJECT_NAME = "emerald-apocalypse-orbital-shard-crystal-faces"
SOURCE_DEFAULT = r"C:\Users\Theorun\Documents\Development\Meshy_AI_Emerald_Crystal_Core_0510181142_texture.glb"
PREPARED_DEFAULT = "output/meshy/emerald-apocalypse-orbital-shard/prepared/emerald-apocalypse-orbital-shard-prepared.glb"
CRYSTAL_FACES_DEFAULT = "output/meshy/emerald-apocalypse-orbital-shard/prepared/emerald-apocalypse-orbital-shard-crystal-faces.glb"


def parse_args():
    parser = argparse.ArgumentParser(
        description="Prepare the Emerald Apocalypse orbital shard GLB and isolate emerald/cyan crystal faces."
    )
    parser.add_argument("--source", default=SOURCE_DEFAULT, help="Corrected source GLB. Do not use Nexus Prism sources.")
    parser.add_argument("--out", default=PREPARED_DEFAULT, help="Prepared full-shard GLB path.")
    parser.add_argument("--crystal-out", default=CRYSTAL_FACES_DEFAULT, help="Crystal-face-only GLB path.")
    parser.add_argument("--manifest", help="Prepared model JSON manifest path.")
    parser.add_argument("--crystal-manifest", help="Crystal-face isolation JSON manifest path.")
    parser.add_argument("--target-size", type=float, default=1.35, help="Max normalized model dimension.")
    parser.add_argument("--min-face-score", type=float, default=0.34, help="Minimum emerald/cyan score for directly kept faces.")
    parser.add_argument("--neighbor-face-score", type=float, default=0.20, help="Minimum score for one-ring neighboring face growth.")
    parser.add_argument("--min-component-score", type=float, default=0.28, help="Minimum component mean score.")
    parser.add_argument("--min-component-p90", type=float, default=0.38, help="Minimum component p90 score.")
    parser.add_argument("--min-bright-fraction", type=float, default=0.18, help="Minimum fraction of strong emerald/cyan faces.")
    parser.add_argument("--strong-face-score", type=float, default=0.34, help="Score counted as a strong emerald/cyan face.")
    parser.add_argument("--min-component-area", type=float, default=0.00012, help="Minimum normalized component area.")
    parser.add_argument("--min-component-faces", type=int, default=2, help="Minimum connected faces for component reporting.")
    parser.add_argument("--min-normal-spread", type=float, default=0.04, help="Minimum normal spread for broad crystal-face islands.")
    parser.add_argument("--max-sample-faces", type=int, default=768, help="Maximum sampled faces per component for scoring metrics.")
    parser.add_argument(
        "--keep-whole-crystal-components",
        action="store_true",
        help="Keep every face of selected crystal-colored components instead of scored faces plus neighbors.",
    )
    return parser.parse_args(sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else [])


def clear_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete()


def vjson(vector):
    return [round(float(vector.x), 6), round(float(vector.y), 6), round(float(vector.z), 6)]


def bounds_for_points(points):
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


def world_bounds(objects):
    points = []
    for obj in objects:
        if obj.type == "MESH" and obj.data and obj.data.vertices:
            points.extend(obj.matrix_world @ vertex.co for vertex in obj.data.vertices)
        else:
            points.extend(obj.matrix_world @ Vector(corner) for corner in obj.bound_box)
    return bounds_for_points(points)


def import_source(path):
    bpy.ops.import_scene.gltf(filepath=str(path))
    meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    if not meshes:
        raise RuntimeError(f"No mesh objects imported from {path}")
    imported_count = len(meshes)
    if len(meshes) > 1:
        bpy.ops.object.select_all(action="DESELECT")
        for obj in meshes:
            obj.select_set(True)
        bpy.context.view_layer.objects.active = meshes[0]
        bpy.ops.object.join()
        meshes = [bpy.context.view_layer.objects.active]
    obj = meshes[0]
    obj.name = PREPARED_OBJECT_NAME
    obj.data.name = PREPARED_OBJECT_NAME
    return obj, imported_count


def normalize_center_origin(obj, target_size):
    low, high = world_bounds([obj])
    center = (low + high) * 0.5
    dims = high - low
    max_dim = max(dims.x, dims.y, dims.z)
    scale = target_size / max_dim if max_dim > 0 else 1.0
    world = obj.matrix_world.copy()
    for vertex in obj.data.vertices:
        vertex.co = (world @ vertex.co - center) * scale
    obj.matrix_world.identity()
    obj.data.update()
    normalized_low, normalized_high = world_bounds([obj])
    return {
        "source_bounds_low": low,
        "source_bounds_high": high,
        "source_center_world": center,
        "source_dimensions": dims,
        "scale": scale,
        "normalized_bounds_low": normalized_low,
        "normalized_bounds_high": normalized_high,
    }


def percentile(values, q):
    if not values:
        return 0.0
    ordered = sorted(values)
    index = min(len(ordered) - 1, max(0, int(round((len(ordered) - 1) * q))))
    return ordered[index]


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


def material_surface_color(material):
    color = list(material.diffuse_color[:4]) if material else [0.0, 0.0, 0.0, 1.0]
    emission = [0.0, 0.0, 0.0, 1.0]
    emission_strength = 0.0
    if material and material.use_nodes and material.node_tree:
        for node in material.node_tree.nodes:
            if node.type == "BSDF_PRINCIPLED":
                if node.inputs.get("Base Color"):
                    color = list(node.inputs["Base Color"].default_value)
                if node.inputs.get("Emission Color"):
                    emission = list(node.inputs["Emission Color"].default_value)
                if node.inputs.get("Emission Strength"):
                    emission_strength = float(node.inputs["Emission Strength"].default_value)
            elif node.type == "EMISSION":
                if node.inputs.get("Color"):
                    emission = list(node.inputs["Color"].default_value)
                if node.inputs.get("Strength"):
                    emission_strength = float(node.inputs["Strength"].default_value)
    if emission_strength > 0:
        return [
            max(float(color[0]), float(emission[0]) * emission_strength),
            max(float(color[1]), float(emission[1]) * emission_strength),
            max(float(color[2]), float(emission[2]) * emission_strength),
            float(color[3]),
        ]
    return [float(value) for value in color]


def image_pixels(image, cache):
    key = image.name
    if key not in cache:
        cache[key] = {
            "size": tuple(int(value) for value in image.size),
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


def emerald_cyan_score(color):
    r, g, b, a = color
    if a <= 0.05:
        return 0.0
    brightness = (r + g + b) / 3.0
    emerald = max(0.0, g - r * 1.08) * 0.58 + max(0.0, g - b * 0.38) * 0.12
    cyan = max(0.0, min(g, b * 1.28) - r * 0.68) * 0.62
    black_plate_penalty = max(0.0, r - min(g, b) * 0.52) * 0.42
    darkness_penalty = max(0.0, 0.18 - brightness) * 1.15
    return max(0.0, emerald + cyan + brightness * 0.18 - black_plate_penalty - darkness_penalty)


def face_score(obj, face, uv_layer, material_images, material_scores, pixel_cache):
    material_score = material_scores.get(face.material_index, 0.0)
    material_image = material_images.get(face.material_index)
    if not material_image or not uv_layer:
        return material_score
    samples = []
    center_uv = sum((loop[uv_layer].uv for loop in face.loops), Vector((0.0, 0.0))) / max(1, len(face.loops))
    samples.append(sample_image(material_image, center_uv, pixel_cache))
    for loop in face.loops:
        samples.append(sample_image(material_image, loop[uv_layer].uv, pixel_cache))
    return max(emerald_cyan_score(color) for color in samples)


def connected_components(bm):
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


def sample_faces(faces, max_sample_faces):
    if len(faces) <= max_sample_faces:
        return faces
    stride = max(1, len(faces) // max_sample_faces)
    return faces[::stride][:max_sample_faces]


def component_metrics(obj, faces, face_scores, args):
    sampled = sample_faces(faces, args.max_sample_faces)
    scores = [face_scores[face.index] for face in sampled]
    points = [obj.matrix_world @ vertex.co for face in faces for vertex in face.verts]
    low, high = bounds_for_points(points)
    dims = high - low
    area = sum(face.calc_area() for face in faces)
    normal_sum = Vector((0.0, 0.0, 0.0))
    for face in sampled:
        normal_sum += face.normal.normalized()
    normal_spread = 1.0 - min(1.0, max(0.0, normal_sum.length / max(1, len(sampled))))
    strong_fraction = sum(1 for score in scores if score >= args.strong_face_score) / max(1, len(scores))
    return {
        "face_count": len(faces),
        "area": float(area),
        "bounds_low": low,
        "bounds_high": high,
        "dimensions": dims,
        "mean_score": sum(scores) / max(1, len(scores)),
        "p75_score": percentile(scores, 0.75),
        "p90_score": percentile(scores, 0.90),
        "max_score": max(scores) if scores else 0.0,
        "strong_fraction": strong_fraction,
        "normal_spread": normal_spread,
    }


def should_keep_component(metrics, args):
    color_pass = (
        metrics["mean_score"] >= args.min_component_score
        or metrics["p90_score"] >= args.min_component_p90
        or metrics["strong_fraction"] >= args.min_bright_fraction
    )
    geometry_pass = (
        metrics["face_count"] >= args.min_component_faces
        and metrics["area"] >= args.min_component_area
        and (metrics["normal_spread"] >= args.min_normal_spread or metrics["max_score"] >= args.min_component_p90)
    )
    return color_pass and geometry_pass


def grow_face_selection(seed_faces, component_faces, face_scores, neighbor_score):
    keep = set(seed_faces)
    component_set = set(component_faces)
    for face in list(seed_faces):
        for edge in face.edges:
            for linked in edge.link_faces:
                if linked in component_set and linked not in keep and face_scores[linked.index] >= neighbor_score:
                    keep.add(linked)
    return keep


def isolate_crystal_faces(source_obj, args):
    obj = source_obj.copy()
    obj.data = source_obj.data.copy()
    obj.name = CRYSTAL_FACES_OBJECT_NAME
    obj.data.name = CRYSTAL_FACES_OBJECT_NAME
    bpy.context.collection.objects.link(obj)

    mesh = obj.data
    uv_layer_name = mesh.uv_layers.active.name if mesh.uv_layers.active else None
    material_images = {
        index: material_base_image(slot.material)
        for index, slot in enumerate(obj.material_slots)
    }
    material_scores = {
        index: emerald_cyan_score(material_surface_color(slot.material))
        for index, slot in enumerate(obj.material_slots)
    }
    material_report = [
        {
            "slot": index,
            "material": slot.material.name if slot.material else None,
            "base_score": round(material_scores.get(index, 0.0), 6),
            "image": material_images[index].name if material_images.get(index) else None,
        }
        for index, slot in enumerate(obj.material_slots)
    ]

    bm = bmesh.new()
    bm.from_mesh(mesh)
    bm.faces.ensure_lookup_table()
    bm.edges.ensure_lookup_table()
    bm.verts.ensure_lookup_table()
    uv_layer = bm.loops.layers.uv.get(uv_layer_name) if uv_layer_name else None
    pixel_cache = {}
    face_scores = {
        face.index: face_score(obj, face, uv_layer, material_images, material_scores, pixel_cache)
        for face in bm.faces
    }

    kept_faces = set()
    component_reports = []
    for component_index, faces in enumerate(connected_components(bm)):
        metrics = component_metrics(obj, faces, face_scores, args)
        component_keep = should_keep_component(metrics, args)
        high_faces = {face for face in faces if face_scores[face.index] >= args.min_face_score}
        if component_keep and high_faces:
            if args.keep_whole_crystal_components:
                kept_faces.update(faces)
            else:
                kept_faces.update(grow_face_selection(high_faces, faces, face_scores, args.neighbor_face_score))
        if component_keep or metrics["p90_score"] >= args.min_component_p90 or high_faces:
            component_reports.append(
                {
                    "component_index": component_index,
                    "kept": bool(component_keep or high_faces),
                    "face_count": metrics["face_count"],
                    "kept_face_count": sum(1 for face in faces if face in kept_faces),
                    "area": round(metrics["area"], 8),
                    "bounds_low": vjson(metrics["bounds_low"]),
                    "bounds_high": vjson(metrics["bounds_high"]),
                    "dimensions": [
                        round(float(metrics["dimensions"].x), 6),
                        round(float(metrics["dimensions"].y), 6),
                        round(float(metrics["dimensions"].z), 6),
                    ],
                    "mean_score": round(float(metrics["mean_score"]), 6),
                    "p75_score": round(float(metrics["p75_score"]), 6),
                    "p90_score": round(float(metrics["p90_score"]), 6),
                    "max_score": round(float(metrics["max_score"]), 6),
                    "strong_fraction": round(float(metrics["strong_fraction"]), 6),
                    "normal_spread": round(float(metrics["normal_spread"]), 6),
                }
            )

    if not kept_faces:
        bm.free()
        raise RuntimeError("Crystal-face isolation selected no emerald/cyan faces. Lower thresholds or inspect source materials.")

    deleted_faces = [face for face in bm.faces if face not in kept_faces]
    bmesh.ops.delete(bm, geom=deleted_faces, context="FACES")
    bm.to_mesh(mesh)
    bm.free()
    mesh.update()

    component_reports.sort(key=lambda row: (not row["kept"], -row["p90_score"], -row["kept_face_count"]))
    return obj, {
        "uv_layer": uv_layer_name,
        "material_report": material_report,
        "face_count_before": len(source_obj.data.polygons),
        "face_count_after": len(obj.data.polygons),
        "face_count_deleted": len(deleted_faces),
        "component_report": component_reports[:240],
    }


def export_selection(path, objects):
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


def write_json(path, payload):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2), encoding="utf-8")


def normalization_manifest(normalization, target_size):
    return {
        "mode": "center-origin-shared",
        "target_size": target_size,
        "source_bounds_low": vjson(normalization["source_bounds_low"]),
        "source_bounds_high": vjson(normalization["source_bounds_high"]),
        "source_center_world": vjson(normalization["source_center_world"]),
        "source_dimensions": vjson(normalization["source_dimensions"]),
        "scale": round(float(normalization["scale"]), 8),
        "normalized_bounds_low": vjson(normalization["normalized_bounds_low"]),
        "normalized_bounds_high": vjson(normalization["normalized_bounds_high"]),
    }


def main():
    args = parse_args()
    source = Path(args.source).expanduser().resolve()
    out = Path(args.out).expanduser().resolve()
    crystal_out = Path(args.crystal_out).expanduser().resolve()
    manifest_path = Path(args.manifest).expanduser().resolve() if args.manifest else out.with_suffix(".manifest.json")
    crystal_manifest_path = (
        Path(args.crystal_manifest).expanduser().resolve()
        if args.crystal_manifest
        else crystal_out.with_suffix(".manifest.json")
    )

    clear_scene()
    prepared_obj, imported_mesh_count = import_source(source)
    normalization = normalize_center_origin(prepared_obj, args.target_size)
    normalization_data = normalization_manifest(normalization, args.target_size)

    export_selection(out, [prepared_obj])
    crystal_obj, crystal_report = isolate_crystal_faces(prepared_obj, args)
    export_selection(crystal_out, [crystal_obj])

    prepared_manifest = {
        "kind": "emerald_apocalypse_orbital_shard_prepared",
        "asset": ASSET_NAME,
        "source": str(source),
        "source_contract": "Corrected Emerald Crystal Core GLB only; no Nexus Prism source input.",
        "prepared_glb": str(out),
        "prepared_object_name": PREPARED_OBJECT_NAME,
        "imported_mesh_count": imported_mesh_count,
        "joined_mesh_objects": imported_mesh_count > 1,
        "normalization": normalization_data,
        "next_artifact": str(crystal_out),
        "rendering_status": "not-rendered; this slice only prepares durable GLBs and manifests",
    }
    crystal_manifest = {
        "kind": "emerald_apocalypse_orbital_shard_crystal_face_isolation",
        "asset": ASSET_NAME,
        "source": str(source),
        "prepared_glb": str(out),
        "crystal_faces_glb": str(crystal_out),
        "crystal_faces_object_name": CRYSTAL_FACES_OBJECT_NAME,
        "normalization": normalization_data,
        "selection": {
            "min_face_score": args.min_face_score,
            "neighbor_face_score": args.neighbor_face_score,
            "min_component_score": args.min_component_score,
            "min_component_p90": args.min_component_p90,
            "min_bright_fraction": args.min_bright_fraction,
            "strong_face_score": args.strong_face_score,
            "min_component_area": args.min_component_area,
            "min_component_faces": args.min_component_faces,
            "min_normal_spread": args.min_normal_spread,
            "max_sample_faces": args.max_sample_faces,
            "keep_whole_crystal_components": args.keep_whole_crystal_components,
            "precedent": "Adapted from emerald-apocalypse-hover-tank crystal overlay isolation, with shard-specific names and emerald/cyan face scoring.",
        },
        "rendering_status": "not-rendered; use as a later glow/crystal-face input only after visual approval",
        **crystal_report,
    }
    write_json(manifest_path, prepared_manifest)
    write_json(crystal_manifest_path, crystal_manifest)

    print(f"prepared_glb={out}")
    print(f"prepared_manifest={manifest_path}")
    print(f"crystal_faces_glb={crystal_out}")
    print(f"crystal_faces_manifest={crystal_manifest_path}")
    print(f"crystal_faces_after={crystal_report['face_count_after']}")


if __name__ == "__main__":
    main()
