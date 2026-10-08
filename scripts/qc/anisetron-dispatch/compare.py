"""Compare exact central-dispatch and shared-target traces across source trees."""
import argparse
import json
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument("baseline", type=Path)
parser.add_argument("candidate", type=Path)
parser.add_argument("--output", type=Path, required=True)
args = parser.parse_args()
before, after = [json.loads(path.read_text(encoding="utf-8-sig"))
                 for path in (args.baseline, args.candidate)]
checks = {"complete": all(r.get("all_pass") and r.get("complete") for r in (before, after))}
for key in ("dispatch", "ledger", "samples", "adapter"):
    checks[key] = bool(before[key]) and before[key] == after[key]
result = {"pass": all(checks.values()), "checks": checks,
          "dispatch_ticks": len(after["dispatch"]), "damage_packets": len(after["ledger"]),
          "samples": len(after["samples"]), "candidate_checks": after["count"]}
args.output.parent.mkdir(parents=True, exist_ok=True)
args.output.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
print(json.dumps(result, indent=2))
raise SystemExit(0 if result["pass"] else 1)
