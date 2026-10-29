"""Real populated-save policy tightening and Quality removal, using private ESIR hooks."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import time

from run import REPO, FIXTURE, NAME, FLAGS, stage, configure, execute, write_json, source_hashes


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--run",required=True)
    parser.add_argument("--worker",default="t",choices=("t","u"))
    parser.add_argument("--phase",choices=("normal","player","donor","eject","removed","reload","relax","legacy","duplicates"),required=True)
    parser.add_argument("--id")
    parser.add_argument("--save")
    parser.add_argument("--refresh-source",action="store_true")
    parser.add_argument("--headless-probe",action="store_true",help="Exercise donor ordinary owners before expensive client loading")
    parser.add_argument("--client",action="store_true",help="Use a connected native player for payment and GUI checks")
    parser.add_argument("--without-quality",action="store_true")
    parser.add_argument("--quality-permission",default="both",choices=("neither","nitrogen","alien","both"))
    parser.add_argument("--productivity-permission",default="both",choices=("neither","nitrogen","alien","both"))
    args=parser.parse_args()
    root=Path(os.path.abspath(args.run))
    assert root.is_relative_to(REPO/".factorio-qc")
    development=json.loads((REPO/".codex/esir/factorio-development.json").read_text())
    engine=REPO/development["engine_path"]
    frozen=root/("transition-main" if args.worker=="t" else "transition-main-u")
    worker=root/args.worker
    if not frozen.exists() or args.refresh_source:
        shutil.copytree(REPO/NAME,frozen,dirs_exist_ok=True)
        for filename,exports in {
            "orbital-combinator.lua":{"qc_build_surface_snapshot":"build_surface_snapshot","qc_reconcile_section":"reconcile_section"},
            "orbital-logistics.lua":{"qc_manifest_from_payload":"manifest_from_payload","qc_reconcile_section":"reconcile_section"},
            "sweeping-radar.lua":{"qc_begin_job":"begin_job","qc_service_control":"service_control","qc_aggregate":"aggregate"},
        }.items():
            path=frozen/"scripts/control"/filename
            content=path.read_text(encoding="utf-8")
            at=content.rfind("\nreturn model")
            assert at>0
            content=content[:at]+"\n"+"\n".join(f"model.{key}={value}" for key,value in exports.items())+content[at:]
            path.write_text(content,encoding="utf-8")
        with (frozen/"control.lua").open("a",encoding="utf-8") as stream:
            stream.write("\n"+(FIXTURE/"bridge.lua").read_text(encoding="utf-8"))
        write_json(root/("transition-production-source-"+args.worker+".json"),source_hashes(REPO/NAME))
        if not (worker/"mods/esir-qc-quality-optional").exists():stage(worker,frozen,engine)
    for path in FIXTURE.glob("*.lua"):shutil.copy2(path,worker/"mods/esir-qc-quality-optional"/path.name)
    shutil.copy2(FIXTURE/"info.json",worker/"mods/esir-qc-quality-optional/info.json")
    case={"id":args.id or args.phase,"phase":args.phase,"quality":args.phase!="removed" and not args.without_quality,"effects":"esir",
          "quality_permission":args.quality_permission,"productivity_permission":args.productivity_permission,"overload":True}
    save=Path(os.path.abspath(args.save)) if args.save else worker/"donor-fresh.zip"
    if args.phase=="reload":
        assert args.save,"Reload requires an accepted saved checkpoint"
        # Keep the exact original fixture/data selection. Changing the phase in
        # case.lua itself legitimately triggers Factorio configuration repair.
        case["id"]=save.stem
        case["phase"]="removed" if args.without_quality else "eject"
    configure(worker,case)
    if args.phase=="reload":
        result=execute(worker,engine,case,["--benchmark",str(save),"--benchmark-ticks","300","--benchmark-runs","1"],"reload")
        result["ordinary_reload"]=True
        result["checkpoint_sha256"]=hashlib.sha256(save.read_bytes()).hexdigest()
        result["callback_guard"]="Original removed/eject callback rejects an unexpected configuration pass without the corresponding real mod/settings change"
        write_json(worker/((args.id or save.stem+"-reload")+".receipt.json"),result)
        assert result["passed"],result
        print(json.dumps({"passed":True,"ordinary_reload":True,"checkpoint":str(save)}))
        return
    if args.headless_probe and args.save:
        result=execute(worker,engine,case,["--benchmark",str(save),"--benchmark-ticks","1601","--benchmark-runs","1"],"probe")
        write_json(worker/(case["id"]+".probe.json"),result)
        assert result["passed"],result
        return
    if args.phase in ("normal","player","donor") and not args.save:
        result=execute(worker,engine,case,["--create",str(save)],"create")
        write_json(worker/"donor-create.json",result)
        assert result["passed"],result
        if args.phase=="normal":
            result=execute(worker,engine,case,["--benchmark",str(save),"--benchmark-ticks","1600","--benchmark-runs","1"],"normal")
            if result["passed"]:
                result["normal"]=json.loads((worker/"script-output"/(case["id"]+".json")).read_text())
                result["passed"]=result["normal"].get("passed",False)
            write_json(worker/(case["id"]+".receipt.json"),result)
            assert result["passed"],result
            print(json.dumps({"case":case,"passed":True,"checks":result["normal"]["checks"]}))
            return
        if args.headless_probe:
            result=execute(worker,engine,case,["--benchmark",str(save),"--benchmark-ticks","210","--benchmark-runs","1"],"headless")
            write_json(worker/"donor-headless.json",result)
            assert result["passed"],result
            return
    if (args.phase in ("player","donor") and not args.save) or args.client:
        checkpoint="quality-"+args.phase
        command=["python","-B",str(REPO/"scripts/qc/factorio-2.1/native_client.py"),"--run",str(worker),
            "--engine",str(engine),"--save",str(save),"--marker",checkpoint+".json","--phase",checkpoint,
            "--checkpoint","_autosave-"+checkpoint+".zip","--timeout","360","--graphics-quality","medium"]
    else:
        assert args.save
        checkpoint="quality-donor" if args.phase=="donor" else case["id"]
        command=["python","-B",str(REPO/"scripts/qc/factorio-2.1/save_checkpoint.py"),"--run",str(worker),
            "--engine",str(engine),"--save",str(save),"--phase",checkpoint,"--receipt",checkpoint+".json",
            "--checkpoint",checkpoint+".zip","--pass-key","passed","--timeout","300",
            "--port","34429" if args.worker=="t" else "34430"]
    environment=dict(os.environ,SteamAppId="427520",SteamGameId="427520")
    result=subprocess.run(command,cwd=REPO,creationflags=FLAGS,env=environment)
    raise SystemExit(result.returncode)


if __name__=="__main__":
    main()
