# Relay federation setup and current limits

This implementation adds certificate-trusted TLS directory peering, simultaneous
anonymous client directory connections, IPv4 multicast LAN hints and routed ENet
gameplay. One origin still authenticates accounts and owns admission/membership/
moderation/item leases. Intermediate relays forward bounded datagrams, not game
logic. Existing world hosting/downloads are unchanged.

## Operator setup

The easy local provisioning command generates a new identity and ready-to-edit
configuration without launching the game or touching account data:

```sh
python3 tools/relays/provision.py /absolute/private/my-relay --label "My relay" --lan
```

The destination must not already exist and must be outside this repository.
Private keys are permission-restricted; failed partial output is preserved for
inspection rather than silently regenerated. `GODOT` overrides the executable.
The command prints the relay ID and startup command. Remove `--lan` if you do not
want local advertisements. Add trusted neighbours to the generated `peers` list.

Provision a private RSA key, X509 certificate and public key **outside the source
repository**. Use common name `comunicare-relay` (or configure the expected name).
Distribute the public certificate and public key through a trusted channel; never
distribute the private key. Godot `Crypto.generate_rsa()` and
`generate_self_signed_certificate()` can provision these, or use your normal PKI.
The relay ID is SHA-256 of the canonical Godot public-key PEM UTF-8 bytes, not the
certificate DER or an account key. Keep infrastructure keys stable across restarts.

Create an operator JSON configuration outside the repository:

```json
{
  "schema": 1,
  "key": "/absolute/private/relay.key",
  "certificate": "/absolute/public/relay.crt",
  "bind": "0.0.0.0",
  "port": 7375,
  "label": "My relay",
  "lan_enabled": true,
  "blocks": [],
  "peers": [
    {
      "host": "relay-b.example",
      "port": 7375,
      "public_key": "/absolute/public/relay-b.pub",
      "certificate": "/absolute/public/relay-b.crt",
      "common_name": "comunicare-relay",
      "connect": true
    }
  ]
}
```

Start the existing relay plus configured federation listener:

```sh
godot --path . --relay -- --federation-config=/absolute/private/relay.json
```

Open the existing UDP gameplay port (7374 by default), configured TLS/TCP port and
local UDP discovery port 37374 where needed. Relay peers authenticate the server
certificate and sign fresh nonce-bound neighbour challenges. Each origin signs
public summary bodies; intermediates forward only known/trusted origin signatures
with bounded hop paths. Configure both peers' public trust entries; use `connect:
false` on a peer that accepts incoming links only. Configuring a peer's key is not
equivalent to an active route. Retry/backoff handles lost outgoing links.

Only pinned world revisions are exported. Private/social/request instances are
not in the public directory. Signed summaries expire; infrastructure configuration
can persist, but users/sessions/tunnels/directories remain in memory only.

## Client setup

Settings → Network has fields below the ordered list for relay ID and certificate
path. Enter a verified relay ID, its TLS host/port and certificate path, then press
**Trust directory certificate for address above**. This explicit action stores the
certificate in `user://relay_directory_trust.json`; no LAN ad silently grants trust.
Up to four trusted directory links are queried concurrently without an account.
Their public instances appear in World Explorer with a federated relay badge.

To use a verified relay as default ingress, fill its relay ID when adding the saved
entry. The existing ordered list still controls main/fallback priority; discovering
or trusting a directory does not reorder that list. Unpinned saved entries continue
to use legacy plain ENet and are not claimed to authenticate the relay server.
Certificate changes need explicit removal/re-import; changing the ordered list
does not approve a certificate. The UI includes removal of trusted directory entries.

Selecting a federated instance stages the exact content hash, establishes a verified
TLS tunnel and freshly authenticates to the origin through the normal ENet protocol.
Clients entering different relays can share one origin instance. The origin's local
actor IDs remain unique inside that instance, rather than truncating global actor
IDs. Voice/pose/animation/profile/item packets use existing origin authorization.

## LAN and blocks

When enabled, relays advertise bounded hints to `239.255.73.74:37374`. Clients
listen locally and list untrusted candidates in Network settings. Use a hint to fill
the address fields, then verify/import the operator certificate. Matching trusted
directories can supply public instances; unverified ads never become joinable rooms.
The current implementation is IPv4 multicast, not DNS-SD/mDNS or IPv6 discovery.
Godot does not expose multicast TTL controls here; deployment must restrict multicast
scope. Interface permission/firewall and multiple-process port binding vary by OS.

User identity/endpoint blocks suppress queried directories and origin results.
Operator blocks reject blocked link identities and origin/transit paths, close
dependent tunnels and purge directory state. Blocking/changing route policy ends
affected gameplay instead of allowing stale packets to restore it. Removing a
preference does not remove its block. No block can stop a malicious operator from
re-signing copied data or disguising its real network relationships.

## Important remaining limitations

**Scope clarification:** internet-wide/global peer discovery is deliberately out
of scope. Use explicitly configured trusted peers and local hints; no DHT, network
crawler, public registry, automatic global peering or NAT traversal is planned for
this implementation. External hardware is not needed for the automated tests.

- This is a **TLS/TCP tunnel for ENet**, not a low-latency datagram transport.
  Head-of-line blocking affects voice/poses; real WAN/VR load and loss testing is
  still required. Frame, queue, rate, connection, path and tunnel caps fail closed.
- Origin loss ends the route; no competing origin is elected. Changing to another
  instance preserves old membership only during staging/route preparation. Once
  transport switching begins, old membership ends even if destination auth fails.
- Operator seeds/trust are manual; automatic internet peer exchange and trustless
  automatic certificate bootstrap are not implemented. LAN candidates need initial
  out-of-band certificate trust. An untrusted LAN cannot safely supply its own trust.
- Relay-origin/transit blocking is enforced on known routes. The tunneled ENet
  membership schema does not yet expose every remote participant's ingress relay
  to each client; the roadmap's per-actor ingress conflict policy is **not complete**.
- Public directory data is limited to 64 KiB frames. Large summary sets need paging
  before this can scale beyond the bounded prototype; overflow closes/rejects rather
  than allocating unlimited buffers. No seamless origin migration or durable replay.
- Current TLS identity derives trust from manually associated public key/certificate
  records, not an audited federation PKI. Independent hostile-operator review,
  wrong-certificate/replay/partition stress tests and cross-platform deployment gates
  remain required. Passing loopback tests is not security certification.

Verification: `python3 tests/relay_federation/run.py` includes 81 service/UI and
additional actual TLS/three-relay/two-client/UDP and route/trust failure assertions.
`python3 tools/relays/test_provision.py` verifies provisioning path safeguards.
Physical Wi-Fi multicast,
renderer, headset input and Internet firewall reachability are not certified.
