#!/usr/bin/env python3
"""Provision a local relay identity/config outside the repository; never overwrite keys."""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]


def validate_destination(destination):
    path = Path(destination).expanduser().resolve()
    if path == ROOT or ROOT in path.parents:
        raise ValueError("Keep relay private keys outside the source repository.")
    if path.exists():
        raise ValueError("Destination already exists; keys/config will not be overwritten.")
    return path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory")
    parser.add_argument("--port", type=int, default=7375, help="TLS port (gameplay UDP remains 7374)")
    parser.add_argument("--label", default="My Comunicare relay")
    parser.add_argument("--lan", action="store_true", help="Opt in to local IPv4 multicast advertisement")
    args = parser.parse_args()
    if not 1 <= args.port <= 65535:
        parser.error("port must be 1..65535")
    try:
        destination = validate_destination(args.directory)
    except ValueError as error:
        parser.error(str(error))
    godot = shutil.which(os.environ.get("GODOT", "godot"))
    if not godot:
        parser.error("Godot required; set GODOT to its executable")
    destination.mkdir(parents=True, mode=0o700)
    # Do not start the game or import its account/settings autoloads.
    script = '''extends SceneTree
func _initialize():
    var target = OS.get_cmdline_user_args()[0]
    var key = Crypto.new().generate_rsa(3072)
    if key == null:
        quit(2)
        return
    var certificate = Crypto.new().generate_self_signed_certificate(key, "CN=comunicare-relay,O=Comunicare,C=DE", "20250101000000", "20350101000000")
    if certificate == null or key.save(target.path_join("relay.key")) != OK or key.save(target.path_join("relay.pub"), true) != OK or certificate.save(target.path_join("relay.crt")) != OK:
        quit(2)
        return
    var hash = HashingContext.new()
    hash.start(HashingContext.HASH_SHA256)
    hash.update(key.save_to_string(true).to_utf8_buffer())
    var file = FileAccess.open(target.path_join("relay-id.txt"), FileAccess.WRITE)
    if file == null:
        quit(2)
        return
    file.store_string(hash.finish().hex_encode() + "\\n")
    file.close()
    quit(0)
'''
    with tempfile.TemporaryDirectory(prefix="relay-provision-", dir="/tmp/opencode") as temporary:
        temp = Path(temporary)
        (temp / "project.godot").write_text('config_version=5\n[application]\nconfig/name="Relay provisioning"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n')
        (temp / "provision.gd").write_text(script)
        env = {**os.environ, "XDG_DATA_HOME": str(temp / "data"), "XDG_CONFIG_HOME": str(temp / "config"), "XDG_CACHE_HOME": str(temp / "cache")}
        try:
            result = subprocess.run([godot, "--headless", "--path", temporary, "--script", "res://provision.gd", "--", str(destination)],
                                    capture_output=True, text=True, timeout=90, env=env)
        except (OSError, subprocess.TimeoutExpired) as error:
            print(f"Provisioning failed; inspect preserved partial directory {destination}: {error}")
            return 2
    if (destination / "relay.key").exists():
        (destination / "relay.key").chmod(0o600)
    if result.returncode or "ERROR:" in result.stdout + result.stderr:
        print(result.stdout + result.stderr)
        print(f"Provisioning failed; partial files preserved at {destination}. No existing keys were replaced.")
        return 2
    config = {"schema": 1, "key": str(destination / "relay.key"), "certificate": str(destination / "relay.crt"),
              "bind": "0.0.0.0", "port": args.port, "label": args.label[:128], "lan_enabled": args.lan,
              "blocks": [], "peers": []}
    (destination / "relay.json").write_text(json.dumps(config, indent=2) + "\n")
    (destination / "relay.json").chmod(0o600)
    print(f"Created relay configuration: {destination / 'relay.json'}")
    print(f"Relay ID: {(destination / 'relay-id.txt').read_text().strip()}")
    print("Share only relay.pub, relay.crt and relay-id.txt with trusted peers/clients. Never share relay.key.")
    print("Start from the game repository:")
    print(f'godot --path . --relay -- --federation-config="{destination / "relay.json"}"')
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
