#!/usr/bin/env python3
"""Opt-in RED VR acceptance project: no XR runtime, account or real input devices."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent


def main():
    executable = shutil.which(os.environ.get("GODOT", "godot"))
    if not executable:
        print("Godot required (override with GODOT)")
        return 2
    with tempfile.TemporaryDirectory(prefix="comunicare-vr-red-", dir="/tmp/opencode") as directory:
        project = Path(directory)
        for folder in ("scripts", "relay_protocol"):
            shutil.copytree(ROOT / folder, project / folder, ignore=shutil.ignore_patterns("__pycache__"))
        shutil.copy2(HERE / "suite.gd", project / "suite.gd")
        for name in ("save_data", "data_loader", "network_handler"):
            shutil.copy2(HERE / "fixtures" / (name + ".gd"), project / (name + ".gd"))
        for source in ("scenes/player/player_vr.tscn", "openxr_action_map.tres"):
            target = project / "evidence" / Path(source).name
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(ROOT / source, target.with_suffix(target.suffix + ".txt"))
        # Production scripts preload resources; no physical player/menu scene is run.
        for source in ("themes/icons/profile.svg",):
            target = project / source
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(ROOT / source, target)
        remote = project / "scenes/player/remote_player.tscn"
        remote.parent.mkdir(parents=True, exist_ok=True)
        remote.write_text('[gd_scene format=3]\n[node name="Remote" type="Node3D"]\n')
        (project / "project.godot").write_text(
            'config_version=5\n[application]\nconfig/name="RED VR contracts"\n'
            '[autoload]\nSaveData="*res://save_data.gd"\nDataLoader="*res://data_loader.gd"\n'
            'NetworkHandler="*res://network_handler.gd"\n'
            '[rendering]\nrenderer/rendering_method="gl_compatibility"\n')
        for args in (["--editor", "--import"], ["--script", "res://suite.gd"]):
            try:
                result = subprocess.run([executable, "--headless", "--path", directory, *args],
                                        capture_output=True, text=True, timeout=60)
            except subprocess.TimeoutExpired as error:
                print(error.stdout or "", error.stderr or "")
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
