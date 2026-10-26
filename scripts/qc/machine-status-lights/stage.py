"""Copy a private dependency seed; hardlink only immutable assets and archives."""
import os
import shutil
import sys
import zipfile
from pathlib import Path

source, target = (Path(p).resolve() for p in sys.argv[1:])
boundary = Path(__file__).resolve().parents[3] / '.factorio-qc'
assert source.is_relative_to(boundary) and target.is_relative_to(boundary)
assert source.is_dir() and not target.exists()
assert not target.is_relative_to(source)
for directory, dirs, files in os.walk(source):
    base = Path(directory)
    assert not base.is_symlink() and not base.is_junction(), base
    relative = base.relative_to(source)
    output = target / relative
    output.mkdir(parents=True)
    for name in files:
        src, dst = base / name, output / name
        assert not src.is_symlink(), src
        # Main-pack refresh and fixture control isolation must never write links.
        readonly = src.suffix.lower() in {'.png', '.ogg', '.zip'} and 'exotic-space-industries-remembrance' not in relative.parts
        if readonly and src.suffix.lower() == '.zip':
            with zipfile.ZipFile(src) as archive:
                readonly = not any(n.count('/') == 1 and n.endswith('/control.lua') for n in archive.namelist())
        if readonly:
            os.link(src, dst)
        else:
            shutil.copy2(src, dst)
print('Copied private seed; immutable assets shared read-only:', target)
