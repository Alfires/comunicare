#!/usr/bin/env python3
"""Isolated production avatar-import responsiveness checks."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent


def main():
    godot = shutil.which(os.environ.get("GODOT", "godot"))
    if not godot:
        return 2
    with tempfile.TemporaryDirectory(prefix="comunicare-avatar-", dir="/tmp/opencode") as directory:
        project = Path(directory)
        for source in ["scripts/startup/data_loader.gd", "scripts/assets/asset_cache.gd", "relay_protocol/world_address.gd"]:
            target = project / source
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(ROOT / source, target)
        shutil.copy2(ROOT / "scripts/assets/humanoid_animation.gd", project / "scripts/assets/humanoid_animation.gd")
        for source in ["suite.gd", "slow_loader.gd"]:
            shutil.copy2(HERE / source, project / source)
        (project / "project.godot").write_text('config_version=5\n[application]\nconfig/name="Avatar import tests"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n')
        for args in [["--editor", "--import"], ["--script", "res://suite.gd"]]:
            result = subprocess.run([godot, "--headless", "--path", directory, *args], capture_output=True, text=True, timeout=90)
            output = result.stdout + result.stderr
            if "--script" in args or result.returncode or "ERROR:" in output:
                print(output, end="")
            if "ERROR:" in output:
                return 2
            if result.returncode:
                return result.returncode
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
