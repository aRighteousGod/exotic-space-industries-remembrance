"""Run an already staged private core fixture and require its acceptance marker."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import time


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--run", required=True)
    parser.add_argument("--engine", default=".factorio-qc/f21/bin/x64/factorio.exe")
    parser.add_argument("--save")
    parser.add_argument("--ticks", type=int, default=600)
    parser.add_argument("--tag", default="native-01")
    parser.add_argument("--marker")
    parser.add_argument("--report", help="Fresh JSON file relative to script-output; copied beside the receipt")
    parser.add_argument("--pass-key", default="all_pass")
    parser.add_argument("--timeout", type=int, default=300)
    args = parser.parse_args()
    assert args.marker or args.report, "A native completion marker or checked report is required"
    root = Path(os.path.abspath(args.run))
    save = Path(os.path.abspath(args.save)) if args.save else root / (args.tag + ".zip")
    common = [os.path.abspath(args.engine), "--config", str(root / "config.ini"),
        "--mod-directory", str(root / "mods"), "--disable-audio"]
    phases = [] if args.save else [("create", ["--create", str(save)])]
    phases.append(("runtime", ["--benchmark", str(save), "--benchmark-ticks", str(args.ticks), "--benchmark-runs", "1"]))
    receipt = {"passed": False, "engine": common[0], "save": str(save), "phases": []}
    archive_manifest = root / "release-selection.json"
    if archive_manifest.exists():
        selection = json.loads(archive_manifest.read_text(encoding="utf-8"))
        for row in selection["packages"]:
            package = Path(row["staged"])
            assert package.parent == root / "mods", "Archive outside isolated mod selection"
            with package.open("rb") as stream:
                assert hashlib.file_digest(stream, "sha256").hexdigest() == row["sha256"], "Archive changed after staging"
        receipt["archive_manifest"] = str(archive_manifest)
        receipt["archive_manifest_sha256"] = hashlib.sha256(archive_manifest.read_bytes()).hexdigest()
        receipt["verified_archives"] = len(selection["packages"])
    hashes = {}
    for directory in (root / "mods").iterdir():
        if directory.is_dir() and (directory / "info.json").is_file():
            for path in [directory / "info.json", *directory.rglob("*.lua")]:
                hashes[str(path.relative_to(root / "mods"))] = hashlib.sha256(path.read_bytes()).hexdigest()
    manifest = root / (args.tag + ".source-manifest.json")
    manifest.write_text(json.dumps(hashes, indent=2), encoding="utf-8")
    receipt["source_manifest"] = str(manifest)
    receipt["source_manifest_sha256"] = hashlib.sha256(manifest.read_bytes()).hexdigest()
    started = time.time()
    for phase, arguments in phases:
        path = root / (args.tag + "." + phase + ".log")
        with path.open("w", encoding="utf-8") as stream:
            process = subprocess.run(common + arguments, stdout=stream, stderr=subprocess.STDOUT,
                timeout=args.timeout, creationflags=subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0)
        contents = path.read_text(encoding="utf-8", errors="replace")
        passed = process.returncode == 0 and "non-recoverable error" not in contents and "Error while running" not in contents
        if phase == "runtime" and args.marker:
            passed = passed and args.marker in contents
        receipt["phases"].append({"phase": phase, "exit_code": process.returncode, "passed": passed, "log": str(path)})
        if not passed:
            receipt["error_tail"] = contents[-5000:]
            break
    else:
        receipt["passed"] = True
        if args.report:
            report_path = root / "script-output" / args.report
            try:
                assert report_path.stat().st_mtime >= started, "Stale fixture report"
                report = json.loads(report_path.read_text(encoding="utf-8"))
                receipt["passed"] = report.get(args.pass_key) is True
                copied_report = root / (args.tag + ".fixture.json")
                copied_report.write_text(json.dumps(report, indent=2), encoding="utf-8")
                receipt["fixture_report"] = str(copied_report)
                receipt["fixture_sha256"] = hashlib.sha256(copied_report.read_bytes()).hexdigest()
                checks = report.get("checks", [])
                receipt["checks"] = checks if isinstance(checks, int) else len(checks)
            except (AssertionError, OSError, ValueError) as error:
                receipt["passed"] = False
                receipt["report_error"] = str(error)
    if save.exists():
        receipt["save_sha256"] = hashlib.sha256(save.read_bytes()).hexdigest()
    receipt["elapsed_seconds"] = round(time.time() - started, 3)
    (root / (args.tag + ".receipt.json")).write_text(json.dumps(receipt, indent=2), encoding="utf-8")
    print(json.dumps(receipt))
    if not receipt["passed"]:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
