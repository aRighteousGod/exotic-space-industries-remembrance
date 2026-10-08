"""Pair untouched normal-zoom engine captures into real-time WebP previews."""
import argparse
import hashlib
import json
from pathlib import Path

from PIL import Image, ImageDraw

parser = argparse.ArgumentParser()
parser.add_argument("--captures", type=Path, required=True)
parser.add_argument("--candidate", required=True)
parser.add_argument("--output", type=Path, required=True)
args = parser.parse_args()
args.output.mkdir(parents=True, exist_ok=True)
clips = {"start": (0, 180), "cruise": (660, 840), "stop-and-restart": (870, 1230),
         "turn45": (1320, 1590), "turn90": (1671, 1941), "turn180": (2022, 2292)}
report = {"candidate": args.candidate, "zoom": 1, "fps": 20, "clips": {}}
for name, (begin, end) in clips.items():
    frames = []
    for tick in range(begin, end + 1, 3):
        frames_at_tick = []
        for key in ("four-h0-e0", args.candidate):
            path = args.captures / key / f"{tick:04d}.png"
            with Image.open(path) as source:
                assert source.size == (512, 512)
                frames_at_tick.append(source.convert("RGB"))
        paired = Image.new("RGB", (1024, 540), (16, 20, 22))
        for i, frame in enumerate(frames_at_tick):
            paired.paste(frame, (i * 512, 28))
        draw = ImageDraw.Draw(paired)
        draw.text((12, 8), "FOUR LEGS / CURRENT BASELINE", fill="white")
        draw.text((524, 8), "TEN LEGS / NATIVE TRIAL", fill="white")
        frames.append(paired)
    path = args.output / f"{name}.webp"
    for quality in (82, 72, 62):
        frames[0].save(path, save_all=True, append_images=frames[1:], duration=50,
                       loop=0, quality=quality, method=4)
        if path.stat().st_size <= 10_000_000:
            break
    assert path.stat().st_size <= 10_000_000
    with Image.open(path) as playback:
        for i in range(playback.n_frames):
            playback.seek(i);playback.load()
    report["clips"][name] = {"path": str(path.resolve()), "bytes": path.stat().st_size,
        "frames": len(frames), "duration_ms": len(frames)*50,
        "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}
    print(name, path.stat().st_size, flush=True)
args.output.joinpath("previews.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
