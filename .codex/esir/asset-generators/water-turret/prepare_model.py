"""Deterministic mechanical split of Meshy attempt 1; original GLB stays intact."""
import bpy, bmesh, json, math, hashlib, argparse, sys
from pathlib import Path
from mathutils import Matrix, Vector
parser=argparse.ArgumentParser()
parser.add_argument('--staging-root',default='output/meshy/water-turret')
options=parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
ROOT=Path(options.staging_root).resolve()
SOURCE=ROOT/'source/attempt-01.glb'
assert hashlib.sha256(SOURCE.read_bytes()).hexdigest()=='f9b54cc4a846b840491bed74b77aff1fc8f99534685aca114c26b439e8819c7a', 'Mechanical split is specific to inspected Meshy attempt 1'
AXIS=Vector((0.055,-0.012,0))
GROUND=-0.5461480021476746
BASE_CUT=-0.255
HEAD_CUT=-0.235

def material(name,color,metallic=0.5,roughness=0.45):
    m=bpy.data.materials.new(name);m.use_nodes=True
    p=m.node_tree.nodes.get('Principled BSDF')
    p.inputs['Base Color'].default_value=(*color,1)
    p.inputs['Metallic'].default_value=metallic;p.inputs['Roughness'].default_value=roughness
    return m

def cylinder(name,radius,low,high,mat,group):
    bpy.ops.mesh.primitive_cylinder_add(vertices=96,radius=radius,depth=high-low,location=(AXIS.x,AXIS.y,(low+high)/2))
    obj=bpy.context.object;obj.name=name;obj.data.materials.append(mat)
    bevel=obj.modifiers.new('machined-edge','BEVEL');bevel.width=0.003;bevel.segments=2
    bpy.context.view_layer.objects.active=obj;bpy.ops.object.modifier_apply(modifier=bevel.name)
    for face in obj.data.polygons: face.use_smooth=abs(face.normal.z)<0.5
    group.append(obj);return obj

def clip(source,name,height,keep_above):
    obj=source.copy();obj.data=source.data.copy();bpy.context.collection.objects.link(obj);obj.name=name
    bm=bmesh.new();bm.from_mesh(obj.data)
    bmesh.ops.bisect_plane(bm,geom=list(bm.verts)+list(bm.edges)+list(bm.faces),dist=0.000001,
        plane_co=(0,0,height),plane_no=(0,0,1),clear_inner=keep_above,clear_outer=not keep_above)
    bm.to_mesh(obj.data);bm.free();obj.data.update()
    return obj

def export(path,objects):
    bpy.ops.object.select_all(action='DESELECT')
    for obj in objects: obj.select_set(True)
    bpy.context.view_layer.objects.active=objects[0]
    bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True,export_apply=True,
        export_image_format='AUTO',export_yup=True)

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(SOURCE))
source=next(o for o in bpy.data.objects if o.type=='MESH')
base=[clip(source,'stationary_ground_base',BASE_CUT,False)]
head=[clip(source,'rotating_platform_head_backpack_pipe',HEAD_CUT,True)]
bpy.data.objects.remove(source,do_unlink=True)
teal=material('bearing_teal',(0.09,0.27,0.28),0.45,0.5)
dark=material('bearing_grease',(0.023,0.032,0.031),0.6,0.3)
steel=material('bearing_brushed_steel',(0.48,0.47,0.41),0.8,0.36)
neutral=material('force_trim',(0.72,0.72,0.72),0.2,0.5)
cylinder('fixed_lower_race',0.326,-0.272,-0.247,teal,base)
cylinder('fixed_dark_bearing_gap',0.307,-0.247,-0.230,dark,base)
cylinder('rotating_turntable_lower_rim',0.321,-0.230,-0.218,steel,head)
cylinder('rotating_turntable_platform',0.335,-0.218,-0.199,teal,head)
# Small owner-identification tab on the upper rear housing, neutral tint layer.
bpy.ops.mesh.primitive_cube_add(size=1,location=(0.905,-0.012,0.288))
trim=bpy.context.object;trim.name='force_trim_rotating_backpack';trim.scale=(0.025,0.28,0.06)
trim.data.materials.append(neutral);head.append(trim)

# Align source nozzle (-X) with prepared north (+Y), using one shared origin.
source_objects=base+head
bpy.context.view_layer.update()
raw={o.name:o.matrix_world.copy() for o in source_objects}
turn=Matrix.Rotation(-math.pi/2,4,'Z')
records=[]
for footprint in (2,3):
    scale=(footprint-0.2)/(0.5427579879760742+0.5418189764022827)
    transform=Matrix.Scale(scale,4) @ turn @ Matrix.Translation((-AXIS.x,-AXIS.y,-GROUND))
    for obj in source_objects: obj.matrix_world=transform @ raw[obj.name]
    destination=ROOT/f'prepared-{footprint}x{footprint}';destination.mkdir(parents=True,exist_ok=True)
    export(destination/'base.glb',base);export(destination/'head.glb',head);export(destination/'assembled.glb',source_objects)
    bpy.ops.wm.save_as_mainfile(filepath=str(destination/'water-turret.blend'))
    muzzle=transform @ Vector((-0.95064,-0.012,0.20))
    records.append({'footprint':footprint,'scale':scale,'bearing_axis':[0,0],
        'seam_z':(-0.238-GROUND)*scale,'muzzle_xyz':list(muzzle),
        'base_objects':[o.name for o in base],'head_objects':[o.name for o in head]})
report={'source':str(SOURCE),'source_sha256':hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
    'raw_bearing_axis':list(AXIS),'ground_z':GROUND,'base_cut_z':BASE_CUT,'head_cut_z':HEAD_CUT,
    'north_axis':'+Y','initial_angle':0,'candidates':records,
    'ownership':'Ground base and external grid connections static; platform, head, backpack and its supply pipe rotate together.'}
(ROOT/'mechanical-split.json').write_text(json.dumps(report,indent=2))
print(json.dumps(report))
