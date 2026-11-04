#!/usr/bin/env python3
"""Run red Active Instance contracts without starting the game or real accounts."""

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
    parser.add_argument("--display", action="store_true", help="Run windowed layout/clipboard/render checks instead of headless contracts")
    parser.add_argument("--artifacts", type=Path, default=Path("/tmp/opencode/active-instance-visual"))
    args = parser.parse_args()
    godot = shutil.which(os.environ.get("GODOT", "godot"))
    if not godot:
        print("Godot 4 required; set GODOT to its executable path.")
        return 2
    temporary = Path("/tmp/opencode")
    with tempfile.TemporaryDirectory(
        prefix="comunicare-active-instance-",
        dir=temporary if temporary.is_dir() else None,
    ) as directory:
        project = Path(directory)
        sources = [
            "scripts/multiplayer/network_handler.gd",
            "scripts/multiplayer/client/participant_registry.gd",
            "scripts/multiplayer/relay.gd",
            *[str(p.relative_to(ROOT)) for p in (ROOT / "relay_protocol").glob("*.gd")],
            *[str(p.relative_to(ROOT)) for p in (ROOT / "scripts/GUI").glob("*.gd")],
        ]
        for source in sources:
            target = project / source
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(ROOT / source, target)
            if (ROOT / (source + ".uid")).is_file():
                shutil.copy2(ROOT / (source + ".uid"), project / (source + ".uid"))
        for folder in ("scripts/discovery", "scripts/assets", "scripts/profile", "scenes/GUI", "themes/icons"):
            shutil.copytree(ROOT / folder, project / folder)
        # Read inherited desktop/VR wiring as scene text, without importing XR,
        # physical capture, avatar addons or the full player scenes.
        inputs = project / "scene_inputs"
        inputs.mkdir()
        for name in ("player_desktop", "player_vr"):
            shutil.copy2(ROOT / f"scenes/player/{name}.tscn", inputs / f"{name}.txt")
        remote = project / "scenes/player/remote_player.tscn"
        remote.parent.mkdir(parents=True, exist_ok=True)
        remote.write_text('[gd_scene format=3]\n[node name="Remote" type="Node3D"]\n')
        shutil.copytree(HERE / "fixtures", project / "fixtures")
        shutil.copy2(HERE / "suite.gd", project / "suite.gd")
        shutil.copy2(HERE / "display_suite.gd", project / "display_suite.gd")
        (project / "project.godot").write_text(
            'config_version=5\n[application]\nconfig/name="Active Instance contracts"\n'
            '[autoload]\nSaveData="*res://fixtures/save_data.gd"\n'
            'DataLoader="*res://fixtures/data_loader.gd"\n'
            'NetworkHandler="*res://scripts/multiplayer/network_handler.gd"\n'
            '[rendering]\nrenderer/rendering_method="gl_compatibility"\n'
        )
        try:
            commands = [["--headless", "--editor", "--import"]]
            if args.display:
                args.artifacts.mkdir(parents=True, exist_ok=True)
                commands.append(["--audio-driver", "Dummy", "--script", "res://display_suite.gd", "--", str(args.artifacts.resolve())])
            else:
                commands.append(["--headless", "--script", "res://suite.gd"])
            for arguments in commands:
                result = subprocess.run(
                    [godot, "--path", directory, *arguments],
                    capture_output=True, text=True, timeout=120,
                )
                output = result.stdout + result.stderr
                if "--script" in arguments or result.returncode or "ERROR:" in output:
                    print(output, end="")
                if "ERROR:" in output:
                    return 2
                if result.returncode:
                    return 1 if "--script" in arguments and result.returncode == 1 else 2
        except subprocess.TimeoutExpired as error:
            print(f"Infrastructure failure: Godot timed out: {error.cmd}")
            return 2
        return 0


if __name__ == "__main__":
    raise SystemExit(main())
