"""Native lamp crops for every requested orientation and all circuit/energy transitions."""
import json
import sys
from itertools import product
from pathlib import Path
from PIL import Image, ImageDraw

run = Path(sys.argv[1])
root = run / "script-output" / "machine-lights"
output = run / "review"
output.mkdir(exist_ok=True)
final = json.loads((root / "status-final.json").read_text())
scenes = json.loads((root / "status-visual.json").read_text())["captures"]
states = ["working", "idle", "missing-input", "full-output", "disabled", "no-power", "low-power"]
names = [name for name, lamps in final["expected"].items() if lamps]
directions = sorted({r["direction"] for s in scenes for r in s["rows"]})


def paste_lamps(canvas, atlas, row, lamps, origin, destination, zoom=2):
    center = [sum(p[i] for p in lamps) / len(lamps) for i in (0, 1)]
    x = atlas.width / 2 + (row["position"][0] + center[0] - origin[0]) * 32 * zoom
    y = atlas.height / 2 + (row["position"][1] + center[1] - origin[1]) * 32 * zoom
    canvas.paste(atlas.crop((round(x) - 56, round(y) - 28, round(x) + 56, round(y) + 28)), destination)


canvases = {}
for zoom, lighting, direction in product((1, 2), ("day", "night"), directions):
    canvas = Image.new("RGB", (1040, 70 + len(names) * 70), "#242424")
    draw = ImageDraw.Draw(canvas)
    draw.text((5, 5), f"Native zoom {zoom} / {lighting} / requested direction {direction}", fill="white")
    for col, state in enumerate(states):
        draw.text((190 + col * 120, 24), state, fill="white")
    canvases[zoom, lighting, direction] = canvas

# Decode each large atlas once, sharing it across its orientation crop sheets.
for index, name in enumerate(names):
    scene = next(s for s in scenes if s["name"] == name)
    for zoom, lighting in product((1, 2), ("day", "night")):
        with Image.open(root / "status" / f"{name}-{lighting}-{zoom}.png") as atlas:
            for direction in directions:
                canvas = canvases[zoom, lighting, direction]
                draw = ImageDraw.Draw(canvas)
                y = 48 + index * 70
                rows = [r for r in scene["rows"] if r["direction"] == direction]
                draw.text((5, y + 6), name.removeprefix("ei-"), fill="white")
                draw.text((5, y + 22), "actual " + str(rows[0]["actual_direction"]), fill="#aaaaaa")
                for row in rows:
                    paste_lamps(canvas, atlas, row, final["expected"][name], (0, 0), (190 + states.index(row["state"]) * 120, y), zoom)
for (zoom, lighting, direction), canvas in canvases.items():
    suffix = "-normal" if zoom == 1 else ""
    canvas.save(output / f"lamps-{lighting}-direction-{direction}{suffix}.png")

if "--scenes-only" in sys.argv:
    print(output)
    raise SystemExit(0)

transitions = json.loads((root / "status-transitions.json").read_text())["rows"]
labels = ["circuit-disabled", "circuit-resumed", "energy-lost", "energy-restored", "output-blocked", "output-cleared", "power-limited", "power-restored"]
canvas = Image.new("RGB", (190 + 155 * len(labels), 50 + len(names) * 70), "#242424")
draw = ImageDraw.Draw(canvas)
for col, label in enumerate(labels):
    draw.text((190 + col * 155, 6), label, fill="white")
for index, name in enumerate(names):
    y = 30 + index * 70
    draw.text((5, y + 6), name.removeprefix("ei-"), fill="white")
    for col, label in enumerate(labels):
        row = next((r for r in transitions if r["name"] == name and r["transition"] == label), None)
        if row is None:
            continue
        with Image.open(root / "transitions" / f"{name}-{label}.png") as atlas:
            paste_lamps(canvas, atlas, row, final["expected"][name], (-72, -36), (190 + col * 155, y))
canvas.save(output / "lamp-transitions.png")

# The refinery now colors its whole display, so retain a dedicated readable
# comparison of the inset screen at both native zoom levels and lighting states.
name = "ei-advanced-refinery"
scene = next(s for s in scenes if s["name"] == name)
offset = final["expected"][name][0]
screen_states = ["working", "full-output", "low-power", "missing-input", "no-power"]
canvas = Image.new("RGB", (850, 490), "#242424")
draw = ImageDraw.Draw(canvas)
for column, state in enumerate(screen_states):
    draw.text((10 + column * 170, 5), state, fill="white")
for index, (lighting, zoom) in enumerate((("day", 1), ("night", 1), ("day", 2), ("night", 2))):
    draw.text((5, 25 + index * 110), f"{lighting} / native zoom {zoom}", fill="white")
    with Image.open(root / "status" / f"{name}-{lighting}-{zoom}.png") as atlas:
        for column, state in enumerate(screen_states):
            row = next(r for r in scene["rows"] if r["state"] == state and r["direction"] == 0)
            cx = atlas.width / 2 + (row["position"][0] + offset[0]) * 32 * zoom
            cy = atlas.height / 2 + (row["position"][1] + offset[1]) * 32 * zoom
            crop = atlas.crop((round(cx) - 30, round(cy) - 20, round(cx) + 30, round(cy) + 20))
            canvas.paste(crop.resize((150, 100), Image.Resampling.NEAREST), (column * 170 + 10, 43 + index * 110))
canvas.save(output / "refinery-whole-screen-native.png")
print(output)
