"""Accept current mode/state checks independently of rendered actor fixtures."""
import argparse
import hashlib
import json
import pathlib
import shutil


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--context', required=True)
    parser.add_argument('--isolated', action='store_true')
    parser.add_argument('--with-reload', action='store_true')
    parser.add_argument('--companion', action='store_true')
    args = parser.parse_args()
    repo = pathlib.Path(__file__).resolve().parents[3]
    context = json.loads(pathlib.Path(args.context).read_text(encoding='utf-8-sig'))
    root = pathlib.Path(context['evidence'])
    modes = ('esir', 'squeak-through', 'vanilla')
    if args.companion:
        cases = [('companion', 'esir', True)]
    elif args.isolated:
        cases = [('isolated-' + mode, mode, True) for mode in modes]
        if args.with_reload:
            cases.append(('isolated-reload', 'esir', True))
    else:
        cases = [('full-' + mode, mode, True) for mode in modes]
        cases += [(before + '-to-' + after, after, True) for before in modes for after in modes if before != after]
        cases += [('full-reload', 'esir', True), ('full-master-off', 'esir', False), ('full-master-on', 'esir', True)]
        cases += [(category + '-off', 'esir', True) for category in ('production', 'power', 'logistics', 'turrets')]
    owner = context['helper'] if args.isolated or args.companion else 'exotic-space-industries-remembrance'
    production = {name: hashlib.sha256((repo / 'exotic-space-industries-remembrance' / name).read_bytes()).hexdigest()
                  for name in ('lib/factory-passage-config.lua', 'lib/runtime-scheduler.lua', 'prototypes/factory-passage.lua',
                               'scripts/data-final-updates/factory-passage.lua', 'scripts/control/factory-passage.lua')}
    results = []
    manifests = []
    for label, mode, enabled in cases:
        receipt = json.loads((root / (label + '.json')).read_text(encoding='utf-8-sig'))
        assert receipt['passed'] and receipt['engine'] == '2.1.24' and receipt['mode'] == mode and receipt['enabled'] == enabled
        assert receipt['checks'] and all(row['passed'] for row in receipt['checks'])
        check_names = {row['name'] for row in receipt['checks']}
        state = receipt['status']
        effective = mode if enabled and not args.companion else 'vanilla'
        assert state['mode'] == state['effective_mode'] == effective and state['configured_mode'] == mode
        reason = 'companion' if args.companion else 'master-disabled' if not enabled else 'pipe-mode' if mode != 'esir' else 'active'
        assert state['inactive_reason'] == reason
        assert state['update_budget'] == 256 and state['counters']['max_processed'] <= 256
        assert state['dirty'] == state['pending'] == 0 and not state['rebuild']['active']
        assert state['counters']['unsupported'] == 0
        if effective != 'esir':
            assert state['helpers'] == state['joints'] == state['watchers'] == 0
        source_label = None
        if '-to-' in label:
            assert receipt['transition']
            before, after = label.split('-to-')
            assert receipt['from_mode'] == before and receipt['from_enabled'] and mode == after
            source_label = 'full-' + before
        if label in ('full-master-off', 'full-master-on'):
            assert receipt['transition'] and receipt['from_mode'] == 'esir'
            assert receipt['from_enabled'] == (label == 'full-master-off')
            source_label = 'full-esir' if label == 'full-master-off' else 'full-master-off'
        if label in ('full-reload', 'isolated-reload'):
            assert receipt['loaded'] and not receipt.get('transition')
            assert {'placed identities fluids temperatures quality and connections survive reload/transition',
                    'ordinary reload preserves helper identities', 'ordinary reload performs no topology rebuild'} <= check_names
            source_label = 'isolated-esir' if args.isolated else 'full-esir'
        if source_label:
            monitor = json.loads((root / (label + '-monitor.json')).read_text(encoding='utf-8-sig'))
            source_monitor = json.loads((root / (source_label + '-settle-monitor.json')).read_text(encoding='utf-8-sig'))
            assert monitor['save_sha256'] == source_monitor['checkpoint_sha256']
        categories = ('production', 'power', 'logistics', 'turrets')
        if label in [category + '-off' for category in categories]:
            disabled = label[:-4]
            changed = receipt['prototypes']['changed']
            present = {row['category'] for row in changed.values()}
            assert disabled not in present and set(categories) - {disabled} <= present
            assert {'representative category switch ' + category for category in categories} <= check_names
        if args.companion:
            assert 'actual Squeak Through 2 overrides every ESIR collision mutation' in check_names
        manifest = json.loads((root / (label + '-sources.json')).read_text(encoding='utf-8-sig'))
        manifest = {name.replace('\\', '/'): sha for name, sha in manifest.items()}
        manifests.append(manifest)
        assert all(manifest[owner + '/' + name] == sha for name, sha in production.items())
        results.append(dict(label=label, assertion_records=len(receipt['checks']), status=state))
    if args.isolated:
        # Keep the exact accepted actor-isolation fix for later source promotion.
        target = root / 'repro'
        target.mkdir(exist_ok=True)
        for name in ('layouts.lua', 'suite.lua'):
            path = pathlib.Path(context['mods']) / context['helper'] / name
            sha = hashlib.sha256(path.read_bytes()).hexdigest()
            assert all(manifest[context['helper'] + '/' + name] == sha for manifest in manifests)
            shutil.copy2(path, target / name)
    output = 'companion-acceptance' if args.companion else 'isolated-movement-acceptance' if args.isolated else 'mode-acceptance'
    report = dict(passed=True, engine='2.1.24', required_labels=[row[0] for row in cases], production_sha256=production,
                  cases=results, scope='Base plus exact passage sources' if args.isolated or args.companion else 'Full ESIR development profile',
                  multiplayer='No two-client synchronization claim',
                  fixture_note='Isolated turret copies prevent test characters colliding before the measured joints' if args.isolated else '')
    (root / (output + '.json')).write_text(json.dumps(report, indent=2), encoding='utf8')
    print(json.dumps(dict(passed=True, groups=len(cases), receipt=output)))


if __name__ == '__main__':
    main()
