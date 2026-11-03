import importlib.util
from pathlib import Path
import subprocess
import tempfile
import unittest

SCRIPT = Path(__file__).with_name("release.py")
spec = importlib.util.spec_from_file_location("release", SCRIPT)
release = importlib.util.module_from_spec(spec)
spec.loader.exec_module(release)


class Tests(unittest.TestCase):
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


if __name__ == "__main__": unittest.main()
