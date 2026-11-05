# Welcome island: small test-first roadmaps

**Planned — 2026-11-05.** No implementation or tests are delivered by these plans.
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

Proposed test area: `tests/welcome_island/`, with a disposable-project runner and
focused suites added incrementally. This path does not exist as a delivered suite
yet. Inspect current production dependencies and existing runner conventions first;
never run against real accounts or launch normal startup against real user data.

## Parts and dependency order

All parts are **planned**; none is marked implemented or verified.

| Part | Scope | Prerequisites |
| --- | --- | --- |
| [01](01-offline-foundation-roadmap.md) | Isolated tests and offline startup/home lifecycle | None |
| [02](02-asset-provenance-roadmap.md) | Free asset manifest, license validation and acquisition | 01 |
| [03](03-credits-roadmap.md) | Offline Settings → Credits | 02 |
| [04](04-island-layout-roadmap.md) | One-island graybox, middle spawn and dry routes | 01 |
| [05](05-spawn-recovery-roadmap.md) | Player/item recovery and built-in revision | 04 |
| [06](06-local-interactions-roadmap.md) | Shared offline pickup and activation | 05 |
| [07](07-pond-dock-roadmap.md) | Pond, shoreline safety and dock | 02, 04, 05 |
| [08](08-working-ship-roadmap.md) | Boardable, player-steered ship | 06, 07 |
| [09](09-house-spaces-roadmap.md) | House, lounge, beds and left/right hangouts | 02, 04, 06 |
| [10](10-room-lighting-roadmap.md) | Adjustable house lighting | 06, 09 |
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
