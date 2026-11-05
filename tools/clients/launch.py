#!/usr/bin/env python3
"""Launch simultaneous local clients with isolated, temporary identities (no shared user.key)."""
import argparse
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import sys

ROOT = Path(__file__).resolve().parents[2]


def client_environment(directory, index, base=None):
    home = Path(directory) / f"client-{index}"
    return {**(os.environ if base is None else base),
            "XDG_DATA_HOME": str(home / "data"), "XDG_CONFIG_HOME": str(home / "config"),
            "XDG_CACHE_HOME": str(home / "cache")}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--count", type=int, default=2)
    parser.add_argument("--relay", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=7374)
    parser.add_argument("--vr", action="store_true", help="Allow real XR initialization; default forces desktop")
    args = parser.parse_args()
    if not sys.platform.startswith("linux"):
        parser.error("This launcher uses Linux/XDG account isolation; unsupported platform")
    if not 1 <= args.count <= 8 or not 1 <= args.port <= 65535:
        parser.error("count must be 1..8 and port 1..65535")
    if not args.relay or any(c in args.relay for c in '\n\r"\\'):
        parser.error("invalid relay hostname/IP")
    godot = shutil.which(os.environ.get("GODOT", "godot"))
    if not godot: parser.error("Godot required; set GODOT")
    with tempfile.TemporaryDirectory(prefix="comunicare-local-clients-", dir="/tmp/opencode") as directory:
        print(f"Temporary client data: {directory}. Accounts are separate and deleted when the launcher exits.", flush=True)
        processes = []
        try:
            for index in range(args.count):
                env = client_environment(directory, index)
                # Normal production SaveData reads this config before profile/player startup.
                user = Path(env["XDG_DATA_HOME"]) / "godot/app_userdata/comunicare"
                user.mkdir(parents=True)
                (user / "user.cfg").write_text(f'[settings]\nnetwork.relay_address="{args.relay}"\nnetwork.relay_port={float(args.port)}\naudio.microphone_muted=true\n')
                command = [godot, "--path", str(ROOT)]
                if not args.vr: command += ["--xr-mode", "off", "--non_vr"]
                processes.append(subprocess.Popen(command, env=env))
            return max(process.wait() for process in processes)
        except KeyboardInterrupt:
            return 130
        finally:
            for process in processes:
                if process.poll() is None:
                    process.terminate()
                    try: process.wait(timeout=5)
                    except subprocess.TimeoutExpired: process.kill(); process.wait()


if __name__ == "__main__":
    raise SystemExit(main())
