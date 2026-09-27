"""Summarize native wholeUpdate samples, excluding warm-up and phase setup.

Factorio --benchmark-verbose reports nanoseconds:
https://wiki.factorio.com/Command_line_parameters
"""
import argparse
import csv
import json
import math
import re
import statistics
from pathlib import Path


def samples(path):
    runs, current, columns = [], [], None
    for line in path.read_text(encoding="utf-8-sig").splitlines():
        fields = [value.strip() for value in next(csv.reader([line.strip()]))]
        if "wholeUpdate" in fields and "tick" in fields:
            if current:
                runs.append(current)
                current = []
            columns = fields
            continue
        if columns is None or not re.match(r"^\s*t?\d+,", line):
            continue
        values = fields
        tick = int(values[0].removeprefix("t"))
        if current and tick <= current[-1][0]:
            runs.append(current)
            current = []
        current.append((tick, float(values[columns.index("wholeUpdate")]) / 1_000_000))
    if current:
        runs.append(current)
    assert len(runs) == 3, f"Expected three timing replays, got {len(runs)}: {path}"
    return runs


def summarize(folder):
    profiles = {}
    for profile in ("original", "2x", "4x", "8x", "16x"):
        report = json.loads((folder / f"{profile}-performance.json").read_text(encoding="utf-8-sig"))
        assert not report["diagnostic"]
        runs = samples(folder / f"{profile}-performance.txt")
        assert len(report["scenarios"]) == 9
        rows = []
        for scenario in report["scenarios"]:
            assert scenario["firing"] == scenario["population"]
            per_run, combined = [], []
            for run in runs:
                # Both this new-save fixture and the benchmark start at tick zero.
                values = [ms for tick, ms in run
                          if scenario["first_timed_tick"] <= tick <= scenario["last_timed_tick"]]
                assert len(values) == 1799, (profile, scenario, len(values))
                per_run.append(statistics.mean(values))
                combined.extend(values)
            combined.sort()
            rows.append({**scenario, "mean_ms": statistics.mean(combined),
                         "p95_ms": combined[math.ceil(len(combined) * 0.95) - 1],
                         "run_means_ms": per_run})
        profiles[profile] = rows
    passed = True
    for profile, rows in profiles.items():
        for index, row in enumerate(rows):
            baseline = profiles["original"][index]
            row["improvement_percent"] = 100 * (1 - row["mean_ms"] / baseline["mean_ms"])
            if profile != "original" and row["population"] == 1000:
                row["repeatable_saving"] = max(row["run_means_ms"]) < min(baseline["run_means_ms"])
                passed = passed and row["repeatable_saving"]
            print(f"{profile:8} {row['population']:4} {row['kind']:5}: "
                  f"mean {row['mean_ms']:.3f} ms, p95 {row['p95_ms']:.3f} ms, "
                  f"saving {row['improvement_percent']:.1f}%")
    result = {"all_pass": passed, "unit": "milliseconds", "profiles": profiles}
    (folder / "performance-summary.json").write_text(json.dumps(result, indent=2), encoding="utf-8")
    return passed


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("folder", type=Path)
    args = parser.parse_args()
    raise SystemExit(0 if summarize(args.folder) else 1)
