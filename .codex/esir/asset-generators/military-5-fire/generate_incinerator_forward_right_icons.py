import argparse
import json
from pathlib import Path

from PIL import Image


FRAME_SIZE = 128
TECH_MIPS = (256, 128, 64, 32)
ITEM_MIPS = (128, 64, 32)


def ensure_dir(path):
    Path(path).mkdir(parents=True, exist_ok=True)


def crop_frame(sheet, direction_row, frame_column):
    box = (
        frame_column * FRAME_SIZE,
        direction_row * FRAME_SIZE,
        (frame_column + 1) * FRAME_SIZE,
        (direction_row + 1) * FRAME_SIZE,
    )
    return sheet.crop(box)


def trim(image):
    bbox = image.getbbox()
    if not bbox:
        return image
    return image.crop(bbox)


def fit(image, max_size):
    image = trim(image).copy()
    image.thumbnail(max_size, Image.Resampling.LANCZOS)
    return image


def build_item_strip(frame, output, fit_size):
    icon = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    subject = fit(frame, (fit_size, fit_size))
    icon.alpha_composite(subject, ((128 - subject.width) // 2, (128 - subject.height) // 2))

    strip = Image.new("RGBA", (224, 128), (0, 0, 0, 0))
    x = 0
    for size in ITEM_MIPS:
        mip = icon if size == 128 else icon.resize((size, size), Image.Resampling.LANCZOS)
        strip.alpha_composite(mip, (x, 0))
        x += size

    ensure_dir(output.parent)
    strip.save(output)


def build_tech_strip(bot_frame, glow_frame, shadow_frame, output):
    base = Image.new("RGBA", (256, 256), (0, 0, 0, 0))

    shadow = fit(shadow_frame, (174, 82))
    base.alpha_composite(shadow, ((256 - shadow.width) // 2 + 10, 150))

    bot = Image.new("RGBA", (FRAME_SIZE, FRAME_SIZE), (0, 0, 0, 0))
    bot.alpha_composite(bot_frame)
    bot.alpha_composite(glow_frame)
    bot = fit(bot, (186, 150))
    base.alpha_composite(bot, ((256 - bot.width) // 2, 14))

    strip = Image.new("RGBA", (sum(TECH_MIPS), 256), (0, 0, 0, 0))
    x = 0
    for size in TECH_MIPS:
        mip = base if size == 256 else base.resize((size, size), Image.Resampling.LANCZOS)
        strip.alpha_composite(mip, (x, 0))
        x += size

    ensure_dir(output.parent)
    strip.save(output)


def flip_mip_strip(source, output):
    image = Image.open(source).convert("RGBA")
    strip = Image.new("RGBA", image.size, (0, 0, 0, 0))
    x = 0
    for size in ITEM_MIPS:
        mip = image.crop((x, 0, x + size, size)).transpose(Image.Transpose.FLIP_LEFT_RIGHT)
        strip.alpha_composite(mip, (x, 0))
        x += size
    ensure_dir(output.parent)
    strip.save(output)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo-root", default=".")
    parser.add_argument("--direction-row", type=int, default=12)
    parser.add_argument("--frame-column", type=int, default=0)
    parser.add_argument("--item-fit-size", type=int, default=112)
    parser.add_argument("--preview", default="output/meshy/military-5-fire/forward-right-icons-preview.png")
    parser.add_argument("--flip-capsule", action="store_true")
    args = parser.parse_args()

    repo_root = Path(args.repo_root).resolve()
    graphics_root = repo_root / "exotic-space-industries-remembrance-graphics-4" / "graphics"
    entity_root = graphics_root / "entities" / "incinerator"
    item_root = graphics_root / "items"
    tech_root = graphics_root / "techs"

    base_sheet = Image.open(entity_root / "incinerator-bot.png").convert("RGBA")
    glow_sheet = Image.open(entity_root / "incinerator-bot-glow.png").convert("RGBA")
    shadow_sheet = Image.open(entity_root / "incinerator-bot-shadow.png").convert("RGBA")

    bot_frame = crop_frame(base_sheet, args.direction_row, args.frame_column)
    glow_frame = crop_frame(glow_sheet, args.direction_row, args.frame_column)
    shadow_frame = crop_frame(shadow_sheet, args.direction_row, args.frame_column)

    bot_item_output = item_root / "incinerator.png"
    tech_output = tech_root / "incinerator.png"
    build_item_strip(bot_frame, bot_item_output, args.item_fit_size)
    build_tech_strip(bot_frame, glow_frame, shadow_frame, tech_output)

    capsule_output = item_root / "incinerator-capsule.png"
    flipped_capsule = False
    if args.flip_capsule:
        source_root = repo_root / ".codex" / "esir" / "asset-generators" / "military-5-fire" / "source"
        capsule_source = source_root / "incinerator-capsule-forward-left.png"
        if not capsule_source.exists():
            ensure_dir(capsule_source.parent)
            Image.open(capsule_output).convert("RGBA").save(capsule_source)
        flip_mip_strip(capsule_source, capsule_output)
        flipped_capsule = True

    preview = Path(args.preview)
    ensure_dir(preview.parent)
    preview_image = Image.new("RGBA", (704, 288), (18, 18, 18, 255))
    preview_image.alpha_composite(Image.open(bot_item_output).convert("RGBA"), (16, 16))
    preview_image.alpha_composite(Image.open(capsule_output).convert("RGBA"), (264, 16))
    preview_image.alpha_composite(Image.open(tech_output).convert("RGBA"), (16, 160))
    preview_image.save(preview)

    manifest = {
        "direction_row": args.direction_row,
        "frame_column": args.frame_column,
        "orientation": "north-first clockwise row 12, southeast/front-right",
        "outputs": {
            "bot_item_icon": str(bot_item_output),
            "capsule_item_icon": str(capsule_output),
            "capsule_source_icon": str(capsule_source) if flipped_capsule else None,
            "tech_icon": str(tech_output),
            "preview": str(preview),
        },
        "capsule_flipped_per_mip": flipped_capsule,
    }
    manifest_path = preview.with_suffix(".manifest.json")
    manifest_path.write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    print(json.dumps(manifest, indent=2))


if __name__ == "__main__":
    main()
