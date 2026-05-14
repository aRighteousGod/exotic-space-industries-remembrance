from __future__ import annotations

import argparse
import json
import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageEnhance, ImageFilter


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Build Emerald Apocalypse charge item and ground-glow icons.")
    parser.add_argument("--frames-dir", required=True, help="Directory containing frame_###.png renders.")
    parser.add_argument("--output-icon", required=True, help="Main 128/64/32 icon strip output.")
    parser.add_argument("--output-glow", required=True, help="Matching ground glow 128/64/32 strip output.")
    parser.add_argument("--work-dir", required=True, help="Preview/contact-sheet output directory.")
    parser.add_argument("--selected-index", type=int, help="Force a specific frame index.")
    parser.add_argument("--manifest", help="Optional manifest path.")
    return parser.parse_args()


def alpha_bbox(image: Image.Image, threshold: int = 8) -> tuple[int, int, int, int] | None:
    alpha = image.getchannel("A").point(lambda a: 255 if a > threshold else 0)
    return alpha.getbbox()


def score_frame(path: Path) -> dict[str, float | int | str | tuple[int, int, int, int] | None]:
    image = Image.open(path).convert("RGBA")
    bbox = alpha_bbox(image)
    if bbox is None:
        return {"path": str(path), "index": int(path.stem.split("_")[-1]), "score": -9999.0, "bbox": None}

    width, height = image.size
    left, top, right, bottom = bbox
    bbox_w = right - left
    bbox_h = bottom - top
    bbox_area = bbox_w * bbox_h
    aspect = bbox_w / max(1, bbox_h)
    target_aspect = 1.18
    margins = (left, top, width - right, height - bottom)
    min_margin = min(margins) / max(width, height)

    px = image.load()
    alpha_area = 0
    green_energy = 0.0
    bronze_energy = 0.0
    for y in range(top, bottom):
        for x in range(left, right):
            r, g, b, a = px[x, y]
            if a <= 8:
                continue
            alpha_area += 1
            green_energy += max(0, g - max(r, b) * 0.72) * (a / 255.0)
            bronze_energy += max(0, min(r * 0.72, g * 0.58) - b * 0.28) * (a / 255.0)

    fill = bbox_area / float(width * height)
    subject_density = alpha_area / max(1, bbox_area)
    aspect_penalty = abs(math.log(max(aspect, 0.001) / target_aspect))
    crop_penalty = max(0.0, 0.065 - min_margin) * 8.0
    score = (
        fill * 3.4
        + subject_density * 0.55
        + min(green_energy / max(1, alpha_area), 1.0) * 0.34
        + min(bronze_energy / max(1, alpha_area), 1.0) * 0.18
        - aspect_penalty * 0.42
        - crop_penalty
    )

    return {
        "path": str(path),
        "index": int(path.stem.split("_")[-1]),
        "score": score,
        "bbox": bbox,
        "aspect": aspect,
        "fill": fill,
        "subject_density": subject_density,
        "min_margin": min_margin,
    }


def crop_subject(image: Image.Image, padding: int = 18) -> Image.Image:
    bbox = alpha_bbox(image)
    if bbox is None:
        raise ValueError("Selected frame is fully transparent.")
    left, top, right, bottom = bbox
    left = max(0, left - padding)
    top = max(0, top - padding)
    right = min(image.width, right + padding)
    bottom = min(image.height, bottom + padding)
    return image.crop((left, top, right, bottom))


def make_canvas(subject: Image.Image, size: int = 128, fit: int = 112) -> Image.Image:
    subject = ImageEnhance.Contrast(subject).enhance(1.08)
    subject = ImageEnhance.Color(subject).enhance(1.08)
    subject = subject.filter(ImageFilter.UnsharpMask(radius=0.85, percent=115, threshold=3))
    scale = min(fit / subject.width, fit / subject.height)
    resized = subject.resize(
        (max(1, round(subject.width * scale)), max(1, round(subject.height * scale))),
        Image.Resampling.LANCZOS,
    )
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    origin = ((size - resized.width) // 2, max(0, (size - resized.height) // 2 - 1))
    canvas.alpha_composite(resized, origin)
    return canvas


def make_inventory_icon(base: Image.Image) -> Image.Image:
    alpha = base.getchannel("A")
    halo = Image.new("RGBA", base.size, (0, 255, 145, 0))
    halo_alpha = alpha.filter(ImageFilter.GaussianBlur(4.0)).point(lambda a: int(a * 0.22))
    halo.putalpha(halo_alpha)
    return Image.alpha_composite(halo, base)


def make_ground_glow(base: Image.Image) -> Image.Image:
    alpha = base.getchannel("A")
    px = base.load()
    green_mask = Image.new("L", base.size, 0)
    mask_px = green_mask.load()
    for y in range(base.height):
        for x in range(base.width):
            r, g, b, a = px[x, y]
            if a <= 8:
                continue
            emerald = max(0, g - max(r, b) * 0.58)
            inner = max(0, min(255, int(emerald * 1.9 + a * 0.20)))
            mask_px[x, y] = min(255, inner)

    broad = alpha.filter(ImageFilter.GaussianBlur(7.5)).point(lambda a: int(a * 0.28))
    core = green_mask.filter(ImageFilter.GaussianBlur(2.4)).point(lambda a: min(255, int(a * 1.15)))
    singularity = Image.new("L", base.size, 0)
    draw = ImageDraw.Draw(singularity, "L")
    draw.ellipse((46, 44, 82, 82), fill=118)
    draw.ellipse((55, 52, 73, 72), fill=210)
    singularity = singularity.filter(ImageFilter.GaussianBlur(5.0))

    glow_alpha = Image.new("L", base.size, 0)
    for source in (broad, core, singularity):
        glow_alpha = Image.composite(source, glow_alpha, source.point(lambda a: min(255, a)))
    glow_alpha = glow_alpha.point(lambda a: min(235, int(a * 1.08)))

    glow = Image.new("RGBA", base.size, (0, 255, 145, 0))
    glow.putalpha(glow_alpha)
    return glow


def build_strip(base_icon: Image.Image) -> Image.Image:
    strip = Image.new("RGBA", (224, 128), (0, 0, 0, 0))
    strip.alpha_composite(base_icon, (0, 0))
    mip64 = base_icon.resize((64, 64), Image.Resampling.LANCZOS)
    mip32 = base_icon.resize((32, 32), Image.Resampling.LANCZOS)
    strip.alpha_composite(mip64, (128, 0))
    strip.alpha_composite(mip32, (192, 0))
    return strip


def make_contact_sheet(scores: list[dict], output: Path) -> None:
    tile = 160
    columns = 8
    rows = math.ceil(len(scores) / columns)
    sheet = Image.new("RGBA", (columns * tile, rows * tile), (8, 10, 10, 255))
    draw = ImageDraw.Draw(sheet, "RGBA")
    for slot, score in enumerate(scores):
        frame = Image.open(score["path"]).convert("RGBA")
        frame.thumbnail((tile - 12, tile - 28), Image.Resampling.LANCZOS)
        x = (slot % columns) * tile
        y = (slot // columns) * tile
        sheet.alpha_composite(frame, (x + (tile - frame.width) // 2, y + 18))
        label = f'{score["index"]:02d}  {float(score["score"]):.2f}'
        draw.text((x + 6, y + 4), label, fill=(150, 255, 198, 235))
    output.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(output)


def main() -> None:
    args = parse_args()
    frames_dir = Path(args.frames_dir)
    work_dir = Path(args.work_dir)
    frame_paths = sorted(frames_dir.glob("frame_*.png"))
    if not frame_paths:
        raise FileNotFoundError(f"No rendered frames in {frames_dir}")

    scores = [score_frame(path) for path in frame_paths]
    scores.sort(key=lambda item: float(item["score"]), reverse=True)
    selected = None
    if args.selected_index is not None:
        for score in scores:
            if int(score["index"]) == args.selected_index:
                selected = score
                break
        if selected is None:
            raise ValueError(f"Requested frame {args.selected_index} was not rendered.")
    else:
        selected = scores[0]

    work_dir.mkdir(parents=True, exist_ok=True)
    make_contact_sheet(sorted(scores, key=lambda item: int(item["index"])), work_dir / "emerald-apocalypse-charge-turntable-contact.png")

    selected_frame = Image.open(selected["path"]).convert("RGBA")
    source = crop_subject(selected_frame)
    source.save(work_dir / "emerald-apocalypse-charge-selected-source.png")
    base_128 = make_inventory_icon(make_canvas(source))
    glow_128 = make_ground_glow(base_128)
    composite_ground = Image.alpha_composite(base_128, glow_128)

    base_128.save(work_dir / "emerald-apocalypse-charge-preview-128.png")
    glow_128.save(work_dir / "emerald-apocalypse-charge-ground-glow-preview-128.png")
    composite_ground.save(work_dir / "emerald-apocalypse-charge-ground-composite-preview-128.png")

    output_icon = Path(args.output_icon)
    output_glow = Path(args.output_glow)
    output_icon.parent.mkdir(parents=True, exist_ok=True)
    output_glow.parent.mkdir(parents=True, exist_ok=True)
    build_strip(base_128).save(output_icon)
    build_strip(glow_128).save(output_glow)

    manifest_path = Path(args.manifest) if args.manifest else work_dir / "emerald-apocalypse-charge-icon-manifest.json"
    manifest = {
        "selected": selected,
        "top_scores": scores[:8],
        "outputs": {
            "icon": str(output_icon),
            "glow": str(output_glow),
            "preview": str(work_dir / "emerald-apocalypse-charge-preview-128.png"),
            "ground_composite_preview": str(work_dir / "emerald-apocalypse-charge-ground-composite-preview-128.png"),
            "contact_sheet": str(work_dir / "emerald-apocalypse-charge-turntable-contact.png"),
        },
        "icon_size": 128,
        "icon_mipmaps": 3,
        "ground_picture_size": 128,
        "ground_picture_scale": 0.25,
    }
    manifest_path.write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    print(f"selected_index={selected['index']}")
    print(f"score={float(selected['score']):.4f}")
    print(f"icon={output_icon}")
    print(f"glow={output_glow}")
    print(f"manifest={manifest_path}")


if __name__ == "__main__":
    main()
