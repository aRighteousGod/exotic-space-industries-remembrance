"""Export four generated, transparent GUI sprites on one fixed registration.

No semantic edits or per-season cropping: imagegen owns the illustrations.
Only resize, deterministic layout and source/provenance copying happen here.
"""
import argparse
import hashlib
import json
import shutil
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, required=True,
                        help="Directory containing spring/summer/autumn/winter.png")
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--promote", type=Path, help="Explicit shipping GUI directory")
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    records = []
    sheet = Image.new("RGB", (960, 430), "#171d22")
    draw = ImageDraw.Draw(sheet)
    font = ImageFont.truetype("C:/Windows/Fonts/segoeuib.ttf", 22)
    small = ImageFont.truetype("C:/Windows/Fonts/segoeui.ttf", 16)
    draw.text((28, 18), "ECOLOGY / SEASONAL MECHANICAL TREES", font=font, fill="#eee9dc")
    for i, season in enumerate(("spring", "summer", "autumn", "winter")):
        source = args.source / f"{season}.png"
        with Image.open(source) as im:
            assert im.mode == "RGBA" and im.size == (1254, 1254), (source, im.mode, im.size)
            assert im.getchannel("A").getextrema()[0] == 0, source
            exported = im.resize((128, 128), Image.Resampling.LANCZOS)
            target = args.output / f"ecology-tree-{season}.png"
            exported.save(target, optimize=True)
            x = i * 232 + 76
            sheet.paste(im.resize((192, 192), Image.Resampling.LANCZOS), (x-42, 72), im.resize((192,192), Image.Resampling.LANCZOS))
            draw.text((x-8, 276), season.upper(), font=font, fill="#eee9dc")
            draw.rounded_rectangle((x+27, 321, x+67, 361), radius=3, fill="#55585b", outline="#777b80")
            toolbar = exported.resize((32, 32), Image.Resampling.LANCZOS)
            sheet.paste(toolbar, (x+31, 325), toolbar)
            records.append({"season": season, "source_sha256": hashlib.sha256(source.read_bytes()).hexdigest(),
                            "sprite_sha256": hashlib.sha256(target.read_bytes()).hexdigest(), "size": [128,128],
                            "alpha_bounds": exported.getchannel("A").point(lambda v: 255 if v >= 128 else 0).getbbox()})
            if args.promote:
                args.promote.mkdir(parents=True, exist_ok=True)
                shutil.copy2(target, args.promote / target.name)
    draw.text((28, 391), "Same copper mechanism ??? Seasonal enamel ??? 32 px toolbar previews", font=small, fill="#b5c5c9")
    sheet.save(args.output / "seasonal-tree-preview.png", optimize=True)
    (args.output / "manifest.json").write_text(json.dumps({"sprites": records}, indent=2)+"\n", encoding="utf-8")


if __name__ == "__main__":
    main()
