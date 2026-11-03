# Avatar sources, automatic motion and emote wheel

First-person clearance defaults to **15 cm forward** of the desktop avatar's
rest-eye position (`first_person_forward_offset` on the player script). In VR,
the avatar shell is offset 15 cm backward instead; headset tracking and camera
pose are not artificially shifted. Both values are tunable per player scene.

Falling playback is now removed: descending uses the static neutral pose, with
no fall loop. First-person derivatives exclude the torso/pelvis/neck as well as
the head so the camera does not look into the avatar shell. Arms and legs remain
available locally; other cameras and shadows retain the intact full avatar.
This deliberately sacrifices first-person torso visibility for reliable interior
clipping avoidance, rather than moving the camera or hiding the body globally.

## First-person rendering and VR tracking

Avatar import now prepares a separate first-person mesh derivative on the worker
before the detached avatar enters the scene tree. VRM 0.x/1.0 first-person mesh
annotations take priority; Auto meshes use dominant head-bone skin weights to
filter the local view. The original full mesh is never replaced or cut. The
local camera renders the derivative, other cameras render the original, both
share one skeleton, and expressions are copied from the original to the local
derivative. The original remains the shadow caster. Additional cameras created
after startup automatically exclude the local-body layer.

VR now has a final SkeletonModifier tracking pass: head alignment and two-bone
arm solving follow the external headset/controller targets after animation.
The old unconfigured XRBodyModifier/TwoBoneIK placeholders are removed. Tracking
never moves the camera; only active XR targets override pose. Fingers and other
untracked channels remain animated. Reach is clamped to the avatar's limb length.

Limitations: automatic first-person filtering can still require avatar-author
annotations for unusual skinning/accessories. Headset/controller orientation and
body proportions need real-device calibration/visual testing; automated target
tests are not a claim of VRChat-equivalent full-body IK. Remote live tracker
poses are not added to the existing animation protocol by this rendering fix.

Current movement behavior: forward walk/run and separate left/right directional
walk variants are selected in player-local space. Idle and landing animation
playback are disabled; stopping blends to a static authored standing pose.
Directional variants adapt Quaternius Walk_Loop by reorienting its motion bases;
the free Standard pack does not include separately authored strafe clips.
Sideways locomotion now applies that adaptation to leg tracks only. Arms,
shoulders, hips and torso use the unrotated static authored standing pose; VR
head/hand tracking remains the final override. Remote avatars use the same
composition, so strafe state no longer swings or twists the arms sideways.

In VR, animation keeps torso, shoulders, arms, fingers and legs. Only head/eye/jaw
and hand tracks are excluded for head/hand tracking; the old lower-body-only
mask is removed. The local avatar's head triangles use a dedicated camera layer
excluded only by its first-person camera. Other cameras still render the head,
including head geometry that originally shared a skinned mesh with the body.

## Configure your avatar

Open **Home → your User/profile entry → Avatar setup**. This is an owner-only
source editor, not a playback console:

- Enable **Select model** to choose a compatible `.vrm`/humanoid `.glb` file or
  HTTPS URL. A model may also contain supported embedded animation clips.
- Otherwise add one or multiple external `.vrma`/humanoid `.glb` files or URLs.
- Confirm redistribution permission only for content you are allowed to share.
  Custom models need that permission to equip; imported emotes without permission
  cannot be broadcast. Unshared custom movement clips fall back to defaults when
  connected to a compatible relay.
- **Apply** equips the candidate configuration. **Cancel / Back** leaves the
  applied avatar/sources unchanged. Imported originals remain cached.

Idle, walk, run, jump, fall and land are selected automatically. Recognized clip
names replace these roles; external sources override embedded clips and bundled
CC0 defaults. Later external sources win. Other compatible clips are emotes.
Bundled defaults are now **Quaternius Universal Animation Library Standard-1.0**
authored full-body motions, not procedural recipes. Dance and Interact are the
included non-basic actions. See `THIRD_PARTY_ASSETS.md` for exact source/license
and reproducible conversion. Saved Wave/Cheer placeholder shortcuts can be
reassigned or reset using the group editor.
The importer currently supports rotation-only, self-contained humanoid GLB/VRMA
with LINEAR/STEP channels, not arbitrary models or full VRMA conformance.

Selections and wheel layout persist per account under `user://avatars/`. Private
filesystem paths are never published as avatar URLs. Corrupt configuration files
are preserved and reported rather than silently replaced.

## Open and customize Emotes

Press **B**, or click **Home → Emotes** in the formerly unused lower-left grid
cell. Change the key under **Settings → Controls → Emote menu**. Typing, modal
dialogs and rebinding suppress the shortcut.

The wheel always has **eight sectors**. Groups with at most eight entries use all
eight for content. Larger groups show five entries plus **Previous animations**,
**Page X / Y**, and **Next animations inside the wheel**. There are no paging
buttons underneath. The center goes Back or cancels; the page indicator is inert.

Select an action to apply it to your avatar. One-shots finish automatically;
explicitly looping clips (name ending in `Loop`) repeat. **Return to movement**,
movement/jumping/falling, or replacing the avatar interrupts an emote. Basic
movement animations remain automatic. Opening/browsing groups never starts an
animation or sends a playback command.

Clip changes blend from the currently visible pose over 0.22 seconds, including
changes that interrupt another transition. Desktop cameras stay attached to the
player (height calibrated once from avatar rest geometry); XR cameras remain
under the tracked XROrigin. Animated head/eye bones no longer drive either camera.

Use **Avatar setup → Customize emote groups and wheel** to create nested groups,
rename/delete groups, add action shortcuts, reorder/move entries and reset the
layout. Fresh imported actions get an Imported actions group; additional actions
are available in the editor's action list. Layout is local, not synchronized.

## VR interaction

The invoking controller opens a stable world-space wheel. The default existing
OpenXR action is B/Y (`by_button`), configurable to Menu under Controls; keyboard
B is a separate desktop binding. While held, move the controller away from the
neutral center toward a sector and release to confirm. Group/paging navigation
keeps the wheel open and switches to a fresh pointer/trigger confirmation.
Home opens pointer/trigger mode directly. Center cancels or goes Back.

Both hands can invoke the wheel. Interface settings control diameter, dead zone
and haptics. Tracking/focus loss closes it. Movement inputs are suppressed while
the XR wheel is open. Motion animation is restricted to lower-body tracks in VR;
head/hands, camera and collision-body motion are not driven by imported clips.
Real headset/controller compatibility, visual comfort and IK require manual tests.

## Networking and cache

Update client and relay together: animation **version 2** on wire ID 28 carries
only resolved locomotion/emote state. Legacy manual Play/Pause/Stop is rejected.
Movement, voice, profiles and admission are unchanged. Compatible participants
request missing hash-verified model/animation bytes from the connected owner;
the relay forwards bounded chunks without persistent files or offline history.

Managed content lives in `user://asset_cache/`. **Settings → Assets** controls
the default 4 GiB budget, checks loaded assets and clears unused downloads.
Known-good content survives failed refreshes. HTTPS is required unless the
development HTTP option is enabled; redirects are currently refused. Remote
worlds are executable Godot content and require explicit trusted-publisher opt-in.

See the roadmap for remaining release gates: full importer conformance, polished
blending, real-avatar/XR visuals, measured latency/jitter synchronization, large
transfer fairness/recovery and exported-build checks are not certified by the
headless synthetic/loopback suites.
