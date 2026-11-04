# Safe, editable worlds and shared interaction roadmap

**Status: proposal, 2026-11-04. No runtime implementation or security certification.**
**Authoring clarification:** worlds are ordinary Godot projects, edited in Godot
with its built-in nodes, scene instances, resources, materials and texture tools.
Add a metadata file and manually package the world; no custom editor or mandatory
publishing plugin. This supersedes the initial custom-editor/JSON-source proposal.
This is the target design for replacing downloaded executable Godot worlds. It
does not make today's loader safe. The current behavior remains documented in
[worlds and instances](../guides/worlds-settings-and-voice.md).

## 1. Product contract and explicit interpretation

- Anyone can create a normal Godot project and build, save and update the world in
  the Godot editor, with full standard-material texture support and a documented
  safe profile of built-in nodes/resources. Publication is manual for now.
  Optional scripts still run on players' devices, but only inside a restricted
  world-language interpreter, never as downloaded GDScript or native code.
- Desktop and VR users can pick up, use, carry, pass and throw the same items.
  Other participants see the object attached to the correct player's hand/grip.
- No new gameplay server, player-host process or owner-operated simulation is
  required. Keep the existing authenticated relay and URL/catalog downloads.
  The relay necessarily remains a server in the networking sense; removing it
  too would contradict preserving delivery/current multiplayer architecture.
- An instance creator has no special gameplay powers. Admins have only explicit
  **kick and instance-ban** actions. No spawn console, script upload, item override,
  forced update, hidden inspection, arbitrary role promotion or world editing power.
  If the last admin leaves, a remaining player automatically becomes admin.
- World authorship, local draft editing, instance moderation and temporary item
  control are independent permissions. None implies the others.
- World files remain downloadable from existing ordinary URLs; no publishing
  account service, world database, new catalog service or upload backend is needed.
- A URL identifies content; `session_id` identifies one instance. Preserve
  `default_wold`, explicit packet IDs, admission and acknowledged transitions.

**Security boundary:** aim to prevent world content from accessing the OS, account,
files or unrestricted engine APIs. Do not promise that any complex client can be
impossible to exploit. Parser/engine defects, modified clients, denial of service
and social deception remain risks; limits, testing and security review are gates.
Without a trusted gameplay authority, perfect anti-cheat and agreement among
malicious peers are not achievable. Safety must not depend on peer honesty.

## 2. Inspected baseline, not assumptions

| Existing code | Consequence for the rewrite |
| --- | --- |
| `scripts/startup/data_loader.gd`: ZIP → `manifest.json` → `main_scene` → `ResourceLoader.load()` → `PackedScene` | Arbitrary downloaded Godot resource graphs are an execution boundary, not a safe document format. Replace this path for remote worlds. |
| Same loader: archive path checks, entry/expanded-size limits, trusted-world setting | Useful defenses but not a scripting sandbox; some limits run after decompression/allocation. |
| Same loader and asset cache: immutable hash directories, revision leases, staged activation | Retain content hashing, cache ownership, exact-revision checks and failure recovery, not executable scenes. |
| `scripts/multiplayer/network_handler.gd`: resolve/stage/join/acknowledge/activate | Preserve membership/content transaction boundaries. |
| `scripts/GUI/world_explorer.gd`: remote catalog plus relay instance listings | Keep discovery/delivery separate; update metadata/schema support without moving hosting. |
| `scripts/player/`: desktop/VR controls, remote avatars and tracking, no shared pickup subsystem found | Add one interaction abstraction rather than separate incompatible pickup implementations. |
| `relay_protocol/packet_info.gd`: explicit IDs through animation ID 28 | Negotiate new capabilities; allocate checked, unused IDs during implementation. Do not renumber existing values. |
| [Relay lifecycle](../relay-data-lifecycle.md): client-owned bans, active connections only | New object/script state must not restore durable relay history. |

The current Active Instance UI/protocol offers management beyond kick/ban. This
proposal intentionally narrows that target behavior; hiding buttons alone is
insufficient. Current moderated admission can close after succession when policy
is missing; safe policy handoff below is required, not assumed already present.

## 3. Architecture and trust boundaries

```text
Godot project → add metadata → manually ZIP selected files → existing URL
                                                                  ↓
catalog/URL → bounded fetch → archive/schema/asset validation → staged WorldDocument
                                                                  ↓
authorized exact-revision instance join → acknowledgement → trusted scene builder
                                                        ↙                 ↘
                                         restricted script VM       interaction service
                                                        ↘                 ↙
                                         typed intents through existing relay
```

Proposed modules, names subject to implementation review:

| Module | Responsibility |
| --- | --- |
| `WorldPackageReader` / `WorldValidator` | Bounded ZIP/TSCN/TRES/media parsing to typed data; no engine resource execution or project startup. |
| `WorldDocument` / `WorldBuilder` | Stable IDs, validated components; construct only application-owned node types/materials. |
| Godot editor / optional future author tools | Native scene/resource editing and saves; metadata examples and manual packaging instructions first, optional validation/export convenience later. |
| `WorldScriptVM` / `WorldCapabilityBroker` | Metered interpreter and checked commands; no engine objects cross the boundary. |
| `InteractionService` / desktop and VR adapters | Selection, grip requests, prediction, held pose, use and release. |
| `WorldStateReplicator` | Revision-scoped commands, snapshots, sequencing and recovery. |
| Existing relay extension | Authenticate/rate-limit/sequence bounded typed operations; membership and temporary grip arbitration only. |

The relay does **not** download worlds, run scripts, simulate physics, choose game
outcomes or save world state. Sequencing/grip leases are explicit extra temporary
router responsibilities, not a disguised host. All clients validate operations;
the relay cannot prove geometry/reach correctness without the world. If even this
small arbitration extension is unacceptable, exclusive, consistently ordered
simultaneous grabs cannot be promised by this design; do not substitute a privileged
player-host without revisiting the contract.

## 4. New saving format: source project, published package, live state

Replace the old executable-scene archive schema, not account/profile/friends
storage. Three deliberately separate formats prevent saving private or transient
state into published worlds.

### 4.1 Editable source: a normal Godot project

```text
my-world/
  project.godot                # normal Godot project, author-side only
  world.json                   # world metadata; packaged as manifest.json
  scenes/world.tscn            # main scene made in the Godot editor
  scenes/props/*.tscn          # reusable native scene instances
  materials/*.tres             # built-in materials/resources
  models/*                    # imported model sources
  textures/*                  # textures edited/configured using Godot
  audio/*
  logic/<uuid>.worldscript     # UTF-8 restricted language source
  attribution.json
```

- Start with Godot's New Project dialog; add a Node3D world scene, meshes,
  colliders, lights, environments and materials normally. Save/edit with Godot's
  existing inspector, gizmos, import dock, undo and scene/resource system.
- Support built-in nodes/resources through a versioned compatibility table, not a
  replacement JSON hierarchy the author must maintain. Target Node/Node3D,
  MeshInstance3D, StaticBody3D, RigidBody3D, CollisionShape3D, Area3D, Marker3D,
  lights, WorldEnvironment, bounded animation and in-world UI, with reviewed
  properties. Extend the table to more native types; unsupported features produce
  actionable errors, not silent removal or unrestricted class instantiation.
- Add application features through editor-set node metadata and `world.json`:
  stable entity UUID, pickup/grip settings, spawn markers and restricted script
  bindings. Reference nodes with scene-local paths resolved to UUIDs during
  validation; paths never become permission to call arbitrary engine methods.
- Normal Godot nested scenes, external materials and imported model placement
  remain usable. Resolve the entire dependency graph inside the package, including
  UID references; missing/ambiguous dependencies and cycles fail clearly. Document
  a source-based import profile so authors need not ship their `.godot` cache.
- The author's own local project can contain trusted tools/GDScript for authoring,
  but that code is never automatically included or run on joining clients. Ordinary
  Godot GDScript is not converted into safe world scripts merely by packaging it.
- Collaboration uses ordinary Godot project files/version control. Keep source
  backups; validators never rewrite source or overwrite newer/corrupt metadata.
  Opening an untrusted project in Godot can execute editor tooling: joiners must
  not open downloaded worlds as projects to validate or play them.

### 4.2 Published `.cworld` package, schema version 1

Use a strictly profiled ZIP container supported by ordinary HTTP hosting. Authors
manually ZIP the selected scene/resource/media files and metadata. `.zip` and
`.cworld` may name the same container; validate contents, not the extension. The
new manifest identifies the safe schema; the old executable-scene archive is not
accepted as safe simply because its filenames look similar.

```text
manifest.json
scenes/world.tscn               # parsed as data, NEVER loaded as a downloaded PackedScene
scenes/props/*.tscn
materials/*.tres                # parsed allowlisted resources/properties
models/*
textures/*
audio/*
logic/*.worldscript             # parsed/validated by the restricted language frontend
attribution.json
```

Illustrative manifest, not a frozen wire/schema specification:

```json
{
  "format": "comunicare.world",
  "schema_version": 1,
  "world_id": "4aa3a976-15cf-4d85-bd41-5677a12abcde",
  "release": "1.0.0",
  "requires": {"world_api": 1, "script_api": 1},
  "main_scene": "scenes/world.tscn",
  "script_capabilities": ["entity.read", "entity.visual", "interaction.events"]
}
```

- `world_id` is logical lineage, not instance identity or a unique authorship proof;
  `release` is a display version, not security. The revision used by joins/cache is
  SHA-256 of the **complete downloaded archive**, retaining the existing model.
  Do not put a self-referential archive hash inside the archive.
- The minimal hand-written metadata requires format/schema/API versions, world ID,
  release and main scene. The reader computes whole-archive and per-file hashes;
  a generated file table or signature is not required for manual ZIP publication.
  Reject duplicate entries/keys and invalid encoding before resolving references.
- Future optional compiler tooling may produce canonical packages, complete file
  tables and publisher signatures. Signatures identify publishers, not safe code;
  they never bypass validation. Manual ZIP timestamps/order may change the revision
  even with identical content; reproducible builds are a future tooling feature,
  not a prerequisite for the initial workflow.
- Entity UUIDs are stable across edits. Components are allowlisted: transform,
  bounded mesh/material, static collider, spawn, light, audio emitter, trigger,
  pickup, grip anchors, declarative UI, script binding and typed state definition.
  Validate hierarchy cycles, references, transforms and scale before construction.
- `.tscn` and `.tres` are **input syntax, not executable engine resources**. Use a
  bounded static parser for a documented subset of Godot text serialization,
  validating every section, type, property, reference and value before constructing
  application-owned nodes/resources. Never feed these files to `load()`,
  `ResourceLoader`, `PackedScene.instantiate()` or object-enabled deserialization.
  Reject attached engine scripts, executable resources, autoloads, arbitrary signal
  method connections and animation method tracks. Scene inheritance/instances must
  be resolved statically and revalidated; application templates are not bypasses.
- Do not mount PCKs or run downloaded `project.godot`. Ordinary Godot export/compile
  produces neither a sandbox nor a safe package. Initial publication uses text
  scenes/resources plus source media; binary `.scn`/`.res`, GDScript bytecode,
  native libraries and custom shader code are not accepted. A future manually
  invoked safe compiler can output a validated intermediate format; clients must
  still validate it. No compiler is required for initial manual ZIP creation.
- Mesh import supports bounded GLB and source dependencies under the package root;
  external network/absolute paths and unsupported executable extensions are rejected.
  Never trust arbitrary importer-generated nodes without reconstruction/validation.
  Bound and review every additional media decoder before support is enabled.
- **Full standard-material texture support is a core target**, not an albedo-only
  prototype: albedo/alpha, normal, roughness, metallic, ambient occlusion, emission,
  height/parallax, detail, clearcoat and other reviewed StandardMaterial3D/
  ORMMaterial3D channels; UV1/UV2 transforms, filtering, repeat, mipmaps, channel
  packing, transparency, culling and supported texture color-space semantics.
  Include lightmap and environment textures, with capability/renderer diagnostics.
  Validate material/pass chains and bound passes/layers to prevent GPU exhaustion.
- Preserve Godot-configured texture meaning through reviewed import options and
  source media, not arbitrary `.godot/imported` resources. Include required `.import`
  sidecars as statically parsed settings only: allowlist options, ignore generated
  cache destinations and never invoke package-selected importers. Target PNG/JPEG/WebP
  for ordinary images and reviewed HDR/EXR support for environment/high-range maps;
  add bounded compressed, layered and procedural built-in textures through the
  compatibility table. Rasterize unsupported source formats in the author's project
  or report them explicitly. Custom GPU programs and every possible texture plugin
  are not implied by "full texture support"; publish a precise parity matrix.
- No package-requested network URLs, including textures, audio, scripts or fonts.
  All dependencies are embedded and hashed. Catalog thumbnails use their own
  existing bounded fetch path and never grant scripts network access.
- Archive reader rejects traversal, absolute/drive paths, backslashes, symlinks,
  encryption, nested archives, duplicate/case-colliding names and unsupported ZIP
  features. Validate metadata first, then enforce streamed decompression limits;
  ZIP header sizes are untrusted. No unbounded `read_file()` before checking limits.
- Establish a shipped limits profile: proposed starting ceilings are 64 MiB download,
  256 MiB expanded, 4,096 entries, 1 MiB manifest, 10,000 entities, depth 64,
  2 million triangles, 4,096-pixel texture dimensions and 256 MiB decoded texture
  memory. Bound each file, decoder allocation, audio duration, collision complexity,
  lights, draw calls, JSON depth and build time too. Benchmark desktop/VR and lower
  limits where necessary; these figures are proposals, not current guarantees.

### 4.3 Local state and live snapshots

- Optional local script saves use a separate account/world/publisher-namespaced,
  quota-limited JSON store. No file paths exposed to scripts; no account keys,
  contact data or private profile fields. Default is no persistence capability.
- Source edits, exported packages, downloaded cache and per-account local saves
  have separate roots and lifecycles. Clearing cache must not delete source work.
- Live instance snapshots contain only bounded schema-defined variables, object
  transforms, lease epochs, script tick/seed and sequence watermark. Never include
  native nodes, closures, source paths, microphones, tracker IDs or account secrets.
- Instance state is ephemeral and disappears when the last participant leaves.
  No automatic cross-instance, cross-revision or reconnect restore. User-triggered
  world-state export, if added later, needs a distinct consent/schema design.

## 5. Script execution without engine execution

Choose a small **typed, metered interpreter** for version 1, not filtered GDScript,
`Expression.execute()` with engine objects, or an unrestricted Lua/Python binding.
Authors edit restricted text scripts alongside their Godot project and bind them
using node/world metadata. The client parses and validates them into a typed syntax
tree; an optional future visual tool/compiler can target that same representation.
Compiler output is still untrusted input. Standard Godot script attachments do
not gain unrestricted client execution through this workflow.

- Support variables, finite numbers, booleans, bounded strings/arrays, functions,
  conditionals, bounded loops and event callbacks. No reflection, dynamic imports,
  eval, recursion, arbitrary threads, engine references or executable extensions.
- All values are copied data or opaque entity handles scoped to this world and
  generation. Broker checks lifetime, capability, target entity and value bounds
  on **every call**, not merely when handing out a handle.
- Useful events: start, fixed tick, enter/exit trigger, grab, release and use.
  Useful APIs: read approved entity state, set declared visual properties, play
  packaged sound, animate authored objects and propose typed shared-state commands.
  Doors, switches, puzzles and toys must work without expanding the OS boundary.
- No filesystem, sockets/HTTP, process launch, shell, clipboard, account/social APIs,
  unrestricted input, camera control, capture/device access, native plugins,
  moderation, join/teleport-to-URL calls or arbitrary RPC. Opening an external link
  requires trusted application UI, explicit user confirmation and safe schemes.
- World UI is clearly marked and cannot impersonate application/security dialogs.
  Never let world scripts request passwords or silently collect typed text.
- Initial per-world budgets: 100,000 interpreter steps/tick at 20 Hz, 8 MiB managed
  heap, 64 KiB script state/module, 256 queued events and bounded broker commands.
  Specify maximum scripts and aggregate client budgets; subdividing scripts must
  not multiply the allowance. Also meter expensive host calls and value copying.
- Fuel checks occur inside loops and operations; a frame watchdog alone cannot
  interrupt a stuck call. Bound AST depth, call stack and allocation before work.
  On violation abort that event transaction, discard pending commands and disable
  the offending module. Rate-limit diagnostics; keep trusted menu/leave responsive.
- Shared logic runs identically on participants from ordered events, fixed ticks,
  seeded randomness and defined fixed-point arithmetic. No local wall clock,
  unordered dictionary iteration or engine physics results in deterministic logic.
  Cosmetic/local behavior is explicitly separate and cannot commit shared state.
- Players can disable world scripts globally or stop them immediately from trusted
  UI. Script-required worlds explain that they cannot be joined interactively with
  scripts disabled; offer safe offline preview instead of silent state divergence.

The VM isolates script behavior, not a vulnerable image/mesh decoder. Investigate
an OS-sandboxed importer worker with bounded typed output for hostile media; this
is a local helper, not a gameplay server. Platform isolation and native parser
review need explicit release decisions. Never label a worker thread a security
sandbox or an optional publisher signature a substitute for isolation.

## 6. Shared state without a privileged host

- Bind every operation to protocol version, session ID, exact world hash,
  connection generation, entity UUID, epoch and monotonic sequence. Authenticate
  the sender from its connection, never from a supplied `player_id`.
- The existing relay provides a bounded ordered reliable control stream and
  atomic temporary grip leases. It forwards typed state, not executable payloads.
  Non-members, old sessions, stale revisions and unsupported versions fail closed.
- Separate reliable discrete operations (grab/release/use, variable transactions,
  joins/snapshots) from sequenced disposable poses. Budget bytes/second, messages,
  entities and buffered snapshots per sender and instance; backpressure, don't grow
  queues indefinitely. Transport acknowledgements do not prove valid gameplay.
- Shared scripts consume the same event order and commit validated transactions.
  Compare bounded state digests/checkpoints. A disagreement freezes affected shared
  behavior and offers rejoin/reset; do not elect an all-powerful script host.
- Late join: an ordinary participant supplies a bounded snapshot at a relay
  watermark, preferably corroborated by another participant's digest. Buffer a
  bounded tail, validate then replay before enabling interaction. Snapshot donor
  is replaceable and gains no rights. With only one existing peer there is no
  independent correctness proof; treat its snapshot as hostile data. On timeout,
  conflicting snapshots or tail overflow retry then fail the destination join,
  leaving old membership intact. Integrate readiness with staged admission so an
  uninitialized participant never broadcasts into the destination.
- Free physics is not cross-device deterministic: use a short-lived controller
  lease per moving object, assigned independently of admin status. Controller
  sends bounded poses/velocities; others interpolate. Sleeping objects stop sending.
  On controller exit, reassign or settle/reset at last valid state. No single
  participant controls the entire simulation; active lease epochs reject old data.
- Modified clients can falsify legal-looking poses or snapshots. Clamp locally,
  reject impossible values, isolate bad objects and expose local hide/report/leave
  controls. Do not claim strong authoritative anti-cheat or Byzantine consensus.

## 7. Pickup, carrying and use: one contract for VR and desktop

Each pickup component declares mass/size limits, primary/secondary grip anchors,
allowed hand count, interaction range, collision mode, use events and reset rules.

1. VR near-grab uses hand/controller pose plus grip action. Desktop uses a
   center-screen/ray target, remappable grab/use/drop keys and a camera-relative
   virtual hand. Optional accessibility ray grab has a world/client distance cap.
   Trusted UI capture wins over gameplay input; do not break current menu bindings.
2. Both adapters issue the same `grab_request(entity, grip_slot, observed_epoch)`.
   Check membership, exact revision, availability and locally observed reach/line
   of sight. Relay serializes competing requests; first valid lease wins. Predicted
   attachment is visibly provisional and rolls back on denial or timeout.
3. Accepted state includes holder connection generation, lease epoch, slot and
   object-to-grip transform. Replicate **object ownership and anchor**, not just
   controller animation. Remote clients resolve to that avatar's tracked hand or
   desktop virtual grip; fallback to body-relative grip if tracking is unavailable.
4. Send bounded, quantized hand/object targets at a capped rate (start at 20 Hz),
   interpolate visually and guard tracker loss, abrupt locomotion and avatar swaps.
   Keep a stable gameplay anchor independent of decorative avatar bone offsets.
5. Held bodies follow a trusted kinematic/constraint policy with swept collision
   and bounded correction. Do not let remote mass/forces launch players or move
   their cameras. Player pushing/weapon damage is outside the initial scope.
6. Release commits final valid transform and capped linear/angular velocity. Derive
   VR throw from a short pose window; desktop uses a capped throw action. Handoff
   is an atomic lease transfer requiring recipient grab/consent, not forced inventory.
7. Two-hand grips share one object lease; secondary grip is subordinate and cannot
   create a second physics owner. Missing hand, sleep, menu safety release, peer
   disconnect, kick/ban and world change all have explicit release/reset paths.

Acceptance includes simultaneous VR/desktop grabs, packet loss/reordering, remote
held-item visibility, two-handed pickup, throw collisions, late join while held,
holder disconnect, peer-ID reuse, tracking loss and an admin leaving mid-grab.

## 8. Moderation, succession and bans

- Creator starts as an ordinary admin; do not retain a separate permanent owner
  role. All gameplay/VM/lease validation is identical for admins and other players.
- Remove extra live management powers from both protocol authorization and UI.
  Instance visibility/access options are selected at creation and immutable for
  that instance; changes create a new instance. Existing social admission checks
  remain admission constraints, not general host commands. Request-mode approval
  remains a narrow admission decision; it is not arbitrary gameplay authority.
- Deterministic succession selects the longest-continuously-present eligible
  participant, with relay membership order as tie-breaker. Relay publishes the new
  role revision atomically; the old connection cannot act afterward. No voting,
  host migration or previous creator override is necessary. Empty instances end.
- Ban scope is the random live-instance moderation ID, not world URL/all instances.
  Reuse existing account-bound client-local moderation storage and fresh unanimous
  admin admission checks. Do not reintroduce disconnected-target relay history.
- Add bounded policy handoff to all participants eligible for fallback admin, with
  explicit notice that ban-target identifiers are client-held moderation data.
  Use authenticated, instance/epoch-scoped policy events, acknowledgements and
  integrity/version checks; do not expose whole policy to ordinary world scripts.
  Client retention/access rules need a privacy review before enabling this handoff.
- Planned departure waits for successor policy acknowledgement where possible.
  Abrupt departures use already acknowledged replicas. If no remaining player has
  complete policy, succession still happens but **new admission stays closed**.
  Never clear bans silently to make succession appear seamless. Signed events
  establish provenance, not a guarantee that a malicious replica retained history.
- A compromised admin can misuse kick/ban; it cannot gain OS/script/editor rights.
  New identity ban evasion is not solved by this account model. No permanent relay
  database, IP tracking or host privilege is introduced to disguise that limitation.

This section supersedes older extra-management proposals only as a future target;
the [current lifecycle contract](../relay-data-lifecycle.md) stays binding throughout.

## 9. Easy authoring, publication and safe updates

The initial workflow is entirely manual:

1. Create a new project in the supported Godot version (currently 4.7).
2. Build a world normally using Godot nodes, scene instances, imported models,
   materials and textures. Save the main scene and all dependencies.
3. Add `world.json` using the documented metadata example, mark spawn/pickup/grip
   nodes through metadata and optionally add restricted world-script files.
4. Copy selected content into a staging folder, copy `world.json` as
   `manifest.json`, and preserve package-relative paths. Exclude `.godot`, `.git`,
   secrets, accounts, editor plugins and ordinary executable scripts. `project.godot`
   stays in the author's project; the package is content, not a runnable project.
5. Manually ZIP the staging contents with `manifest.json` at the archive root.
   No special compiler, custom editor, plugin or upload service is mandatory.
6. Test the package using the client's safe offline preview, then manually upload
   it to the same hosting location and share/update the existing URL/catalog entry.
7. To update, reopen the original project in Godot, edit/save, increment release
   metadata, repeat packaging and test before upload. Keep source and old archives.

- Supply documentation, a complete example Godot project and a metadata template
  first. Optional Godot inspector helpers, validators and safe compiler/export
  scripts can come later without replacing this manual workflow.
- Native Godot Run is useful for trusted local visual work but does not demonstrate
  client compatibility or sandbox safety. Safe preview must use exactly the
  production parser, builder, VM, material profile and limits, reporting unsupported
  nodes/properties/textures with original scene/resource paths.
- Manual packaging must not depend on hidden cache files or undocumented remap
  tables. Test a freshly copied project/package on a second machine with no author
  import cache. Never run a packaged editor plugin to import a downloaded world.
- Save edits as a new immutable revision. Upload the exported package using the
  existing hosting method; no automatic request for hosting credentials. Keep older
  files at immutable URLs if old pinned instances should remain joinable.
- Existing cache refresh may announce a new hash but must not replace an active
  instance's content. New instances select the new revision; old instances remain
  pinned. If the old archive is unavailable and uncached, joining that old instance
  fails clearly rather than accepting different bytes under the same URL.
- Default update workflow: any participant offers the new revision; each user
  independently chooses to join a **new instance** through ordinary staged admission.
  No admin-only upgrade button or forced migration. Declining users stay where they
  are; held objects and ephemeral state do not cross automatically.
- Hot reload is local/offline preview only in version 1. Later live migration needs
  unanimous explicit consent, compatible schemas, quiesced leases, bounded pure
  state transforms and rollback design; do not run publisher-supplied migration code
  outside the VM. Rollback means selecting a previous package in a new instance.

## 10. Compatibility and migration

- Ship a negotiated safe-world capability and new package reader alongside the
  existing code, then make downloaded executable scenes unavailable in normal join
  flows. An old peer cannot join a new shared-interaction instance in degraded mode.
  Incompatible clients receive a clear upgrade message before membership changes.
- Do not add a "trusted publisher → native scripts" escape hatch to safe mode.
  Existing trust settings should migrate to an explanatory legacy warning, never
  be interpreted as consent to expand safe-world capabilities.
- Convert legacy scenes only as an explicit offline author tool on files the author
  already trusts. Prefer static parsing of a narrow supported subset; never open an
  unknown scene in the normal client to discover its scripts. Report dropped scripts,
  unsupported resources and manual logic rewrites; preserve original source files.
- Built-in `default_wold` remains application-trusted content during rollout; port
  it to the data model as a reference fixture without renaming the legacy identifier.
- Keep URL/catalog transport, existing HTTP opt-in policy, cache leases and exact
  hash pinning. Expand wire IDs only after checking the current branch; distinguish
  package schema, script API, replication protocol and application versions.
- No mandatory account/profile/settings reset. Update references and runtime guides
  only when code ships; label historical unsafe loading accurately throughout.

## 11. Delivery phases and measurable gates

Work in coherent tested parts; for each implementation bug, first reproduce with
a failing isolated test, then publish the passing fix. Do not treat this checklist
as completed implementation.

| Phase | Deliverable | Exit gate |
| --- | --- | --- |
| 0 — contracts | Threat model, metadata schema, Godot node/resource/texture parity matrix, VM semantics, permission matrix, wire negotiation and moderation privacy review | Supported native authoring features and rejected executable features are explicit; parser-isolation decision recorded. |
| 1 — data-only worlds | Bounded ZIP/TSCN/TRES/media reader, typed document/builder, standard-material texture pipeline | Hostile corpus fails closed; no downloaded resource execution; representative multi-textured Godot scenes preserve reviewed properties; malformed input preserves current world. |
| 2 — manual Godot authoring | Example Godot project, metadata template, node/grip metadata guide, manual ZIP instructions and safe preview | New ordinary Godot project can be edited/reopened, packaged and played on a clean machine without custom editor/plugin/compiler or author import cache. |
| 3 — restricted scripting | Typed text language bound through metadata, fuel/memory accounting, broker and diagnostics | Doors/puzzles work; filesystem/network/reflection and handle escape tests fail; infinite loops/event floods cannot freeze trusted UI. |
| 4 — ephemeral replication | Sequenced events, grip leases, late-join snapshots, bounded physics controller transfer | Multi-client loss/reorder/race/disconnect tests; no cross-instance/revision packets accepted; relay restart/cleanup retains no user/session history. |
| 5 — complete pickup UX | Shared desktop/VR interaction, remote grips, throws, handoff and two hands | Real desktop + headset sessions see identical holders; tracking loss, comfort, collision and accessibility checks pass. |
| 6 — roles and updates | Kick/ban-only moderation, deterministic fallback, safe policy handoff, revision notifications/new-instance update UX | Creator has no extra powers; last-admin abrupt exit tested; incomplete policy fails closed; update refusal preserves current play. |
| 7 — rollout | Legacy conversion guidance, compatibility rejection, current documentation and security review | No normal remote-scene execution path; external hostile-content review; performance/hardware gates and remaining risks published. |

Proposed isolated suites: `tests/world_format`, `tests/world_authoring`,
`tests/world_scripting`, `tests/world_replication` and `tests/world_interaction`.
These directories do not exist as a consequence of this plan. Use disposable
projects/accounts like the existing runners, never normal startup against real data.

Required test matrix:

- Archive bombs, streaming overrun, duplicate names/keys, Unicode/path ambiguity,
  truncated files, forged sizes/hashes/signatures, unsupported schemas and NaN/Inf.
- Malformed GLB/images/audio, external dependency references, decoder memory/time,
  excessive hierarchy/colliders/materials and attempted engine resource injection.
- Malicious TSCN/TRES constructors, script attachments, inherited/instanced scenes,
  UID/path collisions, signal connections and animation call tracks; reject them
  without loading resources or starting the downloaded project.
- Godot-created scene/material fixtures covering PBR channels, alpha, UV transforms,
  normal/color-space handling, mipmaps, filtering, lightmaps and HDR environments;
  compare safe-preview renders with the documented native rendering profile.
- VM arithmetic/loop/call-depth/heap/event exhaustion, command amplification,
  stale/forged handles, capability bypass and world-UI impersonation boundaries.
- Cross-account local-save access, corrupt save preservation, interrupted writes,
  cache eviction during active leases, manual ZIP dependency completeness and
  optional compiler reproducibility when that tooling is introduced.
- Simultaneous grabs, forged senders/roles, old epochs, reused peers, stale snapshots,
  disconnect mid-transaction, divergent digests and malicious single-donor data.
- Admin privilege escalation, creator departure, policy handoff/timeout, reconnect
  ban admission, relay state scans and zero durable relay writes.
- Existing profile, discovery, Active Instance, friends, avatar, microphone,
  multiplayer-reliability and VR/tracking regressions as applicable. Check runners'
  current availability; old roadmap pass counts are not new evidence.
- Manual Forward Plus/OpenXR/desktop testing, low-end memory/latency budgets,
  real VR/desktop carrying visibility and network impairment. Headless Compatibility
  tests cannot certify rendering, decoder isolation, comfort or headset behavior.

## 12. Completion definition and non-goals

Complete means an author can create an ordinary Godot project, use its native
scene/material/texture tools, add metadata and manually ZIP, safely preview, publish,
edit and republish a world through current hosting; another user can join without
enabling native world code; useful restricted scripts run; VR/desktop players see each other's carried
items; and the creator can leave without taking the instance or special powers with
them. Ban continuity and failure modes must be visible, not silently weakened.

Not promised: arbitrary Godot addon compatibility, general-purpose native scripting,
perfect anti-cheat, permanent shared worlds, a new hosting platform, admin gameplay
consoles, a separate world editor, mandatory publishing automation, arbitrary custom
shaders, seamless forced updates or zero-risk execution of all possible media.
