"""Make native capture contact sheets and measure status-vs-off lamp differences."""
import json
import hashlib
import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

run = Path(sys.argv[1])
root = run / "script-output" / "machine-lights"
output = run / "review"
output.mkdir(exist_ok=True)
final = json.loads((root / "status-final.json").read_text())
names = list(final["expected"])
states = ["working", "idle", "missing-input", "full-output", "disabled", "no-power", "low-power"]
lighting = "day" if "--day" in sys.argv else "night"

# Native double-zoom crops retain the exact rendered pixels for review.
for batch in range(math.ceil(len(names) / 5)):
    canvas = Image.new("RGB", (1260, 940), "#242424")
    draw = ImageDraw.Draw(canvas)
    for s, state in enumerate(states):
        draw.text((s * 180 + 8, 6), state, fill="white")
    for row, name in enumerate(names[batch * 5:batch * 5 + 5]):
        with Image.open(root / "status" / f"{name}-{lighting}-2.png") as atlas:
            sprite = final["snapshot"][name]["graphics_set"]["animation"]
            if "layers" in sprite:
                sprite = sprite["layers"][0]
            size = sprite.get("size", [sprite.get("width", 512), sprite.get("height", 512)])
            if isinstance(size, (int, float)):
                size = [size, size]
            half = int(max(size) * sprite.get("scale", 1) + 48)
            draw.text((6, row * 180 + 26), name, fill="white")
            for s in range(7):
                x, y = atlas.width / 2 + (s - 3) * 24 * 64, atlas.height / 2 - 36 * 64
                crop = atlas.crop((int(x - half), int(y - half), int(x + half), int(y + half)))
                canvas.paste(crop.resize((176, 150)), (s * 180 + 2, row * 180 + 48))
    canvas.save(output / f"{lighting}-states-{batch + 1}.png")

if "--contact-only" in sys.argv:
    print(output)
    raise SystemExit(0)

off_report = json.loads((root / "off-visual.json").read_text())
records = []
capture_hashes = {}
for scene in off_report["captures"]:
    name = scene["name"]
    offsets = final["expected"][name]
    if not offsets:
        continue
    for mode in ("status", "off"):
        path = root / mode / f"{name}-night-1.png"
        capture_hashes[str(path.relative_to(root))] = hashlib.sha256(path.read_bytes()).hexdigest()
    with Image.open(root / "status" / f"{name}-night-1.png") as a, Image.open(root / "off" / f"{name}-night-1.png") as off_image:
        for row in scene["rows"]:
            centers = [(a.width / 2 + (row["position"][0] + offset[0]) * 32,
                        a.height / 2 + (row["position"][1] + offset[1]) * 32) for offset in offsets]
            for light_index, offset in enumerate(offsets):
                cx, cy = centers[light_index]
                left, top = round(cx) - 16, round(cy) - 16
                box = (left, top, left + 33, top + 33)
                rendered = np.array(a.crop(box).convert("RGB"), dtype=np.int16)
                difference = rendered - np.array(off_image.crop(box).convert("RGB"), dtype=np.int16)
                positive = np.maximum(difference, 0)
                yy, xx = np.indices(difference.shape[:2])
                xx, yy = xx + left + 0.5, yy + top + 0.5
                distances = np.stack([(xx - x) ** 2 + (yy - y) ** 2 for x, y in centers])
                nearest = min((math.hypot(cx - x, cy - y) for j, (x, y) in enumerate(centers) if j != light_index), default=math.inf)
                radius = min(6, 0.4 * nearest)
                mask = (distances.argmin(axis=0) == light_index) & (distances[light_index] <= radius ** 2)
                r, g, b = (rendered[:, :, i].astype(float) for i in range(3))
                if row['state'] == 'full-output':
                    chroma = np.maximum(np.minimum(r, g) - b, 0) * (np.minimum(r, g) >= .75 * np.maximum(r, g))
                elif row['state'] == 'low-power':
                    chroma = np.maximum(np.minimum(r - 1.1 * g, g - b), 0)
                elif row['state'] == 'working':
                    chroma = np.maximum(g - np.maximum(r, b), 0)
                else:
                    chroma = np.maximum(r - np.maximum(g, b), 0)
                # Normal-blended lenses may replace old color instead of adding
                # both channels. Check rendered chroma where Status changes Off.
                chroma *= (np.abs(difference).max(axis=2) >= 3)
                weights = chroma.astype(float) * mask
                total = float(weights.sum())
                channel = positive.sum(axis=(0, 1)).tolist()
                contrast = int((chroma * mask).max())
                if total:
                    centroid = [float((xx * weights).sum() / total), float((yy * weights).sum() / total)]
                    distance = math.hypot(centroid[0] - cx, centroid[1] - cy)
                else:
                    centroid, distance = None, None
                records.append({"name": name, "state": row["state"], "status": row["status"],
                                "direction": row["direction"], "actual_direction": row["actual_direction"],
                                "light": light_index, "expected_pixel": [cx, cy], "centroid": centroid,
                                "distance_pixels": distance, "positive_rgb": channel,
                                "core_contrast": contrast, "visible_expected_color": contrast >= 5,
                                "max_difference": int(np.abs(difference).max()), "weight": total})

profile = next(v["light"] for v in final["snapshot"]["ei-crusher"]["graphics_set"]["working_visualisations"] if v.get("apply_tint") == "status")
report = {"lamp_regions": len(records), "profile": profile, "capture_sha256": capture_hashes, "records": records}
(output / "native-light-pixels.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
for state in states:
    group = [r for r in records if r["state"] == state]
    lit = [r for r in group if r["visible_expected_color"]]
    print(state, "regions", len(group), "nonzero", len(lit), "max_difference", max(r["max_difference"] for r in group),
          "max_distance", max((r["distance_pixels"] for r in lit), default=None))
    if state == "no-power":
        assert all(r["max_difference"] == 0 for r in group), "No-energy glow must be absent"
    else:
        # Native lens overlays remain readable even against authored process
        # effects; require every powered indicator, with no process-glow waiver.
        assert len(lit) == len(group), "Missing expected lamp color: " + str([r for r in group if not r["visible_expected_color"]])
        assert all(r["distance_pixels"] < 1.5 for r in lit), "Lamp alignment"

if "--pixels-only" in sys.argv:
    raise SystemExit(0)

# Compact before/after reference from actual native normal-zoom captures.
show = ["ei-crusher", "ei-advanced-chem-plant", "ei-fission-facility", "ei-castor", "ei-high-temperature-reactor"]
columns = [("original", "working", 0), ("status", "working", 0), ("status", "idle", 1), ("status", "no energy", 5), ("off", "working", 0)]
canvas = Image.new("RGB", (1000, 1130), "#242424")
draw = ImageDraw.Draw(canvas)
for col, (mode, label, _) in enumerate(columns):
    draw.text((col * 200 + 8, 8), mode + ": " + label, fill="white")
for index, name in enumerate(show):
    draw.text((8, 32 + index * 218), name, fill="white")
    for col, (mode, _, state_index) in enumerate(columns):
        with Image.open(root / mode / f"{name}-night-1.png") as atlas:
            x, y = atlas.width / 2 + (state_index - 3) * 24 * 32, atlas.height / 2 - 36 * 32
            crop = atlas.crop((int(x - 128), int(y - 128), int(x + 128), int(y + 128)))
            canvas.paste(crop.resize((198, 190)), (col * 200 + 1, 52 + index * 218))
canvas.save(output / "mode-comparison.png")
print(output)
