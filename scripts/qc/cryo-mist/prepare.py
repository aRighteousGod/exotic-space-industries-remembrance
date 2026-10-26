"""Refresh private QC sources; retain real Nonstandard Beacons control only."""
import json
import filecmp
import os
import shutil
import sys
import zipfile
from pathlib import Path
from PIL import Image

repo = Path(__file__).resolve().parents[3]
run = Path(sys.argv[1]).resolve()
run.relative_to((repo / '.factorio-qc').resolve())
mode = sys.argv[2]
mods = run / 'm'
assert mods.is_dir() and not mods.is_junction()
main = mods / 'exotic-space-industries-remembrance'
def copy_changed(source, target):
    if not Path(target).exists() or not filecmp.cmp(source, target, shallow=False):
        shutil.copy2(source, target)
    return str(target)
shutil.copytree(repo / main.name, main, dirs_exist_ok=True, copy_function=copy_changed)
if mode == 'baseline':
    assert (run / 'baseline/data-final-fixes.lua').is_file()
    shutil.copytree(run / 'baseline', main, dirs_exist_ok=True)
fixture = mods / 'zzz-esir-cryo-mist-qc'
fixture.mkdir(exist_ok=True)
Image.new('RGBA', (1024, 1024)).save(fixture / 'empty-atlas.png')
for p in Path(__file__).parent.iterdir():
    if p.suffix in {'.lua', '.json'}:
        shutil.copy2(p, fixture / p.name)
(fixture / 'test-config.lua').write_text(
    f'return {{mode="{mode}", visual={str(mode == "visual").lower()}}}\n', encoding='utf-8')
listing = json.loads((mods / 'mod-list.json').read_text(encoding='utf-8-sig'))
for m in listing['mods']:
    if 'qc' in m['name'] or 'benchmark' in m['name'] or m['name'] in {
        'extinguisher', 'minigun-turret-HD', 'minigun-turret-HD-graphics',
    }:
        m['enabled'] = False
listing['mods'] = [m for m in listing['mods'] if m['name'] != fixture.name]
listing['mods'].append({'name': fixture.name, 'enabled': True})
(mods / 'mod-list.json').write_text(json.dumps(listing), encoding='utf-8')
info = json.loads((fixture / 'info.json').read_text())
info['dependencies'] = [m['name'] for m in listing['mods'] if m['enabled'] and m['name'] != fixture.name]
(fixture / 'info.json').write_text(json.dumps(info), encoding='utf-8')
isolated = []
for p in mods.iterdir():
    if p.name == fixture.name or p.name.startswith('zzz-nonstandard-beacons'):
        continue
    if p.is_dir():
        assert not p.is_junction() and not p.is_symlink(), p
        control = p / 'control.lua'
        if control.exists():
            assert control.stat().st_nlink == 1
            control.write_text('-- Isolated cold mist native fixture.\n', encoding='utf-8')
            isolated.append(p.name)
    elif p.suffix == '.zip':
        with zipfile.ZipFile(p) as z:
            controls = [n for n in z.namelist() if n.count('/') == 1 and n.endswith('/control.lua')]
            if not controls:
                continue
            if all(z.read(n) == b'-- Isolated cold mist native fixture.\n' for n in controls):
                isolated.append(p.name)
                continue
            assert p.stat().st_nlink == 1, p
            temporary = p.with_suffix('.isolated')
            with zipfile.ZipFile(temporary, 'w') as target:
                for member in z.infolist():
                    target.writestr(member, b'-- Isolated cold mist native fixture.\n' if member.filename in controls else z.read(member))
        os.replace(temporary, p)
        isolated.append(p.name)
(run / 'isolation.json').write_text(json.dumps(isolated, indent=2), encoding='utf-8')
(run / 'config.ini').write_text(
    f'[path]\nwrite-data={run.as_posix()}\n[other]\ncheck-updates=false\n'
    '[graphics]\nfull-screen=false\nhalt-rendering-when-minimized=false\n'
    'max-sprite-loading-threads=1\nscreenshots-threads-count=2\ncache-sprite-atlas=false\n'
    'graphics-quality=high\nvideo-memory-usage=low\ntexture-compression-level=high-quality\n', encoding='utf-8')
print('Prepared', mode, run)
