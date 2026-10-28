"""Stage current flamethrower acceptance against the pinned full 2.1 core.

Uses stage_owner for the gameplay snapshot and records the private instrumentation.
The selected run must be new; no existing evidence or installed mods are replaced.
"""
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
    parser.add_argument('--mode', choices=('ordinary', 'transition', 'matrix'), default='ordinary')
    parser.add_argument('--disabled', action='store_true')
    args = parser.parse_args()
    root = Path(os.path.abspath(args.run))
    root.mkdir(parents=True, exist_ok=True)
    fixtures = Path('scripts/qc/flamethrower-fuels')
    exports = root / 'exports.json'
    exports.write_text(json.dumps({'flamethrower-fuels': (fixtures / 'performance-instrument.lua').read_text(encoding='utf-8')}, indent=2), encoding='utf-8')
    subprocess.run([sys.executable, '-B', 'scripts/qc/factorio-2.1/stage_owner.py', '--run', str(root),
                    '--bridge', str(fixtures / 'instrument.lua'), '--exports', str(exports)], check=True)
    mods = root / 'mods'
    helper = mods / 'zzz-esir-flamethrower-qc'
    helper.mkdir()
    for path in fixtures.iterdir():
        if path.is_file():
            shutil.copy2(path, helper / path.name)
    info = json.loads((helper / 'info.json').read_text(encoding='utf-8'))
    info['factorio_version'] = '2.1'
    (helper / 'info.json').write_text(json.dumps(info, indent=2), encoding='utf-8')
    boolean = lambda value: str(bool(value)).lower()
    (helper / 'test-config.lua').write_text(
        f'return {{enabled={boolean(not args.disabled)},budget=100,performance=0,'
        f'transition={boolean(args.mode == "transition")},matrix={boolean(args.mode == "matrix")},'
        'combat=false,effects=false,visual=false,overlap=false,profile="balanced"}\n', encoding='utf-8')
    owner = mods / 'exotic-space-industries-remembrance/scripts/control/flamethrower-fuels.lua'
    source = owner.read_text(encoding='utf-8')
    anchor = 'for index,connections in pairs(pipe_connections) do'
    assert source.count(anchor) == 1
    source = source.replace(anchor, 'assert(not storage.ei.flame_qc_fail,"injected-after-fluid-copy"); ' + anchor)
    owner.write_text(source, encoding='utf-8')
    selection = json.loads((mods / 'mod-list.json').read_text(encoding='utf-8'))
    selection['mods'].append({'name': info['name'], 'enabled': True})
    (mods / 'mod-list.json').write_text(json.dumps(selection, indent=2), encoding='utf-8')
    hashes = {str(path.relative_to(mods)): hashlib.sha256(path.read_bytes()).hexdigest()
              for path in [owner, *helper.glob('*.lua'), helper / 'info.json']}
    (root / 'fixture-manifest.json').write_text(json.dumps({'mode': args.mode,
        'enabled': not args.disabled, 'hashes': hashes}, indent=2), encoding='utf-8')
    print(json.dumps({'run': str(root), 'mode': args.mode, 'enabled': not args.disabled}))


if __name__ == '__main__':
    main()
