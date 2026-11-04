# Multiplayer and public world discovery reliability roadmap

## Status, evidence and scope

**Planning only — 2026-11-04.** This roadmap follows inspection of the current
multiplayer/relay/wire/UI/player/startup files, rather than assuming the older
discovery plan describes all current gaps. No runtime fixes or file splits are
implemented by this document.

Verified baseline commands for this review:

```sh
python3 tests/public_discovery/run.py
python3 tests/profile/run.py
python3 tests/active_instance/run.py
```

All three runners exited 0. These suites use disposable projects and loopback
networking, not a production relay, real user storage, physical voice listening or
full rendered multi-client avatars. The discovery suite has fake-loader/fake-peer
transition groups plus a real-relay group and a second real-coordinator startup
suite; that is not a complete production startup-to-world-to-avatar integration.
Recorded counts for this review: discovery 51 plus startup 24, profile 121,
Active Instance 128. Profile emitted the existing one-object shutdown leak warning.

Goals:

- Reliable connection/authentication, instance lookup/discovery, hosting/joining,
  participant/appearance updates and reconnect/eviction cleanup.
- Public discovery that recovers from timeouts without stale or cross-generation
  results, remains usable without the external catalog, and never leaks private
  instance membership or access policy.
- Bounded hostile-input behavior, finite/ordered live streams, explicit capability
  compatibility and fair scheduling between control, voice, poses and asset chunks.
- Smaller modules with explicit ownership and tests, preserving the current facade
  paths, resource UIDs, numeric packet IDs and authorization/privacy rules.

Non-goals: multi-relay federation, durable/offline relay services, blanket protocol
rewrite, switching everything to Godot RPC, unrestricted remote world execution,
or a claim that ENet/account signatures supply encrypted transport.

## 1. Current code map and file-size assessment

Counts at review time (lines are context, not a mandate to meet an arbitrary limit):

| File | Lines | Current responsibilities | Assessment |
| --- | ---: | --- | --- |
| `scripts/multiplayer/relay.gd` | 639 | ENet host/polling, dispatcher, auth, membership, discovery, profiles, moderation, approvals, all cleanup | Split by state owner after invariant tests; highest coupling |
| `scripts/multiplayer/network_handler.gd` | 449 | Connection setup/deadlines, join staging/activation, management, roster/profile application, remote nodes, legacy RPC adapters | Keep autoload facade; extract session coordinator and participant registry |
| `relay_protocol/relay_peer.gd` | 329 | ENet client, event polling, decode/dispatch, capabilities, mutable session caches, local moderation persistence | Separate transport/dispatch/state/policy without duplicating session authority |
| `scripts/GUI/world_explorer.gd` | 250 | Catalog HTTP, discovery refresh/timeouts, peer subscriptions, model normalization, cards/rows, join/create/code search | Length alone reasonable, but HTTP/model/refresh ownership should leave view |
| `relay_protocol/animation_router.gd` | 168 | Animation state, capabilities/rates, typed chunks, tracked pose routing/expiry | Existing extraction to preserve; separate pose/transfer internals if protocol hardening expands it |
| `relay_protocol/friend_router.gd` | 156 | Active social proofs/routing/presence/lifecycle | Existing boundary; do not duplicate in a new session service |
| `tests/public_discovery/suite.gd` | 447 | Browser/model, coordinator, relay, loader and loopback checks | Split test groups/fixtures while retaining one disposable runner |
| `tests/public_discovery/startup_suite.gd` | 128 | Production coordinator and browser lifecycle checks | Retain, expand generation/auth/retry boundaries |

Most codecs are 15–59 lines. Do not fragment every codec into a directory of tiny
one-function files; centralize shared validation where it removes real duplication.
Do not solve line counts by moving an entire giant dispatcher into another giant
helper or passing the whole server object into every component forever.

Related inspected production files: startup main/DataLoader, desktop/VR/remote
players, animation controller, world explorer scene and packet/identity validators.
Movement, asset and avatar changes may be required to fix user-visible multiplayer;
their symptoms cannot all be repaired by the directory view alone.

## 2. Findings and priority

**Confirmed** means directly visible code path, not a claim of reproduced rendered
failure. **Risk/gap** requires a targeted failing test before calling it a proven
runtime exploit. The passing baseline must not hide either category.

### P0/P1 — identity, session and appearance correctness

1. **Confirmed appearance wiring gap:** `NetworkHandler._on_profiles_updated()`
   replaces verified profiles and updates names only. It does not apply each
   profile's `profile.avatar_url` to its remote player. `remote_player._ready()`
   loads the default model. Typed model transfer covers an explicitly shareable
   custom model, not every public-URL profile avatar. The remaining
   `request_player_model()/sync_player_avatar()` use Godot RPC while the active
   transport is custom ENet; inspection found no multiplayer-peer bridge wiring
   for those RPCs. Add real profile-to-avatar application tests before removing
   legacy adapters. Never paper over this by trusting an arbitrary claimed peer ID.
2. **Confirmed split session mutation:** RelayPeer installs successful
   SESSION_RESULT session identity and clears its caches before emitting the result;
   NetworkHandler independently matches pending operation/session and installs its
   own identity. An unrelated/late result can therefore be ignored by the coordinator
   after the transport already changed state. One correlated transaction must own
   acceptance; transport emits validated data without committing unaccepted state.
3. **Confirmed missing transaction identity:** create/join/resolve results match
   operation/session but have no request nonce/connection generation. A delayed
   earlier result for the same code, or uncorrelated create result, is ambiguous.
   Stage completion also refers back to mutable `peer` across awaits; explicitly
   capture generation/peer and reject disconnect/replacement/stale activation.
4. **Confirmed legacy stream gap:** PlayerData is 26 bytes (byte actor + position/
   Euler floats); voice is actor plus PCM. Neither carries session/connection epoch
   or sequence. Client checks current membership/busy state, not packet membership
   generation. Queued/reordered packets around instance changes or byte-ID reuse
   need tests and a negotiated stream envelope. Reliable control and unsequenced
   streams can arrive across lifecycle boundaries; URL equality cannot fix that.
5. **Confirmed participant registry drift:** remote nodes are created/reconciled by
   child names, while `players` is not populated by `update_connected_peers()` and
   `_on_peer_disconnected()` relies on that dictionary. Define one roster/registry
   owner with fingerprint + connection generation; do not maintain dead parallel maps.
6. **Confirmed sender/movement issues:** desktop process also moves position in
   addition to physics movement; desktop/VR `last_state` is never updated after
   send. Thus the change test is not an actual throttled snapshot and can flood
   packets once the user leaves its initial transform. Fix local movement once,
   implement bounded send cadence and interpolate remote transforms instead of
   snapping directly on every arrival. Quantify real rates in tests.

### P1 — public discovery and catalog reliability

7. **Confirmed discovery recovery limitation:** browser times out after 10 s but
   leaves `refreshing=true`, resets its timer and never issues another request until
   some response arrives. That avoids overlap but permanently stalls on a silent
   connected peer. It can repeatedly show modal errors. Add bounded retries with
   request IDs/generation; stale replies must not finish a newer request.
8. **Confirmed uncorrelated snapshots:** ID 4 is a bare request/response array,
   without request ID, catalog version, sequence or pagination. Old same-connection
   responses cannot be distinguished. Current peer replacement disconnects signals
   correctly, but that does not solve same-peer response ordering.
9. **Confirmed catalog gaps:** a hardcoded external catalog URL, no body-size limit,
   no immediate request-error handling, direct JSON.parse_string, and loose metadata
   conversion. No bounded entry/string/depth policy or cache/retry/last-good catalog.
   Separate catalog failures from directory failures; no network dependency in tests.
   Runtime HTTP catalog behavior is not Git publication tooling; this task adds no
   hosting-specific tools or workflows.
10. **Confirmed UI contract mismatch:** search accepts a world URL or treats any
    other nonempty text as a session code, despite placeholder suggesting search.
    Split filter-by-name from Open URL / Join code intent or clearly label the
    combined input. Manual URL info is not added to worlds_by_url, so title/metadata
    fallback needs a deliberate model policy. Preserve selected URL and focus on refresh.
11. **Confirmed rendering churn:** every refresh clears/rebuilds all cards and the
    open instance rows. Large snapshots can churn nodes/focus/scroll. Add stable keyed
    updates, bounded/sorted display and loading/empty/stale/error distinctions. No
    automatic repeated error popup should steal VR/desktop focus every timeout.
12. **Confirmed summary limitation:** public summaries omit world revision and have
    no capacity/compatibility status. Browser can offer Join before the exact revision
    is known, then resolve correctly at join. Preserve resolve-before-join; make
    readiness/compatibility/hosted-mode clear rather than promising an accessible
    instance merely because it is public.

### P1/P2 — hostile input, scheduling and lifecycle

13. **Confirmed inconsistent decode boundaries:** CreateSession, JoinSession,
    GetSessionPeers, GetPublicSessions and SessionResult use direct JSON parsing;
    peer lists have weak shape protection. Auth/account parsing is bounded generally
    but handlers do not uniformly bound operation bytes before parse. Unknown packet
    types push engine errors. Add quiet bounded Result-like decoders and schema
    validation at ingress; malformed network input must not become Godot exceptions.
14. **Confirmed live-stream validation gaps:** relay checks movement length but not
    finite coordinates/ranges, and PCM packet size but not even sample-byte parity.
    Per-actor rate/burst quotas are uneven. Add finite/size/parity/rate tests without
    pretending a social chat relay is authoritative movement/collision simulation.
15. **Confirmed one-lane transport:** all PacketInfo sends use channel 0, including
    reliable control/asset chunks and unsequenced streams. Both event loops service
    until EVENT_NONE, without per-frame budgets. Floods or large reliable transfers
    can starve application work/control. Measure before changing channels; negotiated
    channel layout must configure both hosts/peers, preserve ordering where required
    and apply bounded scheduling rather than silently break existing peers.
16. **Confirmed connection cleanup gap:** RelayPeer.connect_to_relay logs host error
    then continues; create_peer can replace `peer` without an explicit old-transport
    teardown/in-flight-generation policy. Reconnect, duplicate connect, failed host,
    account change and orderly shutdown need one idempotent cleanup path.
17. **Confirmed pending-admission revision omission:** admission captures world URL,
    admins and mode, but not pinned world revision. It validates these before commit;
    include immutable target revision and request generation too. Missing/modifier
    support must remain fail-closed, never restore disconnected-user relay ban history.
18. **Risk: startup exposure/product policy.** Startup authenticates then immediately
    creates a default public instance. Decide whether Home is public or local/private
    by default with explicit UI; do not change policy silently during refactoring.
    The built-in hash covers scene file only, not transitive resources/export output;
    document and test a real content-manifest/build revision before stronger claims.

## 3. Non-negotiable contracts

- Preserve [relay lifecycle](../relay-data-lifecycle.md): no durable relay users,
  sessions, offline messages, disconnected ban/pose/profile caches or indirect references.
- Transport identity comes from authenticated connection. Fingerprint is account
  identity; peer byte ID is reusable connection addressing; `session_id` plus relay/
  connection generation is instance scope. Never merge by URL or display name.
- Public discovery sends public summaries only. Private/Friends/Friends+/Request
  lookup remains authenticated/authorized; no rosters, keys, bans, grants or social
  graph in directory responses.
- Preparation precedes admission; activation follows matching acknowledgement.
  Failure before commit retains old world. Uncertain committed outcome disconnects
  until reconciled. Cache hit, friendship and pose receipt grant no extra permission.
- Preserve all existing numeric IDs and compatibility spellings. New payload versions/
  capability negotiation must fail explicitly or enter a documented limited legacy
  mode, never silently reinterpret old bytes.
- Signed profile verification stays service-owned. Public avatar URL must be bound
  to current verified profile/actor and generation; custom assets require explicit
  permission, bounded transfer and hash/format checks. URLs are not executable trust.
- No transient raw decoder or state component writes client stores in relay mode.
  Logs are bounded/redacted; no account keys, private URLs or pose payload history.

## 4. Proposed modular structure

Keep `NetworkHandler`, `RelayPeer`, relay scene and WorldExplorer script paths as
compatibility facades at first. Proposed new paths are design, not implemented APIs:

```text
scripts/multiplayer/
  network_handler.gd             # client facade/signals and explicit service wiring
  client/
    connection_service.gd        # generation, connect/auth/teardown/reconnect deadlines
    session_coordinator.gd       # one correlated prepare/admit/activate transaction
    instance_client.gd           # roster/metadata revisions and management requests
    participant_registry.gd      # stable actor records ↔ owned remote nodes/appearance
    stream_receiver.gd           # sequence/epoch checks and transform interpolation
  server/
    relay_transport.gd           # ENet lifecycle, budgets and bounded send queues
    packet_dispatcher.gd         # byte limits, typed decode, auth/capability gates
    session_registry.gd          # ID-keyed instance/member indexes and invariants
    admission_service.gd         # access + fresh moderator/request decisions
    instance_management.gd       # validated admin actions/revisions/result dedupe
    directory_service.gd         # public-only summaries, request/page snapshots
    profile_exchange.gd          # active authenticated signed publications
  relay.gd                       # host composition + ordered idempotent disconnect
scripts/discovery/
  world_catalog.gd               # bounded HTTP/cache parsing and source status
  discovery_client.gd            # authenticated-ready subscription/retries/generation
  discovery_model.gd             # exact URL grouping, keyed rows, local filtering
scripts/GUI/world_explorer.gd    # render/actions/focus only, no transport parsing
relay_protocol/
  relay_peer.gd                  # compatibility facade around transport/dispatch
  decode_result.gd               # typed success/error, no arbitrary engine exceptions
  message_limits.gd             # operation limits/capability versions, not app SemVer
  ...existing codecs/routers...  # explicit IDs; shared bounded validators
```

Session registry should replace nested `sessions[i][0]` mutable arrays with
ID-keyed records and explicit `peer → session` indexes. Its invariants are checked
centrally: one membership per peer; no empty discoverable session; owners subset of
members; revision increments once per committed mutation; target record remains
stable if another empty session is removed. Migrate tests away from private array
shape toward observable behavior; retain temporary test adapters only during extraction.

Avoid cycles/implicit ownership: services receive narrow callbacks/interfaces or
validated values, not global autoload lookup or unconstrained whole-server mutation.
One composition root wires signals. One disconnect transaction invokes every
component's `remove_peer` before releasing its connection ID. Persistent moderation
policy remains a **client** service, not part of server registry.

Prefer RefCounted pure model/validators and explicit main-thread Node owners.
No per-request global GLTF changes, resource UID replacement, service nodes in the
remote-player child list, duplicate frame loops or giant umbrella “manager”. Aim
for cohesive modules around 100–250 lines where natural; exceptions need a reason,
not mechanical subdivision. UI rendering may stay larger if its model is pure/testable.

## 5. Target flows and capability migration

### Connection and session state

```text
Disconnected → Connecting(generation) → Authenticating → Ready
Ready/member → Prepare(transaction + expected instance descriptor)
 → Request admission(request ID + generation + expected URL/hash)
 → Commit accepted state once → Activate → Active
any phase → scoped failure/cancel/teardown → old Active or Disconnected
```

Transport validates and emits messages; coordinator alone accepts a transition.
Peer/connection generation and transaction ID are captured before awaits and checked
after each stage/result. Timeouts release staged handles and pending listeners.
Once commit might have happened, cancellation cannot claim “still in old room”
without authoritative reconciliation. Restart/reconnect never resurrects relay state.

### Public discovery

```text
Catalog source → validated last-good metadata model
Ready relay → DirectoryRequest(id, generation, page/limit)
Relay → public-only consistent snapshot/version + request ID
Client → match current request/generation → replace keyed instance model
View → URL cards + exact instance rows → coordinator join/host intent
```

Use bounded backoff/jitter and one logical current request; retries can use new
correlation IDs after deadline and ignore old responses. Distinguish disconnected,
auth pending, initial loading, fresh empty, stale/retrying and permanent error.
Catalog status must not overwrite directory state. Retain metadata separately;
expired live-instance rows must not stay actionable. Pagination must not merge
inconsistent snapshot revisions; restart/expire tokens with active bounded lifetime.

Design a negotiated version of existing ID-4 JSON request/result or allocate a
new unused explicit ID only with justification. Legacy array requests/responses
remain on a separate adapter with one-in-flight semantics and documented limited
recovery. Do not send new envelopes to an old relay without capability detection.
Discovery connection-ready behavior is a product/API contract: current tests request
on transport connection; if authentication-ready is required, migrate both tests
and UI status deliberately rather than accidentally stopping refresh.

### Live streams and appearance

Participant registry binds verified fingerprint, peer ID, connection generation,
session epoch and avatar revision. Public profile appearance, custom model transfer,
nameplates, transforms, voice and tracked targets refer to that record. No fallback
default reload on every snapshot or duplicate avatar requests for unchanged URLs.

Negotiate sequence/session-epoch stream envelopes before using old unsequenced bytes
for stronger guarantees. Drop stale/nonfinite/forged/out-of-range inputs; interpolate
movement and bounded pose targets, keep voice latency/buffer policy separate. Do
not put reliable asset chunks ahead of all control/voice traffic without budgets.
Do not collect a durable stream history to implement interpolation or debug logging.

## 6. Test-first implementation and small commit plan

Write failing focused tests locally before fixes; commit the verified test+behavior
unit, not knowingly broken intermediate snapshots. Use the existing isolated runners
and ordinary Git only; push each passing Conventional Commit to configured upstream.

| Order / commit | Coherent scope | Exit gate |
| --- | --- | --- |
| 1 `test(network): characterize production participant and discovery lifecycles` | Production facades with fake clocks/HTTP/assets and real ENet; no renderer/real accounts | Existing behavior distinguished from opt-in missing-feature assertions, no Godot parse/runtime errors |
| 2 `fix(avatar): apply verified instance profiles to remote appearance` | Current-profile URL + custom revision precedence, actor/generation checks, dedupe and keep-old-on-failure | Two clients show distinct declared model requests; late old profile/import cannot overwrite; names still update |
| 3 `fix(network): correlate transitions before accepting session state` | Shared transaction acceptance, request/generation capture, timeout/replacement cleanup; negotiated wire support if needed | Late same-code/create result cannot mutate either facade; reconnect during staging cannot join on new peer |
| 4 `fix(protocol): reject malformed packets without engine errors` | Bounded quiet parse + schemas/finite/parity/unknown handling, preserve wire IDs | Truncated/oversized/deep/wrong-type/fractional/NaN/odd PCM fuzz fixtures fail safely |
| 5 `refactor(relay): extract indexed membership and lifecycle registry` | ID-keyed records/indexes, facade adapter, one commit invariant boundary | Same-world sessions isolated, last admin successor, empty removal, peer reuse and cleanup scans pass |
| 6 `refactor(relay): separate admission management and public directory` | Narrow service contracts, auth/profile wiring, bounded pending state | All fresh moderator/friend/access/ban tests unchanged semantically; target revision revalidated |
| 7 `refactor(client): isolate connection session and participant owners` | Facades/signals remain; dead maps and proven-unused RPC removed with tests | Production startup/reconnect/roster/custom/public avatar tests pass without hidden global bridge |
| 8 `feat(discovery): add correlated retryable public snapshots` | Capability handshake, request IDs/generation, bounded consistent pagination and rates | Silent peer retry recovers; old reply/page cannot revive stale rows; private data absent |
| 9 `fix(discovery): bound catalog loading and clarify search actions` | Configurable permitted source, HTTP limits/error/backoff/last-good, metadata schema, filter vs code/URL | Offline catalog still lists builtin/live worlds; huge/bad catalog cannot overwrite valid model |
| 10 `refactor(discovery): move data and refresh policy out of world explorer` | Catalog/client/model services + stable keyed UI rendering | Actual row/button clicks, focus/scroll/selection and teardown tests in desktop/VR viewport |
| 11 `feat(network): scope live streams to membership generations` | Negotiated epochs/sequences, interpolation/send cadence, finite rates, channel/budget policy | Reorder/session switch/peer reuse cannot leak old voice/pose; bounded bytes/events under load |
| 12 `docs(network): publish module contracts compatibility and recovery` | Update function coverage/inventory, protocol/schema/usage/decisions and measured limits per preceding step | Full tooling checks and applicable game suites; no claimed Internet/XR certification |

Splits 5–7/10 are incremental extractions, **not a big-bang rewrite**. If behavior
and extraction cannot be independently verified, combine their minimum dependency
unit; do not rewrite social/animation/import systems just to make interfaces uniform.
Keep protocol negotiation and its client/relay implementation in the same coherent
commit. Never alter production export paths or deploy a relay implicitly.

## 7. Verification matrix and missing coverage

### Add targeted reproductions before changing code

- Production RelayPeer + NetworkHandler disagreement after unmatched result;
  same-code stale join, duplicate create, manual create racing browser join;
  peer/account replacement during resolve/prepare/admit/activate.
- Two real loopback clients publishing different verified public avatar URLs;
  remote scene fixture records requested URL/hash, not just profile name text.
  Model failures preserve old; late imports do not reattach to departed/reused actor.
- Silent relay discovery timeout with recovery, retry exhaustion, old-response
  correlation, pending-auth startup, browser hide/reopen, disconnect and replacement.
- Fake HTTP immediate request failure, 404/redirect/timeout, malformed/non-array/deep
  catalog, byte/entry/string limits and late response after newer catalog/generation.
- Distinguish filter text, URL, valid/invalid code and exact-session join. Same URL
  multiple instances; own hidden instance only; public-to-private update; vanish
  between render/resolve/join; hash mismatch and unsupported capability display.
- Codecs with empty/type-only/truncated/oversized/odd/wrong-type/fractional/nonfinite
  data; no engine ERROR output for expected invalid network input.
- Stream sequencing, sender spoof, epoch mismatch, actor ID reuse, movement flood,
  frame send rate, queued voice after transition and large chunk/control fairness.
- Every extracted service disconnect clears user identity/indirect references,
  pending callbacks/admissions/queues/rates and authored metadata. Fresh relay
  creates no client store and contains no offline user/session history.

### Keep these suites green

```sh
python3 tests/public_discovery/run.py
python3 tests/profile/run.py
python3 tests/active_instance/run.py
python3 tests/friends/run.py
python3 tests/microphone_settings/run.py
python3 tests/avatar_loading/run.py
python3 tests/asset_cache/run.py
python3 tests/animation_sync/run.py
python3 tests/vr_controls/run.py
python3 tests/avatar_tracking/run.py
python3 tools/check_repository.py
```

Runners copying selected production files must copy each new dependency/UID or
provide an explicit narrow fixture. Do not silently replace production coordinator/
codec/registry in the very test meant to verify it. Guard infrastructure failures
separately from assertions and report skipped groups. Split large discovery tests
into browser/model, codec, session, startup and loopback suites under one runner;
use explicit monotonic test clock/pump deadlines, not only sleep/round counts.

### Manual and load gates

Run 2–3 rendered desktop/VR clients against a controlled relay: connect, host/join,
different profile avatars, code search, refresh while joining, request moderation,
leave/reconnect, voice listening and tracked/emote appearance. Record versions,
capabilities, bandwidth, event/frame budgets, latency/jitter/loss and asset sizes.
Test enough simultaneous simulated actors to observe directory pagination/queue
bounds; do not promise a capacity number from a three-client loopback test.

Public relay security/transport encryption, executable-world publisher policy and
real headset/audio certification are separate release concerns. Logs/metrics must
remain redacted aggregate counters, not retained keys/URLs/stream payloads.

## 8. Completion criteria

- Browser recovers from temporary silence/catalog failure and shows only current,
  authorized public summaries without modal retry spam or stale clickable rows.
- Each accepted transition updates one authoritative client session transaction;
  stale generation/results/streams cannot change a new session or actor.
- Participant names, public/custom avatars, body/voice and tracked animation refer
  to the same verified current actor; production remote appearance is actually wired.
- Packet parsing, rates, event budgets and transfer scheduling remain bounded under
  malformed/flooded input; errors are observable without engine exceptions/secrets.
- Relay privacy and fresh admission policy remain intact, including indirect cleanup.
- The long relay/client/transport files become thin stable facades around cohesive
  tested owners. WorldExplorer becomes a view, not an HTTP/protocol state machine.
- Current docs/contracts/inventory and tests explain the new boundaries and measured
  limits; no successful test or old roadmap is used to claim unperformed hardware
  or production Internet verification.
