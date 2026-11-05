# Welcome island startup contracts

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
