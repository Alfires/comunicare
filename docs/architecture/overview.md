# Runtime architecture

## Ownership

```text
startup.tscn → scripts/startup/main.gd
  SaveData: settings, mute, account key, signed profiles and contacts
  NetworkHandler → RelayPeer → ENet relay
  DataLoader → AssetCache / avatar configuration / import workers
  root-local player survives acknowledged world transitions
```

Autoload order is DataLoader, SaveData, NetworkHandler. SaveData loads mute and
settings before player capture starts. Startup selects `--relay` or the
`dedicated_server` feature before client startup; `--non_vr` selects desktop.
Otherwise startup attempts OpenXR and falls back to desktop on supported systems.
Normal startup can generate `user://user.key`; isolated tests substitute accounts.

## Network lifecycle

The client authenticates proof of account-key possession. The relay assigns
connection identity; claimed actor IDs are not authorization. A world URL names
content, while `session_id` names an instance. Joining stages/validates content
before requesting admission; scene activation waits for a matching acknowledgement.
Rejected joins preserve old membership; uncertain committed transitions disconnect
rather than broadcast from the wrong world. See [relay lifecycle](../relay-data-lifecycle.md).

Profiles are owner-signed and instance-scoped. Friends are client-local signed
contacts/consent, not relay history. Presence is neither access nor editing
permission. Moderated joins require fresh current-admin policy; missing policy
fails closed. Disconnect removes indirect identifying references as well as the
departed connection's own records.

## Asset and avatar lifecycle

`DataLoader` coalesces bounded cache acquisition, validates sources, imports
detached models on workers and returns ownership to awaited main-thread callers.
Generation guards prevent stale imports replacing newer selections. Content hashes
identify revisions, not trusted authors. Cache leases protect active content;
failed refreshes keep known-good revisions. Remote world scenes can execute code:
trust opt-in is not a sandbox.

Avatar configuration resolves external/embedded humanoid motion and defaults.
One animation controller chooses locomotion or requested emotes and publishes
resolved version-2 state. The renderer blends owned bone rotations; separate
first-person derivatives share the original skeleton. Camera transforms stay
player/tracker-owned. A final local tracking modifier aligns head and arm targets;
this is not networked tracker-pose or full-body IK support. See the
[current usage and limitations](../asset-cache-and-animation-usage.md).

## Source and evidence

Owners: [startup](../../scripts/startup/main.gd),
[SaveData](../../scripts/settings/save_data.gd),
[DataLoader](../../scripts/startup/data_loader.gd),
[client](../../scripts/multiplayer/network_handler.gd),
[relay](../../scripts/multiplayer/relay.gd).
Verification: [testing guide](../development/testing.md). Full-renderer, physical
capture, headset comfort and large-transfer network behavior remain manual gates.
