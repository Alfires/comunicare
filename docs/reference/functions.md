# Production function contracts

Landscape vegetation now distinguishes pine/fir species, retains authored fir
canopies where reduced base topology lost needles, and adds bounded fern/stump
clusters. Meadow shading applies world-space color variation to the cleared grass
maps; path shoulders are visual only. These changes do not alter spawn/routes or
grant runtime download authority; higher source-fir triangle cost needs profiling.

Additional editor/world helpers and their operating limits are covered in the
[supplemental production contracts](recent-functions.md), which are checked by
the same coverage tool.

House exterior integration builds static collision from visible modest glazing,
frame, sill, porch-post and beam mesh faces, transformed into house coordinates.
Hidden source geometry, oversized detail meshes and the widened entry corridor
are excluded. Landscape ready adds bounded root branches and shoreline rock/plant
placements without dynamic physics or changes to microphone/network state.

Layout `_rim_point` maps only the outer terrain grid to a deterministic radial
contour, leaving the center and routes unchanged. `_build_land` now constructs
an irregular six-ring rock underside rather than a CylinderMesh cone. House
exterior integration fits static side-wall proxies to aggregate transformed wall
bounds so collision does not remain inside the nominal imported footprint.

House `rest_at` accepts only a nearby local player and named bed/sofa, validates
target/exit space and stores a weak rest record without changing local tracked
pose or yaw. It pauses physics walking until `leave_rest`, which validates the
exit or center fallback and restores the prior process state. Home return releases
rest first; teardown clears metadata/process suppression. The imported raised
foundation is hidden to keep the visible floor aligned with app-owned collision.

House `_install_exterior` integrates the cleared bungalow visual while preserving
app-owned circulation/collision. It hides source steps/closed entrance visuals,
rebuilds only the visible front-shell surface for broad access and applies independent
roof-finish overrides. Original GLB bytes/material resources are not mutated globally.
`_furniture` selects named realistic Poly Haven replacements for lounge/daybeds/tables,
uniformly sizes them and records `style_source`; daybed scale uses footprint rather
than the old low-poly height. Decorative architecture is not a collision certificate.

<!-- module: scripts/worlds/welcome_island/landscape.gd -->
## Initial built-in landscape composition

Private ready deterministically places individual cleared optimized sapling/rock
scenes, bounded mesh visibility and simple trunk/perimeter collision proxies.
It does not load a complete environment, use the active scene from a worker,
download content, alter spawn or grant remote scripts. Source assets remain
unchanged; final landscape art and XR performance acceptance remain open.

<!-- module: scripts/GUI/home_help.gd -->
## Optional home Help

`refresh_help` builds wrapping opt-in menu text from the current settings store or
an explicit test store. It reads bindings, XR mode and menu action without writes,
network calls or microphone changes. Private ready builds a 44-pixel toggle and
session-only highlight switch; `_setting_changed` refreshes attached UI only.
Expanded state is process-local; highlight state lives on the current tree root.
Help visibility never grants/blocks gameplay, records progress or spawns lessons.

<!-- module: scripts/worlds/welcome_island/kitchen.gd -->
## Local kitchen foundation

`set_faucet` toggles the bounded stream mesh. `set_heat` accepts off/low/high integer
levels only and updates visible indication without damage/fire simulation.
`set_storage` and `set_fridge` reject occupied door travel space before translating
their panels within fixed bounds. `reset_kitchen` stops effects, attempts safe door
closure, releases local grips and restores eight registered items to their own
homes. `make_controls` returns shared-menu buttons with no saved preferences.
Private ready builds fixtures and temporary original kitchenware; exit stops effects.
State is client-local, not relay ownership; final premade kitchenware is still pending.

<!-- module: scripts/worlds/welcome_island/room_lighting.gd -->
## Local home room lighting

`set_zone` validates named zone, finite brightness 0.1–1.0 and warm/neutral palette;
applies enabled state to actual light energy (0–2), updates client-local state and
emits `zone_changed`, returning false without mutation on invalid input.
`make_controls` creates on/off, brightness and palette controls for the shared
Settings page, with no persistence/global preference writes. Private ready creates
three nonshadowed 7 m OmniLight zones and session defaults. State is discarded with
the house; no network replication, physical dimmer or real-headset certification.

<!-- module: scripts/worlds/welcome_island/house_spaces.gd -->
`rest_at` validates a local rest spot and records pose while suppressing conflicting motion. `leave_rest` restores deliberate movement safely. `make_rest_controls` builds local rest/leave UI, not a networked seat lease.

## Built-in house and furnishing assembly

Private ready builds a single-level shell and places individual cleared furniture
models. `_furniture` normalizes aggregate model bounds with uniform scale, centers
the base and optionally adds a simple static collision proxy. `_box` creates
timber structural meshes/collision. No remote scene code, player pose mutation,
sleep progression, working appliances or adjustable lighting is introduced.

Ship `_hull_clear` now uses a full hull-sized box for translation sweeps and four
sampled rotation/translation overlaps instead of a small sphere. `step` commits
yaw only with an accepted target; berth is offset clear of dock collision. Hull
materials are per-instance PBR timber overrides, never mutations of shared GLB
materials. Pond ripple shading is opaque/world-space with no screen/depth reads;
the revision generator includes `.gdshader` dependencies.

<!-- module: scripts/worlds/welcome_island/pond_ship.gd -->
## Local pond ship

`board` accepts a nearby player-group CharacterBody with a clear dock recovery
target, sets a weak rider link and requires neutral input. `drive` bounds finite
input and stops/rearms on suppression; `step` advances bounded level-plane motion
and translates the rider without forced yaw or local tracked-pose changes. `stop`
clears propulsion. `disembark` requires proximity to berth and clear bank capsule;
`return_to_dock` restores berth and safely releases to bank or center fallback.
Private UI/exit helpers create temporary controls, clear rider metadata and use
sphere-sweep/shore bounds for collision. This is local-only, not relay ownership,
full buoyancy or verified headset comfort. Explicit boarding confirmation belongs
to the built-in world/shared Controls UI; ordinary player movement is paused while riding.

## Pond and dock safety additions

`recover_from_pond` on the trusted built-in world defers player-only recovery,
checks standing clearance at the bank, cancels local grips and resets stopped
players at the bank or center fallback. `_recover_pond_player` never overwrites
tracked local head transforms. Layout `_build_pond` constructs the bounded standard
water surface, trigger volume and timber dock with shared cleared textures.
VR safety destination rays include areas and reject `teleport_disabled` targets;
the water surface is not a walkable body. Final XR water rendering is unverified.

Local pickup `_local_carry_clear` sweeps held collision shapes against original
world masks and checks destination overlaps before accepting a hand transform.
Blocked/nonfinite hand updates keep the last clear pose; release restores physics
there instead of teleporting props through walls. Rotation has endpoint overlap
validation only; this does not certify continuous rotating-shape clearance.

## Trusted local home interaction additions

`activate_local` on the shared pickup controller accepts a trusted current-world
node, rigid-body map and callable activation map. It restores previous ownership,
registers only descendants, and installs local-only state with no relay messages.
Downloaded document `activate` never selects this mode. `cancel_local_input` releases
local grips safely; `reset_local_item` restores a registered home with cleared motion;
`activate_nearest` invokes only an explicitly registered reachable/unobstructed local
callable. Local carry disables collision, drop restores original settings with no
throw velocity, and scene exit clears local references/callables. Desktop/VR retain
existing bindings and suppression; Controls settings discloses local-only behavior.

The recovery/PCK follow-up detects editor-source mode only when `project.godot`
is actually mounted. A pack hosted by the editor executable uses pre-export hashes;
the isolated pack test does not certify a standalone template or real headset.

<!-- module: scripts/worlds/welcome_island/home_contract.gd -->
## Built-in home spawn/revision contract

`reset_player` accepts a live Node3D and finite target, invokes its trusted
`set_player_pos` hook when present, otherwise translates the root, and clears
CharacterBody velocity without writing local tracked-camera transforms.
`revision` hashes sorted dependency records from the locally generated revision
JSON. Editor/source runs read actual listed bytes; exports use pre-export hashes
because imported resources are remapped. Missing manifest/dependency fails empty;
the local generator/check must run before export. This is built-in content identity,
not downloadable-world authorization or session identity.

<!-- module: scenes/world.gd -->
`recover_from_pond` resets only eligible local players through the shipped home recovery contract, not an externally callable remote-player authority.

## Built-in world recovery

`return_player_to_spawn` accepts only player-group nodes and delegates to the shared
contract. `register_recoverable` records a finite global home transform for a live
RigidBody using a weak reference, removes entries on exit, and returns acceptance.
Private ready/spawn callbacks place persistent players on direct world entry;
the void callback defers physics mutations. Registered items restore their own
pose and clear linear/angular motion; unregistered lost rigid bodies are removed.
This does not implement a pickup/vehicle ownership service or a public remote API.

<!-- module: scripts/worlds/welcome_island/layout.gd -->
## Built-in welcome island graybox

Private `_ready` builds application-owned terrain, original graybox footprints and
branching route strips from the layout scene. `_height` reserves a recessed pond
while keeping the dock bank dry. `_build_land` creates one continuous terrain
mesh/collision with boundary skirts and a tapered visual underside. `_box` and
`_material` create temporary colored layout resources; house walls have collision,
path/deck/garden color strips do not add raised obstacles. `routes` is an authored
traversal contract, not a required player route, network state or tutorial progress.
No account, relay, asset download, remote-world script permission or active player
ownership is changed. Final art, water, furniture and reset/revision policy are
separate roadmap parts; these helpers are trusted built-in code only.

Interaction highlight correction: `InteractionHighlight.show_targets` applies
instance-only material_overlay passes and restores preexisting overlays on exit;
it never duplicates geometry or changes physics/input. Physics-tick candidate
selection uses `WorldPickupController.nearest_available`, the same obstruction/
unheld/range selection used by `grab_nearest`. The local mirror defers desktop E
to a held or reachable ordinary pickup instead of swallowing its interaction.

<!-- module: scripts/GUI/credits_page.gd -->
## Offline asset Credits

`load_entries` accepts an array of records and rebuilds a read-only VBox from validated local asset records;
it reads full bundled license text, skips malformed/duplicate/missing-license entries
with visible feedback and never writes settings or downloads content. The private
ready loader merges `assets/credits.json` with the island manifest. Local file-path
and notice checks precede rendering; `source_requested` emits only after an explicit
source button activation. Settings owns the resulting OS browser action. Full terms
expand/collapse inline inside the existing settings scroll area. `_valid_record`
and `_add_text` validate local notice fields and build wrapping readable labels.
The page loads when first shown; `entries` is complete at once while the rows are
built four immediately and three per frame. `finish_build` builds all remaining
rows synchronously. Full terms use TextBlock and are shaped only when expanded.

<!-- module: scripts/assets/default_robot.gd -->
## Bundled default robot

`create` instantiates and normalizes the locally shipped robot, installs humanoid
mapping/content revision and prepares first-person geometry. Default and legacy
default URLs are resolved by DataLoader before external acquisition; other URLs
retain normal validation/import. No script/account/profile migration is performed.

<!-- module: scripts/assets/interaction_highlight.gd -->
## Local interaction hover overlay

Private process selects nearby unheld pickup candidates using desktop grip/VR
hand anchors, and bounded mirror surface proximity, with wall/focus/menu checks.
`show_targets` sets/restores instance-only transparent material overlays without
duplicating geometry. Physics process removes stale overlays and reads
the registry color live. No shared material edits, physics bodies or wire packets.

<!-- module: scripts/GUI/circular_value_control.gd -->
## Reusable circular numeric control

`configure` sets independent title/range/step/unit/value and callback without any
mirror/settings dependency. `set_fraction` maps finite normalized angle fraction
to a clamped stepped scalar and calls the consumer. `fraction` returns its normalized
value; `draw_on` draws the ring/value/Back hint in a caller's draw callback.

<!-- module: scripts/assets/local_mirror.gd -->
`can_grab_at` checks visible unheld surface proximity. `desktop_grab_hit` checks exact camera ray/reach/surface bounds. `grab_range` adapts reach to avatar size; hover/grab use these same predicates, without physics or network state.

## Client-only mirror

`place_in_front` places the local panel relative to the current camera, without
network or physics state. `resize_by` clamps panel dimensions/render target size.
`set_dimensions` clamps independent X/Y meters and updates geometry, notice and
aspect-preserving target. `set_quality` selects bounded low/medium/high longest-edge
resolution; registry signals apply live, teardown disconnects the setting listener.
`try_grab` accepts an anchor near the bounded mirror surface on either side, captures relative transform and reserves
one local grip; `release` clears only the matching grip without throw simulation.
Private process reflects the source eye across the panel and updates off-axis
frustum/clipping in a shared-world SubViewport; mirror/first-person derivative
layers are excluded. Desktop E and VR grip use the entire surface for movement;
the shader shades back faces dark gray. Hide/focus
loss releases grip; controller/session teardown frees mirror and viewport.

<!-- module: scripts/discovery/avatars/request_policy.gd -->
## Avatar discovery request policy

`origin` normalizes scheme/authority. `valid_url` accepts bounded HTTPS without
embedded credentials/token queries; explicit test transport permits loopback HTTP.
`prepare_request` returns URL/headers or empty; built-ins never inherit secrets,
custom bearer/API-key/OAuth bearer headers require the configured exact origin.

<!-- module: scripts/discovery/avatars/source_registry.gd -->
## Avatar discovery sources

`add_source` validates identity, endpoint and auth mode; custom sources only use
the catalog adapter. `set_credentials` stores custom-only secrets in memory;
`get_credentials` copies them. `remove_source` clears source and secret;
`export_configuration` returns nonsecret preferences. `clear_credentials` drops
all memory secrets. OAuth endpoint/public-client config may persist but session
verifiers and credentials never enter preferences; separate services handle login/store.

<!-- module: scripts/discovery/avatars/import_policy.gd -->
## Discovery import gate

`evaluate` reports format support, CC0 sharing and verified-compatibility equip
eligibility. Actual import/Apply still validate bytes and ownership; provider
metadata is never proof of humanoid compatibility.

<!-- module: scripts/discovery/avatars/discovery_service.gd -->
## Avatar discovery service

`configure` cancels prior work and clears credential context. `cancel` invalidates
generations, cancels HTTP and releases awaiters. `request_bytes` awaits bounded
requests, HTTPS redirects, origin/rate checks and no-store detection; returns
bytes or redacted error. `search` normalizes custom schema-1 catalogs or anonymous
OSA/VoxAvatar manifests and pages/filters fetched records. Metadata cache lasts
for five minutes in the open browser, then revalidates; custom advanced filters
apply to the fetched page. Teardown cancels pending work.

<!-- module: scripts/discovery/avatars/catalog_filters.gd -->
## Catalog filters

`apply` returns filtered copies using type/format/query/author/tags/category,
license/compatibility/redistribution/loop metadata and optional title ordering.
Unknown metadata never matches verified compatibility or a known loop flag.

<!-- module: scripts/discovery/avatars/thumbnail_cache.gd -->
## Bounded thumbnails

`decode` validates PNG/JPEG header dimensions and compressed bytes before native
decode, then caps rendered textures at 256px. Unsupported formats return null.
`get_texture` expires five-minute entries; `store` retains at most 64 textures.
No file persistence or authentication headers are involved in thumbnail fetches.

<!-- module: scripts/discovery/avatars/oauth_session.gd -->
## Custom-provider OAuth PKCE

`begin` validates public-client configuration and loopback callback, creates
cryptographic state/verifier and returns authorization URL with S256 challenge.
`accept_callback` requires exact callback/state, expiry, single use and a code;
returns form exchange fields without performing HTTP. `clear` drops session secrets.
The browser owns loopback Host checks, external browser and HTTPS token exchange.

<!-- module: scripts/discovery/avatars/credential_store.gd -->
## Linux Secret Service credential storage

`available` reports helper/platform availability, not whether the keyring is
unlocked. `perform` awaits a bounded worker/helper store/lookup/clear operation,
scoped to application/local-account/source/origin, with secret on standard input.
Unavailable/failed calls return false; never plaintext fallback. Teardown joins
worker. Actual Secret Service round-trip is an opt-in manual environment gate.

<!-- module: scripts/discovery/avatars/animation_conversion.gd -->
## Explicit in-place animation conversion

`convert` validates binary document, removes translation channels and repackages
JSON/BIN, returning bytes only if the ordinary humanoid importer accepts them.
Runs on a worker after explicit selection; source originals are unchanged.

<!-- module: scripts/GUI/avatar_browser.gd -->
## Avatar Browser UI

`submit_home_search` transfers bounded query to Search and resets cursor.
`select_category` installs visible type/category filters. `get_search_state`
returns a copy. Private groups own generation guards, source management, separate
previews, download/digest/license gates and import into the existing editor draft.
Apply stays explicit. No network request runs at ready; user search/category/feed,
preview or import actions initiate external requests. Close/account change cancels
work and removes secrets. Exact limitations are in the browser guide.

<!-- module: scripts/multiplayer/federation/relay_presets.gd -->
## Shipped internet relay discovery presets

`load_presets` validates a bounded versioned application JSON file and returns
copied relay/certificate definitions, or an empty array with last_error on failure.
The shipped list is intentionally empty. `apply_to` installs valid public certificate
seeds into the anonymous directory client without overwriting explicit device trust
or mutating the user's ordered ingress preferences. Presets are not global probing.

<!-- module: scripts/multiplayer/federation/secure_relay_link.gd -->
## Certificate-verified framed TLS link

`connect_to` requires an explicit trusted certificate/common name; `accept_connection`
uses an infrastructure key/certificate. `poll` bounds handshake time, incoming frame
size/work and outgoing queues. `connected`, `send`, `drain` expose framed dictionary
messages; `close` clears stream/queues. No unsafe TLS fallback or account storage.

<!-- module: scripts/multiplayer/federation/relay_directory_service.gd -->
## Live relay directory and datagram routing

`start` binds TLS infrastructure, `trust_peer` registers explicit public key/certificate
trust, `connect_peer` initiates a verified neighbour link with retry/backoff.
`set_local_instances` validates public origin summaries; `set_blocked` purges dependent
state/routes, `poll` processes bounded TLS authentication/gossip/tunnels and expiry,
`public_instances` copies summaries, `stop` clears links/tunnels/live state.
`set_gameplay_port` configures the local UDP origin target. Private tunnel routing
preserves ENet account/admission at the origin; it is not game simulation or PKI audit.

<!-- module: scripts/multiplayer/federation/relay_directory_client.gd -->
## Anonymous simultaneous directory client

`add_trusted` registers an explicitly verified certificate/relay association; `query`
opens up to four TLS directory connections. `set_blocks` tears down blocked sources
and filters distant origins. `poll` checks correlated public responses and expiry;
`instances` deduplicates global keys; `stop` closes links. No account is published.

<!-- module: scripts/multiplayer/federation/relay_directory_trust.gd -->
## Local public certificate trust bundle

`load_trust` validates bounded stored entries and preserves corrupt/newer files.
`add_certificate` imports an explicit local PEM after user action; `remove` requires
explicit removal before key replacement. `apply_to` configures trusted directory
endpoints. Private save atomically replaces public trust configuration; no private
key or advertised certificate is automatically accepted.

<!-- module: scripts/multiplayer/federation/relay_game_tunnel.gd -->
`validate_route` checks bounded unique relay IDs, destination and local blocks
before accepting a ready path. Reusing `start` clears previous diagnostic state;
closing clears route/session buffers. This does not prove a malicious relay's
claimed path describes every physical network participant.
## Origin gameplay over verified TLS routes

`start` binds a local UDP endpoint and opens a trusted TLS connection to the ingress;
`poll` requests a scoped origin route, validates returned blocked paths and forwards
bounded ENet datagrams. `close` sends best-effort route cleanup and closes local
state. Existing origin account auth remains end-to-end. This reliable TCP tunnel
does not guarantee low-latency datagram behavior or per-actor ingress policy.

<!-- module: scripts/multiplayer/federation/relay_operator_config.gd -->
## Operator infrastructure configuration

`load_config` reads bounded versioned JSON, existing private key/certificate and
explicit peer public-key/certificate files; returns typed configuration or preserves
files with a diagnostic. It never generates/replaces keys, stores users, or restores
sessions. Only explicit operator startup uses this configuration path.

<!-- module: scripts/multiplayer/federation/lan_relay_transport.gd -->
## Local IPv4 discovery datagrams

`start` optionally binds multicast listener and sends bounded operator advertisements;
`poll` caps datagram work, validates source addresses through the candidate model
and expires hints. `stop` leaves groups/closes socket. Actual interface multicast
availability is OS-dependent; this is not DNS-SD, certificate trust or automatic login.

<!-- module: scripts/multiplayer/federation/relay_validation.gd -->
## Relay configuration guards

Pure `failure` returns a diagnostic; `identity` checks fingerprint syntax only,
not authenticity. `integer`, `text`, `host` and `keys` enforce bounded types and
fields; `endpoint` creates a canonical local endpoint block key. No DNS, sockets,
crypto trust decisions, account access or persistence occurs in these helpers.

<!-- module: scripts/multiplayer/federation/relay_preferences.gd -->
`update_entry` validates a replacement endpoint/label/identity for an existing stable
row ID, rejects duplicates and emits a preference change without reordering rows,
altering independent blocks or disconnecting current membership.
## Device-local ordered relay preferences

`configure` resets store/path; `load_preferences` validates bounded schema and
preserves corrupt files read-only. `snapshot` deep-copies entries and independent
blocks. `add_entry`, `move_entry`, `remove_entry` mutate order without deleting blocks.
`set_blocked`, `set_endpoint_blocked`, `is_blocked` maintain/query independent
identity/endpoint exclusions. `save_preferences` atomically replaces a valid store;
`migrate_legacy` initializes one old endpoint only when no list file exists.
Changes emit synchronously; identity pins do not themselves authenticate servers.

<!-- module: scripts/multiplayer/federation/relay_connection_manager.gd -->
## Pure relay selection state machine

`configure` resets bounded candidates/limits, keeping attempt serial monotonic.
`begin_selection`, `complete_attempt`, `retry` coalesce/advance ordered attempts;
`tick` advances expired attempts. `set_blocked` invalidates matching pending/current
and directory policy state; `open_directory` reserves bounded secondary policy links;
`snapshot` copies state. This module opens no actual transport sockets and is not
the live coordinator's ENet implementation.

<!-- module: scripts/multiplayer/federation/relay_route_policy.gd -->
## Relay route policy

`configure` copies user/operator blocks, epoch and hop cap. `set_user_blocked` and
`set_operator_blocked` advance policy epoch. `authorize` checks trusted verified
route inputs for matching epoch, identity syntax, origin/ingress endpoints, loops
and blocked hops. It does not cryptographically verify provenance or connect relays.

<!-- module: scripts/multiplayer/federation/federation_directory.gd -->
## Public federation directory state

`configure` resets bounded storage. `valid_summary` checks strict public fields;
`ingest` validates caller-authenticated origin/path and monotonic process sequence
before replacing scoped public summaries. `snapshot` copies them; `set_blocked`
purges origin/transit sightings, `withdraw_origin` removes a matching boot and
`expire` evicts TTL state. There is no network gossip or signature verifier here.

<!-- module: scripts/multiplayer/federation/lan_relay_discovery.gd -->
## LAN candidate validation

`configure` resets enabled/caps/blocks; `local_address` recognizes local-address
classes, not actual interface reachability. `observe` parses bounded source-matching
advertisements into unverified candidates. `verified_directory` accepts a trusted
identity verifier's summaries; `candidates` and `instances` copy state, `expire`
purges dependencies. No multicast socket, automatic login or server verification
is performed by this data-only module.

<!-- module: scripts/multiplayer/federation/federated_instance_state.gd -->
## Origin-scoped instance policy

`configure` resets origin/item state; `admit` accepts only fresh destination-bound
trusted verifier results and nonduplicate account actors. `apply_item` checks actor
generation/instance and exclusive lease epoch for grab/release. `disconnect_actor`
clears actor/sequence/holder references; `lose_origin` suspends and clears live actors;
`snapshot` copies state. It is not wired to a federated transport or proof verifier.

<!-- module: scripts/multiplayer/federation/relay_preferences_panel.gd -->
`edit_entry` loads a selected saved row into the effective endpoint edit form.
The panel now separates TLS import port/file picking from saved relay inputs and
provides connection status, Retry and Cancel; it does not auto-approve certificates.
## Relay preferences UI

`configure` binds the device-local store and builds ordered controls for adding,
making main, moving down, removing and blocking endpoints; independent block rows
allow unblock after removal. Private callbacks validate results and persist only
explicit user changes. Teardown disconnects store notification; no connection switch
is caused by reordering and no account key is sent from this panel.

<!-- module: relay_protocol/world_item_router.gd -->
## Ephemeral relay world item routing

`handle` negotiates capability, scopes requests to authenticated active membership
and pinned revision, rate-limits operations, arbitrates exclusive leases and forwards
bounded normalized held-object poses. `leave` clears sender sequences and holder
references and deletes empty-instance state. `disconnect_peer` also clears capability,
generation and rate state. Private send/broadcast paths skip disconnected transport.
No world loading, scripts, simulation or durable data exists on this router.

<!-- module: scripts/worlds/world_pickup_controller.gd -->
`activate_local` installs home-only items/actions. `cancel_local_input` releases local anchors. `reset_local_item` restores initial pose/motion. `activate_nearest` invokes bounded unobstructed reviewed actions with session/input gates; shared item acquisition still requires relay leases.

## Client world item adapter

`configure` binds trusted coordinator/loader. `activate` resolves validated pickup
entities and requests a live snapshot; `reset` restores collision/freeze settings
and clears world references. `request_grab` checks nearby local entity/grip/anchor;
`nearest_available` returns the nearest unheld unobstructed candidate for both
hover and grab, without changing ownership.
`grab_nearest` selects within a capped range. `release_grip` and `held_by_local` use
acknowledged leases. `receive` checks scope/sequence and state before changing items.
Private processing attaches local held props, publishes capped poses and interpolates
remote transforms. This is initial carrying, not swept collision/two-hand physics.

<!-- module: scripts/worlds/world_runtime.gd -->
`binding_value` reads saved/state bindings. `dispatch_ui` accepts only active-owned-menu actions and rejects reentrancy. `open_menu` renders validated pages; `close_menu` releases input. `respawn_local_player` validates local player/spawn; no remote movement authority.

## Restricted world event execution

`configure` resolves stable current-world entities through weak node references and
copies validated program bindings. `dispatch` runs bounded start/tick/use/grab/release
instruction lists, validates the whole command transaction and applies visibility
only to current Node3D targets. `stop_scripts` disables all callbacks immediately.
Private processing ticks at most 20 Hz; no networking/deterministic game consensus
is implied. No world-supplied script is attached to a node or executed as GDScript.

<!-- module: scripts/worlds/world_data.gd -->
## World data guards

Pure helpers: `failure` returns a diagnostic with no pending commands; `safe_path`
checks bounded ASCII package-relative paths. `bounded` recursively checks copied
data under depth/item budgets, `keys_only` rejects unknown fields and `integer`
checks finite integral ranges. These do not authorize engine objects or filesystem IO.

<!-- module: scripts/worlds/world_extension_registry.gd -->
## World extension requirements

`validate_requirements` checks bounded unique extension declarations, versioned
schemas, package paths and an application-supplied installed registry. Missing or
unknown integrations fail closed; metadata cannot request code download. It does
not install or run Terrain3D and does not certify any supplied registry implementation.

<!-- module: scripts/worlds/world_script_vm.gd -->
## Restricted world instruction VM

`run_event` interprets copied instruction data under capped fuel, heap accounting,
nesting and command limits. Only current-entity visibility commands are implemented;
repeat and allocation instructions exercise budgets. All failures discard pending
commands. It does not parse a text language, touch nodes or execute engine methods.

<!-- module: scripts/worlds/world_interaction.gd -->
## World item leases

`configure` resets one instance's member generations and bounded item definitions.
`apply` validates transport-authenticated sender, scope, sequence and lease epoch
before grab/release. `disconnect_member` clears only the matching generation and
its indirect holder state. `snapshot` returns detached copies. Reach, pose transport,
physics and player input wiring are not provided by this pure service.

<!-- module: scripts/worlds/world_state_replicator.gd -->
## World snapshot and event ordering

`configure` resets session/revision/member scope. `accept_snapshot` checks copied
bounded state, generations and strictly newer watermarks; `apply_event` handles
ordered current-holder release events without replay/gaps. `snapshot` returns a
deep copy. No network routing, donor corroboration or gameplay consensus is implied.

<!-- module: scripts/worlds/world_instance_policy.gd -->
## World instance role policy

`configure` initializes trusted ordered member/admin/policy-readiness input.
`authorize` permits only current-generation admin kick/ban; `disconnect_member`
removes references and selects the earliest remaining fallback. `can_admit` fails
closed on missing moderator policy, and `snapshot` copies current role state. This
service does not replace the existing relay's enforcement or persist ban policy.

<!-- module: scripts/worlds/world_text_parser.gd -->
## Non-executing world text parser

`parse_json` checks bounded JSON with duplicate-key rejection; `parse_resource`
parses a limited Godot text grammar into section/constructor data. Both return
diagnostics instead of constructing engine resources. Private cursor readers bound
depth/work; caller must still validate property semantics, types and references.

<!-- module: scripts/worlds/world_zip_reader.gd -->
## Bounded world ZIP reader

`read_archive` reads capped ZIP32 bytes, validates central/local paths/layout and
size budgets, rejects duplicates/symlinks/encryption and returns checked decoded
file buffers with archive SHA-256. Private checksum code verifies decoded bytes;
no extraction, mount or resource execution occurs. Only stored/deflate are supported.

<!-- module: scripts/worlds/world_deflate.gd -->
## Bounded raw deflate

`decode` implements stored/fixed/dynamic RFC1951 blocks under output, input and work
limits, returning bytes or a diagnostic. Private Huffman/bit readers never call an
engine decompressor, so malformed streams remain data failures instead of logged
Godot errors. This portable implementation still needs large-content profiling.

<!-- module: scripts/worlds/world_package_reader.gd -->
## Safe world package inspection

`inspect_package` validates metadata/API, file types, reviewed native scene/resource
sections, typed property schemas, texture headers/checksums and resource references.
Returns normalized document and archive hash, or a diagnostic; `last_error` describes
local validation failures. No downloaded script or ResourceLoader call occurs.
Initial profile is deliberately narrower than the roadmap's final feature set.

<!-- module: scripts/worlds/world_builder.gd -->
## Safe world construction

`build_package` inspects an archive then reconstructs only explicit built-in node,
primitive mesh/collider and material types, decodes bounded PNGs and packs a newly
owned scene. It returns scene/spawn/revision/document or a diagnostic. Private caches
avoid duplicate resources; no package class/method execution or scene loading occurs.
Native image decode remains inside the client and is not OS sandboxed.

This reference explains every named public function in production `scripts/` and
`relay_protocol/`. Exact parameter types, defaults, return annotations and source
locations are in the [declaration inventory](symbols.json). A module heading links
the authoritative implementation. Private functions and engine callbacks are
indexed there and grouped by lifecycle/algorithm below; they are not an invitation
to bypass public validation or ownership checks. Signals are synchronous Godot
notifications unless their caller explicitly defers them.

**Calling convention:** Node/UI/transport APIs run on the main thread in an active
SceneTree unless explicitly described as pure or worker-only. RefCounted crypto,
validation and parsing helpers need no tree. “Await” means callers must await
completion before using the result; never attach the same returned model twice.
Methods with no explicit return annotation may still return a useful value—use
the contract and code, not an inferred `void`. Failure sentinels do not guarantee
`last_error` is populated on every branch. Function contracts describe current
code, including its limits, rather than promises from old roadmaps.

## Startup and settings

<!-- module: scripts/startup/main.gd -->
### [Startup main](../../scripts/startup/main.gd)

Owner: startup scene. `_ready` selects dedicated relay or account/authentication
client flow. Failure does not regenerate a corrupt account. Player survives world
scene changes under root; do not automate this flow against real user storage.
On startup re-entry an existing `player` group member is reused without reloading
the account or restarting relay selection. `_initialize_xr` handles desktop opt-out,
OpenXR initialization and viewport/vsync setup; isolated tests override only this
private hardware boundary, not production scene selection.

| Functions | Contract |
| --- | --- |
| `load_initial_scene` | Reuses or creates the local player then requests built-in world scene change; deferred startup caller owns order. Not a multiplayer admission shortcut. |
| `instantiate_player` | Loads the supplied scene and stores an instantiated player; trusted internal scene path required. Does not attach it itself. |
| `load_player` | Reuses an existing player group member; otherwise attempts XR unless forced desktop, configures viewport/vsync, selects supported player scene and defers root attachment. Requires engine XR services/display; no headless hardware guarantee. |

<!-- module: scripts/settings/save_data.gd -->
`use_temporary_identity` switches at most once per process to a generated memory-only
key/profile/contact owner after explicit duplicate-account rejection. It never saves
the private key or changes key_path, never imports original contacts/permissions,
and returns false on repeated rotation. Profile editing remains new-key-owned.
### [SaveData](../../scripts/settings/save_data.gd)

Owner: autoload. `_init` creates registry/store/voice/profile services; `_ready`
loads settings before capture, except relay mode. Setting application updates
legacy values/audio buses. Close/predelete saves dirty settings and frees detached
owned nodes. Profile-change adapter mirrors only the local account's public fields.

| Functions | Contract |
| --- | --- |
| `create_acount` | Generates RSA private key and writes configured key path; bool success/account_error. Call only when creating a genuinely new account, not on corrupt-key recovery. |
| `load_acount` | Reads existing private key or creates only if absent; initializes profile on success, returns bool. Corrupt/public-only key fails without replacing it. |
| `initialize_profile` | Configures owner-keyed profile/contact stores, migrates initial profile if absent, connects avatar config when attached, emits account_ready. Optional path is for isolated adapters; filesystem writes are client-owned. |
| `save_data` | Compatibility wrapper saves mirrored profile fields through ownership service then settings; false if either fails. Do not use to edit another account. |
| `laod_data` | Loads/migrates typed settings and legacy profile/world sources; returns store outcome and preserves compatibility spelling. Does not establish account-key ownership. |

<!-- module: scripts/settings/settings_registry.gd -->
### [SettingsRegistry](../../scripts/settings/settings_registry.gd)

RefCounted definitions owner. Validation is pure; mutations emit definitions_changed.

| Functions | Contract |
| --- | --- |
| `register_setting` | Validates definition, range/default and unique ID; deep-copies on success and emits change; bool false leaves registry unchanged. |
| `unregister_setting` | Removes an existing ID and emits change only if removed; dependent store/UI reconcile via subscriptions. |
| `get_definitions` | Returns deep-copied definitions sorted by category/order; caller changes are not registry mutations. |
| `get_definition` | Returns copied definition or empty dictionary for unknown ID. |
| `validate` | Tests a value against boolean/number/text/enum/key rules; no writes; invalid/unknown types fail. URL syntax validation is not trust validation. |
| `register_defaults` | Registers production defaults through normal validation; do not call repeatedly expecting duplicate replacement. |

<!-- module: scripts/settings/settings_store.gd -->
### [SettingsStore](../../scripts/settings/settings_store.gd)

Node owned by SaveData. Private reconciliation follows registry changes. `_process`
debounces dirty saves by 400 ms; failed write does not retry every frame. Exit
saves when allowed; predelete disconnects registry. See [format](storage-formats.md).

| Functions | Contract |
| --- | --- |
| `configure` | Switches registry/path, disconnects old definitions subscription, resets values to registered defaults. Does not load disk. |
| `get_value` | Returns stored value or null for missing ID; caller validates registry presence. |
| `set_value` | Rejects unknown/invalid input; unchanged value succeeds without duplicate signal. Valid change marks dirty, schedules save, emits setting_changed; not immediate durability. |
| `reset_value`, `reset_category` | Restore registered defaults through set_value, including its validation/debounce/signals. Unknown ID/category is harmless. |
| `load_settings` | Reads versioned ConfigFile; invalid individual values fall back to defaults. Corrupt/future store blocks writes and reports persistence_error. bool outcome; no automatic destructive reset. |
| `save_settings` | Writes registered persistent values via temp/rename, preserving unrelated sections. Refuses blocked/corrupt originals; emits saved on success, persistence_error on failure. |

## Voice and player nodes

<!-- module: scripts/player/vr_safety.gd -->
### [VRSafety](../../scripts/player/vr_safety.gd)

RefCounted physics policy requiring attached body/world. `clearance` tests bounded
capsule at a floor destination excluding self; `resize_capsule` permits shrink but
rejects ceiling-obstructed growth. `head_obstructed` queries a small head sphere
for protective overlay. `destination` validates finite short ray, walkable normal,
height difference and capsule space. `commit_teleport` moves body/origin around
head floor pivot and clears velocity, never rewriting local tracked pose. Caller
must revalidate clearance immediately before commit and cancel on focus/UI loss.

<!-- module: scripts/player/vr_room_scale.gd -->
### [VRRoomScale](../../scripts/player/vr_room_scale.gd)

RefCounted physical walking reconciliation. `reconcile` takes attached body/origin/
head nodes, collision-moves capsule toward horizontal headset displacement (bounded
to .5 m per call), restores origin world transform so physical head pose stays
unchanged, and returns actual body displacement. Repeated stationary input is
idempotent. Collision cannot stop real-world walking; callers still need boundary/
head-clipping feedback and ceiling-safe capsule policy. No camera recenter/teleport.

<!-- module: scripts/player/vr_locomotion.gd -->
### [VRLocomotion](../../scripts/player/vr_locomotion.gd)

RefCounted planar movement policy, no scene/network/storage writes. `desired_velocity`
accepts unitless stick/head basis/speed/dead zone and returns bounded horizontal
velocity. Retains last valid projected yaw for near-vertical gaze; rejects nonfinite
input and applies speed once. Caller owns gravity, collision and focus suppression.

<!-- module: scripts/player/vr_turn_controller.gd -->
### [VRTurnController](../../scripts/player/vr_turn_controller.gd)

RefCounted turn state. `step` returns delta yaw for snap/smooth mode; snap requires
neutral rearm and smooth integrates delta once. `reset` clears snap latch;
`pivot_transform` rotates rig about world floor pivot without moving that pivot.
Caller blocks input/menu/focus and preserves headset-local tracking.

<!-- module: scripts/player/vr_input_router.gd -->
### [VRInputRouter](../../scripts/player/vr_input_router.gd)

RefCounted edge ownership. `menu_toggle` coalesces either/both lower face buttons
and suppression into one rising intent; suppressed held presses remain latched
until release. `reset` clears history on explicit lifecycle reset. No hardware,
UI construction, persistence or networking; caller maps current OpenXR actions.

<!-- module: scripts/player/vr_comfort.gd -->
### [VRComfort](../../scripts/player/vr_comfort.gd)

RefCounted bounded vignette policy. `update_vignette` fades strength from movement/
turn rate and delta when enabled; disabled returns clear immediately. `reset`
clears overlay state on lifecycle transitions. The VR player renders its shader;
this policy never alters camera pose or guarantees motion-sickness prevention.

<!-- module: scripts/GUI/vr_pointer_router.gd -->
### [VRPointerRouter](../../scripts/GUI/vr_pointer_router.gd)

RefCounted capture queue. `hover` updates per-hand valid pixel hit. `press` emits
one owned down only for valid unowned target; `release` emits up even after drag-off.
`cancel` emits outstanding release once and clears hits; `drain_events` transfers
pending event dictionaries to caller. Player injects them into the shared viewport;
this helper does not synthesize gameplay or touch global capture/settings.

<!-- module: scripts/player/voice_controller.gd -->
### [VoiceController](../../scripts/player/voice_controller.gd)

SaveData-owned shared input/mute authority. `_input` suppresses shortcuts during
typing/modal/rebinding/IME. Relay mode disables input processing. No independent
UI/player mute flag should replace this service.

| Functions | Contract |
| --- | --- |
| `configure` | Binds store signals, applies saved mute and input bindings; disconnects previous store. Requires valid typed settings. |
| `is_muted` | Reads store or fallback; pure state query. |
| `set_muted`, `toggle_muted` | Updates persistent setting or fallback; capture receives mute and emits mute_changed. Muting clears capture backlog through its owner. |
| `register_capture` | Claims one active capture and immediately applies mute; false if a different live capture already owns it. |
| `unregister_capture` | Releases only matching capture and reports unavailable; does not unregister another node. |
| `set_availability` | Updates availability text and emits notification; not proof that audio packets are flowing. |
| `binding_text` | Returns current microphone InputMap label or Unbound; display only. |
| `handle_toggle_input` | Handles initial bound key press only when not suppressed; returns whether consumed and toggles shared mute. Caller marks viewport handled. |

<!-- module: scripts/player/audio_microphone.gd -->
### [Audio capture](../../scripts/player/audio_microphone.gd)

Player-owned capture Node. Ready registers with shared voice owner, builds capture
only when usable/unmuted; process handles threshold/gain/packet bounds and session
guards. Exit releases only its own effect/stream and registration. Physical device
availability is outside headless packet tests.

| Functions | Contract |
| --- | --- |
| `is_muted` | Queries shared voice mute when available, otherwise safe local fallback. |
| `set_muted` | Applies capture state, clears queued samples on mute and starts only eligible capture on unmute; never replays old samples. Called by voice owner. |

<!-- module: scripts/player/player_desktop_movment.gd -->
`set_avatar_size` applies a finite 0.25–3 multiplier to model, capsule geometry,
camera rest anchor and walking speed, leaving the CharacterBody transform unscaled.
Selection is session/process-local, not a signed profile edit.
### [Desktop player](../../scripts/player/player_desktop_movment.gd)

Root-owned CharacterBody; ready subscribes profile/config and loads avatar.
Physics handles input/collision; process sends position and interpolates camera
translation between the last two physics positions without smoothing mouse look.
This is not motion blur or global/XR interpolation. Mouse input owns camera
pitch/yaw; animation never parents camera to a bone. Generation checks reject
stale loads. Camera forward clearance and rest-eye calibration are local only.

| Functions | Contract |
| --- | --- |
| `update_player_data` | Sends current transform only with connected acknowledged session and no transition; does not grant membership. |
| `set_player_pos` | Sets local body position, clears velocity and resets camera interpolation history, used after world activation; caller provides valid spawn. |
| `load_player_model` | Awaited profile/config model acquisition; skips unchanged key, protects latest generation and swaps only successful result. Attaches local first-person view, calibrates camera from rest geometry. |
| `get_walk_speed` | Returns the shared registry-backed `vr.move_speed` for desktop walking and automatic walk/run classification, identical to VR's unboosted reference. Physics applies the shared held-sprint multiplier to horizontal target speed only; focus/UI/rebind/session suppression requires release before sprint can resume. |

<!-- module: scripts/player/player_vr.gd -->
`set_avatar_size` scales the avatar, XR origin and collision geometry consistently
with walking speed; tracked poses remain runtime-owned. Capsule height updates
retain the multiplier. Real-headset comfort still requires manual verification.
### [VR player](../../scripts/player/player_vr.gd)

Root-owned CharacterBody; XR origin/camera/controllers remain player-owned. Input
opens hand-local wheel and suppresses conflicting movement. Model load binds final
head/arm modifier; no networked live-tracker protocol is implied. Invalid/stale
model does not replace working avatar. Hardware checks are manual.

| Functions | Contract |
| --- | --- |
| `set_player_pos` | Moves body to spawn and clears velocity. Does not overwrite headset tracking pose. |
| `update_player_data` | Sends eligible session body transform, not head/controller poses. |
| `load_vrm_model` | Awaited config/profile import, generation/skeleton checks, model swap/first-person setup and local tracking configuration; camera remains under XROrigin. |
| `get_bone_by_array` | Returns first existing candidate name or empty string; helper for legacy naming, not a substitute for validated humanoid metadata. |
| `get_walk_speed` | Returns the current registry-backed VR walking speed, without sprint boost. Left primary click boosts smooth locomotion only; existing neutral rearm plus sprint release protects recovery. Teleport and physical room-scale motion are not boosted. |

<!-- module: scripts/player/air_control.gd -->
### [Air control](../../scripts/player/air_control.gd)

Shared by desktop and VR smooth locomotion; no persistence or network state.

| Functions | Contract |
| --- | --- |
| `steer` | Moves horizontal velocity toward nonzero input targets at 10% of ground acceleration, bounded by vector distance. Zero input preserves takeoff momentum; vertical velocity is unchanged. Blocked-input braking bypasses this helper. |

<!-- module: scripts/player/sprint_policy.gd -->
### [Sprint policy](../../scripts/player/sprint_policy.gd)

One instance per local player; no persistent or network-owned state.

| Functions | Contract |
| --- | --- |
| `suppress` | Requires a subsequent unblocked release before another held sprint can boost speed. Called immediately on focus loss, including between physics frames. |
| `target_speed` | Returns finite nonnegative walking speed times 1.5 only for an eligible held press. Blocked input arms the release requirement; unblocked release clears it. Never compounds speed or changes vertical motion. |

<!-- module: scripts/player/remote_player.gd -->
### [Remote player](../../scripts/player/remote_player.gd)

Instance-scoped CharacterBody with spatial voice playback. Ready loads fallback;
setting callbacks update nameplate visibility. Exit invalidates pending avatar and
disconnects store signal. Audio helper feeds only its generator, not microphone.

| Functions | Contract |
| --- | --- |
| `load_player_model` | Await URL model, keep old avatar on failure, discard stale/detached completion, attach independent tree and update label. Never reuse a live model node across peers. |
| `set_avatar_hidden` | Sets this remote node's local avatar visibility only, leaving root/nameplate/voice untouched. |
| `attach_avatar` | Applies current hidden state before tree attachment, retires previous model and sets the compatible avatar reference. Used by URL and transferred-model paths. |
| `begin_avatar_loading` | Enables bundled local stand-in and downloading status, hiding the previous model. A local block takes precedence. |
| `avatar_load_failed` | Keeps stand-in with unavailable status on reported import failure; does not reveal an old model. |
| `receive_motion` | Queues finite instance-local transforms in remote motion history; first pose applies immediately, subsequent poses render through interpolation in `_process`. |

<!-- module: scripts/player/remote_motion.gd -->
### [Remote motion](../../scripts/player/remote_motion.gd)

Per-remote-node memory-only history; no persistent identity data. Existing movement
packet layout is unchanged. PlayerData uses sequenced unreliable ENet delivery.

| Functions | Contract |
| --- | --- |
| `push` | Accepts finite position/Euler rotation and monotonic arrival seconds. Rejects older arrivals; bounds history to 32 samples and resets on jumps over 8 m. |
| `sample` | Returns interpolated transform 100 ms behind arrivals with shortest-arc rotation; extrapolates position for at most 100 ms, then holds. First pose/teleport applies immediately. Empty history returns identity. |

<!-- module: scripts/assets/avatar_placeholder.gd -->
### [Avatar placeholder](../../scripts/assets/avatar_placeholder.gd)

Bundled CC0 Quaternius RobotExpressive humanoid; no runtime asset fetch.
Instance-owned materials prevent cross-player appearance mutation.

| Functions | Contract |
| --- | --- |
| `set_state` | Selects amber/X for blocked, red/! for unavailable, or blue/animated dots for loading; does not affect player/network policy. |

<!-- module: scripts/assets/avatar_visibility.gd -->
### [Avatar visibility](../../scripts/assets/avatar_visibility.gd)

Client-owned RefCounted; never serialized or transmitted. Coordinator validates
current membership and resolves fingerprints to remote nodes before applying.

| Functions | Contract |
| --- | --- |
| `set_scope` | Clears preferences when acknowledged session/account scope changes; unchanged scope preserves reconnect choices. |
| `is_hidden` | Queries the identity-keyed local hidden set, not asset URLs/hashes. |
| `set_hidden` | Requires matching nonempty session and non-self identity; changes local policy and emits changed. Coordinator rejects stale/departed targets before calling. |

## Assets, rendering and emotes

<!-- module: scripts/assets/foot_grounding.gd -->
### [FootGrounding](../../scripts/assets/foot_grounding.gd)

RefCounted local terrain contact policy. `resolve` requires a physics-phase direct
space state and world-space target, tests a short vertical ray against caller mask/
exclusions, rejects steep/missing/raised-foot contacts, aligns to surface and holds
small jitter in collider-local space. Lifts or movement release contact; `clear`
drops references on avatar/session teardown. Does not move camera/body or prove
universal gait quality; target stabilization and physical boundary safety differ.

<!-- module: scripts/startup/data_loader.gd -->
`prepare_world_async` awaits worker safe-package parsing and returns staged scene data without activation or admission; scene attachment stays main-thread/coordinator-owned.

### [DataLoader](../../scripts/startup/data_loader.gd)

Stable autoload. Camera-added callback excludes local derivative layer for other
cameras. Avatar/animation workers are serialized, bounded and joined without
blocking frame progress; shutdown alone may join remaining work. Worker functions
must not access active SceneTree or globally register request-local extensions.

| Functions | Contract |
| --- | --- |
| `get_avatar_configuration` | Lazily creates child config and reconfigures for current fingerprint; returns owned service, not caller-owned node. May initiate async restore. |
| `get_asset_cache` | Lazily creates stable cache, connects settings/revision notifications; returns service, not an asset handle. Relay initialization still refuses persistence. |
| `get_world_pickups` | Lazily creates stable client pickup adapter under DataLoader, bound to the coordinator. World activation configures validated pickup entities; server startup must not call this factory. |
| `load_vrm_from_url` | Await validated cache fetch and detached import; returns model/null. Success carries lease/revision/source metadata; caller attaches/frees on main thread. Force bypasses HTTP validators. |
| `read_animation` | Await bounded worker parsing of file or byte buffer (empty path selects bytes); returns parsed dictionary or `{}`, sets animation_import_error. |
| `refresh_loaded_assets` | Await forced checks for live avatar sources, active world and configured sources; source notifications can rebind, world refresh does not hot-swap scene. |
| `load_world_from_url` | Convenience await prepare then activate; bool. Multiplayer code must use coordinator admission rather than bypass it through this wrapper. |
| `prepare_world_from_url` | Await built-in or validated safe remote exact revision preparation; returns staged scene/spawn/handles or `{}`. Refuses revision/schema mismatch; pins bytes. Does not activate or host. |
| `built_in_world_revision` | Returns hash of built-in scene file; not its complete transitive dependency graph. |
| `load_world` | Local safe archive convenience prepare/activate; bool; trusted caller controls path. No filesystem extraction occurs. |
| `prepare_world` | Bounded data parsing and reviewed scene reconstruction; returns staging dictionary or `{}`. Legacy extract-path argument remains unused for compatibility. |
| `activate_world` | Await application-owned scene transition, retain active handles, attach restricted visual runtime and move player group to spawn; bool failure on invalid scene/change. Use after acknowledged transition. |
| `stop_world_scripts` | Immediately disables current runtime callbacks if one exists; also invoked by the world script setting. Re-enabling requires a fresh world activation. |
| `extract_zip` | Extracts relative safe entries with count/total-byte ceilings; bool false on unsafe path/read/write failure. Partial managed extraction may need caller cleanup. |
| `load_manifest` | Parses file JSON object or `{}` with diagnostic; not independently full world validation. |
| `create_directories_recursive` | Creates missing parent path; internal trusted path only, not a permission boundary. |

Private groups: source refresh and validators await importer/cache; `_import_avatar`
owns waiters/thread; `_build_avatar` constructs detached tree, humanoid mappings
and first-person derivatives; world extraction validators own staging cleanup.
TemporaryWorld destructor releases only its managed transient extraction.

<!-- module: scripts/assets/asset_cache.gd -->
### [AssetCache](../../scripts/assets/asset_cache.gd)

Client-only Node; index schema 1. Main-thread callers may await fetch/import.
Private fetch pipeline coalesces jobs, checks validators/cache policy, promotes
immutable bytes then index; failure preserves old verified revision with backoff.
Managed cleanup never follows symlinks or deletes external source originals.

| Functions | Contract |
| --- | --- |
| `initialize` | Sets root once, creates managed dirs, validates index, cleans managed staging; bool. Relay mode disabled; corrupt/future index becomes read-only, preserved. |
| `valid_hash` | Pure lowercase 64-hex validation, false otherwise. |
| `blob_path`, `world_path` | Derive managed revision path or empty for invalid hash; do not validate file existence. |
| `revision_handle` | Verifies cached hash and returns path/hash/lease/stale or `{}`; caller must retain lease. |
| `pin_revision` | Persistently pins matching records; bool false if unavailable/unwritable/save failure. |
| `remove_revision` | Rejects active leases/jobs, removes matching records and unreferenced managed bytes/derivatives, saves index; bool. Never deletes external originals. |
| `retain`, `release` | Increment revision lease count / decrement one count; retain returns RefCounted lease whose destructor releases automatically. Do not manually double-release a lease. |
| `fetch` | Await permitted URL/kind/validator, bounded/coalesced request; returns handle or `{}`. Handle may be stale or temporary/no-store. Validation must establish format safety before publication. |
| `import_file` | Await copy/validator/hash promotion; returns managed handle or `{}`. Pin defaults true, receiver cache can opt out; permissions are not inferred from successful import. |
| `usage_bytes` | Measures managed bytes including derived/staging; no mutation. |
| `clear_unused` | Removes unpinned/unleased records and orphan blobs when no jobs; saves index and emits status. bool false on unsafe/unwritable state. |

Private groups: `_usable` checks bytes/size; `_make_room` performs protected LRU;
`_save` temp-renames index; `_fallback` records bounded retry; `_headers` normalizes
HTTP fields; `_allowed_url` syntax is not DNS destination-policy sandboxing. Lease
and TemporaryFile destructors are indexed in the declaration inventory.

<!-- module: scripts/assets/avatar_configuration.gd -->
`active_avatar` returns active cache key/name/public URL or fallback descriptor; cached private models never inherit an outdated profile URL. It does not mutate signed profiles or bypass Apply ownership.

### [AvatarConfiguration](../../scripts/assets/avatar_configuration.gd)

Client account-owned Node. Applied JSON is separate from signed public profile.
Private restore rebuilds role catalog from managed bytes with generation guards;
source-update queue serializes revision replacements. Corrupt config blocks writes.

| Functions | Contract |
| --- | --- |
| `configure` | Switches account/path/loader, clears drafts/catalog, loads matching schema then starts restore; emits changed. No caller ownership of the returned child services. |
| `role_for` | Pure normalized canonical movement-name matching; returns role or empty for emote/nonrole. |
| `import_source` | Await kind-specific file/URL validation and managed handle; returns source descriptor or `{}`. Does not equip; no-store cannot persist, account changes invalidate completion. |
| `apply` | Await full candidate source/model checks, ownership-generation guard, temp/rename save and catalog restore; bool. Custom models require redistribution permission. Failed candidate keeps old applied selection. |
| `model_key` | Returns cache revision key or fallback URL for load deduplication; no I/O. |
| `load_model` | Await cached configured import or fallback URL; returns detached model/null with lease. Missing configured bytes reports error and attempts fallback. |

<!-- module: scripts/assets/humanoid_animation.gd -->
### [HumanoidAnimation](../../scripts/assets/humanoid_animation.gd)

RefCounted data parser; worker-safe when isolated. No scene/script/callback resource
loading. Private accessors enforce finite values/count/stride/bounds; rest hierarchy
conversion rejects cycles/matrices. See supported subset, not full VRMA claims.

| Functions | Contract |
| --- | --- |
| `read_file` | Reads bounded self-contained GLB/VRMA bytes and returns canonical clip set or `{}`/last_error; no active tree needed. |
| `document` | Validates binary GLB chunks/JSON and rejects external buffer/image URIs; returns json/binary or `{}`. Caller supplies maximum bytes. |
| `humanoid_nodes` | Extracts VRM Animation/VRM 1.0/legacy humanoid node map; missing mappings return empty. Not arbitrary bone-name guessing. |
| `read_bytes` | Parses supported rotation channels to named clips/time/quaternion/rest-basis data with SHA-256; rejects unsupported interpolation/translation/gaze/sparse tracks. No animations are executed. |
| `bind_clip` | Main-thread avatar binding to a Skeleton3D using humanoid metadata/rest-axis conversion; returns Animation/null. Rejects required missing bones, skips explicit optional channels; legacy VRM orientation correction applies to builtin data. |

<!-- module: scripts/assets/default_animations.gd -->
## Bundled motion data

`clip` lazily decodes authored Quaternius rotation samples, source-rest quaternions and provenance and returns a named clip or empty. Consumers copy before masking shared data. No root movement or arbitrary downloaded animation code is executed.

### [DefaultAnimations](../../scripts/assets/default_animations.gd)

Bundled library data is shared lazily; callers must copy before adaptation. Asset
provenance is recorded separately in THIRD_PARTY_ASSETS.md and the source manifest.

<!-- module: scripts/assets/avatar_dimensions.gd -->
### [Avatar dimensions](../../scripts/assets/avatar_dimensions.gd)

`eye_position` returns a rest-space camera anchor in the model parent's coordinates:
averaged mapped eyes, mapped/legacy head, then 92% of finite transformed mesh bounds,
or a 1.6 m default. Nested rig transforms and model scale are included; animated
bone poses never drive the camera. First-person derivative meshes are excluded.

| Functions | Contract |
| --- | --- |
| `clip` | Loads/caches authored bundled JSON and returns canonical clip dictionary or `{}`. Treat returned shared data as read-only; duplicate before masking/composition. Static standing combines reference legs with relaxed authored upper body; library version is wire compatibility, not app version. |

<!-- module: scripts/assets/avatar_animator.gd -->
### [AvatarAnimator](../../scripts/assets/avatar_animator.gd)

Avatar-owned Node. Private mixer-applied pass smoothsteps captured visible owned
bone rotations into evaluated target over .22 s; interrupted transitions recapture
the visible pose. Unused previously owned channels return to rest, not camera/IK
authority. Shared local/remote renderer; it is not a separate network player.

| Functions | Contract |
| --- | --- |
| `attach` | Creates dedicated AnimationPlayer/root/reset library on supplied model; call once per animator. Caller attaches animator/model on main thread. |
| `play_clip` | Binds validated clip, preserves visible pose for transition, installs bounded current/reset libraries, seeks requested phase and starts; bool with last_error on binding failure. Uses 0.55 s for tagged jump→neutral standing transitions, otherwise 0.22 s. The controller tags local/remote resolved roles without mutating cached source clips. Does not move camera/body. |
| `stop` | Clears fade, applies owned RESET, stops and clears descriptor; immediate lifecycle reset, not an emote network command. |
| `set_paused` | Internal renderer pause/resume primitive; not exposed as manual protocol/UI control. Requires attached player. |
| `synchronize` | Corrects phase using playback-speed adjustment bounded to ±10%, with shortest cyclic error for loops. Seeks only for errors above 0.5 s. No-op for stopped/unattached players. |

<!-- module: scripts/assets/animation_controller.gd -->
`locomotion_rate` derives quantized bounded cadence from actual horizontal velocity and avatar stride scale. `locomotion_head_mask` excludes animated gaze/head channels so player-owned tracking/look remains final. Phase-preserving cadence uses the existing resolved animation stream.

### [AnimationController](../../scripts/assets/animation_controller.gd)

DataLoader-hosted service created/recovered by production coordinator factory.
Process owns local state evaluation, transport replacement, clock/snapshot ticks,
transfer fairness limits and expiry. Generation/session/sequence/revision checks
reject stale remote work; clear on membership transitions. Remote live tracker
poses are not included in this protocol.

| Functions | Contract |
| --- | --- |
| `configure` | Binds network/loader and applied avatar config; requires main-tree collaborators. No ownership transfer. |
| `toggle_local_mirror` | Shows or hides the client-only mirror (creating it in front of the camera) and returns visibility. |
| `is_local_mirror_visible` | True when the local mirror exists and is shown. |
| `now` | Returns local monotonic milliseconds plus estimated relay offset; not wall-clock time. |
| `resolve_motion` | Chooses static neutral, forward/back walk/run, left/right strafe or upward jump from actual grounded/local-space velocity; no fall/landing playback. Uses unboosted player walking speed as reference, entering run above 1.3× and leaving at 1.1× (stateful hysteresis). Sprint intent alone cannot trigger run at rest; strafe retains precedence. |
| `tracking_mask` | Returns copied clip excluding tracked head/eye/jaw/hand channels, preserving untracked limbs/torso. Does not itself perform IK. |
| `strafe_pose` | Returns copied lateral legs combined with exact unrotated forward-walk upper-body motion; no procedural replacement keys. |
| `emote_catalog` | Returns applied compatible action entries plus cancel intent when configured; builtin fallback otherwise. Catalog browsing does not send packets. |
| `request_emote` | Validates action/permission, applies through sole renderer/resolved state; bool and last_error. Movement/replacement/completion interrupts via state machine. |
| `cancel_emote` | Clears intent and schedules automatic reevaluation; does not send legacy Stop. |
| `toggle_emote_menu` | Opens/closes shared desktop/XR picker; safely declines detached service. Factory must restore attachment. Owns overlay lifetime and mouse/focus restoration. |
| `open_xr_menu` | Opens stable hand-local wheel from valid tracked nodes; detached/invalid calls ignored. Hardware comfort is not proven by headless geometry. |
| `receive` | Dispatches authenticated transport data after own schema/scope checks; updates clock/current state or request-bound buffers. Tracking requires a 32-character generation. Departure clears tracking-only peers too, but cannot clear caches belonging to a newer generation. Never trust as public arbitrary actor-command interface. |
| `clear` | Drops session descriptors, queues/assets, motion intent, wheel and clock state; resets local renderer. Does not erase persistent library or user layout. |

Private tracking updates also remove peers that are no longer members without
requiring a departure packet. Expired poses, missing avatars and mismatched avatar
revisions invalidate head/hand and body targets rather than leaving old IK active.

Private groups: `_apply_resolved` composes masks/metadata; `_play_resolved` owns
local render state; `_apply_remote` loads exact model/clip then seeks/blends;
typed chunk handlers verify final bytes before importer; departure removes pairwise
references. Input handler suppresses repeat/typing/modal/IME and marks consumed keys.

<!-- module: scripts/assets/emote_layout.gd -->
### [EmoteLayout](../../scripts/assets/emote_layout.gd)

RefCounted account-local graph; no network calls. Limits: 32 groups, four levels
below root, 1,024 entries. Private traversal rejects cycles even in unreachable
components; corrupt load keeps original read-only with defaults.

| Functions | Contract |
| --- | --- |
| `defaults` | Returns fresh root/Dances and builtin/cancel shortcuts; no disk writes. |
| `configure` | Sets JSON path and loads/validates or uses defaults; bad original preserved. |
| `valid` | Pure full graph/type/depth/bounds validation; false on dangling/cyclic links. |
| `commit` | Validates candidate, temp/renames if persistent, deep-copies on success; bool. Empty path supports memory-only fixtures. |
| `add_group` | Creates random stable ID and parent shortcut; returns ID or empty if validation/save fails. |
| `rename_group` | Updates title and incoming shortcut names atomically through commit; bool. |
| `delete_group` | Refuses root, removes target and incoming references; bool. Caller must confirm nonempty deletion; source files are untouched. |
| `add_emote` | Adds named stable action reference to group, validates/persists; bool. Compatibility is checked by picker/catalog, not just this string operation. |
| `move_entry` | Moves one entry across/within groups with clamped position and cycle revalidation; bool; no partial graph mutation. |
| `remove_entry` | Deletes shortcut at valid index and commits; bool; not source deletion. |
| `page_count` | Returns one for 0..8 entries, otherwise ceil(count/5); pure query. |
| `sectors` | Returns eight copied visible entries including fixed lower paging sectors when needed; indicator/empty disabled. Does not play or navigate itself. |

<!-- module: scripts/assets/first_person_avatar.gd -->
### [FirstPersonAvatar](../../scripts/assets/first_person_avatar.gd)

Pure import preparation plus main-thread camera activation; never shares a live
model across avatars. Local derivatives preserve torso, hips, arms and legs while
excluding neck/head/face geometry and head-bone descendants such as hair.
Original geometry stays intact for other cameras/shadows.

| Functions | Contract |
| --- | --- |
| `is_camera_interior_bone` | Pure role membership for neck/head/eyes/jaw filtering; hips/spine/chest and limbs stay visible. |
| `prepare` | Detached worker-safe derivative construction from annotations/skin weights; idempotent. Returns whether view was prepared/changed; missing humanoid rig can fail. Unknown geometry filtering is heuristic, not universal visual correctness. |
| `apply` | Marks local camera, activates cull/layer visibility on already prepared representation without revealing hidden source meshes; bool false if not prepared, leaving the camera unchanged. No runtime mesh cutting. |
| `configure_camera` | Excludes local derivative layer from added non-first-person cameras; callers intentionally selecting special layers must coordinate with this policy. |

Private BlendShapeSync process copies transform/material override/expression values
from original to derivative; activated derivatives follow source visibility even
while hidden. Inactive preview copies stay hidden. Original remains expression
target and shadow caster. Primitive meshes need no ArrayMesh blend-shape mode.
Per-surface material overrides are copied and synchronized through surviving
surface indices, including when head-only surfaces are removed. Clearing an
override restores the original mesh's base material rather than a baked override.
Instance transparency is copied and synchronized so local body fades match the
source instead of displaying an opaque first-person copy.
Material overlays are copied and synchronized, including their removal, so local
body effects remain consistent with the original avatar.
Preparation resolves skin-bind head membership once per mesh instance rather than
per vertex influence, and copies retained triangle indices without allocating a
temporary array per triangle. Named and numeric binds retain the same filtering.

<!-- module: scripts/assets/avatar_tracking.gd -->
Fully faded inactive chains return before bone lookup, pose allocation and bone
writes, preserving animation ownership. Solved history remains available for
smooth reacquisition; active tracking and partially faded chains still solve.
Fully weighted active chains retain the solver's final pose and record it for
fade-out without redundantly interpolating and writing that same pose again.
Validity and body-target setters reuse owned dictionaries when contents are
unchanged. Changed input is still copied (deeply for nested validity), preserving
isolation from later caller mutations and honoring explicit target clearing.

### [AvatarTracking](../../scripts/assets/avatar_tracking.gd)

| Functions | Contract |
| --- | --- |
| `configure` | Main-thread binds humanoid map and independent head/hand target nodes, caching rest calibration. Must be child of skeleton before use. No camera transform mutation. |
| `set_calibration` | Validates bounded finite local head/grip translation offsets; invalid entries ignored. Does not move headset/controllers. |
| `set_tracking_validity` | Sets role validity booleans or timestamped validity records; aged/invalid targets stop overriding base pose. |
| `tracking_weights` | Returns current per-chain blend weights as a copy. Temporary validity loss fades last solved pose toward animation over .2 s; reacquisition fades toward fresh target. Hard target removal releases ownership immediately. |
| `set_body_targets` | Supplies optional pelvis/feet Transform3D targets in skeleton space; final modifier solves valid subset before head/arms. |

SkeletonModifier `_process_modification` runs final head alignment and two-bone arm
reach solve for active targets only. Private rotations convert target world poses
to skeleton/parent space; unreachable targets clamp to limb reach. Untracked
channels retain animation. Physical controller orientation and proportions still
need calibration; not a full-body or remote tracker solution.

## Accounts and social services

<!-- module: scripts/assets/humanoid_rig_adapter.gd -->
### [HumanoidRigAdapter](../../scripts/assets/humanoid_rig_adapter.gd)

RefCounted validation helper. `validate_mapping` returns valid/errors for required
roles, duplicate assignments, ancestry, zero-length chains and nonfinite rest poses.
No skeleton mutation, storage or tracking discovery; report can contain partial
unsupported chains and does not prove anatomical/joint-limit quality.

<!-- module: scripts/assets/tracking_calibration.gd -->
### [TrackingCalibration](../../scripts/assets/tracking_calibration.gd)

RefCounted account/avatar-scoped persistence. `configure` binds path/owner/revision;
`load_calibration` returns validated schema/finite bounded height/scale/head/grip
offsets or empty and blocks corrupt/incompatible replacement. `save_calibration`
temp-renames valid candidate only when owner/store usable. No raw hardware IDs or
pose history. Scope checks are integrity isolation, not cryptographic signatures.
`capture_roles` calculates finite bounded position/quaternion mount offsets from
tracked and desired reference poses; `calibrated_targets` applies only available
calibrated roles, never inventing missing targets. User must match reference pose.

<!-- module: scripts/assets/tracker_role_provider.gd -->
### [TrackerRoleProvider](../../scripts/assets/tracker_role_provider.gd)

RefCounted transient sample adapter. `update_sample` accepts finite timestamped
validity/pose per ephemeral ID, ignores older samples. `assign` validates supported
role/existing valid device and prevents one device on two roles. `available` lists
fresh runtime sample IDs; `unassign` clears a role without deleting the sample.
`targets` returns
fresh assigned transforms within one second; `clear` drops samples/assignments.
This adapter does not discover hardware or claim every runtime exposes FBT.

<!-- module: scripts/assets/full_body_solver.gd -->
An empty target set clears planted-foot history and returns before bone lookups
or IK work. Reacquired feet start from fresh targets rather than stale plants.

### [FullBodySolver](../../scripts/assets/full_body_solver.gd)

RefCounted optional pelvis/feet target solver. `configure` binds skeleton/map;
`solve` accepts finite skeleton-space role transforms and positive delta, sets
bounded pelvis pose and solves reachable two-bone legs/foot orientation. Missing
roles leave base animation intact; no camera writes or tracker discovery.
`stable_foot_target` holds sub-centimeter stationary jitter and releases/smooths
deliberate movement; missing role clears plant. This is target stabilization, not
world-ground collision/foot-contact detection or complete joint-limit calibration.

<!-- module: scripts/profile/profile_identity.gd -->
### [ProfileIdentity](../../scripts/profile/profile_identity.gd)

Pure RefCounted helpers; no persistence/tree. Fixed serialization and canonical
keys are protocol contracts. Signature verification is not content-host trust.

| Functions | Contract |
| --- | --- |
| `digest` | SHA-256 bytes of supplied bytes; returns PackedByteArray. |
| `canonical_key` | Parses bounded PUBLIC KEY PEM and returns canonical public serialization or empty; rejects private/invalid text. |
| `fingerprint` | SHA-256 lowercase hex of canonical public key, empty if invalid. |
| `defaults` | Fresh four-field public profile defaults, not account identity. |
| `valid_url` | Bounded HTTP(S) syntax/control/credential checks, optional empty; no DNS/private-network sandbox. |
| `normalized` | Returns validated/trimmed four-field copy or `{}`; rejects missing/invalid fields. Does not sign or persist. |
| `signed_bytes` | Fixed ordered domain/version/public-key/revision/field array serialization; exact bytes are signed, independent of dictionary ordering. |
| `verify_profile` | Validates exact normalization, canonical key, bounded revision/signature and crypto; bool; no mutation or trust grant beyond signer identity. |

<!-- module: scripts/profile/identity_authenticator.gd -->
`verify_response` exposes a last_rejection code distinguishing a cryptographically
valid duplicate-account connection from invalid/expired/replayed proof. The one-live-
account rule is preserved; the relay returns actionable second-window guidance and
does not disconnect the already authenticated account.
### [IdentityAuthenticator](../../scripts/profile/identity_authenticator.gd)

Relay-owned RefCounted transient challenge/identity maps. No disk writes. Private
challenge consumption/expiry binds proof to peer and prevents replay.

| Functions | Contract |
| --- | --- |
| `issue_challenge` | Validates public key/current connection constraints, stores bounded expiring challenge; returns bytes or empty. Peer ID is transport-derived. |
| `verify_response` | Consumes/checks pending signature proof and duplicate account constraints; bool; failed/expired/replayed proof does not authenticate. |
| `get_identity` | Returns authenticated identity for peer or empty; internal caller must not manufacture verified keys. |
| `expire_challenges` | Removes timed-out challenges; caller ticks relay lifecycle. |
| `disconnect_peer` | Erases peer challenge and identity references, no reconnect history. |

<!-- module: scripts/profile/profile_service.gd -->
### [ProfileService](../../scripts/profile/profile_service.gd)

SaveData-owned RefCounted local signed profile plus transient remote map.
Private signing uses configured private key; public remote cache does not grant
edit rights. Persistence uses temporary ConfigFile/rename with owner/signature checks.

| Functions | Contract |
| --- | --- |
| `configure` | Sets key/path, initializes signed defaults and clears remote/revision maps; does not adopt disk until load_profile. |
| `get_local_fingerprint` | Returns local canonical owner fingerprint or empty. |
| `can_edit` | True only for nonempty matching owner and private key; instance role irrelevant. |
| `get_profile` | Deep copy of local/remote profile or `{}`; never private key. |
| `save_profile` | Validates complete fields/owner, increments/signs revision, refuses corrupt/unrelated original, writes then emits profile_changed; bool/last_error. |
| `load_profile` | Missing file succeeds with defaults; existing matching verified profile adopted, invalid original preserved; bool. |
| `cache_remote_profile` | Internal adapter for already session/signature-validated input; returns fingerprint or empty. Does not independently establish relay membership/signature. |
| `replace_remote_profiles` | Verifies signed array, rejects revision rollback, replaces rather than merges current-session map and emits notification. Caller enforces active session. |
| `clear_remote_profiles` | Drops remote and seen-revision maps, emits remote_profiles_changed; no local profile deletion. |

<!-- module: scripts/profile/profile_media.gd -->
### [ProfileMedia](../../scripts/profile/profile_media.gd)

UI-owned Node; bounded asynchronous image requests and generation guards. External
media reveals client address to host; caller must respect user/request consent.

| Functions | Contract |
| --- | --- |
| `request_icon` | Starts bounded source acquisition/decoding and emits icon_ready or failed; empty uses fallback. New requests supersede old generations. |
| `cancel` | Invalidates pending result/request; no profile mutation. |
| `texture_from_bytes` | Decodes supported bounded image bytes to texture/null; not arbitrary scene loading. |

<!-- module: scripts/profile/friend_service.gd -->
`friend_session` returns a copy of fresh relay-derived public-instance location for an accepted online/DND friend; offline, blocked/revoked/stale locations return empty. Location grants no admission rights and is not persisted as live state.

### [FriendService](../../scripts/profile/friend_service.gd)

SaveData-owned RefCounted client persistence. Private `_commit` validates/signs next
state before atomic file replacement; event state machine stores terminal records
and outbox only after durable commit. Presence/delivery are ephemeral. No relay
mailbox or cached profile editing authority.

| Functions | Contract |
| --- | --- |
| `notifications_allowed` | False for preferred DND; does not change microphone or transport. |
| `configure` | Disconnects old transport, sets account/path, initializes or verifies signed store; corrupt/wrong-owner original blocks writes. Emits changed. |
| `add_contact` | Canonical other public key/nickname/optional verified profile → signed local commit; bool. No friendship request implied. |
| `contacts` | Returns deep copy of saved contacts. |
| `relationship` | Selects current nonterminal relation and pending/accepting/friends status for fingerprint; copy or `{}`. |
| `is_friend` | Requires confirmed relation and no local block; not instance admission by itself. |
| `send_request` | Refuses missing/blocked/already-related contact; creates signed request and durable outbox through event commit; bool. |
| `act` | Accept/decline incoming, cancel outgoing or revoke pair using signed request-bound event; validates state before commit; bool. |
| `block` | Persists block, terminates active pair when blocking, removes live presence and refreshes; unblocking never restores old consent. |
| `remove_contact` | Requires no active relationship, removes saved contact via commit; bool; not a shortcut around revocation. |
| `set_status` | Persists Online/Offline/DND preference then refreshes live transport; bool. |
| `get_profile` | Copy of self or cached contact profile; missing cached profile builds display fallback, not signed editing authority. |
| `can_edit` | Always false: cached social profiles are read-only. |
| `label`, `relationship_label` | Display strings from nickname/profile or terminal consent status; never identity/action keys. |
| `status` | Privacy-authorized fresh presence label or unavailable; expires after 15 s, not durable online history. |
| `attach` | Replaces transport, generates connection generation, negotiates supported capability and refreshes; does not restore stale presence. |
| `disconnect_transport` | Clears transport/live presence/delivery/generation and emits changed; persisted contacts/outbox remain. |
| `refresh` | Sends bounded batches of pending/terminal events and current presence authorizations/subscriptions; guards reentrancy; no offline relay store. |
| `tick` | Periodic refresh and presence expiry; caller polls only active client. |
| `receive` | Routes receipt/event/presence/delivery after schema/generation/sequence/consent checks; durable acceptance precedes receipts. Untrusted actor input still requires signed event validation. |

Private event groups: `_apply` enforces relationship/request identity and outbox
supersession; `_terminate_pair` closes all active grants; `_receive_event` rejects
forgery/replay/blocked senders and persists before acknowledging. Canonical-number
serialization stabilizes signed JSON across parse/reload.

## Client and relay

<!-- module: scripts/multiplayer/client/participant_registry.gd -->
### [ParticipantRegistry](../../scripts/multiplayer/client/participant_registry.gd)

RefCounted appearance adapter. `apply_profile` accepts an already verified current
profile/node binding, updates label and applies changed avatar URL once per node/
fingerprint/source. Weak node records are reclaimed; `clear` resets on session
teardown. Caller enforces active session/signature; this helper is not authorization.

<!-- module: scripts/multiplayer/network_handler.gd -->
`load_local_map` awaits validated local safe-package preparation then reviewed transition/activation; reports failures without loading arbitrary native scripts/scenes or joining by world URL alone.

Explicit duplicate-account auth alone can invoke SaveData's one-time temporary
identity fallback and send a fresh AUTH_HELLO on the unauthenticated connection.
Temporary moderation uses an empty persistence path; other auth failures do not
rotate identity. Reconnects retain the process's temporary identity.
Remote joins targeting the already-authenticated current origin now reuse the
existing transport via ordinary acknowledged join, preventing duplicate-account
authentication races and duplicate membership. A retired/disconnected transport
is not force-disconnected again during route-loss recovery.
`connect_initial_relay` owns one background startup coroutine on the stable autoload
while the local player/menu loads immediately. `cancel_relay_connection` ends the
current selection/auth wait without creating duplicate players or restoring old
membership. Later Retry begins a fresh selection.
Preference notifications now compare independent identity/endpoint block sets:
ordinary add/reorder/remove does not close active federated gameplay. Newly added
restrictions still conservatively terminate the tunnel; missing per-actor ingress
provenance means this cannot yet be narrowed to every affected remote actor.
`get_relay_presets` returns copied application discovery seed definitions for the
Network panel. These are independent of saved main/fallback order and respect the
directory client's identity/endpoint blocks before opening network connections.
`revoke_relay_directory` removes persisted public certificate trust, closes directory
links and conservatively ends active tunneled gameplay before querying remaining
trusted directories. It does not silently approve replacement certificates.
`get_directory_browser` lazily loads public trust and optional LAN socket;
`refresh_relay_directories` queries bounded trusted endpoints; `get_remote_instances`
and `get_lan_relay_candidates` expose copied public/hint state. `trust_relay_directory`
requires explicit local certificate import. `join_remote_instance` stages exact
content, establishes a checked encrypted route, freshly authenticates to the origin
and joins through existing admission. Old membership ends once transport switches;
failure after that point cannot claim old membership preservation.
`get_relay_preferences` lazily loads client-local ordered entries, migrates the old
scalar endpoint once and binds immediate endpoint-block cleanup. The live client
iterates unpinned allowed entries on timeout/unavailability and never claims server
identity verification from existing ENet account authentication.
`ensure_relay_connected` returns true for an already authenticated relay or awaits
one retry attempt. Concurrent callers share `relay_connection_finished`; Network
settings select the endpoint, failures close transport and clear the retry latch.
It never automatically restores instance membership.
### [NetworkHandler](../../scripts/multiplayer/network_handler.gd)

Client autoload. Private transition helpers correlate operation/session, stage
before admission, activate only matching acknowledgement and disconnect on uncertain
commit/activation. `_process` polls peer and deadlines. Profile and instance
handlers reject other sessions/stale revisions. Remote-player cleanup removes
children; animation service lives under DataLoader, not that cleanup list.

| Functions | Contract |
| --- | --- |
| `get_animation_controller` | Returns one attached/recovered nonretiring service when inside tree; replaces queued-deletion instance. Borrowed service, caller must not free it casually. |
| `get_avatar_visibility` | Returns client-local visibility policy synchronized to current session/account scope. |
| `set_player_avatar_hidden` | Validates nonbusy matching session/current roster target, updates local identity policy and remote avatar only, then refreshes rows; sends no packet. |
| `create_peer` | Await key-authenticated relay connection; configures client moderation path/signals, publishes local profile on success; bool. Writes moderation directory client-side. |
| `create_session` | Sends authenticated create with selected mode/world/name and builtin hash where supported; result arrives asynchronously. Not immediate membership success. |
| `request_player_model`, `sync_player_avatar` | Legacy RPC model URL request/response adapters; sender-derived lookup. Current custom ENet/profile and typed asset flow should not be confused with a second authoritative animation stream. |
| `sync_player_data` | Applies received actor transform to current remote node only outside transitions; no local movement authority. |
| `sync_player_voice` | Feeds received samples to remote spatial playback under same session guards; never microphone capture. |
| `join_session` | Await authorized lookup/revision staging, join result and activation; bool/last_session_error. Concurrent request rejected; failure before acknowledgement preserves old world. |
| `host_world` | Await selected content staging then create/result/activate; bool. Explicit hosting, never automatic side effect of discovery click. |
| `update_connected_peers` | Reconciles current other-peer nodes and emits participants_changed; metadata/profile resolution is separate from avatar completion. |
| `is_instance_admin` | Reads local fingerprint's role in authoritative active snapshot; false without identity/state. UI check is not relay authorization. |
| `get_instance_summary` | Returns {title, mode, people} for the status bar from the acknowledged instance; {} when not in one. |
| `refresh_instance` | Sends correlated refresh and starts snapshot deadline; no optimistic permissions. |
| `manage_instance` | Guards busy/pending/admin and emits revisioned action with target identity/peer guards; returns request ID or empty, completion via signal. |

<!-- module: scripts/multiplayer/relay.gd -->
`start_federation` explicitly loads operator infrastructure configuration, starts
the TLS service, trusts/connects configured peers and optionally starts LAN hints.
Normal `handle_events` exports only pinned public instances and polls live links;
teardown closes federation state. Legacy local-only relay startup remains supported.
### [Relay](../../scripts/multiplayer/relay.gd)

Server scene Node. Main-thread ENet event loop; transient auth/profile/membership/
admission/social/animation state only. Private management validates admin, revision,
target, rates and deduplication. Admission is bound to current admins/mode/world;
all required moderation approvals must arrive fresh. No durable user/session store.

| Functions | Contract |
| --- | --- |
| `start_relay` | Binds ENet host on 0.0.0.0:7374; logs failure, leaves unavailable if bind fails. Tests substitute ephemeral host instead. |
| `handle_events` | Expires social/animation/admission state and dispatches connection events/packets until none; requires host. |
| `peer_connected` | Allocates available byte peer ID, metadata/timeouts; full capacity disconnects instead of reusing active identity. |
| `peer_disconnected` | Idempotently removes matching connection and indirect caches/queues/authored metadata/bans; notifies surviving instances and frees ID. |
| `on_packed` | Bounded type dispatch, authenticated operation checks and actor-derived routing; does not trust claimed IDs. Unknown type errors; use real codec/schema fixtures for hostile input. |
| `remove_user_from_session` | Removes peer/admin, increments revision, deletes empty instance or promotes survivor and notifies; clears animation pair state. Valid internal index required. |
| `generate_code` | Creates unused instance code against current sessions; not an access grant or account identity. |
| `get_session_index`, `get_user_in_session` | Find current session/index or −1; no persistent lookup history. |
| `get_public_session` | Builds public-only summaries without roster/account keys; no non-public discovery leakage. |
| `notify_session` | Sends each connected member its other-peer list, scoped profiles and authoritative instance state; invalid index ignored. |
| `send_result` | Sends reliable correlated session outcome with current world revision when available; only connected destination. |
| `valid_creation` | Validates metadata, world address and optional hash; does not download/trust publisher content. |
| `authenticate_peer` | Internal verified-key installation, not a public authentication bypass. Wire handler calls only after challenge proof. |
| `publish_profile` | Accepts matching authenticated owner and valid fields/signature/revision; updates transient publication and notifies instance; bool. Internal unsigned adapters are test-only, not emitted as verified network profiles. |
| `get_profiles_for_peer` | Returns only authenticated current-instance public profiles with derived peer IDs; no unrelated instance or private keys. |

<!-- module: relay_protocol/relay_peer.gd -->
### [RelayPeer](../../relay_protocol/relay_peer.gd)

Client transport object owned by NetworkHandler. Main-thread polling; no automatic
background receive thread. Account private key is used locally for signatures.
Moderation policy is client-owned disk state, unlike relay session metadata.

| Functions | Contract |
| --- | --- |
| `send_animation` | Sends reliable AccountPacket only after authentication/capability; caller supplies sole resolved-state/supporting transport payload. |
| `send_world` | Sends bounded caller world-item intent only after authenticated item capability negotiation. Relay derives sender and enforces instance/revision/lease scope; callers must supply current pinned content revision. |
| `configure_moderation` | Loads bounded owner-key policy or preserves/reports corrupt/wrong-account file; no automatic fail-open approval. |
| `connect_to_relay` | Validates endpoint, creates one-peer ENet host and initiates connection; returns bool for transport initiation with authentication_error on failure. Call handle_events for completion; not authenticated immediately. |
| `create_session`, `join_session` | Sends authenticated selected metadata/session/world and expected revision; no local success claim. |
| `resolve_instance` | Sends authenticated code lookup without changing membership. |
| `decide_join` | Sends allow/decline only for a known pending token; relay still validates current admin/support. |
| `handle_events` | Expires request rows, ticks friends, polls ENet and dispatches until none; requires connection. |
| `connected_to_relay` | Marks transport connected, emits connected, sends public-key hello when private key configured; not proof yet. |
| `disconnected_from_relay` | Clears capabilities/session/profiles/peers and disconnects friend transport, emits lifecycle signal; retains client policy/contacts. |
| `on_packet` | Parses by explicit ID, validates lengths/scope/snapshots/challenges and emits appropriate signal. Rejects late session data; payload parser alone is not authorization. |
| `publish_profile` | Sends authenticated owner-signed profile; relay verifies owner/signature again. |
| `request_instance` | Sends management payload only with connected/authenticated peer; coordinator and relay enforce action semantics. |

## Protocol functions

<!-- module: relay_protocol/decode_result.gd -->
### [DecodeResult](../../relay_protocol/decode_result.gd)

Pure quiet JSON ingress. `json_value` rejects empty/oversized/deeper-than-32 input
before parsing and returns ok/value or ok=false/error without engine exceptions.
`json_object` additionally rejects nonobjects. Callers still enforce exact packet
schema, actor authorization and operation limits; successful JSON is not trust.

<!-- module: scripts/discovery/discovery_model.gd -->
### [DiscoveryModel](../../scripts/discovery/discovery_model.gd)

Pure catalog/directory model. `catalog` validates bounded bytes/entries/metadata
and returns ok/value or failure preserving caller's previous data. `summaries`
normalizes public-only exact-URL instances with integral counts/text bounds.
`classify_query` separates HTTP/builtin URL, five-character alphanumeric room code
and local filter. These functions do not issue requests, admit users or render UI.

<!-- module: relay_protocol/tracking_pose.gd -->
### [TrackingPose](../../relay_protocol/tracking_pose.gd)

RefCounted pure codec/schema. `valid` checks version, sequence, avatar hash,
calibration revision, at most six allowed roles and finite bounded position/unit
quaternion arrays. `encode_target` converts trusted Transform3D to seven numbers;
`decode_targets` reconstructs already validated role transforms. No actor/session
authority or hardware identity in this codec; relay derives actor and checks exact
membership/rate. Avatar revision mismatch prevents remote application.

<!-- module: relay_protocol/packet_info.gd -->
### [PacketInfo](../../relay_protocol/packet_info.gd)

| Functions | Contract |
| --- | --- |
| `encode`, `decode` | Encode/decode the one-byte type only. decode assumes nonempty transport-validated buffer. |
| `sent`, `broadcast` | Encode and send on ENet channel 0 with packet flag to peer/connection; caller owns connection state and authorization. Compatibility spelling `sent` retained. |

<!-- module: relay_protocol/account_packet.gd -->
### [AccountPacket](../../relay_protocol/account_packet.gd)

| Functions | Contract |
| --- | --- |
| `create` | New reliable packet with explicit type/dictionary; no schema/actor validation. |
| `parse` | Returns JSON object or `{}` for invalid/2..256 KiB envelope; caller applies smaller per-operation bounds and authentication. |
| `encode` | Adds UTF-8 JSON after type byte; no object deserialization/execution. |

<!-- module: relay_protocol/create_session.gd -->
### [CreateSession](../../relay_protocol/create_session.gd)

| Functions | Contract |
| --- | --- |
| `create` | Creates reliable metadata request with explicit ID 1; result pending relay validation. |
| `create_from_data` | Instantiates then decodes caller-validated bytes. |
| `encode`, `decode` | JSON object after type; decode falls back `{}` and recursively normalizes integer-valued numbers. Legacy direct JSON errors may be diagnostic; not general hostile-input parser. |

<!-- module: relay_protocol/join_session.gd -->
### [JoinSession](../../relay_protocol/join_session.gd)

| Functions | Contract |
| --- | --- |
| `create` | Reliable session/world/expected-revision request, not URL-only join. |
| `create_from_data` | New packet decoded from transport-validated bytes. |
| `encode`, `decode` | JSON after the one-byte packet type (ID 2); legacy plain ID accepted. Parsed world_revision type checked; malformed revision becomes invalid sentinel. Admission still relay-owned. |

<!-- module: relay_protocol/session_result.gd -->
### [SessionResult](../../relay_protocol/session_result.gd)

| Functions | Contract |
| --- | --- |
| `create`, `create_from_data` | Construct reliable result / instantiate and decode validated bytes. |
| `encode`, `decode` | JSON dictionary after type; non-object leaves empty result. Coordinator matches operation/session and boolean success before acting. |

<!-- module: relay_protocol/public_wolds.gd -->
### [GetPublicSessions](../../relay_protocol/public_wolds.gd)

| Functions | Contract |
| --- | --- |
| `create`, `create_from_data` | Construct reliable public-summary array / decode validated response. |
| `directory` | Construct negotiated version-1 dictionary envelope for correlated requests/results; legacy arrays remain a separate codec path. |
| `encode`, `decode` | JSON array with recursive integer normalization; non-array empty. Client browser validates public mode/identity/address separately. Filename spelling retained. |

<!-- module: relay_protocol/get_session_peers.gd -->
### [GetSessionPeers](../../relay_protocol/get_session_peers.gd)

| Functions | Contract |
| --- | --- |
| `create`, `create_from_data` | Reliable other-member list / decoded new object. |
| `encode`, `decode` | JSON peer array, integer normalization; expects trusted relay shape/transport validation, not a hardened independent schema. Recipient excludes itself. |

<!-- module: relay_protocol/id_assignment.gd -->
### [IDAssingnment](../../relay_protocol/id_assignment.gd)

| Functions | Contract |
| --- | --- |
| `create`, `create_from_data` | Reliable legacy byte-ID packet / decode validated bytes. |
| `encode`, `decode` | Type + ID + remaining byte IDs. Current RelayPeer ignores assignment; legacy spelling/codec preserved, no new authority inferred. |

<!-- module: relay_protocol/player_data.gd -->
### [PlayerData](../../relay_protocol/player_data.gd)

| Functions | Contract |
| --- | --- |
| `create`, `create_from_data` | Unsequenced transform packet / decode exactly 26 transport-validated bytes. |
| `encode`, `decode` | Type/sender plus six float32 coordinates; mutates packet fields. Relay derives sender and instance routing; contains no tracker/animation state. |

<!-- module: relay_protocol/voice_chat.gd -->
### [VoiceData](../../relay_protocol/voice_chat.gd)

| Functions | Contract |
| --- | --- |
| `create`, `create_from_data` | Unsequenced mono float-input voice packet / decode validated byte buffer. |
| `encode`, `decode` | Clamp floats to signed16 PCM after type/sender, inverse to floats on receive; length policy belongs to transport. No microphone activation or compression negotiation. |

<!-- module: relay_protocol/world_address.gd -->
### [WorldAddress](../../relay_protocol/world_address.gd)

| Functions | Contract |
| --- | --- |
| `is_valid` | Pure builtin-or-bounded HTTP(S) syntax check; rejects whitespace/credentials/empty authority. Does not prove publisher trust, cache policy or safe Godot execution. |

<!-- module: relay_protocol/instance_state.gd -->
### [InstanceState](../../relay_protocol/instance_state.gd)

| Functions | Contract |
| --- | --- |
| `integer` | Finite integral number within supplied inclusive bounds, including JSON floats; bool. |
| `valid_metadata` | Mode 0..4, bounded nonblank name/description/control-character rules; pure bool. |
| `valid_fingerprint` | Lowercase 64-hex string only; hash syntax, not account proof. |
| `valid` | Valid metadata/world/session/revision and unique bounded roster roles/IDs/fingerprints; no mutation. Valid shape does not establish sender authorization. |

<!-- module: relay_protocol/animation_state.gd -->
`transfer_timeout_msec` computes bounded size-aware budgets for supported assets, with old minimum and allowance for 256 MiB models at conservative throughput. Byte/chunk validation and admission remain separate.

### [AnimationState](../../relay_protocol/animation_state.gd)

| Functions | Contract |
| --- | --- |
| `integer`, `number` | Pure finite bounded numeric predicates; integer also rejects fractions. |
| `valid` | Version-2 resolved descriptor schema/builtin or custom hash/size/mask/clip bounds; no legacy manual controls. Membership/sender/sequence ordering is router/controller responsibility. |
| `playhead` | Computes current phase using monotonic elapsed, bounded speed, offset and duration; loops modulo or clamps one-shot end. Input must already be valid. |

<!-- module: relay_protocol/animation_router.gd -->
### [AnimationRouter](../../relay_protocol/animation_router.gd)

RefCounted relay component; server object supplies authenticated peers/sessions.
Private `_same` and `_send` protect routing/connection state. No asset files written.

| Functions | Contract |
| --- | --- |
| `handle` | Validates capability/control rate/schema/session/sequence, binds actor/time/generation, routes latest state or request-bound typed chunks. No unauthenticated/unsolicited file forwarding. |
| `snapshot` | Sends latest bounded same-instance states to supported recipient, excluding itself; no history of disconnected actors. |
| `leave` | Removes actor state/pairwise transfers and notifies surviving same-instance peers; called before membership removal. |
| `disconnect_peer` | Leave cleanup plus capability/rate/generation removal; no reconnect restoration. |
| `tick` | Expires outstanding transfer metadata by monotonic deadlines. |

<!-- module: relay_protocol/friend_event.gd -->
### [FriendEvent](../../relay_protocol/friend_event.gd)

| Functions | Contract |
| --- | --- |
| `bytes`, `digest` | Domain-separated fixed-field serialization / SHA-256 hex; no disk/network. Caller supplies canonical event fields. |
| `create` | Signs request or request-bound accept/decline/cancel/revoke with private actor key and random event ID; returns dictionary. Caller owns valid relationship context. |
| `valid` | Checks allowed fields/limits/keys/signature and nested request/digest/actor direction; false on forgery or unexpected nesting. |
| `valid_proof` | Requires matching valid request+accept pair; pure mutual-grant proof syntax/signatures, not current relay freshness. |

<!-- module: relay_protocol/friend_router.gd -->
### [FriendRouter](../../relay_protocol/friend_router.gd)

Ephemeral relay component. Private helpers bind connection actor, signed pair
proofs, subscriptions, presence sequences and rate limits. No saved contacts or
offline delivery mailbox; persistent revocation is client-owned.

| Functions | Contract |
| --- | --- |
| `mutual` | Queries fresh active mutual authorization edge between current connections; not durable contact history. |
| `handle` | Validates/routs supported social operations against authenticated sender and bounded proof/payload; not a trusted arbitrary event injection API. |
| `disconnect_peer` | Clears actor/pair/subscription/proof/rate references including surviving users' caches. |
| `tick` | Expires live authorizations/rates/presence-related temporary state; server polls. |

<!-- module: relay_protocol/friend_system/sent_friend_request.gd -->
### [Legacy friend stub](../../relay_protocol/friend_system/sent_friend_request.gd)

No public functions. This legacy placeholder is not the active signed social
protocol; use FriendEvent/FriendService/FriendRouter. Do not infer an offline
friend-message feature from the filename.

## UI contracts

<!-- module: scripts/GUI/vr_tracking_setup.gd -->
### [VRTrackingSetup](../../scripts/GUI/vr_tracking_setup.gd)

Viewport-local setup panel. `configure` binds the active VR player; private refresh
lists fresh runtime-exposed positional trackers and lets users assign/unassign
hips/feet with duplicate-role guards. Calibration saves current eye height and
per-role position/orientation mount offsets in a three-second cancelable capture.
The user must match the avatar reference stance; reassignment invalidates that role's
offset and requires recalibration. No device
serial persistence or implied support for trackers absent from the OpenXR runtime.
The panel reports rig warnings and preserves blocked corrupt calibration stores.

<!-- module: scripts/GUI/vr_keyboard.gd -->
### [VRKeyboard](../../scripts/GUI/vr_keyboard.gd)

Viewport-local pointer keyboard. `edit` binds a weak LineEdit/TextEdit target;
`type_text` inserts at caret respecting editable/read-only and field length;
`backspace` deletes, `submit` emits LineEdit submission or inserts TextEdit newline,
`close` releases target/hides. Buttons do not steal text focus. Private row builder
and caret movement never access a global text target or persist entered content.
The player opens it on viewport text focus and closes with the main menu; controller
stick scrolling emits bounded wheel events only at valid panel hits.

UI public calls require attached/ready nodes with their declared scene children
and supplied services. They must not be used to bypass account or relay checks.
Asynchronous media/import callbacks use generations/visibility guards. Removing a
subpage must release subscriptions and input ownership without changing an avatar
merely because a menu closes. Evidence: profile/settings/friends/instance and
animation lifecycle tests, plus manual small-window/XR checks.

<!-- module: scripts/GUI/animation_menue.gd -->
`import_animation_files` snapshots consent for a whole selected batch, guards concurrent Apply/import and leaves empty selections unchanged. `choose_model_file` opens single VRM/GLB selection; `choose_animation_files` opens multiple VRMA/GLB selection. No implicit upload or manual URL entry.

### [Avatar source editor](../../scripts/GUI/animation_menue.gd)

Owner-only source editor under profile. Ready creates model/multifile/URL inputs,
draft source list, permission and layout editor. No manual playback console.
Private owner-change handler closes stale editor; exit invalidates async draft work.

| Functions | Contract |
| --- | --- |
| `add_source` | Await config import into draft (model or external); busy/limit/generation guarded. Permission resets after import; no automatic equip. |
| `apply` | Await full candidate commit after current-owner check; displays success/error. Close/Cancel discards draft only, not cached imported bytes. |

<!-- module: scripts/GUI/avatar_preview.gd -->
### [AvatarPreview](../../scripts/GUI/avatar_preview.gd)

Independent SubViewport/world; scripts/physics/audio behavior refused/disabled
before attach. Private bounds fitting/zoom/input owns only preview pivot/camera.
Hiding clears model/rendering. Public profile/equipped avatar is never changed.

| Functions | Contract |
| --- | --- |
| `load_file` | Await bounded local VRM bytes into independent preview; bool. Original path is not sent over network. |
| `set_source` | Changes URL, clears prior preview/restores URL loader, updates affordances; does not fetch until requested by view. |
| `clear_preview` | Invalidates generation, detaches/frees model and disables viewport updates. |
| `load_preview` | Await injected/default URL loader, reject stale/hidden/unsafe result, attach and frame independent model; error signal on failure. |
| `reset_view` | Restores the stage's front view and full-body framing without reloading source. |
| `set_idle_animation` | Plays or stops the bundled neutral stance on a humanoid model; false without a validated rig. |

<!-- module: scripts/GUI/emote_layout_editor.gd -->
`filter_library` bounds/normalizes the query and rebuilds applied-emote add rows, disabling existing group shortcuts; it does not import or play clips.

### [EmoteLayoutEditor](../../scripts/GUI/emote_layout_editor.gd)

| Functions | Contract |
| --- | --- |
| `configure` | Binds account config and renders persistent groups/actions; tracks account owner and closes on switch. Private buttons commit graph operations, confirm deletion/reset, never play clips. |

<!-- module: scripts/GUI/emote_wheel.gd -->
### [EmoteWheel](../../scripts/GUI/emote_wheel.gd)

Shared eight-sector Control renderer. Private draw/input handles dead zone,
hysteresis and desktop/controller confirmation; exit restores owned input once.
No footer paging buttons, network calls or model importing.

| Functions | Contract |
| --- | --- |
| `open` | Binds layout/catalog, resets root/page, captures prior focus/mouse as requested and opens; browsing alone emits no emote intent. |
| `radius` | Computes viewport-adapted wheel radius; pure UI sizing. |
| `refresh` | Repairs current group/page after layout changes, builds sectors, disables unavailable actions and clears hover. |
| `select_direction` | Selects sector from normalized 2D direction with dead zone/hysteresis; no activation. |
| `activate_sector` | Ignores inert/disabled entries; emits action ID or navigates group/page. Returns true only if the action handler dismissed the wheel; local mirror tools do not dismiss it. |
| `open_value_popup` | Opens the reusable in-wheel circular scalar popup with caller-provided title/value/range/step/unit/callback; width and height use separate entries. No avatar playback or input handoff. |
| `set_size_angle` | Delegates a finite normalized turn fraction to the reusable scalar dial callback and redraws without closing. |
| `size_pointer` | Starts/ends ring drag or returns via center Back; shared by desktop mouse and XR trigger. |
| `back` | Restores parent page/focus or dismisses root; no animation side effects. |
| `dismiss` | Hides, restores prior input/focus once and emits closed; safe with later exit cleanup. |

<!-- module: scripts/GUI/xr_emote_wheel.gd -->
### [XREmoteWheel](../../scripts/GUI/xr_emote_wheel.gd)

| Functions | Contract |
| --- | --- |
| `open` | Builds transparent viewport/quad and stable hand-local world placement; configures hold vs pointer mode, action/diameter/haptics. Caller supplies valid attached XR hand/camera. Private process projects direction, confirms/rearms navigation, closes on tracking/focus loss. No camera/locomotion teleport. |

<!-- module: scripts/GUI/error_popup.gd -->
### [ErrorPopup](../../scripts/GUI/error_popup.gd)

| Functions | Contract |
| --- | --- |
| `show_error` | Finds/creates reusable popup under supplied UI parent and presents real error; returns/reuses UI instance, not a logging-only replacement. |
| `present` | Displays message and blocks global shortcuts while visible; preserves caller draft. |
| `dismiss` | Releases popup input state and hides; no data reset. |

### Retired Home page (historical)

The old `home_menue.gd` module was removed by the tablet migration. Its lazy
subpage/profile navigation contract is historical, not a supported runtime API.
Current entry points are [Quick page](../../scripts/GUI/quick_page.gd), which emits
explicit tile/friend/page intents and owns shared mute presentation, and the
[tablet shell](../../scripts/GUI/tablet_shell.gd), which owns navigation. Existing
profile/friend services retain authorization; changing the menu grants no rights.

<!-- module: scripts/GUI/tablet_shell.gd -->
### [TabletShell](../../scripts/GUI/tablet_shell.gd)

Shared tablet layout for the PC overlay and the VR tablet: status bar, six-item
navigation rail, page header with a nested-page stack and lazily created pages.
Mute, presence and profile controls use the SaveData owners; it stores no state
of its own. reset() frees closed pages so hidden menus hold no subscriptions.

| Functions | Contract |
| --- | --- |
| `page_ids` | Returns the rail page ids in order: quick, friends, worlds, avatars, instance, settings. |
| `page_scene_paths` | Returns the production scene path for each page id; copy, not live state. |
| `current_page` | Returns the selected top-level page id. |
| `page` | Returns the page control, creating it on first use through `page_factories`; unknown id returns null. |
| `open_page` | Shows one top-level page, clears nested pages and updates the rail; false for unknown ids. |
| `push_page` | Shows a nested page above the current one with its title and Back. |
| `back` | Frees the top nested page; false on a top-level page so hosts can close. |
| `reset` | Cancels profile edits, clears nested pages, frees non-Quick pages and opens Quick. |
| `set_compact` | Switches the rail between icon+label (96 px) and icon-only (64 px) layouts. |
| `set_vr_mode` | Shows the pin button and VR close wording; reads vr.menu_pin_mode. |
| `refresh_status` | Pulls NetworkHandler.get_instance_summary() into the status bar. |
| `update_status` | Shows instance title, access mode and people count; empty title shows "Not in an instance". |
| `open_own_profile` | Opens the local account's profile as a nested page. |
| `open_profile` | Opens or replaces one nested profile page for a fingerprint; rights stay with the profile service. |
| `handle_quick_action` | Routes Quick tiles: avatar/invite open pages, mute toggles SaveData.voice, others emit quick_action for the host. |

<!-- module: scripts/GUI/quick_page.gd -->
### [QuickPage](../../scripts/GUI/quick_page.gd)

Six Quick tiles (Mute, Emotes, Change avatar, Invite, Respawn, Mirror) and the
online-friends strip. Mute and Mirror act directly through SaveData.voice and the
animation controller; other tiles emit action_requested for the shell. Tiles are
disabled when their target is unavailable (no instance, busy transition).

| Functions | Contract |
| --- | --- |
| `refresh` | Re-evaluates tile availability, mute/mirror state and friends; no network requests. |
| `online_friends` | Returns mutual friends whose status is online, sorted by display name; empty without a friend service. |
| `refresh_friends` | Rebuilds up to eight friend chips plus a "+N" chip, or the empty-friends line. |

<!-- module: scripts/GUI/presence_dot.gd -->
### [PresenceDot](../../scripts/GUI/presence_dot.gd)

No public functions. Draws the status-bar presence dot in the theme's Presence
color for the current state and redraws when the theme changes. It never changes
the friend service; the shell assigns its state.

<!-- module: scripts/GUI/desktop_overlay.gd -->
### [DesktopOverlay](../../scripts/GUI/desktop_overlay.gd)

PC host for the shell: a CanvasLayer with a dimmed background and a centered,
non-movable 4:3 menu. With manage_mouse it releases and captures the mouse like
the previous menu. Esc goes back before closing; keys 1–6 select pages unless a
text field or blocks_global_shortcuts control has focus.

| Functions | Contract |
| --- | --- |
| `is_open` | Returns whether the menu is shown. |
| `open` | Resets the shell to Quick, shows the overlay, releases the mouse and emits opened. |
| `close` | Hides the overlay, drops focus inside it, captures the mouse and emits closed. |
| `toggle` | Opens when closed, otherwise closes. |
| `layout_for` | Returns {rect, compact} for a logical viewport size: 4:3 at 86% height, or full-height compact below 560 px. |
| `apply_layout` | Places and sizes the shell and sets its compact rail. |
| `handle_input` | Applies Esc and number-key navigation; true when the event was consumed. |

<!-- module: scripts/GUI/vr_tablet.gd -->
### [VRTablet](../../scripts/GUI/vr_tablet.gd)

Floating VR tablet hosting the shared menu at 1000×750 logical px rendered at
1600×1200. The node is never scaled (scale_factor resizes meshes) so raycasts and
placement use an orthonormal transform. Placement is session state only.

| Functions | Contract |
| --- | --- |
| `size_m` | Returns the current screen size in metres including scale_factor. |
| `configure` | Binds the settings store and applies VR Menu, reduce motion and interface size settings live. |
| `effective_smoothing` | Returns smoothing, or 0 with reduce motion. |
| `place_initial` | Places the tablet 0.55 m ahead along head yaw, 0.2 m below the eyes, facing them without roll. |
| `summon` | Same placement as place_initial; used by the hold-to-summon gesture. |
| `remember_placement` | Stores the pose relative to the player's yaw and position. |
| `restore_placement` | Reapplies the stored relative pose; false when nothing was stored. |
| `update_follow` | In follow mode re-centers after >45° head turn or >1.5 m distance; pinned or grabbed tablets stay. |
| `raycast_to_pixel` | Returns the physical pixel hit by a front-facing ray, else (-1, -1). |
| `raycast_to_viewport_point` | VRViewport2D-compatible alias of raycast_to_pixel. |
| `inject_input` | Pushes a pointer event at a physical pixel; the viewport converts it to layout coordinates. |
| `is_status_bar_pixel` | True for pixels inside the status bar strip (laser grab). |
| `touch_pixel` | Returns {pixel, hover, pressed} for a fingertip within 3 cm in front to 2 cm behind the screen when direct touch is on, else {}. |
| `grab_zone_contains` | True on the frame band (≤4 cm outside the screen) or the status bar strip, within ±5 cm depth. |
| `world_grab_blocked` | True while visible and the point is in a grab zone, so world pickup yields to the tablet. |
| `is_grabbed` | True while any hand holds the tablet. |
| `begin_grab` | Starts a one-hand grab (two hands enable scaling); requires a grab zone unless forced. |
| `update_grab` | Follows the hand with its grab offset, or scales 0.6–1.6× with two hands; smoothed. |
| `end_grab` | Releases one hand; the other continues from the current pose. |

<!-- module: scripts/GUI/avatar_stage.gd -->
### [AvatarStage](../../scripts/GUI/avatar_stage.gd)

Reusable 3D stage in its own World3D: orbit camera, three-point lighting, floor
disc and themed background. Displays a given model only; loading and safety
checks live in AvatarPreview. Renders continuously only while easing or while an
animation player under the model is playing.

| Functions | Contract |
| --- | --- |
| `background_color` | Returns the theme's PreviewStage background color. |
| `set_model` | Attaches, normalizes (longest side 2 units, centered) and frames a model; replaces the previous one. |
| `clear` | Detaches and frees the model and disables rendering. |
| `frame` | Frames full, upper or face (head bone or 90% height); resets zoom/pan; false for unknown presets. |
| `next_framing` | Cycles full → upper → face and returns the new preset. |
| `camera_target` | Returns the framed target plus pan offset in stage space. |
| `camera_distance` | Returns the framed distance times zoom. |
| `reset_view` | Front view, 8° pitch, zoom 1, no pan, full framing. |
| `orbit` | Turns by pixel delta; pitch limited to −20°…45°. |
| `pan` | Moves the target by pixel delta, at most 1 unit from the framing target. |
| `zoom_by` | Multiplies zoom, limited to 0.5–3. |
| `process_camera` | Eases yaw/pitch/zoom frame-rate independently; instant with reduce motion. |
| `is_rendering_continuously` | True while easing or animating. |

<!-- module: scripts/GUI/toast_host.gd -->
### [ToastHost](../../scripts/GUI/toast_host.gd)

Non-blocking notifications for one shell, at most three, never focusable and
never blocking clicks. Expiry timers are bound to the host, so freeing the host
drops pending removals. Pages reach it through the shell's toast_host meta.

| Functions | Contract |
| --- | --- |
| `find_for` | Static: returns the nearest ancestor's toast host, or null outside a shell. |
| `notify` | Static: shows a toast via find_for; false when no host exists. |
| `visible_toasts` | Returns current toasts, oldest first. |
| `show_message` | Adds a toast of kind info/success/warning/error (unknown → info) for its default or given duration; drops the oldest beyond three. |

<!-- module: scripts/GUI/empty_state.gd -->
### [EmptyState](../../scripts/GUI/empty_state.gd)

Shared empty-list message: muted icon, one sentence and at most one action
button. The icon follows the theme's muted text color. It owns no data and the
action callback is supplied by the page.

| Functions | Contract |
| --- | --- |
| `configure` | Sets icon, message and optional action; the action button is hidden without label or valid callable. |

<!-- module: scripts/GUI/text_block.gd -->
### [TextBlock](../../scripts/GUI/text_block.gd)

No public functions besides `is_shaped`. Long read-only text drawn with a
TextParagraph onto an own RenderingServer canvas item. It does no shaping while
hidden and none on theme changes until shown; glyph commands are re-recorded only
when text, width, font or color change. Used for full license terms in Credits.

| Functions | Contract |
| --- | --- |
| `is_shaped` | True once the text has been shaped for the current width. |

<!-- module: scripts/GUI/gui_warmup.gd -->
### [GuiWarmup](../../scripts/GUI/gui_warmup.gd)

Started once by SaveData after the theme is applied (skipped headless, on relays
and with COMUNICARE_GUI_WARMUP=0). Loads menu page scenes on worker threads,
rasterizes interface glyphs through a throwaway RenderingServer canvas item and
renders the avatar stage once off-screen so preview pipelines compile at startup.

| Functions | Contract |
| --- | --- |
| `pipeline_compilations` | Static: sum of RenderingServer pipeline-compilation counters (diagnostics). |
| `start` | Static: adds one warm-up node to the root per process; null when skipped. |

<!-- module: scripts/GUI/theme/palette.gd -->
### [Palette](../../scripts/GUI/theme/palette.gd)

Only place where UI colors are defined: six presets and seven accents from the
GUI tablet specification, with dark/light/high-contrast accent variants and
semantic colors. Pure data; contrast is verified by tests/gui_tablet.

| Functions | Contract |
| --- | --- |
| `presets` | Returns preset ids in display order. |
| `accents` | Returns accent ids including match_highlight. |
| `is_light` | True for Paper and Sand. |
| `tokens` | Returns the color token dictionary; unknown preset/accent fall back to Graphite/Teal; match_highlight maps the 3D highlight color. |

<!-- module: scripts/GUI/theme/theme_builder.gd -->
### [ThemeBuilder](../../scripts/GUI/theme/theme_builder.gd)

Fills a Theme from palette tokens: flat styleboxes (4 px controls, 6 px panels),
2 px focus ring, three text sizes (18/24/14), 4 px spacing grid, type variations
and custom-drawn control colors. No gradients, textures or strong shadows.

| Functions | Contract |
| --- | --- |
| `build` | Mutates and returns the given Theme and emits changed once, so open controls restyle live. |
| `c` | Returns one token color. |
| `mix` | Linear blend of two colors. |
| `hover` | Hover tint toward text color. |
| `pressed` | Pressed tint toward text color. |
| `faded` | Same color at reduced alpha (disabled states). |
| `box` | New flat stylebox with radius and content margins, no shadow. |
| `bordered` | Flat stylebox with a 1 px border in the border token. |
| `clear_box` | Transparent stylebox with margins. |
| `focus_ring` | Unfilled focus-colored 2 px ring. |
| `shadowed` | Adds the subtle allowed shadow to a stylebox. |
| `set_button_boxes` | Assigns all button state styleboxes for a type. |
| `set_font_colors` | Assigns font and icon colors for all button states of a type. |

<!-- module: scripts/GUI/theme/theme_service.gd -->
### [ThemeService](../../scripts/GUI/theme/theme_service.gd)

Owned by SaveData (created in _init, applied in _ready after settings load).
Rebuilds the shared project Theme when color, accent, highlight, interface size
or reduce-motion settings change, and sets the root content scale.

| Functions | Contract |
| --- | --- |
| `configure` | Binds the settings store (and optionally a Theme for tests); subscribes once. |
| `resolve_theme` | Returns the project theme, loading themes/default.tres if needed. |
| `apply` | Computes tokens from settings, rebuilds the Theme, applies UI scale and emits applied. |
| `current_tokens` | Returns the last applied tokens. |

<!-- module: scripts/GUI/theme/swatch_picker.gd -->
`set_colors` copies replacement swatch data and queues existing buttons to redraw,
without rebuilding nodes, changing selection or committing a setting. The caller
supplies reviewed colors for the enum's stable identities.

### [SwatchPicker](../../scripts/GUI/theme/swatch_picker.gd)

Labelled color swatches for an enum setting (color scheme, accent). Colors are
supplied by the settings page from the palette; selecting emits value_selected
and the settings store remains the owner of the value.

| Functions | Contract |
| --- | --- |
| `set_options` | Builds one self-drawing button per option; with unchanged options it only updates colors and tooltips. |
| `swatch_buttons` | Returns the swatch buttons in option order. |
| `set_colors` | Updates swatch colors in place and redraws; no nodes are rebuilt. |

<!-- module: scripts/GUI/avatar_browser/browser_results.gd -->
### [BrowserResults](../../scripts/GUI/avatar_browser/browser_results.gd)

Avatar browser card grid and home page area. Holds no network state; each card
exposes its thumbnail TextureRect through the "thumbnail" meta for the browser's
anonymous thumbnail loader.

| Functions | Contract |
| --- | --- |
| `columns_for_width` | One column per 220 px, at least one. |
| `cards` | Returns the live result cards. |
| `clear` | Removes cards and page buttons. |
| `set_records` | Replaces cards; shows the empty state for an empty list. |
| `add_record` | Adds one 200×248 card emitting record_selected when pressed. |
| `add_page_button` | Adds a page-level button above the grid. |
| `add_more_button` | Adds a card-sized "Load more" button as the last grid cell. |

<!-- module: scripts/GUI/avatar_browser/browser_sidebar.gd -->
### [BrowserSidebar](../../scripts/GUI/avatar_browser/browser_sidebar.gd)

Navigation, search field, provider and advanced filters of the avatar browser.
It only reports intent (navigate, search_submitted, filters_changed); the browser
owns search state and requests. Text fields block global shortcuts.

| Functions | Contract |
| --- | --- |
| `set_sources` | Rebuilds the provider selector from {id, name} entries plus "All providers". |
| `state` | Returns query, tag, source and every filter value from the controls. |

<!-- module: scripts/GUI/avatar_browser/browser_detail.gd -->
### [BrowserDetail](../../scripts/GUI/avatar_browser/browser_detail.gd)

Detail pane with lazily created preview, license line, one primary action, a
reason when an asset cannot be used and inline progress instead of a modal.

| Functions | Contract |
| --- | --- |
| `show_record` | Shows a record with its import eligibility; disables Use and explains why when not shareable/importable. |
| `ensure_preview` | Creates the AvatarPreview on first use and returns it. |
| `set_progress` | Shows progress 0–100 and disables Use; 100 completes and hides the bar. |
| `show_error` | Ends progress, shows the message and re-enables Use when allowed. |
| `set_compact` | Shows Back to results when the pane replaces the grid. |

<!-- module: scripts/GUI/avatar_browser/browser_sources.gd -->
### [BrowserSources](../../scripts/GUI/avatar_browser/browser_sources.gd)

Providers page, credential storage and the custom-provider PKCE loopback flow,
moved unchanged from the browser. Secrets are memory-only unless explicitly
stored in the OS keyring; preferences never contain credentials.

| Functions | Contract |
| --- | --- |
| `configure` | Binds the browser and creates the credential store. |
| `load_preferences` | Loads the account's custom sources; unreadable files stay untouched and make changes memory-only. |
| `persist` | Atomically writes custom sources when preferences are writable. |
| `render` | Shows provider enable/disable, credential, endpoint and add-source controls. |
| `cancel` | Stops OAuth listening and any pending token exchange. |
| `remember_credential` | Stores the current token in the OS keyring for the provider origin. |
| `restore_credential` | Loads a keyring token if the provider endpoint is unchanged. |
| `forget_credential` | Clears memory and requests keyring removal. |
| `cancel_oauth` | Clears PKCE state and closes the loopback listener. |
| `start_oauth` | Opens a loopback callback and the system browser for sign in (3-minute expiry). |
| `poll` | Accepts one bounded callback request and starts the token exchange. |

<!-- module: scripts/GUI/avatar_browser/browser_assets.gd -->
### [BrowserAssets](../../scripts/GUI/avatar_browser/browser_assets.gd)

Thumbnail, preview and import downloads of the avatar browser, unchanged in
behavior: digests are verified, previews stay isolated, imports are validated
before equip, and stale generations or account switches discard results.

| Functions | Contract |
| --- | --- |
| `pump_thumbnails` | Starts up to two anonymous thumbnail downloads for the current generation. |
| `convert_animation` | Converts animation bytes on one worker thread; empty on failure or when busy. |
| `preview_animation` | Plays a downloaded clip on an isolated copy of the local avatar in the detail preview. |
| `preview_record` | Downloads, verifies and shows an anonymous-source model in the detail preview without equipping. |
| `import_record` | Downloads, verifies, stages and validates; equips with progress or opens the source editor. |

<!-- module: scripts/GUI/menue.gd -->
### [Menu wrapper](../../scripts/GUI/menue.gd)

Keeps the menue.tscn path/UID as a thin wrapper around the tablet shell for the
VR tablet and older callers; current_tab maps to Quick/Friends/Worlds/Settings.
On desktop without the overlay, Esc goes back, then toggles menu and capture.

| Functions | Contract |
| --- | --- |
| `page` | Returns a shell page by id, creating it on first use. |
| `open_page` | Opens a shell page by id; false for unknown ids. |
| `reset` | Resets the shell to Quick and frees closed pages. |
| `close` | In VR emits close_requested; on desktop hides and captures the mouse. |

<!-- module: scripts/GUI/friends_menue.gd -->
### [Friends UI](../../scripts/GUI/friends_menue.gd)

No public functions. Private ready/render handlers subscribe to owner friend
service, show saved/pending/accepted rows, validate public-key input, send explicit
actions and open read-only cached profiles. Account switch clears drafts/rows;
exit unsubscribes. Display strings are not target identities.

<!-- module: scripts/GUI/profile_edit_popup.gd -->
### [ProfileEditPopup](../../scripts/GUI/profile_edit_popup.gd)

| Functions | Contract |
| --- | --- |
| `open_editor` | Requires editable owner and selected field, captures revision/draft and shows only that field; bool false for visitor/invalid request. |
| `draft` | Returns full candidate field values with current edited field, preserving others. |
| `is_dirty` | Compares active draft against captured value; no writes. |
| `save_edit` | Validates current owner/revision, calls signed profile save, emits saved/closes only on success; errors preserve draft. |
| `request_cancel` | Dirty draft asks confirmation; clean closes immediately. |
| `cancel_edit` | Discards local draft and releases modal input; never writes profile. |

<!-- module: scripts/GUI/profile_menue.gd -->
### [ProfileMenu](../../scripts/GUI/profile_menue.gd)

Private refresh uses copies/current rights, independent preview and friend actions;
remote departure clears unavailable view. Close cancels editor/media/preview;
exit unsubscribes from old service. Avatar source editing is self-only.

| Functions | Contract |
| --- | --- |
| `open_profile` | Switches service/fingerprint, cancels old editors/subscriptions, shows current view; owner service controls edit rights. |
| `is_editable` | Delegates can_edit(profile_owner); not inferred from instance role. |
| `get_displayed_public_key` | Returns current public key text or empty; never private identity key. |
| `open_editor` | Opens/reuses one field-specific editor only for owner; bool outcome. |
| `cancel_edit` | Cancels active editor or closes profile view, preserving caller navigation. |

<!-- module: scripts/GUI/settings_menue.gd -->
### [SettingsMenu](../../scripts/GUI/settings_menue.gd)

Rows are built per category: the shown one at once, the others one per frame.
Reading `controls`, `errors` or `resets`, or searching, completes the build first,
so callers always see every setting. The relay panel is created when Network is
first shown and Credits when it is first selected.

| Functions | Contract |
| --- | --- |
| `apply_comfort_preset` | Sets snap turning, 30°, 1.5 m/s, vignette and blink on, jump off through the settings store. |
| `select_category` | Builds the category's rows if still pending, then shows one known registry category, cancels active rebind and resets scroll; invalid name ignored. Private renderer/commit/reset functions use typed store; input conflicts reject without losing capture. Cache actions confirm cleanup and await refresh, not account deletion. |

<!-- module: scripts/GUI/share_session_menue.gd -->
### [Active Instance UI](../../scripts/GUI/share_session_menue.gd)

| Functions | Contract |
| --- | --- |
| `focus_invite` | Quick page Invite: focuses and selects the instance code; without an active instance it shows a hint instead. |
| `open_profile` | Opens selected roster fingerprint using existing profile service/view; instance admin status does not grant account edit rights. Private metadata/moderation handlers use authoritative snapshot/revision, confirmation and correlated results; timeout removes actionable stale permissions. |

<!-- module: scripts/GUI/world_explorer.gd -->
### [WorldExplorer](../../scripts/GUI/world_explorer.gd)

Private catalog and live-session state are independent; snapshots replace stale
rows and preserve catalog worlds. Startup subscribes before request; peer replacement/
exit detaches old subscriptions. Own active instance hidden, not the whole URL.

| Functions | Contract |
| --- | --- |
| `load_sessions` | Validates/replaces public summaries, groups exact URLs and rebuilds open cards/rows; no implicit join/create. |
| `receive_directory_result` | Accepts only current request/generation version-1 envelope while refreshing, then applies validated summary snapshot. |
| `classify_query` | Delegates explicit filter/url/code policy to pure discovery model. |
| `create_world_info_menue` | Opens content info for selected world and lists every eligible other public instance at that URL; legacy spelling retained. Buttons join exact session IDs. |
| `close_info_menu` | Releases info page and restores browser, no relay mutation. |

<!-- module: scripts/GUI/vr_gui.gd -->
### [VRViewport2D](../../scripts/GUI/vr_gui.gd)

Tool Node3D renders a SubViewport onto a locally duplicated quad/material.

| Functions | Contract |
| --- | --- |
| `raycast_to_viewport_point` | Intersects ray with UI plane and maps to viewport pixels; returns negative point when no hit. Caller checks bounds/visibility. |
| `inject_input` | Duplicates event, adjusts mouse position and pushes to viewport; caller supplies validated pointer hit, does not mutate original event. |

## Evidence and limits

Use [testing commands](../development/testing.md) and each suite's README for exact
fixtures. This contract set must be reviewed when behavior changes; coverage checks
only detect missing names/module sections, not whether prose is truthful. Known
manual boundaries remain XR/controller comfort, full-renderer meshes/shadows,
physical voice, arbitrary humanoid compatibility and Internet/large-transfer stress.
