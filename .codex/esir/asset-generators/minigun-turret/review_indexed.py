"""Offline assembled review of indexed-HD versus retained source densities."""
from pathlib import Path
from functools import lru_cache
import json,argparse
import numpy as np
from PIL import Image,ImageDraw,ImageFont

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--repo',type=Path,required=True);p.add_argument('--output',type=Path,required=True)
    a=p.parse_args();repo=a.repo.resolve();out=a.output.resolve();assert out.is_relative_to(repo/'output');out.mkdir(parents=True,exist_ok=True)
    meta=json.loads((repo/'output/minigun-implementation/finalized-minigun/graphics-data.json').read_text())
    variants=[('Original HD',repo/'minigun-turret-HD',meta['profiles']['hd']),
              ('Indexed HD',repo/'exotic-space-industries-remembrance-graphics-6',meta['profiles']['hd']),
              ('Original SD',repo/'output/minigun-implementation/holding/sd-32px-before-quantized-hd/assets',meta['profiles']['sd'])]
    @lru_cache(maxsize=24)
    def atlas(path):return Image.open(path).convert('RGBA')
    def frame(root,leaf,d,pose):
        count=leaf.get('frame_count',1);cell=d*count+(pose if count>1 else 0);cols=leaf['line_length']
        if 'filenames' in leaf:
            capacity=cols*leaf['lines_per_file'];filename=leaf['filenames'][cell//capacity];cell%=capacity
        else:filename=leaf['filename']
        w,h=leaf['width'],leaf['height'];x=(cell%cols)*w;y=(cell//cols)*h
        return atlas(root/filename.split('__/',1)[1]).crop((x,y,x+w,y+h))
    def assemble(variant,d,pose,bg):
        name,root,profile=variant;canvas=Image.new('RGBA',(540,540),(*bg,255))
        for leaf in [profile['shadow'],profile['base'],profile['upper']]+profile['rotor']['layers']:
            image=frame(root,leaf,0 if leaf is profile['base'] else d,pose)
            if leaf is profile['shadow']:
                # Preview-only shadow opacity. Native blending is checked separately.
                image.putalpha(image.getchannel('A').point(lambda v:round(v*.5)))
            factor=leaf['scale']*2
            if factor!=1:image=image.resize((round(image.width*factor),round(image.height*factor)),Image.Resampling.NEAREST)
            x=round(270+leaf['shift'][0]*64-image.width/2);y=round(315+(leaf['shift'][1]+6/32)*64-image.height/2)
            canvas.alpha_composite(image,(x,y))
        return canvas.convert('RGB').crop((50,35,490,435))
    font=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',18);rows=[]
    for name,cases in [('main',[(96,0),(96,1),(0,1),(224,0)]),('boundaries',[(7,1),(8,1),(63,0),(64,0),(127,1),(128,1),(255,1),(0,1)])]:
        sheet=Image.new('RGB',(1320,425*len(cases)),(24,26,24));draw=ImageDraw.Draw(sheet)
        for row,(d,pose) in enumerate(cases):
            bg=(55,58,52) if row%2==0 else (170,174,163)
            for col,v in enumerate(variants):
                image=assemble(v,d,pose,bg);sheet.paste(image,(col*440,row*425+25));draw.text((col*440+8,row*425+3),v[0]+f' / d{d:03} p{pose+1:02}',fill='white',font=font)
        sheet.save(out/(name+'.png'))
    # Fractional rendering smoke: complete assembled images, not separately resampled layers.
    sheet=Image.new('RGB',(1320,740),(24,26,24));draw=ImageDraw.Draw(sheet)
    for row,factor in enumerate([.75,1.25]):
        for col,v in enumerate(variants):
            im=assemble(v,96,1,(60,62,57)).resize((round(440*factor),round(400*factor)),Image.Resampling.BILINEAR)
            im=im.crop((max(0,(im.width-420)//2),max(0,(im.height-335)//2),max(0,(im.width-420)//2)+420,max(0,(im.height-335)//2)+335))
            sheet.paste(im,(col*440+10,row*365+28));draw.text((col*440+10,row*365+4),v[0]+f' / {factor}x',fill='white',font=font)
    sheet.save(out/'fractional.png')
    frames=[]
    large_font=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',32)
    for pose in [0,2,3,4,5,6,7,8,9,10,11,1]:
        sheet=Image.new('RGB',(2640,860),(24,26,24));draw=ImageDraw.Draw(sheet)
        for col,v in enumerate(variants):
            im=assemble(v,96,pose,(55,58,52)).resize((880,800),Image.Resampling.NEAREST)
            sheet.paste(im,(col*880,55));draw.text((col*880+20,12),v[0]+' / '+('256 colors' if col==1 else 'full color'),fill='white',font=large_font)
        frames.append(sheet)
    teaser=out/'hd-vs-indexed-hd-vs-sd-spin-up.webp'
    frames[0].save(teaser,save_all=True,append_images=frames[1:],duration=[900]+[85]*10+[1400],loop=0,lossless=True,method=6)
    assert teaser.stat().st_size<10_000_000
    print('Lossless production comparison',teaser.stat().st_size,'bytes; spin-up slowed for inspection')
    print('Offline review images:',out)

if __name__=='__main__':main()
