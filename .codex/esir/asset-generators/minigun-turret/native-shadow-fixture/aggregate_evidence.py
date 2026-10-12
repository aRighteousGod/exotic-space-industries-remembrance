"""Reproduce the SD/HD full shadow union from actual retained per-profile evidence."""
import argparse
import copy
import hashlib
import importlib.util
import itertools
import json
import os
from pathlib import Path
import numpy as np
from PIL import Image

_spec = importlib.util.spec_from_file_location("minigun_shadow_source_proof", Path(__file__).with_name("source_proof.py"))
_source = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_source)
FINAL_CANARIES, PILOT, require, validate_ledger = _source.FINAL_CANARIES, _source.PILOT, _source.require, _source.validate_ledger
_geometry_spec = importlib.util.spec_from_file_location("minigun_shadow_capture_geometry", Path(__file__).with_name("capture_geometry.py"))
_geometry = importlib.util.module_from_spec(_geometry_spec)
_geometry_spec.loader.exec_module(_geometry)

SCHEMA = "esir.minigun.native-shadow-profile-aggregate.v1"
FRACTIONS = [0,.25,.5,.75]
ZOOMS = [.75,1,1.5,2]


def digest(path):
    return hashlib.sha256(fs(path).read_bytes()).hexdigest()


def fs(path):
    value=os.path.abspath(path)
    if os.name=="nt" and not value.startswith("\\\\?\\"):
        value="\\\\?\\UNC\\"+value[2:] if value.startswith("\\\\") else "\\\\?\\"+value
    return Path(value)


def verify_geometry_pixels(summary, directory, inputs):
    """Recompute registration from hash-bound native pixels, never scalar claims."""
    native=json.loads(fs(directory/"native-report.json").read_text(encoding="utf-8-sig"))
    cases=inputs["controls"]+inputs["cases"]
    require(native.get("cases")==cases and native.get("matrix")==summary["matrix"]
            and native.get("capture_geometry")==_geometry.METHOD and native.get("offset_units")==_geometry.UNITS
            and isinstance(native.get("errors"),(list,dict)) and not native["errors"], "Retained native camera contract differs")
    captures={}
    for row in native.get("captures",[]):
        key=(row.get("case_id"),row.get("variant"))
        require(key not in captures, "Duplicate retained camera capture")
        captures[key]=row
    require(set(captures)=={(case["id"],variant) for case in cases for variant in ("separated","reference")},
            "Retained camera captures do not cover the exact matrix")
    summaries={row["id"]:row for row in summary["cases"]}
    groups={};failures=[]
    for case in cases:
        pair=[];pixels=None
        require(Path(case["id"]).name==case["id"] and "/" not in case["id"] and "\\" not in case["id"], "Unsafe camera case path")
        for variant in ("separated","reference"):
            capture=captures[(case["id"],variant)]
            require(capture.get("path")=="minigun-native-shadow/"+case["id"]+"/"+variant+".png", "Unexpected native camera image path")
            path=directory/"screenshots"/case["id"]/(variant+".png")
            require(digest(path)==summaries[case["id"]]["screenshots_sha256"][variant], "Retained camera pixels changed")
            pair.append(capture)
            if variant=="reference":
                with Image.open(fs(path)) as image:
                    require(list(image.size)==case["resolution"], "Retained camera image bounds changed")
                    pixels=np.asarray(image.convert("RGB"),dtype=np.int16)
        failures.extend(_geometry.inspect(case,pair,pixels,groups,summary["matrix"]))
    geometry,problems=_geometry.finish(groups,summary["matrix"])
    require(not failures and not problems, "Retained pixels do not prove native shadow camera phases")
    require(geometry==summary["capture_geometry"], "Saved camera proof does not match recomputed native pixels")


def validate_component(summary, profile):
    tier_name = "combined_"+profile
    require(summary.get("schema") == "esir.minigun.native-shadow-evidence.v1"
            and summary.get("matrix") == "full" and summary.get("selected_profiles") == [profile]
            and summary.get("automated_checks_passed") is True and summary.get("failures") == [],
            "Expected a passed complete single-profile combined shadow run")
    count = summary.get("source_direction_count")
    require(count in (8,256), "Unknown source family")
    directions = FINAL_CANARIES if count == 256 else PILOT
    require(summary.get("tested_direction_indices") == directions, "Incomplete final canary headings")
    require(summary.get("source_cells_verified") is True and summary.get("staged_files_verified") is True
            and summary.get("reference_selection_verified") is True
            and summary.get("reference_selection") in ("full","cells"), "Missing source/reference provenance")
    require(summary.get("native_shadow_policy_verified") is True
            and summary.get("shadow_texture_policy") == "native-shadow-default"
            and ["alpha-mask","linear-magnification","shadow"] in summary.get("matched_shadow_atlas_flags",[]),
            "Native default shadow policy was not observed")
    compression = summary.get("texture_compression_observed")
    require(compression in ("none","high-quality") and summary.get("texture_compression_requested") == compression,
            "Requested and observed global compression differ")
    require((summary.get("native_rgb_max_allowance"),summary.get("native_rgb_rms_allowance"),
             summary.get("native_equivalent_alpha_max_allowance"),summary.get("source_alpha_max_allowance")) == (2,.25,6,1),
            "Native/source shadow allowances changed")
    for name in ("sd","hd"):
        source = summary.get("source_alpha",{}).get(name,{})
        require(source.get("frames_checked") == count*28 and source.get("maximum_alpha_error") == 0
                and source.get("pixels_above_one_code") == 0 and source.get("passed") is True
                and source.get("exact_alpha") is True, "All source cells were not verified exactly")
    calibration = summary.get("alpha_calibration",{})
    require(calibration.get("passed") is True and 0 <= calibration.get("midpoint_error_rgb",256) <= 2
            and len(calibration.get("darkening_at_alpha255_rgb",[])) == 3
            and all(value >= 10 for value in calibration["darkening_at_alpha255_rgb"]), "Native alpha calibration failed")
    require(set(summary.get("tiers",{})) == {tier_name}, "Component includes an extra or foreign tier")
    tier = summary["tiers"][tier_name]
    require(tier.get("passed") is True and tier.get("representation") == "combined"
            and tier.get("families") == {"base":profile,"upper":profile,"rotor":profile}
            and tier.get("reference_profile") == profile and tier.get("failed_cases") == [], "Wrong complete shadow family")
    require(tier.get("native_eligible") is (compression == "none"), "Uncompressed eligibility changed semantics")
    require(tier.get("final_policy_qualified") is (compression == "high-quality" and count == 256),
            "HQ qualification does not match final source/compression scope")
    rows = summary.get("cases",[])
    require(len(rows) == summary.get("comparison_pairs") == summary.get("expected_comparison_pairs")
            and len({row.get("id") for row in rows}) == len(rows), "Missing/duplicate native comparison records")
    controls = [row for row in rows if "control_alpha" in row]
    cases = [row for row in rows if "control_alpha" not in row]
    expected = set(itertools.product([tier_name],directions,range(28),FRACTIONS,ZOOMS))
    actual = [(row.get("tier"),row.get("direction"),row.get("pose"),row.get("fractional_native_pixel_offset"),row.get("zoom")) for row in cases]
    require(len(actual) == len(expected) and set(actual) == expected and tier.get("comparison_cases") == len(expected),
            "Component is not the complete actual canary matrix")
    require(len(controls) == 3 and {(row.get("id"),row.get("control_alpha")) for row in controls}
            == {("control-background",0),("control-mid",128),("control-full",255)}, "Three independent alpha controls are required")
    for row in rows:
        require(row.get("passed") is True and 0 <= row.get("max_rgb_error",256) <= 2
                and 0 <= row.get("rms_rgb_error",256) <= .25
                and 0 <= row.get("max_equivalent_alpha_error",256) <= 6
                and row.get("registration_border_error") == 0 and row.get("reference_border_deviation",256) <= 1,
                "A native comparison failed or omitted its measured error")
        hashes = row.get("screenshots_sha256",{})
        require(set(hashes) == {"separated","reference"} and all(isinstance(value,str) and len(value)==64
                and all(char in "0123456789abcdef" for char in value) for value in hashes.values()), "Screenshot provenance missing")
        if "control_alpha" in row:
            require(row["max_rgb_error"] == row["rms_rgb_error"] == row["max_equivalent_alpha_error"] == 0,
                    "Identity calibration pair differs")
        else:
            require(row.get("reference_shadow_pixels",0) >= max(16,8*row["zoom"]**2), "Reference shadow is absent")
    require(tier["max_rgb_error"] == max(row["max_rgb_error"] for row in cases)
            and tier["max_equivalent_alpha_error"] == max(row["max_equivalent_alpha_error"] for row in cases)
            and tier["maximum_case_rms_rgb_error"] == max(row["rms_rgb_error"] for row in cases), "Tier extrema disagree with measured cases")
    geometry = summary.get("capture_geometry",{})
    require(geometry.get("passed") is True and geometry.get("method") == "entity-relative-camera-v3"
            and geometry.get("offset_units") == "engine-native-pixel-32-per-tile"
            and geometry.get("required_fractions") == FRACTIONS
            and geometry.get("groups_checked") == len(directions)*28*4
            and geometry.get("unvalidated_duplicate_pixel_groups") == [], "Incomplete actual camera proof")
    duplicates = geometry.get("duplicate_pixel_groups")
    require(isinstance(duplicates,list), "Missing camera quantization diagnostics")
    if duplicates:
        require(geometry.get("pixel_phase_quantization_proven") is True
                and geometry.get("quantization_method") == _geometry.QUANTIZATION
                and geometry.get("translation_rgb_max_allowance")==1
                and geometry.get("translation_support_threshold_rgb")==4
                and geometry.get("translation_support_uncertainty_band_rgb")==[4,5], "Unproven camera aliases")
    lookup, groups = {row["id"]:row for row in cases}, set()
    for group in duplicates:
        key = tuple(group.get("group",[]))
        require(len(key)==4 and key[0]==tier_name and key not in groups, "Duplicate/foreign camera group")
        groups.add(key)
        aliases = group.get("cases",[])
        require(len(aliases)==4 and sorted(row.get("fraction") for row in aliases)==FRACTIONS
                and len({row.get("pixels_sha256") for row in aliases})>=2, "Incomplete/stationary camera group")
        for alias in aliases:
            case = lookup.get(alias.get("case_id"),{})
            require(list(key)==[case.get("tier"),case.get("direction"),case.get("pose"),case.get("zoom")]
                    and alias.get("fraction")==case.get("fractional_native_pixel_offset"), "Alias belongs to another native case")
            records=alias.get("screen_translation_evidence",[])
            require(isinstance(records,list) and len(records)==1, "Native camera translation is absent or ambiguous")
            measured=records[0];shift=measured.get("shift")
            require(isinstance(shift,list) and len(shift)==2 and all(type(value) is int and value>=0 for value in shift)
                    and (alias["fraction"]==0 or shift!=[0,0])
                    and 0<=measured.get("maximum_rgb_error",256)<=1
                    and 0<=measured.get("rms_rgb_error",256)<=1
                    and type(measured.get("differing_pixels")) is int and measured["differing_pixels"]>=0
                    and measured.get("border_exact") is True and measured.get("shadow_support_qualified") is True
                    and type(measured.get("shadow_support_exact")) is bool
                    and measured.get("support_threshold_rgb")==4
                    and measured.get("support_uncertainty_band_rgb")==[4,5], "Invalid bounded native camera translation")
            crossings=measured.get("support_crossing_pixels");values=measured.get("support_crossing_values")
            require(type(crossings) is int and crossings>=0 and isinstance(values,list)
                    and all(value in ([4,5],[5,4]) for value in values)
                    and measured["shadow_support_exact"] is (crossings==0)
                    and bool(values) is (crossings>0), "Shadow support band differs from measured crossings")
    return summary


def aggregate_files(paths):
    require(len(paths)==2, "Both serial full profiles are required")
    components, sources = {}, []
    for path in paths:
        path = Path(path).resolve()
        summary = json.loads(path.read_text(encoding="utf-8-sig"))
        selected = summary.get("selected_profiles",[])
        require(selected in (["sd"],["hd"]) and selected[0] not in components, "Expected exactly one SD and HD component")
        profile = selected[0]
        validate_component(summary,profile)
        manifest = path.parent/"shadow-input-manifest.json"
        proof_path = path.parent/"source-shadow-proof.json"
        require(digest(manifest)==summary.get("input_manifest_sha256") and digest(proof_path)==summary.get("source_proof_sha256"),
                "Retained manifest/source proof changed")
        inputs = json.loads(manifest.read_text(encoding="utf-8-sig"))
        for key in ("candidate_metadata_sha256","reference_metadata_sha256","source_proof_sha256","reference_cells_sha256",
                    "source_direction_count","selected_profiles","reference_selection","tested_direction_indices"):
            require(inputs.get(key)==summary.get(key), "Summary disagrees with retained source manifest: "+key)
        require(inputs.get("matrix")=="full" and inputs.get("selection")=="combined_"+profile,
                "Retained manifest is not the selected full combined tier")
        staged = inputs.get("controls",[])+inputs.get("cases",[])
        require(len(staged)==len(summary["cases"]) and all(all(row.get(key)==value for key,value in case.items())
                for row,case in zip(summary["cases"],staged)), "Measured native rows differ from staged cases")
        verify_geometry_pixels(summary,path.parent,inputs)
        cells = inputs.get("reference_cells",[])
        require(hashlib.sha256(json.dumps(cells,sort_keys=True).encode()).hexdigest()==inputs["reference_cells_sha256"],
                "Retained reference-cell digest changed")
        if inputs["reference_selection"]=="cells":
            wanted={(profile,row["direction"],row["pose"]) for row in inputs["cases"]}
            actual=[(row["profile"],row["direction"],row["pose"]) for row in cells]
            require(len(actual)==len(wanted) and set(actual)==wanted, "Retained full reference selection is incomplete")
        metadata = {}
        for role in ("candidate","reference"):
            file = path.parent/(role+"-metadata.json")
            require(digest(file)==summary[role+"_metadata_sha256"], "Frozen metadata changed")
            metadata[role] = json.loads(file.read_text(encoding="utf-8-sig"))
        validate_ledger(json.loads(proof_path.read_text()),metadata["candidate"],metadata["reference"])
        components[profile] = summary
        sources.append({"profile":profile,"path":str(path),"sha256":digest(path),"input_manifest_sha256":digest(manifest),
                        "source_proof_sha256":digest(proof_path)})
    sd,hd = components["sd"],components["hd"]
    for key in ("candidate_metadata_sha256","reference_metadata_sha256","source_direction_count","tested_direction_indices",
                "texture_compression_observed","texture_compression_requested","shadow_texture_policy","reference_selection",
                "source_proof_sha256","source_alpha","analyzer_sha256"):
        require(sd.get(key)==hd.get(key), "Components have different provenance/policy: "+key)
    result = copy.deepcopy(sd)
    for key in ("run","input_manifest_sha256","reference_cells_sha256","alpha_calibration"):
        result.pop(key,None)
    result["selected_profiles"] = ["sd","hd"]
    result["tiers"] = {**sd["tiers"],**hd["tiers"]}
    result["cases"] = []
    for profile in ("sd","hd"):
        for original in components[profile]["cases"]:
            row = {**original,"component_profile":profile}
            if "control_alpha" in row:
                row["id"] = profile+"/"+row["id"]
            result["cases"].append(row)
    result["comparison_pairs"] = result["expected_comparison_pairs"] = len(result["cases"])
    result["profile_alpha_calibration"] = {profile:components[profile]["alpha_calibration"] for profile in ("sd","hd")}
    result["shadow_leaf_count"] += hd["shadow_leaf_count"]
    result["capture_geometry"]["groups_checked"] += hd["capture_geometry"]["groups_checked"]
    result["capture_geometry"]["duplicate_pixel_groups"] += hd["capture_geometry"]["duplicate_pixel_groups"]
    result["capture_geometry"]["pixel_phase_quantization_proven"] = bool(result["capture_geometry"]["duplicate_pixel_groups"])
    result["aggregation"] = {"schema":SCHEMA,"sources":sorted(sources,key=lambda row:row["profile"]),
        "aggregator_sha256":digest(Path(__file__)),
        "capture_geometry_sha256":digest(Path(__file__).with_name("capture_geometry.py")),"control_count":6,
        "qualification":"final-native-shadow-policy" if all(row["final_policy_qualified"] for row in result["tiers"].values())
            else "uncompressed-native-math" if all(row["native_eligible"] for row in result["tiers"].values()) else "pilot-only"}
    result["production_approved"] = False
    return result


def verify_aggregate(summary):
    require(summary.get("aggregation",{}).get("schema")==SCHEMA, "Unsupported aggregate schema")
    require(summary==aggregate_files([row["path"] for row in summary["aggregation"]["sources"]]),
            "Aggregate cannot be reproduced from retained component files")


if __name__ == "__main__":
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--sd",type=Path,required=True)
    parser.add_argument("--hd",type=Path,required=True)
    parser.add_argument("--output",type=Path,required=True)
    args=parser.parse_args()
    if args.output.exists():
        parser.error("Refusing to overwrite retained evidence")
    result=aggregate_files([args.sd,args.hd])
    args.output.parent.mkdir(parents=True,exist_ok=True)
    args.output.write_text(json.dumps(result,indent=2)+"\n",encoding="utf-8")
    print(json.dumps({"comparison_pairs":result["comparison_pairs"],"qualification":result["aggregation"]["qualification"],"production_approved":False}))
