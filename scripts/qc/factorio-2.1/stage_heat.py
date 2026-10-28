"""Reuse preserved core selections for a paired heat fixture without altering donors."""
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
    parser.add_argument("--source",required=True)
    parser.add_argument("--version",choices=("2.0","2.1"),required=True)
    args=parser.parse_args()
    root=Path(os.path.abspath(args.run))
    source=Path(os.path.abspath(args.source))
    mods=root / "mods"
    mods.mkdir(parents=True)
    source_list=json.loads((source / "mods/mod-list.json").read_text(encoding="utf-8-sig"))
    names={r["name"] for r in source_list["mods"] if r["enabled"] and not r["name"].startswith("esir-qc-")}
    for entry in (source / "mods").iterdir():
        if entry.is_file() and entry.suffix==".zip": os.link(entry,mods / entry.name)
        elif entry.is_dir():
            info=json.loads((entry / "info.json").read_text(encoding="utf-8-sig"))
            if info["name"] not in names: continue
            env=os.environ.copy()
            env.update(ESIR_QC_LINK=str(mods / info["name"]),ESIR_QC_SOURCE=str(entry.resolve()))
            subprocess.run(["powershell","-NoProfile","-Command","New-Item -ItemType Junction -Path $env:ESIR_QC_LINK -Target $env:ESIR_QC_SOURCE | Out-Null"],env=env,check=True)
    fixture=mods / "esir-qc-heat"
    fixture.mkdir()
    shutil.copy2(HERE / "heat/control.lua",fixture / "control.lua")
    (fixture / "info.json").write_text(json.dumps({"name":fixture.name,"version":"1.0.0","factorio_version":args.version,
        "title":"ESIR native heat parity","author":"ESIR QC","dependencies":["exotic-space-industries-remembrance"]}),encoding="utf-8")
    (mods / "mod-list.json").write_text(json.dumps({"mods":[{"name":n,"enabled":True} for n in sorted(names | {fixture.name})]}),encoding="utf-8")
    engine=Path("C:/Program Files (x86)/Steam/steamapps/common/Factorio") if args.version=="2.0" else Path.cwd() / ".factorio-qc/f21"
    (root / "config.ini").write_text(f"[path]\nread-data={engine / 'data'}\nwrite-data={root}\n[other]\ncheck-updates=false\n",encoding="utf-8")


if __name__=="__main__": main()
