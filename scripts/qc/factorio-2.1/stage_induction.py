"""Replay the established induction suite on exact 2.1 with native checkpoints.

Only private staged copies are instrumented. The original 2.0 fixture remains
available, and source/fixture hashes identify this adaptation separately.
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
    parser.add_argument('--refresh', action='store_true')
    parser.add_argument('--configuration', action='store_true')
    parser.add_argument('--seed', action='store_true')
    args = parser.parse_args()
    root = Path(os.path.abspath(args.run))
    fixture = Path('scripts/qc/induction-circuit')
    bridge = Path(__file__).with_name('induction-bridge.lua')
    if not args.refresh:
        subprocess.run([sys.executable, '-B', str(Path(__file__).with_name('stage_owner.py')),
            '--run', str(root), '--bridge', str(bridge)], check=True)
    source = Path('exotic-space-industries-remembrance')
    main_root = root / 'mods/exotic-space-industries-remembrance'
    control = (source / 'control.lua').read_text(encoding='utf-8')
    for original, replacement in (
        ('script.on_configuration_changed(function(e)', '__control_ups_register_config(function(e)'),
        ('script.on_load(function()', '__control_ups_register_load(function()')):
        assert control.count(original) == 1, original
        control = control.replace(original, replacement)
    capture = ('function __control_ups_register_config(handler) __control_ups_config=handler; script.on_configuration_changed(handler) end\n'
        'function __control_ups_register_load(handler) __control_ups_load=handler; script.on_load(handler) end\n')
    (main_root / 'control.lua').write_text(capture + control + '\n' +
        (fixture / 'instrument.lua').read_text(encoding='utf-8') + '\n' + bridge.read_text(encoding='utf-8'), encoding='utf-8')
    helper = root / 'mods/zzz-esir-induction-circuit-qc'
    helper.mkdir(exist_ok=args.refresh)
    shutil.copy2(fixture / 'data-final-fixes.lua', helper / 'data-final-fixes.lua')
    (helper / 'control.lua').write_text('script.on_init(function() if remote.interfaces.freeplay then remote.call("freeplay","set_skip_intro",true) end end)\n', encoding='utf-8')
    (helper / 'info.json').write_text(json.dumps({'name': helper.name, 'version': '0.0.2' if args.configuration else '0.0.1',
        'author': 'ESIR QC', 'title': 'Private induction acceptance', 'factorio_version': '2.1',
        'dependencies': ['exotic-space-industries-remembrance']}, indent=2), encoding='utf-8')
    path = root / 'mods/mod-list.json'
    selection = json.loads(path.read_text(encoding='utf-8'))
    if not any(row['name'] == helper.name for row in selection['mods']):
        selection['mods'].append({'name': helper.name, 'enabled': True})
    path.write_text(json.dumps(selection, indent=2), encoding='utf-8')
    files = [fixture / 'instrument.lua', bridge, main_root / 'control.lua', *helper.glob('*.lua')]
    (root / 'induction-source.json').write_text(json.dumps({str(p): hashlib.sha256(p.read_bytes()).hexdigest()
        for p in files}, indent=2), encoding='utf-8')
    if args.seed:
        with (root / 'seed.create.log').open('w', encoding='utf-8') as log:
            subprocess.run([str(Path('.factorio-qc/f21/bin/x64/factorio.exe').absolute()), '--config', str(root / 'config.ini'),
                '--mod-directory', str(root / 'mods'), '--disable-audio', '--create', str(root / 'seed.zip')],
                stdout=log, stderr=subprocess.STDOUT, creationflags=subprocess.CREATE_NO_WINDOW, check=True, timeout=180)


if __name__ == '__main__':
    main()
