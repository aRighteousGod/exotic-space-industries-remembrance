"""Separate the supplied unified model at its bearing; retain its UV/PBR art."""
import bpy, bmesh, hashlib, json, math, os
from pathlib import Path
from mathutils import Matrix, Vector

ROOT=Path(os.environ.get('ESIR_ACID_REVISION_ROOT','D:/CodexArtifacts/esir-acidthrower-20261009/revision-03'))
SOURCE=ROOT/'source/acidthrower-prototype-2.glb'
SOURCE_HASH='257f4beadb591807487fbfd1b70ff7f1b02c3e38c284068cbbee38c6ce3e4c17'
assert hashlib.sha256(SOURCE.read_bytes()).hexdigest()==SOURCE_HASH
RAW_AXIS=Vector((-.382,.002,-.092))
GROUND=-.40022900700569153
SCALE=1.47
CENTER=Vector((.055,.001,GROUND))
TURN=Matrix.Rotation(-math.pi/2,4,'Z')
TRANSFORM=Matrix.Scale(SCALE,4)@TURN@Matrix.Translation(-CENTER)
PIVOT=TRANSFORM@RAW_AXIS

def metal(name,color,metallic=.55,roughness=.58):
    mat=bpy.data.materials.new(name);mat.use_nodes=True
    bsdf=mat.node_tree.nodes.get('Principled BSDF')
    bsdf.inputs['Base Color'].default_value=(*color,1)
    bsdf.inputs['Metallic'].default_value=metallic
    bsdf.inputs['Roughness'].default_value=roughness
    return mat

def clip(source,name,cuts):
    obj=source.copy();obj.data=source.data.copy();bpy.context.collection.objects.link(obj);obj.name=name
    bm=bmesh.new();bm.from_mesh(obj.data)
    obj.data.materials.append(seal)
    for axis,value,above in cuts:
        normal=[0,0,0];normal[axis]=1;point=[0,0,0];point[axis]=value
        bmesh.ops.bisect_plane(bm,geom=list(bm.verts)+list(bm.edges)+list(bm.faces),dist=1e-6,
            plane_co=point,plane_no=normal,clear_inner=above,clear_outer=not above)
        boundary=[edge for edge in bm.edges if edge.is_boundary and all(abs(v.co[axis]-value)<2e-5 for v in edge.verts)]
        if boundary:
            for face in bmesh.ops.holes_fill(bm,edges=boundary,sides=0).get('faces',[]):
                face.material_index=len(obj.data.materials)-1
    bm.to_mesh(obj.data);bm.free();obj.data.update();obj.matrix_world=TRANSFORM
    return obj

def cylinder(name,radius,depth,location,material):
    bpy.ops.mesh.primitive_cylinder_add(vertices=96,radius=radius,depth=depth,location=location)
    obj=bpy.context.object;obj.name=name;obj.data.materials.append(material)
    for p in obj.data.polygons:p.use_smooth=len(p.vertices)==4
    return obj

def collar(name,side):
    # Identical local profile reflected across X; mouth is exactly x=+/-1.
    profile=[(.80,.085),(.89,.085),(.90,.118),(.975,.118),(1,.104),(1,.073),(.87,.073)]
    verts=[(side*x,-1+r*math.cos(i*math.tau/64),.30+r*math.sin(i*math.tau/64)) for x,r in profile for i in range(64)]
    faces=[]
    for ring in range(len(profile)-1):
        for i in range(64):faces.append((ring*64+i,ring*64+(i+1)%64,(ring+1)*64+(i+1)%64,(ring+1)*64+i))
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],faces);mesh.update()
    bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(mesh);bm.free()
    obj=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(obj);mesh.materials.append(steel)
    for p in mesh.polygons:p.use_smooth=True
    return obj

def bounds(objects):
    points=[obj.matrix_world@v.co for obj in objects for v in obj.data.vertices]
    return [[min(p[i] for p in points) for i in range(3)],[max(p[i] for p in points) for i in range(3)]]

def export(path,objects):
    bpy.ops.object.select_all(action='DESELECT')
    for obj in objects:obj.select_set(True)
    bpy.context.view_layer.objects.active=objects[0]
    bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True,export_apply=True,export_image_format='AUTO',export_yup=True)

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(SOURCE))
source=next(obj for obj in bpy.data.objects if obj.type=='MESH')
source.data.transform(source.matrix_world);source.matrix_world=Matrix.Identity(4)
assert len(source.data.vertices)==540154
seal=metal('acid_bearing_grease',(.045,.05,.043),.20,.8)
steel=metal('acid_port_steel',(.23,.24,.205),.72,.51)
neutral=metal('acid_owner_neutral',(.48,.49,.46),.18,.62)
# The -0.092 seam is above the source's raised rails. The rear half remains
# fixed, preserving both tanks and every visible manifold connection.
base=[clip(source,'acid_fixed_chassis',[(2,RAW_AXIS.z,False)]),
      clip(source,'acid_fixed_tanks_manifold',[(2,RAW_AXIS.z,True),(0,-.085,True)])]
head=[clip(source,'acid_yaw_pressure_head',[(2,RAW_AXIS.z,True),(0,-.085,False)])]
bpy.data.objects.remove(source,do_unlink=True)
base.append(cylinder('acid_fixed_bearing_seal',.196*SCALE,.016,(PIVOT.x,PIVOT.y,PIVOT.z-.006),seal))
head.append(cylinder('acid_yaw_bearing_underside',.190*SCALE,.01,(PIVOT.x,PIVOT.y,PIVOT.z+.002),seal))
base.extend([collar('acid_fixed_port_left',-1),collar('acid_fixed_port_right',1)])
# A small neutral owner plate sits on the front service plaque.
bpy.ops.mesh.primitive_cube_add(size=1,location=(0,1.298,.20))
owner=bpy.context.object;owner.name='acid_owner_front_plate';owner.dimensions=(.57,.008,.105)
bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
owner.data.materials.append(neutral)
bevel=owner.modifiers.new('plate_edges','BEVEL');bevel.width=.014;bevel.segments=3
bpy.context.view_layer.objects.active=owner;bpy.ops.object.modifier_apply(modifier=bevel.name)
base.append(owner)
for obj in base+head:
    obj.data.transform(obj.matrix_world);obj.matrix_world=Matrix.Identity(4)
bpy.context.view_layer.update()
base_bounds=bounds(base);head_bounds=bounds(head)
assert base_bounds[0][0]>=-1.00001 and base_bounds[1][0]<=1.00001
assert base_bounds[0][1]>=-1.5 and base_bounds[1][1]<=1.5
# Confirm the rotating split contains no stray side rails or tanks.
assert head_bounds[1][2]<1.05 and head_bounds[0][1]>.18
left=next(o for o in base if o.name.endswith('port_left'))
right=next(o for o in base if o.name.endswith('port_right'))
mirror_error=max((Vector((-l.co.x,l.co.y,l.co.z))-r.co).length for l,r in zip(left.data.vertices,right.data.vertices))
assert mirror_error<1e-6
muzzle=TRANSFORM@Vector((-.940,.002,.173))
anchors={'source_sha256':SOURCE_HASH,'scale':SCALE,'raw_bearing_axis':list(RAW_AXIS),'raw_ground_z':GROUND,
    'origin_xyz':[0,0,0],'north_axis':'+Y','bearing_xyz':list(PIVOT),'muzzle_xyz':list(muzzle),
    'muzzle_relative_xyz':list(muzzle-Vector((PIVOT.x,PIVOT.y,0))),
    'head_direction_count':256,'head_step_degrees':360/256,'gameplay_footprint':[2,3],
    'head_yaw_limits_degrees':[-48,48],'base_objects':[o.name for o in base],'head_objects':[o.name for o in head],
    'owner_objects':[owner.name],'base_bounds':base_bounds,'head_bounds':head_bounds,
    'connector_mirror_error':mirror_error,'pipe_mouths':[[-1,-1,.30],[1,-1,.30]],
    'canisters_export_owner':'base','glow_active_states':['prepared','attacking','ending-attack']}
prepared=ROOT/'prepared';prepared.mkdir(exist_ok=True)
export(prepared/'base.glb',base);export(prepared/'head-only.glb',head);export(prepared/'assembled.glb',base+head)
export(prepared/'collars.glb',[obj for obj in base if obj.name.startswith('acid_fixed_port_')])
export(prepared/'chassis-with-tanks.glb',[obj for obj in base if not obj.name.startswith('acid_fixed_port_')])
bpy.ops.wm.save_as_mainfile(filepath=str(prepared/'acidthrower-revision03.blend'))
for obj in head:obj.matrix_world=Matrix.Translation((-PIVOT.x,-PIVOT.y,0))
export(prepared/'head-centred.glb',head)
(ROOT/'model-anchors.json').write_text(json.dumps(anchors,indent=2))
print('ACID_PREPARE '+json.dumps(anchors))
