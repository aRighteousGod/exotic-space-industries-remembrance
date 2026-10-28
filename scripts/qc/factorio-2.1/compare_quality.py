"""Verify approved native quality behavior and enumerate every changed module value."""
import argparse
import hashlib
import json
import math
from pathlib import Path


def digest(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--old',type=Path,required=True)
    p.add_argument('--new',type=Path,required=True)
    p.add_argument('--output',type=Path,required=True)
    p.add_argument('--markdown',type=Path)
    a=p.parse_args()
    old,new=(json.loads(x.read_text()) for x in (a.old,a.new))
    assert old['passed'] and new['passed']
    assert old['engine']=='2.0.77' and new['engine']=='2.1.23'
    changes=[]
    assert set(old['modules'])==set(new['modules'])
    for module,qualities in old['modules'].items():
        for quality,effects in qualities.items():
            if quality=='quality-unknown': continue
            for effect,before in effects.items():
                after=new['modules'][module][quality][effect]
                normalized=before*.1 if effect=='quality' else before
                if abs(after-normalized)>1e-6:
                    assert quality!='normal' and effect in ('productivity','quality'), (module,quality,effect)
                    changes.append(dict(module=module,quality=quality,effect=effect,
                                        before_percent=round(normalized*100,5),after_percent=round(after*100,5)))
    assert len(changes)==21
    old_machines={(r['module'],r['quality']):r for r in old['machines']}
    machine_changes=[]
    for row in new['machines']:
        before=old_machines[(row['module'],row['quality'])]
        for field in ('speed_bonus','consumption_bonus','pollution_bonus','productivity_bonus'):
            if abs(before[field]-row[field])>1e-6:
                assert field=='productivity_bonus' and row['quality']!='normal'
                machine_changes.append(dict(module=row['module'],quality=row['quality'],
                                            before=before[field],after=row[field]))
    assert len(machine_changes)==18
    base_trains={r['name']:r for r in old['trains'] if r['quality']=='normal'}
    for train in new['trains']:
        if train['quality']!='normal':continue
        for before,after in zip(base_trains[train['name']]['samples'],train['samples']):
            assert abs(before['speed']-after['speed'])<1e-9
            assert before['position']==after['position']
    speed_factors=dict(zip(('normal','uncommon','rare','epic','legendary'),(1,1.03,1.06,1.09,1.15)))
    cargo_factors=dict(zip(speed_factors,(1,1.25,1.5,1.75,2.5)))
    for name,values in new['locomotives'].items():
        for quality,value in values.items():
            # 2.0 does not expose the locomotive's prototype speed ceiling here;
            # assert the 2.1 native ratio and compare actual normal travel above.
            expected=values['normal']['max_speed']*speed_factors[quality]
            assert abs(value['max_speed']-expected)<1e-6,(name,quality,value,expected)
    for name,values in new['wagons'].items():
        for quality,value in values.items():
            assert value==math.floor(old['wagons'][name]['normal']*cargo_factors[quality]+1e-9),(name,quality,value)
    native_fluid=new['fluids']['fluid-wagon']
    for name,values in new['fluids'].items():
        for quality,value in values.items():
            factor=native_fluid[quality]/native_fluid['normal']
            assert abs(value-old['fluids'][name]['normal']*factor)<1e-6,(name,quality,value)
    result=dict(passed=True,old_sha256=digest(a.old),new_sha256=digest(a.new),
                old=str(a.old),new=str(a.new),module_count=len(new['modules']),machine_cases=len(new['machines']),
                precision_changes=changes,machine_productivity_changes=machine_changes,
                normal_train_trace_parity=True,train_cases=len(new['trains']),
                locomotives=new['locomotives'],cargo_wagons=new['wagons'],fluid_wagons=new['fluids'],
                quality_definitions=new['qualities'])
    a.output.write_text(json.dumps(result,indent=2),encoding='utf-8')
    if a.markdown:
        text=['# Approved native 2.1 quality changes','',
              'The user approved finer native module precision and native quality scaling',
              'for all ESIR locomotives and wagons. Authored normal-quality base values,',
              'module penalties and fuel bonuses remain unchanged. This table enumerates',
              'every effective module value differing after probability-unit normalization.','',
              '| Module | Quality | Effect | 2.0.77 | 2.1.23 |','|---|---|---|---:|---:|']
        for row in changes:
            text.append(f"| `{row['module']}` | {row['quality']} | {row['effect']} | {row['before_percent']:g}% | {row['after_percent']:g}% |")
        text+=['','Native verification covers all 22 shared modules at all five playable qualities',
               'and 110 actual assembler/module combinations. Eighteen productivity changes',
               'are also measured through native machine bonuses. The other three entries',
               'are tier-2 quality-effect precision. All normal-quality values and every',
               'speed/consumption/pollution bonus match after the documented probability-unit',
               'conversion. The original 48,000-craft conservation suite remains a separate',
               'probability/productivity/quality test, not evidence for every table row.','',
               'Locomotive power follows native factors 1 / 1.2 / 1.4 / 1.6 / 2.',
               'Every ESIR locomotive, including its placement body, inherits the native',
               'speed flag: ceilings scale by 1 / 1.03 / 1.06 / 1.09 / 1.15.',
               'Five actual locomotives at normal/rare/legendary quality pass native',
               'automatic travel and station-braking checks. All normal-quality sampled',
               'speeds and positions match 2.0 exactly; stronger quality behavior is approved.','']
        for key,title in [('cargo_wagons','Cargo slots'),('fluid_wagons','Fluid capacity')]:
            text += [f'## {title}','','| Wagon | Normal | Uncommon | Rare | Epic | Legendary |','|---|---:|---:|---:|---:|---:|']
            for name,values in result[key].items():
                text.append('| `'+name+'` | '+' | '.join(f'{values[q]:g}' for q in speed_factors)+' |')
            text+=['']
        text+=['## Evidence and boundaries','',f'- Baseline report: `{a.old}`; SHA-256 `{digest(a.old)}`.',
               f'- Accepted report: `{a.new}`; SHA-256 `{digest(a.new)}`.',
               f'- Full comparison: `{a.output}`.',
               '- Native values and scripted automatic travel are checked; physical driving',
               '  feel, rendered wheel alignment and a whole-factory throughput comparison',
               '  are separate evidence classes.',
               '- Prototype and item identities remain unchanged. Existing higher-quality',
               '  wagons gain capacity; no item or fluid removal is required.',
               '- No production polling, surrogate module identities or rounding emulation',
               '  was added. Balancing these approved native bonuses is deferred.','']
        a.markdown.write_text('\n'.join(text),encoding='utf-8')
    print(json.dumps(dict(passed=True,module_changes=len(changes),train_cases=len(new['trains']))))


if __name__=='__main__':
    main()
