"""Stage populated turbine custody across exact 2.0, 2.1 and second reload."""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--run',required=True)
    parser.add_argument('--version',choices=('2.0','2.1'),required=True)
    parser.add_argument('--mode',choices=('donor','migration','reload'),required=True)
    parser.add_argument('--refresh',action='store_true')
    parser.add_argument('--seed',action='store_true')
    args=parser.parse_args()
    root=Path(os.path.abspath(args.run))
    fixtures=Path(__file__).parent
    if not args.refresh:
        subprocess.run([sys.executable,'-B',str(fixtures/'stage_owner.py'),'--run',str(root),
            '--version',args.version,'--source','.factorio-qc/m20' if args.version=='2.0' else '.factorio-qc/21',
            '--bridge',str(fixtures/'turbine-bridge.lua')],check=True)
    helper=root/'mods/zzz-esir-turbine-migration-qc'
    helper.mkdir(exist_ok=args.refresh)
    shutil.copy2(fixtures/'turbine-migration.lua',helper/'control.lua')
    (helper/'test-config.lua').write_text('return '+json.dumps(args.mode)+'\n',encoding='utf-8')
    (helper/'info.json').write_text(json.dumps({'name':helper.name,'version':'0.0.1','author':'ESIR QC',
        'title':'Private turbine migration','factorio_version':args.version,
        'dependencies':['exotic-space-industries-remembrance']},indent=2),encoding='utf-8')
    mod_list=root/'mods/mod-list.json'
    selection=json.loads(mod_list.read_text(encoding='utf-8'))
    if not any(row['name']==helper.name for row in selection['mods']):
        selection['mods'].append({'name':helper.name,'enabled':True})
    mod_list.write_text(json.dumps(selection,indent=2),encoding='utf-8')
    if args.seed:
        engine=Path('C:/Program Files (x86)/Steam/steamapps/common/Factorio/bin/x64/factorio.exe') if args.version=='2.0' else Path('.factorio-qc/f21/bin/x64/factorio.exe').absolute()
        with (root/'seed.create.log').open('w',encoding='utf-8') as log:
            subprocess.run([str(engine),'--config',str(root/'config.ini'),'--mod-directory',str(root/'mods'),
                '--disable-audio','--create',str(root/'seed.zip')],stdout=log,stderr=subprocess.STDOUT,
                creationflags=subprocess.CREATE_NO_WINDOW,check=True,timeout=180)


if __name__=='__main__':
    main()
