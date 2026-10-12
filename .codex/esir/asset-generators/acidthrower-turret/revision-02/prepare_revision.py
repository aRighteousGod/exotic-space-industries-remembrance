"""Assemble the selected Meshy pressure head and exact fixed chemical base."""
import bpy,bmesh,hashlib,json,math,os,sys
from pathlib import Path
from mathutils import Matrix,Vector

ROOT=Path(os.environ.get('ESIR_ACID_REVISION_ROOT','D:/CodexArtifacts/esir-acidthrower-20261008/revision-02'))
sys.path.insert(0,str(ROOT))
import base_geometry as geo

SOURCE=ROOT/'source/upper-refined.glb'
SOURCE_HASH='11eed7c4933ebcc337041d470f8c36bfcc05891527680d9e550f7d82a8b2d444'
assert hashlib.sha256(SOURCE.read_bytes()).hexdigest()==SOURCE_HASH
PIVOT=Vector((0,.55,.43))
bpy.ops.wm.read_factory_settings(use_empty=True)
geo.material_tiles(ROOT)
right_ports,left_ports=geo.build_base()
base_qa=geo.validate_base(right_ports,left_ports)
before=set(bpy.data.objects)
bpy.ops.import_scene.gltf(filepath=str(SOURCE))
imported=[obj for obj in bpy.data.objects if obj not in before and obj.type=='MESH']
assert len(imported)==1
source=imported[0]
assert len(source.data.vertices)==323212
source.data.transform(source.matrix_world)
source.matrix_world=Matrix.Identity(4)
points=[v.co.copy() for v in source.data.vertices]
ring=[p for p in points if p.z < -.24]
ring_min=[min(p[i] for p in ring) for i in range(3)]
ring_max=[max(p[i] for p in ring) for i in range(3)]
axis=Vector(((ring_min[0]+ring_max[0])/2,(ring_min[1]+ring_max[1])/2,min(p.z for p in points)))
scale=.82/max(ring_max[0]-ring_min[0],ring_max[1]-ring_min[1])
transform=Matrix.Translation(PIVOT)@Matrix.Scale(scale,4)@Matrix.Rotation(-math.pi/2,4,'Z')@Matrix.Translation(-axis)

# Preserve housing, cradle, original UVs and PBR textures. Replace only the
# final forward nozzle cartridge with exact hollow pressure-fitting geometry.
cut_x=-.60
tip=[p for p in points if p.x < -.82]
tip_y=(min(p.y for p in tip)+max(p.y for p in tip))/2
tip_z=(min(p.z for p in tip)+max(p.z for p in tip))/2
bm=bmesh.new()
bm.from_mesh(source.data)
bmesh.ops.bisect_plane(bm,geom=list(bm.verts)+list(bm.edges)+list(bm.faces),
    plane_co=(cut_x,0,0),plane_no=(1,0,0),clear_inner=True,clear_outer=False,dist=1e-6)
edges=[edge for edge in bm.edges if edge.is_boundary and all(abs(v.co.x-cut_x)<2e-5 for v in edge.verts)]
source.data.materials.append(geo.MATERIALS['darksteel'])
if edges:
    caps=bmesh.ops.holes_fill(bm,edges=edges,sides=0)
    for face in caps.get('faces',[]):face.material_index=len(source.data.materials)-1
bm.to_mesh(source.data)
bm.free()
source.name='acid_yaw_meshy_pressure_housing'
source.matrix_world=transform
geo.YAW.append(source)

root=transform@Vector((cut_x,tip_y,tip_z))
nozzle_length=.235
front_y=root.y+nozzle_length
geo.cylinder('acid_yaw_pressure_retaining_union',(root.x,root.y+.022,root.z),.102,.050,'steel',8,'Y',geo.YAW)
steel_profile=[(.087,root.y-.005),(.094,root.y+.041),(.082,root.y+.062),(.064,root.y+.129),
    (.059,root.y+.144),(.037,root.y+.144),(.037,root.y-.005)]
geo.lathe('acid_yaw_stepped_pressure_sleeve',steel_profile,(root.x,0,root.z),'steel','Y',True,64,geo.YAW)
ceramic_profile=[(.050,root.y+.118),(.052,root.y+.159),(.038,front_y),
    (.019,front_y),(.021,root.y+.118)]
geo.lathe('acid_yaw_ceramic_jet_insert',ceramic_profile,(root.x,0,root.z),'ivory','Y',True,64,geo.YAW)
geo.cylinder('acid_yaw_recessed_bore_back',(root.x,root.y+.123,root.z),.021,.006,'rubber',48,'Y',geo.YAW)
geo.cylinder('acid_yaw_bearing_adapter',(0,.55,.445),.395,.030,'darksteel',96,'Z',geo.YAW)
geo.cylinder('acid_yaw_bearing_steel_lip',(0,.55,.464),.405,.010,'steel',96,'Z',geo.YAW)
bpy.context.view_layer.update()

def bounds(objects):
    pts=[obj.matrix_world@v.co for obj in objects for v in obj.data.vertices]
    return ([min(p[i] for p in pts) for i in range(3)],[max(p[i] for p in pts) for i in range(3)])

fixed_bounds={obj.name:bounds([obj]) for obj in geo.FIXED}
head_points=[obj.matrix_world@v.co-PIVOT for obj in geo.YAW for v in obj.data.vertices]
clearance=[]
minimum_gap=float('inf')
for angle in range(-48,49,3):
    rotate=Matrix.Rotation(math.radians(-angle),4,'Z')
    points=[PIVOT+rotate@point for point in head_points]
    low=[min(p[i] for p in points) for i in range(3)]
    high=[max(p[i] for p in points) for i in range(3)]
    assert low[0]>=-1 and high[0]<=1 and low[1]>=-1.5 and high[1]<=1.5,(angle,low,high)
    rear_gap=float('inf')
    for name,(fixed_low,fixed_high) in fixed_bounds.items():
        if name.startswith('acid_fixed_bearing_'):continue
        separations=[max(fixed_low[i]-high[i],low[i]-fixed_high[i]) for i in range(3)]
        gap=max(separations)
        # Disjoint AABBs prove these surfaces cannot intersect. The designed
        # bearing overlap is explicitly excluded; the rotary union is not.
        assert gap>0,(angle,name,'Head intersects fixed-part bounds',gap)
        if 'tank_' in name or 'manifold' in name:
            rear_gap=min(rear_gap,gap)
    minimum_gap=min(minimum_gap,rear_gap)
    clearance.append({'head_yaw_degrees':angle,'upper_bounds':[low,high],'rear_hardware_aabb_gap':rear_gap})

qa={'base':base_qa,'head_clearance_poses':clearance,'minimum_rear_hardware_aabb_gap':minimum_gap,
    'bearing_contact_z':.43,'lower_bearing_top_z':.43,'upper_adapter_bottom_z':.43,
    'source_sha256':SOURCE_HASH,'source_bearing_axis_and_bottom':list(axis),'source_uniform_scale':scale,
    'source_tip_cut_x':cut_x,'exact_bore_radius':.019,'exact_bore_recess_depth':front_y-(root.y+.126)}
anchors={'origin_xyz':[0,0,0],'north_axis':'+Y','bearing_xyz':list(PIVOT),
    'muzzle_xyz':[root.x,front_y,root.z],'muzzle_forward_axis':[0,1,0],
    'head_yaw_limits_degrees':[-48,48],'base_objects':[obj.name for obj in geo.FIXED],
    'upper_objects':[obj.name for obj in geo.YAW],
    'owner_trim_objects':[obj.name for obj in geo.FIXED+geo.YAW if obj.name.startswith('acid_trim_')],
    'canisters_export_owner':'base','production_ready':False,
    'limits':['Comparison model only; production deployment animation and owner-mask export pending approval.',
        'In-engine sprite attachment and muzzle validation remain for production integration.']}
destination=ROOT/'prepared'
destination.mkdir(parents=True,exist_ok=True)
geo.export(destination/'base.glb',geo.FIXED)
geo.export(destination/'head-only.glb',geo.YAW)
geo.export(destination/'assembled.glb',geo.FIXED+geo.YAW)
bpy.ops.wm.save_as_mainfile(filepath=str(destination/'acidthrower-revision02.blend'))
(ROOT/'model-anchors.json').write_text(json.dumps(anchors,indent=2))
(ROOT/'geometry-qa.json').write_text(json.dumps(qa,indent=2))
(ROOT/'base-geometry-qa.json').write_text(json.dumps(base_qa,indent=2))
print('REVISION_QA '+json.dumps({'scale':scale,'muzzle':anchors['muzzle_xyz'],'base_bounds':[base_qa['bounds_min'],base_qa['bounds_max']],
    'symmetry_error':base_qa['mirror_max_vertex_error'],'clearance_poses':len(clearance),'minimum_rear_gap':minimum_gap}))
