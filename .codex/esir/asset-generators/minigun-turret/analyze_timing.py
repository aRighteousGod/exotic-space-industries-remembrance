"""Decode diagnostic phases and compare native shot/ammo curves with legacy."""
import argparse
import json
import shutil
from pathlib import Path
from PIL import Image, ImageDraw

parser=argparse.ArgumentParser()
parser.add_argument('--runs',nargs='+',type=Path,required=True)
parser.add_argument('--output',type=Path,default=Path('output/meshy/minigun-prototypes/prototype-2/handoff-256/timing-probe'))
args=parser.parse_args()
args.output.mkdir(parents=True,exist_ok=True)
reports=[]
def bits(image,y,count):
    result=0
    for bit in range(count):
        rgb=image.getpixel((16+2*(9+12*bit),32+2*y))[:3]
        if min(rgb)>215:result|=1<<bit
        elif max(rgb)>35:return None
    return result
for run in args.runs:
    report=json.loads((run/'script-output/minigun-timing-report.json').read_text())
    rows={r['id']:r for r in report['cases']}
    mode='on' if report['ballistic'] else 'off'
    advanced=any(r['variant']=='native16' for r in rows.values())
    glow=any(r['variant']=='glow1' for r in rows.values())
    glow_hidden=glow and 'local function blank' in (run/'mods/zzz-esir-minigun-timing/data-final-fixes.lua').read_text()
    label=mode+('-glow-hidden' if glow_hidden else '-glow' if glow else '-advanced' if advanced else '')
    retained=args.output/label
    retained.mkdir(exist_ok=True)
    shutil.copy2(run/'script-output/minigun-timing-report.json',retained/'native-report.json')
    for log in ('create.log','graphics.log'):
        shutil.copy2(run/log,retained/log)
    results=[]
    for row in rows.values():
        legacy=rows['legacy-'+row['id'].rsplit('-',1)[1]]
        phases=[]
        for capture in row['captures']:
            path=run/'script-output'/capture['path']
            assert path.exists(),path
            image=Image.open(path).convert('RGB')
            phase,state=bits(image,9,4),bits(image,24,3)
            phases.append({'elapsed':capture['elapsed'],'phase':phase,'state':state})
        steady=[r for r in phases if 110<=r['elapsed']<=150 and r['state']==3 and r['phase'] is not None]
        sequence=[r['phase'] for r in steady]
        deltas=[(b-a)%16 for a,b in zip(sequence,sequence[1:])]
        gaps=[b['elapsed']-a['elapsed'] for a,b in zip(steady,steady[1:])]
        ordered_motion=bool(sequence) and len(set(sequence))>=8 and all(0<=v<=gap for v,gap in zip(deltas,gaps))
        matches=row['curve']==legacy['curve'] and row.get('first_shot')==legacy.get('first_shot') and row['consumed']==legacy['consumed']
        assert row['shots']==row['consumed'],(row['id'],row['shots'],row['consumed'])
        result={'id':row['id'],'first_shot':row.get('first_shot'),'shots':row['shots'],'ammo_consumed':row['consumed'],
            'legacy_shots':legacy['shots'],'steady_660_ticks_shots':sum(v for k,v in row['curve'].items() if 90<=int(k)<750),
            'legacy_steady_660_ticks_shots':sum(v for k,v in legacy['curve'].items() if 90<=int(k)<750),
            'entire_shot_curve_matches_legacy':matches,'ordered_phase_progression':ordered_motion,
            'observed_steady_phases':sequence,'phase_deltas':deltas,'captures_verified':len(phases),
            'steady_decoded_frames':len(steady),'steady_unique_phases':len(set(sequence)),
            'visual_outcome':'ordered' if ordered_motion else 'no_decodable_overlay' if not sequence else 'static_or_aliased',
            'passes':matches and ordered_motion}
        results.append(result)
        (retained/(row['id']+'-decoded.json')).write_text(json.dumps(phases,indent=2)+'\n')
        if row['variant']!='legacy':
            gallery=Image.new('RGB',(160*8,128*2),'#20282d')
            for index,tick in enumerate(range(110,126)):
                path=run/'script-output'/next(c['path'] for c in row['captures'] if c['elapsed']==tick)
                gallery.paste(Image.open(path).convert('RGB'),((index%8)*160,(index//8)*128))
            gallery.save(retained/(row['id']+'-phase-sequence.png'))
    summary={'mode':mode,'advanced':advanced,'glow':glow,'glow_hidden':glow_hidden,'run':str(run),'errors':report['errors'],'results':results,
             'passing_candidates':[r['id'] for r in results if r['passes']]}
    reports.append(summary)
    (retained/'summary.json').write_text(json.dumps(summary,indent=2)+'\n')
(args.output/'timing-summary.json').write_text(json.dumps({'reports':reports,'any_pass':any(r['passing_candidates'] for r in reports)},indent=2)+'\n')
print(json.dumps([{'mode':r['mode'],'advanced':r['advanced'],'passes':r['passing_candidates'],
                  'cases':[{k:v for k,v in row.items() if k in ('id','first_shot','shots','entire_shot_curve_matches_legacy','ordered_phase_progression')} for row in r['results']]} for r in reports],indent=2))
