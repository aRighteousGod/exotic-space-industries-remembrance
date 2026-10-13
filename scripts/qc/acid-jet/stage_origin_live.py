"""Copy only the active installed dependencies/settings into an isolated D: probe."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import zipfile

p = argparse.ArgumentParser()
p.add_argument("root", type=Path)
args = p.parse_args()
live = Path(os.environ["APPDATA"]) / "Factorio"
mods = live / "mods"
cached = Path("D:/CodexArtifacts/esir-acidthrower-20261009/revision-03/pressure-jet/dispersion-02/qc/mods")
loaded = dict(re.findall(r"Loading mod (.+?) ([\d.]+) \(", (live / "factorio-current.log").read_text(encoding="utf-8")))
selection = json.loads((mods / "mod-list.json").read_text(encoding="utf-8-sig"))
destination = args.root / "qc/mods"
destination.mkdir(parents=True, exist_ok=True)
rows = []
for entry in selection["mods"]:
    name = entry["name"]
    if not entry["enabled"] or name in ("base", "quality", "space-age", "elevated-rails"):
        continue
    repo_pack = Path.cwd() / name
    if (repo_pack / "info.json").exists():
        rows.append({"name": name, "source": "current worktree", "path": str(repo_pack)})
        continue
    version = loaded.get(name)
    source = mods / f"{name}_{version}.zip" if version else None
    if not source or not source.exists():
        candidates = []
        for path in mods.glob(name + "_*.zip"):
            with zipfile.ZipFile(path) as archive:
                info = json.loads(archive.read(next(n for n in archive.namelist() if n.count("/") == 1 and n.endswith("/info.json"))))
            if info["name"] == name and info.get("factorio_version") == "2.0":
                candidates.append((tuple(map(int, info["version"].split("."))), path))
        assert candidates, f"No compatible active archive for {name}"
        source = max(candidates)[1]
    digest = hashlib.sha256(source.read_bytes()).hexdigest()
    cache = cached / source.name
    copy_source = cache if cache.exists() and hashlib.sha256(cache.read_bytes()).hexdigest() == digest else source
    target = destination / source.name
    if not target.exists():
        shutil.copy2(copy_source, target)
    assert hashlib.sha256(target.read_bytes()).hexdigest() == digest
    rows.append({"name": name, "archive": source.name, "sha256": digest, "bytes": target.stat().st_size, "copy_source": str(copy_source)})
shutil.copy2(mods / "mod-settings.dat", destination / "mod-settings.dat")
seed = args.root / "live-selection-seed"
seed.mkdir(exist_ok=True)
shutil.copy2(mods / "mod-list.json", seed / "mod-list.json")
manifest = {"live_mod_list_sha256": hashlib.sha256((mods / "mod-list.json").read_bytes()).hexdigest(),
            "live_settings_sha256": hashlib.sha256((mods / "mod-settings.dat").read_bytes()).hexdigest(), "mods": rows}
(args.root / "live-inputs.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")
print(json.dumps({"external_archives": sum("archive" in r for r in rows), "worktree_packs": sum("archive" not in r for r in rows), "seed": str(seed)}))
