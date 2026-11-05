#!/usr/bin/env python3
"""Convert static OBJ triangles/polygons to bounded data-only .worldmesh JSON.

No materials, scripts or external files are loaded. Use reviewed world materials
and explicit primitive colliders in the package scene. UV/normal seams are split.
"""
import argparse
import json
import math
from pathlib import Path


def convert(text):
    positions, normals, uv = [], [], []
    vertices, out_normals, out_uv, indices = [], [], [], []
    mapped = {}

    def index(raw, values):
        value = int(raw)
        if value == 0 or not -len(values) <= value <= len(values):
            raise ValueError("OBJ index out of range")
        return value - 1 if value > 0 else len(values) + value

    for line in text.splitlines():
        fields = line.split("#", 1)[0].split()
        if not fields:
            continue
        if fields[0] in ("v", "vn", "vt"):
            count = 2 if fields[0] == "vt" else 3
            if len(fields) < count + 1:
                raise ValueError("Incomplete OBJ vector")
            vector = [float(x) for x in fields[1:count + 1]]
            if any(not math.isfinite(x) or abs(x) > 10000 for x in vector):
                raise ValueError("Nonfinite or oversized OBJ coordinate")
            {"v": positions, "vn": normals, "vt": uv}[fields[0]].append(vector)
        elif fields[0] == "f":
            if not 3 <= len(fields) - 1 <= 64:
                raise ValueError("Face must have 3..64 corners")
            face = []
            for corner in fields[1:]:
                parts = corner.split("/")
                if len(parts) > 3:
                    raise ValueError("Invalid OBJ corner")
                p = index(parts[0], positions)
                t = index(parts[1], uv) if len(parts) > 1 and parts[1] else None
                n = index(parts[2], normals) if len(parts) > 2 and parts[2] else None
                key = (p, t, n)
                if key not in mapped:
                    mapped[key] = len(vertices)
                    vertices.append(positions[p])
                    out_uv.append(uv[t] if t is not None else None)
                    out_normals.append(normals[n] if n is not None else None)
                face.append(mapped[key])
            for i in range(1, len(face) - 1):
                # OBJ is counterclockwise; Godot front faces are clockwise.
                indices.extend((face[0], face[i + 1], face[i]))
        if len(vertices) > 50000 or len(indices) > 150000:
            raise ValueError("Split this model: world mesh geometry budget exceeded")
    if not indices:
        raise ValueError("No faces")
    result = {"schema": 1, "vertices": vertices, "indices": indices}
    if all(v is not None for v in out_uv):
        result["uv"] = out_uv
    if all(v is not None for v in out_normals):
        result["normals"] = out_normals
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    if args.input.stat().st_size > 16 * 1024 * 1024:
        parser.error("OBJ exceeds 16 MiB authoring limit")
    result = json.dumps(convert(args.input.read_text()), separators=(",", ":"))
    if len(result.encode()) > 16 * 1024 * 1024:
        parser.error("Output exceeds 16 MiB")
    args.output.write_text(result)


if __name__ == "__main__":
    main()
