"""Run one private native server until its requested checkpoint is fully saved.

Uses a hidden child process, loopback binding and a bounded wait. Requires a
fresh save timestamp, 'Saving finished', an intact ZIP and an optional receipt.
Stops only its own child; never scans or terminates unrelated Factorio processes.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import time
import zipfile


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--engine", default=".factorio-qc/f21/bin/x64/factorio.exe")
    parser.add_argument("--run", required=True)
    parser.add_argument("--save", required=True)
    parser.add_argument("--checkpoint", required=True)
    parser.add_argument("--phase", required=True)
    parser.add_argument("--receipt")
    parser.add_argument("--pass-key", choices=("passed", "all_pass"))
    parser.add_argument("--timeout", type=int, default=180)
    parser.add_argument("--port", type=int, default=34429)
    args = parser.parse_args()
    # Do not resolve junctions: Factorio's require loader needs short mod paths.
    root = Path(os.path.abspath(args.run))
    (root / "saves").mkdir(exist_ok=True)
    settings = root / "server-settings.json"
    settings.write_text(json.dumps({"name": "Private ESIR upgrade acceptance", "description": "Disposable native fixture",
        "visibility": {"public": False, "lan": False}, "require_user_verification": False,
        "auto_pause": False, "autosave_interval": 0}), encoding="utf-8")
    command = [os.path.abspath(args.engine), "--config", str(root / "config.ini"), "--mod-directory", str(root / "mods"),
        "--disable-audio", "--start-server", os.path.abspath(args.save), "--server-settings", str(settings),
        "--bind", "127.0.0.1", "--port", str(args.port)]
    checkpoint = root / "saves" / args.checkpoint
    output = root / (args.phase + ".server.log")
    started = time.time()
    with output.open("w", encoding="utf-8") as log:
        process = subprocess.Popen(command, stdout=log, stderr=subprocess.STDOUT,
            creationflags=subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0)
        try:
            while time.time() - started < args.timeout:
                current = output.read_text(encoding="utf-8", errors="replace")
                if process.poll() is not None or "non-recoverable error" in current:
                    raise RuntimeError(current[-5000:])
                marker = root / "script-output" / args.receipt if args.receipt else None
                if "Saving finished" in current and checkpoint.exists() and checkpoint.stat().st_mtime >= started:
                    try:
                        with zipfile.ZipFile(checkpoint) as archive:
                            valid = archive.testzip() is None
                    except (OSError, zipfile.BadZipFile):
                        valid = False
                    if valid and (not marker or (marker.exists() and marker.stat().st_mtime >= started)):
                        if args.pass_key:
                            assert marker, "--pass-key requires --receipt"
                            fixture = json.loads(marker.read_text(encoding="utf-8"))
                            assert fixture.get(args.pass_key), fixture
                        with checkpoint.open("rb") as saved:
                            checksum = hashlib.file_digest(saved, "sha256").hexdigest()
                        receipt = {"passed": True, "phase": args.phase, "checkpoint": str(checkpoint),
                            "checkpoint_sha256": checksum,
                            "checkpoint_bytes": checkpoint.stat().st_size, "elapsed_seconds": round(time.time() - started, 3),
                            "engine": command[0], "log": str(output), "fixture_receipt": str(marker) if marker else None}
                        (root / (args.phase + ".checkpoint.json")).write_text(json.dumps(receipt, indent=2), encoding="utf-8")
                        print(json.dumps(receipt))
                        return
                time.sleep(0.25)
            raise TimeoutError("Native checkpoint did not complete: " + str(output))
        finally:
            if process.poll() is None:
                process.terminate()
                process.wait(timeout=15)


if __name__ == "__main__":
    main()
