# Safe, editable worlds and shared interaction roadmap

**Status: proposal, 2026-11-04. No runtime implementation or security certification.**
This is the target design for replacing downloaded executable Godot worlds. It
does not make today's loader safe. The current behavior remains documented in
[worlds and instances](../guides/worlds-settings-and-voice.md).

## 1. Product contract and explicit interpretation

- Anyone can build, preview, save, publish and update a world without writing code.
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
local editor project → validate/build → immutable world package → existing URL
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
| `WorldPackageReader` / `WorldValidator` | Bounded bytes to typed data; no resource execution, extraction-dependent loading or network callbacks. |
| `WorldDocument` / `WorldBuilder` | Stable IDs, validated components; construct only application-owned node types/materials. |
| `WorldEditor` / `WorldProjectStore` | Draft operations, undo, recovery, validation and reproducible export. |
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

### 4.1 Editable source project

```text
my-world/
  project.json                 # source schema, world ID, title, editor preferences
  scene/entities.json          # stable UUID entities and typed components
  prefabs/<uuid>.json          # reusable editable assemblies
  logic/<uuid>.worldscript     # UTF-8 restricted language source
  assets/<local-name>.*        # source media with licenses/provenance
  attribution.json
```

- Human-readable, version-control-friendly JSON; no Godot scene/resource files.
  Reject duplicate keys, invalid encodings and ambiguous numbers/IDs.
- Atomic replace with previous-good recovery, bounded autosave journal and explicit
  schema migrations. Preserve damaged originals and unknown newer projects;
  never silently overwrite them. Undo is an editor operation log, not game state.
- Local filenames are source-only. Import copies into a chosen project root;
  documents cannot request arbitrary reads. Protect editor imports too.
- Collaboration initially means exchanging source projects/version-control changes,
  not concurrent editing rights for instance admins. Stable IDs support future merges.

### 4.2 Published `.cworld` package, schema version 1

Use a strictly profiled ZIP container supported by ordinary HTTP hosting. The
extension is new; the old `main_scene` archive is **not** accepted as this format.

```text
manifest.json
scene.json
logic/<sha256>.json             # validated typed syntax tree, never engine bytecode
assets/<sha256>.<allowed-type>  # self-contained data only
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
  "entry": "scene.json",
  "files": [
    {"path": "scene.json", "sha256": "<64 lowercase hex characters>", "bytes": 1234}
  ],
  "script_capabilities": ["entity.read", "entity.visual", "interaction.events"]
}
```

- `world_id` is logical lineage, not instance identity or a unique authorship proof;
  `release` is a display version, not security. The revision used by joins/cache is
  SHA-256 of the **complete downloaded archive**, retaining the existing model.
  Do not put a self-referential archive hash inside the archive.
- Define a canonical manifest serialization for optional publisher signatures
  over manifest fields plus the complete file hash table (excluding the signature).
  Reject duplicate/unlisted entries; signatures identify a publisher, not safe code.
  Pinning a publisher is separate from account ownership and must warn on key changes.
- Deterministic build order, timestamps, numeric encoding and compression settings;
  hash table covers every non-manifest file. Rebuilds of identical input must match.
- Entity UUIDs are stable across edits. Components are allowlisted: transform,
  bounded mesh/material, static collider, spawn, light, audio emitter, trigger,
  pickup, grip anchors, declarative UI, script binding and typed state definition.
  Validate hierarchy cycles, references, transforms and scale before construction.
- No `.tscn`, `.scn`, `.tres`, `.res`, `.gd`, PCK, DLL/shared library, shader code,
  arbitrary class names, NodePaths, method names or serialized engine objects.
  Never call `load()`, `ResourceLoader` or object-enabled Variant deserialization
  on package-selected content. Trusted application resources remain internal.
- Initial media profile: validated self-contained GLB geometry with external URIs,
  unknown extensions and embedded executable behavior rejected; bounded PNG/JPEG
  textures and bounded WAV audio. Rebuild materials from approved parameters;
  don't accept arbitrary glTF-generated trees as trusted scenes. Add formats only
  after decoder review, test vectors and resource limits.
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
Visual logic and text scripts compile to the same validated syntax tree. Loaders
revalidate the tree; a compiler's output is still untrusted input.

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

The normal workflow should be: **New from template → place/import → test → publish
file → upload to the same web host → share the same URL**.

- Desktop editor first: hierarchy, drag/drop placement, gizmos/snapping, inspector,
  prefab library, spawn markers, grip preview, undo/redo, autosave and diagnostics
  linked to the offending entity. Use shared accessible UI; VR placement/edit tools
  follow without making VR hardware necessary to author worlds.
- Templates include room, outdoor space and pickup playground. Visual logic covers
  switches, doors, timers and sounds; text view exposes the same restricted language.
  Explain budgets and denied APIs in plain language. Source files remain editable.
- Import wizard reports material/mesh conversion, texture/physics budgets, missing
  licenses and unsupported features. Publishing strips source paths/private editor
  data, validates all references and builds reproducibly into a chosen local file.
- Preview uses exactly the production validator, builder, interpreter and limits,
  with fake participants and desktop/VR grip visualization. No editor-only bypass
  that accidentally makes unsafe packages seem publishable.
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
| 0 — contracts | Threat model, strict schemas, VM semantics, permission matrix, wire negotiation and reviewed moderation privacy decision | Malicious author/peer/admin cases mapped to controls; no hidden host/server assumption; parser-isolation decision recorded. |
| 1 — data-only worlds | Package tooling, bounded reader, typed document/builder, safe built-in example | Hostile archive/schema/media corpus fails closed; no executable-resource loads; deterministic build; malformed input leaves current world untouched. |
| 2 — editor and saves | Templates, entity/prefab tools, validated imports, undo/autosave/recovery, export | Beginner creates/edits/reopens/publishes a pickup room without code; interrupted saves recover; source/cache separation verified. |
| 3 — restricted scripting | Typed language, visual logic, fuel/memory accounting, broker and diagnostics | Doors/puzzles work; filesystem/network/reflection and handle escape tests fail; infinite loops/event floods cannot freeze trusted UI. |
| 4 — ephemeral replication | Sequenced events, grip leases, late-join snapshots, bounded physics controller transfer | Multi-client loss/reorder/race/disconnect tests; no cross-instance/revision packets accepted; relay restart/cleanup retains no user/session history. |
| 5 — complete pickup UX | Shared desktop/VR interaction, remote grips, throws, handoff and two hands | Real desktop + headset sessions see identical holders; tracking loss, comfort, collision and accessibility checks pass. |
| 6 — roles and updates | Kick/ban-only moderation, deterministic fallback, safe policy handoff, revision notifications/new-instance update UX | Creator has no extra powers; last-admin abrupt exit tested; incomplete policy fails closed; update refusal preserves current play. |
| 7 — rollout | Legacy conversion guidance, compatibility rejection, current documentation and security review | No normal remote-scene execution path; external hostile-content review; performance/hardware gates and remaining risks published. |

Proposed isolated suites: `tests/world_format`, `tests/world_editor`,
`tests/world_scripting`, `tests/world_replication` and `tests/world_interaction`.
These directories do not exist as a consequence of this plan. Use disposable
projects/accounts like the existing runners, never normal startup against real data.

Required test matrix:

- Archive bombs, streaming overrun, duplicate names/keys, Unicode/path ambiguity,
  truncated files, forged sizes/hashes/signatures, unsupported schemas and NaN/Inf.
- Malformed GLB/images/audio, external dependency references, decoder memory/time,
  excessive hierarchy/colliders/materials and attempted engine resource injection.
- VM arithmetic/loop/call-depth/heap/event exhaustion, command amplification,
  stale/forged handles, capability bypass and world-UI impersonation boundaries.
- Cross-account local-save access, corrupt save preservation, interrupted writes,
  cache eviction during active leases and reproducible package export.
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

Complete means a novice can create, safely preview, publish, edit and republish a
world through current hosting; another user can join without enabling native world
code; useful restricted scripts run; VR/desktop players see each other's carried
items; and the creator can leave without taking the instance or special powers with
them. Ban continuity and failure modes must be visible, not silently weakened.

Not promised: arbitrary Godot addon compatibility, general-purpose native scripting,
perfect anti-cheat, permanent shared worlds, a new hosting platform, admin gameplay
consoles, seamless forced updates or zero-risk execution of all possible media.
