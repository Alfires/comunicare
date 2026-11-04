# Safe world authoring — initial implementation

Create and edit a normal Godot 4.7 project. There is no custom world editor or
required publishing plugin. The current runtime supports a **limited initial
profile**, not every feature listed in the [roadmap](../roadmaps/safe-world-system-roadmap.md).

## Manual package

1. Save your scene as text `.tscn`, built-in materials as `.tres`, and textures as PNG.
2. Create a staging folder with the same scene/resource paths as the project.
3. Add `manifest.json` at its root:

```json
{
  "format": "comunicare.world",
  "schema_version": 1,
  "world_id": "a-stable-unique-world-id",
  "release": "1.0.0",
  "requires": {"world_api": 1, "script_api": 1},
  "main_scene": "scenes/world.tscn",
  "script_capabilities": []
}
```

4. Copy all referenced scene/material/PNG dependencies into staging. Do not include
   `project.godot`, `.godot`, `.git`, GDScript, plugins, native libraries or shaders.
5. ZIP the folder's **contents**, preserving paths. Stored and deflated ZIP32 are
   supported. Upload the ZIP or `.cworld` file through your existing web host.
6. Reopen the original project in Godot to edit; repack and upload a new revision.
   Active instances stay pinned to old bytes. Keep old archives available for them.

Built-in source examples are currently the scene/material fixtures in
[`tests/world_system`](../../tests/world_system/README.md); a complete author
template project and safe offline preview UI remain follow-up work.

## Current profile and security boundary

- Nodes: Node, Node3D, Marker3D, MeshInstance3D, StaticBody3D, RigidBody3D,
  CollisionShape3D, Area3D and directional/omni/spot lights, with reviewed properties.
- Geometry: built-in box/sphere/cylinder/plane/capsule meshes and reviewed primitive
  collision shapes. Imported models, nested scenes/inheritance, environments,
  animations and world UI are not supported yet; validation rejects them explicitly.
- StandardMaterial3D/ORMMaterial3D resources, PNG texture maps and basic PBR/UV
  settings. The initial exercised channels are albedo, normal, metallic, roughness,
  AO and emission. JPEG/WebP/HDR/EXR, lightmaps and complete texture parity are still
  pending. No downloaded custom shader programs.
- In Godot's node metadata, `world_entity_id` is a stable string ID;
  `world_pickup` and `world_spawn` are booleans. A spawn marker supplies the initial
  player position. Pickup metadata is preserved, but network/player interaction
  wiring is separate from package loading.
- Files are never extracted or mounted as engine resources. Static parsing rejects
  scripts, executable sections/connections, unsupported types and missing references.
  Strict limits cover ZIP sizes, decoder output/work, parsed depth and textures.
- The old `cache.trust_remote_worlds` preference is retained for configuration
  compatibility only; it cannot enable unsafe loading. The client still needs a
  hostile-content review and native media decoder isolation work before any strong
  security assurance. Do not open strangers' projects in Godot to validate them.
- Terrain3D requirements can be validated, but **no Terrain3D adapter is installed**.
  Such worlds currently fail staging. Authors can use addon tools locally and
  convert supported results, but actual terrain baking/integration remains pending.
- Restricted instruction VM, item leases, ordered snapshots and moderation policies
  have isolated service tests. They are not automatically active gameplay features
  merely because those services exist.

Verification: `python3 tests/world_system/run.py`, its Python runner self-tests,
and `python3 tests/public_discovery/run.py` (real DataLoader staging/activation).
Headless results do not prove visual parity, hardware comfort or absence of exploits.
