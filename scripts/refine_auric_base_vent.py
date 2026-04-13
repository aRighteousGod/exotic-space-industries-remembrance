from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image, ImageChops, ImageEnhance, ImageFilter


def odd_size(value: int) -> int:
    return value if value % 2 == 1 else value + 1


def build_refined_alpha(alpha: Image.Image, threshold: int, erode_passes: int, blur_radius: float) -> tuple[Image.Image, Image.Image]:
    # Start from a hard silhouette so we only shave the outer contour.
    binary = alpha.point(lambda a: 255 if a > threshold else 0, mode="L")

    eroded = binary
    for _ in range(erode_passes):
        eroded = eroded.filter(ImageFilter.MinFilter(3))

    feathered = eroded.filter(ImageFilter.GaussianBlur(blur_radius))
    refined_alpha = ImageChops.multiply(alpha, feathered)
    return binary, refined_alpha


def build_edge_mask(binary: Image.Image, refined_alpha: Image.Image, core_expand: int, blur_radius: float) -> Image.Image:
    core_mask = binary
    if core_expand > 0:
        core_mask = core_mask.filter(ImageFilter.MaxFilter(odd_size(core_expand * 2 + 1)))
    core_mask = core_mask.filter(ImageFilter.GaussianBlur(max(1.0, blur_radius * 1.5)))

    edge_mask = ImageChops.multiply(refined_alpha, ImageChops.invert(core_mask))
    return edge_mask.filter(ImageFilter.GaussianBlur(max(1.0, blur_radius)))


def refine_image(
    image: Image.Image,
    threshold: int,
    erode_passes: int,
    blur_radius: float,
    core_expand: int,
    edge_brightness: float,
    edge_saturation: float,
) -> Image.Image:
    rgba = image.convert("RGBA")
    alpha = rgba.getchannel("A")

    binary, refined_alpha = build_refined_alpha(alpha, threshold, erode_passes, blur_radius)
    edge_mask = build_edge_mask(binary, refined_alpha, core_expand, blur_radius)

    base_rgb = rgba.convert("RGB")
    edge_rgb = ImageEnhance.Brightness(base_rgb).enhance(edge_brightness)
    edge_rgb = ImageEnhance.Color(edge_rgb).enhance(edge_saturation)

    refined_rgb = Image.composite(edge_rgb, base_rgb, edge_mask)
    result = refined_rgb.convert("RGBA")
    result.putalpha(refined_alpha)
    return result


def build_preview(before: Image.Image, after: Image.Image) -> Image.Image:
    before_rgba = before.convert("RGBA")
    after_rgba = after.convert("RGBA")
    preview = Image.new("RGBA", (before_rgba.width * 2, before_rgba.height), (0, 0, 0, 0))
    preview.paste(before_rgba, (0, 0))
    preview.paste(after_rgba, (before_rgba.width, 0))
    return preview


def main() -> None:
    parser = argparse.ArgumentParser(description="Manual perimeter refinement for the auric base vent sprite.")
    parser.add_argument("input", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--preview", type=Path)
    parser.add_argument("--threshold", type=int, default=12)
    parser.add_argument("--erode-passes", type=int, default=3)
    parser.add_argument("--blur-radius", type=float, default=2.2)
    parser.add_argument("--core-expand", type=int, default=12)
    parser.add_argument("--edge-brightness", type=float, default=0.9)
    parser.add_argument("--edge-saturation", type=float, default=0.78)
    args = parser.parse_args()

    source = Image.open(args.input)
    refined = refine_image(
        source,
        threshold=args.threshold,
        erode_passes=args.erode_passes,
        blur_radius=args.blur_radius,
        core_expand=args.core_expand,
        edge_brightness=args.edge_brightness,
        edge_saturation=args.edge_saturation,
    )

    args.output.parent.mkdir(parents=True, exist_ok=True)
    refined.save(args.output)

    if args.preview:
        args.preview.parent.mkdir(parents=True, exist_ok=True)
        preview = build_preview(source, refined)
        preview.save(args.preview)


if __name__ == "__main__":
    main()
