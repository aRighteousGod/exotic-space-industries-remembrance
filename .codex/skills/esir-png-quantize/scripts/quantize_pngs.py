"""Stage shared-palette PNG derivatives; never overwrite source artwork."""
from __future__ import annotations

import argparse
import io
import sys
from importlib.metadata import version
from pathlib import Path

import numpy as np
import PIL
from PIL import Image

from png_common import (atomic_bytes, canonical, check_output, color_metadata, digest,
                        load_spec, read_json, require, sha, verify_sources,
                        with_color_metadata, write_json)


def dependencies(tool_path=None):
    if tool_path:
        sys.path.insert(0, str(Path(tool_path).resolve()))
    global lib, ffi
    from imagequant import lib, ffi
    require(version("imagequant") == "1.1.5" and lib.liq_version() == 21501,
            "Use imagequant==1.1.5 with bundled libimagequant 2.15.1")
    return {"imagequant": version("imagequant"), "libimagequant": lib.liq_version(),
            "pillow": PIL.__version__, "numpy": np.__version__, "python": sys.version.split()[0]}


def rgba(path):
    with Image.open(path) as image:
        return np.asarray(image.convert("RGBA"))


def endpoints(job, rows):
    result = {"transparent": False, "opaque": False, "visible": False}
    for row in rows:
        alpha = rgba(job["source"] / row["path"])[:, :, 3]
        result["transparent"] |= bool(np.any(alpha == 0))
        result["opaque"] |= bool(np.any(alpha == 255))
        result["visible"] |= bool(np.any(alpha > 0))
    return result


def samples(job, row, opaque_only=False):
    array = rgba(job["source"] / row["path"])
    width, height = row["cell"]
    for y in range(0, array.shape[0], height):
        for x in range(0, array.shape[1], width):
            cell = array[y:y + height, x:x + width].reshape(-1, 4)
            visible = cell[cell[:, 3] == 255] if opaque_only else cell[cell[:, 3] > 0]
            limit = row["samples_per_cell"]
            if limit != "all" and len(visible) > limit:
                visible = visible[np.linspace(0, len(visible) - 1, limit, dtype=int)]
            yield visible


def check_liq(status, operation):
    require(status == lib.LIQ_OK, f"libimagequant {operation} failed ({status})")


def train(job, rows, fixed=(), opaque_only=False, max_colors=256):
    attr = lib.liq_attr_create()
    hist = result = None
    stats = {"cells": 0, "visible_samples": 0}
    try:
        check_liq(lib.liq_set_max_colors(attr, max_colors), "max colors")
        check_liq(lib.liq_set_speed(attr, 4), "speed")
        hist = lib.liq_histogram_create(attr)
        for color in fixed:
            value = ffi.new("liq_color *", dict(zip(("r", "g", "b", "a"), map(int, color))))
            check_liq(lib.liq_histogram_add_fixed_color(hist, value[0], 0), "fixed color")
        for row in rows:
            for cell in samples(job, row, opaque_only):
                stats["cells"] += 1
                stats["visible_samples"] += len(cell)
                # Exact-length rows avoid introducing transparent padding samples.
                for start in range(0, len(cell), 16384):
                    part = cell[start:start + 16384]
                    raw = part.tobytes()
                    image = lib.liq_image_create_rgba(attr, raw, len(part), 1, 0)
                    require(image != ffi.NULL, "Could not allocate training image")
                    try:
                        check_liq(lib.liq_histogram_add_image(hist, attr, image), "training image")
                    finally:
                        lib.liq_image_destroy(image)
        require(stats["visible_samples"] > 0, "No visible training samples")
        pointer = ffi.new("liq_result **")
        check_liq(lib.liq_histogram_quantize(hist, attr, pointer), "training")
        result = pointer[0]
        palette = lib.liq_get_palette(result)
        colors = [[c.r, c.g, c.b, c.a] for c in palette.entries][:palette.count]
        return colors, stats
    finally:
        if result is not None:
            lib.liq_result_destroy(result)
        if hist is not None:
            lib.liq_histogram_destroy(hist)
        lib.liq_attr_destroy(attr)


def train_group(job, rows):
    alpha = endpoints(job, rows)
    if not alpha["visible"]:
        return {"palette": [[0, 0, 0, 0]], "alpha": alpha, "training": {"cells": sum((r["size"][0] // r["cell"][0]) * (r["size"][1] // r["cell"][1]) for r in rows), "visible_samples": 0}, "opaque_fallback": False}
    fixed = [[0, 0, 0, 0]] if alpha["transparent"] else []
    palette, stats = train(job, rows, fixed)
    fallback = alpha["opaque"] and not any(c[3] == 255 for c in palette)
    if fallback:
        opaque, _ = train(job, rows, opaque_only=True, max_colors=32)
        require(all(c[3] == 255 for c in opaque), "Opaque training produced nonopaque colors")
        palette, stats = train(job, rows, fixed + opaque)
    # A translucent-only source must not gain opaque pixels through palette fitting.
    if not alpha["opaque"]:
        palette = [[r, g, b, min(a, 254)] for r, g, b, a in palette]
    palette = [list(c) for c in dict.fromkeys(map(tuple, palette))]
    require(not alpha["opaque"] or any(c[3] == 255 for c in palette), "No opaque palette entry")
    require(not alpha["transparent"] or any(c[3] == 0 for c in palette), "No transparent palette entry")
    return {"palette": palette, "alpha": alpha, "training": stats, "opaque_fallback": bool(fallback)}


class Quantizer:
    """Fixed RGBA palette with constrained endpoint remapping and explicit lifetime."""

    def __init__(self, palette):
        self.palette = np.array(palette, dtype=np.uint8)
        self.attr = self.result = None
        self.zero = next((i for i, c in enumerate(palette) if c[3] == 0), None)
        opaque = np.flatnonzero(self.palette[:, 3] == 255)
        self.opaque_map = self.opaque_palette = None
        if len(opaque):
            self.opaque_map = np.resize(opaque, 256)
            self.opaque_palette = Image.new("P", (1, 1))
            self.opaque_palette.putpalette(self.palette[self.opaque_map, :3].flatten().tolist())
        if len(palette) == 1:
            return
        hist = image = None
        try:
            self.attr = lib.liq_attr_create()
            check_liq(lib.liq_set_max_colors(self.attr, len(palette)), "fixed max colors")
            check_liq(lib.liq_set_speed(self.attr, 4), "fixed speed")
            hist = lib.liq_histogram_create(self.attr)
            for color in palette:
                value = ffi.new("liq_color *", dict(zip(("r", "g", "b", "a"), map(int, color))))
                check_liq(lib.liq_histogram_add_fixed_color(hist, value[0], 0), "palette color")
            raw = self.palette.tobytes()
            image = lib.liq_image_create_rgba(self.attr, raw, len(palette), 1, 0)
            check_liq(lib.liq_histogram_add_image(hist, self.attr, image), "palette swatch")
            pointer = ffi.new("liq_result **")
            check_liq(lib.liq_histogram_quantize(hist, self.attr, pointer), "fixed palette")
            self.result = pointer[0]
            check_liq(lib.liq_set_dithering_level(self.result, 0), "disable dithering")
            actual = lib.liq_get_palette(self.result)
            actual = [(c.r, c.g, c.b, c.a) for c in actual.entries][:actual.count]
            positions = {tuple(c): i for i, c in enumerate(palette)}
            require(set(actual) == set(positions), "Fixed palette changed")
            self.indices = np.array([positions[c] for c in actual], dtype=np.uint8)
        except Exception:
            self.close()
            raise
        finally:
            if image is not None:
                lib.liq_image_destroy(image)
            if hist is not None:
                lib.liq_histogram_destroy(hist)

    def close(self):
        if self.result is not None:
            lib.liq_result_destroy(self.result)
            self.result = None
        if self.attr is not None:
            lib.liq_attr_destroy(self.attr)
            self.attr = None

    def convert(self, original):
        array = np.asarray(original)
        if len(self.palette) == 1:
            ids = np.zeros(array.shape[:2], dtype=np.uint8)
        else:
            raw = original.tobytes()
            source = lib.liq_image_create_rgba(self.attr, raw, original.width, original.height, 0)
            require(source != ffi.NULL, "Could not allocate remap image")
            try:
                buf = ffi.new("char[]", original.width * original.height)
                check_liq(lib.liq_write_remapped_image(self.result, source, buf, original.width * original.height), "remap")
                ids = self.indices[np.frombuffer(ffi.buffer(buf), dtype=np.uint8).reshape(array.shape[:2])]
            finally:
                lib.liq_image_destroy(source)
        alpha = array[:, :, 3]
        if np.any(alpha == 0):
            require(self.zero is not None, "Missing transparent entry")
            ids[alpha == 0] = self.zero
        bad = (alpha == 255) & (self.palette[ids, 3] != 255)
        if np.any(bad):
            require(self.opaque_palette is not None, "Missing opaque entries")
            nearest = np.asarray(original.convert("RGB").quantize(palette=self.opaque_palette, dither=Image.Dither.NONE))
            ids[bad] = self.opaque_map[nearest[bad]]
        result = Image.frombytes("P", original.size, ids.tobytes())
        result.putpalette(self.palette[:, :3].flatten().tolist())
        result.info["transparency"] = self.palette[:, 3].tobytes()
        return result


def encode(candidate, metadata):
    decoded = candidate.convert("RGBA").tobytes()
    variants = []
    for level in (6, 9):
        stream = io.BytesIO()
        candidate.save(stream, format="PNG", compress_level=level)
        variants.append(with_color_metadata(stream.getvalue(), metadata))
    data = min(variants, key=len)
    with Image.open(io.BytesIO(data)) as image:
        require(image.mode == "P" and image.size == candidate.size and image.convert("RGBA").tobytes() == decoded, "Lossless post-compression changed candidate pixels")
    require(color_metadata(data)[0] == metadata, "Color metadata changed")
    return data, sha(decoded)


def run(spec, output, resume=False, dry_run=False, tool_path=None):
    job = load_spec(spec)
    out = check_output(job, output)
    require(not out.exists() or out.is_dir(), "Output must be a directory")
    if dry_run:
        return {"dry_run": True, "source_root": str(job["source"]), "output": str(out),
                "files": len(job["files"]), "groups": [g["name"] for g in job["spec"].get("groups", [])],
                "source_bytes": sum(r["bytes"] for r in job["files"].values())}
    versions = dependencies(tool_path)
    scripts = {name: digest(Path(__file__).with_name(name)) for name in ("quantize_pngs.py", "png_common.py")}
    contract = {"schema": "esir.png-quantize.source.v1", "spec_sha256": job["spec_sha256"],
                "source_root": str(job["source"]), "scripts": scripts, "versions": versions,
                "files": job["files"], "max_colors": 256, "dithering": 0,
                "alpha_policy": "preserve_0_and_255; quantize_intermediate", "compression_levels": [6, 9]}
    source_contract = out / "source-contract.json"
    if resume:
        require(source_contract.is_file(), "No source contract to resume")
        require(read_json(source_contract) == contract, "Resume inputs/tools changed; choose a new output directory")
    else:
        require(not out.exists() or not any(out.iterdir()), "Output is not empty; use --resume or a new directory")
    group_names = [g["name"] for g in job["spec"].get("groups", [])]
    allowed = {"source-contract.json", "conversion-report.json"}
    for name in group_names:
        allowed.update({f"palettes/{name}.json", f"palettes/{name}.contract.json"})
    for rel in job["files"]:
        allowed.update({"assets/" + rel, "receipts/" + sha(rel.encode()) + ".json"})
    if out.exists():
        for path in out.rglob("*"):
            require(path.resolve().is_relative_to(out), "Output contains an escaping link")
            if path.is_file():
                rel = path.relative_to(out).as_posix()
                require(rel in allowed or rel.endswith(".partial") and rel[:-8] in allowed,
                        "Unexpected output file: " + rel)
    if not resume:
        write_json(source_contract, contract)
    contract_hash = sha(canonical(contract))
    palettes, group_contracts = {}, {}
    # Validate all existing palettes before converting any more files.
    for name in group_names:
        path = out / "palettes" / (name + ".json")
        lock = out / "palettes" / (name + ".contract.json")
        rows = [r for r in job["files"].values() if r["group"] == name]
        if lock.exists():
            require(path.is_file(), "Frozen palette missing")
            saved = read_json(lock)
            require(saved == {"source_contract_sha256": contract_hash, "palette_sha256": digest(path)}, "Frozen palette changed; choose a new output directory")
            palettes[name] = read_json(path)
            group_contracts[name] = sha(canonical(saved))
        else:
            # An interruption between palette and lock writes retrains deterministically.
            trained = train_group(job, rows)
            if path.exists():
                require(read_json(path) == trained, "Unsealed palette differs from deterministic training")
            else:
                write_json(path, trained)
            saved = {"source_contract_sha256": contract_hash, "palette_sha256": digest(path)}
            write_json(lock, saved)
            palettes[name] = trained
            group_contracts[name] = sha(canonical(saved))
    records = []
    # Process one group at a time so CFFI palettes cannot accumulate across a batch.
    for name in [*group_names, None]:
        quantizer = Quantizer(palettes[name]["palette"]) if name is not None else None
        try:
            for rel, row in job["files"].items():
                if row["group"] != name:
                    continue
                target = out / "assets" / rel
                receipt = out / "receipts" / (sha(rel.encode()) + ".json")
                pin = group_contracts[name] if name is not None else contract_hash
                if receipt.exists():
                    saved = read_json(receipt)
                    require(saved["contract_sha256"] == pin and saved["source_sha256"] == row["sha256"] and target.is_file() and digest(target) == saved["sha256"], "Invalid completed receipt: " + rel)
                    records.append(saved)
                    continue
                source = job["source"] / rel
                payload = source.read_bytes()
                require(sha(payload) == row["sha256"], "Source changed: " + rel)
                saved = {"path": rel, "group": name, "source_sha256": row["sha256"], "source_bytes": len(payload), "size": row["size"], "contract_sha256": pin}
                if quantizer is None:
                    data = payload
                    saved.update(mode=row["mode"], unchanged=True)
                else:
                    with Image.open(io.BytesIO(payload)) as image:
                        original = image.convert("RGBA")
                    candidate = quantizer.convert(original)
                    data, decoded_hash = encode(candidate, row["color_chunks"])
                    before, after = np.asarray(original), np.asarray(candidate.convert("RGBA"))
                    alpha = before[:, :, 3]
                    require(np.all(after[:, :, 3][alpha == 0] == 0) and np.all(after[:, :, 3][alpha == 255] == 255), "Alpha endpoint changed")
                    saved.update(mode="P", palette_entries=len(quantizer.palette), alpha_endpoints_exact=True,
                                 intermediate_alpha_changes=int(np.count_nonzero(before[:, :, 3] != after[:, :, 3])),
                                 visible_rgb_changes=int(np.count_nonzero(np.any(before[:, :, :3] != after[:, :, :3], axis=2) & (alpha > 0))),
                                 decoded_rgba_sha256=decoded_hash, lossless_postprocess_verified=True)
                atomic_bytes(target, data)
                saved.update(sha256=sha(data), bytes=len(data))
                write_json(receipt, saved)
                records.append(saved)
                print(f"{len(records)}/{len(job['files'])}: {rel} ({len(data)} bytes)", flush=True)
        finally:
            if quantizer is not None:
                quantizer.close()
    verify_sources(job)
    report = {"schema": "esir.png-quantize.report.v1", "complete": True,
              "source_contract_sha256": contract_hash, "palette_contracts": group_contracts,
              "original_pixel_equality_claim": False, "texture_memory_savings_claim": False,
              "artifacts": records, "source_bytes": sum(r["source_bytes"] for r in records),
              "output_bytes": sum(r["bytes"] for r in records)}
    write_json(out / "conversion-report.json", report)
    return {k: v for k, v in report.items() if k != "artifacts"}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--spec", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--resume", action="store_true")
    parser.add_argument("--tool-path", type=Path, help="Existing task-local pip --target directory")
    args = parser.parse_args()
    try:
        result = run(args.spec, args.output, args.resume, args.dry_run, args.tool_path)
    except (ValueError, OSError, ImportError) as error:
        parser.exit(2, f"error: {error}\n")
    import json
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
