# Welcome island startup contracts

### Latest matrix/voice blocker — 2026-11-06

Matrix artifacts `/tmp/opencode/welcome-release-results-_gxysg0h` recorded 23/24
groups passing, including official Linux debug standalone export. Active Instance
failed one voice-delivery assertion and its avatar preview fixture lacked registry/
store dependencies. The fixture now supplies the real disposable settings owners;
that removes the preview errors without touching production account storage.
Voice failure persists: successful ENet queueing, matching session IDs, but zero
received raw voice packets on failing runs; one diagnostic run received all three
probes. Bounded multiprobe experiments did not consistently fix it and were not
used to weaken the original assertion. Raw packet counters/diagnostic assertion
text remain for investigation. No production transport fix or full release pass
is claimed. Rest/floor work passes 39 focused house assertions.

## Rest/floor alignment and measured desktop follow-up — 2026-11-06

Test-first rest cases failed before adding `rest_at`/`leave_rest`. Deliberate nearby
bed/sofa rest now checks reach and target/exit clearance, preserves tracked local
head transforms, suppresses synthetic physics walking, and restores the previous
processing state on leave. Duplicate rest is rejected; blocked exit uses a clear
center fallback. Returning home releases rest first; scene teardown clears rider
references and movement suppression. Controls settings offers explicit rest/leave
actions; there is no automatic sleep, time skip or forced lying-down rotation.
This is a service/UI-action implementation, not certified seated-headset comfort.

A new visual-alignment assertion reproduced the imported bungalow foundation
overlapping the app-owned accessible floor. The raised imported foundation is now
hidden while original GLB bytes remain unchanged. Visible doorway/window-shell
adaptation and simple collision still need human walkthrough review, not a claim
of exact decorative-mesh collision.

Forward Plus rendered sample on NVIDIA GTX 1070 / Vulkan 1.4.312: 60 render-loop
samples per fixed view after warmup. Median/p95 ms: spawn 8.294/8.955, overview
8.339/8.563, grove 8.318/8.635, underside 8.330/8.535. Reported video memory
386,221,792 bytes. These are small-window desktop event-loop intervals (potentially
vsync limited), not GPU-only timings, sustained load/thermal results or two-eye
headset budgets. Do not compare them directly to a certified 90 Hz XR budget.

Official 4.7.2 Linux debug template was restored to `/tmp/opencode` and SHA-256
verified against the previously recorded value. The earlier remote push blocker
is resolved; ordinary push reported the house commit up to date. Full local matrix
is rerun for this unit; required human XR/final-art gates are not waived.

## House/style asset replacement — 2026-11-06

New house/style assertions failed before acquiring replacements. The home now
integrates Innerscene's original CC0 bungalow GLB with individually downloaded
Poly Haven CC0 Sofa 02, Vintage Day Bed, Coffee Table Round 01 and Wooden Picnic
Table. The A-frame candidate was inspected but not bundled: its loft/steps were
a worse fit for single-level access. No island/environment preset was acquired.

The publisher's bungalow page and embedded GLB copyright explicitly permit use,
modification and redistribution under CC0. Source geometry stays unchanged;
runtime adaptation removes closed entrance/stair visuals and opens the front
facade for the tested broad entry. The original collision shell/interior layout
remains app-owned. A pitched tile roof, cream render, glazing, gutters and porch
details replace the visible three-wall blockout. Independent material overrides
subdue roof color; textured furniture replaces the bright low-poly lounge/beds/table.
Daybed scale is fitted by sleeping footprint rather than the old low bed height.

Asset checks: **518 passed**, with source counts: bungalow 14,796 triangles, sofa
2,728, daybed 2,715, round table 4,044, picnic table 10,210. Exact author/file/hash
and modification records are in the 16-entry island manifest and Credits inventory.
Godot-extracted embedded PNGs were byte-compared with the GLB buffer views before
listing them in provenance. Architecture textures are at most 2K; new furniture
maps use 1K. No source model is assumed safe to use as detailed collision geometry.

House/style checks (32 rendered checks after the final bed-source assertion),
layout 30, combined home 18, startup and Credits pass. Exported-PCK home/revision
passes. The earlier standalone template in `/tmp/opencode` was removed by environment
cleanup; the attempted rerun reports missing template, **not** a new standalone
pass. Previous standalone evidence is historical, not certification of these assets.
Screenshots at `/tmp/opencode/island-house-{outside,inside,left}.png` were inspected
during adaptation. Further final-art work, collision/visual alignment near decorative
windows, full production UI controls, headset comfort and named GPU/VRAM budgets
remain release gates. This improves the requested style but does not close all
remaining work merely by importing a better house.

### Restart follow-up — 2026-11-06

The second local matrix completed before the server restart: 23 of 24 groups
passed; Active Instance failed its same-instance voice assertion. A post-restart
isolated Active Instance run passed 132 assertions, with no skipped groups. This
is intermittent evidence, not a proven fix; no relay/voice behavior was changed
to obtain the pass. The restart removed the earlier temporary logs, so their
original completion report is the retained evidence, not invented log files.

The matrix now writes per-run logs and an incremental `summary.json` under a unique
`/tmp/opencode/welcome-release-results-*` directory instead of overwriting the last
run. It records exit codes, time, source revision/scope and outstanding manual
gates, including `release_ready: false`. Copy that nonprivate summary if it must
survive environment cleanup; temporary artifacts are not durable storage.

Forward Plus initial rendered landscape check passed on NVIDIA GTX 1070, Vulkan
1.4.312; fixture counts were 62–243 draws and 235K–441K primitives. Compatibility
views used Intel UHD 630. Neither measurement establishes frame time/VRAM targets
or XR readiness. The scene still needs a real final-art pass; landscape screenshots
must not be represented as satisfying the original naturalistic-home acceptance.

## Remaining-work integration — 2026-11-05

The eight kitchen items now use individual Kenney Food Kit CC0 GLBs/colormap,
preserving original hashes/license notice. Test-first authored-model checks failed
on all eight placeholders, then passed after acquisition/integration. Kitchen has
55 assertions including real counter settling. Source models are normalized with
simple collision proxies, not detailed hollow collision for cups/bowls.

Part 13 now has an **initial**, not final, landscape composition: 24 optimized
sapling placements, individual perimeter/underside rocks and trunk/border collision
proxies. Tests were red on missing landscape before construction. Rendered views
cover spawn/grove/overview/underside; initial Compatibility captures reported about
100–374 draws and 233K–440K primitives across views, with ~698 ms setup including
frame waits. These are scene counters, not reliable per-light GPU time or XR budgets.
Initial Forward Plus render also passed. Images still show sparse foliage and a
geometric edge/underside; final art acceptance remains open. No audio was added
without a cleared source. Route tests caught perimeter collision obstructing the
pond's dry loop; proxies were moved out and the pond test then passed.

`run_layout.py --acceptance` combines three home reloads with one persistent player,
Help/highlights disabled, authored kitchenware/reset, independent lighting and ship
board/reset; 18 assertions pass. `run_acceptance.py` runs all welcome groups plus
existing settings/discovery/instance/world/VR/startup/export checks into
`/tmp/opencode/welcome-release-results`. It never marks hardware checks passed.
The first matrix found a reproducible dry-perimeter failure (fixed) and an
intermittent active-instance voice assertion (two failed runs, one subsequent pass);
retain that history rather than hiding it with retries. The previously failing
settings status-bar assertion now passes with the concurrently updated UI fixtures.

Release remains blocked by real headset/controller/comfort, whole-map named-device
performance, visual-art quality and optional rest behavior. No available configured
OpenXR runtime can close human hardware gates here. See current
[home usage and limits](../../docs/guides/welcome-home.md).

## Part 12 optional Help — 2026-11-05

`python3 tests/welcome_island/run_credits.py --help-suite --rendered` tests the
production Settings Controls Help component with isolated settings and inert
network/data fixtures. Missing Help assertion failed before implementation.
Help starts collapsed; show/hide and highlight visibility stay session-local.
Live pickup/sprint/emote/mic bindings and VR mode/menu action are read from the
settings owner. No progress tracking, proximity lessons, task locks, arrival modal,
automatic microphone change or session creation is added. Gameplay services never
consult Help visibility. Existing reachable highlights can be hidden; no new
floating text or broad proximity lesson system is introduced.

14 rendered checks pass; source/world service regressions pass. A detached-page
settings callback found during regression was guarded. The microphone/settings
runner still reports an unrelated production `menue.gd` expecting `Shell` in its
old TabContainer fixture; the latest rerun no longer has that infrastructure error,
but still fails one unrelated status-bar microphone-position assertion (110 passed,
1 failed). Thus the full suite is not certified passing here. Actual headset
Help/controller readability and free-exploration user playtesting remain open.
Help is placed near the top of Controls, wraps inside the shared scroll area and
uses 44-pixel actions. Inspect `/tmp/opencode/island-help.png`; turn Help/highlights
off and verify house/ship/kitchen remain usable without any “tutorial finished” event.
Part 11's primitive kitchenware and art/XR limitations remain pending separately.

## Part 11 kitchen foundation — 2026-11-05

`run_layout.py --kitchen` initially failed on the missing kitchen, then passes
46 checks for the exact eight-item inventory (Cup, Bowl, Plate, Pot, Pan, Spoon,
Board, Canister), mass limits, shared pickup/drop/own-home reset, faucet/hob visible
state, door bounds/obstruction and appliance shutdown/reset on reload. The rendered
variant also captures `/tmp/opencode/island-kitchen.png`; image inspected. House
clearance 24, startup 68, settings regressions and standalone Linux debug export pass.

Sink/cooker/fridge are individual CC0 Kenney Furniture Kit models, with source
hashes and Credits records. The eight movable belongings are **temporary original
primitive models**, not the final premade kitchenware required by the design.
This is a functional foundation, not completed kitchen art or full part 11 acceptance.
No kettle, cooking sim, fire or damage is implemented. Faucet is a bounded visible
stream; hob has off/low/high visual indication, not actual heat simulation.

Controls are available through Settings → Controls and the existing local reachable
activation path. Door panels translate within bounded travel; obstruction prevents
movement instead of pushing through players. Reset does not force blocked doors
closed. Collision is simple proxy geometry; detailed handles, meaningful cup/bowl
interiors and seated physical reach need further work. Appliance state is client-local
and resets on reload; no global settings/account/network writes are introduced.

Manual procedure: with hints hidden, use water/hob/storage and every belonging,
carry/drop/place/reset on the counter, obstruct doors, then reload while appliances
are active. Require no stale holds, violent collision or blocked exit. Real-headset
seated reach and production pointer interaction remain open, as do final kitchenware
models/materials and complete door sweep/fixture visual polish.

## Part 10 adjustable room lighting — 2026-11-05

`run_layout.py --lighting --rendered` initially failed on the missing owner, then
passes 29 checks: three independent actual-light zones, on/off, 10–100% brightness,
warm/neutral selection, nonfinite/out-of-range/unknown-zone rejection, real control
signals and reset on home reload. Controls are in the shared Settings → Controls
page, with 44-pixel targets for desktop/VR pointers. State stays local; no settings
store, global renderer preferences or microphone state is written. UI input capture
uses existing settings/menu suppression; hardware pointer input is not simulated
by invoking widget signals.

Three nonshadowed OmniLight zones replace the single static fill. Each has a 7 m
range and bounded 0–2 energy. No strobe, real-time GI or extra shadow maps are added.
Warm/neutral are two documented palettes, not a calibrated Kelvin control. Rendered
off/dim/bright screenshots at `/tmp/opencode/island-lighting-*.png` inspected on
X11/Compatibility/Intel UHD 630; bright shows genuine light on beds, timber and
lounge. Runner reports draw/primitive/process metrics for the rendered fixture;
these are not isolated light GPU cost or a headset frame-budget certification.
House clearance 24 and existing settings 112 checks pass. Actual headset reach,
both-eye reflection/spill and whole-map GPU profiling remain open. No physical
wall-mounted dimmer or persistent home lighting preference is promised here.

## Part 09 house/side spaces — 2026-11-05

`run_layout.py --house --rendered` initially failed on the missing house. It now
passes 27 checks: lounge, two individual beds, kitchen reserve, roof/porch, side
benches/cushions/picnic/herb beds, capsule approach/exit and physical entry. The
full layout suite passes 30 checks after widening the doorway; its ground ray now
starts below ceiling height so roofs aren't confused with indoor walking floors.
Standalone Linux debug export, startup, asset import and Credits checks pass.

Our house shell uses individually assembled structure and existing cleared timber
textures. Ten individual Kenney Furniture Kit 2.0 GLBs are bundled (CC0), not a
furnished scene. Archive/mirror/source/hash and full notices are recorded in the
manifest/THIRD_PARTY_ASSETS. Bounds-derived uniform scale and simple collision
proxies keep original model bytes intact. Furniture is static for this part; no
forced sitting, lying pose, time skip, sleep progression or spawn change. Working
lighting/kitchen controls are parts 10/11. The interior has static warm fill only.

Rendered views at `/tmp/opencode/island-house-{outside,inside,left}.png` inspect
entry, resting places and both side compositions without hints. Floor/deck depth
overlap was corrected after first inspection. Actual headset reach/walkthrough,
final realistic furniture palette and landscape integration remain open. Optional
Sit/Rest/Leave is not implemented, so no synthetic pass is claimed for it.

## Ship/pond remaining-gate follow-up — 2026-11-05

New test-first failures exposed the sphere collision proxy missing bow corners and
the lack of an independent PBR hull finish. Replaced it with a hull-sized box,
translation sweep and four sampled yaw/position overlap checks; moved berth outward
to avoid dock overlap. This is a conservative proxy, not exact hull geometry or
continuous rotational collision. Instance-owned weathered-timber materials replace
the bright source palette without modifying the source GLB. Original author/license
records remain valid; runtime appearance modification is described in the manifest.

The water now uses a shore-clipped opaque mesh with modest world-space ripple
normals/color variation. No screen/depth texture, refraction, SSR, vertex displacement
or view bob. Shader changes are included in built-in revisions. Final natural
shore dressing and whole-map performance still belong to part 13, not this fix.

Ship tests now also invoke real ConfirmationDialog cancel/confirm signals, test
the bow obstacle and verify rider cleanup on ship removal. Rendered pond/ship
and official Linux debug standalone-load tests pass. Screenshots inspected on
X11/Compatibility/Intel UHD 630, not stereo XR. Dialog signals are automated, not
physical controller hit-testing or user comfort validation.

**Hardware blocker rechecked:** `/etc/openxr` and `~/.config/openxr` are absent.
No accessible configured runtime/headset can perform human two-eye, seated-reach,
boarding-view-transition or motion-comfort acceptance here. Those gates remain
unchecked. They require a person wearing a configured headset; synthetic viewports
or installing a headless runtime would not honestly close them.

## Part 08 ship and pond follow-up — 2026-11-05

`run_layout.py --pond --rendered`: 18 checks pass, including physical dock walking
and a shore-clipped water mesh without the old cylinder rim. This closes the
desktop fixture follow-up, not two-eye/headset rendering or final water art.

`run_layout.py --ship --rendered`: 20 checks pass. Initial missing-ship assertion
failed before implementation. Covers explicit nearby boarding, neutral rearming,
bounded propulsion/turning, supported root translation without forced view/head
rotation, invalid input/menu/focus stop, blocked/away-from-dock exits, stranded
reset and prolonged shore containment. Ship is constrained to a level water plane;
not a full buoyancy simulation. Collision uses a conservative sphere proxy plus
shore bounds; detailed rotating hull/corner collision remains a manual limitation.

Near the dock use Controls → “Board pond boat…” and explicitly confirm (or target
the hull with the existing interaction). Movement keys/left stick steer/throttle;
the menu exposes Stop, Leave at dock and Return to dock. Home state is local-only.
VR confirmation mounts in the shared menu viewport; production physical controller
hit-testing and comfort have not been certified. Desktop has a transient button
strip; VR uses shared Controls. Boarding preserves local tracking pose; no camera
roll/bob or forced yaw. No blink/comfort-transition certification is claimed.

Manual gate procedure: repeatedly board from dock in desktop and seated VR, start
only after neutral input, steer both ways, open menus/lose focus, return and exit;
verify no slide/jitter, local tracked offsets, immediate stop and accessible escape.
Inspect `/tmp/opencode/island-ship.png` and shoreline view; desktop image inspected.
Actual-headset tests remain unavailable, not silently passed. Layout 30, recovery
22, startup 68, assets 98, Credits 30, settings 112 and VR/sprint regressions pass.

Hull: Kenney Watercraft Kit 2.1 `boat-row-large.glb`, CC0, unchanged bytes plus
required colormap. Official download returned 403; retrieved from Asset Commons
mirror, matching archive hash and included Kenney license. See asset manifest and
THIRD_PARTY_ASSETS for exact records; runtime scale is 1.6. Final realistic hull
material/style adaptation is not complete. No complete environment preset used.

## Part 07 pond/dock — 2026-11-05

`python3 tests/welcome_island/run_layout.py --pond --rendered` checks the sealed
bed, bounded water, dry perimeter, accessible physical dock, twelve-metre clear
ship turning reserve, actual water-trigger recovery, repeated non-looping bank
returns and blocked-bank fallback. Production VR destination queries explicitly
reject water areas marked `teleport_disabled`. The suite initially failed on the
missing pond before production changes; 16 rendered checks now pass. Layout 30,
recovery 22, startup 68 and VR/sprint 106 + 63 assertions also pass; isolated Linux
debug export and eight-entry provenance validation pass.

The dock is our own assembled timber deck/planks/posts using the previously cleared
Weathered Planks CC0 maps; no newly downloaded models or environment presets. Water
uses one opaque standard-material surface, no SSR, refraction or depth-reading
shader. It is a deliberately inexpensive visual baseline, not final water realism.
The bed stays part of the original continuous island. Ship is not implemented here.
The picnic pickup blocks were moved beside the route after layout regressions
showed they obstructed its walking corridor.

Manual view: camera `(4,8,38)` toward `(23,-0.5,23)`, screenshot
`/tmp/opencode/island-pond.png`; inspect bank contact, dock-to-bank continuity and
readable water edge without SSR. Actual-headset two-eye water/shore and dock
traversal checks remain open; rendered Compatibility is not XR validation.

## Follow-up: carry obstruction and standalone export — 2026-11-05

Two new assertions reproduced held objects crossing a wall and dropping on its
far side. Local carry now sweeps each collision shape using its original mask,
checks the destination overlap and retains the last safe transform when blocked.
This also rejects nonfinite hand transforms. Held-player collision remains disabled;
drop restores original collision at the safe pose. Rotation uses endpoint overlap
checks, not a continuous rotational sweep; complex rotating cookware still needs
manual testing. Remote relay-authorized carrying is unchanged.

`python3 tests/welcome_island/run_interactions.py --rendered`: **85 passed**, including
30 carry/drop repetitions; screenshot inspected at `/tmp/opencode/island-carry.png`.
This fixture render is a basic sphere/camera view, not production-headset validation.
World safety/example/real UDP suites: **126 + 25 + 16 passed**. Recovery: **22 passed**.

Standalone export now passes using a matching **official Godot 4.7.2 Linux debug
x86_64 template**, extracted to `/tmp/opencode` without modifying installed templates.
The exact template SHA-256 is
`1a291d3d15e4180b60b0af96cf6458f11fe143636d76575ddf1e23d1a3f24f2e`.
Source: <https://downloads.godotengine.org/?version=4.7.2&flavor=stable&slug=export_templates.tpz>.
Only that archive member was downloaded via HTTP ranges; archive CRC was checked.

```sh
python3 tests/welcome_island/run_export.py --template /tmp/opencode/godot-4.7.2-linux-debug.x86_64
```

The disposable standalone binary runs its actual main scene (no editor-only path
override), loads home and verifies the expected revision after source unmounting.
Pack-host mode without `--template` also passes. This closes the isolated Linux
debug standalone-load gate, **not** production dedicated-server export, release
template/platform coverage or Forward Plus/XR certification. Actual headset access
remains unavailable (no configured OpenXR runtime); comfort/reach gates stay open.

## Part 06 offline interaction and open-gate follow-up — 2026-11-05

`python3 tests/welcome_island/run_interactions.py` tests trusted local activation
on the existing pickup controller without accounts/network: pickup, carry/drop,
collision restore, duplicate grip, wall/reach rejection, activation, reset,
left/right/virtual anchors, cancellation and cleanup. Missing `activate_local`
failed before implementation. Remote `activate` never enables local authority.
Home has two temporary pickup blocks and a fixed lamp switch at the picnic reserve;
these are graybox fixtures, not final props. Desktop uses the saved world-grab
binding; VR uses the existing grip threshold. Grab precedes activation, so the
fixed switch is not pickupable. Controls settings explains local-only home state.

Evidence: 21 interaction assertions; world safety 126, example 25 and real-UDP
example 16 checks; microphone/settings 112; VR/sprint 105 + 60; startup 68 passed.
Manual procedure: approach picnic objects, aim/reach and use the saved action,
carry/drop, open menus/lose focus while holding, reset/fall and change world.
Require reachable-only highlighting, no violent collisions or stale hands/objects.
Actual controller reach and rendered carry stability remain open.

`run_layout.py --recovery --rendered` now passes 26 assertions, including three
camera-root recoveries; screenshot inspected at `/tmp/opencode/island-recovery.png`
on X11/Compatibility/Intel UHD 630. `run_export.py` exports a disposable PCK,
unmounts source paths and verifies home load plus pre-export revision. It initially
failed with an empty revision, then passed after fixing source/editor detection.
The host is the installed editor executable, **not a standalone export template**.
The template directory is empty and no OpenXR runtime configuration was found;
standalone binary and real-headset recovery/reach/comfort gates remain blocked.
No production export preset or real account is used by these checks.

## Part 05 recovery/revisions — 2026-11-05

`python3 tests/welcome_island/run_layout.py --recovery` runs direct-load spawn,
repeated deferred fall recovery, menu-style trusted return, item-specific homes,
linear/angular motion reset, nonfinite-home rejection, stale-item reference cleanup
and unchanged synthetic local head transforms. The initial run had four clean
failing assertions before production changes. Unknown lost rigid bodies are
removed, not teleported onto the player. Register known items explicitly before
letting them fall; there are no pickup items in the graybox yet.

`python3 tests/public_discovery/run.py` now includes five real DataLoader home
stage/activation/mismatch checks, plus all previous discovery checks. Its fixture
copies the new built-in dependency sources and circular-value UI dependency.
The earlier missing-fixture blocker is resolved; 66 contracts and 24 startup
assertions passed, with no skipped group. Active Instance: 132 checks plus the
visibility group passed. Startup: 68 passed. Credits: 29 passed after adding the
four realistic texture sets. These are source/Compatibility checks, not XR proof.

Before local export, run `python3 tools/assets/build_home_revision.py`, then
`python3 tools/assets/build_home_revision.py --check`. The checked-in JSON lists
sorted source hashes for the wrapper, reset script, island scenes/scripts and all
bundled island payloads (conservative coverage includes presently unused samples).
Source/editor runs recompute listed file hashes to catch edits immediately. Export
runtimes use these pre-export hashes because Godot remaps/converts resources.
**Rebuilding/checking before export is required**; no export hook is installed and
an exported binary built from a stale manifest has not been certified. Tests mutate
a script/subscene/texture in the disposable copy and prove revisions change, while
an unrelated file does not. Downloaded-world validation/session admission is unchanged.

Remaining manual gate: in disposable desktop/real-headset sessions repeatedly fall
and return home, including DataLoader world transitions; confirm stopped motion,
one root player and no forced head rotation. The tests preserve synthetic local
head offsets but do not certify real XR comfort, rider/bed recovery or physical
capsule placement for every user height. Rendered texture/layout views were inspected;
no rendered or physical recovery test is claimed complete.

## Part 04 layout graybox — 2026-11-05

Run `python3 tests/welcome_island/run_layout.py` (optional `--rendered`). The runner
copies only the built-in world/layout into a disposable Compatibility project, with
no account, capture, player, relay or autoload. It checks the preserved scene UID,
middle spawn at `(0, 1, 0)`, level ground/capsule clearance, a physics-sampled
connected landmass, reserved house/deck/garden/pond/dock/grove/picnic areas and
broad dry routes. Each route is densely sampled for slope and standing clearance,
then traversed by an actual CharacterBody capsule at 4 m/s. Wall/off-island negative
controls verify queries reject invalid space. This is synthetic teleport-target
clearance, **not** production VR teleport input or real-headset certification.

Test-first baseline failed on the missing island layout before production edits;
the legacy panel also emitted its known resource-leak errors (runner exit 2, not
a clean red baseline). After replacement the route tests caught a house wall
crossing and pond-bank encroachment; both failed assertions were fixed before
verification. Current result: 30 headless-equivalent assertions plus four rendered
captures, all passing; startup's 68 assertions also pass against the new layout.

Composition procedure written into the suite: center at `(0,1.7,0)` toward the
house, elevated overview and views from both sides. Inspect screenshots at
`/tmp/opencode/island-layout-{overview,center,left,right}.png` for one landmass,
open center and several freely reachable destinations, without tutorial labels
or a required ordered circuit. These are graybox views, not final art. Rendered
X11/Compatibility on Intel UHD 630; actual VR traversal and final Forward Plus
renderer checks remain open. No water/ship/furnished house, collision recovery
redesign, downloaded assets or vegetation are claimed here.

Additional regression attempt: `python3 tests/public_discovery/run.py` exited 2.
It printed 61 passing contract assertions but could not compile a real coordinator
dependency because its fixture omits `scripts/GUI/circular_value_control.gd`, now
preloaded by concurrently edited emote UI. Its second startup group did not run;
this is not a full discovery pass and was not bypassed for the layout change.

The old world-mounted VRPanel was only a camera-display surface, not the player
menu, and is absent in the new world. Startup now tests the full new world with
no panel exclusion; the runner keeps its conditional legacy stripping for older
fixtures. The old reset area's bounds are moved below the deeper underside, but
its reset policy remains unchanged until part 05. Edge safety/final landscaping
remain later work; this graybox is not release-ready.

## Part 03 Credits and optimization verification

Run `python3 tests/welcome_island/run_credits.py` (optional `--rendered`) for the
production Settings page with inert network/data fixtures and disposable settings.
Only local manifests/licenses are copied; tests never open a browser. The source
handler is disconnected before testing explicit source-request emission.
Missing/malformed entries/licenses, complete manifest display, attribution,
expand/collapse, keyboard focus, scrolling, selection and unchanged settings-file
hash are covered. Desktop and 800×600 viewport sizes are checked; this is not
real headset pointer/comfort certification.

Test-first evidence: Credits navigation failed before implementation; four runtime
model existence assertions failed before optimization. Current checks: 25 Credits
assertions, 70 asset assertions, 13 Python provenance methods and 112 settings
regressions pass. Rendered screenshots inspected at `/tmp/opencode/welcome-credits.png`
and `/tmp/opencode/welcome-assets.png`; no private data is included. Actual headset
navigation and whole-map GPU budgets remain open. Manual procedure: open Credits,
expand full terms, scroll with controller and keyboard/pointer, switch categories
and re-render; require readable notices, no reset action, and no network activity
until an explicit source click.

Part 02 adds separate offline provenance and disposable asset-import checks:
`python3 tests/welcome_island/test_provenance.py`,
`python3 tools/assets/provenance.py`, and
`python3 tests/welcome_island/run_assets.py` (optional `--rendered`). See
[asset acquisition/inspection notes](../../assets/welcome_island/README.md).
These do not change the startup runner's fixtures or claim final runtime asset
optimization. Provenance fixtures were run red before the validator existed;
the asset suite initially failed on the missing manifest before acquisition.

Run from the repository root:

```sh
python3 tests/welcome_island/run.py
python3 tests/welcome_island/run.py --suite desktop
python3 tests/welcome_island/run.py --suite xr
python3 tests/welcome_island/run.py --suite account
python3 tests/welcome_island/run.py --suite desktop --rendered
```

Override Godot with `GODOT=/path/to/godot`. Missing Godot, import errors, unexpected
engine errors, timeouts or missing completion markers exit **2**; failed assertions
exit **1**; complete passing selected groups exit **0**. A selected group is not
the whole suite. The account group expects exactly one invalid-key parsing error
and one exact production recovery report; no other `ERROR:` output is ignored.

## Isolation and scope

The runner creates and deletes a disposable project under `/tmp/opencode`. It
copies production startup, settings/profile/voice ownership, required protocol
validators and built-in world terrain/environment/reset code. Every group has
fresh XDG user data. All keys are generated fixture keys or deliberately invalid
fixture bytes; no real key is copied. No real capture node is mounted; the audio
driver is Dummy. A network fixture has no sockets, HTTP or DNS and holds its
completion signal until the tests release it. Thus the network is blocked by
construction, not a claim about operating-system firewall rules.

Player scenes are small menu/camera probes, not production movement, avatar or
microphone scenes. The XR group overrides only startup's `_initialize_xr()` and
tests production selection/mounting using a synthetic successful result; it does
not initialize an XR runtime or certify controllers, tracking or headset comfort.
The desktop group uses production `--non_vr` selection. Real SaveData loads an
existing disposable key or rejects corrupt bytes; successful first-time key
generation is outside this suite.

The copied world omits the legacy world-mounted `VRPanel` subtree. Repeated
unloading of that panel exposed viewport-texture/material resource leaks; the
production panel is unchanged and this suite does not certify its lifecycle.
Remaining built-in terrain, sky/light and reset signals are copied unchanged.
No island content, DataLoader world revision or fall-recovery redesign is included.

Complementary integration check (full production autoloads/player/menu, but a
world-shell fixture, XR off and an absent loopback relay):

```sh
python3 tests/real_ui/run.py --suite startup --rendered
```

That runner retains temporary artifacts including disposable private keys; do not
publish its entire artifact directory. See its own README for isolation limits.

## Test-first evidence — 2026-11-05

Before production changes, executable desktop checks confirmed initial home
loading and hit-tested menu input while network completion was withheld, then
failed **three repeated-startup single-player assertions**. Re-entering startup
mounted another root-level player each time. Re-loading the same CryptoKey also
produced alternating key-parse/recovery errors. Fixture/import mistakes were
fixed before interpreting these behavioral failures. Legacy panel leaks were
isolated rather than suppressed by broad error filtering.

The fix reuses the root-level player on startup re-entry without reloading its
account or restarting relay setup. XR initialization was extracted into one
private method so synthetic selection exercises the same production mount path.

Recorded verification on Godot 4.7.2:

- New runner: **68 passed, 0 failed**, all three groups executed, none skipped.
- Rendered desktop group: **24 passed, 0 failed**; screenshot inspected at
  `/tmp/opencode/welcome-foundation-desktop.png` (outside version control).
- Microphone/settings: **112 passed**, zero failed/dependent groups skipped.
- Public discovery: **61 contracts + 24 startup checks passed**.
- Existing rendered production startup suite: **5 passed, 0 failed**.

Counts are evidence for this change, not a permanent baseline. Both rendered runs
used X11/Compatibility, Mesa Intel UHD 630, not Forward Plus/Jolt or real XR.
Mesa also reported failed NVIDIA DRI initialization before using Intel successfully.
Local documentation links/contracts passed. The startup declaration inventory was
updated and checked against its source. The repository-wide inventory check still
reported drift in concurrently edited `emote_wheel.gd`, `xr_emote_wheel.gd` and
`animation_controller.gd`; those unrelated changes/inventory entries were not
included in this unit.

## Rendered offline-start procedure and remaining gates

1. Run the rendered desktop command above from the isolated runner, not the main
   game. Require the cold-cache and pending-network assertions to pass.
2. Check that terrain and the menu probe actually render in the screenshot. The
   test injects pointer motion/down/up at the button rectangle and requires a
   resulting click; an output message alone is not menu readiness evidence.
3. Require exactly one persistent player after three startup re-entries, unchanged
   key bytes, retained mute and no capture node. Network completion must not gate
   the first rendered home or working menu probe.
4. Run the complementary production startup command; require real player/menu
   readiness before the absent relay timeout and successful cancellation.
5. **Open manual gate:** repeat production-player offline start/menu and world
   return on an actual headset with a disposable profile, unavailable relay and
   capture kept muted. Check tracked offsets, comfortable view and one player.
   Synthetic XR does not satisfy this gate. Legacy panel unloading and the full
   Forward Plus/XR stack also remain unverified by this work.
