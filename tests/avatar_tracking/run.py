#!/usr/bin/env python3
"""Opt-in RED rig/calibration/FBT contracts; synthetic poses, no hardware."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent


def main():
    executable = shutil.which(os.environ.get("GODOT", "godot"))
    if not executable:
        print("Godot required (override with GODOT)")
        return 2
    with tempfile.TemporaryDirectory(prefix="comunicare-tracking-red-", dir="/tmp/opencode") as directory:
        project = Path(directory)
        shutil.copytree(ROOT / "scripts/assets", project / "scripts/assets")
        # Only tracking scripts are loaded; other copied assets are not autoloads.
        shutil.copy2(HERE / "suite.gd", project / "suite.gd")
        (project / "project.godot").write_text(
            'config_version=5\n[application]\nconfig/name="RED tracking contracts"\n'
            '[rendering]\nrenderer/rendering_method="gl_compatibility"\n')
        # Do not editor-import unrelated asset scripts that require client globals.
        result = subprocess.run([executable, "--headless", "--path", directory, "--script", "res://suite.gd"],
                                capture_output=True, text=True, timeout=60)
        output = result.stdout + result.stderr
        print(output, end="")
        return 2 if "ERROR:" in output else result.returncode


if __name__ == "__main__":
    raise SystemExit(main())
