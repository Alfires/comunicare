#!/usr/bin/env python3
"""Full production-autoload/UI regression runner with isolated accounts and artifacts."""
import argparse
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import re
import time
import threading
import functools
import http.server
import zipfile
import json

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--rendered", action="store_true", help="Open a dedicated X11 test window and capture screenshots")
    parser.add_argument("--suite", choices=["ui", "startup", "vr", "all"], default="all")
    parser.add_argument("--plugins", action="store_true", help="Import with production editor plugins enabled (compatibility gate)")
    parser.add_argument("--soak-seconds", type=int, default=0, help="Extend UI membership/edit soak (1200 for 20 minutes)")
    parser.add_argument("--two-clients", action="store_true", help="Run two isolated processes with real UI join and HTTP example world")
    parser.add_argument("--original-world", action="store_true", help="Use unmodified built-in world rather than lifecycle shell fixture")
    args = parser.parse_args()
    if args.soak_seconds < 0 or args.soak_seconds > 3600: parser.error("soak duration must be 0..3600 seconds")
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
    if not args.plugins:
        content = re.sub(r'\[editor_plugins\]\n.*?(?=\n\[)', '[editor_plugins]\nenabled=PackedStringArray()\n', content, flags=re.S)
    config.write_text(content)
    (project / "override.cfg").write_text('[discovery]\nworld_catalog_url=""\n')
    shutil.copy2(HERE / "suite.gd", project / "ui_suite.gd")
    shutil.copy2(HERE / "startup_suite.gd", project / "startup_suite.gd")
    for filename in ("two_client.gd", "two_relay.gd", "vr_suite.gd"):
        shutil.copy2(HERE / filename, project / filename)
    env = {**os.environ, "XDG_DATA_HOME": str(artifacts / "data"), "XDG_CONFIG_HOME": str(artifacts / "config"), "XDG_CACHE_HOME": str(artifacts / "cache")}
    env["COMUNICARE_UI_SOAK_SECONDS"] = str(args.soak_seconds)
    env["COMUNICARE_UI_ORIGINAL_WORLD"] = "1" if args.original_world else "0"
    command = [godot, "--path", str(project), "--rendering-method", "gl_compatibility", "--xr-mode", "off"]
    try:
        imported = subprocess.run([*command, "--headless", "--editor", "--import"], capture_output=True, text=True, timeout=120, env=env)
        (artifacts / "import.log").write_text(imported.stdout + imported.stderr)
        if imported.returncode or "ERROR:" in imported.stdout + imported.stderr:
            print(imported.stdout + imported.stderr)
            return 2
        display = ["--display-driver", "x11"] if args.rendered else ["--headless"]
        if args.two_clients: return run_two_clients(command, display, artifacts, env)
        status = 0
        for suite in (["startup", "ui"] if args.suite == "all" else [args.suite]):
            filename = {"ui": "ui_suite.gd", "startup": "startup_suite.gd", "vr": "vr_suite.gd"}[suite]
            marker = {"ui": "Real UI acceptance:", "startup": "Real startup acceptance:", "vr": "VR emulator acceptance:"}[suite]
            result = subprocess.run([*command, *display, "--script", "res://" + filename, "--non_vr"], capture_output=True, text=True, timeout=90 + args.soak_seconds, env=env)
            output = result.stdout + result.stderr
            (artifacts / (suite + ".log")).write_text(output)
            print(output, end="", flush=True)
            if "ERROR:" in output or marker not in output or result.returncode not in (0, 1): return 2
            status = max(status, result.returncode)
        return status
    except subprocess.TimeoutExpired as error:
        output = (error.stdout or b"").decode() + (error.stderr or b"").decode()
        (artifacts / "timeout.log").write_text(output)
        print(output, end="")
        print(f"Infrastructure timeout: {error}")
        return 2
    except OSError as error:
        print(f"Infrastructure failure: {error}")
        return 2


def run_two_clients(command, display, artifacts, env):
    shared = artifacts / "two-clients"
    shared.mkdir()
    example = ROOT / "examples/simple_world"
    with zipfile.ZipFile(shared / "world.cworld", "w", zipfile.ZIP_DEFLATED) as archive:
        archive.write(example / "manifest.json", "manifest.json")
        for folder in ("scenes", "materials", "textures", "logic"):
            for path in sorted((example / folder).rglob("*")):
                if path.is_file() and path.suffix not in (".uid", ".import"):
                    archive.write(path, path.relative_to(example).as_posix())
    with zipfile.ZipFile(shared / "world.cworld") as source:
        with zipfile.ZipFile(shared / "second.cworld", "w", zipfile.ZIP_DEFLATED) as target:
            for name in source.namelist():
                data = source.read(name)
                if name == "manifest.json":
                    manifest = json.loads(data)
                    manifest["world_id"] = "23be948d-e15c-44e5-ae01-aa168940c478"
                    manifest["title"] = "Second test courtyard"
                    data = json.dumps(manifest).encode()
                target.writestr(name, data)
    class QuietHandler(http.server.SimpleHTTPRequestHandler):
        def log_message(self, *args):
            pass
    server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), functools.partial(QuietHandler, directory=str(shared)))
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    url = f"http://127.0.0.1:{server.server_port}/world.cworld"
    relay_log = (shared / "relay.log").open("w")
    relay = subprocess.Popen([*command, "--headless", "--script", "res://two_relay.gd", "--", str(shared / "port")],
                             stdout=relay_log, stderr=subprocess.STDOUT, env=env)
    clients = []
    handles = []
    try:
        deadline = time.monotonic() + 15
        while not (shared / "port").exists() and relay.poll() is None and time.monotonic() < deadline:
            time.sleep(0.02)
        if not (shared / "port").exists():
            print("Relay fixture did not start")
            return 2
        port = (shared / "port").read_text().strip()
        for role in ("host", "guest"):
            client_env = {**env, "XDG_DATA_HOME": str(shared / role / "data"),
                          "XDG_CONFIG_HOME": str(shared / role / "config"), "XDG_CACHE_HOME": str(shared / role / "cache")}
            log = (shared / (role + ".log")).open("w")
            handles.append(log)
            client = subprocess.Popen([*command, *display, "--script", "res://two_client.gd", "--", role, str(shared), port, url],
                                      stdout=log, stderr=subprocess.STDOUT, env=client_env)
            clients.append(client)
        status = 0
        for role, client in zip(("host", "guest"), clients):
            try:
                code = client.wait(timeout=75 + int(env.get("COMUNICARE_UI_SOAK_SECONDS", "0")))
            except subprocess.TimeoutExpired:
                code = 2
            output = (shared / (role + ".log")).read_text()
            print(output, end="", flush=True)
            print(f"CLIENT_EXIT {role}: {code}", flush=True)
            if "ERROR:" in output or "Two client UI result:" not in output or code not in (0, 1):
                status = 2
            elif status != 2:
                status = max(status, code)
        return status
    finally:
        for process in [*clients, relay]:
            if process.poll() is None:
                process.terminate()
                try: process.wait(timeout=5)
                except subprocess.TimeoutExpired: process.kill(); process.wait()
        for handle in handles: handle.close()
        relay_log.close()
        server.shutdown()
        server.server_close()


if __name__ == "__main__":
    raise SystemExit(main())
