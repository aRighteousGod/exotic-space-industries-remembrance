"""Check engine snapshots; optionally prove the entire before/after cost delta."""
import argparse
import copy
import hashlib
import json
from pathlib import Path

PACK = "metallurgic-science-pack"


def name(ingredient):
    return ingredient[0] if isinstance(ingredient, list) else ingredient["name"]


def check(path):
    data = json.loads(path.read_text(encoding="utf-8"))
    technologies = data["final"]
    for stage in ("updates", "final"):
        assert data["initial_science_templates"] == data[stage + "_science_templates"], stage
    settings = data["settings"]
    metallurgic = technologies[PACK]
    if settings["no_triggers"]:
        assert "unit" in metallurgic and "research_trigger" not in metallurgic
    else:
        assert metallurgic["research_trigger"] == {"type": "craft-item", "item": "tungsten-plate"}
        assert "unit" not in metallurgic
    expected = data["initial_science_templates"]["computer-age"] + [[PACK, 1]]
    acid = technologies["ei-acid-neutralisation-t2"]
    assert acid["unit"]["ingredients"] == expected, acid
    # The existing flatten pass only maps unit-based science unlocks. With
    # native triggers retained it omits this direct edge, while the required
    # science ingredient still gates the acid technology. Do not redefine that
    # separate mode here; assert the normal tree and flattened unit-based tree.
    if not settings["flatten"] or settings["no_triggers"]:
        assert PACK in acid["prerequisites"], acid
    coverage = {}
    for science in data["science"]:
        # Same-identity unlocks cover all vanilla planetary science and the two
        # ESIR Computer Age variants. Other ESIR packs use separate age gates.
        if science not in technologies:
            continue
        pending, seen = [science], set()
        while pending:
            current = pending.pop()
            if current in seen:
                continue
            seen.add(current)
            tech = technologies[current]
            ingredients = tech.get("unit", {}).get("ingredients", [])
            assert science not in map(name, ingredients), (science, current, ingredients)
            pending.extend(tech.get("prerequisites", []))
        coverage[science] = len(seen)
    return data, {"snapshot": str(path), "passed": True, "settings": settings,
                  "science_ancestor_coverage": coverage}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("snapshots", nargs="+", type=Path)
    parser.add_argument("--before", type=Path)
    parser.add_argument("--native", type=Path)
    parser.add_argument("--reload", type=Path)
    parser.add_argument("--checkpoint", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    results = []
    fixed = None
    for path in args.snapshots:
        data, result = check(path)
        fixed = fixed or data
        results.append(result)
    report = {"cases": results}
    if len(results) == 4:
        assert {(r["settings"]["no_triggers"], r["settings"]["flatten"]) for r in results} == {
            (False, False), (False, True), (True, False), (True, True)}
    if args.before:
        before = json.loads(args.before.read_text(encoding="utf-8"))
        assert before["final"].keys() == fixed["final"].keys()
        assert before["recipes"] == fixed["recipes"], "Recipe definition changed"
        changed = []
        retained = []
        for tech_name, old in before["final"].items():
            new = fixed["final"][tech_name]
            if old != new:
                expected = copy.deepcopy(old)
                ingredients = expected["unit"]["ingredients"]
                assert PACK in map(name, ingredients), tech_name
                expected["unit"]["ingredients"] = [i for i in ingredients if name(i) != PACK]
                assert new == expected, (tech_name, "Change beyond removing unintended Metallurgic science")
                changed.append(tech_name)
            elif PACK in map(name, new.get("unit", {}).get("ingredients", [])):
                retained.append(tech_name)
        assert changed and PACK in changed
        report["before_after"] = {"removed_unintended_cost": sorted(changed),
                                  "retained_metallurgic_cost": sorted(retained),
                                  "all_other_captured_technology_fields_unchanged": True,
                                  "all_captured_recipe_fields_unchanged": True}
        try:
            check(args.before)
        except AssertionError as error:
            assert str(error) == "updates", error
            report["negative_control"] = "Original template mutation rejected at data-updates"
        else:
            raise AssertionError("Original regression was not detected")
    if any((args.native, args.reload, args.checkpoint)):
        assert all((args.native, args.reload, args.checkpoint)), "Supply all three native receipts"
        native = json.loads(args.native.read_text(encoding="utf-8"))
        reloaded = json.loads(args.reload.read_text(encoding="utf-8"))
        checkpoint = json.loads(args.checkpoint.read_text(encoding="utf-8"))
        assert native["passed"] and native["completion"]["by_script"] is False
        assert native["accepted"] == reloaded["expected"] == reloaded["actual"]
        state = reloaded["actual"]
        assert state["progress"] == 0.375
        assert state["queue"] == ["ei-acid-neutralisation-t2"]
        assert set(state["inventory"].values()) == {30}
        assert len(state["inventory"]) == 4 and state["metallurgic_recipe_enabled"]
        assert checkpoint["passed"]
        assert hashlib.sha256(Path(checkpoint["checkpoint"]).read_bytes()).hexdigest() == checkpoint["checkpoint_sha256"]
        report["native"] = {"passed": True, "reload_exact_match": True,
                            "researched_technologies": len(state["researched"]),
                            "queue": state["queue"], "progress": state["progress"],
                            "inventory": state["inventory"], "completion": native["completion"],
                            "checkpoint_sha256": checkpoint["checkpoint_sha256"]}
    args.output.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"passed": True, "cases": len(results),
                      "changed_technology_costs": len(report.get("before_after", {}).get("removed_unintended_cost", []))}))


if __name__ == "__main__":
    main()
