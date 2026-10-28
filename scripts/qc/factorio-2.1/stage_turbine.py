"""Stage native combustion-turbine state tests with private creation-failure injection."""
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
    args = parser.parse_args()
    root = Path(os.path.abspath(args.run))
    fixtures = Path(__file__).parent
    if not args.refresh:
        subprocess.run([sys.executable, '-B', str(fixtures / 'stage_owner.py'),
            '--run', str(root), '--bridge', str(fixtures / 'turbine-bridge.lua')], check=True)
    mods = root / 'mods'
    owner = mods / 'exotic-space-industries-remembrance/scripts/control/combustion-turbine.lua'
    if args.refresh:
        shutil.copy2('exotic-space-industries-remembrance/scripts/control/combustion-turbine.lua', owner)
        main_control = mods / 'exotic-space-industries-remembrance/control.lua'
        shutil.copy2('exotic-space-industries-remembrance/control.lua', main_control)
        with main_control.open('a', encoding='utf-8') as stream:
            stream.write('\n-- Private acceptance fixture; not shipping.\n'+
                (fixtures / 'turbine-bridge.lua').read_text(encoding='utf-8'))
    source_hash = hashlib.sha256(owner.read_bytes()).hexdigest()
    contents = owner.read_text(encoding='utf-8')
    signature = 'local function create_turbine_shell(surface, name, position, force, direction, quality)\n'
    assert contents.count(signature) == 1
    contents = contents.replace(signature, signature +
        '    if (storage.ei.qc_turbine_failures or 0)>0 then\n'
        '        storage.ei.qc_turbine_failures=storage.ei.qc_turbine_failures-1\n'
        '        return nil\n    end\n')
    owner.write_text(contents, encoding='utf-8')
    helper = mods / 'zzz-esir-turbine-qc'
    helper.mkdir(exist_ok=args.refresh)
    shutil.copy2(fixtures / 'turbine-runtime.lua', helper / 'control.lua')
    (helper / 'info.json').write_text(json.dumps({'name':helper.name, 'version':'0.0.1',
        'title':'Private ESIR turbine acceptance', 'author':'ESIR QC', 'factorio_version':'2.1',
        'dependencies':['exotic-space-industries-remembrance']},indent=2),encoding='utf-8')
    selection = json.loads((mods / 'mod-list.json').read_text(encoding='utf-8'))
    if not any(row['name']==helper.name for row in selection['mods']):
        selection['mods'].append({'name':helper.name,'enabled':True})
    (mods / 'mod-list.json').write_text(json.dumps(selection,indent=2),encoding='utf-8')
    (root / 'injection.json').write_text(json.dumps({'source_sha256':source_hash,
        'owner_sha256':hashlib.sha256(owner.read_bytes()).hexdigest(),
        'injection':'Only create_turbine_shell is made to return nil for a requested number of calls.'},indent=2),encoding='utf-8')


if __name__ == '__main__':
    main()
