#!/usr/bin/env python3
"""Opt-in RED federation contracts; no accounts, WAN or physical LAN probing."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent


def result_code(process):
    output = process.stdout + process.stderr
    if "ERROR:" in output or process.returncode not in (0, 1):
        return 2
    # An empty/early exit is not proof the acceptance suite actually ran.
    if "Federation acceptance:" not in output:
        return 2
    return process.returncode


def main():
    godot = shutil.which(os.environ.get("GODOT", "godot"))
    if not godot:
        print("Infrastructure failure: Godot required; set GODOT.")
        return 2
    try:
        with tempfile.TemporaryDirectory(prefix="comunicare-federation-red-", dir="/tmp/opencode") as directory:
            project = Path(directory)
            source = ROOT / "scripts/multiplayer/federation"
            if source.is_dir():
                shutil.copytree(source, project / "scripts/multiplayer/federation")
            shutil.copy2(HERE / "suite.gd", project / "suite.gd")
            (project / "project.godot").write_text(
                'config_version=5\n[application]\nconfig/name="RED federation contracts"\n'
                '[rendering]\nrenderer/rendering_method="gl_compatibility"\n')
            env = {**os.environ, "XDG_DATA_HOME": str(project / "data"),
                   "XDG_CONFIG_HOME": str(project / "config"), "XDG_CACHE_HOME": str(project / "cache")}
            imported = subprocess.run([godot, "--headless", "--path", directory, "--editor", "--import"],
                                      capture_output=True, text=True, timeout=90, env=env)
            if imported.returncode or "ERROR:" in imported.stdout + imported.stderr:
                print(imported.stdout + imported.stderr)
                return 2
            result = subprocess.run([godot, "--headless", "--path", directory, "--script", "res://suite.gd"],
                                    capture_output=True, text=True, timeout=60, env=env)
            print(result.stdout, end="")
            print(result.stderr, end="")
            return result_code(result)
    except (OSError, subprocess.TimeoutExpired) as error:
        print(f"Infrastructure failure: {error}")
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
