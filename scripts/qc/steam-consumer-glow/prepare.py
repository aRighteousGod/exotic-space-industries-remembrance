"""Stage live source privately; baseline removes only the six new light fields."""
import argparse
import filecmp
import json
import os
from pathlib import Path
import shutil
import zipfile

parser = argparse.ArgumentParser()
parser.add_argument('run', type=Path)
parser.add_argument('mode', choices=('baseline', 'on', 'off'))
parser.add_argument('--seed', type=Path)
parser.add_argument('--visual', action='store_true')
args = parser.parse_args()
repo = Path(__file__).resolve().parents[3]
run = args.run.resolve()
assert run.is_relative_to(repo / '.factorio-qc') and run.is_dir()
mods = run / 'm'
if args.seed:
    seed = args.seed.resolve()
    assert seed.is_relative_to(repo / '.factorio-qc') and seed != mods
    # Extended paths avoid legacy CopyFile2 limits in deeply nested mod assets.
    for directory, dirs, files in os.walk(seed):
        base = Path(directory)
        assert not base.is_junction() and not base.is_symlink(), base
        relative = base.relative_to(seed)
        output = mods / relative
        output.mkdir(parents=True, exist_ok=True)
        for name in files:
            src, dst = base / name, output / name
            if dst.exists():
                continue
            source_path, target_path = '\\\\?\\' + str(src), '\\\\?\\' + str(dst)
            readonly = src.suffix.lower() in {'.png', '.ogg', '.zip'} and 'exotic-space-industries-remembrance' not in relative.parts
            if readonly and src.suffix.lower() == '.zip':
                with zipfile.ZipFile(source_path) as archive:
                    readonly = not any(n.count('/') == 1 and n.endswith('/control.lua') for n in archive.namelist())
            if readonly:
                os.link(source_path, target_path)
            else:
                shutil.copy2(source_path, target_path)
assert not mods.is_junction() and not mods.is_symlink()

def copy_changed(source, target):
    if not Path(target).exists() or not filecmp.cmp(source, target, shallow=False):
        assert not Path(target).exists() or Path(target).stat().st_nlink == 1, target
        shutil.copy2(source, target)
    return str(target)

main = mods / 'exotic-space-industries-remembrance'
shutil.copytree(repo / main.name, main, dirs_exist_ok=True, copy_function=copy_changed)
changed = {'prototypes/steam-age/steam-miner.lua': 2,
           'prototypes/steam-age/steam-surface-harvester.lua': 1,
           'prototypes/steam-age/steam-assembler.lua': 1,
           'prototypes/steam-age/steam-crusher.lua': 1,
           'prototypes/loaders.lua': 1}
if args.mode == 'baseline':
    for relative, count in changed.items():
        path = main / relative
        source = path.read_text(encoding='utf-8-sig')
        lines = source.splitlines(keepends=True)
        removed = [line for line in lines if 'light_flicker = {minimum_intensity = 0, maximum_intensity = 0},' in line]
        assert len(removed) == count, relative
        path.write_text(''.join(line for line in lines if line not in removed), encoding='utf-8')

helper = mods / 'zzz-esir-steam-glow-qc'
helper.mkdir(exist_ok=True)
for path in Path(__file__).parent.glob('*.lua'):
    shutil.copy2(path, helper / path.name)
(helper / 'test-config.lua').write_text(
    f'return {{mode="{args.mode}", visual={str(args.visual).lower()}}}\n', encoding='utf-8')
listing = json.loads((mods / 'mod-list.json').read_text(encoding='utf-8-sig'))
for mod in listing['mods']:
    if 'qc' in mod['name'] or 'benchmark' in mod['name']:
        mod['enabled'] = False
listing['mods'] = [m for m in listing['mods'] if m['name'] != helper.name]
listing['mods'].append({'name': helper.name, 'enabled': True})
(mods / 'mod-list.json').write_text(json.dumps(listing), encoding='utf-8')
(helper / 'info.json').write_text(json.dumps({'name': helper.name, 'version': '0.0.1',
    'title': 'ESIR steam glow acceptance fixture', 'author': 'ESIR QC', 'factorio_version': '2.0',
    'dependencies': [m['name'] for m in listing['mods'] if m['enabled'] and m['name'] != helper.name]}), encoding='utf-8')
# Defaults must determine this fixture's startup settings on every profile run.
(mods / 'mod-settings.dat').unlink(missing_ok=True)
marker = b'-- Isolated native steam glow fixture.\n'
for path in mods.iterdir():
    if path == helper:
        continue
    if path.is_dir():
        assert not path.is_junction() and not path.is_symlink(), path
        control = path / 'control.lua'
        if control.exists():
            assert control.stat().st_nlink == 1, control
            control.write_bytes(marker)
    elif path.suffix == '.zip':
        with zipfile.ZipFile(path) as archive:
            controls = [n for n in archive.namelist() if n.count('/') == 1 and n.endswith('/control.lua')]
            if not controls or all(archive.read(n) == marker for n in controls):
                continue
            assert path.stat().st_nlink == 1, path
            temporary = path.with_suffix('.isolated')
            with zipfile.ZipFile(temporary, 'w') as target:
                for member in archive.infolist():
                    target.writestr(member, marker if member.filename in controls else archive.read(member))
        os.replace(temporary, path)
(run / 'config.ini').write_text(f'[path]\nwrite-data={run.as_posix()}\n[other]\ncheck-updates=false\n'
    '[graphics]\nfull-screen=false\nhalt-rendering-when-minimized=false\nmax-sprite-loading-threads=2\n'
    'screenshots-threads-count=2\ncache-sprite-atlas=false\nvideo-memory-usage=low\n'
    'texture-compression-level=high-quality\n', encoding='utf-8')
print('Prepared', args.mode, 'visual=' + str(args.visual), run)
