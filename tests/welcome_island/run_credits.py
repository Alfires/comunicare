#!/usr/bin/env python3
"""Isolated production Settings/Credits with inert network/data autoloads."""
import argparse
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--rendered", action="store_true")
    args = parser.parse_args()
    godot = shutil.which(os.environ.get("GODOT", "godot"))
    if not godot:
        return 2
    with tempfile.TemporaryDirectory(prefix="welcome-credits-", dir="/tmp/opencode") as directory:
        project = Path(directory)
        for folder in ("scripts/settings", "scripts/profile", "scripts/GUI", "scripts/player", "scripts/discovery", "relay_protocol", "scenes/GUI", "themes/icons"):
            shutil.copytree(ROOT / folder, project / folder)
        shutil.copytree(ROOT / "scripts/worlds", project / "scripts/worlds")
        shutil.copytree(ROOT / "tests/microphone_settings/fixtures", project / "fixtures")
        for name in ("assets/welcome_island/manifest.json", "assets/welcome_island/licenses/CC0-1.0.txt",
                     "assets/welcome_island/licenses/Kenney-Watercraft.txt",
                     "assets/animations/CC0-1.0.txt", "assets/animations/Quaternius-License.txt"):
            target = project / name
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(ROOT / name, target)
        bundled = ROOT / "assets/credits.json"
        if bundled.exists(): shutil.copy2(bundled, project / "assets/credits.json")
        shutil.copy2(HERE / "credits_suite.gd", project / "suite.gd")
        (project / "project.godot").write_text('config_version=5\n[application]\nconfig/name="Credits contracts"\n[autoload]\nSaveData="*res://fixtures/save_data.gd"\nNetworkHandler="*res://fixtures/network_handler.gd"\nDataLoader="*res://fixtures/data_loader.gd"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n')
        env = {**os.environ, "XDG_DATA_HOME": str(project / "data"), "XDG_CONFIG_HOME": str(project / "config"), "XDG_CACHE_HOME": str(project / "cache"), "WELCOME_CREDITS_RENDERED": "1" if args.rendered else "0"}
        try:
            for importing in (True, False):
                display = ["--display-driver", "x11"] if args.rendered and not importing else ["--headless"]
                extra = ["--editor", "--import"] if importing else ["--script", "res://suite.gd"]
                result = subprocess.run([godot, "--path", directory, *display, *extra], capture_output=True, text=True, timeout=90, env=env)
                output = result.stdout + result.stderr
                if not importing or result.returncode or "ERROR:" in output: print(output, end="")
                if "ERROR:" in output or result.returncode not in (0, 1) or (not importing and "Welcome credits:" not in output): return 2
                if result.returncode: return result.returncode
            return 0
        except (OSError, subprocess.TimeoutExpired) as error:
            print(error)
            return 2


if __name__ == "__main__": raise SystemExit(main())
