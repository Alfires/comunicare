# Welcome island: small test-first roadmaps

[Part 24: gentle terrain relief](24-terrain-relief-roadmap.md) adds grounded
grove/meadow rises while preserving flat circulation and the pond.

[Part 23: rock hull fit](23-rock-hull-fit-roadmap.md) replaces box-corner collision
with cached mesh-derived hulls, preserving placement alignment.

[Part 21: house resource reuse](21-house-resource-reuse-roadmap.md) and
[part 22: facade/rock collision](22-facade-rock-collision-roadmap.md) record the
current house loading cleanup and aligned collision changes.

[Part 20: house comfort](20-house-comfort-roadmap.md) records lighter interior
finishes, lived-in details and mesh-by-mesh exterior assembly.

[Part 19: streamed material reuse](19-streamed-material-reuse-roadmap.md) covers
shared surface materials and incremental upgrades, with current hitch measurements.

[Part 18: material compilation freezes](18-material-freeze-roadmap.md) records the
rendered-heartbeat regression and background runtime-material preparation.

[Part 17: smaller loading slices](17-loading-hitches-roadmap.md) records progressive
grass construction, cached queue priorities and outstanding rendered-load limits.

[Part 16: natural density and stone poses](16-natural-density-roadmap.md) records
the meadow, sheltered planting, young pines and mixed rock placement pass.

[Part 15: dynamic home loading](15-streaming-roadmap.md) records proximity-based
background loading, entry measurements and remaining rendered hitch limitations.

**In progress — 2026-11-06; release blocked.** Part 01's runner/startup fix is implemented with
manual headset/lifecycle gates; part 02 delivers tested provenance and a four-entry
CC0 sample; reduced tree/rock runtime variants now exist. Part 03 Credits is
implemented with a manual headset gate. Part 04 delivers the single-island layout
graybox with physics/capsule and rendered checks; part 05 adds tested spawn/item
recovery and dependency revisions with manual/export gates. Part 06 adds local
pickup/activation and rendered recovery/exported-PCK verification. Part 07 delivers
the pond/dock with synthetic safety checks; part 08 adds constrained local ship
operation with manual XR/UI gates. Part 09 adds the initial furnished house and
side spaces; part 10 adds adjustable local room lighting with XR/performance gates.
Part 11 now has eight premade CC0 kitchenware models and tested local controls,
with fixture/art/hardware gates open. Part 12 adds optional Help with manual XR/playtest and settings
fixture gates. Part 13 has an initial tested composition (final art/performance open);
part 14 has a local matrix/combined acceptance, with release still blocked.
The [shared design overview](../offline-welcome-island-roadmap.md) owns the home-first
requirements, ASCII concepts, asset candidates and compatibility boundaries.
This index and the small roadmaps below replace its original five broad milestones.

## Mandatory workflow for every part

1. **Write tests first.** Before implementing that part, add executable acceptance
   tests and negative cases in disposable fixtures. Run them and record the expected
   failures for missing behavior. Failures must identify the requirement, not an
   unrelated import, syntax or infrastructure error. Existing passing behavior gets
   regression tests too; do not introduce an artificial failure into working code.
2. **Only then build that part.** Implement the smallest scope that satisfies those
   tests. Write a new failing test before adding a behavior not covered initially.
3. **Verify and publish a passing unit.** Re-run tests and prerequisites, perform
   required rendered/manual checks and record failures/skips honestly. Commit the
   implementation together with its tests using Conventional Commits; do not push
   an intentionally failing test-only intermediate snapshot. Stage explicit paths,
   check the staged diff and push to the configured upstream using ordinary Git.

For visual, comfort and performance requirements, write the manual test procedure,
camera positions, target hardware/budgets and pass criteria in step 1 as well as
automated structural/behavior tests. A written checklist alone is not an executable
test, and headless passing tests are not proof of rendering or headset comfort.
Any unfinished manual gate remains explicitly open; it is not a release-ready part.

Delivered test area: [`tests/welcome_island/`](../../../tests/welcome_island/README.md),
with a disposable-project runner and desktop/XR/account groups. Extend focused
suites incrementally. Inspect current production dependencies and runner conventions first;
never run against real accounts or launch normal startup against real user data.

## Parts and dependency order

Part 01 is **implemented with manual gates**; part 02 is **implemented with
asset-selection/runtime limits**; part 03 is **implemented with manual headset gate**;
part 04 is **implemented graybox with manual VR gates**; part 05 is **implemented
with manual/export gates**; part 06 is **implemented with manual interaction/headset
gates**; part 07 is **implemented with manual headset/final-water gates**;
part 08 is **implemented with manual XR/UI gates**; part 09 is **implemented initial
furnished structure with manual XR/art gates**; part 10 is **implemented with manual
XR/performance gates**; part 11 is **partially implemented**; part 12 is **implemented
with manual XR/playtest gates**; part 13 is **initial composition only**; part 14 is
**local matrix implemented, release blocked**. No part's unverified gates are waived.

| Part | Scope | Prerequisites |
| --- | --- | --- |
| [01](01-offline-foundation-roadmap.md) | Implemented: isolated startup tests and persistent-player reuse; actual headset and legacy panel lifecycle gates open | None |
| [02](02-asset-provenance-roadmap.md) | Implemented: manifest/license validation, nature/architecture/furniture/kitchenware sources and optimized runtime variants; later additions repeat the gate | 01 |
| [03](03-credits-roadmap.md) | Implemented: offline read-only Settings → Credits; real-headset validation open | 02 |
| [04](04-island-layout-roadmap.md) | Implemented graybox: one landmass, middle spawn and tested dry routes; real VR/final-art gates open | 01 |
| [05](05-spawn-recovery-roadmap.md) | Shared player/item recovery and dependency revision implemented; isolated Linux debug export passed, real headset recovery open | 04 |
| [06](06-local-interactions-roadmap.md) | Shared local pickup/activation and synthetic rendered carry checks passed; actual headset/carry comfort open | 05 |
| [07](07-pond-dock-roadmap.md) | Implemented: pond, timber dock and safe water recovery; two-eye/headset checks open | 02, 04, 05 |
| [08](08-working-ship-roadmap.md) | Implemented: constrained local board/steer/stop/reset ship; actual headset/UI comfort gates open | 06, 07 |
| [09](09-house-spaces-roadmap.md) | Textured house/lounge/two beds/side hangouts and deliberate rest/leave implemented; manual XR/art gates open | 02, 04, 06 |
| [10](10-room-lighting-roadmap.md) | Three independent local zones with shared UI implemented; manual XR/GPU profiling open | 06, 09 |
| [11](11-kitchen-roadmap.md) | Premade CC0 kitchenware and local controls/reset tested; fixture/door visual polish and seated VR checks pending | 06, 09 |
| [12](12-optional-help-roadmap.md) | Optional live-binding menu Help/session highlight toggle implemented; settings regression later passed, manual XR/playtests open | 06; final text after 08–11 |
| [13](13-landscape-rendering-roadmap.md) | Initial tree/rock composition and rendered checks; final art, human XR and named performance budgets open | 02, 07–11 |
| [14](14-release-acceptance-roadmap.md) | Local matrix/combined no-help lifecycle implemented; release blocked by remaining required gates | 01–13 |

This is dependency order, not a player progression route. Every place and action
is freely available in the finished home. A prerequisite marked manually unverified
does not silently become verified when a later part starts.

All newly bundled assets must join part 02's provenance records and part 03's
Credits coverage, including assets acquired during later parts. Each part updates
its status and this index with actual evidence, while the root roadmap index links
here rather than duplicating fourteen status tables.
