"""Isolate copied fixture controls; never change a source mod or hardlinked file."""
import json
import argparse
import hashlib
import os
import sys
import zipfile
from pathlib import Path

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
assert (mods / "zzz-esir-machine-lights-qc" / "info.json").is_file()
disabled = []
variants = []
for path in mods.iterdir():
    if path.name == "zzz-esir-machine-lights-qc":
        continue
    if path.is_dir():
        if (path / "control.lua").exists():
            assert path.name in mutable, "Refusing to isolate an undeclared or read-only source"
            control = plain(Path(mutable[path.name]) / "control.lua")
            assert control.stat().st_nlink == 1, str(control)
            control.write_text("-- Isolated machine lighting acceptance fixture.\n", encoding="utf-8")
            disabled.append(path.name)
    elif path.suffix == ".zip":
        with path.open('rb') as stream:
            original_hash = hashlib.file_digest(stream, 'sha256').hexdigest()
        with zipfile.ZipFile(path) as source:
            controls = [n for n in source.namelist() if n.count("/") == 1 and n.endswith("/control.lua")]
            if not controls:
                continue
            if all(source.read(n) == b"-- Isolated machine lighting acceptance fixture.\n" for n in controls):
                disabled.append(path.name)
                continue
            # Write a new file, then replace only the view's directory entry.
            # The canonical archive remains immutable even when hardlinked.
            temporary = path.with_suffix(".isolated")
            with zipfile.ZipFile(temporary, "w") as target:
                for member in source.infolist():
                    target.writestr(member, b"-- Isolated machine lighting acceptance fixture.\n" if member.filename in controls else source.read(member))
        os.replace(temporary, path)
        disabled.append(path.name)
        with path.open('rb') as stream:
            variants.append({'file': path.name, 'original_sha256': original_hash, 'variant_sha256': hashlib.file_digest(stream, 'sha256').hexdigest(), 'operation': 'private control isolation'})
dispatch(repo, 'validate', {'run_id': args.run_id})
print(json.dumps({"isolated_runtime_controls": disabled, 'archive_variants': variants}))
