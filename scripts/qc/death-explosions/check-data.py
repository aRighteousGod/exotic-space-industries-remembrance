"""Inspect death coverage without loading the multi-gigabyte final-data dump."""
import argparse
import collections
import hashlib
import json
import mmap
import re
from pathlib import Path


def read_entities(path):
    visual_explosions = {"ei-anisetron-lance-death-visual", "ei-singularity-lance-death-explosion",
                         "ei-death-explosion-alien-huge"}
    fields = {"type", "name", "max_health", "hidden", "flags", "minable",
              "placeable_by", "selectable_in_game", "selection_box", "collision_box",
              "dying_explosion", "dying_trigger_effect", "action", "attack_parameters", "destroy_action",
              "animations", "created_effect", "sound", "light", "smoke", "smoke_count",
              "scale_out_duration", "scale_end", "scale_animation_speed"}
    decoder = json.JSONDecoder()
    with path.open("rb") as handle, mmap.mmap(handle.fileno(), 0, access=mmap.ACCESS_READ) as mapped:
        headers = list(re.finditer(rb'^(  |    )"([^"\r\n]+)":', mapped, re.MULTILINE))
        attribute_pattern = re.compile(rb'^      "([^"\r\n]+)":', re.MULTILINE)
        category = None
        for header_index, header in enumerate(headers):
            if header.group(1) == b"  ":
                category = header.group(2).decode()
                continue
            name = header.group(2).decode()
            if category == "explosion" and name not in visual_explosions:
                continue
            if not (name.startswith(("ei-", "ei_", "spidertron-enhancements-dummy-")) or name in {"spidertron", "assault_spidertron", "flamethrower-turret"}):
                continue
            boundary = headers[header_index + 1].start() if header_index + 1 < len(headers) else len(mapped)
            attributes = list(attribute_pattern.finditer(mapped, header.end(), boundary))
            row = {}
            for index, attribute in enumerate(attributes):
                key = attribute.group(1).decode()
                if key in fields:
                    end = attributes[index + 1].start() if index + 1 < len(attributes) else boundary
                    row[key] = decoder.raw_decode(mapped[attribute.end():end].decode().lstrip())[0]
            if "max_health" in row or category == "explosion" and name in visual_explosions:
                yield category, name, row


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("dump", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--inventory-only", action="store_true")
    parser.add_argument("--baseline", type=Path)
    args = parser.parse_args()
    entities = {(kind, name): row for kind, name, row in read_entities(args.dump)}
    counts = collections.Counter()
    visible = []
    for (kind, name), row in entities.items():
        counts[(kind, str(row.get("dying_explosion")), bool(row.get("hidden")))] += 1
        if not row.get("hidden") and row.get("selectable_in_game", True):
            visible.append({"type": kind, "name": name, "core": row.get("dying_explosion"),
                            "supplemented": bool(row.get("dying_trigger_effect"))})
    def digest(value):
        return hashlib.sha256(json.dumps(value, sort_keys=True).encode()).hexdigest()

    preserved = {
        "snare_action": digest(entities[("land-mine", "ei-prediction-snare-mine")].get("action")),
        "incinerator_attack": digest(entities[("combat-robot", "ei-incinerator")].get("attack_parameters")),
        "lance_death": digest(entities[("explosion", "ei-singularity-lance-death-explosion")]),
        "alien_huge_death": digest(entities[("explosion", "ei-death-explosion-alien-huge")]),
        "helpers": {name: digest([row.get("dying_explosion"), row.get("dying_trigger_effect")])
                    for (_, name), row in entities.items()
                    if name.startswith("spidertron-enhancements-dummy-")
                    or name in {"ei-combustion-turbine-fluid-open-proxy", "ei-sweeping-radar-power",
                                "ei-phased-array-radar-power", "ei-sweeping-radar-output"}},
    }
    incinerator_expiry = entities[("combat-robot", "ei-incinerator")].get("destroy_action")
    report = {"dump": str(args.dump), "entity_count": len(entities), "visible": visible,
              "validation": "inventory" if args.inventory_only else "pending",
              "preserved": preserved,
              "incinerator_expiry": incinerator_expiry,
              "core_counts": [{"type": kind, "core": core, "hidden": hidden, "count": count}
                              for (kind, core, hidden), count in sorted(counts.items())]}
    args.output.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    if args.inventory_only:
        print(f"Inventoried {len(entities)} entity prototypes; report: {args.output}")
        return
    expected = {
        ("radar", "ei-sweeping-radar"): "ei-death-explosion-signal-",
        ("radar", "ei-phased-array-radar"): "ei-death-explosion-signal-",
        ("spider-vehicle", "ei-anisetron"): "ei-death-explosion-alien-",
        ("spider-vehicle", "ei-scout-spidertron"): "ei-death-explosion-electric-logistics-",
        ("spider-vehicle", "assault_spidertron"): "ei-death-explosion-ballistic-",
        ("spider-vehicle", "spidertron"): "ei-death-explosion-ballistic-",
        ("fluid-turret", "flamethrower-turret"): "ei-death-explosion-chemical-",
        ("generator", "ei-combustion-turbine-fluid"): "ei-death-explosion-combustion-",
        ("electric-energy-interface", "ei-crystal-accumulator-low"): "ei-death-explosion-alien-",
        ("electric-energy-interface", "ei-crystal-accumulator-surged"): "ei-death-explosion-alien-",
        ("radar", "ei-sweeping-radar-placement"): "ei-death-explosion-signal-",
        ("radar", "ei-phased-array-radar-placement"): "ei-death-explosion-signal-",
        ("land-mine", "ei-prediction-snare-mine"): "ei-death-explosion-signal-micro",
        ("combat-robot", "ei-incinerator"): "ei-death-explosion-combustion-micro",
    }
    for key, prefix in expected.items():
        row = entities[key]
        assert str(row.get("dying_explosion")).startswith(prefix), (key, row.get("dying_explosion"))
    anisetron = entities[("spider-vehicle", "ei-anisetron")]
    visual_name = "ei-anisetron-lance-death-visual"
    effects = anisetron.get("dying_trigger_effect", [])
    if isinstance(effects, dict):
        effects = [effects]
    assert sum(effect.get("type") == "create-explosion" and effect.get("entity_name") == visual_name for effect in effects) == 1, "Missing/duplicate ANISETRON visual"
    visual = entities[("explosion", visual_name)]
    lance = entities[("explosion", "ei-singularity-lance-death-explosion")]
    for field in ("animations", "scale_out_duration", "scale_end", "scale_animation_speed"):
        assert visual.get(field) == lance.get(field), ("Lance visual mismatch", field)
    assert not any(field in visual for field in ("created_effect", "sound", "light", "smoke", "smoke_count")), "Visual imported bespoke aftermath"
    families = collections.Counter()
    for (kind, name), row in entities.items():
        if kind == "spider-vehicle" and name.startswith("ei-spider-"):
            family = name.split("-", 3)[2]
            source = {"scout": "ei-scout-spidertron", "assault": "assault_spidertron", "rocket": "spidertron"}[family]
            canonical = entities[(kind, source)]
            assert row.get("dying_explosion") == canonical.get("dying_explosion"), name
            assert row.get("dying_trigger_effect") == canonical.get("dying_trigger_effect"), name
            families[family] += 1
    assert all(families[family] > 1 for family in ("scout", "assault", "rocket")), families
    fuel_shells = 0
    for (kind, name), row in entities.items():
        if kind == "fluid-turret" and name.startswith("ei-flamethrower-turret-"):
            canonical = entities[(kind, "flamethrower-turret")]
            assert row.get("dying_explosion") == canonical.get("dying_explosion"), name
            assert row.get("dying_trigger_effect") == canonical.get("dying_trigger_effect"), name
            fuel_shells += 1
    assert fuel_shells > 0, "Missing fuel shells"
    bespoke = {
        ("spider-vehicle", "ei-gaian-saucer"): "ei-gaian-saucer-death-explosion",
        ("electric-turret", "ei-singularity-lance"): "ei-singularity-lance-death-explosion",
        ("electric-energy-interface", "ei_charger"): "ei-em-charger-death-explosion",
        ("car", "ei-emerald-apocalypse-hover-tank"): "ei-emerald-apocalypse-hover-tank-death-explosion",
        ("locomotive", "ei-nuclear-locomotive"): "locomotive-explosion",
    }
    for key, core in bespoke.items():
        assert entities[key].get("dying_explosion") == core, (key, entities[key].get("dying_explosion"))
    assert "ei-death-explosion-nuclear-locomotive-delay-anchor" in json.dumps(entities[("locomotive", "ei-nuclear-locomotive")].get("dying_trigger_effect"))
    mine = entities[("land-mine", "ei-prediction-snare-mine")]
    assert "ei-prediction-snare-sticker" in json.dumps(mine.get("action")), "Lost snare activation"
    if args.baseline:
        baseline = json.loads(args.baseline.read_text(encoding="utf-8"))
        assert preserved == baseline["preserved"], "Mine/robot payload or excluded helper death changed"
        expected_expiry = baseline["incinerator_expiry"]
        expiry_effects = expected_expiry["action_delivery"]["source_effects"]
        if isinstance(expiry_effects, dict):
            expiry_effects = [expiry_effects]
        expiry_effects.append({"type": "create-explosion", "entity_name": entities[("combat-robot", "ei-incinerator")]["dying_explosion"]})
        expected_expiry["action_delivery"]["source_effects"] = expiry_effects
        assert incinerator_expiry == expected_expiry, "Changed non-cosmetic robot expiry behavior"
    report.update(validation="passed", spider_bodies=dict(families), fuel_shells=fuel_shells)
    args.output.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(f"Death profiles, {dict(families)} spider bodies, {fuel_shells} fuel shells and preserved payloads passed; report: {args.output}")


if __name__ == "__main__":
    main()
