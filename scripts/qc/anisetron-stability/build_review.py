"""Package unretouched native captures; compressed loops are previews only."""
import argparse
import json
from pathlib import Path
from PIL import Image, ImageDraw

p = argparse.ArgumentParser()
p.add_argument('--root', type=Path, default=Path('.factorio-qc/anisetron'))
p.add_argument('--output', type=Path, required=True)
args = p.parse_args()
args.output.mkdir(parents=True, exist_ok=True)
source = args.root/'stability-roots/script-output/anisetron-stability'
labels = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW']
for light in ['day', 'night']:
    board = Image.new('RGB', (2048, 1072), '#10151b')
    draw = ImageDraw.Draw(board)
    for i, name in enumerate(labels):
        x, y = i%4*512, i//4*536
        board.paste(Image.open(source/f'motion-{light}-h{i}/0240.png').convert('RGB'), (x, y+24))
        draw.text((x+12, y+6), f'{name} - native zoom 1', fill='white')
    board.save(args.output/f'trails-{light}-eight-headings.webp', lossless=True)
    frames = []
    for tick in range(180, 601, 12):
        frame = Image.new('RGB', (1024, 512))
        for x, heading in [(0, 0), (512, 1)]:
            frame.paste(Image.open(source/f'motion-{light}-h{heading}/{tick:04}.png').convert('RGB'), (x, 0))
        frames.append(frame)
    frames[0].save(args.output/f'north-northeast-{light}.webp', save_all=True,
        append_images=frames[1:], duration=200, loop=0, quality=88, method=4)
turns = args.root/'stability-tracking/script-output/anisetron-regression/turning-dense'
frames = [Image.open(path).convert('RGB') for path in sorted(turns.glob('*.png'))[::2]]
frames[0].save(args.output/'turning-beams.webp', save_all=True, append_images=frames[1:],
    duration=67, loop=0, quality=88, method=4)
report = {'source': str(args.root), 'boards': 'Lossless native pixels, labels outside captures',
          'loops': 'Native-size lossy WebP previews; north/NE at recorded 12-tick cadence, beam turn at 2x slow motion',
          'files': {f.name: f.stat().st_size for f in args.output.glob('*.webp')}}
assert all(size < 10*1024*1024 for size in report['files'].values())
(args.output/'manifest.json').write_text(json.dumps(report, indent=2)+'\n')
print(json.dumps(report))
