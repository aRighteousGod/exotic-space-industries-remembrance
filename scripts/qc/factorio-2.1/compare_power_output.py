"""Compare native electrical delivery and measured fuel use, not just prototypes."""
import argparse
import hashlib
import json
from pathlib import Path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--before', type=Path, required=True)
    parser.add_argument('--after', type=Path, required=True)
    parser.add_argument('--native-before', type=Path, required=True)
    parser.add_argument('--native-after', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    before, after = [json.loads(p.read_text(encoding='utf-8')) for p in (args.before, args.after)]
    assert before['engine'] == '2.0.77' and after['engine'] == '2.1.23'
    native_before, native_after = [json.loads(p.read_text(encoding='utf-8'))
        for p in (args.native_before, args.native_after)]
    assert native_before['engine'] == '2.0.77' and native_after['engine'] == '2.1.23'
    for report in (before, after):
        assert len(report['cases']) == 50 and report['assertions'] == 300
    for report in (native_before, native_after):
        assert len(report['cases']) == 10 and report['assertions'] == 60
    assert not after['failures'] and not native_after['failures']
    # Keep the negative historical result visible. Only these exact measured
    # native shortfalls qualify; no generic percentage waiver or Lua rebalance.
    for report, name in ((before, 'ei-combustion-turbine'), (native_before, 'qc-native-burner')):
        expected_failures = [f'{name}/rare/{regime} power 189439997.25 expected 192000002.86102'
                             for _ in range(2) for regime in ('full', 'overload')]
        assert report['failures'] == expected_failures, report['failures']
    native_old = {row['key']: row for row in native_before['cases']}
    native_new = {row['key']: row for row in native_after['cases']}
    old = {row['key']: row for row in before['cases']}
    new = {row['key']: row for row in after['cases']}
    assert len(old) == len(new) == 50 and old.keys() == new.keys()
    result = {'passed': False, 'cases': 50, 'windows': 100, 'failures': [], 'comparisons': [],
        'native_changes': [], 'historical_negative_assertions': before['failures'],
        'sources': [{'path': str(p), 'sha256': hashlib.sha256(p.read_bytes()).hexdigest()}
                    for p in (args.before, args.after, args.native_before, args.native_after)],
        'electric_tolerance': '1e-6 J absolute or 1e-10 relative',
        'fluid_tolerance': '1e-6 units absolute or 1e-5 relative',
        'solid_fuel_tolerance': '1e-6 J absolute or 1e-10 relative'}
    for key, prior in old.items():
        current = new[key]
        assert len(prior['samples']) == len(current['samples']) == 2
        for field in ('name', 'quality', 'regime', 'maximum_watts', 'demand_watts'):
            if prior[field] != current[field]:
                result['failures'].append({'case': key, 'field': field, 'before': prior[field], 'after': current[field]})
        for index, (a, b) in enumerate(zip(prior['samples'], current['samples'])):
            assert (a['from'], a['to']) == (b['from'], b['to'])
            fields = ['generated_joules', 'delivered_joules', 'generator_buffer_change', 'load_buffer_change']
            fields += ['fluid_consumed'] if 'fluid_consumed' in a else ['fuel_joules_consumed']
            row = {'case': key, 'from': a['from'], 'to': a['to'], 'values': {}}
            for field in fields:
                x, y = a[field], b[field]
                tolerance = max(1e-6, abs(x)*(1e-5 if field == 'fluid_consumed' else 1e-10))
                value = {'before': x, 'after': y, 'difference': y-x, 'tolerance': tolerance}
                row['values'][field] = value
                if abs(y-x) > tolerance:
                    native_key = key.replace('ei-combustion-turbine/', 'qc-native-burner/')
                    isolated = (key in ('ei-combustion-turbine/rare/full', 'ei-combustion-turbine/rare/overload')
                        and field in ('generated_joules', 'delivered_joules', 'fuel_joules_consumed')
                        and x == native_old[native_key]['samples'][index][field]
                        and y == native_new[native_key]['samples'][index][field])
                    if isolated:
                        result['native_changes'].append({'case': key, 'from': a['from'], 'field': field,
                            'reason': 'Identical native burner behavior reproduced with Base/Quality and a private generator only', **value})
                    else:
                        result['failures'].append({'case': key, 'field': field, **value})
            result['comparisons'].append(row)
    result['passed'] = not result['failures']
    assert len(result['native_changes']) == 12
    args.output.write_text(json.dumps(result, indent=2), encoding='utf-8')
    print(json.dumps({k: v for k, v in result.items() if k not in ('comparisons', 'native_changes')}))
    if not result['passed']:
        raise SystemExit(1)


if __name__ == '__main__':
    main()
