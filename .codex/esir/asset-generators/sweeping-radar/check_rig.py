"""Validate saved radar transforms, original triangle preservation and footprint."""
import argparse
import hashlib
import json
import sys
from pathlib import Path
import bpy
import numpy as np

parser=argparse.ArgumentParser()
parser.add_argument('--asset',required=True)
args=parser.parse_args(sys.argv[sys.argv.index('--')+1:])
root=Path.cwd()/'output/meshy'/args.asset
bpy.ops.wm.open_mainfile(filepath=str(root/'prepared'/(args.asset+'.blend')))
report=json.loads((root/'prepared/mechanical-split.json').read_text())
scene=bpy.context.scene
scene.frame_set(1)
fixed={name:np.array(bpy.data.objects[name].matrix_world) for name in report['fixed_objects']}
moving={name:np.array(bpy.data.objects[name].matrix_world) for name in report['rotating_objects']}
checks=[]
for frame in [1,9,17,25,33,41,49,57,65]:
    scene.frame_set(frame)
    fixed_ok=all(np.allclose(np.array(bpy.data.objects[name].matrix_world),matrix,atol=1e-6) for name,matrix in fixed.items())
    changed=all(not np.allclose(np.array(bpy.data.objects[name].matrix_world),matrix,atol=1e-6) for name,matrix in moving.items())
    loop_ok=all(np.allclose(np.array(bpy.data.objects[name].matrix_world),matrix,atol=1e-5) for name,matrix in moving.items()) if frame==65 else True
    checks.append(dict(frame=frame,fixed_base_unchanged=fixed_ok,rotor_changes=changed if frame not in (1,65) else None,loop_closes=loop_ok))
scene.frame_set(1)
source_faces=sum(len(bpy.data.objects[name].data.polygons) for name in ['fixed_wired_base','rotor_upper_assembly'])
uv_ok=all(bpy.data.objects[name].data.uv_layers.active is not None for name in ['fixed_wired_base','rotor_upper_assembly'])
all_pass=all(c['fixed_base_unchanged'] and c['loop_closes'] and c['rotor_changes'] is not False for c in checks)
all_pass=all_pass and source_faces==report['source_faces'] and uv_ok and report['rotor_swept_radius_tiles']<=1.400001
result=dict(asset=args.asset,all_pass=all_pass,checks=checks,original_triangles=report['source_faces'],
            retained_triangles=source_faces,original_uvs_present=uv_ok,rotor_swept_radius=report['rotor_swept_radius_tiles'],
            limits='Transform, footprint and UV checks only. Mechanical seam and glow appearance require rendered review.')
(root/'prepared/rig-checks.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(result,indent=2))
assert all_pass
