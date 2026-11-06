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
    parser.add_argument('--house', action='store_true', help='Run house/side-space clearance contracts')
    parser.add_argument('--lighting', action='store_true', help='Run independent room lighting contracts')
    parser.add_argument('--kitchen', action='store_true', help='Run kitchen controls and inventory contracts')
    parser.add_argument('--landscape', action='store_true', help='Run landscape/resource budget contracts')
    parser.add_argument('--acceptance', action='store_true', help='Run combined no-help home lifecycle acceptance')
    parser.add_argument('--forward-plus', action='store_true', help='Use production Forward Plus rendering instead of Compatibility')
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
        if (ROOT / 'assets/welcome_island/models/furniture').exists():
            shutil.copytree(ROOT / 'assets/welcome_island/models/furniture', project / 'assets/welcome_island/models/furniture', dirs_exist_ok=True, ignore=shutil.ignore_patterns('*.import'))
        for name in ['kitchenware', 'runtime', 'pine_sapling_small', 'boulder_01']:
            source = ROOT / 'assets/welcome_island/models' / name
            if source.exists(): shutil.copytree(source, project / 'assets/welcome_island/models' / name, dirs_exist_ok=True, ignore=shutil.ignore_patterns('*.import', '*.uid'))
        for name in ['architecture', 'style']:
            source = ROOT / 'assets/welcome_island/models' / name
            if source.exists(): shutil.copytree(source, project / 'assets/welcome_island/models' / name, dirs_exist_ok=True, ignore=shutil.ignore_patterns('*.import', '*.uid'))
        shutil.copy2(HERE / ('acceptance_suite.gd' if args.acceptance else 'landscape_suite.gd' if args.landscape else 'kitchen_suite.gd' if args.kitchen else 'lighting_suite.gd' if args.lighting else 'house_suite.gd' if args.house else 'ship_suite.gd' if args.ship else 'pond_suite.gd' if args.pond else 'recovery_suite.gd' if args.recovery else 'layout_suite.gd'), project / 'suite.gd')
        renderer = 'gl_compatibility' if not args.forward_plus else 'forward_plus'
        (project / 'project.godot').write_text('config_version=5\n[application]\nconfig/name="Island layout contracts"\n[rendering]\nrenderer/rendering_method="' + renderer + '"\n')
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
