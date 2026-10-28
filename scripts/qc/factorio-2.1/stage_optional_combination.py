"""Stage a bounded optional combination over the tested release archives."""
import argparse
import json
import os
from pathlib import Path
import re
import shutil

from run_optional_smokes import digest, HERE

p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--run',type=Path,required=True)
p.add_argument('--core',type=Path,required=True)
p.add_argument('--packages',type=Path,required=True)
p.add_argument('--roots',nargs='+',required=True)
a=p.parse_args()
root=a.run.absolute();mods=root/'mods';mods.mkdir(parents=True,exist_ok=False)
packages={r['name']:r for r in json.loads((a.packages/'package-lock.json').read_text())}
resolution=json.loads((a.packages/'resolution.json').read_text())
needed=set();queue=list(a.roots)
while queue:
    name=queue.pop()
    if name in needed:continue
    needed.add(name)
    queue.extend(e['name'] for e in resolution['required_edges'] if e['from']==name and e['name'] in packages)
selection=json.loads((a.core/'release-selection.json').read_text())
rows=selection['packages']
names={r['name'] for r in rows}|needed|{'base','quality','space-age','elevated-rails','recycler'}
for name in needed:
    package=packages[name]
    for dependency in package['info'].get('dependencies',[]):
        conflict=re.match(r'\s*!\s*([^ <=>]+)',dependency)
        assert not conflict or conflict[1] not in names,(name,dependency)
    assert name not in {r['name'] for r in rows},'Do not silently replace a tested core dependency'
    rows.append(dict(name=name,version=package['version'],source=package['absolute_file'],sha256=package['sha256'],candidate=False))
for row in rows:
    source=Path(row['source'])
    assert digest(source)==row['sha256']
    target=mods/source.name
    try:os.link(source,target)
    except OSError as error:
        if error.errno!=18 and getattr(error,'winerror',None)!=17:raise
        shutil.copy2(source,target)
    row['staged']=str(target)
fixture=mods/'esir-qc-optional-smoke';fixture.mkdir()
for path in (HERE/'optional-smoke').glob('*.lua'):shutil.copy2(path,fixture/path.name)
(fixture/'info.json').write_text(json.dumps(dict(name=fixture.name,version='1.0.0',factorio_version='2.1',
    title='ESIR optional combination QC',author='ESIR QC',dependencies=['exotic-space-industries-remembrance',*a.roots])),encoding='utf-8')
names.add(fixture.name)
(mods/'mod-list.json').write_text(json.dumps({'mods':[dict(name=n,enabled=True) for n in sorted(names)]}),encoding='utf-8')
if (a.core/'mods/mod-settings.dat').exists():shutil.copy2(a.core/'mods/mod-settings.dat',mods/'mod-settings.dat')
engine=Path('.factorio-qc/f21').absolute()
(root/'config.ini').write_text(f'[path]\nread-data={engine / "data"}\nwrite-data={root}\n[other]\ncheck-updates=false\n',encoding='utf-8')
(root/'release-selection.json').write_text(json.dumps(dict(packages=rows,source_overlays=False,private_fixture=fixture.name,
    optional_roots=a.roots,required_closure=sorted(needed)),indent=2),encoding='utf-8')
print(json.dumps(dict(roots=len(a.roots),closure=len(needed),archives=len(rows))))
