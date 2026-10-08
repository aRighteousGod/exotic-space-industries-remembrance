"""Encode native-pixel day/night evidence; never brighten or repaint captures."""
import argparse
import json
from pathlib import Path
from PIL import Image

parser = argparse.ArgumentParser()
parser.add_argument('--art', type=Path, required=True)
parser.add_argument('--output', type=Path, required=True)
args = parser.parse_args()
manifest = json.loads((args.art/'captures.json').read_text())
args.output.mkdir(parents=True, exist_ok=True)
products = []
for role in ('motion', 'fire'):
    for light in ('day', 'night'):
        rows = [r for r in manifest['frames'] if r['role'] == role and r['light'] == light]
        frames = [Image.open(args.art.parent/r['path']).convert('RGB') for r in rows]
        path = args.output/f'{role}-{light}.webp'
        frames[0].save(path, save_all=True, append_images=frames[1:], duration=133, loop=0,
                       format='WEBP', quality=92, method=4)
        assert path.stat().st_size <= 10_000_000
        products.append({'path': str(path), 'bytes': path.stat().st_size, 'frames': len(frames),
                         'native_pixel_size': list(frames[0].size), 'engine_zoom': 1})
(args.output/'previews.json').write_text(json.dumps({'fidelity': manifest['fidelity'], 'products': products}, indent=2)+'\n')
print(json.dumps(products))
