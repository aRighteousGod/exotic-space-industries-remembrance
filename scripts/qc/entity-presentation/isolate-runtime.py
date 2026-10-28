"""Disable only staged mod controls for scenes that load no mod runtime scripts."""
import json
import os
import sys
import time
import zipfile
from pathlib import Path

# Keep the short registered run alias: its payload may use the approved D:
# overflow volume. Individual mod source junctions are never writable here.
mods = Path(os.path.abspath(sys.argv[1]))
repo = Path(__file__).resolve().parents[3]
mods.relative_to(repo / ".factorio-qc")
assert (mods / "zzz-esir-entity-presentation-qc" / "info.json").is_file(), "Only staged presentation fixtures may be isolated"
disabled = []
for path in mods.iterdir():
    if path.name == "zzz-esir-entity-presentation-qc":
        continue
    if path.is_dir():
        control = path / "control.lua"
        if control.exists():
            assert not path.is_junction() and not path.is_symlink() and not control.is_symlink(), "Refusing to isolate source through a mod link"
            control.write_text("-- Isolated for native presentation QC.\n", encoding="utf-8")
            disabled.append(path.name)
    elif path.suffix == ".zip":
        with zipfile.ZipFile(path) as source:
            controls = [name for name in source.namelist() if name.count("/") == 1 and name.endswith("/control.lua")]
            if not controls:
                continue
            temporary = path.with_suffix(".isolated")
            with zipfile.ZipFile(temporary, "w") as target:
                for member in source.infolist():
                    target.writestr(member, b"-- Isolated for native presentation QC.\n" if member.filename in controls else source.read(member))
        # Windows indexers/virus scanners can briefly deny replacing a ZIP
        # immediately after it was copied/read. Retry only this private file.
        for attempt in range(40):
            try:
                os.replace(temporary, path)
                break
            except PermissionError:
                if attempt == 39:
                    raise
                time.sleep(0.25)
        disabled.append(path.name)
print(json.dumps({"runtime_controls_isolated": disabled}))
