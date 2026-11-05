# 06 — Offline pickup and activation

**Status:** Planned. **Prerequisites:** 05.
See the [mandatory test-first workflow](README.md) and [home interaction design](../offline-welcome-island-roadmap.md#home-first-freedom-and-unobtrusive-learning).

## 1. Write tests first — before building

- [ ] Add executable pickup/carry/drop/activate/reset cases without relay/auth/leases,
  plus out-of-reach, obstructed target, invalid target and duplicate-hold cases.
- [ ] Cover desktop and synthetic VR aim, current bindings, menu/focus suppression,
  input cancellation, scene exit and held-object cleanup/velocity bounds.
- [ ] Assert native home support never weakens downloaded-world validation or
  implies synchronization. Record expected missing-behavior failures.
- [ ] Define manual seated reach, contact/highlight and held-prop stability checks.

## 2. Build only after the tests exist

- [ ] Inspect the existing pickup/runtime services and choose a narrow shared local
  adapter or validated built-in document, not a second unrelated input system.
- [ ] Implement one reusable offline interaction path, clear affordances and safe
  player collision handling. Use simple fixture props before kitchen/ship content.

## 3. Verify and close

- [ ] Run interaction/world safety/input regressions and repeat scene transitions.
- [ ] Verify real desktop and headset reach and stable carry/drop. Document local-only
  online behavior in contextual/menu information, not world billboards.
