# Initial local project editor and collaboration primitives

Update: direct-IP signed editing transport and owner approval UI now exist. See
[editing with friends](../../docs/guides/editing-with-friends.md) for the current
workflow and limitations. Translation edits synchronize over real ENet; no project
is sent until owner approval. Transport is authenticated but not encrypted; use
trusted LAN/VPN only. The older disabled-transport description below is superseded
by this update, not a claim of full roadmap completion.

Open **World Explorer → Edit local project…**. Create/open a local authoring JSON,
edit supported primitive entities, save it or export a validated `.cworld`. Open
the export through **Open local map…**. Save before closing; there is no unsaved
changes dialog, visual gizmo or viewport editing yet.

The editor accepts source JSON projects, not reverse import of a packaged map.
Keep the original authoring project alongside its exported package. Account changes
block saving through an old panel. Arbitrary GDScript and unsupported assets remain
rejected by the shared authoring validator.

`edit_authority` implements local owner/editor/viewer checks, revocation, generation,
revision and replay rejection. `edit_leases` handles exclusive manipulation expiry.
These are **not connected to authenticated network routing**. There is currently
no working friend invitation/join/edit UI, session discovery or project transfer.
Do not expose these services to packet-provided sender identities. Remote access is
disabled until reviewed capability negotiation/admission/transport exists.

`editor_playtest` compiles and preserves a snapshot; it does not launch a player or
switch worlds. No claim of actual progress isolation in a launched game is made.
`editor_input` currently supports canonical translation only, not rotation/scaling.

Run `python3 tests/map_editor/run.py`: **36 service assertions pass**, zero blocked
groups. This validates local services/export, not a collaborative editing journey.
Broader production UI checks encountered concurrent menu-shell wiring failures;
the local editor panel has not passed a full rendered acceptance journey.
