# Roguelike demo world roadmap

## Status and interpretation

**Proposed — 2026-11-05. No game implementation or assets delivered by this plan.**
**Revised for the world-system update:** target safe packaged gameplay, client-local
player progression, custom leveling menus and matching combat/world animations.
This supersedes the original bundled-only delivery and no-persistence proposal.
Interpret the request's “roadlike” as **roguelike**: a small replayable dungeon
with randomized rooms, simple combat, loot choices and a run that ends on death.
The proposed presentation is detailed, high-quality **3D dark fantasy**, not a
low-poly art style, compatible with Comunicare's desktop
and VR players, rather than a separate 2D game or a driving world.

Working title: **Ember Crypt**. Deliver a polished, playable 20–30 minute solo demo
in a new optional world. Keep the welcome island and `default_wold` unchanged.
This is a small action roguelike, not a traditional turn-based roguelike.
**Expanded-map revision:** the original six-room/5–10 minute scope is superseded
by a connected explorable landscape and crypt, working enemy encounters and
distributed leveling menus. This remains a roadmap, not delivered gameplay.

## 1. Playable scope

- Enter a safe camp, choose **Start run**, explore a connected field, ruins and crypt,
  defeat enemies, choose upgrades, defeat a guardian and reach the exit.
- One biome, one weapon (a short-range magical bolt), one healing pickup,
  two ordinary enemy types and one guardian using readable variants of their attacks.
- Build a real map with landmarks, intersecting paths, optional exploration and
  unlockable shortcuts—not a corridor of repeated combat rooms. Include at least
  twelve named playable areas, eight ordinary encounters across outdoor/indoor
  routes, three safe stops beyond spawn, and a final guardian encounter.
- Keep the hand-authored landscape and major landmarks coherent. Use seeded
  encounter compositions, reward offers, optional route gates and compatible crypt
  module variants; do not generate arbitrary terrain or disconnect key locations.
- Use a deterministic seed for encounter variants, crypt modules and reward offers.
  **Retry seed** reproduces the starting conditions; **New run** chooses a new
  seed. Runtime decisions still affect outcomes.
- Completing a required encounter advances its gate objective; run level-ups offer one of three distinct
  upgrades: increased damage, shorter attack cooldown or increased maximum health.
  Cap stacking; keep offers meaningful and avoid an inventory/equipment system.
- Health reaches zero → stop combat → show run summary → retry or return.
  Victory shows the same options. Run upgrades reset between runs; saved player
  level, lifetime XP and earned unlocks remain (see section 2.1).
- Award run XP for encounters and the guardian. Run level-ups offer the three
  upgrades above through a custom menu; do not also grant duplicate room rewards.
  Separately accumulate lifetime XP for a small persistent player-level track and
  cosmetic unlocks. Persistent level does not silently increase starting damage.
- No general account/profile writes, online leaderboard, crafting,
  trading, large skill tree, PvP, shared loot or multiplayer combat in the MVP.
- Leaving the world must always remain possible through normal application UI.

### Top-down map concept

One continuous overworld connected through a walkable crypt entrance to an
underground wing. North is up; this is schematic, not to scale. Dotted links are
unlockable shortcuts, not required jumps or teleports. Major landmarks stay fixed;
seeded variants change encounters, selected routes and crypt modules.

```text
                              NORTH ^
 OVERWORLD
 [Old watchtower E]---[Ruined village E]---[Chapel refuge L H]
         |                    |                       |
 [Woodland trail E]    [Stone bridge E]----[Crypt forecourt E]
         |                    |                       |
 [Wayside shrine L H]--[OPEN FIELD E E]                 D
         |             /      |      \                 |
 [Farm ruins E]--------/ [Stream ford] \        UNDERGROUND
         |                    |        \       [Crypt entry L H]
         +------[South road]---+         |              |
                      |                 |      [Burial galleries E]
             [SAFE CAMP S C L H]         |         /          \
             Start run / Return home    | [Ossuary E]--[Old armory E]
                      :                 |         \          /
                      :.................:      [Sealed antechamber]
                   unlock return shortcut             |
                                               [Guardian G -> X]
```

`S` = spawn; `C` = asset-creator Credits beside spawn; `L` = a separate physical
leveling-menu location; `H` = bounded healing; `D` = crypt entrance;
`E` = working encounter/patrol location; `G` = guardian; `X` = victory exit.
The three non-spawn safe stops are the wayside shrine, chapel and crypt entry.
Lines are traversable routes; stream banks/cliffs are terrain boundaries, not
invisible arena walls. Keep enemies out of safe stops and the camp.

### Map structure, field and exploration

- Start with an approximately **300 × 250 m overworld**, plus a compact crypt wing;
  tune distances to movement speed and the 20–30 minute run target. At least twelve
  named areas above must be physically distinct playable spaces, not signposts.
- The **open field** is an approximately 100 × 80 m playable meadow with detailed
  grass, uneven but walkable ground, rocks, broken fences, a stream edge and long
  views toward the village/watchtower. Provide a clear main trail plus flanking
  routes, cover and two enemy patrol territories. It is not a decorative backdrop.
- Build two overworld loops (farm/shrine/woodland and field/bridge/village), optional
  watchtower/armory rewards and a clearly recognizable crypt objective. Use authored
  elevation, ruins and sightlines to make navigation legible without forced UI.
- Define three objective encounters (watchtower, village, forecourt); clearing all
  opens the crypt. Clearing burial galleries and either ossuary or armory opens
  the guardian antechamber. Other encounters offer XP/exploration, not mandatory
  full-map extermination. Expose gate requirements in the map/objective panel.
- Unlock return shortcuts from the far side without bypassing objective checks.
  Cleared encounters stay cleared for that run; no enemies respawn on menu use,
  backtracking or crossing a sector boundary. Retry/new run resets the map state.
- Use sector culling/activation for the larger environment, preserving encounter
  state across activation. Test bridge/ford/crypt navigation seams and avoid falls,
  required jumps, invisible blockers and long empty walks between encounters.
- Add a world-owned **Map & objectives** page accessible from the paused menu and
  every leveling station: landmarks, discovered routes, current location, safe
  stops and gate status. It is navigation, not a teleport or a mandatory minimap.

### Controls and comfort

Reuse desktop/VR locomotion and settings rather than adding another player rig.
Desktop aims using the existing view; VR aims using a controller ray. Both invoke
the same bounded attack action with identical damage/range/cooldown rules.
Choose and document a rebindable attack action after auditing existing bindings;
do not hardcode an input that conflicts with menu, grip, sprint or interaction.
Suppress attacks while menus are open or the world is changing.

Avoid forced camera motion, head bob, screen shake, dodge rolls and required jumps.
Enemy attacks have visible windups and visual projectile warnings; audio is an
extra cue, not the only cue. Use readable health/reward information in desktop UI
and a VR-safe panel. No combat flash or audio effect should require changing the
user's microphone/mute, comfort or accessibility preferences.

## 2. Updated world-system delivery and verification boundary

**Delivery target: a normal safely packaged world**, using the updated world's
reviewed model, gameplay, UI and animation interfaces. Download/install the package
through the existing world flow, then support solo play from validated cached
content without a relay. A bundled-only trusted-GDScript world is no longer the
required route. Keep multiplayer combat outside this demo's scope.

Repository inspection confirms `world_local_store.gd`, VM `storage.local`
operations and validated static `.worldmesh` construction. However, the checked-in
[authoring guide](../guides/safe-world-authoring.md), builder and runtime still
describe/implement a narrower profile: no general animated-character/UI nodes and
only limited gameplay commands. The user reports newer safe gameplay/model support;
part 01 must locate and exercise its actual APIs/version before authoring against
them. This is a compatibility gate, not a claim that imported GLTF, arbitrary menus
or full combat are already verified in this checkout. Record any missing adapter
explicitly; do not reinstate unsafe execution or silently replace animated enemies
with static props.

- Inspect DataLoader, startup, world selection and welcome-island activation
  before implementation. Reuse their staging, spawn, recovery and cleanup contracts.
- Use a stable world ID and canonical publication URL; do not overload `default_wold`, replace
  startup's home, or bypass scene-transition ownership through a stray scene change.
- Offer a clear installed/cached solo world-selection entry with a return-home action. Start
  runs only after activation, and dispose the old world before accepting new input.
- When connected to an instance, use the existing acknowledged leave/transition
  flow before entering the solo world. A local run must not leave the client
  advertising membership in an unrelated world. Relay failure must not block
  offline entry or return home.
- Reuse the persistent local player; never create a second camera, XR origin,
  account owner or microphone capture pipeline. Restore player/world-specific
  state on exit, death, failure and reload.
- Keep game health and damage separate from social avatars, moderation, voice and
  the home-world pickup system. Do not expose this solo world as a joinable public
  instance before there is a separately designed multiplayer implementation.
- Do not loosen the downloaded-world validator to accept executable scripts,
  mount untrusted PCKs or claim this demo completes the safe-world roadmap.

Package models, animation data, menus and restricted logic only through supported
validated formats/capabilities. Declare the minimum supported world/script API and
reject incompatible clients with an actionable message. Extend reviewed adapters
only if needed; never include executable downloaded GDScript/native plugins.
Track compatibility against the [safe-world plan](safe-world-system-roadmap.md).
Co-op requires explicit shared-state/authority, late-join and disconnect design;
neither the existing item protocol nor local script callbacks supply combat authority.
Any future relay extension must retain [ephemeral relay data](../relay-data-lifecycle.md)
and exact `session_id`/revision isolation, without a hidden player-host authority.

### 2.1. Saved player progression on the user's PC

Reuse `scripts/worlds/world_local_store.gd` through the trusted world runtime and
declared **`storage.local`** capability, not direct world-script file access or a
second save service. Current VM operations are `save_set`, `save_add`, `save_delete`
and `if_saved`; do not invent unimplemented read/write APIs in world scripts.

- Trusted startup selects the namespace from the local profile fingerprint and
  source URL. Storage lives below `user://world_saves` with hashed owner/URL names.
  The world must not choose a filesystem path, impersonate an owner or read other
  worlds' saves. Temporary identities use memory-only storage.
- Proposed small versioned record: `schema_version`, `lifetime_xp`, derived
  `player_level`, bounded cosmetic unlock IDs, best completed depth, run/win counts
  and a bounded last-awarded run/encounter marker. Validate XP/level consistency
  and clamp neither corrupt nor future-schema data silently into valid progress.
- Run HP, temporary upgrades, active projectiles/enemies and world-node references
  are not permanent progression. Mid-run resume is deferred; say so in the menu.
  Retry starts a clean run, retaining saved player progress. Grant lifetime XP at
  completed-encounter checkpoints, not repeatedly when the reward menu is reopened.
- Commit XP, level, unlock and duplicate-award marker together. Coalesce pending
  changes within the service's **one write per second** limit; never save each
  frame/tick or retry a `save_add` blindly. Show pending/unsaved state and flush
  through the trusted lifecycle before an orderly exit; do not block leaving on
  disk failure or promise crash-safe progress beyond the last successful commit.
- Stay below **16 KiB**, 128 top-level keys and the service's bounded-data limits.
  No combat history log or unbounded seed list. Saves are client-owned and locally
  editable, not proof of competitive achievements or multiplayer permissions.
- Preserve unreadable/corrupt saves, report failures, and offer explicit temporary
  play without replacing the original. Unknown schema versions remain untouched;
  tested migrations are deliberate and versioned. Reset progression requires a
  confirmation and affects only this player's world namespace.
- Keep the canonical URL stable across content revisions: current namespaces are
  URL-based, not `world_id`-based. A host/URL change needs an explicit supported
  migration, not automatic access to another namespace. Account changes must not
  expose the previous player's data. No cloud/relay save or settings/profile fields.

### 2.2. Custom leveling menus

Build world-owned menus in the same stone/amber/teal style as the dungeon, through
the updated safe UI/action-binding APIs. Use shared validated progression data for
both desktop and VR presentations; never duplicate leveling rules in UI callbacks.

- **Entrance / player progression:** player level, lifetime XP bar, next unlock,
  unlocked cosmetics, Start run, and an explicit “runs restart; player level is
  saved on this PC” explanation. Distinguish run level from persistent player level.
- **Run HUD:** health, run level/XP, current upgrades and a brief saved/pending/error
  status. Do not cover enemies or require reading tiny headset text.
- **Level-up panel:** three upgrade cards with icon, current → next stat values,
  capped/disabled state and one confirm action. Queue multiple earned levels;
  selection consumes exactly one choice, ignores double clicks and cannot be
  bypassed by closing/reopening the panel. Pause solo simulation while choosing.
- **Player-level/unlock notice and run summary:** show earned lifetime XP,
  resulting player level, cosmetic unlocks, victory/death, Retry seed, New run and
  Return home. Display saving failures honestly rather than claiming “Saved.”
- Support mouse/keyboard focus and VR pointer/confirm with equivalent actions,
  readable contrast and non-color-only states. Custom-menu input capture suppresses
  attacks; closing restores input. App settings/leave controls remain reachable.
  Global menus, focus loss and level-up panels must not leave enemies ticking
  while the player cannot act; keep pause state consistent on resume/unload.

#### Expanded leveling menu collection

Make progression interactions at spawn **and three additional safe stops** open
the same **Leveling** hub with distinct pages, not one overloaded panel.
In-run pages are also accessible from a compact
progression button while paused; entrance-only actions stay disabled during a run.
Use the same visual language, Back navigation and desktop/VR controls throughout.

| Menu / page | Contents and actions | Progression boundary |
| --- | --- | --- |
| **Player overview** | Persistent player level, lifetime XP, next milestone, equipped cosmetic and save status; links to the pages below | Read-only summary; opening it never awards XP |
| **Character stats** | Base versus current damage, attack cooldown, maximum/current health, run level and upgrade stacks; show each modifier's source | Clearly distinguish temporary run bonuses from permanent cosmetic progression |
| **Upgrade library** | Browse the three upgrade families, inspect each rank's exact effects and caps, and preview current → next values | Informational; browsing is not purchasing or granting an upgrade |
| **Level-up selection** | Three large upgrade cards, details/preview, confirm button and number of pending choices | Consume one pending run-level choice per confirmation; prevent duplicate selection |
| **Current run build** | Chosen upgrades in acquisition order, stack counts and combined effects; empty-state explanation for a fresh run | Bounded to this short run; no respec, extra currency or permanent upgrade purchase |
| **Player-level milestones** | Small fixed track of lifetime-XP thresholds and their cosmetic rewards; mark reached, next and locked milestones | Rewards unlock once when eligible; never require repeatedly clicking Claim |
| **Unlocked cosmetics** | Inspect/preview available spell colors or world-owned cosmetic accents and equip one; show locked item's required player level | Persist selection as a bounded approved ID; do not replace the user's social avatar or sell stat boosts |
| **XP breakdown** | Explain encounter/guardian XP, show this run's earned versus successfully saved lifetime XP, and the next player-level threshold | Use bounded current-run totals, not a permanent event log; retrying/reopening cannot re-award XP |
| **Run results / level recap** | Before → after XP/level, new milestones/cosmetics, selected run build and victory/death; Retry seed, New run, Return home | Resolve results once; save failure does not disguise itself as a successful award |
| **Progression data** | Local-save explanation, saved/pending/error state, temporary-identity warning and a separate confirmed Reset player progression action | Reset only at the safe entrance; cancel changes nothing, confirm affects this world/player only |

Keep all pages backed by one progression model and small declarative definitions.
Do not introduce independent XP counters, skill points, a shop, equipment inventory
or an additional save file just to populate more menus. Cosmetic equipment adds
only a bounded `equipped_cosmetic_id` to the proposed saved record; validate it
against unlocked IDs and use a safe default for an unavailable cosmetic without
discarding otherwise valid progress.

Preserve selected tab/focus only for the current menu session. Opening nested
pages must not unpause combat or release attack input suppression; closing the
last modal restores the prior pause/input state. Level-up choices take priority
over informational pages, with Back returning to the pending choice rather than
discarding it. Never stack multiple floating panels over the VR player's view.

**Additional menu acceptance:** every page has a meaningful empty/locked/capped
state, works with keyboard and VR pointer, and can return to the hub. Test
multi-level XP gains, double confirmations, repeated navigation, cosmetic equip
and relaunch, reset cancel/confirm, missing cosmetic IDs, and saving errors across
all pages. Review the full flow in desktop and headset views, not just screenshots
of individual panels. Include these pages in parts 05–06's implementation gates.

#### Distributed menus and safe stations

Place physical interactive menus at **camp, wayside shrine, chapel refuge and
crypt entry** (the four `L` markers). Each must be reachable, readable and usable
on desktop/VR, not an inactive prop pointing players back to spawn. All expose
overview, stats, upgrades, run build, milestones, cosmetics, XP and Map & objectives.
The current run's level-up choices can be resolved at any station or the paused
menu; no compulsory trek back to camp to spend a pending choice.

Keep Start/New run and destructive progression reset at camp; other stations show
those actions as unavailable with a reason. Return home remains available through
normal app UI everywhere. Healing has a once-per-stop-per-run allowance rather
than refilling every time a menu is opened. Stations are safe landmarks, not
automatic mid-run save/resume points (that feature remains deferred).

All four stations bind one run/progression/save model: choosing an upgrade,
equipping a cosmetic or saving XP at one is reflected at the next. No duplicated
XP, independent station saves or menu-triggered enemy resets. Opening a station
pauses the solo simulation and suppresses attacks; closing restores prior state.
Enemy leashes and projectile collision must prevent attacks entering safe areas,
and block player damage fired from inside them so they cannot be used to farm
enemies without risk.
Keep creator Credits beside spawn as requested, with an optional Credits link at
the other stations using the same manifest. Test sequential visits to all four
stations, interrupted interaction, repeated healing and sector unload/reload.

### 2.3. Asset-creator credits beside spawn

Place a clearly labeled **Credits** interaction on a detailed lectern or wall panel
immediately beside the safe entrance spawn, visible on arrival without blocking
movement or automatically opening. It opens a custom, scrollable/paginated menu
usable with desktop focus and VR pointer. The leveling menu is nearby but separate.

Show **who made the assets**, not just a list of download websites: asset title,
creator/artist, publisher where different, license, source URL and modification/
conversion credit. Cover models, materials, animations, sounds, fonts and icons.
Credit CC0 creators too, even when attribution is optional. Include full required
attribution/license notices and bundled offline license text; links are optional
explicit user actions, never automatic browser navigation or network requests.

Generate the menu from the audited per-world asset manifest so it stays consistent
with THIRD_PARTY_ASSETS and packaged licenses. It must work offline, remain readable
in VR, have a clear Close/Back action and never start a run or award XP. Existing
application Credits can mirror these entries, but are not a substitute for the
requested **menu next to spawn**. Test completeness against every shipped asset.

## 3. Graphics and online asset plan

Aim for detailed, believable dark-fantasy ruins: sculpted/weathered stone, layered
PBR surfaces, realistic metal/wood, convincing character anatomy, warm amber lamps
and restrained teal magic. **No low-poly/faceted/cartoon asset packs as final art.**
Use high-quality online assets with consistent scale, texel density and material
response; assemble an original dungeon, not a complete downloaded demo. Optimize
with LODs, baking and culling without reverting the visible style to low-poly.

Candidate publisher pages checked on **2026-11-05**; no archives have been acquired
or audited by this roadmap. Confirm the exact downloaded archive's terms and
contents before importing; paid/source/EXTRA tiers are not assumed available.

| Source | Proposed use | Publisher license / decision |
| --- | --- | --- |
| [Poly Haven](https://polyhaven.com/) / [license](https://polyhaven.com/license) | Detailed scanned props, stone/wood/metal PBR surfaces and lighting references | Publisher states assets are CC0 and redistributable; audit exact asset, creator and runtime conversion. Environment source, not an assumed animated-enemy library. |
| [ambientCG](https://ambientcg.com/) / [license](https://docs.ambientcg.com/license/) | High-quality masonry, worn floors, metal, wood and surface detail | Publisher states assets are CC0; choose a cohesive small subset and record exact asset IDs/authors. |
| Detailed rigged enemies and compatible animation library — selection gate | Two enemy roles and guardian with matching high-quality combat clips | Exact source not selected: require artist credit, rig/clip quality and permission to redistribute source/converted data in this repository and downloadable package. No unverified marketplace or animation-service license assumptions. |

The former KayKit/Kenney low-poly recommendations are superseded, not fallbacks.
The enemy/animation source remains a required asset-selection milestone; do not
claim that environment libraries solve character art. If suitable free assets
cannot be licensed, report the gap and request a budget/source decision rather
than buying assets or silently lowering the requested quality.

Acquire during development, then safely convert/package the selected runtime subset.
Initial installation may download the world; cached play must work offline without
asset APIs, OAuth, web requests or extra first-play downloads.
Do not copy assets from commercial roguelikes or treat “free download” as a license.

For every selected asset, record creator, original URL, archive/version, retrieval
date, license text, source and converted SHA-256 hashes, local paths and conversion
steps. Add actual bundled assets to [THIRD_PARTY_ASSETS](../../THIRD_PARTY_ASSETS.md)
and the spawn-side Credits menu plus existing offline Credits mechanism. Keep per-world source/provenance records;
do not add candidate assets to the bundled inventory before acquisition.
Select short, redistributable combat/UI sounds separately with the same audit;
do not make the demo depend on unlicensed placeholder music.

### Art acceptance

- Prove one finished room first: correctly scaled doors, collision, a lit enemy,
  working animation, weapon effect and reward chest. Review at player height in
  desktop and headset views, not only from an editor's overhead camera.
- Detailed silhouettes and consistent PBR/texel density, no missing textures, inverted normals, hovering
  props, visible debug primitives or obvious animation sliding.
- Static collision for walls/floors; simple enemy hit volumes. Keep decorative
  props outside the movement corridor and exclude them from expensive collision.
- No required glow/bloom to read attacks. Bound real-time shadow lights, particles,
  transparent effects and concurrent enemies; prefer static lighting where verified.
- Provisional scene budgets: at most six simultaneously engaged enemies across
  adjacent active sectors, including field patrols, and two shadow-casting local
  lights per combat area. Do not evade this cap by splitting one battle into sectors.
  Start with 2K PBR maps, using 4K only for justified hero
  surfaces; author LODs and bound decoded texture/mesh memory. Replace the previous
  50 MiB art cap with measured download/VRAM/frame-time budgets from the reference
  room; do not promise high-detail assets fit the old low-poly payload budget.
- Record reference desktop/GPU, headset, resolution, render settings and frame
  timings. Target 60 fps desktop and the tested headset's native refresh rate;
  headless Compatibility tests do not establish Forward Plus/XR performance.

### Fitting animations and feedback

Audit the chosen detailed character library's actual rig and clips; map exact clip
names to combat idle, walk/run, melee windup/strike/recovery, ranged aim/fire,
hit reaction and death. Give the guardian a distinct silhouette and readable longer
windup. Add chest/door opening, pickup, spell casting and restrained leveling/menu
transitions using supported safe animation data. No stock dance or unrelated
gesture as an attack, and no static enemy substituted for an animated one.

Match feet to movement speed, blend transitions, and align projectile release and
impact effects with combat timing. Rules own damage, not duplicate clip callbacks;
death/interruption cancels pending attacks. Pause gameplay and relevant animation
together. Verify skeleton/skin/material/clip conversion through the packaged loader,
not only the editor; reject executable method-call tracks. Keep camera/head tracking
and avatar IK authoritative: weapon feedback must not force camera motion or move
tracked hands. Provide reduced-motion menu feedback and clean up effects on unload.

## 4. Proposed implementation boundaries

Names below are proposals, not existing services:

| Location | Responsibility |
| --- | --- |
| `scenes/worlds/ember_crypt/` | Entrance, room modules, enemies, rewards, lighting and world root |
| `examples/ember_crypt/` | Editable authoring project, safe logic/UI definitions, manifest and packaging instructions |
| World-local safe modules | Run/combat rules, progression/save adapter, custom menus, spawn Credits and animation bindings; exact paths follow the supported API |
| `assets/ember_crypt/` | Audited models, textures, animations, audio and provenance |
| `tests/roguelike_demo/` | Disposable-project runner, deterministic rules and activation/cleanup fixtures |

Keep rules testable without rendering, audio devices, accounts, external HTTP or XR.
Separate run data from scene nodes: seed, room IDs, encounter status, HP, upgrades
and cooldowns are run-local values. Use stable entity IDs to reject repeated damage
or reward events; delete references when an encounter ends or the world unloads.
Bound frame delta handling, spawn counts, projectiles and seed-generation attempts.

### Working enemies, not animated decorations

Deliver functional melee sentries, ranged casters and the guardian in actual
packaged play. Each has health, detection rules, collision, navigation, attack
cooldowns, damage reception, death, XP ownership and reset/cleanup behavior.

| Enemy | Required behavior | Playable proof |
| --- | --- | --- |
| **Melee sentry** | Patrol a bounded route, detect player with sight/range, chase around cover, telegraph a close strike, recover and leash back if pursuit is lost | Can reach and damage the player legitimately, miss when avoided, receive damage and die once |
| **Ranged caster** | Patrol/guard, acquire line of sight, keep a bounded preferred distance, aim then fire a visible projectile, reposition if blocked | Shots collide with terrain, cannot hit through walls or safe-zone boundaries, and stop after death |
| **Crypt guardian** | Guard arena; alternate a telegraphed close attack and projectile pattern with clear recovery windows | Fight is winnable; no unavoidable arrival hit; death opens exit and grants final rewards exactly once |

State flow: patrol/idle → detect → chase/reposition → telegraph → attack → recover;
lose target → return; hit/death can interrupt appropriately. Separate detection,
navigation, attack eligibility and animation so playing a clip is never mistaken
for implementing combat. Do not rely on social-avatar collision for hit detection.

Use reviewed navigation/gameplay APIs across field terrain, bridge, woodland,
ruins and crypt seams. Budget path queries, cap chase distance and provide an
unreachable-target timeout; enemies must not walk through walls, hover over slopes
or remain stuck attacking from behind cover. Validate melee reach/line of sight
at the damage moment and sweep projectiles to prevent long-frame tunneling.

Retain stable enemy/encounter IDs across sector deactivation. Dead enemies remain
dead within the run, removed projectiles cannot hit later, and revisiting a patrol
cannot farm duplicate clear rewards. Freeze AI, cooldowns and damaging effects
under solo menu pause; clear target references on death, player exit and unload.

**Enemy acceptance:** an unaided player encounters patrols in the field, is
detected/chased/attacked, evades or uses cover, kills enemies, earns XP once and
completes the guardian fight. Test sight occlusion, loss/leash, blocked paths,
safe-zone attacks in both directions, damage cadence, projectile bounds, sector
reactivation, pause/death interruption and replay reset. Record rendered desktop
and headset evidence; static models or isolated AI unit tests do not satisfy this gate.

## 5. Small, verified milestones

Each implementation part gets failing focused tests first where applicable, then
a passing coherent change and Conventional Commit. Keep art/layout review gates
explicit rather than treating headless tests as proof of visual quality.

| Part | Deliverable | Exit gate |
| --- | --- | --- |
| 01 — Updated API/integration contract | Verify safe package model/rig/animation, gameplay, UI and storage APIs; selection, input and lifecycle | Required capabilities exercised through an actual package; save isolation and safe transitions; gaps reported explicitly |
| 02 — High-quality art/animation spike | Audit detailed environment and rigged-enemy sources; finish one PBR room and spawn-side Credits/menu sample | No low-poly final assets; creator/license manifest complete; packaged rig/clips/UI work; desktop review and explicit headset gate |
| 03 — Real-map graybox | Connected field/ruins/crypt, twelve-plus named areas, loops, gates, shortcuts and four safe stations; seeded encounter/module variants | Every route and objective traversable across seeds, field is playable, no softlocks; map/objective panel agrees with geometry |
| 04 — Working enemy/animation slice | Player attack/health, melee patrol and ranged caster in field and ruins, navigation, detection, damage, death and XP | Player can fight and evade real enemies; cover, leashes, safe zones, adjacent-sector caps, interruption/pause and desktop/VR checks |
| 05 — Distributed leveling/custom menus | XP/HUD, upgrade cards, healing, map and all leveling pages at camp/shrine/chapel/crypt entry | All four stations work and share state; no duplicate choices/healing, input restored; no return-to-spawn requirement |
| 06 — Local player progression | Lifetime XP/levels, cosmetics, progression/summary menus, versioned saves and confirmed reset | Relaunch, owner/URL isolation, throttling, duplicate awards, migration, corruption and disk-failure tests |
| 07 — Full-map guardian/art polish | Functional guardian, detailed field/vegetation/ruins/crypt, sound, animation roles and spawn Credits | Full 20–30 minute route and optional exploration; actual enemy fight/XP/exit verified; creator credits and outdoor/indoor frame budgets reviewed |
| 08 — Safe package/release | Publishable package, cached offline entry, return-home recovery and regressions | Clean client validates package; cached play network-disabled; no save, input, animation or scene leaks |

**Dependency order:** 01 → 02 → 03 → 04 → 05 → 06 → 07 → 08. Resolve missing
safe capabilities explicitly; never fall back to executable world downloads.

## 6. Verification and definition of done

The isolated [foundation suite](../../tests/roguelike_demo/README.md) now runs with
`python3 tests/roguelike_demo/run.py`; its runner checks use
`python3 tests/roguelike_demo/test_runner.py`. It exercises actual local storage,
VM permissions and runtime dispatch for four station entities, not gameplay/UI.
Initial verified result: 51 Godot assertions and four Python tests pass. These
counts include fixture setup assertions and are not game acceptance coverage.
Malformed-JSON engine error handling remains an explicitly documented limitation.

Extend this suite as real game implementations arrive. Cover
seed reproducibility/connectivity, encounter ordering, cooldowns and duplicate hits,
reward uniqueness/stack caps, death/victory, restart, pause/menu suppression and
cleanup during world transition. Include long-frame and repeated-entry cases.
Test XP thresholds, queued choices, save coalescing/quotas, duplicate awards,
migration/future schemas, corrupt/read-only files, identity/URL isolation, temporary
identities, relaunch and confirmed reset. Verify packaged menu actions and animation
bindings, interrupted attacks and paused timelines. Check that every shipped asset
has a creator/license entry in the offline spawn-side Credits menu, and that this
menu works before starting a run without triggering combat or progression.
Add route/gate reachability and sector-state tests for the expanded map, field
patrol navigation/occlusion and real damage/death/reward behavior. Verify all four
menu locations share state, healing is bounded and safe zones prevent combat
exploits in both directions. Inspect vegetation, long outdoor sightlines and
simultaneous adjacent-sector enemies under the actual renderer.

Run existing relevant suites after inspecting their current prerequisites:
`tests/world_system`, `tests/public_discovery`, `tests/active_instance`,
`tests/welcome_island`, `tests/vr_controls` and `tests/microphone_settings`.
Use each directory's documented runner; record skips and infrastructure errors.
The foundation suite was run in isolation; full existing regressions and the game,
rendered UI, navigation, enemy behavior and headset gates remain unverified.

Manual release checklist:

- [ ] A new desktop player can start, understand, win/lose and replay without developer tools.
- [ ] A connected twelve-plus-area map includes a playable field, loops, optional routes and a crypt—not just a few rooms.
- [ ] Field/ruin patrols detect, navigate, attack, take damage and die; the guardian fight and exit work.
- [ ] All four physical leveling stations work and share progression without duplicate XP/healing.
- [ ] Different seeds vary layouts/rewards; retrying one reproduces initial conditions.
- [ ] Real headset validates aim, UI distance, movement comfort, scale and frame timing.
- [ ] Finished art is coherent and actual asset license/provenance/Credits are complete.
- [ ] Detailed PBR art and fitting character animations meet the non-low-poly direction.
- [ ] Credits beside spawn identify every asset creator and work offline on desktop/VR.
- [ ] Leveling menus support focus/pointer input, pause and exactly-once upgrade choices.
- [ ] Local player progression survives relaunch; corrupt saves remain preserved and errors visible.
- [ ] Safe package supports rigs/clips/gameplay/UI; cached exported play needs no network or author caches.
- [ ] Return home works after victory, death, abort and failed activation.
- [ ] No unwanted account/settings writes, microphone restart, relay-state leak or duplicate player.
- [ ] The selector and documentation label the demo **solo/offline**, not multiplayer-ready.

## 7. Deferred work

More biomes, weapons, large progression trees, mid-run resume, cloud saves and co-op
are separate proposals. Safe downloadable packaging, small local progression,
custom leveling menus, fitting animations and spawn-side creator Credits are in
scope, not deferred. The connected map, playable field, working enemies and
distributed menus are also required; the reference-room spike is only a quality
prototype, not a replacement for that map. Build and verify it in coherent parts
rather than adding empty acreage. Record delivered milestones
here and update the [roadmap index](README.md); planned features must not be
described as current application behavior.
