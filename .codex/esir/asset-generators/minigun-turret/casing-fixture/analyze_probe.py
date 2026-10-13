"""Measure still native markers against the common registered ground anchor."""
from pathlib import Path
import argparse, json, math
import numpy as np
from PIL import Image

parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--attempt',default='002')
parser.add_argument('--dossier',type=Path,default=Path.cwd()/'output/minigun-implementation/casing-ejection-001')
args=parser.parse_args()
root=args.dossier.resolve()
stage=json.loads((root/f'probe-{args.attempt}-stage.json').read_text(encoding='utf-8-sig'))
run=Path(stage['run'])
report=json.loads((root/'probe-report.json').read_text(encoding='utf-8-sig'))
out=[]
for capture in report['captures']:
    array=np.asarray(Image.open(run/'script-output'/capture['path']).convert('RGB'))
    r,g,b=[array[:,:,i].astype(float) for i in range(3)]
    mask=(r>100)&(b>100)&(g<0.4*np.minimum(r,b))
    width,height=capture['resolution']
    density=32*capture['zoom']
    rows=[r for r in report['rows'] if r['profile']==capture['profile']]
    for row in rows:
        gx=width/2+(row['position'][0]-capture['position'][0])*density
        gy=height/2+(row['position'][1]-capture['position'][1])*density
        xa,xb=int(gx-115),int(gx+115)
        ya,yb=int(gy-115),int(gy+115)
        sy,sx=np.where(mask[max(0,ya):min(height,yb),max(0,xa):min(width,xb)])
        if not len(sx):
            out.append({**row,'marker_found':False})
            continue
        x=float(sx.mean()+max(0,xa)+0.5)
        y=float(sy.mean()+max(0,ya)+0.5)
        dx,dy=(x-gx)/density,(y-gy)/density
        phi=row['direction']*math.tau/256
        expected=(.43*math.cos(phi)-.85*math.sin(phi),
                  (.43*math.sin(phi)+.85*math.cos(phi)-1.65)/math.sqrt(2))
        out.append({**row,'marker_found':True,'marker_pixel':[x,y],
            'ground_pixel':[gx,gy],'offset':[dx,dy],
            'expected_offset':expected,'error_native_pixels':math.dist((dx,dy),expected)*32})
for label in dict.fromkeys(row['label'] for row in out):
    group=[row for row in out if row['label']==label]
    print(label,[(r['direction'],[round(v,4) for v in r.get('offset',[])],r['shots']) for r in group])
(root/'probe-measurements.json').write_text(json.dumps({'attempt':args.attempt,'rows':out},indent=2)+'\n')
