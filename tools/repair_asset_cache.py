#!/usr/bin/env python3
"""Repair trailing-data corruption in a Godot asset-cache index, without data loss.

Close Comunicare first. No account/settings/profile files or asset blobs are
modified. Unsupported schemas and unparseable documents require manual recovery.
"""
import argparse
import hashlib
import json
import math
import os
from pathlib import Path
import tempfile


LIMITS = {"avatar": 1024 * 1024**2, "world": 128 * 1024**2, "animation": 16 * 1024**2}
MAX_INDEX_BYTES = 16 * 1024**2


def valid_index(value):
    if not isinstance(value, dict) or type(value.get("schema")) is not int or value["schema"] != 1:
        return False
    if not isinstance(value.get("sources"), dict):
        return False
    for key, record in value["sources"].items():
        if not isinstance(key, str) or not isinstance(record, dict):
            return False
        kind, digest = record.get("kind"), record.get("hash")
        if not isinstance(kind, str) or kind not in LIMITS:
            return False
        if not isinstance(digest, str) or len(digest) != 64 or any(c not in "0123456789abcdef" for c in digest):
            return False
        for name in ("size", "checked", "accessed"):
            number = record.get(name)
            if type(number) not in (int, float) or not math.isfinite(number):
                return False
        if not 0 < record["size"] <= LIMITS[kind]:
            return False
        if any(not isinstance(record.get(name, ""), str) for name in ("etag", "modified")):
            return False
        if any(type(record.get(name, False)) is not bool for name in ("pinned", "no_cache")):
            return False
    return True


def reject_constant(value):
    raise ValueError("Non-finite JSON number: " + value)


def unique_object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError("Duplicate JSON key; manual recovery required")
        result[key] = value
    return result


def repair(path: Path, dry_run=False):
    if path.is_symlink() or not path.is_file():
        raise ValueError("Index must be an existing regular file, not a symlink")
    if path.stat().st_size > MAX_INDEX_BYTES:
        raise ValueError("Index exceeds the supported 16 MiB limit")
    original = path.read_bytes()
    text = original.decode("utf-8")
    decoder = json.JSONDecoder(parse_constant=reject_constant, object_pairs_hook=unique_object)
    start = len(text) - len(text.lstrip())
    value, end = decoder.raw_decode(text, start)
    if not valid_index(value):
        raise ValueError("Unsupported or invalid cache records; manual recovery required")
    if not text[end:].strip():
        return "Healthy: no repair needed"
    # Only recover an intact, validated first document. Never guess missing data.
    repaired = (text[:end].rstrip() + "\n").encode("utf-8")
    if dry_run:
        return "Repairable: trailing data after a valid cache index (no files changed)"
    backup = path.with_name(path.name + ".corrupt-" + hashlib.sha256(original).hexdigest() + ".bak")
    try:
        with backup.open("xb") as file:
            os.chmod(backup, 0o600)
            file.write(original)
            file.flush()
            os.fsync(file.fileno())
    except FileExistsError:
        if backup.is_symlink() or backup.read_bytes() != original:
            raise ValueError("Backup collision; index left unchanged")
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(dir=path.parent, prefix=".index-repair-", delete=False) as file:
            temporary = Path(file.name)
            file.write(repaired)
            file.flush()
            os.fsync(file.fileno())
        if path.is_symlink() or path.read_bytes() != original:
            raise ValueError("Index changed during repair; close all clients and retry")
        os.replace(temporary, path)
        temporary = None
    finally:
        if temporary is not None:
            temporary.unlink(missing_ok=True)
    return "Repaired trailing data; original preserved at " + str(backup)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    default = Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local/share")) / "godot/app_userdata/comunicare/asset_cache/index.json"
    parser.add_argument("index", nargs="?", type=Path, default=default, help="Cache index path (defaults to Linux Comunicare user cache)")
    parser.add_argument("--dry-run", action="store_true", help="Detect only; do not write or back up files")
    args = parser.parse_args()
    try:
        print(repair(args.index, args.dry_run))
    except (OSError, ValueError, RecursionError) as error:
        print("Not repaired:", error)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
