"""Register actual body pixels and report full-cycle native torso displacement."""
import argparse,json,sys,math
from pathlib import Path
import numpy as np
from PIL import Image
sys.dont_write_bytecode=True

p=argparse.ArgumentParser();p.add_argument('--source',type=Path,required=True);p.add_argument('--output',type=Path,required=True)
args=p.parse_args();root=Path(__file__).resolve().parents[3]
sys.path.insert(0,str(root/'.codex/esir/asset-generators/anisetron/reference17'))
from measure_twin_emitters import Evaluator,point
evaluator=Evaluator(root/'output/meshy/anisetron/reference17/prepared-v2/full128')
data=json.loads((args.source/'anisetron-stability/captures.json').read_text());trace={(r['key'],r['tick']):r for r in data['trace']}
rows=[]
for r in data['frames']:
 frame=Image.open(args.source/r['path']).convert('RGB');screen=np.asarray(frame,dtype=np.float32)/255
 index=math.floor(r['torso']*128+.5)%128
 raw,bounds,ref,_=evaluator.frame(index,1)
 gold=(ref[:,:,3]>.95)&(ref[:,:,0]>ref[:,:,2]*1.15)&(ref[:,:,0]>.035)
 sy,sx=np.nonzero(gold);sy,sx=sy[::3],sx[::3]
 reference=ref[:,:,:3].mean(2)[sy,sx];reference-=reference.mean();denominator=np.sqrt(np.sum(reference**2))
 gray=screen.mean(2);ys=np.arange(screen.shape[0]-ref.shape[0]+1)
 expected_x=round(screen.shape[1]/2+bounds[0]-raw.width/2)
 best=(-1,0,0)
 for x in range(expected_x-8,expected_x+9):
  if x<0 or x+ref.shape[1]>gray.shape[1]:continue
  actual=gray[ys[:,None]+sy[None,:],x+sx[None,:]]
  actual-=actual.mean(1)[:,None]
  scores=np.sum(actual*reference,axis=1)/(denominator*np.sqrt(np.sum(actual**2,axis=1)))
  y=int(np.nanargmax(scores));candidate=(float(scores[y]),x,y)
  if candidate>best:best=candidate
 score,x,y=best;loc=(x,y)
 pivot=np.array(loc,dtype=float)+[raw.width/2-bounds[0],raw.height/2-bounds[1]]
 camera=r['camera'];ground=np.array(camera['resolution'])/2+(point(r['position'])-point(camera['position']))*32
 next_row=trace.get((r['key'],r['tick']+1))
 if next_row:ground+=(point(next_row['position'])-point(r['position']))*32
 rows.append(dict(key=r['key'],tick=r['tick'],speed=r['speed'],score=score,
  height_tiles=float((ground[1]-pivot[1])/32),pivot=pivot.tolist(),path=r['path']))
groups={}
for key in sorted({r['key'] for r in rows}):
 g=[r for r in rows if r['key']==key]
 groups[key]={}
 for phase,part in [('cruise',[r for r in g if r['tick']<400]),('stop',[r for r in g if r['tick']>=496])]:
  heights=[r['height_tiles'] for r in part]
  groups[key][phase]={'min':min(heights),'max':max(heights),'span_pixels':(max(heights)-min(heights))*32,
   'mean':sum(heights)/len(heights),'min_score':min(r['score'] for r in part)}
result={'groups':groups,'rows':rows,'method':'Actual body-template registration; post-physics displacement included. Low-correlation or clipped cases are diagnostic only.'}
args.output.parent.mkdir(parents=True,exist_ok=True);args.output.write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(groups,indent=2))
