"""Shared manifest, PNG metadata and receipt handling for staged derivatives."""
from __future__ import annotations

import hashlib
import json
import re
import struct
import zlib
from pathlib import Path, PurePosixPath

from PIL import Image

SIGNATURE = b"\x89PNG\r\n\x1a\n"
COLOR_CHUNKS = {b"sRGB", b"gAMA", b"cHRM", b"iCCP"}


def require(condition, message):
    if not condition:
        raise ValueError(message)


def sha(data):
    return hashlib.sha256(data).hexdigest()


def digest(path):
    return sha(Path(path).read_bytes())


def canonical(value):
    return json.dumps(value, sort_keys=True, separators=(",", ":")).encode("utf-8")


def read_json(path):
    return json.loads(Path(path).read_text(encoding="utf-8-sig"))


def atomic_bytes(path, data):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(path.name + ".partial")
    temporary.write_bytes(data)
    temporary.replace(path)


def write_json(path, value):
    atomic_bytes(path, (json.dumps(value, indent=2, ensure_ascii=False) + "\n").encode("utf-8"))


def png_chunks(data):
    require(data.startswith(SIGNATURE), "Input is not a PNG")
    pos = 8
    while pos < len(data):
        require(pos + 12 <= len(data), "Truncated PNG chunk")
        size = struct.unpack(">I", data[pos:pos + 4])[0]
        end = pos + size + 12
        require(end <= len(data), "Truncated PNG payload")
        tag, value = data[pos + 4:pos + 8], data[pos + 8:end - 4]
        require(zlib.crc32(tag + value) & 0xffffffff == struct.unpack(">I", data[end - 4:end])[0], "PNG CRC mismatch")
        yield tag, value
        pos = end
        if tag == b"IEND":
            require(pos == len(data), "Unexpected bytes after PNG end")
            return
    raise ValueError("PNG has no IEND")


def color_metadata(data):
    raw, interpretation = {}, {}
    for tag, value in png_chunks(data):
        if tag not in COLOR_CHUNKS:
            continue
        name = tag.decode("ascii")
        require(name not in raw, "Duplicate color metadata: " + name)
        raw[name] = value.hex()
        if tag == b"iCCP":
            label, separator, body = value.partition(b"\0")
            require(separator and 1 <= len(label) <= 79 and body[:1] == b"\0", "Invalid ICC chunk")
            profile = zlib.decompress(body[1:])
            require(len(profile) >= 128 and profile[36:40] == b"acsp", "Invalid ICC profile")
            interpretation[name] = profile.hex()
        else:
            expected = {b"sRGB": 1, b"gAMA": 4, b"cHRM": 32}[tag]
            require(len(value) == expected, "Invalid color metadata: " + name)
            interpretation[name] = value.hex()
    require(not ({"sRGB", "iCCP"} <= raw.keys()), "PNG contains both sRGB and ICC profiles")
    return raw, interpretation


def with_color_metadata(data, raw):
    result = bytearray(SIGNATURE)
    def append(tag, value):
        result.extend(struct.pack(">I", len(value)) + tag + value + struct.pack(">I", zlib.crc32(tag + value) & 0xffffffff))
    for tag, value in png_chunks(data):
        if tag in COLOR_CHUNKS:
            continue
        append(tag, value)
        if tag == b"IHDR":
            for name, payload in raw.items():
                append(name.encode("ascii"), bytes.fromhex(payload))
    return bytes(result)


def relative_path(value):
    require(isinstance(value, str) and value and "\\" not in value and ":" not in value, "Use forward-slash relative PNG paths")
    path = PurePosixPath(value)
    require(not path.is_absolute() and all(p not in ("", ".", "..") for p in value.split("/")), "Unsafe relative path: " + value)
    require(path.suffix.lower() == ".png", "Expected PNG path: " + value)
    # Windows aliases and ADS would make distinct manifest names overwrite one file.
    reserved = {"CON", "PRN", "AUX", "NUL", *(f"COM{i}" for i in range(1, 10)), *(f"LPT{i}" for i in range(1, 10))}
    require(all(not p.endswith((".", " ")) and not re.search(r'[<>"|?*\x00-\x1f]', p) and p.split(".")[0].upper() not in reserved for p in path.parts), "Unsupported filename: " + value)
    return value


def integer_pair(value, name, positive=True):
    require(isinstance(value, list) and len(value) == 2 and all(type(v) is int and (v > 0 if positive else True) for v in value), "Invalid " + name)
    return value


def overlaps(a, b):
    return a == b or a.is_relative_to(b) or b.is_relative_to(a)


def load_spec(path):
    path = Path(path).resolve()
    spec = read_json(path)
    require(isinstance(spec, dict), "Spec must be a JSON object")
    require(spec.get("version") == 1, "Expected spec version 1")
    require(isinstance(spec.get("source_root"), str), "Missing source_root")
    source = (path.parent / spec["source_root"]).resolve()
    require(source.is_dir(), "Missing source root: " + str(source))
    groups = spec.get("groups", [])
    require(isinstance(groups, list) and isinstance(spec.get("copy", []), list), "groups and copy must be arrays")
    files, names = {}, set()

    def add(entry, group, sample):
        entry = {"path": entry} if isinstance(entry, str) else entry
        require(isinstance(entry, dict), "Invalid file entry")
        rel = relative_path(entry.get("path"))
        require(rel.casefold() not in names, "Duplicate/conflicting output: " + rel)
        names.add(rel.casefold())
        src = (source / rel).resolve()
        require(src.is_relative_to(source) and src.is_file(), "Missing or escaping source: " + rel)
        data = src.read_bytes()
        chunk_list = list(png_chunks(data))
        require(chunk_list[0][0] == b"IHDR", "PNG must start with IHDR")
        require(not any(tag == b"acTL" for tag, _ in chunk_list), "APNG is unsupported: " + rel)
        raw, interpretation = color_metadata(data)
        with Image.open(src) as im:
            width, height = im.size
            mode = im.mode
            im.verify()
        if group is not None:
            bits, color_type = chunk_list[0][1][8:10]
            require((color_type in (2, 6) and bits == 8) or (color_type == 3 and bits in (1, 2, 4, 8)), "Quantize only 8-bit RGB/RGBA or indexed PNGs: " + rel)
            if "iCCP" in interpretation:
                require(bytes.fromhex(interpretation["iCCP"])[16:20] == b"RGB ", "Indexed output requires an RGB ICC profile: " + rel)
        cell = integer_pair(entry.get("cell", [width, height]), "cell")
        require(width % cell[0] == 0 and height % cell[1] == 0, "Cell does not divide atlas: " + rel)
        files[rel] = {"path": rel, "group": group, "cell": cell, "size": [width, height], "mode": mode,
                      "samples_per_cell": sample, "sha256": sha(data), "bytes": len(data),
                      "color_chunks": raw, "color_interpretation": interpretation}

    group_names = set()
    for group in groups:
        require(isinstance(group, dict), "Invalid palette group")
        name = group.get("name", "")
        require(isinstance(name, str) and re.fullmatch(r"[a-z0-9][a-z0-9_-]{0,63}", name), "Invalid palette group name")
        require(name.casefold() not in group_names, "Duplicate palette group")
        group_names.add(name.casefold())
        sample = group.get("samples_per_cell", 1600)
        require(sample == "all" or type(sample) is int and sample > 0, "samples_per_cell must be positive or all")
        require(isinstance(group.get("files"), list) and group["files"], "Palette group needs files")
        for entry in group["files"]:
            add(entry, name, sample)
        metadata = [f["color_interpretation"] for f in files.values() if f["group"] == name]
        require(all(m == metadata[0] for m in metadata), "Incompatible color metadata within group: " + name)
    for entry in spec.get("copy", []):
        add(entry, None, None)
    require(files, "Spec has no input files")
    previews = spec.get("previews", [])
    require(isinstance(previews, list), "previews must be an array")
    preview_names = set()
    for preview in previews:
        require(isinstance(preview, dict), "Preview must be an object")
        name = preview.get("name", "")
        require(isinstance(name, str) and re.fullmatch(r"[a-z0-9][a-z0-9_-]{0,63}", name) and name not in preview_names, "Invalid/duplicate preview name")
        preview_names.add(name)
        canvas = integer_pair(preview.get("canvas"), "preview canvas")
        require(isinstance(preview.get("frames"), list) and preview["frames"], "Preview requires frames")
        scale = preview.get("scale", 1)
        require(type(scale) in (int, float) and 0 < scale <= 8, "Preview scale must be >0 and <=8")
        for frame in preview["frames"]:
            require(isinstance(frame, dict), "Frame must be an object")
            require(type(frame.get("duration_ms", 100)) is int and 1 <= frame.get("duration_ms", 100) <= 60000, "Invalid frame duration")
            require(isinstance(frame.get("layers"), list) and frame["layers"], "Frame needs layers")
            for layer in frame["layers"]:
                require(isinstance(layer, dict), "Layer must be an object")
                rel = layer.get("path")
                require(rel in files, "Preview references undeclared file: " + str(rel))
                f = files[rel]
                count = (f["size"][0] // f["cell"][0]) * (f["size"][1] // f["cell"][1])
                require(type(layer.get("cell", 0)) is int and 0 <= layer.get("cell", 0) < count, "Preview cell outside atlas")
                x, y = integer_pair(layer.get("at", [0, 0]), "layer position", positive=False)
                require(x >= 0 and y >= 0 and x + f["cell"][0] <= canvas[0] and y + f["cell"][1] <= canvas[1], "Preview canvas clips a layer")
                opacity = layer.get("opacity", 1)
                require(type(opacity) in (int, float) and 0 <= opacity <= 1, "Invalid preview layer opacity")
    return {"spec": spec, "spec_sha256": digest(path), "source": source, "files": files, "path": path}


def check_output(job, output):
    output = Path(output).resolve()
    require(not overlaps(job["source"], output), "Source and output directories overlap")
    require(not job["path"].is_relative_to(output), "Keep the input spec outside the output directory")
    return output


def verify_sources(job):
    for rel, row in job["files"].items():
        require(digest(job["source"] / rel) == row["sha256"], "Source changed: " + rel)
