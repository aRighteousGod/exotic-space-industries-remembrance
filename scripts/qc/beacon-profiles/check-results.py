"""Inspect saved engine reports, including entity identity across real reloads."""
import argparse
import json
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument("run", type=Path)
parser.add_argument("--transitions", action="store_true")
args = parser.parse_args()
phases = ["off-" + name for name in ("gentle", "vanilla", "strict", "harsh", "severe", "saturating")]
phases += ["on-gentle", "on-saturating"]
if args.transitions:
    phases += ["transition-off", "transition-reload", "transition-on"]
reports = {}
for phase in phases:
    report = json.loads((args.run / (phase + ".json")).read_text(encoding="utf-8-sig"))
    assert report["all_pass"] and len(report["cases"]) == 25, phase
    reports[phase] = report
if args.transitions:
    original = {case["id"]: case["unit"] for case in reports["on-gentle"]["cases"]}
    for phase, enabled in (("transition-off", False), ("transition-reload", False), ("transition-on", True)):
        report = reports[phase]
        assert report["overload"] is enabled and report["profile"] == "strict", phase
        assert {case["id"]: case["unit"] for case in report["cases"]} == original, phase + " machine identities"
        assert (args.run / "saves" / ("beacon-profile-" + phase + ".zip")).is_file(), phase + " saved factory"
    assert reports["transition-off"]["startup_changed"]
    assert reports["transition-on"]["startup_changed"]
    assert len(reports["transition-reload"]["history"]) == 3
    assert len(reports["transition-on"]["history"]) == 4
print(f"PASS: {len(phases)} engine phases, {25 * len(phases)} receiver checkpoints; transitions={args.transitions}")
