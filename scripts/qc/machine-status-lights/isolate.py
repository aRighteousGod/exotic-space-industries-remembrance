"""Isolate copied fixture controls; never change a source mod or hardlinked file."""
import json
import os
import sys
import zipfile
from pathlib import Path

mods = Path(sys.argv[1]).resolve()
repo = Path(__file__).resolve().parents[3]
mods.relative_to((repo / ".factorio-qc").resolve())
assert (mods / "zzz-esir-machine-lights-qc" / "info.json").is_file()
disabled = []
for path in mods.iterdir():
    if path.name == "zzz-esir-machine-lights-qc":
        continue
    if path.is_dir():
        assert not path.is_symlink() and not path.is_junction(), str(path)
        control = path / "control.lua"
        if control.exists():
            assert control.stat().st_nlink == 1, str(control)
            control.write_text("-- Isolated machine lighting acceptance fixture.\n", encoding="utf-8")
            disabled.append(path.name)
    elif path.suffix == ".zip":
        with zipfile.ZipFile(path) as source:
            controls = [n for n in source.namelist() if n.count("/") == 1 and n.endswith("/control.lua")]
            if not controls:
                continue
            if all(source.read(n) == b"-- Isolated machine lighting acceptance fixture.\n" for n in controls):
                disabled.append(path.name)
                continue
            assert path.stat().st_nlink == 1, str(path)
            temporary = path.with_suffix(".isolated")
            with zipfile.ZipFile(temporary, "w") as target:
                for member in source.infolist():
                    target.writestr(member, b"-- Isolated machine lighting acceptance fixture.\n" if member.filename in controls else source.read(member))
        os.replace(temporary, path)
        disabled.append(path.name)
print(json.dumps({"isolated_runtime_controls": disabled}))
