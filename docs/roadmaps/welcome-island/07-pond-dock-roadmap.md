# 07 — Pond and dock

**Status:** Implemented with manual headset/final-water gates — 2026-11-05.
**Prerequisites:** 02, 04, 05. See [evidence](../../../tests/welcome_island/README.md).
See the [mandatory test-first workflow](README.md) and [pond design](../offline-welcome-island-roadmap.md#pond-and-working-ship).

## 1. Write tests first — before building

- [x] Add executable checks for a sealed recessed pond bed, water/shore bounds,
  a dry perimeter route, accessible dock and sufficient reserved ship clearance.
- [x] Test falling into water returns a player safely to a clear bank/dock without
  a death loop; reject blocked recovery targets and unsafe teleport water hits.
- [x] Define desktop/XR checks for legible banks, comfortable dock traversal and
  low-cost water without SSR. Record expected scene/behavior failures first.

## 2. Build only after the tests exist

- [x] Sculpt the pond in the same single island; integrate a cleared whole dock
  asset or individual parts, collision proxies and shoreline borders. A premade
  dock is allowed; a complete island/map preset is not. No second landmass destination.
- [x] Add restrained water and safe pond recovery using the shared reset contract.
  Ship behavior belongs to part 08, not an untested decorative substitute here.

## 3. Verify and close

- [x] Run pond/layout/recovery and provenance checks; walk the dry route end to end.
- [ ] Inspect water/shore contact in both XR eyes and confirm safe falls/returns.
  Final reflections/material polish and performance remain part 13 gates.
