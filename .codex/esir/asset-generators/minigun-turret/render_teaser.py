"""Render a presentation turntable using the approved separated rig/exposures.

This is a Discord presentation master, not a production sprite acceptance run.
The native fixed foundation stays fixed while the upper assembly turns once.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
import runpy
import shutil
import sys
import time
import bpy
import numpy as np

parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--output',type=Path,required=True)
parser.add_argument('--size',type=int,default=960)
parser.add_argument('--samples',type=int,default=128)
parser.add_argument('--turn-frames',type=int,default=120)
args=parser.parse_args(sys.argv[sys.argv.index('--')+1:])
output=args.output.resolve();output.mkdir(parents=True,exist_ok=True)
assert args.turn_frames>=64 and 540<=args.size<=1440
repo=Path.cwd()
source=repo/'.codex/esir/asset-generators/minigun-turret/render_separated.py'
sys.argv=[str(source),'--','--output',str(output/'rig-initialization'),
    '--directions','96','--families','full','--poses','0','--samples',str(args.samples),'--proof-only']
# Reuse the approved rig loader, camera-driver freeze and continuous exposure
# functions. Proof-only initialization renders no image and promotes no asset.
rig=runpy.run_path(str(source))
scene=rig['scene'];scene.render.resolution_x=args.size;scene.render.resolution_y=args.size
scene.render.resolution_percentage=100
configuration={'schema':'esir.minigun.discord-teaser.v1','presentation_only':True,
    'source_sha256':rig['SOURCE_SHA256'],'prepared_scene_sha256':rig['configuration']['scene_sha256'],
    'rig_renderer_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),
    'generator_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
    'size':args.size,'samples':args.samples,'seed':0,'turn_frames':args.turn_frames,
    'hero_direction':96,'fixed_foundation':True,'color_pipeline':scene.view_settings.view_transform,
    'device':rig['device'],'blender':bpy.app.version_string,
    'pose_sequences':{'up':[0,*range(2,12),1],'down':[1,*range(12,28),0]}}
signature=hashlib.sha256(json.dumps(configuration,sort_keys=True).encode()).hexdigest()
config_path=output/'configuration.json'
if config_path.exists():
    assert json.loads(config_path.read_text())['signature']==signature,'Use a new output for changed teaser settings'
else: config_path.write_text(json.dumps({'signature':signature,**configuration},indent=2)+'\n')
records_path=output/'records.json'
records=json.loads(records_path.read_text()) if records_path.exists() else {}
jobs=[(f'hero-{pose:02}',96.0,pose) for pose in range(28)]
for index in range(1,args.turn_frames-1):
    t=index/(args.turn_frames-1);ease=t*t*(3-2*t)
    jobs.append((f'turn-{index:03}',(96+256*ease)%256,0))
started=time.monotonic()
for job,direction,pose in jobs:
    for label in ('Object','Shadow'):
        key=job+'/'+label;path=output/'frames'/label/(job+'.png')
        old=records.get(key)
        if old and old['signature']==signature and path.is_file() and hashlib.sha256(path.read_bytes()).hexdigest()==old['sha256']:
            continue
        assert shutil.disk_usage(output).free>5*1024**3,'Less than 5GiB free'
        rig['setup_pass'](label,path);proof=rig['pose']('full',direction,pose)
        before=time.monotonic();bpy.ops.render.render(write_still=False)
        assert path.is_file()
        image=bpy.data.images.load(str(path),check_existing=False)
        pixels=np.empty(args.size*args.size*4,dtype=np.float32);image.pixels.foreach_get(pixels)
        yy,xx=np.where(pixels.reshape(args.size,args.size,4)[:,:,3]>0)
        assert len(xx)>0
        bounds=[int(xx.min()),int(args.size-1-yy.max()),int(xx.max()+1),int(args.size-yy.min())]
        margin=min(bounds[0],bounds[1],args.size-bounds[2],args.size-bounds[3])
        assert margin>=math.ceil(8*args.size/540),(job,label,bounds)
        bpy.data.images.remove(image)
        record={'job':job,'direction':direction,'pose':pose,'pass':label,'signature':signature,
            'path':path.relative_to(output).as_posix(),'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),
            'seconds':time.monotonic()-before,'alpha_bounds':bounds,'margin':margin,'pose_proof_error':proof}
        records[key]=record
        temporary=records_path.with_suffix('.json.tmp');temporary.write_text(json.dumps(records,indent=2)+'\n')
        temporary.replace(records_path)
        print('TEASER_FRAME '+json.dumps(record),flush=True)
print('TEASER_RENDER_COMPLETE '+json.dumps({'passes':len(records),'seconds':time.monotonic()-started}),flush=True)
