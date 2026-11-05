# 10 — Adjustable room lighting

**Status:** Planned. **Prerequisites:** 06, 09.
See the [mandatory test-first workflow](README.md) and [house controls](../offline-welcome-island-roadmap.md#house-chill-spaces-and-kitchen).

## 1. Write tests first — before building

- [ ] Add executable cases for three independent lounge/bedroom/kitchen zones:
  on/off, bounded brightness and supported warm/neutral color-temperature ranges.
- [ ] Test invalid/nonfinite values, cross-zone isolation, immediate actual-light
  changes, session reset, menu suppression and no global renderer/settings writes.
- [ ] Define rendered lamp-off/on, dynamic-prop illumination, dimmest/brightest and
  both-eye XR checks. Set light-count/cost targets before adding lights.
- [ ] Record expected failures before implementing the controls.

## 2. Build only after the tests exist

- [ ] Add reachable desktop/VR controls and real illumination, not just emissive
  material changes. Keep state local and reset predictably on home reload.
- [ ] Use restrained warm lighting and bounded transitions; no flicker, strobe or
  expensive shadow light for every fixture. Label no area as a lighting tutorial.

## 3. Verify and close

- [ ] Run zone/input/state tests and existing settings regressions.
- [ ] Verify manual desktop/XR range, reach, visibility and reflection/light spill;
  record actual rendering cost. Headless property assertions alone do not close it.
