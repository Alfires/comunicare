# Animation and revision checks

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
