"""Preset renderer for the rigged minigun; resumable global d/p frame indices."""
import argparse
import hashlib
import importlib.util
import json
import math
import sys
import time
from pathlib import Path

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector

REPO = Path.cwd()
ROOT = REPO / 'output/meshy/minigun-prototypes/prototype-2/handoff-256'
parser = argparse.ArgumentParser()
parser.add_argument('--mode', choices=['preflight', 'pilot', 'production', 'benchmark'], default='preflight')
parser.add_argument('--samples', type=int)
parser.add_argument('--output', type=Path)
parser.add_argument('--start-direction', type=int, default=0)
parser.add_argument('--end-direction', type=int, default=256)
args = parser.parse_args(sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else [])
args.samples = args.samples or (256 if args.mode in ('production', 'benchmark') else 64)
if args.mode == 'production':
    gate = json.loads((ROOT / 'qa-summary.json').read_text())
    assert gate['production_gate'] == 'passed', gate['blocker']
    assert args.samples == 256, 'Production contract requires 256 samples'
    assert 0 <= args.start_direction < args.end_direction <= 256
    assert args.start_direction % 16 == args.end_direction % 16 == 0
output = args.output or ROOT / args.mode
output.mkdir(parents=True, exist_ok=True)
module_path = REPO / '.codex/skills/meshy-blender-spritesheet/scripts/render_factorio_preset.py'
module_spec = importlib.util.spec_from_file_location('minigun_preset', module_path)
preset = importlib.util.module_from_spec(module_spec)
module_spec.loader.exec_module(preset)
saved_argv = sys.argv
sys.argv = [str(module_path), '--preset-blend', str(REPO / 'factorioRenderingPreset_v4.blend'),
            '--asset-name', 'minigun-prototype-2', '--output-dir', str(output),
            '--input', str(ROOT / 'prepared/minigun-prototype-2.blend'), '--no-normalize',
            '--no-parent-to-rotation', '--frames', '4096', '--directions', '256',
            '--animation-frames', '16', '--initial-angle', '0', '--ortho-scale', '8.4375',
            '--resolution', '540', '--tile-size', '64', '--samples', str(args.samples),
            '--passes', 'object,shadow', '--cycles-compute-device', 'auto', '--persistent-data']
settings = preset.parse_args()
sys.argv = saved_argv
bpy.ops.wm.open_mainfile(filepath=str(REPO / 'factorioRenderingPreset_v4.blend'))
preset.clear_preset_examples(settings)
with bpy.data.libraries.load(str(ROOT / 'prepared/minigun-prototype-2.blend'), link=False) as (available, imported):
    imported.objects = available.objects
normal_collection = bpy.data.collections.get('Normal')
assert normal_collection is not None
for obj in imported.objects:
    if obj:
        normal_collection.objects.link(obj)
scene = preset.scene()
bpy.context.window.scene = scene
scene['frames'] = 16
scene['dir'] = 256
preset.add_unit_driver(settings)
scene.frame_set(1)
bpy.context.view_layer.update()

def output_path(node, folder):
    folder.mkdir(parents=True, exist_ok=True)
    if hasattr(node, 'directory'):
        node.directory, node.file_name = str(folder), ''
    else:
        node.base_path = str(folder)

preset.set_file_output_path = output_path
scene_record = preset.setup_scene(settings, ['object', 'shadow'], output)
preset.apply_preset_lighting_adjustments(settings)
scene.cycles.seed = 0
scene.cycles.use_animated_seed = False
tree = preset.compositor_tree(scene)
file_nodes = {node.label or node.name: node for node in tree.nodes if node.bl_idname == 'CompositorNodeOutputFile'}
for node in file_nodes.values():
    node.format.file_format = 'PNG'
    node.format.color_mode = 'RGBA'
    node.format.color_depth = '8'
for layer in scene.view_layers:
    layer.use = layer.name in ('Object', 'Shadow')
for node in tree.nodes:
    if node.bl_idname in ('CompositorNodeComposite', 'CompositorNodeViewer'):
        node.mute = True
scene.render.use_file_extension = True
scene.render.use_compositing = True
bpy.context.view_layer.update()

def points(obj):
    array = np.empty(len(obj.data.vertices) * 3, np.float32)
    obj.data.vertices.foreach_get('co', array)
    matrix = np.asarray(obj.matrix_world)
    return array.reshape(-1, 3) @ matrix[:3, :3].T + matrix[:3, 3]

groups = {'base': ['BASE_FIXED', 'FIXED_INTERNAL_BEARING_LINER'],
          'upper': ['UPPER_FIXED_TO_YAW'], 'rotor': ['BARREL_ROTOR', 'ROTOR_INTERNAL_ROOT_HUB']}
neutral = {name: np.concatenate([points(bpy.data.objects[obj]) for obj in names]) for name, names in groups.items()}

def hull(array):
    temporary = bpy.data.meshes.new('temporary_support_hull')
    temporary.vertices.add(len(array))
    temporary.vertices.foreach_set('co', array.astype(np.float32).reshape(-1))
    bm = bmesh.new()
    bm.from_mesh(temporary)
    result = bmesh.ops.convex_hull(bm, input=list(bm.verts), use_existing_faces=False)
    vertices = set(v for face in result['geom'] if isinstance(face, bmesh.types.BMFace) for v in face.verts)
    assert vertices
    array = np.array([tuple(v.co) for v in vertices], dtype=np.float64)
    bm.free()
    bpy.data.meshes.remove(temporary)
    return array

support = {name: hull(array) for name, array in neutral.items()}
rig = json.loads((ROOT / 'prepared/mechanical-split.json').read_text())
root = np.array(rig['canonical_rotor_root'])
axis = Vector(rig['canonical_axis'])

def transform(direction, phase):
    yaw = np.asarray(Matrix.Rotation(-2 * math.pi * direction / 256, 3, 'Z'))
    spin = np.asarray(Matrix.Rotation(2 * math.pi * phase / 16, 3, axis))
    return {'base': (np.eye(3), np.zeros(3)), 'upper': (yaw, np.zeros(3)),
            'rotor': (yaw @ spin, yaw @ (root - spin @ root))}

def camera_bounds():
    frame = scene.camera.data.view_frame(scene=scene)
    return min(v.x for v in frame), max(v.x for v in frame), min(v.y for v in frame), max(v.y for v in frame)

def project(array, matrix=None):
    camera = np.asarray(scene.camera.matrix_world.inverted())
    array = array if matrix is None else array @ matrix.T
    xy = array @ camera[:2, :3].T + camera[:2, 3]
    x0, x1, y0, y1 = camera_bounds()
    return np.column_stack(((xy[:, 0]-x0)/(x1-x0)*scene.render.resolution_x,
                            (y1-xy[:, 1])/(y1-y0)*scene.render.resolution_y))

bpy.context.window.view_layer = scene.view_layers['Shadow']
bpy.context.view_layer.update()
lamp = bpy.data.objects['Shadow Lamp'].evaluated_get(bpy.context.evaluated_depsgraph_get())
light = np.array(lamp.matrix_world.to_quaternion() @ Vector((0, 0, -1)))
bpy.context.window.view_layer = scene.view_layers['Object']
bpy.context.view_layer.update()
assert light[2] < 0
ground = np.eye(3)
ground[:, 2] -= light / light[2]
all_bounds, all_shadow_bounds = [], []
for direction in range(256):
    for phase in range(16):
        matrices = transform(direction, phase)
        world = np.concatenate([array @ matrices[name][0].T + matrices[name][1] for name, array in support.items()])
        image = project(world)
        all_bounds.append([*image.min(axis=0), *image.max(axis=0)])
        shadow_image = project(world, ground)
        all_shadow_bounds.append([*shadow_image.min(axis=0), *shadow_image.max(axis=0)])
all_bounds = np.asarray(all_bounds)
all_shadow_bounds = np.asarray(all_shadow_bounds)
union = np.array([*all_bounds[:, :2].min(axis=0), *all_bounds[:, 2:].max(axis=0)])
shadow_union = np.array([*all_shadow_bounds[:, :2].min(axis=0), *all_shadow_bounds[:, 2:].max(axis=0)])

# Check actual driver matrices and full vertices, independently of hull formulas.
matrix_errors, bounds_errors = [], []
base_reference = np.asarray(bpy.data.objects['BASE_FIXED'].matrix_world).copy()
for direction, phase in [(0, 0), (0, 15), (1, 1), (32, 8), (64, 15), (255, 1)]:
    scene.frame_set(1 + direction * 16 + phase)
    bpy.context.view_layer.update()
    matrix_errors.append(float(np.abs(np.asarray(bpy.data.objects['BASE_FIXED'].matrix_world) - base_reference).max()))
    actual = np.concatenate([points(bpy.data.objects[obj]) for names in groups.values() for obj in names])
    px = project(actual)
    actual_bound = np.array([*px.min(axis=0), *px.max(axis=0)])
    bounds_errors.append(float(np.abs(actual_bound - all_bounds[direction * 16 + phase]).max()))
assert max(matrix_errors) < 1e-6
assert max(bounds_errors) < 0.01, bounds_errors
scene.frame_set(1)
bpy.context.view_layer.update()
camera_anchor = project(np.zeros((1, 3)))[0]
margin = min(union[0], union[1], 540-union[2], 540-union[3], shadow_union[0], shadow_union[1], 540-shadow_union[2], 540-shadow_union[3])
assert margin >= 12, (union, shadow_union, margin)
preflight = {'status': 'passed', 'poses_checked': 4096, 'color_pixel_bounds': union.tolist(),
             'hard_shadow_pixel_bounds': shadow_union.tolist(), 'minimum_master_margin_pixels': float(margin),
             'neutral_support_vertices': {k: len(v) for k, v in support.items()},
             'full_vertex_bounds_max_error_pixels': max(bounds_errors), 'fixed_base_matrix_max_error': max(matrix_errors),
             'ground_anchor_pixels': camera_anchor.tolist(), 'pixels_per_tile': 64,
             'camera_ortho': scene.camera.data.ortho_scale, 'resolution': [540, 540],
             'shadow_light_evaluated_vector': light.tolist(), 'source_sha256': rig['source_sha256']}
(output / 'preflight.json').write_text(json.dumps(preflight, indent=2) + '\n')
np.savez_compressed(output / 'all-pose-bounds.npz', color=all_bounds, shadow=all_shadow_bounds)
muzzle = np.array(rig['canonical_muzzle'])
anchors = []
for direction in range(256):
    yaw = np.asarray(Matrix.Rotation(-2*math.pi*direction/256, 3, 'Z'))
    world = yaw @ muzzle
    pixel = project(world[None, :])[0]
    anchors.append({'direction':direction,'orientation':direction/256,
                    'world':world.tolist(),'master_pixels':pixel.tolist(),
                    'visual_offset_tiles':((pixel-camera_anchor)/64).tolist()})
creation = []
for index in range(256):
    angle = 2*math.pi*index/256
    mapped = (math.atan2(math.sqrt(2)*math.sin(angle),math.cos(angle))/(2*math.pi))%1
    frame = mapped*256
    lower = int(frame)
    offset = np.array(anchors[lower]['visual_offset_tiles'])*(1-frame+lower)+np.array(anchors[(lower+1)%256]['visual_offset_tiles'])*(frame-lower)
    creation.append({'orientation':index/256,'visual_offset_tiles':offset.tolist(),
                     'candidate_with_one_tile_effect_height':(offset+[0,1]).tolist()})
(ROOT / 'muzzle-anchors.json').write_text(json.dumps({'status':'geometry_proposal_not_native_calibrated',
    'source_sha256':rig['source_sha256'],'ground_anchor_pixels':camera_anchor.tolist(),
    'height_compensation_verified':False,'candidate_effect_height_tiles':1,
    'native_lookup_remap':'atan2(sqrt(2)*sin(angle),cos(angle)) / (2*pi) mod 1',
    'visual_anchors':anchors,'creation_map_proposal':creation},indent=2)+'\n')
bpy.context.preferences.filepaths.save_version = 0
if args.mode == 'preflight':
    bpy.ops.wm.save_as_mainfile(filepath=str(ROOT / 'prepared/minigun-render-scene.blend'))
    print('PREFLIGHT ' + json.dumps(preflight), flush=True)


def execute_render_job():
    configuration = {'rig_sha256': hashlib.sha256((ROOT / 'prepared/minigun-prototype-2.blend').read_bytes()).hexdigest(),
                     'script_sha256': hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
                     'preset_sha256': hashlib.sha256((REPO / 'factorioRenderingPreset_v4.blend').read_bytes()).hexdigest(),
                     'samples': args.samples, 'blender': bpy.app.version_string, 'density': 64,
                     'scene': scene_record, 'seed': 0, 'animated_seed': False}
    config_hash = hashlib.sha256(json.dumps(configuration, sort_keys=True).encode()).hexdigest()
    (output / 'configuration.json').write_text(json.dumps({'hash': config_hash, **configuration}, indent=2) + '\n')
    journal_path = output / 'frames.jsonl'
    previous = {}
    if journal_path.exists():
        lines = journal_path.read_text().splitlines()
        for index, line in enumerate(lines):
            try:
                record = json.loads(line)
            except json.JSONDecodeError:
                if index != len(lines)-1:
                    raise
                journal_path.write_text('\n'.join(lines[:index]) + '\n')
                break
            if record['configuration_hash'] == config_hash:
                previous[(record['pass'], record['frame'])] = record

    def passes(selected):
        for layer in scene.view_layers:
            layer.use = layer.name == selected
        for label, node in file_nodes.items():
            node.mute = label != selected
            if label == selected:
                output_path(node, output / selected)
        bpy.context.window.view_layer = scene.view_layers[selected]
        bpy.context.view_layer.update()

    def render(selected, frame):
        path = output / selected / f'{frame:04}.png'
        old = previous.get((selected, frame))
        if old and path.exists() and hashlib.sha256(path.read_bytes()).hexdigest() == old['sha256']:
            return
        scene.frame_set(frame)
        bpy.context.view_layer.update()
        if hasattr(file_nodes[selected], 'file_name'):
            file_nodes[selected].file_name = f'{frame:04}'
        started = time.monotonic()
        bpy.ops.render.render(write_still=False)
        assert path.exists(), path
        image = bpy.data.images.load(str(path), check_existing=False)
        assert list(image.size) == [540, 540]
        pixels = np.empty(540 * 540 * 4, np.float32)
        image.pixels.foreach_get(pixels)
        alpha = pixels.reshape(540, 540, 4)[:, :, 3]
        y, x = np.where(alpha > 1/255)
        assert len(x)
        # Blender pixel buffers have lower-left origins; the recorded PNG bounds use top-left.
        bound = [int(x.min()), int(539-y.max()), int(x.max()+1), int(540-y.min())]
        assert min(bound[0], bound[1], 540-bound[2], 540-bound[3]) >= 8, (selected, frame, bound)
        bpy.data.images.remove(image)
        record = {'pass': selected, 'frame': frame, 'direction': (frame-1)//16, 'phase': (frame-1)%16,
                  'configuration_hash': config_hash, 'sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
                  'seconds': time.monotonic()-started, 'alpha_bounds': bound}
        with journal_path.open('a') as handle:
            handle.write(json.dumps(record) + '\n')
        print('FRAME ' + json.dumps(record), flush=True)

    if args.mode in ('pilot', 'benchmark'):
        poses = [(32, p) for p in range(16)] + [(d, 0) for d in (0, 64, 96, 128, 160, 192, 224)]
        if args.mode == 'benchmark':
            poses = [(32, p) for p in (0, 1, 2, 3)]
        passes('Object')
        for direction, phase in poses:
            render('Object', 1+16*direction+phase)
        passes('Shadow')
        shadows = poses + [(d,p) for d in (64,192) for p in (4,8,12)] if args.mode == 'pilot' else [(32,0)]
        for direction, phase in shadows:
            render('Shadow', 1+16*direction+phase)
    else:
        for start in range(args.start_direction, args.end_direction, 16):
            end = min(start+16, args.end_direction)
            passes('Object')
            for direction in range(start, end):
                for phase in range(16):render('Object', 1+16*direction+phase)
            passes('Shadow')
            for direction in range(start, end):render('Shadow', 1+16*direction)
            (output / f'chunk-{start//16:02}.complete.json').write_text(json.dumps({'configuration_hash':config_hash,'directions':[start,end-1],'beauty':(end-start)*16,'shadows':end-start})+'\n')
            print(f'CHUNK_COMPLETE {start//16}', flush=True)
    print('RENDER_COMPLETE ' + str(output), flush=True)

if args.mode != 'preflight':
    execute_render_job()
