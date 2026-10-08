"""Review every directional pass and native engine screenshot without repainting."""
import argparse
from pathlib import Path
from PIL import Image, ImageDraw

p=argparse.ArgumentParser()
p.add_argument('--bundle',type=Path,required=True)
p.add_argument('--output',type=Path,required=True)
a=p.parse_args()
frames=sorted((a.bundle/'Object').glob('*.png'))
assert len(frames)==64
sheet=Image.new('RGB',(2048,2048),(35,39,43))
eight=Image.new('RGB',(1280,640),(35,39,43))
for i,path in enumerate(frames):
    frame=Image.new('RGBA',(512,512),(35,39,43,255))
    shadow=Image.open(a.bundle/'Shadow'/path.name).convert('RGBA')
    shadow.putalpha(shadow.getchannel('A').point(lambda value:round(value*.4)))
    frame=Image.alpha_composite(frame,shadow)
    for folder in ('Object','Light A Reduced','ColorMask'):
        frame=Image.alpha_composite(frame,Image.open(a.bundle/folder/path.name).convert('RGBA'))
    crop=frame.crop((130,35,505,340))
    cell=crop.copy();cell.thumbnail((250,230),Image.Resampling.LANCZOS)
    x,y=(i%8)*256,(i//8)*256
    sheet.paste(cell,(x,y));ImageDraw.Draw(sheet).text((x+5,y+240),str(i),(210,220,220))
    if i%8==0:
        cell=crop.copy();cell.thumbnail((315,300),Image.Resampling.LANCZOS)
        x,y=(i//8%4)*320,(i//32)*320
        eight.paste(cell,(x,y));ImageDraw.Draw(eight).text((x+8,y+303),('N','NE','E','SE','S','SW','W','NW')[i//8],(210,220,220))
a.output.mkdir(parents=True,exist_ok=True)
sheet.save(a.output/'all-64-directions.png');eight.save(a.output/'eight-directions.png')
