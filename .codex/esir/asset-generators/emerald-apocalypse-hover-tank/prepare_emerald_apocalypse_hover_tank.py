import argparse
import json
import math
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Vector


ASSET_NAME = "emerald-apocalypse-hover-tank"
BODY_OBJECT_NAME = "emerald-apocalypse-hover-tank-body"
ARTIFACT_OBJECT_NAME = "emerald-apocalypse-hover-tank-removed-forward-cylinder"
BARREL_NEEDLE_OBJECT_NAME = "emerald-apocalypse-hover-tank-removed-barrel-needle"


def parse_args():
    parser = argparse.ArgumentParser(description="Prepare Emerald Apocalypse Hover Tank GLB for ESIR preset rendering.")
    parser.add_argument("--source", required=True, help="Path to the read-only source GLB.")
    parser.add_argument("--out", required=True, help="Prepared clean GLB path.")
    parser.add_argument("--artifact-out", required=True, help="GLB path containing the hidden removed barrel cylinder evidence.")
    parser.add_argument("--manifest", help="Optional JSON manifest path.")
    parser.add_argument("--target-width", type=float, default=4.4, help="Prepared model width in preset world units.")
    parser.add_argument("--min-green-score", type=float, default=0.36, help="Material green dominance threshold.")
    parser.add_argument("--min-length-ratio", type=float, default=2.8, help="Minimum elongated component ratio for the cylinder artifact.")
    parser.add_argument("--min-fallback-faces", type=int, default=20, help="Minimum connected faces for geometry-only artifact fallback.")
    parser.add_argument("--barrel-axis", choices=["x", "y", "z"], default="x", help="Source-space barrel axis used to prefer the protruding needle.")
    parser.add_argument("--barrel-sign", choices=["positive", "negative"], default="negative", help="Source-space barrel direction used to prefer the protruding needle.")
    parser.add_argument("--min-barrel-needle-ratio", type=float, default=5.8, help="Minimum elongation for the targeted post-nozzle needle.")
    parser.add_argument("--max-barrel-needle-faces", type=int, default=900, help="Maximum connected faces for the skinny needle so the faceted nozzle is preserved.")
    parser.add_argument("--barrel-trim-fused-needle", dest="barrel_trim_fused_needle", action="store_true", default=True, help="Trim same-axis skinny faces fused into the larger front crystal component.")
    parser.add_argument("--no-barrel-trim-fused-needle", dest="barrel_trim_fused_needle", action="store_false", help="Disable same-axis fused needle trimming.")
    parser.add_argument("--barrel-trim-cross-radius", type=float, default=0.026, help="Source-space cross-axis radius for trimming fused needle faces.")
    parser.add_argument("--barrel-trim-axis-pad", type=float, default=0.005, help="Source-space pad behind the removed needle component when trimming fused needle faces.")
    parser.add_argument("--restore-muzzle-crystal-cap", dest="restore_muzzle_crystal_cap", action="store_true", default=False, help="Add back a short faceted crystal cap after fused needle trimming.")
    parser.add_argument("--no-restore-muzzle-crystal-cap", dest="restore_muzzle_crystal_cap", action="store_false", help="Disable faceted crystal cap restoration.")
    parser.add_argument("--muzzle-cap-radius", type=float, default=0.063, help="Source-space radius of the restored crystal cap base.")
    parser.add_argument("--muzzle-cap-length", type=float, default=0.075, help="Source-space length of the restored crystal cap beyond the removed-cylinder rear cutoff.")
    parser.add_argument("--material-exposure-stops", type=float, default=0.0, help="Optional preview-only material brightness lift in photographic stops.")
    parser.add_argument("--emission-strength-scale", type=float, default=1.0, help="Optional preview-only emission strength multiplier.")
    parser.add_argument("--keep-artifact-visible", action="store_true", help="Keep the removed cylinder visible in the prepared blend/export evidence.")
    return parser.parse_args(sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else [])


def clear_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete()


def import_source(path):
    bpy.ops.import_scene.gltf(filepath=str(path))
    meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    if not meshes:
        raise RuntimeError(f"No mesh objects imported from {path}")
    return meshes


def material_color(material):
    color = list(material.diffuse_color[:4]) if material else [0.0, 0.0, 0.0, 1.0]
    emission = [0.0, 0.0, 0.0, 0.0]
    emission_strength = 0.0
    if material and material.use_nodes:
        for node in material.node_tree.nodes:
            if node.type == "BSDF_PRINCIPLED":
                if "Base Color" in node.inputs:
                    color = list(node.inputs["Base Color"].default_value)
                if "Emission Color" in node.inputs:
                    emission = list(node.inputs["Emission Color"].default_value)
                if "Emission Strength" in node.inputs:
                    emission_strength = float(node.inputs["Emission Strength"].default_value)
            elif node.type == "EMISSION":
                if "Color" in node.inputs:
                    emission = list(node.inputs["Color"].default_value)
                if "Strength" in node.inputs:
                    emission_strength = float(node.inputs["Strength"].default_value)
    return color, emission, emission_strength


def green_score(material):
    color, emission, emission_strength = material_color(material)
    base_green = color[1] - max(color[0], color[2])
    base_bright = max(color[0], color[1], color[2])
    emission_green = emission[1] - max(emission[0], emission[2])
    emission_bright = max(emission[0], emission[1], emission[2]) * max(1.0, emission_strength)
    return max(0.0, base_green) * base_bright + max(0.0, emission_green) * emission_bright


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


def vector_to_json(v):
    return [round(float(v.x), 6), round(float(v.y), 6), round(float(v.z), 6)]


def bbox_for_world_points(points):
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


def component_axis_and_endpoint(low, high, model_center):
    dims = [high.x - low.x, high.y - low.y, high.z - low.z]
    axis_index = max(range(3), key=lambda index: dims[index])
    axis_name = ["x", "y", "z"][axis_index]
    center = Vector(((low.x + high.x) * 0.5, (low.y + high.y) * 0.5, (low.z + high.z) * 0.5))
    positive_distance = [high.x, high.y, high.z][axis_index] - [model_center.x, model_center.y, model_center.z][axis_index]
    negative_distance = [model_center.x, model_center.y, model_center.z][axis_index] - [low.x, low.y, low.z][axis_index]
    sign = 1.0 if positive_distance >= negative_distance else -1.0
    endpoint = center.copy()
    if axis_index == 0:
        endpoint.x = high.x if sign > 0 else low.x
    elif axis_index == 1:
        endpoint.y = high.y if sign > 0 else low.y
    else:
        endpoint.z = high.z if sign > 0 else low.z
    axis = Vector((0.0, 0.0, 0.0))
    axis[axis_index] = sign
    return axis_name, sign, axis, endpoint


def find_green_cylinder_components(
    meshes,
    min_green_score,
    min_length_ratio,
    min_fallback_faces,
    barrel_axis,
    barrel_sign,
    min_barrel_needle_ratio,
    max_barrel_needle_faces,
):
    model_low, model_high = world_bounds(meshes)
    model_center = Vector(((model_low.x + model_high.x) * 0.5, (model_low.y + model_high.y) * 0.5, (model_low.z + model_high.z) * 0.5))
    candidates = []
    material_report = []

    for obj in meshes:
        scores = [green_score(slot.material) for slot in obj.material_slots]
        material_report.extend(
            {
                "object": obj.name,
                "slot": index,
                "material": slot.material.name if slot.material else None,
                "green_score": round(scores[index], 6),
            }
            for index, slot in enumerate(obj.material_slots)
        )
        green_slots = {index for index, score in enumerate(scores) if score >= min_green_score}

        mesh = obj.data
        bm = bmesh.new()
        bm.from_mesh(mesh)
        bm.faces.ensure_lookup_table()
        green_faces = {face for face in bm.faces if face.material_index in green_slots} if green_slots else set()
        search_sets = [("bright-green-material", green_faces)] if green_faces else []
        search_sets.append(("geometry-fallback", set(bm.faces)))
        seen = set()
        for source, face_set in search_sets:
            for face in list(face_set):
                if face in seen:
                    continue
                stack = [face]
                seen.add(face)
                component = []
                while stack:
                    current = stack.pop()
                    component.append(current)
                    for edge in current.edges:
                        for linked_face in edge.link_faces:
                            if linked_face in face_set and linked_face not in seen:
                                seen.add(linked_face)
                                stack.append(linked_face)

                points = [obj.matrix_world @ vertex.co for component_face in component for vertex in component_face.verts]
                if not points:
                    continue
                low, high = bbox_for_world_points(points)
                raw_dims = [high.x - low.x, high.y - low.y, high.z - low.z]
                dims = sorted(raw_dims, reverse=True)
                longest = dims[0]
                thickness = max(0.0001, (dims[1] + dims[2]) * 0.5)
                length_ratio = longest / thickness
                axis_name, sign, axis, endpoint = component_axis_and_endpoint(low, high, model_center)
                if source == "bright-green-material" and length_ratio < min_length_ratio:
                    continue
                if source == "geometry-fallback":
                    horizontal_axis = axis_name in {"x", "y"}
                    smallish = max(raw_dims) < max(model_high.x - model_low.x, model_high.y - model_low.y) * 0.55
                    if len(component) < min_fallback_faces or length_ratio < min_length_ratio or not horizontal_axis or not smallish:
                        continue

                forwardness = (endpoint - model_center).length
                source_bonus = 24.0 if source == "bright-green-material" else 0.0
                score = source_bonus + length_ratio * 3.0 + forwardness + math.log(max(1, len(component)))
                candidates.append(
                    {
                        "object": obj,
                        "bm": bm,
                        "faces": component,
                        "score": score,
                        "source": source,
                        "face_count": len(component),
                        "bbox_low": low,
                        "bbox_high": high,
                        "axis_name": axis_name,
                        "axis_sign": sign,
                        "axis": axis,
                        "endpoint": endpoint,
                        "length_ratio": length_ratio,
                    }
                )

        if not any(candidate["object"] is obj for candidate in candidates):
            bm.free()

    if not candidates:
        raise RuntimeError("No elongated extremely bright green cylinder component was found.")

    axis_index = {"x": 0, "y": 1, "z": 2}[barrel_axis]
    wanted_sign = 1.0 if barrel_sign == "positive" else -1.0
    model_extent = max(model_high.x - model_low.x, model_high.y - model_low.y, model_high.z - model_low.z)

    def axis_value(vector):
        return [vector.x, vector.y, vector.z][axis_index]

    preferred = []
    for candidate in candidates:
        raw_dims = [
            candidate["bbox_high"].x - candidate["bbox_low"].x,
            candidate["bbox_high"].y - candidate["bbox_low"].y,
            candidate["bbox_high"].z - candidate["bbox_low"].z,
        ]
        sorted_dims = sorted(raw_dims, reverse=True)
        longest = sorted_dims[0]
        cross_section = (sorted_dims[1] + sorted_dims[2]) * 0.5
        endpoint_delta = (axis_value(candidate["endpoint"]) - axis_value(model_center)) * wanted_sign
        center_delta = (axis_value((candidate["bbox_low"] + candidate["bbox_high"]) * 0.5) - axis_value(model_center)) * wanted_sign
        if (
            candidate["axis_name"] == barrel_axis
            and candidate["axis_sign"] == wanted_sign
            and candidate["length_ratio"] >= min_barrel_needle_ratio
            and candidate["face_count"] <= max_barrel_needle_faces
            and endpoint_delta > model_extent * 0.22
            and center_delta > 0
            and cross_section < model_extent * 0.04
        ):
            candidate["targeted_barrel_needle_score"] = endpoint_delta * 16.0 + candidate["length_ratio"] + longest
            preferred.append(candidate)

    if preferred:
        preferred.sort(key=lambda item: item["targeted_barrel_needle_score"], reverse=True)
        selected = preferred[0]
        selected["selection_mode"] = "targeted-barrel-needle"
    else:
        candidates.sort(key=lambda item: item["score"], reverse=True)
        selected = candidates[0]
        selected["selection_mode"] = "legacy-elongated-component-fallback"

    selected_bm = selected["bm"]
    freed_bms = set()
    for candidate in candidates[1:]:
        candidate_bm = candidate["bm"]
        if candidate_bm is not selected_bm and id(candidate_bm) not in freed_bms:
            candidate_bm.free()
            freed_bms.add(id(candidate_bm))
    return selected, model_low, model_high, material_report


def trim_fused_barrel_needle(obj, selected, max_cross_radius, axis_pad):
    if max_cross_radius <= 0:
        return 0

    axis_index = {"x": 0, "y": 1, "z": 2}[selected["axis_name"]]
    axis_sign = selected["axis_sign"]
    bbox_low = selected["bbox_low"]
    bbox_high = selected["bbox_high"]
    cross_center = [
        (bbox_low.x + bbox_high.x) * 0.5,
        (bbox_low.y + bbox_high.y) * 0.5,
        (bbox_low.z + bbox_high.z) * 0.5,
    ]
    if axis_index == 0:
        cutoff = bbox_high.x + axis_pad if axis_sign < 0 else bbox_low.x - axis_pad
    elif axis_index == 1:
        cutoff = bbox_high.y + axis_pad if axis_sign < 0 else bbox_low.y - axis_pad
    else:
        cutoff = bbox_high.z + axis_pad if axis_sign < 0 else bbox_low.z - axis_pad

    def axis_value(vector):
        return [vector.x, vector.y, vector.z][axis_index]

    def cross_radius(vector):
        coords = [vector.x, vector.y, vector.z]
        total = 0.0
        for index, value in enumerate(coords):
            if index != axis_index:
                total += (value - cross_center[index]) ** 2
        return math.sqrt(total)

    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bm.faces.ensure_lookup_table()
    doomed = []
    for face in bm.faces:
        center = obj.matrix_world @ face.calc_center_median()
        axis_delta = (axis_value(center) - cutoff) * axis_sign
        vertex_radius = max(cross_radius(obj.matrix_world @ vertex.co) for vertex in face.verts)
        if axis_delta >= 0 and vertex_radius <= max_cross_radius:
            doomed.append(face)
    bmesh.ops.delete(bm, geom=doomed, context="FACES")
    bm.to_mesh(obj.data)
    bm.free()
    obj.data.update()
    return len(doomed)


def make_muzzle_cap_material():
    material = bpy.data.materials.new("ESIR restored emerald muzzle crystal")
    material.use_nodes = True
    material.diffuse_color = (0.0, 0.38, 0.25, 1.0)
    node = material.node_tree.nodes.get("Principled BSDF")
    if node:
        if "Base Color" in node.inputs:
            node.inputs["Base Color"].default_value = (0.0, 0.40, 0.25, 1.0)
        if "Metallic" in node.inputs:
            node.inputs["Metallic"].default_value = 0.0
        if "Roughness" in node.inputs:
            node.inputs["Roughness"].default_value = 0.34
        if "Emission Color" in node.inputs:
            node.inputs["Emission Color"].default_value = (0.0, 0.2, 0.12, 1.0)
        if "Emission Strength" in node.inputs:
            node.inputs["Emission Strength"].default_value = 0.025
    return material


def restore_muzzle_crystal_cap(selected, radius, cap_length):
    if radius <= 0:
        return None
    axis_index = {"x": 0, "y": 1, "z": 2}[selected["axis_name"]]
    if axis_index != 0:
        return None

    bbox_low = selected["bbox_low"]
    bbox_high = selected["bbox_high"]
    axis_sign = selected["axis_sign"]
    center_y = (bbox_low.y + bbox_high.y) * 0.5
    center_z = (bbox_low.z + bbox_high.z) * 0.5
    if axis_sign < 0:
        tip_x = bbox_high.x - cap_length
        base_x = bbox_high.x + 0.025
    else:
        tip_x = bbox_low.x + cap_length
        base_x = bbox_low.x - 0.025
    mid_x = tip_x * 0.38 + base_x * 0.62

    sides = 8
    vertices = []
    for x_value, scale_y, scale_z, phase in [
        (base_x, 1.0, 0.86, 0.0),
        (mid_x, 0.55, 0.48, math.pi / sides),
    ]:
        for index in range(sides):
            angle = (math.tau * index / sides) + phase
            vertices.append(
                (
                    x_value,
                    center_y + math.cos(angle) * radius * scale_y,
                    center_z + math.sin(angle) * radius * scale_z,
                )
            )
    tip_index = len(vertices)
    vertices.append((tip_x, center_y, center_z))
    base_center_index = len(vertices)
    vertices.append((base_x, center_y, center_z))

    faces = []
    for index in range(sides):
        next_index = (index + 1) % sides
        base_a = index
        base_b = next_index
        mid_a = sides + index
        mid_b = sides + next_index
        faces.append((base_a, base_b, mid_b, mid_a))
        faces.append((mid_a, mid_b, tip_index))
        faces.append((base_center_index, base_b, base_a))

    mesh = bpy.data.meshes.new("emerald-apocalypse-hover-tank-restored-muzzle-crystal-cap")
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new("emerald-apocalypse-hover-tank-restored-muzzle-crystal-cap", mesh)
    obj.data.materials.append(make_muzzle_cap_material())
    bpy.context.collection.objects.link(obj)
    return obj


def make_role_objects(selected, trim_fused_needle, trim_cross_radius, trim_axis_pad):
    source_obj = selected["object"]
    clean = source_obj.copy()
    clean.data = source_obj.data.copy()
    clean.name = BODY_OBJECT_NAME
    clean.data.name = BODY_OBJECT_NAME
    bpy.context.collection.objects.link(clean)

    artifact = source_obj.copy()
    artifact.data = source_obj.data.copy()
    artifact.name = ARTIFACT_OBJECT_NAME
    artifact.data.name = ARTIFACT_OBJECT_NAME
    bpy.context.collection.objects.link(artifact)

    selected_face_centers = {
        tuple(round(float(coord), 6) for coord in (source_obj.matrix_world @ face.calc_center_median()))
        for face in selected["faces"]
    }

    def delete_faces_by_membership(obj, keep_selected):
        bm = bmesh.new()
        bm.from_mesh(obj.data)
        bm.faces.ensure_lookup_table()
        doomed = []
        for face in bm.faces:
            center_key = tuple(round(float(coord), 6) for coord in (obj.matrix_world @ face.calc_center_median()))
            is_selected = center_key in selected_face_centers
            if is_selected != keep_selected:
                doomed.append(face)
        bmesh.ops.delete(bm, geom=doomed, context="FACES")
        bm.to_mesh(obj.data)
        bm.free()
        obj.data.update()
        return len(doomed)

    clean_deleted = delete_faces_by_membership(clean, keep_selected=False)
    fused_trim_deleted = 0
    if trim_fused_needle:
        fused_trim_deleted = trim_fused_barrel_needle(clean, selected, trim_cross_radius, trim_axis_pad)
    artifact_deleted = delete_faces_by_membership(artifact, keep_selected=True)
    bpy.data.objects.remove(source_obj, do_unlink=True)
    selected["bm"].free()
    return clean, artifact, clean_deleted, fused_trim_deleted, artifact_deleted


def normalize_objects(objects, low, high, target_width):
    center = Vector(((low.x + high.x) * 0.5, (low.y + high.y) * 0.5, low.z))
    width = max(high.x - low.x, high.y - low.y)
    scale = target_width / width if width > 0 else 1.0
    for obj in objects:
        world = obj.matrix_world.copy()
        for vertex in obj.data.vertices:
            vertex.co = (world @ vertex.co - center) * scale
        obj.matrix_world.identity()
        obj.data.update()
    return center, scale


def transform_metadata(point, axis, origin, scale):
    return (point - origin) * scale, axis.normalized()


def clamp_color(value):
    return max(0.0, min(1.0, float(value)))


def apply_material_exposure(objects, exposure_stops, emission_strength_scale):
    if abs(exposure_stops) < 0.0001 and abs(emission_strength_scale - 1.0) < 0.0001:
        return []

    factor = 2.0 ** exposure_stops
    seen = set()
    report = []
    for obj in objects:
        for slot in obj.material_slots:
            material = slot.material
            if not material or material.name in seen:
                continue
            seen.add(material.name)
            if material.diffuse_color:
                material.diffuse_color = (
                    clamp_color(material.diffuse_color[0] * factor),
                    clamp_color(material.diffuse_color[1] * factor),
                    clamp_color(material.diffuse_color[2] * factor),
                    material.diffuse_color[3],
                )
            changed_nodes = []
            if material.use_nodes:
                for node in material.node_tree.nodes:
                    if node.type == "BSDF_PRINCIPLED":
                        if "Base Color" in node.inputs:
                            color = node.inputs["Base Color"].default_value
                            node.inputs["Base Color"].default_value = (
                                clamp_color(color[0] * factor),
                                clamp_color(color[1] * factor),
                                clamp_color(color[2] * factor),
                                color[3],
                            )
                            changed_nodes.append("Principled Base Color")
                            links = list(node.inputs["Base Color"].links)
                            for link in links:
                                from_socket = link.from_socket
                                boost = material.node_tree.nodes.new("ShaderNodeHueSaturation")
                                boost.name = "ESIR Emerald render value boost"
                                boost.label = "ESIR Emerald render value boost"
                                boost.inputs["Hue"].default_value = 0.5
                                boost.inputs["Saturation"].default_value = 1.0
                                boost.inputs["Value"].default_value = factor
                                boost.inputs["Fac"].default_value = 1.0
                                material.node_tree.links.remove(link)
                                material.node_tree.links.new(from_socket, boost.inputs["Color"])
                                material.node_tree.links.new(boost.outputs["Color"], node.inputs["Base Color"])
                                changed_nodes.append("Base Color texture Value boost")
                        if "Emission Strength" in node.inputs:
                            node.inputs["Emission Strength"].default_value = float(node.inputs["Emission Strength"].default_value) * emission_strength_scale
                            changed_nodes.append("Principled Emission Strength")
                    elif node.type == "EMISSION" and "Strength" in node.inputs:
                        node.inputs["Strength"].default_value = float(node.inputs["Strength"].default_value) * emission_strength_scale
                        changed_nodes.append("Emission Strength")
            report.append(
                {
                    "material": material.name,
                    "exposure_stops": exposure_stops,
                    "emission_strength_scale": emission_strength_scale,
                    "changed_nodes": sorted(set(changed_nodes)),
                }
            )
    return report


def export_selection(path, objects):
    path.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.export_scene.gltf(filepath=str(path), export_format="GLB", use_selection=True, export_apply=True)


def main():
    args = parse_args()
    source = Path(args.source).expanduser().resolve()
    out = Path(args.out).expanduser().resolve()
    artifact_out = Path(args.artifact_out).expanduser().resolve()
    manifest_path = Path(args.manifest).expanduser().resolve() if args.manifest else out.with_suffix(".manifest.json")

    clear_scene()
    meshes = import_source(source)
    selected, model_low, model_high, material_report = find_green_cylinder_components(
        meshes,
        min_green_score=args.min_green_score,
        min_length_ratio=args.min_length_ratio,
        min_fallback_faces=args.min_fallback_faces,
        barrel_axis=args.barrel_axis,
        barrel_sign=args.barrel_sign,
        min_barrel_needle_ratio=args.min_barrel_needle_ratio,
        max_barrel_needle_faces=args.max_barrel_needle_faces,
    )
    selected_source_object_name = selected["object"].name
    clean, artifact, clean_deleted, fused_trim_deleted, artifact_deleted = make_role_objects(
        selected,
        args.barrel_trim_fused_needle,
        args.barrel_trim_cross_radius,
        args.barrel_trim_axis_pad,
    )
    restored_cap = restore_muzzle_crystal_cap(selected, args.muzzle_cap_radius, args.muzzle_cap_length) if args.restore_muzzle_crystal_cap else None
    remaining_meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH" and obj.name != ARTIFACT_OBJECT_NAME]
    origin, scale = normalize_objects(remaining_meshes + [artifact], model_low, model_high, args.target_width)
    material_exposure_report = apply_material_exposure(remaining_meshes, args.material_exposure_stops, args.emission_strength_scale)
    normalized_endpoint, normalized_axis = transform_metadata(selected["endpoint"], selected["axis"], origin, scale)

    export_selection(out, remaining_meshes)
    artifact.hide_viewport = False
    artifact.hide_render = False
    export_selection(artifact_out, [artifact])
    artifact.hide_viewport = not args.keep_artifact_visible
    artifact.hide_render = True

    manifest = {
        "asset": ASSET_NAME,
        "source": str(source),
        "prepared_glb": str(out),
        "removed_artifact_glb": str(artifact_out),
        "body_object_name": BODY_OBJECT_NAME,
        "artifact_object_name": ARTIFACT_OBJECT_NAME,
        "target_width": args.target_width,
        "normalization": {
            "source_origin_world": vector_to_json(origin),
            "scale": round(float(scale), 8),
            "source_bounds_low": vector_to_json(model_low),
            "source_bounds_high": vector_to_json(model_high),
        },
        "removed_forward_cylinder": {
            "source_object": selected_source_object_name,
            "detection_source": selected["source"],
            "selection_mode": selected["selection_mode"],
            "face_count": selected["face_count"],
            "clean_deleted_faces": clean_deleted,
            "fused_trim_deleted_faces": fused_trim_deleted,
            "fused_trim_enabled": args.barrel_trim_fused_needle,
            "fused_trim_cross_radius": args.barrel_trim_cross_radius,
            "fused_trim_axis_pad": args.barrel_trim_axis_pad,
            "restored_muzzle_crystal_cap": bool(restored_cap),
            "restored_muzzle_crystal_cap_radius": args.muzzle_cap_radius,
            "restored_muzzle_crystal_cap_length": args.muzzle_cap_length,
            "artifact_deleted_faces": artifact_deleted,
            "bbox_low_world": vector_to_json(selected["bbox_low"]),
            "bbox_high_world": vector_to_json(selected["bbox_high"]),
            "axis_name": selected["axis_name"],
            "axis_sign": selected["axis_sign"],
            "length_ratio": round(float(selected["length_ratio"]), 6),
            "hidden_in_prepared_scene": not args.keep_artifact_visible,
            "renderable": False,
            "preservation_note": "The targeted cleanup is capped below the thicker faceted crystal nozzle face count and requires high elongation, so the broad crystal muzzle immediately behind the needle remains in the prepared GLB."
        },
        "muzzle_endpoint": {
            "world_source": vector_to_json(selected["endpoint"]),
            "prepared_space": vector_to_json(normalized_endpoint),
            "axis_prepared_space": vector_to_json(normalized_axis),
            "usage": "Anchor chargeup, muzzle flash, beam origin, and shield impact alignment. The removed cylinder itself is evidence only and should not be rendered in the base pass."
        },
        "material_report": material_report,
        "material_exposure": {
            "exposure_stops": args.material_exposure_stops,
            "emission_strength_scale": args.emission_strength_scale,
            "changed_materials": material_exposure_report,
            "usage": "Defaults leave production material unchanged. Non-zero values are intended for brighter Factorio-preset preview GLBs."
        },
        "rendering": {
            "preset": "factorioRenderingPreset_v4.blend",
            "passes": ["object", "shadow", "light-alpha-reduced", "light-alpha", "mask"],
            "directions": 64,
            "classification": {
                "object": "base",
                "shadow": "shadow",
                "light-alpha-reduced": "glow",
                "light-alpha": "glow",
                "mask": "mask evidence pending owner-readability review"
            }
        }
    }
    manifest_path.parent.mkdir(parents=True, exist_ok=True)
    manifest_path.write_text(json.dumps(manifest, indent=2), encoding="utf-8")


if __name__ == "__main__":
    main()
