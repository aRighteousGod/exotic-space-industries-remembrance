"""Validate the capture inventory and make review sheets from native screenshots."""
import hashlib
import json
from pathlib import Path
import re
import sys
from PIL import Image, ImageDraw

record = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8-sig"))
root = Path(record["write_data"]) / "script-output/mirroring/render"
receipt = json.loads((root / "receipt.json").read_text())
names = re.findall(r'"([^"]+)"', Path(__file__).with_name("cases.lua").read_text()) + ["ei-steam-oil-pumpjack"]
assert receipt["engine"] == "2.1.24" and len(receipt["captures"]) == 57
for row in receipt["captures"]:
    assert len(row["rows"]) == 8
    assert all(state["advanced"] and state["status"] == "working" for state in row["rows"]), row["name"]
inventory = {}
for name in names:
    for phase in ("covers", "pipes", "night"):
        files = [root / f"{name}-{phase}.png"]
        if phase != "covers":
            files += [root / f"{name}-{phase}-close-{index}.png" for index in (1, 2)]
        for path in files:
            with Image.open(path) as image:
                image.verify()
            inventory[path.name] = hashlib.sha256(path.read_bytes()).hexdigest()
assert len(inventory) == 133
for index, name in enumerate(names):
    # Full-resolution crops retain all eight directional bodies, then enlarge
    # the north-facing normal/mirrored pair for day/night connector/light review.
    sheet = Image.new("RGB", (1440, 1100), "#252525")
    draw = ImageDraw.Draw(sheet)
    draw.text((10, 5), name + " | N E S W; normal above mirrored; closeups day then night", fill="white")
    wide = Image.open(root / f"{name}-pipes.png")
    for column in range(4):
        for mirror in range(2):
            x, y = 272 + 416 * column, 390 + 500 * mirror
            crop = wide.crop((x - 180, y - 180, x + 180, y + 180))
            sheet.paste(crop, (column * 360, 25 + mirror * 360))
    for column, (phase, mirror) in enumerate((("pipes", 1), ("pipes", 2), ("night", 1), ("night", 2))):
        image = Image.open(root / f"{name}-{phase}-close-{mirror}.png")
        image = image.crop((128, 128, 896, 896)).resize((350, 350))
        sheet.paste(image, (column * 360, 745))
    sheet.save(root / f"review-{index + 1:02}-{name}.jpg", quality=93)
(root / "inventory.json").write_text(json.dumps({"engine": receipt["engine"], "native_images": 133,
    "working_states": 456, "files_sha256": inventory}, indent=2) + "\n")
print("133 images verified; 456 working states; 19 review sheets generated")
