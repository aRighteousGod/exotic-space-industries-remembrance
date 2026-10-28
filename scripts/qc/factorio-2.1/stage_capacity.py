"""Stage the same 36 native fluid-capacity probes in exact 2.0/2.1 cores."""
import argparse
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
    args = parser.parse_args()
    root = Path(os.path.abspath(args.run))
    root.mkdir(parents=True, exist_ok=True)
    bridge = root / 'empty-bridge.lua'
    bridge.write_text('-- All probe events belong to the private helper.\n', encoding='utf-8')
    subprocess.run([sys.executable, '-B', 'scripts/qc/factorio-2.1/stage_owner.py', '--run', str(root),
        '--source', '.factorio-qc/m20' if args.version == '2.0' else '.factorio-qc/21',
        '--version', args.version, '--bridge', str(bridge)], check=True)
    mods = root / 'mods'
    helper = mods / 'zzz-esir-fluid-capacity-qc'
    helper.mkdir()
    for source, target in [('fluid-capacity-data.lua', 'data-final-fixes.lua'), ('fluid-capacity-runtime.lua', 'control.lua')]:
        shutil.copy2(Path('scripts/qc/factorio-2.1') / source, helper / target)
    info = {'name': helper.name, 'version': '0.0.1', 'title': 'Private ESIR fluid capacity probes',
            'author': 'ESIR QC', 'factorio_version': args.version, 'dependencies': ['exotic-space-industries-remembrance']}
    (helper / 'info.json').write_text(json.dumps(info, indent=2), encoding='utf-8')
    selection = json.loads((mods / 'mod-list.json').read_text(encoding='utf-8'))
    selection['mods'].append({'name': helper.name, 'enabled': True})
    (mods / 'mod-list.json').write_text(json.dumps(selection, indent=2), encoding='utf-8')


if __name__ == '__main__':
    main()
