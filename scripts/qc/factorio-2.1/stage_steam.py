"""Run the existing steam working/starved visual fixture with the full 2.1 core.

This stage leaves production runtime owners enabled, unlike the earlier isolated
2.0 graphics lane. All helper prototypes and setting changes stay in this stage.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--run",required=True)
    parser.add_argument("--mode",choices=("on","off"),required=True)
    args=parser.parse_args()
    root=Path(os.path.abspath(args.run));root.mkdir(parents=True,exist_ok=True)
    assert not (root / "mods").exists()
    fixture=root / "fixture";fixture.mkdir()
    source=Path("scripts/qc/steam-consumer-glow")
    for name in ("control.lua","data-final-fixes.lua","settings-updates.lua","cases.lua"):
        shutil.copy2(source / name,fixture / name)
    (fixture / "test-config.lua").write_text('return {mode="'+args.mode+'",visual=true}\n',encoding="utf-8")
    (fixture / "info.json").write_text(json.dumps({"name":"esir-qc-steam-glow","version":"1.0.0","factorio_version":"2.1",
        "title":"ESIR native steam glow acceptance","author":"ESIR QC","dependencies":["exotic-space-industries-remembrance"]}),encoding="utf-8")
    subprocess.run(["powershell","-ExecutionPolicy","Bypass","-File","scripts/qc/factorio-2.1/invoke-core.ps1",
        "-Task","stage","-RunRoot",str(root),"-FixtureRoot",str(fixture)],check=True)
    hashes={str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in source.glob("*.lua")}
    (root / "stage.json").write_text(json.dumps({"mode":args.mode,"full_core_runtime":True,"fixture_sources":hashes,
        "scope":"Native rendered working/starved states for ten steam consumers; no audio or multiplayer claim"},indent=2),encoding="utf-8")


if __name__=="__main__":main()
