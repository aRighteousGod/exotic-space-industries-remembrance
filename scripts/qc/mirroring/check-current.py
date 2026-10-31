"""Verify a later standard profile against the accepted prototype snapshots."""
import hashlib
import json
from pathlib import Path
import sys

old, current = (json.loads(Path(path).read_text(encoding="utf-8-sig")) for path in sys.argv[1:3])
old_root, root = (Path(record["write_data"]) / "script-output/mirroring" for record in (old, current))
info = json.loads((Path(current["mods"]) / "exotic-space-industries-remembrance/info.json").read_text())
report = {"passed": True, "engine": "2.1.24", "mod_version": info["version"],
    "run_id": current["run_id"], "profiles": {}, "input_sha256": {}}
for quality in ("enabled", "disabled"):
    tag = f"candidate-quality-{quality}"
    before, after = (json.loads((folder / (tag + "-final.json")).read_text()) for folder in (old_root, root))
    assert before == after, "Assessed final prototypes changed with the dependency refresh"
    results = {}
    for suffix in ("reload", "transport", "heat", "furnaces"):
        path = root / (tag + "-" + suffix + ".json")
        receipt = json.loads(path.read_text())
        assert receipt["passed"], suffix
        results[suffix] = receipt.get("counts", {"cases": len(receipt.get("cases", []))})
        report["input_sha256"][path.name] = hashlib.sha256(path.read_bytes()).hexdigest()
    path = root / (tag + "-final.json")
    report["input_sha256"][path.name] = hashlib.sha256(path.read_bytes()).hexdigest()
    report["profiles"][quality] = {"prototypes_identical": len(after["entities"]), "native": results}
(root / "current-profile.json").write_text(json.dumps(report, indent=2) + "\n")
print(json.dumps(report, indent=2))
