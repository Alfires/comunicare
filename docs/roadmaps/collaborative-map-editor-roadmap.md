# Local-first collaborative in-game map editor roadmap

Status: **proposal, not implemented**. Multiplayer editing, project synchronization
and project recovery described here are not current runtime features.

Initial implementation update: local JSON editor/save/export panel and service
primitives now exist; 36 service contracts pass. See
[current limits](../../scripts/editor/README.md). Authenticated editing transport,
friend invitations, visual gizmos and actual playtest launches remain unimplemented.
The roadmap is not complete and no remote editing access is enabled.

Test-first update: opt-in [editor acceptance contracts](../../tests/map_editor/README.md)
exist with a verified absent-editor baseline of 0 passed, 7 failed, 7 dependent
groups blocked, exit 1 without engine errors. These proposed service seams do not
establish real networking, editor UI or hardware VR support.

## Goal

Create and edit maps locally in desktop or VR, optionally together with friends,
then export a safe playable package. The creator owns the project on their PC;
friends collaborate through an authenticated live session. No permanent relay
storage, cloud account or hosting-provider dependency is required.

Share the authoring document, component registry, compiler and safe export gates
with the [Godot authoring plugin](world-authoring-plugin-roadmap.md). Do not build
a second incompatible world format or use play-state packets as edit operations.

## Essential distinction

- **Project:** editable source document, asset inventory, provenance and edit journal.
- **Play package:** immutable validated runtime output, identified by content hash.
- **Edit session:** ephemeral authenticated membership, roles and ordered operations.
- **Play session:** existing acknowledged instance/revision behavior and pickup leases.

Two instances of the same world URL are not one edit session. Joining a friend or
learning a project identifier never grants editing access. Local file loading
alone does not transfer the file or create a collaborative session.

## Intended user journey

1. Choose **Create map** or open a local authoring project.
2. Select a template and place objects with desktop mouse/keyboard or VR controllers.
3. Save locally, inspect errors and playtest a disposable snapshot.
4. Choose **Invite friends to edit**, explicitly approve collaborators and assign roles.
5. Collaborate with clear selections/locks and a visible connection/sync indicator.
6. Stop editing or playtest together against a validated revision.
7. Export a `.cworld` package; open locally or host through the existing URL workflow.

The UI must distinguish Save project, Export playable map, Playtest and Publish.
Show unsaved changes and recovery state; never pretend a disconnected edit was
saved by another user's machine.

## Authority, privacy and collaboration design

- Initial topology: creator's client is project authority and persists the journal.
  Relay routes bounded messages and keeps active-connection state only. Host loss
  ends the editing session; automatic authority migration is deferred.
- Owner, editor and viewer roles; invitations bind account fingerprints, project
  identity and edit-session generation. Roles live in client-owned policy, and
  disconnected-user references are removed from relay caches/subscriptions.
- Project snapshots and operations require negotiated capability/version support,
  authenticated admission, limits and explicit new wire values. Do not repurpose
  existing packet IDs or silently allow old clients to edit.
- Every operation has an ID, sender, session generation, expected project revision,
  entity/component target and bounded payload. Authority validates and orders it,
  then broadcasts an acknowledgment/canonical result.
- Reject stale generations, unauthorized targets, invalid assets, oversized arrays,
  replayed operations and rate-limit floods. Client previews are never authority.
- Asset transfer is explicit, content-hash verified and size-budgeted. Never expose
  filesystem paths, account keys or arbitrary remote file fetching. Warn creators
  that sharing an asset supplies its bytes to collaborators; licenses must allow it.
- Save journals and optional collaborator policy on the owner's PC, not relay disk.
  No automatic presence telemetry, clipboard sync or hidden external requests.

## Milestones

### 01 — Shared local project and recovery

- Open/create/save with versioned schema and stable IDs. Source and exports separate.
- Atomic saves, bounded journal/checkpoints, crash recovery and explicit recovery UI.
- Preserve invalid/newer project files; read-only inspection and Save As where safe.
- Store assets by content hash; export only reachable, reviewed dependencies.
- Accept: reopen without data loss; interrupted writes leave a recoverable version;
  traversal/object-deserialization attacks fail; project never includes private paths.

### 02 — Desktop editing foundation

- Select, multi-select, move/rotate/scale, snapping, duplicate, delete and hierarchy.
- Inspector with units, transform reset, spawn markers and collision visualization.
- Layer/selection visibility and searchable object list; prevent accidental player,
  menu, network-service or editor-tool selection/export.
- Undo/redo records commands, not arbitrary node snapshots; duplication generates
  new IDs and remaps internal references deterministically.
- Accept: keyboard/text-field shortcuts never conflict; gizmos work at different
  window sizes; undo restores bindings as well as transforms.

### 03 — VR editing parity

- Floating movable tablet, controller-ray selection, direct manipulation, two-hand
  scaling, precision/snap modes and accessible numeric entry.
- Separate editor locomotion and object-grip ownership from gameplay pickups.
  Explicit modes, comfortable movement defaults and release/rearm on focus/tracking loss.
- World/player scale is a local viewing tool unless the user commits object changes;
  it must not accidentally rescale the saved project or another collaborator.
- Accept: desktop/VR produce identical canonical operations; tracker emulator tests
  input lifecycles; physical OpenXR/headset tests cover comfort, precision and UI.

### 04 — Assets and interaction/behavior tools

- Import supported local assets with preview, budgets and provenance. Untrusted
  imported projects follow the same validation as external content.
- **Make pickup / Make interactable / Make checkpoint** tools use the shared plugin
  definitions, stable IDs, approved colliders and typed script target pickers.
- Add supported event/action templates and local progress inspection in a test scope.
  No arbitrary GDScript console, filesystem API, network API or runtime plugin installer.
- Accept: edit → export → production load preserves visuals, interactions, IDs and
  capability declarations. Unsupported components block export with useful repairs.

### 05 — Authenticated friend collaboration

- Create a distinct edit instance and invite selected friends; default deny.
- Admission policy integrates current instance access/moderator requirements; friends
  do not bypass bans, owner consent or missing capability support.
- Viewer/editor permissions enforced by host on every operation; revocation blocks
  subsequent edits immediately. Export/copy permission is an explicit product choice;
  it cannot technically revoke asset bytes already received.
- Initial join sends a bounded snapshot plus revision, then subsequent operations.
- Accept: two desktop clients and mixed PC/VR emulator clients join the exact edit
  session, converge on identical documents and cannot edit another instance.

### 06 — Conflicts, undo and reconnect

- Begin with short-lived per-entity manipulation leases, visible ownership and
  expiration. Authority serializes property changes and rejects stale expected revisions.
- Do not lock a whole project for one drag. Coalesce drag previews, rate-limit sends,
  and commit an exact final transform. Disconnected leases clear promptly.
- Collaborative undo is a new inverse operation checked against current revision;
  it must not erase another person's later changes. Clearly explain conflicts.
- On reconnect, request snapshot/delta by generation/revision; never blindly replay
  stale offline edits. Offer explicit local draft recovery/import where appropriate.
- Accept: simultaneous grabs/edits, rename/delete/reference conflicts, packet delay,
  duplicate delivery, rejection, disconnect and host shutdown converge or fail clearly.

### 07 — Isolated playtest and map transitions

- Validate/compile an immutable revision without stopping or mutating the source project.
- Solo playtest uses production desktop/VR players, spawn, local progress and pickups;
  test saves use a disposable namespace rather than overwriting real player progress.
- Group playtest requires all participants to acquire/validate the pinned package
  before acknowledged instance transition. Never merge edit roles with play authority.
- Return to editing restores unsaved project, selection and local view state; clear
  transient gameplay leases/avatars. Failed builds keep the edit session usable.
- Accept: repeated edit/play/edit and world/instance switches with two clients,
  unavailable assets, failed validation, menu closure and network loss.

### 08 — Optimization, export and polish

- Reuse opt-in reversible optimization from the plugin roadmap. Show budgets and
  measured target-device frame time; never silently simplify shared project sources.
- Snapshot/journal compaction, dependency deduplication, bounded undo history and
  spatial selection indexes. Large worlds need incremental loading and cancellation.
- Export only after validation; label unsupported visual features and runtime limits.
- Owner-controlled Save As/collaboration copies, attribution/Credits and explicit
  collaborator contribution policy. No implied asset-ownership transfer.
- Accept: sustained multi-client editing soak, bounded memory/message/journal growth,
  deterministic exports and no durable relay data after disconnect.

## Testing and delivery gates

Deliver local editing before networking. Build failing reproductions for bugs and
publish only coherent verified changes. Pure-data tests cover commands, references,
permissions, inverses and revision ordering; disposable production-runtime tests
cover export/reload, local saves and interaction wiring. Add real loopback multi-client
fault tests and rendered desktop journeys. Emulator/Compatibility results do not
certify Forward Plus performance, OpenXR rendering or physical-controller comfort.

Release 1 should explicitly exclude host migration, offline automatic merge, public
anonymous editing, arbitrary scripting, unlimited assets and authoritative shared
gameplay. Add each later only after its protocol, trust model and tests exist.

The [relay lifecycle contract](../relay-data-lifecycle.md) remains authoritative.
Persistent contacts, consent and project policy stay client-owned. Relay discovery
must not advertise private editor projects or return their asset lists to outsiders.
