#!/usr/bin/env python3
"""Friends contracts: disposable account files and an ephemeral loopback relay."""
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
    parser.add_argument("--display", action="store_true")
    args = parser.parse_args()
    godot = shutil.which(os.environ.get("GODOT", "godot"))
    if not godot:
        print("Godot 4 required")
        return 2
    with tempfile.TemporaryDirectory(prefix="comunicare-friends-", dir="/tmp/opencode") as directory:
        project = Path(directory)
        for folder in ("relay_protocol", "scripts/discovery", "scripts/profile", "scripts/GUI", "scripts/assets", "scenes/GUI", "themes/icons"):
            shutil.copytree(ROOT / folder, project / folder)
        target = project / "scripts/multiplayer/relay.gd"
        target.parent.mkdir(parents=True)
        shutil.copy2(ROOT / "scripts/multiplayer/relay.gd", target)
        shutil.copytree(HERE / "fixtures", project / "fixtures")
        shutil.copy2(HERE / "suite.gd", project / "suite.gd")
        (project / "project.godot").write_text(
            'config_version=5\n[application]\nconfig/name="Friends contracts"\n'
            '[autoload]\nSaveData="*res://fixtures/save_data.gd"\n'
            'NetworkHandler="*res://fixtures/network_handler.gd"\n'
            'DataLoader="*res://fixtures/data_loader.gd"\n'
            '[rendering]\nrenderer/rendering_method="gl_compatibility"\n'
        )
        for command in (["--headless", "--editor", "--import"],
                        (["--audio-driver", "Dummy", "--script", "res://suite.gd", "--", "--visual"] if args.display else ["--headless", "--script", "res://suite.gd"])):
            result = subprocess.run([godot, "--path", directory, *command], capture_output=True, text=True, timeout=120)
            output = result.stdout + result.stderr
            if "--script" in command or result.returncode or "ERROR:" in output:
                print(output, end="")
            if "ERROR:" in output:
                return 2
            if result.returncode:
                return result.returncode
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
