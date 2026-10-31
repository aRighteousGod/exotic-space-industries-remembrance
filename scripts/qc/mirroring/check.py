"""Compare complete native final-data snapshots with an exact allowed delta."""
import argparse
import copy
import hashlib
import json
from pathlib import Path
import re

parser = argparse.ArgumentParser()
parser.add_argument("record", type=Path)
args = parser.parse_args()
record = json.loads(args.record.read_text(encoding="utf-8-sig"))
root = Path(record["write_data"]) / "script-output/mirroring"
names = re.findall(r'"([^"]+)"', Path(__file__).with_name("cases.lua").read_text())
assert len(names) == 18
report = {"engine": "2.1.24", "passed": True, "profiles": {}, "input_sha256": {}}
for quality in ("enabled", "disabled"):
    baseline_path = root / f"baseline-quality-{quality}-final.json"
    candidate_path = root / f"candidate-quality-{quality}-final.json"
    baseline = json.loads(baseline_path.read_text())
    candidate = json.loads(candidate_path.read_text())
    assert baseline["quality"] == candidate["quality"] == (quality == "enabled")
    assert baseline["entities"].keys() == candidate["entities"].keys()
    changes = []
    for name, before in baseline["entities"].items():
        after = candidate["entities"][name]
        if before == after:
            assert name not in names and name != "ei-steam-oil-pumpjack"
            continue
        permitted = copy.deepcopy(before)
        if name in names:
            assert not before.get("use_mirroring", False)
            permitted["use_mirroring"] = True
            changes.append({"name": name, "field": "use_mirroring"})
        elif name == "ei-steam-oil-pumpjack":
            permitted["graphics_set_flipped"] = copy.deepcopy(before["graphics_set"])
            assert after["use_mirroring"] and after["migrate_horizontal_mirroring"]
            changes.append({"name": name, "field": "graphics_set_flipped"})
        else:
            raise AssertionError("Unexpected changed prototype: " + name)
        assert permitted == after, "Unexpected prototype field delta: " + name
    assert len(changes) == 19
    receipts = {}
    for mode in ("baseline", "candidate"):
        path = root / f"{mode}-quality-{quality}-reload.json"
        receipt = json.loads(path.read_text())
        assert receipt["engine"] == "2.1.24" and receipt["quality"] == (quality == "enabled")
        assert receipt["passed"], receipt["failures"][:20]
        receipts[mode] = receipt["counts"]
        report["input_sha256"][path.name] = hashlib.sha256(path.read_bytes()).hexdigest()
    for path in (baseline_path, candidate_path):
        report["input_sha256"][path.name] = hashlib.sha256(path.read_bytes()).hexdigest()
    for suffix, count in (("transport", 32), ("heat", 16), ("furnaces", 24)):
        path = root / f"candidate-quality-{quality}-{suffix}.json"
        receipt = json.loads(path.read_text())
        assert receipt["passed"] and len(receipt["cases"]) == count, suffix
        if suffix == "transport":
            assert sum(row["upgraded"] for row in receipt["cases"]) == 8
        elif suffix == "furnaces":
            for row in receipt["cases"]:
                assert row["success"] and row["recipe"]
                expected = copy.deepcopy(row["before"]["ports"])
                for ports in expected:
                    for port in ports:
                        for key in (("x", "tx") if row["horizontal"] else ("y", "ty")):
                            port[key] = -port[key]
                assert expected == row["after"]["ports"]
                assert row["before"]["ports"] == row["restored"]["ports"]
        receipts[suffix] = {"cases": count, "passed": True}
        report["input_sha256"][path.name] = hashlib.sha256(path.read_bytes()).hexdigest()
    report["profiles"][quality] = {"prototypes": len(baseline["entities"]), "changes": changes, "native": receipts}
(root / "acceptance.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
print(json.dumps(report["profiles"], indent=2))
