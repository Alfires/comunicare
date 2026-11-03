#!/usr/bin/env python3
"""Validate proposed Git refs from pre-push stdin; never performs a push."""
from pathlib import Path
import subprocess
import sys

from release import git, parse


def main():
    try:
        for line in sys.stdin:
            local_ref, local_sha, remote_ref, remote_sha = line.split()
            if set(local_sha) == {"0"}: continue  # Deletion, not a new commit.
            if local_ref.startswith("refs/tags/"):
                if local_ref.startswith("refs/tags/v"):
                    from release import check_metadata, verify_release_commit
                    if git("rev-parse", local_sha + "^{commit}") != git("rev-parse", "HEAD"):
                        raise ValueError("Release tag must point to reviewed HEAD for metadata checking")
                    if local_ref != "refs/tags/v" + check_metadata(Path(git("rev-parse", "--show-toplevel"))):
                        raise ValueError("Tag/version mismatch")
                    verify_release_commit(Path(git("rev-parse", "--show-toplevel")), local_ref.removeprefix("refs/tags/v"))
                continue
            if set(remote_sha) == {"0"}:
                configured = subprocess.run(["git", "config", "--get", "comunicare.validationBase"], capture_output=True, text=True)
                if configured.returncode or not configured.stdout.strip():
                    raise ValueError("New branch needs explicit git config --local comunicare.validationBase <reviewed-base>")
                remote_sha = git("rev-parse", configured.stdout.strip() + "^{commit}")
                if subprocess.run(["git", "merge-base", "--is-ancestor", remote_sha, local_sha]).returncode:
                    raise ValueError("Configured validation base is not an ancestor of pushed branch")
            if subprocess.run(["git", "cat-file", "-e", remote_sha + "^{commit}"], capture_output=True).returncode:
                raise ValueError("Remote baseline absent locally; fetch with ordinary Git before pushing")
            for sha in git("rev-list", "--no-merges", remote_sha + ".." + local_sha).splitlines():
                parse(git("show", "-s", "--format=%B", sha))
        root = Path(__file__).resolve().parents[2]
        for tool in ["tools/docs/check.py", "tools/docs/inventory.py", "tools/docs/contracts.py", "tools/docs/privacy.py"]:
            command = [sys.executable, str(root / tool)]
            if tool.endswith("inventory.py"): command.append("--check")
            result = subprocess.run(command)
            if result.returncode: return result.returncode
        return 0
    except (ValueError, OSError, subprocess.CalledProcessError) as error:
        print(f"Pre-push check failed: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__": raise SystemExit(main())
