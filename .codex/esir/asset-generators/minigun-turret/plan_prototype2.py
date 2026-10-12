"""Verify the measured handoff and write a render schedule; no Blender/Meshy mutation."""
import argparse
import hashlib
import json
import struct
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont


def source_arrays(path):
    data = path.read_bytes()
    magic, version, length = struct.unpack_from('<III', data, 0)
    assert magic == 0x46546C67 and version == 2 and length == len(data)
    offset, document, binary = 12, None, None
    while offset < len(data):
        size, kind = struct.unpack_from('<II', data, offset)
        offset += 8
        chunk = memoryview(data)[offset:offset + size]
        if kind == 0x4E4F534A:
            document = json.loads(bytes(chunk))
        elif kind == 0x004E4942:
            binary = chunk
        offset += size
    assert document is not None and binary is not None
    assert len(document['meshes']) == 1
    mesh_nodes = [n for n in document['nodes'] if 'mesh' in n]
    assert len(mesh_nodes) == 1
    for node in document['nodes']:
        assert 'translation' not in node and 'rotation' not in node and 'scale' not in node
        assert 'matrix' not in node or np.allclose(np.array(node['matrix']).reshape(4, 4), np.eye(4))

    def accessor(index):
        item = document['accessors'][index]
        assert 'sparse' not in item
        view = document['bufferViews'][item['bufferView']]
        assert view.get('buffer', 0) == 0
        dtype = {5126: '<f4', 5125: '<u4', 5123: '<u2'}[item['componentType']]
        columns = {'VEC3': 3, 'SCALAR': 1}[item['type']]
        stride = view.get('byteStride', np.dtype(dtype).itemsize * columns)
        start = view.get('byteOffset', 0) + item.get('byteOffset', 0)
        return np.ndarray((item['count'], columns), dtype=dtype, buffer=binary,
                          offset=start, strides=(stride, np.dtype(dtype).itemsize)).copy()

    primitives = document['meshes'][0]['primitives']
    assert len(primitives) == 1 and primitives[0].get('mode', 4) == 4
    primitive = primitives[0]
    raw = accessor(primitive['attributes']['POSITION'])
    vertices = np.column_stack((raw[:, 0], -raw[:, 2], raw[:, 1])).astype(np.float64)
    triangles = accessor(primitive['indices']).reshape(-1, 3)
    return vertices, triangles


def canonical(points, coordinates):
    result = np.empty_like(points, dtype=np.float64)
    bx, by = coordinates['yaw_pivot_xy_source']
    result[..., 0] = points[..., 1] - by
    result[..., 1] = -(points[..., 0] - bx)
    result[..., 2] = points[..., 2] - coordinates['ground_z_source']
    return result * coordinates['uniform_scale']


def diagram(centers, labels, spec, destination):
    # Scientific point plot of triangle centroids, not a model render or edited concept image.
    width, height = 1680, 720
    canvas = Image.new('RGB', (width, height), '#10151a')
    draw = ImageDraw.Draw(canvas)
    font_path = Path('C:/Windows/Fonts/consola.ttf')
    font = ImageFont.truetype(str(font_path), 18) if font_path.exists() else ImageFont.load_default()
    title = ImageFont.truetype(str(font_path), 24) if font_path.exists() else font
    draw.text((24, 18), 'PROTOTYPE 2 / MEASURED PARTITION / CANDIDATE RIG', font=title, fill='#e9edf0')
    draw.text((24, 53), 'Blue = fixed base   Grey = yaw upper   Amber = spinning barrels + collars', font=font, fill='#bbc6cf')
    palette = np.array([[77, 169, 213], [168, 177, 180], [233, 173, 62]], dtype=np.uint8)
    root = np.array(spec['partition']['rotor_axis_root_source'])
    muzzle = np.array(spec['partition']['rotor_axis_muzzle_source'])
    bearing = np.array([*spec['coordinates']['yaw_pivot_xy_source'], spec['partition']['base_centroid_z_less_than']])
    views = [(0, 2, 1, 'SIDE: X / Z'), (1, 2, 0, 'FRONT: Y / Z'), (0, 1, 2, 'TOP: X / Y')]
    # All face centroids participate, sorted by depth, so the part boundary is visible.
    for panel, (horizontal, vertical, depth, label) in enumerate(views):
        left, top, boxw, boxh = 24 + panel * 552, 120, 528, 460
        low = centers[:, [horizontal, vertical]].min(axis=0)
        high = centers[:, [horizontal, vertical]].max(axis=0)
        scale = min((boxw - 40) / (high[0] - low[0]), (boxh - 40) / (high[1] - low[1]))
        center = (low + high) / 2

        def project(points):
            uv = points[..., [horizontal, vertical]] - center
            return np.column_stack((boxw / 2 + uv[..., 0] * scale,
                                    boxh / 2 - uv[..., 1] * scale))

        xy = np.rint(project(centers)).astype(int)
        order = np.argsort(centers[:, depth])
        if depth == 0:
            order = order[::-1]  # Looking into the forward muzzle, toward +X.
        pixels = np.zeros((boxh, boxw, 3), dtype=np.uint8)
        pixels[:] = (20, 28, 34)
        pixels[xy[order, 1], xy[order, 0]] = palette[labels[order]]
        canvas.paste(Image.fromarray(pixels), (left, top))
        draw.rectangle((left, top, left + boxw, top + boxh), outline='#475560', width=1)
        draw.text((left + 12, top + boxh + 12), label, font=font, fill='#c8d2da')
        axis = project(np.array([root, muzzle])) + np.array([left, top])
        draw.line([tuple(axis[0]), tuple(axis[1])], fill='#ff5353', width=3)
        pivot = project(np.array([bearing]))[0] + np.array([left, top])
        draw.ellipse((pivot[0]-5, pivot[1]-5, pivot[0]+5, pivot[1]+5), outline='#58f0ae', width=2)
    draw.text((24, 644), 'Red = candidate bore axis   Green = yaw pivot   Source coordinates before fit', font=font, fill='#c8d2da')
    draw.text((24, 675), 'This verifies selection ownership. Seams, caps, axis wobble and animation are not yet render-tested.', font=font, fill='#e3bb76')
    canvas.save(destination)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--spec', type=Path, default=Path(__file__).with_name('prototype-2-rig-spec.json'))
    parser.add_argument('--output-dir', type=Path)
    args = parser.parse_args()
    spec = json.loads(args.spec.read_text(encoding='utf-8'))
    output = args.output_dir or Path(spec['outputs']['root'])
    output.mkdir(parents=True, exist_ok=True)
    source = Path(spec['source']['path'])
    digest = hashlib.sha256(source.read_bytes()).hexdigest()
    assert digest == spec['source']['sha256'], 'Different model: remeasure before applying cuts.'
    vertices, triangles = source_arrays(source)
    assert len(vertices) == spec['source']['vertices'] and len(triangles) == spec['source']['triangles']
    centers = vertices[triangles].mean(axis=1)
    partition = spec['partition']
    root = np.array(partition['rotor_axis_root_source'])
    muzzle = np.array(partition['rotor_axis_muzzle_source'])
    axis = muzzle - root
    axis /= np.linalg.norm(axis)
    relative = centers - root
    radial = np.linalg.norm(relative - np.outer(relative @ axis, axis), axis=1)
    base = centers[:, 2] < partition['base_centroid_z_less_than']
    rotor = (~base) & (centers[:, 0] < partition['rotor_centroid_x_less_than']) & (radial < partition['rotor_axis_radius_less_than'])
    upper = ~(base | rotor)
    counts = {name: int(mask.sum()) for name, mask in [('base', base), ('upper', upper), ('rotor', rotor)]}
    assert counts == partition['expected_triangle_counts'], counts
    assert sum(counts.values()) == len(triangles)
    fitted_base = canonical(vertices[np.unique(triangles[base])], spec['coordinates'])
    assert np.max(np.abs(fitted_base[:, :2])) <= 1.5, 'Base exceeds selection footprint.'
    fitted_axis = canonical(np.array([root, muzzle]), spec['coordinates'])
    direction_count, phases = spec['motion']['directions'], spec['motion']['phases']
    jobs = []
    for chunk in range(direction_count // spec['atlas']['directions_per_chunk']):
        start = chunk * spec['atlas']['directions_per_chunk']
        jobs.append({'chunk': chunk, 'directions': list(range(start, start + 16)),
                     'frames_one_based_inclusive': [1 + start * phases, (start + 16) * phases],
                     'beauty_frames': 16 * phases, 'ground_shadow_phase_zero_frames': 16,
                     'stripe': f'minigun-attack-{chunk:02}.png', 'status': 'planned_not_rendered'})
    assert [j['frames_one_based_inclusive'] for j in jobs][0][0] == 1
    assert jobs[-1]['frames_one_based_inclusive'][1] == 4096
    color = np.prod(spec['budget']['illustrative_color_cell']).item()
    shadow = np.prod(spec['budget']['illustrative_shadow_cell']).item()
    memory = 4 * (color * direction_count * (phases + 1) + shadow * direction_count) / 2**20
    report = {'status': 'planning_validation_passed_rig_unbuilt', 'source_sha256': digest,
              'triangle_partition': counts, 'triangles_exhaustively_assigned': True,
              'canonical_base_bounds': [fitted_base.min(axis=0).tolist(), fitted_base.max(axis=0).tolist()],
              'source_rotor_axis_unit': axis.tolist(), 'canonical_rotor_root_and_muzzle': fitted_axis.tolist(),
              'canonical_bearing_height': (partition['base_centroid_z_less_than'] - spec['coordinates']['ground_z_source']) * spec['coordinates']['uniform_scale'],
              'planned_beauty_frames': direction_count * phases,
              'illustrative_rgba_mib_native32': memory, 'illustrative_rgba_mib_detail64': memory * 4,
              'unresolved_by_this_check': ['physical seam closure', 'spin-axis visual wobble', 'native timing and shot parity',
                   'full-pose camera and crop bounds', 'muzzle calibration', 'engine graphics memory and visual acceptance']}
    (output / 'planning-report.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
    (output / 'render-job-plan.json').write_text(json.dumps(jobs, indent=2) + '\n', encoding='utf-8')
    labels = np.ones(len(triangles), dtype=np.uint8)
    labels[base], labels[rotor] = 0, 2
    diagram(centers, labels, spec, output / 'rig-partition.png')
    print(json.dumps(report, indent=2))


if __name__ == '__main__':
    main()
