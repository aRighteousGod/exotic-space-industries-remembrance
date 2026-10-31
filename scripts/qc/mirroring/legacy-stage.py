"""Stage the user-supplied 2.0.77 engine with preserved, version-locked 1.3.41 mods."""
import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
import shutil
import subprocess
import sys
import zipfile

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[2]
sys.path.insert(0, str(REPO / "scripts"))
from esir_qc_storage import dispatch

parser = argparse.ArgumentParser()
parser.add_argument("record", type=Path)
parser.add_argument("current_record", type=Path)
parser.add_argument("download", type=Path)
args = parser.parse_args()
record = json.loads(args.record.read_text(encoding="utf-8-sig"))
current = json.loads(args.current_record.read_text(encoding="utf-8-sig"))
root = Path(record["scratch"])
assert root.is_dir() and record["repo"] == str(REPO)

def digest(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()

def extract(archive_path, destination, prefix):
    destination = Path("\\\\?\\" + str(destination.absolute()))
    destination.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(archive_path) as archive:
        for member in archive.infolist():
            if not member.filename.startswith(prefix) or member.is_dir():
                continue
            relative = PurePosixPath(member.filename[len(prefix):])
            assert not relative.is_absolute() and ".." not in relative.parts and "\\" not in member.filename
            target = destination.joinpath(*relative.parts)
            target.parent.mkdir(parents=True, exist_ok=True)
            with archive.open(member) as source, target.open("wb") as output:
                shutil.copyfileobj(source, output, 1024 * 1024)

archive_hash = digest(args.download)
engine_root = root / "engine-2.0.77"
engine_receipt = engine_root / "archive-sha256.txt"
if not engine_receipt.exists():
    with zipfile.ZipFile(args.download) as archive:
        info_path = next(n for n in archive.namelist() if n.endswith("/data/base/info.json"))
        assert json.loads(archive.read(info_path))["version"] == "2.0.77"
        prefix = info_path[:-len("data/base/info.json")]
    extract(args.download, engine_root, prefix)
    engine_receipt.write_text(archive_hash)
assert engine_receipt.read_text() == archive_hash
engine = engine_root / "bin/x64/factorio.exe"
version = subprocess.check_output([str(engine), "--version"], text=True)
assert "Version: 2.0.77 " in version
assert json.loads((engine_root / "data/base/info.json").read_text())["version"] == "2.0.77"
historical = REPO / ".factorio-qc/managed/0422e48554e14570806ee8e7c009f9a8/migration-native-20/donor-stage.json"
selection = json.loads(historical.read_text())
assert selection["engine"] == "2.0.77" and selection["main"] == "1.3.41"
main_name = "exotic-space-industries-remembrance"
packages = []
source = root / "historical-main"
for row in selection["packages"]:
    path = Path(record.get("package_paths", {}).get(row["name"], str(REPO / row["archive"])))
    assert path.is_file()
    if row["name"] == main_name:
        assert digest(path) == row["sha256"] and row["version"] == "1.3.41"
        with zipfile.ZipFile(path) as archive:
            info_path = next(n for n in archive.namelist() if n.count("/") == 1 and n.endswith("/info.json"))
            prefix = info_path.split("/")[0] + "/"
        if not (source / "info.json").exists():
            extract(path, source, prefix)
    else:
        packages.append({"path": str(path), "name": row["name"], "sha256": row["sha256"], "factorio_version": "2.0"})
mod_list = {"mods": [{"name": name, "enabled": True} for name in
    sorted({row["name"] for row in selection["packages"]} | {"base", "space-age", "quality", "elevated-rails", "esir-qc-mirroring-legacy"})]}
view = dispatch(REPO, "stage", {"run_id": record["run_id"], "packages": packages,
    "sources": [{"path": str(source), "name": main_name, "mode": "private-mutable"}], "mod_list": mod_list})
mods = Path(view["mod_view_root"])
helper = mods / "esir-qc-mirroring-legacy"
helper.mkdir(exist_ok=True)
shutil.copy2(HERE / "legacy-control.lua", helper / "control.lua")
(helper / "info.json").write_text(json.dumps({"name": helper.name, "version": "0.0.1", "factorio_version": "2.0",
    "title": "Historical mirroring fixture", "author": "ESIR QC", "dependencies": [main_name]}))
(helper / "legacy-config.lua").write_text('return {phase="donor"}\n')
native = json.loads((Path(current["write_data"]) / "script-output/mirroring/candidate-quality-enabled-reload.json").read_text())
cases = __import__("re").findall(r'"([^"]+)"', (HERE / "cases.lua").read_text())
cases += [row["name"] for row in native["entities"] if row["type"] in ("inserter", "mining-drill")]
assert len(cases) == len(set(cases)) == 44
(helper / "legacy-cases.lua").write_text("return {" + ",".join(json.dumps(n) for n in sorted(cases)) + "}\n")
recipes = {row["name"]: next((c["recipe"] for c in row["cases"] if c.get("recipe")), None) for row in native["entities"]}
(helper / "recipes.lua").write_text("return {" + ",".join(f'["{k}"]="{v}"' for k, v in recipes.items() if v) + "}\n")
write_data = root / "legacy-native"
write_data.mkdir(exist_ok=True)
config = write_data / "config.ini"
config.write_text(f"[path]\nread-data={engine_root / 'data'}\nwrite-data={write_data}\n[other]\ncheck-updates=false\n")
record.update(engine=str(engine), config=str(config), write_data=str(write_data), mods=str(mods),
              download=str(args.download), download_sha256=archive_hash, engine_version="2.0.77",
              source_version="1.3.41", source_selection=str(historical), cases=cases)
args.record.write_text(json.dumps(record, indent=2) + "\n")
print(json.dumps({"engine": "2.0.77", "source": "1.3.41", "prototypes": len(cases), "run_id": record["run_id"]}))
