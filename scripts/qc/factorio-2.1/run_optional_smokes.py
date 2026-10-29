"""Isolated native startup and 600-tick checks for the 45 pinned optional candidates.

Each case includes only that root's required closure over the accepted core seed.
Uses physical short D: paths, hard-links verified archives on that volume, and
retains separate logs/receipts even when a candidate fails. No user installation.
"""
import argparse
import datetime
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import time

HERE=Path(__file__).resolve().parent
REPO=HERE.parents[2]


def digest(path):
    with path.open("rb") as stream: return hashlib.file_digest(stream,"sha256").hexdigest()


def junction(source,target):
    environment=os.environ.copy()
    environment.update(ESIR_QC_SOURCE=str(source.resolve()),ESIR_QC_LINK=str(target))
    subprocess.run(["powershell","-NoProfile","-Command","New-Item -ItemType Junction -Path $env:ESIR_QC_LINK -Target $env:ESIR_QC_SOURCE | Out-Null"],env=environment,check=True)


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--packages",type=Path,required=True)
    parser.add_argument("--audit",type=Path,required=True)
    parser.add_argument("--output",type=Path,required=True)
    parser.add_argument("--only",nargs="*")
    parser.add_argument("--retry-failed",action="store_true")
    parser.add_argument("--rerun-selected",action="store_true",help="Fresh evidence after a source or fixture change; requires --only")
    args=parser.parse_args()
    assert not args.rerun_selected or args.only,"Use --only to bound an intentional rerun"
    root=args.output.absolute()
    root.mkdir(parents=True,exist_ok=True)
    shared=root / "archives"
    shared.mkdir(exist_ok=True)
    package_rows=json.loads((args.packages / "package-lock.json").read_text(encoding="utf-8"))
    core_rows=json.loads((args.audit.parent / "dependencies/dependency-lock-2.1.json").read_text(encoding="utf-8"))
    packages={row["name"]:row for row in package_rows}
    matrix=json.loads((args.audit / "optional-dependencies-packaged.json").read_text(encoding="utf-8"))
    resolution=json.loads((args.packages / "resolution.json").read_text(encoding="utf-8"))
    edges={name:[] for name in packages}
    for edge in resolution["required_edges"]:
        if edge["name"] in packages: edges[edge["from"]].append(edge["name"])
    source=REPO / ".factorio-qc/21/mods"
    core_list=json.loads((source / "mod-list.json").read_text(encoding="utf-8"))
    core_mods={entry["name"]:dict(entry) for entry in core_list["mods"]}
    assert "quality" in core_mods,"Core profile must explicitly select Quality enabled or disabled"
    quality_enabled=bool(core_mods["quality"].get("enabled"))
    core_settings=source / "mod-settings.dat"
    core_profile={"mods":[core_mods[n] for n in sorted(core_mods)],
        "settings_sha256":digest(core_settings) if core_settings.is_file() else None}
    core_profile_sha256=hashlib.sha256(json.dumps(core_profile,sort_keys=True,separators=(",",":")).encode()).hexdigest()
    for row in core_rows:
        target=shared / row["file"]
        if not target.exists(): shutil.copy2(args.audit.parent / "dependencies" / row["file"],target)
        assert digest(target)==row["sha256"],"Core archive integrity"
    engine=REPO / ".factorio-qc/f21/bin/x64/factorio.exe"
    results=[]
    for index,row in enumerate(matrix["entries"],1):
        if (root / "pause-after-current").exists():
            print("Paused at the requested case boundary; completed receipts are preserved.",flush=True)
            break
        if not row["version"] or row["status"]=="port-backlog" or (args.only and row["selected"] not in args.only): continue
        name=row["selected"]
        case=root / f"{index:02d}"
        receipt_path=case / "receipt.json"
        prior_paths=[receipt_path,*sorted(root.glob(f"{index:02d}-retry-*/receipt.json"))]
        accepted=[]
        for prior_path in prior_paths:
            if not prior_path.exists(): continue
            prior=json.loads(prior_path.read_text(encoding="utf-8"))
            if (prior["passed"] and prior["version"]==row["version"] and prior["package_sha256"]==row["sha256"]
                and prior.get("core_profile_sha256")==core_profile_sha256):
                accepted.append(prior)
        if accepted and not args.rerun_selected:
            results.append(max(accepted,key=lambda receipt:receipt["started_utc"]))
            continue
        if receipt_path.exists():
            previous=json.loads(receipt_path.read_text(encoding="utf-8"))
            if (not args.rerun_selected and (previous["passed"] or not args.retry_failed)
                and previous["version"]==row["version"] and previous["package_sha256"]==row["sha256"]
                and previous.get("core_profile_sha256")==core_profile_sha256):
                results.append(previous)
                continue
            case=root / (f"{index:02d}-retry-"+datetime.datetime.now().strftime("%Y%m%d-%H%M%S"))
            receipt_path=case / "receipt.json"
        case.mkdir(exist_ok=True)
        mods=case / "mods"
        mods.mkdir(exist_ok=True)
        needed=set()
        queue=[name]
        while queue:
            child=queue.pop()
            if child in needed: continue
            needed.add(child)
            queue.extend(edges[child])
        assert quality_enabled or not any(edge["from"] in needed and edge["name"]=="quality"
            for edge in resolution["required_edges"]),(name,"requires Quality in a Quality-disabled profile")
        for item in [*core_rows,*[packages[n] for n in sorted(needed)]]:
            target=shared / item["file"]
            if not target.exists():
                origin=Path(item["absolute_file"])
                if origin.drive.lower()==target.drive.lower(): os.link(origin,target)
                else: shutil.copy2(origin,target)
            assert digest(target)==item["sha256"],"Selected archive integrity"
            destination=mods / item["file"]
            if not destination.exists(): os.link(target,destination)
        for directory in source.iterdir():
            if directory.is_dir() and (directory / "info.json").is_file() and not (mods / directory.name).exists():
                junction(directory,mods / directory.name)
        fixture=mods / "esir-qc-optional-smoke"
        fixture.mkdir(exist_ok=True)
        for file in (HERE / "optional-smoke").glob("*.lua"): shutil.copy2(file,fixture / file.name)
        (fixture / "info.json").write_text(json.dumps({"name":fixture.name,"version":"1.0.0","factorio_version":"2.1",
            "title":"ESIR optional smoke","author":"ESIR QC","dependencies":["exotic-space-industries-remembrance",name]}),encoding="utf-8")
        selection={n:dict(entry) for n,entry in core_mods.items()}
        for n in needed | {fixture.name}:
            selection[n]=dict(selection.get(n,{}),name=n,enabled=True)
        selection["quality"]=dict(core_mods["quality"],enabled=quality_enabled)
        (mods / "mod-list.json").write_text(json.dumps({"mods":[selection[n] for n in sorted(selection)]}),encoding="utf-8")
        if core_settings.is_file():shutil.copy2(core_settings,mods / "mod-settings.dat")
        config=case / "config.ini"
        config.write_text(f"[path]\nread-data={engine.parents[2] / 'data'}\nwrite-data={case}\n[other]\ncheck-updates=false\n",encoding="utf-8")
        source_hashes={str(p.relative_to(REPO)):digest(p) for p in (REPO / "exotic-space-industries-remembrance").rglob("*.lua")}
        (case / "source-manifest.json").write_text(json.dumps(source_hashes,indent=2),encoding="utf-8")
        command=[str(engine),"--config",str(config),"--mod-directory",str(mods),"--disable-audio"]
        save=case / "fresh.zip"
        started=time.time()
        receipt={"name":name,"version":row["version"],"package_sha256":row["sha256"],"required_closure":sorted(needed),
            "settings_overrides":{},"core_profile_sha256":core_profile_sha256,"core_profile":core_profile,
            "receipt_path":str(receipt_path),
            "started_utc":datetime.datetime.now(datetime.timezone.utc).isoformat(),"passed":False,
            "scope":"Native create, final crystal assertions and 600 ticks only; progression and migration remain separate"}
        try:
            for phase,arguments in (("create",["--create",str(save)]),("runtime",["--benchmark",str(save),"--benchmark-ticks","601","--benchmark-runs","1"])):
                log=case / (phase+".log")
                with log.open("w",encoding="utf-8") as stream:
                    run=subprocess.run(command+arguments,stdout=stream,stderr=subprocess.STDOUT,timeout=180,
                        creationflags=subprocess.CREATE_NO_WINDOW)
                text=log.read_text(encoding="utf-8",errors="replace")
                if run.returncode!=0 or "non-recoverable error" in text or "Error while running" in text:
                    receipt.update(failed_phase=phase,exit_code=run.returncode,error_tail=text[-6000:])
                    break
            else:
                result=json.loads((case / "script-output/optional-smoke.json").read_text(encoding="utf-8"))
                receipt["passed"]=result["passed"]
                receipt["save_sha256"]=digest(save)
        except subprocess.TimeoutExpired:
            receipt.update(failed_phase=phase,error="Native engine timed out")
        receipt["elapsed_seconds"]=round(time.time()-started,3)
        receipt_path.write_text(json.dumps(receipt,indent=2),encoding="utf-8")
        results.append(receipt)
        (root / "results.json").write_text(json.dumps(results,indent=2),encoding="utf-8")
        print(json.dumps({k:receipt[k] for k in ("name","version","passed","elapsed_seconds")}),flush=True)


if __name__=="__main__": main()
