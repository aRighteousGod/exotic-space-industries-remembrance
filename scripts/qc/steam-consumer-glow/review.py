"""Build labeled contact sheets without modifying the native screenshots."""
import json
from pathlib import Path
import sys
from PIL import Image, ImageDraw

root = Path(sys.argv[1]) / 'script-output/steam-glow'
acceptance = json.loads((root / 'acceptance.json').read_text())
names = acceptance['consumers']
columns = [(mode, state) for mode in ('baseline', 'on', 'off') if (root / mode).is_dir()
           for state in ('working', 'starved')]
for page in range(2):
    subset = names[page * 5:(page + 1) * 5]
    sheet = Image.new('RGB', (len(columns) * 384, len(subset) * 350 + 25), '#202020')
    draw = ImageDraw.Draw(sheet)
    for column, (mode, state) in enumerate(columns):
        draw.text((column * 384 + 8, 7), f'{mode} / {state}', fill='white')
        for row, name in enumerate(subset):
            with Image.open(root / mode / f'{name}-{state}.png') as native:
                assert native.size == (768, 640), (name, native.size)
                preview = native.convert('RGB').resize((384, 320), Image.Resampling.LANCZOS)
            y = 25 + row * 350
            sheet.paste(preview, (column * 384, y))
            draw.text((column * 384 + 8, y + 325), name, fill='white')
    sheet.save(root / f'review-{page + 1}.png')
print('Wrote review-1.png and review-2.png; native captures retained separately.')
