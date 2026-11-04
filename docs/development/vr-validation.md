# VR validation record and hardware release gates

## Automated evidence (2026-11-04)

Run `python3 tests/vr_controls/run.py`,
`python3 tests/avatar_tracking/run.py`,
`python3 tests/animation_sync/run.py` and `python3 tools/check_repository.py`.
The isolated projects use Compatibility, synthetic tracked poses, actual physics
fixtures and loopback ENet. They do not initialize a real headset/runtime.

New terrain/anatomical safeguards are verified for finite bounded head transforms,
camera independence, flat-floor foot contact/jitter/lift and missing terrain.
Conservative neck/wrist rotation cones and bounded neck translation are fallback
safety limits, not measured per-user/per-avatar joint anatomy. Ground contact uses
short local rays; stairs, moving platforms, scaled rigs and slopes need device/
visual verification beyond these fixtures.

## Certification status

**Not hardware certified.** No headset/controller/body-tracker devices are
available in this execution environment. Automated results cannot establish
comfort, sickness prevention, safe playspace behavior, actual runtime profile
support or universal anatomical compatibility. This record is deliberately not
a claim of independent certification, product safety approval or VRChat parity.

## Required reproducible manual record

For each claimed supported combination record:

| Item | Required evidence |
| --- | --- |
| Build | Git revision, Godot/export version, OS/GPU/driver, renderer |
| Runtime | OpenXR runtime/version, enabled extensions, exact interaction profile |
| Devices | Headset/controllers and optional tracker types/roles; no public serials |
| Avatar | Format/version, proportions, scale/rest axes, permission to test |
| Locomotion | Seated/standing/room-scale, walls/ceilings/slopes, snap/smooth/teleport, pivot invariance |
| UI | Either lower button, emote conflict, pointer drag/release, text entry, scrolling, focus/tracking loss |
| Tracking | Calibration/countdown/cancel, hand axes, reach/singularities, waist/feet, crouch/lean, partial loss/reacquisition |
| Rendering | Local/third-person/mirror head/body, shadows/expressions, no camera-driven animation |
| Network | 2–3 clients, exact instance isolation, avatar swap, opt-out, late join, packet delay/loss, disconnect cleanup |
| Performance | Headset refresh, frame-time distribution, tracking latency, transfer/voice fairness |
| Comfort | Settings used, duration, reported discomfort, stop/cancel response; never require continued exposure when uncomfortable |

Archive sanitized results with failures and known limits. A passing combination
does not certify another runtime/device or an arbitrary avatar. Do not relabel an
unexecuted row as passed. Only narrow support claims backed by these records may
be added to a release compatibility matrix.
