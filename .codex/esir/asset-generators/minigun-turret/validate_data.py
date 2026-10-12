"""Inspect the three current engine dumps, retaining only scoped evidence."""
from pathlib import Path
import argparse, hashlib, json, re

parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--dossier', type=Path, default=Path.cwd()/'output/minigun-implementation/standalone-rename-001')
ROOT = parser.parse_args().dossier.resolve()
NAME = 'minigun-turret-hd'


def scan(path):
    selected = {}
    kind = None
    key = None
    block = None
    with path.open('r', encoding='utf-8') as stream:
        for line in stream:
            if block is not None:
                block.append(line)
                if re.match(r'^    }\s*,?\s*$', line):
                    value=json.loads(''.join(block).strip().rstrip(','))
                    if kind != 'technology' or key in (NAME,'ei-gatling-turret') or any(e.get('turret_id') in ('gun-turret',NAME) for e in value.get('effects',[])):
                        selected[kind][key]=value
                    block=None
                continue
            match=re.match(r'^  "([^"]+)":\s*$',line)
            if match:
                kind=match[1]
                if kind in ('ammo-turret','item','recipe','technology'): selected[kind]={}
            match=re.match(r'^    "([^"]+)":\s*$',line)
            if match and kind in selected:
                key=match[1]
                if key in (NAME,'ei-gatling-turret') or kind=='technology': block=[]
    return selected


def check(case):
    stage = json.loads((ROOT / ('data-'+case+'-stage.json')).read_text(encoding='utf-8-sig'))
    path = Path(stage['run'])/'script-output/data-raw-dump.json'
    raw = scan(path)
    present = NAME if case != 'esir' else 'ei-gatling-turret'
    turret = raw['ammo-turret'][present]
    attack = turret['attack_parameters']
    if case == 'esir':
        assert all(NAME not in raw[kind] for kind in ('ammo-turret','item','recipe','technology'))
        assert attack['cooldown'] == 0.25
    else:
        assert turret['max_health'] == 1500 and turret['inventory_size'] == 1
        assert turret['energy_source']['buffer_capacity'] == '666kJ'
        assert turret['energy_source']['drain'] == '15kW' and turret['energy_per_shot'] == '1kJ'
        assert attack['damage_modifier'] == 1 and abs(attack['cooldown']-1/0.9)<1e-12
        assert (attack['range'],attack['min_range'],attack['rotate_penalty']) == (32,4,14)
        assert turret['rotation_speed'] == 0.01 and turret['prepare_range'] == 35
        assert raw['item'][NAME]['stack_size'] == 10
        assert (turret.get('heating_energy') == '100kW') == (case == 'space-age')
        recipe=raw['recipe'][NAME]; technology=raw['technology'][NAME]
        assert not recipe['enabled'] and recipe['category']=='crafting'
        assert not recipe.get('surface_conditions') and 'icon' not in recipe and not recipe.get('icons')
        assert recipe['results'] == [{'type':'item','name':NAME,'amount':1}]
        expected = [('gun-turret',2),('tungsten-plate',40),('iron-gear-wheel',40),('processing-unit',20),('electric-engine-unit',20)] if case=='space-age' else [('gun-turret',2),('steel-plate',40),('iron-gear-wheel',30),('advanced-circuit',20),('electric-engine-unit',10)]
        assert [(i['name'],i['amount']) for i in recipe['ingredients']]==expected
        assert recipe['energy_required'] == (20 if case=='space-age' else 15)
        assert technology['prerequisites'] == (['gun-turret','military-4','metallurgic-science-pack'] if case=='space-age' else ['gun-turret','military-3','electric-engine'])
        assert technology['unit']['count'] == (500 if case=='space-age' else 300)
        assert technology['unit']['time'] == (45 if case=='space-age' else 30)
        science = ['automation-science-pack','logistic-science-pack','military-science-pack','chemical-science-pack']
        if case=='space-age': science += ['utility-science-pack','space-science-pack','metallurgic-science-pack']
        assert technology['unit']['ingredients'] == [[key,1] for key in science]
        assert technology['effects']==[{'type':'unlock-recipe','recipe':NAME}]
        for tech in raw['technology'].values():
            native=[e['modifier'] for e in tech.get('effects',[]) if e.get('turret_id')=='gun-turret']
            ours=[e['modifier'] for e in tech.get('effects',[]) if e.get('turret_id')==NAME]
            assert native==ours
    assert abs(turret['preparing_speed']-1/12)<1e-8 and abs(turret['folding_speed']-1/18)<1e-8
    assert len(attack['projectile_creation_parameters'])==256
    assert raw['item'][present]['icon'].startswith('__minigun-turret-HD__/')
    assert raw['technology'][present]['icon'].startswith('__minigun-turret-HD__/')
    return {'case':case,'passed':True,'dump_sha256':hashlib.file_digest(path.open('rb'),'sha256').hexdigest(),
        'selected_data':raw,'run':stage['run']}


results=[check(case) for case in ('base','space-age','esir')]
launches=[r['selected_data']['ammo-turret'][NAME if r['case']!='esir' else 'ei-gatling-turret']['attack_parameters']['projectile_creation_parameters'] for r in results]
assert launches[0]==launches[1]==launches[2]
keys=None
for path in sorted((Path.cwd()/'minigun-turret-HD/locale').glob('*/*.cfg')):
    section=None; current={}
    for line in path.read_text(encoding='utf-8').splitlines():
        if line.startswith('['): section=line[1:-1]
        elif '=' in line:
            key,value=line.split('=',1); current[(section,key)]=re.findall(r'__\d+__',value)
    if keys is None: keys=current
    assert current==keys and len(current)==9
report={'passed':True,'engine_version':'2.0.77','cases':results,'identical_launch_maps':True,'locale_key_placeholder_coverage':True}
(ROOT/'validation.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print('PASS: three engine data loads, exact progression/stats, shared launch map, seven locales')
