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

An editable [Simple Pickup Courtyard Godot project](../../examples/simple_world/README.md)
is included with a textured floor, spawn, pickup cube, lighting and restricted
beacon script. Its README explains manual packaging, and the world runner tests
its actual source files. A player-facing safe offline preview UI remains follow-up work.

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
  player position. Pickup metadata opts a Node3D prop into initial shared carrying.
  Desktop **E** picks up/drops a nearby prop (rebind under Controls); VR grip holds
  a nearby prop until release. Both clients and relay need item protocol version 1.
  Held poses are replicated only inside the exact instance/pinned revision.
  Initial carrying disables held rigidbody collision to prevent player pushing;
  swept collision, grip offsets, throws, two-hand interaction and handoff remain
  pending. Free/drop physics is local, not a fully synchronized physics simulation.
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
- Restricted visual world scripts now run on activation with an Assets setting to
  stop callbacks immediately; this is not unrestricted GDScript or synchronized
  gameplay scripting. Item leases and held poses now have relay/player wiring and
  loopback/scene-object tests. Kick/ban-only role policy remains an isolated service;
  the existing live Active Instance extra-management UI has not yet been narrowed.

## Restricted visual scripts

Add string node metadata `world_script = "logic/item.worldscript"` to a node with
`world_entity_id = "item"`; include that file in the ZIP and grant `entity.visual`
in manifest `script_capabilities`. The initial `.worldscript` text format is JSON:

```json
{
  "version": 1,
  "events": {
    "start": [
      {"op": "command", "capability": "entity.visual", "entity": "item", "property": "visible", "value": false}
    ]
  }
}
```

Start and capped 20 Hz tick callbacks run locally; use/grab/release dispatch is
available to trusted runtime callers but not yet connected to player controls.
Only visibility commands are currently implemented. Data loops and command counts
are metered; no OS/files/network/engine calls, dynamic evaluation or node objects
are available. Disable **Run restricted world visual scripts** in Assets to stop
callbacks; enabling again takes effect on the next load. This initial declarative
format is not the full planned typed scripting language, and local callbacks must
not be used as authoritative shared game state.

Verification: `python3 tests/world_system/run.py`, its Python runner self-tests,
and `python3 tests/public_discovery/run.py` (real DataLoader staging/activation).
Headless results do not prove visual parity, hardware comfort or absence of exploits.
