"""Strict matched-fleet parity and inclusive LuaProfiler attribution."""
import argparse
import json
import re
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument("baseline", type=Path)
parser.add_argument("candidate", type=Path)
parser.add_argument("--output", type=Path)
args = parser.parse_args()
reports = [json.loads((path / "script-output/anisetron-qc.json").read_text(encoding="utf-8-sig"))
           for path in (args.baseline, args.candidate)]
before, after = reports
checks = {
    "completed": all(r.get("complete") and r.get("all_pass") for r in reports),
    "fleet": before["fleet"] == after["fleet"],
    "samples": bool(before["samples"]) and before["samples"] == after["samples"],
    "damage": bool(before["damage"]) and before["damage"] == after["damage"],
}
profiles, windows = [], []
for path in (args.baseline, args.candidate):
    content = (path / "benchmark.txt").read_text(encoding="utf-8-sig")
    windows.append({phase: int(ticks) for phase, ticks in re.findall(
        r"ANISETRON_UPS_WINDOW ([\w-]+) ticks=(\d+)", content)})
    profiles.append({(phase, module): {"calls": int(calls), "ms": float(ms)}
                     for phase, module, calls, ms in re.findall(
                         r"ANISETRON_UPS ([\w-]+) (\w+) calls=(\d+) Duration: ([\d.]+)ms", content)})
timings = []
for key, old in profiles[0].items():
    new = profiles[1][key]
    # Historical runs of this fixture used fixed 900-tick windows. New runs
    # report simulation ticks; skipped idle calls are intentionally permitted.
    old_ticks, new_ticks = (window.get(key[0], 900) for window in windows)
    checks["window:" + key[0]] = old_ticks == new_ticks and old_ticks > 0
    timings.append({"phase": key[0], "module": key[1], "window_ticks": old_ticks,
                    "before_calls": old["calls"], "after_calls": new["calls"],
                    "before_ms_per_tick": old["ms"] / old_ticks,
                    "after_ms_per_tick": new["ms"] / new_ticks,
                    "change_percent": (new["ms"] / old["ms"] - 1) * 100 if old["ms"] else None})
result = {"pass": all(checks.values()), "checks": checks, "fleet": before["fleet"],
          "sampled_ticks": len(before["samples"]), "damage_packets": len(before["damage"]),
          "timings": timings, "timing_scope": "Inclusive instrumented module costs; nested timers are not additive"}
if args.output:
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
print(json.dumps(result, indent=2))
raise SystemExit(0 if result["pass"] else 1)
