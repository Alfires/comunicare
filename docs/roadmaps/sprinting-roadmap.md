# Desktop and VR sprinting roadmap

## Status and scope

**Planned — 2026-11-04.** This document proposes sprinting; it does not claim
that sprint input or a speed boost is implemented. It extends the movement work
in [VR controls, menus, IK and FBT](vr-controls-menus-ik-fbt-roadmap.md).

Requested controls:

- **VR:** press and hold the **left joystick click** while moving the joystick.
  Tilting the joystick alone continues to walk; the right stick-click keeps its
  existing optional jump behavior.
- **PC:** press and hold **Ctrl** while moving with the existing movement keys.
- Release the sprint control to return to walking. Holding is the proposed
  initial behavior, not a toggle.

Proposed initial tuning is a **1.5× horizontal speed multiplier**: desktop's
current 3 m/s becomes 4.5 m/s; VR's default 2 m/s becomes 3 m/s. Preserve the
user's configured VR walking speed and multiply it rather than replacing it.
These are starting values subject to manual comfort/play testing.

No stamina, cooldown, crouch, new animation assets, camera bob, forced FOV
changes or new multiplayer packet is required for the first version.

## Current-code baseline

- `scripts/player/player_desktop_movment.gd` accelerates horizontal velocity
  toward exported `speed` (default 3.0), then uses `move_and_slide()`.
  Movement is gated by mouse visibility, but the movement loop does not yet
  consistently gate focus, rebinding and session transitions.
- `scripts/player/player_vr.gd` reads `vr.move_speed`, calls
  `scripts/player/vr_locomotion.gd::desired_velocity()` and accelerates toward
  its result. Existing focus, headset/controller validity, menus, emote wheel,
  session-busy and neutral-stick rearming rules must remain authoritative.
- `openxr_action_map.tres` already maps `primary_click` to the left and right
  thumbstick clicks for several controller profiles. Reuse the **left**
  controller's action; verify actual profile coverage on hardware.
- `scripts/settings/settings_registry.gd` and
  `scripts/GUI/settings_menue.gd` explicitly reject standalone modifier keys,
  including Ctrl. Adding only a `KEY_CTRL` setting would therefore fail.
- Both players already publish position/rotation when moving at approximately
  20 Hz. Remote movement does not require a separate sprint flag.
- `scripts/assets/animation_controller.gd::resolve_motion()` currently selects
  forward/back run only above 4 m/s; lateral movement selects strafe roles.
  Default VR sprint at 3 m/s would still select walk without an adjustment.

## 1. Shared sprint policy and input/settings support

- Add a small shared sprint policy under `scripts/player/` so the two players
  agree on multiplier, eligibility and suppression/reset behavior. Keep device
  polling in the respective player, not in the policy.
- Apply the multiplier once to the **target horizontal speed**. Do not repeatedly
  multiply current velocity or alter gravity, jump impulse, acceleration,
  friction, turning, physical room-scale motion or teleport range.
- Permit sprint in any movement direction; preserve diagonal normalization and
  VR analog magnitude/dead-zone scaling. Sprint without movement does not move
  the player. Keep current airborne horizontal steering, using the same target
  speed rule in air; sprint does not add vertical motion or a second jump.
- Add registry-backed `input.sprint`, action `sprint`, default Ctrl. Permit
  standalone Ctrl through an explicit per-definition modifier-key allowance,
  shared by registry validation and the rebind UI. Keep existing bindings'
  modifier restrictions, conflict detection, Escape cancellation, persistence
  and reset behavior unchanged. Verify InputMap installation, held/released
  Ctrl events and left/right Ctrl behavior rather than assuming ordinary-letter
  physical-key handling covers modifiers.
- Reuse left-controller `primary_click`; no XR action-map expansion unless
  profile verification reveals a missing binding. Do not introduce a keyboard
  action that inadvertently responds to the right controller's jump click.
- Initially keep 1.5× as one bounded shared tuning value, not a new persisted
  setting or another independently editable copy in each player.

**Acceptance:** defaults load successfully; Ctrl can be rebound/restored and
survives restart; ordinary shortcut validation is unchanged. Identical policy
inputs produce identical multipliers for desktop and VR.

## 2. Desktop integration

- Select walk/sprint target speed in `_physics_process()` before the existing
  acceleration calculation. Preserve collision handling and walking when Ctrl
  is released; decelerate through the existing movement model.
- Suppress locomotion/sprint when unfocused, mouse is released for menus,
  `SaveData.voice.input_blocked` is true (including rebinding), the emote wheel
  owns input, or `NetworkHandler.session_busy` is true.
- Clear sprint eligibility on suppression and require release of the sprint
  control before a new press can enable it. Closing a menu or regaining focus
  while Ctrl is held must not silently restart sprinting.
- Ensure Ctrl shortcuts in text fields and rebinding screens never accelerate
  the player. Do not persist held input state in settings or profiles.

**Acceptance:** moving plus Ctrl accelerates toward 1.5× walk speed, release
returns toward walking, and diagonals gain no extra speed. Suppression cannot
leave sprint latched; jumping and collisions retain their existing behavior.

## 3. VR integration and comfort

- Read `left_controller.is_button_pressed("primary_click")` only with valid
  left-controller tracking. Pass the effective speed into `desired_velocity()`.
- Combine sprint eligibility with the existing movement suppression/rearm rules,
  adding the rebinding/input-blocked gate where needed. After focus/tracking
  loss or a menu/session transition, require the existing neutral-stick rearm
  **and** release/repress of the sprint click before sprint resumes.
- Disable sprint in teleport mode. Switching locomotion modes clears sprint;
  teleport distance and physical room-scale movement are never boosted.
- Keep head-relative planar direction, snap/smooth turn behavior, collision
  safety and tracked head/hand transforms unchanged. Let the existing optional
  comfort vignette react to actual movement speed; do not force it on.

**Acceptance:** only left click boosts smooth locomotion, analog input retains
its proportional speed, right click retains optional jump, and missing tracking
or blocked input cannot activate or preserve sprint.

## 4. Animation and multiplayer integration

- Keep position/rotation replication and the single existing animation-state
  stream. Do not send raw Ctrl/controller state or add a parallel sprint stream.
- Make automatic walk/run selection aware of the player's effective walking
  reference speed instead of relying solely on the absolute 4 m/s threshold.
  Use actual horizontal motion with suitable hysteresis: holding sprint while
  stationary or pushing into a wall must not select run by input alone.
- Preserve strafe precedence, airborne roles, custom animation resolution,
  emote interruption and VR tracking/IK ownership. A faster strafe need not
  become a forward run animation; no new directional run assets are required.
- Verify remote clients receive the resolved movement animation through the
  existing stream and see faster position changes in the same instance.
- This is a client locomotion feature, **not** authoritative relay-side speed
  enforcement or a new anti-cheat guarantee. Preserve relay ephemeral-data and
  session-isolation rules.

## 5. Verification and delivery

Implement in small, independently passing parts, with failing regression tests
before each production change:

1. Shared policy and scoped Ctrl binding support, with settings/rebind tests.
2. Desktop integration, with synthetic input and isolated player physics tests.
3. VR integration, extending isolated VR controls tests without requiring XR
   hardware or touching real account files.
4. Animation/reference-speed integration and two-client movement verification.

Cover held/released input, no input, all directions, diagonal bounds, analog
dead zones, non-compounding speed, walking-speed changes, airborne movement,
blocked input, menu/focus/tracking loss, rearming, teleport mode and right-click
jump independence. Test sustained collision against a wall and run/walk
transitions near thresholds. Verify old saved settings gain the default binding
without losing unrelated values.

Run relevant isolated runners from the repository root:

```sh
python3 tests/microphone_settings/run.py
python3 tests/vr_controls/run.py
python3 tests/animation_sync/run.py
python3 tests/multiplayer_reliability/run.py
```

Extend runner fixtures for new production dependencies and add a focused desktop
or shared-sprint suite if the existing runners cannot exercise the real path.
Report actual pass/fail and skipped groups; these commands are proposed gates,
not recorded verification of an implementation.

Manual release gates: desktop Ctrl/rebinding and menu shortcuts; real-headset
left click while moving; tracking/focus recovery; comfort at configured VR
speeds; walls/slopes/jumps; and two clients (desktop + VR) observing movement,
walk/run/strafe transitions and uninterrupted tracked arms/body. Synthetic tests
do not certify controller portability, avatar visuals or VR comfort.

After each verified implementation part, use a Conventional Commit and publish
to the configured upstream. Update this roadmap/index with delivered behavior,
test results and remaining hardware gates; do not label proposals as complete.
