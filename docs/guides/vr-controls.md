# VR controls and tracking: implemented behavior

- Left stick requests bounded analog head-relative ground movement. Head pitch/roll
  does not change speed. Right stick turns around the headset floor pivot, with
  Snap (30° default) or Smooth (60°/s default) in VR Movement settings.
- A/X on either hand toggles one shared main-menu viewport. Optional jump is right
  stick click and off by default; B/Y retains the separate emote wheel.
- Controller aim/trigger operates UI, with press capture/release on drag-off/close.
  Stick over the panel scrolls it. Text focus opens a pointer virtual keyboard;
  editable/read-only and length restrictions remain enforced. Close releases target.
- UI/focus/tracking loss blocks synthetic motion until controls return neutral.
  Comfort preferences offer optional vignette/blink, seated capsule mode and dead
  zones. No setting guarantees prevention of motion sickness or shifts headset pose.
- Room-scale following collision-moves the capsule toward the physical headset
  floor point, compensating origin so the headset world pose does not jump. Repeated
  stationary samples are idempotent; walls block capsule, not physical head motion.

## Tracker setup and calibration

Use **VR tracker setup** in the main viewport. Fresh positional poses actually
exposed by the active runtime are listed for hips/feet assignment; duplicate role
use is rejected and missing devices remain untracked. Assignments are session-local,
not hardware serial history. No claim that every tracker/runtime combination works.

The save action records current headset height and zero head/grip translations in
an account/avatar-scoped store. This is **not full-body orientation/T-pose calibration**.
Invalid/corrupt/wrong-owner data is preserved, not overwritten. Rig chain warnings
are displayed. The optional solver accepts pelvis/feet subsets before head/arms.

Temporary head/hand validity loss fades last solved pose toward base animation over
.2 seconds; reacquisition fades in. Hard target removal releases ownership. Camera
remains independent; limb reach is bounded. Tests use synthetic poses, not physical
controller calibration or certified anatomical constraints.

## Remaining release work

Full-body orientation/offset calibration and foot planting; robust torso/joint
constraints; ceiling-safe dynamic capsule growth; head-clipping feedback; safe
teleport; headset-accessible platform file selection; runtime hardware/profile
coverage; networked live tracker poses. Physical boundary safety and room-scale
comfort cannot be established by collision-unit tests. Real headset/controller,
mirror/shadow and large-network tests are required before release-quality claims.

Tests: `python3 tests/vr_controls/run.py`,
`python3 tests/avatar_tracking/run.py`. Architecture and API details are in the
[function contracts](../reference/functions.md) and
[roadmap](../roadmaps/vr-controls-menus-ik-fbt-roadmap.md).
