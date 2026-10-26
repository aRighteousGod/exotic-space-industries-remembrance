"""Verify promoted neutral masks against their reproducible source receipt."""
import hashlib
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

run = Path(sys.argv[1])
repo = Path(__file__).resolve().parents[3]
root = run / 'lens-art'
manifest = root / 'manifest.json'
rows = json.loads(manifest.read_text(encoding='utf-8'))['records']
shipping = repo / 'exotic-space-industries-remembrance/graphics/status-lights'
assert len(rows) == 23 and len({r['name'] for r in rows}) == 20
assert {p.name for p in shipping.glob('*.png')} == {r['file'] for r in rows}
sources = set()
for row in rows:
    path = shipping / row['file']
    assert hashlib.sha256(path.read_bytes()).hexdigest() == row['sha256'], row['file']
    pixels = np.array(Image.open(path))
    assert pixels.shape == (64, 64, 4), row['file']
    assert np.all(pixels[:, :, 0] == pixels[:, :, 1]) and np.all(pixels[:, :, 1] == pixels[:, :, 2]), row['file']
    assert set(np.unique(pixels[:, :, 3])) == {0, 255}, row['file']
    y, x = np.where(pixels[:, :, 3])
    assert [int(x.min()), int(y.min()), int(x.max()), int(y.max())] == row['bounds']
    assert min(x) > 0 and min(y) > 0 and max(x) < 63 and max(y) < 63, row['file']
    assert len(x) == row['opaque_pixels'] and row['edge_guard_pixels'] == 1
    assert row['opaque_pixels'] > row['lens_pixels'] >= row['seed_pixels']
    if row['name'] == 'ei-advanced-refinery':
        assert row['center'] == [470, 555] and row['coverage'] == 'whole-screen'
        assert row['lens_pixels'] > 500, 'Refinery must cover the entire inset screen'
    for source in row['sources']:
        sources.add(source['path'])
        assert hashlib.sha256((repo / source['path']).read_bytes()).hexdigest() == source['sha256'], source['path']
report = dict(status='ok', masks=23, bodies=20, source_files=len(sources),
              original_source_hashes_unchanged=True, shipping_hashes_match_manifest=True,
              edge_guard_pixels=1, refinery_coverage='whole-screen',
              manifest_sha256=hashlib.sha256(manifest.read_bytes()).hexdigest())
(root / 'acceptance.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
print(json.dumps(report))
