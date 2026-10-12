"""Stage independent all-caster references and candidate native shadow families."""
import argparse
import copy
import hashlib
import itertools
import json
import math
import os
from pathlib import Path

import numpy as np
from PIL import Image
from source_proof import (FINAL_CANARIES, check_complete, reference_cell,
                          validate_families, validate_ledger)

MOD = "zzz-esir-minigun-shadow"
PILOT = list(range(0, 256, 32))


def lua(value):
    if isinstance(value, dict):
        return "{" + ",".join("[" + lua(k) + "]=" + lua(v) for k, v in value.items()) + "}"
    if isinstance(value, list):
        return "{" + ",".join(lua(v) for v in value) + "}"
    if isinstance(value, str):
        return json.dumps(value)
    if isinstance(value, bool):
        return "true" if value else "false"
    return "nil" if value is None else repr(value)


def tiers_for(selection):
    if selection in ("combined_hd", "combined_sd", "combined"):
        return [{"id": "combined_" + density, "representation": "combined",
                 "base": density, "upper": density, "shadow": density,
                 "reference": density, "mandatory": True}
                for density in ("hd", "sd")
                if selection == "combined" or selection == "combined_" + density]
    tiers = [{"id": "all_hd", "base": "hd", "upper": "hd", "shadow": "hd", "reference": "hd", "mandatory": True},
             {"id": "sd_baseline", "base": "sd", "upper": "sd", "shadow": "sd", "reference": "sd", "mandatory": True}]
    for base, upper, rotor in itertools.product(("sd", "hd"), repeat=3):
        if (base, upper, rotor) == ("hd", "hd", "hd"):
            continue
        name = {("hd","hd","sd"):"base_upper", ("hd","sd","sd"):"base_only",
                ("sd","sd","sd"):"all_sd"}.get((base,upper,rotor),
            f"hd-b{32 if base == 'sd' else 64}-u{32 if upper == 'sd' else 64}-r{32 if rotor == 'sd' else 64}")
        tiers.append({"id": name,
                      "base": base, "upper": upper, "shadow": rotor, "reference": "hd", "mandatory": False})
    result = tiers if selection == "all" else [tier for tier in tiers if tier["id"] == selection]
    if not result:
        raise ValueError("Unknown shadow tier: " + selection)
    return result


def cases_for(matrix, tiers, source_direction_count=8):
    directions = ([0, 32, 96, 128] if matrix == "smoke" else
                  FINAL_CANARIES if source_direction_count == 256 else PILOT)
    poses = [0, 1, 7, 20] if matrix == "smoke" else list(range(28))
    offsets = [0, .5] if matrix == "smoke" else [0, .25, .5, .75]
    zooms = [1, 1.5] if matrix == "smoke" else [.75, 1, 1.5, 2]
    return [{"id": f"{tier['id']}-d{d:03}-p{p:02}-f{fraction:g}-z{zoom:g}",
             "tier": tier["id"], "reference_density": 32 if tier["reference"] == "sd" else 64,
             "direction": d, "pose": p, "fractional_native_pixel_offset": fraction, "zoom": zoom}
            for tier in tiers for d in directions for p in poses for fraction in offsets for zoom in zooms]


def confined(root, relative):
    path = (root / relative).resolve()
    if not path.is_relative_to(root.resolve()) or not path.is_file():
        raise ValueError(f"Missing or unconfined atlas: {relative}")
    return path


class AlphaReader:
    def __init__(self):
        self.cache = {}

    def frame(self, root, family, direction, pose, density):
        leaf = family["leaf"]
        count = leaf["frame_count"]
        columns = leaf["line_length"]
        index = direction * count + pose
        if "filenames" in leaf:
            per_file = columns * leaf["lines_per_file"]
            filename = leaf["filenames"][index // per_file]
            index %= per_file
        else:
            filename = leaf["filename"]
        path = confined(root, filename)
        if path not in self.cache:
            with Image.open(path) as image:
                self.cache[path] = np.asarray(image.convert("RGBA"))[:, :, 3].copy()
        x, y = index % columns * leaf["width"], index // columns * leaf["height"]
        tile = self.cache[path][y:y+leaf["height"], x:x+leaf["width"]]
        left, top, right, bottom = family["crop"]
        size = 540 * density // 64
        if tile.shape != (bottom-top, right-left) or not (0 <= left < right <= size and 0 <= top < bottom <= size):
            raise ValueError("Atlas cell/crop mismatch while independently checking source alpha")
        canvas = np.zeros((size, size), dtype=np.uint8)
        canvas[top:bottom, left:right] = tile
        return canvas


def alpha_over(under, layer):
    # Independent implementation, avoiding the generator's residual/accumulate.
    return np.rint(layer.astype(np.float64) + under.astype(np.float64) * (1-layer.astype(np.float64)/255)).astype(np.uint8)


def check_source_alpha(candidate_root, candidates, reference_root, reference):
    reader, results = AlphaReader(), {}
    for profile, density in (("hd", 64), ("sd", 32)):
        families = candidates["profiles"][profile]["families"]
        target_family = reference["profiles"][profile]["families"]["shadow"]
        base = reader.frame(candidate_root/profile, families["base"], 0, 0, density)
        maximum, mismatched = 0, 0
        for local_direction, direction in enumerate(PILOT):
            upper = reader.frame(candidate_root/profile, families["upper"], local_direction, 0, density)
            under = alpha_over(base, upper)
            for pose in range(28):
                rotor = reader.frame(candidate_root/profile, families["shadow"], local_direction, pose, density)
                target = reader.frame(reference_root/profile, target_family, local_direction, pose, density)
                error = np.abs(alpha_over(under, rotor).astype(np.int16)-target.astype(np.int16))
                maximum = max(maximum, int(error.max()))
                mismatched += int(np.count_nonzero(error > 1))
        results[profile] = {"frames_checked": 224, "maximum_alpha_error": maximum,
                            "pixels_above_one_code": mismatched, "passed": maximum <= 1}
        if maximum > 1:
            raise ValueError(f"Equal-density source shadow reconstruction failed: {profile}, max alpha={maximum}")
    return results


def build(candidate_root, reference_root, destination, matrix, selection,
          render_references=None, reference_selection="auto"):
    candidate_root, reference_root = candidate_root.resolve(), reference_root.resolve()
    candidate_path, reference_path = candidate_root/"metadata.json", reference_root/"metadata.json"
    candidates = json.loads(candidate_path.read_text(encoding="utf-8-sig"))
    reference = json.loads(reference_path.read_text(encoding="utf-8-sig"))
    combined = selection in ("combined_hd", "combined_sd", "combined")
    directions = reference["direction_indices"]
    source_direction_count = len(directions)
    if directions not in (PILOT, list(range(256))) or (source_direction_count == 256 and not combined):
        raise ValueError("Final256 permits only complete combined SD/HD shadow families")
    if reference_selection not in ("auto", "full", "cells"):
        raise ValueError("Unknown reference selection")
    reference_selection = ("cells" if source_direction_count == 256 else "full") if reference_selection == "auto" else reference_selection
    if not combined and reference_selection != "full":
        raise ValueError("Legacy residual tiers retain their original full-reference fixture")
    if not combined and (candidates["schema"] != "esir.minigun.shadow-candidates.v1" or candidates["native_law"] != "alpha_over"):
        raise ValueError("Unexpected shadow candidate schema or native accumulation law")
    if not combined and candidates["directions"] != PILOT:
        raise ValueError("Legacy residual tiers require all eight pilot directions")
    if not combined and candidates["render_configuration_hash"] != reference["configuration_hash"]:
        raise ValueError("Shadow candidates and all-caster reference originate from different render configurations")
    tiers = tiers_for(selection)
    if matrix == "full" and selection in ("all", "combined"):
        raise ValueError("Run full matrices one selected tier at a time, after its smoke gate")
    if combined:
        if render_references is None:
            render_references = reference_root.parent
        source_alpha, source_proof = check_complete(candidate_root, candidates, reference_root, reference, render_references)
        validate_ledger(source_proof, candidates, reference)
    else:
        source_alpha = check_source_alpha(candidate_root, candidates, reference_root, reference)
    destination.mkdir(parents=True, exist_ok=True)
    profiles, files, extent = {}, [], [0.0, 0.0]
    staged_files, reference_cells = {}, []
    cases = cases_for(matrix, tiers, source_direction_count)
    selected_profiles = sorted({tier[family] for tier in tiers for family in ("base", "upper", "shadow", "reference")})
    tested_directions = sorted({case["direction"] for case in cases})
    tested_poses = sorted({case["pose"] for case in cases})

    def stage(leaf, root, prefix):
        if leaf.get("draw_as_shadow") is not True:
            raise ValueError("Every candidate/reference leaf must declare draw_as_shadow=true")
        output = copy.deepcopy(leaf)
        paths = [leaf["filename"]] if "filename" in leaf else leaf["filenames"]
        names = []
        for relative in paths:
            source = confined(root, relative)
            target = destination/prefix/relative
            key = target.relative_to(destination.parent).as_posix()
            if key not in staged_files:
                payload = source.read_bytes()
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(payload)
                staged_files[key] = {"path": key, "source": str(source),
                    "sha256": hashlib.sha256(payload).hexdigest(), "bytes": len(payload)}
                files.append(staged_files[key])
            elif staged_files[key]["source"] != str(source):
                raise ValueError("Two source shadow files collide at the staged path")
            names.append(f"__{MOD}__/graphics/{prefix}/{relative}")
        if "filename" in leaf:
            output["filename"] = names[0]
        else:
            output["filenames"] = names
        for axis, size in enumerate((leaf["width"], leaf["height"])):
            extent[axis] = max(extent[axis], abs(leaf.get("shift", [0,0])[axis]*32) + size*leaf.get("scale",1)/2)
        return output

    for name, density in (("hd", 64), ("sd", 32)):
        if combined:
            if name not in selected_profiles:
                continue
            target = candidates["profiles"][name]["leaves"]["shadow"]
            source = reference["profiles"][name]["leaves"]["shadow"]
            profiles[name] = {"shadow": stage(target,candidate_root/name,"combined/"+name)}
            if reference_selection == "full":
                profiles[name]["reference"] = stage(source,reference_root/name,"reference/"+name)
            else:
                profiles[name]["reference_cells"] = {}
                proof_cells = {(row["direction"], row["pose"]): row for row in source_proof["cells"] if row["profile"] == name}
                for direction in tested_directions:
                    profiles[name]["reference_cells"][direction] = {}
                    for pose in tested_poses:
                        cell, file_index = reference_cell(source, directions.index(direction), pose)
                        selected = stage(cell, reference_root/name, "reference/"+name)
                        profiles[name]["reference_cells"][direction][pose] = selected
                        proven = proof_cells[direction, pose]["reference"]
                        source_path = confined(reference_root/name, cell["filename"])
                        reference_cells.append({"profile": name, "direction": direction, "pose": pose,
                            "source_file_index": file_index, "source_path": str(source_path),
                            "source_sha256": source_proof["atlas_files"][name]["reference"][cell["filename"]]["sha256"],
                            "rectangle": proven["rectangle"], "decoded_rgba_sha256": proven["decoded_rgba_sha256"],
                            "staged_filename": selected["filename"]})
            continue
        source = candidates["profiles"][name]
        if source["density"] != density or reference["profiles"][name]["density"] != density:
            raise ValueError("Unexpected profile density")
        leaves = source["leaves"]
        target = reference["profiles"][name]["leaves"]["shadow"]
        if leaves["base"]["frame_count"] != 1 or leaves["upper"]["frame_count"] != 1:
            raise ValueError("Base/upper shadows must be static source frames")
        if leaves["shadow"]["frame_count"] != 28 or target["frame_count"] != 28:
            raise ValueError("Residual and all-caster reference must contain 28 physical poses")
        if any(leaf.get("direction_count") != 8 for leaf in (leaves["upper"],leaves["shadow"],target)):
            raise ValueError("Rotating shadow families must declare eight directions")
        profiles[name] = {family: stage(leaves[family],candidate_root/name,"candidates/"+name)
                          for family in ("base","upper","shadow")}
        profiles[name]["reference"] = stage(target,reference_root/name,"reference/"+name)
    for case in cases:
        case["resolution"] = [int(math.ceil((2*axis+32)*case["zoom"]/4)*4) for axis in extent]
        if min(case["resolution"]) <= 0 or max(case["resolution"]) > 2048:
            raise ValueError("Unexpected shadow crop dimensions")
    controls = [{"id":"control-"+name,"control_alpha":alpha,"tier":"control","direction":0,"pose":0,
                 "reference_density":64,"fractional_native_pixel_offset":0,"zoom":2,
                 "resolution":[int(math.ceil((2*axis+32)*2/4)*4) for axis in extent]}
                for name,alpha in (("background",0),("full",255),("mid",128))]
    Image.new("RGBA",(1024,1024),(180,180,180,255)).save(destination/"background.png",optimize=True)
    for alpha in (0,128,255):
        Image.new("RGBA",(32,32),(0,0,0,alpha)).save(destination/f"control-{alpha}.png",optimize=True)
    contract = {"schema":1,"matrix":matrix,"profiles":profiles,"tiers":tiers,
                "reference_selection":reference_selection,
                "cases":controls+cases,"first_capture_tick":20,"finish_tick":22+2*(len(cases)+3),
                "rgb_max_allowance":2,"rgb_rms_allowance":.25,"equivalent_alpha_max_allowance":6}
    manifest = {"schema":1,"matrix":matrix,"selection":selection,"tiers":tiers,
                "source_direction_count":source_direction_count,"direction_indices":directions,
                "tested_direction_indices":tested_directions,"selected_profiles":selected_profiles,
                "reference_selection":reference_selection,"reference_cells":reference_cells,
                "reference_cells_sha256":hashlib.sha256(json.dumps(reference_cells,sort_keys=True).encode()).hexdigest(),
                "shadow_texture_policy":"native-shadow-default",
                "shadow_profiles":profiles if combined else None,
                "capture_geometry":"entity-relative-camera-v3","offset_units":"engine-native-pixel-32-per-tile",
                "candidate_metadata_sha256":hashlib.sha256(candidate_path.read_bytes()).hexdigest(),
                "reference_metadata_sha256":hashlib.sha256(reference_path.read_bytes()).hexdigest(),
                "texture_compression":os.environ.get("ESIR_MINIGUN_SHADOW_COMPRESSION","none"),
                "candidate_root":str(candidate_root),"reference_root":str(reference_root),
                "source_alpha":source_alpha,"files":files,"cases":cases,"controls":controls,
                "comparison_cases":len(cases),"screenshots":2*(len(cases)+3),
                "benchmark_ticks":contract["finish_tick"]+20,"production_approved":False}
    if combined:
        proof_path = destination.parent/"source-shadow-proof.json"
        proof_path.write_text(json.dumps(source_proof,indent=2)+"\n",encoding="utf-8")
        manifest["source_proof_sha256"] = hashlib.sha256(proof_path.read_bytes()).hexdigest()
        for name, path in (("candidate",candidate_path),("reference",reference_path)):
            (destination.parent/(name+"-metadata.json")).write_bytes(path.read_bytes())
    manifest["expected_shadow_leaf_count"] = (sum(5*(28+(28 if "reference" in value else
        sum(len(poses) for poses in value["reference_cells"].values()))) for value in profiles.values())+15
        if combined else None)
    (destination.parent/"contract.lua").write_text("return "+lua(contract)+"\n",encoding="utf-8")
    (destination.parent/"shadow-input-manifest.json").write_text(json.dumps(manifest,indent=2)+"\n",encoding="utf-8")
    return manifest


if __name__ == "__main__":
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--candidates",type=Path,default=os.environ.get("ESIR_MINIGUN_SHADOW_CANDIDATES"))
    parser.add_argument("--reference",type=Path,default=os.environ.get("ESIR_MINIGUN_SHADOW_REFERENCE"))
    parser.add_argument("--matrix",choices=("smoke","full"),default=os.environ.get("ESIR_MINIGUN_SHADOW_MATRIX","smoke"))
    parser.add_argument("--tier",default=os.environ.get("ESIR_MINIGUN_SHADOW_TIER","all"))
    parser.add_argument("--output",type=Path,required=True)
    parser.add_argument("--render-references",type=Path,default=os.environ.get("ESIR_MINIGUN_SHADOW_RENDERS"))
    parser.add_argument("--reference-selection",choices=("auto","full","cells"),
                        default=os.environ.get("ESIR_MINIGUN_SHADOW_REFERENCE_SELECTION","auto"))
    args=parser.parse_args()
    if args.candidates is None or args.reference is None:
        parser.error("Shadow candidates and all-caster reference paths are required")
    result=build(args.candidates,args.reference,args.output,args.matrix,args.tier,args.render_references,args.reference_selection)
    print(json.dumps({k:result[k] for k in ("matrix","selection","comparison_cases","screenshots","benchmark_ticks")}))
