# Welcome home: required human release checks

These are **not yet run/passed**. Isolated scripts, synthetic trackers and desktop
screenshots do not certify comfort, audible playback or subjective art approval.
Use disposable profiles/keys; never publish private keys or entire test artifacts.

Latest isolated desktop measurements and explicit failed/unavailable gates are in
the [2026-11-06 verification record](welcome-home-verification-2026-11-06.md).

| Gate | Required setup | Pass criteria | Evidence to record |
| --- | --- | --- | --- |
| Stereo walkthrough | Configured OpenXR runtime, supported headset/controllers, named GPU/refresh | Spawn, water, glazing, shore and lights read correctly in both eyes; no one-eye artifacts | Runtime/headset/GPU/refresh and concrete failures |
| Seated/standing reach | Human testers in both postures | Kitchenware, menus, light controls, ship confirmation/exit reachable without unsafe leaning; escape always works | Posture/device and blocked interactions |
| Boat/rest comfort | Headset wearer, clear playspace, optional ride | Explicit consent, neutral rearming, immediate stop, no forced tracked rotation, stable rider view and exits | Duration/symptoms/reset outcome; stop immediately on discomfort |
| Audible WAN networking | Two consented clients on separate networks, third in another instance | Intelligible exact-instance voice, no audible leakage, mute stops capture, disconnect clears state | Client commits/latency/loss and quality; no private conversation recordings |
| Sustained performance | Named desktop/headset hardware, production Forward Plus | Meet agreed sustained frame/VRAM budget across home views with moving props | Duration/median/p95/VRAM/thermal and method; separate GPU from vsync timings |
| Free-exploration/art review | New/returning users, Help/highlights hidden | Activities optional, no tutorial/task feeling, coherent naturalistic home without clipping/placeholder art | Specific issues and explicit human approval, not assertion counts |

Record source commit and run `python3 tools/assets/build_home_revision.py --check`.
Run `python3 tests/welcome_island/run_acceptance.py` (optionally `--template` for
a matching standalone Linux debug template). Preserve failures/skips. Matrix exit
0 means selected local checks passed, **not** release approval.

Attach human evidence to the [roadmap gates](../roadmaps/welcome-island/README.md).
Do not tick hardware gates because an emulator starts or simulated input invokes a
service. Missing hardware, a second network participant or reviewer is a blocker
to report, not a reason to change the pass criteria.
