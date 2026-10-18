"""Compare native v1/v2 default placement and v2 Nauvis family isolation."""
import json
import sys
from pathlib import Path

before, after, output = map(Path, sys.argv[1:])
baseline = {(c['planet'], c['seed']): c for c in json.loads(before.read_text())['cases']}
cases = json.loads(after.read_text())['cases']
normal = {(c['planet'], c['seed']): c for c in cases if c['case'] == 'default'}
single = {(c['seed'], c['family'], c['case']): c for c in cases if c.get('family')}
checks = []

def check(name, passed):
    checks.append(dict(name=name, pass_=bool(passed)))

check('complete-matrix', len(cases) == 156)
check('unique-cases', len({(c['planet'], c['seed'], c.get('family'), c['case']) for c in cases}) == len(cases))
for case in cases:
    key = case['planet'], case['seed']
    label = '/'.join(map(str, (*key, case.get('family', 'all'), case['case'])))
    check(label+'/exchange', case['roundtrip'])
    check(label+'/sample-count', all(v.get('omitted') or v['count'] == 9409 for v in case['noise'].values()))
    if case['case'] == 'default':
        for field in ('noise', 'entities', 'territories'):
            check(label+'/'+field, case[field] == baseline[key][field])
        continue
    reference = normal[key]
    check(label+'/property-coverage', case['noise'].keys() == reference['noise'].keys())
    if case.get('mixed'):
        for prop, value in case['noise'].items():
            family = case['families'].get(prop)
            variant = case['mixed'].get(family)
            expected = single[case['seed'], family, variant] if variant else reference
            check(label+'/independent/'+prop, value == expected['noise'][prop])
        continue
    affected = {k: v for k, v in case['noise'].items() if case['families'].get(k) == case['family']}
    check(label+'/family-covered', bool(affected))
    check(label+'/other-families-independent', all(v == reference['noise'][k] for k, v in case['noise'].items() if k not in affected))
    if case['case'] in ('off', 'frequency-zero', 'size-zero'):
        check(label+'/no-placement', all(v['positive'] == 0 for v in affected.values()))
        if case['case'] == 'off':
            names = {k.split(':')[1] for k in affected}
            check(label+'/no-generated-bodies', all(e.split(':')[0] not in names for e in case['entities']))
    else:
        check(label+'/slider-effective', any(v != reference['noise'][k] for k, v in affected.items()))
report = dict(all_pass=all(c['pass_'] for c in checks), cases=len(cases), checks=checks)
output.write_text(json.dumps(report, indent=2)+'\n')
print(json.dumps(dict(all_pass=report['all_pass'], checks=len(checks), cases=len(cases), failures=[c['name'] for c in checks if not c['pass_']])))
sys.exit(not report['all_pass'])
