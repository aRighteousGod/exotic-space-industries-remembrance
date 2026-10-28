"""Stage the minimal engine-only generator migration reproducer."""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--run',required=True)
    parser.add_argument('--version',choices=('2.0','2.1'),required=True)
    parser.add_argument('--seed',action='store_true')
    parser.add_argument('--mode',choices=('donor','migration','prepare'))
    args=parser.parse_args()
    root=Path(os.path.abspath(args.run))
    helper=root/'mods/zzz-native-generator-qc'
    helper.mkdir(parents=True,exist_ok=True)
    source=Path(__file__).parent
    for suffix,target in [('data','data.lua'),('control','control.lua')]:
        shutil.copy2(source/('native-generator-'+suffix+'.lua'),helper/target)
    mode=args.mode or ('donor' if args.version=='2.0' else 'migration')
    (helper/'test-config.lua').write_text('return '+json.dumps(mode)+'\n',encoding='utf-8')
    (helper/'info.json').write_text(json.dumps({'name':helper.name,'version':'0.0.1',
        'title':'Private native generator migration reproduction','author':'ESIR QC',
        'factorio_version':args.version,'dependencies':['base']}),encoding='utf-8')
    # Explicitly omit all expansion and ESIR packs: only Base and this reproducer.
    selection=[{'name':name,'enabled':name in ('base',helper.name)}
        for name in ['base','space-age','quality','recycler','elevated-rails',helper.name]]
    (root/'mods/mod-list.json').write_text(json.dumps({'mods':selection}),encoding='utf-8')
    engine=Path('C:/Program Files (x86)/Steam/steamapps/common/Factorio') if args.version=='2.0' else Path('.factorio-qc/f21').absolute()
    (root/'config.ini').write_text(f'[path]\nread-data={engine / "data"}\nwrite-data={root}\n[other]\ncheck-updates=false\n',encoding='utf-8')
    if args.seed:
        with (root/'seed.create.log').open('w',encoding='utf-8') as log:
            subprocess.run([str(engine/'bin/x64/factorio.exe'),'--config',str(root/'config.ini'),
                '--mod-directory',str(root/'mods'),'--disable-audio','--create',str(root/'seed.zip')],
                stdout=log,stderr=subprocess.STDOUT,creationflags=subprocess.CREATE_NO_WINDOW,check=True,timeout=120)


if __name__=='__main__': main()
