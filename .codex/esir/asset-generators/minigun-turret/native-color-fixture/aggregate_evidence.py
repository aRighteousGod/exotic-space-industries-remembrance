"""Validate and unite two complete native profile runs; never invent missing cases."""
import argparse
import copy
import hashlib
import itertools
import json
from pathlib import Path

SCHEMA = "esir.minigun.native-color-profile-aggregate.v1"
FRACTIONS = [0, .25, .5, .75]
ZOOMS = [.75, 1, 1.5, 2]
PILOT = list(range(0, 256, 32))
FINAL_CANARIES = sorted(set(PILOT + [7, 8, 15, 16, 127, 255]))


def require(condition, message):
    if not condition:
        raise ValueError(message)


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def validate_component(summary, profile):
    require(summary.get("schema") == 1 and summary.get("matrix") == "full"
            and summary.get("selected_profiles") == [profile]
            and summary.get("automated_checks_passed") is True
            and summary.get("failures") == [], "Component is not a passed complete single-profile run")
    count = summary.get("source_direction_count")
    require(count in (8, 256), "Component source family is neither pilot8 nor final256")
    directions = FINAL_CANARIES if count == 256 else PILOT
    require(summary.get("tested_direction_indices") == directions, "Component lacks the exact required canaries")
    require(summary.get("reference_selection_verified") is True
            and summary.get("reference_selection") in ("full", "cells")
            and summary.get("staged_files_verified") is True,
            "Component lacks verified source files/reference selection")
    require(summary.get("color_texture_policy") == "not-compressed"
            and summary.get("color_texture_flags") == ["not-compressed"]
            and summary.get("native_color_flags_verified") is True
            and summary.get("color_leaf_flags_verified") is True
            and summary.get("mathematical_composition_gate") is True
            and summary.get("texture_compression_observed") in ("none", "high-quality")
            and summary.get("texture_compression_requested") == summary.get("texture_compression_observed")
            and any(set(flags) >= {"not-compressed"} and set(flags) <= {"not-compressed", "object"}
                    for flags in summary.get("matched_color_atlas_flags", [])),
            "Component lacks the measured lossless color texture policy")
    require(summary.get("rgb_max_allowance") == 1 and summary.get("rgb_rms_allowance") == .25,
            "Component changed the native error allowance")
    rows = summary.get("cases", [])
    require(len(rows) == summary.get("comparison_pairs") == summary.get("expected_comparison_pairs")
            and len({row.get("id") for row in rows}) == len(rows), "Component has incomplete or duplicate records")
    cases = [row for row in rows if not row.get("background_only")]
    controls = [row for row in rows if row.get("background_only")]
    expected = set(itertools.product([profile], directions, range(28), FRACTIONS, ZOOMS))
    actual = [(row.get("profile"), row.get("direction"), row.get("pose"),
               row.get("fractional_native_pixel_offset"), row.get("zoom")) for row in cases]
    require(len(actual) == len(expected) and set(actual) == expected, "Component matrix is not the complete Cartesian product")
    require(len(controls) == 1 and controls[0].get("profile") == profile
            and controls[0].get("id") == "control-background-" + profile
            and controls[0].get("maximum_rgb_error") == 0
            and controls[0].get("rms_rgb_error") == 0, "Component identity control did not pass exactly")
    for row in rows:
        require(row.get("passed") is True and 0 <= row.get("maximum_rgb_error", 256) <= 1
                and 0 <= row.get("rms_rgb_error", 256) <= .25
                and row.get("registration_border_error") == 0
                and row.get("reference_border_deviation", 256) <= 1,
                "Component contains a failed or incomplete comparison")
        hashes = row.get("screenshots_sha256", {})
        require(set(hashes) == {"separated", "reference"}
                and all(isinstance(value, str) and len(value) == 64
                        and all(char in "0123456789abcdef" for char in value) for value in hashes.values()),
                "Component lacks captured image provenance")
        if not row.get("background_only"):
            require(row.get("reference_foreground_pixels", 0) >= max(16, 8 * row["zoom"] ** 2),
                    "Component comparison has no reference foreground")
    require(summary.get("maximum_rgb_error") == max(row["maximum_rgb_error"] for row in rows)
            and summary.get("maximum_case_rms_rgb_error") == max(row["rms_rgb_error"] for row in rows),
            "Component maxima disagree with its actual cases")
    geometry = summary.get("capture_geometry", {})
    require(geometry.get("passed") is True and geometry.get("method") == "entity-relative-camera-v3"
            and geometry.get("offset_units") == "engine-native-pixel-32-per-tile"
            and geometry.get("required_fractions") == FRACTIONS
            and geometry.get("groups_checked") == len(directions) * 28 * len(ZOOMS)
            and geometry.get("unvalidated_duplicate_pixel_groups") == [],
            "Component lacks the complete actual-camera geometry proof")
    duplicates = geometry.get("duplicate_pixel_groups")
    require(isinstance(duplicates, list), "Component lacks fractional alias diagnostics")
    if duplicates:
        require(geometry.get("pixel_phase_quantization_proven") is True
                and geometry.get("quantization_method") == "exact-native-screen-translations",
                "Component aliases lack exact translated-pixel proof")
    by_id = {row["id"]: row for row in cases}
    groups = set()
    for group in duplicates:
        key = tuple(group.get("group", []))
        require(len(key) == 4 and key[0] == profile and key not in groups, "Duplicate or foreign alias group")
        groups.add(key)
        aliases = group.get("cases", [])
        require(len(aliases) == 4 and sorted(row.get("fraction") for row in aliases) == FRACTIONS
                and len({row.get("pixels_sha256") for row in aliases}) >= 2, "Incomplete or stationary alias group")
        for alias in aliases:
            case = by_id.get(alias.get("case_id"), {})
            require(list(key) == [case.get("profile"), case.get("direction"), case.get("pose"), case.get("zoom")]
                    and alias.get("fraction") == case.get("fractional_native_pixel_offset"),
                    "Alias evidence does not belong to the actual case")
            shifts = alias.get("exact_screen_translations")
            require(isinstance(shifts, list) and shifts
                    and all(isinstance(offset, list) and len(offset) == 2
                            and all(type(value) is int and value >= 0 for value in offset) for offset in shifts)
                    and (alias["fraction"] == 0 or [0, 0] not in shifts), "Invalid exact screen translation")
    return summary


def aggregate_files(paths):
    require(len(paths) == 2, "Both single-profile full summaries are required")
    components, sources = {}, []
    for path in paths:
        path = Path(path).resolve()
        summary = json.loads(path.read_text(encoding="utf-8-sig"))
        profiles = summary.get("selected_profiles", [])
        require(profiles in (["sd"], ["hd"]) and profiles[0] not in components,
                "Aggregation requires exactly one SD and one HD run")
        profile = profiles[0]
        validate_component(summary, profile)
        manifest = path.parent / "color-input-manifest.json"
        require(manifest.is_file() and digest(manifest) == summary.get("input_manifest_sha256"),
                "Component's retained input manifest is missing or changed")
        inputs = json.loads(manifest.read_text(encoding="utf-8-sig"))
        require(inputs.get("metadata_sha256") == summary.get("compiled_metadata_sha256")
                and inputs.get("selected_profiles") == [profile]
                and inputs.get("reference_cells_sha256") == summary.get("reference_cells_sha256"),
                "Component manifest disagrees with its source/projection proof")
        components[profile] = summary
        sources.append({"profile": profile, "path": str(path), "sha256": digest(path),
                        "input_manifest_sha256": digest(manifest)})
    sd, hd = components["sd"], components["hd"]
    for key in ("compiled_metadata_sha256", "source_direction_count", "tested_direction_indices",
                "texture_compression_observed", "texture_compression_requested", "color_texture_policy",
                "color_texture_flags", "reference_selection", "analyzer_sha256"):
        require(sd.get(key) == hd.get(key), "Component provenance differs: " + key)
    result = copy.deepcopy(sd)
    result.pop("run", None)
    result.pop("input_manifest_sha256", None)
    result.pop("reference_cells_sha256", None)
    result["selected_profiles"] = ["sd", "hd"]
    result["cases"] = sd["cases"] + hd["cases"]
    result["comparison_pairs"] = result["expected_comparison_pairs"] = len(result["cases"])
    result["maximum_rgb_error"] = max(sd["maximum_rgb_error"], hd["maximum_rgb_error"])
    result["maximum_case_rms_rgb_error"] = max(sd["maximum_case_rms_rgb_error"], hd["maximum_case_rms_rgb_error"])
    result["color_leaf_flag_count"] = sd["color_leaf_flag_count"] + hd["color_leaf_flag_count"]
    for key in ("observed_atlas_flags", "matched_color_atlas_flags"):
        result[key] = [list(flags) for flags in sorted({tuple(flags) for row in (sd, hd) for flags in row[key]})]
    geometry = result["capture_geometry"]
    geometry["groups_checked"] += hd["capture_geometry"]["groups_checked"]
    geometry["duplicate_pixel_groups"] += hd["capture_geometry"]["duplicate_pixel_groups"]
    geometry["pixel_phase_quantization_proven"] = bool(geometry["duplicate_pixel_groups"])
    result["aggregation"] = {"schema": SCHEMA, "sources": sorted(sources, key=lambda row: row["profile"]),
                             "aggregator_sha256": digest(Path(__file__)), "control_count": 2}
    result["production_approved"] = False
    return result


def verify_aggregate(summary):
    aggregation = summary.get("aggregation", {})
    require(aggregation.get("schema") == SCHEMA, "Unsupported aggregate evidence schema")
    paths = [row["path"] for row in aggregation.get("sources", [])]
    require(summary == aggregate_files(paths), "Aggregate does not exactly reproduce its retained source summaries")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--sd", type=Path, required=True)
    parser.add_argument("--hd", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    if args.output.exists():
        parser.error("Refusing to overwrite existing evidence")
    summary = aggregate_files([args.sd, args.hd])
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"automated_checks_passed": summary["automated_checks_passed"],
                      "comparison_pairs": summary["comparison_pairs"], "production_approved": False}))
