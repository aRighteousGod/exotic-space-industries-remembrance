"""Focused export-integrity checks; synthetic images are never public media."""
import hashlib
import json
from pathlib import Path
import shutil
import unittest
import uuid
from unittest.mock import patch

from PIL import Image
import portal_media as portal


class ExportIntegrity(unittest.TestCase):
    def setUp(self):
        portal.OUT.mkdir(parents=True, exist_ok=True)
        self.test_parent = portal.OUT.resolve()
        self.root = self.test_parent / ("test-" + uuid.uuid4().hex)
        self.root.mkdir()
        self.out = self.root / "output"
        self.directory = self.root / "capture"
        self.directory.mkdir()
        self.source = self.directory / "frame.png"
        Image.new("RGB", (64, 36), "red").save(self.source)
        self.candidate = self.out / "test" / "candidate"
        self.candidate.mkdir(parents=True)
        self.target = self.candidate / "demo.webp"
        Image.new("RGB", (64, 36), "red").save(self.target, "WEBP", save_all=True,
            append_images=[Image.new("RGB", (64, 36), "blue")], duration=[6000, 6000], loop=0)
        self.style = {"width": 64, "height": 36}
        portal.write(self.root / "portal/style.json", self.style)
        self.feature = {"id": "demo", "title": "Example"}
        self.batch = {"id": "test", "features": ["demo"]}
        self.state = {"capture_fingerprint": "current"}
        self.report = {"evidence": {"demo": {"pass": True}}}
        self.receipt = {
            "capture": self.state,
            "source_frames": [{"path": "frame.png", "sha256": portal.digest(self.source)}],
            "file_sha256": portal.digest(self.target),
            "style_sha256": portal.digest(self.root / "portal/style.json"),
            "renderer_sha256": portal.digest(portal.__file__),
            "feature_sha256": hashlib.sha256(json.dumps(self.feature, sort_keys=True).encode()).hexdigest(),
            "intended_duration_ms": 12000, "review": {"status": "pending"},
        }
        self.save_receipt()
        self.patches = [patch.object(portal, "ROOT", self.root), patch.object(portal, "OUT", self.out),
            patch.object(portal, "load_capture", return_value=(self.state, self.directory, self.report))]
        for replacement in self.patches:
            replacement.start()

    def tearDown(self):
        for replacement in reversed(self.patches):
            replacement.stop()
        assert self.root.resolve().is_relative_to(self.test_parent)
        shutil.rmtree(self.root)

    def save_receipt(self):
        portal.write(self.candidate / "demo.json", self.receipt)

    def validate(self):
        return portal.validate(self.batch, [self.feature], self.style)

    def test_decode_preserves_duration_without_editorial_approval(self):
        result = self.validate()
        self.assertEqual(result["media"][0]["duration_ms"], 12000)
        self.assertEqual(result["media"][0]["editorial_review"], "pending")

    def test_changed_source_frame_is_rejected(self):
        Image.new("RGB", (64, 36), "green").save(self.source)
        with self.assertRaisesRegex(ValueError, "source frame"):
            self.validate()

    def test_stale_capture_is_rejected(self):
        self.receipt["capture"] = {"capture_fingerprint": "old"}
        self.save_receipt()
        with self.assertRaisesRegex(ValueError, "older capture"):
            self.validate()

    def test_changed_copy_is_rejected(self):
        self.feature["title"] = "Changed after rendering"
        with self.assertRaisesRegex(ValueError, "Copy changed"):
            self.validate()

    def test_changed_timing_is_rejected(self):
        self.receipt["intended_duration_ms"] = 14000
        self.save_receipt()
        with self.assertRaisesRegex(ValueError, "timing"):
            self.validate()

    def test_failed_native_proof_is_rejected(self):
        self.report["evidence"]["demo"]["pass"] = False
        with self.assertRaisesRegex(ValueError, "native evidence"):
            self.validate()

    def test_source_cannot_escape_capture_directory(self):
        self.receipt["source_frames"][0]["path"] = "../outside.png"
        self.save_receipt()
        with self.assertRaisesRegex(ValueError, "source frame"):
            self.validate()


if __name__ == "__main__":
    unittest.main()
