import argparse
import json
import shutil
from pathlib import Path

from PIL import Image, ImageEnhance, ImageFilter


BRIGHTNESS = 1.55
CONTRAST = 1.12
SATURATION = 1.08


def ensure_dir(path):
    Path(path).mkdir(parents=True, exist_ok=True)


def sorted_pngs(path):
    return sorted(Path(path).glob("*.png"))


def enhance_rgba(image):
    image = image.convert("RGBA")
    red, green, blue, alpha = image.split()
    rgb = Image.merge("RGB", (red, green, blue))
    rgb = ImageEnhance.Brightness(rgb).enhance(BRIGHTNESS)
    rgb = ImageEnhance.Contrast(rgb).enhance(CONTRAST)
    rgb = ImageEnhance.Color(rgb).enhance(SATURATION)
    return Image.merge("RGBA", (*rgb.split(), alpha))


def pack_frames(frame_dir, output, columns, frame_size):
    frames = sorted_pngs(frame_dir)
    if not frames:
        raise RuntimeError(f"No PNG frames found in {frame_dir}")
    rows = (len(frames) + columns - 1) // columns
    sheet = Image.new("RGBA", (columns * frame_size, rows * frame_size), (0, 0, 0, 0))
    for index, frame_path in enumerate(frames):
        frame = Image.open(frame_path).convert("RGBA")
        if frame.size != (frame_size, frame_size):
            frame = frame.resize((frame_size, frame_size), Image.Resampling.LANCZOS)
        x = (index % columns) * frame_size
        y = (index // columns) * frame_size
        sheet.alpha_composite(frame, (x, y))
    sheet = enhance_rgba(sheet)
    ensure_dir(Path(output).parent)
    sheet.save(output)
    return {"frames": len(frames), "columns": columns, "rows": rows, "size": sheet.size}


def make_shadow_sheet(source, output, frame_size, columns, offset, blur, alpha):
    source_img = Image.open(source).convert("RGBA")
    rows = source_img.height // frame_size
    sheet = Image.new("RGBA", source_img.size, (0, 0, 0, 0))
    for row in range(rows):
        for col in range(columns):
            box = (
                col * frame_size,
                row * frame_size,
                (col + 1) * frame_size,
                (row + 1) * frame_size,
            )
            frame = source_img.crop(box)
            frame_alpha = frame.getchannel("A").filter(ImageFilter.GaussianBlur(blur))
            shadow = Image.new("RGBA", (frame_size, frame_size), (0, 0, 0, 0))
            shadow.putalpha(frame_alpha.point(lambda value: int(value * alpha)))
            target = Image.new("RGBA", (frame_size, frame_size), (0, 0, 0, 0))
            target.alpha_composite(shadow, offset)
            sheet.alpha_composite(target, (col * frame_size, row * frame_size))
    ensure_dir(Path(output).parent)
    sheet.save(output)
    return {"size": sheet.size, "rows": rows, "columns": columns}


def make_incinerator_foot_glow_sheet(source, output, frame_size, columns):
    source_img = Image.open(source).convert("RGBA")
    rows = source_img.height // frame_size
    sheet = Image.new("RGBA", source_img.size, (0, 0, 0, 0))
    lower_cutoff = int(frame_size * 0.55)

    for row in range(rows):
        for col in range(columns):
            box = (
                col * frame_size,
                row * frame_size,
                (col + 1) * frame_size,
                (row + 1) * frame_size,
            )
            frame = source_img.crop(box)
            pixels = frame.load()
            mask = Image.new("L", (frame_size, frame_size), 0)
            mask_pixels = mask.load()
            for y in range(lower_cutoff, frame_size):
                for x in range(frame_size):
                    red, green, blue, alpha = pixels[x, y]
                    if (
                        alpha > 24
                        and red > 85
                        and green > 32
                        and blue < 90
                        and red > green * 1.12
                        and green > blue * 1.15
                    ):
                        mask_pixels[x, y] = min(255, int(alpha * 1.7))

            halo = mask.filter(ImageFilter.GaussianBlur(3.0))
            glow = Image.new("RGBA", (frame_size, frame_size), (255, 112, 14, 0))
            glow.putalpha(halo.point(lambda value: min(210, int(value * 1.45))))

            core = Image.new("RGBA", (frame_size, frame_size), (255, 196, 44, 0))
            core.putalpha(mask.point(lambda value: min(255, int(value * 1.1))))
            glow.alpha_composite(core)
            sheet.alpha_composite(glow, (col * frame_size, row * frame_size))

    ensure_dir(Path(output).parent)
    sheet.save(output)
    return {"size": sheet.size, "rows": rows, "columns": columns}


def icon_strip(source, output, fit_size=112):
    src = Image.open(source).convert("RGBA")
    bbox = src.getbbox()
    if bbox:
        src = src.crop(bbox)
    src.thumbnail((fit_size, fit_size), Image.Resampling.LANCZOS)
    src = enhance_rgba(src)
    base = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    base.alpha_composite(src, ((128 - src.width) // 2, (128 - src.height) // 2))
    strip = Image.new("RGBA", (224, 128), (0, 0, 0, 0))
    strip.alpha_composite(base, (0, 0))
    strip.alpha_composite(base.resize((64, 64), Image.Resampling.LANCZOS), (128, 0))
    strip.alpha_composite(base.resize((32, 32), Image.Resampling.LANCZOS), (192, 0))
    ensure_dir(Path(output).parent)
    strip.save(output)
    return {"size": strip.size, "source": str(source)}


def icon_strip_from_sheet(sheet, output, frame_size, direction_row, frame_column, fit_size=112):
    source = Image.open(sheet).convert("RGBA")
    frame = source.crop((
        frame_column * frame_size,
        direction_row * frame_size,
        (frame_column + 1) * frame_size,
        (direction_row + 1) * frame_size,
    ))
    bbox = frame.getbbox()
    if bbox:
        frame = frame.crop(bbox)
    frame.thumbnail((fit_size, fit_size), Image.Resampling.LANCZOS)
    base = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    base.alpha_composite(frame, ((128 - frame.width) // 2, (128 - frame.height) // 2))
    strip = Image.new("RGBA", (224, 128), (0, 0, 0, 0))
    strip.alpha_composite(base, (0, 0))
    strip.alpha_composite(base.resize((64, 64), Image.Resampling.LANCZOS), (128, 0))
    strip.alpha_composite(base.resize((32, 32), Image.Resampling.LANCZOS), (192, 0))
    ensure_dir(Path(output).parent)
    strip.save(output)
    return {
        "size": strip.size,
        "source": str(sheet),
        "direction_row": direction_row,
        "frame_column": frame_column,
    }


def preview_first_frame(sheet, output, frame_size):
    image = Image.open(sheet).convert("RGBA")
    frame = image.crop((0, 0, frame_size, frame_size))
    ensure_dir(Path(output).parent)
    frame.save(output)


def copy_file(src, dst):
    ensure_dir(Path(dst).parent)
    shutil.copy2(src, dst)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo-root", default=".")
    parser.add_argument("--output-root", default="output/meshy/military-5-fire")
    parser.add_argument("--quality", choices=("smoke", "final"), default="final")
    parser.add_argument("--promote", action="store_true")
    args = parser.parse_args()

    repo_root = Path(args.repo_root).resolve()
    output_root = (repo_root / args.output_root).resolve()
    packed_root = output_root / "packed" / args.quality
    ensure_dir(packed_root)

    inc_root = output_root / "incinerator" / args.quality
    grenade_root = output_root / "inferno-grenade" / args.quality

    results = {}
    inc_base = packed_root / "incinerator-bot.png"
    inc_glow = packed_root / "incinerator-bot-glow.png"
    inc_shadow = packed_root / "incinerator-bot-shadow.png"
    results["incinerator_base"] = pack_frames(inc_root / "frames" / "base", inc_base, 8 if args.quality == "final" else 4, 128 if args.quality == "final" else 96)
    results["incinerator_glow"] = make_incinerator_foot_glow_sheet(inc_base, inc_glow, 128 if args.quality == "final" else 96, 8 if args.quality == "final" else 4)
    results["incinerator_shadow"] = make_shadow_sheet(inc_base, inc_shadow, 128 if args.quality == "final" else 96, 8 if args.quality == "final" else 4, (7, 7), 3.0, 0.34)

    grenade_sheet = packed_root / "inferno-grenade-projectile.png"
    grenade_shadow = packed_root / "inferno-grenade-projectile-shadow.png"
    results["grenade_projectile"] = pack_frames(grenade_root / "frames" / "projectile", grenade_sheet, 8, 64)
    results["grenade_shadow"] = make_shadow_sheet(grenade_sheet, grenade_shadow, 64, 8, (4, 4), 2.0, 0.42)

    fragment_root = output_root / "inferno-grenade-fragment" / args.quality
    fragment_sheet = packed_root / "inferno-grenade-fragment.png"
    fragment_shadow = packed_root / "inferno-grenade-fragment-shadow.png"
    results["grenade_fragment"] = pack_frames(fragment_root / "frames" / "projectile", fragment_sheet, 8, 64)
    results["grenade_fragment_shadow"] = make_shadow_sheet(fragment_sheet, fragment_shadow, 64, 8, (4, 4), 2.0, 0.42)

    inc_robot_icon = packed_root / "incinerator.png"
    grenade_icon = packed_root / "inferno-grenade.png"
    results["incinerator_robot_icon"] = icon_strip_from_sheet(
        inc_base,
        inc_robot_icon,
        128 if args.quality == "final" else 96,
        12 if args.quality == "final" else 3,
        0,
    )
    results["grenade_icon"] = icon_strip_from_sheet(grenade_sheet, grenade_icon, 64, 0, 0, fit_size=112)

    preview_first_frame(inc_base, packed_root / "preview-incinerator-first-frame.png", 128 if args.quality == "final" else 96)
    preview_first_frame(grenade_sheet, packed_root / "preview-inferno-grenade-first-frame.png", 64)

    promoted = []
    if args.promote:
        entity_root = repo_root / "exotic-space-industries-remembrance" / "graphics" / "entities"
        item_root = repo_root / "exotic-space-industries-remembrance" / "graphics" / "items"
        copy_targets = [
            (inc_base, entity_root / "incinerator" / "incinerator-bot.png"),
            (inc_glow, entity_root / "incinerator" / "incinerator-bot-glow.png"),
            (inc_shadow, entity_root / "incinerator" / "incinerator-bot-shadow.png"),
            (grenade_sheet, entity_root / "inferno-grenade" / "inferno-grenade-projectile.png"),
            (grenade_shadow, entity_root / "inferno-grenade" / "inferno-grenade-projectile-shadow.png"),
            (fragment_sheet, entity_root / "inferno-grenade" / "inferno-grenade-fragment.png"),
            (fragment_shadow, entity_root / "inferno-grenade" / "inferno-grenade-fragment-shadow.png"),
            (inc_robot_icon, item_root / "incinerator.png"),
            (grenade_icon, item_root / "inferno-grenade.png"),
        ]
        for src, dst in copy_targets:
            copy_file(src, dst)
            promoted.append({"source": str(src), "destination": str(dst)})

    manifest = {
        "quality": args.quality,
        "packed_root": str(packed_root),
        "results": results,
        "promoted": promoted,
    }
    manifest_path = packed_root / "military-5-fire-packed-manifest.json"
    manifest_path.write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    print(json.dumps(manifest, indent=2))


if __name__ == "__main__":
    main()
