"""Review the 41 final technology compositions from a real Factorio data dump."""
from __future__ import annotations

import argparse
import base64
import html
import importlib.util
import json
import sys
import textwrap
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont, ImageOps

ROOT = Path(__file__).resolve().parents[3]
OUTPUT = ROOT / "output/meshy/spider-technology-icons/review"
RENDERER = ROOT / ".codex/skills/esir-recipe-icon-style/scripts/render_recipe_icon_report.py"
spec = importlib.util.spec_from_file_location("esir_icon_resolver", RENDERER)
resolver_module = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = resolver_module
spec.loader.exec_module(resolver_module)


def locale(path):
    values = {}
    section = ""
    for line in path.read_text(encoding="utf-8-sig").splitlines():
        if line.startswith("["):
            section = line[1:-1]
        elif "=" in line and not line.startswith(";"):
            key, value = line.split("=", 1)
            full = f"{section}.{key}"
            assert full not in values, full
            assert "\ufffd" not in value and "doeworks" not in value.lower(), full
            values[full] = value
    return values


def localise(value, strings):
    if not isinstance(value, list):
        return str(value)
    result = strings[value[0]]
    for index, parameter in enumerate(value[1:], 1):
        result = result.replace(f"__{index}__", localise(parameter, strings))
    return result


def render(layers, resolver):
    canvas = Image.new("RGBA", (256, 256))
    for layer in layers:
        source = resolver.resolve(layer["icon"], layer.get("icon_size", 64))
        assert source.image is not None, (layer["icon"], source.note)
        picture = source.image.convert("RGBA")
        size = layer.get("icon_size", 64)
        picture = picture.crop((0, 0, size, size))
        if layer.get("tint"):
            picture = resolver_module.apply_tint(picture, layer["tint"])
        pixels = round(size * layer.get("scale", 128 / size) * 2)
        picture = picture.resize((pixels, pixels), Image.Resampling.LANCZOS)
        shift = layer.get("shift", [0, 0])
        if isinstance(shift, dict):
            shift = [shift.get("x", 0), shift.get("y", 0)]
        canvas.alpha_composite(picture, (round((256-pixels)/2+shift[0]*2), round((256-pixels)/2+shift[1]*2)))
    return canvas


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dump", type=Path, required=True)
    parser.add_argument("--baseline", type=Path)
    args = parser.parse_args()
    data = json.loads(args.dump.read_text(encoding="utf-8-sig"))
    names = sorted(name for name in data["technology"] if name.startswith("ei-spider-") or name in ("ei-assault-spidertron", "ei-assault-smokescreen"))
    assert len(names) == 41, len(names)
    locales = {p.parent.name: locale(p) for p in (ROOT / "exotic-space-industries-remembrance/locale").glob("*/spider-vehicles.cfg")}
    assert len(locales) == 7 and all(set(x) == set(locales["en"]) for x in locales.values())
    signatures = set()
    resolver = resolver_module.AssetResolver(ROOT)
    OUTPUT.mkdir(parents=True, exist_ok=True)
    font = ImageFont.truetype("C:/Windows/Fonts/arial.ttf", 15)
    sheet = Image.new("RGB", (7*280, 6*178), (42, 45, 49))
    draw = ImageDraw.Draw(sheet)
    cards = []
    for index, name in enumerate(names):
        tech = data["technology"][name]
        layers = tech["icons"]
        signature = json.dumps(layers, sort_keys=True)
        assert signature not in signatures, name
        signatures.add(signature)
        for strings in locales.values():
            localise(tech["localised_name"], strings)
        title = localise(tech["localised_name"], locales["en"])
        picture = render(layers, resolver)
        picture.save(OUTPUT / f"{name}.png")
        x, y = index % 7 * 280, index // 7 * 178
        for size, offset in [(64, 8), (32, 86)]:
            small = picture.resize((size, size), Image.Resampling.LANCZOS)
            sheet.paste(small, (x+offset, y+8), small)
        gray = ImageOps.grayscale(picture).convert("RGBA")
        gray.putalpha(picture.getchannel("A"))
        gray = gray.resize((32, 32), Image.Resampling.LANCZOS)
        sheet.paste(gray, (x+132, y+8), gray)
        # Deliberate worst-case badge preview even when this technology is full cost.
        badge = resolver.resolve("__exotic-space-industries-remembrance-graphics-3__/graphics/icons/weight-marker-3.png", 256).image.convert("RGBA")
        badged = Image.alpha_composite(picture, badge.resize((256, 256)))
        small = badged.resize((64, 64), Image.Resampling.LANCZOS)
        sheet.paste(small, (x+192, y+8), small)
        for row, line in enumerate(textwrap.wrap(title, 31)):
            draw.text((x+8, y+82+row*18), line, fill="white", font=font)
        uri = "data:image/png;base64," + base64.b64encode((OUTPUT / f"{name}.png").read_bytes()).decode()
        cards.append(f'<article><h2>{html.escape(title)}</h2><div class="icons">' + ''.join(f'<img src="{uri}" width="{size}" height="{size}" alt="{html.escape(title)}">' for size in [256,64,32]) + f'</div><small>{html.escape(name)}</small></article>')
    sheet.save(OUTPUT / "contact-sheet.png")
    document = '<!doctype html><meta charset="utf-8"><title>Spider technology icon review</title><style>body{background:#292d31;color:#eee;font:15px system-ui;margin:30px}main{display:grid;grid-template-columns:repeat(auto-fit,minmax(430px,1fr));gap:20px}article{background:#373c41;padding:18px}h2{font-size:17px;min-height:44px}.icons{display:flex;align-items:center;gap:18px;height:270px}small{color:#aaa}</style><h1>Spider technology icons</h1><p>All 41 final data-stage icons. Each card shows 256 / 64 / 32 pixels; technical identities are unchanged.</p><main>' + ''.join(cards) + '</main>'
    (OUTPUT / "index.html").write_text(document, encoding="utf-8")
    report = {"technology_count": len(names), "distinct_icons": len(signatures), "locales": sorted(locales), "locale_keys": len(locales["en"]), "gameplay_comparison": None}
    if args.baseline:
        baseline = json.loads(args.baseline.read_text(encoding="utf-8-sig"))
        visual = {"icon", "icons", "icon_size", "icon_mipmaps", "localised_name"}
        differences = []
        for name in names:
            current = {k: v for k, v in data["technology"][name].items() if k not in visual}
            previous = {k: v for k, v in baseline["technology"][name].items() if k not in visual}
            if current != previous:
                differences.append({"name": name, "fields": [k for k in current.keys() | previous.keys() if current.get(k) != previous.get(k)]})
        report["gameplay_comparison"] = differences
        assert not differences, differences
    (OUTPUT / "report.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report))
    print(OUTPUT / "index.html")


if __name__ == "__main__":
    main()
