"""Extract immutable atlas cells for user-guided outlet picking; no art edits."""
import argparse,base64,hashlib,io,json
from pathlib import Path
from PIL import Image

repo=Path.cwd()
parser=argparse.ArgumentParser()
parser.add_argument('--output-root',type=Path,default=repo/'output/acidthrower-origin-calibration-20261013')
root=parser.parse_args().output_root;root.mkdir(parents=True,exist_ok=True)
template_path=Path(__file__).resolve().parent/'origin-picker.template.html'
art=repo/'exotic-space-industries-remembrance-graphics-6/graphics/entities/acidthrower-turret'
head=Image.open(art/'acidthrower-head.png').convert('RGBA')
base=Image.open(art/'acidthrower-base.png').convert('RGBA')
assert head.size==(4096,4096) and base.size==(1280,320)
def encoded(im):
    out=io.BytesIO();im.save(out,format='PNG',optimize=True)
    return 'data:image/png;base64,'+base64.b64encode(out.getvalue()).decode('ascii')
bearing_x,bearing_y,rear=.0014700282,.6423900127,.18
shifts={'N':(bearing_x,-bearing_y+rear),'E':(bearing_y-rear,bearing_x),
        'S':(-bearing_x,bearing_y-rear),'W':(-bearing_y+rear,-bearing_x)}
base_shifts={'N':(0,rear),'E':(-rear,0),'S':(0,-rear),'W':(rear,0)}
poses=[]
for key,label,placement,frame in [
    ('ESE','Angled right (ESE)','E',86),
    ('E','East / right','E',64),('S','South / down','S',128),
    ('SE','Southeast / down-right','E',103),('NE','Northeast / up-right','E',25),
    ('W','West / left','W',192),('N','North / up','N',0),
    ('SW','Southwest / down-left','S',153),('NW','Northwest / up-left','W',231)]:
    x,y=frame%16*256,frame//16*256
    cell=head.crop((x,y,x+256,y+256))
    hx,hy=(32+v*64 for v in shifts[placement])
    bounds=cell.getbbox();margin=14
    left,top,right,bottom=bounds
    poses.append({'id':key,'label':label,'placement':placement,'head_frame':frame,
        'head_offset':[hx,hy],'base_offset':[v*64 for v in base_shifts[placement]],
        'viewbox':[hx+left-margin,hy+top-margin,right-left+2*margin,bottom-top+2*margin],
        'image':encoded(cell)})
data={'calibration_id':'acidthrower-grey-outlet-20261013-v1',
    'atlas_sha256':hashlib.sha256((art/'acidthrower-head.png').read_bytes()).hexdigest(),
    'base_sha256':hashlib.sha256((art/'acidthrower-base.png').read_bytes()).hexdigest(),
    'bases':{f:encoded(base.crop((i*320,0,(i+1)*320,320))) for i,f in enumerate('NESW')},'poses':poses}
template=template_path.read_text(encoding='utf-8')
fragment=template.replace('__ACID_DATA__',json.dumps(data,separators=(',',':')))
assert '__ACID_DATA__' not in fragment and len(fragment.encode('utf-8'))<1000000
out=root/'acidthrower-origin-picker.html';out.write_text(fragment,encoding='utf-8')
manifest={**data,'bases':list(data['bases']), 'poses':[{k:v for k,v in p.items() if k!='image'} for p in poses]}
(root/'calibration-manifest.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
print(json.dumps({'path':str(out),'bytes':out.stat().st_size,'poses':len(poses),'atlas_sha256':data['atlas_sha256']}))
