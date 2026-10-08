"""Independently compare imported normals with prepared source-face-ordered normals."""
import argparse
import json
from pathlib import Path
import sys

import bpy
import numpy as np

parser = argparse.ArgumentParser()
parser.add_argument('--source', required=True, type=Path)
parser.add_argument('--prepared', required=True, type=Path)
parser.add_argument('--output', required=True, type=Path)
args = parser.parse_args(sys.argv[sys.argv.index('--')+1:])
bpy.ops.wm.open_mainfile(filepath=str(args.prepared.resolve()))
metadata = json.loads(args.prepared.with_suffix('.json').read_text())
normals = np.empty((metadata['source_faces'], 3, 3), dtype=np.float32)
for obj in bpy.context.scene.objects:
    mesh = obj.data
    ids = np.empty(len(mesh.polygons), dtype=np.int32)
    mesh.attributes['anisetron_source_face'].data.foreach_get('value', ids)
    data = np.empty(len(mesh.corner_normals)*3, dtype=np.float32)
    mesh.corner_normals.foreach_get('vector', data)
    normals[ids] = data.reshape(-1, 3, 3)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(args.source.resolve()))
body = next(obj for obj in bpy.context.scene.objects if obj.type == 'MESH')
body.data.transform(body.matrix_world)
expected = np.empty(len(body.data.corner_normals)*3, dtype=np.float32)
body.data.corner_normals.foreach_get('vector', expected)
expected = expected.reshape(-1, 3, 3)
expected[:, :, :2] *= -1
errors = np.abs(normals-expected)
maximum = float(errors.max())
a, b = normals.reshape(-1, 3).astype(np.float64), expected.reshape(-1, 3).astype(np.float64)
a /= np.maximum(np.linalg.norm(a, axis=1, keepdims=True), 1e-12)
b /= np.maximum(np.linalg.norm(b, axis=1, keepdims=True), 1e-12)
angles = np.degrees(np.arccos(np.clip(np.sum(a*b, axis=1), -1, 1)))
maximum_angle = float(angles.max())
# Blender encodes split normals again during material separation. Preserve their
# orientation within sub-degree packing precision rather than claiming bit identity.
report = {'pass': maximum_angle < .5, 'maximum_component_error': maximum,
          'maximum_angle_degrees': maximum_angle,
          'p99_component_error': float(np.quantile(errors, .99)),
          'source_faces': len(normals), 'original_normal_orientation_preserved': maximum_angle < .5,
          'scope': 'Source triangle-corner normal direction through world flatten, uniform scale,180 yaw and role separation.'}
args.output.write_text(json.dumps(report, indent=2), encoding='utf-8')
print('ANISETRON17_NORMAL_QC ' + json.dumps(report))
assert report['pass'], 'Imported shading-normal orientation changed'
