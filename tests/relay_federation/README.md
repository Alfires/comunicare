# RED multi-relay acceptance contracts

**Discovery tests update:** the transport suite now checks actual multicast
advertisement delivery using separate interface-bound advertiser sockets and a
listener, plus valid-empty/invalid-version/malformed internet presets and explicit
device-trust precedence. The shipped preset list is empty and makes no external
network requests. Local multicast passed on this host; physical Wi-Fi/router
compatibility remains unverified. See current runner output for updated totals.

**Live transport update:** the runner now also copies the real relay/protocol and
runs `transport_suite.gd`: 28 assertions exercise certificate-verified TLS framing,
three live directory relays, signed multi-hop public summaries, concurrent anonymous
directory links, origin account authentication through encrypted datagram tunnels,
two users via different ingresses sharing membership/item state, block filtering
and actual local UDP advertisement parsing. No physical multicast/WAN/VR or audited
PKI claim is made. The old pure-service-only limits below describe the first stage.

**Implementation update:** 81 service/UI assertions now pass without blocked groups
or Godot errors. Actual coordinator fallback/endpoint blocking also has loopback
coverage in multiplayer_reliability. The RED baseline below is historical. No
encrypted federation transport, physical LAN discovery or cross-relay gameplay
is implemented by this milestone; pure trusted-verifier inputs remain test boundaries.

**Opt-in, intentionally failing. No runtime federation implementation is added.**
Test-first contracts for the [multi-relay roadmap](../../docs/roadmaps/multi-relay-federation-roadmap.md).
Normal green runners and release hooks do not invoke this suite.

```sh
python3 tests/relay_federation/test_runner.py  # green runner integrity tests
python3 tests/relay_federation/run.py          # expected RED acceptance baseline
```

`GODOT=/path/to/godot` overrides the executable. Verified with Godot 4.7.2:
**0 passed, 6 missing-service assertions failed, 6 dependent behavioral groups
blocked**, exit **1**, no Godot errors. Three Python runner tests pass.
Blocked cases below are present in executable code but **not yet executed**.
They are not counted as passed, transport coverage or security evidence.

## Isolation and result handling

The runner copies future production `scripts/multiplayer/federation` into a
disposable Compatibility project under `/tmp/opencode`, imports it to register
scripts and runs GDScript contracts. XDG data/config/cache roots are temporary.
There are no real autoloads, accounts, microphones, VR, external connections,
actual multicast, user files or normal startup. Future pure services must not
start networking in their constructors; transport integration needs a later runner.

Exit **0** requires completed passing assertions; **1** means expected test
failures; **2** means missing Godot, timeout, crash, parse/runtime/engine errors
or missing completion marker. Python tests verify these distinctions. They do
not make a missing feature pass or suppress Godot errors.

## Proposed service contracts

These are test-first interfaces under `scripts/multiplayer/federation/`, not frozen
public APIs. Detached instantiable objects, no constructor IO/network side effects.
Implement real behavior or adapt with evidence, never passing placeholder services.
Methods return dictionaries with `ok: true` or `ok: false` plus nonempty string
`error`, except snapshots/queries and attempt descriptors noted below. Inputs are
copied, not mutated; timing parameters are injected monotonic milliseconds.

### `relay_preferences.gd`

- `configure(path)`, `load_preferences()`, `save_preferences()`;
  `snapshot()` → `{entries: [...], blocked_ids: [...]}`.
- `add_entry(entry)`, `move_entry(entry_id, index)`, `remove_entry(entry_id)`,
  `set_blocked(relay_id, blocked)`, `migrate_legacy(host, port)` → result.
- Entries have local `entry_id`, label, host, UDP port and pinned `relay_id`.
  Reject duplicate identity/endpoint and invalid ports. Top row is main; removal
  preserves blocks, unblock does not add an entry. Local reload preserves state;
  corrupt store is retained and cannot be saved over. Migration is idempotent.
- Current tests use relay-ID blocks; unpinned endpoint-block/UI/key-rotation cases
  remain follow-up. Save atomicity under interruption is not proven by a reload.

### `relay_connection_manager.gd`

- `configure(entries, blocked_ids, limits)`, `begin_selection(now_ms)`,
  `complete_attempt(attempt_id, outcome, now_ms)`, `retry(now_ms)`, `tick(now_ms)`,
  `set_blocked(relay_id, blocked)`, `open_directory(relay_id)`.
- Starting/advancing attempts return `{attempt_id, relay_id}`; authenticated
  completion returns success. Failures return diagnostic results. Snapshot includes
  `entries`, `current_relay_id`, `pending` descriptor and `directory_relays` array.
- Outcomes: `capacity_full`, `unavailable`, `authenticated` with verified relay ID;
  unsolicited `redirect` is rejected. The test models outcomes, **not actual TLS**.
- Full A → down B → connected C; one shared pending attempt, stale result rejection,
  no reordering/forced failback; block invalidates active/pending links; timeout
  advances; all blocked is offline. Secondary directories coexist with gameplay
  ingress, respect blocks and total `max_connections`, and never reorder entries.

### `relay_route_policy.gd`

- `configure(user_blocks, operator_blocks, epoch, max_hops)`,
  `set_user_blocked(id, blocked)`, `set_operator_blocked(id, blocked)`,
  `authorize(route)` → result.
- Route has `origin`, actor `ingress`, authenticated `path`, `verified` boolean and
  `policy_epoch`. Reject blocked origin/ingress/transit, loops, unknown IDs, missing
  origin path endpoint, stale policy and unverified routes. `verified` is supplied
  by a future trusted transport verifier, never a world/client payload assertion.
  This tests policy after verification; it is not cryptographic provenance testing.

### `federation_directory.gd`

- `configure(limits, blocks)`, `ingest(origin_id, boot_id, sequence, summaries,
  authenticated_path, now_ms)` → result; `snapshot()` → array;
  `set_blocked(id, blocked)`, `withdraw_origin(id, boot)`, `expire(now_ms)`.
- Public summaries are strict bounded objects with origin/boot/instance identity,
  content URL/hash, mode=0, name/description/count. No roster/admin/social fields.
  Same local code at different origins is distinct; repeat sightings deduplicate;
  old sequence fails; origin block purges and prevents indirect reappearance;
  withdrawal and TTL remove stale rooms. Transport identity is a trusted input
  here, not inferred from unsigned directory data.

### `lan_relay_discovery.gd`

- `configure(limits, blocked_ids)`, `observe(datagram_bytes, source_ip, now_ms)` →
  result; `candidates()` → unverified candidate array; `verified_directory(id,
  boot_id, public_summaries, now_ms)` → result; `instances()` → verified summary
  array; `expire(now_ms)`.
- Synthetic advertisements use version/relay ID/boot ID/label/host/port. Discovery
  is enabled with bounded candidates/TTL. Ads alone cannot be joinable instances;
  verified directory response can populate the world-list model. Duplicate,
  blocked, malformed, oversized, nonlocal-probe and wrong-boot inputs are checked;
  expiry/opt-out removes or prevents state. No real DNS-SD/UDP service is selected
  by this test schema, and no authentication to discovered servers is performed.

### `federated_instance_state.gd`

- `configure(global_instance, allowed_items)`, `admit(actor, trusted_proof)` →
  result; `apply_item(actor, event)` → result; `snapshot()` → data;
  `disconnect_actor(actor)`, `lose_origin()`.
- Global instance contains origin relay/boot, instance ID, exact world revision.
  Actor contains account, ingress, local peer number and connection generation.
  Admission proof is a trusted verifier result with `verified`, matching destination
  and `fresh`; a boolean from an untrusted client is never sufficient in production.
- Same peer number via different ingresses remains distinct; one origin grants
  exclusive item epoch; competing/stale-generation/foreign-hash requests fail.
  Disconnect removes identity and indirect lease references; loss of origin sets
  `suspended` and cannot grant leases under a newly self-elected coordinator.

## Remaining integration/security gates

This initial suite does **not** test real relay federation, encryption/identity
handshakes, UI settings actions, endpoint pins, DNS, mDNS/multicast, capacity
packets, cross-relay voice/profiles/social admission, policy handoff, partitions,
real scene carrying, boot/key-change replay or exhaustive distributed cleanup.
Do not describe the six pure service groups as testing the entire roadmap.

Next integration runner should start three isolated real relays in chain/triangle
topologies and two independent example-world scenes. Route a real authenticated
join and item traffic through different ingresses to one origin; verify block
changes, partitions, collision-free identities, fallback and cleanup scans on
every relay. Physical LAN discovery needs a separate opt-in interface test with
explicit skip reporting when multicast is unavailable. No such integration test
is claimed to run in the present baseline.
