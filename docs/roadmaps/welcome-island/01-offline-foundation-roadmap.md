# 01 — Offline foundation

**Status:** Implemented with manual gates — 2026-11-05. **Prerequisites:** None.
The isolated runner and startup reuse fix are delivered. See
[test scope and evidence](../../../tests/welcome_island/README.md). Actual headset
validation and legacy world-panel lifecycle remain open; this is not XR release certification.
See the [mandatory test-first workflow](README.md) and [shared design](../offline-welcome-island-roadmap.md).

## 1. Write tests first — before building

- [x] Create the disposable-project runner and initial fixtures without changing
  production behavior. Copy only required sources; isolate user data, relay/DNS,
  account files and physical capture. Document fixture limitations.
- [x] Add executable acceptance cases for home/menu readiness before a failed or
  pending relay connection completes, cold-cache offline loading, repeated home
  entry and one surviving root-level player. Cover desktop and synthetic XR setup.
- [x] Test existing account-error handling without overwriting a real key. Record
  the current baseline and expected missing-behavior failures.
- [x] Define a rendered offline-start test with a disposable profile and blocked
  network, including readiness observations rather than relying on log messages.

## 2. Build only after the tests exist

- [x] Fix only demonstrated startup/lifecycle gaps; preserve asynchronous relay
  connection, desktop/XR selection, scene UID and `default_wold` compatibility.
- [x] Establish focused suite selection and clear nonzero failure reporting.

## 3. Verify and close

- [x] Run the runner and existing relevant startup/settings checks; distinguish
  assertion failures from infrastructure errors and skipped prerequisites.
- [x] Run the rendered offline-start procedure. No relay wait, real-account writes,
  microphone enable or duplicated player is acceptable. Record results and publish
  the coherent passing unit; actual island content belongs to later parts.

- [ ] Complete actual-headset offline startup/menu/return validation. The rendered
  desktop fixture and production startup checks passed, but synthetic XR and
  world-shell/panel exclusions do not close this hardware/lifecycle gate.
