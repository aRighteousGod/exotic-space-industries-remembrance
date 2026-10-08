"""Verify every staged128 sheet cell against its raw pass and all exported anchors."""
import argparse
import hashlib
import json
from pathlib import Path

from PIL import Image

parser = argparse.ArgumentParser()
parser.add_argument('--bundle', required=True, type=Path)
parser.add_argument('--package', required=True, type=Path)
args = parser.parse_args()
manifest = json.loads((args.bundle/'factorio-preset-render-manifest.json').read_text())
report = json.loads((args.package/'asset-qc.json').read_text())
assert not report['preview'] and report['directions'] == report['source_directions'] == 128
assert report['slice'] == report['line_length'] == report['lines_per_file'] == 8
assert report['render_attachment_lift'] == .625
roles = {'anisetron': 'Object', 'anisetron_shadow': 'Shadow',
         'anisetron_glow': 'Light A Reduced', 'anisetron_mask': 'ColorMask'}
cells = 0
for role, folder in roles.items():
    filenames = report['filenames'][role]
    assert len(filenames) == 2
    for part, filename in enumerate(filenames):
        image = Image.open(args.package/'graphics/entities/anisetron'/filename).convert('RGBA')
        assert image.size == (4096, 4096)
        for local in range(64):
            i = part*64+local
            x, y = local%8*512, local//8*512
            raw = Image.open(args.bundle/folder/f'{i+1:04}.png').convert('RGBA')
            assert image.crop((x, y, x+512, y+512)).tobytes() == raw.tobytes(), (role, i)
            cells += 1
for path, expected in report['sha256'].items():
    assert hashlib.sha256((args.package/path).read_bytes()).hexdigest() == expected, path
points = manifest['preflight']['anisetron_anchor_pixels']
scale = manifest['preflight']['anisetron_sprite_scale']
anchors = 0
for name, values in points.items():
    for i, point in enumerate(values):
        actual = report['anchor_lookup'][name][i]
        expected = [i/128, [(point['anchor'][j]-point['pivot'][j])*scale/32 for j in range(2)]]
        assert actual == expected, (name, i)
        anchors += 1
output = {'pass': True, 'directions': 128, 'pass_cells_byte_exact': cells,
          'anchors_exact': anchors, 'png_hashes_match': len(report['sha256']),
          'render_attachment_lift': .625,
          'scope': 'Staged split sheets and camera-derived anchors; no shipping promotion or runtime proof.'}
(args.package/'package-integrity-qc.json').write_text(json.dumps(output, indent=2), encoding='utf-8')
print(json.dumps(output))
