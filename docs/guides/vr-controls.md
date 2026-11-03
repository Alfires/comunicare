# VR controls and tracking: implemented behavior

- Left stick requests horizontal head-relative movement with radial dead zone and
  analog magnitude. Head pitch/roll does not change speed; diagonal input is bounded.
- Right stick turns around the headset's floor pivot. Settings → VR Movement selects
  Snap (default 30°, one per deflection) or Smooth (default 60°/s), speed/dead zones.
- Either lower face button A/X toggles one shared Home/Friends/Explorer/Settings
  viewport. A no longer jumps. Optional jump uses right stick click and is off by
  default. B/Y retains the emote wheel; menu/modal focus suppresses emote opening.
- Point with controller aim and click trigger; pointer release survives drag-off and
  close. Menu/input capture blocks synthetic movement/turning until sticks return
  neutral. Focus/head tracking loss blocks locomotion.
- VR Comfort offers optional vignette/snap blink and a seated short-capsule mode.
  Effects never move the camera and cannot guarantee absence of motion sickness.

The main menu surface is stable while open. It uses the existing service owners,
not duplicate settings/account data. Automatic viewport mouse-coordinate conversion
handles actual non-square size, front face, bounds and world transforms.

Tracking primitives validate required humanoid chains, store bounded per-owner/
avatar calibration and accept fresh uniquely assigned optional role samples. Head/
grip offsets are applied by the final modifier; optional pelvis/feet targets are
solved before head/arms. Device discovery/role-assignment/calibration UI is **not**
provided yet: the sample provider is an integration API, not certified plug-and-play
FBT. Tracking activation currently uses binary validity weights, not polished fades.

Remaining work: complete room-scale/collision policy; headset-ready keyboard,
scrolling and file selection; physical tracker/runtime profiles; foot planting,
body constraints, hardware calibration and multi-client tracker-pose replication.
Do not infer these from passing synthetic tests. Test on real devices before use
as a release-quality comfort or FBT system.

Tests: `python3 tests/vr_controls/run.py`,
`python3 tests/avatar_tracking/run.py`. Architecture and API details are in the
[function contracts](../reference/functions.md) and
[roadmap](../roadmaps/vr-controls-menus-ik-fbt-roadmap.md).
