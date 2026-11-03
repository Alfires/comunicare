#!/usr/bin/env python3
"""Deterministic GDScript declaration inventory, not generated behavioral claims."""
import argparse
import io
import json
from pathlib import Path
import re
import sys
import tokenize

ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / "docs/reference/symbols.json"


def declarations(text):
    # Python's tokenizer understands the strings/comments/brackets used by
    # GDScript declarations; invalid expression tokens do not affect headers.
    tokens = []
    try:
        for token in tokenize.generate_tokens(io.StringIO(text).readline):
            if token.type not in [tokenize.COMMENT, tokenize.STRING]: tokens.append(token)
    except (tokenize.TokenError, IndentationError):
        raise ValueError("Unbalanced declarations; inventory refuses partial output")
    found = []
    for index, token in enumerate(tokens):
        if token.string not in ["func", "signal", "class", "class_name"]: continue
        if index and tokens[index - 1].string == ".": continue
        following = tokens[index + 1:]
        if not following or following[0].type != tokenize.NAME: continue
        name = following[0].string
        depth = 0
        end = token.end
        for item in following:
            if item.string in ["(", "[", "{"]: depth += 1
            elif item.string in [")", "]", "}"]: depth -= 1
            if depth == 0 and (item.string == ":" or item.type == tokenize.NEWLINE): break
            end = item.end
        lines = text.splitlines()
        start_line, start_column = token.start
        end_line, end_column = end
        segment = lines[start_line - 1:end_line]
        segment[0] = segment[0][start_column:]
        segment[-1] = segment[-1][:end_column] if len(segment) > 1 else segment[-1][:end_column - start_column]
        found.append({"kind": token.string, "name": name, "line": start_line,
                      "signature": " ".join(line.strip() for line in segment),
                      "visibility": "private" if name.startswith("_") else "public"})
    return found


def collect():
    return {p.relative_to(ROOT).as_posix(): declarations(p.read_text())
            for folder in ["scripts", "relay_protocol"] for p in sorted((ROOT / folder).rglob("*.gd"))}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    try:
        content = json.dumps(collect(), indent=2, ensure_ascii=False) + "\n"
        if args.check:
            if not OUTPUT.exists() or OUTPUT.read_text() != content:
                print("Symbol inventory stale: run python3 tools/docs/inventory.py", file=sys.stderr)
                return 1
        else: OUTPUT.write_text(content)
        print("Production symbol inventory matches source" if args.check else "Updated production symbol inventory")
        return 0
    except ValueError as error:
        print(error, file=sys.stderr)
        return 1


if __name__ == "__main__": raise SystemExit(main())
