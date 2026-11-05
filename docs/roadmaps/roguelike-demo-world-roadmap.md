# Roguelike demo world roadmap

## Status and interpretation

**Proposed — 2026-11-05. No game implementation or assets delivered by this plan.**
Interpret the request's “roadlike” as **roguelike**: a small replayable dungeon
with randomized rooms, simple combat, loot choices and a run that ends on death.
The proposed presentation is stylized **3D**, compatible with Comunicare's desktop
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
  Victory shows the same options. All upgrades reset between runs.
- No permanent progression, account writes, online leaderboard, crafting,
  trading, large skill tree, PvP, shared loot or multiplayer combat in the MVP.
- Leaving the world must always remain possible through normal application UI.

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

## 2. Inspected project constraints and delivery choice

The current [safe world authoring guide](../guides/safe-world-authoring.md)
documents primitive geometry, PNG materials and restricted local visibility
callbacks. Imported models, animations, environments and world UI are unsupported;
combat, AI and synchronized gameplay scripts are not available. A ZIP containing
GDScript is therefore **not** a valid implementation route.

**MVP proposal: a client-bundled, trusted offline world.** Its reviewed GDScript,
models and animations ship with the application, rather than being downloaded and
executed on join. This requires an explicit built-in-world selection/staging path;
it is not already supported merely by adding a scene file.

- Inspect DataLoader, startup, world selection and welcome-island activation
  before implementation. Reuse their staging, spawn, recovery and cleanup contracts.
- Add a distinct stable built-in identifier; do not overload `default_wold`, replace
  startup's home, or bypass scene-transition ownership through a stray scene change.
- Offer a clear offline world-selection entry with a return-home action. Start
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

Later, downloadable publication depends on reviewed model/animation/UI support and
restricted gameplay capabilities in the [safe-world plan](safe-world-system-roadmap.md).
Co-op also requires explicit shared-state/authority, late-join and disconnect design;
neither the existing item protocol nor local script callbacks supply combat authority.
Any future relay extension must retain [ephemeral relay data](../relay-data-lifecycle.md)
and exact `session_id`/revision isolation, without a hidden player-host authority.

## 3. Graphics and online asset plan

Aim for cohesive low-poly fantasy: cool stone, warm amber lamps, restrained teal
magic, chunky silhouettes and readable floor space. Assemble an original layout
from modular parts, not a complete downloaded dungeon demo. Visual quality comes
from consistent scale/materials, composition, lighting and animation—not realism
or a large number of unrelated packs.

Candidate publisher pages checked on **2026-11-05**; no archives have been acquired
or audited by this roadmap. Confirm the exact downloaded archive's terms and
contents before importing; paid/source/EXTRA tiers are not assumed available.

| Source | Proposed use | Publisher license / decision |
| --- | --- | --- |
| [KayKit Dungeon Remastered](https://kaylousberg.com/game-assets/dungeon-remastered) | Primary modular floors, walls, doors, chests and props | Publisher states CC0; GLTF/FBX/OBJ, gradient-atlas style. Use only verified free redistributable files. |
| [KayKit Characters: Skeletons](https://kaylousberg.com/game-assets/characters-skeletons) | Matching animated melee/ranged enemies; a visually distinct guardian variant | Publisher states CC0, rigged/animated; verify required clips in the free archive. Do not depend on EXTRA characters. |
| [Kenney Mini Dungeon](https://kenney.nl/assets/mini-dungeon) | Alternative smaller art library if the primary kit fails scale/import/performance checks | Publisher lists 3D assets under CC0. Use as an alternative, not an automatic second visual style. |

Download during development, then bundle the selected runtime subset. The finished
demo must play offline without asset APIs, OAuth, web requests or a first-run fetch.
Do not copy assets from commercial roguelikes or treat “free download” as a license.

For every selected asset, record creator, original URL, archive/version, retrieval
date, license text, source and converted SHA-256 hashes, local paths and conversion
steps. Add actual bundled assets to [THIRD_PARTY_ASSETS](../../THIRD_PARTY_ASSETS.md)
and the existing offline Credits mechanism. Keep per-world source/provenance records;
do not add candidate assets to the bundled inventory before acquisition.
Select short, redistributable combat/UI sounds separately with the same audit;
do not make the demo depend on unlicensed placeholder music.

### Art acceptance

- Prove one finished room first: correctly scaled doors, collision, a lit enemy,
  working animation, weapon effect and reward chest. Review at player height in
  desktop and headset views, not only from an editor's overhead camera.
- Consistent atlas/material setup, no missing textures, inverted normals, hovering
  props, visible debug primitives or obvious animation sliding.
- Static collision for walls/floors; simple enemy hit volumes. Keep decorative
  props outside the movement corridor and exclude them from expensive collision.
- No required glow/bloom to read attacks. Bound real-time shadow lights, particles,
  transparent effects and concurrent enemies; prefer static lighting where verified.
- Provisional budgets: at most six active enemies and two shadow-casting local
  lights per active room; selected compressed asset payload at most 50 MiB.
  Validate or revise these targets from measurements, not pack marketing.
- Record reference desktop/GPU, headset, resolution, render settings and frame
  timings. Target 60 fps desktop and the tested headset's native refresh rate;
  headless Compatibility tests do not establish Forward Plus/XR performance.

## 4. Proposed implementation boundaries

Names below are proposals, not existing services:

| Location | Responsibility |
| --- | --- |
| `scenes/worlds/ember_crypt/` | Entrance, room modules, enemies, rewards, lighting and world root |
| `scripts/worlds/ember_crypt/` | Run state, seeded layout, encounter/attack rules, enemy behavior and input adapter |
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
| 01 — Integration contract | Audit built-in selection/activation, input conflicts and existing Credits; define offline identifier, transition and player restoration contracts | Isolated tests cover safe entry/return, no duplicate player and no home replacement; unsupported online entry fails clearly |
| 02 — Asset/art spike | Audit/download minimal free subset; build the single finished reference room | Reproducible provenance, offline imports, desktop visual review; headset scale/comfort gate recorded as passed or still open |
| 03 — Graybox run | Seeded six-room graph, collision, spawn, doors and exit, initially without enemies | Fixed-seed determinism; many seeds produce connected traversable layouts; no overlap, inaccessible exit or unbounded retry |
| 04 — Combat slice | One attack, health, melee enemy, telegraphs, hit/death feedback | Cooldown/range/damage tests; no wall hits or damage after death; desktop playthrough and VR input/comfort check |
| 05 — Roguelike loop | Ranged enemy, room clear, bounded reward choices, healing, upgrades and seed retry | Rewards once only, doors unlock correctly, no softlocks; death/victory/restart reset all run state |
| 06 — Guardian and polish | Guardian encounter, finished art across modules, sound, concise controls and run summary | Complete 5–10 minute run; attacks readable without sound; art/performance budgets measured on declared hardware |
| 07 — World integration/release | Final offline selector, return-home recovery, exports, Credits and regression coverage | Clean exported install works with network disabled; repeated enter/exit leaves no AI, UI, input or audio behind; release checklist below complete |

**Dependency order:** 01 → 02 → 03 → 04 → 05 → 06 → 07. If trusted built-in
integration is unsuitable, stop and revisit delivery scope before building the
game; do not silently fall back to unsafe downloadable scripts.

## 6. Verification and definition of done

Add `python3 tests/roguelike_demo/run.py` as an isolated runner following repository
fixture conventions; this command is **planned and does not exist yet**. Cover
seed reproducibility/connectivity, encounter ordering, cooldowns and duplicate hits,
reward uniqueness/stack caps, death/victory, restart, pause/menu suppression and
cleanup during world transition. Include long-frame and repeated-entry cases.

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
- [ ] Clean exported build plays without network, local import caches or authoring files.
- [ ] Return home works after victory, death, abort and failed activation.
- [ ] No unwanted account/settings writes, microphone restart, relay-state leak or duplicate player.
- [ ] The selector and documentation label the demo **solo/offline**, not multiplayer-ready.

## 7. Deferred work

More biomes, weapons, persistent unlocks, co-op and public downloadable publication
are separate proposals after the small demo passes its gates. Prioritize a finished
room and satisfying core combat over a larger dungeon. Record delivered milestones
here and update the [roadmap index](README.md); planned features must not be
described as current application behavior.
