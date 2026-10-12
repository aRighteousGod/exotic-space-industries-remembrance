"""Sharp d096 icon master from the approved rig, with measured framing."""
import argparse, hashlib, importlib.util, json, math, sys
from pathlib import Path
from types import SimpleNamespace
import bpy
import numpy as np
from mathutils import Quaternion, Vector

REPO=Path.cwd()
ROOT=REPO/'output/meshy/minigun-prototypes/prototype-2/handoff-256'
parser=argparse.ArgumentParser()
parser.add_argument('--output',type=Path,default=ROOT/'separated-v2-icons')
args=parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
output=args.output.resolve();output.mkdir(parents=True,exist_ok=True)
source=ROOT.parent/'source/model.glb'
source_hash=hashlib.sha256(source.read_bytes()).hexdigest()
assert source_hash=='453a8f5b75fd16630803d698293222cf9e07a3e1cecb1f7c3b40434d75008f59'
scene_path=ROOT/'prepared/minigun-render-scene.blend'
bpy.ops.wm.open_mainfile(filepath=str(scene_path));scene=bpy.context.scene
spec=importlib.util.spec_from_file_location('icon_preset',REPO/'.codex/skills/meshy-blender-spritesheet/scripts/render_factorio_preset.py')
preset=importlib.util.module_from_spec(spec);spec.loader.exec_module(preset)
device=preset.configure_cycles_device(SimpleNamespace(cycles_compute_device='auto',cycles_include_cpu=False),scene)
scene.cycles.samples=256;scene.cycles.seed=0;scene.cycles.use_animated_seed=False
scene.render.use_motion_blur=False
scene.camera.data.animation_data_clear();scene.camera.data.ortho_scale=8.4375
rotator=bpy.data.objects.get('Rotation by Frames & Directions')
if rotator: rotator.animation_data_clear();rotator.rotation_euler=(0,0,0)
yaw=bpy.data.objects['YAW_PIVOT'];yaw.animation_data_clear();yaw.rotation_euler=(0,0,-math.tau*96/256)
spin=bpy.data.objects['ROTOR_PIVOT'];spin.animation_data_clear()
spin.rotation_quaternion=Quaternion(spin['alignment_quaternion'])
bpy.context.window.view_layer=scene.view_layers['Object'];scene.frame_set(100);bpy.context.view_layer.update()
# The approved sharp d096 reference supplies the silhouette envelope. Camera
# translation stays in its view plane, so the presentation angle is unchanged.
reference=ROOT/'motion-blur/sharp/Object/d096.png'
im=bpy.data.images.load(str(reference),check_existing=False)
rgba=np.empty(540*540*4,np.float32);im.pixels.foreach_get(rgba)
yy,xx=np.where(rgba.reshape(540,540,4)[:,:,3]>0)
assert len(xx);bounds=[int(xx.min()),int(539-yy.max()),int(xx.max()+1),int(540-yy.min())]
bpy.data.images.remove(im)
cx=(bounds[0]+bounds[2])/2;cy=(bounds[1]+bounds[3])/2
right=scene.camera.matrix_world.to_quaternion()@Vector((1,0,0))
up=scene.camera.matrix_world.to_quaternion()@Vector((0,1,0))
scene.camera.location += right*((cx-270)/64)+up*((270-cy)/64)
scene.camera.data.ortho_scale=max(bounds[2]-bounds[0],bounds[3]-bounds[1])/64/.84
scene.render.resolution_x=1024;scene.render.resolution_y=1024;scene.render.resolution_percentage=100
nodes={n.label or n.name:n for n in preset.compositor_tree(scene).nodes if n.bl_idname=='CompositorNodeOutputFile'}
for layer in scene.view_layers: layer.use=layer.name=='Object';layer.use_motion_blur=False
for name,node in nodes.items():
    node.mute=name!='Object'
    if name=='Object':
        node.directory=str(output);node.file_name='icon-master'
        node.format.file_format='PNG';node.format.color_mode='RGBA';node.format.color_depth='8'
scene.render.use_compositing=True;bpy.context.view_layer.update()
bpy.ops.render.render(write_still=False)
path=output/'icon-master.png';assert path.exists()
im=bpy.data.images.load(str(path),check_existing=False)
rgba=np.empty(1024*1024*4,np.float32);im.pixels.foreach_get(rgba)
yy,xx=np.where(rgba.reshape(1024,1024,4)[:,:,3]>0)
actual=[int(xx.min()),int(1023-yy.max()),int(xx.max()+1),int(1024-yy.min())]
bpy.data.images.remove(im)
assert min(actual[0],actual[1],1024-actual[2],1024-actual[3])>=75,actual
report={'source_sha256':source_hash,'scene_sha256':hashlib.sha256(scene_path.read_bytes()).hexdigest(),
    'script_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
    'direction':96,'rotor':'parked','samples':256,'seed':0,'device':device,
    'size':[1024,1024],'reference_bounds':bounds,'alpha_bounds':actual,
    'ortho':scene.camera.data.ortho_scale,'camera_matrix':[list(r) for r in scene.camera.matrix_world],
    'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'native_icon_review_passed':False}
(output/'icon-report.json').write_text(json.dumps(report,indent=2)+'\n')
print('MINIGUN_ICON_MASTER '+json.dumps(report),flush=True)
