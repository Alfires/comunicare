#!/usr/bin/env python3
"""Require a behavioral contract section for every named public production function."""
from pathlib import Path
import re
import sys

from inventory import collect, ROOT


def missing(inventory, text):
    sections = re.split(r"<!-- module: ([^ ]+) -->", text)
    covered = dict(zip(sections[1::2], sections[2::2]))
    errors = []
    for path, declarations in inventory.items():
        if path not in covered:
            errors.append(f"Missing module contract: {path}")
            continue
        body = covered[path]
        if len(body.strip()) < 150:
            errors.append(f"Contract section too short: {path}")
        for item in declarations:
            if item["kind"] == "func" and item["visibility"] == "public" and f"`{item['name']}`" not in body:
                errors.append(f"Missing public function contract: {path}::{item['name']}")
    for path in covered:
        if path not in inventory: errors.append(f"Stale module contract: {path}")
    return errors


def main():
    errors = missing(collect(), (ROOT / "docs/reference/functions.md").read_text())
    print("\n".join(errors) if errors else "All production modules/public functions have contract entries")
    return int(bool(errors))


if __name__ == "__main__": sys.exit(main())
