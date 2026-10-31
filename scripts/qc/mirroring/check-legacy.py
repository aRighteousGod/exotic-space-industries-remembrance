"""Separate pre-existing 2.0 upgrade differences from this patch's effects."""
import collections
import hashlib
import json
from pathlib import Path
import sys

record = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8-sig"))
root = Path(record["write_data"]) / "script-output/mirroring"
receipts = {phase: json.loads((root / f"legacy-{phase}.json").read_text())
    for phase in ("baseline", "adopt", "reload")}
baseline, candidate, reload = (receipts[phase]["cases"] for phase in ("baseline", "adopt", "reload"))
assert len(baseline) == len(candidate) == len(reload) == 352
for before, after, restored in zip(baseline, candidate, reload):
    for key in ("name", "requested_direction", "requested_mirror", "before", "after"):
        assert before[key] == after[key] == restored[key], (after["name"], key)
differences = collections.Counter(row["name"] for row in candidate if not row["passed"])
assert differences == {name: 8 for name in ("burner-mining-drill", "crusher", "ei-advanced-chem-plant",
    "ei-auric-inoculation-vat", "ei-burner-quarry", "ei-excavator", "ei-steam-miner", "ei-steam-quarry")}
report = {"engine_from": "2.0.77", "engine_to": "2.1.24", "source_from": "1.3.41", "source_to": "1.4.01",
    "patch_preserves_upgrade_behavior": True, "reload_preserves_all_migrated_states": True,
    "cases": 352, "strict_historical_parity": sum(row["passed"] for row in candidate),
    "pre_existing_upgrade_differences": dict(differences), "input_sha256": {
        f"legacy-{phase}.json": hashlib.sha256((root / f"legacy-{phase}.json").read_bytes()).hexdigest()
        for phase in receipts}}
(root / "historical-boundary.json").write_text(json.dumps(report, indent=2) + "\n")
print(json.dumps(report, indent=2))
