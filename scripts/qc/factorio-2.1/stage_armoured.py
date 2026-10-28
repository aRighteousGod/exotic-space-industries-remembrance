"""Prepare fresh full-core Armoured Biters fixtures with explicit startup defaults."""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess

HERE=Path(__file__).resolve().parent


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--run",required=True)
    parser.add_argument("--nest",choices=("true","false"),required=True)
    args=parser.parse_args()
    root=Path(os.path.abspath(args.run))
    root.mkdir(parents=True,exist_ok=True)
    assert not (root / "mods").exists(),"Use a fresh stage"
    fixture=root / "fixture"
    fixture.mkdir()
    for source in (HERE / "armoured").glob("*.lua"): shutil.copy2(source,fixture / source.name)
    (fixture / "info.json").write_text(json.dumps({"name":"esir-qc-armoured","version":"1.0.0","factorio_version":"2.1",
        "title":"ESIR native Armoured nest modes","author":"ESIR QC","dependencies":["exotic-space-industries-remembrance >= 1.4.0"]}),encoding="utf-8")
    (fixture / "settings-final-fixes.lua").write_text('data.raw["bool-setting"]["ab-enable-nest"].default_value='+args.nest+'\n',encoding="utf-8")
    subprocess.run(["powershell","-ExecutionPolicy","Bypass","-File",str(HERE / "invoke-core.ps1"),
        "-Task","stage","-RunRoot",str(root),"-FixtureRoot",str(fixture)],check=True)


if __name__=="__main__": main()
