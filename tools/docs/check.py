#!/usr/bin/env python3
"""Offline Markdown file/heading link checker. Never follows external URLs."""
from pathlib import Path
import re
import subprocess
import sys
import argparse
from urllib.parse import unquote

ROOT = Path(__file__).resolve().parents[2]


def anchors(text):
    result = set()
    counts = {}
    fenced = False
    for line in text.splitlines():
        if line.startswith(("```", "~~~")):
            fenced = not fenced
            continue
        if fenced: continue
        match = re.match(r"^#{1,6}\s+(.+?)\s*#*\s*$", line)
        if not match: continue
        name = re.sub(r"[^\w\- ]", "", match[1].lower()).replace(" ", "-")
        count = counts.get(name, 0)
        counts[name] = count + 1
        result.add(name + (f"-{count}" if count else ""))
    return result


def check_file(path):
    text = path.read_text()
    text = re.sub(r"```.*?```|~~~.*?~~~", "", text, flags=re.S)
    errors = []
    for target in re.findall(r"\]\(([^\s)]+)(?:\s+\"[^\"]*\")?\)", text):
        if re.match(r"^[a-zA-Z][a-zA-Z0-9+.-]*:", target): continue
        name, _, anchor = unquote(target).partition("#")
        destination = (path.parent / name).resolve() if name else path.resolve()
        if not destination.exists():
            errors.append(f"{path}: missing {target}")
        elif anchor and destination.suffix == ".md" and anchor not in anchors(destination.read_text()):
            errors.append(f"{path}: missing anchor {target}")
    return errors


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--changed", action="store_true", help="Check changed tracked Markdown only")
    args = parser.parse_args()
    names = subprocess.check_output(["git", "ls-files", "-z", "--", "*.md"], cwd=ROOT).decode().split("\0")
    if args.changed:
        changed = subprocess.check_output(["git", "diff", "HEAD", "--name-only", "-z", "--", "*.md"], cwd=ROOT).decode().split("\0")
        names = [name for name in names if name in changed]
    # Vendored manuals may reference assets intentionally not included here.
    errors = [error for name in names if name and not name.startswith("addons/") and (ROOT / name).exists() for error in check_file(ROOT / name)]
    print("\n".join(errors) if errors else "Tracked Markdown local links/anchors pass")
    return int(bool(errors))


if __name__ == "__main__": sys.exit(main())
