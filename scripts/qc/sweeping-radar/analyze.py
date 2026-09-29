"""Join engine timings, delivered work and independent stage profiles offline."""
import argparse
import csv
import json
import math
import re
from pathlib import Path

def stats(values):
    values = sorted(values)
    return {"mean": sum(values) / len(values), "p95": values[math.ceil(len(values) * .95) - 1],
            "maximum": values[-1], "samples": len(values)} if values else None

def read_run(path):
    report = json.loads((path / "script-output/radar-qc.json").read_text(encoding="utf-8-sig"))
    offset = report["results"][0]["start_tick"] - report["warmup"]
    timing = {}
    header = None
    with (path / "benchmark.txt").open(encoding="utf-8-sig") as source:
        for line in source:
            if line.startswith("tick,timestamp,"):
                header = line.strip().split(",")
            elif header and re.match(r"^t\d+,", line):
                row = dict(zip(header, line.strip().split(",")))
                tick = offset + int(row["tick"][1:])
                timing[tick] = {k: int(row[k]) / 1_000_000 for k in ("wholeUpdate", "scriptUpdate", "chartUpdate", "mapGenerator")}
    profiles = {}
    profile_path = path / "script-output/radar-stages.csv"
    if profile_path.exists():
        with profile_path.open(encoding="utf-8-sig") as source:
            for row in csv.DictReader(source):
                values = {k: float(re.search(r"[\d.]+", value).group()) for k, value in row.items() if k != "tick"}
                values["total"] = sum(values.values())
                profiles[int(row["tick"])] = values
    for phase in report["results"]:
        # The last tick constructs the next fixture; exclude that transition.
        selected_ticks = [t for t in range(phase["start_tick"] + 1, phase["end_tick"]) if t in timing]
        selected = [timing[t] for t in selected_ticks]
        phase["engine_ms"] = {k: stats([row[k] for row in selected]) for k in ("wholeUpdate", "scriptUpdate", "chartUpdate", "mapGenerator")}
        if selected_ticks:
            peak = max(selected_ticks, key=lambda t: timing[t]["wholeUpdate"])
            phase["peak_engine_tick"] = {"tick": peak, "engine_ms": timing[peak]}
        sampled = [profiles[t] for t in range(phase["start_tick"] + 1, phase["end_tick"]) if t in profiles]
        phase["stages_ms"] = {k: stats([row[k] for row in sampled]) for k in sampled[0]} if sampled else {}
        phase.pop("stages", None)  # Old pilot runs used unusable tostring(LuaProfiler).
    report["run"] = path.name
    return report

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("runs", nargs="+", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    reports = [read_run(path) for path in args.runs]
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(reports, indent=2), encoding="utf-8")
    for report in reports:
        print(report["run"], "baseline" if report["baseline"] else "candidate")
        for phase in report["results"]:
            engine = phase["engine_ms"]["wholeUpdate"]
            print(f'{phase["population"]:3} {phase["workload"]:12} {engine["mean"]:.4f} ms mean; '
                  f'{engine["p95"]:.4f} p95; {phase["observations_per_second"]:.2f} observations/s')
