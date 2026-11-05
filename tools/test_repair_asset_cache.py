#!/usr/bin/env python3
"""Disposable repair regressions; never reads real user data."""
import json
from pathlib import Path
import tempfile
import unittest

from repair_asset_cache import repair


class RepairTests(unittest.TestCase):
    def setUp(self):
        self.folder = tempfile.TemporaryDirectory(dir="/tmp/opencode")
        self.addCleanup(self.folder.cleanup)
        self.path = Path(self.folder.name) / "index.json"
        self.document = {"schema": 1, "sources": {}}

    def write(self, content):
        self.path.write_text(content)

    def test_trailing_data_backup_and_idempotence(self):
        original = json.dumps(self.document) + "xx"
        self.write(original)
        self.assertIn("Repaired", repair(self.path))
        self.assertEqual(json.loads(self.path.read_text()), self.document)
        backups = list(self.path.parent.glob("*.bak"))
        self.assertEqual(len(backups), 1)
        self.assertEqual(backups[0].read_text(), original)
        self.assertIn("Healthy", repair(self.path))

    def test_dry_run_does_not_write(self):
        original = json.dumps(self.document) + "junk"
        self.write(original)
        self.assertIn("Repairable", repair(self.path, True))
        self.assertEqual(self.path.read_text(), original)
        self.assertEqual(len(list(self.path.parent.iterdir())), 1)

    def test_healthy_untouched(self):
        original = json.dumps(self.document) + "\n  "
        self.write(original)
        self.assertIn("Healthy", repair(self.path))
        self.assertEqual(self.path.read_text(), original)

    def test_unsafe_documents_preserved(self):
        for original in ['not json', '{"schema":1', '{"schema":2,"sources":{}}junk',
                         '{"schema":1,"sources":{"bad":{}}}junk',
                         '{"schema":1,"schema":1,"sources":{}}junk']:
            self.write(original)
            with self.assertRaises(ValueError):
                repair(self.path)
            self.assertEqual(self.path.read_text(), original)

    def test_records_preserved(self):
        self.document["sources"]["source-key"] = {"kind": "avatar", "hash": "a" * 64,
            "size": 123, "checked": 1, "accessed": 2, "pinned": True}
        self.write(json.dumps(self.document) + "}}")
        repair(self.path)
        self.assertEqual(json.loads(self.path.read_text()), self.document)

    def test_symlink_refused(self):
        target = self.path.parent / "original"
        target.write_text(json.dumps(self.document) + "junk")
        self.path.symlink_to(target)
        with self.assertRaises(ValueError):
            repair(self.path)


if __name__ == "__main__":
    unittest.main()
