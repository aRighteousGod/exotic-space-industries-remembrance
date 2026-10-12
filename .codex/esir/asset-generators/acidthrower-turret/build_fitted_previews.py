"""Compare a smaller rendered 3D upper on the native base within its firing arc."""
import argparse
import json
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

parser=argparse.ArgumentParser()
parser.add_argument('--root',default='D:/CodexArtifacts/esir-acidthrower-20261008')
root=Path(parser.parse_args().root)
out=root/'comparisons'
render=root/'comparison-renders/head-fitted'
native=Path('C:/Program Files (x86)/Steam/steamapps/common/Factorio/data/base/graphics/entity/flamethrower-turret')
canvas=448
origin=(224,224)
directions=['north','east','south','west']
anchors={'north':(0,-12),'east':(37,19),'south':(0,38),'west':(-24,11)}
base_shifts={'north':(-1,13),'east':(-6,-2.75),'south':(0,-8),'west':(7,-5)}
shadow_shifts={'north':(3,15),'east':(14,9),'south':(3,9),'west':(15,4)}
mask_shifts={'north':(-1,33),'east':(-33,1),'south':(0,-31),'west':(32,-1)}
description=json.loads((render/'render-anchors.json').read_text())
bearing=description['frame_1_anchors']['bearing']
assert description['upper_uniform_scale']==0.75
assert description['yaw_degrees_clockwise_from_north']==[0,90,180,270,-48,-24,24,48]
verified_poses=json.loads((render/'verified-frame-poses.json').read_text())
assert len(verified_poses)==8
assert all(abs(pose['actual_clockwise_yaw']-pose['expected_clockwise_yaw'])<0.001 for pose in verified_poses)

# The first fitted run predates the wrapper's scaled muzzle metadata fix.
# Orthographic projection is affine, so scaling around the bearing projects
# to the same scaling around its screen point, without rerendering the frames.
original_anchors=json.loads((root/'comparison-renders/head-only/render-anchors.json').read_text())['frame_1_anchors']
description['frame_1_anchors']['muzzle']=[bearing[i]+0.75*(original_anchors['muzzle'][i]-bearing[i]) for i in range(2)]
(render/'render-anchors.json').write_text(json.dumps(description,indent=2),encoding='utf-8')

def read(path):
    return Image.open(path).convert('RGBA')

def shifted(image,delta):
    result=Image.new('RGBA',(canvas,canvas))
    result.alpha_composite(image,delta)
    return result

def base_layer(direction,suffix,shift):
    image=read(native/f'flamethrower-turret-base-{direction}{suffix}.png')
    return shifted(image,(round(origin[0]+2*shift[0]-image.width/2),round(origin[1]+2*shift[1]-image.height/2)))

def compose(direction,index,role='head-fitted'):
    delta=(round(origin[0]+anchors[direction][0]-bearing[0]),round(origin[1]+anchors[direction][1]-bearing[1]))
    image=Image.new('RGBA',(canvas,canvas))
    for layer in [base_layer(direction,'-shadow',shadow_shifts[direction]),
        shifted(read(root/f'comparison-renders/{role}/Shadow/{index:04}.png'),delta),
        base_layer(direction,'',base_shifts[direction]),
        base_layer(direction,'-mask',mask_shifts[direction]),
        shifted(read(root/f'comparison-renders/{role}/Object/{index:04}.png'),delta)]:
        image.alpha_composite(layer)
    return image

def flatten(image):
    result=Image.new('RGBA',(canvas,canvas),(45,48,44,255))
    draw=ImageDraw.Draw(result)
    for value in range(0,canvas,32):
        draw.line((value,0,value,canvas),fill=(51,54,50))
        draw.line((0,value,canvas,value),fill=(51,54,50))
    result.alpha_composite(image)
    return result

records=[]
for index in range(1,9):
    for pass_name in ['Object','Shadow']:
        image=read(render/f'{pass_name}/{index:04}.png')
        bbox=image.getchannel('A').getbbox()
        assert image.size==(canvas,canvas) and bbox
        margin=min(bbox[0],bbox[1],canvas-bbox[2],canvas-bbox[3])
        assert margin>=8,(index,pass_name,bbox)
        records.append({'frame':index,'pass':pass_name,'alpha_margin':margin})

facings=[compose(direction,index+1) for index,direction in enumerate(directions)]
bboxes=[image.getchannel('A').getbbox() for image in facings]
left=min(box[0] for box in bboxes)
top=min(box[1] for box in bboxes)
right=max(box[2] for box in bboxes)
bottom=max(box[3] for box in bboxes)
side=max(right-left,bottom-top)+32
cx,cy=(left+right)/2,(top+bottom)/2
crop=(round(cx-side/2),round(cy-side/2),round(cx+side/2),round(cy+side/2))
title=ImageFont.truetype('C:/Windows/Fonts/segoeuib.ttf',28)
font=ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',19)
sheet=Image.new('RGB',(1000,1120),(24,27,25))
draw=ImageDraw.Draw(sheet)
draw.text((28,18),'SMALLER UPPER / MATCHING BASE FACING',font=title,fill=(225,233,216))
draw.text((28,58),'75% upper scale. Base unchanged. Centered within the 96-degree firing arc.',font=font,fill=(182,194,171))
for index,(direction,image) in enumerate(zip(directions,facings)):
    x,y=28+(index%2)*486,118+(index//2)*486
    draw.text((x,y-25),direction.upper(),font=font,fill=(207,231,165))
    sheet.paste(flatten(image).crop(crop).resize((458,458),Image.Resampling.LANCZOS).convert('RGB'),(x,y))
    image.save(out/f'existing-base-fitted-{direction}-transparent.png')
    flatten(image).save(out/f'existing-base-fitted-{direction}.png')
sheet.save(out/'existing-base-fitted-four-views.png')

# South-facing center aim gives a clear view of the ceramic nozzle and tanks.
hero=facings[2]
left,top,right,bottom=hero.getchannel('A').getbbox()
side=max(right-left,bottom-top)+48
cx,cy=(left+right)/2,(top+bottom)/2
hero_crop=(round(cx-side/2),round(cy-side/2),round(cx+side/2),round(cy+side/2))
flatten(hero).crop(hero_crop).resize((768,768),Image.Resampling.LANCZOS).save(out/'existing-base-fitted-focused.png')

# Sweep only the north base's legal forward arc, then return without a full turn.
arc_indices=[5,6,1,7,8,7,1,6]
arc_yaws=[-48,-24,0,24,48,24,0,-24]
assert all(abs(yaw)<=48 for yaw in arc_yaws)
frames=[flatten(compose('north',index)).crop(crop).resize((512,512),Image.Resampling.LANCZOS) for index in arc_indices]
frames[0].save(out/'existing-base-fitted-firing-arc.gif',save_all=True,append_images=frames[1:],duration=260,loop=0,disposal=2)

# A matched south-facing comparison isolates the scale change.
old=compose('south',5,'head-only')
comparison=Image.new('RGB',(1020,560),(24,27,25))
draw=ImageDraw.Draw(comparison)
for column,(label,image) in enumerate([('Previous upper size',old),('75% upper size',hero)]):
    draw.text((28+column*500,16),label,font=font,fill=(207,231,165))
    comparison.paste(flatten(image).resize((480,480),Image.Resampling.LANCZOS).convert('RGB'),(20+column*500,58))
comparison.save(out/'existing-base-fitted-size-comparison.png')

qa={'upper_scale':0.75,'scaled_in_3d':True,'scale_pivot':description['scale_pivot'],
    'base_facings_degrees':[0,90,180,270],'upper_center_aim_degrees':[0,90,180,270],
    'attack_turn_range':(1/3)*0.8,'full_firing_arc_degrees':96,'half_arc_degrees':48,
    'arc_preview_yaw_degrees':arc_yaws,'arc_preview_base_facing':'north',
    'prototype_source':'exotic-space-industries-remembrance/prototypes/steam-age/acid-turret/acid.lua:913',
    'final_dump':'.factorio-qc/terrain-evolution/final-release/script-output/data-raw-dump.json',
    'docs':'https://lua-api.factorio.com/2.0.77/types/BaseAttackParameters.html#turn_range',
    'verified_frame_poses':verified_poses,'raw_pass_checks':records,'limitations':['Draft native-base composite; in-engine attachment and occlusion checks remain.',
        'Head shadow is rendered in 3D, then translated with the bearing; final native-base shadow calibration remains.']}
(out/'fitted-preview-qa.json').write_text(json.dumps(qa,indent=2),encoding='utf-8')
page=root/'index.html'
text=page.read_text(encoding='utf-8')
marker='<!-- fitted-upper-preview -->'
if marker not in text:
    section=marker+'<section><h2>Smaller upper with matching base facing</h2><p>The upper is uniformly scaled to 75% around its bearing in Blender. All four center aims match the base facing. The arc preview sweeps only +/-48 degrees, matching the current 96-degree firing arc.</p><img src="comparisons/existing-base-fitted-focused.png" alt="Smaller upper and existing base facing south together"><p><a href="comparisons/existing-base-fitted-four-views.png">Four aligned facings</a> · <a href="comparisons/existing-base-fitted-firing-arc.gif">Restricted firing arc</a> · <a href="comparisons/existing-base-fitted-size-comparison.png">Same-facing size comparison</a></p></section>'
    text=text.replace('<section>',section+'<section>',1)
    page.write_text(text,encoding='utf-8')
print('Fitted previews complete: 75% upper, matching base facings, +/-48 degree sweep.')
