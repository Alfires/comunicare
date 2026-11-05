# Direct-IP collaborative project editing

Open **World Explorer → Edit local project…**. This edits the authoring JSON source,
not a reverse-imported `.cworld`. Keep the source alongside your exports.

## Owner

1. Create/open a project and finish raw JSON changes before hosting.
2. Choose bind address and UDP port. `127.0.0.1` is same-PC only. For LAN, use the
   machine's LAN address or `0.0.0.0`; share the reachable LAN address, not `0.0.0.0`.
3. Click **Host editing**. Share the host address, port and displayed account
   fingerprint with your collaborator through a trusted channel.
4. Verify the requesting account fingerprint and approve it as **viewer** or **editor**.
5. Revoke access at any time. Save/export uses the host's canonical project state.

## Collaborator

1. Open the editor in another client, enter the owner's IP, UDP port and verified
   fingerprint, then click **Request access**.
2. Wait for explicit approval. No project is sent before approval.
3. Select an entity, enter X/Y/Z, and click **Move selected entity**. Viewers cannot
   move objects. Edits are validated and ordered by the host; stale edits are rejected.
4. Export/save is owner-only in the shared session. Disconnect leaves the latest
   snapshot visible as a local draft; received data cannot be revoked retroactively.

## Limits and security

This is a separate signed ENet protocol, not gameplay membership or public relay
discovery. Signatures authenticate sender/content but **do not encrypt traffic**.
Use a trusted LAN or VPN; no automatic NAT traversal, secure relay tunnel, friend-list
invitation integration or public-internet confidentiality is provided. Do not expose
an editing port to untrusted networks. Accounts use existing local keys; keys never
travel over the wire. Host fingerprint pinning and fresh challenge proofs prevent
accepting a different account merely because it knows an address.

Maximum eight connections, 64 KiB source project, bounded packets/rates, signed
session generation/sequences, 30-second approval timeout. Disconnect removes live
permissions; reconnect needs fresh approval. Host shutdown ends the session; no
authority migration. There is no durable relay data or project upload service.

Current collaborative operation is entity translation only. Raw JSON is read-only
while connected. No 3D gizmos, asset synchronization, rotation/scale editing,
collaborative undo UI or actual isolated player-launch integration yet. Export to
`.cworld`, then use **Open local map…** for manual offline playtesting. Unsaved-change
confirmation and full rendered/VR panel acceptance remain unfinished.
