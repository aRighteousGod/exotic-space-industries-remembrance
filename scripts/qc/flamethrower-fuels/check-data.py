"""Check final engine data against the approved fuel contract (no source rewriting)."""
import json
import mmap
import re
import sys
from pathlib import Path

# Factorio's indented dump contains many unrelated vehicle configurations. Read
# only the seven prototype sections this acceptance check actually examines.
needed = {"ammo", "recipe", "fire", "sticker", "stream", "fluid-turret", "technology"}
dump = {}
with Path(sys.argv[1]).open("rb") as source:
    with mmap.mmap(source.fileno(), 0, access=mmap.ACCESS_READ) as mapped:
        headers = list(re.finditer(rb'^  "([^"\r\n]+)":', mapped, re.MULTILINE))
        decoder = json.JSONDecoder()
        for index, header in enumerate(headers):
            name = header.group(1).decode("utf-8")
            if name in needed:
                end = headers[index + 1].start() if index + 1 < len(headers) else len(mapped)
                dump[name] = decoder.raw_decode(mapped[header.end():end].decode("utf-8").lstrip())[0]
assert set(dump) == needed, "Unexpected Factorio dump formatting or missing sections"
rows = [
    ("heavy-distillate", "ei-heavy-destilate", .4, 2, "ei-destill-tower"),
    ("medium-distillate", "ei-medium-destilate", .5, 1.75, "ei-destill-tower"),
    ("residual-oil", "ei-residual-oil", .65, 1.5, "flamethrower"),
    ("bio-oil", "ei-bio-oil", .8, 1.25, "ei-bio-oil"),
    ("crude-oil", "crude-oil", 1, 1, "flamethrower"),
    ("heavy-oil", "heavy-oil", 1.15, 1.5, "ei-destill-tower"),
    ("light-oil", "light-oil", 1.25, 1, "ei-destill-tower"),
    ("petroleum-gas", "petroleum-gas", 1.35, .5, "flamethrower"),
    ("kerosene", "ei-kerosene", 1.45, .75, "ei-destill-tower"),
    ("diesel", "ei-diesel", 1.6, 2, "advanced-oil-processing"),
]
baseline = dump["ammo"]["flamethrower-ammo"]
expected_fluids = {fluid: damage for _, fluid, damage, _, _ in rows}
assert {f["type"]: f.get("damage_modifier", 1) for f in dump["fluid-turret"]["flamethrower-turret"]["attack_parameters"]["fluids"]} == expected_fluids
for key, fluid, damage, lifetime, tech in rows:
    name = "flamethrower-ammo" if key == "crude-oil" else "ei-flamethrower-ammo-" + key
    ammo, recipe = dump["ammo"][name], dump["recipe"][name]
    assert recipe["ingredients"] == [{"type": "item", "name": "steel-plate", "amount": 5}, {"type": "fluid", "name": fluid, "amount": 100}]
    assert recipe["results"] == [{"type": "item", "name": name, "amount": 1}]
    assert recipe["energy_required"] == 6 and recipe["category"] == "chemistry"
    assert any(e.get("recipe") == name for e in dump["technology"][tech]["effects"])
    for field in ("magazine_size", "stack_size", "weight", "ammo_category"):
        assert ammo[field] == baseline[field]
    for kind in ("ammo", "turret"):
        fire = dump["fire"][f"ei-flame-{key}-{kind}-fire"]
        assert fire["initial_lifetime"] == round(120 * lifetime)
        assert fire["maximum_lifetime"] == round(1800 * lifetime)
        assert fire["lifetime_increase_by"] == int(150 * lifetime + .5)
        assert abs(fire["damage_per_tick"]["amount"] - 13 / 60 * (damage if kind == "ammo" else 1)) < 1e-8
        assert fire["spawn_entity"] == "fire-flame-on-tree"
        sticker = dump["sticker"][f"ei-flame-{key}-{kind}-sticker"]
        assert sticker["duration_in_ticks"] == dump["sticker"]["fire-sticker"]["duration_in_ticks"]
    tank = dump["stream"][f"ei-flame-{key}-tank-flamethrower-fire-stream"]
    assert "create-fire" not in json.dumps(tank["action"])
    turret = dump["fluid-turret"][f"ei-flamethrower-turret-{key}"]
    assert {f["type"]: f.get("damage_modifier", 1) for f in turret["attack_parameters"]["fluids"]} == expected_fluids
    assert turret["placeable_by"]["item"] == "flamethrower-turret"
    for tech_data in dump["technology"].values():
        effects = tech_data.get("effects", [])
        if not isinstance(effects, list):
            continue
        originals = [e for e in effects if e.get("turret_id") == "flamethrower-turret"]
        for effect in originals:
            assert any(e.get("turret_id") == turret["name"] and e.get("modifier") == effect["modifier"] for e in effects)

root = Path(__file__).resolve().parents[3] / "exotic-space-industries-remembrance" / "locale"
expected = None
for locale in ("en", "fr", "ja", "pl", "ru", "zh-CN", "zh-TW"):
    content = (root / locale / "flamethrower-fuels.cfg").read_text(encoding="utf-8")
    assert "\ufffd" not in content and not content.startswith("\ufeff")
    section, keys = "", []
    for line in content.splitlines():
        if line.startswith("["):
            section = line
        elif "=" in line:
            keys.append((section, line.split("=", 1)[0]))
    assert len(keys) == len(set(keys)) == 5
    if expected is None:
        expected = keys
    assert keys == expected
print("PASS: 10 fuels, recipes/unlocks, native damage/lifetimes, research parity, and seven locale contracts")
