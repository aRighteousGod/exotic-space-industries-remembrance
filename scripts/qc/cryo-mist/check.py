"""Compare complete final prototypes and require native state/render evidence."""
import copy
import hashlib
import json
import sys
from pathlib import Path
from PIL import Image, ImageDraw

run = Path(sys.argv[1]).resolve()
out = run / 'script-output/cryo-mist'
baseline = json.loads((out / 'baseline-final.json').read_text())
current = json.loads((out / 'current-final.json').read_text())
checks = []
def require(condition, label):
    assert condition, label
    checks.append(label)

for name, types in baseline.items():
    for kind, old in types.items():
        new = copy.deepcopy(current[name][kind])
        old = copy.deepcopy(old)
        if name == 'ei-cooler' and kind == 'furnace':
            require('ei-nitrogen-gas' in new['factoriopedia_simulation'].pop('update'), 'cooler: preview supply upkeep')
            require('recipes["ei-liquid-nitrogen"].enabled = true' in new['factoriopedia_simulation']['init'], 'cooler: preview recipe enabled')
            new['factoriopedia_simulation']['init'] = new['factoriopedia_simulation']['init'].split('\ndo\n  main_entity.force.recipes')[0]
            old_vis = old['graphics_set']['working_visualisations']
            require(len([v for v in old_vis if 'light' in v]) == 3, 'three original cooler lights')
            old['graphics_set']['working_visualisations'] = [v for v in old_vis if 'light' not in v]
        if kind in {'furnace', 'assembling-machine'} and name in {'ei-cooler', 'ei-copper-beacon-source', 'ei-iron-beacon-source'}:
            graphics = new['graphics_set']
            mist = [v for v in graphics['working_visualisations'] if v.get('name') == 'ei-cryo-mist']
            require(len(mist) == 1, name + ': exactly one mist')
            v = mist[0]; a = v['animation']
            require(v['constant_speed'] and not v['always_draw'] and 'light' not in v, name + ': native working sprite only')
            require(a['frame_count'] == 60 and a['line_length'] == 8 and a['width'] == a['height'] == 256, name + ': atlas')
            require(a['animation_speed'] == 0.15 and a['blend_mode'] == 'additive', name + ': playback')
            require(a['scale'] == (0.8 if name == 'ei-cooler' else 0.5)
                    and a['shift'] == [0, 0.75 if name == 'ei-cooler' else 0.375], name + ': placement')
            require(a['tint'] == {'r': 0.5, 'g': 0.5, 'b': 0.5, 'a': 1}, name + ': half brightness')
            require(a['filename'] == '__exotic-space-industries-remembrance-graphics-6__/graphics/entities/cryo-mist.png', name + ': Graphics 6 asset')
            graphics['working_visualisations'] = [v for v in graphics['working_visualisations'] if v.get('name') != 'ei-cryo-mist']
            if name.endswith('-source'):
                require(new['energy_source']['light_flicker'] == {'minimum_intensity': 0, 'maximum_intensity': 0}, name + ': no native default light')
                old['energy_source'].pop('light_flicker', None)
                new['energy_source'].pop('light_flicker')
                if not graphics['working_visualisations']:
                    del graphics['working_visualisations']
                if not graphics:
                    del new['graphics_set']
        if kind == 'beacon' and name in {'ei-copper-beacon', 'ei-iron-beacon'}:
            sim = new.pop('factoriopedia_simulation')
            prior = old.pop('factoriopedia_simulation')
            require(name + '-source' in sim['init'] and 'ei-liquid-nitrogen' in sim['update'], name + ': preview source and upkeep')
            require(sim['init'].split('\ndo\n  local source =')[0].rstrip() == prior['init'].rstrip(), name + ': original scene retained')
            require({k:v for k,v in sim.items() if k not in {'init','update'}} == {k:v for k,v in prior.items() if k != 'init'}, name + ': scene camera/timing retained')
        require(new == old, name + '/' + kind + ': all remaining fields preserved')

runtime = json.loads((out / 'current-runtime.json').read_text())
visual = json.loads((out / 'visual-runtime.json').read_text())
visual_final = json.loads((out / 'visual-final.json').read_text())
for name in ['ei-cooler', 'ei-copper-beacon', 'ei-iron-beacon', 'ei-copper-beacon-source', 'ei-iron-beacon-source']:
    require(visual_final[name] == current[name], name + ': rendered prototype matches native snapshot')
for label, report in [('runtime', runtime), ('visual', visual)]:
    require(report['passed'] and report['frames'] == 61, label + ': native fixture complete')
    phases = {r['phase'] for r in report['results']}
    require({'steady','preview','input-lost','input-restored','disabled','resumed','power-lost','power-restored','cleanup'} <= phases, label + ': lifecycle coverage')
    require(len([r for r in report['results'] if r['phase'] == 'steady']) == 28, label + ': 28 native placements')
require(runtime['reload_marker'] == 'cold-mist-working-checkpoint', 'checkpoint persisted')
require((out / 'reload.json').exists(), 'actual checkpoint reload receipt')
reload = json.loads((out / 'reload.json').read_text())
require(reload['marker'] == runtime['reload_marker'] and reload['tick'] >= 700, 'actual save/reload retained state')
reload_runtime = json.loads((out / 'reload-runtime.json').read_text())
require(reload_runtime['passed'], 'post-reload transitions and cleanup passed')

repo = Path(__file__).resolve().parents[3]
asset = repo / 'exotic-space-industries-remembrance-graphics-6/graphics/entities/cryo-mist.png'
require(hashlib.sha256(asset.read_bytes()).hexdigest() == '341e2cae41f220872ea1f708531bded1485c8d75962a82d72ded1fd170cbbeb0', 'unchanged upstream asset')
with Image.open(asset) as im:
    require(im.size == (2048, 2048) and im.mode == 'RGBA', 'source dimensions/alpha')

review = run / 'review'
review.mkdir(exist_ok=True)
for name in ['ei-cooler', 'ei-copper-beacon', 'ei-iron-beacon', 'group']:
    for light in ['day','night']:
        frames = []
        for i in range(61):
            path = out / f'loop/{name}-{i:02d}-{light}.png'
            require(path.is_file(), f'capture {name}/{light}/{i}')
            with Image.open(path) as im:
                frames.append(im.convert('RGB'))
        require(len({hashlib.sha256(f.tobytes()).hexdigest() for f in frames}) > 40, f'{name}/{light}: animated frames')
        # The 61st capture verifies closure; do not double it in the review loop.
        frames[0].save(review / f'{name}-{light}.webp', save_all=True, append_images=frames[1:60], duration=111, loop=0, lossless=True)

for folder, count in [('states', 56), ('transitions', 36), ('preview', 6)]:
    require(len(list((out / folder).glob('*.png'))) == count, folder + ': complete native captures')

sheet = Image.new('RGB', (1152, 820), '#20242b')
draw = ImageDraw.Draw(sheet)
for i, name in enumerate(['ei-cooler','ei-copper-beacon','ei-iron-beacon']):
    for j, light in enumerate(['day','night']):
        with Image.open(out / f'loop/{name}-20-{light}.png') as im:
            sheet.paste(im.convert('RGB'), (i * 384, j * 410 + 24))
        draw.text((i * 384 + 12, j * 410 + 6), name + ' / ' + light, fill='white')
sheet.save(review / 'day-night.png')
summary = {'passed': True, 'checks': len(checks), 'native_checks': runtime['checks'], 'visual_checks': visual['checks'],
    'reload_checks': reload_runtime['checks'], 'graphics_quality': 'high; unrelated ESIR sprites empty in render fixture',
    'loop_captures': 488, 'asset_sha256': hashlib.sha256(asset.read_bytes()).hexdigest()}
(out / 'acceptance.json').write_text(json.dumps(summary, indent=2), encoding='utf-8')
print(json.dumps(summary, indent=2))
