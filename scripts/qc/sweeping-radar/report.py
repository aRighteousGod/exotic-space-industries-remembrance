"""Assemble compact, reproducible evidence from completed radar QC runs."""
import argparse
import hashlib
import json
import os
from pathlib import Path
from analyze import read_run

parser = argparse.ArgumentParser()
parser.add_argument("root", type=Path)
parser.add_argument("output", type=Path)
args = parser.parse_args()
root = args.root
def read(path):
    return json.loads(path.read_text(encoding="utf-8-sig"))
def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

runs = [read_run(root / name) for name in ("matrix-b7", "matrix-c7", "matrix-p4", "matrix-b8", "matrix-c8")]
expected_cases = [(population, workload) for population in (1, 10, 50, 100)
                  for workload in ("idle", "warm", "exploration", "dense", "churn", "completion")]
for run in runs:
    assert run["all_pass"]
    assert [(case["population"], case["workload"]) for case in run["results"]] == expected_cases, "Incomplete or reordered matrix"
    for case in run["results"]:
        assert all(value["samples"] == 2399 for value in case["engine_ms"].values()), "Incomplete engine timings"
        if run["run"] == "matrix-p4":
            assert all(value["samples"] == 2399 for value in case["stages_ms"].values()), "Incomplete stage timings"
    path = root / run["run"]
    process_file = path / "concurrent-processes.json"
    run["other_processes_at_start"] = read(process_file) if process_file.exists() and process_file.stat().st_size > 4 else []
    run["fixture_sha256"] = digest(path / "fixture.zip")
    run["mod_list_sha256"] = digest(path / "mods/mod-list.json")
    run["helper_sha256"] = {p.name: digest(p) for p in sorted((path / "mods/zzz-esir-radar-qc").glob("*.lua"))}
baseline, candidate, profile, repeat_baseline, repeat_candidate = runs
for a, b, c in zip(baseline["results"], candidate["results"], profile["results"]):
    assert (a["population"], a["workload"]) == (b["population"], b["workload"]) == (c["population"], c["workload"])
    assert b["observations_per_second"] == c["observations_per_second"], "Profiler changed delivered work"
    if b["workload"] not in ("idle", "churn"):
        assert min(b["measurement_observations"]) > 0, "Ready radar did not progress during measurement"
for a, b in zip(candidate["results"], repeat_candidate["results"]):
    assert a["observations_per_second"] == b["observations_per_second"], "Repeat changed delivered work"
    assert a["measurement_observations"] == b["measurement_observations"], "Repeat changed per-radar progress"

radar_files = sorted(Path("exotic-space-industries-remembrance").rglob("sweeping-radar*"))
radar_hashes = {}
for path in radar_files:
    if not path.is_file():
        continue
    relative = path.relative_to("exotic-space-industries-remembrance")
    radar_hashes[relative.as_posix()] = digest(path)
    assert digest(root / "source-final4" / relative) == digest(path), "Radar source changed after benchmark freeze"
integration_hashes = {}
for relative in ("control.lua", "data.lua", "scripts/control/informatron.lua"):
    integration_hashes[relative] = digest(Path("exotic-space-industries-remembrance") / relative)
    assert integration_hashes[relative] == digest(root / "source-final4" / relative), "Dispatcher/integration changed after benchmark freeze"

long_pass_runs = [read_run(root / name) for name in ("long-warm-final", "long-dense-final", "dispersed-final")]
for run in long_pass_runs:
    assert run["all_pass"] and len(run["results"]) == 1
    case = run["results"][0]
    assert min(case["measurement_observations"]) > 0
    assert case["engine_ms"]["wholeUpdate"]["samples"] == run["measurement"] - 1
    if run["run"] in ("long-warm-final", "long-dense-final"):
        assert case["passes"]["samples"] == case["population"], "A radar did not complete a full pass in the long run"
    path = root / run["run"]
    run["helper_sha256"] = {p.name: digest(p) for p in sorted((path / "mods/zzz-esir-radar-qc").glob("*.lua"))}

result = {
    "engine": "2.0.77 build 84539", "esir": "1.3.40",
    "processor": os.environ.get("PROCESSOR_IDENTIFIER"),
    "logical_processors": os.environ.get("NUMBER_OF_PROCESSORS"),
    "source_manifest_sha256": digest(root / "source-final4-manifest.json"),
    "source_files": read(root / "source-final4-manifest.json"),
    "final_radar_sha256": radar_hashes,
    "integration_sha256": integration_hashes,
    "final_prototypes": read(root / "final-prototypes.json"),
    "fairness_regression": read(root / "fairness-ring/script-output/radar-qc.json"),
    "gate": read(root / "gate-release/script-output/radar-qc.json"),
    "acceptance": read(root / "acceptance-final/script-output/radar-qc.json"),
    "persistence": {name: read(root / f"persist-final3-{name}/script-output/radar-qc.json") for name in ("save", "load", "config", "legacy")},
    "visual": read(root / "visual6/script-output/radar-qc.json"),
    "generation_persistence": {name: read(root / f"generation-{name}/script-output/radar-qc.json") for name in ("save", "load")},
    "final_paid_migration": read(root / "persist-final4-load/script-output/radar-qc.json"),
    "final_paid_configuration": read(root / "persist-final4-config/script-output/radar-qc.json"),
    "limitations": [
        "Timing runs share the workstation with other Factorio activity; no isolated-machine performance guarantee.",
        "Baseline retains native radar/helper entities but disables the radar service.",
        "QC sampling and other enabled mods contribute to whole-engine time on both sides.",
        "Profiling is a separate run and never controls simulation work.",
        "Visual input/GUI events are driven programmatically, not through physical mouse interaction.",
        "Robot upgrades use a transaction fixture, not a flying robot.",
        "No multiplayer desynchronization or native-speaker translation approval is claimed.",
    ],
    "runs": runs,
    "long_pass_runs": long_pass_runs,
}
for run in runs:
    assert run["all_pass"]
for name in ("gate", "acceptance", "visual", "fairness_regression", "final_paid_migration", "final_paid_configuration"):
    assert result[name]["all_pass"], name
for name, item in result["persistence"].items():
    assert item["all_pass"], name
for name, item in result["generation_persistence"].items():
    assert item["all_pass"], name
args.output.write_text(json.dumps(result, indent=2, ensure_ascii=False), encoding="utf-8")
print("| Fleet | Workload | Baseline mean ms (runs 1 / 2) | Candidate mean ms (runs 1 / 2) | Candidate p95 / worst ms (max across runs) | Radar stages mean / p95 ms | Observations/s |")
print("|---:|---|---|---|---|---|---:|")
for a, b, c, d, e in zip(baseline["results"], candidate["results"], profile["results"], repeat_baseline["results"], repeat_candidate["results"]):
    first = b["engine_ms"]["wholeUpdate"]
    second = e["engine_ms"]["wholeUpdate"]
    p = c["stages_ms"]["total"]
    print(f"| {b['population']} | {b['workload']} | {a['engine_ms']['wholeUpdate']['mean']:.3f} / {d['engine_ms']['wholeUpdate']['mean']:.3f} | "
          f"{first['mean']:.3f} / {second['mean']:.3f} | {max(first['p95'], second['p95']):.3f} / {max(first['maximum'], second['maximum']):.3f} | "
          f"{p['mean']:.3f} / {p['p95']:.3f} | {b['observations_per_second']:.2f} |")
print("Evidence written:", args.output)
