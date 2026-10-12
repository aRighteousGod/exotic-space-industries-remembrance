"""Whole-model review renders through ESIR's Factorio preset; no shipping edits."""
import importlib.util
import json
import math
from pathlib import Path
import bpy
import numpy as np
from bpy_extras.object_utils import world_to_camera_view
from mathutils import Matrix, Vector

REPO = Path.cwd()
MODULE = REPO / '.codex/skills/meshy-blender-spritesheet/scripts/render_factorio_preset.py'
spec = importlib.util.spec_from_file_location('minigun_factorio_preset', MODULE)
preset = importlib.util.module_from_spec(spec)
spec.loader.exec_module(preset)
original_import, original_output = preset.import_model, preset.set_file_output_path
original_preflight, original_render = preset.preflight_report, preset.render_animation
original_place = preset.place_imported_objects
args = preset.parse_args()
output = Path(args.output_dir).resolve()
output.mkdir(parents=True, exist_ok=True)
geometry_points = {}

def import_model(path):
    imported = original_import(path)
    meshes = [obj for obj in imported if obj.type == 'MESH']
    arrays, records = [], []
    for obj in meshes:
        coords = np.empty(len(obj.data.vertices) * 3, dtype=np.float32)
        obj.data.vertices.foreach_get('co', coords)
        geometry_points[obj.name] = coords.reshape(-1, 3)
        transform = np.asarray(obj.matrix_world, dtype=np.float64)
        arrays.append(coords.reshape(-1, 3) @ transform[:3, :3].T + transform[:3, 3])
        records.append({'name': obj.name, 'vertices': len(obj.data.vertices),
                        'faces': len(obj.data.polygons), 'uv_layers': len(obj.data.uv_layers),
                        'materials': [m.name if m else None for m in obj.data.materials]})
    vertices = np.concatenate(arrays)
    low, high = vertices.min(axis=0), vertices.max(axis=0)
    cutoff = low[2] + (high[2] - low[2]) * 0.15
    foundation = vertices[vertices[:, 2] <= cutoff]
    base_low, base_high = foundation.min(axis=0), foundation.max(axis=0)
    base_size = base_high - base_low
    scale = 2.8 / max(base_size[0], base_size[1])
    center = (base_low + base_high) / 2
    fit = Matrix.Scale(float(scale), 4) @ Matrix.Translation(Vector((-center[0], -center[1], -low[2])))
    matrices = {obj.name: obj.matrix_world.copy() for obj in meshes}
    for obj in meshes:
        obj.parent = None
        obj.matrix_world = fit @ matrices[obj.name]
    for obj in imported:
        if obj.type != 'MESH':
            bpy.data.objects.remove(obj, do_unlink=True)
    bpy.context.view_layer.update()
    report = {'source': str(path), 'blender_version': bpy.app.version_string,
              'source_bounds': [low.tolist(), high.tolist()],
              'foundation_measurement': {'height_fraction': 0.15, 'cutoff_z': float(cutoff),
                  'bounds': [base_low.tolist(), base_high.tolist()], 'vertices': len(foundation)},
              'uniform_scale': float(scale), 'ground_footprint_tiles': (base_size[:2] * scale).tolist(),
              'selection_target_tiles': [3, 3], 'objects': records,
              'images': [{'name': im.name, 'size': list(im.size), 'packed': bool(im.packed_file)}
                         for im in bpy.data.images if im.type == 'IMAGE'],
              'review_boundary': 'Whole-model turntable; no mechanical separation or production wiring.'}
    (output / 'geometry-inspection.json').write_text(json.dumps(report, indent=2) + '\n')
    print('MINIGUN_GEOMETRY ' + json.dumps({k: report[k] for k in
          ['ground_footprint_tiles', 'uniform_scale', 'objects', 'images']}), flush=True)
    return meshes

def output_path(node, folder):
    # Blender 5.1 exposes directory independently of the filename prefix.
    if hasattr(node, 'directory'):
        folder.mkdir(parents=True, exist_ok=True)
        node.directory, node.file_name = str(folder), ''
    else:
        original_output(node, folder)

def place(objects, arguments, slope_parent=None):
    matrices = {obj.name: obj.matrix_world.copy() for obj in objects}
    original_place(objects, arguments, slope_parent)
    for obj in objects:
        obj.matrix_parent_inverse = Matrix.Identity(4)
        obj.matrix_basis = matrices[obj.name]
    bpy.context.view_layer.update()

def preflight(arguments, **kwargs):
    scene = preset.scene()
    scene.frame_set(1)
    report = original_preflight(arguments, **kwargs)
    poses, radius = [], 0.0
    for frame in range(1, arguments.frames + 1):
        scene.frame_set(frame)
        bpy.context.view_layer.update()
        # Actual vertices avoid the empty corners of a rotated long-barrel bbox
        # forcing excessive camera margins and unnecessarily tiny review images.
        camera = scene.camera
        corners = camera.data.view_frame(scene=scene)
        x0, x1 = min(v.x for v in corners), max(v.x for v in corners)
        y0, y1 = min(v.y for v in corners), max(v.y for v in corners)
        bounds = [1.0, 1.0, 0.0, 0.0]
        for obj in kwargs['imported']:
            if obj.type != 'MESH':
                continue
            matrix = np.asarray(camera.matrix_world.inverted() @ obj.matrix_world)
            points = geometry_points[obj.name] @ matrix[:3, :3].T + matrix[:3, 3]
            low, high = points.min(axis=0), points.max(axis=0)
            bounds = [min(bounds[0], (low[0]-x0)/(x1-x0)), min(bounds[1], (low[1]-y0)/(y1-y0)),
                      max(bounds[2], (high[0]-x0)/(x1-x0)), max(bounds[3], (high[1]-y0)/(y1-y0))]
        bounds = [float(v) for v in bounds]
        radius = max(radius, *(abs(v - 0.5) for v in bounds))
        poses.append({'frame': frame, 'projected_bounds': bounds,
                      'yaw_degrees': math.degrees(bpy.data.objects['Rotation by Frames & Directions'].rotation_euler.z)})
    margin = 0.5 - radius
    risk = margin < arguments.preflight_margin
    report['framing'].update({'all_pose_bounds': poses, 'margin_ratio': margin, 'framing_risk': risk,
        'minimum_ortho_scale': arguments.ortho_scale * radius / (0.5 - arguments.preflight_margin)})
    report['errors'] = [e for e in report['errors'] if not e.startswith('Projected asset margin')]
    if risk and arguments.fail_framing_risk:
        report['errors'].append('All-pose projected margin below configured minimum.')
    report['passed'] = not report['errors']
    scene.frame_set(1)
    return report

def render(output_dir):
    scene, poses = preset.scene(), []
    for frame in range(1, args.frames + 1):
        scene.frame_set(frame)
        yaw = math.degrees(bpy.data.objects['Rotation by Frames & Directions'].rotation_euler.z)
        expected = -args.initial_angle - (frame - 1) * 360 / args.directions
        assert abs(yaw - expected) < 0.001, (frame, yaw, expected)
        poses.append({'frame': frame, 'yaw_degrees': yaw})
    (output_dir / 'verified-frame-poses.json').write_text(json.dumps(poses, indent=2) + '\n')
    bpy.context.preferences.filepaths.save_version = 0
    original_render(output_dir)

preset.import_model, preset.set_file_output_path = import_model, output_path
preset.place_imported_objects = place
preset.preflight_report, preset.render_animation = preflight, render
preset.main()
