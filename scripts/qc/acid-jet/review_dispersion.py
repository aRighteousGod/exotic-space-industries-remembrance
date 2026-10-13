"""Review native liquid dispersion, independently marked outlets and comparisons."""
import argparse, hashlib, json, math
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw

p=argparse.ArgumentParser()
p.add_argument('--root',type=Path,required=True)
p.add_argument('--profiles',nargs='+',default=['original','2x','4x','8x','16x'])
args=p.parse_args();root=args.root;gallery=root/'gallery';gallery.mkdir(exist_ok=True)
# Manually measured shipping-atlas pixels; these are independent of the old
# model anchor and production source formula. Back-facing caps have larger
# uncertainty than the seven visible bores/side mouths.
outlets={
    (1,-48):(229,95.5,60,False),(1,0):(0,128,52,False),(1,48):(27,160,60,False),
    (2,-48):(23,156.5,58,False),(2,0):(64,180,88,True),(2,48):(105,157,120,True),
    (3,-48):(101,160,118,True),(3,0):(128,128,125,True),(3,48):(155,96,118,True),
    (4,-48):(151,99,120,True),(4,0):(192,76,88,True),(4,48):(233,99,60,False)}
bearing_x,bearing_y=.0014700282,.6423900127
shifts=[(bearing_x,-bearing_y+.18),(bearing_y-.18,bearing_x),
        (-bearing_x,bearing_y-.18),(-bearing_y+.18,-bearing_x)]
html=['<!doctype html><meta charset="utf-8"><title>Acidthrower liquid dispersion</title>',
    '<style>body{background:#1b1f21;color:#eee;font:16px system-ui;margin:24px}img{max-width:100%;image-rendering:pixelated}a{color:#afcf78}details{margin:20px 0}.native{max-width:none}button{padding:8px}</style>',
    '<h1>Acidthrower / nozzle attachment and liquid breakup</h1>',
    '<p>Fresh Factorio 2.0.77 captures. Approved pressure jet above, revised liquid breakup below. Cyan muzzle markers show actual native launch positions. No machine image was regenerated.</p>',
    '<p>The attachment report measures actual green ribbon pixels against the grey cylindrical outlet ahead of the ivory housing. Clean and marked captures are separate emission phases; sparse phase gaps are retained.</p>',
    '<button onclick="document.querySelectorAll(\'img\').forEach(i=>i.classList.toggle(\'native\'))">Toggle native pixels / fit window</button>']
metrics=[];muzzles=[];attachments=[]

def world_to_screen(pos,centre,size,zoom=1):
    return (np.array([pos['x'],pos['y']])-centre)*32*zoom+np.array(size)/2

def ribbon_attachment(row,path,marked):
    """Measure real green pixels, not only the native source marker.

    Clean/marked captures are different emission phases. Never subtract them:
    a sparse phase can legitimately have no liquid in the first six pixels.
    """
    im=Image.open(path).convert('RGB');a=np.asarray(im,dtype=float);zoom=4
    centre=np.array([row['position']['x'],row['position']['y']-.3])
    start=world_to_screen(row['last_source_position'],centre,im.size,zoom)
    theta=row['last_launch_orientation']*2*math.pi
    along=np.array([math.sin(theta),-math.cos(theta)]);normal=np.array([-along[1],along[0]])
    y,x=np.indices(a.shape[:2]);xy=np.stack([x-start[0],y-start[1]],axis=-1)
    u=xy@along;w=xy@normal
    green=(a[:,:,1]>45)&(a[:,:,1]>a[:,:,0]*1.15)&(a[:,:,1]>a[:,:,2]*1.8)
    near=green&(u>-16)&(u<25)&(np.abs(w)<20)
    frame,ax,ay,visible=outlets[(row['facing'],row['angle'])]
    relative=np.array(shifts[row['facing']-1])+np.array([ax-128,ay-128])/64
    outlet=relative*32*zoom+np.array(im.size)/2+np.array([0,.3*32*zoom])
    pixels=np.column_stack((x[near],y[near]));corridor=green&(u>=-16)&(u<=128)&(np.abs(w)<16)
    return {'key':row['key'],'marked':marked,'visible_bore':visible,
        'mean_transverse_pixels':float(w[near].mean()/zoom) if near.any() else None,
        'nearest_liquid_to_grey_outlet_pixels':float(np.linalg.norm(pixels-outlet,axis=1).min()/zoom) if near.any() else None,
        'first_liquid_along_pixels':float(u[corridor].min()/zoom) if corridor.any() else None}

def widths(row,path,night):
    im=Image.open(path).convert('RGB');a=np.asarray(im,dtype=float)
    centre=np.array([(row['position']['x']+row['point']['x'])/2,
        (row['position']['y']+row['point']['y'])/2-1])
    start=world_to_screen(row['last_source_position'],centre,im.size)
    end=world_to_screen(row['first_impact'],centre,im.size)
    v=end-start;length=np.linalg.norm(v);along=v/length;normal=np.array([-along[1],along[0]])
    green=(a[:,:,1]>(10 if night else 35))&(a[:,:,1]>a[:,:,0]*1.12)&(a[:,:,1]>a[:,:,2]*1.8)
    y,x=np.where(green);xy=np.stack([x,y],axis=-1)-start
    u=xy@along;w=xy@normal
    usable=(u>50)&(u<length-100)&(np.abs(w)<40)
    u,w=u[usable],w[usable]
    results=[]
    for lo,hi in [(.12,.28),(.4,.6),(.7,.88)]:
        spans=[];coverage=[];centres=[];core=[]
        for left in np.arange(max(50,length*lo),min(length-100,length*hi),8):
            values=w[(u>=left)&(u<left+8)]
            if len(values)<3:continue
            hist,edges=np.histogram(values,bins=np.arange(-40,41))
            peak=np.argmax(hist);c=(edges[peak]+edges[peak+1])/2
            close=values[np.abs(values-c)<=2]
            centres.append(c)
            core.append(float(np.ptp(close)+1) if len(close) else 0)
            spans.append(float(np.ptp(values)+1))
            coverage.append(len(values)/8)
        results.append({'progress':[lo,hi],'samples':len(spans),
            'total_envelope_pixels':float(np.ptp(w[(u>=length*lo)&(u<min(length*hi,length-100))])+1)
                if np.any((u>=length*lo)&(u<min(length*hi,length-100))) else 0,
            'median_envelope_pixels':float(np.median(spans)) if spans else 0,
            'p90_envelope_pixels':float(np.percentile(spans,90)) if spans else 0,
            'median_core_pixels':float(np.median(core)) if core else 0,
            'median_core_offset_pixels':float(np.median(centres)) if centres else 0,
            'occupied_pixels_per_column':float(np.median(coverage)) if coverage else 0})
    return results

for profile in args.profiles:
    run=root/'qc'/f'{profile}-visual';captures=run/'script-output/captures'
    report=json.loads((run/'script-output/jet-report.json').read_text())
    assert report['pressure_baseline'] and len(report['captures'])==352
    html.append(f'<h2>{profile}</h2>')
    for distance in (9,24,38):
        panels=[]
        for variant in ('old','new'):
            im=Image.open(captures/f'matrix-2-{distance}-0-{variant}-day.png').convert('RGB')
            im=im.crop((80,80,im.width-70,540))
            panel=Image.new('RGB',(im.width,im.height+24),(27,31,33));panel.paste(im,(0,24))
            ImageDraw.Draw(panel).text((10,7),f'{"Approved" if variant=="old" else "Revised"} / {distance} tiles / {profile}',fill='white')
            panels.append(panel)
        joined=Image.new('RGB',(panels[0].width,sum(i.height for i in panels)),(27,31,33))
        joined.paste(panels[0],(0,0));joined.paste(panels[1],(0,panels[0].height))
        name=f'{profile}-{distance}-comparison.png';joined.save(gallery/name)
        html.append(f'<h3>{distance} tiles</h3><a href="{name}"><img src="{name}"></a>')
    nozzle=Image.new('RGB',(1536,4*536),(27,31,33));draw=ImageDraw.Draw(nozzle)
    for facing in range(1,5):
        for column,angle in enumerate((-48,0,48)):
            x,y=column*512,(facing-1)*536
            nozzle.paste(Image.open(captures/f'muzzle-{facing}-{angle}-new-marked.png').convert('RGB'),(x,y+24))
            draw.text((x+10,y+5),f'{("N","E","S","W")[facing-1]} / {angle} / native launch marker',fill='white')
    nozzle.save(gallery/f'{profile}-outlets.png')
    html.append(f'<details><summary>Twelve outlet poses, actual source markers</summary><img src="{profile}-outlets.png"></details>')
    frames=[]
    for tick in range(560,781,4):
        panel=Image.new('RGB',(1060,730),(27,31,33));draw=ImageDraw.Draw(panel)
        for row,variant in enumerate(('old','new')):
            im=Image.open(captures/f'sequence-{variant}-{tick}.png').convert('RGB')
            im=im.crop((100,140,1160,480));panel.paste(im,(0,row*365+25))
            draw.text((12,row*365+7),f'{variant} / '+('firing' if tick<600 else f'stopped {(tick-600)/60:.2f}s ago'),fill='white')
        frames.append(panel)
    frames[0].save(gallery/f'{profile}-shutdown.gif',save_all=True,append_images=frames[1:],duration=67,loop=0)
    html.append(f'<h3>Firing and shutdown</h3><img src="{profile}-shutdown.gif">')
    if profile=='original':
        detail=Image.new('RGB',(2400,432),(27,31,33));detail_draw=ImageDraw.Draw(detail)
        for i,variant in enumerate(('old','new')):
            row=next(r for r in report['probes'] if r['key']==f'2/38/0/{variant}')
            im=Image.open(captures/f'matrix-2-38-0-{variant}-day.png').convert('RGB')
            centre=np.array([(row['position']['x']+row['point']['x'])/2,
                (row['position']['y']+row['point']['y'])/2-1])
            point=world_to_screen(row['last_source_position'],centre,im.size)
            x,y=round(point[0]),round(point[1])
            crop=im.crop((x-8,y-24,x+792,y+40)).resize((2400,192),Image.Resampling.NEAREST)
            detail.paste(crop,(0,i*216+24))
            detail_draw.text((12,i*216+5),f'{variant} / outlet to downstream breakup / 3x native pixels',fill='white')
        detail.save(gallery/'liquid-detail-3x.png')
        html.append('<h3>Liquid texture and dispersion / 3x nearest-pixel enlargement</h3><a href="liquid-detail-3x.png"><img src="liquid-detail-3x.png"></a>')
        coating=Image.new('RGB',(1024,3*536),(27,31,33));draw=ImageDraw.Draw(coating)
        for row,kind in enumerate(('sticker-small','sticker-large','sticker-moving')):
            for col,variant in enumerate(('old','new')):
                coating.paste(Image.open(captures/f'{kind}-{variant}-560.png').convert('RGB'),(col*512,row*536+24))
                draw.text((col*512+10,row*536+5),f'{kind} / {variant}',fill='white')
        coating.save(gallery/'wet-corrosion-comparison.png')
        html.append('<h3>Attached corrosion / repeated application</h3><img src="wet-corrosion-comparison.png">')
    for row in report['probes']:
        if not row.get('facing'):continue
        for night in (False,True):
            name='matrix-'+row['key'].replace('/','-')+('-night' if night else '-day')+'.png'
            metrics.append({'profile':profile,'key':row['key'],'night':night,
                'bins':widths(row,captures/name,night)})
        if row['variant']=='new' and row['distance']==24:
            frame,x,y,visible=outlets[(row['facing'],row['angle'])]
            shift=np.array(shifts[row['facing']-1])
            expected=shift+np.array([x-128,y-128])/64
            actual=np.array([row['last_source_position']['x']-row['position']['x'],
                row['last_source_position']['y']-row['position']['y']])
            angle=row['last_launch_orientation']*2*math.pi
            yaw=math.atan2(math.sin(angle),math.sqrt(2)*math.cos(angle))
            actual_frame=round(yaw*256/(2*math.pi))%256
            muzzles.append({'profile':profile,'facing':row['facing'],'aim':row['angle'],
                'marked_frame':frame,'engine_frame_estimate':actual_frame,'visible_bore':visible,
                'manual_source_pixel':[x,y],'error_native_pixels':float(np.linalg.norm(actual-expected)*32),
                'actual_relative':actual.tolist(),'marked_relative':expected.tolist()})
        if row['distance']==24:
            for marked in (False,True):
                name=f'muzzle-{row["facing"]}-{row["angle"]}-{row["variant"]}'+('-marked' if marked else '')+'.png'
                attachments.append({'profile':profile,**ribbon_attachment(row,captures/name,marked)})
    html.append('<details><summary>Every native capture</summary><ul>')
    for name in report['captures']:html.append(f'<li><a href="../qc/{profile}-visual/script-output/captures/{name}.png">{name}</a></li>')
    html.append('</ul></details>')
before=json.loads((root/'machine-hashes-before.json').read_text(encoding='utf-8-sig'))
hashes=[]
for r in before:
    path=Path('exotic-space-industries-remembrance-graphics-6/graphics/entities/acidthrower-turret')/Path(r['Path']).name
    hashes.append({'file':str(path),'unchanged':hashlib.sha256(path.read_bytes()).hexdigest().upper()==r['Hash']})
assert len(hashes)==7 and all(r['unchanged'] for r in hashes)
result={'matrix_widths':metrics,'outlet_measurements':muzzles,'visible_ribbon_attachment':attachments,'machine_hashes':hashes,
    'manual_measurement_uncertainty_source_pixels':{'visible_bores':1,'inferred_caps':2}}
(root/'dispersion-visual-qa.json').write_text(json.dumps(result,indent=2))
(gallery/'index.html').write_text('\n'.join(html),encoding='utf-8')
print(json.dumps({'profiles':args.profiles,'matrix_width_records':len(metrics),
    'max_outlet_error_native_pixels':max(r['error_native_pixels'] for r in muzzles),
    'seven_machine_sprites_unchanged':True}))
