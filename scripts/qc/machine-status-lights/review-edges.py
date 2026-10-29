"""Check native colored lens regions for remaining red, with manual edge galleries."""
import hashlib
import json
import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image

run = Path(sys.argv[1])
repo = Path(__file__).resolve().parents[3]
root = run / 'script-output/machine-lights'
final = json.loads((root / 'status-final.json').read_text())
scenes = json.loads((root / 'status-visual.json').read_text())['captures']
manifest = run / 'lens-art/manifest.json'
masks = json.loads(manifest.read_text())['records']
records, hashes = [], {}
for scene in scenes:
    name = scene['name']
    lenses = [r for r in masks if r['name'] == name]
    if not lenses:
        continue
    scale = final['snapshot'][name]['graphics_set']['animation'].get('scale', 1)
    for lighting in ('day', 'night'):
        for zoom in (1, 2):
            path = root / 'status' / f'{name}-{lighting}-{zoom}.png'
            assert path.stat().st_mtime >= manifest.stat().st_mtime, 'Capture predates final mask: ' + path.name
            hashes[path.name] = hashlib.sha256(path.read_bytes()).hexdigest()
            with Image.open(path) as atlas:
                for row in scene['rows']:
                    if row['state'] not in ('working', 'full-output', 'low-power'):
                        continue
                    for lens, offset in zip(lenses, final['expected'][name]):
                        cx = atlas.width / 2 + (row['position'][0] + offset[0]) * 32 * zoom
                        cy = atlas.height / 2 + (row['position'][1] + offset[1]) * 32 * zoom
                        left, top = math.floor(cx) - 32, math.floor(cy) - 32
                        rgb = np.array(atlas.crop((left, top, left + 64, top + 64)).convert('RGB'), dtype=float)
                        alpha = Image.open(repo / 'exotic-space-industries-remembrance-graphics-6/graphics/status-lights' / lens['file']).getchannel('A')
                        inverse = 1 / (scale * zoom)
                        coverage = np.array(alpha.transform((64, 64), Image.Transform.AFFINE,
                            (inverse, 0, 32 + (left - cx) * inverse,
                             0, inverse, 32 + (top - cy) * inverse), Image.Resampling.BILINEAR))
                        r, g, b = (rgb[:, :, index] for index in range(3))
                        # At night the orange point light further reduces green
                        # in the already orange lens. Distinguish near-pure red
                        # leakage (G/R < 1/8), not legitimate darker orange.
                        ratio = {'working': 1.1, 'full-output': 1.35, 'low-power': 8}[row['state']]
                        opaque = coverage >= 254
                        red = opaque & (r > 80) & (r - np.maximum(g, b) > 24) & (r > ratio * g)
                        records.append(dict(name=name, lens=lens['index'], state=row['state'],
                            lighting=lighting, zoom=zoom, direction=row['direction'],
                            opaque_pixels=int(opaque.sum()), red_pixels=int(red.sum())))
report = dict(regions=len(records), red_pixels=sum(r['red_pixels'] for r in records),
              regions_with_red=sum(bool(r['red_pixels']) for r in records),
              small_regions_without_opaque_pixels=sum(not r['opaque_pixels'] for r in records),
              scope='Opaque projected lens pixels; manual galleries also inspect filtered borders and bezel fit',
              capture_sha256=hashes, records=records)
(run / 'review/native-lens-edges.json').write_text(json.dumps(report, indent=2) + '\n')
print(json.dumps({k: v for k, v in report.items() if k not in ('records', 'capture_sha256')}))
assert report['red_pixels'] == 0, 'Review remaining native red pixels in native-lens-edges.json'
