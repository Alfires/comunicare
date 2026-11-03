# Profile menu and expanded settings roadmap

Scope: original roadmap and baseline, now implemented at the user's request. Status below supersedes proposed implementation details; remaining items are explicitly listed.

## Current implementation status

- Home has an icon-only **top-left profile button**, with microphone remaining flush right. One reusable profile panel opens from Home; same-instance participants have View profile buttons below the header.
- General Settings no longer includes profile fields/category. New functional preferences: microphone gain/voice threshold, mouse sensitivity/invert Y and remote nameplates (Interface category).
- Dedicated ProfileService owns name, multiline description, HTTPS user-icon source/default and avatar URL. Self profiles can be edited; other accounts are read-only, with full public-key display/copy and fingerprint. Saves validate all fields, persist before publishing and reject stale drafts; Cancel/discard leaves saved data unchanged.
- Existing account keys are reused, corrupt keys are not replaced, and legacy name/avatar migrate into per-key signed profile files. A change of display name does not change identity.
- Relay authentication uses connection-bound random single-use signed challenges, timeout handling and duplicate-account rejection. Create/join requires authentication. Profile payloads are signed and verified; snapshots contain only current same-instance members, not another instance of the same world. Session changes/disconnect clear views. Public discovery contains no account keys.
- Icon preview accepts bounded HTTPS raster requests, no redirects, defaults on failure and suppresses obsolete results. Visitor icon fetching is opt-in. Local icon import/cache and full hostile-image/network-address protections are **not implemented**; use trusted HTTPS image sources. Post-decode size limits are not a guarantee against decompression-memory exhaustion.
- Local desktop/VR players react to saved profile changes with generation-checked avatar replacement. Downloads return per-request models rather than sharing `_model`; failed downloads retain old models. Real VRM/XR behavior still needs manual verification. Remote profile views show the avatar URL; automatic downloading of remote profile avatars is not added.

Verified: **69 profile checks** including real loopback multi-client authentication/profile packets, owner/visitor UI, draft conflict/cancel, key migration and corrupt-key preservation. Existing discovery/startup suites also run with authenticated clients. Client and relay must both be updated for the new protocol.

Security boundary: ENet is not encrypted and the relay is not cryptographically authenticated. Challenge proof and profile signatures do not establish secure transport or defend against every active relay/proxy attack. Remote session membership remains relay-authoritative. Signed profile replay across reconnects is not prevented by a durable external revision authority; within a connection, publication revisions and session IDs are checked. Protect/private-back up account key files; key rotation/recovery and account service are not included.

Full-project import still reports pre-existing bundled VRM addon parse errors. Isolated tests do not establish full desktop/VR playability. Further roadmap items (graphics/device/VR settings, model previews, media caching/import, comprehensive secure transport and UI polish) remain follow-up work.

Acceptance tests have since been added at the user's request: `python3 tests/profile/run.py`. Initial result: **5 passing baseline checks, 7 expected failing acceptance checks and 5 dependent groups not run** until their feature APIs exist. See `tests/profile/README.md` for isolation, proposed seams and remaining coverage. No profile/auth implementation is included.

## 1. Required experience

- Add an **icon-only profile/account button at the top-left of Home**. Keep the existing microphone button at the top-right.
- Supply a bundled default user icon. Its owner changes it **only in the separate profile menu**, which also updates the Home button.
- Clicking the Home button opens your profile with **name, description, user icon and avatar**. Opening another participant's profile shows the same public information read-only.
- **Settings must not contain Profile fields or a Profile category.** Profile ownership is tied to the private/public key pair, not a display name or temporary network peer ID.
- Participants connected to the **same instance** can view each other's public keys in the profile menu. Never disclose a private key.
- Keep the existing microphone toggle, V shortcut and left-hand settings categories working.
- Expand Settings with useful options that have real runtime consumers, rather than adding nonfunctional rows.

Home header order: **profile → expanding spacer → microphone**. The profile button sits at the outermost left edge; the microphone remains at the outermost right edge. Check the parent TabContainer's left content inset when implementing the profile placement, without undoing the existing right-inset fix or moving the microphone.

An account is identified by its public key and controlled by possession of the matching private key. The existing local key pair is the starting identity; the relay must authenticate it before associating a connection with an account. This does not require a password/cloud account service. Display names are editable labels, never authentication identifiers. The **user icon is a 2D image**, while the **avatar is a 3D VRM model**; they need separate fields and loaders.

## 2. What exists and what needs changing

| Area | Current state / gap |
| --- | --- |
| `scenes/GUI/home_menue.tscn`, `scripts/GUI/home_menue.gd` | Icon-only mic in a spacer-based header. Add a separate profile control without reusing mic state/signals. |
| `scripts/GUI/menue.gd` | Removes the tab panel's right content inset for the microphone. Retain this; account for the left inset separately so the profile button meets the outer left edge. |
| `scripts/settings/settings_registry.gd` | Currently exposes `profile.username` and `profile.avatar_url` in Settings. Remove their settings visibility/category and migrate them into a dedicated profile schema. |
| `scripts/settings/settings_store.gd` | Typed validation, defaults, migration, debounce/persistence and change signals exist. No atomic multi-field update or draft editing API. |
| `scripts/settings/save_data.gd` | Owns the settings services and existing account CryptoKey. Currently maps username/avatar preferences into `SaveData.data`; retain a migration adapter while the dedicated profile service takes over. Private key material must never become a profile field. |
| `scripts/GUI/settings_menue.gd` | Builds left category buttons and generic controls. Must stop rendering profile data. Multiline/icon editors belong in the separate profile menu; reusable widgets can be shared without sharing menu placement. |
| `scripts/player/player_desktop_movment.gd`, `player_vr.gd` | Load the saved avatar at startup. Profile edits do not currently provide safe live avatar replacement. Desktop sensitivity and VR locomotion values are script fields, not settings. |
| `scripts/startup/data_loader.gd` | Shared `_model` field is used by avatar loading. Concurrent/stale avatar requests can interfere; isolate results before relying on previews/live replacement. |
| `scripts/multiplayer/network_handler.gd`, `scripts/player/remote_player.gd` | Legacy avatar RPCs coexist with custom ENet relay packets; remote names use peer IDs. Changing local settings alone does not implement trustworthy remote profile propagation. |
| `relay_protocol/relay_peer.gd`, `scripts/multiplayer/relay.gd` | No completed key-authentication exchange is present; the relay's `key_mapping` is unused. Public-key identity cannot be assumed authenticated yet. |

## 3. Dedicated profile schema and account ownership

Introduce a dedicated `ProfileService`/profile schema for owner identity, editable profile data and cached remote profiles. Keep general preferences in the existing settings registry/store. Sharing validation/persistence utilities is fine, but profile fields must not appear in the settings definitions exposed to the menu. A dedicated profile section in the current ConfigFile is sufficient; avoid competing copies of the same fields.

Migrate existing `profile.username`, `profile.avatar_url` and legacy `[UserSettings]` values without changing the existing key pair. Keep those stable IDs for migration/compatibility if useful, but remove their Settings rows and the Profile sidebar category. Associate local profile records with a canonical public-key fingerprint; never restore an unrelated account's profile as if it belonged to a newly loaded key.

Identity fields are separate and read-only: canonical `public_key`, a SHA-256 fingerprint of its canonical public-key encoding, and an authenticated-session status. Only name/description/icon/avatar are editable. Determine `can_edit` from the local account's verified key identity matching the profile owner; enforce it again in ProfileService save methods and at the relay. Hiding buttons alone is not authorization. Offline self-editing is allowed using the locally loaded matching private key; publishing waits for authenticated connection.

| Stable profile field / migration ID | Value and validation | Initial/default behavior |
| --- | --- | --- |
| `profile.username` | Existing display name; trim edges, reject blank/control-only names, maximum 128 Unicode characters. Treat as plain text, never rich markup. | Preserve saved value/legacy `username`; no identity/key changes. |
| `profile.description` | New multiline plain text; allow empty; maximum 1,024 Unicode characters; reject disallowed control characters while permitting newlines. | Empty string for existing/new profiles. |
| `profile.icon_source` | New bounded string: empty means bundled default; otherwise supported absolute HTTP(S) URL or application-managed icon reference. Validate source type before loading. | Empty string and bundled `themes/icons/profile.svg` (proposed asset). |
| `profile.avatar_url` | Existing HTTP(S) VRM address with bounded length and real URL validation. Validate downloaded model separately from string validation. | Preserve saved URL and current default avatar. |

Use `profile.icon_source` rather than `profile.icon_url` if local image selection is supported. Import a selected file into `user://profile/icons/` and persist an opaque managed reference, not an arbitrary original filesystem path. Other players cannot resolve local paths; do not put them into network packets.

Use dedicated profile-field metadata such as `multiline`, `editor: image_source`, `placeholder`, and `help_text`. Keep existing IDs stable for migration; do not rename `profile.username` merely for presentation. Centralize profile validation so owner-edit UI, local saves and received public profiles apply consistent constraints. General Settings never renders these fields.

The current simple URL prefix check is insufficient for new media handling. Validate scheme and non-empty host, length and control characters; reject arbitrary `file://`, `res://` or `user://` input. Only allow bundled/managed references created by application code.

## 4. UI structure and editing rules

### Home button

- Add a 48×48 minimum profile button at the left of the header, with an expanding spacer separating it from the right-hand mic. Use containers rather than magic offsets. Keep it icon-only, with tooltip `My profile` and accessible action name where supported.
- Use the bundled icon immediately on first launch/loading/failure; never leave the button blank.
- Display the chosen user image in a square crop with consistent sizing. Home and profile views use the same loader/cache, not independent requests.
- A click opens one profile panel. Repeated clicks must not stack panels or duplicate signal connections. Back restores Home; Escape first cancels a picker/modal before closing the profile panel.
- Subscribe/unsubscribe on ready/exit. A saved self-profile icon change updates Home immediately. Provide a participant-list/nameplate action to open another user's read-only profile by authenticated account identity.

### Profile menu: owner editor and visitor view

Suggested scene/script: `scenes/GUI/profile_menue.tscn`, `scripts/GUI/profile_menue.gd`.

```text
Profile                                   [Back]
[read-only public key fingerprint] [Show/copy full public key]
[user icon preview]   Display name [............]
                     Description  [multiline...]
                     [remaining characters]
User icon [source / Choose image] [Use default]
Avatar    [VRM URL................] [Preview/Reload]
[preview / validation / loading / save error status]
                           [Cancel] [Save profile]
```

- Keep draft values in the editor. Typing does not commit or download media on every keystroke. Validate on submission; debounce only explicit previews if needed.
- Owner mode exposes editors, previews, reset icon, Cancel and Save. Visitor mode exposes plain read-only values, image/avatar presentation and the public key; no Save/reset/picker/editable controls. Public key is read-only in both modes. Reusing one scene with explicit modes is fine.
- Add a ProfileService operation such as `save_profile(owner_fingerprint, fields)` that verifies ownership and validates **every field first**, then commits all fields together. Invalid or unauthorized submissions cannot change any profile. Do not emit partial intermediate snapshots.
- Treat write failure separately from validation/runtime commit: keep the draft and clearly show `Not saved` with retry. If committing in memory before disk success, document that state; do not claim durable success before persistence succeeds. For stronger semantics, stage the config write before publishing a successful profile change.
- Cancel drops the draft and does not alter stored values/current avatar. Back/close with unsaved edits asks whether to discard. Reset icon selects the bundled default without resetting name, description or avatar.
- If a profile revision changes while an owner draft is dirty, show a conflict/reload prompt. Remote visitors receive refreshed public views without acquiring edit permission.
- Show the actual full public key in an expandable/selectable area with Copy, plus an always-visible fingerprint. A fingerprint alone does not satisfy public-key display. Never show or copy the private key. Label unverified/pending identities clearly rather than treating a claimed key as verified.
- Public-key/profile access for others is limited to current same-instance membership; clear remote profile views on departure/session switch. If the viewed user leaves, show unavailable rather than exposing stale session data as current.

## 5. User icon loading and avatar application

### Icons

Suggested service: `scripts/profile/profile_media.gd`, shared by Home and editors.

- Initially support PNG/JPEG/WebP raster images and the bundled trusted SVG default. Do not accept downloaded SVG as executable/vector content without a separate safe handling decision.
- Suggested limits: 5 MiB downloaded file, 2,048×2,048 pixels, bounded request timeout, bounded redirect count. Check decoded dimensions and total pixels, not only extensions or Content-Type. Plan for decompression-memory limits before exposing arbitrary images publicly.
- Provide loading/error state, a bundled fallback and request generation IDs: a late response for icon A must not replace newer icon B.
- Cache by source/content hash, bound disk usage and invalidate on source/reset. Release textures and cancel obsolete requests when panels close.
- Keep local imported assets separate from remote URLs. Private/local-network URLs require a clear policy before loading other users' icon links; a remote profile should not silently cause arbitrary requests into the player's local network.

### Avatar

- Add a player-facing controller that applies a **successfully loaded** new VRM to the active desktop or VR player. Build new model off-tree, validate required nodes, then replace the previous model. Preserve the old model if load fails.
- Refactor `DataLoader.load_vrm_from_url()` to return per-request results instead of relying on shared `_model`. Bound downloads, cancel/ignore obsolete requests and clean up failed previews.
- Rebuild desktop camera/head attachments and VR skeleton/XR body modifiers when replacing models; remove old references safely. Do not recreate the player, microphone or network session just to change the avatar.
- Previews must not apply the avatar or broadcast profile changes. On Save, apply the validated model; define failure behavior explicitly (recommended: retain old avatar and show retry, without claiming the new model is active).
- Keep the default-avatar recovery path available even if the saved URL becomes unavailable.

## 6. More settings, grouped in the existing left sidebar

Retain **Audio** and **Controls**, and remove **Profile** from Settings entirely. Add **Graphics**, **Interface** and **VR** only as their consumers are implemented. Preserve category ordering intentionally rather than hardcoding button counts in tests. Changing name, description, user icon or avatar is available only through the separate owner profile menu.

| Category | Setting | Proposed ID/default | Runtime consumer / scope |
| --- | --- | --- | --- |
| Audio | Microphone input gain | `audio.microphone_gain`, 1.0, range 0–2 | Capture samples before peak/send, clamp safely. Reset prevents accidentally amplifying noise. |
| Audio | Voice activation threshold | `audio.voice_threshold`, 0.004, range 0–0.1 | Replace `SILENCE_PEAK` hardcoding without bypassing mute/privacy gates. |
| Audio | Input device | `audio.input_device`, `default` | Populate supported devices dynamically; safe stop/restart with buffer clearing; hot-unplug fallback stays muted if muted. Add dynamic enum-provider support first. |
| Controls | Mouse sensitivity | `controls.mouse_sensitivity`, 0.003 | Apply to current and newly created desktop players. Do not alter network movement rates. |
| Controls | Invert mouse Y | `controls.invert_mouse_y`, false | Desktop camera vertical look only. |
| Controls | Rebind menu/movement/mic | `input.<action>` | Generalize current binding adapter to registry-declared actions; exclude the action being edited, not hardcoded mic-only; conflicts checked across all bindings. Avoid accidental loss of all menu controls. |
| Graphics | Display mode | `graphics.window_mode`, current/windowed | Map stable enum IDs to supported Godot window modes; preserve startup mode if absent; require confirmation/revert for disruptive changes. Desktop only. |
| Graphics | VSync | `graphics.vsync`, current/enabled | Apply only where supported; do not override XR runtime timing. |
| Graphics | Frame limit | `graphics.max_fps`, 0 = unlimited | `Engine.max_fps`, explicitly desktop-only; validate useful limits. |
| Interface | UI scale | `interface.ui_scale`, 1.0 | Apply at one UI root, not independently in each menu; keep dialogs usable and provide reset/revert. |
| Interface | Show remote player nameplates | `interface.show_nameplates`, true | Remote-player Label3D visibility; new players follow current value. |
| VR | Movement/turn sensitivity | `vr.movement_speed` / `vr.turn_speed`, current values | Apply to actual VR locomotion only after auditing the current script. Bound movement values; do not promise settings for unused fields. |

Never expose OS microphone permissions as if a toggle can grant them. Device selectors, graphics options and VR controls should indicate unsupported/not-applicable state with a reason. Do not silently write unusable device names or apply desktop display options to an XR session.

For the first delivery, prioritize description/icon, mouse sensitivity/invert Y, microphone gain/threshold and nameplates. Follow with device selection, graphics/UI scale and VR controls after their platform/lifecycle handling is ready. Keep existing master/voice volume and mute preferences intact.

## 7. Required key authentication and same-instance profile exchange

This is required for completion, not an optional follow-up. A local editor alone does not meet ownership or same-instance public-key visibility requirements.

### Authenticate possession of the private key

1. Load the existing account key safely. A missing key may create a new identity with clear first-run behavior; a corrupt/unreadable existing key must **not** be silently replaced. Private keys never leave the client.
2. Client presents its public key; relay validates algorithm/encoding/size and issues a cryptographically random, short-lived, single-use challenge bound to that connection, a protocol domain/version and the claimed key fingerprint.
3. Client signs canonical challenge bytes with its private key. Relay verifies using the presented public key, consumes the challenge and establishes `connection → authenticated public key/fingerprint`. Reject invalid signatures, expired/reused challenges and responses from another connection. Use Godot-supported vetted cryptographic primitives, not custom cryptography.
4. Gate create/join/profile publish on successful authentication. Keep transport-connected and account-authenticated as distinct states; startup currently hosts immediately after transport connection and must be updated to wait for authentication.
5. Relay derives profile ownership from this authenticated mapping. Ignore/reject client-supplied owner IDs attempting to edit another account. Define a duplicate-key connection policy (recommended initially: reject a second active connection with an explicit message).

ENet reliability is not encryption or relay authentication. Bind challenges carefully, but do not claim challenge signatures alone prevent an active relay impersonation/proxy attack or encrypt traffic. Define authenticated server identity and secure transport separately before claiming internet-grade protection. Signed, canonical, revisioned profile payloads allow clients to verify that public fields were approved by the key owner even if relayed; they do not hide those fields or by themselves prove fresh session membership.

### Publish and display only within the current instance

- Add a versioned public-profile packet to the **custom relay protocol**, not another unconnected Godot RPC path. Limit sizes, validate field types and derive sender identity at the relay rather than trusting a supplied peer ID.
- Include the verified **public key**, fingerprint, profile revision and intended public fields. Never include ConfigFile dumps, local image paths, **private keys** or private settings. Clearly disclose that name/description/icon/avatar and the persistent public key are visible to same-instance participants; public keys enable correlation across sessions.
- On authenticated join, send the joiner existing members' public keys/profiles and notify existing members of the joiner's identity/profile. Joining the same world URL in another instance must **not** disclose profiles/keys across those instances. Do not add account keys to the public discovery directory.
- Broadcast owner-approved profile updates only within the current instance. Explicit profile requests require requester and target to share that instance. Clear caches/views on departure, session switch and reconnect; use a session generation plus profile revision so old packets cannot resurrect departed users. A self-profile remains locally editable offline.
- Retain a safe default profile when packets are missing or malformed. Profile display name is not an authentication identity.
- Remote icon/avatar fetching is an untrusted-content boundary. Consider relay/media hosting or explicit loading controls before arbitrary URL auto-fetch; define abuse, download-limit and privacy policies first.
- Local icon imports need an explicit upload/media-service design to become shareable. Do not imply local selection is automatically visible to other clients.

## 8. Implementation sequence and file map

1. **Identity/schema and tests:** define authenticated account identity and dedicated profile schema/service; migrate name/avatar out of Settings without replacing keys; add description/icon defaults, owner authorization and atomic profile saves.
2. **Authentication protocol:** challenge/signature exchange, relay connection→key mapping, startup authentication wait, limits/replay protection and key-load error handling. Extend relay protocol/RelayPeer/NetworkHandler/relay and account loading.
3. **Header/profile navigation:** default icon asset, Home button and profile scene with owner-edit/visitor-read-only modes, full public-key display/copy, participant-profile entry point and Back/Cancel/Save behavior.
4. **Media and runtime application:** bounded/cancellable icon service, profile-only preview/edit widgets, safe local imports if included, per-request avatar loader and desktop/VR replacement controller.
5. **Required same-instance exchange:** authenticated/signed public profiles and public-key distribution, session-scoped requests, remote read-only updates and cache cleanup.
6. **Expand general settings:** remove Profile sidebar/fields; add first-priority general settings with adapters. Add remaining settings only with real consumers.
7. **Regression/manual verification:** persistence/migration, ownership attacks, replay/scope tests, resize/parent padding, keyboard focus, VR click targets, offline self-editing, live avatars and multi-client public-key visibility.

Account authentication is required, using existing keys; account key rotation/recovery UI and world discovery redesign are not included. Preserve unrelated work and never reset/regenerate existing account keys merely to migrate profile data.

## 9. Test plan and completion criteria

Use a new isolated profile suite or extend `tests/microphone_settings/`; run actual scene `_ready()`/input/lifecycle code with fake HTTP/model boundaries. No production API implementation is included in this roadmap.

- **Header:** icon-only profile button, bundled default without a network request, tooltip, minimum hit area, top-left outer-edge alignment inside real/padded TabContainer at multiple sizes. Mic remains flush top-right; icons/state/V remain independent.
- **Navigation:** opening twice creates one editor, Back/Cancel/unsaved prompt, reopen, keyboard focus and teardown without duplicate connections.
- **Schema/persistence:** existing name/avatar preserved; empty description/default icon initialized; Unicode/length/control characters/URL validation; all-or-none multi-field validation; save-failure retry; no key file changes.
- **Separation/ownership:** Settings has no Profile category/fields; self-profile edits update Home; remote profile has no editable controls; direct unauthorized service/protocol calls fail without changes; dirty draft detects revisions; Cancel does not publish; reset icon affects no other fields.
- **Icon:** corrupt/oversized/unsupported image, timeout/redirect failure, stale request suppression, cache bounds, bundled fallback, managed-file import, no local paths in public profile payload.
- **Avatar:** preview not applied; failed replacement keeps old model; successive URL changes cannot install stale model; desktop camera and VR skeleton rebuilt; no duplicate mic/network session and correct cleanup.
- **Settings extension:** synthetic new category/definition gets row and persistence; removed settings/category handled safely; each new option affects a real consumer and also applies to newly created nodes; invalid values rejected; device fallback/rebinding conflicts/display rollback covered.
- **Authentication:** valid proof of possession, claimed victim key without its private key rejected, altered/wrong-key signatures, expired/replayed/cross-connection challenges, unknown algorithms/oversized keys, unauthenticated create/join/publish, duplicate-key policy and corrupt key load without regeneration.
- **Privacy/network:** same-instance peers see the verified full public key and profile; another instance of the same world cannot fetch them; forged owner/profile signatures rejected; public directory contains no account keys; no private key/config leakage; late session packets ignored; departure/reconnect cleanup; owner vs viewer state remains correct for repeated display names and recycled peer IDs.
- **Regression:** all existing discovery and microphone/settings suites remain green. Preserve the microphone far-right-edge regression and add the corresponding profile far-left-edge test; do not weaken unrelated mute/capture assertions.

Manual acceptance: edit all four self-profile fields, Save/restart with the same key and confirm persistence; reset icon; verify Settings has no profile fields; edit self while offline; test invalid media and desktop/VR avatar replacement. Connect two different-key users to one instance: each can open the other's read-only profile and inspect/copy the actual public key, but only edit their own. A third user in another instance of the same world must not receive those profiles/keys. Changing display name does not change identity; copying someone else's public key does not grant edit ownership. Confirm layout at small/large sizes.
