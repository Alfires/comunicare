#!/usr/bin/env python3
"""Green self-tests for the RED runner/fixture generator, not world implementation."""
import hashlib
import importlib.util
import json
from pathlib import Path
import struct
import subprocess
import tempfile
import unittest
import zipfile
import zlib

SPEC = importlib.util.spec_from_file_location("world_red_runner", Path(__file__).with_name("run.py"))
RUNNER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(RUNNER)


class RunnerTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(dir="/tmp/opencode" if Path("/tmp/opencode").is_dir() else None)
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.revision = RUNNER.write_packages(self.root)

    def test_valid_manual_package_and_hash(self):
        archive = self.root / "valid.zip"
        self.assertEqual(self.revision, hashlib.sha256(archive.read_bytes()).hexdigest())
        with zipfile.ZipFile(archive) as package:
            manifest = json.loads(package.read("manifest.json"))
            self.assertIn(manifest["main_scene"], package.namelist())
            self.assertEqual(len(package.namelist()), 4)
            self.assertFalse(any(name.startswith(("addons/", ".godot/")) for name in package.namelist()))
            material = package.read("materials/surface.tres").decode()
            self.assertIn("normal_texture", material)
            png = package.read("textures/pixel.png")
        self.assertEqual(png[:8], b"\x89PNG\r\n\x1a\n")
        position = 8
        image = b""
        while position < len(png):
            size = struct.unpack(">I", png[position:position + 4])[0]
            chunk = png[position + 4:position + 8 + size]
            self.assertEqual(zlib.crc32(chunk), struct.unpack(">I", png[position + 8 + size:position + 12 + size])[0])
            if chunk[:4] == b"IDAT":
                image += chunk[4:]
            position += size + 12
        self.assertEqual(zlib.decompress(image), b"\x00\xff\xff\xff\xff")

    def test_attack_fixtures_are_really_hostile(self):
        with zipfile.ZipFile(self.root / "duplicate_entry.zip") as package:
            self.assertEqual(package.namelist().count("textures/pixel.png"), 2)
        with zipfile.ZipFile(self.root / "symlink.zip") as package:
            self.assertEqual(package.getinfo("textures/link").external_attr >> 16, 0o120777)
        with zipfile.ZipFile(self.root / "attached_script.zip") as package:
            self.assertIn(b'script = ExtResource("9")', package.read("scenes/world.tscn"))
            self.assertIn(b"WORLD_SCRIPT_EXECUTED", package.read("evil.gd"))
        with zipfile.ZipFile(self.root / "expanded_limit.zip") as package:
            item = package.getinfo("padding.txt")
            self.assertGreater(item.file_size, 65536)
            self.assertLess(item.compress_size, 65536)
        with self.assertRaises(zipfile.BadZipFile):
            zipfile.ZipFile(self.root / "truncated.zip")

    def test_error_is_not_accepted_as_expected_red(self):
        def process(code, stdout="", stderr=""):
            return subprocess.CompletedProcess([], code, stdout, stderr)
        self.assertEqual(RUNNER.result_code(process(0)), 0)
        self.assertEqual(RUNNER.result_code(process(1, "FAIL: missing feature")), 1)
        self.assertEqual(RUNNER.result_code(process(1, stderr="SCRIPT ERROR: parse failed")), 2)
        self.assertEqual(RUNNER.result_code(process(0, "ERROR: load failed")), 2)
        self.assertEqual(RUNNER.result_code(process(-11)), 2)


if __name__ == "__main__":
    unittest.main()
