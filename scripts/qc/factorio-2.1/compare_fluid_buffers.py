"""Compare merged recipe fluid sizing using the paired native engine formulas.

Input capacities are exact for the tested private crafting inputs. Output values
are recipe sizing floors: a larger authored entity volume can dominate them.
This retains all discrepancies for ownership review instead of blessing defaults.
"""
import argparse
import hashlib
import json
from pathlib import Path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('before', type=Path)
    parser.add_argument('after', type=Path)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    before, after = [json.loads(p.read_text(encoding='utf-8'))['recipe'] for p in (args.before, args.after)]
    aliases = {'molten-iron': 'iron-ore-melting', 'molten-copper': 'copper-ore-melting'}
    for old, new in aliases.items():
        if old in before and new in after:
            before[new] = before.pop(old)
    checked, differences, changed_inputs = {'ingredients': 0, 'results': 0}, [], []
    for name in sorted(before.keys() & after.keys()):
        for field in checked:
            old = [x for x in before[name].get(field, []) if x.get('type') == 'fluid']
            new = [x for x in after[name].get(field, []) if x.get('type') == 'fluid']
            old.sort(key=lambda x: (x['name'], x.get('fluidbox_index', 0)))
            new.sort(key=lambda x: (x['name'], x.get('fluidbox_index', 0)))
            if [x['name'] for x in old] != [x['name'] for x in new]:
                if old or new:
                    differences.append({'recipe': name, 'field': field, 'reason': 'different fluid identities', 'before': old, 'after': new})
                continue
            for a, b in zip(old, new):
                checked[field] += 1
                if field == 'ingredients':
                    ca = a['amount'] * a.get('fluidbox_multiplier', 2)
                    cb = b['amount'] * (b.get('fluidbox_multiplier', 3) + 1)
                    if a['amount'] != b['amount']:
                        changed_inputs.append({'recipe': name, 'fluid': a['name'], 'before': a['amount'], 'after': b['amount']})
                else:
                    ca = a.get('amount', a.get('amount_max')) * 2
                    cb = b.get('amount', b.get('amount_max')) * b.get('fluidbox_multiplier', 3)
                if abs(ca - cb) > 1e-9:
                    differences.append({'recipe': name, 'field': field, 'fluid': a['name'], 'before_capacity': ca,
                        'after_capacity': cb, 'before': a, 'after': b})
    result = {'checked': checked, 'differences': differences, 'changed_input_amounts': changed_inputs, 'aliases': aliases,
        'sources': {str(p): hashlib.sha256(p.read_bytes()).hexdigest() for p in (args.before, args.after)},
        'limits': 'Output sizing floors, not all-machine runtime capacity; no throughput or rendering claim'}
    args.output.write_text(json.dumps(result, indent=2), encoding='utf-8')
    print(json.dumps({'checked': checked, 'differences': len(differences), 'changed_input_amounts': changed_inputs}))


if __name__ == '__main__':
    main()
