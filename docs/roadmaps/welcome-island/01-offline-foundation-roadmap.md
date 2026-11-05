# 01 — Offline foundation

**Status:** Planned. **Prerequisites:** None.
See the [mandatory test-first workflow](README.md) and [shared design](../offline-welcome-island-roadmap.md).

## 1. Write tests first — before building

- [ ] Create the disposable-project runner and initial fixtures without changing
  production behavior. Copy only required sources; isolate user data, relay/DNS,
  account files and physical capture. Document fixture limitations.
- [ ] Add executable acceptance cases for home/menu readiness before a failed or
  pending relay connection completes, cold-cache offline loading, repeated home
  entry and one surviving root-level player. Cover desktop and synthetic XR setup.
- [ ] Test existing account-error handling without overwriting a real key. Record
  the current baseline and expected missing-behavior failures.
- [ ] Define a rendered offline-start test with a disposable profile and blocked
  network, including readiness observations rather than relying on log messages.

## 2. Build only after the tests exist

- [ ] Fix only demonstrated startup/lifecycle gaps; preserve asynchronous relay
  connection, desktop/XR selection, scene UID and `default_wold` compatibility.
- [ ] Establish focused suite selection and clear nonzero failure reporting.

## 3. Verify and close

- [ ] Run the runner and existing relevant startup/settings checks; distinguish
  assertion failures from infrastructure errors and skipped prerequisites.
- [ ] Run the rendered offline-start procedure. No relay wait, real-account writes,
  microphone enable or duplicated player is acceptable. Record results and publish
  the coherent passing unit; actual island content belongs to later parts.
