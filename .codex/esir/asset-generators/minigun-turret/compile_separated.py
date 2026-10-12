"""Compile exact source-over layers from the separated minigun reference renders.

RGB at alpha zero is canonicalized for color decomposition. Every other code
value is preserved, including one-code changes. Corrections use only opaque
replacement or an empty underlay; difficult boundaries are promoted across the
complete state family, never approximated with a partially transparent residual.
"""
from __future__ import annotations

import argparse
import hashlib
import html
import io
import json
import math
import shutil
import struct
import uuid
from contextlib import contextmanager
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont, PngImagePlugin

from separated_contract import SCHEMA, SOURCE_SHA256, PILOT_DIRECTIONS, PARKED, RUNNING, SPIN_UP, SPIN_DOWN

PHYSICAL_POSES = 28
MAX_SHEET = 4096
G4_EXISTING_BYTES = 164243939
ARCHIVE_CAP_BYTES = 256000000


def canonical_rgba(array):
    result = array.copy()
    result[result[:, :, 3] == 0, :3] = 0
    return result


def changed(a, b):
    return np.any(a != b, axis=2)


def dilate(mask, radius):
    image = Image.fromarray(mask.astype(np.uint8) * 255)
    return np.asarray(image.filter(ImageFilter.MaxFilter(radius * 2 + 1))) != 0


def clear(array, mask):
    result = array.copy()
    result[mask] = 0
    return result


def promotion_needed(under, target):
    """Conservatively move every changed partial underlay to the upper owner."""
    alpha = under[:, :, 3]
    return changed(under, target) & (
        ((alpha > 0) & (alpha < 255)) | ((alpha == 255) & (target[:, :, 3] < 255))
    )


def overlay_exact(under, target, opaque_overlap=None):
    """A changed target is legal only over empty pixels or when fully opaque."""
    different = changed(under, target)
    legal = (under[:, :, 3] == 0) | (target[:, :, 3] == 255)
    impossible = different & ~legal
    if np.any(impossible):
        y, x = np.argwhere(impossible)[0]
        raise ValueError(f"Unpromoted alpha boundary at ({x}, {y}); {int(impossible.sum())} pixels")
    result = np.zeros_like(target)
    result[different] = target[different]
    if opaque_overlap is not None:
        overlap = opaque_overlap & (target[:, :, 3] == 255)
        result[overlap] = target[overlap]
    return result


def over(under, layer):
    # Pillow's independently implemented source-over also checks that the
    # compiler has not accidentally depended on a nonstandard blend operation.
    return np.asarray(Image.alpha_composite(Image.fromarray(under), Image.fromarray(layer))).copy()


def bounds(array):
    y, x = np.nonzero(array[:, :, 3])
    return None if not len(x) else (int(x.min()), int(y.min()), int(x.max() + 1), int(y.max() + 1))


def union_bounds(a, b):
    if a is None:
        return b
    if b is None:
        return a
    return min(a[0], b[0]), min(a[1], b[1]), max(a[2], b[2]), max(a[3], b[3])


def padded_crop(box, size, padding, alignment):
    if box is None:
        return (0, 0, alignment, alignment)
    left = math.floor((box[0] - padding) / alignment) * alignment
    top = math.floor((box[1] - padding) / alignment) * alignment
    right = math.ceil((box[2] + padding) / alignment) * alignment
    bottom = math.ceil((box[3] + padding) / alignment) * alignment
    if min(left, top) < 0 or right > size[0] or bottom > size[1]:
        raise ValueError(f"Reference lacks required transparent crop margin: {box}, padding={padding}")
    return left, top, right, bottom


def cut(array, box):
    return array[box[1]:box[3], box[0]:box[2]].copy()


def sha256_bytes(value):
    return hashlib.sha256(value).hexdigest()


def png_color_chunks(payload):
    if payload[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError("Expected PNG source data")
    result = {}
    offset = 8
    while offset + 12 <= len(payload):
        length = struct.unpack(">I", payload[offset:offset + 4])[0]
        kind = payload[offset + 4:offset + 8]
        end = offset + 8 + length
        if end + 4 > len(payload):
            raise ValueError("Truncated PNG chunk")
        if kind in (b"sRGB", b"gAMA", b"cHRM"):
            result[kind.decode("ascii")] = payload[offset + 8:end]
        offset = end + 4
        if kind == b"IEND":
            break
    return result


def png_info(color_chunks):
    result = PngImagePlugin.PngInfo()
    for name, payload in (color_chunks or {}).items():
        result.add(name.encode("ascii"), payload)
    return result


def mask_boundary(mask):
    eroded = np.asarray(Image.fromarray(mask.astype(np.uint8) * 255).filter(ImageFilter.MinFilter(3))) != 0
    return mask & ~eroded


def close_partial_boundary(under, mask, radius):
    """Move unsafe coverage edges out of the opaque correction overlap band.

    A 255-alpha texel next to transparent coverage also becomes translucent
    after bilinear filtering. Include that one-texel inner silhouette boundary,
    not just pixels whose stored alpha is already below 255.
    """
    alpha = under[:, :, 3]
    neighborhood_minimum = np.asarray(Image.fromarray(alpha).filter(ImageFilter.MinFilter(3)))
    partial = (alpha > 0) & (neighborhood_minimum < 255)
    result = mask.copy()
    iterations = 0
    while True:
        addition = dilate(result, radius) & partial & ~result
        if not np.any(addition):
            return result, iterations
        result |= addition
        iterations += 1


def fractional_filter_check(base, upper, rotor, reference):
    """Independent premultiplied bilinear diagnostic on ownership boundaries.

    Only neighborhoods with a varying layer alpha can violate source-over's
    center-pixel identity. Test them at all nine fractional x/y combinations.
    This uses encoded RGB code values; the engine remains the color authority.
    """
    arrays = (base, upper, rotor)
    mask = np.zeros((base.shape[0] - 1, base.shape[1] - 1), bool)
    for array in arrays:
        a = array[:, :, 3]
        mask |= (a[:-1, :-1] != a[:-1, 1:]) | (a[:-1, :-1] != a[1:, :-1]) | (a[:-1, :-1] != a[1:, 1:])
    report = {"neighborhoods": int(mask.sum()), "rgba_max_error": 0,
              "premultiplied_max_error": 0.0, "alpha_max_error": 0.0,
              "opaque_background_max_error": 0, "opaque_background_rms_error": 0.0, "opaque_background_values_over_one": 0}
    if not report["neighborhoods"]:
        return report

    def texels(array):
        result = np.stack((array[:-1, :-1][mask], array[:-1, 1:][mask], array[1:, :-1][mask], array[1:, 1:][mask]), axis=1).astype(np.float64)
        result[:, :, :3] *= result[:, :, 3:4] / 255
        return result

    def straight(premultiplied):
        result = premultiplied.copy()
        alpha = result[:, 3:4]
        np.divide(result[:, :3] * 255, alpha, out=result[:, :3], where=alpha > 0)
        result = np.clip(np.floor(result + .5), 0, 255).astype(np.int16)
        result[result[:, 3] == 0, :3] = 0
        return result

    layers = [texels(array) for array in arrays]
    expected = texels(reference)
    coordinates = np.argwhere(mask)
    for fx in (.25, .5, .75):
        for fy in (.25, .5, .75):
            weights = np.array([(1 - fx) * (1 - fy), fx * (1 - fy), (1 - fx) * fy, fx * fy])[None, :, None]
            result = np.zeros((report["neighborhoods"], 4), np.float64)
            for layer in layers:
                sample = (layer * weights).sum(axis=1)
                result = sample + result * (1 - sample[:, 3:4] / 255)
            target = (expected * weights).sum(axis=1)
            delta = np.abs(result - target)
            report["premultiplied_max_error"] = max(report["premultiplied_max_error"], float(delta.max()))
            alpha_error = float(delta[:, 3].max())
            if alpha_error > report["alpha_max_error"]:
                index = int(delta[:, 3].argmax())
                y, x = coordinates[index]
                report["worst_alpha_sample"] = {"xy": [int(x), int(y)], "fraction": [fx, fy],
                    "layer_corner_alpha": [layer[index, :, 3].tolist() for layer in layers],
                    "reference_corner_alpha": expected[index, :, 3].tolist(),
                    "actual_alpha": float(result[index, 3]), "reference_alpha": float(target[index, 3])}
            report["alpha_max_error"] = max(report["alpha_max_error"], alpha_error)
            report["rgba_max_error"] = max(report["rgba_max_error"], int(np.abs(straight(result) - straight(target)).max()))
            for background in (0, 128, 255):
                actual_rgb = np.floor(result[:, :3] + (1 - result[:, 3:4] / 255) * background + .5).astype(np.int16)
                target_rgb = np.floor(target[:, :3] + (1 - target[:, 3:4] / 255) * background + .5).astype(np.int16)
                difference = np.abs(actual_rgb - target_rgb)
                report["opaque_background_max_error"] = max(report["opaque_background_max_error"], int(difference.max()))
                rms = math.sqrt(float(np.square(difference.astype(np.float64)).sum()) / ((base.shape[0] - 1) * (base.shape[1] - 1) * 3))
                report["opaque_background_rms_error"] = max(report["opaque_background_rms_error"], rms)
                report["opaque_background_values_over_one"] += int(np.count_nonzero(difference > 1))
    for key in ("premultiplied_max_error", "alpha_max_error", "opaque_background_rms_error"):
        report[key] = round(report[key], 10)
    return report


@contextmanager
def packing_directory(output):
    # Python 3.13 TemporaryDirectory creates a restrictive Windows ACL that
    # excludes the workspace sandbox. An ordinary inherited-ACL directory is
    # both usable here and confined to this task's validated staging output.
    root = output.resolve()
    temporary = root / (".packing-" + uuid.uuid4().hex)
    temporary.mkdir()
    try:
        yield temporary
    finally:
        if temporary.resolve().parent != root or not temporary.name.startswith(".packing-"):
            raise ValueError("Refusing cleanup outside the task-owned packing directory")
        shutil.rmtree(temporary)


def encode_png(array, allow_la=False, color_chunks=None):
    """Choose only representations that decode to precisely the input RGBA."""
    original = Image.fromarray(array, "RGBA")
    candidates = [("RGBA", original)]
    if allow_la and np.array_equal(array[:, :, 0], array[:, :, 1]) and np.array_equal(array[:, :, 0], array[:, :, 2]):
        candidates.append(("LA", Image.fromarray(array[:, :, [0, 3]], "LA")))
    # This is an exact color table, not a quantizer. The cheap bounded count
    # avoids sorting millions of pixels when there are already >256 colors.
    if original.getcolors(256) is not None:
        packed = np.ascontiguousarray(array).view(np.uint32).reshape(-1)
        colors, indices = np.unique(packed, return_inverse=True)
        rgba = colors.view(np.uint8).reshape(-1, 4)
        indexed = Image.fromarray(indices.astype(np.uint8).reshape(array.shape[:2]), "P")
        palette = np.zeros((256, 3), dtype=np.uint8)
        palette[:len(rgba)] = rgba[:, :3]
        indexed.putpalette(palette.reshape(-1).tolist())
        indexed.info["transparency"] = bytes(rgba[:, 3])
        candidates.append(("P-exact", indexed))
    winner = None
    for mode, image in candidates:
        stream = io.BytesIO()
        image.save(stream, format="PNG", optimize=True, compress_level=9, pnginfo=png_info(color_chunks))
        payload = stream.getvalue()
        decoded = np.asarray(Image.open(io.BytesIO(payload)).convert("RGBA"))
        if not np.array_equal(decoded, array):
            raise AssertionError(f"PNG {mode} encoding changed decoded RGBA")
        if png_color_chunks(payload) != (color_chunks or {}):
            raise AssertionError(f"PNG {mode} encoding changed color-profile chunks")
        if winner is None or (len(payload), mode) < (len(winner[0]), winner[1]):
            winner = payload, mode
    return winner


class ReferenceReader:
    def __init__(self, root):
        self.root = root
        self.configuration = json.loads((root / "render-configuration.json").read_text(encoding="utf-8"))
        config = self.configuration
        if config["schema"] != SCHEMA or config["source_sha256"] != SOURCE_SHA256:
            raise ValueError("Unexpected source model or render schema")
        if config["density"] != 64 or config["resolution"] != [540, 540] or config["physical_poses"] != PHYSICAL_POSES:
            raise ValueError("Expected the 540px, 64px/tile, 28-pose master reference contract")
        self.records = {}
        for line in (root / "render-records.jsonl").read_text(encoding="utf-8").splitlines():
            row = json.loads(line)
            self.records[(row["family"], row["direction"], row["pose"], row["pass"])] = row
        self.sources = {}
        self.png_chunks = None

    def required(self, directions):
        jobs = [("base", 0, 0, "Object")]
        jobs += [("upper", d, 0, "Object") for d in directions]
        jobs += [("full", d, p, label) for d in directions for p in range(PHYSICAL_POSES) for label in ("Object", "Shadow")]
        missing = [job for job in jobs if job not in self.records or not self.path(*job).is_file()]
        if missing:
            raise ValueError(f"Incomplete reference family: {len(missing)} missing frames, first={missing[:6]}")

    def path(self, family, direction, pose, label):
        return self.root / "references" / family / label / f"d{direction:03}-p{pose:02}.png"

    def load(self, family, direction, pose, label, density):
        path = self.path(family, direction, pose, label)
        payload = path.read_bytes()
        digest = sha256_bytes(payload)
        profile = png_color_chunks(payload)
        if set(profile) != {"sRGB", "gAMA", "cHRM"}:
            raise ValueError(f"Reference lacks the expected sRGB/gAMA/cHRM color profile: {path}")
        if self.png_chunks is None:
            self.png_chunks = profile
        elif profile != self.png_chunks:
            raise ValueError(f"Mixed PNG color profiles in reference family: {path}")
        record = self.records[(family, direction, pose, label)]
        if record["configuration_hash"] != self.configuration["hash"] or record["sha256"] != digest:
            raise ValueError(f"Reference is incomplete, changed, or from a different configuration: {path}")
        image = Image.open(io.BytesIO(payload)).convert("RGBA")
        if image.size != (540, 540):
            raise ValueError(f"Unexpected frame dimensions: {path}")
        raw = np.asarray(image)
        hidden = int(np.count_nonzero((raw[:, :, 3] == 0) & np.any(raw[:, :, :3] != 0, axis=2)))
        key = path.relative_to(self.root).as_posix()
        self.sources[key] = {"sha256": digest, "bytes": len(payload), "hidden_rgb_pixels": hidden}
        if label == "Object":
            image = Image.fromarray(canonical_rgba(raw))
        if density == 32:
            # Decompose the actual low-density reference. Resizing separated
            # layers instead would change alpha coverage at mechanical seams.
            # Make Pillow's normal RGBA resize path explicit: premultiply RGB
            # by alpha, filter color and coverage, then unpremultiply. Filtering
            # straight RGB would let invisible source colors bleed into edges.
            image = image.convert("RGBa").resize((270, 270), Image.Resampling.LANCZOS).convert("RGBA")
        result = np.asarray(image).copy()
        return canonical_rgba(result) if label == "Object" else result


class DensityCompiler:
    def __init__(self, reader, directions, density):
        self.reader, self.directions, self.density = reader, directions, density
        self.size = 540 * density // 64
        self.radius = 8 * density // 64
        self.base_original = self.load("base", 0)
        self.base_clear = np.zeros((self.size, self.size), bool)
        self.rotor_clear = {}
        self.rotor_cover = {}
        self.boxes = dict.fromkeys(("base", "upper", "rotor", "shadow", "reference"))
        self.metrics = {"density": density, "directions": [], "maximum_rgba_error": 0, "differing_rgba_values": 0}
        self.metrics["fractional_filter"] = {"method": "premultiplied bilinear in encoded RGB code values; not native engine proof",
            "fractions_x_y": [.25, .5, .75], "opaque_backgrounds": [0, 128, 255],
            "rgba_max_error": 0, "premultiplied_max_error": 0.0, "alpha_max_error": 0.0,
            "opaque_background_max_error": 0, "opaque_background_rms_error": 0.0, "opaque_background_values_over_one": 0}
        self._cached_direction = None

    def load(self, family, direction, pose=0, label="Object"):
        return self.reader.load(family, direction, pose, label, self.density)

    def analyze(self):
        # First establish family-wide ownership. Clearing B globally wherever
        # any rotor family needs ownership makes the same fixed base safe at
        # every direction and throughout both native transition sequences.
        for direction in self.directions:
            upper = self.load("upper", direction)
            self.base_clear |= dilate(promotion_needed(self.base_original, upper), self.radius)
            promotion = np.zeros((self.size, self.size), bool)
            for pose in range(PHYSICAL_POSES):
                full = self.load("full", direction, pose)
                promotion |= promotion_needed(upper, full)
                self.boxes["reference"] = union_bounds(self.boxes["reference"], bounds(full))
                self.boxes["shadow"] = union_bounds(self.boxes["shadow"], bounds(self.load("full", direction, pose, "Shadow")))
            promotion, _ = close_partial_boundary(upper, dilate(promotion, self.radius), self.radius)
            self.rotor_clear[direction] = promotion
            self.rotor_cover[direction] = dilate(promotion, self.radius)
            self.base_clear |= promotion
            print(f"PROMOTION density={self.density} direction={direction:03} pixels={int(promotion.sum())}", flush=True)
        self.base_clear, base_closure_iterations = close_partial_boundary(self.base_original, self.base_clear, self.radius)
        self.base_cover = dilate(self.base_clear, self.radius)
        self.base = clear(self.base_original, self.base_clear)
        self.boxes["base"] = bounds(self.base)
        self.metrics["base_cleared_visible_pixels"] = int(np.count_nonzero(self.base_clear & (self.base_original[:, :, 3] > 0)))
        self.metrics["base_retained_visible_pixels"] = int(np.count_nonzero(self.base[:, :, 3]))
        self.metrics["base_clear_boundary_over_visible_reference_pixels"] = int(np.count_nonzero(mask_boundary(self.base_clear) & (self.base_original[:, :, 3] > 0)))
        self.metrics["base_partial_boundary_closure_iterations"] = base_closure_iterations
        self.metrics["ownership_strategy"] = "family-stable cleared regions plus wider opaque replacement collars; partial-alpha boundaries promoted to avoid double coverage; native fractional filtering gate required"
        for direction in self.directions:
            under, upper_layer = self.upper(direction)
            actual_under = over(self.base, upper_layer)
            if not np.array_equal(actual_under, under):
                raise AssertionError("Base/upper decomposition is not exact")
            self.boxes["upper"] = union_bounds(self.boxes["upper"], bounds(upper_layer))
            row = {"direction": direction, "promoted_pixels": int(self.rotor_clear[direction].sum()),
                   "maximum_rgba_error": 0, "differing_rgba_values": 0, "rotor_peak_visible_pixels": 0,
                   "rotor_peak_fraction_of_full": 0.0}
            upper_reference = self.load("upper", direction)
            row["promotion_boundary_over_opaque_upper_pixels"] = int(np.count_nonzero(mask_boundary(self.rotor_clear[direction]) & (upper_reference[:, :, 3] == 255)))
            for pose in range(PHYSICAL_POSES):
                full = self.load("full", direction, pose)
                rotor = overlay_exact(actual_under, full, self.rotor_cover[direction])
                result = over(actual_under, rotor)
                delta = np.abs(result.astype(np.int16) - full.astype(np.int16))
                error, count = int(delta.max()), int(np.count_nonzero(delta))
                if error != 0:
                    raise AssertionError(f"Reconstruction changed canonical RGBA: d={direction}, p={pose}, max={error}")
                row["maximum_rgba_error"] = max(row["maximum_rgba_error"], error)
                row["differing_rgba_values"] += count
                visible = int(np.count_nonzero(rotor[:, :, 3]))
                row["rotor_peak_visible_pixels"] = max(row["rotor_peak_visible_pixels"], visible)
                row["rotor_peak_fraction_of_full"] = max(row["rotor_peak_fraction_of_full"], visible / max(1, np.count_nonzero(full[:, :, 3])))
                self.boxes["rotor"] = union_bounds(self.boxes["rotor"], bounds(rotor))
                filtered = fractional_filter_check(self.base, upper_layer, rotor, full)
                for key in ("rgba_max_error", "premultiplied_max_error", "alpha_max_error", "opaque_background_max_error", "opaque_background_rms_error"):
                    self.metrics["fractional_filter"][key] = max(self.metrics["fractional_filter"][key], filtered[key])
                self.metrics["fractional_filter"]["opaque_background_values_over_one"] += filtered["opaque_background_values_over_one"]
                row.setdefault("fractional_filter_frames", []).append({"pose": pose, **filtered})
            self.metrics["directions"].append(row)
        alignment = 2 if self.density == 64 else 1
        self.crops = {name: padded_crop(box, (self.size, self.size), self.radius, alignment) for name, box in self.boxes.items()}
        return self

    def upper(self, direction):
        if self._cached_direction != direction:
            under = clear(self.load("upper", direction), self.rotor_clear[direction])
            self._cached_upper = under, overlay_exact(self.base, under, self.base_cover)
            self._cached_direction = direction
        return self._cached_upper

    def frame(self, family, direction=0, pose=0):
        if family == "base":
            return self.base
        if family == "upper":
            return self.upper(direction)[1]
        if family == "rotor":
            return overlay_exact(self.upper(direction)[0], self.load("full", direction, pose), self.rotor_cover[direction])
        if family == "reference":
            return self.load("full", direction, pose)
        return self.load("full", direction, pose, "Shadow")


def layout_candidates(width, height, poses, directions):
    """Maximize power-of-two directions/file; PNG bytes resolve equal capacity."""
    candidates = []
    if poses == 1:
        capacity = 1
        while capacity * 2 <= min(directions, (MAX_SHEET // width) * (MAX_SHEET // height)):
            capacity *= 2
        while capacity:
            candidates = [{"columns": columns, "rows": capacity // columns,
                           "directions_per_file": capacity, "rows_per_direction": None}
                          for columns in range(1, capacity + 1) if capacity % columns == 0
                          and width * columns <= MAX_SHEET and height * (capacity // columns) <= MAX_SHEET]
            if candidates:
                return candidates
            capacity //= 2
    else:
        for columns in range(1, poses + 1):
            if poses % columns or width * columns > MAX_SHEET:
                continue
            rows_per_direction = poses // columns
            capacity = 1
            maximum = min(directions, MAX_SHEET // (height * rows_per_direction))
            if not maximum:
                continue
            while capacity * 2 <= maximum:
                capacity *= 2
            candidates.append({"columns": columns, "rows": rows_per_direction * capacity,
                               "directions_per_file": capacity, "rows_per_direction": rows_per_direction})
        if candidates:
            most = max(row["directions_per_file"] for row in candidates)
            return [row for row in candidates if row["directions_per_file"] == most]
    raise ValueError(f"No <=4096 atlas arrangement for {width}x{height}, {poses} poses")


def pack_family(compiler, family, profile_root, temporary, *, crop=None, storage_name=None):
    crop = crop or compiler.crops[family]
    storage_name = storage_name or family
    width, height = crop[2] - crop[0], crop[3] - crop[1]
    directions = [0] if family == "base" else compiler.directions
    poses = PHYSICAL_POSES if family in ("rotor", "shadow", "reference") else 1
    candidates = layout_candidates(width, height, poses, len(directions))
    trials = []
    for layout in candidates:
        directory = temporary / f"{storage_name}-c{layout['columns']}"
        directory.mkdir()
        files = []
        for file_index, start in enumerate(range(0, len(directions), layout["directions_per_file"])):
            canvas = np.zeros((height * layout["rows"], width * layout["columns"], 4), np.uint8)
            for local_direction, direction in enumerate(directions[start:start + layout["directions_per_file"]]):
                for pose in range(poses):
                    index = local_direction * poses + pose
                    x, y = index % layout["columns"] * width, index // layout["columns"] * height
                    tile = cut(compiler.frame(family, direction, pose), crop)
                    canvas[y:y + height, x:x + width] = tile
            payload, mode = encode_png(canvas, allow_la=family == "shadow", color_chunks=compiler.reader.png_chunks)
            name = f"minigun-{storage_name}-{file_index:03}.png"
            (directory / name).write_bytes(payload)
            files.append({"name": name, "bytes": len(payload), "sha256": sha256_bytes(payload), "mode": mode,
                          "size": [canvas.shape[1], canvas.shape[0]], "decoded_rgba_bytes": int(canvas.size),
                          "decoded_rgba_sha256": sha256_bytes(canvas.tobytes()),
                          "decoded_rgba_exact": True})
        trials.append({"layout": layout, "bytes": sum(row["bytes"] for row in files), "files": files, "directory": directory})
    winner = min(trials, key=lambda row: (row["bytes"], -row["layout"]["columns"]))
    images = profile_root / "images"
    images.mkdir(parents=True, exist_ok=True)
    for row in winner["files"]:
        shutil.copyfile(winner["directory"] / row["name"], images / row["name"])
    layout = winner["layout"]
    anchor = compiler.reader.configuration["ground_anchor_pixels"]
    shift = [((crop[i] + crop[i + 2]) / 2 - anchor[i] * compiler.density / 64) / compiler.density for i in range(2)]
    leaf = {"width": width, "height": height, "frame_count": poses, "line_length": layout["columns"],
            "scale": 32 / compiler.density, "shift": shift}
    paths = ["images/" + row["name"] for row in winner["files"]]
    if len(paths) == 1:
        leaf["filename"] = paths[0]
    else:
        leaf.update(filenames=paths, slice=layout["columns"], lines_per_file=layout["rows"])
    if family != "base":
        leaf.update(direction_count=len(directions), apply_projection=True, counterclockwise=False)
    if family == "shadow":
        leaf["draw_as_shadow"] = True
    return {"leaf": leaf, "crop": list(crop), "master_crop": [v * 64 // compiler.density for v in crop],
            "alpha_bounds": compiler.boxes[family], "layout": layout, "files": winner["files"],
            "bytes": winner["bytes"], "decoded_rgba_bytes": sum(row["decoded_rgba_bytes"] for row in winner["files"]),
            "layout_trials": [{"layout": row["layout"], "bytes": row["bytes"]} for row in trials]}


def pack_rotor_strips(compiler, profile_root, temporary):
    """Four exact child rectangles; physical28 and the logical crop are unchanged.

    Each rectangle is packed directly from the original decomposed rotor. The
    rectangles tile its crop without overlap or omission. Atlas PNG decoding is
    checked by encode_png; the native fractional seam gate remains separate.
    """
    crop = compiler.crops["rotor"]
    width = crop[2] - crop[0]
    if width < 4:
        raise ValueError("Rotor crop cannot be divided into four nonempty strips")
    boundaries = [crop[0] + width * index // 4 for index in range(5)]
    children = []
    for index in range(4):
        child_crop = (boundaries[index], crop[1], boundaries[index + 1], crop[3])
        child = pack_family(compiler, "rotor", profile_root, temporary,
                            crop=child_crop, storage_name=f"rotor-strip-{index}")
        child["child_index"] = index
        child["source_pixel_rectangle"] = [child_crop[0] - crop[0], 0,
                                            child_crop[2] - crop[0], crop[3] - crop[1]]
        children.append(child)
    assert children[0]["crop"][0] == crop[0] and children[-1]["crop"][2] == crop[2]
    assert all(children[i]["crop"][2] == children[i + 1]["crop"][0] for i in range(3))
    return {"leaf": {"layers": [child["leaf"] for child in children]},
            "representation": "vertical_strips_4", "children": children,
            "crop": list(crop), "master_crop": [v * 64 // compiler.density for v in crop],
            "alpha_bounds": compiler.boxes["rotor"],
            "layout": {"representation": "spatial_children", "children": [
                {"child": child["child_index"], "source_pixel_rectangle": child["source_pixel_rectangle"],
                 "leaf": child["leaf"], "layout": child["layout"]} for child in children]},
            "files": [row for child in children for row in child["files"]],
            "bytes": sum(child["bytes"] for child in children),
            "decoded_rgba_bytes": sum(child["decoded_rgba_bytes"] for child in children),
            "layout_trials": [],
            "spatial_partition_proof": {"exact_disjoint_rectangle_cover": True,
                "logical_crop_unchanged": True, "mechanical_reference_unchanged": True,
                "child_count": 4, "physical_pose_count": PHYSICAL_POSES,
                "direction_count": len(compiler.directions),
                "decoded_png_rgba_exact": True, "native_filtering_tested": False}}


def font(size):
    for path in (Path("C:/Windows/Fonts/segoeui.ttf"), Path("C:/Windows/Fonts/arial.ttf")):
        if path.is_file():
            return ImageFont.truetype(str(path), size)
    return ImageFont.load_default()


def compile_icons(master, profile_root, density, expected_color_chunks=None):
    payload = master.read_bytes()
    color_chunks = png_color_chunks(payload)
    if set(color_chunks) != {"sRGB", "gAMA", "cHRM"} or (expected_color_chunks is not None and color_chunks != expected_color_chunks):
        raise ValueError("Icon source does not share the expected PNG color profile")
    image = Image.open(io.BytesIO(payload)).convert("RGBA")
    if image.size != (1024, 1024):
        raise ValueError("Expected the approved 1024px minigun icon master")
    report_path = master.with_name("icon-report.json")
    report = json.loads(report_path.read_text(encoding="utf-8"))
    if report["sha256"] != sha256_bytes(payload) or report["source_sha256"] != SOURCE_SHA256 or report["direction"] != 96:
        raise ValueError("Icon master does not match its approved source/direction report")
    image = Image.fromarray(canonical_rgba(np.asarray(image))).convert("RGBa")
    icons = {}
    for kind, size in (("item", 128 if density == 32 else 256), ("technology", 256 if density == 32 else 512)):
        resized = image.resize((size, size), Image.Resampling.LANCZOS).convert("RGBA")
        array = canonical_rgba(np.asarray(resized))
        encoded, mode = encode_png(array, color_chunks=color_chunks)
        name = f"minigun-{kind}.png"
        destination = profile_root / "images" / name
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_bytes(encoded)
        icons[kind] = {"path": "images/" + name, "size": size, "bytes": len(encoded), "mode": mode,
                       "sha256": sha256_bytes(encoded), "decoded_rgba_exact": True,
                       "native_ui_readability_tested": False}
    return icons


def backdrop(size):
    image = Image.new("RGBA", size, "#364249")
    draw = ImageDraw.Draw(image)
    for y in range(0, size[1], 16):
        for x in range(0, size[0], 16):
            if (x // 16 + y // 16) % 2:
                draw.rectangle((x, y, x + 15, y + 15), fill="#3f4c53")
    return image


def review_images(compiler, review_root):
    density = compiler.density
    cols = min(4, len(compiler.directions))
    rows = math.ceil(len(compiler.directions) / cols)
    tile_size, header = compiler.size, 30
    contact = Image.new("RGB", (cols * tile_size, rows * 2 * (tile_size + header)), "#19232a")
    draw = ImageDraw.Draw(contact)
    for index, direction in enumerate(compiler.directions):
        for pose in (0, 1):
            rotor = compiler.frame("rotor", direction, pose)
            reconstructed = over(over(compiler.base, compiler.frame("upper", direction)), rotor)
            shadow = Image.fromarray(compiler.frame("shadow", direction, pose))
            shadow.putalpha(shadow.getchannel("A").point(lambda a: round(a * .35)))
            image = Image.alpha_composite(Image.alpha_composite(backdrop((tile_size, tile_size)), shadow), Image.fromarray(reconstructed))
            x = index % cols * tile_size
            y = (index // cols * 2 + pose) * (tile_size + header)
            contact.paste(image.convert("RGB"), (x, y + header))
            draw.text((x + 8, y + 6), f"d{direction:03} | {'parked' if pose == 0 else 'running / 90 deg'} | {density}px/tile", font=font(15), fill="#dce7eb")
    contact.save(review_root / f"contact-{density}.png", optimize=True, pnginfo=png_info(compiler.reader.png_chunks))
    direction = 96 if 96 in compiler.directions else compiler.directions[0]
    upper = compiler.frame("upper", direction)
    rotor = compiler.frame("rotor", direction, 1)
    full = compiler.load("full", direction, 1)
    reconstructed = over(over(compiler.base, upper), rotor)
    panels = [("Fixed base", compiler.base), ("Yaw upper correction", upper), ("Rotor / receiver correction", rotor),
              ("Reconstructed", reconstructed), ("Full reference", full)]
    sheet = Image.new("RGB", (tile_size * len(panels), tile_size + header), "#19232a")
    draw = ImageDraw.Draw(sheet)
    for index, (label, array) in enumerate(panels):
        sheet.paste(Image.alpha_composite(backdrop((tile_size, tile_size)), Image.fromarray(array)).convert("RGB"), (index * tile_size, header))
        draw.text((index * tile_size + 8, 6), label, font=font(15), fill="#dce7eb")
    sheet.save(review_root / f"layers-{density}.png", optimize=True, pnginfo=png_info(compiler.reader.png_chunks))
    ownership = np.zeros((compiler.size, compiler.size, 4), np.uint8)
    ownership[compiler.base_clear] = [225, 140, 30, 190]
    ownership[compiler.rotor_cover[direction]] = [65, 145, 225, 190]
    ownership[compiler.rotor_clear[direction]] = [75, 210, 155, 190]
    Image.alpha_composite(backdrop((compiler.size, compiler.size)), Image.fromarray(ownership)).save(
        review_root / f"ownership-{density}.png", optimize=True, pnginfo=png_info(compiler.reader.png_chunks))


def write_review(output, metadata):
    status = "Complete 256-direction staging" if metadata["complete_direction_family"] else f"{len(metadata['direction_indices'])}-direction pilot only"
    budget = metadata["budget"]
    sections = []
    for name, density in (("sd", 32), ("hd", 64)):
        profile = metadata["profiles"][name]
        sections.append(f'<h2>{density} pixels per tile</h2><p>Maximum canonical RGBA reconstruction error: {profile["reconstruction"]["maximum_rgba_error"]}. '
                        f'Packed PNG bytes: {profile["png_bytes"]:,}. Native filtered-seam validation remains required.</p>'
                        f'<a href="review/contact-{density}.png"><img src="review/contact-{density}.png" alt="All supplied parked and running directions"></a>'
                        f'<a href="review/layers-{density}.png"><img src="review/layers-{density}.png" alt="Separated layers beside reconstruction and reference"></a>'
                        f'<p>Independent bilinear diagnostic: maximum alpha error {profile["reconstruction"]["fractional_filter"]["alpha_max_error"]}; '
                        f'maximum error over opaque backgrounds {profile["reconstruction"]["fractional_filter"]["opaque_background_max_error"]}. This is not a native-engine pass.</p>'
                        f'<p><a href="review/ownership-{density}.png">Ownership masks: amber clears fixed base; green clears for rotor; blue is its wider opaque correction collar.</a> These boundaries require native fractional-position and zoom comparison.</p>')
    page = f'''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Minigun separated sprite compilation</title><style>body{{max-width:1600px;margin:32px auto;padding:0 24px;background:#182127;color:#dce8e9;font:16px/1.5 system-ui}}img{{display:block;max-width:100%;margin:16px 0 28px}}a{{color:#92d0db}}p{{max-width:1050px}}pre{{overflow:auto}}</style>
<h1>Minigun prototype 2 / separated sprite review</h1><p>{html.escape(status)}. Source references remain untouched. Color RGB is normalized only where alpha is zero. SD is decomposed independently from its resized full-scene references.</p>
<p>Ground shadows are complete combined masks; the preview displays them at 35% opacity. Compiled shadow PNGs retain their original alpha. Exact center reconstruction and lossless PNG encoding do not establish native filtering, draw order or state timing.</p>
<p>Legacy all-SD-in-G4 comparison with15% allowance: {budget['g4_with_sd_allowance_bytes']:,} bytes. This is not the selected G4/G5 package layout or a release gate; the emitted artifact map and measured archive builder own that decision. Estimated standalone HD assets with15% allowance: {budget['hd_with_allowance_bytes']:,} bytes. Per-archive cap: {budget['archive_cap_bytes']:,} bytes. Icons {'are included' if budget['icons_included'] else 'are not included yet'}.</p>
{''.join(sections)}<p><a href="metadata.json">Full metadata and verification report</a></p></html>'''
    (output / "index.html").write_text(page, encoding="utf-8")


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input-root", type=Path, default=Path("output/meshy/minigun-prototypes/prototype-2/handoff-256/separated-v2"))
    parser.add_argument("--output", type=Path)
    parser.add_argument("--directions", default=",".join(map(str, PILOT_DIRECTIONS)))
    parser.add_argument("--g4-existing-bytes", type=int, default=G4_EXISTING_BYTES)
    parser.add_argument("--archive-cap-bytes", type=int, default=ARCHIVE_CAP_BYTES)
    parser.add_argument("--preparing-ticks", type=int, choices=(12, 18, 24, 30, 36, 45), default=12)
    parser.add_argument("--icon-master", type=Path, help="Approved 1024px d096 master with adjacent icon-report.json")
    parser.add_argument("--rotor-strips", type=int, choices=(1, 4), default=1,
                        help="Store the unchanged rotor crop as one leaf or four exact vertical child leaves")
    parser.add_argument("--enforce-budget", action="store_true")
    args = parser.parse_args(argv)
    directions = list(range(256)) if args.directions == "all" else sorted(int(x) for x in args.directions.split(","))
    if not directions or len(set(directions)) != len(directions) or min(directions) < 0 or max(directions) > 255:
        parser.error("directions must be unique indices from 0 through 255")
    input_root = args.input_root.resolve()
    output = (args.output or input_root / "compiled").resolve()
    staging_root = (Path.cwd() / "output").resolve()
    if not output.is_relative_to(staging_root) or output == input_root or input_root.is_relative_to(output):
        parser.error("compiler output must be a dedicated directory below this repository's output staging root")
    reader = ReferenceReader(input_root)
    reader.required(directions)
    signature = {"configuration_hash": reader.configuration["hash"], "directions": directions,
                 "script_sha256": sha256_bytes(Path(__file__).read_bytes()), "preparing_ticks": args.preparing_ticks,
                 "rotor_strips": args.rotor_strips,
                 "icon_master_sha256": sha256_bytes(args.icon_master.read_bytes()) if args.icon_master else None}
    signature_path = output / "compile-input.json"
    if signature_path.exists():
        if json.loads(signature_path.read_text(encoding="utf-8")) != signature:
            raise ValueError("Compiler inputs changed; select a new output directory to preserve previous evidence")
    elif output.exists() and any(output.iterdir()):
        raise ValueError("Output directory contains unrelated files; select a dedicated output directory")
    output.mkdir(parents=True, exist_ok=True)
    signature_path.write_text(json.dumps(signature, indent=2) + "\n", encoding="utf-8")
    review_root = output / "review"
    review_root.mkdir(exist_ok=True)
    metadata = {"schema": "esir.minigun.separated.compiled.v2", "source_sha256": SOURCE_SHA256,
                "configuration_hash": reader.configuration["hash"], "direction_indices": directions,
                "expected_production_direction_count": 256, "complete_direction_family": directions == list(range(256)),
                "production_promoted": False, "native_load_tested": False, "native_filtered_seams_tested": False,
                "physical_pose_count": PHYSICAL_POSES, "preparing_ticks": args.preparing_ticks, "folding_ticks": 18,
                "rotor_representation": "vertical_strips_4" if args.rotor_strips == 4 else "single_leaf",
                "sequences": {"parked": PARKED, "running": RUNNING, "preparing": SPIN_UP, "folding": SPIN_DOWN},
                "color_reference_policy": "RGB set to zero only where alpha is zero; SD reference resized before decomposition",
                "sd_resize": {"filter": "Pillow LANCZOS", "method": "RGBA -> 8-bit premultiplied RGBa -> resize -> unpremultiplied RGBA", "color_alpha_zero_rgb_canonicalized": True},
                "shadow_policy": "complete combined ground-shadow family; exact decoded PNG encoding; no isolated part-shadow stacking",
                "profiles": {}}
    if args.icon_master:
        metadata["icon_master"] = {"path": str(args.icon_master.resolve()), "sha256": signature["icon_master_sha256"],
                                  "resize": "Pillow LANCZOS on premultiplied RGBa, then RGBA; canonical zero-alpha RGB",
                                  "native_ui_readability_tested": False}
    for name, density in (("sd", 32), ("hd", 64)):
        compiler = DensityCompiler(reader, directions, density).analyze()
        profile_root = output / name
        profile_root.mkdir(exist_ok=True)
        # Temporary cleanup is confined to this newly created directory beneath
        # the validated task-owned output; no shipping/source path is removable.
        with packing_directory(output) as temporary:
            assert temporary.is_relative_to(output)
            families = {family: (pack_rotor_strips(compiler, profile_root, temporary)
                                if family == "rotor" and args.rotor_strips == 4
                                else pack_family(compiler, family, profile_root, temporary))
                        for family in ("base", "upper", "rotor", "shadow")}
            reference_root = output / "native-reference" / name
            reference = pack_family(compiler, "reference", reference_root, temporary)
            reference["root"] = "native-reference/" + name
            reference["shipping_payload"] = False
        icons = compile_icons(args.icon_master, profile_root, density, reader.png_chunks) if args.icon_master else {}
        icon_bytes = sum(row["bytes"] for row in icons.values())
        projected = icon_bytes + families["base"]["bytes"] + sum(families[family]["bytes"] * 256 / len(directions) for family in ("upper", "rotor", "shadow"))
        projected_decoded = sum(row["size"] ** 2 * 4 for row in icons.values()) + families["base"]["decoded_rgba_bytes"] + sum(
            families[family]["decoded_rgba_bytes"] * 256 / len(directions) for family in ("upper", "rotor", "shadow"))
        metadata["profiles"][name] = {"density": density, "direction_count": len(directions),
            "leaves": {family: record["leaf"] for family, record in families.items()},
            "families": families, "reconstruction": compiler.metrics,
            "png_bytes": icon_bytes + sum(row["bytes"] for row in families.values()),
            "projected_256_png_bytes": math.ceil(projected),
            "decoded_rgba_bytes": sum(row["decoded_rgba_bytes"] for row in families.values()) + sum(row["size"] ** 2 * 4 for row in icons.values()),
            "projected_256_decoded_rgba_bytes": math.ceil(projected_decoded),
            "decoded_size_scope": "sum of sheet pixels at four RGBA bytes each; not measured engine VRAM",
            "icons": icons, "icons_pending": not bool(icons)}
        metadata["profiles"][name]["native_reference"] = reference
        for kind, icon in icons.items():
            metadata["profiles"][name][kind + "_icon"] = icon["path"]
            metadata["profiles"][name][kind + "_icon_size"] = icon["size"]
        review_images(compiler, review_root)
        print(f"COMPILED_PROFILE {name} png_bytes={metadata['profiles'][name]['png_bytes']} estimated_256={math.ceil(projected)}", flush=True)
    sd = metadata["profiles"]["sd"]["projected_256_png_bytes"]
    hd = metadata["profiles"]["hd"]["projected_256_png_bytes"]
    metadata["budget"] = {"archive_cap_bytes": args.archive_cap_bytes, "g4_existing_bytes": args.g4_existing_bytes,
        "scope": "legacy all-SD-in-G4 comparison; final G4/G5/HD gates use emitted artifact map and measured archives",
        "release_gate": False,
        "allowance_fraction": .15, "allowance_scope": "new PNG assets; existing G4 archive already measured",
        "sd_projected_png_bytes": sd, "hd_projected_png_bytes": hd,
        "g4_raw_total_bytes": args.g4_existing_bytes + sd,
        "g4_with_sd_allowance_bytes": args.g4_existing_bytes + math.ceil(sd * 1.15),
        "g4_with_total_allowance_bytes": math.ceil((args.g4_existing_bytes + sd) * 1.15),
        "hd_with_allowance_bytes": math.ceil(hd * 1.15), "icons_included": bool(args.icon_master),
        "projection_is_estimate": len(directions) != 256,
        "g4_fits": args.g4_existing_bytes + math.ceil(sd * 1.15) < args.archive_cap_bytes,
        "hd_fits": math.ceil(hd * 1.15) < args.archive_cap_bytes}
    metadata["sources"] = reader.sources
    metadata["png_color_profile_chunks"] = {name: payload.hex() for name, payload in reader.png_chunks.items()}
    (output / "metadata.json").write_text(json.dumps(metadata, indent=2) + "\n", encoding="utf-8")
    write_review(output, metadata)
    print("COMPILE_COMPLETE " + json.dumps({"output": str(output), "budget": metadata["budget"]}), flush=True)
    return 2 if args.enforce_budget and not (metadata["budget"]["g4_fits"] and metadata["budget"]["hd_fits"]) else 0


if __name__ == "__main__":
    raise SystemExit(main())
