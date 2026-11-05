#!/usr/bin/env python3
"""Disposable data-only animation and relay contracts."""
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
        return 2
    with tempfile.TemporaryDirectory(prefix="comunicare-animation-", dir="/tmp/opencode") as directory:
        project = Path(directory)
        for folder in ("scripts/assets", "scripts/profile", "scripts/worlds", "relay_protocol"):
            shutil.copytree(ROOT / folder, project / folder)
        shutil.copytree(ROOT / "assets/animations", project / "assets/animations")
        shutil.copytree(ROOT / "assets/avatars", project / "assets/avatars")
        avatar_fixture = os.environ.get("AVATAR_FIXTURE")
        if avatar_fixture:
            shutil.copy2(avatar_fixture, project / "real-avatar.vrm")
        (project / "scripts/multiplayer").mkdir(parents=True)
        shutil.copy2(ROOT / "scripts/multiplayer/relay.gd", project / "scripts/multiplayer/relay.gd")
        shutil.copy2(ROOT / "scripts/multiplayer/network_handler.gd", project / "scripts/multiplayer/network_handler.gd")
        shutil.copytree(ROOT / "scripts/multiplayer/client", project / "scripts/multiplayer/client")
        shutil.copytree(ROOT / "scripts/multiplayer/federation", project / "scripts/multiplayer/federation")
        (project / "scripts/player").mkdir(parents=True, exist_ok=True)
        shutil.copy2(ROOT / "scripts/player/remote_motion.gd", project / "scripts/player/remote_motion.gd")
        for name in ("player_desktop_movment.gd", "player_vr.gd", "sprint_policy.gd", "air_control.gd", "vr_locomotion.gd", "vr_turn_controller.gd", "vr_input_router.gd", "vr_comfort.gd", "vr_room_scale.gd", "vr_safety.gd"):
            shutil.copy2(ROOT / "scripts/player" / name, project / "scripts/player" / name)
        remote = project / "scenes/player/remote_player.tscn"
        remote.parent.mkdir(parents=True, exist_ok=True)
        remote.write_text('[gd_scene format=3]\n[node name="Remote" type="Node3D"]\n')
        shutil.copy2(ROOT / "tests/public_discovery/fixtures/save_data.gd", project / "save_data.gd")
        for source in ("scripts/startup/data_loader.gd", "scripts/GUI/vr_keyboard.gd", "scripts/GUI/vr_pointer_router.gd", "scripts/GUI/animation_menue.gd", "scripts/GUI/emote_wheel.gd", "scripts/GUI/xr_emote_wheel.gd", "scripts/GUI/emote_layout_editor.gd", "scenes/GUI/animation_menue.tscn"):
            target = project / source
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(ROOT / source, target)
        shutil.copy2(HERE / "network.gd", project / "network.gd")
        shutil.copy2(ROOT / "scripts/GUI/vr_tracking_setup.gd", project / "scripts/GUI/vr_tracking_setup.gd")
        shutil.copy2(ROOT / "scripts/GUI/circular_value_control.gd", project / "scripts/GUI/circular_value_control.gd")
        shutil.copy2(HERE / "suite.gd", project / "suite.gd")
        shutil.copy2(HERE / "lifecycle_suite.gd", project / "lifecycle_suite.gd")
        shutil.copy2(HERE / "mirror_suite.gd", project / "mirror_suite.gd")
        shutil.copy2(HERE / "performance_suite.gd", project / "performance_suite.gd")
        (project / "project.godot").write_text(
            'config_version=5\n[application]\nconfig/name="Animation tests"\n'
            '[autoload]\nDataLoader="*res://scripts/startup/data_loader.gd"\nSaveData="*res://save_data.gd"\nNetworkHandler="*res://network.gd"\n'
            '[rendering]\nrenderer/rendering_method="gl_compatibility"\n')
        for args in (["--editor", "--import"], ["--script", "res://performance_suite.gd"], ["--script", "res://mirror_suite.gd"], ["--script", "res://lifecycle_suite.gd"], ["--script", "res://suite.gd"]):
            try:
                result = subprocess.run([godot, "--headless", "--path", directory, *args],
                                        capture_output=True, text=True, timeout=30)
            except subprocess.TimeoutExpired as error:
                print((error.stdout or b"").decode() + (error.stderr or b"").decode())
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
