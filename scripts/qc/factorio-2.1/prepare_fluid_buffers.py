"""Historical pre-approval patch retaining native ESIR 2.0 fluid buffer sizes.

Superseded for Quality-enabled development by prepare_native_buffers.py and
ei_lib.recipe_fluidbox_multiplier. Retained to reproduce the earlier parity
evidence; do not apply its output to the accepted 1.4.0 source.

The 36 paired native probes establish input capacity amount*(multiplier+1) in
2.1 versus amount*multiplier in 2.0. Correct the earlier partial port's 2/10 to
1/9; retain the explicitly adjusted railgun lock recipe at 1. Fluid products
need explicit multiplier 2 instead of the new native default 3. Only classified
ingredients/results tables are edited. Other fluid tables require source review.
The script writes a proposed patch and inventory; it never edits shipping Lua.
"""
import argparse
import difflib
import json
from pathlib import Path
from luaparser import ast
from luaparser.astnodes import Assign, Call, Field, Index, LocalAssign, Name, String, Table


def key(node):
    if isinstance(node, Name):
        return node.id
    if isinstance(node, String):
        return node.s.decode()


def fields(table):
    return {key(f.key): f for f in table.fields}


def list_kind(node):
    return key(node.idx) if isinstance(node, Index) and key(node.idx) in ("ingredients", "results") else None


def prepare(path):
    source = path.read_text(encoding="utf-8-sig")
    if "fluid" not in source:
        return source, source, [], []
    tree = ast.parse(source)
    classified = {}

    def accept(table, kind):
        if isinstance(table, Table):
            classified.update((id(f.value), kind) for f in table.fields if isinstance(f.value, Table))

    mining_results = set()
    for node in ast.walk(tree):
        if isinstance(node, Field) and key(node.key) == "minable" and isinstance(node.value, Table):
            result = fields(node.value).get("results")
            if result and isinstance(result.value, Table):
                mining_results.update(id(f.value) for f in result.value.fields)
        if isinstance(node, Field) and key(node.key) in ("ingredients", "results"):
            accept(node.value, key(node.key))
        if isinstance(node, Field) and key(node.key) == "payload_ingredients":
            accept(node.value, "ingredients")
        if isinstance(node, LocalAssign):
            for target, value in zip(node.targets, node.values):
                if isinstance(target, Name) and target.id.endswith("Ingredients"):
                    accept(value, "ingredients")
        if isinstance(node, Assign):
            for target, value in zip(node.targets, node.values):
                if list_kind(target):
                    accept(value, list_kind(target))
        if isinstance(node, Call) and isinstance(node.func, Index) and key(node.func.idx) == "insert":
            if len(node.args) >= 2 and list_kind(node.args[0]) and isinstance(node.args[-1], Table):
                classified[id(node.args[-1])] = list_kind(node.args[0])
        if isinstance(node, Call) and isinstance(node.func, Index) and key(node.func.idx) == "recipe_new":
            if len(node.args) >= 2:
                accept(node.args[1], "ingredients")
        if isinstance(node, Call) and isinstance(node.func, Name) and node.func.id == "make_hidden_recipe" and path.name == "auric-inoculation-vat.lua":
            if len(node.args) >= 3:
                accept(node.args[2], "ingredients")
            if len(node.args) >= 4:
                accept(node.args[3], "results")
    edits, notes, unresolved = [], [], []
    for node in ast.walk(tree):
        if not isinstance(node, Table):
            continue
        f = fields(node)
        if id(node) in mining_results:
            continue
        if "type" not in f or key(f["type"].value) != "fluid" or not ("amount" in f or "amount_max" in f):
            continue
        record = {"path": path.as_posix(), "line": node.first_token.line,
                  "name": key(f["name"].value) if "name" in f else None}
        kind = classified.get(id(node))
        # Reviewed named ingredient maps and rocket make_recipe argument lists.
        # Material descriptors in K2 have no multiplier and remain unclassified.
        if not kind and path.name in ("recipes.lua", "krastorio-patches.lua", "rocket-ammo.lua") and "fluidbox_multiplier" in f:
            kind = "ingredients"
        record["kind"] = kind
        if not kind:
            unresolved.append(record)
        elif "fluidbox_multiplier" not in f:
            position = node.last_token.start
            separator = " " if source[:position].rstrip().endswith(",") else ", "
            edits.append((position, position, separator + "fluidbox_multiplier = " + ("1" if kind == "ingredients" else "2")))
            notes.append(record)
        elif kind == "ingredients":
            value = f["fluidbox_multiplier"].value
            old = source[value.first_token.start:value.last_token.stop + 1]
            assert old in ("1", "2", "9", "10"), (path, record, old)
            if old in ("2", "10"):
                edits.append((value.first_token.start, value.last_token.stop + 1, str(int(old) - 1)))
                notes.append(record)
    updated = source
    for start, end, value in sorted(edits, reverse=True):
        updated = updated[:start] + value + updated[end:]
    return source, updated, notes, unresolved


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--mod", type=Path, default=Path("exotic-space-industries-remembrance"))
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    notes, unresolved, patches = [], [], []
    for path in sorted(args.mod.rglob("*.lua")):
        source, updated, changed, other = prepare(path)
        notes.extend(changed)
        unresolved.extend(other)
        if source == updated:
            continue
        lines = ["*** Begin Patch", "*** Update File: " + path.as_posix()]
        for line in list(difflib.unified_diff(source.splitlines(), updated.splitlines(), lineterm=""))[2:]:
            lines.append("@@" if line.startswith("@@") else line)
        lines.append("*** End Patch")
        target = args.output / f"{len(patches):03d}.patch"
        target.write_text("\n".join(lines) + "\n", encoding="utf-8")
        patches.append(str(target))
    report = {"changes": notes, "other_fluid_tables": unresolved, "patches": patches}
    (args.output / "inventory.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
    print(json.dumps({"changes": len(notes), "files": len(patches), "unclassified": len(unresolved)}))


if __name__ == "__main__":
    main()
