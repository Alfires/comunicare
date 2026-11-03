# Active Instance menu roadmap

## Status and scope

**Superseding project-wide rule:** [`relay-data-lifecycle.md`](relay-data-lifecycle.md) prohibits retention of disconnected-user data, even in memory. The original live-instance relay ban policy below is historical. Cleanup and client-owned reconnect admission are now implemented: admins hold local ban policy, the relay clears disconnected-target bans and cached requests, and moderated joins require all current admins' fresh approval. Missing policy or moderator support fails closed. See the lifecycle document for limitations and wire IDs 21–23.

Originally planning only; implementation is now present. The original baseline and proposed phases below are retained as historical design context, not a description of current gaps.

### Implementation status

Navigation update: Active Instance and World Explorer are now lazy-opened subpages of Home, selected from the first two cells of its expanding 2×2 grid below the status selector. The bottom cells are empty placeholders. Top-level tabs are Home, Friends and Settings; the original standalone-tab wiring below is historical. Back restores the grid and focus; hiding Home releases its open subpage and subscriptions.

Session access update: all five types are selectable. Public permits ordinary joins; Private is closed; Friends permits direct mutual friends of current admins; Friends+ adds one connected mutual-friend hop; Request lets direct admin friends request admission, with Allow/Decline rows in the admin's Active Instance menu and a 60-second deadline. Code-based authorized lookup stages the correct world without publishing non-public instances. Existing membership is preserved on rejection. Client and relay require new explicit packet IDs 25–27. See `docs/friend-system-roadmap.md` for active-edge and same-relay constraints; the original unavailable-mode policy below is historical.

Implemented: Active Instance labels in shared/desktop menus, relay-authoritative full rosters with self and account fingerprints, clickable existing profile views, admin-only metadata editing with Save/Cancel and conflict detection, confirmed kick/ban/promotion, reliable revisioned snapshots, correlated/deduplicated management results, relay authorization and target-identity guards, live-instance account bans, eviction cleanup without relay disconnect, refresh and timeout recovery. Discovery reflects metadata/type edits on its next refresh. The resource paths remain `share_session_menue` for scene compatibility.

Client and relay must both be updated: explicit packet IDs 17–20 add management requests/results, instance snapshots and eviction events. Older relays cannot provide management state; the client exposes a refresh/timeout error rather than granting local admin rights. The code is not a private-instance invite/access implementation: only Public and Private can be selected, and new Private joins remain denied. Bans are in-memory for the live instance lifetime, not persistent relay-wide bans.

Verification runs through `python3 tests/active_instance/run.py` and the three existing isolated regression runners. Test coverage/results and remaining manual/release checks are documented in `tests/active_instance/README.md`. Full-renderer/XR visual and multi-client listening checks remain manual and have not been performed for this change.

Replace the user-facing **Share Session / Session Share** menu with **Active Instance**. It must show everyone connected to the local player's exact instance, open a player's account/profile menu when clicked, and let instance admins manage participants and instance details.

An instance is identified by `session_id` on the connected relay, not by world URL. Two instances of the same world must never share rosters, admin permissions, bans or edits.

## Required player experience

### Header, above the player list

- Title: **Active Instance** on desktop and VR.
- Show the instance name, description, session type and read-only session code, with a **Copy code** button. The displayed/copied code is the acknowledged active `session_id`, not a world URL or a pending destination.
- Admins can edit the name and description and change the session type. Other participants can read these fields but cannot edit them.
- Use an explicit **Save / Cancel** flow. Show pending, success, validation and permission errors without pretending a rejected edit was saved.
- Show a player count derived from the complete authoritative roster.

Suggested layout (not a final visual design):

```text
Active Instance
Instance name                              [Edit]*
Session code: Ab12C                         [Copy code]
Session type: Public                       [Change]*
Description …                              [Edit]*

Players (3)
[Alice — You]             Admin
[Bob]                    Member     [Kick]* [Ban]* [Make admin]*
[Charlie]                Admin      [Kick]* [Ban]*

* Available only to an authorized instance admin and an eligible target.
  Clicking a player's name opens that account's existing profile menu.
```

### Player list and profile navigation

- Show **all current instance participants, including yourself**, exactly once. Do not list everyone connected to the relay or depend on whether an avatar has loaded.
- Each row shows the profile display name, a You marker where applicable, and an Admin/Member badge. A short fingerprint can disambiguate identical names; display names are never action identifiers.
- Clicking the name opens `scenes/GUI/profile_menue.tscn` through its existing `open_profile(SaveData.profile, fingerprint)` API. Other users remain read-only; self editing continues to use profile-service ownership checks. Instance admin status must not grant account/profile editing rights.
- Back returns to Active Instance, restoring the roster and sensible scroll/focus position. If the viewed player leaves, show the existing unavailable-profile state rather than opening a different account that reused the same peer ID.
- Render a placeholder row if signed profile data is not available yet; a missing profile must not remove an actual participant from the count. Open a safe unavailable/loading profile state until verified profile data arrives.
- Refresh on joins, departures, profile updates, role changes and successful metadata updates. Opening/reopening the menu immediately renders the current snapshot without waiting for another player to join.
- No active instance, loading, transitioning, disconnected and request-error states must be explicit. Do not retain actionable rows or a copyable stale code after eviction/disconnect.

### Admin actions beside player names

- **Kick** removes the target from this instance immediately. It does not ban their account; a later authorized join is allowed.
- **Ban** removes the target and denies further joins to this instance for the same authenticated account, including after reconnecting with a new peer ID.
- **Make admin** grants the target instance-management rights and updates every participant's role display. It does not grant relay-wide or profile-editing privileges.
- Confirm kick, ban and admin promotion using the selected name plus stable account identity. Disable duplicate submissions and report the relay result.
- Normal members cannot issue these actions, even by manually constructing packets. UI visibility is not authorization.

## Current code and gaps

| Area | Current behavior / required change |
| --- | --- |
| `scripts/GUI/share_session_menue.gd` | Subscribes to `multiplayer.peer_connected/disconnected`, uses placeholder names and `multiplayer.is_server()`, and calls direct peer disconnection. `load_id()` is empty; Copy accesses the nonexistent `NetworkHandler.tube_client`. Replace these obsolete paths with relay-backed state and requests. |
| `scenes/GUI/share_session_menue.tscn` | Contains a read-only session-code field, Copy button and roster container, but no instance metadata or profile navigation. |
| `scenes/GUI/menue.tscn` | Tab title and metadata use `Session Share`. |
| `scenes/player/player_desktop.tscn` | Overrides tab 2 with `Share Session`; changing only the shared menu would leave the desktop label wrong. |
| `scripts/multiplayer/network_handler.gd` | Tracks acknowledged `current_session_id`, transition state and `participants_changed`, but has no complete active-instance metadata/role snapshot or management API. `participants_changed` currently follows profile updates/disconnect, not every membership change. |
| `relay_protocol/relay_peer.gd` | Holds remote peer IDs and session-scoped profiles. No active-instance metadata/permissions, management acknowledgements or eviction events exist. |
| `scripts/multiplayer/relay.gd` | Owns instance membership and metadata. Creation assigns `owners: [creator_peer_id]`; departure removes owners and promotes the first remaining peer if needed. No kick, ban, promotion or metadata-update handlers exist. |
| `relay.gd:notify_session()` | Sends other peer IDs, excluding the recipient, plus profiles. This is not a full roster with self, stable identities and roles. |
| `scripts/GUI/home_menue.gd` | Already opens profiles by fingerprint and renders remote-profile buttons. Reuse that navigation pattern, but do not mistake its signed-profile cache for a complete membership roster. |
| `scripts/profile/profile_service.gd` | Owns local/remote profiles and enforces self-only editing. Remote profiles can be absent if invalid/unsigned; membership must remain independent. |
| `relay_protocol/packet_info.gd` | Existing modes are `PUBLIC`, `PRIVAT`, `FRIENDS`, `FRIENDSP`, `REQUEST`. Wire IDs and compatibility spellings must remain unchanged. |

## Proposed policy defaults

These are implementation recommendations, not existing guarantees. Confirm changes to these defaults before implementation.

1. **Roles:** use Member and Admin initially; the creator starts as Admin. Treat the relay's existing `owners` list as the source to migrate/adapt, not a reason to add a separate conflicting client-side admin list.
2. **Admin capabilities:** every admin can kick/ban another participant, promote a member, and edit instance metadata. Other admins may be kicked/banned; there is no protected creator role in this initial model. Hide self-kick, self-ban and promotion of an existing admin. Admin demotion, ownership transfer and unban management are follow-up features, not implied by Make admin.
3. **Admin departure:** preserve the current fallback policy: if the last admin leaves and members remain, the relay promotes the first remaining participant. Apply it consistently to voluntary transitions, disconnects and moderation, and broadcast the resulting roles. Delete an empty instance.
4. **Ban scope/lifetime:** store bans by authenticated public-key fingerprint, within the instance, for that live instance's lifetime. They survive target disconnect/reconnect but not instance deletion or relay restart. Persistent bans need a separate storage/recovery design. A newly created account is a different identity; this is not device-level abuse prevention.
5. **Kick/ban destination:** remove instance membership without disconnecting the entire relay connection. Clear the evicted client's active-instance, profile, avatar and voice state; stop sending world data and show a clear removal reason with a route back to World Explorer. Never silently auto-rejoin, auto-host or fall back to another instance. The local world may remain visible, but must be marked offline until an explicit successful join/create.
6. **Session types:** expose friendly labels while preserving enum spellings on the wire. Public is currently joinable; the relay denies new non-public joins because invite/friend/request authorization does not exist. Initially allow Public and Private (display `PRIVAT` as Private, with a clear warning that new joins are currently unavailable), and show other types as unavailable until real authorization is implemented. A code alone does not grant private access. Changing type does not evict existing members or change the session code/world.
7. **Editable fields:** name, description and supported session type only. Keep session ID and world URL immutable. Reuse current creation limits (name 1–128 characters, description up to 2,048), reject whitespace-only names, and use one relay validation policy for create and update. Apply consistent packet byte limits as well as field limits.

## Implementation order

### Phase 1 — Define authoritative instance state and protocol

Add a member-only active-instance snapshot, separate from public discovery. Proposed fields/APIs below are contracts to implement, not existing APIs:

```text
instance snapshot:
  session_id, revision, world_url, name, description, mode
  members: [{peer_id, fingerprint, role}]  # complete roster, including recipient

management request:
  request_id, session_id, expected_revision, action
  target_fingerprint (moderation), target_peer_id (online-target guard)
  changes (metadata update only)

management result:
  request_id, session_id, success, error_code, message, resulting_revision

eviction event:
  session_id, reason (kicked/banned), message
```

- Derive requester identity from the authenticated connection, never from a claimed actor field. Bind member fingerprints to relay authentication, not to client profile payloads.
- Scope snapshots to members of the exact instance; keep full rosters, roles and bans out of public discovery responses. Do not broadcast ban lists to ordinary members.
- Use reliable messages, bounded decoding, explicit new unused packet IDs and strict schemas. Do not reorder existing IDs. Coordinate client/relay rollout; unsupported older relays must leave management unavailable with a useful error rather than report success.
- Define a monotonically increasing per-instance revision and reject stale management requests with a refreshable conflict. Increment it for membership, role and editable-metadata changes. Validate exact target membership and identity again at execution time, including peer-ID reuse.
- Snapshot installation must be tied to acknowledged membership: handle snapshots arriving during world activation and discard data from departed sessions, old connections or older revisions. Do not let management results pass through the existing join/create handler that resets profile/session state on success.
- Provide initial state after create/join and a refresh/resynchronization request for reopening or conflicts. Correlate results by request ID; bounded retries of the same request must not apply the operation twice.

**Acceptance:** packet round-trips; malformed/oversized input rejected; self present exactly once; two same-world instances stay isolated; late or mismatched state/results cannot change the active instance.

### Phase 2 — Relay authorization and lifecycle

- Implement relay handlers for metadata update, kick, ban and admin promotion. Check authentication, active session, admin role, supported action, revision and target eligibility before changing anything.
- Check bans before admitting a join, even for a known session code or a reconnecting account. A rejected join must preserve the requester's previous instance.
- Apply successful mutations once, advance the revision, send a correlated result and publish the updated member snapshot. Kick/ban must notify the removed client as well as remaining members; deny their movement/voice forwarding immediately after removal.
- Preserve the existing one-instance-per-peer rule, cleanup of empty sessions and last-admin fallback. Keep unrelated relay connections/instances unaffected.
- Metadata edits must update discovery summaries on the next refresh: a public-to-private instance disappears, and newly public metadata appears. Never publish private membership data. Do not claim instant browser updates unless a discovery push/invalidation path is also added.
- Bound/rate-limit management requests and retained deduplication entries. Return stable errors such as unauthorized, wrong instance, stale revision, target gone, banned, invalid metadata and unsupported mode.

**Acceptance:** forged/non-admin/cross-instance requests fail without mutations; reconnect cannot evade a ban; peer-ID reuse cannot redirect an action; duplicate requests are safe; last-admin departure and concurrent actions produce consistent state.

### Phase 3 — Client state and profile integration

- Add a single active-instance state owner to `NetworkHandler`, with an instance-changed signal and request methods. `RelayPeer` decodes/transports packets; UI does not become a second permissions or membership authority.
- Build the roster from authoritative membership and enrich rows from `SaveData.profile`. Use the local profile for self and verified remote profiles for others; role badges come only from relay state.
- Update participant notifications for every membership change, including departures without a subsequent profile event. Keep scene/avatar loading independent from roster completeness.
- Track pending management requests separately from world transitions. Disable actions while switching instances, cancel drafts/confirmations on instance change, and clear state on eviction or disconnect. A late result must not edit another instance or complete a join.
- Handle timeout as an uncertain outcome: do not optimistically remove/promote players or blindly repeat a mutation with a fresh request ID. Resync authoritative state, mark unavailable if that fails, and make retry/error behavior explicit.
- Reuse the profile scene with an Active Instance-owned Back route, cancel stale editor/media work on departure, and retain `SaveData.profile.can_edit()` as the only profile-edit permission check.

**Acceptance:** profile changes update names without duplicating rows; missing/invalid profiles preserve membership; reconnect/switch/eviction clears stale UI; admins cannot edit someone else's account.

### Phase 4 — Menu replacement and metadata controls

- Rename the visible title to **Active Instance** in the shared menu tab, tab metadata and desktop override. Check the VR scene's inherited wiring too.
- Prefer retaining existing `share_session_menue` resource paths/node names initially to minimize scene-path breakage; visible renaming does not require a filesystem rename. If later renamed, update all references, UIDs, translation inputs and `project.godot` scene references together.
- Replace the obsolete MultiplayerAPI/direct-disconnect paths and the broken Copy property access. Populate the read-only code from acknowledged active state and disable Copy when no valid instance is active.
- Add header metadata and admin-only editing, then a scrollable roster with clickable names, role badges and adjacent Kick/Ban/Make admin buttons. Keep confirmation dialogs separate from profile navigation.
- Preserve unsaved drafts while roster/profile refreshes occur, but detect metadata conflicts and offer reload rather than overwrite another admin's edits. Clear drafts on instance switch or permission loss.
- Connect callbacks before initial state requests, unsubscribe on teardown and avoid duplicate signals on reopen. Preserve keyboard/controller focus and scrolling where possible.

**Acceptance:** real scene button presses open the correct profile, copy the correct code and send the correct target/session requests; every visible label says Active Instance; ordinary members have no editable metadata or moderation controls.

### Phase 5 — Isolated verification and manual release checks

Add `tests/active_instance/run.py`, `suite.gd` and a README following the existing disposable-project runners. Copy production menu/profile/coordinator/relay/protocol dependencies and use fixture autoloads; never launch normal startup against real account data. Use headless Compatibility rendering and loopback ENet on ephemeral ports.

Required automated coverage:

- Complete initial roster including self; live join/leave/profile/role updates; empty/no-instance/disconnected/reopen states; duplicate names and profiles arriving late or failing signature validation.
- Real profile button navigation, Back, self versus remote edit ownership, user departure while profile is open, and a reused peer ID with a different fingerprint.
- Metadata visibility, Save/Cancel, length/byte/type validation, stale drafts, permission loss, simultaneous admins and discovery changes after visibility/name/description edits.
- Member, unauthenticated, cross-instance, forged-identity and stale-target moderation attempts; promotion and immediate permission refresh for all members.
- Kick followed by permitted rejoin; ban followed by denied reconnect with the same account; no ban bleed into a second instance of the same world; ban removal when its instance is deleted.
- Eviction clears membership/profiles/avatars, stops sending/receiving instance voice/movement and never auto-hosts; other relay sessions remain connected.
- Missing/duplicate/late management results, same-ID retries, timeouts, out-of-order snapshots, transitions during requests, relay loss and unsupported protocol versions.
- Real relay integration with at least four clients: admin and member in instance A, a member in instance B using the same world URL, plus a reconnecting/banned target. Exercise actual encoded requests, not only direct relay helper calls.

Run regression suites after implementation:

```sh
python3 tests/active_instance/run.py  # planned runner; does not exist yet
python3 tests/profile/run.py
python3 tests/public_discovery/run.py
python3 tests/microphone_settings/run.py
```

Treat assertion failures and Godot runtime/import errors separately; check skipped groups. No historical check count is a current pass claim. Manual desktop and VR checks must cover readability, long names/descriptions, row scrolling, controller focus, confirmations, Back/reopen, clipboard behavior and multi-client listening after eviction. Isolated tests do not validate the full XR/renderer stack.

## Completion criteria

- Desktop and VR expose **Active Instance**, with the current code and metadata above a complete, live, instance-scoped player list.
- Every participant can open the correct account profile; only its owner can edit it.
- Admins can kick, ban, promote and change supported metadata; unauthorized clients cannot bypass relay checks.
- Bans survive reconnect for the life of the instance, successful edits propagate to members/discovery as appropriate, and no action affects another instance of the same world.
- Loading, conflicts, timeouts, eviction and disconnect never leave stale permissions or a falsely active session. Automated integration/regression checks and manual desktop/VR results are recorded before release.
