# GUI theme, usability and avatar preview roadmap

## Status and scope

**Planned — 2026-11-05 (revised same day: tablet form factor).** Nothing in
this document is implemented yet. It plans four connected outcomes:

1. A **tablet-style menu by default** that mixes the familiar social-VR layout
   (VRChat-like quick menu, launch-pad tiles, status bar) with a modern, flat
   app design. One shared layout is used on both platforms:
   - **VR:** a floating tablet that you can grab, move, rotate, pin and summon.
   - **PC:** the same tablet content drawn as a 2D overlay menu.
2. One shared **Theme resource** (`themes/default.tres`) that styles every menu,
   desktop and VR, with **several selectable color schemes** and an accent color.
3. A **hand-made, calm look** that does not read as generic AI output, plus
   targeted rewrites to make the menus easier to use.
4. A **much better avatar preview** (orbit/pitch/pan, floor, lighting, loading
   and error states) and a cleaner avatar browser layout.

Out of scope: new networking, profile/settings ownership changes, world
authoring UI, VR IK/FBT (see the [VR roadmap](vr-controls-menus-ik-fbt-roadmap.md)).

## Current-code baseline (verified 2026-11-05)

- `themes/default.tres` is an **empty** `Theme` and is not referenced by
  `project.godot` or any scene. Every control uses Godot's stock theme.
- Hard-coded colors live in `scripts/GUI/circular_value_control.gd`,
  `scripts/GUI/emote_wheel.gd` and `scripts/GUI/error_popup.gd`; inline
  `theme_override_*` values are spread over `profile_menue.tscn`,
  `profile_edit_popup.tscn`, `home_menue.tscn` and several scripts.
- `scripts/GUI/menue.gd` duplicates the TabContainer panel stylebox at runtime
  to strip margins — a layout workaround that a real theme makes unnecessary.
- Navigation is mixed: a bottom `TabContainer` (Home/Friends/World
  Explorer/Settings) *and* a Home grid that opens a `Submenu` with its own
  "← Home" button. World Explorer is reachable from two places.
- `scripts/GUI/settings_menue.gd` builds pages from the registry. Every row
  shows label, description, control, an always-visible **Reset** button and an
  empty error label, giving a long, uniform list with weak hierarchy.
- `scripts/GUI/avatar_preview.gd` (`scenes/GUI/avatar_preview.tscn`):
  yaw-only rotation, zoom 0.5–3×, two directional lights, transparent
  background, no floor/shadow, no pitch or pan, Status/Load/Reset hidden,
  glyph buttons `… ↶ ↷ + −`. Safety (`_safe_preview_tree`), generation
  tickets and the 64 MiB local file limit are good and must be kept.
- `scripts/GUI/avatar_browser.gd` is 806 lines, builds all UI in code, appends
  the preview into the results list and shows a modal `AcceptDialog` for
  applying an avatar.
- `interface.hover_color` (cyan/yellow/green/magenta/white) only tints 3D
  interaction highlights (`scripts/assets/interaction_highlight.gd`).
- VR menus render the same `menue.tscn` into a `SubViewport`
  (`scripts/GUI/vr_gui.gd`, `scripts/player/player_vr.gd`). Theme inheritance
  does **not** cross a SubViewport, so the theme must be set project-wide or on
  each root.
- `player_vr.gd::_toggle_main_menu()` creates a flat 1.2 × 0.9 m quad
  (800 px/m) placed 1.2 m in front of the head, facing the camera. It cannot be
  grabbed, moved, rotated or resized. "VR tracker setup" and "Comfort preset"
  buttons are added on top at absolute pixel positions, outside the menu
  layout. Controller lasers go through `vr_pointer_router.gd`; text fields open
  `vr_keyboard.gd`.
- Desktop: `player_desktop.tscn` instances `menue.tscn` as a TabContainer
  anchored 10 %–90 % of the window, toggled by `open_menue` with mouse capture.
- `project.godot`: stretch mode `canvas_items`, aspect `expand`.
- Bundled icons: `themes/icons/{microphone,microphone_muted,profile,back,edit}.svg`.

## Design direction: "made by people, not generated"

Generic AI-looking UI usually shows: purple/cyan neon gradients, glow,
glassmorphism, every element in an identical rounded card, emoji as icons,
centered everything, and vague, cheerful copy. Rules for this project:

- **Restrained palette.** One neutral ramp (≈7 steps) + one accent + semantic
  colors (success/warning/danger). The accent is used only for the primary
  action, focus ring, selection and active nav item — never as a fill for large
  areas. No gradients, no glow, no blur.
- **Real hierarchy.** Three text sizes (title / body / caption) and two weights.
  Section headers are plain text with spacing, not boxed cards.
- **Consistent geometry.** 4 px spacing grid (4/8/12/16/24/32), corner radius
  4 px for controls and 6 px for panels, 1 px borders in a neutral step. Not
  everything is a card; lists are rows with dividers.
- **Left-aligned, dense-enough layouts.** Labels left, controls right in
  settings; no centered paragraphs.
- **A single consistent icon set** (stroke SVGs in the existing
  `themes/icons/` style), never emoji or Unicode arrows as buttons.
- **Plain, specific copy.** "Load avatar preview (downloads the model)" instead
  of "Load an independent 3D preview."; errors say what happened and what to do.
- **Bundled readable font** (OFL), e.g. *Atkinson Hyperlegible* or *Inter*,
  recorded in `THIRD_PARTY_ASSETS.md`. One family only.
- **Minimal motion.** Only hover/press color transitions and the preview's
  camera damping; no bouncing or sliding panels (also better for VR comfort).

## Default form factor: the tablet

The default menu is a **tablet**: a 4:3 landscape screen with a thin device
frame. The layout is the same on VR and PC; only the host differs.

Mix of social-VR familiarity and modern app design:

| Taken from social-VR (VRChat-like) | Taken from modern app design |
| --- | --- |
| Quick menu first: big tiles for the things used every minute | Flat surfaces, neutral colors, one accent, clear typography |
| Persistent status bar: instance, people count, mic, clock | Left navigation rail with icons + labels, like a tablet app |
| Launch-pad grid on the Quick page; avatar/world cards with thumbnails | Detail panes, inline progress, toasts instead of modal dialogs |
| Safety/mute actions always one tap away | Search, empty states, consistent spacing grid |

Only the interaction ideas are borrowed. No VRChat names, icons, artwork,
fonts or color schemes are copied.

### Screen layout

Exact sizes, colors, texts and behavior are fixed in the
[GUI tablet specification](gui-tablet-specification.md), which takes precedence
over this overview.

```
┌──────────────────────────────────────────────────────────────┐
│ [profile][presence] instance · [people] 7  [pin][mic] 12:41 [x] │ 56 px
├────────┬─────────────────────────────────────────────────────┤
│ Nav    │ Page header: title · back (nested pages) · actions  │
│ rail   ├─────────────────────────────────────────────────────┤
│ Quick  │                                                     │
│ Friends│                 Page content                        │
│ Worlds │                                                     │
│ Avatars│                                                     │
│ Instance                                                     │
│ Settings                                                     │
└────────┴─────────────────────────────────────────────────────┘
```
Bracketed names are icons from the SVG icon set.

- **Quick page (default when opening):** six tiles: Mute, Emotes, Change
  avatar (thumbnail of the current avatar), Invite, Respawn and Mirror. Below
  them is an "Online friends" strip. Each tile is large (≥ 160 × 120 px) and has
  an icon and a short label. Hide avatars and Camera were dropped because no
  matching feature exists (specification D1).
- **Profile and presence** move from the old Home page to the left of the
  status bar.
- **Nav rail:** 96 px wide, icon above label, active item marked with the
  accent bar. It never scrolls at the default scale.
- **Status bar:** always visible. In VR it doubles as the **grab handle**.
- Desktop and VR pages are the same scenes. No page builds its own back button
  or tabs; the shell owns navigation.

### VR: floating, movable tablet

- `scenes/GUI/vr_tablet.tscn` (replaces direct use of `vr_gui.tscn`): a
  `Node3D` with a thin rounded box frame mesh, the screen quad (SubViewport)
  and grab zones on the frame/status bar.
- **Open/close:** the existing menu button (`input.xr_main_menu_action`). On
  first open the tablet appears 0.55 m in front, slightly below eye height and
  tilted toward the face (like holding a tablet). Later opens restore the last
  placement **relative to the player's yaw**, so it stays where you put it
  after you turn or move.
- **Grab and move:** press grip while a hand touches the frame or points at the
  status bar. The tablet follows that hand with its relative offset and
  rotation, smoothed. Releasing leaves it floating in place. Two-hand grab
  scales it within 0.6×–1.6×. Grip already picks up world items
  (`scripts/worlds/world_pickup_controller.gd`). While the menu is open and a
  hand is inside a tablet grab zone, the tablet wins and no world grab is
  requested. Outside the zone, world pickup behaves as today.
- **Pin modes** (button in the status bar): *Pinned in world* (stays where
  placed, default) or *Follow* (lazily re-centers in front when it is more than
  ~45° out of view). **Holding** the menu button for 0.6 s summons it in
  front; a short press still opens or closes it.
- **Interaction:** both controller lasers keep working via
  `vr_pointer_router.gd`. Optional **direct touch** with the controller tip
  (6 cm along the aim direction) when it is within 3 cm of the screen, with a
  press threshold and haptic tick. The laser hides while that hand is touching.
- **Readability:** default 0.55 × 0.41 m screen rendered at 1600 × 1200 px
  (about 2900 px/m) but laid out at 1000 × 750 logical px, so 18 px body text
  is about 1° tall at arm's length. Unshaded screen, no bloom;
  a slight frame shadow helps depth perception.
- **Comfort:** the tablet never locks to the head. Smoothing respects
  `interface.reduce_motion`. Opening the menu still dismisses the emote wheel
  and re-arms movement exactly as today.
- The tracker-setup and comfort-preset buttons move into **Settings → VR** as
  normal rows instead of floating over the menu.
- `vr_keyboard.gd` docks under the tablet and moves with it.
- New settings (category **VR Menu**): `vr.menu_pin_mode` (pinned/follow),
  `vr.menu_scale` (0.6–1.6), `vr.menu_direct_touch` (bool),
  `vr.menu_hand` (which side the tablet opens on). The placement itself is
  session state, not a saved setting.

### PC: 2D overlay menu

- The same tablet shell is drawn in a `CanvasLayer` over the game, centered,
  keeping 4:3 and filling up to 86 % of the window height. On wide or small
  windows it switches to a full-height layout with the rail collapsed to icons.
- A 2D frame in the theme (rounded panel, 1 px border, subtle drop shadow) gives
  the tablet feel without a 3D model. Behind it the game is dimmed (no blur).
- `open_menue` (Esc) toggles it as today, with mouse capture/release
  unchanged. Esc first goes back from nested pages, then closes.
  `blocks_global_shortcuts` keeps working.
- Keyboard: Tab/arrow focus, Enter activates, number keys 1–6 select rail
  items. Mouse wheel scrolls pages; nothing requires hover.
- The PC overlay is **not** movable. It stays a fixed 2D menu.

## Color options

Provided as palette presets; each preset is a small token set, not a separate
hand-edited `.tres`:

| Preset | Base | Notes |
| --- | --- | --- |
| **Graphite** (default) | dark neutral grey | warm-neutral, not blue-black |
| **Paper** | light | off-white background, dark ink text |
| **Forest** | dark green-grey | muted, low saturation |
| **Sand** | light warm | beige/brown neutrals |
| **Night** | near-black | OLED/VR-friendly, low brightness |
| **High contrast** | black/white | WCAG AAA text, thick focus ring |

Accent choices (independent of preset): Teal, Blue, Amber, Green, Rose,
Violet, plus "Match 3D highlight". Each accent defines a light and dark
variant so contrast stays ≥ 4.5:1 for text on every preset.

New registry settings (category **Interface**, registry-driven like existing
ones, no profile fields):

- `interface.theme_preset` — enum, default `graphite`
- `interface.accent` — enum, default `teal`
- `interface.ui_scale` — number 0.75–1.5, step 0.05, default 1.0
  (`content_scale_factor` on desktop; panel `pixel_per_unit` on VR)
- `interface.reduce_motion` — boolean, default false

Changes apply live without restart. `interface.hover_color` stays as-is
(3D highlight); "Match 3D highlight" only reads it.

## Architecture

```
scripts/GUI/theme/
  palette.gd        # presets + accents → token Dictionary (pure, testable)
  theme_builder.gd  # tokens → fills an existing Theme (StyleBoxFlat, colors,
                    # fonts, constants, type variations)
  theme_service.gd  # listens to SaveData.store.setting_changed, rebuilds
themes/default.tres # the shared Theme resource; set as gui/theme/custom
themes/fonts/       # bundled OFL font + license
themes/icons/       # completed icon set
```

- `project.godot` gets `gui/theme/custom="res://themes/default.tres"` so all
  windows and SubViewports (VR panels) share it.
- `theme_builder.gd` **mutates the same Theme instance** and emits `changed`,
  so every open control updates; nothing caches colors.
- Custom-drawn controls (`emote_wheel.gd`, `xr_emote_wheel.gd`,
  `circular_value_control.gd`, `error_popup.gd`) read colors with
  `get_theme_color("…", "EmoteWheel")` etc. and `queue_redraw()` on
  `NOTIFICATION_THEME_CHANGED`.
- **Type variations** replace inline overrides: `HeaderLabel`, `CaptionLabel`,
  `MutedLabel`, `PrimaryButton`, `DangerButton`, `IconButton`, `NavButton`,
  `Sidebar`, `ListRow`, `PreviewStage`, `Toast`.
- Ownership: theme service is created by `SaveData` after settings load (keeps
  the documented autoload order); it does not add a new autoload unless the
  ordering test shows it is needed.

## Parts (each one commit, test-first where behavior changes)

Acceptance tests for all twelve parts already exist as an opt-in RED suite:
`python3 tests/gui_tablet/run.py [--part N]`. Every check is tagged `[P1]`…`[P12]`.
[tests/gui_tablet/README.md](../../tests/gui_tablet/README.md) lists the
proposed component interfaces the tests assume. A part is done when its checks
pass without Godot errors and the affected existing suites stay green.

### Part 1 — Baseline screenshots and inventory
- Extend `tests/real_ui` with a capture mode that saves PNGs of Home, Friends,
  World Explorer, Settings, Profile, Avatar Browser and the preview at
  1280×720 and 1920×1080 (manual comparison artifact, not a pass/fail gate).
- Script that lists every `theme_override_*`, `add_theme_*_override` and
  `Color(` in `scripts/GUI` / `scenes/GUI`; target is zero outside the theme.
- `docs(gui): …` / `test(real_ui): …`.

### Part 2 — Tokens, palette and theme builder
- `palette.gd` with the presets/accents above; unit tests check every
  text/background pair is ≥ 4.5:1 (≥ 7:1 for High contrast) and every preset
  defines all tokens.
- `theme_builder.gd` fills `default.tres`; wire `gui/theme/custom`.
- Remove the `menue.gd` stylebox hack (theme sets the TabContainer margins).
- Acceptance: `tests/gui_tablet/run.py --part 2`.

### Part 3 — Color settings, live switching, UI scale
- Register the four settings; Settings → Interface shows a **preset swatch
  row** and accent swatches instead of plain dropdowns (custom control, still
  backed by the enum value).
- Live apply on desktop and VR panels; tests assert the Theme changes and a
  sampled control's resolved color matches the token.

### Part 4 — Remove hard-coded styling
- Convert the emote wheels, circular value control, error popup and inline
  `.tscn` overrides to theme colors/type variations.
- Inventory script from Part 1 must report zero remaining overrides (allowlist
  for intentional ones, documented).

### Part 5 — Font and icon set
- Bundle one OFL font; add license to `THIRD_PARTY_ASSETS.md`.
- Complete the icon set: home, quick, friends, world, avatar, instance,
  settings, emote, close, search, rotate, zoom, reset, folder, warning, check,
  people, pin. Replace Unicode-glyph buttons everywhere.

### Part 6 — Tablet shell (shared layout)
- New `scenes/GUI/tablet_shell.tscn` / `scripts/GUI/tablet_shell.gd`: status
  bar, nav rail (Quick, Friends, Worlds, Avatars, Instance, Settings), page
  header with a navigation stack (`open_page`, `back`, `reset`) and content.
  It replaces "bottom tabs + Home grid + Submenu".
- New Quick page with the tile grid and online-friends strip. Tiles call the
  existing services (`SaveData.voice` for mute, emote controller, share
  session, avatar visibility), so no new state is introduced.
- `menue.tscn` keeps its path/UID and becomes a thin wrapper around the shell
  so `player_desktop.tscn`, `player_vr.gd` and tests keep loading it. Keep the
  public node names (`home_menue`, `world_explorer`, `settings_menue`,
  `friends_menue`) reachable or update `tests/real_ui`, `tests/friends`,
  `tests/microphone_settings`, `tests/profile` in the same commit.
- Hit targets ≥ 48 px at UI scale 1.0 (≥ 64 px for Quick tiles).
- Tests: navigation stack, back/reset, Quick-tile actions reach the right
  service, mute stays in sync with `SaveData.voice`.

### Part 7 — PC 2D overlay host
- `scenes/GUI/desktop_overlay.tscn`: `CanvasLayer` + dim background + the
  shell at 4:3, responsive collapse for narrow or short windows.
- Same `open_menue` toggle and mouse-capture behavior as today; Esc = back,
  then close; number-key rail shortcuts; `blocks_global_shortcuts` honored.
- Tests (`tests/real_ui`): open/close, focus order, back-before-close, layout
  at 1280×720, 1920×1080 and 1024×768.

### Part 8 — VR floating tablet host
- `scenes/GUI/vr_tablet.tscn` + `scripts/GUI/vr_tablet.gd`: frame mesh, screen
  quad (reuse `VRViewport2D` raycast/inject logic), grab zones, pin button,
  docked keyboard slot. Keep `vr_menu` viewport meta.
- `player_vr.gd`: `_toggle_main_menu()` instantiates the tablet instead of
  `vr_gui.tscn`. Grip near the frame grabs it; placement is stored relative to
  player yaw; summon brings it back in front; follow/pinned modes; two-hand
  scale. Move the tracker-setup and comfort-preset buttons into Settings → VR.
- Optional fingertip direct touch with a press threshold and haptics; the
  lasers stay the default.
- Register the `vr.menu_*` settings.
- Tests (`tests/vr_controls`, synthetic trackers): open in front at the
  expected distance/tilt, grab follows the hand offset, release keeps the
  pose, reopen restores yaw-relative placement, summon re-centers, the laser
  hits the correct pixel after moving/scaling, the menu still dismisses the
  emote wheel and re-arms motion. Headset comfort and readability remain
  manual gates.

### Part 9 — Settings page rewrite
- Row layout: label + caption on the left, control on the right; Reset is a
  small icon that appears only when the value differs from default; error text
  only takes space when present.
- Search box filtering labels/descriptions across categories.
- Category list uses `NavButton`; registry, store and validation unchanged.

### Part 10 — Avatar preview rewrite
Split into a reusable stage and a thin UI:

- `scenes/GUI/avatar_stage.tscn` / `avatar_stage.gd`: SubViewport, camera rig,
  lights, floor; **no** loading logic.
- `avatar_preview.gd`: loading, safety, generation tickets (kept from current
  code), toolbar overlay.

Improvements:

- **Orbit camera**: drag = yaw + limited pitch (−20°…+45°), right/middle drag
  = pan, wheel/pinch = zoom, double-click = reset; damped motion (off with
  `interface.reduce_motion`). VR pointer drag works through the existing
  `vr_pointer_router.gd`.
- **Framing presets**: Full body / Upper body / Face, using the humanoid head
  bone when available, falling back to the AABB fit already in `_fit_model`.
- **Staging**: soft floor disc with contact shadow, three-point lighting, a
  neutral `Environment` with ambient light; background color from the theme's
  `PreviewStage` token (not transparent-on-anything).
- **Idle animation** (optional toggle) using the existing `avatar_animator.gd`,
  same path the browser animation preview already uses.
- **States**: empty (icon + "No avatar set"), loading (spinner + progress
  where DataLoader reports it), error (message + Retry), ready. Status label
  visible again, with honest copy.
- **Toolbar overlay** inside the viewport: icon buttons for open local VRM,
  framing, reset, idle toggle — hidden until hover on desktop, always visible
  in VR.
- **Performance**: render only while visible and while the camera moves or an
  animation plays (`UPDATE_WHEN_VISIBLE` + manual `UPDATE_ONCE` when idle);
  keep the existing `stretch_shrink` cap.
- Must keep: `_safe_preview_tree`, 64 MiB limit, local path never sent over
  the network, URL-change/generation guards, `failed` signal, `set_source`,
  `clear_preview`, `load_preview`, `model` and `loader` used by
  `profile_menue.gd`, `profile_edit_popup.gd`, `avatar_browser.gd` and
  `tests/profile/suite.gd`.

### Part 11 — Avatar browser layout and split
- Layout: left filters, **card grid** of thumbnails in the middle, **detail
  pane** on the right with the new preview, license/source info and a single
  primary "Use this avatar" button. The preview no longer appears inside the
  results list.
- Apply progress shown inline in the detail pane instead of a modal dialog;
  cancel only where the import pipeline already supports it.
- Split `avatar_browser.gd` into `browser_sidebar.gd`, `browser_results.gd`,
  `browser_detail.gd` and keep discovery/import/OAuth logic in
  `scripts/discovery/avatars/` unchanged. `tests/avatar_discovery` and
  `tests/real_ui/avatar_suite.gd` must stay green.

### Part 12 — Remaining pages and polish
- Friends, World Explorer, Active Instance, Profile, Credits and popups moved
  to the shared row/list patterns; empty states with one sentence + action.
- Toasts (`Toast` variation) for non-blocking messages instead of
  `AcceptDialog` where nothing needs confirming.
- Update user docs (`docs/getting-started`, guides) with new screenshots and
  the color options.

## Verification and release gates

- Automated per part: `tests/gui_tablet --part N` (opt-in RED suite), plus the affected suites
  (`real_ui`, `profile`, `microphone_settings`, `friends`, `active_instance`,
  `avatar_discovery`, `avatar_loading`, `animation_sync`, `vr_controls`) and
  `python3 tools/check_repository.py` for docs.
- Contrast check for every preset × accent pair is automated.
- Manual gates (not covered by headless tests): visual review of every preset
  on desktop at 720p/1080p/1440p; VR tablet readability, grab/move/scale feel,
  direct touch accuracy and pointer hit-testing on a headset; seated and
  standing placement; preview performance with a heavy VRM; reviewer check
  against the "made by people" rules above.

## Risks

- Large `.tscn` rewrites can break node paths in tests; mitigate by keeping
  public node names and updating tests in the same commit.
- Mutating the shared Theme triggers relayout of all open controls; switching
  presets is rare, but measure it in VR.
- A bundled font increases export size (~200–400 KB) — acceptable.
- A 1600 × 1200 SubViewport for the VR tablet costs fill-rate. It renders only
  while open, and its update rate drops when nothing changes.
- Grip conflicts between tablet grab and world pickup; covered by the
  grab-zone priority rule and the `vr_controls` tests.
- "VRChat-like" must stay at the level of interaction patterns. Do not copy
  protected names, icons, artwork or exact layouts.
- Preview environment/shadows cost GPU time; keep them inside the preview's
  own world and only render when needed.
