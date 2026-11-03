#!/usr/bin/env python3
"""Run microphone/settings contracts without a device or real user config."""

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
        prefix="comunicare-microphone-settings-",
        dir=temp_root if temp_root.is_dir() else None,
    ) as directory:
        project = Path(directory)
        # Copy real settings/UI/capture code, including future roadmap files.
        for folder in ("scripts/settings", "scripts/profile", "scripts/GUI", "scripts/player", "relay_protocol", "scenes/GUI"):
            shutil.copytree(ROOT / folder, project / folder)
        shutil.copy2(ROOT / "default_bus_layout.tres", project / "default_bus_layout.tres")
        shutil.copytree(ROOT / "themes/icons", project / "themes/icons")
        shutil.copytree(HERE / "fixtures", project / "fixtures")
        shutil.copy2(HERE / "suite.gd", project / "suite.gd")
        # Import the real input definitions, not a fake V action that would make
        # the default-binding test pass before production has implemented it.
        original = (ROOT / "project.godot").read_text()
        input_section = original.split("[input]", 1)[1].split("\n[", 1)[0]
        (project / "project.godot").write_text(
            'config_version=5\n[application]\nconfig/name="Mic/settings contracts"\n'
            '[autoload]\n'
            'SaveData="*res://fixtures/save_data.gd"\n'
            'NetworkHandler="*res://fixtures/network_handler.gd"\n'
            'DataLoader="*res://fixtures/data_loader.gd"\n'
            '[rendering]\nrenderer/rendering_method="gl_compatibility"\n'
            '[input]\n' + input_section
        )
        imported = subprocess.run(
            [godot, "--headless", "--path", directory, "--editor", "--import"],
            capture_output=True, text=True, timeout=90,
        )
        if imported.returncode or "ERROR:" in imported.stdout + imported.stderr:
            print(imported.stdout + imported.stderr)
            return 2
        result = subprocess.run(
            [godot, "--headless", "--path", directory, "--script", "res://suite.gd"],
            capture_output=True, text=True, timeout=60,
        )
        print(result.stdout + result.stderr, end="")
        if "ERROR:" in result.stdout + result.stderr:
            return 2
        return result.returncode


if __name__ == "__main__":
    raise SystemExit(main())
