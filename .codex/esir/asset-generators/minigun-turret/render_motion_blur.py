"""Rotor-only physical exposure study using the retained Factorio render scene."""
import argparse
import hashlib
import importlib.util
import json
import math
import sys
import time
from pathlib import Path
from types import SimpleNamespace

import bpy
import numpy as np
from mathutils import Quaternion, Vector

REPO=Path.cwd()
ROOT=REPO/'output/meshy/minigun-prototypes/prototype-2/handoff-256'
parser=argparse.ArgumentParser()
parser.add_argument('--samples',type=int,default=256)
parser.add_argument('--output',type=Path,default=ROOT/'motion-blur')
args=parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
output=args.output.resolve()
output.mkdir(parents=True,exist_ok=True)
rig=json.loads((ROOT/'prepared/mechanical-split.json').read_text())
source=REPO/'output/meshy/minigun-prototypes/prototype-2/source/model.glb'
assert hashlib.sha256(source.read_bytes()).hexdigest()==rig['source_sha256']
scene_path=ROOT/'prepared/minigun-render-scene.blend'
bpy.ops.wm.open_mainfile(filepath=str(scene_path))
scene=bpy.context.scene
module_path=REPO/'.codex/skills/meshy-blender-spritesheet/scripts/render_factorio_preset.py'
spec=importlib.util.spec_from_file_location('minigun_blur_preset',module_path)
preset=importlib.util.module_from_spec(spec)
spec.loader.exec_module(preset)
device=preset.configure_cycles_device(SimpleNamespace(cycles_compute_device='auto',cycles_include_cpu=False),scene)
scene.cycles.samples=args.samples
scene.cycles.seed=0
scene.cycles.use_animated_seed=False
scene.render.use_persistent_data=True
scene.render.use_motion_blur=True
scene.render.motion_blur_shutter=1.0
scene.render.motion_blur_position='CENTER'
scene.frame_start,scene.frame_end=99,101
assert (scene.render.resolution_x,scene.render.resolution_y)==(540,540)
# Freeze the checked preflight camera instead of relying on the embedded
# preset's unregistered RNA property when reopening with scripts disabled.
preflight=json.loads((ROOT/'preflight/preflight.json').read_text())
scene.camera.data.animation_data_clear()
scene.camera.data.ortho_scale=preflight['camera_ortho']
assert abs(scene.camera.data.ortho_scale-8.4375)<1e-6
scene.frame_set(1)
bpy.context.window.view_layer=scene.view_layers['Object']
bpy.context.view_layer.update()

yaw=bpy.data.objects['YAW_PIVOT']
spin=bpy.data.objects['ROTOR_PIVOT']
yaw.animation_data_clear()
spin.animation_data_clear()
alignment=Quaternion(spin['alignment_quaternion'])
moving={'BARREL_ROTOR','ROTOR_INTERNAL_ROOT_HUB'}
for obj in scene.objects:
    obj.cycles.use_motion_blur=obj.name in moving
    if obj.name in moving:
        obj.cycles.use_deform_motion=False
        obj.cycles.motion_steps=5
rotator=bpy.data.objects.get('Rotation by Frames & Directions')
if rotator:
    rotator.animation_data_clear()
    rotator.rotation_euler=(0,0,0)
for layer in scene.view_layers:
    layer.use=layer.name in ('Object','Shadow')
    layer.use_motion_blur=True
tree=preset.compositor_tree(scene)
nodes={node.label or node.name:node for node in tree.nodes if node.bl_idname=='CompositorNodeOutputFile'}
for node in nodes.values():
    node.format.file_format='PNG'
    node.format.color_mode='RGBA'
    node.format.color_depth='8'
    node.mute=True
for node in tree.nodes:
    if node.bl_idname in ('CompositorNodeComposite','CompositorNodeViewer'):
        node.mute=True
scene.render.use_compositing=True
scene.render.use_file_extension=True

def pose(direction,sweep):
    yaw.rotation_euler=(0,0,-2*math.pi*direction/256)
    half=f'({math.radians(sweep)/2!r})*(frame-100)'
    expressions=[f'{alignment.w!r}*cos({half})-{alignment.z!r}*sin({half})',
                 f'{alignment.x!r}*cos({half})+{alignment.y!r}*sin({half})',
                 f'{alignment.y!r}*cos({half})-{alignment.x!r}*sin({half})',
                 f'{alignment.z!r}*cos({half})+{alignment.w!r}*sin({half})']
    spin.animation_data_clear()
    for index,expression in enumerate(expressions):
        spin.driver_add('rotation_quaternion',index).driver.expression=expression
    scene.frame_set(100)
    bpy.context.view_layer.update()

def frame_at(value):
    whole=math.floor(value)
    scene.frame_set(whole,subframe=value-whole)
    bpy.context.view_layer.update()

def prove(direction,sweep):
    pose(direction,sweep)
    names=['BASE_FIXED','FIXED_INTERNAL_BEARING_LINER','UPPER_FIXED_TO_YAW','YAW_PIVOT',scene.camera.name]
    names+= [obj.name for obj in scene.objects if obj.type=='LIGHT']
    reference={name:np.asarray(bpy.data.objects[name].matrix_world).copy() for name in names}
    center=np.asarray(spin.matrix_world.translation).copy()
    axis=np.asarray(spin.matrix_world.to_quaternion()@Vector((0,0,1))).copy()
    max_static,max_root,max_axis,max_rotation=0.0,0.0,0.0,0.0
    for delta in (-.5,-.375,-.25,-.125,0,.125,.25,.375,.5):
        frame_at(100+delta)
        max_static=max(max_static,max(float(np.abs(np.asarray(bpy.data.objects[n].matrix_world)-m).max()) for n,m in reference.items()))
        max_root=max(max_root,float(np.abs(np.asarray(spin.matrix_world.translation)-center).max()))
        max_axis=max(max_axis,float(np.abs(np.asarray(spin.matrix_world.to_quaternion()@Vector((0,0,1)))-axis).max()))
        expected=alignment@Quaternion((0,0,1),math.radians(sweep)*delta)
        # Packed Blender quaternions have small angular float error; compare components after sign alignment.
        actual=spin.rotation_quaternion.copy()
        if actual.dot(expected)<0:actual.negate()
        max_rotation=max(max_rotation,max(abs(a-b) for a,b in zip(actual,expected)))
    assert max_static<1e-6 and max_root<1e-6 and max_axis<1e-6 and max_rotation<1e-6
    frame_at(100)
    return {'direction':direction,'sweep_degrees':sweep,'subframe_samples':9,
            'view_layer':bpy.context.view_layer.name,
            'stationary_matrix_error':max_static,'rotor_root_error':max_root,
            'rotor_axis_error':max_axis,'rotor_quaternion_error':max_rotation}

proofs=[]
for label in ('Object','Shadow'):
    bpy.context.window.view_layer=scene.view_layers[label]
    bpy.context.view_layer.update()
    proofs.extend(prove(d,s) for s in (36,90,180) for d in (0,32,64,96,128,160,192,224))
bpy.context.window.view_layer=scene.view_layers['Object']
bpy.context.view_layer.update()
configuration={'schema':'esir.minigun.motion-blur.v1','source_sha256':rig['source_sha256'],
    'scene_sha256':hashlib.sha256(scene_path.read_bytes()).hexdigest(),
    'script_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
    'samples':args.samples,'blender':bpy.app.version_string,'device':device,
    'resolution':[540,540],'density':64,'ortho':scene.camera.data.ortho_scale,
    'camera_matrix':[list(row) for row in scene.camera.matrix_world],
    'shutter_frames':1,'shutter_position':'CENTER','center_frame':100,'center_phase_degrees':0,
    'rotor_motion_steps':5,'deformation_blur':False,'moving_meshes':sorted(moving),
    'view_layer_motion_blur':{label:scene.view_layers[label].use_motion_blur for label in ('Object','Shadow')},
    'seed':0,'animated_seed':False,'pose_proofs':proofs,'production_promoted':False}
config_hash=hashlib.sha256(json.dumps(configuration,sort_keys=True).encode()).hexdigest()
(output/'configuration.json').write_text(json.dumps({'hash':config_hash,**configuration},indent=2)+'\n')
records=[]
views=(0,32,64,96,128,160,192,224)
jobs=[('sharp',0,d) for d in views]+[('firing',90,d) for d in views]+[('restrained',36,32),('heavy',180,32)]

def pass_setup(label,folder,direction):
    for layer in scene.view_layers:layer.use=layer.name==label
    for name,node in nodes.items():
        node.mute=name!=label
        if name==label:
            folder.mkdir(parents=True,exist_ok=True)
            node.directory=str(folder)
            node.file_name=f'd{direction:03}'
    bpy.context.window.view_layer=scene.view_layers[label]
    bpy.context.view_layer.update()

for label in ('Object','Shadow'):
    for variant,sweep,direction in jobs:
        pose(direction,sweep)
        scene.render.use_motion_blur=sweep>0
        pass_setup(label,output/variant/label,direction)
        if label=='Object' and variant=='firing' and direction==32:
            bpy.context.preferences.filepaths.save_version=0
            bpy.ops.wm.save_as_mainfile(filepath=str(output/'minigun-motion-blur.blend'))
        started=time.monotonic()
        bpy.ops.render.render(write_still=False)
        path=output/variant/label/f'd{direction:03}.png'
        assert path.exists(),path
        image=bpy.data.images.load(str(path),check_existing=False)
        assert list(image.size)==[540,540]
        pixels=np.empty(540*540*4,np.float32)
        image.pixels.foreach_get(pixels)
        y,x=np.where(pixels.reshape(540,540,4)[:,:,3]>1/255)
        assert len(x)
        bounds=[int(x.min()),int(539-y.max()),int(x.max()+1),int(540-y.min())]
        margin=min(bounds[0],bounds[1],540-bounds[2],540-bounds[3])
        assert margin>=8,(variant,label,direction,bounds)
        bpy.data.images.remove(image)
        record={'variant':variant,'sweep_degrees':sweep,'direction':direction,'pass':label,
                'configuration_hash':config_hash,'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),
                'seconds':time.monotonic()-started,'alpha_bounds':bounds,'margin':margin,
                'path':str(path.relative_to(output)).replace('\\','/')}
        records.append(record)
        (output/'frames.json').write_text(json.dumps(records,indent=2)+'\n')
        print('BLUR_FRAME '+json.dumps(record),flush=True)
print('MOTION_BLUR_COMPLETE '+str(output),flush=True)
