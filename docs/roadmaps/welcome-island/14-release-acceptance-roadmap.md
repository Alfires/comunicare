# 14 — Whole-home release acceptance

**Status:** Planned. **Prerequisites:** 01–13.
See the [mandatory test-first workflow](README.md) and [shared completion criteria](../offline-welcome-island-roadmap.md#delivery-plan-and-completion).

## 1. Write tests first — before integration fixes or release preparation

- [ ] Add end-to-end acceptance cases combining cold-cache offline startup, middle
  spawn, free access to all areas, ship use, house controls, kitchen reset and
  Credits completeness in disposable profiles.
- [ ] Add repeated online-instance entry/leave/return-home cases: player/UI survive,
  local state stays instance-scoped, and session identity/admission/acknowledged
  transitions are unchanged. Include unavailable-network and corrupt-key fixtures.
- [ ] Write regressions reproducing any discovered integration bug before fixing it.
- [ ] Define the final desktop/headset and Help-hidden free-exploration matrix;
  collect open manual gates from every prerequisite before claiming readiness.

## 2. Build/fix only after the tests exist

- [ ] Make only acceptance-driven integration fixes; send larger missing features
  back to their focused roadmap with tests first instead of bypassing that part.
- [ ] Update current user guides, asset inventory, local packaging and roadmap
  status from evidence. No workflows, hosting-specific release tools or fake passes.

## 3. Verify and close

- [ ] Run all welcome-island groups and relevant existing microphone/settings,
  active-instance, discovery, safe-world, VR and real-UI runners; inspect current
  runner names/prerequisites and report every failed or skipped group.
- [ ] Complete actual renderer/headset/performance and free-exploration playtests.
  Confirm one big island, center spawn, working ship, useful furnished home,
  adjustable lights, kitchenware and optional help without tutorial presentation.
- [ ] Publish only the verified unit, record remaining limitations and keep release
  blocked by unmet required gates. A screenshot or green headless suite is not enough.
