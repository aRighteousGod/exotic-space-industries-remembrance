import argparse
import json
import shutil
from pathlib import Path

from PIL import Image, ImageFilter


FRAME_SIZE = 128
GLOW_COLOR = (28, 255, 232)
CORE_COLOR = (170, 255, 246)
ITEM_MIPS = (
    (0, 0, 128),
    (128, 0, 64),
    (192, 0, 32),
)


def ensure_dir(path):
    Path(path).mkdir(parents=True, exist_ok=True)


def copy_file(src, dst):
    ensure_dir(Path(dst).parent)
    shutil.copy2(src, dst)


def central_teal_mask(frame):
    frame = frame.convert("RGBA")
    width, height = frame.size
    pixels = frame.load()
    mask = Image.new("L", frame.size, 0)
    mask_pixels = mask.load()
    cx = width * 0.5
    cy = height * 0.325
    rx = width * 0.24
    ry = height * 0.18
    selected = 0

    for y in range(height):
        for x in range(width):
            red, green, blue, alpha = pixels[x, y]
            if alpha <= 18:
                continue

            radial = ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2
            if radial > 1.0:
                continue

            if (
                green > 105
                and blue > 82
                and green > red * 1.55
                and blue > red * 1.18
                and abs(green - blue) < 112
            ):
                mask_pixels[x, y] = min(255, int(alpha * 1.75))
                selected += 1

    if selected == 0:
        raise RuntimeError("No central teal pixels were selected for the glow mask")

    return mask, selected


def item_teal_mask(frame):
    frame = frame.convert("RGBA")
    width, height = frame.size
    pixels = frame.load()
    mask = Image.new("L", frame.size, 0)
    mask_pixels = mask.load()
    cx = width * 0.5
    cy = height * 0.46
    rx = width * 0.25
    ry = height * 0.22
    selected = 0

    for y in range(height):
        for x in range(width):
            red, green, blue, alpha = pixels[x, y]
            if alpha <= 18:
                continue

            radial = ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2
            if radial > 1.0:
                continue

            if (
                green > 96
                and blue > 78
                and green > red * 1.25
                and blue > red * 1.08
                and abs(green - blue) < 124
            ):
                mask_pixels[x, y] = min(255, int(alpha * 1.65))
                selected += 1

    if selected == 0:
        raise RuntimeError("No central teal pixels were selected for the item glow mask")

    return mask, selected


def make_glow_sheet(source, output, frame_size, columns):
    source_img = Image.open(source).convert("RGBA")
    rows = source_img.height // frame_size
    sheet = Image.new("RGBA", source_img.size, (0, 0, 0, 0))
    total_selected = 0

    for row in range(rows):
        for col in range(columns):
            box = (
                col * frame_size,
                row * frame_size,
                (col + 1) * frame_size,
                (row + 1) * frame_size,
            )
            frame = source_img.crop(box)
            mask, selected = central_teal_mask(frame)
            total_selected += selected

            halo = mask.filter(ImageFilter.GaussianBlur(4.0))
            glow = Image.new("RGBA", (frame_size, frame_size), (*GLOW_COLOR, 0))
            glow.putalpha(halo.point(lambda value: min(205, int(value * 1.6))))

            core_mask = mask.filter(ImageFilter.GaussianBlur(0.65))
            core = Image.new("RGBA", (frame_size, frame_size), (*CORE_COLOR, 0))
            core.putalpha(core_mask.point(lambda value: min(255, int(value * 1.2))))

            glow.alpha_composite(core)
            sheet.alpha_composite(glow, (col * frame_size, row * frame_size))

    ensure_dir(Path(output).parent)
    sheet.save(output)
    return {
        "source": str(source),
        "output": str(output),
        "size": sheet.size,
        "rows": rows,
        "columns": columns,
        "selected_pixels": total_selected,
    }


def make_item_glow_strip(source, output):
    source_img = Image.open(source).convert("RGBA")
    sheet = Image.new("RGBA", source_img.size, (0, 0, 0, 0))
    total_selected = 0

    for x, y, size in ITEM_MIPS:
        frame = source_img.crop((x, y, x + size, y + size))
        mask, selected = item_teal_mask(frame)
        total_selected += selected

        halo = mask.filter(ImageFilter.GaussianBlur(max(1.0, size / 28)))
        glow = Image.new("RGBA", (size, size), (*GLOW_COLOR, 0))
        glow.putalpha(halo.point(lambda value: min(210, int(value * 1.55))))

        core = Image.new("RGBA", (size, size), (*CORE_COLOR, 0))
        core.putalpha(mask.point(lambda value: min(255, int(value * 1.08))))
        glow.alpha_composite(core)
        sheet.alpha_composite(glow, (x, y))

    ensure_dir(Path(output).parent)
    sheet.save(output)
    return {
        "source": str(source),
        "output": str(output),
        "size": sheet.size,
        "selected_pixels": total_selected,
    }


def make_preview(base, glow, output):
    base_img = Image.open(base).convert("RGBA")
    glow_img = Image.open(glow).convert("RGBA")
    preview = Image.new("RGBA", base_img.size, (9, 12, 13, 255))
    preview.alpha_composite(base_img)
    preview.alpha_composite(glow_img)
    ensure_dir(Path(output).parent)
    preview.save(output)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo-root", default=".")
    parser.add_argument("--render-root", default="output/meshy/prediction-snare-mine/Render")
    parser.add_argument("--packed-root", default="output/meshy/prediction-snare-mine/packed")
    parser.add_argument("--frame-size", type=int, default=FRAME_SIZE)
    parser.add_argument("--columns", type=int, default=1)
    parser.add_argument("--promote", action="store_true")
    args = parser.parse_args()

    repo_root = Path(args.repo_root).resolve()
    render_root = (repo_root / args.render_root).resolve()
    packed_root = (repo_root / args.packed_root).resolve()
    ensure_dir(packed_root)

    source_base = render_root / ".Sheets" / "object_0.png"
    source_shadow = render_root / ".Sheets" / "object_shadow_0.png"
    if not source_base.exists():
        raise FileNotFoundError(source_base)
    if not source_shadow.exists():
        raise FileNotFoundError(source_shadow)

    base = packed_root / "prediction-snare-mine.png"
    shadow = packed_root / "prediction-snare-mine-shadow.png"
    glow = packed_root / "prediction-snare-mine-glow.png"
    preview = packed_root / "prediction-snare-mine-preview.png"
    item_icon = (
        repo_root
        / "exotic-space-industries-remembrance-graphics-4"
        / "graphics"
        / "items"
        / "prediction-snare-mine.png"
    )
    item_glow = packed_root / "prediction-snare-mine-item-glow.png"

    copy_file(source_base, base)
    copy_file(source_shadow, shadow)
    glow_result = make_glow_sheet(base, glow, args.frame_size, args.columns)
    make_preview(base, glow, preview)
    item_glow_result = None
    if item_icon.exists():
        item_glow_result = make_item_glow_strip(item_icon, item_glow)

    promoted = []
    if args.promote:
        entity_root = (
            repo_root
            / "exotic-space-industries-remembrance-graphics-4"
            / "graphics"
            / "entities"
            / "prediction-snare-mine"
        )
        for src in (base, shadow, glow):
            dst = entity_root / src.name
            copy_file(src, dst)
            promoted.append({"source": str(src), "destination": str(dst)})
        if item_glow_result:
            dst = item_icon.with_name("prediction-snare-mine-glow.png")
            copy_file(item_glow, dst)
            promoted.append({"source": str(item_glow), "destination": str(dst)})

    manifest = {
        "source_model": str(repo_root / "models" / "prediction-snare-mine.glb"),
        "render_root": str(render_root),
        "packed_root": str(packed_root),
        "base": str(base),
        "shadow": str(shadow),
        "glow": glow_result,
        "item_glow": item_glow_result,
        "preview": str(preview),
        "promoted": promoted,
    }
    manifest_path = packed_root / "prediction-snare-mine-packed-manifest.json"
    manifest_path.write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    print(json.dumps(manifest, indent=2))


if __name__ == "__main__":
    main()
