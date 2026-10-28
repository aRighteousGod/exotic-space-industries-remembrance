"""Stage an inspected existing helper on the pinned core without deployment."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--run',required=True)
    parser.add_argument('--fixture',type=Path,required=True)
    parser.add_argument('--bridge',type=Path)
    parser.add_argument('--options',type=Path)
    parser.add_argument('--refresh',action='store_true')
    parser.add_argument('--seed',action='store_true')
    args=parser.parse_args()
    root=Path(os.path.abspath(args.run))
    bridge=args.bridge or Path(__file__).with_name('fixture-bridge.lua')
    if not args.refresh:
        subprocess.run([sys.executable,'-B',str(Path(__file__).with_name('stage_owner.py')),
            '--run',str(root),'--bridge',str(bridge)],check=True)
    else:
        # Refresh only the private dispatcher bridge and helper, not all owners.
        source=Path('exotic-space-industries-remembrance/control.lua').read_text(encoding='utf-8')
        (root/'mods/exotic-space-industries-remembrance/control.lua').write_text(source+'\n'+bridge.read_text(encoding='utf-8'),encoding='utf-8')
    info=json.loads((args.fixture/'info.json').read_text(encoding='utf-8-sig'))
    info['factorio_version']='2.1'
    helper=root/'mods'/info['name']
    helper.mkdir(exist_ok=args.refresh)
    for path in args.fixture.rglob('*.lua'):
        destination=helper/path.relative_to(args.fixture)
        destination.parent.mkdir(exist_ok=True,parents=True)
        shutil.copy2(path,destination)
    if args.options:
        shutil.copy2(args.options,helper/'options.lua')
    (helper/'info.json').write_text(json.dumps(info,indent=2),encoding='utf-8')
    selection_path=root/'mods/mod-list.json'
    selection=json.loads(selection_path.read_text(encoding='utf-8'))
    if not any(row['name']==info['name'] for row in selection['mods']):
        selection['mods'].append({'name':info['name'],'enabled':True})
    selection_path.write_text(json.dumps(selection,indent=2),encoding='utf-8')
    (root/'fixture-source.json').write_text(json.dumps({'fixture':str(args.fixture),'bridge':str(bridge),
        'bridge_sha256':hashlib.sha256(bridge.read_bytes()).hexdigest(),
        'files':{str(p.relative_to(helper)):hashlib.sha256(p.read_bytes()).hexdigest() for p in helper.rglob('*') if p.is_file()}},indent=2),encoding='utf-8')
    if args.seed:
        with (root/'seed.create.log').open('w',encoding='utf-8') as log:
            subprocess.run([str(Path('.factorio-qc/f21/bin/x64/factorio.exe').absolute()),'--config',str(root/'config.ini'),
                '--mod-directory',str(root/'mods'),'--disable-audio','--create',str(root/'seed.zip')],
                stdout=log,stderr=subprocess.STDOUT,creationflags=subprocess.CREATE_NO_WINDOW,check=True,timeout=180)


if __name__=='__main__':
    main()
