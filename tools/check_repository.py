#!/usr/bin/env python3
"""Run host-independent documentation/release tests. No installs, tags or network."""
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
COMMANDS = [
    ["tools/docs/test_check.py"], ["tools/docs/test_inventory.py"],
    ["tools/docs/test_contracts.py"], ["tools/versioning/test_release.py"],
    ["tools/versioning/test_hooks.py"], ["tools/versioning/test_failures.py"],
    ["tools/docs/check.py"], ["tools/docs/inventory.py", "--check"],
    ["tools/docs/contracts.py"],
]


def main():
    for args in COMMANDS:
        print("CHECK:", " ".join(args), flush=True)
        result = subprocess.run([sys.executable, *args], cwd=ROOT)
        if result.returncode: return result.returncode
    return 0


if __name__ == "__main__": raise SystemExit(main())
