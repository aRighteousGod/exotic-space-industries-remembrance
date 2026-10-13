"""Compare selected final entities with the pre-patch dump and inspect scene QC."""
import argparse
import json
import mmap
import re
from pathlib import Path


def baseline_rows(path, names, fields):
    decoder = json.JSONDecoder()
    with path.open("rb") as handle, mmap.mmap(handle.fileno(), 0, access=mmap.ACCESS_READ) as mapped:
        headers = list(re.finditer(rb'^(  |    )"([^"\r\n]+)":', mapped, re.MULTILINE))
        attribute_pattern = re.compile(rb'^      "([^"\r\n]+)":', re.MULTILINE)
        category, rows = None, {}
        for i, header in enumerate(headers):
            if header.group(1) == b"  ":
                category = header.group(2).decode()
                continue
            name = header.group(2).decode()
            if (category, name) not in names:
                continue
            boundary = headers[i + 1].start() if i + 1 < len(headers) else len(mapped)
            attributes = list(attribute_pattern.finditer(mapped, header.end(), boundary))
            row = {}
            for j, attribute in enumerate(attributes):
                key = attribute.group(1).decode()
                if key in fields:
                    end = attributes[j + 1].start() if j + 1 < len(attributes) else boundary
                    row[key] = decoder.raw_decode(mapped[attribute.end():end].decode().lstrip())[0]
            rows[name] = row
        return rows


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("snapshot", type=Path)
    parser.add_argument("--baseline-dump", type=Path, required=True)
    parser.add_argument("--runtime", type=Path, required=True)
    parser.add_argument("--visual-report", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    snapshot = json.loads(args.snapshot.read_text(encoding="utf-8-sig"))
    entities = snapshot["entities"]
    names = {(row["type"], name) for name, row in entities.items()}
    preserved_fields = {"dying_explosion", "dying_trigger_effect", "attack_parameters", "action", "destroy_action",
                        "time_to_live", "max_health", "minable", "flags", "hidden", "hidden_in_factoriopedia",
                        "selectable_in_game", "factoriopedia_alternative"}
    presentation_fields = {"damaged_trigger_effect", "open_sound", "close_sound", "factoriopedia_simulation"}
    before = baseline_rows(args.baseline_dump, names, preserved_fields | presentation_fields)
    assert set(before) == set(entities), "Baseline profile missing selected entities"
    changed_scenes = {"ei-anisetron", "ei-scout-spidertron", "assault_spidertron", "ei-sweeping-radar",
                      "ei-phased-array-radar", "ei-incinerator", "ei-prediction-snare-mine"}
    for name, row in entities.items():
        for field in preserved_fields:
            assert row.get(field) == before[name].get(field), ("Gameplay/death changed", name, field)
        for field in presentation_fields:
            if field == "factoriopedia_simulation" and name in changed_scenes:
                continue
            if before[name].get(field) is not None:
                assert row.get(field) == before[name][field], ("Authored presentation changed", name, field)
    runtime = json.loads(args.runtime.read_text(encoding="utf-8-sig"))
    assert runtime["validation"] == "passed" and len(runtime["scenes"]) == 8
    for name, scene in runtime["scenes"].items():
        assert scene["body"] == name and scene["preroll_passed"] and scene["steady"], name
    assert runtime["elapsed_ticks"] >= 10800, "Robot lifetime not exercised"
    if args.visual_report:
        visual = json.loads(args.visual_report.read_text(encoding="utf-8-sig"))
        assert visual["capture_validation"] == "passed" and len(visual["scenes"]) == 8
        assert all(row["preroll_passed"] and row["body"] == name for name, row in visual["scenes"].items())
    report = {"validation": "passed", "selected_bodies": len(entities), "spider_bodies": snapshot["spider_bodies"],
              "fuel_shells": snapshot["fuel_shells"], "operational_bodies": snapshot["operational_bodies"],
              "native_scenes": len(runtime["scenes"]), "elapsed_ticks": runtime["elapsed_ticks"],
              "preserved": "gameplay, deaths and existing applicable presentation"}
    args.output.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report))


if __name__ == "__main__":
    main()
