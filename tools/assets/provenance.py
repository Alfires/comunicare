#!/usr/bin/env python3
"""Offline welcome-island asset inventory validation and deterministic notices."""
import argparse
from datetime import date
import hashlib
import json
from pathlib import Path
import re
from urllib.parse import urlsplit

ROOT = Path(__file__).resolve().parents[2]
MANIFEST = "assets/welcome_island/manifest.json"
START = "<!-- welcome-island-assets:start -->"
END = "<!-- welcome-island-assets:end -->"


def https(value):
    if not isinstance(value, str):
        return False
    parsed = urlsplit(value)
    return parsed.scheme == "https" and bool(parsed.hostname) and not parsed.username and not parsed.password


def local(root, value):
    if not isinstance(value, str) or not value or "\\" in value:
        return None
    path = Path(value)
    if path.is_absolute() or ".." in path.parts or ":" in value:
        return None
    result = (root / path).resolve()
    return result if result.is_relative_to(root.resolve()) and result.is_file() else None


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def render_inventory(data):
    lines = [START, "## Welcome island asset inventory", "",
             "Generated from `assets/welcome_island/manifest.json`; candidates not bundled are excluded.", ""]
    for asset in data.get("assets", []):
        if not isinstance(asset, dict):
            continue
        lines += [f"### {asset.get('id', '')} — {asset.get('title', '')}", "",
                  f"- Author: {asset.get('author', '')}",
                  f"- Source: {asset.get('source', '')}",
                  f"- License: {asset.get('license', '')}; terms: `{asset.get('license_file', '')}`",
                  f"- Retrieved: {asset.get('retrieved', '')}",
                  f"- Attribution: {asset.get('attribution', '') or 'Not required (CC0); voluntary acknowledgement above.'}",
                  f"- Modifications: {asset.get('modifications', '')}"]
        files = asset.get("files", [])
        for item in files if isinstance(files, list) else []:
            if isinstance(item, dict):
                lines += [f"- Shipped: `{item.get('path', '')}`; SHA-256 `{item.get('sha256', '')}`",
                          f"  Original: `{item.get('original_name', '')}`; SHA-256 `{item.get('original_sha256', '')}`; download: {item.get('download', '')}"]
        lines.append("")
    return "\n".join([*lines, END])


def validate(data, root, document):
    errors = []
    if not isinstance(data, dict) or data.get("version") != 1 or not isinstance(data.get("assets"), list) or not data["assets"]:
        return ["manifest: expected version 1 with nonempty assets list"]
    ids, paths = set(), set()
    for asset in data["assets"]:
        if not isinstance(asset, dict):
            errors.append("asset: expected object")
            continue
        label = str(asset.get("id", "<missing>"))
        for key in ("id", "title", "author", "source", "license", "license_file", "license_sha256", "retrieved", "modifications"):
            if not isinstance(asset.get(key), str) or not asset[key].strip():
                errors.append(f"{label}: missing {key}")
        if label in ids or not re.fullmatch(r"[a-z0-9][a-z0-9._-]*", label):
            errors.append(f"{label}: duplicate/invalid id")
        ids.add(label)
        if not https(asset.get("source")):
            errors.append(f"{label}: source must be HTTPS")
        try:
            date.fromisoformat(asset.get("retrieved", ""))
        except (ValueError, TypeError):
            errors.append(f"{label}: invalid retrieval date")
        license_id = asset.get("license")
        if license_id not in ("CC0-1.0", "CC-BY-4.0"):
            errors.append(f"{label}: unapproved license")
        if license_id == "CC-BY-4.0" and not str(asset.get("attribution", "")).strip():
            errors.append(f"{label}: CC BY attribution required")
        terms = local(root, asset.get("license_file"))
        if terms is None or digest(terms) != asset.get("license_sha256"):
            errors.append(f"{label}: missing/changed license terms")
        files = asset.get("files")
        if not isinstance(files, list) or not files:
            errors.append(f"{label}: nonempty files required")
            continue
        for item in files:
            if not isinstance(item, dict):
                errors.append(f"{label}: invalid file record")
                continue
            path = item.get("path")
            found = local(root, path)
            if found is None or digest(found) != item.get("sha256"):
                errors.append(f"{label}: missing/changed/unsafe file {path}")
            if isinstance(path, str):
                if path in paths:
                    errors.append(f"{label}: duplicate file {path}")
                paths.add(path)
            for key in ("sha256", "original_sha256"):
                if not isinstance(item.get(key), str) or not re.fullmatch(r"[0-9a-f]{64}", item[key]):
                    errors.append(f"{label}: invalid {key}")
            if str(asset.get("modifications", "")).lower().startswith("unmodified") and item.get("sha256") != item.get("original_sha256"):
                errors.append(f"{label}: unmodified file must match original hash")
            name = item.get("original_name")
            if not isinstance(name, str) or not name.strip() or "." not in name or ".." in Path(name).parts:
                errors.append(f"{label}: invalid original filename")
            if not https(item.get("download")):
                errors.append(f"{label}: invalid download URL")
    for folder in ("models", "textures", "sky"):
        for path in (root / "assets/welcome_island" / folder).rglob("*"):
            if path.is_file() and path.suffix not in (".import", ".uid") and path.relative_to(root).as_posix() not in paths:
                errors.append(f"unlisted payload: {path.relative_to(root)}")
    if render_inventory(data) not in document:
        errors.append("THIRD_PARTY_ASSETS.md: inventory drift")
    return errors


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--write-doc", action="store_true", help="Update only the marked inventory block")
    args = parser.parse_args()
    try:
        data = json.loads((ROOT / MANIFEST).read_text())
        path = ROOT / "THIRD_PARTY_ASSETS.md"
        document = path.read_text()
        if args.write_doc:
            block = render_inventory(data)
            if START in document and END in document:
                document = document[:document.index(START)] + block + document[document.index(END) + len(END):]
            else:
                document = document.rstrip() + "\n\n" + block + "\n"
            # Never publish a regenerated inventory for invalid assets.
            errors = validate(data, ROOT, document)
            if not errors:
                path.write_text(document)
        else:
            errors = validate(data, ROOT, document)
        for error in errors:
            print(error)
        if not errors:
            print(f"Asset provenance: {len(data['assets'])} entries validated offline")
        return 1 if errors else 0
    except (OSError, ValueError, TypeError) as error:
        print(f"Asset provenance infrastructure failure: {error}")
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
