#!/usr/bin/env python3
"""Thirty isolated regression reproductions; no real accounts/network/keyring."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]

def main():
    godot = shutil.which(os.environ.get("GODOT", "godot"))
    if not godot:
        print("Godot required")
        return 2
    with tempfile.TemporaryDirectory(prefix="comunicare-audit-", dir="/tmp/opencode") as folder:
        project = Path(folder)
        for source in ("scripts/assets", "scripts/discovery/avatars"):
            shutil.copytree(ROOT / source, project / source)
        (project / "scripts/GUI").mkdir(parents=True)
        shutil.copy2(ROOT / "scripts/GUI/circular_value_control.gd", project / "scripts/GUI/circular_value_control.gd")
        shutil.copy2(Path(__file__).with_name("suite.gd"), project / "suite.gd")
        (project / "project.godot").write_text('config_version=5\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n')
        result = subprocess.run([godot, "--headless", "--path", folder, "--script", "res://suite.gd"], capture_output=True, text=True, timeout=60)
        output = result.stdout + result.stderr
        print(output, end="")
        return 2 if "ERROR:" in output else result.returncode

if __name__ == "__main__":
    raise SystemExit(main())
