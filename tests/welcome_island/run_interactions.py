#!/usr/bin/env python3
"""Shared pickup controller physics contracts, no network/account dependencies."""
import os
import argparse
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--rendered', action='store_true')
    args = parser.parse_args()
    godot = shutil.which(os.environ.get("GODOT", "godot"))
    if not godot: return 2
    with tempfile.TemporaryDirectory(prefix="island-interactions-", dir="/tmp/opencode") as directory:
        project = Path(directory)
        for name in ["scripts/worlds/world_pickup_controller.gd", "scripts/worlds/world_data.gd"]:
            target = project / name
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(ROOT / name, target)
        shutil.copy2(HERE / "interactions_suite.gd", project / "suite.gd")
        (project / "project.godot").write_text('config_version=5\n[application]\nconfig/name="Offline interactions"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n')
        env = {**os.environ, "XDG_DATA_HOME": str(project / "data"), "XDG_CONFIG_HOME": str(project / "config"), "XDG_CACHE_HOME": str(project / "cache"), "ISLAND_INTERACTIONS_RENDERED": '1' if args.rendered else '0'}
        try:
            display = ['--display-driver', 'x11'] if args.rendered else ['--headless']
            result = subprocess.run([godot, *display, "--path", directory, "--script", "res://suite.gd"], capture_output=True, text=True, timeout=45, env=env)
            output = result.stdout + result.stderr
            print(output, end="")
            if "ERROR:" in output or "Welcome interactions:" not in output or result.returncode not in (0, 1): return 2
            return result.returncode
        except (OSError, subprocess.TimeoutExpired) as error:
            if isinstance(error, subprocess.TimeoutExpired):
                print(error.stdout, error.stderr)
            print(error)
            return 2


if __name__ == "__main__": raise SystemExit(main())
