"""Independently verify every combined ground-shadow cell against retained renders."""
import copy
import hashlib
import io
import json
from pathlib import Path

import numpy as np
from PIL import Image

PILOT = list(range(0, 256, 32))
FINAL_CANARIES = sorted(set(PILOT + [7, 8, 15, 16, 127, 255]))
SCHEMA = "esir.minigun.complete-shadow-source-proof.v1"


def digest(payload):
    return hashlib.sha256(payload).hexdigest()


def require(condition, message):
    if not condition:
        raise ValueError(message)


def confined(root, relative):
    path = (root / relative).resolve()
    require(path.is_relative_to(root.resolve()) and path.is_file(), "Missing/unconfined shadow source: " + relative)
    return path


def reference_cell(leaf, ordinal, pose):
    require(not any(key in leaf for key in ("layers", "stripes", "frame_sequence", "position"))
            and not leaf.get("x", 0) and not leaf.get("y", 0)
            and leaf.get("frame_count") == 28, "Expected a flat zero-origin 28-pose shadow atlas")
    columns = leaf.get("line_length", 0)
    require(type(columns) is int and columns > 0 and 28 % columns == 0,
            "Temporal columns must divide the 28 physical poses")
    require(0 <= ordinal < leaf["direction_count"] and 0 <= pose < 28, "Cell lies outside its complete family")
    row, column = divmod(ordinal * 28 + pose, columns)
    index = 0
    if "filenames" in leaf:
        lines = leaf.get("lines_per_file", 0)
        require(leaf.get("slice") == columns and type(lines) is int and lines > 0
                and lines % (28 // columns) == 0, "Atlas files must contain complete direction records")
        index, row = divmod(row, lines)
        require(index < len(leaf["filenames"]), "Missing shadow atlas file")
        relative = leaf["filenames"][index]
    else:
        relative = leaf["filename"]
    result = copy.deepcopy(leaf)
    for key in ("filenames", "slice", "lines_per_file", "frame_sequence"):
        result.pop(key, None)
    result.update(filename=relative, x=column * leaf["width"], y=row * leaf["height"],
                  frame_count=1, direction_count=1, line_length=1,
                  apply_projection=False, counterclockwise=False)
    return result, index


class AtlasReader:
    """One decoded atlas at a time, plus a small per-file digest ledger."""
    def __init__(self, root, family):
        self.root, self.family = root, family
        self.path, self.pixels = None, None
        self.files = {}
        self.records = {row["name"]: row for row in family["files"]}

    def cell(self, ordinal, pose):
        leaf, index = reference_cell(self.family["leaf"], ordinal, pose)
        path = confined(self.root, leaf["filename"])
        if path != self.path:
            payload = path.read_bytes()
            record = self.records.get(path.name, {})
            require(len(payload) == record.get("bytes") and digest(payload) == record.get("sha256"),
                    "Packed shadow bytes disagree with compiler metadata: " + str(path))
            with Image.open(io.BytesIO(payload)) as image:
                self.pixels = np.asarray(image.convert("RGBA")).copy()
            require(list(reversed(self.pixels.shape[:2])) == record.get("size"), "Packed shadow dimensions changed")
            self.path = path
            self.files[leaf["filename"]] = {"path": str(path), "sha256": digest(payload), "bytes": len(payload)}
        x, y, w, h = leaf["x"], leaf["y"], leaf["width"], leaf["height"]
        cell = self.pixels[y:y+h, x:x+w]
        require(cell.shape == (h, w, 4), "Shadow cell crosses source PNG bounds")
        return cell, leaf, index


def validate_families(metadata):
    directions = metadata.get("direction_indices")
    require(directions in (PILOT, list(range(256))), "Expected actual pilot8 or complete256 global directions")
    require(metadata.get("physical_pose_count") == 28, "Expected all 28 physical poses")
    if len(directions) == 256:
        require(metadata.get("complete_direction_family") is True, "Final source must declare complete256 coverage")
    for name, density in (("sd", 32), ("hd", 64)):
        profile = metadata["profiles"][name]
        leaf = profile["leaves"]["shadow"]
        require(profile["density"] == density and profile["direction_count"] == len(directions)
                and profile.get("direction_indices", directions) == directions,
                "SD/HD direction or density mismatch")
        require(profile["families"]["shadow"]["leaf"] == leaf and leaf.get("frame_count") == 28
                and leaf.get("direction_count") == len(directions) and leaf.get("draw_as_shadow") is True
                and leaf.get("scale") == 32 / density and leaf.get("apply_projection") is True
                and leaf.get("counterclockwise") is False and not leaf.get("flags"),
                "Combined shadow changed complete native family/texture policy")
        reference_cell(leaf, len(directions)-1, 27)
    return directions


def check_complete(candidate_root, candidates, reference_root, reference, render_root):
    directions = validate_families(candidates)
    require(validate_families(reference) == directions, "Candidate/reference direction families differ")
    require(candidates["configuration_hash"] == reference["configuration_hash"], "Render configurations differ")
    render_root = Path(render_root).resolve()
    config_path = render_root / "render-configuration.json"
    records_path = render_root / "render-records.jsonl"
    config = json.loads(config_path.read_text(encoding="utf-8-sig"))
    require(config["hash"] == candidates["configuration_hash"] and config["resolution"] == [540, 540]
            and config["density"] == 64 and config["physical_poses"] == 28,
            "Retained render configuration does not match the exact compiled source")
    records = {}
    for line in records_path.read_text(encoding="utf-8-sig").splitlines():
        row = json.loads(line)
        if row["family"] == "full" and row["pass"] == "Shadow":
            key = (row["direction"], row["pose"])
            require(key not in records or all(records[key].get(field) == row.get(field)
                    for field in ("sha256","configuration_hash","path")), "Conflicting retained render records")
            records[key] = row
    readers = {(name, role): AtlasReader(root/name, metadata["profiles"][name]["families"]["shadow"])
               for name in ("sd", "hd") for role, root, metadata in
               (("candidate", candidate_root, candidates), ("reference", reference_root, reference))}
    rows, maxima = [], {"sd": 0, "hd": 0}
    for ordinal, direction in enumerate(directions):
        for pose in range(28):
            relative = f"references/full/Shadow/d{direction:03}-p{pose:02}.png"
            path = confined(render_root, relative)
            payload = path.read_bytes()
            raw_hash = digest(payload)
            record = records.get((direction, pose), {})
            require(record.get("sha256") == raw_hash and record.get("configuration_hash") == config["hash"]
                    and record.get("path") == relative, "Missing/changed retained render record: " + relative)
            for metadata in (candidates, reference):
                source = metadata.get("sources", {}).get(relative, {})
                require(source.get("sha256") == raw_hash and source.get("bytes") == len(payload),
                        "Compiled source digest/size does not match retained raw shadow: " + relative)
            with Image.open(io.BytesIO(payload)) as image:
                master = image.convert("RGBA")
            require(master.size == (540, 540), "Wrong raw shadow dimensions")
            for name, density in (("sd", 32), ("hd", 64)):
                image = (master.convert("RGBa").resize((270, 270), Image.Resampling.LANCZOS).convert("RGBA")
                         if density == 32 else master)
                target = np.asarray(image)[:, :, 3]
                hashes = {}
                for role, metadata in (("candidate", candidates), ("reference", reference)):
                    reader = readers[name, role]
                    cell, leaf, index = reader.cell(ordinal, pose)
                    left, top, right, bottom = reader.family["crop"]
                    require(cell.shape[:2] == (bottom-top, right-left)
                            and 0 <= left < right <= len(target) and 0 <= top < bottom <= len(target),
                            "Shadow crop does not fit retained render")
                    expected_shift = [((left+right)/2-config["ground_anchor_pixels"][0]*density/64)/density,
                                      ((top+bottom)/2-config["ground_anchor_pixels"][1]*density/64)/density]
                    require(all(abs(a-b) < 1e-10 for a, b in zip(expected_shift, leaf.get("shift", [])))
                            and len(leaf.get("shift", [])) == 2, "Shadow registration does not match ground anchor")
                    canvas = np.zeros_like(target)
                    canvas[top:bottom, left:right] = cell[:, :, 3]
                    maximum = int(np.abs(canvas.astype(np.int16)-target.astype(np.int16)).max())
                    maxima[name] = max(maxima[name], maximum)
                    require(maximum == 0, f"Combined shadow lost source alpha: {name}/{direction}/{pose}/{role}")
                    hashes[role] = {"filename": leaf["filename"], "file_index": index,
                        "rectangle": [leaf["x"], leaf["y"], leaf["x"]+leaf["width"], leaf["y"]+leaf["height"]],
                        "decoded_rgba_sha256": digest(cell.tobytes()), "canvas_alpha_sha256": digest(canvas.tobytes())}
                rows.append({"profile": name, "direction": direction, "pose": pose,
                    "source_path": relative, "source_bytes": len(payload), "source_sha256": raw_hash,
                    "reference_alpha_sha256": digest(target.tobytes()), **hashes})
    proof = {"schema": SCHEMA, "configuration_hash": config["hash"], "render_root": str(render_root),
        "render_configuration_sha256": digest(config_path.read_bytes()),
        "render_records_sha256": digest(records_path.read_bytes()), "direction_indices": directions,
        "source_direction_count": len(directions), "physical_pose_count": 28,
        "sd_resize": "Pillow LANCZOS: RGBA -> RGBa -> 270x270 -> RGBA; alpha compared exactly",
        "atlas_files": {name: {role: reader.files for (profile, role), reader in readers.items() if profile == name}
                        for name in ("sd", "hd")}, "cells": rows}
    summary = {name: {"frames_checked": len(directions)*28, "maximum_alpha_error": maxima[name],
        "pixels_above_one_code": 0, "passed": True, "exact_alpha": True,
        "method": "Every candidate and reference atlas alpha cell matched the hash-bound retained full Shadow render"}
        for name in ("sd", "hd")}
    return summary, proof


def validate_ledger(proof, candidates, reference):
    """Check the retained ledger's complete Cartesian product and independent hash links."""
    directions = validate_families(candidates)
    require(validate_families(reference) == directions and proof.get("schema") == SCHEMA
            and proof.get("configuration_hash") == candidates["configuration_hash"] == reference["configuration_hash"]
            and proof.get("direction_indices") == directions and proof.get("source_direction_count") == len(directions)
            and proof.get("physical_pose_count") == 28, "Source proof has different family/configuration provenance")
    expected = {(name, direction, pose) for name in ("sd", "hd") for direction in directions for pose in range(28)}
    rows = proof.get("cells", [])
    actual = [(row.get("profile"), row.get("direction"), row.get("pose")) for row in rows]
    require(len(actual) == len(expected) and set(actual) == expected, "Source proof omits/duplicates shadow cells")
    for name in ("sd", "hd"):
        for role, metadata in (("candidate",candidates),("reference",reference)):
            family = metadata["profiles"][name]["families"]["shadow"]
            leaf = family["leaf"]
            paths = leaf.get("filenames",[leaf.get("filename")])
            files = proof["atlas_files"][name][role]
            require(set(files) == set(paths), "Source proof omits/adds atlas files")
            records = {row["name"]: row for row in family["files"]}
            for relative, row in files.items():
                record = records[Path(relative).name]
                require(row["sha256"] == record["sha256"] and row["bytes"] == record["bytes"],
                        "Source proof atlas bytes do not match the frozen compiler metadata")
    for row in rows:
        expected_path = f"references/full/Shadow/d{row['direction']:03}-p{row['pose']:02}.png"
        require(row["source_path"] == expected_path, "Wrong source frame address")
        for role, metadata in (("candidate", candidates), ("reference", reference)):
            source = metadata["sources"][expected_path]
            require(row["source_sha256"] == source["sha256"] and row["source_bytes"] == source["bytes"],
                    "Source proof digest is not in compiled metadata")
            require(row[role]["canvas_alpha_sha256"] == row["reference_alpha_sha256"],
                    "Source proof does not demonstrate exact alpha")
            leaf, index = reference_cell(metadata["profiles"][row["profile"]]["leaves"]["shadow"],
                                         directions.index(row["direction"]), row["pose"])
            require(row[role]["filename"] == leaf["filename"] and row[role]["file_index"] == index
                    and row[role]["rectangle"] == [leaf["x"],leaf["y"],leaf["x"]+leaf["width"],leaf["y"]+leaf["height"]],
                    "Source proof cell does not address the actual frozen atlas")
    return True
