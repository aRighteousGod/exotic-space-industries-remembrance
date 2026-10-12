"""Resumable full-scene references; receiver corrections belong to the compiler."""
import argparse, hashlib, importlib.util, json, math, shutil, sys, time
from pathlib import Path
from types import SimpleNamespace
import bpy
import numpy as np
from mathutils import Quaternion, Vector
from bpy_extras.object_utils import world_to_camera_view
HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(HERE))
from separated_contract import SOURCE_SHA256, SCHEMA, physical_pose, phase_degrees, phase_expression
REPO=Path.cwd()
ROOT=REPO/'output/meshy/minigun-prototypes/prototype-2/handoff-256'
parser=argparse.ArgumentParser()
parser.add_argument('--output',type=Path,default=ROOT/'separated-v2')
parser.add_argument('--directions',default='0,32,64,96,128,160,192,224')
parser.add_argument('--families',default='base,upper,full')
parser.add_argument('--poses',default='all')
parser.add_argument('--samples',type=int,default=256)
parser.add_argument('--reuse-endpoints',action='store_true')
parser.add_argument('--proof-only',action='store_true')
args=parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
directions=list(range(256)) if args.directions=='all' else [int(x) for x in args.directions.split(',')]
poses=list(range(28)) if args.poses=='all' else [int(x) for x in args.poses.split(',')]
families=args.families.split(',')
assert len(set(directions))==len(directions) and all(0<=d<256 for d in directions)
assert all(0<=p<28 for p in poses) and set(families)<={'base','upper','full'}
output=args.output.resolve();output.mkdir(parents=True,exist_ok=True)
render_root=output/'references'
source=ROOT.parent/'source/model.glb'
assert hashlib.sha256(source.read_bytes()).hexdigest()==SOURCE_SHA256
scene_path=ROOT/'prepared/minigun-render-scene.blend'
bpy.ops.wm.open_mainfile(filepath=str(scene_path))
scene=bpy.context.scene
spec=importlib.util.spec_from_file_location('factorio_preset',REPO/'.codex/skills/meshy-blender-spritesheet/scripts/render_factorio_preset.py')
preset=importlib.util.module_from_spec(spec);spec.loader.exec_module(preset)
device=preset.configure_cycles_device(SimpleNamespace(cycles_compute_device='auto',cycles_include_cpu=False),scene)
scene.cycles.samples=args.samples;scene.cycles.seed=0;scene.cycles.use_animated_seed=False
scene.render.use_persistent_data=True
scene.render.motion_blur_shutter=1.0;scene.render.motion_blur_position='CENTER'
scene.camera.data.animation_data_clear();scene.camera.data.ortho_scale=8.4375
assert (scene.render.resolution_x,scene.render.resolution_y)==(540,540)
rotator=bpy.data.objects.get('Rotation by Frames & Directions')
if rotator:
    rotator.animation_data_clear();rotator.rotation_euler=(0,0,0)
yaw=bpy.data.objects['YAW_PIVOT'];spin=bpy.data.objects['ROTOR_PIVOT']
alignment=Quaternion(spin['alignment_quaternion']);yaw.animation_data_clear()
# Driver outputs near zero are snapped to zero in this Blender build. Keep the
# measured axis in a constant parent quaternion, and drive an unwrapped Euler
# phase biased by one complete turn; this avoids that snap without changing
# geometry or taking a shortest-path quaternion interpolation.
axis_frame=bpy.data.objects.new('ROTOR_AXIS_FRAME',None);scene.collection.objects.link(axis_frame)
axis_frame.parent=spin.parent;axis_frame.location=spin.location.copy()
axis_frame.rotation_mode='QUATERNION';axis_frame.rotation_quaternion=alignment
spin.parent=axis_frame;spin.location=(0,0,0);spin.animation_data_clear()
spin.rotation_mode='XYZ';spin.rotation_euler=(0,0,math.tau)
# Driver.expression is limited to 255 characters. Separate time, normalized
# time and phase into acyclic helpers, keeping each quaternion expression short.
helpers=[]
for name in ('MG_EXPOSURE_T','MG_EXPOSURE_U','MG_EXPOSURE_PHASE'):
    helper=bpy.data.objects.new(name,None);scene.collection.objects.link(helper)
    helper['value']=0.0;helpers.append(helper)
time_helper,u_helper,phase_helper=helpers

def variable(driver,name,obj):
    v=driver.variables.new();v.name=name;v.type='SINGLE_PROP'
    v.targets[0].id=obj;v.targets[0].data_path='["value"]'
moving={'BARREL_ROTOR','ROTOR_INTERNAL_ROOT_HUB'}
upper_names={'UPPER_FIXED_TO_YAW'}
base_names={'BASE_FIXED','FIXED_INTERNAL_BEARING_LINER'}
for obj in scene.objects:
    obj.cycles.use_motion_blur=obj.name in moving
    if obj.name in moving:
        obj.cycles.use_deform_motion=False;obj.cycles.motion_steps=5
for layer in scene.view_layers:
    layer.use=layer.name in ('Object','Shadow');layer.use_motion_blur=True
tree=preset.compositor_tree(scene)
nodes={n.label or n.name:n for n in tree.nodes if n.bl_idname=='CompositorNodeOutputFile'}
for n in nodes.values():
    n.format.file_format='PNG';n.format.color_mode='RGBA';n.format.color_depth='8';n.mute=True
for n in tree.nodes:
    if n.bl_idname in ('CompositorNodeComposite','CompositorNodeViewer'): n.mute=True
scene.render.use_compositing=True;scene.render.use_file_extension=True
bpy.context.window.view_layer=scene.view_layers['Object'];scene.frame_set(100);bpy.context.view_layer.update()
ground=world_to_camera_view(scene,scene.camera,Vector((0,0,0)))
anchor=[ground.x*540,(1-ground.y)*540]
configuration={'schema':SCHEMA,'source_sha256':SOURCE_SHA256,
    'scene_sha256':hashlib.sha256(scene_path.read_bytes()).hexdigest(),
    'script_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
    'contract_sha256':hashlib.sha256((HERE/'separated_contract.py').read_bytes()).hexdigest(),
    'samples':args.samples,'seed':0,'density':64,'resolution':[540,540],
    'ortho':8.4375,'ground_anchor_pixels':anchor,'blender':bpy.app.version_string,
    'device':device,'physical_poses':28,'shutter':1.0,
    'geometry_partition':{'base':sorted(base_names),'upper':sorted(upper_names),'rotor':sorted(moving)}}
config_hash=hashlib.sha256(json.dumps(configuration,sort_keys=True).encode()).hexdigest()
config_path=output/'render-configuration.json'
if config_path.exists():
    assert json.loads(config_path.read_text())['hash']==config_hash,'Configuration changed; use new output folder.'
else: config_path.write_text(json.dumps({'hash':config_hash,**configuration},indent=2)+'\n')
record_path=output/'render-records.jsonl';records={}
if record_path.exists():
    for line in record_path.read_text().splitlines():
        r=json.loads(line);records[(r['family'],r['direction'],r['pose'],r['pass'])]=r

def frame_at(value):
    i=math.floor(value);scene.frame_set(i,subframe=value-i);bpy.context.view_layer.update()

def pose(family,direction,index):
    for name in base_names|upper_names|moving:
        bpy.data.objects[name].hide_render=(family=='base' and name not in base_names) or (family=='upper' and name in moving)
    yaw.rotation_euler=(0,0,-math.tau*direction/256)
    kind,center=physical_pose(index) if family=='full' else ('parked',0.0)
    for helper in helpers: helper.animation_data_clear()
    time_helper.driver_add('["value"]').driver.expression=f'frame-100+{center!r}'
    duration=10 if kind=='up' else 16
    u_helper.driver_add('["value"]').driver.expression=f'(frame-100+{center!r}-0.5)/{duration}'
    phase_driver=phase_helper.driver_add('["value"]').driver
    variable(phase_driver,'t',time_helper);variable(phase_driver,'u',u_helper)
    if kind=='parked': degrees='0'
    elif kind=='running': degrees='90*t'
    elif kind=='up': degrees='0 if t<=0.5 else 315+90*(t-10.5) if t>=10.5 else 900*(u**4/4+3*u**5/5-u**6/2)'
    else: degrees='90*t if t<=0.5 else 720 if t>=16.5 else 45+1440*(u-23*u**3/16+43*u**4/32-9*u**5/16+u**6/8)'
    phase_driver.expression=f'360+({degrees})'
    spin.animation_data_clear()
    driver=spin.driver_add('rotation_euler',2).driver
    variable(driver,'a',phase_helper);driver.expression=f'a*{math.pi/180!r}'
    scene.render.use_motion_blur=kind!='parked';frame_at(100)
    static={n:np.asarray(bpy.data.objects[n].matrix_world).copy() for n in base_names|upper_names|{'YAW_PIVOT',scene.camera.name}}
    root=np.asarray(spin.matrix_world.translation).copy();error=0.0;diagnostics=[]
    for dt in (-.5,-.375,-.25,-.125,0,.125,.25,.375,.5):
        frame_at(100+dt)
        for n,m in static.items(): error=max(error,float(np.abs(np.asarray(bpy.data.objects[n].matrix_world)-m).max()))
        error=max(error,float(np.abs(np.asarray(spin.matrix_world.translation)-root).max()))
        expected=alignment@Quaternion((0,0,1),math.radians(phase_degrees(kind,center+dt)))
        actual=alignment@spin.rotation_euler.to_quaternion()
        if actual.dot(expected)<0: actual.negate()
        error=max(error,max(abs(a-b) for a,b in zip(actual,expected)))
        diagnostics.append({'dt':dt,'frame':scene.frame_current_final,'t':time_helper['value'],
            'u':u_helper['value'],'phase':phase_helper['value'],
            'expected_phase':360+phase_degrees(kind,center+dt),
            'actual_quaternion':list(actual),'expected_quaternion':list(expected)})
    if error>=2e-6: print('POSE_PROOF_FAILURE '+json.dumps(diagnostics),flush=True)
    assert error<2e-6,(family,direction,index,error)
    frame_at(100);return error

def setup_pass(label,path):
    for layer in scene.view_layers: layer.use=layer.name==label
    for name,node in nodes.items():
        node.mute=name!=label
        if name==label:
            path.parent.mkdir(parents=True,exist_ok=True);node.directory=str(path.parent);node.file_name=path.stem
    bpy.context.window.view_layer=scene.view_layers[label];bpy.context.view_layer.update()

jobs=[('base',0,0)] if 'base' in families else []
jobs += [('upper',d,0) for d in directions] if 'upper' in families else []
jobs += [('full',d,p) for d in directions for p in poses] if 'full' in families else []
completed=0
for family,d,p in jobs:
    if args.proof_only:
        setup_pass('Object',render_root/family/'Object'/f'd{d:03}-p{p:02}.png')
        proof=pose(family,d,p);print('POSE_PROOF '+json.dumps({'family':family,'direction':d,'pose':p,'error':proof}),flush=True)
        continue
    for label in ('Object','Shadow'):
        key=(family,d,p,label);path=render_root/family/label/f'd{d:03}-p{p:02}.png';old=records.get(key)
        if old and path.exists() and hashlib.sha256(path.read_bytes()).hexdigest()==old['sha256']:
            completed+=1;continue
        assert shutil.disk_usage(output).free>5*1024**3,'Less than 5GiB free; render paused safely.'
        setup_pass(label,path);proof=pose(family,d,p);started=time.monotonic();reused=None
        if args.reuse_endpoints and args.samples==256 and family=='full' and p in (0,1):
            old_path=ROOT/'motion-blur'/('sharp' if p==0 else 'firing')/label/f'd{d:03}.png'
            if old_path.exists(): shutil.copyfile(old_path,path);reused=str(old_path.relative_to(REPO)).replace('\\','/')
        if reused is None: bpy.ops.render.render(write_still=False)
        assert path.exists(),path
        image=bpy.data.images.load(str(path),check_existing=False);assert list(image.size)==[540,540]
        pixels=np.empty(540*540*4,np.float32);image.pixels.foreach_get(pixels)
        yy,xx=np.where(pixels.reshape(540,540,4)[:,:,3]>1/255);assert len(xx),(family,d,p,label)
        bounds=[int(xx.min()),int(539-yy.max()),int(xx.max()+1),int(540-yy.min())]
        margin=min(bounds[0],bounds[1],540-bounds[2],540-bounds[3]);assert margin>=8,(family,d,p,label,bounds)
        bpy.data.images.remove(image)
        record={'family':family,'direction':d,'pose':p,'pass':label,'configuration_hash':config_hash,
            'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'seconds':time.monotonic()-started,
            'alpha_bounds':bounds,'margin':margin,'pose_proof_error':proof,
            'path':str(path.relative_to(output)).replace('\\','/'),'reused_source':reused}
        with record_path.open('a',encoding='utf-8') as stream: stream.write(json.dumps(record)+'\n')
        completed+=1;print('SEPARATED_FRAME '+json.dumps(record),flush=True)
print('SEPARATED_RENDER_COMPLETE '+json.dumps({'completed':completed,'output':str(output)}),flush=True)
