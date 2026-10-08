"""Attribute ecology service time separately from native fixture/map setup."""
import json
import math
from pathlib import Path
import re
import sys

run = Path(sys.argv[1])
raw = (run / "benchmark.txt").read_bytes()
log = raw.decode("utf-16") if raw.startswith(b"\xff\xfe") else raw.decode("utf-8-sig")
report = json.loads((run / "script-output/terrain-qc.json").read_text(encoding="utf-8-sig"))
timings = {}
for lane, duration in re.findall(r"TERRAIN_ECOLOGY_PROFILE lane=(\w+) tick=\d+ elapsed=Duration: ([\d.]+)ms", log):
    timings.setdefault(lane, []).append(float(duration))
result = {}
for lane, fixture in report["cases"].items():
    values = sorted(timings[lane])
    assert len(values) == fixture["services"], (lane, len(values), fixture["services"])
    metrics = dict(mean_ms_per_tick=sum(values)/fixture["ticks"],
                   service_p99_ms=values[math.ceil(.99*len(values))-1],
                   service_max_ms=values[-1], services=len(values), ticks=fixture["ticks"])
    metrics["pass"] = bool(fixture["pass"] and metrics["mean_ms_per_tick"] <= .1
                           and metrics["service_p99_ms"] <= .5 and metrics["service_max_ms"] <= 2)
    result[lane] = metrics
text = json.dumps(result, indent=2)
(run / "profile-analysis.json").write_text(text + "\n", encoding="utf-8")
print(text)
if not all(lane["pass"] for lane in result.values()):
    raise SystemExit(1)
