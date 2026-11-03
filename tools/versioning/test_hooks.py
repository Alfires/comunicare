"""Actual hooks exercised in disposable Git repositories; no remote publication."""
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]


class Tests(unittest.TestCase):
    def test_install_and_messages(self):
        with tempfile.TemporaryDirectory(dir="/tmp/opencode") as directory:
            root = Path(directory)
            for name in [".githooks", "tools/versioning"]:
                shutil.copytree(ROOT / name, root / name, ignore=shutil.ignore_patterns("__pycache__"))
            def run(*args):
                return subprocess.run(args, cwd=root, text=True, capture_output=True)
            self.assertEqual(run("git", "init", "-q").returncode, 0)
            run("git", "config", "user.name", "Test")
            run("git", "config", "user.email", "test@example.invalid")
            run("git", "config", "--local", "core.hooksPath", "custom-hooks")
            installer = ("python3", "tools/versioning/install_hooks.py")
            self.assertNotEqual(run(*installer).returncode, 0)
            self.assertEqual(run("git", "config", "--get", "core.hooksPath").stdout.strip(), "custom-hooks")
            run("git", "config", "--unset", "core.hooksPath")
            self.assertEqual(run(*installer).returncode, 0)
            self.assertNotEqual(run("git", "commit", "--allow-empty", "-m", "invalid message").returncode, 0)
            self.assertEqual(run("git", "commit", "--allow-empty", "-m", "docs(test): valid message").returncode, 0)
            # Existing active default hooks must not be replaced either.
            run("git", "config", "--unset", "core.hooksPath")
            (root / ".git/hooks/pre-commit").write_text("#!/bin/sh\nexit 0\n")
            self.assertNotEqual(run(*installer).returncode, 0)

    def test_pre_push_refs(self):
        with tempfile.TemporaryDirectory(dir="/tmp/opencode") as directory:
            root = Path(directory)
            shutil.copytree(ROOT / "tools", root / "tools", ignore=shutil.ignore_patterns("__pycache__"))
            (root / "docs/reference").mkdir(parents=True)
            (root / "scripts").mkdir()
            (root / "relay_protocol").mkdir()
            (root / "docs/reference/symbols.json").write_text("{}\n")
            (root / "docs/reference/functions.md").write_text("# Empty fixture contracts\n")
            def git(*args):
                return subprocess.check_output(["git", *args], cwd=root, text=True).strip()
            git("init", "-q")
            git("config", "user.name", "Test")
            git("config", "user.email", "test@example.invalid")
            git("add", ".")
            git("commit", "-qm", "chore: fixture baseline")
            base = git("rev-parse", "HEAD")
            git("commit", "--allow-empty", "-qm", "fix: valid")
            head = git("rev-parse", "HEAD")
            def check(remote):
                return subprocess.run(["python3", "tools/versioning/pre_push.py"], cwd=root,
                    input=f"refs/heads/test {head} refs/heads/test {remote}\n", text=True, capture_output=True)
            self.assertEqual(check(base).returncode, 0)
            self.assertNotEqual(check("0" * 40).returncode, 0)
            git("config", "--local", "comunicare.validationBase", base)
            self.assertEqual(check("0" * 40).returncode, 0)
            git("commit", "--allow-empty", "-qm", "not conventional")
            head = git("rev-parse", "HEAD")
            self.assertNotEqual(check(base).returncode, 0)


if __name__ == "__main__": unittest.main()
