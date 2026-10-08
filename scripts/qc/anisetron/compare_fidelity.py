"""Compare native ANISETRON mechanics across six fresh startup-fidelity reports."""
import argparse
import json
from pathlib import Path

TIERS = {"off", "lean", "standard", "cinematic", "maximal", "unbounded"}
parser = argparse.ArgumentParser()
parser.add_argument("reports", nargs="+", type=Path)
parser.add_argument("--output", type=Path)
args = parser.parse_args()
reports = []
problems = []
for path in args.reports:
    report = json.loads(path.read_text(encoding="utf-8-sig"))
    if not report.get("all_pass") or not report.get("complete"):
        problems.append(f"Incomplete or failed native report: {path}")
    if report.get("profile") != "native" or report.get("fixture_version") != 2:
        problems.append(f"Wrong profile or fixture version: {path}")
    if not report.get("mechanics", {}).get("sources"):
        problems.append(f"Missing normalized mechanical observations; rerun current draft: {path}")
    reports.append((path, report))
tiers = [report.get("fidelity") for _, report in reports]
if len(reports) != 6 or set(tiers) != TIERS or len(set(tiers)) != len(tiers):
    problems.append("Supply exactly one complete native report for each of the six startup tiers")
baseline = next((report for _, report in reports if report.get("fidelity") == "standard"), None)
if baseline:
    for path, report in reports:
        if report.get("contract") != baseline.get("contract"):
            problems.append(f"Mechanical contract differs from Standard: {path}")
        if report.get("mechanics") != baseline.get("mechanics"):
            problems.append(f"Paid counts, damage, reserves or target sequence differs from Standard: {path}")
result = {"pass": not problems, "reports": {report.get("fidelity", str(path)): str(path) for path, report in reports},
          "compared": ["charge counts", "ammo quality", "remaining reserves", "per-channel counts and damage",
                       "unexpected/legacy damage", "full crown and frontal target-lock sequences"],
          "excluded": ["visual counters", "render handles", "source coordinates", "absolute event ticks"],
          "problems": problems}
if args.output:
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
print(json.dumps(result, indent=2))
raise SystemExit(0 if result["pass"] else 1)
