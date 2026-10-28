"""Keep exact noise/tile preservation distinct from native entity placement."""
import argparse
import hashlib
import json
from pathlib import Path

parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--old',type=Path,required=True)
parser.add_argument('--new',type=Path,required=True)
parser.add_argument('--output',type=Path,required=True)
args=parser.parse_args()
old,new=[json.loads(p.read_text(encoding='utf-8')) for p in (args.old,args.new)]
assert old['positions']==new['positions']==200704
rows=[]
for before,after in zip(old['cases'],new['cases']):
    assert (before['seed'],before['mode'])==(after['seed'],after['mode'])
    row={key:before[key] for key in ('seed','mode')}
    row.update(old_spawners=len(before['entities']),new_spawners=len(after['entities']),
        common_spawners=len(set(before['entities']) & set(after['entities'])),
        exact_placement=before['entities']==after['entities'])
    if 'values' in before:
        row['noise_differences']={key:sum(a!=b for a,b in zip(before['values'][key],after['values'][key])) for key in before['values']}
        row['tile_differences']=sum(a!=b for a,b in zip(before['tiles'],after['tiles']))
        assert not any(row['noise_differences'].values()) and row['tile_differences']==0
    rows.append(row)
assert old['prototypes']==new['prototypes']
report={'noise_and_tiles_preserved':True,'compared_spawner_fields_equal':True,'positions_per_seed':old['positions'],
    'cases':rows,'exact_entity_placement':all(r['exact_placement'] for r in rows),'release_acceptance':False,
    'interpretation':'Placement differs despite equal sampled noise, tiles and inspected prototype fields, including flat surfaces without initial units. This isolates an engine-side difference but does not identify its internal cause.',
    'inputs':[{'path':str(p.absolute()),'sha256':hashlib.sha256(p.read_bytes()).hexdigest()} for p in (args.old,args.new)]}
args.output.write_text(json.dumps(report,indent=2),encoding='utf-8')
print(json.dumps({k:v for k,v in report.items() if k not in ('cases','inputs')}))
