"""Compare compact native inventories; retain every discrepancy as evidence.

Category eligibility is a static final-data check, not a native crafting test.
Product normalization accounts for the native uint amount and probability rename.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path

LEGACY = {"ei-" + x: x for x in ("electronics", "electronics-with-fluid", "electronics-or-assembling",
    "pressing", "chemistry-or-cryogenics", "organic-or-assembling", "organic-or-hand-crafting",
    "organic-or-chemistry", "cryogenics-or-assembling", "metallurgy-or-assembling", "crafting-with-fluid-or-metallurgy")}


def categories(recipe):
    values = recipe.get("categories") or [recipe.get("category", "crafting"), *recipe.get("additional_categories", [])]
    return {LEGACY.get(x, x) for x in values}


def products(recipe):
    rows = []
    for product in recipe.get("results", []):
        row = dict(product)
        if "probability" in row:
            row["independent_probability"] = row.pop("probability")
        if row.get("independent_probability") == 1:
            row.pop("independent_probability")
        if row.get("extra_count_fraction") == 0:
            row.pop("extra_count_fraction")
        if row.get("type", "item") == "item":
            for field in ("amount", "amount_min", "amount_max"):
                if field in row:
                    row[field] = math.floor(row[field])
        for field in ("ignored_by_stats", "show_details_in_recipe_tooltip"):
            row.pop(field, None)
        rows.append(row)
    return sorted(rows, key=lambda r: json.dumps(r, sort_keys=True))


def economic_products(recipe):
    rows = []
    for row in products(recipe):
        rows.append({k: v for k, v in row.items() if k in ("type", "name", "amount", "amount_min", "amount_max",
            "independent_probability", "shared_probability", "extra_count_fraction", "temperature")})
    return sorted(rows, key=lambda r: json.dumps(r, sort_keys=True))


def machines(data):
    return {(kind, name): set(value.get("crafting_categories", []))
            for kind in ("character", "assembling-machine", "furnace") for name, value in data.get(kind, {}).items()}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("before", type=Path)
    parser.add_argument("after", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    before, after = [json.loads(p.read_text(encoding="utf-8")) for p in (args.before, args.after)]
    old_machines, new_machines = machines(before), machines(after)
    shared_machines = sorted(old_machines.keys() & new_machines.keys())
    shared_recipes = sorted(before["recipe"].keys() & after["recipe"].keys())
    routing, recycling, changes = [], [], []
    for name in shared_recipes:
        old, new = before["recipe"][name], after["recipe"][name]
        old_routes = set(old.get("categories") or [old.get("category", "crafting"), *old.get("additional_categories", [])])
        new_routes = set(new.get("categories") or [new.get("category", "crafting")])
        old_eligible = [x for x in shared_machines if old_routes & old_machines[x]]
        new_eligible = [x for x in shared_machines if new_routes & new_machines[x]]
        if old_eligible != new_eligible:
            routing.append({"recipe": name, "before": old_eligible, "after": new_eligible})
        if "recycling" in categories(new):
            result = {}
            if economic_products(old) != economic_products(new):
                result["products"] = {"before": economic_products(old), "after": economic_products(new)}
            if old.get("energy_required", 0.5) != new.get("energy_required", 0.5):
                result["energy_required"] = {"before": old.get("energy_required", 0.5), "after": new.get("energy_required", 0.5)}
            if result:
                recycling.append({"recipe": name, **result})
        else:
            result = {}
            for field, default in (("energy_required", 0.5), ("allow_productivity", False), ("allow_quality", True), ("maximum_productivity", 3)):
                if old.get(field, default) != new.get(field, default):
                    result[field] = {"before": old.get(field, default), "after": new.get(field, default)}
            if economic_products(old) != economic_products(new):
                result["products"] = {"before": economic_products(old), "after": economic_products(new)}
            if result:
                changes.append({"recipe": name, **result})
    ash = []
    for name in sorted(before.get("item", {}).keys() & after.get("item", {}).keys()):
        old, new = before["item"][name], after["item"][name]
        if old.get("burnt_result") != new.get("burnt_result"):
            ash.append({"item": name, "before": old.get("burnt_result"), "after": new.get("burnt_result")})
    report = {"sources": {str(p): hashlib.sha256(p.read_bytes()).hexdigest() for p in (args.before, args.after)},
        "shared_recipes": len(shared_recipes), "shared_crafting_entities": len(shared_machines),
        "machine_category_eligibility_changes": routing, "recycling_changes": recycling,
        "other_recipe_changes": changes, "burnt_result_changes": ash,
        "limits": "Static merged-data comparisons; optional sets differ; native crafts, fluid connections, research and state are separate gates"}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2), encoding="utf-8")
    print(json.dumps({k: len(v) if isinstance(v, list) else v for k, v in report.items() if k not in ("sources", "limits")}))


if __name__ == "__main__":
    main()
