"""Compare exact robot final fields with the fixture's pre-feature snapshot."""
import json
import sys
from pathlib import Path

root = Path(sys.argv[1])
before = json.loads((root / "robot-baseline-final.json").read_text(encoding="utf-8-sig"))
after = json.loads((root / "robot-candidate-final.json").read_text(encoding="utf-8-sig"))
allowed = {"speed", "max_payload_size", "energy_per_move", "max_health"}
checks = 0
for name, entity in before["entities"].items():
    for field, value in entity.items():
        if "advanced" in name and field in allowed:
            continue
        assert after["entities"][name].get(field) == value, (name, field)
        checks += 1
for name, recipe in before["recipes"].items():
    current = after["recipes"][name]
    if name in {"ei-advanced-logistic-bot", "ei-advanced-construction-bot"}:
        # Direct recipes now identify their standard donor bot with a corner icon.
        current = {key: value for key, value in current.items() if key != "icons"}
        recipe = {key: value for key, value in recipe.items() if key != "icons"}
    assert current == recipe, f"Direct/recycling recipe changed: {name}"
    checks += 1
for field, value in before["technology"].items():
    if field != "effects":
        assert after["technology"].get(field) == value, f"Technology changed: {field}"
        checks += 1
for effect in before["technology"]["effects"]:
    assert effect in after["technology"]["effects"]
assert len(after["technology"]["effects"]) == len(before["technology"]["effects"]) + 2
report = {"checks": checks, "direct_and_recycling_recipes_unchanged": True,
          "presentation_inherited_and_verified": True, "previous_tiers_unchanged": True}
(root / "robot-final-comparison.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
print(json.dumps(report))
