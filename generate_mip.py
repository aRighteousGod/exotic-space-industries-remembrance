import argparse
import os
from pathlib import Path

from PIL import Image


def generate_mipmaps(input_path, output_path=None, mip_sizes=None):
    base_image = Image.open(input_path).convert("RGBA")
    mip_sizes = mip_sizes or [512, 256, 128, 64, 32]
    mipmaps = [base_image.resize((size, size), Image.LANCZOS) for size in mip_sizes]

    total_width = sum(mipmap.width for mipmap in mipmaps)
    height = mipmaps[0].height
    combined = Image.new("RGBA", (total_width, height), (0, 0, 0, 0))

    x_offset = 0
    for mipmap in mipmaps:
        combined.paste(mipmap, (x_offset, 0))
        x_offset += mipmap.width

    if output_path is None:
        base_name, _ext = os.path.splitext(input_path)
        output_path = f"{base_name}_mip.png"

    combined.save(output_path)
    print(f"Saved mipmap strip as '{output_path}'.")


def parse_args():
    parser = argparse.ArgumentParser(description="Generate a horizontal mipmap strip from a square source image.")
    parser.add_argument("inputs", nargs="*", help="Input image paths.")
    parser.add_argument("--output", help="Output path for a single input.")
    parser.add_argument("--sizes", nargs="+", type=int, help="Explicit mip sizes, largest to smallest.")
    return parser.parse_args()


def main():
    args = parse_args()
    if args.output and len(args.inputs) != 1:
        raise SystemExit("--output can only be used with exactly one input image.")

    if args.inputs:
        for input_path in args.inputs:
            output_path = args.output if args.output else None
            generate_mipmaps(input_path, output_path=output_path, mip_sizes=args.sizes)
        return

    # Preserve the old ceramic batch behavior when the script is run with no args.
    for legacy_name in ("ceramic.png", "ceramic-2.png", "ceramic-3.png"):
        if Path(legacy_name).exists():
            generate_mipmaps(legacy_name)


if __name__ == "__main__":
    main()
