"""Export approved transparent portraits and deterministic research glyphs.

Portraits are authored with image_gen; this script only resizes those exports.
Glyphs are original geometric UI marks, rendered at 4x for clean small-size edges.
Run without --promote to review staged PNGs before copying into the main mod.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import shutil
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[3]
STAGE = ROOT / "output/meshy/spider-technology-icons/factorio-export"
SHIP = ROOT / "exotic-space-industries-remembrance/graphics/technology/spider-vehicles"


def glyph(name: str) -> Image.Image:
    """A transparent 128px symbol; no plate, lettering font, or baked subject."""
    scale = 4
    image = Image.new("RGBA", (128 * scale, 128 * scale))
    draw = ImageDraw.Draw(image)
    ink = (241, 225, 180, 255)
    edge = (24, 27, 31, 255)

    def line(points, width=11):
        points = [(round(x * scale), round(y * scale)) for x, y in points]
        draw.line(points, fill=edge, width=(width + 8) * scale, joint="curve")
        draw.line(points, fill=ink, width=width * scale, joint="curve")

    def arc(box, start, end):
        box = tuple(x * scale for x in box)
        draw.arc(box, start, end, fill=edge, width=19 * scale)
        draw.arc(box, start, end, fill=ink, width=11 * scale)

    def arrow(a, b, head):
        line([a, b])
        line([head[0], b, head[1]])

    if name.startswith("tier-"):
        count = int(name[-1])
        for index in range(count):
            x = 64 + (index - (count - 1) / 2) * 30
            line([(x, 23), (x, 105)], 15)
            line([(x - 10, 23), (x + 10, 23)], 8)
            line([(x - 10, 105), (x + 10, 105)], 8)
    elif name in ("range", "tracking"):
        arrow((57, 64), (20, 64), [(36, 46), (36, 82)])
        arrow((71, 64), (108, 64), [(92, 46), (92, 82)])
        if name == "tracking":
            arc((39, 26, 89, 102), 235, 305)
            arc((39, 26, 89, 102), 55, 125)
        else:
            line([(16, 23), (16, 40)], 8)
            line([(112, 23), (112, 40)], 8)
    elif name in ("close-engagement", "nozzle"):
        arrow((17, 64), (52, 64), [(36, 46), (36, 82)])
        arrow((111, 64), (76, 64), [(92, 46), (92, 82)])
        if name == "nozzle":
            line([(44, 24), (54, 36), (74, 36), (84, 24)], 9)
    elif name in ("loader", "reload"):
        arc((17, 17, 111, 111), 25, 310)
        line([(78, 16), (104, 27), (101, 53)], 11)
        if name == "loader":
            line([(47, 83), (47, 51), (54, 42), (61, 51), (61, 83)], 8)
        else:
            line([(51, 83), (51, 51), (64, 34), (77, 51), (77, 83)], 8)
    elif name == "mount":
        line([(19, 75), (19, 106), (109, 106), (109, 75)])
        line([(64, 20), (64, 77)], 14)
        line([(37, 48), (91, 48)], 14)
    elif name == "pressure":
        arc((15, 25, 113, 123), 180, 360)
        line([(64, 75), (92, 42)], 12)
        arrow((32, 106), (101, 106), [(87, 93), (87, 117)])
    elif name == "rapid-fire":
        for y in (30, 64, 98):
            arrow((21, y), (104, y), [(84, y - 15), (84, y + 15)])
    else:
        raise ValueError(name)
    return image.resize((128, 128), Image.Resampling.LANCZOS)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--promote", action="store_true")
    args = parser.parse_args()
    STAGE.mkdir(parents=True, exist_ok=True)
    manifest = json.loads(Path(__file__).with_name("prompts.json").read_text(encoding="utf-8"))
    sources = []
    for name, filename in manifest["source_files"].items():
        source = Path(filename)
        picture = Image.open(source).convert("RGBA")
        assert picture.width == picture.height and picture.getchannel("A").getextrema() == (0, 255), name
        picture.resize((256, 256), Image.Resampling.LANCZOS).save(STAGE / f"{name}.png")
        sources.append({"name": name, "source_sha256": hashlib.sha256(source.read_bytes()).hexdigest(), "source_size": picture.size})
    for name in ["loader", "reload", "range", "tracking", "close-engagement", "nozzle", "mount", "pressure", "rapid-fire"]:
        glyph(name).save(STAGE / f"modifier-{name}.png")
    for tier in range(1, 4):
        glyph(f"tier-{tier}").save(STAGE / f"tier-{tier}.png")
    (STAGE / "sources.json").write_text(json.dumps(sources, indent=2) + "\n", encoding="utf-8")
    if args.promote:
        SHIP.mkdir(parents=True, exist_ok=True)
        for path in STAGE.glob("*.png"):
            shutil.copy2(path, SHIP / path.name)
    print(f"Exported {len(list(STAGE.glob('*.png')))} transparent layers to {STAGE}")


if __name__ == "__main__":
    main()
