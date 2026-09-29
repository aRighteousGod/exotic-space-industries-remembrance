"""Stage concentrated Prismatic Liturgy additions without touching legacy art.

Install beside production.py/generate.py for durable replay, or run this staged
copy from the repository root. Only --output is written; no shipping promotion.
Warning and impact sheets combine their core/shell cues in one semantic image.
"""
from __future__ import annotations

import argparse
import hashlib
import importlib
import json
import math
from pathlib import Path
import sys

import numpy as np
from PIL import Image, ImageDraw

sys.dont_write_bytecode = True
TAU = math.tau
SIZE = 256
COLUMNS = 6
WARNING_FRAMES = 30
IMPACT_FRAMES = 12
WARNING_RADIUS = .775
RATIOS = {"collapse": 1.5 / 4, "testament": 3 / 6}
OUTER_RADII = {"collapse": 4, "testament": 6, "echo": 5}


def load_sources(source_dir):
    sys.path.insert(0, str(source_dir.resolve()))
    return importlib.import_module("production"), importlib.import_module("generate")


def concentrated_collapse(study, testament, impact, t, size=SIZE):
    """Preserve the old animated material and add its exclusive damage core.

    The stationary boundary is a semantic cue, distinct from the shrinking clock.
    It is composited after study.collapse so Testament's opaque disk cannot hide it.
    """
    image = study.collapse(testament, impact, t, size)
    x, y, radius, angle = study.field(size)
    ratio = RATIOS["testament" if testament else "collapse"]
    core_radius = WARNING_RADIUS * ratio
    phase = t * TAU
    edge = radius - core_radius
    seam = np.exp(-(edge / .014) ** 2)
    cyan_edge = np.exp(-((edge + .017) / .012) ** 2)
    violet_edge = np.exp(-((edge - .017) / .012) ** 2)
    # Fixed circle, flowing color and hot fragments: shape survives Lean fidelity.
    caustic = .64 + .36 * np.sin(angle * 11 - phase * 2.5) ** 2
    fragments = (.5 + .5 * np.cos(angle * 7 - phase * 3)) ** 14
    alpha = np.maximum(seam * .96, (cyan_edge + violet_edge) * caustic * .83)
    rgb = study.spectrum(np.sin(angle * 2 + phase * .7), phase * .65)
    rgb = study.mix(rgb, (0, 231, 255), cyan_edge * .83)
    rgb = study.mix(rgb, (242, 43, 255), violet_edge * .78)
    rgb = study.mix(rgb, (255, 250, 211), seam * (.88 + .11 * fragments))
    pearls = np.exp(-(edge / .018) ** 2) * fragments
    alpha = np.maximum(alpha, pearls)
    if impact:
        # A hot crystalline center for Collapse; an annular crown for Testament.
        # The latter leaves the existing opaque aperture and cross fully legible.
        fade = (1 - t) ** 1.3
        if testament:
            rays = (.5 + .5 * np.cos(angle * 8 + radius * 33 - phase)) ** 12
            rays *= np.exp(-((radius - core_radius * .83) / .050) ** 2)
            alpha = np.maximum(alpha, rays * .96)
            rgb = study.mix(rgb, (255, 237, 226), rays * .82)
        else:
            petals = (.5 + .5 * np.cos(angle * 6 + radius * 38 - phase)) ** 8
            petals *= np.exp(-(radius / (core_radius * .88)) ** 6)
            contact = np.exp(-(radius / (core_radius * .46)) ** 4) * (1 - t) ** 3
            alpha = np.maximum(alpha, np.maximum(petals * .95, contact))
            rgb = study.mix(rgb, (255, 249, 215), np.maximum(petals * .60, contact))
        alpha *= fade
    # New material is central; this guard also makes finite-edge intent explicit.
    alpha *= np.clip((.98 - np.maximum(np.abs(x), np.abs(y))) / .08, 0, 1)
    image.alpha_composite(study.rgba(rgb, alpha))
    return image


def layer_over(canvas, core, center, radius, pixels_per_tile, production, bloom):
    # Same geometric mapping as prototype scale * runtime radius/reference scale.
    side = round(core.width * radius * pixels_per_tile / (SIZE / 2 * WARNING_RADIUS))
    position = (round(center[0] - side / 2), round(center[1] - side / 2))
    if bloom:
        canvas.alpha_composite(production.glow(core).resize((side, side), Image.Resampling.LANCZOS), position)
    canvas.alpha_composite(core.resize((side, side), Image.Resampling.LANCZOS), position)


def background(size, night, pixels_per_tile):
    color = (10, 15, 25) if night else (79, 89, 70)
    image = Image.new("RGBA", size, (*color, 255))
    draw = ImageDraw.Draw(image)
    grid = tuple(channel + (5 if night else 7) for channel in color)
    for x in range(0, size[0], pixels_per_tile):
        draw.line((x, 0, x, size[1]), fill=grid)
    for y in range(0, size[1], pixels_per_tile):
        draw.line((0, y, size[0], y), fill=grid)
    return image


def validate_sequence(study, key, frames, layers, core_ratio):
    hashes = {hashlib.sha256(frame.tobytes()).hexdigest() for frame in frames}
    assert len(hashes) == len(frames), (key, "duplicate frame")
    for suffix, images in layers.items():
        for index, image in enumerate(images):
            alpha = np.asarray(image)[..., 3]
            assert max(alpha[0].max(), alpha[-1].max(), alpha[:, 0].max(), alpha[:, -1].max()) <= 3, (key, suffix, index, "clipping")
    if key.endswith("warning"):
        _, _, radius, _ = study.field(SIZE)
        marker = np.abs(radius - WARNING_RADIUS * core_ratio) < .006
        # Mid/late frames exercise the marker after the outer ring crosses it.
        for index in [0, 14, 24, 29]:
            pixels = np.asarray(frames[index])
            assert (pixels[..., 3][marker] > 160).mean() > .85, (key, index, "core marker opacity")
            assert (pixels[..., :3].max(axis=2)[marker] > 180).mean() > .85, (key, index, "core marker hidden")


def make_previews(output, sequences, production, study):
    columns = [(False, False, "DAY / LEAN"), (False, True, "DAY / STANDARD"),
               (True, False, "NIGHT / LEAN"), (True, True, "NIGHT / STANDARD")]
    cell = (396, 422)
    board = Image.new("RGB", (cell[0] * 4, 60 + cell[1] * 4), (8, 13, 22))
    ImageDraw.Draw(board).text((18, 13), "PRISMATIC LITURGY / concentrated core and shell / 24 px per tile", font=study.font(25), fill="white")
    rows = [("collapse", "warning", 14), ("testament", "warning", 14),
            ("collapse", "impact", 0), ("testament", "impact", 0)]
    for row, (kind, part, index) in enumerate(rows):
        for column, (night, bloom, label) in enumerate(columns):
            panel = background(cell, night, 24)
            key = f"{kind}-concentrated-{part}"
            layer_over(panel, sequences[key][index], (198, 222), OUTER_RADII[kind], 24, production, bloom)
            draw = ImageDraw.Draw(panel)
            draw.text((12, 9), label, font=study.font(17), fill="white")
            draw.text((12, 36), f"{kind} / {part} / frame {index}", font=study.font(16), fill=(207, 222, 235))
            draw.text((12, 395), f"outer {OUTER_RADII[kind]} / inner {OUTER_RADII[kind] * RATIOS[kind]:g} tiles", font=study.font(16), fill="white")
            board.paste(panel.convert("RGB"), (column * cell[0], 60 + row * cell[1]))
    board.save(output / "hybrid-board.png")
    # Show overlap, not substitution: first impact continues over the echo warning.
    timeline = []
    for tick in range(72):
        image = Image.new("RGB", (1024, 616), (8, 13, 22))
        draw = ImageDraw.Draw(image)
        draw.text((18, 8), f"TESTAMENT / tick {tick:02d} / 4x slow motion / 16 px per tile", font=study.font(23), fill="white")
        for index, (night, bloom, label) in enumerate(columns):
            panel = background((512, 270), night, 16)
            center = (256, 142)
            if tick < 30:
                layer_over(panel, sequences["testament-concentrated-warning"][tick], center, 6, 16, production, bloom)
            else:
                if tick < 60:
                    echo = study.collapse(True, False, (tick - 30) / 29, SIZE)
                    layer_over(panel, echo, center, 5, 16, production, bloom)
                if tick < 42:
                    layer_over(panel, sequences["testament-concentrated-impact"][tick - 30], center, 6, 16, production, bloom)
                if tick >= 60:
                    echo = study.collapse(True, True, (tick - 60) / 11, SIZE)
                    layer_over(panel, echo, center, 5, 16, production, bloom)
            ImageDraw.Draw(panel).text((12, 8), label, font=study.font(17), fill="white")
            image.paste(panel.convert("RGB"), ((index % 2) * 512, 46 + (index // 2) * 270))
        draw.text((18, 591), "0-29: first warning   |   30: first damage + echo warning   |   60: echo damage", font=study.font(17), fill=(200, 219, 235))
        timeline.append(image)
    timeline[0].save(output / "hybrid-timeline.webp", save_all=True, append_images=timeline[1:],
                     duration=[67, 67, 66] * 24, loop=0, quality=90, method=4)
    for tick in [0, 14, 29, 30, 41, 59, 60, 65]:
        timeline[tick].save(output / f"timeline-tick-{tick:02d}.png")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=Path("output/meshy/lance-prismatic-liturgy/hybrid"))
    sibling = Path(__file__).resolve().parent
    default_sources = sibling if (sibling / "production.py").exists() else Path(".codex/esir/asset-generators/singularity-lance/prismatic-redesign")
    parser.add_argument("--source-dir", type=Path, default=default_sources)
    args = parser.parse_args()
    production, study = load_sources(args.source_dir)
    output = args.output
    export = output / "factorio-export"
    export.mkdir(parents=True, exist_ok=True)
    sequences, manifest = {}, {}
    atlas_bytes = 0
    for kind in ["collapse", "testament"]:
        for part, count in [("warning", WARNING_FRAMES), ("impact", IMPACT_FRAMES)]:
            key = f"{kind}-concentrated-{part}"
            frames = [concentrated_collapse(study, kind == "testament", part == "impact", i / (count - 1)) for i in range(count)]
            sequences[key] = frames
            layers = {"semantic": frames, "glow": [production.glow(frame) for frame in frames]}
            validate_sequence(study, key, frames, layers, RATIOS[kind])
            dimensions = (SIZE * COLUMNS, SIZE * math.ceil(count / COLUMNS))
            atlas_bytes += dimensions[0] * dimensions[1] * 4 * 2
            entries = []
            for role, images in layers.items():
                sheet = Image.new("RGBA", dimensions)
                for index, image in enumerate(images):
                    sheet.paste(image, ((index % COLUMNS) * SIZE, (index // COLUMNS) * SIZE))
                path = export / (key + ("-glow" if role == "glow" else "") + ".png")
                sheet.save(path)
                entries.append({"file": path.name, "role": role, "sha256": hashlib.sha256(path.read_bytes()).hexdigest()})
            manifest[key] = {"width": SIZE, "height": SIZE, "frames": count, "columns": COLUMNS,
                             "tile_x": False, "outer_radius": OUTER_RADII[kind], "core_ratio": RATIOS[kind],
                             "core_radius_pixels": SIZE / 2 * WARNING_RADIUS * RATIOS[kind], "layers": entries}
    make_previews(output, sequences, production, study)
    result = {"status": "passed", "sequences": manifest, "total_frames": 84, "shipping_pngs": 8,
              "rgba_atlas_bytes": atlas_bytes, "core_atlas_bytes": atlas_bytes // 2,
              "warning_reference_radius_pixels": SIZE / 2 * WARNING_RADIUS,
              "source": "hybrid.py + unchanged production.py/generate.py", "legacy_assets_written": False,
              "echo_aliases": {"echo-warning": "testament-warning", "echo-impact": "testament-impact"},
              "timeline": {"frames": 72, "first_impact_tick": 30, "echo_impact_tick": 60,
                           "preview_slowdown": 4, "gameplay_ticks_per_second": 60},
              "qa": ["unique semantic frames", "finite semantic/glow edges", "core marker opacity and visibility"]}
    (output / "manifest.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(f"{output}: 8 new PNGs / 84 frames / {atlas_bytes / 1024**2:.1f} MiB RGBA atlas; legacy assets untouched")


if __name__ == "__main__":
    main()
