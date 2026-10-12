"""Inspect the user supplied complete revision-3 source without changing it."""
import bpy, json, hashlib, os
from pathlib import Path
from mathutils import Matrix

ROOT=Path(os.environ.get('ESIR_ACID_REVISION_ROOT','D:/CodexArtifacts/esir-acidthrower-20261009/revision-03'))
SOURCE=ROOT/'source/acidthrower-prototype-2.glb'
assert hashlib.sha256(SOURCE.read_bytes()).hexdigest()=='257f4beadb591807487fbfd1b70ff7f1b02c3e38c284068cbbee38c6ce3e4c17'
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(SOURCE))
objects=[]
for obj in bpy.data.objects:
    if obj.type!='MESH': continue
    obj.data.transform(obj.matrix_world)
    obj.matrix_world=Matrix.Identity(4)
    points=[v.co for v in obj.data.vertices]
    low=[min(p[i] for p in points) for i in range(3)]
    high=[max(p[i] for p in points) for i in range(3)]
    slices={}
    for axis in [0,2]:
        slices[str(axis)]=[]
        for i in range(20):
            start=low[axis]+(high[axis]-low[axis])*i/20
            end=low[axis]+(high[axis]-low[axis])*(i+1)/20
            selected=[p for p in points if start<=p[axis]<end]
            slices[str(axis)].append({'range':[start,end],'count':len(selected),'min':[min(p[j] for p in selected) for j in range(3)],'max':[max(p[j] for p in selected) for j in range(3)]})
    objects.append({'name':obj.name,'vertices':len(points),'faces':len(obj.data.polygons),'bounds':[low,high],'slices':slices})
report={'objects':objects,'images':[{'name':im.name,'size':list(im.size)} for im in bpy.data.images]}
(ROOT/'source/inspection.json').write_text(json.dumps(report,indent=2))
# Orthographic source views, using a diagnostic material and camera only for
# mechanical split inspection. The production render uses the Factorio preset.
from mathutils import Vector
scene=bpy.context.scene
scene.render.engine='BLENDER_EEVEE'
scene.render.resolution_x=1024;scene.render.resolution_y=1024;scene.render.resolution_percentage=100
scene.render.film_transparent=True
scene.world=bpy.data.worlds.new('InspectionWorld')
scene.world.color=(.3,.3,.3)
bpy.ops.object.light_add(type='AREA',location=(-3,-4,5))
bpy.context.object.data.energy=700;bpy.context.object.data.shape='DISK';bpy.context.object.data.size=5
bpy.ops.object.camera_add()
camera=bpy.context.object;camera.data.type='ORTHO';camera.data.ortho_scale=2.5;scene.camera=camera
(ROOT/'inspection').mkdir(exist_ok=True)
for name,position in [('top',(0,0,4)),('side',(0,-4,0)),('front',(-4,0,0)),('perspective',(-3,-3,2.5))]:
    camera.location=position
    camera.rotation_euler=(Vector((0,0,0))-camera.location).to_track_quat('-Z','Y').to_euler()
    scene.render.filepath=str(ROOT/f'inspection/{name}.png')
    bpy.ops.render.render(write_still=True)
print(json.dumps({'objects':[{k:v for k,v in o.items() if k!='slices'} for o in objects],'images':report['images']},indent=2))
