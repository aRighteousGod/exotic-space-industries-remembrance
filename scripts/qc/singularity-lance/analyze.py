"""Summarize matched Factorio stdout and opt-in lance phase timings."""
import argparse
import collections
import hashlib
import json
import math
import pathlib
import re
import statistics

parser = argparse.ArgumentParser()
parser.add_argument("--root", type=pathlib.Path, default=pathlib.Path(".factorio-qc/lance"))
parser.add_argument("--output", type=pathlib.Path, default=pathlib.Path(".factorio-qc/singularity-lance/results.json"))
args = parser.parse_args()
scenes = ["no-lance", "idle", "direct", "normal-power", "dense", "diagonal", "research"]
result = {"engine": "2.0.77", "warmup_runs_discarded": 1,
          "measurement": "Whole-game ms/update; five 720-tick runs after one full warmup run",
          "counter_window": "Candidate counters at tick 600, reset after tick 120",
          "scenes": {}, "profiles": {}, "validation": {"fidelities": {}, "technology_variants": {}}}
for fidelity in ["lean", "standard", "cinematic", "maximal", "unbounded"]:
    path = args.root / f"c-m-dense-{fidelity}-00" / "benchmark-stdout.txt"
    if path.exists():
        content = path.read_text(errors="replace")
        result["validation"]["fidelities"][fidelity] = {
            "passed_assertions": content.count("LANCE_QC PASS"),
            "complete": "LANCE_QC ALL_COMPLETE" in content,
            "secondary_destruction_regression": "PASS secondary reaction removes primary before wound cue" in content,
        }
for flags in ["00", "01", "10", "11"]:
    path = args.root / f"c-m-dense-standard-{flags}" / "benchmark-stdout.txt"
    if path.exists():
        content = path.read_text(errors="replace")
        result["validation"]["technology_variants"][flags] = {
            "scaling": flags[0] == "0", "flattening": flags[1] == "1",
            "final_technology_records": re.findall(r"LANCE_TECH (.+)", content),
        }
path = args.root / "c-r-dense-standard-00/benchmark-stdout.txt"
if path.exists():
    content = path.read_text(errors="replace")
    result["validation"]["counter_seven_reload"] = {
        "passed_assertions": content.count("LANCE_QC PASS"), "complete": "LANCE_QC RELOAD_COMPLETE" in content,
    }
for scene in scenes:
    row = {}
    for version, prefix in [("baseline", "b"), ("candidate", "c")]:
        path = args.root / f"{prefix}-b-{scene}-standard-00" / "benchmark-stdout.txt"
        if not path.exists():
            continue
        content = path.read_text(errors="replace")
        samples = [float(x) for x in re.findall(r"avg: ([\d.]+) ms", content)]
        measured = samples[1:]
        if measured:
            if len(measured) != 5:
                raise ValueError(f"Incomplete five-run benchmark: {path} ({len(measured)} measured runs)")
            row[version] = {"all_run_means_ms": samples, "measured_runs": len(measured),
                            "median_ms": statistics.median(measured), "mean_ms": statistics.mean(measured),
                            "min_ms": min(measured), "max_ms": max(measured)}
            source = path.parent / "mods/exotic-space-industries-remembrance/scripts/control/singularity-lance.lua"
            if source.exists():
                row[version]["runtime_sha256"] = hashlib.sha256(source.read_bytes()).hexdigest()
            snapshots = re.findall(r"LANCE_BENCH SNAPSHOT (.+)", content)
            if snapshots:
                snapshot = json.loads(snapshots[-1])
                row[version]["counters"] = snapshot["counters"]
                if version == "candidate":
                    row[version]["registered_lances"] = snapshot["registered_lances"]
                    row[version]["pending_paid_collapses"] = snapshot["pending"]
    if "baseline" in row and "candidate" in row:
        row["median_change_percent"] = 100 * (row["candidate"]["median_ms"] / row["baseline"]["median_ms"] - 1)
    result["scenes"][scene] = row


def distribution(values):
    values = sorted(values)
    return {"mean_ms": statistics.mean(values), "p95_ms": values[math.ceil(.95 * len(values)) - 1],
            "max_ms": values[-1], "ticks": len(values)}


for folder in sorted(args.root.glob("c-b-*-profile")):
    path = folder / "benchmark-stdout.txt"
    if not path.exists():
        continue
    content = path.read_text(errors="replace")
    ticks = re.findall(r"Performed (\d+) updates", content)
    if not ticks:
        continue
    stop = int(ticks[-1]) - 1  # the final extra engine tick flushes stopped timers
    phases = collections.defaultdict(lambda: collections.defaultdict(float))
    for phase, tick, duration in re.findall(
            r"SINGULARITY_LANCE_PHASE phase=([\w-]+) tick=(\d+) elapsed=Duration: ([\d.]+)\s*ms", content):
        phases[phase][int(tick)] += float(duration)
    totals = {phase: distribution([values[t] for t in range(120, stop)]) for phase, values in phases.items()}
    if phases:
        totals["all-lance"] = distribution([phases["shot"][t] + phases["update-total"][t] for t in range(120, stop)])
        totals["shot-mechanics"] = distribution([max(0, phases["shot"][t] - phases["shot-core"][t]) for t in range(120, stop)])
    result["profiles"][folder.name] = totals
args.output.parent.mkdir(parents=True, exist_ok=True)
args.output.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
print(args.output)
for scene, row in result["scenes"].items():
    if "median_change_percent" in row:
        print(f"{scene:14} {row['baseline']['median_ms']:.3f} -> {row['candidate']['median_ms']:.3f} ms "
              f"({row['median_change_percent']:+.1f}%)")
for name, phases in result["profiles"].items():
    print(name, json.dumps(phases, separators=(",", ":")))
