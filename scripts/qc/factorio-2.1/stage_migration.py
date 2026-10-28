"""Stage the exact required 2.0 core for a populated, isolated migration donor.

Only required dependencies are followed. Historical optional-content saves are
never loaded with reduced dependencies. Main Lua is a private extracted copy so
fixture hooks cannot touch the shipping checkout or the preserved archive.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import zipfile

from build_audit_ledgers import parse_dependency

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[2]
MAIN = "exotic-space-industries-remembrance"
BUILTINS = {"base", "space-age", "quality", "elevated-rails"}


def digest(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def stage_target(root):
    mods = root / "mods"
    profile = json.loads((REPO / ".codex/esir/factorio-development.json").read_text(encoding="utf-8"))
    seed = REPO / profile["dependency_seed"]
    for source in seed.iterdir():
        if source.suffix == ".zip":
            shutil.copy2(source, mods / source.name)
    sources = [p for p in REPO.iterdir() if p.is_dir() and (p.name.startswith(MAIN) or p.name in ("doeworks-deer-continued", "enhanced-walls-continued")) and (p / "info.json").is_file()]
    sources.append(REPO / profile["nsbc_source"])
    hashes = {}
    for source in sources:
        info = json.loads((source / "info.json").read_text(encoding="utf-8-sig"))
        destination = mods / info["name"]
        assert not destination.exists(), "Use a fresh target stage"
        if info["name"] == MAIN:
            shutil.copytree(source, destination)
            hashes = {str(p.relative_to(source)): digest(p) for p in source.rglob("*.lua")}
            with (destination / "control.lua").open("a", encoding="utf-8") as stream:
                stream.write("\n-- Private migration fixture hooks; never packaged.\n")
                stream.write((HERE / "migration/private-hooks.lua").read_text(encoding="utf-8"))
        else:
            environment = os.environ.copy()
            environment.update(ESIR_QC_LINK=str(destination), ESIR_QC_SOURCE=str(source.resolve()))
            subprocess.run(["powershell", "-NoProfile", "-Command",
                "New-Item -ItemType Junction -Path $env:ESIR_QC_LINK -Target $env:ESIR_QC_SOURCE | Out-Null"],
                env=environment, check=True)
    fixture = mods / "esir-qc-core-migration"
    fixture.mkdir()
    shutil.copy2(HERE / "migration/control.lua", fixture / "control.lua")
    (fixture / "info.json").write_text(json.dumps({"name": fixture.name, "version": "1.0.1", "factorio_version": "2.1",
        "title": "ESIR populated core migration fixture", "author": "ESIR QC", "dependencies": [MAIN]}), encoding="utf-8")
    mod_list = json.loads((seed / "mod-list.json").read_text(encoding="utf-8"))
    mod_list["mods"].append({"name": fixture.name, "enabled": True})
    (mods / "mod-list.json").write_text(json.dumps(mod_list), encoding="utf-8")
    engine = REPO / ".factorio-qc/engine-2.1.23"
    (root / "config.ini").write_text("[path]\nread-data=" + str(engine / "data") + "\nwrite-data=" + str(root) + "\n[other]\ncheck-updates=false\n", encoding="utf-8")
    (root / "target-stage.json").write_text(json.dumps({"engine": "2.1.23", "source_hashes": hashes, "private_main_hook": True}, indent=2), encoding="utf-8")
    print(json.dumps({"staged": str(root), "engine": "2.1.23", "source_files": len(hashes)}))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--run", required=True)
    parser.add_argument("--baseline", type=Path, required=True)
    parser.add_argument("--target21", action="store_true")
    args = parser.parse_args()
    root = Path(os.path.abspath(args.run))
    mods = root / "mods"
    mods.mkdir(parents=True, exist_ok=True)
    if args.target21:
        stage_target(root)
        return
    engine = Path("C:/Program Files (x86)/Steam/steamapps/common/Factorio")
    available = {}
    for archive in (args.baseline / "mods").glob("*.zip"):
        with zipfile.ZipFile(archive) as source:
            info_path = next(n for n in source.namelist() if n.endswith("/info.json") and n.count("/") == 1)
            info = json.loads(source.read(info_path))
            assert info["name"] not in available, "Ambiguous baseline selection"
            available[info["name"]] = (archive, info, info_path.split("/")[0])
    needed, queue = set(), [MAIN, *BUILTINS]
    while queue:
        name = queue.pop()
        if name in needed:
            continue
        needed.add(name)
        if name in BUILTINS:
            info = json.loads((engine / "data" / name / "info.json").read_text(encoding="utf-8"))
        else:
            assert name in available, "Missing required preserved dependency: " + name
            info = available[name][1]
        for value in info.get("dependencies", ["base"]):
            dependency = parse_dependency(value)
            if dependency["prefix"] in (None, "~"):
                queue.append(dependency["name"])
    assert len(needed - BUILTINS) == 35, sorted(needed)
    receipts = []
    for name in sorted(needed - BUILTINS):
        archive, info, prefix = available[name]
        assert info["factorio_version"] == "2.0", name
        if name == MAIN:
            target = mods / name
            if target.exists():
                raise RuntimeError("Use a fresh donor stage; main source is already present")
            target.mkdir()
            with zipfile.ZipFile(archive) as source:
                for member in source.infolist():
                    if member.is_dir():
                        continue
                    relative = Path(member.filename).relative_to(prefix)
                    assert not relative.is_absolute() and ".." not in relative.parts
                    destination = target / relative
                    destination.parent.mkdir(parents=True, exist_ok=True)
                    destination.write_bytes(source.read(member))
            with (target / "control.lua").open("a", encoding="utf-8") as stream:
                stream.write("\n-- Private migration fixture hooks; never packaged.\n")
                stream.write((HERE / "migration/private-hooks.lua").read_text(encoding="utf-8"))
        else:
            shutil.copy2(archive, mods / archive.name)
        receipts.append({"name": name, "version": info["version"], "sha256": digest(archive), "archive": str(archive)})
    fixture = mods / "esir-qc-core-migration"
    fixture.mkdir()
    shutil.copy2(HERE / "migration/control.lua", fixture / "control.lua")
    (fixture / "info.json").write_text(json.dumps({"name": fixture.name, "version": "1.0.0", "factorio_version": "2.0",
        "title": "ESIR populated core migration fixture", "author": "ESIR QC", "dependencies": [MAIN]}), encoding="utf-8")
    (mods / "mod-list.json").write_text(json.dumps({"mods": [{"name": n, "enabled": True} for n in sorted(needed | {fixture.name})]}), encoding="utf-8")
    (root / "config.ini").write_text("[path]\nread-data=" + str(engine / "data") + "\nwrite-data=" + str(root) + "\n[other]\ncheck-updates=false\n", encoding="utf-8")
    receipt = {"engine": "2.0.77", "main": "1.3.41", "packages": receipts, "builtins": sorted(BUILTINS),
        "settings": "core defaults", "private_main_hook": True, "historical_optional_saves_loaded": False}
    (root / "donor-stage.json").write_text(json.dumps(receipt, indent=2), encoding="utf-8")
    print(json.dumps({"staged": str(root), "packages": len(receipts), "core_mods": len(needed)}))


if __name__ == "__main__":
    main()
