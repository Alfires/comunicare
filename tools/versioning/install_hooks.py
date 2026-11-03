#!/usr/bin/env python3
"""Explicitly opt in to repository-local hooks. Never overwrites existing policy."""
from pathlib import Path
import subprocess
import sys


def main():
    root = Path(subprocess.check_output(["git", "rev-parse", "--show-toplevel"], text=True).strip())
    current = subprocess.run(["git", "config", "--get", "core.hooksPath"], capture_output=True, text=True)
    if current.returncode == 0 and current.stdout.strip() != ".githooks":
        print("Existing core.hooksPath preserved; integrate hooks manually.", file=sys.stderr)
        return 1
    hooks = Path(subprocess.check_output(["git", "rev-parse", "--git-path", "hooks"], text=True).strip())
    if current.returncode != 0 and hooks.exists() and any(p.is_file() and not p.name.endswith(".sample") for p in hooks.iterdir()):
        print("Existing Git hooks preserved; integrate manually.", file=sys.stderr)
        return 1
    for name in ["commit-msg", "pre-push"]:
        path = root / ".githooks" / name
        path.chmod(path.stat().st_mode | 0o111)
    subprocess.run(["git", "config", "--local", "core.hooksPath", ".githooks"], check=True)
    print("Installed local hook path. Uninstall explicitly with git config --local --unset core.hooksPath")
    return 0


if __name__ == "__main__": raise SystemExit(main())
