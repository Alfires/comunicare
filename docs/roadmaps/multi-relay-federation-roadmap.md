# Multi-relay federation, ordered failover and LAN discovery

**Scope amendment:** global internet-wide discovery/automatic trust bootstrap is
excluded at the user's request. Configured trusted peers and bounded local LAN
hints are the supported discovery model; do not treat worldwide DHT/crawling,
automatic internet peer exchange or NAT traversal as completion requirements.
Local provisioning, trust revocation, route validation and real-loopback failure
tests can be developed without external hardware. Physical VR/Wi-Fi/IPv6 validation
remains a deployment gate, not a prerequisite for testing these local features.

**Status: proposal, 2026-11-04. No federation or LAN discovery implementation.**
**Live network update:** TLS certificate verification, signed neighbour/origin
directory exchange, simultaneous anonymous directory clients, configured operator
peering, IPv4 LAN hint sockets and routed ENet gameplay are now implemented. Real
three-relay tests authenticate two users through distinct ingresses and deliver
origin item state. See [setup and limitations](../guides/relay-federation-setup.md).
Not all roadmap gates are complete: automatic peer/bootstrap trust, per-actor
ingress block conflicts, IPv6/mDNS, seamless transition rollback, WAN/VR performance
and hostile-operator/partition review remain open. Historical initial status below
does not override this update or imply those gates passed.
**Initial implementation:** ordered client preferences, structured settings panel,
endpoint blocking and actual client failover now exist. Seven policy/data services
and panel checks pass 81 assertions, with real coordinator fallback tested separately.
This is not complete federation: encrypted links, server identity verification,
live multi-relay directory connections, physical LAN discovery and cross-relay
gameplay remain pending. See [current limits](../guides/relay-preferences.md).
**Test-first update:** opt-in [RED acceptance contracts](../../tests/relay_federation/README.md)
now cover proposed preferences, fallback/link policy, public directory, LAN input
and origin-state services. Initial run: 0 passed, 6 missing-service failures and
6 explicitly blocked dependent groups, exit 1 without Godot errors. These are
pure service contracts, not real federation/TLS/multicast integration evidence.
This roadmap extends the existing relay, not world hosting or the world format.
Current behavior remains documented in [runtime setup](../getting-started/runtime.md)
and the [wire reference](../reference/protocol.md). The
[relay data lifecycle](../relay-data-lifecycle.md) remains binding.

## 1. Required behavior and terminology

- Users can use several relays concurrently: keep an ingress connection plus
  bounded additional directory/explicit-instance connections where needed. Relay
  federation makes public instances reachable/discoverable across allowed relays.
- The user's **ordered relay list is a connection preference, not a federation
  whitelist**. The top entry is the default/main relay; attempt the next entry if
  it is full or unavailable. Show the actual current relay separately from the
  preferred main relay. Successful fallback does not reorder saved preferences.
- Users can add, reorder, remove and block relays. Removing is not blocking:
  removal stops default/fallback selection; blocking excludes the relay from that
  user's discovery, connections and routed instance participation.
- Relay operators can block other relays. A blocked relay must not be usable via
  a third relay as an indirect route. User and operator restrictions both apply;
  neither side can override the other side's block.
- Compatible reachable relays exchange information and route authorized live
  traffic. "Every relay communicates" means a connected federation graph, not
  an unbounded all-to-all socket mesh or a guarantee of reaching offline/blocked
  operators. No central directory/account database or mandatory cloud service.
- Automatically discover relay advertisements on the local network and show
  their live **public** instances in World Explorer. Discovery never automatically
  saves/reorders a relay, switches a healthy connection or joins an instance.
- World URLs/downloads/catalog remain unchanged. Public discovery and content
  delivery are separate. Same URL does not mean same instance.
- No privileged player-host or gameplay server is introduced. Instance admins
  remain moderation roles, not relay operators. The world's target kick/ban-only
  policy is separate work; federation must not expand current moderation powers.

Definitions: **relay ID** = stable relay public-key fingerprint; **boot ID** =
fresh random process incarnation; **ingress** = user's selected entry relay;
**origin** = relay currently coordinating a particular live instance; **route** =
authenticated relay path to that origin. Directory-only links carry no gameplay
membership and need not publish an account identity.

## 2. Inspected baseline and necessary changes

| Current code | Rewrite requirement |
| --- | --- |
| `scripts/multiplayer/network_handler.gd` owns one `RelayPeer`, one current session and one set of pending requests | Introduce a connection manager and per-connection request state; retain one active gameplay membership. |
| Network settings contain one address/port, default `127.0.0.1:7374`; Reload retries authentication | Migrate endpoint to first list entry; iterate ordered candidates and expose meaningful capacity/unavailable results. |
| `relay_protocol/relay_peer.gd` authenticates a client account to a relay | Add authenticated relay identity and protocol negotiation; existing ENet alone does not prove server identity or provide confidentiality. |
| `scripts/multiplayer/relay.gd` owns membership/admission and a local 0..255 peer pool | Add federated actor/instance identities and origin-bound admission; never treat a remote relay as an ordinary account. |
| Public directory/session codes are local; World Explorer keys instances by local session ID | Namespace instance keys and codes with relay ID/boot ID and enforce source/request correlation. |
| World items use ID 29 and origin-local lease sequencing | Route to one instance coordinator; do not arbitrate the same object independently at multiple relays. |
| Voice/player records contain a single-byte actor ID | New negotiated federated envelopes/actor mapping are needed; identical byte IDs from two relays must never collide. |
| Relay connection/account caches are ephemeral and admin bans are client-owned | Federation replicas/subscriptions need equally strict disconnect and partition cleanup; no durable federation user history. |

Do not implement this by creating an array of today's `NetworkHandler.peer` and
broadcasting packets to all connections. That would duplicate membership, voice,
presence and object ownership, and leak private instance data.

## 3. Architecture and identities

```text
client relay preferences + independent blocks
                  ↓
RelayConnectionManager → chosen ingress A ←authenticated link→ relay B
       ↘ LAN/directory links                  ↘ relay C (instance origin)
                  ↓                                   ↓
        merged public directory            origin membership/admission/leases
                  ↘                                   ↙
           one active instance, explicitly acknowledged route
```

Proposed modules: `RelayPreferences`, `RelayConnectionManager`, `RelayIdentity`,
`LanRelayDiscovery`, `FederationLink`, `FederationDirectory`, `FederationRouter`,
`FederatedAdmission` and `InstanceRouteCoordinator`. Extract bounded responsibilities
from the existing coordinator rather than duplicating its entire mutable state.

- Relay identity is independent of its hostname/IP and users' keys. Pin identity
  after verification/explicit first-use confirmation. Address changes do not evade
  identity blocks; relay key changes require visible reapproval, never silent pin
  replacement. A new key can evade an identity ban: this is not solved by DNS or IP.
- Define instance key `(origin_relay_id, origin_boot_id, random_instance_id)`.
  Retain legacy local `session_id` only behind a compatibility adapter. A shared
  code/URI includes relay scope; a bare five-character legacy code resolves only
  against the explicitly selected relay, not by querying the entire federation.
- Define actors with origin/ingress scope, connection generation and authenticated
  account proof. Transport-local peer numbers are adapter details, never global IDs.
- Each federated message binds protocol version, link/session nonce, relay origin,
  boot ID, instance key, world revision, route-policy epoch, request/event sequence
  and expiry. Per-link sequences and authenticated origin provenance reject spoofing,
  stale-process packets and replay after peer/room-code reuse.

## 4. User list, settings and failover

### Storage and UI

Create a typed client-local store separate from general scalar settings, proposed
`user://relay_preferences.json`, schema 1. Device-scoped connection preferences,
not a public profile/social record. Preserve corrupt/newer files for recovery;
atomic writes, previous-good fallback and explicit migration. Never save health,
live instances or session tokens as startup authority.

Each ordered entry has a local entry UUID, label, canonical hostname/IP, port,
transport profile and optional pinned relay ID. Store blocks independently of the
ordered entries: pinned IDs plus explicit endpoint blocks for not-yet-identified
relays. Removing an entry must not delete its block. Never publish the full saved
list or personal blocklist to federation peers.

Network settings provide:

- Ordered rows, **Move up/down**, **Make main** (moves to top), **Add**, **Remove**,
  **Block/unblock**, endpoint and identity details.
- Current ingress, fallback reason, connecting/full/offline/incompatible/blocked
  status, retry action and separate LAN-discovered section.
- Blocked relays remain inspectable in a blocked-management view, not active world
  results. Unblocking does not automatically restore an entry or join anything.
- Reordering/removing the active relay changes future selection, not current
  membership. Offer an explicit switch. Blocking the active relay is immediate:
  stop affected traffic, invalidate route and attempt allowed fallback.

### Selection state machine

1. Snapshot ordered entries and policy revision; exclude blocked identities/endpoints.
2. Attempt top entry first, then next on timeout, capacity or unreachable transport.
   Bound DNS, transport, relay-identity and account-auth phases separately.
3. Full relays send a minimal authenticated `capacity_full` result with bounded
   retry-after. Reserve transport/control capacity for this rejection; an exhausted
   ENet pool may only time out, which still advances to the next saved entry.
4. Never forward credentials to a server suggested by a failed relay. Ignore
   unsolicited redirect URLs; authenticated peer hints belong to federation discovery,
   not the saved failover list.
5. Protocol incompatibility advances with a visible reason. Key mismatch/security
   rejection is quarantined, not silently retried as trusted. Account rejection
   (e.g. duplicate login) is reported distinctly; do not churn through relays as
   if every rejection meant "full" or bypass an instance ban through failover.
6. Share one in-flight selection attempt across UI callers. Bind results to attempt
   generation; removal/block/change during await invalidates stale completions.
7. If all candidates fail, remain offline with per-entry reasons and explicit Retry.
   Background retries use exponential backoff/jitter and a circuit breaker; never
   retry all endpoints every frame. Healthy fallback stays connected: no forced
   failback when the preferred main returns.

Additional LAN/federation links do not become automatic fallback candidates. Users
must add them to the ordered list first. An explicit Join can request a scoped
direct/bridged route outside the list if policy permits, with clear destination UI.

## 5. Relay-to-relay communication

- Operators configure their relay's identity key, advertised endpoints, federation
  listener, seed peers, admission/capacity policy and relay blocklist. These are
  static infrastructure settings, not persistent user/session records.
- Use mutually authenticated encrypted links with a reviewed TLS/DTLS or equivalent
  maintained transport, replay protection and bounded framing. Make a concrete
  Godot/platform feasibility decision before implementation; do not invent crypto
  or claim plain ENet is encrypted. Client-to-relay identity/security needs the same
  explicit design. Discovery datagrams are not authenticated sessions.
- Bootstrap from operator seeds and LAN advertisements; authenticated peer exchange
  supplies short-lived signed relay endpoint hints. No trusted global inventory can
  be discovered without an initial reachable peer; "all relays" means the reachable
  compatible graph, not the whole internet.
- Suggested initial caps: 8 active federation neighbours, 64 relay hints, 4 route
  hops, 32 directory subscriptions/client, 4 simultaneous client relay links,
  64 KiB control frames and 256 KiB bounded snapshot batches. Benchmark and version
  limits; per-link/origin/instance byte, CPU, queue and connection caps are mandatory.
- Gossip bounded public directory deltas, not every user packet. Instance gameplay
  flows only on active authorized routes; no network-wide flood. Deduplicate by
  origin/boot/sequence; signed path vectors/hop limits reject loops and duplicate
  broadcasts. One blocked link must not cause repeated reconnect storms.
- Relay operators can disable external peering or refuse a peer. Neither clients
  nor other operators may override that choice. Authenticated identity does not
  imply trustworthy data or permission to discover private instances.

## 6. Directory aggregation and local-network discovery

### Federated World Explorer

- Origin relays advertise only live PUBLIC summaries: names/descriptions, content
  URL/hash, scoped instance identity, bounded count, required capabilities and
  expiring origin-authenticated freshness. No roster, admin IDs, bans or social edges.
- Merge by global instance key, never world URL/local code alone. Deduplicate LAN,
  direct and federated sightings; prefer a fresh allowed route, retaining provenance.
  Two instances of the same world stay distinct under the same world card.
- Query IDs/generations and origin boot/revision prevent late responses replacing
  current results. Proposed summary refresh 5 s / expiry 15 s; withdrawal on empty
  instance/mode change/link loss. Wall-clock claims alone never extend a lease.
- Private/Friends/Friends+/Request instances remain out of public gossip. Scoped
  code lookup is authenticated and access-checked at the origin. Only the minimum
  destination information needed for an authorized request crosses the route.

### LAN discovery

- Use DNS-SD/mDNS `_comunicare-relay._udp.local` with a maintained platform adapter;
  expose a Godot-compatible bounded UDP multicast fallback if needed. Freeze the
  fallback wire schema/port only after checking platform conflicts, not by guessing
  an unused number in implementation.
- Auto-discovery is enabled by default with a visible Network opt-out, scoped to
  local interfaces/link-local multicast; no WAN scanning or subnet-wide port scans.
  Handle IPv4/IPv6, interface changes, VPNs and duplicate advertisements.
- Advertisements contain protocol version, relay ID/key hint, display label,
  endpoint, boot nonce and short expiry. No user identity or instance list in
  broadcast packets. Bounds: <=1 KiB advertisement, 64 candidates, probe backoff,
  replies no larger than requests unless a small cookie handshake authorizes them.
- Ads are untrusted hints. Confirm the relay identity on a secure directory link
  before accepting its instance summaries; an IP/label is not a pin. Reject
  advertised non-local endpoints in LAN-only probing, unsafe ports/schemes,
  self-reflection and redirects. Apply endpoint blocks before probing and ID blocks
  immediately when identified. No automatic account authentication/publication.
- Directory-only LAN connections fetch bounded public instances automatically, with
  no account key unless a later explicit user join needs it. If current servers
  require accounts for directories, add a dedicated minimal public-query capability
  rather than silently logging users into every LAN relay.
- Show public instances in World Explorer with LAN/relay badges and an unverified
  hint status until identity validation completes. Offline/unverified advertisements
  never appear as joinable authenticated instances. Multicast absence is not proof
  that no local relays exist; allow manual addition and explain firewall isolation.

## 7. Blocking semantics — both ends and every route

| Action | Required result |
| --- | --- |
| User blocks relay X | Exclude X as ingress, directory source, origin and intermediate hop; remove X-associated directory entries and stop that user's affected routes. |
| Operator A blocks X | Tear down A↔X links; no X-originated/exported content or gameplay through A, including A↔B↔X. A's own local instances remain independent. |
| User removes X from list | No default/fallback attempt to X; federated/LAN visibility is unchanged unless separately blocked. |
| User unblocks X | Permit future checked discovery/connection only; no automatic membership restore or preference insertion. |

Operator blocks are infrastructure-ID policy, not player bans; they can be durable
operator configuration without retaining disconnected users. User blocks stay local.
Filter on origin and authenticated path at ingress, directory merge, lookup,
admission, subscriptions and delivery, not merely on the endpoint socket.

For gameplay participation, relay X also means remote actors currently using X as
ingress: do not silently deliver their traffic through an allowed origin and claim
X was ignored. A newly blocked ingress/member creates a policy conflict for that
user. Version 1 refuses/ends the affected user's instance route and explains why,
rather than inventing different shared membership for each viewer. Other members
may continue. Local mute/hide is a separate per-player feature, not federation block.
Apply stricter combined policy before membership commit, including private joins.

Transmit only route-specific policy constraints/decisions required to enforce an
authorized route, not a user's complete saved blocklist. Policy changes invalidate
in-flight requests and route epochs immediately; delayed packets cannot restore
them. Do not attempt alternate paths to bypass a blocked origin/ingress/hop.

A malicious allowed relay can conceal its real upstream, re-sign copied content or
lie about paths. Cryptographic provenance and end-to-end admission reduce this but
cannot prove network non-participation or force a hostile operator to delete data.
Document this trust limit; a block is enforceable on verified identities/routes,
not an absolute anonymity/firewall guarantee against collusion or new relay keys.

## 8. Cross-relay gameplay, admission and failure recovery

- Keep one origin relay coordinating each instance's membership, role revision,
  admin admission and item leases. Other relays bridge, never independently grant
  membership/admin roles or assign competing item epochs. No relay runs world scripts.
- Join sequence: select global instance → allowed-route resolve → stage exact world
  revision → fresh end-to-end account proof/admission → origin acknowledgement →
  activate route/world. Origin verifies user-signed challenge bound to destination,
  ingress, nonce and expiry; an ingress assertion alone cannot impersonate a user.
- Control messages reliably reach the origin; voice/poses use bounded disposable
  streams for admitted members only. End-to-end sender/membership generation and
  content revision checks survive hop rewriting. Scope profiles, animations,
  asset transfers and items to the acknowledged global instance.
- Preserve social consent and fresh moderated admission at the origin. Do not
  federate the full friend graph, permanent bans or contact stores. Client-side
  consent exchanges provide only proofs needed for the requested join/presence.
  Multi-relay authentication must not defeat same-origin duplicate-account rules.
- Ingress failover authenticates a fresh connection on the next saved relay. If
  origin is reachable through an allowed route, perform explicit correlated rejoin
  with new generations and fresh policy checks. Clear old leases/voice buffers;
  no optimistic continued membership or copied old authorization tokens.
- Origin loss/partition is different from ingress loss. Version 1 suspends the
  affected instance route and ends membership on expiry; it does **not** elect a
  second origin or silently resurrect the old instance. Users may explicitly create
  a new instance at an available relay. Automatic seamless origin migration requires
  a later consensus/authority-transfer design and is not promised here.
- If failover/rejoin times out after uncertain membership commit, disconnect the
  affected route and resolve rather than send to two instances. A process/boot
  restart always invalidates previous routing/session state.

## 9. Privacy, cleanup and capacity

- Active remote users are temporary **routed connections**, not a reason to keep
  offline identity history. Store only scoped data needed for current routes.
  Delete on direct disconnect, authenticated upstream disconnect, route revocation,
  expiry or partition liveness timeout. Origin and every replica apply cleanup.
- Proposed link heartbeat 2 s / loss declaration <=10 s; remote membership cannot
  be renewed without a live authenticated route. Detection is bounded, not instant.
  Drop stale directory summaries and fail closed on expired membership/policy.
- Remove all departed account/actor references from holder maps, presence,
  subscriptions, bans, result caches, deduplication entries, pending admissions and
  transfers on each participating relay. Clear authored metadata per current policy.
  Bound tombstones to live-route sequencing without retaining disconnected identity.
- Relay restart loads only infrastructure keys/config/blocks, not users, sessions,
  live directory caches or social history. No durable message broker, retained user
  logs or federation event database. A network partition cannot be fixed by disk
  replaying disconnected-user state.
- Count transport connections, directory-only queries, active users and routed
  participants separately. Admission reserves resources before committing. Full
  ingress does not authorize overflow past a full origin/instance member limit.
  Flooding from one relay cannot consume every peer/control slot.

## 10. Compatibility and migration

- Migrate existing `network.relay_address`/`network.relay_port` to one top entry
  once; preserve old config and any user-edited list. General settings invoke a
  structured preferences editor, not JSON stored in a plain text settings field.
- Negotiate federation, global-actor, directory and route versions independently
  of application/world/script versions. Allocate explicit unused packet IDs after
  inspecting current values (currently through WORLD_DATA=29); never renumber them.
- Legacy relays/clients can remain local-only. Label them accurately; do not route
  federated actors into byte-ID protocols through lossy truncation. A legacy
  connection cannot accidentally learn non-public federated directory information.
- Do not switch URLs, rename `default_wold`/legacy packet spellings or modify world
  serving as part of this work. Coordinate with the
  [world roadmap](safe-world-system-roadmap.md) and existing discovery reliability work.

## 11. Test-first delivery plan

| Phase | Deliverable | Required exit evidence |
| --- | --- | --- |
| 0 — contracts | Trust model, identity/route schemas, transport decision, block semantics and privacy review | Explicit malicious-relay/partition cases; no hidden global mesh/database assumptions. |
| 1 — user preferences | Structured ordered list, blocks, scalar migration, safe save/recovery and settings UI | Add/remove/reorder/block semantics; default stays top; corrupt-file preservation; changes never silently switch active membership. |
| 2 — connection manager | Per-relay state, coalesced selection, typed full/unavailable results, bounded fallback | A full → B down → C authenticated; no preference reorder; no blocked/unknown redirect targets; attempt-cancellation/race coverage. |
| 3 — LAN | Local advertisements, bounded directory-only identity validation and merged UI | Actual multicast on supported interfaces; synthetic spoof/expiry/flood tests; public instances appear without saving/logging in; blocks suppress probes/results. |
| 4 — federation directory | Authenticated links, peer exchange, scoped instance keys and public gossip | Three-relay chain and triangle; collision/loop/replay/expiry tests; private/social metadata never advertised. |
| 5 — routed admission | Origin-bound identity proofs, role/admission checks and fail-closed routing | Users on A and B join C's same instance; cross-origin/local-ID collisions harmless; unauthorized routes never get profiles/voice/state. |
| 6 — gameplay | Federated movement/voice/avatars/items, bounded origin sequencing and reconnect | Two independent real world scenes carry one item across real relay hops; exclusive lease, generation and privacy cleanup checks. |
| 7 — policy/failure hardening | Immediate transitive blocks, partitions, capacity isolation and complete cleanup | A↔B↔C cannot bypass C block; holder/admin disconnect; no split-brain origin; state scans and zero durable user writes across all relays. |
| 8 — rollout | Protocol compatibility, documentation and deployment/hardware verification | Real LAN IPv4/IPv6/Wi-Fi/VPN/NAT, packet loss/latency, desktop/VR and resource measurements; remaining trust limits published. |

Initial isolated runner `tests/relay_federation/run.py` now exists with guarded
pure service cases; real federation integration remains follow-up. Build
disposable projects/accounts and real loopback relay processes, following existing
runners; no real user stores, WAN peers or physical multicast required for baseline
unit tests. LAN integration must separately use permitted interfaces and disclose
when multicast is unavailable rather than calling mocked advertisements full coverage.

Essential cases beyond the table:

- All candidates unavailable; preferred recovery without failback; settings/account
  switch during auth; stale successful callback after block; full-probe amplification.
- Same hostname/new key, same key/new address, duplicate ads/routes and relay restart;
  invalid TLS identity, forged capacity status and malicious peer hints/redirects.
- Two identical local room codes and peer bytes across relays; same world URL with
  different instances; exact content-hash mismatch; delayed old boot packets.
- User and operator origin/ingress/transit blocks; mixed policy in an occupied
  instance; removal vs blocking vs unblocking; no indirect route or UI-cache bypass.
- Three-node partition, duplicate delivery, missing withdrawal, origin loss while
  holding an item, pending admission/admin departure and stale result correlation.
- Recursively scan every relay's active state after disconnect for departed key,
  fingerprint, actor/generation and indirect references; inspect filesystem writes;
  restart empty. Repeat for dropped inter-relay links, not just graceful clients.
- Regress existing world/example real-network, profile, social, moderation, cache,
  discovery, voice, animation, client reliability and VR/tracking suites. Headless
  tests do not certify real Internet reachability, multicast, rendering or privacy
  behavior of third-party relay operators.

## 12. Definition of done

A user orders A/B/C, normally connects to A, falls back to B/C only when needed,
and can simultaneously discover/use allowed federated/LAN relays without turning
that list into an allowlist. Two users attached to different relays can join the
same acknowledged instance and see each other's held objects. Local public
instances appear automatically. User/operator blocks apply transitively and
immediately; removal alone does not hide a relay. Failover never creates duplicate
membership, conflicting item owners or resurrected server history. World hosting
stays exactly where the author already serves it.

Not promised: automatic reachability of every internet relay, mandatory federation,
unlimited simultaneous sockets, seamless origin failover, perfect malicious-operator
exclusion, global account tracking or durable world/session recovery.
