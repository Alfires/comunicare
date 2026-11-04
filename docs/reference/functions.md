# Production function contracts

This reference explains every named public function in production `scripts/` and
`relay_protocol/`. Exact parameter types, defaults, return annotations and source
locations are in the [declaration inventory](symbols.json). A module heading links
the authoritative implementation. Private functions and engine callbacks are
indexed there and grouped by lifecycle/algorithm below; they are not an invitation
to bypass public validation or ownership checks. Signals are synchronous Godot
notifications unless their caller explicitly defers them.

**Calling convention:** Node/UI/transport APIs run on the main thread in an active
SceneTree unless explicitly described as pure or worker-only. RefCounted crypto,
validation and parsing helpers need no tree. “Await” means callers must await
completion before using the result; never attach the same returned model twice.
Methods with no explicit return annotation may still return a useful value—use
the contract and code, not an inferred `void`. Failure sentinels do not guarantee
`last_error` is populated on every branch. Function contracts describe current
code, including its limits, rather than promises from old roadmaps.

## Startup and settings

<!-- module: scripts/startup/main.gd -->
### [Startup main](../../scripts/startup/main.gd)

Owner: startup scene. `_ready` selects dedicated relay or account/authentication
client flow. Failure does not regenerate a corrupt account. Player survives world
scene changes under root; do not automate this flow against real user storage.

| Functions | Contract |
| --- | --- |
| `load_initial_scene` | Creates the local player then requests built-in world scene change; deferred startup caller owns order. Not a multiplayer admission shortcut. |
| `instantiate_player` | Loads the supplied scene and stores an instantiated player; trusted internal scene path required. Does not attach it itself. |
| `load_player` | Attempts XR unless forced desktop, configures viewport/vsync, selects supported player scene and defers root attachment. Requires engine XR services/display; no headless hardware guarantee. |

<!-- module: scripts/settings/save_data.gd -->
### [SaveData](../../scripts/settings/save_data.gd)

Owner: autoload. `_init` creates registry/store/voice/profile services; `_ready`
loads settings before capture, except relay mode. Setting application updates
legacy values/audio buses. Close/predelete saves dirty settings and frees detached
owned nodes. Profile-change adapter mirrors only the local account's public fields.

| Functions | Contract |
| --- | --- |
| `create_acount` | Generates RSA private key and writes configured key path; bool success/account_error. Call only when creating a genuinely new account, not on corrupt-key recovery. |
| `load_acount` | Reads existing private key or creates only if absent; initializes profile on success, returns bool. Corrupt/public-only key fails without replacing it. |
| `initialize_profile` | Configures owner-keyed profile/contact stores, migrates initial profile if absent, connects avatar config when attached, emits account_ready. Optional path is for isolated adapters; filesystem writes are client-owned. |
| `save_data` | Compatibility wrapper saves mirrored profile fields through ownership service then settings; false if either fails. Do not use to edit another account. |
| `laod_data` | Loads/migrates typed settings and legacy profile/world sources; returns store outcome and preserves compatibility spelling. Does not establish account-key ownership. |

<!-- module: scripts/settings/settings_registry.gd -->
### [SettingsRegistry](../../scripts/settings/settings_registry.gd)

RefCounted definitions owner. Validation is pure; mutations emit definitions_changed.

| Functions | Contract |
| --- | --- |
| `register_setting` | Validates definition, range/default and unique ID; deep-copies on success and emits change; bool false leaves registry unchanged. |
| `unregister_setting` | Removes an existing ID and emits change only if removed; dependent store/UI reconcile via subscriptions. |
| `get_definitions` | Returns deep-copied definitions sorted by category/order; caller changes are not registry mutations. |
| `get_definition` | Returns copied definition or empty dictionary for unknown ID. |
| `validate` | Tests a value against boolean/number/text/enum/key rules; no writes; invalid/unknown types fail. URL syntax validation is not trust validation. |
| `register_defaults` | Registers production defaults through normal validation; do not call repeatedly expecting duplicate replacement. |

<!-- module: scripts/settings/settings_store.gd -->
### [SettingsStore](../../scripts/settings/settings_store.gd)

Node owned by SaveData. Private reconciliation follows registry changes. `_process`
debounces dirty saves by 400 ms; failed write does not retry every frame. Exit
saves when allowed; predelete disconnects registry. See [format](storage-formats.md).

| Functions | Contract |
| --- | --- |
| `configure` | Switches registry/path, disconnects old definitions subscription, resets values to registered defaults. Does not load disk. |
| `get_value` | Returns stored value or null for missing ID; caller validates registry presence. |
| `set_value` | Rejects unknown/invalid input; unchanged value succeeds without duplicate signal. Valid change marks dirty, schedules save, emits setting_changed; not immediate durability. |
| `reset_value`, `reset_category` | Restore registered defaults through set_value, including its validation/debounce/signals. Unknown ID/category is harmless. |
| `load_settings` | Reads versioned ConfigFile; invalid individual values fall back to defaults. Corrupt/future store blocks writes and reports persistence_error. bool outcome; no automatic destructive reset. |
| `save_settings` | Writes registered persistent values via temp/rename, preserving unrelated sections. Refuses blocked/corrupt originals; emits saved on success, persistence_error on failure. |

## Voice and player nodes

<!-- module: scripts/player/vr_safety.gd -->
### [VRSafety](../../scripts/player/vr_safety.gd)

RefCounted physics policy requiring attached body/world. `clearance` tests bounded
capsule at a floor destination excluding self; `resize_capsule` permits shrink but
rejects ceiling-obstructed growth. `head_obstructed` queries a small head sphere
for protective overlay. `destination` validates finite short ray, walkable normal,
height difference and capsule space. `commit_teleport` moves body/origin around
head floor pivot and clears velocity, never rewriting local tracked pose. Caller
must revalidate clearance immediately before commit and cancel on focus/UI loss.

<!-- module: scripts/player/vr_room_scale.gd -->
### [VRRoomScale](../../scripts/player/vr_room_scale.gd)

RefCounted physical walking reconciliation. `reconcile` takes attached body/origin/
head nodes, collision-moves capsule toward horizontal headset displacement (bounded
to .5 m per call), restores origin world transform so physical head pose stays
unchanged, and returns actual body displacement. Repeated stationary input is
idempotent. Collision cannot stop real-world walking; callers still need boundary/
head-clipping feedback and ceiling-safe capsule policy. No camera recenter/teleport.

<!-- module: scripts/player/vr_locomotion.gd -->
### [VRLocomotion](../../scripts/player/vr_locomotion.gd)

RefCounted planar movement policy, no scene/network/storage writes. `desired_velocity`
accepts unitless stick/head basis/speed/dead zone and returns bounded horizontal
velocity. Retains last valid projected yaw for near-vertical gaze; rejects nonfinite
input and applies speed once. Caller owns gravity, collision and focus suppression.

<!-- module: scripts/player/vr_turn_controller.gd -->
### [VRTurnController](../../scripts/player/vr_turn_controller.gd)

RefCounted turn state. `step` returns delta yaw for snap/smooth mode; snap requires
neutral rearm and smooth integrates delta once. `reset` clears snap latch;
`pivot_transform` rotates rig about world floor pivot without moving that pivot.
Caller blocks input/menu/focus and preserves headset-local tracking.

<!-- module: scripts/player/vr_input_router.gd -->
### [VRInputRouter](../../scripts/player/vr_input_router.gd)

RefCounted edge ownership. `menu_toggle` coalesces either/both lower face buttons
and suppression into one rising intent; suppressed held presses remain latched
until release. `reset` clears history on explicit lifecycle reset. No hardware,
UI construction, persistence or networking; caller maps current OpenXR actions.

<!-- module: scripts/player/vr_comfort.gd -->
### [VRComfort](../../scripts/player/vr_comfort.gd)

RefCounted bounded vignette policy. `update_vignette` fades strength from movement/
turn rate and delta when enabled; disabled returns clear immediately. `reset`
clears overlay state on lifecycle transitions. The VR player renders its shader;
this policy never alters camera pose or guarantees motion-sickness prevention.

<!-- module: scripts/GUI/vr_pointer_router.gd -->
### [VRPointerRouter](../../scripts/GUI/vr_pointer_router.gd)

RefCounted capture queue. `hover` updates per-hand valid pixel hit. `press` emits
one owned down only for valid unowned target; `release` emits up even after drag-off.
`cancel` emits outstanding release once and clears hits; `drain_events` transfers
pending event dictionaries to caller. Player injects them into the shared viewport;
this helper does not synthesize gameplay or touch global capture/settings.

<!-- module: scripts/player/voice_controller.gd -->
### [VoiceController](../../scripts/player/voice_controller.gd)

SaveData-owned shared input/mute authority. `_input` suppresses shortcuts during
typing/modal/rebinding/IME. Relay mode disables input processing. No independent
UI/player mute flag should replace this service.

| Functions | Contract |
| --- | --- |
| `configure` | Binds store signals, applies saved mute and input bindings; disconnects previous store. Requires valid typed settings. |
| `is_muted` | Reads store or fallback; pure state query. |
| `set_muted`, `toggle_muted` | Updates persistent setting or fallback; capture receives mute and emits mute_changed. Muting clears capture backlog through its owner. |
| `register_capture` | Claims one active capture and immediately applies mute; false if a different live capture already owns it. |
| `unregister_capture` | Releases only matching capture and reports unavailable; does not unregister another node. |
| `set_availability` | Updates availability text and emits notification; not proof that audio packets are flowing. |
| `binding_text` | Returns current microphone InputMap label or Unbound; display only. |
| `handle_toggle_input` | Handles initial bound key press only when not suppressed; returns whether consumed and toggles shared mute. Caller marks viewport handled. |

<!-- module: scripts/player/audio_microphone.gd -->
### [Audio capture](../../scripts/player/audio_microphone.gd)

Player-owned capture Node. Ready registers with shared voice owner, builds capture
only when usable/unmuted; process handles threshold/gain/packet bounds and session
guards. Exit releases only its own effect/stream and registration. Physical device
availability is outside headless packet tests.

| Functions | Contract |
| --- | --- |
| `is_muted` | Queries shared voice mute when available, otherwise safe local fallback. |
| `set_muted` | Applies capture state, clears queued samples on mute and starts only eligible capture on unmute; never replays old samples. Called by voice owner. |

<!-- module: scripts/player/player_desktop_movment.gd -->
### [Desktop player](../../scripts/player/player_desktop_movment.gd)

Root-owned CharacterBody; ready subscribes profile/config and loads avatar.
Physics handles input/collision; process sends position. Mouse input owns camera
pitch/yaw; animation never parents camera to a bone. Generation checks reject
stale loads. Camera forward clearance and rest-eye calibration are local only.

| Functions | Contract |
| --- | --- |
| `update_player_data` | Sends current transform only with connected acknowledged session and no transition; does not grant membership. |
| `set_player_pos` | Sets local body position, used after world activation; caller provides valid spawn. |
| `load_player_model` | Awaited profile/config model acquisition; skips unchanged key, protects latest generation and swaps only successful result. Attaches local first-person view, calibrates camera from rest geometry. |

<!-- module: scripts/player/player_vr.gd -->
### [VR player](../../scripts/player/player_vr.gd)

Root-owned CharacterBody; XR origin/camera/controllers remain player-owned. Input
opens hand-local wheel and suppresses conflicting movement. Model load binds final
head/arm modifier; no networked live-tracker protocol is implied. Invalid/stale
model does not replace working avatar. Hardware checks are manual.

| Functions | Contract |
| --- | --- |
| `set_player_pos` | Moves body to spawn and clears velocity. Does not overwrite headset tracking pose. |
| `update_player_data` | Sends eligible session body transform, not head/controller poses. |
| `load_vrm_model` | Awaited config/profile import, generation/skeleton checks, model swap/first-person setup and local tracking configuration; camera remains under XROrigin. |
| `get_bone_by_array` | Returns first existing candidate name or empty string; helper for legacy naming, not a substitute for validated humanoid metadata. |

<!-- module: scripts/player/remote_player.gd -->
### [Remote player](../../scripts/player/remote_player.gd)

Instance-scoped CharacterBody with spatial voice playback. Ready loads fallback;
setting callbacks update nameplate visibility. Exit invalidates pending avatar and
disconnects store signal. Audio helper feeds only its generator, not microphone.

| Functions | Contract |
| --- | --- |
| `load_player_model` | Await URL model, keep old avatar on failure, discard stale/detached completion, attach independent tree and update label. Never reuse a live model node across peers. |

## Assets, rendering and emotes

<!-- module: scripts/startup/data_loader.gd -->
### [DataLoader](../../scripts/startup/data_loader.gd)

Stable autoload. Camera-added callback excludes local derivative layer for other
cameras. Avatar/animation workers are serialized, bounded and joined without
blocking frame progress; shutdown alone may join remaining work. Worker functions
must not access active SceneTree or globally register request-local extensions.

| Functions | Contract |
| --- | --- |
| `get_avatar_configuration` | Lazily creates child config and reconfigures for current fingerprint; returns owned service, not caller-owned node. May initiate async restore. |
| `get_asset_cache` | Lazily creates stable cache, connects settings/revision notifications; returns service, not an asset handle. Relay initialization still refuses persistence. |
| `load_vrm_from_url` | Await validated cache fetch and detached import; returns model/null. Success carries lease/revision/source metadata; caller attaches/frees on main thread. Force bypasses HTTP validators. |
| `read_animation` | Await bounded worker parsing of file or byte buffer (empty path selects bytes); returns parsed dictionary or `{}`, sets animation_import_error. |
| `refresh_loaded_assets` | Await forced checks for live avatar sources, active world and configured sources; source notifications can rebind, world refresh does not hot-swap scene. |
| `load_world_from_url` | Convenience await prepare then activate; bool. Multiplayer code must use coordinator admission rather than bypass it through this wrapper. |
| `prepare_world_from_url` | Await built-in or trusted remote exact revision preparation; returns staged scene/spawn/handles or `{}`. Refuses trust/revision mismatch; pins bytes. Does not activate or host. |
| `built_in_world_revision` | Returns hash of built-in scene file; not its complete transitive dependency graph. |
| `load_world` | Local archive convenience prepare/activate with timestamped extraction; bool; trusted caller controls path. |
| `prepare_world` | Extracts bounded archive then validates manifest/PackedScene/spawn; returns staging dictionary or `{}`. Loading executable resources is not sandboxed. |
| `activate_world` | Await PackedScene transition, retain active handles and move player group to spawn; bool failure on invalid scene/change. Use after acknowledged transition. |
| `extract_zip` | Extracts relative safe entries with count/total-byte ceilings; bool false on unsafe path/read/write failure. Partial managed extraction may need caller cleanup. |
| `load_manifest` | Parses file JSON object or `{}` with diagnostic; not independently full world validation. |
| `create_directories_recursive` | Creates missing parent path; internal trusted path only, not a permission boundary. |

Private groups: source refresh and validators await importer/cache; `_import_avatar`
owns waiters/thread; `_build_avatar` constructs detached tree, humanoid mappings
and first-person derivatives; world extraction validators own staging cleanup.
TemporaryWorld destructor releases only its managed transient extraction.

<!-- module: scripts/assets/asset_cache.gd -->
### [AssetCache](../../scripts/assets/asset_cache.gd)

Client-only Node; index schema 1. Main-thread callers may await fetch/import.
Private fetch pipeline coalesces jobs, checks validators/cache policy, promotes
immutable bytes then index; failure preserves old verified revision with backoff.
Managed cleanup never follows symlinks or deletes external source originals.

| Functions | Contract |
| --- | --- |
| `initialize` | Sets root once, creates managed dirs, validates index, cleans managed staging; bool. Relay mode disabled; corrupt/future index becomes read-only, preserved. |
| `valid_hash` | Pure lowercase 64-hex validation, false otherwise. |
| `blob_path`, `world_path` | Derive managed revision path or empty for invalid hash; do not validate file existence. |
| `revision_handle` | Verifies cached hash and returns path/hash/lease/stale or `{}`; caller must retain lease. |
| `pin_revision` | Persistently pins matching records; bool false if unavailable/unwritable/save failure. |
| `remove_revision` | Rejects active leases/jobs, removes matching records and unreferenced managed bytes/derivatives, saves index; bool. Never deletes external originals. |
| `retain`, `release` | Increment revision lease count / decrement one count; retain returns RefCounted lease whose destructor releases automatically. Do not manually double-release a lease. |
| `fetch` | Await permitted URL/kind/validator, bounded/coalesced request; returns handle or `{}`. Handle may be stale or temporary/no-store. Validation must establish format safety before publication. |
| `import_file` | Await copy/validator/hash promotion; returns managed handle or `{}`. Pin defaults true, receiver cache can opt out; permissions are not inferred from successful import. |
| `usage_bytes` | Measures managed bytes including derived/staging; no mutation. |
| `clear_unused` | Removes unpinned/unleased records and orphan blobs when no jobs; saves index and emits status. bool false on unsafe/unwritable state. |

Private groups: `_usable` checks bytes/size; `_make_room` performs protected LRU;
`_save` temp-renames index; `_fallback` records bounded retry; `_headers` normalizes
HTTP fields; `_allowed_url` syntax is not DNS destination-policy sandboxing. Lease
and TemporaryFile destructors are indexed in the declaration inventory.

<!-- module: scripts/assets/avatar_configuration.gd -->
### [AvatarConfiguration](../../scripts/assets/avatar_configuration.gd)

Client account-owned Node. Applied JSON is separate from signed public profile.
Private restore rebuilds role catalog from managed bytes with generation guards;
source-update queue serializes revision replacements. Corrupt config blocks writes.

| Functions | Contract |
| --- | --- |
| `configure` | Switches account/path/loader, clears drafts/catalog, loads matching schema then starts restore; emits changed. No caller ownership of the returned child services. |
| `role_for` | Pure normalized canonical movement-name matching; returns role or empty for emote/nonrole. |
| `import_source` | Await kind-specific file/URL validation and managed handle; returns source descriptor or `{}`. Does not equip; no-store cannot persist, account changes invalidate completion. |
| `apply` | Await full candidate source/model checks, ownership-generation guard, temp/rename save and catalog restore; bool. Custom models require redistribution permission. Failed candidate keeps old applied selection. |
| `model_key` | Returns cache revision key or fallback URL for load deduplication; no I/O. |
| `load_model` | Await cached configured import or fallback URL; returns detached model/null with lease. Missing configured bytes reports error and attempts fallback. |

<!-- module: scripts/assets/humanoid_animation.gd -->
### [HumanoidAnimation](../../scripts/assets/humanoid_animation.gd)

RefCounted data parser; worker-safe when isolated. No scene/script/callback resource
loading. Private accessors enforce finite values/count/stride/bounds; rest hierarchy
conversion rejects cycles/matrices. See supported subset, not full VRMA claims.

| Functions | Contract |
| --- | --- |
| `read_file` | Reads bounded self-contained GLB/VRMA bytes and returns canonical clip set or `{}`/last_error; no active tree needed. |
| `document` | Validates binary GLB chunks/JSON and rejects external buffer/image URIs; returns json/binary or `{}`. Caller supplies maximum bytes. |
| `humanoid_nodes` | Extracts VRM Animation/VRM 1.0/legacy humanoid node map; missing mappings return empty. Not arbitrary bone-name guessing. |
| `read_bytes` | Parses supported rotation channels to named clips/time/quaternion/rest-basis data with SHA-256; rejects unsupported interpolation/translation/gaze/sparse tracks. No animations are executed. |
| `bind_clip` | Main-thread avatar binding to a Skeleton3D using humanoid metadata/rest-axis conversion; returns Animation/null. Rejects required missing bones, skips explicit optional channels; legacy VRM orientation correction applies to builtin data. |

<!-- module: scripts/assets/default_animations.gd -->
### [DefaultAnimations](../../scripts/assets/default_animations.gd)

| Functions | Contract |
| --- | --- |
| `clip` | Loads/caches authored bundled JSON and returns canonical clip dictionary or `{}`. Treat returned shared data as read-only; duplicate before masking/composition. Static standing combines reference legs with relaxed authored upper body; library version is wire compatibility, not app version. |

<!-- module: scripts/assets/avatar_animator.gd -->
### [AvatarAnimator](../../scripts/assets/avatar_animator.gd)

Avatar-owned Node. Private mixer-applied pass smoothsteps captured visible owned
bone rotations into evaluated target over .22 s; interrupted transitions recapture
the visible pose. Unused previously owned channels return to rest, not camera/IK
authority. Shared local/remote renderer; it is not a separate network player.

| Functions | Contract |
| --- | --- |
| `attach` | Creates dedicated AnimationPlayer/root/reset library on supplied model; call once per animator. Caller attaches animator/model on main thread. |
| `play_clip` | Binds validated clip, preserves visible pose for transition, installs bounded current/reset libraries, seeks requested phase and starts; bool with last_error on binding failure. Does not move camera/body. |
| `stop` | Clears fade, applies owned RESET, stops and clears descriptor; immediate lifecycle reset, not an emote network command. |
| `set_paused` | Internal renderer pause/resume primitive; not exposed as manual protocol/UI control. Requires attached player. |

<!-- module: scripts/assets/animation_controller.gd -->
### [AnimationController](../../scripts/assets/animation_controller.gd)

DataLoader-hosted service created/recovered by production coordinator factory.
Process owns local state evaluation, transport replacement, clock/snapshot ticks,
transfer fairness limits and expiry. Generation/session/sequence/revision checks
reject stale remote work; clear on membership transitions. Remote live tracker
poses are not included in this protocol.

| Functions | Contract |
| --- | --- |
| `configure` | Binds network/loader and applied avatar config; requires main-tree collaborators. No ownership transfer. |
| `now` | Returns local monotonic milliseconds plus estimated relay offset; not wall-clock time. |
| `resolve_motion` | Pure role choice from grounded/local-space velocity: static neutral, forward walk/run, left/right strafe, upward jump; no fall/landing playback. |
| `tracking_mask` | Returns copied clip excluding tracked head/eye/jaw/hand channels, preserving untracked limbs/torso. Does not itself perform IK. |
| `strafe_pose` | Returns copied lateral legs combined with exact unrotated forward-walk upper-body motion; no procedural replacement keys. |
| `emote_catalog` | Returns applied compatible action entries plus cancel intent when configured; builtin fallback otherwise. Catalog browsing does not send packets. |
| `request_emote` | Validates action/permission, applies through sole renderer/resolved state; bool and last_error. Movement/replacement/completion interrupts via state machine. |
| `cancel_emote` | Clears intent and schedules automatic reevaluation; does not send legacy Stop. |
| `toggle_emote_menu` | Opens/closes shared desktop/XR picker; safely declines detached service. Factory must restore attachment. Owns overlay lifetime and mouse/focus restoration. |
| `open_xr_menu` | Opens stable hand-local wheel from valid tracked nodes; detached/invalid calls ignored. Hardware comfort is not proven by headless geometry. |
| `receive` | Dispatches authenticated transport data after own schema/scope checks; updates clock/current state or request-bound buffers. Never trust as public arbitrary actor-command interface. |
| `clear` | Drops session descriptors, queues/assets, motion intent, wheel and clock state; resets local renderer. Does not erase persistent library or user layout. |

Private groups: `_apply_resolved` composes masks/metadata; `_play_resolved` owns
local render state; `_apply_remote` loads exact model/clip then seeks/blends;
typed chunk handlers verify final bytes before importer; departure removes pairwise
references. Input handler suppresses repeat/typing/modal/IME and marks consumed keys.

<!-- module: scripts/assets/emote_layout.gd -->
### [EmoteLayout](../../scripts/assets/emote_layout.gd)

RefCounted account-local graph; no network calls. Limits: 32 groups, four levels
below root, 1,024 entries. Private traversal rejects cycles even in unreachable
components; corrupt load keeps original read-only with defaults.

| Functions | Contract |
| --- | --- |
| `defaults` | Returns fresh root/Dances and builtin/cancel shortcuts; no disk writes. |
| `configure` | Sets JSON path and loads/validates or uses defaults; bad original preserved. |
| `valid` | Pure full graph/type/depth/bounds validation; false on dangling/cyclic links. |
| `commit` | Validates candidate, temp/renames if persistent, deep-copies on success; bool. Empty path supports memory-only fixtures. |
| `add_group` | Creates random stable ID and parent shortcut; returns ID or empty if validation/save fails. |
| `rename_group` | Updates title and incoming shortcut names atomically through commit; bool. |
| `delete_group` | Refuses root, removes target and incoming references; bool. Caller must confirm nonempty deletion; source files are untouched. |
| `add_emote` | Adds named stable action reference to group, validates/persists; bool. Compatibility is checked by picker/catalog, not just this string operation. |
| `move_entry` | Moves one entry across/within groups with clamped position and cycle revalidation; bool; no partial graph mutation. |
| `remove_entry` | Deletes shortcut at valid index and commits; bool; not source deletion. |
| `page_count` | Returns one for 0..8 entries, otherwise ceil(count/5); pure query. |
| `sectors` | Returns eight copied visible entries including fixed lower paging sectors when needed; indicator/empty disabled. Does not play or navigate itself. |

<!-- module: scripts/assets/first_person_avatar.gd -->
### [FirstPersonAvatar](../../scripts/assets/first_person_avatar.gd)

Pure import preparation plus main-thread camera activation; never shares a live
model across avatars. Current policy deliberately excludes camera-interior torso
as well as head. Original geometry stays intact for other cameras/shadows.

| Functions | Contract |
| --- | --- |
| `is_camera_interior_bone` | Pure role membership for hips/spine/chest/neck/head/eyes/jaw filtering. |
| `prepare` | Detached worker-safe derivative construction from annotations/skin weights; idempotent. Returns whether view was prepared/changed; missing humanoid rig can fail. Unknown geometry filtering is heuristic, not universal visual correctness. |
| `apply` | Marks local camera, changes cull/layer visibility on already prepared representation; bool false if not prepared. No runtime mesh cutting. |
| `configure_camera` | Excludes local derivative layer from added non-first-person cameras; callers intentionally selecting special layers must coordinate with this policy. |

Private BlendShapeSync process copies transform/material override/expression values
from original to derivative; original remains expression target and shadow caster.

<!-- module: scripts/assets/avatar_tracking.gd -->
### [AvatarTracking](../../scripts/assets/avatar_tracking.gd)

| Functions | Contract |
| --- | --- |
| `configure` | Main-thread binds humanoid map and independent head/hand target nodes, caching rest calibration. Must be child of skeleton before use. No camera transform mutation. |
| `set_calibration` | Validates bounded finite local head/grip translation offsets; invalid entries ignored. Does not move headset/controllers. |
| `set_tracking_validity` | Sets role validity booleans or timestamped validity records; aged/invalid targets stop overriding base pose. |
| `tracking_weights` | Returns current per-chain blend weights as a copy. Temporary validity loss fades last solved pose toward animation over .2 s; reacquisition fades toward fresh target. Hard target removal releases ownership immediately. |
| `set_body_targets` | Supplies optional pelvis/feet Transform3D targets in skeleton space; final modifier solves valid subset before head/arms. |

SkeletonModifier `_process_modification` runs final head alignment and two-bone arm
reach solve for active targets only. Private rotations convert target world poses
to skeleton/parent space; unreachable targets clamp to limb reach. Untracked
channels retain animation. Physical controller orientation and proportions still
need calibration; not a full-body or remote tracker solution.

## Accounts and social services

<!-- module: scripts/assets/humanoid_rig_adapter.gd -->
### [HumanoidRigAdapter](../../scripts/assets/humanoid_rig_adapter.gd)

RefCounted validation helper. `validate_mapping` returns valid/errors for required
roles, duplicate assignments, ancestry, zero-length chains and nonfinite rest poses.
No skeleton mutation, storage or tracking discovery; report can contain partial
unsupported chains and does not prove anatomical/joint-limit quality.

<!-- module: scripts/assets/tracking_calibration.gd -->
### [TrackingCalibration](../../scripts/assets/tracking_calibration.gd)

RefCounted account/avatar-scoped persistence. `configure` binds path/owner/revision;
`load_calibration` returns validated schema/finite bounded height/scale/head/grip
offsets or empty and blocks corrupt/incompatible replacement. `save_calibration`
temp-renames valid candidate only when owner/store usable. No raw hardware IDs or
pose history. Scope checks are integrity isolation, not cryptographic signatures.

<!-- module: scripts/assets/tracker_role_provider.gd -->
### [TrackerRoleProvider](../../scripts/assets/tracker_role_provider.gd)

RefCounted transient sample adapter. `update_sample` accepts finite timestamped
validity/pose per ephemeral ID, ignores older samples. `assign` validates supported
role/existing valid device and prevents one device on two roles. `available` lists
fresh runtime sample IDs; `unassign` clears a role without deleting the sample.
`targets` returns
fresh assigned transforms within one second; `clear` drops samples/assignments.
This adapter does not discover hardware or claim every runtime exposes FBT.

<!-- module: scripts/assets/full_body_solver.gd -->
### [FullBodySolver](../../scripts/assets/full_body_solver.gd)

RefCounted optional pelvis/feet target solver. `configure` binds skeleton/map;
`solve` accepts finite skeleton-space role transforms and positive delta, sets
bounded pelvis pose and solves reachable two-bone legs/foot orientation. Missing
roles leave base animation intact; no camera writes or tracker discovery.
No foot-planting/ground collision or complete joint-limit calibration is implied.

<!-- module: scripts/profile/profile_identity.gd -->
### [ProfileIdentity](../../scripts/profile/profile_identity.gd)

Pure RefCounted helpers; no persistence/tree. Fixed serialization and canonical
keys are protocol contracts. Signature verification is not content-host trust.

| Functions | Contract |
| --- | --- |
| `digest` | SHA-256 bytes of supplied bytes; returns PackedByteArray. |
| `canonical_key` | Parses bounded PUBLIC KEY PEM and returns canonical public serialization or empty; rejects private/invalid text. |
| `fingerprint` | SHA-256 lowercase hex of canonical public key, empty if invalid. |
| `defaults` | Fresh four-field public profile defaults, not account identity. |
| `valid_url` | Bounded HTTP(S) syntax/control/credential checks, optional empty; no DNS/private-network sandbox. |
| `normalized` | Returns validated/trimmed four-field copy or `{}`; rejects missing/invalid fields. Does not sign or persist. |
| `signed_bytes` | Fixed ordered domain/version/public-key/revision/field array serialization; exact bytes are signed, independent of dictionary ordering. |
| `verify_profile` | Validates exact normalization, canonical key, bounded revision/signature and crypto; bool; no mutation or trust grant beyond signer identity. |

<!-- module: scripts/profile/identity_authenticator.gd -->
### [IdentityAuthenticator](../../scripts/profile/identity_authenticator.gd)

Relay-owned RefCounted transient challenge/identity maps. No disk writes. Private
challenge consumption/expiry binds proof to peer and prevents replay.

| Functions | Contract |
| --- | --- |
| `issue_challenge` | Validates public key/current connection constraints, stores bounded expiring challenge; returns bytes or empty. Peer ID is transport-derived. |
| `verify_response` | Consumes/checks pending signature proof and duplicate account constraints; bool; failed/expired/replayed proof does not authenticate. |
| `get_identity` | Returns authenticated identity for peer or empty; internal caller must not manufacture verified keys. |
| `expire_challenges` | Removes timed-out challenges; caller ticks relay lifecycle. |
| `disconnect_peer` | Erases peer challenge and identity references, no reconnect history. |

<!-- module: scripts/profile/profile_service.gd -->
### [ProfileService](../../scripts/profile/profile_service.gd)

SaveData-owned RefCounted local signed profile plus transient remote map.
Private signing uses configured private key; public remote cache does not grant
edit rights. Persistence uses temporary ConfigFile/rename with owner/signature checks.

| Functions | Contract |
| --- | --- |
| `configure` | Sets key/path, initializes signed defaults and clears remote/revision maps; does not adopt disk until load_profile. |
| `get_local_fingerprint` | Returns local canonical owner fingerprint or empty. |
| `can_edit` | True only for nonempty matching owner and private key; instance role irrelevant. |
| `get_profile` | Deep copy of local/remote profile or `{}`; never private key. |
| `save_profile` | Validates complete fields/owner, increments/signs revision, refuses corrupt/unrelated original, writes then emits profile_changed; bool/last_error. |
| `load_profile` | Missing file succeeds with defaults; existing matching verified profile adopted, invalid original preserved; bool. |
| `cache_remote_profile` | Internal adapter for already session/signature-validated input; returns fingerprint or empty. Does not independently establish relay membership/signature. |
| `replace_remote_profiles` | Verifies signed array, rejects revision rollback, replaces rather than merges current-session map and emits notification. Caller enforces active session. |
| `clear_remote_profiles` | Drops remote and seen-revision maps, emits remote_profiles_changed; no local profile deletion. |

<!-- module: scripts/profile/profile_media.gd -->
### [ProfileMedia](../../scripts/profile/profile_media.gd)

UI-owned Node; bounded asynchronous image requests and generation guards. External
media reveals client address to host; caller must respect user/request consent.

| Functions | Contract |
| --- | --- |
| `request_icon` | Starts bounded source acquisition/decoding and emits icon_ready or failed; empty uses fallback. New requests supersede old generations. |
| `cancel` | Invalidates pending result/request; no profile mutation. |
| `texture_from_bytes` | Decodes supported bounded image bytes to texture/null; not arbitrary scene loading. |

<!-- module: scripts/profile/friend_service.gd -->
### [FriendService](../../scripts/profile/friend_service.gd)

SaveData-owned RefCounted client persistence. Private `_commit` validates/signs next
state before atomic file replacement; event state machine stores terminal records
and outbox only after durable commit. Presence/delivery are ephemeral. No relay
mailbox or cached profile editing authority.

| Functions | Contract |
| --- | --- |
| `notifications_allowed` | False for preferred DND; does not change microphone or transport. |
| `configure` | Disconnects old transport, sets account/path, initializes or verifies signed store; corrupt/wrong-owner original blocks writes. Emits changed. |
| `add_contact` | Canonical other public key/nickname/optional verified profile → signed local commit; bool. No friendship request implied. |
| `contacts` | Returns deep copy of saved contacts. |
| `relationship` | Selects current nonterminal relation and pending/accepting/friends status for fingerprint; copy or `{}`. |
| `is_friend` | Requires confirmed relation and no local block; not instance admission by itself. |
| `send_request` | Refuses missing/blocked/already-related contact; creates signed request and durable outbox through event commit; bool. |
| `act` | Accept/decline incoming, cancel outgoing or revoke pair using signed request-bound event; validates state before commit; bool. |
| `block` | Persists block, terminates active pair when blocking, removes live presence and refreshes; unblocking never restores old consent. |
| `remove_contact` | Requires no active relationship, removes saved contact via commit; bool; not a shortcut around revocation. |
| `set_status` | Persists Online/Offline/DND preference then refreshes live transport; bool. |
| `get_profile` | Copy of self or cached contact profile; missing cached profile builds display fallback, not signed editing authority. |
| `can_edit` | Always false: cached social profiles are read-only. |
| `label`, `relationship_label` | Display strings from nickname/profile or terminal consent status; never identity/action keys. |
| `status` | Privacy-authorized fresh presence label or unavailable; expires after 15 s, not durable online history. |
| `attach` | Replaces transport, generates connection generation, negotiates supported capability and refreshes; does not restore stale presence. |
| `disconnect_transport` | Clears transport/live presence/delivery/generation and emits changed; persisted contacts/outbox remain. |
| `refresh` | Sends bounded batches of pending/terminal events and current presence authorizations/subscriptions; guards reentrancy; no offline relay store. |
| `tick` | Periodic refresh and presence expiry; caller polls only active client. |
| `receive` | Routes receipt/event/presence/delivery after schema/generation/sequence/consent checks; durable acceptance precedes receipts. Untrusted actor input still requires signed event validation. |

Private event groups: `_apply` enforces relationship/request identity and outbox
supersession; `_terminate_pair` closes all active grants; `_receive_event` rejects
forgery/replay/blocked senders and persists before acknowledging. Canonical-number
serialization stabilizes signed JSON across parse/reload.

## Client and relay

<!-- module: scripts/multiplayer/network_handler.gd -->
### [NetworkHandler](../../scripts/multiplayer/network_handler.gd)

Client autoload. Private transition helpers correlate operation/session, stage
before admission, activate only matching acknowledgement and disconnect on uncertain
commit/activation. `_process` polls peer and deadlines. Profile and instance
handlers reject other sessions/stale revisions. Remote-player cleanup removes
children; animation service lives under DataLoader, not that cleanup list.

| Functions | Contract |
| --- | --- |
| `get_animation_controller` | Returns one attached/recovered nonretiring service when inside tree; replaces queued-deletion instance. Borrowed service, caller must not free it casually. |
| `create_peer` | Await key-authenticated relay connection; configures client moderation path/signals, publishes local profile on success; bool. Writes moderation directory client-side. |
| `create_session` | Sends authenticated create with selected mode/world/name and builtin hash where supported; result arrives asynchronously. Not immediate membership success. |
| `request_player_model`, `sync_player_avatar` | Legacy RPC model URL request/response adapters; sender-derived lookup. Current custom ENet/profile and typed asset flow should not be confused with a second authoritative animation stream. |
| `sync_player_data` | Applies received actor transform to current remote node only outside transitions; no local movement authority. |
| `sync_player_voice` | Feeds received samples to remote spatial playback under same session guards; never microphone capture. |
| `join_session` | Await authorized lookup/revision staging, join result and activation; bool/last_session_error. Concurrent request rejected; failure before acknowledgement preserves old world. |
| `host_world` | Await selected content staging then create/result/activate; bool. Explicit hosting, never automatic side effect of discovery click. |
| `update_connected_peers` | Reconciles current other-peer nodes and emits participants_changed; metadata/profile resolution is separate from avatar completion. |
| `is_instance_admin` | Reads local fingerprint's role in authoritative active snapshot; false without identity/state. UI check is not relay authorization. |
| `refresh_instance` | Sends correlated refresh and starts snapshot deadline; no optimistic permissions. |
| `manage_instance` | Guards busy/pending/admin and emits revisioned action with target identity/peer guards; returns request ID or empty, completion via signal. |

<!-- module: scripts/multiplayer/relay.gd -->
### [Relay](../../scripts/multiplayer/relay.gd)

Server scene Node. Main-thread ENet event loop; transient auth/profile/membership/
admission/social/animation state only. Private management validates admin, revision,
target, rates and deduplication. Admission is bound to current admins/mode/world;
all required moderation approvals must arrive fresh. No durable user/session store.

| Functions | Contract |
| --- | --- |
| `start_relay` | Binds ENet host on 0.0.0.0:7374; logs failure, leaves unavailable if bind fails. Tests substitute ephemeral host instead. |
| `handle_events` | Expires social/animation/admission state and dispatches connection events/packets until none; requires host. |
| `peer_connected` | Allocates available byte peer ID, metadata/timeouts; full capacity disconnects instead of reusing active identity. |
| `peer_disconnected` | Idempotently removes matching connection and indirect caches/queues/authored metadata/bans; notifies surviving instances and frees ID. |
| `on_packed` | Bounded type dispatch, authenticated operation checks and actor-derived routing; does not trust claimed IDs. Unknown type errors; use real codec/schema fixtures for hostile input. |
| `remove_user_from_session` | Removes peer/admin, increments revision, deletes empty instance or promotes survivor and notifies; clears animation pair state. Valid internal index required. |
| `generate_code` | Creates unused instance code against current sessions; not an access grant or account identity. |
| `get_session_index`, `get_user_in_session` | Find current session/index or −1; no persistent lookup history. |
| `get_public_session` | Builds public-only summaries without roster/account keys; no non-public discovery leakage. |
| `notify_session` | Sends each connected member its other-peer list, scoped profiles and authoritative instance state; invalid index ignored. |
| `send_result` | Sends reliable correlated session outcome with current world revision when available; only connected destination. |
| `valid_creation` | Validates metadata, world address and optional hash; does not download/trust publisher content. |
| `authenticate_peer` | Internal verified-key installation, not a public authentication bypass. Wire handler calls only after challenge proof. |
| `publish_profile` | Accepts matching authenticated owner and valid fields/signature/revision; updates transient publication and notifies instance; bool. Internal unsigned adapters are test-only, not emitted as verified network profiles. |
| `get_profiles_for_peer` | Returns only authenticated current-instance public profiles with derived peer IDs; no unrelated instance or private keys. |

<!-- module: relay_protocol/relay_peer.gd -->
### [RelayPeer](../../relay_protocol/relay_peer.gd)

Client transport object owned by NetworkHandler. Main-thread polling; no automatic
background receive thread. Account private key is used locally for signatures.
Moderation policy is client-owned disk state, unlike relay session metadata.

| Functions | Contract |
| --- | --- |
| `send_animation` | Sends reliable AccountPacket only after authentication/capability; caller supplies sole resolved-state/supporting transport payload. |
| `configure_moderation` | Loads bounded owner-key policy or preserves/reports corrupt/wrong-account file; no automatic fail-open approval. |
| `connect_to_relay` | Creates one-peer ENet connection/host and initiates connection; call handle_events for completion; not authenticated immediately. |
| `create_session`, `join_session` | Sends authenticated selected metadata/session/world and expected revision; no local success claim. |
| `resolve_instance` | Sends authenticated code lookup without changing membership. |
| `decide_join` | Sends allow/decline only for a known pending token; relay still validates current admin/support. |
| `handle_events` | Expires request rows, ticks friends, polls ENet and dispatches until none; requires connection. |
| `connected_to_relay` | Marks transport connected, emits connected, sends public-key hello when private key configured; not proof yet. |
| `disconnected_from_relay` | Clears capabilities/session/profiles/peers and disconnects friend transport, emits lifecycle signal; retains client policy/contacts. |
| `on_packet` | Parses by explicit ID, validates lengths/scope/snapshots/challenges and emits appropriate signal. Rejects late session data; payload parser alone is not authorization. |
| `publish_profile` | Sends authenticated owner-signed profile; relay verifies owner/signature again. |
| `request_instance` | Sends management payload only with connected/authenticated peer; coordinator and relay enforce action semantics. |

## Protocol functions

<!-- module: relay_protocol/packet_info.gd -->
### [PacketInfo](../../relay_protocol/packet_info.gd)

| Functions | Contract |
| --- | --- |
| `encode`, `decode` | Encode/decode the one-byte type only. decode assumes nonempty transport-validated buffer. |
| `sent`, `broadcast` | Encode and send on ENet channel 0 with packet flag to peer/connection; caller owns connection state and authorization. Compatibility spelling `sent` retained. |

<!-- module: relay_protocol/account_packet.gd -->
### [AccountPacket](../../relay_protocol/account_packet.gd)

| Functions | Contract |
| --- | --- |
| `create` | New reliable packet with explicit type/dictionary; no schema/actor validation. |
| `parse` | Returns JSON object or `{}` for invalid/2..256 KiB envelope; caller applies smaller per-operation bounds and authentication. |
| `encode` | Adds UTF-8 JSON after type byte; no object deserialization/execution. |

<!-- module: relay_protocol/create_session.gd -->
### [CreateSession](../../relay_protocol/create_session.gd)

| Functions | Contract |
| --- | --- |
| `create` | Creates reliable metadata request with explicit ID 1; result pending relay validation. |
| `create_from_data` | Instantiates then decodes caller-validated bytes. |
| `encode`, `decode` | JSON object after type; decode falls back `{}` and recursively normalizes integer-valued numbers. Legacy direct JSON errors may be diagnostic; not general hostile-input parser. |

<!-- module: relay_protocol/join_session.gd -->
### [JoinSession](../../relay_protocol/join_session.gd)

| Functions | Contract |
| --- | --- |
| `create` | Reliable session/world/expected-revision request, not URL-only join. |
| `create_from_data` | New packet decoded from transport-validated bytes. |
| `encode`, `decode` | JSON after the one-byte packet type (ID 2); legacy plain ID accepted. Parsed world_revision type checked; malformed revision becomes invalid sentinel. Admission still relay-owned. |

<!-- module: relay_protocol/session_result.gd -->
### [SessionResult](../../relay_protocol/session_result.gd)

| Functions | Contract |
| --- | --- |
| `create`, `create_from_data` | Construct reliable result / instantiate and decode validated bytes. |
| `encode`, `decode` | JSON dictionary after type; non-object leaves empty result. Coordinator matches operation/session and boolean success before acting. |

<!-- module: relay_protocol/public_wolds.gd -->
### [GetPublicSessions](../../relay_protocol/public_wolds.gd)

| Functions | Contract |
| --- | --- |
| `create`, `create_from_data` | Construct reliable public-summary array / decode validated response. |
| `encode`, `decode` | JSON array with recursive integer normalization; non-array empty. Client browser validates public mode/identity/address separately. Filename spelling retained. |

<!-- module: relay_protocol/get_session_peers.gd -->
### [GetSessionPeers](../../relay_protocol/get_session_peers.gd)

| Functions | Contract |
| --- | --- |
| `create`, `create_from_data` | Reliable other-member list / decoded new object. |
| `encode`, `decode` | JSON peer array, integer normalization; expects trusted relay shape/transport validation, not a hardened independent schema. Recipient excludes itself. |

<!-- module: relay_protocol/id_assignment.gd -->
### [IDAssingnment](../../relay_protocol/id_assignment.gd)

| Functions | Contract |
| --- | --- |
| `create`, `create_from_data` | Reliable legacy byte-ID packet / decode validated bytes. |
| `encode`, `decode` | Type + ID + remaining byte IDs. Current RelayPeer ignores assignment; legacy spelling/codec preserved, no new authority inferred. |

<!-- module: relay_protocol/player_data.gd -->
### [PlayerData](../../relay_protocol/player_data.gd)

| Functions | Contract |
| --- | --- |
| `create`, `create_from_data` | Unsequenced transform packet / decode exactly 26 transport-validated bytes. |
| `encode`, `decode` | Type/sender plus six float32 coordinates; mutates packet fields. Relay derives sender and instance routing; contains no tracker/animation state. |

<!-- module: relay_protocol/voice_chat.gd -->
### [VoiceData](../../relay_protocol/voice_chat.gd)

| Functions | Contract |
| --- | --- |
| `create`, `create_from_data` | Unsequenced mono float-input voice packet / decode validated byte buffer. |
| `encode`, `decode` | Clamp floats to signed16 PCM after type/sender, inverse to floats on receive; length policy belongs to transport. No microphone activation or compression negotiation. |

<!-- module: relay_protocol/world_address.gd -->
### [WorldAddress](../../relay_protocol/world_address.gd)

| Functions | Contract |
| --- | --- |
| `is_valid` | Pure builtin-or-bounded HTTP(S) syntax check; rejects whitespace/credentials/empty authority. Does not prove publisher trust, cache policy or safe Godot execution. |

<!-- module: relay_protocol/instance_state.gd -->
### [InstanceState](../../relay_protocol/instance_state.gd)

| Functions | Contract |
| --- | --- |
| `integer` | Finite integral number within supplied inclusive bounds, including JSON floats; bool. |
| `valid_metadata` | Mode 0..4, bounded nonblank name/description/control-character rules; pure bool. |
| `valid_fingerprint` | Lowercase 64-hex string only; hash syntax, not account proof. |
| `valid` | Valid metadata/world/session/revision and unique bounded roster roles/IDs/fingerprints; no mutation. Valid shape does not establish sender authorization. |

<!-- module: relay_protocol/animation_state.gd -->
### [AnimationState](../../relay_protocol/animation_state.gd)

| Functions | Contract |
| --- | --- |
| `integer`, `number` | Pure finite bounded numeric predicates; integer also rejects fractions. |
| `valid` | Version-2 resolved descriptor schema/builtin or custom hash/size/mask/clip bounds; no legacy manual controls. Membership/sender/sequence ordering is router/controller responsibility. |
| `playhead` | Computes current phase using monotonic elapsed, bounded speed, offset and duration; loops modulo or clamps one-shot end. Input must already be valid. |

<!-- module: relay_protocol/animation_router.gd -->
### [AnimationRouter](../../relay_protocol/animation_router.gd)

RefCounted relay component; server object supplies authenticated peers/sessions.
Private `_same` and `_send` protect routing/connection state. No asset files written.

| Functions | Contract |
| --- | --- |
| `handle` | Validates capability/control rate/schema/session/sequence, binds actor/time/generation, routes latest state or request-bound typed chunks. No unauthenticated/unsolicited file forwarding. |
| `snapshot` | Sends latest bounded same-instance states to supported recipient, excluding itself; no history of disconnected actors. |
| `leave` | Removes actor state/pairwise transfers and notifies surviving same-instance peers; called before membership removal. |
| `disconnect_peer` | Leave cleanup plus capability/rate/generation removal; no reconnect restoration. |
| `tick` | Expires outstanding transfer metadata by monotonic deadlines. |

<!-- module: relay_protocol/friend_event.gd -->
### [FriendEvent](../../relay_protocol/friend_event.gd)

| Functions | Contract |
| --- | --- |
| `bytes`, `digest` | Domain-separated fixed-field serialization / SHA-256 hex; no disk/network. Caller supplies canonical event fields. |
| `create` | Signs request or request-bound accept/decline/cancel/revoke with private actor key and random event ID; returns dictionary. Caller owns valid relationship context. |
| `valid` | Checks allowed fields/limits/keys/signature and nested request/digest/actor direction; false on forgery or unexpected nesting. |
| `valid_proof` | Requires matching valid request+accept pair; pure mutual-grant proof syntax/signatures, not current relay freshness. |

<!-- module: relay_protocol/friend_router.gd -->
### [FriendRouter](../../relay_protocol/friend_router.gd)

Ephemeral relay component. Private helpers bind connection actor, signed pair
proofs, subscriptions, presence sequences and rate limits. No saved contacts or
offline delivery mailbox; persistent revocation is client-owned.

| Functions | Contract |
| --- | --- |
| `mutual` | Queries fresh active mutual authorization edge between current connections; not durable contact history. |
| `handle` | Validates/routs supported social operations against authenticated sender and bounded proof/payload; not a trusted arbitrary event injection API. |
| `disconnect_peer` | Clears actor/pair/subscription/proof/rate references including surviving users' caches. |
| `tick` | Expires live authorizations/rates/presence-related temporary state; server polls. |

<!-- module: relay_protocol/friend_system/sent_friend_request.gd -->
### [Legacy friend stub](../../relay_protocol/friend_system/sent_friend_request.gd)

No public functions. This legacy placeholder is not the active signed social
protocol; use FriendEvent/FriendService/FriendRouter. Do not infer an offline
friend-message feature from the filename.

## UI contracts

<!-- module: scripts/GUI/vr_tracking_setup.gd -->
### [VRTrackingSetup](../../scripts/GUI/vr_tracking_setup.gd)

Viewport-local setup panel. `configure` binds the active VR player; private refresh
lists fresh runtime-exposed positional trackers and lets users assign/unassign
hips/feet with duplicate-role guards. Calibration saves current eye height and
zero grip offsets only, explicitly not full-body orientation calibration. No device
serial persistence or implied support for trackers absent from the OpenXR runtime.
The panel reports rig warnings and preserves blocked corrupt calibration stores.

<!-- module: scripts/GUI/vr_keyboard.gd -->
### [VRKeyboard](../../scripts/GUI/vr_keyboard.gd)

Viewport-local pointer keyboard. `edit` binds a weak LineEdit/TextEdit target;
`type_text` inserts at caret respecting editable/read-only and field length;
`backspace` deletes, `submit` emits LineEdit submission or inserts TextEdit newline,
`close` releases target/hides. Buttons do not steal text focus. Private row builder
and caret movement never access a global text target or persist entered content.
The player opens it on viewport text focus and closes with the main menu; controller
stick scrolling emits bounded wheel events only at valid panel hits.

UI public calls require attached/ready nodes with their declared scene children
and supplied services. They must not be used to bypass account or relay checks.
Asynchronous media/import callbacks use generations/visibility guards. Removing a
subpage must release subscriptions and input ownership without changing an avatar
merely because a menu closes. Evidence: profile/settings/friends/instance and
animation lifecycle tests, plus manual small-window/XR checks.

<!-- module: scripts/GUI/animation_menue.gd -->
### [Avatar source editor](../../scripts/GUI/animation_menue.gd)

Owner-only source editor under profile. Ready creates model/multifile/URL inputs,
draft source list, permission and layout editor. No manual playback console.
Private owner-change handler closes stale editor; exit invalidates async draft work.

| Functions | Contract |
| --- | --- |
| `add_source` | Await config import into draft (model or external); busy/limit/generation guarded. Permission resets after import; no automatic equip. |
| `apply` | Await full candidate commit after current-owner check; displays success/error. Close/Cancel discards draft only, not cached imported bytes. |

<!-- module: scripts/GUI/avatar_preview.gd -->
### [AvatarPreview](../../scripts/GUI/avatar_preview.gd)

Independent SubViewport/world; scripts/physics/audio behavior refused/disabled
before attach. Private bounds fitting/zoom/input owns only preview pivot/camera.
Hiding clears model/rendering. Public profile/equipped avatar is never changed.

| Functions | Contract |
| --- | --- |
| `load_file` | Await bounded local VRM bytes into independent preview; bool. Original path is not sent over network. |
| `set_source` | Changes URL, clears prior preview/restores URL loader, updates affordances; does not fetch until requested by view. |
| `clear_preview` | Invalidates generation, detaches/frees model and disables viewport updates. |
| `load_preview` | Await injected/default URL loader, reject stale/hidden/unsafe result, attach and frame independent model; error signal on failure. |
| `reset_view` | Restores facing/zoom/camera framing without reloading source. |

<!-- module: scripts/GUI/emote_layout_editor.gd -->
### [EmoteLayoutEditor](../../scripts/GUI/emote_layout_editor.gd)

| Functions | Contract |
| --- | --- |
| `configure` | Binds account config and renders persistent groups/actions; tracks account owner and closes on switch. Private buttons commit graph operations, confirm deletion/reset, never play clips. |

<!-- module: scripts/GUI/emote_wheel.gd -->
### [EmoteWheel](../../scripts/GUI/emote_wheel.gd)

Shared eight-sector Control renderer. Private draw/input handles dead zone,
hysteresis and desktop/controller confirmation; exit restores owned input once.
No footer paging buttons, network calls or model importing.

| Functions | Contract |
| --- | --- |
| `open` | Binds layout/catalog, resets root/page, captures prior focus/mouse as requested and opens; browsing alone emits no emote intent. |
| `radius` | Computes viewport-adapted wheel radius; pure UI sizing. |
| `refresh` | Repairs current group/page after layout changes, builds sectors, disables unavailable actions and clears hover. |
| `select_direction` | Selects sector from normalized 2D direction with dead zone/hysteresis; no activation. |
| `activate_sector` | Ignores inert/disabled entries; emits action ID or navigates group/page with reset highlight. bool indicates emote selection, not successful avatar playback. |
| `back` | Restores parent page/focus or dismisses root; no animation side effects. |
| `dismiss` | Hides, restores prior input/focus once and emits closed; safe with later exit cleanup. |

<!-- module: scripts/GUI/xr_emote_wheel.gd -->
### [XREmoteWheel](../../scripts/GUI/xr_emote_wheel.gd)

| Functions | Contract |
| --- | --- |
| `open` | Builds transparent viewport/quad and stable hand-local world placement; configures hold vs pointer mode, action/diameter/haptics. Caller supplies valid attached XR hand/camera. Private process projects direction, confirms/rearms navigation, closes on tracking/focus loss. No camera/locomotion teleport. |

<!-- module: scripts/GUI/error_popup.gd -->
### [ErrorPopup](../../scripts/GUI/error_popup.gd)

| Functions | Contract |
| --- | --- |
| `show_error` | Finds/creates reusable popup under supplied UI parent and presents real error; returns/reuses UI instance, not a logging-only replacement. |
| `present` | Displays message and blocks global shortcuts while visible; preserves caller draft. |
| `dismiss` | Releases popup input state and hides; no data reset. |

<!-- module: scripts/GUI/home_menue.gd -->
### [Home](../../scripts/GUI/home_menue.gd)

Ready wires shared mute/profile/presence and Home tiles; exit unsubscribes. Private
visibility/reset helpers close lazy subpages, not avatar animation. Emotes tile
uses the production controller factory rather than owning another renderer.

| Functions | Contract |
| --- | --- |
| `open_profile` | Creates/reuses profile panel for supplied owner and hides grid; service preserves owner/visitor rights. |
| `open_home_menu` | Opens allowed lazy explorer/instance page or selects shared Explorer tab; invalid kind ignored. |
| `close_home_menu` | Detaches/frees subpage and restores grid/focus; no persistent-store mutation. |
| `reset_home` | Cancels visible profile editor or closes subpage on menu hiding. |

<!-- module: scripts/GUI/menue.gd -->
### [Main tabs](../../scripts/GUI/menue.gd)

No public functions. Ready duplicates theme panel before changing local margins;
input toggles menu/capture unless a modal wheel owns shortcuts. Private reset
closes Home/Explorer state. Never mutate shared theme resources globally.

<!-- module: scripts/GUI/friends_menue.gd -->
### [Friends UI](../../scripts/GUI/friends_menue.gd)

No public functions. Private ready/render handlers subscribe to owner friend
service, show saved/pending/accepted rows, validate public-key input, send explicit
actions and open read-only cached profiles. Account switch clears drafts/rows;
exit unsubscribes. Display strings are not target identities.

<!-- module: scripts/GUI/profile_edit_popup.gd -->
### [ProfileEditPopup](../../scripts/GUI/profile_edit_popup.gd)

| Functions | Contract |
| --- | --- |
| `open_editor` | Requires editable owner and selected field, captures revision/draft and shows only that field; bool false for visitor/invalid request. |
| `draft` | Returns full candidate field values with current edited field, preserving others. |
| `is_dirty` | Compares active draft against captured value; no writes. |
| `save_edit` | Validates current owner/revision, calls signed profile save, emits saved/closes only on success; errors preserve draft. |
| `request_cancel` | Dirty draft asks confirmation; clean closes immediately. |
| `cancel_edit` | Discards local draft and releases modal input; never writes profile. |

<!-- module: scripts/GUI/profile_menue.gd -->
### [ProfileMenu](../../scripts/GUI/profile_menue.gd)

Private refresh uses copies/current rights, independent preview and friend actions;
remote departure clears unavailable view. Close cancels editor/media/preview;
exit unsubscribes from old service. Avatar source editing is self-only.

| Functions | Contract |
| --- | --- |
| `open_profile` | Switches service/fingerprint, cancels old editors/subscriptions, shows current view; owner service controls edit rights. |
| `is_editable` | Delegates can_edit(profile_owner); not inferred from instance role. |
| `get_displayed_public_key` | Returns current public key text or empty; never private identity key. |
| `open_editor` | Opens/reuses one field-specific editor only for owner; bool outcome. |
| `cancel_edit` | Cancels active editor or closes profile view, preserving caller navigation. |

<!-- module: scripts/GUI/settings_menue.gd -->
### [SettingsMenu](../../scripts/GUI/settings_menue.gd)

| Functions | Contract |
| --- | --- |
| `select_category` | Shows one known registry category, cancels active rebind and resets scroll; invalid name ignored. Private renderer/commit/reset functions use typed store; input conflicts reject without losing capture. Cache actions confirm cleanup and await refresh, not account deletion. |

<!-- module: scripts/GUI/share_session_menue.gd -->
### [Active Instance UI](../../scripts/GUI/share_session_menue.gd)

| Functions | Contract |
| --- | --- |
| `open_profile` | Opens selected roster fingerprint using existing profile service/view; instance admin status does not grant account edit rights. Private metadata/moderation handlers use authoritative snapshot/revision, confirmation and correlated results; timeout removes actionable stale permissions. |

<!-- module: scripts/GUI/world_explorer.gd -->
### [WorldExplorer](../../scripts/GUI/world_explorer.gd)

Private catalog and live-session state are independent; snapshots replace stale
rows and preserve catalog worlds. Startup subscribes before request; peer replacement/
exit detaches old subscriptions. Own active instance hidden, not the whole URL.

| Functions | Contract |
| --- | --- |
| `load_sessions` | Validates/replaces public summaries, groups exact URLs and rebuilds open cards/rows; no implicit join/create. |
| `create_world_info_menue` | Opens content info for selected world and lists every eligible other public instance at that URL; legacy spelling retained. Buttons join exact session IDs. |
| `close_info_menu` | Releases info page and restores browser, no relay mutation. |

<!-- module: scripts/GUI/vr_gui.gd -->
### [VRViewport2D](../../scripts/GUI/vr_gui.gd)

Tool Node3D renders a SubViewport onto a locally duplicated quad/material.

| Functions | Contract |
| --- | --- |
| `raycast_to_viewport_point` | Intersects ray with UI plane and maps to viewport pixels; returns negative point when no hit. Caller checks bounds/visibility. |
| `inject_input` | Duplicates event, adjusts mouse position and pushes to viewport; caller supplies validated pointer hit, does not mutate original event. |

## Evidence and limits

Use [testing commands](../development/testing.md) and each suite's README for exact
fixtures. This contract set must be reviewed when behavior changes; coverage checks
only detect missing names/module sections, not whether prose is truthful. Known
manual boundaries remain XR/controller comfort, full-renderer meshes/shadows,
physical voice, arbitrary humanoid compatibility and Internet/large-transfer stress.
