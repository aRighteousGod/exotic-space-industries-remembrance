"""Stage immutable fixture assets with long-path-safe hard links, without reparse points."""
import os
from pathlib import Path
import sys

repo, mods = (Path(value).resolve() for value in sys.argv[1:])
assert mods.is_relative_to(repo / '.factorio-qc' / 'managed')

def link(source, target):
    if os.name == 'nt':
        source = Path('\\\\?\\' + str(source))
        target = Path('\\\\?\\' + str(target))
    target.parent.mkdir(parents=True, exist_ok=True)
    if target.exists():
        assert os.path.samefile(source, target), f'Unexpected existing asset: {target}'
        return
    os.link(source, target)

for source in (repo / '.factorio-qc/fmqc/mods-live').glob('*.zip'):
    link(source, mods / source.name)
for pack in repo.glob('exotic-space-industries-remembrance-*'):
    if not pack.is_dir():
        continue
    for source in pack.rglob('*'):
        if source.is_file():
            link(source, mods / pack.name / source.relative_to(pack))
