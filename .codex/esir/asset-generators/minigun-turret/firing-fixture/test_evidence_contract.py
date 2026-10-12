"""Offline rejection tests. Synthetic in-memory records never become native evidence."""
import copy
import json
import os
from pathlib import Path
import unittest
import uuid

from evidence_contract import (AMMO, BOUND_FILES, PILOT, SOURCE, canonical_sha, capture_names,
    capture_path, compare_launches, coverage_failures, expected_identities, fs_path,
    retain_captures, sha, summary_failures, build_candidate_asset_manifest, verify_candidate_asset_manifest)
from summarize_matrix import summarize

REPO = next(path for path in Path(__file__).resolve().parents
            if (path / 'scripts/invoke-esir-dev.ps1').is_file())
TEST_OUTPUT = REPO / 'output/minigun-firing-offline-tests/evidence'


def documents(coverage="full", calibration=False):
    ammunition = ["piercing-rounds-magazine"] if calibration else list(AMMO)
    config = {"schema": 1, "profile": "sd", "ballistic": True, "coverage": coverage,
              "calibration_only": calibration, "include_moving": not calibration,
              "direction_count": 256 if coverage == "full" else 8,
              "ammo_names": ammunition, "case_count": 8 if calibration else 337 if coverage == "full" else 89,
              "source_sha256": SOURCE, "candidate_data_sha256": "a" * 64,
              "mechanical_data_sha256": "b" * 64, "assets_manifest_sha256": "f" * 64}
    anchors = {"source_sha256": SOURCE, "visual_anchors": [
        {"direction": d, "visual_offset_tiles": [d / 256, -2]} for d in range(256)]}
    cases = []
    for ammo in ammunition:
        directions = range(256) if coverage == "full" and ammo == "piercing-rounds-magazine" else PILOT
        for d in directions:
            spec = {"id": f"d{d:03d}-{ammo}", "kind": "static", "ammo": ammo,
                    "requested_rendered_direction": d, "rounds": 1, "case_ticks": 220,
                    "visual_offset_tiles": anchors["visual_anchors"][d]["visual_offset_tiles"]}
            cases.append({"id": spec["id"], "spec": spec,
                          "rows": [{"variant": v} for v in ("native", "flash", "projectile", "blank")]})
    if not calibration:
        spec = {"id": "moving-aim-piercing", "kind": "moving", "ammo": "piercing-rounds-magazine",
                "requested_rendered_direction": 0, "rounds": 1024, "case_ticks": 420,
                "slew_ticks": 240, "visual_offset_tiles": [0, -2]}
        cases.append({"id": spec["id"], "spec": spec,
                      "rows": [{"variant": v} for v in ("native", "flash", "projectile", "blank")]})
    native = {"config": config, "cases": cases, "done": True, "errors": {}, "engine": "2.0.77",
              "prototype_audit": {"profile": "sd", "ballistic": True, "profile_enabled": False}}
    plan = {"config": copy.deepcopy(config), "cases": [copy.deepcopy(c["spec"]) for c in cases],
            "benchmark_ticks": sum(c["spec"]["case_ticks"] for c in cases) + 90}
    return native, plan, anchors


def unapproved_summary(native):
    config = native["config"]
    hashes = {name: "c" * 64 for name in BOUND_FILES.values()}
    hashes["candidate-graphics-data.lua"] = config["candidate_data_sha256"]
    hashes["candidate-mechanical-data.lua"] = config["mechanical_data_sha256"]
    hashes["candidate-assets-manifest.json"] = config["assets_manifest_sha256"]
    result = {key: config[key] for key in ("profile", "ballistic", "coverage", "calibration_only",
              "source_sha256", "candidate_data_sha256", "mechanical_data_sha256", "assets_manifest_sha256")}
    result.update({"status": "OFFLINE_TEST_ONLY_UNAPPROVED", "alignment_gate_passed": False,
                   "native_report_sha256": hashes["native-report.json"], "review_sha256": hashes["visual-review.json"],
                   "evidence": {"schema": "esir.minigun.firing-evidence.v1", "files": dict(hashes),
                                "configuration_sha256": canonical_sha(config)},
                   "cases": [{"id": c["id"], "ammo": c["spec"]["ammo"],
                              "requested_direction": c["spec"]["requested_rendered_direction"],
                              "observed_direction": c["spec"]["requested_rendered_direction"],
                              "failures": [], "pending_review": []}
                             for c in native["cases"] if c["spec"]["kind"] == "static"],
                   "moving": [{"id": "moving-aim-piercing", "sustained_sectors": list(range(8))}]
                             if not config["calibration_only"] else []})
    return result, hashes


class Coverage(unittest.TestCase):
    def test_exact_full_pilot_and_calibration_inventories(self):
        for coverage, calibration, count, ticks in (("full", False, 337, 74430),
                                                    ("pilot", False, 89, 19870),
                                                    ("pilot", True, 8, 1850)):
            native, plan, anchors = documents(coverage, calibration)
            self.assertEqual(len(expected_identities(native["config"])), count)
            self.assertEqual(plan["benchmark_ticks"], ticks)
            self.assertEqual(coverage_failures(native, plan, anchors), [])

    def test_self_consistent_reduced_ammo_plan_is_not_full(self):
        native, plan, anchors = documents()
        native["cases"] = [case for case in native["cases"] if case["spec"]["ammo"] != "ei-neutron-ammo"]
        native["config"]["ammo_names"].remove("ei-neutron-ammo")
        native["config"]["case_count"] -= 8
        plan["config"] = copy.deepcopy(native["config"])
        plan["cases"] = [copy.deepcopy(c["spec"]) for c in native["cases"]]
        self.assertTrue(coverage_failures(native, plan, anchors))

    def test_missing_duplicate_direction_and_contrast_variant_fail(self):
        for change in ("missing", "duplicate", "variant"):
            native, plan, anchors = documents()
            if change == "missing": native["cases"].pop(6)
            elif change == "duplicate": native["cases"][6] = copy.deepcopy(native["cases"][5])
            else: native["cases"][0]["rows"].append({"variant": "native"})
            plan["cases"] = [copy.deepcopy(c["spec"]) for c in native["cases"]]
            self.assertTrue(coverage_failures(native, plan, anchors))

    def test_moving_missing_or_calibration_expanded_is_rejected(self):
        native, plan, anchors = documents()
        native["config"]["include_moving"] = False
        self.assertTrue(coverage_failures(native, plan, anchors))
        native, plan, anchors = documents("pilot", True)
        native["config"]["include_moving"] = True
        with self.assertRaises(ValueError): expected_identities(native["config"])

    def test_native_config_and_prototype_attribution_switches_fail(self):
        for key, value in (("profile", "hd"), ("ballistic", False), ("source_sha256", "d" * 64)):
            native, plan, anchors = documents()
            native["config"][key] = value
            self.assertTrue(coverage_failures(native, plan, anchors))

    def test_additional_compact_control_config_is_allowed_but_bound(self):
        native, plan, anchors = documents()
        native["config"]["compact_heading_templates"] = True
        plan["config"]["compact_heading_templates"] = True
        self.assertEqual(coverage_failures(native, plan, anchors), [])
        summary, hashes = unapproved_summary(native)
        native["config"]["compact_heading_templates"] = False
        plan["config"]["compact_heading_templates"] = False
        self.assertTrue(summary_failures(summary, native, plan, anchors, hashes))

    def test_summary_swaps_stale_native_review_and_candidate_fail(self):
        native, plan, anchors = documents()
        summary, hashes = unapproved_summary(native)
        self.assertEqual(summary_failures(summary, native, plan, anchors, hashes), [])
        for name in ("native-report.json", "visual-review.json", "candidate-graphics-data.lua",
                     "candidate-mechanical-data.lua", "muzzle-anchors.json", "capture-manifest.json", "candidate-assets-manifest.json"):
            changed = dict(hashes); changed[name] = "e" * 64
            self.assertTrue(summary_failures(summary, native, plan, anchors, changed), name)
        switched = copy.deepcopy(summary); switched["profile"] = "hd"
        self.assertTrue(summary_failures(switched, native, plan, anchors, hashes))
        stale = copy.deepcopy(summary); stale["cases"].pop()
        self.assertTrue(summary_failures(stale, native, plan, anchors, hashes))


class CoordinateEvidence(unittest.TestCase):
    @staticmethod
    def observed(source=4.0, payload="instant"):
        return {"prototype_audit": {"delivery": payload}, "cases": [{"id": "static-test", "spec": {"kind": "static"},
            "rows": [{"variant": "native", "shots": [{"source": {"x": source, "y": 2}, "center": {"x": 3, "y": 4}}]}]}]}

    def test_payload_graph_difference_does_not_change_origin_comparison(self):
        self.assertTrue(compare_launches(self.observed(payload="instant"), self.observed(payload="projectile"), True))
        self.assertFalse(compare_launches(self.observed(), self.observed(4.25), True))

    def test_missing_nonfinite_or_empty_launch_observation_rejected(self):
        for value in (float("nan"), float("inf"), None):
            with self.assertRaises(ValueError): compare_launches(self.observed(), self.observed(value))
        empty = self.observed(); empty["cases"][0]["rows"][0]["shots"] = []
        with self.assertRaises(ValueError): compare_launches(self.observed(), empty)


class Retention(unittest.TestCase):
    def test_changed_candidate_png_rejected_when_lua_filename_is_unchanged(self):
        from PIL import Image
        root = TEST_OUTPUT / uuid.uuid4().hex
        references = []
        for profile in ("sd", "hd"):
            path = root / "candidate" / profile / "graphics/items/offline-test.png"
            path.parent.mkdir(parents=True)
            Image.new("RGBA", (2, 2), (7, 8, 9, 255)).save(path)
            references.append('__zzz-esir-minigun-firing__/candidate/' + profile + '/graphics/items/offline-test.png')
        data = root / "candidate-graphics-data.lua"
        data.write_text('-- OFFLINE UNIT TEST ONLY\nreturn {' + ','.join(json.dumps(x) for x in references) + '}\n')
        manifest = build_candidate_asset_manifest(data, root / "candidate")
        self.assertTrue(verify_candidate_asset_manifest(manifest, data, root / "candidate"))
        Image.new("RGBA", (2, 2), (44, 8, 9, 255)).save(root / "candidate/hd/graphics/items/offline-test.png")
        with self.assertRaises(ValueError): verify_candidate_asset_manifest(manifest, data, root / "candidate")

    def test_hardlink_retains_exact_bytes_without_second_physical_file(self):
        root = TEST_OUTPUT / uuid.uuid4().hex
        source = root / "raw/minigun-firing/test/0.png"
        fs_path(source.parent).mkdir(parents=True)
        fs_path(source).write_bytes(b"OFFLINE_UNIT_TEST_NOT_A_NATIVE_PNG")
        native = {"captures": [{"path": "minigun-firing/test/0.png"}, {"path": "minigun-firing/test/0.png"}]}
        manifest = retain_captures(root / "raw", root / "retained", native, "hardlink")
        target = root / "retained/minigun-firing/test/0.png"
        self.assertTrue(os.path.samefile(fs_path(source), fs_path(target)))
        self.assertEqual(manifest["native_report_capture_count"], 1)
        self.assertEqual(manifest["files"]["minigun-firing/test/0.png"]["sha256"], sha(source))
        # Different independent destinations are rejected, never overwritten.
        different = root / "other/minigun-firing/test/0.png"
        fs_path(different.parent).mkdir(parents=True)
        fs_path(different).write_bytes(b"DIFFERENT_UNIT_TEST_BYTES")
        with self.assertRaises(ValueError): retain_captures(root / "raw", root / "other", native, "hardlink")

    def test_capture_traversal_and_missing_matrix_never_pass(self):
        with self.assertRaises(ValueError): capture_path(Path.cwd(), "minigun-firing/../outside.png")
        with self.assertRaises(ValueError): capture_names({"path": "other-root/0.png"})
        missing = Path(__file__).parent / "deliberately-absent-native-evidence"
        result = summarize([missing] * 4, expected_candidate_sha256="a" * 64,
                           expected_mechanical_sha256="b" * 64, expected_anchors_sha256="c" * 64,
                           expected_assets_manifest_sha256="f" * 64)
        self.assertFalse(result["all_four_firing_configurations_passed"])
        self.assertTrue(result["failures"])


if __name__ == "__main__":
    unittest.main()
