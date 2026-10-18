"""Mechanical 4:1 export of approved illustrations; originals remain untouched."""
import argparse
import hashlib
import json
import shutil
from pathlib import Path
from PIL import Image, ImageDraw

parser = argparse.ArgumentParser()
parser.add_argument("staging", type=Path)
parser.add_argument("--promote", action="store_true")
args = parser.parse_args()
repo = Path(__file__).resolve().parents[3]
staging = args.staging.resolve()
manifest = json.loads((staging / "prompts.json").read_text(encoding="utf-8"))
sources = staging / "sources"
exports = staging / "exports"
sources.mkdir(exist_ok=True)
exports.mkdir(exist_ok=True)
sheet = Image.new("RGB", (768, 6 * 216), "#161c20")
draw = ImageDraw.Draw(sheet)
records = {}
for row, (planet, original) in enumerate(manifest["original_paths"].items()):
    source = sources / f"{planet}.png"
    if not source.exists():
        shutil.copyfile(original, source)
    image = Image.open(source).convert("RGB")
    width, height = image.size
    # Crop only excess sky/foreground to the user-approved 4:1 canvas.
    crop_height = width // 4
    if crop_height <= height:
        top = (height - crop_height) // 2
        box = (0, top, width, top + crop_height)
    else:
        crop_width = height * 4
        left = (width - crop_width) // 2
        box = (left, 0, left + crop_width, height)
    banner = image.crop(box).resize((1536, 384), Image.Resampling.LANCZOS)
    name = f"ecology-field-{planet}.png"
    destination = exports / name
    banner.save(destination, optimize=True)
    sheet.paste(banner.resize((768, 192), Image.Resampling.LANCZOS), (0, row * 216 + 24))
    draw.text((12, row * 216 + 5), planet.upper(), fill="#efe8d5")
    records[planet] = {"source_size": [width, height], "crop": box,
        "output_size": [1536, 384], "source_sha256": hashlib.sha256(source.read_bytes()).hexdigest(),
        "output_sha256": hashlib.sha256(destination.read_bytes()).hexdigest()}
    if args.promote:
        shipping = repo / "exotic-space-industries-remembrance-graphics-6/graphics/gui" / name
        shutil.copyfile(destination, shipping)
sheet.save(staging / "contact-sheet.png", optimize=True)
(staging / "manifest.json").write_text(json.dumps(records, indent=2) + "\n", encoding="utf-8")
print(json.dumps({"banners": len(records), "size": [1536, 384], "promoted": args.promote}))
