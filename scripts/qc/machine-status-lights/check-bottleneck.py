"""Native BNL 1.3.4 integration: stage timing, exclusion scope and preservation."""
import copy
import json
import sys
from pathlib import Path

run = Path(sys.argv[1])
root = run / 'script-output/machine-lights'
load = lambda name: json.loads((root / (name + '-final.json')).read_text())
red, green = [1, .06, .03, 1], [.08, 1, .12, 1]
colors = dict(idle=red, insufficient_input=red, disabled=red, working=green,
              full_output=[1, 1, 0, 1], low_power=[1, .5, 0, 1], no_power=[0, 0, 0, 0])
plain = dict(light=dict(type='basic', intensity=1, size=15))
checks, state_cases, transitions = 0, 0, 0


def check(value, message):
    global checks
    checks += 1
    assert value, message


def bnl(visual):
    return visual.get('animation', {}).get('filename') == '__BottleneckLite__/graphics/solid.png'


for profile in ('absent', 'disabled', 'enabled', 'custom'):
    prefix = '' if profile == 'absent' else 'bnl-' + profile + '-'
    baseline = load(prefix + 'baseline')
    active = profile in ('enabled', 'custom')
    for mode in ('original', 'off', 'status'):
        key = prefix + mode
        current = load(key)
        check(current['bottleneck_version'] == ('absent' if profile == 'absent' else '1.3.4'), key + ' pinned BNL version')
        check(current['bottleneck_enabled'] == active, key + ' real BNL startup setting')
        check(sum(current['early']['flags'].values()) == (20 if active and mode == 'status' else 0), key + ' early flag count')
        for name, before in baseline['snapshot'].items():
            expected, after = copy.deepcopy(before), copy.deepcopy(current['snapshot'][name])
            lamps = baseline['expected'].get(name, [])
            if name in baseline['expected']:
                excluded = active and mode == 'status' and bool(lamps)
                check(current['early']['flags'][name] == excluded, key + ' early exclusion ' + name)
                graphics = after['graphics_set']
                check(sum(bnl(v) for v in graphics['working_visualisations']) == (1 if active and not excluded else 0), key + ' BNL indicator count ' + name)
                if excluded:
                    expected['graphics_set']['working_visualisations'] = [v for v in expected['graphics_set']['working_visualisations'] if not bnl(v)]
                    expected['graphics_set'].pop('status_colors')
                if mode != 'original':
                    expected['graphics_set']['working_visualisations'] = [v for v in expected['graphics_set']['working_visualisations'] if v != plain]
                    if mode == 'status' and lamps:
                        check(graphics.pop('status_colors') == colors, key + ' independent ESIR colors ' + name)
                        lenses = [v for v in graphics['working_visualisations'] if v.get('animation', {}).get('filename', '').startswith('__exotic-space-industries-remembrance__/graphics/status-lights/')]
                        check(len(lenses) == len(lamps), key + ' paired lens/emitter count ' + name)
                        graphics['working_visualisations'] = [v for v in graphics['working_visualisations'] if v not in lenses]
            check(after == expected, key + ' complete prototype preservation ' + name)
        control = current['snapshot']['assembling-machine-1']
        check(not any(bnl(v) for v in control['graphics_set']['working_visualisations']), key + ' independently seeded ignore flag honored')
        check(control.get('bottleneck_ignore') == (None if active else True), key + ' existing flag preserved or consumed by BNL')
        control = current['snapshot']['assembling-machine-2']
        check(control.get('bottleneck_ignore') == (None if active else True), key + ' Assembler-Reskin ignore flag preserved or consumed')
        check(not any(bnl(v) for v in control['graphics_set']['working_visualisations']), key + ' reskinned assembler remains excluded')
        # Assembler-Reskin already owns an ignore flag and reads BNL's palette.
        # Use one of the eight intentionally uncovered bodies for BNL's actual
        # added indicator and customized color table.
        control = current['snapshot']['ei-bio-chamber']
        check(sum(bnl(v) for v in control['graphics_set']['working_visualisations']) == int(active), key + ' uncovered body indicator')
        if profile == 'custom':
            for color in control['graphics_set']['status_colors'].values():
                values = color if isinstance(color, list) else [color.get(k, 0) for k in ('r', 'g', 'b')] + [color.get('a', 1)]
                check(len(values) == 4 and all(abs(x-y) < 1e-6 for x,y in zip(values, [.2, .7, 1, 1])), key + ' actual customized BNL palette')
        runtime = json.loads((root / (key + '-runtime.json')).read_text())
        result = json.loads((root / (key + '-transitions.json')).read_text())
        check(runtime['failed'] == 0 and len(runtime['rows']) == 764, key + ' native states')
        check(result['complete'] and result['checks'] == 156 and all(r['valid'] for r in result['rows']), key + ' native transitions')
        state_cases += len(runtime['rows'])
        transitions += result['checks']
report = dict(overall_status='ok', checks=checks, profiles=12, native_state_cases=state_cases,
              transition_checks=transitions, bottleneck_version='1.3.4')
(root / 'bottleneck-acceptance.json').write_text(json.dumps(report, indent=2) + '\n')
print(json.dumps(report))
