"""Compare native assembler emissive lamps with candidate point-light profiles."""
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

run = Path(sys.argv[1])
root = run / "script-output" / "machine-lights"
output = run / "review"
output.mkdir(exist_ok=True)
rows = json.loads((root / "brightness-reference.json").read_text())["rows"]
metrics = []
for lighting in ("day", "night"):
    canvas = Image.new("RGB", (1088, 1560), "#242424")
    draw = ImageDraw.Draw(canvas)
    with Image.open(root / f"brightness-{lighting}-2.png") as atlas:
        for index, row in enumerate(rows):
            column, line = index % 8, index // 8
            x = atlas.width / 2 + (row["position"][0] + row["lamps"][0][0]) * 64
            y = atlas.height / 2 + (row["position"][1] + row["lamps"][0][1]) * 64
            patch = atlas.crop((round(x) - 24, round(y) - 24, round(x) + 24, round(y) + 24))
            canvas.paste(patch.resize((120, 120), Image.Resampling.NEAREST), (column * 136 + 8, line * 156 + 32))
            label = row["name"][-1] if row.get("reference") else str(row["intensity"])
            draw.text((column * 136 + 8, line * 156 + 2), ("AM " if row.get("reference") else "Glow ") + label + " " + row["state"], fill="white")
            if column == 0:
                draw.text((column * 136 + 8, line * 156 + 17), row["source"].removeprefix("ei-"), fill="white")
            core = np.array(atlas.crop((round(x) - 5, round(y) - 5, round(x) + 6, round(y) + 6)).convert("RGB"))
            channel = 1 if row["state"] == "working" else 0
            values = np.sort(core[:, :, channel].flatten())
            srgb = core.astype(float) / 255
            linear = np.where(srgb <= 0.04045, srgb / 12.92, ((srgb + 0.055) / 1.055) ** 2.4)
            luminance = np.sort((linear @ np.array([0.2126, 0.7152, 0.0722])).flatten())
            mean_y = float(luminance[-10:].mean())
            lightness = 116 * mean_y ** (1 / 3) - 16 if mean_y > 0.008856 else 903.3 * mean_y
            metrics.append({"source": row["source"], "state": row["state"], "lighting": lighting,
                            "reference": row.get("reference", False), "intensity": row.get("intensity"),
                            "name": row["name"], "peak": int(values[-1]), "brightest_ten_mean": float(values[-10:].mean()),
                            "brightest_ten_luminance": mean_y, "lightness": lightness})
    canvas.save(output / f"assembler-brightness-{lighting}.png")
(output / "assembler-brightness.json").write_text(json.dumps(metrics, indent=2) + "\n", encoding="utf-8")
for lighting in ("day", "night"):
    for state in ("working", "idle"):
        for level in (None, 0.35, 0.5, 0.65, 0.8, 1.0):
            group = [m for m in metrics if m["lighting"] == lighting and m["state"] == state and m["intensity"] == level]
            print(lighting, state, "reference" if level is None else level,
                  "mean bright core", round(sum(m["brightest_ten_mean"] for m in group) / len(group), 1),
                  "mean L*", round(sum(m["lightness"] for m in group) / len(group), 1),
                  "peak range", min(m["peak"] for m in group), max(m["peak"] for m in group))
