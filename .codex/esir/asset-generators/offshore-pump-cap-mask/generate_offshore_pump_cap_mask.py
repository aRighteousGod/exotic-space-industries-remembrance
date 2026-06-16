from pathlib import Path

from PIL import Image, ImageDraw


REPO_ROOT = Path(__file__).resolve().parents[4]
VANILLA_ROOT = Path(
    r"C:\Program Files (x86)\Steam\steamapps\common\Factorio\data\base\graphics\entity\offshore-pump"
)
TARGET_ROOT = REPO_ROOT / "exotic-space-industries-remembrance-graphics-4" / "graphics" / "entities" / "offshore-pump"
PREVIEW_ROOT = REPO_ROOT / "output" / "offshore-pump-cap-mask"


DIRECTIONS = {
    "North": {
        "size": (90, 162),
        # The matching cap is occluded from the north; keep this empty instead of tinting the front cylinder.
        "regions": (),
    },
    "East": {
        "size": (124, 102),
        "region": (78, 42, 114, 66),
    },
    "South": {
        "size": (92, 192),
        "region": (8, 132, 82, 166),
    },
    "West": {
        "size": (124, 102),
        "region": (1, 18, 32, 58),
    },
}


EDGE_ALPHA_MULTIPLIERS = (0.5, 0.74, 0.9)


def clamp(value, minimum, maximum):
    return max(minimum, min(maximum, value))


def is_cap_pixel(r, g, b, a, mode):
    if a <= 55:
        return False

    if mode == "pale":
        return r > 120 and g > 90 and b < 150 and r >= g * 0.85 and g >= b * 1.05

    warm = r > 115 and g > 65 and b < 120
    yellow = r >= g * 0.92 and g > b * 1.18
    not_copper = not (r > 150 and 75 < g < 115 and b > 70)
    return warm and yellow and not_copper


def source_luminance(r, g, b):
    return (0.2126 * r + 0.7152 * g + 0.0722 * b) / 255


def mask_alpha(r, g, b, a, edge_multiplier):
    luminance = source_luminance(r, g, b)
    brightness = max(r, g, b) / 255
    saturation = (max(r, g, b) - min(r, g, b)) / 255
    alpha = int((132 + luminance * 76 + brightness * 34 + saturation * 24) * (a / 255) * edge_multiplier)
    return clamp(alpha, 60, 205)


def mask_gray(r, g, b):
    luminance = source_luminance(r, g, b)
    brightness = max(r, g, b) / 255
    saturation = (max(r, g, b) - min(r, g, b)) / 255
    gray = int(185 + luminance * 42 + brightness * 22 + saturation * 10)
    return clamp(gray, 185, 255)


def frame_zero(direction, width, height):
    sheet = Image.open(VANILLA_ROOT / f"offshore-pump_{direction}.png").convert("RGBA")
    return sheet.crop((0, 0, width, height))


def neighbors8(x, y):
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            if dx or dy:
                yield x + dx, y + dy


def cleanup_selection(selected):
    cleaned = set()
    for pixel in selected:
        neighbor_count = sum(1 for neighbor in neighbors8(*pixel) if neighbor in selected)
        if neighbor_count >= 2:
            cleaned.add(pixel)
    return cleaned


def erode_selection(selected):
    return {
        pixel
        for pixel in selected
        if all(neighbor in selected for neighbor in neighbors8(*pixel))
    }


def edge_multipliers(selected):
    remaining = set(selected)
    multipliers = {}

    for multiplier in EDGE_ALPHA_MULTIPLIERS:
        eroded = erode_selection(remaining)
        edge = remaining - eroded
        for pixel in edge:
            multipliers[pixel] = multiplier
        remaining = eroded

    for pixel in remaining:
        multipliers[pixel] = 1.0

    return multipliers


def make_mask(direction, spec):
    width, height = spec["size"]
    regions = spec["regions"] if "regions" in spec else (spec["region"],)
    mode = spec.get("mode", "yellow")
    source = frame_zero(direction, width, height)
    mask = Image.new("RGBA", (width, height), (255, 255, 255, 0))
    selected = set()

    for x1, y1, x2, y2 in regions:
        for y in range(y1, y2):
            for x in range(x1, x2):
                r, g, b, a = source.getpixel((x, y))
                if is_cap_pixel(r, g, b, a, mode):
                    selected.add((x, y))

    for (x, y), edge_multiplier in edge_multipliers(cleanup_selection(selected)).items():
        r, g, b, a = source.getpixel((x, y))
        gray = mask_gray(r, g, b)
        mask.putpixel((x, y), (gray, gray, gray, mask_alpha(r, g, b, a, edge_multiplier)))

    return source, mask


def tinted(mask, tint):
    out = Image.new("RGBA", mask.size, (0, 0, 0, 0))
    src = mask.load()
    dst = out.load()
    tr, tg, tb, ta = tint
    for y in range(mask.height):
        for x in range(mask.width):
            r, g, b, a = src[x, y]
            if a:
                dst[x, y] = (int(r * tr / 255), int(g * tg / 255), int(b * tb / 255), int(a * ta))
    return out


def flat_tinted(mask, tint):
    out = Image.new("RGBA", mask.size, (0, 0, 0, 0))
    src = mask.load()
    dst = out.load()
    tr, tg, tb, ta = tint
    for y in range(mask.height):
        for x in range(mask.width):
            _, _, _, a = src[x, y]
            if a:
                dst[x, y] = (tr, tg, tb, int(a * ta))
    return out


def composite_preview(source, mask, tint, flat=False):
    preview = source.copy()
    overlay = flat_tinted(mask, tint) if flat else tinted(mask, tint)
    preview.alpha_composite(overlay)
    return preview


def save_preview(previews):
    margin = 8
    labels = 16
    cell_w = max(entry["source"].width for entry in previews.values())
    cell_h = max(entry["source"].height for entry in previews.values()) + labels
    rows = (
        ("burner", (255, 20, 10, 255), False),
        ("steam", (255, 255, 255, 230), False),
    )
    canvas = Image.new(
        "RGBA",
        (margin + len(previews) * (cell_w + margin), cell_h * len(rows) + margin * (len(rows) + 1)),
        (22, 22, 24, 255),
    )
    draw = ImageDraw.Draw(canvas)

    for col, (direction, source) in enumerate(previews.items()):
        x = margin + col * (cell_w + margin)
        for row, (name, tint, flat) in enumerate(rows):
            y = margin + row * (cell_h + margin)
            preview = composite_preview(source["source"], source["mask"], tint, flat)
            canvas.alpha_composite(preview, (x, y + labels))
            draw.text((x, y), f"{name} {direction}", fill=(235, 235, 235, 255))

    PREVIEW_ROOT.mkdir(parents=True, exist_ok=True)
    canvas.save(PREVIEW_ROOT / "offshore-pump-cap-mask-preview.png")


def main():
    TARGET_ROOT.mkdir(parents=True, exist_ok=True)
    previews = {}
    for direction, spec in DIRECTIONS.items():
        source, mask = make_mask(direction, spec)
        mask.save(TARGET_ROOT / f"offshore-pump-cap-mask-{direction}.png")
        previews[direction] = {"source": source, "mask": mask}

    save_preview(previews)


if __name__ == "__main__":
    main()
