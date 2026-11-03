"""Validate the final native administration/reload pair and retain compact evidence."""
import argparse
import hashlib
import json
import pathlib
import shutil
import struct
import subprocess


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--context', required=True)
    parser.add_argument('--label', default='administration-final-render')
    parser.add_argument('--reload-label', default='administration-final-reload')
    args = parser.parse_args()
    repo = pathlib.Path(__file__).resolve().parents[3]
    context = json.loads(pathlib.Path(args.context).read_text(encoding='utf-8-sig'))
    evidence = pathlib.Path(context['evidence'])

    def read(name):
        return json.loads((evidence / (name + '.json')).read_text(encoding='utf-8-sig'))

    labels = [args.label, args.reload_label]
    names = []
    manifests = []
    for label in labels:
        receipt = read(label)
        assert receipt['passed'] and receipt['engine'] == '2.1.24'
        assert receipt['checks'] and all(row['passed'] for row in receipt['checks'])
        assert receipt['status']['update_budget'] == 1 and receipt['status']['rebuild']['active']
        names.append({row['name'] for row in receipt['checks']})
        manifests.append({name.replace('\\', '/'): sha for name, sha in read(label + '-sources').items()})
    for budget in (1, 2, 7, 8, 31, 32, 63, 64, 65, 256, 1024):
        for kind in ('dirty', 'occupied-joint', 'recipe-check'):
            assert f'native {kind} progress at {budget}' in names[0]
    required = ('native setting type/default/bounds', 'diagnostic summary is pure',
                'summary does not initialize absent state', 'one administration owner',
                'administration writes authoritative native value',
                'stale native-setting draft conflicts without loss', 'non-admin repair denied',
                'non-admin setting edit denied', 'setting edits cause no helper churn',
                'inspection bounded to64', 'inspection notice is localized', 'manual repair admitted',
                'repair receipt is localized', 'localized repair receipt is detached',
                'pace change preserves report identity and progress',
                'shared monitor retains exact waiting report without ETA',
                'repair completes despite permanent recipe checks',
                'repair preserves native fluid state', 'supersession retained in scheduler history')
    assert set(required) <= names[0]
    assert all(f'repair preserves pipe identity {i}' in names[0] for i in range(1, 801))
    assert {'populated administration checkpoint retained',
            'ordinary reload preserves fairness cursor before its first service',
            'ordinary reload retains active report', 'ordinary reload retains bounded backlog',
            'ordinary reload retains runtime budget'} <= names[1]
    checkpoint = read(args.label + '-checkpoint')
    assert checkpoint['sha256'] == read(args.reload_label + '-monitor')['save_sha256']
    shipping = repo / 'exotic-space-industries-remembrance'
    private = pathlib.Path(context['mods']) / 'exotic-space-industries-remembrance'
    owner_paths = ('lib/factory-passage-config.lua', 'lib/runtime-scheduler.lua',
                   'lib/map-settings-config.lua', 'settings.lua', 'prototypes/factory-passage.lua',
                   'scripts/data-final-updates/factory-passage.lua', 'scripts/control/factory-passage.lua',
                   'scripts/control/map-settings.lua', 'scripts/control/admin/map-settings.lua',
                   'scripts/control/admin/registry.lua', 'scripts/control/admin/gui.lua')
    production = {}
    for name in owner_paths:
        sha = digest(shipping / name)
        assert all(manifest['exotic-space-industries-remembrance/' + name] == sha for manifest in manifests)
        production[name] = sha
    # The private bridge runs native setting writes in their real owning mod.
    assert (private / 'control.lua').read_bytes() == (shipping / 'control.lua').read_bytes() + b"\nrequire('factory-passage-qc')\n"
    assert all(manifest['exotic-space-industries-remembrance/control.lua'] == digest(private / 'control.lua') for manifest in manifests)
    production['control.lua'] = digest(shipping / 'control.lua')
    for locale in ('en', 'de', 'fr', 'ja', 'pl', 'ru', 'zh-CN', 'zh-TW'):
        name = f'locale/{locale}/factory-passage.cfg'
        assert (shipping / name).read_bytes() == (private / name).read_bytes()
        production[name] = digest(shipping / name)
    frames = read(args.label + '-frames')
    assert sorted(row['scene'] for row in frames) == ['active-rebuild', 'map-settings', 'waiting-rebuild']
    for row in frames:
        path = pathlib.Path(row['absolute_path'])
        assert digest(path) == row['sha256']
        assert struct.unpack('>II', path.read_bytes()[16:24]) == (1280, 720)
    repro = evidence / 'repro'
    repro.mkdir(exist_ok=True)
    for name in ('administration.lua', 'suite.lua'):
        path = pathlib.Path(context['mods']) / context['helper'] / name
        sha = digest(path)
        assert all(manifest[context['helper'] + '/' + name] == sha for manifest in manifests)
        shutil.copy2(path, repro / name)
    bridge = private / 'factory-passage-qc.lua'
    assert digest(bridge) == digest(pathlib.Path(__file__).with_name('admin-bridge.lua'))
    assert all(manifest['exotic-space-industries-remembrance/factory-passage-qc.lua'] == digest(bridge) for manifest in manifests)
    shutil.copy2(bridge, repro / bridge.name)
    offline = []
    for name in ('fairness', 'map-setting', 'lifecycle'):
        path = pathlib.Path(__file__).with_name(name + '.lua')
        result = subprocess.run([str(repo / '.tools/lua-5.4.8/lua54.exe'), str(path)], cwd=repo, text=True, capture_output=True, check=True)
        offline.append(dict(fixture=name, passed=True, output=result.stdout.strip(), sha256=digest(path)))
    result = dict(passed=True, engine='2.1.24', required_labels=labels, production_sha256=production,
                  checkpoint_sha256=checkpoint['sha256'], budgets=[1, 2, 7, 8, 31, 32, 63, 64, 65, 256, 1024],
                  pipe_identities_preserved=800, frames=frames, offline=offline,
                  scope='Full ESIR profile; actual native GUI, settings, entities, movement and separate-process save/reload. Repeated assertion rows are not distinct scenarios. Native process timing is not performance evidence. Surface report transitions and rollback fault injection are offline. Two-client multiplayer is not tested.')
    (evidence / 'administration-acceptance.json').write_text(json.dumps(result, indent=2), encoding='utf8')
    print(json.dumps(dict(passed=True, native_cases=labels, images=len(frames), offline=offline)))


if __name__ == '__main__':
    main()
