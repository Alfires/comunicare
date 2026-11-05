# Welcome island: small test-first roadmaps

**In progress — 2026-11-05.** Part 01's runner/startup fix is implemented with
manual headset/lifecycle gates; part 02 delivers tested provenance and a four-entry
CC0 sample; reduced tree/rock runtime variants now exist. Part 03 Credits is
implemented with a manual headset gate. Part 04 delivers the single-island layout
graybox with physics/capsule and rendered checks; part 05 adds tested spawn/item
recovery and dependency revisions with manual/export gates. Part 06 adds local
pickup/activation and rendered recovery/exported-PCK verification. Part 07 delivers
the pond/dock with synthetic safety checks; part 08 adds constrained local ship
operation with manual XR/UI gates. Part 09 adds the initial furnished house and
side spaces; part 10 adds adjustable local room lighting with XR/performance gates.
Parts 11–14 remain planned.
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
XR/performance gates**; parts 11–14 remain **planned**.

| Part | Scope | Prerequisites |
| --- | --- | --- |
| [01](01-offline-foundation-roadmap.md) | Implemented: isolated startup tests and persistent-player reuse; actual headset and legacy panel lifecycle gates open | None |
| [02](02-asset-provenance-roadmap.md) | Implemented: manifest/license validator and inspected four-entry CC0 nature/sky sample; later props and runtime optimization pending | 01 |
| [03](03-credits-roadmap.md) | Implemented: offline read-only Settings → Credits; real-headset validation open | 02 |
| [04](04-island-layout-roadmap.md) | Implemented graybox: one landmass, middle spawn and tested dry routes; real VR/final-art gates open | 01 |
| [05](05-spawn-recovery-roadmap.md) | Implemented: shared player/item recovery and dependency revision; real-headset/export verification open | 04 |
| [06](06-local-interactions-roadmap.md) | Implemented: shared local pickup/activation; actual headset and rendered carry checks open | 05 |
| [07](07-pond-dock-roadmap.md) | Implemented: pond, timber dock and safe water recovery; two-eye/headset checks open | 02, 04, 05 |
| [08](08-working-ship-roadmap.md) | Implemented: constrained local board/steer/stop/reset ship; actual headset/UI comfort gates open | 06, 07 |
| [09](09-house-spaces-roadmap.md) | Initial furnished house/lounge/two beds/side hangouts implemented; optional rest action and manual XR/art gates open | 02, 04, 06 |
| [10](10-room-lighting-roadmap.md) | Three independent local zones with shared UI implemented; manual XR/GPU profiling open | 06, 09 |
| [11](11-kitchen-roadmap.md) | Working kitchen and pickupable kitchenware | 06, 09 |
| [12](12-optional-help-roadmap.md) | Minimal contextual actions and opt-in Help | 06; final text after 08–11 |
| [13](13-landscape-rendering-roadmap.md) | Hand-built landscape, atmosphere and optimization | 02, 07–11 |
| [14](14-release-acceptance-roadmap.md) | Full offline/home/online-return acceptance | 01–13 |

This is dependency order, not a player progression route. Every place and action
is freely available in the finished home. A prerequisite marked manually unverified
does not silently become verified when a later part starts.

All newly bundled assets must join part 02's provenance records and part 03's
Credits coverage, including assets acquired during later parts. Each part updates
its status and this index with actual evidence, while the root roadmap index links
here rather than duplicating fourteen status tables.
