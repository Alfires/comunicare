#!/usr/bin/env python3
"""Provisioning path safety; key generation is separately exercised by Godot tests."""
import importlib.util
from pathlib import Path
import tempfile
import unittest

SPEC = importlib.util.spec_from_file_location("provision", Path(__file__).with_name("provision.py"))
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class ProvisionTests(unittest.TestCase):
    def test_repository_keys_rejected(self):
        with self.assertRaises(ValueError):
            MODULE.validate_destination(MODULE.ROOT / "private-test-relay")

    def test_existing_directory_not_overwritten(self):
        with tempfile.TemporaryDirectory(dir="/tmp/opencode") as directory:
            with self.assertRaises(ValueError):
                MODULE.validate_destination(directory)

    def test_new_external_path_accepted(self):
        with tempfile.TemporaryDirectory(dir="/tmp/opencode") as directory:
            target = Path(directory) / "new-relay"
            self.assertEqual(MODULE.validate_destination(target), target)


if __name__ == "__main__":
    unittest.main()
