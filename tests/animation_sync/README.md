# Animation and revision checks

First-person tests now assert detached import preparation, unchanged original
mesh resources, camera-exclusive derivative layers and idempotent activation.
Tracking tests exercise actual SkeletonModifier head/arm solving against external
targets, including an upstream animated-arm disturbance and camera immutability.
The optional real-avatar group covers combined skinned geometry. Rendering,
mirror/shadow appearance and physical tracking calibration still need manual XR
checks; headless pose assertions do not validate their visual quality.

## Authored default animation regressions

The production receiver is exercised with every protocol built-in, including
`neutral`, with both full and tracked-head/hands masks and no custom asset fields.
The standing-player join regression reproduced a `Dictionary.size` error before
the receiver was changed to dispatch using `AnimationState.BUILTINS` rather than
the selectable-default list (which excludes neutral). Custom states without a
declared size are rejected before dispatch. These checks use a synthetic humanoid
rig, not a physical headset.

Defaults now use the free CC0 Quaternius Standard pack, not generated motion.
The suite checks sampled/changing chest, elbows, arms and hands. To additionally
check real-avatar retargeting without bundling a third-party avatar, run:

```sh
AVATAR_FIXTURE=/path/to/permitted/avatar.vrm python3 tests/animation_sync/run.py
```

That optional group uses the production loader and asserts that the authored walk
binds and both hands drop below the shoulders. It caught the legacy VRM 0.x
forward-convention bug that synthetic identity-rest rigs missed. The built-in
AliciaSolid URL was downloaded only to `/tmp/opencode` for this verification;
its model is not redistributed in this repository. Without AVATAR_FIXTURE the
runner explicitly reports that group as skipped. This is a pose assertion, not
a substitute for visual inspection of walking on every possible humanoid rig.

## Startup/menu regressions

The runner also executes `lifecycle_suite.gd` against the **production
NetworkHandler factory**, not the simpler animation fixture. Its 15 assertions
cover production desktop/VR script loading, offline Home wheel opening, detached
controller calls/recovery, same-frame queued-deletion replacement, externally
removed overlays and input ownership restoration on tree exit. The null-tree,
retiring-controller and detached-input regressions were reproduced failing before
their corresponding fixes. The existing 81 animation assertions run separately.

Controllers are hosted by the stable DataLoader autoload, outside NetworkHandler's
remote-player cleanup list. Calls on detached controllers fail safely; subsequent
factory calls repair attachment. This suite uses no real account, headset or
external relay. Headless capture-state checks respect the display backend's
actual supported mouse mode and do not replace desktop/headset interaction tests.

The suite now covers automatic/resolved animation **version 2**, source-only
avatar configuration, actual layout editor, nested groups, eight-sector in-wheel
paging boundaries, movement/landing resolution, emote interruption and rejection
of the removed manual pause schema. Model transfers are requested separately
under the same resolved avatar descriptor. This does not certify real-headset
interaction, production-size model transfers or measured visual synchronization.

Run `python3 tests/animation_sync/run.py` with Godot 4 available (`GODOT` may
override the executable). The runner copies production sources into a disposable
Compatibility project under `/tmp/opencode`, uses synthetic GLB/VRMA data and
ephemeral loopback ENet clients, and never launches normal startup or reads a
real account. Assertions fail with exit 1; Godot errors fail with exit 2.

Coverage: data-only rotation import, malformed/external/oversized input rejection,
declared humanoid mapping, rest rotation, AnimationPlayer controls, eight offline
default recipes, actual file-import UI and library reopening, production receiver
seeking/pause/session isolation, authenticated capability negotiation, relay sender
binding, same-instance delivery, replay rejection, snapshots/clock samples,
requested file bytes, queue cleanup, disconnect erasure and pinned-world mismatch.

Not covered: full VRMA conformance, arbitrary rig-space retargeting, expression or
translation tracks, production-size parsing/frame timing, real Internet latency,
measured 100 ms synchronization, multi-megabyte transfer fairness, exports,
Forward Plus, real-avatar visual quality, XR tracking/IK and physical listening.
Those remain release gates in `docs/roadmaps/avatar-cache-and-animation-roadmap.md`.
