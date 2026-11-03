#!/usr/bin/env python3
"""Scan tracked repository files for private keys/runtime stores; never delete."""
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
PRIVATE_KEY = re.compile(rb"-----BEGIN (?:RSA |EC |OPENSSH |ENCRYPTED )?PRIVATE KEY-----")
RUNTIME_PARTS = {".godot", "asset_cache", "__pycache__"}


def violations(name, data):
    errors = []
    path = Path(name)
    parts = path.parts
    # tests/asset_cache is production-code test infrastructure, not user cache.
    if parts[:2] == ("tests", "asset_cache"): parts = parts[2:]
    if any(part in RUNTIME_PARTS for part in parts): errors.append("generated/runtime directory")
    if path.name in {"user.key", "user.cfg", ".release-transaction.json"} or name.endswith(".release-tmp"):
        errors.append("runtime account/recovery file")
    if PRIVATE_KEY.search(data): errors.append("private-key PEM material")
    return errors


def main():
    names = subprocess.check_output(["git", "ls-files", "-z"], cwd=ROOT).decode().split("\0")
    errors = []
    for name in names:
        if not name or not (ROOT / name).is_file(): continue
        # No contents are printed; diagnostics identify only the path/category.
        errors.extend(f"{name}: {reason}" for reason in violations(name, (ROOT / name).read_bytes()))
    print("\n".join(errors) if errors else "Tracked files contain no detected private-key/runtime-store artifacts")
    return int(bool(errors))


if __name__ == "__main__": sys.exit(main())
