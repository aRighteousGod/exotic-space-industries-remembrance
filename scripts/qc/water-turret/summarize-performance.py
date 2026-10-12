"""Summarize paired water-turret fixtures; Factorio verbose timings are nanoseconds."""
from __future__ import annotations

import argparse
import csv
import json
import re
import statistics
from pathlib import Path


def duration(path: Path) -> float:
    match = re.search(r"Duration:\s*([\d.]+)ms", path.read_text(encoding="utf-8-sig"))
    if not match:
        raise ValueError(f"No profiler duration: {path}")
    return float(match.group(1))


def engine_windows(path: Path) -> list[list[float]]:
    """Keep repeated benchmark runs separate; exclude setup/report remote calls."""
    windows = []
    timings = []
    columns = None
    for line in path.read_text(encoding="utf-8-sig").splitlines():
        if line.startswith("tick,"):
            if timings:
                windows.append(timings)
            timings = []
            columns = next(csv.reader([line]))
        elif columns and re.match(r"t\d+,", line):
            values = next(csv.reader([line]))
            if 2000 < int(values[0][1:]) < 8000:
                record = dict(zip(columns, values))
                timings.append(float(record["wholeUpdate"]) / 1_000_000)
    if timings:
        windows.append(timings)
    if not windows or any(len(window) != 5999 for window in windows):
        raise ValueError(f"Incomplete warmed engine window: {path}")
    return windows


def engine_summary(timings: list[float]) -> dict:
    ordered = sorted(timings)
    return {"engine_ticks": len(timings), "engine_mean_ms": statistics.mean(timings),
            "engine_p95_ms": ordered[int(len(ordered) * .95)], "engine_max_ms": max(timings)}


def summarize(root: Path) -> dict:
    rows = []
    for scene in ("dry", "wet", "dense", "dispersed", "burst"):
        for variant in ("b", "c"):
            run = root / f"{variant}-{scene}"
            report = json.loads((run / "script-output/water-qc.json").read_text(encoding="utf-8-sig"))
            if not report["all_pass"]:
                raise ValueError(f"Acceptance failed: {run}")
            windows = engine_windows(run / "benchmark.txt")
            if len(windows) != 1:
                raise ValueError(f"Expected one paired run: {run}")
            rows.append({
                "scene": scene, "variant": "baseline" if variant == "b" else "candidate",
                "turrets": report["count"], "profile_ticks": report["ticks"],
                "updater_ms_per_tick": duration(run / "script-output/water-profile.txt") / report["ticks"],
                "fire_events_ms_per_tick": duration(run / "script-output/water-events-profile.txt") / report["ticks"],
                **engine_summary(windows[0]),
                "counters": report["counters"], "created_fires": report["births"],
            })
    repeats = {}
    for variant in ("b", "c"):
        run = root / f"{variant}-repeat"
        if not run.exists():
            continue
        report = json.loads((run / "script-output/water-qc.json").read_text(encoding="utf-8-sig"))
        if not report["all_pass"]:
            raise ValueError(f"Repeat acceptance failed: {run}")
        repeats["baseline" if variant == "b" else "candidate"] = [
            engine_summary(window) for window in engine_windows(run / "benchmark.txt")]
    return {"engine": "2.0.77", "runs_per_scene": 1, "results": rows, "dispersed_repeats": repeats}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("root", type=Path)
    args = parser.parse_args()
    print(json.dumps(summarize(args.root), indent=2))
