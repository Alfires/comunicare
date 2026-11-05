# Offline welcome island roadmap

## Status and goal

**In progress — 2026-11-05.** Part 01's isolated startup tests and player-reuse fix
are implemented with manual gates. Part 02 delivers provenance validation and four
bundled CC0 nature/sky samples, now with reduced runtime tree/rock variants. Part 03
delivers offline Credits with manual headset checks open. Part 04 delivers the
island layout graybox, not final art or interactions. This file is the **shared design overview**; implementation is
split into [14 small test-first roadmaps](welcome-island/README.md), whose index
owns dependency order and per-part status. Replace the built-in default blockout with an original,
hand-assembled floating island: **a good home first**, where players can naturally
discover Comunicare through things they choose to do. It must feel worth returning
to, not like a tutorial level that has served its purpose after one visit.

The island must work without a relay, internet connection or downloaded content.
Learning movement and basic game features is a side effect of exploring and using
the home, not the map's visible theme. Aim for believable natural
materials and lighting within a deliberately fantastical floating-island setting.

### Non-negotiable requirements

- **One big, continuous flying island**, not several islands or detached playable
  platforms, with trees and an original terrain silhouette.
- The spawn is in the **middle of the island**, on dry, level ground; the pond
  and all activity areas surround this central clearing rather than displacing it.
- A pond with a **working, boardable and steerable small ship**, not a static
  decoration or an inaccessible animated model.
- Furnish both the left and right sides with places to spend time, without
  crowding the central spawn or making the island a row of activity stations.
- Include a hand-assembled **house with a chill/lounge area, beds, a usable
  kitchen, adjustable room lighting and multiple pickupable kitchen objects**.
- Assemble the terrain, paths, vegetation and props ourselves using individual
  free premade assets. **Do not import a complete island, environment demo or
  large scene preset as the map.** An asset pack is a parts library, not a layout.
- Include actual interactive objects, not only signs describing interactions.
- No generic tutorial stations, floating control billboards, numbered objectives,
  material test displays or forced sightseeing route. No visible debug primitives
  or stock feature-showcase scenery in the finished home.
- Give players freedom to wander, ride, play with objects or simply stay still;
  no task order, completion score or prompts that keep asking them to progress.
- Show lighting and material quality through the home itself, without a labeled
  tech-demo area or sacrificing VR comfort.
- Bundle all required runtime content; no first-launch asset fetch or web tutorial.
- Add **Settings → Credits**, including every mandatory asset attribution and
  optionally acknowledging CC0 contributors too. Use the correctly spelled UI
  label “Credits.”
- Preserve existing accounts, settings, key bindings and `default_wold` spelling.

## Inspected implementation baseline

- `scripts/startup/main.gd` loads the persistent desktop/VR player and changes
  directly to `scenes/world.tscn`; initial relay connection runs separately on
  `NetworkHandler`. Do not introduce a relay wait before the island or menus.
- `scenes/world.tscn` currently contains primitive platforms, a sky/light, a
  below-world reset area and a `VRPanel`. Inspect that panel's camera/viewport
  purpose before replacing it; retain necessary UI behavior rather than copying
  an unexplained panel into the finished landscape.
- `scenes/world.gd` currently resets entering bodies to `(0, 1, 0)` and only clears
  rigid-body linear velocity. A proper player/item reset needs explicit handling.
- `scripts/startup/data_loader.gd` also resolves `default_wold` to that scene,
  stages spawn `[0, 1, 0]`, and hashes only `scenes/world.tscn` for the built-in
  revision. Moving content into subscenes requires a revision strategy covering
  the shipped dependencies, not a stale wrapper-scene hash.
- DataLoader starts safe-world runtime/pickup services only when the staged world
  includes a document. Merely placing physical props in a native built-in scene
  does **not** establish working offline pickup or switch behavior.
- `scripts/GUI/settings_menue.gd` constructs categories from registry definitions.
  Credits needs a read-only page integrated with its navigation; it is not a fake
  saved setting or a new boolean in `settings_registry.gd`.
- The built-in home can also be selected for online sessions. Offline tutorial
  state must not automatically create/join a session or change instance rules.

These are integration constraints, not claims that the planned features exist.

## Experience and original layout

Working title: **Sky Grove**. Start with one approximately 100–120 m wide island
and a roughly 25–35 m wide pond with room to steer a small ship. These are initial
graybox dimensions; adjust after testing movement and the ship's turning circle.
Keep the spawn at the island's plan-view center, not at the center of a side area.
Use a broad walkable upper surface, an asymmetric tapered rocky underside,
overhanging roots and a cloud backdrop that clearly communicates floating height.
No required jumping, narrow balance obstacles or lethal edge challenges.

### Intended final appearance: top-down ASCII concept

```text
                                  NORTH
                     ONE BIG FLOATING ISLAND
               .-----------------------------------.
           .--'       T   T   QUIET GROVE   T       '--.
         .'       T      bench       T       T          '.
         /  LEFT: shaded deck ---- garden path --- HOUSE    \
        /   bench / cushions           |       lounge / beds \
       |         |                     |       kitchen / porch|
       |    T    +---------------+-----+          |     T     |
       |                         |          RIGHT: herb beds  |
       |                    [ SPAWN ]        shore seating   |
       |                  ISLAND MIDDLE          |           |
       |                         |               |           |
       |   picnic garden --------+---- path ---- dock        |
       |    table / lantern      |               H ~~~~~~~   |
        \     T               meadow path       ~ H  /|  ~  /
        \         T                           ~   /_|   ~ /
         '.              T                     ~ \___/ ~.'
           '--.             grassy bank          ~~~~~.-'
               '-------------------------------------'

      T = tree     H = dock     /| + hull = working ship
      ~ = pond water, enclosed by land on this same island
```

### Intended final appearance: side-view ASCII concept

```text
                       trees       central spawn        house
                      /\   /\          |                /\
                     /__\ /__\       [ + ]    dock     /__\
                 ____ ||__ ||__________|_______H__ /| __|[]|___
                / grass / soil / continuous land  \_|          \
               /                         pond ~~~\___/~~~       \
              / rock layers __________ pond bed __________       \
              \        roots       \             /       rock   /
               \  fractured stone   \___________/              /
                \                 rocky underside             /
                 \______        __________       ____________/
                        \______/          \_____/

           ~ clouds ~           open sky          ~ clouds ~
```

These sketches show composition, not construction measurements. The pond is a
recess in the upper surface with a sealed bed; it does not divide the island or
drain into space. All land destinations connect by broad dry paths. The ship
stays inside the pond, and no secondary island is needed for a destination.
Names such as “spawn” label this design document only: the finished clearing has
no giant spawn marker or tutorial signage. Paths branch and reconnect for casual
wandering; their arrangement must not imply an ordered course to complete.
Left/right refer to this north-up plan: the left side has a shaded lounging deck,
picnic garden and grove overlook; the right side has the house, herb garden,
shore seating and pond dock. Keep both sides interesting with natural details
and usable belongings, while preserving an open middle and continuous dry paths.

The diagram is a planning aid, not a premade layout to download. Sculpt/model
the base ourselves; place individual rocks to break up the cliffs and underside,
blend soil/grass/path materials, and compose trees in clusters with open views.
Use consistent meter scale, material palette and plausible transitions between
soil, roots and stone. Avoid obvious repeated boulder piles as the whole island.

| Place | Purpose and content | Completion condition |
| --- | --- | --- |
| Central clearing | Level, unobstructed middle spawn framed by meadow and a nearby landmark tree; views toward several equally inviting places | Player immediately chooses any direction or stays; no sign, checklist or UI wall dominates arrival |
| Garden paths and meadow | Broad branching paths, gentle slopes, optional low steps with accessible bypasses and open grass to wander off-path | Desktop and supported VR locomotion can reach every destination without jumping or following a prescribed route |
| Picnic garden | Stable table, a few believable movable belongings and a lantern; recovery available through contextual/menu actions | Objects feel useful for hanging out or free play, not like a row of interaction exercises; pickup/drop/reset works offline |
| Cozy shelter | Timber/stone nook with warm switchable lighting, weathered wood and ordinary metal fittings | A place to linger; sunlight, shade and material response look good without labeled swatches, test spheres or comparison instructions |
| Left-side lounging deck | Low shaded deck, cushions, bench, side table and a few movable books or game pieces near the grove | Comfortable informal destination with accessible ground-level entry and no timed activity or forced seating |
| House and right-side garden | Lounge, sleeping nook with beds, kitchen, porch, herb beds and pond-facing seating | All rooms are accessible; lighting/kitchen controls and pickupable belongings work offline without displacing the middle spawn |
| Pond and dock | Landscaped pond, shallow readable shoreline, accessible dock and small player-operated ship | Player can board, steer around the pond, stop, return and disembark on desktop and VR without networking |
| Grove and overlook | Trees, rocks, benches, quiet wind/birds and a broad protected view of clouds/underside | A usable relaxing destination with no task marker, timer or forced narration |

Use rock borders, shrubs, railings and generous setbacks to make edges legible.
Provide recovery below the island and a menu-accessible return to spawn. Do not
rely on invisible walls alone. Benches are scenery initially; an actual seating
interaction is optional and must not forcibly move a VR headset.

### House, chill spaces and kitchen

Build the house ourselves from individual cleared structural and furnishing
assets, not a furnished-house scene preset. Match the timber/stone exterior to
the island and keep the footprint modest enough for open views and paths around
the middle. Start with a single accessible level, generous doorways, flush
thresholds and clear teleport/standing space; do not require stairs to reach a bed
or appliance. The outside shelter remains a small garden nook, not a duplicate
feature-demo room.

```text
                 HOUSE: plan, not a downloaded prefab
       .------------------------------------------------.
       | SLEEPING NOOK           | KITCHEN                |
       | [bed]   [bed]           | counter  sink  hob     |
       | bedside lamp / dimmer   | mugs / dishes / pans   |
       |                         | fridge    shelves     |
       |---- open circulation ---+--- dining table ------|
       | LOUNGE / CHILL AREA                             |
       | sofa   cushions   low table   warm floor lamp    |
       |                         clear entry             |
       '---------------------------    ------------------'
                                   porch --> herb beds / pond
```

- **Chill region:** provide a sofa, cushions, low table, reading/game belongings,
  soft lamps and a view outside. Support simply standing, talking or relaxing;
  do not attach a lesson or objective to the furniture.
- **Beds:** provide at least two furnished beds with bedside lighting. They are
  usable resting places; optional explicit Sit/Rest and Leave actions must retain
  an easy exit, preserve XR tracking offsets and never force lying-down head
  rotation. No mandatory sleeping, time skip or change to the central spawn.
- **Adjustable lighting:** lounge, sleeping nook and kitchen each have reachable
  on/off and brightness controls, plus bounded warm/neutral color-temperature
  adjustment where appropriate. Controls must change actual illumination, give
  immediate feedback and work with desktop aim and VR pointers. Avoid rapid
  flicker, blinding minimum/maximum values and excessive shadowed lights.
- **Working kitchen controls:** include an operable faucet with a contained water
  effect, openable fridge/cabinet doors or drawers, and a hob with on/off plus
  bounded low/high heat indication. Controls change visible state rather than
  being decorative knobs. A kettle may be a simple toggleable appliance with
  quiet steam/indicator feedback; a cooking/food simulation is not required.
  Keep water/steam cheap, avoid forced loud sounds and do not add damage/fire.
- **Pickupable kitchen belongings:** aim for at least eight individual movable
  items across mugs/cups, plates/bowls, a pot, pan, kettle, spoon/spatula and
  cutting board or food props. A named inventory of at least eight shipped items
  is the acceptance list; not every listed category has to ship. Use plausible
  mass/scale, simple collision, stable resting surfaces and accessible placement.
  No scoring, recipes or required arrangement; let people set the table or play.
- **Reliable interaction:** allow pickup, carry, place/drop and contextual reset;
  prevent held cookware colliding violently with the player or launching furniture.
  Door/drawer motion must not trap players or block safe exit. Reset restores
  belongings to their own shelves/counters and switches appliances safely off.
- **State ownership:** room lighting/appliance state starts session-local and
  resets predictably on home reload; persistence is not promised. Do not repurpose
  global audio/renderer settings for kitchen knobs. Any future saved home controls
  need reviewed registry/store ownership. Online local-only behavior follows the
  same clear contextual/menu disclosure as the ship and other belongings.

Acquire free, redistribution-cleared beds, seating, modular house parts,
appliances and individual kitchen props under the asset gate below. Record exact
sources and required credits before bundling; these additions do not authorize a
paid pack or complete house/island preset. Prefer matching materials over a large
mismatched prop collection.

### Pond and working ship

- Use a small pond-scale launch/ship rather than a full-size ocean vessel. Obtain
  a free, redistribution-cleared premade hull and suitable dock parts separately;
  assemble the dock, shore and pond ourselves. Exact asset selection is pending
  the same provenance/license gate as trees and materials.
- Provide explicit board, steer/throttle, stop, disembark and reset actions with
  current desktop/VR bindings. Do not call a ship “working” just because it bobs
  or follows an automatic route. Player control is required; autopilot is optional.
- Use bounded local watercraft movement with stable buoyancy or a constrained
  water-surface model, hull/shore collision and a low speed/turn-rate limit. Full
  ocean simulation, sails and swimming are not required for this pond.
- Keep the rider supported without sliding or physics jitter. In VR, boarding
  requires confirmation, preserves tracked head offsets and uses a brief comfort
  transition; never force head rotation, roll or camera bob. Offer immediate stop
  and return-to-dock. Riding is optional; there is no onboarding completion gate.
- Disembark only to a validated clear shore/dock location, not into water, trees
  or the void. Falling into the pond safely returns the player to the bank/dock;
  a menu escape/reset works even if the ship is stranded or overturned.
- Reset restores the ship at its berth, clears motion/input and safely releases
  any rider. Scene changes and menu/focus loss must cancel control appropriately.
- Use restrained water reflections, shore contact and ripples to make the pond
  feel believable; preserve visibility and a low-cost non-SSR fallback in VR.
- Offline ship operation must not require a relay lease. In online home sessions,
  clearly mark it local-only unless authorized synchronized rider/vehicle ownership
  is implemented and verified; do not introduce a vehicle protocol in this plan.

## Home-first freedom and unobtrusive learning

The following are independent possibilities, **not tutorial steps**. All are
available immediately, in any order, and none is a task to finish.

- **Arrive and choose:** an uncluttered view from the middle offers the grove,
  house, shaded deck, shelter, picnic garden and pond as natural destinations. No welcome modal,
  quest marker, arrows, forced camera turn or automatic tour.
- **Wander or do nothing:** the terrain naturally provides walking, turning and
  teleport opportunities without a movement practice zone. Open grass and
  branching paths allow improvisation; resting is as valid as exploring.
- **Make the space feel lived in:** place at least two movable everyday objects
  such as a wooden cup and a small game piece among believable belongings, not
  numbered blocks on pedestals. Let users move and play with them without a
  target arrangement, score or “correct” result. Keep physics away from spawn
  and the cliff edge; make recovery available without a prominent reset kiosk.
- **Enjoy the shelter:** a normal switch or lantern control changes actual light,
  not just emissive appearance. Warm light on the table and fittings showcases
  quality naturally; never ask users to compare roughness swatches. Bound
  brightness and avoid flashing/strobing.
- **Use their home:** adjust the house lights, relax in the lounge or by a bed,
  open the kitchen cupboards, use appliance controls and move dishes around.
  These are ordinary home affordances, not a kitchen tutorial or cooking quest.
- **Use the pond as they like:** board and steer freely, remain at the dock or
  enjoy the bank. No prescribed loop, checkpoint, lap time or ship lesson. On
  deliberate boarding, make stop/disembark/return controls readily available.
- **Find help when wanted:** keep Settings, avatar/emote and world/instance access
  in the existing menu rather than feature-demonstration stations in the garden.
  Offer a clearly discoverable Help/Controls entry with current bindings. A single
  dismissible menu-key hint may appear on first arrival; no repeating reminders.
  Explain offline restrictions in the relevant menu, never through fake successful
  joins, friendships or remote players.
- **Come home again:** no forced online transfer, automatic microphone enable,
  completion telemetry or “tutorial finished” state. The full island remains a
  useful place to return to after learning the controls.

Desktop and VR must share interaction semantics: aim/highlight, activate,
pick up/drop, cancel and reset. Reuse existing binding/settings owners. Resolve
actual VR controller support during the first interaction spike, and only show
controls that work. Local interaction is required even without authentication;
network ownership/lease messages must not be required for offline props.

Contextual affordances should be short, readable at comfortable distance and
non-color-only. Show only the action for an intentionally aimed/reached object,
not labels over everything nearby; allow these hints to be hidden. Extended
movement/feature explanations are opt-in through Help, not proximity-triggered
lessons. Resolve text/icons from current bindings and XR mode/profile rather
than baking defaults into scenery. Support seated reach and desktop aiming;
suppress world interaction while menus capture input. Keep help visibility
session-local initially, with show/hide available; persistent preferences would
need a separately reviewed registry-owned setting, not writes into account,
profile or friend files. Do not track tutorial progress.

## Free asset research and licensing gate

Sources researched on **2026-11-05**. These are candidates, not downloaded,
tested or approved bundled files. Verify each selected download and its included
license before adding it; record the exact creator from the asset page/archive.

| Candidate | Planned use | License/source |
| --- | --- | --- |
| [Poly Haven Pine Tree 01](https://polyhaven.com/a/pine_tree_01) | Hero tree and limited grove instances; simplify foliage and make LOD variants | CC0; [publisher terms](https://polyhaven.com/license) |
| [Poly Haven nature models](https://polyhaven.com/models/nature) | Individually selected rocks, fallen wood and ground plants; exact IDs chosen during visual spike | CC0; select parts only, not a finished environment |
| [Poly Haven Round Wooden Table 02](https://polyhaven.com/a/round_wooden_table_02) | Candidate interaction table; reject if style or geometry cost does not fit | CC0; publisher terms above |
| [ambientCG Grass004](https://ambientcg.com/view?id=Grass004) and [Ground022](https://ambientcg.com/view?id=Ground022) | Grass/soil PBR surface candidates for our own terrain and paths | CC0; [publisher license](https://docs.ambientcg.com/license/) |
| [Poly Haven Kloofendal 48d Partly Cloudy (Pure Sky)](https://polyhaven.com/a/kloofendal_48d_partly_cloudy_puresky) | Sky/ambient lighting candidate without a photographed ground horizon | CC0; publisher terms above |

Prefer CC0 assets: both publishers explicitly allow commercial use, modification
and redistribution without required attribution. Still include useful voluntary
credits. A “free download” without clear redistribution rights is not acceptable.
Do not use paid tiers, editorial-only, noncommercial or no-derivatives assets.
CC BY 4.0 is an optional exception only after preserving its attribution, license
and modification notices; reject ambiguous terms. Audio selection remains open:
choose documented CC0 recordings or omit ambience until a cleared source exists.

For every shipped asset, preserve source URL, author, license identifier/full
terms, retrieval date, original filename/hash, shipped path/hash and conversion
notes (decimation, resizing, material edits, audio trimming). Extend
`THIRD_PARTY_ASSETS.md` as the human-readable provenance authority; add a local
machine-readable manifest and license files for validation/UI. Keep the entries
consistent through a check or shared generation process. Do not list candidates
as bundled assets before they are actually acquired.

### Settings → Credits

- Always accessible offline from the existing desktop and VR settings navigation.
- Read-only, scrollable, comfortably sized content grouped by world models,
  materials, sky, audio and other bundled assets; include existing third-party
  assets, not just this island's future additions.
- Show asset title, creator, source, license, required attribution and modification
  notices. Include full bundled license text access without fetching a website.
- Links open only on explicit user action, never as an automatic request.
- Do not show “Reset category” or write Credits to the settings store. Preserve
  selection/re-render behavior and existing registry-defined categories.
- Test the displayed entries against the bundled manifest and mandatory notices.

## Rendering, sound and performance

Use the project's Godot 4.7 Forward Plus/Jolt configuration. Target a warm,
consistent daylight composition with readable shaded areas, physically plausible
PBR roughness and restrained reflections. Align the directional sun with the
chosen sky; avoid duplicate suns, pitch-black shade and blown-out metal highlights.
Use baked lighting for static geometry where suitable and a small bounded dynamic
lamp for the interaction. Confirm movable props remain convincingly lit.

Do not make readability depend on SSR, volumetric fog, expensive real-time GI or
strong bloom. Provide a simple sky/fog fallback and test both XR eyes for lighting
and reflection artifacts. No forced time-of-day cycle, camera shake or head bob.
Soft wind/leaf motion must not move the entire scene. Audio is quiet, volume-owned
and never turns on capture or changes the saved microphone mute state.

Starting budgets to validate, not promised performance: mostly 1K–2K materials,
shared textures, LODs for trees/rocks, instanced noninteractive vegetation, simple
collision proxies, one shadowed sun and at most two nearby dynamic local lights.
Measure triangles, draw calls, GPU/CPU frame time, VRAM and load time on named
desktop/headset hardware before increasing detail. Record headset refresh rate
and meet its frame budget (for example 11.1 ms at 90 Hz); do not infer XR readiness
from headless checks. Reduce foliage overdraw/shadows first if the budget fails.

## Delivery plan and completion

The original five broad milestones are **superseded** by the
[small-roadmap index](welcome-island/README.md). Use that index for execution
order, prerequisites, mandatory test-first rules and status; this overview retains
the design contract rather than a competing implementation checklist.

Every small roadmap starts with **writing executable tests and running them before
building its feature**. Define manual visual/XR procedures at that same first step.
Then implement, rerun tests and perform required manual checks. New integration
bugs need reproducing tests before fixes too. Do not publish failing intermediate
snapshots or include unrelated player, animation or user changes.

The parts cover offline foundation, asset provenance, Credits, island layout,
recovery/revisions, local interactions, pond/dock, ship, house/side spaces, room
lighting, kitchen, optional Help, landscape/rendering and final release acceptance.
Part 01 is implemented with manual gates; part 02 delivers provenance/sample assets
with runtime limits; part 03 delivers Credits with a manual headset gate;
part 04 delivers the tested layout graybox; parts 05–14 remain planned. See the
index for evidence and outstanding checks rather than inferring completion.

**Done means:** the old default blockout is replaced, the island works offline
from bundled content, it is one big island with the spawn in the middle, the pond
has a working player-steered ship, spawn/recovery are reliable, all required
interactions work on desktop/VR, both sides offer places to linger, and the house
has a lounge, beds, working kitchen controls, adjustable lighting and pickupable
kitchen belongings. Help is optional and unobtrusive, the island is
an enjoyable reusable home without tutorial signage or task progression, Credits is complete,
and measured visual/performance gates pass. A screenshot or headless test alone
does not satisfy this release gate.

## Boundaries and dependencies

This is not a new remote world format, multiplayer protocol, terrain plugin,
avatar system or mandatory onboarding/account workflow. Use trusted application
code for the bundled world without expanding what downloaded worlds may execute.
If a desired shared-world feature is unavailable, document a local-only adapter
or defer that feature rather than waiting for the entire
[safe world roadmap](safe-world-system-roadmap.md). Existing
[VR controls](../guides/vr-controls.md), settings ownership and the
[relay lifecycle contract](../relay-data-lifecycle.md) remain authoritative.
