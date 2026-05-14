from __future__ import annotations

import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageEnhance, ImageFilter


REPO = Path(__file__).resolve().parents[4]
MOD_ROOT = REPO / "exotic-space-industries-remembrance"
ENTITY_ROOT = MOD_ROOT / "graphics" / "entities" / "emerald-apocalypse-hover-tank"
ITEM_OUT = MOD_ROOT / "graphics" / "items" / "emerald-apocalypse-hover-tank.png"
TECH_OUT = MOD_ROOT / "graphics" / "techs" / "emerald-apocalypse-hover-tank.png"
PREVIEW_ROOT = REPO / "temp" / "emerald-apocalypse-hover-tank" / "icon-work"

FRAME_SIZE = 768
TECH_FRAME = 25
ITEM_FRAME = 33


def load_sheet(prefix: str, index: int) -> Image.Image:
    suffix = "" if index == 0 else f"_{index}"
    return Image.open(ENTITY_ROOT / f"{prefix}{suffix}.png").convert("RGBA")


def load_frame(frame_index: int) -> Image.Image:
    sheet_index = frame_index // 16
    local_index = frame_index % 16
    x = (local_index % 4) * FRAME_SIZE
    y = (local_index // 4) * FRAME_SIZE

    base = load_sheet("object_lit_v8_0", sheet_index).crop((x, y, x + FRAME_SIZE, y + FRAME_SIZE))
    glow = load_sheet("emerald_crystal_glow_0", sheet_index).crop((x, y, x + FRAME_SIZE, y + FRAME_SIZE))
    glow = ImageEnhance.Brightness(glow).enhance(1.35)
    glow.putalpha(glow.getchannel("A").point(lambda a: min(255, int(a * 0.70))))

    image = Image.alpha_composite(base, glow)
    image = ImageEnhance.Contrast(image).enhance(1.08)
    image = ImageEnhance.Color(image).enhance(1.08)
    bbox = image.getbbox()
    if bbox:
        image = image.crop(bbox)
    return image


def add_emerald_rim(subject: Image.Image, blur: float, alpha_scale: float) -> Image.Image:
    rim = Image.new("RGBA", subject.size, (0, 255, 145, 0))
    rim_alpha = subject.getchannel("A").filter(ImageFilter.GaussianBlur(blur))
    rim.putalpha(rim_alpha.point(lambda a: int(a * alpha_scale)))
    return Image.alpha_composite(rim, subject)


def draw_tech_background() -> Image.Image:
    icon = Image.new("RGBA", (256, 256), (0, 0, 0, 0))
    draw = ImageDraw.Draw(icon, "RGBA")

    for radius in range(122, 18, -1):
        t = (122 - radius) / 104
        draw.ellipse(
            (128 - radius, 128 - radius, 128 + radius, 128 + radius),
            fill=(2, int(18 + 26 * t), int(16 + 28 * t), int(170 * (1 - t) + 45 * t)),
        )

    for radius, alpha, width in ((118, 120, 2), (103, 70, 1), (86, 60, 1), (66, 45, 1)):
        draw.ellipse(
            (128 - radius, 128 - radius, 128 + radius, 128 + radius),
            outline=(0, 255, 155, alpha),
            width=width,
        )

    for index in range(24):
        angle = (math.tau * index / 24) + (math.pi / 24)
        inner = 76 if index % 2 else 88
        outer = 113
        draw.line(
            (
                128 + math.cos(angle) * inner,
                128 + math.sin(angle) * inner,
                128 + math.cos(angle) * outer,
                128 + math.sin(angle) * outer,
            ),
            fill=(0, 255, 160, 35 if index % 2 else 55),
            width=1,
        )

    draw.polygon([(44, 185), (205, 44), (224, 206)], fill=(0, 70, 52, 42), outline=(0, 255, 160, 48))
    return icon


def build_tech_icon() -> Image.Image:
    icon = draw_tech_background()
    subject = add_emerald_rim(load_frame(TECH_FRAME), 8, 0.34)
    subject.thumbnail((214, 214), Image.Resampling.LANCZOS)
    icon.alpha_composite(subject, ((256 - subject.width) // 2 + 2, (256 - subject.height) // 2 + 5))

    draw = ImageDraw.Draw(icon, "RGBA")
    draw.ellipse((184, 50, 206, 72), fill=(180, 255, 218, 42))
    draw.ellipse((190, 56, 200, 66), fill=(235, 255, 245, 72))
    return icon


def build_item_icon() -> Image.Image:
    icon = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    subject = add_emerald_rim(load_frame(ITEM_FRAME), 4, 0.30)
    subject.thumbnail((61, 61), Image.Resampling.LANCZOS)
    icon.alpha_composite(subject, ((64 - subject.width) // 2, (64 - subject.height) // 2 + 1))
    return icon.filter(ImageFilter.UnsharpMask(radius=0.7, percent=120, threshold=3))


def main() -> None:
    ITEM_OUT.parent.mkdir(parents=True, exist_ok=True)
    TECH_OUT.parent.mkdir(parents=True, exist_ok=True)
    PREVIEW_ROOT.mkdir(parents=True, exist_ok=True)

    tech = build_tech_icon()
    item = build_item_icon()
    tech.save(TECH_OUT)
    item.save(ITEM_OUT)
    tech.save(PREVIEW_ROOT / "emerald-apocalypse-hover-tank-tech-preview.png")
    item.save(PREVIEW_ROOT / "emerald-apocalypse-hover-tank-item-preview.png")
    print(f"Wrote {TECH_OUT.relative_to(REPO)}")
    print(f"Wrote {ITEM_OUT.relative_to(REPO)}")


if __name__ == "__main__":
    main()
