# Godot world-authoring plugin roadmap

Status: **initial primitive-authoring plugin implemented; broader roadmap pending**.
See [plugin usage and limits](../../addons/comunicare_world_tools/README.md).
Current verification: 34 service assertions pass plus a headless editor lifecycle
smoke. Actual isolated PC/VR launching, model import UI, undo/redo and geometry
optimization are not implemented. No performance guarantee is implied.

Test-first update: opt-in [acceptance contracts](../../tests/world_authoring/README.md)
now exist. Verified missing-plugin baseline: 0 passed, 6 failed, 6 dependent groups
blocked, exit 1 without engine errors. Proposed service/schema seams do not establish
editor UI, actual player-launch or hardware functionality.

## Goal

Provide a Godot 4.7 editor plugin that lets creators build, test and export a
Comunicare world without manually assembling entity IDs, script bindings or
interaction metadata. Include the production desktop/VR player integration, not
another movement implementation that behaves differently from the game.

Companion plan: [collaborative in-game editor](collaborative-map-editor-roadmap.md).
The two tools should share the same authoring document, validation, export pipeline
and entity/component definitions.

## Current baseline and limits

Verify these against production code when implementation begins:

- Packages use a manifest, reviewed scene/resource types and restricted
  `.worldscript` instructions. They do not execute downloaded GDScript.
- Static `.worldmesh` geometry is reconstructed from bounded data; direct arbitrary
  GLB/glTF scene import is not a supported runtime package feature.
- Reviewed materials/PNG textures and explicit primitive colliders are supported;
  editor-native plugins, arbitrary shaders and packed-scene graphs are not.
- Pickup leases and instance transitions have existing production owners. Do not
  replace them with ad-hoc Godot multiplayer authority or URL-only membership.
- Local progress and scoped checkpoint selection exist, but are client-local and
  not secure replicated gameplay. A checkpoint instruction is not a complete death
  or respawn gameplay system.
- Local package loading is offline; it does not distribute a filesystem path or
  make a package available to friends automatically.

References: [safe-world plan](safe-world-system-roadmap.md),
[models/gameplay guide](../guides/downloadable-world-models.md),
[local saves](../guides/world-local-saves.md), [local maps](../guides/local-maps.md).

## Creator workflow

1. Enable the locally installed editor plugin; choose **New Comunicare world**.
2. Enter title/description, create a stable world ID, and choose a template.
3. Place a spawn, import assets, and mark objects as scenery, pickup or interaction.
4. Add behavior from templates or a structured script editor; select targets from
   actual entity lists rather than entering resource paths manually.
5. Run **Validate**, then **Play desktop**, **Play VR** or **Play with two clients**.
6. Inspect issues and performance recommendations; preview proposed optimizations.
7. Export a validated package, test that exact export and optionally open it locally.

Keep common actions in one World dock. Show actionable diagnostics with a selected
node, reason and repair option. Advanced settings stay expandable. No silent fixes
that remove scripts, substitute materials or change collision behavior.

## Architecture and trust boundary

- `addons/comunicare_world_tools/`: proposed EditorPlugin, docks, gizmos and import
  adapters. This is **trusted creator-installed tooling**, not downloadable content.
- Shared authoring schema: stable entity UUIDs, components, transforms, asset
  references, behavior documents and provenance. Exact API names remain provisional.
- Shared compiler: authoring data → bounded runtime package. Resource dependencies
  are enumerated explicitly; exporter never zips the whole Godot project.
- Existing package reader/VM remain the final authority. Add new runtime capability
  support separately, with hostile-input tests, before exposing authoring controls.
- Pin compatible game/plugin/schema versions. Newer required features fail with
  diagnostics rather than generating packages older clients misinterpret.
- Native creator GDScript may be an editor-only convenience, but must never be
  advertised as portable behavior. Unsupported behavior blocks export; no arbitrary
  code fallback, runtime plugin download or hidden privileges.

## Milestones

### 01 — Shared authoring schema and plugin skeleton

- Add opt-in plugin installation and a World dock with new/open/save/validate.
- Define stable IDs, explicit asset references and schema migration policy.
- Keep source project files separate from derived export files. Save atomically;
  preserve unreadable/newer files, with explicit recovery rather than overwrite.
- Accept: clean Godot project can create/reopen a world; plugin disable leaves
  source intact; duplicate IDs, dangling paths and newer schema fail clearly.

### 02 — Production player preview and test launcher

- Templates include floor, spawn and optional interaction demonstration.
- Launch actual production client integration in an isolated test project/process;
  do not attach player internals or real account data to an editor scene.
- Desktop/VR selection, spawn and collision visualization, reset-to-spawn and
  visible tracking/runtime availability status. A player rig is preview-only and
  never exported as a world entity or autoload.
- Optional two-client loopback relay launch uses isolated temporary identities,
  muted capture and bounded cleanup. Additional windows do not reuse creator keys.
- Accept: same exported map loads on desktop and VR emulator, correct spawn and
  capsule clearance, menu suppression, world-switch recovery and no leaked test
  processes. Real OpenXR/headset testing is a distinct manual gate.

### 03 — Model/material import and collision tools

- Explicit asset import with bounds, triangle count, units, orientation and licensing
  review. Convert supported static models into the reviewed runtime representation.
- Preserve UV seams/normals and split material surfaces without guessing gameplay.
- Collider helpers for box/sphere/capsule/cylinder; separate visual and physics
  previews. Reject dynamic concave collision or unsupported geometry until reviewed.
- Accept: representative textured props round-trip through actual exported packages;
  oversized, malformed and external-resource inputs cannot bypass package limits.

### 04 — Pickup and interaction authoring

- **Make pickup** creates/selects a stable entity, approved physics body/collider,
  grip offsets and supported metadata. Validator highlights impossible grips,
  missing body shapes and duplicate IDs.
- **Make interactable** binds supported use/grab/release events; show hit/reach
  previews for desktop and both VR hands. Offer button, lever-like visual response,
  collectible and checkpoint templates only where the runtime can express them.
- Interaction manager lists all objects, scripts, references and validation state;
  supports rename, duplicate with fresh IDs and safe deletion/reference repair.
- Accept: two clients cannot hold the same object; drop/disconnect restores state;
  actions cannot target another world. Include undo/redo for every tool action.

### 05 — Easy behavior editor and correct binding

- Structured event/action blocks plus a JSON text view with schema completion.
- Templates: toggle visibility, give local XP, set a local unlock, conditional
  unlock display, select checkpoint. Clearly label local versus shared behavior.
- Target picker uses stable entity IDs and filters by compatible type. Rename/move
  retains bindings; deleting a target presents dependent actions before commit.
- Infer a proposed capability list and require creator review. No hidden capability
  escalation. VM fuel, event rate, data limits and save-write limits remain enforced.
- Inspect last event, failure, target resolution and progress in the isolated tester.
  Destructive reset of test progress requires confirmation and touches test data only.
- Accept: generated behavior executes in production runtime; invalid commands in
  either conditional branch block export; unavailable features never look usable.

### 06 — Safe automatic optimization

- First deliver a report: unique/repeated meshes, vertices, materials, texture memory,
  collider count, draw-call estimates and script/event workload. Separate estimates
  from measured CPU/GPU frame times on a named renderer/device.
- Offer reversible derived-output operations: texture resize/mipmap generation,
  exact duplicate-resource reuse, static batching/instancing where export supports
  it, approved collider simplification and optional mesh LOD generation.
- Never merge entities with independent scripts/grips, bake dynamic objects into
  scenery, discard provenance or change transparent/animated assets silently.
- Show before/after preview and budget changes. Preserve originals; use deterministic
  settings and an explicit quality preset. Unsupported runtime optimization is a
  recommendation, not an export feature.
- Accept: visual/collision comparisons, stable entity references and reproducible
  exports; record target-hardware frame-time distributions, not only average FPS.

### 07 — Packaging, diagnostics and release gates

- Export manifest, assets, restricted programs, provenance/credits and a report.
- Build to a staging file, run production validation, then replace final output.
- **Test exported package** exercises the exact bytes, not privileged editor nodes.
- No implicit uploads. Future publishing needs explicit destination and consent.
- Accept: local-file load, URL-hosted Create/Join, instance/world switches, imported
  static geometry, interaction lifecycle and progress persistence all pass.

## Test and delivery policy

Implement small independently verified parts; reproduce bug fixes first. Unit tests
cover schema/compiler/IDs/optimization. Disposable Godot editor integration tests
cover undo, dock actions and export. Headless tests do not certify visual quality,
native dialogs or hardware VR. Add rendered desktop tests, two-client checks and
manual headset comfort/controls gates. Never run automated tests against creator
accounts, keys, unreviewed external URLs or original project assets in-place.

Initial release scope: static models, supported materials/colliders, existing
restricted behaviors and isolated PC/VR playtesting. Arbitrary native scripting,
terrain plugins, shared combat and general-purpose visual programming are separate
reviewed extensions, not implied promises of this plugin.
