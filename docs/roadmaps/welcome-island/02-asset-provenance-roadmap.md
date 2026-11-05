# 02 — Free assets and provenance

**Status:** Implemented with asset-selection/runtime limits — 2026-11-05.
**Prerequisites:** 01 (actual headset/legacy-panel gates remain open).
See [bundled sample, inspection and reproduction](../../../assets/welcome_island/README.md).
This part delivers four CC0 sample entries, validation and import tests, not final
optimized landscape assets, Credits UI or the later ship/house prop inventory.
See the [mandatory test-first workflow](README.md) and [asset policy](../offline-welcome-island-roadmap.md#free-asset-research-and-licensing-gate).

## 1. Write tests first — before acquiring/building the asset set

- [x] Add executable manifest fixtures: valid entries, absent author/source/license,
  missing license file, duplicate IDs, wrong hashes and nonexistent shipped paths.
- [x] Assert the approved license policy, required attribution/modification notices,
  and consistency with `THIRD_PARTY_ASSETS.md`; reject ambiguous permissions.
- [x] Define inspection checks for meter scale, normals, foliage alpha, runtime
  texture sizes and original/download versus converted hashes. Record expected
  validation failures before writing the validator or bundling island assets.

## 2. Build only after the tests exist

- [x] Implement manifest validation and documented local conversion/import steps.
- [x] Acquire a small cleared tree/rock/material/sky set and individual hull/dock,
  house/furniture/appliance/kitchen candidates as needed by later parts. Prefer
  CC0; verify exact archive terms, not merely “free download” labels.
  The four nature/sky entries are bundled; hull/dock/house/kitchen remain documented
  candidates for later parts, not falsely listed as downloaded inventory.
- [x] Preserve provenance, notices and full licenses; document runtime variants.
  No complete environment, furnished-house preset or paid-tier dependency.

## 3. Verify and close

- [x] Run valid and negative fixtures plus validation of every actually bundled
  asset. Candidates not downloaded remain candidates, not fabricated inventory.
- [x] Import the sample assets in an isolated project and inspect scale/materials.
  Repeat this gate whenever later parts introduce assets; update Credits records.

Verification: 13 Python test methods (including negative cases/subtests), four
manifest entries, 40 isolated Godot import checks and 41 rendered checks passed.
The rendered sample was inspected on X11/Compatibility/Intel UHD 630. Tree and
rock source geometry still needs runtime reduction/LOD; final GPU/XR/performance
acceptance remains part 13. Later acquired assets must repeat these checks.
