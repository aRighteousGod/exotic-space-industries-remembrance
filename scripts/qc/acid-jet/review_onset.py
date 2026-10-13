"""Measure early sustained breakup and export native-pixel comparison strips."""
import json, math, argparse
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw

p=argparse.ArgumentParser();p.add_argument('root',type=Path);p.add_argument('--out',type=Path,default=Path('temp/acid-onset-review'));a=p.parse_args();a.out.mkdir(parents=True,exist_ok=True)
run=a.root/'qc/original-visual/script-output'; report=json.loads((run/'jet-report.json').read_text());rows=[]
def coords(row,im):
    center=np.array([(row['position']['x']+row['point']['x'])/2,(row['position']['y']+row['point']['y'])/2-1])
    start=(np.array([row['last_source_position']['x'],row['last_source_position']['y']])-center)*32+np.array(im.size)/2
    end=(np.array([row['first_impact']['x'],row['first_impact']['y']])-center)*32+np.array(im.size)/2
    return start,end
for row in report['probes']:
    if row.get('facing')!=2 or row['angle']!=0:continue
    variant=row['variant'];distance=row['distance']
    for night in (False,True):
        im=Image.open(run/'captures'/('matrix-2-'+str(distance)+'-0-'+variant+('-night.png' if night else '-day.png')))
        im=im.convert('RGB');pix=np.asarray(im,dtype=float);start,end=coords(row,im);vec=end-start;length=np.linalg.norm(vec);along=vec/length;normal=np.array([-along[1],along[0]])
        green=(pix[:,:,1]>(10 if night else 30))&(pix[:,:,1]>pix[:,:,0]*1.12)&(pix[:,:,1]>pix[:,:,2]*1.8)
        y,x=np.where(green);xy=np.stack([x,y],axis=-1)-start;u=xy@along;v=xy@normal
        keep=(u>10)&(u<length-100)&(abs(v)<35);u,v=u[keep],v[keep]
        bins=[]
        for lower in np.arange(.04,.90,.04):
            vals=v[(u>=lower*length)&(u<(lower+.04)*length)]
            if len(vals)==0:bins.append({'progress':round(lower,2),'n':0});continue
            hist,edges=np.histogram(vals,bins=np.arange(-35,36));center=(edges[hist.argmax()]+edges[hist.argmax()+1])/2
            bins.append({'progress':round(lower,2),'n':len(vals),'width':round(float(np.ptp(vals))+1,2),'core_center':center,'outer_pixels':int(sum(abs(vals-center)>3)), 'outer_per_column':round(float(sum(abs(vals-center)>3))/(.04*length),3)})
        rows.append({'distance':distance,'variant':variant,'night':night,'length':length,'bins':bins})
        if not night:
            x,y=map(lambda z:int(round(z)),start);width=int(round(length))+30
            crop=im.crop((x-15,y-35,x+width-15,y+50));crop=crop.resize((width*2,170),Image.Resampling.NEAREST)
            crop.save(a.out/f'{distance}-{variant}-detail.png')
for distance in (9,24,38):
    panels=[Image.open(a.out/f'{distance}-{variant}-detail.png').convert('RGB') for variant in ('old','new')]
    out=Image.new('RGB',(panels[0].width,400),(20,23,21));draw=ImageDraw.Draw(out)
    for i,panel in enumerate(panels):out.paste(panel,(0,i*200+26));draw.text((8,i*200+6),('Approved' if i==0 else 'Candidate')+f' / {distance} tiles / 2x',fill='white')
    out.save(a.out/f'{distance}-comparison.png')
(a.out/'onset-measurements.json').write_text(json.dumps(rows,indent=2))
print(json.dumps({'records':len(rows),'output':str(a.out)}))
