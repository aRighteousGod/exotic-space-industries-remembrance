"""Check calibrated native origin evidence without claiming cosmetic perfection."""
import argparse
import hashlib
import json
import math
from pathlib import Path, PureWindowsPath

p=argparse.ArgumentParser()
p.add_argument('root',type=Path)
p.add_argument('fit',type=Path)
p.add_argument('--baseline',type=Path,default=Path('D:/CodexArtifacts/esir-acidthrower-20261013/origin-calibration'))
args=p.parse_args()
relative=Path('qc/original-visual/script-output')
before=json.loads((args.baseline/relative/'origin-final-data.json').read_text())
after=json.loads((args.root/relative/'origin-final-data.json').read_text())
fit=json.loads(args.fit.read_text())
report=json.loads((args.root/relative/'origin-probe.json').read_text())
assert after['profile']=='original'
for key in ['source','alias','stream']:
    previous=before[key].copy();current=after[key].copy()
    previous.pop('spine_animation');current.pop('spine_animation')
    assert previous==current, 'Unexpected stream payload or cadence change: '+key
    assert after[key]['spine_animation']==after['source']['spine_animation']
old_turret=before['turret'];new_turret=json.loads(json.dumps(after['turret']))
attack=new_turret['attack_parameters']
assert abs(attack['gun_barrel_length']-fit['barrel_length_tiles'])<1e-10
for key in ['gun_barrel_length','gun_center_shift']:
    attack[key]=old_turret['attack_parameters'][key]
assert new_turret==old_turret, 'Unexpected machine graphics or attack change'
hashes=json.loads(Path('D:/CodexArtifacts/esir-acidthrower-20261012/dispersion-03-soft/machine-hashes-before.json').read_bytes())
shipping=Path('exotic-space-industries-remembrance-graphics-6/graphics/entities/acidthrower-turret')
machine={}
for row in hashes:
    name=PureWindowsPath(row['Path']).name
    value=hashlib.sha256((shipping/name).read_bytes()).hexdigest()
    assert value==row['Hash'].lower(),name+' changed'
    machine[name]=value
assert len(machine)==7
graphics6='__exotic-space-industries-remembrance-graphics-6__/'
asset_refs=set()
def inspect_assets(value):
    if isinstance(value,dict):
        for key,child in value.items():
            if key in ['filename','icon'] and isinstance(child,str) and 'acidthrower' in child:
                assert child.startswith(graphics6), 'Acidthrower asset outside Graphics 6: '+child
                path=Path('exotic-space-industries-remembrance-graphics-6')/child[len(graphics6):]
                assert path.is_file(), 'Missing shipping asset: '+str(path)
                asset_refs.add(child)
            else:inspect_assets(child)
    elif isinstance(value,list):
        for child in value:inspect_assets(child)
inspect_assets(after)
assert after['stream']['spine_animation']['width']==32
assert len(after['stream']['spine_animation']['stripes'])==16
for category in ['items','techs']:
    assert Path('exotic-space-industries-remembrance-graphics-6/graphics',category,'acid-turret.png').is_file()
cases={r['key']:r for r in report['cases']}
source_errors=[]
for source in report['sources']:
    case=cases[source['case']]
    if case['prototype']!='ei-acidthrower-turret':continue
    theta=source['orientation']*math.tau
    sin,cos=math.sin(theta),math.cos(theta)
    norm=math.sqrt(sin*sin+2*cos*cos)
    facing=['north','east','south','west'][case['facing']-1]
    centre=after['turret']['attack_parameters']['gun_center_shift'][facing]
    expected=[case['position']['x']+centre[0]+fit['barrel_length_tiles']*sin/norm,
              case['position']['y']+centre[1]-fit['barrel_length_tiles']*cos/norm]
    error=math.hypot(source['position']['x']-expected[0],source['position']['y']-expected[1])*32
    assert error<1, 'Native source differs from fitted source ray'
    source_errors.append({'case':case['key'],'tick':source['tick'],'native_pixel_error':error})
result={'profile':after['profile'],'engine':'2.0.77','captures':len(report['captures']),
        'canonical_captures':sum(cases[r['case']]['prototype']=='ei-acidthrower-turret' for r in report['captures']),
        'user_mark_max_native_pixels':fit['max_native_pixels'],'source_events':source_errors,
        'stream_payload_and_cadence_unchanged':True,'machine_prototypes_unchanged_except_origin':True,
        'machine_hashes':machine,'seven_machine_sprites_unchanged':True,
        'graphics6_asset_references':sorted(asset_refs),'short_ribbon_integrated':True,
        'visual_continuity_acceptance':'Separate image review required; source markers do not certify ribbon attachment.',
        'sustained_damage_fluid_test':'Not rerun for cosmetic cropping; final payload and cadence compared exactly.'}
out=args.root/'review';out.mkdir(exist_ok=True)
(out/'origin-contract-check.json').write_text(json.dumps(result,indent=2))
print(json.dumps({k:v for k,v in result.items() if k not in ['source_events','machine_hashes']},indent=2))
