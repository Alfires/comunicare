"""Test-first offline provenance contracts; no network or Godot required."""
import copy
import hashlib
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]


class ProvenanceTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(dir="/tmp/opencode")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        (self.root / "sample.bin").write_bytes(b"original sample")
        (self.root / "license.txt").write_text("CC0 1.0 Universal fixture terms")
        digest = hashlib.sha256(b"original sample").hexdigest()
        self.entry = dict(id="sample", title="Sample", author="Fixture author",
                          source="https://example.org/sample", license="CC0-1.0",
                          license_file="license.txt", license_sha256=hashlib.sha256((self.root / "license.txt").read_bytes()).hexdigest(),
                          retrieved="2026-11-05", attribution="", modifications="Unmodified",
                          files=[dict(path="sample.bin", sha256=digest,
                                      original_name="sample.bin", original_sha256=digest,
                                      download="https://example.org/sample.bin")])
        spec = importlib.util.spec_from_file_location("provenance", ROOT / "tools/assets/provenance.py")
        if spec is None or not Path(spec.origin).is_file():
            self.fail("Missing provenance validator: implement only after these tests run")
        self.module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(self.module)

    def validate(self, entries=None, document=None):
        entries = entries if entries is not None else [self.entry]
        data = {"version": 1, "assets": entries}
        document = document if document is not None else self.module.render_inventory(data)
        return self.module.validate(data, self.root, document)

    def test_valid_cc0(self):
        self.assertEqual([], self.validate())

    def test_required_fields(self):
        for key in ("id", "title", "author", "source", "license", "retrieved", "modifications", "files"):
            with self.subTest(key=key):
                entry = copy.deepcopy(self.entry)
                del entry[key]
                self.assertTrue(self.validate([entry]))

    def test_duplicate_ids(self):
        self.assertTrue(self.validate([self.entry, self.entry]))

    def test_missing_and_changed_files(self):
        for field in ("path", "sha256", "original_sha256", "original_name", "download"):
            entry = copy.deepcopy(self.entry)
            entry["files"][0][field] = "invalid"
            with self.subTest(field=field):
                self.assertTrue(self.validate([entry]))
        (self.root / "sample.bin").write_bytes(b"tampered")
        self.assertTrue(self.validate())

    def test_license_integrity(self):
        (self.root / "license.txt").write_text("tampered")
        self.assertTrue(self.validate())
        (self.root / "license.txt").unlink()
        self.assertTrue(self.validate())

    def test_policy_and_attribution(self):
        for license_id in ("unknown", "CC-BY-NC-4.0", "CC-BY-ND-4.0", "CC-BY-4.0"):
            entry = copy.deepcopy(self.entry)
            entry["license"] = license_id
            self.assertTrue(self.validate([entry]))
        entry["attribution"] = "Sample by Fixture author, CC BY 4.0; unmodified."
        (self.root / "license.txt").write_text("Creative Commons Attribution 4.0 fixture terms")
        entry["license_sha256"] = hashlib.sha256((self.root / "license.txt").read_bytes()).hexdigest()
        self.assertEqual([], self.validate([entry]))

    def test_document_drift(self):
        self.assertTrue(self.validate(document="invented inventory"))

    def test_unsafe_paths_and_urls(self):
        for path in ("../sample.bin", "/etc/passwd", "https://example.org/file"):
            entry = copy.deepcopy(self.entry)
            entry["files"][0]["path"] = path
            self.assertTrue(self.validate([entry]))
        self.entry["source"] = "file:///etc/passwd"
        self.assertTrue(self.validate())

    def test_unlisted_payload(self):
        payload = self.root / "assets/welcome_island/models"
        payload.mkdir(parents=True)
        (payload / "uncredited.glb").write_bytes(b"missing")
        self.assertTrue(self.validate())

    def test_schema_errors(self):
        for data in ({}, {"version": 2, "assets": []}, {"version": 1, "assets": [None]}):
            self.assertTrue(self.module.validate(data, self.root, ""))

    def test_nested_invalid_records(self):
        for files in ([None], ["not a file"], [], None):
            entry = copy.deepcopy(self.entry)
            entry["files"] = files
            self.assertTrue(self.validate([entry]))

    def test_unmodified_hashes_must_agree(self):
        self.entry["files"][0]["original_sha256"] = "0" * 64
        self.assertTrue(self.validate())

    def test_outside_symlink(self):
        (self.root / "external.bin").symlink_to("/etc/hosts")
        self.entry["files"][0]["path"] = "external.bin"
        self.assertTrue(self.validate())


if __name__ == "__main__":
    unittest.main()
