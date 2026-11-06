#!/usr/bin/env python3
"""Local release matrix: all selected groups run; failures/skips never become passes."""
import argparse
from datetime import datetime, timezone
import json
from pathlib import Path
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[2]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--rendered', action='store_true')
    parser.add_argument('--template', type=Path)
    args = parser.parse_args()
    commands = [
        ['tests/welcome_island/run_layout.py', '--streaming'],
        ['tools/assets/provenance.py'], ['tests/welcome_island/test_provenance.py'],
        ['tools/assets/build_home_revision.py', '--check'], ['tests/welcome_island/run.py'],
        ['tests/welcome_island/run_assets.py'], ['tests/welcome_island/run_interactions.py'],
        ['tests/welcome_island/run_credits.py'], ['tests/welcome_island/run_credits.py', '--help-suite'],
        *[['tests/welcome_island/run_layout.py', *group] for group in [[], ['--house'], ['--lighting'], ['--kitchen'], ['--pond'], ['--ship'], ['--recovery'], ['--landscape'], ['--acceptance']]],
        ['tests/public_discovery/run.py'], ['tests/active_instance/run.py'],
        ['tests/world_system/run.py'], ['tests/vr_controls/run.py'],
        ['tests/microphone_settings/run.py'], ['tests/real_ui/run.py', '--suite', 'startup'],
    ]
    commands.append(['tests/welcome_island/run_export.py', *(['--template', str(args.template)] if args.template else [])])
    results = []
    artifacts = Path(tempfile.mkdtemp(prefix='welcome-release-results-', dir='/tmp/opencode'))
    print('Artifacts:', artifacts, flush=True)
    try:
        revision = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip()
    except (OSError, subprocess.CalledProcessError):
        revision = 'source snapshot (no git metadata)'
    for index, command in enumerate(commands):
        if args.rendered and command[0] == 'tests/welcome_island/run_layout.py': command.append('--rendered')
        try:
            result = subprocess.run([sys.executable, *command], cwd=ROOT, capture_output=True, text=True, timeout=300)
            (artifacts / f'{index:02}.log').write_text(result.stdout + result.stderr)
            results.append((result.returncode, ' '.join(command)))
        except subprocess.TimeoutExpired as error:
            def text(value):
                return value.decode(errors='replace') if isinstance(value, bytes) else value or ''
            (artifacts / f'{index:02}.log').write_text(text(error.stdout) + text(error.stderr) + '\nInfrastructure timeout\n')
            results.append((2, ' '.join(command) + ' (timeout)'))
        except OSError as error:
            (artifacts / f'{index:02}.log').write_text(f'Infrastructure failure: {error}\n')
            results.append((2, ' '.join(command)))
        print(('PASS' if results[-1][0] == 0 else 'FAIL/BLOCKED'), results[-1][1], flush=True)
        (artifacts / 'summary.json').write_text(json.dumps({
            'revision': revision,
            'recorded_at': datetime.now(timezone.utc).isoformat(),
            'scope': 'local isolated checks; working-tree sources may include uncommitted changes',
            'results': [{'exit_code': code, 'command': name, 'log': f'{i:02}.log'}
                        for i, (code, name) in enumerate(results)],
            'release_ready': False,
            'manual_gates': ['real-headset/controller/comfort', 'human free-exploration',
                             'final landscape art', 'named-device frame/VRAM budgets'],
        }, indent=2) + '\n')
    print('Artifacts:', artifacts)
    print('Hardware gate: NOT RUN — real headset and human comfort/playtest required.')
    return 1 if any(code for code, _ in results) else 0


if __name__ == '__main__': raise SystemExit(main())
