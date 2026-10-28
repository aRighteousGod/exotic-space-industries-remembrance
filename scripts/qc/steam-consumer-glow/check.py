"""Compare complete final prototypes and native state/capture receipts."""
import argparse
import copy
import json
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument('run', type=Path)
parser.add_argument('--visual', action='store_true')
args = parser.parse_args()
root = args.run / 'script-output/steam-glow'
snapshots = {mode: json.loads((root / f'{mode}-final.json').read_text()) for mode in ('baseline', 'on', 'off')}
changed = {'ei-steam-miner', 'ei-steam-quarry', 'ei-steam-surface-harvester',
           'ei-steam-assembler', 'ei-steam-crusher', 'ei-steam-loader'}
expected = changed | {'ei-steam-inserter', 'ei-steam-long-inserter', 'ei-steam-offshore-pump', 'ei-steam-oil-pumpjack'}
assert expected <= snapshots['on']['entities'].keys()
assert snapshots['on']['pyric'] is True and snapshots['off']['pyric'] is False
assert snapshots['on']['entities'] == snapshots['off']['entities'], 'Pyric changed steam consumers'
assert snapshots['on']['excluded'] == snapshots['baseline']['excluded'] == snapshots['off']['excluded']
before = copy.deepcopy(snapshots['baseline']['entities'])
for name in changed:
    assert 'light_flicker' not in before[name]['energy_source'], name
    before[name]['energy_source']['light_flicker'] = {'minimum_intensity': 0, 'maximum_intensity': 0}
assert before == snapshots['on']['entities'], 'Unexpected prototype change beyond the six light fields'
presentation = {}
for name, prototype in snapshots['on']['entities'].items():
    assert prototype['energy_source']['light_flicker'] == {'minimum_intensity': 0, 'maximum_intensity': 0}, name
    presentation[name] = {}
    for field in ('dying_explosion', 'damaged_trigger_effect', 'open_sound', 'close_sound', 'factoriopedia_simulation'):
        assert prototype.get(field) == snapshots['baseline']['entities'][name].get(field), (name, field)
        presentation[name][field] = bool(prototype.get(field))
reports = []
for mode in ('baseline', 'on', 'off'):
    for kind in (('runtime', 'visual') if args.visual else ('runtime',)):
        report = json.loads((root / f'{mode}-{kind}.json').read_text())
        assert report['visual'] == (kind == 'visual')
        assert {(r['name'], r['state']) for r in report['rows']} == {(n, s) for n in expected for s in ('working', 'starved')}
        for row in report['rows']:
            assert row['tick'] and row['status']
            if row['state'] == 'working':
                assert row['activity'] > 0 and row['status'] == 'working', row
            else:
                assert row['activity'] == 0 and row['energy'] == 0 and row['status'] == 'no_input_fluid', row
            if kind == 'visual':
                assert (root / mode / f"{row['name']}-{row['state']}.png").stat().st_size > 1000
        reports.append({'mode': mode, 'kind': kind, 'states': len(report['rows'])})
summary = {'status': 'passed', 'consumers': sorted(before), 'additional_variants': sorted(before.keys() - expected),
           'changed_prototypes': sorted(changed), 'preserved_exclusions': sorted(snapshots['on']['excluded']),
           'presentation_fields_present': presentation, 'reports': reports, 'captures': 60 if args.visual else 0}
(root / 'acceptance.json').write_text(json.dumps(summary, indent=2) + '\n')
print(json.dumps(summary, indent=2))
