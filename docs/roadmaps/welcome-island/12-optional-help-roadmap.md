# 12 — Optional Help, not a tutorial course

**Status:** Planned. **Prerequisites:** 06; finalize action text after 08–11.
See the [mandatory test-first workflow](README.md) and [home-first rules](../offline-welcome-island-roadmap.md#home-first-freedom-and-unobtrusive-learning).

## 1. Write tests first — before building

- [ ] Add executable UI/input cases for opt-in Help/Controls, current remapped
  bindings/XR mode text, show/hide and minimal intentionally targeted action hints.
- [ ] Assert no proximity lessons, repeated arrival reminder, completion tracking,
  prerequisite action locks or auto-enabling microphone/network actions.
- [ ] Cover menu focus/suppression, offline explanations and Help-disabled access
  to ship/house/kitchen. Record failures for missing help and unwanted prompts.
- [ ] Write readability and free-exploration procedures with all hints hidden.

## 2. Build only after the tests exist

- [ ] Integrate Help into the existing menu and a short contextual action layer;
  no control billboards, tutorial stations, numbered route or feature-demo kiosk.
- [ ] Keep visibility session-local and actual settings ownership unchanged. At most
  one dismissible initial menu-key hint; every area/action remains optional.

## 3. Verify and close

- [ ] Run UI/binding regressions and no-help access cases across the complete home.
- [ ] Check desktop/VR readable size, input capture and free exploration; people
  must be able to stay, wander or return without a “finish tutorial” event.
