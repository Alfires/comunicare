# Dropped pickup physics synchronization

Idle pose publication is change-driven: movement of at least 1 mm or rotation of
0.001 radians sends the next available physics update; unchanged bodies send a
one-second repair update rather than a packet every 50 ms. A new lease epoch always
republishes. Sender history is cleared on world reset. This reduces idle traffic,
not a measured rendering FPS improvement.

WORLD_DATA hello negotiates optional `physics_version: 1`. Within each acknowledged
instance, the lowest connected supporting peer ID is elected physics publisher.
Only that peer may publish `physics` poses for already-known, unheld items. Existing
holder/epoch/sequence and world revision checks still apply. Holding uses the holder
as before; released replicas freeze and follow canonical published poses. Snapshot
responses include the physics owner even if the item sequence has not changed.

This is client-authoritative, not server physics or anti-cheat. Only pickups already
introduced through a grab are tracked; untouched scenery does not become a network
body. Re-election is discovered through the periodic snapshot cycle, so publisher
loss may temporarily freeze replicas. Old clients do not offer the new physics
capability. Legacy mixed-client behavior is not a full synchronized simulation.

The real loopback world test checks continued dropped movement between independent
physics scenes. Arbitrary health/inventory/quest stats are not added to this wire
extension: they need a reviewed state schema, authority and gameplay protocol.
Client-local run state and permanent saves remain local rather than being silently
broadcast to other people.

Editor crash regression now instantiates the production panel: its former `owner`
member conflicted with native Control.owner and prevented script loading. Local
file-picker activation is deferred out of its callback; closed ENet peers are not
disconnected twice. A two-client journey loads a local file after repeated world
switches. This is not reproduction of every platform-specific native file crash.
