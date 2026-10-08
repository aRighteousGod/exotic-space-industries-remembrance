"""Native768px viewing copies; only WebP compression differs from engine RGB."""
import argparse
import hashlib
import json
from pathlib import Path

from PIL import Image


parser = argparse.ArgumentParser()
parser.add_argument("--report", type=Path, required=True)
args = parser.parse_args()
report = json.loads(args.report.read_text(encoding="utf-8"))
for kind, sequence in report["sequences"].items():
    frames = [Image.open(row["path"]).convert("RGB") for row in sequence["frames"]]
    durations = [round((i + 1) * 1000 / 30) - round(i * 1000 / 30) for i in range(len(frames))]
    target = args.report.parent / f"{kind}-viewing-2x-slow.webp"
    for quality in (82, 72, 62):
        frames[0].save(target, save_all=True, append_images=frames[1:], duration=durations,
                       loop=0, lossless=False, quality=quality, method=4)
        if target.stat().st_size <= 10_000_000:
            break
    assert target.stat().st_size <= 10_000_000, target
    with Image.open(target) as playback:
        assert playback.size == (768, 768)
        assert playback.n_frames == len(frames)
        for i in range(playback.n_frames):
            playback.seek(i)
            playback.load()
    sequence["viewing_preview"] = {"path": str(target.resolve()), "bytes": target.stat().st_size,
        "sha256": hashlib.sha256(target.read_bytes()).hexdigest(), "size": [768, 768],
        "frames": len(frames), "duration_ms": sum(durations), "quality": quality,
        "encoding": "Lossy WebP viewing preview; native768px original frames at2x slow motion; no recoloring, brightness adjustment or image interpolation"}
    print(json.dumps({kind: sequence["viewing_preview"]}), flush=True)
args.report.write_text(json.dumps(report, indent=2), encoding="utf-8")
