#!/usr/bin/env python3
"""Isolated startup contracts; never launches the game against real user data."""
import argparse
import os
import re
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--suite", choices=("desktop", "xr", "account", "all"), default="all")
    parser.add_argument("--rendered", action="store_true", help="Render the isolated desktop fixture and save a screenshot")
    args = parser.parse_args()
    godot = shutil.which(os.environ.get("GODOT", "godot"))
    if not godot:
        print("Infrastructure failure: Godot required; set GODOT")
        return 2
    with tempfile.TemporaryDirectory(prefix="welcome-island-", dir="/tmp/opencode") as directory:
        project = Path(directory)
        for folder in ("scripts/settings", "scripts/profile"):
            shutil.copytree(ROOT / folder, project / folder)
        for name in ("scripts/startup/main.gd", "scripts/player/voice_controller.gd",
                     "scripts/worlds/world_pickup_controller.gd", "scripts/worlds/world_data.gd",
                     "relay_protocol/instance_state.gd", "relay_protocol/friend_event.gd",
                     "relay_protocol/world_address.gd",
                     "scenes/startup.tscn", "scenes/world.tscn", "scenes/world.gd",
                     "scenes/GUI/vr_gui.tscn", "scripts/GUI/vr_gui.gd"):
            target = project / name
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(ROOT / name, target)
            uid = ROOT / (name + ".uid")
            if uid.exists():
                shutil.copy2(uid, str(target) + ".uid")
        shutil.copytree(HERE / "fixtures", project / "fixtures")
        for folder in ("scenes/worlds/welcome_island", "scripts/worlds/welcome_island"):
            if (ROOT / folder).exists(): shutil.copytree(ROOT / folder, project / folder)
        for id in ("sparse_grass", "rock_path", "rock_01", "weathered_planks"):
            source = ROOT / "assets/welcome_island/textures" / id
            if source.exists(): shutil.copytree(source, project / "assets/welcome_island/textures" / id, ignore=shutil.ignore_patterns("*.import"))
        # The legacy world-mounted VRPanel holds a viewport-texture/material cycle
        # on repeated unloading. This startup suite uses player menu probes, not
        # that unrelated legacy panel. Keep terrain/environment/reset production
        # content intact and document the exclusion rather than ignoring leak errors.
        world = project / "scenes/world.tscn"
        text = world.read_text()
        if '[node name="VRPanel"' in text:
            panel_start = text.index('[node name="VRPanel"')
            connections = text.index('[connection ', panel_start)
            world.write_text(text[:panel_start] + text[connections:])
        shutil.copy2(HERE / "suite.gd", project / "suite.gd")
        players = project / "scenes/player"
        players.mkdir(parents=True)
        for kind in ("desktop", "vr"):
            (players / f"player_{kind}.tscn").write_text(
                '[gd_scene load_steps=2 format=3]\n'
                '[ext_resource type="Script" path="res://fixtures/player.gd" id="1"]\n'
                f'[node name="player_{kind}" type="Node3D" groups=["player"]]\n'
                'script = ExtResource("1")\n'
            )
        (project / "project.godot").write_text(
            'config_version=5\n[application]\nconfig/name="Welcome island contracts"\n'
            '[autoload]\nSaveData="*res://scripts/settings/save_data.gd"\n'
            'NetworkHandler="*res://fixtures/network.gd"\n'
            '[rendering]\nrenderer/rendering_method="gl_compatibility"\n'
            '[display]\nwindow/size/viewport_width=800\nwindow/size/viewport_height=600\n'
        )
        env = {**os.environ, "XDG_DATA_HOME": str(project / "data"),
               "XDG_CONFIG_HOME": str(project / "config"), "XDG_CACHE_HOME": str(project / "cache")}
        command = [godot, "--path", directory, "--audio-driver", "Dummy", "--xr-mode", "off"]
        try:
            imported = subprocess.run([*command, "--headless", "--editor", "--import"],
                                      capture_output=True, text=True, timeout=90, env=env)
            if imported.returncode or "ERROR:" in imported.stdout + imported.stderr:
                print(imported.stdout + imported.stderr)
                return 2
            status = 0
            groups = ("desktop", "xr", "account") if args.suite == "all" else (args.suite,)
            for group in groups:
                group_env = {**env, "WELCOME_SUITE": group,
                             "WELCOME_RENDERED": "1" if args.rendered and group == "desktop" else "0"}
                # A fresh user directory for every process: account tests cannot reuse
                # another group's valid key, profile or cache.
                group_env["XDG_DATA_HOME"] = str(project / ("data-" + group))
                display = ["--display-driver", "x11"] if args.rendered and group == "desktop" else ["--headless"]
                result = subprocess.run([*command, *display, "--script", "res://suite.gd", "--non_vr"],
                                        capture_output=True, text=True, timeout=45, env=group_env)
                output = result.stdout + result.stderr
                print(output, end="", flush=True)
                # Invalid-key parsing and startup's explicit report are the only
                # expected engine errors. All others remain infrastructure failures.
                errors = [line for line in output.splitlines() if "ERROR:" in line]
                unexpected = errors
                if group == "account":
                    expected = (r"ERROR: Error parsing key '-\d+'\.",
                                r"ERROR: Account key is unreadable\. It was not replaced\. Restore your key backup\.")
                    unexpected = [line for line in errors if not any(re.fullmatch(pattern, line) for pattern in expected)]
                    if any(sum(bool(re.fullmatch(pattern, line)) for line in errors) != 1 for pattern in expected):
                        print("Infrastructure failure: expected exactly one invalid-key parse/report pair")
                        return 2
                if unexpected or "Welcome foundation:" not in output or result.returncode not in (0, 1):
                    return 2
                status = max(status, result.returncode)
            return status
        except (OSError, subprocess.TimeoutExpired) as error:
            if isinstance(error, subprocess.TimeoutExpired):
                for output in (error.stdout, error.stderr):
                    if output:
                        print(output.decode() if isinstance(output, bytes) else output)
            print(f"Infrastructure failure: {error}")
            return 2


if __name__ == "__main__":
    raise SystemExit(main())
