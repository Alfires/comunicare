#!/usr/bin/env python3
"""Opt-in RED contracts for the proposed world-authoring plugin."""
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
    with tempfile.TemporaryDirectory(prefix="comunicare-authoring-", dir="/tmp/opencode") as directory:
        project = Path(directory)
        plugin = ROOT / "addons/comunicare_world_tools"
        if plugin.exists():
            shutil.copytree(plugin, project / "addons/comunicare_world_tools", ignore=shutil.ignore_patterns(".godot", "__pycache__"))
        shutil.copytree(ROOT / "scripts/worlds", project / "scripts/worlds")
        shutil.copy2(HERE / "suite.gd", project / "suite.gd")
        (project / "project.godot").write_text(
            'config_version=5\n[application]\nconfig/name="World authoring contracts"\n'
            '[rendering]\nrenderer/rendering_method="gl_compatibility"\n')
        env = {**os.environ, "XDG_DATA_HOME": str(project / "data"),
               "XDG_CONFIG_HOME": str(project / "config"), "XDG_CACHE_HOME": str(project / "cache")}
        for args in (["--editor", "--import"], ["--script", "res://suite.gd"]):
            try:
                result = subprocess.run([godot, "--headless", "--path", directory, *args],
                                        capture_output=True, text=True, timeout=90, env=env)
            except subprocess.TimeoutExpired as error:
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
