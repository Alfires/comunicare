#!/usr/bin/env python3
"""Opt-in RED contracts for the proposed collaborative in-game map editor."""
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
        print("Godot required; set GODOT")
        return 2
    with tempfile.TemporaryDirectory(prefix="comunicare-map-editor-", dir="/tmp/opencode") as directory:
        project = Path(directory)
        for relative in ("scripts/worlds", "scripts/editor", "addons/comunicare_world_tools"):
            if (ROOT / relative).is_dir():
                shutil.copytree(ROOT / relative, project / relative,
                                ignore=shutil.ignore_patterns(".godot", "__pycache__"))
        shutil.copytree(ROOT / "scripts/profile", project / "scripts/profile")
        shutil.copytree(ROOT / "relay_protocol", project / "relay_protocol")
        shutil.copy2(HERE / "network_suite.gd", project / "network_suite.gd")
        (project / "scripts/GUI").mkdir(parents=True, exist_ok=True)
        shutil.copy2(ROOT / "scripts/GUI/map_editor.gd", project / "scripts/GUI/map_editor.gd")
        shutil.copy2(HERE / "suite.gd", project / "suite.gd")
        shutil.copy2(HERE / "regression_suite.gd", project / "regression_suite.gd")
        (project / "project.godot").write_text(
            'config_version=5\n[application]\nconfig/name="Map editor contracts"\n'
            '[rendering]\nrenderer/rendering_method="gl_compatibility"\n')
        env = {**os.environ, "XDG_DATA_HOME": str(project / "data"),
               "XDG_CONFIG_HOME": str(project / "config"), "XDG_CACHE_HOME": str(project / "cache")}
        for args in (["--editor", "--import"], ["--script", "res://regression_suite.gd"], ["--script", "res://suite.gd"], ["--script", "res://network_suite.gd"]):
            try:
                result = subprocess.run([godot, "--headless", "--path", directory, *args],
                                        capture_output=True, text=True, timeout=90, env=env)
            except subprocess.TimeoutExpired as error:
                print((error.stdout or b"").decode(), (error.stderr or b"").decode())
                print("Infrastructure timeout:", error)
                return 2
            output = result.stdout + result.stderr
            if "--script" in args or result.returncode or "ERROR:" in output:
                print(output, end="")
            if "ERROR:" in output or result.returncode not in (0, 1):
                return 2
            if result.returncode:
                return result.returncode
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
