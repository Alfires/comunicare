# Client-only per-player avatar visibility roadmap

## Status and requested behavior

**Implemented with manual gates — 2026-11-05.** The client-local visibility service,
roster controls and centralized profile/custom model attachment are implemented.
Headless tests cover identity scope, same-resource independence, replacement
visibility and real roster toggle behavior. Rendered flash/shadow/mirror checks,
independent-client visual behavior and headset usability remain manual gates.
The design below is retained as implementation history and verification scope.

This extends the [Active Instance roadmap](active-instance-roadmap.md)
with a local presentation preference, not a moderation or access-control action.

Add a **Hide avatar / Show avatar** control beside each other player's entry in
the **Active Instance** menu (the active-session player list).

- Hiding player A affects **only this client**. Player A and other clients do not
  receive a block, notification or visibility command.
- Player B stays visible even if A and B use the exact same avatar URL, cached
  file, model revision, mesh or animation.
- If A changes avatar, reloads it or receives an asset update, A stays hidden.
- Show avatar reverses the local choice and shows A's latest avatar, not a stale
  model from before the hide action.
- Every participant can use the control; admin status is irrelevant. Do not add
  it to the local player's row in the first version.
- Voice, profile viewing, nameplates, membership, world-item ownership, collision
  and moderation are unchanged. “Hide avatar” must not be described as muting,
  blocking the user, preventing downloads or revoking instance access.

## Proposed lifetime and identity

Use the authenticated **player fingerprint**, scoped to the current acknowledged
session, as the hide key. Never use avatar URL/hash, username, row index or a
reusable transport peer ID as the preference's identity.

Initial scope: session-local memory, not a persistent cross-session block list.
Retain hidden fingerprints through a player's disconnect/rejoin into the same
active session so reconnecting or changing transport ID does not bypass hiding.
Clear on successful switch/leave, relay disconnect, account change or service
teardown; a failed world transition keeps the current session's preferences.
Reconnect after a relay disconnect starts with no hidden entries. Do not transfer
hidden choices across different instances of the same world URL.

This retention is **client-local**, not relay history. No preference or departed
player reference is added to relay state. Future persistent hiding would need a
separate explicit design, account scoping and storage/recovery tests.

## Current implementation and affected paths

- `scripts/GUI/share_session_menue.gd::_render()` builds fingerprint-keyed roster
  rows with name/profile, role badge and optional admin actions. Its row signature
  currently lacks local avatar visibility. Reuse these rows rather than adding
  another player list or hiding controls inside the profile editor.
- `scripts/player/remote_player.gd::load_player_model()` asynchronously swaps the
  avatar subtree, guarded by a generation counter. Visibility must be enforced
  on **every** attachment path, before the new model can render.
- `scripts/assets/animation_controller.gd::_store_remote_model()` and the remote
  appearance/animation flow can deliver custom equipped models separately from
  profile URL loading. Audit and route these swaps through the same visibility
  boundary; patching only `load_player_model()` is insufficient.
- `scripts/multiplayer/network_handler.gd` owns acknowledged membership and remote
  node lifetime. Use authoritative member/profile identity to resolve a fingerprint
  to the current remote node; reject stale-session and reused-peer callbacks.
- `scripts/startup/data_loader.gd` and `scripts/assets/asset_cache.gd` share model
  originals across consumers. Do **not** blacklist, delete or mutate shared assets
  to implement a per-person presentation choice.

## 1. Local visibility owner

Introduce one client-only visibility service, for example
`scripts/player/avatar_visibility.gd`, owned by the existing client coordinator.
Proposed responsibilities (not claims of existing APIs):

- Maintain the current session/account scope and hidden-fingerprint set.
- Expose `is_hidden(fingerprint)` and `set_hidden(fingerprint, hidden)` with a
  change signal for row/render updates. Validate targets against current remote
  membership when accepting UI intent; reject self or stale-session requests.
- Preserve state independently of individual UI rows and avatar instances.
- Reapply state when remote identity becomes known, a node is recreated or a
  model attaches. Pending requests must capture session and fingerprint, not
  resolve an old peer ID against a newer roster at completion time.
- Clear the scope only on committed lifecycle changes, never simply because
  the menu closes, a roster rerenders or a transition starts.

Do not put the hidden set into signed profiles, friends data, general global
avatar settings or relay packets. Do not create a second independent flag in
the UI that can disagree with the service.

## 2. Enforce visibility at a per-player avatar boundary

- Use a stable, dedicated `Node3D` avatar visual container under each remote
  player, or an equivalently centralized attach-and-visibility method. Hide this
  per-player visual boundary, **not** the entire remote player root or any shared
  mesh/material resource.
- Both fallback/profile URL models and transferred custom models attach beneath
  that boundary. Keep the `remote.avatar` reference compatible with animator/IK
  consumers; verify all code that assumes the avatar's parent or transform.
- Apply hidden state before attaching a newly loaded model to the active tree.
  No one-frame flash is acceptable during avatar change, tracking setup or async
  completion. Handle the “hide while loading” and “show while loading” races.
- Preserve generation guards and stale/detached-result cleanup. Showing again
  reveals only the newest valid avatar and does not duplicate loads or nodes.
- Hide all model-owned visuals, including accessories and shadows. Check mirror
  and other viewport rendering; a model hidden in the main view must not remain
  visible through a secondary camera. Do not hide the separate nameplate/audio.
- Keep actual movement, spatial voice and pickup/physics behavior unchanged.
  Optional future download/animation suppression is out of scope: it needs its
  own cancellation, memory, resume and privacy design.

## 3. Roster control and feedback

- Add a button immediately beside each other player's row: **Hide avatar** when
  shown, **Show avatar** when hidden. Keep it distinct from admin Kick/Ban actions.
- Explain via tooltip: “Only hides this player's avatar on your device. Voice and
  other players are unaffected.” Give the button a stable accessible name and
  visible state; do not rely on icon/color alone.
- Include hidden state in the row update/signature logic or update the existing
  button through the service signal. Reopening/rerendering the menu must reflect
  the actual state without resetting it or accumulating signal connections.
- Disable actions while changing session or if the target has departed. Capture
  fingerprint and session with the callback; stale rows cannot hide a new player
  who inherited the same peer ID.
- Preserve profile opening, badges, counts, scrolling, admin actions, desktop
  keyboard focus, VR pointer targeting and small-window layout. Use adequate
  VR-friendly hit targets; long names must not push controls outside the list.

## 4. Test-first implementation slices

Each slice gets failing regression tests first, then production changes, focused
passing verification and a Conventional Commit published to the configured
upstream. Never publish broken intermediate states or unrelated working files.

1. **Visibility owner and lifetime:** tests for session/fingerprint scoping,
   self/stale-target rejection, reconnect policy, failed transition preservation,
   successful switch/account/disconnect cleanup, and peer-ID reuse safety.
2. **Remote visual attachment:** real remote node/model fixtures for independent
   same-asset players; hide/show; async avatar changes; transferred models; asset
   refreshes; recreated nodes; no stale completion flash. Assert shared model
   resources/cache files are untouched and voice/nameplate/physics stay active.
3. **Active Instance UI:** actual row button behavior and state refresh for all
   roles; disabled stale rows; reopening; long names, crowded roster, keyboard
   navigation and pointer activation. Existing admin behavior remains intact.
4. **Multi-client/rendered validation:** independent client visibility choices;
   A hidden only on client 1 while client 2 still sees A; B sharing A's model
   stays visible; A switches to a different model and stays hidden. Verify
   shadows/mirrors and Show avatar restoring the newest model.

Relevant existing disposable runners to extend as needed:

```sh
python3 tests/active_instance/run.py
python3 tests/avatar_loading/run.py
python3 tests/animation_sync/run.py
python3 tests/profile/run.py
python3 tests/real_ui/run.py
```

Update copied dependencies/fixtures when adding the service or visual container.
Service-level assertions alone cannot prove no rendered flash, mirror/shadow
leak or VR usability. Record actual executed suites, skips and warnings; do not
present these planned commands as passing results. Do not launch normal startup
against real account data for automated verification.

## Completion gates and documentation

Feature is complete only when local identity-based hiding works across all avatar
swap paths, the beside-row toggle works for non-admins in desktop/VR menus, and
tests establish same-asset independence and no network/global visibility effect.
Document the session-only lifetime and distinction from mute/ban/download policy
in the current user guide. Add service/function contracts and update the symbol
inventory plus this roadmap's index status. Keep outstanding rendered/headset
gates explicit rather than claiming hardware certification from headless tests.
