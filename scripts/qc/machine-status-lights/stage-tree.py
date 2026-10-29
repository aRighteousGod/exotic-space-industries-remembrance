"""Private QC tree copy; share immutable media without duplicating large packs."""
import os
import shutil
import sys
from pathlib import Path

source, target = (Path(p).absolute() for p in sys.argv[1:])
repo = Path(__file__).resolve().parents[3]
assert target.is_relative_to(repo / '.factorio-qc')
assert source != target and not target.is_relative_to(source)
for base, directories, files in os.walk(source):
    base = Path(base)
    assert not base.is_symlink() and not base.is_junction(), base
    directories[:] = [d for d in directories if d not in {'.git', '.qc', '__pycache__'}]
    output = target / base.relative_to(source)
    output.mkdir(parents=True, exist_ok=True)
    for name in files:
        src, dst = base / name, output / name
        assert not src.is_symlink() and not dst.is_symlink()
        assert not dst.exists(), dst
        if src.suffix.lower() in {'.png', '.ogg', '.wav'}:
            os.link(src, dst)
        else:
            shutil.copy2(src, dst)
