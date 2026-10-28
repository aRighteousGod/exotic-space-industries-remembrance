"""Prepare (never apply) an AST-scoped 2.0 -> 2.1 literal migration patch.

Only named fields on actual Lua table constructors are changed. This avoids
confusing recipe category/probability fields with combat and noise definitions.
Requires luaparser. Final-data verification remains mandatory for generated data.
"""
import argparse
import difflib
import json
from pathlib import Path
from luaparser import ast
from luaparser.astnodes import Name, String, Table


def fields(node):
    return {f.key.id: f for f in node.fields if isinstance(f.key, Name)}


def literal(node):
    return node.s.decode() if isinstance(node, String) else None


def transform(path):
    source = path.read_text(encoding="utf-8-sig")
    if not any(word in source for word in ("category", "probability", "freshness", "fresh")):
        return source, source, []
    tree = ast.parse(source)
    replacements = {}
    notes = []

    def replace(node, text):
        key = (node.first_token.start, node.last_token.stop + 1)
        assert key not in replacements, (path, key)
        replacements[key] = text

    def text(node):
        return source[node.first_token.start:node.last_token.stop + 1]

    def remove(field):
        start, stop = field.first_token.start, field.last_token.stop + 1
        if source[stop:stop + 1] == ",":
            stop += 1
        replacements[(start, stop)] = ""

    def append_field(node, value):
        key = node.last_token.start
        prefix = " " if source[:key].rstrip().endswith(",") else ", "
        replacements[(key, key)] = replacements.get((key, key), "") + prefix + value

    crystal_products = set()
    for node in ast.walk(tree):
        if not isinstance(node, Table):
            continue
        f = fields(node)
        if "type" not in f or literal(f["type"].value) != "recipe":
            continue
        name = literal(f["name"].value) if "name" in f else "<generated>"
        if "category" in f or "additional_categories" in f:
            category = text(f["category"].value) if "category" in f else '"crafting"'
            extras = f.get("additional_categories")
            if extras:
                assert isinstance(extras.value, Table), (path, name, "dynamic additional categories")
                category += ", " + ", ".join(text(x.value) for x in extras.value.fields)
            if "category" in f:
                replace(f["category"], "categories = {" + category + "}")
                if extras:
                    remove(extras)
            else:
                replace(extras, "categories = {" + category + "}")
            notes.append({"kind": "recipe-categories", "name": name})
        ingredients = f.get("ingredients")
        results = f.get("results")
        if not results or not isinstance(results.value, Table):
            continue
        products = [x.value for x in results.value.fields if isinstance(x.value, Table)]
        consumes = ingredients and isinstance(ingredients.value, Table) and any(
            isinstance(x.value, Table) and "name" in fields(x.value)
            and literal(fields(x.value)["name"].value) == "ei-high-energy-crystal"
            for x in ingredients.value.fields)
        crystal = {literal(fields(p)["name"].value): p for p in products if "name" in fields(p)
                   and literal(fields(p)["name"].value) in ("ei-high-energy-crystal", "ei-energy-crystal")}
        if consumes and len(crystal) == 2 and "probability" in fields(crystal["ei-high-energy-crystal"]):
            high = fields(crystal["ei-high-energy-crystal"])
            split = float(text(high["probability"].value))
            for crystal_name, product in crystal.items():
                pf = fields(product)
                assert text(pf["amount"].value) == "1", (path, name)
                low, upper = (0, split) if crystal_name == "ei-high-energy-crystal" else (split, 1)
                replace(pf["probability"], f"shared_probability = {{min = {low:g}, max = {upper:g}}}")
                if "ignored_by_productivity" in pf:
                    replace(pf["ignored_by_productivity"].value, "1")
                else:
                    append_field(product, "ignored_by_productivity = 1")
                crystal_products.add(id(product))
            notes.append({"kind": "crystal-return", "name": name, "high": split, "ordinary": round(1 - split, 8)})
        for old, new in (("result_is_always_fresh", "always_fresh"), ("reset_freshness_on_craft", "reset_freshness_on_craft")):
            if old in f:
                value = text(f[old].value)
                for product in products:
                    pf = fields(product)
                    if "type" in pf and literal(pf["type"].value) == "fluid":
                        continue
                    append_field(product, f"{new} = {value}")
                remove(f[old])
                notes.append({"kind": new, "name": name})
        for obsolete in ("always_show_products", "show_amount_in_title"):
            if obsolete in f:
                remove(f[obsolete])

    for node in ast.walk(tree):
        if not isinstance(node, Table):
            continue
        f = fields(node)
        if "loot" in f and isinstance(f["loot"].value, Table):
            for row in f["loot"].value.fields:
                if not isinstance(row.value, Table):
                    continue
                loot = fields(row.value)
                if "item" not in loot:
                    continue
                replace(loot["item"], 'type = "item", name = ' + text(loot["item"].value))
                for old, new in (("count_min", "amount_min"), ("count_max", "amount_max"), ("probability", "independent_probability")):
                    if old in loot:
                        replace(loot[old], new + " = " + text(loot[old].value))
                if "count_min" not in loot and "count_max" not in loot:
                    append_field(row.value, "amount = 1")
                notes.append({"kind": "loot-product"})
        if "fuel_category" in f:
            replace(f["fuel_category"], "fuel_categories = {" + text(f["fuel_category"].value) + "}")
            notes.append({"kind": "fuel-categories"})
        if id(node) in crystal_products:
            continue
        if "probability" in f and "name" in f and "type" in f and literal(f["type"].value) in ("item", "fluid"):
            replace(f["probability"], "independent_probability = " + text(f["probability"].value))
            notes.append({"kind": "independent-product"})
    previous = len(source) + 1
    result = source
    for (start, stop), replacement in sorted(replacements.items(), reverse=True):
        assert stop <= previous, (path, "overlapping edits", start, stop, previous)
        result = result[:start] + replacement + result[stop:]
        previous = start
    if result != source:
        ast.parse(result)
    return source, result, notes


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path("exotic-space-industries-remembrance"))
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    patches, inventory = [], []
    for path in sorted(args.root.rglob("*.lua")):
        if "/scripts/control/" in path.as_posix() or path.name == "control.lua":
            continue
        old, new, notes = transform(path)
        if old != new:
            diff = list(difflib.unified_diff(old.splitlines(True), new.splitlines(True), n=3))[2:]
            patches.append("*** Update File: " + path.as_posix() + "\n" + "".join("@@\n" if line.startswith("@@") else line for line in diff))
            inventory.append({"path": path.as_posix(), "changes": notes})
    args.output.mkdir(parents=True, exist_ok=True)
    (args.output / "literals.patch").write_text("*** Begin Patch\n" + "".join(patches) + "*** End Patch\n", encoding="utf-8")
    (args.output / "literal-inventory.json").write_text(json.dumps(inventory, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"changed_files": len(inventory), "crystal_recipes": sum(n["kind"] == "crystal-return" for f in inventory for n in f["changes"])}))


if __name__ == "__main__":
    main()
