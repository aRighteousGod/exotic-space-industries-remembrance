"""Bind retained native receipts to the unchanged source art and final diagonal sheets."""
import argparse
import hashlib
import json
from pathlib import Path

p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--root',type=Path,required=True)
p.add_argument('--visual-run',type=Path)
p.add_argument('--baseline',type=Path,required=True)
a=p.parse_args();r=a.root;v=a.visual_run or r/'visual'
repo=Path(__file__).resolve().parents[3]
def read(path):return json.loads(path.read_text(encoding='utf-8-sig'))
def digest(path):return hashlib.file_digest(path.open('rb'),'sha256').hexdigest()
visual=read(v/'visual.receipt.json');assert visual['passed'] and visual['engine_version']=='2.1.23'
reload=read(v/'acid-eight-reload.receipt.json');assert reload['passed']
assert len(visual['flow'])==32 and len(visual['muzzle'])==72
assert all(c['launches']>0 and c['event_damage']>0 and c['damage']>0 and c['consumed']>0 for c in visual['muzzle'])
assert len(visual['captures'])==len(visual['images'])
for row in visual['images']:assert digest(Path(row['path']))==row['sha256']
player=read(r/'player/player.receipt.json');assert player['passed'] and player['entities']==144
player_reload=r/'player/acid-eight-player-reload.receipt.json'
if not player_reload.exists():player_reload=r/'player/reload.receipt.json'
assert read(player_reload)['passed']
legacy=read(r/'legacy/script-output/acid-eight-legacy-load.json');assert legacy['passed'] and len(legacy['entities'])==4
assert read(r/'legacy/legacy-seed.checkpoint.json')['passed']
layouts=read(r/'layouts/layouts.receipt.json');assert layouts['passed'] and len(layouts['records'])==8
profiles={name:read(r/('parity-'+name+'.json')) for name in ('original','2x','4x','8x','16x')}
assert all(x['passed'] and x['gameplay_exact'] and x['cardinals_exact'] for x in profiles.values())
old=read(a.baseline/'baseline/machine-hashes.json');assert len(old)==7
for row in old:assert digest(Path(row['Path'])).upper()==row['Hash']
sprites=repo/'exotic-space-industries-remembrance-graphics-6/graphics/entities/acidthrower-turret'
render=read(r/'sprite-qa.json');assert render['passed']
for row in render['sheets']:assert digest(sprites/row['name'])==row['sha256']
source=digest(repo/'models/acidthrower.glb')
assert source=='257f4beadb591807487fbfd1b70ff7f1b02c3e38c284068cbbee38c6ce3e4c17'
owned=[repo/'exotic-space-industries-remembrance/prototypes/steam-age/acid-turret'/name for name in ('acid.lua','graphics.lua','pressure-jet.lua')]
owned+=list((repo/'scripts/qc/acid-eight-way').glob('*.*'))
summary=dict(passed=True,engine='2.1.23',mod_version='1.4.1',native_flow_masks=32,native_combat_cases=72,
    max_source_error_native_pixels=max(c['max_error'] for c in visual['muzzle'])*32,
    min_fluid_consumed=min(c['consumed'] for c in visual['muzzle']),cursor_placements=8,blueprint_transforms=16,
    robot_builds=8,reloaded_wired_bodies=144,legacy_cardinal_bodies=4,adjacent_layouts=8,
    graphics_quality=visual['graphics_quality'],visual_captures=len(visual['images']),visual_run=str(v),
    profiles=list(profiles),original_machine_sheets_unchanged=7,new_diagonal_sheets=render['sheets'],source_model_sha256=source,
    source_hashes={str(path.relative_to(repo)):digest(path) for path in owned},
    boundaries=['Factoriopedia scene content, not full GUI automation','Audio fields preserved; audio playback disabled',
                'Accepted short-ribbon phase gaps retained','Broad preflight has an unrelated pre-existing encoding finding'])
(r/'acceptance-summary.json').write_text(json.dumps(summary,indent=2));print(json.dumps({k:v for k,v in summary.items() if k not in ('source_hashes','new_diagonal_sheets')}))
