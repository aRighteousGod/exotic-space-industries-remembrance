"""Preserve the Meshy source and export aligned acidthrower comparison variants."""
import bpy, bmesh, hashlib, json, math, os
from pathlib import Path
from mathutils import Matrix, Vector

ROOT = Path(os.environ.get('ESIR_ACID_STAGING_ROOT', 'output/meshy/acidthrower-turret')).resolve()
SOURCE = ROOT/'source/attempt-01.glb'
assert hashlib.sha256(SOURCE.read_bytes()).hexdigest() == '2fcd937fb916338948b46ff9390a3bd0994ca8e2cda0a16c83bf34179262fafd', 'Reinspect changed source before applying this mechanical split.'
AXIS = Vector((0.175, 0.025, 0))
GROUND = -0.5947830080986023
BASE_CUT = -0.282
HEAD_CUT = -0.272
SEAM = -0.272

def metal(name, color):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get('Principled BSDF')
    bsdf.inputs['Base Color'].default_value = (*color,1)
    bsdf.inputs['Metallic'].default_value = 0.45
    bsdf.inputs['Roughness'].default_value = 0.60
    return mat

def cylinder(name, radius, bottom, top, material):
    bpy.ops.mesh.primitive_cylinder_add(vertices=96, radius=radius, depth=top-bottom,
        location=(AXIS.x,AXIS.y,(bottom+top)/2))
    obj=bpy.context.object
    obj.name=name
    obj.data.materials.append(material)
    for face in obj.data.polygons:
        face.use_smooth=abs(face.normal.z)<0.5
    return obj

def clip(source, name, z, keep_above):
    obj=source.copy()
    obj.data=source.data.copy()
    bpy.context.collection.objects.link(obj)
    obj.name=name
    # Bake imported transform before the world-space mechanical cut.
    obj.data.transform(obj.matrix_world)
    obj.matrix_world=Matrix.Identity(4)
    bm=bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.bisect_plane(bm, geom=list(bm.verts)+list(bm.edges)+list(bm.faces),
        dist=0.000001,plane_co=(0,0,z),plane_no=(0,0,1),
        clear_inner=keep_above,clear_outer=not keep_above)
    cut_edges=[e for e in bm.edges if e.is_boundary and all(abs(v.co.z-z)<0.00002 for v in e.verts)]
    if cut_edges:
        caps=bmesh.ops.holes_fill(bm,edges=cut_edges,sides=0)
        obj.data.materials.append(cap_material)
        for face in caps.get('faces',[]):
            face.material_index=len(obj.data.materials)-1
    bm.to_mesh(obj.data)
    bm.free()
    obj.data.update()
    return obj

def export(path, objects):
    bpy.ops.object.select_all(action='DESELECT')
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active=objects[0]
    bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True,
        export_apply=True,export_image_format='AUTO',export_yup=True)

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(SOURCE))
sources=[obj for obj in bpy.data.objects if obj.type=='MESH']
assert len(sources)==1, 'Reinspect before applying this source-specific seam.'
assert len(sources[0].data.vertices)==697351, 'Source geometry changed; reinspect.'
cap_material=metal('sealed_cut_surface',(0.10,0.115,0.095))
dark=metal('bearing_grease',(0.065,0.073,0.060))
steel=metal('bearing_collar',(0.29,0.30,0.255))
base=[clip(sources[0],'stationary_pedestal',BASE_CUT,False)]
head=[clip(sources[0],'rotating_nozzle_vessels_turntable',HEAD_CUT,True)]
for source in sources:
    bpy.data.objects.remove(source,do_unlink=True)
base.append(cylinder('fixed_bearing_race',0.428,-0.292,SEAM,dark))
head.append(cylinder('rotating_bearing_underside',0.417,SEAM,-0.255,steel))
bpy.context.view_layer.update()

# One uniform scale/origin for the entire assembly. The square plinth fits
# within the existing 2x3 footprint; exact external collar routing is later QC.
turn=Matrix.Rotation(-math.pi/2,4,'Z')
base_points=[turn @ (obj.matrix_world @ Vector(corner)-AXIS) for obj in base for corner in obj.bound_box]
width=max(p.x for p in base_points)-min(p.x for p in base_points)
length=max(p.y for p in base_points)-min(p.y for p in base_points)
scale=min(1.8/width,2.8/length)
transform=Matrix.Scale(scale,4) @ turn @ Matrix.Translation((-AXIS.x,-AXIS.y,-GROUND))
for obj in base+head:
    obj.matrix_world=transform @ obj.matrix_world
bpy.context.view_layer.update()

destination=ROOT/'prepared'
destination.mkdir(parents=True,exist_ok=True)
export(destination/'base.glb',base)
export(destination/'head-only.glb',head)
export(destination/'assembled.glb',base+head)
bpy.ops.wm.save_as_mainfile(filepath=str(destination/'acidthrower-variants.blend'))
muzzle=transform @ Vector((-0.946,0.027,0.183))
report={'source':str(SOURCE),'source_sha256':hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
    'raw_bearing_axis':list(AXIS),'ground_z':GROUND,'base_cut_z':BASE_CUT,'head_cut_z':HEAD_CUT,
    'scale':scale,'base_footprint':[width*scale,length*scale], 'gameplay_footprint':[2,3],
    'seam_z':(SEAM-GROUND)*scale,'muzzle_xyz':list(muzzle),'north_axis':'+Y',
    'base_objects':[obj.name for obj in base],'head_objects':[obj.name for obj in head],
    'textures_preserved':True,'production_ready':False,
    'limitations':['External pipe collars need exact grid placement before promotion.',
        'Muzzle anchor is a draft geometry measurement; native firing calibration remains.',
        'No deployment animation or runtime owner-color mask is produced in this comparison pass.'],
    'ownership':'Pedestal fixed; complete upper turntable, nozzle, vessels and internal hoses rotate together.',
    'head_origin':'Shared assembly origin retained; use seam_z for bearing contact placement.'}
(ROOT/'mechanical-split.json').write_text(json.dumps(report,indent=2))
print('ACID_PREPARE '+json.dumps(report))
