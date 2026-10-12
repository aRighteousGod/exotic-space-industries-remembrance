"""Retain transparent pilot sheets, viewing aids and measured QA without promotion."""
import hashlib
import json
import math
import statistics
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

ROOT=Path('output/meshy/minigun-prototypes/prototype-2/handoff-256')
PILOT=ROOT/'pilot'
preflight=json.loads((PILOT/'preflight.json').read_text())
configuration=json.loads((PILOT/'configuration.json').read_text())
records=[json.loads(line) for line in (PILOT/'frames.jsonl').read_text().splitlines()]
records=[r for r in records if r['configuration_hash']==configuration['hash']]
records={(r['pass'],r['frame']):r for r in records}
poses=[(32,p) for p in range(16)]+[(d,0) for d in (0,64,96,128,160,192,224)]
for label in ('Object','Shadow'):
    for d,p in poses:
        frame=1+d*16+p
        path=PILOT/label/f'{frame:04}.png'
        assert (label,frame) in records,(label,frame)
        assert hashlib.sha256(path.read_bytes()).hexdigest()==records[(label,frame)]['sha256']

def load(label,d,p):
    return Image.open(PILOT/label/f'{1+d*16+p:04}.png').convert('RGBA')

def crop_box(key,label):
    theoretical=preflight[key]
    actual=[r['alpha_bounds'] for r in records.values() if r['pass']==label]
    union=[min([theoretical[0]]+[b[0] for b in actual]),min([theoretical[1]]+[b[1] for b in actual]),
           max([theoretical[2]]+[b[2] for b in actual]),max([theoretical[3]]+[b[3] for b in actual])]
    # Eight master pixels preserve four native pixels; even boundaries permit exact half-scale placement.
    box=[2*math.floor((union[0]-8)/2),2*math.floor((union[1]-8)/2),
         2*math.ceil((union[2]+8)/2),2*math.ceil((union[3]+8)/2)]
    assert min(box)>=0 and max(box)<=540,box
    return box

color_box=crop_box('color_pixel_bounds','Object')
shadow_box=crop_box('hard_shadow_pixel_bounds','Shadow')
anchor=preflight['ground_anchor_pixels']
def leaf(box,density):
    factor=density/64
    size=[int((box[2]-box[0])*factor),int((box[3]-box[1])*factor)]
    center=[(box[0]+box[2])/2,(box[1]+box[3])/2]
    shift=[(center[i]-anchor[i])/64 for i in range(2)]
    return {'cell':size,'shift_tiles':shift,'factorio_scale':32/density,'master_crop':box}

layouts={str(density):{'color':leaf(color_box,density),'shadow':leaf(shadow_box,density)} for density in (32,64)}
for density,layout in layouts.items():
    count_color=4096+256
    layout['estimated_texture_rgba_mib']=(count_color*math.prod(layout['color']['cell'])+256*math.prod(layout['shadow']['cell']))*4/2**20
    layout['measured_vram']=False

def checker(size):
    image=Image.new('RGBA',size,'#353e43');draw=ImageDraw.Draw(image)
    for y in range(0,size[1],32):
        for x in range(0,size[0],32):
            if (x//32+y//32)%2:draw.rectangle((x,y,x+31,y+31),fill='#424d53')
    return image

def composite(d,p,density=64):
    image=checker((540,540))
    image=Image.alpha_composite(image,load('Shadow',d,p))
    image=Image.alpha_composite(image,load('Object',d,p))
    return image if density==64 else image.resize((270,270),Image.Resampling.LANCZOS)

for density in (32,64):
    cell=layouts[str(density)]['color']['cell']
    sheet=Image.new('RGBA',(cell[0]*16,cell[1]))
    frames=[]
    for p in range(16):
        tile=load('Object',32,p).crop(color_box)
        if density==32:tile=tile.resize(tuple(cell),Image.Resampling.LANCZOS)
        sheet.paste(tile,(p*cell[0],0))
        assert sheet.crop((p*cell[0],0,(p+1)*cell[0],cell[1])).tobytes()==tile.tobytes()
        frames.append(composite(32,p,density).convert('RGB'))
    sheet.save(PILOT/f'spin-{density}-transparent.png')
    frames[0].save(PILOT/f'spin-{density}.gif',save_all=True,append_images=frames[1:],duration=100,loop=0)

gallery=Image.new('RGB',(1080,540),'#20272d')
for index,d in enumerate((0,32,64,96,128,160,192,224)):
    tile=composite(d,0,32).convert('RGB')
    ImageDraw.Draw(tile).text((8,8),f'd={d} / yaw={d*360/256:g}',fill='white')
    gallery.paste(tile,((index%4)*270,(index//4)*270))
gallery.save(PILOT/'directions.png')
yaw=[composite(d,0,32).convert('RGB') for d in (0,32,64,96,128,160,192,224)]
yaw[0].save(PILOT/'yaw.gif',save_all=True,append_images=yaw[1:],duration=350,loop=0)
comparison=Image.new('RGB',(1080,540),'#20272d')
comparison.paste(composite(32,0,32).resize((540,540),Image.Resampling.NEAREST).convert('RGB'),(0,0))
comparison.paste(composite(32,0,64).convert('RGB'),(540,0))
ImageDraw.Draw(comparison).text((15,15),'32 px/tile enlarged 2x | 64 px/tile at 1x',fill='white')
comparison.save(PILOT/'density-comparison.png')

differences=[]
for p in range(16):
    a=np.asarray(load('Object',32,p)).astype(int)
    b=np.asarray(load('Object',32,(p+1)%16)).astype(int)
    differences.append({'from':p,'to':(p+1)%16,'changed_rgba_pixels':int(np.any(a!=b,axis=2).sum()),
                        'max_channel_delta':int(np.abs(a-b).max())})
assert all(row['changed_rgba_pixels']>100 for row in differences)
shadow_comparisons=[]
for d in (32,64,192):
    a=np.asarray(load('Shadow',d,0))[:,:,3].astype(float)
    for p in (range(1,16) if d==32 else (4,8,12)):
        b=np.asarray(load('Shadow',d,p))[:,:,3].astype(float)
        shadow_comparisons.append({'direction':d,'phase':p,'alpha_l1_fraction':float(np.abs(a-b).sum()/max(1,a.sum())),
                                   'changed_alpha_pixels':int((a!=b).sum())})

timing=json.loads((ROOT/'timing-probe/timing-summary.json').read_text())
summary={'schema':'esir.minigun.execution.v1','selected_prototype':2,'source_sha256':preflight['source_sha256'],
    'rig':'passed_source_partition_uv_normals_and_pose_geometry','native_timing':'failed_no_candidate_preserves_fire_and_spin',
    'production_gate':'blocked','blocker':'Factorio 2.0.77 native attacking animation shares firing progress; no independent rotor clock found.',
    'pilot':'rendered_requires_art_review','pilot_beauty_frames':23,'pilot_shadow_frames':29,
    'geometry':preflight,'layouts':layouts,'phase_changes':differences,'shadow_approximation_review':shadow_comparisons,
    'timing_reports':[{'mode':r['mode'],'advanced':r.get('advanced'),'glow':r.get('glow'),'passing_candidates':r['passing_candidates']} for r in timing['reports']],
    'pilot_samples':configuration['samples'],'median_pilot_beauty_seconds':statistics.median(r['seconds'] for r in records.values() if r['pass']=='Object'),
    'production_started':False,'production_frames':0,'shipping_promoted':False,
    'muzzle':'256 geometry anchors and creation-map proposal generated; native compensation/alignment not calibrated',
    'master_sheets':'not_rendered_native_gate_failed','factorio_sheets':'not_rendered_native_gate_failed',
    'native_asset_load':'not_run_no_production_sheets','pilot_rgba_pack':'all_32_cells_equal_to_source_or_declared_half_scale_resize'}
benchmark_path=ROOT/'benchmark/configuration.json'
if benchmark_path.exists():
    benchmark_config=json.loads(benchmark_path.read_text())
    benchmark_rows=[json.loads(line) for line in (ROOT/'benchmark/frames.jsonl').read_text().splitlines()]
    benchmark_rows=[r for r in benchmark_rows if r['configuration_hash']==benchmark_config['hash']]
    beauty=[r['seconds'] for r in benchmark_rows if r['pass']=='Object']
    shadows=[r['seconds'] for r in benchmark_rows if r['pass']=='Shadow']
    if len(beauty)==4 and len(shadows)==1:
        summary['final_settings_benchmark']={'samples':benchmark_config['samples'],'beauty_frames':4,'shadow_frames':1,
            'median_beauty_seconds':statistics.median(beauty[1:]),'shadow_seconds':shadows[0],
            'estimated_4096_beauty_256_shadow_hours':(statistics.median(beauty[1:])*4096+shadows[0]*256)/3600,
            'full_batch_elapsed_is_measured':False,'device':benchmark_config['scene'].get('cycles_device')}
(ROOT/'qa-summary.json').write_text(json.dumps(summary,indent=2)+'\n')
(PILOT/'pilot-qa.json').write_text(json.dumps(summary,indent=2)+'\n')
page='''<!doctype html><html lang="en"><meta charset="utf-8"><title>Prototype 2 minigun rig pilot</title>
<style>body{background:#171e23;color:#d9e1e5;font:16px system-ui;max-width:1160px;margin:40px auto;padding:0 20px}h1{font-size:30px}img{max-width:100%;background:#283238}figure{margin:30px 0}figcaption{color:#a9b9c4;margin-top:8px}a{color:#8dc8dd}.pair{display:flex;gap:20px;align-items:start}.pair figure{flex:1}code{color:#b4ccd5}</style>
<h1>Minigun prototype 2 · exposed cradle</h1>
<p>The source mesh is split into a fixed foundation, aiming cradle/receiver/drum and independent bore-axis rotor. Original UVs and corner normals are preserved. All 4,096 planned poses fit the camera.</p>
<p><strong>Production held:</strong> the native Factorio 2.0.77 timing probe found no setting that combines ordered 16-phase spin with the original firing curve. This page demonstrates Blender motion; it does not prove in-game animation.</p>
<div class="pair"><figure><img src="spin-32.gif"><figcaption>16-phase loop, 32 px/tile. The base and drum remain fixed through the spin.</figcaption></figure><figure><img src="spin-64.gif"><figcaption>64 px/tile master-density comparison. Playback slowed for inspection.</figcaption></figure></div>
<figure><img src="directions.png"><figcaption>Eight aiming directions. The foundation keeps its world orientation; the upper assembly turns.</figcaption></figure>
<figure><img src="yaw.gif"><figcaption>Eight-pose yaw inspection. This is a coarse turntable, not a full 256-direction animation.</figcaption></figure>
<figure><img src="density-comparison.png"><figcaption>32 px/tile enlarged 2x beside 64 px/tile at 1x. Both represent the same world footprint.</figcaption></figure>
<p><a href="spin-64-transparent.png">Transparent master-density phase strip</a> · <a href="spin-32-transparent.png">Native-density phase strip</a> · <a href="pilot-qa.json">Measured pilot QA</a> · <a href="../timing-probe/timing-summary.json">Native timing results</a> · <a href="../muzzle-anchors.json">Uncalibrated 256-muzzle proposal</a></p>
<p>Transparent strips are pilot samples of d=32 only. Full master/Factorio atlases and native muzzle calibration remain gated. Source, rig and production scripts are retained for the selected route.</p></html>'''
(PILOT/'index.html').write_text(page,encoding='utf-8')
print(json.dumps({'layouts':layouts,'pilot_records':len(records),'production_gate':summary['production_gate']},indent=2))
