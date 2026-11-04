#!/usr/bin/env python3
"""Full production-autoload/UI regression runner with isolated accounts and artifacts."""
import argparse
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import re

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--rendered", action="store_true", help="Open a dedicated X11 test window and capture screenshots")
    args = parser.parse_args()
    godot = shutil.which(os.environ.get("GODOT", "godot"))
    if not godot:
        print("Godot required; set GODOT")
        return 2
    artifacts = Path(tempfile.mkdtemp(prefix="comunicare-real-ui-", dir="/tmp/opencode"))
    print(f"Artifacts: {artifacts} (contains disposable private keys; do not publish wholesale)", flush=True)
    project = artifacts / "project"
    project.mkdir()
    names = subprocess.check_output(["git", "ls-files", "--cached", "--others", "--exclude-standard", "-z"], cwd=ROOT).decode().split("\0")
    # Never copy real user data or the game's generated import cache. Known source
    # directories only, even if the user has unrelated untracked files elsewhere.
    for name in set(names):
        relative = Path(name)
        if not name or relative.parts[0] not in ("scripts", "scenes", "relay_protocol", "themes", "assets", "addons", "config"):
            continue
        source = ROOT / relative
        if source.is_file():
            target = project / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, target)
    for name in ("project.godot", "default_bus_layout.tres", "openxr_action_map.tres", "icon.svg"):
        if (ROOT / name).is_file(): shutil.copy2(ROOT / name, project / name)
    config = project / "project.godot"
    content = config.read_text().replace('config/name="comunicare"', 'config/name="Comunicare isolated UI tests"')
    # Runtime UI tests do not exercise editor import plugins. The vendored VRM
    # plugin currently has 4.7 callback return errors; record, don't mask globally.
    content = re.sub(r'\[editor_plugins\]\n.*?(?=\n\[)', '[editor_plugins]\nenabled=PackedStringArray()\n', content, flags=re.S)
    config.write_text(content)
    shutil.copy2(HERE / "suite.gd", project / "ui_suite.gd")
    env = {**os.environ, "XDG_DATA_HOME": str(artifacts / "data"), "XDG_CONFIG_HOME": str(artifacts / "config"), "XDG_CACHE_HOME": str(artifacts / "cache")}
    command = [godot, "--path", str(project), "--rendering-method", "gl_compatibility", "--xr-mode", "off"]
    try:
        imported = subprocess.run([*command, "--headless", "--editor", "--import"], capture_output=True, text=True, timeout=120, env=env)
        (artifacts / "import.log").write_text(imported.stdout + imported.stderr)
        if imported.returncode or "ERROR:" in imported.stdout + imported.stderr:
            print(imported.stdout + imported.stderr)
            return 2
        display = ["--display-driver", "x11"] if args.rendered else ["--headless"]
        result = subprocess.run([*command, *display, "--script", "res://ui_suite.gd", "--non_vr"], capture_output=True, text=True, timeout=90, env=env)
        output = result.stdout + result.stderr
        (artifacts / "suite.log").write_text(output)
        print(output, end="")
        if "ERROR:" in output or "Real UI acceptance:" not in output or result.returncode not in (0, 1): return 2
        return result.returncode
    except subprocess.TimeoutExpired as error:
        output = (error.stdout or b"").decode() + (error.stderr or b"").decode()
        (artifacts / "timeout.log").write_text(output)
        print(output, end="")
        print(f"Infrastructure timeout: {error}")
        return 2
    except OSError as error:
        print(f"Infrastructure failure: {error}")
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
