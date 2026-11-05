# 05 — Spawn, recovery and built-in revision

**Status:** Planned. **Prerequisites:** 04.
See the [mandatory test-first workflow](README.md) and [implementation baseline](../offline-welcome-island-roadmap.md#inspected-implementation-baseline).

## 1. Write tests first — before building

- [ ] Exercise direct startup and DataLoader activation against one spawn contract;
  assert position/clearance, surviving player identity and preserved XR head offsets.
- [ ] Add repeated fall/menu-return cases, linear/angular velocity reset, safe item
  home positions and no duplicate bodies. Reproduce existing reset gaps first.
- [ ] Test deterministic built-in revisions: editing a relevant subscene, script or
  shipped resource changes the revision; irrelevant files don't; mismatches reject.
- [ ] Define rendered/headset recovery checks; record expected failures before fixes.

## 2. Build only after the tests exist

- [ ] Implement shared player/item reset contracts instead of resetting every body
  to the player's head. Retain persistent player lifecycle and safe XR transitions.
- [ ] Implement deterministic dependency-aware revision generation with local tools;
  preserve `default_wold`, staged activation and acknowledged session behavior.

## 3. Verify and close

- [ ] Run recovery/revision and relevant instance/world regressions with disposable
  profiles; verify no stale revision after dependency changes.
- [ ] Perform repeated desktop/headset returns. Movement must stop safely without
  forced tracked-head rotation. Later ship/bed recovery extends these tests first.
