"""Check all named sets, source reproduction and promotion isolation without writes to shipping."""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import shutil
import subprocess
import sys
from PIL import Image

ROOT=Path(__file__).resolve().parents[3]
GEN=ROOT/'.codex/esir/asset-generators/alert-icons'
SHIP=ROOT/'exotic-space-industries-remembrance/graphics/gui/alerts'
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--stage',type=Path,required=True)
parser.add_argument('--rendered-stage',type=Path,required=True)
parser.add_argument('--vanilla-stage',type=Path,required=True)
parser.add_argument('--work-dir',type=Path,required=True)
args=parser.parse_args();stage=args.stage.resolve();rendered_stage=args.rendered_stage.resolve();work=args.work_dir.resolve()
assert any(work.is_relative_to(ROOT/p) for p in ('.factorio-qc','output','temp'))
assert not work.exists(),'Use fresh task-owned test output'
work.mkdir(parents=True)
sys.path.insert(0,str(GEN))
spec=importlib.util.spec_from_file_location('alert_icon_generator',GEN/'generate.py')
generator=importlib.util.module_from_spec(spec);spec.loader.exec_module(generator)
checks=0
def check(value,label):
    global checks
    checks+=1;assert value,label
def fingerprints():
    return {str(p):hashlib.sha256(p.read_bytes()).hexdigest()
            for folder in (SHIP,GEN/'sources') for p in folder.rglob('*') if p.is_file()}
before=fingerprints();manifest=json.loads((stage/'manifest.json').read_text())
for set_id,current in (('svg',stage),('rendered',rendered_stage),('vanilla',args.vanilla_stage.resolve())):
    data=json.loads((current/'manifest.json').read_text())
    check(data.get('set_id')==set_id and len(data['icons'])==27,'complete named '+set_id)
    pixels=set()
    for name in data['icons']:
        if set_id!='rendered':
            source=(current/'svg'/f'{name}.svg').read_text(encoding='utf-8')
            rendered=generator.render_svg(source)
        else:rendered=generator.render_raster(current/'raster'/f'{name}.png')[0]
        with Image.open(current/'png'/f'{name}.png') as expected:
            check(rendered.tobytes()==expected.tobytes(),set_id+'/'+name+' actual source reproduces PNG')
            check(expected.mode=='RGBA' and expected.getchannel('A').getextrema()==(0,255),name+' proper RGBA')
            check(expected.size==(128,128),name+' 128px')
            pixels.add(hashlib.sha256(expected.tobytes()).hexdigest())
            if set_id=='vanilla':
                ink=[(x,y) for y in range(128) for x in range(128)
                     if (lambda c:c[3]>240 and max(c[:3])<70)(expected.getpixel((x,y)))]
                check(len(ink)>400,name+' substantial dark pictogram')
                margin=min(min(x-(64-(y-5)*59/114),(64+(y-5)*59/114)-x,119-y) for x,y in ink)
                check(margin>=2,name+' pictogram remains inset from triangle: '+str(margin))
        check(generator.digest(current/'png'/f'{name}.png')==generator.digest(SHIP/set_id/f'{name}.png'),name+' shipping matches named stage')
    check(len(pixels)==27,set_id+' all icons distinct')
original=json.loads((GEN/'sources/original/manifest.json').read_text())
for path,digest in original['files'].items():
    check(generator.digest(ROOT/path)==digest,'Original retained: '+path)
def rejected(arguments,phrase):
    result=subprocess.run([sys.executable,'-B',str(GEN/'generate.py'),*arguments],cwd=ROOT,capture_output=True,text=True)
    check(result.returncode!=0 and phrase in result.stderr,'rejected: '+phrase)
rejected(['--staging-dir',str(stage)],'--set')
rejected(['--set','original','--staging-dir',str(stage),'--ship'],'invalid choice')
rejected(['--set','svg','--staging-dir',str(SHIP)],'ignored')
rejected(['--set','svg','--staging-dir',str(stage),'--ship','--pilot'],'pilot')
rejected(['--set','rendered','--staging-dir',str(stage),'--ship'],'does not match --set')
rejected(['--set','svg','--staging-dir',str(rendered_stage),'--ship'],'does not match --set')
rejected(['--set','vanilla','--staging-dir',str(stage),'--ship'],'does not match --set')
bad=work/'tampered';shutil.copytree(stage,bad)
first=next(iter(manifest['icons']))
with (bad/'png'/f'{first}.png').open('ab') as f:f.write(b'changed')
rejected(['--set','svg','--staging-dir',str(bad),'--ship'],'Staged file changed')
partial=work/'partial';partial.mkdir()
partial_manifest=dict(manifest);partial_manifest['icons']={first:manifest['icons'][first]}
(partial/'manifest.json').write_text(json.dumps(partial_manifest),encoding='utf-8')
rejected(['--set','svg','--staging-dir',str(partial),'--ship'],'complete 27-icon')
stale=work/'stale';stale.mkdir();stale_manifest=dict(manifest);stale_manifest['generator_hashes']={}
(stale/'manifest.json').write_text(json.dumps(stale_manifest),encoding='utf-8')
rejected(['--set','svg','--staging-dir',str(stale),'--ship'],'Generator changed')
bad_source=work/'tampered-source';shutil.copytree(stage,bad_source)
with (bad_source/'svg'/f'{first}.svg').open('ab') as f:f.write(b'changed')
rejected(['--set','svg','--staging-dir',str(bad_source),'--ship'],'Staged file changed')
result=subprocess.run([sys.executable,'-B',str(GEN/'generate.py'),'--set','svg','--staging-dir',str(work/'preview'),'--pilot'],cwd=ROOT,capture_output=True,text=True)
check(result.returncode==0,'ordinary pilot generation succeeds')
check(fingerprints()==before,'previews and rejected promotions preserve all shipping PNGs and masters')
(work/'result.json').write_text(json.dumps({'status':'passed','checks':checks,'sets':['original','svg','rendered','vanilla'],
    'shipping_and_sources_unchanged':True},indent=2)+'\n',encoding='utf-8')
print(f'PASS {checks} named-set export checks; all shipping and durable source files unchanged')
