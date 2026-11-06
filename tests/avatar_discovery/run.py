#!/usr/bin/env python3
"""Avatar discovery contracts; disposable files, loopback API by default."""
import http.server
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import threading
import urllib.parse

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent


class Handler(http.server.BaseHTTPRequestHandler):
    def log_message(self, *_args):
        pass

    def do_GET(self):
        url = urllib.parse.urlsplit(self.path)
        query = urllib.parse.parse_qs(url.query)
        redirects = {
            "/redirect-relative": "catalog",
            "/redirect-query": "?finished=1",
            "/redirect-origin": "//127.0.0.1:%s/catalog" % self.server.server_port,
            "/redirect-private": "/catalog",
        }
        if url.path in redirects and not (url.path == "/redirect-query" and "finished" in query):
            self.send_response(302)
            self.send_header("Location", redirects[url.path])
            if url.path == "/redirect-private":
                self.send_header("Cache-Control", "no-store")
            self.end_headers()
            return
        if url.path == "/rate-limit":
            self.send_response(429)
            self.send_header("Retry-After", "60")
            self.end_headers()
            return
        if url.path == "/login-required":
            self.send_response(401)
            self.end_headers()
            return
        if url.path == "/bad":
            body = b"not-json"
        else:
            items = [
                {"id": "avatar-a", "type": "avatar", "title": "Robot", "format": "vrm",
                 "license": "CC0-1.0", "page_url": "https://example.test/robot"},
                {"id": "motion-a", "type": "animation", "title": "Wave", "format": "vrma",
                 "license": "CC0-1.0", "page_url": "https://example.test/wave"},
            ]
            if url.path == "/bad-consent":
                items[0]["redistribution"] = 1
            if query.get("type", ["all"])[0] != "all":
                items = [item for item in items if item["type"] == query["type"][0]]
            body = json.dumps({"schema": 1, "items": items, "next_cursor": None if url.path == "/null-cursor" else "page-2",
                "request_received": {"authorization": self.headers.get("Authorization", ""),
                                     "cookie": self.headers.get("Cookie", ""),
                                     "query": query}}).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--display", action="store_true", help="Run browser contracts with a real window (no headset)")
    args = parser.parse_args()
    godot = shutil.which(os.environ.get("GODOT", "godot"))
    if not godot:
        print("Godot required (override with GODOT)")
        return 2
    server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Handler)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    try:
        with tempfile.TemporaryDirectory(prefix="comunicare-avatar-discovery-", dir="/tmp/opencode") as directory:
            project = Path(directory)
            # Production feature modules, never real startup/accounts/autoloads.
            source = ROOT / "scripts/discovery/avatars"
            if source.exists():
                shutil.copytree(source, project / "scripts/discovery/avatars")
            if (ROOT / "scripts/GUI/avatar_browser").is_dir():
                shutil.copytree(ROOT / "scripts/GUI/avatar_browser", project / "scripts/GUI/avatar_browser")
                shutil.copytree(ROOT / "themes/icons", project / "themes/icons")
            for relative in ("scripts/GUI/avatar_browser.gd", "scenes/GUI/avatar_browser.tscn", "scripts/GUI/toast_host.gd"):
                if (ROOT / relative).exists():
                    target = project / relative
                    target.parent.mkdir(parents=True, exist_ok=True)
                    shutil.copy2(ROOT / relative, target)
            shutil.copy2(HERE / "suite.gd", project / "suite.gd")
            reader = project / "scripts/assets/humanoid_animation.gd"
            reader.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(ROOT / "scripts/assets/humanoid_animation.gd", reader)
            shutil.copy2(ROOT / "scripts/assets/avatar_size_policy.gd", reader.with_name("avatar_size_policy.gd"))
            if os.environ.get("ANIMATION_FIXTURE"):
                shutil.copy2(os.environ["ANIMATION_FIXTURE"], project / "sample.vrma")
            if os.environ.get("LIVE_DISCOVERY") == "1":
                (project / "live-opt-in.txt").write_text("explicit external API verification")
            if os.environ.get("KEYRING_TEST") == "1":
                (project / "keyring-opt-in.txt").write_text("explicit synthetic OS keyring roundtrip")
            (project / "home_scene.txt").write_text((ROOT / "scripts/GUI/tablet_shell.gd").read_text() + (ROOT / "scripts/GUI/quick_page.gd").read_text())
            (project / "port.txt").write_text(str(server.server_port))
            (project / "project.godot").write_text(
                'config_version=5\n[application]\nconfig/name="Avatar discovery RED contracts"\n'
                '[rendering]\nrenderer/rendering_method="gl_compatibility"\n')
            for command in (["--headless", "--editor", "--import"], ([] if args.display else ["--headless"]) + ["--script", "res://suite.gd"]):
                result = subprocess.run([godot, "--path", directory, *command],
                                        capture_output=True, text=True, timeout=60)
                output = result.stdout + result.stderr
                if "--script" in command or result.returncode or "ERROR:" in output:
                    print(output, end="")
                if "ERROR:" in output:
                    return 2
                if result.returncode:
                    return result.returncode
        return 0
    except subprocess.TimeoutExpired:
        print("Infrastructure failure: Godot timed out")
        return 2
    finally:
        server.shutdown()
        server.server_close()
        thread.join()


if __name__ == "__main__":
    raise SystemExit(main())
