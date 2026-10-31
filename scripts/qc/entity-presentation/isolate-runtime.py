"""Disable only staged mod controls for scenes that load no mod runtime scripts."""
import json
import argparse
import hashlib
import os
import sys
import time
import zipfile
from pathlib import Path

# The store resolves each writable pack to its private physical tree. A D:
# view may junction an owned C: backing; authoritative source links stay read-only.
repo = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(repo / 'scripts'))
from esir_qc_storage import dispatch, plain

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('mods', type=Path)
parser.add_argument('--run-id', required=True)
parser.add_argument('--repo', type=Path, default=repo)
args = parser.parse_args()
repo = args.repo
mods = plain(args.mods)
run = dispatch(repo, 'inspect', {'run_id': args.run_id})
assert mods == Path(run['mod_view_root']) and run['source_mode'] == 'private-mutable' and not run['closed'], 'Expected this managed private view'
dispatch(repo, 'validate', {'run_id': args.run_id})
mutable = dispatch(repo, 'mutable-sources', {'run_id': args.run_id})['names']
assert (mods / "zzz-esir-entity-presentation-qc" / "info.json").is_file(), "Only staged presentation fixtures may be isolated"
disabled = []
variants = []
for path in mods.iterdir():
    if path.name == "zzz-esir-entity-presentation-qc":
        continue
    if path.is_dir():
        if (path / "control.lua").exists():
            assert path.name in mutable, "Refusing to isolate an undeclared or read-only source"
            control = plain(Path(mutable[path.name]) / "control.lua")
            assert control.stat().st_nlink == 1, "Mutable control must be private"
            control.write_text("-- Isolated for native presentation QC.\n", encoding="utf-8")
            disabled.append(path.name)
    elif path.suffix == ".zip":
        with path.open('rb') as stream:
            before = hashlib.file_digest(stream, 'sha256').hexdigest()
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
        with path.open('rb') as stream:
            variants.append({'file': path.name, 'original_sha256': before, 'variant_sha256': hashlib.file_digest(stream, 'sha256').hexdigest(), 'operation': 'private control isolation'})
dispatch(repo, 'validate', {'run_id': args.run_id})
print(json.dumps({"runtime_controls_isolated": disabled, 'archive_variants': variants}))
