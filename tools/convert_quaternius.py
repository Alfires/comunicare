#!/usr/bin/env python3
"""Extract authored CC0 rotations; no generated/synthesized motion keys.

Usage: python3 tools/convert_quaternius.py /path/to/Universal_Animation_LibraryStandard.zip
Source: https://store.godotengine.org/asset/quaternius/universal-animation-library/download/44/
"""
import hashlib
import json
from pathlib import Path
import struct
import sys
import zipfile
import math

ROOT = Path(__file__).resolve().parents[1]
MEMBER = "Animation Library[Standard]/Godot/AnimationLibrary_Godot_Standard.glb"
SELECTION = {"walk": "Walk_Loop", "run": "Jog_Fwd_Loop", "strafe_left": "Walk_Loop", "strafe_right": "Walk_Loop",
             "jump": "Jump_Start", "fall": "Jump_Loop",
             "dance": "Dance_Loop", "interact": "Interact"}
MAPPING = {"DEF-hips": "hips", "DEF-spine.001": "spine", "DEF-spine.002": "chest",
           "DEF-spine.003": "upperChest", "DEF-neck": "neck", "DEF-head": "head"}
for suffix, side in [("L", "left"), ("R", "right")]:
    for source, target in {"shoulder": "Shoulder", "upper_arm": "UpperArm", "forearm": "LowerArm",
                           "hand": "Hand", "thigh": "UpperLeg", "shin": "LowerLeg",
                           "foot": "Foot", "toe": "Toes"}.items():
        MAPPING[f"DEF-{source}.{suffix}"] = side + target
    for source, finger in [("f_index", "Index"), ("f_middle", "Middle"), ("f_ring", "Ring"), ("f_pinky", "Little"), ("thumb", "Thumb")]:
        parts = ["Metacarpal", "Proximal", "Distal"] if finger == "Thumb" else ["Proximal", "Intermediate", "Distal"]
        for i, part in enumerate(parts, 1):
            MAPPING[f"DEF-{source}.{i:02}.{suffix}"] = side + finger + part


def mul(a, b):
    x, y, z, w = a
    X, Y, Z, W = b
    return [w*X+x*W+y*Z-z*Y, w*Y-x*Z+y*W+z*X, w*Z+x*Y-y*X+z*W, w*W-x*X-y*Y-z*Z]


def inv(q):
    return [-q[0], -q[1], -q[2], q[3]]


def norm(q):
    length = math.sqrt(sum(v*v for v in q))
    return [v/length for v in q]


def main():
    archive = Path(sys.argv[1]).read_bytes()
    with zipfile.ZipFile(sys.argv[1]) as bundle:
        data = bundle.read(MEMBER)
        license_text = bundle.read("Animation Library[Standard]/License.txt")
    json_size = struct.unpack_from("<I", data, 12)[0]
    doc = json.loads(data[20:20+json_size])
    binary = data[28+json_size:]

    def accessor(index):
        item = doc["accessors"][index]
        view = doc["bufferViews"][item["bufferView"]]
        assert item["componentType"] == 5126
        width = {"SCALAR": 1, "VEC4": 4}[item["type"]]
        start = view.get("byteOffset", 0) + item.get("byteOffset", 0)
        stride = view.get("byteStride", width*4)
        return [list(struct.unpack_from("<"+"f"*width, binary, start+i*stride)) for i in range(item["count"])]

    animations = {a["name"]: a for a in doc["animations"]}

    def channels(animation):
        result = {}
        for channel in animation["channels"]:
            if channel["target"]["path"] != "rotation":
                continue  # Explicitly omit translations/scales; in-place only.
            sampler = animation["samplers"][channel["sampler"]]
            assert sampler.get("interpolation", "LINEAR") == "LINEAR"
            result[channel["target"]["node"]] = (accessor(sampler["input"]), accessor(sampler["output"]))
        return result

    reference = channels(animations["A_TPose"])
    parents = {child: i for i, node in enumerate(doc["nodes"]) for child in node.get("children", [])}

    def global_reference(index):
        q = norm(reference[index][1][0]) if index in reference else doc["nodes"][index].get("rotation", [0, 0, 0, 1])
        return norm(mul(global_reference(parents[index]), q)) if index in parents else norm(q)

    clips = {}
    for role, name in SELECTION.items():
        tracks = []
        duration = 0
        for index, (times, values) in channels(animations[name]).items():
            node_name = doc["nodes"][index].get("name", "")
            if node_name not in MAPPING:
                continue
            rest = norm(reference[index][1][0])
            duration = max(duration, times[-1][0])
            basis = global_reference(index)
            if role in ["strafe_left", "strafe_right"]:
                angle = math.pi / 2 if role == "strafe_left" else -math.pi / 2
                basis = mul([0, math.sin(angle/2), 0, math.cos(angle/2)], basis)
            tracks.append({"bone": MAPPING[node_name], "source_rest": basis, "reference_space": "gltf_humanoid",
                           "keys": [[t[0], *norm(mul(inv(rest), norm(q)))] for t, q in zip(times, values)]})
        clips[role] = {"name": role, "source_clip": name, "duration": duration, "tracks": tracks,
                       "provenance": {"author": "Quaternius", "license": "CC0-1.0"}}
    out = ROOT / "assets/animations"
    payload = json.dumps({"schema": 1, "clips": clips}, separators=(",", ":")) + "\n"
    (out / "quaternius_standard.json").write_text(payload)
    (out / "Quaternius-License.txt").write_text("\n".join(line.rstrip() for line in license_text.decode().splitlines()) + "\n")
    manifest = {"schema": 2, "library": "quaternius.standard.v1", "author": "Quaternius", "license": "CC0-1.0",
                "source_url": "https://store.godotengine.org/asset/quaternius/universal-animation-library/",
                "download_url": "https://store.godotengine.org/asset/quaternius/universal-animation-library/download/44/",
                "download_version": "Standard-1.0", "retrieved": "2026-11-03", "archive_sha256": hashlib.sha256(archive).hexdigest(),
                "original_file": MEMBER, "original_sha256": hashlib.sha256(data).hexdigest(),
                "converted_sha256": hashlib.sha256(payload.encode()).hexdigest(), "clips": SELECTION,
                "conversion": "Authored rotation keys extracted without synthesis; A_TPose deltas/global bases preserved; translation/scale omitted. Left/right strafe variants reorient Walk_Loop reference bases by +/-90 degrees; these are adapted walks, not dedicated authored strafes. Idle/landing clips excluded. Fingers retained; optional bones may be skipped."}
    (out / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    print({role: (clip["duration"], len(clip["tracks"])) for role, clip in clips.items()})


if __name__ == "__main__":
    main()
