"""Stage the existing broad spider acceptance suite with explicit 2.1 API ports."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys


def port(text):
    # These fixture assignments disable target entities. Logistic section.active
    # is intentionally untouched; it is a different supported API.
    text = re.sub(r'\b((?:storage\.(?:smoke_enemy|smoke_friend|target))|(?:c\.(?:target|other))|(?:case\.target)|target)\.active\s*=\s*false',
        r'\1.disabled_by_script=true', text)
    return text.replace('game.create_profiler(', 'helpers.create_profiler(')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--run', required=True)
    parser.add_argument('--version', choices=('2.0','2.1'), default='2.1')
    parser.add_argument('--mode', choices=('full','overkill','dispatch','canonical','save','performance'), default='full')
    parser.add_argument('--native', action='store_true')
    parser.add_argument('--vehicles', type=int, choices=(100,500), default=100)
    parser.add_argument('--combat', action='store_true')
    parser.add_argument('--refresh', action='store_true')
    args = parser.parse_args()
    root = Path(os.path.abspath(args.run))
    fixture = Path('scripts/qc/spider-vehicles')
    if not args.refresh:
        subprocess.run([sys.executable, '-B', str(Path(__file__).with_name('stage_owner.py')), '--run', str(root),
            '--source', '.factorio-qc/m20' if args.version=='2.0' else '.factorio-qc/21',
            '--version', args.version, '--bridge', str(fixture / 'gui-instrument.lua')], check=True)
    source = Path('.factorio-qc/m20/mods/exotic-space-industries-remembrance') if args.version=='2.0' else Path('exotic-space-industries-remembrance')
    main_root = root / 'mods/exotic-space-industries-remembrance'
    control = (source / 'control.lua').read_text(encoding='utf-8') + '\n' + (fixture / 'gui-instrument.lua').read_text(encoding='utf-8')
    if args.version=='2.1': control=port(control)
    (main_root / 'control.lua').write_text(control, encoding='utf-8')
    relative = 'scripts/control/spider-vehicles.lua'
    owner = (source / relative).read_text(encoding='utf-8')
    instrument = (fixture / 'selector-instrument.lua').read_text(encoding='utf-8')
    if args.version=='2.1': instrument=port(instrument)
    owner,count=re.subn(r'return model\s*$',instrument+'\nreturn model\n',owner)
    assert count==1
    (main_root / relative).write_text(owner,encoding='utf-8')
    helper = root / 'mods/zzz-esir-spider-qc'
    helper.mkdir(exist_ok=args.refresh)
    for path in fixture.glob('*.lua'):
        contents=path.read_text(encoding='utf-8')
        (helper / path.name).write_text(port(contents) if args.version=='2.1' else contents,encoding='utf-8')
    config={'arachnophobia':False,'smart':not args.native,'performance':args.vehicles if args.mode=='performance' else 0,
        'combat':args.combat,'save_fixture':args.mode=='save','overkill':args.mode=='overkill',
        'rocket_performance':False,'dispatch':args.mode=='dispatch','canonical_items':args.mode=='canonical'}
    (helper / 'test-config.lua').write_text('return {'+','.join(k+'='+json.dumps(v) for k,v in config.items())+'}\n',encoding='utf-8')
    (helper / 'info.json').write_text(json.dumps({'name':helper.name,'version':'0.0.1','title':'Private spider upgrade acceptance',
        'author':'ESIR QC','factorio_version':args.version,'dependencies':['exotic-space-industries-remembrance']},indent=2),encoding='utf-8')
    path=root / 'mods/mod-list.json'
    selection=json.loads(path.read_text(encoding='utf-8'))
    if not any(row['name']==helper.name for row in selection['mods']):
        selection['mods'].append({'name':helper.name,'enabled':True})
    path.write_text(json.dumps(selection,indent=2),encoding='utf-8')
    files=[main_root / 'control.lua',main_root / relative,*helper.glob('*.lua')]
    (root / 'spider-source.json').write_text(json.dumps({'version':args.version,'config':config,
        'hashes':{str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in files}},indent=2),encoding='utf-8')


if __name__=='__main__':
    main()
