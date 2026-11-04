# Relay lists — initial implementation

Settings → Network now includes an ordered relay list. Add a hostname/IP and UDP
port, make a row main, move it down, remove it, or block/unblock its endpoint.
The top allowed entry is tried first. Timeout/unavailable transport advances to
the next saved entry; successful fallback does not reorder the saved list.
World Explorer Reload retries while offline. No healthy connection is switched
just because the list was reordered. Blocking the active endpoint disconnects it;
Reload then selects an allowed entry. Remove does not delete its block.

Preferences are device-local at `user://relay_preferences.json`. Existing scalar
address/port settings migrate once; afterward edit the list, not the legacy fields.
Corrupt/newer preference data is preserved read-only, not silently replaced.
Account authentication rejection stops selection rather than bypassing policy by
trying every relay. Full old relays may only time out; typed capacity replies
are not yet part of the live transport.

## What is not implemented yet

The federation directory, LAN candidate parser, route policy, origin state and
selection policy have isolated tests, but **no relay-to-relay network transport,
secure server identity handshake, actual simultaneous directory sockets, physical
LAN discovery or cross-relay gameplay is connected**. They are not usable simply
because service tests pass. Existing gameplay still uses one ENet relay at a time.

The UI adds unpinned endpoints. Programmatically pinned relay IDs fail closed in
the live client because current ENet client authentication does not authenticate
the server identity. Do not claim identity blocks/security across changing endpoints
until the authenticated transport is implemented. User endpoint blocks work now;
operator transitive blocking remains a service policy awaiting transport wiring.

Verification: `python3 tests/relay_federation/run.py` (81 service/UI assertions),
`python3 tests/multiplayer_reliability/run.py` (including actual client fallback
from unavailable endpoint to a real loopback relay). The RED baseline in the
roadmap is historical; encrypted federation/LAN integration gates remain open.
