#!/usr/bin/env python3
"""Run discovery contracts in a disposable Godot project (loopback network only)."""

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
        raise SystemExit("Godot 4 is required; set GODOT to its executable path.")
    temp_root = Path("/tmp/opencode")
    with tempfile.TemporaryDirectory(
        prefix="comunicare-discovery-", dir=temp_root if temp_root.is_dir() else None
    ) as directory:
        project = Path(directory)
        # Copy only scripts under test: no game startup, VR, downloads, accounts,
        # account writes, editor plugins, external relay, or project.godot changes.
        sources = [
            "scripts/GUI/world_explorer.gd",
            "scripts/GUI/error_popup.gd",
            "scripts/GUI/emote_wheel.gd",
            "scripts/GUI/xr_emote_wheel.gd",
            "scripts/multiplayer/relay.gd",
            "scripts/multiplayer/network_handler.gd",
            "scripts/multiplayer/client/participant_registry.gd",
            "scripts/startup/data_loader.gd",
            "scripts/assets/asset_cache.gd",
            "scripts/assets/humanoid_animation.gd",
            "scenes/GUI/world_explorer.tscn",
            *[str(p.relative_to(ROOT)) for p in (ROOT / "relay_protocol").glob("*.gd")],
        ]
        for source in sources:
            target = project / source
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(ROOT / source, target)
            uid = ROOT / (source + ".uid")
            if uid.is_file():
                shutil.copy2(uid, project / (source + ".uid"))
        shutil.copytree(HERE / "fixtures", project / "fixtures")
        shutil.copytree(ROOT / "scripts/profile", project / "scripts/profile")
        for source in (ROOT / "scripts/assets").glob("*.gd"):
            shutil.copy2(source, project / "scripts/assets" / source.name)
        shutil.copytree(ROOT / "themes/icons", project / "themes/icons")
        # Keep heavy avatar/world assets out of this isolated contract project.
        remote = project / "scenes/player/remote_player.tscn"
        remote.parent.mkdir(parents=True, exist_ok=True)
        remote.write_text('[gd_scene format=3]\n[node name="Remote" type="Node3D"]\n')
        vrm = project / "addons/vrm/vrm_extension.gd"
        vrm.parent.mkdir(parents=True, exist_ok=True)
        vrm.write_text("extends GLTFDocumentExtension\n")
        shutil.copy2(HERE / "suite.gd", project / "suite.gd")
        shutil.copy2(HERE / "startup_suite.gd", project / "startup_suite.gd")
        (project / "project.godot").write_text(
            'config_version=5\n'
            '[application]\nconfig/name="Discovery contract tests"\n'
            '[autoload]\n'
            'NetworkHandler="*res://fixtures/network_handler.gd"\n'
            'DataLoader="*res://fixtures/data_loader.gd"\n'
            'SaveData="*res://fixtures/save_data.gd"\n'
            '[rendering]\nrenderer/rendering_method="gl_compatibility"\n'
        )
        # Register class_name scripts without using/modifying the game's cache.
        imported = subprocess.run(
            [godot, "--headless", "--path", directory, "--editor", "--import"],
            capture_output=True, text=True, timeout=90,
        )
        if imported.returncode or "ERROR:" in imported.stdout + imported.stderr:
            print(imported.stdout + imported.stderr)
            return imported.returncode or 2
        result = subprocess.run(
            [godot, "--headless", "--path", directory, "--script", "res://suite.gd"],
            capture_output=True, text=True, timeout=60,
        )
        print(result.stdout, end="")
        if result.stderr:
            print(result.stderr, end="")
        # Script errors are infrastructure failures, not expected red tests.
        if "ERROR:" in result.stdout + result.stderr:
            return 2
        if result.returncode:
            return result.returncode
        config = project / "project.godot"
        config.write_text(config.read_text().replace(
            '*res://fixtures/network_handler.gd',
            '*res://scripts/multiplayer/network_handler.gd',
        ))
        startup = subprocess.run(
            [godot, "--headless", "--path", directory, "--script", "res://startup_suite.gd"],
            capture_output=True, text=True, timeout=60,
        )
        print(startup.stdout, end="")
        print(startup.stderr, end="")
        if "ERROR:" in startup.stdout + startup.stderr:
            return 2
        return startup.returncode


if __name__ == "__main__":
    raise SystemExit(main())
