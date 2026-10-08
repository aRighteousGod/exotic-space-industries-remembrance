"""Reduce actual native per-tick gait traces; speed and position are separate."""
import argparse
import json
import math
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument("--report", type=Path, required=True)
parser.add_argument("--output", type=Path, required=True)
args = parser.parse_args()
report = json.loads(args.report.read_text(encoding="utf-8-sig"))
rows = []
for record in report["records"]:
    phases = {}
    for phase, stat in record["metrics"].items():
        n = stat["count"]
        mean = stat["sum"] / n
        sd = math.sqrt(max(0, stat["sum2"] / n - mean * mean))
        phases[phase] = {"mean": mean, "sd": sd, "cv": sd / mean if mean else 0,
                         "ripple": (stat["max"] - stat["min"]) / mean if mean else 0,
                         "min": stat["min"], "max": stat["max"], "zero_ticks": stat["zero_ticks"],
                         "velocity_jump": stat["max_delta"], "distance": stat["distance"]}
    rows.append({**{k: record[k] for k in ("key", "profile", "heading", "equipped", "trace")}, "phases": phases})
lookup = {(r["profile"]["id"], r["heading"], r["equipped"]): r for r in rows}
groups = {}
for r in rows:
    key = r["profile"]["id"]
    group = groups.setdefault(key, {"profile": r["profile"], "comparisons": []})
    base = lookup[("four", r["heading"], r["equipped"])]
    saucer = lookup[("saucer", r["heading"], r["equipped"])]
    cruise = r["phases"]["cruise"]
    ratio = cruise["mean"] / saucer["phases"]["cruise"]["mean"]
    group["comparisons"].append({"heading": r["heading"], "equipped": r["equipped"], "ratio": ratio,
        "cv": cruise["cv"], "ripple": cruise["ripple"], "baseline_cv": base["phases"]["cruise"]["cv"],
        "velocity_jump": cruise["velocity_jump"], "baseline_velocity_jump": base["phases"]["cruise"]["velocity_jump"],
        "turn_distance_ratio": sum(r["phases"][p]["distance"] for p in ("turn45", "turn90", "turn180")) /
                               sum(base["phases"][p]["distance"] for p in ("turn45", "turn90", "turn180")),
        "stop_distance": r["phases"]["stop"]["distance"], "baseline_stop_distance": base["phases"]["stop"]["distance"],
        "restart_distance_ratio": r["phases"]["restart"]["distance"] / base["phases"]["restart"]["distance"]})
for key, group in groups.items():
    c = group["comparisons"]
    group["summary"] = {"mean_ratio": sum(x["ratio"] for x in c) / len(c),
        "min_ratio": min(x["ratio"] for x in c), "max_ratio": max(x["ratio"] for x in c),
        "mean_cv": sum(x["cv"] for x in c) / len(c), "max_ripple": max(x["ripple"] for x in c),
        "mean_turn_distance_ratio": sum(x["turn_distance_ratio"] for x in c) / len(c),
        "mean_restart_distance_ratio": sum(x["restart_distance_ratio"] for x in c) / len(c),
        "speed_band_pass": all(.45 <= x["ratio"] <= .55 for x in c)}
    print(key, json.dumps(group["summary"]), flush=True)
args.output.parent.mkdir(parents=True, exist_ok=True)
args.output.write_text(json.dumps({"report": str(args.report), "groups": groups, "records": rows}, indent=2), encoding="utf-8")
