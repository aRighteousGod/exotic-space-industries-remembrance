"""Pack reviewed raw Factorio renders and build staged A/B model comparisons."""
import argparse, json, struct, hashlib
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

parser=argparse.ArgumentParser()
parser.add_argument('--root',default='D:/CodexArtifacts/esir-acidthrower-20261008')
args=parser.parse_args()
root=Path(args.root)
out=root/'comparisons'
out.mkdir(parents=True,exist_ok=True)
native=Path('C:/Program Files (x86)/Steam/steamapps/common/Factorio/data/base/graphics/entity/flamethrower-turret')
canvas=448
origin=(canvas//2,canvas//2)
directions=['north','east','south','west']
anchors={'north':(0,-12),'east':(37,19),'south':(0,38),'west':(-24,11)}
base_shifts={'north':(-1,13),'east':(-6,-2.75),'south':(0,-8),'west':(7,-5)}
shadow_shifts={'north':(3,15),'east':(14,9),'south':(3,9),'west':(15,4)}
mask_shifts={'north':(-1,33),'east':(-33,1),'south':(0,-31),'west':(32,-1)}
head_anchor=json.loads((root/'comparison-renders/head-only/render-anchors.json').read_text())['frame_1_anchors']['bearing']
font_path='C:/Windows/Fonts/segoeui.ttf'
font=ImageFont.truetype(font_path,20)
small=ImageFont.truetype(font_path,15)
title=ImageFont.truetype('C:/Windows/Fonts/segoeuib.ttf',30)
source=root/'source/attempt-01.glb'
qa={'source_glb':{'bytes':source.stat().st_size,'sha256':hashlib.sha256(source.read_bytes()).hexdigest()},'renders':{},'models':{},'hybrid_preview':'Native model-origin attachment, composited draft; engine muzzle/pipe calibration pending.'}

def image(path):
    return Image.open(path).convert('RGBA')

def raw(role,pass_name,index):
    return image(root/f'comparison-renders/{role}/{pass_name}/{index:04}.png')

def background():
    im=Image.new('RGBA',(canvas,canvas),(45,48,44,255))
    d=ImageDraw.Draw(im)
    for i in range(0,canvas,32):
        d.line((i,0,i,canvas),fill=(51,54,50))
        d.line((0,i,canvas,i),fill=(51,54,50))
    return im

def native_layer(direction,suffix,shift):
    im=image(native/f'flamethrower-turret-base-{direction}{suffix}.png')
    dest=Image.new('RGBA',(canvas,canvas))
    xy=(round(origin[0]+2*shift[0]-im.width/2),round(origin[1]+2*shift[1]-im.height/2))
    dest.alpha_composite(im,xy)
    return dest

def translated(im,delta):
    dest=Image.new('RGBA',(canvas,canvas))
    dest.alpha_composite(im,delta)
    return dest

def flatten(body,shadow):
    im=background()
    im.alpha_composite(shadow)
    im.alpha_composite(body)
    return im

# Check real pixel bounds in every emitted pass and pack the raw frame pixels.
for role,count,columns in [('assembled',8,4),('head-only',8,4),('base',4,4)]:
    qa['renders'][role]={}
    for pass_name in ['Object','Shadow']:
        sheet=Image.new('RGBA',(canvas*columns,canvas*((count+columns-1)//columns)))
        margins=[]
        for index in range(1,count+1):
            im=raw(role,pass_name,index)
            assert im.size==(canvas,canvas),(role,pass_name,index,im.size)
            bbox=im.getchannel('A').getbbox()
            assert bbox,(role,pass_name,index,'empty')
            margin=min(bbox[0],bbox[1],canvas-bbox[2],canvas-bbox[3])
            assert margin>=8,(role,pass_name,index,'clipped',bbox)
            margins.append(margin)
            sheet.alpha_composite(im,(((index-1)%columns)*canvas,((index-1)//columns)*canvas))
        sheet.save(out/f'{role}-{pass_name.lower()}-sheet.png')
        qa['renders'][role][pass_name]={'frames':count,'minimum_alpha_margin':min(margins),'frame_size':[canvas,canvas]}

new_frames=[]
hybrid_frames=[]
head_frames=[]
for index in range(1,9):
    new_frames.append(flatten(raw('assembled','Object',index),raw('assembled','Shadow',index)))
    head_frames.append(flatten(raw('head-only','Object',index),raw('head-only','Shadow',index)))
    delta=(round(origin[0]+anchors['north'][0]-head_anchor[0]),round(origin[1]+anchors['north'][1]-head_anchor[1]))
    im=background()
    im.alpha_composite(native_layer('north','-shadow',shadow_shifts['north']))
    im.alpha_composite(translated(raw('head-only','Shadow',index),delta))
    im.alpha_composite(native_layer('north','',base_shifts['north']))
    im.alpha_composite(native_layer('north','-mask',mask_shifts['north']))
    im.alpha_composite(translated(raw('head-only','Object',index),delta))
    hybrid_frames.append(im)

# Four placement facings, each looking forward, share the same pixel scale.
comparison=Image.new('RGB',(1120,1660),(24,27,25))
draw=ImageDraw.Draw(comparison)
draw.text((28,20),'ACIDTHROWER  /  BASE COMPARISON',font=title,fill=(225,233,216))
draw.text((28,62),'Same Meshy upper assembly. Factorio preset. 64 review pixels / tile.',font=small,fill=(169,181,164))
draw.text((62,100),'A  New base',font=font,fill=(207,231,165))
draw.text((606,100),'B  Existing base (draft attachment)',font=font,fill=(207,231,165))
for row,direction in enumerate(directions):
    aim_index=1+row*2
    body=raw('base','Object',row+1)
    shadow=raw('base','Shadow',row+1)
    shadow.alpha_composite(raw('head-only','Shadow',aim_index))
    body.alpha_composite(raw('head-only','Object',aim_index))
    new=flatten(body,shadow)
    delta=(round(origin[0]+anchors[direction][0]-head_anchor[0]),round(origin[1]+anchors[direction][1]-head_anchor[1]))
    hybrid=background()
    hybrid.alpha_composite(native_layer(direction,'-shadow',shadow_shifts[direction]))
    hybrid.alpha_composite(translated(raw('head-only','Shadow',aim_index),delta))
    hybrid.alpha_composite(native_layer(direction,'',base_shifts[direction]))
    hybrid.alpha_composite(native_layer(direction,'-mask',mask_shifts[direction]))
    hybrid.alpha_composite(translated(raw('head-only','Object',aim_index),delta))
    for col,im in enumerate([new,hybrid]):
        im.save(out/f'{"new" if col==0 else "existing"}-base-{direction}.png')
        # Show the complete source canvas: no cardinal view loses a muzzle or shadow.
        crop=im.resize((344,344),Image.Resampling.LANCZOS)
        y=155+row*365
        comparison.paste(crop,(52+col*544,y))
        draw.text((52+col*544,y-23),direction.upper(),font=small,fill=(185,195,179))
draw.text((28,1620),'Staged art comparison: base choice, deployment, owner mask and native firing calibration remain pending.',font=small,fill=(178,188,169))
comparison.save(out/'base-comparison.png')

# Large same-scale assembly vs base-free hero, using the readable SE aim.
hero=Image.new('RGB',(1120,590),(24,27,25))
d=ImageDraw.Draw(hero)
d.text((28,20),'ONE UPPER ASSEMBLY  /  TWO MODEL EXPORTS',font=title,fill=(225,233,216))
for column,(label,frames) in enumerate([('Complete model',new_frames),('Base-free upper assembly',head_frames)]):
    im=frames[3].crop((96,88,376,368)).resize((480,480),Image.Resampling.LANCZOS)
    hero.paste(im,(28+column*554,92))
    d.text((28+column*554,65),label,font=font,fill=(207,231,165))
hero.save(out/'model-variants.png')

# Focused review requested by the user: only the new upper on the existing base.
focus_layers=[native_layer('north','-shadow',shadow_shifts['north']),
    translated(raw('head-only','Shadow',4),
        (round(origin[0]+anchors['north'][0]-head_anchor[0]),round(origin[1]+anchors['north'][1]-head_anchor[1]))),
    native_layer('north','',base_shifts['north']),
    native_layer('north','-mask',mask_shifts['north']),
    translated(raw('head-only','Object',4),
        (round(origin[0]+anchors['north'][0]-head_anchor[0]),round(origin[1]+anchors['north'][1]-head_anchor[1])))]
focus_alpha=Image.new('RGBA',(canvas,canvas))
for layer in focus_layers:
    focus_alpha.alpha_composite(layer)
left,top,right,bottom=focus_alpha.getchannel('A').getbbox()
side=max(right-left,bottom-top)+48
cx,cy=(left+right)/2,(top+bottom)/2
box=(round(cx-side/2),round(cy-side/2),round(cx+side/2),round(cy+side/2))
hybrid_frames[3].crop(box).resize((768,768),Image.Resampling.LANCZOS).save(out/'existing-base-focused.png')
focus_alpha.save(out/'existing-base-focused-transparent.png')

existing_views=Image.new('RGB',(896,970),(24,27,25))
ed=ImageDraw.Draw(existing_views)
ed.text((28,16),'NEW UPPER  /  EXISTING ACIDTHROWER BASE',font=title,fill=(225,233,216))
for index,direction in enumerate(directions):
    x,y=(index%2)*448,64+(index//2)*448
    existing_views.paste(image(out/f'existing-base-{direction}.png').convert('RGB'),(x,y+24))
    ed.text((x+20,y),direction.upper(),font=small,fill=(207,231,165))
existing_views.save(out/'existing-base-four-views.png')

for name,frames in [('new-base',new_frames),('existing-base',hybrid_frames),('head-only',head_frames)]:
    frames[0].save(out/f'{name}-turntable.gif',save_all=True,append_images=frames[1:],duration=220,loop=0,disposal=2)

for name in ['assembled','head-only','base']:
    path=root/f'prepared/{name}.glb'
    with path.open('rb') as stream:
        magic,version,length=struct.unpack('<4sII',stream.read(12))
    assert magic==b'glTF' and version==2 and length==path.stat().st_size,(name,'invalid GLB')
    qa['models'][name]={'bytes':length,'sha256':hashlib.sha256(path.read_bytes()).hexdigest()}
qa['head_bearing_projection']=head_anchor
(out/'comparison-qa.json').write_text(json.dumps(qa,indent=2))

page='''<!doctype html><html lang="en"><meta charset="utf-8"><title>Acidthrower model comparisons</title>
<style>body{margin:32px auto;max-width:1200px;padding:0 24px;background:#181b19;color:#e1e9d8;font:17px/1.55 system-ui}h1{font-size:32px}a{color:#cfe7a5}img{max-width:100%;height:auto}section{margin:36px 0}.views{display:grid;grid-template-columns:repeat(3,1fr);gap:18px}.views img{width:100%}small{color:#b1bea9}li{margin:6px 0}</style>
<h1>Acidthrower: choose the base after comparison</h1>
<p>Both models use the same Meshy-generated upper assembly, separated locally in Blender. The nozzle, pressure vessels, hoses and turntable stay together. Native Factorio preset lighting and a common 64 pixels-per-tile scale are used throughout.</p>
<p><a href="prepared/assembled.glb">Complete GLB</a> · <a href="prepared/head-only.glb">Base-free GLB</a> · <a href="prepared/base.glb">Separate base GLB</a> · <a href="prepared/acidthrower-variants.blend">Prepared Blender file</a></p>
<section><h2>New upper assembly on the existing acidthrower base</h2><img src="comparisons/existing-base-focused.png" alt="New upper assembly mounted on the existing acidthrower base"><p><a href="comparisons/existing-base-four-views.png">Four placement facings</a> · <a href="comparisons/existing-base-turntable.gif">Upper turntable preview</a>. Draft composite; native attachment and firing validation follow selection.</p></section>
<section><img src="comparisons/model-variants.png" alt="Complete turret and the exact same upper assembly without its base"></section>
<section><h2>New base versus existing base</h2><p>The existing-base preview uses corrected Factorio 2.0.77 sprite sizes and anchors. It is a composited draft, not an in-engine validation. Head placement follows the native model-origin contract; shadows are preview approximations.</p><img src="comparisons/base-comparison.png" alt="Four directional comparisons of new and existing bases"></section>
<section class="views"><div><h3>New base</h3><img src="comparisons/new-base-turntable.gif"></div><div><h3>Existing base</h3><img src="comparisons/existing-base-turntable.gif"></div><div><h3>Upper only</h3><img src="comparisons/head-only-turntable.gif"></div></section>
<section><h2>Review boundaries</h2><ul><li>New-base requirement: exterior pipe connectors must be symmetrical across the base's longitudinal centerline, with matching position, height, collar size and orientation. Preserve the existing 2×3 gameplay footprint.</li><li>Full-yaw turntables inspect geometry; they do not imply a change to the turret's firing arc.</li><li>The new plinth fits inside the existing 2×3 gameplay footprint. Exact external pipe collars and mount calibration remain for the selected design.</li><li>Preview sheets contain eight upper angles and four base facings. Final 64-direction sheets, deployment animation, owner masks and engine firing checks follow selection.</li><li>One Meshy 7.1 generation, 4K geometry / 8K base color / PBR: 40 credits. No second generation was used.</li><li>Production sprites and gameplay prototypes are unchanged.</li></ul></section>
<p><a href="comparisons/comparison-qa.json">Artifact checks</a> · <a href="mechanical-split.json">Mechanical split and anchors</a></p></html>'''
(root/'index.html').write_text(page,encoding='utf-8')
print(json.dumps(qa,indent=2))
