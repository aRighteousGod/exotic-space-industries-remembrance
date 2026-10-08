"""Inclusive Lance attribution over fixed simulation ticks, including idle zeros."""
import argparse
import json
import re
from collections import defaultdict
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument("baseline", type=Path)
parser.add_argument("candidate", type=Path)
parser.add_argument("--start", type=int, default=120)
parser.add_argument("--end", type=int, default=600)
parser.add_argument("--output", type=Path, required=True)
args = parser.parse_args()
assert args.end > args.start
profiles, snapshots = [], []
for folder in (args.baseline, args.candidate):
    text = (folder / "benchmark.log").read_text(encoding="utf-8-sig")
    assert "benchmark target population preserved" in text and "LANCE_QC FAIL" not in text
    totals, calls = defaultdict(float), defaultdict(int)
    for phase, tick, elapsed in re.findall(
            r"SINGULARITY_LANCE_PHASE phase=([\w-]+) tick=(\d+) elapsed=Duration: ([\d.]+)\s*ms", text):
        if args.start <= int(tick) < args.end:
            totals[phase] += float(elapsed)
            calls[phase] += 1
    assert "update-total" in totals
    profiles.append({"phase_ms_per_tick": {k: v / (args.end - args.start) for k, v in totals.items()},
                     "phase_ticks": dict(calls),
                     "inclusive_ms_per_tick": (totals["shot"] + totals["update-total"]) / (args.end - args.start)})
    samples = [json.loads(line.split("LANCE_BENCH SNAPSHOT ", 1)[1])
               for line in text.splitlines() if "LANCE_BENCH SNAPSHOT " in line]
    assert samples
    snapshots.append([{k: row.get(k) for k in ("counters", "pending", "pending_contacts", "sweep_count")}
                      for row in samples])
result = {"pass": snapshots[0] == snapshots[1], "start_tick": args.start, "end_tick_exclusive": args.end,
          "window_ticks": args.end - args.start, "before": profiles[0], "after": profiles[1],
          "accounting": snapshots, "scope": "Inclusive shot plus service; nested phases are not additive. No GPU or whole-factory claim."}
args.output.parent.mkdir(parents=True, exist_ok=True)
args.output.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
print(json.dumps({k: result[k] for k in ("pass", "window_ticks", "before", "after")}, indent=2))
raise SystemExit(0 if result["pass"] else 1)
