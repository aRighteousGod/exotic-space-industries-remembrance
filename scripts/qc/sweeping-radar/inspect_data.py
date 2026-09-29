"""Extract authoritative final prototypes without loading the 2 GB dump at once."""
import argparse
import json
import mmap
import re
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument("dump", type=Path)
parser.add_argument("output", type=Path)
args = parser.parse_args()
names = ["ei-sweeping-radar", "ei-phased-array-radar"]
with args.dump.open("rb") as source, mmap.mmap(source.fileno(), 0, access=mmap.ACCESS_READ) as raw:
    def category(name):
        match = re.search(rb'\n  "' + name.encode() + rb'":\s*\{', raw)
        assert match, name
        start = match.end() - 1
        end = raw.find(b"\n  }", start) + 4
        assert end > start
        return json.loads(raw[start:end])

    radars = category("radar")
    recipes = category("recipe")
    technologies = category("technology")
    buffers = category("electric-energy-interface")
    output = {"radars": {}, "recipes": {}, "technologies": {}, "buffers": {}}
    for name in names:
        radar = radars[name]
        assert radar["energy_source"]["type"] == "void"
        assert radar["max_distance_of_sector_revealed"] == 0
        assert radar["max_distance_of_nearby_sector_revealed"] == 0
        assert radar["rotation_speed"] == 0 and not radar["connects_to_other_radars"]
        assert radar["fast_replaceable_group"] == "ei-sweeping-radar"
        assert radar["heating_energy"] == "300kW"
        output["radars"][name] = {key: radar.get(key) for key in ("max_health", "collision_box", "selection_box",
            "next_upgrade", "fast_replaceable_group", "max_distance_of_sector_revealed", "max_distance_of_nearby_sector_revealed", "heating_energy")}
        assert recipes[name].get("allow_productivity") is False
        output["recipes"][name] = recipes[name]
        output["technologies"][name] = technologies[name]
        output["buffers"][name] = {key: buffers[name + "-power"][key] for key in ("energy_usage", "energy_source")}
        idle, input_limit, capacity = ((1000000,64000000,16000000) if name==names[0] else (2000000,128000000,10000000))
        buffer = output["buffers"][name]
        assert buffer["energy_usage"] == f"{idle}W"
        assert buffer["energy_source"]["input_flow_limit"] == f"{input_limit}W"
        assert buffer["energy_source"]["buffer_capacity"] == f"{capacity}J"
        assert buffer["energy_source"]["drain"] == "0W" and buffer["energy_source"]["output_flow_limit"] == "0W"
        assert name + "-recycling" in recipes
    for branch in ("range", "capacity", "efficiency"):
        for level in (1, 2, 3):
            name = f"ei-radar-{branch}-{level}"
            assert name in technologies
            output["technologies"][name] = technologies[name]
    output["standard_radar"] = {key: radars["radar"].get(key) for key in ("energy_usage", "energy_source", "max_distance_of_sector_revealed", "max_distance_of_nearby_sector_revealed")}
args.output.write_text(json.dumps(output, indent=2), encoding="utf-8")
print(f"Final radar prototype audit passed: {args.output}")
