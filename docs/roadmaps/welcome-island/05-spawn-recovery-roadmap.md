# 05 — Spawn, recovery and built-in revision

**Status:** Implemented with manual/export gates — 2026-11-05. **Prerequisites:** 04.
Follow-up: rendered recovery and isolated exported-PCK revision/load checks pass.
Standalone-template export (templates unavailable) and real-headset recovery
(no configured OpenXR runtime) remain open; do not infer them from the PCK test.
See [recovery/revision evidence](../../../tests/welcome_island/README.md).
See the [mandatory test-first workflow](README.md) and [implementation baseline](../offline-welcome-island-roadmap.md#inspected-implementation-baseline).

## 1. Write tests first — before building

- [x] Exercise direct startup and DataLoader activation against one spawn contract;
  assert position/clearance, surviving player identity and preserved XR head offsets.
- [x] Add repeated fall/menu-return cases, linear/angular velocity reset, safe item
  home positions and no duplicate bodies. Reproduce existing reset gaps first.
- [x] Test deterministic built-in revisions: editing a relevant subscene, script or
  shipped resource changes the revision; irrelevant files don't; mismatches reject.
- [x] Define rendered/headset recovery checks; record expected failures before fixes.

## 2. Build only after the tests exist

- [x] Implement shared player/item reset contracts instead of resetting every body
  to the player's head. Retain persistent player lifecycle and safe XR transitions.
- [x] Implement deterministic dependency-aware revision generation with local tools;
  preserve `default_wold`, staged activation and acknowledged session behavior.

## 3. Verify and close

- [x] Run recovery/revision and relevant instance/world regressions with disposable
  profiles; verify no stale revision after dependency changes.
- [ ] Perform repeated desktop/headset returns. Movement must stop safely without
  forced tracked-head rotation. Later ship/bed recovery extends these tests first.

Recovery tests started red before fixes. Shared reset preserves player identity and
tracked local transforms, clears motion and restores registered items to their own
homes. The revision generator/check must be run before local export; exported-resource
hash fallback and actual headset recovery remain unverified manual release gates.
