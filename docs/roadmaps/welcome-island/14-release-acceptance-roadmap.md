# 14 — Whole-home release acceptance

**Status:** Local matrix and combined home acceptance implemented; release BLOCKED — 2026-11-05.
**Prerequisites:** 01–13, including their open art/hardware gates.
See [matrix/evidence](../../../tests/welcome_island/README.md).
See the [mandatory test-first workflow](README.md) and [shared completion criteria](../offline-welcome-island-roadmap.md#delivery-plan-and-completion).

## 1. Write tests first — before integration fixes or release preparation

- [x] Add end-to-end acceptance cases combining cold-cache offline startup, middle
  spawn, free access to all areas, ship use, house controls, kitchen reset and
  Credits completeness in disposable profiles.
- [ ] Add repeated online-instance entry/leave/return-home cases: player/UI survive,
  local state stays instance-scoped, and session identity/admission/acknowledged
  transitions are unchanged. Include unavailable-network and corrupt-key fixtures.
- [x] Write regressions reproducing any discovered integration bug before fixing it.
- [x] Define the final desktop/headset and Help-hidden free-exploration matrix;
  collect open manual gates from every prerequisite before claiming readiness.

The [human release matrix](../../development/welcome-home-release-gates.md) defines
required setups/pass criteria/evidence; it is not a record of completed hardware tests.
Rapid DataLoader home roundtrips reproduced/fixed deferred setup after scene removal.

## 2. Build/fix only after the tests exist

- [ ] Make only acceptance-driven integration fixes; send larger missing features
  back to their focused roadmap with tests first instead of bypassing that part.
- [ ] Update current user guides, asset inventory, local packaging and roadmap
  status from evidence. No workflows, hosting-specific release tools or fake passes.

## 3. Verify and close

- [x] Run all welcome-island groups and relevant existing microphone/settings,
  active-instance, discovery, safe-world, VR and real-UI runners; inspect current
  runner names/prerequisites and report every failed or skipped group.
- [ ] Complete actual renderer/headset/performance and free-exploration playtests.
  Confirm one big island, center spawn, working ship, useful furnished home,
  adjustable lights, kitchenware and optional help without tutorial presentation.
- [ ] Publish only the verified unit, record remaining limitations and keep release
  blocked by unmet required gates. A screenshot or green headless suite is not enough.

Combined no-help lifecycle suite and local matrix are available; real-headset,
human free-exploration, final landscape quality and named GPU/VRAM performance are
not complete. Active-instance voice assertion has intermittent failing evidence;
do not erase it because a later run passes. No release-ready claim is authorized.

Post-restart follow-up (2026-11-06): isolated Active Instance passed 132 checks.
The earlier matrix still failed that group; the cause is not established and no
voice fix is claimed. Matrix logs now use unique directories with an incremental
machine-readable summary. Final-art, human XR and performance gates remain open.

Routing follow-up: the test-only recording relay isolates membership checks from
adaptive unreliable-packet throttle deceleration; bounded stream/outsider-isolation
checks passed three consecutive 138-assertion runs. Production voice semantics
are unchanged. Historical failures remain recorded; they no longer mean the
deterministic routing fixture is blocked. WAN loss/listening and human XR gates remain.
