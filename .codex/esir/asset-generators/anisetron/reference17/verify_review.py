"""Verify review source hashes, image outputs and animation timing without rendering."""
import argparse
import hashlib
import json
from pathlib import Path

from PIL import Image


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def webp_durations(path):
    data = path.read_bytes()
    assert data[:4] == b"RIFF" and data[8:12] == b"WEBP"
    position, durations = 12, []
    while position + 8 <= len(data):
        tag = data[position:position + 4]
        length = int.from_bytes(data[position + 4:position + 8], "little")
        payload = position + 8
        if tag == b"ANMF":
            durations.append(int.from_bytes(data[payload + 12:payload + 15], "little"))
        position = payload + length + length % 2
    return durations


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, required=True)
    args = parser.parse_args()
    manifest_paths = (
        args.root / "engine-standard/preview-manifest.json",
        args.root / "fidelity-comparison/fidelity-comparison-manifest.json",
        args.root / "direction-resolution/comparison-manifest.json",
    )
    source_hashes, expected_outputs = {}, {}
    for path in manifest_paths:
        manifest = json.loads(path.read_text(encoding="utf-8"))
        for name, expected in manifest["source_hashes"].items():
            if name in source_hashes:
                assert source_hashes[name] == expected, name
            source_hashes[name] = expected
        for name, expected in manifest.get("outputs", {}).items():
            expected_outputs[name] = expected
        for item in manifest.get("results", []):
            if "sha256" in item:
                expected_outputs[item["output"]] = item["sha256"]
    for name, expected in source_hashes.items():
        assert sha(Path(name)) == expected, name
    for name, expected in expected_outputs.items():
        assert sha(Path(name)) == expected, name
    artifacts = []
    for folder in ("engine-standard", "fidelity-comparison", "direction-resolution"):
        for path in sorted((args.root / folder).iterdir()):
            if path.suffix.lower() not in (".png", ".gif", ".webp"):
                continue
            with Image.open(path) as im:
                count, dimensions = im.n_frames, list(im.size)
                durations = []
                if path.suffix == ".gif":
                    for index in range(count):
                        im.seek(index)
                        durations.append(im.info["duration"])
                    assert count == 24 and sum(durations) == 4800 and im.info["loop"] == 0
                elif path.suffix == ".webp":
                    durations = webp_durations(path)
                    assert count == len(durations) == 128 and sum(durations) == 6400
                    assert im.info["loop"] == 0
                im.verify() if count == 1 else None
            artifacts.append({"path": str(path), "sha256": sha(path), "bytes": path.stat().st_size,
                              "resolution": dimensions, "frames": count,
                              "duration_ms": sum(durations) if durations else None})
    report = {"kind": "reference17-review-integrity", "passed": True,
              "verified_source_hashes": len(source_hashes),
              "verified_manifest_output_hashes": len(expected_outputs),
              "manifest_sha256": {str(path): sha(path) for path in manifest_paths},
              "artifacts": artifacts,
              "scope": "Source hashes, output decodability, dimensions and animation timing; no new engine or model generation."}
    (args.root / "review-integrity.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"passed": True, "source_hashes": len(source_hashes), "artifacts": len(artifacts)}))


if __name__ == "__main__":
    main()
