"""Prepare icons from an approved full-model view, with native-size review."""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path

from PIL import Image, ImageDraw

parser = argparse.ArgumentParser()
parser.add_argument("--root", type=Path, required=True)
parser.add_argument("--frame", type=int, default=2)
args = parser.parse_args()
root = args.root
source = sorted((root / "renders/Object").glob("*.png"))[args.frame - 1]
spec = importlib.util.spec_from_file_location(
    "icon_prep", Path.cwd() / ".codex/skills/esir-item-icon-prep/scripts/build_factorio_item_icon.py"
)
prep = importlib.util.module_from_spec(spec)
spec.loader.exec_module(prep)
subject = prep.prepare_subject(Image.open(source).convert("RGBA"), 128, [64, 32], False)


def clean(image):
    # Keep the renderer's straight alpha; paste with a mask would square it.
    pixels = image.load()
    for y in range(image.height):
        for x in range(image.width):
            if pixels[x, y][3] == 0:
                pixels[x, y] = (0, 0, 0, 0)
    return image


def fit(size, inner):
    scaled = subject.copy()
    scaled.thumbnail((inner, inner), Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", (size, size))
    canvas.paste(scaled, ((size - scaled.width) // 2, (size - scaled.height) // 2))
    return clean(canvas)


item = fit(128, 118)
technology = fit(256, 236)
strip = Image.new("RGBA", (224, 128))
strip.paste(item, (0, 0))
cursor = 128
for size in (64, 32):
    strip.paste(clean(item.resize((size, size), Image.Resampling.LANCZOS)), (cursor, 0))
    cursor += size
item.save(root / "item-preview.png")
strip.save(root / "acid-turret-item.png", optimize=True)
technology.save(root / "acid-turret-technology.png", optimize=True)

review = Image.new("RGB", (768, 354), (35, 39, 43))
draw = ImageDraw.Draw(review)
for x, icon, label in [(16, technology, "Technology / 256px"), (304, item, "Item / 128px"),
                       (472, item.resize((64, 64), Image.Resampling.LANCZOS), "64px"),
                       (576, item.resize((32, 32), Image.Resampling.LANCZOS), "32px")]:
    draw.text((x, 14), label, fill="white")
    panel = Image.new("RGBA", icon.size, (35, 39, 43, 255))
    panel.alpha_composite(icon)
    review.paste(panel.convert("RGB"), (x, 40))
review.save(root / "icon-review.png")
report = {"source": str(source), "selected_frame": args.frame, "all_pass": True, "icons": {}}
for filename, image in [("acid-turret-item.png", strip), ("acid-turret-technology.png", technology)]:
    bounds = image.getbbox()
    assert bounds and image.getchannel("A").getextrema() == (0, 255)
    report["icons"][filename] = {"size": list(image.size), "alpha_bounds": bounds,
        "sha256": hashlib.sha256((root / filename).read_bytes()).hexdigest()}
report["item_mip_sizes"] = [128, 64, 32]
(root / "icon-qa.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
print(json.dumps(report))
