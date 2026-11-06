#!/usr/bin/env python3
"""Converter location/rotation regressions without external archive downloads."""
import importlib.util
from pathlib import Path
import unittest

PATH = Path(__file__).with_name("convert_quaternius.py")
SPEC = importlib.util.spec_from_file_location("convert_quaternius", PATH)
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class ConverterTests(unittest.TestCase):
    def test_repository_root_after_move(self):
        self.assertEqual(MODULE.ROOT, Path(__file__).resolve().parents[2])
        self.assertTrue((MODULE.ROOT / "assets/animations").is_dir())

    def test_identity_quaternion_multiplication(self):
        value = (0.0, 0.0, 0.0, 1.0)
        self.assertEqual(tuple(MODULE.mul(value, value)), value)


if __name__ == "__main__":
    unittest.main()
