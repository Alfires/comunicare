# Additional production contracts

<!-- module: scripts/assets/avatar_size_policy.gd -->
## Configurable avatar file sizes

`limits` reads bounded warning/hard MiB settings, defaults to 256/1024 and clamps
warning to hard. `classify` distinguishes invalid, blocked, warn and allow at
inclusive byte boundaries. `store_for` resolves the client settings owner.
`file_size` returns readable file length or zero; `file_identity` and
`buffer_identity` compute content SHA-256 for session-only confirmation reuse.
`confirm` rejects invalid/over-limit/headless warning requests, otherwise awaits a
cancelable large-model dialog. Pending confirmations coalesce by content/size/
warning and teardown completes them as canceled. Approvals are bounded in-memory
only; hard limits are checked before reuse. This is not rig/format validation or a
decoded GPU/RAM budget. File hashing remains synchronous and can take time for
very large local models; worker model import remains separate.

Reviewed additions complement [function contracts](functions.md). They describe
current implementation limits, not proposed editor/world APIs.

<!-- module: scripts/GUI/gui_warmup.gd -->
## GUI warmup

`start` schedules one client-only warmup per process, skipping headless/server
runs. Private callbacks use threaded loading and a short offscreen render of the
shipped preview. `pipeline_compilations` totals rendering counters for diagnostics,
not an FPS metric or a guarantee for arbitrary downloaded avatar shaders.

<!-- module: scripts/GUI/text_block.gd -->
## Deferred read-only text

`is_shaped` reports a current shaped paragraph. Private callbacks defer shaping
while hidden, cache width/font-dependent glyph commands, invalidate on text/theme/
size changes and free the private canvas RID at teardown. Plain display text only,
not editable input, script execution or a remote-markup renderer.

<!-- module: scripts/GUI/map_editor.gd -->
## Local project editor UI

Ready builds direct-IP host/join/access controls, entity translation fields and
project text/file actions. It delegates validation, save/export and authenticated
editing to services; account changes close the panel. No public function API is
exposed. Rotation/scale authoring and production playtest launch are not implied.

<!-- module: scripts/editor/edit_authority.gd -->
## Edit authority

`configure` copies the document and initializes owner/session roles and replay IDs.
`admit` and `revoke` are owner-only access changes. `submit` enforces editor role,
generation, unique operation ID and bounded operation history before applying a
validated command. `snapshot` returns a document copy only to admitted members.

<!-- module: scripts/editor/edit_commands.gd -->
## Editor commands

`apply_operation` validates the source project, exact revision and set_transform
translation operation, edits a copy, validates it and returns document/inverse or
error. `undo_operation` applies the revision-bound inverse through the same path;
it is not unrestricted snapshot replacement or general rotation/scale support.

<!-- module: scripts/editor/edit_leases.gd -->
## Editor leases

`acquire` expires old entries and grants one bounded-duration entity/session lease
to a member subject to inventory limits. `release` requires its owning member.
`disconnect_member` clears that member's leases; `expire` removes elapsed leases.
State is transient and does not authorize edits independently of edit authority.

<!-- module: scripts/editor/edit_session.gd -->
## Direct editing session

`host` starts opt-in ENet editing with owner identity/document. `join` requests
access to an independently verified owner fingerprint. `approve` admits editor or
viewer; `revoke` removes access. `move_entity` submits revisioned translation through
authority. `close` disconnects and clears transport/session state. The private
protocol authenticates keys and bounds messages; it is separate from gameplay
relay packets and does not supply durable offline collaboration or public hosting.

<!-- module: scripts/editor/editor_input.gd -->
## Editor input adapter

`transform_operation` rejects blocked input, unsupported modes, invalid/oversized
vectors, nonpositive scale and nonidentity rotation/scale edits. A valid desktop/VR
translation returns copied operation data; it does not mutate a live node or grant
permission. The initial authoring schema is translation-only.

<!-- module: scripts/editor/editor_playtest.gd -->
## Editor playtest preparation

`prepare` accepts desktop/VR mode, exports a safe package and retains a document
copy under a random token; launch_supported remains false. `restore` consumes the
token once and returns the isolated original document. This primitive is not an
implemented production client launcher or persistent progress migration.

<!-- module: scripts/editor/project_store.gd -->
## Editor project storage

`save_project` delegates validated atomic authoring-document save. `load_project`
delegates validated loading; `recover_project` loads the last committed project,
never prefers an uncommitted temporary file. Authorization to save/export stays
with the caller/editor owner; storage is not a gameplay relay persistence service.

<!-- module: scripts/player/avatar_resize.gd -->
## Capsule-safe avatar resize

`apply` requires a finite positive ratio and capsule collision shape, constructs
new dimensions in height-before-radius order, preserves the feet and probes the
final world volume excluding the local body. Collision failure leaves shape and
center unchanged. It does not alter tracked headset poses or guarantee rig fit.

<!-- module: scripts/assets/avatar_rig_profile.gd -->
## Avatar rest-frame preparation

`prepare` finds the skeleton, resolves declared bone names or unique imported
numeric suffixes, rejects ambiguous/duplicate roles and stores resolved mapping,
rest frame and diagnostics. Traversal operates on detached model transforms and
does not touch SceneTree, global import registration or live tracking targets.

<!-- module: scripts/worlds/world_local_store.gd -->
## Local world progress

`configure` scopes data by hashed account/world URL, optionally memory-only, and
loads bounded JSON; invalid originals remain read-only. `commit` validates entry,
byte/depth limits, rate-limits disk writes, atomically replaces a temporary file
and updates state only on success. Scripts cannot choose arbitrary save namespaces.

<!-- module: scripts/worlds/world_menu.gd -->
## World menu renderer

`build` renders reviewed declarative text/button/progress/list widgets for an owner
runtime; it never instantiates provider-selected classes/scripts. `refresh` reads
runtime bindings into those widgets. Actions dispatch through the owner runtime's
validated event/command pipeline. Close releases the menu's local input ownership.

<!-- module: scripts/worlds/world_static_mesh.gd -->
## Data-only static mesh

`valid` checks exact allowed fields, triangle counts, finite bounded vertices/
normals/UVs and integer in-range indices. `build` revalidates then creates an
ArrayMesh with normalized supplied normals and optional UVs, or null. No external
resource paths, scripts, animation skins or arbitrary engine resource loading.

<!-- module: scripts/worlds/world_ui_schema.gd -->
## Declarative world UI schema

`validate` bounds version/pages/widget count, known widget types and metadata,
unique widget IDs, bindings, progress maximum and button target entities. Button
actions are checked through the restricted VM with the declared capability set.
Success is schema acceptance, not permission to execute native Godot callbacks.
