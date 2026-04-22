from __future__ import annotations

import argparse
import math
import shutil
from collections import Counter, deque
from pathlib import Path

from PIL import Image, ImageFilter


DEFAULT_BG_SWATCHES = [
    (254.0, 254.0, 254.0),
    (237.0, 237.0, 237.0),
]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Convert ESIR source art into a transparent horizontal 128/64/32 "
            "Factorio item icon strip."
        )
    )
    parser.add_argument("--source", required=True, help="Path to the source image.")
    parser.add_argument(
        "--output",
        required=True,
        help="Destination path for the generated mip strip.",
    )
    parser.add_argument(
        "--backup",
        help="Optional path for a backup copy of the source before overwrite.",
    )
    parser.add_argument(
        "--preview",
        help="Optional path for a plain transparent 128x128 preview icon.",
    )
    parser.add_argument(
        "--canvas-size",
        type=int,
        default=128,
        help="Base icon size. Defaults to 128.",
    )
    parser.add_argument(
        "--fit-size",
        type=int,
        default=118,
        help="Maximum inner size for the fitted subject. Defaults to 118.",
    )
    parser.add_argument(
        "--mip-sizes",
        default="64,32",
        help="Comma-separated mip sizes. Defaults to 64,32.",
    )
    parser.add_argument(
        "--allow-existing-strip",
        action="store_true",
        help="Allow processing an input that already looks like a mip strip.",
    )
    return parser.parse_args()


def parse_mip_sizes(raw: str) -> list[int]:
    values = []
    for part in raw.split(","):
        part = part.strip()
        if not part:
            continue
        values.append(int(part))
    if not values:
        raise ValueError("At least one mip size is required.")
    return values


def is_light_neutral(pixel: tuple[int, int, int, int]) -> bool:
    r, g, b, a = pixel
    if a == 0:
        return True
    return min(r, g, b) >= 225 and (max(r, g, b) - min(r, g, b)) <= 24


def collect_edge_connected_background(image: Image.Image) -> list[list[bool]]:
    width, height = image.size
    px = image.load()
    background = [[False] * width for _ in range(height)]
    queue: deque[tuple[int, int]] = deque()

    def enqueue(x: int, y: int) -> None:
        if background[y][x]:
            return
        if not is_light_neutral(px[x, y]):
            return
        background[y][x] = True
        queue.append((x, y))

    for x in range(width):
        enqueue(x, 0)
        enqueue(x, height - 1)
    for y in range(height):
        enqueue(0, y)
        enqueue(width - 1, y)

    neighbors = [
        (-1, -1),
        (0, -1),
        (1, -1),
        (-1, 0),
        (1, 0),
        (-1, 1),
        (0, 1),
        (1, 1),
    ]

    while queue:
        x, y = queue.popleft()
        for dx, dy in neighbors:
            nx, ny = x + dx, y + dy
            if 0 <= nx < width and 0 <= ny < height:
                if background[ny][nx]:
                    continue
                if not is_light_neutral(px[nx, ny]):
                    continue
                background[ny][nx] = True
                queue.append((nx, ny))

    return background


def background_swatches(
    image: Image.Image, background: list[list[bool]]
) -> list[tuple[float, float, float]]:
    width, height = image.size
    px = image.load()
    counter: Counter[tuple[int, int, int]] = Counter()

    for x in range(width):
        if background[0][x]:
            counter[px[x, 0][:3]] += 1
        if background[height - 1][x]:
            counter[px[x, height - 1][:3]] += 1
    for y in range(height):
        if background[y][0]:
            counter[px[0, y][:3]] += 1
        if background[y][width - 1]:
            counter[px[width - 1, y][:3]] += 1

    swatches = [tuple(map(float, rgb)) for rgb, _ in counter.most_common(4)]
    return swatches or DEFAULT_BG_SWATCHES


def color_distance(
    rgb: tuple[int, int, int], swatch: tuple[float, float, float]
) -> float:
    return math.sqrt(
        (rgb[0] - swatch[0]) ** 2
        + (rgb[1] - swatch[1]) ** 2
        + (rgb[2] - swatch[2]) ** 2
    )


def cut_out_opaque_source(image: Image.Image) -> Image.Image:
    width, height = image.size
    px = image.load()
    background = collect_edge_connected_background(image)
    swatches = background_swatches(image, background)

    background_mask = Image.new("L", (width, height), 0)
    mask_px = background_mask.load()
    for y in range(height):
        row = background[y]
        for x in range(width):
            if row[x]:
                mask_px[x, y] = 255

    ring_mask = background_mask.filter(ImageFilter.MaxFilter(3))
    ring_px = ring_mask.load()

    output = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    out_px = output.load()

    for y in range(height):
        row = background[y]
        for x in range(width):
            r, g, b, _ = px[x, y]
            if row[x]:
                out_px[x, y] = (0, 0, 0, 0)
                continue

            alpha = 255
            if ring_px[x, y]:
                nearest = min(swatches, key=lambda swatch: color_distance((r, g, b), swatch))
                distance = color_distance((r, g, b), nearest)
                alpha = min(255, max(0, int(distance * 10.5)))
                if 0 < alpha < 255:
                    alpha_factor = alpha / 255.0
                    r = int(
                        max(
                            0,
                            min(255, (r - nearest[0] * (1.0 - alpha_factor)) / alpha_factor),
                        )
                    )
                    g = int(
                        max(
                            0,
                            min(255, (g - nearest[1] * (1.0 - alpha_factor)) / alpha_factor),
                        )
                    )
                    b = int(
                        max(
                            0,
                            min(255, (b - nearest[2] * (1.0 - alpha_factor)) / alpha_factor),
                        )
                    )

            out_px[x, y] = (r, g, b, alpha)

    bbox = output.getbbox()
    if bbox is None:
        raise ValueError("Failed to isolate subject from background.")
    return output.crop(bbox)


def prepare_subject(
    image: Image.Image, canvas_size: int, mip_sizes: list[int], allow_existing_strip: bool
) -> Image.Image:
    strip_width = canvas_size + sum(mip_sizes)
    if (
        not allow_existing_strip
        and image.width == strip_width
        and image.height == canvas_size
    ):
        raise ValueError(
            "Input already looks like a mip strip. Use the original source art "
            "or pass --allow-existing-strip explicitly."
        )

    alpha_extrema = image.getchannel("A").getextrema()
    if alpha_extrema[0] < 255:
        bbox = image.getbbox()
        if bbox is None:
            raise ValueError("Input image is fully transparent.")
        return image.crop(bbox)

    return cut_out_opaque_source(image)


def fit_subject(subject: Image.Image, canvas_size: int, fit_size: int) -> Image.Image:
    scale = min(fit_size / subject.width, fit_size / subject.height)
    new_size = (
        max(1, round(subject.width * scale)),
        max(1, round(subject.height * scale)),
    )
    resized = subject.resize(new_size, Image.Resampling.LANCZOS)

    canvas = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
    origin = ((canvas_size - new_size[0]) // 2, (canvas_size - new_size[1]) // 2)
    canvas.paste(resized, origin, resized)
    return canvas


def build_strip(base_icon: Image.Image, mip_sizes: list[int]) -> Image.Image:
    width = base_icon.width + sum(mip_sizes)
    strip = Image.new("RGBA", (width, base_icon.height), (0, 0, 0, 0))
    strip.paste(base_icon, (0, 0), base_icon)

    cursor = base_icon.width
    for mip_size in mip_sizes:
        mip = base_icon.resize((mip_size, mip_size), Image.Resampling.LANCZOS)
        strip.paste(mip, (cursor, 0), mip)
        cursor += mip_size

    return strip


def ensure_parent(path: Path | None) -> None:
    if path is None:
        return
    path.parent.mkdir(parents=True, exist_ok=True)


def main() -> None:
    args = parse_args()
    mip_sizes = parse_mip_sizes(args.mip_sizes)

    source = Path(args.source)
    output = Path(args.output)
    backup = Path(args.backup) if args.backup else None
    preview = Path(args.preview) if args.preview else None

    if not source.exists():
        raise FileNotFoundError(f"Source image not found: {source}")

    if backup is not None:
        ensure_parent(backup)
        shutil.copy2(source, backup)

    image = Image.open(source).convert("RGBA")
    subject = prepare_subject(image, args.canvas_size, mip_sizes, args.allow_existing_strip)
    base_icon = fit_subject(subject, args.canvas_size, args.fit_size)
    strip = build_strip(base_icon, mip_sizes)

    ensure_parent(output)
    strip.save(output)

    if preview is not None:
        ensure_parent(preview)
        base_icon.save(preview)

    print(f"source={source}")
    print(f"output={output}")
    print(f"output_size={strip.size}")
    if backup is not None:
        print(f"backup={backup}")
    if preview is not None:
        print(f"preview={preview}")


if __name__ == "__main__":
    main()
