"""Assemble only hash-verified native movement frames; no generated motion."""
import argparse,hashlib,json,pathlib
from PIL import Image,ImageDraw,ImageFont
p=argparse.ArgumentParser();p.add_argument('--evidence',type=pathlib.Path,required=True);a=p.parse_args()
inventory=json.loads((a.evidence/'observer-functional-frames.json').read_text())
source={}
for entry in inventory:
    path=pathlib.Path(entry['absolute_path']);assert hashlib.sha256(path.read_bytes()).hexdigest()==entry['sha256']
    if entry['scene'].startswith('movement-'):source[int(entry['scene'].split('-')[1])]=path
font=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',18);frames=[]
for age in range(87,114,3):
    frame=Image.new('RGB',(1000,410),'#172128');draw=ImageDraw.Draw(frame)
    for column,(tick,title) in enumerate(((age,'Connected machine port: walking blocked'),(age+42,'Recipe cleared and refreshed: walking allowed'))):
        frame.paste(Image.open(source[tick]).convert('RGB').resize((500,375)),(500*column,35))
        draw.text((500*column+8,8),title,font=font,fill='white')
    frames.append(frame)
out=a.evidence/'observer-movement.webp'
frames[0].save(out,save_all=True,append_images=frames[1:],duration=180,loop=0,quality=85,method=6)
frames[-1].save(a.evidence/'observer-movement-final.png')
(a.evidence/'observer-render.json').write_text(json.dumps(dict(passed=True,engine='2.1.24',frames=len(frames),
    source='native take_screenshot frames; slowed playback',sha256=hashlib.sha256(out.read_bytes()).hexdigest()),indent=2))
print(out)
