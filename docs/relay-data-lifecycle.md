# Relay data lifecycle — project-wide requirement

## Governing rule

The relay is a **temporary, in-memory router for currently connected users**, not a persistent account or social database. This applies to every system: authentication, profiles, instances, moderation, friends, presence, delivery queues, caches and future features.

- Never persist user/session data to files, databases, backups, analytics or durable message queues on the relay. Do not log public keys, fingerprints, profile/event payloads, social relationships or other identifying user data to retained logs.
- Keep only data needed to serve currently connected users. Pending authentication/transport state is temporary connection state and must be bounded.
- On a processed disconnect, remove all data belonging to or identifying that user from relay application state, including references inside other users' caches or shared instance records. Abrupt network loss is detected by a bounded connection/liveness timeout; cleanup runs when that connection is declared disconnected.
- Reconnecting is a new connection. Authenticate again and explicitly republish/reestablish any necessary state from clients. Nothing about the disconnected account is restored from relay history.
- Relay restart starts empty. Permanent account keys, profiles, contacts, consent records, status preferences, moderation policy and undelivered events belong on clients, not on the relay.

This is an application lifecycle requirement, not a claim of forensic memory erasure: OS/kernel buffers, swap, crash dumps and hosting logs require separate deployment controls. Do not promise immediate detection of an unplugged connection or deletion from someone else's client.

## Disconnect cleanup contract

One idempotent cleanup path must remove the disconnected connection's:

1. Authentication challenges, verified account/public-key mappings and associated connection metadata.
2. Profile publications, presence, subscriptions and pairwise authorizations, including surviving users' references to that account.
3. Membership, admin/owner IDs and any per-user world/voice/movement state. Notify remaining members and apply the existing admin-succession policy without retaining the departed identity.
4. Request/result caches, deduplication entries, rate limits, pending deliveries and payloads referencing that user, regardless of which connection owns the outer dictionary. Discard queued traffic that could be delivered to a reused peer ID.
5. Ban records, social proofs, cached keys and any other indirect references identifying the disconnected account.

An instance may continue while other users remain, but its internal metadata must not retain a creator/previous-member identity or historical participant list. Delete empty instances. User-authored name/description fields may contain personal information; when their author leaves, replace or clear that author's contributed fields unless a remaining member explicitly adopts/re-publishes them. A world URL needed by remaining members is active content state, not permission to retain historical authorship data. Audit this boundary explicitly rather than assuming a populated instance makes all its old data permissible.

Never rewrite public keys into hashes and call that deletion: a stable fingerprint is identifying user data too. Unidentifiable aggregate diagnostics may be retained only if they cannot reconstruct a departed user's identity/activity; no per-account historical metrics.

## Consequences for existing designs

### Friends and presence

- Contacts, signed friendship history, removal/block tombstones and offline outboxes are client-local.
- No relay offline mailbox, last-seen history, persistent social graph or durable presence. An unavailable recipient's event remains on the sender's client for later retry.
- Clear both sides' relay subscription/relationship authorizations when either endpoint disconnects. Clients must synchronize consent again before presence resumes.

### Moderation and reconnect bans

The original Active Instance implementation retained banned fingerprints after disconnect and target identities inside other users' management-result caches. That behavior has been replaced: disconnect deletes the target's relay ban entry and clears management-result caches across active users. Only currently connected banned accounts can have a temporary relay ban entry.

Reconnect-ban policy is now held on admin clients at `user://moderation/<account_fingerprint>.cfg`, keyed by a random live-instance moderation ID rather than a reusable room code. Ban events deliver the target fingerprint to current admins, who persist it locally. When a moderated instance receives a new join, the relay sends fresh random-token admission queries to all current admins. Every admin must approve; any denial, missing/unreadable client policy, changed admin set or five-second timeout fails closed and preserves the candidate's old membership. Candidates receive no destination membership/profile/voice access until approval. A disconnected candidate's request is removed; a disconnected participating moderator cancels pending admission.

Client policy is deliberately not uploaded wholesale. This version has no automatic historical-policy handoff to newly promoted/fallback admins: an admin without the policy fails closed. Thus a moderated instance can become closed to new entrants when its remaining admins lack history. This is safer than silently dropping bans; policy transfer/unban UI remain follow-up work. Local policy files are account-bound and atomically replaced, with corrupt/wrong-owner data preserved, but are not cryptographically signed or multi-device synchronized. A local device owner can modify their own policy; the relay does not provide a durable trust database.

### Current status

Implemented in the current relay: idempotent disconnect cleanup, removal of authenticated/public-profile/challenge/rate state and transport peer metadata; deletion of disconnected-target bans; cross-user management-cache clearing; pending-admission cleanup; clearing name/description fields whose last author disconnected; empty-instance removal and existing last-admin succession. Rejected arbitrary management payloads are not retained as deduplication history. Relay startup skips client settings/profile initialization, and server-side per-user logging has been removed. ENet connection timeout is bounded (configured maximum 10 seconds; actual detection depends on transport scheduling).

New wire IDs 21–23 cover admission query/reply and moderator-client policy delivery. Client and relay must both be updated; a moderator client without admission support causes admission to fail closed. No friends/presence implementation exists yet; those future systems must follow the same lifecycle contract.

Verification is in `tests/active_instance/run.py`: actual multi-client cleanup/reconnect/admission traffic, cross-user-cache and fingerprint/key scans, authored metadata reset, duplicate cleanup, fresh-relay state, local policy recovery and file-creation checks. These are application-owned-state checks, not forensic memory erasure or a comprehensive OS-level filesystem audit.

## Verification work

- Use a real loopback relay with multiple accounts. Populate every relevant cache/subscription, disconnect one user and recursively inspect application-owned state for its key, fingerprint, peer references, profile/event payloads and retained authored fields.
- Exercise normal disconnect, liveness timeout, rejected authentication, repeated cleanup, peer-ID reuse, surviving instances/admin succession, pending deliveries and result caches owned by another user.
- Verify that no user data is written by the relay, and that a relay restart has no account/session/social/moderation history. Distinguish static server configuration from user data.
- Revise ban tests to require client-local policy and fresh admission authorization rather than a relay-held disconnected-account ban list.
- Confirm remaining users' unrelated active state still works after cleanup. Run profile, discovery, Active Instance and microphone regressions, plus future friends/presence tests.
# Animation extension (wire ID 28)

The current negotiated animation version is 2: one resolved locomotion/emote
state carries bounded avatar/configuration revisions. Requested model chunks and
motion chunks are typed separately but authorized by that same active state.
Legacy version-1 manual playback control is not accepted. Group layouts, submenu
names, local file paths and configuration drafts are never sent to the relay.

Capability-negotiated animation routing keeps only current connected-user state,
per-connection random generations, rate counters and bounded requested-transfer
metadata. The relay never downloads motion URLs or writes animation files. It
forwards requested chunks directly and forgets completed/expired transfers.
Leaving an instance removes its actor state and pairwise transfer references;
disconnect also removes capabilities, generations and rate counters. No offline
animation mailbox, durable playback history or disconnected-owner source list is
permitted. Client-local cache/library retention is separate from relay policy.
