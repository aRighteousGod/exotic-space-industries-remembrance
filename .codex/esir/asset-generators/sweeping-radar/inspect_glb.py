"""Read a GLB's metadata without importing geometry or decoding large textures."""
import argparse
import hashlib
import json
import struct
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument('input', type=Path)
parser.add_argument('--output', type=Path)
args = parser.parse_args()
with args.input.open('rb') as stream:
    magic, version, total = struct.unpack('<III', stream.read(12))
    assert magic == 0x46546C67 and version == 2, 'Expected GLB version 2'
    length, kind = struct.unpack('<II', stream.read(8))
    assert kind == 0x4E4F534A, 'Expected JSON first chunk'
    document = json.loads(stream.read(length))
accessors = document.get('accessors', [])
primitives = []
for mesh in document.get('meshes', []):
    for primitive in mesh['primitives']:
        position = accessors[primitive['attributes']['POSITION']]
        indices = accessors[primitive['indices']] if 'indices' in primitive else None
        primitives.append(dict(mesh=mesh.get('name'), vertices=position['count'],
                               triangles=indices['count']//3 if indices else position['count']//3,
                               minimum=position.get('min'), maximum=position.get('max'),
                               material=primitive.get('material'), attributes=primitive['attributes']))
report = dict(source=str(args.input.resolve()), bytes=total,
              sha256=hashlib.file_digest(args.input.open('rb'), 'sha256').hexdigest(),
              primitives=primitives, nodes=document.get('nodes'),
              materials=document.get('materials'), images=document.get('images'),
              textures=document.get('textures'), extensions_used=document.get('extensionsUsed'))
destination = args.output or args.input.with_suffix('.inspection.json')
destination.write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
print(json.dumps(dict(report=str(destination), bytes=total, sha256=report['sha256'],
                      primitives=primitives, material_count=len(report['materials'] or []),
                      image_count=len(report['images'] or [])), indent=2))
