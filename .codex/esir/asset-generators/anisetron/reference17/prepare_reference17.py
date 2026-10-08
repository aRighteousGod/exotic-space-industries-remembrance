"""Prepare reference17 source triangles/UVs/PBR and named visual anchors unchanged."""
import argparse
import hashlib
import json
import math
from pathlib import Path
import sys

import bpy
import numpy as np
from mathutils import Matrix, Vector


def digest(array):
    return hashlib.sha256(np.ascontiguousarray(array).tobytes()).hexdigest()


def material_snapshot(material):
    nodes = []
    for node in material.node_tree.nodes:
        record = {'name': node.name, 'type': node.bl_idname}
        if node.type == 'TEX_IMAGE' and node.image:
            record.update(image=node.image.name, size=list(node.image.size),
                          colorspace=node.image.colorspace_settings.name,
                          packed=bool(node.image.packed_file))
        nodes.append(record)
    links = [(link.from_node.name, link.from_socket.name,
              link.to_node.name, link.to_socket.name)
             for link in material.node_tree.links]
    return {'nodes': nodes, 'links': links}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--input', required=True, type=Path)
    parser.add_argument('--output', required=True, type=Path)
    parser.add_argument('--directions', type=int, default=128)
    parser.add_argument('--emission', type=float, default=.65)
    args = parser.parse_args(sys.argv[sys.argv.index('--') + 1:])
    assert args.directions == 128, 'This approved draft targets128 directions'
    source, output = args.input.resolve(), args.output.resolve()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(source))
    meshes = [obj for obj in bpy.context.scene.objects if obj.type == 'MESH']
    assert len(meshes) == 1, 'Source contract changed: inspect mesh grouping'
    body = meshes[0]
    body.name = 'cathedral_architecture'
    world = body.matrix_world.copy()
    body.parent = None
    body.matrix_world = Matrix.Identity(4)
    body.data.transform(world)
    for obj in list(bpy.context.scene.objects):
        if obj != body:
            bpy.data.objects.remove(obj, do_unlink=True)
    mesh = body.data
    assert len(mesh.materials) == 1 and mesh.uv_layers.active
    original_faces, original_vertices = len(mesh.polygons), len(mesh.vertices)
    assert all(p.loop_total == 3 for p in mesh.polygons)
    xyz = np.empty(original_vertices * 3, dtype=np.float32)
    mesh.vertices.foreach_get('co', xyz)
    xyz = xyz.reshape(-1, 3)
    source_geometry_hash = digest(xyz)
    lo, hi = xyz.min(0), xyz.max(0)
    origin = np.array([(lo[0]+hi[0])/2, (lo[1]+hi[1])/2, lo[2]], dtype=np.float32)
    xyz -= origin
    # Meshy17 facade points-Y at source yaw0. Rotate once into the existing
    # native contract: +Y facade, N rear and S facade at initial angle0.
    xyz[:, :2] *= -1
    count = args.directions
    width = max(np.ptp(xyz[:, 0]*math.cos(i*math.tau/count)
                       - xyz[:, 1]*math.sin(i*math.tau/count)) for i in range(count))
    height = max(np.ptp((xyz[:, 0]*math.sin(i*math.tau/count)
                        + xyz[:, 1]*math.cos(i*math.tau/count)
                        + xyz[:, 2])/math.sqrt(2)) for i in range(count))
    scale = min(6/width, 8/height)
    xyz *= scale
    # Mesh.transform also transforms imported custom normals; changing only
    # vertex coordinates would retain the old normal orientation after yaw.
    normals_before = np.empty(len(mesh.corner_normals)*3, dtype=np.float32)
    mesh.corner_normals.foreach_get('vector', normals_before)
    transform = Matrix.Scale(float(scale), 4) @ Matrix.Rotation(math.pi, 4, 'Z') @ Matrix.Translation(-Vector(origin))
    mesh.transform(transform)
    mesh.update()
    normals_after = np.empty(len(mesh.corner_normals)*3, dtype=np.float32)
    mesh.corner_normals.foreach_get('vector', normals_after)
    expected_normals = normals_before.reshape(-1, 3).copy()
    expected_normals[:, :2] *= -1
    normal_error = float(np.max(np.abs(normals_after.reshape(-1, 3)-expected_normals)))
    # Blender's imported split-normal packing introduces sub-degree rounding
    # on a transform. A wrong yaw would exceed this by orders of magnitude.
    assert normal_error < .002, ('Imported normal transform changed', normal_error)
    mesh.vertices.foreach_get('co', xyz.ravel())
    lo, hi = xyz.min(0), xyz.max(0)
    loop_vertices = np.empty(len(mesh.loops), dtype=np.int32)
    mesh.loops.foreach_get('vertex_index', loop_vertices)
    triangles = loop_vertices.reshape(-1, 3)
    source_uv = np.empty(len(mesh.loops)*2, dtype=np.float32)
    mesh.uv_layers.active.data.foreach_get('uv', source_uv)
    source_uv = source_uv.reshape(-1, 3, 2)
    face_geometry = xyz[triangles]
    centers, face_uv = face_geometry.mean(1), source_uv.mean(1)
    prepared_geometry_hash, uv_hash = digest(face_geometry), digest(source_uv)
    source_material = mesh.materials[0]
    source_material.name = 'cathedral_source_pbr'
    original_pbr = material_snapshot(source_material)
    source_bsdf = next(n for n in source_material.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    texture = source_bsdf.inputs['Base Color'].links[0].from_node.image
    assert list(texture.size) == [8192, 8192], 'Embedded full-resolution albedo missing'
    scoring = texture.copy()
    scoring.scale(2048, 2048)
    pixels = np.empty(2048*2048*4, dtype=np.float32)
    scoring.pixels.foreach_get(pixels)
    pixels = pixels.reshape(2048, 2048, 4)
    rgb = pixels[np.clip((face_uv[:, 1]*2047).astype(int), 0, 2047),
                 np.clip((face_uv[:, 0]*2047).astype(int), 0, 2047), :3]
    z = centers[:, 2]/hi[2]
    cool = (np.minimum(rgb[:, 1], rgb[:, 2])-rgb[:, 0]*1.15 > .018) & (np.minimum(rgb[:, 1], rgb[:, 2]) > .045)
    # The exposed tall center crystal, facade crystal and low keels are distinct
    # original regions. Color protects the gold ribs from geometry-only selection.
    top = cool & (z > .61) & (np.abs(centers[:, 0]) < (hi[0]-lo[0])*.32)
    facade = cool & (z > .32) & (z < .64) & (centers[:, 1] > (hi[1]-lo[1])*.24)
    facade &= np.abs(centers[:, 0]) < (hi[0]-lo[0])*.26
    facade &= ~top
    keel = cool & (z < .23)
    assert top.sum() > 50 and facade.sum() > 50 and keel.sum() > 50, (top.sum(), facade.sum(), keel.sum())
    assert not np.any(top & facade), 'Crystal role ranges overlap'
    crystal = top | facade | keel
    # The owner crest uses an existing gold facade patch beside the crystal.
    gold = (rgb[:, 0] > .12) & (rgb[:, 1] > rgb[:, 2]*1.15)
    crest_candidates = gold & (centers[:, 1] > (hi[1]-lo[1])*.25) & ~crystal
    desired = np.array([hi[0]*.54, hi[1], hi[2]*.30])
    distances = np.square(centers-desired).sum(1)
    distances[~crest_candidates] = np.inf
    crest_center = centers[np.argmin(distances)]
    crest = crest_candidates & (np.square(centers-crest_center).sum(1) < .13**2)
    assert crest.sum() > 10
    bpy.data.images.remove(scoring)
    materials = ['architecture', 'top-crystal', 'facade-crystal', 'keel-crystal', 'owner-mask']
    for role in materials[1:4]:
        material = source_material.copy()
        material.name = 'cathedral_' + role.replace('-', '_') + '_pbr'
        bsdf = next(n for n in material.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
        material.node_tree.links.new(bsdf.inputs['Base Color'].links[0].from_socket, bsdf.inputs['Emission Color'])
        bsdf.inputs['Emission Strength'].default_value = args.emission
        aov = material.node_tree.nodes.new('ShaderNodeOutputAOV')
        aov.name = aov.aov_name = 'anisetron_glow_mask'
        aov.inputs['Value'].default_value = 1
        mesh.materials.append(material)
    owner = bpy.data.materials.new('force_trim_neutral')
    owner.use_nodes = True
    node = owner.node_tree.nodes.get('Principled BSDF')
    node.inputs['Base Color'].default_value = (.65, .65, .65, 1)
    node.inputs['Metallic'].default_value = .1
    node.inputs['Roughness'].default_value = .6
    mesh.materials.append(owner)
    indices = np.zeros(original_faces, dtype=np.int32)
    indices[top], indices[facade], indices[keel], indices[crest] = 1, 2, 3, 4
    mesh.polygons.foreach_set('material_index', indices)
    ids = mesh.attributes.new('anisetron_source_face', 'INT', 'FACE')
    ids.data.foreach_set('value', np.arange(original_faces, dtype=np.int32))
    # Anchors select actual source vertices; they never create new geometry.
    top_vertices = xyz[np.unique(triangles[top])]
    top_anchor = top_vertices[np.argmax(top_vertices[:, 2])]
    front_centers = centers[facade]
    front_color = rgb[facade]
    front_weight = np.maximum(np.minimum(front_color[:, 1], front_color[:, 2])-front_color[:, 0], .001)
    # Frontmost-quarter centers exclude a beveled flank and select the visible
    # crystal face. Its weighted center is the facade beam origin.
    front = front_centers[:, 1] >= np.quantile(front_centers[:, 1], .75)
    facade_anchor = np.average(front_centers[front], axis=0, weights=front_weight[front])
    keel_vertices = xyz[np.unique(triangles[keel])]
    # Separate existing hanging points by X third, then choose each minimum-Z
    # source vertex. Each is checked against the selected original keel region.
    cuts = np.quantile(keel_vertices[:, 0], [1/3, 2/3])
    keel_anchors = []
    for region in (keel_vertices[:, 0] <= cuts[0],
                   (keel_vertices[:, 0] > cuts[0]) & (keel_vertices[:, 0] <= cuts[1]),
                   keel_vertices[:, 0] > cuts[1]):
        points = keel_vertices[region]
        keel_anchors.append(points[np.argmin(points[:, 2])].tolist())
    anchors = {'top_crystal': top_anchor.tolist(), 'facade': facade_anchor.tolist(),
               'keel_left': keel_anchors[0], 'keel_center': keel_anchors[1], 'keel_right': keel_anchors[2]}
    role_by_material = {mat.name: i for i, mat in enumerate(mesh.materials)}
    bpy.context.view_layer.objects.active = body
    body.select_set(True)
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.mesh.separate(type='MATERIAL')
    bpy.ops.object.mode_set(mode='OBJECT')
    roles, names = {}, ['cathedral_architecture', 'cathedral_top_crystal',
                        'cathedral_facade_crystal', 'cathedral_keel_crystals', 'force_trim_crest']
    recovered_positions = np.empty_like(face_geometry)
    recovered_uv = np.empty_like(source_uv)
    recovered_ids = []
    for obj in list(bpy.context.scene.objects):
        part = obj.data
        material_name = next(part.materials[p.material_index].name for p in part.polygons)
        role_index = role_by_material[material_name]
        obj.name = names[role_index]
        roles[obj.name] = materials[role_index]
        face_ids = np.empty(len(part.polygons), dtype=np.int32)
        part.attributes['anisetron_source_face'].data.foreach_get('value', face_ids)
        part_xyz = np.empty(len(part.vertices)*3, dtype=np.float32)
        part.vertices.foreach_get('co', part_xyz)
        loops = np.empty(len(part.loops), dtype=np.int32)
        part.loops.foreach_get('vertex_index', loops)
        uv = np.empty(len(part.loops)*2, dtype=np.float32)
        part.uv_layers.active.data.foreach_get('uv', uv)
        recovered_positions[face_ids] = part_xyz.reshape(-1, 3)[loops].reshape(-1, 3, 3)
        recovered_uv[face_ids] = uv.reshape(-1, 3, 2)
        recovered_ids.append(face_ids)
    recovered_ids = np.concatenate(recovered_ids)
    assert len(recovered_ids) == original_faces and np.array_equal(np.sort(recovered_ids), np.arange(original_faces))
    assert digest(recovered_positions) == prepared_geometry_hash, 'Source triangle geometry changed during separation'
    assert digest(recovered_uv) == uv_hash, 'Original face/loop UVs changed during separation'
    assert material_snapshot(source_material) == original_pbr, 'Architecture PBR changed'
    output.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(output))
    metadata = {
        'source': str(source), 'source_sha256': hashlib.sha256(source.read_bytes()).hexdigest(),
        'source_vertices': original_vertices, 'source_faces': original_faces,
        'preserved_source_faces': len(recovered_ids), 'source_geometry_sha256': source_geometry_hash,
        'prepared_triangle_geometry_sha256': prepared_geometry_hash, 'source_face_uv_sha256': uv_hash,
        'preservation': {'unique_source_face_ids': True, 'prepared_triangle_geometry_exact': True,
                         'face_uv_exact': True, 'architecture_pbr_unchanged': True,
                         'normal_transform_max_error': normal_error},
        'source_pbr': original_pbr, 'source_origin': origin.tolist(), 'prepared_yaw_degrees': 180,
        'uniform_scale': float(scale), 'projected_tiles': {'width': float(width*scale), 'height': float(height*scale)},
        'bounds_tiles': {'min': lo.tolist(), 'max': hi.tolist()}, 'roles': roles,
        'role_faces': {role: int((indices == i).sum()) for i, role in enumerate(materials)},
        'anchors': anchors, 'hover_height': 1.8, 'direction_count': count,
        'front_axis': '+Y', 'initial_angle': 0, 'native_phase': 'N rear, S facade; clockwise directions',
        'selection': {'cyan_difference': .018, 'cyan_minimum': .045, 'top_z': [.61, 1],
                      'facade_z': [.32, .64], 'keel_z': [0, .23], 'crest_center': crest_center.tolist(),
                      'crest_radius': .13, 'emission_strength': args.emission},
        'geometry_policy': 'Every original triangle/UV retained exactly after recorded uniform transform; no geometry added.'}
    output.with_suffix('.json').write_text(json.dumps(metadata, indent=2), encoding='utf-8')
    print('ANISETRON17_PREPARED ' + json.dumps(metadata))


if __name__ == '__main__':
    main()
