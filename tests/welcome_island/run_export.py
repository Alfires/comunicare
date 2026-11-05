#!/usr/bin/env python3
"""Export a disposable resource pack and run it without editor source paths.

Uses the installed Godot executable as pack host; does not certify a standalone
export template binary, which must be installed/tested separately.
"""
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent


def main():
    godot = shutil.which(os.environ.get("GODOT", "godot"))
    if not godot: return 2
    with tempfile.TemporaryDirectory(prefix="island-export-", dir="/tmp/opencode") as directory:
        project = Path(directory) / "project"
        project.mkdir()
        for folder in ("assets/welcome_island", "scenes/worlds/welcome_island", "scripts/worlds/welcome_island"):
            shutil.copytree(ROOT / folder, project / folder, ignore=shutil.ignore_patterns("*.import", "*.uid"))
        for name in ("scenes/world.tscn", "scenes/world.gd", "scripts/worlds/world_pickup_controller.gd", "scripts/worlds/world_data.gd"):
            target = project / name
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(ROOT / name, target)
        shutil.copy2(HERE / "export_suite.gd", project / "export_suite.gd")
        (project / "main.tscn").write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://export_suite.gd" id="1"]\n[node name="Runner" type="Node"]\n')
        (project / "project.godot").write_text('config_version=5\n[application]\nconfig/name="Exported island contracts"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n')
        (project / "export_presets.cfg").write_text('[preset.0]\nname="IsolatedPack"\nplatform="Linux"\nrunnable=true\nexport_filter="all_resources"\ninclude_filter="*.json,*.gd"\nexclude_filter=""\n[preset.0.options]\nbinary_format/architecture="x86_64"\n')
        data = json.loads((project / "scenes/worlds/welcome_island/revision.json").read_text())
        expected = hashlib.sha256(("\n".join(name + ":" + data["files"][name] for name in sorted(data["files"])) + "\n").encode()).hexdigest()
        env = {**os.environ, "XDG_DATA_HOME": directory + "/data", "XDG_CONFIG_HOME": directory + "/config", "XDG_CACHE_HOME": directory + "/cache", "ISLAND_EXPECTED_REVISION": expected}
        pack = Path(directory) / "island.pck"
        try:
            for command in ([godot, "--headless", "--path", str(project), "--editor", "--import"],
                            [godot, "--headless", "--path", str(project), "--export-pack", "IsolatedPack", str(pack)]):
                result = subprocess.run(command, capture_output=True, text=True, timeout=180, env=env)
                if result.returncode or "ERROR:" in result.stdout + result.stderr:
                    print(result.stdout + result.stderr)
                    return 2
            # Remove access to the source project; only the exported pack is mounted.
            project.rename(Path(directory) / "source-not-mounted")
            result = subprocess.run([godot, "--headless", "--path", directory, "--main-pack", str(pack), "--script", "res://export_suite.gd"], capture_output=True, text=True, timeout=60, env=env)
            output = result.stdout + result.stderr
            print(output, end="")
            if "ERROR:" in output or "Exported pack home:" not in output: return 2
            return result.returncode
        except (OSError, subprocess.TimeoutExpired) as error:
            print(error)
            return 2


if __name__ == "__main__": raise SystemExit(main())
