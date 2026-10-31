"""Save the migrated fixture on a private loopback server, then stop that child."""
import json
import os
from pathlib import Path
import subprocess
import sys
import time
import zipfile

record = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8-sig"))
legacy = json.loads(Path(sys.argv[2]).read_text(encoding="utf-8-sig"))
root = Path(record["write_data"])
settings = root / "legacy-server.json"
server = json.loads((Path(record["engine"]).parents[2] / "data/server-settings.example.json").read_text())
server.update(name="Mirroring migration QC", description="Private historical fixture",
    visibility={"public": False, "lan": False}, require_user_verification=False,
    auto_pause=False, auto_pause_when_players_connect=False, autosave_interval=0)
settings.write_text(json.dumps(server), encoding="utf-8")
(Path(record["mods"]) / "esir-qc-mirroring-legacy/legacy-config.lua").write_text('return {phase="adopt"}\n')
save = root / "saves/_autosave-mirroring-migrated.zip"
log_path = root / "legacy-checkpoint.log"
started = time.time()
with log_path.open("w") as log:
    process = subprocess.Popen([record["engine"], "--config", record["config"], "--mod-directory", record["mods"],
        "--disable-audio", "--start-server", str(Path(legacy["write_data"]) / "donor.zip"),
        "--server-settings", str(settings), "--bind", "127.0.0.1", "--port", "34459"],
        stdout=log, stderr=subprocess.STDOUT, creationflags=subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0)
    try:
        while time.time() - started < 180:
            if process.poll() is not None:
                raise RuntimeError(log_path.read_text(errors="replace")[-4000:])
            if save.exists() and save.stat().st_mtime > started and "Saving finished" in log_path.read_text(errors="replace"):
                with zipfile.ZipFile(save) as archive:
                    assert archive.testzip() is None
                print(save)
                break
            time.sleep(0.25)
        else:
            raise TimeoutError("No completed migrated checkpoint")
    finally:
        if process.poll() is None:
            process.terminate()
            process.wait(timeout=15)
