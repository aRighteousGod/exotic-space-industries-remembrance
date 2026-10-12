"""Compose verified native-rig teaser renders and keep the best WebP under10MB."""
import argparse
import hashlib
import json
import math
from pathlib import Path
import numpy as np
from PIL import Image,ImageDraw,features
from seal_teaser_loop import seal

parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--input',type=Path,required=True)
parser.add_argument('--output',type=Path,required=True)
parser.add_argument('--limit',type=int,default=10_000_000)
args=parser.parse_args();root=args.input.resolve();out=args.output.resolve();out.mkdir(parents=True,exist_ok=True)
assert 0 < args.limit <= 10_000_000, 'Discord teaser limit must not exceed 10 million bytes'
assert features.check('webp_anim')
config=json.loads((root/'configuration.json').read_text());records=json.loads((root/'records.json').read_text())
expected=2*(28+config['turn_frames']-2)
assert len(records)==expected
for row in records.values():
    assert row['signature']==config['signature'] and hashlib.sha256((root/row['path']).read_bytes()).hexdigest()==row['sha256']
bounds=[row['alpha_bounds'] for row in records.values()]
box=[min(b[0] for b in bounds),min(b[1] for b in bounds),max(b[2] for b in bounds),max(b[3] for b in bounds)]
side=math.ceil(max(box[2]-box[0],box[3]-box[1])/0.86)
cx,cy=(box[0]+box[2])/2,(box[1]+box[3])/2
crop=(round(cx-side/2),round(cy-side/2),round(cx-side/2)+side,round(cy-side/2)+side)
size=config['size'];y,x=np.mgrid[0:size,0:size]
glow=np.exp(-(((x-size*.43)/(size*.60))**2+((y-size*.39)/(size*.68))**2))
back=np.stack([20+22*glow,24+23*glow,26+23*glow],axis=2).astype('uint8')
background=Image.fromarray(back).convert('RGBA')
cache={}
def composed(job):
    if job not in cache:
        shadow=Image.open(root/'frames/Shadow'/(job+'.png')).convert('RGBA').crop(crop)
        color=Image.open(root/'frames/Object'/(job+'.png')).convert('RGBA').crop(crop)
        if side!=size:
            shadow=shadow.resize((size,size),Image.Resampling.LANCZOS)
            color=color.resize((size,size),Image.Resampling.LANCZOS)
        shadow.putalpha(shadow.getchannel('A').point(lambda value:round(value*.42)))
        cache[job]=Image.alpha_composite(Image.alpha_composite(background,shadow),color).convert('RGB')
    return cache[job]
timeline=[('hero-00',350,'parked')]
timeline += [('hero-00' if i in (0,config['turn_frames']-1) else f'turn-{i:03}',40,'360 rotation')
             for i in range(config['turn_frames'])]
timeline += [(f'hero-{pose:02}',33,'spin up') for pose in config['pose_sequences']['up']]
timeline += [('hero-01',1200,'running blur')]
timeline += [(f'hero-{pose:02}',33,'spin down') for pose in config['pose_sequences']['down']]
timeline += [('hero-00',650,'parked')]
frames=[composed(job) for job,_,_ in timeline];durations=[duration for _,duration,_ in timeline]
attempts=[]
def encode(label,**options):
    path=root/(label+'.webp')
    frames[0].save(path,format='WEBP',save_all=True,append_images=frames[1:],duration=durations,
        loop=0,method=4,minimize_size=False,**options)
    row={'path':str(path),'bytes':path.stat().st_size,**options};attempts.append(row)
    print('TEASER_ENCODE '+json.dumps(row),flush=True)
    return row
# In lossless mode quality controls compression effort, not pixel fidelity.
# Avoid maximum-effort animation searches: this teaser needs detail and a cap,
# rather than the smallest possible file. Lossy quality remains separate below.
candidate=encode('teaser-lossless-fast',lossless=True,quality=30)
if candidate['bytes']>=args.limit:
    # Highest passing visual quality wins; there is no padding to a target size.
    for quality in range(100,79,-1):
        trial=encode(f'teaser-q{quality}',lossless=False,quality=quality)
        if trial['bytes']<args.limit:
            candidate=trial;break
assert candidate['bytes']<args.limit,'No high-quality candidate fits; inspect before changing resolution or frame count'
final=out/'minigun-360-spin-teaser.webp'
final.write_bytes(seal(Path(candidate['path']).read_bytes(), (size,size), args.limit))
poster=out/'minigun-teaser-poster.png';composed('hero-00').save(poster)
# Reopen the delivered file; verify size, animation, dimensions and exact loop duration.
with Image.open(final) as image:
    assert image.is_animated and image.size==(size,size) and image.info.get('loop')==0
    total=0
    for i in range(image.n_frames):
        image.seek(i);image.load();total+=image.info.get('duration',0)
    assert total==sum(durations),(total,sum(durations))
    decoded_frames=image.n_frames
contact=Image.new('RGB',(size*4,size*2),(20,24,26))
indices=[0,round(config['turn_frames']*.25),round(config['turn_frames']*.5),round(config['turn_frames']*.75)]
jobs=['hero-00']+[f'turn-{i:03}' for i in indices[1:]]+['hero-04','hero-01','hero-20','hero-00']
for i,job in enumerate(jobs):contact.paste(composed(job),((i%4)*size,(i//4)*size))
contact.thumbnail((1920,960));contact.save(out/'teaser-contact-sheet.jpg',quality=94)
report={'schema':'esir.minigun.discord-teaser.v1','file':final.name,'bytes':final.stat().st_size,
    'decimal_mb':final.stat().st_size/1_000_000,'strict_limit_bytes':args.limit,'size':[size,size],
    'duration_ms':total,'loop':0,'decoded_frames':decoded_frames,'render_configuration':config,
    'webp_method':4,'loop_endpoint_decoded_identical':True,
    'source_render_passes':len(records),'crop':list(crop),'encoding':candidate,'attempts':attempts,
    'sha256':hashlib.sha256(final.read_bytes()).hexdigest(),'timeline':timeline,
    'presentation_timing_only':True,'production_sprite_acceptance':False,
    'motion':'fixed foundation; complete eased yaw turn; front three-quarter spin up,90-degree barrel blur,spin down',
    'muzzle_effects':'barrel exposure only; native source effects remain separate game effects'}
(out/'teaser-report.json').write_text(json.dumps(report,indent=2)+'\n')
print('TEASER_READY '+json.dumps({key:report[key] for key in ('file','bytes','size','duration_ms','decoded_frames','sha256')}))
