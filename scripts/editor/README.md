# Local project editor and direct-IP collaboration

Open **World Explorer → Edit local project…**. Create/open authoring JSON, edit
supported primitive entities, save source separately or export a validated `.cworld`.
Use **Open local map…** to play the exported package. Existing `.cworld` files are
not reverse-imported into source projects. Save before closing; unsaved-change
confirmation, viewport gizmos and visual asset authoring are not implemented.

## Editing with other users

The owner can host a separate direct-IP signed ENet editing session. A collaborator
pins the owner's account fingerprint and proves their own identity, then waits
for explicit viewer/editor approval. Translation edits synchronize through the
owner; revocation/disconnect removes live permissions. No project is sent before
approval. Save/export from the shared session is owner-only in the panel.

See [editing with friends](../../docs/guides/editing-with-friends.md) for addresses,
ports and limits. Signatures authenticate but **do not encrypt** traffic. Use a
trusted LAN/VPN. There is no friend-list invitation integration, automatic NAT/relay
traversal, host migration, arbitrary asset transfer or public editing discovery.
Normal gameplay membership never grants editing rights.

## Services and boundaries

- `project_store`: shared authoring validation and atomic JSON save/load; recovery
  keeps the valid main file rather than preferring an incomplete temporary write.
- `edit_commands`: derived translation edits and revision-checked inverse operations.
- `edit_authority`: owner/editor/viewer access, generations, revisions and replay checks.
- `edit_leases`: bounded manipulation leases; not a complete collaborative gizmo UI.
- `edit_session`: authenticated direct-IP connection, explicit approval and snapshots.
- `editor_input`: translation-only canonical input; unsupported rotation/scale rejects.
- `editor_playtest`: validated package preparation and snapshot restoration only;
  it does not launch a production player or switch maps.

Run `python3 tests/map_editor/run.py` for service, panel-instantiation and real
loopback transport checks. Passing these does not certify rendered multi-window
editing, physical VR comfort or full collaborative project recovery.
