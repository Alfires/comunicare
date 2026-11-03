# Local contacts and mutual friendship roadmap

## Status and scope

Implementation is now present. The baseline and phases below retain the original plan as historical design context; they are not a statement that the APIs are still absent.

### Implementation status

Implemented: dedicated Friends tab before Settings; save/add-by-public-key with fingerprint review; account-scoped signed local store; signed request/explicit acceptance and durable receipts; decline/cancel/remove/block; client-local retry queues and revocation tombstones; Online/Offline/Do Not Disturb selectors in Friends and Home; mutual-live-authorization presence with expiry, generation and sequence checks; profile Save contact/Add friend actions; cached read-only friend profiles; relay disconnect cleanup without permanent social data. Authentication advertises social support and explicit wire ID 24 routes social packets. Update client and relay together.

Incoming requests are inbox-only (no unsolicited popup/sound, including in DND). Initial bounds are 128 contacts, 2,048 relationship/outbox entries and bounded rotating event retry batches. Local history compaction, multi-device/key migration, cross-relay presence, invitations and friends-only instance access remain out of scope. Display-backed and loopback acceptance coverage and exact limits are documented in `tests/friends/README.md`; manual headset/controller and full XR startup checks remain pending.

**Project-wide constraint:** [`relay-data-lifecycle.md`](../relay-data-lifecycle.md) governs every feature. The relay never stores user data durably and removes all data/references for a user on disconnect. Persistence, offline queues, friendship history and block/revocation records stay on clients.

Goal: let users save another account's **public key in a local, persistent list**, become friends **only when both accounts explicitly consent**, and see friends' **Online / Offline / Do Not Disturb** status.

Important distinction:

- **Saved contact:** a public key stored on your device. This is unilateral and grants no permissions or presence access.
- **Friend:** an account with a mutually accepted friendship. Saving a key, receiving a request or clicking Send is not enough on its own.

Initial scope is a single device/account store, communication through the currently connected relay, and mutual-friend presence on that relay. Cross-relay delivery/presence, account synchronization, location sharing and friends-only world authorization are separate work. Persistent server mailboxes are prohibited by the project-wide relay lifecycle rule, not a later optional feature.

## Required user experience

### Dedicated Friends tab

- Add a new top-level **Friends** tab to the main menu alongside Home, World Explorer, Active Instance and Settings. Use the same label and page on desktop and VR; this is not a subsection of Settings or Active Instance.
- Menu order: **Home → Friends → World Explorer → Settings**. Friends remains the second tab. Below Home's status selector, an expanding 2×2 grid contains World Explorer (top left), Active Instance (top right), and two empty bottom tiles. World Explorer is also a top-level tab; its Home tile selects that shared tab rather than creating a duplicate browser. Active Instance opens a Home subpage with Back navigation. Preserve existing scene resource paths and update inherited tab-index/title overrides when navigation changes.
- Opening Friends shows the self-status selector and sections for **Friends**, **Incoming requests**, **Outgoing requests** and **Saved contacts**. Each section needs a clear empty state; show loading, unavailable relay and recoverable storage/network errors separately.
- Include **Add public key** and **Refresh** actions. Mutually accepted friend rows show Online/Offline/Do Not Disturb (or Status unavailable), and clicking a name opens the existing profile view. Back from that view returns to Friends with selection, scroll and keyboard/controller focus restored where possible.
- Keep local contacts and friendship records readable without a relay connection. Disable only actions that require live delivery; do not empty the tab on disconnect or world/instance changes.
- Refresh visible state through service signals, avoid duplicate subscriptions on reopen, and clear account-specific rows/drafts immediately when switching local accounts.

### Add by public key or existing profile

1. Open a **Friends** page with Contacts, Incoming requests, Outgoing requests and Friends sections.
2. Choose **Add public key**, paste the complete public key, and review its fingerprint. Optionally set a private local nickname.
3. **Save contact** stores it locally without notifying its owner. **Send friend request** explicitly consents to friendship and attempts delivery to that account.
4. Also expose **Save contact / Send friend request** near the top of another user's existing profile overview. Bind actions to the displayed canonical key/fingerprint, never their name or current peer ID. Show sent/already-friends state and disable duplicate requests or blocked accounts.
5. The recipient sees who requested friendship, with a fingerprint and **Accept / Decline**. Accept records the recipient's explicit consent; only the matching consent pair creates friendship.
6. Show progress honestly: Saved locally, Waiting for user to connect, Sent, Incoming request, Accepting, Friends, Declined, Cancelled, Removed, Blocked or Needs synchronization. A delivery acknowledgement is not acceptance.

Names and images are descriptive, not proof of identity. Display a short fingerprint alongside ambiguous names and offer full public-key inspection/copy. A manually entered key has no verified profile until an owner-signed profile is available. Confirm the fingerprint through a trusted channel when identity matters; a signature proves key ownership, not a real-world identity.

### Manage relationships

- Allow cancel of an outgoing request and decline of an incoming request without forming friendship.
- Allow **Remove friend** without the other user's approval. Revocation takes effect locally immediately; show that the remote copy may be stale until synchronization.
- Allow **Block account** locally to stop its requests. Blocking revokes local friendship consent; it is not an instance ban or a relay-wide account ban.
- Keep removing a saved contact distinct from removing friendship. If a contact has pending/friend state, require cancellation/revocation before deleting its contact record; preserve the necessary synchronization tombstone.
- Closing/reopening the menu, restarting or disconnecting must not lose contacts or turn pending requests into friends. Switching the loaded account must immediately show that account's list only.
- Do not automatically load remote avatar/media URLs for a new incoming request. Reuse the existing profile menu and media privacy behavior where appropriate.

### User status: Online / Offline / Do Not Disturb

- Show a labelled status beside every mutually accepted friend in the Friends page and their profile view. Use text and an icon/color together, not color alone. Saved contacts and unaccepted requests show **Status unavailable**, not an inferred online state.
- Add a self-status selector to Home/Friends: **Online**, **Do Not Disturb**, and **Offline (appear offline)**. Persist this preference per local account; default to Online when no preference exists. Actual connection loss always makes the user unavailable regardless of preference.
- **Online:** authenticated and reachable on the connected relay, with current authorized presence evidence.
- **Do Not Disturb:** still connected and reachable, but requesting no interruptions. Suppress unsolicited friend-request/invitation popups and notification sounds; keep requests in the inbox and allow explicit user actions. Do not mute microphone/voice, auto-decline requests or change world membership.
- **Offline:** no current authenticated presence on this relay, or the user chose to appear offline. Friends must not be told which case applies. Appearing offline does not disconnect the game, revoke friendship or guarantee anonymity to players sharing the same instance.
- Use **Status unavailable / reconnecting** when the viewer loses the relay, capability support is absent, presence expires or synchronization is incomplete. Never present stale cached Online/DND as live, or claim a user is globally offline just because another relay cannot be queried. Tooltip/help text explains the same-relay scope.
- Update status after authentication, preference changes, disconnect/timeout, friendship establishment/removal and blocking. Status changes must not require reopening the page. Never expose instance ID, world URL, last-seen time or contact lists through presence.

## Current code baseline

| Area | Existing behavior / integration point |
| --- | --- |
| `scripts/profile/profile_identity.gd` | Canonical public-key parsing, SHA-256 fingerprints, owner-signed profiles and signature verification already exist. Reuse canonical identity helpers, but give friendship its own signed message format. |
| `scripts/profile/identity_authenticator.gd` | Proves private-key possession per connection, rejects replayed/expired challenges and duplicate live accounts on one relay. Relay routing can rely on this verified mapping, not a claimed actor field. |
| `scripts/settings/save_data.gd` | Loads the account key, then initializes a key-scoped signed profile and emits `account_ready`. No contacts/friends store exists. Preserve mute/settings initialization ordering. |
| `scripts/profile/profile_service.gd` | Stores owner-editable local profiles and instance-scoped verified remote profiles. Do not put friendship into profile fields or treat remote-profile presence as friendship. |
| `scripts/GUI/profile_menue.gd` | Opens by account fingerprint and enforces self-only profile editing. Friend controls are separate actions; friendship must not grant profile edit access. |
| `scripts/GUI/home_menue.gd`, `scenes/GUI/menue.tscn` | Existing navigation and profile entry points; add a dedicated top-level Friends tab and update desktop/VR inherited tab-index/title overrides without restoring profile fields to general settings. |
| `scripts/multiplayer/relay.gd` | Has authenticated key mappings, instance-scoped profiles/membership and instance moderation. No account-addressed friend-request delivery or offline mailbox exists. |
| Presence | No friend-presence subscription, privacy enforcement, freshness tracking or Online/Offline/DND preference exists. Authentication is a connection fact, not permission to publish it to arbitrary users. |
| `relay_protocol/packet_info.gd` | Explicit packet IDs through instance-management ID 20; no friendship packet types. `FRIENDS` and `FRIENDSP` modes exist, but their authorization is not implemented. Preserve IDs and legacy spellings. |

## Recommended initial policies

These defaults are proposals to confirm before implementation.

1. **Account-owned local storage:** use a separate friend service owned by `SaveData`, initialized only after successful account-key loading. Proposed path: `user://friends/<local_fingerprint>.cfg`. Do not use general settings or signed public profiles as the contacts database.
2. **Local-first, explicit delivery limits:** contacts and outgoing intent persist locally even when the recipient is offline. Initially deliver only when both accounts are authenticated on the same relay, including different instances. Retry/synchronize on authentication and explicit refresh. Do not claim offline delivery or successful friendship while the recipient is unreachable.
3. **Mutual consent:** sending a request is the sender's consent. Accepting that exact request is the recipient's consent. Incoming requests never auto-accept merely because the sender was saved as a contact. Crossed requests should surface an explicit Accept action instead of silently becoming friends.
4. **Limited presence sharing:** mutual friendship permits basic status sharing on the same relay, subject to appear-offline, revocation and block rules. It grants no location, world access, voice bypass, moderation role or profile edit rights. Saving a contact alone never grants presence access.
5. **Revocation wins for that relationship:** cancellation, removal or blocking invalidates that relationship ID. A delayed acceptance cannot restore it; starting again requires a fresh request and fresh acceptance. Unblock alone does not restore friendship.
6. **No hidden cloud backup:** losing the local account key means losing control of that identity. Changing keys is a different account; never merge contacts based on matching names. Backup/export and multi-device synchronization need an explicit later design.

## Data and consent contract

Keep storage, signed events and transport acknowledgements separate. Names below are proposed APIs/data, not existing code.

### Local store

```text
schema_version
owner_public_key, owner_fingerprint
store_revision, owner_signature
preferred_status: online | do_not_disturb | offline
contacts keyed by canonical remote-key fingerprint:
  public_key, local_nickname
  optional last verified owner-signed profile (labelled cached/stale)
  relationship records and verified signed events
  durable outgoing-delivery queue
  local block state, revoked relationship tombstones
```

Derive effective relationship state from validated consent/revocation records, not an editable `is_friend = true` flag. Verify owner binding, schema, signatures, bounds and all key/fingerprint pairs when loading. Keep private keys out of this store and all packets. A signed store detects edits, not replay of an older valid backup; document rollback limits rather than claiming full rollback resistance.

Write through a temporary file and atomic replacement. Acknowledge a received event only after safely persisting it; signing/persistence failures must preserve the previous usable state and expose an error. Preserve corrupt, unsupported-version, wrong-account or signature-invalid files for recovery rather than replacing them with an empty list. Bound entry counts, queue sizes, event sizes and load costs; define compaction only after revocation correctness is covered.

Store only the self-status preference durably. Remote live-presence state belongs in a separate volatile cache; a restart must not restore a friend as Online from disk.

### Signed friendship events

Use a dedicated versioned, domain-separated encoding with a fixed field order (for example `comunicare/friendship/v1`). Do not reuse profile/authentication signing bytes. Proposed fields:

```text
event_id: cryptographically random unique ID
relationship_id: fresh cryptographically random request ID
kind: request | accept | decline | cancel | revoke
actor_public_key, recipient_public_key
request_digest: exact signed request reference for replies
signature: actor's signature over all semantic fields
```

- Verify canonical keys, sender/recipient distinction, actor signature, recipient ownership and the exact request reference before changing state. Reject self-add, private-key PEM input, malformed/oversized keys, unsupported schema and unknown event kinds.
- `accept` must be signed by the request's recipient, reference the same request and target the original sender. A friendship proof consists of that valid request plus the valid matching acceptance, with no known revocation for that relationship.
- Either participant can revoke an accepted relationship. Only its initiator can cancel an outgoing request; only the intended recipient can accept/decline it. Preserve terminal-state records so an old request or acceptance cannot resurrect a removed relationship.
- Persist an incoming acceptance as **Accepting / awaiting delivery** until the signed acceptance is durably accepted by the sender. Both signatures are the consent evidence; the receipt only reports synchronization, not an extra approval. A lost receipt is retried idempotently.
- Deduplicate by event ID and content digest. Same ID/different payload is an error. Do not order distributed events by wall clock alone; use explicit relationship references and terminal-state precedence. Newly established friendship must use a fresh relationship ID.
- Do not pretend removal is instantly known to an offline peer. Resynchronize known relationship events/tombstones before presenting an old relationship as freshly confirmed. Locally known revocation/blocking always takes precedence.

### Relay transport

- Add bounded reliable account-addressed delivery, delivery receipts/results and capability negotiation using explicit unused packet IDs. Preserve all existing IDs and coordinate client/relay rollout.
- Authenticate both endpoints. Compare the signed actor key with the connection's verified account; derive the sender from the connection, not a user-supplied actor ID. Resolve recipients by canonical key/fingerprint, never a transient peer ID.
- Route only to the intended authenticated account. A friend request is deliberately allowed across instances; this must **not** turn instance profile snapshots into relay-wide profile discovery. Include only the requester's minimal signed identity/profile data when they send it, with their explicit action.
- Rate-limit per account/connection and recipient, constrain retries and queued records, and distinguish delivered, unavailable, rejected, throttled and unsupported. Avoid an unauthenticated account-existence/presence oracle.
- The relay is transport, not a source of either user's consent. It must not forge acceptance, grant friendship from a client boolean, broadcast contact lists, or receive the user's complete local address book.
- Offline events remain in the sender's local queue. No relay-persistent mailbox is permitted. On disconnect, discard all pending relay deliveries and caches identifying either disconnected endpoint, including records stored under another account's connection; client queues handle later retries.

### Authorized presence contract

- Use explicit bounded presence publish/subscribe/update messages and capability negotiation, separate from signed friendship events. The relay derives the publishing account from authenticated connection state; a client cannot publish another account's status.
- Keep preferred status separate from effective presence. Online/DND can only be effective while authenticated; appear-offline always advertises Offline to authorized friends. Disconnects and expired connection liveness invalidate live presence using a documented bounded timeout.
- A subscription requires a verified matching request/acceptance proof and current consent from **both live endpoints** for that exact relationship. Each endpoint must confirm the relationship against its local unrevoked/unblocked state for the current relay connection. A subscriber presenting an old consent pair alone is insufficient. If the target is absent, never expose an old status as live.
- On account login/reconnect, initialize presence sharing to denied until relationship synchronization and both endpoint authorizations complete. This avoids briefly leaking status from a replayed friendship proof before a locally saved removal/block is applied. Do not upload the whole address book; authorize only the relevant mutual relationships.
- Removal/block immediately stops local publication/subscription for that pair, tells the relay to revoke its routing authorization and clears the cached remote status. The other party receives a neutral unavailable state rather than a block-revealing message. Unblock requires a fresh mutual friendship before subscriptions resume.
- Bound the relay's temporary relationship authorizations, subscription fan-out and update rate. Authorization is connection-scoped and must be rebuilt after relay restart or connection replacement. If either endpoint disconnects, delete the pair's authorizations, proofs, subscriptions and pending events from all relay-owned structures. No persistent relay social graph is permitted.
- Include subject fingerprint, connection-generation/subscription identity, monotonic sequence and bounded freshness in updates. Discard old/out-of-order updates and updates for removed relationships or previous connections. Use local monotonic receipt times for expiry, not remote wall-clock timestamps alone.
- Friend UI displays Online/DND only with fresh authorized evidence. Clearing an old status on viewer disconnect is different from receiving authoritative Offline for the subject. Old relays show Status unavailable without breaking saved contacts or friendship.
- Appear-offline changes presentation, not transport reachability. Friend-event delivery results must not identify whether Offline means disconnected or hidden; queues/receipts still must not claim an offline delivery was made when it was not. Co-presence, timing and deliberate replies can reveal activity; document these limits rather than promising invisibility.

## Implementation order

### Phase 1 — Red tests and local contact store

- Add an isolated `tests/friends/run.py` suite following the existing disposable-project pattern; fail on real behavioral assertions rather than unconditional placeholders.
- Implement a key-scoped friend service and storage format, initialized after account load without changing settings/microphone ordering.
- Implement canonical-key add, duplicate detection, local nickname, list/remove and safe persistence. Return copies rather than exposing mutable internal state. Validate ownership at the service boundary, not just in UI.
- Verify restart, account switching, corrupt/wrong-owner data preservation, failed writes and no public/private-key leakage before adding network requests.

### Phase 2 — Mutual-consent state machine

- Implement signing/verification, request, accept, decline, cancel, revoke and local block behavior independently of transport.
- Persist local intent before enqueueing. Persist verified incoming events before delivery acknowledgement. UI must distinguish unsigned/unverified input, durable state and delivery progress.
- Cover crossed requests, duplicate delivery, conflicting event IDs, delayed messages, acceptance after cancel, removal during acceptance, unblock and new friendship after revocation.

### Phase 3 — Account-addressed relay delivery and synchronization

- Add protocol codecs/capabilities, authenticated routing, results, bounded idempotent retry and reconnect synchronization in relay, `RelayPeer` and coordinator together.
- Keep friendship requests separate from world transitions and instance-management request/result handlers. Joining/leaving worlds does not clear the persistent friend store or redirect a request.
- Support two authenticated accounts in different instances of the same relay; deny spoofed actor/recipient identities and cross-account delivery. Surface offline/unavailable status without marking a request accepted.
- Preserve pending state through relay restart/replacement; do not automatically send the whole contacts list. Synchronize only explicitly pending requests, responses and relationship changes with their intended counterpart.

### Phase 4 — Authorized presence and DND behavior

- Implement persistent account-scoped self preference, volatile effective status/cache, authenticated publication and consent-gated pairwise subscriptions.
- Add freshness expiry, connection-generation filtering, relay disconnect cleanup and privacy-first reauthorization on reconnect.
- Wire DND into social notification presentation only. Check it does not change the shared voice owner, mute settings, relay membership or pending friend requests.
- Test appear-offline and removal/block races before exposing status badges. Preserve same-relay scope and keep location/last-seen sharing out of the protocol.

### Phase 5 — Friends page and profile actions

- Create a dedicated Friends page scene/script (proposed: `scenes/GUI/friends_menue.tscn` and `scripts/GUI/friends_menue.gd`) and instance it as a new top-level tab in `scenes/GUI/menue.tscn`. Set its title and tab metadata to Friends; check desktop overrides, VR menu construction, reset/back behavior and translation inputs when tab indices change.
- Implement the tab layout described above: self-status selector, Add public key/Refresh, friends with status badges, incoming/outgoing requests and saved contacts, with explicit empty/offline/error states.
- Reuse the existing profile view without weakening owner-only editing. Cached friend profiles must live separately from `profile_service.remote`, which is cleared on instance changes and currently represents same-instance data.
- Wire explicit Send/Accept/Decline/Cancel/Remove/Block actions, confirmation, pending/disabled controls, useful errors, Back and refresh. Preserve drafts on network errors and selection/focus on list updates.
- Make cached friendship/synchronization state distinct from live presence. Add Online/Offline/Do Not Disturb badges, Status unavailable fallback and the self-status selector; never display instance locations.

### Phase 6 — Hardening and release checks

- Run real loopback relay tests with multiple authenticated clients in separate instances, reconnect/restart cases and packet-level forgery attempts.
- Add display-backed desktop checks and manual headset/controller checks. Test long names/keys, scrolling, keyboard input, confirmation, repeat clicks and account switch while a request/profile is open.
- Document local-only persistence, backup limitations, delivery limits and revocation synchronization. Record real test results; historical counts in other roadmaps are not coverage of this feature.

## Acceptance tests

Minimum isolated coverage before completion:

1. Saving a valid public key persists exactly one contact across restart; alternate accepted formatting resolves to the same canonical key. Invalid/private/self keys fail without writes.
2. Contacts, labels, queues and relationships cannot leak between two local account keys or be adopted from a different owner's file. A corrupt store is preserved and reports recovery information.
3. Saving a contact creates no friend request. Sending a request creates no friendship. An unverified/forged acceptance or acceptance of another request creates no friendship.
4. A sends a signed request, B explicitly accepts that request, both durably receive/verify the consent pair and show friendship. Closing/reopening/restarting retains the relationship.
5. Decline, cancel, ignored requests and crossed requests never silently create friendship. Duplicate requests/receipts are idempotent and repeated clicks cannot create parallel unintended relationships.
6. Remove/revoke/block takes effect locally immediately. Old acceptance, delayed request, reconnect replay or unblocking cannot resurrect it. A fresh mutual exchange is required to become friends again.
7. An offline recipient leaves an honest queued/unavailable state. Later same-relay delivery completes without user-data loss; relay failure or lost acknowledgements cannot fabricate success.
8. Authenticated clients in different instances can exchange intended friend events, but cannot read each other's contacts, impersonate actors, accept on another user's behalf or receive unrelated account events.
9. Actual profile/page buttons target the correct canonical identity when names match or peer IDs change. Friend status grants neither profile editing nor instance admin rights.
10. Persistence failure while accepting, timeout, reconnect, unsupported relay and malformed/oversized messages preserve state and produce useful errors. Complete suites must distinguish assertion failures from Godot runtime/import failures and report prerequisite skips.
11. Accepted friends on the same relay see fresh Online and Do Not Disturb updates without reopening. Saved contacts, unaccepted requests, unrelated accounts and forged subscribers cannot observe presence or publish someone else's status.
12. Disconnecting a subject produces Offline after bounded liveness detection; viewer disconnect, stale updates and unsupported relay produce Status unavailable instead of cached Online. Reconnect requires fresh relationship authorization; previous-connection and out-of-order updates cannot restore status.
13. Choosing Offline while connected shows Offline to authorized friends without changing game connectivity or revealing the hidden/disconnected distinction in presence packets. Basic status messages contain no world, instance, last-seen or contact-list data.
14. Do Not Disturb suppresses unsolicited social popups/sounds but preserves inbox requests, manual acceptance, microphone state and incoming voice. Preference survives restart and is isolated between local accounts.
15. Remove/block races immediately revoke presence locally and at the relay. Replayed old friendship proofs cannot reauthorize sharing; unblock alone does not restore it. A reconnect must not briefly expose presence before local revocations load.
16. Disconnect either participant and verify no public key, fingerprint, consent proof, presence/subscription or pending event for that user remains anywhere in relay application state, including other users' caches. Local contact/history/outbox files remain intact. Relay restart has no social history and creates no user-data files.
17. The actual main-menu scene exposes exactly one top-level Friends tab on desktop and VR. Selecting it opens the Friends page, preserves correct labels for all other tabs and renders persisted local records even while disconnected. Reopening/world changes do not duplicate rows or subscriptions; account switching removes the previous account's rows/drafts. Profile Back returns to Friends with usable scroll/focus, and Add public key/status controls are accessible with keyboard/controller navigation.

Verification commands:

```sh
python3 tests/friends/run.py
python3 tests/active_instance/run.py
python3 tests/profile/run.py
python3 tests/public_discovery/run.py
python3 tests/microphone_settings/run.py
```

Use in-memory test keys, disposable account stores, headless Compatibility rendering and ephemeral loopback ports. Do not launch normal startup or write real account/contact data during automated checks.

## Friendship-based session access

Implemented: Friends admits direct accepted friends of any **current instance admin**; Friends+ also admits a two-edge chain through a connected mutual friend; Request accepts requests only from direct admin friends and requires a current admin's explicit Allow action. Any current admin may decline; approval still requires all existing moderation-policy checks. Private stays closed. Existing members are not evicted merely because the type or friendship changes.

Checks use matching unexpired authorizations from both authenticated endpoints for each friendship edge, not saved contact keys or a single cached proof. For Friends+, the intermediate friend must also be connected to the same relay; disconnected identities/edges are never retained. Admin departure changes the reference set according to existing relay succession. Final admission rechecks friendship, current admin set, type, bans and world identity.

Non-public instances remain absent from public discovery. Enter their exact session code in World Explorer; an authenticated access-checked lookup resolves the world before staging/joining. Request joins remain pending up to 60 seconds, with Allow/Decline controls in the admins' Active Instance tab; DND does not trigger intrusive popups. Rejection/expiry preserves the candidate's prior instance. Explicit packet IDs 25–27 implement lookup and request decisions; clients and relay must both be updated.

Deferred: invitations, cross-relay/offline friendship-chain evaluation, automatic friend-location browsing and location sharing. Never join by world URL alone, publish private instances publicly, or bypass instance bans because two accounts are friends.

## Completion criteria

- A user can store public-key contacts privately and persistently for their own account.
- A dedicated top-level Friends tab on desktop and VR contains the contact/request/friend lists, status controls and add-by-key action; it remains usable for local records while offline.
- Friendship requires a verified request and the other account's explicit matching acceptance; no unilateral operation grants it.
- Cancel/decline/remove/block, restarts and reconnects preserve correct consent state with honest synchronization status.
- Desktop/VR UI uses stable identities, relay routing is authenticated and scoped, corrupt data is recoverable, and automated/manual results are recorded.
- Friends see privacy-controlled, fresh Online/Offline/Do Not Disturb status; users can select their own preference and disconnect/revocation cannot leave stale live badges.
- Documentation clearly distinguishes saved contacts, mutual friends, basic presence and future location/session-access features.
