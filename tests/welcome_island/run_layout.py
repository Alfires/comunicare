#!/usr/bin/env python3
"""Disposable built-in island scene/physics checks; no accounts or autoloads."""
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
    parser.add_argument('--rendered', action='store_true')
    parser.add_argument('--recovery', action='store_true', help='Run focused spawn/recovery contracts')
    parser.add_argument('--pond', action='store_true', help='Run pond/dock physics contracts')
    parser.add_argument('--ship', action='store_true', help='Run player-operated ship contracts')
    args = parser.parse_args()
    godot = shutil.which(os.environ.get('GODOT', 'godot'))
    if not godot: return 2
    with tempfile.TemporaryDirectory(prefix='island-layout-', dir='/tmp/opencode') as directory:
        project = Path(directory)
        for name in ['scenes/world.tscn', 'scenes/world.gd', 'scripts/worlds/world_pickup_controller.gd', 'scripts/worlds/world_data.gd', 'scripts/player/vr_safety.gd']:
            target = project / name
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(ROOT / name, target)
        for folder in ['scenes/worlds/welcome_island', 'scripts/worlds/welcome_island']:
            if (ROOT / folder).exists(): shutil.copytree(ROOT / folder, project / folder)
        for id in ['sparse_grass', 'rock_path', 'rock_01', 'weathered_planks']:
            source = ROOT / 'assets/welcome_island/textures' / id
            if source.exists(): shutil.copytree(source, project / 'assets/welcome_island/textures' / id, ignore=shutil.ignore_patterns('*.import'))
        if args.recovery:
            shutil.copytree(ROOT / 'assets/welcome_island', project / 'assets/welcome_island', dirs_exist_ok=True, ignore=shutil.ignore_patterns('*.import', '*.uid'))
        # Baseline legacy dependency; not loaded after the island scene replaces it.
        for name in ['scenes/GUI/vr_gui.tscn', 'scripts/GUI/vr_gui.gd']:
            target = project / name
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(ROOT / name, target)
        if (ROOT / 'assets/welcome_island/models/ship').exists():
            shutil.copytree(ROOT / 'assets/welcome_island/models/ship', project / 'assets/welcome_island/models/ship', dirs_exist_ok=True, ignore=shutil.ignore_patterns('*.import'))
        shutil.copy2(HERE / ('ship_suite.gd' if args.ship else 'pond_suite.gd' if args.pond else 'recovery_suite.gd' if args.recovery else 'layout_suite.gd'), project / 'suite.gd')
        (project / 'project.godot').write_text('config_version=5\n[application]\nconfig/name="Island layout contracts"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n')
        env = {**os.environ, 'XDG_DATA_HOME': str(project / 'data'), 'XDG_CONFIG_HOME': str(project / 'config'), 'XDG_CACHE_HOME': str(project / 'cache'), 'ISLAND_LAYOUT_RENDERED': '1' if args.rendered else '0'}
        try:
            for importing in [True, False]:
                display = ['--display-driver', 'x11'] if args.rendered and not importing else ['--headless']
                extra = ['--editor', '--import'] if importing else ['--script', 'res://suite.gd']
                result = subprocess.run([godot, '--path', directory, *display, *extra], capture_output=True, text=True, timeout=120, env=env)
                output = result.stdout + result.stderr
                if not importing or result.returncode or 'ERROR:' in output: print(output, end='')
                if 'ERROR:' in output or result.returncode not in (0, 1) or (not importing and 'Welcome layout:' not in output): return 2
                if result.returncode: return result.returncode
            return 0
        except (OSError, subprocess.TimeoutExpired) as error:
            if isinstance(error, subprocess.TimeoutExpired):
                for output in (error.stdout, error.stderr):
                    if output: print(output.decode() if isinstance(output, bytes) else output)
            print(error)
            return 2


if __name__ == '__main__': raise SystemExit(main())
