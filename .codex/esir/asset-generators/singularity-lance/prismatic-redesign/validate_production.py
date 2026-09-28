"""Validate production sheet boundaries, loops, icon layers and shipped hashes."""
import ast
import hashlib
import json
import math
from pathlib import Path
import sys

import numpy as np
from PIL import Image

sys.dont_write_bytecode = True
import production

root = Path('output/meshy/lance-prismatic-liturgy/production')
manifest = json.loads((root/'manifest.json').read_text('utf-8'))
report = {'status':'passed','sequences':{},'loop_checks':{},'shipping_checked':False}
for source in ['production.py','generate.py','validate_production.py']:
    ast.parse(Path(__file__).with_name(source).read_text('utf-8'))
for key, contract in manifest['sequences'].items():
    w,h,n,columns = [contract[field] for field in ['width','height','frames','columns']]
    seen = set()
    for layer in contract['layers']:
        path = root/'factorio-export'/layer['file']
        assert hashlib.sha256(path.read_bytes()).hexdigest() == layer['sha256'],key
        sheet = Image.open(path).convert('RGBA')
        assert sheet.size == (columns*w, math.ceil(n/columns)*h),(key,sheet.size)
        for i in range(n):
            frame = np.asarray(sheet.crop(((i%columns)*w,(i//columns)*h,(i%columns+1)*w,(i//columns+1)*h)))
            alpha = frame[...,3]
            assert max(alpha[0].max(),alpha[-1].max()) <= 3,(key,'vertical clipping',i)
            if contract['tile_x']:
                assert np.array_equal(frame[:,0],frame[:,-1]),(key,'horizontal seam',i)
            else:
                assert max(alpha[:,0].max(),alpha[:,-1].max()) <= 3,(key,'horizontal clipping',i)
            if '-glow' not in path.name:
                seen.add(hashlib.sha256(frame.tobytes()).hexdigest())
    assert len(seen)==n,(key,'repeated frame')
    report['sequences'][key]={'distinct_frames':len(seen),'edge_checks':'passed'}
for kind in ['axial','testament']:
    for part in ['body','head','tail']:
        a=np.asarray(production.beam(kind,part,0),dtype=np.int16)
        b=np.asarray(production.beam(kind,part,math.tau),dtype=np.int16)
        error=int(np.abs(a-b).max());assert error<=1,(kind,part,error)
        report['loop_checks'][kind+'-'+part]=error
        if part != 'body':
            alpha=np.asarray(production.beam(kind,part,0))[...,3].astype(float)
            left=alpha[:,24:72].sum();right=alpha[:,120:168].sum()
            assert (right>left) if part=='head' else (left>right),(kind,part,'native cap direction')
for band in [1,2,3]:
    a=np.asarray(production.wound(band,0),dtype=np.int16)
    b=np.asarray(production.wound(band,math.tau),dtype=np.int16)
    error=int(np.abs(a-b).max());assert error<=1,(band,error)
    report['loop_checks']['wound-'+str(band)]=error
for name in manifest['icons']:
    body=Image.open(root/'factorio-export'/f'{name}-mineral.png').convert('RGBA')
    effect=Image.open(root/'factorio-export'/f'{name}-phenomenon.png').convert('RGBA')
    body.alpha_composite(effect)
    assert body.tobytes()==Image.open(root/f'{name}.png').convert('RGBA').tobytes(),name
preview=Image.open(root/'production-motion.webp');assert preview.n_frames==64
shipping=Path('exotic-space-industries-remembrance/graphics/singularity-lance-upgrades/prismatic-liturgy')
if '--shipping' in sys.argv:
    for path in (root/'factorio-export').glob('*.png'):
        assert path.read_bytes()==(shipping/path.name).read_bytes(),path.name
    report['shipping_checked']=True
report['rgba_atlas_mib']=manifest['rgba_atlas_bytes']/1024**2
report['total_frames']=sum(v['frames'] for v in manifest['sequences'].values())
(root/'qa.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print(json.dumps(report,indent=2))
