"""Merge installed complete graphics-4 with current checkout overlays for GUI QC.

Keeping long sprite names inside a ZIP also avoids Windows extraction limits.
This produces only an isolated QC archive, never a shipping asset replacement.
"""
import os
import sys
from pathlib import Path
from zipfile import ZipFile, ZIP_STORED

repo=Path(sys.argv[1]).resolve()
target=Path(sys.argv[2]).resolve()
pack='exotic-space-industries-remembrance-graphics-4'
source=repo/pack
installed=Path(os.environ['APPDATA'])/'Factorio/mods'/f'{pack}_1.0.0.zip'
overlays={f'{pack}/{p.relative_to(source).as_posix()}':p for p in source.rglob('*') if p.is_file()}
with ZipFile(installed) as original, ZipFile(target,'w',compression=ZIP_STORED) as output:
    for item in original.infolist():
        if item.filename not in overlays and not item.is_dir():
            output.writestr(item.filename,original.read(item))
    for name,path in sorted(overlays.items()):output.write(path,name)
