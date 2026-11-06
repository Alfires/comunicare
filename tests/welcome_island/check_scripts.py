#!/usr/bin/env python3
"""Cold parse built-in island dependencies without startup/accounts/imported art."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]


def main():
    godot = shutil.which(os.environ.get("GODOT", "godot"))
    if not godot:
        print("Godot required; set GODOT")
        return 2
    with tempfile.TemporaryDirectory(prefix="island-script-check-", dir="/tmp/opencode") as directory:
        project = Path(directory)
        shutil.copytree(ROOT / "scripts/worlds/welcome_island", project / "scripts/worlds/welcome_island",
                        ignore=shutil.ignore_patterns("*.uid"))
        (project / "project.godot").write_text('config_version=5\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n')
        paths = sorted((project / "scripts/worlds/welcome_island").glob("*.gd"))
        # Dependencies first, layout last: never substitute or silently omit one.
        paths.sort(key=lambda path: (path.name == "layout.gd", path.name))
        status = 0
        for path in paths:
            relative = path.relative_to(project).as_posix()
            try:
                result = subprocess.run([godot, "--headless", "--path", directory, "--check-only", "--script", "res://" + relative],
                                        capture_output=True, text=True, timeout=30,
                                        env={**os.environ, "XDG_DATA_HOME": str(project / "data"), "XDG_CONFIG_HOME": str(project / "config")})
            except subprocess.TimeoutExpired:
                print("TIMEOUT:", relative)
                return 2
            output = result.stdout + result.stderr
            if result.returncode or "ERROR:" in output:
                print("FAIL:", relative, "\n" + output)
                status = 1
            else:
                print("PASS:", relative)
        return status


if __name__ == "__main__":
    raise SystemExit(main())
