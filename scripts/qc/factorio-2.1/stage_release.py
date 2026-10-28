"""Stage the exact candidate ZIPs and required dependency ZIPs, with no source overlays."""
import argparse
import hashlib
import json
import os
import re
from pathlib import Path
import shutil
import zipfile


def identity(archive):
    with zipfile.ZipFile(archive) as package:
        paths=[n for n in package.namelist() if n.count('/')==1 and n.endswith('/info.json')]
        assert len(paths)==1, archive
        return json.loads(package.read(paths[0]))


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--run',required=True)
    parser.add_argument('--source',default='.factorio-qc/21')
    parser.add_argument('--packages',action='append',required=True)
    args=parser.parse_args()
    root=Path(os.path.abspath(args.run));source=Path(args.source)
    selection=json.loads((source/'mods/mod-list.json').read_text(encoding='utf-8'))
    selection['mods']=[r for r in selection['mods'] if not r['name'].startswith(('esir-qc-','zzz-esir-'))]
    enabled={r['name'] for r in selection['mods'] if r['enabled']}
    packages={}
    for archive in (source/'mods').glob('*.zip'):
        info=identity(archive)
        if info['name'] in enabled: packages[info['name']]=(archive,info)
    candidate_names=set()
    for folder in args.packages:
        for archive in Path(folder).glob('*.zip'):
            if not re.fullmatch(r'[A-Za-z0-9_-]+_\d+\.\d+\.\d+\.zip',archive.name): continue
            info=identity(archive)
            if info['name'] not in enabled: continue
            assert info['name'] not in candidate_names, 'Duplicate release candidate identity'
            candidate_names.add(info['name']);packages[info['name']]=(archive,info)
    native={'base','space-age','quality','recycler','elevated-rails'}
    assert enabled <= set(packages)|native, sorted(enabled-set(packages)-native)
    expected={'exotic-space-industries-remembrance','doeworks-deer-continued',
              'enhanced-walls-continued','zzz-nonstandard-beacons-continued'}
    expected|={f'exotic-space-industries-remembrance-graphics-{i}' for i in range(1,7)}
    expected|={f'exotic-space-industries-remembrance-soundtrack-{i}' for i in (1,2)}
    assert expected <= candidate_names, sorted(expected-candidate_names)
    mods=root/'mods';mods.mkdir(parents=True,exist_ok=False)
    rows=[]
    for name,(archive,info) in sorted(packages.items()):
        destination=mods/archive.name
        try: os.link(archive,destination)
        except OSError as error:
            if error.errno!=18 and getattr(error,'winerror',None) not in (5,17): raise
            shutil.copy2(archive,destination)
        with destination.open('rb') as stream: digest=hashlib.file_digest(stream,'sha256').hexdigest()
        rows.append(dict(name=name,version=info['version'],sha256=digest,source=str(archive.absolute()),
                         staged=str(destination),candidate=name in candidate_names))
    (mods/'mod-list.json').write_text(json.dumps(selection,indent=2),encoding='utf-8')
    settings=source/'mods/mod-settings.dat'
    if settings.exists(): shutil.copy2(settings,mods/settings.name)
    engine=Path('.factorio-qc/f21').absolute()
    (root/'config.ini').write_text(f'[path]\nread-data={engine / "data"}\nwrite-data={root}\n[other]\ncheck-updates=false\n',encoding='utf-8')
    (root/'release-selection.json').write_text(json.dumps(dict(packages=rows,source_overlays=False),indent=2),encoding='utf-8')
    print(json.dumps(dict(packages=len(rows),candidates=len(candidate_names),source_overlays=False)))


if __name__=='__main__':
    main()
