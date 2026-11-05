# 06 — Offline pickup and activation

**Status:** Implemented with manual interaction/headset gates — 2026-11-05.
Follow-up: rendered synthetic carry/drop checks pass; wall-crossing/drop regression
is fixed with swept shape and endpoint clearance tests. Actual-headset reach and
production rendered comfort still require hardware. Linux debug standalone export passes.
**Prerequisites:** 05 (standalone export/headset gates remain open).
See [test evidence and limitations](../../../tests/welcome_island/README.md).
See the [mandatory test-first workflow](README.md) and [home interaction design](../offline-welcome-island-roadmap.md#home-first-freedom-and-unobtrusive-learning).

## 1. Write tests first — before building

- [x] Add executable pickup/carry/drop/activate/reset cases without relay/auth/leases,
  plus out-of-reach, obstructed target, invalid target and duplicate-hold cases.
- [x] Cover desktop and synthetic VR aim, current bindings, menu/focus suppression,
  input cancellation, scene exit and held-object cleanup/velocity bounds.
- [x] Assert native home support never weakens downloaded-world validation or
  implies synchronization. Record expected missing-behavior failures.
- [x] Define manual seated reach, contact/highlight and held-prop stability checks.

## 2. Build only after the tests exist

- [x] Inspect the existing pickup/runtime services and choose a narrow shared local
  adapter or validated built-in document, not a second unrelated input system.
- [x] Implement one reusable offline interaction path, clear affordances and safe
  player collision handling. Use simple fixture props before kitchen/ship content.

## 3. Verify and close

- [x] Run interaction/world safety/input regressions and repeat scene transitions.
- [ ] Verify real desktop and headset reach and stable carry/drop. Document local-only
  online behavior in contextual/menu information, not world billboards.
