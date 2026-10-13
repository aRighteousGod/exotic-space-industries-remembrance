"""Check scoped final prototype data, shot rates and the native casing trajectory."""
from pathlib import Path
import argparse, hashlib, json, math
import numpy as np
from PIL import Image

parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--case',default='standalone-off-001')
parser.add_argument('--dossier',type=Path,default=Path.cwd()/'output/minigun-implementation/casing-ejection-001')
args=parser.parse_args()
root=args.dossier.resolve()
stage=json.loads((root/f'final-{args.case}-stage.json').read_text(encoding='utf-8-sig'))
run=Path(stage['run'])
report=json.loads((root/f'final-{args.case}-report.json').read_text(encoding='utf-8-sig'))
audit=report['audit']
metadata=json.loads((root.parent/'finalized-minigun/graphics-data.json').read_text())
def equivalent(a,b):
    if isinstance(a,(int,float)) and isinstance(b,(int,float)):
        return abs(a-b)<=1e-12
    if isinstance(a,list) and isinstance(b,list):
        return len(a)==len(b) and all(equivalent(x,y) for x,y in zip(a,b))
    return a==b
# Factorio's JSON writer emits rounded decimals; source metadata stays untouched.
assert equivalent(audit['launch'],metadata['projectile_creation_parameters'])
for field,spec in metadata['native_launch_contract'].items():
    assert audit['launch_fields'].get(field)==(spec.get('value') if spec['present'] else None)
assert audit['vanilla_particle']==audit['private_particle_normalized']
assert audit['particle']['life_time']==240 and audit['particle']['fade_away_duration']==60
assert audit['particle']['movement_modifier_when_on_ground']==.6
assert audit['range']==32 and audit['min_range']==4 and equivalent(audit['rotation_speed'],.01)
assert audit['attacking_speed']==20
assert audit['damage_modifier']==1
expected=54 if report['config']['standalone'] else 60
assert all(row['steady_shots']==expected for row in report['rows']),report['rows']
trajectory=[]
for capture in report['captures']:
    if not capture['label'].startswith('single-'):continue
    array=np.asarray(Image.open(run/'script-output'/capture['path']).convert('RGB'))
    r,g,b=[array[:,:,i].astype(float) for i in range(3)]
    sy,sx=np.where((r>100)&(b>100)&(g<.4*np.minimum(r,b)))
    if not len(sx):continue
    density=32*capture['zoom'];width,height=capture['resolution']
    offset=[(float(sx.mean())+.5-width/2)/density,(float(sy.mean())+.5-height/2)/density]
    trajectory.append({'elapsed':int(capture['label'].split('-')[-1]),'offset':offset})
assert len(trajectory)>20,trajectory
steps=[]
for a,b in zip(trajectory,trajectory[1:]):
    if b['elapsed']>=30:
        steps.append(math.dist(a['offset'],b['offset']))
ground_displacement=trajectory[-1]['offset'][0]-trajectory[0]['offset'][0]
result={'case':args.case,'passed':True,'launch_map_identical':True,'launch_fields_identical':True,
        'private_particle_only_requested_changes':True,'steady_shots_per_60_ticks':expected,
        'trajectory':trajectory,'late_step_distances':steps,
        'lateral_travel_tiles':ground_displacement,'run':str(run),
        'captures':[{**c,'sha256':hashlib.sha256((run/'script-output'/c['path']).read_bytes()).hexdigest()} for c in report['captures']]}
(root/f'final-{args.case}-validation.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps({k:v for k,v in result.items() if k not in ('trajectory','captures')},indent=2))
