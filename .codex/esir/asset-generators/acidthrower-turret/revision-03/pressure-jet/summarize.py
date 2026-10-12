"""Aggregate scoped native acceptance without hiding candidate-only runs."""
import argparse,hashlib,json
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--root',type=Path,required=True);args=p.parse_args();root=args.root
profiles=[]
for profile in ('original','2x','4x','8x','16x'):
    combat=json.loads((root/'qc'/profile/'acceptance.json').read_text())
    visual=json.loads((root/'qc'/f'{profile}-visual'/'acceptance.json').read_text())
    assert combat['all_pass'] and visual['all_pass']
    assert not combat.get('native_refresh_candidate') and not visual.get('native_refresh_candidate')
    assert visual['matrix_pairs']==36 and visual['native_captures']==264
    final=json.loads((root/'qc'/f'{profile}-visual'/'script-output/final-data.json').read_text())
    attack,stream=final['turret']['attack_parameters'],final['resolved']
    profiles.append({'profile':profile,'combat_pairs':combat['combat_pairs'],'captures':visual['native_captures'],
        'max_damage_ratio_error':combat['max_damage_ratio_error'],'max_fluid_ratio_error':combat['max_fluid_ratio_error'],
        'interval':stream['particle_spawn_interval'],'timeout':stream['particle_spawn_timeout'],
        'cooldown':attack['cooldown'],'fluid_per_refresh':attack['fluid_consumption'],
        'flight_ticks':visual['flight_ticks'],
        'legacy_minimum_correction':[r for r in combat['combat_ratios'] if r.get('restored_legacy_minimum_cadence')]})
hashes=json.loads((root/'machine-hashes-after.json').read_text(encoding='utf-8-sig'))
assert len(hashes)==7
before=json.loads((root/'machine-hashes-before.json').read_text(encoding='utf-8-sig'))
assert all(hashlib.sha256(Path(r['Path']).read_bytes()).hexdigest().upper()==r['Hash'] for r in before)
machine=json.loads((root/'machine-check/native-visual-qa.json').read_text())
assert machine['all_pass'] and machine['active_only_glow_verified']
result={'all_pass':True,'profiles':profiles,'stationary_pairs':sum(r['combat_pairs'] for r in profiles),
    'stream_captures':sum(r['captures'] for r in profiles),'machine_captures':machine['native_capture_count'],
    'machine_sprite_hashes_unchanged':7,'muzzle_error_pixels':machine['max_muzzle_error_native_pixels'],
    'fine_rotation_samples':machine['distinct_fine_housing_crops'],
    'liquid':json.loads((root/'native-liquid-metrics.json').read_text())}
(root/'validation-summary.json').write_text(json.dumps(result,indent=2))
print(json.dumps({k:v for k,v in result.items() if k!='profiles'}))
