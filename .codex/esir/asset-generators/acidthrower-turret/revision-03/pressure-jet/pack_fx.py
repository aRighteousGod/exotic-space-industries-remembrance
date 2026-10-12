"""Losslessly pack locally rendered liquid FX; no machine artwork is modified."""
import argparse,hashlib,json
from pathlib import Path
from PIL import Image,ImageDraw
p=argparse.ArgumentParser();p.add_argument('--root',type=Path,required=True)
p.add_argument('--parts',nargs='+',default=['spine','droplet','splash','flecks']);args=p.parse_args()
root=args.root;out=root/'factorio-export';out.mkdir(parents=True,exist_ok=True)
records=[];preview=Image.new('RGB',(768,640),(30,34,31));draw=ImageDraw.Draw(preview)
for kind,count,object_size in [('spine',16,(64,32)),('droplet',16,(32,32)),('splash',24,(512,512)),('flecks',16,(96,96))]:
    if kind not in args.parts:continue
    for role,suffix in [('Object',''),('Shadow','-shadow')]:
        size=(80,32) if kind=='spine' and role=='Shadow' else object_size
        files=sorted((root/'renders'/kind/role).glob('*.png'))
        assert len(files)==count,(kind,role,len(files))
        sheet=Image.new('RGBA',(size[0]*4,size[1]*((count+3)//4)))
        frames=[]
        for i,path in enumerate(files):
            frame=Image.open(path).convert('RGBA');w,h=frame.size
            box=((w-size[0])//2,(h-size[1])//2,(w+size[0])//2,(h+size[1])//2)
            bounds=frame.getchannel('A').getbbox()
            assert not bounds or (bounds[0]>=box[0] and bounds[1]>=box[1] and bounds[2]<=box[2] and bounds[3]<=box[3]),(path,bounds,box)
            frame=frame.crop(box);frames.append(frame)
            sheet.paste(frame,((i%4)*size[0],(i//4)*size[1]))
        path=out/f'acid-pressure-{kind}{suffix}.png';sheet.save(path)
        records.append(dict(file=path.name,role=role,frames=count,frame_size=size,sha256=hashlib.sha256(path.read_bytes()).hexdigest()))
        if role=='Object':
            y={'spine':20,'droplet':100,'splash':150,'flecks':100}[kind]
            draw.text((12,y),kind,fill='white')
            frame=frames[4 if kind=='splash' else 0]
            if kind=='splash':preview.paste(frame,(180,128),frame)
            else:preview.paste(frame,(120,y),frame)
            frames[0].save(root/f'{kind}.gif',save_all=True,append_images=frames[1:],duration=45,loop=0,disposal=2)
preview.save(root/'effects-preview.png')
(root/'effect-qa.json').write_text(json.dumps({'all_pass':True,'source':'Factorio preset local Blender geometry','sheets':records},indent=2))
print(json.dumps(records))
