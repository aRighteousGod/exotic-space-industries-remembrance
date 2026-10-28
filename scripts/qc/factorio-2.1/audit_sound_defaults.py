"""Compare effective working-sound fade defaults in exact native data dumps.

This is prototype evidence. It does not claim audible playback or listening.
"""
import argparse
import json
from pathlib import Path
import final_data


def main_sounds(value):
    if not isinstance(value, dict):
        return []
    rows = value.get("main_sounds", value)
    return rows if isinstance(rows, list) else [rows]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--before", type=Path, required=True)
    parser.add_argument("--after", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    docs = json.loads(Path(".factorio-lua-docs-cache/2.1.23/prototype-api.json").read_text(encoding="utf-8"))
    prototypes = {p["name"]: p for p in docs["prototypes"]}
    def entity(p):
        return p["name"] == "EntityPrototype" or bool(p.get("parent") and entity(prototypes[p["parent"]]))
    kinds = {p["typename"] for p in prototypes.values() if p.get("typename") and entity(p)}
    final_data.FIELDS = {kind: {"name", "working_sound"} for kind in kinds}
    old, new = final_data.inventory(args.before), final_data.inventory(args.after)
    changes, shared = [], 0
    for kind in old.keys() & new.keys():
        for name in old[kind].keys() & new[kind].keys():
            before, after = old[kind][name].get("working_sound"), new[kind][name].get("working_sound")
            if not before and not after:
                continue
            shared += 1
            left, right = main_sounds(before), main_sounds(after)
            if len(left) != len(right):
                changes.append({"kind": kind, "name": name, "shape_change": True, "before": before, "after": after})
                continue
            for index, (a, b) in enumerate(zip(left, right)):
                for key, default in (("fade_in_ticks", 8), ("fade_out_ticks", 20)):
                    # These fade fields are prohibited/irrelevant for progress-matched audio.
                    if a.get("match_progress_to_activity") or b.get("match_progress_to_activity"):
                        continue
                    if a.get(key, 0) != b.get(key, default):
                        changes.append({"kind": kind, "name": name, "main_sound_index": index,
                            "field": key, "before": a.get(key, 0), "after": b.get(key, default),
                            "before_explicit": key in a, "after_explicit": key in b})
    args.output.mkdir(parents=True, exist_ok=True)
    for label, values in (("before", old), ("after", new)):
        (args.output / (label + ".json")).write_text(json.dumps(values, indent=2), encoding="utf-8")
    report = {"shared_working_sounds": shared, "changes": changes, "audible_listening": False}
    (args.output / "comparison.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
    print(json.dumps({"shared_working_sounds": shared, "fade_or_shape_changes": len(changes),
        "esir_changes": sum(r["name"].startswith("ei-") for r in changes)}))


if __name__ == "__main__":
    main()
