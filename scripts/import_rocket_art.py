from __future__ import annotations

import argparse
from dataclasses import dataclass
from pathlib import Path
import sys

from PIL import Image


ITEM_MIP_SIZES = [512, 256, 128, 64, 32]
TECH_MIP_SIZES = [256, 128, 64, 32]
TRIM_ALPHA_THRESHOLD = 2
TRIM_PADDING_RATIO = 0.03


@dataclass(frozen=True)
class ItemImport:
    source_name: str
    target_name: str


@dataclass(frozen=True)
class TechImport:
    target_name: str
    left_source_name: str
    right_source_name: str | None = None


ITEM_IMPORTS = [
    ItemImport("Empty rocket airframe icon.png", "ei-rocket-airframe.png"),
    ItemImport("rocket motor.png", "ei-rocket-motor-basic.png"),
    ItemImport("high-energy rocket motor.png", "ei-rocket-motor-high-energy.png"),
    ItemImport("impact warhead.png", "ei-rocket-warhead-impact.png"),
    ItemImport("explosive warhead.png", "ei-rocket-warhead-explosive.png"),
    ItemImport("siege warhead.png", "ei-rocket-warhead-siege.png"),
    ItemImport("corrosive warhead.png", "ei-rocket-warhead-corrosive.png"),
    ItemImport("cryo warhead.png", "ei-rocket-warhead-cryo.png"),
    ItemImport("atomic 235 warhead.png", "ei-rocket-warhead-atomic-u235.png"),
    ItemImport("atomic plutonium warhead.png", "ei-rocket-warhead-atomic-plutonium.png"),
    ItemImport("corrosive rocket.png", "ei-corrosive-rocket.png"),
    ItemImport("cryo rocket.png", "ei-cryo-rocket.png"),
    ItemImport("atomic 235 rocket.png", "ei-atomic-bomb-u235.png"),
    ItemImport("atomic plutonium rocket.png", "ei-atomic-bomb-plutonium.png"),
    ItemImport("doeworks siege rocket.png", "dw-deer-ammo-basic.png"),
    ItemImport("doeworks corrosive rocket.png", "dw-deer-ammo-corrosive.png"),
    ItemImport("doeworks cryo rocket.png", "dw-deer-ammo-cryo.png"),
    ItemImport("doeworks atomic 235 rocket.png", "dw-deer-ammo-atomic-u235.png"),
    ItemImport("doeworks atomic plutonium rocket.png", "dw-deer-ammo-atomic-plutonium.png"),
]


TECH_IMPORTS = [
    TechImport("dw-deer-tech.png", "doeworks siege rocket.png"),
    TechImport("ei-corrosive-rocketry.png", "corrosive rocket.png", "doeworks corrosive rocket.png"),
    TechImport("ei-cryo-rocketry.png", "cryo rocket.png", "doeworks cryo rocket.png"),
    TechImport("atomic-bomb.png", "atomic 235 rocket.png", "doeworks atomic 235 rocket.png"),
    TechImport("ei-plutonium-warheads.png", "atomic plutonium rocket.png", "doeworks atomic plutonium rocket.png"),
]


def trim_transparency(image: Image.Image) -> Image.Image:
    alpha = image.getchannel("A")
    mask = alpha.point(lambda value: 255 if value >= TRIM_ALPHA_THRESHOLD else 0, mode="L")
    bbox = mask.getbbox() or image.getbbox()
    if not bbox:
        return image.copy()

    pad_pixels = round(max(bbox[2] - bbox[0], bbox[3] - bbox[1]) * TRIM_PADDING_RATIO)
    width, height = image.size
    left = max(0, bbox[0] - pad_pixels)
    top = max(0, bbox[1] - pad_pixels)
    right = min(width, bbox[2] + pad_pixels)
    bottom = min(height, bbox[3] + pad_pixels)
    return image.crop((left, top, right, bottom))


def square_fit(image: Image.Image, size: int) -> Image.Image:
    trimmed = trim_transparency(image)
    width, height = trimmed.size
    if width == 0 or height == 0:
        raise ValueError("source image became empty after transparency trim")

    scale = min(size / width, size / height)
    scaled_width = max(1, round(width * scale))
    scaled_height = max(1, round(height * scale))
    resized = trimmed.resize((scaled_width, scaled_height), Image.LANCZOS)

    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    offset_x = (size - scaled_width) // 2
    offset_y = (size - scaled_height) // 2
    canvas.alpha_composite(resized, (offset_x, offset_y))
    return canvas


def inset_square(image: Image.Image, size: int, scale: float) -> Image.Image:
    target_size = max(1, round(size * scale))
    return square_fit(image, target_size)


def compose_single(source_image: Image.Image, size: int) -> Image.Image:
    return square_fit(source_image, size)


def compose_pair(left_image: Image.Image, right_image: Image.Image, size: int) -> Image.Image:
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))

    left_square = inset_square(left_image, size, 0.54)
    right_square = inset_square(right_image, size, 0.70)

    left_x = round(size * 0.03)
    left_y = round(size * 0.18)
    right_x = round(size * 0.29)
    right_y = round(size * 0.07)

    canvas.alpha_composite(left_square, (left_x, left_y))
    canvas.alpha_composite(right_square, (right_x, right_y))
    return canvas


def make_mip_strip(square_image: Image.Image, mip_sizes: list[int]) -> Image.Image:
    base_size = mip_sizes[0]
    strip_width = sum(mip_sizes)
    strip = Image.new("RGBA", (strip_width, base_size), (0, 0, 0, 0))

    x_offset = 0
    for mip_size in mip_sizes:
        mip = square_image.resize((mip_size, mip_size), Image.LANCZOS)
        strip.alpha_composite(mip, (x_offset, 0))
        x_offset += mip_size

    return strip


def load_rgba(path: Path) -> Image.Image:
    return Image.open(path).convert("RGBA")


def ensure_sources_exist(downloads_dir: Path) -> None:
    missing = []
    expected = {entry.source_name for entry in ITEM_IMPORTS}
    expected.update(filter(None, [entry.left_source_name for entry in TECH_IMPORTS]))
    expected.update(filter(None, [entry.right_source_name for entry in TECH_IMPORTS]))

    for source_name in sorted(expected):
        if not (downloads_dir / source_name).exists():
            missing.append(source_name)

    if missing:
        joined = "\n".join(f"  - {name}" for name in missing)
        raise FileNotFoundError(f"Missing expected source files in {downloads_dir}:\n{joined}")


def build_item_assets(downloads_dir: Path, output_dir: Path) -> None:
    output_dir.mkdir(parents=True, exist_ok=True)
    for entry in ITEM_IMPORTS:
        source = load_rgba(downloads_dir / entry.source_name)
        square_master = square_fit(source, ITEM_MIP_SIZES[0])
        strip = make_mip_strip(square_master, ITEM_MIP_SIZES)
        target_path = output_dir / entry.target_name
        strip.save(target_path)
        print(f"saved item {target_path}")


def build_tech_assets(downloads_dir: Path, output_dir: Path) -> None:
    output_dir.mkdir(parents=True, exist_ok=True)
    for entry in TECH_IMPORTS:
        left_image = load_rgba(downloads_dir / entry.left_source_name)
        if entry.right_source_name:
            right_image = load_rgba(downloads_dir / entry.right_source_name)
            square_master = compose_pair(left_image, right_image, TECH_MIP_SIZES[0])
        else:
            square_master = compose_single(left_image, TECH_MIP_SIZES[0])

        strip = make_mip_strip(square_master, TECH_MIP_SIZES)
        target_path = output_dir / entry.target_name
        strip.save(target_path)
        print(f"saved tech {target_path}")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Import ESIR rocket-family art from Downloads into mipmapped temporary main-mod assets.")
    parser.add_argument(
        "--downloads-dir",
        type=Path,
        default=Path.home() / "Downloads",
        help="Directory containing the ready rocket-family PNG sources.",
    )
    parser.add_argument(
        "--items-dir",
        type=Path,
        default=Path("exotic-space-industries-remembrance") / "graphics" / "temp" / "rocket-family" / "items",
        help="Output directory for mipmapped item/ammo/intermediate art.",
    )
    parser.add_argument(
        "--tech-dir",
        type=Path,
        default=Path("exotic-space-industries-remembrance") / "graphics" / "temp" / "rocket-family" / "tech",
        help="Output directory for mipmapped tech art.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()

    ensure_sources_exist(args.downloads_dir)
    build_item_assets(args.downloads_dir, args.items_dir)
    build_tech_assets(args.downloads_dir, args.tech_dir)
    return 0


if __name__ == "__main__":
    sys.exit(main())
