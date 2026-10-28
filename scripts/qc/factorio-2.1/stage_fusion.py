"""Stage native fusion recipes, control custody and populated migration."""
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
    parser.add_argument('--version', choices=('2.0', '2.1'), required=True)
    parser.add_argument('--mode', choices=('donor', 'migration', 'reload', 'recipes', 'actors', 'gui'), required=True)
    parser.add_argument('--refresh', action='store_true')
    parser.add_argument('--seed', action='store_true')
    args = parser.parse_args()
    root = Path(os.path.abspath(args.run))
    fixtures = Path(__file__).parent
    if not args.refresh:
        subprocess.run([sys.executable, '-B', str(fixtures / 'stage_owner.py'), '--run', str(root),
            '--version', args.version, '--source', '.factorio-qc/m20' if args.version == '2.0' else '.factorio-qc/21',
            '--bridge', str(fixtures / 'fusion-bridge.lua')], check=True)
    else:
        source = Path('.factorio-qc/m20/mods/exotic-space-industries-remembrance') if args.version == '2.0' else Path('exotic-space-industries-remembrance')
        main_root = root / 'mods/exotic-space-industries-remembrance'
        shutil.copy2(source / 'scripts/control/fusion-reactor.lua', main_root / 'scripts/control/fusion-reactor.lua')
        (main_root / 'control.lua').write_text((source / 'control.lua').read_text(encoding='utf-8') +
            '\n-- Private fusion acceptance bridge.\n' + (fixtures / 'fusion-bridge.lua').read_text(encoding='utf-8'), encoding='utf-8')
    helper = root / 'mods/zzz-esir-fusion-qc'
    helper.mkdir(exist_ok=args.refresh)
    fixture = 'fusion-' + args.mode + '.lua' if args.mode in ('recipes', 'actors', 'gui') else 'fusion-migration.lua'
    shutil.copy2(fixtures / fixture, helper / 'control.lua')
    (helper / 'test-config.lua').write_text('return ' + json.dumps(args.mode) + '\n', encoding='utf-8')
    (helper / 'info.json').write_text(json.dumps({'name': helper.name, 'version': '0.0.1', 'author': 'ESIR QC',
        'title': 'Private fusion acceptance', 'factorio_version': args.version,
        'dependencies': ['exotic-space-industries-remembrance']}, indent=2), encoding='utf-8')
    selection_path = root / 'mods/mod-list.json'
    selection = json.loads(selection_path.read_text(encoding='utf-8'))
    if not any(row['name'] == helper.name for row in selection['mods']):
        selection['mods'].append({'name': helper.name, 'enabled': True})
    selection_path.write_text(json.dumps(selection, indent=2), encoding='utf-8')
    main_root = root / 'mods/exotic-space-industries-remembrance'
    manifest = {str(p.relative_to(root)): hashlib.sha256(p.read_bytes()).hexdigest()
        for p in [main_root / 'control.lua', main_root / 'scripts/control/fusion-reactor.lua', *helper.glob('*.lua')]}
    (root / 'fusion-source.json').write_text(json.dumps(manifest, indent=2), encoding='utf-8')
    if args.seed:
        engine = Path('C:/Program Files (x86)/Steam/steamapps/common/Factorio/bin/x64/factorio.exe') if args.version == '2.0' else Path('.factorio-qc/f21/bin/x64/factorio.exe').absolute()
        with (root / 'seed.create.log').open('w', encoding='utf-8') as log:
            subprocess.run([str(engine), '--config', str(root / 'config.ini'), '--mod-directory', str(root / 'mods'),
                '--disable-audio', '--create', str(root / 'seed.zip')], stdout=log, stderr=subprocess.STDOUT,
                creationflags=subprocess.CREATE_NO_WINDOW, check=True, timeout=180)


if __name__ == '__main__':
    main()
