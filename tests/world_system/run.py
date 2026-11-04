#!/usr/bin/env python3
"""Opt-in RED world contracts, isolated from accounts, networking and game startup."""

import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import struct
import tempfile
import warnings
import zipfile
import zlib

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
EXAMPLE = ROOT / "examples/simple_world"


def package_example(destination):
    """ZIP the checked-in author project, never a separately invented fixture."""
    sources = [EXAMPLE / "manifest.json"]
    for folder in ("scenes", "materials", "textures", "logic"):
        sources.extend(path for path in sorted((EXAMPLE / folder).rglob("*"))
                       if path.is_file() and path.suffix not in (".uid", ".import"))
    with zipfile.ZipFile(destination, "w", zipfile.ZIP_DEFLATED) as archive:
        for path in sources:
            archive.write(path, path.relative_to(EXAMPLE).as_posix())


def write_packages(destination):
    """Generate real manual ZIP inputs, including deliberately hostile archives."""
    destination.mkdir(parents=True, exist_ok=True)
    metadata = {
        "format": "comunicare.world", "schema_version": 1,
        "world_id": "4aa3a976-15cf-4d85-bd41-5677a12abcde", "release": "1.0.0",
        "requires": {"world_api": 1, "script_api": 1},
        "main_scene": "scenes/world.tscn", "script_capabilities": [],
    }
    scene = (HERE / "fixtures/world.tscn").read_text()
    material = (HERE / "fixtures/surface.tres").read_text()
    def chunk(kind, payload):
        return struct.pack(">I", len(payload)) + kind + payload + struct.pack(">I", zlib.crc32(kind + payload))

    # Real valid RGBA PNG; do not let a corrupt fixture make success impossible.
    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", 1, 1, 8, 6, 0, 0, 0)) + chunk(b"IDAT", zlib.compress(b"\x00\xff\xff\xff\xff")) + chunk(b"IEND", b"")
    common = {
        "manifest.json": json.dumps(metadata), "scenes/world.tscn": scene,
        "materials/surface.tres": material, "textures/pixel.png": png,
    }

    def archive(name, overrides=None, remove=(), manifest=None, extra=()):
        entries = dict(common)
        if manifest is not None:
            entries["manifest.json"] = json.dumps(manifest)
        entries.update(overrides or {})
        for key in remove:
            entries.pop(key, None)
        with zipfile.ZipFile(destination / (name + ".zip"), "w", zipfile.ZIP_DEFLATED) as output:
            for key, value in [*entries.items(), *extra]:
                output.writestr(key, value)

    archive("valid")
    binding = scene.replace('metadata/world_entity_id = "item"', 'metadata/world_entity_id = "item"\nmetadata/world_script = "logic/item.worldscript"')
    program = {"version": 1, "events": {"start": [{"op": "command", "capability": "entity.visual", "entity": "item", "property": "visible", "value": False}], "use": [{"op": "command", "capability": "entity.visual", "entity": "item", "property": "visible", "value": True}]}}
    script_metadata = {**metadata, "script_capabilities": ["entity.visual"]}
    archive("scripted", {"scenes/world.tscn": binding, "logic/item.worldscript": json.dumps(program)}, manifest=script_metadata)
    bad_program = {"version": 1, "events": {"start": [{"op": "command", "capability": "os.execute", "entity": "item", "property": "visible", "value": False}]}}
    archive("script_forbidden", {"scenes/world.tscn": binding, "logic/item.worldscript": json.dumps(bad_program)}, manifest=script_metadata)
    archive("script_missing", {"scenes/world.tscn": binding}, manifest=script_metadata)
    archive("traversal", {"../escape.txt": "not allowed"})
    archive("absolute", {"/outside.txt": "not allowed"})
    archive("backslash", {"textures\\escape.png": png})
    archive("case_collision", {"Textures/PIXEL.png": png})
    with warnings.catch_warnings():
        warnings.simplefilter("ignore", UserWarning)
        archive("duplicate_entry", extra=[("textures/pixel.png", png)])
    archive("missing_texture", remove=("textures/pixel.png",))
    archive("unsupported_schema", manifest={**metadata, "schema_version": 999})
    archive("duplicate_keys", {"manifest.json": '{"format":"comunicare.world","schema_version":1,"schema_version":999}'})
    archive("nonfinite", {"scenes/world.tscn": scene.replace("Vector3(0, 0, 0)", "Vector3(nan, 0, 0)")})
    archive("unknown_node", {"scenes/world.tscn": scene.replace('type="Node3D"', 'type="UnreviewedCustomNode"', 1)})
    archive("wrong_property_type", {"scenes/world.tscn": scene.replace("Vector3(0, 0, 0)", '"not a vector"')})
    archive("bad_constructor", {"scenes/world.tscn": scene.replace("Vector3(0, 0, 0)", "Vector3(0)")})
    archive("resource_cycle", {"scenes/world.tscn": scene.replace('material = ExtResource("1")', 'material = SubResource("Box")')})
    archive("huge_mesh", {"scenes/world.tscn": scene.replace('[sub_resource type="BoxMesh" id="Box"]', '[sub_resource type="BoxMesh" id="Box"]\nsubdivide_width = 999999')})
    archive("bad_texture", {"textures/pixel.png": png[:33]})
    archive("missing_instance", {"scenes/world.tscn": scene.replace('path="res://materials/surface.tres"', 'path="res://missing.tres"')})
    archive("external_texture", {"materials/surface.tres": material.replace('res://textures/pixel.png', 'https://example.invalid/steal.png')})
    archive("shader", {"evil.gdshader": "shader_type spatial; void fragment() { ALBEDO = vec3(1.0); }"})
    # If any production loader executes this tool script, the suite detects its
    # side effect. It is never loaded/imported as code by the runner itself.
    attack = '@tool\nextends Node3D\nfunc _init():\n\tvar f = FileAccess.open("user://WORLD_SCRIPT_EXECUTED", FileAccess.WRITE)\n\tf.store_string("unsafe")\n'
    scripted = scene.replace('[gd_scene load_steps=4 format=3]', '[gd_scene load_steps=5 format=3]\n[ext_resource type="Script" path="res://evil.gd" id="9"]')
    scripted = scripted.replace('metadata/world_entity_id = "world-root"', 'script = ExtResource("9")\nmetadata/world_entity_id = "world-root"')
    archive("attached_script", {"scenes/world.tscn": scripted, "evil.gd": attack})
    archive("method_track", {"scenes/unsafe.tscn": (HERE / "fixtures/method_track.tscn").read_text()})
    archive("signal_method", {"scenes/world.tscn": scene + '\n[connection signal="ready" from="." to="." method="queue_free"]\n'})
    archive("native_extension", {"addons/evil/evil.gdextension": '[configuration]\nentry_symbol="evil_init"\n'})
    archive("project_autoload", {"project.godot": 'config_version=5\n[autoload]\nEvil="*res://evil.gd"\n', "evil.gd": attack})
    archive("expanded_limit", {"padding.txt": "x" * (1024 * 1024)})
    # Forge small directory/local lengths while leaving the larger compressed
    # payload intact; limits must cap actual output, not just trust metadata.
    archive("forged_deflate", {"padding.txt": "x" * (128 * 1024)})
    forged = bytearray((destination / "forged_deflate.zip").read_bytes())
    position = 0
    while position < len(forged) - 46:
        if forged[position:position + 4] == b"PK\x01\x02":
            length = struct.unpack_from("<H", forged, position + 28)[0]
            if forged[position + 46:position + 46 + length] == b"padding.txt":
                struct.pack_into("<I", forged, position + 24, 16)
                local = struct.unpack_from("<I", forged, position + 42)[0]
                struct.pack_into("<I", forged, local + 22, 16)
                break
        position += 1
    (destination / "forged_deflate.zip").write_bytes(forged)
    archive("broken_deflate")
    broken = bytearray((destination / "broken_deflate.zip").read_bytes())
    first_data = 30 + struct.unpack_from("<H", broken, 26)[0] + struct.unpack_from("<H", broken, 28)[0]
    broken[first_data] = 0x07  # reserved block type
    (destination / "broken_deflate.zip").write_bytes(broken)
    archive("texture_dimensions", {"textures/pixel.png": png})  # tested with max_texture_dimension=0
    terrain = {**metadata, "extensions": [{"id": "comunicare.terrain3d", "data_schema": 1, "required": True, "data": "terrain/index.json"}]}
    archive("terrain_required", {"terrain/index.json": '{"regions":[]}'}, manifest=terrain)
    archive("terrain_missing_data", manifest=terrain)
    archive("terrain_code_url", {"terrain/index.json": '{"regions":[]}'}, manifest={**terrain, "extensions": [{**terrain["extensions"][0], "library_url": "https://example.invalid/evil.so"}]})
    with zipfile.ZipFile(destination / "symlink.zip", "w") as output:
        for key, value in common.items():
            output.writestr(key, value)
        info = zipfile.ZipInfo("textures/link")
        info.create_system = 3
        info.external_attr = 0o120777 << 16
        output.writestr(info, "../../outside")
    (destination / "truncated.zip").write_bytes((destination / "valid.zip").read_bytes()[:40])
    return hashlib.sha256((destination / "valid.zip").read_bytes()).hexdigest()


def result_code(process):
    if "ERROR:" in process.stdout + process.stderr or process.returncode not in (0, 1):
        return 2
    return process.returncode


def main():
    godot = shutil.which(os.environ.get("GODOT", "godot"))
    if not godot:
        print("Infrastructure failure: Godot is required; set GODOT to its executable.")
        return 2
    temp_root = Path("/tmp/opencode")
    try:
        with tempfile.TemporaryDirectory(prefix="comunicare-world-red-", dir=temp_root if temp_root.is_dir() else None) as directory:
            project = Path(directory)
            # Proposed pure world services only. No startup, real autoloads,
            # downloaded addons, user account data or XR/physical capture.
            source = ROOT / "scripts/worlds"
            if source.is_dir():
                shutil.copytree(source, project / "scripts/worlds", ignore=shutil.ignore_patterns("__pycache__"))
            shutil.copy2(HERE / "suite.gd", project / "suite.gd")
            shutil.copy2(HERE / "example_suite.gd", project / "example_suite.gd")
            (project / "project.godot").write_text(
                'config_version=5\n[application]\nconfig/name="Isolated RED world contracts"\n'
                '[rendering]\nrenderer/rendering_method="gl_compatibility"\n'
            )
            # Import trusted production scripts first. Hostile fixtures stay out
            # of the editor import scan, and are generated only afterward.
            isolated_env = {**os.environ, "XDG_DATA_HOME": str(project / "isolated-data"), "XDG_CONFIG_HOME": str(project / "isolated-config"), "XDG_CACHE_HOME": str(project / "isolated-cache")}
            # Verify the author's actual source project with Godot too, but never
            # import it in-place or mix it into the consumer's resource namespace.
            author = project / "author"
            shutil.copytree(EXAMPLE, author, ignore=shutil.ignore_patterns(".godot", "*.uid", "*.import"))
            (author / "native_check.gd").write_text(
                'extends SceneTree\nfunc _initialize():\n'
                '\tvar scene = load("res://scenes/world.tscn").instantiate()\n'
                '\tvar material = scene.get_node("PickupCube/Mesh").mesh.material\n'
                '\tvar valid = material.albedo_texture != null\n'
                '\tscene.free()\n'
                '\tprint("Native example scene/texture: ", "PASS" if valid else "FAIL")\n'
                '\tquit(0 if valid else 1)\n'
            )
            for arguments in (["--editor", "--import"], ["--script", "res://native_check.gd"]):
                native = subprocess.run([godot, "--headless", "--path", str(author), *arguments],
                                        capture_output=True, text=True, timeout=90, env=isolated_env)
                if native.returncode or "ERROR:" in native.stdout + native.stderr:
                    print(native.stdout + native.stderr)
                    return 2
                if "--script" in arguments:
                    print(native.stdout, end="")
            imported = subprocess.run([godot, "--headless", "--path", directory, "--editor", "--import"], capture_output=True, text=True, timeout=90, env=isolated_env)
            if imported.returncode or "ERROR:" in imported.stdout + imported.stderr:
                print(imported.stdout + imported.stderr)
                return 2
            packages = project / "packages"
            packages.mkdir()
            (packages / ".gdignore").write_text("")
            revision = write_packages(packages)
            (packages / "expected_revision.txt").write_text(revision)
            package_example(packages / "simple-world.cworld")
            result = subprocess.run([godot, "--headless", "--path", directory, "--script", "res://suite.gd"], capture_output=True, text=True, timeout=60,
                                    env=isolated_env)
            print(result.stdout, end="")
            print(result.stderr, end="")
            status = result_code(result)
            if status: return status
            example = subprocess.run([godot, "--headless", "--path", directory, "--script", "res://example_suite.gd"],
                                     capture_output=True, text=True, timeout=60, env=isolated_env)
            print(example.stdout, end="")
            print(example.stderr, end="")
            return result_code(example)
    except (OSError, subprocess.TimeoutExpired) as error:
        print(f"Infrastructure failure: {error}")
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
