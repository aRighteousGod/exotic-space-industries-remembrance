"""Check radar review passes, raw-frame packing and local gallery references."""
import json
from pathlib import Path
from PIL import Image, ImageChops

root = Path.cwd() / 'output/meshy'
results = []
for asset in ('sweeping-radar', 'phased-array-radar'):
    render = root / asset / 'review/Render'
    passes = {'Object': 'object_0.png', 'Shadow': 'object_shadow_0.png'}
    if asset == 'phased-array-radar':
        passes['Light A'] = 'object_lightA_0.png'
    records = []
    red_pixels = 0
    white_pixels = 0
    for role, sheet_name in passes.items():
        sheet_path = render.parent / 'raw-packed' / sheet_name
        sheet = Image.open(sheet_path).convert('RGBA')
        for index in range(8):
            path = render / role / f'{index + 1:04d}.png'
            image = Image.open(path)
            assert image.mode == 'RGBA', (path, image.mode)
            assert image.size == (384, 384), (path, image.size)
            bounds = image.getchannel('A').getbbox()
            assert bounds, f'Empty alpha: {path}'
            margin = min(bounds[0], bounds[1], 384 - bounds[2], 384 - bounds[3])
            assert margin >= 8, (path, margin)
            packed_equal = None
            if sheet is not None:
                x, y = index % 4 * 384, index // 4 * 384
                crop = sheet.crop((x, y, x + 384, y + 384))
                # Shared packing zeros hidden RGB at alpha zero; visible color
                # and every alpha value must still match the raw frame exactly.
                visible = image.getchannel('A').point(lambda value: 255 if value else 0).convert('RGB')
                difference = ImageChops.difference(crop, image)
                packed_equal = (difference.getchannel('A').getbbox() is None
                    and ImageChops.multiply(difference.convert('RGB'), visible).getbbox() is None)
                assert packed_equal, ('Raw packed pixels differ', path, sheet_path)
            record = dict(pass_name=role, frame=index + 1, alpha_bounds=bounds,
                          minimum_margin=margin, packed_visible_rgba_equal=packed_equal)
            if role == 'Light A':
                pixels = list(image.getdata())
                record['red_pixels'] = sum(a > 0 and r > 100 and r > 2 * max(g, b) for r, g, b, a in pixels)
                record['white_pixels'] = sum(a > 0 and min(r, g, b) > 120 for r, g, b, a in pixels)
                red_pixels += record['red_pixels']
                white_pixels += record['white_pixels']
            records.append(record)
    if asset == 'phased-array-radar':
        assert red_pixels > 0 and white_pixels > 0, ('Missing emission', red_pixels, white_pixels)
    results.append(dict(asset=asset, frames=records, red_pixels=red_pixels, white_pixels=white_pixels))

gallery = root / 'radar-production/index.html'
from html.parser import HTMLParser
class Links(HTMLParser):
    def __init__(self):
        super().__init__()
        self.paths = []
    def handle_starttag(self, tag, attrs):
        for name, value in attrs:
            if name in ('href', 'src') and value and '://' not in value:
                self.paths.append(value)
links = Links()
links.feed(gallery.read_text(encoding='utf-8'))
for path in links.paths:
    assert (gallery.parent / path).resolve().exists(), f'Missing gallery link: {path}'
report = dict(assets=results, gallery_links_checked=len(links.paths),
              browser_interaction='not exercised: CUA reports no browser available',
              all_alpha_and_emission_checks_pass=True)
(root / 'radar-production/review-checks.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
print(json.dumps({k: v for k, v in report.items() if k != 'assets'}, indent=2))
for asset in results:
    mismatch = sum(frame['packed_visible_rgba_equal'] is False for frame in asset['frames'])
    print(asset['asset'], 'frames:', len(asset['frames']), 'packed mismatches:', mismatch,
          'red pixels:', asset['red_pixels'], 'white pixels:', asset['white_pixels'])
