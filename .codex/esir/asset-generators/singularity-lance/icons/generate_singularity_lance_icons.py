from __future__ import annotations

import json
import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageEnhance, ImageFilter


ASSET_NAME = "ei-singularity-lance-icons"


def find_repo_root(start: Path) -> Path:
    for path in [start, *start.parents]:
        if (path / ".gitignore").exists() and (path / "exotic-space-industries-remembrance").exists():
            return path
    raise RuntimeError(f"Could not find repository root from {start}")


REPO_ROOT = find_repo_root(Path(__file__).resolve())
ROOT = REPO_ROOT / "output" / "meshy" / ASSET_NAME
EXPORT_DIR = ROOT / "factorio-export"
PREVIEW_DIR = ROOT / "previews"
ENTITY_DIR = REPO_ROOT / "exotic-space-industries-remembrance" / "graphics" / "entities" / "singularity-lance"
ITEM_DIR = REPO_ROOT / "exotic-space-industries-remembrance" / "graphics" / "items"
TECH_DIR = REPO_ROOT / "exotic-space-industries-remembrance" / "graphics" / "techs"

ITEM_ICON = "ei-singularity-lance.png"
ITEM_OVERLAY_ICON = "ei-singularity-lance-chromatic-overlay.png"
TECH_ICON = "ei-singularity-lance.png"
TECH_OVERLAY_ICON = "ei-singularity-lance-chromatic-overlay.png"
ITEM_SOURCE_SIZE = 128
TECH_SIZE = 256
FRAME_SIZE = 768


def clamp(value: float, low: float = 0.0, high: float = 255.0) -> int:
    return int(max(low, min(high, value)))


def mix(a: tuple[int, int, int], b: tuple[int, int, int], t: float) -> tuple[int, int, int]:
    t = max(0.0, min(1.0, t))
    return (
        clamp(a[0] + (b[0] - a[0]) * t),
        clamp(a[1] + (b[1] - a[1]) * t),
        clamp(a[2] + (b[2] - a[2]) * t),
    )


def spectral_color(offset: float, phase: float = 0.0) -> tuple[int, int, int]:
    band = 0.5 + 0.5 * math.sin(offset * 5.4 + phase)
    if offset < -0.16:
        return mix((0, 225, 255), (75, 82, 255), band)
    if offset > 0.16:
        return mix((255, 38, 198), (160, 72, 255), band)
    hot = mix((255, 110, 16), (255, 232, 58), 0.55 + 0.35 * band)
    return mix(hot, (255, 255, 244), max(0.0, 1.0 - abs(offset) * 7.0) * 0.72)


def first_frame(filename: str) -> Image.Image:
    sheet = Image.open(ENTITY_DIR / filename).convert("RGBA")
    return sheet.crop((0, 0, FRAME_SIZE, FRAME_SIZE))


def alpha_bbox(img: Image.Image, threshold: int = 8) -> tuple[int, int, int, int] | None:
    alpha = img.getchannel("A")
    mask = alpha.point(lambda value: 255 if value > threshold else 0)
    return mask.getbbox()


def fit_subject(img: Image.Image, size: int, fill: float, y_bias: int = 0) -> Image.Image:
    bbox = alpha_bbox(img)
    if not bbox:
        return Image.new("RGBA", (size, size), (0, 0, 0, 0))

    subject = img.crop(bbox)
    target = int(size * fill)
    scale = min(target / subject.width, target / subject.height)
    resized = subject.resize((max(1, int(subject.width * scale)), max(1, int(subject.height * scale))), Image.Resampling.LANCZOS)
    out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    x = (size - resized.width) // 2
    y = (size - resized.height) // 2 + y_bias
    out.alpha_composite(resized, (x, y))
    return out


def crop_subject(img: Image.Image) -> Image.Image:
    bbox = alpha_bbox(img)
    if not bbox:
        return Image.new("RGBA", (1, 1), (0, 0, 0, 0))
    return img.crop(bbox)


def fit_to_width(img: Image.Image, width: int) -> Image.Image:
    width = max(1, width)
    scale = width / max(1, img.width)
    return img.resize((width, max(1, int(img.height * scale))), Image.Resampling.LANCZOS)


def outline_subject(img: Image.Image, radius: int, color: tuple[int, int, int, int]) -> Image.Image:
    alpha = img.getchannel("A")
    expanded = alpha.filter(ImageFilter.MaxFilter(radius * 2 + 1))
    outline_alpha = Image.eval(expanded, lambda value: clamp(value * color[3] / 255.0))
    outline = Image.new("RGBA", img.size, color)
    outline.putalpha(outline_alpha)
    outline.alpha_composite(img)
    return outline


def make_entity_composite() -> Image.Image:
    body = first_frame("ei-singularity-lance.png")
    crystal = first_frame("ei-singularity-lance_crystal.png")

    composite = Image.new("RGBA", (FRAME_SIZE, FRAME_SIZE), (0, 0, 0, 0))
    for layer in (body, crystal):
        composite.alpha_composite(layer)
    alpha = composite.getchannel("A")
    boosted = ImageEnhance.Brightness(composite).enhance(1.46)
    boosted = ImageEnhance.Contrast(boosted).enhance(1.24)
    boosted = ImageEnhance.Color(boosted).enhance(1.24)
    boosted.putalpha(alpha)
    return boosted


def boost_layer(layer: Image.Image) -> Image.Image:
    alpha = layer.getchannel("A")
    boosted = ImageEnhance.Brightness(layer).enhance(1.46)
    boosted = ImageEnhance.Contrast(boosted).enhance(1.24)
    boosted = ImageEnhance.Color(boosted).enhance(1.24)
    boosted.putalpha(alpha)
    return boosted


def make_identity_layout(size: int, tech: bool = False) -> Image.Image:
    body = boost_layer(crop_subject(first_frame("ei-singularity-lance.png")))
    crystal = boost_layer(crop_subject(first_frame("ei-singularity-lance_crystal.png")))

    body_width = int(size * (0.68 if tech else 0.66))
    crystal_width = int(size * (0.27 if tech else 0.25))
    body = fit_to_width(body, body_width)
    crystal = fit_to_width(crystal, crystal_width)

    icon = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    body_x = (size - body.width) // 2
    body_y = int(size * 0.28)
    crystal_x = (size - crystal.width) // 2
    crystal_y = int(size * (0.08 if tech else 0.05))
    icon.alpha_composite(body, (body_x, body_y))
    icon.alpha_composite(crystal, (crystal_x, crystal_y))
    return icon


def draw_chromatic_corner(icon: Image.Image, tech: bool = False, glow: bool = False) -> None:
    size = icon.size[0]
    draw = ImageDraw.Draw(icon, "RGBA")
    corner = size * (0.23 if not tech else 0.25)
    pad = size * (0.052 if not tech else 0.050)
    if not glow:
        tri = [(size - corner, size - pad), (size - pad, size - pad), (size - pad, size - corner)]
        draw.polygon(tri, fill=(5, 6, 10, 154), outline=(255, 224, 64, 210))

    band_count = 5 if not tech else 6
    for band in range(band_count):
        t = band / max(1, band_count - 1)
        color = spectral_color((t - 0.5) * 0.9, 0.9)
        width = max(1, int(size * (0.017 if not tech else 0.013)))
        x1 = size - corner + t * corner * 0.72
        y1 = size - pad
        x2 = size - pad
        y2 = size - corner + t * corner * 0.72
        if glow:
            draw.line((x1, y1, x2, y2), fill=(*color, 108), width=width + max(2, int(size * 0.018)))
        else:
            draw.line((x1, y1, x2, y2), fill=(1, 2, 5, 218), width=width + 2)
            draw.line((x1, y1, x2, y2), fill=(*color, 255), width=width)


def add_lift_glow(icon: Image.Image, strength: float = 1.0) -> Image.Image:
    alpha = icon.getchannel("A")
    glow_alpha = alpha.filter(ImageFilter.MaxFilter(5)).filter(ImageFilter.GaussianBlur(1.6))
    glow_alpha = glow_alpha.point(lambda value: clamp(value * 0.16 * strength))
    glow = Image.new("RGBA", icon.size, (0, 208, 255, 0))
    glow.putalpha(glow_alpha)
    out = Image.new("RGBA", icon.size, (0, 0, 0, 0))
    out.alpha_composite(glow)
    out.alpha_composite(icon)
    return out


def add_readability_rim(img: Image.Image, strength: int) -> Image.Image:
    alpha = img.getchannel("A")
    rim_alpha = alpha.filter(ImageFilter.MaxFilter(5)).filter(ImageFilter.GaussianBlur(0.9))
    rim_alpha = rim_alpha.point(lambda value: clamp(value * strength / 255.0))
    rim = Image.new("RGBA", img.size, (44, 224, 246, 0))
    rim.putalpha(rim_alpha)
    out = Image.new("RGBA", img.size, (0, 0, 0, 0))
    out.alpha_composite(rim)
    out.alpha_composite(img)
    return out


def build_base_icon(size: int, tech: bool = False) -> Image.Image:
    fitted = make_identity_layout(size, tech)
    fitted = add_lift_glow(fitted, 0.82 if tech else 0.66)
    fitted = outline_subject(fitted, 1, (3, 7, 9, 205))

    icon = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    icon.alpha_composite(fitted)
    return icon


def build_overlay_icon(size: int, tech: bool = False) -> Image.Image:
    glow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw_chromatic_corner(glow, tech, True)
    glow = glow.filter(ImageFilter.GaussianBlur(1.8 if tech else 1.2))

    overlay = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    overlay.alpha_composite(glow)
    draw_chromatic_corner(overlay, tech)
    return overlay


def composite_layers(base: Image.Image, overlay: Image.Image) -> Image.Image:
    out = base.copy()
    out.alpha_composite(overlay)
    return out


def build_icon(size: int, tech: bool = False) -> Image.Image:
    return composite_layers(build_base_icon(size, tech), build_overlay_icon(size, tech))


def make_mip_strip(source_128: Image.Image) -> Image.Image:
    strip = Image.new("RGBA", (224, 128), (0, 0, 0, 0))
    strip.alpha_composite(source_128, (0, 0))
    strip.alpha_composite(source_128.resize((64, 64), Image.Resampling.LANCZOS), (128, 0))
    strip.alpha_composite(source_128.resize((32, 32), Image.Resampling.LANCZOS), (192, 0))
    return strip


def luminance(pixel: tuple[int, int, int, int]) -> float:
    r, g, b, a = pixel
    if a <= 0:
        return 0.0
    return (0.2126 * r + 0.7152 * g + 0.0722 * b) * (a / 255.0)


def readability_score(icon: Image.Image, sample_size: int) -> dict[str, float]:
    resized = icon.resize((sample_size, sample_size), Image.Resampling.LANCZOS)
    alpha = resized.getchannel("A")
    bbox = alpha_bbox(resized, 12)
    fill_ratio = sum(1 for value in alpha.getdata() if value > 12) / float(sample_size * sample_size)
    if not bbox:
        return {"fill_ratio": 0, "dark_contrast": 0, "mid_contrast": 0}
    pixels = list(resized.getdata())
    subject = [luminance(pixel) for pixel in pixels if pixel[3] > 24]
    avg_lum = sum(subject) / max(1, len(subject))
    return {
        "fill_ratio": round(fill_ratio, 4),
        "dark_contrast": round(abs(avg_lum - 18.0), 2),
        "mid_contrast": round(abs(avg_lum - 96.0), 2),
    }


def make_preview(item_base: Image.Image, item_overlay: Image.Image, tech_base: Image.Image, tech_overlay: Image.Image) -> None:
    item_icon = composite_layers(item_base, item_overlay)
    tech_icon = composite_layers(tech_base, tech_overlay)
    preview = Image.new("RGBA", (880, 456), (19, 22, 24, 255))
    draw = ImageDraw.Draw(preview, "RGBA")
    swatches = [(8, 12, 16, 255), (76, 53, 32, 255), (84, 88, 90, 255), (34, 43, 48, 255)]
    for i, color in enumerate(swatches):
        x = 24 + i * 204
        draw.rounded_rectangle((x, 24, x + 180, 184), radius=8, fill=color, outline=(120, 130, 136, 84))
        preview.alpha_composite(item_icon, (x + 26, 40))
        preview.alpha_composite(item_icon.resize((64, 64), Image.Resampling.LANCZOS), (x + 54, 108))
        preview.alpha_composite(item_icon.resize((32, 32), Image.Resampling.LANCZOS), (x + 118, 132))

    for i, color in enumerate(swatches[:3]):
        x = 72 + i * 270
        y = 210
        draw.rounded_rectangle((x, y, x + 200, y + 126), radius=8, fill=color, outline=(120, 130, 136, 84))
        preview.alpha_composite(tech_icon.resize((118, 118), Image.Resampling.LANCZOS), (x + 41, y + 4))

    for i, color in enumerate(swatches):
        x = 24 + i * 204
        y = 360
        draw.rounded_rectangle((x, y, x + 180, y + 72), radius=8, fill=color, outline=(120, 130, 136, 84))
        preview.alpha_composite(item_base.resize((64, 64), Image.Resampling.LANCZOS), (x + 32, y + 4))
        preview.alpha_composite(item_base.resize((32, 32), Image.Resampling.LANCZOS), (x + 108, y + 22))

    preview.convert("RGB").save(PREVIEW_DIR / f"{ASSET_NAME}-readability-preview.png")


def write_report(
    item_base: Image.Image,
    item_overlay: Image.Image,
    item_strip: Image.Image,
    item_overlay_strip: Image.Image,
    tech_base: Image.Image,
    tech_overlay: Image.Image,
) -> None:
    item_icon = composite_layers(item_base, item_overlay)
    tech_icon = composite_layers(tech_base, tech_overlay)
    report = {
        "asset_name": ASSET_NAME,
        "outputs": [
            {
                "path": "graphics/items/ei-singularity-lance.png",
                "size": list(item_strip.size),
                "icon_size": 128,
                "icon_mipmaps": 3,
                "mode": item_strip.mode,
            },
            {
                "path": "graphics/items/ei-singularity-lance-chromatic-overlay.png",
                "size": list(item_overlay_strip.size),
                "icon_size": 128,
                "icon_mipmaps": 3,
                "mode": item_overlay_strip.mode,
                "role": "transparent UI icon overlay",
            },
            {
                "path": "graphics/techs/ei-singularity-lance.png",
                "size": list(tech_base.size),
                "icon_size": 256,
                "mode": tech_base.mode,
            },
            {
                "path": "graphics/techs/ei-singularity-lance-chromatic-overlay.png",
                "size": list(tech_overlay.size),
                "icon_size": 256,
                "mode": tech_overlay.mode,
                "role": "transparent UI technology overlay",
            },
        ],
        "readability": {
            "item_base_128": readability_score(item_base, 128),
            "item_ui_128": readability_score(item_icon, 128),
            "item_ui_64": readability_score(item_icon, 64),
            "item_ui_32": readability_score(item_icon, 32),
            "tech_ui_128_preview": readability_score(tech_icon, 128),
        },
    }
    (ROOT / "source" / "generation-report.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
    (EXPORT_DIR / f"{ASSET_NAME}.factorio-asset-manifest.json").write_text(json.dumps(report, indent=2), encoding="utf-8")


def main() -> None:
    EXPORT_DIR.mkdir(parents=True, exist_ok=True)
    PREVIEW_DIR.mkdir(parents=True, exist_ok=True)
    (ROOT / "source").mkdir(parents=True, exist_ok=True)
    ITEM_DIR.mkdir(parents=True, exist_ok=True)
    TECH_DIR.mkdir(parents=True, exist_ok=True)

    item_base = build_base_icon(ITEM_SOURCE_SIZE, tech=False)
    item_overlay = build_overlay_icon(ITEM_SOURCE_SIZE, tech=False)
    item_strip = make_mip_strip(item_base)
    item_overlay_strip = make_mip_strip(item_overlay)
    tech_base = build_base_icon(TECH_SIZE, tech=True)
    tech_overlay = build_overlay_icon(TECH_SIZE, tech=True)

    item_base.save(EXPORT_DIR / "ei-singularity-lance-source-128.png")
    item_overlay.save(EXPORT_DIR / "ei-singularity-lance-chromatic-overlay-source-128.png")
    composite_layers(item_base, item_overlay).save(EXPORT_DIR / "ei-singularity-lance-ui-composite-128.png")
    item_strip.save(EXPORT_DIR / ITEM_ICON)
    item_overlay_strip.save(EXPORT_DIR / ITEM_OVERLAY_ICON)
    tech_base.save(EXPORT_DIR / "ei-singularity-lance-tech.png")
    tech_overlay.save(EXPORT_DIR / "ei-singularity-lance-tech-chromatic-overlay.png")
    item_strip.save(ITEM_DIR / ITEM_ICON)
    item_overlay_strip.save(ITEM_DIR / ITEM_OVERLAY_ICON)
    tech_base.save(TECH_DIR / TECH_ICON)
    tech_overlay.save(TECH_DIR / TECH_OVERLAY_ICON)
    make_preview(item_base, item_overlay, tech_base, tech_overlay)
    write_report(item_base, item_overlay, item_strip, item_overlay_strip, tech_base, tech_overlay)


if __name__ == "__main__":
    main()
