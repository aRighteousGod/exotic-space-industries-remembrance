"""Check native before/after pressure-jet combat and flight evidence."""
import argparse,json
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('run',type=Path)
p.add_argument('--combat-only',action='store_true',help='Check sustained parity from a pre-edge-calibration fixture; does not certify visual coverage.')
args=p.parse_args()
root=args.run;report=json.loads((root/'script-output/jet-report.json').read_text())
data=json.loads((root/'script-output/final-data.json').read_text())
assert len(report['probes'])==(86 if report.get('fixture_version',0)>=6 else 80)
matrix=[r for r in report['probes'] if 'facing' in r]
assert len(matrix)==72
missing=[r['key'] for r in report['probes'] if not r.get('source_count') or not r.get('land_count')]
if not args.combat_only:assert not missing,('Missing source/landing',missing)
assert {(r['facing'],r['distance'],r['angle'],r['variant']) for r in matrix}=={
    (f,d,a,v) for f in range(1,5) for d in (9,24,38) for a in (-48,0,48) for v in ('old','new')}
for name in ('source','resolved','alias'):
    jet=data[name]
    assert jet['particle_horizontal_speed']==.85 and jet['particle_vertical_acceleration']==.00025
    assert jet['particle_buffer_size']==120 and jet['action'][0]['radius']==3
    assert jet['progress_to_create_smoke']==.12
factor=1 if report['profile']=='original' else int(report['profile'][:-1])
assert data['source']['smoke_sources'][0]['frequency']==.59
for name in ('resolved','alias'):
    assert data[name]['smoke_sources'][0]['frequency']==.59/factor
flecks=data['flecks']
assert (flecks['duration'],flecks['fade_in_duration'],flecks['spread_duration'])==(12,8,12)
assert (flecks['start_scale'],flecks['end_scale'])==(.05,1)
# Compare expected source work over normalized flight, not just frequency:
# an earlier start otherwise creates more cosmetic smoke at the same cadence.
assert .59*(1-.12)<=.8*(1-.35)
assert data['turret']['attack_parameters']['lead_target_for_projectile_speed']==.85
assert sum(len(names) for names in data['retired'].values())==10
assert data['poison']['animation']['filename'].endswith('/effects/stickers/spark.png')
pairs={}
for row in report['combat']:pairs.setdefault(row['key'],{})[row['variant']]=row
expected_pairs=144 if report['profile'] in ('8x','16x') and report.get('fixture_version',0)>=4 else 48
assert len(pairs)==(0 if report['captures'] or report.get('probe_only') else expected_pairs)
ratios=[]
for key,pair in pairs.items():
    old,new=pair['old'],pair['new']
    assert min(old['damage'],new['damage'],old['fluid'],new['fluid'])>0,key
    damage=new['damage']/old['damage'];fluid=new['fluid']/old['fluid']
    expected_damage_ratio=1
    restored_minimum=(not report.get('pressure_baseline') and report['profile']=='16x' and '/9.02/' in key and
        (report.get('native_refresh_candidate') or data['turret']['attack_parameters']['cooldown']==32))
    if restored_minimum and key.endswith('/direct'):expected_damage_ratio=2
    if restored_minimum and key.endswith('/combined'):
        direct=pairs[key.removesuffix('combined')+'direct']['old']['damage']
        sticker=pairs[key.removesuffix('combined')+'sticker']['old']['damage']
        expected_damage_ratio=(2*direct+sticker)/(direct+sticker)
    tolerance=.05 if key.endswith('combined') else .01
    assert abs(damage/expected_damage_ratio-1)<=tolerance,(key,'damage',damage,expected_damage_ratio)
    assert abs(fluid-1)<=.01,(key,'fluid',fluid)
    ratios.append({'key':key,'damage_ratio':damage,'expected_damage_ratio':expected_damage_ratio,
        'restored_legacy_minimum_cadence':restored_minimum,'fluid_ratio':fluid})
flights={}
for row in matrix:
    key=f"{row['facing']}/{row['distance']}/{row['angle']}"
    if 'flight_ticks' in row:flights.setdefault(key,{})[row['variant']]=row['flight_ticks']
if report.get('pressure_baseline'):
    assert all(abs(v['new']-v['old'])<=1 for v in flights.values()),flights
    anim=data['sticker']['animation']
    assert anim['filename']=='__base__/graphics/entity/acid-sticker/acid-sticker.png'
    assert (anim['width'],anim['height'],anim['line_length'],anim['frame_count'])==(30,34,5,50)
    assert not anim.get('draw_as_glow') and not anim.get('draw_as_light')
else:
    assert all(v['new']<v['old'] for v in flights.values()),flights
for row in report['probes']:
    if row.get('kind')=='radius':
        assert row['radial'][0]['damage']>0 and row['radial'][1]['damage']==0,row
    if row.get('kind')=='retarget':assert row.get('damage_after_switch',0)>0,row
    if row.get('stopped'):
        assert row['land_count']==row['lands_at_900'],row
        if pairs:assert row['stickers_at_end']==0,row
    if row.get('kind','').startswith('sticker-'):
        samples={s['tick']:s['count'] for s in row['sticker_samples']}
        assert samples[120]>0 and samples[560]>0 and samples[650]>0,row
        assert samples[1600]==0 and row['stickers_at_end']==0,row
assert report['ground_fires']==0
if report['captures']:assert len(report['captures'])==(352 if report.get('fixture_version',0)>=6 else 264)
summary={'all_pass':True,'scope':'combat-only' if args.combat_only else 'full-fixture','profile':report['profile'],'combat_pairs':len(pairs),'matrix_pairs':len(flights),
    'fixture_version':report.get('fixture_version',1),'visual':report.get('visual',bool(report['captures'])),
    'probe_only':report.get('probe_only',False),'native_refresh_candidate':report.get('native_refresh_candidate',False),
    'animation_lifetime_candidate':report.get('animation_lifetime_candidate',False),
    'pressure_baseline':report.get('pressure_baseline',False),
    'native_captures':len(report['captures']),'flight_ticks':flights,'combat_ratios':ratios,
    'max_damage_ratio_error':max((abs(r['damage_ratio']/r['expected_damage_ratio']-1) for r in ratios),default=0),
    'max_fluid_ratio_error':max((abs(r['fluid_ratio']-1) for r in ratios),default=0),
    'behavior':[r for r in report['probes'] if 'kind' in r]}
(root/'acceptance.json').write_text(json.dumps(summary,indent=2))
print(json.dumps({k:v for k,v in summary.items() if k not in {'flight_ticks','combat_ratios','behavior'}}))
