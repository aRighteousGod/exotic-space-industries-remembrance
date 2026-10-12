"""Source-preserving three-part rig for the selected exposed-cradle minigun."""
import argparse
import hashlib
import json
import math
import sys
from pathlib import Path

import bpy
import numpy as np
from mathutils import Matrix, Vector

REPO = Path.cwd()
parser = argparse.ArgumentParser()
parser.add_argument('--spec', default='.codex/esir/asset-generators/minigun-turret/prototype-2-rig-spec.json')
parser.add_argument('--output', default='output/meshy/minigun-prototypes/prototype-2/handoff-256/prepared')
args = parser.parse_args(sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else [])
spec = json.loads((REPO / args.spec).read_text())
output = (REPO / args.output).resolve()
output.mkdir(parents=True, exist_ok=True)
source_path = REPO / spec['source']['path']
assert hashlib.sha256(source_path.read_bytes()).hexdigest() == spec['source']['sha256']
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.preferences.filepaths.save_version = 0
bpy.ops.import_scene.gltf(filepath=str(source_path))
sources = [obj for obj in bpy.data.objects if obj.type == 'MESH']
assert len(sources) == 1
source = sources[0]
mesh = source.data
raw_world = source.matrix_world.copy()
coordinates = np.empty(len(mesh.vertices) * 3, np.float32)
mesh.vertices.foreach_get('co', coordinates)
coordinates = coordinates.reshape(-1, 3)
loop_vertices = np.empty(len(mesh.loops), np.int32)
mesh.loops.foreach_get('vertex_index', loop_vertices)
assert len(mesh.polygons) * 3 == len(mesh.loops)
triangles = loop_vertices.reshape(-1, 3)
world_matrix = np.asarray(raw_world)
world = coordinates @ world_matrix[:3, :3].T + world_matrix[:3, 3]
centers = world[triangles].mean(axis=1)
normal_data = np.empty(len(mesh.loops) * 3, np.float32)
mesh.corner_normals.foreach_get('vector', normal_data)
normal_data = normal_data.reshape(-1, 3)
uvs = {}
for uv in mesh.uv_layers:
    array = np.empty(len(mesh.loops) * 2, np.float32)
    uv.data.foreach_get('uv', array)
    uvs[uv.name] = array.reshape(-1, 2)
materials = list(mesh.materials)
material_indices = np.empty(len(mesh.polygons), np.int32)
mesh.polygons.foreach_get('material_index', material_indices)
smooth = np.empty(len(mesh.polygons), np.bool_)
mesh.polygons.foreach_get('use_smooth', smooth)

part = spec['partition']
root = np.array(part['rotor_axis_root_source'])
muzzle = np.array(part['rotor_axis_muzzle_source'])
axis = muzzle - root
axis /= np.linalg.norm(axis)
relative = centers - root
distance = np.linalg.norm(relative - np.outer(relative @ axis, axis), axis=1)
base = centers[:, 2] < part['base_centroid_z_less_than']
rotor = (~base) & (centers[:, 0] < part['rotor_centroid_x_less_than']) & (distance < part['rotor_axis_radius_less_than'])
upper = ~(base | rotor)
counts = {name: int(mask.sum()) for name, mask in [('base', base), ('upper', upper), ('rotor', rotor)]}
assert counts == part['expected_triangle_counts'], counts
loop_ids = np.arange(len(mesh.loops)).reshape(-1, 3)
records = []

def partition(name, mask):
    selected_faces = np.flatnonzero(mask)
    selected_loops = loop_ids[mask].reshape(-1)
    original_vertices = loop_vertices[selected_loops]
    used, remapped = np.unique(original_vertices, return_inverse=True)
    result = bpy.data.meshes.new(name + '_mesh')
    result.vertices.add(len(used))
    result.vertices.foreach_set('co', coordinates[used].reshape(-1))
    result.loops.add(len(remapped))
    result.loops.foreach_set('vertex_index', remapped.astype(np.int32))
    result.polygons.add(len(selected_faces))
    result.polygons.foreach_set('loop_start', np.arange(len(selected_faces), dtype=np.int32) * 3)
    result.polygons.foreach_set('loop_total', np.full(len(selected_faces), 3, np.int32))
    for material in materials:
        result.materials.append(material)
    result.polygons.foreach_set('material_index', material_indices[mask])
    result.polygons.foreach_set('use_smooth', smooth[mask])
    for uv_name, array in uvs.items():
        result.uv_layers.new(name=uv_name).data.foreach_set('uv', array[selected_loops].reshape(-1))
    result.update(calc_edges=True)
    result.normals_split_custom_set(normal_data[selected_loops])
    result.attributes.new('minigun_source_face', 'INT', 'FACE').data.foreach_set('value', selected_faces.astype(np.int32))
    actual_normals = np.empty(len(selected_loops) * 3, np.float32)
    result.corner_normals.foreach_get('vector', actual_normals)
    actual_normals = actual_normals.reshape(-1, 3)
    dots = np.clip((actual_normals * normal_data[selected_loops]).sum(axis=1), -1, 1)
    max_angle = float(np.degrees(np.arccos(dots)).max())
    assert max_angle < 0.5, (name, max_angle)
    for uv_name, array in uvs.items():
        actual_uv = np.empty(len(selected_loops) * 2, np.float32)
        result.uv_layers[uv_name].data.foreach_get('uv', actual_uv)
        assert np.array_equal(actual_uv.reshape(-1, 2), array[selected_loops])
    obj = bpy.data.objects.new(name, result)
    bpy.context.scene.collection.objects.link(obj)
    records.append({'name': name, 'source_faces': len(selected_faces), 'vertices': len(used),
                    'uvs_exact': True, 'custom_normals_max_error_degrees': max_angle,
                    'materials': [m.name for m in materials]})
    return obj

base_obj = partition('BASE_FIXED', base)
upper_obj = partition('UPPER_FIXED_TO_YAW', upper)
rotor_obj = partition('BARREL_ROTOR', rotor)
bpy.data.objects.remove(source, do_unlink=True)
for obj in list(bpy.data.objects):
    if obj.type != 'MESH':
        bpy.data.objects.remove(obj, do_unlink=True)

c = spec['coordinates']
fit = Matrix.Scale(c['uniform_scale'], 4) @ Matrix.Rotation(-math.pi / 2, 4, 'Z') @ Matrix.Translation((-c['yaw_pivot_xy_source'][0], -c['yaw_pivot_xy_source'][1], -c['ground_z_source']))
canonical_root = fit @ Vector(root)
canonical_muzzle = fit @ Vector(muzzle)
canonical_axis = (canonical_muzzle - canonical_root).normalized()
alignment = Vector((0, 0, 1)).rotation_difference(canonical_axis).to_matrix().to_4x4()

def empty(name, parent=None):
    obj = bpy.data.objects.new(name, None)
    bpy.context.scene.collection.objects.link(obj)
    obj.empty_display_type = 'ARROWS'
    obj.parent = parent
    return obj

asset_root = empty('ASSET_ROOT')
yaw = empty('YAW_PIVOT', asset_root)
yaw.rotation_mode = 'XYZ'
spin = empty('ROTOR_PIVOT', yaw)
spin.matrix_basis = Matrix.Translation(canonical_root) @ alignment
base_obj.parent = asset_root
base_obj.matrix_basis = fit @ raw_world
upper_obj.parent = yaw
upper_obj.matrix_basis = fit @ raw_world
rotor_obj.parent = spin
rotor_obj.matrix_basis = spin.matrix_basis.inverted() @ fit @ raw_world

dark = bpy.data.materials.new('internal_bearing_and_socket')
dark.use_nodes = True
shader = dark.node_tree.nodes.get('Principled BSDF')
shader.inputs['Base Color'].default_value = (0.021, 0.027, 0.025, 1)
shader.inputs['Metallic'].default_value = 0.7
shader.inputs['Roughness'].default_value = 0.44

def cylinder(name, radius, length, center, direction, parent):
    bpy.ops.mesh.primitive_cylinder_add(vertices=128, radius=radius, depth=length)
    obj = bpy.context.object
    obj.name = name
    orientation = Vector((0, 0, 1)).rotation_difference(Vector(direction)).to_matrix().to_4x4()
    obj.parent = parent
    obj.matrix_basis = fit @ Matrix.Translation(Vector(center)) @ orientation
    obj.data.materials.append(dark)
    for face in obj.data.polygons:
        face.use_smooth = abs(face.normal.z) < 0.5
    return obj

bearing = cylinder('FIXED_INTERNAL_BEARING_LINER', 0.395, 0.03,
                   (*c['yaw_pivot_xy_source'], -0.260), (0, 0, 1), asset_root)
socket = cylinder('ROTOR_INTERNAL_ROOT_HUB', 0.125, 0.03,
                  root + axis * 0.002, axis, yaw)
socket_basis = socket.matrix_basis.copy()
socket.parent = spin
socket.matrix_basis = spin.matrix_basis.inverted() @ socket_basis

# Drivers survive saving and expose only the intended two moving axes.
driver = yaw.driver_add('rotation_euler', 2).driver
driver.expression = '-2*pi*((frame-1)//16)/256'
spin.rotation_mode = 'QUATERNION'
# The local rotor is alignment * a Z-axis spin, expressed in four quaternion
# components so the saved .blend previews the full loop without a Python handler.
q = alignment.to_quaternion()
half = 'pi*((frame-1)%16)/16'
expressions = [f'{q.w!r}*cos({half})-{q.z!r}*sin({half})',
               f'{q.x!r}*cos({half})+{q.y!r}*sin({half})',
               f'{q.y!r}*cos({half})-{q.x!r}*sin({half})',
               f'{q.z!r}*cos({half})+{q.w!r}*sin({half})']
for index, expression in enumerate(expressions):
    spin.driver_add('rotation_quaternion', index).driver.expression = expression
spin['canonical_root'] = list(canonical_root)
spin['canonical_axis'] = list(canonical_axis)
spin['alignment_quaternion'] = list(alignment.to_quaternion())
spin['phase_degrees_step'] = 22.5
scene = bpy.context.scene
scene.frame_start, scene.frame_end = 1, 4096
scene.frame_set(1)
bpy.context.view_layer.update()
report = {'source_sha256': spec['source']['sha256'], 'blender_version': bpy.app.version_string,
          'parts': records, 'counts': counts, 'fit_matrix': [list(row) for row in fit],
          'canonical_rotor_root': list(canonical_root), 'canonical_muzzle': list(canonical_muzzle),
          'canonical_axis': list(canonical_axis), 'bearing_height': (-0.26 - c['ground_z_source']) * c['uniform_scale'],
          'liners': [{'name': bearing.name, 'source_radius': 0.395, 'source_z_range': [-0.275, -0.245], 'motion': 'fixed'},
                     {'name': socket.name, 'source_radius': 0.125, 'source_length': 0.03, 'motion': 'rotor'}],
          'materials': [{'name': m.name, 'images': [{'name': n.image.name, 'size': list(n.image.size),
                       'colorspace': n.image.colorspace_settings.name} for n in m.node_tree.nodes
                       if n.type == 'TEX_IMAGE' and n.image]} for m in materials],
          'status': 'rig_built_source_uv_and_corner_normals_verified_pilot_pending'}
(output / 'mechanical-split.json').write_text(json.dumps(report, indent=2) + '\n')
bpy.ops.wm.save_as_mainfile(filepath=str(output / 'minigun-prototype-2.blend'))
print('MINIGUN_RIG ' + json.dumps({'counts': counts, 'parts': records, 'saved': str(output)}), flush=True)
