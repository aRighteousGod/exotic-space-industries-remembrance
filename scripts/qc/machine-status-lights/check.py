"""Compare native final prototypes, independently measured offsets, and real states."""
import argparse
import copy
import json
from pathlib import Path
from PIL import Image

parser = argparse.ArgumentParser()
parser.add_argument("output", type=Path)
args = parser.parse_args()
root = args.output / "machine-lights"
load = lambda name: json.loads((root / name).read_text(encoding="utf-8-sig"))
baseline = load("baseline-final.json")
baseline_states = {(r["name"], r["state"], r["direction"]): r["actual_direction"]
                   for r in load("baseline-runtime.json")["rows"]}
checks = 0


def check(condition, message):
    global checks
    checks += 1
    assert condition, message


plain = {"light": {"type": "basic", "intensity": 1, "size": 15}}
red, green = [1, 0.06, 0.03, 1], [0.08, 1, 0.12, 1]
colors = dict(idle=red, insufficient_input=red, full_output=[1, 1, 0, 1], disabled=red,
              working=green, low_power=[1, .5, 0, 1], no_power=[0, 0, 0, 0])
additive = {"ei-arc-furnace", "ei-plasma-heater", "ei-caster"}
check(len(baseline["expected"]) == 28, "28 targets")
check(sum(bool(v) for v in baseline["expected"].values()) == 20, "20 indicator bodies")
check(sum(len(v) for v in baseline["expected"].values()) == 23, "23 emitters")
for mode in ("original", "status", "off"):
    current = load(mode + "-final.json")
    emitters = 0
    for name, before in baseline["snapshot"].items():
        after = copy.deepcopy(current["snapshot"][name])
        expected = copy.deepcopy(before)
        if name in baseline["expected"]:
            old_visuals = expected["graphics_set"]["working_visualisations"]
            check(sum(v == plain for v in old_visuals) == (0 if name in additive else 1), name + " baseline light")
            if mode != "original":
                expected["graphics_set"]["working_visualisations"] = [v for v in old_visuals if v != plain]
                offsets = baseline["expected"][name]
                if mode == "status" and offsets:
                    check(after["graphics_set"].pop("status_colors") == colors, name + " colors")
                    visuals = after["graphics_set"]["working_visualisations"]
                    lights = [v for v in visuals if v.get("apply_tint") == "status"]
                    check(len(lights) == len(offsets), name + " count")
                    if name in additive:
                        check(visuals[:len(lights)] == lights, name + " status entries first")
                    emitters += len(lights)
                    for index, (visual, offset) in enumerate(zip(lights, offsets), 1):
                        check(set(visual) == {"always_draw", "apply_tint", "light", "animation", "render_layer", "secondary_draw_order", "north_position", "east_position", "south_position", "west_position"}, name + " exact light entry fields")
                        check(visual['render_layer'] == 'light-effect' and visual['secondary_draw_order'] == 4, name + ' lens ordering')
                        check(visual['animation'] == dict(filename=f'__exotic-space-industries-remembrance__/graphics/status-lights/{name[3:]}-{index}.png', size=64, scale=before['graphics_set']['animation'].get('scale', 1), frame_count=1, draw_as_glow=True, blend_mode='normal'), name + ' neutral lens')
                        check(visual["always_draw"] is True, name + " idle visibility")
                        check(visual["light"] == dict(type="basic", color=[1, 1, 1], size=0.5 if name == 'ei-advanced-refinery' else 0.35,
                                                      intensity=1, minimum_darkness=0.1), name + " light profile")
                        for direction in ("north", "east", "south", "west"):
                            check(all(abs(a - b) < 1e-12 for a, b in zip(visual[direction + "_position"], offset)), name + " center")
                    after["graphics_set"]["working_visualisations"] = [v for v in visuals if v not in lights]
        check(after == expected, mode + " complete prototype preservation: " + name)
    check(emitters == (23 if mode == "status" else 0), mode + " total emitters")
    runtime = load(mode + "-runtime.json")
    check(runtime["startup"] == mode, mode + " actual startup setting")
    check(runtime["failed"] == 0 and len(runtime["rows"]) == 764, mode + " native state/direction coverage")
    check(all(row["valid"] for row in runtime["rows"]), mode + " actual statuses")
    check(all(row["actual_direction"] == baseline_states[(row["name"], row["state"], row["direction"])]
              for row in runtime["rows"]), mode + " native direction preservation")
    transitions = load(mode + "-transitions.json")
    check(transitions["complete"] and transitions["checks"] == 156 and all(row["valid"] for row in transitions["rows"]), mode + " circuit/energy/output transitions")

visual = load("status-visual.json")
check(visual["complete"] and visual["scenes"] == 28 and visual["images"] == 112, "complete visual report")
check(len(visual["captures"]) == 28 and all(r["valid"] for s in visual["captures"] for r in s["rows"]), "capture-time native statuses")
expected_paths = set()
for name in baseline["expected"]:
    for lighting in ("day", "night"):
        for zoom in (1, 2):
            path = root / "status" / f"{name}-{lighting}-{zoom}.png"
            expected_paths.add(path.name)
            check(path.stat().st_mtime >= (args.output.parent / "status.zip").stat().st_mtime, "fresh capture " + path.name)
            with Image.open(path) as image:
                check(image.size == (5632 * zoom, 3584 * zoom), "capture dimensions " + path.name)
                image.verify()
check({p.name for p in (root / "status").glob("*.png")} == expected_paths, "unique capture coverage")
for mode in ("off", "original"):
    report = load(mode + "-visual.json")
    check(report["complete"] and report["images"] == 28, mode + " visual report")
    check(all(r["valid"] for s in report["captures"] for r in s["rows"]), mode + " capture-time states")
    for name in baseline["expected"]:
        path = root / mode / f"{name}-night-1.png"
        check(path.stat().st_mtime >= (args.output.parent / f"{mode}.zip").stat().st_mtime, mode + " fresh capture")
        with Image.open(path) as image:
            check(image.size == (5632, 3584), mode + " capture dimensions")
            image.verify()
for name, offsets in baseline["expected"].items():
    if not offsets:
        continue
    labels = ["circuit-disabled", "circuit-resumed", "energy-lost", "energy-restored", "output-blocked", "output-cleared"]
    if baseline['snapshot'][name]['energy_source']['type'] == 'electric':
        labels += ['power-limited', 'power-restored']
    for label in labels:
        path = root / "transitions" / f"{name}-{label}.png"
        check(path.stat().st_mtime >= (args.output.parent / "status.zip").stat().st_mtime, "fresh transition capture")
        with Image.open(path) as image:
            check(image.size == (768, 768), "transition dimensions")
            image.verify()
brightness = load("brightness-reference.json")["rows"]
check(len(brightness) == 80 and all(r["valid"] for r in brightness), "native brightness comparison states")
check(sum(bool(r.get("reference")) for r in brightness) == 30, "30 assembler reference cases")
check({r.get("intensity") for r in brightness if not r.get("reference")} == {0.35, 0.5, 0.65, 0.8, 1}, "50 intensity comparison cases")
check(all("__Assembler-Reskin__/" in r["reference_lamp"] for r in brightness if r.get("reference")), "reference reskin identity")
check(all(r.get("network") and r.get("reference_colors") for r in brightness if r.get("reference")), "powered reference networks and native colors")
for lighting in ("day", "night"):
    for zoom in (1, 2):
        path = root / f"brightness-{lighting}-{zoom}.png"
        check(path.stat().st_mtime >= (args.output.parent / "status.zip").stat().st_mtime, "fresh brightness capture")
        with Image.open(path) as image:
            check(image.size == (2816 * zoom, 3584 * zoom), "brightness capture dimensions")
            image.verify()
result = {"overall_status": "ok", "validation": "passed", "checks": checks, "targets": 28, "indicator_bodies": 20,
          "status_emitters": 23,
          "excluded_bodies_preserved": sum(bool(p) for n, p in baseline["snapshot"].items() if n not in baseline["expected"]),
          "excluded_absences_preserved": sum(not p for p in baseline["snapshot"].values()),
          "startup_modes": ["original", "status", "off"], "native_states_per_mode": 764,
          "transitions_per_mode": 156, "brightness_comparison_cases": 80, "visual_images": 328}
(root / "acceptance.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
print(json.dumps(result))
