#!/usr/bin/env python3
"""Run real world storage/runtime checks in a disposable, account-free project."""

import os
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
SOURCES = ("world_data.gd", "world_local_store.gd", "world_script_vm.gd", "world_runtime.gd")


def result_code(result):
    output = result.stdout + result.stderr
    if "ERROR:" in output or result.returncode not in (0, 1):
        return 2
    if result.returncode == 0 and "Roguelike foundations:" not in output:
        return 2
    return result.returncode


def main():
    godot = shutil.which(os.environ.get("GODOT", "godot"))
    if not godot:
        print("Infrastructure failure: Godot not found; set GODOT=/path/to/godot")
        return 2
    base = Path("/tmp/opencode")
    try:
        with tempfile.TemporaryDirectory(prefix="roguelike-tests-", dir=base if base.is_dir() else None) as directory:
            project = Path(directory)
            scripts = project / "scripts/worlds"
            scripts.mkdir(parents=True)
            for name in SOURCES:
                shutil.copy2(ROOT / "scripts/worlds" / name, scripts / name)
            shutil.copy2(HERE / "suite.gd", project / "suite.gd")
            (project / "project.godot").write_text(
                'config_version=5\n[application]\nconfig/name="Roguelike foundation tests"\n'
                '[rendering]\nrenderer/rendering_method="gl_compatibility"\n'
            )
            env = os.environ.copy()
            for key in ("HOME", "XDG_DATA_HOME", "XDG_CONFIG_HOME", "XDG_CACHE_HOME"):
                location = project / key.lower()
                location.mkdir()
                env[key] = str(location)
            for arguments in (["--editor", "--import"], ["--script", "res://suite.gd"]):
                result = subprocess.run(
                    [godot, "--headless", "--path", directory, *arguments],
                    capture_output=True, text=True, env=env, timeout=90,
                )
                print(result.stdout, end="")
                print(result.stderr, end="")
                if "--editor" in arguments:
                    if result.returncode or "ERROR:" in result.stdout + result.stderr:
                        return 2
                else:
                    return result_code(result)
    except (OSError, subprocess.TimeoutExpired) as error:
        print(f"Infrastructure failure: {error}")
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
