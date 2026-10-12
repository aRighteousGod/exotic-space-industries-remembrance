"""Pack and inspect genuine Cycles exposures; Pillow never synthesizes blur."""
import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT=Path('output/meshy/minigun-prototypes/prototype-2/handoff-256')
OUT=ROOT/'motion-blur'
REVIEW=OUT/'review'
REVIEW.mkdir(parents=True,exist_ok=True)
records=json.loads((OUT/'frames.json').read_text())
config=json.loads((OUT/'configuration.json').read_text())
preflight=json.loads((ROOT/'preflight/preflight.json').read_text())
VIEWS=(0,32,64,96,128,160,192,224)
VARIANTS=('sharp','restrained','firing','heavy')
LABELS=('Sharp / parked','36 degrees / restrained','90 degrees / firing','180 degrees / heavy')
assert len(records)==36
assert {r['configuration_hash'] for r in records}=={config['hash']}
assert hashlib.sha256((OUT/'implementation/render_motion_blur.py').read_bytes()).hexdigest()==config['script_sha256']
expected={(v,p,d) for v in ('sharp','firing') for p in ('Object','Shadow') for d in VIEWS}
expected|={(v,p,32) for v in ('restrained','heavy') for p in ('Object','Shadow')}
assert {(r['variant'],r['pass'],r['direction']) for r in records}==expected
for r in records:
    path=OUT/r['path']
    assert hashlib.sha256(path.read_bytes()).hexdigest()==r['sha256']
    image=Image.open(path)
    assert image.size==(540,540) and image.mode=='RGBA'
    assert list(image.getchannel('A').point(lambda x:255 if x>1 else 0).getbbox())==r['alpha_bounds']
    assert r['margin']>=8

def font(size):
    for path in ('C:/Windows/Fonts/segoeui.ttf','C:/Windows/Fonts/arial.ttf'):
        if Path(path).exists():return ImageFont.truetype(path,size)
    return ImageFont.load_default()

def load(variant,label,direction):
    return Image.open(OUT/variant/label/f'd{direction:03}.png').convert('RGBA')

def backdrop(size):
    image=Image.new('RGBA',size,'#39454b')
    draw=ImageDraw.Draw(image)
    for y in range(0,size[1],32):
        for x in range(0,size[0],32):
            if (x//32+y//32)%2:draw.rectangle((x,y,x+31,y+31),fill='#414e54')
    return image

def composite(variant,direction,density=64):
    size=540 if density==64 else 270
    shadow=load(variant,'Shadow',direction)
    beauty=load(variant,'Object',direction)
    if density==32:
        shadow=shadow.resize((size,size),Image.Resampling.LANCZOS)
        beauty=beauty.resize((size,size),Image.Resampling.LANCZOS)
    # Display opacity only; raw transparent shadows retain their original alpha.
    shadow.putalpha(shadow.getchannel('A').point(lambda a:round(a*.35)))
    return Image.alpha_composite(Image.alpha_composite(backdrop((size,size)),shadow),beauty)

# Fixed framing across every variant; compare actual sprite sizes as well as details.
display_box=(102,48,530,392)
color_box=(102,48,438,334)
shadow_box=(160,148,530,392)
for label,box in (('Object',color_box),('Shadow',shadow_box)):
    for r in records:
        if r['pass']==label:
            b=r['alpha_bounds']
            assert b[0]>=box[0]+6 and b[1]>=box[1]+6
            assert b[2]<=box[2]-6 and b[3]<=box[3]-6,(label,b,box)

def compare(density):
    width,height=428,344
    sheet=Image.new('RGB',(width*4,60+height),'#1b2328')
    draw=ImageDraw.Draw(sheet)
    for index,(variant,label) in enumerate(zip(VARIANTS,LABELS)):
        tile=composite(variant,32,density)
        if density==32:
            half=tuple(x//2 for x in display_box)
            tile=tile.crop(half).resize((width,height),Image.Resampling.NEAREST)
        else:tile=tile.crop(display_box)
        sheet.paste(tile.convert('RGB'),(index*width,60))
        draw.text((index*width+12,10),label,font=font(20),fill='#e7eff0')
        draw.text((index*width+12,36),f'{density} px/tile'+(' - enlarged 2x' if density==32 else ' - actual pixels'),font=font(14),fill='#9aadb5')
    sheet.save(REVIEW/f'strengths-{density}.png')

compare(64)
compare(32)

# Isolate the muzzle and long rotor at the same zoom, without postprocess blur.
detail_box=(280,88,412,192)
detail=Image.new('RGB',(528*4,476),'#1b2328')
draw=ImageDraw.Draw(detail)
for index,(variant,label) in enumerate(zip(VARIANTS,LABELS)):
    tile=Image.alpha_composite(backdrop((540,540)),load(variant,'Object',32))
    tile=tile.crop(detail_box).resize((528,416),Image.Resampling.NEAREST)
    detail.paste(tile.convert('RGB'),(index*528,60))
    draw.text((index*528+12,12),label+' / detail 4x',font=font(20),fill='#e7eff0')
detail.save(REVIEW/'rotor-detail.png')

gallery=Image.new('RGB',(1080,4*300),'#1b2328')
draw=ImageDraw.Draw(gallery)
for index,d in enumerate(VIEWS):
    col,row=index%4,index//4
    for pair,variant in enumerate(('sharp','firing')):
        y=row*600+pair*300
        gallery.paste(composite(variant,d,32).convert('RGB'),(col*270,y+30))
        draw.text((col*270+10,y+7),f'd={d:03} | '+('sharp' if pair==0 else '90-degree firing'),font=font(16),fill='#e7eff0')
gallery.save(REVIEW/'directions.png')

layouts={}
for density in (32,64):
    layouts[str(density)]={}
    for label,box in (('Object',color_box),('Shadow',shadow_box)):
        size=((box[2]-box[0])*density//64,(box[3]-box[1])*density//64)
        atlas=Image.new('RGBA',(size[0]*4,size[1]*2))
        for index,d in enumerate(VIEWS):
            tile=load('firing',label,d).crop(box)
            if density==32:tile=tile.resize(size,Image.Resampling.LANCZOS)
            location=((index%4)*size[0],(index//4)*size[1])
            atlas.paste(tile,location)
            assert atlas.crop((*location,location[0]+size[0],location[1]+size[1])).tobytes()==tile.tobytes()
        path=REVIEW/f'firing-{density}-{label.lower()}-8view.png'
        atlas.save(path)
        center=((box[0]+box[2])/2,(box[1]+box[3])/2)
        anchor=preflight['ground_anchor_pixels']
        layouts[str(density)][label]={'cell':size,'columns':4,'rows':2,'direction_indices':VIEWS,
            'master_crop':box,'factorio_scale':32/density,
            'shift_tiles':[(center[i]-anchor[i])/64 for i in range(2)],'path':path.name,
            'inspection_only':True,'direction_count':8}

# Make slider layers, already registered to a common ground anchor.
for d in VIEWS:
    for variant in ('sharp','firing'):
        composite(variant,d).crop(display_box).save(REVIEW/f'{variant}-d{d:03}.png')

deltas=[]
for d in VIEWS:
    a=np.asarray(load('sharp','Object',d)).astype(np.int16)
    b=np.asarray(load('firing','Object',d)).astype(np.int16)
    changed=np.any(a!=b,axis=2)&((a[:,:,3]>1)|(b[:,:,3]>1))
    assert int(changed.sum())>100
    alpha_a=np.asarray(load('sharp','Shadow',d))[:,:,3].astype(np.int16)
    alpha_b=np.asarray(load('firing','Shadow',d))[:,:,3].astype(np.int16)
    deltas.append({'direction':d,'changed_beauty_pixels':int(changed.sum()),
                   'changed_shadow_alpha_pixels':int((alpha_a!=alpha_b).sum()),
                   'rgba_absolute_delta':int(np.abs(a-b).sum())})
proof_keys=('stationary_matrix_error','rotor_root_error','rotor_axis_error','rotor_quaternion_error')
proof_max={key:max(row[key] for row in config['pose_proofs']) for key in proof_keys}
assert max(proof_max.values())<1e-6
qa={'schema':'esir.minigun.motion-blur-review.v1','render_status':'passed_inspection_bundle',
    'beauty_frames':18,'shadow_frames':18,'samples':config['samples'],'resolution':[540,540],
    'source_sha256':config['source_sha256'],'configuration_hash':config['hash'],
    'minimum_full_frame_alpha_margin':min(r['margin'] for r in records),
    'pose_proof_count':len(config['pose_proofs']),'pose_proof_maxima':proof_max,
    'deltas':deltas,'layouts':layouts,'matching_shadows':True,'presentation_shadow_opacity':.35,
    'native_timing_changed':False,'factorio_load_tested':False,
    'production_promoted':False,'full_256_direction_render_started':False,
    'native_spin_gate':'unchanged_blocked','review_recommendation':'90_degree_running_candidate',
    'visual_inspection':'rotor_blurs_cradle_and_rear_drum_remain_sharp',
    'transition_plan':{'status':'planned_not_engine_validated','preparing_target_ticks':12,
        'preparing_cap_ticks':45,'cap_condition':'only_if_needed_for_smooth_animation',
        'folding_initial_ticks':18,'running_appearance_in_prepared_and_attacking':True}}
(OUT/'inspection-qa.json').write_text(json.dumps(qa,indent=2)+'\n')

page='''<!doctype html><html lang="en"><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Minigun prototype 2 - rotor exposure inspection</title>
<style>
*{box-sizing:border-box}body{margin:36px auto;padding:0 22px;max-width:1500px;background:#182127;color:#dce8e9;font:16px/1.55 system-ui}
h1{font-size:32px;line-height:1.2}h2{font-size:22px;margin:34px 0 10px}p{max-width:1000px;color:#afc0c7}
img{max-width:100%;display:block}a{color:#8dd2dc}figure{margin:16px 0 28px}figcaption{color:#afc0c7;margin-top:9px}
.viewer{position:relative;width:856px;max-width:100%;aspect-ratio:428/344;overflow:hidden;background:#39454b}
.viewer img{position:absolute;width:100%;height:100%;image-rendering:pixelated}.top{clip-path:inset(0 50% 0 0)}
.divider{position:absolute;left:50%;width:2px;height:100%;background:#9aeeee;pointer-events:none}
label{margin-right:18px}select,input{font:inherit;accent-color:#92ced5}input{width:min(856px,100%);display:block;margin:12px 0}
.legend{display:flex;justify-content:space-between;max-width:856px;color:#9fc6d1}button{font:inherit;padding:5px 12px;background:#34434b;color:#dce8e9;border:1px solid #5d737d;cursor:pointer}
</style>
<h1>Minigun prototype 2 / rotor exposure study</h1>
<p>Physical Cycles motion blur around the barrel axis. The foundation, aiming cradle, receiver and ammunition drum hold still. Each blurred view has its own matching ground shadow.</p>
<p>Exposure options: sharp, 36 degrees, 90 degrees and 180 degrees. All share the original camera, materials, 3x3 footprint fit and 256-sample lighting. These are inspection renders, with no game prototype or firing-timing changes.</p>
<p><strong>Preferred running candidate: 90 degrees.</strong> 36 degrees retains more barrel detail; 180 degrees adds little readability. The activation handoff targets a 0.20-second spin-up, with the user's conditional 0.75-second ceiling, and an initial 0.30-second spin-down. Native timing and interruption behavior remain to be tested. <a href="implementation/MOTION-BLUR-INSPECTION.md">Detailed handoff</a>.</p>
<h2>Sharp versus 90-degree firing</h2>
<label for="direction">Aiming direction</label><select id="direction"></select>
<button id="toggle">Toggle full-frame comparison</button>
<figure><div class="viewer"><img id="blurred" src="review/firing-d032.png" alt="90-degree exposure"><img class="top" id="sharp" src="review/sharp-d032.png" alt="Sharp rotor"><div class="divider" id="divider"></div></div>
<input id="wipe" type="range" min="0" max="100" value="50" aria-label="Comparison divider">
<div class="legend"><span>Sharp</span><span>90-degree firing exposure</span></div>
<figcaption>Drag the divider, or toggle the entire view. The display is enlarged 2x; the source renders are 64 pixels per tile.</figcaption></figure>
<h2>Four strengths / 64 pixels per tile</h2><figure><a href="review/strengths-64.png"><img src="review/strengths-64.png" alt="Four exposure strengths"></a>
<figcaption>Same direction and scale. Rendered rotation, not a painted smear. Shadows use 35% alpha for presentation only.</figcaption></figure>
<h2>Four strengths / 32 pixels per tile</h2><figure><a href="review/strengths-32.png"><img src="review/strengths-32.png" alt="Native-density comparison"></a>
<figcaption>Half-size sprite data enlarged 2x with nearest-neighbor display. This shows the effect at native Factorio density.</figcaption></figure>
<h2>Rotor and muzzle detail</h2><figure><a href="review/rotor-detail.png"><img src="review/rotor-detail.png" alt="Rotor detail at four strengths"></a>
<figcaption>Master pixels enlarged 4x. The rear bearing and cradle remain sharp.</figcaption></figure>
<h2>Eight directions</h2><figure><a href="review/directions.png"><img src="review/directions.png" alt="Eight aiming directions, sharp and blurred"></a></figure>
<p>Retained: <a href="inspection-qa.json">QA measurements</a>, <a href="configuration.json">render configuration</a>, <a href="frames.json">frame hashes</a>, <a href="minigun-motion-blur.blend">inspection Blender scene</a>.</p>
<p>Transparent review atlases contain eight sampled directions, not a finished 256-direction sheet:
<a href="review/firing-32-object-8view.png">32-density beauty</a> / <a href="review/firing-32-shadow-8view.png">shadow</a>;
<a href="review/firing-64-object-8view.png">64-density beauty</a> / <a href="review/firing-64-shadow-8view.png">shadow</a>.</p>
<script>
const select=document.querySelector('#direction'),wipe=document.querySelector('#wipe'),sharp=document.querySelector('#sharp'),blurred=document.querySelector('#blurred'),divider=document.querySelector('#divider');
for(const d of [0,32,64,96,128,160,192,224]){const o=document.createElement('option');o.value=String(d).padStart(3,'0');o.textContent=`d=${o.value} / yaw ${d*360/256} degrees`;select.append(o)}select.value='032';
select.onchange=()=>{sharp.src=`review/sharp-d${select.value}.png`;blurred.src=`review/firing-d${select.value}.png`};
function update(){sharp.style.clipPath=`inset(0 ${100-wipe.value}% 0 0)`;divider.style.left=wipe.value+'%'}wipe.oninput=update;
document.querySelector('#toggle').onclick=()=>{wipe.value=Number(wipe.value)>=50?0:100;update()};
</script></html>'''
(OUT/'index.html').write_text(page,encoding='utf-8')
print(json.dumps({'frames':len(records),'proof_maxima':proof_max,'review':str(OUT/'index.html')},indent=2))
