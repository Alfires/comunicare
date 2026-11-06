# RED VR controls acceptance tests

Avatar resizing uses a shared capsule transaction for desktop and VR: preserve
the existing foot plane, set height before radius to avoid implicit clamping, and
reject final volume overlap before changing model/view scale or movement speed.
Regressions cover repeated shrink/grow cycles and rejection beneath a low ceiling.

Movement regressions cover partial desktop analog strength, consistent acceleration
at 30/60/144 physics Hz, focus-loss mouse input, and collision-shape change signals
under submillimeter VR height jitter. Desktop acceleration/braking use exponential
rate-independent weights; VR capsule changes under 5 mm are ignored to avoid noisy
shape rebuilds and clearance queries. These are behavior/workload assertions, not
a measured production FPS or real-headset comfort guarantee.

Desktop camera regressions additionally check render-frame translation between
physics positions, immediate pitch retention and teleport history reset. These
are deterministic transform assertions, not a visual blur/performance measurement.

**Implementation update:** this suite now passes **81 assertions**, exit 0, after
movement/turn/input/settings/pointer/comfort implementation. The red-baseline notes
below are historical. Physical XR visuals, virtual keyboard, scroll, full room-scale
collision and comfort quality remain outside these headless acceptance assertions.

**Intentionally failing, opt-in roadmap tests. No runtime implementation is added.**
Run `python3 tests/vr_controls/run.py`. Expected current result: exit **1** with
assertion failures for missing features; exit **2** means a broken test project,
Godot error or missing prerequisite, not a successful red baseline. Existing green
runners do not invoke this suite. `GODOT=/path/to/godot` overrides the executable.

The disposable Compatibility project under `/tmp/opencode` copies production
scripts, replaces all autoloads, and never instantiates the real player scene,
starts capture, loads an account, contacts a relay or opens an XR session.
The current input-scale check registers a synthetic XRControllerTracker input;
it does not override native XRController methods or use physical tracking.

Expanded baseline: **1 passed, 20 failed**, exit 1, without Godot errors. The guarded
future-component groups will expand their behavioral assertions once components
exist; the summary is therefore not the final implemented-system assertion count.

Coverage: current production double-speed input bug; planar head-relative direction,
pitch/vertical fallback, diagonal/dead-zone handling; snap latch/rearm and smooth
delta/pivot invariance; either-hand/simultaneous lower-button edge ownership;
registry/store comfort defaults and persistence; current A/jump conflict; main-menu
scene wiring. Source evidence checks are explicitly wiring checks, not UI behavior.

The roadmap did not prescribe helper class names. This suite proposes testable
interfaces for future components, guarded with exists/has_method so missing code
fails assertions rather than compilation:

- `scripts/player/vr_locomotion.gd`: `desired_velocity(stick, head_basis, speed, dead_zone)` → horizontal Vector3; maintains last valid yaw.
- `scripts/player/vr_turn_controller.gd`: `step(axis, delta, mode, snap_degrees, smooth_degrees_per_second)` → yaw radians (negative = right), `reset()`, `pivot_transform(rig_transform, floor_pivot, yaw)` → Transform3D.
- `scripts/player/vr_input_router.gd`: `menu_toggle(left_pressed, right_pressed, suppressed)` → one edge-triggered bool, `reset()`.

These contracts may be adapted with implementation evidence, not replaced with
passing empty stubs. Missing components stop only their dependent assertions while
independent settings/current-code tests still run. Proposed setting IDs/defaults
are product contracts for this suite, not claims they already exist.

Additional contracts:

- `scripts/GUI/vr_pointer_router.gd`: `hover(hand, pixels, hit_valid)`,
  `press(hand)`, `release(hand)`, `cancel()`, `drain_events()` → array of pending
  press/release dictionaries (`pressed` boolean). Hover is state only; drag-off
  release/cancel must release owned press exactly once.
- `scripts/player/vr_comfort.gd`: `update_vignette(speed_mps, turn_dps, delta,
  enabled)` → bounded obscuration strength, `reset()`. This tests state, not rendering.

The production `VRViewport2D` helper has a known Vector3 × Vector2 runtime bug.
A failing precondition assertion reports it without treating Godot errors as an
acceptable red baseline. Six real ray-mapping checks (non-square dimensions,
inverted Y, bounds, back face, parallel rays, transformed panel) are explicitly
blocked until that precondition is fixed. They are not counted as passed or as
executed assertions. No production fix is included here.

Guarded movement/turn groups now additionally cover analog magnitude, backward
motion, head roll, release, opposite snap rearm and multiple frame rates.

Later phases still need executable capsule/room-scale collision, actual menu
pointer/drag/scroll/keyboard interaction, vignette rendering, teleport validation,
tracker-driven input-loss and real-headset comfort/profile tests. This initial red
suite does not pretend to cover those or optional pose replication/FBT hardware.
