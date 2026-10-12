"""Generate inexpensive, lossless native-layout diagnostics; never render models."""
import argparse
import hashlib
import json
from pathlib import Path

from PIL import Image, ImageDraw

STATES = ["folded", "preparing", "prepared", "starting-attack", "attacking",
          "ending-attack", "rotate-for-folding", "folding"]
SEQUENCES = {"parked": [1], "running": [2],
             "preparing": [1, *range(3, 13), 2], "folding": [2, *range(13, 29), 1]}
W, H, C, D, N = 64, 32, 7, 8, 28
SHADOW_CASES = [
    ("empty", 0, 0, 0, False), ("b64", 64, 0, 0, False),
    ("b128", 128, 0, 0, False), ("b192", 192, 0, 0, False),
    ("u64", 0, 64, 0, False), ("u128", 0, 128, 0, False),
    ("u192", 0, 192, 0, False), ("b64-u192", 64, 192, 0, False),
    ("b128-u128", 128, 128, 0, False), ("triple", 64, 128, 192, False),
    ("triple-reversed", 64, 128, 192, True),
    ("u64-r192", 0, 64, 192, False), ("u64-r192-reversed", 0, 64, 192, True),
    ("control64", 64, 0, 0, False), ("control128", 128, 0, 0, False),
    ("control192", 192, 0, 0, False), ("control208", 208, 0, 0, False),
    ("control232", 232, 0, 0, False), ("control255", 255, 0, 0, False),
]


def barcode(draw, value, count, y):
    for bit in range(count):
        x = 4 + bit * 7
        draw.rectangle((x, y, x + 4, y + 5), fill="white" if value & (1 << bit) else "black")


def cell(direction, physical_pose, upper=False):
    tile = Image.new("RGBA", (W, H), (28, 82, 110, 255))
    draw = ImageDraw.Draw(tile)
    barcode(draw, direction, 8, 4)
    barcode(draw, physical_pose, 5, 17)
    draw.text((43, 19), "U" if upper else str(physical_pose), fill="white")
    return tile


def location(direction, pose):
    q = (direction % D) * N + pose - 1
    return direction // D, (q % C) * W, (q // C) * H


def build(destination):
    destination.mkdir(parents=True, exist_ok=True)
    files = []

    def save(name, image):
        path = destination / name
        image.save(path, optimize=True)
        files.append({"name": name, "size": list(image.size), "bytes": path.stat().st_size,
                      "sha256": hashlib.sha256(path.read_bytes()).hexdigest()})

    for chunk in range(256 // D):
        sheet = Image.new("RGBA", (C * W, (N // C) * D * H))
        for direction in range(chunk * D, (chunk + 1) * D):
            for pose in range(1, N + 1):
                file_index, x, y = location(direction, pose)
                assert file_index == chunk
                sheet.paste(cell(direction, pose), (x, y))
        save(f"rotor-{chunk:02d}.png", sheet)
    upper = Image.new("RGBA", (16 * W, 16 * H))
    for direction in range(256):
        upper.paste(cell(direction, 0, upper=True), ((direction % 16) * W, (direction // 16) * H))
    save("upper.png", upper)
    base = Image.new("RGBA", (64, 16), (160, 65, 35, 255))
    ImageDraw.Draw(base).text((4, 2), "FIXED BASE", fill="white")
    save("base.png", base)
    for index, state in enumerate(STATES):
        marker = Image.new("RGBA", (64, 16), (45, 80 + index * 15, 45, 255))
        barcode(ImageDraw.Draw(marker), index, 3, 4)
        ImageDraw.Draw(marker).text((28, 2), str(index), fill="white")
        save(f"state-{index}.png", marker)
    for alpha in (0, 64, 128, 192, 208, 232, 255):
        save(f"alpha-{alpha}.png", Image.new("RGBA", (32, 32), (0, 0, 0, alpha)))
    save("blank.png", Image.new("RGBA", (1, 1)))
    save("background.png", Image.new("RGBA", (96, 96), (180, 180, 180, 255)))
    manifest = {"schema": 1, "physical_frame_count": N, "direction_count": 256,
                "instrumentation": {"shell_particles_disabled": True,
                    "shell_particle_scope": "disposable candidate and legacy clones only",
                    "ammo_source_observer_added": True, "damage_delivery_unchanged": True,
                    "production_and_firing_fixture_shells_unchanged": True},
                "width": W, "height": H, "slice": C, "line_length": C,
                "directions_per_file": D, "lines_per_file": 32, "states": STATES,
                "sequences": SEQUENCES, "shadow_cases": SHADOW_CASES, "files": files,
                "status": "diagnostic_files_generated_native_execution_pending"}
    (destination / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    return manifest


def self_check():
    assert len(SEQUENCES["preparing"]) == 12 and len(SEQUENCES["folding"]) == 18
    assert set(sum(SEQUENCES.values(), [])) == set(range(1, 29))
    coordinates = {location(d, p) for d in range(256) for p in range(1, 29)}
    assert len(coordinates) == 256 * 28
    assert location(7, 28) == (0, 384, 992)
    assert location(8, 1) == (1, 0, 0)
    assert location(255, 28) == (31, 384, 992)
    for d, p in ((0, 1), (7, 28), (8, 1), (255, 28)):
        image = cell(d, p)
        for value, count, y in ((d, 8, 6), (p, 5, 19)):
            decoded = sum((image.getpixel((6 + bit * 7, y))[0] > 127) << bit for bit in range(count))
            assert decoded == value


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    self_check()
    if args.output:
        manifest = build(args.output)
        print(json.dumps({"output": str(args.output), "files": len(manifest["files"]),
                          "bytes": sum(x["bytes"] for x in manifest["files"]),
                          "static_atlas_checks": "passed"}))
    else:
        print(json.dumps({"static_atlas_checks": "passed"}))
