"""Stage the minimal Base-only native car physics comparison."""
import argparse
import json
import os
from pathlib import Path
import shutil

p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--run',required=True)
p.add_argument('--version',choices=('2.0','2.1'),required=True)
a=p.parse_args()
root=Path(os.path.abspath(a.run));helper=root/'mods/zzz-native-car-qc'
helper.mkdir(parents=True,exist_ok=False)
for suffix in ('data','control'):
    shutil.copy2(Path(__file__).with_name('native-car-'+suffix+'.lua'),helper/(suffix+'.lua'))
(helper/'info.json').write_text(json.dumps(dict(name=helper.name,version='0.0.1',title='Private native car physics',author='ESIR QC',factorio_version=a.version,dependencies=['base'])),encoding='utf-8')
(root/'mods/mod-list.json').write_text(json.dumps(dict(mods=[dict(name=n,enabled=n in ('base',helper.name)) for n in ('base','quality','recycler','space-age','elevated-rails',helper.name)])),encoding='utf-8')
engine=Path('C:/Program Files (x86)/Steam/steamapps/common/Factorio') if a.version=='2.0' else Path('.factorio-qc/f21').absolute()
(root/'config.ini').write_text(f'[path]\nread-data={engine / "data"}\nwrite-data={root}\n[other]\ncheck-updates=false\n',encoding='utf-8')
