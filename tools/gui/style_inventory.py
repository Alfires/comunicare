#!/usr/bin/env python3
"""List hard-coded GUI styling that should come from the shared theme.

Scans scripts/GUI/**/*.gd and scenes/GUI/**/*.tscn below --root. The theme
implementation itself (scripts/GUI/theme/) is excluded because it is the one
place where colors are defined.

Finding kinds:
  color_literal    Color(...), Color.html(...) or named Color constants in .gd files
  script_override  add_theme_*_override(...) calls in .gd files
  scene_override   theme_override_* properties in .tscn files

--check exits 1 when any finding is not allowlisted. Allowlist lines are
"relative/path:LINE # reason" or "relative/path:* # reason".
"""
import argparse
import json
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[2]
DEFAULT_ALLOWLIST = ROOT / "tools/gui/style_allowlist.txt"
COLOR = re.compile(r"\bColor(?:\(|\.html\b|\.[A-Z][A-Z_]{2,}\b)")
SCRIPT_OVERRIDE = re.compile(r"\badd_theme_\w+_override\s*\(")
SCENE_OVERRIDE = re.compile(r"^\s*theme_override_")
EXCLUDED = ("scripts/GUI/theme/",)


def code_part(line):
    """Drop a trailing GDScript comment, ignoring # inside strings."""
    quote = None
    for index, character in enumerate(line):
        if quote:
            if character == "\\":
                continue
            if character == quote:
                quote = None
        elif character in "\"'":
            quote = character
        elif character == "#":
            return line[:index]
    return line


def scan(root):
    findings = []
    for folder, pattern in (("scripts/GUI", "*.gd"), ("scenes/GUI", "*.tscn")):
        base = root / folder
        if not base.is_dir():
            continue
        for path in sorted(base.rglob(pattern)):
            relative = path.relative_to(root).as_posix()
            if relative.startswith(EXCLUDED):
                continue
            for number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
                if path.suffix == ".gd":
                    code = code_part(line)
                    if COLOR.search(code):
                        findings.append({"path": relative, "line": number, "kind": "color_literal"})
                    if SCRIPT_OVERRIDE.search(code):
                        findings.append({"path": relative, "line": number, "kind": "script_override"})
                elif SCENE_OVERRIDE.match(line):
                    findings.append({"path": relative, "line": number, "kind": "scene_override"})
    return findings


def load_allowlist(path):
    entries = set()
    if path is None or not path.is_file():
        return entries
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.split(" # ", 1)[0].strip()
        if not line or line.startswith("#"):
            continue
        target, _, where = line.rpartition(":")
        if target:
            entries.add((target, where))
    return entries


def allowed(finding, entries):
    return (finding["path"], "*") in entries or (finding["path"], str(finding["line"])) in entries


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--root", type=Path, default=ROOT)
    parser.add_argument("--json", action="store_true", help="print all findings as JSON")
    parser.add_argument("--check", action="store_true", help="exit 1 on findings that are not allowlisted")
    parser.add_argument("--allowlist", type=Path, default=None)
    args = parser.parse_args()
    root = args.root.resolve()
    allowlist = args.allowlist if args.allowlist is not None else (DEFAULT_ALLOWLIST if root == ROOT else None)
    findings = scan(root)
    if args.json:
        print(json.dumps(findings, indent=1))
        return 0
    entries = load_allowlist(allowlist)
    remaining = [item for item in findings if not allowed(item, entries)]
    for item in remaining:
        print(f"{item['path']}:{item['line']}: {item['kind']}")
    print(f"{len(remaining)} hard-coded styling finding(s), {len(findings) - len(remaining)} allowlisted", file=sys.stderr)
    return 1 if args.check and remaining else 0


if __name__ == "__main__":
    raise SystemExit(main())
