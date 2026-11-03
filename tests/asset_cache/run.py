#!/usr/bin/env python3
"""Asset storage and real conditional HTTP checks, with no real user data."""
import http.server
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import threading

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent


class Handler(http.server.BaseHTTPRequestHandler):
    revision = 1
    requests = 0

    def log_message(self, *_args):
        pass

    def do_GET(self):
        if self.path == "/advance":
            Handler.revision += 1
            self.send_response(200)
            self.end_headers()
            return
        Handler.requests += 1
        tag = f'"v{Handler.revision}"'
        if self.path == "/fail":
            self.send_response(503)
            self.end_headers()
            return
        if self.headers.get("If-None-Match") == tag:
            self.send_response(304)
            self.end_headers()
            return
        data = f"valid-revision-{Handler.revision}".encode()
        if self.path == "/bad":
            data = b"invalid"
        self.send_response(200)
        self.send_header("ETag", tag)
        self.send_header("Content-Length", str(len(data)))
        if self.path == "/private":
            self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(data)


def main():
    godot = shutil.which(os.environ.get("GODOT", "godot"))
    if not godot:
        return 2
    server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Handler)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    try:
        with tempfile.TemporaryDirectory(prefix="comunicare-cache-", dir="/tmp/opencode") as directory:
            project = Path(directory)
            shutil.copytree(ROOT / "scripts/assets", project / "scripts/assets")
            shutil.copy2(HERE / "suite.gd", project / "suite.gd")
            (project / "port.txt").write_text(str(server.server_port))
            (project / "project.godot").write_text(
                'config_version=5\n[application]\nconfig/name="Asset cache tests"\n'
                '[rendering]\nrenderer/rendering_method="gl_compatibility"\n')
            for args in (["--editor", "--import"], ["--script", "res://suite.gd"]):
                try:
                    result = subprocess.run([godot, "--headless", "--path", directory, *args],
                                            capture_output=True, text=True, timeout=45)
                except subprocess.TimeoutExpired as error:
                    print((error.stdout or b"").decode() + (error.stderr or b"").decode())
                    return 2
                output = result.stdout + result.stderr
                if "--script" in args or result.returncode or "ERROR:" in output:
                    print(output, end="")
                if "ERROR:" in output:
                    return 2
                if result.returncode:
                    return result.returncode
        return 0
    finally:
        server.shutdown()
        server.server_close()


if __name__ == "__main__":
    raise SystemExit(main())
