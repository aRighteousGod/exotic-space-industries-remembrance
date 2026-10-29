"""Exact gameplay/cardinal parity, eight-way field coverage and original PNG hashes."""
import argparse
import copy
import hashlib
import json
import math
from pathlib import Path

parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--baseline',type=Path,required=True)
parser.add_argument('--current',type=Path,required=True)
parser.add_argument('--hashes',type=Path,required=True)
parser.add_argument('--output',type=Path,required=True)
args=parser.parse_args()
old=json.loads(args.baseline.read_text(encoding='utf-8-sig'))
new=json.loads(args.current.read_text(encoding='utf-8-sig'))
assert old['profile']==new['profile']
assert old['effects']==new['effects'],'Acid effects/payload/profile drift'
assert old['stream']==new['stream'],'Resolved acid stream drift'
t=copy.deepcopy(new['turret']);baseline=old['turret']
assert t['flags']==baseline['flags']+['building-direction-8-way']
t['flags'].remove('building-direction-8-way')
for index,(direction,position) in enumerate([(12,[-1,0]),(8,[0,1])]):
    port=t['fluid_box']['pipe_connections'][index]
    assert port.pop('alt_direction')==direction
    assert port.pop('alt_position')==position
assert len(t['circuit_connector'])==8
t['circuit_connector']=t['circuit_connector'][::2]
diagonals=('north_east','south_east','south_west','north_west')
for state in ('folded','preparing','prepared','attacking','ending_attack','folding'):
    for index,facing in enumerate(diagonals):
        layers=t[state+'_animation'].pop(facing)['layers']
        theta=math.radians(45+90*index)
        expected=[.0014700282*math.cos(theta)+(.6423900127-.18)*math.sin(theta),
                  .0014700282*math.sin(theta)-(.6423900127-.18)*math.cos(theta)]
        # Factorio's deterministic trigonometry differs from host libm below 1e-8.
        assert all(abs(a-b)<1e-7 for a,b in zip(layers[0]['shift'],expected))
        assert layers[0]['direction_count']==256 and layers[0]['apply_projection']
        assert layers[0]['filename']==baseline[state+'_animation']['north']['layers'][0]['filename']
for visual in t['graphics_set']['base_visualisation']:
    for facing in diagonals:
        animation=visual['animation'].pop(facing)
        layers=animation.get('layers',[animation])
        assert all('acidthrower-base-diagonal' in layer['filename'] for layer in layers[-3:])
        if len(layers)==5:
            assert layers[0]['filename']=='__base__/graphics/entity/pipe/pipe-straight-horizontal.png'
            assert layers[1]['filename']=='__base__/graphics/entity/pipe/pipe-straight-vertical.png'
        else:assert len(layers) in (1,3)
for index,facing in enumerate(diagonals):
    theta=math.radians(45+90*index)
    expected=[.0014700282*math.cos(theta)+(.6423900127-.18)*math.sin(theta),
              .0014700282*math.sin(theta)-(.6423900127-.18)*math.cos(theta)-.886152416900*math.sqrt(.5)]
    assert all(abs(a-b)<1e-7 for a,b in zip(t['attack_parameters']['gun_center_shift'].pop(facing),expected))
if t!=baseline:
    def differences(a,b,p=''):
        if type(a)!=type(b):return [p]
        if isinstance(a,dict):
            return sum((differences(a.get(k),b.get(k),p+'/'+k) for k in a.keys()|b.keys()),[])
        if isinstance(a,list):
            if len(a)!=len(b):return [p+'/length']
            return sum((differences(x,y,p+'/'+str(i)) for i,(x,y) in enumerate(zip(a,b))),[])
        return [] if a==b else [p]
    raise AssertionError(differences(t,baseline))
hashes=json.loads(args.hashes.read_text(encoding='utf-8-sig'))
assert len(hashes)==7
for row in hashes:assert hashlib.sha256(Path(row['Path']).read_bytes()).hexdigest().upper()==row['Hash']
report=dict(passed=True,profile=new['profile'],gameplay_exact=True,cardinals_exact=True,
            original_machine_sheets_unchanged=7,effect_prototypes=len(new['effects']),engine='2.1.23')
args.output.write_text(json.dumps(report,indent=2));print(json.dumps(report))
