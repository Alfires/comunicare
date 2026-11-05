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

Working title: **Ember Crypt**. Deliver a polished, playable 5–10 minute solo demo
in a new optional world. Keep the welcome island and `default_wold` unchanged.
This is a small action roguelike, not a traditional turn-based roguelike.

## 1. Playable scope

- Enter a safe entrance room, choose **Start run**, explore a small dungeon,
  defeat enemies, choose upgrades, defeat a guardian and reach the exit.
- One biome, one weapon (a short-range magical bolt), one healing pickup,
  two ordinary enemy types and one guardian using readable variants of their attacks.
- A run has an entrance, three combat rooms, a reward room and a guardian/exit
  room. Randomly choose compatible hand-authored modules and their connections;
  do not begin with unrestricted procedural geometry.
- Use a deterministic seed for layout, enemy placement and reward offers.
  **Retry seed** reproduces the starting conditions; **New run** chooses a new
  seed. Runtime decisions still affect outcomes.
- Defeating a combat room unlocks its exit and offers one of three distinct
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

One example six-room seed, not a fixed map for every run. North is up; rooms and
corridors are schematic, not to scale. The entrance/spawn layout stays stable;
the three combat modules, their connections and encounter dressing vary by seed.

```text
                              NORTH ^
                 +------------------------------+
                 | GUARDIAN HALL                |
                 | pillars    G     sealed exit X|
                 |        clear arena           |
                 +--------------D---------------+
                                |
                 +--------------D---------------+
                 | COMBAT 3: burial chamber     |
                 | E       cover             E  |
                 +--------------D---------------+
                                |
 +----------------------+       |       +----------------------+
 | COMBAT 1: old armory  |       |       | REWARD: quiet shrine |
 | E    cover       E   |       |       | H  chest / upgrades  |
 +----------D-----------+       |       +-----------D----------+
            |                   |                   |
            +----------+--------+-------------------+
                       |
           +-----------D----------------+
           | COMBAT 2: ruined gallery   |
           | E   pillars / clear lane E |
           +-----------D----------------+
                       |
           +-----------D----------------+
           | SAFE ENTRANCE              |
           |                            |
           | C   S    L       Start run |
           | Credits  leveling menu     |
           |        Return home         |
           +----------------------------+
```

`S` = player spawn; `C` = interactive asset-credits menu beside spawn;
`L` = player progression/leveling menu; `D` = doorway; `E` = enemy group;
`G` = guardian; `H` = healing; `X` = victory exit. Combat 3's door requires all
three ordinary encounters cleared; the optional reward shrine is a safe detour.
Keep corridors wide for comfortable movement and place enemies behind encounter
boundaries so the entrance, credits and progression menus are always safe.

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
  completed-room checkpoints, not repeatedly when the reward menu is reopened.
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
- Provisional scene budgets: at most six active enemies and two shadow-casting local
  lights per active room. Start with 2K PBR maps, using 4K only for justified hero
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

Simple enemy states: idle → approach/aim → telegraph → attack → recover; damage
can lead to hit reaction or death. Use a small fixed-room navigation solution
first, with tests for obstacles and unreachable targets. Animation events must
not accidentally apply damage twice or remain active after death/unload.

## 5. Small, verified milestones

Each implementation part gets failing focused tests first where applicable, then
a passing coherent change and Conventional Commit. Keep art/layout review gates
explicit rather than treating headless tests as proof of visual quality.

| Part | Deliverable | Exit gate |
| --- | --- | --- |
| 01 — Updated API/integration contract | Verify safe package model/rig/animation, gameplay, UI and storage APIs; selection, input and lifecycle | Required capabilities exercised through an actual package; save isolation and safe transitions; gaps reported explicitly |
| 02 — High-quality art/animation spike | Audit detailed environment and rigged-enemy sources; finish one PBR room and spawn-side Credits/menu sample | No low-poly final assets; creator/license manifest complete; packaged rig/clips/UI work; desktop review and explicit headset gate |
| 03 — Graybox run | Seeded six-room graph, collision, spawn, doors and exit, initially without enemies | Fixed-seed determinism; many seeds produce connected traversable layouts; no overlap, inaccessible exit or unbounded retry |
| 04 — Combat/animation slice | Attack, health, melee enemy, readable telegraphs and fitting movement/attack/hit/death clips | No wall hits, duplicate/late damage or animation sliding; interruption, pause and desktop/VR checks |
| 05 — Run leveling/custom menus | Ranged enemy, XP/HUD, queued upgrade cards, healing, pause and retry | Choices granted once, input captured/restored, no softlocks; run upgrades reset independently of player progress |
| 06 — Local player progression | Lifetime XP/levels, cosmetics, progression/summary menus, versioned saves and confirmed reset | Relaunch, owner/URL isolation, throttling, duplicate awards, migration, corruption and disk-failure tests |
| 07 — Guardian/art polish | Guardian, detailed room assets, sound, full animation roles and completed spawn Credits | Full short run; all creators credited offline beside spawn; quality and desktop/headset budgets reviewed |
| 08 — Safe package/release | Publishable package, cached offline entry, return-home recovery and regressions | Clean client validates package; cached play network-disabled; no save, input, animation or scene leaks |

**Dependency order:** 01 → 02 → 03 → 04 → 05 → 06 → 07 → 08. Resolve missing
safe capabilities explicitly; never fall back to executable world downloads.

## 6. Verification and definition of done

Add `python3 tests/roguelike_demo/run.py` as an isolated runner following repository
fixture conventions; this command is **planned and does not exist yet**. Cover
seed reproducibility/connectivity, encounter ordering, cooldowns and duplicate hits,
reward uniqueness/stack caps, death/victory, restart, pause/menu suppression and
cleanup during world transition. Include long-frame and repeated-entry cases.
Test XP thresholds, queued choices, save coalescing/quotas, duplicate awards,
migration/future schemas, corrupt/read-only files, identity/URL isolation, temporary
identities, relaunch and confirmed reset. Verify packaged menu actions and animation
bindings, interrupted attacks and paused timelines. Check that every shipped asset
has a creator/license entry in the offline spawn-side Credits menu, and that this
menu works before starting a run without triggering combat or progression.

Run existing relevant suites after inspecting their current prerequisites:
`tests/world_system`, `tests/public_discovery`, `tests/active_instance`,
`tests/welcome_island`, `tests/vr_controls` and `tests/microphone_settings`.
Use each directory's documented runner; record skips and infrastructure errors.
No Godot suite was run for this documentation-only proposal.

Manual release checklist:

- [ ] A new desktop player can start, understand, win/lose and replay without developer tools.
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
scope, not deferred. Prioritize a finished
room and satisfying core combat over a larger dungeon. Record delivered milestones
here and update the [roadmap index](README.md); planned features must not be
described as current application behavior.
