"""Stage unchanged core generators against isolated native electrical loads."""
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
    parser.add_argument('--refresh', action='store_true')
    parser.add_argument('--native-burner', action='store_true', help='Use Base/Quality only, with a minimal burner generator')
    args = parser.parse_args()
    root = Path(os.path.abspath(args.run))
    fixtures = Path(__file__).parent
    if not args.refresh and not args.native_burner:
        root.mkdir(parents=True, exist_ok=True)
        bridge = root / 'empty-bridge.lua'
        bridge.write_text('-- No private exports needed for native generators.\n', encoding='utf-8')
        subprocess.run([sys.executable, '-B', str(fixtures / 'stage_owner.py'),
            '--run', str(root), '--version', args.version, '--bridge', str(bridge),
            '--source', '.factorio-qc/m20' if args.version == '2.0' else '.factorio-qc/21'], check=True)
    helper = root / 'mods/zzz-esir-power-output-qc'
    helper.mkdir(parents=True, exist_ok=args.refresh)
    shutil.copy2(fixtures / 'power-output.lua', helper / 'control.lua')
    shutil.copy2(fixtures / 'power-output-data.lua', helper / 'data.lua')
    dependencies = ['exotic-space-industries-remembrance']
    if args.native_burner:
        dependencies = ['base', 'quality']
        with (helper / 'data.lua').open('a', encoding='utf-8') as stream:
            stream.write('\n' + (fixtures / 'power-native-burner.lua').read_text(encoding='utf-8'))
        (helper / 'power-config.lua').write_text('return {bodies={{name="qc-native-burner",fuel="coal"}}}\n', encoding='utf-8')
        enabled = {'base', 'quality', helper.name}
        if args.version == '2.1':
            enabled.add('recycler')
        selection = {'mods': [{'name': name, 'enabled': name in enabled}
            for name in ['base', 'quality', 'recycler', 'space-age', 'elevated-rails', helper.name]]}
        (root / 'mods/mod-list.json').write_text(json.dumps(selection), encoding='utf-8')
        engine = Path('C:/Program Files (x86)/Steam/steamapps/common/Factorio') if args.version == '2.0' else Path('.factorio-qc/f21').absolute()
        (root / 'config.ini').write_text(f'[path]\nread-data={engine / "data"}\nwrite-data={root}\n[other]\ncheck-updates=false\n', encoding='utf-8')
    else:
        (helper / 'power-config.lua').write_text('return {}\n', encoding='utf-8')
    (helper / 'info.json').write_text(json.dumps({'name': helper.name, 'version': '0.0.1',
        'title': 'Private generator output acceptance', 'author': 'ESIR QC',
        'factorio_version': args.version, 'dependencies': dependencies}, indent=2), encoding='utf-8')
    selection_path = root / 'mods/mod-list.json'
    selection = json.loads(selection_path.read_text(encoding='utf-8'))
    if not any(row['name'] == helper.name for row in selection['mods']):
        selection['mods'].append({'name': helper.name, 'enabled': True})
    selection_path.write_text(json.dumps(selection, indent=2), encoding='utf-8')
    inputs = {str(p): hashlib.sha256(p.read_bytes()).hexdigest() for p in
        [Path(__file__), *sorted(helper.glob('*'))] if p.is_file()}
    (root / 'power-fixture-source.json').write_text(json.dumps(inputs, indent=2), encoding='utf-8')


if __name__ == '__main__':
    main()
