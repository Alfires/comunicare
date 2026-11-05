# 03 — Settings → Credits

**Status:** Implemented with manual headset gate — 2026-11-05. **Prerequisites:** 02.
See [verification/scope](../../../tests/welcome_island/README.md).
See the [mandatory test-first workflow](README.md) and [Credits requirements](../offline-welcome-island-roadmap.md#settings--credits).

## 1. Write tests first — before building

- [x] Add executable UI cases for a read-only Credits category, preserved category
  selection/re-render behavior, scrolling and no settings-store writes/reset action.
- [x] Assert manifest-to-display completeness, required notices and locally readable
  full licenses, including existing bundled third-party assets.
- [x] Test that rendering makes no HTTP request and links need explicit activation;
  include long notices, empty/invalid records and missing-license negative cases.
- [x] Define desktop and VR viewport checks for readable type, pointer/keyboard
  navigation and scrolling. Record expected failures before implementing the page.

## 2. Build only after the tests exist

- [x] Integrate a dedicated read-only page into `settings_menue.gd` navigation;
  do not invent a persisted Credits setting or bypass existing category behavior.
- [x] Render locally bundled asset names, authors, sources, licenses and notices.

## 3. Verify and close

- [x] Run UI/provenance and existing microphone/settings tests with no silent skips.
- [ ] Check offline desktop/VR readability and full license access. Verify later
  asset additions appear automatically or fail completeness checks until included.

Desktop rendered inspection passed; actual controller/headset readability remains
open. The viewport-sized automated checks are not a headset certification.
