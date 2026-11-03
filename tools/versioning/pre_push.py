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
                    from release import check_metadata
                    if git("rev-parse", local_sha + "^{commit}") != git("rev-parse", "HEAD"):
                        raise ValueError("Release tag must point to reviewed HEAD for metadata checking")
                    if local_ref != "refs/tags/v" + check_metadata(Path(git("rev-parse", "--show-toplevel"))):
                        raise ValueError("Tag/version mismatch")
                continue
            if set(remote_sha) == {"0"}:
                # Do not lint all legacy history or guess a new branch baseline.
                raise ValueError("New remote branch: validate an explicit baseline range before publishing; this hook requires an existing remote branch")
            if subprocess.run(["git", "cat-file", "-e", remote_sha + "^{commit}"], capture_output=True).returncode:
                raise ValueError("Remote baseline absent locally; fetch with ordinary Git before pushing")
            for sha in git("rev-list", "--no-merges", remote_sha + ".." + local_sha).splitlines():
                parse(git("show", "-s", "--format=%B", sha))
        root = Path(__file__).resolve().parents[2]
        for tool in ["tools/docs/check.py", "tools/docs/inventory.py"]:
            command = [sys.executable, str(root / tool)]
            if tool.endswith("inventory.py"): command.append("--check")
            result = subprocess.run(command)
            if result.returncode: return result.returncode
        return 0
    except (ValueError, OSError, subprocess.CalledProcessError) as error:
        print(f"Pre-push check failed: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__": raise SystemExit(main())
