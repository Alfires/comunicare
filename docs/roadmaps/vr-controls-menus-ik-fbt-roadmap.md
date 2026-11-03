# VR movement, controls, menus, bone mapping, IK and FBT roadmap

## Status, scope and interpretation

**Planning only.** This roadmap builds on the existing OpenXR player, radial emote
wheel and initial local head/arm solver. It does not claim finished controller
movement, complete VR UI, hardware-tested IK or full-body tracking (FBT).

**Test-first update:** opt-in red acceptance suites now exist at
[`tests/vr_controls`](../../tests/vr_controls/README.md) and
[`tests/avatar_tracking`](../../tests/avatar_tracking/README.md). Initial verified
baselines are 1 pass/17 failures for controls and 2 passes/6 failures for tracking,
both exit 1 without Godot errors. Their READMEs specify proposed helper interfaces,
conditional assertion groups and remaining gaps. No runtime implementation is
added by these tests, and normal green test/tooling entry points do not run them.

Required experience:

- Left joystick moves relative to the headset's **horizontal facing direction**.
- Right joystick turns direction, with selectable **snap** or **smooth** turning.
- Either controller's **lower face button** opens/closes the main menu: default
  **left X / right A** on common Touch-style controllers, using the existing
  `ax_button` action. Other interaction profiles need equivalent remappable bindings.
- Settings expose VR locomotion, controller mappings, comfort, calibration and
  optional FBT controls. Comfort features reduce common triggers; they cannot
  guarantee prevention of motion sickness.
- Avatars use validated humanoid bone maps, calibrated tracking targets and IK.
  Head plus two controllers works without extra trackers; supported extra trackers
  improve body pose without making them mandatory.

Keep desktop behavior, shared mute, account ownership, first-person camera
independence, same-instance authorization and relay privacy intact. This is not
a plan for climbing, vehicles, combat, remote desktop input or unrestricted world
scripts to control the camera.

## 1. Verified baseline and gaps

| Area | Current code | Gap / correction |
| --- | --- | --- |
| VR rig | `scenes/player/player_vr.tscn`: CharacterBody, XROrigin, camera, both controllers/MenuAnchor nodes | Capsule fixed at 2.6 m; no complete calibrated room-scale body/origin policy |
| Movement | `scripts/player/player_vr.gd` reads left `primary`, multiplies input by movement_speed, applies full camera basis, then scales speed again | Head pitch/sign handling and double speed scaling need correction; frame-independent acceleration/friction and normalized diagonal motion need tests |
| Turning | Exported turn_speed exists | No implemented right-stick snap/smooth turn controller |
| Menu buttons | Both hands can open radial emotes using configurable B/Y or menu action | Main-menu open/close is absent from VR rig; right A/X currently jumps, conflicting with requested menu default |
| UI | `scripts/GUI/vr_gui.gd` maps rays to a SubViewport quad; shared 2D menus already exist | VR player scene does not instance the shared main menu; pointer capture, keyboard/focus, scroll and remap need end-to-end wiring |
| Tracking | `scripts/assets/avatar_tracking.gd` final head alignment and two-bone arms | Initial rest calibration only; no torso/root fitting, foot solver, tracker-role assignment or FBT support |
| Bone map | DataLoader extracts VRM humanoid metadata; animation retargeting uses rest bases | Rig validation/reporting, optional mappings, per-avatar calibration and unsupported-rig fallback need explicit contracts |
| Networking | Body PlayerData plus version-2 resolved animation/asset protocol | No networked head/hand/FBT pose stream; local IK must not be described as remote tracker synchronization |
| Comfort | Wheel size/dead zone/haptics settings exist | No locomotion/turn/vignette/seated/teleport comfort system |

The existing [avatar/emote plan](automatic-avatar-animation-roadmap.md) governs
source-only setup, eight-sector nested/paged wheel and B desktop shortcut.
The new lower-face main-menu bindings must not replace or duplicate emote inputs.
Current [camera/tracking decisions](../decisions/0003-avatar-view-and-tracking.md)
and [function contracts](../reference/functions.md) remain reference inputs.

## 2. Input action ownership and controller bindings

Introduce a small VR input router with semantic actions: `move`, `turn`,
`toggle_main_menu`, `toggle_emotes`, `ui_point`, `ui_confirm`, `ui_scroll`,
`ui_back`, `jump` (optional) and `recenter` (explicit). Route from OpenXR action
map/profile bindings, not literal key labels scattered across player scripts.

| Default | Action | Policy |
| --- | --- | --- |
| Left stick XY | Head-relative ground movement | Radial dead zone, normalized magnitude; optional handedness swap |
| Right stick X | Snap/smooth yaw | Y does not unexpectedly pitch camera; independent turn dead zone |
| Left X / right A (`ax_button`) | Toggle main menu | Either hand, rising edge only; held button never repeats |
| Left Y / right B (`by_button`) | Existing emote wheel | Preserve hand-local wheel and independent desktop B shortcut |
| Trigger click / aim pose | UI select / ray | UI capture consumes click before gameplay |
| Stick Y / supported scroll input | Scroll focused UI | Only while pointing/within UI capture |
| Unassigned by default | Jump | Remove existing right A jump conflict; optional explicit remap |

- Simultaneous left/right menu presses toggle **once**, not open and immediately
  close. Require release before another toggle. Use one menu owner/service.
- Build profile-specific fallback labels and binding availability. Do not intercept
  runtime-reserved System buttons or assume every controller has A/X/B/Y. Reuse
  existing mapped actions where suitable; add explicit profiles only when supported.
- Rebinding validates conflicts per hand/context, persists locally through the
  settings registry and provides reset/cancel. Never silently steal jump/emote/UI
  input. Changing a binding requires current buttons/sticks to return neutral.
- Focus loss, disconnect, tracking loss and scene changes clear latched actions.
  No ghost movement, repeated snap or held UI press may survive reconnect.

## 3. Movement, collision and room-scale alignment

Separate desired input, horizontal velocity, gravity and tracked headset pose.

```text
raw left stick → radial dead zone/remap → clamped input vector
head forward projected onto floor plane → horizontal forward/right basis
desired ground velocity → acceleration/friction → collision move_and_slide
room-scale headset displacement → capsule/origin reconciliation
```

- Use `-camera.global_basis.z` projected onto the horizontal plane, normalize it,
  and derive right consistently. When looking nearly straight up/down, use last
  valid horizontal yaw. Head pitch/roll must not move the body upward, change speed
  or reverse forward. Apply movement_speed exactly **once**.
- Clamp diagonal magnitude to one; retain analog speed below full deflection.
  Acceleration/deceleration use delta-safe limits, not `lerp` weights above one.
- Gravity/ground checks remain independent of movement direction. Menu opening
  removes requested translation and synthetic turning; existing momentum should
  decelerate safely rather than tunnel/teleport. Define jump/fall/respawn limits
  and zero outgoing stale motion during acknowledged world transitions.
- Capsule follows horizontal headset room-scale position with collision checks;
  do not force the physical headset back to a bone or recenter every frame.
  Compensate XROrigin offsets when moving capsule so the real view does not jump.
  Compute capsule height from calibrated standing/seated eye height with safe
  bounds and ceiling checks. Physical walking and joystick motion must not be
  counted twice.
- Head/world clipping triggers an optional comfort fade or safe warning; never
  silently push the camera through geometry or override runtime boundary systems.
- Body/avatar yaw can follow the movement/head policy with bounded smoothing;
  do not continuously rotate the visual torso to every small head motion.

**Acceptance:** yawed/pitched headset fixtures still move at the selected speed
along the floor; diagonals/frame rates are consistent; slopes/walls/ceiling and
room-scale offsets do not create camera jumps or wrong-world packets.

## 4. Snap and smooth turning

- **Snap default:** proposed 30° steps, activation threshold 0.7, release/rearm
  threshold 0.3. One step per deflection; no repeat while held by default. Optional
  held-repeat must have an explicit delay/interval and never run on menu capture.
- **Smooth:** bounded configurable yaw rate (proposed 60°/s default, 15–180°/s
  range), analog magnitude and dead-zone remapping. Apply delta once.
- Rotate the locomotion rig about the headset's current **floor-projected pivot**,
  compensating body/origin position. Rotating around capsule/model origin must not
  swing a room-scale-offset user through space. Headset local tracking stays intact.
- Switching mode, opening UI, losing focus/tracking or respawning clears turn
  latches and pending smooth input. No accumulated turn is applied on close.
- Optional brief snap blink/fade uses an accessible overlay; never black out for
  extended periods or hide runtime safety UI. Physical head turning remains free
  in both modes; no artificial camera pitch/roll/bob.

**Acceptance:** one held snap produces one exact step; release/redeflect works;
smooth turn matches expected angle at varying frame rates; head pivot position
stays fixed and neither mode turns while menu/input context blocks it.

## 5. Main menus usable from either hand

- Instance the existing Home/Friends/Explorer/Settings UI into a dedicated VR
  SubViewport/world-space surface, not a second copy of settings/profile services.
  Lower button on either hand opens the same main menu at a comfortable distance
  using invoking-hand placement and headset-facing yaw. Keep placement stable
  while open; no screen chasing the user's head each frame.
- Reuse MenuAnchor nodes as placement inputs, not as constantly moving camera
  parents. Opening from the other hand transfers pointer ownership or closes by
  explicit toggle; it must not create two menus/subscriptions.
- Point using aim pose; transform plane hit by the actual quad dimensions/pixel
  size (current helper's fixed 0.5 scaling needs verification for non-square UI).
  Reject out-of-bounds/behind-plane rays. Maintain hover/press/release capture so
  dragging off a control or closing a menu cannot leave a pressed button.
- Support trigger confirmation, scroll, Back, sliders, long text and virtual or
  runtime keyboard entry for URLs/keys. Do not depend on desktop mouse capture or
  a native file dialog that is inaccessible inside the headset; provide safe
  text/path fallback and explain platform file-selection limits.
- Main menu has input priority over locomotion/emote opening. Emote wheel remains
  its own eight-sector contextual picker; opening one closes/suspends the other
  with no accidental emote selection. Preserve typing/mute shortcut suppression.
- Close/focus loss/tracker loss/eviction/world change releases pointer captures,
  keyboard/modal state and subscriptions exactly once. Restore locomotion only
  after sticks return neutral. Provide adjustable menu scale/distance/handedness.

**Acceptance:** A or X opens/closes one working Home/Settings menu, can change
turn/comfort preferences and enter a URL, and closing never jumps, moves, turns,
selects a dance or unmutes the microphone.

## 6. Comfort and accessibility settings

Add registry-driven categories **VR Movement**, **VR Comfort**, **VR Controls** and
**Avatar Tracking** (names proposed). Use existing typed store/save/reset/UI,
apply before movement begins, and include units/descriptions. No parallel per-menu
settings state. Offer Comfort/Balanced/Custom presets as explicit bulk changes;
changing an individual value marks Custom without overwriting unrelated settings.

| Proposed setting | Initial behavior |
| --- | --- |
| Turn mode / snap angle / smooth rate | Snap by default; 15/30/45° options, bounded smooth rate |
| Movement speed / acceleration / deceleration | Conservative speed, finite bounded values; same physics units as desktop |
| Move/turn dead zones and handedness | Validated analog thresholds and stick-role swap |
| Locomotion mode | Smooth ground motion; optional point-and-teleport comfort alternative in a separate tested phase |
| Movement/turn vignette | Optional adjustable peripheral reduction with bounded fade strength/speed |
| Snap/teleport blink | Optional short transition overlay, never manipulating tracking pose |
| Seated/standing and eye-height calibration | Explicit calibration, safe capsule adjustment, recenter button |
| Head bob/camera shake/artificial roll | Disabled in VR; imported animations never drive camera |
| Menu scale/distance and reduced UI motion | Stable readable placement; no mandatory animated menus |
| Haptics intensity/disable | Optional bounded feedback; respect current emote preference/migration |
| Jump enabled / binding | Off or unassigned by default; never conflicts with lower-button menu |
| Tracking smoothing/prediction | Small bounded body/limb-only filtering; never add latency to runtime headset camera |

Comfort preset: snap turning, moderate movement speed, optional vignette available,
no camera shake/forced pitch/idle bob, no jump binding. Avoid promising “anti-sickness”
as a cure; label effects and allow users to disable them. Pause and remove synthetic
motion when session focus is lost. Teleport, if delivered, needs valid destination,
nav/collision/height checks, preview/cancel, one acknowledged body relocation and
the same head-pivot/camera safety rules—not a raw world-space camera translation.

## 7. Bone mapping and calibration

Create a rig adapter independent of controller hardware and animation source:

```text
VRM metadata / approved local mapping → validated humanoid roles/rest transforms
OpenXR pose provider → tracked role targets + valid/age/confidence flags
calibration → user-to-avatar scale/offsets + controller grip/aim convention
animation base → pelvis/torso fitting → limb IK → tracked overrides → final pose
```

- Prefer VRM 0.x/1.0 declared mapping. Validate duplicate roles, parent chains,
  zero-length bones, finite transforms, handedness/rest axes and required head/
  shoulder/arm/hand/leg hierarchy. Missing optional fingers/chest does not break
  the entire avatar; missing required chains disables that solver with a report.
- Provide owner-local mapping review/override for compatible generic humanoid
  models. Never infer identity solely from display bone names or silently accept
  an arbitrary nonhumanoid skeleton. Keep original rest pose and animation maps.
- Per-avatar calibration includes eye/head offset, arm lengths, floor, pelvis
  height, avatar scale and grip-to-hand orientation. Handle legacy VRM forward
  convention explicitly. Scale avatar/targets, not the tracked camera world scale
  without a deliberate comfort policy. Show reach/height warnings, not forced stretch.
- Save versioned account/avatar-hash scoped calibration, not raw hardware serials
  or last tracked poses. Avatar changes invalidate incompatible calibration; failed
  calibration keeps previous valid data. Provide reset and clear status.

## 8. Head/hands IK first, then optional FBT

### Three-point tracking baseline

- Keep final SkeletonModifier ordering explicit after base animation: pelvis/root
  fit, spine/neck correction, shoulder/arm solve, then head/hand orientation.
- Use calibrated controller grip offsets and stable elbow poles/joint limits;
  prevent elbow flipping at straight-arm/near-target singularities. Reach clamps
  with bounded shoulder assistance, not arbitrary limb scaling.
- Headset drives avatar head target; torso shares rotation within limits instead
  of stretching head translation away from spine. Camera remains independent.
- Only valid tracked chains override animation. Without controllers, hands/arms
  blend back to safe animation; no stale last pose held forever. Finger animation
  remains until valid finger tracking exists. Smooth reacquisition without snap.

### Full-body tracking phase

- Enumerate only trackers actually exposed by the active runtime/providers. Define
  a provider interface for head/hands and optional waist/feet/knees/elbows/chest;
  capability detection is mandatory. Do not promise every SteamVR tracker works
  through every OpenXR runtime or require a proprietary provider for basic play.
- Show tracker assignment/calibration UI, with explicit role selection and pose
  preview. Support head+hands, optional waist, waist+feet and richer sets; quality
  depends on available roles. Missing roles use estimation/animation, not invented
  “tracked” confidence. Unsupported runtime reports unavailable and remains playable.
- Calibrate floor/forward and body offsets in a comfortable standing pose with
  countdown/cancel. Detect bad distances, swapped feet and moved reference origin.
  No mandatory dangerous posture, real-world walking or blind auto-calibration.
- Pelvis/feet solve balances measured targets, limb lengths, joint limits and
  ground contact. Add foot planting/sliding suppression, crouch/sitting/lean and
  reachable knee poles without making feet authoritative camera/capsule motion.
- Tracker validity/age/loss blends each affected chain back to animation/estimated
  pose; remaining tracked chains stay active. Reconnect/recenter requires offset
  consistency or explicit recalibration. Device IDs stay local and ephemeral.

**Acceptance:** synthetic rigs/targets cover singularities/reach/calibration/loss;
real head+hands has aligned wrists/head without moving the camera; supported FBT
hardware shows stable pelvis/feet and safe fallback. Do not call FBT implemented
on the strength of a synthetic two-arm test alone.

## 9. Optional multiplayer pose replication

Local movement/menu/IK must work offline first. Existing body movement and resolved
animation remain; tracked poses are a capability-negotiated extension, not another
manual animation player. If delivered, update client/relay together:

- Send bounded root-relative head/hand and optional role targets, sequence/time,
  session/connection generation and avatar/calibration revision. No camera paths,
  hardware serials, room mesh or absolute playspace history.
- Relay derives actor, validates exact membership/finite bounds/rate/size and
  forwards active-instance data only. Allocate explicit unused wire IDs or a
  versioned negotiated payload; never reorder IDs or overload legacy PlayerData.
- Remote interpolation/jitter buffer applies animation base then available tracked
  chains; stale packets/old avatars/reused peer IDs cannot overwrite new state.
  Loss uses bounded timeout/fade, not frozen limbs or cross-instance poses.
- Client opt-out/privacy controls and visible capability status are explicit.
  Relay removes pose and indirect references on departure, without durable logs.

Keep this phase distinct from local FBT support so menus/movement are not blocked
by a risky protocol rewrite. Never claim remote FBT while only local tracking works.

## 10. Small implementation sequence and tests-first gates

| Conventional Commit unit | Deliverable and exit gate |
| --- | --- |
| `fix(vr): correct planar head-relative movement` | Failing pitch/sign/double-speed/diagonal fixtures → deterministic delta-safe floor movement, capsule/origin policy |
| `feat(vr): add headset-pivot snap and smooth turning` | Tests for one snap per deflection, rearm, smooth delta and invariant headset pivot |
| `feat(input): route controller menu actions without binding conflicts` | A/X either-hand single toggle; remove conflicting jump default; rebind and loss/focus reset tests |
| `feat(vr): integrate shared main menu with controller pointers` | Actual menu scene/viewport, hit-size transform, press capture, scroll/keyboard, either-hand/focus cleanup |
| `feat(settings): add VR movement and comfort preferences` | Registry/store defaults, turn/speed/vignette/seated/presets, persistence/reset and application tests |
| `feat(vr): add optional comfort teleport and transition fades` | Destination/collision checks and cancel/commit tests; no raw camera teleport or automatic publisher code |
| `feat(avatar): validate humanoid chains and persist calibration` | Rig report, controller offsets, per-avatar calibration/migration/corrupt-data tests |
| `fix(ik): stabilize tracked head hands and untracked fallback` | Joint limits/poles/singularities and partial-loss/reacquisition red-to-green tests |
| `feat(tracking): assign supported full-body tracker roles` | Runtime capability/provider adapter, local role UI and safe calibration; unsupported runtime falls back |
| `feat(ik): solve pelvis legs and feet from optional trackers` | FBT subset solve, floor/planting/crouch/reach tests plus explicit real-device checks |
| `feat(network): replicate scoped tracked-avatar poses` | Optional coordinated protocol, bounded validation/interpolation/lifecycle/privacy tests |
| `docs(vr): publish controls comfort and tracking compatibility` | Current guides, exact functions/symbol inventory, hardware matrix and unresolved gates—not just a roadmap status claim |

Write focused failing tests **before each behavioral fix**, then commit/push the
passing coherent part with tests/docs. Use ordinary Git and Conventional Commits;
no GitHub workflows/tools, force pushes, real release tags or silent hook install.
Combine only tightly coupled dependencies that cannot be independently runnable.

## 11. Verification and release matrix

Add isolated `tests/vr_controls/` and `tests/avatar_tracking/` following existing
disposable runner patterns. Replace hardware with explicit pose/action providers;
do not launch normal startup against real accounts or claim hardware coverage.

- **Movement:** head yaw/pitch/roll, near-vertical fallback, analog/diagonal magnitude,
  dead zones, frame rates, gravity/walls/slopes, crouch/capsule, room-scale offsets,
  teleport/spawn, world-transition and tracking/focus loss.
- **Turning:** snap thresholds/repeat/neutral reset, smooth rate, pivot invariance,
  left/right handedness, simultaneous controls and settings changes while held.
- **Menus:** real lower-button events from both hands and simultaneous edges,
  one owner, emote/main conflict, pointer bounds/non-square quads, drag-off/release,
  scroll, virtual keyboard/text input, invalid bindings and teardown/reopen.
- **Comfort:** finite/ranged persisted definitions, safe presets, independent reset,
  vignette/fade enable/disable, no animation-driven camera or synthetic tracking lag.
- **Mapping/IK:** alternate rigs/rest poses, missing/duplicate/zero-length chains,
  grip axes, scale, unreachable/singular targets, body fitting, valid/invalid aged
  trackers, recenter/avatar switch, per-chain animation fallback and FBT subsets.
- **Networking if added:** forged actors, out-of-range/NaN poses, sequence/loss/jitter,
  late join, avatar revision change, peer reuse, instance isolation, capability
  mismatch, opt-out and relay disconnect-reference erasure.

Run all existing eight Godot isolated runners and
`python3 tools/check_repository.py` after affected changes. Update function contracts,
inventory, settings and protocol references in the relevant commit. Record warnings,
skips and flaky timing reruns; never replace real evidence with old pass counts.

Manual gates: named headset/runtime/controller profile, standing/seated/room-scale,
left/right menus, snap/smooth turn, text entry, movement comfort, collision safety,
first-person/mirror appearance, head+hands calibration, each claimed FBT combination,
tracking loss/recenter and multi-client observation. Include refresh rate/frame-time
and reported discomfort; stop tests when uncomfortable. No unsupported hardware
or guaranteed sickness prevention claims.

**Done:** a player can move with the left stick along head-relative ground direction,
turn with configurable snap/smooth right-stick behavior, open the shared menu with
either lower face button without jumping/conflicts, tune comfort preferences, and
use validated calibrated IK with honest optional FBT capability/fallback—all while
keeping camera tracking, desktop behavior, account policy and relay privacy intact.
