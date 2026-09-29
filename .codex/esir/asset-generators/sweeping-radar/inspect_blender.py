"""Inspect imported radar world coordinates, UVs and PBR images in isolated Blender."""
import argparse
import json
import sys
from pathlib import Path
import bpy
import numpy as np
from mathutils import Vector

parser = argparse.ArgumentParser()
parser.add_argument('--input', type=Path, required=True)
parser.add_argument('--output', type=Path, required=True)
args = parser.parse_args(sys.argv[sys.argv.index('--')+1:])
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(args.input.resolve()))
report = dict(blender=bpy.app.version_string, source=str(args.input.resolve()), objects=[], images=[])
for obj in bpy.data.objects:
    if obj.type != 'MESH':
        continue
    bounds = np.array([obj.matrix_world @ Vector(v) for v in obj.bound_box])
    vertices = np.empty(len(obj.data.vertices)*3, dtype=np.float32)
    obj.data.vertices.foreach_get('co', vertices)
    vertices = vertices.reshape((-1, 3))
    transform = np.array(obj.matrix_world)
    world = vertices @ transform[:3, :3].T + transform[:3, 3]
    histogram, edges = np.histogram(world[:,2], bins=50)
    report['objects'].append(dict(name=obj.name, vertices=len(obj.data.vertices), faces=len(obj.data.polygons),
                                 matrix=np.array(obj.matrix_world).tolist(), minimum=bounds.min(axis=0).tolist(),
                                 maximum=bounds.max(axis=0).tolist(), uv_layers=[uv.name for uv in obj.data.uv_layers],
                                 materials=[m.name if m else None for m in obj.data.materials],
                                 height_slices=[dict(low=float(edges[i]), high=float(edges[i+1]), count=int(n)) for i,n in enumerate(histogram)]))
for image in bpy.data.images:
    if image.type == 'IMAGE':
        report['images'].append(dict(name=image.name, size=list(image.size), channels=image.channels))
args.output.mkdir(parents=True, exist_ok=True)
(args.output/'inspection.json').write_text(json.dumps(report, indent=2)+'\n', encoding='utf-8')
bpy.ops.wm.save_as_mainfile(filepath=str((args.output/'inspection.blend').resolve()))
print(json.dumps(report, indent=2))
