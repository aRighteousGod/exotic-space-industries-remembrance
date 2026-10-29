"""Pack only new diagonal layers; never rewrite the seven cardinal/head PNGs."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import numpy as np
from PIL import Image, ImageDraw

parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--root',type=Path,required=True)
parser.add_argument('--promote',type=Path)
args=parser.parse_args();root=args.root
out=root/'sprites';out.mkdir(exist_ok=True)
poses=json.loads((root/'renders/base/verified-frame-poses.json').read_text())
assert len(poses)==4 and all(abs(p['world_yaw_degrees']-(45+i*90))<.001 for i,p in enumerate(poses))
records=[];diffuse=[]
for role,suffix in [('Object',''),('Shadow','_shadow'),('Glow','_glow'),('Owner','_mask')]:
    files=sorted((root/'renders/base'/role).glob('*.png'));assert len(files)==4
    sheet=Image.new('RGBA',(1280,320));bounds=[]
    for i,path in enumerate(files):
        source=Image.open(path).convert('RGBA');assert source.size==(448,448)
        bbox=source.getchannel('A').getbbox()
        if bbox:assert min(bbox[0]-64,bbox[1]-64,384-bbox[2],384-bbox[3])>=8,(role,i,bbox)
        rgba=np.array(source.crop((64,64,384,384)));rgba[rgba[:,:,3]==0,:3]=0
        frame=Image.fromarray(rgba);sheet.paste(frame,(i*320,0));bounds.append(frame.getchannel('A').getbbox())
        if role=='Object':diffuse.append(frame)
    name='acidthrower-base-diagonal'+suffix+'.png'
    path=out/name;sheet.save(path,optimize=True)
    records.append(dict(name=name,role=role,sha256=hashlib.sha256(path.read_bytes()).hexdigest(),bounds=bounds))
    if args.promote:
        assert args.promote.is_dir();shutil.copy2(path,args.promote/name)
gallery=Image.new('RGB',(1280,350),(30,34,36));draw=ImageDraw.Draw(gallery)
for i,frame in enumerate(diffuse):
    gallery.paste(frame,(i*320,30),frame);draw.text((i*320+12,10),['NE','SE','SW','NW'][i],fill='white')
gallery.save(root/'diagonal-base-review.png')
(root/'sprite-qa.json').write_text(json.dumps(dict(passed=True,frame_size=320,scale=.5,
    poses=poses,sheets=records,minimum_alpha_margin=8,existing_sheets_rewritten=False),indent=2))
print(json.dumps(dict(passed=True,sheets=4,review=str(root/'diagonal-base-review.png'))))
