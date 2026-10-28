"""Read selected prototypes from large native data dumps without loading graphics.

Only one prototype is decoded at a time. The input is read-only; output is a
compact evidence inventory, not a substitute for runtime or migration checks.
"""
import argparse
import hashlib
import json
import mmap
from pathlib import Path
import re

SECTIONS = re.compile(rb'^  "([^"\\]+)":\s*\r?$', re.M)
PROTOTYPES = re.compile(rb'^    "([^"\\]+)":\s*\r?$', re.M)
FIELDS = {
    "recipe": {"name", "category", "categories", "additional_categories", "ingredients", "results", "energy_required",
               "allow_productivity", "maximum_productivity", "allow_quality", "enabled", "hidden", "auto_recycle",
               "main_product", "surface_conditions", "result_is_always_fresh", "reset_freshness_on_craft"},
    "technology": {"name", "prerequisites", "effects", "unit", "research_trigger", "enabled", "hidden", "max_level"},
    "assembling-machine": {"name", "crafting_categories", "crafting_speed", "ingredient_count", "module_slots",
                           "allowed_effects", "effect_receiver", "energy_usage", "energy_source"},
    "furnace": {"name", "crafting_categories", "crafting_speed", "module_slots", "allowed_effects", "effect_receiver"},
    "character": {"name", "crafting_categories"},
    "lab": {"name", "inputs", "researching_speed", "effect_receiver"},
    "item": {"name", "fuel_category", "fuel_categories", "fuel_value", "burnt_result", "fuel_acceleration_multiplier",
             "fuel_top_speed_multiplier", "fuel_emissions_multiplier", "spoil_ticks", "spoil_result", "place_result"},
    "tool": {"name", "durability", "spoil_ticks", "spoil_result"},
    "module": {"name", "effect", "tier", "category"},
    "planet": {"name", "surface_properties", "map_gen_settings"},
    "reactor": {"name", "consumption", "neighbour_bonus", "neighbour_connectable", "heat_buffer", "energy_source"},
    "generator": {"name", "fluid_usage_per_tick", "maximum_temperature", "minimum_input_temperature", "maximum_input_temperature", "effectivity", "max_power_output"},
    "fluid-turret": {"name", "flags", "circuit_connector", "fluid_box", "fluid_buffer_size", "attack_parameters"},
}


def inventory(path):
    result = {}
    with path.open("rb") as stream, mmap.mmap(stream.fileno(), 0, access=mmap.ACCESS_READ) as raw:
        sections = list(SECTIONS.finditer(raw))
        for index, section in enumerate(sections):
            kind = section.group(1).decode()
            if kind not in FIELDS:
                continue
            end = sections[index + 1].start() if index + 1 < len(sections) else len(raw)
            rows = list(PROTOTYPES.finditer(raw, section.end(), end))
            selected = result[kind] = {}
            for position, row in enumerate(rows):
                stop = rows[position + 1].start() if position + 1 < len(rows) else end
                start = raw.find(b"{", row.end(), stop)
                # The last prototype is followed by its parent section's brace.
                tail = raw[row.end():stop].rstrip()
                if position + 1 == len(rows):
                    closing = re.search(rb'\r?\n  }\s*,?\s*$', tail)
                    assert closing, (kind, row.group(1), "section boundary")
                    tail = tail[:closing.start()].rstrip()
                item = json.loads(tail.rstrip(b", \r\n"))
                selected[row.group(1).decode()] = {k: v for k, v in item.items() if k in FIELDS[kind]}
    return result


def crystal_contract(recipes):
    rows, failures = [], []
    for name, recipe in sorted(recipes.items()):
        ingredients = recipe.get("ingredients", [])
        consumed = sum(x.get("amount", 0) for x in ingredients if x.get("name") == "ei-high-energy-crystal")
        results = recipe.get("results", [])
        pair = {x.get("name"): x for x in results if x.get("name") in {"ei-high-energy-crystal", "ei-energy-crystal"}}
        if not consumed or len(pair) != 2:
            continue
        high, low = pair["ei-high-energy-crystal"], pair["ei-energy-crystal"]
        hr, lr = high.get("shared_probability", {}), low.get("shared_probability", {})
        # Explicit user correction: alien computer-age science consumes two,
        # permanently spends one and returns the other. All other pairs consume one.
        base_name = re.sub(r"__rigor_module_mod__\d+$", "", name)
        expected_consumed = 2 if base_name == "ei-alien-computer-age-tech" else 1
        expected_probability = 0.9 if base_name == "ei-uranium-extraction" else 0.92 if base_name == "ei-neodym-extraction-morphium" else 0.98
        checks = {
            "known_variant_source": base_name == name or base_name in recipes,
            "approved_input_count": consumed == expected_consumed,
            "approved_probability_split": abs(hr.get("max", -1) - expected_probability) < 1e-10,
            "one_each": high.get("amount") == low.get("amount") == 1,
            "no_independent_gate": all("probability" not in x and "independent_probability" not in x for x in pair.values()),
            "full_partition": hr.get("min") == 0 and hr.get("max") == lr.get("min") and lr.get("max") == 1
                and 0 < hr.get("max", 0) < 1,
            "no_productivity_return": high.get("ignored_by_productivity") == low.get("ignored_by_productivity") == 1,
        }
        row = {"name": name, "consumed": consumed, "permanently_consumed": expected_consumed - 1,
               "high": high, "ordinary": low, "checks": checks}
        rows.append(row)
        if not all(checks.values()): failures.append(name)
    return {"recipes": rows, "count": len(rows), "failures": failures, "all_pass": bool(rows) and not failures}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("dump", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--version", required=True)
    args = parser.parse_args()
    result = inventory(args.dump)
    args.output.mkdir(parents=True, exist_ok=True)
    (args.output / "inventory.json").write_text(json.dumps(result, indent=2), encoding="utf-8")
    crystal = crystal_contract(result["recipe"])
    (args.output / "crystals.json").write_text(json.dumps(crystal, indent=2), encoding="utf-8")
    receipt = {"version": args.version, "source": str(args.dump.resolve()), "source_bytes": args.dump.stat().st_size,
               "counts": {k: len(v) for k, v in result.items()}, "crystal_count": crystal["count"],
               "crystal_contract_pass": crystal["all_pass"]}
    receipt["inventory_sha256"] = hashlib.sha256((args.output / "inventory.json").read_bytes()).hexdigest()
    (args.output / "receipt.json").write_text(json.dumps(receipt, indent=2), encoding="utf-8")
    print(json.dumps(receipt))


if __name__ == "__main__":
    main()
