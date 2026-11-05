# 11 — Working kitchen and movable kitchenware

**Status:** Planned. **Prerequisites:** 06, 09.
See the [mandatory test-first workflow](README.md) and [kitchen specification](../offline-welcome-island-roadmap.md#house-chill-spaces-and-kitchen).

## 1. Write tests first — before building

- [ ] Define an exact inventory of at least eight individual movable objects and
  executable checks for pickup/carry/place/drop/reset of each, safe mass/collision
  and recovery to its own counter/shelf. Cover missing inventory and lost props.
- [ ] Test faucet on/off, storage/fridge motion limits, hob on/off/low/high visible
  state, blocked closure/exit and safe reset/shutdown on reload/scene exit.
- [ ] Assert local-only state, no global preferences changed, and bounded effects;
  test any optional kettle before implementing it. Record initial failures.
- [ ] Write seated reach, cookware stability, door safety and visible water/heat
  procedures before implementing fixtures or effects.

## 2. Build only after the tests exist

- [ ] Assemble cleared counters/appliances/props and implement usable controls;
  decoration-only knobs don't qualify. Use cups/dishes/cookware/utensils from
  the approved exact inventory, with stable surfaces and simple collision.
- [ ] Keep water/steam cheap and contained, prevent violent held-object/player
  collisions and provide safe reset. No damage/fire, recipe quests or cooking sim.

## 3. Verify and close

- [ ] Run inventory, pickup, control/reset and provenance tests; confirm appliance
  shutdown and cleanup through repeated transitions.
- [ ] Verify all required objects and controls manually on desktop and seated VR;
  ordinary free play must work with Help hidden and no correct table arrangement.
