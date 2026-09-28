"""Validate staged lance studies without a browser or Factorio installation."""
import ast
import hashlib
import importlib.util
import json
import math
from pathlib import Path
import sys

import numpy as np
from PIL import Image

sys.dont_write_bytecode=True
source=Path(__file__).with_name('generate.py')
ast.parse(source.read_text('utf-8'))
spec=importlib.util.spec_from_file_location('lance_art_studies',source)
module=importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
root=Path('output/meshy/lance-prismatic-liturgy')
manifest=json.loads((root/'manifest.json').read_text('utf-8'))
report={'status':'passed','scope':'staged assets only; no browser or Factorio acceptance claim','sheets':{},'loop_checks':{}}
for name,contract in manifest.items():
    w,h,n,cols=[contract[k] for k in ['width','height','frames','columns']]
    hashes=[]
    for layer in ['', '-glow']:
        image=Image.open(root/'factorio-export'/f'{name}{layer}.png').convert('RGBA')
        assert image.size==(w*cols,h*math.ceil(n/cols)),name
        clipped=[]
        for i in range(n):
            frame=image.crop(((i%cols)*w,(i//cols)*h,(i%cols+1)*w,(i//cols+1)*h))
            a=np.array(frame)[...,3]
            edge=max(a[0].max(),a[-1].max(),a[:,0].max(),a[:,-1].max())
            if edge>3:clipped.append(i)
            if not layer:hashes.append(hashlib.sha256(frame.tobytes()).hexdigest())
        assert not clipped,(name,layer,'clipped frames',clipped)
    assert len(set(hashes))==n,(name,'repeated frames')
    report['sheets'][name]={'frames':n,'distinct_frames':len(set(hashes)),'edge_clipping':False}
for name,render in [('axial',lambda p:module.beam('axial',p)),('testament-beam',lambda p:module.beam('testament',p)),
                    *[(f'wound-{i}',lambda p,i=i:module.wound(i,p)) for i in [1,2,3]]]:
    a=np.asarray(render(0),dtype=np.int16);b=np.asarray(render(math.tau),dtype=np.int16)
    # Float32 trigonometry/8-bit conversion can differ by one code value.
    difference=np.abs(a-b)
    assert difference.max()<=1,(name,'non-periodic loop',int(difference.max()))
    report['loop_checks'][name]={'endpoint_max_channel_difference':int(difference.max())}
animation=Image.open(root/'motion-study.webp')
assert animation.n_frames==64
report['overview_frames']=animation.n_frames
report['total_animation_frames']=sum(v['frames'] for v in manifest.values())
(root/'qa.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
html=(root/'index.html').read_text('utf-8')
(root/'gallery-script.js').write_text(html.split('<script>',1)[1].split('</script>',1)[0],encoding='utf-8')
print(json.dumps(report,indent=2))
