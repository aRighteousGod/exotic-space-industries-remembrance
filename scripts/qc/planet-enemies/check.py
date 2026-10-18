"""Check native generation and preserved enemy presentation against frozen ESIR."""
import argparse
import json
import math
import runpy
from pathlib import Path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("baseline", type=Path)
    parser.add_argument("candidate", type=Path)
    parser.add_argument("--snapshot", type=Path)
    parser.add_argument("--baseline-dump", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    before = json.loads(args.baseline.read_text())
    after = json.loads(args.candidate.read_text())
    baseline = {(c["planet"], c["seed"]): c for c in before["cases"] if c["case"] == "default"}
    cases = {(c["planet"], c["seed"], c["case"]): c for c in after["cases"]}
    checks = []

    def check(name, passed):
        checks.append({"name": name, "pass": bool(passed)})

    for (planet, seed, kind), case in cases.items():
        label = f"{planet}/{seed}/{kind}"
        normal = cases[planet, seed, "default"]
        check(label + "/exchange", case["roundtrip"])
        check(label + "/finite", all(math.isfinite(x) for v in case["noise"].values() for x in v))
        if kind == "default":
            old = baseline[planet, seed]
            check(label + "/noise", old["noise"] == case["noise"])
            check(label + "/nests", old["entities"] == case["entities"])
            check(label + "/territories", old["territories"] == case["territories"])
        if kind == "foreign-off":
            check(label + "/isolation", normal["noise"] == case["noise"])
        enemy = {k: v for k, v in case["noise"].items() if k.startswith("entity:")}
        if kind in {"off", "frequency-zero", "size-zero"}:
            if planet == "gleba":
                check(label + "/raft-probabilities", all(v == normal["noise"][k] for k, v in enemy.items()))
                if kind == "off":
                    check(label + "/raft-positions", case["entities"] == normal["entities"])
            else:
                check(label + "/no-nest-probability", all(x <= 0 for v in enemy.values() for x in v))
                if kind == "off":
                    check(label + "/no-nests", not case["entities"])
            if planet == "vulcanus":
                check(label + "/no-demolisher-variation", all(x < 0 for x in case["noise"]["demolisher_variation_expression"]))
                check(label + "/no-demolishers", not any(t["units"] for t in case["territories"]))
        if kind in {"frequency-low", "frequency-high", "size-low", "size-high"}:
            check(label + "/slider-changes-placement", any(v != normal["noise"][k] for k, v in enemy.items()))
        if planet == "vulcanus":
            radius = case["noise"]["demolisher_territory_radius"]
            check(label + "/radius-bounds", all(128 <= x <= 65535 for x in radius))
            if kind == "frequency-low":
                check(label + "/same-partition", case["noise"]["demolisher_territory_expression"] == normal["noise"]["demolisher_territory_expression"])
                check(label + "/fewer-occupied-cells", sum(x >= 0 for x in case["noise"]["demolisher_variation_expression"]) < sum(x >= 0 for x in normal["noise"]["demolisher_variation_expression"]))
            if kind == "explosive-only-off":
                check(label + "/demolisher-isolation", all(v == normal["noise"][k] for k, v in case["noise"].items() if k.startswith("demolisher")))
            if kind == "demolisher-only-off":
                check(label + "/explosive-isolation", all(v == normal["noise"][k] for k, v in enemy.items()))

    if args.snapshot:
        snapshot = json.loads(args.snapshot.read_text())
        fields = {key for row in snapshot["entities"].values() for key in row if key != "type"}
        names = {(row["type"], name) for name, row in snapshot["entities"].items()}
        extract = runpy.run_path(str(Path(__file__).parents[1] / "entity-presentation/check.py"))["baseline_rows"]
        old = extract(args.baseline_dump, names, fields)
        check("presentation/body-coverage", set(old) == set(snapshot["entities"]))
        for name, row in snapshot["entities"].items():
            original = old.get(name, {})
            check(name + "/preserved-gameplay-and-presentation", all(row.get(k) == original.get(k) for k in fields if k != "created_effect"))
            def actions(value):
                return ([value] if isinstance(value, dict) else value) if value else []
            effects = actions(row.get("created_effect"))
            notification = {"type": "direct", "action_delivery": {"type": "instant", "target_effects": [{"type": "script", "effect_id": "ei-planet-enemy-created"}]}}
            expected = 0 if row["type"] == "segmented-unit" else 1
            check(name + "/creation-notification", effects.count(notification) == expected)
            check(name + "/existing-creation-effects", [e for e in effects if e != notification] == actions(original.get("created_effect")))
        check("menu/six-controls", len(snapshot["controls"]) == 6)
        check("menu/checks-and-sliders", all(c["can_be_disabled"] and c["category"] == "enemy" and not c.get("richness") for c in snapshot["controls"].values()))
        check("menu/gaia-default-size-five", snapshot["planets"]["gaia"]["autoplace_controls"]["ei-gaia-electric-enemies"]["size"] == 5)

    result = {"all_pass": all(c["pass"] for c in checks), "checks": checks, "cases": len(cases)}
    args.output.write_text(json.dumps(result, indent=2) + "\n")
    failures = [c["name"] for c in checks if not c["pass"]]
    print(json.dumps({"all_pass": result["all_pass"], "checks": len(checks), "cases": len(cases), "failures": failures}))
    raise SystemExit(0 if result["all_pass"] else 1)


if __name__ == "__main__":
    main()
