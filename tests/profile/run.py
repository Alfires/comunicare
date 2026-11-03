#!/usr/bin/env python3
"""Profile contracts in a temporary project, without real accounts or network."""

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
        raise SystemExit("Godot 4 required; set GODOT to its executable path.")
    temp_root = Path("/tmp/opencode")
    with tempfile.TemporaryDirectory(
        prefix="comunicare-profile-",
        dir=temp_root if temp_root.is_dir() else None,
    ) as directory:
        project = Path(directory)
        for folder in ("scripts", "relay_protocol", "scenes/GUI", "themes/icons"):
            shutil.copytree(ROOT / folder, project / folder)
        shutil.copytree(HERE / "fixtures", project / "fixtures")
        shutil.copy2(HERE / "suite.gd", project / "suite.gd")
        # No game startup, physical capture, account files, external HTTP,
        # listening relay or VR plugins. Real UI scripts run their ready paths.
        original = (ROOT / "project.godot").read_text()
        inputs = original.split("[input]", 1)[1].split("\n[", 1)[0]
        (project / "project.godot").write_text(
            'config_version=5\n[application]\nconfig/name="Profile contracts"\n'
            '[autoload]\nSaveData="*res://fixtures/save_data.gd"\n'
            'NetworkHandler="*res://fixtures/network_handler.gd"\n'
            'DataLoader="*res://fixtures/data_loader.gd"\n'
            '[rendering]\nrenderer/rendering_method="gl_compatibility"\n'
            '[input]\n' + inputs
        )
        for arguments in (["--editor", "--import"], ["--script", "res://suite.gd"]):
            result = subprocess.run(
                [godot, "--headless", "--path", directory, *arguments],
                capture_output=True, text=True, timeout=90,
            )
            output = result.stdout + result.stderr
            if "--script" in arguments or result.returncode or "ERROR:" in output:
                print(output, end="")
            if "ERROR:" in output:
                return 2
            if result.returncode:
                return result.returncode
        return 0


if __name__ == "__main__":
    raise SystemExit(main())
