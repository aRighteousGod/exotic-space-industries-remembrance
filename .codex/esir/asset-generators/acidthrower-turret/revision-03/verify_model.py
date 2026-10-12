"""Verify shared-origin exports and swept mechanical clearance in Blender."""
import bpy,hashlib,json,math,os,struct
from pathlib import Path
from mathutils import Matrix,Vector
from mathutils.bvhtree import BVHTree
ROOT=Path(os.environ.get('ESIR_ACID_REVISION_ROOT','D:/CodexArtifacts/esir-acidthrower-20261009/revision-03'))
anchors=json.loads((ROOT/'model-anchors.json').read_text())
pivot=Vector(anchors['bearing_xyz'])

def imported(name):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(ROOT/'prepared'/name))
    result={}
    for obj in bpy.data.objects:
        if obj.type!='MESH':continue
        result[obj.name]=([obj.matrix_world@v.co for v in obj.data.vertices], [tuple(p.vertices) for p in obj.data.polygons])
    return result

def digest(mesh):
    vertices,faces=mesh
    return hashlib.sha256(json.dumps([[[round(c,7) for c in v] for v in vertices],faces],separators=(',',':')).encode()).hexdigest()

head=imported('head-only.glb');complete=imported('assembled.glb')
equality={name:digest(mesh)==digest(complete[name]) for name,mesh in head.items()}
assert all(equality.values()),equality
base_vertices=[];base_faces=[]
for name,(verts,faces) in complete.items():
    if name not in anchors['base_objects'] or 'bearing' in name:continue
    offset=len(base_vertices);base_vertices.extend(verts)
    base_faces.extend(tuple(offset+i for i in face) for face in faces if max(verts[i].z for i in face)>pivot.z+.025)
base_tree=BVHTree.FromPolygons(base_vertices,base_faces,all_triangles=False,epsilon=0)
verts,faces=head['acid_yaw_pressure_head']
faces=[face for face in faces if min(verts[i].z for i in face)>pivot.z+.025]
rows=[]
for degrees in range(-48,49):
    transform=Matrix.Translation(pivot)@Matrix.Rotation(math.radians(degrees),4,'Z')@Matrix.Translation(-pivot)
    moved=[transform@v for v in verts]
    tree=BVHTree.FromPolygons(moved,faces,all_triangles=False,epsilon=0)
    overlaps=tree.overlap(base_tree)
    rows.append({'degrees':degrees,'triangle_overlaps':len(overlaps)})
    if degrees%12==0:print('ACID_CLEARANCE',rows[-1],flush=True)
report={'identical_shared_origin_head':equality,'arc_samples':rows,
    'bearing_contact_exclusion_height':.025,'connector_mirror_error':anchors['connector_mirror_error'],
    'base_bounds':anchors['base_bounds'],'all_pass':all(equality.values()) and all(row['triangle_overlaps']==0 for row in rows)}
(ROOT/'geometry-qa.json').write_text(json.dumps(report,indent=2))
print('ACID_GEOMETRY_PASS',report['all_pass'],flush=True)
assert report['all_pass']
