"""Compare paired native heat probes using physical fluid totals, not API views.

2.0 exposes a private input buffer separately from the external segment; 2.1
shares the segment. The fixture normalizes their initial physical fluid mass.
"""
import argparse
import hashlib
import json
from pathlib import Path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--old", type=Path, required=True)
    parser.add_argument("--new", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    documents, inputs = {}, []
    for version, root in (("2.0.77", args.old), ("2.1.23", args.new)):
        for tick in (60, 120):
            path = root / "script-output" / f"heat-parity-{tick}.json"
            blob = path.read_bytes()
            data = json.loads(blob)
            assert data["engine"] == version and data["tick"] == tick
            assert data["fluid_fuel_value"] == 1000000
            cases = {(r["name"], r["layout"]): r for r in data["cases"]}
            assert len(cases) == 16
            documents[version, tick] = cases
            inputs.append({"path": str(path.absolute()), "sha256": hashlib.sha256(blob).hexdigest()})
    rows = []
    for key in sorted(documents["2.0.77", 60]):
        row = {"name": key[0], "layout": key[1], "samples": []}
        for tick in (60, 120):
            old, new = (documents[v, tick][key] for v in ("2.0.77", "2.1.23"))
            for field in ("bonus", "energy", "physical_fluid_total", "fuel_remaining"):
                if field not in old:
                    assert field not in new
                else:
                    assert abs(old[field] - new[field]) < 1e-7, (key, tick, field, old[field], new[field])
            delta = new["temperature"] - old["temperature"]
            expected = 0.08666666666667 if key[1] == "four" else 0.05416666666667 if key[1] in ("north", "east", "south", "west") else 0
            assert abs(delta - expected) < 1e-6, (key, tick, delta, expected)
            row["samples"].append({"tick": tick, "old_temperature": old["temperature"],
                "new_temperature": new["temperature"], "temperature_delta": delta,
                "physical_fluid_total": new["physical_fluid_total"], "bonus": new["bonus"]})
        old_rise = documents["2.0.77", 120][key]["temperature"] - documents["2.0.77", 60][key]["temperature"]
        new_rise = documents["2.1.23", 120][key]["temperature"] - documents["2.1.23", 60][key]["temperature"]
        assert abs(old_rise - new_rise) < 1e-6
        row["steady_temperature_rise"] = new_rise
        rows.append(row)
    receipt = {"passed": True, "cases": rows, "inputs": inputs,
        "scope": "Paired 16 layouts at ticks 60 and 120; topology bonuses, physical fuel use and steady heat rise",
        "native_startup_difference": "Fixed +0.0541667 C with one matching neighbour and +0.0866667 C at the four-neighbour centre; consistent with earlier native bonus application, not a changed steady rate",
        "limits": ["No long-duration loaded heat-network, solar admission, graphics or multiplayer claim"]}
    args.output.write_text(json.dumps(receipt, indent=2), encoding="utf-8")
    print(json.dumps({"passed": True, "layouts": len(rows), "samples": 32, "receipt": str(args.output)}))


if __name__ == "__main__":
    main()
