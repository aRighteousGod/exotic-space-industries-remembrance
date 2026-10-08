"""Check prepared source-preservation evidence, exact anchors and rendered pass bounds."""
import argparse
import hashlib
import json
from pathlib import Path

from PIL import Image

parser = argparse.ArgumentParser()
parser.add_argument('--bundle', required=True, type=Path)
parser.add_argument('--output', required=True, type=Path)
args = parser.parse_args()
manifest = json.loads((args.bundle/'factorio-preset-render-manifest.json').read_text())
preflight = manifest['preflight']
metadata = preflight['anisetron_preparation']
assert metadata['source_faces'] == metadata['preserved_source_faces'] == 1031452
assert metadata['source_vertices'] == 546599
for key in ('unique_source_face_ids', 'prepared_triangle_geometry_exact', 'face_uv_exact', 'architecture_pbr_unchanged'):
    assert metadata['preservation'][key], key
assert metadata['direction_count'] == preflight['anisetron_direction_count'] == 128
assert metadata['front_axis'] == '+Y' and metadata['prepared_yaw_degrees'] == 180
assert metadata['projected_tiles']['width'] <= 6.00001 and metadata['projected_tiles']['height'] <= 8.00001
assert abs(metadata['bounds_tiles']['min'][2]) < .00001
anchors = preflight['anisetron_anchor_pixels']
assert set(anchors) == {'top_crystal', 'facade', 'keel_left', 'keel_center', 'keel_right'}
for name, points in anchors.items():
    assert len(points) == 128
    assert [point['direction'] for point in points] == list(range(128))
    assert [point['orientation'] for point in points] == [i/128 for i in range(128)]
rows = []
for role in ('Object', 'Shadow', 'Light A Reduced', 'ColorMask'):
    paths = sorted((args.bundle/role).glob('*.png'))
    assert len(paths) == manifest['directions'], role
    for path in paths:
        image = Image.open(path).convert('RGBA')
        assert image.size == (512, 512)
        bounds = image.getchannel('A').getbbox()
        margin = min(bounds[0], bounds[1], 512-bounds[2], 512-bounds[3]) if bounds else None
        if bounds:
            assert margin >= 16, (role, path, bounds)
        else:
            assert role == 'ColorMask', (role, path)
        rows.append({'role': role, 'file': path.name, 'alpha_bounds': bounds, 'margin_px': margin,
                     'sha256': hashlib.sha256(path.read_bytes()).hexdigest()})
report = {'pass': True, 'rendered_directions': manifest['directions'], 'anchor_directions': 128,
          'source_sha256': metadata['source_sha256'], 'preservation': metadata['preservation'],
          'source_face_uv_sha256': metadata['source_face_uv_sha256'],
          'prepared_triangle_geometry_sha256': metadata['prepared_triangle_geometry_sha256'],
          'role_faces': metadata['role_faces'], 'prepared_anchors': metadata['anchors'],
          'minimum_margin_px': min(row['margin_px'] for row in rows if row['margin_px'] is not None),
          'frames': rows, 'scope': 'Reference17 raw render geometry, UV, anchor and transparency QC; shipping integrity and native gameplay use separate reports.'}
args.output.parent.mkdir(parents=True, exist_ok=True)
args.output.write_text(json.dumps(report, indent=2), encoding='utf-8')
print(json.dumps({key: report[key] for key in ('pass', 'rendered_directions', 'anchor_directions', 'minimum_margin_px')}))
