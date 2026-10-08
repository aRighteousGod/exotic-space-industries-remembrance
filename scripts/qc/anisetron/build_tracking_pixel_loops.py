"""Lossless native-capture loops and conservative beam pixel evidence.

This packages original screenshot pixels; it applies no tint, brightness,
resampling, interpolation, recoloring, or generated imagery. Timing is 2x slow.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw


KINDS = ("lethal-dense", "facade-lethal-dense", "tracking-dense", "turning-dense")


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def project(point, camera):
    return np.array(((point["x"] - camera["position"]["x"]) * 32 + 384,
                     (point["y"] - camera["position"]["y"]) * 32 + 384))


def corridor(points, origin, target):
    delta = target - origin
    length = float(np.linalg.norm(delta))
    if length < 1:
        return np.zeros(len(points), dtype=bool)
    offset = points - origin
    along = offset @ delta / length
    across = np.abs(offset[:, 0] * delta[1] - offset[:, 1] * delta[0]) / length
    # Omit muzzle/impact sprites. Native hover/bob makes the approximate source
    # uncertain; this is a broad corridor presence check, not origin alignment.
    return (across <= 16) & (along >= 80) & (along <= length - 20)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    source, output = args.source.resolve(), args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    captures = json.loads((source / "captures.json").read_text(encoding="utf-8-sig"))
    metadata = {x["path"]: x for x in captures["frames"]}
    traces = json.loads((source / "trace.json").read_text(encoding="utf-8-sig"))
    trace = {(x["actor"], x["tick"]): x for x in traces}
    report = {"source": str(source), "source_capture_sha256": sha(source / "captures.json"),
              "source_trace_sha256": sha(source / "trace.json"),
              "rendering": "Unmodified 768x768 engine pixels, lossless animated WebP, 2x slow motion",
              "pixel_method": "RGB minimum >160 and maximum >210; broad 16px projected beam corridors excluding first80px and last20px",
              "limits": ["Bright-pixel evidence checks rendered presence, not damage or targeting correctness.",
                         "Overlapping channels are not independently identifiable where their projected corridors overlap.",
                         "The source offset uses base hover1.8 without unexposed native bob; this is not a muzzle alignment measurement.",
                         "Some endpoints fall outside the fixed 768px view.",
                         "The loop boundary jumps back to the first captured tick; each source sequence is otherwise consecutive."],
              "sequences": {}}
    for kind in KINDS:
        paths = sorted((source / kind).glob("*.png"))
        frames, records = [], []
        for path in paths:
            frame = Image.open(path).convert("RGB")
            assert frame.size == (768, 768), (path, frame.size)
            frames.append(frame)
            shot = metadata[f"anisetron-regression/{kind}/{path.name}"]
            current = trace[shot["actor"], shot["tick"]]
            rgb = np.asarray(frame)
            yy, xx = np.where((rgb.min(axis=2) > 160) & (rgb.max(axis=2) > 210))
            points = np.column_stack((xx, yy)).astype(float)
            masks = {}
            for emitter, channel in current["channels"].items():
                if not channel.get("beam") or not channel.get("endpoint"):
                    continue
                offset = channel["offset"]
                origin = project({"x": current["position"]["x"] + offset[0],
                                  "y": current["position"]["y"] + offset[1] - 1.8}, shot["camera"])
                target = project(channel["endpoint"], shot["camera"])
                masks[emitter] = corridor(points, origin, target)
            channels = {}
            for emitter, mask in masks.items():
                other = np.zeros(len(points), dtype=bool)
                for peer, peer_mask in masks.items():
                    if peer != emitter:
                        other |= peer_mask
                channels[emitter] = {"white_core_pixels_in_corridor": int(mask.sum()),
                                     "exclusive_corridor_pixels": int((mask & ~other).sum())}
            records.append({"path": str(path), "sha256": sha(path), "tick": shot["tick"],
                            "white_core_pixels": len(points), "channels": channels})
        ticks = [x["tick"] for x in records]
        assert all(b - a == 1 for a, b in zip(ticks, ticks[1:])), (kind, ticks)
        durations = [round((i + 1) * 1000 / 30) - round(i * 1000 / 30) for i in range(len(frames))]
        artifact = output / f"{kind}-native-2x-slow.webp"
        frames[0].save(artifact, save_all=True, append_images=frames[1:], duration=durations,
                       loop=0, lossless=True, quality=30, method=0)
        with Image.open(artifact) as replay:
            assert replay.n_frames == len(frames)
            exact = True
            for i, original in enumerate(frames):
                replay.seek(i)
                if not np.array_equal(np.asarray(replay.convert("RGB")), np.asarray(original)):
                    exact = False
                    break
            assert exact, artifact
        chosen = np.linspace(0, len(frames) - 1, 8, dtype=int)
        # A separate review board uses native-resolution crops, never resized.
        board = Image.new("RGB", (4 * 512, 2 * (512 + 30)), (20, 23, 25))
        draw = ImageDraw.Draw(board)
        for slot, index in enumerate(chosen):
            x, y = (slot % 4) * 512, (slot // 4) * 542
            board.paste(frames[index].crop((128, 0, 640, 512)), (x, y + 30))
            draw.text((x + 8, y + 8), f"{kind} | tick {ticks[index]} | native pixel crop", fill="white")
        board_path = output / f"{kind}-native-crops.png"
        board.save(board_path)
        expected = sum(len(x["channels"]) for x in records)
        measured = [ch["white_core_pixels_in_corridor"] for row in records for ch in row["channels"].values()]
        exclusive = [ch["exclusive_corridor_pixels"] for row in records for ch in row["channels"].values()]
        report["sequences"][kind] = {"frame_count": len(frames), "ticks": [ticks[0], ticks[-1]],
                                     "source_duration_ms": len(frames) * 1000 / 60,
                                     "playback_duration_ms": sum(durations), "playback": "2x slow motion; 30fps from consecutive60tick captures",
                                     "webp": str(artifact), "webp_bytes": artifact.stat().st_size,
                                     "webp_sha256": sha(artifact), "decoded_pixels_identical": exact,
                                     "board": str(board_path), "minimum_frame_white_pixels": min(x["white_core_pixels"] for x in records),
                                     "expected_channel_frames": expected,
                                     "channel_frames_with_corridor_pixels": sum(v >= 5 for v in measured),
                                     "channel_frames_with_exclusive_corridor_pixels": sum(v >= 5 for v in exclusive),
                                     "minimum_corridor_pixels": min(measured, default=0), "frames": records}
    report_path = output / "beam-capture-pixel-evidence.json"
    report_path.write_text(json.dumps(report, indent=2), encoding="utf-8")
    print(json.dumps({name: {k: v for k, v in value.items() if k != "frames"}
                      for name, value in report["sequences"].items()}, indent=2))


if __name__ == "__main__":
    main()
