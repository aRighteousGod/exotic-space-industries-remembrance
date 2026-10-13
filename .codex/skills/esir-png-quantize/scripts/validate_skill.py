"""Focused offline conversion checks plus an optional small minigun example."""
from __future__ import annotations

import argparse
import copy
import io
import json
import struct
import sys
import zlib
from pathlib import Path
from unittest.mock import patch

import numpy as np
from PIL import Image, ImageCms

import compare_pngs
import quantize_pngs as quantize
from png_common import digest, read_json, require, with_color_metadata, write_json


def validate(output, tool_path, minigun_root=None, metadata_path=None):
    output = output.resolve()
    require(not output.exists(), "Choose a fresh validation output directory")
    source = output / "inputs"
    source.mkdir(parents=True)
    checks = []

    def checked(label, condition):
        require(condition, label)
        checks.append(label)

    def fails(label, operation):
        try:
            operation()
        except (ValueError, OSError):
            checks.append(label)
        else:
            raise ValueError("Expected rejection: " + label)

    x, y = np.meshgrid(np.arange(64), np.arange(48))
    base = np.stack(((x * 4) % 256, (y * 5) % 256, (x * 7 + y * 3) % 256, np.full_like(x, 255)), axis=2).astype(np.uint8)
    mixed = base.copy()
    mixed[:, :, 3] = ((x * 13 + y * 7) % 256).astype(np.uint8)
    mixed[0, 0, 3] = 0
    mixed[-1, -1, 3] = 255
    translucent = base.copy()
    translucent[:, :, 3] = 1 + ((x + y) % 253)
    rare = base.copy()
    rare[:, :, 3] = 80
    rare[20, 20, 3] = 255
    rare[-1, -1, 3] = 0
    images = {"opaque.png": base, "empty.png": np.zeros_like(base), "translucent.png": translucent,
              "mixed-a.png": mixed, "mixed-b.png": mixed[:, ::-1].copy(), "rare.png": rare}
    for name, array in images.items():
        Image.fromarray(array).save(source / name)
    Image.fromarray(base).convert("P", palette=Image.Palette.ADAPTIVE, colors=8).save(source / "indexed.png", bits=4)
    Image.fromarray(mixed).convert("LA").save(source / "shadow.png")
    profile = ImageCms.ImageCmsProfile(ImageCms.createProfile("sRGB")).tobytes()
    buffer = io.BytesIO()
    Image.fromarray(base).save(buffer, format="PNG")
    icc = {"iCCP": (b"test\0\0" + zlib.compress(profile)).hex()}
    (source / "icc.png").write_bytes(with_color_metadata(buffer.getvalue(), icc))
    alternate_icc = {"iCCP": (b"other-name\0\0" + zlib.compress(profile, 1)).hex()}
    (source / "icc-alternate.png").write_bytes(with_color_metadata(buffer.getvalue(), alternate_icc))
    color = {"sRGB": "00", "gAMA": struct.pack(">I", 45455).hex(),
             "cHRM": struct.pack(">8I", 31270, 32900, 64000, 33000, 30000, 60000, 15000, 6000).hex()}
    (source / "color.png").write_bytes(with_color_metadata(buffer.getvalue(), color))
    spec = {"version": 1, "source_root": "inputs", "groups": [
        {"name": name, "files": [name + ".png"]} for name in ("opaque", "empty", "translucent", "indexed", "icc", "color")],
        "copy": ["shadow.png"], "previews": [{"name": "layers", "canvas": [64, 48], "scale": 2,
          "frames": [{"duration_ms": 120, "layers": [{"path": "opaque.png"}, {"path": name}]} for name in ("mixed-a.png", "mixed-b.png")]}]}
    spec["groups"].append({"name": "mixed", "samples_per_cell": 200, "files": ["mixed-a.png", "mixed-b.png"]})
    spec["groups"].append({"name": "rare", "samples_per_cell": 1, "files": ["rare.png"]})
    next(g for g in spec["groups"] if g["name"] == "icc")["files"].append("icc-alternate.png")
    spec_path = output / "synthetic.json"
    write_json(spec_path, spec)
    baseline = {p.name: digest(p) for p in source.iterdir()}
    dry = output / "dry"
    quantize.run(spec_path, dry, dry_run=True)
    checked("dry-run does not create output", not dry.exists())
    converted = output / "converted"
    report = quantize.run(spec_path, converted, tool_path=tool_path)
    quantize.run(spec_path, converted, resume=True, tool_path=tool_path)
    checked("matching completed conversion resumes", True)
    records = read_json(converted / "conversion-report.json")["artifacts"]
    checked("byte totals match output files", report["output_bytes"] == sum((converted / "assets" / r["path"]).stat().st_size for r in records))
    checked("source files unchanged", baseline == {p.name: digest(p) for p in source.iterdir()})
    checked("protected shadow byte-identical", digest(source / "shadow.png") == digest(converted / "assets/shadow.png"))
    for name in images:
        before = np.asarray(Image.open(source / name).convert("RGBA"))
        after = np.asarray(Image.open(converted / "assets" / name).convert("RGBA"))
        checked(name + " exact alpha endpoints", bool(np.all(after[:, :, 3][before[:, :, 3] == 0] == 0) and np.all(after[:, :, 3][before[:, :, 3] == 255] == 255)))
    after = np.asarray(Image.open(converted / "assets/translucent.png").convert("RGBA"))
    checked("translucent-only art gains no opaque pixels", not np.any(after[:, :, 3] == 255))
    checked("transparent-only palette is one entry", len(read_json(converted / "palettes/empty.json")["palette"]) == 1)
    checked("opaque-only palette has no transparent entry", all(c[3] == 255 for c in read_json(converted / "palettes/opaque.json")["palette"]))
    checked("rare opaque endpoint triggers reserved-color fallback", read_json(converted / "palettes/rare.json")["opaque_fallback"])
    a = np.asarray(Image.open(converted / "assets/mixed-a.png").convert("RGBA"))
    b = np.asarray(Image.open(converted / "assets/mixed-b.png").convert("RGBA"))
    checked("shared colors map identically across files", np.array_equal(a, b[:, ::-1]))
    from png_common import color_metadata
    for name in ("icc.png", "icc-alternate.png", "color.png"):
        checked(name + " metadata preserved", color_metadata((source / name).read_bytes()) == color_metadata((converted / "assets" / name).read_bytes()))
    compare_pngs.run(spec_path, converted, output / "preview")
    checked("static and animated previews produced", (output / "preview/preview-layers.webp").is_file())

    # Simulate an interruption after an output and receipt have reached disk.
    interrupted = output / "interrupted"
    real_write = quantize.write_json
    triggered = [False]
    def stop_after_receipt(path, value):
        real_write(path, value)
        if Path(path).parent.name == "receipts" and not triggered[0]:
            triggered[0] = True
            raise OSError("Intentional fixture interruption")
    with patch.object(quantize, "write_json", stop_after_receipt):
        fails("interruption leaves resumable receipts", lambda: quantize.run(spec_path, interrupted, tool_path=tool_path))
    quantize.run(spec_path, interrupted, resume=True, tool_path=tool_path)
    checked("interrupted run equals fresh conversion", all(digest(interrupted / "assets" / r["path"]) == r["sha256"] for r in records))
    palette_path = interrupted / "palettes/mixed.json"
    old_palette = palette_path.read_bytes()
    palette_path.write_bytes(old_palette + b" ")
    fails("edited frozen palette rejected", lambda: quantize.run(spec_path, interrupted, resume=True, tool_path=tool_path))
    palette_path.write_bytes(old_palette)
    bad = interrupted / "unknown.txt"
    bad.write_text("unexpected", encoding="utf-8")
    fails("unexpected output file rejected", lambda: quantize.run(spec_path, interrupted, resume=True, tool_path=tool_path))
    bad.unlink()
    damaged = interrupted / "assets/opaque.png"
    saved_bytes = damaged.read_bytes()
    damaged.write_bytes(saved_bytes[:-1])
    fails("completed output corruption rejected", lambda: quantize.run(spec_path, interrupted, resume=True, tool_path=tool_path))
    damaged.write_bytes(saved_bytes)
    fails("source/output overlap rejected", lambda: quantize.run(spec_path, source / "nested", dry_run=True))
    fails("source nested in output rejected", lambda: quantize.run(spec_path, output, dry_run=True))
    for label, change in [
        ("duplicate names", lambda s: s["groups"][0]["files"].append("OPAQUE.png")),
        ("path traversal", lambda s: s["groups"][0].update(files=["../opaque.png"])),
        ("absolute paths", lambda s: s["groups"][0].update(files=["C:/opaque.png"])),
        ("nondivisible atlas cells", lambda s: s["groups"][0].update(files=[{"path": "opaque.png", "cell": [7, 7]}])),
        ("incompatible group profiles", lambda s: s["groups"][0].update(files=["opaque.png", "color.png"]))]:
        invalid = copy.deepcopy(spec)
        change(invalid)
        if label == "incompatible group profiles":
            invalid["groups"] = [invalid["groups"][0]]
            invalid.pop("previews")
        invalid_path = output / "invalid.json"
        write_json(invalid_path, invalid)
        fails(label + " rejected before writes", lambda: quantize.run(invalid_path, output / "invalid-output", tool_path=tool_path))
        checked(label + " created no output", not (output / "invalid-output").exists())
    source_file = source / "opaque.png"
    original = source_file.read_bytes()
    Image.new("RGBA", (64, 48), "red").save(source_file)
    fails("source change invalidates resume", lambda: quantize.run(spec_path, converted, resume=True, tool_path=tool_path))
    source_file.write_bytes(original)
    if minigun_root and metadata_path:
        minigun_example(output, tool_path, minigun_root, metadata_path)
        checks.append("small minigun example converted and compared")
    result = {"passed": True, "checks": checks, "check_count": len(checks), "versions": quantize.dependencies(tool_path),
              "no_factorio_launch": True, "shipping_files_modified": False}
    write_json(output / "validation-report.json", result)
    return result


def minigun_example(output, tool_path, root, metadata):
    """Crop one direction from existing HD atlases; this is a fixture, not production."""
    from functools import lru_cache
    profile = read_json(metadata)["profiles"]["hd"]
    fixture = output / "minigun-inputs"
    fixture.mkdir()
    originals = {}
    @lru_cache(maxsize=8)
    def atlas(rel):
        path = root / rel
        originals[rel] = digest(path)
        with Image.open(path) as im:
            return im.copy()
    def cell(leaf, direction, pose):
        count = leaf.get("frame_count", 1)
        index = direction * count + (pose if count > 1 else 0)
        columns = leaf["line_length"]
        if "filenames" in leaf:
            capacity = columns * leaf["lines_per_file"]
            filename = leaf["filenames"][index // capacity]
            index %= capacity
        else:
            filename = leaf["filename"]
        rel = filename.split("__/", 1)[1]
        w, h = leaf["width"], leaf["height"]
        x, y = index % columns * w, index // columns * h
        return atlas(rel).crop((x, y, x + w, y + h))
    leaves = [("base", profile["base"]), ("upper", profile["upper"])]
    leaves += [("rotor-" + str(i), leaf) for i, leaf in enumerate(profile["rotor"]["layers"])]
    leaves += [("shadow", profile["shadow"])]
    files, copies, placements = [], [], {}
    for name, leaf in leaves:
        w, h = leaf["width"], leaf["height"]
        count = leaf.get("frame_count", 1)
        columns = 7 if count > 1 else 1
        sheet = Image.new("LA" if name == "shadow" else "RGBA", (columns * w, ((count + columns - 1) // columns) * h))
        for pose in range(count):
            sheet.paste(cell(leaf, 0 if name == "base" else 96, pose), ((pose % columns) * w, (pose // columns) * h))
        filename = name + ".png"
        sheet.save(fixture / filename)
        entry = {"path": filename, "cell": [w, h]}
        (copies if name == "shadow" else files).append(entry)
        placements[name] = [round(leaf["shift"][0] * 64 - w / 2), round(leaf["shift"][1] * 64 - h / 2)]
    icon_rel = profile["item_icon"].split("__/", 1)[1]
    icon = root / icon_rel
    originals[icon_rel] = digest(icon)
    (fixture / "icon.png").write_bytes(icon.read_bytes())
    left = min(p[0] for p in placements.values()) - 16
    top = min(p[1] for p in placements.values()) - 16
    right = max(placements[n][0] + leaf["width"] for n, leaf in leaves) + 16
    bottom = max(placements[n][1] + leaf["height"] for n, leaf in leaves) + 16
    frames = []
    for pose in [0, *range(2, 12), 1]:
        layers = []
        for name, leaf in sorted(leaves, key=lambda item: item[0] != "shadow"):
            layer = {"path": name + ".png", "cell": pose if leaf.get("frame_count", 1) > 1 else 0,
                     "at": [placements[name][0] - left, placements[name][1] - top]}
            if name == "shadow":
                layer["opacity"] = 0.5
            layers.append(layer)
        frames.append({"duration_ms": 600 if pose in (0, 1) else 100, "layers": layers})
    spec = {"version": 1, "source_root": "minigun-inputs", "groups": [
        {"name": "entity", "files": files}, {"name": "icon", "samples_per_cell": "all", "files": ["icon.png"]}],
        "copy": copies, "previews": [{"name": "spin-up", "canvas": [right - left, bottom - top], "scale": 2, "frames": frames}]}
    spec_path = output / "minigun.json"
    write_json(spec_path, spec)
    quantize.run(spec_path, output / "minigun-converted", tool_path=tool_path)
    compare_pngs.run(spec_path, output / "minigun-converted", output / "minigun-preview")
    require(all(digest(root / rel) == value for rel, value in originals.items()), "Minigun source changed")
    write_json(output / "minigun-source-hashes.json", originals)


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--output", type=Path, required=True)
    p.add_argument("--tool-path", type=Path)
    p.add_argument("--minigun-root", type=Path)
    p.add_argument("--minigun-metadata", type=Path)
    args = p.parse_args()
    print(json.dumps(validate(args.output, args.tool_path, args.minigun_root, args.minigun_metadata), indent=2))


if __name__ == "__main__":
    main()
