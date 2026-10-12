"""Analyze known-color native delta blends; never promote or rewrite captures."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil

import numpy as np
from PIL import Image


def analyze(run,output):
    output.mkdir(parents=True,exist_ok=True)
    helper=run/'mods/zzz-esir-minigun-color'
    inputs=json.loads((helper/'color-input-manifest.json').read_text())
    report=json.loads((run/'script-output/minigun-native-color-report.json').read_text())
    match=re.search(r'\[DXT: ([^\]]+)\]',(run/'graphics.log').read_text(errors='replace'))
    compression=match.group(1) if match else None
    failures=[];cases=[];captures={(x['case_id'],x['variant']):x for x in report['captures']}
    if compression!='none':failures.append('Mathematical probe requires observed DXT none')
    for case in inputs['cases']:
        pair=[];hashes=[]
        for variant in ('candidate','reference'):
            row=captures.get((case['id'],variant))
            if row is None:break
            kind='reference' if variant=='reference' or case.get('control') else case['variant']
            if case.get('identity'):kind='identity-'+kind
            expected_name='mg-delta-'+case['surface']+'-'+kind
            if row.get('prototype_name')!=expected_name:
                failures.append('Wrong native prototype captured '+case['id']+'/'+variant);break
            position=row.get('position',{})
            if any(abs(position.get(axis,1e9)-case['offset']/32)>1e-9 for axis in ('x','y')):
                failures.append('Native position mismatch '+case['id']+'/'+variant);break
            path=run/'script-output'/row['path']
            if not path.is_file():break
            pair.append(np.array(Image.open(path).convert('RGB')).astype(np.int16))
            hashes.append(hashlib.sha256(path.read_bytes()).hexdigest())
        if len(pair)!=2:
            failures.append('Missing capture '+case['id']);continue
        assert pair[0].shape==pair[1].shape
        delta=np.abs(pair[0]-pair[1]);error=delta.max(axis=2)
        h,w=error.shape;yy,xx=np.indices((h,w))
        sx=(xx+.5-w/2)/case['zoom']+96-case['offset']
        sy=(yy+.5-h/2)/case['zoom']+64-case['offset']
        background=(sx<-3)|(sx>195)|(sy<-3)|(sy>131)
        front=(sx>=26)&(sx<=166)&(sy>=36)&(sy<=40)
        fx=(sx>=26)&(sx<=166)&(sy>=85)&(sy<=87)
        metrics={'maximum_rgb_error':int(delta.max()),'rms_rgb_error':float(np.sqrt(np.mean(delta.astype(np.float64)**2))),
                 'background_error':int(error[background].max()),'foreground_error':int(error[front].max()),
                 'fx_error':int(error[fx].max()),'changed_pixels':int(np.count_nonzero(error))}
        passed=metrics['maximum_rgb_error']<=2 and metrics['rms_rgb_error']<=.25
        passed=passed and metrics['background_error']==0 and metrics['foreground_error']==0 and metrics['fx_error']==0
        if case.get('control') or case.get('identity'):passed=metrics['maximum_rgb_error']==0
        def sample(source_x,source_y):
            px=round(w/2+(source_x-96+case['offset'])*case['zoom'])
            py=round(h/2+(source_y-64+case['offset'])*case['zoom'])
            return np.median(pair[1][py-1:py+2,px-1:px+2].reshape(-1,3),axis=0)
        warm,blue=sample(32,28),sample(152,28)
        confidence=bool(warm[0]>warm[2]+1 and blue[2]>blue[0]+1)
        passed=passed and confidence
        metrics['reference_color_confidence']=confidence
        metrics['reference_warm_rgb']=warm.tolist();metrics['reference_blue_rgb']=blue.tolist()
        if not passed:failures.append('Native coefficient/color/depth/light mismatch: '+case['id'])
        if np.any(error):
            heat=np.zeros((h,w,3),np.uint8);heat[:,:,0]=np.minimum(error*8,255)
            destination=output/'differences'/(case['id']+'.png');destination.parent.mkdir(exist_ok=True)
            Image.fromarray(heat).save(destination,optimize=True)
        cases.append({**case,**metrics,'passed':bool(passed),'sha256':hashes})
    complete=len(cases)==len(inputs['cases']) and len(captures)==2*len(inputs['cases'])
    if not complete:failures.append('Incomplete native matrix')
    controls=all(x['passed'] for x in cases if x.get('control'))
    variants={}
    for name in ('ordinary','glow'):
        rows=[x for x in cases if x['variant']==name and not x.get('control')]
        variants[name]={'passed':complete and controls and compression=='none' and bool(rows) and all(x['passed'] for x in rows),
                        'cases':len(rows),'maximum_rgb_error':max((x['maximum_rgb_error'] for x in rows),default=None),
                        'maximum_background_error':max((x['background_error'] for x in rows),default=None),
                        'maximum_foreground_error':max((x['foreground_error'] for x in rows),default=None),
                        'maximum_fx_error':max((x['fx_error'] for x in rows),default=None)}
    # Alternative variants are hypotheses, not mandatory simultaneous behavior.
    # A passing variant permits only a further real-art probe, never promotion.
    passed=any(x['passed'] for x in variants.values())
    summary={'schema':'esir.minigun.native-delta-blend-evidence.v1','matrix':'delta-blend-proof',
             'automated_checks_passed':passed,'texture_compression_observed':compression,'controls_passed':controls,
             'complete':complete,'variants':variants,'failures':failures,'cases':cases,
             'production_approved':False,'real_art_tested':False,'source_over_contract_changed':True,
             'contract_difference':'Color correction uses multiplicative-with-alpha and additive native surfaces; it is not the accepted normal premultiplied source-over-only pipeline.',
             'proof_limit':'Known-color matrix only; a passing hypothesis still needs actual art, all supported zooms/directions/states and normal compression validation.',
             'input_manifest_sha256':hashlib.sha256((helper/'color-input-manifest.json').read_bytes()).hexdigest(),
             'analyzer_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest()}
    (output/'summary.json').write_text(json.dumps(summary,indent=2)+'\n')
    shutil.copytree(run/'script-output/minigun-native-delta',output/'screenshots',dirs_exist_ok=True)
    shutil.copyfile(helper/'color-input-manifest.json',output/'color-input-manifest.json')
    shutil.copyfile(run/'script-output/minigun-native-color-report.json',output/'native-report.json')
    return summary


if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--run',type=Path,required=True);parser.add_argument('--output',type=Path,required=True)
    args=parser.parse_args();result=analyze(args.run,args.output)
    print(json.dumps({k:result[k] for k in ('automated_checks_passed','controls_passed','variants','production_approved')}))
    raise SystemExit(0 if result['automated_checks_passed'] else 2)
