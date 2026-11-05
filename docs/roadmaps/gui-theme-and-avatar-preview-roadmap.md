# GUI theme, usability and avatar preview roadmap

## Status and scope

**Planned — 2026-11-05.** Nothing in this document is implemented yet. It plans
three connected outcomes:

1. One shared **Theme resource** (`themes/default.tres`) that styles every menu,
   desktop and VR, with **several selectable color schemes** and an accent color.
2. A **hand-made, calm look** that does not read as generic AI output, plus
   targeted rewrites to make the menus easier to use.
3. A **much better avatar preview** (orbit/pitch/pan, floor, lighting, loading
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
- New suite `tests/gui_theme/run.py` following the existing runner pattern.

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
- Complete the icon set: home, friends, world, settings, avatar, emote, close,
  search, rotate, zoom, reset, folder, warning, check. Replace Unicode-glyph
  buttons everywhere.

### Part 6 — Menu shell rewrite (navigation)
- Replace "bottom tabs + Home grid + Submenu" with one shell:
  **left navigation rail** (Home, Friends, Worlds, Avatars, Settings) +
  **page header** (title, back button only for nested pages, mic/status on the
  right) + content area.
- Home becomes a summary: current instance, quick actions (Invite, Emotes,
  Change avatar), online friends — not a duplicate of the nav.
- Keyboard/controller focus order, `Esc` = back then close; VR hit targets
  ≥ 48 px at default scale.
- Keep `menue.tscn` path/UID and public node names used by tests
  (`home_menue`, `world_explorer`, `settings_menue`, `friends_menue`) or update
  `tests/real_ui`, `tests/friends`, `tests/microphone_settings`,
  `tests/profile` in the same commit. `blocks_global_shortcuts` and the
  `vr_menu` meta behavior must not change.

### Part 7 — Settings page rewrite
- Row layout: label + caption on the left, control on the right; Reset is a
  small icon that appears only when the value differs from default; error text
  only takes space when present.
- Search box filtering labels/descriptions across categories.
- Category list uses `NavButton`; registry, store and validation unchanged.

### Part 8 — Avatar preview rewrite
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

### Part 9 — Avatar browser layout and split
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

### Part 10 — Remaining pages and polish
- Friends, World Explorer, Active Instance, Profile, Credits and popups moved
  to the shared row/list patterns; empty states with one sentence + action.
- Toasts (`Toast` variation) for non-blocking messages instead of
  `AcceptDialog` where nothing needs confirming.
- Update user docs (`docs/getting-started`, guides) with new screenshots and
  the color options.

## Verification and release gates

- Automated per part: `tests/gui_theme` (new), plus the affected suites
  (`real_ui`, `profile`, `microphone_settings`, `friends`, `active_instance`,
  `avatar_discovery`, `avatar_loading`, `animation_sync`, `vr_controls`) and
  `python3 tools/check_repository.py` for docs.
- Contrast check for every preset × accent pair is automated.
- Manual gates (not covered by headless tests): visual review of every preset
  on desktop at 720p/1080p/1440p; VR panel readability and pointer hit-testing
  on a headset; preview performance with a heavy VRM; reviewer check against
  the "made by people" rules above.

## Risks

- Large `.tscn` rewrites can break node paths in tests; mitigate by keeping
  public node names and updating tests in the same commit.
- Mutating the shared Theme triggers relayout of all open controls; switching
  presets is rare, but measure it in VR.
- A bundled font increases export size (~200–400 KB) — acceptable.
- Preview environment/shadows cost GPU time; keep them inside the preview's
  own world and only render when needed.
