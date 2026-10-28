"""Stage paired native solar-consumer boundary tests without changing its prototype."""
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
    bridge.write_text('-- The separate private helper owns this fixture.\n', encoding='utf-8')
    subprocess.run([sys.executable, '-B', 'scripts/qc/factorio-2.1/stage_owner.py',
        '--run', str(root), '--version', args.version, '--bridge', str(bridge),
        '--source', '.factorio-qc/m20' if args.version == '2.0' else '.factorio-qc/21'], check=True)
    mods = root / 'mods'
    helper = mods / 'zzz-esir-solar-boundary-qc'
    helper.mkdir()
    shutil.copy2(Path(__file__).with_name('solar-boundary.lua'), helper / 'control.lua')
    info = {'name': helper.name, 'version': '0.0.1', 'title': 'Private solar temperature acceptance',
            'author': 'ESIR QC', 'factorio_version': args.version,
            'dependencies': ['exotic-space-industries-remembrance']}
    (helper / 'info.json').write_text(json.dumps(info, indent=2), encoding='utf-8')
    selection = json.loads((mods / 'mod-list.json').read_text(encoding='utf-8'))
    selection['mods'].append({'name': helper.name, 'enabled': True})
    (mods / 'mod-list.json').write_text(json.dumps(selection, indent=2), encoding='utf-8')


if __name__ == '__main__':
    main()
