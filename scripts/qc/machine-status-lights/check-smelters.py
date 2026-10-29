"""Native smelter state, additive-light preservation and arc-preset regression."""
import copy
import json
import sys
from pathlib import Path
from PIL import Image

run = Path(sys.argv[1])
root = run / 'script-output' / 'machine-lights'
load = lambda name: json.loads((root / (name + '.json')).read_text(encoding='utf-8-sig'))
base = load('baseline-final')
additive = {'ei-arc-furnace', 'ei-plasma-heater', 'ei-caster'}
plain = {'light': {'type': 'basic', 'intensity': 1, 'size': 15}}
red, green = [1, .06, .03, 1], [.08, 1, .12, 1]
colors = dict(idle=red, insufficient_input=red, full_output=[1, 1, 0, 1], disabled=red,
              no_power=[0, 0, 0, 0], working=green, low_power=[1, .5, 0, 1])
# Independent expected values of the pre-existing arc flicker presets.
presets = {
    'static': [(None, None, None, .24, 12), (None, None, None, .28, 12), (None, None, None, .36, 5), (None, None, None, .16, 28)],
    'soft': [(22, .90, 1, .32, 12), (18, .88, .98, .38, 12), (26, .92, 1, .44, 5), (30, .94, 1, .18, 32)],
    'reduced': [(14, .72, .96, .46, 14), (12, .68, .92, .52, 14), (16, .76, 1, .62, 5), (18, .82, .98, .24, 38)],
}
checks = 0
state_cases, transition_checks = 0, 0


def check(value, message):
    global checks
    checks += 1
    assert value, message


check(len(base['expected']) == 28, 'all 28 final prototypes covered')
profiles = [('original', 'original', 'original'), ('off', 'off', 'original'), ('status', 'status', 'original')]
profiles += [(arc + '-status', 'status', arc) for arc in ('off', 'static', 'soft', 'reduced')]
for profile, mode, arc in profiles:
    current = load(profile + '-final')
    emitters = 0
    for name, original in base['snapshot'].items():
        expected, actual = copy.deepcopy(original), copy.deepcopy(current['snapshot'][name])
        if not expected:
            check(actual == expected, profile + ' preserved absence ' + name)
            continue
        if name == 'ei-arc-furnace' and arc != 'original':
            visuals = expected['graphics_set']['working_visualisations']
            tagged = [v for v in visuals if v.get('light', {}).get('sprite') == 'arc_furnace_glow']
            check(len(tagged) == 4, 'four authored arc working lights')
            if arc == 'off':
                expected['graphics_set']['working_visualisations'] = [v for v in visuals if v not in tagged]
            else:
                native_tagged = [v for v in actual['graphics_set']['working_visualisations'] if v.get('light', {}).get('sprite') == 'arc_furnace_glow']
                check(len(native_tagged) == 4, arc + ' retains four process lights')
                for visual, values, native in zip(tagged, presets[arc], native_tagged):
                    light = visual['light']
                    for field in ('flicker_interval', 'flicker_min_modifier', 'flicker_max_modifier', 'offset_flicker'):
                        light.pop(field, None)
                    for field, value in zip(('flicker_interval', 'flicker_min_modifier', 'flicker_max_modifier', 'intensity', 'size'), values):
                        if value is not None:
                            check(abs(native['light'][field] - value) < 1e-12, arc + ' process preset ' + field)
                            # Factorio's JSON float formatting can move the last
                            # decimal bit; tolerate that only for preset numbers.
                            light[field] = native['light'][field]
                    if values[0] is not None:
                        light['offset_flicker'] = True
        if name in base['expected'] and mode != 'original':
            visuals = expected['graphics_set']['working_visualisations']
            check(sum(v == plain for v in visuals) == (0 if name in additive else 1), name + ' original generic count')
            expected['graphics_set']['working_visualisations'] = [v for v in visuals if v != plain]
            offsets = base['expected'][name]
            if mode == 'status' and offsets:
                graphics = actual['graphics_set']
                check(graphics.pop('status_colors') == colors, name + ' status colors')
                added = [v for v in graphics['working_visualisations'] if v.get('apply_tint') == 'status']
                check(len(added) == len(offsets), name + ' status emitter count')
                emitters += len(added)
                if name in additive:
                    check(graphics['working_visualisations'][:len(added)] == added, name + ' first entries')
                for index, (visual, offset) in enumerate(zip(added, offsets), 1):
                    target = dict(always_draw=True, apply_tint='status', light=dict(type='basic', color=[1, 1, 1], size=.5 if name == 'ei-advanced-refinery' else .35, intensity=1, minimum_darkness=.1),
                        render_layer='object', secondary_draw_order=4,
                        animation=dict(filename=f'__exotic-space-industries-remembrance-graphics-6__/graphics/status-lights/{name[3:]}-{index}.png', size=64, scale=original['graphics_set']['animation'].get('scale', 1), frame_count=1, draw_as_glow=True, blend_mode='normal'))
                    for direction in ('north', 'east', 'south', 'west'):
                        position = visual.pop(direction + '_position')
                        check(all(abs(a-b) < 1e-12 for a,b in zip(position, offset)), name + ' measured center')
                    check(visual == target, name + ' exact steady light profile')
                graphics['working_visualisations'] = [v for v in graphics['working_visualisations'] if v not in added]
        check(actual == expected, profile + ' complete prototype preservation: ' + name)
    check(emitters == (23 if mode == 'status' else 0), profile + ' total emitters')
    runtime = load(profile + '-runtime')
    check(runtime['startup'] == mode and runtime['arc_preset'] == arc, profile + ' real startup values')
    count = 84 if runtime.get('focus') == 'smelters' else 764
    check(len(runtime['rows']) == count and runtime['failed'] == 0 and all(r['valid'] for r in runtime['rows']), profile + ' native states')
    transitions = load(profile + '-transitions')
    check(transitions['complete'] and transitions['checks'] == (24 if count == 84 else 156) and all(r['valid'] for r in transitions['rows']), profile + ' native transitions')
    state_cases += len(runtime['rows'])
    transition_checks += transitions['checks']

if '--data-only' in sys.argv:
    result = dict(overall_status='ok', checks=checks, native_profiles=7, native_state_cases=state_cases, native_transition_checks=transition_checks)
    (root / 'arc-preset-acceptance.json').write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps(result))
    raise SystemExit(0)

images = 0
for profile in ('status', 'off-status', 'off'):
    report = load(profile + '-visual')
    check(report['complete'] and report['scenes'] in (3, 28), profile + ' visual report')
    check(all(r['valid'] for s in report['captures'] for r in s['rows']), profile + ' capture-time statuses')
    for name in additive:
        for lighting, zoom in ([('night', 1)] if profile == 'off' else [('day', 1), ('day', 2), ('night', 1), ('night', 2)]):
            path = root / profile / f'{name}-{lighting}-{zoom}.png'
            check(path.stat().st_mtime >= (run / (profile + '.zip')).stat().st_mtime, 'fresh native capture')
            with Image.open(path) as image:
                check(image.size == (5632 * zoom, 3584 * zoom), 'native dimensions')
                image.verify()
            images += 1
        if profile != 'off':
            for state in ('circuit-disabled', 'circuit-resumed', 'energy-lost', 'energy-restored', 'output-blocked', 'output-cleared', 'power-limited', 'power-restored'):
                folder = 'transitions' if profile == 'status' and report['scenes'] == 28 else profile + '-transitions'
                path = root / folder / f'{name}-{state}.png'
                check(path.stat().st_mtime >= (run / (profile + '.zip')).stat().st_mtime, 'fresh transition')
                with Image.open(path) as image:
                    check(image.size == (768, 768), 'transition dimensions')
                    image.verify()
                images += 1

result = dict(overall_status='ok', checks=checks, targets=28, status_emitters=23,
              additive_bodies=3, native_profiles=7, native_state_cases=state_cases,
              native_transition_checks=transition_checks, native_images=images,
              arc_presets=['original', 'off', 'static', 'soft', 'reduced'])
(root / 'smelter-acceptance.json').write_text(json.dumps(result, indent=2) + '\n')
print(json.dumps(result))
