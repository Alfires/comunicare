import importlib.util
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

SCRIPT = Path(__file__).with_name("release.py")
spec = importlib.util.spec_from_file_location("release", SCRIPT)
release = importlib.util.module_from_spec(spec)
spec.loader.exec_module(release)


class Tests(unittest.TestCase):
    def test_transaction_rollback(self):
        from transaction import publish, JOURNAL
        import os
        with tempfile.TemporaryDirectory(dir="/tmp/opencode") as directory:
            root = Path(directory)
            (root / "project.godot").write_text("original")
            real_replace = os.replace
            calls = []
            def fail_once(source, destination):
                calls.append(destination)
                if len(calls) == 2: raise OSError("simulated disk failure")
                return real_replace(source, destination)
            with patch("transaction.os.replace", side_effect=fail_once):
                with self.assertRaises(OSError):
                    publish(root, {"VERSION": "1.0.0", "project.godot": "changed", "CHANGELOG.md": "new"})
            self.assertEqual((root / "project.godot").read_text(), "original")
            self.assertFalse((root / "VERSION").exists())
            self.assertFalse((root / JOURNAL).exists())

    def test_messages(self):
        for message, level in [("feat(cache): add storage", 2), ("fix: restore pose", 1),
                               ("docs: explain", 0), ("refactor!: remove API", 3),
                               ("chore: migrate\n\nBREAKING CHANGE: schema replaced", 3)]:
            self.assertEqual(release.parse(message)["level"], level)
        for bad in ["some changes", "unknown: test", "fix: "]:
            with self.assertRaises(ValueError): release.parse(bad)

    def test_temporary_history(self):
        with tempfile.TemporaryDirectory(dir="/tmp/opencode") as directory:
            def git(*args):
                return subprocess.check_output(["git", "-C", directory, *args], text=True).strip()
            git("init", "-q")
            git("config", "user.name", "Test")
            git("config", "user.email", "test@example.invalid")
            git("commit", "--allow-empty", "-qm", "chore: baseline")
            base = git("rev-parse", "HEAD")
            git("commit", "--allow-empty", "-qm", "fix: one")
            git("commit", "--allow-empty", "-qm", "feat: two")
            command = ["python3", str(SCRIPT), "plan", "--base", base, "--current", "0.1.0"]
            a = subprocess.check_output(command, cwd=directory, text=True)
            b = subprocess.check_output(command, cwd=directory, text=True)
            self.assertEqual(a, b)
            self.assertIn('"version": "0.2.0"', a)
            self.assertEqual(git("status", "--porcelain"), "")
            self.assertFalse((Path(directory) / "VERSION").exists())
            git("commit", "--allow-empty", "-qm", "fix!: breaking")
            c = subprocess.check_output(command, cwd=directory, text=True)
            self.assertIn('"version": "1.0.0"', c)
            preview = subprocess.check_output(command + ["--preview"], cwd=directory, text=True)
            self.assertIn('"version": "1.0.0-dev.3"', preview)
            (Path(directory) / "project.godot").write_text('config_version=5\n[application]\nconfig/name="Fixture"\nconfig/features=PackedStringArray("4.7")\n')
            git("add", "project.godot")
            git("commit", "-qm", "chore: add application")
            branch = git("branch", "--show-current")
            prepare = ["python3", str(SCRIPT), "prepare", "--base", base, "--current", "0.1.0", "--branch", branch]
            subprocess.check_call(prepare, cwd=directory, stdout=subprocess.DEVNULL)
            self.assertEqual((Path(directory) / "VERSION").read_text(), "1.0.0\n")
            self.assertIn('"4.7"', (Path(directory) / "project.godot").read_text())
            dirty = subprocess.run(prepare, cwd=directory, capture_output=True)
            self.assertNotEqual(dirty.returncode, 0)
            git("add", "VERSION", "project.godot", "CHANGELOG.md")
            git("commit", "-qm", "chore(release): 1.0.0")
            tag = ["python3", str(SCRIPT), "tag", "--base", base, "--version", "1.0.0", "--branch", branch]
            subprocess.check_call(tag, cwd=directory)
            self.assertEqual(git("cat-file", "-t", "v1.0.0"), "tag")
            self.assertNotEqual(subprocess.run(tag, cwd=directory, capture_output=True).returncode, 0)


if __name__ == "__main__": unittest.main()
