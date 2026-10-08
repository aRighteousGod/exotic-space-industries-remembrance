"""Retain a real-engine sweep animation and a compact day/night review board."""
from pathlib import Path
from PIL import Image, ImageDraw

source = Path('.factorio-qc/anisetron/aligned-art/script-output/anisetron-art')
output = Path('output/meshy/anisetron')
frames = [Image.open(path).convert('RGB') for path in sorted((source/'strafe').glob('*.png'))]
assert len(frames) == 24
frames[0].save(output/'strafe-preview.gif', save_all=True, append_images=frames[1:],
               duration=67, loop=0, optimize=False)
board = Image.new('RGB',(1536,800),(24,24,24))
draw = ImageDraw.Draw(board)
for x,lighting in enumerate(('day','night')):
    board.paste(Image.open(source/f'pose-4-{lighting}.png').convert('RGB'),(x*768,32))
    draw.text((x*768+20,10),f'ANISETRON / original Meshy chapel / {lighting}',fill=(230,225,205))
board.save(output/'engine-day-night.png')
print('Retained 24-frame sweep GIF (half-speed review) and day/night board.')
