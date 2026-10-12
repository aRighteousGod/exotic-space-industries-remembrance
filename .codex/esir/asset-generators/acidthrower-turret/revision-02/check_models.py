"""Verify source identity, embedded textures and the shared upper GLB geometry."""
import argparse
import hashlib
import json
import struct
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument('--root', default='D:/CodexArtifacts/esir-acidthrower-20261008/revision-02')
root = Path(parser.parse_args().root)


def digest(data):
    return hashlib.sha256(data).hexdigest()


def read_glb(path):
    data = path.read_bytes()
    magic, version, length = struct.unpack_from('<4sII', data)
    assert (magic, version, length) == (b'glTF', 2, len(data)), path
    cursor = 12
    document, binary = None, None
    while cursor < length:
        size, kind = struct.unpack_from('<I4s', data, cursor)
        chunk = data[cursor + 8:cursor + 8 + size]
        if kind == b'JSON':
            document = json.loads(chunk)
        elif kind == b'BIN\x00':
            binary = chunk
        cursor += 8 + size
    assert document is not None and binary is not None
    return document, binary, digest(data)


def view_bytes(document, binary, index):
    view = document['bufferViews'][index]
    start = view.get('byteOffset', 0)
    return binary[start:start + view['byteLength']]


def accessor_signature(document, binary, index):
    accessor = document['accessors'][index]
    view = document['bufferViews'][accessor['bufferView']]
    component_size = {5120: 1, 5121: 1, 5122: 2, 5123: 2, 5125: 4, 5126: 4}[accessor['componentType']]
    width = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4, 'MAT4': 16}[accessor['type']] * component_size
    stride = view.get('byteStride', width)
    start = view.get('byteOffset', 0) + accessor.get('byteOffset', 0)
    values = b''.join(binary[start + n * stride:start + n * stride + width] for n in range(accessor['count']))
    return {'count': accessor['count'], 'type': accessor['type'], 'componentType': accessor['componentType'], 'sha256': digest(values)}


def object_signatures(document, binary):
    result = {}
    for node_index, node in enumerate(document.get('nodes', [])):
        if 'mesh' not in node:
            continue
        primitives = []
        for primitive in document['meshes'][node['mesh']]['primitives']:
            primitives.append({
                'attributes': {key: accessor_signature(document, binary, value) for key, value in primitive['attributes'].items()},
                'indices': accessor_signature(document, binary, primitive['indices']),
            })
        result[node.get('name', f'node_{node_index}')] = {
            'transform': {key: node[key] for key in ('matrix', 'translation', 'rotation', 'scale') if key in node},
            'primitives': primitives,
        }
    return result


records = {}
for role, path in [('source', root / 'source/upper-refined.glb')] + [(name, root / f'prepared/{name}.glb') for name in ['assembled', 'head-only', 'base']]:
    document, binary, sha = read_glb(path)
    images = [digest(view_bytes(document, binary, entry['bufferView'])) for entry in document.get('images', [])]
    records[role] = {'sha256': sha, 'embedded_image_hashes': images, 'objects': object_signatures(document, binary)}

assert records['source']['sha256'] == '11eed7c4933ebcc337041d470f8c36bfcc05891527680d9e550f7d82a8b2d444'
for role in ['assembled', 'head-only']:
    assert set(records['source']['embedded_image_hashes']).issubset(set(records[role]['embedded_image_hashes'])), (role, 'original embedded texture bytes changed')
for name, signature in records['head-only']['objects'].items():
    assert records['assembled']['objects'][name] == signature, (name, 'upper export differs')
for name, signature in records['base']['objects'].items():
    assert records['assembled']['objects'][name] == signature, (name, 'base export differs')
assert set(records['head-only']['objects']).isdisjoint(records['base']['objects'])
assert set(records['assembled']['objects']) == set(records['head-only']['objects']) | set(records['base']['objects'])
assert all(name.startswith('acid_yaw_') for name in records['head-only']['objects'])
assert all('tank_' not in name for name in records['head-only']['objects'])
report = {'passed': True, 'same_upper_geometry_and_transform': True, 'same_base_geometry_and_transform': True, 'original_embedded_texture_bytes_preserved': True, 'models': records}
(root / 'model-integrity.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
print(json.dumps({key: value for key, value in report.items() if key != 'models'}, indent=2))
