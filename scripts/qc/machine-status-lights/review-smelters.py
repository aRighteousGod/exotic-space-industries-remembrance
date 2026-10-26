"""Crop native smelter scenes, all directions, and circuit/energy transitions."""
import hashlib
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

run = Path(sys.argv[1])
root = run / 'script-output' / 'machine-lights'
output = run / 'review'
output.mkdir(exist_ok=True)
names = ['ei-arc-furnace', 'ei-plasma-heater', 'ei-caster']
states = ['working', 'idle', 'missing-input', 'full-output', 'disabled', 'no-power', 'low-power']
offsets = json.loads((root / 'status-final.json').read_text())['expected']
reports = {p: json.loads((root / (p + '-visual.json')).read_text()) for p in ('status', 'off-status', 'off')}
records = []
for profile in ('status', 'off-status'):
    for lighting in ('day', 'night'):
        body = Image.new('RGB', (1260, 670), '#242424')
        lamps = Image.new('RGB', (1040, 1080), '#242424')
        bd, ld = ImageDraw.Draw(body), ImageDraw.Draw(lamps)
        for s, state in enumerate(states):
            bd.text((s * 180 + 5, 5), state, fill='white')
            ld.text((190 + s * 120, 25), state, fill='white')
        ld.text((5, 5), profile + ' / ' + lighting + ' / native zoom 2', fill='white')
        for i, name in enumerate(names):
            rows = next(s['rows'] for s in reports[profile]['captures'] if s['name'] == name)
            bd.text((5, 28 + i * 210), name, fill='white')
            with Image.open(root / profile / f'{name}-{lighting}-2.png') as atlas:
                for d, direction in enumerate((0, 4, 8, 12)):
                    y = 50 + (i * 4 + d) * 84
                    ld.text((5, y + 8), name.removeprefix('ei-') + ' / ' + str(direction), fill='white')
                    for row in [r for r in rows if r['direction'] == direction]:
                        s = states.index(row['state'])
                        x = atlas.width / 2 + row['position'][0] * 64
                        z = atlas.height / 2 + row['position'][1] * 64
                        if d == 0:
                            crop = atlas.crop((round(x)-210, round(z)-210, round(x)+210, round(z)+210))
                            body.paste(crop.resize((176, 176)), (s * 180 + 2, 50 + i * 210))
                        cx = x + offsets[name][0][0] * 64
                        cy = z + offsets[name][0][1] * 64
                        lamps.paste(atlas.crop((round(cx)-54, round(cy)-30, round(cx)+54, round(cy)+30)), (190+s*120, y))
        body.save(output / f'{profile}-{lighting}-bodies.png')
        lamps.save(output / f'{profile}-{lighting}-lamps.png')
    canvas = Image.new('RGB', (1430, 315), '#242424')
    draw = ImageDraw.Draw(canvas)
    labels = ['circuit-disabled', 'circuit-resumed', 'energy-lost', 'energy-restored', 'output-blocked', 'output-cleared', 'power-limited', 'power-restored']
    transitions = json.loads((root / (profile + '-transitions.json')).read_text())['rows']
    for col, label in enumerate(labels):
        draw.text((190+155*col, 6), label, fill='white')
    for i, name in enumerate(names):
        draw.text((5, 45+i*88), name.removeprefix('ei-'), fill='white')
        for col, label in enumerate(labels):
            row = next(r for r in transitions if r['name'] == name and r['transition'] == label)
            path = root / (profile + '-transitions' if reports[profile]['scenes'] == 3 else 'transitions') / (name + '-' + label + '.png')
            with Image.open(path) as atlas:
                cx = 384 + (row['position'][0] + 72 + offsets[name][0][0])*64
                cy = 384 + (row['position'][1] + 36 + offsets[name][0][1])*64
                canvas.paste(atlas.crop((round(cx)-60, round(cy)-30, round(cx)+60, round(cy)+30)), (190+155*col, 32+88*i))
    canvas.save(output / (profile + '-transitions.png'))

# The idle capacitor glows are intentionally still present without energy.
# Compare the same native state/frame to prove only the new status light is dark.
for name in names:
    rows = next(s['rows'] for s in reports['status']['captures'] if s['name'] == name)
    paths = [root / p / f'{name}-night-1.png' for p in ('status', 'off')]
    with Image.open(paths[0]) as a, Image.open(paths[1]) as b:
        for row in rows:
            if row['state'] != 'no-power':
                continue
            cx = a.width/2 + (row['position'][0] + offsets[name][0][0])*32
            cy = a.height/2 + (row['position'][1] + offsets[name][0][1])*32
            box = (round(cx)-16, round(cy)-16, round(cx)+17, round(cy)+17)
            delta = np.array(a.crop(box).convert('RGB'), dtype=np.int16)-np.array(b.crop(box).convert('RGB'), dtype=np.int16)
            difference = int(np.abs(delta).max())
            assert difference == 0, (name, row['direction'], difference)
            records.append(dict(name=name, direction=row['direction'], max_difference=difference))
report = dict(no_energy_regions=records, source_sha256={str(p.relative_to(root)):hashlib.sha256(p.read_bytes()).hexdigest() for p in root.glob('*-visual.json')})
(output/'smelter-pixels.json').write_text(json.dumps(report, indent=2)+'\n')
print('Rendered no-energy status vs Off:', len(records), 'regions, exact match')
print(output)
