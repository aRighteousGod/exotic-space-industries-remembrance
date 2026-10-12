"""Strict provenance and native shadow-policy checks, separate from error tolerances."""
import hashlib
import json
import math
from pathlib import Path
import re

from PIL import Image
from source_proof import FINAL_CANARIES, PILOT, require, validate_ledger

STATES = ("folded_animation", "preparing_animation", "prepared_animation", "attacking_animation", "folding_animation")
FIELDS = ("filename", "filenames", "x", "y", "width", "height", "direction_count", "frame_count",
          "frame_sequence", "shift", "scale", "line_length", "slice", "lines_per_file",
          "apply_projection", "counterclockwise")


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def expected_cases(inputs):
    count = inputs.get("source_direction_count", 8)
    require(count in (8, 256), "Unexpected source direction count")
    directions = [0, 32, 96, 128] if inputs["matrix"] == "smoke" else FINAL_CANARIES if count == 256 else PILOT
    poses = [0, 1, 7, 20] if inputs["matrix"] == "smoke" else list(range(28))
    fractions = [0, .5] if inputs["matrix"] == "smoke" else [0, .25, .5, .75]
    zooms = [1, 1.5] if inputs["matrix"] == "smoke" else [.75, 1, 1.5, 2]
    return {(tier["id"], d, p, f, z) for tier in inputs["tiers"] for d in directions for p in poses for f in fractions for z in zooms}


def verify_inputs(helper, inputs):
    files = inputs["files"]
    require(len({row["path"] for row in files}) == len(files), "Duplicate staged image ledger entries")
    for row in files:
        path = (helper/row["path"]).resolve()
        require(path.is_relative_to(helper.resolve()) and path.is_file() and path.stat().st_size == row["bytes"]
                and digest(path) == row["sha256"], "Staged shadow PNG changed/missing: " + row["path"])
    actual = [(row["tier"],row["direction"],row["pose"],row["fractional_native_pixel_offset"],row["zoom"]) for row in inputs["cases"]]
    require(len(actual) == len(expected_cases(inputs)) and set(actual) == expected_cases(inputs), "Staged native matrix is incomplete/duplicated")
    require(len(inputs["controls"]) == 3 and {(row["id"],row["control_alpha"]) for row in inputs["controls"]}
            == {("control-background",0),("control-mid",128),("control-full",255)}, "Exactly three alpha controls are required")
    proof_path = helper/"source-shadow-proof.json"
    require(proof_path.is_file() and digest(proof_path) == inputs.get("source_proof_sha256"), "Retained source proof is missing/changed")
    proof = json.loads(proof_path.read_text(encoding="utf-8-sig"))
    metadata = {}
    for role in ("candidate", "reference"):
        path = helper/(role+"-metadata.json")
        require(path.is_file() and digest(path) == inputs[role+"_metadata_sha256"], "Frozen compiled metadata changed")
        metadata[role] = json.loads(path.read_text(encoding="utf-8-sig"))
    validate_ledger(proof, metadata["candidate"], metadata["reference"])
    require(inputs["direction_indices"] == proof["direction_indices"]
            and inputs["source_direction_count"] == proof["source_direction_count"], "Native/source direction coverage differs")
    for profile in ("sd", "hd"):
        summary = inputs["source_alpha"][profile]
        require(summary.get("frames_checked") == 28*proof["source_direction_count"]
                and summary.get("passed") is True and summary.get("exact_alpha") is True
                and summary.get("maximum_alpha_error") == 0 and summary.get("pixels_above_one_code") == 0,
                "Complete combined source proof did not preserve exact alpha")
    # Every actual candidate file remains present, even though reference cells load only canaries.
    for profile in inputs["selected_profiles"]:
        for relative, row in proof["atlas_files"][profile]["candidate"].items():
            wanted = "graphics/combined/"+profile+"/"+relative
            require(any(file["path"] == wanted and file["sha256"] == row["sha256"] and file["bytes"] == row["bytes"]
                        for file in files), "Native candidate lost an actual full atlas file")
    selection = inputs["reference_selection"]
    require(selection in ("full", "cells"), "Unsupported reference selection")
    references = inputs["reference_cells"]
    require(hashlib.sha256(json.dumps(references,sort_keys=True).encode()).hexdigest() == inputs["reference_cells_sha256"],
            "Reference-cell selection digest changed")
    if selection == "cells":
        expected = {(tier["reference"],row["direction"],row["pose"]) for tier in inputs["tiers"] for row in inputs["cases"] if row["tier"] == tier["id"]}
        actual = [(row["profile"],row["direction"],row["pose"]) for row in references]
        require(len(actual) == len(expected) and set(actual) == expected, "Missing/duplicate selected reference cells")
        source_rows = {(row["profile"],row["direction"],row["pose"]): row for row in proof["cells"]}
        image_path, decoded = None, None
        for row in references:
            source = source_rows[row["profile"],row["direction"],row["pose"]]["reference"]
            require(row["rectangle"] == source["rectangle"] and row["decoded_rgba_sha256"] == source["decoded_rgba_sha256"]
                    and row["source_file_index"] == source["file_index"], "Reference selected a different proven cell")
            relative = "graphics/reference/"+row["profile"]+"/"+source["filename"]
            require(row["staged_filename"] == "__zzz-esir-minigun-shadow__/"+relative, "Reference path differs from source-cell declaration")
            path = helper/relative
            require(digest(path) == row["source_sha256"], "Selected reference source bytes changed")
            if image_path != path:
                if decoded is not None:
                    decoded.close()
                with Image.open(path) as image:
                    decoded = image.convert("RGBA")
                image_path = path
            require(hashlib.sha256(decoded.crop(row["rectangle"]).tobytes()).hexdigest() == row["decoded_rgba_sha256"],
                    "Staged reference cell pixels changed")
        if decoded is not None:
            decoded.close()
    return proof


def expected_leaf_rows(inputs):
    result = {}
    def add(owner, source, pose=None):
        leaf = dict(source)
        if pose is not None:
            leaf["frame_sequence"] = [pose+1]
        for state in STATES:
            result[owner+"/"+state] = leaf
    for tier in inputs["tiers"]:
        require(tier.get("representation") == "combined", "Final native policy applies only to combined shadows")
        profile = inputs["shadow_profiles"][tier["shadow"]]
        reference = inputs["shadow_profiles"][tier["reference"]]
        for pose in range(28):
            add(f"mg-shadow-{tier['id']}-separated-{pose}", profile["shadow"], pose)
            if "reference" in reference:
                add(f"mg-shadow-{tier['id']}-reference-{pose}", reference["reference"], pose)
        for direction, poses in reference.get("reference_cells", {}).items():
            for pose, leaf in poses.items():
                add(f"mg-shadow-{tier['id']}-reference-{pose}-d{direction}", leaf, 0)
    for alpha in (0,128,255):
        add("mg-shadow-control-"+str(alpha), {"filename":f"__zzz-esir-minigun-shadow__/graphics/control-{alpha}.png",
            "width":32,"height":32,"frame_count":1,"direction_count":1,"draw_as_shadow":True})
    return result


def verify_native_policy(inputs, report, log):
    expected = expected_leaf_rows(inputs)
    rows = report.get("shadow_leaf_flags", [])
    require(len(rows) == inputs.get("expected_shadow_leaf_count") == len(expected)
            and len({row.get("owner") for row in rows}) == len(expected), "Native shadow leaf audit is incomplete/duplicated")
    for row in rows:
        leaf = expected.get(row.get("owner"))
        require(leaf is not None and row.get("draw_as_shadow") is True and not row.get("flags"),
                "Native leaf changed the default shadow texture policy")
        for key in FIELDS:
            default = 0 if key in ("x", "y") else [] if key == "frame_sequence" else None
            actual, wanted = row.get(key, default), leaf.get(key, default)
            if key == "frame_sequence" and not actual:
                actual = []
            require(actual == wanted, "Native shadow leaf changed actual packing/registration: " + row["owner"]+"/"+key)
    flags = [sorted({flag.strip() for flag in match.split(",") if flag.strip()})
             for match in re.findall(r"Created an atlas bitmap[^\r\n]*\[([^\]]+)\]",log)]
    matched = [row for row in flags if set(row) == {"shadow", "linear-magnification", "alpha-mask"}]
    require(bool(matched), "Engine log does not confirm the measured native shadow atlas policy")
    return {"observed_atlas_flags":flags,"matched_shadow_atlas_flags":matched,
            "native_shadow_policy_verified":True,"shadow_leaf_count":len(rows)}


def expected_prototype(case, variant, selection):
    if "control_alpha" in case:
        return "mg-shadow-control-"+str(case["control_alpha"])
    name = f"mg-shadow-{case['tier']}-{variant}-{case['pose']}"
    return name+f"-d{case['direction']}" if selection == "cells" and variant == "reference" else name


def verify_capture(case, pair, selection):
    angle = case["direction"]/256*2*math.pi
    wanted = math.atan2(math.sqrt(2)*math.sin(angle),math.cos(angle))/(2*math.pi)%1
    require([row.get("prototype_name") for row in pair] == [expected_prototype(case,variant,selection) for variant in ("separated","reference")],
            "Native capture used a different frozen shadow prototype: " + case["id"])
    require(all(abs(((row.get("orientation",-1)-wanted+.5)%1)-.5) < 1e-7 for row in pair),
            "Native heading differs from the actual projected global direction: " + case["id"])
