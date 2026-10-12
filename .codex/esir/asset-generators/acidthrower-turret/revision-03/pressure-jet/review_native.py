"""Build native/elevated-scale comparisons from isolated Factorio captures."""
import argparse, hashlib, json
from pathlib import Path
import numpy as np
from PIL import Image,ImageDraw

p=argparse.ArgumentParser();p.add_argument('--root',type=Path,required=True)
p.add_argument('--profiles',nargs='+',default=['original','2x','4x','8x','16x'])
p.add_argument('--candidate-profiles',nargs='*',default=[])
args=p.parse_args();root=args.root;gallery=root/'gallery';gallery.mkdir(exist_ok=True)
html=['<!doctype html><meta charset="utf-8"><title>Acidthrower pressure jet</title>',
    '<style>body{background:#1b1f21;color:#eee;font:16px system-ui;margin:24px}img{max-width:100%;image-rendering:pixelated}section{margin:32px 0}a{color:#afcf78}details{margin:16px 0}.native{max-width:none}button{padding:8px}</style>',
    '<h1>Acidthrower / pressure jet</h1><p>Native Factorio 2.0.77 captures. Old lobbed stream above, revised liquid jet below. Sector-edge shots use 47.9 degrees and tiny inward range tolerances to avoid fixed-point rejection.</p>',
    '<button onclick="document.querySelectorAll(\'img\').forEach(i=>i.classList.toggle(\'native\'))">Toggle actual pixel size / fit window</button>']
metrics={}
if args.candidate_profiles:
    html.append('<p><strong>8x/16x refresh compatibility is an isolated candidate, pending the user choice.</strong> See <a href="../refresh-proposal.md">the tested proposal</a>. Other profiles show production definitions.</p>')
for profile in args.profiles:
    candidate=profile in args.candidate_profiles
    run_name=f'{profile}-visual'+('-refresh-candidate' if candidate else '')
    run=root/'qc'/run_name;captures=run/'script-output/captures'
    report=json.loads((run/'script-output/jet-report.json').read_text())
    assert len(report['captures'])==264
    html.append(f'<section><h2>{profile}'+(' / isolated refresh candidate' if candidate else '')+'</h2>')
    for distance in (9,24,38):
        pair=[]
        for variant in ('old','new'):
            im=Image.open(captures/f'matrix-2-{distance}-0-{variant}-day.png').convert('RGB')
            # Crop blank margins only, preserving every native pixel of the FX.
            im=im.crop((100,110,im.width-90,510))
            panel=Image.new('RGB',(im.width,im.height+24),(27,31,33));panel.paste(im,(0,24))
            ImageDraw.Draw(panel).text((10,7),f'{variant} / {distance} tiles / {profile}',fill='white')
            pair.append(panel)
        joined=Image.new('RGB',(pair[0].width,sum(i.height for i in pair)),(27,31,33))
        joined.paste(pair[0],(0,0));joined.paste(pair[1],(0,pair[0].height))
        name=f'{profile}-{distance}-comparison.png';joined.save(gallery/name)
        html.append(f'<h3>{distance} tiles</h3><a href="{name}"><img src="{name}"></a>')
    nozzle=Image.new('RGB',(1024,1072),(27,31,33));draw=ImageDraw.Draw(nozzle)
    for facing in range(1,5):
        x=((facing-1)%2)*512;y=((facing-1)//2)*536
        nozzle.paste(Image.open(captures/f'muzzle-{facing}-new.png').convert('RGB'),(x,y+24))
        draw.text((x+12,y+6),['North','East','South','West'][facing-1]+' / 3x native',fill='white')
    nozzle.save(gallery/f'{profile}-nozzles.png')
    html.append(f'<details><summary>Barrel-tip connection, four facings</summary><img src="{profile}-nozzles.png"></details>')
    frames=[]
    for tick in range(560,781,4):
        panel=Image.new('RGB',(1060,730),(27,31,33));d=ImageDraw.Draw(panel)
        for row,variant in enumerate(('old','new')):
            im=Image.open(captures/f'sequence-{variant}-{tick}.png').convert('RGB')
            im=im.crop((100,140,1160,480));panel.paste(im,(0,row*365+25))
            d.text((12,row*365+7),f'{variant} / '+('firing' if tick<600 else f'emission stopped {(tick-600)/60:.2f}s ago'),fill='white')
        frames.append(panel)
    frames[0].save(gallery/f'{profile}-shutdown.gif',save_all=True,append_images=frames[1:],duration=67,loop=0)
    html.append(f'<h3>Firing and shutdown</h3><img src="{profile}-shutdown.gif"><details><summary>All native day/night and sector captures</summary><ul>')
    for name in report['captures']:
        if name.startswith('matrix-'):html.append(f'<li><a href="../qc/{run_name}/script-output/captures/{name}.png">{name}</a></li>')
    html.append('</ul></details></section>')
    if profile=='original':
        row=next(r for r in report['probes'] if r['key']=='2/38/0/new')
        im=Image.open(captures/'matrix-2-38-0-new-day.png').convert('RGB');a=np.asarray(im,dtype=float)
        centre=np.array([(row['position']['x']+row['point']['x'])/2,(row['position']['y']+row['point']['y'])/2-1])
        def screen(pos):return (np.array([pos['x'],pos['y']])-centre)*32+np.array(im.size)/2
        start,end=screen(row['source_position']),screen(row['first_impact'])
        values=[]
        for x in range(int(start[0]+20),int(end[0]-100)):
            yline=start[1]+(end[1]-start[1])*(x-start[0])/(end[0]-start[0])
            lo,hi=int(yline-12),int(yline+12)
            rgb=a[lo:hi,x];green=(rgb[:,1]>50)&(rgb[:,1]>1.12*rgb[:,0])&(rgb[:,1]>1.9*rgb[:,2])
            ys=np.flatnonzero(green)+lo
            if len(ys):values.append((len(ys),yline-float(np.median(ys)),yline-float(ys.min())))
        v=np.array(values)
        metrics={'sampled_columns':len(values),'visible_fraction':len(values)/(int(end[0]-100)-int(start[0]+20)),
            'median_core_pixels':float(np.median(v[:,0])),'width_p10_p90':np.percentile(v[:,0],[10,90]).tolist(),
            'near_nozzle_median_pixels':float(np.median(v[:100,0])),
            'maximum_centreline_bow_pixels':float(v[:,1].max()),
            'maximum_visible_bow_pixels':float(v[:,2].max()),'maximum_bow_tiles':float(v[:,2].max()/32)}
        assert metrics['maximum_bow_tiles']<.25,metrics
        close=im.crop((int(start[0])+10,int(start[1])-12,int(start[0])+210,int(start[1])+20))
        close.resize((1200,192),Image.Resampling.NEAREST).save(gallery/'liquid-detail-6x.png')
html.append('<h2>Liquid texture / 6x nearest-pixel enlargement</h2><img src="liquid-detail-6x.png">')
html.append('<h2>Machine regression</h2><p><a href="../machine-check/gallery/native-fine-rotation.gif">Fine rotation</a> / <a href="../machine-check/gallery/native-shutdown.gif">Active-only glow shutdown</a> / <a href="../machine-check/gallery/native-draw-order.png">Four-facing pipe draw order</a> / <a href="../validation-summary.json">Native validation summary</a></p>')
(gallery/'index.html').write_text('\n'.join(html),encoding='utf-8')
(root/'native-liquid-metrics.json').write_text(json.dumps(metrics,indent=2))
print(json.dumps(metrics))
