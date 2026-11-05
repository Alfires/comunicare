#!/usr/bin/env python3
"""Generate/check the built-in world's dependency revision before local export."""
import argparse
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / "scenes/worlds/welcome_island/revision.json"


def collect(root=ROOT):
    paths = {root / "scenes/world.tscn", root / "scenes/world.gd"}
    paths.update(root / name for name in ("scripts/worlds/world_pickup_controller.gd", "scripts/worlds/world_data.gd"))
    for folder in ("scenes/worlds/welcome_island", "scripts/worlds/welcome_island"):
        paths.update(path for path in (root / folder).rglob("*") if path.suffix in (".gd", ".tscn", ".tres", ".scn", ".gdshader"))
    # The built-in layout uses shared textures through dynamically composed paths.
    # Include all bundled island payloads conservatively so future placements
    # cannot silently keep an old revision. Exclude import metadata and notices.
    for folder in ("models", "textures", "sky"):
        paths.update(path for path in (root / "assets/welcome_island" / folder).rglob("*")
                     if path.is_file() and path.suffix not in (".import", ".uid"))
    return {path.relative_to(root).as_posix(): hashlib.sha256(path.read_bytes()).hexdigest()
            for path in sorted(paths)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    content = json.dumps({"version": 1, "files": collect()}, indent=2) + "\n"
    if args.check:
        if not OUTPUT.exists() or OUTPUT.read_text() != content:
            print("Built-in world revision manifest stale; run python3 tools/assets/build_home_revision.py")
            return 1
    else:
        OUTPUT.write_text(content)
    print("Built-in dependency revision manifest " + ("verified" if args.check else "generated"))
    return 0


if __name__ == "__main__": raise SystemExit(main())
