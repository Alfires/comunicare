# 04 — One island and a middle spawn

**Status:** Planned. **Prerequisites:** 01.
See the [mandatory test-first workflow](README.md) and [ASCII layout](../offline-welcome-island-roadmap.md#experience-and-original-layout).

## 1. Write tests first — before building

- [ ] Define a layout contract and executable scene/physics checks for one continuous
  playable landmass, a spawn within an explicit tolerance of its plan-view center,
  dry/level spawn clearance and connected broad dry routes to all reserved areas.
- [ ] Cover the house, left deck, right garden, pond footprint, dock, slopes, bypass
  routes and desktop/VR teleport capsule clearance. Fail on disconnected routes,
  obstructed spawn and unsafe slopes; don't mistake decorative rocks for islands.
- [ ] Write rendered composition checks from center and both sides: open arrival,
  meaningful destination choices, no tutorial campus. Record initial failures.

## 2. Build only after the tests exist

- [ ] Author the original graybox base, continuous upper terrain/underside and
  branching paths; keep `scenes/world.tscn` and its UID as the compatible entry.
- [ ] Reserve pond/house footprints and left/right hangout areas without moving
  spawn off-center. No final kit or whole-map preset; primitives are temporary.

## 3. Verify and close

- [ ] Run layout/physics checks and traverse every dry route with desktop and
  synthetic teleport input; report actual headset traversal separately.
- [ ] Review the original layout against ASCII concepts and home-first criteria.
  Graybox completion is not final visual acceptance or verified fall recovery.
