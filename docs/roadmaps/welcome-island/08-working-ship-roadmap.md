# 08 — Player-operated ship

**Status:** Implemented constrained local ship with manual XR/UI gates — 2026-11-05.
**Prerequisites:** 06, 07. See [scope/evidence](../../../tests/welcome_island/README.md).
See the [mandatory test-first workflow](README.md) and [ship contract](../offline-welcome-island-roadmap.md#pond-and-working-ship).

## 1. Write tests first — before building

- [x] Add offline cases for explicit boarding, throttle/steering/stop, supported
  rider motion, bounded speed/turn rate and shoreline collision/containment.
- [x] Test blocked/invalid disembark, safe dock exit, stranded/overturned reset,
  cleared motion/control, scene exit, menu/focus loss and repeated boarding.
- [x] Assert no relay dependency, no forced XR head rotation and correct tracked
  offset handling; record expected failures for absent ship behavior.
- [x] Write real-headset rider-jitter/comfort and desktop steering procedures before
  implementing; synthetic tracking alone cannot prove comfort.

## 2. Build only after the tests exist

- [x] Assemble a cleared small hull with bounded local watercraft motion, rider
  support, steering and safe exit/reset. Do not substitute bobbing or autopilot.
- [x] Offer immediate stop/return-to-dock, clear optional controls and explicit
  boarding confirmation. No ocean simulation or new vehicle network protocol.

## 3. Verify and close

- [x] Run ship, interaction, pond and reset suites plus asset/license checks.
- [ ] Verify moving support, boarding and disembarking on desktop and real headset.
  Riding stays optional; implementing a working ship is required.
