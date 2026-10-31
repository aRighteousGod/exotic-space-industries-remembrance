"""Prepare a managed private source view; never mutate linked source/media."""
import argparse
import json
from pathlib import Path
import shutil

parser = argparse.ArgumentParser()
parser.add_argument("record", type=Path)
parser.add_argument("mode", choices=("baseline", "candidate"))
parser.add_argument("quality", choices=("enabled", "disabled"))
parser.add_argument("--visual", action="store_true")
args = parser.parse_args()
record = json.loads(args.record.read_text(encoding="utf-8-sig"))
mods = Path(record["mods"])
repo = Path(record["repo"])
main = mods / "exotic-space-industries-remembrance"
source = repo / main.name
fixture = Path(__file__).resolve().parent
names = ["advanced-chem-plant", "advanced-centrifuge", "advanced-destill-tower", "advanced-refinery",
         "auric-inoculation-vat", "bio-chamber", "bio-reactor", "destill-tower", "excavator",
         "exchanger", "fusion-reactor", "grower", "nano-factory", "neutron-activator", "purifier", "quantum-computer"]
owners = [next((source / "prototypes").rglob(name + ".lua")).relative_to(source) for name in names]
owners += [Path("scripts/data-updates/more-asteroids.lua"), Path("scripts/data-updates/vanilla-updates/other.lua"),
           Path("prototypes/steam-age/steam-oil-pumpjack.lua")]
for relative in owners:
    target = main / relative
    assert target.resolve() != (source / relative).resolve() and target.stat().st_nlink == 1, target
    text = (source / relative).read_text(encoding="utf-8")
    if args.mode == "baseline":
        lines = text.splitlines(keepends=True)
        removed = [s for s in lines if "use_mirroring = true" in s or "pump.graphics_set_flipped = table.deepcopy(pump.graphics_set)" in s]
        assert len(removed) == 1, relative
        text = "".join(s for s in lines if s not in removed)
    target.write_text(text, encoding="utf-8")
helper = mods / "esir-qc-mirroring"
helper.mkdir(exist_ok=True)
for path in fixture.glob("*.lua"):
    shutil.copy2(path, helper / path.name)
tag = args.mode + "-quality-" + args.quality
(helper / "test-config.lua").write_text(f'return {{mode="{args.mode}", tag="{tag}", visual={str(args.visual).lower()}}}\n', encoding="utf-8")
if args.visual:
    shutil.copy2(fixture / "render-control.lua", helper / "control.lua")
    native = json.loads((Path(record["write_data"]) / f"script-output/mirroring/{tag}-reload.json").read_text())
    recipes = {row["name"]: next((c["recipe"] for c in row["cases"] if c.get("recipe")), None) for row in native["entities"]}
    (helper / "recipes.lua").write_text("return {" + ",".join(f'["{k}"]="{v}"' for k, v in recipes.items() if v) + "}\n", encoding="utf-8")
selection = json.loads((mods / "mod-list.json").read_text(encoding="utf-8-sig"))
selection["mods"] = [m for m in selection["mods"] if m["name"] != helper.name]
for mod in selection["mods"]:
    if mod["name"] == "quality":
        mod["enabled"] = args.quality == "enabled"
    elif mod["name"] == "esir-qc-mirroring-legacy":
        mod["enabled"] = False
selection["mods"].append({"name": helper.name, "enabled": True})
(mods / "mod-list.json").write_text(json.dumps(selection), encoding="utf-8")
(helper / "info.json").write_text(json.dumps({"name": helper.name, "version": "0.0.1", "title": "Mirroring acceptance",
    "author": "ESIR QC", "factorio_version": "2.1", "dependencies": [m["name"] for m in selection["mods"] if m["enabled"] and m["name"] != helper.name]}), encoding="utf-8")
print(tag)
