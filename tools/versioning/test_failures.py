"""Failure/recovery histories and remote rejection tested with local Git only."""
import base64
import json
from pathlib import Path
import subprocess
import tempfile
import unittest

from release import parse
from transaction import recover, JOURNAL

SCRIPT = Path(__file__).with_name("release.py")


class Tests(unittest.TestCase):
    def test_interrupted_recovery_and_invalid_journal(self):
        with tempfile.TemporaryDirectory(dir="/tmp/opencode") as directory:
            root = Path(directory)
            original = b"original Godot metadata"
            journal = {"VERSION": None, "CHANGELOG.md": None,
                       "project.godot": base64.b64encode(original).decode()}
            (root / JOURNAL).write_text(json.dumps(journal))
            (root / "VERSION").write_text("partial")
            (root / "project.godot").write_text("partial")
            recover(root)
            self.assertEqual((root / "project.godot").read_bytes(), original)
            self.assertFalse((root / "VERSION").exists())
            (root / JOURNAL).write_text('{"../outside": null}')
            with self.assertRaises(ValueError): recover(root)
            self.assertTrue((root / JOURNAL).exists())

    def test_malformed_journal_has_no_partial_recovery(self):
        with tempfile.TemporaryDirectory(dir="/tmp/opencode") as directory:
            root = Path(directory)
            (root / "VERSION").write_text("keep")
            (root / JOURNAL).write_text(json.dumps({"VERSION": None, "CHANGELOG.md": "invalid!", "project.godot": None}))
            with self.assertRaises(ValueError): recover(root)
            self.assertEqual((root / "VERSION").read_text(), "keep")

    def test_history_and_remote_failures(self):
        with tempfile.TemporaryDirectory(dir="/tmp/opencode") as directory:
            root = Path(directory)
            repo = root / "repo"
            repo.mkdir()
            def git(*args, cwd=repo, ok=True):
                result = subprocess.run(["git", *args], cwd=cwd, capture_output=True, text=True)
                if ok: self.assertEqual(result.returncode, 0, result.stderr)
                return result
            git("init", "-q", "-b", "main")
            git("config", "user.name", "Test")
            git("config", "user.email", "test@example.invalid")
            git("commit", "--allow-empty", "-qm", "chore: base")
            base = git("rev-parse", "HEAD").stdout.strip()
            def plan(baseline=base):
                return subprocess.run(["python3", str(SCRIPT), "plan", "--base", baseline, "--current", "0.1.0"], cwd=repo, capture_output=True, text=True)
            git("commit", "--allow-empty", "-qm", "docs: no release")
            self.assertFalse(json.loads(plan().stdout)["release"])
            git("checkout", "-qb", "feature")
            git("commit", "--allow-empty", "-qm", "feat: source feature")
            git("checkout", "-q", "main")
            git("merge", "--no-ff", "-m", "Merge topic", "feature")
            result = json.loads(plan().stdout)
            self.assertEqual(result["version"], "0.2.0")
            self.assertEqual(len([c for c in result["commits"] if c["type"] == "feat"]), 1)
            git("checkout", "--orphan", "unrelated")
            git("commit", "--allow-empty", "-qm", "chore: unrelated")
            other = git("rev-parse", "HEAD").stdout.strip()
            git("checkout", "-q", "main")
            self.assertNotEqual(plan(other).returncode, 0)
            self.assertNotEqual(plan("missing-tag").returncode, 0)
            git("commit", "--allow-empty", "-qm", "revert: source feature")
            self.assertEqual(json.loads(plan().stdout)["version"], "0.2.0")
            self.assertNotEqual(git("rev-parse", "--abbrev-ref", "@{upstream}", ok=False).returncode, 0)
            remote = root / "remote.git"
            git("init", "--bare", "-q", str(remote))
            git("remote", "add", "origin", str(remote))
            git("push", "-q", "origin", "main")
            # Receiver rejects all updates. Atomic push must leave both refs unchanged.
            hook = remote / "hooks/pre-receive"
            hook.write_text("#!/bin/sh\nexit 1\n")
            hook.chmod(0o755)
            previous = git("rev-parse", "refs/heads/main", cwd=remote).stdout
            git("commit", "--allow-empty", "-qm", "fix: next")
            git("tag", "-a", "v0.1.1", "-m", "fixture tag")
            rejected = git("push", "--atomic", "origin", "main", "refs/tags/v0.1.1", ok=False)
            self.assertNotEqual(rejected.returncode, 0)
            self.assertEqual(git("rev-parse", "refs/heads/main", cwd=remote).stdout, previous)
            self.assertNotEqual(git("show-ref", "--verify", "refs/tags/v0.1.1", cwd=remote, ok=False).returncode, 0)
            hook.unlink()
            competitor = root / "competitor"
            git("clone", "-q", "--branch", "main", str(remote), str(competitor))
            git("config", "user.name", "Other", cwd=competitor)
            git("config", "user.email", "other@example.invalid", cwd=competitor)
            git("commit", "--allow-empty", "-qm", "fix: competing update", cwd=competitor)
            git("push", "-q", "origin", "main", cwd=competitor)
            remote_head = git("rev-parse", "refs/heads/main", cwd=remote).stdout
            self.assertNotEqual(git("push", "--atomic", "origin", "main", "refs/tags/v0.1.1", ok=False).returncode, 0)
            self.assertEqual(git("rev-parse", "refs/heads/main", cwd=remote).stdout, remote_head)
            self.assertNotEqual(git("show-ref", "--verify", "refs/tags/v0.1.1", cwd=remote, ok=False).returncode, 0)
            shallow = root / "shallow"
            git("clone", "-q", "--depth", "1", "--branch", "main", remote.as_uri(), str(shallow))
            outcome = subprocess.run(["python3", str(SCRIPT), "plan", "--base", "HEAD", "--current", "0.1.0"], cwd=shallow, capture_output=True)
            self.assertNotEqual(outcome.returncode, 0)


if __name__ == "__main__": unittest.main()
