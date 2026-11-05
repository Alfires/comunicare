# 13 — Original landscape, atmosphere and performance

**Status:** Planned. **Prerequisites:** 02, 07–11.
See the [mandatory test-first workflow](README.md) and [rendering policy](../offline-welcome-island-roadmap.md#rendering-sound-and-performance).

## 1. Write tests first — before building

- [ ] Add executable scene/resource tests for shipped dependencies, collision/LOD
  setup, approved material/texture budgets, bounded light counts and optional audio
  cleanup/volume ownership. Preserve layout, center spawn and route tests.
- [ ] Write named camera/view procedures for spawn, grove, deck, house, pond and
  underside; require no final debug geometry or test-swatch scenery.
- [ ] Define named desktop/headset configurations, load/frame/VRAM measurements,
  target refresh budget, both-eye water/reflection checks and a non-SSR fallback.
- [ ] Record graybox failures and measured baseline before final art/optimization.
  No headless substitute for GPU, art-quality or comfort evidence.

## 2. Build only after the tests exist

- [ ] Sculpt the original terrain/underside and hand-place cleared rocks, roots,
  trees and belongings. Match scale/palette; never import a complete island preset.
- [ ] Finish daylight/PBR, warm interior light, restrained water and cleared optional
  ambience. Optimize foliage overdraw, instancing, LODs, shadows and collision.
- [ ] Keep CPU/GPU effects and dynamic physics bounded; don't alter mic mute/capture.

## 3. Verify and close

- [ ] Run resource/layout/provenance regressions, then capture actual rendered
  screenshots and measured desktop/XR results against the prewritten criteria.
- [ ] Confirm every area is inviting with hints hidden and not a tech-demo exhibit.
  Record unsupported hardware/skips honestly; unmet budgets remain open gates.
