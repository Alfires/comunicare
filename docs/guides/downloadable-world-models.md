# Static models and bounded gameplay in downloadable worlds

Downloaded packages still cannot execute GDScript, load native plugins, register
autoloads, or instantiate arbitrary engine resources. This extension adds useful
static geometry and scoped checkpoint selection, not an unrestricted game engine.

## Models

Export static models as OBJ from Blender or another authoring tool, then run:

```sh
python3 tools/worlds/obj_to_worldmesh.py tree.obj tree.worldmesh
```

Place the result in the package (for example `models/tree.worldmesh`) and reference
it from a reviewed `MeshInstance3D`:

```ini
[ext_resource type="ArrayMesh" path="res://models/tree.worldmesh" id="tree"]

[node name="Tree" type="MeshInstance3D" parent="."]
mesh = ExtResource("tree")
```

Use `material_override` with the existing reviewed StandardMaterial3D/ORMMaterial3D
and PNG texture path. Split multi-material models into separate mesh nodes. Use
explicit Box/Sphere/Capsule/Cylinder collision shapes: no automatic triangle-mesh
physics cooking is enabled. This keeps visual detail separate from bounded physics.

The data-only schema contains `schema: 1`, `vertices`, triangle `indices`, optional
`normals` and `uv`. No URLs, scripts or engine object serialization. Limits: 50,000
vertices and 150,000 indices per mesh; 200,000 vertices and 600,000 indices across
the package; 16 MiB per mesh file; finite coordinates within ±10,000. Existing ZIP,
texture and scene limits still apply. OBJ polygon conversion uses fan triangulation;
triangulate concave polygons in your authoring application first.

Direct GLB/glTF, external BIN/JPEG imports, skins, model animations, terrain plugins,
custom shaders and arbitrary packed-scene instances remain unsupported. Convert
static geometry first rather than enabling an unsafe generic ResourceLoader path.

## Gameplay

Restricted scripts support visual interactions and
[local levels/XP/progress](world-local-saves.md). Both `if_saved` branches are
validated, even when one is not selected by the current progress.

Declare `player.checkpoint` to select a current-world Marker3D:

```json
{"op": "checkpoint", "entity": "checkpoint-2"}
```

The marker must have that `metadata/world_entity_id`. The trusted runtime exposes
`respawn_local_player(player)` to client-owned death/reset handling; downloaded
scripts cannot directly teleport a player, select external nodes or move another
user. Checkpoint selection resets with each world runtime. Persistence can record
a checkpoint identifier and select it on `start` using `if_saved`.

These actions are client-local, not authoritative replicated game logic. Networked
combat, inventories, shared quests, automatic death volumes and secure scores need
additional reviewed protocols and are not implemented by this extension.
