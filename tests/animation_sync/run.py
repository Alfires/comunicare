#!/usr/bin/env python3
"""Disposable data-only animation and relay contracts."""
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
    with tempfile.TemporaryDirectory(prefix="comunicare-animation-", dir="/tmp/opencode") as directory:
        project = Path(directory)
        for folder in ("scripts/assets", "scripts/profile", "relay_protocol"):
            shutil.copytree(ROOT / folder, project / folder)
        (project / "scripts/multiplayer").mkdir(parents=True)
        shutil.copy2(ROOT / "scripts/multiplayer/relay.gd", project / "scripts/multiplayer/relay.gd")
        for source in ("scripts/startup/data_loader.gd", "scripts/GUI/animation_menue.gd", "scenes/GUI/animation_menue.tscn"):
            target = project / source
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(ROOT / source, target)
        shutil.copy2(HERE / "network.gd", project / "network.gd")
        shutil.copy2(HERE / "suite.gd", project / "suite.gd")
        (project / "project.godot").write_text(
            'config_version=5\n[application]\nconfig/name="Animation tests"\n'
            '[autoload]\nDataLoader="*res://scripts/startup/data_loader.gd"\nNetworkHandler="*res://network.gd"\n'
            '[rendering]\nrenderer/rendering_method="gl_compatibility"\n')
        for args in (["--editor", "--import"], ["--script", "res://suite.gd"]):
            try:
                result = subprocess.run([godot, "--headless", "--path", directory, *args],
                                        capture_output=True, text=True, timeout=30)
            except subprocess.TimeoutExpired as error:
                print((error.stdout or b"").decode() + (error.stderr or b"").decode())
                return 2
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
