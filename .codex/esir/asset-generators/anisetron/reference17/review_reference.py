"""Build a common-framing inspection board from any number of raw preset directions."""
import argparse
import json
import math
from pathlib import Path
from PIL import Image, ImageDraw

parser = argparse.ArgumentParser()
parser.add_argument('--bundle',type=Path,required=True)
parser.add_argument('--output',type=Path,required=True)
parser.add_argument('--turntable-output',type=Path)
args = parser.parse_args()
paths = sorted((args.bundle/'Object').glob('*.png'))
assert paths, 'No object frames'
images, bounds = [], []
for path in paths:
    body = Image.open(path).convert('RGBA')
    shadow_path = args.bundle/'Shadow'/path.name
    shadow = Image.open(shadow_path).convert('RGBA') if shadow_path.exists() else Image.new('RGBA',body.size)
    shadow.putalpha(shadow.getchannel('A').point(lambda value:round(value*.45)))
    combined = Image.alpha_composite(shadow,body)
    bounds.append(combined.getchannel('A').getbbox())
    images.append(combined)
crop = (max(0,min(box[0] for box in bounds)-16),max(0,min(box[1] for box in bounds)-16),
    min(images[0].width,max(box[2] for box in bounds)+16),min(images[0].height,max(box[3] for box in bounds)+16))
columns,cell = min(4,len(paths)),512
rows = math.ceil(len(paths)/columns)
board = Image.new('RGB',(columns*cell,rows*cell),(35,39,43))
draw = ImageDraw.Draw(board)
manifest = json.loads((args.bundle/'factorio-preset-render-manifest.json').read_text())
turntable = []
for index,image in enumerate(images):
    view = image.crop(crop)
    scale = min((cell-24)/view.width,(cell-44)/view.height)
    view = view.resize((round(view.width*scale),round(view.height*scale)),Image.Resampling.LANCZOS)
    x,y = index%columns*cell,index//columns*cell
    board.paste(view,(x+(cell-view.width)//2,y+(cell-34-view.height)//2),view)
    yaw = (manifest['initial_angle']+index*360/len(paths))%360
    draw.text((x+16,y+cell-24),f'ANISETRON 17 / source yaw {yaw:g}',fill=(215,225,225))
    frame = Image.new('RGB',(cell,cell),(35,39,43))
    frame.paste(view,((cell-view.width)//2,(cell-34-view.height)//2),view)
    ImageDraw.Draw(frame).text((16,cell-24),f'ANISETRON 17 / source yaw {yaw:g}',fill=(215,225,225))
    turntable.append(frame)
args.output.parent.mkdir(parents=True,exist_ok=True)
board.save(args.output)
if args.turntable_output:
    args.turntable_output.parent.mkdir(parents=True,exist_ok=True)
    turntable[0].save(args.turntable_output,save_all=True,append_images=turntable[1:],duration=450,loop=0)
print(json.dumps({'directions':len(paths),'board':str(args.output),'crop':crop}))
