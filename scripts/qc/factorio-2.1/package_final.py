"""Verify final data from the exact archive-only release selection."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import copy

import final_data


def digest(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def approved_buffer_changes(before, after):
    """Permit only the user's exact native buffer exception to the frozen core."""
    left, right = copy.deepcopy(before), copy.deepcopy(after)
    # Explicit follow-up approval adopts native discovery-gated personal travel.
    travel_effect = {'type': 'unlock-travel-to-space-platforms', 'modifier': True}
    assert left['technology']['rocket-silo']['effects'].count(travel_effect) == 1
    assert travel_effect not in right['technology']['rocket-silo']['effects']
    left['technology']['rocket-silo']['effects'].remove(travel_effect)
    for planet in ('vulcanus', 'gleba', 'fulgora'):
        assert travel_effect in right['technology']['planet-discovery-' + planet]['effects']
    changes = []
    assert set(left['recipe']) == set(right['recipe'])
    for name, recipe in left['recipe'].items():
        for kind in ('ingredients', 'results'):
            old_rows, new_rows = recipe.get(kind, []), right['recipe'][name].get(kind, [])
            assert len(old_rows) == len(new_rows), (name, kind)
            for index, (old, new) in enumerate(zip(old_rows, new_rows)):
                old_multiplier, new_multiplier = old.get('fluidbox_multiplier'), new.get('fluidbox_multiplier')
                if old_multiplier == new_multiplier:
                    continue
                assert old.get('type') == new.get('type') == 'fluid', (name, kind, index)
                if kind == 'ingredients':
                    assert (old_multiplier == 1 and new_multiplier is None) or (
                        isinstance(old_multiplier, (int, float)) and new_multiplier == old_multiplier + 1), (name, old, new)
                else:
                    assert old_multiplier == 2 and new_multiplier is None, (name, old, new)
                changes.append(dict(recipe=name,kind=kind,index=index,fluid=old['name'],
                    before=old_multiplier,after=new_multiplier))
                old.pop('fluidbox_multiplier',None);new.pop('fluidbox_multiplier',None)
    assert left == right, 'Gameplay drift beyond approved native buffer and travel policies'
    assert changes, 'Expected the approved buffer policy to change final data'
    return changes


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--run', type=Path, required=True)
    parser.add_argument('--baseline', type=Path, required=True)
    args = parser.parse_args()
    root = args.run.absolute()
    selection_path = root / 'release-selection.json'
    selection = json.loads(selection_path.read_text())
    assert not selection['source_overlays']
    for row in selection['packages']:
        assert digest(Path(row['staged'])) == row['sha256']
    log_path = root / 'packages-final-data.log'
    engine = Path('.factorio-qc/f21/bin/x64/factorio.exe').absolute()
    with log_path.open('w', encoding='utf-8') as log:
        process = subprocess.run([str(engine), '--config', str(root / 'config.ini'),
            '--mod-directory', str(root / 'mods'), '--disable-audio', '--dump-data'],
            stdout=log, stderr=subprocess.STDOUT, timeout=300,
            creationflags=subprocess.CREATE_NO_WINDOW)
    assert process.returncode == 0, log_path
    dump = root / 'script-output/data-raw-dump.json'
    assert dump.exists()
    inventory = final_data.inventory(dump)
    crystals = final_data.crystal_contract(inventory['recipe'])
    assert crystals['all_pass'] and crystals['count'] == 24
    buffer_changes = approved_buffer_changes(json.loads(args.baseline.read_text(encoding='utf-8')), inventory)
    compact = root / 'compact'
    compact.mkdir(exist_ok=True)
    for name, value in [('inventory', inventory), ('crystals', crystals)]:
        (compact / (name + '.json')).write_text(json.dumps(value, indent=2), encoding='utf-8')
    (compact / 'approved-native-buffer-changes.json').write_text(json.dumps(buffer_changes,indent=2),encoding='utf-8')
    fields = {'locomotive': 'quality_affects_max_speed',
              'cargo-wagon': 'quality_affects_inventory_size',
              'fluid-wagon': 'quality_affects_capacity'}
    final_data.FIELDS = {kind: {'name', field} for kind, field in fields.items()}
    rocket_fields = {'arms_speed_modifier_per_quality_level',
        'rocket_engine_starting_speed_modifier_per_quality_level',
        'rocket_rising_speed_modifier_per_quality_level'}
    final_data.FIELDS['rocket-silo'] = {'name', 'lift_weight'} | rocket_fields
    rolling = final_data.inventory(dump)
    counts = {}
    for kind, field in fields.items():
        native = rolling[kind][kind]
        assert native[field] is True
        owned = {name: value for name, value in rolling[kind].items()
                 if name.startswith(('ei-', 'ei_'))}
        counts[kind] = len(owned)
        for name, value in owned.items():
            assert value.get(field) == native[field], (name, field, value)
    assert counts == {'locomotive': 5, 'cargo-wagon': 4, 'fluid-wagon': 3}, counts
    silo = rolling['rocket-silo']['rocket-silo']
    expected_silo = {'arms_speed_modifier_per_quality_level':0.2,
        'rocket_engine_starting_speed_modifier_per_quality_level':0.45,
        'rocket_rising_speed_modifier_per_quality_level':0.15}
    assert all(silo[field] == value for field,value in expected_silo.items()), silo
    assert silo.get('lift_weight', 1000000) == 1000000
    (compact / 'rolling-stock-quality.json').write_text(json.dumps(rolling, indent=2), encoding='utf-8')
    receipt = dict(passed=True, dump=str(dump), dump_sha256=digest(dump),
        archive_manifest_sha256=digest(selection_path), verified_archives=len(selection['packages']),
        crystal_count=crystals['count'], inventory_sha256=digest(compact / 'inventory.json'),
        gameplay_inventory_matches_except_approved_buffers_and_travel=str(args.baseline), native_quality_inheritance=counts,
        native_platform_travel={'rocket_silo':False,'planet_discovery_vulcanus':True,'planet_discovery_gleba':True,'planet_discovery_fulgora':True},
        native_silo_quality_animation=expected_silo, approved_buffer_records=len(buffer_changes),
        quality_inventory_sha256=digest(compact / 'rolling-stock-quality.json'))
    (root / 'packages-final-data.receipt.json').write_text(json.dumps(receipt, indent=2), encoding='utf-8')
    print(json.dumps(receipt))


if __name__ == '__main__':
    main()
