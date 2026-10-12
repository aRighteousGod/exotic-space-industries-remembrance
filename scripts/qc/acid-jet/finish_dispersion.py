"""Aggregate final native evidence, performance contracts and Graphics 6 ownership."""
import argparse,hashlib,json
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--root',type=Path,required=True)
p.add_argument('--combat-root',type=Path);args=p.parse_args()
root=args.root;combat_root=args.combat_root or root/'combat'
visual=json.loads((root/'dispersion-visual-qa.json').read_text())
profiles=[]
pack='__exotic-space-industries-remembrance-graphics-6__/'
for name,factor in [('original',1),('2x',2),('4x',4),('8x',8),('16x',16)]:
    combat=json.loads((combat_root/'qc'/name/'acceptance.json').read_text())
    captures=json.loads((root/'qc'/f'{name}-visual'/'acceptance.json').read_text())
    data=json.loads((combat_root/'qc'/name/'script-output/final-data.json').read_text())
    assert combat['all_pass'] and captures['all_pass'] and combat['pressure_baseline']
    assert not combat['native_refresh_candidate'] and not captures['native_refresh_candidate']
    jet=data['resolved'];attack=data['turret']['attack_parameters'];refresh=.5 if factor>=8 else 1
    assert jet['particle_spawn_interval']==2*factor and jet['particle_spawn_timeout']==max(16,6*factor)
    assert attack['cooldown']==4*factor*refresh and attack['fluid_consumption']==factor*refresh
    assert jet['smoke_sources'][0]['frequency']==.8/factor
    assert jet['action'][0]['radius']==3 and 'initial_action' not in jet
    assert data['sticker']['duration_in_ticks']==900 and data['sticker']['target_movement_modifier']==.6
    assert data['sticker']['animation']['frame_count']==50 and data['sticker']['animation']['blend_mode']=='normal'
    for part in ('source','resolved','alias'):
        for key in ('spine_animation','particle','shadow'):assert data[part][key]['filename'].startswith(pack)
    assert data['turret']['icon'].startswith(pack)
    assert data['turret']['folded_animation']['north']['layers'][0]['filename'].startswith(pack)
    assert data['flecks']['duration']==12 and not data['flecks'].get('show_when_smoke_off',False)
    profiles.append({'profile':name,'stationary_pairs':combat['combat_pairs'],
        'native_captures':captures['native_captures'],'particle_interval':jet['particle_spawn_interval'],
        'particle_timeout':jet['particle_spawn_timeout'],'cooldown':attack['cooldown'],
        'fluid_per_refresh':attack['fluid_consumption'],'cosmetic_frequency':jet['smoke_sources'][0]['frequency'],
        'max_damage_ratio_error':combat['max_damage_ratio_error'],'max_fluid_ratio_error':combat['max_fluid_ratio_error'],
        'flight_ticks':captures['flight_ticks']})
latest=json.loads((root/'final-inspection/qc/original-probes/script-output/final-data.json').read_text())
assert latest['item']['icon']==pack+'graphics/items/acid-turret.png'
assert latest['item']['icon_size']==128 and latest['item']['icon_mipmaps']==3
tech=latest['technology'];icons=tech.get('icons') or [{'icon':tech.get('icon')}]
assert any(i['icon']==pack+'graphics/techs/acid-turret.png' for i in icons)
relocation=json.loads((root/'graphics-6-relocation.json').read_text(encoding='utf-8-sig'))
assert len(relocation)==15
for row in relocation:
    assert not Path(row['source']).exists()
    assert hashlib.sha256(Path(row['destination']).read_bytes()).hexdigest().upper()==row['sha256']
assert len(visual['machine_hashes'])==7 and all(r['unchanged'] for r in visual['machine_hashes'])
liquid=[r for r in visual['matrix_widths'] if r['profile']=='original' and r['key'].endswith('/38/0/new') and not r['night']]
assert len(liquid)==4
envelopes=[r['bins'][2]['total_envelope_pixels'] for r in liquid]
assert all(24<=v<=32 for v in envelopes),envelopes
core=[r['bins'][0]['occupied_pixels_per_column'] for r in liquid]
assert all(1.5<=v<=3.5 for v in core),core
visible=[r['error_native_pixels'] for r in visual['outlet_measurements'] if r['visible_bore']]
# Manual bore centres are marked to source pixels (half a native pixel).
# Report the continuous fit error rather than claiming subpixel precision.
assert max(visible)<=1.5,visible
result={'all_pass':True,'engine_version':'2.0.77','profiles':profiles,
    'stationary_pairs':sum(r['stationary_pairs'] for r in profiles),
    'native_captures':sum(r['native_captures'] for r in profiles),
    'max_damage_ratio_error':max(r['max_damage_ratio_error'] for r in profiles),
    'max_fluid_ratio_error':max(r['max_fluid_ratio_error'] for r in profiles),
    'late_envelope_native_pixels':envelopes,'near_core_occupied_pixels_per_column':core,
    'max_visible_outlet_error_native_pixels':max(visible),
    'outlet_marking_uncertainty_native_pixels':.5,
    'max_inferred_cap_error_native_pixels':max(r['error_native_pixels'] for r in visual['outlet_measurements'] if not r['visible_bore']),
    'graphics_6_files':len(relocation),'seven_machine_sprites_unchanged':True,
    'high_profile_clipping_accepted':True,'new_damaging_particles':0,'production_runtime_handlers_added':0}
(root/'validation-summary.json').write_text(json.dumps(result,indent=2))
print(json.dumps({k:v for k,v in result.items() if k!='profiles'}))
