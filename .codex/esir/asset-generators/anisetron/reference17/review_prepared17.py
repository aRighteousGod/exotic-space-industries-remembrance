"""Review eight prepared passes and original-geometry anchors at common framing."""
import argparse
import json
from pathlib import Path

from PIL import Image, ImageDraw

parser = argparse.ArgumentParser()
parser.add_argument('--bundle', required=True, type=Path)
parser.add_argument('--output', required=True, type=Path)
args = parser.parse_args()
manifest = json.loads((args.bundle/'factorio-preset-render-manifest.json').read_text())
paths = sorted((args.bundle/'Object').glob('*.png'))
assert len(paths) in (8, 128)
count = len(paths)
anchors = manifest['preflight']['anisetron_anchor_pixels']
labels = ('N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW')
colors = {'top_crystal': (240, 110, 255), 'facade': (40, 220, 255),
          'keel_left': (120, 255, 110), 'keel_center': (120, 255, 110), 'keel_right': (120, 255, 110)}
images, all_bounds = [], []
for path in paths:
    body = Image.open(path).convert('RGBA')
    shadow = Image.open(args.bundle/'Shadow'/path.name).convert('RGBA')
    shadow.putalpha(shadow.getchannel('A').point(lambda value: round(value*.4)))
    image = Image.alpha_composite(shadow, body)
    for folder in ('Light A Reduced', 'ColorMask'):
        image = Image.alpha_composite(image, Image.open(args.bundle/folder/path.name).convert('RGBA'))
    images.append(image)
    all_bounds.append(image.getchannel('A').getbbox())
crop = (min(box[0] for box in all_bounds)-16, min(box[1] for box in all_bounds)-16,
        max(box[2] for box in all_bounds)+16, max(box[3] for box in all_bounds)+16)
cell = 512
scale = min((cell-24)/(crop[2]-crop[0]), (cell-64)/(crop[3]-crop[1]))
board, anchored = [Image.new('RGB', (2048, 1024), (35, 39, 43)) for _ in range(2)]
frames = []
for index, source_index in enumerate(range(0, count, count//8)):
    image = images[source_index]
    view = image.crop(crop).resize((round((crop[2]-crop[0])*scale), round((crop[3]-crop[1])*scale)), Image.Resampling.LANCZOS)
    x, y = (index%4)*cell+(cell-view.width)//2, (index//4)*cell+(cell-40-view.height)//2
    board.paste(view, (x, y), view)
    anchored.paste(view, (x, y), view)
    text = f'ANISETRON17 / {labels[index]} / original PBR + .65 emission'
    ImageDraw.Draw(board).text(((index%4)*cell+12, (index//4)*cell+cell-23), text, fill=(220, 225, 225))
    draw = ImageDraw.Draw(anchored)
    draw.text(((index%4)*cell+12, (index//4)*cell+cell-23), text, fill=(220, 225, 225))
    for name, points in anchors.items():
        px, py = points[index*16]['anchor']
        px, py = x+(px-crop[0])*scale, y+(py-crop[1])*scale
        draw.ellipse((px-4, py-4, px+4, py+4), fill=colors[name])
        draw.text((px+6, py-4), name, fill=colors[name])
    frame = Image.new('RGB', (cell, cell), (35, 39, 43))
    frame.paste(view, ((cell-view.width)//2, (cell-40-view.height)//2), view)
    ImageDraw.Draw(frame).text((12, cell-23), labels[index], fill=(220, 225, 225))
    frames.append(frame)
args.output.mkdir(parents=True, exist_ok=True)
board.save(args.output/'eight-prepared-directions.png')
anchored.save(args.output/'eight-anchors.png')
frames[0].save(args.output/'prepared-turntable.gif', save_all=True, append_images=frames[1:], duration=450, loop=0)
if count == 128:
    columns, small = 8, 256
    overview = Image.new('RGB', (columns*small, 16*small), (35, 39, 43))
    factor = min((small-12)/(crop[2]-crop[0]), (small-34)/(crop[3]-crop[1]))
    smooth = []
    for index, image in enumerate(images):
        view = image.crop(crop).resize((round((crop[2]-crop[0])*factor), round((crop[3]-crop[1])*factor)), Image.Resampling.LANCZOS)
        x, y = (index%columns)*small+(small-view.width)//2, (index//columns)*small+(small-24-view.height)//2
        overview.paste(view, (x, y), view)
        ImageDraw.Draw(overview).text(((index%columns)*small+6, (index//columns)*small+small-19),
                                     f'{index:03} / {index*360/count:g} degrees', fill=(220, 225, 225))
        view = image.crop(crop).resize((round((crop[2]-crop[0])*scale), round((crop[3]-crop[1])*scale)), Image.Resampling.LANCZOS)
        frame = Image.new('RGB', (cell, cell), (35, 39, 43))
        frame.paste(view, ((cell-view.width)//2, (cell-40-view.height)//2), view)
        ImageDraw.Draw(frame).text((12, cell-23), f'direction {index:03} / {index*360/count:g} degrees', fill=(220, 225, 225))
        smooth.append(frame)
    overview.save(args.output/'all-128-directions.png')
    smooth[0].save(args.output/'full128-turntable.gif', save_all=True, append_images=smooth[1:], duration=80, loop=0)
print(json.dumps({'review': str(args.output), 'views': count, 'crop': crop}))
