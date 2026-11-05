#!/usr/bin/env python3
"""Opt-in RED acceptance tests for the GUI theme/tablet/avatar-preview roadmap.

Every check is tagged with its roadmap part ([P1]..[P12]). Exit 0 = all pass,
1 = assertion failures (expected until parts are implemented), 2 = broken test
project, Godot error or missing prerequisite. No account, relay, network, XR
runtime or real user data is used.
"""
import argparse
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
INVENTORY = ROOT / "tools/gui/style_inventory.py"
ALLOWLIST = ROOT / "tools/gui/style_allowlist.txt"
SUITES = [
    ("theme_suite.gd", {2, 3, 4, 5}),
    ("shell_suite.gd", {6, 7}),
    ("vr_tablet_suite.gd", {8}),
    ("settings_suite.gd", {8, 9}),
    ("preview_suite.gd", {10}),
    ("browser_suite.gd", {11, 12}),
]
PRESET_NAMES = ["Graphite", "Paper", "Forest", "Sand", "Night", "High contrast"]
LINE = re.compile(r"^(PASS|FAIL): \[P(\d+)\] (.*)$", re.M)


class Results:
    def __init__(self, parts):
        self.parts = parts
        self.counts = {}

    def check(self, part, value, title):
        if part not in self.parts:
            return
        status = "PASS" if value else "FAIL"
        print(f"{status}: [P{part}] {title}", flush=True)
        self.add(part, status)

    def add(self, part, status):
        passed, failed = self.counts.get(part, (0, 0))
        self.counts[part] = (passed + (status == "PASS"), failed + (status == "FAIL"))

    def failed(self):
        return sum(failed for _, failed in self.counts.values())


def run_inventory(*args):
    return subprocess.run([sys.executable, str(INVENTORY), *args], capture_output=True, text=True, timeout=60)


def write(path, text):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text)


def python_part1(results):
    if 1 not in results.parts:
        return
    results.check(1, INVENTORY.is_file(), "style inventory tool exists: tools/gui/style_inventory.py")
    if INVENTORY.is_file():
        with tempfile.TemporaryDirectory(dir="/tmp/opencode" if Path("/tmp/opencode").is_dir() else None) as directory:
            dirty = Path(directory) / "dirty"
            write(dirty / "scripts/GUI/a.gd", 'extends Control\nvar c = Color("123456")\n'
                  'func _ready():\n\tadd_theme_color_override("font_color", c)\n')
            write(dirty / "scenes/GUI/b.tscn", '[gd_scene format=3]\n[node name="B" type="Label"]\n'
                  'theme_override_colors/font_color = Color(1, 0, 0, 1)\ntheme_override_constants/line_spacing = 8\n')
            clean = Path(directory) / "clean"
            write(clean / "scripts/GUI/a.gd", 'extends Control\nfunc _ready():\n\tpass\n')
            write(clean / "scenes/GUI/b.tscn", '[gd_scene format=3]\n[node name="B" type="Label"]\n')
            listed = run_inventory("--root", str(dirty), "--json")
            try:
                findings = json.loads(listed.stdout)
            except json.JSONDecodeError:
                findings = None
            valid = isinstance(findings, list) and all(
                isinstance(item, dict) and isinstance(item.get("line"), int) and "path" in item and "kind" in item
                for item in findings)
            results.check(1, listed.returncode == 0 and valid, "--json lists findings with path, line and kind")
            if valid:
                kinds = sorted(item["kind"] for item in findings)
                results.check(1, kinds == ["color_literal", "scene_override", "scene_override", "script_override"],
                              f"detects color literals, script overrides and scene overrides (got {kinds})")
                results.check(1, all(not Path(item["path"]).is_absolute() and "\\" not in item["path"] for item in findings),
                              "finding paths are relative POSIX paths")
            results.check(1, run_inventory("--root", str(dirty), "--check").returncode == 1, "--check fails on hard-coded styling")
            results.check(1, run_inventory("--root", str(clean), "--check").returncode == 0, "--check passes a clean tree")
            allow = Path(directory) / "allow.txt"
            allow.write_text("# path:line or path:* followed by a reason\nscripts/GUI/a.gd:* # fixture\n")
            partial = run_inventory("--root", str(dirty), "--check", "--allowlist", str(allow))
            allow.write_text("scripts/GUI/a.gd:* # fixture\nscenes/GUI/b.tscn:3 # fixture\nscenes/GUI/b.tscn:4 # fixture\n")
            full = run_inventory("--root", str(dirty), "--check", "--allowlist", str(allow))
            results.check(1, partial.returncode == 1 and full.returncode == 0, "allowlist suppresses exactly the listed findings")
    real_ui = (ROOT / "tests/real_ui/run.py").read_text()
    results.check(1, "--capture" in real_ui, "tests/real_ui offers a screenshot capture mode (wiring check)")


def python_part4(results):
    if 4 not in results.parts:
        return
    if not INVENTORY.is_file():
        results.check(4, False, "repository styling inventory needs tools/gui/style_inventory.py")
        return
    checked = run_inventory("--root", str(ROOT), "--check")
    results.check(4, checked.returncode == 0,
                  "scripts/GUI and scenes/GUI have no non-allowlisted hard-coded styling\n" + checked.stdout[-1500:])
    if ALLOWLIST.is_file():
        entries = [line for line in ALLOWLIST.read_text().splitlines() if line.strip() and not line.lstrip().startswith("#")]
        results.check(4, len(entries) <= 10 and all(" # " in line and line.split(" # ", 1)[1].strip() for line in entries),
                      "allowlist is short and every entry states a reason")


def python_part12(results):
    if 12 not in results.parts:
        return
    guides = [path for path in (ROOT / "docs").rglob("*.md") if "roadmaps" not in path.parts]
    texts = {path: path.read_text() for path in guides}
    results.check(12, any("tablet" in text.lower() and "grip" in text.lower() for text in texts.values()),
                  "user docs explain the VR tablet and how to grab it")
    results.check(12, any(all(name in text for name in PRESET_NAMES) for text in texts.values()),
                  "user docs list all color presets")


def section(text, name):
    match = re.search(r"^\[" + re.escape(name) + r"\]\n(.*?)(?=^\[|\Z)", text, re.M | re.S)
    return f"[{name}]\n{match.group(1)}" if match else ""


def build_project(project):
    for folder in ("scripts", "relay_protocol", "scenes/GUI", "themes"):
        shutil.copytree(ROOT / folder, project / folder, ignore=shutil.ignore_patterns("__pycache__"))
    for name in ("default_bus_layout.tres", "assets/credits.json", "assets/welcome_island/manifest.json"):
        if (ROOT / name).is_file():
            (project / name).parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(ROOT / name, project / name)
    shutil.copytree(HERE / "fixtures", project / "fixtures")
    for name in ["common.gd", *[suite for suite, _ in SUITES]]:
        shutil.copy2(HERE / name, project / name)
    evidence = project / "evidence"
    evidence.mkdir()
    for source in ("project.godot", "THIRD_PARTY_ASSETS.md", "scenes/player/player_desktop.tscn"):
        if (ROOT / source).is_file():
            shutil.copy2(ROOT / source, evidence / (Path(source).name + ".txt"))
    original = (ROOT / "project.godot").read_text()
    (project / "project.godot").write_text(
        'config_version=5\n[application]\nconfig/name="GUI tablet contracts"\n'
        '[autoload]\nSaveData="*res://fixtures/save_data.gd"\n'
        'NetworkHandler="*res://fixtures/network_handler.gd"\nDataLoader="*res://fixtures/data_loader.gd"\n'
        '[rendering]\nrenderer/rendering_method="gl_compatibility"\n'
        + section(original, "input") + section(original, "gui") + section(original, "display"))


def run_godot(godot, results, timeout):
    selected = [(suite, parts) for suite, parts in SUITES if parts & results.parts]
    if not selected:
        return 0
    temp_root = Path("/tmp/opencode")
    with tempfile.TemporaryDirectory(prefix="comunicare-gui-tablet-", dir=temp_root if temp_root.is_dir() else None) as directory:
        project = Path(directory)
        build_project(project)
        env = {**os.environ, "GUI_PARTS": ",".join(str(part) for part in sorted(results.parts))}
        base = [godot, "--headless", "--path", directory]
        imported = subprocess.run([*base, "--editor", "--import"], capture_output=True, text=True, timeout=180, env=env)
        if imported.returncode or "ERROR:" in imported.stdout + imported.stderr:
            print(imported.stdout + imported.stderr)
            return 2
        for suite, _ in selected:
            try:
                result = subprocess.run([*base, "--script", "res://" + suite], capture_output=True, text=True,
                                        timeout=timeout, env=env)
            except subprocess.TimeoutExpired as error:
                print(error.stdout or "", error.stderr or "")
                print(f"Infrastructure timeout in {suite}")
                return 2
            output = result.stdout + result.stderr
            print(output, end="", flush=True)
            if "ERROR:" in output or "GUI tablet " not in output or result.returncode not in (0, 1):
                print(f"Infrastructure failure in {suite} (exit {result.returncode})")
                return 2
            for status, part, _ in LINE.findall(result.stdout):
                results.add(int(part), status)
    return 0


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--part", type=int, action="append", choices=range(1, 13), metavar="N",
                        help="run only roadmap part N (repeatable)")
    parser.add_argument("--timeout", type=int, default=120, help="per Godot suite timeout in seconds")
    args = parser.parse_args()
    results = Results(set(args.part or range(1, 13)))
    python_part1(results)
    python_part4(results)
    python_part12(results)
    status = 0
    if any(parts & results.parts for _, parts in SUITES):
        godot = shutil.which(os.environ.get("GODOT", "godot"))
        if not godot:
            print("Godot 4.7 required; set GODOT")
            return 2
        status = run_godot(godot, results, args.timeout)
    print("\nGUI tablet acceptance by roadmap part:")
    for part in sorted(results.counts):
        passed, failed = results.counts[part]
        print(f"  Part {part:2d}: {passed:3d} passed, {failed:3d} failed")
    total_passed = sum(passed for passed, _ in results.counts.values())
    print(f"  Total:   {total_passed:3d} passed, {results.failed():3d} failed")
    if status:
        return status
    return 1 if results.failed() else 0


if __name__ == "__main__":
    raise SystemExit(main())
