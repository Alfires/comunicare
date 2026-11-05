#!/usr/bin/env python3
"""Import only island sample assets in a disposable Godot project."""
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
    parser.add_argument("--rendered", action="store_true", help="Render the sample inspection view on X11")
    args = parser.parse_args()
    godot = shutil.which(os.environ.get("GODOT", "godot"))
    if not godot:
        print("Infrastructure failure: Godot required")
        return 2
    with tempfile.TemporaryDirectory(prefix="welcome-assets-", dir="/tmp/opencode") as directory:
        project = Path(directory)
        source = ROOT / "assets/welcome_island"
        if source.exists():
            shutil.copytree(source, project / "assets/welcome_island", ignore=shutil.ignore_patterns("*.import", "*.uid"))
        shutil.copy2(HERE / "assets_suite.gd", project / "suite.gd")
        (project / "project.godot").write_text('config_version=5\n[application]\nconfig/name="Island asset import tests"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n')
        env = {**os.environ, "XDG_DATA_HOME": str(project / "data"), "XDG_CACHE_HOME": str(project / "cache"), "XDG_CONFIG_HOME": str(project / "config")}
        try:
            for arguments, marker in ((["--editor", "--import"], None), (["--script", "res://suite.gd"], "Welcome assets:")):
                display = ["--display-driver", "x11"] if args.rendered and marker else ["--headless"]
                result = subprocess.run([godot, *display, "--path", directory, *arguments], capture_output=True, text=True, timeout=120,
                                        env={**env, "WELCOME_ASSET_RENDERED": "1" if args.rendered else "0"})
                output = result.stdout + result.stderr
                if marker or result.returncode or "ERROR:" in output:
                    print(output, end="")
                if "ERROR:" in output or result.returncode not in (0, 1) or (marker and marker not in output):
                    return 2
                if result.returncode:
                    return result.returncode
            return 0
        except (OSError, subprocess.TimeoutExpired) as error:
            print(f"Infrastructure failure: {error}")
            return 2


if __name__ == "__main__":
    raise SystemExit(main())
