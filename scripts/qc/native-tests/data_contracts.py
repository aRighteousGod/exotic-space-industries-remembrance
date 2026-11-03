"""Required focused final-data checks, consumed before managed dump retirement."""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
from datetime import datetime, timezone

HERE = Path(__file__).resolve().parent
CHESTS = ('active-provider-chest', 'buffer-chest', 'requester-chest', 'passive-provider-chest', 'storage-chest')


def inspect_dump(path):
    spec = importlib.util.spec_from_file_location('esir_final_data', HERE.parent / 'factorio-2.1/final_data.py')
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    module.FIELDS = {
        'item': {'hidden'}, 'recipe': {'hidden', 'enabled', 'ingredients', 'results'},
        'technology': {'age', 'prerequisites', 'unit', 'effects', 'icon', 'icon_size'},
        'ammo-category': {'name'}, 'gun': {'attack_parameters'},
        'electric-turret': {'attack_parameters'}, 'ammo': {'ammo_type', 'ammo_category'},
    }
    data = module.inventory(path)
    checks = []

    def record(name, passed, observed=None):
        checks.append({'name': name, 'passed': bool(passed), 'observed': observed})

    for name in CHESTS:
        item = data.get('item', {}).get(name, {})
        recipe = data.get('recipe', {}).get(name, {})
        record('chest-item-hidden-' + name, item.get('hidden') is True)
        record('chest-recipe-hidden-disabled-' + name, recipe.get('hidden') is True and recipe.get('enabled') is False)

    technologies = data.get('technology', {})
    for name, age, prerequisite, pack in (
        ('weapon-shooting-speed-6', 'exotic-age', 'weapon-shooting-speed-5', 'ei-exotic-age-tech'),
        ('mining-productivity-3', 'advanced-computer-age', 'mining-productivity-2', 'ei-advanced-computer-age-tech'),
    ):
        technology = technologies.get(name, {})
        packs = [entry[0] if isinstance(entry, list) else entry['name'] for entry in technology.get('unit', {}).get('ingredients', [])]
        record(name + '-age', technology.get('age') == age, technology.get('age'))
        record(name + '-prerequisite', prerequisite in technology.get('prerequisites', []), technology.get('prerequisites'))
        record(name + '-science', pack in packs, packs)
    record('current-tech-ladder', 'weapon-shooting-speed-7' not in technologies and 'mining-productivity-4' not in technologies)

    accumulator = technologies.get('electric-energy-accumulators', {})
    donor = technologies.get('accumulator-v2')
    expected_icon = donor.get('icon') if donor else '__Accumulator-V2__/graphics/icons/accumulatortech_icon.png'
    expected_size = donor.get('icon_size') if donor else 256
    record('accumulator-icon', accumulator.get('icon') == expected_icon and accumulator.get('icon_size') == expected_size)
    for name, expected in (
        ('accumulator', {'ei-steel-beam': 4, 'battery': 5, 'ei-insulated-wire': 2, 'electronic-circuit': 1}),
        ('accumulator-v2', {'iron-plate': 4, 'battery': 10}),
    ):
        recipe = data.get('recipe', {}).get(name, {})
        ingredients = {entry['name']: entry['amount'] for entry in recipe.get('ingredients', [])}
        record(name + '-costs', ingredients == expected, ingredients)

    for name in ('ei-legacy-tesla-family', 'ei-legacy-tesla-turret'):
        record(name + '-registered', name in data.get('ammo-category', {}))
        effects = [effect for technology in technologies.values() for effect in technology.get('effects', [])
                   if effect.get('ammo_category') == name]
        record(name + '-upgrade-effects', bool(effects), len(effects))
    for kind, name, category in (
        ('gun', 'teslagun', 'ei-legacy-tesla-family'),
        ('electric-turret', 'tesla-turret', 'ei-legacy-tesla-turret'),
    ):
        actual = data.get(kind, {}).get(name, {}).get('attack_parameters', {}).get('ammo_category')
        record(name + '-category', actual == category, actual)
    record('tesla-ammo-category', data.get('ammo', {}).get('tesla-ammo', {}).get('ammo_category') == 'ei-legacy-tesla-family')

    for name in [f'parameter-{index}' for index in range(10)] + ['nsb-filler-recipe', 'nsb-internal-recipe']:
        recipe = data.get('recipe', {}).get(name)
        record(name + '-empty-ingredients', recipe is not None and recipe.get('ingredients') in (None, []))
    return checks


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--dump', type=Path, required=True)
    parser.add_argument('--report', type=Path, required=True)
    parser.add_argument('--run-id', required=True)
    args = parser.parse_args()
    result = {'run_id': args.run_id, 'engine_version': '2.1.24', 'complete': False, 'passed': False,
              'timestamp': datetime.now(timezone.utc).isoformat(), 'checks': []}
    try:
        result['checks'] = inspect_dump(args.dump)
        with args.dump.open('rb') as stream:
            result['dump_sha256'] = hashlib.file_digest(stream, 'sha256').hexdigest()
        result['complete'] = True
        result['passed'] = bool(result['checks']) and all(check['passed'] for check in result['checks'])
    except Exception as error:
        result['error'] = str(error)
    args.report.write_text(json.dumps(result, indent=2), encoding='utf-8')
    return 0 if result['passed'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
