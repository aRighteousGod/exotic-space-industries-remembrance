#!/usr/bin/env python3
"""Add transparent per-cell padding to Spritter rolling-stock sheets."""

from __future__ import annotations

import argparse
import re
from pathlib import Path

from PIL import Image


def parse_metadata(path: Path) -> dict[str, int]:
    text = path.read_text(encoding="utf-8")
    values: dict[str, int] = {}
    for key in ("file_count", "height", "line_length", "lines_per_file", "sprite_count", "width"):
        match = re.search(rf'\["{key}"\]\s*=\s*(\d+)', text)
        if not match:
            raise ValueError(f"{path} is missing metadata key {key}")
        values[key] = int(match.group(1))
    return values


def update_metadata(path: Path, width: int, height: int) -> None:
    text = path.read_text(encoding="utf-8")
    text = re.sub(r'(\["width"\]\s*=\s*)\d+', rf"\g<1>{width}", text)
    text = re.sub(r'(\["height"\]\s*=\s*)\d+', rf"\g<1>{height}", text)
    path.write_text(text, encoding="utf-8", newline="\n")


def edge_max_alpha(alpha: Image.Image, left: int, top: int, right: int, bottom: int) -> int:
    edge_values = []
    edge_values.extend(alpha.crop((left, top, right, top + 1)).getdata())
    edge_values.extend(alpha.crop((left, bottom - 1, right, bottom)).getdata())
    if bottom - top > 2:
        edge_values.extend(alpha.crop((left, top + 1, left + 1, bottom - 1)).getdata())
        edge_values.extend(alpha.crop((right - 1, top + 1, right, bottom - 1)).getdata())
    return max(edge_values) if edge_values else 0


def layer_needs_padding(target_dir: Path, layer: str, metadata: dict[str, int], alpha_threshold: int) -> bool:
    for file_index in range(metadata["file_count"]):
        png = target_dir / f"{layer}-{file_index}.png"
        if not png.exists():
            raise FileNotFoundError(png)
        with Image.open(png).convert("RGBA") as sheet:
            alpha = sheet.getchannel("A")
            for row in range(metadata["lines_per_file"]):
                for column in range(metadata["line_length"]):
                    sprite_index = (
                        file_index * metadata["line_length"] * metadata["lines_per_file"]
                        + row * metadata["line_length"]
                        + column
                    )
                    if sprite_index >= metadata["sprite_count"]:
                        continue
                    left = column * metadata["width"]
                    top = row * metadata["height"]
                    right = left + metadata["width"]
                    bottom = top + metadata["height"]
                    if edge_max_alpha(alpha, left, top, right, bottom) >= alpha_threshold:
                        return True
    return False


def pad_layer(target_dir: Path, layer: str, padding: int, alpha_threshold: int) -> None:
    metadata_path = target_dir / f"{layer}.lua"
    metadata = parse_metadata(metadata_path)
    if not layer_needs_padding(target_dir, layer, metadata, alpha_threshold):
        print(f"skipped {target_dir.name}/{layer}: packed cells already have clear edges")
        return

    old_width = metadata["width"]
    old_height = metadata["height"]
    new_width = old_width + padding * 2
    new_height = old_height + padding * 2

    for file_index in range(metadata["file_count"]):
        png = target_dir / f"{layer}-{file_index}.png"
        if not png.exists():
            raise FileNotFoundError(png)

        with Image.open(png).convert("RGBA") as sheet:
            expected_size = (
                old_width * metadata["line_length"],
                old_height * metadata["lines_per_file"],
            )
            padded_size = (
                new_width * metadata["line_length"],
                new_height * metadata["lines_per_file"],
            )
            if sheet.size == padded_size:
                continue
            if sheet.size != expected_size:
                raise ValueError(f"{png}: size={sheet.size}, expected={expected_size}")

            padded = Image.new("RGBA", padded_size, (0, 0, 0, 0))
            for row in range(metadata["lines_per_file"]):
                for column in range(metadata["line_length"]):
                    left = column * old_width
                    top = row * old_height
                    cell = sheet.crop((left, top, left + old_width, top + old_height))
                    padded.paste(cell, (column * new_width + padding, row * new_height + padding))

            padded.save(png)

    update_metadata(metadata_path, new_width, new_height)
    print(f"padded {target_dir.name}/{layer}: {old_width}x{old_height} -> {new_width}x{new_height}")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("target_dir", type=Path, help="Directory containing Spritter layer PNGs and Lua metadata.")
    parser.add_argument("--layer", choices=("body", "sloped"), action="append", required=True)
    parser.add_argument("--padding", type=int, default=16, help="Transparent pixels to add around every cell.")
    parser.add_argument("--alpha-threshold", type=int, default=8, help="Pad only when a cell edge reaches this alpha.")
    args = parser.parse_args()

    if args.padding < 0:
        raise ValueError("--padding must be non-negative")
    for layer in args.layer:
        pad_layer(args.target_dir, layer, args.padding, args.alpha_threshold)


if __name__ == "__main__":
    main()
