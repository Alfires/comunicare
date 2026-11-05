# 02 — Free assets and provenance

**Status:** Planned. **Prerequisites:** 01.
See the [mandatory test-first workflow](README.md) and [asset policy](../offline-welcome-island-roadmap.md#free-asset-research-and-licensing-gate).

## 1. Write tests first — before acquiring/building the asset set

- [ ] Add executable manifest fixtures: valid entries, absent author/source/license,
  missing license file, duplicate IDs, wrong hashes and nonexistent shipped paths.
- [ ] Assert the approved license policy, required attribution/modification notices,
  and consistency with `THIRD_PARTY_ASSETS.md`; reject ambiguous permissions.
- [ ] Define inspection checks for meter scale, normals, foliage alpha, runtime
  texture sizes and original/download versus converted hashes. Record expected
  validation failures before writing the validator or bundling island assets.

## 2. Build only after the tests exist

- [ ] Implement manifest validation and documented local conversion/import steps.
- [ ] Acquire a small cleared tree/rock/material/sky set and individual hull/dock,
  house/furniture/appliance/kitchen candidates as needed by later parts. Prefer
  CC0; verify exact archive terms, not merely “free download” labels.
- [ ] Preserve provenance, notices and full licenses; document runtime variants.
  No complete environment, furnished-house preset or paid-tier dependency.

## 3. Verify and close

- [ ] Run valid and negative fixtures plus validation of every actually bundled
  asset. Candidates not downloaded remain candidates, not fabricated inventory.
- [ ] Import the sample assets in an isolated project and inspect scale/materials.
  Repeat this gate whenever later parts introduce assets; update Credits records.
