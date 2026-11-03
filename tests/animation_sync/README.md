# Animation and revision checks

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
Those remain release gates in `docs/avatar-cache-and-animation-roadmap.md`.
