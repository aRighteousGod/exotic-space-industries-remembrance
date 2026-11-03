"""Exercise actual Dolly input handlers against a player save on the managed engine."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time

here = Path(__file__).resolve().parent
parser = argparse.ArgumentParser()
parser.add_argument("--repo", type=Path, default=here.parents[2])
parser.add_argument("--context", type=Path, help="Reuse a newly prepared, unused managed run")
args = parser.parse_args()
repo = args.repo.resolve()
sys.path.insert(0, str(repo / "scripts/qc/native-tests"))
from runner import managed, native_path, run_process

with tempfile.TemporaryDirectory() as tmp:
    context = args.context or Path(tmp) / "context.json"
    if not args.context:
        env = {k:v for k,v in os.environ.items() if k.lower() != "psmodulepath"}
        subprocess.run(["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File",
                        str(here / "stage.ps1"), "-Repo", str(repo), "-Record", str(context)], check=True, env=env)
    run = json.loads(context.read_text(encoding="utf-8-sig"))
write = Path(run["write_data"])
evidence = Path(run["evidence"])
mod_list = Path(run["mods"]) / "mod-list.json"
common = [run["engine"], "--config", native_path(run["config"]), "--mod-directory", native_path(run["mods"]),
          "--disable-audio", "--disable-migration-window", "--instrument-mod", "esir-dollies-qc"]
phases = {}
status = "failed"
try:
    for phase in ("absent", "installed", "reload"):
        if phase != "reload":
            selection = json.loads(mod_list.read_text(encoding="utf-8-sig"))
            selection["mods"] = [m for m in selection["mods"] if m["name"] != "even-pickier-dollies"]
            selection["mods"].append({"name":"even-pickier-dollies", "enabled":phase == "installed"})
            mod_list.write_text(json.dumps(selection,indent=2), encoding="utf-8")
        if phase == "absent":
            save = Path(run["scratch"]) / "seed.zip"
            result = run_process(common + ["--create",save], evidence/"create.log", 600)
            if result["exit_code"] or result["fatal"]: raise RuntimeError(result)
        checkpoint = write / "saves" / ("_autosave-dollies-" + phase + ".zip")
        if phase == "reload":
            launch = ["--test-save",save,"--test-arg","reload","--test-ticks","900"]
        else:
            launch = ["--load-game",save,"--window-size","1280x720","--graphics-quality","medium","--video-memory-usage","low"]
        started = time.time()
        result = run_process(common+launch, evidence/(phase+".log"), 600, None if phase=="reload" else checkpoint)
        phases[phase] = result
        if result["fatal"] or result["exit_code"] or (phase!="reload" and not result["checkpoint_verified"]):
            raise RuntimeError(result)
        receipt = write/"script-output"/("dollies-"+phase+".json")
        report = json.loads(receipt.read_text(encoding="utf-8"))
        if report.get("passed") is not True or report.get("phase") != phase or receipt.stat().st_mtime < started:
            raise RuntimeError("Invalid phase receipt: "+phase)
        (evidence/receipt.name).write_bytes(receipt.read_bytes())
        save = checkpoint
    managed("validate", {"run_id":run["run_id"]})
    status = "ok"
finally:
    managed("finish", {"run_id":run["run_id"], "overall_status":status, "result":phases})
    print(run["run_id"],status,flush=True)
