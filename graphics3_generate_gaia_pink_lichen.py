from __future__ import annotations

import colorsys
from dataclasses import dataclass
from pathlib import Path

from PIL import Image


REPO_ROOT = Path(__file__).resolve().parent
BASE_LICHEN_DIR = Path(
    r"C:\Program Files (x86)\Steam\steamapps\common\Factorio\data\base\graphics\decorative\lichen-decal"
)
GAIA_DECORATIVE_DIR = (
    REPO_ROOT
    / "exotic-space-industries-remembrance-graphics-3"
    / "graphics"
    / "decorative"
    / "gaia"
)


@dataclass(frozen=True)
class PinkProfile:
    folder_name: str
    target_rgb: tuple[int, int, int]
    hue_blend: float
    target_sat_weight: float
    source_sat_weight: float
    shadow_start: float
    shadow_end: float
    color_mix: float


PROFILES = (
    PinkProfile(
        folder_name="meadow-pink-lichen-decal",
        target_rgb=(169, 145, 160),
        hue_blend=0.58,
        target_sat_weight=0.36,
        source_sat_weight=0.20,
        shadow_start=0.24,
        shadow_end=0.76,
        color_mix=0.36,
    ),
    PinkProfile(
        folder_name="wet-pink-lichen-decal",
        target_rgb=(145, 151, 182),
        hue_blend=0.62,
        target_sat_weight=0.40,
        source_sat_weight=0.18,
        shadow_start=0.26,
        shadow_end=0.78,
        color_mix=0.34,
    ),
)


def clamp(value: float, low: float, high: float) -> float:
    return max(low, min(high, value))


def smoothstep(edge0: float, edge1: float, value: float) -> float:
    if edge0 == edge1:
        return 1.0 if value >= edge1 else 0.0
    scaled = clamp((value - edge0) / (edge1 - edge0), 0.0, 1.0)
    return scaled * scaled * (3.0 - 2.0 * scaled)


def srgb_to_linear(channel: float) -> float:
    if channel <= 0.04045:
        return channel / 12.92
    return ((channel + 0.055) / 1.055) ** 2.4


def linear_to_srgb(channel: float) -> float:
    if channel <= 0.0031308:
        return 12.92 * channel
    return 1.055 * (channel ** (1.0 / 2.4)) - 0.055


def rgb8_to_float(rgb: tuple[int, int, int]) -> tuple[float, float, float]:
    return tuple(channel / 255.0 for channel in rgb)


def float_to_rgb8(rgb: tuple[float, float, float]) -> tuple[int, int, int]:
    return tuple(int(round(clamp(channel, 0.0, 1.0) * 255.0)) for channel in rgb)


def rgb_to_linear(rgb: tuple[float, float, float]) -> tuple[float, float, float]:
    return tuple(srgb_to_linear(channel) for channel in rgb)


def linear_to_rgb(rgb: tuple[float, float, float]) -> tuple[float, float, float]:
    return tuple(clamp(linear_to_srgb(channel), 0.0, 1.0) for channel in rgb)


def luminance(linear_rgb: tuple[float, float, float]) -> float:
    red, green, blue = linear_rgb
    return 0.2126 * red + 0.7152 * green + 0.0722 * blue


def lerp_angle(start: float, end: float, amount: float) -> float:
    delta = ((end - start + 0.5) % 1.0) - 0.5
    return (start + delta * amount) % 1.0


def recolor_pixel(
    source_rgb8: tuple[int, int, int],
    source_alpha: int,
    profile: PinkProfile,
    target_hsv: tuple[float, float, float],
) -> tuple[int, int, int, int]:
    if source_alpha == 0:
        return 0, 0, 0, 0

    source_rgb = rgb8_to_float(source_rgb8)
    source_h, source_s, source_v = colorsys.rgb_to_hsv(*source_rgb)
    source_linear = rgb_to_linear(source_rgb)
    source_y = luminance(source_linear)

    shadow_guard = smoothstep(profile.shadow_start, profile.shadow_end, source_y)
    tint_strength = 0.28 + 0.72 * shadow_guard
    new_h = lerp_angle(source_h, target_hsv[0], profile.hue_blend * tint_strength)
    new_s = clamp(
        source_s * profile.source_sat_weight
        + target_hsv[1] * profile.target_sat_weight * tint_strength,
        0.0,
        1.0,
    )

    candidate_rgb = colorsys.hsv_to_rgb(new_h, new_s, max(source_v, 0.02))
    candidate_linear = rgb_to_linear(candidate_rgb)
    candidate_y = max(luminance(candidate_linear), 1e-6)
    scale = source_y / candidate_y
    scaled_linear = tuple(channel * scale for channel in candidate_linear)
    peak = max(scaled_linear)
    if peak > 1.0:
        scaled_linear = tuple(channel / peak for channel in scaled_linear)

    detail_gray = (source_y, source_y, source_y)
    highlight_guard = smoothstep(profile.shadow_start + 0.08, 0.92, source_y)
    color_visibility = 0.08 + profile.color_mix * highlight_guard
    final_linear = tuple(
        detail_gray[index] * (1.0 - color_visibility)
        + scaled_linear[index] * color_visibility
        for index in range(3)
    )

    output_rgb = linear_to_rgb(final_linear)
    return (*float_to_rgb8(output_rgb), source_alpha)


def regenerate_profile(profile: PinkProfile) -> None:
    target_hsv = colorsys.rgb_to_hsv(*rgb8_to_float(profile.target_rgb))
    output_dir = GAIA_DECORATIVE_DIR / profile.folder_name
    output_dir.mkdir(parents=True, exist_ok=True)

    for source_path in sorted(BASE_LICHEN_DIR.glob("lichen-decal-*.png")):
        output_path = output_dir / source_path.name
        with Image.open(source_path).convert("RGBA") as image:
            pixels = image.load()
            for x in range(image.width):
                for y in range(image.height):
                    red, green, blue, alpha = pixels[x, y]
                    pixels[x, y] = recolor_pixel(
                        (red, green, blue), alpha, profile, target_hsv
                    )
            image.save(output_path)


def main() -> None:
    for profile in PROFILES:
        regenerate_profile(profile)
        print(f"Regenerated {profile.folder_name}")


if __name__ == "__main__":
    main()
