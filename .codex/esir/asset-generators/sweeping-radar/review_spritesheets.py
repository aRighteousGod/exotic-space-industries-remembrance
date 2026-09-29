"""Build contact sheets from staged, verified radar spritesheets for visual QA."""
import json
from pathlib import Path
from PIL import Image, ImageChops, ImageDraw

ROOT=Path.cwd()
destination=ROOT/'output/meshy/radar-production'
for asset in ('sweeping-radar','phased-array-radar'):
    export=ROOT/'output/meshy'/asset/'factorio-export/256'
    manifest=json.loads((export/'spritesheet-manifest.json').read_text())
    pages={p['filename']:Image.open(export/p['filename']).convert('RGBA')
           for layer in manifest['layers'].values() for p in layer['pages']}
    def pose(index,glow=True):
        canvas=Image.new('RGBA',(384,384),(89,96,90,255))
        for role in ('shadow','body','glow'):
            layer=manifest['layers'].get(role)
            if not layer or (role=='glow' and not glow):continue
            page=next(p for p in layer['pages'] if p['output_start']<=index<=p['output_end'])
            local=index-page['output_start'];w,h=layer['frame_size']
            x,y=local%page['columns']*w,local//page['columns']*h
            tile=pages[page['filename']].crop((x,y,x+w,y+h))
            placed=Image.new('RGBA',(384,384));placed.paste(tile,layer['crop'][:2])
            if role=='glow':
                light=ImageChops.multiply(placed.convert('RGB'),placed.getchannel('A').convert('RGB'))
                canvas=ImageChops.add(canvas.convert('RGB'),light).convert('RGBA')
            else:canvas=Image.alpha_composite(canvas,placed)
        return canvas
    for kind,indices in (('rotation',list(range(0,256,16))),('boundaries',[0,1,126,127,128,129,254,255])):
        sheet=Image.new('RGB',(384*4,410*((len(indices)+3)//4)),(29,34,37))
        draw=ImageDraw.Draw(sheet)
        for cell,index in enumerate(indices):
            x,y=(cell%4)*384,(cell//4)*410
            sheet.paste(pose(index),(x,y))
            draw.text((x+12,y+386),f'{asset} | frame {index+1:03d} | {index*360/256:g} deg',fill=(230,230,225))
        path=destination/f'{asset}-{kind}-review.png';sheet.save(path,optimize=True)
        print(path.relative_to(ROOT))
    if 'glow' in manifest['layers']:
        pose(0,False).save(destination/f'{asset}-glow-off.png')
        pose(0,True).save(destination/f'{asset}-glow-on.png')
    for image in pages.values():image.close()
