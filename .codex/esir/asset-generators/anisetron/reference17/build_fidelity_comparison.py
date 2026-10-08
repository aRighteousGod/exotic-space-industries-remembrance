"""Compose matched Lean/Standard/Maximal native capture samples for review."""
import argparse
import hashlib
import json
from pathlib import Path

from PIL import Image, ImageDraw


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--tier", required=True, action="append", help="lean=ARTDIR, standard=ARTDIR or maximal=ARTDIR")
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    paths = dict(item.split("=", 1) for item in args.tier)
    assert set(paths) == {"lean", "standard", "maximal"}
    roots, hashes, manifests = {}, {}, {}
    for tier, value in paths.items():
        root = roots[tier] = Path(value)
        path = root / "capture-manifest.json"
        manifests[tier] = json.loads(path.read_text())
        assert manifests[tier]["fidelity"] == tier and manifests[tier]["channel_view"] == "all"
        assert manifests[tier]["direction_count"] == 128
        hashes[str(path)] = sha(path)
    for key in ("direction_camera", "ring_camera", "clips"):
        assert len({json.dumps(manifests[tier][key], sort_keys=True) for tier in roots}) == 1
    args.output.mkdir(parents=True, exist_ok=True)
    results = []
    for family, indices in (("ring", (1, 8, 16, 24)), ("motion", (1, 8, 16, 24))):
        for lighting in ("day", "night"):
            board = Image.new("RGB", (3 * 384, 4 * 408), "#111111")
            draw = ImageDraw.Draw(board)
            for column, tier in enumerate(("lean", "standard", "maximal")):
                for row, index in enumerate(indices):
                    shot = roots[tier] / f"{family}-{lighting}" / f"{index:03d}.png"
                    hashes[str(shot)] = sha(shot)
                    frame = Image.open(shot).convert("RGB").resize((384, 384), Image.Resampling.LANCZOS)
                    left, top = column * 384, row * 408
                    board.paste(frame, (left, top + 24))
                    draw.text((left + 6, top + 7), f"{tier.title()} / native {family}-{lighting} / {index:02d}", fill="white")
            path = args.output / f"fidelity-{family}-{lighting}.png"
            board.save(path)
            results.append({"family": family, "lighting": lighting, "sample_frames": list(indices),
                            "output": str(path), "sha256": sha(path)})
    report = {"kind": "native-fidelity-review-boards", "engine_capture": True,
              "tiers": paths, "matched_camera_and_clip_settings": True, "source_hashes": hashes,
              "results": results, "scope": "Matched captured pixels; visual comparison, not timing or performance measurement. Mechanical equivalence has its separate native report."}
    (args.output / "fidelity-comparison-manifest.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"boards": len(results), "output": str(args.output)}))


if __name__ == "__main__":
    main()
