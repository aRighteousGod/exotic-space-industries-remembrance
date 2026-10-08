"""Compare64/128 heading quantization using the same real Meshy17 source frames.

Sprite simulation at scale1.25/zoom1. No engine capture, re-render, model edit,
different source asset, or change to the approved crystal glow is involved.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path

from PIL import Image, ImageDraw


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--bundle", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    manifest = json.loads((args.bundle / "factorio-preset-render-manifest.json").read_text())
    assert manifest["directions"] == 128
    scale = manifest["preflight"]["anisetron_sprite_scale"]
    assert scale == 1.25
    side = 512
    pivot = (210, 360)
    raw_size = round(512 * scale)
    left, top = round(pivot[0] - raw_size / 2), round(pivot[1] - raw_size / 2)
    base = Image.new("RGBA", (side, side), (20, 22, 24, 255))
    draw = ImageDraw.Draw(base)
    for value in range(0, side, 32):
        draw.line((value, 32, value, side - 26), fill=(29, 31, 33, 255))
        draw.line((0, value, side, value), fill=(29, 31, 33, 255))
    cache, source_hashes = {}, {}
    def sprite(index):
        if index not in cache:
            image = base.copy()
            for role, folder, y in (("shadow", "Shadow", top),
                                    ("body", "Object", round(top - 1.8 * 32)),
                                    ("glow", "Light A Reduced", round(top - 1.8 * 32))):
                path = args.bundle / folder / f"{index+1:04d}.png"
                source_hashes[str(path)] = sha(path)
                layer = Image.open(path).convert("RGBA").resize((raw_size, raw_size), Image.Resampling.BILINEAR)
                image.alpha_composite(layer, (left, y))
            cache[index] = image.convert("RGB")
        return cache[index]
    frames = []
    selected = (1, 31, 63, 95)
    board = Image.new("RGB", (1024, 512 * len(selected)), "#141618")
    for index in range(128):
        coarse = (math.floor(index / 2 + .5) * 2) % 128
        frame = Image.new("RGB", (1024, 512))
        frame.paste(sprite(coarse), (0, 0))
        frame.paste(sprite(index), (512, 0))
        overlay = ImageDraw.Draw(frame)
        overlay.rectangle((0, 0, 1024, 35), fill="#141618")
        overlay.text((14, 10), f"64 directions   source frame {coarse:03d}", fill="white")
        overlay.text((526, 10), f"128 directions   source frame {index:03d}", fill="white")
        overlay.rectangle((0, 486, 1024, 512), fill="#141618")
        overlay.text((14, 494), "SIMULATION / same Meshy17 frames / normal scale1.25, zoom1 /32px tiles", fill="white")
        frames.append(frame)
        if index in selected:
            board.paste(frame, (0, selected.index(index) * 512))
    args.output.mkdir(parents=True, exist_ok=True)
    path = args.output / "64-vs-128-normal-zoom.webp"
    frames[0].save(path, format="WEBP", save_all=True, append_images=frames[1:],
                   duration=50, loop=0, quality=86, method=2)
    board_path = args.output / "64-vs-128-normal-zoom-board.png"
    board.save(board_path)
    poster = args.output / "64-vs-128-normal-zoom-poster.png"
    frames[33].save(poster)
    encoded = Image.open(path)
    assert encoded.n_frames == 128 and encoded.size == (1024, 512) and encoded.info.get("loop") == 0
    assert path.stat().st_size <= 10_000_000
    duration = 0
    for index in range(encoded.n_frames):
        encoded.seek(index)
        encoded.load()
        duration += encoded.info.get("duration", 0)
    assert duration == 6400
    report = {"kind": "simulated64-versus128-heading-quantization", "engine_capture": False,
              "source_render_directions": 128, "canvas": [1024, 512], "scale": scale, "zoom": 1,
              "tile_pixels": 32, "static_hover_tiles": 1.8, "bob": None,
              "64_mapping": "floor(index/2+.5)*2 modulo128; even source frames only",
              "128_mapping": "actual source index0..127", "duration_ms": duration,
              "source_render_manifest_sha256": sha(args.bundle / "factorio-preset-render-manifest.json"),
              "source_hashes": source_hashes, "outputs": {str(path): sha(path), str(board_path): sha(board_path), str(poster): sha(poster)},
              "bytes": path.stat().st_size,
              "scope": "Same approved source pixels and natural sprite size in both columns; illustrates heading cadence, not native animation, lighting or performance."}
    (args.output / "comparison-manifest.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"webp": str(path), "bytes": path.stat().st_size, "frames": 128, "duration_ms": duration}))


if __name__ == "__main__":
    main()
