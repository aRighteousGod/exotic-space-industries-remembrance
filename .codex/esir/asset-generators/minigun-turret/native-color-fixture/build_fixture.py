"""Stage byte-exact pilot atlases for native filtering/composition comparisons."""
import argparse
import copy
import hashlib
import json
import math
import os
from pathlib import Path

from PIL import Image

MOD = "zzz-esir-minigun-color"
PILOT = list(range(0, 256, 32))
FINAL_CANARIES = sorted(set(PILOT + [7, 8, 15, 16, 127, 255]))


def lua(value):
    if isinstance(value, dict):
        return "{" + ",".join("[" + lua(key) + "]=" + lua(item) for key, item in value.items()) + "}"
    if isinstance(value, list):
        return "{" + ",".join(lua(item) for item in value) + "}"
    if isinstance(value, str):
        return json.dumps(value, ensure_ascii=True)
    if isinstance(value, bool):
        return "true" if value else "false"
    if value is None:
        return "nil"
    return repr(value)


def confined(root, relative):
    target = (root / relative).resolve()
    if not target.is_relative_to(root.resolve()) or not target.is_file():
        raise ValueError(f"Atlas path escapes source or is missing: {relative}")
    return target


def cases_for(matrix, source_direction_count=8, profile="all"):
    if profile not in ("all", "sd", "hd"):
        raise ValueError("Unsupported color profile selection")
    directions = ([0, 32, 96, 128] if matrix == "smoke" else
                  FINAL_CANARIES if source_direction_count == 256 else PILOT)
    poses = [0, 1, 7, 20] if matrix == "smoke" else list(range(28))
    offsets = [0, 0.5] if matrix == "smoke" else [0, 0.25, 0.5, 0.75]
    zooms = [1, 1.5] if matrix == "smoke" else [0.75, 1, 1.5, 2]
    return [{"id": f"{profile}-d{direction:03}-p{pose:02}-f{offset:g}-z{zoom:g}",
             "profile": profile, "direction": direction, "pose": pose,
             "fractional_native_pixel_offset": offset, "zoom": zoom}
            for profile in (("sd", "hd") if profile == "all" else (profile,))
            for direction in directions for pose in poses
            for offset in offsets for zoom in zooms]


def image_leaves(source):
    if "layers" in source:
        if not source["layers"]:
            raise ValueError("Empty animation layers cannot prove composition")
        for layer in source["layers"]:
            yield from image_leaves(layer)
    else:
        yield source


def reference_cell(leaf, direction_ordinal, pose):
    """Select one exact compiler cell without changing its native registration."""
    if ("layers" in leaf or "stripes" in leaf or leaf.get("frame_count") != 28
            or leaf.get("frame_sequence") or leaf.get("x", 0) or leaf.get("y", 0)
            or leaf.get("position")):
        raise ValueError("Reference selection requires the compiler's flat zero-origin atlas")
    columns = leaf.get("line_length", 0)
    if not isinstance(columns, int) or columns <= 0 or 28 % columns:
        raise ValueError("Reference columns must divide all 28 physical poses")
    if not 0 <= direction_ordinal < leaf["direction_count"] or not 0 <= pose < 28:
        raise ValueError("Reference direction or pose is outside the actual source family")
    row, column = divmod(direction_ordinal * 28 + pose, columns)
    if "filenames" in leaf:
        lines = leaf.get("lines_per_file", 0)
        if (leaf.get("slice") != columns or not isinstance(lines, int) or lines <= 0
                or lines % (28 // columns)):
            raise ValueError("Reference file layout must preserve whole direction records")
        file_index, row = divmod(row, lines)
        if file_index >= len(leaf["filenames"]):
            raise ValueError("Missing reference atlas file")
        relative = leaf["filenames"][file_index]
    else:
        file_index, relative = 0, leaf["filename"]
    result = copy.deepcopy(leaf)
    for key in ("filenames", "slice", "lines_per_file", "frame_sequence"):
        result.pop(key, None)
    result.update(filename=relative, x=column * leaf["width"], y=row * leaf["height"],
                  frame_count=1, direction_count=1, line_length=1,
                  apply_projection=False, counterclockwise=False)
    return result, file_index


def build(compiled, destination, matrix, color_texture_policy="native-default",
          profile="all", reference_selection="auto"):
    if color_texture_policy not in ("native-default", "not-compressed"):
        raise ValueError("Unsupported native color texture policy")
    compiled = compiled.resolve()
    metadata_path = compiled / "metadata.json"
    metadata = json.loads(metadata_path.read_text(encoding="utf-8-sig"))
    destination.mkdir(parents=True, exist_ok=True)
    profiles, files = {}, []
    extent = [0.0, 0.0]
    source_direction_count = metadata["profiles"]["sd"]["direction_count"]
    if source_direction_count not in (8, 256):
        raise ValueError("Color gate accepts only the pilot8 or complete256 family")
    expected_directions = PILOT if source_direction_count == 8 else list(range(256))
    if reference_selection not in ("auto", "full", "cells"):
        raise ValueError("Unsupported reference selection")
    reference_selection = ("cells" if source_direction_count == 256 else "full") if reference_selection == "auto" else reference_selection
    cases = cases_for(matrix, source_direction_count, profile)
    selected_profiles = ["sd", "hd"] if profile == "all" else [profile]
    tested_directions = sorted(set(case["direction"] for case in cases))
    tested_poses = sorted(set(case["pose"] for case in cases))
    staged_files, reference_cells = {}, []

    def stage_file(source_root, prefix, relative):
        source = confined(source_root, relative)
        target = destination / prefix / relative
        key = target.relative_to(destination.parent).as_posix()
        if key not in staged_files:
            target.parent.mkdir(parents=True, exist_ok=True)
            payload = source.read_bytes()
            target.write_bytes(payload)
            row = {"path": key, "source": str(source), "bytes": len(payload),
                   "sha256": hashlib.sha256(payload).hexdigest()}
            staged_files[key] = row
            files.append(row)
        elif staged_files[key]["source"] != str(source):
            raise ValueError("Two source atlases collide at the same staged path")
        return f"__{MOD}__/graphics/{prefix}/{relative}", staged_files[key]

    def stage_leaf(leaf, source_root, prefix):
        result = copy.deepcopy(leaf)
        if "layers" in leaf:
            result["layers"] = [stage_leaf(child,source_root,prefix) for child in leaf["layers"]]
            return result
        if color_texture_policy == "not-compressed":
            if "always-compressed" in result.get("flags", []):
                raise ValueError("Color leaf conflicts with the lossless native texture policy")
            # Native default object sampling was measured without filtering
            # flags. Adding linear-magnification failed composition (max80).
            # Preserve source sampling flags and change only compression.
            result["flags"] = list(dict.fromkeys([
                *result.get("flags", []), "not-compressed"]))
        paths = [leaf["filename"]] if "filename" in leaf else leaf["filenames"]
        replacements = []
        for relative in paths:
            replacements.append(stage_file(source_root, prefix, relative)[0])
        if "filename" in leaf:
            result["filename"] = replacements[0]
        else:
            result["filenames"] = replacements
        scale = leaf.get("scale", 1)
        shift = leaf.get("shift", [0, 0])
        for axis, size in enumerate((leaf["width"], leaf["height"])):
            extent[axis] = max(extent[axis], abs(shift[axis] * 32) + size * scale / 2)
        return result

    for name, density in (("sd", 32), ("hd", 64)):
        source = metadata["profiles"][name]
        directions = source.get("direction_indices", metadata.get("direction_indices", metadata.get("directions")))
        if (source["direction_count"] != source_direction_count or
            directions != expected_directions or source["density"] != density):
            raise ValueError("Native color fixture requires matching SD/HD global direction families")
        leaves = source["leaves"]
        reference = source["native_reference"]
        if leaves["base"]["frame_count"] != 1 or leaves["upper"]["frame_count"] != 1:
            raise ValueError("Unexpected static source frame counts")
        rotor_leaves = list(image_leaves(leaves["rotor"]))
        if any(leaf["frame_count"] != 28 for leaf in rotor_leaves) or reference["leaf"]["frame_count"] != 28:
            raise ValueError("Expected 28 physical color and reference poses")
        if any(leaf.get("direction_count") != source_direction_count for leaf in
               (leaves["upper"], *rotor_leaves, reference["leaf"])):
            raise ValueError("Rotating leaves must retain the complete source direction count")
        if name not in selected_profiles:
            continue
        profiles[name] = {"density": density,
            **{family: stage_leaf(leaves[family], compiled / name, name)
               for family in ("base", "upper", "rotor")}}
        reference_root = compiled / reference["root"]
        if reference_selection == "full":
            profiles[name]["reference"] = stage_leaf(reference["leaf"], reference_root, "reference/" + name)
        else:
            profiles[name]["reference_cells"] = {}
            decoded_path, decoded_image = None, None
            for direction in tested_directions:
                selected = {}
                profiles[name]["reference_cells"][direction] = selected
                for pose in tested_poses:
                    cell, file_index = reference_cell(reference["leaf"], directions.index(direction), pose)
                    relative = cell["filename"]
                    source_path = confined(reference_root, relative)
                    if decoded_path != source_path:
                        if decoded_image is not None:
                            decoded_image.close()
                        with Image.open(source_path) as source_image:
                            decoded_image = source_image.convert("RGBA")
                        decoded_path = source_path
                    bounds = (cell["x"], cell["y"], cell["x"] + cell["width"], cell["y"] + cell["height"])
                    if bounds[2] > decoded_image.width or bounds[3] > decoded_image.height:
                        raise ValueError("Reference cell extends outside its source atlas")
                    decoded_hash = hashlib.sha256(decoded_image.crop(bounds).tobytes()).hexdigest()
                    selected[pose] = stage_leaf(cell, reference_root, "reference/" + name)
                    _, source_file = stage_file(reference_root, "reference/" + name, relative)
                    reference_cells.append({"profile": name, "direction": direction, "pose": pose,
                        "source_file_index": file_index, "source_path": source_file["source"],
                        "source_sha256": source_file["sha256"], "rectangle": list(bounds),
                        "decoded_rgba_sha256": decoded_hash, "staged_filename": selected[pose]["filename"]})
            if decoded_image is not None:
                decoded_image.close()
    for case in cases:
        case["resolution"] = [int(math.ceil((2 * axis + 32) * case["zoom"] / 4) * 4) for axis in extent]
        if min(case["resolution"]) <= 0 or max(case["resolution"]) > 2048:
            raise ValueError("Unexpected sprite bounds or screenshot resolution")
    background = Image.new("RGBA", (1024, 1024), (110, 110, 110, 255))
    background.save(destination / "background.png", optimize=True)
    # The same blank-background pair checks that sequential native screenshots
    # have no camera registration, environmental, lighting or temporal drift.
    control_cases = [{"id": "control-background" + ("-" + profile if profile != "all" else ""),
                      "profile": selected_profiles[0], "direction": 0, "pose": 0,
                      "fractional_native_pixel_offset": 0, "zoom": 2,
                      "resolution": [int(math.ceil((2 * axis + 32) * 2 / 4) * 4) for axis in extent],
                      "background_only": True}]
    contract = {"schema": 1, "matrix": matrix, "profiles": profiles,
                "cases": control_cases + cases, "first_capture_tick": 20,
                "finish_tick": 22 + 2 * (len(cases) + 1),
                "direction_indices": expected_directions, "source_direction_count": source_direction_count,
                "tested_direction_indices": tested_directions,
                "selected_profiles": selected_profiles, "reference_selection": reference_selection,
                "color_texture_policy": color_texture_policy, "rgb_max_allowance": 1,
                "rgb_rms_allowance": 0.25}
    expected_color_leaf_count = 0
    for profile in profiles.values():
        state_leaves = sum(1 for family in ("upper", "rotor") for _ in image_leaves(profile[family]))
        reference_count = (28 if "reference" in profile else
                           sum(len(poses) for poses in profile["reference_cells"].values()))
        expected_color_leaf_count += 28 * (1 + 5 * state_leaves) + 5 * reference_count
    manifest = {"schema": 1, "matrix": matrix, "compiled": str(compiled),
                "expected_color_leaf_count": expected_color_leaf_count,
                "source_direction_count": source_direction_count,
                "tested_direction_indices": tested_directions,
                "selected_profiles": selected_profiles, "reference_selection": reference_selection,
                "reference_cells": reference_cells,
                "reference_cells_sha256": hashlib.sha256(json.dumps(reference_cells, sort_keys=True).encode()).hexdigest(),
                "color_texture_policy": color_texture_policy,
                "color_texture_flags": (["not-compressed"]
                                        if color_texture_policy == "not-compressed" else None),
                "capture_geometry":"entity-relative-camera-v3","offset_units":"engine-native-pixel-32-per-tile",
                "texture_compression": os.environ.get("ESIR_MINIGUN_COLOR_COMPRESSION", "none"),
                "metadata_sha256": hashlib.sha256(metadata_path.read_bytes()).hexdigest(),
                "files": files, "cases": cases, "controls": control_cases,
                "comparison_cases": len(cases), "screenshots": 2 * (len(cases) + 1),
                "benchmark_ticks": contract["finish_tick"] + 20,
                "shadows_included": False, "production_approved": False}
    (destination.parent / "contract.lua").write_text("return " + lua(contract) + "\n", encoding="utf-8")
    (destination.parent / "color-input-manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    return manifest


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--compiled", type=Path, default=os.environ.get("ESIR_MINIGUN_COLOR_COMPILED"))
    parser.add_argument("--matrix", choices=("smoke", "full"), default=os.environ.get("ESIR_MINIGUN_COLOR_MATRIX", "smoke"))
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--profile", choices=("all", "sd", "hd"), default=os.environ.get("ESIR_MINIGUN_COLOR_PROFILE", "all"))
    parser.add_argument("--reference-selection", choices=("auto", "full", "cells"),
                        default=os.environ.get("ESIR_MINIGUN_COLOR_REFERENCE", "auto"))
    parser.add_argument("--color-texture-policy", choices=("native-default", "not-compressed"),
                        default=os.environ.get("ESIR_MINIGUN_COLOR_TEXTURE_POLICY", "native-default"))
    args = parser.parse_args()
    if args.compiled is None:
        parser.error("--compiled or ESIR_MINIGUN_COLOR_COMPILED is required")
    result = build(args.compiled, args.output, args.matrix, args.color_texture_policy,
                   args.profile, args.reference_selection)
    print(json.dumps({key: result[key] for key in ("matrix", "comparison_cases", "screenshots", "benchmark_ticks")}))
