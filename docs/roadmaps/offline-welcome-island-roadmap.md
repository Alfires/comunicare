# Offline welcome island roadmap

## Status and goal

**Planned — 2026-11-05.** No island, asset downloads or Credits UI are delivered
by this roadmap. Replace the built-in default blockout with an original,
hand-assembled floating island: a welcoming introduction to Comunicare that is
also a pleasant place to relax after the introduction is over.

The island must work without a relay, internet connection or downloaded content.
It should teach movement and basic game features through optional, usable
activities rather than a mandatory tutorial corridor. Aim for believable natural
materials and lighting within a deliberately fantastical floating-island setting.

### Non-negotiable requirements

- **One big, continuous flying island**, not several islands or detached playable
  platforms, with trees and an original terrain silhouette.
- The spawn is in the **middle of the island**, on dry, level ground; the pond
  and all activity areas surround this central clearing rather than displacing it.
- A pond with a **working, boardable and steerable small ship**, not a static
  decoration or an inaccessible animated model.
- Assemble the terrain, paths, vegetation and props ourselves using individual
  free premade assets. **Do not import a complete island, environment demo or
  large scene preset as the map.** An asset pack is a parts library, not a layout.
- Include actual interactive objects, not only signs describing interactions.
- Demonstrate lighting and material response without sacrificing VR comfort.
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
        /    shaded overlook ---- loop path ---- shelter  \
       /          |                    |        + lamp     \
      |           |                    |                    |
      |    T      +-------------+------+          T         |
      |                         |                           |
      |                    [ SPAWN ]                        |
      |                  ISLAND MIDDLE                      |
      |                         |                           |
      |   interaction garden ---+---- path ---- dock         |
      |    table / props        |               H ~~~~~~~   |
       \     T              return path        ~ H  /|  ~  /
        \         T                           ~   /_|   ~ /
         '.              T                     ~ \___/ ~.'
           '--.             grassy bank          ~~~~~.-'
               '-------------------------------------'

      T = tree     H = dock     /| + hull = working ship
      ~ = pond water, enclosed by land on this same island
```

### Intended final appearance: side-view ASCII concept

```text
                       trees       central spawn       trees
                      /\   /\          |               /\
                     /__\ /__\       [ + ]    dock     /__\
                 ____ ||__ ||__________|_______H__ /| ___||____
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

The diagram is a planning aid, not a premade layout to download. Sculpt/model
the base ourselves; place individual rocks to break up the cliffs and underside,
blend soil/grass/path materials, and compose trees in clusters with open views.
Use consistent meter scale, material palette and plausible transitions between
soil, roots and stone. Avoid obvious repeated boulder piles as the whole island.

| Place | Purpose and content | Completion condition |
| --- | --- | --- |
| Central clearing | Level, unobstructed spawn; landmark tree beside, not on, the spawn; small welcome sign and choices to explore, show hints or open menu | Player can immediately move or ignore the tutorial; view is not blocked by foliage or UI |
| Movement loop | Broad curved path, gentle slope, optional low steps with an accessible bypass; hints for looking, walking, turning, optional sprint and VR teleport | Both desktop and supported VR locomotion modes can complete the loop without jumping |
| Interaction garden | Stable table, movable objects, reset control and a switch-operated lamp | Player can pick up, move, drop, activate and reset with visible feedback while offline |
| Lighting alcove | Small shaded timber/stone shelter with a warm lamp, rough wood, stone and a restrained metal object | Sun/shade, contact shadows, roughness and reflections are visibly distinct, including with the lamp off |
| Pond and dock | Landscaped pond, shallow readable shoreline, accessible dock and small player-operated ship | Player can board, steer around the pond, stop, return and disembark on desktop and VR without networking |
| Grove and overlook | Trees, rocks, benches, quiet wind/birds and a broad protected view of clouds/underside | A usable relaxing destination with no task marker, timer or forced narration |

Use rock borders, shrubs, railings and generous setbacks to make edges legible.
Provide recovery below the island and a menu-accessible return to spawn. Do not
rely on invisible walls alone. Benches are scenery initially; an actual seating
interaction is optional and must not forcibly move a VR headset.

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
  and return-to-dock. Riding is optional and never gates onboarding completion.
- Disembark only to a validated clear shore/dock location, not into water, trees
  or the void. Falling into the pond safely returns the player to the bank/dock;
  a menu escape/reset works even if the ship is stranded or overturned.
- Reset restores the ship at its berth, clears motion/input and safely releases
  any rider. Scene changes and menu/focus loss must cancel control appropriately.
- Use restrained water reflections, shore contact and ripples as part of the
  lighting showcase; preserve visibility and a low-cost non-SSR fallback in VR.
- Offline ship operation must not require a relay lease. In online home sessions,
  clearly mark it local-only unless authorized synchronized rider/vehicle ownership
  is implemented and verified; do not introduce a vehicle protocol in this plan.

## Optional onboarding and interaction design

1. **Arrive:** “Welcome. Explore at your own pace.” Show a short hint for opening
   the real menu. Offer hide/replay hints; never require completing tasks to play.
2. **Move:** nearby prompts demonstrate look, move and turn. Read current saved
   bindings and XR mode/profile; do not bake keys/controller icons into textures.
   Show sprint only where supported and teleport instructions only in that mode.
3. **Try objects:** provide at least two lightweight, bounded physical props
   (for example a wooden block and small stone), clear target surfaces and a
   reset button. Keep physics away from spawn and the cliff edge.
4. **Try light:** activate a fixed lamp switch, then compare its warm illumination
   on rough/reflective surfaces. The lamp must actually change illumination, not
   just its emissive appearance. Bound brightness and avoid flashing/strobing.
5. **Find game features:** optional station opens existing Settings, avatar/emote
   and world/instance menus where available. Explain that meeting people needs
   a connection; mark unavailable network actions clearly. Never simulate a
   successful join, friendship or remote player in an offline tutorial.
6. **Try the ship (optional):** follow the dry path to the dock, board, steer a
   short loop and return. Explain stop/disembark/reset before moving; users who
   prefer not to ride can enjoy the pond from the bank.
7. **Stay:** dismiss hints and enjoy the grove. No forced transfer to an online
   world, automatic microphone enable or completion telemetry.

Desktop and VR must share interaction semantics: aim/highlight, activate,
pick up/drop, cancel and reset. Reuse existing binding/settings owners. Resolve
actual VR controller support during the first interaction spike, and only show
controls that work. Local interaction is required even without authentication;
network ownership/lease messages must not be required for offline props.

Hints should be short, readable at comfortable distance and non-color-only.
Support seated reach and desktop aiming; suppress world interaction while menus
capture input. Keep onboarding state session-local initially, with hide/replay
available; persistent progress would need a separately reviewed registry-owned
preference, not writes into account/profile/friend files.

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

## Delivery milestones and verification

Each checkbox is a coherent, independently verified future implementation part.
Use Conventional Commits and the repository's ordinary Git publication rules.
For bug fixes, first reproduce the failure with a test. Do not commit unrelated
existing player, animation or test changes along with island work.

### 1. Offline integration and graybox

- [ ] Add an isolated welcome-world test runner with disposable user data; reproduce
  blocked/offline startup, spawn or reset failures before fixing them.
- [ ] Keep `scenes/world.tscn` as the compatible entry point and preserve its UID;
  split authored content into focused island subscenes/resources as needed.
- [ ] Block out the original island, center spawn, paths, shelter and safe edges.
  Test capsule clearance, slopes, desktop movement and VR teleport surfaces.
- [ ] Keep one continuous landmass with the spawn in its middle; graybox the pond,
  sealed pond bed, dry perimeter route, dock and ship turning clearance.
- [ ] Share a spawn/reset contract across direct startup, DataLoader activation
  and fall recovery; preserve root-level player lifetime, XR tracking offsets and
  cleared movement velocity. Reset items to their own homes, not the player's head.
- [ ] Make the built-in revision include relevant shipped dependency changes with
  deterministic local packaging/manifest generation; retain revision mismatch checks.

**Gate:** with networking unavailable, island and menu are usable without waiting
for relay timeout; repeated falls/returns do not duplicate players or leave props
moving, and `default_wold` still resolves through DataLoader.

### 2. Asset spike and Credits foundation

- [ ] Acquire a minimal cleared tree, rock, ground material, table and sky set;
  inspect imports, scale, normals, foliage alpha, license files and redistribution.
- [ ] Select a free cleared ship hull and individual dock components; record exact
  sources/licenses and test suitable scale, collision proxies and water material.
- [ ] Establish original terrain authoring/export steps, asset provenance manifest,
  source/license storage and reduced runtime variants. No opaque imported map.
- [ ] Implement the read-only Credits page and manifest/license consistency tests.

**Gate:** reproduce the small sample scene from documented sources/conversions;
Credits and full notices work offline in desktop UI and the VR viewport.

### 3. Real interactions and gentle onboarding

- [ ] Spike existing `world_pickup_controller.gd`/runtime integration before choosing
  a shared local adapter or validated built-in document. Reuse behavior where safe;
  do not weaken downloaded-world validation or add relay dependencies for offline use.
- [ ] Deliver pickup/drop/reset props plus an activatable lamp switch, including
  aim feedback, reach limits, collision, cancellation and bounded velocities.
- [ ] Deliver offline ship boarding, player steering, stopping, safe disembarking,
  rider support and return-to-dock/reset. Test pond/shore collision, lost focus,
  scene exit and VR comfort; do not substitute a decorative animated ship.
- [ ] Add optional device/binding-aware hints, replay/hide controls and links to
  real menus. Verify remapping and menu/focus suppression.
- [ ] Keep tutorial progress and lamp demonstrations local. If this same built-in
  scene is joined online, either use existing authorized synchronized ownership
  or explicitly label demo objects local-only; never imply unimplemented sync.

**Gate:** a new desktop user and a seated VR user can try every required action
without internet, enabling the microphone, changing preferences or completing
earlier tasks. Reset recovers all props, including lost/held objects, and safely
returns the ship and rider to the dock. The ship is optional to try, not optional
to implement.

### 4. Hand-assembled landscape and lighting pass

- [ ] Replace the graybox with our own terrain and individual asset placements;
  compose the grove, underside, roots, overlooks and quiet destinations.
- [ ] Add consistent PBR materials, shadows, restrained ambience and the lighting
  alcove. Test sunlight/shade and lamp-on/off comparisons with moving props.
- [ ] Finish the pond banks, bed, dock and ship materials; verify waterline,
  reflections and hull contact in both XR eyes without costly required effects.
- [ ] Optimize vegetation, collision, LODs and lighting against measured budgets;
  retain a readable lower-cost configuration and accessible traversal routes.

**Gate:** rendered views from spawn, grove, alcove and overlook show a coherent
floating island, not a kit demo. Manual desktop and headset walkthroughs confirm
readable hints, comfortable reach/locomotion, safe recovery and stable performance.

### 5. Regression and release acceptance

- [ ] Automate scene/load dependencies, spawn clearance, repeated scene changes,
  fall/item reset, interaction cleanup, hint rebinding and Credits completeness.
- [ ] Add ship control/reset/lifecycle tests, invalid disembark rejection, shoreline
  containment and safe pond recovery. Manually verify moving rider stability and
  comfortable boarding/steering on desktop and an actual headset.
- [ ] Run relevant isolated suites: microphone/settings, active instance, public
  discovery, safe worlds, VR controls and real UI; inspect their current runners
  and prerequisites first. Report failures/skips without claiming full coverage.
- [ ] Check offline launch with blocked relay/DNS in a disposable profile and no
  asset cache; check corrupt-account handling without touching real accounts.
- [ ] Check entering/leaving an online instance and returning home: player/UI
  survive correctly, local props cannot affect another instance, and session
  identifiers/admission/acknowledged transition behavior remain unchanged.
- [ ] Record hardware-specific renderer/XR results and screenshots; document
  remaining limitations. Update current user guides and this roadmap's index status.

**Done means:** the old default blockout is replaced, the island works offline
from bundled content, it is one big island with the spawn in the middle, the pond
has a working player-steered ship, spawn/recovery are reliable, all required
interactions work on desktop/VR, tutorials are optional, Credits is complete,
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
