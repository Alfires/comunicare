# VR controls and tracking: implemented behavior

Latest solver safeguards bound neck translation/head-wrist rotation and add local
terrain-aware foot contact (surface alignment, jitter hold, lift release). The
original avatar/camera remains independent. These conservative policies are not
complete per-rig anatomical constraints. See [validation status](../development/vr-validation.md):
automated checks are available, but no real-headset certification has been performed.

## Safety, teleport and expanded tracking

VR Movement now selects smooth or point-and-teleport locomotion. In teleport mode,
hold left stick forward to aim at a walkable surface within 8 m; a green marker
appears only for bounded height and capsule-clearance hits. Release to neutral
commits after revalidation; other input/focus/UI loss cancels. A short blink
accompanies commit. No local tracked headset transform is overwritten.

Capsule growth queries ceiling clearance first; shrinking remains permitted.
Default-enabled head-overlap fade queries a small sphere against world geometry.
The viewport Comfort preset explicitly sets snap, moderate speed, vignette/blink
and no jump; it does not silently change all unrelated preferences. Physical
boundaries and platform safety overlays remain runtime responsibilities.

Tracker setup now offers a cancelable three-second reference-pose capture. It saves
per-role tracker-to-avatar-bone translation/quaternion offsets, applied only to
calibrated available hips/feet. Match the avatar reference stance; reassignment
invalidates that role offset. This is a mounting calibration, not automatic body
measurement, safe-pose recognition or a guaranteed correct result on arbitrary rigs.
Stationary feet suppress sub-centimeter target jitter and release for deliberate
motion; this is not a world-contact/terrain foot-plant solver.

Negotiated tracking version 1 sends bounded root-relative head/hand/body targets
at 20 Hz within the active instance when sharing enabled. Toggle sharing under
VR Comfort. Relay checks actor/session/rate and expires pose after one second;
receivers interpolate matching avatar revisions and fade stale head/hands. No
tracker IDs, playspace mesh or durable pose history is sent. Old peers fall back
to resolved animation. Internet jitter/appearance remains a manual release gate.

Avatar source text field accepts a local path as a headset-accessible alternative
to a platform file picker; native filesystem browsing varies by runtime/platform.

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

The save action records current headset height and per-body-role mount offsets in
an account/avatar-scoped store. It is not an automatic anatomical calibration.
Invalid/corrupt/wrong-owner data is preserved, not overwritten. Rig chain warnings
are displayed. The optional solver accepts pelvis/feet subsets before head/arms.

Temporary head/hand validity loss fades last solved pose toward base animation over
.2 seconds; reacquisition fades in. Hard target removal releases ownership. Camera
remains independent; limb reach is bounded. Tests use synthetic poses, not physical
controller calibration or certified anatomical constraints.

## Remaining release work

Remaining quality/release gates: anatomical joint-limit/torso solving, world-ground
foot contact, arbitrary-rig automatic sizing, per-platform file browsing and runtime
controller/tracker profiles. Physical boundary safety and room-scale comfort cannot
be established by collision-unit tests. Real headset/controller, mirror/shadow and
large-network tests are required before release-quality claims. Current mount
calibration, target stabilization and interpolation are bounded initial policies,
not VRChat-equivalent body tracking or certified universal hardware support.

Tests: `python3 tests/vr_controls/run.py`,
`python3 tests/avatar_tracking/run.py`. Architecture and API details are in the
[function contracts](../reference/functions.md) and
[roadmap](../roadmaps/vr-controls-menus-ik-fbt-roadmap.md).
