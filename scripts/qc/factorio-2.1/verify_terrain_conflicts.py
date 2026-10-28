"""Prove both declared conflicts through the native resolver using identity stubs.

The stubs contain no Terrain Evolution implementation. This tests dependency
rejection, not either external mod's runtime behavior or save migration.
"""
import argparse
import json
import os
from pathlib import Path
import subprocess


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--run", required=True)
    args = parser.parse_args()
    root = Path(os.path.abspath(args.run))
    subprocess.run(["powershell", "-ExecutionPolicy", "Bypass", "-File", "scripts/qc/factorio-2.1/invoke-core.ps1",
        "-Task", "stage", "-RunRoot", str(root)], check=True)
    mod_list_path = root / "mods/mod-list.json"
    core = json.loads(mod_list_path.read_text(encoding="utf-8"))
    results = []
    for name in ("TerrainEvolution", "TerrainEvolution2"):
        stub = root / "mods" / name
        stub.mkdir(exist_ok=True)
        (stub / "info.json").write_text(json.dumps({"name": name, "version": "0.0.1", "factorio_version": "2.1",
            "title": "Dependency identity stub", "author": "ESIR QC", "dependencies": ["base >= 2.1.23"]}), encoding="utf-8")
        case = {"mods": core["mods"] + [{"name": candidate, "enabled": candidate == name}
            for candidate in ("TerrainEvolution", "TerrainEvolution2")]}
        mod_list_path.write_text(json.dumps(case), encoding="utf-8")
        output = root / (name + ".log")
        command = [os.path.abspath(".factorio-qc/f21/bin/x64/factorio.exe"), "--config", str(root / "config.ini"),
            "--mod-directory", str(root / "mods"), "--disable-audio", "--dump-data"]
        with output.open("w", encoding="utf-8") as stream:
            result = subprocess.run(command, stdout=stream, stderr=subprocess.STDOUT, timeout=60,
                creationflags=subprocess.CREATE_NO_WINDOW)
        log = output.read_text(encoding="utf-8", errors="replace")
        assert name in log and "exotic-space-industries-remembrance" in log and "incompatib" in log.lower(), log[-5000:]
        results.append({"external_identity": name, "rejected": True, "exit_code": result.returncode, "log": str(output)})
    report = {"passed": True, "engine": "2.1.23", "fixture": "identity-only dependency stubs", "cases": results}
    (root / "terrain-conflicts.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
    print(json.dumps(report))


if __name__ == "__main__":
    main()
