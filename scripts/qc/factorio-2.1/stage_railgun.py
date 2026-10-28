"""Stage version-pinned native railgun logistics and coolant acceptance."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--run', required=True)
    parser.add_argument('--version', choices=('2.0', '2.1'), default='2.1')
    parser.add_argument('--mode', choices=('fresh', 'donor', 'migration', 'reload'), default='fresh')
    args = parser.parse_args()
    root = Path(os.path.abspath(args.run))
    fixtures = Path('scripts/qc/railgun-cooling')
    subprocess.run([sys.executable, '-B', 'scripts/qc/factorio-2.1/stage_owner.py',
        '--run', str(root), '--source', '.factorio-qc/m20' if args.version == '2.0' else '.factorio-qc/21',
        '--version', args.version, '--bridge', str(fixtures / 'instrument.lua')], check=True)
    mods = root / 'mods'
    helper = mods / 'zzz-esir-railgun-qc'
    helper.mkdir()
    for path in fixtures.iterdir():
        if path.is_file():
            shutil.copy2(path, helper / path.name)
    info = json.loads((helper / 'info.json').read_text(encoding='utf-8'))
    info['factorio_version'] = args.version
    (helper / 'info.json').write_text(json.dumps(info, indent=2), encoding='utf-8')
    config = {'baseline': False, 'save_baseline': args.mode == 'donor',
              'load_baseline': args.mode == 'migration', 'reload': args.mode == 'reload', 'checkpoint': True}
    (helper / 'test-config.lua').write_text('return {' + ','.join(f'{k}={str(v).lower()}' for k, v in config.items()) + '}\n', encoding='utf-8')
    selection = json.loads((mods / 'mod-list.json').read_text(encoding='utf-8'))
    selection['mods'].append({'name': info['name'], 'enabled': True})
    (mods / 'mod-list.json').write_text(json.dumps(selection, indent=2), encoding='utf-8')
    hashes = {path.name: hashlib.sha256(path.read_bytes()).hexdigest() for path in helper.glob('*.lua')}
    (root / 'fixture-manifest.json').write_text(json.dumps({'mode': args.mode, 'version': args.version,
        'hashes': hashes}, indent=2), encoding='utf-8')
    print(json.dumps({'run': str(root), 'mode': args.mode, 'version': args.version}))


if __name__ == '__main__':
    main()
