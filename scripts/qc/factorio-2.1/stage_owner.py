"""Stage a private core owner fixture with explicit exports and no shipping hooks.

Source is an existing pinned mod selection. Only the gameplay mod is copied;
archives are hardlinked and companion sources are junctioned. The manifest
records original source, bridge and injected-export hashes separately.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess

MAIN = "exotic-space-industries-remembrance"


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--run", required=True)
    parser.add_argument("--source", default=".factorio-qc/21")
    parser.add_argument("--bridge", type=Path, required=True)
    parser.add_argument("--exports", type=Path)
    parser.add_argument("--data-bridge", type=Path)
    parser.add_argument("--version", choices=("2.0", "2.1"), default="2.1")
    args = parser.parse_args()
    root, source = (Path(os.path.abspath(p)) for p in (args.run, args.source))
    mods = root / "mods"
    mods.mkdir(parents=True, exist_ok=False)
    selection = json.loads((source / "mods/mod-list.json").read_text(encoding="utf-8-sig"))
    names = {r["name"] for r in selection["mods"] if r["enabled"] and not r["name"].startswith("esir-qc-")}
    for entry in (source / "mods").iterdir():
        if entry.is_file() and entry.suffix == ".zip":
            try:
                os.link(entry, mods / entry.name)
            except OSError as error:
                if error.errno != 18 and getattr(error, "winerror", None) != 17:
                    raise
                # Approved overflow stages can live on a different volume.
                shutil.copy2(entry, mods / entry.name)
        elif entry.is_dir():
            info = json.loads((entry / "info.json").read_text(encoding="utf-8-sig"))
            if info["name"] not in names:
                continue
            destination = mods / info["name"]
            if info["name"] == MAIN:
                shutil.copytree(entry, destination)
            else:
                environment = os.environ.copy()
                environment.update(ESIR_QC_LINK=str(destination), ESIR_QC_SOURCE=str(entry.resolve()))
                subprocess.run(["powershell", "-NoProfile", "-Command",
                    "New-Item -ItemType Junction -Path $env:ESIR_QC_LINK -Target $env:ESIR_QC_SOURCE | Out-Null"],
                    env=environment, check=True)
    main_root = mods / MAIN
    hashes = {str(p.relative_to(main_root)): digest(p) for p in main_root.rglob("*.lua")}
    if args.exports:
        exports = json.loads(args.exports.read_text(encoding="utf-8"))
        for relative, text in exports.items():
            path = main_root / "scripts/control" / (relative + ".lua")
            contents = path.read_text(encoding="utf-8")
            contents, count = re.subn(r"return model\s*$", text + "\nreturn model\n", contents)
            assert count == 1, "Expected one final owner export: " + str(path)
            path.write_text(contents, encoding="utf-8")
    with (main_root / "control.lua").open("a", encoding="utf-8") as stream:
        stream.write("\n-- Private acceptance fixture; not shipping.\n" + args.bridge.read_text(encoding="utf-8"))
    if args.data_bridge:
        with (main_root / "data-final-fixes.lua").open("a", encoding="utf-8") as stream:
            stream.write("\n-- Private acceptance prototypes; not shipping.\n" + args.data_bridge.read_text(encoding="utf-8"))
    (mods / "mod-list.json").write_text(json.dumps({"mods": [{"name": n, "enabled": True} for n in sorted(names)]}), encoding="utf-8")
    engine = Path("C:/Program Files (x86)/Steam/steamapps/common/Factorio") if args.version == "2.0" else Path.cwd() / ".factorio-qc/f21"
    (root / "config.ini").write_text(f"[path]\nread-data={engine / 'data'}\nwrite-data={root}\n[other]\ncheck-updates=false\n", encoding="utf-8")
    receipt = {"source": str(source), "version": args.version, "source_hashes": hashes,
        "bridge": str(args.bridge), "bridge_sha256": digest(args.bridge),
        "exports": str(args.exports) if args.exports else None,
        "exports_sha256": digest(args.exports) if args.exports else None}
    receipt["data_bridge"] = str(args.data_bridge) if args.data_bridge else None
    receipt["data_bridge_sha256"] = digest(args.data_bridge) if args.data_bridge else None
    (root / "stage.json").write_text(json.dumps(receipt, indent=2), encoding="utf-8")
    print(json.dumps({"staged": str(root), "lua_files": len(hashes)}))


if __name__ == "__main__":
    main()
