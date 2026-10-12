"""Inspect the preserved selected Meshy upper before source-specific alignment."""
import bpy,json,hashlib,os
from pathlib import Path

root=Path(os.environ.get('ESIR_ACID_REVISION_ROOT','D:/CodexArtifacts/esir-acidthrower-20261008/revision-02'))
source=root/'source/upper-refined.glb'
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(source))
result={'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'objects':[],'images':[]}
for obj in bpy.data.objects:
    if obj.type!='MESH':continue
    points=[obj.matrix_world@v.co for v in obj.data.vertices]
    low=[min(p[i] for p in points) for i in range(3)]
    high=[max(p[i] for p in points) for i in range(3)]
    record={'name':obj.name,'vertices':len(points),'faces':len(obj.data.polygons),'bounds':[low,high],'slices':{}}
    for axis in [0,1,2]:
        slices=[]
        for i in range(12):
            start=low[axis]+(high[axis]-low[axis])*i/12
            end=low[axis]+(high[axis]-low[axis])*(i+1)/12
            selected=[p for p in points if start<=p[axis]<end]
            if selected:slices.append({'range':[start,end],'count':len(selected),'min':[min(p[j] for p in selected) for j in range(3)],'max':[max(p[j] for p in selected) for j in range(3)]})
        record['slices'][str(axis)]=slices
    result['objects'].append(record)
for im in bpy.data.images:
    result['images'].append({'name':im.name,'size':list(im.size),'packed':bool(im.packed_file)})
(root/'source/upper-inspection.json').write_text(json.dumps(result,indent=2))
print('UPPER_INSPECT '+json.dumps({'source_sha256':result['source_sha256'],'objects':[{k:v for k,v in obj.items() if k!='slices'} for obj in result['objects']],'images':result['images']}))
