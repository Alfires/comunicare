# GUI theme, tablet and avatar preview acceptance tests

**Implemented 2026-11-06: 356 passed, 0 failed, exit 0** (Godot 4.7.2). Written
first as opt-in red roadmap tests; the history below is kept.
They cover all twelve parts of the
[GUI theme, usability and avatar preview roadmap](../../docs/roadmaps/gui-theme-and-avatar-preview-roadmap.md).
`tools/check_repository.py` does not invoke this suite; run it after GUI changes.

```sh
python3 tests/gui_tablet/run.py              # all parts
python3 tests/gui_tablet/run.py --part 8     # one part (repeatable)
GODOT=/path/to/godot python3 tests/gui_tablet/run.py
```

Exit **0** = all checks pass, **1** = assertion failures (expected until the parts
are implemented), **2** = broken test project, Godot `ERROR:`/script error, timeout
or missing prerequisite. Exit 2 is never an acceptable red baseline.

Initial red baseline (2026-11-05, Godot 4.7.2, before any implementation):
**17 passed, 79 failed**, exit 1, no Godot errors. The passing checks are
regression guards for behavior that already exists and must survive the
rewrites: preview safety, stale-load handling, local-file limits, the unchanged
`interface.hover_color` setting and existing settings rows. Groups stop after a
missing component, so the assertion count grows as each part lands. This
summary is not the final implemented-system count.

## How it runs

- Python checks: Part 1 (style inventory tool), Part 4 (repository inventory),
  Part 12 (user docs).
- Godot checks: a disposable Compatibility project under `/tmp/opencode` with
  copies of `scripts/`, `scenes/GUI`, `themes/`, `relay_protocol/` and the real
  `[input]`, `[gui]` and `[display]` sections of `project.godot`.
  - `SaveData` uses the real registry, store and voice code with a disposable config.
  - `DataLoader` and `NetworkHandler` are inert fixtures.
  - Heavy production pages (friends, discovery, OAuth) are replaced in shell tests
    through `page_factories`. Their scene paths are asserted separately.
  - `project.godot`, `THIRD_PARTY_ASSETS.md` and `player_desktop.tscn` are copied
    as text evidence.
- Lines marked *(wiring check)* are source/scene evidence, not behavior.
- Not covered: rendered appearance, real VR headset feel, comfort, hand
  tracking, font rendering quality and preview GPU cost. These remain manual gates.

## Proposed contracts by part

The roadmap did not fix every interface. These are product contracts for the
tests. They may be adapted with implementation evidence, but must not be
replaced by passing empty stubs. Values, texts and behavior come from the
[GUI tablet specification](../../docs/roadmaps/gui-tablet-specification.md).
The tests check its palette tables, the 18/24/14 px text sizes, the Quick tile
list, the status-bar contents, the VR logical layout size and the key texts.

### Part 1: `tools/gui/style_inventory.py`
- `--root DIR` (default: repository root) scans `scripts/GUI/*.gd` and `scenes/GUI/*.tscn`.
- Finding kinds:
  - `color_literal`: `Color(`, `Color.html` or named `Color.X` constants, in `.gd` files only.
  - `script_override`: `add_theme_*_override` calls.
  - `scene_override`: `theme_override_*` lines in `.tscn` files.
- `--json` prints `[{"path": relative POSIX path, "line": int, "kind": str}]`.
- `--check` exits 1 if any finding is not allowlisted.
- `--allowlist FILE` (default `tools/gui/style_allowlist.txt`) takes `path:LINE` or `path:*` entries, each with a ` # reason`.
- `tests/real_ui/run.py` gains a `--capture` screenshot mode.

### Part 2: `scripts/GUI/theme/`
- `palette.gd`:
  - `presets()` and `accents()` return the roadmap lists.
  - `tokens(preset, accent, highlight)` returns Colors for `background, surface, surface_raised, border, text, text_muted, accent, accent_text, focus, success, warning, danger, preview_stage, overlay_dim`.
  - Unknown names fall back to Graphite/Teal.
  - Contrast is checked with an independent WCAG implementation: text ≥ 4.5:1 (7:1 for High contrast), focus/danger ≥ 3:1.
  - Restraint rules: surfaces saturation ≤ 0.25, accents ≤ 0.85.
- `theme_builder.gd`: `build(theme, tokens)` mutates and returns the same Theme and provides:
  - Type variations: `HeaderLabel, CaptionLabel, MutedLabel, PrimaryButton, DangerButton, IconButton, NavButton, QuickTile, Sidebar, ListRow, PreviewStage, Toast, TabletFrame, StatusBar`.
  - Custom colors: `EmoteWheel.{segment,segment_hover,segment_disabled,label,label_disabled,message}`, `CircularValue.{background,track,knob}`, `ErrorPopup.shade`, `PreviewStage.background`, `DesktopOverlay.dim`.
  - Radii: 4 px for controls, 6 px for panels.
  - Exactly three text sizes, and spacing on a 4 px grid.
  - Only flat/empty/line styleboxes, with shadows ≤ 8 px and ≤ 35 % alpha.
- `theme_service.gd`: `SaveData.theme_service` with `apply()`, `current_tokens()` and `reduce_motion`.
- `project.godot` sets `gui/theme/custom="res://themes/default.tres"`.

### Part 3: color settings
- Interface settings `interface.theme_preset`, `interface.accent`, `interface.ui_scale` and `interface.reduce_motion`. Changes apply live.
- `ui_scale` sets the root window's `content_scale_factor`.
- `scripts/GUI/theme/swatch_picker.gd`: `swatch_buttons()` and `value`. Used by `settings_menue.gd` for preset and accent.

### Parts 4–5
- Drawn controls use `get_theme_color` and redraw on `NOTIFICATION_THEME_CHANGED`.
- One OFL font in `themes/fonts/`, with its license next to it and an entry in `THIRD_PARTY_ASSETS.md`.
- Square stroke SVG icons: `home quick friends world avatar instance settings emote close search rotate zoom reset folder warning check people pin` plus the existing ones.
- No glyph-only, arrow or emoji button labels in `scenes/GUI` / `scripts/GUI`.

### Part 6: `scenes/GUI/tablet_shell.tscn` (`scripts/GUI/tablet_shell.gd`)
- Methods: `open_page, push_page(control, title), back() -> bool, reset, current_page, page_ids, page_scene_paths, set_compact, update_status(dict), handle_quick_action(id)`.
- `page_factories` is a Dictionary of `id → Callable`, prefilled with the defaults.
- Signals `close_requested` and `quick_action(id)`.
- Unique nodes: `%StatusBar %NavRail %PageHeader %Content %ProfileButton %PresenceButton %InstanceLabel %PeopleLabel %PinButton %MicButton %Clock %CloseButton %BackButton %PageTitle %HeaderActions`.
- `%PresenceButton` is a MenuButton with the items Online, Do not disturb and Appear offline.
- `%PinButton` is hidden on desktop and visible on the VR tablet.
- With no instance, `%InstanceLabel` reads "Not in an instance".
- Nav buttons carry the `page_id` meta.
- `scenes/GUI/quick_page.tscn` emits `action_requested(id)`. Tiles carry the `quick_action` meta, in this order: `mute emotes avatar invite respawn mirror`. `%OnlineFriends` holds the friends strip.
- The mic button and mute tile use `SaveData.voice`, with icons `microphone.svg` / `microphone_muted.svg`.
- `menue.tscn` keeps its path and wraps the shell.

### Part 7: `scenes/GUI/desktop_overlay.tscn`
- Root is a `CanvasLayer` with `%Dim` (ColorRect, no material) and `%Shell`.
- Methods: `open, close, toggle, is_open, layout_for(size) -> {rect, compact}, apply_layout(size), handle_input(event) -> bool`. Signals `opened` / `closed`.
- Layout: 4:3, centered, at most 86 % of the window height.
- Compact mode switches on when 0.86·height < 560 px or the 4:3 width does not fit the window. It uses the full window height.
- Esc goes back first, then closes, and reopens on Quick. Keys 1–6 select pages. `blocks_global_shortcuts` is honored. The overlay is not draggable, and a click on `%Dim` closes it.
- `player_desktop.tscn` references the overlay.

### Part 8: `scenes/GUI/vr_tablet.tscn` (`scripts/GUI/vr_tablet.gd`, screen faces +Z)
- Methods: `configure(store), place_initial(head), summon(head), raycast_to_pixel(origin, dir), grab_zone_contains(point), begin_grab(hand, transform) -> bool, update_grab, end_grab, remember_placement(player), restore_placement(player) -> bool, update_follow(head, delta), world_grab_blocked(point), touch_pixel(fingertip) -> {pixel, hover, pressed} or {}, effective_smoothing()`.
- Properties: `viewport` (1600×1200, `size_2d_override` 1000×750 with stretch, `vr_menu` meta), `screen_size_m` (0.55 × 0.4125), `scale_factor` (0.6–1.6), `pin_mode`, `smoothing`, `reduce_motion`, `direct_touch_enabled`, and `%KeyboardAnchor` below the screen.
- Direct touch: hover from 0 to 3 cm in front of the screen; press from 0.8 cm in front to 2 cm behind it.
- Settings in category VR Menu: `vr.menu_pin_mode`, `vr.menu_scale`, `vr.menu_direct_touch`, `vr.menu_hand`.
- `TrackerSetupButton` and `ComfortPresetButton` move into Settings.

### Part 9: settings rows
- Each row (meta `setting_id`) has the children `Title`, `Caption` (only when a description exists; `CaptionLabel` or `MutedLabel`), `Value`, `Reset` (`IconButton`, visible only when the value is not the default) and `Error` (hidden while empty).
- `Search` is a LineEdit with the `blocks_global_shortcuts` meta, and `NoResults` is shown when nothing matches.
- Category buttons use `NavButton`.

### Part 10: `scenes/GUI/avatar_stage.tscn` and the preview
- Stage methods: `set_model, clear, orbit(Vector2), pan(Vector2), zoom_by, reset_view, frame("full"|"upper"|"face") -> bool, camera_target() (stage-world), camera_distance, process_camera(delta), is_rendering_continuously, background_color`.
- Stage properties: `yaw, target_yaw, pitch` (−20° to +45°), `zoom` (0.5–3), `pan_offset` (≤ 1), `smoothing`, `reduce_motion`. The stage contains `Floor`, at least three lights, a WorldEnvironment and an opaque SubViewport.
- The preview keeps its current API, and adds:
  - `state`: `empty|loading|error|ready`.
  - `stage`, plus the nodes `%StatusLabel %Loading %RetryButton %Toolbar` (with `OpenFile Framing ResetView Idle`) and `%StageContainer`.
  - `set_idle_animation(bool) -> bool`.
  - The toolbar is shown on hover on desktop and always on the VR tablet.

### Parts 11–12
- `scripts/GUI/avatar_browser/browser_results.gd`: `set_records`, `cards()`, `columns_for_width` (220 px per column), signal `record_selected`, `EmptyState` node.
- `browser_detail.gd`: `show_record(record, eligibility)`, `set_progress`, `show_error`, signal `apply_requested`. Nodes `UseButton` (PrimaryButton, "Use this avatar"), `Progress` and `Reason`.
- `browser_sidebar.gd`: `set_sources`, `state()`, signal `filters_changed`, and a `Search` field.
- `avatar_browser.gd` is at most 400 lines and has no modal apply dialog.
- `scripts/GUI/toast_host.gd`: `show_message(text, kind, seconds)`, `visible_toasts()`, a static `find_for(node)` lookup and `ToastHost.notify(node, text, kind)`. At most three toasts, which never take focus. Pages count as toast users when they call `show_message(` or `ToastHost.notify(`.
- `scripts/GUI/empty_state.gd`: `configure(icon, message, action_label := "", action := Callable())` with `Message` and `Action` nodes.
- User docs mention the tablet, grip and all six presets.
