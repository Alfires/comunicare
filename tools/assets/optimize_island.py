#!/usr/bin/env python3
"""Rebuild only runtime island model variants in an isolated Godot project."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import hashlib
import json

ROOT = Path(__file__).resolve().parents[2]


def main():
    godot = shutil.which(os.environ.get("GODOT", "godot"))
    if not godot: return 2
    with tempfile.TemporaryDirectory(prefix="island-optimize-", dir="/tmp/opencode") as directory:
        project = Path(directory)
        shutil.copytree(ROOT / "assets/welcome_island", project / "assets/welcome_island", ignore=shutil.ignore_patterns("*.import", "*.uid", "runtime"))
        shutil.copy2(Path(__file__).with_suffix(".gd"), project / "optimize.gd")
        (project / "project.godot").write_text('config_version=5\n[application]\nconfig/name="Isolated island optimization"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n')
        env = {**os.environ, "XDG_DATA_HOME": str(project / "data"), "XDG_CONFIG_HOME": str(project / "config"), "XDG_CACHE_HOME": str(project / "cache")}
        for extra in (["--editor", "--import"], ["--script", "res://optimize.gd"]):
            result = subprocess.run([godot, "--headless", "--path", directory, *extra], capture_output=True, text=True, timeout=180, env=env)
            if result.returncode or "ERROR:" in result.stdout + result.stderr:
                print(result.stdout + result.stderr)
                return 2
            if "--script" in extra: print(result.stdout)
        output = ROOT / "assets/welcome_island/models/runtime"
        output.mkdir(exist_ok=True)
        for source in (project / "assets/welcome_island/models/runtime").glob("*.scn"):
            shutil.copy2(source, output / source.name)
        manifest = ROOT / "assets/welcome_island/manifest.json"
        data = json.loads(manifest.read_text())
        for entry in data["assets"]:
            if entry["id"] not in ("polyhaven.pine_sapling_small", "polyhaven.boulder_01", "polyhaven.fir_sapling"): continue
            original = next(item for item in entry["files"] if item["path"].endswith(".gltf"))
            entry["files"] = [item for item in entry["files"] if "/runtime/" not in item["path"]]
            prefix = entry["id"].split(".", 1)[1]
            for path in sorted(output.glob(prefix + "*.scn")):
                entry["files"].append(dict(path=path.relative_to(ROOT).as_posix(), sha256=hashlib.sha256(path.read_bytes()).hexdigest(),
                                           original_name=original["original_name"], original_sha256=original["original_sha256"], download=original["download"]))
            entry["modifications"] = "Publisher 1K glTF/buffer/textures preserved unchanged. Derived runtime scenes split individual variants, select Godot 4.7 meshoptimizer LOD topology up to 7000 triangles per surface, compact unused vertices and regenerate distance LODs. Rebuild: python3 tools/assets/optimize_island.py."
        manifest.write_text(json.dumps(data, indent=2) + "\n")
    return 0


if __name__ == "__main__": raise SystemExit(main())
