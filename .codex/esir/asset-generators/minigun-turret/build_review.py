"""Build comparison images and alpha/luminance QA from unmodified Blender renders."""
import argparse
import html
import json
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import numpy as np

parser = argparse.ArgumentParser()
parser.add_argument('--phase', choices=['preview', 'final'], required=True)
args = parser.parse_args()
root = Path('output/meshy/minigun-prototypes').resolve()
fontpath = 'C:/Windows/Fonts/segoeui.ttf'
font = ImageFont.truetype(fontpath, 24)
small = ImageFont.truetype(fontpath, 17)
title = ImageFont.truetype(fontpath, 32)

def stats(path):
    image = Image.open(path).convert('RGBA')
    a = np.asarray(image)
    mask = a[:,:,3] > 16
    ys, xs = np.where(mask)
    if len(xs) == 0:
        return {'path': str(path.relative_to(root)), 'blank': True}
    rgb = a[:,:,:3][mask].astype(float)
    luma = rgb @ np.array([0.2126,0.7152,0.0722])
    bounds = [int(xs.min()), int(ys.min()), int(xs.max())+1, int(ys.max())+1]
    margin = min(bounds[0], bounds[1], image.width-bounds[2], image.height-bounds[3])
    return {'path': str(path.relative_to(root)), 'size': list(image.size), 'blank': False,
            'bounds': bounds, 'minimum_margin_px': margin, 'mean_luma': float(luma.mean()),
            'median_luma': float(np.median(luma)), 'clip250_pct': float((luma>=250).mean()*100)}

def add_render(canvas, source, box):
    image = source.copy() if isinstance(source, Image.Image) else Image.open(source).convert('RGBA')
    image.thumbnail((box[2],box[3]), Image.Resampling.LANCZOS)
    canvas.alpha_composite(image, (box[0]+(box[2]-image.width)//2,box[1]+(box[3]-image.height)//2))

review = root/'review'
review.mkdir(exist_ok=True)
records = []
if args.phase == 'preview':
    profiles = ['preset-default','rail-fill','gamma-rescue']
    board = Image.new('RGBA',(1536,1140),(33,37,40,255))
    draw = ImageDraw.Draw(board)
    draw.text((24,16),'Minigun prototypes | Factorio preset lighting comparison',font=title,fill='white')
    for n in (1,2):
        y = 60+(n-1)*530
        for col,profile in enumerate(profiles):
            files = sorted((root/f'prototype-{n}'/'lighting-compare'/profile/'Object').glob('*.png'))
            if not files:
                continue
            record = stats(files[0]); record.update(prototype=n,profile=profile); records.append(record)
            add_render(board,files[0],(col*512,y,512,470))
            draw.text((col*512+20,y+470),f'{n} / {profile}',font=font,fill='white')
            draw.text((col*512+20,y+501),f"Median {record['median_luma']:.0f} | clipped {record['clip250_pct']:.2f}%",font=small,fill='#adb6bb')
    board.convert('RGB').save(review/'lighting-comparison.jpg',quality=94)
    (review/'lighting-qa.json').write_text(json.dumps(records,indent=2)+'\n')
else:
    all_frames = [p for n in (1,2) for role in ('Object','Shadow')
                  for p in (root/f'prototype-{n}'/'final'/role).glob('*.png')]
    assert len(all_frames)==32, ('Expected 16 object and 16 shadow frames',len(all_frames))
    boxes = [Image.open(p).getbbox() for p in all_frames]
    crop = [max(0,min(b[0] for b in boxes)-32), max(0,min(b[1] for b in boxes)-32),
            min(1024,max(b[2] for b in boxes)+32), min(1024,max(b[3] for b in boxes)+32)]
    (review/'presentation-crop.json').write_text(json.dumps({'shared_crop':crop,
        'preview_shadow_opacity':0.35,
        'note':'Identical crop for both prototypes; original 1024px transparent frames and full shadow masks retained.'},indent=2)+'\n')
    for n in (1,2):
        folder = root/f'prototype-{n}'/'final'
        files = sorted((folder/'Object').glob('*.png'))
        assert len(files)==8, (n,len(files))
        # Pack PNG bytes without a second Blender color-management transform.
        # The downloaded PBR and rendered individual frames remain untouched.
        for role,filename in [('Object','object_0.png'),('Shadow','object_shadow_0.png')]:
            frames=sorted((folder/role).glob('*.png'))
            assert len(frames)==8,(n,role,len(frames))
            packed=Image.new('RGBA',(4096,2048))
            for index,frame in enumerate(frames):
                raw=Image.open(frame).convert('RGBA')
                assert raw.size==(1024,1024)
                packed.paste(raw,((index%4)*1024,(index//4)*1024))
            destination=folder/'.Sheets'/filename
            packed.save(destination)
            check=Image.open(destination).convert('RGBA')
            for index,frame in enumerate(frames):
                x,y=(index%4)*1024,(index//4)*1024
                assert np.array_equal(np.asarray(check.crop((x,y,x+1024,y+1024))),
                                      np.asarray(Image.open(frame).convert('RGBA')))
        board = Image.new('RGBA',(1600,980),(33,37,40,255))
        draw = ImageDraw.Draw(board)
        draw.text((24,16),f'Prototype {n} | Eight Factorio-camera sample views',font=title,fill='white')
        for i,path in enumerate(files):
            record=stats(path); record.update(prototype=n,role='object'); records.append(record)
            assert not record['blank'] and record['minimum_margin_px']>=8,record
            x,y=(i%4)*400,60+(i//4)*445
            combined = Image.open(folder/'Shadow'/path.name).convert('RGBA')
            combined.putalpha(combined.getchannel('A').point(lambda value: round(value*0.35)))
            combined.alpha_composite(Image.open(path).convert('RGBA'))
            combined = combined.crop(crop)
            add_render(board,combined,(x,y,400,400))
            if i==2:
                combined.save(review/f'prototype-{n}-hero.png')
            draw.text((x+18,y+397),f'View {i+1} / turn {i*45} deg',font=small,fill='#cad2d6')
        shadows = sorted((folder/'Shadow').glob('*.png'))
        assert len(shadows)==8, (n,len(shadows),'shadows')
        for path in shadows:
            record=stats(path); record.update(prototype=n,role='shadow'); records.append(record)
            assert not record['blank'] and record['minimum_margin_px']>=2,record
        board.convert('RGB').save(review/f'prototype-{n}-samples.jpg',quality=95)
    (review/'render-qa.json').write_text(json.dumps(records,indent=2)+'\n')
    pair=Image.new('RGBA',(1440,850),(33,37,40,255))
    draw=ImageDraw.Draw(pair)
    draw.text((24,18),'Minigun prototypes | Matched Factorio renders',font=title,fill='white')
    for n in (1,2):
        x=(n-1)*720
        add_render(pair,review/f'prototype-{n}-hero.png',(x,60,720,710))
        draw.text((x+28,779),f'Prototype {n}',font=title,fill='white')
        draw.text((x+28,819),'Ultra 4K geometry / 8K textures / original PBR',font=small,fill='#adb6bb')
    pair.convert('RGB').save(review/'comparison.jpg',quality=96)
    page='''<!doctype html><meta charset="utf-8"><title>Minigun prototype review</title>
<style>body{background:#15191c;color:#e8eef1;font:18px system-ui;max-width:1600px;margin:40px auto;padding:0 24px}img{max-width:100%}a{color:#a9d8f1}p{line-height:1.6}</style>
<h1>Minigun prototype review</h1><p>Meshy 7.1 Ultra 4K geometry, 8K base color and PBR. Original models preserved. Both measured foundations fitted inside a nominal 3x3 tile footprint. Whole-model turntables; production mechanical separation and muzzle calibration remain separate work. Contact sheets use 35% shadow opacity for presentation; separate full shadow masks are retained.</p>'''
    for n in (1,2):
        page+=f'<h2>Prototype {n}</h2><p><a href="../prototype-{n}/source/model.glb">Original GLB</a> | <a href="../prototype-{n}/sample-scene.blend">Blender scene</a> | <a href="../prototype-{n}/final/Object/">Transparent sample frames</a></p><img src="prototype-{n}-samples.jpg">'
    page+='<h2>Matched comparison</h2><img src="comparison.jpg"><h2>Lighting comparison</h2><img src="lighting-comparison.jpg"><p><a href="render-qa.json">Render QA</a> | <a href="../generation-request.json">Generation settings and task IDs</a></p>'
    (review/'index.html').write_text(page,encoding='utf-8')
print(json.dumps({'phase':args.phase,'records':len(records),'output':str(review)},indent=2))
