# Public world discovery roadmap

Original scope: plan and failing acceptance tests. Implementation has now started at the user's request; the original plan and initial red-test result are retained below as the baseline.

## Implementation status

Discovery UI refinement: do not display a total public-instance count. The world-info instance list excludes the player's current `current_session_id`, while retaining other instances of the same world and the world card itself. Per-instance player counts remain visible.

Implemented: URL-grouped world cards, persistent world-info public-instance list, independent catalog/snapshot state, periodic refresh and disconnect cleanup, public summaries without membership IDs, relay lifecycle fixes, URL-checked joins with explicit result packets, staged world loading without implicit hosting, explicit public-instance creation, and movement/voice suppression during transitions. Non-public direct joins are denied until an authorization system exists.

Clients and relay must both be updated: `SESSION_RESULT` is a new packet type and new clients require acknowledgements. The relay accepts legacy ID-only join requests, but this does not make new clients compatible with old relays.

Run `python3 tests/public_discovery/run.py` for browser contracts, real coordinator/loader checks and a three-client loopback ENet integration test. The test project uses lightweight world/avatar resources; it does not launch the complete VR game or prove VR input usability. `tests/.gdignore` prevents fixture autoload scripts being imported as game scripts.

Current verified result: **75 checks passed, 0 failed** (51 discovery contracts plus 24 startup/lifecycle checks), including the actual relay packet exchange, join rejection, acknowledgement matching, timeout/disconnect recovery, loader staging and activation without hosting.

Startup regression coverage: `tests/public_discovery/startup_suite.gd` runs in a second Godot process with the real `NetworkHandler` autoload and the real browser `_ready()`, `_process()` and `_exit_tree()` paths. Only the external catalog request is replaced via `_request_catalog()`; browser initialization is not skipped. This suite reproduced the reported `NetworkHandler.peerŝ` invalid-property error before correcting it to `NetworkHandler.peer`. It checks absent/unconnected/connected/replaced peers, actual startup discovery requests, scene button wiring, duplicate subscriptions, reopen, own-instance filtering with the real acknowledged session identity, timeout recovery and disconnect cleanup. The runner treats Godot runtime errors as failures even if assertions continue to run.

Still pending: VR/desktop visual playtesting, safe reconnect UX, cache/staging-directory cleanup, comprehensive hostile-archive limits before decompression, sandboxing downloaded scene/script content, non-public authorization, multi-relay discovery, and pagination/scaling. Extracted paths are constrained and download/extracted-byte limits exist, but loaded Godot world content is **not sandboxed**; use trusted world packages only. A post-ack activation failure disconnects from the relay as an explicit recovery path rather than pretending the scene/membership transition is atomic.

Full-project import is currently blocked by an unresolved `XRToolsRumbleManager` autoload UID and parse errors in bundled VRM addon scripts. Those unrelated files/configuration have not been changed by this implementation.

## Required player experience

- Show **one world card per exact world URL**. Identical names do not imply identical worlds; different version/query URLs remain separate. Keep `default_wold` as the built-in home identifier for compatibility.
- Opening a card opens its world-info menu, including an **Instances** submenu/list containing **every public instance of that world**, regardless of who created it. Do not limit results to friends, catalog entries, or the first instance found.
- Never show private, friends-only, friends-plus, or request-only instances in public discovery. An instance changing away from public must disappear on refresh.
- Each instance shows its name, description, population, and its own Join button. Joining targets that instance's `session_id`, not its URL, owner, or position in the list.
- Keep **Create instance** separate from **Join existing instance**. Catalog worlds and home remain usable with zero public instances; discovery-only cards disappear when their last public instance disappears.

“All instances” currently means all public instances on the connected relay. Cross-relay discovery is a separate feature: identities then need `(relay identity, session_id)` and joining needs relay routing. The current client connects to one relay.

## What the code currently does

| Area | Existing behavior / gap |
| --- | --- |
| `relay_protocol/public_wolds.gd` | Reliable JSON-array discovery packet already exists. Keep it; strengthen validation rather than inventing a second transport. |
| `scripts/multiplayer/relay.gd:get_public_session()` | Already filters `PacketInfo.MODE.PUBLIC`, but exposes raw `owners`/`peers` and includes empty sessions. |
| `relay_protocol/relay_peer.gd:on_packet()` | Decodes discovery and emits the array. `public_session` is not populated; signal declarations do not describe their payloads. |
| `scripts/GUI/world_explorer.gd:_ready()` | Sends before connecting its response callback; assumes a connected peer. Also downloads an independent HTTP catalog. |
| `world_explorer.gd:load_sessions()` | Ignores the supplied sessions, appends another home entry every call, and renders only catalog data. |
| `world_explorer.gd:create_world_info_menue()` | Creates a temporary menu with one generic Join button; no instance rows. |
| `world_explorer.gd:_on_join_pressed()` | Loads a world and creates a session instead of joining an existing one. |
| `scripts/startup/data_loader.gd` | `load_world()` creates a session as a side effect. `load_world_from_url()` does not propagate extraction/scene-loading failure. |
| `scripts/multiplayer/network_handler.gd` | Creation always advertises `default_wold`, even for downloaded worlds. Joining logs success before any relay confirmation and does not load the target world. |
| `relay.gd:peer_connected()` | Automatically inserts a newly connected peer into the first session (and assumes its membership list has no duplicate). Relay connectivity must not imply joining. |
| `relay.gd:on_packed()` join branch | Removes old membership before validating the destination; has no join-result response or access-mode enforcement. |
| `relay.gd:peer_disconnected()` | Removes entries while iterating forward; adjacent empty sessions can be skipped/out-of-range. Owners are not updated. |

## Implementation order

### 1. Define the contract and relay-owned lifecycle

Retain existing packet IDs and the array snapshot initially. Define a public summary:

```text
session_id: non-empty string unique on this relay
world_url: absolute HTTP(S) URL or exactly "default_wold"
mode: PUBLIC (0)
name, description: bounded strings
player_count: non-negative integer calculated by relay
```

Do not send raw membership/owner IDs in public discovery. Validate creation metadata at the relay. Reject unknown modes, invalid URLs and oversized fields. Maintain one active membership per peer, generate collision-free session IDs, remove empty sessions safely, and define owner departure behavior (recommended: instance persists while any participants remain). Do not silently add newly connected peers to any room.

**Tests now:** public-only baseline, packet round-trip, public-summary privacy, empty-session exclusion, no auto-join, missing-target membership preservation.

### 2. Store catalog and discovery independently

Suggested responsibilities (names are proposals, not existing APIs):

- `catalog_by_url`: optional HTTP metadata only.
- `public_instances_by_id`: validated latest relay snapshot, replaced atomically.
- `worlds_by_url`: derived union of catalog, home and discovered URLs; each world contains its matching instance IDs.

Accept public worlds that are not in the official catalog. Use safe fallback display metadata for those worlds. Deduplicate session IDs before grouping, fail closed on missing/unknown visibility, and reject unusable IDs/URLs. Do not mutate the catalog when rendering home. Do not let a late HTTP response call `load_sessions([])` and erase discovery. Avoid URL normalization that merges distinct version/query URLs.

**Tests now:** unknown worlds, same-URL grouping, distinct query versions, stable home/catalog cards, duplicate/malformed records, HTTP/discovery arrival order.

### 3. Build world-info instance UI

In `scenes/GUI/world_explorer.tscn`, prefer a persistent world-info panel and scrollable Instances container over dynamically creating whole menus. Keep selection by URL and row identity by session ID. Rows show instance name/description/population and Join; one card must expose all matching public rows. Support home identically. Distinguish loading, no public instances, relay disconnected, catalog unavailable and refresh error.

Update an open submenu when snapshots replace state. Remove vanished/private rows, retain selected world when sensible, and never duplicate signal connections on reopening. Connect discovery callbacks **before** sending; request only once connected; disconnect/clear stale state on relay loss. During refresh, mark old state as stale rather than accidentally presenting a failed request as “no rooms.” Add a bounded timeout and prevent concurrent stale responses from overriding newer state (request IDs if concurrent requests are allowed).

**Test hook:** instance row root has `session_id` metadata; row contains a Label with its advertised name and a Button labeled `Join`. Tests click real card/row signals. This is a small proposed observable UI convention, not a production implementation.

**Tests now:** exact submenu membership, labels, home submenu, live removal, refresh replacement and no duplicate cards.

### 4. Make joining explicit, acknowledged and independent of hosting

1. Snapshot the selected session ID and advertised world URL; disable repeated Join clicks.
2. Download/validate the world into a staging area **without creating a session or changing active membership**. Home uses the built-in scene. Propagate download, extraction, manifest and scene errors accurately.
3. Send the selected ID through `NetworkHandler.join_session()` / `JoinSession`; do not automatically create a replacement session if it vanished.
4. Relay validates destination existence and access permissions **before** leaving the old instance. Public instances need no friendship/invite checks. Non-public direct-ID joining needs its own real authorization policy; hiding a room is not access control.
5. Add an explicit join-result packet/signal with session ID, authoritative world URL, success/error and useful failure codes. Peer-list updates alone are not reliable acknowledgement. If the URL changed, abort/re-stage rather than loading the wrong world.
6. On success, activate the staged scene, clear old remote players and install the authoritative membership. Handle activation failure with a defined recovery path; do not claim a fully atomic client/relay transition without one. On rejection/timeout, retain the previous usable world and show an error.
7. Move hosting into an explicit Create action, advertise the actual loaded URL and chosen mode, and create exactly once after successful loading. Audit startup hosting separately so it cannot run during joins.

Update `data_loader.gd`, `network_handler.gd`, `relay_peer.gd`, `relay.gd`, protocol packets and explorer together in this phase. Do not “fix” the UI alone while keeping implicit hosting in the loader.

**Tests now:** selecting Bob rather than Alice calls `join_session("bob")`, loads Bob's advertised URL and never invokes Create. Fake loader completes immediately; these tests do **not** yet prove staging/acknowledgement ordering or the real loader's lack of side effects.

### 5. Integration hardening before release

Add tests alongside each new lifecycle/protocol API; do not treat the initial suite as complete release coverage:

- Real loader: join never emits CreateSession; failed downloads/archives/manifests preserve active state; correctly propagate errors. Treat untrusted world archives/scene resources as a separate security boundary: constrain extraction paths, size and executable content.
- Two clients host different public instances of the same URL; third client sees one card, two rows and can join either, including an owner who is not a friend.
- Different URLs with identical names do not merge. Catalog unavailable still permits discovery and joining.
- Join acknowledgement/rejection, vanished room, mode changed after listing, timeout, double-click, disconnect/reconnect, out-of-order refresh, malformed packet and unauthorized private-room ID.
- Last participant leaves, owner leaves with other participants remaining, multiple adjacent empty sessions cleaned up, switching instances and accurate counts.
- Desktop and VR: scroll/focus/navigation, Back, reopen, refresh while info is open, readable errors; no duplicate signal connections.
- If scaling requires pagination, exhaust all pages before claiming all instances are shown. Multi-relay support requires relay-qualified identities and explicit reconnection tests.

## Tests added now

Run from the repository root:

```sh
python3 tests/public_discovery/run.py
# Optional executable override:
GODOT=/path/to/godot python3 tests/public_discovery/run.py
```

Requires Python 3 and Godot 4 (verified with 4.7.2). No test plugin installation or main-project configuration changes required. The runner copies the actual explorer scene/script, relay, coordinator, loader and protocol scripts into a disposable project under `/tmp/opencode` when available, imports its class names, and runs `suite.gd` headlessly. HTTP/startup/autoload services are replaced by test doubles. Unit tests run relay methods without a listening server; the integration test starts a real ENet relay bound only to loopback on an ephemeral port, with three local clients. There is no external relay dependency. Loader archive fixtures and extracted files are written inside the disposable project.

Exit `1` means acceptance assertions failed (expected until implementation); script/import errors are infrastructure failures, not intended failures. Existing working filtering and serialization remain passing regression checks. Failures assert desired behavior, not unconditional `assert(false)` placeholders. No production file is modified by the runner.

Initial verified result: **2 passing regression checks, 18 failing acceptance checks**, exit code **1**, with no script/import errors.

The tests deliberately use current entry points (`load_sessions`, the HTTP callback, card presses, relay handlers) rather than requiring an unimplemented discovery service. Fixture autoloads record join/create/load calls. Later implementation can keep these entry points as adapters or update the harness while preserving the behavioral contracts.
