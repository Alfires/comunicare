# 09 — House, beds and side spaces

**Status:** Implemented initial furnished structure with manual XR/art gates — 2026-11-05.
Collision follow-up (2026-11-06): side proxies fitted to the aggregate transformed
architectural shell, fixing invisible barriers inside the wider rendered room.
Decorative window/trim collision is still proxy-based, not exact per-triangle physics.
Style follow-up (2026-11-06): cleared textured Innerscene bungalow exterior and
Poly Haven sofa/daybeds/coffee table/picnic table replace the visible box-house
and mismatched bright low-poly furnishings. Single-level layout/collision retained;
asset source/modification records and tests added. Final art/XR gates are not waived.
Rest follow-up: explicit nearby bed/sofa rest/leave, duplicate rejection, clear-exit
fallback and spawn-release tests now pass. The imported raised foundation is hidden
to prevent visual overlap with the accessible floor. This supersedes the earlier
“rest not implemented” note below, not actual-headset comfort or final visual gates.
**Prerequisites:** 02, 04, 06. See [evidence](../../../tests/welcome_island/README.md).
See the [mandatory test-first workflow](README.md) and [house plan](../offline-welcome-island-roadmap.md#house-chill-spaces-and-kitchen).

## 1. Write tests first — before building

- [x] Add scene/physics checks for a house with lounge, kitchen footprint and at
  least two beds; accessible entry, clear exits, room-scale/teleport clearance
  and dry routes from the middle to left/right hangouts.
- [ ] Test any explicit Sit/Rest/Leave behavior before implementing it: cancel,
  safe exit, scene cleanup, preserved XR offsets and no spawn/time changes.
- [x] Define home-first visual checks for left deck/cushions/picnic area and right
  house/porch/herb garden/shore seating, including seated reach. Record failures.

## 2. Build only after the tests exist

- [x] Assemble modular cleared house parts and individual furnishings ourselves;
  no furnished prefab. Provide single-level circulation and usable resting places.
- [x] Furnish both sides while preserving open central views and an unobstructed
  middle spawn. Reserve accessible kitchen counters and lighting control positions.
- [x] Keep physical lounge/bed use comfortable; never force a lying-down head pose.

## 3. Verify and close

- [ ] Run room/layout/interaction/provenance checks, then desktop and headset room
  walkthroughs. Confirm beds have a safe approach and exit.
- [ ] Review with hints hidden: a coherent home, not furniture arranged as exercises.
  Working lights/kitchen are separate required parts, not claimed complete here.

27 rendered house checks, 30 layout checks, startup/assets/Credits and isolated
Linux debug export pass. Beds/furniture have physical surfaces, no explicit rest
action or forced camera pose; optional Sit/Rest/Leave is not implemented and its
checkbox remains open. Real headset walkthrough and final art remain manual gates.
