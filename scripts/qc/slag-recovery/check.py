"""Compare fresh baseline/candidate final data and enforce the approved recovery budget."""
import json
import math
import sys
from pathlib import Path

root = Path(sys.argv[1])
baseline = json.loads((root / 'Baseline-slag-final-data.json').read_text(encoding='utf-8'))
candidate = json.loads((root / 'Candidate-slag-final-data.json').read_text(encoding='utf-8'))
checks = 0


def check(value, message):
    global checks
    checks += 1
    assert value, message


def close(actual, expected, message):
    check(math.isclose(actual, expected, rel_tol=1e-10, abs_tol=1e-10), message)


def mean(product):
    return product.get('probability', 1) * (product['amount'] if 'amount' in product else (product['amount_min'] + product['amount_max']) / 2)


def product(recipe, name):
    return next(p for p in recipe['results'] if p['name'] == name)


def ingredient(recipe, name):
    return next(p['amount'] for p in recipe['ingredients'] if p['name'] == name)


common_names = ['coal', 'iron', 'copper', 'sulfur']
rare_names = ['lead', 'gold', 'uranium', 'neodym']
tiers = {
    'sulfuric': ([2, 2, 1, 1], [.1, .025, .01, .005], 'sulfuric-acid', 25, 10, 6.14, 'ei-purifier'),
    'nitric': ([3, 3, 2, 2], [.25, .1, .05, .02], 'ei-nitric-acid', 20, 8, 10.42, 'ei-nitric-acid'),
    'morphium': ([4, 5, 4, 3], [.5, .2, .1, .05], 'ei-morphium', 10, 6, 16.85, 'ei-morphium-usage'),
}
changed = {'ei-slag-crushing'}
totals = []
for tier, (commons, rares, fluid, fluid_count, time, total, unlock) in tiers.items():
    for crushed in (False, True):
        name = 'ei-slag-extraction-' + tier + ('-crushed' if crushed else '')
        changed.add(name)
        old, new = baseline['recipes'][name], candidate['recipes'][name]
        check({k: v for k, v in old.items() if k not in ('ingredients', 'results')} ==
              {k: v for k, v in new.items() if k not in ('ingredients', 'results')}, name + ' presentation/flags unchanged')
        expected_inputs = [{'type': 'fluid', 'name': fluid, 'amount': fluid_count}]
        if tier == 'morphium':
            expected_inputs.append({'type': 'item', 'name': 'ei-high-energy-crystal', 'amount': 1})
        expected_inputs.append({'type': 'item', 'name': 'ei-crushed-slag' if crushed else 'ei-slag', 'amount': 200 if crushed else 100})
        check(new['ingredients'] == expected_inputs, name + ' ingredients')
        check(new['energy_required'] == time and new['category'] == 'ei-purifier', name + ' time/category')
        check(not new.get('allow_productivity', False), name + ' modules remain forbidden')
        check(candidate['unlocks'][name] == baseline['unlocks'][name] == [unlock], name + ' unlock')
        chunks = [p for p in new['results'] if p['name'].endswith('-chunk')]
        check(len(chunks) == 8, name + ' eight chunk outputs')
        for metal, amount in zip(common_names, commons):
            p = product(new, 'ei-' + metal + '-chunk')
            wanted = amount * (1.5 if crushed else 1)
            check(p.get('probability', 1) == 1, name + ' guaranteed ' + metal)
            if wanted == int(wanted):
                check(p.get('amount') == wanted and 'amount_min' not in p, name + ' fixed ' + metal)
            else:
                check('amount' not in p and p['amount_min'] == math.floor(wanted) and p['amount_max'] == math.ceil(wanted), name + ' range ' + metal)
        for metal, probability in zip(rare_names, rares):
            p = product(new, 'ei-' + metal + '-chunk')
            check(p.get('amount') == 1 and 'amount_min' not in p, name + ' rare amount ' + metal)
            close(p['probability'], probability * (1.5 if crushed else 1), name + ' probability ' + metal)
        check([p for p in old['results'] if not p['name'].endswith('-chunk')] ==
              [p for p in new['results'] if not p['name'].endswith('-chunk')], name + ' fluid/crystal rows unchanged')
        expected = total * (1.5 if crushed else 1)
        close(sum(map(mean, chunks)), expected, name + ' exact expected yield')
        totals.append({'recipe': name, 'expected': expected, 'level_five_expected': expected * 1.5})

for name, recipe in candidate['recipes'].items():
    if name not in changed:
        check(recipe == baseline['recipes'][name], name + ' unchanged adjacent recipe')
crushing = candidate['recipes']['ei-slag-crushing']
check({k: v for k, v in crushing.items() if k != 'energy_required'} ==
      {k: v for k, v in baseline['recipes']['ei-slag-crushing'].items() if k != 'energy_required'}, 'crushing changes time only')
check(crushing['energy_required'] == .5, 'crushing time')
check(candidate['crusher_power'] == '900kW', 'crusher energy basis')
check(candidate['technology'] == baseline['technology'], 'research entirely unchanged')
tech = candidate['technology']
check(tech['max_level'] == 5 and len(tech['effects']) == 6, 'five research levels / six effects')
for effect in tech['effects']:
    check(effect['type'] == 'change-recipe-productivity' and effect['recipe'] in changed and effect['change'] == .1, 'research effect')

# Derive the return from current final recipes rather than freezing 165.6 alone.
metal_returns = {}
for metal in ('lead', 'gold'):
    recipes = candidate['recipes']
    purify = recipes['ei-' + metal + '-chunk-purifier']
    cast = recipes['ei-cast-' + metal + '-ingot']
    crush = recipes['ei-crushed-' + metal]
    leach = recipes['ei-crushed-' + metal + '-sulfuric-extraction']
    for name in (cast['name'], crush['name']):
        check(not recipes[name].get('allow_productivity', False) and not candidate['productivity'][name], name + ' no extra productivity')
    slag = product(leach, 'ei-crushed-slag')
    check(slag.get('ignored_by_productivity', slag.get('ignored_by_stats', 0)) >= slag.get('amount', slag.get('amount_max')), 'leaching slag excluded from productivity')
    returns = []
    for route in ('ei-molten-', 'ei-plasma-molten-'):
        melt = recipes[route + metal + '-pure-ore']
        pure_per_chunk = mean(product(purify, 'ei-pure-' + metal)) / ingredient(purify, 'ei-' + metal + '-chunk') * (1 + purify.get('maximum_productivity', 3))
        molten_per_pure = mean(product(melt, 'ei-molten-' + metal)) / ingredient(melt, 'ei-pure-' + metal) * (1 + melt.get('maximum_productivity', 3))
        ingots_per_molten = mean(product(cast, 'ei-' + metal + '-ingot')) / ingredient(cast, 'ei-molten-' + metal)
        crushed_per_ingot = mean(product(crush, 'ei-crushed-' + metal)) / ingredient(crush, 'ei-' + metal + '-ingot')
        returns.append(pure_per_chunk * molten_per_pure * ingots_per_molten * crushed_per_ingot * mean(slag) / ingredient(leach, 'ei-crushed-' + metal))
    metal_returns[metal] = max(returns)
loop_returns = {}
for tier in tiers:
    recipe = candidate['recipes']['ei-slag-extraction-' + tier + '-crushed']
    returned = sum(mean(product(recipe, 'ei-' + metal + '-chunk')) * 1.5 * value for metal, value in metal_returns.items())
    check(returned < ingredient(recipe, 'ei-crushed-slag'), tier + ' return loop remains lossy')
    loop_returns[tier] = returned
close(loop_returns['morphium'], 165.6, 'maximum morphium loop return')

report = {'checks': checks, 'totals': totals, 'loop_returns_per_200_crushed_slag': loop_returns}
(root / 'final-data-check.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
print(json.dumps(report, indent=2))
