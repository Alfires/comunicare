#!/usr/bin/env python3
"""Opt-in intentionally RED multiplayer regressions, isolated from real users."""
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
    parser.add_argument("--suite", choices=["client", "discovery", "all"], default="all")
    args = parser.parse_args()
    godot = shutil.which(os.environ.get("GODOT", "godot"))
    if not godot:
        print("Godot required; set GODOT")
        return 2
    with tempfile.TemporaryDirectory(prefix="comunicare-network-red-", dir="/tmp/opencode") as directory:
        project = Path(directory)
        for folder in ("scripts", "relay_protocol", "themes/icons", "scenes/GUI"):
            shutil.copytree(ROOT / folder, project / folder)
        shutil.copytree(HERE / "fixtures", project / "fixtures")
        remote = project / "scenes/player/remote_player.tscn"
        remote.parent.mkdir(parents=True, exist_ok=True)
        remote.write_text('[gd_scene format=3]\n[node name="Remote" type="Node3D"]\n')
        (project / "project.godot").write_text(
            'config_version=5\n[application]\nconfig/name="RED network contracts"\n'
            '[autoload]\nDataLoader="*res://fixtures/data_loader.gd"\n'
            'SaveData="*res://fixtures/save_data.gd"\n'
            'NetworkHandler="*res://scripts/multiplayer/network_handler.gd"\n'
            '[rendering]\nrenderer/rendering_method="gl_compatibility"\n')
        suites = [args.suite] if args.suite != "all" else ["client", "discovery"]
        commands = [["--editor", "--import"]]
        for suite in suites:
            shutil.copy2(HERE / (suite + "_suite.gd"), project / (suite + "_suite.gd"))
            commands.append(["--script", "res://" + suite + "_suite.gd"])
        status = 0
        for command in commands:
            try:
                result = subprocess.run([godot, "--headless", "--path", directory, *command],
                                        capture_output=True, text=True, timeout=60)
            except subprocess.TimeoutExpired as error:
                print(error.stdout or "", error.stderr or "")
                return 2
            output = result.stdout + result.stderr
            if "--script" in command or result.returncode or "ERROR:" in output:
                print(output, end="")
            if "ERROR:" in output or result.returncode not in [0, 1]:
                return 2
            if result.returncode:
                status = 1
                if "--editor" in command: return 2
        return status


if __name__ == "__main__": raise SystemExit(main())
