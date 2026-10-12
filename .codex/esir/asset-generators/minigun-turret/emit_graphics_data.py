"""Emit staged minigun graphics Lua and an exact source-to-package artifact map.

Never writes to a shipping mod. Fixture mode copies only selected PNG payloads;
production mode emits shipping paths without claiming native acceptance. Source
images remain byte-identical, including their sRGB/gAMA/cHRM chunks.
"""
import argparse
from hd_library_metadata import library_metadata
import copy
import hashlib
import importlib.util
import json
import math
import re
import shutil
import struct
from pathlib import Path, PurePosixPath

from PIL import Image

SOURCE_SHA256 = "453a8f5b75fd16630803d698293222cf9e07a3e1cecb1f7c3b40434d75008f59"
PACKS = {"sd": "exotic-space-industries-remembrance-graphics-6",
         "hd": "minigun-turret-HD"}
SEQUENCES = {"parked": [1], "running": [2], "preparing": [1, *range(3, 13), 2],
             "folding": [2, *range(13, 29), 1]}
REMAP = "atan2(sqrt(2)*sin(angle),cos(angle)) / (2*pi) mod 1"
TIERS = {"all_hd": {"base": "hd", "upper": "hd", "rotor": "hd"},
         "base_upper": {"base": "hd", "upper": "hd", "rotor": "sd"},
         "base_only": {"base": "hd", "upper": "sd", "rotor": "sd"},
         "all_sd": {"base": "sd", "upper": "sd", "rotor": "sd"}}
LEAF_KEYS = {"filename", "filenames", "width", "height", "frame_count", "line_length",
             "scale", "shift", "slice", "lines_per_file", "direction_count",
             "apply_projection", "counterclockwise", "draw_as_shadow"}


def require(condition, message):
    if not condition:
        raise ValueError(message)


def sha(payload):
    return hashlib.sha256(payload).hexdigest()


def read_json(path):
    return json.loads(path.read_text(encoding="utf-8-sig"))


def finite_pair(value, label):
    require(isinstance(value, list) and len(value) == 2 and
            all(isinstance(v, (int, float)) and math.isfinite(v) for v in value), label)


def relative_path(value):
    path = PurePosixPath(value)
    require(isinstance(value, str) and "\\" not in value and not path.is_absolute()
            and not any(p in ("..", ".") for p in path.parts) and ":" not in value,
            f"Unsafe relative asset path: {value!r}")
    return path


def color_chunks(payload):
    require(payload[:8] == b"\x89PNG\r\n\x1a\n", "Not a PNG")
    offset, result = 8, {}
    while offset < len(payload):
        size = struct.unpack(">I", payload[offset:offset + 4])[0]
        tag = payload[offset + 4:offset + 8].decode("ascii")
        if tag in ("sRGB", "gAMA", "cHRM"):
            require(tag not in result, f"Duplicate PNG color chunk {tag}")
            result[tag] = payload[offset + 8:offset + 8 + size].hex()
        offset += size + 12
    return result


def lua(value, depth=0, *, graphics_6_paths=False):
    if value is None:
        return "nil"
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, (int, float)):
        require(math.isfinite(value), "Nonfinite Lua number")
        return repr(value)
    if isinstance(value, str):
        require(all(ord(c) >= 32 for c in value), "Control characters in Lua string")
        prefix = "__" + PACKS["sd"] + "__/"
        if graphics_6_paths and value.startswith(prefix):
            return "ei_graphics_6_path.." + json.dumps(value[len(prefix):], ensure_ascii=False)
        return json.dumps(value, ensure_ascii=False)
    if isinstance(value, list):
        return "{" + ", ".join(lua(item, depth + 1, graphics_6_paths=graphics_6_paths) for item in value) + "}"
    if isinstance(value, dict):
        rows = []
        for key, item in value.items():
            name = key if re.fullmatch(r"[A-Za-z_][A-Za-z_0-9]*", key) else "[" + lua(key) + "]"
            rows.append("    " * (depth + 1) + name + " = " + lua(item, depth + 1, graphics_6_paths=graphics_6_paths) + ",")
        return "{\n" + "\n".join(rows) + "\n" + "    " * depth + "}"
    raise TypeError(type(value))


def validate_anchors(path, source_hash):
    anchors = read_json(path)
    require(anchors.get("source_sha256") == source_hash, "Muzzle proposal source differs from rendered model")
    require(anchors.get("status") == "geometry_proposal_not_native_calibrated"
            and anchors.get("height_compensation_verified") is False,
            "This emitter accepts the retained uncalibrated proposal only; calibrated evidence needs a separate reviewed integration")
    require(anchors.get("native_lookup_remap") == REMAP and anchors.get("candidate_effect_height_tiles") == 1,
            "Unrecognized muzzle lookup or effect-height proposal")
    visual, proposal = anchors.get("visual_anchors", []), anchors.get("creation_map_proposal", [])
    require(len(visual) == len(proposal) == 256, "Expected all 256 visual and creation-map entries even for a pilot")
    for i, row in enumerate(visual):
        require(row["direction"] == i and row["orientation"] == i / 256, "Muzzle visual direction ordering changed")
        finite_pair(row["visual_offset_tiles"], "Invalid visual muzzle offset")
    result = []
    for i, row in enumerate(proposal):
        require(row["orientation"] == i / 256, "Muzzle creation-map ordering changed")
        angle = math.tau * i / 256
        frame = ((math.atan2(math.sqrt(2) * math.sin(angle), math.cos(angle)) / math.tau) % 1) * 256
        lower, mix = math.floor(frame), frame % 1
        expected = [visual[lower]["visual_offset_tiles"][j] * (1 - mix)
                    + visual[(lower + 1) % 256]["visual_offset_tiles"][j] * mix for j in range(2)]
        finite_pair(row["visual_offset_tiles"], "Invalid mapped muzzle offset")
        actual = row["candidate_with_one_tile_effect_height"]
        finite_pair(actual, "Invalid candidate creation offset")
        require(max(abs(row["visual_offset_tiles"][j] - expected[j]) for j in range(2)) <= 1e-10,
                f"Stored native inverse-projection proposal disagrees at index {i}")
        require(abs(actual[0] - expected[0]) <= 1e-10 and abs(actual[1] - expected[1] - 1) <= 1e-10,
                f"Stored one-tile effect compensation disagrees at index {i}")
        # Preserve stored values exactly; validation must not silently recalibrate.
        result.append([row["orientation"], list(actual)])
    return result, {"status": anchors["status"], "source_sha256": source_hash,
                    "anchors_sha256": sha(path.read_bytes()), "native_lookup_remap": REMAP,
                    "height_compensation_verified": False, "candidate_effect_height_tiles": 1,
                    "native_calibrated": False, "creation_map_entries": 256,
                    "lookup_index_is_uniform_orientation": True}


class Emitter:
    def __init__(self, args):
        self.args = args
        self.root = args.compiled.resolve()
        self.meta_path = self.root / "metadata.json"
        self.meta = read_json(self.meta_path)
        self.meta_hash = sha(self.meta_path.read_bytes())
        self.directions = self.meta.get("direction_indices", [])
        require(self.meta.get("schema") == "esir.minigun.separated.compiled.v2", "Unsupported compiler metadata")
        require(self.meta.get("source_sha256") == SOURCE_SHA256, "Unexpected minigun source")
        n = len(self.directions)
        require(n in (8, 256) and self.directions == list(range(0, 256, 256 // n)),
                "Native emitter requires uniformly spaced pilot8 or full256 directions")
        require(self.meta.get("complete_direction_family") == (n == 256), "Incorrect complete-direction flag")
        require(args.mode != "production" or n == 256, "Production-shaped metadata requires all 256 real directions")
        require(self.meta.get("physical_pose_count") == 28 and self.meta.get("sequences") == SEQUENCES,
                "Physical/logical pose map differs from the verified native contract")
        require(self.meta.get("preparing_ticks") in (12, 18, 24, 30, 36, 45) and self.meta.get("folding_ticks") == 18,
                "Unsupported native state duration")
        self.color_profile = self.meta.get("png_color_profile_chunks", {})
        require(set(self.color_profile) == {"sRGB", "gAMA", "cHRM"}, "Missing compiler PNG color profile")
        self.signature = read_json(self.root / "compile-input.json")
        require(self.signature.get("configuration_hash") == self.meta.get("configuration_hash")
                and self.signature.get("directions") == self.directions
                and self.signature.get("preparing_ticks") == self.meta["preparing_ticks"], "Compiler signature mismatch")
        require(re.fullmatch(r"[0-9a-f]{64}", self.signature.get("script_sha256", "")) is not None,
                "Missing compiler source hash")
        self.artifacts, self.checked_pngs = {}, {}
        self.color_evidence = None
        self.color_eligible = False
        color_path = getattr(args, "color_evidence", None)
        if color_path:
            self.validate_color_evidence(color_path.resolve())
        self.shadow = None
        self.shadow_hash = None
        self.shadow_eligible = {"sd": False, "hd": False}
        self.shadow_final_policy = {"sd": False, "hd": False}
        self.shadow_evidence = None
        if args.shadow_candidates:
            self.shadow_root = args.shadow_candidates.resolve()
            self.shadow_path = self.shadow_root / "metadata.json"
            self.shadow = read_json(self.shadow_path)
            self.shadow_hash = sha(self.shadow_path.read_bytes())
            require(self.shadow.get("schema") == "esir.minigun.shadow-candidates.v1"
                    and self.shadow.get("native_law") == "alpha_over", "Unsupported shadow candidate representation")
            require(self.shadow.get("directions") == self.directions
                    and self.shadow.get("render_configuration_hash") == self.meta["configuration_hash"],
                    "Shadow candidates do not belong to this exact color render/direction set")
        else:
            require(args.shadow_tier in ("all_hd", "all_sd"), "Combined shadows cannot use a partial HD tier")
        if args.shadow_evidence:
            self.validate_shadow_evidence(args.shadow_evidence.resolve())
        if args.shadow_tier in ("base_upper", "base_only"):
            require(self.shadow is not None and self.shadow_eligible["hd"],
                    "Mixed-density residuals require exact native geometry/filter eligibility evidence; naive mixing is refused")

    def validate_color_evidence(self, path):
        evidence = read_json(path)
        geometry = evidence.get("capture_geometry", {})
        matrix = evidence.get("matrix")
        texture_policy = evidence.get("color_texture_policy", "native-default")
        lossless_flags = ["not-compressed"]
        flagged_lossless = (texture_policy == "not-compressed"
            and evidence.get("native_color_flags_verified") is True
            and evidence.get("color_leaf_flags_verified") is True
            and sorted(evidence.get("color_texture_flags") or []) == lossless_flags
            and any(set(flags) >= set(lossless_flags) and set(flags) <= set(lossless_flags) | {"object"}
                    for flags in evidence.get("matched_color_atlas_flags", [])))
        require(evidence.get("schema") == 1 and evidence.get("compiled_metadata_sha256") == self.meta_hash,
                "Color evidence is not bound to this exact compiled metadata")
        require(matrix in ("smoke", "full") and evidence.get("automated_checks_passed") is True
                and evidence.get("mathematical_composition_gate") is True
                and (evidence.get("texture_compression_observed") == "none" or flagged_lossless)
                and evidence.get("failures") == [],
                "Color evidence did not pass the uncompressed native comparison")
        duplicates = geometry.get("duplicate_pixel_groups")
        alias_proof = (isinstance(duplicates, list) and bool(duplicates)
            and geometry.get("pixel_phase_quantization_proven") is True
            and geometry.get("quantization_method") == "exact-native-screen-translations"
            and geometry.get("unvalidated_duplicate_pixel_groups") == [])
        require(geometry.get("method") == "entity-relative-camera-v3" and geometry.get("passed") is True
                and geometry.get("offset_units") == "engine-native-pixel-32-per-tile"
                and (duplicates == [] or alias_proof)
                and geometry.get("required_fractions") == ([0, .5] if matrix == "smoke" else [0, .25, .5, .75]),
                "Color evidence lacks the validated native fractional camera geometry")
        cases = evidence.get("cases", [])
        aggregate = evidence.get("aggregation") is not None
        if aggregate:
            module_path = Path(__file__).parent / "native-color-fixture" / "aggregate_evidence.py"
            spec = importlib.util.spec_from_file_location("minigun_color_aggregate", module_path)
            module = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(module)
            # Re-read both retained summaries and their manifests; a synthesized
            # union or one passed profile cannot claim the complete native gate.
            module.verify_aggregate(evidence)
        require(cases and len(cases) == evidence.get("comparison_pairs") == evidence.get("expected_comparison_pairs")
                and all(row.get("passed") is True for row in cases), "Color evidence has incomplete case coverage")
        # Check the actual case set, not merely a label that claims a full matrix.
        canaries = list(range(0, 256, 32))
        directions = ([0, 32, 96, 128] if matrix == "smoke"
                      else evidence.get("tested_direction_indices", canaries))
        require(isinstance(directions, list) and directions == sorted(set(directions))
                and all(direction in self.directions for direction in directions)
                and (matrix == "smoke" or set(canaries).issubset(directions)),
                "Color evidence lacks the required global direction canaries")
        poses = [0, 1, 7, 20] if matrix == "smoke" else list(range(28))
        fractions = [0, .5] if matrix == "smoke" else [0, .25, .5, .75]
        zooms = [1, 1.5] if matrix == "smoke" else [.75, 1, 1.5, 2]
        expected = {(profile, direction, pose, fraction, zoom) for profile in ("sd", "hd")
                    for direction in directions for pose in poses for fraction in fractions for zoom in zooms}
        actual = [(row.get("profile"), row.get("direction"), row.get("pose"),
                   row.get("fractional_native_pixel_offset"), row.get("zoom"))
                  for row in cases if not row.get("background_only")]
        controls = [row for row in cases if row.get("background_only")]
        expected_controls = 2 if aggregate else 1
        require(len(actual) == len(expected) and set(actual) == expected and len(controls) == expected_controls
                and all(row.get("maximum_rgb_error") == 0 for row in controls),
                "Color evidence matrix or identity control is incomplete")
        by_id = {row["id"]: row for row in cases}
        for group in duplicates:
            rows = group.get("cases", [])
            require(len(rows) == len(fractions) and sorted(row.get("fraction") for row in rows) == fractions
                    and len({row.get("pixels_sha256") for row in rows}) >= 2,
                    "Camera alias group is incomplete or never moves on screen")
            for row in rows:
                case = by_id.get(row.get("case_id"), {})
                require(group.get("group") == [case.get("profile"), case.get("direction"), case.get("pose"), case.get("zoom")]
                        and row.get("fraction") == case.get("fractional_native_pixel_offset"),
                        "Camera alias proof belongs to a different comparison case")
                translations = row.get("exact_screen_translations")
                require(isinstance(translations, list) and translations
                        and all(isinstance(offset, list) and len(offset) == 2
                                and all(isinstance(value, int) and value >= 0 for value in offset)
                                for offset in translations)
                        and (row["fraction"] == 0 or [0, 0] not in translations),
                        "Camera alias lacks exact nonzero native screen-translation evidence")
        require(evidence.get("maximum_rgb_error", 256) <= 1
                and evidence.get("maximum_case_rms_rgb_error", 256) <= .25,
                "Color evidence exceeds the native rounding allowance")
        self.color_eligible = (matrix == "full" and len(self.directions) == 256
                               and evidence.get("source_direction_count") == 256)
        require(self.args.mode != "production" or self.color_eligible,
                "Production strips require final256-metadata full native canary evidence")
        require(self.args.mode != "production" or flagged_lossless,
                "Production strips require validated per-sprite lossless textures with native filtering")
        self.color_evidence = {"path": str(path), "sha256": sha(path.read_bytes()),
                               "compiled_metadata_sha256": self.meta_hash, "matrix": matrix,
                               "tested_direction_indices": directions,
                               "color_texture_policy": texture_policy,
                               "color_texture_flags": lossless_flags if flagged_lossless else None,
                               "production_eligible": self.color_eligible}

    def validate_shadow_evidence(self, path):
        evidence = read_json(path)
        if self.shadow is None:
            require(evidence.get("schema") == "esir.minigun.native-shadow-evidence.v1"
                    and evidence.get("candidate_metadata_sha256") == self.meta_hash
                    and evidence.get("reference_metadata_sha256") == self.meta_hash,
                    "Combined shadow evidence is not bound to the exact final compiled metadata")
            require(evidence.get("automated_checks_passed") is True and evidence.get("failures") == [],
                    "Combined shadow evidence has failed comparisons")
            aggregated = evidence.get("aggregation") is not None
            if aggregated:
                module_path = Path(__file__).parent / "native-shadow-fixture" / "aggregate_evidence.py"
                spec = importlib.util.spec_from_file_location("minigun_shadow_aggregate", module_path)
                module = importlib.util.module_from_spec(spec)
                spec.loader.exec_module(module)
                module.verify_aggregate(evidence)
            require(self.args.mode != "production" or aggregated,
                    "Production combined shadows require the retained SD/HD serial full aggregate")
            full_source = (self.directions == list(range(256)) and evidence.get("source_direction_count") == 256)
            for profile in ("sd", "hd"):
                row = evidence.get("tiers", {}).get("combined_"+profile, {})
                self.shadow_eligible[profile] = bool(aggregated and full_source and row.get("native_eligible") is True)
                self.shadow_final_policy[profile] = bool(aggregated and full_source and row.get("final_policy_qualified") is True)
            self.shadow_evidence = {"path":str(path),"sha256":sha(path.read_bytes()),
                "representation":"combined","qualification":evidence.get("aggregation",{}).get("qualification","pilot-only")}
            return
        require(self.shadow is not None, "Residual shadow evidence requires --shadow-candidates")
        require(evidence.get("schema") == "esir.minigun.native-shadow-evidence.v1"
                and evidence.get("candidate_metadata_sha256") == self.shadow_hash
                and evidence.get("reference_metadata_sha256") == self.meta_hash,
                "Shadow eligibility evidence is not bound to these exact source manifests")
        global_pass = (evidence.get("matrix") == "full" and evidence.get("texture_compression_observed") == "none"
                       and evidence.get("automated_checks_passed") is True)
        for profile, tier in (("sd", "sd_baseline"), ("hd", self.args.shadow_tier)):
            row = evidence.get("tiers", {}).get(tier, {})
            families = {part: "sd" for part in ("base", "upper", "rotor")} if profile == "sd" else TIERS[tier]
            source_proofs = evidence.get("source_alpha", {})
            source_pass = all(source_proofs.get(p, {}).get("passed") is True for p in set(families.values()))
            self.shadow_eligible[profile] = (global_pass and source_pass and row.get("native_eligible") is True
                and row.get("reference_profile") == profile and row.get("families") == families)
        self.shadow_evidence = {"path": str(path), "sha256": sha(path.read_bytes())}

    def png(self, source, record):
        source = source.resolve()
        key = str(source)
        if key not in self.checked_pngs:
            payload = source.read_bytes()
            require(sha(payload) == record["sha256"] and len(payload) == record["bytes"], f"PNG hash/length changed: {source}")
            require(record.get("decoded_rgba_exact") is True, f"PNG lacks decoded-exact declaration: {source}")
            require(color_chunks(payload) == self.color_profile, f"PNG color profile changed: {source}")
            with Image.open(source) as image:
                require(image.format == "PNG" and 0 < min(image.size) and max(image.size) <= 4096,
                        f"Invalid PNG dimensions: {source}")
                expected = record.get("size")
                if isinstance(expected, int):
                    expected = [expected, expected]
                require(list(image.size) == expected, f"PNG dimensions disagree with metadata: {source}")
                decoded = image.convert("RGBA").tobytes()
                result = {"sha256": sha(payload), "bytes": len(payload), "size": list(image.size),
                          "decoded_rgba_sha256": sha(decoded), "decoded_rgba_bytes": len(decoded),
                          "png_color_profile_chunks": self.color_profile}
            self.checked_pngs[key] = result
        return self.checked_pngs[key]

    def asset(self, source, record, profile, family, destination, *, pack=None, directions=None):
        inspected = self.png(source, record)
        destination = relative_path(destination).as_posix()
        pack = pack or PACKS[profile]
        require(pack in PACKS.values(), "Unrecognized shipping pack")
        key = (pack, destination)
        fixture_path = f"{profile}/{destination}"
        artifact = {"source": str(source.resolve()), "pack": pack, "path": destination,
                    "profile": profile, "family": family, "fixture_path": fixture_path, **inspected}
        if directions is not None:
            artifact["global_direction_indices"] = directions
        if key in self.artifacts:
            require(self.artifacts[key] == artifact, f"Conflicting package destination: {key}")
        self.artifacts[key] = artifact
        if self.args.mode == "fixture":
            return f"__{self.args.fixture_mod}__/candidate/{fixture_path}"
        return f"__{pack}__/{destination}"

    def family(self, profile, family, *, residual=False, child_record=None):
        source_meta = self.shadow if residual else self.meta
        source_root = self.shadow_root if residual else self.root
        data = source_meta["profiles"][profile]
        record = child_record or data["families"][family]
        leaf = copy.deepcopy(record["leaf"] if child_record else data["leaves"][family])
        require(leaf == record["leaf"], f"Contradictory {profile}/{family} leaf")
        if "layers" in leaf:
            require(family == "rotor" and not residual and child_record is None
                    and set(leaf) == {"layers"} and len(leaf["layers"]) == 4,
                    "Only one exact four-strip rotor container is supported")
            require(self.color_evidence is not None,
                    "Rotor strips require exact hash-bound passed --color-evidence")
            require(self.args.mode != "production" or self.color_eligible,
                    "Production strips require complete256-direction full native evidence")
            child_layouts = record.get("layout", {}).get("children", [])
            require(len(child_layouts) == 4, "Missing four-strip spatial layout proof")
            files = {row["name"]: row for row in record["files"]}
            require(len(files) == len(record["files"]), "Duplicate strip image record")
            crop = record["crop"]; width, height = crop[2] - crop[0], crop[3] - crop[1]
            next_x = 0; mapped = []; used = []
            origin = None
            for index, (child, layout) in enumerate(zip(leaf["layers"], child_layouts)):
                require(layout.get("child") == index and layout.get("leaf") == child,
                        "Strip child ordering differs from spatial proof")
                rectangle = layout.get("source_pixel_rectangle")
                require(rectangle == [next_x, 0, next_x + child["width"], height]
                        and child["height"] == height, "Rotor child rectangles overlap or leave a gap")
                center = (rectangle[0] + rectangle[2]) / 2
                density = 32 if profile == "sd" else 64
                if origin is None:
                    origin = [child["shift"][0] - center / density, child["shift"][1]]
                require(abs(child["shift"][0] - (origin[0] + center / density)) <= 1e-10
                        and abs(child["shift"][1] - origin[1]) <= 1e-10,
                        "Rotor strip registration differs from its source rectangle")
                next_x = rectangle[2]
                paths = [child["filename"]] if "filename" in child else child["filenames"]
                names = [relative_path(path).name for path in paths]
                require(all(name in files for name in names), "Strip leaf lacks its recorded PNG")
                used.extend(names)
                child_data = {"leaf": child, "layout": layout["layout"], "files": [files[name] for name in names]}
                mapped.append(self.family(profile, family, child_record=child_data))
            require(next_x == width and len(used) == len(files) and set(used) == set(files),
                    "Rotor strips do not cover the exact logical crop and PNG set")
            return {"layers": mapped}
        require(set(leaf) <= LEAF_KEYS, f"Unreviewed sprite fields: {set(leaf) - LEAF_KEYS}")
        density = 32 if profile == "sd" else 64
        require(data["density"] == density and leaf["scale"] == 32 / density, "Unexpected sprite world scale")
        finite_pair(leaf["shift"], "Sprite shift must be finite")
        expected_frames = 1 if family in ("base", "upper") else 28
        require(leaf["frame_count"] == expected_frames, "Wrong physical frame count")
        if family == "base":
            require("direction_count" not in leaf, "Fixed base must be an ordinary Animation")
        else:
            require(leaf.get("direction_count") == len(self.directions) and leaf.get("apply_projection") is True
                    and leaf.get("counterclockwise") is False, "Unexpected native direction convention")
        require(bool(leaf.get("filename")) != bool(leaf.get("filenames")), "Exactly one filename representation is required")
        paths = [leaf["filename"]] if "filename" in leaf else leaf["filenames"]
        records = record["files"]
        require(len(paths) == len(records), "Atlas filename/record count differs")
        layout = record["layout"]
        columns, rows, per_file = layout["columns"], layout["rows"], layout["directions_per_file"]
        require(all(isinstance(v, int) and v > 0 for v in (columns, rows, per_file, leaf["width"], leaf["height"])),
                "Nonpositive atlas dimension")
        require(per_file & (per_file - 1) == 0 and leaf["line_length"] == columns, "Invalid physical direction stride")
        count = 1 if family == "base" else len(self.directions)
        require(len(paths) == math.ceil(count / per_file) and columns * rows >= per_file * expected_frames,
                "Atlas cannot hold the complete physical family")
        if expected_frames == 28:
            require(28 % columns == 0 and rows == per_file * (28 // columns), "Dynamic atlas does not preserve 28-frame stride")
        if len(paths) > 1:
            require(leaf.get("slice") == columns and leaf.get("lines_per_file") == rows, "Multi-file atlas stride mismatch")
        mapped = []
        for file_index, (path, image) in enumerate(zip(paths, records)):
            relative = relative_path(path)
            require(relative.parts == ("images", image["name"]), "Leaf points outside its recorded image family")
            require(image["size"] == [columns * leaf["width"], rows * leaf["height"]], "Atlas sheet dimensions mismatch")
            stem = image["name"]
            if residual:
                role = "rotor" if family == "shadow" else family
                prefix = f"minigun-{family}-"
                require(stem.startswith(prefix), "Unexpected shadow candidate filename")
                stem = f"minigun-shadow-{role}-" + stem[len(prefix):]
            pack = PACKS[profile]
            file_directions = None
            if profile == "sd" and family == "rotor" and not residual:
                file_directions = self.directions[file_index * per_file:(file_index + 1) * per_file]
                require(file_directions, "Rotor file has no directions")
            mapped.append(self.asset(source_root / profile / Path(relative), image, profile,
                                     ("shadow_" if residual else "") + family,
                                     "graphics/entities/gatling-turret/" + stem,
                                     pack=pack, directions=file_directions))
        leaf.pop("filename", None)
        leaf.pop("filenames", None)
        leaf["filename" if len(mapped) == 1 else "filenames"] = mapped[0] if len(mapped) == 1 else mapped
        if residual or family == "shadow":
            leaf["draw_as_shadow"] = True
        elif self.color_evidence and self.color_evidence.get("color_texture_flags"):
            leaf["flags"] = list(self.color_evidence["color_texture_flags"])
        return leaf

    def profile(self, name):
        source = self.meta["profiles"][name]
        require(source.get("direction_count") == len(self.directions) and source.get("icons_pending") is False,
                f"Incomplete {name} direction/icon payload")
        require(source.get("reconstruction", {}).get("maximum_rgba_error") == 0,
                f"{name} canonical pixel-center reconstruction is not exact")
        if self.args.mode == "production" and "layers" in source["leaves"]["rotor"]:
            proof = source["reconstruction"].get("directions", [])
            require([row.get("direction") for row in proof] == list(range(256))
                    and all(row.get("maximum_rgba_error") == 0 and row.get("differing_rgba_values") == 0
                            and [frame.get("pose") for frame in row.get("fractional_filter_frames", [])] == list(range(28))
                            for row in proof),
                    "Production strips require exact offline reconstruction of all7168 logical cells")
        profile = {family: self.family(name, family) for family in ("base", "upper", "rotor")}
        profile["complete_families"] = True
        profile["rotor_representation"] = "vertical_strips_4" if "layers" in profile["rotor"] else "single_leaf"
        profile["rotor_native_eligible"] = self.color_eligible if "layers" in profile["rotor"] else True
        if self.shadow:
            selection = {part: "sd" for part in ("base", "upper", "rotor")} if name == "sd" else TIERS[self.args.shadow_tier]
            profile["shadow_representation"] = "alpha_over_residual"
            profile["shadow_native_eligible"] = self.shadow_eligible[name]
            profile["shadows"] = {part: self.family(density, "shadow" if part == "rotor" else part, residual=True)
                                  for part, density in selection.items()}
            profile["shadow_family_profiles"] = selection
        else:
            profile["shadow_representation"] = "combined"
            density = "sd" if name == "sd" or self.args.shadow_tier == "all_sd" else "hd"
            require(self.args.mode != "production" or self.shadow_final_policy[density],
                    "Production combined shadows require final256 HQ native-shadow-policy qualification")
            profile["shadow"] = self.family(density, "shadow")
            profile["shadow_family_profiles"] = {"combined": density}
            profile["shadow_native_eligible"] = self.shadow_eligible[density]
            profile["shadow_final_policy_qualified"] = self.shadow_final_policy[density]
        for kind, directory in (("item", "items"), ("technology", "techs")):
            row = source["icons"][kind]
            expected = (128 if kind == "item" else 256) * (2 if name == "hd" else 1)
            require(row["size"] == expected and source[kind + "_icon"] == row["path"]
                    and source[kind + "_icon_size"] == expected, "Unexpected icon dimensions/path")
            relative = relative_path(row["path"])
            require(relative.parts[0] == "images", "Icon must belong to the compiler profile image directory")
            profile[kind + "_icon"] = self.asset(self.root / name / Path(relative), row, name, kind + "_icon",
                                                  f"graphics/{directory}/gatling-turret.png")
            profile[kind + "_icon_size"] = expected
        return profile

    def emit(self):
        creation, muzzle = validate_anchors(self.args.anchors.resolve(), self.meta["source_sha256"])
        profiles = {name: self.profile(name) for name in ("sd", "hd")}
        provenance = {"status": "staged_proposal_not_native_accepted", "production_promoted": False,
                      "native_load_tested": False, "native_filtered_seams_tested": False,
                      "native_ui_readability_tested": False, "muzzle_native_calibrated": False,
                      "compiled_metadata_sha256": self.meta_hash,
                      "render_configuration_hash": self.meta["configuration_hash"],
                      "source_sha256": self.meta["source_sha256"],
                      "compiler_sha256": self.signature["script_sha256"],
                      "emitter_sha256": sha(Path(__file__).read_bytes()),
                      "complete_direction_family": len(self.directions) == 256,
                      "direction_indices": self.directions, "shadow_tier": self.args.shadow_tier,
                      "shadow_representation": profiles["sd"]["shadow_representation"],
                      "shadow_metadata_sha256": self.shadow_hash,
                      "shadow_native_evidence": self.shadow_evidence,
                      "color_native_evidence": self.color_evidence,
                      "sd_pack": PACKS["sd"],
                      "connector_policy": "preserve existing production connector; user owns placement"}
        art = {"schema": "esir.minigun.graphics.v2", "hd_major": 1,
               "preparing_ticks": self.meta["preparing_ticks"], "folding_ticks": 18,
               "profiles": profiles, "projectile_creation_parameters": creation,
               "muzzle_proposal": muzzle, "provenance": provenance}
        # The package contract always uses shipping roots, even when the runnable
        # fixture table deliberately points at copies in its disposable helper.
        def shipping_value(value):
            if isinstance(value, dict):
                return {k: shipping_value(v) for k, v in value.items()}
            if isinstance(value, list):
                return [shipping_value(v) for v in value]
            if isinstance(value, str):
                for row in self.artifacts.values():
                    fixture = f"__{self.args.fixture_mod}__/candidate/{row['fixture_path']}"
                    if value == fixture:
                        return f"__{row['pack']}__/{row['path']}"
            return value

        artifact_map = {"schema": "esir.minigun.artifact-map.v1",
                        "complete_direction_family": len(self.directions) == 256,
                        "compiled_metadata_sha256": self.meta_hash,
                        "source_path_base": "absolute", "production_promoted": False,
                        "shadow_tier": self.args.shadow_tier,
                        "shadow_representation": profiles["sd"]["shadow_representation"],
                        "sd_pack_policy": {"pack": PACKS["sd"],
                            "families": "all standard-resolution colors, shadows and icons",
                            "unit": "complete files; every direction retains all 28 poses",
                            "pilot_assignment_is_not_full_family_budget": len(self.directions) != 256},
                        "frozen_profile_contract": shipping_value(art),
                        "artifacts": sorted(self.artifacts.values(), key=lambda r: (r["pack"], r["path"]))}
        # Preserve old staging evidence: a rerun must reproduce the same complete
        # request and source bytes before it can touch a previously emitted tree.
        output = self.args.output.resolve()
        staging = (Path.cwd() / "output").resolve()
        require(output.is_relative_to(staging) and output != staging and output != self.root
                and not self.root.is_relative_to(output), "Emitter output must be a dedicated repository output directory")
        request = {"mode": self.args.mode, "fixture_mod": self.args.fixture_mod,
                   "provenance": provenance, "anchors_sha256": muzzle["anchors_sha256"],
                   "artifacts": [{k: row[k] for k in ("source", "pack", "path", "sha256")} for row in artifact_map["artifacts"]]}
        request_path = output / "emit-input.json"
        if output.exists() and any(output.iterdir()):
            require(request_path.is_file() and read_json(request_path) == request,
                    "Emission inputs changed or output has unrelated files; choose a new output directory")
        output.mkdir(parents=True, exist_ok=True)
        request_path.write_text(json.dumps(request, indent=2) + "\n", encoding="utf-8")
        if self.args.mode == "fixture":
            for row in artifact_map["artifacts"]:
                destination = output / "candidate-assets" / row["fixture_path"]
                destination.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(row["source"], destination)
                require(sha(destination.read_bytes()) == row["sha256"], "Fixture copy changed PNG bytes")
        filename = "candidate-graphics-data.lua" if self.args.mode == "fixture" else "graphics-data.lua"
        header = ("-- Generated by emit_graphics_data.py; staged proposal, not native acceptance.\n"
                  "-- blueprint: .codex/esir/blueprints/minigun-turret-graphics.md#contract\n"
                  "-- Muzzle lookup/effect-height values are preserved uncalibrated proposals.\n"
                  "-- Production promotion and native gates are separate from this emitter.\n")
        bind_graphics_6 = self.args.mode == "production"
        (output / filename).write_text(header + "return " + lua(art, graphics_6_paths=bind_graphics_6) + "\n", encoding="utf-8")
        (output / "graphics-data.json").write_text(json.dumps(art, indent=2) + "\n", encoding="utf-8")
        artifact_map["graphics_data_filename"] = filename
        artifact_map["graphics_data_path_binding"] = "ei_graphics_6_path" if bind_graphics_6 else None
        artifact_map["graphics_data_sha256"] = sha((output / filename).read_bytes())
        # Reuse documentation is unloaded in the asset-only HD mod. Keep its
        # generated profile self-contained; only explicit SD shadow fallback
        # references may name Graphics 6. This draft retains the same calibration
        # flags, so the example refuses pilot/proposal data until final approval.
        example = library_metadata(shipping_value(art))
        example_path = output / "hd-example-graphics-data.lua"
        example_path.write_text("-- SPDX-License-Identifier: GPL-3.0-or-later\n"
            "-- Shared HD layout and calibrated native launch positions.\n"
            + "return " + lua(example) + "\n", encoding="utf-8")
        artifact_map["support_artifacts"] = [{"source": str(example_path), "pack": PACKS["hd"],
            "profile": "hd", "path": "lib/graphics-data.lua", "role": "graphics_library_metadata",
            "sha256": sha(example_path.read_bytes()), "bytes": example_path.stat().st_size}]
        (output / "artifact-map.json").write_text(json.dumps(artifact_map, indent=2) + "\n", encoding="utf-8")
        report = {"output": str(output), "candidate_data": str(output / filename),
                  "candidate_assets": str(output / "candidate-assets") if self.args.mode == "fixture" else None,
                  "artifact_map": str(output / "artifact-map.json"),
                  "direction_count": len(self.directions), "asset_count": len(self.artifacts),
                  "pack_png_bytes": {pack: sum(row["bytes"] for row in self.artifacts.values() if row["pack"] == pack)
                                     for pack in PACKS.values()},
                  "status": provenance["status"], "muzzle_calibrated": False,
                  "native_compression": ("Color leaves preserve measured native default sampling and use validated not-compressed textures; automatic cropping remains enabled"
                      if self.color_evidence and self.color_evidence.get("color_texture_flags") else
                      "Fixture retains native texture defaults; production requires tested per-sprite lossless color textures")}
        (output / "emitter-report.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
        return report


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--compiled", type=Path, required=True, help="Compiler output containing metadata.json and sd/hd images")
    parser.add_argument("--anchors", type=Path, required=True, help="Retained uncalibrated 256-direction muzzle-anchors.json")
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--mode", choices=("fixture", "production"), default="fixture")
    parser.add_argument("--fixture-mod", default="zzz-esir-minigun-firing")
    parser.add_argument("--shadow-candidates", type=Path, help="Optional alpha-over residual candidate directory")
    parser.add_argument("--shadow-tier", choices=tuple(TIERS), default="all_hd")
    parser.add_argument("--shadow-evidence", type=Path, help="Exact-input native shadow eligibility report; mandatory for mixed density")
    parser.add_argument("--color-evidence", type=Path, help="Exact-input passed camera-v3 lossless color evidence; mandatory for rotor strips")
    args = parser.parse_args(argv)
    require(re.fullmatch(r"[a-z0-9][a-z0-9-]*", args.fixture_mod) is not None, "Invalid fixture mod identifier")
    print("GRAPHICS_DATA_EMITTED " + json.dumps(Emitter(args).emit()), flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
