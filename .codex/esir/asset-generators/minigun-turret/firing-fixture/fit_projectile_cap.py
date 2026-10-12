"""Locate the actual first tracer cap, independently of proposed launch positions.

Diagnostic only: retain uncertainty and native pictures; never approve a gate.
The source sprite and tint are checked against this run's final prototype audit.
"""
import argparse
import json
from pathlib import Path
import numpy as np
from PIL import Image,ImageDraw
from analyze_fixture import fs_path,rgb,sha
from fit_flash_origin import signal,rotation

def weighted_cap_match(source,template,weight):
    height,width=template.shape;rows,cols=source.shape
    shape=(rows+height-1,cols+width-1)
    def correlate(a,b):
        return np.fft.irfft2(np.fft.rfft2(a,s=shape)*np.conj(np.fft.rfft2(b,s=shape)),s=shape)[:rows-height+1,:cols-width+1]
    scores=correlate(source,template*weight)/np.sqrt(np.maximum(correlate(source*source,weight),1)*
        max(float((template*template*weight).sum()),1))
    y,x=np.unravel_index(np.argmax(scores),scores.shape)
    other=scores.copy();other[max(0,y-8):y+9,max(0,x-8):x+9]=-1
    return {'score':float(scores[y,x]),'origin_pixels':[int(x+width/2),int(y+height/2)],
        'translation_peak_margin':float(scores[y,x]-other.max())}

def run(root,out,source_png):
    root,out,source_png=fs_path(root),fs_path(out),fs_path(source_png);out.mkdir(parents=True,exist_ok=True)
    report=json.loads((root/'native-report.json').read_text(encoding='utf-8-sig'))
    with Image.open(source_png) as source:
        assert source.size==(3,50)
        rgba=np.asarray(source.convert('RGBA').resize((6,100),Image.Resampling.NEAREST),dtype=np.float32)
    results=[]
    for case in report['cases']:
        if case['spec']['kind']!='static' or case['spec']['ammo']!='piercing-rounds-magazine':continue
        rows={row['variant']:row for row in case['rows']}
        captures={name:{cap['shot_offset']:cap for cap in row['captures']} for name,row in rows.items()}
        panels={}
        for variant in ('native','projectile'):
            row=rows[variant];projectile=row['projectiles'][0]['effect_entity']
            animation=report['prototype_audit']['projectiles'][projectile['name']]['animation']
            assert (animation['filename'],animation['width'],animation['height'],animation['frame_count'],animation['blend_mode']) == (
                '__base__/graphics/entity/bullet/bullet.png',3,50,1,'additive')
            assert animation.get('shift',[0,0])==[0,0] and animation.get('scale',1)==1
            tint=animation.get('tint',{});color=np.array([tint.get(channel,1) for channel in ('r','g','b')])
            canvas=np.zeros((128,128,3),dtype=np.float32)
            canvas[14:114,61:67]=rgba[:,:,:3]*rgba[:,:,3:]/255*color
            template=signal(canvas);weight=np.zeros((128,128),dtype=np.float32);weight[12:47,55:73]=1
            heading=projectile['orientation']*360
            before=captures[variant][-1];blank_before=captures['blank'][-1]
            for offset in (0,1):
                cap=captures[variant][offset];blank=captures['blank'][offset]
                actual=rgb(root/cap['path'])
                delta=actual-rgb(root/before['path'])-rgb(root/blank['path'])+rgb(root/blank_before['path'])
                evidence=signal(delta);candidates=[]
                for correction in (-2,-1,0,1,2):
                    angle=-heading+correction
                    match=weighted_cap_match(evidence,rotation(template,angle),np.maximum(rotation(weight,angle),0))
                    match['angle_correction_degrees']=correction;candidates.append(match)
                best=dict(max(candidates,key=lambda entry:entry['score']))
                close=[entry for entry in candidates if entry['score']>=best['score']-.02]
                best.update(case=case['id'],variant=variant,shot_offset=offset,zoom=cap['zoom'],
                    capture=cap['path'],capture_sha256=sha(root/cap['path']),
                    prefire_capture=before['path'],prefire_sha256=sha(root/before['path']),
                    native_heading_degrees=heading,animation=animation,candidates=candidates,
                    approved=False,method='authored-leading-cap-plus-gutter;native-heading-plus-or-minus2degrees;unrestricted-translation',
                    interpretation='muzzle attachment' if offset==0 else 'moving glyph center, not muzzle',
                    competing_origin_spread_pixels=max(float(np.linalg.norm(np.asarray(entry['origin_pixels'])-best['origin_pixels'])) for entry in close))
                if offset==0:
                    best['proposed_anchor_error_native_pixels']=float(np.linalg.norm(np.asarray(best['origin_pixels'])-[160,160])/cap['zoom'])
                    best['near_best_maximum_anchor_error_native_pixels']=max(float(np.linalg.norm(np.asarray(entry['origin_pixels'])-[160,160])/cap['zoom']) for entry in close)
                results.append(best)
                panel=Image.fromarray(actual.astype('uint8'));draw=ImageDraw.Draw(panel);x,y=best['origin_pixels']
                draw.line((x-7,y,x+7,y),fill='#00ffff');draw.line((x,y-7,x,y+7),fill='#00ffff')
                draw.rectangle((158,158,162,162),outline='#ff00ff')
                panels[variant,offset]=panel
        strip=Image.new('RGB',(1280,350),(20,24,26));draw=ImageDraw.Draw(strip)
        before=Image.open(root/captures['native'][-1]['path']).convert('RGB')
        for index,(label,picture) in enumerate([('Pre-shot barrel',before),('Full native t0',panels['native',0]),
            ('Projectile control t0',panels['projectile',0]),('Full native t1',panels['native',1])]):
            strip.paste(picture,(320*index,30));draw.text((320*index+6,8),case['id']+' / '+label,fill='white')
        strip.save(out/(case['id']+'-projectile.png'))
    result={'schema':1,'status':'unreviewed-first-projectile-image-measurements','approved':False,
        'native_report_sha256':sha(root/'native-report.json'),'candidate_data_sha256':report['config']['candidate_data_sha256'],
        'source_png':str(source_png),'source_png_sha256':sha(source_png),'source_frame_center':[1.5,25],
        'results':results,'limitations':['Piercing bullet route only; all other visuals need their own audited source',
            'Native rendered images must be inspected before accepting the measured attachment',
            'CPU rotation is a fitting approximation; retain close alternatives and the exact-heading result']}
    (out/'first-projectile-measurements.json').write_text(json.dumps(result,indent=2)+'\n')
    return result

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--evidence',type=Path,required=True);parser.add_argument('--output',type=Path,required=True)
    parser.add_argument('--source-png',type=Path,default=Path('C:/Program Files (x86)/Steam/steamapps/common/Factorio/data/base/graphics/entity/bullet/bullet.png'))
    args=parser.parse_args();result=run(args.evidence,args.output,args.source_png)
    print(json.dumps({'status':result['status'],'measurements':len(result['results']),'approved':False}))
