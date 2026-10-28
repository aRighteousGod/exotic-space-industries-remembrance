"""Validate the 2.1 On/Off steam receipts without claiming a new 2.0 render baseline."""
import argparse
import hashlib
import json
from pathlib import Path
from PIL import Image

parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--on',type=Path,required=True)
parser.add_argument('--off',type=Path,required=True)
parser.add_argument('--output',type=Path,required=True)
args=parser.parse_args()
reports={}
sources=[]
for mode,root in [('on',args.on),('off',args.off)]:
    final_path=root / 'script-output/steam-glow' / (mode+'-final.json')
    visual_path=root / 'client/script-output/steam-glow' / (mode+'-visual.json')
    final=json.loads(final_path.read_text(encoding='utf-8'))
    visual=json.loads(visual_path.read_text(encoding='utf-8'))
    assert visual['passed'] and visual['visual'] and visual['engine']=='2.1.23' and len(visual['rows'])==20
    assert final['pyric']==(mode=='on')
    for name,entity in final['entities'].items():
        assert entity['energy_source']['light_flicker']=={'minimum_intensity':0,'maximum_intensity':0},name
    images={}
    for row in visual['rows']:
        if row['state']=='working':assert row['status']=='working' and row['activity']>0
        else:assert row['status']=='no_input_fluid' and row['activity']==row['energy']==0
        name=row['name']+'-'+row['state']+'.png'
        path=root / 'client/script-output/steam-glow' / mode / name
        assert path.stat().st_size>1000
        pixels=Image.open(path).convert('RGBA')
        assert pixels.size==(768,640)
        images[name]={'file_sha256':hashlib.sha256(path.read_bytes()).hexdigest(),
            'pixel_sha256':hashlib.sha256(pixels.tobytes()).hexdigest()}
    reports[mode]={'final':final,'native_states':visual['rows'],'images':images}
    sources.extend({'path':str(p.absolute()),'sha256':hashlib.sha256(p.read_bytes()).hexdigest()} for p in (final_path,visual_path))
assert reports['on']['final']['entities']==reports['off']['final']['entities']
assert reports['on']['final']['excluded']==reports['off']['final']['excluded']
same=[n for n,p in reports['on']['images'].items() if p['pixel_sha256']==reports['off']['images'][n]['pixel_sha256']]
result={'passed':True,'engine':'2.1.23','native_states':40,'captures':40,'same_pixel_frames':same,
    'final_prototypes_equal_across_pyric':True,'reports':reports,'inputs':sources,
    'limits':['No new 2.0 render baseline','No audio, manual mouse interaction or multiplayer claim',
        'Different source-save seeds can change ore variations and native animation phases; pixel inequality is not itself a lighting failure']}
args.output.write_text(json.dumps(result,indent=2),encoding='utf-8')
print(json.dumps({k:v for k,v in result.items() if k not in ('reports','inputs')}))
