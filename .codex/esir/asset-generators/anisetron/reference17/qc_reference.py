"""Verify source GLB structure, original maps and eight raw inspection-frame bounds."""
import hashlib
import io
import json
import struct
from pathlib import Path
from PIL import Image

root = Path('output/meshy/anisetron/reference17')
source = root/'anisetron17-max-detail.glb'
raw = source.read_bytes()
magic,version,length = struct.unpack_from('<4sII',raw,0)
assert magic==b'glTF' and version==2 and length==len(raw)
json_length,json_type = struct.unpack_from('<II',raw,12)
assert json_type==0x4e4f534a
model = json.loads(raw[20:20+json_length])
binary_offset = 20+json_length+8
maps = []
for image in model['images']:
    view = model['bufferViews'][image['bufferView']]
    start = binary_offset+view.get('byteOffset',0)
    contents = raw[start:start+view['byteLength']]
    with Image.open(io.BytesIO(contents)) as texture:
        maps.append({'mime':image['mimeType'],'size':list(texture.size),
            'sha256':hashlib.sha256(contents).hexdigest()})
assert [entry['size'] for entry in maps]==[[8192,8192],[4096,4096],[4096,4096]]
vertices=triangles=0
for mesh in model['meshes']:
    for primitive in mesh['primitives']:
        assert primitive.get('mode',4)==4 and 'TEXCOORD_0' in primitive['attributes']
        vertices += model['accessors'][primitive['attributes']['POSITION']]['count']
        triangles += model['accessors'][primitive['indices']]['count']//3
rows = []
for role in ('Object','Shadow'):
    paths = sorted((root/'inspection'/role).glob('*.png'))
    assert len(paths)==8
    for path in paths:
        with Image.open(path) as frame:
            assert frame.size==(512,512) and frame.mode=='RGBA'
            bounds=frame.getchannel('A').getbbox()
            assert bounds
            margin=min(bounds[0],bounds[1],512-bounds[2],512-bounds[3])
            assert margin>=16,(path,margin)
            rows.append({'role':role,'file':path.name,'bounds':bounds,'margin_px':margin,
                'sha256':hashlib.sha256(path.read_bytes()).hexdigest()})
manifest=json.loads((root/'inspection/factorio-preset-render-manifest.json').read_text())
inspection=manifest['preflight']['anisetron_inspection']
assert inspection['vertices']==vertices and inspection['faces']==triangles
assert manifest['lighting_profile']=='preset-default'
assert not manifest['preflight']['framing']['framing_risk']
report={'pass':True,'task_id':'01a109e4-32e3-76e7-b8b3-7188f94993a1',
    'consumed_credits':40,'remaining_balance':1194,'source_sha256':hashlib.sha256(raw).hexdigest(),
    'source_bytes':len(raw),'mesh_count':len(model['meshes']),'material_count':len(model['materials']),
    'vertices':vertices,'triangles':triangles,'animation_count':len(model.get('animations',[])),
    'embedded_maps':maps,'views':8,'pass_frames':len(rows),
    'minimum_margin_px':min(entry['margin_px'] for entry in rows),'frames':rows,
    'scope':'Original model and eight preset inspection views only; no gameplay or shipped sheet replacement.'}
(root/'model-qc.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps({key:report[key] for key in ('pass','views','pass_frames','minimum_margin_px','vertices','triangles')}))
